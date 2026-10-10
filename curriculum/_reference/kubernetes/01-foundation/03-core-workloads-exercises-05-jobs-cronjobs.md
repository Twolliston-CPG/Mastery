# Exercise 5: Jobs and CronJobs

## Objectives

- Understand Job completion semantics
- Configure parallelism and completions
- Schedule recurring tasks with CronJobs
- Handle job failures and retries

## Prerequisites

- Completed Exercises 1-4
- Understanding of Pod concepts
- kubectl proficiency

---

## Part 1: Job Fundamentals

### 1.1 Simple Job

```yaml
# job-basic.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: hello-job
spec:
  template:
    spec:
      containers:
      - name: hello
        image: busybox:1.36
        command: ["sh", "-c", "echo 'Hello from Kubernetes Job!' && sleep 5"]
      restartPolicy: Never  # Required for Jobs
```

```bash
kubectl apply -f job-basic.yaml

# Watch job progress
kubectl get jobs hello-job -w

# View pod created by job
kubectl get pods -l job-name=hello-job

# Check logs
kubectl logs -l job-name=hello-job

# Describe job
kubectl describe job hello-job

# Cleanup
kubectl delete job hello-job
```

### 1.2 Job Completion States

```
Job States:
- Active: Pods are running
- Succeeded: Required completions achieved
- Failed: backoffLimit exceeded

Pod restartPolicy for Jobs:
- Never: Create new pod on failure
- OnFailure: Restart container in same pod
```

---

## Part 2: Job Configurations

### 2.1 Single Completion Job

```yaml
# job-single.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: data-processor
spec:
  completions: 1           # Run once (default)
  parallelism: 1           # One pod at a time (default)
  backoffLimit: 3          # Retry 3 times on failure
  activeDeadlineSeconds: 100  # Total time limit
  template:
    spec:
      containers:
      - name: processor
        image: busybox:1.36
        command: ["sh", "-c"]
        args:
        - |
          echo "Processing data..."
          sleep 10
          echo "Data processed successfully!"
      restartPolicy: Never
```

### 2.2 Multiple Completions (Sequential)

```yaml
# job-multiple-sequential.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: batch-sequential
spec:
  completions: 5           # Run 5 times total
  parallelism: 1           # One at a time (sequential)
  template:
    spec:
      containers:
      - name: worker
        image: busybox:1.36
        command: ["sh", "-c", "echo Processing item $RANDOM && sleep 3"]
      restartPolicy: Never
```

```bash
kubectl apply -f job-multiple-sequential.yaml

# Watch pods being created one at a time
kubectl get pods -l job-name=batch-sequential -w
```

### 2.3 Parallel Jobs

```yaml
# job-parallel.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: batch-parallel
spec:
  completions: 10          # Total completions needed
  parallelism: 3           # Run 3 pods at a time
  template:
    spec:
      containers:
      - name: worker
        image: busybox:1.36
        command: ["sh", "-c"]
        args:
        - |
          echo "Worker started at $(date)"
          WORK_TIME=$((RANDOM % 10 + 5))
          echo "Working for $WORK_TIME seconds..."
          sleep $WORK_TIME
          echo "Worker completed at $(date)"
      restartPolicy: Never
```

```bash
kubectl apply -f job-parallel.yaml

# Watch 3 pods running in parallel
kubectl get pods -l job-name=batch-parallel -w

# View job progress
kubectl get job batch-parallel -w
```

### 2.4 Work Queue Pattern

```yaml
# job-workqueue.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: work-queue
spec:
  completions: null        # Unset - pods determine completion
  parallelism: 3           # Worker count
  template:
    spec:
      containers:
      - name: worker
        image: busybox:1.36
        command: ["sh", "-c"]
        args:
        - |
          # Simulate pulling work from queue
          ITEMS=$((RANDOM % 5 + 1))
          for i in $(seq 1 $ITEMS); do
            echo "Processing item $i"
            sleep 2
          done
          echo "Queue empty, exiting"
      restartPolicy: Never
```

---

## Part 3: Failure Handling

### 3.1 Backoff Limit

```yaml
# job-failure.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: failing-job
spec:
  backoffLimit: 4          # Allow 4 retries
  template:
    spec:
      containers:
      - name: fail
        image: busybox:1.36
        command: ["sh", "-c", "echo 'Attempting...' && exit 1"]
      restartPolicy: Never
```

```bash
kubectl apply -f job-failure.yaml

# Watch retries with exponential backoff
kubectl get pods -l job-name=failing-job -w

# Check job events
kubectl describe job failing-job
```

### 3.2 Pod Failure Policy (Kubernetes 1.26+)

```yaml
# job-failure-policy.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: controlled-failure
spec:
  backoffLimit: 6
  podFailurePolicy:
    rules:
    - action: FailJob           # Fail immediately on this error
      onExitCodes:
        operator: In
        values: [42]            # Exit code 42 = permanent failure
    - action: Ignore            # Don't count as failure
      onPodConditions:
      - type: DisruptionTarget  # Node drain, preemption
    - action: Count             # Count toward backoffLimit (default)
      onExitCodes:
        operator: NotIn
        values: [42]
  template:
    spec:
      containers:
      - name: worker
        image: busybox:1.36
        command: ["sh", "-c"]
        args:
        - |
          RANDOM_NUM=$((RANDOM % 10))
          if [ $RANDOM_NUM -eq 0 ]; then
            echo "Permanent failure!"
            exit 42
          elif [ $RANDOM_NUM -lt 5 ]; then
            echo "Temporary failure, retrying..."
            exit 1
          else
            echo "Success!"
            exit 0
          fi
      restartPolicy: Never
```

### 3.3 Active Deadline

```yaml
# job-deadline.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: deadline-job
spec:
  activeDeadlineSeconds: 30  # Job times out after 30 seconds
  template:
    spec:
      containers:
      - name: slow
        image: busybox:1.36
        command: ["sh", "-c", "echo 'Starting long task...' && sleep 60"]
      restartPolicy: Never
```

---

## Part 4: CronJobs

### 4.1 Basic CronJob

```yaml
# cronjob-basic.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: hello-cron
spec:
  schedule: "*/5 * * * *"    # Every 5 minutes
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: hello
            image: busybox:1.36
            command: ["sh", "-c", "echo 'Hello at $(date)'"]
          restartPolicy: OnFailure
```

```bash
kubectl apply -f cronjob-basic.yaml

# Check CronJob
kubectl get cronjob hello-cron

# Wait for job to run and check
kubectl get jobs -l app=hello-cron

# View logs from most recent job
kubectl logs -l job-name=$(kubectl get jobs -l app=hello-cron -o jsonpath='{.items[-1].metadata.name}')
```

### 4.2 Cron Schedule Syntax

**Cron schedule syntax**

```text
┌───────────── minute        (0 – 59)
│ ┌───────────── hour        (0 – 23)
│ │ ┌───────────── day of month (1 – 31)
│ │ │ ┌───────────── month     (1 – 12)
│ │ │ │ ┌───────────── day of week (0 – 6, Sunday = 0)
│ │ │ │ │
* * * * *
```

| Expression | Means |
|---|---|
| `0 * * * *` | Every hour |
| `0 0 * * *` | Every day at midnight |
| `0 0 * * 0` | Every Sunday at midnight |
| `*/15 * * * *` | Every 15 minutes |
| `0 9-17 * * 1-5` | Hourly from 09:00 to 17:00, weekdays only |
| `0 0 1 * *` | The first of every month |

Two fields can both restrict the day — day-of-month and day-of-week. When **both** are set to
something other than `*`, cron runs on either match, not both. `0 0 13 * 5` is the 13th *and* every
Friday, which is rarely what was meant.

### 4.3 CronJob Policies

```yaml
# cronjob-policies.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: backup-cron
spec:
  schedule: "0 2 * * *"               # 2 AM daily
  timeZone: "America/New_York"        # Timezone (K8s 1.27+)
  concurrencyPolicy: Forbid           # Don't run if previous still running
  successfulJobsHistoryLimit: 3       # Keep 3 successful job records
  failedJobsHistoryLimit: 1           # Keep 1 failed job record
  startingDeadlineSeconds: 200        # Start within 200s or skip
  suspend: false                      # Set true to pause scheduling
  jobTemplate:
    spec:
      activeDeadlineSeconds: 3600     # 1 hour timeout
      backoffLimit: 2
      template:
        spec:
          containers:
          - name: backup
            image: busybox:1.36
            command: ["sh", "-c"]
            args:
            - |
              echo "Starting backup at $(date)"
              sleep 60
              echo "Backup completed at $(date)"
          restartPolicy: OnFailure
```

### 4.4 Concurrency Policies

```yaml
# Allow: Default - allow concurrent runs
concurrencyPolicy: Allow

# Forbid: Skip if previous still running
concurrencyPolicy: Forbid

# Replace: Stop previous, start new
concurrencyPolicy: Replace
```

---

## Part 5: Real-World Examples

### 5.1 Database Backup Job

```yaml
# database-backup.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgres-backup
spec:
  schedule: "0 3 * * *"  # 3 AM daily
  concurrencyPolicy: Forbid
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: postgres:15
            command: ["sh", "-c"]
            args:
            - |
              TIMESTAMP=$(date +%Y%m%d_%H%M%S)
              BACKUP_FILE="/backup/db_$TIMESTAMP.sql.gz"

              echo "Starting backup at $(date)"
              pg_dump -h $POSTGRES_HOST -U $POSTGRES_USER $POSTGRES_DB | gzip > $BACKUP_FILE

              if [ $? -eq 0 ]; then
                echo "Backup successful: $BACKUP_FILE"
                ls -lh $BACKUP_FILE
              else
                echo "Backup failed!"
                exit 1
              fi
            env:
            - name: POSTGRES_HOST
              value: "postgres-service"
            - name: POSTGRES_USER
              valueFrom:
                secretKeyRef:
                  name: postgres-secret
                  key: username
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: postgres-secret
                  key: password
            - name: POSTGRES_DB
              value: "production"
            - name: PGPASSWORD
              valueFrom:
                secretKeyRef:
                  name: postgres-secret
                  key: password
            volumeMounts:
            - name: backup-volume
              mountPath: /backup
          restartPolicy: OnFailure
          volumes:
          - name: backup-volume
            persistentVolumeClaim:
              claimName: backup-pvc
```

### 5.2 Data Processing Pipeline

```yaml
# data-pipeline.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: etl-pipeline
spec:
  completions: 1
  backoffLimit: 2
  template:
    spec:
      initContainers:
      # Extract
      - name: extract
        image: busybox:1.36
        command: ["sh", "-c"]
        args:
        - |
          echo "Extracting data..."
          echo '{"id": 1, "value": 100}' > /data/extracted.json
          echo '{"id": 2, "value": 200}' >> /data/extracted.json
        volumeMounts:
        - name: data
          mountPath: /data

      # Transform
      - name: transform
        image: busybox:1.36
        command: ["sh", "-c"]
        args:
        - |
          echo "Transforming data..."
          # Simple transformation
          cat /data/extracted.json | while read line; do
            echo "$line" | sed 's/"value":/"transformed_value":/'
          done > /data/transformed.json
        volumeMounts:
        - name: data
          mountPath: /data

      containers:
      # Load
      - name: load
        image: busybox:1.36
        command: ["sh", "-c"]
        args:
        - |
          echo "Loading data..."
          cat /data/transformed.json
          echo "ETL Pipeline completed!"
        volumeMounts:
        - name: data
          mountPath: /data

      restartPolicy: Never
      volumes:
      - name: data
        emptyDir: {}
```

### 5.3 Cleanup Job

```yaml
# cleanup-cronjob.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: cleanup-old-data
spec:
  schedule: "0 4 * * 0"  # 4 AM every Sunday
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: cleanup-sa
          containers:
          - name: cleanup
            image: bitnami/kubectl:latest
            command: ["sh", "-c"]
            args:
            - |
              echo "Cleaning up completed jobs older than 24 hours..."
              kubectl delete jobs --field-selector=status.successful=1 \
                --all-namespaces \
                -l cleanup=enabled

              echo "Cleaning up failed jobs..."
              kubectl delete jobs --field-selector=status.successful=0 \
                --all-namespaces \
                -l cleanup=enabled

              echo "Cleanup completed!"
          restartPolicy: OnFailure
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cleanup-sa
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: job-cleaner
rules:
- apiGroups: ["batch"]
  resources: ["jobs"]
  verbs: ["list", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cleanup-sa-binding
subjects:
- kind: ServiceAccount
  name: cleanup-sa
  namespace: default
roleRef:
  kind: ClusterRole
  name: job-cleaner
  apiGroup: rbac.authorization.k8s.io
```

---

## Part 6: Job TTL Controller

### 6.1 Automatic Cleanup with TTL

```yaml
# job-ttl.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: auto-cleanup-job
spec:
  ttlSecondsAfterFinished: 100  # Delete job 100s after completion
  template:
    spec:
      containers:
      - name: task
        image: busybox:1.36
        command: ["sh", "-c", "echo 'Task done!' && sleep 5"]
      restartPolicy: Never
```

```bash
kubectl apply -f job-ttl.yaml

# Watch job complete and get cleaned up
kubectl get jobs auto-cleanup-job -w
```

---

## Part 7: Hands-on Challenges

### Challenge 1: Parallel Image Processor

Create a Job that:
- Processes 20 images (simulated)
- Runs 5 workers in parallel
- Handles failures gracefully

```yaml
# image-processor.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: image-processor
spec:
  completions: 20
  parallelism: 5
  backoffLimit: 10
  template:
    spec:
      containers:
      - name: processor
        image: busybox:1.36
        command: ["sh", "-c"]
        args:
        - |
          IMAGE_ID=$((RANDOM % 1000))
          echo "Processing image $IMAGE_ID"

          # Simulate occasional failure
          if [ $((RANDOM % 10)) -eq 0 ]; then
            echo "Processing failed!"
            exit 1
          fi

          sleep $((RANDOM % 5 + 2))
          echo "Image $IMAGE_ID processed successfully"
      restartPolicy: Never
```

### Challenge 2: Scheduled Report Generator

Create a CronJob that:
- Runs hourly during business hours (9 AM - 5 PM)
- Only on weekdays
- Doesn't overlap with previous runs
- Keeps last 5 successful runs

### Challenge 3: Multi-Stage Pipeline

Create a Job with init containers representing:
1. Data validation stage
2. Data transformation stage
3. Final processing in main container

---

## Verification Tasks

1. [ ] Created and monitored simple Job
2. [ ] Configured parallel Job with multiple completions
3. [ ] Implemented Job with backoff and retry
4. [ ] Created CronJob with proper schedule
5. [ ] Tested concurrency policies
6. [ ] Implemented TTL-based cleanup

---

## Key Takeaways

- Jobs run pods to completion
- Use completions and parallelism to control work distribution
- backoffLimit controls retry behavior
- CronJobs schedule recurring Jobs
- Concurrency policies prevent overlap
- TTL controller automates cleanup

---

## Module Complete!

You've completed the Core Workloads module. Continue to:
- [Phase 2: Core Operations](../../phase-2-core-operations/README.md)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Job Fundamentals
- Job Configurations
- Failure Handling
- CronJobs

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
