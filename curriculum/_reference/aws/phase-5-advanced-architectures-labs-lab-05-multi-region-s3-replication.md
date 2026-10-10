# Lab 05: S3 Cross-Region Replication

## Objective

Set up S3 cross-region replication (CRR) between two buckets in different AWS regions. Upload versioned objects and verify that they replicate automatically. Understand replication rules, IAM roles, and versioning requirements.

## Estimated Cost

- **Free to $0.50.** S3 storage for a few test files is negligible. CRR charges for data transfer between regions (~$0.02/GB), but our test data is tiny. Tear down when done.

## Architecture

```
SOURCE REGION (us-east-1)                     DESTINATION REGION (us-west-2)
+---------------------------+                 +---------------------------+
| S3 Bucket                 |   Automatic     | S3 Bucket                 |
| (source-repl-lab-xxx)     |   Replication   | (dest-repl-lab-xxx)       |
|                           | ------------->  |                           |
| Versioning: ENABLED       |   (async,       | Versioning: ENABLED       |
|                           |    usually      |                           |
| Objects uploaded here     |    seconds to   | Replicated objects        |
| are replicated            |    minutes)     | appear here               |
+---------------------------+                 +---------------------------+
```

**Key requirement:** Both source and destination buckets MUST have versioning enabled. Replication does not work without versioning.

---

## Part 1: Create Buckets with CLI

```bash
SUFFIX=$(date +%s)
SOURCE_BUCKET="source-repl-lab-${SUFFIX}"
DEST_BUCKET="dest-repl-lab-${SUFFIX}"
SOURCE_REGION="us-east-1"
DEST_REGION="us-west-2"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create source bucket
aws s3 mb s3://$SOURCE_BUCKET --region $SOURCE_REGION

# Create destination bucket
aws s3 mb s3://$DEST_BUCKET --region $DEST_REGION

# Enable versioning on BOTH buckets (required for replication)
aws s3api put-bucket-versioning \
    --bucket $SOURCE_BUCKET \
    --versioning-configuration Status=Enabled

aws s3api put-bucket-versioning \
    --bucket $DEST_BUCKET \
    --versioning-configuration Status=Enabled

echo "Source bucket: $SOURCE_BUCKET ($SOURCE_REGION)"
echo "Destination bucket: $DEST_BUCKET ($DEST_REGION)"
echo "Versioning enabled on both buckets."
```

---

## Part 2: Create IAM Role for Replication

```bash
# Create the replication role
aws iam create-role \
    --role-name s3-replication-lab-role \
    --assume-role-policy-document '{
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Allow",
            "Principal": {"Service": "s3.amazonaws.com"},
            "Action": "sts:AssumeRole"
        }]
    }'

# Attach replication permissions
aws iam put-role-policy \
    --role-name s3-replication-lab-role \
    --policy-name S3ReplicationPolicy \
    --policy-document "{
        \"Version\": \"2012-10-17\",
        \"Statement\": [
            {
                \"Effect\": \"Allow\",
                \"Action\": [
                    \"s3:GetReplicationConfiguration\",
                    \"s3:ListBucket\"
                ],
                \"Resource\": \"arn:aws:s3:::${SOURCE_BUCKET}\"
            },
            {
                \"Effect\": \"Allow\",
                \"Action\": [
                    \"s3:GetObjectVersionForReplication\",
                    \"s3:GetObjectVersionAcl\",
                    \"s3:GetObjectVersionTagging\"
                ],
                \"Resource\": \"arn:aws:s3:::${SOURCE_BUCKET}/*\"
            },
            {
                \"Effect\": \"Allow\",
                \"Action\": [
                    \"s3:ReplicateObject\",
                    \"s3:ReplicateDelete\",
                    \"s3:ReplicateTags\"
                ],
                \"Resource\": \"arn:aws:s3:::${DEST_BUCKET}/*\"
            }
        ]
    }"

REPL_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/s3-replication-lab-role"
echo "Replication role ARN: $REPL_ROLE_ARN"

sleep 10  # Wait for role propagation
```

---

## Part 3: Configure Replication Rule

```bash
aws s3api put-bucket-replication \
    --bucket $SOURCE_BUCKET \
    --replication-configuration "{
        \"Role\": \"${REPL_ROLE_ARN}\",
        \"Rules\": [
            {
                \"ID\": \"ReplicateAll\",
                \"Status\": \"Enabled\",
                \"Priority\": 1,
                \"Filter\": {},
                \"Destination\": {
                    \"Bucket\": \"arn:aws:s3:::${DEST_BUCKET}\",
                    \"StorageClass\": \"STANDARD\"
                },
                \"DeleteMarkerReplication\": {
                    \"Status\": \"Enabled\"
                }
            }
        ]
    }"

echo "Replication rule configured."

# Verify replication configuration
aws s3api get-bucket-replication --bucket $SOURCE_BUCKET \
    --query 'ReplicationConfiguration.Rules[0].{ID:ID,Status:Status,Destination:Destination.Bucket}'
```

---

## Part 4: Test Replication with Boto3

```python
#!/usr/bin/env python3
"""
S3 Cross-Region Replication Lab - Test Script
Uploads objects to source bucket and verifies replication to destination.
"""

import boto3
import time
import json
from datetime import datetime

# Configuration -- replace with your bucket names
SOURCE_BUCKET = "source-repl-lab-REPLACE_ME"
DEST_BUCKET = "dest-repl-lab-REPLACE_ME"
SOURCE_REGION = "us-east-1"
DEST_REGION = "us-west-2"

s3_source = boto3.client("s3", region_name=SOURCE_REGION)
s3_dest = boto3.client("s3", region_name=DEST_REGION)


def upload_test_files():
    """Upload test files to the source bucket."""
    files = {
        "test/document.txt": "This is a test document for replication.",
        "test/data.json": json.dumps(
            {"message": "Replication test", "timestamp": datetime.utcnow().isoformat()}
        ),
        "test/report.csv": "id,name,value\n1,alpha,100\n2,beta,200\n3,gamma,300",
    }

    print("Uploading files to source bucket...")
    for key, content in files.items():
        s3_source.put_object(
            Bucket=SOURCE_BUCKET,
            Key=key,
            Body=content.encode(),
        )
        print(f"  Uploaded: {key} ({len(content)} bytes)")

    return list(files.keys())


def check_replication(keys, max_wait=120):
    """Wait for objects to replicate and verify."""
    print(f"\nWaiting for replication (checking every 10 seconds, max {max_wait}s)...")

    start = time.time()
    replicated = set()

    while time.time() - start < max_wait and len(replicated) < len(keys):
        for key in keys:
            if key in replicated:
                continue
            try:
                response = s3_dest.head_object(Bucket=DEST_BUCKET, Key=key)
                replicated.add(key)
                print(
                    f"  REPLICATED: {key} "
                    f"(size: {response['ContentLength']} bytes, "
                    f"version: {response.get('VersionId', 'N/A')[:8]})"
                )
            except s3_dest.exceptions.ClientError:
                pass  # Not replicated yet

        if len(replicated) < len(keys):
            time.sleep(10)

    elapsed = time.time() - start
    print(f"\nReplication results ({elapsed:.0f} seconds):")
    print(f"  Replicated: {len(replicated)}/{len(keys)}")

    if len(replicated) < len(keys):
        missing = set(keys) - replicated
        print(f"  Not yet replicated: {missing}")
        print("  (Replication can sometimes take a few minutes)")


def test_versioning():
    """Upload multiple versions and verify version replication."""
    key = "test/versioned-file.txt"
    print(f"\nTesting version replication for: {key}")

    versions = []
    for i in range(3):
        content = f"Version {i + 1} - {datetime.utcnow().isoformat()}"
        response = s3_source.put_object(
            Bucket=SOURCE_BUCKET,
            Key=key,
            Body=content.encode(),
        )
        version_id = response["VersionId"]
        versions.append(version_id)
        print(f"  Uploaded version {i + 1}: {version_id[:8]}")
        time.sleep(1)

    # Wait for replication
    print("  Waiting 30 seconds for version replication...")
    time.sleep(30)

    # Check versions in destination
    dest_versions = s3_dest.list_object_versions(
        Bucket=DEST_BUCKET, Prefix=key
    )

    if "Versions" in dest_versions:
        print(f"  Destination has {len(dest_versions['Versions'])} version(s):")
        for v in dest_versions["Versions"]:
            print(
                f"    Version: {v['VersionId'][:8]}, "
                f"Size: {v['Size']}, "
                f"Modified: {v['LastModified']}"
            )
    else:
        print("  No versions found in destination yet. Replication may still be in progress.")


def check_replication_status():
    """Check the replication status of objects."""
    print("\nChecking replication status on source objects...")
    objects = s3_source.list_objects_v2(Bucket=SOURCE_BUCKET, Prefix="test/")

    for obj in objects.get("Contents", []):
        head = s3_source.head_object(Bucket=SOURCE_BUCKET, Key=obj["Key"])
        status = head.get("ReplicationStatus", "N/A")
        print(f"  {obj['Key']}: ReplicationStatus = {status}")


def main():
    keys = upload_test_files()
    check_replication(keys)
    test_versioning()
    check_replication_status()

    print("\n--- Summary ---")
    print(f"Source bucket: {SOURCE_BUCKET} ({SOURCE_REGION})")
    print(f"Destination bucket: {DEST_BUCKET} ({DEST_REGION})")
    print("Replication is asynchronous. Most objects replicate within seconds to minutes.")


if __name__ == "__main__":
    main()
```

---

## Part 5: Verify with CLI

```bash
# List objects in source bucket
echo "Source bucket objects:"
aws s3 ls s3://$SOURCE_BUCKET/test/ --region $SOURCE_REGION

# List objects in destination bucket (should match after replication)
echo "Destination bucket objects:"
aws s3 ls s3://$DEST_BUCKET/test/ --region $DEST_REGION

# Check replication status on a source object
aws s3api head-object \
    --bucket $SOURCE_BUCKET \
    --key test/document.txt \
    --query '{ReplicationStatus:ReplicationStatus,VersionId:VersionId,ContentLength:ContentLength}'

# List versions of a specific object in both buckets
echo "Source versions:"
aws s3api list-object-versions \
    --bucket $SOURCE_BUCKET \
    --prefix test/versioned-file.txt \
    --query 'Versions[*].{VersionId:VersionId,Size:Size,LastModified:LastModified}'

echo "Destination versions:"
aws s3api list-object-versions \
    --bucket $DEST_BUCKET \
    --prefix test/versioned-file.txt \
    --query 'Versions[*].{VersionId:VersionId,Size:Size,LastModified:LastModified}'
```

---

## Part 6: Test Delete Marker Replication

```bash
# Delete an object in the source (creates a delete marker)
aws s3 rm s3://$SOURCE_BUCKET/test/document.txt

# Wait for replication
sleep 30

# Check if delete marker was replicated
echo "Source delete markers:"
aws s3api list-object-versions \
    --bucket $SOURCE_BUCKET \
    --prefix test/document.txt \
    --query 'DeleteMarkers'

echo "Destination delete markers:"
aws s3api list-object-versions \
    --bucket $DEST_BUCKET \
    --prefix test/document.txt \
    --query 'DeleteMarkers'
```

---

## Important Replication Facts for the Exam

| Fact | Detail |
|---|---|
| Versioning required | Both source and destination must have versioning enabled |
| Existing objects | Objects that existed BEFORE enabling replication are NOT replicated automatically (use S3 Batch Replication) |
| Replication direction | One-way by default. For bidirectional, configure rules on both buckets |
| Same-region replication (SRR) | Also supported (use cases: log aggregation, compliance copies) |
| Cross-account | Supported (destination bucket needs to grant permissions) |
| Storage class override | Can replicate to a different storage class (e.g., S3 IA for cost savings) |
| Replication Time Control (RTC) | Guarantees 99.99% of objects replicate within 15 minutes (additional cost) |
| Delete marker replication | Optional (must be explicitly enabled in the rule) |
| Encryption | Supports SSE-S3, SSE-KMS (with additional KMS permissions), and SSE-C |
| Chaining | NOT supported. If A replicates to B, and B replicates to C, objects in A do NOT automatically reach C |

---

## Cleanup

```bash
# Remove all objects and versions from both buckets
# (Must delete all versions for versioned buckets)

echo "Deleting all object versions from source bucket..."
aws s3api list-object-versions --bucket $SOURCE_BUCKET --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' --output json > /tmp/source-versions.json
aws s3api list-object-versions --bucket $SOURCE_BUCKET --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' --output json > /tmp/source-markers.json

# Delete versions (if any exist)
python3 -c "
import json, subprocess
for f in ['/tmp/source-versions.json', '/tmp/source-markers.json']:
    data = json.load(open(f))
    if data.get('Objects'):
        subprocess.run(['aws', 's3api', 'delete-objects', '--bucket', '$SOURCE_BUCKET', '--delete', json.dumps(data)])
"

echo "Deleting all object versions from destination bucket..."
aws s3api list-object-versions --bucket $DEST_BUCKET --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' --output json > /tmp/dest-versions.json
aws s3api list-object-versions --bucket $DEST_BUCKET --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' --output json > /tmp/dest-markers.json

python3 -c "
import json, subprocess
for f in ['/tmp/dest-versions.json', '/tmp/dest-markers.json']:
    data = json.load(open(f))
    if data.get('Objects'):
        subprocess.run(['aws', 's3api', 'delete-objects', '--bucket', '$DEST_BUCKET', '--delete', json.dumps(data)])
"

# Delete buckets
aws s3 rb s3://$SOURCE_BUCKET --region $SOURCE_REGION
aws s3 rb s3://$DEST_BUCKET --region $DEST_REGION

# Delete IAM role
aws iam delete-role-policy --role-name s3-replication-lab-role --policy-name S3ReplicationPolicy
aws iam delete-role --role-name s3-replication-lab-role

echo "All replication lab resources cleaned up."
```

---

## What You Learned

1. S3 cross-region replication requires versioning on both source and destination buckets.
2. Replication is asynchronous (usually seconds to minutes).
3. Existing objects before replication is enabled are NOT replicated (use S3 Batch Replication).
4. Delete marker replication must be explicitly enabled.
5. Replication requires an IAM role with appropriate S3 permissions.
6. You can override the destination storage class for cost optimization.
7. Replication is NOT chained (A->B->C does not mean A->C).

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Create Buckets with CLI
- Create IAM Role for Replication
- Configure Replication Rule
- Test Replication with Boto3

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
