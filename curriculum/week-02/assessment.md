# Week 2 Assessment

> Closed book. 45 minutes. **Part B is the one that matters — do it on paper with no calculator.**

## Part A — Recall (10 min)
1. What must you run after editing a systemd unit file, and why?
2. Name four things a systemd timer gives you that cron does not.
3. What does `ProtectSystem=strict` do, and what is its Kubernetes equivalent?
4. Why does `PYTHONUNBUFFERED=1` matter in a service unit?
5. What permissions must `~/.ssh` and `authorized_keys` have?
6. Difference between `ssh -L` and `ssh -R`?
7. What does TCP state `CLOSE-WAIT` accumulating tell you?
8. What does `[R]` mean in tcpdump output, and how does it differ from a timeout?
9. What does `dig +trace` do differently from `dig`?
10. Which three commands replaced `ifconfig`, `netstat`, and `arp`?

## Part B — Subnetting, no calculator (20 min)
11. `10.0.0.0/22` — network, broadcast, total, AWS-usable
12. `192.168.5.192/26` — network, broadcast, first and last usable
13. Smallest AWS subnet for 1,000 instances?
14. Split `172.20.0.0/16` into 8 equal subnets — prefix, and list the 1st, 4th, 8th
15. `10.5.64.0/18` — what is the address range?
16. Do `10.1.0.0/16` and `10.1.128.0/17` overlap?
17. `cidrsubnet("10.0.0.0/16", 4, 3)` returns what?
18. You need 9 subnets from `10.30.0.0/16`, each supporting 2,000 hosts, with 50% of the VPC left
    free. Give the prefix and the first three CIDRs.
19. Why can't you peer two VPCs both using `10.0.0.0/16`?
20. How many usable addresses in a `/28` on AWS, and why not 14?

## Part C — Diagnose (15 min)
21. `systemctl start myapp` fails with 203/EXEC. What is wrong and what do you check?
22. Key-based SSH suddenly asks for a password. Walk your diagnosis.
23. `ping 8.8.8.8` works, `curl https://example.com` fails. What layer, and what four commands?
24. Local network reachable, internet is not. What do you check first?
25. Small HTTP requests succeed, large downloads hang. What is this, and how do you prove it?

---

# Answer key

**A1.** `sudo systemctl daemon-reload`. systemd caches unit files in memory; without a reload your
edit is ignored and you debug the old version. The #1 systemd mistake.

**A2.** journald logging with unit context · `Persistent=true` catches up missed runs · dependency
ordering with `After=`/`Requires=` · explicit `Environment=` (no empty-PATH surprise) ·
`systemctl list-timers` shows last/next · cgroup resource limits · `RandomizedDelaySec`.

**A3.** Mounts the whole filesystem read-only except `/dev`, `/proc`, `/sys`; writable paths must be
whitelisted with `ReadWritePaths`. Kubernetes equivalent: `securityContext.readOnlyRootFilesystem: true`.

**A4.** Python buffers stdout when it isn't a TTY. Without it, logs appear late or are lost entirely
when the process is killed. Same problem occurs in containers.

**A5.** `~/.ssh` = 700, `authorized_keys` = 600. sshd refuses keys if either is group/world-writable.

**A6.** `-L` local forward: a port on **your** machine tunnels to a host reachable from the remote.
`-R` remote forward: a port on the **remote** tunnels back to something reachable from you.

**A7.** The remote closed the connection and **your application hasn't called `close()`**. It's an
application bug — leaked file descriptors — and it will eventually exhaust the fd limit.

**A8.** `[R]` is a TCP RST: something actively refused the connection (closed port, or a firewall
REJECT). A **timeout** with no reply means the packet was silently dropped — a DROP rule or a black
hole. RST = "no"; timeout = "nothing there, or something ate it."

**A9.** `dig +trace` starts at the root servers and follows delegations itself, bypassing your
resolver's cache. Plain `dig` asks your configured resolver, which may answer from cache.

**A10.** `ip addr` · `ss` · `ip neigh`

---

**B11.** net `10.0.0.0`, bcast `10.0.3.255`, 1,024 total, **1,019 usable**
**B12.** net `192.168.5.192`, bcast `192.168.5.255`, first `.193`, last `.254` (AWS first usable `.196`)
**B13.** 1,000 + 5 = 1,005 → 1,024 → **`/22`**
**B14.** `/19` each. 1st `172.20.0.0/19`, 4th `172.20.96.0/19`, 8th `172.20.224.0/19` (block size 32)
**B15.** `10.5.64.0` – `10.5.127.255`
**B16.** **Yes.** `10.1.128.0/17` is the upper half of `10.1.0.0/16`.
**B17.** `10.0.48.0/20`. Adds 4 bits → /20; block size 16 in the third octet; index 3 → 3×16 = 48.
**B18.** 2,000 + 5 → 2,048 → **`/21`**. `10.30.0.0/21`, `10.30.8.0/21`, `10.30.16.0/21`.
Nine /21s consume `10.30.0.0` – `10.30.71.255`, about 14% of the /16 — comfortably under the 50% cap.
**B19.** VPC peering has no NAT, so identical CIDRs make routing ambiguous — there is no way to
express "which 10.0.1.5." Fix: re-CIDR one VPC, or route through a Transit Gateway with NAT.
**B20.** **11.** AWS reserves 5 per subnet (network, VPC router `.1`, DNS `.2`, future `.3`,
broadcast), not the usual 2.

---

**C21.** `ExecStart` points at a binary that doesn't exist or isn't executable. Check the exact path
with `systemctl cat myapp`, confirm with `ls -l`, verify the `User=` can execute it, and check for
a missing interpreter in the shebang. Then `daemon-reload` after fixing.

**C22.** Client: `ssh -vvv` → "Authentications that can continue: publickey,password" means the key
was offered and rejected. Server: `journalctl -u ssh -n 30` → "bad ownership or modes for directory".
Fix the permissions (700/600) and ownership. Also check: right key offered (`IdentitiesOnly yes`),
`AllowUsers` includes you, `authorized_keys` actually contains the public key.

**C23.** Layer 7/name resolution — IP connectivity works, so it's not routing.
`dig example.com` · `cat /etc/resolv.conf` · `dig @8.8.8.8 example.com` (works with a different
resolver → it's the configured one) · `resolvectl status`. If DNS is fine, then
`curl -v` and check TLS and the port.

**C24.** `ip route show` — is the default route present and does the gateway sit on a
directly-connected subnet? Then `ping <gateway>`, `ip addr`, `arp -n`. A gateway outside your own
subnet can never resolve via ARP, which is BF-12.

**C25.** **MTU / path MTU discovery failure.** Prove it with
`ping -c2 -M do -s 1472 <dest>` (fails) versus `ping -c2 -M do -s 1372 <dest>` (succeeds) — that
brackets the real MTU. Fix by matching MTUs or clamping MSS. This shows up constantly with VPNs,
overlay networks, and Kubernetes CNIs, and almost no junior candidate can name it.

## Scoring
| | |
|---|---|
| 22–25 | Move on. |
| 18–21 | Redo Part B. Subnetting must be automatic before week 6. |
| < 18 | **Add two days.** Do 100 more subnetting problems. Week 6's VPC lab depends entirely on this. |
