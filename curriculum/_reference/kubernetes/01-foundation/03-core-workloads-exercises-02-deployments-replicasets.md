# Exercise 2: Deployments and ReplicaSets

## Objectives

- Understand ReplicaSet controller behavior
- Master Deployment strategies
- Perform rolling updates and rollbacks
- Configure deployment specifications

## Prerequisites

- Completed Exercise 1
- Understanding of Pod concepts
- kubectl proficiency

---

## Part 1: ReplicaSets

### 1.1 Understanding ReplicaSets

ReplicaSets ensure a specified number of pod replicas are running.

```yaml
# replicaset.yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: nginx-rs
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
      tier: frontend
  template:
    metadata:
      labels:
        app: nginx
        tier: frontend
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
```

```bash
kubectl apply -f replicaset.yaml

# Watch pods being created
kubectl get pods -l app=nginx -w

# Check ReplicaSet status
kubectl get rs nginx-rs
kubectl describe rs nginx-rs
```

### 1.2 ReplicaSet Behavior

```bash
# Delete a pod and watch recreation
kubectl delete pod -l app=nginx --wait=false
kubectl get pods -l app=nginx -w

# Scale manually
kubectl scale rs nginx-rs --replicas=5
kubectl get pods -l app=nginx

# Scale down
kubectl scale rs nginx-rs --replicas=2
kubectl get pods -l app=nginx

# Cleanup
kubectl delete rs nginx-rs
```

### 1.3 Label Selector Types

```yaml
# Match labels (equality-based)
selector:
  matchLabels:
    app: nginx

# Match expressions (set-based)
selector:
  matchExpressions:
  - key: app
    operator: In
    values:
    - nginx
    - web
  - key: environment
    operator: NotIn
    values:
    - production
  - key: tier
    operator: Exists
```

---

## Part 2: Deployments

### 2.1 Basic Deployment

```yaml
# deployment.yaml
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
    spec:
      containers:
      - name: nginx
        image: nginx:1.24
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
          limits:
            cpu: "200m"
            memory: "256Mi"
```

```bash
kubectl apply -f deployment.yaml

# Check all related resources
kubectl get deployment webapp
kubectl get rs -l app=webapp
kubectl get pods -l app=webapp

# Describe deployment
kubectl describe deployment webapp
```

### 2.2 Deployment Structure

**Deployment**

  - ReplicaSet (revision 1)
      - Pod
      - Pod
      - Pod
  - ReplicaSet (revision 2) [after update]
      - Pod
      - Pod
      - Pod


---

## Part 3: Rolling Updates

### 3.1 Performing an Update

```bash
# Update image
kubectl set image deployment/webapp nginx=nginx:1.25

# Watch rollout
kubectl rollout status deployment/webapp

# Check ReplicaSets
kubectl get rs -l app=webapp

# View rollout history
kubectl rollout history deployment/webapp
```

### 3.2 Update Strategies

```yaml
# rolling-update-strategy.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-rolling
spec:
  replicas: 10
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 2        # Max pods over desired count
      maxUnavailable: 1  # Max pods unavailable during update
  selector:
    matchLabels:
      app: webapp-rolling
  template:
    metadata:
      labels:
        app: webapp-rolling
    spec:
      containers:
      - name: nginx
        image: nginx:1.24
        ports:
        - containerPort: 80
```

```yaml
# recreate-strategy.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-recreate
spec:
  replicas: 3
  strategy:
    type: Recreate  # Kill all, then create new
  selector:
    matchLabels:
      app: webapp-recreate
  template:
    metadata:
      labels:
        app: webapp-recreate
    spec:
      containers:
      - name: nginx
        image: nginx:1.24
```

### 3.3 Controlling Rollout Speed

```yaml
# slow-rollout.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-slow
spec:
  replicas: 10
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0  # Zero downtime
  minReadySeconds: 30    # Wait 30s before considering pod ready
  progressDeadlineSeconds: 600  # Rollout timeout
  selector:
    matchLabels:
      app: webapp-slow
  template:
    metadata:
      labels:
        app: webapp-slow
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
```

---

## Part 4: Rollbacks

### 4.1 Rollback Commands

```bash
# View rollout history
kubectl rollout history deployment/webapp

# View specific revision
kubectl rollout history deployment/webapp --revision=2

# Rollback to previous revision
kubectl rollout undo deployment/webapp

# Rollback to specific revision
kubectl rollout undo deployment/webapp --to-revision=1

# Check status
kubectl rollout status deployment/webapp
```

### 4.2 Rollback Scenario

```bash
# Create deployment
kubectl create deployment rollback-demo --image=nginx:1.24 --replicas=3

# Record change with annotation
kubectl annotate deployment rollback-demo kubernetes.io/change-cause="Initial deployment v1.24"

# Update to 1.25
kubectl set image deployment/rollback-demo nginx=nginx:1.25
kubectl annotate deployment rollback-demo kubernetes.io/change-cause="Updated to v1.25"

# Simulate bad deployment
kubectl set image deployment/rollback-demo nginx=nginx:nonexistent
kubectl annotate deployment rollback-demo kubernetes.io/change-cause="Bad image"

# Watch failure
kubectl rollout status deployment/rollback-demo --timeout=30s

# Check history
kubectl rollout history deployment/rollback-demo

# Rollback
kubectl rollout undo deployment/rollback-demo

# Verify
kubectl get pods -l app=rollback-demo
kubectl describe deployment rollback-demo | grep Image

# Cleanup
kubectl delete deployment rollback-demo
```

### 4.3 Revision History Limit

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: limited-history
spec:
  replicas: 3
  revisionHistoryLimit: 5  # Keep only 5 old ReplicaSets
  selector:
    matchLabels:
      app: limited-history
  template:
    metadata:
      labels:
        app: limited-history
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
```

---

## Part 5: Advanced Deployment Patterns

### 5.1 Blue-Green Deployment

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
      - name: nginx
        image: nginx:1.24
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
      - name: nginx
        image: nginx:1.25
---
# service.yaml - Switch between blue/green
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

```bash
# Deploy both versions
kubectl apply -f blue-deployment.yaml
kubectl apply -f green-deployment.yaml

# Service points to blue
kubectl apply -f service.yaml

# Test blue
kubectl run test --rm -it --image=busybox -- wget -qO- webapp

# Switch to green (edit service selector)
kubectl patch svc webapp -p '{"spec":{"selector":{"version":"green"}}}'

# Test green
kubectl run test --rm -it --image=busybox -- wget -qO- webapp
```

### 5.2 Canary Deployment

```yaml
# stable-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-stable
spec:
  replicas: 9  # 90% of traffic
  selector:
    matchLabels:
      app: webapp
      track: stable
  template:
    metadata:
      labels:
        app: webapp
        track: stable
    spec:
      containers:
      - name: nginx
        image: nginx:1.24
---
# canary-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-canary
spec:
  replicas: 1  # 10% of traffic
  selector:
    matchLabels:
      app: webapp
      track: canary
  template:
    metadata:
      labels:
        app: webapp
        track: canary
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
---
# service.yaml - Routes to both
apiVersion: v1
kind: Service
metadata:
  name: webapp
spec:
  selector:
    app: webapp  # Matches both stable and canary
  ports:
  - port: 80
```

### 5.3 Pause and Resume

```bash
# Pause rollout for canary testing
kubectl rollout pause deployment/webapp

# Make changes while paused
kubectl set image deployment/webapp nginx=nginx:1.25
kubectl set resources deployment/webapp -c nginx --limits=cpu=500m,memory=512Mi

# Resume rollout
kubectl rollout resume deployment/webapp

# Watch rollout
kubectl rollout status deployment/webapp
```

---

## Part 6: Deployment Best Practices

### 6.1 Production Deployment Template

```yaml
# production-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-production
  labels:
    app: webapp
    environment: production
  annotations:
    kubernetes.io/change-cause: "Initial production deployment"
spec:
  replicas: 3
  revisionHistoryLimit: 10

  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0

  minReadySeconds: 10
  progressDeadlineSeconds: 600

  selector:
    matchLabels:
      app: webapp
      environment: production

  template:
    metadata:
      labels:
        app: webapp
        environment: production
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchLabels:
                  app: webapp
              topologyKey: kubernetes.io/hostname

      terminationGracePeriodSeconds: 30

      containers:
      - name: webapp
        image: webapp:1.0.0
        imagePullPolicy: IfNotPresent

        ports:
        - name: http
          containerPort: 8080
          protocol: TCP

        env:
        - name: ENVIRONMENT
          value: "production"
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name

        resources:
          requests:
            cpu: "250m"
            memory: "256Mi"
          limits:
            cpu: "1000m"
            memory: "512Mi"

        startupProbe:
          httpGet:
            path: /health/startup
            port: http
          failureThreshold: 30
          periodSeconds: 2

        livenessProbe:
          httpGet:
            path: /health/live
            port: http
          periodSeconds: 10
          failureThreshold: 3

        readinessProbe:
          httpGet:
            path: /health/ready
            port: http
          periodSeconds: 5
          failureThreshold: 3

        lifecycle:
          preStop:
            exec:
              command: ["/bin/sh", "-c", "sleep 10"]

        securityContext:
          runAsNonRoot: true
          runAsUser: 1000
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
```

---

## Part 7: Hands-on Challenges

### Challenge 1: Zero-Downtime Update

```bash
# Create deployment with 5 replicas
kubectl create deployment zero-downtime --image=nginx:1.24 --replicas=5

# Configure for zero downtime
kubectl patch deployment zero-downtime -p '
{
  "spec": {
    "strategy": {
      "type": "RollingUpdate",
      "rollingUpdate": {
        "maxSurge": 1,
        "maxUnavailable": 0
      }
    },
    "minReadySeconds": 5
  }
}'

# Add readiness probe
kubectl patch deployment zero-downtime --type=json -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/readinessProbe",
    "value": {
      "httpGet": {
        "path": "/",
        "port": 80
      },
      "periodSeconds": 2
    }
  }
]'

# Expose service
kubectl expose deployment zero-downtime --port=80

# In one terminal, continuously test
while true; do curl -s zero-downtime > /dev/null && echo "OK" || echo "FAIL"; sleep 0.5; done

# In another terminal, perform update
kubectl set image deployment/zero-downtime nginx=nginx:1.25

# Verify no failures during update
```

### Challenge 2: Automated Rollback

```bash
#!/bin/bash
# auto-rollback.sh

DEPLOYMENT=$1
TIMEOUT=${2:-120}

echo "Monitoring deployment: $DEPLOYMENT"
echo "Timeout: ${TIMEOUT}s"

if ! kubectl rollout status deployment/$DEPLOYMENT --timeout=${TIMEOUT}s; then
  echo "Rollout failed! Initiating rollback..."
  kubectl rollout undo deployment/$DEPLOYMENT

  echo "Waiting for rollback to complete..."
  kubectl rollout status deployment/$DEPLOYMENT --timeout=60s

  echo "Rollback completed"
  exit 1
fi

echo "Deployment successful!"
```

### Challenge 3: Multi-Version Deployment

Deploy an application with:
- 3 replicas of v1 (stable)
- 1 replica of v2 (canary)
- Single service routing to both
- Ability to gradually shift traffic

---

## Verification Tasks

1. [ ] Created ReplicaSet and observed self-healing
2. [ ] Deployed application with rolling update strategy
3. [ ] Performed image update and watched rollout
4. [ ] Successfully rolled back to previous version
5. [ ] Implemented blue-green deployment
6. [ ] Configured canary deployment with traffic split

---

## Key Takeaways

- ReplicaSets maintain desired pod count
- Deployments manage ReplicaSets for updates
- Rolling updates provide zero-downtime deployments
- Rollbacks enable quick recovery
- Advanced patterns (blue-green, canary) reduce risk

---

## Next Steps

Continue to [Exercise 3: StatefulSets](03-statefulsets.md)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- ReplicaSets
- Deployments
- Rolling Updates
- Rollbacks

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
