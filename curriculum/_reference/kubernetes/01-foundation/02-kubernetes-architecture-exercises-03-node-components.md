# Exercise 3: Node Components Deep Dive

## Objectives

- Understand kubelet's role and configuration
- Master kube-proxy networking modes
- Explore container runtime interface (CRI)
- Debug node-level issues

## Prerequisites

- Completed Exercise 2
- Access to worker nodes (SSH or kubectl debug)
- Understanding of container concepts

---

## Part 1: Kubelet Deep Dive

### 1.1 Understanding Kubelet

The kubelet is the primary node agent that:
- Registers the node with the API server
- Receives pod specifications from the API server
- Ensures containers are running and healthy
- Reports node and pod status

### 1.2 Examining Kubelet Configuration

```bash
# View kubelet configuration on a node
kubectl get nodes
NODE_NAME=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')

# Check kubelet status via node proxy
kubectl get --raw /api/v1/nodes/$NODE_NAME/proxy/configz | jq .

# View kubelet command line arguments
kubectl get node $NODE_NAME -o jsonpath='{.status.nodeInfo}' | jq .
```

### 1.3 Kubelet Key Configuration Options

```yaml
# Example kubelet config (KubeletConfiguration)
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
# Resource management
evictionHard:
  memory.available: "100Mi"
  nodefs.available: "10%"
  imagefs.available: "15%"
evictionSoft:
  memory.available: "200Mi"
evictionSoftGracePeriod:
  memory.available: "1m30s"

# Pod management
maxPods: 110
podPidsLimit: 4096

# Security
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
authorization:
  mode: Webhook

# Health checks
healthzPort: 10248
healthzBindAddress: "127.0.0.1"
```

### 1.4 Kubelet Debugging

```bash
# Create a debug pod on specific node
kubectl debug node/$NODE_NAME -it --image=busybox

# Once inside the debug pod:
# View kubelet logs
chroot /host
journalctl -u kubelet -f

# Check kubelet health
curl -sk https://localhost:10250/healthz

# View running containers
crictl ps

# Exit debug pod
exit
exit
```

---

## Part 2: Kube-proxy Networking

### 2.1 Understanding Kube-proxy

Kube-proxy maintains network rules for Services:
- Implements Service abstraction
- Load balances traffic to pods
- Handles ClusterIP, NodePort, LoadBalancer

### 2.2 Proxy Modes

```bash
# Check current proxy mode
kubectl get pods -n kube-system -l k8s-app=kube-proxy -o yaml | grep -A 5 "command:"

# View kube-proxy configuration
kubectl get configmap -n kube-system kube-proxy -o yaml
```

**iptables mode** (default):
```bash
# View iptables rules on a node
kubectl debug node/$NODE_NAME -it --image=nicolaka/netshoot -- bash
iptables -t nat -L KUBE-SERVICES -n | head -20
exit
```

**IPVS mode** (recommended for large clusters):
```bash
# View IPVS rules
kubectl debug node/$NODE_NAME -it --image=nicolaka/netshoot -- bash
ipvsadm -Ln
exit
```

### 2.3 Service Traffic Flow

```bash
# Create test service
kubectl create deployment proxy-test --image=nginx:1.25 --replicas=3
kubectl expose deployment proxy-test --port=80

# Get service details
kubectl get svc proxy-test
kubectl get endpoints proxy-test

# Observe how traffic is distributed
# From inside cluster:
kubectl run test --rm -it --image=busybox -- sh
# Inside pod:
for i in $(seq 1 10); do wget -qO- proxy-test | grep -o "Welcome to nginx"; done
exit
```

### 2.4 Debugging Service Connectivity

```bash
# Check if endpoints exist
kubectl get endpoints proxy-test

# Check iptables rules for service
kubectl debug node/$NODE_NAME -it --image=nicolaka/netshoot -- bash
iptables -t nat -L KUBE-SVC-* -n 2>/dev/null | head -30
exit

# Trace network path
kubectl run netshoot --rm -it --image=nicolaka/netshoot -- bash
# Inside pod:
nslookup proxy-test
traceroute proxy-test
curl -v proxy-test
exit

# Cleanup
kubectl delete deployment proxy-test
kubectl delete svc proxy-test
```

---

## Part 3: Container Runtime Interface (CRI)

### 3.1 Understanding CRI

CRI is the standard interface between kubelet and container runtimes:
- containerd (most common)
- CRI-O
- Docker (via cri-dockerd)

### 3.2 Exploring containerd

```bash
# Debug node to explore runtime
kubectl debug node/$NODE_NAME -it --image=busybox -- sh
chroot /host

# Check containerd status
systemctl status containerd

# Use crictl to interact with runtime
crictl info
crictl ps
crictl images

# View container details
crictl inspect <container-id>

exit
exit
```

### 3.3 Image Management

```bash
# Using crictl for image operations
kubectl debug node/$NODE_NAME -it --image=busybox -- sh
chroot /host

# List images
crictl images

# Pull an image
crictl pull docker.io/library/redis:7

# Image disk usage
crictl imagefsinfo

exit
exit
```

### 3.4 Container Lifecycle

```bash
# Watch container creation
# Terminal 1: Watch events
kubectl get events -w

# Terminal 2: Create a pod
kubectl run lifecycle-test --image=nginx:1.25

# Check container on node
kubectl debug node/$NODE_NAME -it --image=busybox -- sh
chroot /host
crictl ps | grep lifecycle
crictl logs <container-id>
exit
exit

# Cleanup
kubectl delete pod lifecycle-test
```

---

## Part 4: Node Status and Resources

### 4.1 Node Conditions

```bash
# View all node conditions
kubectl describe node $NODE_NAME | grep -A 20 "Conditions:"

# Conditions explained:
# - Ready: Node is healthy and can accept pods
# - MemoryPressure: Running low on memory
# - DiskPressure: Running low on disk
# - PIDPressure: Too many processes
# - NetworkUnavailable: Network not configured
```

### 4.2 Node Capacity and Allocatable

```bash
# View capacity vs allocatable
kubectl describe node $NODE_NAME | grep -A 10 "Capacity:"
kubectl describe node $NODE_NAME | grep -A 10 "Allocatable:"

# Difference is system reserved resources

# View current allocation
kubectl describe node $NODE_NAME | grep -A 10 "Allocated resources:"
```

### 4.3 Node Resource Monitoring

```bash
# Using metrics-server
kubectl top nodes
kubectl top node $NODE_NAME

# Detailed resource usage
kubectl get node $NODE_NAME -o jsonpath='{.status.allocatable}' | jq .
```

---

## Part 5: Node Troubleshooting

### 5.1 Common Node Issues

```bash
# Node not ready
kubectl describe node $NODE_NAME | grep -A 5 "Conditions"

# Check kubelet logs
kubectl debug node/$NODE_NAME -it --image=busybox -- sh
chroot /host
journalctl -u kubelet --since "10 minutes ago"
exit
exit
```

### 5.2 Pod Eviction Issues

```bash
# Check eviction thresholds
kubectl get --raw /api/v1/nodes/$NODE_NAME/proxy/configz | jq '.kubeletconfig.evictionHard'

# Monitor for evictions
kubectl get events --field-selector=reason=Evicted
```

### 5.3 Network Troubleshooting

```bash
# DNS resolution test
kubectl run dns-test --rm -it --image=busybox -- nslookup kubernetes

# Service connectivity test
kubectl run curl-test --rm -it --image=curlimages/curl -- sh
# Inside pod:
curl -v kubernetes.default.svc.cluster.local
exit
```

---

## Part 6: Hands-on Challenges

### Challenge 1: Node Health Dashboard

```bash
#!/bin/bash
# node-health.sh

echo "=== Node Health Dashboard ==="
echo "Generated: $(date)"
echo ""

for node in $(kubectl get nodes -o name); do
  node_name=$(echo $node | cut -d'/' -f2)
  echo "--- $node_name ---"

  # Get status
  status=$(kubectl get $node -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
  echo "Ready: $status"

  # Get resource pressure
  mem_pressure=$(kubectl get $node -o jsonpath='{.status.conditions[?(@.type=="MemoryPressure")].status}')
  disk_pressure=$(kubectl get $node -o jsonpath='{.status.conditions[?(@.type=="DiskPressure")].status}')
  echo "MemoryPressure: $mem_pressure"
  echo "DiskPressure: $disk_pressure"

  # Get allocatable vs capacity
  cpu_alloc=$(kubectl get $node -o jsonpath='{.status.allocatable.cpu}')
  mem_alloc=$(kubectl get $node -o jsonpath='{.status.allocatable.memory}')
  echo "Allocatable: CPU=$cpu_alloc, Memory=$mem_alloc"

  echo ""
done
```

### Challenge 2: Container Runtime Investigation

```bash
#!/bin/bash
# runtime-info.sh

NODE_NAME=$1

if [ -z "$NODE_NAME" ]; then
  echo "Usage: $0 <node-name>"
  exit 1
fi

echo "=== Container Runtime Info for $NODE_NAME ==="

# Get runtime info from node status
runtime=$(kubectl get node $NODE_NAME -o jsonpath='{.status.nodeInfo.containerRuntimeVersion}')
echo "Runtime: $runtime"

kubelet=$(kubectl get node $NODE_NAME -o jsonpath='{.status.nodeInfo.kubeletVersion}')
echo "Kubelet: $kubelet"

os=$(kubectl get node $NODE_NAME -o jsonpath='{.status.nodeInfo.osImage}')
echo "OS: $os"

kernel=$(kubectl get node $NODE_NAME -o jsonpath='{.status.nodeInfo.kernelVersion}')
echo "Kernel: $kernel"
```

### Challenge 3: Service Endpoint Tracer

```bash
#!/bin/bash
# trace-service.sh

SERVICE_NAME=$1
NAMESPACE=${2:-default}

if [ -z "$SERVICE_NAME" ]; then
  echo "Usage: $0 <service-name> [namespace]"
  exit 1
fi

echo "=== Service Trace: $SERVICE_NAME (ns: $NAMESPACE) ==="
echo ""

# Get service info
echo "--- Service ---"
kubectl get svc $SERVICE_NAME -n $NAMESPACE -o wide

echo ""
echo "--- Endpoints ---"
kubectl get endpoints $SERVICE_NAME -n $NAMESPACE -o wide

echo ""
echo "--- Backend Pods ---"
selector=$(kubectl get svc $SERVICE_NAME -n $NAMESPACE -o jsonpath='{.spec.selector}' | jq -r 'to_entries | map("\(.key)=\(.value)") | join(",")')
kubectl get pods -n $NAMESPACE -l "$selector" -o wide

echo ""
echo "--- Connectivity Test ---"
kubectl run test-curl-$RANDOM --rm -it --restart=Never --image=curlimages/curl -- \
  curl -s -o /dev/null -w "HTTP Status: %{http_code}\nTime: %{time_total}s\n" \
  "http://$SERVICE_NAME.$NAMESPACE.svc.cluster.local"
```

---

## Verification Tasks

1. [ ] Examined kubelet configuration on a node
2. [ ] Identified kube-proxy mode (iptables/IPVS)
3. [ ] Used crictl to inspect containers
4. [ ] Analyzed node conditions and resources
5. [ ] Created node health monitoring script
6. [ ] Traced service connectivity through the stack

---

## Key Takeaways

- Kubelet is the node's primary agent responsible for pod lifecycle
- Kube-proxy implements Service networking via iptables or IPVS
- Container runtime (containerd) handles actual container operations
- Node conditions indicate cluster health at the node level
- Understanding node components is crucial for troubleshooting

---

## Next Steps

Continue to [Exercise 4: kubectl Advanced Usage](04-kubectl-advanced.md)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Kubelet Deep Dive
- Kube-proxy Networking
- Container Runtime Interface (CRI)
- Node Status and Resources

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
