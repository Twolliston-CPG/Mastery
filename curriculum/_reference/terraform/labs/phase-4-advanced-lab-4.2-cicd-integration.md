# Lab 4.2: CI/CD Integration

## Objective

Integrate Terraform into CI/CD pipelines with best practices for automation.

## Duration: 120 minutes

---

## Part 1: GitHub Actions

### Basic Workflow

```yaml
# .github/workflows/terraform.yml
name: Terraform

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

env:
  TF_VERSION: "1.6.0"
  AWS_REGION: "us-east-1"

jobs:
  terraform:
    name: Terraform
    runs-on: ubuntu-latest

    permissions:
      contents: read
      pull-requests: write

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Terraform Format
        id: fmt
        run: terraform fmt -check -recursive
        continue-on-error: true

      - name: Terraform Init
        id: init
        run: terraform init

      - name: Terraform Validate
        id: validate
        run: terraform validate

      - name: Terraform Plan
        id: plan
        if: github.event_name == 'pull_request'
        run: terraform plan -no-color -out=tfplan
        continue-on-error: true

      - name: Update PR
        uses: actions/github-script@v7
        if: github.event_name == 'pull_request'
        with:
          script: |
            const output = `#### Terraform Format 🖌\`${{ steps.fmt.outcome }}\`
            #### Terraform Init ⚙️\`${{ steps.init.outcome }}\`
            #### Terraform Validate 🤖\`${{ steps.validate.outcome }}\`
            #### Terraform Plan 📖\`${{ steps.plan.outcome }}\`

            <details><summary>Show Plan</summary>

            \`\`\`terraform
            ${{ steps.plan.outputs.stdout }}
            \`\`\`

            </details>

            *Pushed by: @${{ github.actor }}, Action: \`${{ github.event_name }}\`*`;

            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: output
            })

      - name: Terraform Apply
        if: github.ref == 'refs/heads/main' && github.event_name == 'push'
        run: terraform apply -auto-approve
```

### Multi-Environment Workflow

```yaml
# .github/workflows/terraform-environments.yml
name: Terraform Multi-Environment

on:
  push:
    branches:
      - main
      - 'release/**'
  pull_request:
    branches: [main]

jobs:
  plan:
    name: Plan - ${{ matrix.environment }}
    runs-on: ubuntu-latest
    strategy:
      matrix:
        environment: [dev, staging, prod]
      fail-fast: false

    steps:
      - uses: actions/checkout@v4

      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.6.0"

      - name: Configure AWS
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets[format('AWS_ROLE_{0}', matrix.environment)] }}
          aws-region: us-east-1

      - name: Init
        run: |
          terraform init \
            -backend-config="key=${{ matrix.environment }}/terraform.tfstate"

      - name: Plan
        run: |
          terraform plan \
            -var-file="environments/${{ matrix.environment }}.tfvars" \
            -out=${{ matrix.environment }}.tfplan

      - name: Upload Plan
        uses: actions/upload-artifact@v4
        with:
          name: ${{ matrix.environment }}-plan
          path: ${{ matrix.environment }}.tfplan

  apply-dev:
    name: Apply Dev
    needs: plan
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment: dev

    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3

      - name: Download Plan
        uses: actions/download-artifact@v4
        with:
          name: dev-plan

      - name: Apply
        run: terraform apply dev.tfplan

  apply-staging:
    name: Apply Staging
    needs: apply-dev
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment: staging

    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3

      - name: Download Plan
        uses: actions/download-artifact@v4
        with:
          name: staging-plan

      - name: Apply
        run: terraform apply staging.tfplan

  apply-prod:
    name: Apply Production
    needs: apply-staging
    if: startsWith(github.ref, 'refs/heads/release/')
    runs-on: ubuntu-latest
    environment: production

    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3

      - name: Download Plan
        uses: actions/download-artifact@v4
        with:
          name: prod-plan

      - name: Apply
        run: terraform apply prod.tfplan
```

---

## Part 2: GitLab CI

```yaml
# .gitlab-ci.yml
image: hashicorp/terraform:1.6.0

variables:
  TF_ROOT: ${CI_PROJECT_DIR}
  TF_ADDRESS: ${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/terraform/state/default

cache:
  key: "${CI_COMMIT_REF_SLUG}"
  paths:
    - ${TF_ROOT}/.terraform

stages:
  - validate
  - plan
  - apply
  - destroy

before_script:
  - cd ${TF_ROOT}
  - terraform init
    -backend-config="address=${TF_ADDRESS}"
    -backend-config="lock_address=${TF_ADDRESS}/lock"
    -backend-config="unlock_address=${TF_ADDRESS}/lock"
    -backend-config="username=gitlab-ci-token"
    -backend-config="password=${CI_JOB_TOKEN}"
    -backend-config="lock_method=POST"
    -backend-config="unlock_method=DELETE"
    -backend-config="retry_wait_min=5"

validate:
  stage: validate
  script:
    - terraform validate
    - terraform fmt -check -recursive

plan:
  stage: plan
  script:
    - terraform plan -out=plan.tfplan
  artifacts:
    paths:
      - ${TF_ROOT}/plan.tfplan
    expire_in: 1 week

apply:
  stage: apply
  script:
    - terraform apply -auto-approve plan.tfplan
  dependencies:
    - plan
  when: manual
  only:
    - main

destroy:
  stage: destroy
  script:
    - terraform destroy -auto-approve
  when: manual
  only:
    - main
```

---

## Part 3: Atlantis (PR Automation)

### atlantis.yaml

```yaml
# atlantis.yaml
version: 3
projects:
  - name: infrastructure
    dir: .
    workspace: default
    terraform_version: v1.6.0
    autoplan:
      when_modified: ["*.tf", "*.tfvars", "modules/**/*.tf"]
      enabled: true
    apply_requirements: [approved, mergeable]
    workflow: default

  - name: infrastructure-dev
    dir: environments/dev
    workspace: dev
    terraform_version: v1.6.0
    autoplan:
      enabled: true
    apply_requirements: [approved]

  - name: infrastructure-prod
    dir: environments/prod
    workspace: prod
    terraform_version: v1.6.0
    autoplan:
      enabled: true
    apply_requirements: [approved, mergeable]
    workflow: prod

workflows:
  default:
    plan:
      steps:
        - init
        - plan
    apply:
      steps:
        - apply

  prod:
    plan:
      steps:
        - init
        - run: tfsec .
        - plan:
            extra_args: ["-var-file=prod.tfvars"]
    apply:
      steps:
        - run: echo "Applying to production..."
        - apply
```

---

## Part 4: Security Scanning

### tfsec Integration

```yaml
# .github/workflows/security.yml
name: Security Scan

on: [push, pull_request]

jobs:
  tfsec:
    name: tfsec
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: tfsec
        uses: aquasecurity/tfsec-action@v1.0.0
        with:
          soft_fail: true
          format: sarif
          out: tfsec.sarif

      - name: Upload SARIF
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: tfsec.sarif

  checkov:
    name: Checkov
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Checkov
        uses: bridgecrewio/checkov-action@v12
        with:
          directory: .
          framework: terraform
          output_format: sarif
          output_file_path: checkov.sarif

      - name: Upload SARIF
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: checkov.sarif
```

### Pre-commit Hooks

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.83.0
    hooks:
      - id: terraform_fmt
      - id: terraform_validate
      - id: terraform_docs
        args:
          - --hook-config=--path-to-file=README.md
          - --hook-config=--add-to-existing-file=true
          - --hook-config=--create-file-if-not-exist=true
      - id: terraform_tflint
        args:
          - --args=--config=__GIT_WORKING_DIR__/.tflint.hcl
      - id: terraform_tfsec
      - id: terraform_checkov
```

```bash
# Install pre-commit
pip install pre-commit

# Install hooks
pre-commit install

# Run manually
pre-commit run --all-files
```

---

## Part 5: Cost Estimation

### Infracost Integration

```yaml
# .github/workflows/infracost.yml
name: Infracost

on:
  pull_request:
    branches: [main]

jobs:
  infracost:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write

    steps:
      - uses: actions/checkout@v4

      - name: Setup Infracost
        uses: infracost/actions/setup@v3
        with:
          api-key: ${{ secrets.INFRACOST_API_KEY }}

      - name: Checkout base
        uses: actions/checkout@v4
        with:
          ref: ${{ github.event.pull_request.base.sha }}
          path: base

      - name: Generate base cost
        run: |
          infracost breakdown --path=base \
            --format=json \
            --out-file=/tmp/base.json

      - name: Checkout PR
        uses: actions/checkout@v4
        with:
          path: pr

      - name: Generate PR cost
        run: |
          infracost breakdown --path=pr \
            --format=json \
            --out-file=/tmp/pr.json

      - name: Generate diff
        run: |
          infracost diff --path=/tmp/pr.json \
            --compare-to=/tmp/base.json \
            --format=json \
            --out-file=/tmp/diff.json

      - name: Post comment
        run: |
          infracost comment github \
            --path=/tmp/diff.json \
            --repo=${{ github.repository }} \
            --pull-request=${{ github.event.pull_request.number }} \
            --github-token=${{ github.token }} \
            --behavior=update
```

---

## Part 6: Drift Detection Pipeline

```yaml
# .github/workflows/drift-detection.yml
name: Drift Detection

on:
  schedule:
    - cron: '0 */6 * * *'  # Every 6 hours
  workflow_dispatch:

jobs:
  detect-drift:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        environment: [dev, staging, prod]

    steps:
      - uses: actions/checkout@v4

      - uses: hashicorp/setup-terraform@v3

      - name: Configure AWS
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets[format('AWS_ROLE_{0}', matrix.environment)] }}
          aws-region: us-east-1

      - name: Init
        run: |
          terraform init \
            -backend-config="key=${{ matrix.environment }}/terraform.tfstate"

      - name: Detect Drift
        id: drift
        run: |
          terraform plan -refresh-only -detailed-exitcode 2>&1 | tee plan.log
          echo "exit_code=$?" >> $GITHUB_OUTPUT
        continue-on-error: true

      - name: Notify on Drift
        if: steps.drift.outputs.exit_code == '2'
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "Drift detected in ${{ matrix.environment }}!",
              "blocks": [
                {
                  "type": "section",
                  "text": {
                    "type": "mrkdwn",
                    "text": "*Drift detected in ${{ matrix.environment }}*\n<${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}|View details>"
                  }
                }
              ]
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}
```

---

## Exercise: Complete CI/CD Pipeline

Create a production-ready CI/CD pipeline with:

1. Format and validate on every PR
2. Security scanning (tfsec, checkov)
3. Cost estimation with Infracost
4. Plan preview in PR comments
5. Manual approval for production
6. Scheduled drift detection
7. Slack/Teams notifications

---

## Checkpoint

Before moving to Phase 5, verify you can:

- [ ] Create GitHub Actions workflows
- [ ] Implement multi-environment pipelines
- [ ] Integrate security scanning
- [ ] Add cost estimation
- [ ] Automate drift detection
- [ ] Configure notifications

---

## Next: Phase 5 - Professional Topics

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- GitHub Actions
- GitLab CI
- Atlantis (PR Automation)
- Security Scanning

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
