# Lab 06: Deployment Strategies

## Overview

In this lab, you'll implement various deployment strategies including rolling updates, blue-green deployments, canary releases, and A/B testing. You'll use Kubernetes and service mesh technologies to achieve zero-downtime deployments.

**Duration**: 3-4 hours
**Difficulty**: Intermediate to Advanced

## Prerequisites

- Kubernetes cluster (minikube, kind, or cloud)
- kubectl configured
- Helm 3.x installed
- Basic understanding of Kubernetes concepts
- Familiarity with service mesh concepts

## Learning Objectives

- Implement rolling update deployments
- Configure blue-green deployments
- Set up canary releases with traffic splitting
- Implement A/B testing with feature flags
- Use Argo Rollouts for progressive delivery

## Lab Environment Setup

```bash
# Create lab directory
mkdir -p ~/deployment-strategies-lab && cd ~/deployment-strategies-lab

# Start minikube with sufficient resources
minikube start --memory=4096 --cpus=2 --addons=ingress

# Create namespaces for each strategy
kubectl create namespace rolling
kubectl create namespace blue-green
kubectl create namespace canary
kubectl create namespace ab-testing

# Create sample application
cat > app/main.go << 'EOF'
package main

import (
    "encoding/json"
    "fmt"
    "log"
    "net/http"
    "os"
)

type Response struct {
    Message string `json:"message"`
    Version string `json:"version"`
    Color   string `json:"color"`
    PodName string `json:"pod_name"`
}

func main() {
    version := os.Getenv("APP_VERSION")
    if version == "" {
        version = "1.0.0"
    }

    color := os.Getenv("APP_COLOR")
    if color == "" {
        color = "blue"
    }

    podName := os.Getenv("POD_NAME")
    if podName == "" {
        podName = "unknown"
    }

    http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
        resp := Response{
            Message: fmt.Sprintf("Hello from version %s!", version),
            Version: version,
            Color:   color,
            PodName: podName,
        }
        w.Header().Set("Content-Type", "application/json")
        json.NewEncoder(w).Encode(resp)
    })

    http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
        w.WriteHeader(http.StatusOK)
        w.Write([]byte("OK"))
    })

    log.Printf("Starting server version %s (%s)", version, color)
    http.ListenAndServe(":8080", nil)
}
EOF

# Create Dockerfile
cat > app/Dockerfile << 'EOF'
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY main.go .
RUN go build -o server main.go

FROM alpine:3.19
COPY --from=builder /app/server /server
EXPOSE 8080
CMD ["/server"]
EOF

# Build images for different versions
cd app
docker build -t demo-app:v1 --build-arg APP_VERSION=1.0.0 .
docker build -t demo-app:v2 --build-arg APP_VERSION=2.0.0 .
docker build -t demo-app:v3 --build-arg APP_VERSION=3.0.0 .

# Load images into minikube
minikube image load demo-app:v1
minikube image load demo-app:v2
minikube image load demo-app:v3
```

---

## Part 1: Guided Exercise - Rolling Update Deployment

### Step 1: Create Rolling Update Deployment

```bash
# Create deployment with rolling update strategy
cat > rolling-deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-app
  namespace: rolling
spec:
  replicas: 4
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1        # Max pods above desired during update
      maxUnavailable: 1  # Max pods unavailable during update
  selector:
    matchLabels:
      app: demo-app
  template:
    metadata:
      labels:
        app: demo-app
        version: v1
    spec:
      containers:
        - name: app
          image: demo-app:v1
          ports:
            - containerPort: 8080
          env:
            - name: APP_VERSION
              value: "1.0.0"
            - name: APP_COLOR
              value: "blue"
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
          resources:
            requests:
              cpu: 100m
              memory: 64Mi
            limits:
              cpu: 200m
              memory: 128Mi
          readinessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 5
          livenessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: demo-app
  namespace: rolling
spec:
  selector:
    app: demo-app
  ports:
    - port: 80
      targetPort: 8080
EOF

kubectl apply -f rolling-deployment.yaml
```

### Step 2: Monitor Rolling Update

```bash
# Watch the rollout in real-time
kubectl rollout status deployment/demo-app -n rolling

# In another terminal, watch pods
kubectl get pods -n rolling -w

# Update to v2
kubectl set image deployment/demo-app app=demo-app:v2 -n rolling

# Check rollout history
kubectl rollout history deployment/demo-app -n rolling

# Rollback if needed
kubectl rollout undo deployment/demo-app -n rolling

# Rollback to specific revision
kubectl rollout undo deployment/demo-app -n rolling --to-revision=1
```

### Step 3: Test with Traffic

```bash
# Port forward to test
kubectl port-forward svc/demo-app -n rolling 8080:80 &

# Send continuous requests during rollout
while true; do curl -s localhost:8080 | jq -r '.version'; sleep 0.5; done

# Trigger update and observe versions changing
kubectl set image deployment/demo-app app=demo-app:v2 -n rolling
```

---

## Part 2: Semi-Guided Exercise - Blue-Green Deployment

### Objective

Implement blue-green deployment with:
- Two identical production environments
- Instant traffic switching
- Easy rollback capability
- Zero-downtime deployments

### Requirements

1. **Create blue and green deployments**

<details>
<summary>Click for deployment hint</summary>

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-app-blue
  namespace: blue-green
spec:
  replicas: 3
  selector:
    matchLabels:
      app: demo-app
      version: blue
  template:
    metadata:
      labels:
        app: demo-app
        version: blue
    spec:
      containers:
        - name: app
          image: demo-app:v1
          env:
            - name: APP_COLOR
              value: "blue"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-app-green
  namespace: blue-green
spec:
  replicas: 3
  selector:
    matchLabels:
      app: demo-app
      version: green
  template:
    metadata:
      labels:
        app: demo-app
        version: green
    spec:
      containers:
        - name: app
          image: demo-app:v2
          env:
            - name: APP_COLOR
              value: "green"
```
</details>

2. **Create service for traffic switching**

<details>
<summary>Click for service hint</summary>

```yaml
apiVersion: v1
kind: Service
metadata:
  name: demo-app
  namespace: blue-green
spec:
  selector:
    app: demo-app
    version: blue  # Switch to 'green' to change traffic
  ports:
    - port: 80
      targetPort: 8080
```
</details>

3. **Create switch script**

<details>
<summary>Click for script hint</summary>

```bash
#!/bin/bash
# switch-traffic.sh

CURRENT=$(kubectl get svc demo-app -n blue-green -o jsonpath='{.spec.selector.version}')
if [ "$CURRENT" == "blue" ]; then
    NEW="green"
else
    NEW="blue"
fi

kubectl patch svc demo-app -n blue-green -p "{\"spec\":{\"selector\":{\"version\":\"$NEW\"}}}"
echo "Switched traffic from $CURRENT to $NEW"
```
</details>

### Tasks

1. Deploy blue version with 3 replicas
2. Deploy green version with new code (initially 0 replicas)
3. Scale green to 3 replicas and test internally
4. Switch traffic from blue to green
5. Verify all traffic goes to green
6. Practice rollback by switching back to blue

### Validation

```bash
# Verify deployments
kubectl get deployments -n blue-green

# Check which version is active
kubectl get svc demo-app -n blue-green -o jsonpath='{.spec.selector.version}'

# Test traffic
for i in {1..10}; do
    curl -s localhost:8080 | jq -r '.color'
done | sort | uniq -c
```

---

## Part 3: Challenge - Canary Deployment with Argo Rollouts

### Objective

Implement sophisticated canary deployments using Argo Rollouts:
- Gradual traffic shifting
- Automated analysis
- Automatic rollback on failure
- Integration with metrics

### Requirements

1. **Install Argo Rollouts**

```bash
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

# Install kubectl plugin
brew install argoproj/tap/kubectl-argo-rollouts
# or
curl -LO https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64
chmod +x kubectl-argo-rollouts-linux-amd64
sudo mv kubectl-argo-rollouts-linux-amd64 /usr/local/bin/kubectl-argo-rollouts
```

2. **Create Rollout resource**

3. **Configure AnalysisTemplate**

4. **Set up traffic management**

### Success Criteria

- [ ] Argo Rollouts installed and running
- [ ] Rollout resource deployed
- [ ] Canary progresses through 10%, 30%, 50%, 100%
- [ ] Analysis runs at each step
- [ ] Automatic rollback on failed analysis
- [ ] Dashboard accessible

### Starting Point - Rollout with Canary

```yaml
# canary-rollout.yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: demo-app
  namespace: canary
spec:
  replicas: 5
  strategy:
    canary:
      canaryService: demo-app-canary
      stableService: demo-app-stable
      trafficRouting:
        nginx:
          stableIngress: demo-app-ingress
      steps:
        - setWeight: 10
        - pause: {duration: 30s}
        - analysis:
            templates:
              - templateName: success-rate
        - setWeight: 30
        - pause: {duration: 30s}
        - analysis:
            templates:
              - templateName: success-rate
        - setWeight: 50
        - pause: {duration: 30s}
        - setWeight: 100
      analysis:
        successfulRunHistoryLimit: 3
        unsuccessfulRunHistoryLimit: 3
  revisionHistoryLimit: 3
  selector:
    matchLabels:
      app: demo-app
  template:
    metadata:
      labels:
        app: demo-app
    spec:
      containers:
        - name: app
          image: demo-app:v1
          ports:
            - containerPort: 8080
          resources:
            requests:
              cpu: 100m
              memory: 64Mi
---
apiVersion: v1
kind: Service
metadata:
  name: demo-app-stable
  namespace: canary
spec:
  selector:
    app: demo-app
  ports:
    - port: 80
      targetPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: demo-app-canary
  namespace: canary
spec:
  selector:
    app: demo-app
  ports:
    - port: 80
      targetPort: 8080
```

### Starting Point - Analysis Template

```yaml
# analysis-template.yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: success-rate
  namespace: canary
spec:
  args:
    - name: service-name
      value: demo-app-canary
  metrics:
    - name: success-rate
      interval: 30s
      count: 3
      successCondition: result[0] >= 0.95
      failureLimit: 1
      provider:
        prometheus:
          address: http://prometheus.monitoring:9090
          query: |
            sum(rate(http_requests_total{service="{{args.service-name}}",status=~"2.*"}[1m])) /
            sum(rate(http_requests_total{service="{{args.service-name}}"}[1m]))
    - name: latency-p99
      interval: 30s
      count: 3
      successCondition: result[0] < 500
      failureLimit: 1
      provider:
        prometheus:
          address: http://prometheus.monitoring:9090
          query: |
            histogram_quantile(0.99,
              sum(rate(http_request_duration_seconds_bucket{service="{{args.service-name}}"}[1m]))
              by (le))
```

### A/B Testing Configuration

```yaml
# ab-testing-rollout.yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: demo-app-ab
  namespace: ab-testing
spec:
  replicas: 4
  strategy:
    canary:
      stableService: demo-app-stable
      canaryService: demo-app-canary
      trafficRouting:
        istio:
          virtualService:
            name: demo-app-vsvc
            routes:
              - primary
          destinationRule:
            name: demo-app-destrule
            canarySubsetName: canary
            stableSubsetName: stable
      steps:
        - setHeaderRoute:
            name: header-route
            match:
              - headerName: X-Canary
                headerValue:
                  exact: "true"
        - pause: {}  # Wait for manual promotion
  selector:
    matchLabels:
      app: demo-app
  template:
    metadata:
      labels:
        app: demo-app
    spec:
      containers:
        - name: app
          image: demo-app:v1
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: demo-app-vsvc
  namespace: ab-testing
spec:
  hosts:
    - demo-app
  http:
    - name: primary
      route:
        - destination:
            host: demo-app-stable
          weight: 100
        - destination:
            host: demo-app-canary
          weight: 0
```

### Validation Script

```bash
#!/bin/bash
# validate-deployment-strategies.sh

echo "Validating Deployment Strategies..."

# Check rolling deployment
echo "=== Rolling Deployment ==="
if kubectl get deployment demo-app -n rolling &>/dev/null; then
    REPLICAS=$(kubectl get deployment demo-app -n rolling -o jsonpath='{.status.readyReplicas}')
    echo "✓ Rolling deployment: $REPLICAS replicas ready"
else
    echo "✗ Rolling deployment not found"
fi

# Check blue-green deployments
echo "=== Blue-Green Deployment ==="
for color in blue green; do
    if kubectl get deployment demo-app-$color -n blue-green &>/dev/null; then
        echo "✓ $color deployment exists"
    else
        echo "✗ $color deployment not found"
    fi
done

ACTIVE=$(kubectl get svc demo-app -n blue-green -o jsonpath='{.spec.selector.version}' 2>/dev/null)
echo "Active version: $ACTIVE"

# Check Argo Rollouts
echo "=== Canary with Argo Rollouts ==="
if kubectl get rollout demo-app -n canary &>/dev/null; then
    STATUS=$(kubectl argo rollouts status demo-app -n canary --timeout 5s 2>&1 | head -1)
    echo "✓ Rollout status: $STATUS"
else
    echo "✗ Rollout not found"
fi

# Check analysis templates
ANALYSES=$(kubectl get analysistemplate -n canary -o name 2>/dev/null | wc -l)
echo "✓ Found $ANALYSES analysis templates"

echo "Validation complete!"
```

---

## Cleanup

```bash
# Delete namespaces
kubectl delete namespace rolling blue-green canary ab-testing argo-rollouts

# Stop minikube
minikube stop

# Remove lab files
cd ~
rm -rf deployment-strategies-lab
```

## Summary

In this lab, you learned:
- Implementing rolling update deployments with Kubernetes
- Configuring blue-green deployments for instant traffic switching
- Setting up canary releases with Argo Rollouts
- Implementing automated analysis for deployment validation
- Using traffic management for A/B testing

## Next Steps

- Explore Flagger for progressive delivery
- Implement GitOps with ArgoCD and Argo Rollouts
- Set up automated rollbacks based on custom metrics
- Integrate with feature flag systems

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Challenge - Canary Deployment with Argo Rollouts
- Create Rolling Update Deployment
- Monitor Rolling Update
- Test with Traffic

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"The pipeline deploys the application."* |
| ✓ | *"CI writes a new image tag into a config repository and stops. A controller running *inside* the cluster polls that repo, diffs the rendered manifests against live state, and applies the difference — so nothing outside the cluster ever holds credentials to it."* |

**Trace it:** `git push` → the new version serving traffic, with nothing else typed. Name where the handoff between CI and CD happens, and what that handoff physically is.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** the four [OpenGitOps principles](https://opengitops.dev/#principles) — then say which one a `kubectl apply` inside CI violates.
Full list per domain: [`SOURCES.md`](../../SOURCES.md#cicd-gitops)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../../MASTERY.md)

<!-- /feynman-check -->
