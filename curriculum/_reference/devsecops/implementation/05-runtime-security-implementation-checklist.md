# Domain 5: Runtime Security & Network Security -- Implementation Checklist

## Prerequisites

- [ ] Kubernetes cluster 1.28+ with containerd runtime
- [ ] Helm 3.x installed
- [ ] kubectl configured with cluster admin access
- [ ] Flux CD or ArgoCD installed for GitOps delivery
- [ ] Prometheus + Alertmanager deployed (monitoring namespace)
- [ ] Elasticsearch/OpenSearch deployed (logging namespace)
- [ ] Istio service mesh installed (istio-system namespace)

---

## Phase 1: Namespace Setup & Pod Security Standards

### 1.1 Create Namespaces with PSS Labels

- [ ] Apply namespace policies from `templates/network-security/pod-security-standards/`
- [ ] Verify PSS enforcement on application namespaces

```bash
# Verify PSS labels are applied
kubectl get namespace {{APP_NAMESPACE}} -o jsonpath='{.metadata.labels}' | jq .

# Test: attempt to create a privileged pod in restricted namespace (should fail)
kubectl run test-privileged --image=nginx --restart=Never \
  -n {{APP_NAMESPACE}} \
  --overrides='{"spec":{"containers":[{"name":"test","image":"nginx","securityContext":{"privileged":true}}]}}'
# Expected: Error from server (Forbidden)

# Clean up
kubectl delete pod test-privileged -n {{APP_NAMESPACE}} --ignore-not-found
```

### 1.2 Apply PSS Exemptions

- [ ] Deploy RuntimeClass for privileged workloads
- [ ] Deploy ResourceQuota for security namespace

```bash
# Verify ResourceQuota
kubectl get resourcequota -n security
kubectl describe resourcequota privileged-pod-quota -n security
```

---

## Phase 2: OPA Gatekeeper

### 2.1 Deploy Gatekeeper

- [ ] Apply Gatekeeper Helm release from `templates/gatekeeper/gatekeeper.yaml`

```bash
# Verify Gatekeeper is running
kubectl get pods -n gatekeeper-system
kubectl get constrainttemplates

# Check webhook configuration
kubectl get validatingwebhookconfigurations | grep gatekeeper
```

### 2.2 Deploy Workload Constraint Templates

- [ ] Apply constraint templates from `templates/gatekeeper/constraint-templates.yaml`

```bash
# Verify all templates are installed
kubectl get constrainttemplates
# Expected: k8srequiredlabels, k8scontainerlimits, k8sblockprivilegedcontainer,
#           k8sblockhostnamespace, k8sallowedrepos, k8sblocknodeport,
#           k8srequirenonrootuser, k8sblocklatest
```

### 2.3 Deploy Workload Constraints

- [ ] Apply constraints from `templates/gatekeeper/constraints.yaml`

```bash
# Verify constraints are active
kubectl get constraints

# Check for existing violations
kubectl get k8srequiredlabels deployment-must-have-labels -o yaml | grep -A 50 'status:'
kubectl get k8scontainerlimits container-must-have-limits -o yaml | grep -A 50 'status:'

# Test: attempt to deploy without labels (should fail)
kubectl create deployment test-no-labels --image=nginx -n {{APP_NAMESPACE}}
# Expected: admission webhook denied

# Clean up
kubectl delete deployment test-no-labels -n {{APP_NAMESPACE}} --ignore-not-found
```

### 2.4 Deploy Supply Chain Constraint Templates

- [ ] Apply supply chain templates from `templates/gatekeeper/supply-chain-templates.yaml`

```bash
# Verify supply chain templates
kubectl get constrainttemplates | grep -E "imagedigest|imagesignature|slsa|sbom|denylist|trustedbuilder"
```

### 2.5 Deploy Supply Chain Constraints

- [ ] Apply supply chain constraints from `templates/gatekeeper/supply-chain-constraints.yaml`

```bash
# Verify supply chain constraints
kubectl get constraints | grep -E "require-image-digest|require-signed|require-slsa|require-sbom|blocked-images|require-trusted"

# Check audit results
kubectl get k8srequireimagedigest require-image-digest -o yaml | grep -A 20 'violations:'
```

### 2.6 Deploy Binary Authorization

- [ ] Apply binary authorization from `templates/gatekeeper/binary-authorization.yaml`

```bash
# Verify Cosign signature constraint
kubectl get k8scosignsignature
kubectl get clusterimagepolicy  # Sigstore Policy Controller
```

---

## Phase 3: Kyverno Policies

### 3.1 Deploy Kyverno Policies

- [ ] Apply all policies from `templates/kyverno/`

```bash
# Verify Kyverno policies
kubectl get clusterpolicy

# Check policy reports
kubectl get policyreport -A
kubectl get clusterpolicyreport

# Test: attempt to create privileged pod
kubectl run test-kyverno --image=nginx --restart=Never \
  -n {{APP_NAMESPACE}} \
  --overrides='{"spec":{"containers":[{"name":"test","image":"nginx","securityContext":{"privileged":true}}]}}'
# Expected: Error (policy violation)
```

---

## Phase 4: Falco Runtime Monitoring

### 4.1 Deploy Falco

- [ ] Apply Falco Helm release from `templates/falco/falco.yaml`
- [ ] NOTE: If running on GCP kernel 6.14.0, Falco will fail. See known limitations.

```bash
# Verify Falco DaemonSet
kubectl get daemonset -n security falco
kubectl get pods -n security -l app.kubernetes.io/name=falco

# Check Falco logs for successful start
kubectl logs -n security -l app.kubernetes.io/name=falco --tail=20

# Verify eBPF driver loaded
kubectl logs -n security -l app.kubernetes.io/name=falco | grep -i "driver"
# Expected: "Loading modern eBPF probe"
```

### 4.2 Deploy Custom Rules

- [ ] Apply custom rules ConfigMap from `templates/falco/custom-rules.yaml`

```bash
# Verify ConfigMap
kubectl get configmap falco-custom-rules -n security

# Trigger a test rule: exec into a pod (should generate Falco alert)
kubectl exec -it <any-pod> -n {{APP_NAMESPACE}} -- /bin/sh
# Check Falco logs for "Terminal shell in container" alert
kubectl logs -n security -l app.kubernetes.io/name=falco --tail=5 | grep "Terminal"
```

### 4.3 Deploy Falcosidekick

- [ ] Apply Falcosidekick from `templates/falco/falcosidekick.yaml`

```bash
# Verify Falcosidekick
kubectl get pods -n security -l app.kubernetes.io/name=falcosidekick
kubectl get svc -n security falcosidekick

# Check Falcosidekick UI
kubectl port-forward -n security svc/falcosidekick-ui 2802:2802
# Open http://localhost:2802 in browser
```

---

## Phase 5: KubeArmor

### 5.1 Deploy KubeArmor

- [ ] Apply KubeArmor Helm release from `templates/kubearmor/kubearmor.yaml`

```bash
# Verify KubeArmor DaemonSet
kubectl get daemonset -n kubearmor
kubectl get pods -n kubearmor

# Check KubeArmor logs
kubectl logs -n kubearmor -l kubearmor-app=kubearmor --tail=20

# Install karmor CLI for testing
curl -sfL https://raw.githubusercontent.com/kubearmor/kubearmor-client/main/install.sh | sudo sh -s -- -b /usr/local/bin
```

### 5.2 Deploy KubeArmor Policies

- [ ] Apply policies from `templates/kubearmor/policies.yaml`

```bash
# Verify policies
kubectl get kubearmorpolicies -A
kubectl get kubearmorclusterpolicies

# Test: attempt to read /etc/shadow (should be blocked)
kubectl exec -it <app-pod> -n {{APP_NAMESPACE}} -- cat /etc/shadow
# Expected: Permission denied

# Test: attempt to run apt (should be blocked)
kubectl exec -it <app-pod> -n {{APP_NAMESPACE}} -- apt update
# Expected: Permission denied

# Monitor KubeArmor alerts
karmor log --namespace {{APP_NAMESPACE}}
```

---

## Phase 6: Runtime Verifier

### 6.1 Deploy Runtime Verifier

- [ ] Apply runtime verifier from `templates/runtime-verifier/runtime-verifier.yaml`

```bash
# Verify DaemonSet
kubectl get daemonset -n runtime-verifier
kubectl get pods -n runtime-verifier

# Check verification logs
kubectl logs -n runtime-verifier -l app.kubernetes.io/name=runtime-verifier --tail=30

# Verify RBAC
kubectl auth can-i list pods --as=system:serviceaccount:runtime-verifier:runtime-verifier
# Expected: yes

kubectl auth can-i delete pods --as=system:serviceaccount:runtime-verifier:runtime-verifier
# Expected: no
```

---

## Phase 7: Network Security

### 7.1 Deploy ModSecurity WAF

- [ ] Apply ModSecurity from `templates/network-security/modsecurity/`

```bash
# Verify ModSecurity deployment
kubectl get pods -n waf
kubectl get svc -n waf modsecurity

# Test WAF rules
# SQL injection attempt (should be blocked)
curl -v "http://modsecurity.waf.svc/api/test?id=1' OR 1=1--"
# Expected: 403 Forbidden

# XSS attempt (should be blocked)
curl -v "http://modsecurity.waf.svc/api/test?name=<script>alert(1)</script>"
# Expected: 403 Forbidden

# Check WAF logs
kubectl logs -n waf -l app=modsecurity -c modsecurity --tail=10
```

### 7.2 Deploy DLP Components

- [ ] Apply DLP namespace and Presidio from `templates/network-security/dlp/`
- [ ] [GCP-SPECIFIC] Apply Cloud DLP configuration

```bash
# Verify Presidio
kubectl get pods -n dlp
kubectl get svc -n dlp

# Test Presidio analyzer
kubectl port-forward -n dlp svc/presidio-analyzer 3000:3000
curl -X POST http://localhost:3000/analyze \
  -H "Content-Type: application/json" \
  -d '{"text":"My SSN is 123-45-6789","language":"en"}'
# Expected: JSON response with detected PII entities
```

### 7.3 Deploy API Authorization

- [ ] Apply OPA deployment and policies from `templates/network-security/api-authorization/`

```bash
# Verify OPA
kubectl get pods -n opa-system
kubectl get svc -n opa-system opa

# Test OPA policy
kubectl port-forward -n opa-system svc/opa 8181:8181
curl -X POST http://localhost:8181/v1/data/{{APP_NAME}}/authz/allow \
  -H "Content-Type: application/json" \
  -d '{"input":{"attributes":{"request":{"http":{"method":"GET","path":"/api/v1/health"}}}}}'
# Expected: {"result": true}
```

---

## Phase 8: Incident Responder

### 8.1 Create Secrets

- [ ] Create incident responder secrets

```bash
# Create secrets manually (or use External Secrets Operator)
kubectl create secret generic incident-responder-secrets -n security \
  --from-literal=slack-webhook-url='https://hooks.slack.com/services/xxx' \
  --from-literal=pagerduty-service-key='xxx' \
  --from-literal=jira-api-token='xxx'

# Verify secret exists
kubectl get secret incident-responder-secrets -n security
```

### 8.2 Deploy Incident Responder

- [ ] Apply incident responder from `templates/incident-responder/`

```bash
# Verify deployment
kubectl get pods -n security -l app.kubernetes.io/name=incident-responder
kubectl get svc -n security incident-responder

# Test webhook endpoint
kubectl port-forward -n security svc/incident-responder 8080:8080
curl -X POST http://localhost:8080/incident \
  -H "Content-Type: application/json" \
  -d '{"source":"test","rule":"test-rule","priority":"WARNING"}'
# Expected: 200 OK
```

---

## Phase 9: RBAC Audit

### 9.1 Deploy RBAC Roles and Bindings

- [ ] Apply roles from `templates/rbac-audit/rbac-roles.yaml`
- [ ] Apply bindings from `templates/rbac-audit/rbac-bindings.yaml`

```bash
# Verify roles
kubectl get clusterroles | grep {{APP_NAME}}

# Verify bindings
kubectl get clusterrolebindings | grep {{APP_NAME}}
kubectl get rolebindings -A | grep {{APP_NAME}}

# Test developer access
kubectl auth can-i create deployments -n {{APP_NAMESPACE}} --as=developer@example.com
# Expected: no (developers are read-only)

kubectl auth can-i get pods -n {{APP_NAMESPACE}} --as=developer@example.com
# Expected: yes
```

### 9.2 Deploy Audit Policy

- [ ] Apply audit policy from `templates/rbac-audit/audit-policy.yaml`
- [ ] Apply audit sink from `templates/rbac-audit/audit-sink.yaml`

```bash
# Verify audit policy ConfigMap
kubectl get configmap audit-policy -n kube-system

# Check audit logs are flowing
kubectl logs -n logging -l app=fluent-bit --tail=10 | grep "kube.audit"

# Verify Elasticsearch index
curl -s "http://elasticsearch-master.logging:9200/k8s-audit-*/_count"
```

---

## Phase 10: Security Workflows

### 10.1 Deploy CI/CD Security Workflows

- [ ] Copy workflow files from `templates/security-workflows/` to `.github/workflows/`

```bash
# Verify workflow files exist
ls -la .github/workflows/security-checks.yml
ls -la .github/workflows/security-review-schedule.yml

# Trigger manual workflow run
gh workflow run security-checks.yml
gh run list --workflow=security-checks.yml
```

---

## Phase 11: SIEM Rules

### 11.1 Deploy SIEM Alert Rules

- [ ] Apply SIEM rules to OpenSearch

```bash
# Verify SIEM ConfigMap
kubectl get configmap siem-alert-rules -n opensearch

# Check OpenSearch security analytics
curl -s "http://opensearch-cluster-master:9200/_plugins/_security_analytics/rules" | jq '.total'
```

---

## Verification Checklist

### End-to-End Security Tests

- [ ] **Admission control:** Deploy a pod with `:latest` tag -- should be rejected by Gatekeeper
- [ ] **Runtime monitoring:** Exec into a pod and run `curl` -- Falco should alert
- [ ] **Process blocking:** Attempt to install packages in a pod -- KubeArmor should block
- [ ] **Network policy:** Attempt cross-namespace communication -- Cilium should deny
- [ ] **WAF protection:** Send SQL injection payload -- ModSecurity should block
- [ ] **DLP detection:** Send PII in API response -- Presidio should detect
- [ ] **Incident response:** Trigger a critical Falco rule -- Incident Responder should quarantine and alert
- [ ] **RBAC enforcement:** Developer attempts to delete a deployment -- should be denied
- [ ] **Supply chain:** Deploy unsigned image -- Gatekeeper should reject

### Monitoring Verification

- [ ] Falco metrics visible in Prometheus (`falco_events_total`)
- [ ] KubeArmor alerts visible in relay logs
- [ ] Gatekeeper violation metrics in Prometheus
- [ ] ModSecurity audit logs flowing to Elasticsearch
- [ ] Audit logs visible in Elasticsearch (`k8s-audit-*` index)
- [ ] SIEM alerts triggering for test scenarios
- [ ] Runtime Verifier metrics in Prometheus

### Documentation Verification

- [ ] All templates are genericized (no hardcoded org/app names)
- [ ] All [GCP-SPECIFIC] items are marked
- [ ] Consumer templates are ready for per-service customization
- [ ] Incident response runbook is documented
- [ ] RBAC roles are documented with business justification

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Namespace Setup & Pod Security Standards
- OPA Gatekeeper
- Kyverno Policies
- Falco Runtime Monitoring

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
