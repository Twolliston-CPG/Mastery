# Exercise 4: Volume Snapshots

## Objectives

- Understand VolumeSnapshot architecture
- Create and manage snapshots
- Restore volumes from snapshots
- Implement backup strategies

## Prerequisites

- Completed Exercises 1-3
- CSI driver with snapshot support
- VolumeSnapshot CRDs installed

---

## Part 1: Volume Snapshot Architecture

### 1.1 Snapshot Components

**VolumeSnapshotClass**

  - Defines snapshot provisioner
  - Sets parameters (deletion policy)

**VolumeSnapshot**

  - References VolumeSnapshotClass
  - References source PVC
  - Creates VolumeSnapshotContent

**VolumeSnapshotContent**

  - Actual snapshot in storage backend


### 1.2 Installing Snapshot Controller

```bash
# Install snapshot CRDs
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/release-6.3/client/config/crd/snapshot.storage.k8s.io_volumesnapshotclasses.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/release-6.3/client/config/crd/snapshot.storage.k8s.io_volumesnapshotcontents.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/release-6.3/client/config/crd/snapshot.storage.k8s.io_volumesnapshots.yaml

# Install snapshot controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/release-6.3/deploy/kubernetes/snapshot-controller/rbac-snapshot-controller.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/release-6.3/deploy/kubernetes/snapshot-controller/setup-snapshot-controller.yaml

# Verify installation
kubectl get crd | grep volumesnapshot
kubectl get pods -n kube-system | grep snapshot
```

---

## Part 2: VolumeSnapshotClass

### 2.1 AWS EBS Snapshot Class

```yaml
# aws-snapshotclass.yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: ebs-snapshot-class
  annotations:
    snapshot.storage.kubernetes.io/is-default-class: "true"
driver: ebs.csi.aws.com
deletionPolicy: Delete  # Delete snapshot when VolumeSnapshot deleted
parameters:
  # Optional: tags for snapshots
  tagSpecification_1: "backup=true"
```

### 2.2 GCP Snapshot Class

```yaml
# gcp-snapshotclass.yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: gcp-snapshot-class
driver: pd.csi.storage.gke.io
deletionPolicy: Retain  # Keep snapshot even if VolumeSnapshot deleted
parameters:
  snapshot-type: STANDARD  # or ARCHIVE for cheaper storage
```

### 2.3 Azure Snapshot Class

```yaml
# azure-snapshotclass.yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: azure-snapshot-class
driver: disk.csi.azure.com
deletionPolicy: Delete
parameters:
  incremental: "true"  # Use incremental snapshots
```

---

## Part 3: Creating Snapshots

### 3.1 Basic Snapshot

```yaml
# snapshot-basic.yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: database-snapshot
spec:
  volumeSnapshotClassName: ebs-snapshot-class
  source:
    persistentVolumeClaimName: database-pvc
```

```bash
kubectl apply -f snapshot-basic.yaml

# Check snapshot status
kubectl get volumesnapshot database-snapshot

# Detailed status
kubectl describe volumesnapshot database-snapshot

# View the underlying content
kubectl get volumesnapshotcontent
```

### 3.2 Snapshot with Labels

```yaml
# labeled-snapshot.yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: database-snapshot-2024-01-15
  labels:
    app: database
    type: scheduled
    retention: weekly
spec:
  volumeSnapshotClassName: ebs-snapshot-class
  source:
    persistentVolumeClaimName: database-pvc
```

### 3.3 Pre-Snapshot Application Quiesce

```yaml
# pre-snapshot-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: pre-snapshot-quiesce
spec:
  template:
    spec:
      containers:
      - name: quiesce
        image: postgres:15
        command:
        - /bin/sh
        - -c
        - |
          # Connect to database and create checkpoint
          PGPASSWORD=$POSTGRES_PASSWORD psql -h postgres -U admin -d appdb -c "CHECKPOINT;"
          echo "Database checkpointed for snapshot"
      env:
      - name: POSTGRES_PASSWORD
        valueFrom:
          secretKeyRef:
            name: postgres-secret
            key: POSTGRES_PASSWORD
      restartPolicy: Never
  backoffLimit: 3
```

---

## Part 4: Restoring from Snapshots

### 4.1 Create PVC from Snapshot

```yaml
# pvc-from-snapshot.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: database-restored
spec:
  storageClassName: tier1-high-performance
  dataSource:
    name: database-snapshot
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 50Gi  # Must be >= snapshot source size
```

```bash
kubectl apply -f pvc-from-snapshot.yaml

# Wait for PVC to be bound
kubectl get pvc database-restored -w

# Use restored PVC in new pod
kubectl run restore-test --rm -it --image=postgres:15 \
  --overrides='{
    "spec": {
      "containers": [{
        "name": "restore-test",
        "image": "postgres:15",
        "command": ["ls", "-la", "/data"],
        "volumeMounts": [{
          "name": "data",
          "mountPath": "/data"
        }]
      }],
      "volumes": [{
        "name": "data",
        "persistentVolumeClaim": {
          "claimName": "database-restored"
        }
      }]
    }
  }'
```

### 4.2 Clone PVC (Direct Copy)

```yaml
# pvc-clone.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: database-clone
spec:
  storageClassName: tier1-high-performance
  dataSource:
    name: database-pvc     # Source PVC
    kind: PersistentVolumeClaim
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 50Gi
```

---

## Part 5: Automated Snapshot Management

### 5.1 Scheduled Snapshot CronJob

```yaml
# scheduled-snapshot.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: database-snapshot-scheduler
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  concurrencyPolicy: Forbid
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: snapshot-creator
          containers:
          - name: snapshot-creator
            image: bitnami/kubectl:latest
            command:
            - /bin/sh
            - -c
            - |
              TIMESTAMP=$(date +%Y%m%d-%H%M%S)
              cat <<EOF | kubectl apply -f -
              apiVersion: snapshot.storage.k8s.io/v1
              kind: VolumeSnapshot
              metadata:
                name: database-snapshot-${TIMESTAMP}
                labels:
                  app: database
                  type: scheduled
                  created: "${TIMESTAMP}"
              spec:
                volumeSnapshotClassName: ebs-snapshot-class
                source:
                  persistentVolumeClaimName: database-pvc
              EOF
              echo "Created snapshot: database-snapshot-${TIMESTAMP}"
          restartPolicy: OnFailure
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: snapshot-creator
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: snapshot-creator-role
rules:
- apiGroups: ["snapshot.storage.k8s.io"]
  resources: ["volumesnapshots"]
  verbs: ["create", "get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: snapshot-creator-binding
subjects:
- kind: ServiceAccount
  name: snapshot-creator
roleRef:
  kind: Role
  name: snapshot-creator-role
  apiGroup: rbac.authorization.k8s.io
```

### 5.2 Snapshot Retention CronJob

```yaml
# snapshot-cleanup.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: snapshot-cleanup
spec:
  schedule: "0 3 * * *"  # Daily at 3 AM (after snapshots)
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: snapshot-cleaner
          containers:
          - name: cleaner
            image: bitnami/kubectl:latest
            command:
            - /bin/sh
            - -c
            - |
              # Keep last 7 daily snapshots
              KEEP=7
              SNAPSHOTS=$(kubectl get volumesnapshots -l app=database,type=scheduled \
                --sort-by=.metadata.creationTimestamp -o name | head -n -${KEEP})

              if [ -n "$SNAPSHOTS" ]; then
                echo "Deleting old snapshots:"
                echo "$SNAPSHOTS"
                kubectl delete $SNAPSHOTS
              else
                echo "No snapshots to delete"
              fi
          restartPolicy: OnFailure
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: snapshot-cleaner
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: snapshot-cleaner-role
rules:
- apiGroups: ["snapshot.storage.k8s.io"]
  resources: ["volumesnapshots"]
  verbs: ["get", "list", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: snapshot-cleaner-binding
subjects:
- kind: ServiceAccount
  name: snapshot-cleaner
roleRef:
  kind: Role
  name: snapshot-cleaner-role
  apiGroup: rbac.authorization.k8s.io
```

---

## Part 6: Cross-Namespace Snapshot

### 6.1 Export Snapshot Content

```bash
# Get VolumeSnapshotContent name
CONTENT=$(kubectl get volumesnapshot database-snapshot -o jsonpath='{.status.boundVolumeSnapshotContentName}')

# Make content available for import
kubectl patch volumesnapshotcontent $CONTENT -p '{"spec":{"deletionPolicy":"Retain"}}'

# Get snapshot handle for import
kubectl get volumesnapshotcontent $CONTENT -o jsonpath='{.status.snapshotHandle}'
```

### 6.2 Import Snapshot in Another Namespace

```yaml
# import-snapshot.yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotContent
metadata:
  name: imported-snapshot-content
spec:
  volumeSnapshotRef:
    name: imported-snapshot
    namespace: production
  source:
    snapshotHandle: snap-0123456789abcdef  # From source snapshot
  driver: ebs.csi.aws.com
  deletionPolicy: Delete
  volumeSnapshotClassName: ebs-snapshot-class
---
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: imported-snapshot
  namespace: production
spec:
  volumeSnapshotClassName: ebs-snapshot-class
  source:
    volumeSnapshotContentName: imported-snapshot-content
```

---

## Part 7: Disaster Recovery with Snapshots

### 7.1 Complete Backup Script

```bash
#!/bin/bash
# backup-database.sh

NAMESPACE=${1:-default}
PVC_NAME=${2:-database-pvc}
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

echo "=== Database Backup: ${PVC_NAME} ==="

# Step 1: Quiesce application
echo "Step 1: Quiescing application..."
kubectl exec -n $NAMESPACE deployment/database -- pg_ctl stop -m fast || true
sleep 5

# Step 2: Create snapshot
echo "Step 2: Creating snapshot..."
cat <<EOF | kubectl apply -f -
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: ${PVC_NAME}-backup-${TIMESTAMP}
  namespace: ${NAMESPACE}
  labels:
    app: database
    type: backup
    pvc: ${PVC_NAME}
spec:
  volumeSnapshotClassName: ebs-snapshot-class
  source:
    persistentVolumeClaimName: ${PVC_NAME}
EOF

# Step 3: Wait for snapshot
echo "Step 3: Waiting for snapshot..."
kubectl wait --for=jsonpath='{.status.readyToUse}'=true \
  volumesnapshot/${PVC_NAME}-backup-${TIMESTAMP} \
  -n $NAMESPACE \
  --timeout=300s

# Step 4: Resume application
echo "Step 4: Resuming application..."
kubectl exec -n $NAMESPACE deployment/database -- pg_ctl start || true

echo "=== Backup Complete: ${PVC_NAME}-backup-${TIMESTAMP} ==="
```

### 7.2 Restore Script

```bash
#!/bin/bash
# restore-database.sh

SNAPSHOT_NAME=$1
NEW_PVC_NAME=${2:-database-restored}
NAMESPACE=${3:-default}

if [ -z "$SNAPSHOT_NAME" ]; then
  echo "Usage: $0 <snapshot-name> [new-pvc-name] [namespace]"
  exit 1
fi

echo "=== Restoring from Snapshot: ${SNAPSHOT_NAME} ==="

# Step 1: Get original PVC size
ORIGINAL_SIZE=$(kubectl get volumesnapshot $SNAPSHOT_NAME -n $NAMESPACE \
  -o jsonpath='{.status.restoreSize}')

echo "Original size: ${ORIGINAL_SIZE}"

# Step 2: Create restored PVC
echo "Step 2: Creating restored PVC..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ${NEW_PVC_NAME}
  namespace: ${NAMESPACE}
spec:
  storageClassName: tier1-high-performance
  dataSource:
    name: ${SNAPSHOT_NAME}
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: ${ORIGINAL_SIZE}
EOF

# Step 3: Wait for PVC
echo "Step 3: Waiting for PVC..."
kubectl wait --for=jsonpath='{.status.phase}'=Bound \
  pvc/${NEW_PVC_NAME} \
  -n $NAMESPACE \
  --timeout=300s

echo "=== Restore Complete: ${NEW_PVC_NAME} ==="
```

---

## Part 8: Hands-on Challenges

### Challenge 1: Snapshot Testing Pipeline

Create a complete testing pipeline:
1. Create snapshot of production data
2. Restore to test namespace
3. Run integration tests
4. Clean up test resources

### Challenge 2: Point-in-Time Recovery

Implement PITR for PostgreSQL:
1. Regular base snapshots
2. WAL archiving to object storage
3. Recovery to specific timestamp
4. Automated testing of recovery

### Challenge 3: Multi-Region Snapshot Replication

Design snapshot replication:
1. Create snapshot in primary region
2. Copy to secondary region
3. Test restoration in secondary
4. Document RTO/RPO

---

## Verification Tasks

1. [ ] Created VolumeSnapshotClass
2. [ ] Took manual snapshot of PVC
3. [ ] Restored PVC from snapshot
4. [ ] Implemented scheduled snapshots
5. [ ] Created retention policy
6. [ ] Tested disaster recovery workflow

---

## Key Takeaways

- VolumeSnapshots provide point-in-time copies
- Snapshots are storage-backend dependent
- Deletion policy controls snapshot lifecycle
- Automated snapshots require RBAC setup
- Application quiescing ensures consistency
- Test recovery procedures regularly

---

## Next Steps

Continue to [Exercise 5: CSI Drivers](05-csi-drivers.md)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Volume Snapshot Architecture
- VolumeSnapshotClass
- Creating Snapshots
- Restoring from Snapshots

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
