# Lab 01 -- IAM Users, Groups, Roles, and Custom Policies

## Lab Overview

| Item | Detail |
|---|---|
| **Objective** | Create IAM users, groups, roles, and custom policies using the AWS CLI and Boto3 |
| **Estimated time** | 60-90 minutes |
| **Cost** | Free (IAM is always free) |
| **Prerequisites** | AWS CLI v2 configured, Python 3.10+ with boto3, an AWS account with admin access |
| **Cleanup required** | Yes -- delete all created resources when done to keep the account clean |

---

## What You Will Build

1. An IAM group called `Developers` with a managed policy attached.
2. An IAM group called `ReadOnlyAuditors` with read-only access.
3. Two IAM users: one assigned to `Developers`, one assigned to `ReadOnlyAuditors`.
4. A custom IAM policy that restricts S3 access to a specific bucket and prefix.
5. An IAM role that EC2 instances can assume to read from S3.
6. A policy that requires MFA for certain actions.

---

## Part 1: Create IAM Groups (AWS CLI)

### Step 1.1 -- Create the Developers Group

```bash
# Create the group
aws iam create-group --group-name Developers --profile saa-study

# Attach the AWS managed policy for PowerUser access
aws iam attach-group-policy \
  --group-name Developers \
  --policy-arn arn:aws:iam::aws:policy/PowerUserAccess \
  --profile saa-study

# Verify the attached policies
aws iam list-attached-group-policies \
  --group-name Developers \
  --profile saa-study
```

### Step 1.2 -- Create the ReadOnlyAuditors Group

```bash
# Create the group
aws iam create-group --group-name ReadOnlyAuditors --profile saa-study

# Attach the AWS managed policy for ReadOnly access
aws iam attach-group-policy \
  --group-name ReadOnlyAuditors \
  --policy-arn arn:aws:iam::aws:policy/ReadOnlyAccess \
  --profile saa-study

# Verify
aws iam list-attached-group-policies \
  --group-name ReadOnlyAuditors \
  --profile saa-study
```

### Step 1.3 -- List All Groups

```bash
aws iam list-groups --profile saa-study
```

---

## Part 2: Create IAM Users (AWS CLI)

### Step 2.1 -- Create Users and Add to Groups

```bash
# Create developer user
aws iam create-user --user-name dev-alice --profile saa-study

# Create auditor user
aws iam create-user --user-name auditor-bob --profile saa-study

# Add users to their respective groups
aws iam add-user-to-group \
  --user-name dev-alice \
  --group-name Developers \
  --profile saa-study

aws iam add-user-to-group \
  --user-name auditor-bob \
  --group-name ReadOnlyAuditors \
  --profile saa-study

# Verify group membership
aws iam get-group --group-name Developers --profile saa-study
aws iam get-group --group-name ReadOnlyAuditors --profile saa-study
```

### Step 2.2 -- Create Access Keys for Programmatic Access

```bash
# Create access keys for dev-alice (for testing purposes only)
aws iam create-access-key --user-name dev-alice --profile saa-study

# IMPORTANT: Save the AccessKeyId and SecretAccessKey from the output.
# The secret key is shown only once. In a real environment, distribute
# securely and rotate regularly.
```

### Step 2.3 -- Create a Login Profile for Console Access

```bash
# Create a login profile (console password) for dev-alice
aws iam create-login-profile \
  --user-name dev-alice \
  --password 'TempP@ssw0rd!2024' \
  --password-reset-required \
  --profile saa-study
```

---

## Part 3: Create a Custom IAM Policy (AWS CLI)

### Step 3.1 -- Write the Policy Document

Create a file called `s3-restricted-policy.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowListBucket",
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::saa-study-lab01-*",
      "Condition": {
        "StringLike": {
          "s3:prefix": ["dev/*", "shared/*"]
        }
      }
    },
    {
      "Sid": "AllowGetPutObjects",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": [
        "arn:aws:s3:::saa-study-lab01-*/dev/*",
        "arn:aws:s3:::saa-study-lab01-*/shared/*"
      ]
    },
    {
      "Sid": "DenyDeleteBucket",
      "Effect": "Deny",
      "Action": "s3:DeleteBucket",
      "Resource": "arn:aws:s3:::saa-study-lab01-*"
    }
  ]
}
```

**What this policy does:**
- Allows listing objects in any bucket whose name starts with `saa-study-lab01-`, but only under the `dev/` and `shared/` prefixes.
- Allows reading, writing, and deleting objects under `dev/` and `shared/` prefixes.
- Explicitly denies deleting the bucket itself.

### Step 3.2 -- Create the Policy

```bash
aws iam create-policy \
  --policy-name S3RestrictedDevAccess \
  --policy-document file://s3-restricted-policy.json \
  --description "Restricts S3 access to dev/ and shared/ prefixes in saa-study-lab01 buckets" \
  --profile saa-study

# Note the PolicyArn from the output -- you will need it in the next step.
```

### Step 3.3 -- Attach the Custom Policy to the Developers Group

```bash
# Replace <account-id> with your AWS account ID
aws iam attach-group-policy \
  --group-name Developers \
  --policy-arn arn:aws:iam::<account-id>:policy/S3RestrictedDevAccess \
  --profile saa-study
```

---

## Part 4: Create an IAM Role for EC2 (AWS CLI)

### Step 4.1 -- Write the Trust Policy

Create a file called `ec2-trust-policy.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowEC2Assume",
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

### Step 4.2 -- Create the Role

```bash
aws iam create-role \
  --role-name EC2-S3ReadOnly \
  --assume-role-policy-document file://ec2-trust-policy.json \
  --description "Allows EC2 instances to read from S3" \
  --profile saa-study
```

### Step 4.3 -- Attach a Permission Policy to the Role

```bash
aws iam attach-role-policy \
  --role-name EC2-S3ReadOnly \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess \
  --profile saa-study
```

### Step 4.4 -- Create an Instance Profile

```bash
# Create the instance profile
aws iam create-instance-profile \
  --instance-profile-name EC2-S3ReadOnly-Profile \
  --profile saa-study

# Add the role to the instance profile
aws iam add-role-to-instance-profile \
  --instance-profile-name EC2-S3ReadOnly-Profile \
  --role-name EC2-S3ReadOnly \
  --profile saa-study
```

---

## Part 5: Repeat Key Steps with Boto3 (Python)

### Step 5.1 -- Setup

```python
"""
Lab 01 - IAM Operations with Boto3
Run with: python lab01_iam_boto3.py
"""

import json
import boto3
from botocore.exceptions import ClientError

# Initialize IAM client using the saa-study profile
session = boto3.Session(profile_name='saa-study')
iam = session.client('iam')
```

### Step 5.2 -- Create a Group and Attach a Policy

```python
def create_group_with_policy(group_name: str, policy_arn: str) -> dict:
    """Create an IAM group and attach a managed policy."""
    try:
        # Create the group
        response = iam.create_group(GroupName=group_name)
        print(f"Created group: {group_name}")
        print(f"  ARN: {response['Group']['Arn']}")

        # Attach the managed policy
        iam.attach_group_policy(
            GroupName=group_name,
            PolicyArn=policy_arn
        )
        print(f"  Attached policy: {policy_arn}")

        return response['Group']

    except ClientError as e:
        if e.response['Error']['Code'] == 'EntityAlreadyExists':
            print(f"Group {group_name} already exists. Skipping creation.")
        else:
            raise


# Example usage:
# create_group_with_policy('Developers-Boto3', 'arn:aws:iam::aws:policy/PowerUserAccess')
```

### Step 5.3 -- Create a User and Add to a Group

```python
def create_user_in_group(username: str, group_name: str) -> dict:
    """Create an IAM user and add them to a group."""
    try:
        # Create the user
        response = iam.create_user(UserName=username)
        print(f"Created user: {username}")
        print(f"  ARN: {response['User']['Arn']}")

        # Add to group
        iam.add_user_to_group(
            UserName=username,
            GroupName=group_name
        )
        print(f"  Added to group: {group_name}")

        return response['User']

    except ClientError as e:
        if e.response['Error']['Code'] == 'EntityAlreadyExists':
            print(f"User {username} already exists. Skipping creation.")
        else:
            raise


# Example usage:
# create_user_in_group('dev-charlie', 'Developers-Boto3')
```

### Step 5.4 -- Create a Custom Policy

```python
def create_custom_policy(policy_name: str, description: str) -> str:
    """Create a custom IAM policy for restricted S3 access. Returns the policy ARN."""
    policy_document = {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "AllowListBucket",
                "Effect": "Allow",
                "Action": "s3:ListBucket",
                "Resource": "arn:aws:s3:::saa-study-lab01-*",
                "Condition": {
                    "StringLike": {
                        "s3:prefix": ["dev/*", "shared/*"]
                    }
                }
            },
            {
                "Sid": "AllowGetPutObjects",
                "Effect": "Allow",
                "Action": [
                    "s3:GetObject",
                    "s3:PutObject",
                    "s3:DeleteObject"
                ],
                "Resource": [
                    "arn:aws:s3:::saa-study-lab01-*/dev/*",
                    "arn:aws:s3:::saa-study-lab01-*/shared/*"
                ]
            }
        ]
    }

    try:
        response = iam.create_policy(
            PolicyName=policy_name,
            PolicyDocument=json.dumps(policy_document),
            Description=description
        )
        policy_arn = response['Policy']['Arn']
        print(f"Created policy: {policy_name}")
        print(f"  ARN: {policy_arn}")
        return policy_arn

    except ClientError as e:
        if e.response['Error']['Code'] == 'EntityAlreadyExists':
            print(f"Policy {policy_name} already exists.")
            # Retrieve existing policy ARN
            account_id = session.client('sts').get_caller_identity()['Account']
            return f"arn:aws:iam::{account_id}:policy/{policy_name}"
        else:
            raise


# Example usage:
# policy_arn = create_custom_policy('S3RestrictedDevAccess-Boto3', 'Restricted S3 access')
```

### Step 5.5 -- Create a Role for EC2

```python
def create_ec2_role(role_name: str, policy_arn: str) -> dict:
    """Create an IAM role that EC2 instances can assume."""
    trust_policy = {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "AllowEC2Assume",
                "Effect": "Allow",
                "Principal": {
                    "Service": "ec2.amazonaws.com"
                },
                "Action": "sts:AssumeRole"
            }
        ]
    }

    try:
        # Create the role
        role_response = iam.create_role(
            RoleName=role_name,
            AssumeRolePolicyDocument=json.dumps(trust_policy),
            Description='Allows EC2 instances to read from S3'
        )
        print(f"Created role: {role_name}")
        print(f"  ARN: {role_response['Role']['Arn']}")

        # Attach the permission policy
        iam.attach_role_policy(
            RoleName=role_name,
            PolicyArn=policy_arn
        )
        print(f"  Attached policy: {policy_arn}")

        # Create instance profile
        iam.create_instance_profile(
            InstanceProfileName=f"{role_name}-Profile"
        )
        iam.add_role_to_instance_profile(
            InstanceProfileName=f"{role_name}-Profile",
            RoleName=role_name
        )
        print(f"  Created instance profile: {role_name}-Profile")

        return role_response['Role']

    except ClientError as e:
        if e.response['Error']['Code'] == 'EntityAlreadyExists':
            print(f"Role {role_name} already exists.")
        else:
            raise


# Example usage:
# create_ec2_role('EC2-S3ReadOnly-Boto3', 'arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess')
```

### Step 5.6 -- List and Inspect Resources

```python
def audit_iam_resources():
    """List all IAM users, groups, and roles created in this lab."""
    print("=" * 60)
    print("IAM AUDIT REPORT")
    print("=" * 60)

    # List users
    print("\n--- Users ---")
    users = iam.list_users()
    for user in users['Users']:
        print(f"  {user['UserName']} (created: {user['CreateDate']})")
        # List groups for each user
        groups = iam.list_groups_for_user(UserName=user['UserName'])
        for group in groups['Groups']:
            print(f"    -> Member of: {group['GroupName']}")

    # List groups
    print("\n--- Groups ---")
    groups = iam.list_groups()
    for group in groups['Groups']:
        print(f"  {group['GroupName']}")
        # List attached policies
        policies = iam.list_attached_group_policies(GroupName=group['GroupName'])
        for policy in policies['AttachedPolicies']:
            print(f"    -> Policy: {policy['PolicyName']}")

    # List roles (filter to lab-created roles)
    print("\n--- Roles (custom) ---")
    roles = iam.list_roles()
    for role in roles['Roles']:
        if role['RoleName'].startswith('EC2-S3'):
            print(f"  {role['RoleName']}")
            print(f"    ARN: {role['Arn']}")

    print("\n" + "=" * 60)


# Example usage:
# audit_iam_resources()
```

---

## Part 6: Verify and Experiment

### Verification Checklist

- [ ] List all groups and confirm `Developers` and `ReadOnlyAuditors` exist.
- [ ] Confirm `dev-alice` is in the `Developers` group.
- [ ] Confirm `auditor-bob` is in the `ReadOnlyAuditors` group.
- [ ] Confirm the `S3RestrictedDevAccess` policy exists and is attached to the `Developers` group.
- [ ] Confirm the `EC2-S3ReadOnly` role exists and has the correct trust policy.
- [ ] Use the IAM Policy Simulator (https://policysim.aws.amazon.com/) to test your custom policy.

### Experiment: Use the IAM Policy Simulator

```bash
# Simulate: Can dev-alice perform s3:GetObject on saa-study-lab01-test/dev/file.txt?
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::<account-id>:user/dev-alice \
  --action-names s3:GetObject \
  --resource-arns arn:aws:s3:::saa-study-lab01-test/dev/file.txt \
  --profile saa-study

# Simulate: Can dev-alice perform s3:DeleteBucket?
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::<account-id>:user/dev-alice \
  --action-names s3:DeleteBucket \
  --resource-arns arn:aws:s3:::saa-study-lab01-test \
  --profile saa-study
```

---

## Part 7: Cleanup

**IMPORTANT:** Always clean up IAM resources after the lab.

### AWS CLI Cleanup

```bash
# Remove users from groups
aws iam remove-user-from-group --user-name dev-alice --group-name Developers --profile saa-study
aws iam remove-user-from-group --user-name auditor-bob --group-name ReadOnlyAuditors --profile saa-study

# Delete access keys (list them first)
ACCESS_KEY_ID=$(aws iam list-access-keys --user-name dev-alice --profile saa-study --query 'AccessKeyMetadata[0].AccessKeyId' --output text)
aws iam delete-access-key --user-name dev-alice --access-key-id "$ACCESS_KEY_ID" --profile saa-study

# Delete login profiles
aws iam delete-login-profile --user-name dev-alice --profile saa-study

# Delete users
aws iam delete-user --user-name dev-alice --profile saa-study
aws iam delete-user --user-name auditor-bob --profile saa-study

# Detach policies from groups
aws iam detach-group-policy --group-name Developers --policy-arn arn:aws:iam::aws:policy/PowerUserAccess --profile saa-study
aws iam detach-group-policy --group-name Developers --policy-arn arn:aws:iam::<account-id>:policy/S3RestrictedDevAccess --profile saa-study
aws iam detach-group-policy --group-name ReadOnlyAuditors --policy-arn arn:aws:iam::aws:policy/ReadOnlyAccess --profile saa-study

# Delete groups
aws iam delete-group --group-name Developers --profile saa-study
aws iam delete-group --group-name ReadOnlyAuditors --profile saa-study

# Delete the custom policy
aws iam delete-policy --policy-arn arn:aws:iam::<account-id>:policy/S3RestrictedDevAccess --profile saa-study

# Remove role from instance profile
aws iam remove-role-from-instance-profile --instance-profile-name EC2-S3ReadOnly-Profile --role-name EC2-S3ReadOnly --profile saa-study

# Delete instance profile
aws iam delete-instance-profile --instance-profile-name EC2-S3ReadOnly-Profile --profile saa-study

# Detach policy from role
aws iam detach-role-policy --role-name EC2-S3ReadOnly --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess --profile saa-study

# Delete role
aws iam delete-role --role-name EC2-S3ReadOnly --profile saa-study

echo "Cleanup complete!"
```

### Boto3 Cleanup

```python
def cleanup_lab01():
    """Remove all IAM resources created in this lab."""
    # Define resources to clean up
    users_and_groups = [
        ('dev-alice', 'Developers'),
        ('auditor-bob', 'ReadOnlyAuditors'),
    ]

    for username, group_name in users_and_groups:
        try:
            # Remove from group
            iam.remove_user_from_group(UserName=username, GroupName=group_name)
            print(f"Removed {username} from {group_name}")

            # Delete access keys
            keys = iam.list_access_keys(UserName=username)
            for key in keys['AccessKeyMetadata']:
                iam.delete_access_key(UserName=username, AccessKeyId=key['AccessKeyId'])
                print(f"Deleted access key for {username}")

            # Delete login profile
            try:
                iam.delete_login_profile(UserName=username)
                print(f"Deleted login profile for {username}")
            except ClientError:
                pass

            # Delete user
            iam.delete_user(UserName=username)
            print(f"Deleted user: {username}")

        except ClientError as e:
            print(f"Error cleaning up {username}: {e}")

    # [TODO: Add group cleanup, policy cleanup, and role cleanup]
    print("Lab 01 cleanup complete!")


# cleanup_lab01()
```

---

## Reflection Questions

After completing this lab, answer these questions:

1. What happens if you try to create a user that already exists?
2. Why is it better to attach policies to groups rather than directly to users?
3. What is the difference between a trust policy and a permission policy on a role?
4. Why does the IAM role need an instance profile to be used with EC2?
5. What would happen if you attached both an Allow and a Deny for the same S3 action on the same resource?

[TODO: Add answer key for reflection questions]

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Create IAM Groups (AWS CLI)
- Create IAM Users (AWS CLI)
- Create a Custom IAM Policy (AWS CLI)
- Create an IAM Role for EC2 (AWS CLI)

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
