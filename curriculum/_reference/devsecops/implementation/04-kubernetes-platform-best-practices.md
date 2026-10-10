# Domain 4: Kubernetes Platform -- Best Practices

> Strengths, limitations, and recommendations for the reference K8s platform.

---

## Strengths

### 1. GitOps-First Architecture

- **Full declarative state**: Every cluster component -- from CRDs to application services -- is defined in Git and managed by ArgoCD.
- **Sync-wave ordering**: Dependency-aware deployment (Wave -3 through Wave 4) prevents race conditions where applications deploy before their infrastructure dependencies (databases, secrets stores, service mesh) are ready.
- **Self-healing**: `automated.prune: true` and `selfHeal: true` on all Applications ensures the cluster continuously reconciles toward the desired state.
- **Drift detection**: ArgoCD continuously compares live state against Git, surfacing configuration drift before it causes incidents.

### 2. Defense-in-Depth Security

- **Pod Security Standards**: Namespace-level enforcement (`restricted` for app namespaces) blocks privileged containers, host networking, and root execution.
- **Non-root, read-only rootfs**: Every application container runs as UID 1000, drops ALL capabilities, and uses a read-only root filesystem.
- **Istio ambient mTLS**: STRICT mesh-wide PeerAuthentication ensures all service-to-service communication is encrypted without requiring sidecar injection overhead.
- **Authorization Policies**: Fine-grained principal-based access control (e.g., only API Gateway can call auth-service).
- **Secret rotation**: ExternalSecrets with 5m-1h refresh intervals combined with Stakater Reloader provides dynamic secret rotation without manual intervention.

### 3. Cost-Optimized Infrastructure

- **[KUBEADM-SPECIFIC]** Self-managed cluster avoids GKE management fees (~$72/month per cluster).
- **Spot VM workers**: Application workloads run on preemptible VMs for 60-90% cost savings.
- **Control plane scheduling**: Stateful services (PostgreSQL, Redis, ArgoCD) tolerate the control plane taint, surviving worker preemption events.
- **Right-sized resources**: Every component has explicit CPU/memory requests and limits tuned to actual usage.

### 4. Kustomize-Based Configuration Management

- **Base + overlay pattern**: Common service definitions in `apps/{go,nodejs}-services/base/` with per-environment overlays.
- **Image tag management**: Kustomize `images` transformer allows ArgoCD Image Updater to modify tags without patching deployment manifests.
- **Consistent labeling**: `app.kubernetes.io/*` labels applied via Kustomize `labels` transformer ensure uniform metadata across all resources.

### 5. Comprehensive Observability

- **Prometheus scrape annotations**: Every deployment template includes `prometheus.io/scrape`, `prometheus.io/port`, and `prometheus.io/path`.
- **ServiceMonitors**: Platform tools (cert-manager, ESO, Velero, Redis, PostgreSQL) expose Prometheus metrics.
- **Hubble**: Cilium's Hubble provides network flow visibility at the eBPF level.
- **Structured logging**: Fluent Bit collects logs to Elasticsearch/OpenSearch with index lifecycle management.

### 6. Resilient Data Layer

- **PgBouncer connection pooling**: Transaction-mode pooling (200 max client connections, 20 pool size) prevents connection exhaustion.
- **Litestream WAL streaming**: 10-second sync interval provides near-continuous backup with point-in-time recovery.
- **Redis AOF + RDB**: Dual persistence strategy (AOF for durability, RDB for fast recovery).
- **Velero scheduled backups**: Daily full + hourly app-only backups with 30-day and 7-day retention.

---

## Limitations

### 1. Single-Replica Stateful Services

- PostgreSQL and Redis are deployed as single-replica StatefulSets. There is no built-in HA failover.
- **Impact**: A control plane node failure takes down the database and cache until the node recovers.
- **Mitigation present**: Litestream WAL backup enables recovery, but there is a recovery time gap.

### 2. Self-Managed Cluster Operational Burden

- **[KUBEADM-SPECIFIC]** Kubernetes version upgrades, etcd backups, certificate rotation, and node OS patching are manual responsibilities.
- **Impact**: Requires dedicated platform engineering time that managed services (GKE, EKS) handle automatically.
- **Mitigation present**: Packer images pre-bake kubeadm configuration, and GitHub Actions workflows automate bootstrap.

### 3. NodePort-Based Ingress

- Istio ingress gateway uses NodePort (30080/30443) instead of a cloud load balancer.
- **Impact**: Requires external load balancing (e.g., GCP HTTP(S) LB, HAProxy, or EdgeNet tunnel) to be configured separately.
- **Mitigation present**: The architecture supports adding a cloud LB in front of NodePort.

### 4. No Multi-Cluster / Multi-Region

- The architecture is a single-cluster, single-region deployment.
- **Impact**: A regional outage takes down the entire platform.
- **Mitigation present**: Velero backups to GCS enable recovery in a different region, but this is not automated failover.

### 5. Spot VM Worker Risk

- Worker nodes on Spot VMs can be preempted with 30 seconds notice.
- **Impact**: In-flight requests may be dropped during preemption. PodDisruptionBudgets (minAvailable: 1) help but cannot prevent all disruption.
- **Mitigation present**: Application pods have `terminationGracePeriodSeconds: 30` and rolling update with `maxUnavailable: 0`.

### 6. Secret Rotation Scope

- External Secrets rotation depends on the secret being rotated in GCP Secret Manager first. The platform only handles pulling the new value.
- **Impact**: If the upstream secret is not rotated, ESO will keep pulling the same value.
- **Mitigation present**: Rotation labels (`platform.io/secret-rotation: enabled`) mark secrets that should be rotated, but automatic upstream rotation must be implemented separately.

### 7. Database Password in ConfigMap (Staging)

- Staging overlay ConfigMaps contain plaintext database passwords (`staging-password`).
- **Impact**: Secrets leak into Git history.
- **Mitigation**: Production uses ExternalSecrets. Staging should be migrated to the same pattern.

---

## Recommendations

### Short-Term (0-3 months)

1. **Migrate staging secrets to ExternalSecrets**: Remove plaintext passwords from staging overlay ConfigMaps. Use the same ESO pattern as production.

2. **Add startup probes**: Go services with fast startup need only liveness/readiness, but Node.js services should add `startupProbe` to avoid premature liveness failures during cold starts.

3. **Implement NetworkPolicies per service**: The current architecture defines network policies at the service-group level (`go-services/network-policies.yaml`). Add per-service Cilium NetworkPolicies to enforce least-privilege network access.

4. **Add resource quota per namespace**: Define `ResourceQuota` objects to prevent runaway resource consumption in shared clusters.

5. **Enable Velero pre-deployment backups in CI**: The `pre-deployment-template` Backup exists but is not automatically triggered. Wire it into the `k8s-deploy.yml` workflow before every production deployment.

### Medium-Term (3-6 months)

6. **PostgreSQL HA with Patroni or CloudNativePG**: Replace the single-replica StatefulSet with a Patroni-based HA cluster or CloudNativePG operator for automatic failover.

7. **Redis Sentinel or Cluster mode**: Deploy Redis Sentinel for automatic failover, or migrate to Redis Cluster for horizontal scaling.

8. **Add canary deployments**: Integrate Argo Rollouts for canary or blue-green deployment strategies. The current `RollingUpdate` with `maxUnavailable: 0` is safe but does not support traffic-based canary analysis.

9. **Implement Istio VirtualService rate limiting**: Add rate limiting at the Istio gateway level to protect against traffic spikes.

10. **Centralize logging with correlation IDs**: Ensure all services emit structured logs with a shared correlation/trace ID, and configure Fluent Bit to parse and forward these to the SIEM stack.

### Long-Term (6-12 months)

11. **Multi-cluster with ArgoCD ApplicationSets**: Extend the ApplicationSet generators to target multiple clusters for HA and geographic distribution.

12. **Migrate to Gateway API fully**: Replace any remaining Istio VirtualService/Gateway objects with Kubernetes Gateway API resources for portability.

13. **Implement OPA/Gatekeeper supply chain policies**: Enforce SLSA provenance and SBOM attestation requirements via admission control.

14. **Automated kubeadm upgrades**: Build a workflow that performs rolling kubeadm upgrades (control plane first, then workers) with automatic rollback on health check failure.

15. **Consider managed Kubernetes**: Evaluate whether the cost savings of self-managed kubeadm justify the operational overhead compared to GKE Autopilot or Standard mode, especially as the team scales.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- GitOps-First Architecture
- Defense-in-Depth Security
- Cost-Optimized Infrastructure
- Kustomize-Based Configuration Management

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
