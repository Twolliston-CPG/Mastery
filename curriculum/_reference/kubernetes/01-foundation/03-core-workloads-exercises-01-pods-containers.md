# Exercise 1: Pods and Containers

## Objectives

- Understand Pod anatomy and lifecycle
- Configure multi-container pods
- Use init containers effectively
- Implement health checks (probes)

## Prerequisites

- Running Kubernetes cluster
- kubectl configured
- Understanding of containers

---

## Part 1: Pod Fundamentals

### 1.1 Creating a Basic Pod

```bash
# Imperative creation
kubectl run nginx-basic --image=nginx:1.25 --port=80

# Check pod status
kubectl get pod nginx-basic
kubectl describe pod nginx-basic

# View pod logs
kubectl logs nginx-basic

# Execute command in pod
kubectl exec nginx-basic -- ls -la /usr/share/nginx/html

# Interactive shell
kubectl exec -it nginx-basic -- /bin/bash

# Cleanup
kubectl delete pod nginx-basic
```

### 1.2 Declarative Pod Definition

```yaml
# basic-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: webapp
  labels:
    app: webapp
    environment: development
  annotations:
    description: "Basic web application pod"
spec:
  containers:
  - name: nginx
    image: nginx:1.25
    ports:
    - containerPort: 80
      name: http
    resources:
      requests:
        cpu: "100m"
        memory: "128Mi"
      limits:
        cpu: "200m"
        memory: "256Mi"
```

```bash
kubectl apply -f basic-pod.yaml
kubectl get pod webapp -o wide
kubectl describe pod webapp
kubectl delete pod webapp
```

### 1.3 Pod Lifecycle States

```
Pending → Running → Succeeded/Failed

Pod Phases:
- Pending: Waiting for scheduling or image pull
- Running: At least one container running
- Succeeded: All containers terminated successfully (exit 0)
- Failed: At least one container terminated with failure
- Unknown: Pod state cannot be determined
```

---

## Part 2: Container Configuration

### 2.1 Environment Variables

```yaml
# env-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: env-demo
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "echo $APP_NAME running in $ENVIRONMENT && sleep 3600"]
    env:
    # Static value
    - name: APP_NAME
      value: "MyApp"
    # From field reference
    - name: POD_NAME
      valueFrom:
        fieldRef:
          fieldPath: metadata.name
    - name: POD_NAMESPACE
      valueFrom:
        fieldRef:
          fieldPath: metadata.namespace
    - name: POD_IP
      valueFrom:
        fieldRef:
          fieldPath: status.podIP
    - name: NODE_NAME
      valueFrom:
        fieldRef:
          fieldPath: spec.nodeName
    # From resource field
    - name: CPU_LIMIT
      valueFrom:
        resourceFieldRef:
          containerName: app
          resource: limits.cpu
    # From ConfigMap
    - name: ENVIRONMENT
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: environment
          optional: true
    # From Secret
    - name: DATABASE_PASSWORD
      valueFrom:
        secretKeyRef:
          name: db-secret
          key: password
          optional: true
```

```bash
# Create supporting resources
kubectl create configmap app-config --from-literal=environment=production
kubectl create secret generic db-secret --from-literal=password=mysecret

# Deploy pod
kubectl apply -f env-pod.yaml
kubectl logs env-demo

# Verify environment
kubectl exec env-demo -- env | sort

# Cleanup
kubectl delete pod env-demo
kubectl delete configmap app-config
kubectl delete secret db-secret
```

### 2.2 Command and Arguments

```yaml
# command-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: command-demo
spec:
  containers:
  - name: main
    image: busybox:1.36
    # Overrides ENTRYPOINT
    command: ["sh", "-c"]
    # Overrides CMD
    args:
    - |
      echo "Starting application..."
      echo "Current time: $(date)"
      echo "Running as user: $(whoami)"
      sleep 3600
```

### 2.3 Volume Mounts

```yaml
# volume-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: volume-demo
spec:
  containers:
  - name: writer
    image: busybox:1.36
    command: ["sh", "-c", "while true; do date >> /data/log.txt; sleep 5; done"]
    volumeMounts:
    - name: shared-data
      mountPath: /data
  - name: reader
    image: busybox:1.36
    command: ["sh", "-c", "tail -f /data/log.txt"]
    volumeMounts:
    - name: shared-data
      mountPath: /data
      readOnly: true
  volumes:
  - name: shared-data
    emptyDir: {}
```

```bash
kubectl apply -f volume-pod.yaml
kubectl logs volume-demo -c reader -f
kubectl delete pod volume-demo
```

---

## Part 3: Multi-Container Patterns

### 3.1 Sidecar Pattern

```yaml
# sidecar-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: sidecar-demo
spec:
  containers:
  # Main application container
  - name: app
    image: nginx:1.25
    ports:
    - containerPort: 80
    volumeMounts:
    - name: logs
      mountPath: /var/log/nginx

  # Sidecar: Log shipper
  - name: log-shipper
    image: busybox:1.36
    command: ["sh", "-c"]
    args:
    - |
      echo "Starting log shipper..."
      tail -F /var/log/nginx/access.log 2>/dev/null || echo "Waiting for logs..."
      while true; do
        if [ -f /var/log/nginx/access.log ]; then
          tail -F /var/log/nginx/access.log
        fi
        sleep 1
      done
    volumeMounts:
    - name: logs
      mountPath: /var/log/nginx
      readOnly: true

  volumes:
  - name: logs
    emptyDir: {}
```

### 3.2 Ambassador Pattern

```yaml
# ambassador-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: ambassador-demo
spec:
  containers:
  # Main application
  - name: app
    image: curlimages/curl
    command: ["sh", "-c"]
    args:
    - |
      while true; do
        echo "Calling external service via ambassador..."
        curl -s localhost:8080/external-api || echo "Ambassador not ready"
        sleep 10
      done

  # Ambassador: Proxy to external services
  - name: ambassador
    image: nginx:1.25
    ports:
    - containerPort: 8080
    volumeMounts:
    - name: config
      mountPath: /etc/nginx/conf.d

  volumes:
  - name: config
    configMap:
      name: ambassador-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: ambassador-config
data:
  default.conf: |
    server {
        listen 8080;
        location /external-api {
            # Proxy to external service
            return 200 '{"status": "ok", "from": "ambassador"}';
            add_header Content-Type application/json;
        }
    }
```

### 3.3 Adapter Pattern

```yaml
# adapter-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: adapter-demo
spec:
  containers:
  # Main application (outputs custom format)
  - name: app
    image: busybox:1.36
    command: ["sh", "-c"]
    args:
    - |
      while true; do
        echo "CUSTOM|$(date +%s)|metric1|$(shuf -i 1-100 -n 1)" >> /metrics/raw.log
        sleep 5
      done
    volumeMounts:
    - name: metrics
      mountPath: /metrics

  # Adapter: Converts to Prometheus format
  - name: adapter
    image: busybox:1.36
    command: ["sh", "-c"]
    args:
    - |
      while true; do
        if [ -f /metrics/raw.log ]; then
          # Convert custom format to Prometheus format
          tail -1 /metrics/raw.log | awk -F'|' '{print "# HELP "$3" Custom metric\n"$3" "$4}'
        fi
        sleep 5
      done
    volumeMounts:
    - name: metrics
      mountPath: /metrics
      readOnly: true

  volumes:
  - name: metrics
    emptyDir: {}
```

---

## Part 4: Init Containers

### 4.1 Basic Init Container

```yaml
# init-container-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: init-demo
spec:
  initContainers:
  # Wait for dependency
  - name: wait-for-db
    image: busybox:1.36
    command: ['sh', '-c']
    args:
    - |
      echo "Waiting for database..."
      # Simulate waiting for database
      sleep 5
      echo "Database ready!"

  # Download configuration
  - name: download-config
    image: busybox:1.36
    command: ['sh', '-c']
    args:
    - |
      echo "Downloading configuration..."
      echo "config_key=config_value" > /config/app.conf
      echo "Configuration downloaded!"
    volumeMounts:
    - name: config
      mountPath: /config

  containers:
  - name: app
    image: busybox:1.36
    command: ['sh', '-c']
    args:
    - |
      echo "Starting application..."
      cat /config/app.conf
      sleep 3600
    volumeMounts:
    - name: config
      mountPath: /config
      readOnly: true

  volumes:
  - name: config
    emptyDir: {}
```

### 4.2 Network Dependency Check

```yaml
# init-network-check.yaml
apiVersion: v1
kind: Pod
metadata:
  name: webapp-with-init
spec:
  initContainers:
  - name: wait-for-service
    image: busybox:1.36
    command: ['sh', '-c']
    args:
    - |
      until nc -z redis-service 6379; do
        echo "Waiting for Redis..."
        sleep 2
      done
      echo "Redis is available!"

  containers:
  - name: webapp
    image: nginx:1.25
    env:
    - name: REDIS_HOST
      value: "redis-service"
```

---

## Part 5: Health Checks (Probes)

### 5.1 Liveness Probe

```yaml
# liveness-probe.yaml
apiVersion: v1
kind: Pod
metadata:
  name: liveness-demo
spec:
  containers:
  - name: app
    image: nginx:1.25
    ports:
    - containerPort: 80
    livenessProbe:
      httpGet:
        path: /healthz
        port: 80
      initialDelaySeconds: 5    # Wait before first probe
      periodSeconds: 10         # Check every 10 seconds
      timeoutSeconds: 3         # Timeout for probe
      failureThreshold: 3       # Restart after 3 failures
      successThreshold: 1       # Consider healthy after 1 success
```

### 5.2 Readiness Probe

```yaml
# readiness-probe.yaml
apiVersion: v1
kind: Pod
metadata:
  name: readiness-demo
  labels:
    app: webapp
spec:
  containers:
  - name: app
    image: nginx:1.25
    ports:
    - containerPort: 80
    readinessProbe:
      httpGet:
        path: /ready
        port: 80
      initialDelaySeconds: 5
      periodSeconds: 5
      failureThreshold: 3
      successThreshold: 1
```

### 5.3 Startup Probe

```yaml
# startup-probe.yaml
apiVersion: v1
kind: Pod
metadata:
  name: startup-demo
spec:
  containers:
  - name: app
    image: nginx:1.25
    ports:
    - containerPort: 80
    # For slow starting apps
    startupProbe:
      httpGet:
        path: /healthz
        port: 80
      failureThreshold: 30      # 30 * 10 = 300 seconds max startup time
      periodSeconds: 10
    # Regular liveness after startup succeeds
    livenessProbe:
      httpGet:
        path: /healthz
        port: 80
      periodSeconds: 10
```

### 5.4 Different Probe Types

```yaml
# all-probe-types.yaml
apiVersion: v1
kind: Pod
metadata:
  name: probe-types-demo
spec:
  containers:
  - name: app
    image: nginx:1.25
    ports:
    - containerPort: 80

    # HTTP GET probe
    livenessProbe:
      httpGet:
        path: /healthz
        port: 80
        httpHeaders:
        - name: Custom-Header
          value: "probe-check"
      periodSeconds: 10

    # TCP Socket probe
    readinessProbe:
      tcpSocket:
        port: 80
      periodSeconds: 5

  - name: worker
    image: busybox:1.36
    command: ["sh", "-c", "while true; do echo ok > /tmp/healthy; sleep 10; done"]

    # Exec probe (command)
    livenessProbe:
      exec:
        command:
        - cat
        - /tmp/healthy
      periodSeconds: 10

    # gRPC probe (for gRPC services)
    # livenessProbe:
    #   grpc:
    #     port: 50051
    #   periodSeconds: 10
```

---

## Part 6: Hands-on Challenges

### Challenge 1: Complete Application Pod

Create a pod with:
- Main application container
- Sidecar for log collection
- Init container for configuration
- All three probe types
- Resource limits

```yaml
# challenge1-complete-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: complete-app
  labels:
    app: complete-app
    tier: frontend
spec:
  initContainers:
  - name: init-config
    image: busybox:1.36
    command: ['sh', '-c']
    args:
    - |
      echo "server.port=8080" > /config/application.properties
      echo "log.level=INFO" >> /config/application.properties
    volumeMounts:
    - name: config
      mountPath: /config

  containers:
  - name: app
    image: nginx:1.25
    ports:
    - containerPort: 80
      name: http
    resources:
      requests:
        cpu: "100m"
        memory: "128Mi"
      limits:
        cpu: "500m"
        memory: "256Mi"
    volumeMounts:
    - name: config
      mountPath: /etc/app
      readOnly: true
    - name: logs
      mountPath: /var/log/nginx
    startupProbe:
      httpGet:
        path: /
        port: 80
      failureThreshold: 30
      periodSeconds: 2
    livenessProbe:
      httpGet:
        path: /
        port: 80
      periodSeconds: 10
      failureThreshold: 3
    readinessProbe:
      httpGet:
        path: /
        port: 80
      periodSeconds: 5

  - name: log-collector
    image: busybox:1.36
    command: ["sh", "-c", "tail -F /var/log/nginx/access.log 2>/dev/null || sleep infinity"]
    resources:
      requests:
        cpu: "10m"
        memory: "32Mi"
      limits:
        cpu: "50m"
        memory: "64Mi"
    volumeMounts:
    - name: logs
      mountPath: /var/log/nginx
      readOnly: true

  volumes:
  - name: config
    emptyDir: {}
  - name: logs
    emptyDir: {}
```

### Challenge 2: Debug Unhealthy Pod

```bash
# Create a pod that will fail health checks
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: unhealthy-pod
spec:
  containers:
  - name: app
    image: nginx:1.25
    livenessProbe:
      httpGet:
        path: /nonexistent
        port: 80
      initialDelaySeconds: 5
      periodSeconds: 5
      failureThreshold: 3
EOF

# Debug it
kubectl describe pod unhealthy-pod
kubectl get events --field-selector involvedObject.name=unhealthy-pod

# What do you observe?
# How would you fix it?
```

---

## Verification Tasks

1. [ ] Created pods using both imperative and declarative methods
2. [ ] Configured environment variables from multiple sources
3. [ ] Built multi-container pods with shared volumes
4. [ ] Implemented sidecar pattern
5. [ ] Used init containers for dependencies
6. [ ] Configured all three probe types

---

## Key Takeaways

- Pods are the smallest deployable unit
- Multi-container pods share network and storage
- Init containers run before main containers
- Probes ensure container health and readiness
- Resource limits prevent noisy neighbors

---

## Next Steps

Continue to [Exercise 2: Deployments and ReplicaSets](03-core-workloads-exercises-02-deployments-replicasets.md)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Pod Fundamentals
- Container Configuration
- Multi-Container Patterns
- Init Containers

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
