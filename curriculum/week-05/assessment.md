# Week 5 Assessment

> Closed book, 40 min. Plus 30 SAA-style practice questions from
> `_reference/aws/phase-1-foundations-practice-questions-questions.md`.

## Part A — IAM (20 min)
1. Recite the IAM policy evaluation order. All seven steps.
2. What are the two policies attached to a role, and which question does each answer?
3. `AccessDenied` on `sts:AssumeRole` — which policy, and what are the two possible causes?
4. What does a permission boundary do? Does it grant anything?
5. How do you let developers create IAM roles without letting them escalate to admin?
6. What is `ExternalId` for and what attack does it prevent?
7. `s3:ListBucket` and `s3:GetObject` — which ARN does each take, and what breaks if you swap them?
8. Why does a denied `GetObject` sometimes return 404 instead of AccessDenied?
9. Can you express "allow everything except one prefix" with Allow statements alone?
10. `aws:SourceIp` doesn't match for traffic arriving via a VPC endpoint. Why, and what do you use?

## Part B — EC2 and credentials (10 min)
11. List the AWS SDK credential chain in order.
12. How does an EC2 instance call AWS APIs with no credentials on disk?
13. IMDSv1 vs IMDSv2 — what changed and what attack does it stop?
14. What does `HttpPutResponseHopLimit=1` do and why does it matter in Kubernetes?
15. gp3 vs gp2 in one sentence.
16. Why reference a security group ID as a source instead of a CIDR? Give three reasons.
17. Your user data didn't run. How do you debug it without SSH?
18. Two things that keep billing after you terminate an instance.

## Part C — Diagnose (10 min)
19. A role has `s3:GetObject` allowed on the bucket. Downloads fail with AccessDenied. Uploads work.
    What is it?
20. You have `AdministratorAccess` attached and still cannot launch an EC2 instance. Three
    possibilities.

---

# Answer key

**A1.** (1) Explicit **Deny** anywhere → deny, always. (2) SCP doesn't allow → deny. (3) Resource
policy may allow on its own (cross-account). (4) Permission boundary doesn't allow → deny.
(5) Session policy doesn't allow → deny. (6) Identity policy allows → allow. (7) Otherwise implicit
deny.

**A2.** **Trust policy** — *who may assume this role?* **Permissions policy** — *what can this role
do?*

**A3.** The **trust** side of the transaction. Two causes: the role's trust policy doesn't name the
caller, **or** the caller's identity policy doesn't allow `sts:AssumeRole` on that role ARN.
Cross-account requires both.

**A4.** It caps the **maximum** permissions a principal can have. Effective = identity policy ∩
boundary. **It never grants anything** — a boundary alone gives zero access.

**A5.** Grant `iam:CreateRole`/`iam:AttachRolePolicy` with a condition requiring
`iam:PermissionsBoundary` equal to a specific boundary policy ARN. They can create roles, but only
capped ones. Without that condition, letting someone create roles is equivalent to giving them admin.

**A6.** The **confused deputy** problem. A SaaS vendor assumes roles in many customers' accounts; a
per-customer secret in the trust condition prevents one customer from tricking the vendor into
assuming another customer's role. Any third-party AWS integration should use one.

**A7.** `s3:ListBucket` → the **bucket** ARN (`arn:aws:s3:::bucket`, no `/*`).
`s3:GetObject` → the **object** ARN (`arn:aws:s3:::bucket/*`). Swap them and `aws s3 ls` fails while
`aws s3 cp` works, or vice versa — the most common S3 policy bug.

**A8.** Deliberate design: without `s3:ListBucket` you aren't allowed to learn whether a key exists,
so S3 returns 404 rather than 403 to prevent bucket enumeration by probing.

**A9.** **No.** You need an explicit `Deny`, which overrides every Allow anywhere — including
resource policies and cross-account grants.

**A10.** `aws:SourceIp` evaluates the caller's **public** IP. Traffic through a VPC endpoint never
leaves the AWS network and has no public source IP, so the condition can't match and the request is
denied. Use `aws:SourceVpce` or `aws:SourceVpc` instead.

---

**B11.** Explicit code parameters → environment variables → `~/.aws/credentials` →
`~/.aws/config` (role_arn/source_profile) → container credentials (ECS task role / EKS Pod
Identity) → **IMDS (instance profile)** → fail.

**B12.** An **instance profile** attaches an IAM role to the instance. IMDS at `169.254.169.254`
vends temporary STS credentials; the SDK picks them up at the end of the credential chain. They
rotate automatically and nothing is stored on disk.

**B13.** IMDSv1 was an unauthenticated GET. IMDSv2 requires a **PUT** with a custom header to obtain
a session token first. This stops **SSRF**: a vulnerability that makes the app fetch an
attacker-supplied URL can usually only issue a GET without custom headers, so it can no longer steal
the instance role's credentials.

**B14.** It limits the metadata response to a single network hop, so it won't traverse a proxy or a
container network bridge. In Kubernetes it prevents **pods** from reaching the node's IMDS and
assuming the node's role — which is exactly the problem IRSA solves.

**B15.** gp3 decouples IOPS and throughput from volume size (3,000 IOPS baseline at any size,
independently tunable); gp2 tied IOPS to size at 3 IOPS/GB. gp3 is cheaper and more flexible.

**B16.** (1) The rule follows instances as they're replaced — no IP churn. (2) It works across AZs
and subnets automatically. (3) It's self-documenting ("from the web tier"). Also: it's the correct
fix for an ALB 503 caused by the instance SG not allowing the ALB.

**B17.** `aws ec2 get-console-output --instance-id i-xxx`. And build for this in advance by adding
`exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1` to the top of the
script, so output reaches the serial console. On the instance: `/var/log/cloud-init-output.log`.

**B18.** **Unattached EBS volumes** and **unassociated Elastic IPs**. (Also: snapshots, AMIs, NAT
gateways, and load balancers — but those two are the classic surprises.)

---

**C19.** **KMS.** The bucket uses SSE-KMS with a customer-managed key. Reading requires
`kms:Decrypt` granted by **both** the IAM policy and the **key policy**; writing requires
`kms:GenerateDataKey`. The asymmetry (uploads working, downloads failing) is the tell. Confirm with
`aws s3api head-object` to see `SSEKMSKeyId`, then check the key policy.

**C20.** (1) A **permission boundary** caps the user below admin. (2) An **SCP** at the organization
level denies `ec2:RunInstances` (or the region, or the instance type). (3) An **explicit Deny** in
another attached policy — it beats the Allow. (Also possible: a **service control** on the instance
type, or you are not the principal you think you are — always run `aws sts get-caller-identity`
first.)

## Scoring
| | |
|---|---|
| 18–20 | Move on. |
| 14–17 | Re-read the IAM notes; redo Lab 2 policies 3 and 6. |
| < 14 | **Redo Labs 2 and 3.** IAM is load-bearing for weeks 12, 16, 19, and 23 — and it is the most-asked AWS interview topic. |

Plus: **≥ 70% on the 30 SAA practice questions.** Below that, you are behind the week-9 target.
