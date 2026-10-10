# Compliance Mapping for Threat Modeling

## Overview

Threat modeling supports compliance with security frameworks by demonstrating systematic risk identification and control selection. This guide covers mapping threat models to major compliance frameworks.

---

## Framework Mapping Matrix

| Framework | Threat Modeling Requirement | Key Controls |
|-----------|---------------------------|--------------|
| PCI DSS 4.0 | Req 6.3.2 - Design review | 6.2.4, 6.3, 6.4 |
| HIPAA | § 164.308(a)(1) - Risk analysis | Technical safeguards |
| SOC 2 | CC3.2 - Risk assessment | CC6, CC7 |
| ISO 27001 | A.8.25 - Secure development | A.8.26, A.8.27 |
| NIST CSF | ID.RA - Risk assessment | ID.RA-1 to ID.RA-6 |
| FedRAMP | RA-3 - Risk assessment | SC family |

---

## PCI DSS 4.0

### Relevant Requirements

```yaml
pci_dss_mapping:
  requirement_6.3.2:
    title: "Review software development policies and procedures"
    threat_model_evidence:
      - Threat modeling process documentation
      - Evidence of threat models for payment systems
      - Secure coding standards derived from threats

  requirement_6.2.4:
    title: "Software attack techniques prevented"
    threat_model_evidence:
      - STRIDE analysis covering common attacks
      - Injection prevention controls
      - Authentication bypass prevention

  requirement_6.3.3:
    title: "Security vulnerabilities identified"
    threat_model_evidence:
      - Threat model findings
      - Risk ratings
      - Remediation tracking
```

### Evidence Requirements

| Control | Threat Model Evidence |
|---------|----------------------|
| 6.2.4 | STRIDE threats mapped to OWASP Top 10 |
| 6.3.2 | Process documents, completed models |
| 6.3.3 | Finding log with CVE/CWE mapping |
| 6.4.1 | Public-facing app threat models |
| 6.4.2 | WAF rule justification from threats |

### Sample Threat Model Report for PCI

```markdown
## PCI DSS Threat Model Report

### System: Payment Processing API
### Scope: Cardholder Data Environment (CDE)

### Data Flow Summary
- Card data enters via API Gateway
- Transmitted to payment processor (encrypted)
- Tokens stored in database (no CHD storage)

### STRIDE Analysis

| Threat | Control | PCI Requirement |
|--------|---------|-----------------|
| Credential theft | MFA, encryption | 8.3, 4.2 |
| SQL injection | Parameterized queries | 6.2.4 |
| Data interception | TLS 1.2+ | 4.2.1 |
| Unauthorized access | RBAC | 7.1, 7.2 |

### Residual Risk
- Low: All identified threats have controls
- Monitoring: GuardDuty, CloudTrail for detection
```

---

## HIPAA

### Security Rule Mapping

```yaml
hipaa_mapping:
  administrative_safeguards:
    164.308_a_1:
      title: "Security Management Process - Risk Analysis"
      threat_model_evidence:
        - PHI system threat models
        - Risk ratings
        - Treatment plans

    164.308_a_3:
      title: "Workforce Security"
      threat_model_evidence:
        - Insider threat analysis
        - Access control threats
        - Role-based access design

  technical_safeguards:
    164.312_a_1:
      title: "Access Control"
      threat_model_evidence:
        - Authentication threats
        - Authorization model
        - Session management threats

    164.312_e_1:
      title: "Transmission Security"
      threat_model_evidence:
        - Data flow diagrams
        - Encryption requirements
        - Network threats
```

### PHI System Threat Model Template

```yaml
system: Patient Portal
phi_types:
  - Patient demographics
  - Medical records
  - Insurance information

data_flows:
  - flow: Patient → Portal
    data: Credentials, health queries
    encryption: TLS 1.3
    hipaa_control: 164.312(e)(1)

  - flow: Portal → EHR Database
    data: PHI queries/updates
    encryption: TLS + AES-256 at rest
    hipaa_control: 164.312(a)(2)(iv)

threats:
  - threat: Unauthorized PHI access
    stride: Information Disclosure
    hipaa_impact: Breach notification required
    controls:
      - Role-based access (164.312(a)(1))
      - Audit logging (164.312(b))
      - Encryption (164.312(e)(2))

  - threat: PHI modification
    stride: Tampering
    hipaa_impact: Data integrity violation
    controls:
      - Input validation
      - Integrity checks
      - Audit trail
```

---

## SOC 2

### Trust Service Criteria Mapping

| TSC | Threat Model Contribution |
|-----|---------------------------|
| CC3.1 | Risk assessment process includes threat modeling |
| CC3.2 | Threat identification methodology |
| CC6.1 | Logical access threats and controls |
| CC6.6 | Transmission threats and encryption |
| CC6.7 | Input/output threat analysis |
| CC7.1 | Vulnerability identification |
| CC7.2 | Anomaly detection requirements |

### SOC 2 Evidence Package

```markdown
## Threat Modeling Program - SOC 2 Evidence

### CC3.2 - Risk Identification
Evidence: Threat modeling process document
- Methodology: STRIDE
- Trigger: All new systems, major changes
- Frequency: Annual refresh

### CC6.1 - Logical Access
Evidence: Authentication threat analysis
- Threats: Credential theft, session hijacking
- Controls: MFA, token expiration, session binding
- Testing: Penetration test validation

### CC6.6 - Transmission Security
Evidence: Data flow diagram
- All PII flows identified
- Encryption requirements defined
- TLS 1.3 enforced

### CC7.1 - Vulnerability Identification
Evidence: Threat model findings log
- 45 threats identified Q1
- 38 remediated
- 7 accepted with justification
```

---

## ISO 27001

### Annex A Mapping

| Control | Threat Model Evidence |
|---------|----------------------|
| A.8.25 | Secure development lifecycle includes threat modeling |
| A.8.26 | Application security requirements from threat model |
| A.8.27 | Secure architecture based on threat analysis |
| A.8.28 | Secure coding from threat mitigation |
| A.8.9 | Configuration management threats |

### ISMS Integration

```yaml
isms_integration:
  risk_assessment:
    - Threat models feed ISMS risk register
    - Consistent risk rating methodology
    - Treatment plans align with ISMS

  documentation:
    - Threat models stored in document management
    - Version controlled
    - Regular review cycle

  audit:
    - Threat models reviewed in internal audits
    - External auditors reference as evidence
    - Findings tracked in corrective actions
```

---

## NIST Cybersecurity Framework

### Function Mapping

| Function | Category | Threat Model Contribution |
|----------|----------|---------------------------|
| Identify | ID.RA | Risk assessment process |
| Protect | PR.DS | Data security controls |
| Protect | PR.AC | Access control design |
| Detect | DE.AE | Anomaly detection requirements |
| Respond | RS.AN | Incident scenarios |

### CSF Profile with Threat Modeling

```yaml
csf_profile:
  identify:
    ID.RA-1:
      activity: "Asset vulnerabilities identified"
      threat_model: "DFD identifies assets and data flows"

    ID.RA-3:
      activity: "Threats identified"
      threat_model: "STRIDE analysis per component"

    ID.RA-5:
      activity: "Risks determined"
      threat_model: "Risk ratings with likelihood/impact"

  protect:
    PR.DS-1:
      activity: "Data-at-rest protected"
      threat_model: "Encryption requirements from I threats"

    PR.DS-2:
      activity: "Data-in-transit protected"
      threat_model: "TLS requirements from data flows"
```

---

## Compliance Documentation Template

```markdown
# Threat Model Compliance Report

## System Information
- **System Name**: [Name]
- **Owner**: [Owner]
- **Compliance Frameworks**: [PCI DSS, HIPAA, SOC 2]
- **Threat Model Date**: [Date]
- **Next Review**: [Date]

## Regulatory Data Classification
| Data Type | Regulation | Classification |
|-----------|------------|----------------|
| Payment card | PCI DSS | Cardholder data |
| Patient info | HIPAA | PHI |
| Customer PII | GDPR/CCPA | Personal data |

## Threat Analysis Summary
| Threat Category | Count | High Risk | Mitigated |
|-----------------|-------|-----------|-----------|
| Spoofing | 3 | 1 | 3 |
| Tampering | 5 | 2 | 5 |
| Repudiation | 2 | 0 | 2 |
| Info Disclosure | 4 | 2 | 4 |
| DoS | 2 | 0 | 2 |
| Elevation | 3 | 1 | 3 |

## Control Mapping
| Threat | Control | Framework Requirement |
|--------|---------|----------------------|
| Credential theft | MFA | PCI 8.3, HIPAA 164.312(d) |
| Data exposure | Encryption | PCI 4.2, HIPAA 164.312(e) |
| SQL injection | Parameterized queries | PCI 6.2.4 |

## Auditor Notes
[Space for auditor comments and sign-off]
```

---

## Next Steps

→ [Scaling Threat Modeling](scaling.md)
→ [Risk Communication](risk-communication.md)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Framework Mapping Matrix
- PCI DSS 4.0
- PCI DSS Threat Model Report
- HIPAA

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
