# Shared Utilities

This directory contains reusable code, cleanup scripts, Terraform
configurations, and diagrams shared across all study phases.

---

## Directory Structure

```
shared/
  utils/                    Python helper modules
    aws_helpers.py          Boto3 session, client, tagging, pretty-print
    cost_tracker.py         Cost estimates, warnings, lab timer
  cleanup-scripts/          Automated resource teardown
    cleanup_all.py          Master cleanup (all phases)
    cleanup_phase1.py       Phase 1: VPC, networking, EC2
    cleanup_phase2.py       Phase 2: Compute, storage, serverless
    cleanup_phase3.py       Phase 3: Databases, caching, messaging
  terraform/                Shared Terraform configuration
    provider.tf             AWS provider + default tags
    variables.tf            Common variables (region, project name)
    outputs.tf              Placeholder outputs with usage guide
  diagrams/                 Architecture diagram resources
    README.md               Notation guide for text-based diagrams
```

---

## Using the Python Helpers

### aws_helpers.py

```python
# Import helpers into any lab script.
from shared.utils.aws_helpers import (
    get_client,
    get_resource,
    wait_for_resource,
    tag_ec2_resource,
    print_json,
    get_project_tags,
)

# Create a client for a specific service.
ec2 = get_client("ec2", region="us-east-1")

# Describe resources and pretty-print the result.
response = ec2.describe_vpcs()
print_json(response)

# Tag a resource with the standard project tags plus extras.
tag_ec2_resource(ec2, ["i-0123456789abcdef0"], {
    "Name": "Lab-Instance",
    "Phase": "1",
})

# Wait for an instance to reach the "running" state.
wait_for_resource(ec2, "instance_running", InstanceIds=["i-0123456789abcdef0"])
```

### cost_tracker.py

```python
from shared.utils.cost_tracker import print_cost_warning, CostTimer

# Show estimated costs before deploying.
print_cost_warning(["nat_gateway", "ec2_t3_micro", "rds_single_az"])

# Track lab duration and estimate spend.
timer = CostTimer(["nat_gateway", "ec2_t3_micro"])
timer.start()
# ... do lab work ...
timer.stop()
timer.print_summary()
```

---

## Running Cleanup Scripts

Every cleanup script supports two modes:

| Mode      | Flag        | Behaviour                              |
|-----------|-------------|----------------------------------------|
| Dry run   | *(default)* | Lists what would be deleted, no changes |
| Execute   | `--execute` | Actually deletes resources               |

### Quick reference

```bash
# See what Phase 1 resources exist (safe, no deletions):
python shared/cleanup-scripts/cleanup_phase1.py

# Actually delete Phase 1 resources:
python shared/cleanup-scripts/cleanup_phase1.py --execute

# Clean up everything across all phases:
python shared/cleanup-scripts/cleanup_all.py --execute

# Target a different region:
python shared/cleanup-scripts/cleanup_all.py --region us-west-2 --execute
```

### How tag filtering works

All cleanup scripts look for resources tagged with:

```
Project = python-saa
```

If a resource does not have this tag, it will **not** be touched.  This
means your personal or production resources are safe as long as they do
not share the same tag.

Always tag your lab resources using the helpers in `aws_helpers.py` to
ensure the cleanup scripts can find them.

---

## Terraform Setup

### First-time setup

1. Install Terraform (>= 1.5.0): https://developer.hashicorp.com/terraform/install
2. Copy or symlink the shared Terraform files into your phase directory:

```bash
cd phase-1-foundations/terraform/
ln -s ../../shared/terraform/provider.tf .
ln -s ../../shared/terraform/variables.tf .
```

3. Initialise Terraform:

```bash
terraform init
```

4. Plan and apply:

```bash
terraform plan
terraform apply
```

5. When finished, destroy all resources:

```bash
terraform destroy
```

### Customising variables

Create a `terraform.tfvars` file in the phase directory:

```hcl
aws_region   = "us-west-2"
project_name = "python-saa"
environment  = "lab"

common_tags = {
  Phase = "1"
  Owner = "student"
}
```

---

## Diagrams

The `diagrams/` directory contains a `README.md` that explains the
text-based ASCII art notation used throughout the study materials.
Read it once so you can quickly interpret the architecture diagrams
in each phase.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Using the Python Helpers
- Running Cleanup Scripts
- Terraform Setup
- Quick reference

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
