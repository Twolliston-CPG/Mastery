# IAM Cheat Sheet

Quick reference for IAM concepts, policy structure, and key limits.

---

## Core Concepts at a Glance

| Concept | Key Point |
|---|---|
| IAM is **global** | Not Region-specific. Users, roles, policies work everywhere. |
| IAM is **free** | No charge for IAM itself. |
| Root user | Full access. Protect with MFA. Do not use for daily operations. |
| Implicit deny | By default, everything is denied unless explicitly allowed. |
| Explicit deny wins | An explicit Deny overrides any number of Allow statements. |

---

## IAM Entities

| Entity | What It Is | Has Credentials? | Can Be Principal? |
|---|---|---|---|
| **User** | Person or application | Yes (password, access keys) | Yes |
| **Group** | Collection of users | No | **No** (cannot be a principal in a policy) |
| **Role** | Identity with temporary credentials | No (uses STS) | Yes |
| **Policy** | JSON document defining permissions | N/A | N/A |

---

## Policy Types

| Type | Attached To | Grants Permissions? | Restricts Permissions? |
|---|---|---|---|
| Identity-based (managed/inline) | User, Group, Role | Yes | Yes (via Deny) |
| Resource-based | AWS resource (S3, SQS, etc.) | Yes | Yes (via Deny) |
| Permission boundary | User or Role | **No** (ceiling only) | Yes |
| SCP | Organization OU or Account | **No** (ceiling only) | Yes |
| Session policy | STS session | **No** (ceiling only) | Yes |

---

## Policy Document Structure

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "OptionalIdentifier",
      "Effect": "Allow | Deny",
      "Action": "service:Action",
      "Resource": "arn:aws:...",
      "Condition": { "Operator": { "Key": "Value" } }
    }
  ]
}
```

**Required elements:** Version, Statement, Effect, Action, Resource (Resource not required in resource-based policies).

---

## Policy Evaluation Logic (Simplified)

```
1. Start with IMPLICIT DENY
2. Is there an EXPLICIT DENY? --> DENY (game over)
3. Does the SCP allow it?     --> If not, DENY
4. Does the boundary allow it? --> If not, DENY
5. Does any policy ALLOW it?   --> If yes, ALLOW
6. Otherwise                   --> DENY (implicit)
```

**Golden rule:** Explicit Deny > Allow > Implicit Deny

---

## Common Condition Keys

| Condition Key | Use |
|---|---|
| `aws:SourceIp` | Restrict by requester's IP |
| `aws:RequestedRegion` | Restrict by target Region |
| `aws:MultiFactorAuthPresent` | Require MFA |
| `aws:PrincipalTag/tagkey` | Match tag on the caller |
| `aws:ResourceTag/tagkey` | Match tag on the resource |
| `aws:CurrentTime` | Time-based conditions |
| `s3:prefix` | S3 prefix filtering |

---

## Key STS API Calls

| API | Use Case |
|---|---|
| `AssumeRole` | Same-account or cross-account role assumption |
| `AssumeRoleWithSAML` | SAML 2.0 federation (e.g., Active Directory) |
| `AssumeRoleWithWebIdentity` | Web identity (Google, SocialGraph, Cognito) |
| `GetSessionToken` | Temporary creds for an IAM user (MFA-protected access) |

---

## Cross-Account Access

```
Account A (caller)                   Account B (resource owner)
+-----------------------+            +-----------------------+
| IAM user or role      |            | IAM role              |
| Policy:               |  Assumes   | Trust policy:         |
|   Allow sts:AssumeRole|----------->|   Allow Account A     |
|   on role in Acct B   |            | Permission policy:    |
+-----------------------+            |   Allow s3:GetObject  |
                                     +-----------------------+
```

Both sides must agree: trust policy + identity-based policy.

**Exception:** Resource-based policies (e.g., S3 bucket policies) can grant cross-account access without role assumption.

---

## Organizations and SCPs

| Concept | Key Point |
|---|---|
| Management account | Creates the org. Pays all bills. NOT affected by SCPs. |
| SCPs | Restrict max permissions. Do NOT grant permissions. |
| SCP inheritance | Applied to OU or account. Inherited by children. |
| Deny list strategy | Default FullAWSAccess SCP + explicit deny SCPs (recommended). |
| Allow list strategy | Remove default SCP + explicitly allow only what you want. |

---

## IAM Key Limits

| Resource | Limit |
|---|---|
| IAM users per account | 5,000 |
| Groups per account | 300 |
| Groups per user | 10 |
| Managed policies per user/role/group | 10 |
| Inline policy size | 2,048 characters (user), 10,240 (role/group) |
| Managed policy size | 6,144 characters |
| Access keys per user | 2 |
| MFA devices per user | 8 |
| Roles per account | 1,000 (soft limit) |
| Policy versions (customer managed) | 5 |
| Instance profiles per account | 1,000 |

---

## IAM Best Practices Checklist

- [ ] Root user secured with MFA, no access keys.
- [ ] Individual IAM users (no shared accounts).
- [ ] Permissions assigned via groups, not directly to users.
- [ ] Least privilege: start with zero, add what is needed.
- [ ] MFA enabled for all human users.
- [ ] Roles used for applications and services (no hard-coded keys).
- [ ] Access keys rotated regularly (use credential report to audit).
- [ ] CloudTrail enabled for IAM API call logging.
- [ ] IAM Access Analyzer used to find external access and unused permissions.
- [ ] Permission boundaries used when delegating IAM admin rights.

---

## Exam Quick Tips

1. **"How to grant EC2 access to S3?"** --> IAM role + instance profile. NEVER hard-code keys.
2. **"Cross-account access?"** --> IAM role with trust policy + AssumeRole.
3. **"Restrict to specific Region?"** --> Use `aws:RequestedRegion` condition key in policy or SCP.
4. **"Who patches RDS?"** --> AWS. "Who patches EC2 OS?" --> Customer.
5. **"SCPs don't grant permissions"** --> They only set a ceiling. You still need identity-based policies.
6. **"Permission boundary + identity policy?"** --> Effective permissions = intersection (overlap) of both.
7. **"Fastest multi-account governance?"** --> AWS Control Tower.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Core Concepts at a Glance
- IAM Entities
- Policy Types
- Policy Document Structure

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
