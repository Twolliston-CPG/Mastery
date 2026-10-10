# Lab 12: Platform Engineering Capstone Project

## Lab Overview

| Attribute | Details |
|-----------|---------|
| **Duration** | 8-12 hours (multi-day project) |
| **Level** | Advanced |
| **Prerequisites** | All Phase 8 labs, full curriculum completion |
| **Environment** | Complete platform stack |
| **Learning Objectives** | Integrate all platform engineering skills in a comprehensive project |

## Introduction

This capstone project challenges you to design and implement a complete Internal Developer Platform (IDP) for a fictional company. You'll apply everything learned throughout the DevOps Academy to create a production-grade platform that demonstrates mastery of platform engineering principles.

## The Scenario

### Company Profile: TechCorp Global

**Industry:** B2B SaaS (Enterprise Resource Planning)
**Size:** 500 engineers across 40 teams
**Current State:**
- Multiple deployment methods (manual, scripts, various CI/CD tools)
- Inconsistent environments between teams
- Long onboarding time (4-6 weeks for new developers)
- Frequent production incidents related to deployment issues
- Teams spending 30% of time on infrastructure tasks

**Strategic Goals:**
1. Reduce time-to-production for new services from 4 weeks to 1 day
2. Decrease developer time spent on infrastructure from 30% to 5%
3. Reduce new developer onboarding time from 6 weeks to 1 week
4. Achieve 99.9% deployment success rate
5. Enable teams to self-service 80% of infrastructure needs

## Project Requirements

### Part 1: Platform Strategy and Design

**Deliverable: Platform Strategy Document (2-3 pages)**

Create a comprehensive strategy document that includes:

#### 1.1 Current State Assessment
- Document existing tooling and processes
- Identify key pain points
- Map stakeholder concerns
- Assess team capabilities

#### 1.2 Platform Vision
- Define the target state
- Articulate value proposition
- Identify success metrics
- Create platform principles

#### 1.3 Architecture Design
Create architecture diagrams showing:

**Required Components:**

- Developer Portal (Backstage)
- Infrastructure Abstraction (Crossplane)
- GitOps Engine (ArgoCD)
- CI/CD Platform (GitHub Actions / GitLab CI)
- Observability Stack (Prometheus, Grafana, Loki)
- Policy Engine (OPA Gatekeeper)
- Secret Management (Vault / External Secrets)
- Identity Management (IdentityCo / Azure AD integration)


#### 1.4 Adoption Roadmap
- Phase 1: Foundation (Months 1-3)
- Phase 2: Self-Service (Months 4-6)
- Phase 3: Optimization (Months 7-12)

**Evaluation Criteria:**
- [ ] Clear articulation of current state problems
- [ ] Realistic and measurable goals
- [ ] Architecture addresses all requirements
- [ ] Adoption plan considers organizational change

---

### Part 2: Core Platform Implementation

**Deliverable: Working Platform Components**

#### 2.1 Developer Portal Setup

Implement a Backstage-based developer portal with:

```yaml
# Minimum required functionality
backstage_features:
  catalog:
    - Service catalog with 5+ example services
    - API catalog with OpenAPI integration
    - Team and ownership information
    - Dependency mapping

  templates:
    - Go microservice template
    - Python FastAPI template
    - Frontend React template

  plugins:
    - Kubernetes integration
    - ArgoCD integration
    - GitHub integration
    - TechDocs

  techdocs:
    - At least 3 documented services
    - Onboarding documentation
    - Platform user guide
```

```typescript
// Example: Custom plugin for platform metrics
// plugins/platform-metrics/src/components/PlatformOverview.tsx

export const PlatformOverview: React.FC = () => {
  // Show key platform metrics:
  // - Total services in catalog
  // - Templates used this month
  // - Active deployments
  // - Self-service success rate

  return (
    // Your implementation
  );
};
```

#### 2.2 Infrastructure Abstraction Layer

Implement Crossplane compositions for:

```yaml
# Required abstractions
infrastructure_abstractions:
  databases:
    - PostgreSQL (small, medium, large tiers)
    - Redis cache cluster

  storage:
    - S3-compatible object storage

  messaging:
    - Kafka topic (shared cluster)

  networking:
    - Application load balancer
    - DNS record management

  applications:
    - Complete application environment
    - Includes namespace, RBAC, resource quotas
```

Example composition requirement:

```yaml
# crossplane/application-environment/composition.yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: application-environment
spec:
  compositeTypeRef:
    apiVersion: platform.techcorp.io/v1alpha1
    kind: ApplicationEnvironment
  resources:
    # Implement the following:
    # - Namespace with labels
    # - ResourceQuota based on tier
    # - LimitRange for pod defaults
    # - NetworkPolicy (default deny ingress)
    # - ServiceAccount
    # - RoleBinding for team access
    # - ConfigMap with environment metadata
```

#### 2.3 Golden Path Templates

Create 3 complete software templates:

**Template 1: Backend API Service**
- Language: Go or Python
- Framework: Chi/Gin or FastAPI
- Database: PostgreSQL connection
- Features: Health checks, metrics, tracing
- CI/CD: Complete pipeline
- Kubernetes: Production-ready manifests
- Documentation: TechDocs setup

**Template 2: Frontend Application**
- Framework: React or Next.js
- Build: Optimized production build
- CDN: Static asset delivery
- CI/CD: Preview environments
- Testing: Unit and E2E tests

**Template 3: Event-Driven Service**
- Messaging: Kafka consumer/producer
- Processing: At-least-once semantics
- Observability: Consumer lag metrics
- Error handling: Dead letter queue

**Evaluation Criteria:**
- [ ] All components deploy successfully
- [ ] Templates generate working services
- [ ] Abstractions provision real resources
- [ ] Integration between components works

---

### Part 3: Governance and Security

**Deliverable: Policy Framework**

#### 3.1 Policy Implementation

Implement policies using OPA Gatekeeper:

```yaml
# Required policies
policies:
  security:
    - No privileged containers
    - Required security context
    - Approved image registries only
    - No latest tags
    - Required resource limits

  compliance:
    - Required labels (team, cost-center, environment)
    - Required annotations (owner, on-call)
    - Namespace naming conventions

  operational:
    - Minimum replicas in production
    - Required readiness/liveness probes
    - PodDisruptionBudget required
```

#### 3.2 Policy Exceptions Process

Implement an exception workflow:

```yaml
# exception_workflow:
steps:
  1. Developer requests exception via CLI or portal
  2. Automatic validation of justification
  3. Notification to approvers
  4. Approval tracked in audit log
  5. Time-limited exception applied
  6. Automatic expiration and cleanup
```

#### 3.3 Audit and Compliance Dashboard

Create a dashboard showing:
- Current policy compliance rate
- Violations by team/namespace
- Exception status and expiration
- Trend over time

**Evaluation Criteria:**
- [ ] Policies enforce correctly
- [ ] Exception process is functional
- [ ] Audit trail is complete
- [ ] Dashboard provides actionable insights

---

### Part 4: Developer Experience

**Deliverable: Complete Developer Workflows**

#### 4.1 Platform CLI

Extend the platform CLI with commands:

```bash
# Required CLI commands
platform service create    # Create new service from template
platform service deploy    # Deploy service to environment
platform service logs      # Stream service logs
platform service status    # Show deployment status

platform infra request     # Request infrastructure
platform infra list        # List owned resources
platform infra delete      # Cleanup resources

platform auth login        # Authenticate
platform auth token        # Get current token

platform docs open         # Open documentation
platform docs search       # Search documentation

platform team list         # List team members
platform team oncall       # Show on-call schedule
```

#### 4.2 Onboarding Automation

Implement automated onboarding:

```yaml
# onboarding_flow:
trigger: New user in identity provider
steps:
  - Create GitHub organization membership
  - Add to team repositories
  - Create Kubernetes RBAC
  - Create personal dev namespace
  - Send welcome message with:
    - Quick start guide link
    - Team channel invitation
    - Assigned buddy information
  - Create learning path
  - Schedule 30-day check-in
```

#### 4.3 Self-Service Workflows

Implement end-to-end self-service:

1. **New Service Creation**
   - Developer uses template in Backstage
   - Repository created automatically
   - CI/CD configured
   - Service registered in catalog
   - Initial deployment to development

2. **Database Provisioning**
   - Developer requests via portal or CLI
   - Approval (if required for tier)
   - Database provisioned
   - Credentials stored in Vault
   - Connection info in service config

3. **Environment Promotion**
   - Developer triggers promotion
   - Automated testing gates
   - Approval workflow for production
   - Deployment with rollback capability

**Evaluation Criteria:**
- [ ] CLI provides smooth developer experience
- [ ] Onboarding completes without manual intervention
- [ ] Self-service workflows function end-to-end
- [ ] Error handling provides clear guidance

---

### Part 5: Observability and Operations

**Deliverable: Operational Excellence**

#### 5.1 Platform Metrics

Implement comprehensive platform observability:

```yaml
# platform_metrics:
adoption:
  - Templates used (by type, team)
  - Self-service success rate
  - Time to first deployment
  - Active developers per day

health:
  - Platform component availability
  - API response times
  - Error rates by component
  - Queue depths

developer_experience:
  - CLI command success rate
  - Portal response times
  - Search effectiveness
  - Documentation views
```

#### 5.2 SLOs for Platform

Define and implement platform SLOs:

| Service | SLI | SLO Target |
|---------|-----|------------|
| Developer Portal | Availability | 99.9% |
| Developer Portal | Latency (p99) | < 2s |
| GitOps Sync | Sync success rate | 99.5% |
| GitOps Sync | Sync latency | < 5m |
| Self-Service | Request success rate | 99% |
| Self-Service | Provisioning time | < 15m |

#### 5.3 Runbooks and Incident Response

Create runbooks for:
- Platform component failures
- Self-service provisioning stuck
- GitOps sync failures
- Authentication issues
- Template generation errors

**Evaluation Criteria:**
- [ ] Metrics cover adoption, health, and experience
- [ ] SLOs are measurable and monitored
- [ ] Alerts are actionable
- [ ] Runbooks enable fast resolution

---

### Part 6: Documentation and Training

**Deliverable: Complete Platform Documentation**

#### 6.1 Platform Documentation

**`docs/`**

- `getting-started/`
  - `quickstart.md`
  - `first-service.md`
  - `local-development.md`
- `user-guide/`
  - `services/`
  - `infrastructure/`
  - `deployments/`
- `architecture/`
  - `overview.md`
  - `components.md`
  - `security.md`
- `operations/`
  - `runbooks/`
  - `troubleshooting.md`
- `contributing/`
  - `templates.md`
  - `platform-development.md`


#### 6.2 Training Materials

Create training content:
- Platform overview presentation (10 slides)
- Hands-on tutorial (1 hour)
- FAQ document
- Video walkthrough script

**Evaluation Criteria:**
- [ ] Documentation is complete and accurate
- [ ] Getting started guide works for new users
- [ ] Training materials are engaging
- [ ] Content is searchable in portal

---

## Submission Requirements

### Required Artifacts

1. **Strategy Document** (PDF, 2-3 pages)
   - Platform vision and goals
   - Architecture decisions
   - Adoption roadmap

2. **Implementation Repository**
   - All platform components
   - Infrastructure-as-code
   - CI/CD configurations
   - Documentation

3. **Demo Recording** (15-20 minutes)
   - Platform walkthrough
   - Developer workflow demonstration
   - Self-service in action
   - Metrics and dashboards

4. **Architecture Diagrams**
   - High-level architecture
   - Component interactions
   - Data flow
   - Security model

5. **Retrospective Document** (1-2 pages)
   - What went well
   - Challenges faced
   - Lessons learned
   - Future improvements

### Evaluation Rubric

| Category | Weight | Criteria |
|----------|--------|----------|
| Strategy | 15% | Clear vision, realistic goals, comprehensive plan |
| Implementation | 35% | Working components, integration, code quality |
| Governance | 15% | Effective policies, exception handling, compliance |
| Developer Experience | 20% | Smooth workflows, helpful tooling, documentation |
| Observability | 10% | Comprehensive metrics, actionable alerts |
| Presentation | 5% | Clear demo, good documentation |

### Scoring Guide

- **Exceptional (90-100%)**: All requirements met, production-quality implementation, innovative solutions
- **Proficient (75-89%)**: All core requirements met, good implementation quality
- **Developing (60-74%)**: Most requirements met, some gaps in implementation
- **Beginning (<60%)**: Significant gaps in requirements or implementation

---

## Tips for Success

### Planning

1. Start with the strategy document
2. Prioritize core platform components
3. Build incrementally, test often
4. Document as you build

### Implementation

1. Use existing tools and integrations
2. Start with minimal viable implementations
3. Focus on end-to-end workflows first
4. Add polish and features later

### Common Pitfalls

- Over-engineering early
- Skipping documentation
- Not testing developer workflows
- Ignoring error handling
- Building in isolation

### Time Management

| Phase | Suggested Time |
|-------|---------------|
| Strategy & Planning | 2 hours |
| Core Platform Setup | 3 hours |
| Templates & Self-Service | 2 hours |
| Governance & Security | 1.5 hours |
| Observability | 1 hour |
| Documentation | 1 hour |
| Demo & Polish | 1.5 hours |

---

## Resources

### Reference Implementations
- [Backstage Demo](https://demo.backstage.io)
- [Crossplane Examples](https://docs.crossplane.io/latest/)
- [ArgoCD Examples](https://github.com/argoproj/argocd-example-apps)

### Documentation
- [Backstage Documentation](https://backstage.io/docs)
- [Crossplane Documentation](https://crossplane.io/docs)
- [OPA Gatekeeper](https://open-policy-agent.github.io/gatekeeper)

### Community
- [CNCF Slack](https://slack.cncf.io)
- [Platform Engineering Community](https://platformengineering.org)

---

## Conclusion

This capstone project represents the culmination of your platform engineering journey. By completing it, you demonstrate:

- **Strategic Thinking**: Ability to design platforms that deliver business value
- **Technical Depth**: Mastery of platform engineering tools and patterns
- **Developer Empathy**: Focus on creating great developer experiences
- **Operational Excellence**: Building reliable, observable, maintainable systems
- **Leadership**: Ability to drive change and adoption

Good luck! Remember that platform engineering is about enabling others to do their best work. Keep the developer experience at the center of every decision.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- The Scenario
- Project Requirements
- Company Profile: TechCorp Global
- Platform Strategy and Design

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
