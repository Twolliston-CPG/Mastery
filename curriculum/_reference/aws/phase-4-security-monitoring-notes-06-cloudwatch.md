# 06 — CloudWatch (Metrics, Alarms, Logs, Dashboards)

## Overview

Amazon CloudWatch is the central monitoring service for all AWS resources and applications. It collects metrics, creates alarms, visualizes data, and processes logs. CloudWatch appears in nearly every exam scenario that involves monitoring, scaling, or troubleshooting.

---

## CloudWatch Metrics

### Standard vs Custom Metrics

| Property | Standard Metrics | Custom Metrics |
|----------|-----------------|----------------|
| **Who publishes** | AWS services automatically | You (via API, CLI, or Agent) |
| **Cost** | Free (basic monitoring) | $0.30/metric/month (first 10K, then cheaper) |
| **Resolution** | 5 minutes (basic) or 1 minute (detailed) | 1 second to 1 minute (high-resolution) |
| **Examples** | CPU utilization, network in/out, disk read/write (EBS), status checks | Memory usage, disk space, application-specific metrics |
| **Retention** | Based on resolution (see below) | Same retention policy |

### Metric Resolution

| Resolution | Period | Retention |
|------------|--------|-----------|
| High-resolution | 1 second | 3 hours |
| 1-minute | 60 seconds | 15 days |
| 5-minute | 300 seconds | 63 days |
| 1-hour | 3600 seconds | 455 days (15 months) |

As metrics age, they are automatically aggregated to lower resolutions.

### What EC2 Does NOT Report by Default

These require the **CloudWatch Agent** (important for exam):

| Metric | Available by Default? | Needs Agent? |
|--------|----------------------|-------------|
| CPU utilization | Yes | No |
| Network in/out | Yes | No |
| Disk read/write ops | Yes (EBS-level) | No |
| Status checks | Yes | No |
| **Memory utilization** | **No** | **Yes** |
| **Disk space usage** | **No** | **Yes** |
| **Number of processes** | **No** | **Yes** |
| **Swap usage** | **No** | **Yes** |

### Exam Tip
"Monitor memory utilization on EC2" => Install CloudWatch Agent. This is one of the most frequently tested facts.

### Publishing Custom Metrics

```python
import boto3

cloudwatch = boto3.client("cloudwatch")

cloudwatch.put_metric_data(
    Namespace="MyApplication",
    MetricData=[
        {
            "MetricName": "ActiveUsers",
            "Value": 42,
            "Unit": "Count",
            "Dimensions": [
                {"Name": "Environment", "Value": "Production"},
                {"Name": "Service", "Value": "WebApp"}
            ]
        }
    ]
)
```

### Dimensions
- Name/value pairs that identify a metric uniquely
- Examples: InstanceId, AutoScalingGroupName, LoadBalancer
- Up to 30 dimensions per metric
- Same metric name with different dimensions = different metric streams

---

## CloudWatch Alarms

### Alarm States

| State | Meaning |
|-------|---------|
| **OK** | Metric is within the defined threshold |
| **ALARM** | Metric has breached the threshold |
| **INSUFFICIENT_DATA** | Not enough data to determine state (alarm just created, metric not reporting) |

### Alarm Components

| Component | Description |
|-----------|-------------|
| **Metric** | The CloudWatch metric to monitor |
| **Threshold** | The value that triggers the alarm (e.g., CPU > 80%) |
| **Period** | The length of time to evaluate the metric (e.g., 300 seconds) |
| **Evaluation Periods** | Number of consecutive periods the threshold must be breached (e.g., 3) |
| **Datapoints to Alarm** | Minimum breached periods within evaluation window (e.g., 2 of 3) |
| **Actions** | What happens when alarm state changes |

### Alarm Actions

| Action Type | Target |
|-------------|--------|
| **SNS notification** | Send email, trigger Lambda, push to SQS |
| **Auto Scaling** | Scale in/out an Auto Scaling group |
| **EC2 action** | Stop, terminate, reboot, or recover an EC2 instance |
| **Systems Manager** | Trigger OpsItem creation |

### Composite Alarms
- Combine multiple alarms using AND/OR logic
- Reduces alarm noise (e.g., only alert if BOTH CPU is high AND memory is high)
- Helps avoid false positives from individual metrics

```
Composite Alarm Example:

ALARM state only when:
  (CPU_Alarm = ALARM) AND (Memory_Alarm = ALARM)

This avoids alerting when only one metric spikes temporarily.
```

---

## CloudWatch Logs

### Hierarchy

**CloudWatch Logs**

- Log Group          (e.g., /aws/lambda/my-function)
  - Log Stream     (e.g., 2024/01/15/[$LATEST]abc123)
    - Log Event  (timestamp + message)
    - Log Event
    - Log Event
  - Log Stream
  - Log Stream
- Log Group          (e.g., /var/log/messages)
  - `...`


### Key Concepts

| Concept | Description |
|---------|-------------|
| **Log Group** | Collection of log streams with shared retention, monitoring, and access settings |
| **Log Stream** | Sequence of log events from the same source (e.g., one Lambda invocation, one EC2 instance) |
| **Retention** | Configurable: 1 day to 10 years, or never expire. Default: never expire. |
| **Subscription Filter** | Real-time stream of log events to Lambda, Kinesis Data Streams, or Kinesis Data Firehose |
| **Metric Filter** | Extract metric values from log events (e.g., count ERROR occurrences) |
| **Log Insights** | Interactive query language for searching and analyzing log data |
| **Export** | Export log data to S3 (can take up to 12 hours — not real-time) |

### Metric Filters

Turn log data into CloudWatch metrics:

```
Example: Count HTTP 500 errors in ALB access logs

Filter Pattern: [ip, id, user, timestamp, request, status_code=5*, size]

This creates a metric that increments each time a 500-status line appears.
You can then create an alarm: "Alert if > 10 HTTP 500 errors in 5 minutes"
```

### CloudWatch Logs Insights

Query language for analyzing logs interactively:

```
# Find the 25 most recent errors
fields @timestamp, @message
| filter @message like /ERROR/
| sort @timestamp desc
| limit 25

# Count events by status code per hour
fields @timestamp, status_code
| stats count(*) by bin(1h), status_code

# Average Lambda duration
fields @timestamp, @duration
| stats avg(@duration) as avgDuration by bin(5m)

# Find top 10 most expensive Lambda invocations
fields @timestamp, @billedDuration, @memorySize
| sort @billedDuration desc
| limit 10
```

### Log Sources

| Service | Log Group Pattern | Automatic? |
|---------|------------------|------------|
| Lambda | `/aws/lambda/<function-name>` | Yes (if execution role has permissions) |
| API Gateway | Custom name | Must enable |
| ECS | Custom name | Must configure in task definition |
| VPC Flow Logs | Custom name | Must enable |
| CloudTrail | Custom name | Must configure |
| EC2 | Custom name | Requires CloudWatch Agent |
| Route 53 | `/aws/route53/<hosted-zone-id>` | Must enable query logging |

---

## CloudWatch Agent

### What It Does
- Installs on EC2 instances (or on-premises servers)
- Collects **memory, disk, swap, process** metrics (not available by default)
- Sends custom log files to CloudWatch Logs
- Uses a JSON configuration file

### Setup Steps
1. Create IAM role with `CloudWatchAgentServerPolicy`
2. Install the agent (SSM or manual download)
3. Configure via wizard or JSON config file
4. Start the agent

### Unified CloudWatch Agent vs Old Monitoring Scripts
- Old: `perl` monitoring scripts (deprecated) — do not choose these on the exam
- New: Unified CloudWatch Agent — always the correct answer
- Collects both metrics AND logs in a single agent

---

## CloudWatch Anomaly Detection

- Uses ML to establish a baseline (band) for a metric
- Alerts when metric goes outside the expected band
- No need to set static thresholds
- Good for metrics with natural variability (e.g., request counts that vary by time of day)
- Creates an anomaly detection model after 2 weeks of data

---

## CloudWatch Contributor Insights

- Analyze log data to identify top contributors
- Example: "Top 10 IP addresses generating the most errors"
- Example: "Top 10 URLs with the highest latency"
- Works with VPC Flow Logs, CloudTrail logs, any CloudWatch Logs
- Pre-built rules available for common services

---

## CloudWatch Dashboards

- Custom visualizations of metrics across accounts and regions
- Up to 3 dashboards (50 metrics each) free
- Additional dashboards: $3/month each
- Can be shared publicly or with specific accounts
- Auto-refresh intervals: 10s, 1m, 2m, 5m, 15m
- Cross-account, cross-region dashboards supported

---

## Common Exam Scenarios

| Scenario | Answer |
|----------|--------|
| "Monitor EC2 memory utilization" | CloudWatch Agent |
| "Alert when CPU > 80% for 3 consecutive periods" | CloudWatch Alarm |
| "Alert only when BOTH CPU and memory are high" | Composite Alarm |
| "Count number of 500 errors in application logs" | Metric Filter on Log Group |
| "Search through Lambda logs for specific errors" | CloudWatch Logs Insights |
| "Stream logs in real-time to a Lambda for processing" | Subscription Filter |
| "Export logs to S3 for long-term archival" | Export task (not real-time, up to 12 hours) |
| "Real-time log export to S3" | Subscription Filter -> Kinesis Data Firehose -> S3 |
| "Metric behaves differently on weekends, static thresholds won't work" | Anomaly Detection |
| "Find top talkers in VPC Flow Logs" | Contributor Insights |
| "Single dashboard showing metrics from 5 accounts" | Cross-account CloudWatch Dashboard |

---

## Next Steps

- Complete **Lab 05: CloudWatch Monitoring** to create custom metrics, alarms, and dashboards
- Continue to **Note 07: CloudTrail & Logging** for audit trails, VPC Flow Logs, and X-Ray

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- CloudWatch Metrics
- CloudWatch Alarms
- CloudWatch Logs
- CloudWatch Agent

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
