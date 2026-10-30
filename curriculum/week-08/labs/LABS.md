# Week 8 Labs

> **Figures:** one numbered mechanism figure per lab, with the spoken script, the numbers to own and
> the command that proves each badge, in [`FIGURES.md`](FIGURES.md) (8.2 to 8.6). Read a lab's figure
> before you start it; redraw it after.

---

# Lab 1 — Decoupling (3h)

## Build the pattern
```bash
DLQ=$(aws sqs create-queue --queue-name lab-dlq --query QueueUrl --output text)
DLQ_ARN=$(aws sqs get-queue-attributes --queue-url $DLQ --attribute-names QueueArn \
  --query 'Attributes.QueueArn' --output text)

Q=$(aws sqs create-queue --queue-name lab-queue --attributes "{
  \"VisibilityTimeout\": \"60\",
  \"MessageRetentionPeriod\": \"345600\",
  \"RedrivePolicy\": \"{\\\"deadLetterTargetArn\\\":\\\"$DLQ_ARN\\\",\\\"maxReceiveCount\\\":\\\"3\\\"}\"
}" --query QueueUrl --output text)
```

## Tasks
1. Send, receive, and delete a message by hand. Observe that **receiving does not delete** — you must
   explicitly `delete-message` after processing.
2. Receive a message and **don't** delete it. Watch it reappear after the visibility timeout.
   That's BF-31.
3. **Reproduce BF-31 properly:** set `VisibilityTimeout=5`, write a consumer that takes 20 seconds,
   and observe the same message processed by two consumers concurrently.
4. Send a poison message that always fails; watch `maxReceiveCount` push it to the DLQ after 3 tries.
5. Attach a Lambda event source and set the Lambda timeout to 30s. Confirm the queue's visibility
   timeout is **at least 6× the function timeout** (AWS's own guidance) and explain why.
6. Build SNS → 2 SQS queues fan-out, and confirm both receive a copy.
7. Build an EventBridge rule matching on a payload field and routing to different targets.

```bash
aws sqs send-message --queue-url $Q --message-body '{"order":123}'
aws sqs receive-message --queue-url $Q --wait-time-seconds 20   # long polling
aws sqs get-queue-attributes --queue-url $Q --attribute-names All
```

**Long polling (`--wait-time-seconds 20`) vs short polling:** short polling returns immediately,
often empty, and you pay per request — a tight loop can cost more than the compute. Always long poll.

## Standard vs FIFO
```bash
aws sqs create-queue --queue-name lab.fifo \
  --attributes FifoQueue=true,ContentBasedDeduplication=true
aws sqs send-message --queue-url $FIFO --message-body '{"x":1}' --message-group-id order-123
```
`MessageGroupId` is the ordering unit — messages in the same group are strictly ordered, different
groups process in parallel. **Choosing the group ID is the throughput decision**: one group means
serial processing for the whole queue.

---

# Lab 2 — KMS and Secrets (3h)

```bash
KEY=$(aws kms create-key --description "lab cmk" \
  --query KeyMetadata.KeyId --output text)
aws kms create-alias --alias-name alias/lab --target-key-id $KEY
aws kms enable-key-rotation --key-id $KEY
```

## Tasks
1. Encrypt and decrypt a string directly:
   ```bash
   CT=$(aws kms encrypt --key-id alias/lab --plaintext "$(echo -n secret | base64)" \
     --query CiphertextBlob --output text)
   aws kms decrypt --ciphertext-blob fileb://<(echo "$CT" | base64 -d) \
     --query Plaintext --output text | base64 -d
   ```
2. Understand **envelope encryption**: `generate-data-key` returns both a plaintext data key and an
   encrypted copy. You encrypt your data with the plaintext key, discard it, and store the encrypted
   key alongside. **KMS never sees your data** — this is why there's a 4 KB direct-encrypt limit.
3. Write a **key policy** granting `kms:Decrypt` to one role only.
4. **Reproduce BF-26 deliberately:** give a role `s3:*` on a KMS-encrypted bucket but no KMS
   permissions. Confirm `GetObject` fails with AccessDenied.
5. Add an **encryption context** and show that decrypting with a different context fails.
6. Secrets Manager vs Parameter Store:
   ```bash
   aws secretsmanager create-secret --name lab/db --secret-string '{"user":"app","pass":"x"}'
   aws ssm put-parameter --name /lab/api-key --value "abc" --type SecureString
   ```
   Compare: rotation support, cost, cross-region replication, and size limits.
7. Schedule key deletion and note the **mandatory 7–30 day waiting period** — and why that exists
   (deleting a key makes every object encrypted with it permanently unreadable).

---

# Lab 3 — CloudWatch and CloudTrail (3h)

## Alarms — and testing them
```bash
aws cloudwatch put-metric-alarm --alarm-name lab-high-cpu \
  --metric-name CPUUtilization --namespace AWS/EC2 \
  --dimensions Name=InstanceId,Value=$INSTANCE \
  --statistic Average --period 300 --evaluation-periods 2 \
  --threshold 70 --comparison-operator GreaterThanThreshold \
  --treat-missing-data notBreaching \
  --alarm-actions $SNS_TOPIC

# TEST IT. An untested alarm is a decoration.
aws cloudwatch set-alarm-state --alarm-name lab-high-cpu \
  --state-value ALARM --state-reason "verifying the notification path"
```

## Tasks
1. Create the alarm, **force it**, and confirm the email actually arrives
2. **Confirm the SNS subscription** — an unconfirmed subscription means the alarm fires and nobody
   hears it. This is BF-32's most annoying cause.
3. Publish a **custom metric** and alarm on it
4. Deliberately create a **dimension mismatch** and watch the alarm sit in `INSUFFICIENT_DATA`
5. Set `--treat-missing-data notBreaching` on a metric that stops publishing during an outage, and
   understand why that hides real failures
6. Build a composite alarm (`ALARM(a) AND ALARM(b)`) to reduce noise

## Logs Insights
```bash
aws logs start-query --log-group-name /aws/lambda/lab-fn \
  --start-time $(($(date +%s)-3600)) --end-time $(date +%s) \
  --query-string 'fields @timestamp, @message
                  | filter @message like /ERROR/
                  | sort @timestamp desc | limit 50'
```
Write queries for: all 5xx in the last hour · p95 duration by function · the top 10 error messages by
count · Lambda cold starts (`filter @type = "REPORT" | filter ispresent(@initDuration)`).

## CloudTrail
```bash
aws cloudtrail lookup-events --max-results 10 \
  --lookup-attributes AttributeKey=EventName,AttributeValue=DeleteBucket
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=Username,AttributeValue=iam-lab-user
```
**Tasks:** find *who* deleted something, and *when*. Then look up a failed API call and read
`errorCode`/`errorMessage` — this is how you diagnose AccessDenied when the client-side message is
unhelpful.

**Management events vs data events:** CloudTrail records control-plane calls by default.
`s3:GetObject` and `lambda:Invoke` are **data events** and are **off by default** because volume (and
cost) is huge. "Who read this object?" is unanswerable unless data events were already enabled.
That's a good detail to know.

---

# Lab 4 — CloudFront, Route 53, Organizations (2h)

## CloudFront with OAC over a private bucket
1. Create a bucket, **Block Public Access on**, upload an `index.html`
2. Create a CloudFront distribution with the bucket as origin, using **Origin Access Control**
3. Apply the generated bucket policy allowing only the distribution
4. Confirm: the CloudFront URL works; the direct S3 URL returns 403
5. Add your ACM certificate and an alternate domain name
6. Set a cache policy; test with `curl -I` and read the `X-Cache: Hit from cloudfront` header
7. Invalidate the cache and watch it become a miss again

**This is the correct answer to "how do I host static content publicly?"** Not a public bucket.

## Route 53
1. Create a public hosted zone for your domain (you bought one in week 3)
2. Create an **alias** record at the apex pointing at the CloudFront distribution — and note that a
   CNAME would be illegal here
3. Create a weighted routing pair (90/10) between two targets and observe the split
4. Create a failover pair with a health check; break the primary and watch it shift

## Organizations and SCPs (read-only if you have one account)
```bash
aws organizations describe-organization
aws organizations list-policies --filter SERVICE_CONTROL_POLICY
```
Write (don't necessarily apply) an SCP that denies leaving the organization, denies disabling
CloudTrail, and denies all regions except two.

**SCPs never grant — they only cap.** An SCP allowing `s3:*` gives nobody S3 access; it just permits
IAM to grant it. That distinction is asked about.

---

# Lab 5 — DR, Cost, Break/Fix (3h)

## The four DR strategies — write the table yourself first
| Strategy | RTO | RPO | Relative cost | What's running |
|---|---|---|---|---|
| Backup & Restore | | | | |
| Pilot Light | | | | |
| Warm Standby | | | | |
| Multi-Site Active/Active | | | | |

Then build **pilot light**: S3 cross-region replication for data, an AMI copied to the DR region,
Terraform (week 10) able to stand up the compute. Measure how long a restore actually takes.

## Cost
```bash
aws ce get-cost-and-usage \
  --time-period Start=$(date -u -d '30 days ago' +%F 2>/dev/null || date -u -v-30d +%F),End=$(date -u +%F) \
  --granularity MONTHLY --metrics UnblendedCost \
  --group-by Type=DIMENSION,Key=SERVICE --output table

aws ce get-cost-and-usage \
  --time-period Start=$(date -u -d '30 days ago' +%F 2>/dev/null || date -u -v-30d +%F),End=$(date -u +%F) \
  --granularity MONTHLY --metrics UnblendedCost \
  --group-by Type=TAG,Key=Environment
```
**Tasks:** tag everything with `Environment` and `Project`; build a Cost Explorer view grouped by
tag; enable a Cost Anomaly Detector; look at Trusted Advisor's cost checks.

**Tagging is not bureaucracy — it is the only way to answer "what is this costing us?"** Untagged
resources are the reason cost conversations stall. Enforce it later with an SCP or Kyverno-style
policy (week 19).

## Break/Fix
**BF-31** (SQS visibility timeout) · **BF-32** (alarm never fires).
