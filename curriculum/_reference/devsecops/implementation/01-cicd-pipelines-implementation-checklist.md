# CI/CD Pipelines — Implementation Checklist

## Prerequisites

- [ ] GitHub organization created (`{{ORG_NAME}}`)
- [ ] Workflows repository created (`{{APP_NAME}}-workflows`)
- [ ] Container registry available (`{{REGISTRY_URL}}`) **[GCP-SPECIFIC]** Artifact Registry; AWS: ECR; Azure: ACR
- [ ] ArgoCD installed on the target cluster (see Domain 04)
- [ ] Required secrets configured in GitHub org settings (see [Required Secrets](#step-5-configure-secrets))

## Step 1: Create the Workflows Repository

```bash
gh repo create {{ORG_NAME}}/{{APP_NAME}}-workflows --private
cd {{APP_NAME}}-workflows
mkdir -p .github/workflows templates
```

**Verification**: `gh repo view {{ORG_NAME}}/{{APP_NAME}}-workflows` returns the repo metadata.

## Step 2: Deploy Standalone Workflows

Copy each standalone workflow template from `01-cicd-pipelines/templates/standalone/` into `.github/workflows/`:

```bash
cp templates/standalone/*.yml .github/workflows/
```

Replace all placeholders:
```bash
find .github/workflows/ -type f -name '*.yml' -exec sed -i '' \
  -e 's/{{ORG_NAME}}/your-org/g' \
  -e 's/{{APP_NAME}}/your-app/g' \
  -e 's/{{REGISTRY_URL}}/your-registry-url/g' \
  {} +
```

**Verification**: `actionlint .github/workflows/*.yml` passes with no errors (after placeholder substitution).

## Step 3: Deploy Composite Workflows

Copy composite workflows:
```bash
cp templates/composite/*.yml .github/workflows/
```

Replace placeholders (same as Step 2).

**Verification**: Composite workflows reference standalone workflows that exist in the same directory.

## Step 4: Create Version Tags

```bash
git add .github/workflows/
git commit -m "feat: add reusable CI/CD workflows"
git tag v1
git push origin main --tags
```

**Verification**: `gh release list` shows `v1` tag.

## Step 5: Configure Secrets

Set these secrets at the organization level:

```bash
# Core
gh secret set NPM_TOKEN --org {{ORG_NAME}} --body "your-npm-token"
gh secret set CODECOV_TOKEN --org {{ORG_NAME}} --body "your-codecov-token"

# Security (Node.js)
gh secret set SNYK_TOKEN --org {{ORG_NAME}} --body "your-snyk-token"
gh secret set SONAR_TOKEN --org {{ORG_NAME}} --body "your-sonar-token"
gh secret set SONAR_HOST_URL --org {{ORG_NAME}} --body "https://sonar.example.com"

# Enterprise (DefectDojo)
gh secret set DEFECTDOJO_URL --org {{ORG_NAME}} --body "{{DEFECTDOJO_URL}}"
gh secret set DEFECTDOJO_TOKEN --org {{ORG_NAME}} --body "your-defectdojo-token"
```

**[GCP-SPECIFIC]** For deployment, configure Workload Identity Federation instead of service account keys (see [cross-cutting/oidc-workload-identity.md](../cross-cutting/oidc-workload-identity.md)):
```bash
# No stored keys — WIF is configured via Terraform module (Domain 03)
```

**Verification**: `gh secret list --org {{ORG_NAME}}` shows all expected secrets.

## Step 6: Integrate a Go Service

In your Go service repository:

1. Copy consumer templates:
```bash
mkdir -p .github/workflows
cp consumer-templates/go-service/ci.yml .github/workflows/
cp consumer-templates/go-service/deploy-staging.yml .github/workflows/
cp consumer-templates/go-service/deploy-production.yml .github/workflows/
```

2. Replace placeholders:
```bash
find .github/workflows/ -type f -name '*.yml' -exec sed -i '' \
  -e 's/{{ORG_NAME}}/your-org/g' \
  -e 's/{{APP_NAME}}/your-app/g' \
  -e 's/{{SERVICE_NAME}}/your-service/g' \
  -e 's/{{GO_VERSION}}/1.22/g' \
  -e 's/{{COVERAGE_THRESHOLD}}/60/g' \
  {} +
```

3. Push and verify:
```bash
git add .github/workflows/
git commit -m "ci: add CI/CD workflows"
git push origin main
```

**Verification**: Check GitHub Actions tab — CI workflow should trigger and run lint, test, build, and security-scan jobs.

## Step 7: Integrate a Node.js Service

Same as Step 6, using `consumer-templates/node-service/` instead.

**Additional steps**:
- Ensure `sonar-project.properties` exists (see Domain 08 consumer templates)
- Ensure `NPM_TOKEN` secret is available for private package access

**Verification**: CI workflow triggers with lint, test, build, security-scan, and sonarqube jobs.

## Step 8: Configure ArgoCD Image Updater

For each service, add annotations to its ArgoCD Application manifest:

```yaml
metadata:
  annotations:
    argocd-image-updater.argoproj.io/image-list: >-
      {{SERVICE_NAME}}={{REGISTRY_URL}}/{{SERVICE_NAME}}
    argocd-image-updater.argoproj.io/{{SERVICE_NAME}}.update-strategy: semver
    argocd-image-updater.argoproj.io/write-back-method: git
```

**Verification**: After pushing a new tagged image, check ArgoCD Image Updater logs:
```bash
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-image-updater
```
You should see a commit to the manifests repo updating the image tag.

## Step 9: Validate Templates

After all placeholders are replaced, validate the workflow files:

```bash
# Install actionlint
brew install actionlint  # macOS
# or: go install github.com/rhysd/actionlint/cmd/actionlint@latest

# Validate all workflows
actionlint .github/workflows/*.yml

# Validate YAML syntax
yamllint .github/workflows/
```

**Verification**: Both commands exit with code 0.

## Step 10: Test End-to-End

1. Create a feature branch in a service repo
2. Make a small change and open a PR
3. Verify CI workflow runs (lint, test, build, security-scan)
4. Merge the PR to main
5. Verify staging deployment happens automatically (ArgoCD sync)
6. Trigger a production deployment manually
7. Verify canary deployment with 10% traffic

**Verification**: All jobs green in GitHub Actions, ArgoCD shows Synced status, smoke tests pass.

## Troubleshooting

| Issue | Cause | Fix |
|-------|-------|-----|
| `workflow not found` | Workflow file not in `.github/workflows/` | Ensure file is in the correct path in the workflows repo |
| `permission denied` on reusable workflow | Workflow repo is private, caller is external | Set workflow repo visibility or use org-level sharing |
| Cache miss on every run | Cache key changed (e.g., new dependency) | Expected on first run after dependency change |
| Cosign signing fails | Missing OIDC permissions | Add `permissions: id-token: write` to the workflow |
| ArgoCD doesn't detect new image | Image Updater not running or misconfigured | Check Image Updater logs and annotation spelling |

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Create the Workflows Repository
- Deploy Standalone Workflows
- Deploy Composite Workflows
- Create Version Tags

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
