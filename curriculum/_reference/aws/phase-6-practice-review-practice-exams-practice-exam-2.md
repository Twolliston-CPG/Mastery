# Practice Exam 2 — Full 65-Question SAA-C03 Simulation

## Focus: Commonly Confused Topics

**Time Limit:** 130 minutes
**Passing Score:** 72% (47/65)
**Target Score:** 80%+ (53/65)

This exam deliberately targets the most commonly confused AWS services and concepts. If you struggle with specific pairs (SQS vs Kinesis, SG vs NACL, etc.), this exam will expose those gaps.

**Domain Weighting:**
- Domain 1: Design Secure Architectures — Questions 1-20 (30%)
- Domain 2: Design Resilient Architectures — Questions 21-37 (26%)
- Domain 3: Design High-Performing Architectures — Questions 38-53 (24%)
- Domain 4: Design Cost-Optimized Architectures — Questions 54-65 (20%)

---

## Domain 1: Design Secure Architectures (Questions 1-20)

### Question 1
A company runs EC2 instances in a private subnet. The security team wants to control both inbound and outbound traffic at the subnet level. They need to explicitly deny traffic from a specific IP range (10.0.5.0/24) while allowing all other traffic.

Which solution should the architect configure?

A) Configure a security group rule to deny traffic from 10.0.5.0/24
B) Configure a Network ACL (NACL) with a deny rule for 10.0.5.0/24 with a lower rule number than the allow rule
C) Configure an AWS WAF rule to block the IP range
D) Configure a route table entry to blackhole the IP range

### Question 2
An application on EC2 instances needs to access a DynamoDB table and an S3 bucket. The security team requires that the credentials used are temporary and automatically rotated.

Which approach satisfies this requirement with the LEAST operational effort?

A) Create an IAM user, generate access keys, and configure key rotation every 90 days
B) Create an IAM role with the necessary DynamoDB and S3 permissions and associate it with the EC2 instances via an instance profile
C) Store long-term credentials in AWS Secrets Manager with automatic rotation
D) Use AWS STS AssumeRole from the application code to get temporary credentials

### Question 3
A company needs to store database passwords that are rotated automatically every 60 days. The application retrieves the password at runtime. Another team needs to store non-sensitive application configuration values.

Which combination of services should the architect recommend?

A) AWS Secrets Manager for database passwords with automatic rotation; AWS Systems Manager Parameter Store (standard parameters) for configuration values
B) AWS Systems Manager Parameter Store for both passwords and configuration values
C) AWS KMS for database passwords; Amazon S3 for configuration values
D) AWS Secrets Manager for both passwords and configuration values

### Question 4
A company has a web application behind an Application Load Balancer. The security team has identified that bots are scraping the website. They want to implement rate-based rules and block known bot IP addresses.

Which AWS service should the architect recommend?

A) AWS Shield Advanced
B) AWS WAF with rate-based rules and IP set rules
C) Amazon GuardDuty
D) Security groups on the ALB

### Question 5
A solutions architect is designing a VPC. The application tier in private subnets needs to call the DynamoDB API. The company's security policy prohibits any traffic from traversing the public internet.

Which solution meets this requirement at the LOWEST cost?

A) Deploy a NAT Gateway and route DynamoDB traffic through it
B) Create a VPC Gateway Endpoint for DynamoDB
C) Create a VPC Interface Endpoint (PrivateLink) for DynamoDB
D) Deploy a proxy server in a public subnet to forward DynamoDB requests

### Question 6
A company is deciding between using IAM roles and resource-based policies to grant cross-account access to an S3 bucket. The accessing account's users should not need to give up their existing permissions when accessing the bucket.

Which approach should the architect recommend?

A) Use an IAM role in the target account — the users assume the role
B) Use a resource-based policy (S3 bucket policy) that grants access to the source account's IAM principal
C) Use an IAM user in the target account with shared credentials
D) Use AWS Organizations to share the S3 bucket

### Question 7
An application encrypts data before storing it in S3. The application uses AWS KMS for key management. The security team wants to ensure that even if someone gains access to the S3 bucket, they cannot read the data without also having access to the KMS key.

Which encryption approach does this describe?

A) SSE-S3 (server-side encryption with S3-managed keys)
B) SSE-KMS (server-side encryption with KMS-managed keys)
C) SSE-C (server-side encryption with customer-provided keys)
D) Client-side encryption with a KMS-managed key

### Question 8
A company has a public-facing ALB and wants to protect it from volumetric DDoS attacks (Layer 3/4) and also wants access to the AWS DDoS Response Team and cost protection during an attack.

Which service provides these features?

A) AWS WAF
B) AWS Shield Standard
C) AWS Shield Advanced
D) Amazon GuardDuty

### Question 9
A company needs to ensure that specific S3 objects cannot be deleted or overwritten for a regulatory retention period of 5 years, even by the root user.

Which S3 feature enforces this?

A) S3 Versioning
B) S3 Object Lock in Compliance mode
C) S3 Object Lock in Governance mode
D) S3 bucket policy denying delete actions

### Question 10
A solutions architect needs to design network security for a three-tier application. The web tier is in a public subnet, and the application and database tiers are in private subnets. The architect wants to allow the web tier to communicate with the application tier on port 8080, but deny all other traffic between the tiers.

Which is the MOST appropriate approach?

A) Use security groups only: allow inbound port 8080 on the application tier SG from the web tier SG
B) Use NACLs only: create allow and deny rules for port 8080
C) Use both security groups and NACLs: SGs for allow rules and NACLs for explicit deny rules
D) Use AWS WAF to control traffic between tiers

### Question 11
A company has sensitive data in an S3 bucket. They need to discover and classify personally identifiable information (PII) across their S3 buckets and receive alerts when PII is detected in new objects.

Which AWS service is purpose-built for this?

A) Amazon GuardDuty
B) Amazon Inspector
C) Amazon Macie
D) AWS Config

### Question 12
A company needs to encrypt data in transit between their application servers and an Amazon RDS PostgreSQL database.

Which approach should the architect recommend?

A) Enable encryption at rest on the RDS instance
B) Configure the RDS instance to require SSL connections by setting the rds.force_ssl parameter to 1 and use SSL certificates in the application
C) Use a VPN connection between the application servers and RDS
D) Enable KMS encryption on the RDS instance

### Question 13
An application running on EC2 needs to retrieve a secret from AWS Secrets Manager. The application is in a private subnet with no internet access and no NAT Gateway.

How can the application access Secrets Manager?

A) It cannot — Secrets Manager requires internet access
B) Create a VPC Interface Endpoint (PrivateLink) for Secrets Manager
C) Create a VPC Gateway Endpoint for Secrets Manager
D) Peer the VPC with the Secrets Manager VPC

### Question 14
A company wants to enforce that all S3 buckets in their AWS account have server-side encryption enabled and that public access is blocked. They want to automatically remediate non-compliant buckets.

Which solution provides this capability?

A) AWS Config rules with automatic remediation using SSM Automation
B) AWS Trusted Advisor recommendations
C) CloudWatch alarms with Lambda remediation
D) S3 event notifications with Lambda

### Question 15
A solutions architect needs to allow an on-premises application to securely access AWS services through a private connection. The on-premises application communicates over the internet today and the company wants to move this traffic to a dedicated connection.

Which service provides a dedicated, private network connection from on-premises to AWS?

A) AWS Site-to-Site VPN
B) AWS Direct Connect
C) AWS Client VPN
D) AWS Transit Gateway

### Question 16
A company has an Auto Scaling group of EC2 instances that process images uploaded to S3. The images contain sensitive data, so the processing must happen within the VPC. The EC2 instances need to download images from S3 and upload results back to S3 without traversing the internet.

Which configuration enables this?

A) Assign public IP addresses to the EC2 instances
B) Configure a NAT Gateway for S3 access
C) Create a VPC Gateway Endpoint for S3 and update the route tables
D) Create an S3 bucket in the same AZ as the EC2 instances

### Question 17
A company wants to centrally manage encryption keys used across multiple AWS accounts in their organization. They need to control who can use specific keys and audit key usage.

Which service should the architect recommend?

A) AWS CloudHSM
B) AWS KMS with multi-region keys and key policies shared via AWS Organizations
C) AWS Secrets Manager
D) AWS Certificate Manager (ACM)

### Question 18
A company uses Amazon Cognito User Pools for authentication. They need to allow users to sign in with their Google and SocialGraph accounts in addition to username/password.

Which Cognito feature enables this?

A) Cognito Identity Pools (Federated Identities)
B) Cognito User Pools with social identity provider integration
C) Cognito Sync
D) IAM Identity Center (SSO)

### Question 19
An application uses HTTPS to communicate with an ALB. The company wants to use a free SSL/TLS certificate and have it automatically renewed.

Which service provides free, auto-renewing certificates that work with ALB?

A) AWS Certificate Manager (ACM) — request a public certificate
B) Import a self-signed certificate into ACM
C) Purchase a certificate from a third-party CA and upload it to IAM
D) Use AWS CloudHSM to generate and manage certificates

### Question 20
A company has a VPC with both public and private subnets. They deploy an EC2 instance in a private subnet. The instance has no public IP and no Elastic IP. A developer tries to SSH into the instance directly from the internet but cannot connect.

What is the CORRECT explanation?

A) The security group is blocking SSH
B) The NACL is blocking SSH
C) Instances in private subnets have no route to an internet gateway and no public IP, so they cannot be reached directly from the internet
D) The SSH key pair is invalid

---

## Domain 2: Design Resilient Architectures (Questions 21-37)

### Question 21
A company needs a message queue to process financial transactions. Each transaction must be processed exactly once and in the exact order it was sent. The system processes approximately 200 transactions per second.

Which messaging solution meets these requirements?

A) Amazon SQS Standard queue
B) Amazon SQS FIFO queue
C) Amazon Kinesis Data Streams
D) Amazon SNS with SQS subscription

### Question 22
A company collects clickstream data from millions of users in real time. They need to analyze trends over 24-hour windows and store the raw data for later batch processing. The data volume is 2 GB per second.

Which ingestion service is MOST appropriate?

A) Amazon SQS
B) Amazon Kinesis Data Streams
C) Amazon SNS
D) AWS IoT Core

### Question 23
A company's application uses Amazon Aurora MySQL. They want to deploy the application globally so users in Europe and Asia have low-latency read access to the database. Writes will always occur in us-east-1.

Which Aurora feature should the architect use?

A) Aurora Read Replicas in us-east-1
B) Aurora Global Database with secondary regions in Europe and Asia
C) Aurora Multi-AZ deployment
D) Aurora Serverless v2

### Question 24
A company runs an RDS MySQL database. They need a read-only copy of the database in a different AWS region for disaster recovery and to serve read traffic from that region.

Which feature should they use?

A) RDS Multi-AZ in the other region
B) RDS Cross-Region Read Replica
C) RDS automated backup with cross-region copy
D) AWS Database Migration Service (DMS) for continuous replication

### Question 25
A solutions architect is choosing between Amazon SQS and Amazon Kinesis Data Streams for a data processing pipeline. The data must be processed by multiple independent consumers, and the data order must be preserved.

Which service should the architect choose, and why?

A) SQS Standard — it supports multiple consumers and high throughput
B) SQS FIFO — it preserves order and supports exactly-once processing
C) Kinesis Data Streams — it supports multiple independent consumers reading the same data in order, using enhanced fan-out
D) SNS — it supports fan-out to multiple consumers

### Question 26
A company hosts a website on Amazon S3 with CloudFront. They need to ensure the website remains available even if the primary S3 bucket becomes unavailable.

Which CloudFront feature provides this resilience?

A) CloudFront Origin Failover — configure an origin group with a primary and secondary origin
B) CloudFront Lambda@Edge for routing
C) S3 cross-region replication alone
D) Route 53 health checks

### Question 27
A company needs a managed message broker service that supports MQTT and AMQP protocols for migrating their existing on-premises RabbitMQ application to AWS with minimal code changes.

Which AWS service should they use?

A) Amazon SQS
B) Amazon SNS
C) Amazon MQ
D) Amazon Kinesis

### Question 28
An application writes data to an SQS queue. A fleet of EC2 instances processes the messages. Occasionally, a message fails to process and keeps being retried, blocking other messages from being processed.

Which SQS feature prevents this issue?

A) Message visibility timeout increase
B) Dead-letter queue (DLQ) — configure a maximum receive count, after which failed messages are moved to the DLQ
C) FIFO queue migration
D) Long polling

### Question 29
A company runs an application using an Auto Scaling group. The application experiences predictable traffic spikes every day at 9 AM. Auto Scaling reactive policies cause a brief period of degraded performance while new instances launch.

Which Auto Scaling feature addresses this?

A) Target tracking scaling policy
B) Scheduled scaling action to increase capacity before 9 AM
C) Step scaling policy
D) Increasing the cooldown period

### Question 30
A company needs to create a disaster recovery plan for their application running in us-east-1. They need an RTO of under 1 minute and an RPO of zero.

Which DR strategy meets these requirements?

A) Backup and restore
B) Pilot light
C) Warm standby
D) Multi-site active-active deployment

### Question 31
A company uses Amazon EventBridge (formerly CloudWatch Events) and Amazon SNS for event-driven architectures. They need to route events from multiple sources to different targets based on event content. Some events should go to Lambda, some to SQS, and some to Step Functions.

Which service is BEST suited for content-based routing?

A) Amazon SNS with message filtering
B) Amazon EventBridge with rules and event patterns
C) Amazon SQS with message attributes
D) AWS Lambda with custom routing logic

### Question 32
A company has an application that uses an Application Load Balancer. The application instances take 3 minutes to start up and begin serving traffic. The Auto Scaling group sometimes terminates instances that are still starting up.

Which two settings should the architect adjust? (Select TWO)

A) Increase the ALB health check interval to 300 seconds
B) Set the Auto Scaling health check grace period to at least 180 seconds
C) Configure the ALB target group health check with appropriate thresholds (healthy threshold count and interval)
D) Decrease the deregistration delay
E) Set the Auto Scaling cooldown period to 0

### Question 33
A company is designing an architecture for a critical application. The architect needs to decide between Amazon RDS Multi-AZ and Amazon Aurora. The company needs automatic failover, up to 15 read replicas, and automatic storage scaling.

Which option should the architect choose?

A) RDS Multi-AZ with read replicas — it supports all requirements
B) Amazon Aurora — it supports automatic failover, up to 15 replicas, and auto-scaling storage
C) RDS Multi-AZ is sufficient — it provides up to 15 read replicas
D) Aurora Serverless — it provides all features plus automatic compute scaling

### Question 34
A company migrates a .NET application to AWS. The application requires a Windows-compatible shared file system that supports the SMB protocol. Multiple EC2 instances need to access the file system concurrently.

Which storage service should the architect recommend?

A) Amazon EFS
B) Amazon FSx for Windows File Server
C) Amazon S3
D) Amazon EBS with Multi-Attach

### Question 35
An application needs to process events from an SNS topic. The processing takes 10 minutes per event. The company wants to ensure no events are lost, even if the processing fails.

Which architecture ensures reliability?

A) Subscribe a Lambda function directly to the SNS topic
B) Subscribe an SQS queue to the SNS topic, then have EC2 instances process messages from the SQS queue
C) Subscribe an HTTP endpoint to the SNS topic
D) Use SNS message attributes to retry failed deliveries

### Question 36
A company runs an application across three Availability Zones. The application uses an Auto Scaling group with a minimum of 6 instances. The company wants to ensure the application can survive the loss of one entire AZ.

What is the MINIMUM number of instances the architect should configure as the desired capacity?

A) 6
B) 9
C) 12
D) 3

### Question 37
A company needs to replicate their DynamoDB table across three AWS regions for a globally distributed application. Each region should be able to handle both reads and writes with local latency.

Which DynamoDB feature provides this?

A) DynamoDB Streams with Lambda replication
B) DynamoDB Global Tables
C) DynamoDB Cross-Region Read Replicas
D) AWS Database Migration Service

---

## Domain 3: Design High-Performing Architectures (Questions 38-53)

### Question 38
A company runs a web application that requires sticky sessions. The application stores session data locally on the EC2 instance. Users report losing their session when they are routed to a different instance.

Which TWO approaches would solve this problem? (Select TWO)

A) Enable sticky sessions (session affinity) on the ALB target group
B) Store session data in Amazon ElastiCache for Redis and remove local session storage
C) Use a Network Load Balancer instead of an ALB
D) Increase the instance size
E) Deploy instances in a placement group

### Question 39
A company needs to choose between Amazon CloudFront and AWS Global Accelerator for their application. The application uses TCP connections (not HTTP) and needs static IP addresses.

Which service should the architect recommend?

A) Amazon CloudFront — it supports all protocols and provides static IPs
B) AWS Global Accelerator — it supports TCP/UDP and provides two static Anycast IP addresses
C) Amazon Route 53 — it provides static IPs and protocol support
D) Elastic Load Balancer with Elastic IPs

### Question 40
A company has a DynamoDB table that is experiencing hot partition issues. Certain items are read much more frequently than others, causing throttling.

Which solution reduces the impact of hot partitions?

A) Increase the provisioned read capacity units
B) Enable DynamoDB Accelerator (DAX) to absorb read traffic for hot keys
C) Migrate to Amazon RDS
D) Use DynamoDB Streams to distribute reads

### Question 41
An application needs to perform complex queries with joins across multiple tables in a relational database. The database experiences heavy read traffic during business hours. The application needs sub-millisecond latency for frequently repeated queries.

Which caching strategy should the architect implement?

A) Amazon DynamoDB Accelerator (DAX)
B) Amazon ElastiCache for Redis with a cache-aside (lazy loading) pattern
C) Amazon CloudFront
D) Amazon S3 caching

### Question 42
A company needs to choose between an Application Load Balancer (ALB) and a Network Load Balancer (NLB). The application requires support for WebSocket connections, path-based routing, and HTTP/2.

Which load balancer should the architect choose?

A) Network Load Balancer — it supports all Layer 4 and Layer 7 features
B) Application Load Balancer — it supports WebSocket, path-based routing, and HTTP/2
C) Classic Load Balancer
D) Gateway Load Balancer

### Question 43
A company is designing an architecture for a real-time leaderboard. The leaderboard must return the top 100 scores with sub-millisecond latency. Scores are updated frequently.

Which solution provides the BEST performance?

A) Amazon DynamoDB with a Global Secondary Index
B) Amazon ElastiCache for Redis using Sorted Sets
C) Amazon RDS with indexed queries
D) Amazon Redshift for analytical queries

### Question 44
A company has an EC2 instance that requires temporary storage with very high IOPS for a cache. The data does not need to persist if the instance is stopped.

Which storage type is MOST appropriate?

A) Amazon EBS gp3
B) Amazon EBS io2
C) EC2 Instance Store
D) Amazon EFS

### Question 45
A company needs to migrate a large Oracle database to AWS. They want to use a fully managed service and are willing to refactor the application. They need high performance, automatic scaling, and MySQL compatibility.

Which migration path should the architect recommend?

A) Migrate to Amazon RDS for Oracle
B) Migrate to Amazon Aurora MySQL using AWS Schema Conversion Tool (SCT) and Database Migration Service (DMS)
C) Install Oracle on Amazon EC2
D) Migrate to Amazon DynamoDB

### Question 46
A web application needs to serve different content based on the user's country. The architect wants to minimize latency for all users globally.

Which combination of services provides this?

A) Amazon CloudFront with Lambda@Edge to customize responses based on the CloudFront-Viewer-Country header
B) Multiple EC2 instances in different regions with Route 53 simple routing
C) A single ALB with geolocation rules
D) Amazon S3 with different buckets per country

### Question 47
A company processes large CSV files (5 GB each) uploaded to S3. A Lambda function is triggered by S3 events to process the file. The processing consistently times out.

Which solution should the architect recommend?

A) Increase the Lambda timeout to 15 minutes
B) Increase the Lambda memory to 10 GB
C) Use S3 multipart upload to split the file and trigger separate Lambda invocations, or use AWS Step Functions to orchestrate processing, or switch to ECS/Fargate for the heavy processing
D) Use S3 Transfer Acceleration

### Question 48
A company needs a database for a gaming application. The database must handle millions of requests per second with single-digit millisecond latency. The data model is key-value based.

Which database service is MOST appropriate?

A) Amazon RDS for MySQL
B) Amazon Aurora
C) Amazon DynamoDB
D) Amazon Redshift

### Question 49
A company runs an application that requires a shared POSIX-compliant file system accessible from multiple Linux EC2 instances across different Availability Zones. The application uses a Linux-based file locking mechanism.

Which storage service meets these requirements?

A) Amazon EBS with Multi-Attach
B) Amazon EFS
C) Amazon FSx for Windows File Server
D) Amazon S3 with s3fs

### Question 50
An application uses Amazon RDS PostgreSQL. During peak hours, the database CPU utilization reaches 90% due to complex analytical queries running alongside OLTP transactions.

Which solution addresses this with MINIMAL application changes?

A) Vertically scale the RDS instance
B) Create a read replica and direct analytical queries to the replica
C) Migrate to DynamoDB
D) Add an ElastiCache layer

### Question 51
A company has a three-tier application where the web tier receives 10,000 requests per second. Each request results in a database query. The database is becoming a bottleneck. Most queries (80%) are read operations that return the same data.

Which solution MOST effectively reduces database load?

A) Add more web tier instances
B) Scale up the database instance
C) Implement Amazon ElastiCache between the web tier and database tier to cache read results
D) Add an SQS queue between the web and database tiers

### Question 52
A company needs to process video transcoding jobs. Each job takes 20-40 minutes. The workload is unpredictable — sometimes there are 5 jobs, sometimes 500. The company needs a cost-effective compute solution that automatically scales.

Which compute solution should the architect recommend?

A) A fixed fleet of EC2 On-Demand instances
B) AWS Lambda functions
C) Amazon ECS on Fargate with auto scaling
D) A single large EC2 instance

### Question 53
A solutions architect needs to improve the performance of an API backed by Lambda functions. The Lambda functions connect to an RDS database. Under high load, the database runs out of connections because each Lambda invocation opens a new connection.

Which solution addresses this?

A) Increase the RDS instance size to support more connections
B) Use Amazon RDS Proxy to pool and share database connections
C) Reduce the Lambda concurrency limit
D) Switch to DynamoDB

---

## Domain 4: Design Cost-Optimized Architectures (Questions 54-65)

### Question 54
A company has a workload that runs on EC2 instances. The workload is steady and predictable during weekdays but drops to near zero on weekends. The company wants to minimize costs while ensuring capacity during weekdays.

Which combination of purchase options is MOST cost-effective?

A) Use On-Demand instances for all capacity
B) Use Reserved Instances (or Savings Plans) for the baseline weekday capacity and On-Demand for any additional peaks
C) Use Spot Instances for all capacity
D) Use Reserved Instances for 24/7 capacity including weekends

### Question 55
A company stores data in S3 that is accessed unpredictably. Some months the data is heavily accessed, other months it is barely touched. The company wants to minimize costs without managing storage classes manually.

Which S3 storage class is MOST cost-effective?

A) S3 Standard
B) S3 Standard-IA
C) S3 Intelligent-Tiering
D) S3 One Zone-IA

### Question 56
A company wants to reduce costs on their NAT Gateway. They are currently paying $300/month in NAT Gateway data processing charges because EC2 instances in private subnets access S3 and DynamoDB frequently.

Which change would reduce these costs the MOST?

A) Replace the NAT Gateway with a NAT Instance
B) Create VPC Gateway Endpoints for S3 and DynamoDB (which are free) so that traffic no longer goes through the NAT Gateway
C) Move EC2 instances to public subnets
D) Compress data before sending to S3

### Question 57
A company runs a development environment that mirrors production. The production environment uses m5.2xlarge instances (8 vCPU, 32 GB RAM). The development team only needs the instances during business hours and does not need production-level performance.

Which approach minimizes development costs? (Select TWO)

A) Use smaller instance types (e.g., m5.large or t3.large) for development
B) Schedule instances to stop outside of business hours
C) Use the same m5.2xlarge instances as production
D) Use Dedicated Hosts for development
E) Run development on Reserved Instances with 3-year commitments

### Question 58
A company has a data lake in S3 with 100 TB of data. They run Athena queries against this data daily. The Athena costs are high because queries scan large amounts of data.

Which TWO strategies would reduce Athena query costs? (Select TWO)

A) Convert data to columnar format (Parquet or ORC) to reduce the amount of data scanned
B) Increase the number of S3 buckets
C) Partition data by commonly filtered columns (e.g., date, region) so queries only scan relevant partitions
D) Use S3 Transfer Acceleration
E) Move data to Amazon Redshift

### Question 59
A company wants to compare the total cost of running a workload on different EC2 instance families (m5, c5, r5) to find the most cost-effective option for their workload profile.

Which AWS tool provides instance type recommendations based on actual utilization data?

A) AWS Pricing Calculator
B) AWS Compute Optimizer
C) AWS Cost Explorer
D) AWS Trusted Advisor

### Question 60
A company has a web application that serves images. The images are stored in S3 and served directly to users. The company is paying high S3 data transfer (egress) costs because of global user traffic.

Which change reduces data transfer costs?

A) Move images to EBS volumes
B) Use Amazon CloudFront with S3 as the origin — CloudFront has lower data transfer rates and caches content at edge locations
C) Use S3 Transfer Acceleration
D) Use S3 Requester Pays

### Question 61
A company runs a stateless web application on EC2 instances behind an ALB. Traffic patterns are unpredictable with occasional spikes. The company wants to minimize costs while handling traffic spikes.

Which compute strategy is MOST cost-effective?

A) Use a fixed number of large On-Demand instances
B) Use an Auto Scaling group with a mix of On-Demand instances for the baseline and Spot Instances for additional capacity
C) Use only Spot Instances
D) Use Reserved Instances sized for peak capacity

### Question 62
A company stores 500 TB of archival data that must be retained for 10 years. The data is accessed approximately once per year, and the company can tolerate a retrieval time of up to 12 hours.

Which S3 storage class is MOST cost-effective?

A) S3 Standard
B) S3 Glacier Flexible Retrieval
C) S3 Glacier Deep Archive
D) S3 Standard-IA

### Question 63
A company uses AWS Lambda functions extensively. Each function invocation takes an average of 200ms and uses 256 MB of memory. The company notices that increasing memory to 512 MB reduces execution time to 100ms.

Which configuration is MORE cost-effective?

A) 256 MB memory at 200ms — less memory is always cheaper
B) 512 MB memory at 100ms — Lambda charges for GB-seconds, so the total cost is the same but the function runs faster, improving user experience. If the reduction in time is proportionally greater than the increase in memory, it can actually be cheaper.
C) Use the maximum 10 GB memory for all functions
D) Memory allocation has no effect on cost

### Question 64
A company uses Amazon RDS with a Multi-AZ deployment for high availability. They also have a read replica for read traffic. The company is looking to reduce database costs.

If the read replica is no longer needed because read traffic has decreased, which action saves the MOST money?

A) Delete the read replica — read replicas incur separate instance charges
B) Convert the read replica to a Multi-AZ standby
C) Stop the read replica
D) Reduce the read replica instance size to the smallest available

### Question 65
A startup is building a new application. They are unsure about the traffic patterns and want to avoid over-provisioning. The application uses API Gateway, Lambda, and DynamoDB.

Why is this architecture inherently cost-optimized for unpredictable workloads?

A) These services are always free
B) All three services support pay-per-use pricing — API Gateway charges per request, Lambda charges per invocation and duration, and DynamoDB on-demand mode charges per read/write request. There is no cost when there is no traffic.
C) AWS provides free tier credits that cover all costs
D) Serverless is always cheaper than EC2

---

# Answer Key and Explanations

## Domain 1: Design Secure Architectures

**Question 1: B**
NACLs support explicit deny rules (security groups do not — they can only allow). A NACL rule with a lower number (higher priority) to deny 10.0.5.0/24 will block that traffic before a broader allow rule. Security groups (A) cannot deny — they are allow-only. WAF (C) works at the application layer. Route table blackholes (D) do not work for traffic within a VPC.

**Question 2: B**
IAM roles with instance profiles provide temporary, automatically rotated credentials with zero operational effort. IAM users (A) require manual key rotation. Secrets Manager (C) adds complexity. STS AssumeRole (D) requires the application to manage the assume-role logic.

**Question 3: A**
Secrets Manager is designed for secrets with automatic rotation — ideal for database passwords. Parameter Store (standard) is free and suitable for non-sensitive configuration. Using Parameter Store for passwords (B) lacks native automatic rotation for RDS credentials. KMS (C) manages encryption keys, not secrets. Secrets Manager for both (D) works but costs more than needed for simple config values.

**Question 4: B**
AWS WAF supports rate-based rules to throttle bots and IP set rules to block known bad IPs. Shield (A) protects against DDoS, not bot scraping. GuardDuty (C) detects threats but does not block traffic. Security groups (D) do not support rate limiting.

**Question 5: B**
VPC Gateway Endpoints for DynamoDB are free and keep traffic within the AWS network. NAT Gateway (A) costs money. Interface Endpoints (C) work but cost per hour and per GB. A proxy (D) adds complexity and cost.

**Question 6: B**
Resource-based policies allow cross-account access without assuming a role, meaning users keep their existing permissions. When assuming a role (A), the user temporarily gives up their original permissions and takes on the role's permissions. Shared credentials (C) are insecure. Organizations (D) do not directly share S3 buckets.

**Question 7: D**
Client-side encryption means the data is encrypted before it reaches S3. Even with S3 bucket access, the encrypted ciphertext is useless without KMS key access. SSE-S3 (A) and SSE-KMS (B) encrypt server-side — someone with S3 read permissions could potentially decrypt. SSE-C (C) requires the customer to provide the key with each request.

**Question 8: C**
Shield Advanced provides DDoS protection, access to the DDoS Response Team (DRT), and cost protection (credits for scaling charges during an attack). WAF (A) protects at Layer 7 but does not provide DRT access. Shield Standard (B) is free and automatic but has no DRT or cost protection. GuardDuty (D) is threat detection, not DDoS protection.

**Question 9: B**
S3 Object Lock in Compliance mode prevents anyone, including root, from deleting objects during the retention period. Governance mode (C) allows users with special permissions to override. Versioning (A) preserves versions but does not prevent deletion. Bucket policies (D) can be modified by root.

**Question 10: A**
Security groups are the most appropriate for this use case — they are stateful (return traffic is automatic), operate at the instance level, and can reference other security groups. NACLs (B) are stateless and more complex. While using both (C) is a valid defense-in-depth approach, security groups alone are the most appropriate and simplest answer. WAF (D) does not work between internal tiers.

**Question 11: C**
Amazon Macie uses machine learning to discover, classify, and protect sensitive data in S3, specifically PII. GuardDuty (A) detects threats. Inspector (B) assesses EC2 vulnerabilities. Config (D) tracks configuration.

**Question 12: B**
Forcing SSL on RDS PostgreSQL encrypts data in transit. Encryption at rest (A, D) protects stored data, not data in transit. A VPN (C) is unnecessary for traffic within a VPC.

**Question 13: B**
VPC Interface Endpoints (PrivateLink) provide private access to Secrets Manager without internet. Gateway Endpoints (C) only exist for S3 and DynamoDB. It is not true that Secrets Manager requires internet (A). You cannot peer with an AWS service VPC (D).

**Question 14: A**
AWS Config rules evaluate compliance, and automatic remediation using SSM Automation documents can fix non-compliant resources. Trusted Advisor (B) does not auto-remediate. CloudWatch/Lambda (C) could work but requires custom development. S3 events (D) do not cover all scenarios.

**Question 15: B**
AWS Direct Connect provides a dedicated, private physical connection. VPN (A) traverses the public internet (encrypted). Client VPN (C) is for individual users. Transit Gateway (D) is for connecting VPCs and on-premises networks but is not the connection itself.

**Question 16: C**
VPC Gateway Endpoints for S3 allow private subnet instances to access S3 without internet. Public IPs (A) expose instances to the internet. NAT Gateway (B) works but costs money. S3 is a regional service, not AZ-specific (D).

**Question 17: B**
AWS KMS manages encryption keys, supports key policies for access control, and integrates with CloudTrail for auditing. CloudHSM (A) gives more control but is significantly more complex and expensive. Secrets Manager (C) stores secrets, not encryption keys. ACM (D) manages TLS certificates.

**Question 18: B**
Cognito User Pools natively support social identity providers (Google, SocialGraph, Apple, Amazon). Identity Pools (A) are for granting AWS credentials, not authentication. Cognito Sync (C) is for data sync. IAM Identity Center (D) is for workforce identity.

**Question 19: A**
ACM provides free public SSL/TLS certificates that auto-renew and integrate directly with ALB. Self-signed certs (B) are not trusted by browsers. Third-party certs (C) cost money and require manual renewal. CloudHSM (D) is for custom key management.

**Question 20: C**
Private subnets have no route to an internet gateway. Without a public IP and a route to an internet gateway, the instance cannot be reached from the internet. While SGs (A) or NACLs (B) could also block traffic, the fundamental issue is the lack of routing and public IP.

---

## Domain 2: Design Resilient Architectures

**Question 21: B**
SQS FIFO queues guarantee exactly-once processing and ordering. Standard queues (A) provide at-least-once delivery and best-effort ordering. Kinesis (C) preserves order within a shard but does not guarantee exactly-once processing natively. SNS (D) is pub/sub, not a queue.

**Question 22: B**
Kinesis Data Streams handles real-time data ingestion at scale (2 GB/sec requires multiple shards). SQS (A) is for message queuing, not real-time streaming. SNS (C) is pub/sub. IoT Core (D) is for IoT device connectivity.

**Question 23: B**
Aurora Global Database replicates data to secondary regions with typically less than 1-second lag for low-latency reads globally. Local read replicas (A) only help in the same region. Multi-AZ (C) is for availability within a region. Serverless (D) is for auto-scaling compute, not global distribution.

**Question 24: B**
RDS Cross-Region Read Replicas provide a read-only copy in another region and serve as DR target. Multi-AZ (A) is only within a single region. Automated backups with cross-region copy (C) support DR but not read traffic. DMS (D) could work but is more complex than a native read replica.

**Question 25: C**
Kinesis supports multiple independent consumers (including enhanced fan-out) reading the same data in order. SQS Standard (A) does not preserve order. SQS FIFO (B) preserves order but a message is consumed by only one consumer. SNS (D) does fan-out but does not preserve order or allow replay.

**Question 26: A**
CloudFront Origin Failover with an origin group automatically serves content from a secondary origin if the primary fails. S3 CRR (C) replicates data but does not provide automatic failover at the CloudFront level. Route 53 (D) works for domain-level failover but not for specific CloudFront origins.

**Question 27: C**
Amazon MQ is a managed message broker supporting MQTT, AMQP, STOMP, and OpenWire — directly compatible with RabbitMQ and ActiveMQ. SQS (A) and SNS (B) use AWS-proprietary protocols. Kinesis (D) is for data streaming.

**Question 28: B**
Dead-letter queues capture messages that fail processing after a configurable number of attempts, preventing them from blocking other messages. Increasing visibility timeout (A) just delays the retry. FIFO (C) does not solve processing failures. Long polling (D) reduces empty receives.

**Question 29: B**
Scheduled scaling proactively adjusts capacity before the predictable spike. Target tracking (A) and step scaling (C) are reactive. Increasing cooldown (D) slows scaling.

**Question 30: D**
Multi-site active-active provides near-zero RTO and zero RPO because both sites are actively serving traffic. Backup/restore (A) has the longest RTO. Pilot light (B) requires time to scale up. Warm standby (C) is close but cannot achieve sub-minute RTO for zero RPO as effectively.

**Question 31: B**
EventBridge supports complex event pattern matching and content-based routing to diverse targets. SNS filtering (A) supports basic attribute filtering but is less flexible. SQS (C) does not route. Lambda (D) requires custom code.

**Question 32: B, C**
The health check grace period (B) tells Auto Scaling to wait before checking health on new instances. ALB health check thresholds (C) ensure the health check does not pass until the application is truly ready. Increasing the interval to 300s (A) is too aggressive and delays detecting real failures. Deregistration delay (D) is for removing instances, not adding. Zero cooldown (E) could cause rapid scaling oscillations.

**Question 33: B**
Aurora supports automatic failover, up to 15 read replicas (vs 5 for RDS MySQL), and auto-scaling storage up to 128 TB. RDS Multi-AZ (A, C) only supports 5 read replicas for MySQL. Aurora Serverless (D) supports auto-scaling compute but the question does not require that feature and it does not necessarily support all 15 replicas in all configurations.

**Question 34: B**
FSx for Windows File Server supports SMB protocol natively and is compatible with Windows applications. EFS (A) supports NFS (Linux). S3 (C) is object storage, not a file system. EBS Multi-Attach (D) only works with io1/io2 in a single AZ.

**Question 35: B**
SQS subscription to SNS ensures messages are durably stored even if processing fails. Lambda (A) has a 15-minute timeout limit and 10-minute processing would be risky. HTTP endpoints (C) can fail without retry guarantees. Message attributes (D) do not provide retry logic.

**Question 36: B**
With 3 AZs and a minimum of 6 instances, you need 9 total (3 per AZ). If one AZ is lost, the remaining 2 AZs each have 3 instances, giving you 6 — meeting the minimum. With only 6 instances (A), losing an AZ leaves only 4.

**Question 37: B**
DynamoDB Global Tables provide multi-region, multi-active replication with local read and write capabilities. Streams with Lambda (A) is a custom solution and more complex. Cross-region read replicas (C) do not exist as a native DynamoDB feature. DMS (D) is a migration tool.

---

## Domain 3: Design High-Performing Architectures

**Question 38: A, B**
Sticky sessions (A) ensure the user stays on the same instance. Externalizing sessions to ElastiCache (B) is the better long-term solution — it allows any instance to serve any user. NLB (C) does not solve session persistence at the application level. Instance size (D) and placement groups (E) are irrelevant.

**Question 39: B**
Global Accelerator supports TCP and UDP protocols and provides two static Anycast IPs. CloudFront (A) is primarily for HTTP/HTTPS. Route 53 (C) does not provide static IPs for applications. ELB with EIPs (D) is regional only.

**Question 40: B**
DAX caches frequently read items and absorbs the read traffic for hot keys, reducing throttling on the underlying table. Increasing RCUs (A) helps broadly but does not address hot partitions specifically. RDS (C) is a different database type. Streams (D) are for change data capture, not read distribution.

**Question 41: B**
ElastiCache for Redis with cache-aside pattern works with any database, including relational databases with joins. DAX (A) is only for DynamoDB. CloudFront (C) caches HTTP responses. S3 (D) is not a caching solution.

**Question 42: B**
ALB operates at Layer 7 and supports WebSocket, path-based routing, host-based routing, and HTTP/2. NLB (A) operates at Layer 4 and does not support path-based routing. Classic LB (C) is legacy. Gateway LB (D) is for third-party appliances.

**Question 43: B**
Redis Sorted Sets provide O(log N) operations for ranking and can return top-N results with sub-millisecond latency. DynamoDB with GSI (A) works but has higher latency. RDS (C) requires query execution. Redshift (D) is for analytics, not real-time.

**Question 44: C**
Instance Store provides the highest IOPS with directly attached storage. Data is ephemeral — lost when the instance stops. EBS gp3 (A) and io2 (B) provide persistence, which is not needed. EFS (D) is network-attached and higher latency.

**Question 45: B**
Aurora MySQL with SCT for schema conversion and DMS for data migration is the recommended managed path. RDS for Oracle (A) does not move away from Oracle licensing costs. EC2 Oracle (C) adds operational overhead. DynamoDB (D) is a completely different database paradigm.

**Question 46: A**
CloudFront with Lambda@Edge can inspect the CloudFront-Viewer-Country header and serve customized content at the edge with low latency. Multiple EC2 instances (B) with simple routing does not route by country. ALB (C) is regional. Multiple S3 buckets (D) requires complex routing.

**Question 47: C**
Lambda has a 15-minute timeout (A is technically possible but 5 GB files may not process in time). The best approach is to split processing or use a longer-running compute service like ECS/Fargate. Lambda memory increase (B) helps CPU but not necessarily duration for I/O-bound work. Transfer Acceleration (D) is for uploads to S3.

**Question 48: C**
DynamoDB provides single-digit millisecond latency at any scale for key-value data. RDS (A) and Aurora (B) are relational and have higher latency at extreme scale. Redshift (D) is for analytics.

**Question 49: B**
Amazon EFS is a managed NFS file system that is POSIX-compliant, supports file locking, and spans multiple AZs. EBS Multi-Attach (A) only works in a single AZ with io1/io2. FSx for Windows (C) uses SMB, not NFS. S3 with s3fs (D) is not truly POSIX-compliant.

**Question 50: B**
Read replicas offload analytical queries with minimal application changes — just point analytical queries to the replica endpoint. Scaling up (A) is expensive. DynamoDB (C) requires a redesign. ElastiCache (D) caches results but does not help with complex analytical queries that change.

**Question 51: C**
ElastiCache caches the 80% repeated reads, reducing database load by up to 80%. More web instances (A) increases database load. Scaling the database (B) is expensive. SQS (D) queues requests but does not reduce total query count.

**Question 52: C**
ECS on Fargate scales to zero when idle and scales up automatically. No 15-minute Lambda limit (B) issue with 20-40 minute jobs. Fixed EC2 fleet (A) and single instance (D) waste money during idle periods.

**Question 53: B**
RDS Proxy pools database connections and shares them across Lambda invocations, preventing connection exhaustion. Larger instance (A) only increases the connection limit, not the pooling. Reducing concurrency (C) reduces throughput. DynamoDB (D) requires redesign.

---

## Domain 4: Design Cost-Optimized Architectures

**Question 54: B**
Reserved Instances for the predictable weekday baseline saves ~30-72% on that capacity. On-Demand covers any peaks. Paying for 24/7 Reserved (D) wastes money on weekends. All On-Demand (A) is full price. All Spot (C) is unreliable for production.

**Question 55: C**
Intelligent-Tiering automatically moves objects between frequent and infrequent tiers based on access patterns — ideal for unpredictable access. Standard (A) is expensive for infrequent months. Standard-IA (B) charges retrieval fees during heavy months. One Zone-IA (D) has availability risk.

**Question 56: B**
VPC Gateway Endpoints for S3 and DynamoDB are free and eliminate NAT Gateway data processing charges for that traffic. NAT Instance (A) still has data processing costs. Public subnets (C) expose instances. Compression (D) reduces data volume but does not eliminate NAT costs.

**Question 57: A, B**
Smaller instances (A) reduce hourly costs. Scheduling (B) eliminates costs during non-business hours. Same instance sizes (C) is wasteful. Dedicated Hosts (D) increase costs. 3-year RIs (E) are long commitments for dev environments that may change.

**Question 58: A, C**
Columnar formats (A) reduce data scanned because Athena only reads needed columns. Partitioning (C) reduces data scanned because Athena only scans relevant partitions. More buckets (B) does not help. Transfer Acceleration (D) is unrelated. Redshift (E) could help but moves away from the serverless Athena model.

**Question 59: B**
Compute Optimizer analyzes actual CloudWatch utilization metrics and recommends optimal instance types. Pricing Calculator (A) estimates costs for known configurations. Cost Explorer (C) analyzes historical spending. Trusted Advisor (D) provides general recommendations.

**Question 60: B**
CloudFront caches content at edge locations and charges lower data transfer rates than S3 direct egress. EBS (A) is not for static content serving. Transfer Acceleration (C) is for uploads. Requester Pays (D) shifts cost to the requester but does not reduce rates.

**Question 61: B**
A mix of On-Demand for baseline and Spot for bursts provides the best cost/reliability balance. Fixed On-Demand (A) is expensive. All Spot (C) is unreliable. Reserved for peak (D) wastes money during non-peak.

**Question 62: C**
S3 Glacier Deep Archive is the lowest-cost storage class and supports retrieval within 12 hours (standard retrieval). Standard (A) is most expensive. Glacier Flexible Retrieval (B) is more expensive than Deep Archive. Standard-IA (D) is for less infrequent access.

**Question 63: B**
Lambda charges for GB-seconds. 256 MB x 200ms = 51,200 MB-ms. 512 MB x 100ms = 51,200 MB-ms. The cost is identical, but the function runs twice as fast, improving user experience. If the time reduction is proportionally greater, it can even save money. Maximum memory (C) is wasteful. Memory absolutely affects cost (D is wrong).

**Question 64: A**
Deleting the unused read replica eliminates its separate instance charges. You cannot convert a replica to standby (B). You cannot stop a read replica (C) — only the primary. Reducing size (D) saves money but not as much as deleting.

**Question 65: B**
Serverless services with pay-per-use pricing mean zero cost at zero traffic, making them ideal for unpredictable workloads. They are not always free (A). Free tier is limited (C). Serverless is not always cheaper at scale (D) — but for unpredictable, potentially low-traffic workloads, pay-per-use avoids over-provisioning.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Focus: Commonly Confused Topics
- Domain 1: Design Secure Architectures (Questions 1-20)
- Domain 2: Design Resilient Architectures (Questions 21-37)
- Domain 3: Design High-Performing Architectures (Questions 38-53)

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
