# Phase 2: Core Operations (Weeks 7-12)

Master networking, storage, and configuration management—the operational foundation of production Kubernetes.

## Learning Objectives

By the end of this phase, you will:
- [ ] Design and implement Kubernetes networking
- [ ] Configure persistent storage for stateful workloads
- [ ] Manage configuration and secrets securely
- [ ] Complete a production networking stack deployment

## Prerequisites

- Completed Phase 1: Foundation
- Working Kubernetes cluster (local or cloud)
- Basic understanding of TCP/IP networking

## Content Structure

| Week | Topic | Content | Exercises |
|------|-------|---------|-----------|
| 7-8 | Networking Deep Dive | [01-networking-deep-dive](01-networking-deep-dive-README.md) | 6 exercises |
| 9-10 | Storage Systems | [02-storage-systems](02-storage-systems-README.md) | 5 exercises |
| 11-12 | Configuration & Secrets | [03-configuration-secrets](03-configuration-secrets-README.md) | 5 exercises |

## Phase Project

**[Production Networking Stack](project-production-networking-README.md)**

Build a complete production networking setup:
- Cilium CNI with network policies
- NGINX Ingress Controller with TLS
- cert-manager for automatic certificates
- External DNS for automatic DNS records
- Service mesh basics (optional)

## Progress Checklist

### Week 7-8: Networking Deep Dive
- [ ] Understand Pod networking model
- [ ] Configure and compare CNI plugins
- [ ] Master Service types and use cases
- [ ] Deploy and configure Ingress controllers
- [ ] Implement Network Policies for segmentation
- [ ] Understand CoreDNS and cluster DNS

### Week 9-10: Storage Systems
- [ ] Understand PV/PVC lifecycle
- [ ] Configure Storage Classes
- [ ] Deploy stateful workloads with persistence
- [ ] Implement volume snapshots and backup
- [ ] Work with CSI drivers

### Week 11-12: Configuration & Secrets
- [ ] Master ConfigMap patterns
- [ ] Implement secure secrets management
- [ ] Deploy External Secrets Operator
- [ ] Integrate with HashiCorp Vault
- [ ] Implement GitOps-friendly secret patterns

## Validation Criteria

Before moving to Phase 3, you should be able to:

1. **Design** a network topology with proper segmentation
2. **Implement** Network Policies from scratch
3. **Configure** persistent storage for any workload
4. **Manage** secrets without storing them in Git
5. **Complete** the phase project with all components working

## Time Investment

- **Study Time**: ~3-4 hours/day
- **Hands-On Practice**: ~2 hours/day
- **Total**: ~35-40 hours/week

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Validation Criteria
- Time Investment
- 8: Networking Deep Dive
- 10: Storage Systems

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
