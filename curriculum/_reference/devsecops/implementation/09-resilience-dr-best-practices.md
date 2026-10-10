# Resilience & Disaster Recovery -- Best Practices & Gaps

## Strengths

### 1. Three-Tier Backup Strategy with Complementary Tools
The combination of Velero (Kubernetes resources + PV snapshots), Litestream (PostgreSQL WAL streaming), and etcd snapshots covers all data tiers. No single tool failure results in total data loss. Velero handles cluster state, Litestream provides near-zero RPO for database data, and etcd snapshots protect the cluster control plane.

### 2. Continuous PostgreSQL Replication via Litestream
Litestream streams WAL segments to GCS every 10 seconds with hourly snapshots, achieving approximately 10-second RPO for PostgreSQL data without requiring a managed database service. This is significantly better than daily database dumps and eliminates the "last 24 hours of data loss" problem common in backup-only strategies.

### 3. Automated Chaos Engineering with Steady-State Validation
LitmusChaos experiments run on weekly and monthly schedules with HTTP probes that validate application health during fault injection. This proactively identifies resilience gaps rather than discovering them during actual incidents. The probe-based validation ensures experiments measure real user impact, not just pod restart counts.

### 4. Orchestrated Recovery Workflows with Graduated Actions
The `cluster-recover.yml` workflow provides four graduated recovery actions (restart VMs, rejoin worker, reset cluster, restore from backup) rather than a single "nuclear option." Operators can select the least disruptive action appropriate for the failure scenario, reducing unnecessary recovery time.

### 5. Infrastructure-as-Code for Full Recreate Capability
The `infrastructure-destroy-recreate.yml` workflow can destroy and rebuild the entire staging environment through Terraform, proving the infrastructure is fully reproducible. This is the strongest possible validation that the environment can be recovered from scratch.

### 6. Scheduled Health Checks as Early Warning System
The `cluster-health-check.yml` runs every 6 hours, checking VM status, node readiness, system pods, CNI health, and resource usage. This provides early detection of degradation before it escalates to an outage requiring DR procedures.

### 7. Pre-Deployment Backups as Safety Net
Velero pre-deployment backup templates enable CI/CD pipelines to create a restore point before every deployment. If a deployment introduces a data-corrupting change, the pre-deployment backup provides a known-good restore point.

### 8. Explicit Confirmation for Destructive Actions
The destroy-recreate workflow requires typing "staging" as a confirmation string, preventing accidental infrastructure destruction from misclicks or automation errors.

## Known Limitations

### 1. No Automated DR Test Workflow
There is no end-to-end automated DR test that validates the full backup-restore-verify cycle. The individual pieces (Velero backup, etcd restore, Litestream replay) are tested in isolation but not as a coordinated sequence. An automated DR test running monthly would provide confidence that the restore procedures work together.

**Impact**: High -- DR procedures may drift from reality without regular automated validation.

**Recommendation**: Create a `reusable-dr-test.yml` workflow that runs monthly in staging: triggers a backup, destroys a namespace, restores it, and verifies application health.

### 2. Single-Region Backup Storage
All backups (Velero, Litestream, etcd) target GCS buckets in a single region. A regional GCS outage would make all backups inaccessible simultaneously. Cross-region replication for backup buckets is not configured.

**Impact**: Medium -- GCS has 99.99% availability, but a regional failure during an active DR scenario would be catastrophic.

**Recommendation**: Enable GCS dual-region or multi-region storage for backup buckets, or configure a secondary backup destination in a different region.

### 3. No Litestream Sidecar Deployed in Manifests
The PostgreSQL StatefulSet in the source manifests includes a Litestream ConfigMap but does not deploy Litestream as a sidecar container. The WAL streaming configuration exists but is not actively running unless manually added.

**Impact**: High -- PostgreSQL WAL backup is configured but not operational without the sidecar container being added to the StatefulSet.

**Recommendation**: Add a Litestream sidecar container to the PostgreSQL StatefulSet with the GCS replica configuration.

### 4. No Chaos Experiments for Stateful Workloads
All chaos experiments target stateless application deployments (pod delete, network latency, CPU/memory stress). There are no experiments that test database failover, persistent volume loss, or storage class disruption.

**Impact**: Medium -- Stateful workload resilience is unvalidated. Database recovery procedures are untested under chaos conditions.

**Recommendation**: Add chaos experiments that target the PostgreSQL StatefulSet (e.g., pod-delete for postgres-0) and validate that Litestream replay restores data correctly.

### 5. Manual Trigger Required for Most Recovery Actions
The `cluster-recover.yml` workflow requires manual `workflow_dispatch` with operator input. There is no automated detection-to-recovery loop. If a cluster fails at 3 AM and no operator triggers the workflow, recovery is delayed until someone notices.

**Impact**: Medium -- RTO depends on operator availability and response time.

**Recommendation**: Integrate cluster health check failures with alerting (PagerDuty, Slack) and consider auto-triggering `restart-vms` for specific failure patterns.

### 6. etcd Backup Script Embedded in Init Script
The etcd backup script is embedded within the control-plane-init.sh Terraform template rather than managed as a separate, versioned artifact. Updating the backup script requires modifying and re-applying the Terraform module.

**Impact**: Low -- The script is simple and stable, but updates require infrastructure changes rather than a simple file deploy.

**Recommendation**: Extract the backup script to a ConfigMap or DaemonSet that can be updated independently via GitOps.

### 7. No Backup Verification or Integrity Checks
Backups are created on schedule but there is no automated verification that they are restorable. A corrupted Velero backup or truncated etcd snapshot would only be discovered during an actual restore attempt.

**Impact**: High -- Silent backup failures could result in discovering during a DR event that backups are unusable.

**Recommendation**: Add a nightly job that restores the latest backup to a temporary namespace and runs basic health checks before cleanup.

### 8. Chaos Experiments Lack Abort Conditions
The ChaosEngine specs do not define abort conditions or maximum blast radius limits. If a chaos experiment causes cascading failures beyond the intended scope, there is no automatic circuit breaker.

**Impact**: Medium -- A chaos experiment could escalate into an actual outage in a staging or production environment.

**Recommendation**: Add `jobCleanUpPolicy: delete` and configure experiment-level timeouts with Litmus `terminationGracePeriodSeconds` to limit blast radius.

## Recommendations Summary

| Priority | Recommendation | Effort |
|----------|---------------|--------|
| P0 | Deploy Litestream sidecar in PostgreSQL StatefulSet | Low |
| P0 | Add automated backup verification job | Medium |
| P1 | Create end-to-end DR test workflow | Medium |
| P1 | Enable cross-region backup replication | Low |
| P1 | Add chaos experiments for stateful workloads | Medium |
| P2 | Integrate health check failures with alerting | Low |
| P2 | Extract etcd backup script from init template | Low |
| P2 | Add abort conditions to chaos experiments | Low |

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Known Limitations
- Recommendations Summary
- Three-Tier Backup Strategy with Complementary Tools
- Continuous PostgreSQL Replication via Litestream

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
