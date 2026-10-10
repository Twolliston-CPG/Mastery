# Lab 02 — Secrets Management (Secrets Manager + SSM Parameter Store)

## Objective

Store a secret in Secrets Manager, retrieve it with Lambda (Boto3), store parameters in SSM Parameter Store, and compare the two workflows side by side. This lab builds practical experience with both services.

## Prerequisites

- AWS CLI configured
- Python 3.9+ with `boto3`
- Lab 01 complete (KMS key understanding)
- Basic Lambda knowledge (Phase 2)

## Estimated Time: 60-75 minutes

## Cost Estimate

| Resource | Cost | Notes |
|----------|------|-------|
| Secrets Manager | $0.40/secret/month (prorated) | Delete after lab |
| SSM Parameter Store | Free (standard tier) | No cost |
| Lambda invocations | Free tier | Well within free tier |
| **Total** | **~$0.02** | Delete secret after lab |

---

## Part 1: Secrets Manager — Store and Retrieve Secrets

### Step 1.1 — Create a Secret (CLI)

```bash
# Create a secret that simulates database credentials
aws secretsmanager create-secret \
  --name "saa-lab/database/credentials" \
  --description "SAA Lab - Database credentials for demo app" \
  --secret-string '{"username":"admin","password":"S3cur3P@ssw0rd!","host":"mydb.cluster-abc123.us-east-1.rds.amazonaws.com","port":"5432","dbname":"myapp"}'

# Save the ARN from the output
```

### Step 1.2 — Retrieve the Secret (CLI)

```bash
# Get the secret value
aws secretsmanager get-secret-value \
  --secret-id "saa-lab/database/credentials" \
  --query "SecretString" \
  --output text

# Get secret metadata (without the value)
aws secretsmanager describe-secret \
  --secret-id "saa-lab/database/credentials"
```

### Step 1.3 — Retrieve the Secret (Boto3)

Create a file called `get_secret.py`:

```python
"""
Retrieve a secret from AWS Secrets Manager.
Demonstrates the recommended pattern for applications.
"""

import boto3
import json

def get_secret(secret_name, region="us-east-1"):
    """Retrieve and parse a secret from Secrets Manager."""
    client = boto3.client("secretsmanager", region_name=region)

    try:
        response = client.get_secret_value(SecretId=secret_name)
    except client.exceptions.ResourceNotFoundException:
        print(f"Secret '{secret_name}' not found.")
        return None
    except client.exceptions.AccessDeniedException:
        print(f"Access denied to secret '{secret_name}'. Check IAM permissions.")
        return None

    # Secrets can be stored as string or binary
    if "SecretString" in response:
        secret = json.loads(response["SecretString"])
        return secret
    else:
        # Binary secret
        return response["SecretBinary"]

def main():
    secret_name = "saa-lab/database/credentials"
    creds = get_secret(secret_name)

    if creds:
        print("Secret retrieved successfully!")
        print(f"  Host:     {creds['host']}")
        print(f"  Port:     {creds['port']}")
        print(f"  Database: {creds['dbname']}")
        print(f"  Username: {creds['username']}")
        print(f"  Password: {'*' * len(creds['password'])} (masked)")

        # In a real app, you would use these to connect:
        # connection_string = f"postgresql://{creds['username']}:{creds['password']}@{creds['host']}:{creds['port']}/{creds['dbname']}"

if __name__ == "__main__":
    main()
```

```bash
python get_secret.py
```

### Step 1.4 — Update the Secret

```bash
# Update the password
aws secretsmanager update-secret \
  --secret-id "saa-lab/database/credentials" \
  --secret-string '{"username":"admin","password":"N3wS3cur3P@ss!","host":"mydb.cluster-abc123.us-east-1.rds.amazonaws.com","port":"5432","dbname":"myapp"}'

# View version stages
aws secretsmanager describe-secret \
  --secret-id "saa-lab/database/credentials" \
  --query "VersionIdsToStages"

# Note: AWSCURRENT points to the new version, AWSPREVIOUS to the old one
```

### Step 1.5 — Retrieve a Previous Version

```python
import boto3
import json

client = boto3.client("secretsmanager")

# Get the current version
current = client.get_secret_value(
    SecretId="saa-lab/database/credentials",
    VersionStage="AWSCURRENT"
)
print(f"Current password: {json.loads(current['SecretString'])['password']}")

# Get the previous version
try:
    previous = client.get_secret_value(
        SecretId="saa-lab/database/credentials",
        VersionStage="AWSPREVIOUS"
    )
    print(f"Previous password: {json.loads(previous['SecretString'])['password']}")
except Exception as e:
    print(f"No previous version: {e}")
```

---

## Part 2: SSM Parameter Store — Store and Retrieve Parameters

### Step 2.1 — Create Parameters (CLI)

```bash
# String parameter (plain text config)
aws ssm put-parameter \
  --name "/saa-lab/prod/app/api-url" \
  --type "String" \
  --value "https://api.example.com/v2" \
  --description "Production API URL"

# StringList parameter
aws ssm put-parameter \
  --name "/saa-lab/prod/app/allowed-origins" \
  --type "StringList" \
  --value "https://app.example.com,https://admin.example.com,http://localhost:3000" \
  --description "Allowed CORS origins"

# SecureString parameter (encrypted with default KMS key)
aws ssm put-parameter \
  --name "/saa-lab/prod/db/password" \
  --type "SecureString" \
  --value "MyDbP@ssw0rd123" \
  --description "Database password"

# SecureString with custom KMS key
aws ssm put-parameter \
  --name "/saa-lab/prod/db/api-key" \
  --type "SecureString" \
  --value "sk-abc123def456ghi789" \
  --key-id "alias/saa-lab-key" \
  --description "Third-party API key"

# Additional config parameters for hierarchy demo
aws ssm put-parameter \
  --name "/saa-lab/prod/db/host" \
  --type "String" \
  --value "prod-db.example.com"

aws ssm put-parameter \
  --name "/saa-lab/prod/db/port" \
  --type "String" \
  --value "5432"
```

### Step 2.2 — Retrieve Parameters (CLI)

```bash
# Get a single parameter
aws ssm get-parameter \
  --name "/saa-lab/prod/app/api-url"

# Get a SecureString (decrypted)
aws ssm get-parameter \
  --name "/saa-lab/prod/db/password" \
  --with-decryption

# Get a SecureString (encrypted - see the difference)
aws ssm get-parameter \
  --name "/saa-lab/prod/db/password" \
  --no-with-decryption

# Get multiple parameters at once
aws ssm get-parameters \
  --names "/saa-lab/prod/db/host" "/saa-lab/prod/db/port" "/saa-lab/prod/db/password" \
  --with-decryption

# Get all parameters under a path
aws ssm get-parameters-by-path \
  --path "/saa-lab/prod/db" \
  --recursive \
  --with-decryption
```

### Step 2.3 — Retrieve Parameters (Boto3)

Create a file called `get_parameters.py`:

```python
"""
Retrieve parameters from SSM Parameter Store.
Demonstrates single, multiple, and path-based retrieval.
"""

import boto3

def main():
    ssm = boto3.client("ssm")

    # --- Single Parameter ---
    print("=== Single Parameter ===")
    response = ssm.get_parameter(
        Name="/saa-lab/prod/app/api-url"
    )
    param = response["Parameter"]
    print(f"  Name:    {param['Name']}")
    print(f"  Type:    {param['Type']}")
    print(f"  Value:   {param['Value']}")
    print(f"  Version: {param['Version']}")

    # --- SecureString (Decrypted) ---
    print("\n=== SecureString (Decrypted) ===")
    response = ssm.get_parameter(
        Name="/saa-lab/prod/db/password",
        WithDecryption=True
    )
    print(f"  Value: {response['Parameter']['Value']}")

    # --- Multiple Parameters at Once ---
    print("\n=== Multiple Parameters ===")
    response = ssm.get_parameters(
        Names=[
            "/saa-lab/prod/db/host",
            "/saa-lab/prod/db/port",
            "/saa-lab/prod/db/password",
            "/saa-lab/prod/nonexistent"  # This one does not exist
        ],
        WithDecryption=True
    )
    for param in response["Parameters"]:
        print(f"  {param['Name']} = {param['Value']}")

    if response["InvalidParameters"]:
        print(f"  Invalid/Missing: {response['InvalidParameters']}")

    # --- Get All Parameters Under a Path ---
    print("\n=== Parameters by Path (/saa-lab/prod/db/) ===")
    response = ssm.get_parameters_by_path(
        Path="/saa-lab/prod/db",
        Recursive=True,
        WithDecryption=True
    )
    for param in response["Parameters"]:
        masked = "****" if param["Type"] == "SecureString" else param["Value"]
        print(f"  {param['Name']} ({param['Type']}) = {masked}")

if __name__ == "__main__":
    main()
```

```bash
python get_parameters.py
```

---

## Part 3: Lambda Function Retrieving Secrets (Boto3)

### Step 3.1 — Create the Lambda Execution Role

```bash
# Create the trust policy
cat > /tmp/lambda-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "lambda.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create the role
aws iam create-role \
  --role-name saa-lab-secrets-lambda-role \
  --assume-role-policy-document file:///tmp/lambda-trust-policy.json

# Attach basic Lambda execution policy
aws iam attach-role-policy \
  --role-name saa-lab-secrets-lambda-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

# Create and attach a policy for Secrets Manager and SSM access
cat > /tmp/secrets-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": "arn:aws:secretsmanager:*:*:secret:saa-lab/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameter",
        "ssm:GetParameters",
        "ssm:GetParametersByPath"
      ],
      "Resource": "arn:aws:ssm:*:*:parameter/saa-lab/*"
    },
    {
      "Effect": "Allow",
      "Action": "kms:Decrypt",
      "Resource": "*"
    }
  ]
}
EOF

aws iam put-role-policy \
  --role-name saa-lab-secrets-lambda-role \
  --policy-name SecretsAccess \
  --policy-document file:///tmp/secrets-policy.json

# Wait for role propagation
sleep 10
```

### Step 3.2 — Create the Lambda Function

Create `lambda_secrets.py`:

```python
"""
Lambda function that retrieves secrets from both Secrets Manager
and SSM Parameter Store, demonstrating both approaches.
"""

import json
import boto3

def lambda_handler(event, context):
    results = {}

    # --- Secrets Manager ---
    sm = boto3.client("secretsmanager")
    try:
        response = sm.get_secret_value(SecretId="saa-lab/database/credentials")
        db_creds = json.loads(response["SecretString"])
        results["secrets_manager"] = {
            "host": db_creds["host"],
            "username": db_creds["username"],
            "status": "retrieved successfully"
        }
    except Exception as e:
        results["secrets_manager"] = {"error": str(e)}

    # --- SSM Parameter Store ---
    ssm = boto3.client("ssm")
    try:
        response = ssm.get_parameters_by_path(
            Path="/saa-lab/prod/db",
            Recursive=True,
            WithDecryption=True
        )
        params = {p["Name"].split("/")[-1]: p["Value"] for p in response["Parameters"]}
        results["parameter_store"] = {
            "host": params.get("host", "N/A"),
            "port": params.get("port", "N/A"),
            "status": "retrieved successfully"
        }
    except Exception as e:
        results["parameter_store"] = {"error": str(e)}

    return {
        "statusCode": 200,
        "body": json.dumps(results, indent=2)
    }
```

### Step 3.3 — Deploy and Test

```bash
# Package the function
cd /tmp && zip lambda_secrets.zip lambda_secrets.py

# Get the role ARN
ROLE_ARN=$(aws iam get-role --role-name saa-lab-secrets-lambda-role --query "Role.Arn" --output text)

# Create the function
aws lambda create-function \
  --function-name saa-lab-secrets-demo \
  --runtime python3.12 \
  --handler lambda_secrets.lambda_handler \
  --role $ROLE_ARN \
  --zip-file fileb:///tmp/lambda_secrets.zip \
  --timeout 30

# Invoke the function
aws lambda invoke \
  --function-name saa-lab-secrets-demo \
  --payload '{}' \
  /tmp/lambda-output.json

# View the output
cat /tmp/lambda-output.json | python -m json.tool
```

---

## Part 4: Compare Workflows Side by Side

Create `compare_workflows.py`:

```python
"""
Side-by-side comparison of Secrets Manager vs SSM Parameter Store workflows.
Measures API call patterns and response structures.
"""

import boto3
import json
import time

def test_secrets_manager():
    """Demonstrate Secrets Manager workflow."""
    sm = boto3.client("secretsmanager")

    print("=" * 60)
    print("SECRETS MANAGER WORKFLOW")
    print("=" * 60)

    # Create
    start = time.time()
    sm.create_secret(
        Name="saa-lab/compare/api-key",
        SecretString=json.dumps({"key": "sk-test-12345", "environment": "test"})
    )
    print(f"  Create: {(time.time()-start)*1000:.0f}ms")

    # Retrieve
    start = time.time()
    response = sm.get_secret_value(SecretId="saa-lab/compare/api-key")
    print(f"  Retrieve: {(time.time()-start)*1000:.0f}ms")
    print(f"  Version ID: {response['VersionId']}")
    print(f"  Version Stages: {response['VersionStages']}")

    # Update
    start = time.time()
    sm.update_secret(
        SecretId="saa-lab/compare/api-key",
        SecretString=json.dumps({"key": "sk-test-67890", "environment": "test"})
    )
    print(f"  Update: {(time.time()-start)*1000:.0f}ms")

    # Cleanup
    sm.delete_secret(SecretId="saa-lab/compare/api-key", ForceDeleteWithoutRecovery=True)
    print("  Deleted (force)")

def test_parameter_store():
    """Demonstrate SSM Parameter Store workflow."""
    ssm = boto3.client("ssm")

    print("\n" + "=" * 60)
    print("SSM PARAMETER STORE WORKFLOW")
    print("=" * 60)

    # Create
    start = time.time()
    ssm.put_parameter(
        Name="/saa-lab/compare/api-key",
        Type="SecureString",
        Value="sk-test-12345"
    )
    print(f"  Create: {(time.time()-start)*1000:.0f}ms")

    # Retrieve
    start = time.time()
    response = ssm.get_parameter(
        Name="/saa-lab/compare/api-key",
        WithDecryption=True
    )
    print(f"  Retrieve: {(time.time()-start)*1000:.0f}ms")
    print(f"  Version: {response['Parameter']['Version']}")
    print(f"  Type: {response['Parameter']['Type']}")

    # Update (overwrite)
    start = time.time()
    ssm.put_parameter(
        Name="/saa-lab/compare/api-key",
        Type="SecureString",
        Value="sk-test-67890",
        Overwrite=True
    )
    print(f"  Update: {(time.time()-start)*1000:.0f}ms")

    # Cleanup
    ssm.delete_parameter(Name="/saa-lab/compare/api-key")
    print("  Deleted")

def main():
    test_secrets_manager()
    test_parameter_store()

    print("\n" + "=" * 60)
    print("KEY DIFFERENCES OBSERVED")
    print("=" * 60)
    print("  1. Secrets Manager has version stages (AWSCURRENT, AWSPREVIOUS)")
    print("  2. Parameter Store uses simple integer versioning")
    print("  3. Secrets Manager update is a separate API (update_secret)")
    print("  4. Parameter Store update uses same API (put_parameter + Overwrite)")
    print("  5. Secrets Manager has a recovery window on delete (unless forced)")
    print("  6. Parameter Store delete is immediate")

if __name__ == "__main__":
    main()
```

```bash
python compare_workflows.py
```

---

## Cleanup

```bash
# Delete the secret (with recovery window)
aws secretsmanager delete-secret \
  --secret-id "saa-lab/database/credentials" \
  --force-delete-without-recovery

# Delete all SSM parameters
aws ssm delete-parameters --names \
  "/saa-lab/prod/app/api-url" \
  "/saa-lab/prod/app/allowed-origins" \
  "/saa-lab/prod/db/password" \
  "/saa-lab/prod/db/api-key" \
  "/saa-lab/prod/db/host" \
  "/saa-lab/prod/db/port"

# Delete Lambda function
aws lambda delete-function --function-name saa-lab-secrets-demo

# Delete IAM role (detach policies first)
aws iam delete-role-policy --role-name saa-lab-secrets-lambda-role --policy-name SecretsAccess
aws iam detach-role-policy --role-name saa-lab-secrets-lambda-role --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
aws iam delete-role --role-name saa-lab-secrets-lambda-role

# Clean temp files
rm -f /tmp/lambda-trust-policy.json /tmp/secrets-policy.json /tmp/lambda_secrets.zip /tmp/lambda_secrets.py /tmp/lambda-output.json
```

---

## Review Questions

1. What is the main advantage of Secrets Manager over SSM Parameter Store?
2. Can you store structured data (JSON) in SSM Parameter Store?
3. What happens when you call `get_parameter` with `WithDecryption=False` on a SecureString?
4. How does Secrets Manager versioning differ from Parameter Store versioning?
5. When should you use SSM Parameter Store instead of Secrets Manager?

## Answers

1. Automatic secret rotation with native integration for RDS, Redshift, and DocumentDB.
2. Yes, but as a plain string. You parse the JSON yourself. Secrets Manager also stores it as a string but is designed for it.
3. You receive the encrypted ciphertext blob, not the decrypted value.
4. Secrets Manager uses version stages (AWSCURRENT, AWSPREVIOUS). Parameter Store uses integer version numbers (1, 2, 3...).
5. When you need cost-free storage, hierarchical parameter organization, or you are storing non-secret configuration data.

---

## Next Lab

Proceed to **Lab 03: WAF & Shield** to set up web application firewall rules.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Estimated Time: 60-75 minutes
- Secrets Manager — Store and Retrieve Secrets
- SSM Parameter Store — Store and Retrieve Parameters
- Lambda Function Retrieving Secrets (Boto3)

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
