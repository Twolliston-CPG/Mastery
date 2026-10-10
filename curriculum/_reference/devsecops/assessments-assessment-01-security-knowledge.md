# Assessment 1: Security & Compliance Knowledge Assessment

## Overview

**Duration**: 90 minutes
**Total Points**: 100
**Passing Score**: 75%
**Format**: Multiple choice, short answer, and scenario-based questions

---

## Section 1: Security Fundamentals (20 points)

### Question 1.1 (2 points)
Which of the following best describes the principle of "defense in depth"?

A) Using the strongest single security control available
B) Implementing multiple layers of security controls
C) Focusing all security resources on the perimeter
D) Relying on user training as the primary defense

### Question 1.2 (2 points)
In the CIA triad, what does "Integrity" specifically refer to?

A) Keeping data secret from unauthorized users
B) Ensuring data is accurate and has not been tampered with
C) Making sure systems are available when needed
D) Verifying user identities before granting access

### Question 1.3 (3 points)
Match each threat modeling methodology with its primary focus:

| Methodology | Focus |
|-------------|-------|
| 1. STRIDE | A. Asset-centric, risk quantification |
| 2. PASTA | B. Attacker-centric, attack trees |
| 3. Attack Trees | C. Threat categories for software |

### Question 1.4 (3 points)
Arrange the following OWASP Top 10 2021 vulnerabilities in order from most critical (#1) to less critical (#5):

- [ ] Server-Side Request Forgery (SSRF)
- [ ] Broken Access Control
- [ ] Injection
- [ ] Security Misconfiguration
- [ ] Cryptographic Failures

### Question 1.5 (4 points - Short Answer)
Explain the difference between authentication and authorization. Provide one example of each in a Kubernetes context.

### Question 1.6 (3 points)
Which security principle is violated when a developer uses an admin account for routine development tasks?

A) Defense in depth
B) Least privilege
C) Separation of duties
D) Need to know

### Question 1.7 (3 points)
A CVSS score of 9.2 would be classified as:

A) Low
B) Medium
C) High
D) Critical

---

## Section 2: Infrastructure Security (20 points)

### Question 2.1 (3 points)
Which Kubernetes resource would you use to restrict network traffic between pods?

A) SecurityContext
B) NetworkPolicy
C) PodSecurityPolicy
D) ResourceQuota

### Question 2.2 (4 points)
Review the following Dockerfile and identify TWO security issues:

```dockerfile
FROM ubuntu:latest
RUN apt-get update && apt-get install -y curl
COPY . /app
WORKDIR /app
ENV DB_PASSWORD=secretpassword123
RUN chmod 777 /app
CMD ["./start.sh"]
```

**Security Issue 1**: _______________
**Security Issue 2**: _______________

### Question 2.3 (3 points)
Which Pod Security Standard level would BLOCK a container from running as root?

A) Privileged
B) Baseline
C) Restricted
D) None of the above

### Question 2.4 (4 points - Short Answer)
Explain why running containers with `privileged: true` is dangerous. What specific capabilities does this grant?

### Question 2.5 (3 points)
In Kubernetes RBAC, what is the difference between a Role and a ClusterRole?

A) Roles apply to all namespaces, ClusterRoles to one namespace
B) Roles apply to one namespace, ClusterRoles to the entire cluster
C) Roles are for users, ClusterRoles are for service accounts
D) There is no difference

### Question 2.6 (3 points)
Which security scanning type would detect a hardcoded API key in source code?

A) DAST (Dynamic Application Security Testing)
B) SCA (Software Composition Analysis)
C) SAST (Static Application Security Testing)
D) IAST (Interactive Application Security Testing)

---

## Section 3: Identity and Access Management (15 points)

### Question 3.1 (3 points)
In OAuth 2.0, what is the purpose of a refresh token?

A) To authenticate the user initially
B) To obtain new access tokens without re-authentication
C) To encrypt communication between client and server
D) To verify the identity provider's certificate

### Question 3.2 (3 points)
Which OIDC claim typically contains the user's unique identifier?

A) `aud`
B) `iss`
C) `sub`
D) `exp`

### Question 3.3 (4 points)
Review the following OPA Rego policy and answer: What does this policy enforce?

```rego
package kubernetes.admission

deny[msg] {
    input.request.kind.kind == "Pod"
    container := input.request.object.spec.containers[_]
    not startswith(container.image, "gcr.io/company-registry/")
    msg := sprintf("Image %v is not from approved registry", [container.image])
}
```

**Answer**: _______________

### Question 3.4 (2 points)
In a Zero Trust architecture, which statement is TRUE?

A) Users on the corporate network are implicitly trusted
B) VPN access grants full network access
C) Every access request must be verified regardless of source
D) Perimeter firewalls are the primary security control

### Question 3.5 (3 points)
What is the primary purpose of SPIFFE/SPIRE in a microservices architecture?

A) Load balancing between services
B) Workload identity and authentication
C) Service discovery and DNS
D) Traffic encryption and TLS termination

---

## Section 4: Compliance and Governance (15 points)

### Question 4.1 (3 points)
Under GDPR, how quickly must a data breach be reported to the supervisory authority?

A) 24 hours
B) 72 hours
C) 7 days
D) 30 days

### Question 4.2 (3 points)
Which PCI-DSS requirement specifically addresses secure software development?

A) Requirement 3
B) Requirement 6
C) Requirement 10
D) Requirement 12

### Question 4.3 (4 points - Short Answer)
Explain the difference between SOC 2 Type I and SOC 2 Type II reports. Which provides more assurance to customers?

### Question 4.4 (2 points)
In the context of compliance, what does "compensating control" mean?

A) A control that replaces a failed primary control
B) An alternative control when the standard control cannot be implemented
C) A backup control for disaster recovery
D) A control that measures compliance metrics

### Question 4.5 (3 points)
Which framework provides a maturity model for assessing security practices in software development?

A) NIST CSF
B) OWASP SAMM
C) ISO 27001
D) CIS Controls

---

## Section 5: Security Operations (15 points)

### Question 5.1 (3 points)
In a SIEM, which type of rule would detect multiple failed login attempts from the same IP address?

A) Correlation rule
B) Threshold rule
C) Anomaly detection rule
D) Pattern matching rule

### Question 5.2 (3 points)
What does MTTD measure in security operations?

A) Mean Time to Deploy
B) Mean Time to Detect
C) Mean Time to Defend
D) Mean Time to Document

### Question 5.3 (4 points)
Order the following incident response phases correctly:

- [ ] Containment
- [ ] Eradication
- [ ] Preparation
- [ ] Identification
- [ ] Recovery
- [ ] Lessons Learned

### Question 5.4 (3 points)
Which Suricata rule component specifies the signature identifier?

A) msg
B) sid
C) rev
D) classtype

### Question 5.5 (2 points)
In vulnerability management, what does EPSS (Exploit Prediction Scoring System) measure?

A) The technical severity of a vulnerability
B) The probability a vulnerability will be exploited
C) The business impact of a vulnerability
D) The time required to patch a vulnerability

---

## Section 6: Scenario-Based Questions (15 points)

### Scenario 6.1 (5 points)

Your security scanning pipeline detected the following vulnerability in a production container image:

```
CVE-2024-1234
Severity: Critical (CVSS 9.8)
Package: openssl 1.1.1k
Description: Remote code execution via crafted TLS handshake
Affected: Production API service (10 replicas)
EPSS: 0.89 (89% exploitation probability)
```

**Questions:**
a) What is your recommended immediate action? (2 points)
b) How would you prioritize this against other critical vulnerabilities? (1 point)
c) What information would you need before deciding to take the service offline? (2 points)

### Scenario 6.2 (5 points)

You're implementing network policies in Kubernetes. A developer requests the following policy:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-policy
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector: {}
    ports:
    - protocol: TCP
      port: 8080
```

**Questions:**
a) What does `podSelector: {}` in the ingress rule mean? (2 points)
b) Is this policy secure? Explain why or why not. (2 points)
c) How would you modify it to only allow traffic from the frontend pods? (1 point)

### Scenario 6.3 (5 points)

Your organization is preparing for a SOC 2 Type II audit. The auditor asks for evidence of your vulnerability management program.

**Questions:**
a) List three types of evidence you would need to provide. (2 points)
b) What metrics would demonstrate an effective vulnerability management program? (2 points)
c) How would you handle a gap where you don't have 12 months of historical data? (1 point)

---

## Answer Key

### Section 1
1.1: B
1.2: B
1.3: 1-C, 2-A, 3-B
1.4: 1-Broken Access Control, 2-Cryptographic Failures, 3-Injection, 4-Security Misconfiguration, 5-SSRF
1.5: Authentication verifies identity (who you are), Authorization determines permissions (what you can do). K8s examples: Authentication - ServiceAccount tokens; Authorization - RBAC roles.
1.6: B
1.7: D

### Section 2
2.1: B
2.2: 1) Hardcoded password in ENV, 2) Using `ubuntu:latest` (unpinned/bloated), 3) `chmod 777` (excessive permissions)
2.3: C
2.4: Privileged mode grants all Linux capabilities, access to host devices, can mount host filesystem, can load kernel modules. Essentially root access to the host.
2.5: B
2.6: C

### Section 3
3.1: B
3.2: C
3.3: The policy enforces that all container images must come from the approved registry (gcr.io/company-registry/).
3.4: C
3.5: B

### Section 4
4.1: B
4.2: B
4.3: Type I evaluates design of controls at a point in time; Type II evaluates operating effectiveness over a period (typically 6-12 months). Type II provides more assurance because it demonstrates sustained compliance.
4.4: B
4.5: B

### Section 5
5.1: B
5.2: B
5.3: Preparation → Identification → Containment → Eradication → Recovery → Lessons Learned
5.4: B
5.5: B

### Section 6

**6.1 Sample Answer:**
a) Immediately patch/update the container image to a version with patched OpenSSL. Deploy to staging, run security scan, then rolling update to production.
b) High priority based on: Critical CVSS, high EPSS (active exploitation likely), production exposure, RCE capability.
c) Business impact assessment, availability of patch, ability to implement compensating controls, active exploitation in the wild.

**6.2 Sample Answer:**
a) `podSelector: {}` means all pods in the same namespace can access the API on port 8080.
b) Not secure - it allows ANY pod in the namespace to access the API, violating least privilege.
c) Change to: `podSelector: matchLabels: app: frontend`

**6.3 Sample Answer:**
a) Vulnerability scan reports, remediation tickets/timelines, vulnerability management policy, SLA compliance metrics.
b) MTTR by severity, vulnerability age distribution, SLA compliance rate, vulnerability escape rate.
c) Document the gap, implement controls immediately, provide evidence of new processes, commit to full period for next audit.

---

## Grading Rubric

| Section | Points | Passing Threshold |
|---------|--------|------------------|
| Security Fundamentals | 20 | 15 |
| Infrastructure Security | 20 | 15 |
| Identity and Access Management | 15 | 11 |
| Compliance and Governance | 15 | 11 |
| Security Operations | 15 | 11 |
| Scenario-Based | 15 | 11 |
| **Total** | **100** | **75** |

## Certification Requirements

- Score of 75% or higher to pass
- Must score at least 50% in each section
- Retake allowed after 7 days
- Certification valid for 2 years

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Security Fundamentals
- Infrastructure Security
- Identity and Access Management
- Compliance and Governance

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
