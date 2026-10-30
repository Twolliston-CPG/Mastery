# Mock Exam 1 — eighteen tasks, two hours, 100 points

> Run on the kubeadm cluster after `solutions/mock-exam-1-setup.sh` has been run by someone who is
> not you. Timer visible. Docs allowed, nothing else. Pass mark for the real exam is 66 %
> (confirm in the candidate handbook); treat 66 here as the bar too.
>
> Every task names the **context** to switch to first. Contexts `mock-a`, `mock-b`, `mock-c` all
> point at this cluster with different default namespaces; the exam's contexts point at different
> clusters, and the habit is the same. Write answers that ask for a file to `/opt/answers/` on
> `k8s-cp`.

Domain split: Troubleshooting 30 · Cluster Architecture 25 · Services and Networking 20 ·
Workloads and Scheduling 15 · Storage 10.

| # | Weight | Context | Domain |
|---|---|---|---|
| 1 | 8 | mock-a | Troubleshooting |
| 2 | 5 | mock-a | Troubleshooting |
| 3 | 5 | mock-a | Troubleshooting |
| 4 | 7 | mock-b | Troubleshooting |
| 5 | 5 | mock-b | Troubleshooting |
| 6 | 8 | mock-b | Cluster Architecture |
| 7 | 4 | mock-a | Cluster Architecture |
| 8 | 7 | mock-b | Cluster Architecture |
| 9 | 6 | mock-c | Cluster Architecture |
| 10 | 6 | mock-a | Services and Networking |
| 11 | 6 | mock-c | Services and Networking |
| 12 | 4 | mock-a | Services and Networking |
| 13 | 4 | mock-c | Services and Networking |
| 14 | 5 | mock-a | Workloads and Scheduling |
| 15 | 4 | mock-c | Workloads and Scheduling |
| 16 | 6 | mock-c | Workloads and Scheduling |
| 17 | 6 | mock-b | Storage |
| 18 | 4 | mock-b | Storage |

---

## Task 1 — 8 points · context `mock-a`

Node `k8s-w2` is `NotReady`. Make it `Ready`. The fix must survive a reboot of the node.

**End state:** `kubectl get nodes` shows `k8s-w2` `Ready`; on the node, `systemctl is-enabled kubelet` prints `enabled`.

## Task 2 — 5 points · context `mock-a`

In namespace `shop`, deployment `web` has zero Ready replicas. Make all three replicas Ready without changing the replica count.

**End state:** `kubectl -n shop get deploy web` shows `3/3`.

## Task 3 — 5 points · context `mock-a`

In namespace `shop`, service `api` returns no response from inside the cluster. Fix it without recreating the service or the deployment. Then write the service's ClusterIP to `/opt/answers/task3.txt`.

**End state:** `kubectl -n shop get endpoints api` lists two addresses; `/opt/answers/task3.txt` contains the ClusterIP.

## Task 4 — 7 points · context `mock-b`

New pods in every namespace stay `Pending` and `kubectl describe` shows no `FailedScheduling` event at all. Find the cause on the control plane and fix it. Write the path of the file you changed to `/opt/answers/task4.txt`.

**End state:** `kubectl -n kube-system get pod kube-scheduler-k8s-cp` is `Running`; `kubectl run probe --image=busybox:1.36 -- sleep 60` reaches `Running`; the file contains the manifest path.

## Task 5 — 5 points · context `mock-b`

Pods in namespace `shop` cannot resolve `kubernetes.io`; `api.shop.svc.cluster.local` still resolves. Fix external name resolution.

**End state:** `kubectl -n shop exec deploy/web -- nslookup kubernetes.io` succeeds.

## Task 6 — 8 points · context `mock-b`

Take a snapshot of etcd to `/opt/answers/etcd-snapshot.db`. Then restore the cluster from the snapshot that already exists at `/opt/mock/etcd-before.db`, so that the namespace `restored-ns` (which existed when that snapshot was taken) is present again.

**End state:** `/opt/answers/etcd-snapshot.db` exists and `etcdutl snapshot status` (or `etcdctl snapshot status`) reads it; `kubectl get ns restored-ns` succeeds; all control-plane pods are Running.

## Task 7 — 4 points · context `mock-a`

Create a ServiceAccount `auditor` in namespace `shop`, a Role `secret-lister` that allows `list` and `get` on `secrets` only, and bind them. Write the output of `kubectl auth can-i list secrets --as=system:serviceaccount:shop:auditor -n shop` to `/opt/answers/task7.txt`.

**End state:** the file contains `yes`; `auth can-i delete secrets` for the same account prints `no`.

## Task 8 — 7 points · context `mock-b`

Node `k8s-w1` runs a kubelet one patch version behind the control plane. Upgrade `kubeadm` and `kubelet` on `k8s-w1` to the control plane's version, draining the node first and uncordoning it afterwards.

**End state:** `kubectl get nodes` shows identical versions for `k8s-cp` and `k8s-w1`, and `k8s-w1` is `Ready` and schedulable.

## Task 9 — 6 points · context `mock-c`

Install the Helm chart found at `/opt/mock/charts/hello` as release `hello` in namespace `apps` (create it), with values from `/opt/mock/charts/hello-values.yaml` and the replica count overridden to 2. Then list every CustomResourceDefinition in the cluster whose group ends in `.projectcalico.org` and write the names, one per line, to `/opt/answers/task9.txt`.

**End state:** `helm -n apps status hello` is `deployed` with 2 Ready pods; the file lists the Calico CRDs.

## Task 10 — 6 points · context `mock-a`

Namespace `shop` has a `deny-all` NetworkPolicy that must stay. Add policies so that: every pod in `shop` can resolve DNS; pods labelled `app=web` can reach pods labelled `app=api` on TCP 8080; nothing else changes.

**End state:** from a `web` pod, `wget -qO- api:8080` succeeds and `wget -qO- --timeout=3 db:5432` fails; `nslookup api` succeeds.

## Task 11 — 6 points · context `mock-c`

A GatewayClass `mock-gw` exists. Create a Gateway `apps-gw` in namespace `apps` listening on HTTP port 80, and an HTTPRoute `hello` in `apps` that sends requests for host `hello.local` with path prefix `/` to service `hello` on port 80.

**End state:** `kubectl -n apps get gateway apps-gw` shows `PROGRAMMED True`; `kubectl -n apps get httproute hello` shows the parent accepted.

## Task 12 — 4 points · context `mock-a`

Expose deployment `web` in `shop` with a NodePort service named `web-np` on port 80, node port 30080.

**End state:** `curl -s http://<any-node-ip>:30080` returns the nginx page.

## Task 13 — 4 points · context `mock-c`

Create an Ingress `hello` in namespace `apps` with ingress class `nginx`, routing `hello.local/` (prefix) to service `hello` port 80.

**End state:** `kubectl -n apps get ingress hello -o jsonpath='{.spec.ingressClassName}'` prints `nginx` and the rule is present.

## Task 14 — 5 points · context `mock-a`

Update deployment `web` in `shop` to image `nginx:1.27-alpine` using a rolling update that never drops below three Ready pods. Record the change cause `"alpine"`. Then roll back to the previous revision.

**End state:** `kubectl -n shop rollout history deploy web` shows at least three revisions with the change cause on one of them; the running image is the one before `1.27-alpine`.

## Task 15 — 4 points · context `mock-c`

Create a CronJob `report` in namespace `apps` that runs `busybox:1.36` with `date` every ten minutes, keeps 3 successful and 1 failed job in history, and never runs two jobs at once.

**End state:** `kubectl -n apps get cj report -o jsonpath='{.spec.concurrencyPolicy}'` prints `Forbid`; the schedule is `*/10 * * * *`.

## Task 16 — 6 points · context `mock-c`

Create a pod `logger` in namespace `apps` with two containers: `app` running `busybox:1.36` writing the date to `/var/log/app/out.log` every five seconds, and `shipper` running `busybox:1.36` tailing that file. They share an `emptyDir`. The pod must run only on nodes labelled `tier=apps` and must tolerate the taint `dedicated=apps:NoSchedule`.

**End state:** `kubectl -n apps get pod logger -o wide` shows it Running on `k8s-w1`; `kubectl -n apps logs logger -c shipper` shows dates.

## Task 17 — 6 points · context `mock-b`

Create a PersistentVolume `pv-mock` of 1Gi, `hostPath` `/mnt/mock`, access mode `ReadWriteOnce`, storage class `manual`, reclaim policy `Retain`. Create a PVC `pvc-mock` in namespace `data` that binds to it, and a pod `writer` in `data` mounting it at `/data` that writes `hello` to `/data/hello.txt`.

**End state:** `kubectl -n data get pvc pvc-mock` is `Bound` to `pv-mock`; `/mnt/mock/hello.txt` on the pod's node contains `hello`.

## Task 18 — 4 points · context `mock-b`

Create a StorageClass `slow` using provisioner `kubernetes.io/no-provisioner` with `volumeBindingMode: WaitForFirstConsumer`. Create a PVC `slow-claim` in `data` of 500Mi using it. Explain in `/opt/answers/task18.txt`, in one line, why the PVC is Pending and what would make it bind.

**End state:** the StorageClass exists with that binding mode; the PVC is `Pending`; the file has the one-line answer.

---

When the timer stops, stop. Score with [`../solutions/MOCK-EXAM-1-SOLUTIONS.md`](../solutions/MOCK-EXAM-1-SOLUTIONS.md).
