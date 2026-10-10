# Threat Model Document Template

## Document Information

| Field | Value |
|-------|-------|
| **System Name** | |
| **Version** | |
| **Author** | |
| **Date Created** | |
| **Last Updated** | |
| **Status** | Draft / In Review / Approved |
| **Review Cycle** | Quarterly / On Change |

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | | | Initial version |
| | | | |

---

## 1. Executive Summary

### 1.1 Purpose
*Brief description of why this threat model was created and what it covers.*

### 1.2 Scope
*Define what's in scope and out of scope.*

| In Scope | Out of Scope |
|----------|--------------|
| | |

### 1.3 Key Findings Summary

| Risk Level | Count |
|------------|-------|
| Critical | |
| High | |
| Medium | |
| Low | |

### 1.4 Top 3 Risks

1. **[Risk Name]**: Brief description and recommended action
2. **[Risk Name]**: Brief description and recommended action
3. **[Risk Name]**: Brief description and recommended action

---

## 2. System Overview

### 2.1 Business Context
*What does this system do? What business value does it provide?*

### 2.2 Technology Stack

| Layer | Technology |
|-------|------------|
| Frontend | |
| Backend | |
| Database | |
| Cloud/Hosting | |
| Authentication | |
| Other | |

### 2.3 Data Classification

| Data Type | Classification | Storage | Notes |
|-----------|----------------|---------|-------|
| | Public/Internal/Confidential/Restricted | | |

### 2.4 Compliance Requirements
*List applicable compliance requirements (PCI DSS, HIPAA, GDPR, SOC 2, etc.)*

- [ ] PCI DSS
- [ ] HIPAA
- [ ] GDPR
- [ ] SOC 2
- [ ] FedRAMP
- [ ] Other: ___

---

## 3. Architecture

### 3.1 Architecture Diagram
*Insert or reference architecture diagram*

### 3.2 Data Flow Diagram

```
[Insert DFD here]
```

### 3.3 Trust Boundaries

| Boundary | Description | Components |
|----------|-------------|------------|
| TB1 | | |
| TB2 | | |

### 3.4 Entry Points

| ID | Entry Point | Protocol | Authentication | Description |
|----|-------------|----------|----------------|-------------|
| EP1 | | | | |
| EP2 | | | | |

### 3.5 Assets

| ID | Asset | Type | Classification | Owner |
|----|-------|------|----------------|-------|
| A1 | | Data/System/Function | | |
| A2 | | | | |

### 3.6 External Dependencies

| Dependency | Type | Trust Level | Data Shared |
|------------|------|-------------|-------------|
| | Third-party API/Service/Library | | |

---

## 4. Threat Identification

### 4.1 Methodology
*Describe the methodology used (STRIDE, PASTA, etc.)*

### 4.2 Threat Actors

| Actor | Capability | Motivation | Target |
|-------|------------|------------|--------|
| | Low/Medium/High | | |

### 4.3 Threat List

| ID | Component | Category | Threat Description | Attack Vector |
|----|-----------|----------|-------------------|---------------|
| T001 | | S/T/R/I/D/E | | |
| T002 | | | | |
| T003 | | | | |

---

## 5. Risk Assessment

### 5.1 Risk Matrix

| Likelihood ↓ &nbsp; Impact → | **Low** | **Medium** | **High** | **Critical** |
|---|---|---|---|---|
| **High** | Medium | High | **Critical** | **Critical** |
| **Medium** | Low | Medium | High | **Critical** |
| **Low** | Low | Low | Medium | High |

The cell is not the decision — it is the start of the conversation. Two findings in the same cell can
get different treatment because one has a cheap compensating control and the other does not.

### 5.2 Risk Register

| Threat ID | Threat | Likelihood | Impact | Risk Score | Existing Controls | Residual Risk |
|-----------|--------|------------|--------|------------|-------------------|---------------|
| T001 | | L/M/H | L/M/H/C | | | |
| T002 | | | | | | |

---

## 6. Mitigations

### 6.1 Mitigation Summary

| Threat ID | Mitigation | Type | Status | Owner | Due Date |
|-----------|------------|------|--------|-------|----------|
| T001 | | Prevent/Detect/Correct | Not Started/In Progress/Done | | |

### 6.2 Mitigation Details

#### T001: [Threat Name]

**Description:** [Detailed threat description]

**Mitigation Strategy:**
- [ ] Control 1
- [ ] Control 2
- [ ] Control 3

**Implementation Notes:**
*Technical details for implementation*

**Verification:**
*How to verify the mitigation is effective*

---

## 7. Residual Risks

| Threat ID | Residual Risk Description | Accepted By | Date | Review Date |
|-----------|---------------------------|-------------|------|-------------|
| | | | | |

---

## 8. Assumptions and Constraints

### 8.1 Assumptions
1.
2.
3.

### 8.2 Constraints
1.
2.
3.

---

## 9. Action Items

| ID | Action | Owner | Priority | Status | Due Date |
|----|--------|-------|----------|--------|----------|
| | | | P0/P1/P2 | | |

---

## 10. Appendices

### Appendix A: Detailed DFDs
*Additional diagrams*

### Appendix B: STRIDE Analysis Tables
*Detailed STRIDE analysis*

### Appendix C: References
*External references, standards, threat intelligence*

### Appendix D: Glossary
*Terms and definitions*

---

## Approvals

| Role | Name | Signature | Date |
|------|------|-----------|------|
| Security Architect | | | |
| Engineering Lead | | | |
| Product Owner | | | |
| CISO/Security Lead | | | |

---

*Template Version: 1.0*
*Last Updated: January 2026*

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Document Information
- Revision History
- System Overview
- Threat Identification

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
