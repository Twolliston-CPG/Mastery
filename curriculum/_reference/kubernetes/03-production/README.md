# Phase 3: Production Readiness (Weeks 13-20)

Master observability, security, and performance—the pillars of production Kubernetes.

## Learning Objectives

By the end of this phase, you will:
- [ ] Implement comprehensive observability (metrics, logs, traces)
- [ ] Configure security controls and RBAC policies
- [ ] Optimize cluster and workload performance
- [ ] Build a production-ready monitoring platform

## Prerequisites

- Completed Phase 2: Core Operations
- Understanding of networking and storage
- Working Kubernetes cluster with 3+ nodes

## Content Structure

| Week | Topic | Content | Exercises |
|------|-------|---------|-----------|
| 13-15 | Observability Stack | [01-observability-stack](01-observability-stack-README.md) | 8 exercises |
| 16-18 | Security & RBAC | [02-security-rbac](02-security-rbac-README.md) | 7 exercises |
| 19-20 | Scaling & Performance | [03-scaling-performance](03-scaling-performance-README.md) | 6 exercises |

## Phase Project

**[Production Monitoring Platform](project-production-platform-README.md)**

Build enterprise-grade observability:
- Prometheus + Thanos for metrics
- Grafana dashboards with alerts
- Loki for log aggregation
- Jaeger/Tempo for distributed tracing
- PagerDuty/Slack alert routing

## Progress Checklist

### Week 13-15: Observability Stack
- [ ] Deploy Prometheus with persistent storage
- [ ] Configure ServiceMonitors and PodMonitors
- [ ] Build Grafana dashboards from scratch
- [ ] Implement alerting rules and routing
- [ ] Deploy Loki for centralized logging
- [ ] Set up distributed tracing with Jaeger
- [ ] Implement SLOs and error budgets

### Week 16-18: Security & RBAC
- [ ] Design RBAC strategy for multi-team clusters
- [ ] Implement Pod Security Standards
- [ ] Configure OPA Gatekeeper policies
- [ ] Set up audit logging
- [ ] Implement secrets encryption at rest
- [ ] Configure network policies for zero-trust
- [ ] Implement workload identity

### Week 19-20: Scaling & Performance
- [ ] Configure HPA with custom metrics
- [ ] Implement VPA for right-sizing
- [ ] Set up Cluster Autoscaler
- [ ] Optimize resource requests/limits
- [ ] Implement Pod Disruption Budgets
- [ ] Configure priority and preemption
- [ ] Performance test and benchmark

## Validation Criteria

Before moving to Phase 4, you should be able to:

1. **Build** a complete observability stack from scratch
2. **Design** RBAC policies for complex organizational structures
3. **Implement** security policies that pass compliance audits
4. **Optimize** cluster performance and cost efficiency
5. **Complete** the phase project with full alerting pipeline

## Time Investment

- **Study Time**: ~4-5 hours/day
- **Hands-On Practice**: ~3 hours/day
- **Total**: ~45-50 hours/week

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Validation Criteria
- Time Investment
- 15: Observability Stack
- 18: Security & RBAC

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
