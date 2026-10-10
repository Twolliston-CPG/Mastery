# 01 -- Cloud Fundamentals

## Table of Contents
1. [AWS Global Infrastructure](#aws-global-infrastructure)
2. [AWS Well-Architected Framework](#aws-well-architected-framework)
3. [Shared Responsibility Model](#shared-responsibility-model)
4. [Key Takeaways for the SAA-C03 Exam](#key-takeaways-for-the-saa-c03-exam)

---

## AWS Global Infrastructure

### Regions

A **Region** is a geographic area that contains multiple isolated data center clusters. Each Region is completely independent and isolated from other Regions, which provides fault isolation and data residency.

**How to choose a Region:**

| Factor | Question to Ask |
|---|---|
| Compliance / Data Residency | Does local law require data to stay in a specific country? |
| Latency | Where are your end users? Pick the Region closest to them. |
| Service Availability | Is the service you need available in that Region? Not all services launch everywhere simultaneously. |
| Pricing | Prices differ across Regions. US-East-1 (N. Virginia) is often cheapest. |

**Current scale (exam does not require exact numbers but awareness helps):**
- 30+ Regions globally
- Each Region has a minimum of 3 Availability Zones (with rare exceptions for older Regions)

[TODO: Add a diagram or ASCII art showing a world map with major Regions marked]

### Availability Zones (AZs)

An **Availability Zone** is one or more discrete data centers within a Region, each with redundant power, networking, and connectivity. AZs within a Region are connected by high-bandwidth, low-latency networking.

Key facts:
- AZs are physically separated -- different buildings, different flood plains, different power grids.
- AZ names (e.g., `us-east-1a`) are **mapped differently per account** to distribute load. Your `us-east-1a` might be a different physical data center than another account's `us-east-1a`. Use **AZ IDs** (e.g., `use1-az1`) for consistent cross-account references.
- Designing for **multi-AZ** is a core principle for high availability on the SAA exam.

[TODO: Expand on how multi-AZ deployments work for RDS, EC2 Auto Scaling, and ELB -- these will be covered in later phases but plant the seed here]

### Edge Locations and Regional Edge Caches

**Edge Locations** are endpoints for AWS services that cache content closer to end users. They are used primarily by:

- **Amazon CloudFront** (CDN) -- caches static and dynamic content at edge locations.
- **AWS Global Accelerator** -- routes traffic through the AWS global network to the optimal endpoint.
- **Amazon Route 53** -- answers DNS queries from the nearest edge location.
- **AWS WAF** -- can be deployed at edge locations through CloudFront.

**Regional Edge Caches** sit between CloudFront edge locations and your origin (e.g., an S3 bucket or ALB). They have a larger cache than edge locations and retain content longer. You do not configure these directly; CloudFront manages them automatically.

There are 400+ edge locations and 10+ Regional Edge Caches worldwide.

[TODO: Add a simple flow diagram: User -> Edge Location -> Regional Edge Cache -> Origin]

### Local Zones, Wavelength Zones, and Outposts

These are less heavily tested on the SAA-C03 but you should know what they are:

| Component | What It Is | Use Case |
|---|---|---|
| **Local Zones** | Extensions of a Region placed closer to population centers | Single-digit millisecond latency for video rendering, real-time gaming |
| **Wavelength Zones** | AWS infrastructure embedded in 5G provider data centers | Ultra-low latency for mobile edge computing |
| **AWS Outposts** | AWS-managed racks installed in your own data center | Hybrid workloads that must run on-premises for latency or data residency |

[TODO: Add 1-2 exam-style scenarios for each to solidify understanding]

---

## AWS Well-Architected Framework

The Well-Architected Framework provides a consistent approach for evaluating architectures against best practices. It has **six pillars**. On the SAA-C03 exam, you will be asked to identify which pillar a given design decision supports, and you will need to make architectural choices that align with these pillars.

### Pillar 1: Operational Excellence

**Focus:** Running and monitoring systems to deliver business value and continually improving processes and procedures.

**Key Design Principles:**
- Perform operations as code (Infrastructure as Code -- IaC)
- Make frequent, small, reversible changes
- Refine operations procedures frequently
- Anticipate failure (run game days, chaos engineering)
- Learn from all operational events and failures

**Key AWS Services:**
- AWS CloudFormation / Terraform (IaC)
- AWS Config (track configuration changes)
- Amazon CloudWatch (monitoring and alarms)
- AWS Systems Manager (operational management)
- AWS X-Ray (tracing and debugging)

**Exam tip:** If a question asks about automating deployments, reducing manual effort, or improving operational procedures, think Operational Excellence.

[TODO: Add 2-3 real-world scenarios showing operational excellence in action]

### Pillar 2: Security

**Focus:** Protecting information, systems, and assets while delivering business value through risk assessments and mitigation strategies.

**Key Design Principles:**
- Implement a strong identity foundation (least privilege)
- Enable traceability (log everything)
- Apply security at all layers (edge, VPC, subnet, instance, OS, application)
- Automate security best practices
- Protect data in transit and at rest
- Keep people away from data (reduce direct access)
- Prepare for security events (incident response runbooks)

**Key AWS Services:**
- IAM (identity and access management)
- AWS KMS (encryption key management)
- AWS CloudTrail (API call logging)
- Amazon GuardDuty (threat detection)
- AWS Security Hub (centralized security view)
- VPC Security Groups and NACLs

**Exam tip:** If a question mentions encryption, least privilege, logging, or compliance, think Security pillar.

[TODO: Deep-dive into defense-in-depth layering with concrete examples]

### Pillar 3: Reliability

**Focus:** The ability of a workload to perform its intended function correctly and consistently, including the ability to recover from failures.

**Key Design Principles:**
- Automatically recover from failure
- Test recovery procedures
- Scale horizontally to increase aggregate availability
- Stop guessing capacity (use Auto Scaling)
- Manage change through automation

**Key AWS Services:**
- Amazon EC2 Auto Scaling
- Elastic Load Balancing
- Amazon RDS Multi-AZ
- Amazon S3 (11 9s durability)
- AWS Backup
- Amazon Route 53 (DNS failover)

**Exam tip:** Multi-AZ, Auto Scaling, backups, and disaster recovery strategies all fall under Reliability.

[TODO: Cover RTO and RPO definitions here since they come up frequently on the exam]

### Pillar 4: Performance Efficiency

**Focus:** Using computing resources efficiently and maintaining that efficiency as demand changes and technologies evolve.

**Key Design Principles:**
- Democratize advanced technologies (use managed services instead of building from scratch)
- Go global in minutes (deploy to multiple Regions)
- Use serverless architectures where possible
- Experiment more often
- Consider mechanical sympathy (understand how services are consumed and pick the right tool)

**Key AWS Services:**
- AWS Lambda (serverless compute)
- Amazon DynamoDB (serverless database)
- Amazon CloudFront (CDN for performance)
- Amazon ElastiCache (in-memory caching)
- Auto Scaling (right-sizing)

**Exam tip:** Questions about choosing the right instance type, caching strategies, or serverless vs. provisioned are Performance Efficiency.

[TODO: Add a decision tree for choosing compute: EC2 vs Lambda vs ECS vs Fargate]

### Pillar 5: Cost Optimization

**Focus:** Avoiding unnecessary costs, understanding where money is being spent, and selecting the most cost-effective resources.

**Key Design Principles:**
- Implement cloud financial management (assign ownership of costs)
- Adopt a consumption model (pay only for what you use)
- Measure overall efficiency
- Stop spending money on undifferentiated heavy lifting (use managed services)
- Analyze and attribute expenditure

**Key AWS Services:**
- AWS Cost Explorer
- AWS Budgets
- Savings Plans and Reserved Instances
- Spot Instances
- S3 Intelligent-Tiering and lifecycle policies
- AWS Trusted Advisor (cost optimization checks)

**Exam tip:** Spot Instances, Reserved Instances, S3 storage classes, and right-sizing are common cost optimization question topics.

[TODO: Create a comparison table of EC2 pricing models -- On-Demand, Reserved, Savings Plans, Spot, Dedicated]

### Pillar 6: Sustainability

**Focus:** Minimizing the environmental impacts of running cloud workloads.

**Key Design Principles:**
- Understand your impact
- Establish sustainability goals
- Maximize utilization (right-size, scale down when idle)
- Anticipate and adopt new, more efficient offerings
- Use managed services (shared infrastructure is more efficient)
- Reduce the downstream impact of your workloads

**Key AWS Services:**
- EC2 Auto Scaling (scale down when not needed)
- AWS Graviton processors (more energy-efficient)
- Amazon S3 Intelligent-Tiering (reduce storage footprint)
- AWS Lambda (no idle resources)

**Exam tip:** Sustainability is the newest pillar. Questions are less frequent but may ask about choosing energy-efficient instance types (Graviton) or reducing idle resources.

[TODO: Add 1-2 exam-style scenario questions for sustainability]

---

## Shared Responsibility Model

The Shared Responsibility Model defines what AWS is responsible for and what the customer is responsible for. This is **one of the most fundamental concepts** on the SAA-C03 exam.

### The Core Idea

> **AWS is responsible for security OF the cloud.**
> **The customer is responsible for security IN the cloud.**

### AWS Responsibilities (Security OF the Cloud)

AWS manages, operates, and controls components from the host operating system and virtualization layer down to the physical security of the facilities:

- Physical security of data centers (guards, fences, cameras, environmental controls)
- Hardware and global infrastructure (Regions, AZs, Edge Locations)
- Hypervisor and host OS management
- Network infrastructure (routers, switches, cabling)
- Managed service infrastructure (e.g., the RDS database engine patching, S3 storage layer)

### Customer Responsibilities (Security IN the Cloud)

The customer is responsible for managing their data and configuring the services they use:

- **Data** -- encryption at rest and in transit, data classification, backups
- **Identity and Access Management** -- IAM policies, MFA, password policies
- **Operating system** -- patching guest OS on EC2 instances
- **Network configuration** -- Security Groups, NACLs, route tables, VPC design
- **Application** -- application-level security, code vulnerabilities
- **Firewall configuration** -- both host-based and network-based

### Shared Controls

Some controls are shared between AWS and the customer:

| Control | AWS Responsibility | Customer Responsibility |
|---|---|---|
| Patch management | Infrastructure patching | Guest OS and application patching |
| Configuration management | Infrastructure device config | Application and database config |
| Awareness and training | AWS employee training | Customer employee training |

### How Responsibility Shifts by Service Type

| Service Type | Example | Customer Responsibility |
|---|---|---|
| **IaaS** (Infrastructure) | EC2 | Everything from the guest OS up: patching, firewall, data, application |
| **PaaS** (Platform) | RDS, Elastic Beanstalk | Data, user access, some network config. AWS handles OS patching. |
| **SaaS** (Software) | Amazon Rekognition, Lex | Data input/output, IAM permissions. AWS handles almost everything else. |
| **Serverless** | Lambda, DynamoDB, S3 | Data, IAM permissions, encryption settings. AWS handles servers entirely. |

[TODO: Add a visual "stack" diagram showing customer vs. AWS responsibility for IaaS, PaaS, and SaaS]

### Common Exam Scenarios

1. **"Who is responsible for patching the database engine on an RDS instance?"** -- AWS. RDS is a managed service; AWS handles engine patching.
2. **"Who is responsible for patching the OS on an EC2 instance?"** -- The customer. EC2 is IaaS; the customer manages the guest OS.
3. **"Who is responsible for physical security of a data center?"** -- AWS. Always.
4. **"Who is responsible for encrypting data stored in S3?"** -- The customer must enable and configure encryption (SSE-S3, SSE-KMS, SSE-C, or client-side). AWS provides the encryption mechanisms but the customer chooses to use them.
5. **"Who is responsible for configuring Security Group rules?"** -- The customer. Network configuration is always customer responsibility.

[TODO: Add 5 more tricky shared responsibility scenarios]

---

## Key Takeaways for the SAA-C03 Exam

1. **Multi-AZ = high availability.** Any time the exam asks for HA, think multi-AZ.
2. **Multi-Region = disaster recovery and low latency globally.** More expensive than multi-AZ.
3. **Edge Locations are for caching and DNS.** Think CloudFront and Route 53.
4. **Know all six Well-Architected pillars by name** and be able to match a design decision to its pillar.
5. **The Shared Responsibility Model is a guaranteed exam topic.** Know the IaaS vs. PaaS vs. Serverless responsibility differences cold.
6. **When in doubt, pick the answer that is most automated, most managed, and most multi-AZ.** These align with AWS best practices.

[TODO: Add a self-assessment checklist -- "Can I explain X without looking at my notes?"]

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- AWS Global Infrastructure
- AWS Well-Architected Framework
- Shared Responsibility Model
- Key Takeaways for the SAA-C03 Exam

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
