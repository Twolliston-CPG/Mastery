# 02 -- IAM Deep Dive

## Table of Contents
1. [IAM Overview](#iam-overview)
2. [Users](#users)
3. [Groups](#groups)
4. [Roles](#roles)
5. [Policies](#policies)
6. [Policy Evaluation Logic](#policy-evaluation-logic)
7. [AWS Security Token Service (STS)](#aws-security-token-service-sts)
8. [Cross-Account Access](#cross-account-access)
9. [AWS Organizations](#aws-organizations)
10. [Service Control Policies (SCPs)](#service-control-policies-scps)
11. [AWS Control Tower](#aws-control-tower)
12. [IAM Best Practices](#iam-best-practices)
13. [Key Takeaways for the SAA-C03 Exam](#key-takeaways-for-the-saa-c03-exam)

---

## IAM Overview

AWS Identity and Access Management (IAM) is a **global service** (not Region-specific) that controls who (authentication) can do what (authorization) in your AWS account.

Key characteristics:
- **Free** -- IAM itself costs nothing. You pay for the resources you access.
- **Global** -- IAM entities (users, roles, policies) are available across all Regions.
- **Eventually consistent** -- Changes to IAM propagate globally but may take a few seconds.
- **Integrated with every AWS service** -- Every API call is authenticated and authorized through IAM.

### The Root User

The root user is created when you first set up your AWS account. It has **unrestricted access** to everything.

**Root user best practices:**
- Enable MFA on the root user immediately.
- Do NOT use the root user for day-to-day operations.
- Create an IAM admin user instead.
- Only use root for tasks that require root (e.g., changing account settings, closing the account, restoring IAM permissions, changing the support plan).

[TODO: List all tasks that specifically require root user access -- there are roughly 10 and the exam may test on these]

---

## Users

An **IAM user** represents a person or application that interacts with AWS. Each user has a unique name within the account.

**Authentication methods:**
| Method | Use Case |
|---|---|
| Console password | Human users logging into the AWS Management Console |
| Access key (Access Key ID + Secret Access Key) | Programmatic access via CLI, SDK, or API |

**Key facts:**
- A user can have at most **2 access keys** at a time (to allow key rotation without downtime).
- New users have **no permissions** by default (implicit deny).
- Users can belong to multiple groups.
- Users can have policies attached directly (inline or managed), but best practice is to use groups.

**Hard limit:** 5,000 IAM users per account. If you need more identities, use IAM Identity Center (successor to AWS SSO) or federation.

[TODO: Explain when to use IAM users vs. IAM Identity Center vs. federation -- this is a common exam question]

---

## Groups

An **IAM group** is a collection of users. Groups simplify permission management by letting you assign policies to a group rather than to individual users.

**Key facts:**
- A group is **not an identity** -- you cannot log in as a group, and a group cannot be referenced as a principal in a resource-based policy.
- A user can belong to up to **10 groups**.
- Groups **cannot be nested** (no groups within groups).
- There is no "all users" default group -- you must create one if you want it.

**Common group examples:**
- `Admins` -- full access
- `Developers` -- access to development resources
- `ReadOnlyAuditors` -- read-only access for compliance
- `BillingTeam` -- access to billing and cost management

[TODO: Show a diagram of users belonging to multiple groups with combined permissions]

---

## Roles

An **IAM role** is an identity with specific permissions that can be **assumed** by trusted entities. Unlike a user, a role does not have long-term credentials (password or access keys). Instead, when a role is assumed, AWS provides **temporary security credentials** via STS.

### Who Can Assume a Role?

| Trusted Entity | Example Use Case |
|---|---|
| AWS service | EC2 instance accessing S3, Lambda function writing to DynamoDB |
| IAM user (same account) | Developer temporarily assuming an admin role |
| IAM user (different account) | Cross-account access for a partner or shared service |
| Federated user (SAML/OIDC) | Corporate employees logging in via Active Directory |
| Web identity (Cognito, Google, SocialGraph) | Mobile app users accessing AWS resources |

### Role Components

1. **Trust policy** -- Defines WHO can assume the role (the trusted principal).
2. **Permission policy** -- Defines WHAT the role can do once assumed.
3. **Session duration** -- How long temporary credentials are valid (default 1 hour, max 12 hours).

### Instance Profiles

An **instance profile** is a container for an IAM role that you attach to an EC2 instance. When you assign a role to an EC2 instance, AWS automatically creates an instance profile with the same name.

The EC2 instance metadata service (`http://169.254.169.254/latest/meta-data/iam/`) provides the temporary credentials to applications running on the instance.

**Exam tip:** Never put access keys on an EC2 instance. Always use an IAM role via an instance profile.

[TODO: Explain the difference between instance profile and role in more detail -- they are often conflated]

---

## Policies

A **policy** is a JSON document that defines permissions. Policies are the mechanism that actually grants or denies access.

### Policy Types (in order of evaluation precedence context)

| Policy Type | Attached To | Purpose |
|---|---|---|
| **Service Control Policy (SCP)** | AWS Organization OU or account | Guardrails -- restricts the maximum permissions available |
| **Permission boundary** | IAM user or role | Limits the maximum permissions an entity can have |
| **Identity-based policy** | IAM user, group, or role | Grants permissions to the identity |
| **Resource-based policy** | AWS resource (S3 bucket, SQS queue, etc.) | Grants permissions to principals directly on the resource |
| **Session policy** | STS session | Limits permissions for a specific session |
| **Access control list (ACL)** | S3 bucket or object, VPC subnet | Legacy mechanism -- generally prefer policies instead |

### Identity-Based Policies: Managed vs. Inline

| Aspect | AWS Managed Policy | Customer Managed Policy | Inline Policy |
|---|---|---|---|
| Created by | AWS | You | You |
| Reusable | Yes (attach to many entities) | Yes | No (embedded in a single entity) |
| Versioned | Yes (AWS manages) | Yes (up to 5 versions) | No |
| Use case | Common permissions (e.g., ReadOnlyAccess) | Organization-specific permissions | Strict 1:1 relationship between policy and entity |

### Policy Document Structure

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowS3ReadAccess",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::my-bucket",
        "arn:aws:s3:::my-bucket/*"
      ],
      "Condition": {
        "StringEquals": {
          "aws:RequestedRegion": "us-east-1"
        }
      }
    }
  ]
}
```

**Statement elements:**

| Element | Required? | Description |
|---|---|---|
| `Version` | Yes | Always use `"2012-10-17"` (the current policy language version) |
| `Statement` | Yes | Array of individual permission statements |
| `Sid` | No | Optional human-readable identifier |
| `Effect` | Yes | `"Allow"` or `"Deny"` |
| `Action` | Yes | The API action(s) -- e.g., `s3:GetObject`, `ec2:RunInstances` |
| `Resource` | Yes* | The ARN(s) of the resources the action applies to. (* Not required for resource-based policies that imply the resource.) |
| `Condition` | No | Optional conditions that must be true for the statement to apply |
| `Principal` | Only in resource-based policies | WHO the policy applies to |

### Common Condition Keys

| Condition Key | What It Checks |
|---|---|
| `aws:SourceIp` | The IP address of the requester |
| `aws:RequestedRegion` | The Region the API call targets |
| `aws:PrincipalTag/<key>` | Tag on the IAM principal making the request |
| `aws:ResourceTag/<key>` | Tag on the resource being accessed |
| `aws:MultiFactorAuthPresent` | Whether MFA was used for authentication |
| `s3:prefix` | The prefix in an S3 list request |
| `ec2:ResourceTag/<key>` | Tag on an EC2 resource |

[TODO: Add more condition key examples and a section on policy variables like `${aws:username}`]

---

## Policy Evaluation Logic

Understanding how AWS evaluates policies is critical for the exam. Here is the evaluation flow:

### The Decision Algorithm (Simplified)

1. **Start with an implicit DENY** -- By default, everything is denied.
2. **Evaluate all applicable policies** (SCPs, permission boundaries, identity-based, resource-based, session policies).
3. **If any explicit DENY exists, the request is DENIED.** Explicit deny always wins.
4. **If an ALLOW exists (and no explicit deny), the request is ALLOWED.**
5. **If neither allow nor deny, the request is DENIED** (implicit deny).

### The Full Evaluation Order

```
Request arrives
    |
    v
Is there an explicit DENY in any policy?
    |-- YES --> DENY (final)
    |-- NO  --> continue
    v
Evaluate SCPs (if in an Organization)
    |-- Does the SCP allow it? NO --> DENY
    |-- YES --> continue
    v
Evaluate Permission Boundaries (if set)
    |-- Does the boundary allow it? NO --> DENY
    |-- YES --> continue
    v
Evaluate Session Policies (if using STS with a session policy)
    |-- Does the session policy allow it? NO --> DENY
    |-- YES --> continue
    v
Evaluate Identity-Based Policies
    |-- Does the identity-based policy allow it? YES --> ALLOW
    |-- NO --> continue
    v
Evaluate Resource-Based Policies
    |-- Does the resource-based policy allow it? YES --> ALLOW
    |-- NO --> DENY (implicit)
```

### Key Gotchas

- **Explicit deny always wins.** No matter how many allow statements exist, a single explicit deny overrides them all.
- **Resource-based policies can grant cross-account access** even without an identity-based policy allowing it (for same-service calls like S3).
- **SCPs do not grant permissions** -- they only restrict them. An SCP that allows `s3:*` does not give S3 access; it just means S3 access is not blocked at the Organization level.
- **Permission boundaries do not grant permissions** -- they only set a ceiling. The effective permissions are the intersection of the boundary and the identity-based policy.

[TODO: Add a worked example showing a request that passes through SCP, permission boundary, and identity policy]
[TODO: Add a Venn diagram showing intersection of permission boundaries and identity policies]

---

## AWS Security Token Service (STS)

STS is the service that provides **temporary security credentials** when a role is assumed or federation occurs.

### Key STS API Calls

| API Call | Use Case |
|---|---|
| `AssumeRole` | Assume a role within your account or cross-account |
| `AssumeRoleWithSAML` | Assume a role using SAML 2.0 federation (e.g., Active Directory) |
| `AssumeRoleWithWebIdentity` | Assume a role using web identity federation (Google, SocialGraph, Cognito) |
| `GetSessionToken` | Get temporary credentials for an IAM user (useful for MFA-protected API access) |
| `GetFederationToken` | Get temporary credentials with a custom policy for a federated user |
| `DecodeAuthorizationMessage` | Decode an encoded authorization failure message for debugging |

### Temporary Credential Characteristics

- Consist of: Access Key ID, Secret Access Key, and a **Session Token**.
- Valid for a configurable duration (15 minutes to 12 hours depending on the call).
- Cannot be revoked individually, but you can revoke all sessions for a role by updating the role's trust policy.

[TODO: Show a Boto3 code example of calling sts.assume_role() and using the returned credentials]

---

## Cross-Account Access

Cross-account access allows a user or role in Account A to access resources in Account B. This is a common pattern for centralized logging, shared services, or partner access.

### How It Works

1. **Account B** (resource owner) creates an IAM role with a trust policy that trusts Account A.
2. **Account A** user or role calls `sts:AssumeRole` targeting the role in Account B.
3. STS returns temporary credentials scoped to the assumed role.
4. The user uses those credentials to access resources in Account B.

### Requirements

- The role in Account B must have a **trust policy** that allows the principal in Account A.
- The principal in Account A must have an **identity-based policy** that allows `sts:AssumeRole` for the role ARN in Account B.
- Both sides must agree -- it is a two-way handshake.

**Exception:** Resource-based policies (e.g., S3 bucket policies) can grant cross-account access without requiring a role assumption. The principal in Account A can directly access the S3 bucket in Account B if the bucket policy allows it.

[TODO: Draw a sequence diagram showing the cross-account role assumption flow]
[TODO: Show the trust policy and identity policy JSON side by side]

---

## AWS Organizations

AWS Organizations is a service for centrally managing multiple AWS accounts.

### Key Concepts

- **Management account** (formerly "master account") -- The account that creates the organization. It pays all bills (consolidated billing) and manages organizational policies.
- **Member accounts** -- All other accounts in the organization.
- **Organizational Units (OUs)** -- Logical groupings of accounts (e.g., `Production`, `Development`, `Security`). OUs can be nested.
- **Root** -- The top-level container for all accounts and OUs.

### Features

| Feature | Description |
|---|---|
| **Consolidated billing** | One bill for all accounts. Volume discounts apply across accounts. |
| **Service Control Policies (SCPs)** | Restrict what services and actions member accounts can use. |
| **Tag policies** | Enforce consistent tagging across accounts. |
| **Backup policies** | Centralize backup management. |
| **AI services opt-out policies** | Control whether AWS can use your data to improve AI services. |

### Organizational Structure Example

**Root**

- Management Account
- OU: Security
  - Log Archive Account
  - Audit Account
- OU: Infrastructure
  - Shared Services Account
- OU: Workloads
  - OU: Production
    - Prod App Account A
    - Prod App Account B
  - OU: Development
    - Dev Account A
    - Sandbox Account


[TODO: Explain the recommended multi-account strategy from AWS -- Security Reference Architecture]

---

## Service Control Policies (SCPs)

SCPs define the **maximum available permissions** for member accounts in an Organization. They are applied at the OU or account level and inherited downward.

### Critical Rules

1. SCPs **do not grant permissions**. They only restrict. You still need identity-based policies to actually allow actions.
2. SCPs **do not affect the management account**. The management account always has full permissions regardless of SCPs.
3. SCPs **affect all users and roles in the account**, including the root user of member accounts.
4. SCPs **are inherited**. An SCP applied to a parent OU applies to all child OUs and accounts.
5. The effective permissions for an account are the **intersection** of all applicable SCPs along the hierarchy.

### SCP Strategies

**Deny list (recommended):**
- Start with the default `FullAWSAccess` SCP (allows everything).
- Attach additional SCPs that explicitly deny specific actions you want to block.
- Example: Deny access to Regions you do not use.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyNonApprovedRegions",
      "Effect": "Deny",
      "Action": "*",
      "Resource": "*",
      "Condition": {
        "StringNotEquals": {
          "aws:RequestedRegion": ["us-east-1", "us-west-2", "eu-west-1"]
        }
      }
    }
  ]
}
```

**Allow list:**
- Remove the default `FullAWSAccess` SCP.
- Explicitly allow only the services and actions you want.
- More restrictive but harder to manage.

[TODO: Add 3-4 common SCP examples: deny root user actions, deny leaving the organization, deny disabling CloudTrail]

---

## AWS Control Tower

Control Tower provides an easy way to set up and govern a secure multi-account AWS environment (a "landing zone").

### Key Concepts

| Concept | Description |
|---|---|
| **Landing Zone** | A well-architected, multi-account environment set up by Control Tower. Includes a management account, log archive account, and audit account. |
| **Guardrails** (now called **Controls**) | Pre-configured governance rules. Can be preventive (SCP-based), detective (AWS Config rule-based), or proactive (CloudFormation hooks). |
| **Account Factory** | Automates provisioning of new accounts with pre-configured settings and guardrails. |
| **Dashboard** | Central view of compliance status across all accounts. |

### Guardrail Types

| Type | Mechanism | Example |
|---|---|---|
| **Preventive** | SCP | "Disallow changes to the log archive bucket" |
| **Detective** | AWS Config rule | "Detect whether MFA is enabled for the root user" |
| **Proactive** | CloudFormation hooks | "Ensure all S3 buckets have versioning enabled at creation time" |

**Exam tip:** Control Tower questions often ask about the easiest way to set up a multi-account governance structure. The answer is almost always Control Tower if it is an option.

[TODO: Explain relationship between Control Tower, Organizations, and SSO/Identity Center]

---

## IAM Best Practices

1. **Lock away the root user** -- MFA, no access keys, use only when required.
2. **Use roles instead of long-term access keys** wherever possible.
3. **Grant least privilege** -- Start with zero permissions and add only what is needed.
4. **Use groups to assign permissions** -- Do not attach policies directly to users.
5. **Enable MFA** for all human users, especially privileged accounts.
6. **Rotate credentials regularly** -- Use IAM credential reports to find old keys.
7. **Use policy conditions** for extra security (e.g., require MFA, restrict by IP, restrict by Region).
8. **Monitor with CloudTrail** -- Log all IAM and STS API calls.
9. **Use IAM Access Analyzer** to identify resources shared with external entities and unused permissions.
10. **Use permission boundaries** when delegating IAM administration.

[TODO: Add a decision flowchart: "How should I grant access to X?" -- user, role, federation, resource-based policy]

---

## Key Takeaways for the SAA-C03 Exam

1. **IAM is global.** Policies, users, roles -- all global.
2. **Explicit deny always wins** in policy evaluation.
3. **Roles are preferred over users for applications and services.** Never hard-code credentials.
4. **SCPs do not grant permissions** and do not affect the management account.
5. **Permission boundaries set a ceiling** -- effective permissions are the intersection of the boundary and the identity policy.
6. **Cross-account access requires a two-way trust** (trust policy on the role + identity policy on the caller) unless using resource-based policies.
7. **STS provides temporary credentials** -- know `AssumeRole`, `AssumeRoleWithSAML`, and `AssumeRoleWithWebIdentity`.
8. **Control Tower is the fastest way to set up a governed multi-account environment.**
9. **Know the policy document structure cold** -- Effect, Action, Resource, Condition.
10. **AWS Organizations enables consolidated billing** -- volume discounts apply across all accounts.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- IAM Overview
- Users
- Groups
- Roles

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
