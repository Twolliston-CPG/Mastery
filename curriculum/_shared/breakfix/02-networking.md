# Break/Fix: Networking (BF-11 – BF-18)

---

## BF-11 — "The network is down" (it's DNS)

**SYMPTOM:** `curl https://example.com` hangs or returns "Could not resolve host." Ping to `8.8.8.8`
works fine.

**BREAK:** `sudo sed -i 's/^nameserver.*/nameserver 192.0.2.1/' /etc/resolv.conf`

**DIAGNOSIS — walk it in this order:**
```bash
ping -c1 8.8.8.8            # IP connectivity OK? -> yes, so not routing
dig example.com             # resolution fails / times out
cat /etc/resolv.conf        # what resolver are we using?
dig @8.8.8.8 example.com    # works with a known-good resolver -> it's the configured one
resolvectl status           # systemd-resolved systems
dig +trace example.com      # full delegation path when you need depth
```

**ROOT CAUSE:** Nameserver points at an unreachable address.

**FIX:** Correct `/etc/resolv.conf`. On systemd-resolved systems that file is a symlink — edit the
netplan/NetworkManager config instead, or the change vanishes on reboot.

**THE METHOD THAT MATTERS:** Prove IP connectivity works *before* blaming DNS, then prove DNS is the
layer by resolving against a different server. That two-step is the whole answer to "walk me through
troubleshooting a connectivity problem."

---

## BF-12 — Wrong default gateway

**SYMPTOM:** Local network reachable, internet is not.

**BREAK:** `sudo ip route del default && sudo ip route add default via 192.0.2.254`

**DIAGNOSIS:**
```bash
ip route show                    # default via 192.0.2.254 -- is that our gateway?
ip addr show                     # our subnet is 10.0.0.0/24 -- gateway is off-subnet
ping -c1 <gateway>               # unreachable
traceroute 8.8.8.8               # dies at hop 1
arp -n                           # no MAC for the gateway
```

**ROOT CAUSE:** Default route points at an address outside the local subnet, so ARP never resolves.

**FIX:** `sudo ip route replace default via <real-gateway>`

**KEY INSIGHT:** A gateway must be **on a directly-connected subnet**. This is exactly the same
concept as an AWS route table sending `0.0.0.0/0` to an internet gateway — week 6 is easier because
you learned it here.

---

## BF-13 — Firewall rule ordering

**SYMPTOM:** Port 8080 is explicitly allowed, but connections still time out.

**BREAK:**
```bash
sudo iptables -A INPUT -p tcp --dport 8080 -j DROP
sudo iptables -A INPUT -p tcp --dport 8080 -j ACCEPT
```

**DIAGNOSIS:**
```bash
sudo iptables -L INPUT -n -v --line-numbers
# Watch the packet counters -- the DROP rule is incrementing
ss -tlnp | grep 8080         # is anything even listening?
```

**ROOT CAUSE:** iptables evaluates **top to bottom, first match wins.** The DROP at line 1 fires
before the ACCEPT at line 2 is ever considered.

**FIX:** `sudo iptables -D INPUT 1` — or insert the ACCEPT above: `iptables -I INPUT 1 ...`

**CONNECT IT TO AWS:** Security Groups are **stateful and allow-only** — no ordering, no deny, return
traffic automatic. NACLs are **stateless and numbered** — order matters, deny exists, and you must
allow the ephemeral return ports explicitly. Being able to draw that contrast cleanly is an
extremely common AWS interview question, and BF-13 is where you earn it.

---

## BF-14 — 502 Bad Gateway

**SYMPTOM:** Nginx returns 502. The backend "looks fine."

**BREAK:** Stop the backend, or change its listen port.

**DIAGNOSIS:**
```bash
sudo tail -f /var/log/nginx/error.log     # "connect() failed (111: Connection refused)"
curl -v http://127.0.0.1:3000/health      # test the backend DIRECTLY
ss -tlnp | grep 3000                      # is it listening? on which address?
sudo nginx -T | grep -A3 proxy_pass       # what is nginx actually configured to hit?
```

**ROOT CAUSES, in frequency order:**
1. Backend is down → start it
2. Backend listening on `127.0.0.1` but nginx is in a different netns/container → bind `0.0.0.0`
3. Port mismatch between `proxy_pass` and the app
4. SELinux blocking the connection → `setsebool -P httpd_can_network_connect 1`
5. Backend is up but slower than `proxy_read_timeout` → that's a **504**, not 502

**DISTINGUISHING 502 FROM 504 CORRECTLY IS THE SIGNAL.** 502 = the upstream refused or died. 504 =
the upstream accepted but didn't answer in time. They have completely different fixes.

---

## BF-15 — Expired TLS certificate

**SYMPTOM:** Browsers show a security warning. `curl` fails with "certificate has expired."

**DIAGNOSIS:**
```bash
echo | openssl s_client -connect example.com:443 -servername example.com 2>/dev/null \
  | openssl x509 -noout -dates -subject -issuer
curl -vI https://example.com 2>&1 | grep -i 'expire\|subject\|issuer'
openssl x509 -in /etc/ssl/cert.pem -noout -text | head -20
```

**FIX:** `sudo certbot renew --force-renewal && sudo systemctl reload nginx`

**THE THREE CERT FAILURES AND HOW TO TELL THEM APART:**
| Error | Cause |
|---|---|
| "certificate has expired" | `notAfter` passed — renew |
| "unable to verify the first certificate" | **Missing intermediate** — serve the full chain, not just the leaf |
| "hostname mismatch" | SAN doesn't cover the name — reissue with the right SAN, or fix SNI |

The intermediate-chain one is the interesting answer: it works in browsers (which cache
intermediates) but fails in `curl` and in your CI. Being able to explain *why it works in Chrome but
breaks the pipeline* is a memorable interview moment.

**PREVENT:** Automated renewal + an expiry alarm at 30 days. A cert expiry is a self-inflicted outage.

---

## BF-16 — Port already in use

**SYMPTOM:** `Error: listen EADDRINUSE :::8080`

**DIAGNOSIS:**
```bash
sudo ss -tlnp | grep :8080
sudo lsof -i :8080
sudo fuser -n tcp 8080
```

**FIX:** Kill the holder, or change your port.

**THE SUBTLE ONE:** If nothing is listening but bind still fails, the socket is in `TIME_WAIT`. Check
`ss -tan | grep 8080`. The correct fix is `SO_REUSEADDR` in the application, not waiting it out.
Knowing `TIME_WAIT` exists and why (to absorb delayed duplicate packets) is a strong networking
answer.

---

## BF-17 — MTU / fragmentation black hole

**SYMPTOM:** SSH connects and small commands work, but `ls` of a large directory hangs. Small HTTP
requests succeed; large responses stall.

**BREAK:** `sudo ip link set dev eth0 mtu 1400` on one side only.

**DIAGNOSIS:**
```bash
ping -c2 -M do -s 1472 8.8.8.8     # 1472 + 28 header = 1500. Fails if MTU < 1500
ping -c2 -M do -s 1372 8.8.8.8     # succeeds -> real MTU is ~1400
ip link show eth0 | grep mtu
tracepath 8.8.8.8                  # reports the path MTU
```

**ROOT CAUSE:** Path MTU mismatch. Large packets with DF set are dropped, and the ICMP
"fragmentation needed" message is being filtered — so the sender never learns.

**FIX:** Match MTUs, or clamp MSS:
```bash
sudo iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN \
  -j TCPMSS --clamp-mss-to-pmtu
```

**WHY THIS SCENARIO EARNS ITS PLACE:** "Small things work, big things hang" is the signature of an
MTU problem and it appears constantly with VPNs, overlay networks, and **Kubernetes CNIs**. Very few
junior candidates can name it. You will be able to.

---

## BF-18 — Asymmetric routing / stateful firewall drop

**SYMPTOM:** TCP handshake starts (SYN seen at the server) but the client never completes.

**DIAGNOSIS:**
```bash
sudo tcpdump -ni any 'tcp port 8080 and (tcp[tcpflags] & (tcp-syn|tcp-ack)) != 0'
# Server sends SYN-ACK; client never ACKs -> return path is broken or filtered
ip route get <client-ip>       # which interface does the reply leave by?
```

**ROOT CAUSE:** The reply leaves via a different path than the request arrived on, and a stateful
firewall in the middle has no connection record for it, so it drops it.

**FIX:** Correct the routing so request and reply are symmetric, or use policy routing to pin the
reply to the ingress interface.

**THE TRANSFERABLE LESSON:** `tcpdump` on **both ends** tells you which direction is missing, and
that immediately halves the search space. "I'd packet-capture both sides to see which direction
disappears" is an answer that sounds like experience.
