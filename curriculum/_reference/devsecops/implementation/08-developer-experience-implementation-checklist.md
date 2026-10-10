# Domain 8: Developer Experience -- Implementation Checklist

## Prerequisites

- [ ] Python 3.8+ installed (for pre-commit)
- [ ] Go 1.22+ installed (for golangci-lint, gosec, gitleaks)
- [ ] Node.js 18+ installed (for Backstage)
- [ ] Helm 3.x installed (for helmlint hook)
- [ ] Docker installed (for hadolint)
- [ ] `kubectl` configured with cluster access (for PR previews)
- [ ] GitHub organization with admin access
- [ ] PostgreSQL instance available (for Backstage)

---

## Phase 1: Pre-Commit Hooks

### Step 1.1: Install pre-commit

```bash
# Install pre-commit
pip install pre-commit

# Verify installation
pre-commit --version
# Expected: pre-commit 3.x.x
```

### Step 1.2: Copy configuration files

```bash
# Copy pre-commit config to your repository root
cp templates/pre-commit-config.yaml .pre-commit-config.yaml

# Copy golangci-lint config (for Go repositories)
cp templates/golangci.yml .golangci.yml

# Copy markdownlint config
cp templates/markdownlint.json .markdownlint.json
```

### Step 1.3: Install hooks in repository

```bash
# Install pre-commit hooks
pre-commit install

# Install commit-msg hooks (for commitizen)
pre-commit install --hook-type commit-msg
```

**Verification:**

```bash
# Verify hooks are installed
ls -la .git/hooks/pre-commit .git/hooks/commit-msg
# Expected: Both files exist and are executable

# Run all hooks against entire repo
pre-commit run --all-files
# Expected: All hooks pass (or show expected findings)
```

### Step 1.4: Test individual hooks

```bash
# Test gitleaks (should find no secrets)
pre-commit run gitleaks --all-files

# Test Terraform hooks (only if .tf files exist)
pre-commit run terraform_fmt --all-files
pre-commit run terraform_validate --all-files

# Test Go hooks (only if .go files exist)
pre-commit run golangci-lint --all-files
pre-commit run gosec --all-files

# Test standard hooks
pre-commit run check-yaml --all-files
pre-commit run check-json --all-files
pre-commit run trailing-whitespace --all-files
pre-commit run end-of-file-fixer --all-files

# Test commitizen (requires a commit message)
echo "test: valid conventional commit" | pre-commit run commitizen --commit-msg-filename=/dev/stdin
```

### Step 1.5: Test the no-commit-to-branch guard

```bash
# Attempt a commit on main (should be blocked)
git checkout main
echo "test" > /tmp/test.txt && git add /tmp/test.txt
git commit -m "test: this should fail"
# Expected: "no-commit-to-branch" hook FAILS

# Clean up
git checkout -
git reset HEAD /tmp/test.txt 2>/dev/null
```

- [ ] pre-commit installed and hooks registered
- [ ] All 20 hooks pass on `pre-commit run --all-files`
- [ ] `no-commit-to-branch` blocks commits to main
- [ ] Commitizen validates conventional commit format

---

## Phase 2: Backstage Developer Portal

### Step 2.1: Set up Backstage project

```bash
# Create Backstage app (if starting fresh)
npx @backstage/create-app@latest --name {{APP_NAME}}-backstage

# Or copy template configuration into existing Backstage app
cp templates/backstage/app-config.yaml <backstage-repo>/app-config.yaml
cp templates/backstage/app-config.staging.yaml <backstage-repo>/app-config.staging.yaml
cp templates/backstage/app-config.production.yaml <backstage-repo>/app-config.production.yaml
```

### Step 2.2: Configure catalog entities

```bash
# Copy catalog structure
cp -r templates/backstage/catalog/ <backstage-repo>/catalog/

# Customize domain, systems, and resources
# Edit catalog/domains/domain.yaml -- replace {{APP_NAME}}, {{TEAM_NAME}}
# Edit catalog/systems/*.yaml -- replace placeholders
# Edit catalog/resources.yaml -- replace placeholders
```

### Step 2.3: Set up environment variables

```bash
# Required environment variables for Backstage
export APP_BASE_URL="https://backstage.{{DOMAIN}}"
export BACKEND_BASE_URL="https://backstage.{{DOMAIN}}"
export POSTGRES_HOST="localhost"
export POSTGRES_PORT="5432"
export POSTGRES_USER="backstage"
export POSTGRES_PASSWORD="<secure-password>"
export GITHUB_TOKEN="<github-fine-grained-pat>"
export GITHUB_OAUTH_CLIENT_ID="<oauth-app-client-id>"
export GITHUB_OAUTH_CLIENT_SECRET="<oauth-app-client-secret>"
export K8S_CLUSTER_URL="https://<cluster-api-url>"
export K8S_SERVICE_ACCOUNT_TOKEN="<service-account-token>"
export ARGOCD_URL="https://argocd.{{DOMAIN}}"
export ARGOCD_AUTH_TOKEN="<argocd-api-token>"
export PROMETHEUS_URL="http://prometheus.monitoring.svc.cluster.local:9090"
export REDIS_HOST="localhost"
export REDIS_PORT="6379"
export REDIS_PASSWORD="<redis-password>"
```

### Step 2.4: Install Backstage plugins

```bash
cd <backstage-repo>

# Install Kubernetes plugin
yarn --cwd packages/backend add @backstage/plugin-kubernetes-backend
yarn --cwd packages/app add @backstage/plugin-kubernetes

# Install ArgoCD plugin
yarn --cwd packages/app add @roadiehq/backstage-plugin-argo-cd

# Install Prometheus plugin
yarn --cwd packages/app add @roadiehq/backstage-plugin-prometheus

# Install GitHub Actions plugin
yarn --cwd packages/app add @backstage/plugin-github-actions

# Install TechDocs
yarn --cwd packages/backend add @backstage/plugin-techdocs-backend
yarn --cwd packages/app add @backstage/plugin-techdocs
```

### Step 2.5: Start and verify Backstage

```bash
# Start in development mode
cd <backstage-repo>
yarn dev

# Verify Backstage is accessible
curl -s http://localhost:3000 | head -5
# Expected: HTML content from Backstage frontend

# Verify backend health
curl -s http://localhost:7007/healthcheck
# Expected: {"status":"ok"}

# Verify catalog entities loaded
curl -s http://localhost:7007/api/catalog/entities | python3 -m json.tool | head -20
# Expected: JSON array of catalog entities
```

### Step 2.6: Add catalog-info.yaml to each service repository

```bash
# For Go services
cp consumer-templates/go-service/catalog-info.yaml <go-service-repo>/catalog-info.yaml
# Edit: replace {{SERVICE_NAME}}, {{ORG_NAME}}, {{TEAM_NAME}}, etc.

# For Node.js services
cp consumer-templates/node-service/catalog-info.yaml <node-service-repo>/catalog-info.yaml
# Edit: replace {{SERVICE_NAME}}, {{ORG_NAME}}, {{TEAM_NAME}}, etc.
```

**Verification:**

```bash
# Verify entity appears in Backstage catalog
curl -s "http://localhost:7007/api/catalog/entities?filter=metadata.name={{SERVICE_NAME}}" | python3 -m json.tool
# Expected: Entity with correct metadata and annotations
```

- [ ] Backstage application deployed and accessible
- [ ] PostgreSQL database configured and connected
- [ ] GitHub OAuth configured for authentication
- [ ] Kubernetes plugin showing pod status
- [ ] ArgoCD plugin showing deployment status
- [ ] Prometheus plugin showing metrics
- [ ] TechDocs rendering documentation
- [ ] All service catalog-info.yaml files registered

---

## Phase 3: Renovate

### Step 3.1: Install Renovate GitHub App

```bash
# Install Renovate GitHub App from: https://github.com/apps/renovate
# Grant access to all repositories in your organization

# Alternatively, self-host Renovate:
npm install -g renovate
```

### Step 3.2: Create shared preset

```bash
# Copy the shared Go preset to your workflows repository
cp templates/renovate/renovate-go.json <workflows-repo>/templates/renovate-go.json

# Customize:
# - Replace {{ORG_NAME}} with your GitHub org
# - Replace team names in assignees/reviewers
# - Adjust schedule and timezone
```

### Step 3.3: Add Renovate config to each service

```bash
# For Go services
cp consumer-templates/go-service/renovate.json <go-service-repo>/renovate.json
# Edit: replace {{ORG_NAME}}, {{APP_NAME}}, {{SERVICE_NAME}}

# For Node.js services
cp consumer-templates/node-service/renovate.json <node-service-repo>/renovate.json
# Edit: replace {{ORG_NAME}}, {{APP_NAME}}, {{SERVICE_NAME}}
```

**Verification:**

```bash
# Check Renovate dashboard issue in the repository
gh issue list --repo {{ORG_NAME}}/{{SERVICE_NAME}} --label "renovate"
# Expected: "Dependency Dashboard" issue exists

# Verify Renovate is creating PRs
gh pr list --repo {{ORG_NAME}}/{{SERVICE_NAME}} --label "dependencies"
# Expected: PRs for outdated dependencies (if any exist)

# Verify Renovate config is valid
# Visit: https://app.renovatebot.com/dashboard
# Or check GitHub App logs
```

- [ ] Renovate GitHub App installed and configured
- [ ] Shared preset in workflows repository
- [ ] `renovate.json` in each service repository
- [ ] Dependency Dashboard issue created in each repo
- [ ] Security updates auto-merging correctly
- [ ] Minor/patch updates scheduled for Monday mornings

---

## Phase 4: Dependabot

### Step 4.1: Add Dependabot configuration

```bash
# Copy Dependabot config to each service repository
mkdir -p <service-repo>/.github
cp templates/dependabot/dependabot.yml <service-repo>/.github/dependabot.yml

# Customize:
# - Replace {{SERVICE_NAME}} with the service name
# - Replace {{ORG_NAME}} with your GitHub org
# - Adjust ecosystems based on service type (npm, gomod, docker)
```

**Verification:**

```bash
# Check Dependabot status in GitHub
# Navigate to: https://github.com/{{ORG_NAME}}/{{SERVICE_NAME}}/settings/security_analysis
# Verify "Dependabot" section shows enabled ecosystems

# Check for Dependabot PRs
gh pr list --repo {{ORG_NAME}}/{{SERVICE_NAME}} --author "dependabot[bot]"
# Expected: PRs for dependency updates (if any exist)
```

- [ ] `.github/dependabot.yml` in each service repository
- [ ] Dependabot enabled in repository security settings
- [ ] PRs being created for GitHub Actions updates
- [ ] No duplicate PRs with Renovate (check for overlapping ecosystems)

---

## Phase 5: PR Preview Environments

### Step 5.1: Copy reusable workflows

```bash
# Copy PR preview workflows to your workflows repository
cp templates/pr-preview/reusable-pr-preview.yml <workflows-repo>/.github/workflows/reusable-pr-preview.yml
cp templates/pr-preview/reusable-pr-cleanup.yml <workflows-repo>/.github/workflows/reusable-pr-cleanup.yml

# Customize:
# - Replace {{ORG_NAME}} with your GitHub org
# - Replace {{APP_NAME}} with your app name
# - Replace {{REGISTRY_URL}} with your container registry
# - Adjust GCP/cloud-specific settings for your provider
```

### Step 5.2: Configure secrets in GitHub

```bash
# Required secrets (set in GitHub org or repo settings)
# [GCP-SPECIFIC] GCP_STAGING_SA_KEY      -- GCP service account key (base64 JSON)
# [GCP-SPECIFIC] GCP_STAGING_PROJECT_ID  -- GCP project ID for staging
# K8S_KUBECONFIG                         -- Kubernetes kubeconfig (base64 encoded)
# NPM_TOKEN                              -- GitHub Packages token
# SNYK_TOKEN                             -- Snyk API token (for security scans)
```

### Step 5.3: Create caller workflow in each service

```yaml
# Create .github/workflows/pr-preview.yml in each service repo
name: PR Preview
on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  preview:
    uses: {{ORG_NAME}}/{{APP_NAME}}-workflows/.github/workflows/reusable-pr-preview.yml@v1
    with:
      service-name: {{SERVICE_NAME}}
    secrets: inherit

# Create .github/workflows/pr-cleanup.yml
name: PR Cleanup
on:
  pull_request:
    types: [closed]

jobs:
  cleanup:
    uses: {{ORG_NAME}}/{{APP_NAME}}-workflows/.github/workflows/reusable-pr-cleanup.yml@v1
    with:
      service-name: {{SERVICE_NAME}}
    secrets: inherit
```

**Verification:**

```bash
# Open a test PR and verify the preview deploys
gh pr create --title "test: PR preview" --body "Testing preview environment"

# Wait for workflow to complete
gh run list --workflow=pr-preview.yml --limit=1

# Check the PR for the preview deployment comment
gh pr view --comments

# Verify the namespace exists
kubectl get namespace pr-<PR_NUMBER>
# Expected: Namespace exists with preview labels

# Verify the deployment is running
kubectl get pods -n pr-<PR_NUMBER>
# Expected: Pod is Running

# Close the PR and verify cleanup
gh pr close <PR_NUMBER>

# Wait for cleanup workflow
gh run list --workflow=pr-cleanup.yml --limit=1

# Verify namespace was deleted
kubectl get namespace pr-<PR_NUMBER>
# Expected: "not found"
```

- [ ] Reusable PR preview workflow in workflows repository
- [ ] Reusable PR cleanup workflow in workflows repository
- [ ] Required secrets configured in GitHub
- [ ] Caller workflows in each service repository
- [ ] Test PR creates preview namespace and deployment
- [ ] PR comment shows deployment information
- [ ] Closing PR triggers cleanup
- [ ] Namespace is deleted after cleanup

---

## Phase 6: pre-commit.ci

### Step 6.1: Enable pre-commit.ci

```bash
# 1. Visit https://pre-commit.ci/
# 2. Sign in with GitHub
# 3. Install the pre-commit.ci GitHub App
# 4. Grant access to your repositories

# The ci: block in .pre-commit-config.yaml configures the behavior
# (already included in the template from Phase 1)
```

**Verification:**

```bash
# Check for auto-update PRs
gh pr list --repo {{ORG_NAME}}/{{SERVICE_NAME}} --author "pre-commit-ci[bot]"
# Expected: PRs with title "[pre-commit.ci] pre-commit autoupdate"

# Verify autofix on PRs
# Create a PR with a trailing whitespace issue
echo "test   " > test.txt
git add test.txt && git commit -m "test: with trailing whitespace" && git push
# Expected: pre-commit.ci creates a fixup commit removing trailing whitespace
```

- [ ] pre-commit.ci GitHub App installed
- [ ] Weekly autoupdate PRs appearing
- [ ] Autofix commits on PRs with fixable issues

---

## Phase 7: Consumer Templates

### Step 7.1: Set up Go service with all DevEx tooling

```bash
# Copy all consumer templates to a new Go service
cp consumer-templates/go-service/catalog-info.yaml <new-go-service>/catalog-info.yaml
cp consumer-templates/go-service/renovate.json <new-go-service>/renovate.json
cp consumer-templates/go-service/Dockerfile <new-go-service>/Dockerfile
cp templates/pre-commit-config.yaml <new-go-service>/.pre-commit-config.yaml
cp templates/golangci.yml <new-go-service>/.golangci.yml
cp templates/markdownlint.json <new-go-service>/.markdownlint.json

# Replace all placeholders
# {{ORG_NAME}}, {{APP_NAME}}, {{SERVICE_NAME}}, {{TEAM_NAME}}, {{DOMAIN}}, {{REGISTRY_URL}}

# Initialize pre-commit
cd <new-go-service>
pre-commit install
pre-commit install --hook-type commit-msg
```

### Step 7.2: Set up Node.js service with all DevEx tooling

```bash
# Copy all consumer templates to a new Node.js service
cp consumer-templates/node-service/catalog-info.yaml <new-node-service>/catalog-info.yaml
cp consumer-templates/node-service/renovate.json <new-node-service>/renovate.json
cp consumer-templates/node-service/sonar-project.properties <new-node-service>/sonar-project.properties
cp consumer-templates/node-service/Dockerfile <new-node-service>/Dockerfile
cp templates/pre-commit-config.yaml <new-node-service>/.pre-commit-config.yaml
cp templates/markdownlint.json <new-node-service>/.markdownlint.json

# Replace all placeholders
# {{ORG_NAME}}, {{APP_NAME}}, {{SERVICE_NAME}}, {{TEAM_NAME}}, {{DOMAIN}}, {{REGISTRY_URL}}

# Initialize pre-commit
cd <new-node-service>
pre-commit install
pre-commit install --hook-type commit-msg
```

- [ ] Go service consumer templates customized and deployed
- [ ] Node.js service consumer templates customized and deployed
- [ ] All placeholder values replaced
- [ ] pre-commit hooks installed in consumer repos

---

## Final Verification Checklist

### Developer Workflow End-to-End Test

```bash
# 1. Clone a service repository
git clone https://github.com/{{ORG_NAME}}/{{SERVICE_NAME}}.git
cd {{SERVICE_NAME}}

# 2. Install pre-commit hooks
pre-commit install && pre-commit install --hook-type commit-msg

# 3. Make a change and commit
git checkout -b feat/test-devex
echo "// test" >> main.go
git add main.go
git commit -m "feat: test developer experience"
# Expected: All pre-commit hooks run and pass

# 4. Push and create PR
git push -u origin feat/test-devex
gh pr create --title "feat: test developer experience" --body "Testing DevEx pipeline"
# Expected: CI runs, PR preview deploys

# 5. Check Backstage
# Navigate to https://backstage.{{DOMAIN}}/catalog/default/component/{{SERVICE_NAME}}
# Expected: Component visible with all plugin integrations

# 6. Close PR and verify cleanup
gh pr close
# Expected: Preview namespace deleted
```

### Health Check Summary

| Component | Check Command | Expected Result |
|-----------|--------------|-----------------|
| Pre-commit | `pre-commit run --all-files` | All hooks pass |
| Backstage | `curl http://backstage:7007/healthcheck` | `{"status":"ok"}` |
| Renovate | `gh issue list --label renovate` | Dashboard issue exists |
| Dependabot | GitHub Security settings page | Enabled ecosystems shown |
| PR Preview | `kubectl get ns pr-<N>` | Namespace exists during PR |
| PR Cleanup | `kubectl get ns pr-<N>` | "not found" after PR close |
| pre-commit.ci | `gh pr list --author pre-commit-ci[bot]` | Autoupdate PRs exist |

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Pre-Commit Hooks
- Backstage Developer Portal
- Renovate
- Dependabot

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"We scan for vulnerabilities in the pipeline."* |
| ✓ | *"SAST reads source without running it, SCA resolves the dependency tree against an advisory database, and image scanning compares installed package versions to that same database. All three report what was known at build time — which is why the registry is re-scanned: the image does not change, the database does."* |

**Trace it:** A CVE published today against your base image → a blocked deploy. Name every component between the advisory and the refused `apply`.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** the [SLSA threat model](https://slsa.dev/spec/v1.2/threats) — it names every point at which a build can be subverted, and most teams defend three of them.
Full list per domain: [`SOURCES.md`](../../SOURCES.md#devsecops)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../../MASTERY.md)

<!-- /feynman-check -->
