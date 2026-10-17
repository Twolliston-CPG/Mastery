# Exercise 4: Resource Optimization

## Objectives

- Analyze and optimize resource utilization
- Implement resource quotas and limit ranges
- Configure Quality of Service (QoS) classes
- Apply cost optimization strategies

## Prerequisites

- Completed Exercises 1-3
- Metrics Server deployed
- Understanding of resource requests and limits

---

## Part 1: Resource Analysis

### 1.1 Understanding Resource Types

| Kubernetes Resources |  |
|---|---|
| Compressible Resources (can be throttled): |  |
| ├── CPU |  |
|  | ├── Measured in millicores (1 CPU = 1000m) |
|  | ├── Requests: guaranteed minimum |
|  | └── Limits: maximum allowed (throttled if exceeded) |
| Incompressible Resources (cannot be throttled): |  |
| ├── Memory |  |
|  | ├── Measured in bytes (Mi, Gi) |
|  | ├── Requests: guaranteed minimum |
|  | └── Limits: OOM killed if exceeded |
| Extended Resources: |  |
| ├── GPUs (nvidia.com/gpu) |  |
| ├── Hugepages (hugepages-2Mi) |  |
| └── Custom resources (example.com/custom) |  |
| Node Allocatable = Capacity - System Reserved - Kube Reserved |  |


### 1.2 Current Usage Analysis

```bash
#!/bin/bash
# resource-analysis.sh

echo "=== Cluster Resource Analysis ==="

# Node capacity and allocatable
echo -e "\n--- Node Resources ---"
kubectl get nodes -o custom-columns=\
NAME:.metadata.name,\
CPU_CAPACITY:.status.capacity.cpu,\
MEM_CAPACITY:.status.capacity.memory,\
CPU_ALLOC:.status.allocatable.cpu,\
MEM_ALLOC:.status.allocatable.memory

# Top resource-consuming pods
echo -e "\n--- Top 10 CPU Consuming Pods ---"
kubectl top pods -A --sort-by=cpu | head -11

echo -e "\n--- Top 10 Memory Consuming Pods ---"
kubectl top pods -A --sort-by=memory | head -11

# Resource requests vs usage
echo -e "\n--- Resource Requests vs Actual Usage ---"
kubectl get pods -A -o json | jq -r '
  .items[] |
  select(.status.phase == "Running") |
  "\(.metadata.namespace)/\(.metadata.name): " +
  "CPU Request: \(.spec.containers[0].resources.requests.cpu // "none"), " +
  "Memory Request: \(.spec.containers[0].resources.requests.memory // "none")"
' | head -20
```

### 1.3 Namespace Resource Summary

```bash
#!/bin/bash
# namespace-resources.sh

echo "=== Namespace Resource Summary ==="

for ns in $(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}'); do
  # Get running pods in namespace
  pods=$(kubectl get pods -n $ns --field-selector=status.phase=Running -o json)

  # Calculate totals
  cpu_requests=$(echo $pods | jq '[.items[].spec.containers[].resources.requests.cpu // "0m" |
    gsub("m$"; "") | tonumber] | add // 0')
  mem_requests=$(echo $pods | jq '[.items[].spec.containers[].resources.requests.memory // "0Mi" |
    gsub("Mi$"; "") | gsub("Gi$"; "" | . + "000") | tonumber] | add // 0')

  echo "$ns: CPU Requests: ${cpu_requests}m, Memory Requests: ${mem_requests}Mi"
done
```

---

## Part 2: Resource Quotas

### 2.1 Basic Resource Quota

```yaml
# resource-quota-basic.yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
  namespace: production
spec:
  hard:
    # Compute resources
    requests.cpu: "20"
    requests.memory: 40Gi
    limits.cpu: "40"
    limits.memory: 80Gi

    # Object counts
    pods: "50"
    persistentvolumeclaims: "10"
    services: "20"
    secrets: "50"
    configmaps: "50"
```

### 2.2 Scoped Resource Quota

```yaml
# resource-quota-scoped.yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: priority-quota
  namespace: production
spec:
  hard:
    pods: "10"
    requests.cpu: "10"
    requests.memory: 20Gi
  scopeSelector:
    matchExpressions:
      - operator: In
        scopeName: PriorityClass
        values:
          - high-priority
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: best-effort-quota
  namespace: production
spec:
  hard:
    pods: "100"
  scopes:
    - BestEffort  # Only applies to BestEffort QoS pods
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: not-best-effort-quota
  namespace: production
spec:
  hard:
    pods: "50"
    requests.cpu: "30"
    requests.memory: 60Gi
  scopes:
    - NotBestEffort  # Applies to Guaranteed and Burstable pods
```

### 2.3 Storage Quota

```yaml
# storage-quota.yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: storage-quota
  namespace: production
spec:
  hard:
    # Total storage requests
    requests.storage: 500Gi

    # Per storage class quotas
    standard.storageclass.storage.k8s.io/requests.storage: 200Gi
    premium.storageclass.storage.k8s.io/requests.storage: 100Gi

    # PVC counts
    persistentvolumeclaims: "20"
    standard.storageclass.storage.k8s.io/persistentvolumeclaims: "15"
    premium.storageclass.storage.k8s.io/persistentvolumeclaims: "5"
```

---

## Part 3: Limit Ranges

### 3.1 Container Limit Range

```yaml
# limit-range-container.yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: container-limits
  namespace: production
spec:
  limits:
    - type: Container
      # Default values (applied if not specified)
      default:
        cpu: 500m
        memory: 512Mi
      # Default requests (applied if not specified)
      defaultRequest:
        cpu: 100m
        memory: 128Mi
      # Minimum allowed
      min:
        cpu: 50m
        memory: 64Mi
      # Maximum allowed
      max:
        cpu: 4
        memory: 8Gi
      # Max ratio of limit/request
      maxLimitRequestRatio:
        cpu: 10
        memory: 4
```

### 3.2 Pod Limit Range

```yaml
# limit-range-pod.yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: pod-limits
  namespace: production
spec:
  limits:
    - type: Pod
      min:
        cpu: 100m
        memory: 128Mi
      max:
        cpu: 8
        memory: 16Gi
```

### 3.3 PVC Limit Range

```yaml
# limit-range-pvc.yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: storage-limits
  namespace: production
spec:
  limits:
    - type: PersistentVolumeClaim
      min:
        storage: 1Gi
      max:
        storage: 100Gi
```

---

## Part 4: Quality of Service (QoS)

### 4.1 QoS Classes

**QoS classes**

The kubelet assigns a QoS class from the requests and limits you wrote; you
never set it directly. It decides who dies first when a node runs out of memory.

| Class | Condition | Eviction behaviour |
|---|---|---|
| **Guaranteed** | *Every* container sets memory limit = memory request **and** CPU limit = CPU request | Last to be evicted |
| **Burstable** | At least one container sets a memory or CPU request/limit, and requests ≠ limits | Evicted under node memory pressure, worst-overcommitted first |
| **BestEffort** | No requests and no limits anywhere in the pod | First to be evicted |

Eviction order: `BestEffort` → `Burstable` (those furthest over their request) → `Guaranteed`.

### 4.2 Guaranteed QoS Pod

```yaml
# guaranteed-qos-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: guaranteed-pod
  namespace: production
spec:
  containers:
    - name: app
      image: myapp:1.0
      resources:
        # Requests = Limits for Guaranteed QoS
        requests:
          cpu: 500m
          memory: 512Mi
        limits:
          cpu: 500m
          memory: 512Mi
```

### 4.3 Burstable QoS Pod

```yaml
# burstable-qos-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: burstable-pod
  namespace: production
spec:
  containers:
    - name: app
      image: myapp:1.0
      resources:
        # Requests < Limits for Burstable QoS
        requests:
          cpu: 100m
          memory: 128Mi
        limits:
          cpu: 1
          memory: 1Gi
```

### 4.4 Check QoS Class

```bash
# Check pod QoS class
kubectl get pod <pod-name> -o jsonpath='{.status.qosClass}'

# List all pods with QoS class
kubectl get pods -A -o custom-columns=\
NAMESPACE:.metadata.namespace,\
NAME:.metadata.name,\
QOS:.status.qosClass
```

---

## Part 5: Cost Optimization Strategies

### 5.1 Right-Sizing Analysis

```yaml
# right-sizing-job.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: resource-analysis
  namespace: monitoring
spec:
  schedule: "0 */6 * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
            - name: analyzer
              image: bitnami/kubectl:latest
              command:
                - /bin/sh
                - -c
                - |
                  echo "=== Resource Efficiency Report ===" > /tmp/report.txt
                  echo "Time: $(date)" >> /tmp/report.txt

                  # Analyze each namespace
                  for ns in $(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}'); do
                    echo -e "\n--- Namespace: $ns ---" >> /tmp/report.txt

                    for pod in $(kubectl get pods -n $ns -o jsonpath='{.items[*].metadata.name}'); do
                      # Get requests
                      requests=$(kubectl get pod $pod -n $ns -o json | jq -r '
                        .spec.containers[] |
                        "CPU Request: \(.resources.requests.cpu // "none"), Memory Request: \(.resources.requests.memory // "none")"
                      ')

                      # Get current usage
                      usage=$(kubectl top pod $pod -n $ns --no-headers 2>/dev/null || echo "N/A N/A")

                      echo "$pod: Requests($requests) Usage($usage)" >> /tmp/report.txt
                    done
                  done

                  cat /tmp/report.txt
          restartPolicy: OnFailure
```

### 5.2 Spot Instance Tolerations

```yaml
# spot-tolerant-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: batch-processor
  namespace: production
spec:
  replicas: 5
  selector:
    matchLabels:
      app: batch-processor
  template:
    metadata:
      labels:
        app: batch-processor
    spec:
      # Prefer spot instances
      tolerations:
        - key: "spot"
          operator: "Equal"
          value: "true"
          effect: "NoSchedule"
      affinity:
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              preference:
                matchExpressions:
                  - key: lifecycle
                    operator: In
                    values:
                      - spot
      containers:
        - name: processor
          image: batch-processor:1.0
          resources:
            requests:
              cpu: 500m
              memory: 512Mi
            limits:
              cpu: 1
              memory: 1Gi
```

### 5.3 Resource Efficiency Dashboard

```yaml
# Prometheus recording rules for efficiency metrics
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: resource-efficiency
  namespace: monitoring
spec:
  groups:
    - name: resource-efficiency
      interval: 5m
      rules:
        # CPU efficiency
        - record: namespace:cpu_efficiency:ratio
          expr: |
            sum by (namespace) (rate(container_cpu_usage_seconds_total{container!=""}[5m]))
            /
            sum by (namespace) (kube_pod_container_resource_requests{resource="cpu"})

        # Memory efficiency
        - record: namespace:memory_efficiency:ratio
          expr: |
            sum by (namespace) (container_memory_working_set_bytes{container!=""})
            /
            sum by (namespace) (kube_pod_container_resource_requests{resource="memory"})

        # Over-provisioned pods (using < 50% of requests)
        - record: namespace:overprovisioned_pods:count
          expr: |
            count by (namespace) (
              (
                rate(container_cpu_usage_seconds_total{container!=""}[5m])
                /
                on(namespace, pod, container) kube_pod_container_resource_requests{resource="cpu"}
              ) < 0.5
            )
```

---

## Part 6: Memory Optimization

### 6.1 Memory Management

```yaml
# memory-optimized-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: memory-optimized
  namespace: production
spec:
  containers:
    - name: app
      image: myapp:1.0
      resources:
        requests:
          memory: 256Mi
        limits:
          memory: 512Mi
      env:
        # JVM memory settings
        - name: JAVA_OPTS
          value: "-Xms200m -Xmx400m -XX:+UseG1GC -XX:MaxGCPauseMillis=100"
        # Node.js memory settings
        - name: NODE_OPTIONS
          value: "--max-old-space-size=400"
```

### 6.2 Memory Cgroup Settings

```yaml
# memory-swap-disabled.yaml
apiVersion: v1
kind: Pod
metadata:
  name: no-swap-pod
  namespace: production
spec:
  containers:
    - name: app
      image: myapp:1.0
      resources:
        requests:
          memory: 512Mi
        limits:
          memory: 512Mi  # Hard limit, OOM if exceeded
```

### 6.3 Hugepages Configuration

```yaml
# hugepages-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: hugepages-pod
  namespace: production
spec:
  containers:
    - name: app
      image: database:1.0
      resources:
        requests:
          memory: 1Gi
          hugepages-2Mi: 512Mi
        limits:
          memory: 1Gi
          hugepages-2Mi: 512Mi
      volumeMounts:
        - name: hugepage
          mountPath: /hugepages
  volumes:
    - name: hugepage
      emptyDir:
        medium: HugePages
```

---

## Part 7: CPU Optimization

### 7.1 CPU Management Policy

```yaml
# kubelet-config.yaml
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cpuManagerPolicy: static  # Enable static CPU management
cpuManagerReconcilePeriod: 10s
reservedSystemCPUs: "0-1"  # Reserve CPUs for system
```

### 7.2 Guaranteed CPU Allocation

```yaml
# guaranteed-cpu-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: cpu-guaranteed
  namespace: production
spec:
  containers:
    - name: latency-critical
      image: app:1.0
      resources:
        # Integer CPU values for exclusive CPU allocation
        requests:
          cpu: "2"
          memory: 1Gi
        limits:
          cpu: "2"
          memory: 1Gi
```

### 7.3 CPU Pinning Verification

```bash
# Verify CPU allocation
kubectl exec -it cpu-guaranteed -- cat /proc/1/status | grep Cpus_allowed

# Check cgroup CPU settings
kubectl exec -it cpu-guaranteed -- cat /sys/fs/cgroup/cpu/cpu.cfs_quota_us
kubectl exec -it cpu-guaranteed -- cat /sys/fs/cgroup/cpu/cpu.cfs_period_us
```

---

## Part 8: Monitoring Resource Usage

### 8.1 Resource Metrics

```promql
# CPU utilization vs requests
sum(rate(container_cpu_usage_seconds_total{container!=""}[5m])) by (namespace, pod)
/
sum(kube_pod_container_resource_requests{resource="cpu"}) by (namespace, pod)

# Memory utilization vs requests
sum(container_memory_working_set_bytes{container!=""}) by (namespace, pod)
/
sum(kube_pod_container_resource_requests{resource="memory"}) by (namespace, pod)

# Pods near memory limit
(
  sum(container_memory_working_set_bytes{container!=""}) by (namespace, pod)
  /
  sum(kube_pod_container_resource_limits{resource="memory"}) by (namespace, pod)
) > 0.9

# OOM kills
increase(container_oom_events_total[1h])
```

### 8.2 Alert Rules

```yaml
# resource-alerts.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: resource-alerts
  namespace: monitoring
spec:
  groups:
    - name: resources
      rules:
        - alert: PodMemoryNearLimit
          expr: |
            (
              sum(container_memory_working_set_bytes{container!=""}) by (namespace, pod)
              /
              sum(kube_pod_container_resource_limits{resource="memory"}) by (namespace, pod)
            ) > 0.9
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: Pod memory usage near limit
            description: "Pod {{ $labels.namespace }}/{{ $labels.pod }} is using {{ $value | humanizePercentage }} of memory limit"

        - alert: NamespaceQuotaExhausted
          expr: |
            kube_resourcequota{type="used"} / kube_resourcequota{type="hard"} > 0.9
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: Namespace quota nearly exhausted

        - alert: ContainerCPUThrottling
          expr: |
            rate(container_cpu_cfs_throttled_periods_total[5m])
            /
            rate(container_cpu_cfs_periods_total[5m]) > 0.25
          for: 15m
          labels:
            severity: warning
          annotations:
            summary: Container experiencing CPU throttling
```

---

## Part 9: Hands-on Challenges

### Challenge 1: Namespace Budget

Configure resource management for a new team:
1. Create namespace with resource quotas
2. Set up limit ranges
3. Configure default resources
4. Monitor quota usage

### Challenge 2: Efficiency Audit

Perform efficiency audit:
1. Identify over-provisioned pods
2. Analyze request vs usage
3. Generate right-sizing recommendations
4. Implement VPA for automation

### Challenge 3: Cost Attribution

Implement cost tracking:
1. Label resources by team/project
2. Calculate resource costs
3. Create cost allocation reports
4. Set up budget alerts

---

## Verification Tasks

1. [ ] Created resource quotas
2. [ ] Configured limit ranges
3. [ ] Analyzed resource efficiency
4. [ ] Implemented QoS classes appropriately
5. [ ] Set up monitoring dashboards
6. [ ] Created efficiency alerts

---

## Key Takeaways

- Always set resource requests and limits
- Use limit ranges for default values
- Quotas prevent namespace resource exhaustion
- QoS class determines eviction priority
- Monitor actual vs requested resources
- Right-size based on actual usage patterns

---

## Next Steps

Continue to [Exercise 5: Pod Disruption Budgets](03-scaling-performance-exercises-05-pod-disruption-budgets.md)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Resource Analysis
- Resource Quotas
- Limit Ranges
- Quality of Service (QoS)

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
