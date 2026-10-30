# Week 3 Labs

> **Figures:** one numbered mechanism figure per lab, with the spoken script, the numbers to own and
> the command that proves each badge, in [`FIGURES.md`](FIGURES.md) (3.2 to 3.7). Read a lab's figure
> before you start it; redraw it after.

---

# Lab 1 — Routing, NAT, and Firewalls (3h)

## Part 1 — Routing

```bash
ip route show
ip route get 8.8.8.8            # which route/interface would be used
ip route get 10.0.0.5

# Add a static route (a second VM or container as the "next hop")
sudo ip route add 192.168.99.0/24 via 10.0.0.1 dev eth0
ip route show
sudo ip route del 192.168.99.0/24

# Break and fix the default route (BF-12)
ip route show default
sudo ip route del default
ping -c1 8.8.8.8                # fails
sudo ip route add default via <your-gateway>
```

**Understand longest-prefix match.** With routes for `0.0.0.0/0`, `10.0.0.0/8`, and `10.0.5.0/24`, a
packet to `10.0.5.7` takes the `/24` — the most specific route always wins, regardless of order.
This is exactly how AWS route tables work.

## Part 2 — Build a NAT router with network namespaces

This is the single best way to understand what a NAT gateway does, and it costs nothing.

```bash
# Create an isolated "private network"
sudo ip netns add private
sudo ip link add veth-host type veth peer name veth-priv
sudo ip link set veth-priv netns private

sudo ip addr add 10.99.0.1/24 dev veth-host
sudo ip link set veth-host up

sudo ip netns exec private ip addr add 10.99.0.2/24 dev veth-priv
sudo ip netns exec private ip link set veth-priv up
sudo ip netns exec private ip link set lo up
sudo ip netns exec private ip route add default via 10.99.0.1

# The namespace can reach the host but NOT the internet -- yet
sudo ip netns exec private ping -c1 10.99.0.1     # works
sudo ip netns exec private ping -c1 8.8.8.8       # FAILS

# Now become a NAT router
sudo sysctl -w net.ipv4.ip_forward=1
sudo iptables -t nat -A POSTROUTING -s 10.99.0.0/24 -o eth0 -j MASQUERADE

sudo ip netns exec private ping -c1 8.8.8.8       # WORKS
sudo iptables -t nat -L POSTROUTING -n -v
```

**You just built a NAT gateway.** The `private` namespace is a private subnet; the host is the NAT
gateway; `MASQUERADE` is source NAT. When week 6 asks why a private-subnet instance needs a NAT
gateway in a *public* subnet, you will already know — because the router has to have a route out
itself.

Cleanup: `sudo ip netns del private`

## Part 3 — Firewalls and rule order

```bash
sudo iptables -L -n -v --line-numbers

# Reproduce BF-13: order matters
sudo iptables -A INPUT -p tcp --dport 8080 -j DROP
sudo iptables -A INPUT -p tcp --dport 8080 -j ACCEPT
curl -m3 localhost:8080         # blocked -- the DROP is first
sudo iptables -L INPUT -n -v --line-numbers   # watch the DROP counter increment
sudo iptables -D INPUT 1

# The stateful rule that makes everything else work
sudo iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
```

**Tasks:**
1. Build a default-deny INPUT policy that still allows SSH and established connections
2. Prove the conntrack rule is what makes outbound connections work — remove it and watch
3. Compare DROP and REJECT: `curl` against each and observe timeout vs immediate refusal

```bash
# ufw equivalent, for comparison
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp
sudo ufw allow 80,443/tcp
sudo ufw enable && sudo ufw status verbose
```

> **Arch path:** run `sudo systemctl enable --now ufw` before `ufw enable`, or the rules do not
> survive a reboot. On the GCP VM the VPC firewall sits in front of all of this — a port must be
> open in **both** to be reachable. Add that hop to the mapping below.

**Write down the mapping now — you will be asked it:**
| Linux | AWS |
|---|---|
| iptables with conntrack (stateful) | **Security Group** |
| iptables without conntrack, ordered rules, DROP+ACCEPT | **NACL** |
| MASQUERADE / SNAT | **NAT Gateway** |
| default route to the router | **Route table `0.0.0.0/0 → igw`** |

---

# Lab 2 — DNS with Your Own Domain (2h)

**Buy a domain first.** Namecheap, Porkbun, or Cloudflare Registrar — around $10–12/year.

```bash
dig yourdomain.com NS +short       # your registrar's nameservers
dig yourdomain.com SOA
dig yourdomain.com +trace          # full delegation from the root
```

**Tasks:**
1. Create an `A` record pointing at your lab VM's public IP (or any IP)
2. Create a `CNAME` for `www` → the apex, and observe the extra lookup in `dig`
3. **Try to create a CNAME at the apex.** Your registrar will refuse. Understand why — a CNAME
   cannot coexist with the SOA and NS records that must exist at the apex.
4. Set a TTL of 60, query, change the record, and time how long the old value persists
5. Add a TXT record and query it: `dig yourdomain.com TXT +short`
6. Set up an MX record and explain what the priority number does

```bash
# Watch caching behavior
dig yourdomain.com                       # note the TTL
sleep 10 && dig yourdomain.com           # TTL decreased -- this was cached
dig @1.1.1.1 yourdomain.com +norecurse   # is it in Cloudflare's cache?
dig @ns1.registrar.com yourdomain.com    # authoritative -- always full TTL
```

**The apex/CNAME problem is why Route 53 alias records exist** (week 7). Hitting it yourself here
means you'll never forget it.

---

# Lab 3 — Nginx Reverse Proxy and Load Balancing (3h)

## Part 1 — Two backends

> **Arch path:** replace the `apt` line with `sudo pacman -S nginx`, then do the one-time layout
> setup in [`_setup/DISTRO.md`](../../_setup/DISTRO.md#week-3--making-the-nginx-lab-work-unchanged)
> **before Part 2**. Arch's Nginx has no `sites-available/` and is not started for you. After
> that setup, the rest of this lab runs as written.

```bash
sudo apt install -y nginx
mkdir -p ~/lab3

# Two distinguishable backends
for p in 3001 3002; do
  cat > ~/lab3/backend-$p.py <<PY
import http.server, socketserver, json, os, sys
PORT = $p
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/health":
            self.send_response(200 if os.path.exists("/tmp/healthy-$p") else 503)
        else:
            self.send_response(200)
        self.send_header("Content-Type","application/json"); self.end_headers()
        self.wfile.write(json.dumps({"backend": PORT, "path": self.path}).encode())
    def log_message(self,*a): pass
socketserver.TCPServer.allow_reuse_address = True
with socketserver.TCPServer(("0.0.0.0",PORT),H) as s:
    sys.stderr.write(f"backend {PORT} up\n"); s.serve_forever()
PY
  touch /tmp/healthy-$p
  python3 ~/lab3/backend-$p.py &
done

curl -s localhost:3001 | jq
curl -s localhost:3002 | jq
```

## Part 2 — Proxy and balance

```bash
sudo tee /etc/nginx/sites-available/lab >/dev/null <<'EOF2'
upstream app_backend {
    server 127.0.0.1:3001 max_fails=2 fail_timeout=10s;
    server 127.0.0.1:3002 max_fails=2 fail_timeout=10s;
    # least_conn;      # try each of these
    # ip_hash;         # sticky by client IP
    keepalive 32;
}

server {
    listen 80;
    server_name _;

    access_log /var/log/nginx/lab-access.log;
    error_log  /var/log/nginx/lab-error.log warn;

    location /health {
        access_log off;
        return 200 "ok\n";
    }

    location / {
        proxy_pass http://app_backend;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_connect_timeout 5s;
        proxy_send_timeout    30s;
        proxy_read_timeout    30s;

        proxy_next_upstream error timeout http_502 http_503;
    }
}
EOF2

sudo ln -sf /etc/nginx/sites-available/lab /etc/nginx/sites-enabled/lab
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t                    # ALWAYS validate before reloading
sudo systemctl reload nginx

for i in $(seq 1 10); do curl -s localhost | jq -r .backend; done
```

**Tasks:**
1. Observe round-robin across both backends
2. Kill backend 3001 and watch traffic shift — measure how long it takes
3. Reproduce BF-14 (502): stop both backends, read `/var/log/nginx/error.log`
4. Make a backend slow (`time.sleep(40)`) and observe a **504**, not a 502 — explain the difference
5. Try `least_conn` and `ip_hash` and describe when each is correct
6. Bind a backend to `127.0.0.1` only, then put nginx in a container — watch it fail, and connect
   that to BF-20

## Part 3 — Headers that matter

```bash
curl -s localhost -H 'Host: app.example.com' | jq
sudo tail -5 /var/log/nginx/lab-access.log
```

**`X-Forwarded-For` is not optional.** Without it every request in your backend logs appears to come
from the proxy's IP, which destroys rate limiting, geo-logic, audit trails, and abuse investigation.
The AWS equivalent is the ALB's `X-Forwarded-For`, and the "preserve the real client IP" question
comes up in ALB-vs-NLB discussions constantly.

---

# Lab 4 — TLS End to End (2h)

## Part 1 — Self-signed, to see the machinery

```bash
mkdir -p ~/lab3/tls && cd ~/lab3/tls

# Your own CA
openssl genrsa -out ca.key 4096
openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 -out ca.crt \
  -subj "/C=US/O=Lab CA/CN=Lab Root CA"

# A server key + CSR with SANs
openssl genrsa -out server.key 2048
openssl req -new -key server.key -out server.csr \
  -subj "/C=US/O=Lab/CN=lab.local"

cat > san.cnf <<'EOF2'
subjectAltName = DNS:lab.local, DNS:*.lab.local, IP:127.0.0.1
EOF2

openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out server.crt -days 365 -sha256 -extfile san.cnf

openssl x509 -in server.crt -noout -text | head -25
openssl verify -CAfile ca.crt server.crt
```

**Tasks:**
1. Configure nginx with this cert; `curl` it and observe the verification failure
2. `curl --cacert ca.crt https://lab.local/` — now it succeeds. Explain why.
3. Issue a cert with the **wrong** SAN and observe the hostname-mismatch error
4. Issue a cert that **expired yesterday** (`-days -1`) and observe that error
5. Serve only the leaf (omit the CA) to a client that doesn't have the CA — this is the
   "unable to verify the first certificate" case

**Those three failures — expired, hostname mismatch, missing chain — are BF-15, and being able to
distinguish them by their error text is the interview answer.**

## Part 2 — Let's Encrypt on your real domain

> **Arch path:** `sudo pacman -S certbot certbot-nginx`. Let's Encrypt must reach the VM on port
> 80, so set `open_web = true` in `_setup/gcp-lab/terraform.tfvars` and re-apply first.

```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com

sudo certbot renew --dry-run          # test auto-renewal
systemctl list-timers | grep certbot  # the renewal timer
```

```bash
# Verify what you're actually serving
echo | openssl s_client -connect yourdomain.com:443 -servername yourdomain.com 2>/dev/null \
  | openssl x509 -noout -subject -issuer -dates -ext subjectAltName

# Check the full chain is served (the BF-15 trap)
echo | openssl s_client -connect yourdomain.com:443 -showcerts 2>/dev/null | grep -c 'BEGIN CERT'
# should be >= 2: leaf + intermediate
```

## Part 3 — Modern TLS config

```nginx
ssl_protocols TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers off;
ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384;
ssl_session_cache shared:SSL:10m;
ssl_session_timeout 1d;
ssl_stapling on;
ssl_stapling_verify on;
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
```
Test at ssllabs.com/ssltest — aim for an A.

---

# Lab 5 — Break/Fix Friday #3 (2h)

**BF-13** (firewall rule ordering) · **BF-14** (502 Bad Gateway) · **BF-15** (expired certificate) ·
**BF-16** (port already in use).

Bonus: **BF-17** (MTU black hole) — set up two namespaces with mismatched MTUs and reproduce it.
Very few people have ever seen this one.

---

# Lab 6 — Git Collaboration (3h)

## Part 1 — Rebase workflow

```bash
mkdir -p ~/lab6-git && cd ~/lab6-git && git init
echo "line 1" > f.txt && git add . && git commit -m "feat: initial"

git switch -c feature
for i in 1 2 3 4; do echo "feature $i" >> f.txt; git add .; git commit -m "wip $i"; done

git switch main
echo "main change" >> other.txt && git add . && git commit -m "feat: main work"

# Compare the two integrations
git switch feature
git rebase main                  # replay feature commits on top of main
git log --oneline --graph --all

# Now clean it up before the "PR"
git rebase -i main               # squash wip 2-4 into wip 1, write a real message
git log --oneline
```

## Part 2 — Conflicts

```bash
git switch main
echo "MAIN VERSION" > conflict.txt && git add . && git commit -m "feat: main version"
git switch -c other main~1
echo "OTHER VERSION" > conflict.txt && git add . && git commit -m "feat: other version"
git switch main && git merge other    # CONFLICT

cat conflict.txt                       # read the markers
git diff                               # combined diff view
git checkout --ours conflict.txt       # take main's
git checkout --theirs conflict.txt     # take other's
# or edit by hand, then:
git add conflict.txt && git commit
```

Enable `rerere` so git remembers your resolution if the same conflict recurs during a rebase:
```bash
git config --global rerere.enabled true
```

## Part 3 — bisect

```bash
cd ~/lab6-git
for i in $(seq 1 12); do
  echo "v$i" > version.txt
  [[ $i -eq 7 ]] && echo "BROKEN" >> version.txt
  git add . && git commit -q -m "chore: version $i"
done

git bisect start
git bisect bad HEAD
git bisect good HEAD~11
# test: grep -q BROKEN version.txt && git bisect bad || git bisect good
# repeat -- it will name the commit in ~4 steps, not 11
git bisect reset

# Automate it entirely:
git bisect start HEAD HEAD~11
git bisect run bash -c '! grep -q BROKEN version.txt'
git bisect reset
```

## Part 4 — PR workflow on GitHub

1. Push `sysreport` from week 1
2. Create a branch, make a real improvement (add the inode check)
3. Open a PR **against your own repo**
4. Review your own diff — read it as a reviewer would
5. Request changes on yourself, address them, merge with squash
6. Add a `CODEOWNERS` file and a branch protection rule requiring review

**Doing this on your own repo builds the muscle memory** so the first real PR you open at a job isn't
the first PR you've ever opened.
