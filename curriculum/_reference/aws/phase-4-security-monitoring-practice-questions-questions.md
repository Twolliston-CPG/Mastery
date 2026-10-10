# Phase 4 — Practice Questions (25 SAA-Style Scenario Questions)

## Instructions

- Each question has 4 answer choices (A-D). Select the BEST answer.
- Time yourself: aim for ~2 minutes per question (50 minutes total).
- Answers and detailed explanations are at the end of this document.
- These questions cover: KMS, Secrets Manager, WAF/Shield, GuardDuty, Inspector, Macie, Config, Cognito, CloudWatch, CloudTrail, CloudFormation, and related services.

---

## Questions

### Question 1 — KMS Key Types

A company wants to encrypt S3 objects using a KMS key that they can control, including the ability to disable the key and grant cross-account access. They want to manage the key rotation schedule themselves. Which type of KMS key should they use?

A. AWS owned key (SSE-S3)
B. AWS managed key (aws/s3)
C. Customer managed key (CMK)
D. CloudHSM key

---

### Question 2 — Envelope Encryption

A developer needs to encrypt a 50 MB file using AWS KMS. What is the correct approach?

A. Call `kms:Encrypt` directly with the 50 MB file
B. Call `kms:GenerateDataKey`, use the plaintext data key to encrypt the file locally, store the encrypted data key alongside the encrypted file
C. Call `kms:GenerateDataKeyWithoutPlaintext`, then call `kms:Decrypt` to get the plaintext key
D. Upload the file to S3 with SSE-KMS — KMS handles large files automatically

---

### Question 3 — CloudHSM vs KMS

A financial services company must meet FIPS 140-2 Level 3 compliance requirements for their cryptographic key management. They also need to perform SSL/TLS offloading on their web servers. Which service should they use?

A. AWS KMS with a customer managed key
B. AWS CloudHSM
C. AWS Secrets Manager
D. AWS KMS with an imported key

---

### Question 4 — Secrets Manager vs Parameter Store

A startup needs to store database credentials for their application. The credentials must be automatically rotated every 30 days. The database is Amazon RDS MySQL. Which service provides the simplest solution?

A. SSM Parameter Store with a scheduled Lambda function
B. AWS Secrets Manager with native rotation
C. AWS KMS with encrypted environment variables
D. Amazon DynamoDB with client-side encryption

---

### Question 5 — SSM Parameter Store

A development team stores application configuration in SSM Parameter Store using a path hierarchy: `/app/prod/db/host`, `/app/prod/db/port`, `/app/prod/db/password` (SecureString). They want to retrieve all database parameters in a single API call. Which API should they use?

A. `ssm:GetParameter` called three times
B. `ssm:GetParameters` with all three names
C. `ssm:GetParametersByPath` with path `/app/prod/db`
D. `ssm:DescribeParameters` with a filter

---

### Question 6 — ACM Certificates

A company uses CloudFront to distribute their web application. They need a free SSL/TLS certificate for their custom domain. In which region must the ACM certificate be created?

A. The region closest to the majority of their users
B. The same region as their origin server
C. us-east-1 (N. Virginia)
D. Any region — CloudFront certificates are global

---

### Question 7 — WAF Rate Limiting

A company's login page is under a brute-force attack, with thousands of requests per second from various IP addresses. They use an ALB for their web application. What is the most effective immediate mitigation?

A. Enable AWS Shield Advanced
B. Create a WAF rate-based rule on the ALB
C. Increase the ALB capacity
D. Block all traffic using a NACL

---

### Question 8 — Shield Standard vs Advanced

A company wants DDoS protection but cannot afford additional costs. They need protection against SYN floods and UDP reflection attacks. What should they use?

A. AWS Shield Advanced
B. AWS WAF with rate-based rules
C. AWS Shield Standard (no action needed — it is automatic and free)
D. Amazon GuardDuty

---

### Question 9 — GuardDuty

A security team notices that an EC2 instance is communicating with a known command-and-control server. Which AWS service would have detected this threat?

A. AWS Config
B. Amazon Inspector
C. Amazon GuardDuty
D. AWS CloudTrail

---

### Question 10 — Inspector vs GuardDuty

A company needs to scan their EC2 instances for missing operating system patches and known software vulnerabilities (CVEs). Which service should they use?

A. Amazon GuardDuty
B. Amazon Inspector
C. Amazon Macie
D. AWS Config

---

### Question 11 — Macie

A healthcare company stores patient records in Amazon S3. They need to identify which S3 buckets contain Protected Health Information (PHI) such as Social Security numbers and medical record numbers. Which service should they use?

A. Amazon GuardDuty
B. Amazon Inspector
C. Amazon Macie
D. AWS Config with a custom rule

---

### Question 12 — AWS Config

A company policy requires that all S3 buckets have server-side encryption enabled. They want to automatically detect when a new bucket is created without encryption and automatically enable encryption. Which combination of services achieves this?

A. CloudTrail + Lambda
B. AWS Config managed rule + SSM Automation auto-remediation
C. GuardDuty + EventBridge + Lambda
D. Security Hub + SNS

---

### Question 13 — Security Hub

A company uses GuardDuty, Inspector, Macie, and Config across multiple accounts. They want a single dashboard to view all security findings in a normalized format. Which service provides this?

A. CloudWatch Dashboard
B. AWS Config Aggregator
C. AWS Security Hub
D. Amazon Detective

---

### Question 14 — Cognito User Pools vs Identity Pools

A mobile application needs user sign-up and sign-in functionality with email verification and MFA. After authentication, users need to upload photos directly to an S3 bucket using AWS credentials. Which Cognito components are needed?

A. Cognito User Pool only
B. Cognito Identity Pool only
C. Cognito User Pool for authentication, then Cognito Identity Pool for AWS credentials
D. IAM users for each mobile app user

---

### Question 15 — IAM Identity Center

A company with 50 AWS accounts in an Organization needs to give employees single sign-on access to multiple accounts. Different teams need different permissions per account (e.g., developers get admin in dev but read-only in prod). Which service should they use?

A. Cognito User Pools
B. IAM Identity Center (SSO)
C. IAM users in each account
D. STS AssumeRole with SAML

---

### Question 16 — CloudWatch Agent

A solutions architect is troubleshooting an EC2 instance that is running slowly. CloudWatch shows CPU utilization is only 30%, but the application team reports the instance is sluggish. Which metric should the architect check, and how?

A. Check network throughput in standard CloudWatch metrics
B. Check memory utilization using the CloudWatch Agent (not available by default)
C. Check disk I/O in standard CloudWatch metrics
D. Check EBS burst balance in standard CloudWatch metrics

---

### Question 17 — CloudWatch Alarms

A company wants to receive an alert ONLY when both CPU utilization AND memory utilization exceed 80% simultaneously on an EC2 instance. They want to avoid alerts when only one metric spikes temporarily. What should they use?

A. A single alarm with two metrics
B. Two separate alarms with the same SNS topic
C. A composite alarm that combines CPU and memory alarms with AND logic
D. A CloudWatch Anomaly Detection model

---

### Question 18 — CloudWatch Logs

A company needs to stream application logs from CloudWatch Logs to S3 in near real-time for long-term analysis with Athena. Which approach provides near real-time delivery?

A. CloudWatch Logs export task to S3
B. CloudWatch Logs Subscription Filter -> Kinesis Data Firehose -> S3
C. CloudWatch Logs Insights query saved to S3
D. CloudWatch Agent configured to write directly to S3

---

### Question 19 — CloudTrail

An auditor needs to verify that CloudTrail log files have not been tampered with since they were delivered to S3. Which CloudTrail feature provides this assurance?

A. S3 Object Lock on the log bucket
B. CloudTrail log file integrity validation (digest files)
C. CloudTrail encryption with KMS
D. S3 versioning on the log bucket

---

### Question 20 — VPC Flow Logs

A network administrator is troubleshooting connectivity issues between an EC2 instance and an RDS database in a different subnet. The security group allows traffic, but connections are being rejected. What should the administrator check?

A. CloudTrail logs for API errors
B. VPC Flow Logs for REJECT entries (likely a NACL issue)
C. GuardDuty findings
D. X-Ray traces

---

### Question 21 — Systems Manager Session Manager

A security team requires that all administrative access to EC2 instances be logged and auditable, with no SSH keys distributed and no inbound ports opened for remote access. Which solution meets these requirements?

A. SSH with CloudTrail logging
B. EC2 Instance Connect
C. AWS Systems Manager Session Manager
D. AWS Direct Connect with VPN

---

### Question 22 — CloudFormation Change Sets

A team needs to update a CloudFormation stack but wants to preview exactly which resources will be added, modified, or replaced before applying the changes. Which feature should they use?

A. Drift Detection
B. Stack Policy
C. Change Set
D. Stack update with rollback disabled

---

### Question 23 — CloudFormation DeletionPolicy

A company has a CloudFormation stack with an RDS database. They need to ensure that if the stack is ever deleted, a final snapshot of the database is created before the database is removed. Which DeletionPolicy should they use?

A. `DeletionPolicy: Retain`
B. `DeletionPolicy: Snapshot`
C. `DeletionPolicy: Delete`
D. `UpdateReplacePolicy: Snapshot`

---

### Question 24 — Trusted Advisor

A company with an AWS Basic Support plan wants to check if their root account has MFA enabled and if any S3 buckets have public access. Are these checks available?

A. No — all Trusted Advisor checks require Business or Enterprise Support
B. Yes — both are free security checks available to all accounts
C. Only the MFA check is free; the S3 check requires Business Support
D. Yes, but only through the API, not the console

---

### Question 25 — Multi-Service Integration

A company discovers that an EC2 instance is mining cryptocurrency. They want to: (1) detect this behavior automatically, (2) receive an alert, and (3) automatically stop the instance. Which combination of services achieves this?

A. CloudTrail -> CloudWatch Alarm -> EC2 Stop
B. GuardDuty -> EventBridge -> Lambda (stop instance) + SNS (alert)
C. Inspector -> SNS -> Lambda (stop instance)
D. Config Rule -> SSM Automation -> EC2 Stop

---

## Answers and Explanations

### Question 1 — Answer: C

**Customer managed key (CMK)** is the correct answer. Customer managed keys give you full control over the key policy (including cross-account access), the ability to enable/disable the key, and control over key rotation. AWS managed keys cannot be disabled, and their key policies cannot be edited. AWS owned keys are not visible in your account.

---

### Question 2 — Answer: B

**`GenerateDataKey` + local encryption** is the correct approach. KMS `Encrypt` can only handle data up to 4 KB. For larger data, you use envelope encryption: generate a data key, encrypt your data locally with the plaintext data key, then store the encrypted data key alongside the ciphertext. While option D (SSE-KMS on S3) does work, the question asks about encrypting a file, implying client-side encryption. Option B is the explicit correct answer for envelope encryption.

---

### Question 3 — Answer: B

**AWS CloudHSM** provides FIPS 140-2 Level 3 validated hardware security modules and supports SSL/TLS offloading. KMS is Level 2. CloudHSM gives you dedicated, single-tenant HSMs where AWS has no access to your key material.

---

### Question 4 — Answer: B

**AWS Secrets Manager with native rotation** is the simplest solution. Secrets Manager has built-in integration with RDS MySQL for automatic credential rotation. Parameter Store (A) would require you to build and maintain a custom Lambda rotation function.

---

### Question 5 — Answer: C

**`GetParametersByPath`** retrieves all parameters under a specific path in a single API call. This is the most efficient approach for hierarchical parameter organization. `GetParameters` (B) also works but requires listing all parameter names explicitly.

---

### Question 6 — Answer: C

**us-east-1** is required for ACM certificates used with CloudFront. This is a hard requirement — CloudFront only reads certificates from the N. Virginia region. All other CloudFront configuration can be in any region, but the ACM certificate must be in us-east-1.

---

### Question 7 — Answer: B

**WAF rate-based rule** is the most effective immediate mitigation for brute-force attacks. It automatically blocks IPs that exceed the request rate threshold within a 5-minute window. Shield (A) protects against Layer 3/4 DDoS, not application-layer brute force. Increasing capacity (C) does not stop the attack. Blocking all traffic (D) blocks legitimate users too.

---

### Question 8 — Answer: C

**AWS Shield Standard** is free and automatic for all AWS customers. It protects against common Layer 3/4 DDoS attacks including SYN floods and UDP reflection. No action is required to enable it.

---

### Question 9 — Answer: C

**Amazon GuardDuty** detects communication with command-and-control servers by analyzing VPC Flow Logs and DNS logs with threat intelligence feeds. The finding type would be something like `Backdoor:EC2/C&CActivity.B`.

---

### Question 10 — Answer: B

**Amazon Inspector** scans for software vulnerabilities (CVEs) and missing patches on EC2 instances, ECR container images, and Lambda functions. GuardDuty detects active threats, not vulnerabilities. Macie discovers sensitive data. Config checks configuration compliance.

---

### Question 11 — Answer: C

**Amazon Macie** uses ML and pattern matching to discover sensitive data (PII, PHI) in S3 buckets. It identifies Social Security numbers, credit card numbers, medical record numbers, and other sensitive data types.

---

### Question 12 — Answer: B

**AWS Config managed rule + SSM Automation auto-remediation** is the correct combination. Config detects non-compliant S3 buckets, and auto-remediation triggers an SSM Automation document to enable encryption. This is a fully managed, no-code solution. Option A would work but requires custom code.

---

### Question 13 — Answer: C

**AWS Security Hub** aggregates findings from GuardDuty, Inspector, Macie, Config, Firewall Manager, and third-party tools into a single dashboard using the AWS Security Finding Format (ASFF). Config Aggregator (B) only aggregates Config data, not findings from other services.

---

### Question 14 — Answer: C

**User Pool for authentication + Identity Pool for AWS credentials.** The User Pool handles sign-up, sign-in, MFA, and email verification, returning JWT tokens. The Identity Pool exchanges those JWT tokens for temporary AWS credentials (STS) that allow direct S3 uploads. Using User Pool alone (A) would only give JWT tokens, not AWS credentials for S3.

---

### Question 15 — Answer: B

**IAM Identity Center (SSO)** provides single sign-on across multiple AWS accounts with Permission Sets that define different permissions per account. This is the AWS-recommended approach for workforce access to multiple accounts. Cognito (A) is for customer-facing applications, not workforce SSO.

---

### Question 16 — Answer: B

**Memory utilization requires the CloudWatch Agent** because it is not available in standard EC2 CloudWatch metrics. Standard metrics include CPU, network, disk I/O (EBS-level), and status checks — but NOT memory or disk space. If CPU is at 30% but the instance is slow, memory exhaustion is a likely cause.

---

### Question 17 — Answer: C

**Composite alarm** combines multiple alarms using AND/OR logic. By setting AND logic on CPU and memory alarms, the composite alarm only triggers when BOTH conditions are met simultaneously. This reduces false positives from temporary single-metric spikes.

---

### Question 18 — Answer: B

**Subscription Filter -> Kinesis Data Firehose -> S3** provides near real-time log delivery to S3. The export task (A) can take up to 12 hours and is not real-time. Kinesis Data Firehose delivers data to S3 within 60-900 seconds (configurable).

---

### Question 19 — Answer: B

**Log file integrity validation** uses SHA-256 digest files that CloudTrail creates hourly. Each digest file contains hashes of log files and references the previous digest, creating a chain of trust. You validate with `aws cloudtrail validate-logs`. S3 Object Lock (A) prevents deletion but does not verify integrity. KMS encryption (C) protects confidentiality, not integrity.

---

### Question 20 — Answer: B

**VPC Flow Logs with REJECT entries** will show if traffic is being rejected at the network level. If the security group allows traffic but connections are being rejected, the most likely cause is a NACL blocking the traffic. Flow Logs show ACCEPT/REJECT at the ENI level, helping identify whether the SG or NACL is responsible.

---

### Question 21 — Answer: C

**AWS Systems Manager Session Manager** provides browser-based or CLI shell access without SSH keys, without opening inbound ports, and with full session logging to S3 and CloudWatch Logs. It uses IAM for authentication and CloudTrail for audit trails. EC2 Instance Connect (B) still requires port 22 to be open.

---

### Question 22 — Answer: C

**Change Set** previews exactly which resources will be added, modified, or replaced before the update is applied. Drift Detection (A) checks for out-of-band changes, not pending updates. Stack Policy (B) prevents updates to specific resources.

---

### Question 23 — Answer: B

**`DeletionPolicy: Snapshot`** creates a final snapshot of the RDS database before deleting it when the stack is deleted. `Retain` (A) would keep the database running (not deleted), which is not what was asked. Note: `UpdateReplacePolicy: Snapshot` (D) applies when a resource is replaced during an update, not during stack deletion.

---

### Question 24 — Answer: B

**Both are free security checks.** Trusted Advisor provides 6 free security checks to all accounts regardless of support plan: S3 bucket permissions, security groups unrestricted ports, IAM use, MFA on root, EBS public snapshots, and RDS public snapshots. Service limit checks are also free.

---

### Question 25 — Answer: B

**GuardDuty -> EventBridge -> Lambda + SNS** is the correct combination. GuardDuty detects cryptocurrency mining with the finding `CryptoCurrency:EC2/BitcoinTool.B`. EventBridge routes the finding to both a Lambda function (which stops the instance via `ec2.stop_instances()`) and an SNS topic (which sends the alert). CloudTrail (A) logs API calls but does not detect crypto mining. Inspector (C) scans for vulnerabilities, not active threats.

---

## Score Guide

| Score | Assessment |
|-------|-----------|
| 23-25 | Excellent — You are ready for the security domain |
| 20-22 | Good — Review the topics you missed |
| 16-19 | Fair — Revisit the relevant notes and redo the labs |
| Below 16 | Needs work — Re-read all notes before continuing to Phase 5 |

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Instructions
- Score Guide
- Question 1 — KMS Key Types
- Question 2 — Envelope Encryption

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
