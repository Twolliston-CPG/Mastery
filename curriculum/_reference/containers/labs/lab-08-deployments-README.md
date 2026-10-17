# Lab 08: Kubernetes Deployments

## Objectives

- Create and manage Deployments
- Perform rolling updates and rollbacks
- Configure health probes
- Implement scaling strategies

## Prerequisites

- Completed Lab 07
- Running Kubernetes cluster
- kubectl configured

---

## Part 1: Deployment Basics (Guided)

### Step 1: Create Deployment

```yaml
# Create deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
  labels:
    app: webapp
spec:
  replicas: 3
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
        version: v1
    spec:
      containers:
      - name: webapp
        image: nginx:1.21
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
```

```bash
# Apply deployment
kubectl apply -f deployment.yaml

# View deployment
kubectl get deployments
kubectl describe deployment webapp

# View ReplicaSet
kubectl get rs

# View pods
kubectl get pods -l app=webapp
kubectl get pods -o wide
```

### Step 2: Rolling Updates

```bash
# Update image
kubectl set image deployment/webapp webapp=nginx:1.22

# Watch rollout
kubectl rollout status deployment/webapp

# View rollout history
kubectl rollout history deployment/webapp

# View specific revision
kubectl rollout history deployment/webapp --revision=2
```

### Step 3: Rollback

```bash
# Rollback to previous version
kubectl rollout undo deployment/webapp

# Rollback to specific revision
kubectl rollout undo deployment/webapp --to-revision=1

# Verify
kubectl rollout status deployment/webapp
kubectl get pods -l app=webapp
```

### Validation

```bash
#!/bin/bash
# validate-part1.sh

echo "=== Part 1 Validation ==="

# Check deployment exists
if kubectl get deployment webapp &> /dev/null; then
    echo "✓ Deployment exists"
else
    echo "✗ Deployment not found"
    exit 1
fi

# Check replicas
READY=$(kubectl get deployment webapp -o jsonpath='{.status.readyReplicas}')
DESIRED=$(kubectl get deployment webapp -o jsonpath='{.spec.replicas}')
if [ "$READY" = "$DESIRED" ]; then
    echo "✓ All replicas ready: $READY/$DESIRED"
else
    echo "✗ Not all replicas ready: $READY/$DESIRED"
fi

# Test rollout
kubectl set image deployment/webapp webapp=nginx:1.23 --record
kubectl rollout status deployment/webapp

REVISIONS=$(kubectl rollout history deployment/webapp --no-headers | wc -l)
if [ "$REVISIONS" -gt 1 ]; then
    echo "✓ Rollout history available: $REVISIONS revisions"
else
    echo "✗ No rollout history"
fi

echo "Part 1 validation complete!"
```

---

## Part 2: Update Strategies (Semi-Guided)

### Objective

Configure different deployment strategies.

### Tasks

1. Configure RollingUpdate with custom parameters
2. Test Recreate strategy
3. Implement blue-green deployment pattern

### RollingUpdate Configuration

```yaml
# rolling-update.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rolling-demo
spec:
  replicas: 4
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1          # Max pods above desired
      maxUnavailable: 0    # Zero downtime
  selector:
    matchLabels:
      app: rolling-demo
  template:
    metadata:
      labels:
        app: rolling-demo
    spec:
      containers:
      - name: app
        image: nginx:1.21
        ports:
        - containerPort: 80
```

### Recreate Strategy

```yaml
# recreate.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: recreate-demo
spec:
  replicas: 3
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: recreate-demo
  template:
    metadata:
      labels:
        app: recreate-demo
    spec:
      containers:
      - name: app
        image: nginx:1.21
```

### Blue-Green Pattern

```yaml
# blue-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-blue
spec:
  replicas: 3
  selector:
    matchLabels:
      app: webapp
      version: blue
  template:
    metadata:
      labels:
        app: webapp
        version: blue
    spec:
      containers:
      - name: app
        image: nginx:1.21
---
# green-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-green
spec:
  replicas: 3
  selector:
    matchLabels:
      app: webapp
      version: green
  template:
    metadata:
      labels:
        app: webapp
        version: green
    spec:
      containers:
      - name: app
        image: nginx:1.22
---
# service.yaml (switch between blue/green)
apiVersion: v1
kind: Service
metadata:
  name: webapp
spec:
  selector:
    app: webapp
    version: blue  # Change to 'green' to switch
  ports:
  - port: 80
```

### Validation

```bash
#!/bin/bash
# validate-part2.sh

echo "=== Part 2 Validation ==="

# Deploy blue-green
kubectl apply -f blue-deployment.yaml
kubectl apply -f green-deployment.yaml
kubectl apply -f service.yaml

sleep 10

# Check both deployments
BLUE_READY=$(kubectl get deployment webapp-blue -o jsonpath='{.status.readyReplicas}')
GREEN_READY=$(kubectl get deployment webapp-green -o jsonpath='{.status.readyReplicas}')

if [ "$BLUE_READY" -eq 3 ] && [ "$GREEN_READY" -eq 3 ]; then
    echo "✓ Both blue and green deployments ready"
else
    echo "✗ Deployments not ready: blue=$BLUE_READY, green=$GREEN_READY"
fi

# Test switching
kubectl patch service webapp -p '{"spec":{"selector":{"version":"green"}}}'
sleep 3

ENDPOINT_VERSION=$(kubectl get endpoints webapp -o jsonpath='{.subsets[0].addresses[0].targetRef.name}' | grep -o 'green\|blue')
if echo "$ENDPOINT_VERSION" | grep -q "green"; then
    echo "✓ Service switched to green"
else
    echo "✗ Service not switched properly"
fi

echo "Part 2 validation complete!"
```

---

## Part 3: Health Probes (Semi-Guided)

### Objective

Configure liveness, readiness, and startup probes.

### Tasks

1. Add liveness probe (container health)
2. Add readiness probe (traffic handling)
3. Add startup probe (initialization time)

### Probe Types

```yaml
# probes.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: probe-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: probe-demo
  template:
    metadata:
      labels:
        app: probe-demo
    spec:
      containers:
      - name: app
        image: nginx:alpine
        ports:
        - containerPort: 80

        # Liveness: Is the container alive?
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3

        # Readiness: Can it handle traffic?
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 3
          successThreshold: 1
          failureThreshold: 3

        # Startup: For slow-starting containers
        startupProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 0
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 30  # Allow 150s for startup
```

### Test Failing Probes

```yaml
# failing-probe.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: failing-probe
spec:
  replicas: 1
  selector:
    matchLabels:
      app: failing-probe
  template:
    metadata:
      labels:
        app: failing-probe
    spec:
      containers:
      - name: app
        image: nginx:alpine
        livenessProbe:
          httpGet:
            path: /nonexistent
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
```

```bash
# Watch the container restart
kubectl apply -f failing-probe.yaml
kubectl get pods -w

# Check events
kubectl describe pod -l app=failing-probe
```

### Validation

```bash
#!/bin/bash
# validate-part3.sh

echo "=== Part 3 Validation ==="

kubectl apply -f probes.yaml
sleep 20

# Check pod is ready
POD_READY=$(kubectl get pods -l app=probe-demo -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}')
if [ "$POD_READY" = "True" ]; then
    echo "✓ Pod ready (probes passing)"
else
    echo "✗ Pod not ready"
fi

# Check probe configuration
LIVENESS=$(kubectl get deployment probe-demo -o jsonpath='{.spec.template.spec.containers[0].livenessProbe.httpGet.path}')
READINESS=$(kubectl get deployment probe-demo -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.httpGet.path}')

if [ -n "$LIVENESS" ] && [ -n "$READINESS" ]; then
    echo "✓ Probes configured"
else
    echo "✗ Probes not configured"
fi

echo "Part 3 validation complete!"
```

---

## Part 4: Challenge - Production Deployment

### Objective

Create a production-ready deployment with all best practices.

### Requirements

1. **Deployment Configuration:**
   - 3 replicas minimum
   - Rolling update (maxSurge: 1, maxUnavailable: 0)
   - Resource requests and limits
   - All three probe types
   - Pod anti-affinity (spread across nodes)

2. **Service Configuration:**
   - ClusterIP service
   - Proper selectors

3. **Horizontal Pod Autoscaler:**
   - Min: 3, Max: 10
   - Target CPU: 70%

4. **Pod Disruption Budget:**
   - minAvailable: 2

### Application Files

```yaml
# Complete production deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: production-app
  labels:
    app: production
spec:
  replicas: 3
  revisionHistoryLimit: 5
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app: production
  template:
    metadata:
      labels:
        app: production
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchLabels:
                  app: production
              topologyKey: kubernetes.io/hostname
      containers:
      - name: app
        image: nginx:1.24
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 15
          periodSeconds: 20
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 10
        startupProbe:
          httpGet:
            path: /
            port: 80
          failureThreshold: 30
          periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: production-app
spec:
  selector:
    app: production
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: production-app
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: production-app
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: production-app
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: production
```

### Validation Script

```bash
#!/bin/bash
# validate-challenge.sh

echo "=== Challenge Validation ==="

# Check deployment
if kubectl get deployment production-app &> /dev/null; then
    echo "✓ Deployment exists"
else
    echo "✗ Deployment not found"
    exit 1
fi

# Check strategy
STRATEGY=$(kubectl get deployment production-app -o jsonpath='{.spec.strategy.type}')
MAX_SURGE=$(kubectl get deployment production-app -o jsonpath='{.spec.strategy.rollingUpdate.maxSurge}')
MAX_UNAVAIL=$(kubectl get deployment production-app -o jsonpath='{.spec.strategy.rollingUpdate.maxUnavailable}')

if [ "$STRATEGY" = "RollingUpdate" ] && [ "$MAX_UNAVAIL" = "0" ]; then
    echo "✓ Rolling update configured (maxUnavailable: 0)"
else
    echo "✗ Strategy not configured correctly"
fi

# Check HPA
if kubectl get hpa production-app &> /dev/null; then
    echo "✓ HPA configured"
    MIN=$(kubectl get hpa production-app -o jsonpath='{.spec.minReplicas}')
    MAX=$(kubectl get hpa production-app -o jsonpath='{.spec.maxReplicas}')
    echo "  Min: $MIN, Max: $MAX"
else
    echo "✗ HPA not found"
fi

# Check PDB
if kubectl get pdb production-app &> /dev/null; then
    echo "✓ PDB configured"
    MIN_AVAIL=$(kubectl get pdb production-app -o jsonpath='{.spec.minAvailable}')
    echo "  Min available: $MIN_AVAIL"
else
    echo "✗ PDB not found"
fi

# Check probes
LIVENESS=$(kubectl get deployment production-app -o jsonpath='{.spec.template.spec.containers[0].livenessProbe}')
READINESS=$(kubectl get deployment production-app -o jsonpath='{.spec.template.spec.containers[0].readinessProbe}')
STARTUP=$(kubectl get deployment production-app -o jsonpath='{.spec.template.spec.containers[0].startupProbe}')

if [ -n "$LIVENESS" ] && [ -n "$READINESS" ] && [ -n "$STARTUP" ]; then
    echo "✓ All probes configured"
else
    echo "✗ Not all probes configured"
fi

echo ""
echo "Challenge validation complete!"
```

---

## Deliverables

1. Production deployment manifest
2. HPA configuration
3. PDB configuration
4. Documentation of update strategy

## Commands Reference

```bash
# Deployment management
kubectl create deployment <name> --image=<image>
kubectl scale deployment <name> --replicas=<n>
kubectl set image deployment/<name> <container>=<image>

# Rollout management
kubectl rollout status deployment/<name>
kubectl rollout history deployment/<name>
kubectl rollout undo deployment/<name>
kubectl rollout pause deployment/<name>
kubectl rollout resume deployment/<name>

# Autoscaling
kubectl autoscale deployment <name> --min=3 --max=10 --cpu-percent=70
kubectl get hpa

# Pod disruption
kubectl get pdb
kubectl describe pdb <name>
```

## Resources

- [Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [Rolling Updates](https://kubernetes.io/docs/tutorials/kubernetes-basics/update/update-intro/)
- [Configure Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)

## Next Lab

Continue to [Lab 09: Services and Ingress](lab-09-services-ingress-README.md)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Deployment Basics
- Update Strategies
- Health Probes
- Challenge - Production Deployment

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
