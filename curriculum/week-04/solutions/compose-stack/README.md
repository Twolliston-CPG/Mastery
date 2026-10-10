# Week 4 Deliverable — Compose Stack (reference solution)

Nginx (TLS) → Flask/gunicorn → Postgres, with healthchecks, a named volume, a non-root app user,
a read-only root filesystem, and an internal-only database network.

## Run it

```bash
cp .env.example .env      # edit the password
make up
make verify               # proves every acceptance criterion
make down                 # keeps data
make clean                # deletes data
```

## What to study here

| File | The lesson |
|---|---|
| `compose.yaml` | `condition: service_healthy` — the difference between "started" and "ready" |
| `compose.yaml` | `networks.backend.internal: true` — the DB has no route off the compose network |
| `Dockerfile` | multi-stage, numeric UID, exec-form ENTRYPOINT |
| `app.py` | `/health` vs `/ready` — liveness must not check dependencies (BF-44) |
| `nginx.conf` | `X-Forwarded-For`, and 502-vs-504 timeouts |
| `Makefile` | `verify` — an acceptance test you can actually run |

Full explanation in [`../SOLUTIONS.md`](../SOLUTIONS.md).
