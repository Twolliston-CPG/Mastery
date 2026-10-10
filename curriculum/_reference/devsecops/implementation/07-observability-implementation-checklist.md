# Implementation Checklist

## Prerequisites

- [ ] Kubernetes cluster running with `kubectl` access
- [ ] Helm 3.x installed
- [ ] `monitoring` namespace created
- [ ] `logging` namespace created
- [ ] Storage class available for PersistentVolumeClaims
- [ ] ExternalSecrets operator deployed (for credential management)

```bash
# Verify prerequisites
kubectl version --client
helm version
kubectl get ns monitoring logging 2>/dev/null || echo "Namespaces need creation"
kubectl get storageclass
```

---

## Phase 1: Metrics Infrastructure

### Step 1.1: Create Monitoring Namespace

```bash
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace monitoring monitoring=enabled
```

**Verify:**
```bash
kubectl get namespace monitoring -o jsonpath='{.metadata.labels}'
```

### Step 1.2: Deploy Prometheus Stack

```bash
# Add Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install kube-prometheus-stack
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --version 56.0.0 \
  --values templates/prometheus/prometheus-stack-values.yaml \
  --wait --timeout 10m
```

**Verify:**
```bash
# Check all pods are running
kubectl get pods -n monitoring -l "release=kube-prometheus-stack"

# Verify Prometheus is scraping targets
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090 &
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets | length'

# Verify Alertmanager is running
kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093 &
curl -s http://localhost:9093/api/v2/status | jq '.cluster.status'
```

### Step 1.3: Deploy ServiceMonitors

```bash
kubectl apply -f templates/prometheus/servicemonitors.yaml
```

**Verify:**
```bash
# List all ServiceMonitors
kubectl get servicemonitors -n monitoring

# Check Prometheus has discovered the new targets (may take up to 30s)
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090 &
curl -s http://localhost:9090/api/v1/targets | jq '[.data.activeTargets[] | .labels.job]'
```

### Step 1.4: Deploy Supply Chain Alert Rules

```bash
kubectl apply -f templates/prometheus/supply-chain-alerts.yaml
```

**Verify:**
```bash
# List all PrometheusRules
kubectl get prometheusrules -n monitoring

# Verify rules are loaded in Prometheus
curl -s http://localhost:9090/api/v1/rules | jq '[.data.groups[] | .name]'

# Check for any alert rule evaluation errors
curl -s http://localhost:9090/api/v1/rules | jq '[.data.groups[] | .rules[] | select(.health != "ok")]'
```

---

## Phase 2: Visualization

### Step 2.1: Deploy Grafana Dashboards

```bash
# Apply operational dashboards
kubectl apply -f templates/grafana/operational-dashboard.yaml
kubectl apply -f templates/grafana/services-dashboard.yaml

# Apply security dashboards
kubectl apply -f templates/grafana/security-overview-dashboard.yaml
kubectl apply -f templates/grafana/security-dashboard.yaml

# Apply supply chain dashboard
kubectl apply -f templates/grafana/supply-chain-dashboard.yaml
```

**Verify:**
```bash
# Check dashboard ConfigMaps exist
kubectl get configmaps -n monitoring -l grafana_dashboard=1

# Port-forward to Grafana and verify dashboards load
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80 &
# Open http://localhost:3000 (default: admin / prom-operator)
# Navigate to Dashboards and confirm all dashboards appear
```

### Step 2.2: Configure Grafana Data Sources

If using additional data sources (Elasticsearch, Cloud Trace):

```bash
# Verify Prometheus data source is auto-configured
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80 &
curl -s -u admin:prom-operator http://localhost:3000/api/datasources | jq '.[].name'
```

---

## Phase 3: Logging Infrastructure

### Step 3.1: Create Logging Namespace

```bash
kubectl create namespace logging --dry-run=client -o yaml | kubectl apply -f -
```

### Step 3.2: Deploy Elasticsearch / OpenSearch

```bash
# Option A: Elasticsearch with ECK
kubectl apply -f templates/alertmanager/elasticsearch-cluster.yaml

# Wait for Elasticsearch to be ready (this can take 5-10 minutes)
kubectl wait --for=condition=Ready elasticsearch/elasticsearch -n logging --timeout=600s
```

**Verify:**
```bash
# Check Elasticsearch cluster health
ES_PASS=$(kubectl get secret elasticsearch-es-elastic-user -n logging -o jsonpath='{.data.elastic}' | base64 -d)
kubectl port-forward -n logging svc/elasticsearch-es-http 9200:9200 &
curl -s -u "elastic:$ES_PASS" http://localhost:9200/_cluster/health | jq '.status'
```

### Step 3.3: Deploy Fluent Bit

```bash
# Add Helm repository
helm repo add fluent https://fluent.github.io/helm-charts
helm repo update

# Install Fluent Bit
helm install fluent-bit fluent/fluent-bit \
  --namespace monitoring \
  --version 0.43.0 \
  --values templates/fluent-bit/fluent-bit-values.yaml \
  --wait --timeout 5m
```

**Verify:**
```bash
# Check Fluent Bit DaemonSet is running on all nodes
kubectl get daemonset fluent-bit -n monitoring
kubectl get pods -n monitoring -l app.kubernetes.io/name=fluent-bit -o wide

# Verify Fluent Bit health endpoint
FB_POD=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=fluent-bit -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n monitoring $FB_POD -- curl -s http://localhost:2020/api/v1/health

# Check Fluent Bit metrics
kubectl exec -n monitoring $FB_POD -- curl -s http://localhost:2020/api/v1/metrics | head -20
```

### Step 3.4: Set Up Index Templates and ILM Policies

```bash
kubectl apply -f templates/siem-rules/index-templates.yaml
```

**Verify:**
```bash
# Check index templates were created
curl -s -u "elastic:$ES_PASS" http://localhost:9200/_index_template | jq '.index_templates[].name'

# Check ILM policies
curl -s -u "elastic:$ES_PASS" http://localhost:9200/_ilm/policy | jq 'keys'
```

---

## Phase 4: Alerting Configuration

### Step 4.1: Configure Alertmanager Receivers

```bash
kubectl apply -f templates/alertmanager/alertmanager-config.yaml
```

**Verify:**
```bash
# Check Alertmanager configuration was loaded
kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093 &
curl -s http://localhost:9093/api/v2/status | jq '.config.original'

# Check for active alerts
curl -s http://localhost:9093/api/v2/alerts | jq 'length'
```

### Step 4.2: Test Alert Routing

```bash
# Send a test alert to Alertmanager
curl -X POST http://localhost:9093/api/v2/alerts \
  -H "Content-Type: application/json" \
  -d '[{
    "labels": {
      "alertname": "TestAlert",
      "severity": "warning",
      "namespace": "test"
    },
    "annotations": {
      "summary": "Test alert for routing verification"
    },
    "generatorURL": "http://localhost:9090"
  }]'

# Verify alert appears in Alertmanager
curl -s http://localhost:9093/api/v2/alerts | jq '.[0].labels'
```

---

## Phase 5: SIEM Integration

### Step 5.1: Deploy Elastic SIEM Rules

```bash
kubectl apply -f templates/siem-rules/elastic-siem-rules.yaml

# Wait for import job to complete
kubectl wait --for=condition=complete job/siem-rules-import -n logging --timeout=120s
```

**Verify:**
```bash
# Check import job logs
kubectl logs -n logging job/siem-rules-import

# Verify rules exist in Kibana (via API)
kubectl port-forward -n logging svc/kibana-kb-http 5601:5601 &
curl -s -u "elastic:$ES_PASS" \
  -H "kbn-xsrf: true" \
  http://localhost:5601/api/detection_engine/rules/_find | jq '.total'
```

### Step 5.2: Deploy OpenSearch SIEM Rules

```bash
kubectl apply -f templates/siem-rules/opensearch-siem-rules.yaml
```

**Verify:**
```bash
# Check rule ConfigMap exists
kubectl get configmap opensearch-siem-rules -n logging -o jsonpath='{.data}' | jq 'keys'
```

### Step 5.3: Deploy Platform SIEM Alert Rules

```bash
kubectl apply -f templates/siem-rules/platform-siem-rules.yaml
```

**Verify:**
```bash
kubectl get configmap siem-alert-rules -n opensearch -o jsonpath='{.data}' | jq 'keys'
```

---

## Phase 6: Consumer Templates

### Step 6.1: Deploy Per-Service ServiceMonitor

For each application service:

```bash
# Replace placeholders and apply
export SERVICE_NAME="my-service"
export APP_NAMESPACE="my-app"
export SERVICE_PORT="http"

envsubst < consumer-templates/service-monitor.yaml | kubectl apply -f -
```

**Verify:**
```bash
kubectl get servicemonitors -n monitoring | grep $SERVICE_NAME
```

### Step 6.2: Deploy Per-Service Alert Rules

```bash
envsubst < consumer-templates/prometheus-rules.yaml | kubectl apply -f -
```

**Verify:**
```bash
kubectl get prometheusrules -n monitoring | grep $SERVICE_NAME
```

### Step 6.3: Deploy Per-Service Grafana Dashboard

```bash
envsubst < consumer-templates/grafana-dashboard.json | \
  kubectl create configmap grafana-dashboard-$SERVICE_NAME \
    --from-file=$SERVICE_NAME.json=/dev/stdin \
    -n monitoring --dry-run=client -o yaml | \
  kubectl label --local -f - grafana_dashboard=1 -o yaml | \
  kubectl apply -f -
```

**Verify:**
```bash
kubectl get configmap grafana-dashboard-$SERVICE_NAME -n monitoring
```

---

## Phase 7: Validation

### Step 7.1: End-to-End Metrics Verification

```bash
# Verify Prometheus has targets for all expected services
EXPECTED_TARGETS=("{{APP_NAME}}-api" "postgres" "redis" "{{APP_NAME}}-go-services" "argocd")
for target in "${EXPECTED_TARGETS[@]}"; do
  echo -n "Target $target: "
  curl -s http://localhost:9090/api/v1/targets | \
    jq -r "[.data.activeTargets[] | select(.labels.job == \"$target\")] | length"
done
```

### Step 7.2: End-to-End Logging Verification

```bash
# Generate a test log entry
kubectl run log-test --image=busybox --restart=Never -- sh -c 'echo "{\"level\":\"info\",\"msg\":\"observability test\"}" && sleep 5'

# Wait 30 seconds for Fluent Bit to collect and forward
sleep 30

# Search for test log in Elasticsearch
curl -s -u "elastic:$ES_PASS" \
  "http://localhost:9200/_search?q=observability+test" | jq '.hits.total.value'

# Cleanup
kubectl delete pod log-test
```

### Step 7.3: Dashboard Verification

```bash
# List all Grafana dashboards via API
curl -s -u admin:prom-operator http://localhost:3000/api/search | jq '.[].title'

# Expected dashboards:
# - {{APP_NAME}} Platform Overview
# - {{APP_NAME}} Services
# - Security Overview
# - Security Dashboard
# - Supply Chain Security
```

### Step 7.4: Alert Rule Verification

```bash
# List all loaded alert rules
curl -s http://localhost:9090/api/v1/rules | \
  jq '[.data.groups[] | {name: .name, rules: [.rules[] | .name]}]'

# Check for any unhealthy rules
curl -s http://localhost:9090/api/v1/rules | \
  jq '[.data.groups[] | .rules[] | select(.health != "ok") | {name: .name, error: .lastError}]'
```

### Step 7.5: SIEM Rule Verification

```bash
# Count Elastic SIEM rules
curl -s -u "elastic:$ES_PASS" \
  -H "kbn-xsrf: true" \
  http://localhost:5601/api/detection_engine/rules/_find | jq '.total'

# Expected: 9 rules (brute-force, privilege-escalation, secret-access,
# pod-exec, waf-critical, data-exfiltration, unauthorized-api,
# financial-anomaly, container-escape)
```

---

## Rollback Procedure

If issues are encountered, rollback in reverse order:

```bash
# Rollback SIEM rules
kubectl delete job siem-rules-import -n logging
kubectl delete configmap siem-detection-rules -n logging
kubectl delete configmap opensearch-siem-rules -n logging

# Rollback Fluent Bit
helm uninstall fluent-bit -n monitoring

# Rollback Grafana dashboards
kubectl delete configmap -n monitoring -l grafana_dashboard=1

# Rollback alert rules
kubectl delete prometheusrules -n monitoring --all

# Rollback ServiceMonitors
kubectl delete servicemonitors -n monitoring --all

# Rollback Prometheus stack (CAUTION: deletes all monitoring)
helm uninstall kube-prometheus-stack -n monitoring

# Rollback Elasticsearch
kubectl delete elasticsearch elasticsearch -n logging
```

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Metrics Infrastructure
- Visualization
- Logging Infrastructure
- Alerting Configuration

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
