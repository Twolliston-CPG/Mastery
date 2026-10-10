# Risk Assessment Template

## Overview

Use this template to consistently assess and prioritize threats identified during threat modeling.

---

## Risk Rating Methodology

### DREAD Model (Optional)

| Factor | Description | Scale |
|--------|-------------|-------|
| **D**amage | How bad would an attack be? | 1-10 |
| **R**eproducibility | How easy to reproduce? | 1-10 |
| **E**xploitability | How much work to exploit? | 1-10 |
| **A**ffected users | How many users impacted? | 1-10 |
| **D**iscoverability | How easy to discover? | 1-10 |

Risk Score = (D + R + E + A + D) / 5

### Simplified Risk Matrix (Recommended)

| Likelihood ↓ &nbsp; Impact → | **Low** | **Medium** | **High** |
|---|---|---|---|
| **High** | Medium | High | **Critical** |
| **Medium** | Low | Medium | High |
| **Low** | Low | Low | Medium |

Read a cell as *"if this happened, how bad, and how likely is it."* The diagonal is the argument you
will actually have: a critical impact that is very unlikely and a medium impact that is near-certain
land in different cells, and only one of them gets funded this quarter.

---

## Likelihood Assessment

### Likelihood Factors

| Factor | Low | Medium | High |
|--------|-----|--------|------|
| Attacker skill required | Expert | Moderate | Beginner |
| Attack complexity | Complex multi-step | Moderate | Simple |
| Access required | Physical/privileged | Authenticated | Public |
| Existing exploitation | No known exploits | PoC exists | Active exploitation |
| Detection probability | Easily detected | Moderate | Difficult to detect |

### Likelihood Definitions

| Level | Description | Probability |
|-------|-------------|-------------|
| **Low** | Unlikely to occur | < 25% |
| **Medium** | Could reasonably occur | 25-75% |
| **High** | Likely to occur | > 75% |

---

## Impact Assessment

### Impact Factors

| Factor | Low | Medium | High |
|--------|-----|--------|------|
| Data exposure | Non-sensitive | Internal only | PII/Financial/PHI |
| System affected | Non-critical | Important | Critical |
| Regulatory | No violation | Minor violation | Major violation |
| Financial | < $10K | $10K - $100K | > $100K |
| Reputational | None | Limited | Significant |
| Operational | Minimal disruption | Partial outage | Full outage |

### Impact Definitions

| Level | Description |
|-------|-------------|
| **Low** | Minor inconvenience, easily recoverable |
| **Medium** | Moderate damage, requires effort to recover |
| **High** | Significant damage, major recovery effort |
| **Critical** | Severe damage, business-threatening |

---

## Risk Assessment Worksheet

### Threat Entry

| Field | Value |
|-------|-------|
| Threat ID | T-001 |
| Threat Description | SQL injection in user search |
| STRIDE Category | Tampering, Information Disclosure |
| Affected Component | Search API |
| Attack Vector | Authenticated user input |

### Likelihood Scoring

| Factor | Score | Justification |
|--------|-------|---------------|
| Skill required | High (3) | Basic SQL knowledge needed |
| Complexity | High (3) | Simple injection pattern |
| Access required | Medium (2) | Requires authentication |
| Existing exploitation | High (3) | Well-known attack type |
| Detection | Medium (2) | WAF may detect |
| **Overall Likelihood** | **High** | Multiple high factors |

### Impact Scoring

| Factor | Score | Justification |
|--------|-------|---------------|
| Data exposure | High (3) | Could expose all user data |
| System affected | High (3) | Production database |
| Regulatory | High (3) | GDPR, PCI implications |
| Financial | Medium (2) | Breach response costs |
| Reputational | High (3) | Customer trust impact |
| Operational | Medium (2) | DB may need recovery |
| **Overall Impact** | **High** | Multiple high factors |

### Risk Calculation

| Likelihood | Impact | Risk Level |
|------------|--------|------------|
| High | High | **Critical** |

---

## Risk Register

| ID | Threat | Likelihood | Impact | Risk | Status | Owner |
|----|--------|------------|--------|------|--------|-------|
| T-001 | SQL injection | High | High | Critical | Open | Dev Team |
| T-002 | Session hijacking | Medium | High | High | Mitigated | Security |
| T-003 | DoS on API | High | Medium | High | Accepted | Ops |
| T-004 | Log injection | Low | Low | Low | Open | Dev Team |

---

## Risk Treatment Options

### Treatment Strategies

| Strategy | Description | When to Use |
|----------|-------------|-------------|
| **Mitigate** | Implement controls to reduce risk | Risk is too high to accept |
| **Accept** | Accept the risk as-is | Cost of mitigation exceeds risk |
| **Transfer** | Transfer risk to third party | Insurance, outsourcing |
| **Avoid** | Eliminate the risk source | Risk cannot be adequately mitigated |

### Treatment Plan Template

| Field | Value |
|-------|-------|
| Threat ID | T-001 |
| Current Risk | Critical |
| Treatment Strategy | Mitigate |
| Proposed Controls | Parameterized queries, input validation, WAF rules |
| Implementation Owner | Development Team |
| Target Date | 2024-03-15 |
| Residual Risk | Low |
| Verification Method | SAST scan, penetration test |

---

## Prioritization Matrix

### Priority Assignment

| Risk Level | Priority | SLA |
|------------|----------|-----|
| Critical | P1 | Fix within 7 days |
| High | P2 | Fix within 30 days |
| Medium | P3 | Fix within 90 days |
| Low | P4 | Track, fix as capacity allows |

### Prioritized Findings

| Priority | ID | Threat | Risk | Target Date |
|----------|----|----|------|-------------|
| P1 | T-001 | SQL injection | Critical | 2024-03-15 |
| P2 | T-002 | Session hijacking | High | 2024-03-30 |
| P2 | T-003 | DoS on API | High | 2024-03-30 |
| P4 | T-004 | Log injection | Low | Backlog |

---

## Risk Acceptance Template

For risks that will be accepted:

```
RISK ACCEPTANCE FORM

Threat ID: T-003
Description: Denial of Service on public API

Risk Level: High
Likelihood: High | Impact: Medium

Justification for Acceptance:
- Rate limiting provides partial mitigation
- Auto-scaling handles burst traffic
- Cost of full DDoS protection exceeds risk
- Business accepts occasional degradation

Compensating Controls:
1. Rate limiting per IP
2. Auto-scaling configuration
3. Monitoring and alerting
4. Incident response playbook

Accepted By: [Name]
Title: [Title]
Date: [Date]

Review Date: [Annual review date]
```

---

## Metrics

### Risk Metrics to Track

| Metric | Calculation | Target |
|--------|-------------|--------|
| Open Critical Risks | Count of P1 open | 0 |
| Open High Risks | Count of P2 open | < 5 |
| Average Time to Remediate | Mean days to close | < 30 days |
| Risk Acceptance Rate | Accepted / Total | < 10% |
| Finding Discovery Rate | Findings per threat model | 5-15 |

---

## References

- [STRIDE Worksheet](stride-worksheet.md)
- [Threat Model Template](threat-model-template.md)
- [OWASP Risk Rating Methodology](https://owasp.org/www-community/OWASP_Risk_Rating_Methodology)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Risk Rating Methodology
- Likelihood Assessment
- Impact Assessment
- Risk Assessment Worksheet

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
