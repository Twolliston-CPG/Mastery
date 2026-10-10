# Phase 0: Prerequisites

**Goal:** Set up your learning environment with a Kubernetes cluster and Argo CD installation.

**Duration:** ~30 minutes

---

## Overview

Before diving into Argo CD, you need:
1. A Kubernetes cluster (we'll use kind)
2. Argo CD installed on that cluster
3. CLI tools configured

## Prerequisites Checklist

### Required Tools

| Tool | Purpose | Install Command |
|------|---------|-----------------|
| `kubectl` | Kubernetes CLI | `brew install kubectl` |
| `kind` | Local Kubernetes clusters | `brew install kind` |
| `helm` | Package manager | `brew install helm` |
| `git` | Version control | `brew install git` |

### Optional but Recommended

| Tool | Purpose | Install Command |
|------|---------|-----------------|
| `argocd` | Argo CD CLI | `brew install argocd` |
| `k9s` | Kubernetes TUI | `brew install k9s` |

### Verify Installation

```bash
kubectl version --client
kind version
helm version
git version
argocd version --client  # Optional
```

---

## Lab 0.1: Create Your Lab Cluster

We use **kind** (Kubernetes in Docker) because it's:
- Fast to create/destroy
- Runs entirely locally
- Supports multiple clusters
- Good for learning and testing

### Step 1: Review the Cluster Configuration

```bash
cat kind-cluster-config.yaml
```

This configuration:
- Creates a single-node cluster named `argocd-lab`
- Exposes ports 30080 and 30443 for accessing services
- Configures the node for ingress support

### Step 2: Create the Cluster

```bash
./setup-cluster.sh
```

Or manually:

```bash
kind create cluster --config kind-cluster-config.yaml
```

### Step 3: Verify the Cluster

```bash
# Check cluster info
kubectl cluster-info --context kind-argocd-lab

# Check nodes
kubectl get nodes

# Check all pods are running
kubectl get pods -A
```

**Expected Output:**
```
NAME                           STATUS   ROLES           AGE   VERSION
argocd-lab-control-plane       Ready    control-plane   1m    v1.28.0
```

### Acceptance Criteria
- [ ] `kubectl get nodes` shows a Ready node
- [ ] You can create a test namespace: `kubectl create ns test && kubectl delete ns test`

---

## Lab 0.2: Install Argo CD

### Step 1: Run the Installation Script

```bash
./install-argocd.sh
```

Or manually:

```bash
# Create namespace
kubectl create namespace argocd

# Install Argo CD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for pods
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s
```

### Step 2: Get the Admin Password

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
echo  # Add newline for readability
```

**Save this password!** You'll need it to log in.

### Step 3: Access the UI

In a **separate terminal** (keep it running):

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Then open: https://localhost:8080

- **Username:** `admin`
- **Password:** (from Step 2)

Accept the self-signed certificate warning.

### Step 4: Configure the CLI (Optional but Recommended)

```bash
# Login to Argo CD
argocd login localhost:8080 --insecure --username admin --password '<your-password>'

# Update your password (recommended)
argocd account update-password

# Verify connection
argocd cluster list
```

### Acceptance Criteria
- [ ] All pods in `argocd` namespace are Running
- [ ] You can access the UI at https://localhost:8080
- [ ] You can log in with admin credentials
- [ ] (Optional) CLI is logged in: `argocd account get-user-info`

---

## Lab 0.3: Verify Everything

Run the verification script:

```bash
./verify-setup.sh
```

This checks:
- All required tools are installed
- Cluster is running
- Argo CD components are healthy
- CRDs are installed

**All checks should pass before proceeding to Phase 1.**

---

## Troubleshooting

### Cluster Won't Start

```bash
# Check Docker is running
docker info

# Delete and recreate
kind delete cluster --name argocd-lab
./setup-cluster.sh
```

### Pods Stuck in Pending

```bash
# Check events
kubectl get events -n argocd --sort-by='.lastTimestamp'

# Check node resources
kubectl describe node
```

### Can't Access UI

```bash
# Verify port-forward is running
# Check for errors in the terminal running port-forward

# Try a different port
kubectl port-forward svc/argocd-server -n argocd 9090:443
# Then access https://localhost:9090
```

### Forgot Password

```bash
# Get initial password again
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Or reset it
kubectl -n argocd patch secret argocd-secret \
  -p '{"stringData": {"admin.password": "'$(htpasswd -bnBC 10 "" newpassword | tr -d ':\n')'"}}'
```

---

## Files in This Directory

| File | Purpose |
|------|---------|
| `kind-cluster-config.yaml` | Kind cluster configuration |
| `setup-cluster.sh` | Creates the kind cluster |
| `install-argocd.sh` | Installs Argo CD |
| `verify-setup.sh` | Verifies everything is working |

---

## What's Next?

Once all verification checks pass, proceed to **Phase 1: Foundation & Architecture** to learn how Argo CD works under the hood.

```bash
cd ../phase-1-foundation
cat README.md
```

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Prerequisites Checklist
- 1: Create Your Lab Cluster
- 2: Install Argo CD
- 3: Verify Everything

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
