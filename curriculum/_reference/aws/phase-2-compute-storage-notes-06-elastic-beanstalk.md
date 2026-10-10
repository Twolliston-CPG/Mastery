# 06 — Elastic Beanstalk

## Table of Contents
1. [What is Elastic Beanstalk](#what-is-elastic-beanstalk)
2. [Deployment Policies](#deployment-policies)
3. [Deployment Policies Comparison Table](#deployment-policies-comparison-table)
4. [.ebextensions](#ebextensions)
5. [Platform Hooks](#platform-hooks)
6. [Environment Types](#environment-types)
7. [Blue/Green Deployment with Beanstalk](#bluegreen-deployment-with-beanstalk)
8. [Key Takeaways for the Exam](#key-takeaways-for-the-exam)

---

## What is Elastic Beanstalk

AWS Elastic Beanstalk is a Platform-as-a-Service (PaaS) that simplifies deploying and managing applications. You upload your code, and Beanstalk handles capacity provisioning, load balancing, auto-scaling, and health monitoring.

**Key facts:**
- No additional charge for Beanstalk itself — you only pay for the underlying resources (EC2, ELB, RDS, etc.).
- Supports many platforms: Python, Node.js, Java, .NET, PHP, Ruby, Go, Docker.
- Under the hood, Beanstalk creates CloudFormation stacks to manage resources.
- You retain full control over the underlying resources.

**Components:**
- **Application**: A logical collection of environments, versions, and configurations.
- **Application Version**: A specific labeled iteration of deployable code (stored in S3).
- **Environment**: A running instance of an application version. Has its own URL.
- **Environment Tier**: Web Server (HTTP requests via ELB) or Worker (processes messages from SQS).

---

## Deployment Policies

### All-at-Once

Deploy the new version to **all instances simultaneously**.

- **Downtime**: Yes — all instances are briefly unavailable during the update.
- **Speed**: Fastest deployment.
- **Rollback**: Requires a manual re-deploy of the previous version.
- **Use case**: Development environments where downtime is acceptable.

### Rolling

Deploy in **batches**. One batch is taken out of service, updated, then put back.

- **Downtime**: No full downtime, but capacity is reduced during deployment.
- **Speed**: Slower than All-at-Once (depends on batch size).
- **Rollback**: Manual re-deploy. Some instances may run old version, some new.
- **Configuration**: Set the batch size (number or percentage of instances).

### Rolling with Additional Batch

Same as Rolling, but Beanstalk **launches a new batch of instances first** so capacity is never reduced.

- **Downtime**: None. Full capacity maintained throughout.
- **Speed**: Slower (need to launch new instances).
- **Cost**: Slightly higher — temporarily have extra instances.
- **Rollback**: Manual re-deploy.

### Immutable

Launch a **completely new set of instances** in a new temporary ASG. If healthy, swap them into the original ASG and terminate old instances.

- **Downtime**: None. Full capacity maintained.
- **Speed**: Slowest.
- **Rollback**: Very fast — just terminate the new instances.
- **Cost**: Double capacity during deployment.
- **Use case**: Production environments where quick rollback is critical.

### Traffic Splitting (Canary)

Deploy to a new set of instances and **split a percentage of traffic** to them. If healthy, shift all traffic.

- **Downtime**: None.
- **Speed**: Slow (includes a monitoring/evaluation period).
- **Rollback**: Automatic if health checks fail.
- **Use case**: Test new versions with real production traffic before full rollout.

---

## Deployment Policies Comparison Table

| Policy | Downtime | Deploy Speed | Capacity During Deploy | Rollback Speed | Cost Impact | DNS Change |
|---|---|---|---|---|---|---|
| **All-at-Once** | Yes | Fastest | Reduced to 0 | Slow (re-deploy) | None | No |
| **Rolling** | No | Medium | Reduced by 1 batch | Slow (re-deploy) | None | No |
| **Rolling + Additional Batch** | No | Medium-Slow | Full + extra batch | Slow (re-deploy) | Small increase | No |
| **Immutable** | No | Slow | Full + full new set | Fast (terminate new) | Double during deploy | No |
| **Traffic Splitting** | No | Slowest | Full + full new set | Fast (terminate new + auto) | Double during deploy | No |
| **Blue/Green** (manual) | No | Medium | Two full environments | Fast (swap URLs) | Double until swap | Yes (URL swap) |

**Exam tips:**
- "Fastest deployment" = All-at-Once.
- "No downtime, no reduced capacity" = Rolling with Additional Batch, Immutable, or Traffic Splitting.
- "Fastest rollback" = Immutable (just terminate new instances) or Blue/Green (swap URLs back).
- "Test with a small percentage of traffic first" = Traffic Splitting.
- "Zero downtime and immediate rollback" = Immutable.

---

## .ebextensions

A folder named `.ebextensions/` in the root of your source bundle containing `.config` files (YAML or JSON) that customize your Beanstalk environment.

**`my-app/`**

- `application.py`
- `requirements.txt`
- `.ebextensions/`
  - `01-packages.config`
  - `02-custom-settings.config`
  - `03-environment.config`


### Example: Install Packages

```yaml
# .ebextensions/01-packages.config
packages:
  yum:
    git: []
    jq: []
```

### Example: Custom Environment Option Settings

```yaml
# .ebextensions/02-custom-settings.config
option_settings:
  aws:elasticbeanstalk:application:environment:
    APP_ENV: production
    DB_HOST: mydb.cluster-abc123.us-east-1.rds.amazonaws.com
  aws:autoscaling:asg:
    MinSize: 2
    MaxSize: 10
  aws:elasticbeanstalk:environment:
    LoadBalancerType: application
```

### Example: Create Files and Run Commands

```yaml
# .ebextensions/03-environment.config
files:
  "/etc/my-app/config.json":
    mode: "000644"
    owner: root
    group: root
    content: |
      {
        "log_level": "info",
        "feature_flag": true
      }

container_commands:
  01_migrate_db:
    command: "python manage.py migrate"
    leader_only: true
  02_collect_static:
    command: "python manage.py collectstatic --noinput"
```

**Key sections in .config files:**
- `packages`: Install OS packages.
- `sources`: Download and extract archives.
- `files`: Create files on the instance.
- `commands`: Run commands before the application is deployed.
- `container_commands`: Run commands after the application is deployed but before it starts. Supports `leader_only` (run on only one instance).
- `option_settings`: Configure Beanstalk environment options.
- `Resources`: Define additional AWS resources via CloudFormation.

**Exam tip:** `leader_only: true` in `container_commands` ensures a command (like a DB migration) runs on only one instance.

---

## Platform Hooks

Scripts placed in specific directories on the instance that run at different stages of the deployment lifecycle.

**`.platform/`**

- `hooks/`
  - `prebuild/` — Run before the build step
  - `predeploy/` — Run after the build but before the deploy
  - `postdeploy/` — Run after the deploy completes
- `confighooks/`
  - `prebuild/`
  - `predeploy/`
  - `postdeploy/`


**Differences from .ebextensions:**
- Platform hooks are simpler — just shell scripts.
- They run at well-defined lifecycle stages.
- `.ebextensions` offer more configuration options (option_settings, Resources, files, etc.).
- **Both can be used together.**

---

## Environment Types

### Web Server Environment

- Receives HTTP/HTTPS traffic via an Elastic Load Balancer.
- Runs your web application (Flask, Django, Express, Spring, etc.).
- Auto Scaling Group manages EC2 instances.
- Optional RDS instance.

### Worker Environment

- Processes background tasks from an SQS queue.
- Beanstalk creates and manages the SQS queue.
- A daemon on each instance polls the queue and sends messages to your application via HTTP POST to `http://localhost/`.
- Use for long-running tasks, email sending, data processing.
- Can be paired with a Web Server environment: web app sends messages to SQS, worker processes them.

**Exam tip:** "Decouple web application from background processing" = Web Server environment + Worker environment + SQS.

---

## Blue/Green Deployment with Beanstalk

Beanstalk does not natively support blue/green as a deployment policy. Instead, you do it manually:

1. Create a new environment (Green) with the new version.
2. Test the Green environment independently.
3. Use **Swap Environment URLs** to swap the CNAME of Blue and Green.
4. Traffic immediately flows to the Green environment.
5. Keep the Blue environment as a rollback option.
6. Terminate Blue when confident.

**Limitation:** DNS propagation may cause some users to hit the old environment temporarily.

---

## Key Takeaways for the Exam

1. **Beanstalk is free** — you only pay for underlying resources.
2. **Deployment policies**: Know the tradeoffs (speed, downtime, rollback, cost) from the comparison table.
3. **Immutable**: Safest deployment with fastest rollback. Creates new instances in a temporary ASG.
4. **Traffic Splitting**: Canary deployment. Sends a percentage of traffic to the new version.
5. **.ebextensions**: YAML/JSON config files in `.ebextensions/` folder. Use for packages, files, commands, option settings, and CloudFormation resources.
6. **leader_only**: Run a command on just one instance (e.g., DB migration).
7. **Platform hooks**: Shell scripts in `.platform/hooks/` for prebuild, predeploy, postdeploy.
8. **Web Server vs Worker**: Web handles HTTP, Worker processes SQS messages.
9. **Blue/Green**: Manual URL swap between two environments.
10. **Under the hood**: Beanstalk uses CloudFormation, EC2, ASG, ELB, and optionally RDS.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- What is Elastic Beanstalk
- Deployment Policies
- Deployment Policies Comparison Table
- .ebextensions

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
