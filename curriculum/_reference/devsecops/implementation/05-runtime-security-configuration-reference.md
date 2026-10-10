# Domain 5: Runtime Security & Network Security -- Configuration Reference

## Table of Contents

1. [Falco Rules](#1-falco-rules)
2. [KubeArmor Policy Format](#2-kubearmor-policy-format)
3. [Gatekeeper Constraints](#3-gatekeeper-constraints)
4. [Kyverno Policies](#4-kyverno-policies)
5. [Cilium Network Policy Format](#5-cilium-network-policy-format)
6. [Incident Responder Configuration](#6-incident-responder-configuration)
7. [ModSecurity WAF Configuration](#7-modsecurity-waf-configuration)
8. [DLP Configuration](#8-dlp-configuration)
9. [OPA API Authorization](#9-opa-api-authorization)
10. [Pod Security Standards](#10-pod-security-standards)
11. [RBAC Audit Configuration](#11-rbac-audit-configuration)

---

## 1. Falco Rules

### Rule Structure

```yaml
- rule: <Rule Name>
  desc: <Description>
  condition: >
    <Falco condition expression using syscall fields>
  output: >
    <Output template with field interpolation>
  priority: <EMERGENCY|ALERT|CRITICAL|ERROR|WARNING|NOTICE|INFORMATIONAL|DEBUG>
  tags: [<tag1>, <tag2>]
```

### Key Macros

```yaml
# Container check
- macro: container
  condition: container.id != host

# Process spawn detection
- macro: spawned_process
  condition: evt.type = execve and evt.dir = <

# File operations
- macro: open_read
  condition: evt.type = open and evt.is_open_read = true
- macro: open_write
  condition: evt.type = open and evt.is_open_write = true

# Network direction
- macro: inbound
  condition: (fd.type = ipv4 or fd.type = ipv6) and fd.direction = in
- macro: outbound
  condition: (fd.type = ipv4 or fd.type = ipv6) and fd.direction = out
```

### Lists

```yaml
# Allowed processes for application containers
- list: {{APP_NAME}}_api_allowed_processes
  items: [{{APP_NAME}}-api, sh, pause]

# Known crypto mining binaries
- list: crypto_miners
  items: [xmrig, minerd, minergate, cryptonight, stratum, cpuminer, ccminer]

# Known mining pools
- list: mining_pools
  items: [pool.minexmr.com, xmrpool.eu, supportxmr.com, pool.hashvault.pro]

# Binaries used in container escapes
- list: escape_binaries
  items: [nsenter, docker, kubectl, crictl, runc]
```

### Falco Helm Values (Key Settings)

```yaml
driver:
  kind: modern_ebpf          # eBPF driver (NOTE: incompatible with GCP kernel 6.14.0)
falco:
  jsonOutput: true            # JSON format for structured logging
  priority: notice            # Minimum priority to report
  grpc:
    enabled: true             # Enable gRPC for Falcosidekick
    bindAddress: "0.0.0.0:5060"
collectors:
  containerd:
    enabled: true
    socket: /run/containerd/containerd.sock
```

### Falcosidekick Configuration

```yaml
config:
  alertmanager:
    hostport: "http://kube-prometheus-stack-alertmanager.monitoring:9093"
    minimumpriority: "warning"
  slack:
    webhookurl: ""                           # Set via secret
    minimumpriority: "warning"
  webhook:
    address: "http://incident-responder.security:8080/incident"
    minimumpriority: "warning"
    customHeaders:
      X-Source: "falco"
      X-Cluster: "{{APP_NAME}}"
```

---

## 2. KubeArmor Policy Format

### Namespace-Scoped Policy

```yaml
apiVersion: security.kubearmor.com/v1
kind: KubeArmorPolicy
metadata:
  name: <policy-name>
  namespace: {{APP_NAMESPACE}}
spec:
  selector:
    matchLabels:
      app.kubernetes.io/part-of: {{APP_NAME}}

  # File access controls
  file:
    matchPaths:
      - path: /etc/shadow
        action: Block             # Block | Allow | Audit
    matchDirectories:
      - dir: /etc/ssh/
        recursive: true           # Apply to all subdirectories
        action: Block

  # Process execution controls
  process:
    matchPaths:
      - path: /bin/bash
        action: Block
    matchPatterns:
      - pattern: "**/xmr*"
        action: Block

  # Network controls
  network:
    matchProtocols:
      - protocol: raw
        action: Block
      - protocol: icmp
        action: Audit

  # Capability controls
  capabilities:
    matchCapabilities:
      - capability: net_raw
        action: Block
      - capability: sys_admin
        action: Block

  action: Block                   # Default action for the policy
```

### Cluster-Scoped Policy

```yaml
apiVersion: security.kubearmor.com/v1
kind: KubeArmorClusterPolicy
metadata:
  name: <policy-name>
spec:
  selector:
    matchExpressions:
      - key: kubearmor-visibility
        operator: Exists
  # ... same spec as KubeArmorPolicy
```

### Action Types

| Action | Behavior |
|---|---|
| `Block` | Deny the operation and log |
| `Allow` | Permit the operation (used in allow-list mode) |
| `Audit` | Permit but log the operation |

---

## 3. Gatekeeper Constraints

### ConstraintTemplate Structure

```yaml
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8s<constraintname>
spec:
  crd:
    spec:
      names:
        kind: K8s<ConstraintName>
      validation:
        openAPIV3Schema:
          type: object
          properties:
            # Parameter definitions
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8s<constraintname>
        violation[{"msg": msg}] {
          # Rego policy logic
        }
```

### Constraint Structure

```yaml
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8s<ConstraintName>
metadata:
  name: <constraint-name>
spec:
  enforcementAction: deny | dryrun | warn
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
      - apiGroups: ["apps"]
        kinds: ["Deployment", "StatefulSet", "DaemonSet"]
    namespaces:
      - {{APP_NAMESPACE}}
    excludedNamespaces:
      - kube-system
      - gatekeeper-system
  parameters:
    # Constraint-specific parameters
```

### Workload Constraint Summary

| Template | Parameters | Enforcement |
|---|---|---|
| `K8sRequiredLabels` | `labels: [list of required label keys]` | deny |
| `K8sContainerLimits` | `cpu: string, memory: string` | deny |
| `K8sBlockPrivilegedContainer` | `exemptImages: [image prefixes]` | deny |
| `K8sBlockHostNamespace` | (none) | deny |
| `K8sAllowedRepos` | `repos: [allowed registry prefixes]` | deny |
| `K8sBlockNodePort` | (none) | deny |
| `K8sRequireNonRootUser` | `exemptImages: [image prefixes]` | deny |
| `K8sBlockLatest` | (none) | deny |

### Supply Chain Constraint Summary

| Template | Parameters | Enforcement |
|---|---|---|
| `K8sRequireImageDigest` | `exemptImages`, `allowedTagPatterns` | deny |
| `K8sRequireImageSignature` | `trustedIdentities`, `oidcIssuers`, `exemptImages`, `verifierEndpoint` | deny |
| `K8sSLSALevelRequirement` | `minimumLevel` (1-4), `attestationStore`, `trustedBuilders`, `exemptImages` | deny |
| `K8sRequireSBOM` | `sbomFormats` (spdx/cyclonedx), `exemptImages`, `sbomVerifierEndpoint` | deny |
| `K8sImageDenyList` | `images`, `digests`, `reason` | deny |
| `K8sTrustedBuilder` | `trustedBuilders`, `exemptImages`, `attestationStore` | deny |

### Binary Authorization

| Template | Parameters | Enforcement |
|---|---|---|
| `K8sCosignSignature` | `allowedIssuers`, `allowedSubjectPatterns`, `exemptImages`, `exemptNamespaces` | deny |

---

## 4. Kyverno Policies

### ClusterPolicy Structure

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: <policy-name>
  annotations:
    policies.kyverno.io/title: <Title>
    policies.kyverno.io/category: <Category>
    policies.kyverno.io/severity: high | medium | low
    policies.kyverno.io/description: >-
      <Description>
spec:
  validationFailureAction: Enforce | Audit
  background: true
  rules:
    - name: <rule-name>
      match:
        any:
          - resources:
              kinds:
                - Pod
              namespaces:
                - {{APP_NAMESPACE}}
      validate:
        message: "<violation message>"
        # Pattern-based validation
        pattern:
          spec:
            containers:
              - resources:
                  limits:
                    memory: "?*"
        # OR deny-based validation
        deny:
          conditions:
            any:
              - key: "{{ expression }}"
                operator: GreaterThan
                value: 0
```

### Policy Summary

| Policy | Action | Rules |
|---|---|---|
| `disallow-privileged-containers` | Enforce | Block privileged containers, block host namespaces |
| `require-labels` | Audit | Require `app` label on Pods, `app.kubernetes.io/part-of` on Deployments |
| `require-resource-limits` | Audit | Require CPU/memory limits and requests |
| `restrict-image-registries` | Audit | Allow only approved registry prefixes |

---

## 5. Cilium Network Policy Format

### CiliumNetworkPolicy Structure

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: <policy-name>
  namespace: {{APP_NAMESPACE}}
spec:
  endpointSelector:
    matchLabels:
      app.kubernetes.io/name: {{SERVICE_NAME}}

  # Ingress rules (who can talk TO this pod)
  ingress:
    - fromEndpoints:
        - matchLabels:
            app.kubernetes.io/name: api-gateway
      toPorts:
        - ports:
            - port: "3000"
              protocol: TCP
          rules:
            http:                               # L7 HTTP rules
              - method: "GET"
                path: "/api/v1/.*"
              - method: "POST"
                path: "/api/v1/bookings"

  # Egress rules (who this pod can talk TO)
  egress:
    - toEndpoints:
        - matchLabels:
            app.kubernetes.io/name: postgres
      toPorts:
        - ports:
            - port: "5432"
              protocol: TCP
    # Allow DNS resolution
    - toEndpoints:
        - matchLabels:
            k8s:io.kubernetes.pod.namespace: kube-system
            k8s-app: kube-dns
      toPorts:
        - ports:
            - port: "53"
              protocol: UDP
          rules:
            dns:
              - matchPattern: "*.{{APP_NAMESPACE}}.svc.cluster.local"
```

### CiliumClusterwideNetworkPolicy (Default Deny)

```yaml
apiVersion: cilium.io/v2
kind: CiliumClusterwideNetworkPolicy
metadata:
  name: default-deny
spec:
  endpointSelector:
    matchLabels:
      io.kubernetes.pod.namespace: {{APP_NAMESPACE}}
  ingress:
    - {}        # Empty = deny all unless explicitly allowed
  egress:
    - {}
```

---

## 6. Incident Responder Configuration

### Remediation Configuration

```yaml
remediations:
  - name: <incident-type>
    triggers:
      - source: falco | kubearmor | runtime-verifier | gatekeeper | trivy
        event: "<event name>"
        rule: "<rule name>"            # For Falco triggers
        severity: CRITICAL             # For Trivy triggers
    actions:
      - type: block-image             # Add to Gatekeeper deny list
        constraint: blocked-images-security
      - type: quarantine-pod          # Apply NetworkPolicy
        networkPolicy: deny-all | deny-all-egress
      - type: kill-pod                # Delete the pod
      - type: restart-pod             # Restart via rollout restart
      - type: alert                   # Send alert notification
        severity: critical | high | medium | low
      - type: create-ticket           # Create Jira/GitHub ticket
        priority: P0 | P1 | P2 | P3
      - type: collect-forensics       # Capture pod logs, describe, filesystem
      - type: log                     # Log only (no action)
```

### Alerting Configuration

```yaml
alerting:
  slack:
    enabled: true
    channels:
      critical: "{{SLACK_CHANNEL_CRITICAL}}"
      high: "{{SLACK_CHANNEL_ALERTS}}"
      medium: "{{SLACK_CHANNEL_ALERTS}}"
  pagerduty:
    enabled: true
    urgencyMapping:
      critical: high
      high: high
      medium: low
  ticketing:
    provider: "jira"
    jira:
      endpoint: "https://{{ORG_NAME}}.atlassian.net"
      project: "SEC"
      issueType: "Security Incident"
```

### Quarantine Network Policies

```yaml
# Full quarantine (deny all ingress and egress)
quarantine:
  denyAllPolicy:
    spec:
      podSelector:
        matchLabels:
          quarantine: "true"
      policyTypes: [Ingress, Egress]

  # Partial quarantine (deny egress only)
  denyEgressPolicy:
    spec:
      podSelector:
        matchLabels:
          quarantine: "true"
      policyTypes: [Egress]
      egress: []
```

---

## 7. ModSecurity WAF Configuration

### Core Settings

```
SecRuleEngine On                          # Enable rule engine
SecRequestBodyAccess On                   # Inspect request bodies
SecRequestBodyLimit 13107200              # 12.5 MB limit
SecResponseBodyAccess On                  # Inspect response bodies
SecAuditEngine RelevantOnly               # Log only relevant events
SecDefaultAction "phase:1,deny,log,status:403"
```

### OWASP CRS Settings

```
# Paranoia Level (1-4, higher = more strict, more false positives)
setvar:tx.paranoia_level=2

# Anomaly scoring thresholds
setvar:tx.inbound_anomaly_score_threshold=5
setvar:tx.outbound_anomaly_score_threshold=4

# Allowed HTTP methods
setvar:'tx.allowed_methods=GET HEAD POST OPTIONS PUT PATCH DELETE'

# Blocking paranoia level
setvar:tx.blocking_paranoia_level=2
```

### Custom Rule Format

```
SecRule <VARIABLE> "<OPERATOR>" \
  "id:<ID>,\
  phase:<1-5>,\
  <ACTION>,\
  status:<HTTP_STATUS>,\
  log,\
  msg:'<MESSAGE>',\
  severity:<CRITICAL|WARNING|NOTICE>,\
  chain"
  SecRule <CHAINED_VARIABLE> "<CHAINED_OPERATOR>" ""
```

### Rule ID Ranges

| Range | Purpose |
|---|---|
| 9000000-9000099 | API-specific rules |
| 9001000-9001099 | Booking endpoint rules |
| 9002000-9002099 | Financial endpoint rules |
| 9003000-9003099 | Authentication rules |
| 9004000-9004099 | Response filtering rules |
| 9005000-9005099 | Geo-blocking rules |

---

## 8. DLP Configuration

### [GCP-SPECIFIC] Cloud DLP Info Types

```json
{
  "infoTypes": [
    {"name": "PERSON_NAME"},
    {"name": "EMAIL_ADDRESS"},
    {"name": "PHONE_NUMBER"},
    {"name": "CREDIT_CARD_NUMBER"},
    {"name": "US_SOCIAL_SECURITY_NUMBER"},
    {"name": "US_DRIVERS_LICENSE_NUMBER"},
    {"name": "US_BANK_ROUTING_MICR"},
    {"name": "US_BANK_ACCOUNT_NUMBER"},
    {"name": "DATE_OF_BIRTH"},
    {"name": "STREET_ADDRESS"},
    {"name": "IP_ADDRESS"},
    {"name": "PASSPORT"}
  ]
}
```

### Presidio Custom Recognizers

```yaml
recognizers:
  - name: <RecognizerName>
    supported_language: en
    supported_entities:
      - <ENTITY_TYPE>
    patterns:
      - name: <pattern_name>
        regex: "<regex pattern>"
        score: 0.9                   # Confidence score (0.0 - 1.0)
    context:                         # Optional: contextual keywords
      - account
      - bank
```

### Presidio Anonymization Operators

| Type | Parameters | Usage |
|---|---|---|
| `replace` | `new_value` | Replace with static string |
| `mask` | `masking_char`, `chars_to_mask`, `from_end` | Partial masking |
| `hash` | `hash_type` (sha256, md5) | One-way hash |
| `redact` | (none) | Remove entirely |

---

## 9. OPA API Authorization

### Policy Structure (Rego)

```rego
package {{APP_NAME}}.authz

import future.keywords.if
import future.keywords.in

default allow := false

# Extract JWT claims
claims := payload if {
  [_, payload, _] := io.jwt.decode(bearer_token)
}

# Role-based access
allow if {
  user_role == "admin"
  path_match("/api/v1/users*", input.attributes.request.http.path)
}

# Resource-owner access
allow if {
  user_role == "customer"
  input.attributes.request.http.method in ["GET", "PUT"]
  path_user_id := split(input.attributes.request.http.path, "/")[4]
  path_user_id == user_id
}

# Rate limiting metadata
rate_limit["requests_per_minute"] := 60 if {
  user_role == "customer"
}
```

### Envoy Integration

```yaml
# EnvoyFilter for OPA ext_authz
typed_config:
  "@type": type.googleapis.com/envoy.extensions.filters.http.ext_authz.v3.ExtAuthz
  grpc_service:
    envoy_grpc:
      cluster_name: outbound|9191||opa.opa-system.svc.cluster.local
    timeout: 0.5s
  failure_mode_allow: false           # Deny on OPA failure
  with_request_body:
    max_request_bytes: 8192
```

---

## 10. Pod Security Standards

### Namespace Labels

```yaml
metadata:
  labels:
    pod-security.kubernetes.io/enforce: restricted | baseline | privileged
    pod-security.kubernetes.io/enforce-version: latest
    pod-security.kubernetes.io/audit: restricted | baseline | privileged
    pod-security.kubernetes.io/audit-version: latest
    pod-security.kubernetes.io/warn: restricted | baseline | privileged
    pod-security.kubernetes.io/warn-version: latest
```

### PSS Levels

| Level | Restrictions |
|---|---|
| `restricted` | No privileged, no hostNetwork/PID/IPC, runAsNonRoot, drop ALL caps, no allowPrivilegeEscalation, restricted volume types |
| `baseline` | No privileged, no hostNetwork/PID/IPC, limited host ports, limited volume types |
| `privileged` | No restrictions (for system components) |

---

## 11. RBAC Audit Configuration

### Audit Policy Levels

| Level | Logged Data |
|---|---|
| `RequestResponse` | Request metadata + request body + response body |
| `Request` | Request metadata + request body |
| `Metadata` | Request metadata only |
| `None` | Not logged |

### Audit Policy Example

```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  # Full audit for secrets
  - level: RequestResponse
    resources:
      - group: ""
        resources: ["secrets"]
    namespaces: ["{{APP_NAMESPACE}}"]

  # Full audit for RBAC changes
  - level: RequestResponse
    resources:
      - group: "rbac.authorization.k8s.io"
        resources: ["clusterroles", "clusterrolebindings", "roles", "rolebindings"]

  # Request-level for deployments
  - level: Request
    resources:
      - group: "apps"
        resources: ["deployments", "statefulsets", "daemonsets"]
    verbs: ["create", "update", "patch", "delete"]

  # Exclude noisy system operations
  - level: None
    users: ["system:kube-scheduler", "system:kube-controller-manager"]
```

### Role Summary

| Role | Scope | Key Permissions |
|---|---|---|
| `{{APP_NAME}}-platform-admin` | Cluster | Full access (break-glass, 4h max) |
| `{{APP_NAME}}-devops-engineer` | Namespace | Deploy, manage workloads, services, HPA |
| `{{APP_NAME}}-developer` | Cluster (read) | Read-only workloads, pods, logs |
| `{{APP_NAME}}-developer-debug` | Staging only | Pod exec, port-forward |
| `{{APP_NAME}}-security-auditor` | Cluster (read) | Read RBAC, network policies, Gatekeeper, KubeArmor |
| `{{APP_NAME}}-oncall-engineer` | Namespace | DevOps + pod exec + rollback |
| `{{APP_NAME}}-cicd-deployer` | Namespace | Deploy workloads, manage configmaps, ArgoCD sync |

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Falco Rules
- KubeArmor Policy Format
- Gatekeeper Constraints
- Kyverno Policies

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
