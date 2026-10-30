# Week 27 Solutions

> Worked commands for every lab task, with what a correct run prints. Everything runs on the nodes
> over IAP SSH. Versions are whatever `kubernetes_minor` installed; nothing here is pinned.

---

## Lab 1 — kubeadm init, Calico, join

### Task 1 — three flags in the apiserver manifest

```bash
sudo grep -E -- '--(etcd-servers|etcd-cafile|etcd-certfile|client-ca-file|tls-cert-file|tls-private-key-file)' /etc/kubernetes/manifests/kube-apiserver.yaml
```
```
    - --client-ca-file=/etc/kubernetes/pki/ca.crt
    - --etcd-cafile=/etc/kubernetes/pki/etcd/ca.crt
    - --etcd-certfile=/etc/kubernetes/pki/apiserver-etcd-client.crt
    - --etcd-servers=https://127.0.0.1:2379
    - --tls-cert-file=/etc/kubernetes/pki/apiserver.crt
    - --tls-private-key-file=/etc/kubernetes/pki/apiserver.key
```
- **Finds etcd:** `--etcd-servers`, and authenticates to it with `apiserver-etcd-client.crt`, signed by the **etcd CA**, not the cluster CA.
- **Trusts clients with:** `--client-ca-file`: any certificate signed by `ca.crt` is an authenticated user (CN) in groups (O).
- **Serves with:** `--tls-cert-file` / `--tls-private-key-file`, the certificate whose SANs Lab 2 inspects.

### Task 2 — why the mirror pod exists

```bash
kubectl -n kube-system get pod kube-apiserver-k8s-cp -o jsonpath='{.metadata.annotations.kubernetes\.io/config\.source}{"\n"}{.metadata.annotations.kubernetes\.io/config\.mirror}{"\n"}'
```
```
file
<hash>
```
`config.source: file` is the tell. The kubelet creates a mirror object so the API can show a pod it did
not schedule. No ReplicaSet, no Deployment, no owner.

### Task 3 — delete the mirror, move the manifest

```bash
kubectl -n kube-system delete pod kube-apiserver-k8s-cp     # returns; kubectl may hang a second
kubectl -n kube-system get pod kube-apiserver-k8s-cp         # back, AGE a few seconds, same container
sudo crictl ps | grep kube-apiserver                          # container ID unchanged: nothing restarted

sudo mv /etc/kubernetes/manifests/kube-apiserver.yaml /tmp/
sleep 15; sudo crictl ps | grep kube-apiserver               # gone
kubectl get nodes                                             # The connection to the server 10.10.0.5:6443 was refused
sudo mv /tmp/kube-apiserver.yaml /etc/kubernetes/manifests/
sleep 20; kubectl get nodes                                   # back
```

### The from-memory rebuild

```bash
# all three nodes
sudo kubeadm reset -f && sudo rm -rf /etc/cni/net.d "$HOME/.kube" && sudo iptables -F && sudo iptables -t nat -F
# then Parts 2 to 4. A correct run ends with:
kubectl get nodes
# NAME     STATUS   ROLES           AGE   VERSION
# k8s-cp   Ready    control-plane   9m    v1.NN.x
# k8s-w1   Ready    <none>          3m    v1.NN.x
# k8s-w2   Ready    <none>          2m    v1.NN.x
```

---

## Lab 2 — Certificates and kubeconfigs

### Task 1 — a group binding

```bash
for u in ops-1 ops-2; do
  openssl genrsa -out $u.key 2048 && openssl req -new -key $u.key -subj "/CN=$u/O=ops" -out $u.csr
  kubectl apply -f - <<EOF
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata: { name: $u }
spec: { request: $(base64 -w0 $u.csr), signerName: kubernetes.io/kube-apiserver-client, expirationSeconds: 86400, usages: [client auth] }
EOF
  kubectl certificate approve $u
  kubectl get csr $u -o jsonpath='{.status.certificate}' | base64 -d > $u.crt
  kubectl config set-credentials $u --client-key=$u.key --client-certificate=$u.crt --embed-certs=true
  kubectl config set-context $u --cluster=kubernetes --user=$u
done
kubectl create clusterrolebinding ops-view --clusterrole=view --group=ops
kubectl --context=ops-1 get pods -A | head -3       # works
kubectl --context=ops-2 get pods -A | head -3       # works: never named in any binding; the group was
kubectl --context=ops-2 auth whoami
```
```
ATTRIBUTE   VALUE
Username    ops-2
Groups      [ops system:authenticated]
```

### Task 2 — a separate kubeconfig, and the three sections

```bash
kubectl config set-cluster kubernetes --kubeconfig=jane.conf --server=https://10.10.0.5:6443 --certificate-authority=/etc/kubernetes/pki/ca.crt --embed-certs=true
kubectl config set-credentials jane --kubeconfig=jane.conf --client-key=jane.key --client-certificate=jane.crt --embed-certs=true
kubectl config set-context jane --kubeconfig=jane.conf --cluster=kubernetes --user=jane --namespace=default
kubectl config use-context jane --kubeconfig=jane.conf
kubectl --kubeconfig=jane.conf get pods
kubectl config view --kubeconfig=jane.conf --minify     # clusters[], users[], contexts[], current-context
```
`current-context` names an entry in `contexts`; each context names one cluster and one user.

### Task 3 — the context reflex

```bash
kubectl config get-contexts        # the * marks current
kubectl config use-context jane && kubectl get pods && kubectl config use-context kubernetes-admin@kubernetes
```
On the exam every task statement begins with the context to use. Type it before reading the rest of the task.

### The kubelet's certificate

```bash
sudo openssl x509 -in /var/lib/kubelet/pki/kubelet-client-current.pem -noout -subject -dates
```
```
subject=O = system:nodes, CN = system:node:k8s-w1
notBefore=...
notAfter=...   (one year out; a new CSR appears in `kubectl get csr` as it approaches)
```

---

## Lab 3 — etcd

### Task 1 — why the directory must not exist

`snapshot restore` writes a complete new member (WAL and snap directories, member ID, cluster ID)
and refuses to write into a populated directory, so a restore can never half-overwrite the live
data. The live `/var/lib/etcd` is untouched; you switch to the new one by changing the mount.

### Task 2 — what matches what

```bash
sudo grep -E -- '--data-dir|path: /var/lib/etcd' /etc/kubernetes/manifests/etcd.yaml
```
```
    - --data-dir=/var/lib/etcd          # inside the container: unchanged
      path: /var/lib/etcd-restored      # on the host: changed
```
The hostPath is mounted at the container path; the flag names the container path.

### Task 3 — find the four values from a process list

```bash
ps aux | grep -o -E -- '--(listen-client-urls|trusted-ca-file|cert-file|key-file)=[^ ]+' | sort -u
```
```
--cert-file=/etc/kubernetes/pki/etcd/server.crt
--key-file=/etc/kubernetes/pki/etcd/server.key
--listen-client-urls=https://127.0.0.1:2379,https://10.10.0.5:2379
--trusted-ca-file=/etc/kubernetes/pki/etcd/ca.crt
```

### Task 4 — off the node, and in production

```bash
# laptop
gcloud compute scp k8s-cp:/opt/etcd-*.db ./ --tunnel-through-iap
```
Production: a CronJob on the control plane (or a sidecar) running `etcdctl snapshot save` with the
certificate directory mounted read-only and the output pushed to versioned object storage; retention
by lifecycle rule; a restore drill on a schedule, because an untested backup is a guess.

### The proof, as printed

```bash
kubectl get cm before-snapshot after-snapshot
```
```
NAME              DATA   AGE
before-snapshot   1      14m
Error from server (NotFound): configmaps "after-snapshot" not found
```

---

## Lab 4 — Upgrade

### Task 1 — the manual table

`kubeadm upgrade plan` prints:
```
Components that must be manually upgraded after you have upgraded the control plane with 'kubeadm upgrade apply':
COMPONENT   NODE     CURRENT   TARGET
kubelet     k8s-cp   v1.N.x    v1.N+1.y
kubelet     k8s-w1   ...
```
The kubelet is a host package managed by apt, not a Kubernetes object; kubeadm cannot replace a binary
on a node it is not running on, and on the control plane it will not restart the process that is
running it.

### Task 2 — a kubelet ahead of the API server

The kubelet registers, then fails API calls it makes with fields or versions the older server does
not know; the node flaps or stays NotReady and the kubelet journal shows `the server could not find
the requested resource` style errors. The only fix is to **downgrade the kubelet** to the API server's
minor (or at most ahead by zero): `apt-get install kubelet=<old> --allow-downgrades`. Upgrading the
control plane two minors in one jump is not allowed either.

### Task 3 — the order, as spoken

Control plane: repo · kubeadm · plan · apply · drain · kubelet+kubectl · uncordon.
Worker: repo · kubeadm · `upgrade node` · drain (from cp) · kubelet+kubectl · uncordon (from cp).

### The PDB during the drain

```bash
kubectl create deploy web --image=nginx:alpine --replicas=2
kubectl create pdb web --selector=app=web --min-available=1
kubectl drain k8s-w1 --ignore-daemonsets --delete-emptydir-data
```
```
evicting pod default/web-xxxxx
pod/web-xxxxx evicted
```
Both replicas were on w1? The second eviction waits until the first replacement is Ready on w2, then
proceeds. With `--replicas=1` and the same PDB, the drain prints
`Cannot evict pod as it would violate the pod's disruption budget` forever: week 15 Lab 2, now real.

---

## Lab 5 — Break/Fix on nodes

Each diagnosis, in the form the journal expects. Times are targets.

| BF | What you see | What proves it | Fix | Target |
|---|---|---|---|---|
| 59 | `k8s-w1 NotReady` | `journalctl -u kubelet`: `cgroup driver ... is different from` or `kubelet.service: inactive` | set `cgroupDriver: systemd`, `systemctl restart kubelet` | 5 min |
| 60 | scheduler pod `CrashLoopBackOff`, new pods Pending | `crictl logs <scheduler>`: `dial tcp ...:6444: connect: connection refused`; `grep server /etc/kubernetes/scheduler.conf` | fix the port, bounce the scheduler manifest | 8 min |
| 61 | `kubectl`: connection refused | `crictl ps -a`: apiserver exited; `crictl logs`: `unknown flag: --this-flag-does-not-exist` | remove the line; the kubelet restarts it | 6 min |
| 62 | new pods on w1 `ContainerCreating` | `describe pod`: `cni config uninitialized`; `ls /etc/cni/net.d` empty on w1 | restore the conflist (or `kubectl -n calico-system delete pod -l k8s-app=calico-node --field-selector spec.nodeName=k8s-w1` to regenerate) | 6 min |
| 63 | `k8s-w1 NotReady` | `journalctl -u kubelet`: `failed to get runtime status ... connection refused`; `systemctl status containerd`: inactive | `systemctl start containerd` | 4 min |
| 64 | `kubectl`: connection refused; apiserver logs `etcdserver: ... connection refused` | `crictl ps -a`: etcd exiting; `crictl logs <etcd>`: `cannot access data directory` | fix the hostPath | 8 min |

The Sunday total for all six cold: under 40 minutes.
