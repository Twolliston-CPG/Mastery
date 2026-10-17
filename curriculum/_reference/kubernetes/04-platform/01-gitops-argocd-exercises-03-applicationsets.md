# Exercise 3: ApplicationSets

## Objective

Use ApplicationSets to dynamically generate ArgoCD Applications based on templates and generators, enabling scalable multi-environment and multi-cluster deployments.

## Prerequisites

- ArgoCD installed with ApplicationSet controller
- Multiple namespaces or clusters for testing
- Git repository with manifests

## Concepts

**ApplicationSet generators**

An ApplicationSet is a template plus a generator: the generator produces a set of
parameter maps, and one Application is rendered per map.

| Generator | Produces one Application per… | Reach for it when |
|---|---|---|
| **List** | Entry in a hard-coded list | You have 2–3 fixed environments and want the list reviewable in the diff |
| **Cluster** | Cluster registered in Argo CD | Fleet-wide add-ons (metrics-server, CNI policy, log shipper) |
| **Git** | Directory or file matched in a repo | The repo layout *is* the inventory — new directory, new app |
| **Matrix** | Cartesian product of two generators | Every app × every cluster |
| **Merge** | Combined result, with later generators overriding earlier keys | A matrix that needs per-cluster exceptions |

`Matrix` is the one that surprises people: two generators of 5 and 4 elements
produce 20 Applications, and a typo in the template breaks all 20 at once. Run it
with `--dry-run` through `argocd appset generate` before committing.

## Tasks

### Task 1: List Generator - Multi-Environment

```yaml
# applicationset-list.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: api-environments
  namespace: argocd
spec:
  generators:
  - list:
      elements:
      - env: development
        namespace: development
        revision: develop
        replicas: "1"
      - env: staging
        namespace: staging
        revision: release
        replicas: "2"
      - env: production
        namespace: production
        revision: main
        replicas: "3"

  template:
    metadata:
      name: 'api-{{env}}'
      namespace: argocd
      labels:
        app: api
        environment: '{{env}}'
    spec:
      project: default

      source:
        repoURL: https://github.com/myorg/k8s-manifests.git
        targetRevision: '{{revision}}'
        path: 'overlays/{{env}}/api'
        kustomize:
          replicas:
          - name: api
            count: '{{replicas}}'

      destination:
        server: https://kubernetes.default.svc
        namespace: '{{namespace}}'

      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
        - CreateNamespace=true
```

### Task 2: Cluster Generator - Multi-Cluster

```yaml
# First, label your clusters in ArgoCD
# argocd cluster set production-us-west --label env=production --label region=us-west
# argocd cluster set production-eu-west --label env=production --label region=eu-west

---
# applicationset-clusters.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: global-monitoring
  namespace: argocd
spec:
  generators:
  - clusters:
      selector:
        matchLabels:
          env: production

  template:
    metadata:
      name: 'monitoring-{{name}}'
    spec:
      project: infrastructure

      source:
        repoURL: https://prometheus-community.github.io/helm-charts
        chart: kube-prometheus-stack
        targetRevision: 51.2.0
        helm:
          releaseName: monitoring
          values: |
            prometheus:
              prometheusSpec:
                externalLabels:
                  cluster: {{name}}
                  region: {{metadata.labels.region}}

      destination:
        server: '{{server}}'
        namespace: monitoring

      syncPolicy:
        automated:
          selfHeal: true
        syncOptions:
        - CreateNamespace=true
```

### Task 3: Git Directory Generator - Dynamic App Discovery

```yaml
# applicationset-git-directories.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: microservices
  namespace: argocd
spec:
  generators:
  - git:
      repoURL: https://github.com/myorg/k8s-manifests.git
      revision: main
      directories:
      # Include all services
      - path: 'services/*'
      # Exclude specific directories
      - path: 'services/deprecated-*'
        exclude: true

  template:
    metadata:
      name: '{{path.basename}}'
      labels:
        app.kubernetes.io/name: '{{path.basename}}'
    spec:
      project: default

      source:
        repoURL: https://github.com/myorg/k8s-manifests.git
        targetRevision: main
        path: '{{path}}'

      destination:
        server: https://kubernetes.default.svc
        namespace: production

      syncPolicy:
        automated:
          prune: true
          selfHeal: true
```

### Task 4: Git Files Generator - Config-Driven

```yaml
# config/apps/api.yaml in git repo
# cluster: production-us
# app: api
# team: platform
# replicas: 3

# config/apps/web.yaml in git repo
# cluster: production-us
# app: web
# team: frontend
# replicas: 2

---
# applicationset-git-files.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: config-driven-apps
  namespace: argocd
spec:
  generators:
  - git:
      repoURL: https://github.com/myorg/k8s-manifests.git
      revision: main
      files:
      - path: 'config/apps/*.yaml'

  template:
    metadata:
      name: '{{app}}-{{cluster}}'
      labels:
        team: '{{team}}'
    spec:
      project: default

      source:
        repoURL: https://github.com/myorg/k8s-manifests.git
        targetRevision: main
        path: 'overlays/{{cluster}}/{{app}}'
        kustomize:
          replicas:
          - name: '{{app}}'
            count: '{{replicas}}'

      destination:
        server: https://kubernetes.default.svc
        namespace: '{{app}}'

      syncPolicy:
        automated:
          prune: true
          selfHeal: true
```

### Task 5: Matrix Generator - Environments x Services

```yaml
# applicationset-matrix.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: all-apps-all-envs
  namespace: argocd
spec:
  generators:
  - matrix:
      generators:
      # First generator: environments
      - list:
          elements:
          - env: staging
            cluster: in-cluster
            revision: develop
          - env: production
            cluster: production-cluster
            revision: main

      # Second generator: services (from git)
      - git:
          repoURL: https://github.com/myorg/k8s-manifests.git
          revision: '{{revision}}'
          directories:
          - path: 'services/*'

  template:
    metadata:
      name: '{{path.basename}}-{{env}}'
      labels:
        app: '{{path.basename}}'
        environment: '{{env}}'
    spec:
      project: '{{env}}'

      source:
        repoURL: https://github.com/myorg/k8s-manifests.git
        targetRevision: '{{revision}}'
        path: 'overlays/{{env}}/{{path.basename}}'

      destination:
        server: '{{cluster}}'
        namespace: '{{env}}'

      syncPolicy:
        automated:
          prune: true
          selfHeal: true
```

### Task 6: Merge Generator - Override Defaults

```yaml
# applicationset-merge.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: apps-with-overrides
  namespace: argocd
spec:
  generators:
  - merge:
      mergeKeys:
      - app
      generators:
      # Base configuration (defaults)
      - list:
          elements:
          - app: api
            replicas: "2"
            memory: "256Mi"
            cpu: "100m"
          - app: web
            replicas: "2"
            memory: "128Mi"
            cpu: "50m"
          - app: worker
            replicas: "1"
            memory: "512Mi"
            cpu: "200m"

      # Override for production (merged by 'app' key)
      - list:
          elements:
          - app: api
            replicas: "5"
            memory: "1Gi"
            cpu: "500m"
          - app: web
            replicas: "3"
            memory: "512Mi"

  template:
    metadata:
      name: '{{app}}-production'
    spec:
      project: production

      source:
        repoURL: https://github.com/myorg/k8s-manifests.git
        targetRevision: main
        path: 'base/{{app}}'
        kustomize:
          replicas:
          - name: '{{app}}'
            count: '{{replicas}}'
          patches:
          - patch: |
              - op: replace
                path: /spec/template/spec/containers/0/resources/requests/memory
                value: {{memory}}
              - op: replace
                path: /spec/template/spec/containers/0/resources/requests/cpu
                value: {{cpu}}
            target:
              kind: Deployment

      destination:
        server: https://kubernetes.default.svc
        namespace: production
```

### Task 7: Progressive Sync with ApplicationSet

```yaml
# applicationset-progressive.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: progressive-rollout
  namespace: argocd
spec:
  generators:
  - list:
      elements:
      - env: canary
        weight: "10"
      - env: production-us-west
        weight: "30"
      - env: production-us-east
        weight: "30"
      - env: production-eu
        weight: "30"

  # Progressive sync strategy
  strategy:
    type: RollingSync
    rollingSync:
      steps:
      - matchExpressions:
        - key: env
          operator: In
          values:
          - canary
      - matchExpressions:
        - key: env
          operator: In
          values:
          - production-us-west
          - production-us-east
        maxUpdate: 1  # Update one at a time
      - matchExpressions:
        - key: env
          operator: In
          values:
          - production-eu

  template:
    metadata:
      name: 'api-{{env}}'
      labels:
        env: '{{env}}'
    spec:
      project: production
      source:
        repoURL: https://github.com/myorg/k8s-manifests.git
        targetRevision: main
        path: 'overlays/{{env}}/api'
      destination:
        server: https://kubernetes.default.svc
        namespace: '{{env}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
```

## Validation

```bash
# Apply ApplicationSet
kubectl apply -f applicationset-list.yaml

# Watch applications being created
watch kubectl get applications -n argocd

# Check ApplicationSet status
kubectl get applicationsets -n argocd
kubectl describe applicationset api-environments -n argocd

# Verify generated applications
argocd app list | grep api-

# Test adding new environment (add to list generator)
# Applications will be auto-created
```

## Success Criteria

- [ ] List generator creates apps for each environment
- [ ] Cluster generator deploys to all matching clusters
- [ ] Git generator discovers new services automatically
- [ ] Matrix generator creates cross-product of apps
- [ ] Merge generator applies overrides correctly
- [ ] Progressive sync respects rollout order

## Best Practices

1. **Use goTemplate** - Enable `goTemplate: true` for advanced templating
2. **Validate templates** - Test template rendering before applying
3. **Use sync waves** - Combine with sync waves for dependencies
4. **Label clusters** - Use labels for cluster selection
5. **Progressive rollout** - Use rolling sync for production safety

## Cleanup

```bash
# Delete ApplicationSet (will delete all generated apps)
kubectl delete applicationset api-environments -n argocd

# Delete without cascading
kubectl delete applicationset api-environments -n argocd \
  --cascade=orphan
```

## Next Exercise

Continue to [Exercise 4: Multi-Cluster Deployments](01-gitops-argocd-exercises-04-multi-cluster.md) for cross-cluster GitOps.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- List Generator - Multi-Environment
- Cluster Generator - Multi-Cluster
- Git Directory Generator - Dynamic App Discovery
- Git Files Generator - Config-Driven

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
