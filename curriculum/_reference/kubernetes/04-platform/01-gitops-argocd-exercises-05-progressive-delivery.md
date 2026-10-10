# Exercise 5: Progressive Delivery with Argo Rollouts

## Objectives

- Deploy and configure Argo Rollouts
- Implement canary deployments
- Configure blue-green deployments
- Integrate with analysis and metrics

## Prerequisites

- Completed Exercises 1-4
- ArgoCD running and configured
- Prometheus deployed for metrics

---

## Part 1: Argo Rollouts Overview

### 1.1 Progressive Delivery Strategies

**Canary** — shift traffic gradually, watch the metrics at each step

| Step | v1 | v2 |
|---|---|---|
| Start | 100% | — |
| 1 | 90% | 10% |
| 2 | 50% | 50% |
| Done | — | 100% |

**Blue-green** — run both, switch all at once

| Step | Blue | Green |
|---|---|---|
| Start | active | — |
| 1 | active | preview, receiving no production traffic |
| Done | — | active |

**Experiment (A/B)** — split by *user*, not by percentage of requests

| Baseline | Canary A | Canary B |
|---|---|---|
| 60% | 20% | 20% |

The three answer different questions. Canary asks *"is the new version broken?"* and the answer is a
metric. Blue-green asks *"can we go back instantly?"* and the answer is a service selector. An
experiment asks *"is the new version better?"* — which needs consistent user assignment and enough
traffic for the result to mean anything, and is a product decision wearing a deployment costume.

---

## Part 2: Installation

### 2.1 Install Argo Rollouts

```bash
# Create namespace
kubectl create namespace argo-rollouts

# Install Argo Rollouts
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

# Install kubectl plugin
curl -LO https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64
chmod +x kubectl-argo-rollouts-linux-amd64
sudo mv kubectl-argo-rollouts-linux-amd64 /usr/local/bin/kubectl-argo-rollouts

# Verify installation
kubectl argo rollouts version
```

### 2.2 Install Dashboard

```bash
# Deploy dashboard
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/dashboard-install.yaml

# Access dashboard
kubectl port-forward svc/argo-rollouts-dashboard -n argo-rollouts 3100:3100
```

---

## Part 3: Canary Deployments

### 3.1 Basic Canary Rollout

```yaml
# canary-rollout.yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: myapp
  namespace: production
spec:
  replicas: 10
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
        - name: myapp
          image: myapp:v1.0.0
          ports:
            - containerPort: 8080
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
  strategy:
    canary:
      steps:
        - setWeight: 10
        - pause: {duration: 5m}
        - setWeight: 30
        - pause: {duration: 5m}
        - setWeight: 50
        - pause: {duration: 5m}
        - setWeight: 80
        - pause: {duration: 5m}
```

### 3.2 Canary with Traffic Management

```yaml
# canary-traffic-management.yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: myapp
  namespace: production
spec:
  replicas: 10
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
        - name: myapp
          image: myapp:v1.0.0
          ports:
            - containerPort: 8080
  strategy:
    canary:
      canaryService: myapp-canary
      stableService: myapp-stable
      trafficRouting:
        nginx:
          stableIngress: myapp-ingress
          additionalIngressAnnotations:
            canary-by-header: X-Canary
      steps:
        - setWeight: 10
        - pause: {duration: 2m}
        - setWeight: 25
        - pause: {duration: 2m}
        - setWeight: 50
        - pause: {duration: 5m}
        - setWeight: 75
        - pause: {duration: 5m}
---
# Services
apiVersion: v1
kind: Service
metadata:
  name: myapp-stable
spec:
  selector:
    app: myapp
  ports:
    - port: 80
      targetPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: myapp-canary
spec:
  selector:
    app: myapp
  ports:
    - port: 80
      targetPort: 8080
---
# Ingress
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress
  annotations:
    nginx.ingress.kubernetes.io/canary: "true"
spec:
  ingressClassName: nginx
  rules:
    - host: myapp.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: myapp-stable
                port:
                  number: 80
```

### 3.3 Istio Traffic Routing

```yaml
# canary-istio.yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: myapp
spec:
  replicas: 10
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
        - name: myapp
          image: myapp:v1.0.0
  strategy:
    canary:
      canaryService: myapp-canary
      stableService: myapp-stable
      trafficRouting:
        istio:
          virtualServices:
            - name: myapp-vsvc
              routes:
                - primary
          destinationRule:
            name: myapp-destrule
            canarySubsetName: canary
            stableSubsetName: stable
      steps:
        - setWeight: 10
        - pause: {duration: 5m}
        - setWeight: 50
        - pause: {duration: 10m}
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: myapp-vsvc
spec:
  hosts:
    - myapp.example.com
  http:
    - name: primary
      route:
        - destination:
            host: myapp-stable
          weight: 100
        - destination:
            host: myapp-canary
          weight: 0
---
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: myapp-destrule
spec:
  host: myapp
  subsets:
    - name: stable
      labels:
        app: myapp
    - name: canary
      labels:
        app: myapp
```

---

## Part 4: Blue-Green Deployments

### 4.1 Basic Blue-Green

```yaml
# blue-green-rollout.yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: myapp
  namespace: production
spec:
  replicas: 5
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
        - name: myapp
          image: myapp:v1.0.0
          ports:
            - containerPort: 8080
  strategy:
    blueGreen:
      activeService: myapp-active
      previewService: myapp-preview
      autoPromotionEnabled: false  # Manual promotion required
      previewReplicaCount: 2
      scaleDownDelaySeconds: 60
---
apiVersion: v1
kind: Service
metadata:
  name: myapp-active
spec:
  selector:
    app: myapp
  ports:
    - port: 80
      targetPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: myapp-preview
spec:
  selector:
    app: myapp
  ports:
    - port: 80
      targetPort: 8080
```

### 4.2 Blue-Green with Auto Promotion

```yaml
# blue-green-auto-promotion.yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: myapp
spec:
  replicas: 5
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
        - name: myapp
          image: myapp:v1.0.0
  strategy:
    blueGreen:
      activeService: myapp-active
      previewService: myapp-preview
      autoPromotionEnabled: true
      autoPromotionSeconds: 300  # Auto promote after 5 minutes
      prePromotionAnalysis:
        templates:
          - templateName: smoke-tests
      postPromotionAnalysis:
        templates:
          - templateName: integration-tests
```

---

## Part 5: Analysis and Metrics

### 5.1 AnalysisTemplate with Prometheus

```yaml
# analysis-template.yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: success-rate
spec:
  args:
    - name: service-name
    - name: namespace
  metrics:
    - name: success-rate
      interval: 1m
      successCondition: result[0] >= 0.95
      failureCondition: result[0] < 0.90
      failureLimit: 3
      provider:
        prometheus:
          address: http://prometheus.monitoring:9090
          query: |
            sum(rate(http_requests_total{service="{{args.service-name}}", status=~"2.*"}[5m]))
            /
            sum(rate(http_requests_total{service="{{args.service-name}}"}[5m]))
```

### 5.2 Multi-Metric Analysis

```yaml
# comprehensive-analysis.yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: comprehensive-check
spec:
  args:
    - name: service-name
  metrics:
    # Success rate check
    - name: success-rate
      interval: 2m
      count: 5
      successCondition: result[0] >= 0.95
      provider:
        prometheus:
          address: http://prometheus.monitoring:9090
          query: |
            sum(rate(http_requests_total{service="{{args.service-name}}", status=~"2.*"}[5m]))
            /
            sum(rate(http_requests_total{service="{{args.service-name}}"}[5m]))

    # Latency check
    - name: latency-p99
      interval: 2m
      count: 5
      successCondition: result[0] < 500
      provider:
        prometheus:
          address: http://prometheus.monitoring:9090
          query: |
            histogram_quantile(0.99,
              sum(rate(http_request_duration_seconds_bucket{service="{{args.service-name}}"}[5m])) by (le)
            ) * 1000

    # Error rate check
    - name: error-rate
      interval: 2m
      count: 5
      successCondition: result[0] < 0.01
      provider:
        prometheus:
          address: http://prometheus.monitoring:9090
          query: |
            sum(rate(http_requests_total{service="{{args.service-name}}", status=~"5.*"}[5m]))
            /
            sum(rate(http_requests_total{service="{{args.service-name}}"}[5m]))
```

### 5.3 Rollout with Analysis

```yaml
# rollout-with-analysis.yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: myapp
spec:
  replicas: 10
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
        - name: myapp
          image: myapp:v1.0.0
  strategy:
    canary:
      canaryService: myapp-canary
      stableService: myapp-stable
      analysis:
        templates:
          - templateName: comprehensive-check
        args:
          - name: service-name
            value: myapp-canary
        startingStep: 1  # Start analysis after first step
      steps:
        - setWeight: 10
        - pause: {duration: 2m}
        - setWeight: 30
        - pause: {duration: 5m}
        - setWeight: 50
        - pause: {duration: 5m}
        - setWeight: 80
        - pause: {duration: 5m}
```

### 5.4 Web Analysis Provider

```yaml
# web-analysis.yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: smoke-test
spec:
  metrics:
    - name: smoke-test
      count: 1
      provider:
        web:
          url: http://smoke-test-service/run
          method: POST
          headers:
            - key: Content-Type
              value: application/json
          body: |
            {
              "target": "{{args.target-url}}",
              "tests": ["health", "api", "database"]
            }
          jsonPath: "{$.success}"
          timeoutSeconds: 300
```

---

## Part 6: Rollout Operations

### 6.1 CLI Commands

```bash
# Watch rollout status
kubectl argo rollouts get rollout myapp -n production -w

# Promote rollout (continue to next step)
kubectl argo rollouts promote myapp -n production

# Full promotion (skip remaining steps)
kubectl argo rollouts promote myapp -n production --full

# Abort rollout (rollback)
kubectl argo rollouts abort myapp -n production

# Retry aborted rollout
kubectl argo rollouts retry rollout myapp -n production

# Undo rollout (go back to previous version)
kubectl argo rollouts undo myapp -n production

# Undo to specific revision
kubectl argo rollouts undo myapp -n production --to-revision=3

# Pause rollout
kubectl argo rollouts pause myapp -n production

# Resume paused rollout
kubectl argo rollouts resume myapp -n production

# Set image (trigger rollout)
kubectl argo rollouts set image myapp myapp=myapp:v2.0.0 -n production

# Restart rollout
kubectl argo rollouts restart myapp -n production
```

### 6.2 Rollout Status

```bash
# Get detailed status
kubectl argo rollouts status myapp -n production

# Output:
# Name:            myapp
# Namespace:       production
# Status:          ✔ Healthy
# Strategy:        Canary
#   Step:          8/8
#   SetWeight:     100
#   ActualWeight:  100
# Images:          myapp:v2.0.0 (stable)
# Replicas:
#   Desired:       10
#   Current:       10
#   Updated:       10
#   Ready:         10
#   Available:     10
```

---

## Part 7: ArgoCD Integration

### 7.1 Rollout Application

```yaml
# argocd-rollout-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/org/myapp-config
    targetRevision: main
    path: rollouts
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### 7.2 Notifications for Rollouts

```yaml
# notifications-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-notifications-cm
  namespace: argocd
data:
  trigger.on-rollout-step-completed: |
    - send: [slack-rollout-step]
      when: app.status.operationState.phase == 'Succeeded'
  trigger.on-rollout-analysis-failed: |
    - send: [slack-rollout-failed]
      when: app.status.health.status == 'Degraded'
  template.slack-rollout-step: |
    message: |
      Rollout {{.app.metadata.name}} completed step {{.app.status.sync.revision}}
  template.slack-rollout-failed: |
    message: |
      :warning: Rollout {{.app.metadata.name}} analysis failed!
      Reason: {{.app.status.operationState.message}}
```

---

## Part 8: Advanced Patterns

### 8.1 Header-Based Routing

```yaml
# header-routing.yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: myapp
spec:
  replicas: 5
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
        - name: myapp
          image: myapp:v1.0.0
  strategy:
    canary:
      canaryService: myapp-canary
      stableService: myapp-stable
      trafficRouting:
        managedRoutes:
          - name: canary-header
        nginx:
          stableIngress: myapp-ingress
      steps:
        # Route specific users to canary via header
        - setCanaryScale:
            replicas: 2
        - setHeaderRoute:
            name: canary-header
            match:
              - headerName: X-Canary
                headerValue:
                  exact: "true"
        - pause: {}  # Wait for manual promotion
        # Gradually shift traffic
        - setWeight: 25
        - pause: {duration: 5m}
        - setWeight: 50
        - pause: {duration: 5m}
        - setWeight: 100
```

### 8.2 Experiment (A/B Testing)

```yaml
# experiment.yaml
apiVersion: argoproj.io/v1alpha1
kind: Experiment
metadata:
  name: myapp-experiment
spec:
  duration: 1h
  progressDeadlineSeconds: 3600
  templates:
    - name: baseline
      specRef: stable
      replicas: 2
    - name: canary-a
      specRef: canary
      replicas: 1
      selector:
        matchLabels:
          experiment: canary-a
      template:
        spec:
          containers:
            - name: myapp
              image: myapp:v2.0.0-variant-a
    - name: canary-b
      replicas: 1
      selector:
        matchLabels:
          experiment: canary-b
      template:
        spec:
          containers:
            - name: myapp
              image: myapp:v2.0.0-variant-b
  analyses:
    - name: compare-variants
      templateName: compare-variants
      args:
        - name: baseline-service
          value: baseline
        - name: canary-a-service
          value: canary-a
        - name: canary-b-service
          value: canary-b
```

---

## Part 9: Hands-on Challenges

### Challenge 1: Canary Pipeline

Implement full canary pipeline:
1. Create Rollout with canary strategy
2. Configure traffic management (Nginx/Istio)
3. Add analysis templates
4. Integrate with ArgoCD

### Challenge 2: Blue-Green with Analysis

Set up blue-green with validation:
1. Configure blue-green Rollout
2. Add pre-promotion analysis
3. Add post-promotion analysis
4. Test rollback scenarios

### Challenge 3: Multi-Service Rollout

Coordinate multiple services:
1. Create dependent Rollouts
2. Configure sync waves
3. Implement cross-service analysis
4. Test failure scenarios

---

## Verification Tasks

1. [ ] Installed Argo Rollouts
2. [ ] Created canary Rollout
3. [ ] Configured blue-green Rollout
4. [ ] Implemented analysis templates
5. [ ] Integrated with traffic management
6. [ ] Tested rollback procedures

---

## Key Takeaways

- Argo Rollouts extends Kubernetes deployments
- Canary for gradual traffic shifting
- Blue-green for instant switchover
- Analysis provides automated validation
- Integrate with service mesh for advanced routing
- ArgoCD syncs Rollout resources seamlessly

---

## Next Steps

Continue to [Exercise 6: Secrets Management](06-secrets-management.md)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Argo Rollouts Overview
- Canary Deployments
- Blue-Green Deployments
- Analysis and Metrics

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
