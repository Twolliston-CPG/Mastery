# Exercise 2: Control Plane Deep Dive

## Objectives

- Understand each control plane component's role
- Trace request flow through the cluster
- Debug control plane issues
- Configure control plane components

## Prerequisites

- Completed Exercise 1
- Access to control plane components
- Understanding of Kubernetes API

---

## Part 1: API Server Deep Dive

### 1.1 API Server Request Flow

```
Client Request → Authentication → Authorization → Admission Control → Validation → etcd
```

### 1.2 Examining API Server Configuration

```bash
# View API server pod specification
kubectl get pod -n kube-system -l component=kube-apiserver -o yaml

# Key configuration flags to understand:
# --advertise-address: IP clients use to reach API server
# --secure-port: HTTPS port (default 6443)
# --authorization-mode: How requests are authorized (Node,RBAC)
# --enable-admission-plugins: Which admission controllers are enabled
# --etcd-servers: etcd cluster endpoints
```

### 1.3 API Server Admission Controllers

```bash
# List enabled admission controllers
kubectl get pod -n kube-system -l component=kube-apiserver -o jsonpath='{.items[0].spec.containers[0].command}' | tr ',' '\n' | grep admission

# Common admission controllers:
# - NamespaceLifecycle: Prevents creation in non-existent namespaces
# - LimitRanger: Enforces LimitRanges
# - ServiceAccount: Automates service accounts
# - ResourceQuota: Enforces resource quotas
# - PodSecurityPolicy/PodSecurity: Enforces security standards
# - MutatingAdmissionWebhook: Custom mutations
# - ValidatingAdmissionWebhook: Custom validations
```

### 1.4 API Server Audit Logging

Create an audit policy to track API server activity:

```yaml
# audit-policy.yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  # Log pod changes at RequestResponse level
  - level: RequestResponse
    resources:
    - group: ""
      resources: ["pods"]

  # Log secrets at Metadata level (don't log request/response body)
  - level: Metadata
    resources:
    - group: ""
      resources: ["secrets"]

  # Don't log read-only requests to endpoints
  - level: None
    resources:
    - group: ""
      resources: ["endpoints"]
    verbs: ["get", "list", "watch"]

  # Default level for all other resources
  - level: Metadata
```

---

## Part 2: etcd Investigation

### 2.1 Understanding etcd's Role

etcd stores all cluster state:
- Pods, Services, ConfigMaps, Secrets
- RBAC rules
- Custom resources
- Cluster configuration

### 2.2 etcd Health Check

```bash
# Check etcd pod status
kubectl get pods -n kube-system -l component=etcd

# Check etcd member list (if etcdctl is available)
kubectl exec -n kube-system etcd-<master-node> -- etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  member list

# Check etcd endpoint status
kubectl exec -n kube-system etcd-<master-node> -- etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  endpoint status --write-out=table
```

### 2.3 etcd Data Exploration

```bash
# List all keys (be careful in production!)
kubectl exec -n kube-system etcd-<master-node> -- etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get / --prefix --keys-only | head -50

# Key structure:
# /registry/pods/<namespace>/<name>
# /registry/services/<namespace>/<name>
# /registry/configmaps/<namespace>/<name>
# /registry/secrets/<namespace>/<name>
```

---

## Part 3: Controller Manager

### 3.1 Understanding Controllers

Controllers implement the control loop pattern:
```
Observe Current State → Compare with Desired State → Take Action
```

### 3.2 Key Controllers

```bash
# View controller manager configuration
kubectl get pod -n kube-system -l component=kube-controller-manager -o yaml

# Key controllers:
# - Node Controller: Monitors node health
# - Replication Controller: Manages ReplicaSets
# - Endpoints Controller: Populates Services endpoints
# - ServiceAccount Controller: Creates default ServiceAccounts
# - Deployment Controller: Manages Deployments and ReplicaSets
# - StatefulSet Controller: Manages StatefulSets
# - Job Controller: Manages Jobs and CronJobs
# - PersistentVolume Controller: Manages PV binding
```

### 3.3 Controller Leader Election

In HA setups, only one controller manager is active:

```bash
# Check current leader
kubectl get endpoints kube-controller-manager -n kube-system -o yaml

# Leader information is in the annotation
kubectl get endpoints kube-controller-manager -n kube-system -o jsonpath='{.metadata.annotations.control-plane\.alpha\.kubernetes\.io/leader}'
```

### 3.4 Watching Controllers in Action

```bash
# Create a deployment and watch the controller
kubectl create deployment controller-test --image=nginx:1.25 --replicas=3

# Watch ReplicaSet controller create pods
kubectl get rs -w &
kubectl get pods -w &

# Scale and observe
kubectl scale deployment controller-test --replicas=5

# Delete a pod and watch recreation
kubectl delete pod -l app=controller-test --wait=false

# Cleanup
kubectl delete deployment controller-test
```

---

## Part 4: Scheduler

### 4.1 Understanding Scheduling

The scheduler assigns pods to nodes based on:
- Resource requirements
- Node selectors and affinity
- Taints and tolerations
- Pod priority and preemption

### 4.2 Scheduler Configuration

```bash
# View scheduler pod
kubectl get pod -n kube-system -l component=kube-scheduler -o yaml

# View scheduler logs
kubectl logs -n kube-system -l component=kube-scheduler --tail=50
```

### 4.3 Scheduling Decisions

```bash
# Create a pending pod to observe scheduling
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: scheduler-test
spec:
  containers:
  - name: nginx
    image: nginx:1.25
    resources:
      requests:
        cpu: "100m"
        memory: "128Mi"
EOF

# Check scheduling events
kubectl describe pod scheduler-test | grep -A 10 "Events"

# View scheduler decision
kubectl get pod scheduler-test -o jsonpath='{.spec.nodeName}'

# Cleanup
kubectl delete pod scheduler-test
```

### 4.4 Custom Scheduling

```yaml
# pod-with-node-selector.yaml
apiVersion: v1
kind: Pod
metadata:
  name: node-selector-test
spec:
  nodeSelector:
    disk: ssd  # Requires node with this label
  containers:
  - name: nginx
    image: nginx:1.25
```

```yaml
# pod-with-affinity.yaml
apiVersion: v1
kind: Pod
metadata:
  name: affinity-test
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: kubernetes.io/os
            operator: In
            values:
            - linux
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 1
        preference:
          matchExpressions:
          - key: zone
            operator: In
            values:
            - us-west-1a
  containers:
  - name: nginx
    image: nginx:1.25
```

---

## Part 5: Request Flow Tracing

### 5.1 Create and Trace a Resource

```bash
# Enable verbose logging for kubectl
kubectl create deployment trace-test --image=nginx:1.25 --replicas=2 -v=8

# This shows:
# 1. REST request to API server
# 2. Authentication/Authorization
# 3. Admission control
# 4. Response from API server

# Cleanup
kubectl delete deployment trace-test
```

### 5.2 Understanding the Complete Flow

When you create a Deployment:

1. **kubectl** → Sends POST request to API server
2. **API Server** → Authenticates, authorizes, validates, stores in etcd
3. **Deployment Controller** → Detects new Deployment, creates ReplicaSet
4. **ReplicaSet Controller** → Detects new ReplicaSet, creates Pods
5. **Scheduler** → Assigns unscheduled Pods to Nodes
6. **Kubelet** → Sees assigned Pod, creates containers

---

## Part 6: Hands-on Challenges

### Challenge 1: Control Plane Monitoring Script

```bash
#!/bin/bash
# control-plane-monitor.sh

echo "=== Control Plane Health Monitor ==="
echo "Time: $(date)"
echo ""

# Check each component
components=("kube-apiserver" "kube-controller-manager" "kube-scheduler" "etcd")

for comp in "${components[@]}"; do
  pod=$(kubectl get pods -n kube-system -l component=$comp -o name 2>/dev/null | head -1)
  if [ -n "$pod" ]; then
    status=$(kubectl get $pod -n kube-system -o jsonpath='{.status.phase}')
    restarts=$(kubectl get $pod -n kube-system -o jsonpath='{.status.containerStatuses[0].restartCount}')
    echo "$comp: Status=$status, Restarts=$restarts"
  else
    echo "$comp: NOT FOUND (might be running outside cluster)"
  fi
done

echo ""
echo "=== API Server Latency Test ==="
time kubectl get pods -A > /dev/null 2>&1
```

### Challenge 2: Debug Unschedulable Pod

```bash
# Create a pod that won't schedule
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: unschedulable-test
spec:
  nodeSelector:
    special-hardware: gpu-tesla-v100
  containers:
  - name: nginx
    image: nginx:1.25
EOF

# Debug why it's pending
kubectl describe pod unschedulable-test
kubectl get events --field-selector=involvedObject.name=unschedulable-test

# Fix it by adding the label to a node (or removing nodeSelector)
# kubectl label nodes <node-name> special-hardware=gpu-tesla-v100

# Cleanup
kubectl delete pod unschedulable-test
```

### Challenge 3: etcd Backup (for cluster admins)

```bash
#!/bin/bash
# etcd-backup.sh

BACKUP_DIR="/tmp/etcd-backup"
mkdir -p $BACKUP_DIR

# Create snapshot
kubectl exec -n kube-system etcd-<master-node> -- etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save /tmp/etcd-snapshot.db

# Copy snapshot locally
kubectl cp kube-system/etcd-<master-node>:/tmp/etcd-snapshot.db $BACKUP_DIR/etcd-snapshot-$(date +%Y%m%d-%H%M%S).db

echo "Backup completed: $BACKUP_DIR"
```

---

## Verification Tasks

1. [ ] Examined API server configuration and admission controllers
2. [ ] Checked etcd health and explored key structure
3. [ ] Identified controller manager components
4. [ ] Observed scheduler making placement decisions
5. [ ] Traced complete request flow for resource creation
6. [ ] Created control plane monitoring script

---

## Key Takeaways

- API server is the central communication hub
- etcd stores all cluster state and is critical
- Controller manager runs multiple controllers as one process
- Scheduler uses complex algorithms for pod placement
- Understanding request flow aids troubleshooting

---

## Next Steps

Continue to [Exercise 3: Node Components](02-kubernetes-architecture-exercises-03-node-components.md)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- API Server Deep Dive
- etcd Investigation
- Controller Manager
- Scheduler

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
