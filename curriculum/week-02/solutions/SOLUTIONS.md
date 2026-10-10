# Week 2 Solutions

---

## Lab 1 — systemd

### The service unit

```ini
# /etc/systemd/system/webapp.service
[Unit]
Description=Lab web application
Documentation=https://github.com/you/webapp
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=webapp
Group=webapp
WorkingDirectory=/opt/webapp
Environment=PORT=8080
Environment=PYTHONUNBUFFERED=1
ExecStart=/usr/bin/python3 /opt/webapp/app.py

Restart=on-failure
RestartSec=5s
StartLimitIntervalSec=60
StartLimitBurst=3

# --- hardening: each line removes a capability the app doesn't need ---
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictAddressFamilies=AF_INET AF_INET6
RestrictNamespaces=true
LockPersonality=true
MemoryDenyWriteExecute=true
ReadWritePaths=/var/log/webapp

StandardOutput=journal
StandardError=journal
SyslogIdentifier=webapp

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload        # REQUIRED after every unit edit
sudo systemctl enable --now webapp
systemctl status webapp
curl -s localhost:8080 | jq
systemd-analyze security webapp     # scores your hardening 0-10
```

### Notes on the choices

**`PYTHONUNBUFFERED=1`** — without it Python buffers stdout when it isn't a TTY, so your logs appear
in journald minutes late or not at all when the process is killed. This bites people constantly, in
systemd **and in containers**.

**`Restart=on-failure` + `StartLimitBurst`** — restart on crash, but give up after 3 failures in 60
seconds so a genuinely broken app doesn't spin forever. Note the parallel to Kubernetes
`CrashLoopBackOff`: same problem, same solution shape.

**`ProtectSystem=strict`** makes the entire filesystem read-only except `/dev`, `/proc`, `/sys` — so
you must whitelist writable paths with `ReadWritePaths`. **This is the same principle as
`readOnlyRootFilesystem: true` in a Kubernetes pod spec** (week 18).

**`Type=simple` vs `Type=notify` vs `Type=forking`** — `simple` means systemd considers the service
started the moment it forks the process, which can be *before* it's actually listening. `notify`
(the app calls `sd_notify`) is accurate. This is the same gap that `readinessProbe` fills in
Kubernetes.

**Restart it and watch:**
```bash
sudo pkill -f app.py
journalctl -u webapp -f          # watch systemd bring it back after RestartSec
```

### Timer vs cron — the answer to give in an interview

| | cron | systemd timer |
|---|---|---|
| Logging | You redirect it yourself, or output vanishes | journald, automatically, with unit context |
| Missed runs | Lost | `Persistent=true` catches up after downtime |
| Dependencies | None | `After=`, `Requires=` |
| Environment | Nearly empty — the #1 cron bug (BF-07) | Explicit `Environment=` |
| Visibility | `crontab -l` | `systemctl list-timers` shows last and next run |
| Resource limits | None | Full cgroup controls |
| Randomization | Manual | `RandomizedDelaySec` (avoids thundering herd) |

```bash
systemd-analyze calendar "*-*-* 02:00:00"    # → next elapse: ...
systemd-analyze calendar "Mon..Fri 09:00"
```

---

## Lab 2 — SSH and disks

### The hardening that matters, ranked

1. **`PasswordAuthentication no`** — kills brute force entirely. Everything else is secondary.
2. **`PermitRootLogin no`** — forces an audit trail; attackers must guess a username too.
3. **`AllowUsers` / `AllowGroups`** — explicit allow-list.
4. `MaxAuthTries 3` — limits per-connection attempts.
5. `ClientAliveInterval` — reaps dead sessions.

Do **not** bother with a non-standard port as a security measure — it stops log noise, not
attackers, and it breaks tooling. Say that if asked; it shows you distinguish security from
security theater.

### Diagnosing `ssh -vvv`

```bash
ssh -vvv user@host 2>&1 | grep -E 'debug1: (Offering|Authentications|Next auth)'
# debug1: Offering public key: /home/u/.ssh/id_ed25519
# debug1: Authentications that can continue: publickey,password   <- key was REJECTED
```
Server side: `sudo journalctl -u ssh -n 30` → `Authentication refused: bad ownership or modes for
directory /home/u/.ssh`.

**Fix:** `chmod 700 ~/.ssh; chmod 600 ~/.ssh/authorized_keys; chown -R $USER:$USER ~/.ssh`

### SSH tunnels

```bash
ssh -L 9090:localhost:8080 lab      # LOCAL forward: your :9090 -> lab's :8080
ssh -R 9090:localhost:8080 lab      # REMOTE forward: lab's :9090 -> your :8080
ssh -D 1080 lab                     # DYNAMIC: SOCKS proxy through lab
ssh -J bastion private-host         # ProxyJump
```
Local forwarding is how you reach a private RDS instance through a bastion, and it is the manual
version of `kubectl port-forward`.

### Inode exhaustion

```bash
sudo mkfs.ext4 -N 1024 /dev/loop0     # only 1024 inodes
sudo mount /dev/loop0 /mnt/labdisk
cd /mnt/labdisk && for i in $(seq 1 2000); do touch "f$i" 2>/dev/null; done
df -h /mnt/labdisk    # plenty of SPACE free
df -i /mnt/labdisk    # IUse% = 100%
touch newfile         # "No space left on device"
```
**This is BF-08 with a real filesystem.** The error message lies — it says "no space" and `df -h`
disagrees. `df -i` is the answer.

---

## Lab 3 — Subnetting

Full answer key is in `_shared/drills/subnetting.md`. Here is the Part 3 VPC design.

### `10.40.0.0/16` — three AZs, three tiers, 50%+ free

The binding requirement is **2,000 pods per AZ in private-app**. EKS with the VPC CNI assigns each
pod a real subnet IP, so 2,000 pods + nodes + headroom means at least 2,048 → with 5 AWS-reserved
addresses you need a `/20` (4,091 usable), which gives 2× headroom.

| Subnet | CIDR | Usable | Purpose |
|---|---|---|---|
| public-a | 10.40.0.0/24 | 251 | NAT GW, ALB |
| public-b | 10.40.1.0/24 | 251 | NAT GW, ALB |
| public-c | 10.40.2.0/24 | 251 | NAT GW, ALB |
| data-a | 10.40.3.0/24 | 251 | RDS |
| data-b | 10.40.4.0/24 | 251 | RDS |
| data-c | 10.40.5.0/24 | 251 | RDS |
| *(reserved)* | 10.40.6.0/23 | — | future small subnets |
| app-a | 10.40.16.0/20 | 4,091 | EKS nodes + pods |
| app-b | 10.40.32.0/20 | 4,091 | EKS nodes + pods |
| app-c | 10.40.48.0/20 | 4,091 | EKS nodes + pods |
| **free** | **10.40.64.0/18 + 10.40.128.0/17** | **~49,000** | **75% of the VPC unallocated** |

### The reasoning to be able to state out loud

**Public subnets are deliberately small.** They hold a NAT gateway and load balancer ENIs — a handful
of addresses. Giving them a `/20` wastes 4,000 IPs. Beginners size all subnets equally; sizing them
to purpose is the signal.

**App subnets are deliberately large,** because with the AWS VPC CNI **every pod consumes a subnet
IP**. This is the #1 way people run out of addresses on EKS, and re-CIDRing a live VPC is
extremely painful. (Prefix delegation and custom networking mitigate it, but plan for the simple
case.)

**Aligning app subnets to /20 boundaries at 16, 32, 48** keeps the math trivial and the Terraform
`for_each` clean.

**The free space is the real design decision.** A VPC CIDR cannot be shrunk and overlapping CIDRs
make peering impossible forever. Reserving 75% costs nothing — addresses are free — and buys you
the ability to add an environment, a TGW attachment, or a second cluster later.

---

## Lab 4 — TCP/IP and DNS

### Reading a tcpdump handshake

```
10:14:02.103 IP 10.0.0.5.54321 > 93.184.216.34.80: Flags [S],  seq 1234567, win 64240
10:14:02.148 IP 93.184.216.34.80 > 10.0.0.5.54321: Flags [S.], seq 7654321, ack 1234568
10:14:02.148 IP 10.0.0.5.54321 > 93.184.216.34.80: Flags [.],  ack 7654322
10:14:02.149 IP 10.0.0.5.54321 > 93.184.216.34.80: Flags [P.], length 78: HTTP: GET / HTTP/1.1
10:14:02.194 IP 93.184.216.34.80 > 10.0.0.5.54321: Flags [P.], length 1440: HTTP/1.1 200 OK
10:14:02.195 IP 10.0.0.5.54321 > 93.184.216.34.80: Flags [F.], ...
```

| Flag | Meaning |
|---|---|
| `[S]` | SYN |
| `[S.]` | SYN-ACK (the `.` is the ACK bit) |
| `[.]` | ACK only |
| `[P.]` | PSH+ACK — data |
| `[F.]` | FIN+ACK — graceful close |
| `[R]` | RST — **abrupt reset.** Usually "nothing is listening on that port" or a firewall rejecting. |

**The RTT is visible:** SYN at `.103`, SYN-ACK at `.148` → 45 ms round trip. Being able to read
latency straight out of a capture is a genuinely useful skill.

**`[R]` vs a timeout, in one line:** RST means something actively refused you (closed port, or a
REJECT firewall rule). A timeout with no reply means a DROP rule or a black hole — the packet
vanished. Different causes, different fixes.

### `dig +trace` hops

```
.           NS a.root-servers.net.          <- 1. root: "ask the .com servers"
com.        NS a.gtld-servers.net.          <- 2. TLD:  "ask example.com's servers"
example.com NS a.iana-servers.net.          <- 3. authoritative delegation
example.com A  93.184.216.34                <- 4. the answer
```
`+trace` starts from the root and follows delegations itself, ignoring your resolver's cache — which
is why it's the tool for "DNS is returning stale/wrong data."

**TTL decreasing on a repeat query** proves you got a cached answer: the resolver counts down the
remaining lifetime. A full-TTL answer means it was fetched fresh.

### The `curl -w` timing breakdown

```
dns:      0.004s        <- resolution
connect:  0.048s        <- + TCP handshake (so TCP took 44ms)
tls:      0.121s        <- + TLS handshake (TLS took 73ms)
ttfb:     0.168s        <- + server think time (server took 47ms)
total:    0.171s        <- + transfer
```
Each number is cumulative, so subtract to get each phase. **This instantly tells you whether "the
site is slow" is DNS, network, TLS, or the application** — and it's a two-second answer to a
question that otherwise turns into an hour of guessing.

---

## Lab 5 — Break/Fix

Full walkthroughs in `_shared/breakfix/`:
BF-05 and BF-06 and BF-07 in `01-linux.md`, BF-11 in `02-networking.md`.

**The pattern to notice across all four:** in every case the *error message was not the problem*.
"Job failed" didn't say the binary was missing. "Permission denied" didn't say the directory mode
was wrong. "Network is unreachable" was DNS. **Reading the error and then looking one layer deeper
is the entire skill.**
