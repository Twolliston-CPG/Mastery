# Exercise 1: Persistent Volumes and Claims

## Objective

Master Kubernetes storage concepts including PersistentVolumes (PV), PersistentVolumeClaims (PVC), StorageClasses, and dynamic provisioning for stateful workloads.

## Prerequisites

- Running Kubernetes cluster
- Storage provisioner (local-path, AWS EBS, GCE PD, or similar)
- Basic understanding of storage concepts

## Tasks

### Task 1: Understand Static Provisioning

Create a PersistentVolume manually:

```yaml
# static-pv.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: manual-pv
  labels:
    type: local
spec:
  capacity:
    storage: 5Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:
    path: /data/manual-pv
```

Create a matching PersistentVolumeClaim:

```yaml
# static-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: manual-pvc
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: manual
  resources:
    requests:
      storage: 5Gi
```

**Test it:**
```bash
kubectl apply -f static-pv.yaml
kubectl apply -f static-pvc.yaml
kubectl get pv,pvc
```

### Task 2: Dynamic Provisioning with StorageClass

```yaml
# storage-class.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast
provisioner: rancher.io/local-path  # Adjust for your cluster
parameters:
  type: local
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: slow
provisioner: rancher.io/local-path
parameters:
  type: local
reclaimPolicy: Retain
volumeBindingMode: Immediate
```

```yaml
# dynamic-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: dynamic-pvc
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: fast
  resources:
    requests:
      storage: 10Gi
```

### Task 3: Deploy a Stateful Application

```yaml
# stateful-app.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: storage-lab
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
  namespace: storage-lab
spec:
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
        image: postgres:15-alpine
        env:
        - name: POSTGRES_PASSWORD
          value: testpassword
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata
        ports:
        - containerPort: 5432
        volumeMounts:
        - name: postgres-data
          mountPath: /var/lib/postgresql/data
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
      volumes:
      - name: postgres-data
        persistentVolumeClaim:
          claimName: postgres-pvc
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
  namespace: storage-lab
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
---
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: storage-lab
spec:
  selector:
    app: postgres
  ports:
  - port: 5432
```

**Verify data persistence:**
```bash
# Create some data
kubectl exec -n storage-lab deploy/postgres -- psql -U postgres -c "CREATE TABLE test (id serial, data text);"
kubectl exec -n storage-lab deploy/postgres -- psql -U postgres -c "INSERT INTO test (data) VALUES ('persistent data');"

# Delete the pod
kubectl delete pod -n storage-lab -l app=postgres

# Wait for recreation and verify data
kubectl wait --for=condition=ready pod -n storage-lab -l app=postgres --timeout=60s
kubectl exec -n storage-lab deploy/postgres -- psql -U postgres -c "SELECT * FROM test;"
```

### Task 4: Volume Expansion

```yaml
# expandable-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: expandable-pvc
  namespace: storage-lab
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: fast  # Must support expansion
  resources:
    requests:
      storage: 5Gi
```

**Expand the volume:**
```bash
kubectl apply -f expandable-pvc.yaml

# Check current size
kubectl get pvc expandable-pvc -n storage-lab

# Expand to 10Gi
kubectl patch pvc expandable-pvc -n storage-lab -p '{"spec":{"resources":{"requests":{"storage":"10Gi"}}}}'

# Verify expansion
kubectl get pvc expandable-pvc -n storage-lab
```

### Task 5: Access Modes

Demonstrate different access modes:

```yaml
# access-modes.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: access-mode-lab
---
# ReadWriteOnce - single node read-write
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: rwo-pvc
  namespace: access-mode-lab
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
---
# ReadOnlyMany - multiple nodes read-only (requires NFS or similar)
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: rox-pvc
  namespace: access-mode-lab
spec:
  accessModes:
  - ReadOnlyMany
  resources:
    requests:
      storage: 1Gi
---
# ReadWriteMany - multiple nodes read-write (requires NFS or similar)
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: rwx-pvc
  namespace: access-mode-lab
spec:
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 1Gi
```

### Task 6: Volume Snapshots

```yaml
# volume-snapshot.yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: csi-snapclass
driver: your-csi-driver  # Replace with your CSI driver
deletionPolicy: Delete
---
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: postgres-snapshot
  namespace: storage-lab
spec:
  volumeSnapshotClassName: csi-snapclass
  source:
    persistentVolumeClaimName: postgres-pvc
```

**Create PVC from snapshot:**
```yaml
# pvc-from-snapshot.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: restored-pvc
  namespace: storage-lab
spec:
  dataSource:
    name: postgres-snapshot
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
```

### Task 7: StatefulSet with volumeClaimTemplates

```yaml
# statefulset-storage.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: redis-cluster
  namespace: storage-lab
spec:
  serviceName: redis
  replicas: 3
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        ports:
        - containerPort: 6379
        command:
        - redis-server
        - --appendonly
        - "yes"
        volumeMounts:
        - name: data
          mountPath: /data
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes:
      - ReadWriteOnce
      resources:
        requests:
          storage: 5Gi
---
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: storage-lab
spec:
  clusterIP: None
  selector:
    app: redis
  ports:
  - port: 6379
```

**Verify:**
```bash
kubectl get pvc -n storage-lab
# Should see: data-redis-cluster-0, data-redis-cluster-1, data-redis-cluster-2
```

## Success Criteria

- [ ] Static PV provisioning works
- [ ] Dynamic provisioning with StorageClass works
- [ ] Data persists across pod restarts
- [ ] Volume expansion works
- [ ] StatefulSet creates individual PVCs for each replica
- [ ] Volume snapshots can be created and restored (if CSI supports it)

## Cleanup

```bash
kubectl delete namespace storage-lab
kubectl delete namespace access-mode-lab
kubectl delete pv manual-pv
```

## Next Exercise

Continue to [Exercise 2: CSI Drivers](./02-csi-drivers.md) to learn about Container Storage Interface drivers.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Understand Static Provisioning
- Dynamic Provisioning with StorageClass
- Deploy a Stateful Application
- Volume Expansion

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
