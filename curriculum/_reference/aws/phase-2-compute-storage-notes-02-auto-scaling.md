# 02 — EC2 Auto Scaling

## Table of Contents
1. [Overview](#overview)
2. [Launch Templates vs Launch Configurations](#launch-templates-vs-launch-configurations)
3. [Auto Scaling Group (ASG) Basics](#auto-scaling-group-asg-basics)
4. [Scaling Policies](#scaling-policies)
5. [Cooldown Period](#cooldown-period)
6. [Lifecycle Hooks](#lifecycle-hooks)
7. [Warm Pools](#warm-pools)
8. [Instance Refresh](#instance-refresh)
9. [Key Takeaways for the Exam](#key-takeaways-for-the-exam)

---

## Overview

EC2 Auto Scaling automatically adjusts the number of EC2 instances in a group based on demand or a schedule. It ensures you have the right number of instances to handle your workload, improving availability and reducing cost.

**Three core components:**
1. **Launch Template / Launch Configuration** — What to launch (AMI, instance type, key pair, security groups, user data).
2. **Auto Scaling Group (ASG)** — Where to launch (VPC, subnets, AZs) and how many (min, max, desired).
3. **Scaling Policies** — When to scale (based on metrics, schedules, or predictions).

---

## Launch Templates vs Launch Configurations

| Feature | Launch Template | Launch Configuration |
|---|---|---|
| Status | **Recommended** (current) | **Legacy** (do not use for new setups) |
| Versioning | Yes — multiple versions with a default | No — immutable, must create new |
| Instance types | Can specify multiple (mixed instances) | Single instance type only |
| Spot + On-Demand mix | Supported | Not supported |
| T2/T3 Unlimited | Can configure | Can configure |
| Placement groups | Can specify | Cannot specify |
| Capacity Reservations | Supported | Not supported |
| Dedicated Hosts | Supported | Not supported |
| Elastic GPU | Supported | Not supported |

**Exam tip:** If a question asks about mixing Spot and On-Demand in an ASG, or using multiple instance types, the answer requires a **Launch Template** (not a Launch Configuration).

### Launch Template Example (CLI)

```bash
aws ec2 create-launch-template \
  --launch-template-name my-web-template \
  --version-description "v1" \
  --launch-template-data '{
    "ImageId": "ami-0abcdef1234567890",
    "InstanceType": "t3.micro",
    "KeyName": "my-key",
    "SecurityGroupIds": ["sg-0abc123"],
    "UserData": "IyEvYmluL2Jhc2gKeXVtIHVwZGF0ZSAteQo=",
    "TagSpecifications": [
      {
        "ResourceType": "instance",
        "Tags": [{"Key": "Environment", "Value": "dev"}]
      }
    ]
  }'
```

---

## Auto Scaling Group (ASG) Basics

### Capacity Settings

| Setting | Description |
|---|---|
| **Minimum capacity** | The fewest instances the ASG will maintain. Never scales below this. |
| **Maximum capacity** | The most instances the ASG will allow. Never scales above this. |
| **Desired capacity** | The target number of instances right now. ASG works to maintain this count. |

Example: min=2, desired=2, max=10. Under normal load, 2 instances run. Under high load, up to 10.

### Multi-AZ Distribution

- ASG distributes instances **evenly across AZs** in the specified subnets.
- If one AZ becomes unhealthy, ASG launches replacement instances in the remaining AZs.
- **AZ Rebalancing**: If an AZ imbalance is detected, ASG launches new instances in the under-represented AZ before terminating excess ones in the over-represented AZ (this can temporarily exceed max capacity by 10%).

### Health Checks

| Type | Description | Default |
|---|---|---|
| **EC2** | Instance status checks (running, not impaired) | Always enabled |
| **ELB** | Target group health check (HTTP 200 from app) | Must be explicitly enabled |
| **Custom** | Via the Auto Scaling API (external monitoring) | Must be explicitly configured |

**Exam tip:** By default, ASG only uses EC2 health checks. If you want ASG to replace instances that fail application-level health checks, you must **enable ELB health checks** on the ASG.

### Termination Policy

When scaling in, ASG decides which instance to terminate using the **default termination policy** (in order):

1. Select the AZ with the most instances (for rebalancing).
2. Select the instance with the **oldest launch configuration/template**.
3. Select the instance **closest to the next billing hour**.
4. If tied, select randomly.

Other policies: `OldestInstance`, `NewestInstance`, `OldestLaunchConfiguration`, `ClosestToNextInstanceHour`, `OldestLaunchTemplate`, `AllocationStrategy`.

---

## Scaling Policies

### Comparison Table

| Policy Type | How It Works | Best For | Example |
|---|---|---|---|
| **Target Tracking** | Maintains a metric at a target value (like a thermostat) | Most common; simple and effective | Keep average CPU at 50% |
| **Step Scaling** | Adds/removes instances in steps based on alarm thresholds | Granular control over scaling increments | CPU > 60%: add 1; CPU > 80%: add 3 |
| **Simple Scaling** | Adds/removes a fixed number based on a single alarm | Legacy; use Step or Target Tracking instead | CPU > 70%: add 1 |
| **Scheduled Scaling** | Changes capacity at a specific time | Predictable demand patterns | Scale to 10 instances at 9 AM, back to 2 at 6 PM |
| **Predictive Scaling** | Uses ML to forecast demand and pre-scale | Cyclical patterns that repeat daily/weekly | Traffic peaks every day at noon |

### Target Tracking — Details

The simplest and most commonly recommended policy. You choose a metric and a target value; ASG does the rest.

**Predefined metrics:**
- `ASGAverageCPUUtilization` (e.g., target 50%)
- `ASGAverageNetworkIn` (bytes)
- `ASGAverageNetworkOut` (bytes)
- `ALBRequestCountPerTarget` (e.g., target 1000 requests/target)

```bash
aws autoscaling put-scaling-policy \
  --auto-scaling-group-name my-asg \
  --policy-name cpu-target-50 \
  --policy-type TargetTrackingScaling \
  --target-tracking-configuration '{
    "PredefinedMetricSpecification": {
      "PredefinedMetricType": "ASGAverageCPUUtilization"
    },
    "TargetValue": 50.0
  }'
```

You can also use a **custom CloudWatch metric** as the tracking target.

### Step Scaling — Details

Requires a CloudWatch alarm. You define "step adjustments" — different scaling amounts for different ranges of the metric.

Example:
- CPU 60-70%: add 1 instance
- CPU 70-80%: add 2 instances
- CPU > 80%: add 3 instances

**Key difference from Simple Scaling:** Step Scaling continues to evaluate alarms and adjust while scaling is in progress. Simple Scaling waits for the cooldown.

### Scheduled Scaling — Details

Set the desired, min, or max capacity to change at a specific date/time or on a recurring schedule (cron expression).

```bash
aws autoscaling put-scheduled-update-group-action \
  --auto-scaling-group-name my-asg \
  --scheduled-action-name scale-up-morning \
  --recurrence "0 9 * * MON-FRI" \
  --desired-capacity 10
```

### Predictive Scaling — Details

- Uses machine learning to analyze 14 days of historical data.
- Forecasts future demand and pre-provisions instances **before** the load arrives.
- Works well with cyclical patterns (daily, weekly).
- Can be used in **forecast-only** mode first to evaluate accuracy before enabling actual scaling.

---

## Cooldown Period

- A period after a scaling activity during which ASG **does not launch or terminate** additional instances.
- **Default cooldown:** 300 seconds (5 minutes).
- Purpose: let newly launched instances warm up and start handling traffic before ASG evaluates again.
- **Target Tracking and Step Scaling** have their own built-in "warm-up" concept (instance warm-up time) that is more flexible than the cooldown.

**Exam tip:** If instances are launching and terminating repeatedly ("thrashing"), increase the cooldown period or the instance warm-up time.

---

## Lifecycle Hooks

Allow you to **pause** an instance during launch or termination to perform custom actions.

```
Pending  --(launch hook)--> Pending:Wait --> Pending:Proceed --> InService
InService --> Terminating --(terminate hook)--> Terminating:Wait --> Terminating:Proceed --> Terminated
```

**Use cases:**
- **Launch hook**: Install software, pull configuration from S3, register with a configuration management tool, warm the cache.
- **Terminate hook**: Deregister from a service discovery system, drain connections, upload logs to S3.

**How to signal completion:**
1. Call `complete-lifecycle-action` API.
2. The hook times out after the `HeartbeatTimeout` (default 3600 seconds = 1 hour).

**Integration targets:** EventBridge, SNS, SQS.

---

## Warm Pools

A pool of **pre-initialized** EC2 instances that sit in a `Stopped` or `Running` state, ready to be placed into the ASG quickly.

**Without warm pool:** Launch -> boot OS -> run user data -> install app -> register with ELB = minutes.
**With warm pool (stopped):** Start pre-initialized instance -> register with ELB = seconds.

| Setting | Description |
|---|---|
| Pool state | `Stopped` (cheapest, no compute charge) or `Running` (fastest, but costs money) or `Hibernated` (preserves RAM state) |
| Min size | Minimum number of instances in the pool |
| Max prepared capacity | Maximum total instances (in-service + warm pool) |
| Reuse policy | Whether instances return to warm pool on scale-in instead of being terminated |

**Exam tip:** If a question says "reduce the time to scale out" or "pre-initialize instances" — warm pools.

---

## Instance Refresh

A way to **rolling-update** instances in an ASG when you update the launch template (e.g., new AMI).

- You specify a **minimum healthy percentage** (e.g., 90%) — ASG keeps at least this percentage running while replacing instances.
- Optionally set a **checkpoint** to pause at certain percentages for validation.
- Uses a similar approach to a rolling deployment.

```bash
aws autoscaling start-instance-refresh \
  --auto-scaling-group-name my-asg \
  --preferences '{
    "MinHealthyPercentage": 90,
    "InstanceWarmup": 300
  }'
```

**Exam tip:** If a question says "update all instances in an ASG to a new AMI with minimal downtime" — instance refresh.

---

## Key Takeaways for the Exam

1. **Launch Templates > Launch Configurations**: Always prefer Launch Templates. They support versioning, mixed instances, Spot/On-Demand combinations.
2. **Target Tracking is the default recommendation**: Simplest scaling policy, works like a thermostat.
3. **Step Scaling**: Use when you need different scaling amounts at different thresholds. Does not wait for cooldown.
4. **Scheduled Scaling**: For predictable patterns (business hours, weekends).
5. **Predictive Scaling**: ML-based, requires 14 days of history, pre-provisions before demand.
6. **Cooldown**: Prevents thrashing. Default 300 seconds.
7. **Lifecycle Hooks**: Custom actions on launch/terminate (install software, drain connections).
8. **Warm Pools**: Pre-initialized instances for faster scale-out.
9. **Instance Refresh**: Rolling update of all instances in an ASG to a new launch template version.
10. **ELB Health Checks**: Must be explicitly enabled on the ASG — not automatic.
11. **AZ Rebalancing**: ASG launches first, then terminates, so it can temporarily exceed max capacity.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Launch Templates vs Launch Configurations
- Auto Scaling Group (ASG) Basics
- Scaling Policies
- Cooldown Period

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
