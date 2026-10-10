# Assets, Threats, and Threat Actors

## Understanding Assets

### What is an Asset?

An asset is anything of value that needs protection. In threat modeling, we identify assets to understand what attackers might target.

### Asset Categories

**Asset types**

| Data assets | System assets |
|---|---|
| Customer PII | Servers and VMs |
| Financial records | Databases |
| Authentication credentials | APIs |
| Business secrets | Network infrastructure |
| Source code | Container orchestration |
| Encryption keys | Cloud resources |

| Functional assets | Reputational assets |
|---|---|
| Business processes | Brand trust |
| Service availability | Customer confidence |
| Transaction processing | Regulatory standing |
| User sessions | Market position |

The right-hand column of the second table is the one executives care about and threat models usually
omit. It is also the one with no technical control: you cannot patch brand trust, you can only avoid
spending it.

### Data Classification

| Level | Description | Examples | Handling |
|-------|-------------|----------|----------|
| **Public** | No impact if disclosed | Marketing materials, public docs | No restrictions |
| **Internal** | Minor impact | Internal procedures, org charts | Need-to-know |
| **Confidential** | Significant impact | Customer data, financials | Encrypted, access controlled |
| **Restricted** | Severe impact | Auth credentials, encryption keys, PHI | Strict controls, audited |

### Asset Inventory Template

| Asset ID | Asset Name | Type | Classification | Owner | Location | Dependencies |
|----------|------------|------|----------------|-------|----------|--------------|
| A001 | Customer Database | Data | Restricted | DBA Team | AWS RDS us-east-1 | App servers, backup |
| A002 | API Keys | Data | Restricted | DevOps | AWS Secrets Manager | All services |
| A003 | User Sessions | Data | Confidential | Backend Team | Redis cluster | Auth service |
| A004 | Payment Service | System | Critical | Payments Team | EKS cluster | Database, payment gateway |

### Cloud Asset Considerations

**AWS Assets:**
- IAM roles and policies
- KMS keys
- S3 buckets
- RDS instances
- Lambda functions
- API Gateway endpoints
- Secrets in Secrets Manager/Parameter Store

**Azure Assets:**
- Azure AD identities
- Key Vault secrets
- Storage accounts
- SQL databases
- Function Apps
- API Management

**GCP Assets:**
- Service accounts
- Cloud KMS keys
- Cloud Storage buckets
- Cloud SQL instances
- Cloud Functions
- API Gateway

---

## Understanding Threats

### What is a Threat?

A threat is a potential negative action or event that could exploit a vulnerability and cause harm to an asset.

**Threat Formula:**
```
THREAT = Threat Actor + Motive + Capability + Opportunity
```

### Threat Categories (STRIDE)

| Category | Description | Target Property | Example |
|----------|-------------|-----------------|---------|
| **Spoofing** | Pretending to be someone/something else | Authentication | Session hijacking |
| **Tampering** | Modifying data or code | Integrity | SQL injection |
| **Repudiation** | Denying actions performed | Non-repudiation | Deleting audit logs |
| **Information Disclosure** | Exposing data to unauthorized parties | Confidentiality | Data breach |
| **Denial of Service** | Making system unavailable | Availability | DDoS attack |
| **Elevation of Privilege** | Gaining unauthorized access | Authorization | Privilege escalation |

### Threat Sources

| THREAT SOURCES |  |
|---|---|
| EXTERNAL | INTERNAL |
| • Hackers | • Malicious insiders |
| • Competitors | • Negligent employees |
| • Nation-states | • Disgruntled staff |
| • Hacktivists | • Compromised accounts |
| • Script kiddies | • Shadow IT |
| • Organized crime | • Contractors |
| ENVIRONMENTAL |  |
| • Natural disasters  • Power failures  • Hardware failure |  |
| • Network outages    • Software bugs   • Supply chain |  |


---

## Understanding Threat Actors

### What is a Threat Actor?

A threat actor is an individual, group, or organization that poses a threat to your assets. Understanding threat actors helps prioritize defenses.

### Threat Actor Profiles

#### 1. Script Kiddies
```
Sophistication: ████░░░░░░ Low
Resources:      ████░░░░░░ Low
Motivation:     Fame, curiosity, vandalism
Target Selection: Opportunistic
TTPs: Automated tools, known exploits, default credentials
Defense Priority: Medium - High volume, low impact
```

#### 2. Hacktivists
```
Sophistication: ██████░░░░ Medium
Resources:      █████░░░░░ Medium
Motivation:     Political, social, ideological
Target Selection: Organizations opposing their cause
TTPs: DDoS, defacement, data leaks, doxxing
Defense Priority: Medium-High if in their crosshairs
```

#### 3. Cybercriminals
```
Sophistication: ███████░░░ Medium-High
Resources:      ███████░░░ Medium-High
Motivation:     Financial gain
Target Selection: Targets with valuable data or ability to pay
TTPs: Ransomware, BEC, credential theft, data theft
Defense Priority: High - Most common enterprise threat
```

#### 4. Insider Threats
```
Sophistication: ██████████ Varies (knows your systems)
Resources:      ██████████ Has legitimate access
Motivation:     Money, revenge, ideology, coercion
Target Selection: Data/systems they can access
TTPs: Data exfiltration, sabotage, fraud
Defense Priority: High - Bypasses perimeter defenses
```

#### 5. Competitors
```
Sophistication: ███████░░░ Medium-High
Resources:      ████████░░ High
Motivation:     Business advantage
Target Selection: Trade secrets, customer data, strategy
TTPs: Corporate espionage, social engineering, recruiting
Defense Priority: Medium-High for competitive industries
```

#### 6. Nation-State Actors (APT)
```
Sophistication: ██████████ Very High
Resources:      ██████████ Very High
Motivation:     Espionage, disruption, strategic advantage
Target Selection: Government, critical infrastructure, defense
TTPs: Zero-days, supply chain, long-term persistence
Defense Priority: Critical for government/critical infrastructure
```

### Threat Actor Matrix

| Actor | Skill | Resources | Persistence | Stealth | Typical TTPs |
|-------|-------|-----------|-------------|---------|--------------|
| Script Kiddie | Low | Low | Low | Low | Known exploits, scanning |
| Hacktivist | Medium | Low-Med | Medium | Low | DDoS, defacement |
| Cybercriminal | Med-High | Medium | Medium | Medium | Phishing, ransomware |
| Insider | Varies | Has access | Varies | Can be high | Abuse of access |
| Competitor | Med-High | High | Medium | High | Espionage |
| Nation-State | Very High | Very High | Very High | Very High | Zero-day, supply chain |

---

## Mapping Threats to Assets

### Threat-Asset Matrix

| Asset | Spoofing | Tampering | Repudiation | Info Disclosure | DoS | EoP |
|-------|----------|-----------|-------------|-----------------|-----|-----|
| User Database | ✓ | ✓ | | ✓ | ✓ | |
| Auth Service | ✓ | ✓ | ✓ | | ✓ | ✓ |
| API Gateway | ✓ | | | ✓ | ✓ | |
| Payment Data | | ✓ | | ✓ | | |
| Admin Console | ✓ | ✓ | ✓ | ✓ | | ✓ |

### Attack Vector Analysis

For each threat-asset combination, identify attack vectors:

**Example: Information Disclosure → User Database**

| Attack Vector | Description | Likelihood | Impact |
|---------------|-------------|------------|--------|
| SQL Injection | Malicious queries extract data | Medium | Critical |
| Misconfigured S3 | Backup exposed publicly | Low | Critical |
| Insider Access | DBA exfiltrates data | Low | Critical |
| Application Bug | API returns excessive data | Medium | High |
| Log Exposure | Sensitive data in logs | Medium | High |

---

## Industry-Specific Threat Considerations

### Financial Services

**High-Value Assets:**
- Customer financial data
- Transaction records
- Trading algorithms
- Payment card data (PCI)

**Primary Threat Actors:**
- Cybercriminals (financial motivation)
- Nation-states (economic espionage)
- Insiders (fraud)

**Key Threats:**
- Account takeover
- Wire fraud
- Data theft for identity fraud
- Market manipulation

### Healthcare

**High-Value Assets:**
- Protected Health Information (PHI)
- Medical devices
- Research data
- Prescription systems

**Primary Threat Actors:**
- Cybercriminals (ransomware)
- Nation-states (research theft)
- Insiders (snooping)

**Key Threats:**
- Ransomware disrupting care
- PHI theft for insurance fraud
- Medical device tampering
- HIPAA violations

### SaaS / Technology

**High-Value Assets:**
- Customer data (multi-tenant)
- Source code / IP
- API keys and credentials
- Infrastructure

**Primary Threat Actors:**
- Competitors
- Cybercriminals
- Nation-states (for tech IP)

**Key Threats:**
- Tenant isolation failures
- Supply chain compromise
- API abuse
- Data breaches affecting all customers

### Government

**High-Value Assets:**
- Classified information
- Citizen PII
- Critical infrastructure systems
- Election systems

**Primary Threat Actors:**
- Nation-states (primary)
- Hacktivists
- Terrorists

**Key Threats:**
- Espionage
- Disruption of services
- Disinformation
- Critical infrastructure attacks

---

## Threat Intelligence Integration

### Sources of Threat Intelligence

**Open Source (OSINT):**
- MITRE ATT&CK
- NIST NVD
- US-CERT/CISA alerts
- Security blogs and research
- CVE databases

**Commercial:**
- Threat intelligence platforms
- ISAC membership (FS-ISAC, H-ISAC)
- Vendor threat reports

**Internal:**
- Security incident history
- Penetration test results
- Bug bounty findings
- SOC observations

### Using Threat Intel in Threat Modeling

1. **Identify relevant threat actors** for your industry
2. **Map known TTPs** to your system components
3. **Prioritize threats** based on active campaigns
4. **Update threat model** when new intel emerges
5. **Validate controls** against known attack patterns

---

## Practical Exercises

### Exercise 1: Asset Identification

You're building a healthcare patient portal with:
- Patient login and profile management
- Appointment scheduling
- Medical records viewing
- Prescription refill requests
- Messaging with providers

**Task:** Create an asset inventory identifying:
1. All data assets with classification
2. System assets
3. Functional assets

### Exercise 2: Threat Actor Profiling

Your company is a mid-size fintech startup offering:
- Personal finance management
- Bank account aggregation
- Investment recommendations

**Task:**
1. Which threat actors are most relevant?
2. What are their likely targets?
3. What TTPs would they use?

### Exercise 3: Threat Mapping

Given this simple architecture:

```
[Mobile App] → [API Gateway] → [Backend Service] → [Database]
                    ↓
            [Auth Service] → [User Store]
```

**Task:** Create a threat-asset matrix showing which STRIDE categories apply to each component.

---

## Key Takeaways

1. **Know your assets** - You can't protect what you don't know about

2. **Classify data** - Not all data needs the same protection level

3. **Understand your adversaries** - Different actors have different capabilities

4. **Threat actors evolve** - Stay current with threat intelligence

5. **Industry matters** - Different sectors face different threat profiles

6. **Map threats to assets** - Creates actionable prioritization

---

## Next Steps

→ [Data Flow Diagrams Basics](dfd-basics.md)
→ [Lab 01: Basic Web Application Threat Model](../../labs/lab-01-basic-web-app/)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Understanding Assets
- Understanding Threats
- Understanding Threat Actors
- Mapping Threats to Assets

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
