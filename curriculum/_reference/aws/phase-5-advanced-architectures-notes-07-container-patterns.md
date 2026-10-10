# Container Architecture Patterns

## Why This Matters for the Exam

The SAA-C03 tests your ability to choose between ECS and EKS, Fargate and EC2 launch types, and when containers are the right choice versus serverless or EC2. Expect 2-4 questions on container architectures, often framed as "which compute option best fits this scenario."

---

## Container Fundamentals (Quick Review)

A **container** packages application code, runtime, libraries, and dependencies into a single portable unit. Containers are:
- **Lightweight:** Share the host OS kernel (unlike VMs which have their own OS).
- **Portable:** Run the same way on a laptop, on-premises, or in the cloud.
- **Fast to start:** Seconds, compared to minutes for EC2 instances.

**Docker** is the most common container runtime. A **Docker image** is a template; a **container** is a running instance of an image.

---

## Amazon Elastic Container Registry (ECR)

ECR is a fully managed Docker container registry (like Docker Hub, but private and integrated with AWS).

| Feature | Detail |
|---|---|
| **What it stores** | Docker images and OCI images |
| **Public/Private** | Both (ECR Public Gallery or private repositories) |
| **Encryption** | Images encrypted at rest with KMS |
| **Scanning** | Vulnerability scanning (basic or enhanced via Inspector) |
| **Lifecycle policies** | Automatically clean up old images |
| **Cross-region replication** | Replicate images to other regions |
| **Integration** | Native integration with ECS, EKS, and Lambda (container images) |

**Exam tip:** ECR is the default answer when questions ask "where to store container images in AWS." It integrates seamlessly with ECS and EKS.

---

## Amazon ECS (Elastic Container Service)

ECS is AWS's proprietary container orchestration service. It manages the lifecycle of containers: scheduling, scaling, load balancing, and health monitoring.

### Key ECS Concepts

| Concept | Description |
|---|---|
| **Cluster** | Logical grouping of tasks or services (the "environment") |
| **Task Definition** | Blueprint for your container (image, CPU, memory, ports, environment variables, IAM role) |
| **Task** | A running instance of a task definition (one or more containers) |
| **Service** | Manages desired count of tasks, integrates with ELB, handles rolling updates |
| **Container Instance** | EC2 instance registered to an ECS cluster (only for EC2 launch type) |

### ECS Launch Types: Fargate vs EC2

| Feature | Fargate | EC2 Launch Type |
|---|---|---|
| **Infrastructure** | AWS manages all infrastructure | You manage EC2 instances |
| **Scaling** | Task-level (no instance management) | Must scale EC2 instances + tasks |
| **Pricing** | Per vCPU + memory per second | EC2 instance pricing (can use Reserved/Spot) |
| **Cost at scale** | More expensive per unit | Cheaper at sustained high scale (Reserved Instances) |
| **Startup time** | Slightly slower (provision compute) | Faster (if instance capacity exists) |
| **GPU support** | No | Yes (GPU instances) |
| **EBS volumes** | Ephemeral storage (20 GB default, up to 200 GB) | Full EBS support |
| **EFS support** | Yes | Yes |
| **Networking** | Each task gets its own ENI (awsvpc mode required) | Flexible (host, bridge, awsvpc) |
| **Security** | Stronger isolation (no shared host) | Shared host kernel (less isolated) |
| **Operational overhead** | Low (no patching, no instance management) | High (patch OS, manage capacity) |
| **Spot support** | Fargate Spot (up to 70% discount) | EC2 Spot Instances |

### When to Use Each

| Scenario | Launch Type | Why |
|---|---|---|
| "Minimize operational overhead" | Fargate | No instance management |
| "Run GPU-based ML inference containers" | EC2 | Fargate does not support GPU |
| "Predictable, high-scale workload 24/7" | EC2 (with Reserved Instances) | Cheaper at sustained scale |
| "Variable workload, sometimes zero" | Fargate | Pay-per-task, scales to zero |
| "Need to access host OS or Docker daemon" | EC2 | Full OS access |
| "Compliance requires dedicated hardware" | EC2 (Dedicated Instances/Hosts) | Hardware isolation |

---

## Amazon EKS (Elastic Kubernetes Service)

EKS is a managed Kubernetes service. It runs the Kubernetes control plane across multiple AZs, handles upgrades, and integrates with AWS services.

### ECS vs EKS

| Feature | ECS | EKS |
|---|---|---|
| **Orchestration** | AWS proprietary | Kubernetes (open-source standard) |
| **Learning curve** | Lower (AWS-native concepts) | Higher (Kubernetes ecosystem) |
| **Portability** | AWS-only | Multi-cloud, on-premises (K8s is universal) |
| **Ecosystem** | AWS tools | Massive Kubernetes ecosystem (Helm, Istio, etc.) |
| **Control plane cost** | Free (included) | $0.10/hour (~$73/month) per cluster |
| **Launch types** | Fargate or EC2 | Fargate or EC2 (managed node groups or self-managed) |
| **Best for** | Teams invested in AWS, simpler container needs | Teams with Kubernetes expertise, multi-cloud strategy |

### When to Use EKS Over ECS

| Scenario | Answer |
|---|---|
| "Team already uses Kubernetes on-premises" | EKS (leverage existing K8s knowledge) |
| "Need to run same workloads across AWS and on-premises" | EKS (K8s is portable) |
| "Need service mesh (Istio, Linkerd)" | EKS (Kubernetes ecosystem) |
| "Simple container deployment, team is AWS-native" | ECS (simpler, no K8s overhead) |
| "Multi-cloud strategy" | EKS (Kubernetes runs everywhere) |

**Exam tip:** If the question mentions "Kubernetes" or "K8s" or "multi-cloud," the answer is EKS. If the question says "simplest container solution" or does not mention Kubernetes, ECS is usually the answer.

---

## ECS/EKS Networking

### ECS Network Modes

| Mode | Description | Use Case |
|---|---|---|
| **awsvpc** | Each task gets its own ENI with private IP | Default for Fargate; recommended for EC2 |
| **bridge** | Docker bridge network on the host | Legacy, multiple containers share host ports |
| **host** | Container uses the host's network directly | Maximum performance, port conflicts possible |
| **none** | No external networking | Isolated batch processing |

**Fargate only supports awsvpc mode.** In awsvpc mode, each task has its own security group.

### Load Balancing with Containers

| Load Balancer | Use Case |
|---|---|
| **ALB** | HTTP/HTTPS traffic, path-based routing to different container services |
| **NLB** | TCP/UDP traffic, ultra-low latency, static IP |
| **ALB with dynamic port mapping** | Multiple tasks on same EC2 instance (EC2 launch type) |

**Dynamic port mapping:** When using the EC2 launch type with bridge networking, multiple tasks on the same instance need different host ports. ALB automatically discovers the dynamically assigned port for each task.

---

## Service Discovery

Service discovery allows containers to find and communicate with each other without hardcoded endpoints.

### AWS Cloud Map

- Managed service discovery for ECS and EKS.
- Registers container instances with DNS names (e.g., `orders.myapp.local`).
- Health checks automatically deregister unhealthy instances.
- Integrates with Route 53 for DNS-based discovery.

### ECS Service Connect

- Built-in service mesh for ECS.
- Automatic service-to-service communication without manual configuration.
- Uses envoy proxy sidecars.
- Traffic management, observability, and retry logic.

---

## Service Mesh

A service mesh handles service-to-service communication in a microservices architecture: load balancing, retries, circuit breaking, mutual TLS, and observability.

### AWS App Mesh

| Feature | Detail |
|---|---|
| **What it does** | Manages service-to-service communication for ECS, EKS, and EC2 |
| **Proxy** | Uses Envoy sidecar proxy (injected into each container/task) |
| **Features** | Traffic routing, retries, circuit breaking, mutual TLS, observability |
| **Integration** | CloudWatch, X-Ray, third-party monitoring |

### When to Use a Service Mesh

- 10+ microservices communicating with each other.
- Need advanced traffic management (canary deployments, A/B testing between service versions).
- Need mutual TLS between all services.
- Need centralized observability of inter-service traffic.

**Exam tip:** If the question mentions "canary deployment between microservice versions" or "mutual TLS between containers," think App Mesh or ECS Service Connect.

---

## Container Architecture Patterns

### Pattern 1: Microservices on ECS

```
+-------------------+
| ALB               |
| /api/orders/*     |--> ECS Service: Orders (Fargate, 3 tasks)
| /api/users/*      |--> ECS Service: Users (Fargate, 2 tasks)
| /api/catalog/*    |--> ECS Service: Catalog (Fargate, 2 tasks)
+-------------------+
         |
    Each service has:
    - Its own Task Definition
    - Its own ECR image
    - Its own DynamoDB table or RDS connection
    - Its own IAM Task Role
    - Independent scaling
```

### Pattern 2: Sidecar Pattern

```
+--------------------------------------+
| ECS Task                             |
| +------------------+ +-------------+ |
| | Main Container   | | Sidecar     | |
| | (application)    | | (logging/   | |
| |                  | |  monitoring)| |
| |  App logic       | |  Fluent Bit | |
| |  Port: 8080      | |  -> CW Logs | |
| +------------------+ +-------------+ |
+--------------------------------------+
```

Sidecar containers run alongside the main application container in the same task. Common sidecars:
- **Logging:** Fluent Bit forwarding logs to CloudWatch.
- **Monitoring:** Prometheus exporter, X-Ray daemon.
- **Proxy:** Envoy proxy for service mesh.

### Pattern 3: Batch Processing with ECS

```
EventBridge (scheduled rule: every hour)
    |
    v
Lambda (trigger) --> ECS RunTask (Fargate)
                         |
                         v
                    +------------------+
                    | Container        |
                    | - Pull data from |
                    |   S3/RDS         |
                    | - Process        |
                    | - Write results  |
                    |   to S3/DynamoDB |
                    | - Exit (task     |
                    |   terminates)    |
                    +------------------+
```

**Why ECS over Lambda for batch:**
- Processing exceeds Lambda's 15-minute limit.
- Needs more than 10 GB of memory.
- Needs more than 10 GB of temporary storage.
- Needs specific tools/libraries not easily packaged in Lambda.

---

## When to Choose Containers

### Containers Are the Right Choice When

| Situation | Why Containers |
|---|---|
| Application is already Dockerized | Natural fit, no rewriting |
| Need specific runtime/language/library versions | Full control over environment |
| Task duration > 15 minutes | Lambda limit |
| Need > 10 GB memory or storage | Lambda limits |
| Microservices architecture with 5+ services | Container orchestration shines |
| Team has Docker/Kubernetes expertise | Leverage existing skills |
| Multi-cloud portability needed | Containers are cloud-agnostic |
| Need to run third-party software in containers | COTS software with Docker images |

### Containers vs Lambda vs EC2 Quick Reference

| Question | Lambda | Containers (Fargate) | EC2 |
|---|---|---|---|
| "Minimize ops overhead for short tasks" | Best | Good | Overkill |
| "Docker-based microservices" | Possible | **Best** | Possible |
| "Need GPU compute" | No | No (Fargate) | **Best** |
| "Long-running process (hours)" | No (15 min limit) | **Best** | Good |
| "Process 1 million events/day, each < 1 sec" | **Best** | Overkill | Overkill |
| "Run Kubernetes" | No | EKS Fargate | EKS on EC2 |
| "Cheapest at sustained high scale" | Expensive | Medium | **Best** (Reserved) |
| "Need to scale to zero" | **Best** | Good | No |

---

## ECS Task IAM Roles

Two types of IAM roles in ECS:

| Role | Purpose | Example |
|---|---|---|
| **Task Execution Role** | Allows ECS agent to pull images from ECR, send logs to CloudWatch | `ecr:GetAuthorizationToken`, `logs:CreateLogStream` |
| **Task Role** | Allows the container application to call AWS services | `dynamodb:PutItem`, `s3:GetObject` |

**Exam tip:** If the question asks "how does the application in the container access DynamoDB," the answer is the Task Role (not the execution role). The execution role is for the ECS infrastructure itself.

---

## Key Takeaways

1. **ECS for AWS-native teams; EKS for Kubernetes teams or multi-cloud requirements.**
2. **Fargate for minimal ops; EC2 launch type for GPU, sustained high scale, or full OS control.**
3. **awsvpc networking** gives each task its own ENI and security group -- this is the default for Fargate and the recommended mode.
4. **ECR is the container image registry.** Use lifecycle policies to clean up old images.
5. **Service discovery (Cloud Map) lets containers find each other** without hardcoded addresses.
6. **Task Role vs Execution Role:** Task Role is for the application; Execution Role is for the ECS agent.
7. **Containers are the middle ground** between Lambda (minimal ops, limited runtime) and EC2 (full control, most ops).

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Container Fundamentals (Quick Review)
- Amazon Elastic Container Registry (ECR)
- Amazon ECS (Elastic Container Service)
- Amazon EKS (Elastic Kubernetes Service)

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
