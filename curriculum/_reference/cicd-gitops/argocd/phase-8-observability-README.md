# Phase 8: Observability

**Goal:** Master monitoring, notifications, and custom health checks for Argo CD.

**Duration:** 2-3 hours

---

## Overview

This phase covers:
- Prometheus metrics and ServiceMonitors
- Alerting rules for Argo CD
- Notifications (Slack, email, webhooks)
- Custom health checks with Lua

---

## Concepts

### Argo CD Metrics

Argo CD exposes Prometheus metrics on port 8082:

**Metrics Endpoints**

argocd-server:8082/metrics       - API server metrics
argocd-application-controller:8082/metrics - Controller metrics
argocd-repo-server:8082/metrics  - Repo server metrics
argocd-dex-server:5558/metrics   - Dex metrics


**Key metrics:**

| Metric | Type | Description |
|--------|------|-------------|
| `argocd_app_info` | Gauge | Application info with labels |
| `argocd_app_sync_total` | Counter | Sync operation counts |
| `argocd_app_reconcile` | Histogram | Reconciliation duration |
| `argocd_cluster_connection_status` | Gauge | Cluster connectivity |
| `argocd_git_request_total` | Counter | Git operations |

### Application Info Metric

The `argocd_app_info` metric is especially useful:

```prometheus
argocd_app_info{
  name="myapp",
  project="default",
  dest_server="https://kubernetes.default.svc",
  dest_namespace="production",
  sync_status="Synced",
  health_status="Healthy"
} 1
```

Use it for:
- Counting apps by status
- Alerting on OutOfSync or Degraded
- Dashboards

### Notifications Architecture

<!-- figure: generated from the Mermaid below by _shared/diagrams/embed-figures.py — do not edit the image -->
![Notifications Architecture — diagram](../../../../_figures/curriculum-_reference-cicd-gitops-argocd-phase-8-observability-README-0-b9c6b4ca.png)

<details>
<summary>Diagram source (Mermaid)</summary>

```mermaid
%%{init: {'theme':'base','themeVariables':{'fontFamily':'Helvetica, Arial, sans-serif','fontSize':'13px','primaryColor':'#ffffff','primaryTextColor':'#2d3436','primaryBorderColor':'#9aa3ab','lineColor':'#9aa3ab','textColor':'#2d3436','clusterBkg':'#fbfcfd','clusterBorder':'#d4dae0','edgeLabelBackground':'#ffffff','tertiaryColor':'#eef4fb'},'flowchart':{'curve':'basis','padding':14,'nodeSpacing':42,'rankSpacing':58}}}%%
flowchart LR
  classDef default fill:#ffffff,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef n    fill:#ffffff,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef crit fill:#eef4fb,stroke:#2f6fb8,stroke-width:1.8px,color:#1b3a5c
  classDef data fill:#f4f7fa,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef mut  fill:#ffffff,stroke:#cfd6dc,stroke-width:1.1px,color:#7a8288
  classDef warn fill:#fdf0ec,stroke:#c0522d,stroke-width:1.6px,color:#8a3a1e
  APP["Application<br/><i>state change</i>"]
  TR["Trigger<br/><i>when to notify — on-sync-failed, on-health-degraded</i>"]
  TP["Template<br/><i>what the message says</i>"]
  SV["Service<br/><i>how it is delivered</i>"]
  SL["Slack"]
  EM["Email"]
  WH["Webhook"]
  APP ==> TR ==> TP ==> SV
  SV --> SL
  SV --> EM
  SV --> WH
  class APP n
  class TR crit
  class TP n
  class SV n
  class SL,EM,WH mut
  linkStyle 0,1,2 stroke:#2f6fb8,stroke-width:2px

%% Trigger and template are separate on purpose: one template can serve several
%% triggers, and changing what a message says does not mean touching the
%% condition that decides whether to send it.
```

</details>

**Components:**
- **Triggers** - Conditions that fire notifications
- **Templates** - Message formatting
- **Services** - Delivery channels (Slack, email, etc.)

### Custom Health Checks

Argo CD uses Lua scripts to determine resource health:

```lua
hs = {}
if obj.status ~= nil then
  if obj.status.phase == "Running" then
    hs.status = "Healthy"
    hs.message = "Resource is running"
  elseif obj.status.phase == "Failed" then
    hs.status = "Degraded"
    hs.message = "Resource failed"
  end
else
  hs.status = "Progressing"
  hs.message = "Waiting for status"
end
return hs
```

**Health statuses:**
- `Healthy` - Working correctly
- `Degraded` - Has errors
- `Progressing` - Still starting
- `Suspended` - Paused
- `Missing` - Resource deleted
- `Unknown` - Can't determine

---

## Labs

### Lab 8.1: Prometheus Metrics Setup

#### Step 1: Review ServiceMonitor Configuration

```bash
cat monitoring/servicemonitors.yaml
```

ServiceMonitors tell Prometheus what to scrape.

#### Step 2: Install Prometheus (if not already)

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace
```

#### Step 3: Apply ServiceMonitors

```bash
kubectl apply -f monitoring/servicemonitors.yaml
```

#### Step 4: Verify Metrics

```bash
# Port-forward to Prometheus
kubectl port-forward svc/prometheus-kube-prometheus-prometheus \
  -n monitoring 9090:9090

# Open http://localhost:9090
# Query: argocd_app_info
```

#### Step 5: Explore Metrics

Try these PromQL queries:

```promql
# Count apps by sync status
count(argocd_app_info) by (sync_status)

# Count apps by health status
count(argocd_app_info) by (health_status)

# Sync operations per minute
rate(argocd_app_sync_total[5m])

# Failed syncs
argocd_app_sync_total{phase="Failed"}

# Reconciliation time (95th percentile)
histogram_quantile(0.95, sum(rate(argocd_app_reconcile_bucket[5m])) by (le))
```

### Lab 8.2: Configure Alerting Rules

#### Step 1: Review Alert Rules

```bash
cat monitoring/prometheus-rules.yaml
```

Alerts defined:
- `ArgoCDAppOutOfSync` - App out of sync for 15 minutes
- `ArgoCDAppDegraded` - App health degraded for 5 minutes
- `ArgoCDSyncFailed` - Sync operations failing
- `ArgoCDClusterConnectionFailed` - Cluster unreachable

#### Step 2: Apply Alert Rules

```bash
kubectl apply -f monitoring/prometheus-rules.yaml
```

#### Step 3: Verify Rules

```bash
# Port-forward to Prometheus
# Then check http://localhost:9090/rules
```

#### Step 4: Test an Alert

Make an app unhealthy to trigger an alert:

```bash
# Scale deployment to 0 replicas
kubectl scale deployment guestbook-ui -n guestbook --replicas=0

# Wait for alert to fire (after 5 minutes)
```

### Lab 8.3: Configure Notifications

#### Step 1: Review Notification Config

```bash
cat notifications/argocd-notifications-cm.yaml
```

Key sections:
- **Services** - Slack, email, webhook configuration
- **Triggers** - When to send notifications
- **Templates** - Message formatting

#### Step 2: Create Slack Token Secret

```bash
# Create secret with your Slack token
kubectl create secret generic argocd-notifications-secret \
  -n argocd \
  --from-literal=slack-token=xoxb-your-slack-token

# Or apply the template
kubectl apply -f notifications/argocd-notifications-secret.yaml
```

#### Step 3: Apply Notification Config

```bash
kubectl apply -f notifications/argocd-notifications-cm.yaml
```

#### Step 4: Subscribe an Application

Add annotation to an application:

```yaml
metadata:
  annotations:
    notifications.argoproj.io/subscribe.on-sync-succeeded.slack: my-channel
    notifications.argoproj.io/subscribe.on-sync-failed.slack: my-channel
    notifications.argoproj.io/subscribe.on-health-degraded.slack: my-channel
```

Or use the example:

```bash
cat notifications/app-with-notifications.yaml
kubectl apply -f notifications/app-with-notifications.yaml
```

#### Step 5: Test Notifications

```bash
# Sync the app to trigger a notification
argocd app sync notified-app
```

### Lab 8.4: Custom Health Checks

#### Step 1: Review Health Check Lua Scripts

```bash
cat health-checks/custom-health-lua.yaml
```

Examples included:
- cert-manager Certificate
- Argo Rollout
- Kafka Topic (Strimzi)
- Generic CRD pattern

#### Step 2: Understand Lua Health Checks

Basic structure:

```lua
hs = {}                    -- Health status object

-- Check status exists
if obj.status ~= nil then
  -- Check conditions
  if obj.status.conditions ~= nil then
    for i, condition in ipairs(obj.status.conditions) do
      if condition.type == "Ready" then
        if condition.status == "True" then
          hs.status = "Healthy"
          hs.message = condition.message
          return hs
        end
      end
    end
  end
end

hs.status = "Progressing"
hs.message = "Waiting for status"
return hs
```

#### Step 3: Apply Custom Health Checks

```bash
kubectl apply -f health-checks/custom-health-lua.yaml

# Restart controller to pick up changes
kubectl rollout restart deployment argocd-application-controller -n argocd
```

#### Step 4: Test Health Check

Deploy a cert-manager Certificate:

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: test-cert
spec:
  secretName: test-cert-tls
  issuerRef:
    name: letsencrypt
    kind: ClusterIssuer
  dnsNames:
    - example.com
```

Watch the health status change:
1. Initial: `Progressing` (waiting to be issued)
2. Success: `Healthy` (certificate issued)
3. Failure: `Degraded` (issuance failed)

### Lab 8.5: Grafana Dashboard

#### Step 1: Import Dashboard

The Argo CD project provides official Grafana dashboards:

```bash
# Dashboard ID: 14584 (Argo CD Dashboard)
# Import in Grafana: Dashboards > Import > Enter ID 14584
```

#### Step 2: Key Panels to Include

- Application count by status
- Sync success rate
- Reconciliation latency
- Git operation performance
- Cluster connection status

---

## Notification Triggers Reference

| Trigger | Fires When |
|---------|------------|
| `on-sync-succeeded` | Sync operation succeeds |
| `on-sync-failed` | Sync operation fails |
| `on-sync-running` | Sync operation starts |
| `on-sync-status-unknown` | Sync status becomes unknown |
| `on-health-degraded` | Health becomes Degraded |
| `on-deployed` | Synced AND Healthy |
| `on-created` | Application is created |
| `on-deleted` | Application is deleted |

### Custom Triggers

Create your own triggers:

```yaml
trigger.on-my-trigger: |
  - when: app.status.health.status == 'Degraded' and app.metadata.labels.critical == 'true'
    send: [critical-app-degraded]
```

---

## Best Practices

### Metrics

1. **Use labels wisely** - Don't create high-cardinality metrics
2. **Set alert thresholds carefully** - Avoid alert fatigue
3. **Include runbook URLs** - Help on-call engineers
4. **Dashboard per team** - Filter by project/labels

### Notifications

1. **Subscribe at project level** - Use annotations on AppProject
2. **Use `oncePer`** - Prevent duplicate notifications
3. **Include context** - Revision, namespace, project in messages
4. **Escalation paths** - Different channels for severity

### Health Checks

1. **Return quickly** - Lua runs on every reconcile
2. **Handle nil** - Always check for nil status
3. **Clear messages** - Help users understand state
4. **Test thoroughly** - Bad health checks break apps

---

## Knowledge Check

Answer these questions before proceeding:

1. **What metric shows application sync and health status?**
   <details>
   <summary>Answer</summary>
   `argocd_app_info` - It has labels for sync_status and health_status, plus project, namespace, etc.
   </details>

2. **What's the difference between triggers and templates in notifications?**
   <details>
   <summary>Answer</summary>
   Triggers define WHEN to send (conditions). Templates define WHAT to send (message format). Triggers reference templates.
   </details>

3. **What Lua health statuses are available?**
   <details>
   <summary>Answer</summary>
   Healthy, Degraded, Progressing, Suspended, Missing, and Unknown.
   </details>

4. **How do you subscribe an app to notifications?**
   <details>
   <summary>Answer</summary>
   Add annotation: `notifications.argoproj.io/subscribe.<trigger>.<service>: <destination>` to the Application.
   </details>

5. **What does `oncePer` do in notification triggers?**
   <details>
   <summary>Answer</summary>
   Prevents duplicate notifications for the same event. Uses the expression value as a deduplication key (e.g., revision).
   </details>

---

## Common Mistakes

1. **Missing ServiceMonitor labels** - Prometheus won't find the targets
2. **Wrong alert thresholds** - Too sensitive or too lenient
3. **No `oncePer` in triggers** - Notification spam
4. **Lua nil errors** - Always check for nil before accessing fields
5. **Not testing health checks** - Deploy a test resource first

---

## Files in This Directory

| File/Directory | Purpose |
|----------------|---------|
| `monitoring/servicemonitors.yaml` | Prometheus ServiceMonitors |
| `monitoring/prometheus-rules.yaml` | Alert rules |
| `notifications/argocd-notifications-cm.yaml` | Notification config |
| `notifications/argocd-notifications-secret.yaml` | Notification secrets |
| `notifications/app-with-notifications.yaml` | Example subscribed app |
| `health-checks/custom-health-lua.yaml` | Custom Lua health checks |

---

## What's Next?

Now that you understand observability, proceed to **Phase 9: HA & Disaster Recovery** to learn about high availability and backup strategies.

```bash
cd ../phase-9-ha-dr
cat README.md
```

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Notification Triggers Reference
- Argo CD Metrics
- Application Info Metric
- Notifications Architecture

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"The pipeline deploys the application."* |
| ✓ | *"CI writes a new image tag into a config repository and stops. A controller running *inside* the cluster polls that repo, diffs the rendered manifests against live state, and applies the difference — so nothing outside the cluster ever holds credentials to it."* |

**Trace it:** `git push` → the new version serving traffic, with nothing else typed. Name where the handoff between CI and CD happens, and what that handoff physically is.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** the four [OpenGitOps principles](https://opengitops.dev/#principles) — then say which one a `kubectl apply` inside CI violates.
Full list per domain: [`SOURCES.md`](../../SOURCES.md#cicd-gitops)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../../MASTERY.md)

<!-- /feynman-check -->
