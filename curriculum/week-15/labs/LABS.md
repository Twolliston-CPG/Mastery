# Week 15 Labs

> **Figures:** one numbered mechanism figure per lab, with the spoken script, the numbers to own and
> the command that proves each badge, in [`FIGURES.md`](FIGURES.md) (15.2 to 15.7). Read a lab's figure
> before you start it; redraw it after.

---

# Lab 1 — Probes, Resources, QoS (3h)

## Part 1 — Trigger OOMKilled (BF-43)

```bash
kubectl run oom --image=polinux/stress --restart=Never \
  --limits=memory=64Mi \
  -- stress --vm 1 --vm-bytes 200M --vm-hang 1

kubectl get pod oom -w
kubectl describe pod oom | grep -A5 'Last State'
kubectl get pod oom -o jsonpath='{.status.containerStatuses[0].lastState.terminated}' | jq
```

## Part 2 — QoS classes

```bash
# Guaranteed: requests == limits for EVERY container
kubectl run g --image=nginx --requests=cpu=100m,memory=128Mi --limits=cpu=100m,memory=128Mi
# Burstable: requests < limits
kubectl run b --image=nginx --requests=cpu=50m,memory=64Mi --limits=cpu=200m,memory=256Mi
# BestEffort: neither
kubectl run be --image=nginx

kubectl get pods -o custom-columns=NAME:.metadata.name,QOS:.status.qosClass
```

| Class | Condition | Evicted under node pressure |
|---|---|---|
| `Guaranteed` | requests == limits, all containers | **Last** |
| `Burstable` | requests < limits | Middle |
| `BestEffort` | neither set | **First** |

## Part 3 — CPU throttling vs memory kill

```bash
kubectl run cpu --image=polinux/stress --limits=cpu=100m -- stress --cpu 2
kubectl top pod cpu           # pinned at ~100m; SLOW but alive
# vs the memory case above: DEAD
```

**The sentence:** *"CPU is compressible so it's throttled; memory isn't so it's killed."* That
asymmetry explains most resource-related production behavior and is a clean interview answer.

## Part 4 — The probe disaster (BF-44)

```yaml
livenessProbe:
  httpGet: { path: /health, port: 8080 }
  initialDelaySeconds: 1       # app takes 20s to start
  periodSeconds: 5
  failureThreshold: 1
```
Deploy this against a slow-starting app. Watch it restart forever with **completely normal logs** —
because something external is killing it.

**Then build the correct set** (`startupProbe` + liveness + readiness) and confirm it stabilizes.

**Then the important exercise:** put a **database check in the liveness probe**, take the database
down, and watch **every replica restart simultaneously**. That is the production disaster, and having
caused it yourself makes it a story rather than a fact.

---

# Lab 2 — Scheduling, HPA, PDB (3h)

## HPA
```bash
kubectl autoscale deploy app --cpu-percent=50 --min=2 --max=10
kubectl get hpa -w
kubectl run load --rm -it --image=busybox -- \
  sh -c 'while true; do wget -qO- http://app.shop; done'
```

```yaml
behavior:
  scaleDown:
    stabilizationWindowSeconds: 300   # don't flap
    policies: [{ type: Percent, value: 50, periodSeconds: 60 }]
  scaleUp:
    stabilizationWindowSeconds: 0
    policies: [{ type: Percent, value: 100, periodSeconds: 30 }]
```
**Aggressive out, conservative in** — same principle as the week-7 ASG.

## PodDisruptionBudget
```bash
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data
```
With `minAvailable: 1` on a 2-replica Deployment, the drain evicts one pod and **waits** for the
replacement to be Ready before evicting the second. Without a PDB, both go at once and the service is
down during a routine node upgrade.

**`minAvailable` vs `maxUnavailable`:** prefer `minAvailable` for small deployments (it's absolute
and unambiguous at 2 replicas) and `maxUnavailable` as a percentage for large ones.

**The trap:** a PDB of `minAvailable: 1` on a **1-replica** Deployment blocks drains **forever** —
there's no way to satisfy it. Node upgrades hang and nobody knows why.

## Taints, tolerations, affinity
```bash
kubectl taint nodes mastery-worker dedicated=gpu:NoSchedule
kubectl run test --image=nginx        # Pending: untolerated taint
kubectl describe pod test | grep -A3 Events
kubectl taint nodes mastery-worker dedicated=gpu:NoSchedule-
```

```yaml
tolerations:
  - { key: dedicated, operator: Equal, value: gpu, effect: NoSchedule }
affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector: { matchLabels: { app: app } }
        topologyKey: kubernetes.io/hostname
```
`required` anti-affinity on a 3-replica Deployment with 2 nodes leaves one pod **Pending forever**.
`preferred` (or `topologySpreadConstraints` with `whenUnsatisfiable: ScheduleAnyway`) is usually
right.

**Taint effects:** `NoSchedule` (no new pods) · `PreferNoSchedule` (soft) · `NoExecute` (**evicts
running pods too**).

---

# Lab 3 — Storage (3h)

```bash
kubectl get storageclass
kubectl get pv,pvc -A
```

## Tasks
1. Create a PVC with no `storageClassName` — does it bind? What's the default SC?
2. Create one naming a nonexistent class → Pending. Read `describe pvc` (BF-46).
3. Set `volumeBindingMode: WaitForFirstConsumer` and observe the PVC stay Pending **correctly** until
   a pod is scheduled.
4. Try `ReadWriteMany` on a block-storage class → fails. Explain why.
5. Scale a Deployment with an RWO PVC to 2 replicas across nodes → the second pod is stuck. Explain.
6. Delete a StatefulSet and observe that the **PVCs are retained** on purpose.
7. `reclaimPolicy: Retain` vs `Delete` — set both and delete the PVC each time.

```yaml
volumeClaimTemplates:
  - metadata: { name: data }
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: standard
      resources: { requests: { storage: 2Gi } }
```

**Access modes:** `ReadWriteOnce` = one **node** at a time (block storage: EBS, GCE PD).
`ReadWriteMany` = many nodes (file storage: EFS, NFS). `ReadWriteOncePod` = exactly one **pod**.

---

# Lab 4 — RBAC (2h)

```bash
kubectl create sa deployer -n shop
kubectl create role pod-reader --verb=get,list,watch --resource=pods,pods/log -n shop --dry-run=client -o yaml
kubectl create rolebinding deployer-reader --role=pod-reader --serviceaccount=shop:deployer -n shop

kubectl auth can-i list pods --as=system:serviceaccount:shop:deployer -n shop     # yes
kubectl auth can-i list pods --as=system:serviceaccount:shop:deployer -n default  # no
kubectl auth can-i --list --as=system:serviceaccount:shop:deployer -n shop
```

## The four-way matrix — draw it from memory
| | RoleBinding | ClusterRoleBinding |
|---|---|---|
| **Role** | permissions in that namespace | *not allowed* |
| **ClusterRole** | permissions in **that one namespace** | permissions **cluster-wide** |

The bottom-left cell is what people get wrong and what interviewers ask about.

## Tasks
1. Build the SA/Role/RoleBinding and test allowed and denied paths
2. Break it four ways: wrong `apiGroup`, missing sub-resource (`pods/log`), wrong namespace, pod not
   using the SA. Read each error (BF-48).
3. Bind a **ClusterRole** with a **RoleBinding** and confirm it's namespace-scoped
4. Find every binding that grants `cluster-admin`:
   ```bash
   kubectl get clusterrolebindings -o json | \
     jq -r '.items[] | select(.roleRef.name=="cluster-admin") |
            "\(.metadata.name)\t\(.subjects // [] | map(.kind+"/"+.name) | join(","))"'
   ```
   **This is a real audit query** and usually the first thing to look at in a cluster you've inherited.
5. Set `automountServiceAccountToken: false` where the app doesn't call the API

---

# Lab 5 — Break/Fix Friday #6: build the Gate 4 set (3h)

**These five are Gate 4.** By week 17 you must diagnose any of them unaided, under 15 minutes,
narrating aloud. Build a script that injects one at random.

| # | Scenario | Break |
|---|---|---|
| BF-43 | OOMKilled | `--limits=memory=32Mi` on something that needs 200Mi |
| BF-44 | Liveness restart loop | `initialDelaySeconds: 1` on a 20s-boot app |
| BF-45 | Unschedulable | `kubectl taint nodes <n> k=v:NoSchedule` |
| BF-46 | PVC Pending | `storageClassName: nonexistent` |
| BF-48 | RBAC Forbidden | Remove a verb from the Role |

```bash
cat > break.sh <<'SH'
#!/usr/bin/env bash
# A partner runs this without telling you which. Diagnose under a timer.
set -euo pipefail
case $((RANDOM % 5)) in
  0) kubectl -n shop set resources deploy/app --limits=memory=32Mi ;;
  1) kubectl -n shop patch deploy app --type=json -p \
       '[{"op":"replace","path":"/spec/template/spec/containers/0/livenessProbe/periodSeconds","value":1},
         {"op":"remove","path":"/spec/template/spec/containers/0/startupProbe"}]' ;;
  2) kubectl taint nodes "$(kubectl get nodes -o name | tail -1 | cut -d/ -f2)" broken=yes:NoSchedule ;;
  3) kubectl -n shop apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata: { name: scratch }
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: nonexistent
  resources: { requests: { storage: 1Gi } }
---
apiVersion: v1
kind: Pod
metadata: { name: scratch-user }
spec:
  containers: [{ name: c, image: busybox:1.36, command: [sleep, '3600'],
                 volumeMounts: [{ name: s, mountPath: /scratch }] }]
  volumes: [{ name: s, persistentVolumeClaim: { claimName: scratch } }]
EOF
     ;;   # volumeClaimTemplates on a live StatefulSet are immutable, so the break is a new claim
  4) kubectl -n shop patch role pod-reader --type=json -p \
       '[{"op":"replace","path":"/rules/0/verbs","value":["get"]}]' ;;   # list and watch gone
esac
echo "something is broken. go."
SH
chmod +x break.sh
```

**Log every run with the time taken.** By week 17 the target is under 15 minutes each, consistently.

---

# Lab 6 — Helm (3h)

```bash
helm create shop
helm lint shop
helm template shop --values values-dev.yaml | less
helm install shop ./shop -n shop --create-namespace -f values-dev.yaml
helm upgrade shop ./shop -f values-prod.yaml
helm history shop -n shop
helm rollback shop 1 -n shop
helm uninstall shop -n shop
```

**Tasks:** package the week-14 stack as a chart. Values must control replicas, image tag, resources,
probe timings, ingress host, and whether the database is enabled. Then write `values-dev.yaml` and
`values-prod.yaml` differing **only in values** — the same discipline as week 11's dev/prod split.

```yaml
# templates/_helpers.tpl
{{- define "shop.labels" -}}
app.kubernetes.io/name: {{ include "shop.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
```

**Helm vs Kustomize, for the interview:** Helm is templating with a package manager — versioning,
dependencies, a registry, `rollback`. Kustomize is patching — no templating language, no
dependencies, built into `kubectl`. Helm for third-party software you consume; Kustomize (or Helm)
for your own manifests. ArgoCD supports both natively (week 16).
