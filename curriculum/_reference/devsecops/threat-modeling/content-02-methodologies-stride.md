# STRIDE Threat Modeling Deep Dive

## Overview

STRIDE is a threat classification model developed by Microsoft. It provides a systematic approach to identifying threats by categorizing them into six types based on the security properties they violate.

| STRIDE |  |  |
|---|---|---|
| Category | Description | Security Property |
| S poofing | Impersonating someone | Authentication |
| T ampering | Modifying data/code | Integrity |
| R epudiation | Denying actions | Non-repudiation |
| I nfo Disclosure | Exposing data | Confidentiality |
| D enial of Service | Degrading availability | Availability |
| E levation of Privilege | Gaining access | Authorization |


---

## STRIDE Categories Explained

### S - Spoofing

**Definition:** Illegally accessing and using another user's authentication credentials or identity.

**Questions to Ask:**
- How does the system verify identity?
- Can credentials be stolen or forged?
- Are there hardcoded credentials?
- Can session tokens be hijacked?

**Attack Examples:**

| Attack | Description | Target |
|--------|-------------|--------|
| Credential theft | Phishing, keylogging | User passwords |
| Session hijacking | Stealing session cookies | Active sessions |
| Token forgery | Creating fake JWTs | API authentication |
| ARP spoofing | Redirecting network traffic | Network identity |
| DNS spoofing | Redirecting domain queries | Service identity |
| Certificate impersonation | Fake SSL certs | TLS identity |

**Cloud-Specific Spoofing:**
**AWS:**

- IAM credential theft
- Assumed role abuse
- IMDS exploitation (169.254.169.254)
- Cross-account confusion

**Kubernetes:**

- Service account token theft
- Pod identity spoofing
- Kubelet API abuse
- Impersonation of ServiceAccounts


**Mitigations:**
- Multi-factor authentication (MFA)
- Strong credential policies
- Certificate-based authentication
- Token binding and rotation
- IMDSv2 (instance metadata service v2)
- Network identity verification

### T - Tampering

**Definition:** Malicious modification of data or code.

**Questions to Ask:**
- Can input be manipulated?
- Is data validated at trust boundaries?
- Can data in transit be modified?
- Can data at rest be altered?
- Can code/configuration be changed?

**Attack Examples:**

| Attack | Description | Target |
|--------|-------------|--------|
| SQL Injection | Malicious SQL in input | Database queries |
| XSS | Injecting client scripts | Web pages |
| Command injection | OS commands in input | System calls |
| Parameter tampering | Modifying request params | API requests |
| Man-in-the-middle | Altering data in transit | Network traffic |
| Binary patching | Modifying executables | Application code |

**Cloud-Specific Tampering:**
**AWS:**

- S3 object modification
- Lambda function code injection
- CloudFormation template tampering
- SSM Parameter Store modification
- ECR image replacement

**Kubernetes:**

- ConfigMap/Secret modification
- Container image tampering
- Admission webhook bypass
- etcd data modification
- Mutating webhook abuse


**Mitigations:**
- Input validation and sanitization
- Parameterized queries
- Code signing and verification
- Integrity monitoring (file integrity)
- Immutable infrastructure
- TLS for data in transit
- Encryption with integrity (AES-GCM)

### R - Repudiation

**Definition:** Users or attackers denying that they performed an action.

**Questions to Ask:**
- Are actions logged?
- Are logs tamper-proof?
- Can logs be attributed to specific users?
- Is there a complete audit trail?
- Are timestamps trustworthy?

**Attack Examples:**

| Attack | Description | Target |
|--------|-------------|--------|
| Log deletion | Removing evidence | Audit logs |
| Log tampering | Altering log entries | Audit trail |
| Timestamp manipulation | Changing event times | Forensic timeline |
| Shared account abuse | Actions under shared ID | Attribution |
| Log injection | Inserting false entries | Log integrity |

**Cloud-Specific Repudiation:**
**AWS:**

- CloudTrail log deletion
- S3 access log tampering
- VPC Flow Log gaps
- Root account actions without MFA
- Cross-account access without attribution

**Kubernetes:**

- Audit log deletion
- API server audit bypass
- Pod logging gaps
- Shared service account actions
- Anonymous API access


**Mitigations:**
- Centralized, immutable logging
- Log integrity verification
- Digital signatures on logs
- Separate log storage account
- Strong authentication
- Timestamping services
- WORM storage for compliance

### I - Information Disclosure

**Definition:** Exposure of information to unauthorized parties.

**Questions to Ask:**
- What sensitive data exists?
- Is data encrypted at rest and in transit?
- Who can access what data?
- Are there data leakage paths?
- Is sensitive data in logs, errors, or backups?

**Attack Examples:**

| Attack | Description | Target |
|--------|-------------|--------|
| Data breach | Unauthorized data access | Customer data |
| Error message leakage | Sensitive info in errors | System details |
| Directory traversal | Accessing unintended files | File system |
| Memory disclosure | Exposing process memory | Credentials, keys |
| Side-channel attacks | Inferring data indirectly | Encryption keys |
| SSRF | Server-side requests exposing internal resources | Internal services |

**Cloud-Specific Information Disclosure:**
**AWS:**

- Public S3 buckets
- Exposed EBS snapshots
- Overly permissive IAM policies
- Secrets in environment variables
- IMDS credential exposure
- CloudWatch Logs with sensitive data

**Kubernetes:**

- Exposed secrets in pods
- etcd access without encryption
- Overly permissive RBAC
- Debug endpoints exposed
- Secrets in environment variables
- Service account token exposure


**Mitigations:**
- Encryption at rest and in transit
- Access control and least privilege
- Data classification and handling
- Error handling (generic messages)
- Secrets management
- DLP (Data Loss Prevention)
- Network segmentation

### D - Denial of Service

**Definition:** Denying or degrading service to users.

**Questions to Ask:**
- What are the resource limits?
- Can resources be exhausted?
- Are there single points of failure?
- How does the system handle overload?
- What's the blast radius of failures?

**Attack Examples:**

| Attack | Description | Target |
|--------|-------------|--------|
| DDoS | Overwhelming with traffic | Network/application |
| Resource exhaustion | Consuming CPU/memory/disk | System resources |
| Application logic abuse | Expensive operations | Business logic |
| Algorithmic complexity | Triggering worst-case | Hash tables, regex |
| Cascade failures | Triggering system-wide outage | Dependencies |
| Data corruption | Making data unusable | Data stores |

**Cloud-Specific DoS:**
**AWS:**

- Lambda concurrency exhaustion
- API Gateway throttling abuse
- DynamoDB capacity exhaustion
- S3 request rate limits
- Cross-AZ traffic costs
- Resource quota exhaustion

**Kubernetes:**

- Pod resource exhaustion
- etcd storage limits
- API server overload
- Node resource starvation
- Namespace resource quota bypass
- Network policy gaps


**Mitigations:**
- Rate limiting and throttling
- Auto-scaling with limits
- Resource quotas
- Circuit breakers
- Redundancy and failover
- DDoS protection services
- Graceful degradation
- Chaos engineering/testing

### E - Elevation of Privilege

**Definition:** Gaining capabilities beyond those legitimately granted.

**Questions to Ask:**
- How is authorization enforced?
- Can authorization be bypassed?
- Are there default/weak permissions?
- Can roles be escalated?
- Are admin functions protected?

**Attack Examples:**

| Attack | Description | Target |
|--------|-------------|--------|
| Privilege escalation | User becomes admin | Authorization |
| Broken access control | Accessing others' data | Resource access |
| IDOR | Direct object access | API endpoints |
| JWT manipulation | Changing claims | Token authorization |
| Container escape | Breaking out of container | Host system |
| SQL privilege escalation | DB user gains DBA | Database roles |

**Cloud-Specific EoP:**
**AWS:**

- IAM policy escalation
- Assume role chaining
- Lambda privilege abuse
- SSM Session Manager escape
- EC2 instance profile abuse
- Cross-account role confusion

**Kubernetes:**

- RBAC escalation
- Privileged container escape
- Host path mount abuse
- Service account privilege abuse
- Node access to secrets
- Admission controller bypass


**Mitigations:**
- Principle of least privilege
- Role-based access control
- Regular access reviews
- Separation of duties
- Secure defaults
- Container security (non-root, read-only)
- IAM policy boundaries

---

## STRIDE-per-Element Approach

Apply STRIDE systematically by element type:

### External Entities
| STRIDE | Applicable | Common Threats |
|--------|------------|----------------|
| Spoofing | ✓ | User impersonation |
| Tampering | | |
| Repudiation | ✓ | Denying actions |
| Info Disclosure | | |
| Denial of Service | | |
| Elevation of Privilege | | |

### Processes
| STRIDE | Applicable | Common Threats |
|--------|------------|----------------|
| Spoofing | ✓ | Service impersonation |
| Tampering | ✓ | Code injection |
| Repudiation | ✓ | Missing audit logs |
| Info Disclosure | ✓ | Error messages, logs |
| Denial of Service | ✓ | Resource exhaustion |
| Elevation of Privilege | ✓ | Authorization bypass |

### Data Stores
| STRIDE | Applicable | Common Threats |
|--------|------------|----------------|
| Spoofing | | |
| Tampering | ✓ | Data modification |
| Repudiation | | |
| Info Disclosure | ✓ | Unauthorized access |
| Denial of Service | ✓ | Data corruption |
| Elevation of Privilege | | |

### Data Flows
| STRIDE | Applicable | Common Threats |
|--------|------------|----------------|
| Spoofing | | |
| Tampering | ✓ | Man-in-the-middle |
| Repudiation | | |
| Info Disclosure | ✓ | Eavesdropping |
| Denial of Service | ✓ | Network disruption |
| Elevation of Privilege | | |

---

## STRIDE Threat Enumeration Process

### Step 1: Create DFD
See [DFD Basics](content-01-foundations-dfd-basics.md)

### Step 2: Identify Elements
List all:
- External entities
- Processes
- Data stores
- Data flows
- Trust boundaries

### Step 3: Apply STRIDE to Each Element

For each element, go through applicable STRIDE categories:

**Element: API Gateway**

- Spoofing
  - Threat: Attacker spoofs legitimate service calls
- Tampering
  - Threat: Request modification in transit
- Repudiation
  - Threat: API calls not logged with caller identity
- Information Disclosure
  - Threat: Verbose error messages expose internals
- Denial of Service
  - Threat: Rate limiting bypass exhausts backend
- Elevation of Privilege
  - Threat: JWT claim manipulation grants admin access


### Step 4: Document Threats

Use structured format:

| ID | Element | Category | Threat Description | Attack Vector | Impact | Likelihood | Risk |
|----|---------|----------|-------------------|---------------|--------|------------|------|
| T001 | API Gateway | Spoofing | Attacker uses stolen API key | Key theft via log exposure | High | Medium | High |
| T002 | API Gateway | Info Disclosure | Error messages reveal stack trace | Trigger errors with invalid input | Medium | High | Medium |

### Step 5: Identify Mitigations

| Threat ID | Mitigation | Control Type | Status |
|-----------|------------|--------------|--------|
| T001 | API key rotation, logging of key usage | Detective, Preventive | Planned |
| T002 | Custom error handler, remove stack traces | Preventive | In Progress |

---

## STRIDE Worksheets

### Quick Reference Card

**STRIDE quick reference**

| Threat | The question to ask | The control |
|---|---|---|
| **S**poofing | Can someone pretend to be something they are not? | Authentication · verify identity |
| **T**ampering | Can data be modified maliciously? | Input validation · integrity checks |
| **R**epudiation | Can someone deny having done it? | Log everything · protect the logs |
| **I**nformation disclosure | Can data reach unauthorised parties? | Encryption · access control |
| **D**enial of service | Can the system be made unavailable? | Rate limiting · scaling · redundancy |
| **E**levation of privilege | Can someone gain more access than allowed? | Least privilege · validate authorization |

STRIDE is a *prompt*, not a taxonomy to argue about. Point it at one element of your DFD, ask all six
questions, write down what surfaces, move to the next element. The value is the systematic coverage —
it makes you consider repudiation on a component where you would never have thought to.

### Element Analysis Template

**ELEMENT: [Name]**

TYPE: [External Entity / Process / Data Store / Data Flow]
TRUST BOUNDARY: [Inside / Outside / Crossing]

STRIDE Analysis:
 S - SPOOFING
 Q: How is this element's identity verified?
 Threats:
 •
 Mitigations:
 •
 T - TAMPERING
 Q: Can data in this element be modified?
 Threats:
 •
 Mitigations:
 •
 R - REPUDIATION
 Q: Are actions logged and attributed?
 Threats:
 •
 Mitigations:
 •
 I - INFORMATION DISCLOSURE
 Q: Can data be accessed by unauthorized parties?
 Threats:
 •
 Mitigations:
 •
 D - DENIAL OF SERVICE
 Q: Can this element be made unavailable?
 Threats:
 •
 Mitigations:
 •
 E - ELEVATION OF PRIVILEGE
 Q: Can someone gain unauthorized access via this element?
 Threats:
 •
 Mitigations:
 •


---

## Practical Exercise

### Exercise: Apply STRIDE to a Kubernetes Deployment

**Scenario:** A containerized API service deployed on Kubernetes:

```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-service
spec:
  replicas: 3
  template:
    spec:
      serviceAccountName: api-service-sa
      containers:
      - name: api
        image: myregistry/api:v1.2.3
        ports:
        - containerPort: 8080
        env:
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: password
        volumeMounts:
        - name: config
          mountPath: /etc/config
      volumes:
      - name: config
        configMap:
          name: api-config
---
apiVersion: v1
kind: Service
metadata:
  name: api-service
spec:
  selector:
    app: api-service
  ports:
  - port: 80
    targetPort: 8080
```

**Task:**
1. Identify all elements in this deployment
2. Apply STRIDE to each element
3. Document at least 2 threats per STRIDE category
4. Propose mitigations

**Elements to consider:**
- Container image
- Service account
- Secrets
- ConfigMap
- Service/Network exposure
- Pod-to-pod communication

---

## Key Takeaways

1. **STRIDE is systematic** - Apply to every element, every category
2. **Element type matters** - Different elements have different applicable threats
3. **Trust boundaries are key** - Focus on boundary crossings
4. **Document everything** - Structured documentation enables tracking
5. **Mitigations follow** - Every threat needs a response
6. **Cloud-native needs attention** - STRIDE applies to K8s, serverless, IaC

---

## Next Steps

→ [PASTA Framework](content-02-methodologies-pasta.md)
→ [Lab 02: API Threat Model with STRIDE](labs-lab-02-api-threat-model-README.md)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- STRIDE Categories Explained
- STRIDE-per-Element Approach
- STRIDE Threat Enumeration Process
- STRIDE Worksheets

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
