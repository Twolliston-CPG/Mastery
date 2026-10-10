# Week 3 Assessment

> Closed book, 40 minutes.

## Part A — Recall (15 min)
1. With routes for `0.0.0.0/0`, `10.0.0.0/8`, and `10.0.5.0/24`, which is used for `10.0.5.7`? Why?
2. Three things a Linux box needs to act as a NAT router
3. Why must an AWS NAT gateway live in a **public** subnet?
4. What does the conntrack `ESTABLISHED,RELATED` rule do, and what breaks without it?
5. DROP vs REJECT — what does the client experience in each case?
6. Map: stateful firewall → AWS? Stateless ordered rules → AWS? MASQUERADE → AWS?
7. Why can a CNAME not exist at a zone apex, and what does Route 53 offer instead?
8. 502 vs 504 — cause and fix for each
9. The three TLS failure modes and the error text that identifies each
10. Which TLS failure works in Chrome but breaks `curl` and CI, and why?

## Part B — Commands (10 min)
11. Show which route would be used to reach `8.8.8.8`
12. Enable IP forwarding and add a MASQUERADE rule for `10.99.0.0/24` out `eth0`
13. Show iptables rules with **packet counters** and line numbers
14. Verify an nginx config before reloading
15. Show a certificate's expiry, subject, issuer, and SANs for a remote host
16. Count how many certificates a server sends (to detect a broken chain)
17. Break down a request's timing into DNS / connect / TLS / TTFB
18. Automate `git bisect` with a test script
19. Squash the last 4 commits into 1 without an editor
20. Trace a DNS name from the root servers

## Part C — Diagnose (15 min)
21. Nginx returns 502. Five possible causes, in order of likelihood.
22. Your API returns 504 only for one endpoint. Where do you look?
23. The site loads in Chrome but your Python client raises an SSL error. What is it?
24. A rule explicitly allows port 8080 but connections still fail. What do you check?
25. You changed a DNS record an hour ago; some users still get the old IP. Explain, and describe how
    you should have done the change.

---

# Answer key

**A1.** `10.0.5.0/24` — **longest prefix match**. The most specific route wins regardless of order.

**A2.** (1) `net.ipv4.ip_forward=1`, (2) a source-NAT/MASQUERADE rule, (3) **the router itself must
have a route to the destination** — plus clients need a default route pointing at it.

**A3.** Because the NAT gateway is the router, and a router must be able to reach the internet
itself. A public subnet is one whose route table has `0.0.0.0/0 → igw`. A NAT gateway in a private
subnet would have nowhere to forward to. (BF-27)

**A4.** It allows inbound packets belonging to connections **you initiated**. Without it, a
default-deny INPUT policy breaks every outbound request, because the reply arrives on an ephemeral
port with no matching allow rule. It is the mechanism that makes a firewall "stateful."

**A5.** **DROP**: silence — the client hangs until its own timeout. **REJECT**: an RST or ICMP
unreachable — immediate "connection refused." DROP for internet-facing (slows scanners, leaks
nothing); REJECT internally (fails fast, debuggable).

**A6.** Stateful → **Security Group**. Stateless with ordered allow/deny rules → **NACL**.
MASQUERADE/SNAT → **NAT Gateway**.

**A7.** RFC 1034 forbids a CNAME coexisting with any other record type, and the apex must carry SOA
and NS records. Route 53 provides **alias** records, which work at the apex, resolve directly to the
target's IP with no extra lookup, and are free to query.

**A8.** **502** — the upstream refused, died, or returned a malformed response. Fix: start the
backend, correct the port, or fix a `127.0.0.1` bind. **504** — the upstream accepted but didn't
respond within the timeout. Fix: make the app faster, or raise `proxy_read_timeout`.

**A9.** *Expired* → "certificate has expired" · *Hostname mismatch* → "no alternative certificate
subject name matches target host name" · *Incomplete chain* → "unable to get local issuer
certificate" / "unable to verify the first certificate".

**A10.** The **incomplete chain**. Browsers cache intermediates from earlier sites and some fetch the
missing one via the AIA extension; `curl`, CI runners, and mobile clients generally do not. Detect
with `openssl s_client -showcerts | grep -c 'BEGIN CERT'` — it should be ≥ 2.

---

**B11.** `ip route get 8.8.8.8`
**B12.** `sudo sysctl -w net.ipv4.ip_forward=1 && sudo iptables -t nat -A POSTROUTING -s 10.99.0.0/24 -o eth0 -j MASQUERADE`
**B13.** `sudo iptables -L -n -v --line-numbers`
**B14.** `sudo nginx -t`
**B15.** `echo | openssl s_client -connect host:443 -servername host 2>/dev/null | openssl x509 -noout -subject -issuer -dates -ext subjectAltName`
**B16.** `echo | openssl s_client -connect host:443 -showcerts 2>/dev/null | grep -c 'BEGIN CERT'`
**B17.** `curl -w 'dns %{time_namelookup} connect %{time_connect} tls %{time_appconnect} ttfb %{time_starttransfer} total %{time_total}\n' -o /dev/null -s https://host`
**B18.** `git bisect start HEAD HEAD~20 && git bisect run ./test.sh`
**B19.** `git reset --soft HEAD~4 && git commit -m "msg"`
**B20.** `dig example.com +trace`

---

**C21.** (1) Backend is down. (2) Backend bound to `127.0.0.1` while nginx is in a different network
namespace or container. (3) Port mismatch between `proxy_pass` and the app. (4) SELinux blocking the
outbound connection (`httpd_can_network_connect`). (5) Backend up but returning a malformed
response. Read `/var/log/nginx/error.log` first — it names the errno.

**C22.** That endpoint is slower than `proxy_read_timeout`. Check the app's own latency for that
route, look for a slow database query or a downstream call without a timeout, and check whether the
work legitimately takes that long — if it does, the fix is making it asynchronous, not raising the
timeout forever.

**C23.** Almost certainly an **incomplete certificate chain**. Chrome has the intermediate cached;
Python's `ssl` module with `certifi` does not and won't fetch it. Serve the full chain
(`fullchain.pem`, not `cert.pem` — that exact mistake is extremely common with certbot).

**C24.** (1) **Rule order** — is there a DROP above it? Check the packet counters
(`iptables -L -n -v --line-numbers`); if the DROP counter is incrementing, that's it. (2) Is anything
actually listening (`ss -tlnp`)? (3) Is it bound to `127.0.0.1` instead of `0.0.0.0`? (4) Is there a
second firewall — cloud security group, or a NACL?

**C25.** Resolvers cached the old record for its TTL; nothing "propagates," it just expires. If the
old TTL was 3600, some resolvers legitimately serve the old value for up to an hour after the change.
**The correct procedure:** lower the TTL to 60 well in advance, **wait for the full original TTL to
elapse** so every cache has picked up the short TTL, then make the change, then restore the longer
TTL. Skipping the "wait for the old TTL first" step is the classic mistake.

## Scoring
| | |
|---|---|
| 22–25 | Move on. |
| 18–21 | Review the sections you missed; make Anki cards. |
| < 18 | Redo Labs 1 and 4. The SG/NACL and TLS material is directly reused in weeks 6 and 13. |
