# Subnetting Drill

> **Do 20 of these every day in weeks 2–4, then 10/day until week 10.**
> Target: any question answered in under 10 seconds, no calculator.
> This is ~6 hours of total investment and it pays off in every AWS, VPC, and Kubernetes
> conversation you will ever have.

## The table to burn into memory

| CIDR | Netmask | Total addrs | AWS usable | Common use |
|---|---|---|---|---|
| /16 | 255.255.0.0 | 65,536 | 65,531 | A whole VPC |
| /17 | 255.255.128.0 | 32,768 | 32,763 | |
| /18 | 255.255.192.0 | 16,384 | 16,379 | |
| /19 | 255.255.224.0 | 8,192 | 8,187 | Large subnet |
| /20 | 255.255.240.0 | 4,096 | 4,091 | Typical AZ subnet |
| /21 | 255.255.248.0 | 2,048 | 2,043 | |
| /22 | 255.255.252.0 | 1,024 | 1,019 | |
| /23 | 255.255.254.0 | 512 | 507 | |
| /24 | 255.255.255.0 | 256 | 251 | Standard subnet |
| /25 | 255.255.255.128 | 128 | 123 | |
| /26 | 255.255.255.192 | 64 | 59 | Small subnet |
| /27 | 255.255.255.224 | 32 | 27 | |
| /28 | 255.255.255.240 | 16 | 11 | **AWS minimum** |
| /32 | 255.255.255.255 | 1 | 1 | Single host (SG rules) |

**AWS reserves 5 addresses per subnet:** network, VPC router (.1), DNS (.2), future use (.3),
broadcast. So usable = total − 5, not − 2. **This is a classic exam trap.**

## The three mental shortcuts

**1. Powers of two from the back.** `/24` = 256. Every bit you take away doubles:
`/23`=512, `/22`=1024, `/21`=2048, `/20`=4096. Every bit you add halves: `/25`=128, `/26`=64.

**2. The "block size" trick.** For any prefix, block size = 256 − (last octet of the mask).
`/26` → mask 192 → block size 64 → networks at .0, .64, .128, .192.

**3. Count hosts, then round UP to a power of two, then add the AWS 5.** Need 500 hosts?
500 + 5 = 505 → next power of two is 512 → `/23`.

---

## Set A — CIDR to facts (answers at the bottom)

1. `10.0.0.0/24` — network, broadcast, usable count?
2. `192.168.1.64/26` — network, broadcast, first/last usable?
3. `172.16.0.0/20` — how many addresses? usable in AWS?
4. `10.50.0.0/22` — what is the last IP in this range?
5. `10.0.128.0/17` — what is the range?
6. `192.168.100.128/25` — broadcast address?
7. `10.10.10.0/28` — usable host addresses in AWS?
8. `172.31.0.0/16` — total addresses?
9. `10.0.0.64/27` — network and broadcast?
10. `192.0.2.0/23` — does `192.0.3.55` belong to it?

## Set B — Requirements to CIDR

11. Smallest subnet for 500 EC2 instances?
12. Smallest subnet for 10 instances (AWS)?
13. Split `10.0.0.0/16` into 4 equal subnets — list them.
14. Split `10.0.0.0/16` into 16 equal subnets — what prefix, and what is the 3rd?
15. VPC `10.0.0.0/16`, need 6 subnets of ~4000 hosts each — what prefix, list the first three.
16. You need exactly 2 usable IPs for a point-to-point link (non-AWS) — what prefix?
17. Smallest AWS subnet possible, and how many usable?

## Set C — Overlap and design (the ones AWS actually tests)

18. Do `10.0.0.0/16` and `10.1.0.0/16` overlap?
19. Do `10.0.0.0/8` and `10.5.0.0/16` overlap?
20. You have VPC-A `10.0.0.0/16` and VPC-B `10.0.0.0/16`. Can you peer them? Why not?
21. Design a VPC for 3 AZs with public + private + database tiers in each (9 subnets), from
    `10.20.0.0/16`, leaving room to grow.
22. `172.16.0.0/12` — what is the full private range it covers?
23. Which RFC1918 ranges exist, and what are their prefixes?

---

## Answers

**Set A**
1. net `10.0.0.0`, bcast `10.0.0.255`, 256 total / **251 usable in AWS**
2. net `192.168.1.64`, bcast `192.168.1.127`, first `.65`, last `.126` (AWS: first usable `.68`)
3. 4,096 total, **4,091 usable in AWS**
4. `10.50.3.255` (block size 4 in the third octet: 0–3)
5. `10.0.128.0` – `10.0.255.255`
6. `192.168.100.255`
7. 16 total − 5 = **11 usable**
8. 65,536
9. net `10.0.0.64`, bcast `10.0.0.95` (block size 32)
10. **Yes** — `/23` covers `192.0.2.0`–`192.0.3.255`

**Set B**
11. 500 + 5 = 505 → 512 → **`/23`**
12. 10 + 5 = 15 → 16 → **`/28`** (the AWS minimum anyway)
13. `/18` each: `10.0.0.0/18`, `10.0.64.0/18`, `10.0.128.0/18`, `10.0.192.0/18`
14. `/20` each; 3rd is `10.0.32.0/20` (block size 16 in the third octet)
15. 4000 + 5 → 4096 → **`/20`**: `10.0.0.0/20`, `10.0.16.0/20`, `10.0.32.0/20`
16. `/30` (4 addrs, 2 usable) — or `/31` under RFC 3021 for point-to-point
17. **`/28`**, 11 usable

**Set C**
18. **No.** `10.0.x.x` vs `10.1.x.x` are distinct.
19. **Yes.** `/8` covers all of `10.0.0.0`–`10.255.255.255`, which contains `10.5.0.0/16`.
20. **No.** VPC peering requires non-overlapping CIDRs — there is no NAT in a peering connection, so
    the route tables would be ambiguous. **This is asked constantly.** Fix: re-CIDR one VPC, or use
    a Transit Gateway with NAT in between.
21. From `10.20.0.0/16`, use `/20` per subnet (4,091 usable each), which uses only the first quarter
    of the VPC and leaves 10.20.144.0+ free to grow:
    ```
    AZ-a  public 10.20.0.0/20   private 10.20.16.0/20   db 10.20.32.0/20
    AZ-b  public 10.20.48.0/20  private 10.20.64.0/20   db 10.20.80.0/20
    AZ-c  public 10.20.96.0/20  private 10.20.112.0/20  db 10.20.128.0/20
    ```
    In an interview, say why: *public subnets are small in practice (just NAT/ALB) but keeping them
    uniform makes the Terraform `for_each` trivial, and a /20 leaves headroom for EKS pod IPs, which
    consume subnet addresses fast.* That last clause is the senior detail.
22. `172.16.0.0` – `172.31.255.255`
23. `10.0.0.0/8` · `172.16.0.0/12` · `192.168.0.0/16`

---

## Generate unlimited practice

```bash
python3 - <<'PY'
import ipaddress, random
for _ in range(20):
    p = random.choice([16,17,18,19,20,21,22,23,24,25,26,27,28])
    base = ipaddress.IPv4Address(random.randint(167772160, 184549375))  # 10/8 - 11/8
    net = ipaddress.IPv4Network(f"{base}/{p}", strict=False)
    print(f"{net}  ->  net? bcast? total? aws-usable?")
    print(f"    [{net.network_address}] [{net.broadcast_address}] "
          f"[{net.num_addresses}] [{max(net.num_addresses-5,0)}]")
PY
```
