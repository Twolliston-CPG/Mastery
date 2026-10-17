# Exercise 6: Audit Logging

## Objectives

- Configure Kubernetes audit logging
- Design effective audit policies
- Analyze audit logs
- Implement compliance monitoring

## Prerequisites

- Completed Exercises 1-5
- Cluster admin access
- Log aggregation system (optional)

---

## Part 1: Audit Logging Overview

### 1.1 Audit Event Structure

**Kubernetes Audit Event**

```
{
  "apiVersion": "audit.k8s.io/v1",
  "kind": "Event",
  "level": "RequestResponse",
  "auditID": "unique-id",
  "stage": "ResponseComplete",
  "requestURI": "/api/v1/namespaces/default/secrets",
  "verb": "create",
  "user": {
    "username": "admin@example.com",
    "groups": ["system:authenticated"]
  },
  "sourceIPs": ["10.0.0.5"],
  "objectRef": {
    "resource": "secrets",
    "namespace": "default",
    "name": "my-secret"
  },
  "responseStatus": {
    "code": 201
  },
  "requestReceivedTimestamp": "2024-01-15T10:00:00Z",
  "stageTimestamp": "2024-01-15T10:00:01Z"
}
```


### 1.2 Audit Levels

```yaml
# Audit Levels (from least to most verbose):

# None - Don't log events matching this rule
level: None

# Metadata - Log request metadata only
# (user, timestamp, resource, verb, etc.)
level: Metadata

# Request - Log metadata + request body
# (for non-read requests)
level: Request

# RequestResponse - Log metadata + request + response bodies
# (most detailed, largest storage)
level: RequestResponse
```

### 1.3 Audit Stages

```yaml
# Stages where events can be logged:

# RequestReceived - Event generated when handler receives request
stage: RequestReceived

# ResponseStarted - Response headers sent (streaming only)
stage: ResponseStarted

# ResponseComplete - Response body complete
stage: ResponseComplete

# Panic - If panic occurs during handling
stage: Panic
```

---

## Part 2: Audit Policy Configuration

### 2.1 Comprehensive Audit Policy

```yaml
# audit-policy.yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  # Don't log requests to certain non-resource URL paths
  - level: None
    nonResourceURLs:
      - /healthz*
      - /version
      - /swagger*
      - /readyz
      - /livez

  # Don't log watch requests
  - level: None
    verbs: ["watch"]
    resources:
      - group: ""
        resources: ["events"]

  # Don't log system:apiserver internal requests
  - level: None
    users: ["system:apiserver"]

  # Don't log kubelet health checks
  - level: None
    userGroups: ["system:nodes"]
    verbs: ["get"]
    resources:
      - group: ""
        resources: ["nodes/status"]

  # Log authentication failures
  - level: Metadata
    nonResourceURLs:
      - /api
      - /api/*
      - /apis
      - /apis/*

  # Log secrets at RequestResponse level
  - level: RequestResponse
    resources:
      - group: ""
        resources: ["secrets", "configmaps"]
    omitStages:
      - RequestReceived

  # Log token requests
  - level: RequestResponse
    resources:
      - group: ""
        resources: ["serviceaccounts/token"]
    omitStages:
      - RequestReceived

  # Log RBAC changes at RequestResponse
  - level: RequestResponse
    resources:
      - group: "rbac.authorization.k8s.io"
        resources: ["roles", "rolebindings", "clusterroles", "clusterrolebindings"]
    omitStages:
      - RequestReceived

  # Log pod exec/attach
  - level: RequestResponse
    resources:
      - group: ""
        resources: ["pods/exec", "pods/attach", "pods/portforward"]
    omitStages:
      - RequestReceived

  # Log security policy changes
  - level: RequestResponse
    resources:
      - group: "networking.k8s.io"
        resources: ["networkpolicies"]
      - group: "policy"
        resources: ["podsecuritypolicies"]
    omitStages:
      - RequestReceived

  # Log namespace operations
  - level: Metadata
    resources:
      - group: ""
        resources: ["namespaces"]

  # Log all create, update, patch, delete
  - level: Request
    verbs: ["create", "update", "patch", "delete"]
    omitStages:
      - RequestReceived

  # Everything else at Metadata
  - level: Metadata
    omitStages:
      - RequestReceived
```

### 2.2 Security-Focused Policy

```yaml
# security-audit-policy.yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  # Authentication events
  - level: RequestResponse
    nonResourceURLs:
      - /api
      - /api/*
      - /apis
      - /apis/*
    verbs: ["get", "post"]
    users: ["*"]

  # All secret operations
  - level: RequestResponse
    resources:
      - group: ""
        resources: ["secrets"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]

  # Service account token creation
  - level: RequestResponse
    resources:
      - group: ""
        resources: ["serviceaccounts/token"]
      - group: "authentication.k8s.io"
        resources: ["tokenreviews"]

  # All RBAC operations
  - level: RequestResponse
    resources:
      - group: "rbac.authorization.k8s.io"

  # Certificate operations
  - level: RequestResponse
    resources:
      - group: "certificates.k8s.io"
        resources: ["certificatesigningrequests", "certificatesigningrequests/approval"]

  # Admission webhook configurations
  - level: RequestResponse
    resources:
      - group: "admissionregistration.k8s.io"

  # Pod security
  - level: RequestResponse
    resources:
      - group: ""
        resources: ["pods/exec", "pods/attach", "pods/portforward"]
      - group: "policy"
        resources: ["podsecuritypolicies"]

  # Network policies
  - level: RequestResponse
    resources:
      - group: "networking.k8s.io"
        resources: ["networkpolicies"]

  # Default: metadata for everything else
  - level: Metadata
    omitStages:
      - RequestReceived
```

---

## Part 3: Enable Audit Logging

### 3.1 API Server Configuration

```yaml
# Add to kube-apiserver.yaml manifest
apiVersion: v1
kind: Pod
metadata:
  name: kube-apiserver
  namespace: kube-system
spec:
  containers:
  - command:
    - kube-apiserver
    # Audit configuration
    - --audit-policy-file=/etc/kubernetes/audit/audit-policy.yaml
    - --audit-log-path=/var/log/kubernetes/audit/audit.log
    - --audit-log-maxage=30
    - --audit-log-maxbackup=10
    - --audit-log-maxsize=100
    # Optional: webhook backend
    - --audit-webhook-config-file=/etc/kubernetes/audit/webhook-config.yaml
    - --audit-webhook-batch-max-wait=5s
    volumeMounts:
    - name: audit-policy
      mountPath: /etc/kubernetes/audit
      readOnly: true
    - name: audit-logs
      mountPath: /var/log/kubernetes/audit
  volumes:
  - name: audit-policy
    hostPath:
      path: /etc/kubernetes/audit
      type: Directory
  - name: audit-logs
    hostPath:
      path: /var/log/kubernetes/audit
      type: DirectoryOrCreate
```

### 3.2 Webhook Backend Configuration

```yaml
# webhook-config.yaml
apiVersion: v1
kind: Config
clusters:
  - name: audit-webhook
    cluster:
      server: https://audit-collector.monitoring.svc:8443/audit
      certificate-authority: /etc/kubernetes/pki/audit-webhook-ca.crt
contexts:
  - name: webhook
    context:
      cluster: audit-webhook
current-context: webhook
```

### 3.3 Audit Log Collector

```yaml
# audit-collector.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: audit-collector
  namespace: monitoring
spec:
  replicas: 2
  selector:
    matchLabels:
      app: audit-collector
  template:
    metadata:
      labels:
        app: audit-collector
    spec:
      containers:
      - name: collector
        image: audit-collector:1.0
        ports:
        - containerPort: 8443
        volumeMounts:
        - name: tls
          mountPath: /etc/tls
          readOnly: true
        env:
        - name: ELASTICSEARCH_URL
          value: "http://elasticsearch:9200"
        - name: INDEX_PREFIX
          value: "k8s-audit"
      volumes:
      - name: tls
        secret:
          secretName: audit-collector-tls
---
apiVersion: v1
kind: Service
metadata:
  name: audit-collector
  namespace: monitoring
spec:
  selector:
    app: audit-collector
  ports:
  - port: 8443
    targetPort: 8443
```

---

## Part 4: Log Analysis

### 4.1 Common Audit Queries

```bash
# Find all secret access
jq 'select(.objectRef.resource == "secrets")' audit.log

# Find failed authentication attempts
jq 'select(.responseStatus.code >= 400 and .responseStatus.code < 500)' audit.log

# Find privilege escalation attempts
jq 'select(.objectRef.resource == "clusterrolebindings" and .verb == "create")' audit.log

# Find exec into pods
jq 'select(.objectRef.resource == "pods" and .objectRef.subresource == "exec")' audit.log

# Find who deleted resources
jq 'select(.verb == "delete") | {user: .user.username, resource: .objectRef.resource, name: .objectRef.name, time: .requestReceivedTimestamp}' audit.log

# Find all actions by a specific user
jq 'select(.user.username == "admin@example.com")' audit.log
```

### 4.2 Security Analysis Script

```bash
#!/bin/bash
# analyze-audit-logs.sh

AUDIT_LOG=${1:-/var/log/kubernetes/audit/audit.log}

echo "=== Kubernetes Audit Log Analysis ==="
echo "Analyzing: $AUDIT_LOG"

echo -e "\n--- Summary Statistics ---"
echo "Total events: $(wc -l < $AUDIT_LOG)"
echo "Unique users: $(jq -r '.user.username' $AUDIT_LOG | sort -u | wc -l)"
echo "Unique resources: $(jq -r '.objectRef.resource' $AUDIT_LOG 2>/dev/null | sort -u | wc -l)"

echo -e "\n--- Top 10 Users by Activity ---"
jq -r '.user.username' $AUDIT_LOG | sort | uniq -c | sort -rn | head -10

echo -e "\n--- Top 10 Resources Accessed ---"
jq -r '.objectRef.resource' $AUDIT_LOG 2>/dev/null | sort | uniq -c | sort -rn | head -10

echo -e "\n--- Failed Requests (4xx/5xx) ---"
jq 'select(.responseStatus.code >= 400) | {user: .user.username, verb: .verb, resource: .objectRef.resource, code: .responseStatus.code}' $AUDIT_LOG | head -50

echo -e "\n--- Secret Access Events ---"
jq 'select(.objectRef.resource == "secrets") | {user: .user.username, verb: .verb, namespace: .objectRef.namespace, name: .objectRef.name, time: .requestReceivedTimestamp}' $AUDIT_LOG | head -20

echo -e "\n--- Pod Exec Events ---"
jq 'select(.objectRef.subresource == "exec") | {user: .user.username, pod: .objectRef.name, namespace: .objectRef.namespace, time: .requestReceivedTimestamp}' $AUDIT_LOG

echo -e "\n--- RBAC Changes ---"
jq 'select(.objectRef.apiGroup == "rbac.authorization.k8s.io" and (.verb == "create" or .verb == "update" or .verb == "delete")) | {user: .user.username, verb: .verb, resource: .objectRef.resource, name: .objectRef.name}' $AUDIT_LOG
```

### 4.3 Elasticsearch Dashboard Queries

```json
// Kibana queries for audit logs

// Failed authentication
{
  "query": {
    "bool": {
      "must": [
        {"range": {"responseStatus.code": {"gte": 401, "lt": 500}}}
      ]
    }
  }
}

// Privilege escalation attempts
{
  "query": {
    "bool": {
      "must": [
        {"term": {"verb": "create"}},
        {"terms": {"objectRef.resource": ["clusterrolebindings", "rolebindings"]}}
      ]
    }
  }
}

// Sensitive resource access
{
  "query": {
    "bool": {
      "should": [
        {"term": {"objectRef.resource": "secrets"}},
        {"term": {"objectRef.subresource": "exec"}},
        {"term": {"objectRef.subresource": "attach"}}
      ],
      "minimum_should_match": 1
    }
  }
}
```

---

## Part 5: Alerting on Audit Events

### 5.1 Prometheus Alerting Rules

```yaml
# audit-alerts.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: audit-alerts
  namespace: monitoring
spec:
  groups:
  - name: audit.security
    rules:
    # Multiple failed auth attempts
    - alert: MultipleFailedAuthentications
      expr: |
        increase(apiserver_audit_event_total{code=~"401|403"}[5m]) > 10
      for: 1m
      labels:
        severity: warning
      annotations:
        summary: "Multiple failed authentication attempts"

    # Secret access spike
    - alert: UnusualSecretAccess
      expr: |
        increase(apiserver_audit_event_total{resource="secrets", verb="get"}[5m])
        >
        2 * avg_over_time(apiserver_audit_event_total{resource="secrets", verb="get"}[1h])
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Unusual spike in secret access"

    # RBAC changes
    - alert: RBACConfigurationChanged
      expr: |
        increase(apiserver_audit_event_total{apiGroup="rbac.authorization.k8s.io", verb=~"create|update|delete"}[5m]) > 0
      for: 1m
      labels:
        severity: info
      annotations:
        summary: "RBAC configuration changed"
```

### 5.2 Fluent Bit Alert Configuration

```yaml
# fluent-bit-audit-alerts.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluent-bit-audit-config
  namespace: logging
data:
  fluent-bit.conf: |
    [SERVICE]
        Flush         1
        Log_Level     info

    [INPUT]
        Name              tail
        Path              /var/log/kubernetes/audit/audit.log
        Parser            json
        Tag               kube.audit.*
        Refresh_Interval  5

    [FILTER]
        Name              rewrite_tag
        Match             kube.audit.*
        Rule              $verb ^(create|delete)$ critical.$TAG false
        Rule              $objectRef['resource'] ^secrets$ secrets.$TAG false

    [OUTPUT]
        Name              slack
        Match             critical.*
        Webhook           https://hooks.slack.com/services/xxx/xxx/xxx
        Message           K8s Audit Alert: ${verb} ${objectRef['resource']}

    [OUTPUT]
        Name              es
        Match             *
        Host              elasticsearch
        Port              9200
        Index             k8s-audit
```

---

## Part 6: Compliance Reporting

### 6.1 SOC2 Compliance Report

```bash
#!/bin/bash
# soc2-audit-report.sh

AUDIT_LOG=${1:-/var/log/kubernetes/audit/audit.log}
START_DATE=${2:-$(date -d "30 days ago" +%Y-%m-%d)}
END_DATE=${3:-$(date +%Y-%m-%d)}

echo "=== SOC2 Compliance Audit Report ==="
echo "Period: $START_DATE to $END_DATE"
echo "Generated: $(date)"

echo -e "\n## CC6.1 - Logical and Physical Access Controls"
echo "### User Access Activity"
jq -r 'select(.requestReceivedTimestamp >= "'$START_DATE'" and .requestReceivedTimestamp <= "'$END_DATE'") | .user.username' $AUDIT_LOG | sort | uniq -c | sort -rn | head -20

echo -e "\n### Failed Access Attempts"
jq 'select(.requestReceivedTimestamp >= "'$START_DATE'" and .requestReceivedTimestamp <= "'$END_DATE'" and .responseStatus.code >= 400)' $AUDIT_LOG | wc -l

echo -e "\n## CC6.2 - System Operations"
echo "### Configuration Changes"
jq 'select(.requestReceivedTimestamp >= "'$START_DATE'" and .requestReceivedTimestamp <= "'$END_DATE'" and (.verb == "create" or .verb == "update" or .verb == "delete"))' $AUDIT_LOG | wc -l

echo -e "\n## CC6.7 - Restriction of Access"
echo "### Privileged Access Events (exec/attach)"
jq 'select(.requestReceivedTimestamp >= "'$START_DATE'" and .requestReceivedTimestamp <= "'$END_DATE'" and (.objectRef.subresource == "exec" or .objectRef.subresource == "attach"))' $AUDIT_LOG | wc -l

echo -e "\n### Secret Access Events"
jq 'select(.requestReceivedTimestamp >= "'$START_DATE'" and .requestReceivedTimestamp <= "'$END_DATE'" and .objectRef.resource == "secrets")' $AUDIT_LOG | wc -l
```

---

## Part 7: Hands-on Challenges

### Challenge 1: Custom Audit Policy

Design audit policy for:
1. PCI-DSS compliance
2. HIPAA requirements
3. GDPR data access
4. Custom security requirements

### Challenge 2: Real-Time Alerting

Implement real-time alert system:
1. Stream audit logs
2. Detect anomalies
3. Alert on suspicious activity
4. Track alert metrics

### Challenge 3: Audit Dashboard

Build comprehensive dashboard:
1. User activity heatmap
2. Resource access patterns
3. Failed attempts timeline
4. Compliance metrics

---

## Verification Tasks

1. [ ] Configured audit policy
2. [ ] Enabled audit logging on API server
3. [ ] Set up log aggregation
4. [ ] Created analysis queries
5. [ ] Implemented alerting
6. [ ] Generated compliance report

---

## Key Takeaways

- Audit logging is essential for security compliance
- Balance detail level with storage costs
- Focus on security-relevant events
- Automate analysis and alerting
- Regular compliance reporting
- Retain logs according to policy

---

## Next Steps

Continue to [Exercise 7: Workload Identity](02-security-rbac-exercises-07-workload-identity.md)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Audit Logging Overview
- Audit Policy Configuration
- Enable Audit Logging
- Log Analysis

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"Kubernetes schedules the pod."* |
| ✓ | *"The scheduler watches for pods with no `nodeName`, filters nodes by predicates, scores the survivors, and writes `nodeName` into the pod spec. The kubelet on that node is watching the API for pods bound to it, and starts the containers."* |

**Trace it:** `kubectl apply -f pod.yaml` → a running container. Name every component that acts, in order, and what each one writes.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** [Kubernetes the Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way) — one weekend, and "the control plane" stops being a word.
Full list per domain: [`SOURCES.md`](../../SOURCES.md#kubernetes)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../../MASTERY.md)

<!-- /feynman-check -->
