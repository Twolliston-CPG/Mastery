# Domain 1: Design Secure Architectures (30% of Exam)

This is the highest-weighted domain. You will see approximately 20 questions on security topics. Master this domain and you have a massive advantage.

---

## 1. IAM (Identity and Access Management)

### Core Concepts
- **Users**: Represent people or applications. Have long-term credentials (password, access keys).
- **Groups**: Collections of users. Cannot be nested. Cannot be used in resource-based policies.
- **Roles**: Temporary credentials. Used by services (EC2, Lambda), cross-account access, and federation.
- **Policies**: JSON documents defining permissions. Types: Identity-based, Resource-based, SCPs, Permission Boundaries.

### Policy Evaluation Logic
1. Explicit Deny always wins
2. SCPs (Organization level) restrict what accounts CAN do
3. Permission Boundaries limit the maximum permissions an identity CAN have
4. Identity-based + Resource-based policies are evaluated together (for same-account); for cross-account, BOTH must allow

### Key Exam Scenarios
- **"Least privilege access"** → Use IAM roles with minimal permissions, never use AdministratorAccess
- **"Temporary credentials"** → IAM Roles with STS (AssumeRole)
- **"Cross-account access"** → Either cross-account IAM role (user gives up original permissions) OR resource-based policy (user keeps original permissions)
- **"EC2 needs to access S3"** → IAM role attached via instance profile (NEVER access keys on the instance)
- **"Lambda needs to access DynamoDB"** → Lambda execution role with DynamoDB permissions

### Traps to Avoid
- IAM is GLOBAL — not regional
- Root account should have MFA, should NOT be used for daily tasks
- Access keys should be rotated and never hardcoded
- SCPs do NOT apply to the management account
- SCPs do NOT grant permissions — they only restrict them

---

## 2. AWS KMS (Key Management Service)

### Key Types
| Key Type | Who Manages | Rotation | Cross-Account | Cost |
|---|---|---|---|---|
| AWS Owned | AWS | Automatic | No | Free |
| AWS Managed (aws/service) | AWS | Automatic (every year) | No | Free |
| Customer Managed (CMK) | You | Optional (enable annual auto-rotation) | Yes | $1/month + API calls |

### Encryption Patterns
- **SSE-S3**: S3 manages keys. Simplest. No audit trail of key usage.
- **SSE-KMS**: KMS manages keys. Audit trail via CloudTrail. Rate limits apply (GenerateDataKey calls).
- **SSE-C**: Customer provides the key with each request. AWS does not store the key.
- **Client-side encryption**: Data encrypted before sending to AWS. Maximum control.

### Key Exam Scenarios
- **"Company must manage and rotate keys"** → SSE-KMS with customer managed CMK
- **"Audit key usage"** → SSE-KMS (CloudTrail logs KMS API calls)
- **"Cross-account encryption"** → SSE-KMS with key policy granting cross-account access
- **"Encryption envelope"** → KMS generates a data key; you encrypt data with the data key, then encrypt the data key with the CMK

### Traps to Avoid
- SSE-KMS has API call rate limits (5,500 to 30,000 requests/sec depending on region)
- You CANNOT enable encryption at rest on an existing unencrypted RDS instance — you must snapshot, copy with encryption, and restore
- EFS encryption at rest must be enabled at creation time

---

## 3. VPC Security

### Security Groups vs NACLs

| Feature | Security Groups | NACLs |
|---|---|---|
| Level | Instance (ENI) | Subnet |
| State | Stateful (return traffic auto-allowed) | Stateless (must allow both inbound AND outbound) |
| Rules | Allow only | Allow AND Deny |
| Default | Deny all inbound, allow all outbound | Allow all inbound and outbound |
| Evaluation | All rules evaluated together | Rules evaluated in order (lowest number first) |
| Reference | Can reference other SGs | Cannot reference SGs |

### VPC Endpoints
- **Gateway Endpoints**: S3 and DynamoDB ONLY. Free. Route table entry.
- **Interface Endpoints (PrivateLink)**: Almost all other services. ENI in your subnet. Costs per hour + per GB. Supports security groups.

### Key Exam Scenarios
- **"Block a specific IP"** → NACL (SGs cannot deny)
- **"Allow EC2 to talk to RDS"** → SG on RDS allowing inbound from EC2 SG
- **"Private subnet access to S3"** → VPC Gateway Endpoint (free)
- **"Private subnet access to Secrets Manager"** → VPC Interface Endpoint
- **"No internet access but needs AWS service access"** → VPC Endpoints

### Traps to Avoid
- NACLs are stateless — if you allow inbound port 80, you must also allow outbound ephemeral ports (1024-65535)
- Gateway Endpoints do NOT support cross-region (S3 endpoint only works for S3 in the same region)
- Interface Endpoints create an ENI with a private IP in your subnet

---

## 4. AWS WAF & Shield

### AWS WAF
- Protects against Layer 7 attacks: SQL injection, XSS, bad bots
- Works with: ALB, CloudFront, API Gateway, AppSync
- Supports: IP set rules, rate-based rules, geo-matching, string matching, regex
- Web ACLs contain rules evaluated in order

### AWS Shield
- **Standard**: Free, automatic. Protects against Layer 3/4 DDoS (SYN flood, UDP reflection)
- **Advanced**: $3,000/month. DDoS Response Team (DRT), cost protection during attacks, advanced metrics, works with WAF

### Key Exam Scenarios
- **"SQL injection / XSS protection"** → AWS WAF
- **"DDoS protection with cost protection"** → Shield Advanced
- **"Rate limiting"** → AWS WAF rate-based rules
- **"Bot mitigation"** → AWS WAF Bot Control

---

## 5. Amazon GuardDuty

- Threat detection service using ML, anomaly detection, and threat intelligence
- Analyzes: CloudTrail logs, VPC Flow Logs, DNS logs, S3 data events, EKS audit logs
- Detects: Cryptocurrency mining, compromised instances, unauthorized access, unusual API calls, compromised credentials
- Does NOT block threats — only detects and alerts

### Key Exam Scenarios
- **"Detect compromised EC2 instances"** → GuardDuty
- **"Detect unusual API activity"** → GuardDuty
- **"Automatically detect threats with minimal setup"** → GuardDuty (one-click enable)

---

## 6. AWS Config

- Records and evaluates resource configurations
- Provides compliance dashboard
- Managed rules: encrypted-volumes, s3-bucket-public-read-prohibited, etc.
- Can trigger automatic remediation via SSM Automation
- Stores configuration history in S3

### Key Exam Scenarios
- **"Detect non-compliant resources"** → AWS Config
- **"Automatically remediate non-compliant security groups"** → AWS Config + SSM Automation
- **"Track configuration changes over time"** → AWS Config

---

## 7. Amazon Cognito

### User Pools
- User directory for authentication (sign-up, sign-in)
- Supports MFA, email/phone verification
- Social identity provider integration (Google, SocialGraph, Apple)
- Returns JWT tokens

### Identity Pools (Federated Identities)
- Provides temporary AWS credentials
- Maps users to IAM roles
- Supports authenticated and unauthenticated access
- Can scope credentials per user (e.g., S3 prefix per user)

### Common Pattern
User signs in via **User Pool** → gets JWT → **Identity Pool** exchanges JWT for temporary AWS credentials → user accesses AWS services with scoped permissions

---

## 8. Other Security Services

### AWS Secrets Manager
- Stores secrets (database passwords, API keys)
- Automatic rotation with built-in Lambda functions for RDS
- Cross-account access supported
- Costs: $0.40/secret/month + $0.05/10,000 API calls

### AWS Systems Manager Parameter Store
- Stores configuration values and secrets
- Standard tier: free, up to 10,000 parameters, 4 KB max
- Advanced tier: paid, up to 100,000 parameters, 8 KB max
- Does NOT natively support automatic rotation for RDS (unlike Secrets Manager)

### AWS Certificate Manager (ACM)
- Free public SSL/TLS certificates
- Auto-renewal for DNS-validated certificates (CNAME must remain in DNS)
- Integrates with ALB, CloudFront, API Gateway
- Cannot be used directly on EC2 (use the certificate on a load balancer instead)

### Amazon Macie
- Discovers and protects sensitive data (PII, PHI) in S3
- Uses ML to classify data
- Alerts on public buckets, unencrypted data

### Amazon Inspector
- Automated security assessments for EC2 and container images
- Checks for software vulnerabilities and network exposure
- Integrates with Systems Manager for EC2 scanning

---

## Common Exam Traps for Domain 1

1. **"Encrypt an existing RDS database"** → You CANNOT enable encryption on an existing unencrypted instance. Snapshot → copy with encryption → restore.
2. **"EC2 needs credentials"** → ALWAYS use IAM roles, NEVER access keys on the instance.
3. **"Block an IP"** → Use NACLs (security groups cannot deny).
4. **"Cross-account S3 access without giving up permissions"** → Resource-based policy (bucket policy), NOT cross-account role.
5. **"Free private access to S3 from private subnet"** → VPC Gateway Endpoint.
6. **"Tamper-proof audit logs"** → CloudTrail + S3 Object Lock (Compliance mode).
7. **"Automatic secret rotation"** → Secrets Manager, NOT Parameter Store.
8. **"Free SSL certificate for ALB"** → ACM public certificate.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- IAM (Identity and Access Management)
- AWS KMS (Key Management Service)
- VPC Security
- AWS WAF & Shield

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
