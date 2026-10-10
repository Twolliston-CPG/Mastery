# Practice Exam 1 — Full 65-Question SAA-C03 Simulation

**Time Limit:** 130 minutes
**Passing Score:** 72% (47/65)
**Target Score:** 80%+ (53/65)

**Domain Weighting:**
- Domain 1: Design Secure Architectures — Questions 1-20 (30%)
- Domain 2: Design Resilient Architectures — Questions 21-37 (26%)
- Domain 3: Design High-Performing Architectures — Questions 38-53 (24%)
- Domain 4: Design Cost-Optimized Architectures — Questions 54-65 (20%)

**Instructions:**
- Select ONE answer unless the question says "select TWO" or "select THREE"
- Read every option before selecting
- Flag questions you are unsure about and come back to them
- Do NOT spend more than 2-3 minutes on any single question

---

## Domain 1: Design Secure Architectures (Questions 1-20)

### Question 1
A company stores sensitive customer data in Amazon S3. The security team requires that all objects be encrypted at rest using keys that the company manages and rotates annually. The company wants to minimize operational overhead.

Which solution meets these requirements?

A) Enable S3 default encryption with SSE-S3 and configure a bucket policy to deny unencrypted uploads
B) Enable S3 default encryption with SSE-KMS using an AWS managed key (aws/s3)
C) Enable S3 default encryption with SSE-KMS using a customer managed key (CMK) with automatic rotation enabled
D) Enable S3 default encryption with SSE-C and store encryption keys in AWS Secrets Manager

### Question 2
A solutions architect is designing a multi-tier web application. The web tier runs on Amazon EC2 instances behind an Application Load Balancer (ALB). The application must ensure that traffic between the ALB and EC2 instances is encrypted. The EC2 instances must not be directly accessible from the internet.

Which combination of steps meets these requirements? (Select TWO)

A) Place the EC2 instances in a public subnet and assign them Elastic IP addresses
B) Place the EC2 instances in a private subnet
C) Configure the ALB to use HTTPS listeners with an ACM certificate and set the target group protocol to HTTPS
D) Configure a security group on the EC2 instances to allow inbound traffic from 0.0.0.0/0 on port 443
E) Configure a security group on the EC2 instances to allow inbound HTTPS traffic only from the ALB security group

### Question 3
An application running on Amazon EC2 instances needs to read objects from an S3 bucket and write messages to an SQS queue. A solutions architect must implement this access following the principle of least privilege.

Which approach should the solutions architect use?

A) Create an IAM user with an access key, grant S3 read and SQS write permissions, and store the access key on the EC2 instances
B) Create an IAM role with policies granting S3 read and SQS write permissions, and attach the role to the EC2 instances using an instance profile
C) Create an IAM role with the AdministratorAccess managed policy and attach it to the EC2 instances
D) Store S3 and SQS credentials in AWS Systems Manager Parameter Store and have the application retrieve them at startup

### Question 4
A company has a VPC with public and private subnets across two Availability Zones. The company needs to allow instances in the private subnet to access the internet for software updates while preventing inbound connections from the internet.

Which solution meets these requirements with the HIGHEST availability?

A) Deploy a single NAT instance in one public subnet. Update route tables for both private subnets to point to the NAT instance.
B) Deploy a NAT Gateway in one public subnet. Update route tables for both private subnets to point to the NAT Gateway.
C) Deploy a NAT Gateway in each public subnet. Update each private subnet route table to point to the NAT Gateway in the same Availability Zone.
D) Configure an internet gateway and update the private subnet route tables to point directly to it.

### Question 5
A company must ensure that all API calls made to AWS services are logged and stored in a tamper-proof manner for compliance auditing. The logs must be retained for 7 years.

Which solution meets these requirements?

A) Enable AWS CloudTrail in all regions with a trail that logs to an S3 bucket. Enable S3 Object Lock in compliance mode with a 7-year retention period.
B) Enable VPC Flow Logs and store them in Amazon CloudWatch Logs with a 7-year retention policy
C) Enable AWS Config and store configuration snapshots in an S3 bucket with a lifecycle policy
D) Enable CloudTrail and send logs to CloudWatch Logs. Set the log group retention to 7 years.

### Question 6
A web application uses Amazon Cognito for user authentication. The application requires that users verify their email address before they can sign in. After signing in, users must be able to access specific S3 objects based on their user ID.

Which combination of Cognito features accomplishes this? (Select TWO)

A) Use a Cognito User Pool with email verification enabled during sign-up
B) Use a Cognito Identity Pool to provide temporary AWS credentials scoped to the user's prefix in S3
C) Use a Cognito User Pool to directly grant IAM permissions to S3
D) Store user credentials in a DynamoDB table and look them up during authentication
E) Use Amazon Cognito Sync to synchronize S3 object access across devices

### Question 7
A company wants to protect its web application hosted on Amazon EC2 instances behind an Application Load Balancer from common web exploits such as SQL injection and cross-site scripting (XSS) attacks.

Which AWS service should the solutions architect recommend?

A) Amazon GuardDuty
B) AWS Shield Standard
C) AWS WAF
D) Amazon Inspector

### Question 8
A solutions architect needs to grant a third-party auditing company temporary access to the company's AWS account. The access should expire after 1 hour, and the auditor should only be able to view resources — not modify them.

Which approach is MOST secure?

A) Create an IAM user with the ReadOnlyAccess policy, generate an access key, and share it with the auditor
B) Create a cross-account IAM role with the ReadOnlyAccess policy and a trust policy for the auditor's AWS account. Set the maximum session duration to 1 hour.
C) Share the root account credentials with the auditor temporarily and change the password after 1 hour
D) Create an IAM user with a password that expires after 1 hour and attach the ViewOnlyAccess policy

### Question 9
An application stores database credentials that must be rotated every 30 days. The application runs on AWS Lambda and must retrieve the credentials at runtime. The solution must handle rotation automatically with no application changes.

Which service should the solutions architect use?

A) AWS Systems Manager Parameter Store with a standard parameter
B) AWS Secrets Manager with automatic rotation enabled
C) AWS KMS with key rotation enabled
D) Store the credentials in an environment variable in the Lambda function configuration

### Question 10
A company requires that all Amazon EBS volumes attached to EC2 instances be encrypted. The security team wants to enforce this policy across all regions and receive notifications when a non-compliant resource is detected.

Which solution meets these requirements?

A) Create an SCP in AWS Organizations to deny the ec2:CreateVolume action when encryption is not specified
B) Use AWS Config with the encrypted-volumes managed rule and configure an SNS topic for non-compliant notifications
C) Enable EBS encryption by default in each region and use CloudWatch Events to monitor for unencrypted volumes
D) Use AWS Trusted Advisor to check for unencrypted EBS volumes and send email notifications

### Question 11
A company is migrating to AWS and needs to establish a private, encrypted connection between their on-premises data center and a VPC. They need the connection set up within a few hours.

Which solution meets these requirements?

A) AWS Direct Connect
B) AWS Site-to-Site VPN
C) AWS Direct Connect with a VPN overlay
D) AWS Transit Gateway with peered VPCs

### Question 12
A solutions architect is designing an application where multiple EC2 instances need to access a shared file system. The file system must support NFS protocol, be highly available across multiple Availability Zones, and automatically scale storage capacity.

Which storage solution should the architect recommend?

A) Amazon EBS Multi-Attach with io2 volumes
B) Amazon EFS with Standard storage class
C) Amazon S3 mounted using s3fs
D) Amazon FSx for Windows File Server

### Question 13
A company uses AWS Organizations to manage multiple AWS accounts. The security team wants to prevent any account in the organization from launching EC2 instances in the ap-southeast-1 region while allowing all other actions.

Which solution achieves this?

A) Create an IAM policy in each account that denies ec2:RunInstances in ap-southeast-1
B) Create a Service Control Policy (SCP) that denies ec2:RunInstances with a condition for the ap-southeast-1 region and attach it to the organizational unit
C) Configure AWS Config rules to terminate any EC2 instances launched in ap-southeast-1
D) Use AWS CloudTrail to detect and alert on EC2 launches in ap-southeast-1

### Question 14
A web application receives SSL/TLS certificates from AWS Certificate Manager (ACM). The certificate is used on an Application Load Balancer. The company wants to ensure the certificate is automatically renewed before expiration.

Which statement is correct about ACM certificate renewal?

A) ACM certificates must be manually renewed before expiration
B) ACM certificates used with ALB are automatically renewed by ACM at no additional cost
C) ACM certificates can only be renewed by re-importing them
D) ACM certificates are only automatically renewed if DNS validation was used and the CNAME record still exists

### Question 15
A company stores confidential documents in Amazon S3. They must ensure that objects can only be accessed over HTTPS and never over unencrypted HTTP connections.

Which solution enforces this requirement?

A) Enable S3 Transfer Acceleration on the bucket
B) Create a bucket policy with a condition that denies requests where aws:SecureTransport is false
C) Enable S3 versioning on the bucket
D) Configure the bucket to only allow access from a specific VPC endpoint

### Question 16
An application running in a private subnet needs to call the Amazon S3 API without sending traffic over the internet.

Which solution should the solutions architect implement?

A) Deploy a NAT Gateway in a public subnet and route S3 traffic through it
B) Create a VPC Gateway Endpoint for S3 and update the private subnet route table
C) Create a VPC Interface Endpoint for S3 and configure a private DNS name
D) Configure an internet gateway and add a route from the private subnet

### Question 17
A company wants to detect potential security threats such as cryptocurrency mining on EC2 instances, unauthorized API calls, and compromised IAM credentials. The solution should work automatically with minimal configuration.

Which AWS service provides this capability?

A) AWS Config
B) Amazon Macie
C) Amazon GuardDuty
D) AWS CloudTrail

### Question 18
A solutions architect needs to encrypt data in Amazon RDS for PostgreSQL. The database already exists and contains production data. The company requires that AWS manages the encryption keys.

What should the architect do?

A) Enable encryption on the existing RDS instance by modifying the instance settings
B) Create a snapshot of the existing RDS instance, copy the snapshot with encryption enabled using an AWS managed key, and restore the encrypted snapshot to a new RDS instance
C) Enable Transparent Data Encryption (TDE) on the PostgreSQL instance
D) Use client-side encryption in the application code before writing to the database

### Question 19
A company has multiple VPCs across different regions that need to communicate with each other. They also have an on-premises data center connected via AWS Direct Connect. The company wants to simplify network management and reduce the number of connections.

Which service should the solutions architect recommend?

A) VPC Peering between all VPCs
B) AWS Transit Gateway with inter-region peering
C) AWS PrivateLink between all VPCs
D) A mesh VPN between all VPCs

### Question 20
An application processes credit card payments and must comply with PCI DSS requirements. The cardholder data is stored in Amazon DynamoDB. The application runs on Amazon EC2.

Which combination of security measures should be implemented? (Select TWO)

A) Encrypt DynamoDB tables using AWS-owned keys (the default encryption)
B) Encrypt DynamoDB tables using a customer managed KMS key and enable CloudTrail logging for all DynamoDB API calls
C) Store the EC2 instances in a public subnet to allow PCI compliance scanning
D) Use VPC endpoints for DynamoDB to keep traffic within the AWS network
E) Disable CloudTrail to reduce the attack surface

---

## Domain 2: Design Resilient Architectures (Questions 21-37)

### Question 21
A company runs a critical e-commerce application on Amazon EC2 instances behind an Application Load Balancer. The application uses Amazon RDS MySQL as its database. The company requires the application to recover automatically from the failure of a single Availability Zone.

Which architecture meets this requirement?

A) Deploy EC2 instances in a single AZ with Auto Scaling. Use an RDS Single-AZ instance with automated backups.
B) Deploy EC2 instances across two AZs using an Auto Scaling group. Use an RDS Multi-AZ deployment.
C) Deploy EC2 instances across two AZs with manual scaling. Use an RDS Read Replica in a different AZ.
D) Deploy EC2 instances in a single AZ with a larger instance type. Use an RDS Multi-AZ deployment.

### Question 22
A company needs to design a disaster recovery strategy for their application. The Recovery Time Objective (RTO) is 4 hours, and the Recovery Point Objective (RPO) is 1 hour. The company wants to minimize costs.

Which DR strategy meets these requirements at the LOWEST cost?

A) Multi-site active-active deployment
B) Warm standby with a scaled-down version of the production environment running in another region
C) Pilot light with critical core components running in another region and data replication
D) Backup and restore with regular snapshots stored in another region

### Question 23
An application processes orders asynchronously. When order volume spikes, some orders are lost because the processing servers cannot keep up. The architect needs to ensure no orders are lost and they are processed in the order received.

Which solution addresses this requirement?

A) Use Amazon SQS Standard queue between the order intake and processing tiers
B) Use Amazon SQS FIFO queue between the order intake and processing tiers
C) Use Amazon SNS to fan out orders to multiple processing servers
D) Use Amazon Kinesis Data Streams with a single shard

### Question 24
A company hosts a static website on Amazon S3 with Amazon CloudFront as the CDN. The company wants to ensure that users can only access the S3 content through CloudFront, not directly from the S3 bucket URL.

Which solution implements this restriction?

A) Make the S3 bucket public and use CloudFront signed URLs
B) Use a CloudFront Origin Access Control (OAC) and update the S3 bucket policy to allow access only from the OAC
C) Enable S3 website hosting and use a custom domain name
D) Configure S3 CORS to only allow requests from the CloudFront domain

### Question 25
A solutions architect is designing an application that receives sensor data from thousands of IoT devices. The data must be ingested in real time and made available for immediate analytics. The solution must handle variable throughput.

Which service should the architect use for data ingestion?

A) Amazon SQS
B) Amazon Kinesis Data Streams
C) Amazon SNS
D) Amazon MQ

### Question 26
A company has an application that uses Amazon Aurora MySQL as its database. The application has periods of heavy read traffic. The company wants to improve read performance without modifying the application code significantly.

Which solution should the architect recommend?

A) Increase the instance size of the Aurora primary instance
B) Add Aurora Replicas and use the Aurora reader endpoint in the application
C) Migrate from Aurora to Amazon DynamoDB
D) Enable Multi-AZ on the Aurora cluster

### Question 27
An application stores user session data that must be accessible with sub-millisecond latency. The session data expires after 24 hours. The application runs on multiple EC2 instances across two Availability Zones.

Which storage solution is MOST appropriate?

A) Amazon DynamoDB with TTL enabled
B) Amazon ElastiCache for Redis with Multi-AZ enabled
C) Amazon S3 with lifecycle policies
D) Amazon EBS volumes shared across instances

### Question 28
A company runs a web application that stores uploaded images in Amazon S3. The company recently expanded to a second AWS Region. They need to ensure that images uploaded in either region are available in both regions with minimal delay.

Which S3 feature meets this requirement?

A) S3 Transfer Acceleration
B) S3 Cross-Region Replication (CRR)
C) S3 Same-Region Replication (SRR)
D) S3 Intelligent-Tiering

### Question 29
A solutions architect is designing an architecture for a microservices application. One microservice publishes events that multiple other microservices need to consume independently. Each consumer must receive every event.

Which messaging pattern should the architect implement?

A) Amazon SQS with a single queue read by all consumers
B) Amazon SNS topic with an SQS queue subscription for each consuming microservice
C) Amazon Kinesis Data Streams with one consumer per shard
D) Direct API calls between microservices

### Question 30
A company needs a relational database that can automatically scale storage and compute. The database must support MySQL compatibility and provide up to 15 read replicas. The company wants minimal administrative overhead.

Which database solution meets these requirements?

A) Amazon RDS MySQL with storage autoscaling enabled
B) Amazon Aurora MySQL
C) MySQL installed on Amazon EC2 with EBS autoscaling
D) Amazon DynamoDB (using the PartiQL SQL-compatible interface)

### Question 31
A company hosts a legacy application that requires a fixed IP address. The application runs on an EC2 instance that occasionally fails and must be restarted in the same or a different Availability Zone. The company needs to minimize downtime when the instance fails.

Which solution provides the FASTEST recovery?

A) Use an Elastic IP address associated with the instance. Create a CloudWatch alarm that triggers a Lambda function to reassociate the EIP to a replacement instance.
B) Use a Network Load Balancer with a static IP and register the instance as a target. Use an Auto Scaling group with a minimum of 1 instance.
C) Assign a secondary private IP address that can be moved between instances
D) Use Route 53 with a health check and DNS failover to a standby instance

### Question 32
A company has a batch processing job that runs every night. The job reads from an SQS queue, processes messages, and writes results to S3. Currently, a single EC2 instance processes all messages, but the job does not complete before the next business day.

Which solution scales the processing while maintaining cost efficiency?

A) Use a larger EC2 instance type
B) Deploy an Auto Scaling group of EC2 instances that scales based on the SQS ApproximateNumberOfMessagesVisible metric
C) Use multiple Reserved Instances running 24/7
D) Migrate the processing logic to a single, more powerful Lambda function

### Question 33
A solutions architect must design a system where a failure in one component does not cascade to other components. The application has a web tier, an application tier, and a database tier.

Which design principle addresses this requirement?

A) Design for horizontal scaling
B) Design using loosely coupled components with asynchronous messaging between tiers
C) Deploy all tiers on a single large EC2 instance
D) Use synchronous API calls between all tiers with retry logic

### Question 34
A company needs to deploy a globally distributed application. Users should be routed to the nearest healthy endpoint. If an endpoint becomes unhealthy, traffic should automatically failover to the next closest region.

Which Route 53 routing policy should the architect use?

A) Simple routing
B) Weighted routing
C) Latency-based routing with health checks
D) Geolocation routing

### Question 35
A company has an application that writes critical data to Amazon DynamoDB. The company needs to create backups of the DynamoDB table and be able to restore to any point within the last 35 days.

Which DynamoDB feature provides this capability?

A) DynamoDB Streams
B) DynamoDB On-Demand Backup
C) DynamoDB Point-in-Time Recovery (PITR)
D) DynamoDB Global Tables

### Question 36
An application uses an Auto Scaling group behind an Application Load Balancer. During a recent deployment, new instances launched by Auto Scaling were receiving traffic before the application had fully started, causing errors for users.

Which solution prevents this issue?

A) Increase the health check interval on the ALB target group
B) Configure a longer health check grace period on the Auto Scaling group and ensure the ALB health check waits for the application to be ready
C) Decrease the desired capacity of the Auto Scaling group
D) Use a Network Load Balancer instead of an Application Load Balancer

### Question 37
A company has a three-tier application. The web tier and application tier are running on EC2 instances. During peak traffic, the application tier becomes a bottleneck while the web tier handles the load fine. The application tier processes requests synchronously.

Which change will improve the application's resilience and ability to handle peak loads?

A) Vertically scale the application tier instances
B) Introduce an SQS queue between the web tier and the application tier, and add an Auto Scaling group for the application tier
C) Add more web tier instances
D) Move the application tier to the same instances as the web tier

---

## Domain 3: Design High-Performing Architectures (Questions 38-53)

### Question 38
A company is running a high-performance computing (HPC) workload on EC2 instances. The instances need to communicate with each other with the lowest possible network latency.

Which EC2 feature should the architect configure?

A) Enhanced networking with Elastic Network Adapter (ENA)
B) A cluster placement group
C) A spread placement group
D) Multiple Elastic Network Interfaces (ENIs) per instance

### Question 39
An application stores frequently accessed thumbnails that must be served to users worldwide with low latency. The thumbnails are stored in Amazon S3.

Which solution provides the BEST performance for global users?

A) Enable S3 Transfer Acceleration
B) Use Amazon CloudFront with the S3 bucket as the origin
C) Use S3 cross-region replication to buckets in each region
D) Use larger EC2 instances to serve the thumbnails

### Question 40
A company is running a database workload on Amazon EC2. The database requires storage that provides 64,000 IOPS and 1,000 MB/s throughput. The data is critical and must survive the failure of a single disk.

Which EBS volume type meets these requirements?

A) gp3 (General Purpose SSD)
B) io2 Block Express
C) st1 (Throughput Optimized HDD)
D) gp2 (General Purpose SSD)

### Question 41
A company has a DynamoDB table that serves a global application. Users in Europe experience high latency when reading data because the table is in us-east-1. The company needs to provide low-latency reads for European users.

Which solution addresses this?

A) Create a DynamoDB read replica in eu-west-1
B) Enable DynamoDB Accelerator (DAX) in us-east-1
C) Use DynamoDB Global Tables and add a replica table in eu-west-1
D) Use ElastiCache in eu-west-1 to cache DynamoDB data

### Question 42
A solutions architect is designing an application that processes large video files. Users upload videos through an API, and the processing takes 10-15 minutes per video. The processing function needs up to 4 GB of memory and access to temporary storage.

Which compute service is MOST appropriate?

A) AWS Lambda with 10,240 MB memory and /tmp storage
B) Amazon ECS on AWS Fargate
C) Amazon EC2 with Auto Scaling
D) AWS Lambda with a 3-minute timeout

### Question 43
A company wants to accelerate the transfer of large datasets (100 TB) from their on-premises data center to Amazon S3. Their internet connection is 1 Gbps.

Which solution provides the FASTEST transfer?

A) Use AWS DataSync over the existing internet connection
B) Use S3 multipart upload over the internet connection
C) Order an AWS Snowball Edge device
D) Set up a Direct Connect connection and use DataSync

### Question 44
An application queries a PostgreSQL database for reporting. The same complex queries are run frequently and the results rarely change. Query execution takes 30 seconds, causing poor user experience.

Which caching solution would provide the MOST improvement?

A) Amazon ElastiCache for Redis to cache query results
B) Amazon DynamoDB Accelerator (DAX)
C) CloudFront caching
D) EC2 instance store for local caching

### Question 45
A company is streaming clickstream data from its website. The data arrives at a rate of 5,000 records per second, with each record being 1 KB. The data must be available for real-time analytics and also stored for long-term analysis.

Which architecture handles this requirement?

A) Amazon SQS queue feeding into Amazon RDS
B) Amazon Kinesis Data Streams for ingestion, with Kinesis Data Firehose to deliver data to S3 and Kinesis Data Analytics for real-time processing
C) Amazon SNS topic feeding Lambda functions that write to DynamoDB
D) Direct writes to Amazon Redshift from the website

### Question 46
A company needs to run a memory-intensive application on EC2. The application requires 512 GB of RAM and performs in-memory data processing.

Which EC2 instance family is MOST appropriate?

A) C-family (compute optimized)
B) R-family (memory optimized)
C) T-family (burstable)
D) M-family (general purpose)

### Question 47
A web application serves static assets (images, CSS, JavaScript) alongside dynamic API responses. The static assets rarely change, while the API responses change with every request.

Which CloudFront configuration provides the BEST performance?

A) Set a single cache behavior with a TTL of 0 for all content
B) Create separate cache behaviors: long TTL for static assets (e.g., /images/*, /css/*) and short or no caching for API paths (e.g., /api/*)
C) Disable CloudFront caching entirely and serve all content directly from the origin
D) Use a single cache behavior with a long TTL for all content

### Question 48
A company runs an OLAP (Online Analytical Processing) workload that requires running complex SQL queries across petabytes of structured data. The data is loaded nightly from various sources.

Which AWS service is MOST appropriate?

A) Amazon RDS for PostgreSQL
B) Amazon Aurora
C) Amazon Redshift
D) Amazon DynamoDB

### Question 49
An application uses Amazon S3 to store objects. The application needs to list and retrieve thousands of objects per second with consistent performance. Some object keys follow a sequential pattern based on timestamps.

Which S3 design provides the BEST performance?

A) Use sequential key names for easy sorting
B) S3 automatically handles high request rates (3,500 PUT/5,500 GET per second per prefix), so no special action is needed — but distribute reads across multiple prefixes if needed
C) Use a single prefix for all objects
D) Store all objects in a single S3 bucket with versioning enabled

### Question 50
A company has an on-premises application that requires a consistent, low-latency connection to AWS resources. The application cannot tolerate the variability of internet-based connections. The company needs the connection set up within 2 weeks.

Which solution should the architect recommend initially, with a long-term plan?

A) Use AWS Site-to-Site VPN initially, then migrate to AWS Direct Connect
B) Use AWS Direct Connect from the start
C) Use AWS Client VPN
D) Use a third-party SD-WAN solution

### Question 51
A Lambda function needs to access resources inside a VPC (an RDS database in a private subnet). The Lambda function also needs to call an external third-party API on the internet.

What must be configured?

A) Place the Lambda function in the VPC's private subnet, and configure a NAT Gateway in the public subnet for internet access
B) Place the Lambda function in the VPC's public subnet
C) Lambda functions cannot be placed in a VPC
D) Place the Lambda function in the VPC and use a VPC endpoint for all external API calls

### Question 52
A company wants to improve the performance of their global application. Users in Asia experience slow response times connecting to the application running in us-east-1. The application uses both TCP and UDP protocols.

Which service should the architect use to improve performance?

A) Amazon CloudFront
B) AWS Global Accelerator
C) Amazon Route 53 latency-based routing
D) AWS Direct Connect

### Question 53
A company needs to process messages from an SQS queue using Lambda functions. Each message takes approximately 5 minutes to process. The company wants to maximize throughput.

Which configuration achieves this?

A) Set the Lambda timeout to 5 minutes and let Lambda's SQS event source mapping manage concurrency automatically with a batch size of 1
B) Set the Lambda timeout to 15 minutes and process all messages in a single Lambda invocation
C) Use EC2 instances instead of Lambda to process messages
D) Set the Lambda timeout to 1 minute and retry failed messages

---

## Domain 4: Design Cost-Optimized Architectures (Questions 54-65)

### Question 54
A company runs production EC2 instances 24/7 for a workload that will continue for at least 3 years. The workload is steady-state and predictable. The company wants the MOST cost-effective pricing option.

Which purchase option provides the GREATEST cost savings?

A) On-Demand Instances
B) Spot Instances
C) 3-year All Upfront Reserved Instances (or 3-year Compute Savings Plan)
D) 1-year No Upfront Reserved Instances

### Question 55
A company stores 50 TB of log files in Amazon S3. The logs are frequently accessed during the first 30 days, rarely accessed between 30-90 days, and almost never accessed after 90 days. The company must retain all logs for 7 years for compliance.

Which S3 lifecycle configuration minimizes costs?

A) Store all logs in S3 Standard permanently
B) Start in S3 Standard, transition to S3 Standard-IA after 30 days, transition to S3 Glacier Flexible Retrieval after 90 days, and transition to S3 Glacier Deep Archive after 365 days
C) Store all logs in S3 Glacier Deep Archive from day 1
D) Start in S3 Standard, transition to S3 One Zone-IA after 30 days, then delete after 90 days

### Question 56
A development team runs EC2 instances for testing purposes. The instances are only needed during business hours (8 AM to 6 PM, Monday through Friday). The instances are currently running 24/7.

Which solution reduces costs the MOST?

A) Use Reserved Instances for the development workload
B) Use AWS Instance Scheduler or Amazon EventBridge rules to start instances at 8 AM and stop them at 6 PM on weekdays
C) Migrate to smaller instance types
D) Use Spot Instances for the development workload

### Question 57
A data analytics team runs batch processing jobs that are fault-tolerant and can be interrupted. The jobs typically take 2-6 hours to complete and can be restarted if interrupted. The team wants to reduce compute costs significantly.

Which EC2 purchase option is MOST cost-effective?

A) On-Demand Instances
B) Spot Instances
C) Reserved Instances
D) Dedicated Hosts

### Question 58
A company wants to understand which AWS services are generating the most cost and identify opportunities for savings. They need cost forecasting and recommendations for right-sizing EC2 instances.

Which combination of AWS tools should they use? (Select TWO)

A) AWS Cost Explorer for cost analysis, forecasting, and Reserved Instance recommendations
B) AWS Trusted Advisor for general best practice checks
C) AWS Compute Optimizer for EC2 right-sizing recommendations
D) Amazon CloudWatch for cost monitoring
E) AWS Config for cost compliance

### Question 59
A company has an application that uses an Amazon RDS Multi-AZ MySQL database. The application performs heavy read operations that are impacting write performance. The company wants to improve performance while minimizing costs.

Which solution should the architect recommend?

A) Upgrade to a larger RDS instance type
B) Create one or more RDS Read Replicas and direct read traffic to the replica endpoint(s)
C) Migrate to Amazon DynamoDB
D) Enable RDS Proxy to manage database connections

### Question 60
A company uses Amazon S3 to host a data lake. They are unsure about the access patterns of different datasets. Some are accessed frequently, some rarely, and patterns change over time.

Which S3 storage class is MOST cost-effective when access patterns are unknown?

A) S3 Standard
B) S3 Standard-IA
C) S3 Intelligent-Tiering
D) S3 One Zone-IA

### Question 61
A company has a serverless application using API Gateway and Lambda. The Lambda function queries a DynamoDB table on every invocation. The same data is queried repeatedly, and the data changes infrequently. The company wants to reduce DynamoDB read costs.

Which solution reduces costs while maintaining low latency?

A) Increase the DynamoDB provisioned read capacity units
B) Enable DynamoDB Accelerator (DAX) to cache frequently read items
C) Use DynamoDB on-demand capacity mode
D) Increase the Lambda function memory allocation

### Question 62
A company transfers 5 TB of data per month from EC2 instances in us-east-1 to the internet. The company wants to reduce data transfer costs.

Which solution could reduce these costs?

A) Use Amazon CloudFront to cache and serve content, reducing the amount of data transferred directly from EC2
B) Move EC2 instances to a different region
C) Use larger EC2 instance types
D) Enable S3 Transfer Acceleration

### Question 63
A company runs a containerized application on Amazon ECS. The application has variable traffic patterns — it is idle for hours and then has sudden bursts of activity. The company wants to minimize costs during idle periods.

Which ECS launch type is MOST cost-effective for this pattern?

A) ECS on EC2 with Reserved Instances
B) ECS on EC2 with On-Demand Instances
C) ECS on AWS Fargate
D) ECS on EC2 with Spot Instances in an Auto Scaling group

### Question 64
A company is evaluating whether to use a NAT Gateway or a NAT Instance. The expected traffic volume is low (under 5 GB per month) and the company prioritizes minimizing costs above all else.

Which option is MORE cost-effective for this use case?

A) NAT Gateway, because it is a managed service
B) NAT Instance on a t3.micro or t4g.nano instance, because it is cheaper for low-traffic scenarios
C) Neither — use a VPC endpoint instead
D) Internet Gateway, because it is free

### Question 65
A company runs a web application that receives consistent traffic. The company uses On-Demand EC2 instances (m5.xlarge) and has been running the same instance types and sizes for over a year. They want to reduce EC2 costs without any changes to instance types or commitment length flexibility.

Which pricing option should the architect recommend?

A) Spot Instances
B) Compute Savings Plans
C) EC2 Instance Savings Plans
D) Standard Reserved Instances with 1-year no upfront

---

# Answer Key and Explanations

## Domain 1: Design Secure Architectures

**Question 1: C**
SSE-KMS with a customer managed key (CMK) allows the company to manage and rotate keys. CMKs support automatic annual rotation. SSE-S3 (A) uses AWS-managed keys the company cannot control. The AWS managed KMS key `aws/s3` (B) does not allow customer-controlled rotation. SSE-C (D) requires the customer to manage keys with every request, which is high operational overhead.

**Question 2: B, C (or B, E)**
The correct answers are **B and E**. EC2 instances must be in a private subnet (B) to prevent direct internet access. The security group should only allow HTTPS from the ALB security group (E), not from the internet. (C) is also valid for encrypting ALB-to-instance traffic but the question focuses on not being directly accessible plus encryption — B and E is the strongest pairing. (A) puts instances in a public subnet. (D) allows all internet traffic.

**Question 3: B**
IAM roles attached via instance profiles follow the principle of least privilege by providing temporary credentials automatically. IAM users with access keys (A) are less secure. AdministratorAccess (C) violates least privilege. Storing credentials in Parameter Store (D) is unnecessary when IAM roles exist.

**Question 4: C**
A NAT Gateway in each AZ provides high availability. If one AZ fails, the other private subnet still has internet access through its own NAT Gateway. A single NAT Gateway (B) is a single point of failure. NAT instances (A) require more management. Private subnets cannot route directly to an internet gateway (D).

**Question 5: A**
CloudTrail logs API calls, and S3 Object Lock in compliance mode prevents deletion or modification (tamper-proof). VPC Flow Logs (B) capture network traffic, not API calls. AWS Config (C) tracks resource configuration, not API calls. CloudWatch Logs (D) does not provide tamper-proof storage.

**Question 6: A, B**
Cognito User Pools handle authentication including email verification (A). Cognito Identity Pools provide temporary AWS credentials that can be scoped per user (B). User Pools do not directly grant IAM permissions (C). DynamoDB (D) is unnecessary. Cognito Sync (E) is for data synchronization, not access control.

**Question 7: C**
AWS WAF protects against web exploits like SQL injection and XSS. GuardDuty (A) detects threats but does not block them at the application layer. Shield (B) protects against DDoS, not application-layer attacks. Inspector (D) assesses vulnerabilities on EC2 instances, not web traffic.

**Question 8: B**
Cross-account IAM roles with limited permissions and session duration are the most secure approach for temporary third-party access. IAM users with access keys (A) are long-lived credentials. Root credentials (C) should never be shared. IAM passwords (D) do not have built-in expiration after a specific duration.

**Question 9: B**
AWS Secrets Manager supports automatic rotation of database credentials with built-in Lambda rotation functions. Parameter Store (A) does not natively support automatic rotation. KMS (C) rotates encryption keys, not database credentials. Environment variables (D) are not secure and do not support rotation.

**Question 10: B**
AWS Config with the encrypted-volumes rule continuously evaluates compliance and can trigger SNS notifications. SCPs (A) can prevent creation but the question asks for detection and notification. EBS encryption by default (C) only applies to new volumes and does not detect existing non-compliant ones. Trusted Advisor (D) has limited checks and is not real-time.

**Question 11: B**
AWS Site-to-Site VPN can be set up within hours over the internet. Direct Connect (A) takes weeks to months to provision. Direct Connect with VPN overlay (C) also requires Direct Connect setup time. Transit Gateway (D) does not provide the on-premises connection itself.

**Question 12: B**
Amazon EFS supports NFS, is Multi-AZ by default, and automatically scales. EBS Multi-Attach (A) only works within a single AZ for io1/io2 volumes. S3 with s3fs (C) is not a true file system. FSx for Windows (D) uses SMB, not NFS.

**Question 13: B**
SCPs in AWS Organizations can restrict actions across all accounts in an OU. IAM policies per account (A) would need to be applied individually and could be modified. Config rules (C) detect but do not prevent. CloudTrail (D) detects but does not prevent.

**Question 14: D**
ACM automatically renews certificates, but for DNS-validated certificates, the CNAME record must still exist for renewal to succeed. ACM certificates are not entirely automatic without conditions. (B) is partially true but incomplete — the critical requirement is that the DNS CNAME validation record must remain in place.

**Question 15: B**
A bucket policy with `aws:SecureTransport: false` condition denies unencrypted HTTP requests. Transfer Acceleration (A) speeds up transfers but does not enforce encryption. Versioning (C) is unrelated. VPC endpoint (D) restricts access source, not encryption in transit.

**Question 16: B**
A VPC Gateway Endpoint for S3 provides private access without internet traffic. It is free and highly available. NAT Gateway (A) works but costs money and sends traffic through the internet gateway path. Interface endpoints (C) also work for S3 but cost more than Gateway endpoints. Private subnets cannot use internet gateways (D).

**Question 17: C**
Amazon GuardDuty uses machine learning to detect threats including cryptocurrency mining, compromised credentials, and unusual API activity. Config (A) tracks configuration changes. Macie (B) specifically detects sensitive data in S3. CloudTrail (D) logs API calls but does not analyze them for threats.

**Question 18: B**
You cannot enable encryption on an existing unencrypted RDS instance. You must create an encrypted snapshot copy and restore it. Modifying the instance (A) is not possible for encryption. TDE (C) is not supported on PostgreSQL in RDS. Client-side encryption (D) does not encrypt data at rest in the database.

**Question 19: B**
AWS Transit Gateway provides hub-and-spoke connectivity and supports inter-region peering. It simplifies management compared to full-mesh VPC peering (A). PrivateLink (C) is for exposing services, not general connectivity. Mesh VPN (D) is complex and hard to manage.

**Question 20: B, D**
Customer managed KMS keys (B) provide auditability and control required by PCI DSS. VPC endpoints (D) keep traffic private. AWS-owned keys (A) provide encryption but limited auditability. Public subnets (C) increase attack surface. Disabling CloudTrail (E) violates PCI requirements.

---

## Domain 2: Design Resilient Architectures

**Question 21: B**
Multi-AZ EC2 with Auto Scaling and Multi-AZ RDS provides automatic recovery from a single AZ failure. Single AZ EC2 (A, D) creates a single point of failure. Read Replicas (C) do not provide automatic failover like Multi-AZ.

**Question 22: C**
Pilot light keeps only critical core elements running (like a database) and can scale up within the 4-hour RTO. Warm standby (B) meets requirements but costs more. Multi-site (A) is the most expensive. Backup and restore (D) might not meet the 4-hour RTO reliably.

**Question 23: B**
SQS FIFO preserves message ordering and guarantees exactly-once delivery. Standard SQS (A) does not guarantee ordering. SNS (C) does not queue messages. Kinesis (D) with a single shard has ordering but is not designed for this pattern and has throughput limitations.

**Question 24: B**
Origin Access Control (OAC) restricts S3 access to only CloudFront. Making the bucket public (A) defeats the purpose. Website hosting (C) does not restrict access. CORS (D) is a browser-enforced mechanism, not a security control.

**Question 25: B**
Kinesis Data Streams is designed for real-time data ingestion from many producers. SQS (A) is for decoupling, not real-time analytics. SNS (C) is pub/sub notification, not streaming. MQ (D) is for legacy messaging protocol compatibility.

**Question 26: B**
Aurora Replicas with the reader endpoint distribute read traffic automatically. The application only needs to use the reader endpoint. Larger instances (A) are more expensive. DynamoDB (C) requires application changes. Multi-AZ (D) is for availability, not read performance.

**Question 27: B**
ElastiCache for Redis provides sub-millisecond latency, supports Multi-AZ, and can set TTL on keys. DynamoDB with TTL (A) provides single-digit millisecond latency, which is close but ElastiCache is faster. S3 (C) is not designed for session storage. EBS (D) cannot be shared across instances.

**Question 28: B**
S3 Cross-Region Replication copies objects between buckets in different regions. Transfer Acceleration (A) speeds up uploads but does not replicate. SRR (C) is same-region only. Intelligent-Tiering (D) manages storage classes, not replication.

**Question 29: B**
SNS with SQS subscriptions (fan-out pattern) ensures each consumer gets every event independently. A single SQS queue (A) means messages are consumed once. Kinesis (C) requires consumer management. Direct API calls (D) create tight coupling.

**Question 30: B**
Aurora MySQL supports auto-scaling storage (up to 128 TB), up to 15 read replicas, and is managed. RDS MySQL (A) supports up to 5 read replicas. EC2 MySQL (C) has high administrative overhead. DynamoDB (D) is not relational.

**Question 31: B**
An NLB provides a static IP, and the Auto Scaling group ensures a replacement instance is launched automatically. EIP with Lambda (A) works but has more complexity and slower recovery. Secondary private IPs (C) only work within the same subnet. Route 53 (D) has DNS TTL delays.

**Question 32: B**
Auto Scaling based on SQS queue depth scales workers proportionally to the backlog and scales down when the queue is empty. Larger instances (A) may not be enough. Reserved Instances 24/7 (C) waste money when the job finishes. Lambda (D) has a 15-minute timeout limit.

**Question 33: B**
Loose coupling with asynchronous messaging prevents cascading failures. A single instance (C) is the opposite of resilience. Synchronous calls (D) propagate failures. Horizontal scaling (A) helps performance but does not prevent cascading failures by itself.

**Question 34: C**
Latency-based routing with health checks sends users to the lowest-latency healthy endpoint. Simple routing (A) does not support health checks. Weighted routing (B) distributes by percentage, not proximity. Geolocation (D) routes by location, not latency.

**Question 35: C**
Point-in-Time Recovery (PITR) allows restoration to any second within the last 35 days. DynamoDB Streams (A) captures changes but is not a backup mechanism. On-Demand Backup (B) creates manual backups at a specific point. Global Tables (D) provide multi-region replication, not backup.

**Question 36: B**
A health check grace period prevents Auto Scaling from terminating new instances before they are ready. The ALB health check verifies the application is serving traffic. Increasing intervals (A) slows detection. Decreasing capacity (C) does not solve the problem. NLB (D) does not solve application readiness.

**Question 37: B**
An SQS queue decouples the web and application tiers, allowing the application tier to process at its own rate. Auto Scaling lets it handle peaks. Vertical scaling (A) has limits. More web instances (C) does not help the bottleneck. Co-locating tiers (D) increases coupling.

---

## Domain 3: Design High-Performing Architectures

**Question 38: B**
A cluster placement group places instances close together in the same AZ for lowest latency. Enhanced networking (A) improves single-instance performance but does not reduce inter-instance latency as much. Spread placement (C) maximizes separation. Multiple ENIs (D) do not reduce latency.

**Question 39: B**
CloudFront caches content at edge locations worldwide, providing low latency to global users. Transfer Acceleration (A) speeds uploads to S3, not downloads. Cross-region replication (C) helps but requires custom routing. EC2 (D) adds unnecessary complexity.

**Question 40: B**
io2 Block Express supports up to 256,000 IOPS and 4,000 MB/s throughput. gp3 (A) maxes out at 16,000 IOPS. st1 (C) is HDD and does not provide high IOPS. gp2 (D) maxes at 16,000 IOPS.

**Question 41: C**
DynamoDB Global Tables replicate data to multiple regions for low-latency local reads. There are no "DynamoDB read replicas" (A). DAX (B) caches in the same region. ElastiCache (D) requires custom application logic to keep in sync.

**Question 42: B**
ECS on Fargate supports long-running tasks (no 15-minute limit), large memory, and persistent storage. Lambda (A) has a 15-minute timeout — 10-15 minutes processing is too close to the limit and risky. Lambda (D) has a 3-minute timeout which is incorrect. EC2 (C) works but has more operational overhead.

**Question 43: C**
Snowball Edge can transfer 100 TB faster than 1 Gbps internet (which would take ~9 days of continuous transfer). DataSync (A) is limited by the 1 Gbps connection. Multipart upload (B) does not increase bandwidth. Direct Connect (D) takes weeks to set up.

**Question 44: A**
ElastiCache for Redis can cache SQL query results and serve them in sub-millisecond time. DAX (B) is only for DynamoDB. CloudFront (C) caches HTTP responses, not database queries. Instance store (D) is local to one instance.

**Question 45: B**
Kinesis Data Streams ingests real-time data, Firehose delivers to S3 for storage, and Kinesis Data Analytics provides real-time processing. SQS/RDS (A) does not support real-time analytics at this scale. SNS/Lambda/DynamoDB (C) is overly complex and costly. Direct Redshift writes (D) would overwhelm the cluster.

**Question 46: B**
R-family instances are memory optimized and support very large RAM configurations. C-family (A) is compute optimized. T-family (C) is for variable workloads. M-family (D) is balanced but does not have the highest memory options.

**Question 47: B**
Separate cache behaviors allow optimal TTLs per content type. A single TTL of 0 (A) negates caching benefits. Disabling caching (C) wastes CDN capability. Long TTL for all content (D) serves stale API responses.

**Question 48: C**
Amazon Redshift is designed for OLAP workloads and petabyte-scale data warehousing with complex SQL. RDS (A) and Aurora (B) are OLTP databases. DynamoDB (D) is NoSQL and does not support complex SQL joins.

**Question 49: B**
S3 automatically partitions for high request rates (3,500 PUT/5,500 GET per second per prefix). If needed, distribute across multiple prefixes. Sequential keys (A) are no longer a problem in modern S3 but concentrating everything in one prefix (C) can still cause throttling at extreme rates.

**Question 50: A**
VPN can be set up in hours while Direct Connect takes weeks. Use VPN initially and migrate to Direct Connect for consistent, low-latency performance. Direct Connect from the start (B) cannot meet the 2-week timeline. Client VPN (C) is for individual clients, not site-to-site. SD-WAN (D) does not provide Direct Connect benefits.

**Question 51: A**
Lambda in a VPC private subnet needs a NAT Gateway for internet access. A public subnet (B) does not work because Lambda ENIs do not get public IPs. Lambda can be placed in a VPC (C is wrong). VPC endpoints (D) only work for AWS services, not arbitrary external APIs.

**Question 52: B**
Global Accelerator provides static IPs and routes traffic over the AWS global network for both TCP and UDP. CloudFront (A) works for HTTP/HTTPS only. Route 53 (C) helps but does not improve network path. Direct Connect (D) is for on-premises connectivity.

**Question 53: A**
Lambda's SQS event source mapping automatically scales concurrency based on queue depth. A batch size of 1 with a 5-minute timeout processes messages individually. Processing all in one invocation (B) exceeds timeout if many messages arrive. EC2 (C) adds complexity. A 1-minute timeout (D) would fail all messages.

---

## Domain 4: Design Cost-Optimized Architectures

**Question 54: C**
3-year All Upfront Reserved Instances provide the deepest discount (up to 72% over On-Demand). Spot (B) is cheapest per hour but not suitable for 24/7 production. On-Demand (A) is full price. 1-year No Upfront (D) saves less than 3-year All Upfront.

**Question 55: B**
This lifecycle policy matches the access pattern: Standard for hot data, Standard-IA for infrequent access, Glacier for archival, and Deep Archive for long-term retention. Keeping in Standard (A) is the most expensive. Glacier from day 1 (C) charges retrieval fees for the first 30 days of access. Deleting after 90 days (D) violates the 7-year retention requirement.

**Question 56: B**
Scheduling instances to run only during business hours reduces runtime from 168 hours/week to 50 hours/week (70% savings). Reserved (A) provides discount but still runs 24/7. Smaller types (C) save some money but not as much. Spot (D) may be interrupted during work hours.

**Question 57: B**
Spot Instances provide up to 90% savings over On-Demand and are ideal for fault-tolerant, interruptible workloads. On-Demand (A) is full price. Reserved (C) is for steady-state. Dedicated Hosts (D) are the most expensive.

**Question 58: A, C**
Cost Explorer provides cost analysis, forecasting, and RI recommendations (A). Compute Optimizer analyzes utilization metrics and recommends right-sizing (C). Trusted Advisor (B) has some cost checks but is not comprehensive. CloudWatch (D) monitors metrics, not costs. Config (E) tracks resource configuration, not cost.

**Question 59: B**
Read Replicas offload read traffic from the primary, improving write performance. They cost less than scaling up the primary (A). DynamoDB (C) requires a complete redesign. RDS Proxy (D) manages connections but does not offload reads.

**Question 60: C**
S3 Intelligent-Tiering automatically moves objects between access tiers based on usage patterns at a small monitoring fee. Standard (A) is expensive for infrequent data. Standard-IA (B) charges retrieval fees if data is accessed frequently. One Zone-IA (D) has availability risk.

**Question 61: B**
DAX provides a fully managed in-memory cache for DynamoDB that reduces read costs and provides microsecond latency. Increasing RCUs (A) costs more. On-demand mode (C) does not reduce reads. More Lambda memory (D) does not reduce DynamoDB reads.

**Question 62: A**
CloudFront charges lower data transfer rates than EC2 direct transfer and caches content at edge locations, reducing origin transfer volume. Changing regions (B) does not reduce internet egress costs. Larger instances (C) do not affect transfer costs. Transfer Acceleration (D) is for uploads to S3.

**Question 63: C**
Fargate charges only for vCPU and memory while containers run. During idle periods, costs drop to zero if no tasks are running. EC2 with RI (A) runs 24/7. EC2 On-Demand (B) also runs 24/7. EC2 with Spot (D) saves on compute but instances still run during idle periods unless Auto Scaling terminates them.

**Question 64: B**
A NAT instance on a small instance type costs less than a NAT Gateway for very low traffic. NAT Gateway charges $0.045/hour (~$32/month) plus data processing. A t3.micro costs ~$7.60/month. For low traffic, the instance is cheaper. VPC endpoints (C) only work for supported AWS services, not internet access. An internet gateway (D) does not provide NAT for private subnets.

**Question 65: B**
Compute Savings Plans offer savings (up to 66%) with flexibility across instance types, regions, and even compute services (EC2, Lambda, Fargate). Spot (A) is not suitable for consistent production workloads. EC2 Instance Savings Plans (C) lock you to a specific instance family in a specific region. Standard RIs (D) are less flexible than Savings Plans.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Domain 1: Design Secure Architectures (Questions 1-20)
- Domain 2: Design Resilient Architectures (Questions 21-37)
- Domain 3: Design High-Performing Architectures (Questions 38-53)
- Domain 4: Design Cost-Optimized Architectures (Questions 54-65)

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
