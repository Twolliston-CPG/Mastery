# Exercise 2: Storage Classes

## Objectives

- Configure StorageClasses for dynamic provisioning
- Understand storage class parameters
- Implement storage tiers
- Set default storage class

## Prerequisites

- Completed Exercise 1
- Understanding of PV/PVC concepts
- Access to storage provisioner

---

## Part 1: StorageClass Fundamentals

### 1.1 Understanding StorageClasses

StorageClasses enable dynamic provisioning:
- Define storage "tiers" (fast, standard, archive)
- Specify provisioner and parameters
- Control reclaim policy and binding mode

### 1.2 Viewing Existing StorageClasses

```bash
# List storage classes
kubectl get storageclass

# Describe default storage class
kubectl describe storageclass

# View in YAML
kubectl get storageclass -o yaml
```

### 1.3 StorageClass Structure

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: my-storage-class
  annotations:
    storageclass.kubernetes.io/is-default-class: "false"
provisioner: kubernetes.io/aws-ebs    # Provider-specific
parameters:
  type: gp3                           # Provider-specific parameters
  fsType: ext4
reclaimPolicy: Delete                 # Delete or Retain
allowVolumeExpansion: true           # Allow PVC resize
volumeBindingMode: WaitForFirstConsumer  # Immediate or WaitForFirstConsumer
mountOptions:                         # Mount options for volumes
  - debug
```

---

## Part 2: Cloud Provider StorageClasses

### 2.1 AWS EBS StorageClass

```yaml
# aws-ebs-storageclass.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  iops: "3000"
  throughput: "125"
  encrypted: "true"
  kmsKeyId: "arn:aws:kms:us-west-2:111122223333:key/1234abcd-12ab-34cd-56ef-1234567890ab"
reclaimPolicy: Delete
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: high-iops
provisioner: ebs.csi.aws.com
parameters:
  type: io2
  iops: "10000"
  encrypted: "true"
reclaimPolicy: Retain
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
```

### 2.2 GCP Persistent Disk StorageClass

```yaml
# gcp-pd-storageclass.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: pd.csi.storage.gke.io
parameters:
  type: pd-ssd
  replication-type: regional-pd
reclaimPolicy: Retain
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: standard
provisioner: pd.csi.storage.gke.io
parameters:
  type: pd-balanced
reclaimPolicy: Delete
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
```

### 2.3 Azure Disk StorageClass

```yaml
# azure-disk-storageclass.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: premium-ssd
provisioner: disk.csi.azure.com
parameters:
  skuName: Premium_LRS
  cachingMode: ReadOnly
reclaimPolicy: Delete
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ultra-disk
provisioner: disk.csi.azure.com
parameters:
  skuName: UltraSSD_LRS
  DiskIOPSReadWrite: "10000"
  DiskMBpsReadWrite: "100"
reclaimPolicy: Retain
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
```

---

## Part 3: Local Storage Classes

### 3.1 Local Path Provisioner

```bash
# Install local path provisioner (for local clusters)
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.26/deploy/local-path-storage.yaml

# Verify
kubectl get storageclass local-path
```

### 3.2 HostPath StorageClass (Development Only)

```yaml
# hostpath-storageclass.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-storage
provisioner: kubernetes.io/no-provisioner  # Manual provisioning
volumeBindingMode: WaitForFirstConsumer
---
# Manually create PV
apiVersion: v1
kind: PersistentVolume
metadata:
  name: local-pv-1
spec:
  capacity:
    storage: 10Gi
  volumeMode: Filesystem
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
  local:
    path: /mnt/data
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - node-1
```

---

## Part 4: Storage Tiers

### 4.1 Implementing Storage Tiers

```yaml
# storage-tiers.yaml
# Tier 1: High Performance
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: tier1-high-performance
  labels:
    tier: "1"
    performance: high
provisioner: ebs.csi.aws.com
parameters:
  type: io2
  iops: "16000"
  encrypted: "true"
reclaimPolicy: Retain
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
---
# Tier 2: Standard
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: tier2-standard
  labels:
    tier: "2"
    performance: standard
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  encrypted: "true"
reclaimPolicy: Delete
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
---
# Tier 3: Archive/Cold
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: tier3-archive
  labels:
    tier: "3"
    performance: low
provisioner: ebs.csi.aws.com
parameters:
  type: sc1
  encrypted: "true"
reclaimPolicy: Retain
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
```

### 4.2 Using Storage Tiers

```yaml
# database-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: database-storage
spec:
  storageClassName: tier1-high-performance
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 100Gi
---
# logs-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: logs-storage
spec:
  storageClassName: tier3-archive
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 500Gi
```

---

## Part 5: Volume Binding Modes

### 5.1 Immediate Binding

```yaml
# immediate-binding.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: immediate-class
provisioner: ebs.csi.aws.com
volumeBindingMode: Immediate  # PV created immediately when PVC created
```

- PV provisioned when PVC created
- May cause zone mismatch with pods
- Use for pre-provisioning scenarios

### 5.2 WaitForFirstConsumer

```yaml
# wait-for-consumer.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: delayed-binding
provisioner: ebs.csi.aws.com
volumeBindingMode: WaitForFirstConsumer  # Wait for pod scheduling
```

- PV provisioned when pod scheduled
- Ensures zone alignment
- Recommended for most cases

### 5.3 Demonstrating Binding Modes

```bash
# Create PVC with WaitForFirstConsumer
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: delayed-pvc
spec:
  storageClassName: delayed-binding
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
EOF

# PVC stays Pending until pod uses it
kubectl get pvc delayed-pvc

# Create pod
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
spec:
  containers:
  - name: test
    image: nginx:1.25
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: delayed-pvc
EOF

# Now PVC binds and pod starts
kubectl get pvc delayed-pvc
kubectl get pod test-pod
```

---

## Part 6: Default StorageClass

### 6.1 Setting Default StorageClass

```bash
# View current default
kubectl get storageclass

# Remove default from current class
kubectl patch storageclass <current-default> -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'

# Set new default
kubectl patch storageclass tier2-standard -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

### 6.2 PVC Without StorageClass

```yaml
# pvc-no-class.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: default-class-pvc
spec:
  # No storageClassName specified - uses default
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
```

```bash
kubectl apply -f pvc-no-class.yaml

# Verify it uses default class
kubectl get pvc default-class-pvc -o jsonpath='{.spec.storageClassName}'
```

---

## Part 7: Reclaim Policies

### 7.1 Delete Policy

```yaml
reclaimPolicy: Delete
# PV and underlying storage deleted when PVC deleted
# Use for temporary/replaceable data
```

### 7.2 Retain Policy

```yaml
reclaimPolicy: Retain
# PV retained when PVC deleted (becomes Released)
# Manual cleanup required
# Use for important data
```

### 7.3 Changing Reclaim Policy

```bash
# Change PV reclaim policy
kubectl patch pv <pv-name> -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'

# List PVs with reclaim policy
kubectl get pv -o custom-columns=NAME:.metadata.name,RECLAIM:.spec.persistentVolumeReclaimPolicy,STATUS:.status.phase
```

---

## Part 8: Hands-on Challenges

### Challenge 1: Multi-Tier Storage Setup

Create a complete storage tier system:
1. High-performance SSD tier for databases
2. Standard tier for applications
3. Archive tier for backups/logs
4. Set appropriate default

### Challenge 2: Cross-Zone Storage

Configure storage that works across availability zones:
1. Use WaitForFirstConsumer binding
2. Test pod scheduling with zone awareness
3. Verify storage and pod co-location

### Challenge 3: Storage Migration

Plan and execute storage class migration:
1. Create new StorageClass
2. Migrate data from old to new
3. Update applications
4. Clean up old resources

---

## Verification Tasks

1. [ ] Created cloud-specific StorageClasses
2. [ ] Implemented storage tier system
3. [ ] Configured volume binding modes
4. [ ] Set default StorageClass
5. [ ] Tested reclaim policies
6. [ ] Demonstrated zone-aware provisioning

---

## Key Takeaways

- StorageClasses enable dynamic provisioning
- Parameters are provider-specific
- WaitForFirstConsumer prevents zone issues
- Storage tiers match workload requirements
- Reclaim policy protects important data
- Default class simplifies PVC creation

---

## Next Steps

Continue to [Exercise 3: Stateful Workloads](03-stateful-workloads.md)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- StorageClass Fundamentals
- Cloud Provider StorageClasses
- Local Storage Classes
- Storage Tiers

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
