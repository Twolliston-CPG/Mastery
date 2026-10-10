# Domain 4: Kubernetes Platform -- Implementation Checklist

> Step-by-step implementation with testable verification commands.

---

## Prerequisites

- [ ] GCE VMs provisioned (control plane + worker) via Terraform [GCP-SPECIFIC]
- [ ] SSH access to control plane node configured
- [ ] `kubectl`, `kustomize`, `helm` CLI tools installed locally
- [ ] GitHub repository for infrastructure manifests created
- [ ] Container registry (Artifact Registry) created [GCP-SPECIFIC]
- [ ] GCP Secret Manager secrets populated [GCP-SPECIFIC]

---

## Phase 1: Cluster Bootstrap [KUBEADM-SPECIFIC]

### 1.1 Initialize kubeadm Cluster

- [ ] SSH into the control plane VM and run `kubeadm init`
- [ ] Configure kubeconfig for local access

**Verify:**
```bash
kubectl cluster-info
kubectl get nodes
# Expected: control plane node in Ready status
```

### 1.2 Install Cilium v1.15 CNI

- [ ] Install Cilium CLI on control plane
- [ ] Deploy Cilium with eBPF kube-proxy replacement and Hubble enabled

**Verify:**
```bash
cilium status --brief
# Expected: OK for all components (Operator, Relay, Hubble)

kubectl get pods -n kube-system -l k8s-app=cilium
# Expected: cilium pods Running on each node

cilium connectivity test
# Expected: All tests pass
```

### 1.3 Join Worker Nodes

- [ ] Run `kubeadm join` on worker VMs with the token from init
- [ ] Label worker nodes: `kubectl label node <worker> node-type=app`

**Verify:**
```bash
kubectl get nodes -o wide
# Expected: All nodes Ready, worker labeled node-type=app

kubectl get nodes --show-labels | grep node-type
# Expected: worker node shows node-type=app
```

### 1.4 Apply CoreDNS Control Plane Affinity

- [ ] Apply CoreDNS patch to schedule on control plane

**Verify:**
```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide
# Expected: CoreDNS pods running on control plane node
```

---

## Phase 2: ArgoCD Bootstrap

### 2.1 Create ArgoCD Namespace

- [ ] Apply namespace manifest: `kubectl apply -f k8s-manifests/bootstrap/argocd-namespace.yaml`

**Verify:**
```bash
kubectl get namespace argocd
# Expected: argocd namespace Active
```

### 2.2 Install ArgoCD

- [ ] Install ArgoCD v2.10 with control plane affinity patches

```bash
kubectl apply -k k8s-manifests/platform/argocd-install/staging
```

**Verify:**
```bash
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
kubectl wait --for=condition=available --timeout=300s deployment/argocd-repo-server -n argocd

kubectl get pods -n argocd
# Expected: All ArgoCD pods Running (server, repo-server, app-controller, redis, dex)
```

### 2.3 Apply ArgoCD Configuration

- [ ] Apply RBAC and CM patches: `kubectl apply -f k8s-manifests/bootstrap/argocd-config.yaml`

**Verify:**
```bash
kubectl get configmap argocd-cm -n argocd -o yaml | grep statusbadge
# Expected: statusbadge.enabled: "true"

kubectl get configmap argocd-rbac-cm -n argocd -o yaml | grep "policy.default"
# Expected: policy.default: role:readonly
```

### 2.4 Retrieve ArgoCD Admin Password

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### 2.5 Create AppProjects

- [ ] Apply root application manifest: `kubectl apply -f k8s-manifests/bootstrap/root-application.yaml`

**Verify:**
```bash
kubectl get appproject -n argocd
# Expected: bootstrap, platform, applications projects exist
```

---

## Phase 3: Platform Bootstrap (App-of-Apps)

### 3.1 Deploy Platform Bootstrap Application

- [ ] Apply environment-specific platform bootstrap

```bash
kubectl apply -f k8s-manifests/gitops-apps/environments/staging/platform-bootstrap.yaml
```

**Verify:**
```bash
kubectl get application platform-staging -n argocd
# Expected: Application exists with Sync status

kubectl get applications -n argocd
# Expected: Child applications appearing as sync waves progress
```

### 3.2 Verify Wave -3: Namespaces

**Verify:**
```bash
kubectl get namespaces | grep -E "{{APP_NAMESPACE}}|cert-manager|external-secrets|istio-system|velero|monitoring"
# Expected: All platform namespaces exist
```

### 3.3 Verify Wave -2: CRD Providers

**Verify cert-manager:**
```bash
kubectl get pods -n cert-manager
# Expected: cert-manager, cert-manager-webhook, cert-manager-cainjector Running

kubectl get clusterissuers
# Expected: letsencrypt-staging, letsencrypt-prod, selfsigned, {{APP_NAME}}-ca
```

**Verify external-secrets:**
```bash
kubectl get pods -n external-secrets
# Expected: external-secrets controller, webhook, cert-controller Running

kubectl get clustersecretstore
# Expected: gcp-secret-manager store listed
```

### 3.4 Verify Wave -1: Core Infrastructure

**Verify Istio:**
```bash
kubectl get pods -n istio-system
# Expected: istiod, ztunnel, istio-cni, istio-ingress pods Running

kubectl get peerauthentication -A
# Expected: default PeerAuthentication with mode: STRICT in istio-system

kubectl get gateway -n istio-system
# Expected: {{APP_NAME}}-gateway with HTTP/HTTPS listeners
```

**Verify PostgreSQL:**
```bash
kubectl get statefulset postgres -n {{APP_NAMESPACE}}-system
# Expected: 1/1 Ready

kubectl exec -n {{APP_NAMESPACE}}-system postgres-0 -- pg_isready
# Expected: accepting connections

kubectl get pdb postgres -n {{APP_NAMESPACE}}-system
# Expected: minAvailable: 1
```

**Verify PgBouncer:**
```bash
kubectl get deployment pgbouncer -n {{APP_NAMESPACE}}-system
# Expected: 1/1 Ready

kubectl get svc pgbouncer -n {{APP_NAMESPACE}}-system
# Expected: ClusterIP service on port 6432
```

**Verify Redis:**
```bash
kubectl get statefulset redis -n {{APP_NAMESPACE}}-system
# Expected: 1/1 Ready

kubectl exec -n {{APP_NAMESPACE}}-system redis-0 -- redis-cli ping
# Expected: PONG

kubectl get pdb redis -n {{APP_NAMESPACE}}-system
# Expected: minAvailable: 1
```

### 3.5 Verify Wave 0: Observability

**Verify:**
```bash
kubectl get pods -n monitoring
# Expected: prometheus, grafana, alertmanager pods Running

kubectl get servicemonitor -A | wc -l
# Expected: Multiple ServiceMonitors registered
```

### 3.6 Verify Wave 1: Security

**Verify:**
```bash
kubectl get pods -n security
# Expected: Gatekeeper, Falco pods Running

kubectl get constrainttemplates
# Expected: Constraint templates registered

kubectl get clusterpolicies
# Expected: Kyverno policies (if deployed)
```

### 3.7 Verify Wave 2: ArgoCD Image Updater

**Verify:**
```bash
kubectl get deployment argocd-image-updater -n argocd
# Expected: 1/1 Ready

kubectl logs -n argocd deployment/argocd-image-updater --tail=20
# Expected: Log lines showing registry checks, no errors
```

### 3.8 Verify Wave 3: Application Services

**Verify:**
```bash
kubectl get deployments -n {{APP_NAMESPACE}}
# Expected: All microservice deployments listed

kubectl get pods -n {{APP_NAMESPACE}}
# Expected: All pods Running with 1/1 Ready

kubectl get hpa -n {{APP_NAMESPACE}}
# Expected: HPA for each service showing current/target metrics

kubectl get pdb -n {{APP_NAMESPACE}}
# Expected: PDB for each service with minAvailable: 1
```

---

## Phase 4: Secrets Verification

### 4.1 Verify External Secrets Sync

**Verify:**
```bash
kubectl get externalsecrets -A
# Expected: All ExternalSecrets with status SecrCraftMarketnced

kubectl get externalsecret -n {{APP_NAMESPACE}}-system postgres-credentials -o jsonpath='{.status.conditions[0].type}'
# Expected: Ready

kubectl get externalsecret -n {{APP_NAMESPACE}}-system redis-credentials -o jsonpath='{.status.conditions[0].type}'
# Expected: Ready
```

### 4.2 Verify Stakater Reloader

**Verify:**
```bash
kubectl get deployment reloader -n external-secrets
# Expected: 1/1 Ready

kubectl get secret -n {{APP_NAMESPACE}} -l "reloader.stakater.com/match=true"
# Expected: Secrets with Reloader annotation listed
```

---

## Phase 5: Networking Verification

### 5.1 Verify Istio mTLS

**Verify:**
```bash
# Check mTLS status between services
kubectl exec -n {{APP_NAMESPACE}} deploy/api-gateway -- curl -sS http://auth-service:3001/health
# Expected: 200 OK (mTLS handled transparently by ztunnel)

# Check PeerAuthentication is enforced
kubectl get peerauthentication -n istio-system default -o jsonpath='{.spec.mtls.mode}'
# Expected: STRICT
```

### 5.2 Verify Ingress

**Verify:**
```bash
kubectl get svc istio-ingressgateway -n istio-system
# Expected: NodePort service with ports 30080/30443

curl -k https://<node-ip>:30443/health
# Expected: Response from API Gateway
```

### 5.3 Verify Service Communication

**Verify:**
```bash
# From within the cluster, verify service DNS resolution
kubectl exec -n {{APP_NAMESPACE}} deploy/api-gateway -- nslookup auth-service.{{APP_NAMESPACE}}.svc.cluster.local
# Expected: DNS resolves to ClusterIP

# Verify all service endpoints
kubectl get endpoints -n {{APP_NAMESPACE}}
# Expected: Each service has at least one endpoint
```

---

## Phase 6: Backup Verification

### 6.1 Verify Velero Installation

**Verify:**
```bash
kubectl get pods -n velero
# Expected: velero and node-agent pods Running

velero backup-location get
# Expected: gcs backup location listed and Available

velero schedule get
# Expected: daily-full-backup and hourly-app-backup schedules listed
```

### 6.2 Test Backup and Restore

```bash
# Create a test backup
velero backup create test-backup --include-namespaces {{APP_NAMESPACE}} --wait

# Verify backup completed
velero backup describe test-backup
# Expected: Phase: Completed

# Clean up test backup
velero backup delete test-backup --confirm
```

### 6.3 Verify Litestream

**Verify:**
```bash
kubectl logs -n {{APP_NAMESPACE}}-system statefulset/postgres -c litestream --tail=10
# Expected: Log lines showing WAL sync to GCS [GCP-SPECIFIC]
```

---

## Phase 7: Health Check Automation

### 7.1 Verify Prometheus Scraping

**Verify:**
```bash
# Check that application metrics are being scraped
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090 &
curl -sS 'http://localhost:9090/api/v1/targets' | jq '.data.activeTargets | length'
# Expected: Number matching total scraped endpoints

# Check for service-specific metrics
curl -sS 'http://localhost:9090/api/v1/query?query=up{namespace="{{APP_NAMESPACE}}"}' | jq '.data.result | length'
# Expected: Number matching active service pods
```

### 7.2 Verify HPA Metrics

**Verify:**
```bash
kubectl top pods -n {{APP_NAMESPACE}}
# Expected: CPU and memory usage displayed for all pods

kubectl get hpa -n {{APP_NAMESPACE}}
# Expected: Current utilization percentages displayed (not <unknown>)
```

### 7.3 Verify Probes

**Verify:**
```bash
# Check that liveness and readiness probes are configured
kubectl get deployment -n {{APP_NAMESPACE}} -o json | jq '.items[].spec.template.spec.containers[].livenessProbe.httpGet.path' | sort -u
# Expected: /health/live, /health, or similar paths

kubectl get deployment -n {{APP_NAMESPACE}} -o json | jq '.items[].spec.template.spec.containers[].readinessProbe.httpGet.path' | sort -u
# Expected: /health/ready, /health, or similar paths
```

---

## Phase 8: GitOps Workflow Verification

### 8.1 Test ArgoCD Auto-Sync

- [ ] Make a change to a manifest in Git
- [ ] Verify ArgoCD detects and syncs the change

**Verify:**
```bash
kubectl get application -n argocd <app-name> -o jsonpath='{.status.sync.status}'
# Expected: Synced

kubectl get application -n argocd <app-name> -o jsonpath='{.status.health.status}'
# Expected: Healthy
```

### 8.2 Test Image Updater

- [ ] Push a new semver-tagged image to the registry
- [ ] Verify Image Updater commits the tag change to Git
- [ ] Verify ArgoCD syncs the new image

**Verify:**
```bash
kubectl logs -n argocd deployment/argocd-image-updater --tail=50 | grep "new tag"
# Expected: Log line showing new tag detection

git log --oneline -5 origin/main
# Expected: Commit from argocd-image-updater with "build: update image" message
```

### 8.3 Test Self-Heal

```bash
# Manually scale a deployment (simulating drift)
kubectl scale deployment api-gateway -n {{APP_NAMESPACE}} --replicas=5

# Wait for ArgoCD to detect and revert
sleep 60

kubectl get deployment api-gateway -n {{APP_NAMESPACE}} -o jsonpath='{.spec.replicas}'
# Expected: Original replica count (2) restored by ArgoCD self-heal
```

---

## Completion Criteria

- [ ] All nodes Ready with Cilium operational
- [ ] ArgoCD managing all platform components via App-of-Apps
- [ ] All sync waves (Wave -3 through Wave 4) completed successfully
- [ ] PostgreSQL and Redis accepting connections with ExternalSecrets-provided credentials
- [ ] Istio ambient mTLS enforced mesh-wide
- [ ] cert-manager issuing certificates (ClusterIssuers registered)
- [ ] ArgoCD Image Updater polling registry and writing back to Git
- [ ] Velero backup schedules active with accessible backup location
- [ ] Prometheus scraping all service endpoints
- [ ] HPA reporting metrics (not `<unknown>`)
- [ ] All application pods Running with passing health probes

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Cluster Bootstrap [KUBEADM-SPECIFIC]
- ArgoCD Bootstrap
- Platform Bootstrap (App-of-Apps)
- Secrets Verification

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
