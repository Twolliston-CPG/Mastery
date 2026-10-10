# 07 — S3 Deep Dive

## Table of Contents
1. [S3 Fundamentals](#s3-fundamentals)
2. [Storage Classes Comparison](#storage-classes-comparison)
3. [Lifecycle Rules](#lifecycle-rules)
4. [Versioning](#versioning)
5. [MFA Delete](#mfa-delete)
6. [Replication (CRR and SRR)](#replication-crr-and-srr)
7. [Encryption](#encryption)
8. [S3 Object Lock](#s3-object-lock)
9. [S3 Access Points](#s3-access-points)
10. [Presigned URLs](#presigned-urls)
11. [S3 Select and Glacier Select](#s3-select-and-glacier-select)
12. [Event Notifications](#event-notifications)
13. [S3 Transfer Acceleration](#s3-transfer-acceleration)
14. [Bucket Policies vs ACLs](#bucket-policies-vs-acls)
15. [Additional S3 Features](#additional-s3-features)
16. [Key Takeaways for the Exam](#key-takeaways-for-the-exam)

---

## S3 Fundamentals

Amazon S3 (Simple Storage Service) is object storage with virtually unlimited capacity. Objects (files) are stored in buckets (containers).

**Key facts:**
- **Object size**: 0 bytes to 5 TB. Multipart upload required for > 5 GB (recommended for > 100 MB).
- **Bucket names**: Globally unique across all AWS accounts. 3-63 characters, lowercase, no underscores.
- **Key**: The full path of the object (e.g., `photos/2024/vacation/img001.jpg`). There are no actual folders — the "/" is part of the key name.
- **Durability**: 99.999999999% (11 nines) for all storage classes.
- **Availability**: Varies by storage class (99.5% to 99.99%).
- **Strong consistency**: All read/write/list operations are strongly consistent as of December 2020.

---

## Storage Classes Comparison

| Storage Class | Availability | Min Storage Duration | Retrieval Fee | Retrieval Time | Price ($/GB/mo, us-east-1) | Use Case |
|---|---|---|---|---|---|---|
| **S3 Standard** | 99.99% | None | None | Immediate | $0.023 | Frequently accessed data, default |
| **S3 Intelligent-Tiering** | 99.9% | None | None (small monitoring fee) | Immediate | $0.023 (frequent) / $0.0125 (infrequent) / $0.004 (archive) | Unknown or changing access patterns |
| **S3 Standard-IA** | 99.9% | 30 days | Per-GB retrieval fee | Immediate | $0.0125 | Infrequent access, but rapid retrieval needed |
| **S3 One Zone-IA** | 99.5% | 30 days | Per-GB retrieval fee | Immediate | $0.01 | Infrequent access, re-creatable data (e.g., thumbnails) |
| **S3 Glacier Instant Retrieval** | 99.9% | 90 days | Per-GB retrieval fee | Immediate (milliseconds) | $0.004 | Archive data needing instant access (once per quarter) |
| **S3 Glacier Flexible Retrieval** | 99.99% | 90 days | Per-GB retrieval fee | Expedited: 1-5 min; Standard: 3-5 hr; Bulk: 5-12 hr | $0.0036 | Archive data, flexible retrieval time |
| **S3 Glacier Deep Archive** | 99.99% | 180 days | Per-GB retrieval fee | Standard: 12 hr; Bulk: 48 hr | $0.00099 | Long-term archive, compliance, lowest cost |

### S3 Intelligent-Tiering — Details

Automatically moves objects between tiers based on access patterns. No retrieval fees.

| Tier | Access Pattern | Storage Cost |
|---|---|---|
| Frequent Access | Recently or frequently accessed | Standard pricing |
| Infrequent Access | Not accessed for 30 days | ~40% cheaper |
| Archive Instant Access | Not accessed for 90 days | ~68% cheaper |
| Archive Access (optional) | Not accessed for 90-730+ days | Glacier pricing |
| Deep Archive Access (optional) | Not accessed for 180-730+ days | Deep Archive pricing |

**Small monitoring and automation fee**: $0.0025 per 1,000 objects/month.

**Exam tip:** If the question says "unpredictable access pattern" or "don't know how often data will be accessed" — S3 Intelligent-Tiering.

---

## Lifecycle Rules

Automate transitioning objects between storage classes or deleting them.

**Two types of actions:**
1. **Transition actions**: Move objects to another storage class after a specified number of days.
2. **Expiration actions**: Delete objects (or old versions) after a specified number of days.

### Transition Waterfall (Allowed Directions)

```
Standard -> Standard-IA -> Intelligent-Tiering -> One Zone-IA -> Glacier Instant -> Glacier Flexible -> Deep Archive
```

**Constraints:**
- Cannot transition from any class to Standard.
- Minimum 30 days in Standard before transitioning to Standard-IA or One Zone-IA.
- Minimum 30 days in Standard-IA before transitioning to Glacier classes (so 60 days total from Standard).
- Objects smaller than 128 KB are not transitioned to IA classes.

### Example Lifecycle Rule (JSON)

```json
{
  "Rules": [
    {
      "ID": "ArchiveOldLogs",
      "Filter": { "Prefix": "logs/" },
      "Status": "Enabled",
      "Transitions": [
        { "Days": 30, "StorageClass": "STANDARD_IA" },
        { "Days": 90, "StorageClass": "GLACIER" },
        { "Days": 365, "StorageClass": "DEEP_ARCHIVE" }
      ],
      "Expiration": { "Days": 2555 }
    }
  ]
}
```

This rule: objects under `logs/` move to Standard-IA after 30 days, Glacier after 90 days, Deep Archive after 365 days, and are deleted after 7 years (2555 days).

---

## Versioning

Keep multiple variants of an object in the same bucket.

- **Enabled at the bucket level**.
- Once enabled, versioning can be **suspended** but not disabled (cannot go back to unversioned).
- Each object version has a unique **Version ID**.
- Deleting an object adds a **delete marker** (the object is not physically deleted). To permanently delete, you must specify the Version ID.
- Versioning protects against accidental deletion and overwrites.
- **Cost implication**: All versions are stored and billed.

**Exam tip:** Versioning is a prerequisite for **replication** and for **MFA Delete**.

---

## MFA Delete

Adds an extra layer of protection by requiring MFA to:
- **Permanently delete** an object version.
- **Suspend versioning** on a bucket.

Does NOT require MFA for:
- Enabling versioning.
- Listing versions.
- Adding a delete marker.

**Requirements:**
- Versioning must be enabled.
- Only the **bucket owner (root account)** can enable/disable MFA Delete.
- Can only be enabled via the CLI or API (not the console).

---

## Replication (CRR and SRR)

### Cross-Region Replication (CRR)

Replicates objects to a bucket in a **different AWS region**.

**Use cases:**
- Compliance (data in multiple regions).
- Lower latency for users in different geographies.
- Disaster recovery.

### Same-Region Replication (SRR)

Replicates objects to a bucket in the **same region**.

**Use cases:**
- Aggregate logs from multiple source buckets.
- Live replication between production and test accounts.
- Data sovereignty (keep data in the same region but separate accounts).

### Replication Requirements and Behaviors

| Feature | Detail |
|---|---|
| Versioning | Must be enabled on **both** source and destination buckets |
| IAM role | Replication requires an IAM role with read access to source and write access to destination |
| Existing objects | **Not replicated** automatically. Use S3 Batch Replication for existing objects. |
| Delete markers | **Not replicated** by default. Can be enabled optionally. |
| Deletions with Version ID | **Never replicated** (prevents malicious deletes from propagating). |
| Chaining | Not supported. Bucket A -> Bucket B -> Bucket C: objects in A replicate to B, but NOT from B to C. |
| Storage class | Can replicate to a different storage class (e.g., source Standard -> destination Standard-IA). |

---

## Encryption

### Server-Side Encryption (SSE)

| Method | Key Management | KMS API Calls | Use Case |
|---|---|---|---|
| **SSE-S3** | AWS manages keys entirely | None | Default, simplest option |
| **SSE-KMS** | AWS KMS manages keys; you control key policy | Yes (count toward KMS quota) | Audit trail (CloudTrail), key rotation control, cross-account access |
| **SSE-C** | Customer provides key with every request | None | Customer requires full key control; keys never stored by AWS |
| **DSSE-KMS** | Dual-layer encryption with KMS | Yes | Compliance requiring two layers of encryption |

### Client-Side Encryption

- Encrypt data **before** uploading to S3.
- AWS never sees the unencrypted data.
- You manage the encryption/decryption process entirely.

### Default Encryption

- As of January 2023, **SSE-S3 is automatically applied** to all new objects if no encryption is specified.
- You can override the default to SSE-KMS.
- Bucket policies can **deny** PutObject requests that do not include a specific encryption header.

### SSE-KMS Considerations

- Each upload/download makes a KMS `GenerateDataKey` / `Decrypt` API call.
- KMS has a **request quota** (5,500 - 30,000 requests/second depending on region).
- High-throughput S3 workloads with SSE-KMS may hit KMS throttling.
- Solution: Use **S3 Bucket Keys** — S3 generates a bucket-level key from KMS, reducing KMS API calls by up to 99%.

**Exam tip:** If a question mentions "audit who accessed the encryption key" or "need CloudTrail logging for key usage" — SSE-KMS. If "customer manages the key and never shares it with AWS" — SSE-C.

---

## S3 Object Lock

Prevents objects from being deleted or overwritten for a fixed period or indefinitely. Requires versioning.

### Retention Modes

| Mode | Behavior |
|---|---|
| **Governance Mode** | Users with special IAM permissions (`s3:BypassGovernanceRetention`) can override the lock. |
| **Compliance Mode** | **No one** (not even the root user) can delete the object or shorten the retention period. |

### Legal Hold

- A separate flag (independent of retention period).
- When enabled, the object cannot be deleted regardless of retention settings.
- Can be applied/removed by users with the `s3:PutObjectLegalHold` permission.

**Exam tip:** "Regulatory requirement, data cannot be deleted by anyone for 7 years" = Compliance Mode. "Protect data during an investigation, may need to release later" = Legal Hold.

---

## S3 Access Points

Simplify managing access to shared S3 buckets with many users or applications.

- Each Access Point has its own **DNS name**, **access point policy**, and **network origin controls**.
- Instead of one complex bucket policy, create an Access Point per application with its own simple policy.
- **VPC Access Points**: Restrict access to only come from a specific VPC (via a VPC endpoint).

### S3 Object Lambda Access Points

- Add a Lambda function between S3 and the application.
- Lambda can transform the data on the fly (e.g., redact PII, resize images, convert formats).
- The application calls the Object Lambda Access Point, which invokes Lambda, which reads from S3.

---

## Presigned URLs

Generate a temporary URL that grants time-limited access to a private S3 object.

- **Inherits the permissions** of the IAM user/role that generated it.
- **Expiration**: Configurable (default 1 hour for console; up to 7 days via CLI with IAM user credentials).
- Use cases: allow a user to download a private file, allow a user to upload a file to a specific key.

```bash
# Generate a presigned URL (expires in 3600 seconds = 1 hour)
aws s3 presign s3://my-bucket/private-file.pdf --expires-in 3600
```

```python
import boto3

s3_client = boto3.client('s3')
url = s3_client.generate_presigned_url(
    'get_object',
    Params={'Bucket': 'my-bucket', 'Key': 'private-file.pdf'},
    ExpiresIn=3600
)
print(url)
```

**Exam tip:** "Allow a temporary download of a private S3 object without making it public" = presigned URL.

---

## S3 Select and Glacier Select

Retrieve a **subset** of data from an object using SQL expressions. S3 filters on the server side, reducing data transfer and cost.

- Supports CSV, JSON, and Apache Parquet formats.
- Can filter rows (`WHERE`) and select columns (`SELECT`).
- Up to 400% faster and 80% cheaper than downloading and processing the full object.

```sql
SELECT s.name, s.age FROM s3object s WHERE s.age > 30
```

**Exam tip:** "Retrieve only specific columns/rows from a large CSV in S3" = S3 Select. For more complex analytics, use Athena.

---

## Event Notifications

S3 can send notifications when certain events occur on objects.

**Supported events:**
- `s3:ObjectCreated:*` (Put, Post, Copy, CompleteMultipartUpload)
- `s3:ObjectRemoved:*` (Delete, DeleteMarkerCreated)
- `s3:ObjectRestore:*` (from Glacier)
- `s3:Replication:*`

**Notification targets:**
- **SNS** topic
- **SQS** queue
- **Lambda** function
- **Amazon EventBridge** (recommended — enables filtering, multiple targets, archive/replay)

### EventBridge vs Direct Notifications

| Feature | Direct (SNS/SQS/Lambda) | EventBridge |
|---|---|---|
| Filtering | By prefix/suffix only | Advanced rules (JSON pattern matching) |
| Targets | 1 per event type | Multiple targets per rule |
| Archive/Replay | No | Yes |
| Cross-account | Manual setup | Built-in |
| Other services | No | Step Functions, Kinesis, etc. |

**Exam tip:** If a question requires "advanced filtering" or "multiple destinations for S3 events" — use EventBridge.

---

## S3 Transfer Acceleration

Speeds up long-distance uploads to S3 by routing through **CloudFront edge locations**.

- Client uploads to the nearest edge location over an optimized AWS backbone network.
- Useful for global users uploading to a single S3 bucket.
- Costs extra: $0.04 - $0.08 per GB.
- Must be enabled on the bucket. Uses a special endpoint: `<bucket>.s3-accelerate.amazonaws.com`.

**When it helps:** Large file uploads (>1 GB), users far from the bucket's region, variable network quality.
**When it does NOT help:** Uploads from the same region as the bucket.

---

## Bucket Policies vs ACLs

### Bucket Policies (Recommended)

- JSON-based policies attached to the bucket.
- Can grant/deny access to IAM users, roles, other accounts, or anonymous users.
- Can enforce conditions (IP range, VPC endpoint, encryption headers, MFA, etc.).
- **Use for**: Cross-account access, enforcing encryption, IP-based restrictions, public access.

### ACLs (Legacy)

- Simpler, less granular than bucket policies.
- Applied at the **bucket level** (Bucket ACL) or **object level** (Object ACL).
- AWS recommends **disabling ACLs** (bucket ownership enforced) for most use cases.
- Object ACLs are still useful when objects are uploaded by other accounts and you need to control ownership.

**Exam tip:** Use **bucket policies** for access control. Avoid ACLs unless the question specifically requires object-level ownership control for cross-account uploads.

### S3 Block Public Access

A set of four settings that override bucket policies and ACLs to prevent public access:

1. `BlockPublicAcls` — Block new public ACLs.
2. `IgnorePublicAcls` — Ignore existing public ACLs.
3. `BlockPublicPolicy` — Block new public bucket policies.
4. `RestrictPublicBuckets` — Restrict access to only AWS services and authorized users for public policies.

Can be set at the **account level** (applies to all buckets) or **bucket level**.

---

## Additional S3 Features

### Multipart Upload
- Required for objects > 5 GB. Recommended for > 100 MB.
- Uploads parts in parallel for better throughput.
- Failed parts can be retried independently.

### S3 Byte-Range Fetches
- Download specific byte ranges of an object in parallel.
- Use case: Speed up downloads, retrieve only a portion (e.g., first 50 bytes for a header).

### Requester Pays
- The requester (not the bucket owner) pays for data transfer and requests.
- Use case: Sharing large public datasets.

---

## Key Takeaways for the Exam

1. **Storage class selection**: Know the retrieval times and minimum storage durations from the comparison table.
2. **Glacier Instant Retrieval**: Millisecond access, cheapest for data accessed once per quarter.
3. **Glacier Flexible Retrieval**: Expedited (1-5 min), Standard (3-5 hr), Bulk (5-12 hr).
4. **Glacier Deep Archive**: Standard (12 hr), Bulk (48 hr). Cheapest storage.
5. **Lifecycle rules**: Automate class transitions and deletions. Know the transition waterfall.
6. **Versioning**: Required for replication and MFA Delete. Delete markers hide objects.
7. **Replication**: Versioning required on both buckets. Existing objects not replicated. No chaining.
8. **SSE-KMS**: Audit trail via CloudTrail, KMS quota can be a bottleneck. Use S3 Bucket Keys to reduce API calls.
9. **SSE-C**: Customer provides key, AWS never stores it.
10. **Object Lock Compliance Mode**: Not even root can delete.
11. **Access Points**: Simplify complex bucket policies. Object Lambda transforms data on read.
12. **Presigned URLs**: Temporary access to private objects.
13. **Event Notifications**: Prefer EventBridge for advanced filtering and multiple targets.
14. **Transfer Acceleration**: Use for long-distance uploads via CloudFront edge locations.
15. **Strong consistency**: All S3 operations are strongly consistent.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- S3 Fundamentals
- Storage Classes Comparison
- Lifecycle Rules
- Versioning

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
