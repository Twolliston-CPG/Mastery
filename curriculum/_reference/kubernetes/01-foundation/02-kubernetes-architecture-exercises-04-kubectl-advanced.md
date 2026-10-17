# Exercise 4: kubectl Advanced Usage

## Objectives

- Master advanced kubectl commands
- Create effective aliases and functions
- Use plugins to extend kubectl
- Automate common tasks

## Prerequisites

- Completed previous exercises
- kubectl installed and configured
- Basic shell scripting knowledge

---

## Part 1: Advanced Output Formatting

### 1.1 JSONPath Mastery

```bash
# Basic JSONPath
kubectl get pods -o jsonpath='{.items[*].metadata.name}'

# With newlines
kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'

# Multiple fields with formatting
kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.phase}{"\t"}{.spec.nodeName}{"\n"}{end}'

# Conditional selection
kubectl get nodes -o jsonpath='{.items[?(@.status.conditions[?(@.type=="Ready")].status=="True")].metadata.name}'

# Array indices
kubectl get pod <pod-name> -o jsonpath='{.spec.containers[0].image}'

# Nested queries
kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{" - "}{.spec.containers[*].name}{"\n"}{end}'
```

### 1.2 Custom Columns

```bash
# Basic custom columns
kubectl get pods -o custom-columns=NAME:.metadata.name,STATUS:.status.phase

# Multiple columns with nested paths
kubectl get pods -o custom-columns=\
NAME:.metadata.name,\
NODE:.spec.nodeName,\
IP:.status.podIP,\
CONTAINERS:.spec.containers[*].name,\
IMAGES:.spec.containers[*].image

# Save as template file
cat <<'EOF' > /tmp/pod-columns.txt
NAME            NAMESPACE           STATUS          NODE            AGE
metadata.name   metadata.namespace  status.phase    spec.nodeName   metadata.creationTimestamp
EOF

kubectl get pods -A -o custom-columns-file=/tmp/pod-columns.txt
```

### 1.3 Go Templates

```bash
# Basic go template
kubectl get pods -o go-template='{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}'

# With conditionals
kubectl get pods -o go-template='{{range .items}}{{if eq .status.phase "Running"}}{{.metadata.name}}{{"\n"}}{{end}}{{end}}'

# Complex formatting
kubectl get nodes -o go-template='{{range .items}}{{.metadata.name}}{{"\t"}}{{range .status.conditions}}{{if eq .type "Ready"}}{{.status}}{{end}}{{end}}{{"\n"}}{{end}}'

# Template with functions
kubectl get pods -o go-template='{{range .items}}{{.metadata.name}} - Containers: {{len .spec.containers}}{{"\n"}}{{end}}'
```

---

## Part 2: Resource Management

### 2.1 Patch Operations

```bash
# Create test deployment
kubectl create deployment patch-test --image=nginx:1.25

# JSON Patch (RFC 6902)
kubectl patch deployment patch-test --type='json' -p='[
  {"op": "replace", "path": "/spec/replicas", "value": 3},
  {"op": "add", "path": "/spec/template/metadata/labels/version", "value": "v1"}
]'

# Merge Patch
kubectl patch deployment patch-test --type='merge' -p='{"spec":{"replicas":5}}'

# Strategic Merge Patch (default for Kubernetes)
kubectl patch deployment patch-test -p='{"spec":{"template":{"spec":{"containers":[{"name":"nginx","resources":{"limits":{"cpu":"500m","memory":"256Mi"}}}]}}}}'

# Patch from file
cat <<EOF > /tmp/patch.yaml
spec:
  replicas: 2
  template:
    spec:
      containers:
      - name: nginx
        image: nginx:1.26
EOF
kubectl patch deployment patch-test --patch-file=/tmp/patch.yaml

# Cleanup
kubectl delete deployment patch-test
```

### 2.2 Apply vs Create vs Replace

```bash
# Create - fails if resource exists
kubectl create deployment test --image=nginx:1.25

# Apply - creates or updates (declarative)
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: apply-test
spec:
  replicas: 2
  selector:
    matchLabels:
      app: apply-test
  template:
    metadata:
      labels:
        app: apply-test
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
EOF

# Replace - replaces entire resource
kubectl replace -f <file>

# Server-side apply (recommended)
kubectl apply -f <file> --server-side

# Force conflicts resolution
kubectl apply -f <file> --server-side --force-conflicts

# Cleanup
kubectl delete deployment apply-test test
```

### 2.3 Dry Run and Diff

```bash
# Client-side dry run
kubectl create deployment dry-test --image=nginx:1.25 --dry-run=client -o yaml

# Server-side dry run
kubectl create deployment dry-test --image=nginx:1.25 --dry-run=server -o yaml

# Diff before applying
cat <<EOF > /tmp/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: diff-test
spec:
  replicas: 3
  selector:
    matchLabels:
      app: diff-test
  template:
    metadata:
      labels:
        app: diff-test
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
EOF

kubectl apply -f /tmp/deployment.yaml
# Modify the file
sed -i '' 's/replicas: 3/replicas: 5/' /tmp/deployment.yaml
# See the diff
kubectl diff -f /tmp/deployment.yaml

# Cleanup
kubectl delete deployment diff-test
```

---

## Part 3: Context and Configuration

### 3.1 Multiple Clusters

```bash
# View all contexts
kubectl config get-contexts

# Current context
kubectl config current-context

# Switch context
kubectl config use-context <context-name>

# Set namespace for context
kubectl config set-context --current --namespace=default

# Create new context
kubectl config set-context my-context \
  --cluster=my-cluster \
  --user=my-user \
  --namespace=production
```

### 3.2 Kubeconfig Management

```bash
# View merged kubeconfig
kubectl config view

# View specific kubeconfig
kubectl config view --kubeconfig=/path/to/config

# Merge kubeconfigs
KUBECONFIG=~/.kube/config:/path/to/other/config kubectl config view --flatten > /tmp/merged-config

# Use specific kubeconfig
kubectl --kubeconfig=/path/to/config get pods

# Environment variable
export KUBECONFIG=~/.kube/config:/path/to/cluster2/config
```

### 3.3 Impersonation

```bash
# Impersonate user
kubectl get pods --as=jane

# Impersonate group
kubectl get pods --as=jane --as-group=developers

# Impersonate service account
kubectl get pods --as=system:serviceaccount:default:my-sa

# Check permissions as different user
kubectl auth can-i list pods --as=jane
kubectl auth can-i --list --as=system:serviceaccount:default:my-sa
```

---

## Part 4: Productive Aliases and Functions

### 4.1 Essential Aliases

```bash
# Add to ~/.bashrc or ~/.zshrc

# Basic aliases
alias k='kubectl'
alias kx='kubectl config use-context'
alias kn='kubectl config set-context --current --namespace'

# Get commands
alias kg='kubectl get'
alias kgp='kubectl get pods'
alias kgpa='kubectl get pods -A'
alias kgd='kubectl get deployments'
alias kgs='kubectl get services'
alias kgn='kubectl get nodes'
alias kgns='kubectl get namespaces'

# Describe
alias kd='kubectl describe'
alias kdp='kubectl describe pod'
alias kdd='kubectl describe deployment'

# Logs
alias kl='kubectl logs'
alias klf='kubectl logs -f'
alias klt='kubectl logs --tail=100'

# Exec
alias kex='kubectl exec -it'

# Apply/Delete
alias ka='kubectl apply -f'
alias kd='kubectl delete -f'

# Watch
alias kw='kubectl get pods -w'
alias kwa='kubectl get pods -A -w'

# Resource usage
alias kt='kubectl top'
alias ktp='kubectl top pods'
alias ktn='kubectl top nodes'
```

### 4.2 Useful Functions

```bash
# Add to ~/.bashrc or ~/.zshrc

# Quick exec into pod
kexec() {
  kubectl exec -it "$1" -- "${2:-/bin/sh}"
}

# Get pod logs with grep
klg() {
  kubectl logs "$1" | grep -i "$2"
}

# Delete all pods in namespace
kdelpods() {
  kubectl delete pods --all -n "${1:-default}"
}

# Get all resources in namespace
kall() {
  kubectl api-resources --verbs=list --namespaced -o name | xargs -n 1 kubectl get --show-kind --ignore-not-found -n "${1:-default}"
}

# Decode secret
ksecret() {
  kubectl get secret "$1" -o jsonpath="{.data.$2}" | base64 -d
}

# Watch events
kevents() {
  kubectl get events --sort-by=.lastTimestamp "${@}"
}

# Port forward with auto-naming
kpf() {
  local pod="$1"
  local ports="$2"
  echo "Port forwarding $pod on $ports"
  kubectl port-forward "$pod" "$ports"
}

# Get pod by partial name
kgpp() {
  kubectl get pods | grep "$1"
}

# Restart deployment
krestart() {
  kubectl rollout restart deployment "$1"
}
```

### 4.3 Context/Namespace Prompt

```bash
# For bash - add to ~/.bashrc
__kube_ps1() {
  local context=$(kubectl config current-context 2>/dev/null)
  local namespace=$(kubectl config view --minify -o jsonpath='{..namespace}' 2>/dev/null)
  [ -n "$context" ] && echo "(k8s: $context/${namespace:-default})"
}
PS1='$(__kube_ps1)\n\u@\h:\w\$ '

# Or use kube-ps1 for more features
# https://github.com/jonmosco/kube-ps1
```

---

## Part 5: kubectl Plugins

### 5.1 Using krew (Plugin Manager)

```bash
# Install krew
(
  set -x; cd "$(mktemp -d)" &&
  OS="$(uname | tr '[:upper:]' '[:lower:]')" &&
  ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/arm.*$/arm64/')" &&
  KREW="krew-${OS}_${ARCH}" &&
  curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" &&
  tar zxvf "${KREW}.tar.gz" &&
  ./"${KREW}" install krew
)

# Add to PATH
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

# Search plugins
kubectl krew search

# Install popular plugins
kubectl krew install ctx          # Context switching
kubectl krew install ns           # Namespace switching
kubectl krew install neat         # Clean up YAML output
kubectl krew install tree         # Show resource hierarchy
kubectl krew install images       # Show images in use
kubectl krew install pod-logs     # Multi-pod logs
kubectl krew install node-shell   # Shell into nodes
```

### 5.2 Popular Plugin Usage

```bash
# ctx - Context switching
kubectl ctx                    # List contexts
kubectl ctx my-context         # Switch context

# ns - Namespace switching
kubectl ns                     # List namespaces
kubectl ns production          # Switch namespace

# neat - Clean YAML output
kubectl get pod my-pod -o yaml | kubectl neat

# tree - Resource hierarchy
kubectl tree deployment my-deployment

# images - Container images
kubectl images -A

# node-shell - Debug nodes
kubectl node-shell my-node
```

### 5.3 Creating Custom Plugins

```bash
# kubectl plugins are just executables named kubectl-<name>
cat <<'EOF' > ~/bin/kubectl-podcount
#!/bin/bash
# kubectl-podcount - Count pods per namespace

echo "Pods per namespace:"
kubectl get pods -A --no-headers | awk '{print $1}' | sort | uniq -c | sort -rn
EOF

chmod +x ~/bin/kubectl-podcount

# Now use it
kubectl podcount
```

---

## Part 6: Hands-on Challenges

### Challenge 1: Resource Report Generator

```bash
#!/bin/bash
# kubectl-report - Generate cluster resource report

echo "=== Kubernetes Cluster Report ==="
echo "Generated: $(date)"
echo "Context: $(kubectl config current-context)"
echo ""

echo "=== Nodes ==="
kubectl get nodes -o custom-columns=\
NAME:.metadata.name,\
STATUS:.status.conditions[-1].status,\
VERSION:.status.nodeInfo.kubeletVersion,\
CPU:.status.allocatable.cpu,\
MEMORY:.status.allocatable.memory

echo ""
echo "=== Namespaces with Pod Count ==="
for ns in $(kubectl get ns -o name | cut -d/ -f2); do
  count=$(kubectl get pods -n $ns --no-headers 2>/dev/null | wc -l)
  printf "%-30s %d\n" "$ns" "$count"
done | sort -k2 -rn

echo ""
echo "=== Deployments Not Fully Available ==="
kubectl get deployments -A -o custom-columns=\
NAMESPACE:.metadata.namespace,\
NAME:.metadata.name,\
DESIRED:.spec.replicas,\
AVAILABLE:.status.availableReplicas 2>/dev/null | awk 'NR==1 || $3!=$4'

echo ""
echo "=== Recent Warning Events ==="
kubectl get events -A --field-selector=type=Warning --sort-by=.lastTimestamp | tail -10
```

### Challenge 2: Multi-Cluster Command

```bash
#!/bin/bash
# kubectl-multicluster - Run command across clusters

COMMAND="$@"

if [ -z "$COMMAND" ]; then
  echo "Usage: kubectl multicluster <command>"
  echo "Example: kubectl multicluster get pods -A"
  exit 1
fi

for ctx in $(kubectl config get-contexts -o name); do
  echo ""
  echo "=== Context: $ctx ==="
  kubectl --context="$ctx" $COMMAND 2>/dev/null || echo "Failed to connect"
done
```

### Challenge 3: Resource Finder

```bash
#!/bin/bash
# kubectl-find - Find resources by various criteria

usage() {
  echo "Usage: kubectl find [options]"
  echo "Options:"
  echo "  --image <pattern>    Find pods by image"
  echo "  --label <key=value>  Find resources by label"
  echo "  --name <pattern>     Find resources by name pattern"
  exit 1
}

case "$1" in
  --image)
    pattern="$2"
    echo "Pods using image matching: $pattern"
    kubectl get pods -A -o json | jq -r ".items[] | select(.spec.containers[].image | contains(\"$pattern\")) | [.metadata.namespace, .metadata.name] | @tsv"
    ;;
  --label)
    kubectl get all -A -l "$2"
    ;;
  --name)
    pattern="$2"
    kubectl get all -A | grep -i "$pattern"
    ;;
  *)
    usage
    ;;
esac
```

---

## Verification Tasks

1. [ ] Used JSONPath to extract complex nested data
2. [ ] Created custom column output templates
3. [ ] Performed patch operations on resources
4. [ ] Managed multiple kubeconfig contexts
5. [ ] Set up productive aliases and functions
6. [ ] Installed and used kubectl plugins

---

## Key Takeaways

- kubectl output formats are powerful for scripting
- Patches enable surgical updates to resources
- Context management is essential for multi-cluster work
- Aliases and functions dramatically improve productivity
- Plugins extend kubectl for specialized tasks

---

## Module Complete!

You've completed the Kubernetes Architecture module. Continue to:
- [Core Workloads Module](03-core-workloads-README.md)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Advanced Output Formatting
- Resource Management
- Context and Configuration
- Productive Aliases and Functions

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
