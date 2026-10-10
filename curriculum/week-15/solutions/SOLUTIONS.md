# Week 15 Solutions

---

## Lab 1 — Resources and probes

### Reading an OOMKill

```bash
kubectl get pod oom -o jsonpath='{.status.containerStatuses[0].lastState.terminated}' | jq
{
  "containerID": "containerd://...",
  "exitCode": 137,
  "reason": "OOMKilled",
  "startedAt": "...",
  "finishedAt": "..."
}
```

**137 = 128 + 9 (SIGKILL).** The kernel's OOM killer, acting on the container's memory cgroup — not
the node running out of memory. The container hit **its own limit**.

**The distinction that matters:** a container OOMKill at its limit is a *configuration* problem
(raise the limit or fix the leak). A **node** under memory pressure evicting pods is a *capacity*
problem and shows up as `Evicted` status with a `MemoryPressure` node condition instead. Different
symptoms, different fixes.

### requests vs limits — the full picture

| | Purpose | Enforced by |
|---|---|---|
| **request** | What the **scheduler** reserves; decides *where* the pod lands | kube-scheduler, at admission |
| **limit** | The hard ceiling at runtime | the kernel cgroup |

**CPU:** compressible. Exceeding the limit **throttles** — the process gets slower but stays alive.
Visible as `container_cpu_cfs_throttled_periods_total` in Prometheus (week 20).

**Memory:** not compressible. Exceeding the limit is an immediate **SIGKILL**.

**The scheduling gap.** Scheduling uses *requests*, not actual usage. A cluster at 10% real CPU
utilization can be 100% unschedulable if requests are overset. Diagnose with:
```bash
kubectl describe node <node> | grep -A8 'Allocated resources'
# compare "Requests" against "Capacity" -- and both against `kubectl top node`
```
Explaining that gap out loud is a genuinely senior-sounding observation.

### The three probes, and the disaster

```yaml
startupProbe:                    # suppresses the other two until it passes
  failureThreshold: 30
  periodSeconds: 5               # allows 150s to boot
livenessProbe:                   # "is the PROCESS wedged?" -> RESTARTS
  periodSeconds: 10
  failureThreshold: 3
readinessProbe:                  # "should I get traffic?" -> REMOVES FROM ENDPOINTS
  periodSeconds: 5
  failureThreshold: 2
```

**The production disaster, stated precisely:**

> Put a database connectivity check in the **liveness** probe. The database has a five-second blip.
> Every replica fails liveness at the same moment. Kubernetes restarts the entire fleet
> simultaneously. The restarts hammer the recovering database with a reconnection storm, which
> extends the blip. You have converted a five-second hiccup into a multi-minute outage, and the
> monitoring shows "all pods restarting" with no obvious cause.

**The rule:** liveness checks only the process itself, and honestly, if you can't name a deadlock it
would catch, you may not need one at all. Dependency checks belong in **readiness**, where failing
takes the pod out of rotation without restarting it — so it recovers the moment the dependency does.

`startupProbe` exists so you don't have to set a huge `initialDelaySeconds` on liveness, which would
weaken failure detection forever after the boot.

---

## Lab 2 — Scheduling

### HPA behavior

```yaml
behavior:
  scaleUp:
    stabilizationWindowSeconds: 0
    policies: [{ type: Percent, value: 100, periodSeconds: 30 }]  # can double every 30s
  scaleDown:
    stabilizationWindowSeconds: 300                                # 5 min of calm first
    policies: [{ type: Percent, value: 50, periodSeconds: 60 }]
```
**Aggressive out, conservative in.** Scaling out too slowly costs an outage; scaling in too quickly
causes flapping. Identical to the week-7 ASG reasoning — worth noticing that the pattern recurs.

**HPA requires metrics-server** (installed by `_setup/02-kind-cluster.sh`). Without it the HPA shows
`<unknown>/50%` and never scales — a common "it doesn't work" that is really a missing component.

**HPA and requests:** the HPA computes utilization as a **percentage of the request**, not of the
limit. A pod with a 100m request running at 80m is at 80%. Getting requests wrong makes the HPA
behave strangely, which is another reason requests matter.

### The PDB trap

```yaml
spec:
  minAvailable: 1        # on a 1-replica Deployment
```
`kubectl drain` can never satisfy this — evicting the single pod would leave zero available. **The
drain blocks forever**, node upgrades hang, and cluster autoscaler can't remove the node.

For single-replica workloads either use `maxUnavailable: 1` (explicitly allowing the disruption) or
accept that they need 2 replicas to be drain-safe. This is the kind of thing that surfaces at 2am
during a cluster upgrade.

### Anti-affinity vs topology spread

```yaml
# RIGID -- 3 replicas on 2 nodes leaves one Pending FOREVER
podAntiAffinity:
  requiredDuringSchedulingIgnoredDuringExecution: [...]

# FLEXIBLE -- spreads when it can, schedules anyway when it can't
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: kubernetes.io/hostname
    whenUnsatisfiable: ScheduleAnyway
```
`topologySpreadConstraints` is the modern answer and almost always the right one. `required`
anti-affinity turns a capacity shortage into a permanently Pending pod.

---

## Lab 3 — Storage

### Why a PVC stays Pending

```bash
kubectl describe pvc data-db-0
```
| Event | Cause |
|---|---|
| `no persistent volumes available... and no storage class is set` | No default StorageClass and none named |
| `storageclass.storage.k8s.io "x" not found` | Typo |
| `waiting for first consumer to be created before binding` | **Correct behavior** — `WaitForFirstConsumer` |
| `Failed to provision volume... AccessMode not supported` | RWX on block storage |

**`WaitForFirstConsumer` is the one that looks like a bug and isn't.** It delays binding until a pod
is scheduled, so the volume is created in the **same AZ as the pod**. With `Immediate`, the volume
can be created in AZ-a and the pod scheduled to AZ-b, producing
`volume node affinity conflict` — a permanently unschedulable pod.

### Access modes, concretely

| Mode | Meaning | Backed by |
|---|---|---|
| `ReadWriteOnce` (RWO) | One **node** at a time | EBS, GCE PD — block storage |
| `ReadOnlyMany` (ROX) | Many nodes, read only | |
| `ReadWriteMany` (RWX) | Many nodes, read-write | EFS, NFS, CephFS — file storage |
| `ReadWriteOncePod` | Exactly one **pod** | Newer; stronger than RWO |

Scaling a Deployment with an RWO PVC to 2 replicas across nodes leaves the second pod stuck with
`Multi-Attach error for volume`. **Block storage physically attaches to one machine.** If you need
shared storage, you need a filesystem, not a disk.

### Why StatefulSet PVCs are retained

Deleting a StatefulSet does **not** delete its PVCs — deliberately, so you can recreate the
StatefulSet and reattach the data. Cleanup is manual:
```bash
kubectl delete pvc -l app=db
```
Newer Kubernetes adds `persistentVolumeClaimRetentionPolicy` to make this configurable. Defaulting to
"retain" is the right call: accidentally deleting a StatefulSet should not be accidentally deleting
the data.

---

## Lab 4 — RBAC

### Reading the error

```
Error from server (Forbidden): pods is forbidden:
  User "system:serviceaccount:shop:deployer"   <- WHO
  cannot list                                   <- VERB
  resource "pods" in API group ""               <- RESOURCE + apiGroup
  in the namespace "prod"                       <- NAMESPACE
```
All four variables are in the message. Check each against the Role.

### The five causes

1. **`Role` + `RoleBinding` grants only in that namespace** and the request was for another
2. A `ClusterRole` bound with a `RoleBinding` — legal, and scoped to one namespace, which surprises
   people
3. **Wrong `apiGroup`** — core resources use `""`; deployments use `"apps"`; ingresses use
   `"networking.k8s.io"`
4. **Missing sub-resource** — `pods/log`, `pods/exec`, `pods/portforward` are separate from `pods`
5. The pod isn't using the ServiceAccount you think — check `spec.serviceAccountName` (unset means
   `default`)

### The audit query worth keeping

```bash
kubectl get clusterrolebindings -o json | jq -r '
  .items[] | select(.roleRef.name=="cluster-admin") |
  "\(.metadata.name)\t\(.subjects // [] | map(.kind+"/"+.name) | join(","))"'
```
In an inherited cluster this is usually the **first** thing to run. Over-broad `cluster-admin`
bindings are the most common real RBAC finding, far more than any subtle misconfiguration.

Also worth knowing:
```bash
kubectl auth can-i --list --as=system:serviceaccount:ns:sa -n ns
```
This enumerates everything a principal can do — much faster than reading policies.

---

## Lab 6 — Helm

### Helm vs Kustomize, for the interview

| | Helm | Kustomize |
|---|---|---|
| Mechanism | Go templating + a package manager | Strategic-merge patching |
| Versioning / rollback | **Yes** (`helm rollback`) | No (git is your history) |
| Dependencies | **Yes** (subcharts) | No |
| Registry | **Yes** | No |
| Templating language | Yes — powerful, and unreadable at scale | **None** — output is always valid YAML |
| Built into kubectl | No | **Yes** (`kubectl apply -k`) |

**The answer:** Helm for third-party software you *consume* (ingress-nginx, Prometheus, ArgoCD) —
you want versioning and a registry. Kustomize for your **own** manifests, where the base is yours and
overlays are small. ArgoCD supports both natively, so it isn't an exclusive choice.

**The honest criticism of Helm** is worth being able to voice: a heavily-templated chart becomes
unreadable, and `helm template | less` to see what will actually apply is a sign the abstraction has
gone too far. Kustomize's constraint — no templating language — is a feature.

### `helm template` before `helm install`, always

```bash
helm template shop ./shop -f values-prod.yaml | less
helm diff upgrade shop ./shop -f values-prod.yaml   # requires the helm-diff plugin
```
This is the Helm equivalent of `terraform plan`, and skipping it is the equivalent of applying
without reading the plan. `helm-diff` is worth installing on day one.
