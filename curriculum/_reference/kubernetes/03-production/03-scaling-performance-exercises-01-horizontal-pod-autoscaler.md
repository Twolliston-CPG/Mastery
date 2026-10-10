# Exercise 1: Horizontal Pod Autoscaler

## Objective

Configure Horizontal Pod Autoscalers (HPA) using CPU, memory, and custom metrics to automatically scale workloads based on demand.

## Prerequisites

- Running Kubernetes cluster
- Metrics server installed
- Prometheus (for custom metrics)

## Tasks

### Task 1: Install Metrics Server

```bash
# Check if metrics server is running
kubectl get deployment metrics-server -n kube-system

# Install if not present
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# For local clusters (kind/minikube), you may need to add:
# --kubelet-insecure-tls flag to the deployment

# Verify
kubectl top nodes
kubectl top pods -A
```

### Task 2: Deploy Test Application

```yaml
# test-app.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: hpa-lab
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  namespace: hpa-lab
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
    spec:
      containers:
      - name: web
        image: nginx:alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 256Mi
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: web-app
  namespace: hpa-lab
spec:
  selector:
    app: web-app
  ports:
  - port: 80
    targetPort: 80
```

### Task 3: Create Basic HPA (CPU-based)

```yaml
# hpa-cpu.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: web-app-hpa-cpu
  namespace: hpa-lab
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web-app
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50
```

**Test scaling:**
```bash
# Apply HPA
kubectl apply -f hpa-cpu.yaml

# Watch HPA
kubectl get hpa -n hpa-lab -w

# Generate load (in another terminal)
kubectl run load-generator --image=busybox -n hpa-lab -- /bin/sh -c "while true; do wget -q -O- http://web-app; done"

# Observe scaling
kubectl get pods -n hpa-lab -w

# Clean up load generator
kubectl delete pod load-generator -n hpa-lab
```

### Task 4: HPA with Memory

```yaml
# hpa-memory.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: web-app-hpa-memory
  namespace: hpa-lab
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web-app
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 70
```

### Task 5: HPA with Multiple Metrics

```yaml
# hpa-multi-metric.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: web-app-hpa-multi
  namespace: hpa-lab
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web-app
  minReplicas: 2
  maxReplicas: 20
  metrics:
  # CPU metric
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50
  # Memory metric
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 70
  # Scaling behavior
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300  # Wait 5 min before scaling down
      policies:
      - type: Percent
        value: 10
        periodSeconds: 60
      - type: Pods
        value: 2
        periodSeconds: 60
      selectPolicy: Min  # Use the policy that results in fewer changes
    scaleUp:
      stabilizationWindowSeconds: 0  # Scale up immediately
      policies:
      - type: Percent
        value: 100
        periodSeconds: 15
      - type: Pods
        value: 4
        periodSeconds: 15
      selectPolicy: Max  # Use the policy that results in more pods
```

### Task 6: HPA with Custom Metrics (Prometheus)

First, install prometheus-adapter:
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus-adapter prometheus-community/prometheus-adapter \
  --namespace monitoring \
  --set prometheus.url=http://prometheus-operated.monitoring.svc \
  --set prometheus.port=9090
```

Configure custom metrics:
```yaml
# prometheus-adapter-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: adapter-config
  namespace: monitoring
data:
  config.yaml: |
    rules:
    - seriesQuery: 'http_requests_total{namespace!="",pod!=""}'
      resources:
        overrides:
          namespace: {resource: "namespace"}
          pod: {resource: "pod"}
      name:
        matches: "^(.*)_total$"
        as: "${1}_per_second"
      metricsQuery: 'sum(rate(<<.Series>>{<<.LabelMatchers>>}[2m])) by (<<.GroupBy>>)'
    - seriesQuery: 'http_request_duration_seconds_bucket{namespace!="",pod!=""}'
      resources:
        overrides:
          namespace: {resource: "namespace"}
          pod: {resource: "pod"}
      name:
        matches: "^(.*)_bucket$"
        as: "${1}_p99"
      metricsQuery: 'histogram_quantile(0.99, sum(rate(<<.Series>>{<<.LabelMatchers>>}[2m])) by (<<.GroupBy>>, le))'
```

```yaml
# hpa-custom-metrics.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: web-app-hpa-custom
  namespace: hpa-lab
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web-app
  minReplicas: 2
  maxReplicas: 20
  metrics:
  # Custom metric: requests per second
  - type: Pods
    pods:
      metric:
        name: http_requests_per_second
      target:
        type: AverageValue
        averageValue: 100  # 100 RPS per pod
  # External metric (e.g., queue length)
  - type: External
    external:
      metric:
        name: queue_messages_ready
        selector:
          matchLabels:
            queue: orders
      target:
        type: AverageValue
        averageValue: 30  # 30 messages per pod
```

### Task 7: HPA with Object Metrics

```yaml
# hpa-object-metrics.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: web-app-hpa-ingress
  namespace: hpa-lab
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web-app
  minReplicas: 2
  maxReplicas: 10
  metrics:
  # Scale based on Ingress requests
  - type: Object
    object:
      describedObject:
        apiVersion: networking.k8s.io/v1
        kind: Ingress
        name: web-app-ingress
      metric:
        name: requests-per-second
      target:
        type: Value
        value: 1000  # Total 1000 RPS across the ingress
```

### Task 8: Container Resource Metrics

```yaml
# hpa-container-resources.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: web-app-hpa-container
  namespace: hpa-lab
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web-app
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: ContainerResource
    containerResource:
      name: cpu
      container: web
      target:
        type: Utilization
        averageUtilization: 60
```

## Validation

```bash
# Check HPA status
kubectl get hpa -n hpa-lab

# Describe HPA for details
kubectl describe hpa web-app-hpa-multi -n hpa-lab

# Check if metrics are available
kubectl get --raw /apis/metrics.k8s.io/v1beta1/pods -n hpa-lab | jq

# Check custom metrics (if configured)
kubectl get --raw /apis/custom.metrics.k8s.io/v1beta1 | jq

# Watch scaling events
kubectl get events -n hpa-lab --field-selector reason=SuccessfulRescale
```

## Success Criteria

- [ ] Metrics server running and providing metrics
- [ ] HPA scales up under load
- [ ] HPA scales down after load decreases
- [ ] Multiple metrics work together
- [ ] Scaling behavior controls work as expected
- [ ] Custom metrics available (if Prometheus configured)

## Troubleshooting

```bash
# HPA shows "unknown" for metrics
kubectl describe hpa <name> -n <namespace>
# Check: Metrics server running? Pods have resource requests?

# HPA not scaling
# Check: Target threshold too high? Min replicas already met?
# Check: Stabilization window not elapsed?

# Custom metrics not working
kubectl get --raw "/apis/custom.metrics.k8s.io/v1beta1" | jq
# Check: Prometheus adapter running? Metrics query correct?
```

## Cleanup

```bash
kubectl delete namespace hpa-lab
```

## Next Exercise

Continue to [Exercise 2: Vertical Pod Autoscaler](./02-vertical-pod-autoscaler.md) to learn about automatic resource recommendations.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Install Metrics Server
- Deploy Test Application
- Create Basic HPA (CPU-based)
- HPA with Memory

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
