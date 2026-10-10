# Practice Exam 3 — Full 65-Question SAA-C03 Simulation

## Difficulty: HARD — Multi-Service Architectures & Tricky Scenarios

**Time Limit:** 130 minutes
**Passing Score:** 72% (47/65)
**Target Score:** 80%+ (53/65)

This is the most difficult of the three practice exams. It focuses on multi-service architecture decisions, cost optimization trade-offs, "least operational overhead" nuances, migration scenarios, and hybrid architectures. If you score 75%+ on this exam, you are well-prepared for the real SAA-C03.

**Domain Weighting:**
- Domain 1: Design Secure Architectures — Questions 1-20 (30%)
- Domain 2: Design Resilient Architectures — Questions 21-37 (26%)
- Domain 3: Design High-Performing Architectures — Questions 38-53 (24%)
- Domain 4: Design Cost-Optimized Architectures — Questions 54-65 (20%)

---

## Domain 1: Design Secure Architectures (Questions 1-20)

### Question 1
A company is building a multi-account architecture using AWS Organizations. They want to ensure that no account can create IAM users with console access — all human access must go through AWS IAM Identity Center (SSO). They also want to prevent accounts from leaving the organization.

Which combination of SCPs achieves this? (Select TWO)

A) An SCP that denies iam:CreateUser and iam:CreateLoginProfile
B) An SCP that denies organizations:LeaveOrganization
C) An SCP that denies sts:AssumeRole
D) An SCP attached to the management account to restrict IAM users
E) An SCP that denies iam:CreateAccessKey only

### Question 2
A company stores encrypted data in S3 using SSE-KMS. A partner company in a different AWS account needs read access to specific objects. The partner should be able to decrypt the objects.

Which combination of steps is required? (Select THREE)

A) Grant s3:GetObject permission to the partner's IAM principal via an S3 bucket policy
B) Grant kms:Decrypt permission to the partner's IAM principal via the KMS key policy
C) Share the KMS key's raw key material with the partner
D) Ensure the partner's IAM policy allows s3:GetObject and kms:Decrypt
E) Create an S3 Access Point for the partner account
F) Disable SSE-KMS encryption on the objects first

### Question 3
A healthcare application processes patient records and must comply with HIPAA. The application stores data in Amazon RDS (PostgreSQL) and Amazon S3. Data must be encrypted at rest and in transit. All access to patient data must be logged.

Which combination meets ALL HIPAA requirements? (Select THREE)

A) Enable RDS encryption with a KMS CMK
B) Enable S3 default encryption with SSE-KMS
C) Force SSL connections on RDS by setting rds.force_ssl = 1
D) Use S3 Standard-IA storage class for cost savings (this automatically handles HIPAA)
E) Enable CloudTrail to log all S3 and RDS API calls
F) Store data in public S3 buckets with ACLs restricting access

### Question 4
A company has a VPC with CIDR 10.0.0.0/16. They establish VPC peering with a partner's VPC (172.16.0.0/16). The partner also has a VPC peered with a third company (192.168.0.0/16). The company wants to reach the third company's VPC through the partner's VPC.

Is this possible? Why or why not?

A) Yes — VPC peering supports transitive routing
B) No — VPC peering does not support transitive routing. The company must create a direct peering connection with the third company or use AWS Transit Gateway.
C) Yes — if the partner configures their route tables correctly
D) No — VPC peering only works within the same AWS account

### Question 5
A Lambda function processes data from an SQS queue and needs to write results to a DynamoDB table in a different AWS account (Account B). The Lambda function runs in Account A.

Which approach implements this cross-account access with LEAST privilege?

A) Create an IAM user in Account B, generate access keys, and hardcode them in the Lambda function
B) Create an IAM role in Account B with DynamoDB write permissions and a trust policy for Account A's Lambda execution role. Have the Lambda function assume this role using STS.
C) Make the DynamoDB table public
D) Create a VPC peering connection between the two accounts

### Question 6
A company is deploying a new application. The security team requires that all EC2 instances have the SSM Agent installed and can be managed via AWS Systems Manager Session Manager instead of SSH. They want to eliminate the need for SSH key management and close port 22 entirely.

Which steps are required? (Select TWO)

A) Open port 22 in the security group for Systems Manager to work
B) Attach an IAM role with the AmazonSSMManagedInstanceCore policy to the EC2 instances
C) Ensure the EC2 instances can reach the Systems Manager endpoints (via NAT Gateway, VPC endpoints, or internet)
D) Install a VPN client on all EC2 instances
E) Configure a bastion host in a public subnet

### Question 7
An application running on ECS Fargate in a private subnet needs to pull container images from Amazon ECR. The security team does not allow any internet access from the private subnet.

Which solution enables ECR access without internet?

A) Configure a NAT Gateway
B) Create VPC Interface Endpoints for ECR (ecr.api, ecr.dkr) and S3 Gateway Endpoint (ECR stores image layers in S3)
C) Move the Fargate tasks to a public subnet
D) Copy container images to a local Docker registry on an EC2 instance

### Question 8
A company needs to encrypt an existing unencrypted RDS MySQL database with minimal downtime. The database is 500 GB and serves a production application.

Which approach minimizes downtime?

A) Enable encryption on the existing instance through the RDS console modify option
B) Create a read replica, enable encryption on the read replica, promote the read replica, and switch the application endpoint
C) Create an encrypted snapshot of the unencrypted instance, restore to a new encrypted instance, and switch the application during a maintenance window
D) Use AWS DMS to migrate data from the unencrypted instance to a new encrypted instance with minimal downtime

### Question 9
A company has an S3 bucket that must never be made public. Even if someone accidentally changes the bucket policy or ACL, public access must remain blocked.

Which feature provides this protection?

A) S3 Versioning
B) S3 Block Public Access settings at the account level
C) S3 Object Lock
D) IAM policies denying s3:PutBucketPolicy

### Question 10
A company uses AWS CloudTrail for auditing. A security engineer discovers that someone disabled CloudTrail in one region, and the activity was not detected for two weeks.

Which solution prevents this from happening again?

A) Enable CloudTrail log file validation
B) Create a CloudWatch Events (EventBridge) rule that triggers on CloudTrail StopLogging API calls and sends an SNS notification
C) Enable VPC Flow Logs
D) Enable AWS Config with a rule to check CloudTrail status, and use an SNS notification for non-compliance

### Question 11
A company needs to implement single sign-on (SSO) for their workforce to access multiple AWS accounts. They use Microsoft Active Directory on-premises.

Which AWS service integrates with their existing AD for multi-account SSO?

A) Amazon Cognito
B) AWS IAM Identity Center (successor to AWS SSO) with AD Connector or AWS Managed Microsoft AD
C) IAM federation with SAML 2.0 in each account
D) AWS Directory Service Simple AD

### Question 12
A company has a web application that accepts file uploads. They want to allow users to upload files directly to S3 from their browser without routing the upload through the application server, while still maintaining security controls.

Which approach is MOST secure and efficient?

A) Make the S3 bucket public and let users upload directly
B) Generate pre-signed S3 URLs on the application server and return them to the client for direct upload to S3
C) Have the application server accept the upload and then transfer it to S3
D) Use S3 Transfer Acceleration with public write access

### Question 13
A company runs a microservices architecture on ECS. Each microservice needs its own set of secrets (database credentials, API keys). The security team requires that secrets are encrypted at rest, rotated automatically, and accessible only to the specific microservice that needs them.

Which solution meets all requirements?

A) Store secrets in environment variables in the ECS task definition
B) Store each microservice's secrets in AWS Secrets Manager with separate secrets per service, enable automatic rotation, and grant access via IAM task roles specific to each ECS service
C) Store all secrets in a single AWS Systems Manager Parameter Store SecureString parameter
D) Store secrets in an encrypted S3 bucket accessible by all microservices

### Question 14
A company needs to ensure that data stored in Amazon EFS is encrypted at rest and in transit. The EFS file system already exists with data.

Which statements are TRUE? (Select TWO)

A) Encryption at rest can be enabled on an existing EFS file system
B) Encryption at rest must be enabled at file system creation — you must create a new encrypted EFS and migrate data
C) Encryption in transit is enabled by mounting the file system using the EFS mount helper with the TLS option
D) Encryption in transit requires modifying the EFS file system settings
E) EFS does not support encryption

### Question 15
A solutions architect is designing a system where EC2 instances in a VPC need to access both Amazon S3 and Amazon DynamoDB without sending traffic over the internet.

Which is the MOST cost-effective solution?

A) Create VPC Interface Endpoints for both S3 and DynamoDB
B) Create VPC Gateway Endpoints for both S3 and DynamoDB
C) Use a NAT Gateway for both services
D) Create a VPC Interface Endpoint for S3 and a Gateway Endpoint for DynamoDB

### Question 16
A company needs to protect their CloudFront distribution so that only authenticated users can access premium video content. The authentication system uses a custom authorization service.

Which CloudFront feature should the architect use?

A) CloudFront signed URLs or signed cookies
B) CloudFront Origin Access Control
C) AWS WAF on the CloudFront distribution
D) S3 bucket policies

### Question 17
A company is migrating from on-premises to AWS. They have a strict requirement that certain workloads must run on hardware that is NOT shared with any other AWS customer.

Which EC2 option satisfies this requirement?

A) Reserved Instances
B) Dedicated Instances
C) Dedicated Hosts
D) Placement Groups

### Question 18
An application needs to validate incoming API requests against a custom authorization logic that checks user permissions in a database before allowing the request to proceed.

Which API Gateway feature should the architect use?

A) API Gateway usage plans
B) API Gateway Lambda authorizer (custom authorizer)
C) API Gateway IAM authorization
D) API Gateway API keys

### Question 19
A company has a hybrid architecture with workloads both on-premises and in AWS. They need a DNS solution that allows on-premises systems to resolve AWS private hosted zone DNS names and allows AWS resources to resolve on-premises DNS names.

Which service enables this bidirectional DNS resolution?

A) Amazon Route 53 public hosted zones
B) Amazon Route 53 Resolver with inbound and outbound endpoints
C) AWS Direct Connect
D) A custom DNS server on an EC2 instance

### Question 20
A company operates in the EU and must comply with GDPR. They need to ensure that all customer data processing and storage occurs only within the EU (Frankfurt region — eu-central-1). No data should be replicated to or processed in any other region.

Which combination of controls enforces this? (Select TWO)

A) Use an SCP to deny all actions in regions other than eu-central-1
B) Use S3 bucket policies to deny cross-region replication
C) Enable AWS Config rules to detect resources created outside eu-central-1
D) Use Amazon Macie to scan for data outside the EU
E) Disable all other regions in the AWS account settings

---

## Domain 2: Design Resilient Architectures (Questions 21-37)

### Question 21
A company runs a critical application with an RTO of 15 minutes and an RPO of 1 minute. The application uses Amazon Aurora MySQL, EC2 Auto Scaling groups, and an ALB. The primary region is us-east-1.

Which DR strategy meets these requirements?

A) Backup and restore — take Aurora snapshots every hour and store AMIs in another region
B) Pilot light — run Aurora Global Database in us-west-2, launch EC2 instances from AMIs during failover
C) Warm standby — run Aurora Global Database in us-west-2 with a scaled-down Auto Scaling group and ALB in us-west-2
D) Multi-site active-active — run full production in both regions

### Question 22
A company has a monolithic application that they want to decouple into microservices. The application currently has a component that sends emails after an order is placed. The email sending frequently fails, causing the entire order process to fail.

Which architecture change addresses this?

A) Retry the email sending with exponential backoff in the monolith
B) Decouple the email service: publish an event to an SNS topic or SQS queue when an order is placed, and have a separate service consume the event and send the email
C) Use a larger EC2 instance to handle email sending
D) Send emails synchronously with a longer timeout

### Question 23
A company has an application that uses Auto Scaling with target tracking set to maintain 60% CPU utilization. During a sudden traffic spike, the application experiences degraded performance for 5 minutes before new instances are ready.

Which combination of strategies addresses this? (Select TWO)

A) Use predictive scaling based on historical traffic patterns to pre-provision capacity
B) Decrease the target CPU utilization to 40% to maintain more headroom
C) Use warm pools to keep pre-initialized instances ready to launch quickly
D) Switch to manual scaling
E) Use larger instances to eliminate the need for scaling

### Question 24
A media company processes video uploads. Each video is uploaded to S3, which triggers a Lambda function that adds a processing job to an SQS queue. A fleet of EC2 instances processes the jobs. Some videos are high priority and must be processed before standard videos.

Which solution handles priority processing?

A) Use a single SQS queue and set message priorities
B) Use two separate SQS queues (high-priority and standard). Configure the processing fleet to poll the high-priority queue first.
C) Use SQS FIFO queue to ensure ordered processing
D) Increase the processing fleet size to process all videos faster

### Question 25
A company operates a ride-sharing application. The application stores ride data in DynamoDB and needs to trigger downstream processes (billing, notifications, analytics) whenever a new ride record is written.

Which DynamoDB feature enables this event-driven pattern?

A) DynamoDB Global Tables
B) DynamoDB Streams with Lambda triggers
C) DynamoDB On-Demand Backup
D) DynamoDB Transaction APIs

### Question 26
A company runs a web application on EC2 instances. During deployment, they want to perform blue-green deployments to minimize risk and allow instant rollback.

Which AWS service simplifies blue-green deployments?

A) AWS CodeDeploy with a blue/green deployment type and an ALB to shift traffic
B) AWS CodePipeline alone
C) Manual deployment by terminating old instances and launching new ones
D) AWS CloudFormation stack updates with UpdatePolicy

### Question 27
A company has a three-tier application (web, app, database) running in a single AZ. They need to redesign for high availability. The database is PostgreSQL.

Which architecture provides the HIGHEST availability with the LEAST operational overhead?

A) Deploy EC2 instances in multiple AZs with Auto Scaling, use Amazon Aurora PostgreSQL with Multi-AZ, and an ALB
B) Deploy EC2 instances in multiple AZs, use RDS PostgreSQL Single-AZ with automated backups
C) Deploy EC2 instances in a single AZ with Auto Scaling, use Aurora PostgreSQL
D) Use Elastic Beanstalk in a single AZ with RDS Multi-AZ

### Question 28
A company is designing an architecture that uses Amazon S3 as the primary data store. Objects range from 1 KB to 5 TB. Some objects are modified frequently. The company needs to protect against accidental deletion and overwrites while maintaining access to previous versions.

Which S3 feature should be enabled?

A) S3 Object Lock
B) S3 Versioning
C) S3 Cross-Region Replication
D) S3 Lifecycle Policies

### Question 29
A company has an application that receives webhook notifications from a third-party service. The webhooks arrive in bursts of thousands per minute. The backend processing takes 30 seconds per webhook and cannot be scaled quickly.

Which architecture absorbs the burst while ensuring all webhooks are processed?

A) Receive webhooks directly in the backend application and scale up
B) Use API Gateway to receive webhooks, push them to an SQS queue, and have the backend process messages from the queue at its own rate
C) Use an ALB to distribute webhooks across multiple backend instances
D) Drop excess webhooks during bursts

### Question 30
A company runs an application with an Auto Scaling group behind an ALB. The instances boot from a custom AMI. The company recently updated the AMI but found that the Auto Scaling group still launches instances with the old AMI.

What must the company do to use the new AMI?

A) Terminate all existing instances — Auto Scaling will launch new ones with the new AMI
B) Update the Launch Template (or create a new version) with the new AMI ID, and update the Auto Scaling group to use the new Launch Template version
C) Auto Scaling automatically detects new AMIs
D) Update the ALB to point to the new AMI

### Question 31
A company uses Amazon Aurora MySQL for a global e-commerce platform. During a regional outage in us-east-1, they need to promote the Aurora Global Database secondary in eu-west-1 to a standalone cluster. After the us-east-1 region recovers, they want to fail back.

What is the correct procedure?

A) Aurora automatically fails over and fails back
B) Manually promote the secondary to standalone during outage, then when us-east-1 recovers, recreate the Global Database with eu-west-1 as primary and add us-east-1 as a new secondary
C) Use RDS Multi-AZ — it handles failover automatically
D) Restore from a backup in us-east-1

### Question 32
An application uses S3 event notifications to trigger Lambda functions for processing. During high-upload periods, some events are lost because Lambda throttling causes S3 to drop notifications.

Which solution ensures no events are lost?

A) Increase Lambda reserved concurrency
B) Configure S3 event notifications to send to an SQS queue, then configure Lambda to poll the SQS queue (SQS event source mapping). SQS retains messages if Lambda is throttled.
C) Use S3 batch operations
D) Enable S3 versioning

### Question 33
A company has an on-premises application that uses a file share (NFS). They want to migrate to AWS but some on-premises applications still need access to the files during the migration period.

Which AWS service provides a hybrid storage solution?

A) Amazon EFS with AWS Direct Connect
B) AWS Storage Gateway (File Gateway) — provides on-premises NFS access backed by S3
C) Amazon S3 with s3fs
D) AWS DataSync

### Question 34
A company runs a web application across multiple regions. They need to route traffic to the healthy, lowest-latency region. If all endpoints in a region are unhealthy, traffic should go to the next best region.

Which Route 53 configuration achieves this?

A) Weighted routing policy
B) Failover routing policy with two records
C) Latency-based routing policy with health checks enabled on each record
D) Geoproximity routing policy

### Question 35
A company has an SQS FIFO queue processing orders. They notice that processing throughput is limited to 300 transactions per second.

Which feature increases FIFO throughput?

A) Switch to a Standard queue
B) Enable high-throughput mode for the FIFO queue, which supports up to 3,000 messages per second per API action with batching
C) Create multiple FIFO queues and distribute messages
D) Increase the message visibility timeout

### Question 36
A company uses AWS Step Functions to orchestrate a multi-step data processing workflow. One step occasionally fails due to a transient error from a downstream service.

Which Step Functions feature handles transient failures?

A) Use a Catch block to redirect to a failure state
B) Configure retry policies with exponential backoff on the failing step
C) Increase the timeout for the step
D) Remove the failing step from the workflow

### Question 37
A company has an application that stores files in Amazon S3. The company wants to implement a lifecycle policy that transitions objects to different storage classes based on age: frequently accessed for the first 30 days, then infrequently accessed, then archived after 90 days.

However, they also want the option for objects that are never accessed to be moved to the infrequent tier earlier than 30 days.

Which approach meets both requirements?

A) Use only S3 Lifecycle rules — transition to Standard-IA at 30 days and Glacier at 90 days
B) Use S3 Intelligent-Tiering as the storage class (which automatically moves objects to infrequent access after 30 days of no access) combined with a lifecycle rule to move to Glacier at 90 days
C) Use S3 Analytics to manually determine access patterns
D) Create a Lambda function to move objects between storage classes

---

## Domain 3: Design High-Performing Architectures (Questions 38-53)

### Question 38
A company runs an API backend on Lambda functions behind API Gateway. The Lambda functions connect to an RDS MySQL database. Under load, the application experiences intermittent database connection errors. Monitoring shows that RDS has available connections, but Lambda invocations spike and overwhelm the connection pool.

Which solution addresses this with MINIMAL code changes?

A) Increase the RDS instance size to support more connections
B) Implement connection pooling in the Lambda function code
C) Deploy Amazon RDS Proxy between Lambda and RDS to manage connection pooling
D) Switch to DynamoDB

### Question 39
A company needs to run a machine learning training job that requires 8 GPUs and 640 GB of memory. The job runs for approximately 4 hours.

Which EC2 instance type is designed for this workload?

A) R5.24xlarge (memory optimized)
B) P4d.24xlarge or similar GPU instance (accelerated computing)
C) C5.24xlarge (compute optimized)
D) M5.24xlarge (general purpose)

### Question 40
A company has an application that uses ElastiCache for Redis as a session store. The cluster currently has a single node. The company needs to implement high availability and automatic failover.

Which ElastiCache for Redis deployment provides this?

A) ElastiCache for Redis single node with automated backups
B) ElastiCache for Redis cluster mode disabled with Multi-AZ and automatic failover (primary + replica)
C) ElastiCache for Memcached with auto-discovery
D) ElastiCache for Redis with a larger single node

### Question 41
A gaming company stores player state data in DynamoDB. A single player item can be updated hundreds of times per second by concurrent game servers. The company wants to maintain an accurate counter of player actions without losing updates.

Which DynamoDB feature handles this?

A) DynamoDB conditional writes
B) DynamoDB atomic counters (using UpdateItem with ADD)
C) DynamoDB transactions
D) DynamoDB Streams

### Question 42
A company has a data lake stored in S3. They use Amazon Athena for ad-hoc SQL queries. Query performance is slow when scanning large Parquet files. The queries typically filter on a "date" column and a "region" column.

Which TWO optimizations improve query performance? (Select TWO)

A) Partition the data in S3 by date and region (e.g., s3://bucket/data/date=2024-01/region=us-east-1/)
B) Convert from Parquet to CSV format
C) Use Athena workgroups with different engine versions
D) Use columnar compression (Snappy or GZIP) within the Parquet files
E) Store all data in a single large Parquet file

### Question 43
A company operates a globally distributed application. They want to direct user traffic to the closest AWS Region while also using custom health checks that validate application-level functionality (not just TCP connectivity).

Which combination of services achieves this?

A) AWS Global Accelerator with custom health checks
B) Route 53 latency-based routing with health checks that perform HTTPS string matching on the response body
C) CloudFront with multiple origins
D) An ALB with cross-region load balancing

### Question 44
A company runs a real-time analytics application that ingests data from Kinesis Data Streams. The application must process each record within 200 milliseconds of arrival. There are 5 different consumer applications that each need to independently read every record.

Which Kinesis feature enables this?

A) Kinesis Client Library (KCL) with shared throughput
B) Kinesis Enhanced Fan-Out — each consumer gets a dedicated 2 MB/sec throughput per shard with push-based delivery
C) Multiple Kinesis streams for each consumer
D) Kinesis Data Firehose

### Question 45
A company has a REST API that returns JSON responses. The same API response is requested thousands of times per second. The response changes at most once per minute.

Which solution provides the BEST performance at LOWEST cost?

A) Scale the backend API servers horizontally
B) Place Amazon API Gateway with caching enabled in front of the API, with a cache TTL of 60 seconds
C) Use CloudFront to cache API responses with a 60-second TTL
D) Use ElastiCache to cache responses and have clients query ElastiCache directly

### Question 46
A company runs a batch data pipeline that reads 10 TB of data from S3, processes it using Apache Spark, and writes results back to S3. The pipeline runs daily and takes 3 hours.

Which AWS service should the architect recommend for the LEAST operational overhead?

A) Amazon EMR on EC2 instances
B) Amazon EMR on EKS
C) AWS Glue (which runs Spark jobs serverlessly)
D) Apache Spark on EC2 instances managed by the company

### Question 47
A company has an application with a write-heavy DynamoDB table. The write pattern includes occasional bursts that exceed the provisioned write capacity, causing throttling.

Which DynamoDB feature handles this MOST effectively without over-provisioning?

A) DynamoDB on-demand capacity mode
B) DynamoDB auto scaling with a high target utilization
C) DynamoDB reserved capacity
D) DynamoDB DAX

### Question 48
A company needs to transfer 10 PB of data from their on-premises data center to AWS S3. They have a 10 Gbps Direct Connect link. The transfer must be completed within 3 months.

Which solution is MOST efficient?

A) Use AWS DataSync over the Direct Connect link
B) Use AWS Snowball Edge devices (multiple in parallel)
C) Use AWS Snowmobile
D) Use S3 multipart upload over the Direct Connect link

### Question 49
A company runs a containerized application on ECS with Fargate. The application needs to process 50,000 short-lived tasks (each taking ~30 seconds) per day. Tasks arrive in bursts.

Which ECS configuration MINIMIZES cost?

A) Run tasks on Fargate with auto scaling
B) Run tasks on Fargate Spot for up to 70% cost savings (tasks are short-lived and can be retried if interrupted)
C) Run tasks on EC2 with Reserved Instances
D) Run tasks on a single large Fargate task

### Question 50
A company needs to perform full-text search across millions of documents stored in S3. The search must support fuzzy matching, relevance scoring, and faceted search.

Which AWS service provides this capability?

A) Amazon RDS with SQL LIKE queries
B) Amazon OpenSearch Service (successor to Amazon Elasticsearch Service)
C) Amazon DynamoDB with a Global Secondary Index
D) Amazon Athena with SQL queries

### Question 51
A solutions architect needs to design a multi-region architecture for a time-sensitive financial application. The application must have sub-100ms read latency globally and must handle 100,000 reads per second.

Which database solution meets these requirements?

A) Amazon RDS Multi-AZ with cross-region read replicas
B) Amazon DynamoDB Global Tables
C) Amazon Aurora Global Database
D) Amazon ElastiCache Global Datastore

### Question 52
A company processes IoT sensor data. Each sensor sends 1 KB messages every second. There are 10,000 sensors. The data must be ingested, processed in near-real-time, and stored in S3 for batch analytics.

Which architecture handles this at scale?

A) API Gateway -> Lambda -> S3
B) IoT Core -> Kinesis Data Streams (sufficient shards for 10 MB/s) -> Kinesis Data Firehose -> S3, with Kinesis Data Analytics for near-real-time processing
C) IoT Core -> SQS -> EC2 -> S3
D) Direct S3 PutObject from each sensor

### Question 53
A company runs a SQL Server database on-premises with a 2 TB data warehouse. They want to migrate to AWS and use a fully managed service. They need to continue using SQL Server-specific features (SSRS, SSIS, linked servers).

Which migration option supports these SQL Server-specific features?

A) Amazon RDS for SQL Server
B) Amazon Aurora
C) Amazon Redshift
D) SQL Server on Amazon EC2 (provides full OS-level access to install and configure all SQL Server features including SSRS, SSIS, linked servers)

---

## Domain 4: Design Cost-Optimized Architectures (Questions 54-65)

### Question 54
A company runs a production web application on m5.xlarge On-Demand instances (4 vCPU, 16 GB RAM). AWS Compute Optimizer shows that the instances average 10% CPU utilization and 30% memory utilization.

Which action reduces costs the MOST?

A) Switch to Reserved Instances for the same instance type
B) Right-size by moving to m5.large (2 vCPU, 8 GB RAM) or t3.large and then consider Savings Plans
C) Move to Spot Instances
D) Add more instances to distribute the load

### Question 55
A company has a data processing pipeline: files are uploaded to S3, a Lambda function is triggered, processes the file, and writes results to DynamoDB. The Lambda function runs for an average of 60 seconds with 1 GB memory. There are 1 million invocations per month.

A developer proposes moving the processing to an always-running t3.medium EC2 instance (~$30/month). The Lambda cost at 1 million invocations x 60s x 1 GB is approximately $1,000/month.

Should the company switch to EC2?

A) No — Lambda is always cheaper than EC2
B) Yes — for this specific workload profile (high invocations, long duration), EC2 is significantly cheaper. Lambda is cost-effective for short, infrequent invocations, but for sustained high-volume, long-running workloads, EC2 can be more cost-effective.
C) No — EC2 requires a VPC which adds costs
D) Yes — EC2 is always cheaper than Lambda

### Question 56
A company archives compliance documents in S3 Glacier Deep Archive. Occasionally (once or twice per year), they need to retrieve a specific document. When they retrieve it, they have used the Expedited retrieval option, which costs significantly more.

How can they reduce retrieval costs while still getting documents within an acceptable timeframe?

A) Switch to S3 Standard for all documents
B) Use S3 Glacier Deep Archive Standard retrieval (within 12 hours) instead of Expedited (which is not available for Deep Archive) — or if using Glacier Flexible Retrieval, switch from Expedited to Standard (3-5 hours) or Bulk (5-12 hours) retrieval
C) Use S3 Lifecycle policies to delete old documents
D) Move to S3 Standard-IA

### Question 57
A company uses Amazon Redshift for data warehousing. The cluster runs 24/7 but is only queried during business hours (8 AM - 6 PM). The data is loaded nightly.

Which TWO strategies reduce Redshift costs? (Select TWO)

A) Use Redshift Serverless instead of a provisioned cluster — it automatically scales and charges based on usage
B) Pause the Redshift cluster outside of business hours (automatic or scheduled)
C) Use Reserved Nodes for the Redshift cluster
D) Switch to DynamoDB
E) Delete and recreate the cluster daily

### Question 58
A company has a microservices application where each service runs on a dedicated t3.small EC2 instance. There are 20 microservices, each running on its own instance. Most instances are idle 90% of the time.

Which approach significantly reduces compute costs?

A) Use Reserved Instances for all 20 instances
B) Containerize the microservices and run them on Amazon ECS with Fargate, so resources are shared and you pay only for what you use
C) Move all microservices to a single large EC2 instance
D) Use Spot Instances for all 20 microservices

### Question 59
A company stores data in S3. They use S3 Standard for all data. Analysis shows that 80% of the data has not been accessed in the last 90 days, but the company does not know which specific objects are in this category.

Which feature helps identify infrequently accessed data and recommends storage class changes?

A) S3 Storage Lens
B) S3 Storage Class Analysis
C) S3 Inventory
D) S3 Access Analyzer

### Question 60
A company has a multi-tier application. The web tier (in public subnets) calls the application tier (in private subnets) via an internal ALB. The application tier calls a third-party API on the internet via a NAT Gateway. Monthly NAT Gateway costs are $500 (mostly from application-tier internet calls).

The company wants to reduce NAT Gateway costs. The third-party API offers an AWS PrivateLink endpoint.

What should the architect do?

A) Replace the NAT Gateway with a NAT Instance
B) Use the PrivateLink endpoint for the third-party API to eliminate internet traffic through the NAT Gateway
C) Move the application tier to public subnets
D) Compress data before sending to the third-party API

### Question 61
A company uses On-Demand EC2 instances across multiple instance families (m5, c5, r5) in multiple regions. They want to save costs but need flexibility to change instance types, sizes, and regions.

Which savings option provides the MOST flexibility while still saving costs?

A) EC2 Instance Savings Plans (locked to an instance family in a region)
B) Compute Savings Plans (flexible across instance families, regions, OS, and even Lambda/Fargate)
C) Standard Reserved Instances
D) Convertible Reserved Instances

### Question 62
A company processes 100,000 images per day. Each image processing task takes 10 seconds and is independent. The company currently uses a fleet of c5.xlarge On-Demand instances that are underutilized (average 30% CPU).

Which architecture is MOST cost-effective?

A) Keep the current architecture but use Savings Plans
B) Use AWS Lambda functions (10 seconds is within the timeout; 100,000 invocations x 10 sec x appropriate memory is reasonable for Lambda)
C) Use EC2 Spot Instances
D) Use AWS Batch with Spot Instances

### Question 63
A company is evaluating data transfer costs for their architecture. They have EC2 instances in us-east-1 that transfer data to:
1. An S3 bucket in us-east-1
2. An EC2 instance in eu-west-1
3. Users on the internet

Which data transfer scenario is FREE?

A) EC2 to S3 in the same region (data transfer from EC2 to S3 within the same region is free)
B) EC2 in us-east-1 to EC2 in eu-west-1
C) EC2 to the internet
D) All of the above are free

### Question 64
A company runs a testing environment that is an exact copy of production. Production uses 10 x m5.2xlarge instances. The testing environment is only used 4 hours per day, 5 days per week.

Which is the MOST cost-effective approach for the testing environment?

A) Run the same 10 x m5.2xlarge instances 24/7 with On-Demand pricing
B) Use the same instance types but schedule them to run only 4 hours/day, and consider Spot Instances since testing workloads can tolerate interruption
C) Use Reserved Instances for the testing environment
D) Run testing on t3.micro instances

### Question 65
A solutions architect is designing a multi-tier application. They need to choose between:
- Option A: API Gateway + Lambda + DynamoDB (serverless)
- Option B: ALB + EC2 (Auto Scaling) + RDS MySQL (provisioned)

The application expects low and variable traffic initially but may grow significantly. The company wants to minimize costs while the traffic is low and scale cost-effectively as traffic grows.

Which option is BETTER for the initial low-traffic phase, and why?

A) Option B — EC2 and RDS provide better cost predictability
B) Option A — serverless architecture has near-zero cost at low traffic because you pay per request. With API Gateway, Lambda, and DynamoDB on-demand, the cost approaches zero when there is no traffic. Option B requires minimum running instances and an RDS database 24/7, which costs money even at zero traffic.
C) Both options cost the same at low traffic
D) Option A — but only because Lambda is faster than EC2

---

# Answer Key and Explanations

## Domain 1: Design Secure Architectures

**Question 1: A, B**
An SCP denying iam:CreateUser and iam:CreateLoginProfile (A) prevents IAM console user creation. An SCP denying organizations:LeaveOrganization (B) prevents accounts from leaving. Denying sts:AssumeRole (C) would break all role-based access. SCPs do not apply to the management account (D). Denying only CreateAccessKey (E) still allows console users.

**Question 2: A, B, D**
Three things are needed for cross-account SSE-KMS access: the S3 bucket policy must grant s3:GetObject (A), the KMS key policy must grant kms:Decrypt (B), and the partner's own IAM policy must allow both actions (D). Raw key material should never be shared (C). Access Points (E) are optional. Disabling encryption (F) defeats the purpose.

**Question 3: A, B, C, E (select THREE — best: A, C, E or A, B, E)**
HIPAA requires encryption at rest (A, B), encryption in transit (C), and audit logging (E). S3 storage class (D) has nothing to do with HIPAA. Public buckets (F) violate security requirements. The best three are A (RDS encryption), C (SSL in transit), and E (CloudTrail logging). B is also valid — select the most critical three.

**Question 4: B**
VPC peering is non-transitive. You cannot route from VPC A through VPC B to VPC C. You need either a direct peering connection or AWS Transit Gateway. (A) and (C) are incorrect about transitivity. (D) is wrong — peering works across accounts.

**Question 5: B**
Cross-account access via STS AssumeRole with a role in Account B follows least privilege. Hardcoded keys (A) are insecure. Public DynamoDB tables (C) do not exist. VPC peering (D) does not grant service-level permissions.

**Question 6: B, C**
Session Manager requires the SSM Agent (usually pre-installed on Amazon Linux), an IAM role with SSM permissions (B), and network access to SSM endpoints (C). Port 22 (A) is not needed — that is the whole point. VPN (D) and bastion (E) are unnecessary with Session Manager.

**Question 7: B**
ECR requires Interface Endpoints for ecr.api and ecr.dkr, plus a Gateway Endpoint for S3 (where ECR stores image layers). NAT Gateway (A) provides internet which is explicitly prohibited. Public subnets (C) expose the tasks. Local registry (D) adds operational overhead.

**Question 8: D**
AWS DMS can perform a continuous replication migration with minimal downtime (the source remains operational during migration). You cannot enable encryption on existing instances (A). Read replicas cannot have encryption enabled if the source is unencrypted (B). Snapshot/restore (C) works but requires more downtime than DMS.

**Question 9: B**
S3 Block Public Access at the account level overrides any bucket policy or ACL that would make a bucket public. Versioning (A) protects against deletion, not public access. Object Lock (C) prevents deletion. IAM policies (D) can be changed.

**Question 10: B (and D is also acceptable)**
A CloudWatch Events rule on the StopLogging API call provides immediate alerting. AWS Config (D) also works by checking CloudTrail status continuously. Log file validation (A) ensures log integrity but does not detect disabled trails. VPC Flow Logs (C) are unrelated.

**Question 11: B**
IAM Identity Center integrates with AD Connector or AWS Managed Microsoft AD for multi-account SSO. Cognito (A) is for customer identity. SAML federation (C) per account is more work than centralized SSO. Simple AD (D) does not integrate with on-premises AD.

**Question 12: B**
Pre-signed URLs allow direct, time-limited, authenticated uploads to S3 without making the bucket public. Public buckets (A) are insecure. Proxying through the server (C) wastes bandwidth. Transfer Acceleration with public access (D) is insecure.

**Question 13: B**
Separate Secrets Manager secrets per microservice with automatic rotation and IAM task roles provide least privilege and meet all requirements. Environment variables (A) are not encrypted or rotated. A single parameter (C) gives all services access to all secrets. Shared S3 bucket (D) lacks automatic rotation.

**Question 14: B, C**
EFS encryption at rest must be enabled at creation (B). Encryption in transit is configured at mount time using TLS (C). You cannot enable encryption at rest after creation (A). Encryption in transit is a client-side mount option, not a server setting (D). EFS supports encryption (E is wrong).

**Question 15: B**
Gateway Endpoints for both S3 and DynamoDB are free. Interface Endpoints (A) have hourly charges. NAT Gateway (C) has data processing charges. A mix (D) works but Interface Endpoint for S3 costs money.

**Question 16: A**
Signed URLs/cookies control who can access content and for how long, enabling authenticated access to premium content. OAC (B) controls origin access, not user access. WAF (C) filters requests but does not authenticate users. Bucket policies (D) do not integrate with custom authentication.

**Question 17: C**
Dedicated Hosts provide single-tenant physical servers. Dedicated Instances (B) run on dedicated hardware but you do not control placement and may share the host with your own other instances. Reserved Instances (A) and Placement Groups (D) do not guarantee single-tenant hardware.

**Question 18: B**
Lambda authorizers run custom authorization logic before the API request reaches the backend. Usage plans (A) manage API keys and throttling. IAM auth (C) uses IAM policies, not custom logic. API keys (D) identify callers but do not perform custom authorization.

**Question 19: B**
Route 53 Resolver endpoints enable bidirectional DNS resolution: inbound endpoints resolve private hosted zone names for on-premises clients, outbound endpoints forward queries to on-premises DNS. Direct Connect (C) provides network connectivity but not DNS resolution. Custom DNS (D) is more operational overhead.

**Question 20: A, C (or A, E)**
An SCP denying all actions outside eu-central-1 (A) enforces compute and storage restrictions. Config rules (C) detect non-compliant resources. Disabling regions (E) is also valid but does not cover all global services. Bucket policies (B) only cover S3. Macie (D) discovers data but does not prevent processing.

---

## Domain 2: Design Resilient Architectures

**Question 21: C**
Warm standby with Aurora Global Database provides RPO ~1 second (replication lag) and RTO ~15 minutes (scale up and switch DNS). Backup/restore (A) cannot meet 1-minute RPO. Pilot light (B) might work but scaling up from stopped instances takes longer. Multi-site (D) exceeds requirements and cost.

**Question 22: B**
Decoupling with SQS/SNS ensures the email failure does not impact order processing. The email service can retry independently. Retry in the monolith (A) still couples the components. Larger instance (C) does not fix the coupling. Longer timeout (D) makes it worse.

**Question 23: A, C**
Predictive scaling (A) pre-provisions based on patterns. Warm pools (C) keep pre-initialized instances ready to serve immediately. Lower CPU target (B) helps but wastes resources. Manual scaling (D) cannot react to spikes. Larger instances (E) have the same startup delay.

**Question 24: B**
SQS does not support message priorities natively. Two queues with priority polling is the standard pattern. A single queue (A) cannot prioritize. FIFO (C) is about ordering, not priority. More capacity (D) does not prioritize.

**Question 25: B**
DynamoDB Streams captures item-level changes and can trigger Lambda functions for downstream processing. Global Tables (A) is for replication. On-Demand Backup (C) is for backups. Transaction APIs (D) are for ACID transactions.

**Question 26: A**
CodeDeploy supports blue/green deployments with ALB traffic shifting and automatic rollback. CodePipeline (B) orchestrates but does not perform the actual deployment. Manual deployment (C) is error-prone. CloudFormation (D) can do rolling updates but blue/green requires CodeDeploy or manual setup.

**Question 27: A**
Aurora PostgreSQL Multi-AZ with EC2 Auto Scaling across multiple AZs and ALB provides the highest availability with managed services (least overhead). RDS Single-AZ (B) is a single point of failure. Single AZ EC2 (C) fails for EC2 tier. Elastic Beanstalk single AZ (D) is not highly available.

**Question 28: B**
Versioning preserves every version of every object, protecting against accidental deletion and overwrites. Object Lock (A) prevents deletion entirely. CRR (C) is for replication. Lifecycle (D) manages transitions.

**Question 29: B**
API Gateway + SQS acts as a buffer, absorbing bursts while the backend processes at its own rate. Direct processing (A) fails under burst. ALB (C) distributes but does not buffer. Dropping webhooks (D) loses data.

**Question 30: B**
Auto Scaling uses the Launch Template to determine the AMI. You must update the Launch Template with the new AMI ID. Terminating instances (A) will relaunch with the old AMI if the Launch Template is not updated. Auto Scaling does not auto-detect AMI changes (C). ALB does not know about AMIs (D).

**Question 31: B**
Aurora Global Database requires manual promotion of secondaries. After the primary region recovers, you recreate the global configuration with the new primary. Aurora Global Database does not automatically fail back (A). RDS Multi-AZ (C) is regional only. Restoring from backup (D) causes data loss.

**Question 32: B**
SQS between S3 and Lambda acts as a buffer. If Lambda is throttled, messages remain in SQS and are processed later. Increasing concurrency (A) helps but may still throttle. Batch operations (C) are for bulk processing. Versioning (D) is unrelated.

**Question 33: B**
Storage Gateway File Gateway provides on-premises NFS access backed by S3, enabling hybrid access during migration. EFS with Direct Connect (A) works but is more expensive for hybrid. S3 with s3fs (C) is unreliable. DataSync (D) is for one-time or scheduled transfers, not ongoing file access.

**Question 34: C**
Latency-based routing with health checks routes to the lowest-latency healthy endpoint and fails over automatically. Weighted (A) distributes by percentage. Failover (B) supports only two records. Geoproximity (D) routes by geographic bias.

**Question 35: B**
FIFO high-throughput mode supports up to 3,000 messages/second with batching (or 300/second per message group without batching). Standard queue (A) loses ordering guarantees. Multiple FIFO queues (C) add complexity. Visibility timeout (D) does not affect throughput.

**Question 36: B**
Step Functions retry policies with exponential backoff automatically retry transient failures. Catch (A) handles errors but does not retry. Timeout (C) does not retry. Removing the step (D) breaks the workflow.

**Question 37: B**
Intelligent-Tiering automatically moves never-accessed objects to the infrequent tier, while the lifecycle rule handles the 90-day archive to Glacier. Standard lifecycle rules alone (A) only transition by age, not access pattern. Analytics (C) provides recommendations but does not automate. Lambda (D) is custom and operational overhead.

---

## Domain 3: Design High-Performing Architectures

**Question 38: C**
RDS Proxy manages a connection pool shared across all Lambda invocations, preventing connection exhaustion. Larger instance (A) increases the limit but Lambda can still overwhelm it. Lambda connection pooling (B) does not work well because each invocation is independent. DynamoDB (D) requires a redesign.

**Question 39: B**
P-family instances (accelerated computing) provide GPUs for ML training. R-family (A) is memory optimized without GPUs. C-family (C) is compute optimized. M-family (D) is general purpose.

**Question 40: B**
Cluster mode disabled with a replica and Multi-AZ provides automatic failover. A single node (A) has no failover. Memcached (C) does not support replication. A larger node (D) does not provide failover.

**Question 41: B**
Atomic counters (ADD operation) handle concurrent updates without losing data. Conditional writes (A) may fail under high concurrency. Transactions (C) add overhead for a simple counter. Streams (D) capture changes but do not solve concurrent updates.

**Question 42: A, D**
Partitioning by commonly filtered columns (A) reduces data scanned. Compression (D) reduces the amount of data read from S3. CSV (B) is worse than Parquet. Workgroups (C) manage settings, not performance. Single large file (E) prevents parallelism.

**Question 43: B**
Route 53 latency-based routing directs to the closest healthy region. HTTPS string matching health checks validate application-level functionality. Global Accelerator (A) supports health checks but not complex string matching. CloudFront (C) caches content, not custom routing. ALB (D) is regional.

**Question 44: B**
Enhanced Fan-Out provides each consumer with its own dedicated 2 MB/sec pipe per shard, with push-based delivery for lower latency. Shared throughput (A) divides bandwidth among consumers. Multiple streams (C) is wasteful. Firehose (D) is for delivery to destinations, not multiple consumers.

**Question 45: C**
CloudFront caches responses globally at edge locations with a 60-second TTL, serving subsequent requests without hitting the backend. API Gateway caching (B) works but does not provide edge caching. Scaling backend (A) is more expensive. Direct ElastiCache access (D) requires custom client-side logic.

**Question 46: C**
AWS Glue runs Spark jobs serverlessly with no cluster management. EMR on EC2 (A) requires cluster management. EMR on EKS (B) requires Kubernetes management. Self-managed Spark (D) has the most overhead.

**Question 47: A**
On-demand capacity mode handles unpredictable bursts automatically without provisioning. Auto scaling (B) has a reaction delay during sudden bursts. Reserved capacity (C) does not handle bursts. DAX (D) is for reads, not writes.

**Question 48: C**
10 PB is best served by Snowmobile (a 45-foot shipping container). At 10 Gbps, DataSync (A) would take ~3 months of continuous transfer — possible but tight. Snowball Edge (B) would require ~125 devices. Multipart upload (D) is limited by bandwidth.

**Question 49: B**
Fargate Spot provides up to 70% savings. With 30-second tasks and SQS for job management, interrupted tasks can be easily retried. Regular Fargate (A) is more expensive. EC2 RIs (C) are overkill for short-lived tasks. Single large task (D) is not how Fargate works.

**Question 50: B**
OpenSearch Service provides full-text search with fuzzy matching, relevance scoring, and faceted search. RDS LIKE (A) is slow and limited. DynamoDB GSI (C) supports exact lookups, not full-text search. Athena (D) is for SQL analytics, not search.

**Question 51: B**
DynamoDB Global Tables provide multi-region active-active with single-digit millisecond latency and massive read throughput. RDS replicas (A) have higher latency. Aurora Global (C) has higher read latency than DynamoDB at 100K reads/sec. ElastiCache Global (D) is for caching, not a primary datastore.

**Question 52: B**
IoT Core for device connectivity, Kinesis Data Streams for high-throughput ingestion (10,000 sensors x 1 KB = 10 MB/s), Firehose for S3 delivery, and Analytics for real-time processing. API Gateway + Lambda (A) has overhead per sensor. SQS (C) adds latency. Direct S3 puts (D) are inefficient for 10,000 concurrent writers.

**Question 53: D**
SQL Server on EC2 provides full OS access for SSRS, SSIS, linked servers, and other SQL Server features not supported by RDS. RDS for SQL Server (A) does not support SSRS or SSIS natively. Aurora (B) does not support SQL Server. Redshift (C) is a data warehouse, not SQL Server.

---

## Domain 4: Design Cost-Optimized Architectures

**Question 54: B**
Right-sizing (reducing from xlarge to large, saving ~50%) plus Savings Plans provides the highest savings. Same-size RIs (A) saves 30-72% on compute but the instances are oversized. Spot (C) is not for production web apps. More instances (D) increases costs.

**Question 55: B**
Lambda costs increase linearly with invocations x duration. At 1M invocations x 60s x 1GB, EC2 is significantly cheaper. Lambda is not always cheaper (A). VPC cost (C) is negligible. EC2 is not always cheaper (D) — it depends on the workload profile.

**Question 56: B**
Standard retrieval from Glacier Flexible Retrieval (3-5 hours) is much cheaper than Expedited. For Deep Archive, Standard retrieval (12 hours) is the only cost-effective option. Moving to Standard (A) is far more expensive for archival data. Deleting (C) violates compliance. Standard-IA (D) is expensive for data accessed once a year.

**Question 57: A, B**
Redshift Serverless (A) eliminates costs when not in use. Pausing the cluster (B) stops compute charges during non-use hours. Reserved Nodes (C) save money but you still pay when idle. DynamoDB (D) is a different database type. Deleting/recreating (E) loses data and is operationally complex.

**Question 58: B**
Containerization on Fargate allows multiple microservices to share compute resources efficiently, and you pay only for what you use. RIs (A) still run 20 underutilized instances. Single instance (C) is a single point of failure. Spot (D) may have interruptions.

**Question 59: B**
S3 Storage Class Analysis monitors access patterns and recommends when to move data to a different storage class. Storage Lens (A) provides account-level metrics. Inventory (C) lists objects. Access Analyzer (D) checks bucket permissions.

**Question 60: B**
Using PrivateLink for the third-party API routes traffic privately, eliminating NAT Gateway data processing charges for that traffic. NAT Instance (A) still has data transfer costs. Public subnets (C) expose the application tier. Compression (D) reduces volume but does not eliminate NAT costs.

**Question 61: B**
Compute Savings Plans offer savings across all instance families, sizes, regions, OS types, and even Fargate/Lambda — maximum flexibility. EC2 Instance Savings Plans (A) lock to a family/region. Standard RIs (C) are the least flexible. Convertible RIs (D) are more flexible than Standard but less flexible than Compute Savings Plans.

**Question 62: B**
Lambda at 100K invocations x 10 sec is approximately $16-20/month (depending on memory), which is much cheaper than EC2 instances. This is a case where the per-invocation model excels — short, independent tasks. Savings Plans (A) reduce EC2 cost but the fleet is underutilized. Spot (C) saves money but still runs underutilized instances. Batch with Spot (D) adds complexity for simple independent tasks.

**Question 63: A**
Data transfer from EC2 to S3 within the same region is free. Cross-region EC2-to-EC2 (B) costs money. Internet egress (C) costs money. Only same-region to S3 is free.

**Question 64: B**
Scheduling for 4 hours/day with Spot Instances saves: scheduling reduces runtime by 83%, and Spot saves up to 90% on the remaining runtime. Full-time On-Demand (A) is the most expensive. RIs (C) still run 24/7. t3.micro (D) may not match the testing requirements.

**Question 65: B**
Serverless (Option A) has near-zero baseline cost: API Gateway, Lambda, and DynamoDB on-demand all charge per request. With low traffic, the cost is negligible. Option B requires a minimum ALB ($16/month), at least one EC2 instance (~$30-75/month), and an RDS instance (~$25-100/month) running 24/7 even with zero traffic. At low traffic, serverless is dramatically cheaper.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Difficulty: HARD — Multi-Service Architectures & Tricky Scenarios
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
