# MITRE ATT&CK for Threat Modeling

## Overview

MITRE ATT&CK (Adversarial Tactics, Techniques, and Common Knowledge) is a knowledge base of adversary behavior that can enhance threat modeling by providing real-world attack patterns and techniques.

**Value for Threat Modeling:**
- Evidence-based threat identification
- Standardized attack vocabulary
- Mapping to real-world adversary behavior
- Prioritization based on observed techniques
- Alignment with detection and response

---

## ATT&CK Structure

### Matrices

| Matrix | Scope | Use Case |
|--------|-------|----------|
| Enterprise | Windows, macOS, Linux, Cloud, Network | Most threat models |
| Mobile | Android, iOS | Mobile applications |
| ICS | Industrial Control Systems | OT/SCADA systems |
| Containers | Container environments | Kubernetes, Docker |

### Hierarchy

**Tactic (WHY)**

- Technique (HOW)
  - Sub-technique (SPECIFIC HOW)
    - Procedure (REAL-WORLD EXAMPLE)


### Enterprise Tactics

| ID | Tactic | Description |
|----|--------|-------------|
| TA0001 | Initial Access | Entry into network |
| TA0002 | Execution | Running malicious code |
| TA0003 | Persistence | Maintaining access |
| TA0004 | Privilege Escalation | Gaining higher permissions |
| TA0005 | Defense Evasion | Avoiding detection |
| TA0006 | Credential Access | Stealing credentials |
| TA0007 | Discovery | Mapping the environment |
| TA0008 | Lateral Movement | Moving through network |
| TA0009 | Collection | Gathering target data |
| TA0010 | Exfiltration | Stealing data out |
| TA0011 | Command and Control | Communicating with compromised systems |
| TA0040 | Impact | Disrupting systems |

---

## Integrating ATT&CK with STRIDE

### Mapping STRIDE to ATT&CK

| STRIDE | Related ATT&CK Tactics |
|--------|------------------------|
| Spoofing | Initial Access, Credential Access |
| Tampering | Execution, Persistence, Impact |
| Repudiation | Defense Evasion |
| Information Disclosure | Collection, Exfiltration, Discovery |
| Denial of Service | Impact |
| Elevation of Privilege | Privilege Escalation, Initial Access |

### Combined Threat Analysis

```yaml
threat:
  title: "Web Application Credential Theft"

  stride:
    categories: [Spoofing, Information Disclosure]

  mitre_attack:
    tactics:
      - TA0006: Credential Access

    techniques:
      - T1056.001: Input Capture - Keylogging
      - T1539: Steal Web Session Cookie
      - T1552.001: Unsecured Credentials - Credentials in Files
      - T1110: Brute Force

  attack_vectors:
    - XSS to steal session cookies
    - Form hijacking for credentials
    - Exposed credentials in client-side code

  mitigations:
    - M1032: Multi-factor Authentication
    - M1017: User Training
    - M1054: Software Configuration (secure cookies)
```

---

## ATT&CK Navigator

### Using Navigator for Threat Modeling

```
1. Access Navigator: https://mitre-attack.github.io/attack-navigator/

2. Create threat model layer:
   - Select relevant techniques
   - Color-code by:
     - Risk level
     - Implementation status
     - Threat actor coverage

3. Export layer as JSON:
   - Include in threat model documentation
   - Version control with model
```

### Navigator Layer Example

```json
{
  "name": "E-Commerce Threat Model",
  "versions": {
    "attack": "14",
    "navigator": "4.9.1",
    "layer": "4.5"
  },
  "description": "ATT&CK techniques relevant to e-commerce platform",
  "domain": "enterprise-attack",
  "techniques": [
    {
      "techniqueID": "T1190",
      "tactic": "initial-access",
      "color": "#ff0000",
      "comment": "Public-facing web application - critical",
      "score": 100
    },
    {
      "techniqueID": "T1078",
      "tactic": "initial-access",
      "color": "#ff6600",
      "comment": "Valid accounts via credential theft",
      "score": 80
    },
    {
      "techniqueID": "T1552.001",
      "tactic": "credential-access",
      "color": "#ff6600",
      "comment": "Secrets in configuration files",
      "score": 80
    }
  ]
}
```

---

## Cloud ATT&CK Techniques

### AWS-Relevant Techniques

| Technique ID | Name | Relevance |
|--------------|------|-----------|
| T1078.004 | Valid Accounts: Cloud Accounts | Stolen AWS credentials |
| T1098 | Account Manipulation | IAM policy modification |
| T1530 | Data from Cloud Storage | S3 bucket access |
| T1537 | Transfer Data to Cloud Account | Exfil to attacker AWS |
| T1578 | Modify Cloud Compute | EC2 manipulation |
| T1552.005 | Cloud Instance Metadata API | IMDS exploitation |
| T1580 | Cloud Infrastructure Discovery | Recon of cloud resources |

### Azure-Relevant Techniques

| Technique ID | Name | Relevance |
|--------------|------|-----------|
| T1078.004 | Valid Accounts: Cloud Accounts | Azure AD compromise |
| T1087.004 | Account Discovery: Cloud Account | Enumerate Azure users |
| T1098.001 | Account Manipulation: Add Auth | Azure AD backdoors |
| T1136.003 | Create Account: Cloud Account | Malicious Azure accounts |
| T1528 | Steal Application Access Token | Azure token theft |
| T1606.002 | Forge Web Credentials: SAML | SAML token forgery |

### Kubernetes-Relevant Techniques

| Technique ID | Name | Relevance |
|--------------|------|-----------|
| T1609 | Container Administration Command | kubectl abuse |
| T1610 | Deploy Container | Malicious container |
| T1611 | Escape to Host | Container escape |
| T1613 | Container and Resource Discovery | Cluster enumeration |
| T1552.007 | Container API | Kubernetes API secrets |

---

## Threat Model Templates with ATT&CK

### Web Application Template

```yaml
system: Web Application
architecture:
  - component: Web Server
    threats:
      - technique: T1190
        name: Exploit Public-Facing Application
        attack_surface: HTTP endpoints
        mitigations:
          - WAF
          - Input validation
          - Regular patching

      - technique: T1059.007
        name: Command and Scripting Interpreter: JavaScript
        attack_surface: Client-side code execution
        mitigations:
          - CSP headers
          - Input encoding

  - component: Authentication
    threats:
      - technique: T1110
        name: Brute Force
        sub_techniques:
          - T1110.001: Password Guessing
          - T1110.003: Password Spraying
        mitigations:
          - Rate limiting
          - Account lockout
          - MFA

      - technique: T1539
        name: Steal Web Session Cookie
        attack_surface: Session management
        mitigations:
          - Secure cookie flags
          - Short session timeout
          - Session binding

  - component: Database
    threats:
      - technique: T1190
        name: SQL Injection
        attack_surface: Data queries
        mitigations:
          - Parameterized queries
          - WAF rules
          - Least privilege DB access
```

### Cloud Infrastructure Template

```yaml
system: AWS Cloud Infrastructure
components:
  - name: IAM
    threats:
      - technique: T1078.004
        name: Valid Accounts - Cloud
        description: Stolen or leaked AWS credentials
        indicators:
          - Unusual API calls
          - New regions accessed
          - Off-hours activity
        mitigations:
          - MFA required
          - Short-lived credentials
          - CloudTrail monitoring

      - technique: T1098
        name: Account Manipulation
        description: Modify IAM policies
        indicators:
          - Policy changes
          - New roles created
          - Trust policy modifications
        mitigations:
          - SCPs (Service Control Policies)
          - Change monitoring
          - Approval workflow

  - name: S3 Storage
    threats:
      - technique: T1530
        name: Data from Cloud Storage
        description: Access/exfiltrate S3 data
        indicators:
          - Large downloads
          - Access from new IPs
          - GetObject anomalies
        mitigations:
          - Bucket policies
          - VPC endpoints
          - Access logging
```

---

## Threat Actor Mapping

### Using Groups for Prioritization

```yaml
threat_actors:
  - group: FIN7
    description: Financial crime group targeting retail/hospitality
    relevance: High for e-commerce
    techniques:
      - T1566.001: Phishing - Spearphishing Attachment
      - T1059.001: PowerShell
      - T1055: Process Injection
      - T1547.001: Registry Run Keys
      - T1041: Exfiltration Over C2 Channel

    priority_mitigations:
      - Email security (anti-phishing)
      - PowerShell logging/constraints
      - EDR deployment
      - Network monitoring

  - group: APT29
    description: Russian state-sponsored, targets government/tech
    relevance: High for government clients
    techniques:
      - T1195: Supply Chain Compromise
      - T1078: Valid Accounts
      - T1550: Use Alternate Authentication Material
      - T1606: Forge Web Credentials

    priority_mitigations:
      - Supply chain security
      - Zero trust architecture
      - Token security
```

---

## ATT&CK-Based Detection Requirements

### Mapping Threats to Detection

```yaml
threat_detection_mapping:
  - technique: T1078.004
    name: Cloud Account Compromise

    data_sources:
      - AWS CloudTrail
      - Azure Activity Logs
      - GCP Audit Logs

    detection_rules:
      - name: Login from new geography
        logic: |
          source_ip.geo NOT IN known_locations
          AND event.type = "ConsoleLogin"

      - name: API calls from new user agent
        logic: |
          user_agent NOT IN baseline
          AND api_call.count > 10

    siem_integration:
      - Splunk: AWS:CloudTrail sourcetype
      - Sentinel: AzureActivity table
      - Chronicle: GCP Cloud Audit Logs

  - technique: T1530
    name: S3 Data Access

    data_sources:
      - S3 Access Logs
      - CloudTrail data events

    detection_rules:
      - name: Bulk download detection
        logic: |
          GetObject.count > 100
          AND timewindow = 1hour
          AND source_ip NOT IN known_ips

      - name: Public bucket access
        logic: |
          requester = "-"
          AND object.acl = "public-read"
```

---

## Tools for ATT&CK Integration

### MITRE Tools

| Tool | Purpose | URL |
|------|---------|-----|
| ATT&CK Navigator | Visualization | attack-navigator |
| ATT&CK Workbench | Custom content | attackworkbench |
| CALDERA | Adversary emulation | caldera |
| CARET | Detection analytics | car.mitre.org |

### Integration Scripts

```python
# Fetch ATT&CK data via STIX
from stix2 import TAXIICollectionSource
from taxii2client import Collection

# Connect to ATT&CK TAXII server
collection = Collection(
    "https://cti-taxii.mitre.org/stix/collections/"
    "95ecc380-afe9-11e4-9b6c-751b66dd541e/"
)
tc_source = TAXIICollectionSource(collection)

# Get all techniques
techniques = tc_source.query([
    Filter("type", "=", "attack-pattern")
])

# Filter for specific tactics
initial_access = [
    t for t in techniques
    if "initial-access" in t.get("kill_chain_phases", [{}])[0].get("phase_name", "")
]
```

---

## ATT&CK in Threat Model Reports

### Report Section Template

```markdown
## ATT&CK Mapping

### Applicable Techniques

| ID | Technique | Tactic | Risk Level | Status |
|----|-----------|--------|------------|--------|
| T1190 | Exploit Public-Facing Application | Initial Access | Critical | Mitigated |
| T1078 | Valid Accounts | Multiple | High | Partial |
| T1530 | Data from Cloud Storage | Collection | High | Open |

### Threat Actor Coverage

Based on ATT&CK threat intelligence, the following groups are relevant:
- **FIN7**: 15/20 techniques covered by current controls
- **APT29**: 8/25 techniques covered (requires attention)

### Detection Coverage

| Tactic | Techniques | Detected | Gap |
|--------|------------|----------|-----|
| Initial Access | 5 | 4 | 80% |
| Execution | 8 | 5 | 62% |
| Persistence | 10 | 6 | 60% |
| Credential Access | 7 | 4 | 57% |

### Priority Mitigations

Based on ATT&CK coverage analysis:
1. **M1032**: Multi-factor Authentication (covers 15 techniques)
2. **M1026**: Privileged Account Management (covers 12 techniques)
3. **M1018**: User Account Management (covers 10 techniques)
```

---

## Best Practices

### Do's

- Use ATT&CK to validate STRIDE findings
- Map mitigations to specific techniques
- Prioritize based on threat actor relevance
- Update mappings as ATT&CK evolves
- Include Navigator layers in documentation

### Don'ts

- Don't try to cover all techniques (focus on relevant)
- Don't ignore context (not all techniques apply)
- Don't skip sub-techniques (they provide specificity)
- Don't forget detection alongside prevention

---

## Next Steps

→ [CI/CD Integration Patterns](../../terraform/labs/phase-4-advanced-lab-4.2-cicd-integration.md)
→ [Return to Tools Overview](threat-modeling-roadmap.md#tools)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- ATT&CK Structure
- Integrating ATT&CK with STRIDE
- ATT&CK Navigator
- Cloud ATT&CK Techniques

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
