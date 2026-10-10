# Enterprise Threat Modeling Mastery Roadmap

> **Profile:** DevSecOps/Security/DevOps Professional
> **Environment:** Cloud-Native (AWS/Azure/GCP)
> **Industries:** Finance, Healthcare, SaaS, Government
> **Tools:** Free/Open-Source

---

## How to Use This Curriculum

### Learning Path Structure
```
For each module:
1. Read the concept content (theory)
2. Study the examples and case studies
3. Complete the hands-on lab
4. Build the associated project
5. Self-assess using the rubric
6. Move to next module when competency achieved
```

### Competency Gates (Not Time-Based)
Progress when you can demonstrate the skill, not after a set number of weeks.

### Directory Structure
**`threat-modeling/`**

- `content/` — Theory and concepts
  - `01-foundations/`
  - `02-methodologies/`
  - `03-technical-skills/`
  - `04-tools/`
  - `05-enterprise/`
  - `06-advanced/`
  - `07-mastery/`
- `labs/` — Hands-on exercises
- `projects/` — Portfolio projects
- `templates/` — Reusable templates
- `case-studies/` — Real-world breach analysis
- `resources/` — Additional materials


---

## Self-Assessment: Starting Point

Rate yourself (1-5) on each area before beginning:

| Skill Area | 1 (Novice) | 3 (Intermediate) | 5 (Expert) | Your Score |
|------------|------------|------------------|------------|------------|
| Security fundamentals (CIA, AuthN/AuthZ) | | | | ___ |
| Reading architecture diagrams | | | | ___ |
| Cloud security (AWS/Azure/GCP) | | | | ___ |
| Application security concepts | | | | ___ |
| Risk assessment | | | | ___ |
| Compliance frameworks | | | | ___ |
| Facilitating technical discussions | | | | ___ |

**Scoring:**
- 7-15: Start at Phase 1
- 16-25: Start at Phase 2
- 26-30: Start at Phase 3
- 31+: Start at Phase 4 or 5

---

## Phase 1: Foundations

### Learning Objectives
By the end of this phase, you will be able to:
- Explain the purpose and value of threat modeling
- Identify assets, threats, and threat actors
- Create basic data flow diagrams
- Articulate security properties (CIA+)

### Content Modules
1. [Security Fundamentals Review](content/01-foundations/security-fundamentals.md)
2. [Introduction to Threat Modeling](content/01-foundations/intro-threat-modeling.md)
3. [Assets, Threats, and Threat Actors](content/01-foundations/assets-threats-actors.md)
4. [Data Flow Diagrams Basics](content/01-foundations/dfd-basics.md)

### Hands-On Lab
- [Lab 01: Basic Web Application Threat Model](labs/lab-01-basic-web-app/)

### Competency Gate
- [ ] Can explain threat modeling to a developer in 2 minutes
- [ ] Can create a Level 0 and Level 1 DFD
- [ ] Can identify at least 10 threats for a simple web app
- [ ] Can categorize threats by security property

---

## Phase 2: Core Methodologies

### Learning Objectives
- Apply STRIDE systematically to any system
- Conduct a full PASTA assessment
- Use LINDDUN for privacy threat analysis
- Build and analyze attack trees
- Select appropriate methodology for context

### Content Modules
1. [STRIDE Deep Dive](content/02-methodologies/stride.md)
2. [PASTA Framework](content/02-methodologies/pasta.md)
3. [LINDDUN Privacy Threats](content/02-methodologies/linddun.md)
4. [Attack Trees](content/02-methodologies/attack-trees.md)
5. [Methodology Selection Guide](content/02-methodologies/methodology-selection.md)

### Hands-On Labs
- [Lab 02: API Threat Model with STRIDE](labs/lab-02-api-threat-model/)
- [Lab 03: Microservices with PASTA](labs/lab-03-microservices/)

### Competency Gate
- [ ] Can apply STRIDE to a component and identify threats in all 6 categories
- [ ] Can complete a 7-stage PASTA assessment
- [ ] Can identify privacy threats using LINDDUN
- [ ] Can build an attack tree with AND/OR nodes
- [ ] Can justify methodology choice for different scenarios

---

## Phase 3: Cloud-Native Technical Skills

### Learning Objectives
- Threat model Kubernetes deployments
- Analyze serverless architectures for threats
- Identify cloud-specific attack vectors (AWS/Azure/GCP)
- Model Infrastructure as Code security
- Assess CI/CD pipeline threats

### Content Modules
1. [Cloud Security Fundamentals](content/03-technical-skills/cloud-security.md)
2. [Kubernetes Threat Modeling](content/03-technical-skills/kubernetes.md)
3. [Serverless Security Patterns](content/03-technical-skills/serverless.md)
4. [Infrastructure as Code Threats](content/03-technical-skills/iac-security.md)
5. [CI/CD Pipeline Security](content/03-technical-skills/cicd-security.md)
6. [API Security Patterns](content/03-technical-skills/api-security.md)

### Hands-On Labs
- [Lab 04: Kubernetes Deployment](labs/lab-04-kubernetes/)
- [Lab 05: Serverless Application](labs/lab-05-serverless/)
- [Lab 06: Multi-Cloud Architecture](labs/lab-06-multi-cloud/)
- [Lab 10: CI/CD Pipeline](labs/lab-10-cicd-pipeline/)

### Competency Gate
- [ ] Can identify Kubernetes-specific threats (RBAC, network policies, secrets)
- [ ] Can threat model a Lambda/Cloud Functions architecture
- [ ] Can analyze Terraform/CloudFormation for security issues
- [ ] Can identify CI/CD supply chain risks
- [ ] Can map cloud threats to MITRE ATT&CK for Cloud

---

## Phase 4: Tools & Automation

### Learning Objectives
- Use OWASP Threat Dragon effectively
- Implement threat modeling as code with Threagile
- Integrate threat modeling into DevSecOps pipelines
- Automate threat identification and tracking

### Content Modules
1. [OWASP Threat Dragon Guide](content/04-tools/threat-dragon.md)
2. [Threagile for DevSecOps](content/04-tools/threagile.md)
3. [Microsoft Threat Modeling Tool](content/04-tools/ms-tmt.md)
4. [pytm - Pythonic Threat Modeling](content/04-tools/pytm.md)
5. [MITRE ATT&CK Integration](content/04-tools/mitre-attack.md)
6. [CI/CD Integration Patterns](content/04-tools/cicd-integration.md)

### Hands-On Labs
- Build threat models using each tool
- Integrate Threagile into a GitHub Actions pipeline
- Generate threat reports automatically

### Competency Gate
- [ ] Can create a complete threat model in Threat Dragon
- [ ] Can write Threagile YAML and generate reports
- [ ] Can integrate threat modeling into CI/CD
- [ ] Can map threats to MITRE ATT&CK techniques

---

## Phase 5: Enterprise & Compliance

### Learning Objectives
- Align threat modeling with compliance requirements
- Build and scale a threat modeling program
- Communicate risk to executives and auditors
- Handle industry-specific requirements

### Content Modules
1. [Building a Threat Modeling Program](content/05-enterprise/building-program.md)
2. [Compliance Mapping](content/05-enterprise/compliance-mapping.md)
3. [Risk Quantification & Communication](content/05-enterprise/risk-communication.md)
4. [Scaling Threat Modeling](content/05-enterprise/scaling.md)

### Industry-Specific Labs
- [Lab 07: Healthcare PHI System (HIPAA)](labs/lab-07-healthcare-phi/)
- [Lab 08: FinTech Payment Platform (PCI DSS)](labs/lab-08-fintech-pci/)
- [Lab 09: SaaS Multi-Tenant Platform](labs/lab-09-saas-multi-tenant/)

### Competency Gate
- [ ] Can map threats to compliance control requirements
- [ ] Can present threat model findings to non-technical stakeholders
- [ ] Can design a threat modeling program for an organization
- [ ] Can create industry-specific threat libraries

---

## Phase 6: Advanced Topics

### Learning Objectives
- Integrate threat intelligence into models
- Adopt adversarial/red team thinking
- Threat model AI/ML systems
- Assess supply chain and third-party risks

### Content Modules
1. [Threat Intelligence Integration](content/06-advanced/threat-intelligence.md)
2. [Adversarial Thinking](content/06-advanced/adversarial-thinking.md)
3. [AI/ML System Threats](content/06-advanced/ai-ml-threats.md)
4. [Supply Chain Security](content/06-advanced/supply-chain.md)
5. [Zero Trust Architecture](content/06-advanced/zero-trust.md)

### Competency Gate
- [ ] Can incorporate threat intelligence into threat models
- [ ] Can think like an attacker and identify non-obvious attack paths
- [ ] Can threat model an ML pipeline
- [ ] Can assess third-party/vendor risks

---

## Phase 7: Mastery & Leadership

### Learning Objectives
- Train others in threat modeling
- Contribute to the security community
- Continuously improve organizational practices
- Handle complex, ambiguous scenarios

### Content Modules
1. [Facilitating Threat Modeling Sessions](content/07-mastery/facilitation.md)
2. [Training Development Teams](content/07-mastery/training-teams.md)
3. [Handling Resistance](content/07-mastery/handling-resistance.md)
4. [Continuous Improvement](content/07-mastery/continuous-improvement.md)

### Competency Gate
- [ ] Can facilitate a threat modeling session with skeptical engineers
- [ ] Can train a team to do their own threat modeling
- [ ] Can handle "we don't have time for security" objections
- [ ] Can maintain and evolve threat models over system lifetime

---

## Projects Portfolio

Complete these to demonstrate mastery:

| # | Project | Skills Demonstrated |
|---|---------|---------------------|
| 1 | [Startup MVP Threat Model](projects/01-startup-mvp.md) | Foundations, STRIDE |
| 2 | [API Gateway Security](projects/02-api-gateway.md) | API security, cloud |
| 3 | [Kubernetes Platform](projects/03-kubernetes-platform.md) | K8s, containers |
| 4 | [Serverless Data Pipeline](projects/04-serverless-pipeline.md) | Serverless, data flow |
| 5 | [Healthcare Records System](projects/05-healthcare-system.md) | HIPAA, privacy |
| 6 | [Payment Processing Platform](projects/06-payment-platform.md) | PCI DSS, finance |
| 7 | [Multi-Tenant SaaS](projects/07-multi-tenant-saas.md) | Isolation, scaling |
| 8 | [Government Cloud Migration](projects/08-gov-cloud.md) | FedRAMP, compliance |
| 9 | [DevSecOps Pipeline](projects/09-devsecops-pipeline.md) | CI/CD, supply chain |
| 10 | [Enterprise Threat Program](projects/10-enterprise-program.md) | Program design |

---

## Case Studies

Learn from real-world incidents:

| Case Study | Focus Area |
|------------|------------|
| [Meridian Bank 2019](case-studies/Meridian Bank.md) | Cloud misconfiguration, SSRF |
| [OrionSoft 2020](case-studies/orionsoft.md) | Supply chain, build pipeline |
| [Log4Shell 2021](case-studies/log4shell.md) | Dependency risk, SBOM |
| [IdentityCo/ThreatGroup-A 2022](case-studies/identityco-threatgroup-a.md) | Third-party access |
| [FileTransferApp 2023](case-studies/filetransferapp.md) | File transfer, zero-day |
| [Microsoft ThreatGroup-B 2023](case-studies/threatgroup-b.md) | Key management, identity |

---

## Templates

Ready-to-use templates in `templates/`:

- [Threat Model Document Template](templates/threat-model-template.md)
- [DFD Component Library](templates/dfd-components.md)
- [STRIDE Worksheet](templates/stride-worksheet.md)
- [Risk Assessment Matrix](templates/risk-matrix.md)
- [Session Facilitation Guide](templates/facilitation-guide.md)
- [Executive Summary Template](templates/executive-summary.md)
- [Compliance Mapping Worksheet](templates/compliance-mapping.md)

---

## Open-Source Tools Reference

| Tool | Purpose | Link |
|------|---------|------|
| OWASP Threat Dragon | DFD & threat modeling | github.com/OWASP/threat-dragon |
| Threagile | Threat modeling as code | github.com/Threagile/threagile |
| pytm | Python threat modeling | github.com/izar/pytm |
| OWASP Cornucopia | Card game for threats | owasp.org/www-project-cornucopia |
| draw.io | Diagramming | diagrams.net |
| MITRE ATT&CK Navigator | Technique mapping | mitre-attack.github.io/attack-navigator |
| Trivy | Container/IaC scanning | github.com/aquasecurity/trivy |
| Checkov | IaC security scanning | github.com/bridgecrewio/checkov |
| KICS | IaC security scanning | github.com/Checkmarx/kics |

---

## Progress Tracker

### Phase Completion

| Phase | Status | Date Started | Date Completed |
|-------|--------|--------------|----------------|
| 1. Foundations | [ ] | | |
| 2. Methodologies | [ ] | | |
| 3. Cloud-Native | [ ] | | |
| 4. Tools | [ ] | | |
| 5. Enterprise | [ ] | | |
| 6. Advanced | [ ] | | |
| 7. Mastery | [ ] | | |

### Labs Completed

| Lab | Status | Notes |
|-----|--------|-------|
| 01: Basic Web App | [ ] | |
| 02: API Threat Model | [ ] | |
| 03: Microservices | [ ] | |
| 04: Kubernetes | [ ] | |
| 05: Serverless | [ ] | |
| 06: Multi-Cloud | [ ] | |
| 07: Healthcare PHI | [ ] | |
| 08: FinTech PCI | [ ] | |
| 09: SaaS Multi-Tenant | [ ] | |
| 10: CI/CD Pipeline | [ ] | |

### Projects Completed

| Project | Status | Repository Link |
|---------|--------|-----------------|
| 01: Startup MVP | [ ] | |
| 02: API Gateway | [ ] | |
| 03: Kubernetes Platform | [ ] | |
| 04: Serverless Pipeline | [ ] | |
| 05: Healthcare System | [ ] | |
| 06: Payment Platform | [ ] | |
| 07: Multi-Tenant SaaS | [ ] | |
| 08: Government Cloud | [ ] | |
| 09: DevSecOps Pipeline | [ ] | |
| 10: Enterprise Program | [ ] | |

---

*Curriculum Version: 2.0 | Last Updated: January 2026*

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Self-Assessment: Starting Point
- Foundations
- Core Methodologies
- Cloud-Native Technical Skills

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
