# Phase 4: Platform Engineering (Weeks 21-28)

Master GitOps, CI/CD, and platform automation—build self-service Kubernetes platforms.

## Learning Objectives

By the end of this phase, you will:
- [ ] Implement GitOps workflows with ArgoCD/Flux
- [ ] Build CI/CD pipelines for Kubernetes deployments
- [ ] Create self-service developer platforms
- [ ] Automate infrastructure lifecycle management

## Prerequisites

- Completed Phase 3: Production Readiness
- Understanding of Git workflows
- Experience with CI/CD concepts
- Working monitoring stack

## Content Structure

| Week | Topic | Content | Exercises |
|------|-------|---------|-----------|
| 21-23 | GitOps & ArgoCD | [01-gitops-argocd](01-gitops-argocd-README.md) | 7 exercises |
| 24-26 | CI/CD Pipelines | [02-cicd-pipelines](02-cicd-pipelines-README.md) | 6 exercises |
| 27-28 | Developer Platform | [03-developer-platform](03-developer-platform-README.md) | 5 exercises |

## Phase Project

**[Self-Service Platform](project-self-service-platform-README.md)**

Build an internal developer platform:
- ArgoCD for GitOps deployments
- Backstage for service catalog
- Crossplane for infrastructure provisioning
- Automated environments on PR
- Cost tracking and showback

## Progress Checklist

### Week 21-23: GitOps & ArgoCD
- [ ] Deploy and configure ArgoCD
- [ ] Implement App of Apps pattern
- [ ] Configure multi-cluster deployments
- [ ] Implement progressive delivery (Argo Rollouts)
- [ ] Set up GitOps for infrastructure (Crossplane)
- [ ] Configure RBAC and SSO for ArgoCD
- [ ] Implement secrets management in GitOps

### Week 24-26: CI/CD Pipelines
- [ ] Design Kubernetes-native CI/CD
- [ ] Implement Tekton pipelines
- [ ] Configure GitHub Actions for K8s
- [ ] Build container images with Kaniko/BuildKit
- [ ] Implement image scanning in pipelines
- [ ] Set up artifact management
- [ ] Configure deployment promotion

### Week 27-28: Developer Platform
- [ ] Deploy Backstage service catalog
- [ ] Create service templates
- [ ] Implement Crossplane compositions
- [ ] Build self-service workflows
- [ ] Configure cost allocation
- [ ] Implement platform guardrails

## Validation Criteria

Before moving to Phase 5, you should be able to:

1. **Design** GitOps workflows for complex deployments
2. **Build** CI/CD pipelines from scratch
3. **Implement** progressive delivery strategies
4. **Create** self-service developer experiences
5. **Complete** the phase project with full automation

## Time Investment

- **Study Time**: ~4-5 hours/day
- **Hands-On Practice**: ~3-4 hours/day
- **Total**: ~50-55 hours/week

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Validation Criteria
- Time Investment
- 23: GitOps & ArgoCD
- 26: CI/CD Pipelines

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"Kubernetes schedules the pod."* |
| ✓ | *"The scheduler watches for pods with no `nodeName`, filters nodes by predicates, scores the survivors, and writes `nodeName` into the pod spec. The kubelet on that node is watching the API for pods bound to it, and starts the containers."* |

**Trace it:** `kubectl apply -f pod.yaml` → a running container. Name every component that acts, in order, and what each one writes.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** [Kubernetes the Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way) — one weekend, and "the control plane" stops being a word.
Full list per domain: [`SOURCES.md`](../../SOURCES.md#kubernetes)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../../MASTERY.md)

<!-- /feynman-check -->
