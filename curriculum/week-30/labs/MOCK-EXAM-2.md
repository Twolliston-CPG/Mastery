# Mock Exam 2 — three sets of eight, forty minutes each

> One set per family group. Run your weakest family's set three times (cold, after the solutions,
> next morning); then the second family's. Each set is eight tasks, equal weight, forty minutes:
> five minutes per task, which is the exam's pace with no slack. Docs allowed, nothing else.
>
> Contexts `mock-a` (namespace `shop`), `mock-b` (`default`), `mock-c` (`apps`) from week 29's
> setup. Each set is prepared by `../solutions/mock-exam-2-setup.sh A` (or `B`, `C`), run by someone who is not you. Answers that ask for a file go to `/opt/answers/`.

---

## Set A — Troubleshooting (eight tasks, 40 min)

**A1 · mock-a.** Deployment `web` in `shop` shows `2/3` Ready and one pod `CrashLoopBackOff`. Make it `3/3` without changing the image.
End state: `kubectl -n shop get deploy web` shows `3/3`.

**A2 · mock-a.** Service `web` in `shop` has endpoints, but `wget -qO- web` from another pod in the namespace is refused. Fix the service.
End state: `kubectl -n shop exec deploy/api -- wget -qO- --timeout=3 web` returns HTML.

**A3 · mock-b.** `kubectl get nodes` shows `k8s-w1` `NotReady`. The kubelet is running. Find why and fix it.
End state: `k8s-w1` is `Ready`.

**A4 · mock-b.** Pods cannot be created in any namespace: `kubectl run` returns an error mentioning a webhook or admission. Restore pod creation; the admission configuration that caused it must be removed, and its name written to `/opt/answers/a4.txt`.
End state: `kubectl run probe --image=busybox:1.36 -- sleep 30` succeeds; the file names the webhook configuration.

**A5 · mock-b.** The controller manager is not running. New Deployments create no ReplicaSets. Fix it; write the path of the file you changed to `/opt/answers/a5.txt`.
End state: `kubectl -n kube-system get pod kube-controller-manager-k8s-cp` is `Running`; `kubectl create deploy probe2 --image=nginx:1.27` produces a ReplicaSet.

**A6 · mock-a.** Pods in `shop` resolve nothing at all, not even cluster names. Fix DNS.
End state: `kubectl -n shop exec deploy/api -- nslookup web` succeeds.

**A7 · mock-b.** Node `k8s-w2` is `Ready` but no new pod is ever scheduled to it, and nobody added a taint. Find the cause and fix it so that a pod with no constraints can land there.
End state: `kubectl get node k8s-w2 -o jsonpath='{.spec.unschedulable}'` is empty; a new pod scheduled with `nodeName: k8s-w2` runs.

**A8 · mock-a.** The `deployer` ServiceAccount in `shop` must be able to `get` and `list` pods **and** read their logs. It can list pods but `kubectl logs` as that account is `Forbidden`. Fix the Role.
End state: `kubectl auth can-i get pods/log --as=system:serviceaccount:shop:deployer -n shop` prints `yes`.

---

## Set B — Cluster architecture and storage (eight tasks, 40 min)

**B1 · mock-b.** Take an etcd snapshot to `/opt/answers/b1.db` and write the snapshot's total key count to `/opt/answers/b1.txt`.
End state: `etcdutl snapshot status /opt/answers/b1.db` works; the file holds the key count from that output.

**B2 · mock-b.** Check the expiry of every control-plane certificate and write the output to `/opt/answers/b2.txt`. Then renew only the `apiserver` certificate and restart what must be restarted for it to take effect.
End state: the file lists the certificates; `kubeadm certs check-expiration` shows a new expiry for `apiserver`; `kubectl get --raw /readyz` is `ok`.

**B3 · mock-b.** Drain `k8s-w2` for maintenance, respecting that `shop` has a PodDisruptionBudget `web-pdb` with `minAvailable: 2`. Then uncordon it.
End state: the drain completed without `--disable-eviction`; `web` never went below two Ready pods (check `kubectl -n shop get deploy web -w` output you saved to `/opt/answers/b3.txt`); `k8s-w2` is schedulable.

**B4 · mock-b.** Write the command sequence that upgrades the **control plane** to the next patch version to `/opt/answers/b4.sh`, in the correct order, without running it. The file must be a valid shell script.
End state: `bash -n /opt/answers/b4.sh` passes; the sequence is kubeadm upgrade, then kubelet, then restart, then uncordon, with the `apt-mark` steps around the package install.

**B5 · mock-a.** Create a ClusterRole `node-viewer` allowing `get`, `list`, `watch` on `nodes`, and bind it to the ServiceAccount `deployer` in `shop` with a **RoleBinding** in `shop`. Then write the output of `kubectl auth can-i list nodes --as=system:serviceaccount:shop:deployer` to `/opt/answers/b5.txt` and one line explaining the result.
End state: the file holds `no` and the explanation (nodes are cluster-scoped; a RoleBinding grants in a namespace only).

**B6 · mock-b.** A PV `pv-orphan` of 500Mi exists with reclaim policy `Retain` and status `Released`. Make it `Available` again without recreating it, and bind a new PVC `reuse` in namespace `data` to it.
End state: `kubectl get pv pv-orphan` is `Bound` to `data/reuse`.

**B7 · mock-b.** Create a StorageClass `fast` as the **default** class, provisioner `kubernetes.io/no-provisioner`, `volumeBindingMode: Immediate`. Then create a PVC `auto` in `data` with no class named and show which class it received.
End state: `kubectl get pvc -n data auto -o jsonpath='{.spec.storageClassName}'` is `fast`.

**B8 · mock-b.** Write the kubelet's configured `cgroupDriver` on `k8s-w1` and the container runtime's endpoint the kubelet uses to `/opt/answers/b8.txt`, one per line.
End state: the file has two lines, matching `/var/lib/kubelet/config.yaml` and the kubelet's `--container-runtime-endpoint` or `containerRuntimeEndpoint`.

---

## Set C — Services, networking and workloads (eight tasks, 40 min)

**C1 · mock-a.** Create a headless Service `api-headless` in `shop` for the `api` pods on port 8080. Write the DNS A records it returns to `/opt/answers/c1.txt`.
End state: `kubectl -n shop get svc api-headless -o jsonpath='{.spec.clusterIP}'` is `None`; the file lists two pod IPs.

**C2 · mock-a.** Create an Ingress `shop` with class `nginx` routing `shop.local/web` (prefix) to service `web:80` and `shop.local/api` (prefix) to `api:8080`.
End state: `kubectl -n shop get ingress shop -o jsonpath='{.spec.rules[0].http.paths[*].path}'` prints `/web /api`.

**C3 · mock-c.** In `apps`, create a Gateway `edge` on class `mock-gw` with an HTTPS listener on 443 using TLS secret `edge-tls` (create a self-signed one for `apps.local`), and an HTTPRoute `hello-tls` for `apps.local` to service `hello:80`.
End state: `kubectl -n apps get gateway edge -o jsonpath='{.spec.listeners[0].tls.certificateRefs[0].name}'` is `edge-tls`.

**C4 · mock-a.** Write a NetworkPolicy in `shop` that allows ingress to `db` pods on TCP 5432 **only** from `api` pods, and nothing else to `db`.
End state: from an `api` pod, `nc -zv -w2 db 5432` succeeds; from a `web` pod it fails.

**C5 · mock-a.** Deployment `web` must roll out a new image `nginx:1.27-alpine` with at most one pod unavailable and no surge, pause the rollout halfway, then resume it.
End state: `rollout history` shows the new revision; `maxSurge` is `0` and `maxUnavailable` is `1`.

**C6 · mock-c.** Create a Job `batch` in `apps` that runs `busybox:1.36` `echo done` to **five completions**, **two at a time**, with a backoff limit of 1.
End state: `kubectl -n apps get job batch -o jsonpath='{.spec.completions}/{.spec.parallelism}/{.spec.backoffLimit}'` is `5/2/1` and the Job completes.

**C7 · mock-c.** Create a DaemonSet `node-agent` in `apps` running `busybox:1.36` `sleep 3600` on **every** node including the control plane.
End state: `kubectl -n apps get ds node-agent` shows desired, current and ready equal to the node count.

**C8 · mock-c.** A Kustomize base exists at `/opt/mock/kustomize/base` (a Deployment `kz` and a Service). Create an overlay at `/opt/mock/kustomize/overlays/prod` that sets the namespace to `apps`, adds the common label `env=prod`, and sets replicas to 3. Apply it with `kubectl apply -k`.
End state: `kubectl -n apps get deploy kz -o jsonpath='{.spec.replicas}/{.metadata.labels.env}'` is `3/prod`.

---

Score each set out of eight with [`../solutions/MOCK-EXAM-2-SOLUTIONS.md`](../solutions/MOCK-EXAM-2-SOLUTIONS.md). Log the time per run; the third run is the number.
