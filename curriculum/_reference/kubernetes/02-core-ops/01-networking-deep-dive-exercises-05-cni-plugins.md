# Exercise 5: CNI Plugins

## Objectives

- Understand CNI plugin architecture
- Compare popular CNI solutions
- Deploy and configure Cilium
- Implement advanced networking features

## Prerequisites

- Completed Exercises 1-4
- Access to cluster with CNI configuration
- Understanding of network concepts

---

## Part 1: CNI Architecture

### 1.1 Understanding CNI

Container Network Interface (CNI) is a specification for container networking:
- Defines how plugins configure networking
- Provides standard interface for Kubernetes
- Handles IP allocation, routing, network policies

### 1.2 CNI Plugin Workflow

```
1. Pod Created → kubelet calls CNI plugin
2. CNI ADD → Plugin configures network:
   - Creates veth pair
   - Assigns IP address
   - Sets up routing
   - Configures iptables/eBPF rules
3. Pod Deleted → CNI DEL → Plugin cleans up
```

### 1.3 Viewing Current CNI

```bash
# Check CNI configuration
ls /etc/cni/net.d/

# View CNI config
cat /etc/cni/net.d/*.conflist

# Check CNI binaries
ls /opt/cni/bin/

# View kubelet CNI configuration
ps aux | grep kubelet | grep cni
```

---

## Part 2: CNI Plugin Comparison

### 2.1 Popular CNI Plugins

| Plugin | Network Policy | Encryption | Performance | Use Case |
|--------|---------------|------------|-------------|----------|
| Calico | Yes | Yes (WireGuard) | High | General purpose |
| Cilium | Yes (Advanced) | Yes | Very High | Security-focused |
| Flannel | No | No | Medium | Simple setups |
| Weave | Yes | Yes | Medium | Multi-cloud |
| Canal | Yes | No | High | Calico + Flannel |

### 2.2 Checking Installed CNI

```bash
# Calico
kubectl get pods -n kube-system -l k8s-app=calico-node

# Cilium
kubectl get pods -n kube-system -l k8s-app=cilium

# Flannel
kubectl get pods -n kube-system -l app=flannel

# View CNI DaemonSet
kubectl get daemonset -n kube-system
```

---

## Part 3: Cilium Deep Dive

### 3.1 Installing Cilium

```bash
# Install Cilium CLI
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin

# Install Cilium
cilium install

# Check status
cilium status
```

### 3.2 Cilium Helm Installation

```bash
# Add Helm repo
helm repo add cilium https://helm.cilium.io/

# Install with custom values
helm install cilium cilium/cilium \
  --namespace kube-system \
  --set hubble.relay.enabled=true \
  --set hubble.ui.enabled=true \
  --set prometheus.enabled=true \
  --set operator.prometheus.enabled=true
```

### 3.3 Cilium Configuration

```yaml
# cilium-values.yaml
cilium:
  # Enable Hubble for observability
  hubble:
    enabled: true
    relay:
      enabled: true
    ui:
      enabled: true
    metrics:
      enabled:
        - dns
        - drop
        - tcp
        - flow
        - icmp
        - http

  # Enable encryption
  encryption:
    enabled: true
    type: wireguard

  # Network policy mode
  policyEnforcementMode: "default"  # or: always, never

  # IPAM mode
  ipam:
    mode: "cluster-pool"
    operator:
      clusterPoolIPv4PodCIDRList:
        - "10.0.0.0/8"

  # Enable bandwidth manager
  bandwidthManager:
    enabled: true

  # Kubernetes integration
  k8sServiceHost: "kubernetes.default.svc"
  k8sServicePort: "443"
```

---

## Part 4: Cilium Network Policies

### 4.1 L3/L4 Policies

```yaml
# cilium-l3l4-policy.yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: l3-l4-rule
spec:
  endpointSelector:
    matchLabels:
      app: backend
  ingress:
  - fromEndpoints:
    - matchLabels:
        app: frontend
    toPorts:
    - ports:
      - port: "8080"
        protocol: TCP
```

### 4.2 L7 Policies (HTTP)

```yaml
# cilium-l7-policy.yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: l7-http-rule
spec:
  endpointSelector:
    matchLabels:
      app: api
  ingress:
  - fromEndpoints:
    - matchLabels:
        app: frontend
    toPorts:
    - ports:
      - port: "8080"
        protocol: TCP
      rules:
        http:
        - method: "GET"
          path: "/api/v1/.*"
        - method: "POST"
          path: "/api/v1/users"
          headers:
          - 'Content-Type: application/json'
```

### 4.3 DNS-Based Policies

```yaml
# cilium-dns-policy.yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: allow-external-api
spec:
  endpointSelector:
    matchLabels:
      app: client
  egress:
  - toFQDNs:
    - matchName: "api.github.com"
    - matchPattern: "*.amazonaws.com"
    toPorts:
    - ports:
      - port: "443"
        protocol: TCP
```

### 4.4 Cluster-Wide Policies

```yaml
# cilium-cluster-policy.yaml
apiVersion: cilium.io/v2
kind: CiliumClusterwideNetworkPolicy
metadata:
  name: default-deny-all
spec:
  endpointSelector: {}
  ingress:
  - fromEndpoints:
    - matchLabels:
        "k8s:io.kubernetes.pod.namespace": kube-system
  egress:
  - toEndpoints:
    - matchLabels:
        "k8s:io.kubernetes.pod.namespace": kube-system
  - toEntities:
    - cluster
    - host
```

---

## Part 5: Hubble Observability

### 5.1 Hubble CLI

```bash
# Install Hubble CLI
export HUBBLE_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/hubble/master/stable.txt)
curl -L --fail --remote-name-all https://github.com/cilium/hubble/releases/download/$HUBBLE_VERSION/hubble-linux-amd64.tar.gz
sudo tar xzvfC hubble-linux-amd64.tar.gz /usr/local/bin

# Port forward to Hubble relay
kubectl port-forward -n kube-system svc/hubble-relay 4245:80 &

# Check Hubble status
hubble status

# Observe flows
hubble observe

# Filter by namespace
hubble observe --namespace default

# Filter by pod
hubble observe --pod default/my-pod

# Filter by verdict
hubble observe --verdict DROPPED
```

### 5.2 Hubble UI

```bash
# Port forward to Hubble UI
kubectl port-forward -n kube-system svc/hubble-ui 12000:80

# Access at http://localhost:12000
```

### 5.3 Flow Analysis

```bash
# Show DNS queries
hubble observe --protocol dns

# Show HTTP traffic
hubble observe --protocol http

# Show dropped traffic
hubble observe --verdict DROPPED

# JSON output for processing
hubble observe --output json | jq .

# Follow specific traffic
hubble observe --follow --from-pod default/frontend --to-pod default/backend
```

---

## Part 6: Calico Configuration

### 6.1 Installing Calico

```bash
# Install Calico operator
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/tigera-operator.yaml

# Install Calico
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/custom-resources.yaml

# Verify installation
kubectl get pods -n calico-system
```

### 6.2 Calico CLI (calicoctl)

```bash
# Install calicoctl
curl -L https://github.com/projectcalico/calico/releases/download/v3.27.0/calicoctl-linux-amd64 -o calicoctl
chmod +x calicoctl
sudo mv calicoctl /usr/local/bin

# Configure datastore
export DATASTORE_TYPE=kubernetes
export KUBECONFIG=~/.kube/config

# Check Calico status
calicoctl node status

# View IP pools
calicoctl get ippools -o wide

# View workload endpoints
calicoctl get workloadendpoints -A
```

### 6.3 Calico Network Policies

```yaml
# calico-global-policy.yaml
apiVersion: projectcalico.org/v3
kind: GlobalNetworkPolicy
metadata:
  name: default-deny
spec:
  selector: all()
  types:
  - Ingress
  - Egress
---
apiVersion: projectcalico.org/v3
kind: GlobalNetworkPolicy
metadata:
  name: allow-kube-system
spec:
  order: 100
  selector: all()
  types:
  - Ingress
  - Egress
  ingress:
  - action: Allow
    source:
      namespaceSelector: kubernetes.io/metadata.name == "kube-system"
  egress:
  - action: Allow
    destination:
      namespaceSelector: kubernetes.io/metadata.name == "kube-system"
```

### 6.4 Calico WireGuard Encryption

```bash
# Enable WireGuard encryption
kubectl patch felixconfiguration default --type='merge' -p '{"spec":{"wireguardEnabled":true}}'

# Verify encryption
calicoctl get felixconfiguration default -o yaml | grep wireguard
```

---

## Part 7: Hands-on Challenges

### Challenge 1: CNI Migration Planning

Document the steps to migrate from Flannel to Cilium:
1. Audit current network policies
2. Plan IP address management
3. Test in staging environment
4. Execute migration

### Challenge 2: L7 Policy Implementation

Implement HTTP-aware network policies that:
1. Allow only GET requests to `/api/public/*`
2. Allow POST to `/api/v1/users` only with JSON content-type
3. Block all other API access

### Challenge 3: Network Observability

Set up comprehensive network monitoring:
1. Deploy Hubble
2. Create dashboard for flow visualization
3. Set up alerts for dropped traffic
4. Document troubleshooting procedures

---

## Verification Tasks

1. [ ] Examined CNI configuration
2. [ ] Compared CNI plugin features
3. [ ] Deployed Cilium CNI
4. [ ] Created L7 network policies
5. [ ] Used Hubble for observability
6. [ ] Configured Calico features

---

## Key Takeaways

- CNI plugins handle pod networking
- Cilium provides advanced L7 policies
- eBPF enables high-performance networking
- Hubble provides deep network visibility
- Calico offers flexible policy options
- Choose CNI based on requirements

---

## Next Steps

Continue to [Exercise 6: Load Balancing](01-networking-deep-dive-exercises-06-load-balancing.md)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- CNI Architecture
- CNI Plugin Comparison
- Cilium Deep Dive
- Cilium Network Policies

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
