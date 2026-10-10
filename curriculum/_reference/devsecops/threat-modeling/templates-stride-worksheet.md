# STRIDE Analysis Worksheet

## System Information

| Field | Value |
|-------|-------|
| System Name | |
| Component Being Analyzed | |
| Analyst | |
| Date | |

---

## Quick Reference

| Category | Threat Type | Security Property | Key Question |
|----------|-------------|-------------------|--------------|
| **S**poofing | Identity fraud | Authentication | Can someone pretend to be someone else? |
| **T**ampering | Data modification | Integrity | Can data be modified maliciously? |
| **R**epudiation | Deny actions | Non-repudiation | Can actions be denied? |
| **I**nfo Disclosure | Data exposure | Confidentiality | Can data be accessed by unauthorized parties? |
| **D**enial of Service | Availability impact | Availability | Can the system be made unavailable? |
| **E**levation of Privilege | Unauthorized access | Authorization | Can someone gain more access than allowed? |

---

## Element Analysis

### Element Details

| Attribute | Value |
|-----------|-------|
| Element Name | |
| Element Type | External Entity / Process / Data Store / Data Flow |
| Trust Boundary | Inside / Outside / Crossing |
| Description | |

---

## STRIDE Analysis

### S - Spoofing

**Question:** How is this element's identity verified? Can an attacker impersonate this element or its users?

**Applicable to this element?** [ ] Yes [ ] No

**Threats Identified:**

| Threat ID | Description | Attack Vector | Likelihood | Impact |
|-----------|-------------|---------------|------------|--------|
| S-001 | | | L/M/H | L/M/H |
| S-002 | | | | |

**Existing Controls:**
-

**Recommended Mitigations:**
-

---

### T - Tampering

**Question:** Can data in or processed by this element be modified maliciously?

**Applicable to this element?** [ ] Yes [ ] No

**Threats Identified:**

| Threat ID | Description | Attack Vector | Likelihood | Impact |
|-----------|-------------|---------------|------------|--------|
| T-001 | | | L/M/H | L/M/H |
| T-002 | | | | |

**Existing Controls:**
-

**Recommended Mitigations:**
-

---

### R - Repudiation

**Question:** Are actions by or to this element logged and attributed? Can someone deny performing an action?

**Applicable to this element?** [ ] Yes [ ] No

**Threats Identified:**

| Threat ID | Description | Attack Vector | Likelihood | Impact |
|-----------|-------------|---------------|------------|--------|
| R-001 | | | L/M/H | L/M/H |
| R-002 | | | | |

**Existing Controls:**
-

**Recommended Mitigations:**
-

---

### I - Information Disclosure

**Question:** Can data be accessed by unauthorized parties? Is sensitive data exposed?

**Applicable to this element?** [ ] Yes [ ] No

**Threats Identified:**

| Threat ID | Description | Attack Vector | Likelihood | Impact |
|-----------|-------------|---------------|------------|--------|
| I-001 | | | L/M/H | L/M/H |
| I-002 | | | | |

**Existing Controls:**
-

**Recommended Mitigations:**
-

---

### D - Denial of Service

**Question:** Can this element be made unavailable or its performance degraded?

**Applicable to this element?** [ ] Yes [ ] No

**Threats Identified:**

| Threat ID | Description | Attack Vector | Likelihood | Impact |
|-----------|-------------|---------------|------------|--------|
| D-001 | | | L/M/H | L/M/H |
| D-002 | | | | |

**Existing Controls:**
-

**Recommended Mitigations:**
-

---

### E - Elevation of Privilege

**Question:** Can someone gain unauthorized access or capabilities through this element?

**Applicable to this element?** [ ] Yes [ ] No

**Threats Identified:**

| Threat ID | Description | Attack Vector | Likelihood | Impact |
|-----------|-------------|---------------|------------|--------|
| E-001 | | | L/M/H | L/M/H |
| E-002 | | | | |

**Existing Controls:**
-

**Recommended Mitigations:**
-

---

## Summary

### Threats by Category

| Category | Count | Highest Risk |
|----------|-------|--------------|
| Spoofing | | |
| Tampering | | |
| Repudiation | | |
| Information Disclosure | | |
| Denial of Service | | |
| Elevation of Privilege | | |
| **Total** | | |

### Top Threats

| Priority | Threat ID | Description | Recommended Action |
|----------|-----------|-------------|-------------------|
| 1 | | | |
| 2 | | | |
| 3 | | | |

---

## Notes

*Additional observations, assumptions, or areas requiring further investigation:*

---

*Worksheet completed by:* _________________ *Date:* _________________

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- System Information
- Quick Reference
- Element Analysis
- STRIDE Analysis

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
