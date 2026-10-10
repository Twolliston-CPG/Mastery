# Lab 07 — CloudFormation Deploy

## Objective

Write a CloudFormation template that creates a VPC, public subnet, Internet Gateway, security group, and EC2 instance. Deploy the stack, update it with a change set, detect drift, and explore DeletionPolicy behavior. This lab teaches you Infrastructure as Code fundamentals.

## Prerequisites

- AWS CLI configured
- Understanding of VPC, subnets, and security groups (Phase 1)
- Basic YAML knowledge

## Estimated Time: 75-90 minutes

## Cost Estimate

| Resource | Cost | Notes |
|----------|------|-------|
| EC2 t2.micro | Free tier | 750 hours/month free |
| VPC / Subnet / IGW | Free | No cost for VPC resources |
| EBS (8 GB gp2) | Free tier | 30 GB/month free |
| S3 bucket (DeletionPolicy test) | Free tier | Negligible |
| **Total** | **$0** | All within free tier |

---

## Part 1: Write the CloudFormation Template

### Step 1.1 — Create the Template File

Create `saa-lab-stack.yaml`:

```yaml
AWSTemplateFormatVersion: "2010-09-09"
Description: >
  SAA Lab - CloudFormation stack with VPC, public subnet,
  security group, and EC2 instance. Demonstrates Parameters,
  Mappings, Conditions, Intrinsic Functions, and DeletionPolicy.

# ============================================================
# PARAMETERS — User inputs at deploy time
# ============================================================
Parameters:
  EnvironmentType:
    Type: String
    Default: dev
    AllowedValues:
      - dev
      - prod
    Description: Environment type (dev or prod)

  KeyPairName:
    Type: String
    Default: ""
    Description: EC2 Key Pair name (leave empty for no SSH access - use Session Manager instead)

  VpcCidr:
    Type: String
    Default: "10.100.0.0/16"
    Description: CIDR block for the VPC

  SubnetCidr:
    Type: String
    Default: "10.100.1.0/24"
    Description: CIDR block for the public subnet

# ============================================================
# MAPPINGS — Static lookup tables
# ============================================================
Mappings:
  RegionAMI:
    us-east-1:
      AmazonLinux2023: ami-0c02fb55956c7d316
    us-west-2:
      AmazonLinux2023: ami-0892d3c7ee96c0bf7
    eu-west-1:
      AmazonLinux2023: ami-0d71ea30463e0ff8d

  EnvironmentConfig:
    dev:
      InstanceType: t2.micro
      EnableMonitoring: "false"
    prod:
      InstanceType: t3.small
      EnableMonitoring: "true"

# ============================================================
# CONDITIONS — Conditional resource creation
# ============================================================
Conditions:
  IsProd: !Equals [!Ref EnvironmentType, "prod"]
  HasKeyPair: !Not [!Equals [!Ref KeyPairName, ""]]

# ============================================================
# RESOURCES — The actual infrastructure
# ============================================================
Resources:

  # --- VPC ---
  VPC:
    Type: AWS::EC2::VPC
    Properties:
      CidrBlock: !Ref VpcCidr
      EnableDnsHostnames: true
      EnableDnsSupport: true
      Tags:
        - Key: Name
          Value: !Sub "${AWS::StackName}-vpc"
        - Key: Environment
          Value: !Ref EnvironmentType

  # --- Internet Gateway ---
  InternetGateway:
    Type: AWS::EC2::InternetGateway
    Properties:
      Tags:
        - Key: Name
          Value: !Sub "${AWS::StackName}-igw"

  VPCGatewayAttachment:
    Type: AWS::EC2::VPCGatewayAttachment
    Properties:
      VpcId: !Ref VPC
      InternetGatewayId: !Ref InternetGateway

  # --- Public Subnet ---
  PublicSubnet:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      CidrBlock: !Ref SubnetCidr
      AvailabilityZone: !Select [0, !GetAZs ""]
      MapPublicIpOnLaunch: true
      Tags:
        - Key: Name
          Value: !Sub "${AWS::StackName}-public-subnet"

  # --- Route Table ---
  PublicRouteTable:
    Type: AWS::EC2::RouteTable
    Properties:
      VpcId: !Ref VPC
      Tags:
        - Key: Name
          Value: !Sub "${AWS::StackName}-public-rt"

  PublicRoute:
    Type: AWS::EC2::Route
    DependsOn: VPCGatewayAttachment
    Properties:
      RouteTableId: !Ref PublicRouteTable
      DestinationCidrBlock: "0.0.0.0/0"
      GatewayId: !Ref InternetGateway

  SubnetRouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      SubnetId: !Ref PublicSubnet
      RouteTableId: !Ref PublicRouteTable

  # --- Security Group ---
  WebSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: !Sub "Security group for ${AWS::StackName} web server"
      VpcId: !Ref VPC
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 80
          ToPort: 80
          CidrIp: "0.0.0.0/0"
          Description: "Allow HTTP from anywhere"
        - IpProtocol: tcp
          FromPort: 443
          ToPort: 443
          CidrIp: "0.0.0.0/0"
          Description: "Allow HTTPS from anywhere"
      SecurityGroupEgress:
        - IpProtocol: "-1"
          CidrIp: "0.0.0.0/0"
          Description: "Allow all outbound"
      Tags:
        - Key: Name
          Value: !Sub "${AWS::StackName}-web-sg"

  # --- IAM Role for EC2 (Session Manager access) ---
  EC2Role:
    Type: AWS::IAM::Role
    Properties:
      RoleName: !Sub "${AWS::StackName}-ec2-role"
      AssumeRolePolicyDocument:
        Version: "2012-10-17"
        Statement:
          - Effect: Allow
            Principal:
              Service: ec2.amazonaws.com
            Action: sts:AssumeRole
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore

  EC2InstanceProfile:
    Type: AWS::IAM::InstanceProfile
    Properties:
      Roles:
        - !Ref EC2Role

  # --- EC2 Instance ---
  WebServer:
    Type: AWS::EC2::Instance
    Metadata:
      AWS::CloudFormation::Init:
        config:
          packages:
            yum:
              httpd: []
          files:
            /var/www/html/index.html:
              content: !Sub |
                <html>
                <body>
                <h1>SAA Lab CloudFormation Stack</h1>
                <p>Environment: ${EnvironmentType}</p>
                <p>Stack: ${AWS::StackName}</p>
                <p>Region: ${AWS::Region}</p>
                <p>Instance Type: ${!FindInMap [EnvironmentConfig, !Ref EnvironmentType, InstanceType]}</p>
                </body>
                </html>
              mode: "000644"
              owner: "root"
              group: "root"
          services:
            sysvinit:
              httpd:
                enabled: true
                ensureRunning: true
    CreationPolicy:
      ResourceSignal:
        Count: 1
        Timeout: PT10M
    Properties:
      InstanceType: !FindInMap [EnvironmentConfig, !Ref EnvironmentType, InstanceType]
      ImageId: !FindInMap [RegionAMI, !Ref "AWS::Region", AmazonLinux2023]
      SubnetId: !Ref PublicSubnet
      SecurityGroupIds:
        - !Ref WebSecurityGroup
      IamInstanceProfile: !Ref EC2InstanceProfile
      KeyName: !If [HasKeyPair, !Ref KeyPairName, !Ref "AWS::NoValue"]
      Tags:
        - Key: Name
          Value: !Sub "${AWS::StackName}-web-server"
        - Key: Environment
          Value: !Ref EnvironmentType
      UserData:
        Fn::Base64: !Sub |
          #!/bin/bash -xe
          yum update -y aws-cfn-bootstrap
          /opt/aws/bin/cfn-init -v \
            --stack ${AWS::StackName} \
            --resource WebServer \
            --region ${AWS::Region}
          /opt/aws/bin/cfn-signal -e $? \
            --stack ${AWS::StackName} \
            --resource WebServer \
            --region ${AWS::Region}

  # --- S3 Bucket (demonstrates DeletionPolicy) ---
  DataBucket:
    Type: AWS::S3::Bucket
    DeletionPolicy: Retain
    Properties:
      BucketName: !Sub "${AWS::StackName}-data-${AWS::AccountId}"
      BucketEncryption:
        ServerSideEncryptionConfiguration:
          - ServerSideEncryptionByDefault:
              SSEAlgorithm: AES256
      Tags:
        - Key: Name
          Value: !Sub "${AWS::StackName}-data-bucket"

  # --- Elastic IP (only in prod) ---
  ElasticIP:
    Type: AWS::EC2::EIP
    Condition: IsProd
    Properties:
      InstanceId: !Ref WebServer
      Tags:
        - Key: Name
          Value: !Sub "${AWS::StackName}-eip"

# ============================================================
# OUTPUTS — Return values
# ============================================================
Outputs:
  VpcId:
    Description: VPC ID
    Value: !Ref VPC
    Export:
      Name: !Sub "${AWS::StackName}-VpcId"

  PublicSubnetId:
    Description: Public Subnet ID
    Value: !Ref PublicSubnet
    Export:
      Name: !Sub "${AWS::StackName}-PublicSubnetId"

  SecurityGroupId:
    Description: Web Security Group ID
    Value: !Ref WebSecurityGroup

  InstanceId:
    Description: EC2 Instance ID
    Value: !Ref WebServer

  InstancePublicIP:
    Description: EC2 Public IP Address
    Value: !GetAtt WebServer.PublicIp

  WebsiteURL:
    Description: URL of the web server
    Value: !Sub "http://${WebServer.PublicDnsName}"

  DataBucketName:
    Description: S3 Data Bucket Name
    Value: !Ref DataBucket

  DataBucketARN:
    Description: S3 Data Bucket ARN
    Value: !GetAtt DataBucket.Arn
```

---

## Part 2: Deploy the Stack

### Step 2.1 — Validate the Template

```bash
aws cloudformation validate-template \
  --template-body file://saa-lab-stack.yaml
```

### Step 2.2 — Create the Stack

```bash
aws cloudformation create-stack \
  --stack-name saa-lab-cfn \
  --template-body file://saa-lab-stack.yaml \
  --parameters \
    ParameterKey=EnvironmentType,ParameterValue=dev \
  --capabilities CAPABILITY_NAMED_IAM \
  --tags Key=Purpose,Value=SAA-Lab

echo "Stack creation initiated. Waiting for completion..."
```

### Step 2.3 — Monitor Stack Creation

```bash
# Watch stack events in real-time
aws cloudformation describe-stack-events \
  --stack-name saa-lab-cfn \
  --query "StackEvents[*].{Time:Timestamp,Resource:LogicalResourceId,Status:ResourceStatus,Reason:ResourceStatusReason}" \
  --output table

# Wait for stack to complete
aws cloudformation wait stack-create-complete --stack-name saa-lab-cfn
echo "Stack creation complete!"

# View stack outputs
aws cloudformation describe-stacks \
  --stack-name saa-lab-cfn \
  --query "Stacks[0].Outputs[*].{Key:OutputKey,Value:OutputValue}" \
  --output table
```

### Step 2.4 — Test the Web Server

```bash
# Get the public URL
URL=$(aws cloudformation describe-stacks --stack-name saa-lab-cfn --query "Stacks[0].Outputs[?OutputKey=='WebsiteURL'].OutputValue" --output text)
echo "Web server URL: $URL"

# Test it
curl $URL
```

---

## Part 3: Update with Change Set

### Step 3.1 — Modify the Template

Add a new tag to the security group in `saa-lab-stack.yaml`. In the `WebSecurityGroup` tags section, add:

```yaml
        - Key: UpdatedBy
          Value: "ChangeSet"
```

### Step 3.2 — Create a Change Set

```bash
aws cloudformation create-change-set \
  --stack-name saa-lab-cfn \
  --change-set-name add-sg-tag \
  --template-body file://saa-lab-stack.yaml \
  --parameters \
    ParameterKey=EnvironmentType,ParameterValue=dev \
  --capabilities CAPABILITY_NAMED_IAM \
  --description "Add a tag to the security group"

# Wait for change set creation
sleep 10

# Review the change set
aws cloudformation describe-change-set \
  --stack-name saa-lab-cfn \
  --change-set-name add-sg-tag \
  --query "Changes[*].{Action:ResourceChange.Action,Resource:ResourceChange.LogicalResourceId,Type:ResourceChange.ResourceType,Replacement:ResourceChange.Replacement}" \
  --output table
```

### Step 3.3 — Execute the Change Set

```bash
aws cloudformation execute-change-set \
  --stack-name saa-lab-cfn \
  --change-set-name add-sg-tag

aws cloudformation wait stack-update-complete --stack-name saa-lab-cfn
echo "Stack updated via change set."
```

---

## Part 4: Detect Drift

### Step 4.1 — Manually Modify a Resource (Create Drift)

```bash
# Manually add an inbound rule to the security group (outside CloudFormation)
SG_ID=$(aws cloudformation describe-stacks --stack-name saa-lab-cfn --query "Stacks[0].Outputs[?OutputKey=='SecurityGroupId'].OutputValue" --output text)

aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 8080 \
  --cidr "10.0.0.0/8" \
  --tag-specifications 'ResourceType=security-group-rule,Tags=[{Key=Note,Value=ManuallyAdded}]'

echo "Manually added port 8080 rule to SG (outside CloudFormation)"
```

### Step 4.2 — Run Drift Detection

```bash
# Start drift detection
DRIFT_ID=$(aws cloudformation detect-stack-drift \
  --stack-name saa-lab-cfn \
  --query "StackDriftDetectionId" \
  --output text)

echo "Drift detection started: $DRIFT_ID"

# Wait for detection to complete
sleep 30

# Check drift status
aws cloudformation describe-stack-drift-detection-status \
  --stack-drift-detection-id $DRIFT_ID

# View drifted resources
aws cloudformation describe-stack-resource-drifts \
  --stack-name saa-lab-cfn \
  --stack-resource-drift-status-filters MODIFIED DELETED \
  --query "StackResourceDrifts[*].{Resource:LogicalResourceId,Status:StackResourceDriftStatus,Differences:PropertyDifferences}" \
  --output json
```

You should see the security group marked as `MODIFIED` with the added port 8080 rule.

---

## Part 5: DeletionPolicy Demonstration

### Step 5.1 — Review DeletionPolicy in Template

In our template, the `DataBucket` has `DeletionPolicy: Retain`. This means when we delete the stack, the S3 bucket will survive.

### Step 5.2 — Delete the Stack

```bash
# Delete the stack
aws cloudformation delete-stack --stack-name saa-lab-cfn

aws cloudformation wait stack-delete-complete --stack-name saa-lab-cfn
echo "Stack deleted."

# Verify the S3 bucket still exists (DeletionPolicy: Retain)
BUCKET_NAME="saa-lab-cfn-data-$(aws sts get-caller-identity --query Account --output text)"
aws s3 ls s3://$BUCKET_NAME 2>/dev/null && echo "Bucket RETAINED (DeletionPolicy worked!)" || echo "Bucket not found"
```

---

## Cleanup

```bash
# The stack was already deleted above.
# But the S3 bucket with DeletionPolicy: Retain still exists.
# Delete it manually:
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws s3 rb s3://saa-lab-cfn-data-${ACCOUNT_ID}

# Also remove the manually-added security group rule drift (SG was deleted with stack)
# Clean up the template file
rm -f saa-lab-stack.yaml

echo "Full cleanup complete."
```

---

## Review Questions

1. What is the only required section in a CloudFormation template?
2. What does `!Sub "${AWS::StackName}-vpc"` do?
3. What is the difference between `Action` and `OverrideAction` in a CloudFormation change set preview?
4. What happens if `cfn-signal` does not send a signal within the CreationPolicy timeout?
5. What is the difference between `DeletionPolicy: Retain` and `DeletionPolicy: Snapshot`?

## Answers

1. `Resources` is the only required section.
2. It substitutes the pseudo parameter `AWS::StackName` into the string, producing something like `saa-lab-cfn-vpc`.
3. A change set shows `Action` as Add, Modify, or Remove for each resource. `Replacement` indicates whether the resource will be replaced (True), updated in place (False), or conditionally replaced (Conditional).
4. The resource creation fails, and the entire stack rolls back.
5. `Retain` keeps the resource as-is after stack deletion. `Snapshot` creates a snapshot of the resource (EBS, RDS, etc.) before deleting it. `Snapshot` is only supported for specific resource types.

---

## Next Steps

You have completed all 7 labs! Proceed to the **Projects** section to build comprehensive, multi-service solutions.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Estimated Time: 75-90 minutes
- Write the CloudFormation Template
- Deploy the Stack
- Update with Change Set

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
