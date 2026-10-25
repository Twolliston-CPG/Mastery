# Break/Fix: Cluster Nodes (BF-59 – BF-64)

> **The node set, weeks 27 to 30.** Gate 4 broke objects; these break the machines the objects run
> on. They need a kubeadm cluster (`_setup/gcp-lab/` with `kubeadm_nodes` set), because kind runs its
> control plane as containers and cannot show a kubelet dying. By the Gate 7 Sunday you diagnose any
> of them in under 10 minutes, narrated. They are also the node third of the CKA troubleshooting domain.

## The universal first three commands, node edition

```bash
kubectl get nodes -o wide                        # which node, since when
kubectl describe node <node> | grep -A6 Conditions   # Ready · DiskPressure · MemoryPressure · PIDPressure
ssh <node> 'sudo systemctl status kubelet --no-pager; sudo journalctl -u kubelet --no-pager | tail -30'
```

**The API cannot fix a kubelet.** When a node is NotReady, the second command is `ssh`. When the API
server itself is gone, the tools are `crictl` and the files under `/var/log/pods/`, because
`kubectl logs` needs the thing that is down.

---

## BF-59 — Node NotReady: the kubelet is down, or on the wrong cgroup driver

**SYMPTOM:** One node `NotReady`. Pods on it still show Running for a while, then Terminating after the
eviction timeout. New pods avoid the node.

**BREAK:** on the worker, one of:
```bash
sudo systemctl stop kubelet
# or
sudo sed -i 's/^cgroupDriver: systemd/cgroupDriver: cgroupfs/' /var/lib/kubelet/config.yaml && sudo systemctl restart kubelet
```

**DIAGNOSIS:** `systemctl status kubelet` says inactive (first case) or activating/auto-restart (second).
`journalctl -u kubelet` for the second:
```
"Failed to run kubelet" err="failed to run Kubelet: misconfiguration: kubelet cgroup driver: \"cgroupfs\" is different from docker cgroup driver: \"systemd\""
```
The kubelet and the container runtime must use the same cgroup driver; containerd is on `systemd`
(`SystemdCgroup = true` in `/etc/containerd/config.toml`) and the kubelet must say so.

**FIX:**
```bash
sudo sed -i 's/^cgroupDriver: cgroupfs/cgroupDriver: systemd/' /var/lib/kubelet/config.yaml
sudo systemctl restart kubelet && sudo systemctl enable kubelet
```

**THE TEACHING LINE:** a NotReady node is a process on a machine. `describe node` tells you which
machine; the journal on that machine tells you which process and why. Nothing in the API fixes it.

---

## BF-60 — One client cannot authenticate: an expired or mis-pathed certificate

**SYMPTOM:** Everything works except one thing: the scheduler pod restarts and new pods stay Pending; or
the controller manager restarts and Deployments stop reconciling; or one user's `kubectl` says
`x509: certificate has expired` / `certificate signed by unknown authority` / `connection refused`.

**BREAK:** on the control plane, one of:
```bash
sudo sed -i 's#:6443#:6444#' /etc/kubernetes/scheduler.conf            # wrong port
sudo sed -i 's#/etc/kubernetes/pki/ca.crt#/etc/kubernetes/pki/ca.crt.bak#' /etc/kubernetes/manifests/kube-controller-manager.yaml   # wrong path
# the expired case is Lab 2's `check-expiration` on a cluster not upgraded in a year
```

**DIAGNOSIS:**
```bash
kubectl -n kube-system get pods                                  # which component is crash-looping
sudo crictl ps -a | grep scheduler; sudo crictl logs <id> 2>&1 | tail -5
#   dial tcp 10.10.0.5:6444: connect: connection refused         -> the kubeconfig's server line
#   open /etc/kubernetes/pki/ca.crt.bak: no such file            -> the manifest's path
sudo kubeadm certs check-expiration                              # the expiry case, in one table
sudo openssl x509 -in <the file the config points at> -noout -dates -subject
```

**FIX:** correct the port or path in the kubeconfig or manifest; for expiry,
`sudo kubeadm certs renew all` then move the four manifests out and back so the running processes
reload, and re-copy `admin.conf` to `~/.kube/config`.

**THE TEACHING LINE:** when exactly one client fails, it is that client's credential: which file it
reads, what that file points at, and whether the certificate inside is still valid. `openssl x509
-dates` on the right file is the whole investigation.

---

## BF-61 — The API server is gone: a static pod manifest typo

**SYMPTOM:** `kubectl` returns `The connection to the server <ip>:6443 was refused`. The node is
fine; the kubelet is fine; everything that needs the API is dead.

**BREAK:** on the control plane, one of:
```bash
sudo sed -i 's/--etcd-servers=https:\/\/127.0.0.1:2379/&\n    - --this-flag-does-not-exist=true/' /etc/kubernetes/manifests/kube-apiserver.yaml   # bad flag
sudo sed -i 's/^    - --etcd-servers/   - --etcd-servers/' /etc/kubernetes/manifests/kube-apiserver.yaml          # bad indentation
```

**DIAGNOSIS:**
```bash
sudo crictl ps -a | grep kube-apiserver          # bad flag: a container that keeps Exiting
sudo crictl logs <id> 2>&1 | tail -3             #   Error: unknown flag: --this-flag-does-not-exist
sudo journalctl -u kubelet | grep -i apiserver | tail -3   # bad YAML: "Could not process manifest file" ... yaml: line N
ls /var/log/pods/ | grep apiserver               # the container logs on disk, for when crictl is unfamiliar
```

**FIX:** correct the manifest. The kubelet notices within seconds and restarts the pod; `kubectl` is
back in about twenty.

**THE TEACHING LINE:** static pods have no controller and no `kubectl logs` when the thing they run
is the API. `crictl` and the kubelet's journal are the only witnesses. If the container never
appears, the YAML did not parse; if it appears and exits, the binary rejected its arguments.

---

## BF-62 — Pods stuck ContainerCreating: the CNI is not running

**SYMPTOM:** New pods on one node (or all) sit in `ContainerCreating`. Existing pods keep running.
`kubectl get nodes` may still say Ready, or may say NotReady with `NetworkPluginNotReady`.

**BREAK:** on a worker, one of:
```bash
sudo mv /etc/cni/net.d/10-calico.conflist /root/ && sudo systemctl restart kubelet
# or, from the control plane
kubectl -n calico-system patch ds calico-node -p '{"spec":{"template":{"spec":{"nodeSelector":{"nope":"true"}}}}}'
```

**DIAGNOSIS:**
```bash
kubectl describe pod <stuck> | tail -5
#   Warning  FailedCreatePodSandBox ... network plugin is not ready: cni config uninitialized
ssh k8s-w1 'ls -l /etc/cni/net.d/'                  # empty
kubectl -n calico-system get pods -o wide            # is calico-node running on that node?
```

**FIX:** restore the config file, or revert the DaemonSet patch; the kubelet picks the file up and the
sandboxes are created.
```bash
sudo mv /root/10-calico.conflist /etc/cni/net.d/
kubectl -n calico-system patch ds calico-node --type=json -p '[{"op":"remove","path":"/spec/template/spec/nodeSelector/nope"}]'
```

**THE TEACHING LINE:** the kubelet creates the pod sandbox and then asks the CNI plugin to wire it.
No CNI config, no network, no sandbox, and the pod waits forever in the state whose name says so.
The same message is what a fresh `kubeadm init` shows before the CNI is installed.

---

## BF-63 — Node NotReady: containerd stopped, or the disk is full

**SYMPTOM:** One node `NotReady`; or `Ready` with `DiskPressure=True` and pods being evicted from it
with `The node had condition: [DiskPressure]`.

**BREAK:** on a worker, one of:
```bash
sudo systemctl stop containerd
# or
sudo fallocate -l $(( $(df --output=avail -B1 / | tail -1) - 500000000 )) /var/fill    # leave ~500 MB
```

**DIAGNOSIS:**
```bash
kubectl describe node k8s-w1 | grep -A6 Conditions
sudo journalctl -u kubelet --no-pager | tail -20
#   "Container runtime not ready" ... failed to get runtime status: rpc error: ... connection refused   -> containerd
#   "Disk usage on image filesystem is at 97% which is over the high threshold (85%)"                   -> disk
sudo systemctl status containerd; df -h /
```

**FIX:**
```bash
sudo systemctl start containerd
# or
sudo rm /var/fill; sudo crictl rmi --prune        # the kubelet also garbage-collects images under pressure
```

**THE TEACHING LINE:** the kubelet depends on a runtime and a disk, and reports both as node
conditions. The eviction thresholds (85 percent image filesystem by default) are why a full disk
empties a node before it fills it.

---

## BF-64 — The API server cannot reach etcd

**SYMPTOM:** `kubectl` is refused or hangs; the apiserver container restarts; its log says it cannot
reach `127.0.0.1:2379`.

**BREAK:** on the control plane, one of:
```bash
sudo sed -i 's#--listen-client-urls=https://127.0.0.1:2379,#--listen-client-urls=#' /etc/kubernetes/manifests/etcd.yaml   # no longer on localhost
sudo sed -i 's#path: /var/lib/etcd$#path: /var/lib/etcd-does-not-exist#' /etc/kubernetes/manifests/etcd.yaml   # empty data dir: a NEW empty cluster, not a crash
```

**DIAGNOSIS:**
```bash
sudo crictl ps -a | grep -E 'etcd|apiserver'
sudo crictl logs $(sudo crictl ps -a -q --name kube-apiserver | head -1) 2>&1 | grep -i etcd | tail -3
#   transport: Error while dialing: dial tcp 127.0.0.1:2379: connect: connection refused
sudo ss -lntp | grep 2379                                 # who is listening, and on which address
sudo crictl logs $(sudo crictl ps -a -q --name etcd | head -1) 2>&1 | tail -5
sudo grep -A1 'name: etcd-data' /etc/kubernetes/manifests/etcd.yaml
```
Watch for the second variant: etcd **starts fine** on an empty directory and the API server comes
back with **no objects in it**. `kubectl get nodes` returning nothing is the clue, and the fix is the
Lab 3 restore.

**FIX:** restore `--listen-client-urls` or the hostPath; the kubelet restarts etcd, the apiserver
reconnects. If the apiserver stays down more than a minute, move its manifest out and back.

**THE TEACHING LINE:** the API server is a stateless front for etcd. Every "the API is down" has two
candidates: the apiserver's own manifest (BF-61) or the thing it talks to (this one). `ss -lntp |
grep 2379` splits them in one line.
