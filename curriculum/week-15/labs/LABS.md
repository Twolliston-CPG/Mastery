# Week 15 Labs

> **Figures:** one numbered mechanism figure per lab, with the spoken script, the numbers to own and
> the command that proves each badge, in [`FIGURES.md`](FIGURES.md) (15.2 to 15.8). Read a lab's figure
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
8. **CKA thread — Jobs (30 min):** a `Job` with `completions: 3`, `parallelism: 2`, `backoffLimit: 1`
   whose command fails on the first attempt (`sh -c 'exit $((RANDOM % 2))'`). Read `describe job`,
   the pod names, and when the Job gives up. Then a `CronJob` on `* * * * *` with
   `concurrencyPolicy: Forbid` and `successfulJobsHistoryLimit: 1`; watch two runs, then
   `kubectl patch cronjob <n> -p '{"spec":{"suspend":true}}'` and prove nothing new starts.

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

**CKA thread — the same stack with Kustomize (45 min).** No templating: a `base/` holding the plain
manifests and a `kustomization.yaml` listing them, then `overlays/dev/` and `overlays/prod/` that
patch only replicas and the image tag (a strategic-merge patch for one, a JSON patch for the other,
so you have written both). `kubectl kustomize overlays/prod | less`, then `kubectl apply -k
overlays/prod`. Write the one-paragraph comparison: Helm templates and packages a release with a
history; Kustomize patches plain YAML with no release object at all. The exam asks for both, and
most production teams run both.

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

---

# Go deeper — The scheduler, plugin by plugin (3h · ladder: scheduling, rung 4)

**Optional inside the week, mandatory for the ladder** ([`KUBERNETES-MASTERY.md`](../../../KUBERNETES-MASTERY.md)).
Lab 2 used the scheduler: taints, affinity, a pod stuck Pending. This lab opens it. The scheduler is
a loop over a queue, and each pod goes through a fixed list of **plugins** in two phases: filter
(which nodes can take it) and score (which of those is best). By the end you have read a decision
from the logs, run a second scheduler with a different opinion, caused a preemption, and watched the
queue retry. On the `mastery` kind cluster: one control plane, two workers.

## Part 1 — Read one decision (35 min)

The default log level hides the scores. Raise it on the static pod; the kubelet restarts the
scheduler for you (Figure 14.2, badge ③):

```bash
docker exec mastery-control-plane sed -i 's/- --v=[0-9]*//; s/- kube-scheduler/- kube-scheduler\n    - --v=10/' \
  /etc/kubernetes/manifests/kube-scheduler.yaml
sleep 15 && kubectl -n kube-system get pod -l component=kube-scheduler
```

`-v=10` is loud; you will filter. Schedule one pod and read it:

```bash
kubectl run scored --image=nginx:alpine --requests=cpu=100m,memory=64Mi
kubectl -n kube-system logs -l component=kube-scheduler --tail=2000 \
  | grep -E 'scored|"Attempting to schedule pod"|"Computing predicates"|feasible|Successfully bound' \
  | grep scored
```

Expect, in order: `Attempting to schedule pod`, then one line per **score plugin per node**:
`"Plugin scored node for pod" pod="default/scored" plugin="NodeResourcesFit" node="mastery-worker" score=...`,
then the totals and `Successfully bound pod to node`. Write down which plugins scored (the defaults
include `NodeResourcesFit`, `NodeResourcesBalancedAllocation`, `ImageLocality`, `TaintToleration`,
`NodeAffinity`, `InterPodAffinity`, `PodTopologySpread`) and which node won and by how much. Then
read the **filter** side: taint a worker and schedule again; the control plane node was never a
candidate either, and the log says why (`TaintToleration` filtered it).

```bash
kubectl taint node mastery-worker2 deep=yes:NoSchedule
kubectl run scored2 --image=nginx:alpine
kubectl -n kube-system logs -l component=kube-scheduler --tail=500 | grep -E 'scored2' | grep -iE 'filter|feasible|taint' | head
kubectl taint node mastery-worker2 deep-
```

The plugin list and the two phases are the **scheduling framework**; the reading is
`pkg/scheduler/framework` in the Kubernetes repository and the enhancement proposal that introduced
it (KEP-624). Every plugin implements one or more extension points: PreFilter, Filter, PostFilter,
PreScore, Score, Reserve, Permit, PreBind, Bind, PostBind. Preemption is a PostFilter plugin.

## Part 2 — A second scheduler with a different opinion (50 min)

The default `NodeResourcesFit` scoring strategy is `LeastAllocated`: spread. Run a second scheduler
that **packs** (`MostAllocated`) and ignores balanced allocation, and prove it chooses differently.

```yaml
# packing-config.yaml  (goes into a ConfigMap)
apiVersion: kubescheduler.config.k8s.io/v1
kind: KubeSchedulerConfiguration
leaderElection:
  leaderElect: false                 # one replica, no lease; the docs' manifest shows the leased form
profiles:
  - schedulerName: packing
    plugins:
      score:
        disabled:
          - name: NodeResourcesBalancedAllocation
    pluginConfig:
      - name: NodeResourcesFit
        args:
          scoringStrategy:
            type: MostAllocated
            resources:
              - { name: cpu, weight: 1 }
              - { name: memory, weight: 1 }
```

Deploy it as a Deployment in `kube-system`: the image is `registry.k8s.io/kube-scheduler:<your cluster
version>` (`kubectl version` says which), the command is `kube-scheduler --config=/etc/kubernetes/packing-config.yaml --v=4`,
the config is mounted from the ConfigMap, and the pod runs as a ServiceAccount bound to the
`system:kube-scheduler` and `system:volume-scheduler` ClusterRoles. The Kubernetes docs page
**"Configure Multiple Schedulers"** carries the complete manifest, RBAC included; copy it, change
the config, and read every line you copied.

```bash
kubectl create cm packing-config -n kube-system --from-file=packing-config.yaml
kubectl apply -f packing-scheduler.yaml        # the docs manifest, edited
kubectl -n kube-system get pods -l component=scheduler
```

Now the experiment. Six pods with real requests, three per scheduler, and count where they land:

```bash
for s in default-scheduler packing; do
  for i in 1 2 3; do
    kubectl run $s-$i --image=nginx:alpine --requests=cpu=200m,memory=64Mi \
      --overrides="{\"spec\":{\"schedulerName\":\"$s\"}}"
  done
done
kubectl get pods -o custom-columns='NAME:.metadata.name,SCHED:.spec.schedulerName,NODE:.spec.nodeName'
```

`LeastAllocated` alternates between the workers; `MostAllocated` keeps choosing the fuller one until
it cannot. Read the packing scheduler's own log and find the `NodeResourcesFit` scores that inverted.
Say what each strategy is for: spreading survives a node loss; packing lets a cluster autoscaler
remove a node. Neither is "right"; it is a question you ask about the workload.

## Part 3 — Preemption (30 min)

Fill one worker, then send a pod that outranks what is there:

```bash
ALLOC=$(kubectl get node mastery-worker -o jsonpath='{.status.allocatable.cpu}'); echo "allocatable cpu: $ALLOC"
kubectl create deploy filler --image=nginx:alpine --replicas=4
kubectl patch deploy filler -p '{"spec":{"template":{"spec":{"nodeSelector":{"kubernetes.io/hostname":"mastery-worker"},
  "containers":[{"name":"nginx","resources":{"requests":{"cpu":"'$(( ${ALLOC%m} / 4 - 50 ))'m"}}}]}}}}'
kubectl get pods -o wide                              # four fillers on mastery-worker, little cpu left
kubectl create priorityclass urgent --value=1000000 --description="preempts"
kubectl run vip --image=nginx:alpine --requests=cpu=500m \
  --overrides='{"spec":{"priorityClassName":"urgent","nodeSelector":{"kubernetes.io/hostname":"mastery-worker"}}}'
kubectl get pod vip -o jsonpath='{.status.nominatedNodeName}{"\n"}'
kubectl get events --sort-by=.lastTimestamp | grep -iE 'preempt|vip|filler' | tail -8
```

The sequence: the filter phase finds no node for `vip`; the PostFilter (preemption) plugin picks a
node where evicting the lowest-priority pods would make room, writes `status.nominatedNodeName`, and
deletes the victims (the event on each says `Preempted by default/vip on node mastery-worker`). The
victims get their graceful termination period; `vip` stays Pending until the resources are actually
free, then binds. Note what `nominatedNodeName` is for: it reserves the node in the scheduler's
accounting so a third pod does not take the freed space first. If `ALLOC` is large on your machine,
raise the filler requests until the worker is actually full; preemption only happens when the filter
phase fails.

## Part 4 — Spread versus anti-affinity, counted (25 min)

Same workload, three placements, counted per node. Two workers, six replicas:

```bash
count() { kubectl get pods -l app=$1 -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}' | sort | uniq -c; }
kubectl create deploy spread --image=nginx:alpine --replicas=6
kubectl patch deploy spread -p '{"spec":{"template":{"spec":{"topologySpreadConstraints":[{"maxSkew":1,
  "topologyKey":"kubernetes.io/hostname","whenUnsatisfiable":"DoNotSchedule","labelSelector":{"matchLabels":{"app":"spread"}}}]}}}}'
count spread                                            # 3 and 3
kubectl create deploy anti --image=nginx:alpine --replicas=6
kubectl patch deploy anti -p '{"spec":{"template":{"spec":{"affinity":{"podAntiAffinity":{"requiredDuringSchedulingIgnoredDuringExecution":[
  {"topologyKey":"kubernetes.io/hostname","labelSelector":{"matchLabels":{"app":"anti"}}}]}}}}}}'
count anti; kubectl get pods -l app=anti | grep -c Pending     # 1 per worker, 4 Pending: required means required
```

Then change `required...` to `preferred...` with a weight and count again. The three say different
things: spread constraints bound the **imbalance** (`maxSkew`); required anti-affinity forbids
**co-location** and refuses to run more pods than nodes; preferred anti-affinity is a score, not a
filter, and will co-locate when it must. For a web tier across zones the first is almost always the
one you want, and `topologyKey: topology.kubernetes.io/zone` is the one-word change on EKS.

## Part 5 — The queue, and when it retries (20 min)

```bash
kubectl run stuck --image=nginx:alpine --overrides='{"spec":{"nodeSelector":{"disk":"nvme"}}}'
kubectl -n kube-system logs -l component=kube-scheduler --tail=200 | grep stuck | grep -iE 'unschedulable|no fit|backoff|retry' | head
```

A pod the filter phase rejects does not spin. It goes to the **unschedulable** pool, and the
scheduler moves it back to the active queue when a cluster event could change the answer: a node
joins, a node's labels change, a pod on a node ends. Retries that fail again back off, from one second
doubling to ten (`podInitialBackoffSeconds` and `podMaxBackoffSeconds` in the configuration). Prove
the event path: label a worker and watch the pod bind within seconds, with no restart of anything.

```bash
kubectl label node mastery-worker2 disk=nvme
kubectl get pod stuck -o wide                           # Running, on mastery-worker2
kubectl -n kube-system logs -l component=kube-scheduler --tail=100 | grep -E 'stuck' | tail -3
```

Clean up: delete the deployments, the priority class, the label, and the packing scheduler; put the
scheduler's verbosity back (`docker exec mastery-control-plane sed -i '/- --v=10/d' /etc/kubernetes/manifests/kube-scheduler.yaml`).

**From memory, timed (20 min):** with the file closed, name the two phases and five default plugins,
write a `KubeSchedulerConfiguration` profile that packs, and produce a preemption whose victim's event
you can quote. Target: under twenty minutes.
