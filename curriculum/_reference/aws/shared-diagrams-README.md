# Architecture Diagram Notation Guide

Throughout this study project, architecture diagrams are represented as
**text-based ASCII art** so they can live alongside the code and render
in any terminal or editor without special tooling.

This document explains the notation conventions used in those diagrams.

---

## Boxes — Resources and Services

Resources (EC2 instances, RDS databases, S3 buckets, etc.) are drawn as
rectangular boxes using `+`, `-`, and `|` characters:

```
+---------------------+
|    EC2 Instance      |
|    t3.micro          |
|    10.0.1.10         |
+---------------------+
```

Larger logical groupings (VPCs, subnets, Availability Zones) use
double-line or labeled borders:

```
+========================== VPC 10.0.0.0/16 ==========================+
|                                                                      |
|  +--- Public Subnet 10.0.1.0/24 ---+   +--- Public Subnet ...---+  |
|  |                                   |   |                        |  |
|  |  +-------------+                 |   |  +-------------+       |  |
|  |  | EC2 (web)   |                 |   |  | EC2 (web)   |       |  |
|  |  +-------------+                 |   |  +-------------+       |  |
|  +-----------------------------------+   +------------------------+  |
|                                                                      |
+======================================================================+
```

## Arrows — Data Flow and Connections

```
----->      One-way data flow (left to right)
<-----      One-way data flow (right to left)
<---->      Bidirectional communication

|           Vertical connection
|
v           Downward flow

^           Upward flow
|

- - - ->    Dashed arrow: optional, conditional, or async flow
```

Arrows are labeled when the protocol or purpose matters:

```
User ---HTTPS---> ALB ---HTTP:80---> EC2
```

## Cloud Boundaries

The AWS cloud boundary and region/AZ boundaries are shown with labeled
borders:

```
+=================== AWS Cloud ===================+
|                                                   |
|  +--- us-east-1a ---+   +--- us-east-1b ---+    |
|  |                    |   |                   |   |
|  |  (resources)       |   |  (resources)      |   |
|  +--------------------+   +-------------------+   |
|                                                   |
+===================================================+
```

## Service Icons (Text Abbreviations)

Since we cannot embed images in plain text, services use short labels:

| Abbreviation | AWS Service                       |
|-------------|-----------------------------------|
| `[EC2]`     | Elastic Compute Cloud             |
| `[S3]`      | Simple Storage Service            |
| `[RDS]`     | Relational Database Service       |
| `[DDB]`     | DynamoDB                          |
| `[ALB]`     | Application Load Balancer         |
| `[NLB]`     | Network Load Balancer             |
| `[IGW]`     | Internet Gateway                  |
| `[NGW]`     | NAT Gateway                       |
| `[SG]`      | Security Group                    |
| `[NACL]`    | Network ACL                       |
| `[RT]`      | Route Table                       |
| `[EIP]`     | Elastic IP                        |
| `[ASG]`     | Auto Scaling Group                |
| `[LC/LT]`   | Launch Config / Launch Template  |
| `[EFS]`     | Elastic File System               |
| `[EBS]`     | Elastic Block Store               |
| `[Lambda]`  | AWS Lambda                        |
| `[APIGW]`   | API Gateway                      |
| `[SQS]`     | Simple Queue Service              |
| `[SNS]`     | Simple Notification Service       |
| `[CW]`      | CloudWatch                        |
| `[CF]`      | CloudFormation                    |
| `[R53]`     | Route 53                          |
| `[CF-CDN]`  | CloudFront (CDN)                 |
| `[IAM]`     | Identity and Access Management    |
| `[KMS]`     | Key Management Service            |
| `[ECR]`     | Elastic Container Registry        |

## Security Boundaries

Security groups and NACLs are shown as dashed or dotted borders around
the resources they protect:

```
+--- SG: web-sg (allow 80, 443) ---+
|                                    |
|  +-------------+                  |
|  | EC2 (web)   |                  |
|  +-------------+                  |
|                                    |
+------------------------------------+
```

## Complete Example

Below is a simplified two-tier web application:

```
                         Internet
                            |
                            v
                       +--------+
                       |  [IGW] |
                       +--------+
                            |
+============== VPC 10.0.0.0/16 ==============+
|                           |                   |
|  +-- Public Subnet ------+--+                |
|  |                        |  |                |
|  |  +--------+  +------+ |  |                |
|  |  | [ALB]  |  | [NGW]| |  |                |
|  |  +--------+  +------+ |  |                |
|  |       |           |    |  |                |
|  +-------+-----------+----+  |                |
|          |           |        |                |
|  +-- Private Subnet -+-------+--+             |
|  |       |                   |   |             |
|  |  +----v----+   +--------+|   |             |
|  |  | [EC2]   |   | [EC2]  ||   |             |
|  |  | (app)   |   | (app)  ||   |             |
|  |  +---------+   +--------+|   |             |
|  |       |                   |   |             |
|  +-------+-------------------+   |             |
|          |                       |             |
|  +-- Private Subnet (DB) -------+--+          |
|  |       |                       |   |          |
|  |  +----v----+                  |   |          |
|  |  | [RDS]   |                  |   |          |
|  |  | (MySQL) |                  |   |          |
|  |  +---------+                  |   |          |
|  +-------------------------------+   |          |
|                                       |          |
+===========================================+
```

## Tips for Reading Diagrams

1. **Start at the top** — diagrams generally flow from the internet or
   user down through the infrastructure.
2. **Follow the arrows** — they show how traffic or data moves.
3. **Look at the labels** — CIDR blocks, port numbers, and protocol
   names tell you exactly what is allowed.
4. **Check the boundaries** — which subnet is public vs. private?
   Which security group protects which resource?
5. **Compare with the code** — every box in the diagram corresponds to
   a resource in the Boto3 script or Terraform configuration.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Boxes — Resources and Services
- Arrows — Data Flow and Connections
- Cloud Boundaries
- Service Icons (Text Abbreviations)

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
