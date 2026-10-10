# Lab 1.1: Environment Setup

## Objective

Set up a complete Terraform development environment with all necessary tools and configurations.

## Duration: 30 minutes

---

## Part 1: Install Terraform CLI

### macOS (using Homebrew)

```bash
# Install Homebrew if not present
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Terraform
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

# Verify installation
terraform version
```

### Linux (Ubuntu/Debian)

```bash
# Add HashiCorp GPG key
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

# Add repository
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

# Install
sudo apt update && sudo apt install terraform

# Verify
terraform version
```

### Windows (using Chocolatey)

```powershell
# Install Chocolatey if not present (run as Administrator)
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Install Terraform
choco install terraform

# Verify
terraform version
```

---

## Part 2: Configure Shell Autocompletion

```bash
# Bash
terraform -install-autocomplete

# Zsh (add to ~/.zshrc)
autoload -U +X bashcompinit && bashcompinit
complete -o nospace -C /usr/local/bin/terraform terraform

# Reload shell
source ~/.bashrc  # or ~/.zshrc
```

---

## Part 3: Install AWS CLI

### macOS

```bash
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
sudo installer -pkg AWSCLIV2.pkg -target /
aws --version
```

### Linux

```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
aws --version
```

---

## Part 4: Configure AWS Credentials

### Option A: AWS CLI Configuration (Recommended for Learning)

```bash
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Enter default region (e.g., us-east-1)
# Enter output format (json)
```

### Option B: Environment Variables

```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"
```

### Option C: AWS Profile (Best Practice)

```bash
# Create named profile
aws configure --profile terraform-learning

# Use in Terraform
export AWS_PROFILE=terraform-learning
```

### Verify AWS Access

```bash
aws sts get-caller-identity
```

Expected output:
```json
{
    "UserId": "AIDAXXXXXXXXXXXXXXXXX",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/your-username"
}
```

---

## Part 5: Install Development Tools

### VS Code Extensions

1. **HashiCorp Terraform** - Syntax highlighting, validation, autocompletion
2. **Terraform doc snippets** - Quick documentation access
3. **GitLens** - Git integration

### Install via CLI

```bash
code --install-extension hashicorp.terraform
code --install-extension run-at-scale.terraform-doc-snippets
```

### Additional Tools

```bash
# TFLint - Terraform linter
brew install tflint  # macOS
# or
curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash

# tfsec - Security scanner
brew install tfsec  # macOS
# or
curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash

# Verify installations
tflint --version
tfsec --version
```

---

## Part 6: Create Project Structure

```bash
# Create learning workspace
mkdir -p ~/terraform-learning/{labs,projects,modules}
cd ~/terraform-learning

# Create first project
mkdir -p labs/01-hello-terraform
cd labs/01-hello-terraform

# Create initial files
touch main.tf variables.tf outputs.tf terraform.tfvars
```

### Recommended Project Structure

**`project/`**

| File | What it is |
|---|---|
| `main.tf` | Primary configuration |
| `variables.tf` | Input variable definitions |
| `outputs.tf` | Output definitions |
| `terraform.tfvars` | Variable values (gitignored) |
| `versions.tf` | Provider and Terraform version constraints |
| `locals.tf` | Local values |
| `data.tf` | Data sources |
| `README.md` | Documentation |


---

## Part 7: Verification Exercise

Create a file named `main.tf` with this content to verify your setup:

```hcl
# main.tf
terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Simple data source to verify AWS connectivity
data "aws_caller_identity" "current" {}

output "account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "caller_arn" {
  value = data.aws_caller_identity.current.arn
}
```

### Run Verification

```bash
# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Plan (no changes, just verification)
terraform plan

# Apply to see outputs
terraform apply -auto-approve
```

### Expected Output

```
Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

Outputs:

account_id = "123456789012"
caller_arn = "arn:aws:iam::123456789012:user/your-username"
```

---

## Troubleshooting

### Issue: "No valid credential sources found"

```bash
# Check AWS credentials
aws sts get-caller-identity

# Ensure credentials file exists
cat ~/.aws/credentials
```

### Issue: "Provider registry.terraform.io/hashicorp/aws not found"

```bash
# Clear provider cache
rm -rf .terraform
terraform init
```

### Issue: Permission Denied

```bash
# Ensure Terraform is executable
chmod +x $(which terraform)
```

---

## Checkpoint

Before moving to Lab 1.2, verify:

- [ ] `terraform version` returns version 1.x or higher
- [ ] `aws sts get-caller-identity` shows your account
- [ ] `terraform init` completes successfully
- [ ] `terraform validate` shows "Success!"
- [ ] VS Code Terraform extension is installed

---

## Next: Lab 1.2 - HCL Syntax Deep Dive

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Install Terraform CLI
- Configure Shell Autocompletion
- Install AWS CLI
- Configure AWS Credentials

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"Terraform manages your infrastructure."* |
| ✓ | *"`plan` is a three-way comparison: the configuration (desired), the state file (what Terraform believes it created), and a refresh against the real API (what exists). Almost every confusing result is one of those three drifting from the other two."* |

**Trace it:** `terraform apply` on one resource: config → plan → API call → state write. Then say what happens if the process dies between the API call and the state write.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** [the purpose of Terraform state](https://developer.hashicorp.com/terraform/language/state/purpose) — almost every confusing result is a three-way disagreement, spelled out there.
Full list per domain: [`SOURCES.md`](../../SOURCES.md#terraform)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../../MASTERY.md)

<!-- /feynman-check -->
