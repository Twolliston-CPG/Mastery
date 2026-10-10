# New Service Onboarding Checklist

End-to-end checklist for adding a new microservice to the platform. Uses consumer templates from all 9 domains.

**Goal**: A new service should be fully onboarded (CI/CD, security, infrastructure, K8s, monitoring, compliance) in under 30 minutes using these templates.

---

## Prerequisites

- [ ] GitHub repository created under `{{ORG_NAME}}/{{REPO_NAME}}`
- [ ] Service code compiles/runs locally
- [ ] Language identified: **Go** or **Node.js**
- [ ] Service name chosen: `{{SERVICE_NAME}}` (e.g., `payment-service`)
- [ ] Service port chosen: `{{SERVICE_PORT}}` (e.g., `3001`)

---

## Phase 1: CI/CD Pipeline (Domain 1)

**Time**: ~5 minutes

Copy consumer templates from `01-cicd-pipelines/consumer-templates/{go,node}-service/`:

- [ ] **`.github/workflows/ci.yml`** — CI pipeline (lint, test, build, security scan)
  ```bash
  mkdir -p .github/workflows
  cp ci.yml .github/workflows/ci.yml
  # Replace placeholders
  sed -i 's/{{SERVICE_NAME}}/payment-service/g' .github/workflows/ci.yml
  sed -i 's/{{ORG_NAME}}/my-org/g' .github/workflows/ci.yml
  ```

- [ ] **`.github/workflows/deploy-staging.yml`** — Staging deployment
- [ ] **`.github/workflows/deploy-production.yml`** — Production deployment

**Verify**: Push a branch, confirm CI workflow triggers and passes.

---

## Phase 2: Security Configuration (Domain 2)

**Time**: ~3 minutes

Copy consumer templates from `02-security-pipeline/consumer-templates/{go,node}-service/`:

### Go Services
- [ ] **`.gosec.conf`** — Gosec configuration
- [ ] **`.trivyignore`** — Trivy CVE suppressions (start empty)

### Node.js Services
- [ ] **`sonar-project.properties`** — SonarQube configuration
- [ ] **`.snyk`** — Snyk policy file
- [ ] **`.trivyignore`** — Trivy CVE suppressions (start empty)

**Verify**: Security scan job in CI passes.

---

## Phase 3: Infrastructure (Domain 3)

**Time**: ~5 minutes

Copy consumer templates from `03-infrastructure-as-code/consumer-templates/`:

- [ ] **`infrastructure/main.tf`** — Service-specific Terraform (GCS buckets, Pub/Sub topics, etc.)
- [ ] **`infrastructure/variables.tf`** — Terraform variables
- [ ] **`infrastructure/staging.tfvars`** — Staging values
- [ ] **`infrastructure/production.tfvars`** — Production values

**Verify**: `terraform plan` shows expected resources.

---

## Phase 4: Kubernetes Manifests (Domain 4)

**Time**: ~5 minutes

Copy consumer templates from `04-kubernetes-platform/consumer-templates/`:

- [ ] **`k8s/base/deployment.yaml`** — Deployment with security context, probes, resource limits
- [ ] **`k8s/base/service.yaml`** — ClusterIP Service
- [ ] **`k8s/base/hpa.yaml`** — HorizontalPodAutoscaler (CPU 70% / memory 80%)
- [ ] **`k8s/base/pdb.yaml`** — PodDisruptionBudget (minAvailable: 1)
- [ ] **`k8s/base/serviceaccount.yaml`** — ServiceAccount
- [ ] **`k8s/base/kustomization.yaml`** — Kustomize base

Replace all `{{SERVICE_NAME}}`, `{{SERVICE_PORT}}`, `{{REGISTRY_URL}}` placeholders.

**Verify**: `kubectl apply --dry-run=client -f k8s/base/` succeeds.

---

## Phase 5: Runtime Security (Domain 5)

**Time**: ~3 minutes

Copy consumer templates from `05-runtime-security/consumer-templates/`:

- [ ] **`k8s/security/kubearmor-policy.yaml`** — KubeArmor runtime policy
- [ ] **`k8s/security/network-policy.yaml`** — Cilium NetworkPolicy

**Verify**: `kubectl apply --dry-run=client` on security manifests succeeds.

---

## Phase 6: Compliance (Domain 6)

**Time**: ~3 minutes

Copy consumer template from `06-compliance-as-code/consumer-templates/`:

- [ ] **`compliance/component-definition.yaml`** — OSCAL component-definition with NIST 800-53 mapping

**Verify**: `trestle validate -f compliance/component-definition.yaml` passes (if trestle is installed).

---

## Phase 7: Observability (Domain 7)

**Time**: ~5 minutes

Copy consumer templates from `07-observability/consumer-templates/`:

- [ ] **`k8s/monitoring/service-monitor.yaml`** — Prometheus ServiceMonitor
- [ ] **`k8s/monitoring/prometheus-rules.yaml`** — Alert rules (error rate, latency, availability)
- [ ] **`k8s/monitoring/grafana-dashboard.json`** — Grafana dashboard

**Verify**: After deployment, confirm the service appears in Prometheus targets and Grafana dashboards.

---

## Phase 8: Developer Experience (Domain 8)

**Time**: ~3 minutes

Copy consumer templates from `08-developer-experience/consumer-templates/{go,node}-service/`:

- [ ] **`catalog-info.yaml`** — Backstage service catalog entry
- [ ] **`renovate.json`** — Renovate dependency management config
- [ ] **`Dockerfile`** — Production container image

### Go Services
```bash
# Verify Dockerfile builds
docker build -t {{SERVICE_NAME}}:test .
```

### Node.js Services
- [ ] **`sonar-project.properties`** — SonarQube config (if not already from Phase 2)

**Verify**:
- Docker image builds successfully
- `catalog-info.yaml` is valid YAML
- Backstage discovers the service after push to main

---

## Phase 9: Resilience (Domain 9)

**Time**: ~2 minutes

Copy consumer template from `09-resilience-dr/consumer-templates/`:

- [ ] **`chaos/chaos-experiment.yaml`** — Litmus chaos experiment template

**Verify**: Experiment YAML is valid.

---

## Post-Onboarding Verification

After all phases are complete:

- [ ] **CI/CD**: Push to a branch → CI pipeline runs successfully
- [ ] **Security**: All security scan jobs pass (SAST, SCA, secrets, container)
- [ ] **GitOps**: Merge to main → ArgoCD detects new manifests → staging deploys
- [ ] **Monitoring**: Service appears in Prometheus targets → Grafana dashboard shows metrics
- [ ] **Backstage**: Service is visible in the developer portal catalog
- [ ] **Network**: Service communicates with allowed dependencies (NetworkPolicy verified)
- [ ] **Runtime**: KubeArmor policy is enforced (check KubeArmor logs)

---

## Placeholder Substitution Command

Run this to replace all placeholders across all copied templates:

```bash
# Define values
export ORG_NAME="my-org"
export APP_NAME="myapp"
export APP_NAMESPACE="myapp"
export SERVICE_NAME="payment-service"
export SERVICE_PORT="3001"
export REPO_NAME="myapp-payment-service"
export REGISTRY_URL="us-east1-docker.pkg.dev/my-project/myapp"
export GCP_PROJECT_ID="my-project"
export GCP_REGION="us-east1"
export DOMAIN="myapp.com"
export TEAM_NAME="platform-team"
export COVERAGE_THRESHOLD="80"

# Replace in all files
find . -type f \( -name "*.yml" -o -name "*.yaml" -o -name "*.tf" -o -name "*.json" -o -name "*.properties" -o -name "*.md" -o -name "Dockerfile" \) | while read file; do
  sed -i "s/{{ORG_NAME}}/$ORG_NAME/g" "$file"
  sed -i "s/{{APP_NAME}}/$APP_NAME/g" "$file"
  sed -i "s/{{APP_NAMESPACE}}/$APP_NAMESPACE/g" "$file"
  sed -i "s/{{SERVICE_NAME}}/$SERVICE_NAME/g" "$file"
  sed -i "s/{{SERVICE_PORT}}/$SERVICE_PORT/g" "$file"
  sed -i "s/{{REPO_NAME}}/$REPO_NAME/g" "$file"
  sed -i "s|{{REGISTRY_URL}}|$REGISTRY_URL|g" "$file"
  sed -i "s/{{GCP_PROJECT_ID}}/$GCP_PROJECT_ID/g" "$file"
  sed -i "s/{{GCP_REGION}}/$GCP_REGION/g" "$file"
  sed -i "s/{{DOMAIN}}/$DOMAIN/g" "$file"
  sed -i "s/{{TEAM_NAME}}/$TEAM_NAME/g" "$file"
  sed -i "s/{{COVERAGE_THRESHOLD}}/$COVERAGE_THRESHOLD/g" "$file"
done
```

---

## Time Summary

| Phase | Domain | Time |
|-------|--------|------|
| 1 | CI/CD | ~5 min |
| 2 | Security | ~3 min |
| 3 | Infrastructure | ~5 min |
| 4 | Kubernetes | ~5 min |
| 5 | Runtime Security | ~3 min |
| 6 | Compliance | ~3 min |
| 7 | Observability | ~5 min |
| 8 | Developer Experience | ~3 min |
| 9 | Resilience | ~2 min |
| **Total** | **All domains** | **~34 min** |

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- CI/CD Pipeline (Domain 1)
- Security Configuration (Domain 2)
- Infrastructure (Domain 3)
- Kubernetes Manifests (Domain 4)

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
