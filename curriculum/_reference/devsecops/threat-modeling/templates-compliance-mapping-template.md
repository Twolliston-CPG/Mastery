# Compliance Mapping Template

## Overview

Use this template to map threat model findings to compliance framework requirements.

---

## System Compliance Profile

| Field | Value |
|-------|-------|
| System Name | |
| Owner | |
| Applicable Frameworks | [ ] PCI DSS [ ] HIPAA [ ] SOC 2 [ ] ISO 27001 [ ] GDPR [ ] Other |
| Data Classification | [ ] Public [ ] Internal [ ] Confidential [ ] Restricted |
| Last Assessment | |

---

## Data Classification Matrix

| Data Type | Classification | Applicable Regulation |
|-----------|---------------|----------------------|
| Customer names | PII | GDPR, CCPA |
| Email addresses | PII | GDPR, CCPA |
| Payment cards | Cardholder Data | PCI DSS |
| Health records | PHI | HIPAA |
| Financial data | Confidential | SOX, various |
| Auth credentials | Restricted | All |

---

## PCI DSS Mapping

### Requirement Coverage

| Req | Title | Related Threats | Controls | Status |
|-----|-------|-----------------|----------|--------|
| 1.1 | Network security controls | Network threats | Firewall, segmentation | |
| 3.4 | PAN rendering unreadable | Data exposure | Encryption, tokenization | |
| 4.1 | Strong cryptography in transit | Interception | TLS 1.2+ | |
| 6.2.4 | Software attack prevention | Injection, XSS | Input validation, WAF | |
| 7.1 | Limit access to CHD | Unauthorized access | RBAC, least privilege | |
| 8.3 | Strong authentication | Credential theft | MFA | |
| 10.1 | Audit trails | Repudiation | Logging | |
| 11.3 | Penetration testing | All threats | Annual pen test | |

### Threat to PCI Mapping

| Threat ID | Threat | PCI Requirement | Control Gap |
|-----------|--------|-----------------|-------------|
| T-001 | SQL injection | 6.2.4 | None |
| T-002 | Unencrypted PAN | 3.4 | Encryption needed |
| T-003 | Missing audit logs | 10.1 | Logging implementation |

---

## HIPAA Mapping

### Security Rule Coverage

| Standard | Section | Related Threats | Controls | Status |
|----------|---------|-----------------|----------|--------|
| Access Control | 164.312(a)(1) | Unauthorized access | RBAC, MFA | |
| Audit Controls | 164.312(b) | Repudiation | Logging | |
| Integrity | 164.312(c)(1) | Tampering | Checksums, validation | |
| Authentication | 164.312(d) | Spoofing | MFA, passwords | |
| Transmission | 164.312(e)(1) | Interception | Encryption | |

### PHI Protection Mapping

| Threat ID | Threat | HIPAA Control | Gap Analysis |
|-----------|--------|---------------|--------------|
| T-001 | PHI exposure | 164.312(e)(1) | TLS implemented |
| T-002 | Unauthorized PHI access | 164.312(a)(1) | RBAC gaps exist |
| T-003 | No audit trail | 164.312(b) | Logging needed |

---

## SOC 2 Mapping

### Trust Service Criteria

| Category | Criteria | Related Threats | Controls | Status |
|----------|----------|-----------------|----------|--------|
| Security | CC6.1 | Authentication threats | Logical access | |
| Security | CC6.6 | Transmission threats | Encryption | |
| Security | CC6.7 | Input threats | Validation | |
| Availability | CC9.1 | DoS threats | Redundancy | |
| Confidentiality | CC6.5 | Data exposure | Encryption | |
| Processing Integrity | CC8.1 | Tampering | Validation | |

### Threat to SOC 2 Mapping

| Threat ID | Threat | TSC | Evidence Required |
|-----------|--------|-----|-------------------|
| T-001 | Auth bypass | CC6.1 | Access controls |
| T-002 | Data exposure | CC6.5 | Encryption policy |
| T-003 | Input tampering | CC6.7 | Validation controls |

---

## ISO 27001 Mapping

### Annex A Controls

| Control | Title | Related Threats | Implementation | Status |
|---------|-------|-----------------|----------------|--------|
| A.8.25 | Secure development | All code threats | SDLC | |
| A.8.26 | Application security requirements | Design threats | Threat modeling | |
| A.8.27 | Secure architecture | Architecture threats | Design review | |
| A.8.28 | Secure coding | Code vulnerabilities | Code review, SAST | |
| A.8.9 | Configuration management | Config threats | CM process | |

---

## NIST CSF Mapping

### Function Coverage

| Function | Category | Related Threats | Implementation |
|----------|----------|-----------------|----------------|
| Identify | ID.RA | All threats | Risk assessment |
| Protect | PR.AC | Access threats | Access control |
| Protect | PR.DS | Data threats | Data protection |
| Detect | DE.AE | All threats | Monitoring |
| Respond | RS.AN | Incident threats | Response plan |
| Recover | RC.RP | Availability threats | Recovery plan |

---

## Compliance Evidence Checklist

### Documentation Required

| Evidence Type | Description | Location | Owner |
|---------------|-------------|----------|-------|
| Threat Model | System threat analysis | | |
| DFD | Data flow diagram | | |
| Risk Assessment | Prioritized risks | | |
| Control Matrix | Implemented controls | | |
| Remediation Plan | Gap closure plan | | |
| Test Results | Validation evidence | | |

### Audit Support

| Audit Need | Threat Model Evidence |
|------------|----------------------|
| Control justification | Threat analysis driving control selection |
| Risk assessment | Prioritized threats with ratings |
| Compliance coverage | Mapping to framework requirements |
| Due diligence | Documentation of security analysis |

---

## Gap Analysis Summary

| Framework | Requirement | Current State | Gap | Priority |
|-----------|-------------|---------------|-----|----------|
| PCI DSS | 3.4 | Partial | Tokenization needed | High |
| HIPAA | 164.312(b) | None | Audit logging | High |
| SOC 2 | CC6.1 | Partial | MFA gaps | Medium |

---

## Remediation Tracking

| Gap ID | Framework | Requirement | Remediation | Owner | Due Date | Status |
|--------|-----------|-------------|-------------|-------|----------|--------|
| G-001 | PCI DSS | 3.4 | Implement tokenization | Dev | Q2 | In Progress |
| G-002 | HIPAA | 164.312(b) | Deploy audit logging | Ops | Q2 | Open |
| G-003 | SOC 2 | CC6.1 | Expand MFA coverage | IT | Q3 | Open |

---

## Compliance Attestation

```
THREAT MODEL COMPLIANCE ATTESTATION

System: [System Name]
Date: [Date]
Prepared By: [Name]

Frameworks Assessed:
☐ PCI DSS 4.0
☐ HIPAA Security Rule
☐ SOC 2 Type II
☐ ISO 27001:2022
☐ NIST CSF

Summary:
This threat model has been reviewed for alignment with the
applicable compliance frameworks listed above.

Findings:
- [X] total threats identified
- [X] threats mapped to compliance requirements
- [X] gaps identified requiring remediation
- [X] controls verified as implemented

Attestation:
I attest that this threat model accurately represents the
security posture of the system and its alignment with
applicable compliance requirements.

Prepared By: _________________ Date: _________
Reviewed By: _________________ Date: _________
Approved By: _________________ Date: _________
```

---

## References

- [Compliance Mapping Guide](content-05-enterprise-compliance-mapping.md)
- [PCI DSS v4.0 Requirements](https://www.pcisecuritystandards.org/)
- [HIPAA Security Rule](https://www.hhs.gov/hipaa/)
- [SOC 2 Trust Services Criteria](https://www.aicpa.org/)
- [ISO 27001 Controls](https://www.iso.org/isoiec-27001-information-security.html)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- System Compliance Profile
- Data Classification Matrix
- PCI DSS Mapping
- HIPAA Mapping

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
