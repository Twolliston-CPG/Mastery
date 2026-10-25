# Week 27 Labs

> **Figures:** one numbered mechanism figure per lab, with the spoken script, the numbers to own and
> the command that proves each badge, in [`FIGURES.md`](FIGURES.md) (27.2 to 27.6). Read a lab's figure
> before you start it; redraw it after.

> **Where you are running.** Every command in this file runs **on the nodes**, over
> `gcloud compute ssh k8s-cp --tunnel-through-iap` (and `k8s-w1`, `k8s-w2`), not on your laptop. The
> exam is the same: a terminal on a machine that is not yours, docs in a browser tab, no copy-paste
> from your notes. Type everything.

---

# Lab 1 — kubeadm init, Calico, join, and read what it wrote (3h)

## Part 0 — Book the exam

Do it now, before the first command. Pick a date at the end of week 30, a morning slot. The package
includes two killer.sh sessions and one retake; both are reasons to book early, not late. **Confirm
the exam version, the duration and the pass mark in the candidate handbook while you are there** and
write them in `progress.md`.

## Part 1 — What the node image already did

```bash
swapon --show                                   # empty: swap is off, kubelet refuses to start otherwise
lsmod | grep -E 'br_netfilter|overlay'
sysctl net.ipv4.ip_forward net.bridge.bridge-nf-call-iptables   # both 1
grep -n SystemdCgroup /etc/containerd/config.toml                # true: the kubelet's cgroup driver is systemd
apt-mark showhold                               # kubeadm kubelet kubectl, held at kubernetes_minor
kubeadm version -o short
systemctl status kubelet --no-pager | head -5   # activating (auto-restart): it crash-loops until init writes its config. Expected.
```

**Say why each one matters.** Swap: the kubelet's memory accounting assumes none. `br_netfilter` and
`ip_forward`: pod traffic crosses a bridge and is forwarded between interfaces; without them pods
reach nothing. `SystemdCgroup`: the kubelet and the runtime must agree on a cgroup driver, and
mismatch is BF-59. The held packages: an `apt upgrade` must never move Kubernetes a minor on its own.

## Part 2 — Initialise the control plane

```bash
CP_IP=$(hostname -I | awk '{print $1}')          # 10.10.0.x, the subnet address, not the external one
sudo kubeadm init \
  --apiserver-advertise-address="$CP_IP" \
  --pod-network-cidr=192.168.0.0/16 \
  --upload-certs | tee ~/kubeadm-init.log
```

Read the output top to bottom once. Preflight checks, certificate generation (one line per cert),
kubeconfig generation (four files), static pod manifests (four), the wait for the API server, the
`kubelet-config` and `kubeadm-config` ConfigMaps, the bootstrap token, the join command. That list
**is** the 25 percent domain.

```bash
mkdir -p "$HOME/.kube" && sudo cp /etc/kubernetes/admin.conf "$HOME/.kube/config" && sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"
kubectl get nodes          # NotReady: no CNI yet. That is correct and it is BF-62 in disguise
kubectl -n kube-system get pods   # coredns Pending, everything else Running
```

## Part 3 — Calico, through the operator

Calico, not the kind default, because it **enforces NetworkPolicy** (week 19 Lab 3 showed what a CNI
that does not do looks like) and because installing a CNI is on the blueprint.

```bash
CALICO=$(curl -s https://api.github.com/repos/projectcalico/calico/releases/latest | jq -r .tag_name)
kubectl create -f "https://raw.githubusercontent.com/projectcalico/calico/${CALICO}/manifests/tigera-operator.yaml"
cat <<EOF | kubectl apply -f -
apiVersion: operator.tigera.io/v1
kind: Installation
metadata: { name: default }
spec:
  calicoNetwork:
    ipPools:
      - cidr: 192.168.0.0/16        # must equal --pod-network-cidr
        encapsulation: VXLAN         # UDP 4789 between nodes; the lab firewall allows all intra-subnet traffic
        natOutgoing: Enabled
        nodeSelector: all()
EOF
watch kubectl get pods -n calico-system       # until calico-node and calico-kube-controllers are Running
kubectl get nodes                             # Ready
ls /etc/cni/net.d/                            # 10-calico.conflist: the file the kubelet was waiting for
```

## Part 4 — Join the workers

On the control plane:
```bash
kubeadm token create --print-join-command     # tokens expire after 24 h; a fresh one is always one command away
```
On `k8s-w1` and `k8s-w2`, paste it with `sudo`. Then from the control plane:
```bash
kubectl get nodes -o wide
kubectl label node k8s-w1 node-role.kubernetes.io/worker=   # cosmetic; the exam does not care
```

**What `join` did:** the worker downloaded the cluster CA through a token-authenticated, hash-verified
request (`--discovery-token-ca-cert-hash` is the pin), asked the API server to sign a kubelet client
certificate (TLS bootstrapping), wrote `/etc/kubernetes/kubelet.conf` and `/var/lib/kubelet/config.yaml`,
and started the kubelet. No manifests directory with content: workers run no static pods unless you
add one (week 28).

## Part 5 — Read what kubeadm wrote

```bash
sudo tree /etc/kubernetes                     # apt-get install -y tree if missing
sudo tree /var/lib/kubelet | head -30
```

| Path | Who reads it | What breaks if it is wrong |
|---|---|---|
| `/etc/kubernetes/manifests/*.yaml` | the kubelet, every few seconds | the component disappears; `crictl ps` shows it gone; BF-61 |
| `/etc/kubernetes/admin.conf` | you, through `~/.kube/config` | `kubectl` fails; nothing else does |
| `/etc/kubernetes/super-admin.conf` | nobody, by design | the break-glass identity (`system:masters`) kept out of daily use |
| `/etc/kubernetes/controller-manager.conf`, `scheduler.conf` | those two static pods | the pod runs but authenticates nowhere; BF-60 |
| `/etc/kubernetes/kubelet.conf` | the kubelet | node NotReady; `journalctl -u kubelet` says why |
| `/etc/kubernetes/pki/` | every component, by file path from the manifests | everything, selectively; Lab 2 |
| `/var/lib/kubelet/config.yaml` | the kubelet, at start | cgroup driver, staticPodPath, rotation; BF-59 |
| `/var/lib/kubelet/kubeadm-flags.env` | the kubelet systemd drop-in | the container runtime endpoint |
| `/var/lib/kubelet/pki/kubelet-client-current.pem` | the kubelet, rotated automatically | node auth fails a year later; Lab 2 |
| `/etc/cni/net.d/` | the kubelet, at pod creation | pods stuck ContainerCreating; BF-62 |
| `/var/lib/etcd/` | etcd | the cluster forgets everything; Lab 3 |

```bash
sudo cat /etc/kubernetes/manifests/kube-apiserver.yaml | grep -E -- '--(etcd|client-ca|tls|service-cluster|advertise|authorization|enable-admission)' 
kubectl -n kube-system get cm kubeadm-config -o yaml   # the ClusterConfiguration: what `kubeadm upgrade` will read
kubectl -n kube-system get cm kubelet-config -o yaml   # what every joining kubelet downloads
sudo crictl ps                                         # the four static pods as containers; the exam has crictl, not docker
```

**Tasks:**
1. Explain, from the apiserver manifest, how the API server finds etcd, which CA it trusts for
   clients, and where its own serving certificate is. Three flags.
2. `kubectl get pod -n kube-system kube-apiserver-k8s-cp -o yaml | grep -A3 ownerReferences` returns
   nothing. Why does the pod exist in the API at all? (It is a **mirror pod**: the kubelet creates it
   so you can see the static pod; deleting it does nothing, the kubelet recreates it.)
3. Delete the mirror pod and watch it come back. Then move the manifest out of the directory, watch
   the container stop in `crictl ps`, and move it back.

**Do it again, from memory, timed.** `kubeadm reset -f` on all three nodes (and `sudo rm -rf /etc/cni/net.d
$HOME/.kube`), then Parts 2 to 4 without this file open. Target: 25 minutes to three Ready nodes.

---

# Lab 2 — Certificates and kubeconfigs (3h)

## Part 1 — What exists, and when it expires

```bash
sudo kubeadm certs check-expiration
```

Read the table. Every leaf certificate kubeadm issued expires in **one year**; the three CAs
(`ca`, `etcd-ca`, `front-proxy-ca`) in **ten**. The table also tells you which certs are
**externally managed** (none here) and that `kubeadm upgrade` renews the leaves automatically, which is
why clusters upgraded at least yearly never hit this, and clusters that are not become BF-60.

```bash
sudo openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -text | grep -A1 'Subject Alternative Name'
sudo openssl x509 -in /etc/kubernetes/pki/apiserver-kubelet-client.crt -noout -subject   # O = kubeadm:cluster-admins (1.29+); CN names the client
sudo openssl x509 -in /etc/kubernetes/pki/etcd/server.crt -noout -subject -issuer         # issued by etcd-ca, not ca
```

**The SAN list is the exam question.** The API server's certificate must contain every name a client
will dial: the node name, the advertise IP, `kubernetes.default.svc.cluster.local`, the Service IP
(10.96.0.1), and any load-balancer name you want in front later. A missing SAN is
`x509: certificate is valid for ..., not <name>`; the fix is `kubeadm init phase certs apiserver`
with `--apiserver-cert-extra-sans`, or the `certSANs` list in the ClusterConfiguration.

## Part 2 — Renew one, then all

```bash
sudo kubeadm certs renew apiserver
sudo kubeadm certs check-expiration | grep ^apiserver
# The running API server still holds the OLD cert in memory. The kubelet restarts a static pod only
# when its manifest changes, so:
sudo mv /etc/kubernetes/manifests/kube-apiserver.yaml /tmp/ && sleep 20 && sudo mv /tmp/kube-apiserver.yaml /etc/kubernetes/manifests/
sudo crictl ps | grep apiserver          # a new container, seconds old
sudo kubeadm certs renew all             # then bounce all four the same way; admin.conf is renewed too, so re-copy it to ~/.kube/config
```

## Part 3 — A user, from a CSR

Kubernetes has no user objects. A user is **whatever the CA signed**: the CN is the username, the O
fields are the groups. This is the mechanism behind every `kubectl` you have ever run.

```bash
openssl genrsa -out jane.key 2048
openssl req -new -key jane.key -subj "/CN=jane/O=developers" -out jane.csr
cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata: { name: jane }
spec:
  request: $(base64 -w0 jane.csr)
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 86400          # one day; the signer may clamp it
  usages: [client auth]
EOF
kubectl get csr jane                                  # Pending
kubectl certificate approve jane
kubectl get csr jane -o jsonpath='{.status.certificate}' | base64 -d > jane.crt
openssl x509 -in jane.crt -noout -subject -dates

kubectl config set-credentials jane --client-key=jane.key --client-certificate=jane.crt --embed-certs=true
kubectl config set-context jane --cluster=kubernetes --user=jane --namespace=default
kubectl --context=jane get pods                       # Forbidden: authenticated as jane, authorised for nothing
kubectl create role pod-reader --verb=get,list --resource=pods
kubectl create rolebinding jane-pods --role=pod-reader --user=jane
kubectl --context=jane get pods                       # works
kubectl --context=jane auth whoami                    # jane, groups developers + system:authenticated
```

**Tasks:**
1. Build a second user in group `ops` and bind the group, not the user, to a ClusterRole `view`.
   Prove the binding is on the group by creating a third user in `ops` and watching it inherit access.
2. Write the kubeconfig for `jane` to a **separate file** with `--kubeconfig=jane.conf` on every
   command above, and say what the three sections of a kubeconfig are (clusters, users, contexts)
   and which one `current-context` points into.
3. The exam gives you a kubeconfig with several contexts and starts every task with
   `kubectl config use-context <name>`. Practise it until it is reflex: a task done in the wrong
   context scores zero.

## Part 4 — The kubelet's own certificates

```bash
sudo ls -l /var/lib/kubelet/pki/                       # kubelet-client-current.pem is a symlink to the newest rotated cert
sudo openssl x509 -in /var/lib/kubelet/pki/kubelet-client-current.pem -noout -subject -dates   # CN system:node:<name>, O system:nodes
grep -E 'rotateCertificates|serverTLSBootstrap' /var/lib/kubelet/config.yaml
```

`rotateCertificates: true` means the kubelet requests a new client cert through a CSR before expiry,
and the controller manager's CSR approver signs it because the request comes from a node identity.
This is why worker kubelets outlive the one-year leaf validity and the control-plane components do
not: the components use **files**, the kubelet uses **the API**. The kubelet's *serving* cert
(port 10250) is self-signed unless `serverTLSBootstrap` is on, which is why `kubectl logs` works
with `--insecure-skip-tls-verify` on the apiserver's side by default.

**Do it again, from memory, timed.** Part 3 for a new user, including the RoleBinding and the
`auth whoami` proof, in under 8 minutes.

---

# Lab 3 — etcd: snapshot, restore, prove it (3h)

## Part 1 — Talk to etcd with its own certificates

```bash
sudo apt-get install -y etcd-client                    # etcdctl and etcdutl; on the exam they are already present
sudo cat /etc/kubernetes/manifests/etcd.yaml | grep -E -- '--(data-dir|listen-client-urls|cert-file|key-file|trusted-ca-file|name|initial)'
```

Every `etcdctl` command needs **three** files and **one** endpoint, and all four come from that
manifest, which is the whole trick. Export them once per shell:

```bash
export ETCDCTL_API=3
export ETCDCTL_ENDPOINTS=https://127.0.0.1:2379
export ETCDCTL_CACERT=/etc/kubernetes/pki/etcd/ca.crt
export ETCDCTL_CERT=/etc/kubernetes/pki/etcd/server.crt
export ETCDCTL_KEY=/etc/kubernetes/pki/etcd/server.key
sudo -E etcdctl member list -w table
sudo -E etcdctl endpoint health
sudo -E etcdctl get /registry/namespaces/default --prefix --keys-only   # the API's objects, as keys
```

## Part 2 — Snapshot

```bash
kubectl create configmap before-snapshot --from-literal=when=before
sudo -E etcdctl snapshot save /opt/etcd-$(date +%F).db
sudo etcdutl snapshot status /opt/etcd-*.db -w table      # hash, revision, total keys, size
kubectl create configmap after-snapshot --from-literal=when=after    # this one must NOT survive the restore
```

## Part 3 — Restore to a new data directory

A restore does not write into the live data dir. It **creates a new one** and you repoint the static
pod at it. Pass the member identity flags so the restored member matches what the manifest expects;
without `--name` and `--initial-cluster` a restored member calls itself `default` and single-node
clusters usually survive that, but the exam and real clusters should not depend on usually.

```bash
NAME=$(sudo grep -- '--name=' /etc/kubernetes/manifests/etcd.yaml | sed 's/.*=//')
PEER=$(sudo grep -- '--initial-advertise-peer-urls=' /etc/kubernetes/manifests/etcd.yaml | sed 's/.*=//')
sudo etcdutl snapshot restore /opt/etcd-*.db \
  --name "$NAME" \
  --initial-cluster "$NAME=$PEER" \
  --initial-advertise-peer-urls "$PEER" \
  --data-dir /var/lib/etcd-restored
sudo ls /var/lib/etcd-restored/member/      # snap, wal

# Repoint the static pod: the hostPath volume named etcd-data
sudo sed -i 's#path: /var/lib/etcd$#path: /var/lib/etcd-restored#' /etc/kubernetes/manifests/etcd.yaml
sudo grep -n -A1 'name: etcd-data' /etc/kubernetes/manifests/etcd.yaml
```

The kubelet sees the manifest change and restarts etcd on the new directory. The API server loses
its etcd connection for a few seconds and reconnects; if `kubectl` stays dead for more than a
minute, bounce the apiserver manifest the Lab 2 way.

```bash
sudo crictl ps | grep etcd
kubectl get configmap before-snapshot after-snapshot
# before-snapshot: present.  after-snapshot: NotFound.  That is the proof the restore worked.
```

**Tasks:**
1. Explain why `--data-dir` must point at a directory that does not exist yet.
2. Where does `--data-dir` in the restore command have to match something in the manifest? (It does
   not. The manifest's `--data-dir` flag stays `/var/lib/etcd` *inside the container*; what you
   changed is the **hostPath** mounted there. Say this out loud; it is the step people get wrong.)
3. Take a snapshot **from your laptop's point of view**: the exam may hand you a cluster where etcd
   runs on a different host, with certificates in a different directory. Practise finding all four
   values from `ps aux | grep etcd` or the manifest in under a minute.
4. A snapshot is only a backup if it is **off the node**. `gcloud compute scp` it to your laptop, and say
   what you would do in production instead (a CronJob or a sidecar writing to object storage, with the
   certs mounted read-only).

**Do it again, from memory, timed.** Snapshot, create an object, restore, prove the object is gone.
Target: 10 minutes.

---

# Lab 4 — Upgrade one minor version (3h)

The nodes were installed one minor below current on purpose. Kubernetes upgrades move **one minor at
a time**, control plane **first**, then every worker, and kubeadm will refuse anything else.

## Part 1 — Version skew, before you touch anything

| Component | May lag the API server by | Why it matters today |
|---|---|---|
| kube-apiserver | the reference | upgrades first, always |
| controller-manager, scheduler | 0 minors (same as apiserver; may be 1 older during upgrade) | kubeadm moves them with the apiserver |
| kubelet | up to **3** minors older (since 1.28); never newer | a worker can be upgraded later; it must never be upgraded first |
| kubectl | ±1 minor | upgrade it with the kubelet |
| kubeadm | the target version | the first package you move |

## Part 2 — Control plane

```bash
# 1. Point apt at the next minor. The repo path IS the minor; this is the only edit.
CUR=$(kubeadm version -o short | cut -d. -f1-2 | tr -d v)        # e.g. 1.33
NEXT="1.$(( ${CUR#1.} + 1 ))"                                      # 1.34
sudo sed -i "s#core:/stable:/v${CUR}/#core:/stable:/v${NEXT}/#" /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
apt-cache madison kubeadm | head -3                                # the exact patch versions available

# 2. kubeadm first, by itself
sudo apt-mark unhold kubeadm && sudo apt-get install -y "kubeadm=${NEXT}.*" && sudo apt-mark hold kubeadm
kubeadm version -o short

# 3. Plan, read, apply
sudo kubeadm upgrade plan                                          # read the whole thing: components, the "you must manually upgrade kubelet" table, the API deprecations
sudo kubeadm upgrade apply "v$(kubeadm version -o short | tr -d v)" -y
# What just happened: pulled the new control-plane images, renewed every certificate, rewrote the four
# static pod manifests one at a time (etcd included), updated the kubeadm-config and kubelet-config
# ConfigMaps, re-applied the CoreDNS and kube-proxy addons.

# 4. Now the kubelet and kubectl on THIS node, with the node drained
kubectl drain k8s-cp --ignore-daemonsets
sudo apt-mark unhold kubelet kubectl && sudo apt-get install -y "kubelet=${NEXT}.*" "kubectl=${NEXT}.*" && sudo apt-mark hold kubelet kubectl
sudo systemctl daemon-reload && sudo systemctl restart kubelet
kubectl uncordon k8s-cp
kubectl get nodes                                                  # k8s-cp at the new version, workers still old. Allowed by the skew policy.
```

## Part 3 — Each worker

Run the drain from the **control plane**, the package commands on the **worker**:

```bash
# control plane
kubectl drain k8s-w1 --ignore-daemonsets --delete-emptydir-data   # pods move to w2; this is the only downtime, and only for singletons
# k8s-w1
sudo sed -i "s#core:/stable:/v${CUR}/#core:/stable:/v${NEXT}/#" /etc/apt/sources.list.d/kubernetes.list && sudo apt-get update
sudo apt-mark unhold kubeadm && sudo apt-get install -y "kubeadm=${NEXT}.*" && sudo apt-mark hold kubeadm
sudo kubeadm upgrade node                                          # workers: rewrites the local kubelet config from the cluster's ConfigMap, nothing else
sudo apt-mark unhold kubelet kubectl && sudo apt-get install -y "kubelet=${NEXT}.*" "kubectl=${NEXT}.*" && sudo apt-mark hold kubelet kubectl
sudo systemctl daemon-reload && sudo systemctl restart kubelet
# control plane
kubectl uncordon k8s-w1
kubectl get nodes
```

Repeat for `k8s-w2`. Run a 2-replica Deployment with a PodDisruptionBudget of `minAvailable: 1`
before you start and watch what the drain does with it (week 15 Lab 2, now on real nodes).

## Part 4 — HA control planes, as a reading

You will not build one on three VMs, but the exam asks you to understand the shape:

- **Stacked etcd:** every control-plane node runs etcd as a static pod; three nodes means three
  etcd members. Simpler, and one node loss takes a control plane and an etcd member together.
- **External etcd:** etcd on its own machines; control-plane nodes point at it. More machines, and
  losing a control-plane node costs no etcd member.
- Both need a **load balancer in front of 6443**, and its address is `--control-plane-endpoint`
  at `kubeadm init`. It cannot be added later without regenerating the API server certificate, which
  is why the flag is set on day one even for a single node.
- **Quorum:** etcd needs a majority: `(n/2)+1`. Three members tolerate one loss; five tolerate two;
  two members tolerate none and are worse than one.
- Additional control-plane nodes join with `kubeadm join --control-plane --certificate-key <key>`;
  the key is what `--upload-certs` printed in Lab 1 and it expires in two hours.

**Tasks:**
1. `kubeadm upgrade plan` printed a table of "components that must be manually upgraded". Which ones
   and why does kubeadm not do it?
2. A worker's kubelet is accidentally upgraded two minors *ahead* of the API server. What happens,
   and what is the only fix?
3. Say the order, out loud, as a list of seven steps: apt repo, kubeadm, plan, apply, drain, kubelet
   and kubectl, uncordon. Then the worker's six.

**Do it again, from memory, timed.** Not literally (you cannot un-upgrade), but write the fourteen
commands for a control plane and a worker on paper, from nothing, in under 6 minutes. On the exam this
task is worth a lot and is pure recall.

---

# Lab 5 — Break/Fix on nodes: the BF-59 to BF-64 set (4h)

The Gate 4 set broke **objects**. This set breaks **the machines the objects run on**, which is the
third of the troubleshooting domain kind could not teach. Scenarios are in
[`../../_shared/breakfix/08-cluster-nodes.md`](../../_shared/breakfix/08-cluster-nodes.md); the loop is
[Figure BF.0](../../_shared/breakfix/FIGURE.md).

| # | Scenario | Break | First command |
|---|---|---|---|
| BF-59 | Node NotReady: kubelet down, or wrong cgroup driver | stop the kubelet, or `cgroupDriver: cgroupfs` | `systemctl status kubelet`, `journalctl -u kubelet` |
| BF-60 | A component or user cannot authenticate: expired or mis-pathed cert | wrong port in a kubeconfig, or the scheduler's cert path | `kubectl config view`, `openssl x509 -dates` |
| BF-61 | API server gone: static pod manifest typo | a bad flag or bad YAML in `kube-apiserver.yaml` | `crictl ps -a`, `crictl logs`, `/var/log/pods/` |
| BF-62 | Pods stuck ContainerCreating: CNI not running | move the CNI config away, or scale Calico to zero | `describe pod` → "cni config uninitialized" |
| BF-63 | Node NotReady: containerd stopped, or disk pressure | `systemctl stop containerd`, or fill the disk | `describe node` → conditions |
| BF-64 | API server cannot reach etcd | wrong `--listen-client-urls` or a hostPath that does not exist | `crictl logs <etcd>`, `ss -lntp \| grep 2379` |

```bash
cat > ~/break-nodes.sh <<'SH'
#!/usr/bin/env bash
# Run on k8s-cp as root. A partner runs it without telling you which. Diagnose under a timer.
set -euo pipefail
W=k8s-w1
case $((RANDOM % 6)) in
  0) ssh "$W" "sudo sed -i 's/^cgroupDriver: systemd/cgroupDriver: cgroupfs/' /var/lib/kubelet/config.yaml && sudo systemctl restart kubelet" ;;
  1) sed -i 's#server: https://\(.*\):6443#server: https://\1:6444#' /etc/kubernetes/scheduler.conf ;;   # the scheduler pod restarts into a wall
  2) sed -i 's/--etcd-servers=https:\/\/127.0.0.1:2379/--etcd-servers=https:\/\/127.0.0.1:2379\n    - --this-flag-does-not-exist=true/' /etc/kubernetes/manifests/kube-apiserver.yaml ;;
  3) ssh "$W" "sudo mv /etc/cni/net.d/10-calico.conflist /root/ && sudo systemctl restart kubelet" ;;
  4) ssh "$W" "sudo systemctl stop containerd" ;;
  5) sed -i 's#path: /var/lib/etcd-restored#path: /var/lib/etcd-does-not-exist#' /etc/kubernetes/manifests/etcd.yaml ;;
esac
echo "something is broken. go."
SH
chmod +x ~/break-nodes.sh
```

(`ssh k8s-w1` from the control plane works because OS Login gives you the same identity on every
node; if it prompts, run the worker lines by hand in a second IAP session.)

**Rules:** snapshot nothing (these are VMs you can rebuild in 25 minutes; Lab 1 proved it), narrate
every step, time it, journal it with the Surprised line. Six scenarios, under 10 minutes each by the
end of Saturday. Then run the **week 15 `break.sh` on this cluster too**: the Gate 4 set on kubeadm
behaves exactly as it did on kind, which is the point.

**Do it again, from memory, timed.** Sunday: all six, cold, in a row. Record the total.
