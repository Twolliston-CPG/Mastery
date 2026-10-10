# Lab 1: Security Fundamentals and Threat Modeling

## Objectives

- Understand core security principles and their application
- Perform STRIDE threat modeling on a sample application
- Create security requirements from threat analysis
- Document and prioritize security risks

## Prerequisites

- Basic understanding of web application architecture
- Familiarity with common attack vectors
- Access to a diagramming tool (draw.io, Lucidchart, or similar)

## Duration

2 hours

## Lab Environment

For this lab, you'll analyze a fictional e-commerce application with the following components:
- Web frontend (React)
- API backend (Node.js)
- PostgreSQL database
- Redis cache
- Payment service integration
- User authentication via OAuth2

## Part 1: Security Principles Analysis (30 minutes)

### Task 1.1: Identify CIA Triad Elements

Analyze the e-commerce application and identify assets that require protection:

```markdown
# CIA Triad Analysis

## Confidentiality
List data/assets requiring confidentiality:
1. User credentials (passwords, tokens)
2. Payment card information
3. Personal user data (email, address)
4. Order history
5. [Add more...]

## Integrity
List data/processes requiring integrity:
1. Transaction records
2. Product pricing
3. Inventory counts
4. User account details
5. [Add more...]

## Availability
List services requiring high availability:
1. Shopping cart functionality
2. Checkout process
3. Product catalog
4. User authentication
5. [Add more...]
```

### Task 1.2: Apply Defense in Depth

Document security controls at each layer:

```markdown
# Defense in Depth - E-commerce Application

## Network Layer
- [ ] Web Application Firewall (WAF)
- [ ] DDoS protection
- [ ] Network segmentation
- [ ] TLS/SSL encryption

## Host Layer
- [ ] OS hardening
- [ ] Host-based firewall
- [ ] Endpoint protection
- [ ] Patch management

## Application Layer
- [ ] Input validation
- [ ] Output encoding
- [ ] Authentication/Authorization
- [ ] Session management
- [ ] API security

## Data Layer
- [ ] Encryption at rest
- [ ] Encryption in transit
- [ ] Database access controls
- [ ] Data masking
- [ ] Backup encryption
```

## Part 2: STRIDE Threat Modeling (60 minutes)

### Task 2.1: Create Data Flow Diagram

Create a Level 1 DFD for the e-commerce checkout process:

```
                                  Trust Boundary
                                       |
    +--------+    HTTPS     +----------v---------+
    |  User  |------------->|   Load Balancer    |
    +--------+              +----------+---------+
                                       |
                            +----------v---------+
                            |    Web Frontend    |
                            +----------+---------+
                                       |
                  Trust Boundary       |
                       |               |
              +--------v---------------v--------+
              |           API Gateway           |
              +--------+---------------+--------+
                       |               |
           +-----------v---+   +-------v-----------+
           |  Auth Service |   |  Payment Service  |---> External Payment
           +-------+-------+   +-------+-----------+     Provider
                   |                   |
              +----v-------------------v----+
              |         PostgreSQL          |
              +-----------------------------+
```

### Task 2.2: Apply STRIDE to Each Component

For each component, identify threats using STRIDE:

```markdown
# STRIDE Analysis: API Gateway

## Spoofing
- Threat: Attacker spoofs API requests using stolen tokens
- Likelihood: Medium
- Impact: High
- Mitigation: Token validation, short expiry, refresh tokens

## Tampering
- Threat: Man-in-the-middle modifies API requests
- Likelihood: Low (with TLS)
- Impact: High
- Mitigation: TLS everywhere, request signing, integrity checks

## Repudiation
- Threat: User denies making a purchase
- Likelihood: Medium
- Impact: Medium
- Mitigation: Comprehensive audit logging, digital signatures

## Information Disclosure
- Threat: Sensitive data exposed in API responses
- Likelihood: Medium
- Impact: High
- Mitigation: Response filtering, data classification, encryption

## Denial of Service
- Threat: API overwhelmed by malicious requests
- Likelihood: High
- Impact: High
- Mitigation: Rate limiting, WAF, auto-scaling, caching

## Elevation of Privilege
- Threat: User gains admin access through API vulnerability
- Likelihood: Medium
- Impact: Critical
- Mitigation: RBAC, principle of least privilege, input validation
```

Complete STRIDE analysis for:
1. Web Frontend
2. Auth Service
3. Payment Service
4. Database

### Task 2.3: Create Attack Trees

Create an attack tree for "Steal User Payment Information":

**Goal: Steal User Payment Information**

- 1. Exploit Web Application Vulnerabilities
  - 1.1 SQL Injection on search/filter
    - AND database stores CC info
  - 1.2 XSS to capture form data
    - AND payment form is vulnerable
  - 1.3 Insecure Direct Object Reference
    - AND payment API returns full CC data
- 2. Compromise Backend Services
  - 2.1 Exploit unpatched vulnerabilities
    - AND service has network access to DB
  - 2.2 Steal service credentials
    - AND credentials are not rotated
  - 2.3 Container escape
    - AND gain host access
- 3. Network-based Attacks
  - 3.1 Man-in-the-middle
    - AND TLS not properly configured
  - 3.2 DNS hijacking
    - AND redirect to malicious server
- 4. Social Engineering
  - 4.1 Phish customer support
    - AND support has payment data access
  - 4.2 Insider threat
    - AND employee has database access


## Part 3: Security Requirements (30 minutes)

### Task 3.1: Convert Threats to Requirements

Transform identified threats into actionable security requirements:

```markdown
# Security Requirements Document

## Authentication & Authorization

### REQ-AUTH-001: Secure Authentication
- Description: All users must authenticate using secure methods
- Priority: Critical
- Source: STRIDE - Spoofing
- Acceptance Criteria:
  - OAuth2/OIDC implementation
  - MFA support for sensitive operations
  - Password complexity requirements enforced
  - Account lockout after 5 failed attempts

### REQ-AUTH-002: Session Management
- Description: Sessions must be securely managed
- Priority: High
- Source: STRIDE - Spoofing, Tampering
- Acceptance Criteria:
  - Session tokens are cryptographically random
  - Session timeout after 30 minutes of inactivity
  - Session invalidation on logout
  - Secure cookie flags (HttpOnly, Secure, SameSite)

## Data Protection

### REQ-DATA-001: Payment Data Handling
- Description: Payment data must be handled per PCI-DSS
- Priority: Critical
- Source: STRIDE - Information Disclosure
- Acceptance Criteria:
  - Never store full card numbers (use tokenization)
  - Encrypt cardholder data in transit
  - No payment data in logs
  - Use payment service provider for card processing

### REQ-DATA-002: Encryption at Rest
- Description: Sensitive data must be encrypted at rest
- Priority: High
- Source: STRIDE - Information Disclosure
- Acceptance Criteria:
  - AES-256 encryption for PII
  - Key management via HSM or KMS
  - Encrypted database backups
  - Encrypted file storage

## Input Validation

### REQ-INPUT-001: Input Sanitization
- Description: All user input must be validated and sanitized
- Priority: Critical
- Source: STRIDE - Tampering, Elevation of Privilege
- Acceptance Criteria:
  - Server-side validation for all inputs
  - Parameterized queries for database operations
  - Output encoding for display
  - File upload validation and scanning
```

### Task 3.2: Risk Register

Create a risk register documenting identified risks:

```markdown
# Security Risk Register

| ID | Risk Description | Likelihood | Impact | Risk Score | Status | Owner | Mitigation |
|----|-----------------|------------|--------|------------|--------|-------|------------|
| R001 | SQL Injection in product search | Medium | Critical | High | Open | Dev Team | Parameterized queries |
| R002 | Brute force on login | High | Medium | High | Mitigating | Security | Rate limiting, account lockout |
| R003 | Payment data exposure | Low | Critical | Medium | Open | Compliance | PCI-DSS compliance |
| R004 | DDoS attack on checkout | Medium | High | High | Mitigating | Ops | WAF, CDN, auto-scaling |
| R005 | Insider data theft | Low | Critical | Medium | Open | HR/Security | Access controls, monitoring |
```

## Verification

Complete the following checklist:

- [ ] Completed CIA Triad analysis for all major assets
- [ ] Created Data Flow Diagram with trust boundaries
- [ ] Applied STRIDE to at least 4 components
- [ ] Created attack tree for payment data theft
- [ ] Documented at least 10 security requirements
- [ ] Created risk register with at least 5 risks
- [ ] Prioritized risks by likelihood and impact

## Challenge Tasks

1. **DREAD Analysis**: Score your top 5 risks using DREAD (Damage, Reproducibility, Exploitability, Affected Users, Discoverability)

2. **MITRE ATT&CK Mapping**: Map your attack tree to MITRE ATT&CK techniques

3. **Threat Model Review**: Have a peer review your threat model and incorporate their feedback

## Summary

In this lab, you:
- Applied security principles (CIA Triad, Defense in Depth)
- Created data flow diagrams for threat analysis
- Used STRIDE methodology for systematic threat identification
- Developed attack trees for complex attack scenarios
- Converted threats into actionable security requirements
- Created a risk register for tracking and prioritization

## Next Steps

- Lab 2: Infrastructure Security and Hardening
- Review OWASP Top 10 for web application threats
- Study NIST Cybersecurity Framework

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Security Principles Analysis
- Confidentiality
- Integrity
- Availability

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"We scan for vulnerabilities in the pipeline."* |
| ✓ | *"SAST reads source without running it, SCA resolves the dependency tree against an advisory database, and image scanning compares installed package versions to that same database. All three report what was known at build time — which is why the registry is re-scanned: the image does not change, the database does."* |

**Trace it:** A CVE published today against your base image → a blocked deploy. Name every component between the advisory and the refused `apply`.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** the [SLSA threat model](https://slsa.dev/spec/v1.2/threats) — it names every point at which a build can be subverted, and most teams defend three of them.
Full list per domain: [`SOURCES.md`](../SOURCES.md#devsecops)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../MASTERY.md)

<!-- /feynman-check -->
