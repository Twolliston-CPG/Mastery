# Exercise 4: DaemonSets

## Objectives

- Understand DaemonSet use cases
- Deploy cluster-wide agents
- Control DaemonSet scheduling
- Manage DaemonSet updates

## Prerequisites

- Completed Exercises 1-3
- Understanding of node concepts
- kubectl proficiency

---

## Part 1: DaemonSet Fundamentals

### 1.1 When to Use DaemonSets

DaemonSets ensure one pod runs on each (or selected) node:
- **Node monitoring agents**: Prometheus node exporter, Datadog agent
- **Log collectors**: Fluentd, Fluent Bit, Logstash
- **Storage daemons**: Ceph, GlusterFS
- **Network plugins**: Calico, Flannel, Cilium
- **Security agents**: Falco, Sysdig

### 1.2 DaemonSet vs Deployment

| Feature | Deployment | DaemonSet |
|---------|-----------|-----------|
| Replicas | Specified count | One per node |
| Scheduling | Scheduler decides | Per-node guarantee |
| Scale with cluster | Manual | Automatic |
| Use case | Stateless apps | Node-level services |

---

## Part 2: Basic DaemonSet

### 2.1 Simple DaemonSet

```yaml
# daemonset-basic.yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-exporter
  labels:
    app: node-exporter
spec:
  selector:
    matchLabels:
      app: node-exporter
  template:
    metadata:
      labels:
        app: node-exporter
    spec:
      containers:
      - name: node-exporter
        image: prom/node-exporter:v1.7.0
        ports:
        - containerPort: 9100
          name: metrics
        resources:
          requests:
            cpu: "50m"
            memory: "64Mi"
          limits:
            cpu: "200m"
            memory: "128Mi"
```

```bash
kubectl apply -f daemonset-basic.yaml

# Check pods - one per node
kubectl get pods -l app=node-exporter -o wide

# Verify pod count matches node count
kubectl get nodes --no-headers | wc -l
kubectl get pods -l app=node-exporter --no-headers | wc -l

# Describe DaemonSet
kubectl describe daemonset node-exporter
```

### 2.2 DaemonSet Status

```bash
# Get DaemonSet status
kubectl get daemonset node-exporter

# Output columns:
# DESIRED - Number of nodes that should run the pod
# CURRENT - Number of nodes running at least one pod
# READY   - Number of pods ready
# UP-TO-DATE - Number of pods with current template
# AVAILABLE - Number of pods available
```

---

## Part 3: Node Selection

### 3.1 Using nodeSelector

```yaml
# daemonset-nodeselector.yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: gpu-monitor
spec:
  selector:
    matchLabels:
      app: gpu-monitor
  template:
    metadata:
      labels:
        app: gpu-monitor
    spec:
      nodeSelector:
        hardware: gpu  # Only run on GPU nodes
      containers:
      - name: monitor
        image: busybox:1.36
        command: ["sh", "-c", "while true; do echo 'Monitoring GPU'; sleep 60; done"]
```

```bash
# Label a node
kubectl label nodes <node-name> hardware=gpu

# Apply DaemonSet
kubectl apply -f daemonset-nodeselector.yaml

# Check - only runs on labeled nodes
kubectl get pods -l app=gpu-monitor -o wide
```

### 3.2 Using Node Affinity

```yaml
# daemonset-affinity.yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: zone-specific
spec:
  selector:
    matchLabels:
      app: zone-monitor
  template:
    metadata:
      labels:
        app: zone-monitor
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: topology.kubernetes.io/zone
                operator: In
                values:
                - us-west-2a
                - us-west-2b
      containers:
      - name: monitor
        image: busybox:1.36
        command: ["sh", "-c", "while true; do echo 'Zone monitor'; sleep 60; done"]
```

### 3.3 Tolerating Taints

```yaml
# daemonset-tolerations.yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-logger
spec:
  selector:
    matchLabels:
      app: node-logger
  template:
    metadata:
      labels:
        app: node-logger
    spec:
      # Tolerate common node taints to run everywhere
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
      - key: node-role.kubernetes.io/master
        operator: Exists
        effect: NoSchedule
      - key: node.kubernetes.io/not-ready
        operator: Exists
        effect: NoExecute
      - key: node.kubernetes.io/unreachable
        operator: Exists
        effect: NoExecute
      - key: node.kubernetes.io/disk-pressure
        operator: Exists
        effect: NoSchedule
      - key: node.kubernetes.io/memory-pressure
        operator: Exists
        effect: NoSchedule
      containers:
      - name: logger
        image: busybox:1.36
        command: ["sh", "-c", "while true; do echo $(hostname) $(date); sleep 30; done"]
```

```bash
kubectl apply -f daemonset-tolerations.yaml

# Now runs on control plane nodes too
kubectl get pods -l app=node-logger -o wide
```

---

## Part 4: Host Access

### 4.1 Host Network and PID

```yaml
# daemonset-host-access.yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: host-monitor
spec:
  selector:
    matchLabels:
      app: host-monitor
  template:
    metadata:
      labels:
        app: host-monitor
    spec:
      hostNetwork: true   # Use node's network namespace
      hostPID: true       # Access node's process namespace
      containers:
      - name: monitor
        image: busybox:1.36
        command: ["sh", "-c"]
        args:
        - |
          while true; do
            echo "=== Host Network Info ==="
            hostname
            ip addr show | grep -E "inet " | head -5
            echo "=== Top Processes ==="
            ps aux | head -10
            sleep 60
          done
        securityContext:
          privileged: false
          capabilities:
            add:
            - NET_ADMIN
```

### 4.2 Host Path Volumes

```yaml
# daemonset-hostpath.yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: log-collector
spec:
  selector:
    matchLabels:
      app: log-collector
  template:
    metadata:
      labels:
        app: log-collector
    spec:
      containers:
      - name: collector
        image: busybox:1.36
        command: ["sh", "-c", "tail -F /var/log/syslog /var/log/messages 2>/dev/null || sleep infinity"]
        volumeMounts:
        - name: varlog
          mountPath: /var/log
          readOnly: true
        - name: containers
          mountPath: /var/lib/docker/containers
          readOnly: true
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
      - name: containers
        hostPath:
          path: /var/lib/docker/containers
```

---

## Part 5: Update Strategies

### 5.1 RollingUpdate (Default)

```yaml
# daemonset-rolling.yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: rolling-update-demo
spec:
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1  # Update one node at a time
      maxSurge: 0        # Don't create extra pods
  selector:
    matchLabels:
      app: rolling-demo
  template:
    metadata:
      labels:
        app: rolling-demo
    spec:
      containers:
      - name: nginx
        image: nginx:1.24
```

```bash
kubectl apply -f daemonset-rolling.yaml

# Update image
kubectl set image daemonset/rolling-update-demo nginx=nginx:1.25

# Watch rollout
kubectl rollout status daemonset/rolling-update-demo

# View history
kubectl rollout history daemonset/rolling-update-demo
```

### 5.2 OnDelete Strategy

```yaml
updateStrategy:
  type: OnDelete  # Only update when pods are manually deleted
```

```bash
# With OnDelete, must delete pods manually to update
kubectl delete pod -l app=rolling-demo
```

### 5.3 Percentage-Based Updates

```yaml
updateStrategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 25%  # Update 25% of nodes at a time
```

---

## Part 6: Real-World Examples

### 6.1 Fluent Bit Log Collector

```yaml
# fluentbit-daemonset.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluent-bit-config
data:
  fluent-bit.conf: |
    [SERVICE]
        Flush         1
        Log_Level     info
        Daemon        off

    [INPUT]
        Name              tail
        Path              /var/log/containers/*.log
        Parser            docker
        Tag               kube.*
        Refresh_Interval  5
        Mem_Buf_Limit     5MB
        Skip_Long_Lines   On

    [OUTPUT]
        Name              stdout
        Match             *
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluent-bit
  labels:
    app: fluent-bit
spec:
  selector:
    matchLabels:
      app: fluent-bit
  template:
    metadata:
      labels:
        app: fluent-bit
    spec:
      serviceAccountName: fluent-bit
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
      containers:
      - name: fluent-bit
        image: fluent/fluent-bit:2.2
        volumeMounts:
        - name: varlog
          mountPath: /var/log
          readOnly: true
        - name: containers
          mountPath: /var/lib/docker/containers
          readOnly: true
        - name: config
          mountPath: /fluent-bit/etc/fluent-bit.conf
          subPath: fluent-bit.conf
        resources:
          requests:
            cpu: "50m"
            memory: "64Mi"
          limits:
            cpu: "200m"
            memory: "128Mi"
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
      - name: containers
        hostPath:
          path: /var/lib/docker/containers
      - name: config
        configMap:
          name: fluent-bit-config
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: fluent-bit
```

### 6.2 Node Problem Detector

```yaml
# node-problem-detector.yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-problem-detector
spec:
  selector:
    matchLabels:
      app: node-problem-detector
  template:
    metadata:
      labels:
        app: node-problem-detector
    spec:
      tolerations:
      - operator: Exists
        effect: NoSchedule
      - operator: Exists
        effect: NoExecute
      hostNetwork: true
      containers:
      - name: node-problem-detector
        image: registry.k8s.io/node-problem-detector/node-problem-detector:v0.8.14
        command:
        - /node-problem-detector
        - --logtostderr
        - --config.system-log-monitor=/config/kernel-monitor.json
        volumeMounts:
        - name: log
          mountPath: /var/log
          readOnly: true
        - name: localtime
          mountPath: /etc/localtime
          readOnly: true
        resources:
          requests:
            cpu: "10m"
            memory: "80Mi"
          limits:
            cpu: "50m"
            memory: "160Mi"
        securityContext:
          privileged: true
      volumes:
      - name: log
        hostPath:
          path: /var/log
      - name: localtime
        hostPath:
          path: /etc/localtime
```

---

## Part 7: Hands-on Challenges

### Challenge 1: Custom Node Metrics Collector

Create a DaemonSet that:
- Runs on all nodes (including control plane)
- Collects CPU, memory, disk metrics
- Exposes metrics on port 9100

```yaml
# metrics-collector.yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: custom-metrics
spec:
  selector:
    matchLabels:
      app: custom-metrics
  template:
    metadata:
      labels:
        app: custom-metrics
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "9100"
    spec:
      tolerations:
      - operator: Exists
      hostPID: true
      containers:
      - name: metrics
        image: busybox:1.36
        command: ["sh", "-c"]
        args:
        - |
          # Simple metrics server
          while true; do
            cat <<EOF > /tmp/metrics
          # HELP node_cpu_usage Node CPU usage
          node_cpu_usage $(cat /proc/loadavg | awk '{print $1}')
          # HELP node_memory_free Node free memory
          node_memory_free $(cat /proc/meminfo | grep MemFree | awk '{print $2}')
          EOF
            sleep 15
          done &

          # Simple HTTP server
          while true; do
            echo -e "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\n$(cat /tmp/metrics)" | nc -l -p 9100
          done
        ports:
        - containerPort: 9100
          name: metrics
        resources:
          requests:
            cpu: "10m"
            memory: "32Mi"
```

### Challenge 2: Rolling Update with Health Checks

Configure a DaemonSet update that:
- Updates one node at a time
- Waits for readiness before continuing
- Can be rolled back if issues

```bash
# Configure with proper probes and update strategy
# Test by triggering an update and watching rollout
# Practice rollback if needed
```

### Challenge 3: Selective Deployment

Create a DaemonSet that:
- Only runs on nodes with SSD storage
- Excludes control plane nodes
- Has specific resource limits

---

## Verification Tasks

1. [ ] Created basic DaemonSet running on all nodes
2. [ ] Used nodeSelector to limit DaemonSet scope
3. [ ] Added tolerations for control plane nodes
4. [ ] Mounted host paths for log collection
5. [ ] Performed rolling update of DaemonSet
6. [ ] Implemented real-world logging agent

---

## Key Takeaways

- DaemonSets guarantee one pod per node
- Use nodeSelector/affinity for targeted deployment
- Tolerations enable running on tainted nodes
- Host access (network, PID, volumes) for system-level work
- RollingUpdate strategy for controlled updates
- Essential for cluster-wide agents and services

---

## Next Steps

Continue to [Exercise 5: Jobs and CronJobs](03-core-workloads-exercises-05-jobs-cronjobs.md)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- DaemonSet Fundamentals
- Basic DaemonSet
- Node Selection
- Host Access

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
