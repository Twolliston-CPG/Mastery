# Lab 01 — KMS Encryption

## Objective

Create a KMS customer managed key, use it to encrypt and decrypt data with Boto3, encrypt S3 objects with SSE-KMS, and encrypt an EBS volume. This lab reinforces envelope encryption and KMS integration with AWS services.

## Prerequisites

- AWS CLI configured with credentials
- Python 3.9+ with `boto3` installed
- Phase 1-3 complete (basic S3 and EC2 knowledge)

## Estimated Time: 60-90 minutes

## Cost Estimate

| Resource | Cost | Notes |
|----------|------|-------|
| KMS key | $1/month (prorated) | Delete after lab to stop charges |
| KMS API calls | ~$0.01 | Well within free tier (20K free requests/month) |
| S3 storage | Free tier | Tiny objects |
| EBS volume | Free tier | 30 GB free per month |
| **Total** | **~$0.03** | Delete KMS key after lab |

---

## Part 1: Create a KMS Key (CLI)

### Step 1.1 — Create a Symmetric KMS Key

```bash
# Create the key
aws kms create-key \
  --description "SAA Lab - Customer Managed Key" \
  --key-usage ENCRYPT_DECRYPT \
  --key-spec SYMMETRIC_DEFAULT \
  --tags TagKey=Purpose,TagValue=SAA-Lab

# Save the KeyId from the output — you will need it throughout this lab
# Example: "KeyId": "12345678-abcd-efgh-ijkl-123456789012"
```

### Step 1.2 — Create an Alias (Friendly Name)

```bash
# Replace <KEY_ID> with your actual KeyId
aws kms create-alias \
  --alias-name alias/saa-lab-key \
  --target-key-id <KEY_ID>
```

### Step 1.3 — Verify the Key

```bash
# Describe the key
aws kms describe-key --key-id alias/saa-lab-key

# List all keys in the account
aws kms list-keys

# List aliases
aws kms list-aliases --query "Aliases[?starts_with(AliasName, 'alias/saa')]"
```

### Step 1.4 — View the Key Policy

```bash
aws kms get-key-policy --key-id alias/saa-lab-key --policy-name default
```

Examine the output. Notice the default policy allows the root account full access.

---

## Part 2: Encrypt and Decrypt Small Data with KMS API (Boto3)

This demonstrates direct KMS encryption (for data up to 4 KB).

### Step 2.1 — Create the Script

Create a file called `kms_encrypt_decrypt.py`:

```python
"""
KMS Direct Encryption/Decryption Demo
Encrypts and decrypts a small piece of data (< 4 KB) using KMS directly.
"""

import boto3
import base64

def main():
    kms = boto3.client("kms")
    key_alias = "alias/saa-lab-key"

    # ---- ENCRYPT ----
    plaintext = "This is my secret data for the SAA-C03 lab!"
    print(f"Original plaintext: {plaintext}")
    print(f"Plaintext size: {len(plaintext.encode())} bytes")

    encrypt_response = kms.encrypt(
        KeyId=key_alias,
        Plaintext=plaintext.encode("utf-8")
    )

    ciphertext_blob = encrypt_response["CiphertextBlob"]
    print(f"\nEncrypted (base64): {base64.b64encode(ciphertext_blob).decode()[:80]}...")
    print(f"Encryption algorithm: {encrypt_response['EncryptionAlgorithm']}")
    print(f"Key ID used: {encrypt_response['KeyId']}")

    # ---- DECRYPT ----
    decrypt_response = kms.decrypt(
        CiphertextBlob=ciphertext_blob
    )
    # Note: We do NOT need to specify the KeyId for decryption of symmetric keys.
    # KMS stores the key ID in the ciphertext metadata.

    decrypted_text = decrypt_response["Plaintext"].decode("utf-8")
    print(f"\nDecrypted plaintext: {decrypted_text}")
    print(f"Key ID used for decryption: {decrypt_response['KeyId']}")

    assert decrypted_text == plaintext, "Decryption failed!"
    print("\nSUCCESS: Plaintext matches after encrypt/decrypt cycle.")

if __name__ == "__main__":
    main()
```

### Step 2.2 — Run It

```bash
python kms_encrypt_decrypt.py
```

### Checkpoint Questions
- Why did we NOT need to specify the key ID during decryption?
- What is the maximum size of data you can encrypt with `kms.encrypt()`?

---

## Part 3: Envelope Encryption with GenerateDataKey (Boto3)

This demonstrates how to encrypt data larger than 4 KB.

### Step 3.1 — Create the Script

Create a file called `envelope_encryption.py`:

```python
"""
Envelope Encryption Demo
Uses KMS GenerateDataKey to encrypt a file larger than 4 KB.
"""

import boto3
import os
from cryptography.fernet import Fernet
import base64
import hashlib
import json

def generate_fernet_key_from_data_key(data_key_plaintext):
    """Convert a KMS data key to a Fernet-compatible key."""
    # Fernet requires a 32-byte key, URL-safe base64-encoded
    key_hash = hashlib.sha256(data_key_plaintext).digest()
    return base64.urlsafe_b64encode(key_hash)

def encrypt_file(kms_client, key_alias, input_data):
    """Encrypt data using envelope encryption."""
    # Step 1: Generate a data key from KMS
    response = kms_client.generate_data_key(
        KeyId=key_alias,
        KeySpec="AES_256"
    )
    plaintext_data_key = response["Plaintext"]
    encrypted_data_key = response["CiphertextBlob"]

    print(f"Generated data key (encrypted size: {len(encrypted_data_key)} bytes)")

    # Step 2: Use the plaintext data key to encrypt the data locally
    fernet_key = generate_fernet_key_from_data_key(plaintext_data_key)
    fernet = Fernet(fernet_key)
    encrypted_data = fernet.encrypt(input_data.encode("utf-8"))

    print(f"Encrypted data size: {len(encrypted_data)} bytes")

    # Step 3: IMMEDIATELY discard the plaintext data key
    del plaintext_data_key
    del fernet_key
    print("Plaintext data key deleted from memory.")

    # Step 4: Return the encrypted data key + encrypted data (stored together)
    envelope = {
        "encrypted_data_key": base64.b64encode(encrypted_data_key).decode(),
        "encrypted_data": base64.b64encode(encrypted_data).decode()
    }
    return envelope

def decrypt_file(kms_client, envelope):
    """Decrypt data using envelope decryption."""
    encrypted_data_key = base64.b64decode(envelope["encrypted_data_key"])
    encrypted_data = base64.b64decode(envelope["encrypted_data"])

    # Step 1: Decrypt the data key using KMS
    response = kms_client.decrypt(CiphertextBlob=encrypted_data_key)
    plaintext_data_key = response["Plaintext"]

    print(f"Data key decrypted by KMS (key: {response['KeyId'][:40]}...)")

    # Step 2: Use the plaintext data key to decrypt the data locally
    fernet_key = generate_fernet_key_from_data_key(plaintext_data_key)
    fernet = Fernet(fernet_key)
    decrypted_data = fernet.decrypt(encrypted_data).decode("utf-8")

    # Step 3: Discard the plaintext data key
    del plaintext_data_key
    del fernet_key
    print("Plaintext data key deleted from memory.")

    return decrypted_data

def main():
    kms = boto3.client("kms")
    key_alias = "alias/saa-lab-key"

    # Create some data larger than 4 KB
    large_data = "SAA-C03 study notes: " + ("Security is 30% of the exam. " * 200)
    print(f"Original data size: {len(large_data)} bytes ({len(large_data)/1024:.1f} KB)")
    print(f"First 80 chars: {large_data[:80]}...")

    # Encrypt using envelope encryption
    print("\n--- ENCRYPTING ---")
    envelope = encrypt_file(kms, key_alias, large_data)

    # Save envelope to a file (simulating storage)
    with open("/tmp/encrypted_envelope.json", "w") as f:
        json.dump(envelope, f)
    print(f"Envelope saved to /tmp/encrypted_envelope.json")

    # Decrypt
    print("\n--- DECRYPTING ---")
    with open("/tmp/encrypted_envelope.json", "r") as f:
        loaded_envelope = json.load(f)

    decrypted = decrypt_file(kms, loaded_envelope)
    print(f"Decrypted data size: {len(decrypted)} bytes")
    print(f"First 80 chars: {decrypted[:80]}...")

    assert decrypted == large_data, "Decryption failed!"
    print("\nSUCCESS: Envelope encryption/decryption verified.")

if __name__ == "__main__":
    main()
```

### Step 3.2 — Install Dependency and Run

```bash
pip install cryptography
python envelope_encryption.py
```

### Checkpoint Questions
- Why do we delete the plaintext data key from memory immediately after encryption?
- Which part of the envelope encryption happens locally vs in KMS?
- What would happen if we lost the KMS CMK?

---

## Part 4: Encrypt S3 Objects with SSE-KMS (CLI + Boto3)

### Step 4.1 — Create an S3 Bucket

```bash
BUCKET_NAME="saa-lab-kms-$(date +%s)"
aws s3 mb s3://$BUCKET_NAME
echo "Bucket created: $BUCKET_NAME"
```

### Step 4.2 — Upload with SSE-KMS (CLI)

```bash
# Create a test file
echo "This file is encrypted with SSE-KMS using our custom CMK" > /tmp/kms-test.txt

# Upload with SSE-KMS using our key
aws s3 cp /tmp/kms-test.txt s3://$BUCKET_NAME/kms-test.txt \
  --sse aws:kms \
  --sse-kms-key-id alias/saa-lab-key

# Verify the encryption
aws s3api head-object --bucket $BUCKET_NAME --key kms-test.txt
# Look for "ServerSideEncryption": "aws:kms" and "SSEKMSKeyId" in the output
```

### Step 4.3 — Upload with SSE-KMS (Boto3)

```python
import boto3

s3 = boto3.client("s3")
kms = boto3.client("kms")

# Get the key ARN
key_info = kms.describe_key(KeyId="alias/saa-lab-key")
key_arn = key_info["KeyMetadata"]["Arn"]

bucket_name = "YOUR_BUCKET_NAME"  # Replace with your bucket name

# Upload with SSE-KMS
s3.put_object(
    Bucket=bucket_name,
    Key="boto3-encrypted.txt",
    Body=b"Encrypted by Boto3 using SSE-KMS",
    ServerSideEncryption="aws:kms",
    SSEKMSKeyId=key_arn
)
print("Object uploaded with SSE-KMS encryption")

# Download and verify
response = s3.get_object(Bucket=bucket_name, Key="boto3-encrypted.txt")
content = response["Body"].read().decode("utf-8")
print(f"Decrypted content: {content}")
print(f"Encryption: {response['ServerSideEncryption']}")
print(f"KMS Key: {response['SSEKMSKeyId']}")
```

### Step 4.4 — Set Default Bucket Encryption to SSE-KMS

```bash
KEY_ARN=$(aws kms describe-key --key-id alias/saa-lab-key --query "KeyMetadata.Arn" --output text)

aws s3api put-bucket-encryption \
  --bucket $BUCKET_NAME \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "aws:kms",
        "KMSMasterKeyID": "'$KEY_ARN'"
      },
      "BucketKeyEnabled": true
    }]
  }'

echo "Default encryption set to SSE-KMS with Bucket Key enabled"
```

**Note:** BucketKeyEnabled reduces KMS API costs by using a bucket-level key.

---

## Part 5: Encrypt an EBS Volume

### Step 5.1 — Create an Encrypted EBS Volume (CLI)

```bash
# Create a 1 GB encrypted EBS volume using our KMS key
KEY_ARN=$(aws kms describe-key --key-id alias/saa-lab-key --query "KeyMetadata.Arn" --output text)

aws ec2 create-volume \
  --availability-zone us-east-1a \
  --size 1 \
  --volume-type gp3 \
  --encrypted \
  --kms-key-id $KEY_ARN \
  --tag-specifications 'ResourceType=volume,Tags=[{Key=Name,Value=saa-lab-encrypted-volume}]'

# Verify encryption
# Save the VolumeId from the output, then:
aws ec2 describe-volumes \
  --filters "Name=tag:Name,Values=saa-lab-encrypted-volume" \
  --query "Volumes[0].{Encrypted:Encrypted,KmsKeyId:KmsKeyId,State:State}"
```

---

## Cleanup

**Important: Clean up to avoid charges.**

```bash
# 1. Delete S3 objects and bucket
aws s3 rm s3://$BUCKET_NAME --recursive
aws s3 rb s3://$BUCKET_NAME

# 2. Delete EBS volume
VOLUME_ID=$(aws ec2 describe-volumes --filters "Name=tag:Name,Values=saa-lab-encrypted-volume" --query "Volumes[0].VolumeId" --output text)
aws ec2 delete-volume --volume-id $VOLUME_ID

# 3. Schedule KMS key deletion (minimum 7 days waiting period)
KEY_ID=$(aws kms describe-key --key-id alias/saa-lab-key --query "KeyMetadata.KeyId" --output text)
aws kms schedule-key-deletion --key-id $KEY_ID --pending-window-in-days 7

# 4. Delete alias
aws kms delete-alias --alias-name alias/saa-lab-key

# 5. Clean up temp files
rm -f /tmp/kms-test.txt /tmp/encrypted_envelope.json
```

---

## Review Questions

1. What is the maximum data size you can encrypt directly with the KMS `Encrypt` API?
2. In envelope encryption, which key encrypts the data, and which key encrypts the data key?
3. Why do you NOT need to specify the key ID when decrypting data with a symmetric KMS key?
4. What is the benefit of enabling S3 Bucket Keys with SSE-KMS?
5. Can you delete a KMS key immediately?

## Answers

1. 4 KB
2. The data key encrypts the data; the CMK (KMS key) encrypts the data key.
3. The key ID is stored as metadata in the ciphertext blob.
4. Reduces the number of KMS API calls (and thus cost) by generating a bucket-level key.
5. No — minimum 7-day waiting period (configurable up to 30 days). During this period, the key is disabled but not deleted.

---

## Next Lab

Proceed to **Lab 02: Secrets Management** to work with Secrets Manager and SSM Parameter Store.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Estimated Time: 60-90 minutes
- Create a KMS Key (CLI)
- Encrypt and Decrypt Small Data with KMS API (Boto3)
- Envelope Encryption with GenerateDataKey (Boto3)

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
