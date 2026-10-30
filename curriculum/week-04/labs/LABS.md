# Week 4 Labs

> **Figures:** one numbered mechanism figure per lab, with the spoken script, the numbers to own and
> the command that proves each badge, in [`FIGURES.md`](FIGURES.md) (4.2 to 4.7). Read a lab's figure
> before you start it; redraw it after.

---

# Lab 1 — Python Ops CLI (3h)

Rewrite week 1's `sysreport.sh` in Python. Not as a translation — as a better tool.

## Requirements
- `argparse` with subcommands: `report`, `check`, `watch`
- Type hints throughout; `mypy` clean
- `logging` to stderr with `--verbose`/`--quiet`
- `--format table|json|prometheus` (Prometheus text exposition — you'll use it in week 20)
- Exit codes: 0 healthy, 1 threshold breach, 2 usage error
- Proper exception handling — no bare `except:`
- `pytest` tests with at least 6 test cases
- Packaged with `pyproject.toml` so `pip install -e .` gives you a `sysreport` command

## Skeleton

```python
#!/usr/bin/env python3
"""System health report."""
from __future__ import annotations

import argparse
import json
import logging
import sys
from dataclasses import dataclass, asdict, field
from pathlib import Path
from typing import Any, Iterator

log = logging.getLogger("sysreport")


@dataclass(frozen=True)
class DiskUsage:
    mount: str
    used_pct: int
    available_bytes: int

    @property
    def healthy(self) -> bool:
        return self.used_pct < 80


@dataclass
class Report:
    hostname: str
    kernel: str
    load: tuple[float, float, float]
    cores: int
    memory_pct: int
    disks: list[DiskUsage] = field(default_factory=list)

    @property
    def healthy(self) -> bool:
        return self.memory_pct < 80 and all(d.healthy for d in self.disks)


def read_loadavg(proc: Path = Path("/proc/loadavg")) -> tuple[float, float, float]:
    """Return the 1/5/15-minute load averages."""
    parts = proc.read_text().split()
    return (float(parts[0]), float(parts[1]), float(parts[2]))


def read_meminfo(proc: Path = Path("/proc/meminfo")) -> int:
    """Return memory used as a percentage of total."""
    values: dict[str, int] = {}
    for line in proc.read_text().splitlines():
        key, _, rest = line.partition(":")
        values[key] = int(rest.split()[0])
    total = values["MemTotal"]
    available = values["MemAvailable"]
    return round((total - available) * 100 / total)


def collect() -> Report:
    ...  # TODO


def render_table(r: Report) -> str: ...
def render_json(r: Report) -> str: ...
def render_prometheus(r: Report) -> str: ...


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(prog="sysreport", description=__doc__)
    p.add_argument("-f", "--format", choices=("table", "json", "prometheus"), default="table")
    p.add_argument("-t", "--threshold", type=int, default=80)
    p.add_argument("-v", "--verbose", action="store_true")
    args = p.parse_args(argv)

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.WARNING,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
        stream=sys.stderr,
    )

    try:
        report = collect()
    except FileNotFoundError as exc:
        log.error("cannot read %s -- is this Linux?", exc.filename)
        return 2
    except PermissionError as exc:
        log.error("permission denied reading %s", exc.filename)
        return 2

    renderers = {"table": render_table, "json": render_json, "prometheus": render_prometheus}
    print(renderers[args.format](report))
    return 0 if report.healthy else 1


if __name__ == "__main__":
    sys.exit(main())
```

## Why these choices matter

**`Path.read_text()` with an injectable default** (`proc: Path = Path("/proc/loadavg")`) makes the
function testable — a test passes a fixture file instead of needing a real `/proc`. **Designing for
testability by parameterizing I/O is the single most useful Python-for-ops habit.**

**`@dataclass(frozen=True)`** gives you free `__eq__`, `__repr__`, and immutability. `asdict()`
serializes for free.

**`sys.exit(main())`** means `main()` returns an int and is directly unit-testable — no
`SystemExit` to catch in tests.

**Never `except:` bare** — it catches `KeyboardInterrupt` and `SystemExit` too, so Ctrl+C stops
working. Catch specific exceptions.

## Prometheus output format (preview of week 20)

```
# HELP node_load1 1-minute load average
# TYPE node_load1 gauge
node_load1 0.42
# HELP node_memory_used_percent Memory used as a percentage
# TYPE node_memory_used_percent gauge
node_memory_used_percent 61
# HELP node_filesystem_used_percent Filesystem usage
# TYPE node_filesystem_used_percent gauge
node_filesystem_used_percent{mount="/"} 43
node_filesystem_used_percent{mount="/var"} 71
```
Note the labels in `{}`. That is exactly the cardinality question from BF-56 — `mount` is fine
(bounded), a `pid` label would not be.

---

# Lab 2 — Testing, Packaging, HTTP (2h)

## Part 1 — pytest

```python
# tests/test_sysreport.py
import textwrap
import pytest
from pathlib import Path
from sysreport import read_loadavg, read_meminfo, DiskUsage, Report


@pytest.fixture
def fake_loadavg(tmp_path: Path) -> Path:
    p = tmp_path / "loadavg"
    p.write_text("0.42 0.55 0.61 2/331 12345\n")
    return p


@pytest.fixture
def fake_meminfo(tmp_path: Path) -> Path:
    p = tmp_path / "meminfo"
    p.write_text(textwrap.dedent("""\
        MemTotal:       16384000 kB
        MemFree:         2048000 kB
        MemAvailable:    6553600 kB
    """))
    return p


def test_read_loadavg(fake_loadavg):
    assert read_loadavg(fake_loadavg) == (0.42, 0.55, 0.61)


def test_read_meminfo(fake_meminfo):
    assert read_meminfo(fake_meminfo) == 60


def test_read_loadavg_missing_file(tmp_path):
    with pytest.raises(FileNotFoundError):
        read_loadavg(tmp_path / "nope")


@pytest.mark.parametrize("pct,expected", [(0, True), (79, True), (80, False), (100, False)])
def test_disk_healthy_threshold(pct, expected):
    assert DiskUsage("/", pct, 0).healthy is expected


def test_report_unhealthy_if_any_disk_unhealthy():
    r = Report("h", "k", (0, 0, 0), 4, 10, [DiskUsage("/", 10, 0), DiskUsage("/var", 95, 0)])
    assert r.healthy is False


def test_main_exit_code_on_bad_args(capsys):
    from sysreport import main
    with pytest.raises(SystemExit) as exc:
        main(["--format", "bogus"])
    assert exc.value.code == 2
```

```bash
pytest -v
pytest --cov=sysreport --cov-report=term-missing
mypy sysreport.py
ruff check .
```

**The boundary-value parametrize test (79/80) is the one that matters.** Off-by-one on a threshold is
the most common bug in a check script, and it's the test a reviewer looks for.

## Part 2 — Package it

```toml
# pyproject.toml
[project]
name = "sysreport"
version = "1.0.0"
description = "System health report"
requires-python = ">=3.10"
dependencies = ["requests>=2.31"]

[project.scripts]
sysreport = "sysreport:main"

[project.optional-dependencies]
dev = ["pytest>=8", "pytest-cov", "mypy", "ruff"]

[build-system]
requires = ["setuptools>=68"]
build-backend = "setuptools.build_meta"
```

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -e '.[dev]'
sysreport --format json | jq
```

## Part 3 — HTTP clients that don't break in production

```python
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry


def make_session(retries: int = 3, backoff: float = 0.5) -> requests.Session:
    """A Session with retries, backoff, and a connection pool."""
    s = requests.Session()
    retry = Retry(
        total=retries,
        backoff_factor=backoff,
        status_forcelist=[429, 500, 502, 503, 504],
        allowed_methods=frozenset(["GET", "PUT", "DELETE", "POST"]),
        respect_retry_after_header=True,
    )
    adapter = HTTPAdapter(max_retries=retry, pool_connections=10, pool_maxsize=10)
    s.mount("https://", adapter)
    s.mount("http://", adapter)
    s.headers.update({"User-Agent": "sysreport/1.0"})
    return s


session = make_session()
r = session.get("https://api.github.com/rate_limit", timeout=(3.05, 10))
r.raise_for_status()
print(r.json())
```

**`timeout=` is not optional.** Without it, `requests` waits **forever** — a hung connection to a
dependency will hang your process until something kills it. The tuple is `(connect, read)`. This is
the #1 production bug in Python scripts that call APIs, and "always set a timeout" is a good answer
when asked about resilience.

---

# Lab 3 — Docker: What a Container Actually Is (3h)

> **Arch path:** the setup scripts install the workstation toolchain, not Docker on the lab VM, so install it there yourself:
> `sudo pacman -S docker docker-compose docker-buildx`, `sudo systemctl enable --now docker`,
> `sudo usermod -aG docker "$USER"`, then log out and back in.

## Part 1 — Prove it's just a process

```bash
docker run -d --name demo nginx:alpine
docker ps

# On the HOST, find the container's processes
ps -ef | grep nginx
docker inspect demo --format '{{.State.Pid}}'
sudo ls -l /proc/$(docker inspect demo --format '{{.State.Pid}}')/ns/
# ipc -> ipc:[4026532...]
# mnt -> mnt:[4026532...]
# net -> net:[4026532...]
# pid -> pid:[4026532...]
# uts -> uts:[4026532...]
# Compare to your shell:
ls -l /proc/self/ns/
```

**Different namespace IDs = different views. Same kernel.** That is the entire trick.

```bash
# Inside, it thinks it's PID 1
docker exec demo ps aux

# Its cgroup limits
docker run -d --name limited --memory=100m --cpus=0.5 nginx:alpine
cat /sys/fs/cgroup/$(docker inspect limited --format '{{.Id}}')/memory.max 2>/dev/null || \
  docker inspect limited --format '{{.HostConfig.Memory}}'
```

## Part 2 — Images are layers

```bash
docker pull python:3.12-slim
docker history python:3.12-slim
docker image inspect python:3.12-slim --format '{{json .RootFS.Layers}}' | jq
docker save python:3.12-slim -o /tmp/py.tar && tar -tf /tmp/py.tar | head
```

Build two images and observe layer sharing:
```bash
mkdir -p ~/lab4/layers && cd ~/lab4/layers
printf 'FROM python:3.12-slim\nRUN echo one > /one\n' > Dockerfile.a
printf 'FROM python:3.12-slim\nRUN echo two > /two\n' > Dockerfile.b
docker build -f Dockerfile.a -t layer-a .
docker build -f Dockerfile.b -t layer-b .
docker images | grep layer
docker system df       # note the SHARED size -- the base layer exists once
```

## Part 3 — Networking

```bash
docker network ls
docker network inspect bridge

# Default bridge: NO DNS between containers
docker run -d --name c1 alpine sleep 3600
docker run -d --name c2 alpine sleep 3600
docker exec c1 ping -c1 c2         # FAILS -- no name resolution

# User-defined network: embedded DNS at 127.0.0.11
docker network create appnet
docker run -d --name d1 --network appnet alpine sleep 3600
docker run -d --name d2 --network appnet alpine sleep 3600
docker exec d1 ping -c1 d2         # WORKS
docker exec d1 cat /etc/resolv.conf   # nameserver 127.0.0.11
```

**This is why Compose "just works"** — it creates a user-defined network for you. (BF-24)

```bash
# Reproduce BF-20: the bind-address bug
docker run -d --name bindbug -p 8080:8080 python:3.12-slim \
  python3 -c "import http.server,socketserver; socketserver.TCPServer(('127.0.0.1',8080), http.server.SimpleHTTPRequestHandler).serve_forever()"
curl -m3 localhost:8080            # connection reset
docker exec bindbug ss -tlnp       # bound to 127.0.0.1 -- there's the bug
```

## Part 4 — Volumes

```bash
docker run -d --name pg1 -e POSTGRES_PASSWORD=x postgres:16
docker exec pg1 psql -U postgres -c "CREATE TABLE t(i int); INSERT INTO t VALUES (1);"
docker rm -f pg1
docker run -d --name pg2 -e POSTGRES_PASSWORD=x postgres:16
docker exec pg2 psql -U postgres -c "SELECT * FROM t;"   # ERROR: relation does not exist

# Now with a volume
docker rm -f pg2
docker volume create pgdata
docker run -d --name pg3 -e POSTGRES_PASSWORD=x -v pgdata:/var/lib/postgresql/data postgres:16
sleep 5
docker exec pg3 psql -U postgres -c "CREATE TABLE t(i int); INSERT INTO t VALUES (1);"
docker rm -f pg3
docker run -d --name pg4 -e POSTGRES_PASSWORD=x -v pgdata:/var/lib/postgresql/data postgres:16
sleep 5
docker exec pg4 psql -U postgres -c "SELECT * FROM t;"   # the row is there
```

---

# Lab 4 — Dockerfiles: 1.2 GB → 20 MB (3h)

## The target application

```bash
mkdir -p ~/lab4/app && cd ~/lab4/app
cat > app.py <<'PY'
import os, signal, sys, json, logging
from flask import Flask, jsonify
import psycopg2

logging.basicConfig(level=logging.INFO, format='%(asctime)s %(levelname)s %(message)s')
app = Flask(__name__)
READY = {"v": False}

@app.get("/health")            # liveness: is the process alive?
def health(): return jsonify(status="ok"), 200

@app.get("/ready")             # readiness: can it serve traffic?
def ready():
    try:
        conn = psycopg2.connect(os.environ["DATABASE_URL"], connect_timeout=2)
        conn.close()
        return jsonify(status="ready"), 200
    except Exception as e:
        return jsonify(status="not-ready", error=str(e)), 503

@app.get("/")
def index(): return jsonify(app="demo", pid=os.getpid(), host=os.uname().nodename)

def term(sig, frame):
    logging.info("SIGTERM received, shutting down")
    sys.exit(0)
signal.signal(signal.SIGTERM, term)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 8080)))
PY

cat > requirements.txt <<'REQ'
flask==3.1.3
psycopg2-binary==2.9.9
gunicorn==22.0.0
REQ
```

**Note the two separate endpoints.** `/health` only checks the process; `/ready` checks the
database. That split is exactly the liveness/readiness distinction from BF-44 — a database blip
should take you out of rotation, not restart you.

## Step 1 — the naive Dockerfile (measure it)

```dockerfile
# Dockerfile.v1
FROM python:3.12
WORKDIR /app
COPY . .
RUN pip install -r requirements.txt
CMD ["python", "app.py"]
```
```bash
docker build -f Dockerfile.v1 -t demo:v1 .
docker images demo:v1
trivy image --severity HIGH,CRITICAL demo:v1 | tail -5
```
**Record the size and CVE count.** These numbers go in your README.

## Step 2 — slim base + `.dockerignore` + layer ordering
## Step 3 — multi-stage with a virtualenv
## Step 4 — non-root, read-only filesystem, healthcheck
## Step 5 — measure again

Work through each step yourself; the final Dockerfile and the numbers are in the solutions.

**Tasks:**
1. Build all versions and record size + CVE count for each in a table
2. Prove layer caching: change `app.py` and rebuild — which steps re-run?
3. Reverse the `COPY`/`RUN pip install` order and time both builds (BF-23)
4. Reproduce BF-22 by adding `.git` to the build context without a `.dockerignore`
5. Run as root vs non-root and `docker exec whoami` to confirm

---

# Lab 5 — Break/Fix Friday #4 (2h)

**BF-19** (container exits immediately) · **BF-20** (can't reach the container) ·
**BF-21** (data lost on restart) · **BF-22** (1.2 GB image) · **BF-23** (cache always misses) ·
**BF-24** (DNS inside a container).

All six are container-specific and every one of them recurs in Kubernetes in week 14. Log them all.

---

# Lab 6 — The Compose Stack (4h) — DELIVERABLE

Build: **Nginx (TLS) → Flask app (gunicorn) → Postgres**, with healthchecks, a named volume, a
non-root app user, and no secrets in the image.

## Requirements
- [ ] `docker compose up` brings the whole stack up from a clean machine
- [ ] Nginx terminates TLS (self-signed is fine) and proxies to the app
- [ ] App runs as non-root with a read-only root filesystem
- [ ] Postgres data survives `docker compose down && docker compose up`
- [ ] Healthchecks on all three services; app waits for a **healthy** database
- [ ] Secrets via environment/`.env`, never baked into the image
- [ ] `docker compose logs` shows structured output from all services
- [ ] Resource limits on every service
- [ ] `.dockerignore`, `.gitignore`, and no secrets in git history

## Deliverable
- [ ] Public repo with README (use `_shared/templates/PROJECT-README-template.md`)
- [ ] Architecture diagram
- [ ] `RUNBOOK.md` — how to start, stop, back up, restore, and debug it
- [ ] Image size before/after table with real numbers
- [ ] A **"What broke"** section with at least three genuine entries
