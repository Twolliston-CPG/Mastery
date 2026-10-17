# Exercise 3: StatefulSets

## Objectives

- Understand StatefulSet use cases
- Deploy stateful applications
- Manage persistent storage with StatefulSets
- Handle StatefulSet scaling and updates

## Prerequisites

- Completed Exercises 1-2
- Understanding of PersistentVolumes
- Familiarity with Deployments

---

## Part 1: StatefulSet Fundamentals

### 1.1 When to Use StatefulSets

Use StatefulSets when you need:
- **Stable network identities**: Predictable pod names and DNS
- **Stable storage**: PV bound to specific pod
- **Ordered deployment/scaling**: Pods created/deleted in order
- **Ordered rolling updates**: Updates happen one at a time in order

Examples: Databases, message queues, distributed systems (Kafka, ZooKeeper, etcd)

### 1.2 StatefulSet vs Deployment

| Feature | Deployment | StatefulSet |
|---------|-----------|-------------|
| Pod names | Random suffix (pod-abc123) | Ordinal index (pod-0, pod-1) |
| Scaling | Parallel | Sequential (ordered) |
| Storage | Shared or ephemeral | Individual PVC per pod |
| DNS | Service-based | Predictable hostname |
| Updates | Parallel | Sequential (ordered) |

---

## Part 2: Basic StatefulSet

### 2.1 Simple StatefulSet

```yaml
# statefulset-basic.yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-headless
  labels:
    app: nginx
spec:
  ports:
  - port: 80
    name: web
  clusterIP: None  # Headless service
  selector:
    app: nginx
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: nginx
spec:
  serviceName: "nginx-headless"  # Must match headless service
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
          name: web
```

```bash
kubectl apply -f statefulset-basic.yaml

# Watch pods being created in order
kubectl get pods -l app=nginx -w

# Notice: nginx-0, nginx-1, nginx-2 (not random names)
```

### 2.2 Headless Service DNS

```bash
# Each pod gets a DNS entry
# Format: <pod-name>.<service-name>.<namespace>.svc.cluster.local

kubectl run test --rm -it --image=busybox -- sh

# Inside pod:
nslookup nginx-headless
nslookup nginx-0.nginx-headless
nslookup nginx-1.nginx-headless
nslookup nginx-2.nginx-headless

# The headless service returns all pod IPs
# Individual pod DNS returns that pod's IP
exit
```

---

## Part 3: StatefulSet with Persistent Storage

### 3.1 VolumeClaimTemplates

```yaml
# statefulset-storage.yaml
apiVersion: v1
kind: Service
metadata:
  name: mysql-headless
spec:
  ports:
  - port: 3306
    name: mysql
  clusterIP: None
  selector:
    app: mysql
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql
spec:
  serviceName: "mysql-headless"
  replicas: 3
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
      - name: mysql
        image: mysql:8.0
        ports:
        - containerPort: 3306
          name: mysql
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: root-password
        volumeMounts:
        - name: data
          mountPath: /var/lib/mysql
        resources:
          requests:
            cpu: "250m"
            memory: "512Mi"
          limits:
            cpu: "1000m"
            memory: "1Gi"

  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: "standard"
      resources:
        requests:
          storage: 10Gi
---
apiVersion: v1
kind: Secret
metadata:
  name: mysql-secret
type: Opaque
data:
  root-password: cGFzc3dvcmQxMjM=  # password123
```

```bash
kubectl apply -f statefulset-storage.yaml

# Check PVCs created
kubectl get pvc -l app=mysql

# Notice: data-mysql-0, data-mysql-1, data-mysql-2
# Each pod gets its own PVC

# PVCs persist even if StatefulSet is deleted
```

### 3.2 Storage Persistence Behavior

```bash
# Delete a pod
kubectl delete pod mysql-0

# Watch recreation
kubectl get pods -l app=mysql -w

# The new mysql-0 pod reattaches to the same PVC

# Delete StatefulSet (pods are deleted, PVCs remain)
kubectl delete statefulset mysql

# PVCs still exist
kubectl get pvc -l app=mysql

# Recreate StatefulSet - pods reattach to existing PVCs
kubectl apply -f statefulset-storage.yaml
```

---

## Part 4: Pod Management Policy

### 4.1 OrderedReady (Default)

```yaml
spec:
  podManagementPolicy: OrderedReady
  # Pods are created in order: 0, 1, 2
  # Each pod must be Running and Ready before next is created
  # Pods are terminated in reverse order: 2, 1, 0
```

### 4.2 Parallel

```yaml
# parallel-statefulset.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: parallel-demo
spec:
  serviceName: "parallel-svc"
  replicas: 5
  podManagementPolicy: Parallel  # All pods created/deleted at once
  selector:
    matchLabels:
      app: parallel
  template:
    metadata:
      labels:
        app: parallel
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
```

```bash
kubectl apply -f parallel-statefulset.yaml

# Watch - all pods start at once
kubectl get pods -l app=parallel -w

# Useful when order doesn't matter but stable identity does
```

---

## Part 5: Update Strategies

### 5.1 RollingUpdate (Default)

```yaml
# rolling-statefulset.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: rolling-demo
spec:
  serviceName: "rolling-svc"
  replicas: 5
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      partition: 0  # Update all pods (N-1 down to 0)
  selector:
    matchLabels:
      app: rolling
  template:
    metadata:
      labels:
        app: rolling
    spec:
      containers:
      - name: nginx
        image: nginx:1.24
```

```bash
kubectl apply -f rolling-statefulset.yaml

# Update image
kubectl set image statefulset/rolling-demo nginx=nginx:1.25

# Watch - updates in reverse order (4, 3, 2, 1, 0)
kubectl rollout status statefulset/rolling-demo
```

### 5.2 Partitioned Rolling Updates (Canary)

```yaml
updateStrategy:
  type: RollingUpdate
  rollingUpdate:
    partition: 3  # Only update pods with ordinal >= 3
```

```bash
# Create StatefulSet with 5 replicas
kubectl apply -f rolling-statefulset.yaml

# Set partition to update only last 2 pods
kubectl patch statefulset rolling-demo -p '{"spec":{"updateStrategy":{"rollingUpdate":{"partition":3}}}}'

# Update image - only pods 3 and 4 are updated
kubectl set image statefulset/rolling-demo nginx=nginx:1.25

# Verify
kubectl get pods -l app=rolling -o jsonpath='{range .items[*]}{.metadata.name}: {.spec.containers[0].image}{"\n"}{end}'

# After testing, update all (set partition to 0)
kubectl patch statefulset rolling-demo -p '{"spec":{"updateStrategy":{"rollingUpdate":{"partition":0}}}}'
```

### 5.3 OnDelete Strategy

```yaml
updateStrategy:
  type: OnDelete  # Pods only update when manually deleted
```

```bash
# With OnDelete, update the StatefulSet
kubectl set image statefulset/rolling-demo nginx=nginx:1.26

# No pods are updated automatically
# Must manually delete pods to trigger recreation with new image
kubectl delete pod rolling-demo-0
```

---

## Part 6: Real-World Example - Redis Cluster

### 6.1 Redis StatefulSet

```yaml
# redis-statefulset.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: redis-config
data:
  redis.conf: |
    bind 0.0.0.0
    port 6379
    cluster-enabled yes
    cluster-config-file /data/nodes.conf
    cluster-node-timeout 5000
    appendonly yes
    appendfilename "appendonly.aof"
---
apiVersion: v1
kind: Service
metadata:
  name: redis-cluster
spec:
  ports:
  - port: 6379
    name: client
  - port: 16379
    name: gossip
  clusterIP: None
  selector:
    app: redis-cluster
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: redis-cluster
spec:
  serviceName: "redis-cluster"
  replicas: 6  # 3 masters + 3 replicas
  selector:
    matchLabels:
      app: redis-cluster
  template:
    metadata:
      labels:
        app: redis-cluster
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        ports:
        - containerPort: 6379
          name: client
        - containerPort: 16379
          name: gossip
        command:
        - redis-server
        - /config/redis.conf
        volumeMounts:
        - name: data
          mountPath: /data
        - name: config
          mountPath: /config
        resources:
          requests:
            cpu: "100m"
            memory: "256Mi"
          limits:
            cpu: "500m"
            memory: "512Mi"
        readinessProbe:
          exec:
            command:
            - redis-cli
            - ping
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: config
        configMap:
          name: redis-config
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 5Gi
```

### 6.2 Initialize Redis Cluster

```bash
kubectl apply -f redis-statefulset.yaml

# Wait for all pods
kubectl wait --for=condition=ready pod -l app=redis-cluster --timeout=120s

# Get pod IPs for cluster creation
kubectl get pods -l app=redis-cluster -o jsonpath='{range .items[*]}{.status.podIP}:6379 {end}'

# Create cluster (run from one of the pods)
kubectl exec -it redis-cluster-0 -- redis-cli --cluster create \
  $(kubectl get pods -l app=redis-cluster -o jsonpath='{range .items[*]}{.status.podIP}:6379 {end}') \
  --cluster-replicas 1 --cluster-yes
```

---

## Part 7: Scaling StatefulSets

### 7.1 Scale Up

```bash
# Scale up
kubectl scale statefulset nginx --replicas=5

# New pods are created in order: nginx-3, nginx-4
kubectl get pods -l app=nginx -w
```

### 7.2 Scale Down

```bash
# Scale down
kubectl scale statefulset nginx --replicas=2

# Pods deleted in reverse order: nginx-4, nginx-3, nginx-2
# PVCs are NOT deleted automatically
kubectl get pvc -l app=nginx
```

### 7.3 PVC Retention Policy (Kubernetes 1.27+)

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: with-retention
spec:
  persistentVolumeClaimRetentionPolicy:
    whenDeleted: Delete    # Delete PVCs when StatefulSet is deleted
    whenScaled: Retain     # Keep PVCs when scaling down
  # ... rest of spec
```

---

## Part 8: Hands-on Challenges

### Challenge 1: PostgreSQL StatefulSet

Create a PostgreSQL StatefulSet with:
- 3 replicas
- Persistent storage
- Proper initialization
- Health checks

```yaml
# postgres-statefulset.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: postgres-config
data:
  POSTGRES_DB: "myapp"
  POSTGRES_USER: "admin"
---
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secret
type: Opaque
data:
  POSTGRES_PASSWORD: cGFzc3dvcmQxMjM=
---
apiVersion: v1
kind: Service
metadata:
  name: postgres
spec:
  ports:
  - port: 5432
  clusterIP: None
  selector:
    app: postgres
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
spec:
  serviceName: "postgres"
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:15
        ports:
        - containerPort: 5432
        envFrom:
        - configMapRef:
            name: postgres-config
        - secretRef:
            name: postgres-secret
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
        readinessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - admin
          initialDelaySeconds: 10
          periodSeconds: 5
        livenessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - admin
          initialDelaySeconds: 30
          periodSeconds: 10
        resources:
          requests:
            cpu: "250m"
            memory: "512Mi"
          limits:
            cpu: "1000m"
            memory: "1Gi"
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 10Gi
```

### Challenge 2: Ordered Initialization

Create a StatefulSet where:
- Each pod waits for the previous pod to be ready
- Pod-0 initializes as primary
- Other pods initialize as replicas connecting to pod-0

### Challenge 3: Partition Update

Practice partitioned rolling updates:
1. Create 5-replica StatefulSet
2. Update with partition=3 (canary on pods 3,4)
3. Verify canary pods have new version
4. Complete rollout by setting partition=0

---

## Verification Tasks

1. [ ] Created StatefulSet with headless service
2. [ ] Verified predictable pod naming (0, 1, 2)
3. [ ] Tested pod DNS resolution
4. [ ] Deployed StatefulSet with volumeClaimTemplates
5. [ ] Verified PVC persistence after pod deletion
6. [ ] Performed partitioned rolling update

---

## Key Takeaways

- StatefulSets provide stable identity and storage
- Headless services enable direct pod DNS
- VolumeClaimTemplates create per-pod storage
- Updates happen in reverse ordinal order
- Partition updates enable canary deployments
- PVCs survive pod and StatefulSet deletion

---

## Next Steps

Continue to [Exercise 4: DaemonSets](03-core-workloads-exercises-04-daemonsets.md)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- StatefulSet Fundamentals
- Basic StatefulSet
- StatefulSet with Persistent Storage
- Pod Management Policy

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
