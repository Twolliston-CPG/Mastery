# Week 27 Labs

> **Figures:** one numbered mechanism figure per lab, with the spoken script, the numbers to own and
> the command that proves each badge, in [`FIGURES.md`](FIGURES.md) (27.2 to 27.10; the last four belong to the Go deeper labs at the end of this file). Read a lab's figure
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

## Lab 1, the hard way

[`HARD-WAY.md`](HARD-WAY.md) is the same cluster with no kubeadm: every certificate, kubeconfig and
unit written by hand, with a line per step on what kubeadm hid. Six hours, once, for the ladder
(lifecycle and authn at rung 3), not for the exam. Figure 27.10 is its certificate fan-out.

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

---

# Go deeper — The kubelet, every ten seconds (3h · ladder: kubelet and runtime, rung 3; resources and scale, rung 3)

> Optional inside the week; mandatory for the ladder in [`KUBERNETES-MASTERY.md`](../../../KUBERNETES-MASTERY.md).
> Everything here runs **on a worker** as root. Figure 27.7.

The kubelet is a loop: watch the API for pods bound to this node, make the runtime match, report
back. Every ten seconds it posts node status; every second its pod lifecycle event generator
relists the runtime; every housekeeping tick it checks thresholds. This lab makes each of those
visible in a file or a log line.

## Part 1 — The config, and where it came from

```bash
sudo cat /var/lib/kubelet/config.yaml                              # what THIS kubelet started with
kubectl -n kube-system get cm kubelet-config -o yaml | head -40    # what kubeadm wrote for every node
kubectl get --raw "/api/v1/nodes/$(hostname)/proxy/configz" | jq . | head -60   # what it is running with now
```

Three views of one config: the file on disk, the ConfigMap a joining node downloads, the live
values. `kubeadm upgrade` rewrites the ConfigMap; `kubeadm upgrade node` pulls it down; the file is
what survives a reboot. The fields this lab touches: `cgroupDriver`, `evictionHard`,
`imageGCHighThresholdPercent`, `imageGCLowThresholdPercent`, `nodeStatusUpdateFrequency` (10s),
`staticPodPath`.

## Part 2 — cgroups v2 for one pod

```bash
kubectl run burst --image=nginx:alpine --overrides="{\"spec\":{\"nodeName\":\"$(hostname)\"}}" \
  --requests=cpu=100m,memory=64Mi --limits=cpu=200m,memory=128Mi
UID=$(kubectl get pod burst -o jsonpath='{.metadata.uid}' | tr - _)
kubectl get pod burst -o jsonpath='{.status.qosClass}{"\n"}'       # Burstable: limits ≠ requests
cd /sys/fs/cgroup/kubepods.slice/kubepods-burstable.slice/kubepods-burstable-pod${UID}.slice && ls
cat cpu.max          # "20000 100000": 200m = 20 ms of every 100 ms period. That IS the limit
cat cpu.weight       # from the request: 100m → a weight the scheduler of the kernel honours under contention
cat memory.max       # 134217728 = 128Mi. Over it: the OOM killer, exit 137, figure 14.5 badge ⑥
cat memory.current   # what it uses now
cat cpu.stat         # nr_throttled / throttled_usec: how often the quota bit
cat memory.events    # oom_kill count: the evidence after a kill
ls cri-containerd-*.scope   # one cgroup per container inside the pod's
```

```bash
# the three QoS directories, and which pods land where
ls /sys/fs/cgroup/kubepods.slice/                         # kubepods-besteffort.slice  kubepods-burstable.slice  kubepods-pod<uid>.slice (Guaranteed, at the top level)
```

**Say it.** Requests become `cpu.weight` and the scheduler's reservation; limits become `cpu.max`
and `memory.max`. CPU over the limit is throttled (`nr_throttled` climbs); memory over the limit is
killed (`oom_kill` climbs). The QoS class is the directory the slice lives in, and the eviction
order in Part 3 reads it.

## Part 3 — Eviction, by threshold

```bash
# Lower the disk threshold so you can hit it without filling 30 GB
sudo python3 - <<'EOF'
import yaml; p="/var/lib/kubelet/config.yaml"; c=yaml.safe_load(open(p))
c["evictionHard"]={"nodefs.available":"60%","memory.available":"100Mi"}   # 60% free is the floor: easy to breach
yaml.safe_dump(c,open(p,"w"))
EOF
sudo systemctl restart kubelet
df -h /var/lib/kubelet                                    # how far from 60% free you are
sudo fallocate -l 8G /var/tmp/fill                        # one or two of these; nodefs is the root fs here
watch -n2 'kubectl describe node $(hostname) | grep -A5 Conditions; kubectl get pods -A --field-selector spec.nodeName=$(hostname)'
kubectl get events --field-selector reason=Evicted -A     # "The node was low on resource: ephemeral-storage"
```

**Who goes first.** BestEffort pods, then Burstable pods using more than they requested, ranked by
how far over; Guaranteed pods last, and only if they exceed their requests, which by definition
they cannot for memory. Read the eviction event's pod name against the three directories from
Part 2 and say why that one. Then clean up: `rm /var/tmp/fill`, restore `evictionHard`, restart.

## Part 4 — Image garbage collection

```bash
sudo crictl images | wc -l
sudo python3 - <<'EOF'
import yaml; p="/var/lib/kubelet/config.yaml"; c=yaml.safe_load(open(p))
c["imageGCHighThresholdPercent"]=30; c["imageGCLowThresholdPercent"]=20; c["imageMinimumGCAge"]="30s"
yaml.safe_dump(c,open(p,"w"))
EOF
sudo systemctl restart kubelet
for i in 1 2 3 4 5; do sudo crictl pull "python:3.12.$i-slim" ; done   # unused images, several hundred MB
sudo journalctl -u kubelet --since '5 min ago' | grep -i 'image garbage\|imageGC\|Removing image'
sudo crictl images | wc -l                                # fewer: only images no container uses are candidates
```

Defaults are 85 percent high, 80 percent low, and a two-minute minimum age. GC removes images no
container references, oldest first, until usage is below the low mark. Restore the three fields.

## Part 5 — The PLEG

```bash
sudo journalctl -u kubelet -o cat | grep -i pleg | head   # at the default verbosity, only health lines
# raise verbosity for a minute: add --v=4 to KUBELET_EXTRA_ARGS in /etc/default/kubelet, restart, then
sudo journalctl -u kubelet -f -o cat | grep -E 'GenericPLEG|Relist'        # a relist every second
```

The pod lifecycle event generator asks the runtime "what containers exist and in what state"
(`pkg/kubelet/pleg`), diffs against last time, and emits events that drive the sync loop. If a
relist takes longer than three minutes (a hung runtime, thousands of containers) the kubelet
reports *PLEG is not healthy* and the node goes NotReady with every pod still running. The
evented PLEG enhancement (KEP-3386) replaces polling with CRI events so that cost no longer scales
with the number of containers. Put `--v=2` back.

## Part 6 — A static pod and its mirror

```bash
sudo tee /etc/kubernetes/manifests/static-web.yaml >/dev/null <<EOF
apiVersion: v1
kind: Pod
metadata: { name: static-web }
spec:
  containers: [{ name: web, image: nginx:alpine }]
EOF
kubectl get pod static-web-$(hostname) -o yaml | grep -E 'config\.(mirror|source)|ownerReferences' -A1
kubectl delete pod static-web-$(hostname) && sleep 3 && kubectl get pod static-web-$(hostname)   # back: the kubelet re-creates the mirror
sudo rm /etc/kubernetes/manifests/static-web.yaml && sleep 5 && kubectl get pod static-web-$(hostname)   # gone: the manifest was the truth
```

`staticPodPath` is set on workers too. The API object is a **mirror** the kubelet publishes so you
can see it; deleting it changes nothing. The control plane itself (Lab 1 Part 5) is four of these.

**Do it again, from memory, timed.** Parts 2 and 6 cold: the five cgroup files for a pod you just
created, and a static pod with its mirror deleted and back. Target: 12 minutes.

---

# Go deeper — A CNI plugin in forty lines of bash (2h · ladder: networking datapath, rung 4)

> Optional inside the week; mandatory for the ladder. On **one worker**, `k8s-w2`, with Calico left
> running but out-ranked on that node; everything is reversible with one `rm`. Figure 27.8.

A CNI plugin is an executable. The runtime runs it with a handful of environment variables and a
JSON document on stdin, and expects a JSON document on stdout. That is the whole contract, and the
point of writing one is that "the network plugin" stops being a thing that happens to you.

## Part 1 — The contract

From the [CNI specification](https://github.com/containernetworking/cni/blob/main/SPEC.md):

| Input | Meaning |
|---|---|
| `CNI_COMMAND` | `ADD`, `DEL`, `CHECK`, or `VERSION` |
| `CNI_CONTAINERID` | the sandbox id |
| `CNI_NETNS` | the network namespace path, `/var/run/netns/cni-…` |
| `CNI_IFNAME` | the interface to create inside it, `eth0` |
| `CNI_PATH` | where plugins live, `/opt/cni/bin` |
| stdin | the config file from `/etc/cni/net.d/`, with `cniVersion`, `name`, `type` and anything else you put there |
| stdout | on `ADD`, a result: `interfaces`, `ips`, `routes`; on error, `{"code":…,"msg":…}` |

containerd loads the **lexically first** file in `/etc/cni/net.d/`, so `00-bashcni.conf` beats
Calico's `10-calico.conflist` for every pod created after it appears, on that node only.

## Part 2 — The plugin

```bash
sudo apt-get install -y jq
sudo tee /opt/cni/bin/bashcni >/dev/null <<'EOF'
#!/usr/bin/env bash
# bashcni: a CNI plugin. ADD, DEL, CHECK, VERSION. One /24 per node, allocations kept in a file.
set -euo pipefail
exec 3>&1                                   # fd 3 is the protocol; stdout is noisy
exec 1>>/var/log/bashcni.log 2>&1
conf=$(cat)
echo "$(date +%T) ${CNI_COMMAND} ${CNI_CONTAINERID:-} ${CNI_NETNS:-} ${CNI_IFNAME:-}"
subnet=$(jq -r .subnet <<<"$conf")          # e.g. 10.244.2.0/24
base=${subnet%.*}                           # 10.244.2
gw="${base}.1"
bridge=bashcni0
db=/var/lib/bashcni/allocated
mkdir -p "$(dirname "$db")" && touch "$db"
case "$CNI_COMMAND" in
  VERSION) echo '{"cniVersion":"1.0.0","supportedVersions":["0.4.0","1.0.0"]}' >&3 ;;
  CHECK)   : ;;
  ADD)
    if ! ip link show "$bridge" >/dev/null 2>&1; then
      ip link add "$bridge" type bridge && ip addr add "${gw}/24" dev "$bridge" && ip link set "$bridge" up
      iptables -t nat -A POSTROUTING -s "$subnet" ! -o "$bridge" -j MASQUERADE   # pods reach the internet as the node
    fi
    host=$(printf 'veth%s' "${CNI_CONTAINERID:0:8}")
    ns=$(basename "$CNI_NETNS")
    for i in $(seq 2 254); do grep -q " ${base}.${i}$" "$db" || { ip="${base}.${i}"; break; }; done
    echo "${CNI_CONTAINERID} ${ip}" >>"$db"
    ip link add "$host" type veth peer name "$CNI_IFNAME" netns "$ns"
    ip link set "$host" master "$bridge" up
    ip -n "$ns" addr add "${ip}/24" dev "$CNI_IFNAME"
    ip -n "$ns" link set "$CNI_IFNAME" up && ip -n "$ns" link set lo up
    ip -n "$ns" route add default via "$gw"
    mac=$(ip -n "$ns" -j link show "$CNI_IFNAME" | jq -r '.[0].address')
    printf '{"cniVersion":"1.0.0","interfaces":[{"name":"%s","mac":"%s","sandbox":"%s"}],"ips":[{"address":"%s/24","gateway":"%s","interface":0}],"routes":[{"dst":"0.0.0.0/0"}]}\n' \
      "$CNI_IFNAME" "$mac" "$CNI_NETNS" "$ip" "$gw" >&3 ;;
  DEL)
    host=$(printf 'veth%s' "${CNI_CONTAINERID:0:8}")
    ip link del "$host" 2>/dev/null || true
    sed -i "/^${CNI_CONTAINERID} /d" "$db" ;;
  *) echo "{\"code\":4,\"msg\":\"unsupported CNI_COMMAND ${CNI_COMMAND}\"}" >&3; exit 1 ;;
esac
EOF
sudo chmod +x /opt/cni/bin/bashcni
sudo tee /etc/cni/net.d/00-bashcni.conf >/dev/null <<'EOF'
{ "cniVersion": "1.0.0", "name": "bashcni", "type": "bashcni", "subnet": "10.244.2.0/24" }
EOF
```

Read it once as the runtime would: `VERSION` answers what you speak; `ADD` builds a bridge on
first use, picks the first free address in the node's range, creates a veth pair with one end
already inside the pod's namespace, addresses it, routes it, and reports; `DEL` undoes the pair
and frees the address. Forty lines, no IPAM daemon, no datastore, no policy.

## Part 3 — Watch the kubelet call it

```bash
# from k8s-cp: a pod pinned to the worker that now has the plugin
kubectl run bashpod --image=busybox:1.36 --overrides='{"spec":{"nodeName":"k8s-w2"}}' --command -- sleep 3600
kubectl get pod bashpod -o wide            # an address from 10.244.2.0/24, not Calico's range
```

```bash
# on k8s-w2
sudo tail /var/log/bashcni.log             # ADD, with the container id and the netns path
sudo journalctl -u containerd --since '2 min ago' | grep -i cni | tail -3
ip addr show bashcni0; bridge link
ping -c2 "$(kubectl get pod bashpod -o jsonpath='{.status.podIP}')"      # from the node: through the bridge
kubectl exec bashpod -- wget -qO- -T3 http://1.1.1.1 >/dev/null && echo "internet: via MASQUERADE"
```

The kubelet asked containerd for a sandbox; containerd created the namespace, read the first config
file, ran `/opt/cni/bin/bashcni` with `CNI_COMMAND=ADD`, and put the result's address in the pod
status. Nothing in the API server knows or cares which plugin did it.

## Part 4 — Cross-node, and why it fails here

```bash
# on k8s-w1 (still Calico): a static route for the bash range via the node that owns it
sudo ip route add 10.244.2.0/24 via "$(getent hosts k8s-w2 | awk '{print $1}')"
ping -c2 -W2 <bashpod ip>                   # fails
sudo tcpdump -ni any host <bashpod ip>     # on k8s-w2: nothing arrives
```

The packet leaves `k8s-w1` with destination `10.244.2.x`. The VPC routes it to `k8s-w2` only if the
VPC has a route for that prefix, and the reply would leave `k8s-w2` with a **source** address that is
not the VM's; GCE's anti-spoofing drops that unless IP forwarding is enabled on the instance, which
the lab nodes deliberately do not have. The same rule exists on every cloud. That failure is the
reason overlays exist: the pod packet is wrapped in a UDP packet whose source and destination are
the nodes, and the VPC sees only node traffic.

**Optional, 30 minutes: the overlay by hand.** On both workers, a VXLAN device that does what
Calico's VXLAN mode and flannel do, with static neighbour and forwarding entries instead of a daemon:

```bash
# on each worker; SELF and PEER are node addresses, PEER_MAC is the other node's vxlan0 MAC (read it there first)
sudo ip link add vxlan0 type vxlan id 42 dstport 4789 local "$SELF" dev "$(ip -o -4 route show default | awk '{print $5}')" nolearning
sudo ip link set vxlan0 up && cat /sys/class/net/vxlan0/address        # give this MAC to the other node
sudo ip addr add "${MY_POD_BASE}.0/32" dev vxlan0                       # 10.244.2.0/32 on w2, Calico's range base on w1
sudo ip neigh add "${PEER_POD_BASE}.0" lladdr "$PEER_MAC" dev vxlan0 nud permanent
sudo bridge fdb add "$PEER_MAC" dev vxlan0 dst "$PEER"
sudo ip route add "${PEER_POD_BASE}.0/24" via "${PEER_POD_BASE}.0" dev vxlan0 onlink
```

Then the ping works, and `tcpdump -ni any udp port 4789` on either node shows the wrapped packet.
The firewall rule `lab-allow-k8s-internal` already admits UDP 4789; that line in `kubeadm.tf` is
this lab.

## Part 5 — Put Calico back, and say what it adds

```bash
sudo rm /etc/cni/net.d/00-bashcni.conf           # Calico's conflist is first again
kubectl delete pod bashpod                        # DEL runs; the veth and the allocation go
sudo ip link del bashcni0; sudo ip link del vxlan0 2>/dev/null; sudo iptables -t nat -D POSTROUTING -s 10.244.2.0/24 ! -o bashcni0 -j MASQUERADE
kubectl run calicopod --image=busybox:1.36 --overrides='{"spec":{"nodeName":"k8s-w2"}}' --command -- sleep 60
kubectl get pod calicopod -o wide                 # back in Calico's range
```

What forty lines did not do: hand out ranges to nodes (IPAM across the cluster), tell other nodes
where each range lives (routing, by BGP or VXLAN), rewrite anything when a node dies, or enforce
`NetworkPolicy` (Felix programs iptables or eBPF per pod interface). A CNI plugin connects a pod
to a network; a network policy engine decides what crosses it. Week 19 Lab 3's lesson, that the
kind default CNI applies policies cleanly and enforces nothing, is this distinction.

**Do it again, from memory, timed.** The script, from a blank file, with the pod reachable from the
node. Target: 20 minutes.

---

# Go deeper — etcd under the cluster (3h · ladder: etcd and state, rung 3)

> Optional inside the week; mandatory for the ladder. On **k8s-cp** as root, with Lab 3's `ETCDCTL_*`
> exports in the shell. Figure 27.9. Reading: the etcd documentation's *Learning* section (data
> model, API guarantees, the glossary) and the Raft paper, *In Search of an Understandable Consensus
> Algorithm*.

The API server is a validation and admission layer in front of one key-value store with revisions
and watches. Every behaviour you have met as a Kubernetes user, `resourceVersion`, watch, *too old
resource version*, the 2 GiB cluster that stops accepting writes, is etcd showing through.

## Part 1 — MVCC by hand

```bash
sudo -E etcdctl get /registry/pods/default/ --prefix --keys-only | head
sudo -E etcdctl get "/registry/pods/default/$(kubectl get pod -o jsonpath='{.items[0].metadata.name}')" --print-value-only | head -c 200 | xxd | head -5
```

The value begins `k8s` and a null byte, then protobuf: the API server stores objects in its binary
wire format, not JSON, because it is smaller and faster to decode, and `kubectl` only ever sees
JSON because the server converts. Now revisions:

```bash
sudo -E etcdctl endpoint status -w table                     # REVISION: the cluster-wide counter every write bumps
kubectl create configmap rev --from-literal=a=1
sudo -E etcdctl get /registry/configmaps/default/rev -w json | jq '.kvs[0] | {create_revision, mod_revision, version}'
kubectl patch configmap rev -p '{"data":{"a":"2"}}'
sudo -E etcdctl get /registry/configmaps/default/rev -w json | jq '.kvs[0].mod_revision'   # higher
REV=$(sudo -E etcdctl get /registry/configmaps/default/rev -w json | jq '.kvs[0].create_revision')
sudo -E etcdctl get /registry/configmaps/default/rev --rev="$REV" --print-value-only | strings | grep -o 'a.1'   # the old value, still there
kubectl get configmap rev -o jsonpath='{.metadata.resourceVersion}{"\n"}'   # the same number as mod_revision
```

`resourceVersion` **is** etcd's `mod_revision`. That is why it is opaque, why it is monotonic across
all objects, and why optimistic concurrency works: an update carrying an old `resourceVersion` is
refused because the key's revision moved.

```bash
# a watch from a past revision replays every event since it, in order: this is what the apiserver's watch does
sudo -E etcdctl watch /registry/configmaps/default/ --prefix --rev="$REV" &
kubectl patch configmap rev -p '{"data":{"a":"3"}}'; kubectl delete configmap rev; kill %1
```

## Part 2 — Compaction and defragmentation

```bash
sudo -E etcdctl endpoint status -w table               # DB SIZE and DB SIZE IN USE
grep -E 'etcd-compaction-interval' /etc/kubernetes/manifests/kube-apiserver.yaml || echo "default: the apiserver compacts every 5 minutes"
sudo -E etcdctl compact "$(sudo -E etcdctl endpoint status -w json | jq '.[0].Status.header.revision')"
sudo -E etcdctl get /registry/configmaps/default/rev --rev="$REV"      # "required revision has been compacted"
sudo -E etcdctl defrag                                 # returns the space compaction freed to the OS; db size drops
```

Compaction discards revisions older than a point; it is the API server that asks for it, every five
minutes by default (`--etcd-compaction-interval`), and etcd can also do it itself with
`--auto-compaction-retention` on the static pod. Compaction frees nothing on disk until `defrag`
rewrites the file, and defrag blocks the member while it runs, so on a three-member cluster you do
it one member at a time.

```bash
# the alarm: shrink the quota so you can hit it, write junk outside /registry, watch writes refuse
sudo sed -i 's|- etcd|- etcd\n    - --quota-backend-bytes=33554432|' /etc/kubernetes/manifests/etcd.yaml   # 32 MiB; the kubelet restarts etcd
sleep 20; sudo -E etcdctl endpoint status -w table
for i in $(seq 1 400); do sudo -E etcdctl put "/lab/junk-$i" "$(head -c 100000 /dev/zero | tr '\0' x)" >/dev/null 2>&1 || break; done
sudo -E etcdctl alarm list                              # alarm:NOSPACE
kubectl create configmap after-alarm                   # etcdserver: mvcc: database space exceeded
sudo -E etcdctl del /lab/ --prefix >/dev/null
sudo -E etcdctl compact "$(sudo -E etcdctl endpoint status -w json | jq '.[0].Status.header.revision')" && sudo -E etcdctl defrag && sudo -E etcdctl alarm disarm
kubectl create configmap after-alarm                   # works. Now remove the quota line from the manifest.
```

The default quota is 2 GiB and the recommended maximum is 8 GiB. The alarm is the mechanism behind
"the cluster stopped accepting writes"; the three commands that clear it are the answer.

## Part 3 — Raft, fsync, and a slow disk

```bash
curl -s http://127.0.0.1:2381/metrics | grep -E '^etcd_server_(has_leader|leader_changes_seen_total|is_leader) '
curl -s http://127.0.0.1:2381/metrics | grep -E '^etcd_disk_wal_fsync_duration_seconds_bucket\{le="(0.001|0.004|0.016|0.064)"\}'
```

Every write is appended to the write-ahead log and `fsync`ed before Raft counts it as committed;
with one member, committed means fsynced. The histogram above is the number that matters: the
99th percentile should sit under 10 ms, and above about 100 ms the leader starts missing
heartbeats and elections begin. Prove it by making the disk slow for etcd only:

```bash
ETCD_UID=$(kubectl -n kube-system get pod etcd-k8s-cp -o jsonpath='{.metadata.uid}' | tr - _)
DEV=$(lsblk -no MAJ:MIN "$(findmnt -no SOURCE /var/lib/etcd | sed 's/\[.*//')" | head -1)
echo "$DEV wbps=524288" | sudo tee "/sys/fs/cgroup/kubepods.slice/kubepods-burstable.slice/kubepods-burstable-pod${ETCD_UID}.slice/io.max"   # 512 KiB/s writes
time kubectl create configmap slow --from-literal=a=1                        # seconds, not milliseconds
curl -s http://127.0.0.1:2381/metrics | grep -E '^etcd_disk_wal_fsync_duration_seconds_(sum|count) '
sudo journalctl -u kubelet -o cat --since '1 min ago' | grep -ic 'apiserver' ; kubectl get --raw /readyz?verbose | grep -i etcd
echo "$DEV wbps=max" | sudo tee "/sys/fs/cgroup/kubepods.slice/kubepods-burstable.slice/kubepods-burstable-pod${ETCD_UID}.slice/io.max"
```

That is what "etcd on a network disk" or "etcd sharing a disk with the container runtime" looks
like from the API: slow writes, then `etcdserver: request timed out`, then controllers falling
behind. Dedicated, local, low-latency storage for etcd is not a preference.

## Part 4 — The watch cache, and 410 Gone

```bash
kubectl get --raw '/api/v1/namespaces/default/configmaps?watch=1&resourceVersion=1&timeoutSeconds=2'
# {"type":"ERROR","object":{"kind":"Status","message":"too old resource version: 1 (…)","code":410}}
```

The API server keeps a **watch cache** per resource (`--default-watch-cache-size`, and per-resource
`--watch-cache-sizes`) so that thousands of informers do not each open an etcd watch. A client that
asks to resume from a revision older than the cache holds, or older than etcd's last compaction,
gets `410 Gone`, and `client-go` answers it by relisting. That relist storm after a control-plane
restart is the watch cache being empty, not a bug in your controller.

## Part 5 — What three members buy

```bash
sudo -E etcdctl member list -w table     # one member here; a stacked kubeadm HA cluster has three, one per control plane
```

Raft commits when a majority has fsynced. Three members tolerate one loss; five tolerate two; two
members tolerate none and are worse than one. **Stacked** etcd runs on the control-plane nodes
(three nodes, three members, three apiservers); **external** etcd runs on its own machines, so a
control-plane failure and an etcd failure are separate events. Lab 4 Part 4 drew both; this is the
number underneath the drawing.

**Do it again, from memory, timed.** Part 1 and the alarm recovery in Part 2, cold. Target: 15 minutes.
