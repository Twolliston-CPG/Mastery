# Lab 04 — S3 Operations

## Objective

Create an S3 bucket and configure versioning, lifecycle rules, cross-region replication, server-side encryption, presigned URLs, and event notifications to Lambda. Uses both AWS CLI and Python/Boto3.

## Prerequisites

- AWS CLI configured, Python 3.9+, Boto3 installed.
- Lab 03 completed (familiar with creating Lambda functions).

## Cost Estimate

- **S3 Standard**: 5 GB free for 12 months. 2,000 PUT and 20,000 GET free. This lab uses < 100 objects. **$0.00**
- **Lambda**: Free tier. **$0.00**
- **Cross-region replication** bucket in a second region: negligible for a few small objects (< $0.01).
- **Total: $0.00 - $0.01**

---

## Part 1: Bucket Creation and Versioning (CLI)

### Step 1: Create a Bucket

```bash
# Use a unique bucket name (S3 bucket names are globally unique)
BUCKET_NAME="lab04-saa-$(aws sts get-caller-identity --query Account --output text)-$(date +%s)"
REGION="us-east-1"

aws s3api create-bucket \
  --bucket "$BUCKET_NAME" \
  --region "$REGION"

echo "Bucket created: $BUCKET_NAME"
```

### Step 2: Enable Versioning

```bash
aws s3api put-bucket-versioning \
  --bucket "$BUCKET_NAME" \
  --versioning-configuration Status=Enabled

# Verify
aws s3api get-bucket-versioning --bucket "$BUCKET_NAME"
```

### Step 3: Test Versioning

```bash
# Upload an object
echo "Version 1 content" > test-file.txt
aws s3 cp test-file.txt "s3://$BUCKET_NAME/test-file.txt"

# Upload again with different content (creates a new version)
echo "Version 2 content" > test-file.txt
aws s3 cp test-file.txt "s3://$BUCKET_NAME/test-file.txt"

# Upload a third version
echo "Version 3 content" > test-file.txt
aws s3 cp test-file.txt "s3://$BUCKET_NAME/test-file.txt"

# List all versions
aws s3api list-object-versions \
  --bucket "$BUCKET_NAME" \
  --prefix "test-file.txt" \
  --query "Versions[*].{Key:Key,VersionId:VersionId,IsLatest:IsLatest,LastModified:LastModified,Size:Size}"

# Download a specific version
OLDEST_VERSION=$(aws s3api list-object-versions \
  --bucket "$BUCKET_NAME" \
  --prefix "test-file.txt" \
  --query "Versions[-1].VersionId" --output text)

aws s3api get-object \
  --bucket "$BUCKET_NAME" \
  --key "test-file.txt" \
  --version-id "$OLDEST_VERSION" \
  version1-restored.txt

cat version1-restored.txt
# Should show "Version 1 content"

# Delete the object (creates a delete marker)
aws s3 rm "s3://$BUCKET_NAME/test-file.txt"

# The object appears deleted, but versions still exist
aws s3api list-object-versions \
  --bucket "$BUCKET_NAME" \
  --prefix "test-file.txt" \
  --query "{Versions:Versions[*].VersionId, DeleteMarkers:DeleteMarkers[*].VersionId}"
```

---

## Part 2: Lifecycle Rules (CLI)

```bash
# Create a lifecycle rule
cat > lifecycle-rules.json << 'EOF'
{
  "Rules": [
    {
      "ID": "TransitionAndExpire",
      "Filter": { "Prefix": "logs/" },
      "Status": "Enabled",
      "Transitions": [
        { "Days": 30, "StorageClass": "STANDARD_IA" },
        { "Days": 90, "StorageClass": "GLACIER" }
      ],
      "Expiration": { "Days": 365 },
      "NoncurrentVersionTransitions": [
        { "NoncurrentDays": 30, "StorageClass": "STANDARD_IA" }
      ],
      "NoncurrentVersionExpiration": { "NoncurrentDays": 90 }
    }
  ]
}
EOF

aws s3api put-bucket-lifecycle-configuration \
  --bucket "$BUCKET_NAME" \
  --lifecycle-configuration file://lifecycle-rules.json

# Verify
aws s3api get-bucket-lifecycle-configuration --bucket "$BUCKET_NAME"

# Upload test objects to the logs/ prefix
for i in 1 2 3; do
  echo "Log entry $i" | aws s3 cp - "s3://$BUCKET_NAME/logs/log-$i.txt"
done
echo "3 log files uploaded to logs/ prefix"
```

---

## Part 3: Encryption (CLI)

### SSE-S3 (Default)

```bash
# All objects are encrypted with SSE-S3 by default since Jan 2023
# But you can also set it explicitly as the bucket default
aws s3api put-bucket-encryption \
  --bucket "$BUCKET_NAME" \
  --server-side-encryption-configuration '{
    "Rules": [
      {
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        },
        "BucketKeyEnabled": false
      }
    ]
  }'

# Upload and check encryption
echo "SSE-S3 encrypted file" | aws s3 cp - "s3://$BUCKET_NAME/encrypted-sse-s3.txt"
aws s3api head-object --bucket "$BUCKET_NAME" --key "encrypted-sse-s3.txt" \
  --query "ServerSideEncryption"
# Should return "AES256"
```

### SSE-KMS

```bash
# Switch default encryption to SSE-KMS (using the default aws/s3 KMS key)
aws s3api put-bucket-encryption \
  --bucket "$BUCKET_NAME" \
  --server-side-encryption-configuration '{
    "Rules": [
      {
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "aws:kms",
          "KMSMasterKeyID": "alias/aws/s3"
        },
        "BucketKeyEnabled": true
      }
    ]
  }'

# Upload and check
echo "SSE-KMS encrypted file" | aws s3 cp - "s3://$BUCKET_NAME/encrypted-sse-kms.txt"
aws s3api head-object --bucket "$BUCKET_NAME" --key "encrypted-sse-kms.txt" \
  --query "{Encryption:ServerSideEncryption,KeyId:SSEKMSKeyId,BucketKeyEnabled:BucketKeyEnabled}"
# Should return "aws:kms" and the KMS key ARN

# Revert to SSE-S3 for simplicity
aws s3api put-bucket-encryption \
  --bucket "$BUCKET_NAME" \
  --server-side-encryption-configuration '{
    "Rules": [
      {
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        }
      }
    ]
  }'
```

---

## Part 4: Presigned URLs (CLI + Boto3)

### CLI

```bash
# Generate a presigned URL for download (1 hour expiry)
echo "Secret document content" | aws s3 cp - "s3://$BUCKET_NAME/private/document.txt"

PRESIGNED_URL=$(aws s3 presign "s3://$BUCKET_NAME/private/document.txt" --expires-in 3600)
echo "Presigned URL: $PRESIGNED_URL"

# Test it (works without AWS credentials)
curl -s "$PRESIGNED_URL"
```

### Boto3

```python
#!/usr/bin/env python3
"""Generate presigned URLs for upload and download."""

import boto3
import requests

BUCKET_NAME = "YOUR_BUCKET_NAME"  # Replace with your bucket name

s3_client = boto3.client('s3')

# Presigned URL for download
download_url = s3_client.generate_presigned_url(
    'get_object',
    Params={'Bucket': BUCKET_NAME, 'Key': 'private/document.txt'},
    ExpiresIn=3600,
)
print(f"Download URL: {download_url}")

# Test download
response = requests.get(download_url)
print(f"Download status: {response.status_code}")
print(f"Content: {response.text}")

# Presigned URL for upload
upload_url = s3_client.generate_presigned_url(
    'put_object',
    Params={'Bucket': BUCKET_NAME, 'Key': 'uploads/user-file.txt'},
    ExpiresIn=3600,
)
print(f"\nUpload URL: {upload_url}")

# Test upload
response = requests.put(upload_url, data="Uploaded via presigned URL!")
print(f"Upload status: {response.status_code}")

# Verify the upload
obj = s3_client.get_object(Bucket=BUCKET_NAME, Key='uploads/user-file.txt')
print(f"Uploaded content: {obj['Body'].read().decode()}")
```

---

## Part 5: Event Notifications to Lambda (CLI)

### Step 1: Create a Lambda Function for S3 Events

```bash
# Lambda code that logs S3 events
cat > s3_event_handler.py << 'PYEOF'
import json

def lambda_handler(event, context):
    for record in event['Records']:
        bucket = record['s3']['bucket']['name']
        key = record['s3']['object']['key']
        size = record['s3']['object'].get('size', 0)
        event_name = record['eventName']
        print(f"Event: {event_name} | Bucket: {bucket} | Key: {key} | Size: {size}")
    return {'statusCode': 200, 'body': 'Processed'}
PYEOF

zip s3_event_handler.zip s3_event_handler.py

# Reuse the Lambda role from Lab 03 or create a new one
ROLE_ARN=$(aws iam get-role --role-name lab03-lambda-execution-role \
  --query "Role.Arn" --output text 2>/dev/null)

if [ -z "$ROLE_ARN" ] || [ "$ROLE_ARN" == "None" ]; then
  echo "Creating new Lambda role..."
  cat > lambda-trust.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "lambda.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }]
}
EOF
  ROLE_ARN=$(aws iam create-role \
    --role-name lab04-lambda-role \
    --assume-role-policy-document file://lambda-trust.json \
    --query "Role.Arn" --output text)
  aws iam attach-role-policy \
    --role-name lab04-lambda-role \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
  sleep 10
fi

LAMBDA_ARN=$(aws lambda create-function \
  --function-name lab04-s3-event-handler \
  --runtime python3.12 \
  --role "$ROLE_ARN" \
  --handler s3_event_handler.lambda_handler \
  --zip-file fileb://s3_event_handler.zip \
  --timeout 10 \
  --query "FunctionArn" --output text)

echo "Lambda ARN: $LAMBDA_ARN"
```

### Step 2: Grant S3 Permission to Invoke Lambda

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

aws lambda add-permission \
  --function-name lab04-s3-event-handler \
  --statement-id s3-invoke \
  --action lambda:InvokeFunction \
  --principal s3.amazonaws.com \
  --source-arn "arn:aws:s3:::$BUCKET_NAME" \
  --source-account "$ACCOUNT_ID"
```

### Step 3: Configure Bucket Notification

```bash
cat > notification-config.json << EOF
{
  "LambdaFunctionConfigurations": [
    {
      "Id": "NotifyOnUpload",
      "LambdaFunctionArn": "$LAMBDA_ARN",
      "Events": ["s3:ObjectCreated:*"],
      "Filter": {
        "Key": {
          "FilterRules": [
            { "Name": "prefix", "Value": "uploads/" }
          ]
        }
      }
    }
  ]
}
EOF

aws s3api put-bucket-notification-configuration \
  --bucket "$BUCKET_NAME" \
  --notification-configuration file://notification-config.json

echo "Event notification configured!"
```

### Step 4: Test the Notification

```bash
# Upload a file to the uploads/ prefix
echo "This should trigger Lambda" | aws s3 cp - "s3://$BUCKET_NAME/uploads/trigger-test.txt"

# Wait a few seconds for Lambda to execute
sleep 5

# Check CloudWatch Logs for the Lambda function
LATEST_STREAM=$(aws logs describe-log-streams \
  --log-group-name /aws/lambda/lab04-s3-event-handler \
  --order-by LastEventTime --descending \
  --query "logStreams[0].logStreamName" --output text)

aws logs get-log-events \
  --log-group-name /aws/lambda/lab04-s3-event-handler \
  --log-stream-name "$LATEST_STREAM" \
  --query "events[*].message" --output text
```

---

## Part 6: Cross-Region Replication (CLI)

```bash
# Create a destination bucket in another region
DEST_BUCKET="${BUCKET_NAME}-replica"
DEST_REGION="us-west-2"

aws s3api create-bucket \
  --bucket "$DEST_BUCKET" \
  --region "$DEST_REGION" \
  --create-bucket-configuration LocationConstraint="$DEST_REGION"

# Enable versioning on the destination (required for replication)
aws s3api put-bucket-versioning \
  --bucket "$DEST_BUCKET" \
  --versioning-configuration Status=Enabled

# Create an IAM role for replication
cat > replication-trust.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "s3.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }]
}
EOF

REPL_ROLE_ARN=$(aws iam create-role \
  --role-name lab04-s3-replication-role \
  --assume-role-policy-document file://replication-trust.json \
  --query "Role.Arn" --output text)

# Create replication policy
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
cat > replication-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetReplicationConfiguration",
        "s3:ListBucket"
      ],
      "Resource": "arn:aws:s3:::$BUCKET_NAME"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObjectVersionForReplication",
        "s3:GetObjectVersionAcl",
        "s3:GetObjectVersionTagging"
      ],
      "Resource": "arn:aws:s3:::$BUCKET_NAME/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:ReplicateObject",
        "s3:ReplicateDelete",
        "s3:ReplicateTags"
      ],
      "Resource": "arn:aws:s3:::$DEST_BUCKET/*"
    }
  ]
}
EOF

aws iam put-role-policy \
  --role-name lab04-s3-replication-role \
  --policy-name s3-replication \
  --policy-document file://replication-policy.json

sleep 10

# Configure replication on the source bucket
cat > replication-config.json << EOF
{
  "Role": "$REPL_ROLE_ARN",
  "Rules": [
    {
      "ID": "ReplicateAll",
      "Status": "Enabled",
      "Filter": { "Prefix": "replicated/" },
      "Destination": {
        "Bucket": "arn:aws:s3:::$DEST_BUCKET",
        "StorageClass": "STANDARD_IA"
      },
      "DeleteMarkerReplication": { "Status": "Disabled" }
    }
  ]
}
EOF

aws s3api put-bucket-replication \
  --bucket "$BUCKET_NAME" \
  --replication-configuration file://replication-config.json

echo "Replication configured! Only NEW objects under replicated/ will be replicated."

# Test replication
echo "This will be replicated" | aws s3 cp - "s3://$BUCKET_NAME/replicated/test-repl.txt"
sleep 30

# Check the destination bucket
aws s3 ls "s3://$DEST_BUCKET/replicated/"
```

---

## Teardown (IMPORTANT)

```bash
# Remove all objects and versions from the source bucket
aws s3api list-object-versions --bucket "$BUCKET_NAME" \
  --query "{Objects: Versions[].{Key:Key,VersionId:VersionId}}" --output json > versions.json
aws s3api delete-objects --bucket "$BUCKET_NAME" --delete file://versions.json 2>/dev/null

aws s3api list-object-versions --bucket "$BUCKET_NAME" \
  --query "{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}" --output json > markers.json
aws s3api delete-objects --bucket "$BUCKET_NAME" --delete file://markers.json 2>/dev/null

# Delete the source bucket
aws s3api delete-bucket --bucket "$BUCKET_NAME"

# Empty and delete the replica bucket
aws s3 rm "s3://$DEST_BUCKET" --recursive
aws s3api list-object-versions --bucket "$DEST_BUCKET" \
  --query "{Objects: Versions[].{Key:Key,VersionId:VersionId}}" --output json > versions2.json
aws s3api delete-objects --bucket "$DEST_BUCKET" --delete file://versions2.json 2>/dev/null
aws s3api delete-bucket --bucket "$DEST_BUCKET"

# Delete Lambda function
aws lambda delete-function --function-name lab04-s3-event-handler
aws logs delete-log-group --log-group-name /aws/lambda/lab04-s3-event-handler 2>/dev/null

# Delete replication IAM role
aws iam delete-role-policy --role-name lab04-s3-replication-role --policy-name s3-replication
aws iam delete-role --role-name lab04-s3-replication-role

# Clean up local files
rm -f test-file.txt version1-restored.txt lifecycle-rules.json notification-config.json
rm -f s3_event_handler.py s3_event_handler.zip lambda-trust.json
rm -f replication-trust.json replication-policy.json replication-config.json
rm -f versions.json markers.json versions2.json

echo "Teardown complete!"
```

---

## Verification Checklist

- [ ] S3 bucket created with versioning enabled.
- [ ] Multiple versions of an object uploaded and listed.
- [ ] Delete marker created and older version retrieved.
- [ ] Lifecycle rules configured for the logs/ prefix.
- [ ] SSE-S3 and SSE-KMS encryption tested.
- [ ] Presigned URL generated and used for download.
- [ ] S3 event notification triggers Lambda on uploads/ prefix.
- [ ] Lambda CloudWatch logs show the S3 event details.
- [ ] Cross-region replication configured and verified.
- [ ] All resources torn down.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Bucket Creation and Versioning (CLI)
- Lifecycle Rules (CLI)
- Encryption (CLI)
- Presigned URLs (CLI + Boto3)

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
