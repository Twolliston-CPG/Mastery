# Exercise 1: Implementing Network Policies

## Objective

Learn to secure your Kubernetes cluster by implementing network policies that control traffic flow between pods, namespaces, and external endpoints.

## Prerequisites

- Running Kubernetes cluster with a CNI that supports NetworkPolicy (Calico, Cilium, or Weave)
- Basic understanding of Kubernetes networking concepts
- `kubectl` configured

## Verify CNI Support

```bash
# Check if your CNI supports NetworkPolicy
kubectl get pods -n kube-system | grep -E "(calico|cilium|weave)"

# For kind clusters, Calico can be installed:
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
```

## Scenario

You're securing a three-tier application with:
- Frontend pods (public-facing)
- Backend API pods (internal only)
- Database pods (only accessible from backend)

## Setup

Create the test environment:

```yaml
# setup.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: netpol-lab
  labels:
    purpose: network-policy-testing
---
# Frontend deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: netpol-lab
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
      tier: web
  template:
    metadata:
      labels:
        app: frontend
        tier: web
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
  name: frontend
  namespace: netpol-lab
spec:
  selector:
    app: frontend
  ports:
  - port: 80
---
# Backend deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: netpol-lab
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
      tier: api
  template:
    metadata:
      labels:
        app: backend
        tier: api
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: netpol-lab
spec:
  selector:
    app: backend
  ports:
  - port: 8080
---
# Database deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: database
  namespace: netpol-lab
spec:
  replicas: 1
  selector:
    matchLabels:
      app: database
      tier: db
  template:
    metadata:
      labels:
        app: database
        tier: db
    spec:
      containers:
      - name: postgres
        image: postgres:15-alpine
        env:
        - name: POSTGRES_PASSWORD
          value: testpassword
        ports:
        - containerPort: 5432
---
apiVersion: v1
kind: Service
metadata:
  name: database
  namespace: netpol-lab
spec:
  selector:
    app: database
  ports:
  - port: 5432
```

Apply the setup:
```bash
kubectl apply -f setup.yaml
kubectl get pods -n netpol-lab
```

## Tasks

### Task 1: Default Deny All Ingress

Create a policy that denies all incoming traffic by default:

```yaml
# 01-default-deny-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: netpol-lab
spec:
  podSelector: {}  # Applies to all pods
  policyTypes:
  - Ingress
```

**Test it:**
```bash
# Deploy a test pod
kubectl run test-pod --image=busybox -n netpol-lab -- sleep 3600

# Try to reach frontend (should fail after policy is applied)
kubectl exec -n netpol-lab test-pod -- wget -qO- --timeout=2 http://frontend
```

### Task 2: Allow Frontend to Receive External Traffic

Create a policy allowing ingress to frontend pods:

```yaml
# 02-allow-frontend-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-ingress
  namespace: netpol-lab
spec:
  podSelector:
    matchLabels:
      app: frontend
  policyTypes:
  - Ingress
  ingress:
  - from: []  # Allow from anywhere
    ports:
    - protocol: TCP
      port: 80
```

**Test it:**
```bash
kubectl exec -n netpol-lab test-pod -- wget -qO- --timeout=2 http://frontend
# Should succeed now
```

### Task 3: Backend Only Accessible from Frontend

Create a policy that only allows frontend pods to access backend:

```yaml
# 03-backend-from-frontend-only.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-from-frontend-only
  namespace: netpol-lab
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

**Test it:**
```bash
# From test pod (should fail)
kubectl exec -n netpol-lab test-pod -- wget -qO- --timeout=2 http://backend:8080

# From frontend pod (should succeed)
FRONTEND_POD=$(kubectl get pod -n netpol-lab -l app=frontend -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n netpol-lab $FRONTEND_POD -- wget -qO- --timeout=2 http://backend:8080
```

### Task 4: Database Only Accessible from Backend

```yaml
# 04-database-from-backend-only.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: database-from-backend-only
  namespace: netpol-lab
spec:
  podSelector:
    matchLabels:
      app: database
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: backend
    ports:
    - protocol: TCP
      port: 5432
```

### Task 5: Egress Control

Create a policy that restricts egress from the database to only DNS:

```yaml
# 05-database-egress.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: database-egress
  namespace: netpol-lab
spec:
  podSelector:
    matchLabels:
      app: database
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector: {}
      podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - protocol: UDP
      port: 53
```

### Task 6: Cross-Namespace Policy

Create a monitoring namespace and allow it to scrape metrics:

```yaml
# 06-allow-monitoring.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring
  labels:
    purpose: monitoring
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-prometheus-scrape
  namespace: netpol-lab
spec:
  podSelector: {}  # All pods
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          purpose: monitoring
    ports:
    - protocol: TCP
      port: 9090
```

### Task 7: Allow Specific CIDR Blocks

Allow backend to reach external APIs:

```yaml
# 07-allow-external-api.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-egress
  namespace: netpol-lab
spec:
  podSelector:
    matchLabels:
      app: backend
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
  # Allow database
  - to:
    - podSelector:
        matchLabels:
          app: database
    ports:
    - protocol: TCP
      port: 5432
  # Allow external API (example IP range)
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

## Validation

Run a comprehensive test:

```bash
#!/bin/bash
echo "=== Network Policy Validation ==="

# Test frontend accessibility
echo -n "Frontend from external: "
kubectl exec -n netpol-lab test-pod -- wget -qO- --timeout=2 http://frontend > /dev/null 2>&1 && echo "PASS" || echo "FAIL"

# Test backend isolation
echo -n "Backend from test-pod (should fail): "
kubectl exec -n netpol-lab test-pod -- wget -qO- --timeout=2 http://backend:8080 > /dev/null 2>&1 && echo "FAIL" || echo "PASS"

# Test frontend to backend
FRONTEND_POD=$(kubectl get pod -n netpol-lab -l app=frontend -o jsonpath='{.items[0].metadata.name}')
echo -n "Backend from frontend: "
kubectl exec -n netpol-lab $FRONTEND_POD -- wget -qO- --timeout=2 http://backend:8080 > /dev/null 2>&1 && echo "PASS" || echo "FAIL"

# Test database isolation
echo -n "Database from frontend (should fail): "
kubectl exec -n netpol-lab $FRONTEND_POD -- nc -zv database 5432 2>&1 | grep -q "succeeded" && echo "FAIL" || echo "PASS"

# Test backend to database
BACKEND_POD=$(kubectl get pod -n netpol-lab -l app=backend -o jsonpath='{.items[0].metadata.name}')
echo -n "Database from backend: "
kubectl exec -n netpol-lab $BACKEND_POD -- nc -zv database 5432 2>&1 | grep -q "succeeded" && echo "PASS" || echo "FAIL"
```

## Success Criteria

- [ ] Default deny policy blocks all ingress by default
- [ ] Frontend is accessible from outside
- [ ] Backend is only accessible from frontend pods
- [ ] Database is only accessible from backend pods
- [ ] Egress is properly controlled
- [ ] Cross-namespace policies work correctly

## Solution

<details>
<summary>Click to reveal complete policy set</summary>

```yaml
# complete-network-policies.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: netpol-lab
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns-egress
  namespace: netpol-lab
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: UDP
      port: 53
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-policy
  namespace: netpol-lab
spec:
  podSelector:
    matchLabels:
      app: frontend
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from: []
    ports:
    - protocol: TCP
      port: 80
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: backend
    ports:
    - protocol: TCP
      port: 8080
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-policy
  namespace: netpol-lab
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: database
    ports:
    - protocol: TCP
      port: 5432
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: database-policy
  namespace: netpol-lab
spec:
  podSelector:
    matchLabels:
      app: database
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: backend
    ports:
    - protocol: TCP
      port: 5432
```

</details>

## Cleanup

```bash
kubectl delete namespace netpol-lab
kubectl delete namespace monitoring
```

## Next Exercise

Continue to [Exercise 2: Ingress Controllers](01-networking-deep-dive-exercises-02-ingress-controllers.md) to learn about exposing services externally.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Verify CNI Support
- Default Deny All Ingress
- Allow Frontend to Receive External Traffic
- Backend Only Accessible from Frontend

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
