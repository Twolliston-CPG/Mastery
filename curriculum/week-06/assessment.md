# Week 6 Assessment

> Closed book, 35 min + 40 SAA practice questions from the reference library.

## Part A (15 min)
1. What makes a subnet public? Do not say "a checkbox."
2. Why must a NAT gateway live in a public subnet?
3. Why is the VPC main route table a trap?
4. SG vs NACL: five differences.
5. Why must a NACL have an inbound rule for ports 1024–65535?
6. Gateway endpoint vs interface endpoint: which services, what cost, what mechanism?
7. Name three advantages of SSM Session Manager over a bastion host.
8. In AWS, a blocked connection **times out** rather than being refused. Why, and what does that
   tell you diagnostically?
9. What does `AbortIncompleteMultipartUpload` prevent, and why is it invisible otherwise?
10. With versioning on, you delete 1 TB of objects. How much storage did you free?

## Part B — Design (10 min)
11. Design subnets for `10.60.0.0/16`: 3 AZs, public/app/data tiers, app must support 3,000 pods per
    AZ, ≥50% of the VPC left free. Give the table.
12. An app in a private subnet only talks to S3 and DynamoDB. How much NAT gateway do you need, and
    what do you use instead?
13. How do you make a bucket readable *only* from inside your VPC, even with valid credentials?

## Part C — Diagnose (10 min)
14. Private instance can't reach the internet. Five checks, in order.
15. `aws s3 ls s3://bucket` fails but `aws s3 cp s3://bucket/file .` works. Why?
16. An object upload succeeds but download returns AccessDenied. Why?
17. You enabled Flow Logs and see nothing at all for a failing connection. What does that tell you?
18. Someone reports your "private" database subnet has internet access. What happened?

---

# Answer key

**A1.** Its route table contains a route to an **internet gateway**. It's a property of routing.
`map_public_ip_on_launch` is orthogonal — it assigns public IPs but doesn't create reachability.

**A2.** The NAT gateway *is* the router, and a router needs its own route to the destination. In a
private subnet its default route would point at a NAT gateway — itself or nothing. (BF-27)

**A3.** Every subnet is **implicitly associated with the main route table** unless explicitly
associated elsewhere. Add an IGW route to it and every unassociated subnet silently becomes public.
Defensive pattern: keep the main route table with no default route and associate every subnet
explicitly, so mistakes fail closed.

**A4.** SG: stateful · allow-only · attaches to an ENI · all rules evaluated together (no order) ·
default deny-all inbound, allow-all outbound. NACL: **stateless** · allow **and** deny · attaches to
a subnet · **numbered, first match wins** · default allows all.

**A5.** Because it's stateless. A client's response arrives on a random high source port with no
connection state to match, so you must allow the ephemeral range explicitly. The #1 NACL mistake.

**A6.** **Gateway** — S3 and DynamoDB **only**, free, implemented as a prefix-list route in the route
table. **Interface** — most other services, an ENI in your subnets, ~$7/mo per endpoint per AZ plus
per-GB.

**A7.** No inbound ports open at all · no SSH keys to distribute or rotate · CloudTrail audit
automatically · no bastion instance to patch or pay for · works in fully private subnets via VPC
endpoints. (Any three.)

**A8.** SG and NACL denies behave like an iptables **DROP** — the packet is silently discarded, no
RST. So the client waits for its own timeout. Diagnostically: **timeout ⇒ suspect a security group,
NACL, or routing. Connection refused ⇒ you reached the host and nothing was listening.** That
bisection saves a lot of time.

**A9.** Orphaned parts from failed multipart uploads. They bill at full Standard rate indefinitely
and **do not appear in the console's object listing**, so teams find them years later as an
unexplained cost line.

**A10.** **Zero.** With versioning enabled, a delete adds a *delete marker*; the previous versions
remain and keep billing. You need `NoncurrentVersionExpiration` (and to delete the versions) to
actually free storage.

---

**B11.** App tier binds the design: 3,000 pods + nodes + headroom → next power of two is 4,096 →
`/20` (4,091 usable).

| Subnet | CIDR | Usable |
|---|---|---|
| public-a/b/c | 10.60.0.0/24, 10.60.1.0/24, 10.60.2.0/24 | 251 each |
| data-a/b/c | 10.60.3.0/24, 10.60.4.0/24, 10.60.5.0/24 | 251 each |
| app-a | 10.60.16.0/20 | 4,091 |
| app-b | 10.60.32.0/20 | 4,091 |
| app-c | 10.60.48.0/20 | 4,091 |
| **free** | 10.60.64.0/18 + 10.60.128.0/17 | **~49,000 (75%)** |

Justify: public subnets hold only NAT/ALB ENIs so a `/24` is generous; app subnets are large because
the VPC CNI consumes one IP per pod; the free space matters because a VPC CIDR can't be shrunk and
overlapping CIDRs block peering forever.

**B12.** **None.** Use an **S3 gateway endpoint and a DynamoDB gateway endpoint** — both free, both
route-table entries. That removes the ~$32/month/AZ NAT cost plus all per-GB processing, and keeps
the traffic off the internet entirely.

**B13.** A bucket policy with
`"Condition": {"StringNotEquals": {"aws:SourceVpce": "vpce-xxx"}}` on a `Deny`. Then even valid
credentials used from outside the VPC are refused. (`aws:SourceIp` will not work — endpoint traffic
has no public source IP.)

---

**C14.** (1) Private route table has `0.0.0.0/0 → nat-xxx`? (2) Is the NAT in a **public** subnet
with an IGW route? (3) Is the NAT `available` with an EIP? (4) Does the instance SG allow egress?
(5) NACL missing the ephemeral inbound return rule?

**C15.** `s3:ListBucket` acts on the **bucket** ARN; `s3:GetObject` acts on the **object** ARN. The
policy grants the object permission but not the bucket-level list permission.

**C16.** **KMS.** The bucket has SSE-KMS default encryption. Uploading needs
`kms:GenerateDataKey`; downloading needs `kms:Decrypt` — and both must be granted by the **key
policy** as well as IAM. The asymmetry is the tell. (BF-26)

**C17.** The traffic never reached the network interface — so the failure is *before* the packet is
sent. Almost always **DNS** (name never resolved, so no connection was attempted), or the client
never tried. Flow Logs record what arrives at the ENI; silence means nothing arrived.

**C18.** Most likely the subnet was never explicitly associated with a route table, so it inherited
the **main route table** — and someone added an IGW route to it. (Alternatively: an explicit IGW
route was added to the data route table, or an instance there has a public IP *and* the route.)

## Scoring
| | |
|---|---|
| 16–18 | Move on. |
| 12–15 | Redo Lab 2 (SG vs NACL) and Lab 3 (endpoints). |
| < 12 | **Rebuild the VPC from scratch, timed.** Weeks 7, 13, and 16 all sit on this. |

Plus **≥ 70%** on the 40 SAA practice questions.
