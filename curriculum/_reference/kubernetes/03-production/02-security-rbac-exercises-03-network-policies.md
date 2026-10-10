# Exercise 3: Network Policies

## Objectives

- Implement zero-trust network architecture
- Create ingress and egress policies
- Design namespace isolation
- Configure DNS policies

## Prerequisites

- Completed Exercises 1-2
- CNI with Network Policy support (Calico, Cilium, etc.)
- Understanding of Kubernetes networking

---

## Part 1: Network Policy Basics

### 1.1 Network Policy Model

**Network Policy Model**

**Default Behavior (no policy):**

- All ingress allowed
- All egress allowed

**With Network Policy:**

- Additive (whitelist model)
- Applies to pods matching selector
- Denies all traffic not explicitly allowed

**Policy Types:**

- Ingress: Controls incoming traffic
- Egress: Controls outgoing traffic
- Both: Controls all traffic

Empty selector {} matches all pods in namespace


### 1.2 Default Deny All

```yaml
# default-deny-all.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production
spec:
  podSelector: {}  # Matches all pods
  policyTypes:
    - Ingress
    - Egress
  # No ingress/egress rules = deny all
```

### 1.3 Allow All (Namespace)

```yaml
# allow-all.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-all
  namespace: development
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - {}  # Allow all ingress
  egress:
    - {}  # Allow all egress
```

---

## Part 2: Ingress Policies

### 2.1 Allow from Specific Pods

```yaml
# allow-frontend-to-backend.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-allow-frontend
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: frontend
      ports:
        - protocol: TCP
          port: 8080
```

### 2.2 Allow from Namespace

```yaml
# allow-from-namespace.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-monitoring
  namespace: production
spec:
  podSelector: {}  # All pods in production
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: monitoring
      ports:
        - protocol: TCP
          port: 9090  # Prometheus metrics
```

### 2.3 Allow from External (CIDR)

```yaml
# allow-from-cidr.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-external-ingress
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: api-gateway
  policyTypes:
    - Ingress
  ingress:
    # Allow from load balancer IPs
    - from:
        - ipBlock:
            cidr: 10.0.0.0/8
            except:
              - 10.10.0.0/16  # Except internal network
      ports:
        - protocol: TCP
          port: 443
```

### 2.4 Combined Ingress Rules

```yaml
# combined-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-ingress
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes:
    - Ingress
  ingress:
    # Rule 1: Allow from frontend pods in same namespace
    - from:
        - podSelector:
            matchLabels:
              app: frontend
      ports:
        - protocol: TCP
          port: 8080

    # Rule 2: Allow from any pod in staging namespace
    - from:
        - namespaceSelector:
            matchLabels:
              environment: staging
          podSelector:
            matchLabels:
              app: test-client
      ports:
        - protocol: TCP
          port: 8080

    # Rule 3: Allow Prometheus scraping from monitoring namespace
    - from:
        - namespaceSelector:
            matchLabels:
              name: monitoring
      ports:
        - protocol: TCP
          port: 9090
```

---

## Part 3: Egress Policies

### 3.1 Allow DNS Egress

```yaml
# allow-dns.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: production
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    # Allow DNS
    - to:
        - namespaceSelector: {}
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
```

### 3.2 Allow Specific Services

```yaml
# allow-backend-egress.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-egress
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
    - Egress
  egress:
    # Allow DNS
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
      ports:
        - protocol: UDP
          port: 53

    # Allow database
    - to:
        - podSelector:
            matchLabels:
              app: postgresql
      ports:
        - protocol: TCP
          port: 5432

    # Allow Redis
    - to:
        - podSelector:
            matchLabels:
              app: redis
      ports:
        - protocol: TCP
          port: 6379

    # Allow external APIs
    - to:
        - ipBlock:
            cidr: 0.0.0.0/0
            except:
              - 10.0.0.0/8
              - 172.16.0.0/12
              - 192.168.0.0/16
      ports:
        - protocol: TCP
          port: 443
```

### 3.3 Restrict Egress to Specific Endpoints

```yaml
# restricted-egress.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: restricted-egress
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: secure-app
  policyTypes:
    - Egress
  egress:
    # Only allow specific external IPs
    - to:
        - ipBlock:
            cidr: 203.0.113.0/24  # Specific external service
      ports:
        - protocol: TCP
          port: 443
```

---

## Part 4: Namespace Isolation

### 4.1 Complete Namespace Isolation

```yaml
# namespace-isolation.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: isolate-namespace
  namespace: secure-namespace
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
  ingress:
    # Only allow traffic from same namespace
    - from:
        - podSelector: {}
  egress:
    # Allow DNS
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
      ports:
        - protocol: UDP
          port: 53
    # Allow traffic within namespace
    - to:
        - podSelector: {}
```

### 4.2 Multi-Tenant Isolation

```yaml
# multi-tenant-isolation.yaml
---
# Tenant A namespace
apiVersion: v1
kind: Namespace
metadata:
  name: tenant-a
  labels:
    tenant: tenant-a
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: tenant-isolation
  namespace: tenant-a
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
  ingress:
    # Only from same tenant
    - from:
        - namespaceSelector:
            matchLabels:
              tenant: tenant-a
  egress:
    # DNS
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
      ports:
        - protocol: UDP
          port: 53
    # Same tenant
    - to:
        - namespaceSelector:
            matchLabels:
              tenant: tenant-a
    # Shared services
    - to:
        - namespaceSelector:
            matchLabels:
              shared-services: "true"
```

---

## Part 5: Application Policies

### 5.1 Three-Tier Application

```yaml
# three-tier-policies.yaml
---
# Frontend policy
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-policy
  namespace: production
spec:
  podSelector:
    matchLabels:
      tier: frontend
  policyTypes:
    - Ingress
    - Egress
  ingress:
    # Allow from ingress controller
    - from:
        - namespaceSelector:
            matchLabels:
              name: ingress-nginx
      ports:
        - protocol: TCP
          port: 80
  egress:
    # DNS
    - ports:
        - protocol: UDP
          port: 53
    # To backend
    - to:
        - podSelector:
            matchLabels:
              tier: backend
      ports:
        - protocol: TCP
          port: 8080
---
# Backend policy
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-policy
  namespace: production
spec:
  podSelector:
    matchLabels:
      tier: backend
  policyTypes:
    - Ingress
    - Egress
  ingress:
    # From frontend only
    - from:
        - podSelector:
            matchLabels:
              tier: frontend
      ports:
        - protocol: TCP
          port: 8080
  egress:
    # DNS
    - ports:
        - protocol: UDP
          port: 53
    # To database
    - to:
        - podSelector:
            matchLabels:
              tier: database
      ports:
        - protocol: TCP
          port: 5432
---
# Database policy
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: database-policy
  namespace: production
spec:
  podSelector:
    matchLabels:
      tier: database
  policyTypes:
    - Ingress
    - Egress
  ingress:
    # From backend only
    - from:
        - podSelector:
            matchLabels:
              tier: backend
      ports:
        - protocol: TCP
          port: 5432
  egress:
    # DNS only (for potential replication)
    - ports:
        - protocol: UDP
          port: 53
```

### 5.2 Microservices Mesh Policy

```yaml
# microservices-policy.yaml
---
# API Gateway
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-gateway-policy
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: api-gateway
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: ingress-nginx
      ports:
        - protocol: TCP
          port: 8080
  egress:
    - ports:
        - protocol: UDP
          port: 53
    # Allow to all microservices
    - to:
        - podSelector:
            matchLabels:
              type: microservice
      ports:
        - protocol: TCP
          port: 8080
---
# Inter-service communication
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: microservice-policy
  namespace: production
spec:
  podSelector:
    matchLabels:
      type: microservice
  policyTypes:
    - Ingress
    - Egress
  ingress:
    # From API gateway
    - from:
        - podSelector:
            matchLabels:
              app: api-gateway
      ports:
        - protocol: TCP
          port: 8080
    # From other microservices (for service-to-service calls)
    - from:
        - podSelector:
            matchLabels:
              type: microservice
      ports:
        - protocol: TCP
          port: 8080
  egress:
    # DNS
    - ports:
        - protocol: UDP
          port: 53
    # Other microservices
    - to:
        - podSelector:
            matchLabels:
              type: microservice
      ports:
        - protocol: TCP
          port: 8080
    # Message queue
    - to:
        - podSelector:
            matchLabels:
              app: rabbitmq
      ports:
        - protocol: TCP
          port: 5672
    # Cache
    - to:
        - podSelector:
            matchLabels:
              app: redis
      ports:
        - protocol: TCP
          port: 6379
```

---

## Part 6: Testing Network Policies

### 6.1 Testing Script

```bash
#!/bin/bash
# test-network-policies.sh

NAMESPACE=${1:-production}

echo "=== Network Policy Tests for $NAMESPACE ==="

# Create test pods
kubectl run test-client \
  --image=nicolaka/netshoot \
  --namespace=$NAMESPACE \
  --labels="app=test-client" \
  --command -- sleep infinity

kubectl run test-server \
  --image=nginx \
  --namespace=$NAMESPACE \
  --labels="app=test-server" \
  --port=80

# Wait for pods
kubectl wait --for=condition=Ready pod/test-client -n $NAMESPACE --timeout=60s
kubectl wait --for=condition=Ready pod/test-server -n $NAMESPACE --timeout=60s

SERVER_IP=$(kubectl get pod test-server -n $NAMESPACE -o jsonpath='{.status.podIP}')

# Test connectivity
echo -e "\n--- Testing connectivity to test-server ---"
kubectl exec test-client -n $NAMESPACE -- \
  curl -s --connect-timeout 5 http://$SERVER_IP:80 && echo "SUCCESS: Connected" || echo "BLOCKED: Connection refused"

# Test DNS
echo -e "\n--- Testing DNS resolution ---"
kubectl exec test-client -n $NAMESPACE -- \
  nslookup kubernetes.default.svc.cluster.local && echo "SUCCESS: DNS works" || echo "BLOCKED: DNS failed"

# Test external connectivity
echo -e "\n--- Testing external connectivity ---"
kubectl exec test-client -n $NAMESPACE -- \
  curl -s --connect-timeout 5 https://google.com > /dev/null && echo "SUCCESS: External access" || echo "BLOCKED: No external access"

# Cleanup
kubectl delete pod test-client test-server -n $NAMESPACE
```

### 6.2 Policy Debugging

```bash
# List all network policies
kubectl get networkpolicy -A

# Describe policy
kubectl describe networkpolicy <name> -n <namespace>

# Check if CNI supports network policies
kubectl get pods -n kube-system | grep -E "calico|cilium|weave"

# View Calico policy status
calicoctl get networkpolicy -n production -o yaml

# View Cilium policy status
cilium policy get -n production
```

---

## Part 7: Hands-on Challenges

### Challenge 1: Zero-Trust Implementation

Implement zero-trust networking:
1. Default deny all in namespace
2. Allow only required communications
3. Test all service connectivity
4. Document allowed flows

### Challenge 2: Multi-Cluster Policies

Configure cross-cluster policies:
1. Set up cluster mesh
2. Define cross-cluster rules
3. Test service discovery
4. Implement failover policies

### Challenge 3: Policy Automation

Automate policy generation:
1. Analyze traffic patterns
2. Generate baseline policies
3. Test in audit mode
4. Deploy to production

---

## Verification Tasks

1. [ ] Implemented default deny
2. [ ] Created tiered application policies
3. [ ] Configured namespace isolation
4. [ ] Set up DNS egress rules
5. [ ] Tested all connectivity paths
6. [ ] Documented policy matrix

---

## Key Takeaways

- Network policies are additive (whitelist)
- Empty selector matches all pods
- Always allow DNS for service discovery
- Test policies thoroughly before production
- Use labels for flexible policy targeting
- Monitor and audit network flows

---

## Next Steps

Continue to [Exercise 4: OPA Gatekeeper](04-opa-gatekeeper.md)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Network Policy Basics
- Ingress Policies
- Egress Policies
- Namespace Isolation

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
