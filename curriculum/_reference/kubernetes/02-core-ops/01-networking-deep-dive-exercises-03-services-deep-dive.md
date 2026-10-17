# Exercise 3: Services Deep Dive

## Objectives

- Master all Service types
- Understand Service networking internals
- Configure external access patterns
- Implement session affinity

## Prerequisites

- Completed Exercises 1-2
- Understanding of kube-proxy
- Basic networking knowledge

---

## Part 1: Service Types

### 1.1 ClusterIP (Default)

```yaml
# clusterip-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: backend-clusterip
spec:
  type: ClusterIP
  selector:
    app: backend
  ports:
  - name: http
    port: 80           # Service port
    targetPort: 8080   # Container port
    protocol: TCP
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
spec:
  replicas: 3
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: backend
        image: hashicorp/http-echo
        args:
        - "-text=Hello from backend"
        - "-listen=:8080"
        ports:
        - containerPort: 8080
```

```bash
kubectl apply -f clusterip-service.yaml

# Service is only accessible within cluster
kubectl get svc backend-clusterip

# Test from within cluster
kubectl run test --rm -it --image=busybox -- wget -qO- backend-clusterip

# View endpoints
kubectl get endpoints backend-clusterip
```

### 1.2 NodePort

```yaml
# nodeport-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: backend-nodeport
spec:
  type: NodePort
  selector:
    app: backend
  ports:
  - port: 80
    targetPort: 8080
    nodePort: 30080    # Optional: auto-assigned if not specified (30000-32767)
```

```bash
kubectl apply -f nodeport-service.yaml

# Accessible on any node at nodePort
kubectl get svc backend-nodeport

# Access via node IP
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
curl $NODE_IP:30080
```

### 1.3 LoadBalancer

```yaml
# loadbalancer-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: backend-lb
  annotations:
    # Cloud-specific annotations
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
    service.beta.kubernetes.io/aws-load-balancer-internal: "false"
spec:
  type: LoadBalancer
  selector:
    app: backend
  ports:
  - port: 80
    targetPort: 8080
  # Optional: restrict source IPs
  loadBalancerSourceRanges:
  - 10.0.0.0/8
  - 192.168.0.0/16
```

```bash
kubectl apply -f loadbalancer-service.yaml

# Wait for external IP
kubectl get svc backend-lb -w

# Access via external IP
EXTERNAL_IP=$(kubectl get svc backend-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl $EXTERNAL_IP
```

### 1.4 ExternalName

```yaml
# externalname-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: external-db
spec:
  type: ExternalName
  externalName: database.example.com
```

```bash
kubectl apply -f externalname-service.yaml

# DNS resolution returns CNAME
kubectl run test --rm -it --image=busybox -- nslookup external-db
```

---

## Part 2: Headless Services

### 2.1 Basic Headless Service

```yaml
# headless-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: backend-headless
spec:
  clusterIP: None      # Headless
  selector:
    app: backend
  ports:
  - port: 8080
```

```bash
kubectl apply -f headless-service.yaml

# Returns all pod IPs instead of virtual IP
kubectl run test --rm -it --image=busybox -- nslookup backend-headless

# Compare with regular service
kubectl get svc backend-clusterip -o jsonpath='{.spec.clusterIP}'
```

### 2.2 StatefulSet with Headless Service

```yaml
# stateful-headless.yaml
apiVersion: v1
kind: Service
metadata:
  name: db-headless
spec:
  clusterIP: None
  selector:
    app: database
  ports:
  - port: 5432
    name: postgres
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: database
spec:
  serviceName: db-headless
  replicas: 3
  selector:
    matchLabels:
      app: database
  template:
    metadata:
      labels:
        app: database
    spec:
      containers:
      - name: postgres
        image: postgres:15
        env:
        - name: POSTGRES_PASSWORD
          value: password
        ports:
        - containerPort: 5432
```

```bash
kubectl apply -f stateful-headless.yaml

# Each pod gets DNS: <pod-name>.<service-name>.<namespace>.svc.cluster.local
kubectl run test --rm -it --image=busybox -- sh
nslookup database-0.db-headless
nslookup database-1.db-headless
nslookup database-2.db-headless
exit
```

---

## Part 3: Service Discovery

### 3.1 DNS-Based Discovery

```bash
# Service DNS formats:
# <service>.<namespace>.svc.cluster.local
# <service>.<namespace>.svc
# <service>.<namespace>
# <service> (same namespace)

kubectl run test --rm -it --image=busybox -- sh
nslookup backend-clusterip
nslookup backend-clusterip.default
nslookup backend-clusterip.default.svc
nslookup backend-clusterip.default.svc.cluster.local
exit
```

### 3.2 Environment Variable Discovery

```yaml
# env-discovery.yaml
apiVersion: v1
kind: Pod
metadata:
  name: env-discovery-test
spec:
  containers:
  - name: test
    image: busybox:1.36
    command: ["sh", "-c", "env | grep -i backend && sleep 3600"]
```

```bash
kubectl apply -f env-discovery.yaml

# Kubernetes automatically injects service info as env vars
kubectl logs env-discovery-test

# Format: <SERVICE_NAME>_SERVICE_HOST, <SERVICE_NAME>_SERVICE_PORT
# BACKEND_CLUSTERIP_SERVICE_HOST=10.96.x.x
# BACKEND_CLUSTERIP_SERVICE_PORT=80
```

---

## Part 4: Session Affinity

### 4.1 ClientIP Affinity

```yaml
# session-affinity.yaml
apiVersion: v1
kind: Service
metadata:
  name: sticky-service
spec:
  selector:
    app: backend
  ports:
  - port: 80
    targetPort: 8080
  sessionAffinity: ClientIP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 3600   # 1 hour
```

```bash
kubectl apply -f session-affinity.yaml

# Requests from same client IP go to same pod
kubectl run test --rm -it --image=busybox -- sh
for i in $(seq 1 10); do wget -qO- sticky-service; done
# Should see same backend response
exit
```

### 4.2 Testing Affinity

```bash
# Without affinity (round-robin)
for i in $(seq 1 10); do
  kubectl run test-$i --rm -it --restart=Never --image=busybox -- wget -qO- backend-clusterip 2>/dev/null
done

# With affinity (same backend)
kubectl run sticky-test --rm -it --image=busybox -- sh
for i in $(seq 1 10); do wget -qO- sticky-service; done
exit
```

---

## Part 5: External Traffic Policy

### 5.1 Cluster vs Local

```yaml
# external-traffic-policy.yaml
apiVersion: v1
kind: Service
metadata:
  name: local-traffic
spec:
  type: NodePort
  selector:
    app: backend
  ports:
  - port: 80
    targetPort: 8080
    nodePort: 30081
  externalTrafficPolicy: Local    # Preserve client IP
  # externalTrafficPolicy: Cluster  # Default - may hop nodes
```

**Cluster (default)**:
- Traffic may be routed to pods on other nodes
- Better load distribution
- Client IP is lost (SNAT)

**Local**:
- Traffic only to pods on receiving node
- Preserves client IP
- May cause uneven distribution

### 5.2 Testing External Traffic Policy

```bash
kubectl apply -f external-traffic-policy.yaml

# Check which node has pods
kubectl get pods -l app=backend -o wide

# Access from node without pods - returns error with Local policy
# Access from node with pods - works
```

---

## Part 6: Multi-Port Services

### 6.1 Multiple Ports

```yaml
# multi-port-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: multi-port
spec:
  selector:
    app: multi-app
  ports:
  - name: http        # Name required when multiple ports
    port: 80
    targetPort: 8080
  - name: https
    port: 443
    targetPort: 8443
  - name: metrics
    port: 9090
    targetPort: 9090
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: multi-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: multi-app
  template:
    metadata:
      labels:
        app: multi-app
    spec:
      containers:
      - name: app
        image: nginx:1.25
        ports:
        - containerPort: 8080
          name: http
        - containerPort: 8443
          name: https
        - containerPort: 9090
          name: metrics
```

### 6.2 Named Port References

```yaml
# Port name reference
apiVersion: v1
kind: Service
metadata:
  name: named-port-svc
spec:
  selector:
    app: webapp
  ports:
  - name: web
    port: 80
    targetPort: http   # References container port by name
```

---

## Part 7: Hands-on Challenges

### Challenge 1: Service Comparison

Create identical deployments and expose with each service type. Compare:
- Accessibility (internal vs external)
- Load balancing behavior
- Client IP preservation

### Challenge 2: Service Mesh Simulation

Create services that demonstrate:
- Service-to-service communication
- Session affinity for stateful requests
- Different traffic routing patterns

### Challenge 3: Production Service Design

Design a service topology for:
- Frontend (external access via LoadBalancer)
- Backend API (internal ClusterIP)
- Database (headless for StatefulSet)
- Cache (ClusterIP with session affinity)

---

## Verification Tasks

1. [ ] Created and tested all four service types
2. [ ] Configured headless service for StatefulSet
3. [ ] Implemented session affinity
4. [ ] Compared external traffic policies
5. [ ] Created multi-port service
6. [ ] Designed production service topology

---

## Key Takeaways

- ClusterIP for internal services
- NodePort for development/testing external access
- LoadBalancer for production external access
- Headless for direct pod access (StatefulSets)
- Session affinity for stateful applications
- External traffic policy affects client IP preservation

---

## Next Steps

Continue to [Exercise 4: DNS and Service Discovery](01-networking-deep-dive-exercises-04-dns-service-discovery.md)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Service Types
- Headless Services
- Service Discovery
- Session Affinity

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
