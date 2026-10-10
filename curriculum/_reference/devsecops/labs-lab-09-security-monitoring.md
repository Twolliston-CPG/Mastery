# Lab 9: Security Monitoring and SIEM

## Objectives

- Deploy Elastic Security stack for SIEM
- Configure security detection rules
- Create security dashboards
- Implement automated alerting and response

## Prerequisites

- Kubernetes cluster with 16GB+ RAM
- Helm installed
- Basic Elasticsearch knowledge

## Duration

3 hours

## Part 1: Elastic Security Deployment (60 minutes)

### Task 1.1: Deploy Elasticsearch

```bash
# Add Elastic Helm repo
helm repo add elastic https://helm.elastic.co
helm repo update

# Create namespace
kubectl create namespace elastic

# Deploy Elasticsearch
helm install elasticsearch elastic/elasticsearch \
  --namespace elastic \
  --set replicas=3 \
  --set resources.requests.memory=2Gi \
  --set resources.limits.memory=4Gi \
  --set volumeClaimTemplate.resources.requests.storage=50Gi

# Wait for deployment
kubectl wait --for=condition=ready pod -l app=elasticsearch-master -n elastic --timeout=300s
```

### Task 1.2: Deploy Kibana with Security

```bash
# Deploy Kibana
helm install kibana elastic/kibana \
  --namespace elastic \
  --set service.type=LoadBalancer

# Port forward for access
kubectl port-forward svc/kibana-kibana 5601:5601 -n elastic &
```

### Task 1.3: Deploy Filebeat for Log Collection

```yaml
# filebeat/filebeat-daemonset.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: filebeat-config
  namespace: elastic
data:
  filebeat.yml: |
    filebeat.inputs:
    - type: container
      paths:
        - /var/log/containers/*.log
      processors:
        - add_kubernetes_metadata:
            host: ${NODE_NAME}
            matchers:
            - logs_path:
                logs_path: "/var/log/containers/"

    output.elasticsearch:
      hosts: ['${ELASTICSEARCH_HOST:elasticsearch-master}:${ELASTICSEARCH_PORT:9200}']
      username: ${ELASTICSEARCH_USERNAME}
      password: ${ELASTICSEARCH_PASSWORD}

    setup.kibana:
      host: "kibana-kibana:5601"

    setup.dashboards.enabled: true
    setup.ilm.enabled: auto
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: filebeat
  namespace: elastic
spec:
  selector:
    matchLabels:
      app: filebeat
  template:
    metadata:
      labels:
        app: filebeat
    spec:
      serviceAccountName: filebeat
      containers:
      - name: filebeat
        image: docker.elastic.co/beats/filebeat:8.11.0
        env:
        - name: NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        - name: ELASTICSEARCH_HOST
          value: "elasticsearch-master"
        - name: ELASTICSEARCH_PORT
          value: "9200"
        - name: ELASTICSEARCH_USERNAME
          value: "elastic"
        - name: ELASTICSEARCH_PASSWORD
          valueFrom:
            secretKeyRef:
              name: elasticsearch-master-credentials
              key: password
        volumeMounts:
        - name: config
          mountPath: /usr/share/filebeat/filebeat.yml
          subPath: filebeat.yml
        - name: varlog
          mountPath: /var/log
          readOnly: true
        - name: varlibdockercontainers
          mountPath: /var/lib/docker/containers
          readOnly: true
      volumes:
      - name: config
        configMap:
          name: filebeat-config
      - name: varlog
        hostPath:
          path: /var/log
      - name: varlibdockercontainers
        hostPath:
          path: /var/lib/docker/containers
```

## Part 2: Detection Rules (60 minutes)

### Task 2.1: Create Custom Detection Rules

```json
// Navigate to Kibana > Security > Rules > Create new rule

// Rule 1: Brute Force Detection
{
  "name": "SSH Brute Force Attempt",
  "description": "Detects multiple failed SSH authentication attempts",
  "risk_score": 73,
  "severity": "high",
  "type": "threshold",
  "query": "event.category:authentication AND event.outcome:failure AND process.name:sshd",
  "threshold": {
    "field": ["source.ip"],
    "value": 10
  },
  "index": ["filebeat-*", "logs-*"],
  "interval": "5m",
  "from": "now-5m"
}

// Rule 2: Suspicious Process Execution
{
  "name": "Suspicious Shell Command",
  "description": "Detects potentially malicious shell commands",
  "risk_score": 50,
  "severity": "medium",
  "type": "query",
  "query": "process.command_line:(*curl*|*wget*) AND process.command_line:(*|*bash* OR *|*sh*)",
  "index": ["auditbeat-*", "logs-*"],
  "interval": "5m"
}

// Rule 3: Kubernetes Privilege Escalation
{
  "name": "K8s Privileged Pod Creation",
  "description": "Detects creation of privileged pods",
  "risk_score": 73,
  "severity": "high",
  "type": "query",
  "query": "kubernetes.audit.verb:create AND kubernetes.audit.objectRef.resource:pods AND kubernetes.audit.requestObject:*privileged*true*",
  "index": ["logs-kubernetes*"],
  "interval": "5m"
}
```

### Task 2.2: Import Sigma Rules

```bash
# Install Sigma
pip install sigma-cli

# Convert Sigma rules to Elastic format
sigma convert -t elasticsearch -p ecs_windows rules/windows/*.yml > elastic-rules.ndjson

# Import via API
curl -X POST "localhost:5601/api/detection_engine/rules/_import" \
  -H "kbn-xsrf: true" \
  -H "Content-Type: application/x-ndjson" \
  --data-binary @elastic-rules.ndjson
```

## Part 3: Security Dashboards (45 minutes)

### Task 3.1: Create Security Operations Dashboard

```json
// Kibana Dashboard Configuration
{
  "title": "Security Operations Center",
  "panels": [
    {
      "title": "Security Alerts by Severity",
      "type": "lens",
      "gridData": {"x": 0, "y": 0, "w": 12, "h": 8}
    },
    {
      "title": "Top Attack Sources",
      "type": "maps",
      "gridData": {"x": 12, "y": 0, "w": 12, "h": 8}
    },
    {
      "title": "Authentication Failures Trend",
      "type": "lens",
      "gridData": {"x": 0, "y": 8, "w": 24, "h": 8}
    },
    {
      "title": "Recent Security Events",
      "type": "discover",
      "gridData": {"x": 0, "y": 16, "w": 24, "h": 12}
    }
  ]
}
```

## Part 4: Automated Response (45 minutes)

### Task 4.1: Create Alert Actions

```yaml
# elastic/alert-actions.yaml
# Slack notification for critical alerts
- name: slack-security-alerts
  actionTypeId: .slack
  params:
    message: |
      🚨 Security Alert: {{context.rule.name}}
      Severity: {{context.rule.severity}}
      Risk Score: {{context.rule.risk_score}}
      Details: {{context.alerts[0]._source.message}}

# PagerDuty for critical incidents
- name: pagerduty-critical
  actionTypeId: .pagerduty
  params:
    severity: critical
    eventAction: trigger
    summary: "{{context.rule.name}} - {{context.alerts.length}} alerts"
```

### Task 4.2: Automated Blocking Script

```python
#!/usr/bin/env python3
# security/auto_block.py

import requests
from elasticsearch import Elasticsearch

es = Elasticsearch(['http://elasticsearch:9200'])

def get_brute_force_ips():
    """Get IPs with multiple failed auth attempts."""
    query = {
        "size": 0,
        "query": {
            "bool": {
                "filter": [
                    {"term": {"event.outcome": "failure"}},
                    {"term": {"event.category": "authentication"}},
                    {"range": {"@timestamp": {"gte": "now-1h"}}}
                ]
            }
        },
        "aggs": {
            "ips": {
                "terms": {"field": "source.ip", "min_doc_count": 10}
            }
        }
    }

    result = es.search(index="logs-*", body=query)
    return [bucket['key'] for bucket in result['aggregations']['ips']['buckets']]

def block_ip_in_firewall(ip: str):
    """Block IP using AWS WAF."""
    import boto3
    waf = boto3.client('wafv2')
    # Add IP to block list
    # Implementation depends on WAF configuration

if __name__ == "__main__":
    malicious_ips = get_brute_force_ips()
    for ip in malicious_ips:
        print(f"Blocking IP: {ip}")
        block_ip_in_firewall(ip)
```

## Verification

Complete the following checklist:

- [ ] Deployed Elastic Security stack
- [ ] Configured log collection with Filebeat
- [ ] Created custom detection rules
- [ ] Built security dashboard
- [ ] Set up automated alerting
- [ ] Implemented automated response actions

## Summary

In this lab, you:
- Deployed Elastic Security for SIEM
- Created security detection rules
- Built security operations dashboards
- Implemented automated alerting and response

## Next Steps

- Lab 10: Vulnerability Management
- Review MITRE ATT&CK framework
- Study incident response procedures

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Elastic Security Deployment
- Detection Rules
- Security Dashboards
- Automated Response

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"We scan for vulnerabilities in the pipeline."* |
| ✓ | *"SAST reads source without running it, SCA resolves the dependency tree against an advisory database, and image scanning compares installed package versions to that same database. All three report what was known at build time — which is why the registry is re-scanned: the image does not change, the database does."* |

**Trace it:** A CVE published today against your base image → a blocked deploy. Name every component between the advisory and the refused `apply`.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** the [SLSA threat model](https://slsa.dev/spec/v1.2/threats) — it names every point at which a build can be subverted, and most teams defend three of them.
Full list per domain: [`SOURCES.md`](../SOURCES.md#devsecops)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../MASTERY.md)

<!-- /feynman-check -->
