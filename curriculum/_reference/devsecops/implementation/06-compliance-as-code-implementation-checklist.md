# Compliance as Code -- Implementation Checklist

## Prerequisites

- [ ] Python 3.11+ installed
- [ ] `pip install compliance-trestle requests pyyaml jinja2`
- [ ] Kubernetes cluster with `kubectl` access
- [ ] GitHub Actions configured with required secrets
- [ ] Kustomize installed (`kubectl kustomize` or standalone)

**Verify prerequisites:**
```bash
python3 --version           # >= 3.11
trestle version             # compliance-trestle installed
kubectl version --client    # kubectl available
kustomize version           # kustomize available
```

---

## Phase 1: OSCAL Repository Setup

### Step 1.1: Initialize Trestle Workspace

- [ ] Create the compliance repository structure

```bash
mkdir -p compliance-repo && cd compliance-repo
trestle init

# Verify Trestle workspace
ls .trestle/
# Expected: config.ini
```

### Step 1.2: Create Directory Structure

- [ ] Create all OSCAL directories

```bash
mkdir -p catalogs
mkdir -p profiles/{{APP_NAME}}-soc2
mkdir -p profiles/{{APP_NAME}}-production
mkdir -p component-definitions/kubernetes-policies
mkdir -p component-definitions/cicd-security
mkdir -p component-definitions/infrastructure-security
mkdir -p system-security-plans/{{APP_NAME}}-ssp
mkdir -p assessment-results/latest
mkdir -p assessment-results/evidence
mkdir -p assessment-plans
mkdir -p scripts
mkdir -p docs/ssp-markdown
mkdir -p docs/control-matrix
```

**Verify:**
```bash
find . -type d | sort
# Should list all directories above
```

### Step 1.3: Create SOC2 Profile

- [ ] Add the SOC2 profile selecting 28 NIST 800-53 controls

```bash
# Copy template from templates/oscal/profiles/profile.json
# Customize the control selection for your organization
cp templates/oscal/profiles/profile.json profiles/{{APP_NAME}}-soc2/profile.json

# Validate
trestle validate -f profiles/{{APP_NAME}}-soc2/profile.json
```

### Step 1.4: Create Production Profile

- [ ] Add the production profile extending SOC2

```bash
cp templates/oscal/profiles/profile.json profiles/{{APP_NAME}}-production/profile.json
# Edit to import the SOC2 profile and add production-specific modifications

trestle validate -f profiles/{{APP_NAME}}-production/profile.json
```

### Step 1.5: Create Component Definitions

- [ ] Add Kubernetes policies component definition
- [ ] Add CI/CD security component definition
- [ ] Add Infrastructure security component definition

```bash
# For each component definition:
cp templates/oscal/component-definitions/component-definition.json \
   component-definitions/kubernetes-policies/component-definition.json
# Edit to add your specific controls

# Validate all component definitions
for dir in component-definitions/*/; do
  echo "Validating $(basename $dir)..."
  trestle validate -f "${dir}component-definition.json"
done
```

### Step 1.6: Create System Security Plan

- [ ] Add the SSP document

```bash
cp templates/oscal/system-security-plans/system-security-plan.json \
   system-security-plans/{{APP_NAME}}-ssp/system-security-plan.json
# Customize system characteristics, users, components, and control implementations

trestle validate -f system-security-plans/{{APP_NAME}}-ssp/system-security-plan.json
```

### Step 1.7: Validate All OSCAL Documents

- [ ] Run full validation

```bash
trestle validate -a
# Expected: All documents pass validation with no errors
```

---

## Phase 2: Compliance Scripts

### Step 2.1: Install Script Dependencies

- [ ] Install Python packages

```bash
pip install compliance-trestle requests pyyaml jinja2
```

### Step 2.2: Deploy Scripts

- [ ] Copy all 8 scripts to the `scripts/` directory

```bash
cp templates/sync-scripts/*.py scripts/
chmod +x scripts/*.py

# Verify scripts are present
ls -la scripts/
# Expected: 8 Python files
```

### Step 2.3: Test Evidence Collection (GitHub)

- [ ] Verify GitHub evidence collection

```bash
export GITHUB_TOKEN="your-github-token"

python scripts/collect-github-evidence.py \
  --org {{ORG_NAME}} \
  --output assessment-results/evidence/

# Verify output
ls assessment-results/evidence/
# Expected: github-alerts.json, vulnerability-summary.json
```

### Step 2.4: Test Control Matrix Generation

- [ ] Verify control matrix generation

```bash
python scripts/generate-control-matrix.py \
  --components component-definitions/ \
  --output docs/control-matrix/control-matrix.md

# Verify output
cat docs/control-matrix/control-matrix.md | head -20
# Expected: Markdown table with NIST, SOC2, ISO controls
```

### Step 2.5: Test SSP Markdown Generation

- [ ] Verify SSP documentation generation

```bash
python scripts/generate-ssp-markdown.py \
  --input system-security-plans/{{APP_NAME}}-ssp/system-security-plan.json \
  --output docs/ssp-markdown/

# Verify output
ls docs/ssp-markdown/
# Expected: ssp-overview.md, control-implementations.md
```

---

## Phase 3: DefectDojo Deployment

### Step 3.1: Deploy DefectDojo

- [ ] Apply DefectDojo manifests

```bash
# Review and customize secrets FIRST (do NOT use defaults in production)
# Edit templates/defectdojo/secret.yaml with secure credentials

kubectl apply -k templates/defectdojo/

# Verify namespace created
kubectl get namespace defectdojo
```

### Step 3.2: Wait for DefectDojo Startup

- [ ] Verify all pods are running

```bash
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=defectdojo \
  -n defectdojo --timeout=300s

kubectl get pods -n defectdojo
# Expected: defectdojo-django, defectdojo-celery-beat, defectdojo-celery-worker,
#           defectdojo-redis, defectdojo-db all in Running/Ready state
```

### Step 3.3: Verify DefectDojo Access

- [ ] Access DefectDojo UI

```bash
# Get NodePort URL
kubectl get svc defectdojo -n defectdojo
# Access at http://<node-ip>:30080

# Test API
curl -s http://localhost:30080/api/v2/users/ \
  -H "Authorization: Token <your-token>" | python -m json.tool
# Expected: Valid JSON response with user list
```

### Step 3.4: Test DefectDojo Integration

- [ ] Verify DefectDojo evidence collection

```bash
export DEFECTDOJO_TOKEN="your-defectdojo-api-token"

python scripts/collect-defectdojo-evidence.py \
  --url "http://localhost:30080" \
  --output assessment-results/evidence/

# Verify output
cat assessment-results/evidence/defectdojo-summary.json
# Expected: JSON with severity counts
```

---

## Phase 4: Dependency-Track Deployment

### Step 4.1: Deploy Dependency-Track

- [ ] Apply Dependency-Track manifests

```bash
kubectl apply -k templates/dependency-track/

# Wait for Helm release to reconcile (if using Flux)
# Or apply the YAML manifests directly

kubectl get namespace dependency-track
```

### Step 4.2: Verify Dependency-Track

- [ ] Check pods are running

```bash
kubectl get pods -n dependency-track
# Expected: apiserver, frontend, and postgresql pods running

# Verify external access
kubectl get svc dependency-track-external -n dependency-track
# Access at http://<node-ip>:30082
```

### Step 4.3: Configure SBOM Upload

- [ ] Verify SBOM upload works

```bash
# Get API key from Dependency-Track UI (Administration > Access Management > Teams)
# Or from the external secret

# Upload a test SBOM
curl -X POST "http://localhost:30082/api/v1/bom" \
  -H "X-API-Key: <your-api-key>" \
  -H "Content-Type: multipart/form-data" \
  -F "project=test-project" \
  -F "bom=@path/to/sbom.json"
# Expected: 200 OK
```

---

## Phase 5: CISO Assistant Deployment

### Step 5.1: Deploy CISO Assistant

- [ ] Apply CISO Assistant manifests

```bash
# Review and customize secrets FIRST
kubectl apply -k templates/ciso-assistant/

kubectl get namespace ciso-assistant
```

### Step 5.2: Verify CISO Assistant

- [ ] Check pods are running

```bash
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=ciso-assistant \
  -n ciso-assistant --timeout=300s

kubectl get pods -n ciso-assistant
# Expected: backend, frontend, database all Running

# Verify external access
kubectl get svc ciso-assistant -n ciso-assistant
# Access at http://<node-ip>:30081
```

### Step 5.3: Test CISO Assistant Sync

- [ ] Verify OSCAL-to-CISO-Assistant sync

```bash
export CISO_ASSISTANT_TOKEN="your-ciso-assistant-token"

python scripts/sync-to-ciso-assistant.py \
  --url "http://localhost:30081" \
  --components component-definitions/ \
  --assessment assessment-results/latest/assessment-results.json \
  --project "{{APP_NAME}} Platform"

# Expected: Control implementations imported, evidence attached
```

---

## Phase 6: GitHub Actions Workflows

### Step 6.1: Configure GitHub Secrets

- [ ] Add required secrets to the repository

```
Repository Settings > Secrets and variables > Actions

Secrets:
  DEFECTDOJO_TOKEN    = <DefectDojo API token>
  CISO_ASSISTANT_TOKEN = <CISO Assistant API token>

Variables:
  DEFECTDOJO_URL      = http://defectdojo.{{APP_NAME}}.internal:30080
  CISO_ASSISTANT_URL  = http://ciso-assistant.{{APP_NAME}}.internal:30081
```

### Step 6.2: Deploy Workflows

- [ ] Copy workflows to `.github/workflows/`

```bash
mkdir -p .github/workflows
cp templates/assessment-workflows/*.yml .github/workflows/

ls .github/workflows/
# Expected: trestle-validate.yml, trestle-assemble.yml,
#           trestle-assess.yml, trestle-sync-tools.yml
```

### Step 6.3: Test Validation Workflow

- [ ] Create a PR and verify validation runs

```bash
git checkout -b test/validate-oscal
# Make a minor change to a component definition
git add . && git commit -m "test: Trigger OSCAL validation"
git push origin test/validate-oscal
# Create PR and verify the "Validate OSCAL" check passes
```

### Step 6.4: Test Assessment Workflow

- [ ] Trigger manual assessment

```bash
# Via GitHub Actions UI: Actions > Automated Compliance Assessment > Run workflow
# Or via gh CLI:
gh workflow run trestle-assess.yml

# Verify results
gh run list --workflow=trestle-assess.yml --limit=1
# Expected: Successful run with assessment results committed
```

---

## Phase 7: GDPR Data Lifecycle

### Step 7.1: Deploy Data Archival Workflow

- [ ] Copy the data lifecycle workflow

```bash
cp templates/data-lifecycle/location-archival-cron.yml .github/workflows/

# Configure required secrets:
# GCP_SA_KEY (or Workload Identity)  [GCP-SPECIFIC]
# K8S_KUBECONFIG
# GCP_PROJECT_ID                     [GCP-SPECIFIC]
# SLACK_WEBHOOK_URL (for failure notifications)
```

### Step 7.2: Test Data Archival (Dry Run)

- [ ] Verify archival works with dry-run

```bash
# Via GitHub Actions UI:
# Actions > Location Data Archival > Run workflow
#   environment: staging
#   retention-days: 30
#   dry-run: true

# Verify the job summary shows the archival report
```

---

## Phase 8: Verification

### Step 8.1: End-to-End Compliance Validation

- [ ] Validate the complete compliance setup

```bash
# 1. Validate all OSCAL documents
trestle validate -a

# 2. Generate control matrix
python scripts/generate-control-matrix.py \
  --components component-definitions/ \
  --output docs/control-matrix/control-matrix.md

# 3. Generate SSP documentation
python scripts/generate-ssp-markdown.py \
  --input system-security-plans/{{APP_NAME}}-ssp/system-security-plan.json \
  --output docs/ssp-markdown/

# 4. Verify all compliance tools are accessible
kubectl get svc -n defectdojo         # Port 30080
kubectl get svc -n dependency-track   # Port 30082
kubectl get svc -n ciso-assistant     # Port 30081

# 5. Run a manual assessment
python scripts/generate-assessment-results.py \
  --ssp system-security-plans/{{APP_NAME}}-ssp/system-security-plan.json \
  --evidence assessment-results/evidence/ \
  --output assessment-results/latest/assessment-results.json \
  --timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# 6. Generate summary
python scripts/generate-assessment-summary.py \
  --results assessment-results/latest/assessment-results.json \
  --output assessment-results/latest/summary.md

cat assessment-results/latest/summary.md
# Expected: Compliance score, findings detail, recommendations
```

### Step 8.2: Verify Framework Coverage

- [ ] Confirm control coverage

```bash
# Count unique NIST controls across all component definitions
python -c "
import json, glob
controls = set()
for f in glob.glob('component-definitions/*/component-definition.json'):
    data = json.load(open(f))
    for comp in data['component-definition']['components']:
        for impl in comp.get('control-implementations', []):
            if 'nist' in impl.get('source', '').lower() or not impl.get('source', '').startswith(('soc2', 'iso')):
                for req in impl.get('implemented-requirements', []):
                    cid = req.get('control-id', '')
                    if not cid.startswith(('CC', 'A.')):
                        controls.add(cid)
print(f'NIST 800-53 controls: {len(controls)}')
for c in sorted(controls):
    print(f'  {c.upper()}')
"
# Expected: 28 NIST 800-53 controls
```

### Step 8.3: Verify Network Policies

- [ ] Confirm network policies are applied

```bash
kubectl get networkpolicy -n defectdojo
# Expected: defectdojo-network-policy

kubectl get networkpolicy -n ciso-assistant
# Expected: ciso-assistant-network-policy

kubectl get networkpolicy -n dependency-track
# Expected: dependency-track-network-policy
```

---

## Post-Implementation

- [ ] Change all default admin passwords for DefectDojo and CISO Assistant
- [ ] Move secrets from plain YAML to a secret manager (External Secrets)
- [ ] Configure Dependency-Track API key in DefectDojo for SBOM import
- [ ] Add auditor read-only accounts to CISO Assistant
- [ ] Schedule quarterly manual review of control implementations
- [ ] Document the compliance architecture in the organization wiki

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- OSCAL Repository Setup
- Compliance Scripts
- DefectDojo Deployment
- Dependency-Track Deployment

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
