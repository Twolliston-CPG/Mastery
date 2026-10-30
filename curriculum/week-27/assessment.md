# Week 27 Assessment

> Closed book, 30 min. Exam facts are planning estimates; confirm them in the candidate handbook.

## Part A (20 min)
1. List the phases of `kubeadm init` in order, and name the subcommand that runs one phase alone.
2. Four files under `/etc/kubernetes/`, four under `/etc/kubernetes/manifests/`, three under `/var/lib/kubelet/`. Name them and say who reads each.
3. Why is a freshly initialised node `NotReady`, and what file ends that state?
4. What is a mirror pod? What happens when you `kubectl delete` one?
5. What does `kubeadm join` verify about the cluster, and what does it receive in return?
6. Leaf certificates and CAs: how long does kubeadm issue each for, and what renews the leaves without you asking?
7. You renewed the API server certificate with `kubeadm certs renew apiserver` and nothing changed. Why, and what is the fix?
8. Name five entries that must be in the API server's SAN list.
9. A user in Kubernetes is defined by what, exactly? Where do groups come from?
10. The four values every `etcdctl` command needs, and where you find them in under a minute.
11. On restore, what does `--data-dir` point at, and what do you change in the static pod manifest? What do you **not** change?
12. State the version skew policy for kubelet and kubectl relative to the API server.
13. The seven control-plane upgrade commands, in order. Then the six for a worker.
14. What does `kubeadm upgrade apply` do to certificates, manifests and ConfigMaps?
15. Why must `--control-plane-endpoint` be set on day one, even for a single node?
16. etcd quorum for 3 and 5 members; why is 2 worse than 1?
17. A node is `NotReady`. First three commands, in order, and the condition names you read on the way.
18. `kubectl` returns `connection refused` on the control plane. Where do you read the API server's log when `kubectl logs` cannot?
19. Pods on one node sit in `ContainerCreating`. Which message in `describe pod` names it, and which two things could be missing?
20. Which failures in BF-59 to BF-64 does the kubelet's journal diagnose, and which need `crictl`?

## Part B — Write it (10 min)
21. The `kubeadm init` command for a control plane advertising `10.10.0.5` with Calico's default pod CIDR and certificate upload.
22. A `CertificateSigningRequest` for user `ops-1` in group `ops`, client auth, one day.
23. The `etcdctl snapshot save` command with all four values given as flags.
24. The `etcdutl snapshot restore` command for member `k8s-cp` with peer URL `https://10.10.0.5:2380` into `/var/lib/etcd-restored`.
25. The `drain` command for a worker that has DaemonSets and emptyDir volumes.

---

# Answer key

**A1.** preflight · certs · kubeconfig · kubelet-start · control-plane (the four manifests) · etcd ·
upload-config · upload-certs (with `--upload-certs`) · mark-control-plane · bootstrap-token · kubelet-finalize ·
addon (CoreDNS, kube-proxy). Any single one: `kubeadm init phase <name>`.

**A2.** `/etc/kubernetes/`: `admin.conf` (you), `super-admin.conf` (break-glass, nobody),
`controller-manager.conf` and `scheduler.conf` (those static pods), `kubelet.conf` (the kubelet).
`manifests/`: `etcd.yaml`, `kube-apiserver.yaml`, `kube-controller-manager.yaml`, `kube-scheduler.yaml`
(the kubelet polls the directory). `/var/lib/kubelet/`: `config.yaml` (kubelet settings),
`kubeadm-flags.env` (runtime endpoint for the systemd unit), `pki/kubelet-client-current.pem` (the
rotating client cert).

**A3.** No CNI: the kubelet reports `NetworkPluginNotReady` until a config file exists in
`/etc/cni/net.d/`. Installing the CNI (Calico writes `10-calico.conflist`) ends it.

**A4.** The API representation of a static pod, created by the kubelet so the pod is visible. Deleting
it removes the API object for a moment; the kubelet recreates it. The container never stops.

**A5.** It verifies the cluster CA against `--discovery-token-ca-cert-hash` (the pin) using a
token-authenticated discovery request, then performs TLS bootstrapping: a CSR for
`system:node:<name>` that the controller manager auto-approves. It receives the CA, a signed kubelet
client certificate, `kubelet.conf`, and the kubelet config from the `kubelet-config` ConfigMap.

**A6.** Leaves one year, CAs ten. `kubeadm upgrade apply` (and `upgrade node` for the kubelet config)
renews every leaf; a cluster upgraded at least yearly never expires.

**A7.** The file was rewritten but the running API server still holds the old certificate in memory.
The kubelet restarts a static pod only when its manifest changes: move `kube-apiserver.yaml` out of
`/etc/kubernetes/manifests/` and back (or edit it). Then re-copy `admin.conf` if you renewed `all`.

**A8.** The node hostname; the advertise IP; `kubernetes`, `kubernetes.default`,
`kubernetes.default.svc`, `kubernetes.default.svc.cluster.local`; the first Service IP (`10.96.0.1`);
plus any load-balancer name or extra SAN. Missing one gives "certificate is valid for ..., not ...".

**A9.** A certificate signed by the cluster CA (or a token/OIDC identity): the CN is the username,
each O field is a group. There is no user object. Groups also come from system membership:
`system:authenticated`, `system:nodes`, `system:masters`.

**A10.** `ETCDCTL_API=3`, the endpoint (`https://127.0.0.1:2379`), `--cacert /etc/kubernetes/pki/etcd/ca.crt`,
`--cert .../etcd/server.crt`, `--key .../etcd/server.key`. From `/etc/kubernetes/manifests/etcd.yaml`
(`--listen-client-urls`, `--trusted-ca-file`, `--cert-file`, `--key-file`) or `ps aux | grep etcd`.

**A11.** A directory that does not exist yet (for example `/var/lib/etcd-restored`). In the manifest
you change the **hostPath** of the `etcd-data` volume to that directory. You do not change the
container's `--data-dir` flag, which still says `/var/lib/etcd` inside the container.

**A12.** kubelet: up to three minors older than the API server (since 1.28), never newer. kubectl:
one minor either side. Control plane components move with the API server; one minor per upgrade.

**A13.** Control plane: (1) apt repo path to the next minor, `apt-get update` (2) unhold/install/hold
`kubeadm` (3) `kubeadm upgrade plan` (4) `kubeadm upgrade apply vX.Y.Z` (5) `kubectl drain <cp> --ignore-daemonsets`
(6) unhold/install/hold `kubelet kubectl`, `daemon-reload`, `restart kubelet` (7) `kubectl uncordon <cp>`.
Worker: (1) repo (2) kubeadm (3) `kubeadm upgrade node` (4) drain from the control plane (5) kubelet and
kubectl, restart (6) uncordon.

**A14.** Pulls new images; renews all leaf certificates; rewrites the four static pod manifests one at
a time; updates the `kubeadm-config` and `kubelet-config` ConfigMaps; re-applies the CoreDNS and
kube-proxy addons. It does **not** touch the kubelet or kubectl packages.

**A15.** The endpoint name goes into the API server certificate's SANs and into every kubeconfig.
Adding one later means regenerating the certificate and rewriting the kubeconfigs; setting it to a
DNS name on day one costs nothing and makes HA a join command later.

**A16.** `(n/2)+1`: 3 members need 2 (tolerate 1 loss); 5 need 3 (tolerate 2). With 2 members quorum is
2, so one loss stops the cluster: no more fault tolerance than one member, and double the chance of
losing one.

**A17.** `kubectl get nodes` → `kubectl describe node <n>` (Conditions: Ready, DiskPressure,
MemoryPressure, PIDPressure, and the last heartbeat) → SSH, `systemctl status kubelet` and
`journalctl -u kubelet`. Then `systemctl status containerd`, `df -h`.

**A18.** `sudo crictl ps -a` to find the exited apiserver container, `sudo crictl logs <id>`, or the
files under `/var/log/pods/kube-system_kube-apiserver-<node>_*/`. The kubelet's journal says whether
it could parse the manifest at all.

**A19.** `network plugin is not ready: cni config uninitialized` (or `failed to find network info`).
Missing: the config file in `/etc/cni/net.d/` on that node, or the CNI's pod (Calico's `calico-node`)
not running on that node.

**A20.** Journal: BF-59 (kubelet stopped or cgroup mismatch), BF-63 (runtime unreachable), and the
parse half of BF-61. `crictl`: the flag half of BF-61, BF-64 (etcd's own log), and anything where the
apiserver container exists but exits. BF-60 is `kubectl config view` plus `openssl x509 -dates`; BF-62
is `describe pod` plus `ls /etc/cni/net.d`.

**B21.**
```bash
sudo kubeadm init --apiserver-advertise-address=10.10.0.5 --pod-network-cidr=192.168.0.0/16 --upload-certs
```

**B22.**
```yaml
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata: { name: ops-1 }
spec:
  request: <base64 of a CSR with subject /CN=ops-1/O=ops>
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 86400
  usages: [client auth]
```

**B23.**
```bash
ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save /opt/etcd-backup.db
```

**B24.**
```bash
etcdutl snapshot restore /opt/etcd-backup.db --name k8s-cp \
  --initial-cluster k8s-cp=https://10.10.0.5:2380 --initial-advertise-peer-urls https://10.10.0.5:2380 \
  --data-dir /var/lib/etcd-restored
```

**B25.**
```bash
kubectl drain k8s-w1 --ignore-daemonsets --delete-emptydir-data
```
