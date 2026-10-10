# Argo CD Mastery Roadmap

**From Beginner to Elite GitOps Engineer**

This roadmap takes you from zero to production-ready Argo CD expertise through structured phases, hands-on labs, and real-world scenarios.

---

# Phase 0: Prerequisites

**Goal:** Ensure you have the foundation needed to succeed.

## Required Knowledge

Before starting, you should be comfortable with:

### Kubernetes Fundamentals
- [ ] Pods, Deployments, Services, ConfigMaps, Secrets
- [ ] Namespaces and resource organization
- [ ] RBAC basics (Roles, RoleBindings, ClusterRoles)
- [ ] Custom Resource Definitions (CRDs)
- [ ] kubectl proficiency

### Git Fundamentals
- [ ] Branching, merging, pull requests
- [ ] Repository structure best practices
- [ ] Working with remotes

### YAML
- [ ] Comfortable reading/writing Kubernetes manifests
- [ ] Understanding of anchors and references

## Required Tools

Install these before proceeding:

```bash
# Kubernetes CLI
brew install kubectl

# Local Kubernetes cluster (choose one)
brew install kind        # Recommended - lightweight
brew install minikube    # Alternative

# Argo CD CLI
brew install argocd

# Helm (for later phases)
brew install helm

# Git
brew install git
```

## Environment Setup

### Lab 0.1: Create Your Lab Cluster

```bash
# Create a kind cluster with a custom name
cat <<EOF | kind create cluster --name argocd-lab --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30080
    hostPort: 30080
    protocol: TCP
  - containerPort: 30443
    hostPort: 30443
    protocol: TCP
EOF

# Verify cluster is running
kubectl cluster-info --context kind-argocd-lab
kubectl get nodes
```

**Acceptance Criteria:**
- [ ] `kubectl get nodes` shows a Ready node
- [ ] You can create and delete a test namespace

### Lab 0.2: Create Your GitOps Repository

1. Create a new repository on GitHub/GitLab named `argocd-learning`
2. Clone it locally:

```bash
git clone https://github.com/YOUR_USERNAME/argocd-learning.git
cd argocd-learning

# Create initial structure
mkdir -p apps/{base,overlays/{dev,staging,prod}}
mkdir -p clusters/{dev,staging,prod}
mkdir -p applicationsets
mkdir -p projects

# Create a README
echo "# Argo CD Learning Repository" > README.md
git add .
git commit -m "Initial repository structure"
git push origin main
```

**Acceptance Criteria:**
- [ ] Repository is accessible via HTTPS
- [ ] Directory structure is in place

---

# Phase 1: Foundation & Architecture

**Goal:** Understand what Argo CD is, why it exists, and how it works.

## Concepts

### What is GitOps?

GitOps is a set of practices where:

1. **Declarative** - The entire system is described declaratively
2. **Versioned** - The canonical desired state is stored in Git
3. **Automated** - Approved changes are automatically applied
4. **Auditable** - Git provides complete audit trail

**Why GitOps matters:**
- Single source of truth for infrastructure
- Reproducible deployments
- Easy rollbacks via git revert
- Collaboration through pull requests
- Security through Git access controls

### Why Argo CD?

Argo CD is a declarative, GitOps continuous delivery tool for Kubernetes that:

- Continuously monitors running applications
- Compares live state against desired state in Git
- Visualizes differences and provides sync capabilities
- Supports multiple config management tools (Helm, Kustomize, etc.)

**Comparison with alternatives:**

| Feature | Argo CD | Flux | Jenkins |
|---------|---------|------|---------|
| GitOps Native | Yes | Yes | No (CI/CD) |
| UI | Rich Web UI | Limited | Plugin-based |
| Multi-cluster | Native | Native | Manual |
| RBAC | Built-in | Kubernetes | Plugin |
| Drift Detection | Real-time | Polling | None |

### Architecture Deep Dive

Argo CD consists of three core components:

<!-- figure: generated from the Mermaid below by _shared/diagrams/embed-figures.py — do not edit the image -->
![Architecture Deep Dive — diagram](../../../../_figures/curriculum-_reference-cicd-gitops-argocd-ARGOCD_MASTERY_ROADMAP-0-dea32e8b.png)

<details>
<summary>Diagram source (Mermaid)</summary>

```mermaid
%%{init: {'theme':'base','themeVariables':{'fontFamily':'Helvetica, Arial, sans-serif','fontSize':'13px','primaryColor':'#ffffff','primaryTextColor':'#2d3436','primaryBorderColor':'#9aa3ab','lineColor':'#9aa3ab','textColor':'#2d3436','clusterBkg':'#fbfcfd','clusterBorder':'#d4dae0','edgeLabelBackground':'#ffffff','tertiaryColor':'#eef4fb'},'flowchart':{'curve':'basis','padding':14,'nodeSpacing':42,'rankSpacing':58}}}%%
flowchart TB
  classDef default fill:#ffffff,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef n    fill:#ffffff,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef crit fill:#eef4fb,stroke:#2f6fb8,stroke-width:1.8px,color:#1b3a5c
  classDef data fill:#f4f7fa,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef mut  fill:#ffffff,stroke:#cfd6dc,stroke-width:1.1px,color:#7a8288
  classDef warn fill:#fdf0ec,stroke:#c0522d,stroke-width:1.6px,color:#8a3a1e
  subgraph ARGO["Argo CD"]
    direction LR
    API["API server<br/><small>web UI · gRPC/REST · auth and RBAC · webhooks</small>"]:::n
    REPO["Repo server<br/><small>git clone · manifest generation · caching</small>"]:::n
    CTRL["Application controller<br/><small>reconciliation · sync · health checks</small>"]:::crit
  end
  REDIS[("Redis<br/><small>cache</small>")]:::data
  GIT[("Git repository<br/><small>the source of truth</small>")]:::data
  K8S["Target cluster"]:::n

  GIT --> REPO
  REPO --> CTRL
  API --> CTRL
  API -.-> REDIS
  REPO -.-> REDIS
  CTRL -->|"apply"| K8S

  linkStyle 0,1,5 stroke:#2f6fb8,stroke-width:2px
```

</details>

**API Server:**
- Exposes gRPC/REST API for UI, CLI, and CI/CD integrations
- Handles authentication and RBAC enforcement
- Manages repository and cluster credentials
- Processes Git webhook events

**Repository Server:**
- Clones Git repositories containing manifests
- Generates Kubernetes manifests using appropriate tools
- Caches repository data and generated manifests
- Stateless - can be scaled horizontally

**Application Controller:**
- Kubernetes controller watching Application CRDs
- Continuously compares desired state (Git) vs live state (cluster)
- Identifies out-of-sync applications
- Executes sync operations and lifecycle hooks

**Redis:**
- Caches data between components
- Stores generated manifests
- "Throw-away" cache - rebuilds without data loss

### The Reconciliation Loop

<!-- figure: generated from the Mermaid below by _shared/diagrams/embed-figures.py — do not edit the image -->
![The Reconciliation Loop — diagram](../../../../_figures/curriculum-_reference-cicd-gitops-argocd-ARGOCD_MASTERY_ROADMAP-1-23e6ad3b.png)

<details>
<summary>Diagram source (Mermaid)</summary>

```mermaid
%%{init: {'theme':'base','themeVariables':{'fontFamily':'Helvetica, Arial, sans-serif','fontSize':'13px','primaryColor':'#ffffff','primaryTextColor':'#2d3436','primaryBorderColor':'#9aa3ab','lineColor':'#9aa3ab','textColor':'#2d3436','clusterBkg':'#fbfcfd','clusterBorder':'#d4dae0','edgeLabelBackground':'#ffffff','tertiaryColor':'#eef4fb'},'flowchart':{'curve':'basis','padding':14,'nodeSpacing':42,'rankSpacing':58}}}%%
flowchart LR
  classDef default fill:#ffffff,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef n    fill:#ffffff,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef crit fill:#eef4fb,stroke:#2f6fb8,stroke-width:1.8px,color:#1b3a5c
  classDef data fill:#f4f7fa,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef mut  fill:#ffffff,stroke:#cfd6dc,stroke-width:1.1px,color:#7a8288
  classDef warn fill:#fdf0ec,stroke:#c0522d,stroke-width:1.6px,color:#8a3a1e
  GIT[("Git repository")]:::data
  REPO["Repo server<br/><small>generate manifests</small>"]:::n
  CTRL["Controller<br/><small>compare desired vs live</small>"]:::crit
  Q{"out of sync?"}:::n
  SYNC["Sync operation"]:::crit
  CL["Cluster"]:::n

  GIT --> REPO --> CTRL --> Q
  Q -->|"yes"| SYNC --> CL
  Q -->|"no"| CTRL
  CL -.->|"observed state"| CTRL

  linkStyle 0,1,2,3,4 stroke:#2f6fb8,stroke-width:2px
```

</details>

Default intervals:
- **Reconciliation:** Every 3 minutes (configurable)
- **Hard refresh:** Every 24 hours
- **Webhook-triggered:** Immediate

## Installation Options

### Non-HA (Development/Testing)

```yaml
# Standard install with cluster-admin access
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Namespace-scoped (limited permissions)
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/namespace-install.yaml
```

### HA (Production)

```yaml
# HA with cluster-admin access
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/ha/install.yaml

# HA namespace-scoped
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/ha/namespace-install.yaml
```

### Core (Headless)

```yaml
# Lightweight - no UI or API server
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/core-install.yaml
```

## Labs

### Lab 1.1: Install Argo CD

```bash
# Create namespace
kubectl create namespace argocd

# Install Argo CD (non-HA for learning)
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for pods to be ready
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s

# Verify installation
kubectl get pods -n argocd
kubectl get svc -n argocd
```

**Expected output:**
```
NAME                                  READY   STATUS    RESTARTS   AGE
argocd-application-controller-0       1/1     Running   0          2m
argocd-dex-server-xxx                 1/1     Running   0          2m
argocd-redis-xxx                      1/1     Running   0          2m
argocd-repo-server-xxx                1/1     Running   0          2m
argocd-server-xxx                     1/1     Running   0          2m
```

### Lab 1.2: Access the UI

```bash
# Get the initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo  # Add newline

# Port-forward to access UI (keep this terminal open)
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Open https://localhost:8080 in your browser (accept the self-signed certificate).
- Username: `admin`
- Password: (from command above)

### Lab 1.3: Configure the CLI

```bash
# Login to Argo CD
argocd login localhost:8080 --insecure

# Update your password
argocd account update-password

# Verify connection
argocd cluster list
argocd app list
```

### Lab 1.4: Explore the Architecture

```bash
# Examine each component
kubectl get deploy,statefulset -n argocd

# Check the CRDs Argo CD installs
kubectl get crd | grep argo

# Inspect an Application CRD
kubectl explain application.spec

# View Argo CD's own configuration
kubectl get configmap argocd-cm -n argocd -o yaml
kubectl get secret argocd-secret -n argocd -o yaml
```

**Knowledge Check Questions:**
1. Which component is responsible for generating manifests?
2. What happens if Redis loses all data?
3. How does Argo CD detect changes in Git?

## Common Mistakes

1. **Not waiting for pods** - Trying to access UI before pods are ready
2. **Forgetting the password** - The initial secret is deleted after first login
3. **Firewall issues** - Port-forward requires local network access

## Troubleshooting

```bash
# Check pod logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server

# Check events
kubectl get events -n argocd --sort-by='.lastTimestamp'
```

---

# Phase 2: Core Concepts & Mental Models

**Goal:** Master the fundamental building blocks and vocabulary.

## Concepts

### The Application CRD

The `Application` is Argo CD's core custom resource. It defines:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd           # Applications live in argocd namespace
spec:
  project: default            # AppProject for access control

  source:                     # WHERE to get manifests
    repoURL: https://github.com/org/repo.git
    targetRevision: HEAD      # Branch, tag, or commit
    path: kubernetes/         # Path within repo

  destination:                # WHERE to deploy
    server: https://kubernetes.default.svc
    namespace: my-namespace

  syncPolicy:                 # HOW to sync
    automated:
      prune: true
      selfHeal: true
```

### Key Terminology

| Term | Definition |
|------|------------|
| **Target State** | Desired state as defined in Git |
| **Live State** | Actual state running in the cluster |
| **Sync Status** | Whether live state matches target state |
| **Health Status** | Whether resources are functioning correctly |
| **Refresh** | Compare Git with live state to detect drift |
| **Sync** | Apply changes to make live state match target state |

### Sync Status vs Health Status

These are **independent** concepts:

**An Application has two independent statuses — conflating them is a common mistake**

| Sync status | Meaning |
|---|---|
| `Synced` | live state matches Git |
| `OutOfSync` | live state differs from Git |
| `Unknown` | Argo CD cannot determine it |

| Health status | Meaning |
|---|---|
| `Healthy` | the resources report themselves healthy |
| `Progressing` | a rollout is in flight |
| `Degraded` | the resources report a failure |
| `Suspended` | paused, e.g. a suspended CronJob |
| `Missing` | in Git, not in the cluster |
| `Unknown` | cannot be determined |

**`Synced` does not mean working.** A Deployment whose pods are all CrashLooping is `Synced` and
`Degraded` — Git got applied exactly as written, and the application is down.

**Example scenarios:**

| Scenario | Sync Status | Health Status |
|----------|-------------|---------------|
| Deployment matches Git, pods running | Synced | Healthy |
| New commit in Git, not yet applied | OutOfSync | Healthy |
| Deployment matches Git, pods crashing | Synced | Degraded |
| Manual kubectl edit, pods running | OutOfSync | Healthy |

### Refresh vs Sync

**Refresh** (read-only):
- Fetches latest Git state
- Compares with live cluster state
- Updates sync status
- Does NOT modify the cluster

**Sync** (mutating):
- Applies manifests to cluster
- Creates/updates/deletes resources
- Executes hooks if defined

```bash
# Refresh only (safe, read-only)
argocd app get my-app --refresh

# Hard refresh (clear cache, re-clone repo)
argocd app get my-app --hard-refresh

# Sync (applies changes)
argocd app sync my-app
```

### Application Source Types

Argo CD supports multiple tools for generating manifests:

| Type | Detection | Use Case |
|------|-----------|----------|
| **Directory** | Plain YAML/JSON files | Simple deployments |
| **Kustomize** | `kustomization.yaml` present | Overlays, patching |
| **Helm** | `Chart.yaml` present | Templated charts |
| **Jsonnet** | `.jsonnet` files | Programmatic configs |
| **Plugin** | Configured in argocd-cm | Custom tooling |

### Projects (Preview)

Projects (`AppProject`) provide:
- Source repository restrictions
- Destination cluster/namespace restrictions
- Resource whitelisting/blacklisting
- RBAC for teams

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: team-alpha
  namespace: argocd
spec:
  description: "Team Alpha's project"
  sourceRepos:
    - 'https://github.com/org/team-alpha-*'
  destinations:
    - namespace: 'alpha-*'
      server: https://kubernetes.default.svc
```

## Labs

### Lab 2.1: Create Your First Application (CLI)

```bash
# Create a simple app from a public repo
argocd app create guestbook \
  --repo https://github.com/argoproj/argocd-example-apps.git \
  --path guestbook \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default

# Check status
argocd app get guestbook

# Notice it's OutOfSync - we haven't synced yet
```

### Lab 2.2: Understand Application States

```bash
# View detailed status
argocd app get guestbook

# See the diff (what would change)
argocd app diff guestbook

# Sync the application
argocd app sync guestbook

# Check status again - should be Synced and Healthy
argocd app get guestbook

# View in the UI - explore the resource tree
```

### Lab 2.3: Create Application Declaratively

Create a file in your learning repo:

```yaml
# apps/base/guestbook-declarative.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: guestbook-declarative
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/argoproj/argocd-example-apps.git
    targetRevision: HEAD
    path: guestbook
  destination:
    server: https://kubernetes.default.svc
    namespace: guestbook
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
```

```bash
# Apply it
kubectl apply -f apps/base/guestbook-declarative.yaml

# Check it appears
argocd app list
```

### Lab 2.4: Observe Sync vs Health

```bash
# Create a deployment that will be unhealthy
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: broken-app
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: broken
  template:
    metadata:
      labels:
        app: broken
    spec:
      containers:
      - name: broken
        image: nginx:nonexistent-tag
EOF

# Create an Argo CD app pointing to this
# (In real world, this would be in Git)
# The app will be Synced but Degraded
```

### Lab 2.5: Trigger Drift Detection

```bash
# Manually modify a resource managed by Argo CD
kubectl scale deployment guestbook-ui --replicas=5 -n default

# Refresh and observe
argocd app get guestbook --refresh

# Status is now OutOfSync
# View the diff
argocd app diff guestbook
```

**Knowledge Check Questions:**
1. An app shows Synced but Degraded - what does this mean?
2. What's the difference between `--refresh` and `--hard-refresh`?
3. How does Argo CD detect that you need a Helm chart vs Kustomize?

## Common Mistakes

1. **Creating Applications in wrong namespace** - Applications must be in `argocd` namespace (by default)
2. **Confusing Sync and Health** - Synced doesn't mean working
3. **Editing resources directly** - Use Git, not kubectl edit

---

# Phase 3: Application Sources & Tools

**Goal:** Deploy using different manifest generation tools.

## Concepts

### Plain Manifests (Directory)

The simplest approach - raw YAML files:

**`my-app/`**

- `deployment.yaml`
- `service.yaml`
- `configmap.yaml`


```yaml
source:
  repoURL: https://github.com/org/repo.git
  path: my-app
  targetRevision: main
  directory:
    recurse: true          # Include subdirectories
    exclude: '{*.md,test/*}'  # Glob patterns to exclude
```

### Kustomize

Overlay-based customization:

**`my-app/`**

- `base/`
  - `kustomization.yaml`
  - `deployment.yaml`
  - `service.yaml`
- `overlays/`
  - `dev/`
    - `kustomization.yaml`
  - `prod/`
    - `kustomization.yaml`


```yaml
source:
  repoURL: https://github.com/org/repo.git
  path: my-app/overlays/prod
  targetRevision: main
  kustomize:
    namePrefix: prod-
    nameSuffix: -v1
    images:
      - name: my-image
        newTag: v1.2.3
    commonLabels:
      env: production
```

**Available Kustomize options:**

| Field | Purpose |
|-------|---------|
| `namePrefix` | Add prefix to all resource names |
| `nameSuffix` | Add suffix to all resource names |
| `images` | Override image names/tags |
| `commonLabels` | Add labels to all resources |
| `commonAnnotations` | Add annotations to all resources |
| `namespace` | Set namespace for all resources |
| `patches` | Inline JSON patches |
| `components` | Reference Kustomize components |

### Helm

Template-based charts:

```yaml
source:
  repoURL: https://charts.bitnami.com/bitnami
  chart: nginx
  targetRevision: 15.0.0
  helm:
    releaseName: my-nginx
    valueFiles:
      - values-prod.yaml
    values: |
      replicaCount: 3
      service:
        type: LoadBalancer
    parameters:
      - name: image.tag
        value: "1.25.0"
```

**Values precedence (lowest to highest):**
1. Chart's default values.yaml
2. `valueFiles` (in order listed)
3. `values` (inline string)
4. `valuesObject` (inline object)
5. `parameters` (highest priority)

**Helm-specific options:**

| Field | Purpose |
|-------|---------|
| `releaseName` | Override Helm release name |
| `valueFiles` | List of values files from repo |
| `values` | Inline values as YAML string |
| `valuesObject` | Inline values as YAML object |
| `parameters` | Individual value overrides |
| `skipCrds` | Don't install CRDs |
| `passCredentials` | Pass credentials to chart dependencies |

### Multiple Sources

Combine sources for complex deployments:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: multi-source-app
spec:
  sources:
    # Helm chart from registry
    - repoURL: https://charts.bitnami.com/bitnami
      chart: nginx
      targetRevision: 15.0.0
      helm:
        valueFiles:
          - $values/nginx/values-prod.yaml

    # Values from Git repo
    - repoURL: https://github.com/org/config.git
      targetRevision: main
      ref: values  # Reference name for $values
```

**Key rules:**
- Use `sources` (plural) instead of `source`
- Last source producing a resource wins
- Don't abuse - max 2-3 sources recommended

### OCI Helm Charts

```yaml
source:
  repoURL: registry-1.docker.io/bitnamicharts  # No oci:// prefix
  chart: nginx
  targetRevision: 15.0.0
```

## Labs

### Lab 3.1: Deploy Plain Manifests

Create in your learning repo:

```bash
mkdir -p apps/plain-manifests
```

```yaml
# apps/plain-manifests/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: plain-demo
---
# apps/plain-manifests/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  namespace: plain-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
---
# apps/plain-manifests/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx
  namespace: plain-demo
spec:
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
```

```yaml
# apps/plain-manifests-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: plain-manifests-demo
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/YOUR_USERNAME/argocd-learning.git
    targetRevision: HEAD
    path: apps/plain-manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: plain-demo
```

```bash
git add .
git commit -m "Add plain manifests demo"
git push

kubectl apply -f apps/plain-manifests-app.yaml
argocd app sync plain-manifests-demo
```

### Lab 3.2: Deploy with Kustomize

```bash
mkdir -p apps/kustomize-demo/{base,overlays/{dev,prod}}
```

```yaml
# apps/kustomize-demo/base/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: web
        image: nginx:1.25
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
```

```yaml
# apps/kustomize-demo/base/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: web
spec:
  selector:
    app: web
  ports:
  - port: 80
```

```yaml
# apps/kustomize-demo/base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
  - service.yaml
```

```yaml
# apps/kustomize-demo/overlays/dev/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: kustomize-dev
resources:
  - ../../base
namePrefix: dev-
commonLabels:
  env: dev
patches:
  - patch: |-
      - op: replace
        path: /spec/replicas
        value: 1
    target:
      kind: Deployment
      name: web
```

```yaml
# apps/kustomize-demo/overlays/prod/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: kustomize-prod
resources:
  - ../../base
namePrefix: prod-
commonLabels:
  env: prod
patches:
  - patch: |-
      - op: replace
        path: /spec/replicas
        value: 3
    target:
      kind: Deployment
      name: web
```

```yaml
# apps/kustomize-dev-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kustomize-dev
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/YOUR_USERNAME/argocd-learning.git
    targetRevision: HEAD
    path: apps/kustomize-demo/overlays/dev
  destination:
    server: https://kubernetes.default.svc
    namespace: kustomize-dev
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
```

```bash
git add .
git commit -m "Add Kustomize demo"
git push

kubectl apply -f apps/kustomize-dev-app.yaml
argocd app sync kustomize-dev
```

### Lab 3.3: Deploy Helm Chart

```yaml
# apps/helm-nginx-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: helm-nginx
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://charts.bitnami.com/bitnami
    chart: nginx
    targetRevision: 15.0.0
    helm:
      releaseName: my-nginx
      values: |
        replicaCount: 2
        service:
          type: ClusterIP
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
  destination:
    server: https://kubernetes.default.svc
    namespace: helm-demo
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
```

```bash
kubectl apply -f apps/helm-nginx-app.yaml
argocd app sync helm-nginx
```

### Lab 3.4: Helm with External Values

```bash
mkdir -p apps/helm-values
```

```yaml
# apps/helm-values/values-common.yaml
replicaCount: 2
resources:
  requests:
    memory: "64Mi"
    cpu: "100m"
```

```yaml
# apps/helm-values/values-prod.yaml
replicaCount: 5
service:
  type: LoadBalancer
```

```yaml
# apps/helm-external-values-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: helm-external-values
  namespace: argocd
spec:
  project: default
  sources:
    - repoURL: https://charts.bitnami.com/bitnami
      chart: nginx
      targetRevision: 15.0.0
      helm:
        valueFiles:
          - $values/apps/helm-values/values-common.yaml
          - $values/apps/helm-values/values-prod.yaml
    - repoURL: https://github.com/YOUR_USERNAME/argocd-learning.git
      targetRevision: HEAD
      ref: values
  destination:
    server: https://kubernetes.default.svc
    namespace: helm-external
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
```

**Knowledge Check Questions:**
1. How do you override a single Helm value without a values file?
2. What happens when two sources produce the same resource?
3. How does Argo CD detect a Kustomize application?

## Common Mistakes

1. **Helm random functions** - Using `randAlphaNum` causes perpetual OutOfSync
2. **Missing kustomization.yaml** - Kustomize won't work without it
3. **Wrong targetRevision** - Using branch names for Helm charts (use version)
4. **OCI prefix** - Don't include `oci://` in repoURL

---

# Phase 4: Sync Lifecycle

**Goal:** Master sync policies, waves, hooks, and windows.

## Concepts

### Sync Policies

Control how and when applications sync:

```yaml
syncPolicy:
  automated:                    # Enable auto-sync
    prune: true                 # Delete resources not in Git
    selfHeal: true              # Revert manual changes
    allowEmpty: false           # Prevent syncing empty resources
  retry:
    limit: 5                    # Number of retry attempts
    backoff:
      duration: 5s              # Initial backoff duration
      factor: 2                 # Multiplier for each retry
      maxDuration: 3m           # Maximum backoff duration
  syncOptions:
    - CreateNamespace=true      # Create namespace if missing
    - PruneLast=true            # Prune after all resources healthy
    - ApplyOutOfSyncOnly=true   # Only sync changed resources
```

### Sync Options Reference

| Option | Purpose |
|--------|---------|
| `Validate=false` | Skip kubectl validation |
| `CreateNamespace=true` | Auto-create destination namespace |
| `PrunePropagationPolicy=foreground` | Control deletion cascading |
| `PruneLast=true` | Prune after health checks pass |
| `ApplyOutOfSyncOnly=true` | Only apply changed resources |
| `Replace=true` | Use kubectl replace instead of apply |
| `ServerSideApply=true` | Use server-side apply |
| `FailOnSharedResource=true` | Fail if resource owned by another app |
| `RespectIgnoreDifferences=true` | Apply ignoreDifferences during sync |

### Resource-Level Sync Options

Apply via annotations:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: important-data
  annotations:
    argocd.argoproj.io/sync-options: Prune=false,Delete=false
```

### Sync Waves

Control deployment order with waves:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "-1"  # Deploys first
---
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "0"   # Deploys second (default)
---
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "1"   # Deploys third
```

**Ordering:**
1. Phase (PreSync < Sync < PostSync)
2. Wave number (lower first)
3. Kind (Namespaces before Deployments, etc.)
4. Name (alphabetical)

**Wave delay:** Default 2 seconds between waves (configurable via `ARGOCD_SYNC_WAVE_DELAY`)

### Resource Hooks

Execute Jobs/Pods at specific sync phases:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: db-migration
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
spec:
  template:
    spec:
      containers:
      - name: migrate
        image: my-app:migrate
        command: ["./migrate.sh"]
      restartPolicy: Never
```

**Hook Types:**

| Hook | When It Runs |
|------|--------------|
| `PreSync` | Before manifests are applied |
| `Sync` | During manifest application |
| `PostSync` | After sync and resources healthy |
| `SyncFail` | When sync fails |
| `PostDelete` | After application deletion (v2.10+) |
| `Skip` | Skip this resource during sync |

**Deletion Policies:**

| Policy | Behavior |
|--------|----------|
| `HookSucceeded` | Delete after hook succeeds |
| `HookFailed` | Delete after hook fails |
| `BeforeHookCreation` | Delete before creating new hook |

### Sync Windows

Time-based restrictions for sync operations:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: production
spec:
  syncWindows:
    - kind: allow
      schedule: "0 9-17 * * 1-5"  # Weekdays 9am-5pm
      duration: 8h
      applications:
        - "prod-*"
      namespaces:
        - "production"
    - kind: deny
      schedule: "0 0 25 12 *"     # Christmas
      duration: 24h
      applications:
        - "*"
      manualSync: true            # Also block manual syncs
```

### Rollback

```bash
# View history
argocd app history my-app

# Rollback to specific revision
argocd app rollback my-app 3

# Note: Rollback is disabled when auto-sync is enabled
```

## Labs

### Lab 4.1: Configure Auto-Sync

```yaml
# apps/auto-sync-demo-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: auto-sync-demo
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/YOUR_USERNAME/argocd-learning.git
    targetRevision: HEAD
    path: apps/plain-manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: auto-sync-demo
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

Test self-healing:

```bash
kubectl apply -f apps/auto-sync-demo-app.yaml
argocd app sync auto-sync-demo

# Make a manual change
kubectl scale deployment nginx -n auto-sync-demo --replicas=5

# Watch it revert (within 5 seconds by default)
kubectl get deployment nginx -n auto-sync-demo -w
```

### Lab 4.2: Implement Sync Waves

```bash
mkdir -p apps/sync-waves-demo
```

```yaml
# apps/sync-waves-demo/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: waves-demo
  annotations:
    argocd.argoproj.io/sync-wave: "-2"
---
# apps/sync-waves-demo/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: waves-demo
  annotations:
    argocd.argoproj.io/sync-wave: "-1"
data:
  config.json: |
    {"database": "postgres://db:5432"}
---
# apps/sync-waves-demo/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
  namespace: waves-demo
  annotations:
    argocd.argoproj.io/sync-wave: "0"
spec:
  replicas: 1
  selector:
    matchLabels:
      app: demo
  template:
    metadata:
      labels:
        app: demo
    spec:
      containers:
      - name: app
        image: nginx:1.25
        volumeMounts:
        - name: config
          mountPath: /etc/config
      volumes:
      - name: config
        configMap:
          name: app-config
---
# apps/sync-waves-demo/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: app
  namespace: waves-demo
  annotations:
    argocd.argoproj.io/sync-wave: "1"
spec:
  selector:
    app: demo
  ports:
  - port: 80
```

```bash
git add .
git commit -m "Add sync waves demo"
git push

# Create the app and watch the sync order
argocd app create sync-waves-demo \
  --repo https://github.com/YOUR_USERNAME/argocd-learning.git \
  --path apps/sync-waves-demo \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace waves-demo

argocd app sync sync-waves-demo
```

### Lab 4.3: Create Resource Hooks

```bash
mkdir -p apps/hooks-demo
```

```yaml
# apps/hooks-demo/pre-sync-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: pre-check
  namespace: hooks-demo
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-delete-policy: BeforeHookCreation
spec:
  template:
    spec:
      containers:
      - name: check
        image: busybox
        command: ["sh", "-c", "echo 'Running pre-sync checks...' && sleep 5 && echo 'Checks passed!'"]
      restartPolicy: Never
  backoffLimit: 1
---
# apps/hooks-demo/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: main-app
  namespace: hooks-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: main
  template:
    metadata:
      labels:
        app: main
    spec:
      containers:
      - name: app
        image: nginx:1.25
---
# apps/hooks-demo/post-sync-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: smoke-test
  namespace: hooks-demo
  annotations:
    argocd.argoproj.io/hook: PostSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
spec:
  template:
    spec:
      containers:
      - name: test
        image: curlimages/curl
        command: ["sh", "-c", "echo 'Running smoke tests...' && sleep 3 && echo 'Tests passed!'"]
      restartPolicy: Never
  backoffLimit: 1
```

```bash
git add .
git commit -m "Add hooks demo"
git push

argocd app create hooks-demo \
  --repo https://github.com/YOUR_USERNAME/argocd-learning.git \
  --path apps/hooks-demo \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace hooks-demo \
  --sync-option CreateNamespace=true

# Watch the hooks execute
argocd app sync hooks-demo
```

### Lab 4.4: Ignore Differences

```yaml
# apps/ignore-diff-demo.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ignore-diff-demo
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/YOUR_USERNAME/argocd-learning.git
    targetRevision: HEAD
    path: apps/plain-manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: ignore-diff-demo
  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers:
        - /spec/replicas          # Ignore replica count (for HPA)
    - group: ""
      kind: Service
      jqPathExpressions:
        - .spec.clusterIP         # Ignore auto-assigned IP
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
      - RespectIgnoreDifferences=true
```

**Knowledge Check Questions:**
1. What's the difference between `prune: true` and `PruneLast=true`?
2. In what order do sync waves with the same number execute?
3. When would you use `BeforeHookCreation` vs `HookSucceeded`?

## Common Mistakes

1. **Hooks without delete policy** - Old hook Jobs accumulate
2. **Self-heal with HPA** - Constant fighting over replicas (use ignoreDifferences)
3. **Circular wave dependencies** - Wave 1 depends on Wave 2's resource
4. **Rollback with auto-sync** - Rollback is disabled when auto-sync is on

---

# Phase 5: ApplicationSets

**Goal:** Deploy applications at scale with generators.

## Concepts

### What is ApplicationSet?

ApplicationSet is a controller that generates multiple Argo CD Applications from a single template. It solves:

- Multi-cluster deployments
- Monorepo application management
- Self-service environments
- PR-based preview environments

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: my-apps
  namespace: argocd
spec:
  generators:           # Define how to generate parameters
    - list:
        elements: [...]
  template:             # Application template to stamp out
    metadata:
      name: '{{.name}}'
    spec:
      project: default
      source:
        repoURL: '{{.repo}}'
        path: '{{.path}}'
      destination:
        server: '{{.server}}'
```

### Generator Types

#### 1. List Generator

Fixed list of key-value pairs:

```yaml
generators:
  - list:
      elements:
        - cluster: dev
          url: https://dev-cluster.example.com
          namespace: myapp-dev
        - cluster: staging
          url: https://staging-cluster.example.com
          namespace: myapp-staging
        - cluster: prod
          url: https://prod-cluster.example.com
          namespace: myapp-prod
```

#### 2. Cluster Generator

Auto-discover clusters registered in Argo CD:

```yaml
generators:
  - clusters:
      selector:
        matchLabels:
          env: production
      values:
        revision: stable
```

**Available parameters:**
- `{{.name}}` - Cluster name
- `{{.server}}` - Cluster URL
- `{{.metadata.labels.KEY}}` - Cluster labels
- `{{.values.FIELD}}` - Custom values

#### 3. Git Generator (Directory)

Generate from repository directory structure:

```yaml
generators:
  - git:
      repoURL: https://github.com/org/repo.git
      revision: HEAD
      directories:
        - path: apps/*
        - path: apps/excluded
          exclude: true
```

**Available parameters:**
- `{{.path.path}}` - Full path (apps/myapp)
- `{{.path.basename}}` - Directory name (myapp)
- `{{.path.basenameNormalized}}` - DNS-safe name

#### 4. Git Generator (Files)

Generate from JSON/YAML files:

```yaml
generators:
  - git:
      repoURL: https://github.com/org/repo.git
      revision: HEAD
      files:
        - path: "config/**/config.json"
```

File content becomes parameters:

```json
// config/us-east/config.json
{
  "cluster": "us-east-1",
  "replicas": 3,
  "env": "production"
}
```

#### 5. Matrix Generator

Combine two generators (cartesian product):

```yaml
generators:
  - matrix:
      generators:
        - clusters:
            selector:
              matchLabels:
                env: production
        - list:
            elements:
              - app: frontend
                path: apps/frontend
              - app: backend
                path: apps/backend
```

Creates applications for: `frontend-cluster1`, `frontend-cluster2`, `backend-cluster1`, `backend-cluster2`

#### 6. Merge Generator

Combine generators with overrides:

```yaml
generators:
  - merge:
      mergeKeys:
        - cluster
      generators:
        # Base configuration
        - list:
            elements:
              - cluster: dev
                replicas: 1
              - cluster: prod
                replicas: 3
        # Override specific clusters
        - list:
            elements:
              - cluster: prod
                replicas: 10  # Override prod replicas
```

#### 7. Pull Request Generator

Generate from open PRs:

```yaml
generators:
  - pullRequest:
      github:
        owner: myorg
        repo: myrepo
        tokenRef:
          secretName: github-token
          key: token
        labels:
          - preview
      requeueAfterSeconds: 60
```

**Available parameters:**
- `{{.number}}` - PR number
- `{{.branch}}` - Source branch
- `{{.head_sha}}` - Commit SHA
- `{{.labels}}` - PR labels

#### 8. SCM Provider Generator

Discover repositories in organization:

```yaml
generators:
  - scmProvider:
      github:
        organization: myorg
        tokenRef:
          secretName: github-token
          key: token
      filters:
        - repositoryMatch: "^service-.*"
```

#### 9. Plugin Generator

External RPC for custom logic:

```yaml
generators:
  - plugin:
      configMapRef:
        name: my-plugin
      input:
        parameters:
          env: production
      requeueAfterSeconds: 300
```

### Progressive Sync

Control rollout across generated applications:

```yaml
spec:
  strategy:
    type: RollingSync
    rollingSync:
      steps:
        - matchExpressions:
            - key: env
              operator: In
              values:
                - dev
        - matchExpressions:
            - key: env
              operator: In
              values:
                - staging
          maxUpdate: 50%
        - matchExpressions:
            - key: env
              operator: In
              values:
                - prod
          maxUpdate: 1
```

## Labs

### Lab 5.1: List Generator

```yaml
# applicationsets/list-demo.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: nginx-environments
  namespace: argocd
spec:
  generators:
    - list:
        elements:
          - env: dev
            replicas: "1"
            namespace: nginx-dev
          - env: staging
            replicas: "2"
            namespace: nginx-staging
          - env: prod
            replicas: "3"
            namespace: nginx-prod
  template:
    metadata:
      name: 'nginx-{{.env}}'
      labels:
        env: '{{.env}}'
    spec:
      project: default
      source:
        repoURL: https://charts.bitnami.com/bitnami
        chart: nginx
        targetRevision: 15.0.0
        helm:
          parameters:
            - name: replicaCount
              value: '{{.replicas}}'
      destination:
        server: https://kubernetes.default.svc
        namespace: '{{.namespace}}'
      syncPolicy:
        automated:
          prune: true
        syncOptions:
          - CreateNamespace=true
```

```bash
kubectl apply -f applicationsets/list-demo.yaml

# Verify applications were created
argocd app list

# Should see: nginx-dev, nginx-staging, nginx-prod
```

### Lab 5.2: Git Directory Generator

```bash
mkdir -p apps/services/{frontend,backend,api}
```

Create identical base apps:

```yaml
# apps/services/frontend/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: app
        image: nginx:1.25
        ports:
        - containerPort: 80
```

(Create similar files for backend and api)

```yaml
# applicationsets/git-directory-demo.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: services
  namespace: argocd
spec:
  generators:
    - git:
        repoURL: https://github.com/YOUR_USERNAME/argocd-learning.git
        revision: HEAD
        directories:
          - path: apps/services/*
  template:
    metadata:
      name: 'service-{{.path.basename}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/YOUR_USERNAME/argocd-learning.git
        targetRevision: HEAD
        path: '{{.path.path}}'
      destination:
        server: https://kubernetes.default.svc
        namespace: '{{.path.basename}}'
      syncPolicy:
        automated:
          prune: true
        syncOptions:
          - CreateNamespace=true
```

```bash
git add .
git commit -m "Add services for Git directory generator"
git push

kubectl apply -f applicationsets/git-directory-demo.yaml
```

### Lab 5.3: Git File Generator

```bash
mkdir -p cluster-config/{us-east,us-west,eu-central}
```

```json
// cluster-config/us-east/config.json
{
  "cluster": "us-east",
  "region": "us-east-1",
  "replicas": 3,
  "env": "production"
}
```

```json
// cluster-config/us-west/config.json
{
  "cluster": "us-west",
  "region": "us-west-2",
  "replicas": 2,
  "env": "production"
}
```

```json
// cluster-config/eu-central/config.json
{
  "cluster": "eu-central",
  "region": "eu-central-1",
  "replicas": 2,
  "env": "staging"
}
```

```yaml
# applicationsets/git-file-demo.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: regional-apps
  namespace: argocd
spec:
  generators:
    - git:
        repoURL: https://github.com/YOUR_USERNAME/argocd-learning.git
        revision: HEAD
        files:
          - path: "cluster-config/**/config.json"
  template:
    metadata:
      name: 'app-{{.cluster}}'
      labels:
        region: '{{.region}}'
        env: '{{.env}}'
    spec:
      project: default
      source:
        repoURL: https://charts.bitnami.com/bitnami
        chart: nginx
        targetRevision: 15.0.0
        helm:
          parameters:
            - name: replicaCount
              value: '{{.replicas}}'
      destination:
        server: https://kubernetes.default.svc
        namespace: 'app-{{.cluster}}'
      syncPolicy:
        automated:
          prune: true
        syncOptions:
          - CreateNamespace=true
```

### Lab 5.4: Matrix Generator (Multi-Cluster Multi-App)

```yaml
# applicationsets/matrix-demo.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: platform-apps
  namespace: argocd
spec:
  generators:
    - matrix:
        generators:
          # Environments
          - list:
              elements:
                - env: dev
                  namespace-suffix: dev
                - env: prod
                  namespace-suffix: prod
          # Applications
          - list:
              elements:
                - app: redis
                  chart: redis
                  version: 17.0.0
                - app: postgresql
                  chart: postgresql
                  version: 12.0.0
  template:
    metadata:
      name: '{{.app}}-{{.env}}'
    spec:
      project: default
      source:
        repoURL: https://charts.bitnami.com/bitnami
        chart: '{{.chart}}'
        targetRevision: '{{.version}}'
      destination:
        server: https://kubernetes.default.svc
        namespace: 'data-{{.namespace-suffix}}'
      syncPolicy:
        automated:
          prune: true
        syncOptions:
          - CreateNamespace=true
```

Creates: `redis-dev`, `redis-prod`, `postgresql-dev`, `postgresql-prod`

### Lab 5.5: Pull Request Preview Environments

```yaml
# applicationsets/pr-preview.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: pr-previews
  namespace: argocd
spec:
  generators:
    - pullRequest:
        github:
          owner: YOUR_USERNAME
          repo: argocd-learning
          tokenRef:
            secretName: github-token
            key: token
          labels:
            - deploy-preview
        requeueAfterSeconds: 60
  template:
    metadata:
      name: 'preview-{{.number}}'
      labels:
        app: preview
        pr: '{{.number}}'
    spec:
      project: default
      source:
        repoURL: 'https://github.com/YOUR_USERNAME/argocd-learning.git'
        targetRevision: '{{.head_sha}}'
        path: apps/plain-manifests
      destination:
        server: https://kubernetes.default.svc
        namespace: 'preview-{{.number}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
```

**Note:** Create the GitHub token secret first:

```bash
kubectl create secret generic github-token \
  -n argocd \
  --from-literal=token=ghp_YOUR_TOKEN
```

**Knowledge Check Questions:**
1. What's the difference between Matrix and Merge generators?
2. How do you exclude a directory in the Git generator?
3. What happens to Applications when you delete an ApplicationSet?

## Common Mistakes

1. **Forgetting gotemplate syntax** - Using `{{name}}` instead of `{{.name}}`
2. **Cluster doesn't exist** - Clusters must be registered in Argo CD first
3. **PR generator without token** - API rate limiting
4. **ApplicationSet in wrong namespace** - Must be in argocd namespace

---

# Phase 6: Projects & Multi-Tenancy

**Goal:** Implement team isolation and access control.

## Concepts

### AppProject Overview

Projects provide:
- **Source restrictions** - Which repos can be used
- **Destination restrictions** - Which clusters/namespaces
- **Resource restrictions** - Which resource types
- **Role-based access** - Team-specific permissions

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: team-backend
  namespace: argocd
spec:
  description: "Backend team's project"

  # Allowed source repositories
  sourceRepos:
    - 'https://github.com/myorg/backend-*'
    - 'https://charts.helm.sh/*'

  # Allowed destinations
  destinations:
    - namespace: 'backend-*'
      server: https://kubernetes.default.svc
    - namespace: 'backend-prod'
      server: https://prod-cluster.example.com

  # Allowed cluster-scoped resources
  clusterResourceWhitelist:
    - group: ''
      kind: Namespace

  # Denied namespaced resources
  namespaceResourceBlacklist:
    - group: ''
      kind: ResourceQuota
    - group: ''
      kind: LimitRange

  # Allowed namespaced resources (if whitelist used, only these allowed)
  namespaceResourceWhitelist:
    - group: 'apps'
      kind: Deployment
    - group: 'apps'
      kind: StatefulSet
    - group: ''
      kind: Service
    - group: ''
      kind: ConfigMap
    - group: ''
      kind: Secret
```

### Destination Restrictions

Control where applications can deploy:

```yaml
destinations:
  # Specific namespace on specific cluster
  - namespace: production
    server: https://prod-cluster.example.com

  # Any namespace matching pattern on any cluster
  - namespace: 'team-*'
    server: '*'

  # Specific namespace on cluster by name
  - namespace: staging
    name: staging-cluster
```

### Source Repository Restrictions

```yaml
sourceRepos:
  # Exact match
  - 'https://github.com/myorg/myrepo.git'

  # Wildcard
  - 'https://github.com/myorg/*'

  # All repositories (use cautiously)
  - '*'
```

### Resource Whitelisting/Blacklisting

**Blacklist approach** (allow all except):

```yaml
namespaceResourceBlacklist:
  - group: ''
    kind: ResourceQuota
  - group: ''
    kind: LimitRange
  - group: 'networking.k8s.io'
    kind: NetworkPolicy
```

**Whitelist approach** (deny all except):

```yaml
namespaceResourceWhitelist:
  - group: 'apps'
    kind: '*'           # All resources in apps group
  - group: ''
    kind: Service
  - group: ''
    kind: ConfigMap
```

### Project Roles

Define custom roles within a project:

```yaml
spec:
  roles:
    - name: developer
      description: "Development team access"
      policies:
        - p, proj:team-backend:developer, applications, get, team-backend/*, allow
        - p, proj:team-backend:developer, applications, sync, team-backend/*, allow
      groups:
        - my-oidc-group          # OIDC group binding

    - name: viewer
      description: "Read-only access"
      policies:
        - p, proj:team-backend:viewer, applications, get, team-backend/*, allow
```

### Orphaned Resources

Monitor resources not managed by any Application:

```yaml
spec:
  orphanedResources:
    warn: true                    # Show warnings in UI
    ignore:
      - group: ''
        kind: ConfigMap
        name: kube-root-ca.crt   # Ignore specific resources
```

### Sync Windows (Project-Level)

```yaml
spec:
  syncWindows:
    - kind: allow
      schedule: '0 9-17 * * 1-5'  # Cron: Weekdays 9am-5pm
      duration: 8h
      applications:
        - '*'
      clusters:
        - in-cluster
      namespaces:
        - production

    - kind: deny
      schedule: '0 0 * * 0'       # Sundays
      duration: 24h
      applications:
        - '*'
      manualSync: true            # Also block manual syncs
```

## Labs

### Lab 6.1: Create Team Projects

```yaml
# projects/team-frontend.yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: team-frontend
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  description: "Frontend team project"

  sourceRepos:
    - 'https://github.com/YOUR_USERNAME/argocd-learning.git'
    - 'https://charts.bitnami.com/*'

  destinations:
    - namespace: 'frontend-*'
      server: https://kubernetes.default.svc

  clusterResourceWhitelist:
    - group: ''
      kind: Namespace

  namespaceResourceWhitelist:
    - group: 'apps'
      kind: Deployment
    - group: 'apps'
      kind: ReplicaSet
    - group: ''
      kind: Service
    - group: ''
      kind: ConfigMap
    - group: ''
      kind: Pod
```

```yaml
# projects/team-backend.yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: team-backend
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  description: "Backend team project"

  sourceRepos:
    - 'https://github.com/YOUR_USERNAME/argocd-learning.git'
    - 'https://charts.bitnami.com/*'

  destinations:
    - namespace: 'backend-*'
      server: https://kubernetes.default.svc

  clusterResourceWhitelist:
    - group: ''
      kind: Namespace

  # Backend can use StatefulSets for databases
  namespaceResourceWhitelist:
    - group: 'apps'
      kind: Deployment
    - group: 'apps'
      kind: StatefulSet
    - group: 'apps'
      kind: ReplicaSet
    - group: ''
      kind: Service
    - group: ''
      kind: ConfigMap
    - group: ''
      kind: Secret
    - group: ''
      kind: PersistentVolumeClaim
    - group: ''
      kind: Pod
```

```bash
kubectl apply -f projects/
```

### Lab 6.2: Deploy to Team Projects

```yaml
# apps/frontend-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: frontend-web
  namespace: argocd
spec:
  project: team-frontend   # Uses the restricted project
  source:
    repoURL: https://charts.bitnami.com/bitnami
    chart: nginx
    targetRevision: 15.0.0
  destination:
    server: https://kubernetes.default.svc
    namespace: frontend-dev    # Must match project's allowed namespaces
  syncPolicy:
    automated:
      prune: true
    syncOptions:
      - CreateNamespace=true
```

```bash
kubectl apply -f apps/frontend-app.yaml
argocd app sync frontend-web
```

### Lab 6.3: Test Project Restrictions

Try to violate project restrictions:

```yaml
# apps/frontend-violation.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: frontend-violation
  namespace: argocd
spec:
  project: team-frontend
  source:
    repoURL: https://charts.bitnami.com/bitnami
    chart: nginx
    targetRevision: 15.0.0
  destination:
    server: https://kubernetes.default.svc
    namespace: backend-dev     # VIOLATION: Wrong namespace pattern
```

```bash
kubectl apply -f apps/frontend-violation.yaml
# This should fail with: "application destination is not allowed"
```

### Lab 6.4: Add Sync Windows

```yaml
# projects/team-production.yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: team-production
  namespace: argocd
spec:
  description: "Production project with sync windows"

  sourceRepos:
    - '*'

  destinations:
    - namespace: 'prod-*'
      server: https://kubernetes.default.svc

  # Only allow syncs during business hours
  syncWindows:
    - kind: allow
      schedule: '0 9 * * 1-5'    # 9am Monday-Friday
      duration: 8h               # Until 5pm
      applications:
        - '*'
      manualSync: true

    - kind: deny
      schedule: '0 0 25 12 *'    # Christmas
      duration: 48h
      applications:
        - '*'
      manualSync: true
```

### Lab 6.5: Orphaned Resource Monitoring

```yaml
# projects/monitored-project.yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: monitored-project
  namespace: argocd
spec:
  description: "Project with orphaned resource monitoring"

  sourceRepos:
    - '*'

  destinations:
    - namespace: 'monitored'
      server: https://kubernetes.default.svc

  orphanedResources:
    warn: true
    ignore:
      - group: ''
        kind: ConfigMap
        name: kube-root-ca.crt
```

```bash
# Create a namespace and deploy an app
kubectl create namespace monitored

# Create a resource manually (will be detected as orphaned)
kubectl create configmap orphan-config --from-literal=key=value -n monitored

# Create an application
argocd app create monitored-app \
  --project monitored-project \
  --repo https://github.com/argoproj/argocd-example-apps.git \
  --path guestbook \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace monitored

argocd app sync monitored-app

# Check for orphaned resources in the UI or CLI
argocd proj get monitored-project
```

**Knowledge Check Questions:**
1. What happens if an Application tries to deploy a resource type not in the whitelist?
2. How do sync windows interact with auto-sync?
3. Can an Application belong to multiple projects?

## Common Mistakes

1. **Empty whitelist blocks everything** - An empty `namespaceResourceWhitelist` denies all
2. **Forgetting finalizers** - Projects without finalizers can be deleted with apps
3. **Overlapping sync windows** - Deny windows override allow windows
4. **Wildcard in destinations** - `*` for server is very permissive

---

# Phase 7: Security & Access Control

**Goal:** Implement production-ready security.

## Concepts

### RBAC Overview

Argo CD uses Casbin-based RBAC with two main constructs:

```
# Group assignment
g, <user/group>, <role>

# Policy (permission)
p, <role/user/group>, <resource>, <action>, <object>, <effect>
```

### Built-in Roles

| Role | Permissions |
|------|-------------|
| `role:readonly` | Read all resources |
| `role:admin` | Full access to all resources |

### Resources and Actions

| Resource | Actions |
|----------|---------|
| `applications` | get, create, update, delete, sync, action, override |
| `applicationsets` | get, create, update, delete |
| `clusters` | get, create, update, delete |
| `projects` | get, create, update, delete |
| `repositories` | get, create, update, delete |
| `accounts` | get, update |
| `logs` | get |
| `exec` | create |

### RBAC Configuration

```yaml
# argocd-rbac-cm ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  # Default role for authenticated users
  policy.default: role:readonly

  # Custom policies
  policy.csv: |
    # Assign built-in role to group
    g, my-admin-group, role:admin

    # Custom role for developers
    p, role:developer, applications, get, */*, allow
    p, role:developer, applications, sync, */*, allow
    p, role:developer, applications, action, */*, allow
    g, developers, role:developer

    # Project-specific permissions
    p, team-a, applications, *, team-a/*, allow
    p, team-a, repositories, get, *, allow
    g, team-a-members, team-a

    # Deny specific actions
    p, role:developer, applications, delete, */*, deny

  # Use glob matching (default) or regex
  policy.matchMode: glob
```

### SSO Integration

Argo CD supports multiple identity providers:

**OIDC (Generic):**

```yaml
# argocd-cm ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  url: https://argocd.example.com
  oidc.config: |
    name: IdentityCo
    issuer: https://your-org.identityco.com
    clientID: your-client-id
    clientSecret: $oidc.identityco.clientSecret
    requestedScopes: ["openid", "profile", "email", "groups"]
```

**Dex (Built-in connector):**

```yaml
data:
  dex.config: |
    connectors:
      - type: github
        id: github
        name: GitHub
        config:
          clientID: $dex.github.clientID
          clientSecret: $dex.github.clientSecret
          orgs:
            - name: your-github-org
```

### Secret Management Strategies

**Recommended: External Secrets Operator**

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: app-secrets
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: app-secrets
  data:
    - secretKey: database-password
      remoteRef:
        key: secret/app
        property: db_password
```

**Alternative: Sealed Secrets**

```bash
# Encrypt secrets client-side
kubeseal --format=yaml < secret.yaml > sealed-secret.yaml
```

The sealed secret can be committed to Git safely.

### Repository Credentials

**HTTPS with token:**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: private-repo
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  url: https://github.com/myorg/private-repo.git
  username: git
  password: ghp_xxxxxxxxxxxxx
```

**SSH key:**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: private-repo-ssh
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  url: git@github.com:myorg/private-repo.git
  sshPrivateKey: |
    -----BEGIN OPENSSH PRIVATE KEY-----
    ...
    -----END OPENSSH PRIVATE KEY-----
```

**Credential templates (pattern matching):**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: github-creds
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repo-creds
stringData:
  url: https://github.com/myorg
  username: git
  password: ghp_xxxxxxxxxxxxx
```

## Labs

### Lab 7.1: Configure Basic RBAC

```yaml
# Update argocd-rbac-cm
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  policy.default: role:readonly
  policy.csv: |
    # Admin group gets full access
    g, argocd-admins, role:admin

    # Developers can view and sync
    p, role:developer, applications, get, */*, allow
    p, role:developer, applications, sync, */*, allow
    p, role:developer, logs, get, */*, allow
    g, developers, role:developer

    # Team-specific access
    p, team-frontend, applications, *, team-frontend/*, allow
    p, team-frontend, repositories, get, *, allow

    p, team-backend, applications, *, team-backend/*, allow
    p, team-backend, repositories, get, *, allow
```

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  policy.default: role:readonly
  policy.csv: |
    g, argocd-admins, role:admin
    p, role:developer, applications, get, */*, allow
    p, role:developer, applications, sync, */*, allow
    g, developers, role:developer
EOF
```

### Lab 7.2: Create Local Users

```yaml
# argocd-cm ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  # Enable local users
  accounts.developer: apiKey, login
  accounts.viewer: login
```

```bash
# Apply the config
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  accounts.developer: apiKey, login
  accounts.viewer: login
EOF

# Set passwords
argocd account update-password --account developer
argocd account update-password --account viewer

# Verify accounts
argocd account list
```

### Lab 7.3: Add Repository Credentials

```bash
# Via CLI
argocd repo add https://github.com/YOUR_USERNAME/private-repo.git \
  --username git \
  --password ghp_YOUR_TOKEN

# Verify
argocd repo list
```

Or declaratively:

```yaml
# secrets/repo-creds.yaml
apiVersion: v1
kind: Secret
metadata:
  name: private-repo-creds
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repo-creds
type: Opaque
stringData:
  url: https://github.com/YOUR_USERNAME
  username: git
  password: ghp_YOUR_TOKEN   # Replace with actual token
```

### Lab 7.4: Set Up External Secrets (Demo)

```bash
# Install External Secrets Operator
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets \
  -n external-secrets --create-namespace
```

```yaml
# Create a fake secret store for demo
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: fake-store
  namespace: default
spec:
  provider:
    fake:
      data:
        - key: "/database/password"
          value: "super-secret-password"
        - key: "/api/key"
          value: "api-key-12345"
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: app-secrets
  namespace: default
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: fake-store
    kind: SecretStore
  target:
    name: app-secrets
  data:
    - secretKey: db-password
      remoteRef:
        key: /database/password
    - secretKey: api-key
      remoteRef:
        key: /api/key
```

```bash
kubectl apply -f external-secret-demo.yaml

# Verify the secret was created
kubectl get secret app-secrets -o yaml
```

### Lab 7.5: Test RBAC Policies

```bash
# Login as developer
argocd login localhost:8080 --username developer --password <password>

# Try to view apps (should work)
argocd app list

# Try to delete an app (should fail)
argocd app delete nginx-dev
# Error: permission denied

# Try to sync (should work)
argocd app sync nginx-dev
```

**Knowledge Check Questions:**
1. What's the difference between `role:readonly` and a custom readonly policy?
2. How does the `g` (group) directive work?
3. What takes precedence: allow or deny?

## Common Mistakes

1. **Default policy too permissive** - Giving `role:admin` to all authenticated users
2. **Missing group mappings** - OIDC groups not mapped to Argo CD roles
3. **Secrets in Git** - Never commit actual secrets, use Sealed Secrets or External Secrets
4. **Not using repo-creds** - Creating individual credentials per repo instead of patterns

---

# Phase 8: Observability & Optimization

**Goal:** Monitor, alert, and optimize Argo CD.

## Concepts

### Metrics Overview

Argo CD exposes Prometheus metrics on multiple endpoints:

| Component | Endpoint | Port |
|-----------|----------|------|
| Application Controller | `argocd-metrics:8082/metrics` | 8082 |
| API Server | `argocd-server-metrics:8083/metrics` | 8083 |
| Repo Server | `argocd-repo-server:8084/metrics` | 8084 |

### Key Metrics

**Application Health:**
```promql
# Application sync status
argocd_app_info{sync_status="OutOfSync"}

# Application health status
argocd_app_info{health_status="Degraded"}

# Sync operations
argocd_app_sync_total{phase="Succeeded"}
argocd_app_sync_total{phase="Failed"}
```

**Controller Performance:**
```promql
# Reconciliation duration
histogram_quantile(0.95, sum(rate(argocd_app_reconcile_bucket[5m])) by (le))

# Pending applications
argocd_app_info{sync_status="Unknown"}

# Cluster connection status
argocd_cluster_connection_status
```

**Resource Usage:**
```promql
# Git operations
argocd_git_request_total
argocd_git_request_duration_seconds

# Kubectl operations
argocd_kubectl_exec_total
```

### Notifications

Configure alerts for application events:

```yaml
# argocd-notifications-cm ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-notifications-cm
  namespace: argocd
data:
  # Notification services
  service.slack: |
    token: $slack-token

  # Triggers
  trigger.on-sync-failed: |
    - when: app.status.sync.status == 'OutOfSync'
      send: [app-sync-failed]

  trigger.on-health-degraded: |
    - when: app.status.health.status == 'Degraded'
      send: [app-health-degraded]

  # Templates
  template.app-sync-failed: |
    message: |
      Application {{.app.metadata.name}} sync failed.
      Sync Status: {{.app.status.sync.status}}

  template.app-health-degraded: |
    message: |
      Application {{.app.metadata.name}} is degraded.
      Health Status: {{.app.status.health.status}}
```

### Subscribing to Notifications

Via annotations on Applications:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  annotations:
    notifications.argoproj.io/subscribe.on-sync-failed.slack: my-channel
    notifications.argoproj.io/subscribe.on-health-degraded.slack: my-channel
```

### Custom Health Checks

Write Lua scripts for custom resource health:

```yaml
# argocd-cm ConfigMap
data:
  resource.customizations.health.mycrd.example.com_MyResource: |
    hs = {}
    if obj.status ~= nil then
      if obj.status.phase == "Ready" then
        hs.status = "Healthy"
        hs.message = "Resource is ready"
      elseif obj.status.phase == "Provisioning" then
        hs.status = "Progressing"
        hs.message = "Resource is being provisioned"
      else
        hs.status = "Degraded"
        hs.message = obj.status.message or "Unknown error"
      end
    else
      hs.status = "Progressing"
      hs.message = "Waiting for status"
    end
    return hs
```

### Diff Customization

Ignore certain fields to prevent false drift:

```yaml
# argocd-cm ConfigMap
data:
  resource.customizations.ignoreDifferences.all: |
    managedFieldsManagers:
      - kube-controller-manager
      - cluster-autoscaler

  resource.customizations.ignoreDifferences.admissionregistration.k8s.io_MutatingWebhookConfiguration: |
    jqPathExpressions:
      - '.webhooks[]?.clientConfig.caBundle'
```

### Git Webhooks

Configure webhooks for immediate sync:

```yaml
# argocd-cm ConfigMap
data:
  # GitHub webhook secret
  webhook.github.secret: $webhook.github.secret
```

Then configure webhook in GitHub:
- URL: `https://argocd.example.com/api/webhook`
- Content type: `application/json`
- Secret: (match the secret above)
- Events: Push, Pull Request

## Labs

### Lab 8.1: Set Up Prometheus Monitoring

```yaml
# prometheus-servicemonitors.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-metrics
  namespace: argocd
  labels:
    release: prometheus
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-metrics
  endpoints:
    - port: metrics
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-server-metrics
  namespace: argocd
  labels:
    release: prometheus
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-server-metrics
  endpoints:
    - port: metrics
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-repo-server
  namespace: argocd
  labels:
    release: prometheus
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-repo-server
  endpoints:
    - port: metrics
```

### Lab 8.2: Create Alerting Rules

```yaml
# prometheus-rules.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: argocd-alerts
  namespace: argocd
spec:
  groups:
    - name: argocd
      rules:
        - alert: ArgoCDAppOutOfSync
          expr: argocd_app_info{sync_status="OutOfSync"} == 1
          for: 15m
          labels:
            severity: warning
          annotations:
            summary: "Application {{ $labels.name }} is out of sync"
            description: "Application {{ $labels.name }} in project {{ $labels.project }} has been out of sync for more than 15 minutes."

        - alert: ArgoCDAppDegraded
          expr: argocd_app_info{health_status="Degraded"} == 1
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "Application {{ $labels.name }} is degraded"
            description: "Application {{ $labels.name }} has been in degraded health for more than 5 minutes."

        - alert: ArgoCDSyncFailed
          expr: increase(argocd_app_sync_total{phase="Failed"}[10m]) > 0
          labels:
            severity: warning
          annotations:
            summary: "Application sync failed"
            description: "An application sync operation failed in the last 10 minutes."
```

### Lab 8.3: Configure Slack Notifications

```yaml
# argocd-notifications-secret
apiVersion: v1
kind: Secret
metadata:
  name: argocd-notifications-secret
  namespace: argocd
type: Opaque
stringData:
  slack-token: xoxb-YOUR-SLACK-TOKEN
---
# argocd-notifications-cm
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-notifications-cm
  namespace: argocd
data:
  service.slack: |
    token: $slack-token

  trigger.on-deployed: |
    - when: app.status.operationState.phase in ['Succeeded'] and app.status.health.status == 'Healthy'
      oncePer: app.status.sync.revision
      send: [app-deployed]

  trigger.on-sync-failed: |
    - when: app.status.operationState.phase in ['Error', 'Failed']
      send: [app-sync-failed]

  trigger.on-health-degraded: |
    - when: app.status.health.status == 'Degraded'
      send: [app-health-degraded]

  template.app-deployed: |
    slack:
      attachments: |
        [{
          "color": "#18be52",
          "title": "{{ .app.metadata.name }} deployed",
          "fields": [
            {"title": "Revision", "value": "{{ .app.status.sync.revision }}", "short": true},
            {"title": "Project", "value": "{{ .app.spec.project }}", "short": true}
          ]
        }]

  template.app-sync-failed: |
    slack:
      attachments: |
        [{
          "color": "#E96D76",
          "title": "{{ .app.metadata.name }} sync failed",
          "fields": [
            {"title": "Error", "value": "{{ .app.status.operationState.message }}", "short": false}
          ]
        }]

  template.app-health-degraded: |
    slack:
      attachments: |
        [{
          "color": "#f4c030",
          "title": "{{ .app.metadata.name }} health degraded",
          "fields": [
            {"title": "Health Status", "value": "{{ .app.status.health.status }}", "short": true}
          ]
        }]
```

Subscribe an application:

```bash
kubectl annotate application my-app \
  notifications.argoproj.io/subscribe.on-deployed.slack=deployments \
  notifications.argoproj.io/subscribe.on-sync-failed.slack=alerts \
  notifications.argoproj.io/subscribe.on-health-degraded.slack=alerts \
  -n argocd
```

### Lab 8.4: Custom Health Check

```yaml
# Add to argocd-cm ConfigMap
data:
  resource.customizations.health.cert-manager.io_Certificate: |
    hs = {}
    if obj.status ~= nil then
      if obj.status.conditions ~= nil then
        for i, condition in ipairs(obj.status.conditions) do
          if condition.type == "Ready" and condition.status == "True" then
            hs.status = "Healthy"
            hs.message = condition.message
            return hs
          end
          if condition.type == "Ready" and condition.status == "False" then
            hs.status = "Degraded"
            hs.message = condition.message
            return hs
          end
        end
      end
    end
    hs.status = "Progressing"
    hs.message = "Waiting for certificate to be issued"
    return hs
```

### Lab 8.5: Configure Ignore Differences

```yaml
# Add to argocd-cm ConfigMap
data:
  resource.customizations.ignoreDifferences.all: |
    managedFieldsManagers:
      - kube-controller-manager
    jsonPointers:
      - /status

  resource.customizations.ignoreDifferences.apps_Deployment: |
    jqPathExpressions:
      - .spec.replicas
    managedFieldsManagers:
      - cluster-autoscaler
```

**Knowledge Check Questions:**
1. Which metric indicates an application has been out of sync?
2. How do you make notifications trigger only once per commit?
3. What Lua return values indicate a healthy resource?

## Common Mistakes

1. **Missing ServiceMonitor labels** - Prometheus won't discover the endpoints
2. **Notification syntax errors** - YAML in ConfigMap is tricky
3. **Overly broad ignoreDifferences** - Can hide real drift
4. **No alert routing** - Alerts fire but nobody receives them

---

# Phase 9: High Availability & Disaster Recovery

**Goal:** Run Argo CD reliably at scale.

## Concepts

### HA Architecture

For production, deploy Argo CD in HA mode:

<!-- figure: generated from the Mermaid below by _shared/diagrams/embed-figures.py — do not edit the image -->
![HA Architecture — diagram](../../../../_figures/curriculum-_reference-cicd-gitops-argocd-ARGOCD_MASTERY_ROADMAP-2-8af20988.png)

<details>
<summary>Diagram source (Mermaid)</summary>

```mermaid
%%{init: {'theme':'base','themeVariables':{'fontFamily':'Helvetica, Arial, sans-serif','fontSize':'13px','primaryColor':'#ffffff','primaryTextColor':'#2d3436','primaryBorderColor':'#9aa3ab','lineColor':'#9aa3ab','textColor':'#2d3436','clusterBkg':'#fbfcfd','clusterBorder':'#d4dae0','edgeLabelBackground':'#ffffff','tertiaryColor':'#eef4fb'},'flowchart':{'curve':'basis','padding':14,'nodeSpacing':42,'rankSpacing':58}}}%%
flowchart TB
  classDef default fill:#ffffff,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef n    fill:#ffffff,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef crit fill:#eef4fb,stroke:#2f6fb8,stroke-width:1.8px,color:#1b3a5c
  classDef data fill:#f4f7fa,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef mut  fill:#ffffff,stroke:#cfd6dc,stroke-width:1.1px,color:#7a8288
  classDef warn fill:#fdf0ec,stroke:#c0522d,stroke-width:1.6px,color:#8a3a1e
  LB["Load balancer"]:::n
  subgraph HA["High-availability Argo CD"]
    direction TB
    S["argocd-server · 3+ replicas<br/><small>stateless</small>"]:::n
    R["argocd-repo-server · 2+ replicas<br/><small>stateless, scales horizontally</small>"]:::n
    C["argocd-application-controller<br/><small>shard by cluster for large installs</small>"]:::crit
    RD[("redis-ha · 3 replicas<br/><small>the only stateful piece</small>")]:::data
  end

  LB --> S
  S --> C
  R --> C
  S -.-> RD
  C -.-> RD

  linkStyle 1,2 stroke:#2f6fb8,stroke-width:2px
```

</details>

### Controller Sharding

For large deployments (1000+ applications), shard the controller:

```yaml
# Set number of controller replicas
env:
  - name: ARGOCD_CONTROLLER_REPLICAS
    value: "3"
```

**Sharding algorithms:**
- `legacy` - Round-robin based on app name
- `round-robin` - Balanced distribution
- `consistent-hashing` - Minimal resharding on scale

### Performance Tuning

**Application Controller:**
```yaml
# Increase processors for more apps
args:
  - --status-processors=50    # Default: 20
  - --operation-processors=25  # Default: 10
  - --self-heal-timeout-seconds=5
```

**Repo Server:**
```yaml
# Limit concurrent manifest generations
args:
  - --parallelismlimit=5
env:
  - name: ARGOCD_EXEC_TIMEOUT
    value: "180"   # Seconds for helm/kustomize
  - name: ARGOCD_GIT_ATTEMPTS_COUNT
    value: "5"     # Retry failed git operations
```

**API Server:**
```yaml
env:
  - name: ARGOCD_GRPC_MAX_SIZE_MB
    value: "200"   # Increase for many apps
```

### Monorepo Optimization

For repositories with many applications:

```yaml
# Application annotation
metadata:
  annotations:
    argocd.argoproj.io/manifest-generate-paths: /apps/my-app
```

This tells Argo CD to only regenerate manifests when files in that path change.

### Backup and Restore

**Export all Argo CD data:**

```bash
# Using Docker
docker run -v ~/.kube:/home/argocd/.kube --rm \
  quay.io/argoproj/argocd:v2.9.0 \
  argocd admin export > backup.yaml

# Or using kubectl
kubectl get applications,appprojects,secrets,configmaps \
  -n argocd -o yaml > backup.yaml
```

**Restore:**

```bash
docker run -i -v ~/.kube:/home/argocd/.kube --rm \
  quay.io/argoproj/argocd:v2.9.0 \
  argocd admin import - < backup.yaml
```

### Upgrade Strategy

1. **Backup current state**
2. **Read release notes** for breaking changes
3. **Test in non-prod** environment first
4. **Apply new manifests** (HA ensures zero downtime)
5. **Verify health** of all components
6. **Monitor** for issues

```bash
# Example upgrade
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.10.0/manifests/ha/install.yaml
```

## Labs

### Lab 9.1: Deploy HA Argo CD

```bash
# Delete existing non-HA installation
kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Install HA version
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/ha/install.yaml

# Wait for all pods
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s

# Verify HA deployment
kubectl get pods -n argocd
```

Expected output shows multiple replicas:
```
argocd-application-controller-0          1/1     Running
argocd-redis-ha-server-0                 2/2     Running
argocd-redis-ha-server-1                 2/2     Running
argocd-redis-ha-server-2                 2/2     Running
argocd-repo-server-xxx                   1/1     Running
argocd-repo-server-yyy                   1/1     Running
argocd-server-xxx                        1/1     Running
argocd-server-yyy                        1/1     Running
argocd-server-zzz                        1/1     Running
```

### Lab 9.2: Configure Controller Sharding

```bash
# For 3 controller replicas
kubectl set env statefulset/argocd-application-controller \
  ARGOCD_CONTROLLER_REPLICAS=3 \
  -n argocd

# Scale the StatefulSet
kubectl scale statefulset argocd-application-controller --replicas=3 -n argocd

# Verify sharding
kubectl logs argocd-application-controller-0 -n argocd | grep shard
```

### Lab 9.3: Performance Tuning

```yaml
# argocd-cmd-params-cm ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cmd-params-cm
  namespace: argocd
data:
  # Controller settings
  controller.status.processors: "50"
  controller.operation.processors: "25"
  controller.self.heal.timeout.seconds: "5"

  # Repo server settings
  reposerver.parallelism.limit: "5"

  # Server settings
  server.grpc.max.message.size: "209715200"  # 200MB
```

```bash
kubectl apply -f argocd-cmd-params-cm.yaml

# Restart components to pick up changes
kubectl rollout restart deployment argocd-server -n argocd
kubectl rollout restart deployment argocd-repo-server -n argocd
kubectl rollout restart statefulset argocd-application-controller -n argocd
```

### Lab 9.4: Backup and Restore

```bash
# Create backup
kubectl get applications,appprojects -n argocd -o yaml > argocd-backup-$(date +%Y%m%d).yaml

# Verify backup
cat argocd-backup-*.yaml | grep "kind: Application" | wc -l

# Simulate disaster - delete an application
argocd app delete guestbook --cascade=false -y

# Restore
kubectl apply -f argocd-backup-*.yaml

# Verify restoration
argocd app list
```

### Lab 9.5: Simulate Upgrade

```bash
# Check current version
argocd version

# Backup before upgrade
kubectl get applications,appprojects,secrets,configmaps -n argocd -o yaml > pre-upgrade-backup.yaml

# Apply new version (example)
# kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.10.0/manifests/ha/install.yaml

# Watch rollout
kubectl rollout status deployment/argocd-server -n argocd
kubectl rollout status deployment/argocd-repo-server -n argocd

# Verify new version
argocd version
```

**Knowledge Check Questions:**
1. How many nodes minimum are required for HA installation?
2. What happens to applications if Redis loses all data?
3. When should you use controller sharding?

## Common Mistakes

1. **Skipping backup before upgrade** - No rollback path
2. **Not reading release notes** - Missing breaking changes
3. **Upgrading without testing** - Issues hit production first
4. **Wrong shard count** - Must match ARGOCD_CONTROLLER_REPLICAS

---

# Phase 10: Advanced Patterns & Integration

**Goal:** Master real-world deployment patterns.

## Concepts

### App of Apps Pattern

Manage multiple applications with a parent application:

**`apps-root/`**

- `Chart.yaml`
- `values.yaml`
- `templates/`
  - `team-a-apps.yaml`
  - `team-b-apps.yaml`
  - `platform-apps.yaml`


```yaml
# apps-root/templates/team-a-apps.yaml
{{- range .Values.teamA.apps }}
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: {{ .name }}
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: team-a
  source:
    repoURL: {{ $.Values.repoURL }}
    targetRevision: {{ $.Values.targetRevision }}
    path: {{ .path }}
  destination:
    server: https://kubernetes.default.svc
    namespace: {{ .namespace }}
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
{{- end }}
```

```yaml
# apps-root/values.yaml
repoURL: https://github.com/myorg/gitops.git
targetRevision: main

teamA:
  apps:
    - name: frontend
      path: apps/frontend
      namespace: team-a
    - name: backend
      path: apps/backend
      namespace: team-a
```

### Cluster Bootstrapping

Use Argo CD to bootstrap new clusters:

```yaml
# bootstrap/applicationset.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: cluster-bootstrap
  namespace: argocd
spec:
  generators:
    - clusters:
        selector:
          matchLabels:
            bootstrap: "true"
  template:
    metadata:
      name: 'bootstrap-{{.name}}'
    spec:
      project: platform
      source:
        repoURL: https://github.com/myorg/cluster-bootstrap.git
        targetRevision: HEAD
        path: bootstrap
      destination:
        server: '{{.server}}'
        namespace: argocd
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
```

The bootstrap app can install:
- Ingress controllers
- Cert-manager
- Monitoring stack
- Other platform components

### CI/CD Integration

**GitHub Actions example:**

```yaml
# .github/workflows/deploy.yaml
name: Deploy
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Update image tag
        run: |
          cd apps/my-app/overlays/prod
          kustomize edit set image myapp=${{ github.sha }}

      - name: Commit and push
        run: |
          git config user.name github-actions
          git config user.email github-actions@github.com
          git add .
          git commit -m "Deploy ${{ github.sha }}"
          git push

      - name: Wait for sync
        run: |
          argocd app wait my-app --health --timeout 300
```

**ArgoCD Image Updater:**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  annotations:
    argocd-image-updater.argoproj.io/image-list: myapp=myregistry/myapp
    argocd-image-updater.argoproj.io/myapp.update-strategy: semver
    argocd-image-updater.argoproj.io/write-back-method: git
```

### Progressive Delivery with Argo Rollouts

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: my-app
spec:
  replicas: 5
  strategy:
    canary:
      steps:
        - setWeight: 20
        - pause: {duration: 1h}
        - setWeight: 40
        - pause: {duration: 1h}
        - setWeight: 60
        - pause: {duration: 1h}
        - setWeight: 80
        - pause: {duration: 1h}
```

### Multi-Cluster Patterns

**Hub and Spoke:**
<!-- figure: generated from the Mermaid below by _shared/diagrams/embed-figures.py — do not edit the image -->
![Multi-Cluster Patterns — diagram](../../../../_figures/curriculum-_reference-cicd-gitops-argocd-ARGOCD_MASTERY_ROADMAP-3-ec18dd9b.png)

<details>
<summary>Diagram source (Mermaid)</summary>

```mermaid
%%{init: {'theme':'base','themeVariables':{'fontFamily':'Helvetica, Arial, sans-serif','fontSize':'13px','primaryColor':'#ffffff','primaryTextColor':'#2d3436','primaryBorderColor':'#9aa3ab','lineColor':'#9aa3ab','textColor':'#2d3436','clusterBkg':'#fbfcfd','clusterBorder':'#d4dae0','edgeLabelBackground':'#ffffff','tertiaryColor':'#eef4fb'},'flowchart':{'curve':'basis','padding':14,'nodeSpacing':42,'rankSpacing':58}}}%%
flowchart TB
  classDef default fill:#ffffff,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef n    fill:#ffffff,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef crit fill:#eef4fb,stroke:#2f6fb8,stroke-width:1.8px,color:#1b3a5c
  classDef data fill:#f4f7fa,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef mut  fill:#ffffff,stroke:#cfd6dc,stroke-width:1.1px,color:#7a8288
  classDef warn fill:#fdf0ec,stroke:#c0522d,stroke-width:1.6px,color:#8a3a1e
  M["Management cluster<br/><small>Argo CD lives here only</small>"]:::crit
  DEV["Dev cluster"]:::n
  PRD["Prod cluster"]:::n

  M -->|"applies to"| DEV
  M -->|"applies to"| PRD

  linkStyle 0,1 stroke:#2f6fb8,stroke-width:2px
```

</details>

**Federated:**
<!-- figure: generated from the Mermaid below by _shared/diagrams/embed-figures.py — do not edit the image -->
![Multi-Cluster Patterns — diagram](../../../../_figures/curriculum-_reference-cicd-gitops-argocd-ARGOCD_MASTERY_ROADMAP-4-2350f865.png)

<details>
<summary>Diagram source (Mermaid)</summary>

```mermaid
%%{init: {'theme':'base','themeVariables':{'fontFamily':'Helvetica, Arial, sans-serif','fontSize':'13px','primaryColor':'#ffffff','primaryTextColor':'#2d3436','primaryBorderColor':'#9aa3ab','lineColor':'#9aa3ab','textColor':'#2d3436','clusterBkg':'#fbfcfd','clusterBorder':'#d4dae0','edgeLabelBackground':'#ffffff','tertiaryColor':'#eef4fb'},'flowchart':{'curve':'basis','padding':14,'nodeSpacing':42,'rankSpacing':58}}}%%
flowchart LR
  classDef default fill:#ffffff,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef n    fill:#ffffff,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef crit fill:#eef4fb,stroke:#2f6fb8,stroke-width:1.8px,color:#1b3a5c
  classDef data fill:#f4f7fa,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef mut  fill:#ffffff,stroke:#cfd6dc,stroke-width:1.1px,color:#7a8288
  classDef warn fill:#fdf0ec,stroke:#c0522d,stroke-width:1.6px,color:#8a3a1e
  A2["Region A<br/><small>Argo CD + workloads</small>"]:::crit
  B2["Region B<br/><small>Argo CD + workloads</small>"]:::crit

  A2 -->|"each region self-manages;<br/>Git is the shared source of truth"| B2

  linkStyle 0 stroke:#2f6fb8,stroke-width:2px
```

</details>

## Labs

### Lab 10.1: Implement App of Apps

```bash
mkdir -p apps-root/templates
```

```yaml
# apps-root/Chart.yaml
apiVersion: v2
name: apps-root
version: 1.0.0
```

```yaml
# apps-root/values.yaml
repoURL: https://github.com/YOUR_USERNAME/argocd-learning.git
targetRevision: HEAD

applications:
  - name: guestbook
    path: apps/guestbook
    namespace: guestbook
  - name: nginx
    path: apps/plain-manifests
    namespace: nginx-app
```

```yaml
# apps-root/templates/applications.yaml
{{- range .Values.applications }}
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: {{ .name }}
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: {{ $.Values.repoURL }}
    targetRevision: {{ $.Values.targetRevision }}
    path: {{ .path }}
  destination:
    server: https://kubernetes.default.svc
    namespace: {{ .namespace }}
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
{{- end }}
```

```yaml
# Create the root application
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: apps-root
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/YOUR_USERNAME/argocd-learning.git
    targetRevision: HEAD
    path: apps-root
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

```bash
git add .
git commit -m "Add app of apps"
git push

kubectl apply -f apps-root-app.yaml
argocd app sync apps-root
```

### Lab 10.2: Register External Cluster

```bash
# Add a second kind cluster
kind create cluster --name argocd-target

# Get the kubeconfig context
kubectl config get-contexts

# Register with Argo CD (from management cluster context)
kubectl config use-context kind-argocd-lab
argocd cluster add kind-argocd-target

# Verify
argocd cluster list
```

### Lab 10.3: Deploy to Multiple Clusters

```yaml
# applicationsets/multi-cluster.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: multi-cluster-app
  namespace: argocd
spec:
  generators:
    - clusters: {}  # All registered clusters
  template:
    metadata:
      name: 'nginx-{{.name}}'
    spec:
      project: default
      source:
        repoURL: https://charts.bitnami.com/bitnami
        chart: nginx
        targetRevision: 15.0.0
      destination:
        server: '{{.server}}'
        namespace: nginx-multi
      syncPolicy:
        automated:
          prune: true
        syncOptions:
          - CreateNamespace=true
```

### Lab 10.4: CI/CD Integration Simulation

```bash
# Simulate CI updating image tag
cd apps/plain-manifests

# Update deployment image
sed -i '' 's/nginx:1.25/nginx:1.26/' deployment.yaml

git add .
git commit -m "Update nginx to 1.26"
git push

# Watch Argo CD detect the change
argocd app get plain-manifests-demo --refresh
argocd app sync plain-manifests-demo
```

### Lab 10.5: Deep Links and UI Extensions

```yaml
# argocd-cm ConfigMap
data:
  # Deep links to external systems
  resource.links: |
    - url: https://grafana.example.com/d/dashboard?var-namespace={{.metadata.namespace}}&var-pod={{.metadata.name}}
      title: Grafana Dashboard
      icon.class: "fa fa-chart-line"
      if: kind == "Pod"
    - url: https://logs.example.com/search?query=kubernetes.namespace:{{.metadata.namespace}}
      title: View Logs
      icon.class: "fa fa-file-alt"
```

**Knowledge Check Questions:**
1. What's the benefit of app-of-apps over ApplicationSets?
2. How do you prevent the root app from being deleted?
3. What's the difference between hub-spoke and federated multi-cluster?

## Common Mistakes

1. **Missing finalizers** - Child apps orphaned when parent deleted
2. **Circular dependencies** - App-of-apps includes itself
3. **Cluster credentials expiring** - ServiceAccount tokens need refresh
4. **Not testing multi-cluster** - Works in dev, fails in prod clusters

---

# Capstone Project

**Goal:** Build a production-ready multi-team GitOps platform.

## Requirements

Build a complete GitOps platform that includes:

### Platform Infrastructure
- [ ] HA Argo CD installation
- [ ] Prometheus monitoring with alerts
- [ ] Slack notifications for deployments and failures
- [ ] Git webhooks for immediate sync

### Multi-Tenancy
- [ ] 3 team projects (frontend, backend, data)
- [ ] RBAC policies for each team
- [ ] Resource restrictions per project
- [ ] Sync windows for production

### Application Patterns
- [ ] App-of-apps for platform components
- [ ] ApplicationSet for team applications
- [ ] Kustomize overlays (dev/staging/prod)
- [ ] Helm charts with external values

### Advanced Features
- [ ] Custom health checks for CRDs
- [ ] Ignore differences for HPA-managed replicas
- [ ] PreSync hooks for migrations
- [ ] Progressive sync across environments

### Documentation
- [ ] Architecture diagram
- [ ] Onboarding guide for new teams
- [ ] Runbook for common issues

## Suggested Structure

**`gitops-platform/`**

- `README.md`
- `docs/`
  - `architecture.md`
  - `onboarding.md`
  - `runbook.md`
- `platform/`
  - `argocd/` — Argo CD installation
  - `monitoring/` — Prometheus, Grafana
  - `bootstrap/` — Cluster bootstrap app
- `projects/`
  - `team-frontend.yaml`
  - `team-backend.yaml`
  - `team-data.yaml`
- `applicationsets/`
  - `team-frontend.yaml`
  - `team-backend.yaml`
  - `team-data.yaml`
- `apps/`
  - `frontend/`
    - `base/`
    - `overlays/`
  - `backend/`
    - `base/`
    - `overlays/`
  - `data/`
    - `base/`
    - `overlays/`


## Acceptance Criteria

1. **Verify HA:** Kill an argocd-server pod and confirm zero downtime
2. **Verify Isolation:** Team A cannot deploy to Team B's namespace
3. **Verify Auto-sync:** Push a change and watch it deploy automatically
4. **Verify Alerting:** Cause a sync failure and receive Slack notification
5. **Verify Progressive Sync:** Changes deploy to dev → staging → prod

---

# Quick Reference

## Essential Commands

```bash
# Application management
argocd app list
argocd app get <app-name>
argocd app sync <app-name>
argocd app diff <app-name>
argocd app delete <app-name>

# Refresh/Sync
argocd app get <app-name> --refresh
argocd app get <app-name> --hard-refresh
argocd app sync <app-name> --prune
argocd app sync <app-name> --force

# History/Rollback
argocd app history <app-name>
argocd app rollback <app-name> <history-id>

# Cluster management
argocd cluster list
argocd cluster add <context-name>
argocd cluster rm <server-url>

# Repository management
argocd repo list
argocd repo add <repo-url>
argocd repo rm <repo-url>

# Project management
argocd proj list
argocd proj get <project-name>
argocd proj create <project-name>

# Account management
argocd account list
argocd account update-password
```

## Common Annotations

```yaml
# Sync options
argocd.argoproj.io/sync-options: Prune=false
argocd.argoproj.io/sync-options: Delete=false
argocd.argoproj.io/sync-options: Replace=true

# Sync waves
argocd.argoproj.io/sync-wave: "-1"

# Hooks
argocd.argoproj.io/hook: PreSync
argocd.argoproj.io/hook: PostSync
argocd.argoproj.io/hook: SyncFail
argocd.argoproj.io/hook-delete-policy: HookSucceeded
argocd.argoproj.io/hook-delete-policy: BeforeHookCreation

# Notifications
notifications.argoproj.io/subscribe.on-sync-succeeded.slack: my-channel
notifications.argoproj.io/subscribe.on-sync-failed.slack: alerts

# Monorepo optimization
argocd.argoproj.io/manifest-generate-paths: /path/to/app
```

## Troubleshooting Checklist

1. **App stuck OutOfSync**
   - Check `argocd app diff <app>` for differences
   - Look for `ignoreDifferences` opportunities
   - Verify repository access

2. **App stuck Progressing**
   - Check pod events: `kubectl describe pod <pod>`
   - Verify image exists and is pullable
   - Check resource requests vs node capacity

3. **App Degraded**
   - Check pod logs: `kubectl logs <pod>`
   - Verify ConfigMaps/Secrets exist
   - Check service endpoints

4. **Sync Failed**
   - Check sync operation message in UI
   - Verify RBAC permissions
   - Check for resource conflicts

5. **Webhook not triggering**
   - Verify webhook secret matches
   - Check argocd-server logs
   - Confirm network connectivity

---

**Congratulations!** You now have a complete roadmap to becoming an elite Argo CD engineer. Work through each phase methodically, complete all labs, and build the capstone project to cement your knowledge.

Remember: The best way to learn is by doing. Set up a lab cluster and practice each concept hands-on.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Suggested Structure
- Essential Commands
- Common Annotations
- Troubleshooting Checklist

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
