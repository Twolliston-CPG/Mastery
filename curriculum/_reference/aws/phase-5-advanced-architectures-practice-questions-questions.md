# Phase 5: Practice Questions -- Advanced Architectures

25 SAA-C03 style scenario questions. Try to answer each before revealing the answer and explanation.

---

## Question 1 -- Migration Strategy

A company wants to move 300 on-premises Windows and Linux servers to AWS as quickly as possible. They have a 6-month data center lease expiration. The applications should run on AWS with minimal modifications. Which migration strategy and AWS service should they use?

**A.** Refactor using Lambda and API Gateway
**B.** Rehost using AWS Application Migration Service (MGN)
**C.** Replatform using AWS Elastic Beanstalk
**D.** Repurchase using AWS Marketplace SaaS products

<details>
<summary>Answer</summary>

**B. Rehost using AWS Application Migration Service (MGN)**

MGN performs automated lift-and-shift migration for physical, virtual, and cloud servers. It uses continuous block-level replication with minimal cutover downtime. Rehost is the fastest strategy for large-scale migrations when minimal changes are acceptable. "300 servers" + "quickly" + "minimal modifications" = Rehost with MGN.
</details>

---

## Question 2 -- Database Migration

A company is migrating an on-premises Oracle database to Amazon Aurora PostgreSQL. The database is 2 TB. They need to minimize downtime during the cutover. Which combination of services should they use?

**A.** AWS DMS with full load only
**B.** AWS DMS with Schema Conversion Tool (SCT) and Change Data Capture (CDC)
**C.** AWS Snowball Edge to transfer the database, then DMS
**D.** Export the Oracle database to CSV and import into Aurora

<details>
<summary>Answer</summary>

**B. AWS DMS with Schema Conversion Tool (SCT) and Change Data Capture (CDC)**

This is a heterogeneous migration (Oracle -> Aurora PostgreSQL), so SCT is required to convert the schema. CDC captures ongoing changes during migration, enabling near-zero downtime. DMS performs the full load while CDC replicates changes that occur during the migration. At cutover, you switch the application to Aurora with minimal data loss.
</details>

---

## Question 3 -- DR Strategy Selection

A company operates an internal HR application used during business hours. The application stores data in an RDS MySQL database. The company can tolerate up to 24 hours of downtime and can afford to lose up to 4 hours of data. They want the most cost-effective DR solution. Which DR strategy should they use?

**A.** Multi-Site Active/Active
**B.** Warm Standby
**C.** Pilot Light
**D.** Backup and Restore

<details>
<summary>Answer</summary>

**D. Backup and Restore**

The requirements are RPO = 4 hours and RTO = 24 hours. Backup and Restore is the cheapest DR strategy and can meet these requirements with regular RDS automated backups (point-in-time recovery within the backup retention period) and cross-region snapshot copies. There is no need to pay for a running read replica or warm standby environment for such relaxed RPO/RTO requirements.
</details>

---

## Question 4 -- DR Strategy Selection (Strict Requirements)

A financial services company runs a trading platform that processes millions of transactions daily. They require an RPO of near-zero and an RTO of less than 1 minute. Which DR strategy and database solution should they use?

**A.** Pilot Light with RDS read replica
**B.** Warm Standby with Aurora read replica
**C.** Multi-Site Active/Active with Aurora Global Database
**D.** Backup and Restore with RDS automated backups

<details>
<summary>Answer</summary>

**C. Multi-Site Active/Active with Aurora Global Database**

Near-zero RPO and < 1 minute RTO requires Multi-Site Active/Active. Aurora Global Database provides cross-region replication with < 1 second lag (near-zero RPO) and can promote a secondary region to writer in < 1 minute (meeting the RTO requirement). This is the most expensive strategy but the only one that meets these strict requirements.
</details>

---

## Question 5 -- CloudFront Origin

A company hosts a static website in an S3 bucket and wants to serve it globally through CloudFront. They want to ensure users cannot bypass CloudFront and access S3 directly. The S3 objects are encrypted with SSE-KMS. Which approach should they use?

**A.** Origin Access Identity (OAI) with S3 bucket policy
**B.** Origin Access Control (OAC) with S3 bucket policy
**C.** S3 website endpoint as a custom origin with a Referer header check
**D.** Public S3 bucket with CloudFront as a pass-through

<details>
<summary>Answer</summary>

**B. Origin Access Control (OAC) with S3 bucket policy**

OAC is the recommended approach (OAI is legacy). The critical detail is that the objects are encrypted with SSE-KMS. OAI does NOT support SSE-KMS encrypted objects. OAC supports SSE-KMS, all HTTP methods, and all S3 regions. The S3 bucket policy should only allow the CloudFront distribution's service principal with a condition matching the distribution ARN.
</details>

---

## Question 6 -- CloudFront vs Global Accelerator

A gaming company runs UDP-based multiplayer game servers on EC2 instances in us-east-1. Players worldwide experience high latency. The company needs static IP addresses for their game clients to connect to. Which service should they use?

**A.** Amazon CloudFront
**B.** AWS Global Accelerator
**C.** Amazon Route 53 latency-based routing
**D.** AWS Direct Connect

<details>
<summary>Answer</summary>

**B. AWS Global Accelerator**

Three key clues: (1) UDP protocol -- CloudFront only supports HTTP/HTTPS, not UDP. (2) Static IP addresses -- Global Accelerator provides 2 static Anycast IPs. (3) Low latency for gaming -- Global Accelerator routes traffic through the AWS backbone. CloudFront cannot handle UDP traffic, which immediately eliminates it.
</details>

---

## Question 7 -- CloudFront Functions vs Lambda@Edge

A company uses CloudFront to serve their website. They need to add security headers (HSTS, Content-Security-Policy, X-Frame-Options) to all responses. The solution must handle millions of requests per second with minimal latency. Which approach should they use?

**A.** Lambda@Edge on Viewer Response
**B.** CloudFront Functions on Viewer Response
**C.** Modify the origin server to add headers
**D.** Use CloudFront custom headers in the distribution configuration

<details>
<summary>Answer</summary>

**B. CloudFront Functions on Viewer Response**

Adding static security headers is a simple, lightweight operation that does not require network access or heavy computation. CloudFront Functions are designed for exactly this: simple viewer request/response manipulation at massive scale (millions of requests/second) with sub-millisecond execution time. Lambda@Edge would work but is more expensive and slower for this simple task.
</details>

---

## Question 8 -- Signed URLs vs Signed Cookies

A media company uses CloudFront to deliver premium video content. Each video consists of hundreds of HLS segment files (`.ts` files) and a manifest file (`.m3u8`). Only paying subscribers should be able to watch videos. Which approach should they use?

**A.** CloudFront signed URLs for each segment file
**B.** CloudFront signed cookies
**C.** S3 pre-signed URLs for each segment file
**D.** API Gateway with Lambda authorizer in front of CloudFront

<details>
<summary>Answer</summary>

**B. CloudFront signed cookies**

HLS video streaming involves hundreds of segment files per video. Signed URLs would require generating a unique signed URL for every single segment file, which is impractical. Signed cookies apply to ALL requests matching a path pattern, so one cookie covers all segment files and the manifest. This is the standard approach for multi-file content like video streaming.
</details>

---

## Question 9 -- Hybrid Connectivity

A company has 20 VPCs across 3 AWS regions and an on-premises data center. They need to connect all VPCs to each other and to the on-premises network. Currently they use 10 Gbps Direct Connect. What architecture should they use?

**A.** VPC peering between all 20 VPCs plus VPN connections to on-premises
**B.** Transit Gateway in each region with Transit Gateway peering, connected to on-premises via Direct Connect Gateway
**C.** AWS PrivateLink between all VPCs
**D.** VPN connections between each VPC and on-premises

<details>
<summary>Answer</summary>

**B. Transit Gateway in each region with Transit Gateway peering, connected to on-premises via Direct Connect Gateway**

20 VPCs would require 190 peering connections (full mesh), which is unmanageable. Transit Gateway provides hub-and-spoke connectivity within each region. Transit Gateway peering connects TGWs across regions. Direct Connect Gateway connects the on-premises Direct Connect to Transit Gateways in all regions through a single DX connection. This is the standard architecture for multi-region, multi-VPC environments with on-premises connectivity.
</details>

---

## Question 10 -- VPN Bandwidth

A company uses Site-to-Site VPN to connect their on-premises data center to AWS. They need more than 1.25 Gbps of bandwidth over VPN. How can they achieve this?

**A.** Upgrade to Direct Connect
**B.** Create multiple VPN connections to a Transit Gateway with ECMP
**C.** Increase the VPN tunnel MTU size
**D.** Use VPN accelerator to increase single tunnel bandwidth

<details>
<summary>Answer</summary>

**B. Create multiple VPN connections to a Transit Gateway with ECMP**

A single VPN tunnel is limited to ~1.25 Gbps. Transit Gateway supports Equal-Cost Multi-Path (ECMP) routing, which distributes traffic across multiple VPN connections. For example, 4 VPN connections provide ~5 Gbps aggregate bandwidth. This is the only way to increase VPN bandwidth beyond 1.25 Gbps without switching to Direct Connect.
</details>

---

## Question 11 -- Outposts vs Wavelength vs Local Zones

A company must process sensitive healthcare data that regulatory compliance requires to stay within their own data center. However, they want to use AWS services and APIs for their application. Which service should they use?

**A.** AWS Wavelength
**B.** AWS Local Zones
**C.** AWS Outposts
**D.** AWS Region with a VPN connection

<details>
<summary>Answer</summary>

**C. AWS Outposts**

Outposts deploys AWS infrastructure (compute, storage, databases) physically in the customer's data center. Data never leaves the customer's facility, meeting data residency requirements. The customer uses the same AWS APIs and tools. Wavelength is for 5G edge, Local Zones are for metro-area latency, and a VPN still sends data to an AWS region.
</details>

---

## Question 12 -- Serverless Pattern

A company needs to process images uploaded to S3. Each image requires 5 transformation steps: resize, watermark, format conversion, metadata extraction, and thumbnail generation. If any step fails, the entire process should retry that step up to 3 times. Which architecture should they use?

**A.** S3 event notification -> Lambda (single function doing all 5 steps)
**B.** S3 event notification -> Lambda -> Step Functions (5 Lambda steps with retry)
**C.** S3 event notification -> SQS -> EC2 (processing application)
**D.** S3 event notification -> SNS -> 5 Lambda functions in parallel

<details>
<summary>Answer</summary>

**B. S3 event notification -> Lambda -> Step Functions (5 Lambda steps with retry)**

Step Functions is designed for multi-step workflows with built-in retry logic, error handling, and state management. Each transformation step can be a separate Lambda function orchestrated by Step Functions. The retry policy (up to 3 retries per step) is a native Step Functions feature. A single Lambda function would be brittle and hard to debug. SNS fan-out would run all 5 in parallel but they likely need to be sequential (resize before watermark).
</details>

---

## Question 13 -- Serverless vs Containers

A company has a Java application that runs continuously, processes messages from a queue, and requires 30 GB of memory. The application uses specific JVM tuning parameters and custom libraries. Which compute option is most appropriate?

**A.** AWS Lambda with a container image
**B.** ECS on Fargate
**C.** ECS on EC2 with memory-optimized instances
**D.** Elastic Beanstalk with a Docker platform

<details>
<summary>Answer</summary>

**C. ECS on EC2 with memory-optimized instances**

Lambda is limited to 10 GB of memory, so it is eliminated. Fargate supports up to 30 GB memory for a single task (as of the latest Fargate configurations), but for a continuously running Java application with specific JVM tuning and 30 GB memory, ECS on EC2 with memory-optimized instances (e.g., R5/R6i) provides the best control over the runtime environment and is more cost-effective for 24/7 workloads using Reserved Instances.
</details>

---

## Question 14 -- Container Architecture

A company is migrating their Kubernetes-based microservices architecture from on-premises to AWS. They want to continue using their existing Kubernetes manifests and Helm charts. They do not want to manage the underlying EC2 instances. Which solution should they use?

**A.** Amazon ECS on Fargate
**B.** Amazon EKS on Fargate
**C.** Amazon ECS on EC2
**D.** Amazon EKS on EC2 with managed node groups

<details>
<summary>Answer</summary>

**B. Amazon EKS on Fargate**

Two key requirements: (1) Continue using Kubernetes manifests and Helm charts -- this requires EKS (not ECS, which is AWS-proprietary). (2) Do not manage EC2 instances -- this requires Fargate (serverless compute). EKS on Fargate runs Kubernetes pods without managing nodes. Managed node groups (option D) still require managing EC2 instances to some degree.
</details>

---

## Question 15 -- ECS Roles

A containerized application running on ECS Fargate needs to read messages from an SQS queue and write results to a DynamoDB table. How should the application be granted permissions?

**A.** Create an IAM user with access keys embedded in the container environment variables
**B.** Attach an IAM Task Role to the ECS task definition with SQS and DynamoDB permissions
**C.** Attach an IAM Task Execution Role with SQS and DynamoDB permissions
**D.** Use the EC2 instance profile of the underlying Fargate infrastructure

<details>
<summary>Answer</summary>

**B. Attach an IAM Task Role to the ECS task definition with SQS and DynamoDB permissions**

The Task Role grants the application (container) permissions to call AWS services. The Task Execution Role is for the ECS agent (pulling images, sending logs) -- not for application-level permissions. IAM users with access keys are an anti-pattern. Fargate does not expose instance profiles.
</details>

---

## Question 16 -- Data Analytics: Kinesis

A company collects clickstream data from their website. They need to deliver this data to S3 for batch analytics and to OpenSearch Service for real-time dashboards. The solution should require minimal operational management. Which approach should they use?

**A.** Kinesis Data Streams with two consumers: Lambda (writes to S3) and Lambda (writes to OpenSearch)
**B.** Kinesis Data Firehose with S3 as destination, and a separate Firehose with OpenSearch as destination
**C.** Kinesis Data Streams with Kinesis Data Firehose consumer (to S3) and a Lambda consumer (to OpenSearch)
**D.** SQS queue with two Lambda consumers

<details>
<summary>Answer</summary>

**C. Kinesis Data Streams with Kinesis Data Firehose consumer (to S3) and a Lambda consumer (to OpenSearch)**

Kinesis Data Streams supports multiple consumers. Firehose can be a consumer of Data Streams and delivers to S3 with no code. A separate Lambda consumer reads from Data Streams and writes to OpenSearch. This combines the real-time capability of Data Streams (multiple consumers) with the operational simplicity of Firehose (auto-delivery to S3). Option B with two separate Firehose streams would work but requires the producer to send to two streams. SQS does not support multiple consumers for the same message.
</details>

---

## Question 17 -- Athena Cost Optimization

A company queries their S3 data lake using Amazon Athena. Their monthly Athena bill is $500 and growing. Most queries scan specific date ranges but end up reading all data. How can they reduce costs?

**A.** Convert data from JSON to Parquet format and partition by date
**B.** Move data to Amazon Redshift
**C.** Use larger S3 object sizes
**D.** Increase the Athena query timeout

<details>
<summary>Answer</summary>

**A. Convert data from JSON to Parquet format and partition by date**

Athena charges $5 per TB of data scanned. Two techniques dramatically reduce data scanned: (1) Parquet is a columnar format -- Athena reads only the needed columns instead of entire rows, reducing data scanned by 75% or more. (2) Partitioning by date means Athena only scans partitions matching the WHERE clause, skipping irrelevant dates entirely. Together, these can reduce costs by 90%+.
</details>

---

## Question 18 -- Glue vs EMR

A company needs to run Apache Spark jobs to process 500 GB of data daily. The Spark jobs use custom libraries and require specific Spark configuration tuning. The data engineering team has deep Spark expertise. Which service should they use?

**A.** AWS Glue ETL
**B.** Amazon EMR
**C.** Amazon Athena
**D.** AWS Lambda

<details>
<summary>Answer</summary>

**B. Amazon EMR**

While Glue ETL uses Spark under the hood, EMR provides full control over the Spark configuration, custom libraries, and cluster tuning. The team's deep Spark expertise makes EMR a natural fit. EMR also allows the use of Spot Instances for Task nodes to reduce costs. Glue ETL is better for simpler ETL jobs where operational simplicity is prioritized over configuration control.
</details>

---

## Question 19 -- Global Accelerator Failover

A company runs a TCP-based application in us-east-1 and eu-west-1. They need instant failover (< 30 seconds) if one region becomes unhealthy. The application does not serve cacheable HTTP content. Which service should they use?

**A.** Amazon CloudFront with origin failover
**B.** AWS Global Accelerator with endpoint groups in both regions
**C.** Route 53 with failover routing and health checks
**D.** Application Load Balancer with cross-region targets

<details>
<summary>Answer</summary>

**B. AWS Global Accelerator with endpoint groups in both regions**

Key requirements: (1) TCP (not HTTP) -- eliminates CloudFront. (2) Instant failover < 30 seconds -- Global Accelerator detects failures and reroutes in < 30 seconds. Route 53 failover depends on DNS TTL propagation, which can take minutes. (3) Not cacheable -- confirms CloudFront is not appropriate. ALB does not support cross-region targets natively.
</details>

---

## Question 20 -- EventBridge vs SNS

A company needs to trigger multiple AWS services when specific events occur in their application. The events have complex JSON payloads, and they need content-based filtering to route events to different targets based on the event content. They also need the ability to replay past events for debugging. Which service should they use?

**A.** Amazon SNS with message filtering
**B.** Amazon EventBridge with event patterns and archive/replay
**C.** Amazon SQS with multiple queues
**D.** Amazon Kinesis Data Streams

<details>
<summary>Answer</summary>

**B. Amazon EventBridge with event patterns and archive/replay**

EventBridge provides rich content-based filtering (matching on any JSON field in the event payload), supports 20+ target types, and has built-in archive and replay capability. SNS has basic attribute filtering but cannot filter on the message body content. SQS does not support routing or filtering. Kinesis is for streaming, not event routing.
</details>

---

## Question 21 -- S3 Replication

A company has an S3 bucket with 10 TB of existing data and is enabling cross-region replication to a bucket in another region. After enabling replication, they notice that the 10 TB of existing data has not been replicated. What should they do?

**A.** Delete and re-upload all existing objects
**B.** Use S3 Batch Replication to replicate existing objects
**C.** Disable and re-enable replication
**D.** Create a new bucket and re-upload with replication enabled from the start

<details>
<summary>Answer</summary>

**B. Use S3 Batch Replication to replicate existing objects**

S3 replication only applies to NEW objects uploaded after the replication rule is enabled. Existing objects are NOT automatically replicated. S3 Batch Replication (a feature of S3 Batch Operations) can replicate existing objects, objects that failed replication, and objects replicated under a previous rule. This is the correct and most efficient solution.
</details>

---

## Question 22 -- Migration: Large Database

A company needs to migrate a 60 TB Oracle database to AWS. Their internet connection is 1 Gbps. Using DMS over the internet would take over 6 days. They want to reduce the migration time. Which approach should they use?

**A.** AWS DMS over the internet with parallel replication tasks
**B.** AWS Snowball Edge to transfer the initial data, then DMS with CDC for ongoing changes
**C.** AWS Direct Connect to increase bandwidth
**D.** Compress the database and transfer via S3 Transfer Acceleration

<details>
<summary>Answer</summary>

**B. AWS Snowball Edge to transfer the initial data, then DMS with CDC for ongoing changes**

DMS supports integration with Snowball Edge for large-scale database migrations. The process: (1) Use DMS to extract data to a Snowball Edge device. (2) Ship the Snowball Edge to AWS (days, but moves 60 TB without network). (3) AWS loads the data into S3, then DMS loads it into the target database. (4) DMS CDC captures all changes made since the extraction started and applies them. This minimizes migration time and downtime.
</details>

---

## Question 23 -- Pilot Light vs Warm Standby

A company implements DR in a secondary region. They have an RDS read replica running continuously in the DR region, but no EC2 instances, no ALB, and no NAT Gateway. AMIs and launch templates are pre-configured. What DR strategy is this?

**A.** Backup and Restore
**B.** Pilot Light
**C.** Warm Standby
**D.** Multi-Site Active/Active

<details>
<summary>Answer</summary>

**B. Pilot Light**

Pilot Light keeps the core/critical components running (the RDS read replica) with everything else ready but not running (AMIs ready, templates configured). The key differentiator from Warm Standby is that there is NO running compute (no EC2, no ALB). In Warm Standby, a scaled-down but fully functional environment is running (ALB + minimal EC2 + read replica). In Pilot Light, only the data layer is live.
</details>

---

## Question 24 -- Direct Connect Encryption

A company uses AWS Direct Connect for their 10 Gbps connection to AWS. A security audit requires that all data in transit be encrypted. How should they encrypt traffic over Direct Connect?

**A.** Direct Connect traffic is encrypted by default using TLS
**B.** Enable MACsec encryption on the Direct Connect connection
**C.** Create a Site-to-Site VPN connection over the Direct Connect link
**D.** Use S3 server-side encryption for all data

<details>
<summary>Answer</summary>

**C. Create a Site-to-Site VPN connection over the Direct Connect link**

Direct Connect traffic is NOT encrypted by default. To encrypt it, create a VPN connection that runs over the Direct Connect link. This combines the consistent bandwidth and low latency of Direct Connect with IPsec encryption of VPN. MACsec (option B) is also valid for dedicated connections at supported Direct Connect locations, but VPN over DX is the more commonly tested and widely available answer on the SAA-C03.
</details>

---

## Question 25 -- Lake Formation

A company has a data lake on S3 with hundreds of tables cataloged in the Glue Data Catalog. Different business teams need access to different columns in the same table. For example, the marketing team should see customer names but NOT social security numbers. The current approach using S3 bucket policies is unmanageable. Which service should they use?

**A.** S3 Access Points with different policies per team
**B.** AWS Lake Formation with column-level permissions
**C.** IAM policies with S3 resource ARNs for specific prefixes
**D.** Create separate S3 buckets for each team with filtered data

<details>
<summary>Answer</summary>

**B. AWS Lake Formation with column-level permissions**

Lake Formation provides fine-grained access control at the column level (and even row level and cell level). You can grant the marketing team access to specific columns in a table while hiding sensitive columns like SSN. This is centrally managed through Lake Formation grants, not scattered across S3 bucket policies. S3 Access Points and IAM policies operate at the object/prefix level, not the column level.
</details>

---

## Scoring Guide

| Score | Assessment |
|---|---|
| 22-25 | Excellent -- ready for Phase 5 exam questions |
| 18-21 | Good -- review the topics you missed |
| 14-17 | Fair -- re-read the relevant notes and redo questions |
| Below 14 | Review Phase 5 notes thoroughly before proceeding |

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Migration Strategy
- Database Migration
- DR Strategy Selection
- DR Strategy Selection (Strict Requirements)

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
