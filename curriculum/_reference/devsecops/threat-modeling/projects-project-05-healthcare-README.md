# Project 5: Healthcare System Threat Model (HIPAA)

## Overview

Create a comprehensive threat model for a healthcare application that handles Protected Health Information (PHI). This project focuses on healthcare-specific threats and HIPAA compliance requirements.

**Difficulty:** Advanced
**Estimated Time:** 12-15 hours
**Prerequisites:** Projects 1-3, Compliance Mapping module

---

## Scenario

You're the security architect for "HealthConnect," a telehealth platform connecting patients with healthcare providers. The platform handles PHI and must comply with HIPAA regulations.

### System Description

HealthConnect provides:
- Patient portal for appointment scheduling
- Video consultations with providers
- Secure messaging between patients and providers
- Electronic health records (EHR) integration
- Prescription management
- Insurance verification and billing

### Architecture

<!-- figure: generated from the Mermaid below by _shared/diagrams/embed-figures.py — do not edit the image -->
![Architecture — diagram](../../../../_figures/curriculum-_reference-devsecops-threat-modeling-projects-project-05-healthcare-README-0-1363b73a.png)

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
  subgraph U["Users"]
    direction LR
    PAT["Patients<br/><i>web and mobile</i>"]
    PRO["Providers<br/><i>web and mobile</i>"]
    ADM["Administrators"]
  end
  subgraph PRES["Presentation layer"]
    direction LR
    CDN(["CDN"])
    WAF(["WAF"])
    ALB(["Load balancer"])
    CDN ==> WAF ==> ALB
  end
  subgraph APP["Application layer"]
    direction LR
    PP(["Patient portal API"])
    PVP(["Provider portal API"])
    AA(["Admin API"])
    TH(["Telehealth service"])
    MSG(["Messaging service"])
    SCH(["Scheduling service"])
  end
  subgraph DATA["Data layer"]
    direction LR
    PG[("PostgreSQL<br/><i>PHI</i>")]
    S3[("Object storage<br/><i>documents</i>")]
    EC[("Cache<br/><i>sessions</i>")]
  end
  subgraph INT["Integration layer"]
    direction LR
    EHR["EHR systems<br/><i>HL7 FHIR</i>"]
    INS["Insurance eligibility"]
    RX["Pharmacy e-prescribing"]
    VID["Video provider"]
    NOT["SMS and email"]
    PAYP["Payment provider"]
  end
  subgraph SEC["Security and compliance"]
    direction LR
    CT["Audit logging"]
    GD["Threat detection"]
    CFG["Configuration compliance"]
    KMS["KMS — encryption"]
    SM["Secrets manager"]
    IAM["IAM"]
  end
  U ==> CDN
  ALB ==> APP ==> DATA
  APP <==> INT
  SEC -.->|"monitors and protects every layer"| DATA
  class PAT,PRO mut
  class ADM crit
  class CDN,ALB n
  class WAF crit
  class PP,PVP,TH,MSG,SCH n
  class AA crit
  class PG crit
  class S3,EC data
  class EHR crit
  class INS,RX,VID,NOT mut
  class PAYP crit
  class CT,KMS,IAM crit
  class GD,CFG,SM n
  linkStyle 2,3,4,5,6 stroke:#2f6fb8,stroke-width:2px

%% Six external integrations, and every one of them is a business associate
%% under HIPAA -- which means each needs an agreement, and each is a place PHI
%% leaves your control while remaining your liability. The integration layer,
%% not the data layer, is where most of the compliance work lives.
```

</details>

### PHI Data Types
- Patient demographics (name, DOB, SSN, address)
- Medical records (diagnoses, treatments, medications)
- Insurance information
- Provider notes
- Video consultation recordings
- Secure messages

### Compliance Requirements
- HIPAA Privacy Rule
- HIPAA Security Rule
- HITECH Act
- State health privacy laws

---

## Project Tasks

### Task 1: PHI Data Inventory

Document all PHI:
- Data elements and classification
- Storage locations
- Processing systems
- Transmission paths
- Access controls

**Deliverable:** PHI data inventory with ePHI flow diagram

### Task 2: HIPAA Security Rule Mapping

Map threats to HIPAA requirements:
- Administrative safeguards
- Physical safeguards
- Technical safeguards

**Deliverable:** HIPAA control mapping matrix

### Task 3: Access Control Analysis

Analyze access to PHI:
- Authentication mechanisms
- Authorization models
- Role definitions
- Access logging

**Deliverable:** Access control assessment

### Task 4: Encryption Analysis

Assess encryption controls:
- Data at rest encryption
- Data in transit encryption
- Key management
- Encryption exceptions

**Deliverable:** Encryption assessment

### Task 5: Third-Party (BAA) Risk Analysis

Assess Business Associate risks:
- Identify all Business Associates
- Document PHI sharing
- Assess BA security posture
- Review BAA requirements

**Deliverable:** Business Associate risk assessment

### Task 6: Breach Scenario Analysis

Develop breach scenarios:
- Unauthorized PHI access
- PHI disclosure
- PHI modification
- System unavailability

**Deliverable:** Breach scenario documentation

### Task 7: STRIDE Analysis with HIPAA Context

Apply STRIDE with healthcare focus:
- Map threats to HIPAA requirements
- Consider patient safety implications
- Include insider threat scenarios

**Deliverable:** Healthcare-specific STRIDE analysis

### Task 8: Final Threat Model Report

Compile comprehensive analysis:
- Executive summary
- System overview
- PHI inventory
- HIPAA compliance mapping
- Threat analysis
- Risk assessment
- Recommendations

**Deliverable:** Complete threat model (30-40 pages)

---

## Healthcare-Specific Threats

### PHI Confidentiality
- Unauthorized access to patient records
- PHI exposure in logs or errors
- Business associate data breach
- Insider snooping

### PHI Integrity
- Medical record tampering
- Prescription modification
- Insurance fraud
- EHR data corruption

### PHI Availability
- Ransomware attacks
- System outages affecting care
- Data loss without backup
- Denial of service

### Patient Safety
- Telehealth session hijacking
- Prescription tampering
- Identity theft affecting care
- Provider impersonation

### Compliance Risks
- Audit trail gaps
- Insufficient access controls
- Inadequate encryption
- BAA violations

---

## HIPAA Threat Mapping

| STRIDE | HIPAA Safeguard | Example Threat |
|--------|-----------------|----------------|
| Spoofing | 164.312(d) | Provider account takeover |
| Tampering | 164.312(c)(1) | Medical record modification |
| Repudiation | 164.312(b) | Denied access to records |
| Info Disclosure | 164.312(e)(1) | PHI exposure in transit |
| DoS | 164.308(a)(7) | Ransomware attack |
| Elevation | 164.312(a)(1) | Admin privilege abuse |

---

## Evaluation Criteria

| Criterion | Weight | Description |
|-----------|--------|-------------|
| PHI Inventory | 15% | Complete data inventory |
| HIPAA Mapping | 20% | Security Rule compliance |
| Access Control | 15% | Authorization analysis |
| Encryption | 10% | Data protection |
| BA Risk | 15% | Third-party assessment |
| Threat Analysis | 15% | Comprehensive STRIDE |
| Documentation | 10% | Professional presentation |

---

## Submission Requirements

1. **PHI Inventory** - All PHI documented with flows
2. **HIPAA Mapping** - Threats to requirements matrix
3. **Access Control Review** - Authentication/authorization
4. **Encryption Assessment** - At-rest and in-transit
5. **BA Risk Assessment** - Third-party analysis
6. **Breach Scenarios** - Potential incident types
7. **Threat Model Report** - Complete document

---

## Extension Challenges

1. **Add IoT Devices:** Include medical device integration (e.g., patient monitors)

2. **HITRUST Mapping:** Extend to HITRUST CSF controls

3. **Incident Response:** Develop HIPAA breach notification procedures

4. **Patient Safety Analysis:** Conduct safety-focused threat analysis

---

## Resources

- [HIPAA Security Rule](https://www.hhs.gov/hipaa/for-professionals/security/)
- [NIST HIPAA Guidance](https://csrc.nist.gov/pubs/sp/800/66/r2/final)
- [Compliance Mapping Guide](../content/05-enterprise/compliance-mapping.md)
- [HHS Breach Portal](https://ocrportal.hhs.gov/ocr/breach/breach_report.jsf)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Healthcare-Specific Threats
- HIPAA Threat Mapping
- PHI Data Types
- Compliance Requirements

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
