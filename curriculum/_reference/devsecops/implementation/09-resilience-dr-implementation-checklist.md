# Resilience & Disaster Recovery -- Implementation Checklist

## Prerequisites

- [ ] Kubernetes cluster operational (Domain 4)
- [ ] Observability stack deployed (Domain 7) -- Prometheus + Grafana for metrics
- [ ] GCS buckets created for backups [GCP-SPECIFIC]
- [ ] GCP IAM service accounts created with appropriate permissions [GCP-SPECIFIC]
- [ ] `kubectl` and `velero` CLI tools installed locally
- [ ] GitHub Actions workflows repository exists

## Step 1: Deploy Velero

Install Velero for Kubernetes resource backup and PV snapshots.

```bash
# Create Velero namespace
kubectl apply -f templates/velero/namespace.yaml

# Deploy Velero via Kustomize (includes HelmRelease + schedules)
kubectl apply -k templates/velero/

# Or install via Helm directly
helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts
helm install velero vmware-tanzu/velero \
  --namespace velero \
  --create-namespace \
  --values templates/velero/velero.yaml
```

Replace placeholders in all Velero templates:
```bash
find templates/velero/ -type f -name '*.yaml' | xargs sed -i '' \
  -e 's/{{APP_NAME}}/your-app/g' \
  -e 's/{{APP_NAMESPACE}}/your-namespace/g' \
  -e 's/{{GCP_PROJECT_ID}}/your-project-id/g'
```

**Verification**:
```bash
# Velero server is running
kubectl get pods -n velero
# Expected: velero-* pod in Running state

# Backup storage location is available
velero backup-storage-location get
# Expected: gcs location with Phase "Available"

# Volume snapshot location is available
velero snapshot-location get
# Expected: gcs location listed
```

## Step 2: Configure Velero Backup Schedules

Apply the backup schedule manifests.

```bash
kubectl apply -f templates/velero/schedules.yaml
```

**Verification**:
```bash
# Schedules are created
velero schedule get
# Expected: daily-full-backup and hourly-app-backup listed

# Trigger a manual backup to test
velero backup create test-backup --include-namespaces {{APP_NAMESPACE}}
velero backup describe test-backup
# Expected: Phase "Completed" with no errors

# Clean up test backup
velero backup delete test-backup --confirm
```

## Step 3: Deploy Litestream for PostgreSQL WAL Streaming

Configure continuous PostgreSQL replication to GCS.

```bash
# Apply Litestream ConfigMap
kubectl apply -f templates/litestream/litestream-config.yaml

# Patch the PostgreSQL StatefulSet to add the Litestream sidecar
kubectl apply -f templates/litestream/postgres-litestream-sidecar.yaml
```

Replace placeholders:
```bash
find templates/litestream/ -type f -name '*.yaml' | xargs sed -i '' \
  -e 's/{{APP_NAMESPACE}}/your-namespace/g' \
  -e 's/{{GCP_PROJECT_ID}}/your-project-id/g'
```

**Verification**:
```bash
# Litestream sidecar is running alongside PostgreSQL
kubectl get pods -n {{APP_NAMESPACE}}-system -l app.kubernetes.io/name=postgres
# Expected: postgres-0 pod with 2/2 containers Ready

# Check Litestream replication status
kubectl logs -n {{APP_NAMESPACE}}-system postgres-0 -c litestream
# Expected: "replicating" log messages with WAL segment uploads

# Verify GCS bucket has WAL data [GCP-SPECIFIC]
gsutil ls gs://{{GCP_PROJECT_ID}}-backups/postgres/wal/
# Expected: WAL segment files listed
```

## Step 4: Configure etcd Backup Script

Deploy the etcd backup script and cron job on the control plane node.

```bash
# Copy backup script to control plane [KUBEADM-SPECIFIC]
scp templates/etcd-backup/k8s-backup.sh control-plane:/usr/local/bin/k8s-backup.sh

# Set permissions
ssh control-plane 'sudo chmod +x /usr/local/bin/k8s-backup.sh'

# Install cron job
scp templates/etcd-backup/k8s-backup-cron control-plane:/etc/cron.d/k8s-backup
```

Replace placeholders in the backup script:
```bash
sed -i '' 's/{{GCP_PROJECT_ID}}/your-project-id/g' templates/etcd-backup/k8s-backup.sh
```

**Verification**:
```bash
# Run backup manually
ssh control-plane 'sudo /usr/local/bin/k8s-backup.sh'
# Expected: "Backup completed" message

# Verify backup in GCS [GCP-SPECIFIC]
gsutil ls gs://{{GCP_PROJECT_ID}}-backups/etcd/
# Expected: etcd-YYYYMMDD-HHMMSS.db file listed

gsutil ls gs://{{GCP_PROJECT_ID}}-backups/pki/
# Expected: pki-YYYYMMDD-HHMMSS.tar.gz file listed

# Verify etcd snapshot integrity
ssh control-plane 'ETCDCTL_API=3 etcdctl snapshot status /mnt/data/backups/etcd-*.db --write-out=table'
# Expected: Hash, Revision, Total Keys, Total Size displayed
```

## Step 5: Deploy LitmusChaos

Install the chaos engineering platform.

```bash
# Create Litmus namespace
kubectl apply -f templates/litmus/namespace.yaml

# Deploy LitmusChaos via Kustomize
kubectl apply -k templates/litmus/

# Or install via Helm
helm repo add litmuschaos https://litmuschaos.github.io/litmus-helm/
helm install litmus litmuschaos/litmus \
  --namespace litmus \
  --create-namespace

helm install litmus-operator litmuschaos/chaos-operator \
  --namespace litmus
```

**Verification**:
```bash
# Litmus pods are running
kubectl get pods -n litmus
# Expected: litmus-frontend, litmus-server, litmus-auth, mongodb pods Running

# Chaos operator is running
kubectl get pods -n litmus -l app=chaos-operator
# Expected: chaos-operator pod in Running state

# CRDs are installed
kubectl get crds | grep litmuschaos
# Expected: chaosengines, chaosexperiments, chaosresults, chaosschedules
```

## Step 6: Deploy Chaos Experiments

Install the chaos experiment definitions and schedules.

```bash
# Deploy RBAC for chaos experiments
kubectl apply -f templates/litmus/litmus.yaml

# Deploy experiment definitions
kubectl apply -f templates/litmus/chaos-experiments.yaml

# Deploy chaos schedules
kubectl apply -f templates/litmus/chaos-schedules.yaml
```

Replace placeholders:
```bash
find templates/litmus/ -type f -name '*.yaml' | xargs sed -i '' \
  -e 's/{{APP_NAME}}/your-app/g' \
  -e 's/{{APP_NAMESPACE}}/your-namespace/g' \
  -e 's/{{SERVICE_NAME}}/your-service/g'
```

**Verification**:
```bash
# Experiments are registered
kubectl get chaosexperiments -n {{APP_NAMESPACE}}
# Expected: pod-delete, network-latency, cpu-stress, memory-stress, container-kill

# Chaos schedules are created
kubectl get chaosschedules -n {{APP_NAMESPACE}}
# Expected: weekly-chaos and monthly-full-chaos schedules listed

# Run a manual chaos experiment to test
kubectl apply -f consumer-templates/chaos-experiment.yaml
kubectl get chaosengine -n {{APP_NAMESPACE}}
# Expected: ChaosEngine with engineStatus "completed"

# Check experiment results
kubectl get chaosresults -n {{APP_NAMESPACE}}
# Expected: verdict "Pass" for pod-delete experiment
```

## Step 7: Deploy Platform Workflows

Copy the recovery and health check workflows to the infrastructure repository.

```bash
cp templates/platform-workflows/dr-test-workflow.yml \
   {{INFRASTRUCTURE_REPO}}/.github/workflows/reusable-dr-test.yml

cp templates/platform-workflows/cluster-recover.yml \
   {{INFRASTRUCTURE_REPO}}/.github/workflows/cluster-recover.yml

cp templates/platform-workflows/infrastructure-destroy-recreate.yml \
   {{INFRASTRUCTURE_REPO}}/.github/workflows/infrastructure-destroy-recreate.yml
```

Replace placeholders:
```bash
find {{INFRASTRUCTURE_REPO}}/.github/workflows/ -type f -name 'cluster-*' -o -name 'infrastructure-*' -o -name 'reusable-dr-*' | xargs sed -i '' \
  -e 's/{{APP_NAME}}/your-app/g' \
  -e 's/{{GCP_PROJECT_ID}}/your-project-id/g'
```

**Verification**:
```bash
# Validate workflow syntax
actionlint {{INFRASTRUCTURE_REPO}}/.github/workflows/cluster-recover.yml
actionlint {{INFRASTRUCTURE_REPO}}/.github/workflows/infrastructure-destroy-recreate.yml

# Trigger health check manually
gh workflow run cluster-health-check.yml -f environment=staging
# Expected: Workflow completes with HEALTHY status for all components
```

## Step 8: Validate End-to-End DR

Run a full DR test in the staging environment.

```bash
# 1. Create a known-good backup
velero backup create dr-test-backup \
  --include-namespaces {{APP_NAMESPACE}} \
  --wait

# 2. Verify backup completed
velero backup describe dr-test-backup
# Expected: Phase "Completed"

# 3. Delete a test deployment
kubectl delete deployment {{SERVICE_NAME}} -n {{APP_NAMESPACE}}

# 4. Restore from backup
velero restore create dr-test-restore \
  --from-backup dr-test-backup \
  --include-namespaces {{APP_NAMESPACE}} \
  --wait

# 5. Verify restore
kubectl get deployment {{SERVICE_NAME}} -n {{APP_NAMESPACE}}
# Expected: Deployment restored with correct replica count

# 6. Verify application health
kubectl get pods -n {{APP_NAMESPACE}} -l app={{SERVICE_NAME}}
# Expected: All pods in Running state

# 7. Clean up
velero backup delete dr-test-backup --confirm
```

## Step 9: Configure Alerting for Backup Failures

```bash
# Apply Prometheus alerting rules for backup monitoring
kubectl apply -f - <<EOF
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: backup-alerts
  namespace: monitoring
  labels:
    release: kube-prometheus-stack
spec:
  groups:
    - name: backup-alerts
      rules:
        - alert: VeleroBackupFailed
          expr: velero_backup_failure_total > 0
          for: 1h
          labels:
            severity: critical
          annotations:
            summary: "Velero backup has failed"
        - alert: VeleroBackupMissing
          expr: time() - velero_backup_last_successful_timestamp > 86400
          for: 1h
          labels:
            severity: warning
          annotations:
            summary: "No successful Velero backup in the last 24 hours"
EOF
```

**Verification**:
```bash
# Check Prometheus rules loaded
kubectl get prometheusrules -n monitoring
# Expected: backup-alerts rule listed

# Check Velero metrics are being scraped
kubectl port-forward -n velero svc/velero 8085:8085
curl -s localhost:8085/metrics | grep velero_backup
# Expected: velero_backup_* metrics present
```

## Post-Implementation Verification Summary

| Component | Verification Command | Expected Result |
|-----------|---------------------|-----------------|
| Velero server | `kubectl get pods -n velero` | Running |
| Backup storage | `velero backup-storage-location get` | Phase: Available |
| Backup schedules | `velero schedule get` | 2 schedules listed |
| Litestream sidecar | `kubectl get pods -n {{APP_NAMESPACE}}-system -l app.kubernetes.io/name=postgres` | 2/2 Ready |
| etcd backup cron | `ssh control-plane 'crontab -l'` | Daily 2 AM entry |
| Litmus operator | `kubectl get pods -n litmus` | All Running |
| Chaos experiments | `kubectl get chaosexperiments -n {{APP_NAMESPACE}}` | 5 experiments |
| Recovery workflows | `gh workflow list` | cluster-recover, infrastructure-destroy-recreate |
| Backup alerts | `kubectl get prometheusrules -n monitoring` | backup-alerts listed |

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Deploy Velero
- Configure Velero Backup Schedules
- Deploy Litestream for PostgreSQL WAL Streaming
- Configure etcd Backup Script

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
