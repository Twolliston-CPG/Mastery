# Figure 3.1 — Browser to backend: routing, NAT, firewall, TLS, and the reverse proxy

> Week 3 · badges ① to ⑩ · about three and a half minutes at a normal pace. Point at each badge as you say its line. Blue is the path to follow first; orange-red is where something refuses or fails.

![Figure 3.1 — Browser to backend: routing, NAT, firewall, TLS, and the reverse proxy](figure-3.1-browser-to-backend-routing-nat-firewall.png)

Follow the blue path from a client on the internet to the Python process behind Nginx. Every box is something you build by hand this week, and every box is something AWS will later sell you under a different name.

## What to say, badge by badge

- **Open.** “This is the packet path you will be asked to explain at Gate 1: a browser on the internet to a Python process on your VM. Seven boxes on the blue line, each one built by hand this week.”
- **① client.** “Start with `curl -v`. It prints the DNS answer, the TCP connect, the TLS handshake, and the HTTP exchange, in order. When something breaks, the line where curl stops names the layer.”
- **② DNS.** “Your own domain, bought this week for about twelve dollars. One A record points at the VM. The TTL you choose is how long a wrong answer lives in every cache on the internet.”
- **③ router and NAT.** “A packet that leaves a private address needs its source rewritten. MASQUERADE does that at the router, and the conntrack table remembers the mapping so the reply finds its way back. You build this with a network namespace, so you can see both sides.”
- **④ firewall.** “nftables evaluates rules in order and stops at the first match. The stateful rule, `ct state established,related accept`, goes first; without it every reply is dropped. BF-13 is exactly this: a correct rule in the wrong position. Stateful versus stateless is the whole SG versus NACL conversation in week 6.”
- **⑤ Nginx on 443.** “TLS terminates here. The certificate is from Let's Encrypt, valid 90 days, renewed by a timer. Nginx is the only process that listens on a public port.”
- **⑥ upstream pool.** “Two backends behind one name. Health checks mark one down; traffic fails over on a 502. Kill a backend and watch the other take the load. That is a load balancer, and you now know what the ALB does.”
- **⑦ backend app.** “The Python process listens on 8000, on localhost only. It never sees the internet. If it did, the firewall and the proxy would be decoration.”
- **⑧ ACME HTTP-01.** “Let's Encrypt proves you own the name by fetching a token over port 80. If 80 is closed, issuance fails. That is the reason the firewall opens 80 even though users use 443.”
- **⑨ three TLS failures.** “Expired, name mismatch, untrusted chain. They look identical in a browser and completely different in `openssl s_client`. Break each one on purpose so you recognize it on sight.”
- **⑩ Git collaboration.** “Friday afternoon: resolve a real three-way conflict, squash twelve commits into three with an interactive rebase, and find a breaking commit with bisect in log-two-n steps.”
- **Close.** “Name, route, rewrite, filter, terminate, balance, serve. Weeks 6 and 7 are this diagram with AWS names: Route 53, NAT gateway, security group, ALB, target group.”

## Use it

- Read the figure before the day plan. Say the script out loud on Friday with the file closed.
- Each badge line is a thirty-second interview answer; the whole script is the three-minute version.
- Regenerate after editing the spec in `_shared/diagrams/week_figures/`:

```bash
python3 ../../_shared/diagrams/generate-week-figures.py --only 3
```
