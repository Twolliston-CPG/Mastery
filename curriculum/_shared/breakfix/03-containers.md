# Break/Fix: Containers (BF-19 – BF-24)

---

## BF-19 — Container exits immediately

**SYMPTOM:** `docker run myapp` returns instantly. `docker ps` shows nothing. `docker ps -a` shows
`Exited (0)`.

**BREAK:** `FROM alpine` with `CMD ["echo","hello"]`, or a service started in background.

**DIAGNOSIS:**
```bash
docker ps -a                       # exit code is the first clue
docker logs <container>
docker inspect <container> --format '{{.State.ExitCode}} {{.Config.Cmd}} {{.Config.Entrypoint}}'
docker run -it --entrypoint sh myapp     # get in and look around
```

**EXIT CODE DECODER:**
| Code | Meaning |
|---|---|
| 0 | Main process finished normally — your CMD isn't long-running |
| 1 | Application error — read the logs |
| 125 | Docker daemon error (bad flag) |
| 126 | Command found but not executable |
| 127 | Command not found — usually a missing binary in a slim/distroless base |
| 137 | SIGKILL — **almost always OOM**, check `docker inspect` for `OOMKilled: true` |
| 139 | SIGSEGV — segfault |
| 143 | SIGTERM — graceful stop |

**ROOT CAUSE (exit 0):** A container lives exactly as long as PID 1. If your CMD starts a daemon in
the background and returns, the container exits. **Run the process in the foreground.**

**137 IS THE ONE TO MEMORIZE.** "Container keeps dying with 137" → out of memory → raise the limit or
fix the leak. It maps directly to Kubernetes `OOMKilled` in week 15.

---

## BF-20 — Can't reach the container

**SYMPTOM:** `docker run -p 8080:8080 myapp` starts fine, but `curl localhost:8080` refuses.

**BREAK:** App binds to `127.0.0.1:8080` inside the container.

**DIAGNOSIS:**
```bash
docker port <container>
docker exec <container> ss -tlnp       # what address is it bound to INSIDE?
# 127.0.0.1:8080  <-- the bug
docker exec <container> curl -s localhost:8080   # works inside, fails outside
```

**ROOT CAUSE:** `127.0.0.1` inside a container is the *container's* loopback. The port forward
targets the container's external interface, where nothing is listening.

**FIX:** Bind `0.0.0.0` in the application config.

**THIS IS THE SINGLE MOST COMMON CONTAINER NETWORKING BUG.** It reappears identically in Kubernetes.
Being able to say "bind 0.0.0.0, not localhost, and here's why" is a fast credibility win.

---

## BF-21 — Data lost on restart

**SYMPTOM:** Database contents vanish every time the container restarts.

**DIAGNOSIS:**
```bash
docker inspect <container> --format '{{json .Mounts}}' | jq
docker volume ls
```

**ROOT CAUSE:** No volume. The container's writable layer is destroyed with the container.

**FIX:**
```bash
docker run -v pgdata:/var/lib/postgresql/data postgres:16
```

**NAMED VOLUME vs BIND MOUNT:** Named volumes are managed by Docker, portable, and correct for
databases. Bind mounts map a host path and are right for source code in development. Using a bind
mount for a database on macOS/Windows is also a well-known performance trap.

---

## BF-22 — Image is 1.2 GB

**SYMPTOM:** Builds are slow, pushes are slow, the scanner reports 200+ CVEs.

**DIAGNOSIS:**
```bash
docker images                          # confirm the size
docker history myapp:latest            # WHICH LAYER is huge?
dive myapp:latest                      # interactive layer explorer
trivy image myapp:latest | head -30
```

**ROOT CAUSES:**
1. Full OS base image (`ubuntu`, `node`) instead of slim/alpine/distroless
2. Build toolchain shipped in the final image — no multi-stage build
3. Package manager cache not cleaned **in the same layer** as the install
4. `COPY . .` dragging in `.git`, `node_modules`, test fixtures — no `.dockerignore`

**FIX — multi-stage:**
```dockerfile
FROM golang:1.22 AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o /app ./cmd/server

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /app /app
USER nonroot:nonroot
ENTRYPOINT ["/app"]
```
1.2 GB → ~15 MB, and the CVE count drops to near zero because there is no shell and no OS packages.

**RECORD THE BEFORE/AFTER NUMBERS.** They go straight in your project README and your interview
answers.

---

## BF-23 — Layer cache always misses

**SYMPTOM:** Every build re-downloads all dependencies. 8-minute builds for a one-line change.

**DIAGNOSIS:** Look at the Dockerfile ordering.

**ROOT CAUSE:**
```dockerfile
COPY . .                    # <-- invalidates on ANY file change
RUN npm install             # <-- therefore always re-runs
```

**FIX — copy the dependency manifest first:**
```dockerfile
COPY package.json package-lock.json ./
RUN npm ci                  # cached unless dependencies actually changed
COPY . .                    # source changes only invalidate from here down
```

**THE RULE:** Order Dockerfile instructions from **least likely to change** to **most likely to
change**. A cache-friendly Dockerfile is a visible sign of someone who has waited on real builds.

---

## BF-24 — Container can't resolve DNS

**SYMPTOM:** `curl https://api.example.com` from inside the container fails to resolve; the host
resolves it fine.

**DIAGNOSIS:**
```bash
docker exec <c> cat /etc/resolv.conf
docker exec <c> nslookup api.example.com
docker network inspect bridge
docker exec <c> nslookup <other-container-name>
```

**ROOT CAUSES:**
1. On the **default bridge** network there is no DNS-based service discovery — containers can only
   reach each other by IP or legacy `--link`. **User-defined networks have an embedded DNS server
   at 127.0.0.11 that resolves container names.** This is why Compose "just works."
2. Host VPN or corporate resolver isn't reachable from the container's netns
3. `--network=none`

**FIX:** Use a user-defined network: `docker network create appnet && docker run --network appnet ...`

**THIS EXPLAINS COMPOSE.** Compose creates a user-defined network, which is why `postgres` resolves
as a hostname from your app container. Knowing the mechanism — not just that it works — is the
difference between using Docker and understanding it.
