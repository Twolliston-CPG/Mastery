# Lab 04: Kubernetes Deployment Threat Model

## Objective

Perform a comprehensive threat model of a Kubernetes-based microservices deployment, identifying container-specific, orchestration, and cloud-native threats.

---

## Scenario: FinanceApp Microservices Platform

You are the security architect for a financial services company deploying a new trading platform on Kubernetes.

### Application Components

**FinanceApp Microservices:**

- API Gateway (Kong)
- Authentication Service
- User Service
- Trading Service
- Portfolio Service
- Market Data Service
- Notification Service
- Audit Service
- Supporting Infrastructure
  - PostgreSQL (via StatefulSet)
  - Redis (session cache)
  - Kafka (event streaming)
  - Vault (secrets management)


### Deployment Environment

| Aspect | Configuration |
|--------|---------------|
| Cloud Provider | AWS EKS |
| Kubernetes Version | 1.28 |
| Node Groups | 3 (system, application, data) |
| Namespaces | default, finance-app, monitoring, vault |
| Ingress | AWS ALB Ingress Controller |
| Service Mesh | Istio |
| Secrets | HashiCorp Vault with CSI driver |
| Monitoring | Prometheus, Grafana, Loki |

---

## Architecture Diagram

<!-- figure: generated from the Mermaid below by _shared/diagrams/embed-figures.py — do not edit the image -->
![Architecture Diagram — diagram](../../../../_figures/curriculum-_reference-devsecops-threat-modeling-labs-lab-04-kubernetes-README-0-9c6c21a4.png)

<details>
<summary>Diagram source (Mermaid)</summary>

```mermaid
%%{init: {'theme':'base','themeVariables':{'fontFamily':'Helvetica, Arial, sans-serif','fontSize':'13px','primaryColor':'#ffffff','primaryTextColor':'#2d3436','primaryBorderColor':'#9aa3ab','lineColor':'#9aa3ab','textColor':'#2d3436','clusterBkg':'#fbfcfd','clusterBorder':'#d4dae0','edgeLabelBackground':'#ffffff','tertiaryColor':'#eef4fb'},'flowchart':{'curve':'basis','padding':14,'nodeSpacing':42,'rankSpacing':58}}}%%
flowchart TB
  classDef default fill:#ffffff,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef n    fill:#ffffff,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef crit fill:#eef4fb,stroke:#2f6fb8,stroke-width:1.8px,color:#1b3a5c
  classDef data fill:#f4f7fa,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef mut  fill:#ffffff,stroke:#cfd6dc,stroke-width:1.1px,color:#7a8288
  classDef warn fill:#fdf0ec,stroke:#c0522d,stroke-width:1.6px,color:#8a3a1e
  TR["Traders<br/><i>mobile and desktop</i>"]
  ALB["Cloud load balancer<br/><i>public</i>"]
  subgraph EKS["Managed Kubernetes cluster"]
    direction TB
    subgraph APPNS["Namespace: finance-app"]
      direction TB
      IGW(["Service mesh ingress gateway"])
      KONG(["API gateway"])
      AUTH(["Auth service"])
      TRD(["Trading service"])
      PORT(["Portfolio service"])
      USR(["User service"])
      MKT(["Market data service"])
      AUD(["Audit service"])
      NTF(["Notification service"])
      IGW ==> KONG ==> AUTH
      KONG ==> TRD
      KONG ==> PORT
      KONG ==> USR
      TRD --> MKT
      TRD --> AUD
    end
    subgraph DATANS["Namespace: data"]
      direction LR
      PG[("PostgreSQL")]
      RD[("Redis cluster")]
      KF[("Kafka cluster")]
      TS[("Time-series DB")]
    end
    subgraph VAULTNS["Namespace: vault"]
      VLT["Secrets · PKI · dynamic database credentials"]
    end
  end
  EXTMKT["External market data providers"]
  TR ==>|"HTTPS · account boundary"| ALB ==>|"cluster boundary"| IGW
  APPNS ==>|"namespace boundary"| DATANS
  APPNS -.-> VAULTNS
  MKT ==> EXTMKT
  class TR mut
  class ALB n
  class IGW,KONG crit
  class AUTH crit
  class TRD crit
  class PORT,USR,MKT,NTF n
  class AUD crit
  class PG,RD,KF,TS data
  class VLT crit
  class EXTMKT mut
  linkStyle 6,7,8,9,11 stroke:#2f6fb8,stroke-width:2px

%% Three namespaces, three trust levels, and the vault namespace is the one that
%% must never be reachable from the others except through its own API. In a
%% cluster with no NetworkPolicy, a compromised notification pod can open a TCP
%% connection to PostgreSQL, and nothing in this diagram would show it.
```

</details>

---

## Kubernetes Manifests (Excerpts)

### Trading Service Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: trading-service
  namespace: finance-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: trading-service
  template:
    metadata:
      labels:
        app: trading-service
        version: v1
      annotations:
        vault.hashicorp.com/agent-inject: "true"
        vault.hashicorp.com/role: "trading-service"
        vault.hashicorp.com/agent-inject-secret-db: "database/creds/trading"
    spec:
      serviceAccountName: trading-service
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
      containers:
      - name: trading
        image: financeapp/trading-service:v2.3.1
        ports:
        - containerPort: 8080
        resources:
          limits:
            cpu: "500m"
            memory: "512Mi"
          requests:
            cpu: "250m"
            memory: "256Mi"
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
              - ALL
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
        volumeMounts:
        - name: tmp
          mountPath: /tmp
        - name: config
          mountPath: /etc/config
          readOnly: true
      volumes:
      - name: tmp
        emptyDir: {}
      - name: config
        configMap:
          name: trading-config
```

### Network Policy

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: trading-service-policy
  namespace: finance-app
spec:
  podSelector:
    matchLabels:
      app: trading-service
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: kong-gateway
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: data
      podSelector:
        matchLabels:
          app: postgresql
    ports:
    - protocol: TCP
      port: 5432
  - to:
    - podSelector:
        matchLabels:
          app: portfolio-service
    ports:
    - protocol: TCP
      port: 8080
```

### RBAC Configuration

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: trading-service
  namespace: finance-app
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: trading-service-role
  namespace: finance-app
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  resourceNames: ["trading-config"]
  verbs: ["get", "watch"]
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["trading-tls"]
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: trading-service-binding
  namespace: finance-app
subjects:
- kind: ServiceAccount
  name: trading-service
  namespace: finance-app
roleRef:
  kind: Role
  name: trading-service-role
  apiGroup: rbac.authorization.k8s.io
```

---

## Lab Tasks

### Task 1: Kubernetes Threat Landscape Analysis (20 minutes)

Identify threats specific to each Kubernetes layer:

**KUBERNETES THREAT LAYERS**

**Layer 1: Cloud Infrastructure (AWS)**

- IAM misconfigurations
- Network exposure
- Resource quotas

**Layer 2: Kubernetes Control Plane**

- API Server access
- etcd security
- Admission controllers

**Layer 3: Node Security**

- Node access
- kubelet security
- Container runtime

**Layer 4: Workload Security**

- Pod security
- Container security
- Application vulnerabilities

**Layer 5: Data Security**

- Secrets management
- Persistent storage
- Data in transit


**Deliverable:** List 3-5 specific threats for each layer

---

### Task 2: STRIDE Analysis of Kubernetes Components (45 minutes)

Apply STRIDE to key Kubernetes components:

#### 2.1 API Server

| STRIDE | Threat | Attack Vector |
|--------|--------|---------------|
| Spoofing | | |
| Tampering | | |
| Repudiation | | |
| Info Disclosure | | |
| DoS | | |
| EoP | | |

#### 2.2 Service Account: trading-service

| STRIDE | Threat | Attack Vector |
|--------|--------|---------------|
| Spoofing | | |
| Tampering | | |
| Repudiation | | |
| Info Disclosure | | |
| DoS | | |
| EoP | | |

#### 2.3 Pod-to-Pod Communication (Service Mesh)

| STRIDE | Threat | Attack Vector |
|--------|--------|---------------|
| Spoofing | | |
| Tampering | | |
| Repudiation | | |
| Info Disclosure | | |
| DoS | | |
| EoP | | |

#### 2.4 Secrets (Vault Integration)

| STRIDE | Threat | Attack Vector |
|--------|--------|---------------|
| Spoofing | | |
| Tampering | | |
| Repudiation | | |
| Info Disclosure | | |
| DoS | | |
| EoP | | |

---

### Task 3: Container Image Security Analysis (20 minutes)

Analyze the container image security posture:

```
Container Image Threat Checklist:
□ Base image vulnerabilities
□ Dependency vulnerabilities
□ Hardcoded secrets in layers
□ Excessive permissions (USER root)
□ Unnecessary packages installed
□ Missing image signing
□ Mutable tags (e.g., :latest)
□ Unsigned/untrusted registry
```

**Questions to answer:**
1. What could go wrong with the image `financeapp/trading-service:v2.3.1`?
2. How could an attacker compromise the image supply chain?
3. What controls are missing from the deployment manifest?

---

### Task 4: Network Security Assessment (20 minutes)

Review the NetworkPolicy and identify gaps:

```yaml
# Current NetworkPolicy (from above)
# Analyze:
# 1. Is egress properly restricted?
# 2. Can pods communicate that shouldn't?
# 3. Is the policy enforced (CNI support)?
```

**Create a threat map:**
**Trading Service Network Threats:**

- Intra-namespace: Can any pod in finance-app reach trading-service?
- Cross-namespace: Can pods in other namespaces reach trading-service?
- Egress: What external endpoints can trading-service reach?
- DNS: Can trading-service resolve arbitrary domains?


---

### Task 5: RBAC Review (20 minutes)

Analyze the RBAC configuration for privilege escalation paths:

**Review checklist:**
```
□ Service account has minimal permissions
□ No cluster-wide permissions for workload accounts
□ No ability to create/modify secrets beyond needs
□ No ability to modify own RBAC
□ No access to other namespaces
□ Pod security admission enforced
```

**Identify:**
1. What could an attacker do if they compromised the trading-service pod?
2. Can they escalate privileges within the cluster?
3. Can they access other services' data?

---

### Task 6: Attack Tree - Cluster Compromise (25 minutes)

Build an attack tree for "Compromise Trading Service Data":

<!-- figure: generated from the Mermaid below by _shared/diagrams/embed-figures.py — do not edit the image -->
![Task 6: Attack Tree - Cluster Compromise (25 minutes) — diagram](../../../../_figures/curriculum-_reference-devsecops-threat-modeling-labs-lab-04-kubernetes-README-1-e8b6a404.png)

<details>
<summary>Diagram source (Mermaid)</summary>

```mermaid
%%{init: {'theme':'base','themeVariables':{'fontFamily':'Helvetica, Arial, sans-serif','fontSize':'13px','primaryColor':'#ffffff','primaryTextColor':'#2d3436','primaryBorderColor':'#9aa3ab','lineColor':'#9aa3ab','textColor':'#2d3436','clusterBkg':'#fbfcfd','clusterBorder':'#d4dae0','edgeLabelBackground':'#ffffff','tertiaryColor':'#eef4fb'},'flowchart':{'curve':'basis','padding':14,'nodeSpacing':42,'rankSpacing':58}}}%%
flowchart TB
  classDef default fill:#ffffff,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef n    fill:#ffffff,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef crit fill:#eef4fb,stroke:#2f6fb8,stroke-width:1.8px,color:#1b3a5c
  classDef data fill:#f4f7fa,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef mut  fill:#ffffff,stroke:#cfd6dc,stroke-width:1.1px,color:#7a8288
  classDef warn fill:#fdf0ec,stroke:#c0522d,stroke-width:1.6px,color:#8a3a1e
  R["<b>Compromise trading service data</b>"]
  A["Compromise a pod"]
  B["Exploit the network"]
  C["Attack the secrets store"]
  D["Supply chain"]
  R ==> A
  R ==> B
  R ==> C
  R ==> D
  class R crit
  class A,C crit
  class B,D n
  linkStyle 0,2 stroke:#2f6fb8,stroke-width:2px

%% The template to decompose in this lab. Each branch keeps going until its
%% leaves are things a control can attach to -- `automountServiceAccountToken`,
%% a NetworkPolicy, a Vault auth role, an image signature.
```

</details>

**Decompose each path** to leaf nodes with:
- Attack technique
- Required access
- Detection difficulty

---

### Task 7: Compliance Mapping (15 minutes)

Map identified threats to compliance requirements:

| Threat | PCI DSS | SOC 2 | Mitigation Required |
|--------|---------|-------|---------------------|
| Container running as root | 2.2 | CC6.1 | |
| Secrets in environment vars | 3.4 | CC6.1 | |
| Missing network segmentation | 1.3 | CC6.6 | |
| No audit logging | 10.2 | CC7.2 | |

---

## Kubernetes Threat Reference

<details>
<summary>Click to reveal Kubernetes-specific threats</summary>

### Control Plane Threats
- Anonymous API access enabled
- Insecure API server flags
- etcd without encryption
- Missing admission controllers
- Weak authentication (no OIDC)

### Node Threats
- kubelet anonymous auth
- Privileged node access
- Host path mounts
- Node port exposure
- Container runtime vulnerabilities

### Workload Threats
- Privileged containers
- Host namespace sharing
- Writable root filesystem
- Missing resource limits
- Capability abuse

### Network Threats
- Missing network policies
- Service exposure (LoadBalancer/NodePort)
- DNS exfiltration
- Pod-to-pod lateral movement
- Ingress misconfiguration

### Secrets Threats
- Secrets mounted to unnecessary pods
- Base64 "encryption" only
- Secrets in environment variables
- etcd secrets unencrypted
- RBAC allowing secret access

### Supply Chain Threats
- Unsigned images
- Mutable image tags
- Vulnerable base images
- Malicious admission webhooks
- Compromised operators

</details>

---

## Evaluation Criteria

| Criteria | Points |
|----------|--------|
| Layer-specific threat identification | 15 |
| STRIDE analysis completeness | 25 |
| Container security assessment | 15 |
| Network security analysis | 15 |
| RBAC review thoroughness | 10 |
| Attack tree quality | 15 |
| Compliance mapping | 5 |
| **Total** | **100** |

---

## Tools for This Lab

| Tool | Purpose | Command |
|------|---------|---------|
| kubectl | Cluster inspection | `kubectl get pods -A` |
| kube-bench | CIS benchmark | `kube-bench run` |
| kubeaudit | Security audit | `kubeaudit all` |
| trivy | Image scanning | `trivy image <image>` |
| kube-hunter | Penetration testing | `kube-hunter --remote <ip>` |
| Falco | Runtime security | Runtime monitoring |

---

## Next Lab

→ [Lab 05: Serverless Application](labs-lab-05-serverless-README.md)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Scenario: FinanceApp Microservices Platform
- Kubernetes Manifests (Excerpts)
- Kubernetes Threat Reference
- Tools for This Lab

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
