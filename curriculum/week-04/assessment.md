# ★ GATE 1 — Month 1 Assessment

> **This is a gate, not a quiz.** Passing is demonstrated, not self-assessed.
> Failing means spend one extra week and re-test. Do **not** advance to AWS on a broken foundation.

---

## Part 1 — The practical (90 min, timed)

**Setup:** a *fresh* Linux VM. Delete your lab VM and create a new one, or restore the `clean`
snapshot. You may use `man` pages and official documentation. **No tutorials, no blog posts, no
copying from your own previous labs.**

### The task

From nothing, produce a running system where:

1. Docker is installed and working
2. Your Compose stack (app + Postgres + Nginx) is deployed
3. Nginx terminates TLS with a certificate you generate
4. The whole stack is managed by a **systemd unit** so it survives a reboot
5. The host firewall allows only 22, 80, and 443
6. The app runs as non-root with a read-only root filesystem
7. Postgres data survives `reboot`

### Then, out loud, without notes

**Trace the full path of a request** from a browser on your laptop to the Python process and back:

> DNS resolution → TCP handshake → TLS handshake → nginx accepts → nginx proxies to the app
> container → Docker's user-defined network resolves `app` → gunicorn worker → Flask route →
> psycopg2 to `db` → response back up every layer.

Name at every hop: **what could break here, and what command would show me?**

### Pass conditions
- [ ] Completed in 90 minutes
- [ ] `curl -k https://<vm-ip>/` returns the app's JSON
- [ ] `sudo reboot` — everything comes back with no manual steps
- [ ] `docker compose exec app id` shows a non-root UID
- [ ] Database row written before the reboot is still there after
- [ ] `ss -tlnp` shows only 22, 80, 443 listening externally
- [ ] You narrated the full request path without notes

---

## Part 2 — Subnetting, no calculator (15 min)

All ten, on paper.

1. `10.0.0.0/19` — total addresses, AWS-usable
2. `192.168.10.128/26` — network, broadcast, first and last usable
3. Smallest AWS subnet for 250 instances
4. Split `172.16.0.0/16` into 4 — list all four
5. `10.8.192.0/18` — the address range
6. Do `10.2.0.0/16` and `10.2.64.0/18` overlap?
7. How many `/24` subnets fit in a `/16`?
8. You need 3 subnets of 8,000 hosts each from `10.50.0.0/16` — prefix and the first three
9. Why can't two VPCs with `10.0.0.0/16` be peered?
10. `cidrsubnet("10.0.0.0/16", 4, 5)` → ?

**Pass: 9/10 in 15 minutes.**

---

## Part 3 — Written (30 min)

11. What is a container? Answer in a way that explains why it starts in milliseconds and why its
    isolation is weaker than a VM's.
12. Explain namespaces vs cgroups. Name three namespaces and what each isolates.
13. Docker exit codes 0, 1, 127, 137. What does each mean and what do you check?
14. Why does a container die immediately when its CMD starts a daemon in the background?
15. Your app is bound to `127.0.0.1:8080` inside a container with `-p 8080:8080`. Why can't you
    reach it?
16. Explain the difference between `/health` and `/ready` endpoints, and give the concrete production
    disaster that results from getting it wrong.
17. `ENTRYPOINT ["x"]` vs `CMD x` (shell form) — what actually breaks with the shell form?
18. Why does `USER app` work in Docker but fail Kubernetes' `runAsNonRoot`?
19. Your image is 1.2 GB. List four causes and the fix for each.
20. You changed one line of application code and the build reinstalled every dependency. Why, and
    what is the fix?

---

# Answer key

**Part 2:**
1. 8,192 total / **8,187 usable**
2. net `192.168.10.128`, bcast `192.168.10.191`, first `.129`, last `.190`
3. 250 + 5 = 255 → 256 → **`/24`**
4. `/18` each: `172.16.0.0/18`, `172.16.64.0/18`, `172.16.128.0/18`, `172.16.192.0/18`
5. `10.8.192.0` – `10.8.255.255`
6. **Yes** — the `/18` is inside the `/16`
7. **256**
8. 8,000 + 5 → 8,192 → **`/19`**: `10.50.0.0/19`, `10.50.32.0/19`, `10.50.64.0/19`
9. Peering has no NAT; identical CIDRs make routes ambiguous. Re-CIDR one, or use TGW with NAT.
10. `10.0.80.0/20` (4 added bits → /20; block size 16; 5 × 16 = 80)

**Part 3:**

**11.** A normal Linux process whose visibility is restricted by namespaces and whose resource
consumption is capped by cgroups. It shares the host kernel — hence millisecond startup (no kernel
to boot, no hardware to emulate) and hence weaker isolation (a kernel vulnerability crosses the
boundary; a VM has a hypervisor in between).

**12.** **Namespaces = what a process can see. cgroups = what it can use.** `pid` (process IDs — it
sees itself as PID 1), `net` (interfaces, routes, iptables, ports), `mnt` (filesystem view); also
`uts`, `ipc`, `user`, `cgroup`.

**13.** **0** — main process finished normally; your CMD isn't long-running. **1** — application
error; read the logs. **127** — command not found, usually a missing binary in a slim/distroless
base. **137** — SIGKILL (128+9), **almost always the OOM killer**; confirm with
`docker inspect --format '{{.State.OOMKilled}}'`.

**14.** A container lives exactly as long as PID 1. If CMD starts a daemon and returns, PID 1 exits
and the container stops — with exit code 0, which makes it look like success. Run the process in the
foreground.

**15.** `127.0.0.1` inside the container is the *container's* loopback, a separate network namespace.
The port publish forwards to the container's external interface, where nothing is listening. Bind
`0.0.0.0`. (BF-20 — and it recurs identically in Kubernetes.)

**16.** `/health` (liveness) answers "is this process alive?" — failure restarts the container.
`/ready` (readiness) answers "should I get traffic?" — failure removes it from the load balancer
without restarting. **The disaster:** put a database check in liveness, and a brief DB blip fails
liveness on *every replica simultaneously*, restarting the entire fleet and hammering the recovering
database with reconnections. A five-second blip becomes a full outage. (BF-44)

**17.** Shell form wraps the command in `/bin/sh -c`, so **the shell is PID 1 and your application is
its child**. SIGTERM goes to the shell, which doesn't forward it, so your app never shuts down
gracefully — it gets SIGKILLed after the grace period on every single deploy, dropping in-flight
requests. Always use the exec (JSON array) form.

**18.** Docker resolves the username from the image's `/etc/passwd` at runtime. Kubernetes'
`runAsNonRoot: true` admission check happens **before** the container starts and cannot read the
image's passwd file, so it can only verify a numeric UID. A username-only `USER` fails with
"container has runAsNonRoot and image has non-numeric user." Set an explicit numeric UID.

**19.** (1) Full OS base — use slim/alpine/distroless. (2) Build toolchain in the final image — use
multi-stage. (3) Package cache not cleaned in the same layer — `--no-cache-dir`, or
`rm -rf /var/lib/apt/lists/*` in the same `RUN`. (4) `COPY . .` dragging in `.git`, `node_modules`,
test fixtures — add a `.dockerignore`.

**20.** `COPY . .` sits **above** the dependency install, so any source change invalidates that layer
and every layer below it, including the install. Fix: copy only the dependency manifest, install,
*then* copy source. **Order instructions from least-likely-to-change to most-likely-to-change.**

---

## ★ Gate 1 result

| | |
|---|---|
| **PASS** | Part 1 completed in 90 min + 9/10 on Part 2 + 16/20 on Part 3 → **start week 5** |
| **NEAR** | Part 1 passed but slow, or 7–8 on Part 2 → **2 extra days** on the weak area, re-test Part 2 |
| **FAIL** | Part 1 not completed, or < 7 on Part 2 → **one extra week.** Redo weeks 2 and 4 labs. |

**Be honest here.** Month 2's AWS material assumes every one of these. Subnetting in particular is
load-bearing for weeks 6, 7, 13, and 16 — a weak foundation does not get stronger by being built on.

---

## Month 1 retrospective (write this, Sunday)

In `progress/progress.md`:

1. **Hours actually logged** vs the 4–8/day target. Be honest — this number predicts everything.
2. **The 70/30 ratio** — what fraction of your time was actually hands-on keyboard?
3. **Top 3 "Surprised" lines** from the incident journal. These are your first interview stories.
4. **Weakest area** — and what specifically you will do about it in month 2.
5. **Sustainability check** — did you take a rest day every week? If not, fix that now. Week 15 is
   where people burn out, and it is caused by weeks 1–4.
