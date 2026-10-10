# 04 — Containers: ECS, EKS, and ECR

## Table of Contents
1. [Containers on AWS — Overview](#containers-on-aws--overview)
2. [Amazon ECS — Elastic Container Service](#amazon-ecs--elastic-container-service)
3. [ECS Launch Types: EC2 vs Fargate](#ecs-launch-types-ec2-vs-fargate)
4. [Task Definitions](#task-definitions)
5. [ECS Services](#ecs-services)
6. [IAM Roles for ECS](#iam-roles-for-ecs)
7. [Amazon EKS — Elastic Kubernetes Service](#amazon-eks--elastic-kubernetes-service)
8. [Amazon ECR — Elastic Container Registry](#amazon-ecr--elastic-container-registry)
9. [Key Takeaways for the Exam](#key-takeaways-for-the-exam)

---

## Containers on AWS — Overview

Containers package an application and its dependencies into a single unit that runs consistently across environments. AWS offers multiple services to run containers:

| Service | Description | When to Use |
|---|---|---|
| **ECS** | AWS-native container orchestration | Default choice for containers on AWS |
| **EKS** | Managed Kubernetes | When you need Kubernetes compatibility or are migrating from on-prem K8s |
| **Fargate** | Serverless compute engine for containers | When you do not want to manage the underlying EC2 instances |
| **ECR** | Container image registry | Store, manage, and deploy Docker images |
| **App Runner** | Fully managed container service | Simple web apps/APIs with minimal configuration |

---

## Amazon ECS — Elastic Container Service

ECS is AWS's proprietary container orchestration platform. It manages the lifecycle of containers (starting, stopping, scaling) across a cluster of compute resources.

**Core concepts:**
- **Cluster**: A logical grouping of tasks or services. Can be EC2-based or Fargate-based.
- **Task Definition**: A blueprint that describes one or more containers (image, CPU, memory, ports, environment variables, volumes).
- **Task**: A running instance of a task definition. One task can run one or more containers.
- **Service**: Maintains a desired count of tasks, integrates with load balancers, handles rolling deployments.

---

## ECS Launch Types: EC2 vs Fargate

| Feature | EC2 Launch Type | Fargate Launch Type |
|---|---|---|
| **Infrastructure** | You manage EC2 instances (provision, patch, scale) | AWS manages compute — fully serverless |
| **Pricing** | Pay for EC2 instances (even if underutilized) | Pay per task (vCPU + memory per second) |
| **Control** | Full control over instance type, OS, networking | Limited control — AWS abstracts the infrastructure |
| **Scaling** | Must scale the EC2 instances AND the ECS tasks | Only scale the tasks; Fargate handles compute |
| **GPU Support** | Yes | Limited (GPU not supported on Fargate at exam time) |
| **Placement strategies** | Yes (spread, binpack, random) | No — AWS handles placement |
| **Persistent storage** | EBS volumes on EC2 hosts, EFS | EFS only (no EBS) |
| **Cost optimization** | Spot Instances, Reserved Instances | Fargate Spot |
| **Use case** | Large-scale, cost-optimized with Spot, GPU workloads | Small teams, variable workloads, prefer simplicity |

**Exam tip:**
- "No infrastructure management" or "serverless containers" = **Fargate**.
- "Need to use Spot or Reserved Instances for containers" = **EC2 launch type** (or Fargate Spot).
- "Need GPU for container workload" = **EC2 launch type**.

### ECS with EC2 — Placement Strategies

| Strategy | Description |
|---|---|
| **binpack** | Place tasks on instances with the least available CPU/memory (minimize instance count, reduce cost) |
| **spread** | Place tasks across instances, AZs, or hosts (maximize availability) |
| **random** | Place tasks randomly |

You can combine strategies (e.g., spread across AZs, then binpack within each AZ).

---

## Task Definitions

A JSON document that describes the containers in a task.

```json
{
  "family": "web-app",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "executionRoleArn": "arn:aws:iam::123456789012:role/ecsTaskExecutionRole",
  "taskRoleArn": "arn:aws:iam::123456789012:role/ecsTaskRole",
  "containerDefinitions": [
    {
      "name": "web",
      "image": "123456789012.dkr.ecr.us-east-1.amazonaws.com/my-app:latest",
      "portMappings": [
        {
          "containerPort": 80,
          "protocol": "tcp"
        }
      ],
      "essential": true,
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/web-app",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "web"
        }
      },
      "environment": [
        { "name": "APP_ENV", "value": "production" }
      ]
    }
  ]
}
```

**Key fields:**
- `family`: Name of the task definition (like a "name" for the group of revisions).
- `networkMode`: `awsvpc` (recommended for Fargate and most EC2 — each task gets its own ENI), `bridge`, `host`, `none`.
- `cpu` and `memory`: Required for Fargate; at the task level.
- `executionRoleArn`: IAM role for the ECS agent (pull images, push logs).
- `taskRoleArn`: IAM role for the containers to call AWS APIs.
- `containerDefinitions`: Array of container specs (image, port mappings, environment variables, log config).
- `essential`: If true, the task stops when this container stops.

### Data Volumes

- **Bind mounts**: Share data between containers in the same task.
- **EFS volumes**: Persist data across tasks and task restarts. Works with both EC2 and Fargate.
- **EBS volumes** (EC2 launch type only): Attach host EC2 EBS volumes.

---

## ECS Services

A service ensures that a specified number of task instances are running at all times.

**Key features:**
- **Desired count**: Service maintains N running tasks. If a task fails, it launches a replacement.
- **Load balancer integration**: Distribute traffic across tasks using ALB (recommended) or NLB.
- **Rolling deployments**: Update tasks to a new task definition version with configurable min/max healthy percentages.
- **Service Auto Scaling**: Scale tasks based on CloudWatch metrics (CPU, memory, ALB request count).
  - **Target Tracking**: Maintain average CPU at 70%.
  - **Step Scaling**: Add tasks when thresholds are breached.
  - **Scheduled Scaling**: Scale at specific times.

### ECS Service with ALB

When using `awsvpc` network mode, each task gets its own private IP. The ALB routes traffic to these IPs using **dynamic port mapping** (or a fixed port per task).

**Exam tip:** For ECS + ALB, use `awsvpc` network mode. For Fargate, `awsvpc` is the **only** option.

---

## IAM Roles for ECS

There are **two distinct IAM roles** to understand:

| Role | Purpose | Who Uses It |
|---|---|---|
| **ECS Task Execution Role** | Allows the ECS agent to pull container images from ECR and send logs to CloudWatch | The ECS agent / Fargate agent |
| **ECS Task Role** | Allows the containers in the task to call AWS APIs (e.g., read from S3, write to DynamoDB) | Your application code inside the container |

**Exam tip:** If a container needs to access S3 or DynamoDB, you assign permissions via the **Task Role** (not the Execution Role, and not instance role).

### EC2 Instance Role (EC2 Launch Type Only)

- The EC2 instances in the cluster also need an **EC2 Instance Role** that allows the ECS agent to communicate with the ECS service, pull images, and push logs.
- This is separate from the Task Role.

---

## Amazon EKS — Elastic Kubernetes Service

EKS is a managed Kubernetes service. AWS manages the **control plane** (API server, etcd); you manage (or use Fargate for) the **worker nodes**.

### EKS vs ECS

| Feature | ECS | EKS |
|---|---|---|
| Orchestration | AWS proprietary | Open-source Kubernetes |
| Learning curve | Lower (AWS-native) | Higher (Kubernetes ecosystem) |
| Portability | AWS only | Multi-cloud, on-prem (via EKS Anywhere) |
| Ecosystem | AWS integrations | Huge Kubernetes ecosystem (Helm, Istio, etc.) |
| Cost | No control plane charge | $0.10/hour for control plane ($73/month) |
| Worker nodes | EC2 or Fargate | EC2, Fargate, or Managed Node Groups |

### EKS Node Types

| Type | Description |
|---|---|
| **Managed Node Groups** | AWS manages the EC2 instances (auto-creates ASG, handles updates) |
| **Self-Managed Nodes** | You manage EC2 instances and join them to the cluster |
| **Fargate** | Serverless — no nodes to manage (pay per pod) |

**Exam tip:** "Migrate on-premises Kubernetes to AWS" = EKS. "Run containers with minimal AWS lock-in" = EKS. "Simplest container solution on AWS" = ECS with Fargate.

---

## Amazon ECR — Elastic Container Registry

A fully managed Docker container registry to store, manage, and deploy container images.

**Key features:**
- **Private repositories**: Secured by IAM.
- **Public repositories**: ECR Public Gallery (public.ecr.aws).
- **Image scanning**: Automatic vulnerability scanning on push.
- **Image lifecycle policies**: Automatically clean up old or untagged images.
- **Cross-region and cross-account replication**.
- **Immutable image tags**: Prevent overwriting images.
- Supports **OCI** images and Helm charts.

### ECR Authentication

```bash
# Authenticate Docker to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  123456789012.dkr.ecr.us-east-1.amazonaws.com

# Push an image
docker tag my-app:latest 123456789012.dkr.ecr.us-east-1.amazonaws.com/my-app:latest
docker push 123456789012.dkr.ecr.us-east-1.amazonaws.com/my-app:latest
```

---

## Key Takeaways for the Exam

1. **ECS vs EKS**: ECS is simpler and AWS-native. EKS is for Kubernetes workloads, multi-cloud, or migration from on-prem K8s.
2. **EC2 vs Fargate**: Fargate = serverless, no infrastructure management. EC2 = more control, Spot/RI pricing, GPU.
3. **Task Definition**: Blueprint for containers. Defines image, CPU, memory, ports, IAM roles, volumes.
4. **Task Role vs Execution Role**: Task Role = for your app to call AWS APIs. Execution Role = for ECS agent to pull images/push logs.
5. **awsvpc network mode**: Each task gets its own ENI and private IP. Required for Fargate, recommended for EC2.
6. **ECS Service**: Maintains desired count of running tasks, integrates with ALB, supports auto scaling.
7. **Placement strategies**: binpack (minimize cost), spread (maximize availability), random.
8. **ECR**: Store Docker images. IAM-secured. Supports scanning, lifecycle policies, replication.
9. **EFS with ECS**: The only shared storage option for Fargate tasks. EBS works only with EC2 launch type.
10. **EKS costs $0.10/hour** for the control plane alone, plus the worker node costs.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Containers on AWS — Overview
- Amazon ECS — Elastic Container Service
- ECS Launch Types: EC2 vs Fargate
- Task Definitions

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
