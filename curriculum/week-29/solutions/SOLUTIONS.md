# Week 29 Solutions

Mock exam: [`MOCK-EXAM-1-SOLUTIONS.md`](MOCK-EXAM-1-SOLUTIONS.md) and its setup script
[`mock-exam-1-setup.sh`](mock-exam-1-setup.sh).

---

## Lab 1 — The exam terminal

### Part 2 timing, and where the twelve minutes go

A clean run of the eight generators plus edits, applied and verified on kind, lands between nine and
twelve minutes. The time sinks, in the order people hit them:

| Sink | Fix |
|---|---|
| Typing `--dry-run=client -o yaml` by hand | `$do` |
| Hand-writing a probe block | `kubectl explain pod.spec.containers.livenessProbe --recursive`, copy the field names, not the docs |
| A tab character in the YAML | the `.vimrc`; the error reads `found character that cannot start any token` |
| Applying to the wrong namespace | `kn shop`, then `kubectl config view --minify \| grep namespace` |
| Forgetting `--command` on `kubectl run` | without it, the args after `--` replace the image's args, not its entrypoint |

### Part 3, the answers that go to a file

```bash
k get pod X -o jsonpath='{.status.containerStatuses[0].lastState.terminated.exitCode}{"\n"}' > /opt/answers/exit.txt
k get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.nodeInfo.kubeletVersion}{"\n"}{end}' > /opt/answers/versions.txt
k get pods -A --field-selector status.phase!=Running -o name > /opt/answers/not-running.txt
cat /opt/answers/*.txt      # always: the proof is the file, not the command
```

### Part 5, the ritual timed

Overhead per task: two `kubectl config` commands, one read of the end state, one verification
command, one line of notes. Thirty to forty seconds once it is reflex; ninety seconds while it is
still a checklist. Twelve reps on Monday is what moves it from the second number to the first.

---

## Lab 2 — The twelve breaks

`seed.sh`, run once on `k8s-cp`, creates the `shop` namespace the cases assume:

```bash
cat > seed.sh <<'SH'
#!/usr/bin/env bash
set -euo pipefail
kubectl get ns shop >/dev/null 2>&1 || kubectl create ns shop
kubectl -n shop create deploy web --image=nginx:1.27 --replicas=3 --dry-run=client -o yaml | kubectl apply -f -
kubectl -n shop expose deploy web --port=80 --dry-run=client -o yaml | kubectl apply -f -
kubectl -n shop create deploy api --image=nginxinc/nginx-unprivileged:1.27 --replicas=2 --port=8080 --dry-run=client -o yaml | kubectl apply -f -
kubectl -n shop expose deploy api --port=8080 --dry-run=client -o yaml | kubectl apply -f -
kubectl -n shop create sa deployer --dry-run=client -o yaml | kubectl apply -f -
kubectl -n shop create role pod-reader --verb=get,list,watch --resource=pods,pods/log --dry-run=client -o yaml | kubectl apply -f -
kubectl -n shop create rolebinding deployer-reader --role=pod-reader --serviceaccount=shop:deployer --dry-run=client -o yaml | kubectl apply -f -
kubectl -n shop rollout status deploy/web && kubectl -n shop rollout status deploy/api
SH
bash seed.sh
```

| Case | Family | First command shows | Fix | The file, if any |
|---|---|---|---|---|
| 0 | application | `describe pod`: `manifest unknown` | `rollout undo deploy/web` | — |
| 1 | application | `get endpoints api`: none; and the pod's port | selector back to `app=api`; `set env deploy/api APP_PORT-` is a red herring the image ignores, say so | — |
| 2 | application | `auth can-i list pods --as=...deployer`: no | `kubectl -n shop edit role pod-reader`, verbs back to get,list,watch | — |
| 3 | control plane | `kubectl`: connection refused; `crictl ps -a`: apiserver exiting; `crictl logs`: cannot connect to etcd on 2378 | `--etcd-servers` back to `:2379` | `/etc/kubernetes/manifests/kube-apiserver.yaml` |
| 4 | control plane | Pending with no events; scheduler pod missing or crashing | `kube-schedulerr` → `kube-scheduler` | `/etc/kubernetes/manifests/kube-scheduler.yaml` |
| 5 | control plane | `kubectl get nodes`: Forbidden for `system:node:k8s-cp` | `mv /etc/kubernetes/admin.conf.bak /etc/kubernetes/admin.conf`; or regenerate with `kubeadm kubeconfig user --client-name kubernetes-admin --org system:masters` | `/etc/kubernetes/admin.conf` |
| 6 | worker node | `describe node`: Kubelet stopped posting status | `systemctl enable --now kubelet` on the node | — |
| 7 | worker node | pods ContainerCreating; `journalctl -u kubelet`: cannot connect to CRI socket | `systemctl start containerd` on the node | — |
| 8 | worker node | `describe node`: DiskPressure True; `df -h /var/lib` | `rm /var/lib/fill.img`; the taint clears itself | — |
| 9 | networking | `nslookup kubernetes.io` fails, `nslookup api` works | `forward . /etc/resolv.conf` in the CoreDNS ConfigMap, restart | — |
| 10 | networking | every connection times out, DNS included | allow-dns egress, web→api ingress and egress on 8080 (the Mock Exam Task 10 manifests) | — |
| 11 | networking | `network plugin not ready`; `calico-node` DaemonSet desired 0 | remove the `nodeSelector` from the DaemonSet | — |

Case 5's error is the tell: `kubelet.conf` carries the node's identity, so `kubectl` suddenly
speaks as `system:node:k8s-cp` and the Node authorizer refuses almost everything.

Case 8 on a small disk: `dd` can take a minute; the eviction follows within the kubelet's
`evictionPressureTransitionPeriod` (5 minutes by default), so give the symptom time to appear before
starting the timer.

---

## Lab 5 — Two more weightings for the triage drill

Same eighteen tasks, different weights. Order them in five minutes, then check against the rules.

**Weighting B.** 1:4 · 2:8 · 3:4 · 4:5 · 5:7 · 6:13 · 7:3 · 8:5 · 9:4 · 10:8 · 11:3 · 12:6 · 13:4 · 14:5 · 15:6 · 16:4 · 17:7 · 18:4 (= 100).
The 13-point etcd task is the trap: it goes in the middle, after the 8s you are sure of, never last.

**Weighting C.** 1:9 · 2:3 · 3:6 · 4:9 · 5:4 · 6:6 · 7:5 · 8:10 · 9:3 · 10:5 · 11:7 · 12:3 · 13:3 · 14:6 · 15:4 · 16:7 · 17:6 · 18:4 (= 100).
Two 9s and a 10 that are all node work: do them consecutively while you are already on the nodes,
not spread across the two hours.

An order is right when: the first forty minutes are tasks you were sure of, the two longest tasks
sit between 0:40 and 1:30, nothing under 4 points that you did not know how to start was attempted,
and the last ten minutes were verification. The exact sequence is yours.
