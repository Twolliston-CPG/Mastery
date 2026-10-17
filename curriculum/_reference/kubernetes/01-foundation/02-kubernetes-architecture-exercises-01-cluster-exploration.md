# Exercise 1: Cluster Exploration and API Server

## Objectives

- Understand the Kubernetes API structure
- Explore cluster components programmatically
- Master kubectl for cluster inspection
- Learn API server health monitoring

## Prerequisites

- Running Kubernetes cluster (local or cloud)
- kubectl configured and working
- Basic understanding of REST APIs

---

## Part 1: API Server Exploration

### 1.1 Discovering API Resources

```bash
# List all available API resources
kubectl api-resources

# List resources with additional information
kubectl api-resources -o wide

# Filter by API group
kubectl api-resources --api-group=apps
kubectl api-resources --api-group=batch

# List only namespaced resources
kubectl api-resources --namespaced=true

# List cluster-scoped resources
kubectl api-resources --namespaced=false
```

**Exercise:** Count how many API resources support the `create` verb:
```bash
kubectl api-resources --verbs=create -o name | wc -l
```

### 1.2 Understanding API Versions

```bash
# List all API versions
kubectl api-versions

# Understand API groups
# - Core API (legacy): v1
# - Named groups: apps/v1, batch/v1, networking.k8s.io/v1
```

### 1.3 Raw API Access

```bash
# Access API root
kubectl get --raw /

# List all API groups
kubectl get --raw /apis | jq '.groups[].name'

# Get specific API group details
kubectl get --raw /apis/apps/v1 | jq .

# Get pods through raw API
kubectl get --raw /api/v1/namespaces/default/pods | jq '.items[].metadata.name'
```

---

## Part 2: Health and Status Endpoints

### 2.1 API Server Health

```bash
# Basic health check
kubectl get --raw /healthz

# Verbose health check (shows all checks)
kubectl get --raw /healthz?verbose

# Individual health checks
kubectl get --raw /healthz/etcd
kubectl get --raw /healthz/ping
kubectl get --raw /healthz/poststarthook/start-apiserver-admission-initializer

# Liveness endpoint
kubectl get --raw /livez

# Readiness endpoint
kubectl get --raw /readyz
```

### 2.2 API Server Metrics

```bash
# Get API server metrics (if accessible)
kubectl get --raw /metrics | head -100

# Filter for specific metrics
kubectl get --raw /metrics | grep apiserver_request_total | head -20
```

---

## Part 3: Cluster Component Investigation

### 3.1 Control Plane Pods

```bash
# List control plane components
kubectl get pods -n kube-system

# Describe API server
kubectl describe pod -n kube-system -l component=kube-apiserver

# View API server logs
kubectl logs -n kube-system -l component=kube-apiserver --tail=50

# View scheduler logs
kubectl logs -n kube-system -l component=kube-scheduler --tail=50

# View controller-manager logs
kubectl logs -n kube-system -l component=kube-controller-manager --tail=50
```

### 3.2 etcd Investigation (if accessible)

```bash
# Check etcd pod
kubectl get pods -n kube-system -l component=etcd

# View etcd configuration
kubectl describe pod -n kube-system -l component=etcd

# Check etcd health (from inside cluster)
kubectl exec -n kube-system etcd-<master-node> -- etcdctl endpoint health
```

### 3.3 Component Status (deprecated but informative)

```bash
# Get component statuses (deprecated in newer versions)
kubectl get componentstatuses

# Alternative: check via API server health endpoints
kubectl get --raw /healthz/etcd
kubectl get --raw /healthz/poststarthook/start-kube-controller-manager-informers
```

---

## Part 4: kubectl Mastery

### 4.1 Output Formats

```bash
# Create a test deployment
kubectl create deployment nginx --image=nginx:1.25 --replicas=2

# Different output formats
kubectl get pods -o wide
kubectl get pods -o yaml
kubectl get pods -o json
kubectl get pods -o name

# Custom columns
kubectl get pods -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,IP:.status.podIP

# JSONPath queries
kubectl get pods -o jsonpath='{.items[*].metadata.name}'
kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.phase}{"\n"}{end}'

# Go templates
kubectl get pods -o go-template='{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}'
```

### 4.2 Resource Selection

```bash
# Select by labels
kubectl get pods -l app=nginx
kubectl get pods -l 'app in (nginx, redis)'
kubectl get pods -l 'app!=nginx'

# Select by field
kubectl get pods --field-selector=status.phase=Running
kubectl get pods --field-selector=metadata.namespace=default

# Combine selectors
kubectl get pods -l app=nginx --field-selector=status.phase=Running
```

### 4.3 Sorting and Filtering

```bash
# Sort by creation timestamp
kubectl get pods --sort-by=.metadata.creationTimestamp

# Sort by restart count
kubectl get pods --sort-by='.status.containerStatuses[0].restartCount'

# Get all resources
kubectl get all
kubectl get all -A
```

### 4.4 Explain Command

```bash
# Understand resource structure
kubectl explain pod
kubectl explain pod.spec
kubectl explain pod.spec.containers
kubectl explain pod.spec.containers.resources

# With API version
kubectl explain deployment --api-version=apps/v1

# Recursive explanation
kubectl explain pod --recursive | head -100
```

---

## Part 5: Hands-on Challenge

### Challenge 1: API Discovery Script

Create a script that discovers all custom resources in your cluster:

```bash
#!/bin/bash
# discover-crds.sh

echo "=== Custom Resource Definitions in Cluster ==="
echo ""

kubectl get crds -o custom-columns=NAME:.metadata.name,GROUP:.spec.group,VERSION:.spec.versions[0].name,SCOPE:.spec.scope

echo ""
echo "Total CRDs: $(kubectl get crds -o name | wc -l)"
```

### Challenge 2: Cluster Health Report

Create a comprehensive health check script:

```bash
#!/bin/bash
# cluster-health.sh

echo "=== Kubernetes Cluster Health Report ==="
echo "Generated: $(date)"
echo ""

echo "--- API Server Health ---"
kubectl get --raw /healthz?verbose 2>/dev/null | grep -E '^\[|\+|ok|failed'

echo ""
echo "--- Node Status ---"
kubectl get nodes -o custom-columns=NAME:.metadata.name,STATUS:.status.conditions[-1].type,READY:.status.conditions[-1].status

echo ""
echo "--- Control Plane Pods ---"
kubectl get pods -n kube-system -l 'component in (kube-apiserver,kube-scheduler,kube-controller-manager,etcd)' \
  -o custom-columns=COMPONENT:.metadata.labels.component,STATUS:.status.phase,RESTARTS:.status.containerStatuses[0].restartCount

echo ""
echo "--- Pod Summary by Namespace ---"
kubectl get pods -A --no-headers | awk '{ns[$1]++} END {for (n in ns) print n, ns[n]}' | sort -k2 -nr | head -10

echo ""
echo "--- Recent Events (Warnings) ---"
kubectl get events -A --field-selector=type=Warning --sort-by=.lastTimestamp | tail -10
```

### Challenge 3: Resource Audit

Find all resources not using resource limits:

```bash
#!/bin/bash
# audit-resources.sh

echo "=== Pods Without Resource Limits ==="

kubectl get pods -A -o json | jq -r '
  .items[] |
  select(.spec.containers[].resources.limits == null) |
  [.metadata.namespace, .metadata.name] |
  @tsv
' | column -t
```

---

## Verification Tasks

1. [ ] Successfully accessed raw API endpoints
2. [ ] Retrieved API server health status
3. [ ] Listed all control plane components
4. [ ] Used multiple kubectl output formats
5. [ ] Created a cluster health check script
6. [ ] Identified pods without resource limits

---

## Key Takeaways

- The API server is the central hub for all cluster communication
- Understanding the API structure helps with troubleshooting
- kubectl supports powerful output formatting with JSONPath
- Health endpoints provide insight into cluster state
- Regular health monitoring prevents issues

---

## Next Steps

Continue to [Exercise 2: Control Plane Deep Dive](02-kubernetes-architecture-exercises-02-control-plane-deep-dive.md)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- API Server Exploration
- Health and Status Endpoints
- Cluster Component Investigation
- kubectl Mastery

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
