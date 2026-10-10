# Case Study: OrionSoft Supply Chain Attack (2020)

## Incident Overview

| Attribute | Details |
|-----------|---------|
| **Date Discovered** | December 8, 2020 (by FireEye) |
| **Attack Duration** | October 2019 - December 2020 (14+ months) |
| **Organizations Affected** | ~18,000 organizations installed backdoored updates |
| **High-Value Targets** | US Treasury, DHS, DOE, Microsoft, FireEye |
| **Attribution** | Russian SVR (APT29/Cozy Bear) |
| **Attack Type** | Software supply chain compromise |

---

## Attack Overview

<!-- figure: generated from the Mermaid below by _shared/diagrams/embed-figures.py — do not edit the image -->
![Attack Overview — diagram](../../../../_figures/curriculum-_reference-devsecops-threat-modeling-case-studies-orionsoft-0-706e9b28.png)

<details>
<summary>Diagram source (Mermaid)</summary>

```mermaid
%%{init: {'theme':'base','themeVariables':{'fontFamily':'Helvetica, Arial, sans-serif','fontSize':'13px','primaryColor':'#ffffff','primaryTextColor':'#2d3436','primaryBorderColor':'#9aa3ab','lineColor':'#9aa3ab','textColor':'#2d3436','clusterBkg':'#fbfcfd','clusterBorder':'#d4dae0','edgeLabelBackground':'#ffffff','tertiaryColor':'#eef4fb'},'flowchart':{'curve':'basis','padding':14,'nodeSpacing':42,'rankSpacing':58}}}%%
flowchart LR
  classDef default fill:#ffffff,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef n    fill:#ffffff,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef crit fill:#eef4fb,stroke:#2f6fb8,stroke-width:1.8px,color:#1b3a5c
  classDef data fill:#f4f7fa,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef mut  fill:#ffffff,stroke:#cfd6dc,stroke-width:1.1px,color:#7a8288
  classDef warn fill:#fdf0ec,stroke:#c0522d,stroke-width:1.6px,color:#8a3a1e
  subgraph VENDOR["Vendor build environment"]
    direction LR
    SRC[("Source repository<br/><small><b>clean</b> — review, SAST and SCA all pass</small>")]:::data
    BLD["Build server<br/><small><b>COMPROMISED</b> — the implant is injected here</small>"]:::crit
    UPD["Update server<br/><small>legitimate, and correctly signed</small>"]:::n
    SRC --> BLD --> UPD
  end

  subgraph CUST["Thousands of customers"]
    direction LR
    C1["Customer A"]:::n
    C2["Customer B"]:::n
    C3["…"]:::n
  end

  UPD -->|"signed update · every control passes"| C1
  UPD --> C2
  UPD --> C3

  linkStyle 1,3 stroke:#2f6fb8,stroke-width:2px
```

</details>

---

## Attack Chain Details

### Phase 1: Initial Compromise of OrionSoft

**Attacker Actions:**

- Gained access to OrionSoft development environment
- Compromised build system (not source repository)
- Implanted SUNSPOT malware on build server
- SUNSPOT injected SUNBURST into Orion during compilation

**Key Technique: Build Process Manipulation**

- Source code remained clean
- Malware only injected during build
- Signed with legitimate OrionSoft certificate
- Appeared as normal software update


### Phase 2: Distribution

**Timeline:**

- Oct 2019: Attackers test deployment mechanism
- Feb 2020: SUNBURST first compiled into Orion updates
- Mar-Jun 2020: Malicious updates distributed to customers
- Dec 2020: FireEye discovers breach, alerts OrionSoft


### Phase 3: Post-Compromise Activities

**SUNBURST Behavior:**

- 2-week dormancy period after installation
- DNS beaconing to attacker-controlled domains
- Victim identification and prioritization
- High-value targets received TEARDROP/RAINDROP follow-up malware
- Lateral movement and data exfiltration

**Evasion Techniques:**

- Mimicked legitimate Orion traffic patterns
- Used victim's own infrastructure for C2
- Avoided systems with security tools (sandbox detection)
- Operated during business hours to blend in
- Used legitimate cloud services (AWS, Azure)


---

## Threat Modeling Perspective

### Supply Chain Attack Surface

<!-- figure: generated from the Mermaid below by _shared/diagrams/embed-figures.py — do not edit the image -->
![Supply Chain Attack Surface — diagram](../../../../_figures/curriculum-_reference-devsecops-threat-modeling-case-studies-orionsoft-1-df8db1b0.png)

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
  subgraph TRAD["Where most threat models look"]
    RT["Application runtime"]:::n
  end

  subgraph REAL["Where this attack actually lived"]
    direction TB
    W["Developer workstations<br/><small>← the initial compromise</small>"]:::crit
    R["Source repository"]:::n
    B["<b>Build system</b><br/><small>← the implant</small>"]:::crit
    SG["Signing infrastructure"]:::n
    D["Distribution / update server"]:::n
    RT2["Application runtime"]:::n
    W --> R --> B --> SG --> D --> RT2
  end

  NOTE["The source was clean, so code review, SAST and SCA all passed.<br/>Only reproducible builds and signed provenance from a hardened<br/>builder (SLSA L3) address this."]:::mut

  linkStyle 1,2 stroke:#2f6fb8,stroke-width:2px
```

</details>

### STRIDE Analysis of Build Pipeline

| Component | S | T | R | I | D | E | SUNBURST Relevance |
|-----------|---|---|---|---|---|---|--------------------|
| Dev Workstation | ✓ | ✓ | ✓ | ✓ | | ✓ | Entry point |
| Source Repo | ✓ | ✓ | ✓ | ✓ | | ✓ | Remained clean |
| Build Server | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | **Injection point** |
| Artifact Storage | | ✓ | | ✓ | ✓ | | Stored malware |
| Signing Service | ✓ | | ✓ | | | ✓ | **Legitimized malware** |
| Update Server | | ✓ | | ✓ | ✓ | | Distributed malware |

### Threats That Should Have Been Modeled

1. **Build-Time Injection** (T: Tampering)
   - Malicious code added during compilation
   - Source and binary don't match
   - Build server compromise

2. **Signing Key Abuse** (S: Spoofing, E: Elevation)
   - Malicious code signed with legitimate key
   - Trust chain exploitation
   - Certificate protection inadequate

3. **Update Mechanism Abuse** (T: Tampering, E: Elevation)
   - Software updates as attack vector
   - Trusted channel for malware delivery

4. **Supply Chain Trust** (S: Spoofing)
   - Implicit trust in vendor software
   - No verification of build integrity
   - Customer trusts signed updates

---

## Lessons for Threat Modeling

### Expanding Threat Model Scope

**Include in Scope:**

- Development environment
  - Developer workstations
  - IDE plugins and extensions
  - Development tools
- Source control
  - Repository access
  - Branch protection
  - Code review process
- Build pipeline
  - CI/CD systems
  - Build agents/runners
  - Build scripts
  - Build-time dependencies
- Artifact management
  - Package repositories
  - Container registries
  - Binary storage
- Code signing
  - Key storage (HSM?)
  - Signing process
  - Certificate management
- Distribution
  - Update mechanisms
  - `CDN/hosting`
  - Customer deployment


### Build Pipeline Threat Model

<!-- figure: generated from the Mermaid below by _shared/diagrams/embed-figures.py — do not edit the image -->
![Build Pipeline Threat Model — diagram](../../../../_figures/curriculum-_reference-devsecops-threat-modeling-case-studies-orionsoft-2-bbae5dce.png)

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
  GOAL(["<b>Goal:</b> inject malicious code into the build"]):::crit

  A1["Compromise a developer<br/><small>phishing · stolen credentials · malicious dependency on the workstation</small>"]:::n
  A2["Modify build scripts<br/><small>write access to CI configuration</small>"]:::n
  A3["Compromise a dependency<br/><small>typosquat · maintainer takeover · registry compromise</small>"]:::n
  A4["Inject via a build tool<br/><small>compiler, plugin, or base image</small>"]:::n

  GOAL --> A1
  GOAL --> A2
  GOAL --> A3
  GOAL --> A4

  M["<b>Mitigations</b><br/><small>hardened isolated builders · reproducible builds<br/>signed provenance · pinned dependencies and lockfiles<br/>pinned action/tool digests · two-person review on CI config</small>"]:::mut

  A1 -.-> M
  A2 -.-> M
  A3 -.-> M
  A4 -.-> M

  linkStyle 0,1,2,3 stroke:#2f6fb8,stroke-width:2px
```

</details>

---

## Detection and Prevention

### Controls That Would Have Helped

| Control | Description | Would It Have Detected/Prevented? |
|---------|-------------|-----------------------------------|
| **Reproducible Builds** | Same source → same binary | Yes - binary wouldn't match |
| **Build Isolation** | Ephemeral, isolated build environments | Possibly - harder to persist |
| **Binary Analysis** | Compare source to compiled output | Yes - would show extra code |
| **Behavioral Monitoring** | Monitor build server behavior | Possibly - unusual processes |
| **Multi-Party Signing** | Require multiple approvals | Possibly - higher barrier |
| **SBOM + Provenance** | Document build inputs/process | Yes - would show anomalies |

### Modern Mitigations

**Supply Chain Security Framework:**

- SLSA (Supply-chain Levels for Software Artifacts)
  - Level 1: Documentation
  - Level 2: Tamper resistance
  - Level 3: Extra resistance
  - Level 4: Maximum confidence
- Sigstore / Cosign
  - Keyless signing
  - Transparency logs
  - Verification tooling
- In-toto
  - Supply chain layout
  - Signed attestations
  - Policy enforcement
- SBOM (Software Bill of Materials)
  - Dependency tracking
  - Vulnerability correlation
  - Provenance documentation


---

## Threat Model Exercise

### Exercise: Model Your Build Pipeline

**Scenario:** You maintain a CI/CD pipeline for a critical application:

```
[Developer] → [GitHub] → [Jenkins] → [Artifactory] → [Production]
                              │
                      [Build Dependencies]
                      [npm, Maven, Docker]
```

**Tasks:**

1. **Enumerate Assets:**
   - What are the crown jewels?
   - What needs protection?

2. **Identify Entry Points:**
   - Where could an attacker enter?
   - What trust relationships exist?

3. **Apply STRIDE to Build Server:**
   - How could Jenkins be compromised?
   - What could an attacker do with access?

4. **Model Dependency Risk:**
   - How are dependencies resolved?
   - Could a malicious package be introduced?

5. **Design Controls:**
   - How would you detect a SUNBURST-style attack?
   - What preventive controls would help?

---

## Key Takeaways

1. **Trust is transitive** - Customers trusted OrionSoft, who trusted their build system

2. **Build systems are high-value targets** - Compromise once, affect thousands

3. **Signatures aren't enough** - Signed malware is still malware

4. **Source ≠ Binary** - Build process can introduce changes

5. **Threat model the full lifecycle** - Not just runtime, but development and distribution

6. **Supply chain security is a discipline** - SLSA, SBOM, provenance are essential

---

## References

- CISA Alert AA20-352A
- FireEye: Highly Evasive Attacker Leverages OrionSoft Supply Chain
- Microsoft: Solorigate Investigation
- MITRE ATT&CK: Supply Chain Compromise (T1195.002)
- SLSA Framework: slsa.dev

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Incident Overview
- Attack Overview
- Attack Chain Details
- Threat Modeling Perspective

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
