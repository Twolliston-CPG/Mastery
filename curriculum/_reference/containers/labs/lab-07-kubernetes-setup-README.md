# Lab 07: Kubernetes Setup

## Objectives

- Set up a local Kubernetes cluster
- Understand kubectl basics
- Deploy your first application
- Explore cluster components

## Prerequisites

- Completed Docker labs (01-06)
- 4GB+ RAM available
- Basic understanding of containers

---

## Part 1: Cluster Installation (Guided)

### Option A: Minikube

```bash
# Install minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Start cluster
minikube start --driver=docker --cpus=2 --memory=4096

# Verify
minikube status

# Enable addons
minikube addons enable metrics-server
minikube addons enable ingress
minikube addons enable dashboard
```

### Option B: kind (Kubernetes in Docker)

```bash
# Install kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Create cluster
kind create cluster --name dev-cluster

# Verify
kubectl cluster-info
```

### Option C: k3s (Lightweight)

```bash
# Install k3s
curl -sfL https://get.k3s.io | sh -

# Configure kubectl
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER ~/.kube/config

# Verify
kubectl get nodes
```

### Step 2: Install kubectl

```bash
# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Configure autocompletion
echo 'source <(kubectl completion bash)' >> ~/.bashrc
echo 'alias k=kubectl' >> ~/.bashrc
echo 'complete -o default -F __start_kubectl k' >> ~/.bashrc
source ~/.bashrc

# Verify
kubectl version
```

### Step 3: Explore the Cluster

```bash
# Cluster info
kubectl cluster-info

# List nodes
kubectl get nodes
kubectl describe node <node-name>

# List namespaces
kubectl get namespaces

# List all resources in kube-system
kubectl get all -n kube-system
```

### Validation

```bash
#!/bin/bash
# validate-part1.sh

echo "=== Part 1 Validation ==="

# Check kubectl
if command -v kubectl &> /dev/null; then
    echo "✓ kubectl installed"
else
    echo "✗ kubectl not installed"
    exit 1
fi

# Check cluster access
if kubectl cluster-info &> /dev/null; then
    echo "✓ Cluster accessible"
else
    echo "✗ Cannot access cluster"
    exit 1
fi

# Check nodes ready
READY_NODES=$(kubectl get nodes --no-headers | grep "Ready" | wc -l)
if [ "$READY_NODES" -gt 0 ]; then
    echo "✓ $READY_NODES node(s) ready"
else
    echo "✗ No ready nodes"
    exit 1
fi

# Check kube-system pods
RUNNING_PODS=$(kubectl get pods -n kube-system --no-headers | grep "Running" | wc -l)
echo "  System pods running: $RUNNING_PODS"

echo "Part 1 validation complete!"
```

---

## Part 2: First Deployment (Semi-Guided)

### Objective

Deploy your first application to Kubernetes.

### Tasks

1. Deploy nginx using kubectl run
2. Expose the deployment as a service
3. Access the application
4. Clean up resources

### Imperative Commands

```bash
# Create deployment
kubectl create deployment nginx --image=nginx:alpine

# View deployment
kubectl get deployments
kubectl get pods
kubectl describe deployment nginx

# Expose as service
kubectl expose deployment nginx --port=80 --type=NodePort

# Get service details
kubectl get services
kubectl describe service nginx

# Access application
# For minikube:
minikube service nginx --url

# For kind/k3s:
kubectl port-forward svc/nginx 8080:80

# Scale deployment
kubectl scale deployment nginx --replicas=3

# View pods
kubectl get pods -o wide

# Cleanup
kubectl delete service nginx
kubectl delete deployment nginx
```

### Declarative Approach

```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  labels:
    app: nginx
spec:
  replicas: 3
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
        image: nginx:alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx
spec:
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
  type: NodePort
```

```bash
# Apply configuration
kubectl apply -f deployment.yaml

# View resources
kubectl get all -l app=nginx

# Delete resources
kubectl delete -f deployment.yaml
```

### Validation

```bash
#!/bin/bash
# validate-part2.sh

echo "=== Part 2 Validation ==="

# Create deployment
kubectl create deployment test-nginx --image=nginx:alpine
sleep 10

# Check deployment
if kubectl get deployment test-nginx &> /dev/null; then
    echo "✓ Deployment created"
else
    echo "✗ Deployment not found"
fi

# Check pod running
POD_STATUS=$(kubectl get pods -l app=test-nginx -o jsonpath='{.items[0].status.phase}')
if [ "$POD_STATUS" = "Running" ]; then
    echo "✓ Pod running"
else
    echo "✗ Pod not running: $POD_STATUS"
fi

# Expose and test
kubectl expose deployment test-nginx --port=80 --type=NodePort
sleep 5

# Port forward and test
kubectl port-forward svc/test-nginx 8888:80 &
PF_PID=$!
sleep 3

if curl -s http://localhost:8888 | grep -q "nginx"; then
    echo "✓ Application accessible"
else
    echo "✗ Application not accessible"
fi

kill $PF_PID 2>/dev/null

# Cleanup
kubectl delete svc test-nginx
kubectl delete deployment test-nginx

echo "Part 2 validation complete!"
```

---

## Part 3: kubectl Deep Dive (Semi-Guided)

### Objective

Master essential kubectl commands.

### Resource Management

```bash
# Get resources with different output formats
kubectl get pods -o wide
kubectl get pods -o yaml
kubectl get pods -o json
kubectl get pods -o jsonpath='{.items[*].metadata.name}'

# Labels and selectors
kubectl get pods -l app=nginx
kubectl get pods --selector='app=nginx,tier=frontend'
kubectl label pod <pod-name> env=production

# Annotations
kubectl annotate deployment nginx description="My nginx deployment"

# Resource filtering
kubectl get pods --field-selector status.phase=Running
kubectl get pods --sort-by=.metadata.creationTimestamp
```

### Debugging Commands

```bash
# Describe (detailed info)
kubectl describe pod <pod-name>

# Logs
kubectl logs <pod-name>
kubectl logs <pod-name> -c <container-name>
kubectl logs -f <pod-name>  # Follow
kubectl logs --previous <pod-name>  # Previous instance

# Exec into pod
kubectl exec -it <pod-name> -- /bin/sh

# Port forward
kubectl port-forward pod/<pod-name> 8080:80
kubectl port-forward svc/<svc-name> 8080:80

# Copy files
kubectl cp <pod-name>:/path/file ./local-file
kubectl cp ./local-file <pod-name>:/path/file
```

### Context and Namespace

```bash
# View contexts
kubectl config get-contexts
kubectl config current-context

# Switch context
kubectl config use-context <context-name>

# Set default namespace
kubectl config set-context --current --namespace=<namespace>

# Create namespace
kubectl create namespace dev
kubectl get namespaces

# Run in specific namespace
kubectl get pods -n kube-system
kubectl get pods --all-namespaces
```

### Validation

```bash
#!/bin/bash
# validate-part3.sh

echo "=== Part 3 Validation ==="

# Test namespace creation
kubectl create namespace test-ns
if kubectl get namespace test-ns &> /dev/null; then
    echo "✓ Namespace creation works"
else
    echo "✗ Namespace creation failed"
fi

# Test deployment in namespace
kubectl create deployment test-app --image=nginx:alpine -n test-ns
sleep 10

# Test label selector
kubectl label deployment test-app env=test -n test-ns
LABELED=$(kubectl get deployment -n test-ns -l env=test -o name | wc -l)
if [ "$LABELED" -gt 0 ]; then
    echo "✓ Label selector works"
else
    echo "✗ Label selector failed"
fi

# Test log access
POD=$(kubectl get pods -n test-ns -o name | head -1)
if kubectl logs $POD -n test-ns &> /dev/null; then
    echo "✓ Log access works"
else
    echo "✗ Log access failed"
fi

# Cleanup
kubectl delete namespace test-ns

echo "Part 3 validation complete!"
```

---

## Part 4: Challenge - Complete Cluster Setup

### Objective

Set up a production-like Kubernetes cluster with essential components.

### Requirements

1. **Cluster Setup:**
   - Multi-node cluster (1 control plane + 2 workers) using kind
   - Ingress controller installed
   - Metrics server enabled

2. **Namespaces:**
   - dev
   - staging
   - production

3. **RBAC:**
   - Service account for CI/CD
   - Limited permissions in each namespace

4. **Deploy Application:**
   - nginx deployment in each namespace
   - Different replica counts per namespace

### Kind Multi-Node Configuration

```yaml
# kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
- role: worker
- role: worker
```

```bash
# Create cluster
kind create cluster --config kind-config.yaml --name prod-cluster
```

### Ingress Controller

```bash
# Install nginx ingress controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Wait for it to be ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s
```

### Validation Script

```bash
#!/bin/bash
# validate-challenge.sh

echo "=== Challenge Validation ==="

# Check nodes
NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
if [ "$NODE_COUNT" -ge 3 ]; then
    echo "✓ Multi-node cluster: $NODE_COUNT nodes"
else
    echo "✗ Expected 3+ nodes, got $NODE_COUNT"
fi

# Check ingress controller
if kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller | grep -q Running; then
    echo "✓ Ingress controller running"
else
    echo "✗ Ingress controller not running"
fi

# Check namespaces
for NS in dev staging production; do
    if kubectl get namespace $NS &> /dev/null; then
        echo "✓ Namespace $NS exists"
    else
        echo "✗ Namespace $NS not found"
    fi
done

# Check deployments in namespaces
for NS in dev staging production; do
    PODS=$(kubectl get pods -n $NS --no-headers 2>/dev/null | wc -l)
    echo "  Pods in $NS: $PODS"
done

# Check service account
if kubectl get serviceaccount ci-sa -n default &> /dev/null; then
    echo "✓ CI/CD service account exists"
else
    echo "✗ CI/CD service account not found"
fi

echo ""
echo "Challenge validation complete!"
```

---

## Deliverables

1. Working multi-node Kubernetes cluster
2. Ingress controller configured
3. Namespaces created and configured
4. Service account with appropriate RBAC
5. Deployed applications in each namespace

## kubectl Cheat Sheet

```bash
# Cluster
kubectl cluster-info
kubectl get nodes

# Workloads
kubectl create deployment <name> --image=<image>
kubectl scale deployment <name> --replicas=<n>
kubectl rollout status deployment <name>

# Services
kubectl expose deployment <name> --port=<port>
kubectl get services

# Debugging
kubectl describe <resource> <name>
kubectl logs <pod>
kubectl exec -it <pod> -- /bin/sh

# Configuration
kubectl apply -f <file>
kubectl delete -f <file>
kubectl get all

# Context
kubectl config get-contexts
kubectl config use-context <context>
```

## Resources

- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [Minikube Documentation](https://minikube.sigs.k8s.io/docs/)
- [kind Documentation](https://kind.sigs.k8s.io/)

## Next Lab

Continue to [Lab 08: Deployments](lab-08-deployments-README.md)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Cluster Installation
- First Deployment
- kubectl Deep Dive
- Challenge - Complete Cluster Setup

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"A container isolates the application."* |
| ✓ | *"A container is an ordinary Linux process started with namespaces (what it can see), cgroups (what it can use) and usually seccomp (what it may ask the kernel). There is no container object in the kernel — only a process with those features switched on."* |

**Trace it:** `docker run` → an isolated process. Name the namespaces in the order they are created, and which component actually calls `clone()`.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** the [LWN namespaces series](https://lwn.net/Articles/531114/) — seven parts by the man-pages maintainer, and the reason containers stop being magic.
Full list per domain: [`SOURCES.md`](../../SOURCES.md#containers)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../../MASTERY.md)

<!-- /feynman-check -->
