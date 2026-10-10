# Phase 2 — Practice Questions

## Instructions

- 25 SAA-C03 style scenario questions.
- Each question has 4 answer choices (A-D). Select the **one best answer**.
- Target time: 1.5 minutes per question (37.5 minutes total).
- Answers and explanations are at the end.

---

## Questions

### Q1. EC2 Instance Types

A company runs a web application on a fleet of EC2 instances. The application has a variable workload with occasional CPU spikes but is mostly idle. The company wants to minimize costs. Which instance type is most appropriate?

A. c6i.large
B. m6i.large
C. t3.medium
D. r6i.large

---

### Q2. EC2 Purchase Options

A company has a batch processing workload that runs for 4-6 hours at a time. The workload can tolerate interruptions and be restarted. The company wants to minimize cost. Which purchase option should they use?

A. On-Demand Instances
B. Reserved Instances (1-year, No Upfront)
C. Spot Instances
D. Dedicated Hosts

---

### Q3. EBS Volume Types

A database administrator needs an EBS volume for a production MySQL database that requires sustained 10,000 IOPS. The database stores 200 GiB of data. Which volume type is the most cost-effective choice?

A. gp2 (3,334 GiB to get 10,000 IOPS)
B. gp3 (200 GiB with 10,000 provisioned IOPS)
C. io2 (200 GiB with 10,000 provisioned IOPS)
D. st1 (200 GiB)

---

### Q4. EBS Snapshots

A solutions architect needs to move an EC2 instance from us-east-1 to eu-west-1 for disaster recovery. What is the correct approach?

A. Create an AMI from the instance and launch it in eu-west-1
B. Create an EBS snapshot, copy the snapshot to eu-west-1, create a volume from the snapshot, launch an instance
C. Detach the EBS volume and re-attach it to an instance in eu-west-1
D. Use EBS Multi-Attach to access the volume from eu-west-1

---

### Q5. Placement Groups

A company runs a high-performance computing (HPC) workload that requires the lowest possible network latency between instances. All instances are in the same Availability Zone. Which placement group strategy should be used?

A. Spread
B. Cluster
C. Partition
D. No placement group needed

---

### Q6. Auto Scaling — Scaling Policies

A web application experiences predictable traffic increases every weekday from 9 AM to 5 PM. The solutions architect wants to pre-provision instances before the traffic arrives. Which scaling approach is most appropriate?

A. Target Tracking Scaling
B. Step Scaling
C. Scheduled Scaling
D. Simple Scaling

---

### Q7. Auto Scaling — Health Checks

An Auto Scaling Group is configured with an Application Load Balancer. Instances occasionally become unresponsive to application requests but pass EC2 status checks. The ASG does not replace these instances. What should the solutions architect do?

A. Increase the health check grace period
B. Enable ELB health checks on the Auto Scaling Group
C. Create a CloudWatch alarm to terminate unhealthy instances
D. Configure a lifecycle hook to check instance health

---

### Q8. Lambda Limits

A company wants to use Lambda to process video files that take 20-30 minutes to transcode. Why is Lambda NOT suitable for this workload?

A. Lambda does not support video processing libraries
B. Lambda has a maximum timeout of 15 minutes
C. Lambda does not have enough memory for video processing
D. Lambda cannot read files larger than 50 MB from S3

---

### Q9. Lambda Concurrency

A Lambda function processes orders from an API Gateway. During flash sales, the function is throttled and returns 429 errors. The function currently uses unreserved concurrency. What should the solutions architect do to guarantee the function has enough capacity?

A. Increase the function's memory allocation
B. Configure provisioned concurrency for the function
C. Configure reserved concurrency for the function
D. Increase the function's timeout

---

### Q10. Lambda@Edge vs CloudFront Functions

A company needs to add security headers (HSTS, X-Frame-Options) to all HTTP responses from their CloudFront distribution. The logic is simple header manipulation. Which solution is the most cost-effective?

A. Lambda@Edge on the Origin Response event
B. CloudFront Functions on the Viewer Response event
C. An Application Load Balancer rule
D. A custom origin that adds headers

---

### Q11. S3 Storage Classes

A company stores medical imaging files in S3. Files are accessed frequently for the first 30 days, then rarely accessed but must be available within milliseconds when needed. After 1 year, files must be archived with retrieval within 12 hours acceptable. Which lifecycle policy is correct?

A. Standard -> Standard-IA (30 days) -> Glacier Flexible Retrieval (365 days)
B. Standard -> One Zone-IA (30 days) -> Glacier Deep Archive (365 days)
C. Standard -> Standard-IA (30 days) -> Glacier Instant Retrieval (365 days)
D. Standard -> Intelligent-Tiering (30 days) -> Glacier Flexible Retrieval (365 days)

---

### Q12. S3 Encryption

A compliance requirement states that all S3 objects must be encrypted with keys managed by the company's security team, and all key usage must be logged in CloudTrail. Which encryption method meets these requirements?

A. SSE-S3
B. SSE-KMS with a customer-managed key
C. SSE-C
D. Client-side encryption

---

### Q13. S3 Replication

A company enables Cross-Region Replication on an S3 bucket. They notice that existing objects in the bucket are not replicated to the destination. What should they do?

A. Delete and re-upload the existing objects
B. Use S3 Batch Replication to replicate existing objects
C. Disable and re-enable replication
D. Change the replication rule to include existing objects

---

### Q14. S3 Object Lock

A financial services company must store transaction records in S3 for 7 years. Regulations require that no one, including the root account, can delete these records during the retention period. Which S3 feature should they use?

A. S3 Object Lock in Governance Mode
B. S3 Object Lock in Compliance Mode
C. S3 Versioning with MFA Delete
D. An S3 bucket policy denying s3:DeleteObject

---

### Q15. S3 Presigned URLs

An application generates reports stored in a private S3 bucket. Authenticated users should be able to download reports temporarily without AWS credentials. What is the best approach?

A. Make the bucket public and use IP-based bucket policy restrictions
B. Create an IAM user for each application user
C. Generate presigned URLs for the report objects
D. Use S3 Access Points with public access

---

### Q16. EFS vs EBS

A web application running on multiple EC2 instances needs a shared file system for storing user-uploaded images. The instances are in different Availability Zones. Which storage solution is appropriate?

A. EBS with Multi-Attach
B. Amazon EFS
C. Amazon S3 mounted with s3fs
D. Instance store

---

### Q17. FSx Variants

A company is migrating an on-premises Windows file server that uses Active Directory, DFS namespaces, and SMB shares. Which AWS service should they use?

A. Amazon EFS
B. FSx for Lustre
C. FSx for Windows File Server
D. FSx for OpenZFS

---

### Q18. FSx for Lustre

A machine learning team needs a high-performance file system that can read training data directly from an S3 bucket with sub-millisecond latency. Which service provides this?

A. FSx for Windows File Server
B. FSx for Lustre
C. EFS with Max I/O performance mode
D. S3 with Transfer Acceleration

---

### Q19. Storage Gateway — File Gateway

A company has on-premises applications that need to store files in S3 but currently use NFS mounts. They want to minimize changes to their applications. Which solution should they use?

A. AWS DataSync
B. S3 File Gateway
C. Volume Gateway (Cached)
D. AWS Transfer Family

---

### Q20. Storage Gateway — Volume Gateway

A company wants to use S3 as primary storage for application data while maintaining low-latency access to frequently used data on-premises. They need iSCSI block storage. Which solution should they use?

A. Volume Gateway — Stored Volumes
B. Volume Gateway — Cached Volumes
C. S3 File Gateway
D. Tape Gateway

---

### Q21. Snow Family

A company needs to migrate 60 TB of data from an on-premises data center to S3. Their internet connection can sustain 100 Mbps. The migration must complete within 1 week. Which approach should they use?

A. S3 Transfer Acceleration
B. AWS DataSync over the internet
C. AWS Snowball Edge Storage Optimized
D. AWS Snowmobile

---

### Q22. ECS Launch Types

A startup wants to deploy containerized microservices with minimal operational overhead. They do not want to manage any servers or clusters. Which solution should they use?

A. ECS with EC2 launch type
B. ECS with Fargate launch type
C. EKS with managed node groups
D. EC2 instances with Docker installed

---

### Q23. ECS Task Roles

An ECS task needs to read from an S3 bucket and write to a DynamoDB table. Where should the IAM permissions be configured?

A. On the EC2 instance role of the ECS cluster
B. On the ECS Task Execution Role
C. On the ECS Task Role
D. On the S3 bucket policy and DynamoDB resource policy

---

### Q24. Elastic Beanstalk Deployment

A production Elastic Beanstalk environment needs to deploy a new application version with zero downtime and the fastest possible rollback. Which deployment policy should be used?

A. All-at-Once
B. Rolling
C. Immutable
D. Traffic Splitting

---

### Q25. Data Migration

A company needs to continuously replicate data from their on-premises NFS server to Amazon EFS. The replication should run on a daily schedule with only changed files transferred. Which service should they use?

A. S3 File Gateway
B. AWS DataSync
C. AWS Snowball Edge
D. AWS Transfer Family

---

## Answers and Explanations

### Q1: C — t3.medium

T3 instances are burstable and designed for **variable workloads with occasional spikes**. They accumulate CPU credits during idle periods and spend them during spikes. C-series (compute optimized) and R-series (memory optimized) would be more expensive and unnecessary. M-series (general purpose) does not have the burst capability cost advantage.

### Q2: C — Spot Instances

Spot Instances offer up to 90% discount over On-Demand. The workload **tolerates interruptions**, making Spot ideal. Reserved Instances require a 1-3 year commitment, which is unnecessary for a batch job. Dedicated Hosts are for licensing or compliance, not cost savings.

### Q3: B — gp3 (200 GiB with 10,000 provisioned IOPS)

gp3 lets you provision IOPS independently of volume size. 200 GiB at $0.08/GiB + 7,000 extra IOPS (above the 3,000 baseline) at $0.005/IOPS = $16 + $35 = $51/month. gp2 would need 3,334 GiB at $0.10/GiB = $333/month. io2 costs $0.125/GiB + IOPS pricing, totaling more. st1 is HDD and cannot provide 10,000 IOPS.

### Q4: A — Create an AMI from the instance and launch it in eu-west-1

Creating an AMI captures the root volume and configuration. The AMI can be **copied to another region** and used to launch a new instance. Option B also works but is more complex and does not capture instance configuration. Option C is impossible (EBS volumes are AZ-locked). Option D: Multi-Attach is same-AZ only.

### Q5: B — Cluster

Cluster placement groups place instances **close together on the same rack** in a single AZ, providing the lowest network latency. Spread maximizes availability by separating instances (opposite of what is needed). Partition is for large distributed systems.

### Q6: C — Scheduled Scaling

The traffic pattern is **predictable** (9 AM to 5 PM weekdays), making Scheduled Scaling the best fit. It allows pre-provisioning before traffic arrives. Target Tracking reacts to current metrics (not proactive). Predictive Scaling could also work but Scheduled is simpler for known patterns.

### Q7: B — Enable ELB health checks on the Auto Scaling Group

By default, ASG only uses **EC2 health checks** (instance status). To detect application-level failures, you must **explicitly enable ELB health checks** on the ASG. This allows the ASG to use the ALB's health check results to replace unresponsive instances.

### Q8: B — Lambda has a maximum timeout of 15 minutes

Lambda's maximum execution time is **900 seconds (15 minutes)**. A 20-30 minute video transcode exceeds this limit. Lambda supports up to 10 GB of memory and can install video processing libraries, so A and C are incorrect. Lambda can read files of any size from S3 (D is incorrect).

### Q9: C — Configure reserved concurrency for the function

**Reserved concurrency** guarantees a portion of the account's concurrency limit for a specific function, ensuring it always has capacity. Provisioned concurrency eliminates cold starts but does not guarantee capacity during account-wide throttling. Memory and timeout do not affect concurrency.

### Q10: B — CloudFront Functions on the Viewer Response event

CloudFront Functions run at **218+ edge locations**, handle millions of requests/second, execute in under 1 ms, and cost 1/6th of Lambda@Edge. For simple header manipulation, CloudFront Functions is the most cost-effective. Lambda@Edge is overkill for this use case.

### Q11: A — Standard -> Standard-IA (30 days) -> Glacier Flexible Retrieval (365 days)

Files need millisecond access for the first year (Standard-IA provides this). After 1 year, 12-hour retrieval is acceptable, so Glacier Flexible Retrieval (Standard retrieval: 3-5 hours) works. One Zone-IA is risky for medical records (single AZ). Glacier Instant Retrieval would work for the first transition but is more expensive than Standard-IA.

### Q12: B — SSE-KMS with a customer-managed key

SSE-KMS with a **customer-managed key** (CMK) allows the security team to manage the key policy and rotation. All key usage is logged in **CloudTrail**. SSE-S3: keys managed by AWS, no CloudTrail logging of key usage. SSE-C: keys not stored by AWS, no CloudTrail integration. Client-side: no CloudTrail logging.

### Q13: B — Use S3 Batch Replication to replicate existing objects

S3 replication only applies to **new objects** created after the rule is enabled. To replicate existing objects, use **S3 Batch Replication**. Re-uploading objects (A) would work but is impractical for large datasets. Disabling/re-enabling (C) does not replicate existing objects.

### Q14: B — S3 Object Lock in Compliance Mode

**Compliance Mode** prevents anyone, including the root account, from deleting objects or shortening the retention period during the retention window. Governance Mode allows users with special permissions to override the lock. MFA Delete only protects against accidental deletion. Bucket policies can be changed by admins.

### Q15: C — Generate presigned URLs for the report objects

**Presigned URLs** provide temporary, time-limited access to private S3 objects without requiring AWS credentials. The application generates the URL (inheriting its IAM permissions), and users download via the URL. Making the bucket public (A) is a security risk. IAM users per app user (B) does not scale.

### Q16: B — Amazon EFS

EFS is a **shared NFS file system** that can be mounted on instances across **multiple AZs**. EBS Multi-Attach only works within a **single AZ** and requires io1/io2. S3 is object storage (not a POSIX file system). Instance store is ephemeral and not shared.

### Q17: C — FSx for Windows File Server

FSx for Windows provides **SMB protocol, Active Directory integration, and DFS** — all required by the migration. EFS is NFS (Linux only, no AD). FSx for Lustre is for HPC. FSx for OpenZFS is NFS-based.

### Q18: B — FSx for Lustre

FSx for Lustre has **native S3 integration** — it can present S3 objects as files in a high-performance file system with sub-millisecond latency. It is designed for ML and HPC workloads. EFS does not integrate directly with S3. S3 Transfer Acceleration speeds uploads, not read latency.

### Q19: B — S3 File Gateway

S3 File Gateway provides an **NFS/SMB interface to S3**, requiring minimal changes to applications that already use NFS mounts. DataSync is for one-time or scheduled migrations, not ongoing access. Volume Gateway provides iSCSI (block), not NFS. Transfer Family is for SFTP/FTPS.

### Q20: B — Volume Gateway — Cached Volumes

**Cached Volumes** store the full dataset in S3 and cache frequently accessed data locally, providing low-latency access via iSCSI. Stored Volumes keep all data on-premises (S3 is only for backup). S3 File Gateway provides NFS/SMB, not iSCSI. Tape Gateway is for backup.

### Q21: C — AWS Snowball Edge Storage Optimized

60 TB at 100 Mbps = ~55 days to transfer over the network. This exceeds the 1-week deadline, so network transfer is not viable. Snowball Edge (80 TB capacity) can be shipped in a few days. Snowmobile is for exabyte-scale (>10 PB). DataSync over the internet would take too long.

### Q22: B — ECS with Fargate launch type

Fargate is **serverless** — no servers, clusters, or instances to manage. You define the task and Fargate runs it. ECS with EC2 requires managing instances. EKS with managed node groups still involves node management. Raw EC2 with Docker has the most operational overhead.

### Q23: C — On the ECS Task Role

The **Task Role** is the IAM role assumed by the containers in the task to call AWS APIs (S3, DynamoDB). The **Execution Role** is for the ECS agent (pulling images, pushing logs). The EC2 instance role should not be used for application permissions.

### Q24: C — Immutable

**Immutable** deployment creates a completely new set of instances. If the deployment fails, rollback is instant (terminate the new instances). There is zero downtime. All-at-Once causes downtime. Rolling reduces capacity. Traffic Splitting is also zero-downtime but slower.

### Q25: B — AWS DataSync

**DataSync** is designed for scheduled, incremental data transfers between on-premises storage and AWS (including EFS). It supports NFS sources, daily scheduling, and transfers only changed files. S3 File Gateway provides ongoing access, not migration. Snowball is for offline migration. Transfer Family is for SFTP.

---

## Score Interpretation

| Score | Assessment |
|---|---|
| 22-25 (88-100%) | Excellent — ready for Phase 3 |
| 18-21 (72-84%) | Good — review missed topics |
| 14-17 (56-68%) | Needs improvement — re-read relevant notes |
| Below 14 (<56%) | Re-study Phase 2 notes and redo labs |

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Instructions
- Score Interpretation
- EC2 Instance Types
- EC2 Purchase Options

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
