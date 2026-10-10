# Lab 06 — CloudTrail & VPC Flow Logs

## Objective

Enable CloudTrail for multi-region API logging, configure S3 delivery, enable VPC Flow Logs, and analyze logs using CloudWatch Logs Insights. This lab teaches you how to audit API activity and troubleshoot network issues.

## Prerequisites

- AWS CLI configured
- Python 3.9+ with `boto3`
- A VPC (from Phase 1 labs or default VPC)

## Estimated Time: 60-75 minutes

## Cost Estimate

| Resource | Cost | Notes |
|----------|------|-------|
| CloudTrail (management events) | Free (first trail) | One management event trail per region is free |
| S3 storage for logs | Negligible | Small log files |
| VPC Flow Logs to CloudWatch | ~$0.50/GB ingested | Minimal traffic in lab |
| CloudWatch Logs Insights | $0.005/GB scanned | Tiny amounts |
| **Total** | **~$0.10-0.50** | Minimal cost |

---

## Part 1: Enable CloudTrail (Multi-Region)

### Step 1.1 — Create S3 Bucket for CloudTrail Logs

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
TRAIL_BUCKET="saa-lab-cloudtrail-${ACCOUNT_ID}-$(date +%s)"

aws s3 mb s3://$TRAIL_BUCKET

# Apply bucket policy required by CloudTrail
aws s3api put-bucket-policy --bucket $TRAIL_BUCKET --policy '{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AWSCloudTrailAclCheck",
      "Effect": "Allow",
      "Principal": { "Service": "cloudtrail.amazonaws.com" },
      "Action": "s3:GetBucketAcl",
      "Resource": "arn:aws:s3:::'$TRAIL_BUCKET'"
    },
    {
      "Sid": "AWSCloudTrailWrite",
      "Effect": "Allow",
      "Principal": { "Service": "cloudtrail.amazonaws.com" },
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::'$TRAIL_BUCKET'/AWSLogs/'$ACCOUNT_ID'/*",
      "Condition": {
        "StringEquals": { "s3:x-amz-acl": "bucket-owner-full-control" }
      }
    }
  ]
}'

echo "Trail bucket: $TRAIL_BUCKET"
```

### Step 1.2 — Create a Multi-Region Trail

```bash
aws cloudtrail create-trail \
  --name saa-lab-trail \
  --s3-bucket-name $TRAIL_BUCKET \
  --is-multi-region-trail \
  --enable-log-file-validation \
  --tags-list Key=Purpose,Value=SAA-Lab

# Start logging
aws cloudtrail start-logging --name saa-lab-trail

echo "Multi-region trail created and logging started."
```

### Step 1.3 — Verify Trail Configuration

```bash
# Describe the trail
aws cloudtrail describe-trails --trail-name-list saa-lab-trail

# Check trail status
aws cloudtrail get-trail-status --name saa-lab-trail

# Check if logging is enabled
aws cloudtrail get-trail-status --name saa-lab-trail \
  --query "{IsLogging:IsLogging,LatestDeliveryTime:LatestDeliveryTime}"
```

### Step 1.4 — Generate Some API Activity

```bash
# Perform some actions that CloudTrail will record
aws s3 ls
aws ec2 describe-instances --max-items 1
aws iam list-users
aws sts get-caller-identity

echo "API calls made. CloudTrail will deliver logs within 5-15 minutes."
```

### Step 1.5 — Send CloudTrail to CloudWatch Logs (Optional)

```bash
# Create a CloudWatch Logs log group for CloudTrail
aws logs create-log-group --log-group-name "/saa-lab/cloudtrail"

# Create IAM role for CloudTrail to write to CloudWatch Logs
aws iam create-role \
  --role-name saa-lab-cloudtrail-cw-role \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": { "Service": "cloudtrail.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }]
  }'

CW_ROLE_ARN=$(aws iam get-role --role-name saa-lab-cloudtrail-cw-role --query "Role.Arn" --output text)

aws iam put-role-policy \
  --role-name saa-lab-cloudtrail-cw-role \
  --policy-name CloudWatchLogsAccess \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    }]
  }'

sleep 10

# Update trail to send to CloudWatch Logs
LOG_GROUP_ARN=$(aws logs describe-log-groups --log-group-name-prefix "/saa-lab/cloudtrail" --query "logGroups[0].arn" --output text)

aws cloudtrail update-trail \
  --name saa-lab-trail \
  --cloud-watch-logs-log-group-arn $LOG_GROUP_ARN \
  --cloud-watch-logs-role-arn $CW_ROLE_ARN

echo "CloudTrail now also delivers to CloudWatch Logs."
```

---

## Part 2: Look Up CloudTrail Events

### Step 2.1 — Look Up Recent Events (CLI)

```bash
# Look up the last 10 management events
aws cloudtrail lookup-events \
  --max-results 10 \
  --query "Events[*].{Time:EventTime,Name:EventName,User:Username,Source:EventSource}" \
  --output table

# Look up specific event type
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=DescribeInstances \
  --max-results 5
```

### Step 2.2 — Look Up Events with Boto3

Create `cloudtrail_events.py`:

```python
"""
Query CloudTrail events to audit recent API activity.
"""

import boto3
from datetime import datetime, timedelta

def main():
    ct = boto3.client("cloudtrail")

    # Look up events from the last hour
    end_time = datetime.utcnow()
    start_time = end_time - timedelta(hours=1)

    print(f"{'='*80}")
    print(f"CLOUDTRAIL EVENTS ({start_time.strftime('%H:%M')} - {end_time.strftime('%H:%M')} UTC)")
    print(f"{'='*80}")

    response = ct.lookup_events(
        StartTime=start_time,
        EndTime=end_time,
        MaxResults=20
    )

    events_by_source = {}
    for event in response["Events"]:
        source = event.get("EventSource", "unknown")
        if source not in events_by_source:
            events_by_source[source] = []
        events_by_source[source].append(event)

    for source, events in sorted(events_by_source.items()):
        print(f"\n  [{source}]")
        for event in events:
            time_str = event["EventTime"].strftime("%H:%M:%S")
            username = event.get("Username", "N/A")
            event_name = event.get("EventName", "N/A")
            read_only = "READ" if "Describe" in event_name or "List" in event_name or "Get" in event_name else "WRITE"
            print(f"    {time_str} | {read_only:5} | {event_name:40} | User: {username}")

    print(f"\nTotal events: {len(response['Events'])}")

    # Count by event type
    write_events = [e for e in response["Events"]
                    if not any(prefix in e.get("EventName", "")
                              for prefix in ["Describe", "List", "Get"])]
    print(f"Write events: {len(write_events)}")
    print(f"Read events: {len(response['Events']) - len(write_events)}")

if __name__ == "__main__":
    main()
```

```bash
python cloudtrail_events.py
```

---

## Part 3: Enable VPC Flow Logs

### Step 3.1 — Create Flow Logs to CloudWatch Logs

```bash
# Get the VPC ID (use default VPC or your lab VPC)
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --query "Vpcs[0].VpcId" --output text)
echo "VPC ID: $VPC_ID"

# Create a log group for flow logs
aws logs create-log-group --log-group-name "/saa-lab/vpc-flow-logs"

# Create IAM role for VPC Flow Logs
aws iam create-role \
  --role-name saa-lab-flow-logs-role \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": { "Service": "vpc-flow-logs.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }]
  }'

aws iam put-role-policy \
  --role-name saa-lab-flow-logs-role \
  --policy-name FlowLogsAccess \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ],
      "Resource": "*"
    }]
  }'

FLOW_ROLE_ARN=$(aws iam get-role --role-name saa-lab-flow-logs-role --query "Role.Arn" --output text)
sleep 10

# Create the flow log
aws ec2 create-flow-logs \
  --resource-type VPC \
  --resource-ids $VPC_ID \
  --traffic-type ALL \
  --log-group-name "/saa-lab/vpc-flow-logs" \
  --deliver-logs-permission-arn $FLOW_ROLE_ARN \
  --tag-specifications 'ResourceType=vpc-flow-log,Tags=[{Key=Purpose,Value=SAA-Lab}]'

echo "VPC Flow Logs enabled. Logs will appear in 5-10 minutes."
```

### Step 3.2 — Generate Network Traffic

```bash
# Generate some traffic for flow logs to capture
curl -s https://aws.amazon.com > /dev/null
curl -s https://google.com > /dev/null

# If you have an EC2 instance, try connecting to it
# ssh ec2-user@YOUR_INSTANCE_IP

echo "Network traffic generated. Wait 10 minutes for flow log delivery."
sleep 600
```

### Step 3.3 — Query Flow Logs with CloudWatch Logs Insights

```bash
# Find rejected traffic
aws logs start-query \
  --log-group-name "/saa-lab/vpc-flow-logs" \
  --start-time $(date -u -v-1H +%s 2>/dev/null || date -u -d "1 hour ago" +%s) \
  --end-time $(date -u +%s) \
  --query-string 'fields @timestamp, srcAddr, dstAddr, dstPort, action
    | filter action = "REJECT"
    | sort @timestamp desc
    | limit 20'

# Save the queryId from the output, then check results:
# aws logs get-query-results --query-id "YOUR_QUERY_ID"
```

### Step 3.4 — Analyze Flow Logs with Boto3

Create `analyze_flow_logs.py`:

```python
"""
Query VPC Flow Logs using CloudWatch Logs Insights.
"""

import boto3
import time

def run_insights_query(logs_client, log_group, query, description):
    """Run a CloudWatch Logs Insights query and return results."""
    print(f"\n{'─'*60}")
    print(f"Query: {description}")
    print(f"{'─'*60}")

    import datetime
    end_time = int(datetime.datetime.utcnow().timestamp())
    start_time = end_time - 3600  # Last hour

    response = logs_client.start_query(
        logGroupName=log_group,
        startTime=start_time,
        endTime=end_time,
        queryString=query
    )

    query_id = response["queryId"]

    # Wait for query to complete
    while True:
        result = logs_client.get_query_results(queryId=query_id)
        if result["status"] == "Complete":
            break
        time.sleep(2)

    if not result["results"]:
        print("  No results found.")
        return

    for row in result["results"][:10]:
        values = {field["field"]: field["value"] for field in row}
        # Remove @ptr field
        values.pop("@ptr", None)
        print(f"  {values}")

    print(f"  Total results: {len(result['results'])}")

def main():
    logs = boto3.client("logs")
    log_group = "/saa-lab/vpc-flow-logs"

    # Query 1: Top source IPs with rejected traffic
    run_insights_query(logs, log_group,
        """fields srcAddr, dstAddr, dstPort, action
        | filter action = "REJECT"
        | stats count(*) as rejectCount by srcAddr
        | sort rejectCount desc
        | limit 10""",
        "Top 10 source IPs with REJECTED traffic"
    )

    # Query 2: Most common destination ports
    run_insights_query(logs, log_group,
        """fields dstPort, protocol, action
        | stats count(*) as cnt by dstPort, action
        | sort cnt desc
        | limit 15""",
        "Most common destination ports"
    )

    # Query 3: Traffic volume by source IP
    run_insights_query(logs, log_group,
        """fields srcAddr, bytes
        | stats sum(bytes) as totalBytes by srcAddr
        | sort totalBytes desc
        | limit 10""",
        "Top 10 source IPs by traffic volume (bytes)"
    )

    # Query 4: All accepted traffic on port 22 (SSH)
    run_insights_query(logs, log_group,
        """fields @timestamp, srcAddr, dstAddr, dstPort, action
        | filter dstPort = 22 and action = "ACCEPT"
        | sort @timestamp desc
        | limit 20""",
        "Accepted SSH traffic (port 22)"
    )

if __name__ == "__main__":
    main()
```

```bash
python analyze_flow_logs.py
```

---

## Part 4: Validate CloudTrail Log Integrity

### Step 4.1 — Validate Logs

```bash
# Validate CloudTrail log file integrity
# This proves logs have not been tampered with
aws cloudtrail validate-logs \
  --trail-arn $(aws cloudtrail describe-trails --trail-name-list saa-lab-trail --query "trailList[0].TrailARN" --output text) \
  --start-time $(date -u -v-1H +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "1 hour ago" +%Y-%m-%dT%H:%M:%SZ)

# Output will show "valid" for each digest file checked
```

---

## Cleanup

```bash
# Stop CloudTrail logging
aws cloudtrail stop-logging --name saa-lab-trail
aws cloudtrail delete-trail --name saa-lab-trail

# Delete VPC Flow Logs
FLOW_LOG_ID=$(aws ec2 describe-flow-logs --filter "Name=tag:Purpose,Values=SAA-Lab" --query "FlowLogs[0].FlowLogId" --output text)
aws ec2 delete-flow-logs --flow-log-ids $FLOW_LOG_ID

# Delete log groups
aws logs delete-log-group --log-group-name "/saa-lab/cloudtrail"
aws logs delete-log-group --log-group-name "/saa-lab/vpc-flow-logs"

# Delete S3 bucket
aws s3 rm s3://$TRAIL_BUCKET --recursive
aws s3 rb s3://$TRAIL_BUCKET

# Delete IAM roles
aws iam delete-role-policy --role-name saa-lab-cloudtrail-cw-role --policy-name CloudWatchLogsAccess
aws iam delete-role --role-name saa-lab-cloudtrail-cw-role

aws iam delete-role-policy --role-name saa-lab-flow-logs-role --policy-name FlowLogsAccess
aws iam delete-role --role-name saa-lab-flow-logs-role

echo "Cleanup complete."
```

---

## Review Questions

1. What is the difference between management events and data events in CloudTrail?
2. How many free management event trails can you have per region?
3. What does CloudTrail log file integrity validation prove?
4. At what levels can you enable VPC Flow Logs?
5. What types of traffic are NOT captured by VPC Flow Logs?

## Answers

1. Management events are control plane operations (create/delete/modify resources). Data events are data plane operations (read/write on specific resources like S3 GetObject or Lambda Invoke).
2. One. The first trail that logs management events in each region is free.
3. It proves that log files have not been modified, deleted, or tampered with after delivery. CloudTrail creates SHA-256 digest files for verification.
4. VPC level, subnet level, or ENI (network interface) level.
5. Traffic to/from 169.254.169.254 (metadata), DHCP traffic, traffic to the VPC DNS server, traffic to the reserved IP of the VPC router, and Windows license activation traffic.

---

## Next Lab

Proceed to **Lab 07: CloudFormation Deploy** to write and deploy infrastructure as code.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Estimated Time: 60-75 minutes
- Enable CloudTrail (Multi-Region)
- Look Up CloudTrail Events
- Enable VPC Flow Logs

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"The security group allows the traffic."* |
| ✓ | *"A security group is a stateful allow-list attached to an ENI. Traffic matching an inbound rule is permitted and the reply is permitted automatically, because the connection is tracked — which is why you never write an outbound rule for a reply."* |

**Trace it:** A request from the internet to an instance in a private subnet. Name every hop, every route-table lookup, and every rule evaluated, in order.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** [Timeouts, retries and backoff with jitter](https://aws.amazon.com/builders-library/timeouts-retries-and-backoff-with-jitter/) — 15 minutes from the AWS Builders' Library, and it changes how you write every client you touch afterwards.
Full list per domain: [`SOURCES.md`](../SOURCES.md#aws)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../MASTERY.md)

<!-- /feynman-check -->
