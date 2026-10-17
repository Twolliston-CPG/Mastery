# Lab 08: Incident Management

## Overview
Implement comprehensive incident management practices including detection, response, communication, and post-incident learning.

## Prerequisites
- Completed Labs 01-07
- Alertmanager configured
- Understanding of on-call practices
- Slack or Discord for communication (optional)

## Learning Objectives
- Implement incident detection and classification
- Create runbooks for common scenarios
- Build incident response automation
- Conduct effective post-mortems
- Design on-call rotations

## Lab Environment

Extends previous environment with incident management tools:

```yaml
services:
  # Incident bot (mock implementation)
  incident-bot:
    build: ./incident-bot
    environment:
      - ALERTMANAGER_URL=http://alertmanager:9093
      - SLACK_WEBHOOK_URL=${SLACK_WEBHOOK_URL:-}
    ports:
      - "8090:8090"

  # Runbook automation
  runbook-runner:
    build: ./runbook-runner
    volumes:
      - ./runbooks:/runbooks
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - PROMETHEUS_URL=http://prometheus:9090
```

---

## Part 1: Guided Exercises

### Exercise 1.1: Incident Detection and Classification

**Objective:** Create a structured approach to incident detection and severity classification.

**Step 1:** Define severity levels.

```yaml
# incident-classification.yml
severity_levels:
  SEV1:
    name: "Critical"
    description: "Complete service outage or major security incident"
    response_time: "15 minutes"
    update_frequency: "30 minutes"
    escalation_time: "30 minutes"
    examples:
      - "Production database unavailable"
      - "Payment processing completely down"
      - "Security breach detected"
      - "Data loss or corruption"
    notifications:
      - on_call_primary
      - on_call_secondary
      - engineering_manager
      - vp_engineering
    communication_channel: "#incident-war-room"

  SEV2:
    name: "High"
    description: "Significant feature degradation affecting many users"
    response_time: "30 minutes"
    update_frequency: "1 hour"
    escalation_time: "2 hours"
    examples:
      - "API latency severely degraded"
      - "Login failures for subset of users"
      - "Search functionality broken"
    notifications:
      - on_call_primary
      - team_lead
    communication_channel: "#incidents"

  SEV3:
    name: "Medium"
    description: "Minor feature degradation or limited impact"
    response_time: "4 hours"
    update_frequency: "4 hours"
    escalation_time: "24 hours"
    examples:
      - "Minor UI bugs affecting usability"
      - "Non-critical background job failures"
      - "Performance degradation for specific endpoints"
    notifications:
      - on_call_primary
    communication_channel: "#incidents"

  SEV4:
    name: "Low"
    description: "Cosmetic issues or minimal impact"
    response_time: "24 hours"
    update_frequency: "Daily"
    escalation_time: "1 week"
    examples:
      - "Typo in error message"
      - "Minor styling issues"
      - "Non-critical logging errors"
    notifications:
      - team_channel
    communication_channel: "#ops-low-priority"
```

**Step 2:** Create alert-to-severity mapping in Alertmanager.

```yaml
# alertmanager/alertmanager.yml
route:
  receiver: 'default'
  group_by: ['alertname', 'severity', 'service']
  routes:
    # SEV1 - Critical
    - match:
        severity: critical
      receiver: 'sev1-pager'
      group_wait: 10s
      repeat_interval: 5m
      routes:
        - match:
            category: security
          receiver: 'security-sev1'

    # SEV2 - High
    - match:
        severity: warning
        impact: high
      receiver: 'sev2-urgent'
      group_wait: 30s

    # SEV3 - Medium
    - match:
        severity: warning
      receiver: 'sev3-normal'
      group_wait: 1m

receivers:
  - name: 'default'
    webhook_configs:
      - url: 'http://incident-bot:8090/webhook/default'

  - name: 'sev1-pager'
    webhook_configs:
      - url: 'http://incident-bot:8090/webhook/sev1'
    pagerduty_configs:
      - service_key: '${PAGERDUTY_SERVICE_KEY}'
        severity: critical

  - name: 'sev2-urgent'
    webhook_configs:
      - url: 'http://incident-bot:8090/webhook/sev2'
    slack_configs:
      - api_url: '${SLACK_WEBHOOK_URL}'
        channel: '#incidents'

  - name: 'sev3-normal'
    webhook_configs:
      - url: 'http://incident-bot:8090/webhook/sev3'
```

**Step 3:** Create incident detection rules.

```yaml
# prometheus/rules/incident_detection.yml
groups:
  - name: incident_detection
    rules:
      # SEV1: Complete outage detection
      - alert: ServiceCompleteOutage
        expr: |
          up{job=~"api|webapp|payments"} == 0
        for: 2m
        labels:
          severity: critical
          incident_type: outage
          auto_incident: "true"
        annotations:
          summary: "{{ $labels.job }} is completely down"
          impact: "Service {{ $labels.job }} is unavailable"
          runbook: "https://runbooks.example.com/{{ $labels.job }}-down"

      # SEV1: Error budget exhausted
      - alert: ErrorBudgetExhausted
        expr: slo:api_availability:error_budget_remaining < 0
        for: 5m
        labels:
          severity: critical
          incident_type: slo_breach
          auto_incident: "true"

      # SEV2: High error rate
      - alert: HighErrorRate
        expr: |
          sum(rate(api_requests_total{status=~"5.."}[5m]))
          /
          sum(rate(api_requests_total[5m]))
          > 0.10
        for: 5m
        labels:
          severity: warning
          impact: high
          incident_type: degradation

      # SEV2: Severe latency degradation
      - alert: SevereLatencyDegradation
        expr: |
          histogram_quantile(0.99,
            sum by (le) (rate(api_request_duration_seconds_bucket[5m]))
          ) > 5
        for: 5m
        labels:
          severity: warning
          impact: high
          incident_type: performance
```

**Verification:**
- [ ] Severity levels documented
- [ ] Alert routing configured
- [ ] Detection rules loaded

---

### Exercise 1.2: Runbook Implementation

**Objective:** Create actionable runbooks for common incidents.

**Step 1:** Create runbook template.

````markdown
# runbooks/template.md

# Runbook: [INCIDENT_TYPE]

## Overview
Brief description of what this runbook addresses.

## Symptoms
- [ ] Symptom 1
- [ ] Symptom 2
- [ ] Symptom 3

## Impact
- **Users affected**: Description
- **Business impact**: Description
- **Systems affected**: List of systems

## Severity Assessment
| Condition | Severity |
|-----------|----------|
| Condition A | SEV1 |
| Condition B | SEV2 |
| Condition C | SEV3 |

## Quick Diagnosis
```bash
# Commands to quickly assess the situation
```

## Resolution Steps

### Step 1: Initial Assessment
1. Action 1
2. Action 2

### Step 2: Mitigation
1. Action 1
2. Action 2

### Step 3: Resolution
1. Action 1
2. Action 2

## Rollback Procedure
Steps to rollback if resolution fails.

## Post-Resolution
- [ ] Verify service recovery
- [ ] Update status page
- [ ] Notify stakeholders

## Escalation
| Time | Action |
|------|--------|
| +15m | Escalate to team lead |
| +30m | Escalate to engineering manager |
| +1h  | Executive notification |

## Related Alerts
- AlertName1
- AlertName2

## History
| Date | Description | Outcome |
|------|-------------|---------|
| YYYY-MM-DD | Incident description | Resolved in Xm |
````

**Step 2:** Create API service runbook.

````markdown
# runbooks/api-high-error-rate.md

# Runbook: API High Error Rate

## Overview
This runbook addresses situations where the API service experiences elevated error rates (>5% 5xx responses).

## Symptoms
- [ ] Alertmanager firing `HighErrorRate` alert
- [ ] Grafana dashboard showing elevated 5xx responses
- [ ] Customer reports of failures
- [ ] Error budget burn rate elevated

## Impact
- **Users affected**: All users making API requests
- **Business impact**: Failed transactions, poor user experience
- **Systems affected**: API Gateway, Backend Services, Database

## Quick Diagnosis

```bash
# Check current error rate
curl -s 'http://prometheus:9090/api/v1/query?query=sum(rate(api_requests_total{status=~"5.."}[5m]))/sum(rate(api_requests_total[5m]))' | jq

# Check pod status
kubectl get pods -n production -l app=api

# Check recent deployments
kubectl rollout history deployment/api -n production

# Check resource usage
kubectl top pods -n production -l app=api

# Check recent logs
kubectl logs -n production -l app=api --tail=100 | grep -i error
```

## Resolution Steps

### Step 1: Identify Error Source

1. Open Grafana dashboard: http://grafana:3000/d/api-errors
2. Check error breakdown by:
   - Endpoint
   - Error code
   - Upstream service
3. Identify if errors are:
   - [ ] Specific to one endpoint
   - [ ] Distributed across all endpoints
   - [ ] Coming from upstream dependency

### Step 2: Check Dependencies

```bash
# Check database connectivity
kubectl exec -n production deploy/api -- nc -zv postgres 5432

# Check Redis connectivity
kubectl exec -n production deploy/api -- nc -zv redis 6379

# Check downstream services
for svc in orders payments inventory; do
  kubectl exec -n production deploy/api -- curl -s http://$svc:8080/health
done
```

### Step 3: Apply Mitigation

**If database issues:**
```bash
# Restart database connections
kubectl rollout restart deployment/api -n production
```

**If specific endpoint:**
```bash
# Enable circuit breaker for failing endpoint
kubectl patch configmap api-config -n production \
  --patch '{"data":{"CIRCUIT_BREAKER_ENABLED":"true"}}'
kubectl rollout restart deployment/api -n production
```

**If recent deployment:**
```bash
# Rollback to previous version
kubectl rollout undo deployment/api -n production
```

### Step 4: Verify Recovery

```bash
# Monitor error rate
watch -n 5 'curl -s "http://prometheus:9090/api/v1/query?query=sum(rate(api_requests_total{status=~\"5..\"}[1m]))/sum(rate(api_requests_total[1m]))" | jq ".data.result[0].value[1]"'

# Verify pods are healthy
kubectl get pods -n production -l app=api -w
```

## Escalation
| Time | Action |
|------|--------|
| +15m | Page secondary on-call |
| +30m | Notify engineering manager |
| +60m | Consider customer communication |

## Related Alerts
- HighErrorRate
- APIServiceDown
- DatabaseConnectionErrors
````

**Step 3:** Create automated runbook runner.

```python
# runbook-runner/runner.py
import yaml
import subprocess
import requests
from datetime import datetime

class RunbookRunner:
    def __init__(self, prometheus_url: str):
        self.prometheus_url = prometheus_url
        self.execution_log = []

    def log(self, message: str):
        timestamp = datetime.now().isoformat()
        entry = f"[{timestamp}] {message}"
        self.execution_log.append(entry)
        print(entry)

    def query_prometheus(self, query: str) -> dict:
        """Execute a Prometheus query."""
        response = requests.get(
            f"{self.prometheus_url}/api/v1/query",
            params={"query": query}
        )
        return response.json()

    def run_command(self, command: str, timeout: int = 30) -> tuple:
        """Execute a shell command."""
        try:
            result = subprocess.run(
                command,
                shell=True,
                capture_output=True,
                text=True,
                timeout=timeout
            )
            return result.returncode, result.stdout, result.stderr
        except subprocess.TimeoutExpired:
            return -1, "", "Command timed out"

    def execute_runbook(self, runbook_path: str, context: dict = None):
        """Execute an automated runbook."""
        with open(runbook_path, 'r') as f:
            runbook = yaml.safe_load(f)

        self.log(f"Starting runbook: {runbook['name']}")
        self.log(f"Description: {runbook['description']}")

        results = {
            "runbook": runbook['name'],
            "started_at": datetime.now().isoformat(),
            "steps": [],
            "success": True
        }

        for step in runbook['steps']:
            self.log(f"Executing step: {step['name']}")

            step_result = {
                "name": step['name'],
                "status": "pending"
            }

            try:
                if step['type'] == 'query':
                    # Execute Prometheus query
                    result = self.query_prometheus(step['query'])
                    step_result['output'] = result
                    step_result['status'] = 'success'

                elif step['type'] == 'command':
                    # Execute shell command
                    code, stdout, stderr = self.run_command(step['command'])
                    step_result['exit_code'] = code
                    step_result['stdout'] = stdout
                    step_result['stderr'] = stderr
                    step_result['status'] = 'success' if code == 0 else 'failed'

                elif step['type'] == 'condition':
                    # Evaluate condition
                    result = self.query_prometheus(step['query'])
                    value = float(result['data']['result'][0]['value'][1])

                    if eval(step['condition'].replace('value', str(value))):
                        step_result['status'] = 'condition_met'
                        if 'then' in step:
                            self.log(f"Condition met, executing: {step['then']}")
                    else:
                        step_result['status'] = 'condition_not_met'
                        if 'else' in step:
                            self.log(f"Condition not met, executing: {step['else']}")

                elif step['type'] == 'wait':
                    import time
                    time.sleep(step['seconds'])
                    step_result['status'] = 'success'

            except Exception as e:
                step_result['status'] = 'error'
                step_result['error'] = str(e)
                results['success'] = False

            results['steps'].append(step_result)
            self.log(f"Step result: {step_result['status']}")

        results['completed_at'] = datetime.now().isoformat()
        results['log'] = self.execution_log
        return results

# Example automated runbook YAML
example_runbook = """
name: API High Error Rate Diagnosis
description: Automated diagnosis for high API error rates

steps:
  - name: Check current error rate
    type: query
    query: sum(rate(api_requests_total{status=~"5.."}[5m]))/sum(rate(api_requests_total[5m]))

  - name: Check if database is the cause
    type: condition
    query: sum(rate(database_errors_total[5m]))
    condition: value > 10
    then: escalate_to_dba
    else: continue

  - name: Check pod health
    type: command
    command: kubectl get pods -n production -l app=api -o json

  - name: Get recent logs
    type: command
    command: kubectl logs -n production -l app=api --tail=50 --since=5m

  - name: Wait for metrics to settle
    type: wait
    seconds: 30

  - name: Recheck error rate
    type: query
    query: sum(rate(api_requests_total{status=~"5.."}[1m]))/sum(rate(api_requests_total[1m]))
"""
```

**Verification:**
- [ ] Runbook template created
- [ ] Specific runbooks documented
- [ ] Automated runner working

---

### Exercise 1.3: Incident Communication

**Objective:** Implement effective incident communication workflows.

**Step 1:** Create incident bot.

```python
# incident-bot/bot.py
from flask import Flask, request, jsonify
from datetime import datetime
import requests
import uuid

app = Flask(__name__)

# In-memory incident storage
incidents = {}

class Incident:
    def __init__(self, alert_data: dict):
        self.id = str(uuid.uuid4())[:8]
        self.created_at = datetime.now()
        self.status = "open"
        self.severity = alert_data.get('labels', {}).get('severity', 'unknown')
        self.title = alert_data.get('labels', {}).get('alertname', 'Unknown Incident')
        self.description = alert_data.get('annotations', {}).get('description', '')
        self.service = alert_data.get('labels', {}).get('service', 'unknown')
        self.timeline = []
        self.commander = None
        self.updates = []

    def to_dict(self):
        return {
            "id": self.id,
            "created_at": self.created_at.isoformat(),
            "status": self.status,
            "severity": self.severity,
            "title": self.title,
            "description": self.description,
            "service": self.service,
            "commander": self.commander,
            "timeline": self.timeline,
            "updates": self.updates
        }

    def add_timeline_event(self, event: str):
        self.timeline.append({
            "timestamp": datetime.now().isoformat(),
            "event": event
        })

def send_slack_message(channel: str, message: str, blocks: list = None):
    """Send message to Slack."""
    webhook_url = app.config.get('SLACK_WEBHOOK_URL')
    if not webhook_url:
        print(f"[Slack] Would send to {channel}: {message}")
        return

    payload = {"channel": channel, "text": message}
    if blocks:
        payload["blocks"] = blocks

    requests.post(webhook_url, json=payload)

def format_incident_message(incident: Incident) -> dict:
    """Format incident for Slack."""
    severity_emoji = {
        "critical": "🔴",
        "warning": "🟡",
        "info": "🔵"
    }
    emoji = severity_emoji.get(incident.severity, "⚪")

    blocks = [
        {
            "type": "header",
            "text": {
                "type": "plain_text",
                "text": f"{emoji} Incident #{incident.id}: {incident.title}"
            }
        },
        {
            "type": "section",
            "fields": [
                {"type": "mrkdwn", "text": f"*Severity:*\n{incident.severity.upper()}"},
                {"type": "mrkdwn", "text": f"*Status:*\n{incident.status}"},
                {"type": "mrkdwn", "text": f"*Service:*\n{incident.service}"},
                {"type": "mrkdwn", "text": f"*Created:*\n{incident.created_at.strftime('%H:%M:%S')}"}
            ]
        },
        {
            "type": "section",
            "text": {"type": "mrkdwn", "text": f"*Description:*\n{incident.description}"}
        },
        {
            "type": "actions",
            "elements": [
                {
                    "type": "button",
                    "text": {"type": "plain_text", "text": "Acknowledge"},
                    "action_id": f"ack_{incident.id}",
                    "style": "primary"
                },
                {
                    "type": "button",
                    "text": {"type": "plain_text", "text": "View Runbook"},
                    "url": f"https://runbooks.example.com/{incident.service}"
                }
            ]
        }
    ]

    return {"text": f"Incident #{incident.id}: {incident.title}", "blocks": blocks}

@app.route('/webhook/<severity>', methods=['POST'])
def handle_webhook(severity):
    """Handle incoming alerts from Alertmanager."""
    data = request.json
    alerts = data.get('alerts', [])

    for alert in alerts:
        if alert.get('status') == 'firing':
            # Create new incident
            incident = Incident(alert)
            incidents[incident.id] = incident
            incident.add_timeline_event(f"Incident created from alert {alert.get('labels', {}).get('alertname')}")

            # Send notification
            channel = "#incidents" if severity != "sev1" else "#incident-war-room"
            message = format_incident_message(incident)
            send_slack_message(channel, message['text'], message['blocks'])

            print(f"Created incident {incident.id} with severity {severity}")

        elif alert.get('status') == 'resolved':
            # Find and resolve matching incident
            alertname = alert.get('labels', {}).get('alertname')
            for inc_id, inc in incidents.items():
                if inc.title == alertname and inc.status == 'open':
                    inc.status = 'resolved'
                    inc.add_timeline_event("Alert resolved, incident auto-closed")
                    send_slack_message("#incidents", f"✅ Incident #{inc.id} resolved")

    return jsonify({"status": "ok"})

@app.route('/incidents', methods=['GET'])
def list_incidents():
    """List all incidents."""
    return jsonify([inc.to_dict() for inc in incidents.values()])

@app.route('/incidents/<incident_id>', methods=['GET', 'PATCH'])
def get_or_update_incident(incident_id):
    """Get or update a specific incident."""
    if incident_id not in incidents:
        return jsonify({"error": "Incident not found"}), 404

    incident = incidents[incident_id]

    if request.method == 'PATCH':
        data = request.json
        if 'status' in data:
            incident.status = data['status']
            incident.add_timeline_event(f"Status changed to {data['status']}")
        if 'commander' in data:
            incident.commander = data['commander']
            incident.add_timeline_event(f"Incident commander set to {data['commander']}")
        if 'update' in data:
            incident.updates.append({
                "timestamp": datetime.now().isoformat(),
                "message": data['update']
            })
            incident.add_timeline_event(f"Update posted: {data['update'][:50]}...")

    return jsonify(incident.to_dict())

@app.route('/incidents/<incident_id>/timeline', methods=['POST'])
def add_timeline_event(incident_id):
    """Add event to incident timeline."""
    if incident_id not in incidents:
        return jsonify({"error": "Incident not found"}), 404

    data = request.json
    incidents[incident_id].add_timeline_event(data.get('event', ''))
    return jsonify({"status": "ok"})

if __name__ == '__main__':
    import os
    app.config['SLACK_WEBHOOK_URL'] = os.getenv('SLACK_WEBHOOK_URL')
    app.run(host='0.0.0.0', port=8090)
```

**Step 2:** Create status page update integration.

```python
# incident-bot/statuspage.py
class StatusPageUpdater:
    """Integration with status page (e.g., Statuspage.io, Cachet)."""

    def __init__(self, api_key: str, page_id: str):
        self.api_key = api_key
        self.page_id = page_id
        self.base_url = f"https://api.statuspage.io/v1/pages/{page_id}"

    def create_incident(self, name: str, status: str, body: str, components: list = None):
        """Create a new status page incident."""
        payload = {
            "incident": {
                "name": name,
                "status": status,  # investigating, identified, monitoring, resolved
                "body": body,
                "component_ids": components or []
            }
        }
        # POST to status page API
        return payload

    def update_incident(self, incident_id: str, status: str, body: str):
        """Update an existing incident."""
        payload = {
            "incident": {
                "status": status,
                "body": body
            }
        }
        return payload

    def get_status_template(self, phase: str, incident_type: str) -> str:
        """Get status update template."""
        templates = {
            "investigating": {
                "outage": "We are currently investigating reports of {service} being unavailable. We will provide an update within 30 minutes.",
                "degradation": "We are investigating reports of degraded performance for {service}. Our team is actively looking into the issue."
            },
            "identified": {
                "outage": "We have identified the cause of the {service} outage. Our team is working on a fix. ETA: {eta}",
                "degradation": "The issue affecting {service} has been identified as {cause}. We are implementing a fix."
            },
            "monitoring": {
                "default": "A fix has been implemented and we are monitoring the results. {service} should be returning to normal operation."
            },
            "resolved": {
                "default": "This incident has been resolved. {service} is now operating normally. We apologize for any inconvenience."
            }
        }
        return templates.get(phase, {}).get(incident_type, templates.get(phase, {}).get("default", ""))
```

**Verification:**
- [ ] Incident bot receiving alerts
- [ ] Slack notifications working
- [ ] Status page integration configured

---

### Exercise 1.4: Post-Incident Review

**Objective:** Create a structured post-incident review process.

**Step 1:** Create post-mortem template.

```markdown
# Post-Incident Review: [INCIDENT_ID]

## Incident Summary
| Field | Value |
|-------|-------|
| Incident ID | INC-XXXX |
| Date | YYYY-MM-DD |
| Duration | X hours Y minutes |
| Severity | SEV1/SEV2/SEV3 |
| Incident Commander | Name |
| Services Affected | Service1, Service2 |

## Timeline
| Time (UTC) | Event |
|------------|-------|
| HH:MM | Alert fired |
| HH:MM | Incident declared |
| HH:MM | First responder engaged |
| HH:MM | Root cause identified |
| HH:MM | Fix deployed |
| HH:MM | Service restored |
| HH:MM | Incident resolved |

## Impact
### Customer Impact
- Number of users affected: X
- Revenue impact: $X (if applicable)
- Customer tickets: X

### Technical Impact
- Requests failed: X
- Error rate peak: X%
- Data affected: Description

## Root Cause Analysis

### What Happened
Detailed description of what occurred.

### Why It Happened
Analysis of the underlying causes.

### 5 Whys Analysis
1. Why did [immediate cause] happen?
   → Because [reason 1]
2. Why did [reason 1] happen?
   → Because [reason 2]
3. Why did [reason 2] happen?
   → Because [reason 3]
4. Why did [reason 3] happen?
   → Because [reason 4]
5. Why did [reason 4] happen?
   → Because [root cause]

## Contributing Factors
- [ ] Human error
- [ ] Code bug
- [ ] Configuration error
- [ ] Insufficient monitoring
- [ ] Capacity issue
- [ ] Dependency failure
- [ ] Security incident
- [ ] Other: _____

## What Went Well
- Item 1
- Item 2
- Item 3

## What Went Poorly
- Item 1
- Item 2
- Item 3

## Where We Got Lucky
- Item 1
- Item 2

## Action Items
| ID | Action | Owner | Priority | Due Date | Status |
|----|--------|-------|----------|----------|--------|
| 1 | Action description | @person | P1 | YYYY-MM-DD | Open |
| 2 | Action description | @person | P2 | YYYY-MM-DD | Open |

## Lessons Learned
Key takeaways for the team.

## Prevention Measures
How we will prevent this from happening again.

## Detection Improvements
How we will detect this faster in the future.

## Response Improvements
How we will respond better next time.

---
**Review Date**: YYYY-MM-DD
**Attendees**: Names
**Next Review**: YYYY-MM-DD (if follow-up needed)
```

**Step 2:** Create post-mortem automation.

```python
# postmortem_generator.py
import requests
from datetime import datetime
import json

class PostMortemGenerator:
    def __init__(self, prometheus_url: str, incident_bot_url: str):
        self.prometheus_url = prometheus_url
        self.incident_bot_url = incident_bot_url

    def get_incident_data(self, incident_id: str) -> dict:
        """Fetch incident data from incident bot."""
        response = requests.get(f"{self.incident_bot_url}/incidents/{incident_id}")
        return response.json()

    def get_metrics_during_incident(self, start_time: str, end_time: str) -> dict:
        """Fetch relevant metrics during incident window."""
        queries = {
            "error_rate": 'sum(rate(api_requests_total{status=~"5.."}[5m]))/sum(rate(api_requests_total[5m]))',
            "latency_p99": 'histogram_quantile(0.99, sum by (le) (rate(api_request_duration_seconds_bucket[5m])))',
            "request_rate": 'sum(rate(api_requests_total[5m]))',
        }

        results = {}
        for name, query in queries.items():
            response = requests.get(
                f"{self.prometheus_url}/api/v1/query_range",
                params={
                    "query": query,
                    "start": start_time,
                    "end": end_time,
                    "step": "1m"
                }
            )
            results[name] = response.json()

        return results

    def calculate_impact(self, metrics: dict) -> dict:
        """Calculate incident impact from metrics."""
        error_rates = [
            float(v[1]) for v in metrics.get('error_rate', {}).get('data', {}).get('result', [{}])[0].get('values', [])
        ]

        return {
            "peak_error_rate": f"{max(error_rates) * 100:.2f}%" if error_rates else "N/A",
            "avg_error_rate": f"{sum(error_rates)/len(error_rates) * 100:.2f}%" if error_rates else "N/A",
        }

    def generate_postmortem(self, incident_id: str) -> str:
        """Generate a post-mortem document."""
        incident = self.get_incident_data(incident_id)

        # Calculate duration
        created = datetime.fromisoformat(incident['created_at'])
        resolved = datetime.fromisoformat(incident.get('resolved_at', datetime.now().isoformat()))
        duration = resolved - created

        # Get metrics
        metrics = self.get_metrics_during_incident(
            incident['created_at'],
            incident.get('resolved_at', datetime.now().isoformat())
        )
        impact = self.calculate_impact(metrics)

        # Generate document
        postmortem = f"""# Post-Incident Review: {incident_id}

## Incident Summary
| Field | Value |
|-------|-------|
| Incident ID | {incident_id} |
| Date | {created.strftime('%Y-%m-%d')} |
| Duration | {duration} |
| Severity | {incident['severity']} |
| Incident Commander | {incident.get('commander', 'Not assigned')} |
| Services Affected | {incident['service']} |

## Timeline
"""
        for event in incident.get('timeline', []):
            postmortem += f"| {event['timestamp']} | {event['event']} |\n"

        postmortem += f"""
## Impact
- Peak error rate: {impact['peak_error_rate']}
- Average error rate: {impact['avg_error_rate']}

## Root Cause Analysis
*To be completed by incident responders*

## Action Items
| ID | Action | Owner | Priority | Due Date | Status |
|----|--------|-------|----------|----------|--------|
| 1 | Complete root cause analysis | TBD | P1 | TBD | Open |
| 2 | Add additional monitoring | TBD | P2 | TBD | Open |

---
Generated: {datetime.now().isoformat()}
"""
        return postmortem
```

**Verification:**
- [ ] Post-mortem template in use
- [ ] Automation generates initial draft
- [ ] Action items tracked

---

### Exercise 1.5: On-Call Management

**Objective:** Design effective on-call rotations and handoffs.

**Step 1:** Define on-call structure.

```yaml
# oncall-config.yml
teams:
  platform:
    name: "Platform Team"
    escalation_timeout: 15m
    rotations:
      - name: "primary"
        schedule: "weekly"
        handoff_day: "monday"
        handoff_time: "09:00"
        members:
          - name: "Alice"
            email: "alice@example.com"
            phone: "+1234567890"
          - name: "Bob"
            email: "bob@example.com"
            phone: "+1234567891"
          - name: "Charlie"
            email: "charlie@example.com"
            phone: "+1234567892"

      - name: "secondary"
        schedule: "weekly"
        handoff_day: "monday"
        handoff_time: "09:00"
        members:
          - name: "Dave"
          - name: "Eve"
          - name: "Frank"

    escalation_policy:
      - level: 1
        targets: ["primary"]
        timeout: 15m
      - level: 2
        targets: ["secondary"]
        timeout: 15m
      - level: 3
        targets: ["engineering_manager"]
        timeout: 30m

handoff_checklist:
  - "Review active incidents"
  - "Check error budget status"
  - "Review recent deployments"
  - "Check scheduled maintenance"
  - "Verify alerting is working"
  - "Update contact information"
```

**Step 2:** Create handoff automation.

```python
# oncall_handoff.py
from datetime import datetime
import yaml

def generate_handoff_report(prometheus_url: str) -> dict:
    """Generate on-call handoff report."""
    import requests

    report = {
        "generated_at": datetime.now().isoformat(),
        "sections": {}
    }

    # Active alerts
    alerts_response = requests.get(f"{prometheus_url}/api/v1/alerts")
    alerts = alerts_response.json().get('data', {}).get('alerts', [])
    report["sections"]["active_alerts"] = [
        {
            "name": a.get('labels', {}).get('alertname'),
            "severity": a.get('labels', {}).get('severity'),
            "since": a.get('activeAt')
        }
        for a in alerts if a.get('state') == 'firing'
    ]

    # Error budget status
    budget_query = 'slo:api_availability:error_budget_remaining * 100'
    budget_response = requests.get(
        f"{prometheus_url}/api/v1/query",
        params={"query": budget_query}
    )
    budget_result = budget_response.json().get('data', {}).get('result', [])
    if budget_result:
        report["sections"]["error_budget"] = {
            "remaining": f"{float(budget_result[0]['value'][1]):.1f}%"
        }

    # Recent incidents (last 7 days)
    report["sections"]["recent_incidents"] = []  # Would fetch from incident system

    # System health
    health_queries = {
        "api_availability": "sli:api_availability:ratio * 100",
        "api_latency_p99": "histogram_quantile(0.99, sum by (le) (rate(api_request_duration_seconds_bucket[1h])))",
    }
    report["sections"]["system_health"] = {}
    for name, query in health_queries.items():
        response = requests.get(
            f"{prometheus_url}/api/v1/query",
            params={"query": query}
        )
        result = response.json().get('data', {}).get('result', [])
        if result:
            report["sections"]["system_health"][name] = result[0]['value'][1]

    return report

def format_handoff_message(report: dict) -> str:
    """Format handoff report for Slack."""
    message = f"""
📋 *On-Call Handoff Report*
Generated: {report['generated_at']}

*Active Alerts ({len(report['sections']['active_alerts'])})*
"""
    for alert in report['sections']['active_alerts']:
        message += f"• {alert['severity'].upper()}: {alert['name']} (since {alert['since']})\n"

    if not report['sections']['active_alerts']:
        message += "• No active alerts ✅\n"

    message += f"""
*Error Budget*
• Remaining: {report['sections'].get('error_budget', {}).get('remaining', 'N/A')}

*System Health*
"""
    for metric, value in report['sections'].get('system_health', {}).items():
        message += f"• {metric}: {value}\n"

    message += """
*Handoff Checklist*
☐ Reviewed active incidents
☐ Checked error budget status
☐ Reviewed recent deployments
☐ Checked scheduled maintenance
☐ Verified alerting is working
"""
    return message

if __name__ == "__main__":
    report = generate_handoff_report("http://localhost:9090")
    print(format_handoff_message(report))
```

**Verification:**
- [ ] On-call schedule defined
- [ ] Escalation policy configured
- [ ] Handoff automation working

---

## Part 2: Semi-Guided Exercises

### Exercise 2.1: Incident Response Automation

**Requirements:**
1. Auto-create incident from critical alerts
2. Auto-assign based on service ownership
3. Auto-escalate based on response time
4. Auto-resolve when alert clears

---

### Exercise 2.2: War Room Coordination

**Requirements:**
1. Auto-create dedicated Slack channel for SEV1
2. Invite relevant responders
3. Pin incident details and runbook
4. Track action items in thread

---

### Exercise 2.3: Customer Communication

**Requirements:**
1. Integrate with status page
2. Template-based updates
3. Auto-update on resolution
4. Track customer notifications

---

### Exercise 2.4: Incident Metrics

**Requirements:**
1. Track MTTD (Mean Time to Detect)
2. Track MTTR (Mean Time to Resolve)
3. Track incident frequency
4. Create incident analytics dashboard

---

## Part 3: Challenge Exercises

### Challenge 3.1: AI-Assisted Incident Response

**Objective:** Build intelligent incident assistance.

**Requirements:**
1. Similar incident detection
2. Suggested runbooks
3. Auto-diagnosis
4. Resolution recommendations

---

### Challenge 3.2: Chaos Incident Drills

**Objective:** Regular incident simulation exercises.

**Requirements:**
1. Scheduled chaos experiments
2. Simulated incident workflow
3. Response time measurement
4. Improvement tracking

---

### Challenge 3.3: Cross-Team Incident Coordination

**Objective:** Multi-team incident management.

**Requirements:**
1. Cross-team communication
2. Shared timeline
3. Coordinated response
4. Joint post-mortems

---

## Cleanup

```bash
docker-compose down
rm -rf incident-bot runbook-runner runbooks
```

## Additional Resources

- [Google SRE Book - Incident Management](https://sre.google/sre-book/managing-incidents/)
- [PagerDuty Incident Response](https://response.pagerduty.com/)
- [Post-Mortem Culture](https://sre.google/sre-book/postmortem-culture/)

## Next Lab
Continue to [Lab 09: Chaos Engineering](labs-lab-09-chaos-engineering-README.md) to implement chaos experiments.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Symptoms
- Impact
- Severity Assessment
- Quick Diagnosis

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"Prometheus monitors the service."* |
| ✓ | *"Prometheus discovers targets from the Kubernetes API, applies relabelling rules, scrapes `/metrics` over HTTP on an interval, and appends samples to a local TSDB. Nothing is pushed — so a target missing from a dashboard is a service-discovery problem, not an application one."* |

**Trace it:** A latency regression → a phone ringing. Name each hop: sample, rule evaluation, alert state transition, routing, notification — and where each one can silently stop.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** [SRE Workbook ch. 5, *Alerting on SLOs*](https://sre.google/workbook/alerting-on-slos/) — free, and the best thing written on why static thresholds page you for nothing.
Full list per domain: [`SOURCES.md`](../SOURCES.md#observability-sre)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../MASTERY.md)

<!-- /feynman-check -->
