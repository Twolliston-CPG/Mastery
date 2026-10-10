# Resilience & Disaster Recovery -- Configuration Reference

## Velero Configuration

### HelmRelease Values

```yaml
# Source: k8s-manifests/infrastructure/velero/velero.yaml
spec:
  chart:
    spec:
      chart: velero
      version: "5.2.0"                          # Velero Helm chart version
      sourceRef:
        kind: HelmRepository
        name: vmware-tanzu                       # Official VMware Tanzu Helm repo

  values:
    resources:
      limits:
        memory: 512Mi                            # Velero server memory limit
        cpu: 500m                                # Velero server CPU limit
      requests:
        memory: 256Mi
        cpu: 100m

    initContainers:
      - name: velero-plugin-for-gcp              # [GCP-SPECIFIC] GCS storage plugin
        image: velero/velero-plugin-for-gcp:v1.8.0
        volumeMounts:
          - mountPath: /target
            name: plugins

    configuration:
      backupStorageLocation:
        - name: gcs                              # [GCP-SPECIFIC] GCS backup location
          provider: gcp
          bucket: {{APP_NAME}}-velero-backups     # GCS bucket name
          config:
            serviceAccount: {{APP_NAME}}-velero@{{GCP_PROJECT_ID}}.iam.gserviceaccount.com

      volumeSnapshotLocation:
        - name: gcs                              # [GCP-SPECIFIC] GCE PD snapshot location
          provider: gcp
          config:
            project: {{GCP_PROJECT_ID}}
            snapshotLocation: us-central1        # GCE region for snapshots

      defaultBackupTTL: 720h                     # 30 days default retention
      features: EnableCSI                        # CSI snapshot support

    serviceAccount:
      server:
        create: true
        annotations:
          # [GCP-SPECIFIC] Workload Identity binding
          iam.gke.io/gcp-service-account: {{APP_NAME}}-velero@{{GCP_PROJECT_ID}}.iam.gserviceaccount.com

    deployNodeAgent: true                        # Required for filesystem-level backups

    nodeAgent:
      resources:
        limits:
          memory: 256Mi
          cpu: 200m
        requests:
          memory: 128Mi
          cpu: 50m

    metrics:
      enabled: true                              # Expose Prometheus metrics
      serviceMonitor:
        enabled: true
        additionalLabels:
          release: kube-prometheus-stack          # Match Prometheus Operator selector
```

### Backup Schedules

```yaml
# --- Daily Full Backup ---
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: daily-full-backup
  namespace: velero
spec:
  schedule: "0 2 * * *"                          # Daily at 2 AM UTC
  template:
    includedNamespaces:
      - {{APP_NAMESPACE}}                        # Application namespace
      - {{APP_NAMESPACE}}-system                 # System namespace
    excludedResources:
      - events                                   # Exclude noisy event resources
      - events.events.k8s.io
    includeClusterResources: true                # Include ClusterRoles, CRDs, etc.
    storageLocation: gcs                         # [GCP-SPECIFIC]
    volumeSnapshotLocations:
      - gcs                                      # [GCP-SPECIFIC] PV snapshot location
    ttl: 720h                                    # 30 days retention
    snapshotVolumes: true                        # Snapshot PersistentVolumes
    defaultVolumesToFsBackup: false              # Use CSI snapshots, not fs backup

# --- Hourly Application Backup ---
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: hourly-app-backup
  namespace: velero
spec:
  schedule: "0 * * * *"                          # Every hour
  template:
    includedNamespaces:
      - {{APP_NAMESPACE}}                        # Application namespace only
    excludedResources:
      - events
      - events.events.k8s.io
      - persistentvolumeclaims                   # Exclude PVs (handled by daily backup)
      - persistentvolumes
    includeClusterResources: false               # Namespace-scoped only
    storageLocation: gcs                         # [GCP-SPECIFIC]
    ttl: 168h                                    # 7 days retention
    snapshotVolumes: false                       # Resources only, no volume snapshots
```

### Pre-Deployment Backup Template

```yaml
# Triggered manually or by CI/CD before deployments
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: pre-deployment-template
  namespace: velero
  labels:
    backup-type: pre-deployment
spec:
  includedNamespaces:
    - {{APP_NAMESPACE}}
    - {{APP_NAMESPACE}}-system
  includeClusterResources: true
  storageLocation: gcs                           # [GCP-SPECIFIC]
  volumeSnapshotLocations:
    - gcs                                        # [GCP-SPECIFIC]
  ttl: 168h                                      # 7 days retention
  snapshotVolumes: true
```

---

## Litestream Configuration

### ConfigMap

```yaml
# Source: k8s-manifests/infrastructure/postgres/postgres.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: litestream-config
  namespace: {{APP_NAMESPACE}}-system
data:
  litestream.yml: |
    dbs:
      - path: /var/lib/postgresql/data/pgdata    # PostgreSQL data directory
        replicas:
          - type: gcs                            # [GCP-SPECIFIC] Replica to GCS
            bucket: {{GCP_PROJECT_ID}}-backups    # GCS bucket for WAL streaming
            path: postgres/wal                   # Prefix path within bucket
            sync-interval: 10s                   # WAL sync every 10 seconds (RPO ~10s)
            snapshot-interval: 1h                # Full snapshot every hour
```

### PostgreSQL WAL Settings (Required for Litestream)

```ini
# Source: k8s-manifests/infrastructure/postgres/postgres.yaml (postgresql.conf)
wal_level = replica                              # Required: enables WAL archiving
archive_mode = on                                # Required: enables archive_command
archive_command = 'true'                         # Litestream handles archiving directly
max_wal_senders = 3                              # Allow replication connections
wal_keep_size = 256MB                            # Retain WAL segments on disk
```

### Litestream Sidecar Container (Recommended Addition)

```yaml
# Add as a sidecar container in the PostgreSQL StatefulSet
containers:
  - name: litestream
    image: litestream/litestream:0.3.13
    args:
      - replicate
    volumeMounts:
      - name: data
        mountPath: /var/lib/postgresql/data      # Shared volume with PostgreSQL
      - name: litestream-config
        mountPath: /etc/litestream.yml
        subPath: litestream.yml
    resources:
      limits:
        memory: 128Mi
        cpu: 100m
      requests:
        memory: 64Mi
        cpu: 50m
    env:
      - name: GOOGLE_APPLICATION_CREDENTIALS     # [GCP-SPECIFIC]
        value: /var/run/secrets/gcp/key.json     # Or use Workload Identity
```

---

## LitmusChaos Configuration

### HelmRelease Values

```yaml
# Source: k8s-manifests/infrastructure/litmus/litmus.yaml
# --- LitmusChaos Control Plane ---
spec:
  chart:
    spec:
      chart: litmus
      version: "3.0.0"
  values:
    portal:
      frontend:
        resources:
          limits:
            memory: 256Mi
            cpu: 200m
          requests:
            memory: 128Mi
            cpu: 50m
      server:
        resources:
          limits:
            memory: 512Mi
            cpu: 500m
          requests:
            memory: 256Mi
            cpu: 100m
      auth:
        resources:
          limits:
            memory: 256Mi
            cpu: 200m
          requests:
            memory: 128Mi
            cpu: 50m

    mongodb:
      resources:
        limits:
          memory: 512Mi
          cpu: 500m
        requests:
          memory: 256Mi
          cpu: 100m
      persistence:
        enabled: true
        size: 10Gi
        storageClass: standard                   # Adjust to your storage class

    prometheus:
      enabled: true
      serviceMonitor:
        enabled: true
        additionalLabels:
          release: kube-prometheus-stack

    securityContext:
      runAsNonRoot: true
      runAsUser: 1000
      fsGroup: 1000

    ingress:
      enabled: false                             # Access via port-forward only
```

### Chaos Operator

```yaml
# Depends on litmus control plane
spec:
  chart:
    spec:
      chart: chaos-operator
      version: "3.0.0"
  values:
    operator:
      resources:
        limits:
          memory: 256Mi
          cpu: 200m
        requests:
          memory: 128Mi
          cpu: 50m
    runner:
      resources:
        limits:
          memory: 256Mi
          cpu: 200m
        requests:
          memory: 128Mi
          cpu: 50m
```

### RBAC Configuration

```yaml
# ClusterRole for chaos experiments
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: litmus-chaos-admin
rules:
  - apiGroups: [""]
    resources: ["pods", "pods/log", "pods/exec", "services", "configmaps", "secrets"]
    verbs: ["get", "list", "watch", "create", "delete", "patch"]
  - apiGroups: ["apps"]
    resources: ["deployments", "replicasets", "statefulsets", "daemonsets"]
    verbs: ["get", "list", "watch", "patch", "delete"]
  - apiGroups: ["litmuschaos.io"]
    resources: ["*"]
    verbs: ["*"]
  - apiGroups: ["batch"]
    resources: ["jobs"]
    verbs: ["get", "list", "watch", "create", "delete"]
```

### Chaos Experiment Environment Variables

| Experiment | Variable | Default | Description |
|-----------|----------|---------|-------------|
| pod-delete | `TOTAL_CHAOS_DURATION` | `30` | Duration in seconds |
| pod-delete | `CHAOS_INTERVAL` | `10` | Interval between pod kills |
| pod-delete | `FORCE` | `false` | Force delete (bypass graceful) |
| pod-delete | `PODS_AFFECTED_PERC` | `50` | Percentage of pods to target |
| pod-delete | `SEQUENCE` | `parallel` | Kill pods in parallel or serial |
| network-latency | `NETWORK_LATENCY` | `200` | Latency in milliseconds |
| network-latency | `JITTER` | `50` | Jitter in milliseconds |
| network-latency | `CONTAINER_RUNTIME` | `containerd` | Container runtime type |
| network-latency | `SOCKET_PATH` | `/run/containerd/containerd.sock` | Runtime socket path |
| cpu-stress | `CPU_CORES` | `1` | Number of CPU cores to stress |
| cpu-stress | `CPU_LOAD` | `80` | CPU load percentage |
| memory-stress | `MEMORY_CONSUMPTION` | `500` | Memory consumption in MB |
| container-kill | `SIGNAL` | `SIGKILL` | Kill signal to send |

---

## etcd Backup Configuration

### Backup Script

```bash
#!/bin/bash
# Source: modules/k8s-cluster/scripts/control-plane-init.sh (embedded)
# [KUBEADM-SPECIFIC] etcd backup for kubeadm-managed clusters
set -euo pipefail

BACKUP_BUCKET="{{GCP_PROJECT_ID}}-backups"       # [GCP-SPECIFIC] GCS bucket
BACKUP_DIR="/mnt/data/backups"                    # Local backup staging directory
DATE=$(date +%Y%m%d-%H%M%S)

echo "Starting backup at $DATE"

# Backup etcd snapshot
ETCDCTL_API=3 etcdctl snapshot save "$BACKUP_DIR/etcd-$DATE.db" \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \      # etcd CA certificate
  --cert=/etc/kubernetes/pki/etcd/server.crt \    # etcd server certificate
  --key=/etc/kubernetes/pki/etcd/server.key        # etcd server key

# Backup Kubernetes PKI certificates
tar -czf "$BACKUP_DIR/pki-$DATE.tar.gz" -C /etc/kubernetes pki

# Backup kubeadm configuration
cp /etc/kubernetes/kubeadm-config.yaml "$BACKUP_DIR/kubeadm-config-$DATE.yaml"

# Upload to GCS [GCP-SPECIFIC]
gsutil -m cp "$BACKUP_DIR/etcd-$DATE.db" "gs://$BACKUP_BUCKET/etcd/"
gsutil -m cp "$BACKUP_DIR/pki-$DATE.tar.gz" "gs://$BACKUP_BUCKET/pki/"
gsutil -m cp "$BACKUP_DIR/kubeadm-config-$DATE.yaml" "gs://$BACKUP_BUCKET/config/"

# Cleanup local backups older than 3 days
find "$BACKUP_DIR" -type f -mtime +3 -delete

echo "Backup completed at $(date)"
```

### Cron Schedule

```cron
# Daily etcd backup at 2 AM
0 2 * * * root /usr/local/bin/k8s-backup.sh >> /var/log/k8s-backup.log 2>&1
```

### etcd Connection Parameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| `--endpoints` | `https://127.0.0.1:2379` | Local etcd endpoint |
| `--cacert` | `/etc/kubernetes/pki/etcd/ca.crt` | etcd CA certificate [KUBEADM-SPECIFIC] |
| `--cert` | `/etc/kubernetes/pki/etcd/server.crt` | etcd server certificate [KUBEADM-SPECIFIC] |
| `--key` | `/etc/kubernetes/pki/etcd/server.key` | etcd server key [KUBEADM-SPECIFIC] |

### GCS Bucket Structure [GCP-SPECIFIC]

```
gs://{{GCP_PROJECT_ID}}-backups/
  etcd/
    etcd-YYYYMMDD-HHMMSS.db                     # etcd snapshots
  pki/
    pki-YYYYMMDD-HHMMSS.tar.gz                  # PKI certificate archives
  config/
    kubeadm-config-YYYYMMDD-HHMMSS.yaml          # kubeadm configuration
```

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Velero Configuration
- Litestream Configuration
- LitmusChaos Configuration
- etcd Backup Configuration

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"We scan for vulnerabilities in the pipeline."* |
| ✓ | *"SAST reads source without running it, SCA resolves the dependency tree against an advisory database, and image scanning compares installed package versions to that same database. All three report what was known at build time — which is why the registry is re-scanned: the image does not change, the database does."* |

**Trace it:** A CVE published today against your base image → a blocked deploy. Name every component between the advisory and the refused `apply`.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** the [SLSA threat model](https://slsa.dev/spec/v1.2/threats) — it names every point at which a build can be subverted, and most teams defend three of them.
Full list per domain: [`SOURCES.md`](../../SOURCES.md#devsecops)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../../MASTERY.md)

<!-- /feynman-check -->
