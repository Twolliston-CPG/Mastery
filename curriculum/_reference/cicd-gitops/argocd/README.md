# Argo CD Mastery Roadmap

**From Beginner to Elite GitOps Engineer**

A comprehensive, hands-on learning path for mastering Argo CD and GitOps practices.

## Quick Start

```bash
# Run the setup script
./setup.sh

# Choose option 4 for full setup
```

## Directory Structure

**`.`**

| File | What it is |
|---|---|
| `ARGOCD_MASTERY_ROADMAP.md` | Complete learning guide |
| `setup.sh` | Main setup script |
| `phase-0-prerequisites/` | Cluster setup scripts |
| `phase-1-foundation/` | Architecture exploration |
| `phase-2-core-concepts/` | First applications |
| `phase-3-application-sources/` | Helm, Kustomize, multi-source |
| `phase-4-sync-lifecycle/` | Waves, hooks, policies |
| `phase-5-applicationsets/` | Generators, scaling |
| phase-6-projects-multitenancy/# Team isolation |  |
| `phase-7-security/` | RBAC, secrets |
| `phase-8-observability/` | Metrics, notifications |
| `phase-9-ha-dr/` | HA, backup/restore |
| `phase-10-advanced/` | App-of-apps, multi-cluster |
| `capstone/` | Final project |


## Learning Path

| Phase | Topic | Duration |
|-------|-------|----------|
| 0 | Prerequisites | 30 min |
| 1 | Foundation & Architecture | 1-2 hours |
| 2 | Core Concepts | 1-2 hours |
| 3 | Application Sources | 2-3 hours |
| 4 | Sync Lifecycle | 2-3 hours |
| 5 | ApplicationSets | 2-3 hours |
| 6 | Projects & Multi-Tenancy | 2-3 hours |
| 7 | Security & Access Control | 2-3 hours |
| 8 | Observability | 2-3 hours |
| 9 | HA & Disaster Recovery | 2-3 hours |
| 10 | Advanced Patterns | 2-3 hours |
| Capstone | Complete Platform | 4-6 hours |

## Prerequisites

- Docker Desktop or equivalent
- kubectl
- kind (Kubernetes in Docker)
- helm
- git
- argocd CLI (optional but recommended)

Install on macOS:
```bash
brew install kubectl kind helm git argocd
```

## How to Use

1. Read `ARGOCD_MASTERY_ROADMAP.md` for concepts
2. Run labs in each phase directory
3. Complete knowledge checks before moving on
4. Build the capstone project to prove mastery

## Labs Overview

### Phase 0: Prerequisites
- Create kind cluster
- Install Argo CD
- Verify setup

### Phase 1: Foundation
- Explore architecture
- CLI basics

### Phase 2: Core Concepts
- Create first application
- Understand sync vs health
- Refresh vs sync

### Phase 3: Application Sources
- Plain manifests
- Kustomize overlays
- Helm charts
- Multiple sources

### Phase 4: Sync Lifecycle
- Sync waves
- Resource hooks
- Auto-sync policies
- Ignore differences

### Phase 5: ApplicationSets
- List generator
- Cluster generator
- Git directory/file generators
- Matrix and merge generators
- Pull request generator
- Progressive sync

### Phase 6: Projects & Multi-Tenancy
- Team projects
- Source/destination restrictions
- Sync windows

### Phase 7: Security
- RBAC configuration
- Local users
- Repository credentials
- External secrets

### Phase 8: Observability
- Prometheus metrics
- Alerting rules
- Notifications
- Custom health checks

### Phase 9: HA & Disaster Recovery
- HA installation
- Performance tuning
- Controller sharding
- Backup and restore

### Phase 10: Advanced Patterns
- App of apps
- Multi-cluster
- CI/CD integration

### Capstone
- Complete multi-team GitOps platform
- All features combined

## Customization

Before using the labs, update repository URLs:

```bash
# Replace YOUR_USERNAME with your GitHub username
find . -name "*.yaml" -exec sed -i '' 's/YOUR_USERNAME/your-actual-username/g' {} \;
```

## Resources

- [Official Docs](https://argo-cd.readthedocs.io/)
- [Argo CD GitHub](https://github.com/argoproj/argo-cd)
- [Example Apps](https://github.com/argoproj/argocd-example-apps)

## License

This learning material is provided for educational purposes.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Labs Overview
- Customization
- Foundation
- Core Concepts

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"The pipeline deploys the application."* |
| ✓ | *"CI writes a new image tag into a config repository and stops. A controller running *inside* the cluster polls that repo, diffs the rendered manifests against live state, and applies the difference — so nothing outside the cluster ever holds credentials to it."* |

**Trace it:** `git push` → the new version serving traffic, with nothing else typed. Name where the handoff between CI and CD happens, and what that handoff physically is.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** the four [OpenGitOps principles](https://opengitops.dev/#principles) — then say which one a `kubectl apply` inside CI violates.
Full list per domain: [`SOURCES.md`](../../SOURCES.md#cicd-gitops)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../../MASTERY.md)

<!-- /feynman-check -->
