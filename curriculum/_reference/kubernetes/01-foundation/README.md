# Phase 1: Foundation (Weeks 1-6)

Build a rock-solid foundation in containers and Kubernetes architecture before moving to operations.

## Learning Objectives

By the end of this phase, you will:
- [ ] Build production-ready container images
- [ ] Understand Kubernetes architecture at the component level
- [ ] Deploy and manage core workload types
- [ ] Complete a full microservices deployment

## Prerequisites

- Basic Linux command line proficiency
- Understanding of networking fundamentals (TCP/IP, DNS, HTTP)
- A working local development environment

## Content Structure

| Week | Topic | Content | Exercises |
|------|-------|---------|-----------|
| 1-2 | Container Fundamentals | [01-container-fundamentals](01-container-fundamentals-README.md) | 5 exercises |
| 3-4 | Kubernetes Architecture | [02-kubernetes-architecture](02-kubernetes-architecture-README.md) | 6 exercises |
| 5-6 | Core Workloads | [03-core-workloads](03-core-workloads-README.md) | 8 exercises |

## Phase Project

**[Microservices E-Commerce Application](project-microservices-app-README.md)**

Deploy a complete e-commerce platform with:
- Frontend (React/Vue)
- API Gateway
- Product Service
- Order Service
- User Service
- PostgreSQL (StatefulSet)
- Redis Cache (StatefulSet)
- RabbitMQ (Message Queue)
- Background Workers

## Progress Checklist

### Week 1-2: Container Fundamentals
- [ ] Understand container runtime architecture
- [ ] Build multi-stage Docker images
- [ ] Implement image security best practices
- [ ] Scan images for vulnerabilities
- [ ] Push images to a container registry

### Week 3-4: Kubernetes Architecture
- [ ] Explain the role of each control plane component
- [ ] Describe node component responsibilities
- [ ] Complete Kubernetes The Hard Way (or kubeadm setup)
- [ ] Navigate the Kubernetes API with kubectl
- [ ] Understand declarative vs imperative management

### Week 5-6: Core Workloads
- [ ] Deploy Pods with proper configurations
- [ ] Manage Deployments with rolling updates
- [ ] Configure StatefulSets for databases
- [ ] Use DaemonSets for cluster-wide services
- [ ] Schedule Jobs and CronJobs
- [ ] Manage configuration with ConfigMaps and Secrets

## Validation Criteria

Before moving to Phase 2, you should be able to:

1. **Build** a production-ready container image from scratch
2. **Explain** the request flow from kubectl to a running Pod
3. **Deploy** any workload type without referencing documentation
4. **Troubleshoot** common Pod startup failures
5. **Complete** the phase project with all components running

## Time Investment

- **Study Time**: ~3-4 hours/day
- **Hands-On Practice**: ~2 hours/day
- **Total**: ~35-40 hours/week

## Quick Navigation

```bash
# Start here
cd 01-container-fundamentals && cat README.md

# Then
cd ../02-kubernetes-architecture && cat README.md

# Finally
cd ../03-core-workloads && cat README.md

# Complete the project
cd ../project-microservices-app && cat README.md
```

## Resources

### Official Documentation
- [Docker Documentation](https://docs.docker.com/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Kubernetes API Reference](https://kubernetes.io/docs/reference/kubernetes-api/)

### Recommended Reading
- "Kubernetes Up & Running" - Chapters 1-7
- "Docker Deep Dive" - Nigel Poulton

### Video Resources
- [Kubernetes The Hard Way - Walkthrough](https://www.youtube.com/results?search_query=kubernetes+the+hard+way)
- [CNCF YouTube Channel](https://www.youtube.com/c/cloudnativefdn)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Validation Criteria
- Time Investment
- Quick Navigation
- 2: Container Fundamentals

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
