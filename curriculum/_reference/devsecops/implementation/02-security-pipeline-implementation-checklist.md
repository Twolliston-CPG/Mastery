# Security Pipeline — Implementation Checklist

## Prerequisites

- [ ] CI/CD Pipelines (Domain 1) are operational
- [ ] Workflows repository (`{{APP_NAME}}-workflows`) exists with CI workflows deployed
- [ ] Container registry available for image scanning
- [ ] GitHub Advanced Security enabled (for CodeQL and SARIF uploads)

## Step 1: Deploy Security Scanning Workflows

Copy standalone security workflow templates into the workflows repository:

```bash
cd {{APP_NAME}}-workflows
cp templates/standalone/reusable-go-security.yml .github/workflows/
cp templates/standalone/reusable-node-security.yml .github/workflows/
cp templates/standalone/reusable-terraform-security.yml .github/workflows/
cp templates/standalone/reusable-dast-scan.yml .github/workflows/
cp templates/standalone/reusable-sonarqube.yml .github/workflows/
cp templates/standalone/reusable-defectdojo-import.yml .github/workflows/
cp templates/standalone/reusable-dependency-track.yml .github/workflows/
cp templates/standalone/reusable-vulnerability-sla.yml .github/workflows/
```

Replace placeholders:
```bash
find .github/workflows/ -type f -name 'reusable-*security*' -o -name 'reusable-dast*' -o -name 'reusable-defect*' -o -name 'reusable-dependency*' -o -name 'reusable-sonar*' -o -name 'reusable-vulnerability*' | xargs sed -i '' \
  -e 's/{{ORG_NAME}}/your-org/g' \
  -e 's/{{APP_NAME}}/your-app/g' \
  -e 's/{{APP_NAMESPACE}}/your-namespace/g' \
  -e 's/{{REGISTRY_URL}}/your-registry-url/g'
```

**Verification**: `actionlint .github/workflows/reusable-*security*.yml` passes with no errors.

## Step 2: Deploy Composite Security Workflow

```bash
cp templates/composite/reusable-security-with-defectdojo.yml .github/workflows/
```

Replace placeholders (same as Step 1).

**Verification**: The composite workflow references standalone workflows that exist in the same repo.

## Step 3: Configure Security Secrets

Set organization-level secrets:

```bash
# Snyk (Node.js security scanning)
gh secret set SNYK_TOKEN --org {{ORG_NAME}} --body "your-snyk-token"

# SonarQube (code quality)
gh secret set SONAR_TOKEN --org {{ORG_NAME}} --body "your-sonar-token"
gh secret set SONAR_HOST_URL --org {{ORG_NAME}} --body "https://sonar.example.com"

# DefectDojo (vulnerability aggregation)
gh secret set DEFECTDOJO_URL --org {{ORG_NAME}} --body "http://<node-ip>:30080"
gh secret set DEFECTDOJO_TOKEN --org {{ORG_NAME}} --body "your-defectdojo-token"

# Dependency-Track (SBOM analysis)
gh secret set DEPENDENCY_TRACK_URL --org {{ORG_NAME}} --body "http://<node-ip>:30082"
gh secret set DEPENDENCY_TRACK_API_KEY --org {{ORG_NAME}} --body "your-dtrack-api-key"
```

**Verification**: `gh secret list --org {{ORG_NAME}}` shows all security secrets.

## Step 4: Deploy DefectDojo

Deploy DefectDojo to the Kubernetes cluster:

```bash
# Apply DefectDojo manifests (from Domain 6 compliance-stack templates)
kubectl apply -k compliance-stack/defectdojo/

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app=defectdojo -n defectdojo --timeout=300s

# Get admin credentials
kubectl get secret defectdojo-admin -n defectdojo -o jsonpath='{.data.password}' | base64 -d
```

**Verification**: `curl -s http://<node-ip>:30080/api/v2/test_types/ -H "Authorization: Token <token>" | jq '.count'` returns a number.

## Step 5: Deploy Dependency-Track

```bash
# Apply Dependency-Track manifests
kubectl apply -k security/dependency-track/

# Wait for pods
kubectl wait --for=condition=ready pod -l app=dependency-track -n dependency-track --timeout=300s
```

**Verification**: `curl -s http://<node-ip>:30082/api/version` returns Dependency-Track version info.

## Step 6: Integrate a Go Service

In your Go service repository, the CI workflow should already call the security workflow. Verify:

```yaml
# .github/workflows/ci.yml should include:
security:
  uses: {{ORG_NAME}}/{{APP_NAME}}-workflows/.github/workflows/reusable-go-security.yml@main
  with:
    enable-codeql: true
    enable-secret-scanning: true
    fail-on-severity: high
```

**Verification**: Open a PR in the Go service repo. Check that the security job runs and produces:
- Gosec SARIF results in GitHub Security tab
- Trivy SARIF results in GitHub Security tab
- govulncheck output in the workflow log

## Step 7: Integrate a Node.js Service

In your Node.js service repository:

1. Ensure `sonar-project.properties` exists:
```bash
cp consumer-templates/node-service/sonar-project.properties .
sed -i '' \
  -e 's/{{ORG_NAME}}/your-org/g' \
  -e 's/{{SERVICE_NAME}}/your-service/g' \
  sonar-project.properties
```

2. Verify CI workflow calls security:
```yaml
# .github/workflows/ci.yml should include:
security:
  uses: {{ORG_NAME}}/{{APP_NAME}}-workflows/.github/workflows/reusable-security.yml@v1
  with:
    enable-snyk: true
    enable-secret-scanning: true
    fail-on-severity: high
  secrets: inherit
```

**Verification**: Open a PR in the Node.js service repo. Check GitHub Security tab for Snyk and Trivy findings.

## Step 8: Configure Threat Modeling

1. Copy the Threagile model template:
```bash
mkdir -p docs/security
cp templates/threat-modeling/threagile-model.yaml docs/security/
cp templates/threat-modeling/threagile-analysis.yml .github/workflows/
```

2. Customize the threat model for your system architecture.

3. Run Threagile locally to verify:
```bash
docker run --rm -v $(pwd):/app threagile/threagile analyze -model /app/docs/security/threagile-model.yaml
```

**Verification**: Threagile produces a risk report without errors.

## Step 9: Validate Templates

After all placeholders are replaced:

```bash
# Validate workflow syntax
actionlint .github/workflows/reusable-*security*.yml
actionlint .github/workflows/reusable-dast*.yml
actionlint .github/workflows/reusable-defect*.yml
actionlint .github/workflows/reusable-sonar*.yml

# Validate YAML syntax
yamllint .github/workflows/
```

**Verification**: All commands exit with code 0.

## Step 10: Test End-to-End Security Pipeline

1. Create a feature branch in a service repo
2. Introduce a known vulnerability (e.g., outdated dependency with known CVE)
3. Open a PR and verify:
   - [ ] SAST findings appear in GitHub Security tab
   - [ ] SCA findings appear in GitHub Security tab
   - [ ] Secret detection runs clean (no false positives)
   - [ ] Container scan results uploaded
   - [ ] License check passes
4. Merge to main and verify:
   - [ ] DefectDojo receives scan results
   - [ ] Dependency-Track receives SBOM
   - [ ] DAST scan runs against staging
5. Check vulnerability SLA:
   - [ ] `reusable-vulnerability-sla.yml` reports SLA status

**Verification**: All scan results visible in GitHub Security tab, DefectDojo, and Dependency-Track.

## Troubleshooting

| Issue | Cause | Fix |
|-------|-------|-----|
| `SARIF upload failed` | Missing `security-events: write` permission | Add permission to workflow |
| `Snyk auth failed` | Invalid or expired SNYK_TOKEN | Regenerate token at snyk.io |
| `DefectDojo import failed` | Network/auth error | Check DEFECTDOJO_URL is reachable from runner, verify token |
| `govulncheck: no Go files` | Wrong working-directory | Ensure working-directory points to Go module root |
| `ZAP scan timeout` | Service not responding | Check port-forward is working, verify K8S_KUBECONFIG |
| `SonarQube quality gate failed` | Below thresholds | Review sonar-project.properties, adjust quality gate |
| `Dependency-Track upload failed` | Project not found | Workflow auto-creates projects; check API key permissions |
| `Threagile analysis error` | Invalid model YAML | Run `threagile validate` locally first |

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Deploy Security Scanning Workflows
- Deploy Composite Security Workflow
- Configure Security Secrets
- Deploy DefectDojo

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
