# AWS SAA-C03 Study Project (Python / Boto3 / Terraform)

A hands-on study project for the **AWS Solutions Architect Associate
(SAA-C03)** exam.  Every topic is reinforced with working Python/Boto3
scripts, AWS CLI commands, and Terraform configurations that you deploy
into a real AWS account.

---

## Project Structure

```
python-saa/
  README.md                     You are here
  requirements.txt              Python dependencies
  .env.example                  Example environment variables
  .gitignore                    Files excluded from git

  shared/                       Reusable code and config
    README.md                   Overview of shared utilities
    utils/
      aws_helpers.py            Boto3 session, client, tagging, pretty-print
      cost_tracker.py           Cost estimates and lab timer
    cleanup-scripts/
      cleanup_all.py            Master cleanup (all phases)
      cleanup_phase1.py         Phase 1 cleanup
      cleanup_phase2.py         Phase 2 cleanup
      cleanup_phase3.py         Phase 3 cleanup
    terraform/
      provider.tf               AWS provider + default tags
      variables.tf              Common variables
      outputs.tf                Placeholder outputs
    diagrams/
      README.md                 Notation guide for ASCII diagrams

  phase-1-foundations/           VPC, Networking, IAM, EC2 basics
    (labs and exercises)

  phase-2-compute-storage/      EC2 deep-dive, ASG, EBS, EFS, S3, Lambda
    (labs and exercises)

  phase-3-databases-messaging/  RDS, DynamoDB, ElastiCache, SQS, SNS
    (labs and exercises)

  phase-4-ha-security/          HA architectures, CloudFront, Route 53, KMS
    (labs and exercises)

  phase-5-exam-prep/            Practice questions, review, mock exams
    (labs and exercises)
```

---

## Prerequisites

Before starting, make sure you have the following installed and
configured on your machine:

| Tool             | Minimum Version | Installation                                    |
|-----------------|----------------|------------------------------------------------|
| **Python**       | 3.8+           | https://www.python.org/downloads/               |
| **pip**          | 21+            | Included with Python                             |
| **AWS CLI**      | 2.x            | https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html |
| **Terraform**    | 1.5+           | https://developer.hashicorp.com/terraform/install |
| **git**          | 2.x            | https://git-scm.com/downloads                   |

You also need an **AWS account**.  A free-tier account is sufficient for
most labs, but some resources (NAT Gateways, RDS Multi-AZ) will incur
charges.  See *Cost Management* below.

---

## Setup Instructions

### 1. Clone the repository

```bash
git clone <your-repo-url> python-saa
cd python-saa
```

### 2. Create a virtual environment and install dependencies

```bash
python -m venv venv
source venv/bin/activate          # macOS / Linux
# venv\Scripts\activate           # Windows
pip install -r requirements.txt
```

### 3. Configure AWS credentials

```bash
aws configure
# Enter your Access Key ID, Secret Access Key, default region (us-east-1),
# and output format (json).
```

Or copy the example environment file and fill in your details:

```bash
cp .env.example .env
# Edit .env with your preferred editor.
```

### 4. Verify your setup

```bash
aws sts get-caller-identity
# You should see your account ID, user ARN, and user ID.

python -c "import boto3; print(boto3.Session().region_name)"
# Should print: us-east-1 (or your configured region)

terraform -version
# Should print: Terraform v1.x.x
```

---

## How to Use This Study Plan

Work through the phases **in order**.  Each phase builds on the
knowledge and infrastructure from the previous one.

### Recommended workflow for each lab

1. **Read the theory** in the lab's README or notes.
2. **Review the architecture diagram** (see `shared/diagrams/README.md`
   for the notation guide).
3. **Run the Boto3 script** to deploy resources and observe what happens.
4. **Experiment** in the AWS Console — click around, look at the
   resources, check the tags.
5. **Modify the script** — change a CIDR block, add a new subnet, break
   something on purpose and fix it.
6. **Run the cleanup script** to tear everything down.
7. **Move on** to the next lab.

### Phase overview

| Phase | Focus                                  | Key Services                                    |
|-------|---------------------------------------|-------------------------------------------------|
| 1     | Foundations                            | VPC, Subnets, IGW, NAT GW, SGs, NACLs, IAM, EC2 |
| 2     | Compute and Storage                    | EC2 deep-dive, ASG, EBS, EFS, S3, Lambda        |
| 3     | Databases and Application Integration  | RDS, DynamoDB, ElastiCache, SQS, SNS, Kinesis   |
| 4     | High Availability and Security         | Multi-AZ, CloudFront, Route 53, KMS, WAF        |
| 5     | Exam Preparation                       | Practice questions, weak-area review, mock exams |

---

## Cost Management

**This is critical.**  AWS charges by the hour (or by the second) for
many resources.  Forgetting to clean up after a lab can result in
unexpected charges.

### Strategy

1. **Always tag resources** with `Project = python-saa`.  The helper
   function `get_project_tags()` in `aws_helpers.py` does this for you.
2. **Check estimated costs before deploying** using `print_cost_warning()`
   from `cost_tracker.py`.
3. **Run the cleanup script immediately after finishing a lab.**
4. **Use the dry-run mode first** to see what would be deleted.
5. **Set a billing alarm** in the AWS Console:
   - Go to Billing > Budgets > Create a budget.
   - Set a monthly budget of $5-10 with email alerts at 50% and 80%.

### Running cleanup

```bash
# Dry run (safe — shows what would be deleted):
python shared/cleanup-scripts/cleanup_all.py

# Actually delete everything:
python shared/cleanup-scripts/cleanup_all.py --execute

# Phase-specific cleanup:
python shared/cleanup-scripts/cleanup_phase1.py --execute
python shared/cleanup-scripts/cleanup_phase2.py --execute
python shared/cleanup-scripts/cleanup_phase3.py --execute
```

### Highest-cost resources to watch

| Resource            | Approx. Hourly Cost | Monthly if Forgotten |
|--------------------|--------------------:|---------------------:|
| NAT Gateway         | $0.045              | $32.40               |
| RDS db.t3.micro     | $0.017              | $12.24               |
| ALB                 | $0.023              | $16.20               |
| ElastiCache t3.micro| $0.017              | $12.24               |
| EC2 t3.micro        | $0.010              | $7.49                |

---

## Troubleshooting

**"No credentials found" error**
- Run `aws configure` and enter your keys.
- Or set `AWS_PROFILE` in your `.env` file.

**"Region not specified" error**
- Set `AWS_DEFAULT_REGION=us-east-1` in your `.env` or shell.

**"Access denied" error**
- Your IAM user may not have the required permissions.
- For study purposes, attach the `AdministratorAccess` policy.
- In production, always use least-privilege policies.

**Terraform "provider not found" error**
- Run `terraform init` to download the AWS provider plugin.

---

## Links

- [AWS SAA-C03 Exam Guide](https://d1.awsstatic.com/training-and-certification/docs-sa-assoc/AWS-Certified-Solutions-Architect-Associate_Exam-Guide.pdf)
- [AWS Free Tier](https://aws.amazon.com/free/)
- [Boto3 Documentation](https://boto3.amazonaws.com/v1/documentation/api/latest/index.html)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Well-Architected Framework](https://docs.aws.amazon.com/wellarchitected/latest/framework/welcome.html)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Project Structure
- Setup Instructions
- Cost Management
- Links

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
