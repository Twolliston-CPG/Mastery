# Week 4 Solutions

Working code: [`compose-stack/`](compose-stack/)

---

## Lab 3 — What a container actually is

### The namespace proof

```bash
sudo ls -l /proc/$(docker inspect demo --format '{{.State.Pid}}')/ns/
# net -> net:[4026532567]
ls -l /proc/self/ns/
# net -> net:[4026531840]      <- different ID = different network stack
```

| Namespace | Isolates |
|---|---|
| `pid` | Process IDs — the container's main process sees itself as PID 1 |
| `net` | Interfaces, routing table, iptables, ports |
| `mnt` | Mount points — the container's filesystem view |
| `uts` | Hostname and domain name |
| `ipc` | Shared memory, semaphores |
| `user` | UID/GID mapping — root in the container ≠ root on the host (when enabled) |
| `cgroup` | The cgroup root the process sees |

**cgroups** are the other half: they limit what a process can *consume* — CPU shares, memory, I/O,
PIDs. Namespaces = visibility. cgroups = consumption.

### The sentence to have ready for an interview

> "A container isn't a lightweight VM — it's a normal Linux process whose visibility is restricted by
> namespaces and whose resource consumption is capped by cgroups. It shares the host kernel, which
> is why it starts in milliseconds instead of seconds, and also why the isolation is weaker than a
> VM's — a kernel vulnerability crosses the boundary."

That single answer explains images-as-layers, why a container dies when PID 1 dies, why `OOMKilled`
happens, and why you can't run a different kernel in a container.

### Why the default bridge has no DNS

Docker's embedded DNS server (at `127.0.0.11` inside the container) is only attached to
**user-defined** networks. The default `bridge` network predates it and keeps legacy `--link`
behavior for compatibility.

**Always create a user-defined network.** Compose does it for you automatically — which is the entire
reason `postgres` resolves as a hostname from your app container. (BF-24)

---

## Lab 4 — The Dockerfile progression

### The numbers (Debian-based Python app; yours will differ slightly)

| Version | Size | HIGH+CRITICAL CVEs | Build time (code change) |
|---|---|---|---|
| v1 naive `python:3.12` | ~1.02 GB | ~45 | 95 s |
| v2 `python:3.12-slim` + `.dockerignore` | ~210 MB | ~12 | 62 s |
| v3 multi-stage venv | ~155 MB | ~8 | **4 s** (cached) |
| v4 non-root + read-only + healthcheck | ~155 MB | ~8 | 4 s |
| v5 distroless (Go/static equivalent) | ~20 MB | **0–2** | 3 s |

**Record your own numbers.** "I reduced the image from 1.02 GB to 155 MB and HIGH/CRITICAL CVEs from
45 to 8" is a concrete, memorable interview line. A vague "I optimized the Dockerfile" is not.

### v2 — slim base, correct layer order

```dockerfile
FROM python:3.12-slim
WORKDIR /app

# Dependencies FIRST -- this layer is cached unless requirements.txt changes
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Source LAST -- a code change only invalidates from here down
COPY . .

CMD ["gunicorn", "-b", "0.0.0.0:8080", "-w", "2", "app:app"]
```

```
# .dockerignore
.git
.gitignore
__pycache__
*.pyc
.venv
.pytest_cache
tests/
*.md
.env
```

**`--no-cache-dir`** stops pip keeping a wheel cache in the image — free savings.
**`.dockerignore`** is what stops `COPY . .` dragging in your `.git` directory (BF-22). It also
stops you accidentally baking a `.env` file into a published image, which is a real leak vector.

### v3 — multi-stage

```dockerfile
FROM python:3.12-slim AS builder
WORKDIR /app
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

FROM python:3.12-slim
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1
WORKDIR /app
COPY app.py .
CMD ["gunicorn", "-b", "0.0.0.0:8080", "-w", "2", "app:app"]
```

The build stage may install `gcc` and `libpq-dev`; **none of that reaches the final image** because
only `/opt/venv` is copied forward. That's the whole point of multi-stage.

**`PYTHONUNBUFFERED=1`** again — without it your container logs are buffered and appear late or are
lost entirely when the container is killed. Exactly the same trap as the systemd unit in week 2.

### v4 — the production version

```dockerfile
FROM python:3.12-slim AS builder
WORKDIR /app
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

FROM python:3.12-slim

RUN groupadd -r app --gid 10001 && \
    useradd -r -g app --uid 10001 --no-log-init --create-home app

COPY --from=builder --chown=app:app /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PORT=8080

WORKDIR /app
COPY --chown=app:app app.py .

USER app:app
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8080/health').status==200 else 1)"

ENTRYPOINT ["gunicorn"]
CMD ["-b", "0.0.0.0:8080", "-w", "2", "--access-logfile", "-", "app:app"]
```

Run it read-only:
```bash
docker run -d --name demo-v4 \
  --read-only --tmpfs /tmp \
  --cap-drop=ALL --security-opt=no-new-privileges \
  -p 8080:8080 demo:v4
docker exec demo-v4 whoami          # app
docker exec demo-v4 touch /x        # Read-only file system
```

### Why a numeric UID matters

`USER app` works in Docker because Docker resolves the name from the image's `/etc/passwd`. But
Kubernetes `runAsNonRoot: true` **cannot verify a username** — it needs a numeric UID to check. So
set the UID explicitly (`--uid 10001`) and, in Kubernetes, set `runAsUser: 10001`. Otherwise the pod
is rejected with "container has runAsNonRoot and image has non-numeric user."

That's a week-18 problem you're solving now.

### ENTRYPOINT vs CMD

| Form | Behavior |
|---|---|
| `ENTRYPOINT ["x"]` + `CMD ["a"]` | Runs `x a`. `docker run img b` → `x b`. **Use this.** |
| `CMD ["x","a"]` only | `docker run img b` → runs `b`, replacing everything |
| Shell form `CMD x a` | Wrapped in `/bin/sh -c`, so **your process is not PID 1** and does not receive SIGTERM |

**The shell form is a real bug**, not a style preference: signals go to the shell, not your app, so
graceful shutdown silently stops working. Always use the exec (JSON array) form.

### Layer cache proof (BF-23)

```bash
# deps-last (wrong)
time docker build -f Dockerfile.bad -t bad .     # 62s
touch app.py && time docker build -f Dockerfile.bad -t bad .    # 58s -- reinstalls everything

# deps-first (right)
time docker build -f Dockerfile.v3 -t good .     # 64s
touch app.py && time docker build -f Dockerfile.v3 -t good .    # 4s
```

---

## Lab 6 — The Compose stack

Complete working files in [`compose-stack/`](compose-stack/):
`compose.yaml`, `Dockerfile`, `nginx.conf`, `.env.example`, `Makefile`.

### The three things worth studying

**1. `depends_on` with `condition: service_healthy`**
```yaml
depends_on:
  db:
    condition: service_healthy
```
Plain `depends_on` only waits for the container to *start*, not to be *ready*. Postgres takes several
seconds to accept connections after its container starts, so without the health condition your app
crashes on boot, restarts, and eventually succeeds — which looks like flakiness and is actually a
race you wrote. **This is the exact same problem `readinessProbe` and init containers solve in
Kubernetes.**

**2. `read_only: true` + `tmpfs`**
```yaml
read_only: true
tmpfs:
  - /tmp
```
The container filesystem is immutable; only `/tmp` is writable, and it's in memory. If an attacker
achieves code execution they cannot write a payload to disk. Anything that legitimately needs to
write gets an explicit volume.

**3. Secrets are not baked in**
```yaml
environment:
  POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:?set in .env}
```
The `:?` makes Compose fail loudly if it's unset, rather than starting with an empty password.
`.env` is gitignored; `.env.example` is committed with placeholder values.

**Note the limitation, and say it in an interview:** environment variables are visible in
`docker inspect` and in `/proc/<pid>/environ`. For a lab that's fine. In production you use Docker
secrets, or a secrets manager — which is exactly what External Secrets does in week 16.

### Verify the deliverable

```bash
docker compose up -d
docker compose ps                  # all three "healthy"
curl -k https://localhost/         # through nginx TLS
docker compose exec app whoami     # app, not root
docker compose exec db psql -U app -c "CREATE TABLE t(i int); INSERT INTO t VALUES (1);"
docker compose down                # NOT -v
docker compose up -d && sleep 5
docker compose exec db psql -U app -c "SELECT * FROM t;"   # row survives
docker compose down -v             # now it's gone -- that's what -v means
```

**`docker compose down` vs `down -v`** is worth internalizing: `-v` deletes named volumes. Running
it on production data is a career-defining mistake, and it's why `prevent_destroy` exists in
Terraform (week 11).
