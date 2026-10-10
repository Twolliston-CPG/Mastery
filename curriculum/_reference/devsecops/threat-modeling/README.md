# Enterprise Threat Modeling Mastery

A comprehensive, hands-on curriculum for mastering enterprise threat modeling. Progress from foundational concepts to leading organization-wide threat modeling programs.

## Overview

This curriculum is designed for security professionals with DevSecOps, Security Engineering, or Cloud Architecture backgrounds who want to master threat modeling for enterprise environments.

**Target Industries:** Finance, Healthcare, SaaS, Government
**Tools Focus:** Free and open-source tools only
**Cloud Platforms:** AWS, Azure, GCP

---

## Curriculum Structure

**`threat-modeling/`**

- `content/` — Learning modules
  - `01-foundations/` — Core concepts
  - `02-methodologies/` — STRIDE, PASTA, LINDDUN, Attack Trees
  - `03-technical-skills/` — Cloud, K8s, API, IaC, Serverless
  - `04-tools/` — Threat Dragon, MS TMT, pytm, Threagile
  - `05-enterprise/` — Program building, compliance, scaling
  - `06-advanced/` — Threat intel, adversarial, AI/ML, supply chain
  - `07-mastery/` — Facilitation, training, handling resistance
- `labs/` — Hands-on exercises
  - `lab-01-stride-basics/`
  - `lab-02-web-app/`
  - `lab-03-api-threats/`
  - `lab-04-cloud-aws/`
  - `lab-05-cloud-azure/`
  - `lab-06-cloud-gcp/`
  - `lab-07-kubernetes/`
  - `lab-08-threat-dragon/`
  - `lab-09-saas-multi-tenant/`
  - `lab-10-cicd-pipeline/`
- `projects/` — Real-world projects
  - `project-01-web-app/`
  - `project-02-api-microservices/`
  - `project-03-cloud-native/`
  - `project-04-kubernetes/`
  - `project-05-healthcare/`
  - `project-06-fintech/`
  - `project-07-saas-multitenant/`
  - `project-08-ml-pipeline/`
  - `project-09-supply-chain/`
  - `project-10-zero-trust/`
- `case-studies/` — Real breach analysis
  - Meridian Bank.md
  - `orionsoft.md`
  - `log4shell.md`
  - `identityco-threatgroup-a.md`
  - `filetransferapp.md`
  - `threatgroup-b.md`
- `templates/` — Reusable templates
  - `threat-model-template.md`
  - `stride-worksheet.md`
  - `dfd-template.md`
  - `risk-assessment-template.md`
  - `session-checklist.md`
  - `compliance-mapping-template.md`


---

## Learning Path

### Phase 1: Foundations (Weeks 1-2)
Build core threat modeling knowledge.

| Module | Content | Time |
|--------|---------|------|
| Security Fundamentals | CIA triad, defense in depth | 2 hrs |
| Introduction to Threat Modeling | Four questions, process overview | 2 hrs |
| Assets, Threats, and Actors | Crown jewels, threat actors | 2 hrs |
| DFD Basics | Creating data flow diagrams | 3 hrs |
| **Lab 1** | STRIDE Basics | 2 hrs |

### Phase 2: Methodologies (Weeks 3-4)
Master threat identification frameworks.

| Module | Content | Time |
|--------|---------|------|
| STRIDE Deep Dive | Per-element and per-interaction | 4 hrs |
| PASTA | Process for Attack Simulation | 3 hrs |
| LINDDUN | Privacy threat modeling | 2 hrs |
| Attack Trees | Hierarchical threat analysis | 2 hrs |
| **Lab 2** | Web Application Threats | 3 hrs |
| **Lab 3** | API Threat Modeling | 3 hrs |

### Phase 3: Technical Skills (Weeks 5-8)
Apply threat modeling to modern architectures.

| Module | Content | Time |
|--------|---------|------|
| Cloud Security | AWS, Azure, GCP threats | 4 hrs |
| Kubernetes Security | Container orchestration threats | 4 hrs |
| Serverless Security | FaaS threat patterns | 3 hrs |
| IaC Security | Terraform, CloudFormation | 3 hrs |
| API Security | OWASP API Top 10 | 3 hrs |
| **Labs 4-7** | Cloud and K8s hands-on | 12 hrs |

### Phase 4: Tools (Weeks 9-10)
Master threat modeling tools.

| Module | Content | Time |
|--------|---------|------|
| OWASP Threat Dragon | Web-based modeling | 2 hrs |
| Microsoft Threat Modeling Tool | Azure integration | 2 hrs |
| pytm | Threat modeling as code | 3 hrs |
| Threagile | YAML-based automation | 2 hrs |
| MITRE ATT&CK Integration | TTP mapping | 2 hrs |
| **Lab 8** | Threat Dragon Practice | 3 hrs |

### Phase 5: Enterprise (Weeks 11-13)
Scale threat modeling across organizations.

| Module | Content | Time |
|--------|---------|------|
| Building a Program | Maturity model, SDLC integration | 4 hrs |
| Compliance Mapping | PCI DSS, HIPAA, SOC 2, ISO 27001 | 4 hrs |
| Scaling Threat Modeling | Champions, self-service, automation | 3 hrs |
| **Projects 1-4** | Progressive complexity | 40 hrs |

### Phase 6: Advanced Topics (Weeks 14-16)
Expert-level threat analysis.

| Module | Content | Time |
|--------|---------|------|
| Threat Intelligence Integration | Intel-driven modeling | 4 hrs |
| Adversarial Thinking | Attacker mindset, attack paths | 3 hrs |
| AI/ML Threat Modeling | Training, inference, LLM threats | 4 hrs |
| Supply Chain Security | SLSA, dependencies, CI/CD | 4 hrs |
| Zero Trust Architecture | ZTA threat modeling | 3 hrs |
| **Projects 5-8** | Industry-specific projects | 60 hrs |

### Phase 7: Mastery (Weeks 17-20)
Lead and teach threat modeling.

| Module | Content | Time |
|--------|---------|------|
| Facilitation Skills | Running effective sessions | 3 hrs |
| Training Others | Building organizational capability | 3 hrs |
| Handling Resistance | Overcoming objections | 2 hrs |
| **Projects 9-10** | Expert capstone projects | 40 hrs |

---

## Projects Overview

| # | Project | Difficulty | Focus Areas |
|---|---------|------------|-------------|
| 1 | Basic Web Application | Beginner | STRIDE, DFDs, fundamentals |
| 2 | API & Microservices | Intermediate | OWASP API Top 10, PCI DSS |
| 3 | Cloud-Native Platform | Intermediate | Multi-cloud, IaC, shared responsibility |
| 4 | Kubernetes Platform | Advanced | Container security, RBAC, supply chain |
| 5 | Healthcare System | Advanced | HIPAA, PHI protection |
| 6 | Fintech Payment | Advanced | PCI DSS Level 1, tokenization |
| 7 | SaaS Multi-Tenant | Advanced | Tenant isolation, noisy neighbor |
| 8 | ML Pipeline | Expert | Adversarial ML, data poisoning |
| 9 | Software Supply Chain | Expert | SLSA, dependencies, CI/CD |
| 10 | Zero Trust Enterprise | Expert | Capstone, full architecture |

---

## Case Studies

Learn from real-world breaches:

| Case Study | Year | Key Lessons |
|------------|------|-------------|
| Meridian Bank | 2019 | SSRF, IAM misconfiguration, cloud security |
| OrionSoft | 2020 | Supply chain, build pipeline compromise |
| Log4Shell | 2021 | Dependency vulnerabilities, JNDI injection |
| IdentityCo/ThreatGroup-A | 2022 | Third-party risk, contractor access |
| FileTransferApp | 2023 | SQL injection, file transfer security |
| ThreatGroup-B | 2023 | Token forgery, key management, cloud identity |

---

## Tools Used

All tools in this curriculum are free or open-source:

| Tool | Purpose | Link |
|------|---------|------|
| OWASP Threat Dragon | Web-based threat modeling | [threatdragon.org](https://threatdragon.org) |
| Microsoft TMT | Threat modeling for Azure | [Microsoft](https://aka.ms/tmt) |
| pytm | Python threat modeling | [GitHub](https://github.com/izar/pytm) |
| Threagile | YAML-based threat modeling | [threagile.io](https://threagile.io) |
| draw.io | Diagramming | [draw.io](https://draw.io) |

---

## Templates

Ready-to-use templates for your threat modeling practice:

- **Threat Model Template** - Complete document structure
- **STRIDE Worksheet** - Per-component threat analysis
- **DFD Template** - Data flow diagram guide
- **Risk Assessment Template** - DREAD and matrix-based rating
- **Session Checklist** - Facilitation preparation
- **Compliance Mapping Template** - PCI, HIPAA, SOC 2, ISO mapping

---

## Getting Started

### Prerequisites
- Basic understanding of software development
- Familiarity with cloud platforms (AWS, Azure, or GCP)
- Understanding of common security concepts

### Recommended Approach

1. **Start with the roadmap**: Read `content/threat-modeling-roadmap.md`
2. **Follow the phases**: Progress through modules in order
3. **Complete labs**: Hands-on practice after each section
4. **Apply to projects**: Use projects to build portfolio
5. **Use templates**: Adapt templates for your organization

### Time Investment

| Path | Estimated Time | Best For |
|------|----------------|----------|
| Fast Track | 80-100 hours | Experienced security professionals |
| Standard | 150-200 hours | Security practitioners |
| Comprehensive | 250+ hours | Career changers, deep mastery |

---

## Certification Path

This curriculum prepares you for:

- **GIAC Cloud Security Automation (GCSA)**
- **Certified Threat Intelligence Analyst (CTIA)**
- **SABSA Chartered Security Architect**
- **AWS/Azure/GCP Security Certifications**

---

## Contributing

This curriculum is maintained for personal learning. Contributions welcome via:

1. Suggesting additional case studies
2. Reporting outdated content
3. Adding new tool guides
4. Sharing project variations

---

## References

### Books
- *Threat Modeling: Designing for Security* - Adam Shostack
- *Threat Modeling* - Izar Tarandach & Matthew Coles

### Standards
- [OWASP Threat Modeling](https://owasp.org/www-community/Threat_Modeling)
- [NIST SP 800-154](https://csrc.nist.gov/publications/detail/sp/800-154/draft)
- [MITRE ATT&CK](https://attack.mitre.org/)

### Communities
- OWASP Threat Modeling Community
- Threat Modeling Slack/Discord communities
- BSides and OWASP local chapters

---

## License

This curriculum is for educational purposes. Case studies reference public information about security incidents for learning purposes only.

---

## Quick Start

```bash
# Navigate to the first module
cd content/01-foundations

# Read the introduction
cat intro-threat-modeling.md

# Start your first lab
cd ../../labs/lab-01-stride-basics
cat README.md
```

**Ready to begin?** Start with [Threat Modeling Roadmap](content/threat-modeling-roadmap.md)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Curriculum Structure
- Projects Overview
- Case Studies
- Tools Used

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
