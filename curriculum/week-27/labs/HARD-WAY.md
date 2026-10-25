# Lab 1, the hard way — a cluster with no kubeadm

> The slow path, once. Same three nodes, every certificate, kubeconfig and unit file written by hand,
> so that each thing `kubeadm init` prints in one line is something you have typed. Ladder:
> lifecycle, upgrades, HA, rung 3; authn, authz, admission, rung 3. About 6 hours; do it on a
> Saturday after Lab 5, or in week 31. The reference is the upstream
> [Kubernetes the Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way); this is
> its sequence mapped onto `k8s-cp`, `k8s-w1`, `k8s-w2`, with a line per step on what kubeadm hid.
> Figure 27.10 in [`FIGURES.md`](FIGURES.md) is the certificate fan-out you are about to build.

**Roles.** `k8s-cp` is the server (etcd and the three control-plane binaries) and your jumpbox; the
two workers run the kubelet, kube-proxy and the CNI bridge. Pod CIDR `10.200.0.0/16` (`10.200.1.0/24`
on w1, `10.200.2.0/24` on w2), service CIDR `10.32.0.0/24`, so the first service address is
`10.32.0.1` and CoreDNS gets `10.32.0.10`.

**Rule.** Nothing is copy-pasted from this file into a shell you have not read. Every command that
writes a file is a line you can explain.

---

## Step 0 — Put the packaged kubelet and kubeadm out of the way

On all three nodes:

```bash
sudo kubeadm reset -f && sudo rm -rf /etc/cni/net.d /etc/kubernetes "$HOME/.kube"   # a clean slate
sudo systemctl disable --now kubelet                 # the unit from the package; we run the binary ourselves
sudo rm -f /etc/systemd/system/kubelet.service.d/10-kubeadm.conf && sudo systemctl daemon-reload
```

**What it proves.** The kubelet is a binary with a config file and a kubeconfig. The package adds a
unit and a drop-in that reads `/var/lib/kubelet/kubeadm-flags.env`; take them away and the binary
is still there, waiting for you to tell it where the API server is.

## Step 1 — Binaries

On `k8s-cp` (the control plane and the client tools), then the kubelet, kube-proxy and CNI plugins on
each worker. The release train is the same one kubeadm would have used:

```bash
V=$(curl -Ls https://dl.k8s.io/release/stable.txt)      # or the exam's minor: v1.NN.0
for b in kube-apiserver kube-controller-manager kube-scheduler kubectl; do
  curl -LO "https://dl.k8s.io/release/${V}/bin/linux/amd64/${b}" && chmod +x "$b" && sudo mv "$b" /usr/local/bin/
done
curl -L https://github.com/etcd-io/etcd/releases/latest/download/etcd-$(curl -Ls https://api.github.com/repos/etcd-io/etcd/releases/latest | jq -r .tag_name)-linux-amd64.tar.gz \
  | tar xz --strip-components=1 -C /tmp && sudo mv /tmp/etcd /tmp/etcdctl /tmp/etcdutl /usr/local/bin/
```

```bash
# on each worker
V=$(curl -Ls https://dl.k8s.io/release/stable.txt)
for b in kubelet kube-proxy kubectl; do
  curl -LO "https://dl.k8s.io/release/${V}/bin/linux/amd64/${b}" && chmod +x "$b" && sudo mv "$b" /usr/local/bin/
done
sudo mkdir -p /opt/cni/bin /etc/cni/net.d
curl -L https://github.com/containernetworking/plugins/releases/latest/download/cni-plugins-linux-amd64-$(curl -Ls https://api.github.com/repos/containernetworking/plugins/releases/latest | jq -r .tag_name).tgz \
  | sudo tar xz -C /opt/cni/bin
```

**What it proves.** A cluster is seven binaries and a runtime. containerd and runc are already on
the nodes from the image; the CNI plugins are a tarball of small executables; nothing here is a
service you subscribe to.

## Step 2 — The certificate authority, and every certificate the cluster uses

On `k8s-cp`, in `~/pki`. One CA; then a certificate per identity. **The subject is the identity:**
the API server authenticates a client certificate by reading its `CN` as the user and its `O`s as
the groups, and RBAC's built-in bindings name exactly these.

```bash
mkdir -p ~/pki && cd ~/pki
openssl genrsa -out ca.key 4096
openssl req -x509 -new -sha512 -noenc -key ca.key -days 3653 -subj "/CN=kubernetes-ca" -out ca.crt

# A helper: a key, a CSR with the subject, a cert signed by the CA, with optional SANs.
cert() {   # cert <name> <subject> [san-file]
  openssl genrsa -out "$1.key" 4096
  openssl req -new -key "$1.key" -subj "$2" -out "$1.csr"
  openssl x509 -req -sha512 -days 365 -CA ca.crt -CAkey ca.key -CAcreateserial \
    -in "$1.csr" -out "$1.crt" ${3:+-extfile "$3" -extensions v3}
}
```

| Identity | Subject | Why that subject |
|---|---|---|
| `admin` | `/CN=admin/O=system:masters` | `system:masters` is bound to `cluster-admin` by a built-in ClusterRoleBinding |
| `kube-controller-manager` | `/CN=system:kube-controller-manager` | the built-in `system:kube-controller-manager` ClusterRole is bound to this user |
| `kube-scheduler` | `/CN=system:kube-scheduler` | likewise |
| `kube-proxy` | `/CN=system:kube-proxy/O=system:node-proxier` | the `system:node-proxier` role lets it list Services and EndpointSlices |
| `k8s-w1`, `k8s-w2` | `/CN=system:node:<name>/O=system:nodes` | the **Node authorizer** grants a kubelet access only to objects on its own node, keyed by this CN |
| `kube-apiserver` | `/CN=kube-apiserver` plus SANs | the serving certificate; clients verify the name they dialled |
| `service-accounts` | `/CN=service-accounts` | not for TLS: the key pair that signs and verifies ServiceAccount tokens |

```bash
cert admin "/CN=admin/O=system:masters"
cert kube-controller-manager "/CN=system:kube-controller-manager"
cert kube-scheduler "/CN=system:kube-scheduler"
cert kube-proxy "/CN=system:kube-proxy/O=system:node-proxier"
for n in k8s-w1 k8s-w2; do cert "$n" "/CN=system:node:${n}/O=system:nodes"; done
cert service-accounts "/CN=service-accounts"

CP_IP=$(hostname -I | awk '{print $1}')
cat > apiserver.ext <<EOF
[v3]
subjectAltName = DNS:kubernetes,DNS:kubernetes.default,DNS:kubernetes.default.svc,DNS:kubernetes.default.svc.cluster.local,DNS:k8s-cp,IP:10.32.0.1,IP:${CP_IP},IP:127.0.0.1
extendedKeyUsage = serverAuth
EOF
cert kube-apiserver "/CN=kube-apiserver" apiserver.ext

for n in k8s-w1 k8s-w2; do scp ca.crt "$n.crt" "$n.key" "$n":~/; done
```

**What it proves.** `kubeadm init phase certs all` is eleven `openssl` invocations with the
subjects above, and `/etc/kubernetes/pki/` is this directory. BF-60 is one of these files with the
wrong date or path. The `10.32.0.1` SAN is why a pod can call `https://kubernetes.default` and
verify the certificate.

## Step 3 — Kubeconfigs

A kubeconfig is three things: a server, a CA to trust it by, a credential. One per client
certificate; `--embed-certs` inlines the files so the config is portable.

```bash
cd ~/pki
kc() {   # kc <name> <user> <server>
  kubectl config set-cluster hard --certificate-authority=ca.crt --embed-certs=true --server="$3" --kubeconfig="$1.kubeconfig"
  kubectl config set-credentials "$2" --client-certificate="$1.crt" --client-key="$1.key" --embed-certs=true --kubeconfig="$1.kubeconfig"
  kubectl config set-context default --cluster=hard --user="$2" --kubeconfig="$1.kubeconfig"
  kubectl config use-context default --kubeconfig="$1.kubeconfig"
}
for n in k8s-w1 k8s-w2; do kc "$n" "system:node:${n}" "https://${CP_IP}:6443"; done
kc kube-proxy system:kube-proxy "https://${CP_IP}:6443"
kc kube-controller-manager system:kube-controller-manager https://127.0.0.1:6443   # same host as the apiserver
kc kube-scheduler system:kube-scheduler https://127.0.0.1:6443
kc admin admin https://127.0.0.1:6443
for n in k8s-w1 k8s-w2; do scp "$n.kubeconfig" kube-proxy.kubeconfig "$n":~/; done
```

**What it proves.** `kubeadm init phase kubeconfig all` is four of these; the ones in
`/etc/kubernetes/*.conf` point at `127.0.0.1` because the control plane talks to itself, and the
workers' point at the advertise address. Lab 2 Part 3 built one of these for a human.

## Step 4 — Encryption at rest

```bash
head -c 32 /dev/urandom | base64 > ~/pki/enc.key
cat > ~/pki/encryption-config.yaml <<EOF
kind: EncryptionConfiguration
apiVersion: apiserver.config.k8s.io/v1
resources:
  - resources: [secrets]
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: $(cat ~/pki/enc.key)
      - identity: {}
EOF
```

**What it proves.** The week 14 figure 14.4 said Secrets sit in etcd as plaintext by default. This
file is the `--encryption-provider-config` that changes it, and kubeadm does **not** write one;
it is on you in every cluster you have ever run.

## Step 5 — etcd, as a unit

```bash
sudo mkdir -p /etc/etcd /var/lib/etcd && sudo chmod 700 /var/lib/etcd
sudo cp ~/pki/ca.crt ~/pki/kube-apiserver.crt ~/pki/kube-apiserver.key /etc/etcd/
sudo tee /etc/systemd/system/etcd.service >/dev/null <<EOF
[Unit]
Description=etcd
[Service]
ExecStart=/usr/local/bin/etcd \\
  --name k8s-cp \\
  --cert-file=/etc/etcd/kube-apiserver.crt --key-file=/etc/etcd/kube-apiserver.key \\
  --trusted-ca-file=/etc/etcd/ca.crt --client-cert-auth \\
  --listen-client-urls https://127.0.0.1:2379 --advertise-client-urls https://127.0.0.1:2379 \\
  --listen-peer-urls http://127.0.0.1:2380 --initial-advertise-peer-urls http://127.0.0.1:2380 \\
  --initial-cluster k8s-cp=http://127.0.0.1:2380 --initial-cluster-state new \\
  --listen-metrics-urls http://127.0.0.1:2381 \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload && sudo systemctl enable --now etcd
sudo etcdctl --cacert /etc/etcd/ca.crt --cert /etc/etcd/kube-apiserver.crt --key /etc/etcd/kube-apiserver.key member list -w table
```

**What it proves.** The static pod from Lab 3 is this unit with the same flags in a container.
Lab 3's three `etcdctl` certificate flags are the three files on this command line. A single member
is a quorum of one; Lab 4 Part 4 is what changes with three.

## Step 6 — The control plane, as three units

```bash
sudo mkdir -p /var/lib/kubernetes
sudo cp ~/pki/{ca.crt,ca.key,kube-apiserver.crt,kube-apiserver.key,service-accounts.crt,service-accounts.key,encryption-config.yaml} /var/lib/kubernetes/
sudo cp ~/pki/{kube-controller-manager,kube-scheduler}.kubeconfig /var/lib/kubernetes/

sudo tee /etc/systemd/system/kube-apiserver.service >/dev/null <<EOF
[Unit]
Description=kube-apiserver
[Service]
ExecStart=/usr/local/bin/kube-apiserver \\
  --advertise-address=${CP_IP} --allow-privileged=true \\
  --authorization-mode=Node,RBAC --client-ca-file=/var/lib/kubernetes/ca.crt \\
  --enable-admission-plugins=NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\
  --etcd-servers=https://127.0.0.1:2379 --etcd-cafile=/var/lib/kubernetes/ca.crt \\
  --etcd-certfile=/var/lib/kubernetes/kube-apiserver.crt --etcd-keyfile=/var/lib/kubernetes/kube-apiserver.key \\
  --encryption-provider-config=/var/lib/kubernetes/encryption-config.yaml \\
  --kubelet-certificate-authority=/var/lib/kubernetes/ca.crt \\
  --kubelet-client-certificate=/var/lib/kubernetes/kube-apiserver.crt --kubelet-client-key=/var/lib/kubernetes/kube-apiserver.key \\
  --service-account-key-file=/var/lib/kubernetes/service-accounts.crt \\
  --service-account-signing-key-file=/var/lib/kubernetes/service-accounts.key \\
  --service-account-issuer=https://${CP_IP}:6443 \\
  --service-cluster-ip-range=10.32.0.0/24 --service-node-port-range=30000-32767 \\
  --tls-cert-file=/var/lib/kubernetes/kube-apiserver.crt --tls-private-key-file=/var/lib/kubernetes/kube-apiserver.key \\
  --v=2
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF

sudo tee /etc/systemd/system/kube-controller-manager.service >/dev/null <<EOF
[Unit]
Description=kube-controller-manager
[Service]
ExecStart=/usr/local/bin/kube-controller-manager \\
  --kubeconfig=/var/lib/kubernetes/kube-controller-manager.kubeconfig \\
  --cluster-cidr=10.200.0.0/16 --service-cluster-ip-range=10.32.0.0/24 \\
  --cluster-signing-cert-file=/var/lib/kubernetes/ca.crt --cluster-signing-key-file=/var/lib/kubernetes/ca.key \\
  --root-ca-file=/var/lib/kubernetes/ca.crt \\
  --service-account-private-key-file=/var/lib/kubernetes/service-accounts.key \\
  --use-service-account-credentials=true --leader-elect=false --v=2
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF

sudo tee /var/lib/kubernetes/kube-scheduler.yaml >/dev/null <<EOF
apiVersion: kubescheduler.config.k8s.io/v1
kind: KubeSchedulerConfiguration
clientConnection:
  kubeconfig: /var/lib/kubernetes/kube-scheduler.kubeconfig
leaderElection:
  leaderElect: false
EOF
sudo tee /etc/systemd/system/kube-scheduler.service >/dev/null <<EOF
[Unit]
Description=kube-scheduler
[Service]
ExecStart=/usr/local/bin/kube-scheduler --config=/var/lib/kubernetes/kube-scheduler.yaml --v=2
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload && sudo systemctl enable --now kube-apiserver kube-controller-manager kube-scheduler
sleep 10 && kubectl --kubeconfig ~/pki/admin.kubeconfig get --raw /readyz?verbose | tail -3
```

Then the one piece of RBAC kubeadm writes for you: the API server reaches kubelets (for `logs` and
`exec`) with its own certificate, `CN=kube-apiserver`, which no built-in role names:

```bash
kubectl --kubeconfig ~/pki/admin.kubeconfig apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata: { name: system:kube-apiserver-to-kubelet }
rules:
  - apiGroups: [""]
    resources: [nodes/proxy, nodes/stats, nodes/log, nodes/spec, nodes/metrics]
    verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata: { name: system:kube-apiserver }
roleRef: { apiGroup: rbac.authorization.k8s.io, kind: ClusterRole, name: system:kube-apiserver-to-kubelet }
subjects: [{ apiGroup: rbac.authorization.k8s.io, kind: User, name: kube-apiserver }]
EOF
```

**What it proves.** The four static-pod manifests under `/etc/kubernetes/manifests` are these
three units plus etcd, flag for flag. Read `kube-apiserver.service` against Lab 1 Part 5's grep of
the kubeadm manifest: the same `--etcd-servers`, `--client-ca-file`, `--tls-cert-file`. The
service-account key pair is why a pod's token is verifiable by the API server and by nothing else.
`kubectl logs` failing with `Forbidden (user=kube-apiserver)` is the missing ClusterRole above.

## Step 7 — Workers: kubelet, kube-proxy, CNI

On each worker (`k8s-w1` shown; `10.200.2.0/24` on `k8s-w2`):

```bash
N=$(hostname); POD_CIDR=10.200.1.0/24
sudo mkdir -p /var/lib/kubelet /var/lib/kube-proxy /var/lib/kubernetes /var/run/kubernetes
sudo cp ~/ca.crt /var/lib/kubernetes/ && sudo cp ~/"$N".crt ~/"$N".key /var/lib/kubelet/
sudo cp ~/"$N".kubeconfig /var/lib/kubelet/kubeconfig && sudo cp ~/kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig

sudo tee /etc/cni/net.d/10-bridge.conf >/dev/null <<EOF
{ "cniVersion": "1.0.0", "name": "bridge", "type": "bridge", "bridge": "cnio0", "isGateway": true, "ipMasq": true,
  "ipam": { "type": "host-local", "ranges": [[{ "subnet": "${POD_CIDR}" }]], "routes": [{ "dst": "0.0.0.0/0" }] } }
EOF
sudo tee /etc/cni/net.d/99-loopback.conf >/dev/null <<EOF
{ "cniVersion": "1.0.0", "name": "lo", "type": "loopback" }
EOF

sudo tee /var/lib/kubelet/kubelet-config.yaml >/dev/null <<EOF
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous: { enabled: false }
  webhook: { enabled: true }
  x509: { clientCAFile: /var/lib/kubernetes/ca.crt }
authorization: { mode: Webhook }
clusterDomain: cluster.local
clusterDNS: [10.32.0.10]
cgroupDriver: systemd
containerRuntimeEndpoint: unix:///var/run/containerd/containerd.sock
podCIDR: ${POD_CIDR}
tlsCertFile: /var/lib/kubelet/${N}.crt
tlsPrivateKeyFile: /var/lib/kubelet/${N}.key
EOF
sudo tee /etc/systemd/system/kubelet.service >/dev/null <<EOF
[Unit]
Description=kubelet
After=containerd.service
[Service]
ExecStart=/usr/local/bin/kubelet --config=/var/lib/kubelet/kubelet-config.yaml --kubeconfig=/var/lib/kubelet/kubeconfig --v=2
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF

sudo tee /var/lib/kube-proxy/kube-proxy-config.yaml >/dev/null <<EOF
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection: { kubeconfig: /var/lib/kube-proxy/kubeconfig }
mode: iptables
clusterCIDR: 10.200.0.0/16
EOF
sudo tee /etc/systemd/system/kube-proxy.service >/dev/null <<EOF
[Unit]
Description=kube-proxy
[Service]
ExecStart=/usr/local/bin/kube-proxy --config=/var/lib/kube-proxy/kube-proxy-config.yaml
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload && sudo systemctl enable --now kubelet kube-proxy
```

Then the routes, from `k8s-cp` and each worker, because the bridge plugin gives every node its own
`/24` and nothing advertises it (this is the job Calico did in Lab 1; Go deeper lab E is what fails
on GCP without encapsulation and why):

```bash
# on every node, for each OTHER worker:   ip route add <its pod cidr> via <its node ip>
sudo ip route add 10.200.2.0/24 via "$(getent hosts k8s-w2 | awk '{print $1}')"
```

```bash
kubectl --kubeconfig ~/pki/admin.kubeconfig get nodes -o wide     # on k8s-cp: two Ready nodes
```

**What it proves.** `kubeadm join` is: a kubeconfig with `CN=system:node:<name>`, a kubelet config
downloaded from the `kubelet-config` ConfigMap, and the unit. Here the config is the file you
wrote, and `cgroupDriver: systemd` is the line that would be BF-59 if it disagreed with containerd.
kube-proxy is a DaemonSet in a kubeadm cluster; here it is a unit, and the iptables rules it writes
(figure 14.3 badge ⑦) are identical.

## Step 8 — CoreDNS, and the smoke test

```bash
export KUBECONFIG=~/pki/admin.kubeconfig
kubectl apply -f https://raw.githubusercontent.com/kelseyhightower/kubernetes-the-hard-way/master/configs/coredns.yaml   # the upstream manifest; read it first: a Deployment, a Service at 10.32.0.10, a ConfigMap
kubectl -n kube-system get pods -w

# Encryption at rest: a Secret must be unreadable in etcd
kubectl create secret generic hard --from-literal=k=v
sudo etcdctl --cacert /etc/etcd/ca.crt --cert /etc/etcd/kube-apiserver.crt --key /etc/etcd/kube-apiserver.key \
  get /registry/secrets/default/hard | hexdump -C | head -5          # k8s:enc:aescbc:v1:key1, not the value

kubectl create deployment web --image=nginx:alpine --replicas=2 && kubectl expose deployment web --port 80 --type NodePort
kubectl get pods -o wide                                            # one per worker, addresses from each /24
kubectl exec deploy/web -- nslookup kubernetes                      # CoreDNS answers 10.32.0.1
kubectl logs deploy/web | head -2                                   # the apiserver→kubelet ClusterRole at work
curl -s "http://k8s-w1:$(kubectl get svc web -o jsonpath='{.spec.ports[0].nodePort}')" | head -3
```

**What it proves.** `kubeadm init phase addon` is the CoreDNS manifest and the kube-proxy DaemonSet.
The hexdump is the only direct evidence most engineers ever see that encryption at rest is on.

---

## Step → `kubeadm` phase → the file it writes

| Step | kubeadm equivalent | What kubeadm writes |
|---|---|---|
| 0 binaries and the packaged unit | the `kubelet` and `kubeadm` packages | `/usr/bin/kubelet`, `/etc/systemd/system/kubelet.service.d/10-kubeadm.conf` |
| 2 CA and certificates | `kubeadm init phase certs all` | `/etc/kubernetes/pki/{ca,apiserver,apiserver-kubelet-client,front-proxy-*,sa}.{crt,key}`, `pki/etcd/*` |
| 3 kubeconfigs | `kubeadm init phase kubeconfig all` | `/etc/kubernetes/{admin,super-admin,controller-manager,scheduler,kubelet}.conf` |
| 4 encryption at rest | none; kubeadm does not do this | the `--encryption-provider-config` you add to the apiserver manifest yourself |
| 5 etcd | `kubeadm init phase etcd local` | `/etc/kubernetes/manifests/etcd.yaml` (a static pod, not a unit), `/var/lib/etcd` |
| 6 control plane | `kubeadm init phase control-plane all` | `manifests/kube-apiserver.yaml`, `kube-controller-manager.yaml`, `kube-scheduler.yaml` |
| 6 apiserver→kubelet RBAC | `kubeadm init phase bootstrap-token` and the `kubeadm:*` ClusterRoleBindings | the `kubeadm:kubelet-bootstrap` and `system:kube-apiserver` bindings in the API |
| 7 kubelet and config | `kubeadm init phase kubelet-start`, `kubeadm join` | `/var/lib/kubelet/config.yaml`, `kubeadm-flags.env`, `/etc/kubernetes/kubelet.conf` |
| 7 kube-proxy | `kubeadm init phase addon kube-proxy` | the `kube-proxy` DaemonSet and ConfigMap in `kube-system` |
| 7 CNI | none; "install a CNI" is step one of every kubeadm guide | `/etc/cni/net.d/*` written by the CNI's own installer |
| 8 CoreDNS | `kubeadm init phase addon coredns` | the `coredns` Deployment, Service and ConfigMap |
| 2 again, a year later | `kubeadm certs renew all` | the same files, new dates |

**Do it again, from memory, timed.** Not this one. Once is the point; the figure is the retrieval.
What you redraw is 27.10, and the sentence you keep is: *the subject of the certificate is the
identity, and kubeadm is a program that runs the steps above in order.*

Back to the fast path: `kubeadm reset -f` on all three nodes, remove the units and `/var/lib/kubernetes`,
re-enable the packaged `kubelet` unit, and Lab 1 Part 2 again in 25 minutes.
