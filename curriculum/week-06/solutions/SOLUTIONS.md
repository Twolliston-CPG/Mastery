# Week 6 Solutions

---

## Lab 1 — VPC

### Why the main route table is a trap

Every subnet is **implicitly associated with the VPC's main route table** unless you explicitly
associate another one. So if someone adds an IGW route to the main route table "temporarily," every
unassociated subnet in the VPC silently becomes public — including your database tier.

**The defensive pattern:** leave the main route table with no `0.0.0.0/0` route at all, and
explicitly associate every subnet with a purpose-built route table. Then a forgotten association
fails closed instead of open. Saying this in an interview is a real signal.

### The full build script

```bash
#!/usr/bin/env bash
set -euo pipefail
REGION=us-east-1
CIDR=10.20.0.0/16

VPC_ID=$(aws ec2 create-vpc --cidr-block $CIDR \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=lab-vpc}]' \
  --query Vpc.VpcId --output text)
aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-hostnames
aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-support

IGW_ID=$(aws ec2 create-internet-gateway --query InternetGateway.InternetGatewayId --output text)
aws ec2 attach-internet-gateway --vpc-id "$VPC_ID" --internet-gateway-id "$IGW_ID"

declare -A SUBNETS=(
  [public-a]="10.20.0.0/24:${REGION}a"
  [public-b]="10.20.1.0/24:${REGION}b"
  [data-a]="10.20.3.0/24:${REGION}a"
  [data-b]="10.20.4.0/24:${REGION}b"
  [app-a]="10.20.16.0/20:${REGION}a"
  [app-b]="10.20.32.0/20:${REGION}b"
)
declare -A IDS
for name in "${!SUBNETS[@]}"; do
  IFS=: read -r cidr az <<< "${SUBNETS[$name]}"
  IDS[$name]=$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block "$cidr" \
    --availability-zone "$az" \
    --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$name}]" \
    --query Subnet.SubnetId --output text)
  echo "$name -> ${IDS[$name]} ($cidr in $az)"
done

RTB_PUB=$(aws ec2 create-route-table --vpc-id "$VPC_ID" \
  --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=rtb-public}]' \
  --query RouteTable.RouteTableId --output text)
aws ec2 create-route --route-table-id "$RTB_PUB" --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW_ID"
for s in public-a public-b; do
  aws ec2 associate-route-table --route-table-id "$RTB_PUB" --subnet-id "${IDS[$s]}" >/dev/null
  aws ec2 modify-subnet-attribute --subnet-id "${IDS[$s]}" --map-public-ip-on-launch
done

RTB_DATA=$(aws ec2 create-route-table --vpc-id "$VPC_ID" \
  --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=rtb-data}]' \
  --query RouteTable.RouteTableId --output text)
for s in data-a data-b; do
  aws ec2 associate-route-table --route-table-id "$RTB_DATA" --subnet-id "${IDS[$s]}" >/dev/null
done
echo "VPC $VPC_ID ready. Data tier has NO default route -- that is deliberate."
```

**Why the data tier has no `0.0.0.0/0` at all:** a database should never need to initiate an outbound
internet connection. Denying it by *routing* rather than by firewall rule means even a
misconfigured security group can't create an exfiltration path. It's defense in depth, and it's a
better answer than "I'd put it in a private subnet."

### The answer to "what makes a subnet public?"

> A subnet is public **if and only if its route table has a route to an internet gateway.** It is a
> property of routing, not a checkbox. `map_public_ip_on_launch` is orthogonal — it assigns instances
> a public IP. An instance with a public IP in a subnet with no IGW route is unreachable; an
> instance with no public IP in a public subnet can reach out via NAT but can't be reached inbound.

---

## Lab 2 — NAT, bastion, SG vs NACL

### Why the NAT gateway must be in a public subnet (BF-27)

Exactly the week-3 namespace lab. The NAT device **is the router**; a router must itself have a
route to the destination. A NAT gateway in a private subnet has a default route pointing at... a NAT
gateway. Itself, or nothing. There is nowhere for the packet to go.

```
private instance -> route table 0.0.0.0/0 -> nat-gw
                                              |
                                    nat-gw is in public subnet
                                              |
                                    route table 0.0.0.0/0 -> igw -> internet
```

**The checklist when a private instance can't reach the internet:**
1. Does the private subnet's route table have `0.0.0.0/0 → nat-xxx`?
2. Is the NAT gateway in a **public** subnet (one with an IGW route)?
3. Does the NAT gateway have an Elastic IP and is it `available`?
4. Does the instance SG allow egress? (Default allows all, but people restrict it.)
5. Is there a NACL missing the ephemeral-port inbound return rule?

### SG vs NACL — the full mapping

| Week 3 Linux concept | AWS | Why |
|---|---|---|
| `iptables -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT` | **Security Group** | Stateful — return traffic is automatic and you cannot turn it off |
| Numbered iptables rules, first match wins, DROP+ACCEPT | **NACL** | Stateless, ordered, has deny, requires an explicit ephemeral-port egress/ingress rule |
| `MASQUERADE` / SNAT | **NAT Gateway** | |
| Default route to the router | **Route table `0.0.0.0/0 → igw`** | |
| DROP vs REJECT | SG/NACL deny behaves like DROP — timeouts, not refusals | Which is why a blocked AWS connection **hangs** rather than failing fast |

That last row is a practical diagnostic: a connection that **times out** in AWS is usually a security
group or NACL; a connection **refused** means you reached the host and nothing was listening.

### The NACL ephemeral-port rule

```bash
aws ec2 create-network-acl-entry --network-acl-id $ACL --rule-number 100 --egress \
  --protocol tcp --port-range From=1024,To=65535 --cidr-block 0.0.0.0/0 --rule-action allow
```
A client connecting to your port 80 uses a random high source port. The response goes back to *that*
port, and since NACLs are stateless there's no connection state to match on — you must allow the
whole ephemeral range explicitly. **This is the #1 NACL mistake** and the reason most teams use NACLs
only as coarse subnet-level guardrails rather than primary access control.

### SSM Session Manager over a bastion

```bash
aws ssm start-session --target i-xxx
aws ssm start-session --target i-xxx \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["5432"],"localPortNumber":["15432"]}'
```

| Bastion | Session Manager |
|---|---|
| Port 22 open to something | **No inbound ports at all** |
| SSH keys to distribute and rotate | IAM permissions |
| Audit = whatever you set up | CloudTrail, automatically |
| An instance to patch and pay for | No instance |

It works in fully private subnets given the SSM VPC endpoints from Lab 3. **"I'd use Session
Manager rather than a bastion" is a strong, current answer** and a lot of candidates never mention it.

---

## Lab 3 — Endpoints

### The cost argument, with numbers

| Option | Monthly cost | Notes |
|---|---|---|
| NAT gateway | ~$32/mo per AZ + **$0.045/GB processed** | 1 TB of S3 traffic = +$45 |
| S3 **gateway** endpoint | **$0** | No hourly, no data charge |
| Interface endpoint | ~$7/mo per endpoint per AZ + $0.01/GB | Needed for non-S3/DynamoDB services |

An application in a private subnet whose only external dependency is S3 needs **no NAT gateway at
all**. That's a real, defensible cost optimization and a good FinOps answer.

There's a security argument too: traffic to a gateway endpoint never traverses the internet, and you
can put a condition on the bucket policy restricting access to `aws:SourceVpce` — so even a leaked
credential can't read the bucket from outside your VPC.

```json
{
  "Effect": "Deny",
  "Principal": "*",
  "Action": "s3:*",
  "Resource": ["arn:aws:s3:::BUCKET", "arn:aws:s3:::BUCKET/*"],
  "Condition": {"StringNotEquals": {"aws:SourceVpce": "vpce-0abc123"}}
}
```
**This is also why `aws:SourceIp` fails for endpoint traffic** (week 5, A10) — there is no public
source IP.

### Flow Log fields worth knowing

```
version account-id interface-id srcaddr dstaddr srcport dstport protocol
packets bytes start end action log-status
```
`action` is `ACCEPT` or `REJECT`. `log-status` of `NODATA` means no traffic; `SKIPDATA` means records
were dropped due to capacity.

**What Flow Logs can and cannot tell you:** they show whether a packet arrived and whether the
SG/NACL allowed it. They do **not** show payloads, and they do not show traffic that never left the
source (e.g. a DNS failure means the connection was never attempted, so there is nothing in Flow
Logs at all). That absence is itself diagnostic.

---

## Lab 4 & 5 — S3

### The lifecycle policy people forget

```json
{
  "Rules": [
    {
      "ID": "tiering",
      "Status": "Enabled",
      "Filter": {"Prefix": ""},
      "Transitions": [
        {"Days": 30,  "StorageClass": "STANDARD_IA"},
        {"Days": 90,  "StorageClass": "GLACIER"},
        {"Days": 365, "StorageClass": "DEEP_ARCHIVE"}
      ],
      "NoncurrentVersionTransitions": [{"NoncurrentDays": 30, "StorageClass": "GLACIER"}],
      "NoncurrentVersionExpiration": {"NoncurrentDays": 365},
      "AbortIncompleteMultipartUpload": {"DaysAfterInitiation": 7}
    }
  ]
}
```

**`AbortIncompleteMultipartUpload` is the one that surprises people.** A failed 5 GB upload leaves
parts that bill at full Standard rate, forever, and **do not appear in the console's object list**.
Teams discover them years later as an unexplained line item. Every production bucket should have this
rule.

**Second surprise:** with versioning on, deleting an object doesn't free any storage — it adds a
delete marker and the old version keeps billing. You need `NoncurrentVersionExpiration` too.

### Storage class decision table

| Access pattern | Class |
|---|---|
| Frequent, unknown duration | Standard |
| **Unpredictable / changing** | **Intelligent-Tiering** — auto-moves, small monitoring fee, no retrieval charge |
| Infrequent, needs millisecond access | Standard-IA (min 30 days, retrieval fee) |
| Infrequent + recreatable | One Zone-IA (20% cheaper, **single AZ** — lose an AZ, lose the data) |
| Archive, occasional instant access | Glacier Instant Retrieval |
| Archive, minutes-to-hours OK | Glacier Flexible |
| Compliance archive, 12h OK | Deep Archive (cheapest by far) |

**The trap on the exam and in real life:** IA classes have a **30-day minimum billing duration** and a
**per-GB retrieval charge**. Moving objects that get read frequently to Standard-IA *increases* your
bill. Intelligent-Tiering exists precisely because most people guess wrong about access patterns.

### Block Public Access layering

Account-level settings **override** bucket-level. Turn all four on at the account level:
`BlockPublicAcls`, `IgnorePublicAcls`, `BlockPublicPolicy`, `RestrictPublicBuckets`.

Then serve public content via **CloudFront with Origin Access Control**, keeping the bucket private:
```json
{
  "Effect": "Allow",
  "Principal": {"Service": "cloudfront.amazonaws.com"},
  "Action": "s3:GetObject",
  "Resource": "arn:aws:s3:::BUCKET/*",
  "Condition": {"StringEquals": {"AWS:SourceArn": "arn:aws:cloudfront::ACCT:distribution/DIST_ID"}}
}
```
**"I wouldn't make the bucket public — I'd use CloudFront with OAC"** is the correct modern answer,
and it also gets you caching, TLS, and WAF.

### Presigned URLs

```bash
aws s3 presign "s3://$B/file.txt" --expires-in 300
```
A presigned URL carries the **signature of the principal who created it** and that principal's
permissions. Two consequences worth knowing:
- If you generate it with a long-lived user's credentials, it stays valid until the expiry no matter
  what — revoking the user later doesn't invalidate issued URLs.
- If you generate it from a **role**, the URL dies when the role's temporary credentials expire, even
  if you asked for a longer expiry. That surprises people who generate 7-day URLs from a Lambda.
