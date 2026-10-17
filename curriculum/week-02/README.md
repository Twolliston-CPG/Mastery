# Week 2 — Linux II and Networking I

> **Thesis:** systemd is how every Linux service actually runs, and subnetting is the single
> highest-return 6 hours in this entire program. Every AWS VPC, every Kubernetes CNI, every
> firewall conversation for the rest of your career runs on the CIDR math you drill this week.

| | |
|---|---|
| **Hours** | 30–45 |
| **Deliverable** | Blog post #1 — "What actually happens when you type a URL and hit enter" |
| **Break/Fix** | BF-05, BF-06, BF-07, BF-11 |
| **Exit check** | CIDR math with no calculator. Explain a TCP handshake from a packet capture. |

## The week in one figure

**Figure 2.1 — From a URL to a packet, and the service that answers.** The blue path is the request: name resolution, the three-way handshake, HTTP. Around it are the things that make the server answer at all: a systemd unit, a hardened sshd, and the CIDR math that decides where the packet goes.

![Figure 2.1 — From a URL to a packet, and the service that answers](content/figure-2.1-from-a-url-to-a-packet.png)

**Say it, badge by badge:** [`content/FIGURE.md`](content/FIGURE.md) — the spoken script for each of the 10 badges, about three and a half minutes; [`content/figure-2.1-numbered-spoken.pdf`](content/figure-2.1-numbered-spoken.pdf) is the printable two-page version. Read the figure before the day plan; say the script on Friday.

---

## Day plan

| Day | Focus | Lab |
|---|---|---|
| Mon | systemd: units, services, timers, journald | Lab 1 |
| Tue | Users, sudo, SSH hardening, disks | Lab 2 |
| Wed | **Subnetting drill (100 problems)** + IP fundamentals | Lab 3 |
| Thu | TCP/IP, DNS, tcpdump | Lab 4 |
| Fri | Break/Fix BF-05, 06, 07, 11 | Lab 5 |
| Sat | Write and publish blog post #1 | — |
| Sun | Review, plan week 3 | — |

## Reading map

- `_reference/linux-networking/08-networking-fundamentals.md`
- `_reference/linux-networking/10-ssh-remote-access.md`
- `_reference/linux-networking/11-system-monitoring.md`
- `_reference/linux-networking/alt/09-dns-and-http.md`
- `_reference/linux-networking/alt/10-network-troubleshooting.md`
- **Drill:** `_shared/drills/subnetting.md` — this is the week's centerpiece

**Free primary sources:** `man systemd.unit`, `man systemd.timer`, `man 5 sshd_config`,
Julia Evans' networking zines, and Beej's Guide to Network Programming (chapters 1–3).

## Labs

All labs: [labs/LABS.md](labs/LABS.md) · Solutions: [solutions/SOLUTIONS.md](solutions/SOLUTIONS.md)

| # | Lab | Time |
|---|---|---|
| 1 | systemd services and timers | 3h |
| 2 | SSH hardening and disk management | 3h |
| 3 | **Subnetting to automaticity** | 3h |
| 4 | TCP/IP and DNS with tcpdump | 3h |
| 5 | Break/Fix Friday #2 | 2h |

## Drills (Block 4, daily)

- **20 subnetting problems, every single day this week.** Non-negotiable.
- `_shared/drills/bash-oneliners.md` — Processes and network section
- Anki: `linux-networking.tsv`, plus your own cards

## Exit criteria

- [ ] Write a systemd unit + timer from blank and explain why it beats cron
- [ ] Harden sshd without locking yourself out (keep two sessions open)
- [ ] **Convert any CIDR to network/broadcast/host-count in under 10 seconds, no calculator**
- [ ] Split a /16 into N subnets on paper
- [ ] Explain the TCP three-way handshake pointing at a real `tcpdump` capture
- [ ] Trace a DNS query through the full delegation chain with `dig +trace`
- [ ] Blog post #1 published
- [ ] 4 more incident-journal entries
