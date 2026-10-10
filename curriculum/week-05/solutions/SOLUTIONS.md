# Week 5 Solutions

Policy JSON files: [`policies/`](policies/)

---

## Lab 2 — The six policies

### 1. Read-only on `reports/*`
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": "s3:GetObject",
    "Resource": "arn:aws:s3:::BUCKET/reports/*"
  }]
}
```

### 2. Read+write on `reports/*`, read-only elsewhere
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadAll",
      "Effect": "Allow",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::BUCKET/*"
    },
    {
      "Sid": "WriteReportsOnly",
      "Effect": "Allow",
      "Action": ["s3:PutObject", "s3:DeleteObject"],
      "Resource": "arn:aws:s3:::BUCKET/reports/*"
    }
  ]
}
```

### 3. Full access except `private/*` — requires an explicit Deny
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:*",
      "Resource": ["arn:aws:s3:::BUCKET", "arn:aws:s3:::BUCKET/*"]
    },
    {
      "Sid": "DenyPrivate",
      "Effect": "Deny",
      "Action": "s3:*",
      "Resource": "arn:aws:s3:::BUCKET/private/*"
    }
  ]
}
```
**You cannot express "everything except X" with Allow alone.** An explicit `Deny` is required, and
it beats every Allow anywhere — including one in a different policy, a resource policy, or a
cross-account grant. That is rule #1 of the evaluation order.

### 4. Source-IP restriction
```json
{
  "Effect": "Allow",
  "Action": "s3:GetObject",
  "Resource": "arn:aws:s3:::BUCKET/*",
  "Condition": {
    "IpAddress": {"aws:SourceIp": ["203.0.113.0/24"]}
  }
}
```
**Caveat worth knowing:** `aws:SourceIp` refers to the *public* IP of the caller. A request arriving
through a **VPC endpoint** has no public IP, so this condition never matches and the request is
denied. For VPC traffic use `aws:SourceVpce` or `aws:SourceVpc` instead. This trips people up
constantly.

### 5. TLS-only — usually written as a Deny in the **bucket** policy
```json
{
  "Sid": "DenyInsecureTransport",
  "Effect": "Deny",
  "Principal": "*",
  "Action": "s3:*",
  "Resource": ["arn:aws:s3:::BUCKET", "arn:aws:s3:::BUCKET/*"],
  "Condition": {"Bool": {"aws:SecureTransport": "false"}}
}
```
Putting it in the **bucket policy** as a Deny means it applies to every principal, including
cross-account and anonymous, regardless of what their identity policy says. This exact statement is
a CIS benchmark control and `checkov` will flag its absence in week 11.

### 6. ListBucket — the most common mistake
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ListOnlyReportsPrefix",
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::BUCKET",
      "Condition": {"StringLike": {"s3:prefix": ["reports/*", "reports/"]}}
    },
    {
      "Effect": "Allow",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::BUCKET/reports/*"
    }
  ]
}
```
**`s3:ListBucket` acts on the BUCKET ARN (no `/*`). `s3:GetObject` acts on the OBJECT ARN (with
`/*`).** Getting this backwards means `aws s3 ls` fails while `aws s3 cp` works, or vice versa, and
it is the single most common S3 policy bug.

Note the difference in error too: a denied `GetObject` on an object that exists returns
**AccessDenied**, but if you lack `ListBucket`, S3 returns **404 NoSuchKey** even for objects that
do exist — deliberately, so you can't enumerate a bucket by probing. That's a great detail to know.

---

## Lab 3 — Roles

### Trust vs permissions — the diagnostic

| Error | Which policy |
|---|---|
| `User X is not authorized to perform: sts:AssumeRole on resource: role/Y` | **Either**: A's trust policy doesn't name X, **or** X's identity policy doesn't allow `sts:AssumeRole`. Check both. |
| Assume succeeds, then the API call is denied | **Permissions policy** on the role |

Cross-account assume-role requires **both sides**:
```json
// Account A -- the role's TRUST policy
{"Effect":"Allow","Principal":{"AWS":"arn:aws:iam::B:root"},"Action":"sts:AssumeRole"}
```
```json
// Account B -- the caller's IDENTITY policy
{"Effect":"Allow","Action":"sts:AssumeRole","Resource":"arn:aws:iam::A:role/TheRole"}
```
`Principal: {"AWS": "arn:aws:iam::B:root"}` does **not** mean the root user — it means "delegate to
account B, which may then grant this to any of its principals." That naming is confusing and is
worth stating correctly.

### ExternalId and the confused deputy

A SaaS vendor's account assumes a role in *many* customers' accounts. Without `ExternalId`, if you
know the vendor's role ARN and a victim's role ARN, you could trick the vendor into assuming the
victim's role on your behalf. `ExternalId` is a per-customer shared secret in the trust policy's
condition that the vendor must supply:

```json
{
  "Effect": "Allow",
  "Principal": {"AWS": "arn:aws:iam::VENDOR:root"},
  "Action": "sts:AssumeRole",
  "Condition": {"StringEquals": {"sts:ExternalId": "customer-specific-uuid"}}
}
```

**Any time you grant a third party access to your AWS account, you should see an ExternalId.** If a
vendor doesn't use one, that's a finding.

### Permission boundaries

**Effective permissions = identity policy ∩ boundary.** A boundary never grants anything; it only
caps. This is what makes safe IAM delegation possible:

```json
{
  "Effect": "Allow",
  "Action": ["iam:CreateRole", "iam:AttachRolePolicy"],
  "Resource": "*",
  "Condition": {
    "StringEquals": {"iam:PermissionsBoundary": "arn:aws:iam::ACCT:policy/DevBoundary"}
  }
}
```
Developers can create roles — but only roles that carry the boundary, so they cannot escalate beyond
it. Without that condition, "let developers create IAM roles" is equivalent to giving them
administrator.

---

## Lab 4 — EC2

### Making user data debuggable

```bash
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1
```
This one line sends all output to a log file, to syslog, **and** to the EC2 serial console — so
`aws ec2 get-console-output` shows it even when you can't SSH in. Without it, "my user data didn't
run" is undebuggable.

```bash
aws ec2 get-console-output --instance-id i-xxx --output text | tail -50
# On the instance:
sudo cat /var/log/cloud-init-output.log
```

**User data runs once, on first boot, as root, and only if cloud-init is present.** To re-run it for
testing: `sudo cloud-init clean --logs && sudo cloud-init init && sudo cloud-init modules --mode=final`.

### Security group referencing

```bash
aws ec2 authorize-security-group-ingress --group-id sg-app \
  --protocol tcp --port 8080 --source-group sg-web
```
Referencing the **source SG ID** instead of a CIDR means: the rule follows instances as they're
replaced, it survives IP changes, it works across AZs automatically, and it is self-documenting
("traffic from the web tier"). A CIDR-based rule has to be updated whenever the network changes.

This is also the answer to BF-28 (ALB returns 503): the instance SG must allow the **ALB's SG**, not
a CIDR.

### gp3 vs gp2 — the one-line answer

gp3 decouples IOPS and throughput from volume size (3,000 IOPS and 125 MB/s baseline at *any* size,
independently tunable). gp2 tied IOPS to size at 3 IOPS/GB, so teams provisioned 1 TB volumes they
didn't need just to get 3,000 IOPS. **gp3 is both cheaper and more flexible — it is the default
answer.**

---

## Lab 5 — Instance profiles and IMDSv2

### The credential chain, in order

The AWS SDKs look for credentials in this sequence:
1. Explicit parameters in code
2. Environment variables (`AWS_ACCESS_KEY_ID`, …)
3. `~/.aws/credentials` (the shared credentials file)
4. `~/.aws/config` (with `role_arn` / `source_profile`)
5. Container credentials (ECS task role / EKS Pod Identity)
6. **Instance metadata service (IMDS)** ← the EC2 instance profile
7. Fail

That is why `aws s3 ls` works on an instance with no credentials file: the chain falls through to
IMDS, which hands back temporary STS credentials that auto-rotate. **Knowing the chain order is also
how you debug "it used the wrong account"** — usually a stale `AWS_PROFILE` env var shadowing what
you expected.

### IMDSv2, precisely

```bash
# v1 -- a single unauthenticated GET
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/RoleName

# v2 -- requires a PUT to obtain a session token first
TOKEN=$(curl -sX PUT http://169.254.169.254/latest/api/token \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/...
```

**Why v2 defends against SSRF:** a server-side request forgery vulnerability lets an attacker make
the application fetch an arbitrary URL. With IMDSv1 that's a single GET to `169.254.169.254` and the
attacker has the instance role's credentials. IMDSv2 requires:
- an HTTP **PUT** (most SSRF primitives only do GET),
- a **custom header** (most SSRF primitives can't set one),
- and `HttpPutResponseHopLimit=1` means the response won't traverse a proxy or a container network
  hop.

Enforce it everywhere:
```bash
aws ec2 modify-instance-metadata-options --instance-id i-xxx \
  --http-tokens required --http-put-response-hop-limit 1
```

**In Kubernetes, set the hop limit to 1 and additionally block pod access to IMDS entirely**,
because otherwise any pod can assume the *node's* role — which is precisely the problem IRSA solves
(week 16).

### BF-26 — the KMS answer

```bash
aws s3api head-object --bucket BUCKET --key reports/q1.txt
# "ServerSideEncryption": "aws:kms", "SSEKMSKeyId": "arn:aws:kms:..."
```

Reading a KMS-encrypted object requires **`kms:Decrypt` granted by both the IAM policy and the key
policy**. Writing requires `kms:GenerateDataKey`. The key policy is a separate gate that IAM cannot
override — an IAM policy saying `kms:*` on `*` does nothing if the key policy doesn't include the
principal.

**The asymmetry is the tell:** uploads sometimes work while downloads fail, because they need
different KMS actions.

```json
// key policy statement
{
  "Sid": "AllowAppRole",
  "Effect": "Allow",
  "Principal": {"AWS": "arn:aws:iam::ACCT:role/AppRole"},
  "Action": ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"],
  "Resource": "*"
}
```

**"S3 AccessDenied even though S3 permissions are correct" is a great interview answer** because
it's real, common, and non-obvious. Naming KMS — and knowing the key policy is a separate gate —
reads as someone who has operated encrypted storage.

---

## Cost check

```bash
aws ce get-cost-and-usage \
  --time-period Start=$(date -u -v-7d +%F 2>/dev/null || date -u -d '7 days ago' +%F),End=$(date -u +%F) \
  --granularity DAILY --metrics UnblendedCost \
  --group-by Type=DIMENSION,Key=SERVICE \
  --query 'ResultsByTime[-1].Groups[?Metrics.UnblendedCost.Amount!=`0`].[Keys[0],Metrics.UnblendedCost.Amount]' \
  --output table
```
Run this every Monday. Week 5 should be **under $3**.
