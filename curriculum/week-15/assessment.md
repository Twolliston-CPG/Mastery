# Week 15 Assessment

> Closed book, 35 min.

## Part A (20 min)
1. requests vs limits — who enforces each, and what happens when you exceed each?
2. Why can a cluster at 10% CPU utilization be 100% unschedulable?
3. Name the three QoS classes, their conditions, and eviction order.
4. What are the three probes and what does failing each one do?
5. Describe the production disaster caused by a database check in a liveness probe.
6. What is `startupProbe` for, and what would you have to do without it?
7. What does `minAvailable: 1` do on a **1-replica** Deployment, and why is that a problem?
8. `required` anti-affinity vs `topologySpreadConstraints` — which and why?
9. Name the three taint effects and what each does.
10. Why would a PVC correctly stay Pending?
11. `ReadWriteOnce` vs `ReadWriteMany` — what backs each, and what breaks if you confuse them?
12. Why are StatefulSet PVCs retained when you delete the StatefulSet?
13. A `ClusterRole` bound with a `RoleBinding` — what's the scope?
14. Five causes of an RBAC `Forbidden`.
15. Helm vs Kustomize — when each?

## Part B — Commands (10 min)
16. Show the QoS class of every pod
17. Show whether a service account can list pods in a namespace
18. List everything a service account is allowed to do
19. Find every ClusterRoleBinding granting `cluster-admin`
20. Show the exit code and reason of a crashed container
21. Show allocated vs capacity resources on a node
22. Drain a node safely
23. See what a Helm chart will actually apply, without applying it

## Part C — Gate 4 rehearsal (5 min)
24. Pod is `Pending`. Name five possible causes and the single command that tells you which.
25. Pod restarts every 30 seconds with perfectly normal logs. What is it?

---

# Answer key

**A1.** **request** — what the scheduler reserves; determines placement; enforced at admission.
**limit** — the runtime ceiling; enforced by the kernel cgroup. Exceeding CPU → **throttled**
(slower, alive). Exceeding memory → **SIGKILL, exit 137, OOMKilled**.

**A2.** Scheduling is based on **requests**, not usage. If requests are set far above real
consumption, the scheduler believes the nodes are full while `kubectl top` shows them idle.

**A3.** `Guaranteed` (requests == limits for every container) — evicted **last**.
`Burstable` (requests < limits) — middle. `BestEffort` (neither set) — evicted **first**.

**A4.** **startup** — suppresses the other two until it passes; failing kills the container.
**liveness** — failing **restarts** the container. **readiness** — failing **removes the pod from
Service endpoints** without restarting it.

**A5.** A database blip fails liveness on **every replica at once**; Kubernetes restarts the whole
fleet simultaneously; the reconnection storm extends the database's recovery. A five-second hiccup
becomes a multi-minute outage, with monitoring showing "everything restarting" and no obvious cause.

**A6.** It allows a slow boot without weakening liveness permanently. Without it you'd set a large
`initialDelaySeconds` on liveness — which also delays genuine failure detection forever after
startup.

**A7.** A drain can never satisfy it — evicting the only pod leaves zero available. **The drain
blocks indefinitely**, so node upgrades hang and the cluster autoscaler cannot remove the node. Use
`maxUnavailable: 1`, or run 2 replicas.

**A8.** `topologySpreadConstraints` with `whenUnsatisfiable: ScheduleAnyway`. `required`
anti-affinity turns a capacity shortage into a **permanently Pending** pod — 3 replicas on 2 nodes
never schedules the third.

**A9.** `NoSchedule` — no new pods without a toleration. `PreferNoSchedule` — soft preference.
`NoExecute` — also **evicts already-running pods** that don't tolerate it.

**A10.** `volumeBindingMode: WaitForFirstConsumer`. Binding is delayed until a pod is scheduled so the
volume is created in the **same AZ** as the pod. With `Immediate` you get
`volume node affinity conflict` and a permanently unschedulable pod.

**A11.** RWO = one **node** at a time, backed by **block** storage (EBS, GCE PD). RWX = many nodes,
backed by a **filesystem** (EFS, NFS). Confusing them: scaling a Deployment with an RWO PVC across
nodes leaves the second pod stuck with `Multi-Attach error`.

**A12.** Deliberate data safety. Deleting a StatefulSet should not be deleting the data; retaining
PVCs lets you recreate the StatefulSet and reattach. Cleanup is explicit
(`kubectl delete pvc -l app=db`), or configurable via
`persistentVolumeClaimRetentionPolicy` in newer versions.

**A13.** **Only that one namespace.** It's legal and often intended — it's how you reuse a
cluster-wide role definition with namespace-scoped effect — but it surprises people.

**A14.** (1) Role/RoleBinding is namespace-scoped and the request was for another namespace.
(2) ClusterRole bound with a RoleBinding. (3) Wrong `apiGroup` (`""` for core, `"apps"` for
deployments). (4) Missing sub-resource (`pods/log`, `pods/exec`). (5) The pod isn't using the
ServiceAccount you think.

**A15.** **Helm** for third-party software you consume — versioning, dependencies, a registry,
`rollback`. **Kustomize** for your own manifests — no templating language, output is always valid
YAML, built into `kubectl`. ArgoCD supports both, so it isn't exclusive.

---

**B16.** `kubectl get pods -o custom-columns=NAME:.metadata.name,QOS:.status.qosClass`
**B17.** `kubectl auth can-i list pods --as=system:serviceaccount:ns:sa -n ns`
**B18.** `kubectl auth can-i --list --as=system:serviceaccount:ns:sa -n ns`
**B19.** `kubectl get clusterrolebindings -o json | jq -r '.items[] | select(.roleRef.name=="cluster-admin") | .metadata.name'`
**B20.** `kubectl get pod X -o jsonpath='{.status.containerStatuses[0].lastState.terminated}' | jq`
**B21.** `kubectl describe node N | grep -A8 'Allocated resources'`
**B22.** `kubectl cordon N && kubectl drain N --ignore-daemonsets --delete-emptydir-data`
**B23.** `helm template <release> ./chart -f values.yaml`

---

**C24.** Causes: insufficient CPU/memory **requests** available · untolerated node taint ·
`nodeSelector`/affinity matches nothing · unbound PVC · volume node-affinity conflict · pod-count
limit on the node. **The one command: `kubectl describe pod <pod>`** — the `FailedScheduling` event
names the reason verbatim.

**C25.** **A liveness probe is killing it.** Normal logs mean the app is fine; something external is
terminating it. Check `kubectl describe pod` for `Liveness probe failed`, and compare
`initialDelaySeconds`/`startupProbe` against the app's real boot time. (Second possibility: OOMKilled,
but that shows exit 137 and `reason: OOMKilled` in `lastState`.)

## Scoring
| | |
|---|---|
| 20–25 | On track for Gate 4. |
| 15–19 | Redo Lab 1 and Lab 5. |
| < 15 | **Redo the whole week.** These are the Gate 4 scenarios and the most common junior K8s interview questions, almost verbatim. |
