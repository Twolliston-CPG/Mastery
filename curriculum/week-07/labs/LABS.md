# Week 7 Labs

---

# Lab 1 — ALB and Target Groups (3h)

## Build
```bash
TG=$(aws elbv2 create-target-group --name lab-tg --protocol HTTP --port 80 \
  --vpc-id $VPC_ID --target-type instance \
  --health-check-path /health --health-check-interval-seconds 15 \
  --healthy-threshold-count 2 --unhealthy-threshold-count 2 \
  --query 'TargetGroups[0].TargetGroupArn' --output text)

ALB=$(aws elbv2 create-load-balancer --name lab-alb \
  --subnets $PUB_A $PUB_B --security-groups $SG_ALB --scheme internet-facing \
  --query 'LoadBalancers[0].LoadBalancerArn' --output text)

aws elbv2 create-listener --load-balancer-arn $ALB --protocol HTTP --port 80 \
  --default-actions Type=forward,TargetGroupArn=$TG
```

**Critical:** the instance security group must allow inbound from the **ALB's security group ID**,
not a CIDR:
```bash
aws ec2 authorize-security-group-ingress --group-id $SG_APP \
  --protocol tcp --port 80 --source-group $SG_ALB
```

## Tasks
1. Register two instances in different AZs; confirm round-robin
2. **Break the health check deliberately** — point it at `/nope` — and watch the ALB return **503**.
   Read `describe-target-health` and find the `Reason` field. (BF-28)
3. Remove the SG rule allowing the ALB and observe `Target.Timeout`
4. Add a **path-based listener rule**: `/api/*` → a second target group
5. Add a **host-based rule**: `api.yourdomain.com` → a different target group
6. Enable ALB access logs to S3; find a request in them
7. Add an HTTPS listener with an ACM certificate for your domain (free cert — request it in ACM,
   validate via DNS)

## ALB vs NLB — build both and feel the difference
```bash
aws elbv2 create-load-balancer --name lab-nlb --type network \
  --subnets $PUB_A $PUB_B --scheme internet-facing
```
Note: the NLB preserves the client source IP at the target (no `X-Forwarded-For` needed), gets a
static IP per AZ, and operates at L4 so it cannot do path routing or terminate HTTP.

---

# Lab 2 — Auto Scaling (3h)

## Launch template
```bash
cat > userdata.sh <<'UD'
#!/bin/bash
set -euxo pipefail
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1
dnf install -y nginx stress-ng
systemctl enable --now nginx
echo "<h1>$(hostname -f)</h1>" > /usr/share/nginx/html/index.html
echo "ok" > /usr/share/nginx/html/health
UD

aws ec2 create-launch-template --launch-template-name lab-lt \
  --launch-template-data "{
    \"ImageId\": \"resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64\",
    \"InstanceType\": \"t3.micro\",
    \"SecurityGroupIds\": [\"$SG_APP\"],
    \"MetadataOptions\": {\"HttpTokens\": \"required\", \"HttpPutResponseHopLimit\": 1},
    \"UserData\": \"$(base64 -w0 userdata.sh)\",
    \"TagSpecifications\": [{\"ResourceType\":\"instance\",\"Tags\":[{\"Key\":\"Name\",\"Value\":\"asg-web\"}]}]
  }"

aws autoscaling create-auto-scaling-group --auto-scaling-group-name lab-asg \
  --launch-template LaunchTemplateName=lab-lt,Version='$Latest' \
  --min-size 2 --max-size 6 --desired-capacity 2 \
  --vpc-zone-identifier "$APP_A,$APP_B" \
  --target-group-arns $TG \
  --health-check-type ELB --health-check-grace-period 300
```

**`--health-check-grace-period 300` is the setting that matters.** With ELB health checks and a slow
boot, too short a grace period means the ASG kills instances before they finish starting — forever.
That's BF-29, and it's the most common ASG failure.

## Tasks
1. **Terminate an instance manually and time the full recovery** — from termination to a healthy
   target in the target group. Write the number down; it goes in your README and your interview
   answer.
2. Add a target-tracking scaling policy at 50% CPU:
   ```bash
   aws autoscaling put-scaling-policy --auto-scaling-group-name lab-asg \
     --policy-name cpu-target --policy-type TargetTrackingScaling \
     --target-tracking-configuration '{
       "PredefinedMetricSpecification":{"PredefinedMetricType":"ASGAverageCPUUtilization"},
       "TargetValue":50.0}'
   ```
3. Load-test it: `ssh` to an instance and run `stress-ng --cpu 2 --timeout 600s`, or hit the ALB with
   `hey`/`ab`. Watch it scale **out**, then watch it scale **back in** (that takes longer — cooldowns
   and the 15-minute default for scale-in are deliberate, to avoid flapping).
4. Set `grace period` to 30 seconds and reproduce **BF-29** — the launch/terminate loop
5. Use `describe-scaling-activities` to read the `StatusMessage` and `Cause`
6. Add a **spot** mixed-instances policy and note the savings

---

# Lab 3 — RDS: Multi-AZ and the Measured Failover (3h · ~$3)

```bash
aws rds create-db-subnet-group --db-subnet-group-name lab-db-subnets \
  --db-subnet-group-description "lab" --subnet-ids $DATA_A $DATA_B

aws rds create-db-instance --db-instance-identifier lab-db \
  --db-instance-class db.t3.micro --engine postgres --engine-version 16 \
  --allocated-storage 20 --storage-encrypted \
  --master-username appadmin --manage-master-user-password \
  --db-subnet-group-name lab-db-subnets --vpc-security-group-ids $SG_DB \
  --multi-az --backup-retention-period 1 --no-publicly-accessible
```

**`--manage-master-user-password`** puts the password directly into Secrets Manager with rotation.
Terraform never sees it, you never see it, it never lands in state. **This is the correct answer to
"how do you handle database passwords in IaC"** (week 11, BF-36).

## The measurement (the point of the lab)

```bash
# Terminal 1: hammer the database, timestamping every result
while true; do
  printf '%s ' "$(date +%T.%3N)"
  PGPASSWORD=$PW timeout 2 psql -h $ENDPOINT -U appadmin -d postgres \
    -tAc 'select 1' 2>&1 | tr -d '\n'
  echo
  sleep 0.25
done | tee /tmp/failover.log

# Terminal 2: force the failover
aws rds reboot-db-instance --db-instance-identifier lab-db --force-failover
```

Then compute the gap:
```bash
grep -n 'error\|timeout\|could not' /tmp/failover.log | head -1
grep -n '1$' /tmp/failover.log | awk -F: '$1 > FIRSTFAIL' | head -1
```

**Write the number down.** Typical is 60–120 seconds. "I measured an RDS Multi-AZ failover at 73
seconds" is a specific, credible thing to say in an interview; "Multi-AZ fails over automatically" is
a sentence from a brochure.

## Tasks
1. Measure the failover. Note that the **endpoint DNS name does not change** — the CNAME is
   repointed, which is why your connection string never changes but your connection pool must
   reconnect.
2. Create a **read replica**; write to the primary, read from the replica, and measure replication
   lag with `SELECT now() - pg_last_xact_replay_timestamp();`
3. Take a manual snapshot; restore it to a new instance; note that restore creates a **new endpoint**
4. Enable Performance Insights and look at it
5. Try to connect from a public subnet — it fails. Fix by adding the app SG to the DB SG.
6. Reproduce **BF-30**: a Lambda in the VPC that times out reaching RDS

---

# Lab 4 — DynamoDB (2h)

```bash
aws dynamodb create-table --table-name lab-orders \
  --attribute-definitions \
    AttributeName=PK,AttributeType=S AttributeName=SK,AttributeType=S \
    AttributeName=GSI1PK,AttributeType=S AttributeName=GSI1SK,AttributeType=S \
  --key-schema AttributeName=PK,KeyType=HASH AttributeName=SK,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST \
  --global-secondary-indexes '[{
    "IndexName":"GSI1",
    "KeySchema":[{"AttributeName":"GSI1PK","KeyType":"HASH"},
                 {"AttributeName":"GSI1SK","KeyType":"RANGE"}],
    "Projection":{"ProjectionType":"ALL"}}]'
```

## The two access patterns
1. "All orders for customer X, newest first" → `PK=CUSTOMER#123`, `SK=ORDER#<timestamp>`
2. "All orders with status SHIPPED in date order" → `GSI1PK=STATUS#SHIPPED`, `GSI1SK=<timestamp>`

```python
import boto3
from boto3.dynamodb.conditions import Key

t = boto3.resource("dynamodb").Table("lab-orders")

t.put_item(Item={
    "PK": "CUSTOMER#123", "SK": "ORDER#2026-03-14T10:00:00",
    "GSI1PK": "STATUS#SHIPPED", "GSI1SK": "2026-03-14T10:00:00",
    "total": 42,
})

# Pattern 1
print(t.query(KeyConditionExpression=Key("PK").eq("CUSTOMER#123"),
              ScanIndexForward=False)["Items"])
# Pattern 2
print(t.query(IndexName="GSI1",
              KeyConditionExpression=Key("GSI1PK").eq("STATUS#SHIPPED"))["Items"])
```

## Tasks
1. Load 50 items and run both queries
2. Run a `scan` and compare the consumed capacity to the equivalent `query`
   (`ReturnConsumedCapacity='TOTAL'`). **This is the whole reason DynamoDB modeling matters.**
3. Try to query by an attribute that isn't a key — you can't without a scan or another index
4. Explain in writing why **GSI vs LSI**: LSI shares the partition key, must be created with the
   table, shares capacity, can be strongly consistent. GSI has a different partition key, can be
   added anytime, has its own capacity, is eventually consistent only.
5. Enable point-in-time recovery and TTL

**The one-sentence version for an interview:** *"With DynamoDB you design the table around your
access patterns, because you can only query efficiently on keys — unlike SQL where you add an index
after the fact."*

---

# Lab 5 — Lambda, Fargate, Break/Fix (3h)

## Lambda in a VPC
```bash
aws lambda create-function --function-name lab-fn --runtime python3.12 \
  --role $LAMBDA_ROLE --handler index.handler --timeout 15 \
  --zip-file fileb://fn.zip \
  --vpc-config SubnetIds=$APP_A,$APP_B,SecurityGroupIds=$SG_LAMBDA
```

**Tasks:**
1. Put it in a **public** subnet and try to reach the internet — it fails. Explain why (BF-30).
2. Move it to a private subnet with a NAT gateway — it works.
3. Reach RDS from it; get the DB SG rule wrong and read the timeout.
4. Set the Lambda timeout to 3s and the DB connect timeout to 10s — observe that the Lambda dies
   before producing a useful error. Fix the ordering.
5. Measure cold start vs warm invocation.

## ECS Fargate
```bash
aws ecs create-cluster --cluster-name lab-cluster
# register a task definition using the week-4 image, then:
aws ecs create-service --cluster lab-cluster --service-name lab-svc \
  --task-definition lab-task --desired-count 2 --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[$APP_A,$APP_B],securityGroups=[$SG_APP]}" \
  --load-balancers targetGroupArn=$TG_IP,containerName=app,containerPort=8080
```
Note the target group must be `--target-type ip` for Fargate, because each task gets its own ENI.

## Break/Fix
**BF-28** (ALB 503) · **BF-29** (ASG launch/terminate loop) · **BF-30** (Lambda→RDS timeout).

## Teardown
```bash
aws rds delete-db-instance --db-instance-identifier lab-db --skip-final-snapshot
aws elbv2 delete-load-balancer --load-balancer-arn $ALB
aws autoscaling update-auto-scaling-group --auto-scaling-group-name lab-asg --min-size 0 --desired-capacity 0
aws autoscaling delete-auto-scaling-group --auto-scaling-group-name lab-asg --force-delete
bash ../../_setup/03-teardown.sh
```
