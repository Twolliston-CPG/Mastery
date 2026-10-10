# 09 — CloudFormation & Infrastructure as Code

## Overview

AWS CloudFormation lets you define your infrastructure in code (JSON or YAML templates) and deploy it as managed stacks. The SAA-C03 exam expects you to understand template structure, key intrinsic functions, stack operations, and important features like Change Sets, Drift Detection, and DeletionPolicy.

---

## Template Structure

```yaml
AWSTemplateFormatVersion: "2010-09-09"    # Only valid value (optional but recommended)
Description: "My infrastructure template"   # What this template does

Metadata:                                    # Additional info about template
  # Used by cfn-init, console UI, etc.

Parameters:                                  # Input values at deploy time
  EnvironmentType:
    Type: String
    Default: dev
    AllowedValues: [dev, staging, prod]
    Description: "Environment type"

Mappings:                                    # Static key-value lookup tables
  RegionAMI:
    us-east-1:
      HVM64: ami-0abcdef1234567890
    us-west-2:
      HVM64: ami-0fedcba9876543210

Conditions:                                  # Conditional resource creation
  IsProd: !Equals [!Ref EnvironmentType, prod]

Transform:                                   # Macros (e.g., AWS::Serverless)
  - AWS::Serverless-2016-10-31

Resources:                                   # REQUIRED - the actual resources
  MyBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Sub "${AWS::StackName}-data"

Outputs:                                     # Return values after creation
  BucketARN:
    Description: "S3 Bucket ARN"
    Value: !GetAtt MyBucket.Arn
    Export:
      Name: !Sub "${AWS::StackName}-BucketARN"  # Cross-stack reference
```

### The Only Required Section: `Resources`

---

## Key Intrinsic Functions

| Function | Purpose | Example |
|----------|---------|---------|
| `!Ref` | Reference a parameter value or resource ID | `!Ref MyBucket` returns bucket name; `!Ref EnvironmentType` returns parameter value |
| `!GetAtt` | Get an attribute of a resource | `!GetAtt MyBucket.Arn` returns the bucket ARN |
| `!Sub` | String substitution with variables | `!Sub "arn:aws:s3:::${BucketName}/*"` |
| `!Join` | Join strings with a delimiter | `!Join ["-", [!Ref "AWS::StackName", "bucket"]]` |
| `!Select` | Select an item from a list by index | `!Select [0, !GetAZs ""]` returns first AZ |
| `!Split` | Split a string into a list | `!Split [",", "a,b,c"]` returns `["a","b","c"]` |
| `!FindInMap` | Look up value in Mappings section | `!FindInMap [RegionAMI, !Ref "AWS::Region", HVM64]` |
| `!If` | Conditional value | `!If [IsProd, "m5.xlarge", "t3.micro"]` |
| `!Equals` | Compare two values (for Conditions) | `!Equals [!Ref Env, "prod"]` |
| `!And` / `!Or` / `!Not` | Logical operators (for Conditions) | `!And [Condition: IsProd, Condition: IsUSEast]` |
| `!GetAZs` | Get list of AZs in a region | `!GetAZs ""` returns AZs for current region |
| `!ImportValue` | Import an exported output from another stack | `!ImportValue "NetworkStack-VpcId"` |
| `!Cidr` | Generate CIDR address blocks | `!Cidr [!Ref VpcCidr, 6, 8]` |

### Pseudo Parameters (Built-in References)

| Pseudo Parameter | Returns |
|-----------------|---------|
| `AWS::AccountId` | Current account ID |
| `AWS::Region` | Current region |
| `AWS::StackName` | Current stack name |
| `AWS::StackId` | Current stack ID (ARN) |
| `AWS::URLSuffix` | `amazonaws.com` (or `amazonaws.com.cn` for China) |
| `AWS::NoValue` | Removes a property (used with `!If`) |

---

## Stacks

### Stack Operations

| Operation | What Happens |
|-----------|-------------|
| **Create** | All resources in the template are created. If any fails, the entire stack rolls back. |
| **Update** | Modified resources are updated. Can use Change Sets to preview changes. |
| **Delete** | All resources are deleted (unless protected by DeletionPolicy). |
| **Rollback** | On creation failure: all resources deleted. On update failure: reverts to previous state. |

### Stack Status Values (Key Ones)

| Status | Meaning |
|--------|---------|
| `CREATE_COMPLETE` | All resources created successfully |
| `CREATE_FAILED` | One or more resources failed to create |
| `ROLLBACK_COMPLETE` | Stack creation failed and rolled back — stack is in a terminal state |
| `UPDATE_COMPLETE` | Stack update succeeded |
| `UPDATE_ROLLBACK_COMPLETE` | Update failed, reverted to previous version |
| `DELETE_COMPLETE` | Stack deleted |

---

## StackSets

- Deploy stacks across **multiple accounts and regions** in a single operation
- Requires: AWS Organizations or self-managed permissions
- Administrator account creates StackSet; target accounts receive stack instances
- Use case: deploy Config rules, CloudTrail, GuardDuty across all accounts

---

## Change Sets

### What They Do
- Preview the changes CloudFormation will make BEFORE applying them
- Shows which resources will be Added, Modified, or Replaced
- Does NOT tell you if the update will succeed — only what will change

### Why Replacement Matters

| Update Behavior | Description | Example |
|----------------|-------------|---------|
| **No interruption** | Resource updated in-place, no downtime | Changing a tag on an EC2 instance |
| **Some interruption** | Brief interruption during update | Changing instance type (requires stop/start) |
| **Replacement** | Old resource deleted, new one created | Changing an RDS DB engine, changing EC2 AMI |

### Change Set Workflow
```bash
# 1. Create a change set
aws cloudformation create-change-set \
  --stack-name my-stack \
  --template-body file://updated-template.yaml \
  --change-set-name my-changes

# 2. Review the change set
aws cloudformation describe-change-set \
  --stack-name my-stack \
  --change-set-name my-changes

# 3. Execute the change set (apply changes)
aws cloudformation execute-change-set \
  --stack-name my-stack \
  --change-set-name my-changes

# Or delete it if you don't want to apply
aws cloudformation delete-change-set \
  --stack-name my-stack \
  --change-set-name my-changes
```

---

## Drift Detection

### What It Does
- Detects when actual resource configurations **differ from the template**
- Someone modified a resource manually (via console/CLI) => drift

### Drift Status Values

| Status | Meaning |
|--------|---------|
| `IN_SYNC` | Actual config matches template |
| `DRIFTED` | Actual config differs from template |
| `NOT_CHECKED` | Drift detection has not been run |
| `DELETED` | Resource was deleted outside CloudFormation |

### Example
```
Template says: Security Group allows port 443 only
Someone manually adds port 80 via the console
Drift Detection: DRIFTED (shows port 80 was added)
```

---

## Stack Policies

- JSON document that prevents unintentional updates to specific resources
- Once applied, ALL resources are protected by default (Deny all updates)
- You must explicitly Allow updates to specific resources
- Cannot be removed once applied (but can be overridden temporarily during an update)

### Example Stack Policy
```json
{
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "Update:*",
      "Principal": "*",
      "Resource": "*"
    },
    {
      "Effect": "Deny",
      "Action": "Update:Replace",
      "Principal": "*",
      "Resource": "LogicalResourceId/ProductionDatabase"
    }
  ]
}
```
This allows all updates EXCEPT replacement of the production database.

---

## DeletionPolicy

Controls what happens to a resource when the stack is deleted.

| Policy | Behavior |
|--------|----------|
| `Delete` | Resource is deleted with the stack (default for most resources) |
| `Retain` | Resource is preserved after stack deletion. CloudFormation removes it from the stack but does NOT delete it. |
| `Snapshot` | Creates a snapshot before deleting. Supported for: EBS volumes, RDS instances, RDS clusters, Redshift clusters, Neptune, ElastiCache. |

### Example
```yaml
Resources:
  MyDatabase:
    Type: AWS::RDS::DBInstance
    DeletionPolicy: Snapshot          # Creates final snapshot before deletion
    UpdateReplacePolicy: Snapshot     # Creates snapshot if replaced during update
    Properties:
      DBInstanceClass: db.t3.micro
      Engine: mysql
      # ...

  ImportantBucket:
    Type: AWS::S3::Bucket
    DeletionPolicy: Retain            # Bucket survives stack deletion
    Properties:
      BucketName: critical-data-bucket
```

### Exam Tip
- "Keep the S3 bucket when stack is deleted" => `DeletionPolicy: Retain`
- "Take a snapshot of RDS before stack deletion" => `DeletionPolicy: Snapshot`

---

## cfn-init, cfn-signal, CreationPolicy, WaitCondition

### cfn-init
- Bootstraps an EC2 instance during creation
- Defined in `AWS::CloudFormation::Init` metadata
- More declarative than UserData scripts
- Supports: packages, groups, users, sources, files, commands, services

### cfn-signal
- Signals CloudFormation that the instance has been successfully configured
- Used with CreationPolicy or WaitCondition
- Without signaling, CloudFormation assumes the instance is ready as soon as it launches (even if bootstrapping is not complete)

### CreationPolicy
- Tells CloudFormation to wait for a signal before marking the resource as CREATE_COMPLETE
- Timeout: if no signal received within the timeout, the resource creation fails

```yaml
Resources:
  MyInstance:
    Type: AWS::EC2::Instance
    CreationPolicy:
      ResourceSignal:
        Count: 1           # Wait for 1 signal
        Timeout: PT15M     # Wait up to 15 minutes
    Metadata:
      AWS::CloudFormation::Init:
        config:
          packages:
            yum:
              httpd: []
          services:
            sysvinit:
              httpd:
                enabled: true
                ensureRunning: true
    Properties:
      InstanceType: t3.micro
      ImageId: ami-0abcdef1234567890
      UserData:
        Fn::Base64: !Sub |
          #!/bin/bash -xe
          yum update -y aws-cfn-bootstrap
          /opt/aws/bin/cfn-init -v --stack ${AWS::StackName} --resource MyInstance --region ${AWS::Region}
          /opt/aws/bin/cfn-signal -e $? --stack ${AWS::StackName} --resource MyInstance --region ${AWS::Region}
```

### WaitCondition
- Similar to CreationPolicy but can be used with **external resources**
- Creates a pre-signed URL that anything can use to send a signal
- More flexible but less common than CreationPolicy for EC2

### cfn-init vs UserData

| Feature | UserData | cfn-init |
|---------|----------|----------|
| **Format** | Shell script | Declarative (YAML/JSON metadata) |
| **Idempotent** | Not by default (runs once) | Yes — cfn-hup can re-apply on updates |
| **Logging** | `/var/log/cloud-init-output.log` | `/var/log/cfn-init.log` |
| **Update support** | Must replace instance | cfn-hup detects metadata changes and re-runs |
| **Best for** | Simple bootstrapping | Complex, repeatable instance configuration |

---

## Cross-Stack References

### Outputs + Export
```yaml
# Network Stack (exports VPC ID)
Outputs:
  VpcId:
    Value: !Ref MyVPC
    Export:
      Name: NetworkStack-VpcId
```

### ImportValue
```yaml
# Application Stack (imports VPC ID)
Resources:
  MyInstance:
    Type: AWS::EC2::Instance
    Properties:
      SubnetId: !ImportValue NetworkStack-SubnetId
```

- Exported names must be unique within a region
- Cannot delete a stack whose exports are imported by another stack
- Use `Fn::ImportValue` to reference

---

## Common Exam Scenarios

| Scenario | Answer |
|----------|--------|
| "Preview changes before updating stack" | Change Set |
| "Someone modified a resource outside CloudFormation" | Drift Detection |
| "Keep S3 bucket when deleting stack" | `DeletionPolicy: Retain` |
| "Take RDS snapshot before stack deletion" | `DeletionPolicy: Snapshot` |
| "Prevent accidental deletion of production database in stack" | Stack Policy |
| "Deploy same stack across 20 accounts" | StackSets |
| "Wait for EC2 bootstrap to complete before marking CREATE_COMPLETE" | CreationPolicy + cfn-signal |
| "Look up AMI ID based on region" | Mappings + `!FindInMap` |
| "Conditionally create a resource based on parameter" | Conditions + `!If` |
| "Reference output from another stack" | `!ImportValue` with exported outputs |
| "Substitute variables in a string" | `!Sub` |
| "Get the ARN of a resource" | `!GetAtt Resource.Arn` |

---

## Next Steps

- Complete **Lab 07: CloudFormation Deploy** to write and deploy a real template
- Continue to **Note 10: Trusted Advisor & Health Dashboard**

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Template Structure
- Key Intrinsic Functions
- Stacks
- StackSets

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
