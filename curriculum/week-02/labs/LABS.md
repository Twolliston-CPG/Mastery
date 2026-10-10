# Week 2 Labs

---

# Lab 1 — systemd: Services and Timers (3h)

## Part 1 — Anatomy of a unit

```bash
systemctl list-units --type=service --state=running
systemctl status ssh
systemctl cat ssh                # the EFFECTIVE unit, including drop-ins
systemctl show ssh | head -30    # every property
systemd-analyze blame | head -10 # what's slowing down boot
systemd-analyze critical-chain
```

> **Arch path:** the unit is `sshd`, not `ssh` — here and everywhere else in this week.

## Part 2 — Write a real service

Build a tiny HTTP service and run it properly under systemd.

```bash
sudo mkdir -p /opt/webapp
sudo tee /opt/webapp/app.py >/dev/null <<'PY'
#!/usr/bin/env python3
import http.server, socketserver, os, signal, sys, json, datetime

PORT = int(os.environ.get("PORT", "8080"))
_healthy = True

class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/health":
            code = 200 if _healthy else 503
            body = json.dumps({"status": "ok" if _healthy else "degraded"})
        else:
            code = 200
            body = json.dumps({"time": datetime.datetime.utcnow().isoformat(),
                               "path": self.path, "pid": os.getpid()})
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(body.encode())
    def log_message(self, fmt, *a):
        sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % a))

def on_term(signum, frame):
    # Handle SIGTERM properly -- this is what Kubernetes will send you in week 15
    sys.stderr.write("SIGTERM received, shutting down cleanly\n")
    sys.exit(0)

signal.signal(signal.SIGTERM, on_term)
sys.stderr.write(f"listening on 0.0.0.0:{PORT}\n")
with socketserver.TCPServer(("0.0.0.0", PORT), H) as srv:
    srv.serve_forever()
PY
sudo chmod +x /opt/webapp/app.py
sudo useradd -r -s /usr/sbin/nologin webapp || true
sudo chown -R webapp:webapp /opt/webapp
```

**Tasks:**
1. Write `/etc/systemd/system/webapp.service`. It must:
   - run as the `webapp` user (never root)
   - set `PORT=8080` via `Environment=`
   - restart on failure with a backoff
   - apply hardening: `NoNewPrivileges`, `PrivateTmp`, `ProtectSystem=strict`,
     `ProtectHome`, `ReadWritePaths` only where needed
   - log to journald
2. `daemon-reload`, `enable --now`, verify with `curl localhost:8080`
3. `kill` the process and watch systemd restart it
4. Break `ExecStart` deliberately and read the failure (BF-05)

## Part 3 — Timers

Convert last week's `sysreport.sh` to a timer (the unit files are in week 1's
`solutions/lab-04-solution.md`).

```bash
systemctl list-timers --all
journalctl -u sysreport.service --since "1 hour ago"
systemd-analyze calendar "*-*-* 02:00:00"       # verify a schedule expression
systemd-analyze calendar "Mon..Fri 09:00"
```

## Part 4 — journald

```bash
journalctl -u webapp -f                    # follow
journalctl -u webapp --since "10 min ago"
journalctl -p err -b                       # errors this boot
journalctl -b -1                           # previous boot
journalctl -u webapp -o json-pretty | head -30
journalctl --disk-usage
sudo journalctl --vacuum-time=7d
```

**Make journald persistent** (it isn't by default on some distros — logs vanish on reboot):
```bash
sudo mkdir -p /var/log/journal && sudo systemctl restart systemd-journald
```

---

# Lab 2 — SSH Hardening and Disks (3h)

## Part 1 — SSH keys and config

```bash
ssh-keygen -t ed25519 -C "lab-key" -f ~/.ssh/lab_ed25519
ssh-copy-id -i ~/.ssh/lab_ed25519.pub user@host

cat >> ~/.ssh/config <<'EOF2'
Host lab
    HostName 192.168.64.10
    User ubuntu
    IdentityFile ~/.ssh/lab_ed25519
    IdentitiesOnly yes
    ServerAliveInterval 60

Host bastion
    HostName bastion.example.com
    User ubuntu

Host private-*
    ProxyJump bastion          # <-- jump host. You will use this constantly in AWS.
EOF2
chmod 600 ~/.ssh/config
```

> **Arch path:** the GCP VM has no `192.168.64.10` and no `ubuntu` user — its only SSH door is
> IAP. Use the `Host lab` block from
> [`_setup/DISTRO.md`](../../_setup/DISTRO.md#week-2--ssh-to-the-gcp-vm) instead of the one above.

**`ProxyJump` is the pattern for reaching private-subnet instances through a bastion**, which is
exactly week 6's VPC lab. Learn it here.

## Part 2 — Harden sshd

> **Open a second SSH session and keep it open. Verify the new config with a THIRD session before
> closing either.** This habit will save you at least once.

```bash
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
sudo tee /etc/ssh/sshd_config.d/99-hardening.conf >/dev/null <<'EOF2'
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
ChallengeResponseAuthentication no
X11Forwarding no
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
AllowUsers ubuntu
Protocol 2
LoginGraceTime 30
EOF2

sudo sshd -t                     # VALIDATE FIRST. Always.
sudo systemctl reload ssh        # reload, not restart -- keeps existing sessions
# NOW test from a third terminal before you close anything
```

> **Arch path:** two changes, and the first one locks you out if you miss it. `AllowUsers` must
> name **your** login (`whoami` on the VM), not `ubuntu`. And the reload is
> `sudo systemctl reload sshd`. Take a disk snapshot before this step — see
> [`_setup/DISTRO.md`](../../_setup/DISTRO.md#week-2-warning--allowusers-can-lock-you-out).

**Tasks:**
1. Harden as above, verify from a new session
2. Deliberately break the permissions on `~/.ssh` and diagnose the failure (BF-06)
3. `ssh -vvv` a failing connection and identify where it fails
4. Set up an SSH tunnel: `ssh -L 9090:localhost:8080 lab` then `curl localhost:9090`

## Part 3 — Disks and filesystems

```bash
lsblk -f
df -hT
mount | column -t
cat /etc/fstab

# Create a loopback "disk" to practice safely
sudo dd if=/dev/zero of=/tmp/disk.img bs=1M count=512
sudo losetup -fP /tmp/disk.img
lsblk | grep loop
sudo mkfs.ext4 /dev/loop0
sudo mkdir -p /mnt/labdisk
sudo mount /dev/loop0 /mnt/labdisk
df -h /mnt/labdisk
sudo umount /mnt/labdisk && sudo losetup -d /dev/loop0
```

**Tasks:** fill a filesystem to 100% and recover (BF-01 again, with a real filesystem this time).
Then exhaust its inodes (BF-08) and observe that `df -h` still shows free space.

---

# Lab 3 — Subnetting to Automaticity (3h)

> **This is the highest-return lab in month 1.** Six hours of drilling here pays off in every AWS,
> Kubernetes, and firewall conversation for the rest of your career — and it is visibly impressive
> in an interview because most candidates reach for a calculator.

## Part 1 — Build the mental model (45 min)

```bash
ipcalc 10.0.0.0/20        # install with: apt install ipcalc
sipcalc 10.0.0.0/20       # Arch path: ipcalc is already installed (different output layout); skip sipcalc

python3 -c "
import ipaddress
n = ipaddress.ip_network('10.0.0.0/20')
print('network  ', n.network_address)
print('broadcast', n.broadcast_address)
print('netmask  ', n.netmask)
print('total    ', n.num_addresses)
print('aws usable', n.num_addresses - 5)
"
```

Then **stop using the tools** and do it on paper.

## Part 2 — The 100-problem drill (90 min)

Work every problem in `_shared/drills/subnetting.md`, Sets A, B, and C.
Then generate 80 more with the script at the bottom of that file.

**Rules:** paper and pen, no calculator, target 10 seconds per question. Check with `ipcalc` only
after answering.

## Part 3 — Design a real VPC layout (45 min)

You are given `10.40.0.0/16` for a new environment. Requirements:
- 3 availability zones
- Each AZ needs: public, private-app, private-data
- Public subnets hold only NAT gateways and load balancers (small)
- Private-app must support **EKS**, which consumes one IP per pod — plan for 2,000 pods per AZ
- Private-data holds RDS — small
- **Leave at least 50% of the VPC free for future growth**

Produce a table: subnet name, CIDR, usable IPs, purpose. Then justify each prefix choice in writing.

## Part 4 — Linux networking commands (30 min)

```bash
ip addr show
ip -br addr                     # brief, much more readable
ip route show
ip -s link show                 # interface statistics -- errors and drops matter
ip neigh                        # ARP table

ss -tlnp                        # listening TCP
ss -tan state established
ss -s                           # summary

# The modern tools replace the deprecated ones:
#   ip addr   <- ifconfig
#   ip route  <- route
#   ss        <- netstat
#   ip neigh  <- arp
```

---

# Lab 4 — TCP/IP and DNS with tcpdump (3h)

## Part 1 — Capture a real handshake (60 min)

```bash
sudo tcpdump -ni any -c 20 'tcp port 80 and host example.com' &
curl -s http://example.com > /dev/null
wait
```

**Identify in the output:**
1. The DNS query and response (run a second capture on `port 53`)
2. `[S]` — the SYN
3. `[S.]` — the SYN-ACK
4. `[.]` — the ACK (handshake complete)
5. `[P.]` — data being pushed (the HTTP request)
6. `[F.]` or `[R]` — connection teardown

```bash
# Useful captures
sudo tcpdump -ni any port 53                      # DNS
sudo tcpdump -ni any -A 'tcp port 80'             # ASCII payload
sudo tcpdump -ni any -X 'icmp'                    # hex + ascii
sudo tcpdump -ni any -w /tmp/cap.pcap 'port 443'  # write for Wireshark
sudo tcpdump -ni any 'tcp[tcpflags] & tcp-syn != 0'   # SYNs only
```

## Part 2 — TCP states (30 min)

```bash
ss -tan | awk '{print $1}' | sort | uniq -c
```

| State | Meaning |
|---|---|
| `LISTEN` | Waiting for connections |
| `SYN-SENT` / `SYN-RECV` | Mid-handshake |
| `ESTAB` | Connected |
| `FIN-WAIT-1/2`, `CLOSING`, `LAST-ACK` | Closing |
| `TIME-WAIT` | Waiting out delayed duplicates (~60s) |
| `CLOSE-WAIT` | **The other side closed and your app hasn't.** Piles of these = an application bug. |

**`CLOSE-WAIT` accumulation is a real production symptom** meaning your code isn't closing sockets.
Knowing it is a strong answer.

## Part 3 — DNS (60 min)

```bash
dig example.com
dig example.com +short
dig example.com +trace           # THE full delegation path -- run this and read every hop
dig example.com MX
dig example.com NS
dig -x 8.8.8.8                   # reverse lookup
dig @1.1.1.1 example.com         # ask a specific resolver
dig example.com +norecurse       # is it cached here?

cat /etc/resolv.conf
resolvectl status                # systemd-resolved
resolvectl query example.com
```

**Tasks:**
1. Run `dig +trace` and write down every hop: root → TLD → authoritative
2. Query the same name twice and compare TTLs — explain why the second is lower
3. Break DNS (BF-11) and fix it
4. Find the authoritative nameservers for a domain and query them directly

## Part 4 — HTTP and TLS (30 min)

```bash
curl -v https://example.com 2>&1 | head -40
curl -sI https://example.com
curl -w '@-' -o /dev/null -s https://example.com <<'EOF2'
   dns:      %{time_namelookup}s
   connect:  %{time_connect}s
   tls:      %{time_appconnect}s
   ttfb:     %{time_starttransfer}s
   total:    %{time_total}s
EOF2

echo | openssl s_client -connect example.com:443 -servername example.com 2>/dev/null \
  | openssl x509 -noout -subject -issuer -dates -ext subjectAltName
```

**The `curl -w` timing breakdown is a genuinely useful debugging skill** — it tells you instantly
whether slowness is DNS, TCP, TLS, or the application.

---

# Lab 5 — Break/Fix Friday #2 (2h)

Snapshot first. Scenarios: **BF-05** (systemd unit fails), **BF-06** (SSH lockout),
**BF-07** (cron job never runs), **BF-11** (DNS).

Same rules as week 1: read only SYMPTOM and BREAK, close the file, timer on, narrate out loud.
Log every one with the **Surprised** line filled in.

**Bonus if time:** BF-12 (wrong default gateway) and BF-16 (port in use).
