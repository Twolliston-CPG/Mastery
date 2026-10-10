# Lab 05 — CloudWatch Monitoring

## Objective

Create custom CloudWatch metrics with Boto3, set up alarms with SNS notifications, create a dashboard, configure the CloudWatch Agent on EC2 for memory/disk metrics, and create metric filters on log groups.

## Prerequisites

- AWS CLI configured
- Python 3.9+ with `boto3`
- An EC2 instance running (t2.micro free tier)
- SNS topic knowledge (Phase 3)

## Estimated Time: 75-90 minutes

## Cost Estimate

| Resource | Cost | Notes |
|----------|------|-------|
| Custom metrics | Free tier (10 custom metrics free) | Within free tier |
| Alarms | Free tier (10 alarms free) | Within free tier |
| Dashboard | Free (up to 3 dashboards) | Within free tier |
| EC2 t2.micro | Free tier | 750 hours/month |
| SNS | Free tier | First 1M requests free |
| **Total** | **$0** | All within free tier |

---

## Part 1: Publish Custom Metrics (Boto3)

### Step 1.1 — Publish a Simple Custom Metric

Create `publish_metrics.py`:

```python
"""
Publish custom CloudWatch metrics.
Simulates an application publishing business metrics.
"""

import boto3
import random
import time
from datetime import datetime

def publish_single_metric(cw, value):
    """Publish a single metric data point."""
    cw.put_metric_data(
        Namespace="SAALab/WebApp",
        MetricData=[
            {
                "MetricName": "ActiveUsers",
                "Value": value,
                "Unit": "Count",
                "Timestamp": datetime.utcnow(),
                "Dimensions": [
                    {"Name": "Environment", "Value": "Production"},
                    {"Name": "Service", "Value": "WebApp"}
                ]
            }
        ]
    )

def publish_multiple_metrics(cw):
    """Publish multiple metrics in a single API call."""
    cw.put_metric_data(
        Namespace="SAALab/WebApp",
        MetricData=[
            {
                "MetricName": "RequestLatency",
                "Value": random.uniform(50, 500),
                "Unit": "Milliseconds",
                "Dimensions": [
                    {"Name": "Environment", "Value": "Production"},
                    {"Name": "Endpoint", "Value": "/api/users"}
                ]
            },
            {
                "MetricName": "RequestLatency",
                "Value": random.uniform(100, 800),
                "Unit": "Milliseconds",
                "Dimensions": [
                    {"Name": "Environment", "Value": "Production"},
                    {"Name": "Endpoint", "Value": "/api/orders"}
                ]
            },
            {
                "MetricName": "ErrorCount",
                "Value": random.randint(0, 5),
                "Unit": "Count",
                "Dimensions": [
                    {"Name": "Environment", "Value": "Production"}
                ]
            },
            {
                "MetricName": "QueueDepth",
                "Value": random.randint(0, 100),
                "Unit": "Count",
                "Dimensions": [
                    {"Name": "QueueName", "Value": "OrderProcessing"}
                ]
            }
        ]
    )

def main():
    cw = boto3.client("cloudwatch")

    print("Publishing custom metrics to CloudWatch...")
    print("Sending 20 data points (one every 10 seconds)...")

    for i in range(20):
        active_users = random.randint(10, 200)
        publish_single_metric(cw, active_users)
        publish_multiple_metrics(cw)
        print(f"  [{i+1}/20] ActiveUsers={active_users}, Latency/Errors/Queue published")
        time.sleep(10)

    print("\nDone! Metrics published to namespace 'SAALab/WebApp'")
    print("View in CloudWatch console: Metrics > All metrics > SAALab/WebApp")

if __name__ == "__main__":
    main()
```

```bash
python publish_metrics.py
```

### Step 1.2 — Query Custom Metrics (CLI)

```bash
# List custom metrics in our namespace
aws cloudwatch list-metrics --namespace "SAALab/WebApp"

# Get metric statistics
aws cloudwatch get-metric-statistics \
  --namespace "SAALab/WebApp" \
  --metric-name "ActiveUsers" \
  --dimensions Name=Environment,Value=Production Name=Service,Value=WebApp \
  --start-time $(date -u -v-1H +%Y-%m-%dT%H:%M:%S 2>/dev/null || date -u -d "1 hour ago" +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Average Maximum Minimum
```

---

## Part 2: Create CloudWatch Alarms

### Step 2.1 — Create an SNS Topic for Notifications

```bash
# Create SNS topic
TOPIC_ARN=$(aws sns create-topic --name saa-lab-cloudwatch-alerts --query "TopicArn" --output text)
echo "Topic ARN: $TOPIC_ARN"

# Subscribe your email (replace with your email)
aws sns subscribe \
  --topic-arn $TOPIC_ARN \
  --protocol email \
  --notification-endpoint your-email@example.com

echo "Check your email and confirm the subscription!"
```

### Step 2.2 — Create an Alarm on Custom Metric (CLI)

```bash
# Alarm: Alert when ActiveUsers exceeds 150
aws cloudwatch put-metric-alarm \
  --alarm-name "saa-lab-high-active-users" \
  --alarm-description "Alert when active users exceeds 150" \
  --namespace "SAALab/WebApp" \
  --metric-name "ActiveUsers" \
  --dimensions Name=Environment,Value=Production Name=Service,Value=WebApp \
  --statistic Average \
  --period 60 \
  --threshold 150 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2 \
  --datapoints-to-alarm 2 \
  --alarm-actions $TOPIC_ARN \
  --ok-actions $TOPIC_ARN \
  --treat-missing-data missing

echo "Alarm created: saa-lab-high-active-users"
```

### Step 2.3 — Create an Alarm on EC2 CPU (Boto3)

Create `create_alarms.py`:

```python
"""
Create CloudWatch alarms using Boto3.
Demonstrates different alarm configurations.
"""

import boto3
import os

def main():
    cw = boto3.client("cloudwatch")

    # You need a running EC2 instance ID and an SNS topic ARN
    # Replace these values:
    instance_id = "i-YOUR_INSTANCE_ID"  # Replace with your EC2 instance ID
    sns_topic_arn = "YOUR_TOPIC_ARN"     # Replace with your SNS topic ARN

    # --- Alarm 1: High CPU ---
    cw.put_metric_alarm(
        AlarmName="saa-lab-ec2-high-cpu",
        AlarmDescription="Alert when EC2 CPU exceeds 80% for 3 consecutive periods",
        Namespace="AWS/EC2",
        MetricName="CPUUtilization",
        Dimensions=[{"Name": "InstanceId", "Value": instance_id}],
        Statistic="Average",
        Period=300,  # 5 minutes
        Threshold=80.0,
        ComparisonOperator="GreaterThanThreshold",
        EvaluationPeriods=3,
        DatapointsToAlarm=3,
        AlarmActions=[sns_topic_arn],
        OKActions=[sns_topic_arn],
        TreatMissingData="missing"
    )
    print("Created alarm: saa-lab-ec2-high-cpu")

    # --- Alarm 2: Error rate too high (custom metric) ---
    cw.put_metric_alarm(
        AlarmName="saa-lab-high-error-rate",
        AlarmDescription="Alert when error count exceeds 3 in any 1-minute period",
        Namespace="SAALab/WebApp",
        MetricName="ErrorCount",
        Dimensions=[{"Name": "Environment", "Value": "Production"}],
        Statistic="Sum",
        Period=60,
        Threshold=3.0,
        ComparisonOperator="GreaterThanThreshold",
        EvaluationPeriods=1,
        DatapointsToAlarm=1,
        AlarmActions=[sns_topic_arn],
        TreatMissingData="notBreaching"
    )
    print("Created alarm: saa-lab-high-error-rate")

    # --- Alarm 3: EC2 Status Check Failed (auto-recovery) ---
    cw.put_metric_alarm(
        AlarmName="saa-lab-ec2-status-check",
        AlarmDescription="Recover EC2 instance on status check failure",
        Namespace="AWS/EC2",
        MetricName="StatusCheckFailed_System",
        Dimensions=[{"Name": "InstanceId", "Value": instance_id}],
        Statistic="Maximum",
        Period=60,
        Threshold=1.0,
        ComparisonOperator="GreaterThanOrEqualToThreshold",
        EvaluationPeriods=2,
        DatapointsToAlarm=2,
        AlarmActions=[
            f"arn:aws:automate:us-east-1:ec2:recover",  # Auto-recover the instance
            sns_topic_arn
        ],
        TreatMissingData="missing"
    )
    print("Created alarm: saa-lab-ec2-status-check (with auto-recovery)")

    # List all alarms
    print("\nAll alarms in account:")
    alarms = cw.describe_alarms(AlarmNamePrefix="saa-lab")
    for alarm in alarms["MetricAlarms"]:
        print(f"  {alarm['AlarmName']} - State: {alarm['StateValue']}")

if __name__ == "__main__":
    main()
```

```bash
python create_alarms.py
```

### Step 2.4 — Test an Alarm by Setting Its State

```bash
# Force the alarm into ALARM state to test notification
aws cloudwatch set-alarm-state \
  --alarm-name "saa-lab-high-active-users" \
  --state-value ALARM \
  --state-reason "Testing alarm notification"

echo "Alarm triggered! Check your email for the SNS notification."
```

---

## Part 3: Create a CloudWatch Dashboard

### Step 3.1 — Create Dashboard (CLI)

```bash
aws cloudwatch put-dashboard \
  --dashboard-name "SAALab-Dashboard" \
  --dashboard-body '{
    "widgets": [
      {
        "type": "metric",
        "x": 0, "y": 0, "width": 12, "height": 6,
        "properties": {
          "title": "Active Users",
          "metrics": [
            ["SAALab/WebApp", "ActiveUsers", "Environment", "Production", "Service", "WebApp", {"stat": "Average", "period": 60}]
          ],
          "view": "timeSeries",
          "region": "us-east-1"
        }
      },
      {
        "type": "metric",
        "x": 12, "y": 0, "width": 12, "height": 6,
        "properties": {
          "title": "Error Count",
          "metrics": [
            ["SAALab/WebApp", "ErrorCount", "Environment", "Production", {"stat": "Sum", "period": 60}]
          ],
          "view": "timeSeries",
          "region": "us-east-1"
        }
      },
      {
        "type": "metric",
        "x": 0, "y": 6, "width": 12, "height": 6,
        "properties": {
          "title": "Request Latency by Endpoint",
          "metrics": [
            ["SAALab/WebApp", "RequestLatency", "Environment", "Production", "Endpoint", "/api/users", {"stat": "Average", "period": 60}],
            ["SAALab/WebApp", "RequestLatency", "Environment", "Production", "Endpoint", "/api/orders", {"stat": "Average", "period": 60}]
          ],
          "view": "timeSeries",
          "region": "us-east-1"
        }
      },
      {
        "type": "metric",
        "x": 12, "y": 6, "width": 12, "height": 6,
        "properties": {
          "title": "Queue Depth",
          "metrics": [
            ["SAALab/WebApp", "QueueDepth", "QueueName", "OrderProcessing", {"stat": "Average", "period": 60}]
          ],
          "view": "timeSeries",
          "region": "us-east-1"
        }
      }
    ]
  }'

echo "Dashboard created! View at: https://console.aws.amazon.com/cloudwatch/home#dashboards:name=SAALab-Dashboard"
```

---

## Part 4: CloudWatch Agent on EC2 (Conceptual + Config)

If you have a running EC2 instance, install the CloudWatch Agent to collect memory and disk metrics.

### Step 4.1 — Attach IAM Role

```bash
# The instance needs the CloudWatchAgentServerPolicy
# If your instance already has a role, add the policy to it.
# Otherwise, create a new role and attach it to the instance.

# Add policy to existing instance profile role
aws iam attach-role-policy \
  --role-name YOUR_EC2_ROLE \
  --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy
```

### Step 4.2 — Install Agent via SSM (Run Command)

```bash
# Install CloudWatch Agent using SSM Run Command
aws ssm send-command \
  --instance-ids "i-YOUR_INSTANCE_ID" \
  --document-name "AWS-ConfigureAWSPackage" \
  --parameters '{"action":["Install"],"name":["AmazonCloudWatchAgent"]}'
```

### Step 4.3 — Agent Configuration File

The CloudWatch Agent uses a JSON config file. Here is a typical configuration:

```json
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "root"
  },
  "metrics": {
    "namespace": "SAALab/EC2Custom",
    "append_dimensions": {
      "InstanceId": "${aws:InstanceId}",
      "AutoScalingGroupName": "${aws:AutoScalingGroupName}"
    },
    "metrics_collected": {
      "mem": {
        "measurement": ["mem_used_percent", "mem_total", "mem_used"],
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": ["used_percent", "total", "used"],
        "metrics_collection_interval": 60,
        "resources": ["/"]
      },
      "swap": {
        "measurement": ["swap_used_percent"],
        "metrics_collection_interval": 60
      }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/messages",
            "log_group_name": "/saa-lab/ec2/var/log/messages",
            "log_stream_name": "{instance_id}",
            "retention_in_days": 7
          },
          {
            "file_path": "/var/log/httpd/access_log",
            "log_group_name": "/saa-lab/ec2/httpd/access_log",
            "log_stream_name": "{instance_id}",
            "retention_in_days": 7
          }
        ]
      }
    }
  }
}
```

### Step 4.4 — Store Config in SSM and Start Agent

```bash
# Store the config in SSM Parameter Store
aws ssm put-parameter \
  --name "AmazonCloudWatch-saa-lab-config" \
  --type "String" \
  --value "$(cat cloudwatch-agent-config.json)"

# Start the agent with the config (via SSM Run Command)
aws ssm send-command \
  --instance-ids "i-YOUR_INSTANCE_ID" \
  --document-name "AmazonCloudWatch-ManageAgent" \
  --parameters '{"action":["configure"],"mode":["ec2"],"optionalConfigurationSource":["ssm"],"optionalConfigurationLocation":["AmazonCloudWatch-saa-lab-config"],"optionalRestart":["yes"]}'
```

---

## Part 5: Metric Filters on Log Groups

### Step 5.1 — Create a Log Group and Publish Sample Logs

```python
"""
Create a log group and publish sample log events with errors.
Then create a metric filter to count errors.
"""

import boto3
import time
import random

def main():
    logs = boto3.client("logs")
    log_group = "/saa-lab/application"
    log_stream = "web-server-001"

    # Create log group
    try:
        logs.create_log_group(logGroupName=log_group)
        print(f"Created log group: {log_group}")
    except logs.exceptions.ResourceAlreadyExistsException:
        print(f"Log group already exists: {log_group}")

    # Create log stream
    try:
        logs.create_log_stream(logGroupName=log_group, logStreamName=log_stream)
    except logs.exceptions.ResourceAlreadyExistsException:
        pass

    # Publish sample log events
    sample_logs = [
        "INFO: Request processed successfully for /api/users",
        "INFO: Request processed successfully for /api/orders",
        "ERROR: Database connection timeout after 30s",
        "INFO: Health check passed",
        "ERROR: NullPointerException in OrderService.processOrder()",
        "WARN: Slow query detected (2.5s) for SELECT * FROM orders",
        "INFO: Request processed successfully for /api/products",
        "ERROR: HTTP 500 Internal Server Error on /api/checkout",
        "INFO: User login successful for user@example.com",
        "ERROR: S3 upload failed - Access Denied",
        "INFO: Cache hit ratio: 0.85",
        "WARN: Memory usage at 78%",
        "ERROR: Connection refused to downstream service",
        "INFO: Batch job completed - processed 1000 records",
        "INFO: Request processed successfully for /api/users",
    ]

    events = []
    for msg in sample_logs:
        events.append({
            "timestamp": int(time.time() * 1000),
            "message": msg
        })
        time.sleep(0.1)  # Small delay for different timestamps

    logs.put_log_events(
        logGroupName=log_group,
        logStreamName=log_stream,
        logEvents=events
    )
    print(f"Published {len(events)} log events to {log_group}/{log_stream}")

if __name__ == "__main__":
    main()
```

```bash
python publish_logs.py
```

### Step 5.2 — Create a Metric Filter

```bash
# Create a metric filter that counts ERROR log entries
aws logs put-metric-filter \
  --log-group-name "/saa-lab/application" \
  --filter-name "saa-lab-error-count" \
  --filter-pattern "ERROR" \
  --metric-transformations '[{
    "metricName": "ApplicationErrorCount",
    "metricNamespace": "SAALab/AppLogs",
    "metricValue": "1",
    "defaultValue": 0
  }]'

echo "Metric filter created: counts 'ERROR' entries in application logs"

# Verify the filter
aws logs describe-metric-filters --log-group-name "/saa-lab/application"
```

### Step 5.3 — Create an Alarm on the Metric Filter

```bash
# Alarm when more than 3 errors in 5 minutes
aws cloudwatch put-metric-alarm \
  --alarm-name "saa-lab-app-error-alarm" \
  --alarm-description "Alert when application errors exceed 3 in 5 minutes" \
  --namespace "SAALab/AppLogs" \
  --metric-name "ApplicationErrorCount" \
  --statistic Sum \
  --period 300 \
  --threshold 3 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 1 \
  --alarm-actions $TOPIC_ARN \
  --treat-missing-data notBreaching

echo "Alarm created on metric filter"
```

---

## Cleanup

```bash
# Delete alarms
aws cloudwatch delete-alarms --alarm-names \
  "saa-lab-high-active-users" \
  "saa-lab-ec2-high-cpu" \
  "saa-lab-high-error-rate" \
  "saa-lab-ec2-status-check" \
  "saa-lab-app-error-alarm"

# Delete dashboard
aws cloudwatch delete-dashboards --dashboard-names "SAALab-Dashboard"

# Delete metric filter
aws logs delete-metric-filter \
  --log-group-name "/saa-lab/application" \
  --filter-name "saa-lab-error-count"

# Delete log group
aws logs delete-log-group --log-group-name "/saa-lab/application"

# Delete SNS topic
aws sns delete-topic --topic-arn $TOPIC_ARN

# Delete custom metrics (they expire automatically after 15 months with no new data)
echo "Custom metrics will expire automatically. No manual deletion needed."

echo "Cleanup complete."
```

---

## Review Questions

1. Which EC2 metrics require the CloudWatch Agent?
2. What is the maximum resolution for a custom CloudWatch metric?
3. How do you create a CloudWatch metric from log data?
4. What is the difference between a standard alarm and a composite alarm?
5. How do you stream logs to S3 in real-time?

## Answers

1. Memory utilization, disk space usage, swap usage, and number of processes.
2. 1 second (high-resolution custom metric). Standard is 1 minute minimum.
3. Create a metric filter on a log group. The filter pattern matches log events and increments a custom metric.
4. A standard alarm monitors one metric. A composite alarm combines multiple alarms with AND/OR logic to reduce false positives.
5. Subscription filter -> Kinesis Data Firehose -> S3. Direct export to S3 (`create-export-task`) is NOT real-time (up to 12 hours).

---

## Next Lab

Proceed to **Lab 06: CloudTrail & Flow Logs** to enable audit logging and network traffic analysis.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Estimated Time: 75-90 minutes
- Publish Custom Metrics (Boto3)
- Create CloudWatch Alarms
- Create a CloudWatch Dashboard

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
