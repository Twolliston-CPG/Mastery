# Phase 8 Assessment 2: Platform Engineering Practical Assessment

## Assessment Overview

| Attribute | Details |
|-----------|---------|
| **Duration** | 4-6 hours |
| **Format** | Hands-on implementation |
| **Passing Score** | 70% |
| **Total Points** | 100 |
| **Prerequisites** | Completion of Phase 8 labs, access to Kubernetes cluster |

## Introduction

This practical assessment evaluates your ability to design, implement, and operate platform engineering solutions. You will build components of an Internal Developer Platform for a fictional company and demonstrate platform engineering best practices.

## Scenario: BuildCo Platform Engineering

You are joining BuildCo, a software company with 100 engineers across 10 teams. They are building their first Internal Developer Platform. Your task is to implement key platform components that demonstrate your platform engineering skills.

### Current Environment

```yaml
environment:
  kubernetes: "Kind or Minikube cluster"
  source_control: "GitHub (or GitLab)"
  ci_cd: "GitHub Actions (or GitLab CI)"

  existing_tools:
    - kubectl configured and working
    - Helm 3.x installed
    - Docker or Podman available
    - Git configured

  provided_resources:
    - Base Kubernetes cluster
    - GitHub repository template
    - Sample application code
```

### Assessment Requirements

You must complete **all tasks in Parts 1-3** and **at least 2 tasks from Part 4**. Partial credit is available for incomplete tasks.

---

## Part 1: Developer Portal Setup (25 points)

### Task 1.1: Deploy Backstage (8 points)

Deploy a Backstage instance to your Kubernetes cluster with the following requirements:

**Requirements:**
- [ ] Backstage is accessible via ingress or port-forward
- [ ] PostgreSQL database is deployed for persistence
- [ ] Basic authentication is configured
- [ ] Catalog is populated with at least 3 sample services

**Deliverables:**
1. Kubernetes manifests or Helm values used for deployment
2. Screenshot of running Backstage instance
3. Brief documentation of access method

**Evaluation Criteria:**
| Criterion | Points |
|-----------|--------|
| Backstage running and accessible | 3 |
| PostgreSQL persistence configured | 2 |
| Authentication working | 1 |
| Catalog populated | 2 |

### Task 1.2: Create a Software Template (10 points)

Create a Backstage Software Template for a Python FastAPI microservice.

**Template Requirements:**
- [ ] Prompts for service name, description, owner
- [ ] Generates FastAPI application with health endpoint
- [ ] Includes Dockerfile (multi-stage build)
- [ ] Includes Kubernetes manifests (Deployment, Service)
- [ ] Includes GitHub Actions workflow (build, test, push)
- [ ] Registers service in Backstage catalog
- [ ] Includes README with setup instructions

**Template Structure:**
**`template/`**

- `template.yaml` — Backstage template definition
- `skeleton/`
  - `src/`
    - `main.py` — FastAPI application
    - `__init__.py`
  - `tests/`
    - `test_main.py` — Basic tests
  - Dockerfile
  - `requirements.txt`
  - `catalog-info.yaml` — Backstage catalog entry
  - `.github/`
    - `workflows/`
      - `ci.yaml` — CI pipeline
  - `k8s/`
    - `deployment.yaml`
    - `service.yaml`
- `README.md`


**Evaluation Criteria:**
| Criterion | Points |
|-----------|--------|
| Template syntax correct and valid | 2 |
| FastAPI app with health endpoint | 2 |
| Multi-stage Dockerfile | 1 |
| Kubernetes manifests correct | 2 |
| CI pipeline complete | 2 |
| Catalog integration | 1 |

### Task 1.3: Configure TechDocs (7 points)

Set up TechDocs for automated documentation generation.

**Requirements:**
- [ ] TechDocs backend configured in Backstage
- [ ] At least one service documented with TechDocs
- [ ] Documentation includes: Overview, API reference, Runbook
- [ ] Documentation is searchable

**Deliverables:**
1. TechDocs configuration (app-config.yaml changes)
2. Sample documentation (mkdocs.yml + markdown files)
3. Screenshot of rendered documentation

**Evaluation Criteria:**
| Criterion | Points |
|-----------|--------|
| TechDocs backend configured | 2 |
| Documentation renders correctly | 2 |
| Required sections present | 2 |
| Search functional | 1 |

---

## Part 2: Infrastructure Abstraction (25 points)

### Task 2.1: Deploy Crossplane (5 points)

Install and configure Crossplane in your cluster.

**Requirements:**
- [ ] Crossplane installed via Helm
- [ ] At least one provider configured (Kubernetes provider is acceptable)
- [ ] Provider is healthy and ready

**Deliverables:**
1. Helm values or installation commands
2. Output showing healthy Crossplane installation

**Evaluation Criteria:**
| Criterion | Points |
|-----------|--------|
| Crossplane installed | 2 |
| Provider configured | 2 |
| Provider healthy | 1 |

### Task 2.2: Create an XRD and Composition (12 points)

Create a Crossplane abstraction for a "Application Environment" that developers can self-service.

**ApplicationEnvironment should create:**
- Kubernetes Namespace
- ResourceQuota (based on tier: small, medium, large)
- LimitRange
- NetworkPolicy (default deny ingress)
- ServiceAccount
- RoleBinding (for a specified group)

**XRD Interface:**
```yaml
apiVersion: platform.buildco.io/v1alpha1
kind: ApplicationEnvironment
metadata:
  name: my-app-staging
spec:
  name: my-app
  environment: staging
  tier: medium        # small, medium, large
  teamGroup: my-team  # Group for RBAC
```

**Tier Specifications:**
```yaml
tiers:
  small:
    cpu: "2"
    memory: "4Gi"
    pods: "20"
  medium:
    cpu: "8"
    memory: "16Gi"
    pods: "50"
  large:
    cpu: "32"
    memory: "64Gi"
    pods: "100"
```

**Deliverables:**
1. XRD definition (YAML)
2. Composition (YAML)
3. Example claim demonstrating usage
4. Output showing provisioned resources

**Evaluation Criteria:**
| Criterion | Points |
|-----------|--------|
| XRD schema correct | 3 |
| Composition creates all resources | 4 |
| ResourceQuota varies by tier | 2 |
| RBAC configured correctly | 2 |
| Example claim works | 1 |

### Task 2.3: Self-Service Workflow (8 points)

Create a self-service workflow that developers can use to request an ApplicationEnvironment.

**Option A: Backstage Plugin/Action**
- Create a custom action or scaffolder step
- Integrate with Crossplane to create claim

**Option B: CLI Tool**
- Create a simple CLI (bash script or Go/Python)
- Validates input, creates claim, shows status

**Option C: GitHub/GitLab Workflow**
- Create an issue template for requests
- Workflow creates claim via GitOps

**Requirements (any option):**
- [ ] Developer can request environment without kubectl
- [ ] Input validation for tier and environment
- [ ] Feedback on request status
- [ ] Request is auditable (logged or in git)

**Evaluation Criteria:**
| Criterion | Points |
|-----------|--------|
| Request mechanism works | 3 |
| Input validation | 2 |
| Status feedback | 2 |
| Audit trail | 1 |

---

## Part 3: Policy and Governance (25 points)

### Task 3.1: Deploy OPA Gatekeeper (5 points)

Install OPA Gatekeeper in your cluster.

**Requirements:**
- [ ] Gatekeeper installed and running
- [ ] Audit functionality enabled
- [ ] Mutation webhook configured (optional)

**Deliverables:**
1. Installation commands or manifests
2. Output showing healthy Gatekeeper pods

**Evaluation Criteria:**
| Criterion | Points |
|-----------|--------|
| Gatekeeper installed | 3 |
| Audit enabled | 2 |

### Task 3.2: Implement Security Policies (12 points)

Create and deploy the following ConstraintTemplates and Constraints:

**Policy 1: Required Labels**
- All pods must have: `team`, `app`, `environment` labels
- Enforcement mode: deny

**Policy 2: No Privileged Containers**
- Pods cannot run privileged containers
- Pods cannot run as root
- Enforcement mode: deny

**Policy 3: Approved Registries**
- Images must come from approved registries:
  - `ghcr.io/buildco/`
  - `docker.io/library/`
- Enforcement mode: deny

**Policy 4: Resource Limits Required**
- All containers must have CPU and memory limits
- Enforcement mode: warn (audit only)

**Deliverables:**
1. ConstraintTemplates for each policy
2. Constraints with appropriate configurations
3. Test manifests showing enforcement (both passing and failing)
4. Output showing policy violations in audit

**Evaluation Criteria:**
| Criterion | Points |
|-----------|--------|
| Required labels policy | 3 |
| No privileged policy | 3 |
| Approved registries policy | 3 |
| Resource limits policy (audit) | 2 |
| Testing demonstrates enforcement | 1 |

### Task 3.3: Policy Exception System (8 points)

Implement a mechanism for requesting and granting policy exceptions.

**Requirements:**
- [ ] Developers can request exceptions with justification
- [ ] Exceptions are time-limited (e.g., 7 days)
- [ ] Exceptions are tracked/auditable
- [ ] Approved exceptions allow deployment

**Implementation Options:**
- Config file with exemptions checked into git
- Namespace annotations that grant exceptions
- Custom constraint parameters for exemptions
- External approval workflow that modifies constraints

**Deliverables:**
1. Exception mechanism documentation
2. Example exception request and approval
3. Demonstration of exception working

**Evaluation Criteria:**
| Criterion | Points |
|-----------|--------|
| Exception mechanism implemented | 3 |
| Time-limited exceptions | 2 |
| Audit trail | 2 |
| Demonstrated working | 1 |

---

## Part 4: Choose Your Own Adventure (25 points)

Complete **at least 2** of the following tasks. Each task is worth 12-13 points.

### Option A: Platform CLI (12 points)

Create a CLI tool that provides a unified interface to platform capabilities.

**Required Commands:**
```bash
buildco service list      # List services from catalog
buildco service create    # Create from template
buildco env request       # Request ApplicationEnvironment
buildco env status        # Check environment status
buildco policy check      # Validate manifests against policies
```

**Requirements:**
- [ ] At least 3 commands implemented
- [ ] Help text for all commands
- [ ] Error handling with helpful messages
- [ ] Outputs in human-readable and JSON formats

**Evaluation Criteria:**
| Criterion | Points |
|-----------|--------|
| Commands work correctly | 4 |
| Help text present | 2 |
| Error handling | 3 |
| Output formats | 3 |

### Option B: Platform Metrics Dashboard (12 points)

Create a Grafana dashboard showing platform health and adoption metrics.

**Required Metrics:**
- Number of services in catalog
- Deployments per day/week
- Policy violations (current and trend)
- Self-service request volume and success rate

**Requirements:**
- [ ] Prometheus metrics collection configured
- [ ] At least 4 panels showing platform metrics
- [ ] Dashboard is importable (JSON export)
- [ ] Documentation on metrics sources

**Evaluation Criteria:**
| Criterion | Points |
|-----------|--------|
| Metrics collection working | 3 |
| Dashboard panels functional | 4 |
| Dashboard exportable | 2 |
| Documentation | 3 |

### Option C: GitOps Deployment (12 points)

Configure ArgoCD for GitOps-based platform component management.

**Requirements:**
- [ ] ArgoCD installed and accessible
- [ ] ApplicationSet for managing services
- [ ] Automatic sync for dev environment
- [ ] Manual sync with approval for prod
- [ ] Rollback demonstrated

**Evaluation Criteria:**
| Criterion | Points |
|-----------|--------|
| ArgoCD installed | 2 |
| ApplicationSet configured | 4 |
| Sync policies correct | 3 |
| Rollback working | 3 |

### Option D: Developer Onboarding Automation (13 points)

Create an automated onboarding workflow for new developers.

**Workflow should:**
- [ ] Create personal development namespace
- [ ] Configure RBAC for the developer
- [ ] Clone and configure template repository
- [ ] Deploy sample application
- [ ] Send welcome notification (email, Slack, or file)

**Requirements:**
- [ ] Triggered by adding user to a group/config
- [ ] Idempotent (can be re-run safely)
- [ ] Logged for audit purposes
- [ ] Includes cleanup/offboarding

**Evaluation Criteria:**
| Criterion | Points |
|-----------|--------|
| Automation works end-to-end | 4 |
| All resources created | 3 |
| Idempotent | 2 |
| Audit logging | 2 |
| Offboarding included | 2 |

### Option E: Documentation System (12 points)

Create a comprehensive documentation system for the platform.

**Required Documentation:**
- [ ] Platform overview and architecture
- [ ] Getting started guide (< 15 minutes to first deployment)
- [ ] How-to guides for common tasks
- [ ] API/CLI reference
- [ ] Troubleshooting guide

**Requirements:**
- [ ] Documentation in MkDocs or similar
- [ ] Automated build and publish
- [ ] Search functionality
- [ ] Feedback mechanism (edit links, comments, or form)

**Evaluation Criteria:**
| Criterion | Points |
|-----------|--------|
| All required docs present | 4 |
| Quality and clarity | 3 |
| Automated publishing | 2 |
| Search and feedback | 3 |

---

## Submission Requirements

### Repository Structure

Submit your work as a Git repository with the following structure:

**`platform-assessment/`**

- `README.md` — Overview and setup instructions
- `part1-portal/`
  - `backstage/`
    - `helm-values.yaml`
    - `app-config.yaml`
  - `templates/`
    - `fastapi-service/`
  - `techdocs/`
- `part2-infrastructure/`
  - `crossplane/`
    - `provider.yaml`
    - `xrd.yaml`
    - `composition.yaml`
  - `self-service/`
- `part3-policy/`
  - `gatekeeper/`
    - `templates/`
    - `constraints/`
  - `exceptions/`
- part4-[chosen-option]/
  - `...`
- `screenshots/`
  - `...`
- `docs/`
  - `assessment-notes.md` — Your notes and decisions


### Documentation Requirements

Your `README.md` should include:

1. **Setup Instructions**
   - Prerequisites
   - Step-by-step deployment guide
   - How to verify each component

2. **Architecture Overview**
   - Diagram of implemented components
   - How components interact

3. **Design Decisions**
   - Key decisions made and rationale
   - Trade-offs considered

4. **Known Limitations**
   - What's not implemented
   - What would be improved with more time

### Verification Checklist

Before submitting, verify:

- [ ] All deployed components are running
- [ ] Screenshots captured for each part
- [ ] README has complete setup instructions
- [ ] Code is commented where non-obvious
- [ ] No secrets committed to repository

---

## Evaluation Rubric

### Part 1: Developer Portal (25 points)

| Task | Max Points | Criteria |
|------|------------|----------|
| 1.1 Backstage Deploy | 8 | Working deployment with persistence and catalog |
| 1.2 Software Template | 10 | Complete, functional template with all components |
| 1.3 TechDocs | 7 | Working documentation with search |

### Part 2: Infrastructure Abstraction (25 points)

| Task | Max Points | Criteria |
|------|------------|----------|
| 2.1 Crossplane Deploy | 5 | Healthy installation with provider |
| 2.2 XRD and Composition | 12 | Correct abstraction with all resources |
| 2.3 Self-Service Workflow | 8 | Functional request mechanism with audit |

### Part 3: Policy and Governance (25 points)

| Task | Max Points | Criteria |
|------|------------|----------|
| 3.1 Gatekeeper Deploy | 5 | Working installation with audit |
| 3.2 Security Policies | 12 | All four policies implemented and tested |
| 3.3 Exception System | 8 | Functional exception mechanism |

### Part 4: Choose Your Own (25 points)

| Task | Max Points | Criteria |
|------|------------|----------|
| Chosen Task 1 | 12-13 | Meets task-specific criteria |
| Chosen Task 2 | 12-13 | Meets task-specific criteria |

### Documentation and Quality (Implicit)

These factors are considered across all parts:

- Code quality and organization
- Documentation clarity
- Error handling
- Security considerations
- Following best practices

---

## Scoring Guide

| Score | Level | Meaning |
|-------|-------|---------|
| 90-100 | Exceptional | Production-ready implementation, excellent documentation |
| 80-89 | Proficient | All requirements met, good quality |
| 70-79 | Competent | Core requirements met, some gaps |
| 60-69 | Developing | Partial implementation, review needed |
| <60 | Needs Improvement | Significant gaps, additional practice required |

---

## Hints and Tips

### Part 1 Tips
- Start with a simple Backstage deployment, add features incrementally
- Use the official Backstage software template as a reference
- TechDocs can use local storage for this assessment

### Part 2 Tips
- Use the Crossplane Kubernetes provider if you don't have cloud access
- Test your composition with simple claims first
- Remember: XRD defines the API, Composition implements it

### Part 3 Tips
- Start with one policy, get it working, then add more
- Use `gator test` to validate policies locally
- Audit mode (`enforcement: warn`) is useful for testing

### Part 4 Tips
- Choose options that align with your strengths
- It's better to do two tasks well than four tasks poorly
- Document your reasoning for partial implementations

---

## Support and Resources

### Reference Documentation
- [Backstage Documentation](https://backstage.io/docs)
- [Crossplane Documentation](https://crossplane.io/docs)
- [OPA Gatekeeper Documentation](https://open-policy-agent.github.io/gatekeeper)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io)

### Sample Repositories
- [Backstage Software Templates](https://github.com/backstage/software-templates)
- [Crossplane Examples](https://docs.crossplane.io/latest/)
- [Gatekeeper Policy Library](https://github.com/open-policy-agent/gatekeeper-library)

### Troubleshooting
- Check pod logs: `kubectl logs -n <namespace> <pod>`
- Describe resources: `kubectl describe <resource> <name>`
- Check events: `kubectl get events -n <namespace>`

---

## Time Management Suggestions

| Part | Suggested Time | Notes |
|------|----------------|-------|
| Part 1 | 1.5-2 hours | Template creation takes longest |
| Part 2 | 1-1.5 hours | Composition logic is complex |
| Part 3 | 1-1.5 hours | Policy testing takes time |
| Part 4 | 1-1.5 hours | Depends on chosen options |
| Documentation | 30-45 min | Don't skip this |

**Total:** 4-6 hours

---

## Assessment Completion

When you have completed the assessment:

1. Ensure all components are deployed and running
2. Capture screenshots of each working component
3. Complete the README with setup instructions
4. Push all code to your repository
5. Submit the repository URL

Good luck! This assessment is designed to evaluate real-world platform engineering skills. Focus on demonstrating understanding of the concepts, not just getting things working.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Scenario: BuildCo Platform Engineering
- Developer Portal Setup
- Infrastructure Abstraction
- Policy and Governance

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
