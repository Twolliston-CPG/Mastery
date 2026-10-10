# Break/Fix: AWS (BF-25 – BF-32)

---

## BF-25 — AccessDenied despite an "allow" policy

**SYMPTOM:** Role has `s3:GetObject` allowed, but the call returns `AccessDenied`.

**DIAGNOSIS — walk the evaluation chain in this exact order:**
```bash
aws sts get-caller-identity                       # WHO am I actually?
aws iam simulate-principal-policy \
  --policy-source-arn <role-arn> \
  --action-names s3:GetObject \
  --resource-arns arn:aws:s3:::bucket/key
aws s3api get-bucket-policy --bucket <bucket>     # resource policy
aws organizations describe-policy --policy-id <scp-id>   # SCP
```
Then read CloudTrail — the `errorMessage` names the deny type.

**IAM POLICY EVALUATION LOGIC — memorize this, it is asked constantly:**
```
1. Explicit DENY anywhere                    -> DENY. Always. Nothing overrides it.
2. SCP does not allow                        -> DENY (org guardrail)
3. Resource policy allows (cross-account)    -> may grant on its own
4. Permission boundary does not allow        -> DENY
5. Session policy does not allow             -> DENY
6. Identity policy allows                    -> ALLOW
7. Otherwise (implicit deny)                 -> DENY
```

**THE FIVE CAUSES, in real-world frequency:**
1. You're not the principal you think you are — `get-caller-identity` first, every time
2. Bucket policy has an explicit `Deny` (e.g. deny unless `aws:SecureTransport`)
3. An SCP blocks it at the org level
4. A permission boundary caps the role
5. **KMS** — you have S3 permissions but not `kms:Decrypt` on the key (see BF-26)

**PREVENT:** Least privilege built from CloudTrail evidence rather than guessed.

---

## BF-26 — S3 works, KMS doesn't

**SYMPTOM:** `s3:GetObject` is allowed and the bucket policy is fine, but downloads fail with
`AccessDenied`. Uploads may work while downloads don't.

**DIAGNOSIS:**
```bash
aws s3api head-object --bucket b --key k          # shows SSEKMSKeyId
aws kms describe-key --key-id <id>
aws kms get-key-policy --key-id <id> --policy-name default
```

**ROOT CAUSE:** The object is encrypted with a **customer-managed KMS key**. Reading it requires
`kms:Decrypt` on that key, granted by **both** the IAM policy and the **key policy**. Writing
requires `kms:GenerateDataKey`.

**FIX:** Add the principal to the key policy and grant `kms:Decrypt` / `kms:GenerateDataKey` in IAM.

**WHY THIS IS A GREAT INTERVIEW ANSWER:** "S3 access denied even though S3 permissions are correct"
is a real, common, non-obvious failure. Naming KMS as the cause — and knowing the key policy is a
*separate* gate from IAM — reads as someone who has actually operated encrypted storage.

---

## BF-27 — Private instance can't reach the internet

**SYMPTOM:** An instance in a private subnet times out on `yum update` / `apt update`.

**DIAGNOSIS — check in this order:**
```bash
aws ec2 describe-route-tables --filters "Name=association.subnet-id,Values=<subnet>"
#   need: 0.0.0.0/0 -> nat-xxxx
aws ec2 describe-nat-gateways --filter "Name=state,Values=available"
#   the NAT must be in a PUBLIC subnet
aws ec2 describe-security-groups --group-ids <sg>      # egress allowed?
aws ec2 describe-network-acls --filters "Name=association.subnet-id,Values=<subnet>"
#   NACLs are stateless: allow ephemeral 1024-65535 INBOUND for return traffic
```

**ROOT CAUSES, in frequency order:**
1. No `0.0.0.0/0 -> nat-gw` route in the private subnet's route table
2. **The NAT gateway was placed in a private subnet** — it must live in a public subnet with a route
   to the IGW. This is the single most common VPC mistake.
3. Security group egress restricted
4. NACL missing the ephemeral-port inbound return rule

**THE MENTAL MODEL:** "Public subnet" is not a property you set. A subnet is public **if and only
if** its route table has a route to an internet gateway. Say it that way in an interview.

---

## BF-28 — ALB returns 503

**SYMPTOM:** `503 Service Temporarily Unavailable` from the load balancer.

**DIAGNOSIS:**
```bash
aws elbv2 describe-target-health --target-group-arn <arn>
# Read the 'Reason' field -- it tells you exactly what's wrong:
#   Target.FailedHealthChecks   -> health check path/port wrong, or app is down
#   Target.NotRegistered        -> ASG never registered the instance
#   Target.Timeout              -> SG blocking the ALB, or app too slow
#   Elb.InternalError           -> subnet/AZ misconfiguration
```

**ROOT CAUSES:**
1. Zero healthy targets — health check hits `/` but the app only serves `/health`
2. **Instance SG doesn't allow inbound from the ALB's SG** — the classic. The rule source should be
   the ALB's security group ID, not a CIDR.
3. Health check port ≠ application port
4. Health check interval/threshold too aggressive for a slow-starting app
5. No targets in the AZs the ALB is attached to

**503 vs 502 vs 504 ON AN ALB:**
| Code | Meaning |
|---|---|
| **503** | No healthy targets at all |
| **502** | Target returned a malformed response, or closed the connection |
| **504** | Target didn't answer inside the idle timeout |

**FIX:** Correct the health check path, and set the instance SG to allow the ALB SG on the app port.

---

## BF-29 — ASG launches and immediately terminates

**SYMPTOM:** Instances cycle endlessly: launch, terminate, launch.

**DIAGNOSIS:**
```bash
aws autoscaling describe-scaling-activities --auto-scaling-group-name <asg> --max-items 10
# The "StatusMessage" and "Cause" fields name the reason.
aws ec2 get-console-output --instance-id <id>      # did user-data fail?
```

**ROOT CAUSES:**
1. **ELB health check + a long app boot** — the ASG uses ELB health, the app takes 3 minutes to
   start, health check grace period is 60s → killed before it's ready. **Fix: raise
   `HealthCheckGracePeriod`.** This is the most common cause by a wide margin.
2. User data script exits non-zero
3. AMI missing a dependency
4. Insufficient capacity for the instance type in that AZ
5. Spot interruption

**PREVENT:** Grace period longer than worst-case boot; test user data on a standalone instance first;
log user data to CloudWatch.

---

## BF-30 — Lambda times out reaching RDS

**SYMPTOM:** Lambda works against a public API but times out connecting to RDS in the VPC.

**DIAGNOSIS:**
```bash
aws lambda get-function-configuration --function-name <fn> --query 'VpcConfig'
aws rds describe-db-instances --db-instance-identifier <db> \
  --query 'DBInstances[0].[DBSubnetGroup.Subnets,VpcSecurityGroups]'
```

**ROOT CAUSES:**
1. Lambda not attached to the VPC at all → it can't see private RDS
2. Lambda in the VPC but in a subnet with no route to what it needs
3. **RDS security group doesn't allow inbound from the Lambda's security group**
4. Lambda timeout shorter than the connection timeout — it dies before erroring usefully
5. Lambda placed in a **public** subnet expecting internet access — a VPC Lambda has no public IP;
   it needs a **NAT gateway** from a private subnet, or VPC endpoints

**THE ONE PEOPLE MISS:** Putting a Lambda in a public subnet does *not* give it internet access. ENIs
attached to Lambda get no public IP. Private subnet + NAT, or VPC endpoints. This is a favorite
interview question.

**FIX:** Lambda in private subnets, RDS SG allows the Lambda SG on 5432/3306, timeout ≥ 10s, and use
RDS Proxy if connection count is the real problem.

---

## BF-31 — SQS messages stuck / processed twice

**SYMPTOM:** Messages reappear after being processed. Or they vanish and never hit the DLQ.

**DIAGNOSIS:**
```bash
aws sqs get-queue-attributes --queue-url <url> --attribute-names All
# Compare: VisibilityTimeout vs your consumer's actual processing time
# Check: ApproximateNumberOfMessagesNotVisible (in flight)
#        RedrivePolicy (is there even a DLQ?)
```

**ROOT CAUSE:** `VisibilityTimeout` is shorter than processing time. The message becomes visible
again mid-processing and a second consumer picks it up → duplicate work.

**FIX:**
- Set `VisibilityTimeout` ≥ 6× the Lambda timeout (AWS's own recommendation)
- Or call `ChangeMessageVisibility` to extend the lease during long work
- Configure a DLQ with `maxReceiveCount` so poison messages stop looping
- **Make the consumer idempotent** — SQS standard queues are at-least-once *by design*, so
  duplicates are not a bug to eliminate but a property to handle

**THE PRINCIPLE:** "At-least-once delivery means idempotency is the consumer's job." That single
sentence answers a large family of distributed-systems interview questions.

---

## BF-32 — CloudWatch alarm never fires

**SYMPTOM:** You caused the condition, and the alarm stayed in `OK` — or went to `INSUFFICIENT_DATA`.

**DIAGNOSIS:**
```bash
aws cloudwatch describe-alarms --alarm-names <name>
aws cloudwatch get-metric-statistics --namespace AWS/EC2 --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=<id> \
  --start-time $(date -u -v-1H +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) --period 300 --statistics Average
```

**ROOT CAUSES:**
1. **Dimension mismatch** — the alarm watches a dimension combination that no metric publishes. The
   #1 cause, and it shows as `INSUFFICIENT_DATA`.
2. Period shorter than the publishing interval (EC2 basic monitoring is 5 min, not 1 min)
3. `TreatMissingData` set to `notBreaching`, hiding a genuine outage
4. `EvaluationPeriods` × `Period` longer than the event lasted
5. Custom metric never actually published
6. SNS subscription never confirmed — **alarm fired, nobody got email**

**ALWAYS TEST AN ALARM BY FORCING IT:**
```bash
aws cloudwatch set-alarm-state --alarm-name <name> \
  --state-value ALARM --state-reason "testing notification path"
```
An untested alarm is not monitoring — it is a comforting decoration. Say that in an interview.
