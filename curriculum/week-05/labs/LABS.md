# Week 5 Labs

> **Every lab ends with teardown.** Run `bash ../../_setup/03-teardown.sh` before you close the laptop.

---

# Lab 1 — Guardrails and the CLI (1h)

```bash
EMAIL=you@example.com bash ../../_setup/01-aws-guardrails.sh
```

Then the manual steps the script prints. Do all five.

## Test the alarm actually works
```bash
aws budgets describe-budgets --account-id $(aws sts get-caller-identity --query Account --output text)
```
An alarm you have never seen fire is not monitoring — it's a comforting decoration. You'll meet this
idea again in BF-32.

## CLI setup
```bash
aws configure --profile lab
aws configure list-profiles
export AWS_PROFILE=lab

aws sts get-caller-identity          # ALWAYS the first command when debugging IAM
aws ec2 describe-regions --query 'Regions[].RegionName' --output table
aws ec2 describe-availability-zones --query 'AvailabilityZones[].ZoneName' --output text

# Query syntax is worth 20 minutes now -- you'll use it for six months
aws ec2 describe-instances \
  --query 'Reservations[].Instances[].{ID:InstanceId,Type:InstanceType,State:State.Name}' \
  --output table
aws ec2 describe-instances --filters "Name=instance-state-name,Values=running"
```

**Tasks:** configure a profile, list regions, list AZs in two regions and note that AZ *names* are
randomized per account (`us-east-1a` is a different physical AZ for you than for me — AZ **IDs**
like `use1-az1` are the stable identifier). That detail matters for cross-account architecture and
is a nice thing to know.

---

# Lab 2 — IAM Policies From Scratch (3h)

## Part 1 — Anatomy

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadOneprefix",
      "Effect": "Allow",
      "Action": ["s3:GetObject"],
      "Resource": "arn:aws:s3:::my-bucket/reports/*",
      "Condition": {
        "StringEquals": {"s3:ExistingObjectTag/classification": "public"},
        "Bool": {"aws:SecureTransport": "true"}
      }
    }
  ]
}
```

**The five elements:** `Effect` · `Action` · `Resource` · `Principal` (resource policies only) ·
`Condition`.

**ARN structure — be able to write one from memory:**
```
arn:partition:service:region:account-id:resource
arn:aws:s3:::my-bucket/key                      # S3 omits region and account
arn:aws:iam::123456789012:role/MyRole           # IAM is global, no region
arn:aws:ec2:us-east-1:123456789012:instance/i-0abc123
```

## Part 2 — Build and test (this is the lab)

```bash
BUCKET="iam-lab-$(aws sts get-caller-identity --query Account --output text)"
aws s3 mb "s3://$BUCKET"
echo "public report"  | aws s3 cp - "s3://$BUCKET/reports/q1.txt"
echo "secret payroll" | aws s3 cp - "s3://$BUCKET/private/payroll.txt"
```

**Tasks — write each policy yourself, then test both the allow and the deny path:**

1. Read-only on `reports/*` only
2. Read+write on `reports/*`, read-only everywhere else in the bucket
3. Full access **except** `private/*` (requires an explicit `Deny`)
4. Access only from a specific source IP
5. Access only over TLS (deny when `aws:SecureTransport` is false)
6. Allow `s3:ListBucket` — note this is on the **bucket** ARN, not the object ARN. Getting this
   wrong is the most common S3 policy mistake.

```bash
# Create a test user with no permissions
aws iam create-user --user-name iam-lab-user
aws iam create-access-key --user-name iam-lab-user   # save the output

aws iam put-user-policy --user-name iam-lab-user \
  --policy-name test --policy-document file://policy.json

# Test as that user
AWS_PROFILE=iamlab aws s3 cp "s3://$BUCKET/reports/q1.txt" -        # should work
AWS_PROFILE=iamlab aws s3 cp "s3://$BUCKET/private/payroll.txt" -   # should be denied
```

## Part 3 — The policy simulator

```bash
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::ACCT:user/iam-lab-user \
  --action-names s3:GetObject s3:PutObject s3:DeleteObject \
  --resource-arns "arn:aws:s3:::$BUCKET/reports/q1.txt" \
  --query 'EvaluationResults[].{Action:EvalActionName,Decision:EvalDecision}' --output table
```

**Learn this tool now.** It answers "why is this denied" faster than any amount of reading, and
`--query` on `MatchedStatements` shows you exactly which statement decided.

## Part 4 — Memorize the evaluation order

```
1. Explicit DENY anywhere                 -> DENY.  Nothing ever overrides this.
2. SCP does not allow                     -> DENY   (organization guardrail)
3. Resource policy allows                 -> may grant on its own (cross-account)
4. Permission boundary does not allow     -> DENY   (a cap, not a grant)
5. Session policy does not allow          -> DENY
6. Identity policy allows                 -> ALLOW
7. Otherwise                              -> DENY   (implicit)
```

Write it out from memory every day this week until it's automatic. **It is asked in almost every AWS
interview**, and it is the framework for debugging every AccessDenied you will ever see.

---

# Lab 3 — Roles, Assume-Role, Boundaries (3h)

## Part 1 — Your first role

```bash
ACCT=$(aws sts get-caller-identity --query Account --output text)

cat > trust.json <<JSON
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"AWS": "arn:aws:iam::${ACCT}:user/iam-lab-user"},
    "Action": "sts:AssumeRole",
    "Condition": {"Bool": {"aws:MultiFactorAuthPresent": "false"}}
  }]
}
JSON

aws iam create-role --role-name LabReadOnly --assume-role-policy-document file://trust.json
aws iam attach-role-policy --role-name LabReadOnly \
  --policy-arn arn:aws:iam::aws:policy/ReadOnlyAccess

# Assume it
aws sts assume-role --role-arn "arn:aws:iam::${ACCT}:role/LabReadOnly" \
  --role-session-name lab --profile iamlab
```

**The two policies on a role — this distinction is essential:**
| | Question it answers |
|---|---|
| **Trust policy** (`AssumeRolePolicyDocument`) | *Who may become this role?* |
| **Permissions policy** (attached policies) | *What can this role do?* |

A role with permissions but no trust is unusable. A role with trust but no permissions can be assumed
and does nothing. **"AccessDenied on assume-role" is always the trust policy; "AccessDenied after
assuming" is always the permissions policy.** Being able to say that instantly is a strong signal.

## Part 2 — Profile-based role assumption

```ini
# ~/.aws/config
[profile lab]
region = us-east-1

[profile lab-readonly]
role_arn = arn:aws:iam::111122223333:role/LabReadOnly
source_profile = lab
region = us-east-1
```
```bash
aws s3 ls --profile lab-readonly
aws sts get-caller-identity --profile lab-readonly   # ARN shows assumed-role/LabReadOnly/...
```

## Part 3 — Cross-account (use two accounts, or simulate with two roles)

Build: account A has a role; account B's principal assumes it. **Both sides must agree** — A's trust
policy must name B, *and* B's identity policy must allow `sts:AssumeRole` on A's role ARN. Missing
either side fails.

Add an `ExternalId` condition and explain why it exists (the "confused deputy" problem — it's how
third-party SaaS vendors safely access your account).

## Part 4 — Permission boundaries

```bash
cat > boundary.json <<'JSON'
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["s3:*", "cloudwatch:*", "logs:*"],
    "Resource": "*"
  }]
}
JSON
aws iam create-policy --policy-name DevBoundary --policy-document file://boundary.json
aws iam put-user-permissions-boundary --user-name iam-lab-user \
  --permissions-boundary arn:aws:iam::ACCT:policy/DevBoundary
```

Now attach `AdministratorAccess` to that user and try to launch an EC2 instance. **It fails.** The
boundary caps the *maximum*; the effective permission is the **intersection** of identity policy and
boundary.

**This is how you safely let developers create their own IAM roles** — you require that every role
they create carries a boundary, so they cannot escalate beyond it. That's a genuinely good answer to
"how do you delegate IAM safely?"

---

# Lab 4 — EC2, EBS, AMIs, Security Groups (3h · ~$1)

## Part 1 — Launch with user data

```bash
cat > userdata.sh <<'UD'
#!/bin/bash
set -euxo pipefail
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

dnf install -y docker
systemctl enable --now docker
docker run -d --name web -p 80:80 --restart=always nginx:alpine
echo "user-data finished at $(date)" >> /var/log/user-data.log
UD

aws ec2 run-instances \
  --image-id resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --instance-type t3.micro \
  --key-name your-key \
  --security-group-ids sg-xxx \
  --user-data file://userdata.sh \
  --metadata-options "HttpTokens=required,HttpPutResponseHopLimit=1" \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=lab-web},{Key=Environment,Value=lab}]'
```

**Two details worth noting now:**
- `resolve:ssm:/aws/service/ami-amazon-linux-latest/...` avoids hardcoding an AMI ID that goes stale
  and differs per region. You'll reuse this in Terraform.
- `HttpTokens=required` enforces **IMDSv2**. Do this on every instance from now on — see Lab 5.

**Tasks:**
1. Launch it, `curl` the public IP
2. Read `/var/log/user-data.log` — the `exec > >(tee ...)` line is what makes user data debuggable,
   and it is the answer to "my user data didn't run" (BF-29)
3. Break the user data deliberately and diagnose with `aws ec2 get-console-output`

## Part 2 — EBS

```bash
aws ec2 create-volume --size 10 --volume-type gp3 --availability-zone us-east-1a
aws ec2 attach-volume --volume-id vol-xxx --instance-id i-xxx --device /dev/sdf
# on the instance:
lsblk && sudo mkfs.ext4 /dev/nvme1n1 && sudo mkdir /data && sudo mount /dev/nvme1n1 /data
```

**Tasks:** snapshot the volume, create a new volume from the snapshot, attach and verify the data.
Then modify the volume to 20 GB **while attached** and grow the filesystem with `resize2fs` — that's
a real operational task.

**gp3 vs gp2 in one line:** gp3 decouples IOPS and throughput from size (3,000 IOPS baseline at any
size); gp2 scales IOPS *with* size (3 IOPS/GB), so people over-provisioned storage just to get IOPS.
gp3 is cheaper and the default choice.

## Part 3 — AMIs and security groups

```bash
aws ec2 create-image --instance-id i-xxx --name "lab-web-$(date +%s)" --no-reboot
```

Security group tasks:
1. Create a web SG allowing 80/443 from `0.0.0.0/0`
2. Create an app SG allowing 8080 **from the web SG's ID**, not a CIDR
3. Verify that referencing an SG as a source works and understand why it's better than a CIDR
4. Add an inbound rule and observe that the return traffic needs no rule — **stateful**. Connect this
   to week 3's conntrack lab.

---

# Lab 5 — Instance Profiles, IMDSv2, Break/Fix (3h)

## Part 1 — No credentials on disk

```bash
aws iam create-role --role-name EC2S3Reader --assume-role-policy-document '{
  "Version":"2012-10-17",
  "Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},
                "Action":"sts:AssumeRole"}]}'
aws iam attach-role-policy --role-name EC2S3Reader \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess
aws iam create-instance-profile --instance-profile-name EC2S3Reader
aws iam add-role-to-instance-profile --instance-profile-name EC2S3Reader --role-name EC2S3Reader
aws ec2 associate-iam-instance-profile --instance-id i-xxx \
  --iam-instance-profile Name=EC2S3Reader
```

On the instance:
```bash
ls ~/.aws 2>/dev/null          # nothing
aws s3 ls                      # WORKS
aws sts get-caller-identity    # assumed-role/EC2S3Reader/i-0abc...
```

## Part 2 — See the mechanism

```bash
# IMDSv2: you must get a token first
TOKEN=$(curl -sX PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/iam/security-credentials/
curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/iam/security-credentials/EC2S3Reader | jq
# -> AccessKeyId, SecretAccessKey, Token, Expiration

# IMDSv1 (a plain GET) -- should FAIL if HttpTokens=required
curl -s --max-time 3 http://169.254.169.254/latest/meta-data/ ; echo "rc=$?"
```

**Tasks:**
1. Get credentials via IMDSv2 and confirm the expiry is a few hours out
2. Launch an instance with `HttpTokens=optional` and show that a plain GET works
3. **Write down why that is dangerous:** an SSRF vulnerability in a web app — anything that makes the
   app fetch an attacker-supplied URL — becomes credential theft with a single GET to
   `169.254.169.254`. IMDSv2's PUT-for-token requirement plus `HopLimit=1` closes it, because a
   naive SSRF can't issue a PUT with a custom header.

**This is the connection that makes the answer memorable in an interview:** an AWS feature, a real
vulnerability class, and a specific mitigation.

## Part 3 — Break/Fix

**BF-25** (AccessDenied despite an allow) and **BF-26** (S3 works, KMS doesn't).

For BF-26, build it:
```bash
aws kms create-key --description "lab key" --query 'KeyMetadata.KeyId' --output text
aws s3api put-bucket-encryption --bucket "$BUCKET" \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":
    {"SSEAlgorithm":"aws:kms","KMSMasterKeyID":"KEY-ID"}}]}'
# Now try to read as a principal with full S3 access but no KMS permissions.
```

## Teardown — do it now
```bash
bash ../../_setup/03-teardown.sh
aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].InstanceId' --output text
aws ec2 describe-volumes --filters "Name=status,Values=available" \
  --query 'Volumes[].VolumeId' --output text     # unattached volumes STILL BILL
```
**Unattached EBS volumes and unassociated Elastic IPs are the two things people forget.** Both bill.
