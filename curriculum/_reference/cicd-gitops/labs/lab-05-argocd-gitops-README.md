# Lab 05: ArgoCD and GitOps

## Overview

In this lab, you'll implement GitOps using ArgoCD to deploy applications to Kubernetes. You'll learn declarative deployment management, automated synchronization, and multi-environment deployments.

**Duration**: 3-4 hours
**Difficulty**: Intermediate to Advanced

## Prerequisites

- Kubernetes cluster (minikube, kind, or cloud)
- kubectl configured
- Helm 3.x installed
- Git repository access
- Basic Kubernetes knowledge

## Learning Objectives

- Install and configure ArgoCD
- Create and manage ArgoCD Applications
- Implement GitOps workflow
- Configure auto-sync and self-healing
- Set up multi-environment deployments
- Implement progressive delivery with ArgoCD

## Lab Environment Setup

```bash
# Create lab directory
mkdir -p ~/argocd-lab && cd ~/argocd-lab

# Start minikube if using local cluster
minikube start --memory=4096 --cpus=2

# Verify cluster access
kubectl cluster-info
```

---

## Part 1: Guided Exercise - ArgoCD Installation and Basic Application

### Step 1: Install ArgoCD

```bash
# Create namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for pods to be ready
kubectl wait --for=condition=available --timeout=300s \
  deployment/argocd-server -n argocd

# Get initial admin password
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)
echo "ArgoCD admin password: $ARGOCD_PASSWORD"

# Port forward to access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443 &

echo "ArgoCD UI available at: https://localhost:8080"
echo "Username: admin"
echo "Password: $ARGOCD_PASSWORD"
```

### Step 2: Install ArgoCD CLI

```bash
# macOS
brew install argocd

# Linux
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64

# Login to ArgoCD
argocd login localhost:8080 --username admin --password $ARGOCD_PASSWORD --insecure
```

### Step 3: Create Application Manifests Repository

```bash
# Create Git repository structure
mkdir -p app-manifests/{base,overlays/{dev,staging,prod}}

# Create base deployment
cat > app-manifests/base/deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: demo-app
  template:
    metadata:
      labels:
        app: demo-app
    spec:
      containers:
        - name: demo-app
          image: nginx:1.25
          ports:
            - containerPort: 80
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 200m
              memory: 256Mi
          readinessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 5
            periodSeconds: 5
EOF

# Create base service
cat > app-manifests/base/service.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: demo-app
spec:
  selector:
    app: demo-app
  ports:
    - port: 80
      targetPort: 80
EOF

# Create base kustomization
cat > app-manifests/base/kustomization.yaml << 'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment.yaml
  - service.yaml

commonLabels:
  managed-by: argocd
EOF

# Create dev overlay
cat > app-manifests/overlays/dev/kustomization.yaml << 'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: dev

resources:
  - ../../base
  - namespace.yaml

namePrefix: dev-

patches:
  - patch: |-
      - op: replace
        path: /spec/replicas
        value: 1
    target:
      kind: Deployment
      name: demo-app
EOF

cat > app-manifests/overlays/dev/namespace.yaml << 'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: dev
EOF

# Create staging overlay
cat > app-manifests/overlays/staging/kustomization.yaml << 'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: staging

resources:
  - ../../base
  - namespace.yaml

namePrefix: staging-

patches:
  - patch: |-
      - op: replace
        path: /spec/replicas
        value: 2
    target:
      kind: Deployment
      name: demo-app
EOF

cat > app-manifests/overlays/staging/namespace.yaml << 'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: staging
EOF

# Create prod overlay
cat > app-manifests/overlays/prod/kustomization.yaml << 'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: production

resources:
  - ../../base
  - namespace.yaml

namePrefix: prod-

patches:
  - patch: |-
      - op: replace
        path: /spec/replicas
        value: 3
    target:
      kind: Deployment
      name: demo-app
EOF

cat > app-manifests/overlays/prod/namespace.yaml << 'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: production
EOF

# Initialize Git repo
cd app-manifests
git init
git add .
git commit -m "Initial application manifests"
```

### Step 4: Create ArgoCD Application

```bash
# Create ArgoCD Application manifest
cat > ~/argocd-lab/demo-app-dev.yaml << 'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: demo-app-dev
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default

  source:
    repoURL: https://github.com/YOUR_USERNAME/app-manifests.git
    targetRevision: HEAD
    path: overlays/dev

  destination:
    server: https://kubernetes.default.svc
    namespace: dev

  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF

# For local testing, use a local path
# First, start a local Git server or use the ArgoCD repo server

# Apply the application (using CLI for local testing)
argocd app create demo-app-dev \
  --repo https://github.com/YOUR_USERNAME/app-manifests.git \
  --path overlays/dev \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace dev \
  --sync-policy automated \
  --auto-prune \
  --self-heal

# Or apply from manifest
kubectl apply -f demo-app-dev.yaml
```

### Step 5: Sync and Verify Application

```bash
# Sync the application
argocd app sync demo-app-dev

# Check sync status
argocd app get demo-app-dev

# Watch the sync progress
argocd app wait demo-app-dev --sync

# Verify deployment
kubectl get pods -n dev
kubectl get svc -n dev

# Test the application
kubectl port-forward svc/dev-demo-app -n dev 8081:80 &
curl http://localhost:8081
```

---

## Part 2: Semi-Guided Exercise - Multi-Environment Setup

### Objective

Set up ArgoCD applications for staging and production environments with:
- Different sync policies per environment
- Manual approval for production
- Notification on sync events

### Requirements

1. **Create ApplicationSet for multiple environments**

<details>
<summary>Click for ApplicationSet hint</summary>

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: demo-app
  namespace: argocd
spec:
  generators:
    - list:
        elements:
          - env: dev
            autoSync: true
          - env: staging
            autoSync: true
          - env: prod
            autoSync: false
  template:
    metadata:
      name: 'demo-app-{{env}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/YOUR_USERNAME/app-manifests.git
        targetRevision: HEAD
        path: 'overlays/{{env}}'
      destination:
        server: https://kubernetes.default.svc
        namespace: '{{env}}'
      syncPolicy:
        # Conditional sync policy based on environment
```
</details>

2. **Configure sync windows for production**

<details>
<summary>Click for sync window hint</summary>

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: production
  namespace: argocd
spec:
  syncWindows:
    - kind: allow
      schedule: "0 10-18 * * 1-5"  # Weekdays 10am-6pm
      duration: 8h
      applications:
        - '*'
```
</details>

3. **Add health checks**

### Tasks

1. Create an ApplicationSet that deploys to all environments
2. Configure appropriate sync policies:
   - Dev: Auto-sync enabled
   - Staging: Auto-sync enabled with approval
   - Production: Manual sync only
3. Add Slack notifications for sync events
4. Implement sync windows for production

### Validation

```bash
# Verify all applications are created
argocd app list

# Check each environment
for env in dev staging production; do
  echo "=== $env ==="
  kubectl get pods -n $env
  kubectl get svc -n $env
done

# Test auto-sync by changing manifest
# Commit change to dev overlay
# Verify ArgoCD syncs automatically
```

---

## Part 3: Challenge - GitOps with Argo Rollouts

### Objective

Implement progressive delivery using Argo Rollouts with ArgoCD:
- Canary deployments
- Automated analysis
- Rollback on failure

### Requirements

1. **Install Argo Rollouts**

```bash
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
```

2. **Convert Deployment to Rollout**

3. **Configure canary strategy with analysis**

4. **Integrate with ArgoCD**

### Success Criteria

- [ ] Argo Rollouts installed and running
- [ ] Application uses Rollout instead of Deployment
- [ ] Canary strategy configured with 10%, 30%, 50%, 100% steps
- [ ] AnalysisTemplate checks HTTP success rate
- [ ] ArgoCD shows Rollout status
- [ ] Automatic rollback on failed analysis

### Starting Point

```yaml
# Convert this Deployment to a Rollout with canary strategy
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: demo-app
spec:
  replicas: 5
  strategy:
    canary:
      steps:
        - setWeight: 10
        - pause: { duration: 30s }
        - setWeight: 30
        - pause: { duration: 30s }
        - setWeight: 50
        - pause: { duration: 30s }
      # Add analysis template
      # Add traffic routing
  selector:
    matchLabels:
      app: demo-app
  template:
    # ... pod template
```

### Validation Script

```bash
#!/bin/bash
# validate-gitops.sh

echo "Validating GitOps Setup..."

# Check ArgoCD
if kubectl get deployment argocd-server -n argocd &>/dev/null; then
  echo "✓ ArgoCD installed"
else
  echo "✗ ArgoCD not found"
  exit 1
fi

# Check applications
APPS=$(argocd app list -o name | wc -l)
echo "✓ Found $APPS ArgoCD applications"

# Check Argo Rollouts
if kubectl get deployment argo-rollouts -n argo-rollouts &>/dev/null; then
  echo "✓ Argo Rollouts installed"
else
  echo "⚠ Argo Rollouts not installed (optional)"
fi

# Check sync status
SYNCED=$(argocd app list -o json | jq '[.[] | select(.status.sync.status == "Synced")] | length')
TOTAL=$(argocd app list -o json | jq '. | length')
echo "✓ $SYNCED/$TOTAL applications synced"

# Check health
HEALTHY=$(argocd app list -o json | jq '[.[] | select(.status.health.status == "Healthy")] | length')
echo "✓ $HEALTHY/$TOTAL applications healthy"

echo "Validation complete!"
```

---

## Cleanup

```bash
# Delete ArgoCD applications
argocd app delete demo-app-dev --cascade
argocd app delete demo-app-staging --cascade
argocd app delete demo-app-prod --cascade

# Delete ArgoCD
kubectl delete namespace argocd

# Delete Argo Rollouts
kubectl delete namespace argo-rollouts

# Delete application namespaces
kubectl delete namespace dev staging production

# Stop minikube
minikube stop

# Remove lab files
rm -rf ~/argocd-lab
```

## Summary

In this lab, you learned:
- Installing and configuring ArgoCD
- Creating and managing ArgoCD Applications
- Implementing GitOps workflow with automated sync
- Multi-environment deployment strategies
- Progressive delivery with Argo Rollouts

## Next Steps

- Explore ArgoCD ApplicationSets for dynamic application generation
- Implement ArgoCD Image Updater for container image automation
- Set up ArgoCD notifications for Slack/Teams integration
- Configure RBAC for multi-team ArgoCD usage

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Challenge - GitOps with Argo Rollouts
- Install ArgoCD
- Install ArgoCD CLI
- Create Application Manifests Repository

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
