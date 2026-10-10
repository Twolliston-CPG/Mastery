# Phase 8 Assessment 1: Platform Engineering Knowledge Assessment

## Assessment Overview

| Attribute | Details |
|-----------|---------|
| **Duration** | 90 minutes |
| **Format** | Multiple choice, short answer, scenario-based |
| **Passing Score** | 70% |
| **Total Points** | 100 |
| **Prerequisites** | Completion of Phase 8 content and labs |

## Instructions

- Answer all questions to the best of your ability
- For multiple choice, select the best answer
- For short answer, be concise but complete
- For scenario questions, explain your reasoning
- No external resources allowed during the assessment

---

## Section 1: Platform Engineering Fundamentals (20 points)

### Question 1.1 (2 points)
**What is the primary goal of an Internal Developer Platform (IDP)?**

A) To standardize all technology choices across the organization
B) To reduce cognitive load and enable developer self-service while maintaining guardrails
C) To eliminate the need for platform teams
D) To enforce strict compliance through manual approval workflows

### Question 1.2 (2 points)
**According to the Team Topologies framework, what is the ideal interaction mode between a platform team and stream-aligned teams?**

A) Collaboration - working together frequently
B) X-as-a-Service - providing self-service capabilities
C) Facilitating - helping other teams learn
D) Blocking - controlling access to resources

### Question 1.3 (3 points)
**Short Answer:** Explain the concept of "golden paths" in platform engineering and why they are important.

```
Your answer:




```

### Question 1.4 (2 points)
**Which statement best describes the relationship between platform engineering and DevOps?**

A) Platform engineering replaces DevOps
B) Platform engineering is a specialization that enables DevOps at scale
C) DevOps and platform engineering are competing approaches
D) Platform engineering only applies to large organizations

### Question 1.5 (3 points)
**Short Answer:** What are the key differences between "platform as a product" and "platform as infrastructure"?

```
Your answer:




```

### Question 1.6 (2 points)
**What is the "pit of success" concept in platform design?**

A) A debugging technique for identifying platform failures
B) Design principle where the default path leads to good outcomes
C) A metric for measuring platform adoption
D) A pattern for handling exceptions

### Question 1.7 (3 points)
**Short Answer:** List three characteristics of a well-designed platform abstraction.

```
Your answer:




```

### Question 1.8 (3 points)
**Match each platform component with its primary purpose:**

| Component | Purpose |
|-----------|---------|
| A. Backstage | 1. GitOps continuous delivery |
| B. Crossplane | 2. Policy enforcement |
| C. ArgoCD | 3. Developer portal |
| D. OPA Gatekeeper | 4. Infrastructure abstraction |

```
Your answers:
A =
B =
C =
D =
```

---

## Section 2: Developer Portal and Experience (20 points)

### Question 2.1 (2 points)
**What is the primary value proposition of a software catalog in a developer portal?**

A) Source code storage and version control
B) Centralized visibility into services, ownership, and dependencies
C) Automated deployment and release management
D) Cost tracking and budget management

### Question 2.2 (3 points)
**Short Answer:** Describe the role of Software Templates in Backstage and provide an example use case.

```
Your answer:




```

### Question 2.3 (2 points)
**Which Backstage plugin would you use to display technical documentation generated from Markdown files in code repositories?**

A) Catalog plugin
B) TechDocs plugin
C) Kubernetes plugin
D) Search plugin

### Question 2.4 (3 points)
**Scenario:** A team complains that creating new microservices takes 2 weeks because they need to request infrastructure, configure CI/CD, set up monitoring, and register the service. How would a developer portal address this?

```
Your answer:




```

### Question 2.5 (2 points)
**What is the purpose of the `catalog-info.yaml` file in Backstage?**

A) Configure Backstage deployment settings
B) Define entity metadata (services, APIs, resources) for the catalog
C) Store sensitive credentials
D) Configure CI/CD pipelines

### Question 2.6 (3 points)
**Short Answer:** Explain how TechDocs differs from traditional wiki-based documentation.

```
Your answer:




```

### Question 2.7 (3 points)
**You are designing a developer portal for a company with 50 microservices. What entities and relationships would you model in the catalog?**

```
Your answer:




```

### Question 2.8 (2 points)
**What is the primary benefit of integrating Backstage with ArgoCD?**

A) Automatic code generation
B) Visibility into deployment status and sync state from the portal
C) Database provisioning
D) Load testing automation

---

## Section 3: Infrastructure Abstraction (15 points)

### Question 3.1 (2 points)
**In Crossplane, what is a Composition?**

A) A Kubernetes namespace
B) A template that defines how to provision a set of resources from a single claim
C) A monitoring dashboard configuration
D) A security policy definition

### Question 3.2 (3 points)
**Short Answer:** Explain the difference between a Composite Resource Definition (XRD) and a Composition in Crossplane.

```
Your answer:




```

### Question 3.3 (2 points)
**What is the primary advantage of using Crossplane over direct Terraform/Pulumi for developer self-service?**

A) Crossplane is faster to execute
B) Crossplane uses Kubernetes-native APIs, enabling GitOps and RBAC
C) Crossplane supports more cloud providers
D) Crossplane doesn't require YAML

### Question 3.4 (3 points)
**Scenario:** You need to create a self-service abstraction for PostgreSQL databases with three tiers (dev, staging, prod). The abstraction should hide the underlying cloud provider. Design the XRD interface.

```yaml
# Your answer (provide the spec schema):




```

### Question 3.5 (3 points)
**Short Answer:** What are "composite resources" and why are they useful for platform teams?

```
Your answer:




```

### Question 3.6 (2 points)
**Which Crossplane concept allows you to inject credentials and configuration into provisioned resources?**

A) ProviderConfig
B) Composition
C) XRD
D) ClusterRole

---

## Section 4: Policy and Governance (15 points)

### Question 4.1 (2 points)
**What is the primary function of OPA Gatekeeper in a Kubernetes cluster?**

A) Network traffic management
B) Admission control and policy enforcement
C) Log aggregation
D) Service mesh implementation

### Question 4.2 (3 points)
**Short Answer:** Explain the difference between a ConstraintTemplate and a Constraint in OPA Gatekeeper.

```
Your answer:




```

### Question 4.3 (3 points)
**Write a Gatekeeper Constraint that requires all pods to have a "team" label:**

```yaml
# Your answer:




```

### Question 4.4 (2 points)
**What is the purpose of "dry-run" or "audit" mode in policy enforcement?**

A) To run policies faster
B) To identify violations without blocking resources
C) To test network connectivity
D) To generate compliance reports only

### Question 4.5 (3 points)
**Scenario:** A team needs to deploy a service that violates the "no privileged containers" policy for a legitimate reason. Design an exception process.

```
Your answer:




```

### Question 4.6 (2 points)
**Which of the following is NOT a benefit of Policy as Code?**

A) Version control and audit trail
B) Automated testing of policies
C) Faster deployment times
D) Consistent enforcement across environments

---

## Section 5: Developer Productivity Metrics (15 points)

### Question 5.1 (2 points)
**Which metric is NOT part of the DORA four key metrics?**

A) Deployment Frequency
B) Code Coverage
C) Lead Time for Changes
D) Mean Time to Recovery

### Question 5.2 (3 points)
**Short Answer:** Explain the SPACE framework and its five dimensions.

```
Your answer:




```

### Question 5.3 (2 points)
**What does "elite" performance look like for Deployment Frequency according to DORA research?**

A) Weekly deployments
B) Monthly deployments
C) On-demand (multiple deploys per day)
D) Quarterly releases

### Question 5.4 (3 points)
**Scenario:** Your organization has the following metrics:
- Deployment Frequency: 1 per week per team
- Lead Time: 2 weeks
- Change Failure Rate: 15%
- MTTR: 1 day

What DORA performance level is this, and what would you prioritize improving?

```
Your answer:




```

### Question 5.5 (3 points)
**Short Answer:** Why is it important to measure developer satisfaction alongside activity metrics?

```
Your answer:




```

### Question 5.6 (2 points)
**Which metric best measures platform team success?**

A) Number of features shipped
B) Lines of code written
C) Self-service success rate and developer time savings
D) Number of support tickets closed

---

## Section 6: Technical Leadership (15 points)

### Question 6.1 (2 points)
**What is the primary purpose of an Architecture Decision Record (ADR)?**

A) Document meeting minutes
B) Track project timelines
C) Capture the context and reasoning behind architectural decisions
D) Store API documentation

### Question 6.2 (3 points)
**Short Answer:** What information should be included in an ADR?

```
Your answer:




```

### Question 6.3 (2 points)
**In the RAPID decision-making framework, what does the "D" stand for?**

A) Developer
B) Decide (has final authority)
C) Document
D) Deliver

### Question 6.4 (3 points)
**Scenario:** You need to decide between three database technologies for a new platform service. Two teams have strong but different preferences. Describe how you would facilitate this decision.

```
Your answer:




```

### Question 6.5 (3 points)
**Short Answer:** What is the RFC (Request for Comments) process and when should it be used?

```
Your answer:




```

### Question 6.6 (2 points)
**What is "disagree and commit" in decision-making?**

A) Forcing agreement through hierarchy
B) Accepting a decision you disagreed with and supporting its execution
C) Documenting disagreement for future reference
D) Escalating all disagreements to leadership

---

## Scenario-Based Questions (Bonus: 10 points)

### Bonus Question 1 (5 points)

**Scenario:** You are the platform engineering lead at a 200-engineer company. After 18 months of building your Internal Developer Platform, adoption is stuck at 25%. Teams complain that:
- The platform doesn't support their specific needs
- Documentation is confusing
- They can't get help when stuck
- Leadership doesn't seem to care about adoption

**Question:** Outline a 6-month plan to improve adoption. Include specific initiatives, metrics you would track, and organizational changes you would recommend.

```
Your answer:




```

### Bonus Question 2 (5 points)

**Scenario:** Your platform team is evaluating whether to build or buy a developer portal solution. You have the following constraints:
- 300 engineers across 30 teams
- Mix of languages (Go, Python, Java, Node.js)
- Existing investment in GitHub, ArgoCD, and Datadog
- Budget of $500K for the first year
- Need to show value within 6 months

**Question:** What would you recommend and why? Consider both technical and organizational factors.

```
Your answer:




```

---

## Answer Key

### Section 1: Platform Engineering Fundamentals

**1.1:** B - To reduce cognitive load and enable developer self-service while maintaining guardrails

**1.2:** B - X-as-a-Service - providing self-service capabilities

**1.3:** Sample answer: Golden paths are opinionated, supported, and well-documented approaches for common tasks (like creating a new service or deploying to production). They're important because they:
- Reduce cognitive load by providing ready-made solutions
- Encode best practices and organizational standards
- Enable fast onboarding while allowing deviation when needed
- Free developers to focus on business logic rather than infrastructure

**1.4:** B - Platform engineering is a specialization that enables DevOps at scale

**1.5:** Sample answer:
- Platform as a Product: Treats developers as customers, focuses on user experience, has dedicated product management, measures success by adoption and satisfaction, iterates based on feedback
- Platform as Infrastructure: Treats platform as technical tooling, focuses on technical capabilities, measures success by uptime and feature count, builds based on technical requirements

**1.6:** B - Design principle where the default path leads to good outcomes

**1.7:** Sample answers (any three):
- Hides unnecessary complexity while exposing meaningful controls
- Matches developer mental models
- Provides sensible defaults
- Offers escape hatches for advanced use cases
- Self-documenting with good error messages
- Consistent API design patterns

**1.8:** A=3, B=4, C=1, D=2

### Section 2: Developer Portal and Experience

**2.1:** B - Centralized visibility into services, ownership, and dependencies

**2.2:** Sample answer: Software Templates are predefined scaffolds that generate new projects/services with standardized structure, configurations, and integrations. Use case: A "Backend API" template that creates a new repository with Go code, Dockerfile, Kubernetes manifests, CI/CD pipeline, TechDocs configuration, and registers the service in the catalog—all from a simple form.

**2.3:** B - TechDocs plugin

**2.4:** Sample answer: A developer portal would provide:
- Software templates that create repository, infrastructure, CI/CD, and monitoring automatically
- Self-service infrastructure provisioning via the portal UI
- Automatic service registration in the catalog
- Pre-configured observability integration
Result: Service creation in minutes instead of weeks

**2.5:** B - Define entity metadata (services, APIs, resources) for the catalog

**2.6:** Sample answer: TechDocs is "docs as code":
- Documentation lives in source repositories alongside code
- Uses MkDocs/Markdown format
- Automatically built and published on merge
- Stays in sync with code changes
- Searchable from a central portal

Wikis are separate from code, often become outdated, have inconsistent formatting, and require manual maintenance.

**2.7:** Sample answer:
- Entities: Components (50 services), APIs, Systems (groupings), Domains, Resources (databases, queues), Users, Teams
- Relationships: ownedBy (team), providesApi, consumesApi, dependsOn, partOf (system), memberOf (domain)
- Additional: documentation links, runbook URLs, on-call schedules, deployment status

**2.8:** B - Visibility into deployment status and sync state from the portal

### Section 3: Infrastructure Abstraction

**3.1:** B - A template that defines how to provision a set of resources from a single claim

**3.2:** Sample answer:
- XRD (Composite Resource Definition): Defines the schema/API that developers interact with. It specifies what parameters are available (like database size, region) and creates a new Kubernetes API type.
- Composition: Implements the XRD by mapping the API to actual infrastructure resources. Multiple compositions can implement the same XRD (e.g., different cloud providers).

**3.3:** B - Crossplane uses Kubernetes-native APIs, enabling GitOps and RBAC

**3.4:** Sample answer:
```yaml
spec:
  group: database.platform.example.com
  names:
    kind: PostgreSQLInstance
    plural: postgresqlinstances
  claimNames:
    kind: PostgreSQLClaim
    plural: postgresqlclaims
  versions:
    - name: v1alpha1
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              properties:
                tier:
                  type: string
                  enum: [dev, staging, prod]
                storageGB:
                  type: integer
                  minimum: 10
                  maximum: 1000
              required:
                - tier
```

**3.5:** Sample answer: Composite resources are Crossplane's abstraction layer that combines multiple underlying resources into a single, higher-level API. They're useful because:
- Platform teams can create company-specific abstractions
- Developers get simpler interfaces without cloud-specific details
- Best practices are encoded (security groups, encryption, backup)
- Changes to underlying implementation don't affect consumers

**3.6:** A - ProviderConfig

### Section 4: Policy and Governance

**4.1:** B - Admission control and policy enforcement

**4.2:** Sample answer:
- ConstraintTemplate: Defines reusable policy logic using Rego. Contains the parameterizable rule that can be applied to multiple scenarios.
- Constraint: An instance of a ConstraintTemplate with specific parameters. Specifies which resources the policy applies to and with what configuration.

**4.3:** Sample answer:
```yaml
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredLabels
metadata:
  name: require-team-label
spec:
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
  parameters:
    labels:
      - key: team
```

**4.4:** B - To identify violations without blocking resources

**4.5:** Sample answer:
1. Team submits exception request with justification via portal/CLI
2. Request includes: resource, policy, reason, duration, risk acceptance
3. Automated validation checks basic criteria
4. Routes to appropriate approver (security for security policies, etc.)
5. If approved: Creates time-limited namespace annotation/exception
6. Exception logged in audit system
7. Automatic expiration with notification before removal
8. Periodic review of all active exceptions

**4.6:** C - Faster deployment times

### Section 5: Developer Productivity Metrics

**5.1:** B - Code Coverage

**5.2:** Sample answer: SPACE framework measures developer productivity across five dimensions:
- **S**atisfaction: Developer happiness, fulfillment
- **P**erformance: Code quality, outcomes
- **A**ctivity: Volume of actions (commits, PRs, reviews)
- **C**ollaboration: Cross-team work, knowledge sharing
- **E**fficiency: Flow state, minimal interruptions

**5.3:** C - On-demand (multiple deploys per day)

**5.4:** Sample answer:
- Current level: Medium/Low performer (approaching Medium)
- Priority improvements:
  1. Lead Time (2 weeks → days): Focus on CI/CD automation, reduce approval bottlenecks
  2. Change Failure Rate (15%): Improve testing, feature flags, smaller batches
  3. Deployment Frequency will improve naturally as lead time decreases

**5.5:** Sample answer: Activity metrics alone can be gamed and don't capture actual productivity. A developer might have many commits but be frustrated and considering leaving. Satisfaction captures:
- Sustainability of pace
- Tool effectiveness
- Team health
- Likelihood of retention
High satisfaction correlates with better outcomes long-term.

**5.6:** C - Self-service success rate and developer time savings

### Section 6: Technical Leadership

**6.1:** C - Capture the context and reasoning behind architectural decisions

**6.2:** Sample answer: ADRs should include:
- Title and date
- Status (proposed, accepted, deprecated, superseded)
- Context: What problem are we solving?
- Decision: What did we decide?
- Consequences: What are the implications (positive and negative)?
- Alternatives considered: What else did we evaluate?

**6.3:** B - Decide (has final authority)

**6.4:** Sample answer:
1. Define evaluation criteria with both teams (performance, ops complexity, team skills, cost)
2. Have each team present their preference with evidence
3. Create decision matrix scoring each option
4. Facilitate discussion to surface concerns
5. If no consensus: Decide based on evidence, document reasoning
6. If strong preferences remain: Use "disagree and commit"
7. Record decision in ADR with full context

**6.5:** Sample answer: RFC is a formal process for proposing significant technical changes:
- Written proposal shared broadly before implementation
- Open comment period for feedback
- Used for: Major architecture changes, new technologies, cross-team impacts
- Benefits: Inclusive decision-making, documented rationale, early problem identification

**6.6:** B - Accepting a decision you disagreed with and supporting its execution

### Bonus Questions (Sample Answers)

**Bonus 1 Sample Answer:**

**Month 1-2: Research and Quick Wins**
- Conduct 30+ developer interviews to understand pain points
- Implement top 3 quick fixes based on feedback
- Launch platform champions program (2 per team)
- Establish weekly office hours for support

**Month 3-4: Migration and Support**
- Build migration tooling for existing services
- Create tiered adoption levels (catalog → observability → deployment → full)
- Publish case studies from early adopters
- Executive alignment: Add adoption to company OKRs

**Month 5-6: Culture and Measurement**
- Monthly platform show-and-tell
- Developer advisory council influence on roadmap
- Sunset alternative tools with transition support
- Quarterly recognition for platform excellence

**Metrics:**
- Adoption rate (target: 60% by month 6)
- Developer NPS (target: +20)
- Self-service success rate (target: 90%)
- Support satisfaction (target: 4.0/5)

**Bonus 2 Sample Answer:**

**Recommendation: Buy (Backstage) with customization**

**Rationale:**
- Backstage is open-source with strong community and AudioWave backing
- Existing integrations for GitHub, ArgoCD available
- Datadog plugin exists in community
- 6-month timeline favors configuration over building

**Approach:**
- Month 1-2: Core deployment, GitHub and ArgoCD integration
- Month 3-4: Software templates for each language stack
- Month 5-6: TechDocs, Datadog integration, custom dashboards

**Budget Allocation:**
- Infrastructure: $100K
- Consultant/contractor support: $150K
- Internal team (2 FTEs equivalent): $200K
- Contingency: $50K

**Risks and Mitigations:**
- Risk: Backstage complexity → Hire consultant with experience
- Risk: Custom plugin needs → Budget for development
- Risk: Adoption → Start champions program immediately

---

## Scoring Guide

| Score Range | Performance Level |
|-------------|-------------------|
| 90-100 | Exceptional - Ready to lead platform initiatives |
| 80-89 | Proficient - Strong understanding, some areas to develop |
| 70-79 | Competent - Meets requirements, continue learning |
| 60-69 | Developing - Review weak areas before proceeding |
| <60 | Needs Improvement - Complete additional study |

## Study Resources

If you scored below 70%, review these materials:
- Platform Engineering content modules 1-6
- Labs 1-12 (especially labs where topics were missed)
- Case studies for real-world context
- CNCF Platform Engineering whitepaper
- Backstage and Crossplane documentation

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Instructions
- Platform Engineering Fundamentals
- Developer Portal and Experience
- Infrastructure Abstraction

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"The platform makes developers more productive."* |
| ✓ | *"A golden path is a template that produces a repository with CI, manifests, dashboards and alerts already wired, so the product team owns none of them. It reduces cognitive load by removing decisions, not by adding features — and without a documented escape hatch it is a cage."* |

**Trace it:** A developer commits `service.yaml` → a running service with a dashboard and a paging rule. Name every system that acts, and which team owns each one.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** [Team Topologies — cognitive load](https://teamtopologies.com/key-concepts) and the [CNCF Platforms White Paper](https://tag-app-delivery.cncf.io/whitepapers/platforms/) — why golden paths exist at all.
Full list per domain: [`SOURCES.md`](../SOURCES.md#platform-engineering)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../MASTERY.md)

<!-- /feynman-check -->
