# LINDDUN Privacy Threat Modeling

## Overview

LINDDUN is a privacy-focused threat modeling framework developed at KU Leuven. While STRIDE focuses on security, LINDDUN addresses privacy threats—essential for GDPR, HIPAA, CCPA, and other privacy regulations.

| LINDDUN |  |
|---|---|
| Privacy Threat Categories |  |
| L inkability | Linking data across contexts |
| I dentifiability | Identifying individuals from data |
| N on-repudiation | Unable to deny actions (privacy) |
| D etectability | Detecting existence of data/action |
| D isclosure | Exposing personal information |
| U nawareness | Users unaware of data processing |
| N on-compliance | Violating privacy regulations |


---

## When to Use LINDDUN

| Use LINDDUN | Use STRIDE |
|-------------|------------|
| Processing personal data (PII/PHI) | General security threats |
| GDPR/HIPAA/CCPA compliance | Technical vulnerability focus |
| Privacy-by-design requirements | Confidentiality concerns |
| Consumer-facing applications | System integrity focus |
| Healthcare, finance, HR systems | Availability concerns |

**Best Practice:** Use LINDDUN alongside STRIDE for comprehensive coverage.

---

## LINDDUN Categories Explained

### L - Linkability

**Definition:** The ability to link two or more items of interest (data, actions, identities) without knowing the identity of the data subject.

**Privacy Property Violated:** Unlinkability

**Examples:**
**Linkability Threats:**

- Linking browsing history across websites via cookies
- Correlating anonymous transactions by timing
- Connecting pseudonymous accounts via metadata
- Linking health records via unique identifiers
- Tracking users across services via device fingerprinting


**Questions to Ask:**
- Can data from different sources be combined?
- Are there unique identifiers that persist across contexts?
- Can metadata (timestamps, IP, device) enable linking?
- Can pseudonymous data be correlated?

**Cloud-Specific Linkability:**
**AWS/Cloud:**

- CloudTrail logs correlating user activities
- Cross-account access patterns
- API Gateway request correlation
- S3 access logs linking requests
- VPC Flow Logs identifying patterns

**Data Stores:**

- Foreign keys enabling joins
- Consistent user IDs across tables
- Metadata in object storage
- Cache keys revealing relationships


**Mitigations:**
- Data minimization
- Pseudonymization with separate key management
- Anonymization techniques (k-anonymity, differential privacy)
- Purpose limitation (don't combine data across purposes)
- Decoupled identifiers

---

### I - Identifiability

**Definition:** The ability to identify a data subject from data that is not explicitly identified.

**Privacy Property Violated:** Anonymity, Pseudonymity

**Examples:**
**Identifiability Threats:**

- Re-identification from "anonymized" datasets
- Identifying users from demographic combinations
- Facial recognition from images
- Voice identification from recordings
- Behavioral patterns revealing identity
- Location data identifying individuals


**Questions to Ask:**
- Can individuals be identified from the data?
- Is the data truly anonymized or just pseudonymized?
- Can quasi-identifiers (age, zip, gender) enable identification?
- Does aggregated data have small cell sizes?

**Re-identification Risks:**
**Quasi-Identifier Combinations:**

- ZIP code + Birth date + Gender = 87% of US population unique
- Movie ratings + timestamps = StreamCo dataset de-anonymized
- Location traces = 4 points identify 95% of people
- Search queries = AOL dataset identified users

**Data Types at Risk:**

- Medical records (diagnosis codes)
- Financial transactions (amounts, merchants)
- Location data (home, work patterns)
- Biometric data (fingerprints, face)
- Genetic data (inherently identifying)


**Mitigations:**
- Proper anonymization (not just removing names)
- K-anonymity, l-diversity, t-closeness
- Differential privacy for analytics
- Data aggregation with minimum thresholds
- Suppression of outliers

---

### N - Non-repudiation (Privacy Context)

**Definition:** Being unable to deny having performed an action, which can be a privacy concern when users need plausible deniability.

**Privacy Property Violated:** Plausible Deniability

**Note:** In security, non-repudiation is desired. In privacy, it can be a threat.

**Examples:**
**Non-repudiation Privacy Threats:**

- Mandatory audit trails revealing sensitive actions
- Digital signatures proving authorship
- Access logs showing who viewed what records
- Transaction records proving purchases
- Location check-ins proving presence


**Questions to Ask:**
- Are there actions users should be able to deny?
- Do audit logs capture sensitive activities?
- Can signatures be required vs. optional?
- Is there a legitimate need for plausible deniability?

**Sensitive Contexts:**
**Situations Requiring Deniability:**

- Whistleblowing platforms
- Anonymous tip lines
- Sensitive health queries (mental health, STDs)
- Political speech in repressive regimes
- Domestic abuse victim resources


**Mitigations:**
- Anonymous submission options
- Confidential computing
- Onion routing (Tor)
- Ring signatures
- Proportionate logging (don't over-log)

---

### D - Detectability

**Definition:** The ability to detect whether an item of interest (data, communication, action) exists.

**Privacy Property Violated:** Undetectability, Unobservability

**Examples:**
**Detectability Threats:**

- Detecting that a medical record exists
- Inferring membership in a dataset
- Observing encrypted traffic patterns
- Detecting presence in a database via timing
- Presence detection via online status
- File existence leakage via error messages


**Questions to Ask:**
- Can someone detect if a record exists?
- Does the system leak information via error messages?
- Can traffic analysis reveal patterns?
- Are timing side-channels present?

**Detection Vectors:**
**Error Message Leakage:**

- "Username not found" vs "Invalid password"
- "No records found" revealing absence
- Different response times for existing vs non-existing
- HTTP status codes revealing state

**Traffic Analysis:**

- Packet sizes revealing content type
- Timing patterns revealing activity
- Connection destinations revealing relationships
- Metadata revealing communication


**Mitigations:**
- Consistent error messages
- Constant-time operations
- Traffic padding and shaping
- Dummy operations to hide patterns
- Access pattern obfuscation

---

### D - Disclosure of Information

**Definition:** Exposing personal information to unauthorized parties.

**Privacy Property Violated:** Confidentiality (of personal data)

**Note:** Overlaps with Information Disclosure in STRIDE, but focuses specifically on personal data.

**Examples:**
**Disclosure Threats:**

- Unauthorized access to personal records
- Data breach exposing customer PII
- Accidental exposure via misconfiguration
- Insider access to sensitive data
- Third-party data sharing without consent
- Logs containing personal data


**Questions to Ask:**
- Who can access personal data?
- Is access logged and monitored?
- Can insiders access data they shouldn't?
- Is personal data shared with third parties?
- Is personal data in logs, backups, caches?

**Cloud-Specific Disclosure:**
**AWS/Cloud:**

- S3 bucket misconfigurations exposing PII
- Database snapshots accessible cross-account
- Lambda environment variables with PII
- CloudWatch logs containing personal data
- IAM policies allowing broad access
- Third-party SaaS integrations

**Application:**

- API responses returning excessive data
- Debug endpoints exposing user data
- Error messages containing PII
- Client-side storage of sensitive data
- Insecure data transmission


**Mitigations:**
- Access control and least privilege
- Data encryption (at rest and in transit)
- Data masking and tokenization
- Audit logging of personal data access
- Data Loss Prevention (DLP)
- Vendor security assessments

---

### U - Unawareness

**Definition:** Users being unaware of how their data is collected, processed, stored, or shared.

**Privacy Property Violated:** Transparency, User Control

**Examples:**
**Unawareness Threats:**

- Hidden data collection (tracking pixels)
- Unclear privacy policies
- Data sharing not disclosed
- No visibility into data held
- Inability to access/correct/delete data
- Automated decision-making not explained
- Retention periods not communicated


**Questions to Ask:**
- Do users know what data is collected?
- Is the privacy policy clear and accessible?
- Can users access their data?
- Can users correct or delete their data?
- Are users informed of third-party sharing?
- Is automated decision-making explained?

**Regulatory Requirements:**
**GDPR Requirements:**

- Right to be informed (Articles 13-14)
- Right of access (Article 15)
- Right to rectification (Article 16)
- Right to erasure (Article 17)
- Right to data portability (Article 20)
- Right to object (Article 21)
- Rights related to automated decision-making (Article 22)

**CCPA Requirements:**

- Right to know
- Right to delete
- Right to opt-out
- Right to non-discrimination
- Right to correct


**Mitigations:**
- Clear, accessible privacy notices
- Just-in-time privacy notices
- Privacy dashboards
- Data subject access request (DSAR) processes
- Consent management
- Explainable AI/ML

---

### N - Non-compliance

**Definition:** Not adhering to privacy laws, regulations, and organizational policies.

**Privacy Property Violated:** Regulatory Compliance

**Examples:**
**Non-compliance Threats:**

- Processing without legal basis (GDPR Art. 6)
- Transferring data to inadequate countries
- Missing Data Protection Impact Assessment
- Insufficient consent mechanisms
- Excessive data retention
- Missing breach notification processes
- No Data Protection Officer when required
- Inadequate security measures


**Questions to Ask:**
- What regulations apply (GDPR, HIPAA, CCPA)?
- Is there a valid legal basis for processing?
- Are international data transfers compliant?
- Is a DPIA required and completed?
- Are consent mechanisms adequate?
- Is breach notification process in place?

**Compliance Matrix:**
```
                    GDPR    HIPAA   CCPA    PCI DSS
Legal Basis          ✓       ✓       ✓        -
Consent Management   ✓       ✓       ✓        -
Data Subject Rights  ✓       ✓       ✓        -
Breach Notification  ✓       ✓       ✓        ✓
Data Minimization    ✓       ✓       -        ✓
Encryption Required  ✓       ✓       -        ✓
DPO/Privacy Officer  ✓       ✓       -        -
Impact Assessment    ✓       ✓       -        -
```

**Mitigations:**
- Privacy program establishment
- Data Processing Impact Assessments (DPIAs)
- Privacy-by-design implementation
- Vendor management program
- Incident response procedures
- Regular compliance audits
- Staff training

---

## LINDDUN Process

### Step 1: Model the System
Create DFDs focusing on personal data flows:
**Focus on:**

- Where personal data enters
- How personal data is processed
- Where personal data is stored
- Who/what accesses personal data
- Where personal data exits
- Trust boundaries for personal data


### Step 2: Map Privacy Threat Categories
For each DFD element, consider LINDDUN categories:

| Element Type | L | I | N | D | D | U | N |
|--------------|---|---|---|---|---|---|---|
| External Entity | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Data Flow | ✓ | ✓ | - | ✓ | ✓ | - | ✓ |
| Process | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Data Store | ✓ | ✓ | - | ✓ | ✓ | - | ✓ |

### Step 3: Elicit Threats
Use threat trees or catalogs to identify specific threats.

### Step 4: Prioritize and Mitigate
Assess impact and implement Privacy Enhancing Technologies (PETs).

---

## Privacy Enhancing Technologies (PETs)

| Technology | LINDDUN Category | Description |
|------------|------------------|-------------|
| Encryption | Disclosure | Protect data at rest and in transit |
| Anonymization | Identifiability | Remove identifying information |
| Pseudonymization | Identifiability, Linkability | Replace identifiers with pseudonyms |
| Differential Privacy | Identifiability | Add noise to aggregate queries |
| Homomorphic Encryption | Disclosure | Compute on encrypted data |
| Secure Multi-Party Computation | Disclosure | Compute without revealing inputs |
| Zero-Knowledge Proofs | Disclosure, Identifiability | Prove without revealing |
| Data Minimization | All | Collect only necessary data |
| Purpose Limitation | Linkability | Use data only for stated purpose |
| Consent Management | Unawareness | Transparent user control |

---

## Practical Exercise

**Scenario:** Employee Health & Wellness Portal

A company deploys an employee wellness portal:
- Health risk assessments
- Mental health resources
- Fitness tracking integration
- Anonymous employee assistance queries
- Aggregated wellness reports to HR

**Task:** Apply LINDDUN to this system

### Exercise Questions:

1. **Linkability:** How might employee wellness data be linked to other HR data?

2. **Identifiability:** Even if "anonymized," how might employees be identified from wellness data?

3. **Non-repudiation:** What sensitive actions should employees be able to deny?

4. **Detectability:** Can managers detect if an employee used mental health resources?

5. **Disclosure:** Who has access to what wellness data?

6. **Unawareness:** Do employees understand how their data is used?

7. **Non-compliance:** What regulations apply and are we compliant?

---

## Key Takeaways

1. **Privacy ≠ Security** - STRIDE doesn't cover privacy threats

2. **Personal data requires special attention** - LINDDUN focuses here

3. **Regulatory compliance is essential** - GDPR, HIPAA, CCPA

4. **Privacy by design** - Build privacy in from the start

5. **Use with STRIDE** - Combine for comprehensive coverage

6. **PETs enable privacy** - Technical solutions exist

---

## Next Steps

→ [Attack Trees](attack-trees.md)
→ [Lab 07: Healthcare PHI System (HIPAA)](../../labs/lab-07-healthcare-phi/)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- When to Use LINDDUN
- LINDDUN Categories Explained
- LINDDUN Process
- Privacy Enhancing Technologies (PETs)

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
