# The Kubernetes thread

> Every lab in the program, weeks 1 to 30, read as Kubernetes. The Linux, networking, AWS, Terraform
> and CI weeks are not prerequisites you did once; they are the parts Kubernetes is made of, and this
> file says which part, one level under the lab. The ladder it feeds, the rubric and the schedule are in
> [`../KUBERNETES-MASTERY.md`](../KUBERNETES-MASTERY.md).

**How to use it.** After each lab, read its entry. Run the **See it in Kubernetes** command when a
cluster is at hand (kind from week 14, the kubeadm nodes from week 27). Say the **Say it** sentence
aloud; it is the retrieval cue that joins the lab to the mechanism. The **Ladder** line names the topic
and the rung the lab reached, so the scoring table at each gate has evidence. Five minutes a lab.

**Relation levels.** *strong*: the lab is a Kubernetes mechanism, or the same mechanism Kubernetes runs on.
*medium*: a design or operation Kubernetes reproduces with its own objects. *background*: context the
cluster work assumes. *none*: no thread; the entry says why in one line.

---

<a id="week-1"></a>

## Week 1 — Linux I, Git, and the Environment

### Lab 1 — Environment Setup and Filesystem Tour · [lab](week-01/labs/lab-01-environment.md)
**Relates:** medium
**How:** `/proc` is the kernel's view of every process, and a pod is a group of processes the kernel sees exactly this way. `/proc/PID/ns` is where a container's namespaces are visible as symlinks; `lsof` reading `/proc/PID/fd` is what `crictl` and `kubectl debug` ultimately do on a node. The snapshot-and-restore habit is the mental model for nodes: disposable, rebuilt from an image, never repaired in place.
**The mechanism:** The kubelet does not have a private window into containers. It asks the runtime (containerd) through the CRI, and containerd reports what the kernel knows: PIDs, cgroups, namespaces, open files. Every `kubectl top`, every eviction decision, every `describe node` capacity number is a read of `/proc` and `/sys/fs/cgroup` on that node, done by cAdvisor inside the kubelet. When a node misbehaves, the fastest diagnosis is still `ls /proc/<pid>/ns`, `cat /proc/<pid>/cgroup` and `lsof -p`, exactly as here; a `kubectl debug node/<n>` pod mounts the host filesystem under `/host` so you can do it without SSH.
**See it in Kubernetes:**
```bash
PID=$(sudo crictl inspect $(sudo crictl ps -q --name web) | jq .info.pid); sudo ls -l /proc/$PID/ns
kubectl debug node/k8s-w1 -it --image=busybox -- ls /host/proc
```
**Say it:** "A pod is a set of PIDs the kernel already knows about; the kubelet just reads /proc the way I did."
**Ladder:** kubelet and runtime · rung 2 debug.

### Lab 2 — Permissions, Users, and Processes · [lab](week-01/labs/lab-02-permissions-processes.md)
**Relates:** strong
**How:** `runAsUser`, `runAsGroup`, `fsGroup` and `readOnlyRootFilesystem` are the mode bits, UIDs and mount flags from this lab, written in YAML. SIGTERM-then-SIGKILL is literally pod termination: `terminationGracePeriodSeconds` (default 30) is the gap between the two signals. The directory `x` bit is why a volume mounted with the wrong `fsGroup` yields "permission denied" on a file the app owns. Zombies (BF-09) are the PID-1 problem inside containers.
**The mechanism:** On delete, the kubelet runs the `preStop` hook, sends SIGTERM to PID 1 of each container, waits the grace period, then SIGKILL. A process that does not handle SIGTERM (a shell wrapper, an app with no handler) wastes the full 30 seconds and is killed mid-write; that is why `exec` in entrypoints and `STOPSIGNAL` matter. Inside the container the first process is PID 1 and inherits PID 1's duties: reaping children. An app that forks and never waits leaves zombies that count against the pod's PID limit (`pids.max` in the cgroup), which is BF-09 at scale. UID mapping is honest: `runAsUser: 1000` is UID 1000 on the node, and `runAsNonRoot: true` makes the kubelet refuse to start an image whose `USER` is a name it cannot resolve to a number. A `D` state process on a node is as unkillable under Kubernetes as it was here; the pod sits in Terminating until the I/O returns.
**See it in Kubernetes:**
```bash
kubectl exec deploy/web -- sh -c 'echo PID1=$$; ls -ld /var/cache/nginx; id'
kubectl get pod web -o jsonpath='{.spec.terminationGracePeriodSeconds}'; kubectl delete pod web --wait=false; kubectl get pod web -w
```
**Say it:** "Pod termination is SIGTERM, a 30-second wait, then SIGKILL, delivered to PID 1, and PID 1 has to reap."
**Ladder:** isolation and security · kubelet and runtime · rung 3 explain.

### Lab 3 — Text Processing: The Log Analysis Lab · [lab](week-01/labs/lab-03-text-processing.md)
**Relates:** background
**How:** `kubectl logs` is a stream of lines, and this pipeline is how you read it: `kubectl logs -l app=web --prefix | awk`, `kubectl get pods -o json | jq`, `-o jsonpath` and `-o custom-columns` are the same field-and-filter habits. The error-rate threshold with an exit code is the shape of a liveness check and of an alert.
**The mechanism:** Container stdout and stderr are written by containerd to `/var/log/pods/<ns>_<pod>_<uid>/<container>/0.log` on the node, rotated by the kubelet at `containerLogMaxSize` (default 10Mi) and `containerLogMaxFiles` (default 5). `kubectl logs` asks the API server, which proxies to the kubelet, which reads that file; `--previous` reads the rotated one from the last container instance. Log shippers (the week-14 sidecar, a DaemonSet) tail the same files. Structured JSON logs (week 20) exist so this lab's `awk` fields become `jq` keys.
**See it in Kubernetes:**
```bash
kubectl logs -l app=web --prefix --tail=1000 | awk '{print $(NF-1)}' | sort | uniq -c | sort -rn | head
sudo ls /var/log/pods/*/web/
```
**Say it:** "kubectl logs is a file under /var/log/pods, read through the kubelet; the pipeline is the same."
**Ladder:** kubelet and runtime · rung 1 use.

### Lab 4 — Bash Scripting: Build `sysreport.sh` · [lab](week-01/labs/lab-04-bash-sysreport.md)
**Relates:** medium
**How:** Exit codes are a Kubernetes contract: a container's exit code decides restart (CrashLoopBackOff on non-zero under `restartPolicy: Always`, Job `backoffLimit` on failure, `podFailurePolicy` rules keyed on exit codes). `set -euo pipefail` in an init container or a Job is the difference between a failure you see and one that silently succeeds. The `/proc` and `df` reads are what the kubelet's cAdvisor collects for `kubectl top` and for eviction.
**The mechanism:** The kubelet records `lastState.terminated.exitCode` and `reason` for every container exit. Exit 0 under `Always` restarts anyway (week 14 Lab 4); exit 137 is SIGKILL from the OOM killer or the grace-period expiry; exit 143 is SIGTERM handled; exit 1 is yours. A Job's `podFailurePolicy` can say "exit code 42 means do not retry" or "a disruption (eviction) does not count against backoffLimit", which is this lab's exit-code discipline promoted to the controller. Graceful degradation when `/proc/*/fd` is unreadable is the same reflex as a readiness probe that fails closed rather than crashing.
**See it in Kubernetes:**
```bash
kubectl get pod crash1 -o jsonpath='{.status.containerStatuses[0].lastState.terminated}'
kubectl explain job.spec.podFailurePolicy.rules.onExitCodes
```
**Say it:** "The exit code is the message; Kubernetes reads it before it reads your logs."
**Ladder:** controllers · kubelet and runtime · rung 2 debug.

### Lab 5 — Break/Fix Friday #1 · [lab](week-01/labs/lab-05-breakfix.md)
**Relates:** medium
**How:** The seven-step loop is the Gate 4 narration unchanged. Each Linux scenario has a node twin: BF-01 disk full is `DiskPressure` on a node, which evicts pods and makes the kubelet garbage-collect images; BF-02 runaway CPU is a pod at its CPU limit being throttled (`cpu.stat` `nr_throttled`) rather than killed; BF-03 exec permission denied is `CreateContainerError` with "permission denied" on the entrypoint; BF-04 broken PATH is exit 127 and CrashLoopBackOff; BF-10 deleted-but-open file is the same `lsof +L1` inside a container's overlay upper dir.
**The mechanism:** The kubelet watches `nodefs` and `imagefs` against eviction thresholds (`nodefs.available<10%`, `imagefs.available<15%` by default). Below the hard threshold it sets the `DiskPressure` condition, taints the node, and evicts pods by QoS and usage; it also deletes unused images down to `imageGCLowThresholdPercent`. A file held open by a crashed-but-not-exited process keeps the space, exactly as BF-10, and `du` on the node disagrees with `df` for the same reason.
**See it in Kubernetes:**
```bash
kubectl describe node k8s-w1 | grep -A6 Conditions; sudo journalctl -u kubelet | grep -i 'eviction\|imagefs'
kubectl exec deploy/app -- cat /sys/fs/cgroup/cpu.stat | grep throttled
```
**Say it:** "Every Linux break has a node condition or a container state with the same cause."
**Ladder:** resources and scale · kubelet and runtime · rung 2 debug.

### Lab 6 — Git Fundamentals and Your First Repo · [lab](week-01/labs/lab-06-git.md)
**Relates:** background
**How:** The commit SHA becomes an image tag (week 12) and a Git repository becomes the desired state ArgoCD reconciles the cluster toward (week 16). Reset versus revert is the GitOps rule: history is never rewritten on the branch a cluster watches, because the cluster will follow it.
**The mechanism:** ArgoCD and Flux are controllers whose "spec" is a Git ref. They fetch, render (Kustomize, Helm), diff against live objects, and apply; a `git revert` is a rollout, a force-push is drift. The content-addressed object model you drew here is also how container images work: layers by digest, a manifest pointing at them, a tag as a movable ref, which is why signing (week 18) attaches to the digest and never the tag.
**See it in Kubernetes:**
```bash
kubectl get application -n argocd -o jsonpath='{.items[0].status.sync.revision}'
```
**Say it:** "A Git SHA and an image digest are the same idea, and the cluster follows refs to both."
**Ladder:** controllers · rung 1 use.

<a id="week-2"></a>

## Week 2 — Linux II and Networking I

### Lab 1 — systemd: Services and Timers · [lab](week-02/labs/LABS.md)
**Relates:** strong
**How:** The kubelet and containerd are systemd units; `systemctl status kubelet` and `journalctl -u kubelet` are the first commands on any broken node (BF-59). `Restart=on-failure` with backoff is `restartPolicy` and CrashLoopBackOff. The hardening directives map one to one: `NoNewPrivileges` is `allowPrivilegeEscalation: false`, `ProtectSystem=strict` is `readOnlyRootFilesystem`, `PrivateTmp` is an `emptyDir`. A timer is a CronJob. systemd is also the cgroup driver.
**The mechanism:** With `SystemdCgroup = true` in containerd and `cgroupDriver: systemd` in the kubelet, every pod is a systemd slice: `kubepods.slice/kubepods-burstable.slice/kubepods-burstable-pod<uid>.slice/cri-containerd-<id>.scope`. The QoS classes of week 15 are literally these three slices (`kubepods-besteffort`, `kubepods-burstable`, and Guaranteed pods directly under `kubepods.slice`). A kubelet and runtime that disagree on the driver is BF-59: pods start and die with cgroup errors. Static pods are the kubelet's own `enable --now`: a manifest directory it watches with no API server involved, which is how the control plane boots itself on kubeadm. The journal is also where the control plane's own logs go on a kubeadm node when containerd's logging is not what you expected.
**See it in Kubernetes:**
```bash
systemctl cat kubelet; sudo journalctl -u kubelet -n 50 --no-pager
systemd-cgls /kubepods.slice | head -30
```
**Say it:** "The kubelet is a unit, every pod is a slice, and restartPolicy is Restart= with a backoff the kubelet owns."
**Ladder:** kubelet and runtime · lifecycle, upgrades, HA · rung 3 explain.

### Lab 2 — SSH Hardening and Disks · [lab](week-02/labs/LABS.md)
**Relates:** strong
**How:** `dd`, `losetup`, `mkfs`, `mount` is the exact sequence a CSI node plugin runs: `NodeStageVolume` formats and mounts the device once under `/var/lib/kubelet/plugins/`, `NodePublishVolume` bind-mounts it into the pod's directory. Inode exhaustion with free blocks is a node `DiskPressure` cause (`nodefs.inodesFree`). Hardened SSH on a node is OS Login, SSM, or IAP: nothing listens for the world, and most clusters never SSH at all.
**The mechanism:** A PersistentVolume for block storage goes through attach (the attach-detach controller on the control plane asks the cloud to attach the disk to the node), stage (format if empty, mount at a global path), and publish (bind mount into `/var/lib/kubelet/pods/<uid>/volumes/`). `kubectl describe pod` shows each step as an event, and a volume stuck between attach and mount is the storage half of week 15. The filesystem you chose here is the `fsType` on the StorageClass; the `-o` mount flags are `mountOptions`. On the security side, the kubelet's own API on 10250 is the thing hardened like sshd: client certificates, no anonymous, authorization delegated to the API server.
**See it in Kubernetes:**
```bash
kubectl describe pod postgres-0 | grep -iE 'attach|mount'; sudo findmnt | grep kubelet/pods
sudo df -i /var/lib/containerd
```
**Say it:** "A PVC is attach, stage, publish: the same mkfs and mount I ran, done by a plugin, reported as events."
**Ladder:** storage and CSI · isolation and security · rung 3 explain.

### Lab 3 — Subnetting to Automaticity · [lab](week-02/labs/LABS.md)
**Relates:** strong
**How:** A cluster has three address spaces you size here: the pod CIDR (`--pod-network-cidr`, carved into a per-node `podCIDR`, by default a /24 per node, so a /16 is 256 nodes), the Service CIDR (`--service-cluster-ip-range`, where ClusterIPs come from), and the node subnets. On EKS the VPC CNI gives pods real VPC addresses, so the subnet math of this lab decides how many pods an AZ can hold.
**The mechanism:** The controller manager allocates `podCIDR` to each node from the cluster CIDR with `--node-cidr-mask-size` (default 24). The CNI hands pod addresses out of that range on the node, which caps a node at 254 pods regardless of `maxPods` (default 110). The Service range must not overlap anything routable, because ClusterIPs exist only in kube-proxy rules and a real host at the same address becomes unreachable. On EKS, each pod consumes a secondary IP on an ENI, or a /28 slice with prefix delegation, so the private-app subnets must be sized for pods and the public ones for load balancers; running out of IPs shows as pods stuck ContainerCreating with "failed to assign an IP". The "keep half the /16 free" rule from the lab is there so a second node group or a second cluster fits.
**See it in Kubernetes:**
```bash
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.podCIDR}{"\n"}{end}'
kubectl cluster-info dump | grep -m1 -E 'service-cluster-ip-range|cluster-cidr'
```
**Say it:** "Three CIDRs, and the per-node /24 is why a /16 pod range is 256 nodes."
**Ladder:** networking datapath · resources and scale · rung 3 explain.

### Lab 4 — TCP/IP and DNS with tcpdump · [lab](week-02/labs/LABS.md)
**Relates:** strong
**How:** A SYN to a ClusterIP is DNAT-ed by kube-proxy to a pod IP, and the conntrack entry you watched here is what carries the reply back; TIME-WAIT and CLOSE-WAIT pile up in pods exactly as on a host. `dig +trace` is the shape of cluster DNS: `web.default.svc.cluster.local` resolved by CoreDNS, with `resolv.conf` inside the pod carrying `ndots:5` and three search domains. `curl -w` timings are how you size probe timeouts.
**The mechanism:** The pod's `/etc/resolv.conf` is written by the kubelet from `dnsPolicy` (default `ClusterFirst`): nameserver is the kube-dns ClusterIP, search is `<ns>.svc.cluster.local svc.cluster.local cluster.local`, and `ndots:5` means any name with fewer than five dots is tried with every search suffix first. A lookup of `api.example.com` from a pod is up to four cluster-internal NXDOMAINs before the real query, which is the latency people blame on CoreDNS. `tcpdump` on a node shows it: the same `[S]`, `[S.]`, `[.]` you captured, now on the veth of the pod. Readiness and liveness probes are TCP or HTTP connects from the kubelet on the node, so their `timeoutSeconds` (default 1) is the `connect` number from `curl -w`, and a probe that times out is a connection the app accepted too slowly, not a crash.
**See it in Kubernetes:**
```bash
kubectl exec deploy/web -- cat /etc/resolv.conf
kubectl debug -it pod/web --image=nicolaka/netshoot --target=web -- tcpdump -ni eth0 port 53 or port 80 -c 20
```
**Say it:** "A ClusterIP is a DNAT plus a conntrack entry, and ndots:5 is why a short name costs up to five queries."
**Ladder:** networking datapath · DNS · rung 3 explain.

### Lab 5 — Break/Fix Friday #2 · [lab](week-02/labs/LABS.md)
**Relates:** medium
**How:** Each scenario has a cluster twin. BF-05 (broken ExecStart) is BF-59, a kubelet unit that will not start; BF-06 (SSH lockout) is losing node access, which is why nodes are reached by IAP or SSM and rebuilt rather than rescued; BF-07 (cron never runs) is a CronJob that never fires: `suspend: true`, a `startingDeadlineSeconds` that was missed, `concurrencyPolicy: Forbid` with a stuck previous Job; BF-11 (DNS) is CoreDNS down or `ndots`; BF-12 (wrong gateway) is a node whose CNI routes are gone (BF-62); BF-16 (port in use) is `hostPort` or `hostNetwork` pods colliding on a node.
**The mechanism:** The CronJob controller computes the next schedule, and if it finds more than 100 missed schedules since the last run it stops scheduling and emits an event rather than catching up; `startingDeadlineSeconds` bounds how late a run may start. `Forbid` skips a run when the previous Job's pod is still alive, which is the "never runs" symptom when a job hangs. For port conflicts, the scheduler treats `hostPort` as a resource, so a second pod with the same `hostPort` stays Pending with a clear event, unlike the host, where the second process just fails to bind.
**See it in Kubernetes:**
```bash
kubectl describe cronjob backup | grep -iE 'suspend|deadline|concurrency|events' -A3
kubectl get events --field-selector reason=FailedScheduling
```
**Say it:** "The Friday breaks are node breaks with a controller watching; the controller's event is the new first clue."
**Ladder:** controllers · lifecycle, upgrades, HA · rung 2 debug.

<a id="week-3"></a>

## Week 3 — Networking II, Git Collaboration, Nginx

### Lab 1 — Routing, NAT, and Firewalls · [lab](week-03/labs/LABS.md)
**Relates:** strong
**How:** The namespace plus veth pair you built is a pod's network, exactly: the CNI creates the veth, moves one end into the pod's netns, assigns the address, and installs the route. `ip_forward=1` is a kubeadm preflight requirement because every node routes for its pods. `MASQUERADE` is kube-proxy's `KUBE-MARK-MASQ` chain. The conntrack `ESTABLISHED,RELATED` rule is what lets the reply to a DNAT-ed Service connection find its way back. First-match chain order is the `KUBE-SERVICES` chain. DROP versus REJECT is a NetworkPolicy drop (a timeout) versus a Service with no endpoint (connection refused).
**The mechanism:** Calico, Flannel, and the VPC CNI differ only in how traffic leaves the node: an overlay (VXLAN, the same encapsulation idea as your namespace talking out through the host), BGP routes, or real VPC addresses. On the node, `ip route` shows one route per peer node's `podCIDR`. kube-proxy in iptables mode writes a `KUBE-SVC-*` chain per Service with a probabilistic jump to one `KUBE-SEP-*` chain per endpoint, the DNAT lives there, and conntrack remembers the choice for the life of the connection. That is why removing a pod from a Service does not break existing connections, and why a Service with `sessionAffinity: ClientIP` is a conntrack-backed hash. The IPVS and nftables modes replace the chains but not the model. NetworkPolicy is implemented by the CNI as the same `iptables`/`nftables`/eBPF rules on the node, which is why kind's default CNI "accepts" a policy and enforces nothing.
**See it in Kubernetes:**
```bash
sudo iptables-save -t nat | grep -E 'KUBE-SVC|KUBE-SEP|MASQ' | head; sudo conntrack -L | grep 10.96 | head
ip route | grep -v default   # one route per peer node's podCIDR
```
**Say it:** "A pod is this namespace and veth; a Service is DNAT in a chain plus a conntrack entry; NetworkPolicy is the firewall on every node."
**Ladder:** networking datapath · rung 3 explain, rung 4 after the week-27 CNI-by-hand lab.

### Lab 2 — DNS with Your Own Domain · [lab](week-03/labs/LABS.md)
**Relates:** strong
**How:** The cluster runs its own authoritative zone, `cluster.local`, served by CoreDNS: `<svc>.<ns>.svc.cluster.local` is an A record pointing at the ClusterIP, a headless Service returns the pod IPs directly, named ports get SRV records, and `ExternalName` is a CNAME. TTL decay and caching are the same; the apex-CNAME rule is why `ExternalName` cannot be used for an apex either. external-dns is the controller that writes Route 53 from your Ingress and Service objects.
**The mechanism:** CoreDNS's `kubernetes` plugin watches Services and EndpointSlices through the API server and answers from memory, so DNS is never behind the API; the `forward` plugin sends everything else to the node's resolver, and `cache` holds answers for the TTL (30 seconds by default for cluster records). A StatefulSet pod gets a stable name, `postgres-0.postgres.app.svc.cluster.local`, only because its headless Service publishes per-pod A records, which is why databases are addressed by name rather than load-balanced. external-dns reads the `external-dns.alpha.kubernetes.io/hostname` annotation or the Ingress host and upserts records with a TXT ownership record beside each, the same ownership idea as a registrar.
**See it in Kubernetes:**
```bash
kubectl run -it --rm dig --image=nicolaka/netshoot -- dig +search web; dig @10.96.0.10 postgres.app.svc.cluster.local
kubectl -n kube-system get configmap coredns -o yaml | sed -n '/Corefile/,$p'
```
**Say it:** "cluster.local is a zone CoreDNS serves from a watch; headless Services are the records that make a pod addressable."
**Ladder:** DNS · rung 3 explain.

### Lab 3 — Nginx Reverse Proxy and Load Balancing · [lab](week-03/labs/LABS.md)
**Relates:** strong
**How:** ingress-nginx is this nginx with the `upstream` block generated from EndpointSlices; 502 and 504 keep their exact meanings (no backend accepted, a backend was too slow). `max_fails` and `fail_timeout` are what a readiness probe replaces: a pod failing readiness is removed from the endpoints, so the proxy never sees it. `X-Forwarded-For` is `externalTrafficPolicy: Local` and the proxy-protocol question. `keepalive 32` is `upstream-keepalive-connections`.
**The mechanism:** Every Ingress controller is a config generator plus a proxy: it watches Ingress, Service, and EndpointSlice objects, renders a config (nginx.conf, Envoy xDS for Contour, listener rules for the AWS ALB), and reloads or pushes it. The proxy balances across pod IPs directly, not ClusterIPs, which is why `kubectl get endpointslices` is the diagnostic for a 502 from an Ingress: an empty list is the selector or readiness, exactly as in week 14 Lab 2. Timeouts are annotations (`proxy-read-timeout`) and a 504 is the same `proxy_read_timeout` you hit with `sleep(40)`. Client IP survives only if the hop before the proxy preserves it: a cloud LB with proxy protocol, or a NodePort with `externalTrafficPolicy: Local`, which keeps the source address at the cost of a second hop being refused.
**See it in Kubernetes:**
```bash
kubectl -n ingress-nginx exec deploy/ingress-nginx-controller -- cat /etc/nginx/nginx.conf | grep -A3 'upstream upstream_balancer'
kubectl get endpointslices -l kubernetes.io/service-name=web
```
**Say it:** "An Ingress controller is nginx with upstreams rendered from endpoints; 502 and 504 mean what they meant on Tuesday."
**Ladder:** networking datapath · rung 3 explain.

### Lab 4 — TLS End to End · [lab](week-03/labs/LABS.md)
**Relates:** strong
**How:** A cluster is a PKI: one CA under `/etc/kubernetes/pki`, client certificates for every component and for you (`admin.conf` carries one), a server certificate on the API server whose SANs include its ClusterIP and DNS names, and a one-year client expiry that is BF-60 when it lapses. cert-manager is certbot as a controller. An Ingress TLS secret is the leaf plus chain; "unable to verify the first certificate" means the intermediate is missing from `tls.crt`.
**The mechanism:** The kubelet proves itself to the API server with a client certificate the CA signed through a CertificateSigningRequest at join time and rotates it before expiry (`rotateCertificates: true`); the API server proves itself with a server certificate whose SAN list is why adding a load balancer name to a control plane needs `kubeadm init phase certs apiserver --apiserver-cert-extra-sans`. kubectl trusts the CA from the kubeconfig's `certificate-authority-data`. cert-manager watches Certificate objects, creates an Order with an ACME issuer, solves the HTTP-01 challenge through your Ingress, and writes a `kubernetes.io/tls` Secret the Ingress controller loads; the renewal timer is the controller requeueing at two thirds of the lifetime. Every x509 error you read in this lab reappears verbatim in `kubectl` output when a kubeconfig or the cluster CA is wrong.
**See it in Kubernetes:**
```bash
sudo kubeadm certs check-expiration
openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -text | grep -A1 'Subject Alternative Name'
```
**Say it:** "The cluster is a CA plus client certs; expiry, SAN mismatch and a missing chain are the same three errors, in kubectl's voice."
**Ladder:** authn, authz, admission · lifecycle, upgrades, HA · rung 3 explain.

### Lab 5 — Break/Fix Friday #3 · [lab](week-03/labs/LABS.md)
**Relates:** medium
**How:** BF-13 (rule order) has a twin with a twist: NetworkPolicies have no order, they are additive allow-lists, so the diagnosis is "which policy should have allowed this" rather than "which rule matched first". BF-14 (502) is an Ingress whose backend has no ready endpoints. BF-15 (TLS) is a bad `kubernetes.io/tls` Secret or a wrong `secretName`. BF-16 (port in use) is `hostPort`. BF-17 (MTU black hole) is a CNI MTU mismatch: VXLAN adds 50 bytes, and a pod MTU left at 1500 on an overlay hangs large transfers exactly as here.
**The mechanism:** The CNI sets the pod interface MTU from its own config (Calico `mtu`, Flannel subtracts the overlay overhead automatically); on AWS the VPC CNI uses 9001 to match jumbo frames, which breaks the day traffic leaves to a 1500-byte path without PMTU discovery. Small requests work, large responses stall, and `tcpdump` on the veth shows the retransmits. For TLS at the Ingress, the controller logs the certificate it failed to load and falls back to a self-signed default, so a browser warning about "Kubernetes Ingress Controller Fake Certificate" is BF-15's new face.
**See it in Kubernetes:**
```bash
kubectl exec deploy/web -- ip link show eth0 | grep mtu; kubectl -n kube-system get configmap calico-config -o yaml 2>/dev/null | grep -i mtu
kubectl get networkpolicy -A
```
**Say it:** "Policies add, they do not order; and an overlay steals 50 bytes of MTU."
**Ladder:** networking datapath · rung 2 debug.

### Lab 6 — Git Collaboration · [lab](week-03/labs/LABS.md)
**Relates:** background
**How:** Pull requests, squash merges and branch protection are the control plane of GitOps: the cluster's desired state changes only through a reviewed merge to the branch ArgoCD watches (week 16). A rebase that rewrites a watched branch is a forced resync; `bisect` against a cluster is bisecting which commit changed the rendered manifests.
**The mechanism:** ArgoCD keeps the last synced revision in the Application status and diffs every poll (three minutes by default, or on a webhook) against the live cluster; an `OutOfSync` after a merge is the normal state for a few seconds, and after a force-push it is the sign someone rewrote history under a running controller. The Kustomize overlays you will write in week 15 and week 28 are what a PR review actually reads, which is why `kubectl kustomize` output in the PR comment is a common CI step.
**See it in Kubernetes:**
```bash
kubectl -n argocd get application -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,REV:.status.sync.revision
```
**Say it:** "The merge is the deploy; the controller follows the branch."
**Ladder:** controllers · rung 1 use.

<a id="week-4"></a>

## Week 4 — Python for Ops, Docker, and Gate 1

### Lab 1 — Python Ops CLI · [lab](week-04/labs/LABS.md)
**Relates:** medium
**How:** The Prometheus renderer with a bounded `mount` label and an unbounded `pid` label is the cardinality lesson behind BF-56, and `/metrics` in this exact exposition format is what a ServiceMonitor scrapes in week 20. The exit-code contract is a Job's. An executable named `kubectl-foo` on your PATH is a kubectl plugin, so this CLI's shape is how you extend kubectl.
**The mechanism:** The kubelet, kube-proxy, the scheduler and the API server all expose `/metrics` in this format, and the API server's `apiserver_request_total` carries labels for verb, resource, and code, bounded on purpose. A label whose value set grows with traffic (pod UID, request path) makes Prometheus allocate a new series per value until memory runs out, which is why `kube-state-metrics` exposes object metadata with a fixed label set. The Python client for Kubernetes wraps the same REST API kubectl uses; a script that lists pods with it is making `GET /api/v1/namespaces/x/pods`, with the same authentication from the kubeconfig.
**See it in Kubernetes:**
```bash
kubectl get --raw /metrics | grep -c '^apiserver_request_total'
kubectl get --raw /api/v1/namespaces/default/pods | jq '.items | length'
```
**Say it:** "Bounded labels or a dead Prometheus; the cluster's own components follow the rule."
**Ladder:** resources and scale · API machinery · rung 2 debug.

### Lab 2 — Testing, Packaging, HTTP · [lab](week-04/labs/LABS.md)
**Relates:** medium
**How:** A resilient HTTP client with timeouts, retries and backoff on 429 and 5xx is what client-go is: every controller talks to the API server through one, honours `Retry-After`, and backs off on 429. The API server returns 429 on purpose when API Priority and Fairness queues overflow, so a client without backoff is a client that makes an overload worse. A missing timeout is a probe that hangs the kubelet's worker.
**The mechanism:** The API server classifies every request into a flow schema and a priority level (APF); when a level's concurrency is exhausted requests queue, then get 429 with `Retry-After`. client-go's default rate limiter (QPS 5, burst 10 for a bare client; higher for controllers) and its exponential backoff on 429 and 5xx are this lab's `Retry` object. The liveness probe has `timeoutSeconds` (default 1) for the same reason the connect timeout here is 3.05: a probe with no bound would hold a kubelet goroutine and delay every other probe on the node.
**See it in Kubernetes:**
```bash
kubectl get --raw /metrics | grep apiserver_flowcontrol_rejected_requests_total | head -3
kubectl get flowschemas
```
**Say it:** "client-go is a Session with Retry; the API server hands out 429s and expects you to back off."
**Ladder:** API machinery · rung 2 debug.

### Lab 3 — Docker: What a Container Actually Is · [lab](week-04/labs/LABS.md)
**Relates:** strong
**How:** This is the week on which all of Kubernetes rests. A pod is the namespaces you listed, shared: every container in a pod joins one network and one IPC namespace held open by the pause container, and optionally one PID namespace (`shareProcessNamespace`). `memory.max` is `limits.memory`; `cpu.max` is `limits.cpu`; `cpu.weight` is `requests.cpu`. Layers are shared between pods on a node by containerd's snapshotter. The embedded DNS at 127.0.0.11 becomes CoreDNS at the cluster DNS ClusterIP. The 127.0.0.1 bind bug is BF-47's "endpoints but refused". The named volume is a PVC.
**The mechanism:** containerd creates the pod sandbox first: a pause container that does nothing but hold the network and IPC namespaces, which is why a pod has one IP before any of your containers start and keeps it while they restart. Each app container is then created with `CLONE_NEWNS` and `CLONE_NEWPID` of its own but joins the sandbox's net and IPC namespaces, so `localhost` is shared and a sidecar reads the app on 127.0.0.1. Resources become cgroup v2 files under the pod's slice: `memory.max` for the limit (exceed it and the kernel's OOM killer sends SIGKILL, exit 137), `cpu.max` as a quota per period (exceed it and the scheduler throttles, no kill), `cpu.weight` from requests (what the node shares under contention). The image is a stack of layers addressed by digest; the snapshotter mounts them as one overlay per container, so a second pod from the same image on the node pulls nothing. Running as root inside the container is root on the node unless user namespaces are on.
**See it in Kubernetes:**
```bash
sudo crictl pods; sudo crictl inspectp <sandbox> | jq '.info.runtimeSpec.linux.namespaces'
cat /sys/fs/cgroup/kubepods.slice/kubepods-burstable.slice/*/memory.max
```
**Say it:** "A pod is a pause container's namespaces, shared; limits are cgroup files; the image is layers one overlay deep."
**Ladder:** isolation and security · kubelet and runtime · resources and scale · rung 3 explain.

### Lab 4 — Dockerfiles: 1.2 GB → 20 MB · [lab](week-04/labs/LABS.md)
**Relates:** strong
**How:** Image size is pull time, and pull time is the Pulling-to-Pulled gap in the pod's events, the thing that makes scale-out slow and rollouts long. A numeric `USER` is what `runAsNonRoot` can verify. Read-only root with writable paths is `readOnlyRootFilesystem` plus `emptyDir`. `HEALTHCHECK` is ignored by Kubernetes entirely; `/health` and `/ready` become liveness and readiness probes. Layer order is cache hits in CI and shared layers on the node.
**The mechanism:** The kubelet pulls with `imagePullPolicy` (`IfNotPresent` for a tagged image, `Always` for `:latest`), serialised per node by default, so ten pods of a 1.2 GB image on a fresh node start minutes apart; the image GC of BF-01 then fights to keep disk under the threshold. A `:latest` tag that moved is why rollouts "did nothing" and why the exam and week 19 ban it. Multi-stage builds matter twice: smaller pulls and fewer CVEs for the week 18 scanner. `runAsNonRoot: true` makes the kubelet refuse to start a container whose image user is a name rather than a numeric UID, because it cannot prove the name is not 0 without the image's `/etc/passwd`. Docker's `HEALTHCHECK` has no consumer: Kubernetes decides health with its own probes from the kubelet, so the Dockerfile line is dead weight.
**See it in Kubernetes:**
```bash
kubectl get events --field-selector reason=Pulled -o custom-columns=POD:.involvedObject.name,MSG:.message | head
kubectl get pod web -o jsonpath='{.spec.containers[0].imagePullPolicy}'
```
**Say it:** "Size is pull time, USER must be a number, and HEALTHCHECK is ignored; probes are the kubelet's."
**Ladder:** kubelet and runtime · isolation and security · rung 3 explain.

### Lab 5 — Break/Fix Friday #4 · [lab](week-04/labs/LABS.md)
**Relates:** strong
**How:** Every container scenario is a pod scenario. BF-19 (exits immediately with code 0) is week 14's `crash2`: a finished PID 1 under `restartPolicy: Always` is CrashLoopBackOff with a clean exit. BF-20 (bound to 127.0.0.1) is endpoints present, connection refused. BF-21 (data lost on recreate) is `emptyDir` where a PVC was needed. BF-22 (`.git` in the build context) and BF-23 (cache always misses) are CI time and pull time. BF-24 (container DNS) is CoreDNS and `dnsPolicy`.
**The mechanism:** The kubelet's restart backoff starts at ten seconds and doubles to five minutes, resetting after ten minutes of clean running; `kubectl describe` shows `Back-off restarting failed container` with the previous exit code in `lastState`. For the bind address, the readiness probe is run by the kubelet against the pod IP, not localhost, so an app bound to 127.0.0.1 fails readiness and never gets endpoints; if it has no probe, it gets endpoints and refuses. `emptyDir` lives in `/var/lib/kubelet/pods/<uid>/volumes/kubernetes.io~empty-dir/` and is deleted with the pod, which is the week-14 acceptance test's reason to exist.
**See it in Kubernetes:**
```bash
kubectl get pod crash2 -o jsonpath='{.status.containerStatuses[0].lastState.terminated.exitCode}'
kubectl get endpointslices -l kubernetes.io/service-name=web -o jsonpath='{.items[0].endpoints[*].addresses}'
```
**Say it:** "Six container breaks, six pod states; the probe runs against the pod IP, never localhost."
**Ladder:** kubelet and runtime · networking datapath · rung 2 debug.

### Lab 6 — The Compose Stack · [lab](week-04/labs/LABS.md)
**Relates:** strong
**How:** This stack is ported object for object in week 14 Lab 5, and the table there is this lab's spec: `depends_on: service_healthy` becomes an init container plus a readiness probe; `healthcheck` becomes three probes; a named volume becomes a PVC on a StatefulSet; the user-defined network's DNS becomes CoreDNS; `.env` becomes a ConfigMap and a Secret mounted as a file; resource limits become requests and limits; nginx becomes an Ingress.
**The mechanism:** The split that Compose hides is the one Kubernetes makes explicit: a thing and the way it is reached are different objects (Deployment and Service), startup order and traffic readiness are different mechanisms (init container and readiness probe), and configuration is not baked into the unit that runs. Compose's `depends_on` orders starts once; a readiness probe keeps deciding for the life of the pod, which is why a database blip removes the app from the Service instead of crashing it. The three-service topology also fixes the vocabulary for the rest of the program: a proxy tier, a stateless app tier, a stateful data tier, each scaled and secured differently.
**See it in Kubernetes:**
```bash
kubectl get deploy,svc,sts,pvc,ingress -n app
kubectl get pod -n app -o jsonpath='{range .items[*]}{.metadata.name}{" init="}{.spec.initContainers[*].name}{"\n"}{end}'
```
**Say it:** "Every Compose line has a Kubernetes object, and the lines that were one thing become two."
**Ladder:** controllers · networking datapath · storage and CSI · rung 3 explain.

<a id="week-5"></a>

## Week 5 — AWS Foundations: IAM and EC2

### Lab 1 — Guardrails and the CLI · [lab](week-05/labs/LABS.md)
**Relates:** background
**How:** The budget alarm you test here is the one that catches a forgotten EKS cluster: the control plane bills by the hour whether or not nodes exist, and an orphaned load balancer created by a controller (week 16) bills after `terraform destroy`. `--query` is JMESPath; `kubectl -o jsonpath` and `jq` do the same job and you will use all three. AZ names versus AZ IDs matter for EKS: the control plane subnets and node subnets must be in AZs the service supports, and names differ per account.
**The mechanism:** Kubernetes has no cost model; a cluster's bill is nodes, load balancers, EBS volumes and NAT, created by controllers that do not know they cost money. The habit from this lab, alarm first and test the alarm, is the only guard against a `type: LoadBalancer` Service in a loop.
**See it in Kubernetes:**
```bash
kubectl get svc -A --field-selector spec.type=LoadBalancer
```
**Say it:** "Controllers create billable things; the alarm is the control."
**Ladder:** resources and scale · rung 1 use.

### Lab 2 — IAM Policies From Scratch · [lab](week-05/labs/LABS.md)
**Relates:** strong
**How:** Kubernetes RBAC is IAM with half the evaluation ladder removed: no explicit deny, no boundary, no resource policy. A request is allowed if any binding grants the verb on the resource in that scope; otherwise it is denied by default. Where IAM says "explicit Deny wins", Kubernetes says "admission": the deny lives in Kyverno, ValidatingAdmissionPolicy or Pod Security Admission, evaluated after RBAC. `simulate-principal-policy` is `kubectl auth can-i --as`. On EKS, the IAM principal is mapped to a Kubernetes group by an access entry, so both ladders run, IAM first.
**The mechanism:** The API server authenticates (certificate, token, OIDC, or on EKS the IAM authenticator validating a presigned STS call), then authorizes by asking each configured authorizer in order (Node, RBAC, webhook); RBAC's answer is the union of every Role and ClusterRole bound to the user, its groups, and `system:authenticated`. There is no deny rule to write, so "take away" means "remove a binding", and a ClusterRoleBinding to `cluster-admin` is unreviewable breadth. The `ListBucket`-on-the-wrong-ARN mistake has a twin: a Role granting `get` on `pods` does not grant `pods/log`, because the sub-resource is a separate resource string (BF-48). Admission is where IAM's conditions reappear: `aws:SecureTransport` becomes a policy requiring TLS on an Ingress.
**See it in Kubernetes:**
```bash
kubectl auth can-i list secrets --as=system:serviceaccount:shop:deployer -n shop
kubectl auth can-i --list --as=jane; aws eks list-access-entries --cluster-name alpha
```
**Say it:** "RBAC is union-of-allows with implicit deny; the explicit deny moved to admission."
**Ladder:** authn, authz, admission · rung 3 explain.

### Lab 3 — Roles, Assume-Role, Boundaries · [lab](week-05/labs/LABS.md)
**Relates:** strong
**How:** IRSA (week 16) is this lab with a different principal: the trust policy names an OIDC provider and a `sub` of `system:serviceaccount:<ns>:<sa>`, and the pod calls `AssumeRoleWithWebIdentity` with a projected ServiceAccount token instead of `sts:AssumeRole` with a user. Trust versus permissions keeps its meaning exactly: AccessDenied on the assume is the trust policy, AccessDenied after is the permissions policy. `ExternalId` is the `aud` claim. Pod Identity is the same handshake with the token exchanged by an agent on the node.
**The mechanism:** The API server is an OIDC issuer: it signs ServiceAccount tokens (JWTs) with a cluster key and publishes the public key at `/openid/v1/jwks`. EKS hosts that document at a public URL so IAM can verify a token's signature without talking to the cluster. A projected token has an audience, an expiry (an hour by default, rotated by the kubelet), and a `sub` naming the ServiceAccount. The AWS SDK's credential chain reads `AWS_WEB_IDENTITY_TOKEN_FILE` and `AWS_ROLE_ARN`, injected by a mutating webhook, and performs the assume. A permission boundary has no cluster twin, but the related problem does: RBAC's `escalate` and `bind` verbs are what stops a user who can create Roles from granting more than they hold.
**See it in Kubernetes:**
```bash
kubectl get --raw /openid/v1/jwks | jq '.keys[0].kid'
kubectl exec deploy/s3-reader -- sh -c 'cat $AWS_WEB_IDENTITY_TOKEN_FILE' | cut -d. -f2 | base64 -d 2>/dev/null | jq '{sub,aud,exp}'
```
**Say it:** "IRSA is assume-role where the principal is a signed ServiceAccount token; trust is who, permissions are what, same as today."
**Ladder:** authn, authz, admission · rung 3 explain.

### Lab 4 — EC2, EBS, AMIs, Security Groups · [lab](week-05/labs/LABS.md)
**Relates:** strong
**How:** A node is this instance: a managed node group is a launch template plus an ASG, the AMI is the EKS-optimized image, and the user data runs the bootstrap that joins the cluster. EBS is a PersistentVolume through the EBS CSI driver, `ReadWriteOnce` and pinned to its AZ, which is why `WaitForFirstConsumer` exists. Security groups that reference security groups are the cluster security group rules: control plane to kubelet on 10250, nodes to each other, nodes to the API on 443. IMDSv2 with hop limit 1 is the setting that stops a pod from reading the node's credentials.
**The mechanism:** The EBS CSI controller (a Deployment) calls `AttachVolume` on behalf of the attach-detach controller; the node plugin (a DaemonSet) formats and mounts it, as in week 2 Lab 2. A volume can only attach to an instance in its own AZ, so a PVC with `volumeBindingMode: Immediate` can be provisioned in an AZ the scheduler then cannot place the pod in; `WaitForFirstConsumer` delays provisioning until the pod has a node. Snapshots are `VolumeSnapshot` objects through the same driver. On the node, the hop limit is a routing fact: a pod on the bridge is one extra hop from 169.254.169.254, so a limit of 1 drops its request, and IRSA becomes the only credential path; a pod with `hostNetwork: true` is zero extra hops and sees IMDS regardless.
**See it in Kubernetes:**
```bash
kubectl get storageclass -o custom-columns=NAME:.metadata.name,PROV:.provisioner,BIND:.volumeBindingMode
aws ec2 describe-instances --filters Name=tag-key,Values=eks:nodegroup-name --query 'Reservations[].Instances[].MetadataOptions'
```
**Say it:** "A node is an instance from a launch template; a PV is an EBS volume that cannot leave its AZ; hop limit 1 keeps pods out of IMDS."
**Ladder:** storage and CSI · isolation and security · lifecycle, upgrades, HA · rung 3 explain.

### Lab 5 — Instance Profiles, IMDSv2, Break/Fix · [lab](week-05/labs/LABS.md)
**Relates:** strong
**How:** The node's instance profile is what every pod inherits when nothing else is configured, which is the first of the four IRSA failure causes in week 16 ("no annotation → the node role"). The SSRF path you traced is the classic cluster escalation: any pod with a request-forging bug reads the node role's credentials unless the hop limit or a NetworkPolicy to 169.254.169.254 stops it. BF-25 and BF-26 reappear as a pod's `AccessDenied` with a correct-looking IRSA policy that forgot `kms:Decrypt`.
**The mechanism:** The node role needs real permissions (pull from ECR, attach volumes, describe instances for the CNI), so it is never harmless. Without IRSA, the SDK in a pod walks its credential chain to IMDS and gets those permissions; with IRSA the chain finds the web identity token first and stops. The remaining risk is `hostNetwork` pods and the hop limit, which is why the week-19 NetworkPolicy work includes an egress deny to the metadata address. The IMDS token's 21600-second TTL is unrelated to the pod token's hour: two credentials, two clocks, and in an incident you must say which one leaked.
**See it in Kubernetes:**
```bash
kubectl run imds --rm -it --image=curlimages/curl -- sh -c 'curl -s -m 3 -X PUT http://169.254.169.254/latest/api/token -H "X-aws-ec2-metadata-token-ttl-seconds: 60" || echo blocked'
kubectl get sa s3-reader -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}'
```
**Say it:** "Without IRSA every pod is the node; the SSRF from today is the escalation path on a cluster."
**Ladder:** isolation and security · authn, authz, admission · rung 3 explain.

<a id="week-6"></a>

## Week 6 — VPC and S3

### Lab 1 — Build a VPC by Hand · [lab](week-06/labs/LABS.md)
**Relates:** strong
**How:** EKS has opinions about this exact layout: subnets in at least two AZs, private subnets tagged `kubernetes.io/role/internal-elb` and public ones `kubernetes.io/role/elb` so the load balancer controller can find them, nodes in the private tier, and app subnets sized for pod IPs because the VPC CNI hands pods real addresses. The data tier with no default route is the same posture as a NetworkPolicy egress deny: a database that cannot initiate outbound.
**The mechanism:** The control plane runs in an AWS-owned VPC and reaches your nodes through cross-account ENIs it places in the subnets you list at cluster creation; those subnets must have free addresses forever or control plane upgrades fail. The VPC CNI on each node attaches ENIs and assigns secondary IPs (or /28 prefixes) to pods, so the app tier's /20 is really a pod budget: about 4,000 addresses per AZ minus nodes and ENIs. Route tables decide the pod egress path the same way they decide an instance's: private subnet, NAT, Internet Gateway. "Public" meaning "has a route to the IGW" is why a node group accidentally placed in the public tier gets public IPs on its nodes and nothing else changes.
**See it in Kubernetes:**
```bash
aws ec2 describe-subnets --filters Name=tag-key,Values=kubernetes.io/role/internal-elb --query 'Subnets[].[SubnetId,AvailabilityZone,AvailableIpAddressCount]'
kubectl get pods -A -o wide | awk '{print $7}' | sort | uniq -c   # pod IPs are VPC IPs
```
**Say it:** "On EKS the app subnet is the pod budget, and the tags are how controllers find the tiers."
**Ladder:** networking datapath · resources and scale · rung 3 explain.

### Lab 2 — NAT, Bastion, SG vs NACL · [lab](week-06/labs/LABS.md)
**Relates:** strong
**How:** Nodes in private subnets pull images and reach STS through this NAT, one per AZ; BF-27 (NAT in a private subnet) becomes every pod on a fresh node stuck in `ImagePullBackOff` with `i/o timeout`. Security groups are stateful like conntrack, and so is NetworkPolicy: allowing an ingress flow allows its replies. A bastion is replaced by `kubectl exec` and `kubectl debug`, which go through the API server over 443 and leave an audit record; nodes get SSM or IAP, or no login at all.
**The mechanism:** A pod's outbound packet is SNAT-ed to the node's primary IP by the VPC CNI (unless `AWS_VPC_K8S_CNI_EXTERNALSNAT` is set), then follows the node subnet's route table to the NAT. Every node's image pulls, every IRSA token exchange with STS, and every webhook to an external service cross that NAT, which is both the bill and the single point of failure per AZ. `kubectl exec` is an HTTP upgrade to a websocket proxied by the API server to the kubelet's 10250, so its authorization is RBAC on `pods/exec` and its log line is in the audit log; nothing like that exists for SSH, which is the argument for closing port 22 on nodes entirely.
**See it in Kubernetes:**
```bash
kubectl get events -A --field-selector reason=Failed | grep -i 'i/o timeout' | head -3
kubectl auth can-i create pods/exec -n app --as=jane
```
**Say it:** "Pods egress through the node's NAT; exec is an audited websocket through the API server, not SSH."
**Ladder:** networking datapath · authn, authz, admission · rung 3 explain.

### Lab 3 — VPC Endpoints and Flow Logs · [lab](week-06/labs/LABS.md)
**Relates:** strong
**How:** A private EKS cluster is this lab done completely: endpoints for `ecr.api`, `ecr.dkr`, `s3` (image layers), `sts` (IRSA), `ec2` (the CNI), `elasticloadbalancing` (the LB controller), and `logs`, and no NAT at all. Flow logs' REJECT bisection, "never arrived" versus "refused", is the same two-way split as a NetworkPolicy drop (timeout) versus a missing endpoint (refused), and Calico or Cilium flow logs give you the pod-level version.
**The mechanism:** A cluster with a private API endpoint publishes its address only inside the VPC, and `kubectl` from a laptop needs a VPN, a bastion, or `--endpoint-public-access` with a CIDR allow-list. Every AWS call a controller makes then needs a private path: the CNI's `DescribeNetworkInterfaces` to `ec2`, the SDK's `AssumeRoleWithWebIdentity` to `sts`, the kubelet's layer pulls to `s3` through the ECR gateway. A missing endpoint shows up as a controller log line with a connection timeout to an `amazonaws.com` hostname, and the flow log for the node's ENI shows the REJECT. Interface endpoints bill per AZ, so the three-AZ cluster pays three times per service, which is the cost table from this lab at cluster scale.
**See it in Kubernetes:**
```bash
kubectl -n kube-system logs ds/aws-node -c aws-node | grep -i timeout | head -3
aws ec2 describe-vpc-endpoints --query 'VpcEndpoints[].[ServiceName,VpcEndpointType]'
```
**Say it:** "A private cluster is seven endpoints; flow logs tell arrived from refused, and so do CNI flow logs."
**Ladder:** networking datapath · rung 3 explain.

### Lab 4 — S3 Deep Dive · [lab](week-06/labs/LABS.md)
**Relates:** medium
**How:** Object storage is not a volume, and a pod reaches it through an SDK with IRSA, not a mount, except through the Mountpoint CSI driver for read-mostly data. Versioning and lifecycle are the backup story: etcd snapshots (week 27) and Velero PV backups land in a versioned bucket with a lifecycle; ECR applies the same lifecycle idea to image tags. A registry is an object store with a manifest index on top, and a layer pull is a ranged GET.
**The mechanism:** The week-16 IRSA lab's `s3-reader` is this bucket's consumer: a ServiceAccount, a role trusted by the cluster's OIDC provider, a policy scoped to one ARN, and an SDK call from the pod. A `VolumeSnapshot` of an EBS PV is stored by AWS, but a cluster-level backup (Velero) writes object metadata and PV data to S3 with a retention lifecycle, so this lab's transitions and expirations are the retention policy of your disaster recovery. ECR's lifecycle policy expiring untagged images is the registry twin of expiring noncurrent versions.
**See it in Kubernetes:**
```bash
kubectl get csidrivers | grep -i s3 || echo 'no object-store CSI: pods use the SDK'
velero backup get 2>/dev/null || kubectl get volumesnapshots -A
```
**Say it:** "Pods read buckets through IRSA and an SDK; buckets are where cluster backups live."
**Ladder:** storage and CSI · rung 2 debug.

### Lab 5 — S3 Security and Break/Fix · [lab](week-06/labs/LABS.md)
**Relates:** medium
**How:** Layered gates that each can say no, with the outermost overriding, is the admission chain: Pod Security Admission at the namespace, then Kyverno or ValidatingAdmissionPolicy, then the object is stored. BF-26 (S3 works, KMS does not) is the most common IRSA failure after the four named ones: a role that can `GetObject` but not `kms:Decrypt` on the bucket's key. BF-27 is the image-pull timeout above. Serving a private bucket through CloudFront with OAC is the shape of a private registry behind a pull-through cache.
**The mechanism:** Admission plugins run in a fixed order: mutating webhooks first, then schema validation, then validating webhooks, and any validating rejection discards the mutation; Block Public Access at the account level is the equivalent of a cluster-wide policy that namespace labels cannot loosen. A pod whose SDK gets `AccessDenied` from KMS logs it as an S3 error, which is BF-26's lesson again: the failing permission is on the key, not the bucket, and the IRSA policy must name both ARNs.
**See it in Kubernetes:**
```bash
kubectl get validatingwebhookconfigurations,mutatingwebhookconfigurations
kubectl logs deploy/s3-reader | grep -i 'kms\|AccessDenied' | head -3
```
**Say it:** "Admission is layered gates with the outer one winning; and the KMS permission is the one the policy forgot."
**Ladder:** authn, authz, admission · rung 2 debug.

<a id="week-7"></a>

## Week 7 — Compute, Scaling, and Databases

### Lab 1 — ALB and Target Groups · [lab](week-07/labs/LABS.md)
**Relates:** strong
**How:** The AWS Load Balancer Controller turns an Ingress into exactly this: an ALB, a listener, rules from the Ingress paths and hosts, one target group per backend Service. `target-type: ip` registers pod IPs; `instance` registers NodePorts. The target group's health check (`/health`, 15 s, 2/2) is a second health check running beside the readiness probe, and the two disagreeing is the classic "ready but 503". The SG gap that produced `Target.Timeout` is the controller's managed rules between the ALB SG and the node or pod SG. NLB preserving the client IP is `externalTrafficPolicy: Local`.
**The mechanism:** With `target-type: ip`, the controller watches EndpointSlices and registers and deregisters pod IPs as pods come and go; a rolling update is a stream of register, wait for the ALB health check, deregister calls, and the `alb.ingress.kubernetes.io/healthcheck-*` annotations set the numbers you tuned by hand. Pod readiness gates (`elbv2.k8s.aws/pod-readiness-gate-inject`) make a pod not Ready until the ALB reports it healthy, closing the window where Kubernetes thinks a pod is ready and the ALB has not finished registering it. A 503 from the ALB with zero healthy targets is week 14's "no endpoints" seen from outside the cluster.
**See it in Kubernetes:**
```bash
kubectl get ingress web -o jsonpath='{.metadata.annotations}' | jq
aws elbv2 describe-target-health --target-group-arn $(aws elbv2 describe-target-groups --query 'TargetGroups[0].TargetGroupArn' --output text)
```
**Say it:** "An Ingress on EKS is an ALB with pod IPs as targets, and two health checks that must agree."
**Ladder:** networking datapath · controllers · rung 3 explain.

### Lab 2 — Auto Scaling · [lab](week-07/labs/LABS.md)
**Relates:** strong
**How:** A managed node group is this ASG. The cluster autoscaler changes its desired count when pods are Pending for lack of resources; Karpenter skips the ASG and launches instances to fit the pending pods directly. BF-29's launch-and-terminate loop has a Kubernetes twin at the pod level, BF-44's liveness loop, and at the node level: a node that joins, fails a health check, and is replaced forever. Target tracking at 50 % CPU is the HPA on `averageUtilization: 50`, with the same fast-out, slow-in asymmetry (`stabilizationWindowSeconds: 300` on scale-down).
**The mechanism:** Node health in Kubernetes is the kubelet's heartbeat: miss it for `node-monitor-grace-period` (tens of seconds) and the node is `NotReady`; the node lifecycle controller then taints it `unreachable` and, after each pod's `tolerationSeconds` (default 300), evicts the pods so the ReplicaSet makes new ones elsewhere. That five-minute delay is the replacement time you measured here, and a PodDisruptionBudget is what stops a scale-in from taking the last ready replica. HPA reads metrics from the metrics server every 15 seconds, computes `desired = ceil(current × actual / target)`, and applies its scale-up policy immediately and its scale-down after the stabilization window, exactly the two asymmetric numbers from the ASG.
**See it in Kubernetes:**
```bash
kubectl get hpa -o custom-columns=NAME:.metadata.name,MIN:.spec.minReplicas,MAX:.spec.maxReplicas,TARGET:.spec.metrics[0].resource.target.averageUtilization
kubectl describe node k8s-w1 | grep -A3 Taints; kubectl get pdb -A
```
**Say it:** "A node group is an ASG; NotReady plus five minutes is the replacement clock; the HPA is target tracking with a slow scale-down."
**Ladder:** controllers · resources and scale · rung 3 explain.

### Lab 3 — RDS: Multi-AZ and the Measured Failover · [lab](week-07/labs/LABS.md)
**Relates:** strong
**How:** The lesson that the application must reconnect applies unchanged to pods: a pod whose connection pool holds sockets to the old primary sees errors until it retries, whether the database is RDS or a StatefulSet. The CNAME repoint is the headless Service record changing when `postgres-0` is rescheduled. The measured 60 to 120 seconds is the number to compare with an in-cluster database's failover: node failure detection plus pod rescheduling plus EBS detach and attach, usually longer.
**The mechanism:** A StatefulSet pod on a failed node is not rescheduled automatically until the node is confirmed gone, because two `postgres-0` pods writing one volume is worse than downtime; that is the at-most-one guarantee and why `kubectl delete pod --force` on a stateful pod is dangerous. Operators such as CloudNativePG implement what RDS does for you: a primary, replicas with streaming replication, a failover that promotes a replica and repoints a Service. The trade-off this lab prices is the one to say in interviews: RDS costs more and fails over in a minute with no code; an in-cluster database is cheaper and makes you the operator.
**See it in Kubernetes:**
```bash
kubectl get pod postgres-0 -o wide; kubectl delete pod postgres-0; kubectl get pod postgres-0 -w   # the name survives, the IP changes
kubectl get endpointslices -l kubernetes.io/service-name=postgres -o jsonpath='{.items[0].endpoints[0].addresses}'
```
**Say it:** "The app must reconnect either way; the question is whether you or RDS are the failover operator."
**Ladder:** storage and CSI · controllers · rung 3 explain.

### Lab 4 — DynamoDB · [lab](week-07/labs/LABS.md)
**Relates:** medium
**How:** etcd is also a key-value store designed around access patterns, and the API server's key layout is the design: `/registry/<resource>/<namespace>/<name>`. Listing pods in one namespace is a prefix scan, exactly a Query; a field selector that is not an index is a Scan the API server does in memory; label selectors are evaluated in the API server's watch cache, not in etcd. There is no GSI: that is why `kubectl get pods --field-selector spec.nodeName=` works (it is indexed) and most other fields do not.
**The mechanism:** Every object is one etcd key with a protobuf value and a `resourceVersion` that is etcd's revision. The API server keeps a watch cache per resource so most reads never reach etcd, and a `LIST` with a selector is a filter over that cache. The scan cost you measured with `ConsumedCapacity` is the cost of a `kubectl get pods -A` on a 100,000-pod cluster: the API server serialises every object, which is why controllers use informers (one watch, local index) and never poll with lists.
**See it in Kubernetes:**
```bash
sudo ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key get /registry/pods/default --prefix --keys-only | head
kubectl get pods -A --field-selector spec.nodeName=k8s-w1
```
**Say it:** "etcd is keyed by resource, namespace, name; a namespace list is a prefix scan and most selectors are filters in the cache."
**Ladder:** etcd and state · API machinery · rung 3 explain.

### Lab 5 — Lambda, Fargate, Break/Fix · [lab](week-07/labs/LABS.md)
**Relates:** strong
**How:** Fargate on EKS is pods without nodes you manage: each pod gets its own ENI and micro-VM, which is why DaemonSets, `hostNetwork`, `hostPort` and privileged containers cannot run there, and why the ALB must use `target-type: ip`. A Lambda in a private subnet needing NAT is a pod in a private subnet needing NAT. The timeout ordering lesson (the function must outlive its database connect timeout) is `terminationGracePeriodSeconds` versus the app's shutdown, and probe `timeoutSeconds` versus the handler.
**The mechanism:** A Fargate profile matches pods by namespace and labels; matching pods are scheduled by a Fargate scheduler onto AWS-managed capacity, show as nodes named `fargate-ip-...`, and bill per vCPU-second. Because there is no shared node, there is no image cache, so pull time is paid on every pod start, which is the week-4 Dockerfile lab's number again. Timeout ordering in a pod: the kubelet sends SIGTERM, the app should stop accepting, finish in-flight work, and exit before the grace period; a database driver with a connect timeout longer than the grace period leaves work half-done at SIGKILL, exactly the silent death of a Lambda whose timeout is shorter than its connect.
**See it in Kubernetes:**
```bash
kubectl get nodes -l eks.amazonaws.com/compute-type=fargate
kubectl get pod web -o jsonpath='{.spec.terminationGracePeriodSeconds} {.spec.containers[0].livenessProbe.timeoutSeconds}'
```
**Say it:** "Fargate is a pod with its own ENI and no node to share; and the outer timeout must be the longest one."
**Ladder:** kubelet and runtime · networking datapath · rung 2 debug.

<a id="week-8"></a>

## Week 8 — Integration, Security, Monitoring, Cost

### Lab 1 — Decoupling · [lab](week-08/labs/LABS.md)
**Relates:** strong
**How:** The visibility-timeout lesson is pod termination: a consumer pod killed mid-message, by a rollout or a node drain, lets the message reappear, so every consumer must be idempotent. A Job with `parallelism` draining a queue is the work-queue pattern; KEDA scales a Deployment from queue depth the way Lambda's event source mapping does. The DLQ after `maxReceiveCount` is `backoffLimit` and `podFailurePolicy`. Long polling, a request held open until something changes, is how `kubectl get -w` and every informer work.
**The mechanism:** A `watch` is an HTTP response that never ends: the API server streams ADDED, MODIFIED, DELETED events from a `resourceVersion` onward, with periodic BOOKMARK events so a client can resume without a full relist. Informers in every controller are long polls with a local cache, which is why a controller survives an API server restart with one reconnect. The "6× rule" (visibility timeout at least six times the function timeout) has a pod twin: `terminationGracePeriodSeconds` must cover the longest message a consumer handles, and `preStop` can be used to stop pulling new messages before SIGTERM arrives.
**See it in Kubernetes:**
```bash
kubectl get pods -w --output-watch-events -v=6 2>&1 | grep -m3 'GET\|BOOKMARK'
kubectl get scaledobjects -A 2>/dev/null   # KEDA, if installed
```
**Say it:** "A watch is a long poll that never ends; and a consumer pod can be killed mid-message, so be idempotent."
**Ladder:** API machinery · controllers · rung 3 explain.

### Lab 2 — KMS and Secrets · [lab](week-08/labs/LABS.md)
**Relates:** strong
**How:** A Kubernetes Secret in etcd is plaintext until you configure encryption at rest, and the recommended configuration is envelope encryption exactly as here: the API server's KMS provider asks KMS for a data key per secret, encrypts the value locally, stores the encrypted DEK beside the ciphertext, and never sends the data to KMS. EKS does this for you when you enable secrets encryption with a KMS key. External Secrets Operator and the Secrets Store CSI driver are the "source of truth outside the cluster" options from week 14 Lab 3.
**The mechanism:** `EncryptionConfiguration` on the API server lists providers in order; the first is used to write, all are tried to read, and `kubectl get secrets -A -o json | kubectl replace -f -` re-encrypts everything after a key change. The KMS v2 provider keeps a cached DEK and calls the KMS plugin (a Unix socket on the control plane) to wrap it, so a KMS outage does not stop reads of cached keys but does stop new writes, which is a failure mode to say out loud. BF-26 is the operational edge: a role that can read the Secret's source in Secrets Manager but not decrypt with its key gets AccessDenied in the operator's log, not in the pod.
**See it in Kubernetes:**
```bash
sudo etcdctl --endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key get /registry/secrets/default/db | head -c 200 | strings
aws eks describe-cluster --name alpha --query 'cluster.encryptionConfig'
```
**Say it:** "Secrets at rest are envelope-encrypted by the API server with a KMS-wrapped data key, or they are plaintext."
**Ladder:** etcd and state · isolation and security · rung 3 explain.

### Lab 3 — CloudWatch and CloudTrail · [lab](week-08/labs/LABS.md)
**Relates:** strong
**How:** The metric-to-human chain with every link that silently breaks is week 20's Prometheus and Alertmanager chain: a ServiceMonitor whose label does not match (the dimension mismatch), an alert with no receiver (the unconfirmed subscription), `absent()` for missing data, `amtool` for `set-alarm-state`. CloudTrail is the API server audit log: every request, who made it, which verb, which object, at a configured level. EKS ships control-plane logs (api, audit, authenticator, controller manager, scheduler) to CloudWatch.
**The mechanism:** The audit log is produced by the API server itself according to an audit policy that sets a level per rule: None, Metadata, Request, RequestResponse. On kubeadm it is a file behind `--audit-log-path`; on EKS it is the `audit` log type. It is the only record of who ran `kubectl exec` or deleted a namespace, because the kubelet and etcd never see identities. The "alarm never fires" diagnosis maps link by link: the metric exists (the exporter is up), the dimensions match (ServiceMonitor selector and `release` label), the rule evaluates (`promtool check rules`), the route matches (`amtool config routes test`), the receiver works (a test alert).
**See it in Kubernetes:**
```bash
sudo grep -m3 '"verb":"delete"' /var/log/kubernetes/audit.log | jq '{user:.user.username,verb,obj:.objectRef.name}'
aws eks describe-cluster --name alpha --query 'cluster.logging.clusterLogging'
```
**Say it:** "The audit log is CloudTrail for the API server; the alert chain breaks at the same five links."
**Ladder:** authn, authz, admission · resources and scale · rung 3 explain.

### Lab 4 — CloudFront, Route 53, Organizations · [lab](week-08/labs/LABS.md)
**Relates:** medium
**How:** external-dns writes the Route 53 records for your Ingress hosts, alias and all; ACM certificates attach to the ALB through an annotation while cert-manager handles certificates the cluster terminates itself. CloudFront in front of an Ingress is the same OAC idea at the edge. An SCP that caps but never grants is a `ResourceQuota`, a `LimitRange`, or a cluster-wide `ValidatingAdmissionPolicy`: a ceiling on every namespace that a namespace cannot raise.
**The mechanism:** `ResourceQuota` is enforced at admission: a pod that would push the namespace over its CPU, memory, or object count is rejected with a 403 naming the quota, which is the SCP "allowed by policy, blocked by the ceiling" shape. `LimitRange` sets defaults and bounds per pod so quota can be applied at all (a pod with no requests cannot be charged). Both are the platform's version of an Organizations guardrail: the team's admin cannot lift them from inside the namespace.
**See it in Kubernetes:**
```bash
kubectl describe quota -n app; kubectl describe limitrange -n app
kubectl get ingress web -o jsonpath='{.metadata.annotations.external-dns\.alpha\.kubernetes\.io/hostname}'
```
**Say it:** "Quota and LimitRange are SCPs for a namespace: a ceiling nobody inside can raise."
**Ladder:** authn, authz, admission · resources and scale · rung 2 debug.

### Lab 5 — DR, Cost, Break/Fix · [lab](week-08/labs/LABS.md)
**Relates:** strong
**How:** Cluster DR is the pilot-light tier: etcd snapshots to S3 (week 27), persistent volumes backed up by Velero or EBS snapshots, and everything else re-applied from Git by ArgoCD in a new cluster. Tag-based cost allocation is namespace- and label-based allocation in OpenCost or Kubecost, charged on requests rather than usage, which is why over-requesting is the cluster's biggest waste. Spot node groups are the Spot mix from this lab with a PDB to survive reclaims. BF-32 (alarm never fires) is the Alertmanager chain above.
**The mechanism:** A cluster's state is in exactly three places: etcd (every object), Git (the objects' source), and volumes (data). RTO is how fast you can build nodes, restore or re-apply, and reattach data; RPO is the etcd snapshot and volume snapshot cadence. A GitOps cluster shortens the first two to "apply the Application that applies everything" and leaves data as the real recovery work. Cost allocation by requests means a namespace reserving 4 CPUs and using 0.2 pays for 4, because the scheduler reserved them; `kubectl top` versus requests is the rightsizing report, and the Vertical Pod Autoscaler's recommendations are the automated version.
**See it in Kubernetes:**
```bash
kubectl get pods -A -o custom-columns=NS:.metadata.namespace,POD:.metadata.name,REQ:.spec.containers[*].resources.requests.cpu | head
kubectl top pods -A --sum=true 2>/dev/null | tail -1
```
**Say it:** "etcd, Git, volumes: back up the first and third, and the second rebuilds the cluster; cost follows requests."
**Ladder:** lifecycle, upgrades, HA · resources and scale · etcd and state · rung 3 explain.

<a id="week-9"></a>

## Week 9 — SAA Consolidation ★ GATE 2

### Activity 1 — The whiteboard drill · [lab](week-09/labs/LABS.md)
**Relates:** strong
**How:** Redraw the same design with EKS in the app tier and every box has a cluster twin: ALB from the load balancer controller, a managed node group per AZ pair, pods addressed from the VPC, IRSA instead of instance roles, EBS CSI volumes pinned to an AZ, the cluster autoscaler or Karpenter instead of target tracking, RDS unchanged. Then answer the AZ-failure question for a cluster, second by second.
**The mechanism:** An AZ failure on a cluster: kubelets in that AZ stop heartbeating; after the grace period their nodes go NotReady; after `tolerationSeconds` their pods are evicted and recreated on surviving nodes, if those have room (the cluster autoscaler then adds nodes, minutes later). Pods with EBS volumes in the failed AZ cannot be recreated elsewhere, because the volume cannot leave the AZ, which is why stateful workloads need per-AZ replicas or a storage layer that replicates. Topology spread constraints and pod anti-affinity are what put the replicas in different AZs in the first place; PDBs keep the autoscaler from compounding the failure. Saying that chain with the numbers is the Gate 4 version of this Gate 2 drill.
**See it in Kubernetes:**
```bash
kubectl get nodes -L topology.kubernetes.io/zone; kubectl get pods -A -o wide | awk '{print $8}' | sort | uniq -c
kubectl get deploy web -o jsonpath='{.spec.template.spec.topologySpreadConstraints}'
```
**Say it:** "An AZ failure is NotReady, taint, evict, reschedule, and the volumes that cannot follow."
**Ladder:** lifecycle, upgrades, HA · scheduling · rung 3 explain, rung 5 when drawn and narrated.

### Activity 2 — The comparison sprint · [lab](week-09/labs/LABS.md)
**Relates:** background
**How:** Run the same sprint over the Kubernetes pairs when you reach Gate 4: Deployment versus StatefulSet, ClusterIP versus NodePort versus LoadBalancer, Ingress versus Gateway API, HPA versus VPA versus Karpenter, emptyDir versus PVC, Role versus ClusterRole, ConfigMap versus Secret, liveness versus readiness versus startup, taint versus affinity, Helm versus Kustomize. One sentence each, the same fifteen-minute discipline.
**The mechanism:** The AWS pairs resolve on cost or operational overhead; the Kubernetes pairs resolve on one of four axes: who owns the object, whether identity is stable, whether traffic or startup is the question, and where the decision is enforced. Naming the axis is the senior answer; naming the tool is the junior one.
**See it in Kubernetes:**
```bash
kubectl explain deployment.spec --recursive | head -5; kubectl explain statefulset.spec.podManagementPolicy
```
**Say it:** "Every Kubernetes pair resolves on an axis, not a feature list."
**Ladder:** controllers · rung 3 explain.

### Activity 3 — Rebuild your two weakest domains by hand · [lab](week-09/labs/LABS.md)
**Relates:** background
**How:** The method transfers unchanged to the week 29 weak-domain tally: score, find the two weakest exam domains, rebuild them on the kubeadm cluster, retest. The rebuild targets map too: "secure" is RBAC plus NetworkPolicy plus PSA, "resilient" is PDBs plus topology spread plus a drained node, "performing" is HPA plus requests tuned from `kubectl top`, "cost" is Spot node groups plus rightsizing.
**The mechanism:** Rebuilding by hand works because the failure in a multiple-choice domain is usually a mechanism you have read about and never watched happen; the cluster version of this activity is to break the thing and watch the controller respond, which is what every Friday lab trains.
**See it in Kubernetes:**
```bash
kubectl drain k8s-w1 --ignore-daemonsets --delete-emptydir-data && kubectl get pods -A -o wide -w
```
**Say it:** "Weakest domain, rebuild it, retest: the same loop drives week 29."
**Ladder:** lifecycle, upgrades, HA · rung 2 debug.

### Activity 4 — Service limits and numbers · [lab](week-09/labs/LABS.md)
**Relates:** medium
**How:** The cluster has its own list to carry alongside this one, and the exam and interviews both ask for it: 110 pods per node by default; a /24 podCIDR per node; NodePorts 30000 to 32767; 30 seconds of termination grace; a 1-second probe timeout; etcd's 1.5 MiB request limit and ConfigMap and Secret objects capped at 1 MiB; etcd's 2 GB default backend quota, with 8 GB the recommended ceiling; the tested scalability thresholds of 5,000 nodes, 150,000 pods, and 300,000 containers; ServiceAccount tokens that live an hour; join tokens that live a day; client certificates that live a year; five minutes before an unreachable node's pods are evicted.
**The mechanism:** Each number is a mechanism with a dial. `maxPods` is a kubelet flag bounded by the node's podCIDR and, on EKS, by ENI capacity. The 1.5 MiB limit is etcd's gRPC message size, which is why a ConfigMap holding a large file fails at the API, not at the mount. The scalability thresholds are the SIG's tested envelope, not hard limits; past them the API server's watch fan-out and etcd's write rate are what degrade, which is the week-30 scale lab.
**See it in Kubernetes:**
```bash
kubectl get node k8s-w1 -o jsonpath='{.status.allocatable.pods}'
kubectl create configmap big --from-file=big=<(head -c 2M /dev/zero) 2>&1 | tail -1   # fails: too large for etcd
```
**Say it:** "Every limit is a dial on a mechanism, and I can name the mechanism for each one."
**Ladder:** resources and scale · rung 3 explain.

### Activity 5 — Book it, and plan week 10 · [lab](week-09/labs/LABS.md)
**Relates:** none
**How:** Administration: booking the SAA and planning the Terraform month; the Kubernetes thread resumes in week 10 with the state and lifecycle ideas Terraform shares with controllers.

<a id="week-10"></a>

## Week 10 — ★ SAA EXAM · Terraform I

### Lab 1 — HCL Fundamentals · [lab](week-10/labs/LABS.md) · [figure 10.2](week-10/labs/FIGURES.md)
**Relates:** medium
**How:** Terraform is the first declarative system in the program: you describe a desired state, a program diffs it against reality and acts. Kubernetes is the same idea with one difference the lab cannot show: the diff never stops. The lab builds a dependency graph you can print; Kubernetes has no graph at all.
**The mechanism:** `terraform plan` is a one-shot reconcile: read the world, diff, propose, and then a human runs apply. A Kubernetes controller runs the same loop forever against a watch stream, with no plan step and no human. Terraform orders operations by the DAG it built from references; Kubernetes controllers do not coordinate, so a Deployment that needs a Secret that does not exist yet simply fails to start its pods and retries with backoff until the Secret appears. That is why "dependency" in Kubernetes is handled by retry (init containers, backoff, readiness) rather than by ordering. The production failure that follows is the one Terraform never has: a controller silently retrying forever against a typo, with the only evidence in events that expire after an hour.
**See it in Kubernetes:**
```bash
kubectl create deploy web --image=nginx --dry-run=client -o yaml   # the declaration, no graph
kubectl get events -w                                               # the retry loop, visible
```
**Say it:** "Terraform diffs once when I ask; a controller diffs forever and never asks."
**Ladder:** controllers · rung 3.

### Lab 2 — State · [lab](week-10/labs/LABS.md) · [figure 10.3](week-10/labs/FIGURES.md)
**Relates:** medium
**How:** State is Terraform's map from declaration to real resource, kept in a file with a serial and a lock. Kubernetes keeps the same map in etcd, but every object carries its own version and there are no locks.
**The mechanism:** Every object in etcd lives under `/registry/<kind>/<namespace>/<name>` and carries a `resourceVersion`, the etcd modification revision. A write that includes a `resourceVersion` is accepted only if the object still has that version, which is optimistic concurrency: two editors race, one gets a 409 Conflict and must re-read. That replaces Terraform's lock file. State corruption has an analogue too: the kubelet keeps a local pod cache, and the API server keeps a watch cache, so "the state disagrees with the world" shows up as a stale watch rather than a corrupt file. Terraform's `state pull` is `etcdctl get /registry/... --prefix`, and week 27 does the restore the lab does here from an S3 version.
**See it in Kubernetes:**
```bash
kubectl get deploy web -o jsonpath='{.metadata.resourceVersion}'
kubectl get deploy web -o yaml > a.yaml; kubectl edit deploy web; kubectl replace -f a.yaml   # 409 Conflict
```
**Say it:** "Terraform locks the whole state; Kubernetes versions every object and lets the loser retry."
**Ladder:** etcd and state · API machinery · rung 3.

### Lab 3 — Import, State Manipulation, Drift · [lab](week-10/labs/LABS.md) · [figure 10.4](week-10/labs/FIGURES.md)
**Relates:** medium
**How:** Drift is the gap between the declaration and the world, and the lab's answer is a human decision after `plan -refresh-only`. In Kubernetes drift is closed automatically within seconds, which is both the feature and the danger.
**The mechanism:** A ReplicaSet controller that sees two pods when the spec says three creates one; it does not ask. That is `selfHeal` built into every core controller, and ArgoCD extends it to Git in week 16. Import has an analogue in adoption: a ReplicaSet adopts orphan pods whose labels match its selector and whose `ownerReferences` are empty, and `kubectl apply` on an object created some other way records your field ownership in `managedFields` through server-side apply, so the next apply knows which fields are yours. The production failure is the opposite of Terraform's: not unreconciled drift, but a controller "fixing" a hand change you made during an incident, thirty seconds after you made it.
**See it in Kubernetes:**
```bash
kubectl scale deploy web --replicas=5 && kubectl get rs -w       # the controller closes the gap
kubectl get deploy web -o yaml --show-managed-fields | grep -A3 managedFields
```
**Say it:** "Terraform shows me drift; a controller erases it, and so would erase my hotfix."
**Ladder:** controllers · API machinery · rung 3.

### Lab 4 — ⚑ Project Alpha Kickoff · [lab](week-10/labs/LABS.md) · [figure 10.5](week-10/labs/FIGURES.md)
**Relates:** background
**How:** The network module built here is the one EKS lands in during week 16. Its shape already encodes Kubernetes requirements: `/20` app subnets because the VPC CNI gives every pod a real VPC address, two AZs because node groups and the control plane's ENIs spread across them, and subnet tags the load balancer controller discovers by name.
**The mechanism:** On EKS the control plane runs in AWS's account and reaches your nodes through ENIs it creates in your subnets, so the subnets must have free addresses for them as well as for pods. The production failure is IP exhaustion: a `/24` app subnet runs out of pod addresses long before it runs out of nodes.
**Say it:** "The pod network is the VPC, so I sized the subnets for pods, not instances."
**Ladder:** networking datapath · rung 1.

<a id="week-11"></a>

## Week 11 — Terraform II: Modules, Patterns, Testing

### Lab 1 — Module Design · [lab](week-11/labs/LABS.md) · [figure 11.2](week-11/labs/FIGURES.md)
**Relates:** medium
**How:** A module is a contract: typed inputs, outputs, private implementation. Kubernetes has two forms of the same contract: a Helm chart's `values.yaml`, and a CustomResourceDefinition whose `spec` is the input and whose `status` is the output, with a controller as the implementation.
**The mechanism:** A CRD registers a new kind with the API server, including an OpenAPI schema the server validates against on every write and CEL rules that can cross-check fields, exactly like the lab's `validation` blocks. The operator in week 28 is the module body: it watches the custom resource and makes real objects, then writes what it did into `status`. The `provider` rule has an analogue too: a controller that hard-codes which cluster or account it talks to cannot be reused, which is why controllers read credentials from their ServiceAccount, never from their spec. The production failure is a CRD without a schema: every write is accepted, and the controller crashes on the first malformed one.
**See it in Kubernetes:**
```bash
kubectl get crd certificates.cert-manager.io -o jsonpath='{.spec.versions[0].schema}' | head -c 600
kubectl explain certificate.spec
```
**Say it:** "A CRD is a module interface; its schema is the variable validation; the operator is the body."
**Ladder:** API machinery · controllers · rung 3.

### Lab 2 — `for_each` vs `count` · [lab](week-11/labs/LABS.md) · [figure 11.3](week-11/labs/FIGURES.md)
**Relates:** medium
**How:** The lab's lesson is that identity by position is fragile and identity by stable key is safe. Kubernetes built two controllers on exactly that distinction.
**The mechanism:** A Deployment's pods are `count`: anonymous, random suffixes, interchangeable, and when the ReplicaSet controller scales down it picks victims by its own rules (unscheduled first, then by readiness and age, then by the `controller.kubernetes.io/pod-deletion-cost` annotation). A StatefulSet's pods are `for_each`: `db-0`, `db-1`, stable names, each bound to its own PVC by that name, created and deleted in order. Removing the middle of a Deployment is meaningless; removing the middle of a StatefulSet is impossible, because the ordinal is the key. The production failure is the one the lab reproduces: a database run as a Deployment with two replicas, where a scale-down deletes the pod holding the volume and the survivor attaches an empty one.
**See it in Kubernetes:**
```bash
kubectl get pods -l app=web -o name          # random suffixes: count
kubectl get pods -l app=db -o name           # db-0, db-1: for_each
```
**Say it:** "Deployment pods are indexed by nothing; StatefulSet pods are keyed by ordinal, and the PVC follows the key."
**Ladder:** controllers · storage and CSI · rung 3.

### Lab 3 — Environments, Remote State, Refactoring · [lab](week-11/labs/LABS.md) · [figure 11.4](week-11/labs/FIGURES.md)
**Relates:** medium
**How:** Same modules, different inputs, separate state: that is Kustomize overlays, Helm values files, and one ArgoCD Application per environment, which weeks 15 and 16 build. The remote-state-versus-SSM question is the Kubernetes question of how one namespace learns a value another produced.
**The mechanism:** Kubernetes has no cross-object reference by output: a Service name is a DNS contract, a Secret is copied in by an operator, a ConfigMap is written by whoever produced the value. That is the SSM pattern, a published contract, not `terraform_remote_state`, which would be one controller reading another's internal objects. The `moved` block's job, rename without destroy, has no equivalent for most Kubernetes objects: a Deployment's selector is immutable, a StatefulSet's volumeClaimTemplates are immutable, so a rename is a delete and a create, and week 16's `Replace=true` sync option is the admission of that. The production failure is an "environment" that differs from prod by a patch nobody tracked.
**See it in Kubernetes:**
```bash
kubectl kustomize overlays/prod | diff - <(kubectl kustomize overlays/dev)   # only inputs differ
```
**Say it:** "Environments are overlays over one base, and values cross boundaries by contract, not by reaching in."
**Ladder:** controllers · lifecycle, upgrades, HA · rung 2.

### Lab 4 — Validation, Linting, Testing · [lab](week-11/labs/LABS.md) · [figure 11.5](week-11/labs/FIGURES.md)
**Relates:** medium
**How:** The gate stack, fmt, validate, lint, scan, test, has a one-to-one Kubernetes equivalent, and the lab's best lesson, `expect_failures`, is the one most Kubernetes teams skip.
**The mechanism:** `terraform validate` is the API server's schema check, which happens on every write against the OpenAPI schema of the kind, and for CRDs against the schema the CRD author wrote. `tflint` and `checkov` are `kubeconform` and `trivy config` on manifests. `terraform test` with `expect_failures` is `kyverno test` and `conftest verify`: a policy that is never tested with an input that must fail is a policy that may allow everything. Week 19 proves it with a policy typo. The production failure is a validating webhook whose rule has a typo, which admits every pod and reports success.
**See it in Kubernetes:**
```bash
kubectl apply --dry-run=server -f deploy.yaml     # schema and admission, nothing written
kubectl apply -f deploy.yaml --validate=strict     # unknown fields rejected
```
**Say it:** "Server-side dry run is my validate; a policy test that expects a failure is my `expect_failures`."
**Ladder:** authn, authz, admission · rung 2.

### Lab 5 — Break/Fix + ⚑ Alpha · [lab](week-11/labs/LABS.md) · [figure 11.6](week-11/labs/FIGURES.md)
**Relates:** background
**How:** The secret-in-state drill is the secret-in-etcd drill from week 14 Lab 3 in a different file: a password written where the tool stores everything, readable by anyone who can read the store, and rotation first because removal does not un-leak. The remediation order is identical in Kubernetes: rotate upstream, then replace the Secret object, then confirm no pod still holds the old value in its environment.
**Say it:** "State and etcd are both plaintext stores of everything, so rotation comes before removal in both."
**Ladder:** isolation and security · rung 2.

<a id="week-12"></a>

## Week 12 — CI/CD with GitHub Actions and OIDC

### Lab 1 — GitHub Actions Fundamentals · [lab](week-12/labs/LABS.md) · [figure 12.2](week-12/labs/FIGURES.md)
**Relates:** medium
**How:** A workflow is a job that runs to completion on an ephemeral machine with least-privilege permissions, and its outputs are artifacts and images. That is a Kubernetes Job, and many teams run their runners as pods.
**The mechanism:** The Actions Runner Controller runs each job as a pod from a `Job`-like custom resource, scaled by a controller watching the GitHub queue, which is the HPA idea pointed at a queue instead of CPU. The lab's three security rules map directly: pinning an action by SHA is pulling an image by digest, since a tag can move and a digest cannot; declaring `permissions:` is a ServiceAccount with a Role rather than cluster-admin; and the script-injection rule, pass untrusted strings through `env`, is the reason a container's command is an array and not a shell string. The production failure the lab names, a mutable tag repointed, is `imagePullPolicy: Always` on `:latest` deploying something nobody reviewed.
**See it in Kubernetes:**
```bash
kubectl create job once --image=busybox -- sh -c 'echo build && exit 0'; kubectl get job once -w
kubectl get pod -o jsonpath='{.items[0].status.containerStatuses[0].imageID}'   # the digest that actually ran
```
**Say it:** "A workflow is a Job; a pinned action is a digest; `permissions:` is RBAC."
**Ladder:** controllers · isolation and security · rung 2.

### Lab 2 — OIDC Federation · [lab](week-12/labs/LABS.md) · [figure 12.3](week-12/labs/FIGURES.md)
**Relates:** strong
**How:** The lab shows GitHub as an OIDC issuer signing a short-lived JWT that AWS verifies by signature and claim. The Kubernetes API server is an OIDC issuer in exactly the same sense, and every pod's ServiceAccount token is one of these JWTs. The lab never says so.
**The mechanism:** The API server signs ServiceAccount tokens with the key behind `--service-account-signing-key-file` and publishes the discovery document at `/.well-known/openid-configuration` and the public keys at `/openid/v1/jwks`, readable by the `system:service-account-issuer-discovery` role. Since bound tokens became the default (KEP-1205, `pkg/serviceaccount`), a token is minted on demand through the TokenRequest API, bound to a specific pod, scoped to an audience, and expires, typically after an hour; the kubelet refreshes the projected file before expiry. The `sub` claim is `system:serviceaccount:<namespace>:<name>`, which is the string IRSA's trust policy matches in week 16. Audience is what stops a token for the API server being replayed at STS. The production failure is a token read once at startup and cached past its expiry by an application, which then gets 401 from an API that was never down.
**See it in Kubernetes:**
```bash
kubectl get --raw /.well-known/openid-configuration | jq .
kubectl create token default --audience=example --duration=10m | cut -d. -f2 | base64 -d 2>/dev/null | jq .
```
**Say it:** "The API server is an identity provider; a ServiceAccount token is the JWT, and its `sub` is what a trust policy checks."
**Ladder:** authn, authz, admission · rung 3.

### Lab 3 — The Terraform Pipeline · [lab](week-12/labs/LABS.md) · [figure 12.4](week-12/labs/FIGURES.md)
**Relates:** medium
**How:** Gates before apply, one apply at a time, an approval tied to an environment: the lab's pipeline is a push model. Week 16 replaces it with a pull model for Kubernetes, and the reasons map onto this lab's pieces.
**The mechanism:** The pipeline's `concurrency` group is leader election: controllers that must not run twice hold a `Lease` object in `kube-node-lease` or `kube-system` and renew it, and the standby watches the lease rather than a queue. The approval gate is ArgoCD's manual sync or a sync window. The lock file that pins provider versions is the image digest in the manifest. What does not map is where credentials live: this pipeline holds a role that can change prod, which is the push model's exposure; the pull model keeps the deployer inside the cluster with a ServiceAccount and nothing to steal from CI. The production failure is a cancelled apply, and its Kubernetes twin is a controller killed mid-reconcile, which is harmless only because reconcile is written to be re-run.
**See it in Kubernetes:**
```bash
kubectl -n kube-system get lease kube-controller-manager -o yaml | grep -E 'holderIdentity|renewTime'
```
**Say it:** "Concurrency is a Lease, approval is a sync gate, and the credential moves from CI into the cluster."
**Ladder:** controllers · lifecycle, upgrades, HA · rung 2.

### Lab 4 — Containers, ECR, Reusable Workflows · [lab](week-12/labs/LABS.md) · [figure 12.5](week-12/labs/FIGURES.md)
**Relates:** strong
**How:** The lab builds a multi-architecture image with semver and SHA tags and attestations. The consumer of all of that is the kubelet, and the lab stops at the push.
**The mechanism:** When a pod is scheduled, the kubelet's image manager (`pkg/kubelet/images`) asks containerd over the CRI to pull; containerd fetches the manifest list, picks the entry for the node's architecture, and stores every layer in a content store addressed by digest, so two tags for the same image share one copy. `imagePullPolicy` decides whether a tag is resolved again: `IfNotPresent` on a mutable tag means a node that already has an old `:latest` keeps running it after every other node pulled a new one, which is the production failure, and why the SHA tag or a digest reference is the only honest pointer. Pull credentials come from `imagePullSecrets` or, on EKS, from the node's instance role through a credential provider; a 401 surfaces as `ImagePullBackOff` with the kubelet retrying on the same doubling backoff as a crash loop. The provenance attestation pushed here is what Kyverno fetches at admission in week 18.
**See it in Kubernetes:**
```bash
kubectl get pod web -o jsonpath='{.status.containerStatuses[0].imageID}'   # what ran, by digest
sudo crictl images --digests                                               # on a node: the content store
```
**Say it:** "The kubelet pulls by platform and stores by digest; a tag is a pointer that can lie."
**Ladder:** kubelet and runtime · rung 3.

### Lab 5 — Break/Fix, Branch Protection, ⚑ Alpha · [lab](week-12/labs/LABS.md) · [figure 12.6](week-12/labs/FIGURES.md)
**Relates:** medium
**How:** Branch protection with `enforce_admins` makes the Git branch the only path to production. In Kubernetes that rule becomes RBAC: nobody but the GitOps controller holds write on production namespaces.
**The mechanism:** The pull model only means something when `kubectl apply` to prod is impossible for humans, which is a RoleBinding question, not a policy question: developers get `get`, `list`, `watch` and `port-forward`; the ArgoCD application controller's ServiceAccount gets the writes. The RBAC-based ArgoCD projects then limit which repositories may deploy where. The production failure is the one branch protection prevents in Git: an admin applying a manifest by hand because it was faster, and the controller reverting it a minute later or, worse, the controller being paused and the hand change living on untracked.
**See it in Kubernetes:**
```bash
kubectl auth can-i create deployments -n prod --as=jane            # should be no
kubectl auth can-i create deployments -n prod --as=system:serviceaccount:argocd:argocd-application-controller
```
**Say it:** "Branch protection on `main` is a RoleBinding that gives write only to the controller."
**Ladder:** authn, authz, admission · rung 2.

<a id="week-13"></a>

## Week 13 — Alpha Completion + Terraform Associate Prep ★ GATE 3

### Lab 1 — ⚑ Alpha to Acceptance Criteria · [lab](week-13/labs/LABS.md) · [figure 13.2](week-13/labs/FIGURES.md)
**Relates:** medium
**How:** Two of the acceptance criteria are Kubernetes lessons in AWS form: alarm on symptoms, and find what is still billing after destroy.
**The mechanism:** Symptom alarms become Prometheus alerts on SLIs in week 20, and the "prove the notification path" step is the Alertmanager test. The orphan scan has a sharper Kubernetes answer: finalizers. A Service of type LoadBalancer carries `service.kubernetes.io/load-balancer-cleanup`, an Ingress on EKS carries `ingress.k8s.aws/resources`, a PVC carries `kubernetes.io/pvc-protection`; the object cannot leave etcd until the controller that owns the cloud resource confirms it deleted it. Delete the cluster without deleting those objects first and the controller is gone before it can clean up, which is week 16's orphaned ALB bill. The production failure in the other direction is a namespace stuck `Terminating` because a finalizer's controller no longer exists.
**See it in Kubernetes:**
```bash
kubectl get svc -A -o custom-columns=NAME:.metadata.name,FIN:.metadata.finalizers
kubectl get ns stuck -o jsonpath='{.spec.finalizers}'
```
**Say it:** "A finalizer is a controller's promise to clean up a cloud resource before the object is allowed to disappear."
**Ladder:** controllers · lifecycle, upgrades, HA · rung 2.

### Lab 2 — ⚑ Documentation · [lab](week-13/labs/LABS.md) · [figure 13.3](week-13/labs/FIGURES.md)
**Relates:** background
**How:** The measured numbers the lab asks for, apply time, merge-to-deployed, terminate-to-healthy, are the same numbers you will measure for the Kubernetes stack in weeks 16 and 21: sync time, rollout time, and the time from a pod kill to a ready replacement. Keep the table's columns; the rows change.
**Say it:** "Every deployment system gets the same three numbers: how long to change, how long to recover, what it costs."
**Ladder:** resources and scale · rung 1.

### Lab 3 — ⚑ The Clean-Account Test · [lab](week-13/labs/LABS.md) · [figure 13.4](week-13/labs/FIGURES.md)
**Relates:** medium
**How:** From nothing to a working system by following the README, then kill an instance and time the recovery. The Kubernetes version of both halves is cheaper and faster, which is the point of the comparison.
**The mechanism:** The clean-account test becomes cluster bootstrap: a fresh cluster, one ArgoCD app-of-apps applied, and everything else arrives from Git, which week 16 Lab 4 builds. The recovery test becomes a ReplicaSet doing in seconds what the ASG did in minutes: the controller sees one pod fewer than `replicas`, creates one, the scheduler binds it, the kubelet pulls and starts it, and the readiness probe decides when the EndpointSlice includes it. The measured number here is the gap between a pod disappearing from the slice and its replacement appearing, which is usually dominated by image pull and probe timing, both of which you control.
**See it in Kubernetes:**
```bash
kubectl delete pod -l app=web --wait=false; kubectl get endpointslices -l kubernetes.io/service-name=web -w
```
**Say it:** "The clean-account test is a cluster bootstrapped from Git; the recovery test is a ReplicaSet and a readiness probe."
**Ladder:** controllers · rung 2.

### Lab 4 — Terraform Associate Prep · [lab](week-13/labs/LABS.md) · [figure 13.5](week-13/labs/FIGURES.md)
**Relates:** none
**How:** Exam preparation for HCP Terraform; the run lifecycle it covers has an ArgoCD analogue, but nothing here builds Kubernetes understanding.

### Lab 5 — Week 14 Preparation · [lab](week-13/labs/LABS.md) · [figure 13.6](week-13/labs/FIGURES.md)
**Relates:** none
**How:** Job-search setup. No Kubernetes thread.

<a id="week-14"></a>

## Week 14 — ★ TF ASSOCIATE · ★ APPLICATIONS BEGIN · Kubernetes I

### Lab 1 — Architecture and Pods · [lab](week-14/labs/LABS.md) · [figure 14.2](week-14/labs/FIGURES.md)
**Relates:** strong
**How:** The lab and its figure show the components and the five events. What they leave as a word is "watch": how the scheduler and the kubelet learn about a pod without anything calling them.
**The mechanism:** Every component holds an informer: it lists a kind once, then opens a watch from the `resourceVersion` it got, and the API server streams changes from its watch cache, which is itself fed by one etcd watch per kind. The scheduler's informer filters on pods with an empty `nodeName`; when it chooses, it does not edit the pod, it POSTs to the `pods/<name>/binding` subresource, and the API server writes `nodeName`. The kubelet's informer filters on `spec.nodeName == its name`, so it never sees other nodes' pods. Once a pod arrives, the kubelet creates a sandbox (the pause container that holds the network and IPC namespaces), runs init containers to completion in order, then starts app containers, and its pod lifecycle event generator (`pkg/kubelet/pleg`) relists the runtime every second to notice containers dying. The `readOnlyRootFilesystem` crash is the overlay root mounted read-only while nginx opens `/var/cache/nginx` for writing; the `emptyDir` is a directory under `/var/lib/kubelet/pods/<uid>/volumes/` bind-mounted in. Production failure: "PLEG is not healthy" when the runtime stalls, which turns the node NotReady and evicts every pod on it.
**See it in Kubernetes:**
```bash
kubectl get pods -w -v=6 2>&1 | grep -i watch | head -2      # the watch request itself
docker exec mastery-worker ls /var/lib/kubelet/pods/           # one directory per pod UID
```
**Say it:** "Nothing calls the scheduler or the kubelet; each one watches the API server for the pods that are its business."
**Ladder:** API machinery · kubelet and runtime · rung 3.

### Lab 2 — Deployments, Services, Ingress · [lab](week-14/labs/LABS.md) · [figure 14.3](week-14/labs/FIGURES.md)
**Relates:** strong
**How:** The figure says "kube-proxy writes iptables rules". Underneath is a controller chain that turns a selector into addresses, and a packet path you can read rule by rule.
**The mechanism:** The deployment controller (`pkg/controller/deployment`) hashes the pod template into `pod-template-hash`, names the ReplicaSet after it, and sets `ownerReferences` so garbage collection can cascade. The ReplicaSet controller creates pods and tracks "expectations" so a slow API does not make it create twice. Separately, the API server allocates the ClusterIP from the service CIDR, and the endpointslice controller watches pods matching the selector and writes EndpointSlices, up to a hundred endpoints each, with `ready`, `serving` and `terminating` conditions taken from the pod's readiness. kube-proxy watches Services and EndpointSlices and, in iptables mode (`pkg/proxy/iptables`), writes `KUBE-SERVICES` → `KUBE-SVC-<hash>` → one `KUBE-SEP-<hash>` per endpoint, choosing with the `statistic` match at equal probability and DNATing in `nat PREROUTING`; conntrack remembers the choice for the connection. The nftables mode (`pkg/proxy/nftables`) does the same with maps instead of chains and scales better. The Ingress is only data; Contour watches it and the EndpointSlices and programs Envoy. Production failure: a full conntrack table drops new connections with nothing in any Kubernetes object to show it.
**See it in Kubernetes:**
```bash
kubectl get endpointslices -l kubernetes.io/service-name=web -o yaml | grep -B2 -A4 conditions
docker exec mastery-worker iptables -t nat -L KUBE-SERVICES -n | grep web
```
**Say it:** "Selector to EndpointSlice to iptables: three watchers, and the ClusterIP exists only as a DNAT rule."
**Ladder:** controllers · networking datapath · rung 3.

### Lab 3 — Config, Secrets, Namespaces · [lab](week-14/labs/LABS.md) · [figure 14.4](week-14/labs/FIGURES.md)
**Relates:** strong
**How:** The figure draws where a Secret leaks. Underneath is how it reaches a pod at all, and why a file updates while an environment variable does not.
**The mechanism:** The Secret is written to etcd under `/registry/secrets/<ns>/<name>`, plaintext unless an `EncryptionConfiguration` wraps it; the KMS v2 provider (KEP-3299) envelope-encrypts each object with a data key, the same shape as week 8's envelope encryption. When a pod mounts it, the kubelet's secret manager watches that one Secret (the default `Watch` change-detection strategy) and writes it into a tmpfs under `/var/lib/kubelet/pods/<uid>/volumes/kubernetes.io~secret/`, as a timestamped directory with a `..data` symlink swapped atomically, so a reader never sees a half-written file. An environment variable is read once when the container is created and never again, and a `subPath` mount copies the file at mount time and is never updated either; both are the reason "we rotated it and nothing changed". A namespace is a key prefix in etcd and a field in RBAC and quota checks; it is not a network boundary, which week 19 makes concrete. Production failure: an etcd backup copied to a laptop, and every Secret with it.
**See it in Kubernetes:**
```bash
docker exec mastery-worker sh -c 'ls -la /var/lib/kubelet/pods/*/volumes/kubernetes.io~secret/*/'   # the ..data symlink
sudo etcdctl get /registry/secrets/default/db --cacert ... --cert ... --key ... | strings | head  # on k8s-cp
```
**Say it:** "A mounted Secret is a tmpfs the kubelet keeps in sync through a symlink swap; an env var is a copy taken once."
**Ladder:** etcd and state · kubelet and runtime · rung 3.

### Lab 4 — Break/Fix Friday #5 · [lab](week-14/labs/LABS.md) · [figure 14.5](week-14/labs/FIGURES.md)
**Relates:** strong
**How:** The figure is the diagnostic ladder. Underneath are the three mechanisms that produce the three symptoms, and the reason the events you read exist at all.
**The mechanism:** `ImagePullBackOff` is the kubelet's image manager retrying a CRI `PullImage` that returned an error, with a backoff that starts at ten seconds and doubles to five minutes; no container ran, so `logs` has nothing. `CrashLoopBackOff` is the same backoff applied to a container that exited, whatever the exit code, because `restartPolicy: Always` means "keep it running"; the kubelet records the exit in `lastState.terminated` and 137 means the cgroup's `memory.max` was hit and the kernel sent SIGKILL, which the kubelet reports as `OOMKilled`. "No endpoints" is the endpointslice controller finding no pod whose labels match or whose readiness is true. Every one of those is announced by an Event object written by the component that saw it, with a TTL of one hour by default, which is why an outage diagnosed the next morning has no events left. Production failure: the pull backoff hides a registry outage for minutes before anyone notices because the old pods keep serving.
**See it in Kubernetes:**
```bash
kubectl get events --field-selector reason=BackOff -o custom-columns=T:.lastTimestamp,MSG:.message
kubectl get pod crash3 -o jsonpath='{.status.containerStatuses[0].lastState.terminated.exitCode}'
```
**Say it:** "Two of the three symptoms are the same kubelet backoff; the third is a controller finding an empty selector."
**Ladder:** kubelet and runtime · rung 3.

### Lab 5 — Port the Week-4 Stack · [lab](week-14/labs/LABS.md) · [figure 14.6](week-14/labs/FIGURES.md)
**Relates:** strong
**How:** The lab maps Compose to objects. Underneath, three controllers and the kubelet's prober cooperate to make `depends_on: service_healthy` true without anyone ordering anything.
**The mechanism:** The StatefulSet controller creates `postgres-0`, waits for it to be Running and Ready before any `postgres-1`, and creates its PVC from the template with the pod's name baked in; the `kubernetes.io/pvc-protection` finalizer keeps the claim alive after the pod is deleted. The headless Service has no ClusterIP, so CoreDNS answers the Service name with the pod addresses from the EndpointSlice and `postgres-0.postgres.<ns>.svc.cluster.local` with one address. The app's init container polls port 5432 until the kernel answers, which is why no controller needs to know about the dependency. Then the kubelet's prober (`pkg/kubelet/prober`) runs the three probes from the node: startup holds the others off, liveness restarts the container, readiness flips the pod's `Ready` condition, and only that condition moves the pod into the Service's EndpointSlice. Production failure: a readiness probe on a path that depends on the database, so a database blip removes every app pod from the Service at once.
**See it in Kubernetes:**
```bash
kubectl get pod postgres-0 -o jsonpath='{.status.conditions}' | jq
kubectl run -it --rm d --image=busybox -- nslookup postgres-0.postgres
```
**Say it:** "Ordering comes from readiness conditions and a port check, not from a dependency graph."
**Ladder:** controllers · DNS · storage and CSI · rung 3.

<a id="week-15"></a>

## Week 15 — Kubernetes II: Operations and Debugging

### Lab 1 — Probes, Resources, QoS · [lab](week-15/labs/LABS.md) · [figure 15.2](week-15/labs/FIGURES.md)
**Relates:** strong
**How:** The lab's sentence is "CPU is throttled, memory is killed". Underneath are cgroup files the kubelet writes, and a kernel that enforces them without knowing Kubernetes exists.
**The mechanism:** The kubelet's container manager (`pkg/kubelet/cm`) builds a cgroup v2 tree: `kubepods.slice`, then `kubepods-burstable.slice` and `kubepods-besteffort.slice`, then one cgroup per pod. A CPU limit of `100m` becomes `cpu.max = 10000 100000`: ten milliseconds of every hundred, enforced by the CFS scheduler, and `cpu.stat` counts `nr_throttled`. A memory limit becomes `memory.max`, and the first allocation over it triggers the kernel OOM killer, which picks a process in the cgroup; the kubelet sees the exit and writes `OOMKilled`. QoS is a side effect of requests and limits and it sets `oom_score_adj`: Guaranteed pods get -997, BestEffort 1000, Burstable in between, so when the node itself runs out of memory the kernel kills BestEffort first. Before that happens the kubelet's eviction manager (`pkg/kubelet/eviction`) acts on its own thresholds, `memory.available` under 100Mi by default, evicting in the same order. Probes are run by the kubelet from the node's network namespace, and a liveness failure is a container kill followed by the normal restart backoff. Production failure: CFS throttling adding tens of milliseconds of latency to a service whose CPU graph looks idle.
**See it in Kubernetes:**
```bash
docker exec mastery-worker sh -c 'cat /sys/fs/cgroup/kubepods.slice/kubepods-burstable.slice/*/cpu.max'
docker exec mastery-worker sh -c 'cat /proc/$(pgrep -f stress | head -1)/oom_score_adj'
```
**Say it:** "A limit is a cgroup file; the kernel enforces it; the kubelet only reads the result."
**Ladder:** kubelet and runtime · resources and scale · rung 3.

### Lab 2 — Scheduling, HPA, PDB · [lab](week-15/labs/LABS.md) · [figure 15.3](week-15/labs/FIGURES.md)
**Relates:** strong
**How:** Three controllers change pod count, says the figure. Underneath, the scheduler is a pipeline of plugins, the autoscaler is a formula on a timer, and the drain is an API subresource that refuses.
**The mechanism:** The scheduler (`pkg/scheduler/framework`) runs each pending pod through extension points: PreFilter, Filter (NodeResourcesFit, TaintToleration, NodeAffinity, InterPodAffinity remove nodes), PostFilter (preemption, evicting lower-priority pods if that would make room), Score, Reserve, and Bind. A pod that is Pending forever has an empty list after Filter, and the event names the plugin that emptied it. The HPA controller recomputes every fifteen seconds: desired = ceil(current × observed/target), with a ten percent tolerance and the stabilization windows the lab sets, reading utilization through the metrics API that metrics-server serves. A drain does not delete pods; it POSTs to each pod's `eviction` subresource, and the API server consults PodDisruptionBudgets before accepting, returning 429 when the budget would be violated, so a one-replica PDB with `minAvailable: 1` is refused forever. Taints with `NoExecute` are enforced by the node lifecycle controller, which also taints nodes `not-ready` and `unreachable`, and every pod carries a default five-minute toleration for both. Production failure: a node upgrade hanging at 2 a.m. on a PDB nobody remembers writing.
**See it in Kubernetes:**
```bash
kubectl describe pod pending | grep -A2 FailedScheduling          # the plugin that said no
kubectl get pod web-0 -o jsonpath='{.spec.tolerations}' | jq      # the 300 s defaults
```
**Say it:** "Filter empties the node list, the HPA runs a formula every fifteen seconds, and drain is an eviction the API can refuse."
**Ladder:** scheduling · controllers · rung 3.

### Lab 3 — Storage · [lab](week-15/labs/LABS.md) · [figure 15.4](week-15/labs/FIGURES.md)
**Relates:** strong
**How:** The lab moves a claim from Pending to Bound. Underneath is a hand-off between four controllers and a driver that speaks a gRPC interface, which is why "PVC Pending" has so many causes.
**The mechanism:** The PV controller in kube-controller-manager matches claims to volumes; when nothing matches, the StorageClass's provisioner name tells which driver's external-provisioner sidecar should act, and that sidecar calls the driver's `CreateVolume` over the CSI gRPC socket and creates the PV object. With `WaitForFirstConsumer` nothing happens until the scheduler's VolumeBinding plugin picks a node and writes `volume.kubernetes.io/selected-node` on the claim, so the volume lands in the right zone. Then the attach/detach controller creates a `VolumeAttachment`, the external-attacher calls `ControllerPublishVolume` (attach the disk to the node), and the kubelet calls `NodeStageVolume` and `NodePublishVolume` (format, mount, bind-mount into the pod) through the driver's socket under `/var/lib/kubelet/plugins/`. `ReadWriteOnce` is the attach step: a block disk attaches to one node, so the second pod on another node waits with a `Multi-Attach error`. Reclaim policy is executed by the PV controller after the claim is gone, and the `pvc-protection` finalizer delays that until no pod uses the claim. The Jobs thread is a different controller: the Job controller tracks pods with a finalizer so a pod it has already counted cannot be counted twice, and the CronJob controller stops creating runs after a hundred missed schedules. Production failure: a volume stuck attached to a node that died, so its pod cannot start anywhere else until the attachment times out.
**See it in Kubernetes:**
```bash
kubectl get volumeattachments
kubectl get pvc data-db-0 -o jsonpath='{.metadata.annotations}' | jq
```
**Say it:** "Provision, attach, stage, publish: four steps, four actors, and RWO is enforced at attach."
**Ladder:** storage and CSI · rung 3.

### Lab 4 — RBAC · [lab](week-15/labs/LABS.md) · [figure 15.5](week-15/labs/FIGURES.md)
**Relates:** strong
**How:** The figure is who, may do what, where. Underneath is a chain of authenticators and authorizers that every request passes through before RBAC is even consulted, and three verbs that let RBAC be escalated.
**The mechanism:** A request arrives with a credential: a client certificate whose CN is the user and whose organizations are groups, a ServiceAccount JWT the API server verifies against its own keys, or on EKS a token checked by the IAM authenticator webhook. Authentication yields a user, groups and a UID. Then the authorizer chain runs in order; kubeadm and EKS set `Node,RBAC`: the Node authorizer first lets a kubelet read only the Secrets and ConfigMaps of pods bound to it, then the RBAC authorizer (`plugin/pkg/auth/authorizer/rbac`) walks every binding in the namespace and every cluster binding looking for a rule that allows the verb on the resource and subresource. `pods/log` is a subresource, which is why the lab's missing-verb break works. There is no deny rule; the first allow wins and nothing can subtract. `kubectl auth can-i` is a `SelfSubjectAccessReview` the server evaluates the same way. The verbs `escalate` and `bind` exist because a user who can create Roles could otherwise grant themselves more than they hold; and `impersonate` lets you test as anyone, through the `Impersonate-User` header. Production failure: a ClusterRoleBinding to `cluster-admin` for a group that later grows.
**See it in Kubernetes:**
```bash
kubectl get --raw /apis/authorization.k8s.io/v1 >/dev/null && kubectl auth can-i --list --as=system:serviceaccount:shop:deployer -n shop
kubectl get clusterrolebindings -o json | jq -r '.items[] | select(.roleRef.name=="cluster-admin") | .metadata.name'
```
**Say it:** "Authenticate to a user and groups, Node authorizer first, then RBAC looks for one allow and can never deny."
**Ladder:** authn, authz, admission · rung 3.

### Lab 5 — Break/Fix Friday #6: build the Gate 4 set · [lab](week-15/labs/LABS.md) · [figure 15.6](week-15/labs/FIGURES.md)
**Relates:** strong
**How:** Five faults, one script. Underneath, every fault announces itself through the same two channels, conditions and events, and reading those channels is the skill the Gate measures.
**The mechanism:** A pod carries conditions (`PodScheduled`, `Initialized`, `ContainersReady`, `Ready`), each with a reason and a timestamp; the one that is false first is the layer that failed. A node carries conditions (`MemoryPressure`, `DiskPressure`, `PIDPressure`, `Ready`) set by the kubelet and `Ready=Unknown` set by the node lifecycle controller when the node's Lease in `kube-node-lease` stops being renewed. Events are separate objects written by whichever component noticed something, so `describe` is a join of the object and the events that reference it. The OOM case is a `lastState`; the taint case is a `FailedScheduling` event from the scheduler; the PVC case is a `ProvisioningFailed` event from the provisioner; the RBAC case is not an event at all, it is a 403 in the response body, which is why reading the error text is the first command. Production failure: an on-call engineer running `logs` on a pod that has no container, because the condition that says so was never read.
**See it in Kubernetes:**
```bash
kubectl get pod -o custom-columns=NAME:.metadata.name,SCHED:'.status.conditions[?(@.type=="PodScheduled")].status',READY:'.status.conditions[?(@.type=="Ready")].status'
kubectl -n kube-node-lease get lease -o custom-columns=NODE:.metadata.name,RENEWED:.spec.renewTime
```
**Say it:** "Conditions say which layer failed; events say why; the Lease says whether the node is still talking."
**Ladder:** kubelet and runtime · API machinery · rung 2.

### Lab 6 — Helm · [lab](week-15/labs/LABS.md) · [figure 15.7](week-15/labs/FIGURES.md)
**Relates:** strong
**How:** Helm templates and keeps a release history; Kustomize patches. Underneath, both end at the same API call, and where Helm keeps its history is a Kubernetes object with a size limit.
**The mechanism:** `helm install` renders templates client-side, then stores the whole release, manifest included, gzipped and base64-encoded, in a Secret of type `helm.sh/release.v1` in the target namespace, one per revision; `rollback` re-applies an older Secret's manifest. Every object in etcd is capped by etcd's request limit of about 1.5 MB, so a chart that renders a huge ConfigMap can fail at exactly that store. On upgrade Helm computes a three-way merge between the last stored manifest, the new one, and the live object, which is how it tolerates a field a controller added. Kustomize does no bookkeeping: `kubectl apply -k` is the same `apply` as any manifest, and with server-side apply the API server records field ownership in `managedFields` so two appliers of the same object conflict on the fields they both claim rather than overwriting. ArgoCD renders both tools in its repo-server and applies the result itself, which is why a chart deployed through ArgoCD has no Helm release Secret. Production failure: `helm upgrade` after someone edited the live object by hand, and the three-way merge keeping the hand edit.
**See it in Kubernetes:**
```bash
kubectl -n shop get secret -l owner=helm -o custom-columns=NAME:.metadata.name,STATUS:.metadata.labels.status
kubectl -n shop get secret sh.helm.release.v1.shop.v1 -o jsonpath='{.data.release}' | base64 -d | base64 -d | gunzip | head -c 400
```
**Say it:** "Helm's history is a Secret per revision; Kustomize has no history because `apply` already tracks field ownership."
**Ladder:** API machinery · rung 3.

<a id="week-16"></a>

## Week 16 — EKS and GitOps with ArgoCD

### Lab 1 — EKS via Terraform · [lab](week-16/labs/LABS.md) · [figure 16.2](week-16/labs/FIGURES.md)
**Relates:** strong
**How:** One module call produces a cluster. Underneath, the control plane you cannot see still reaches into your VPC, pods get real VPC addresses, and your `kubectl` authenticates through a webhook, all of which explain the week's failures.
**The mechanism:** EKS runs the API servers and etcd in an AWS-owned account; it creates ENIs in your subnets so the API server can call kubelets on 10250 and your admission webhooks, which is why a security group on those ENIs can break Kyverno. The VPC CNI gives each pod a secondary IP from the node's ENIs (or a `/28` prefix with prefix delegation), so pods are routable in the VPC and the `/20` subnets from week 10 matter. `aws eks update-kubeconfig` installs an exec credential plugin: `kubectl` runs `aws eks get-token`, which produces a presigned STS `GetCallerIdentity` request, and the API server's token webhook (the IAM authenticator) verifies it and maps the IAM principal to a Kubernetes user and groups, through access entries now or the `aws-auth` ConfigMap before. Node groups are an ASG and a launch template with IMDSv2 required; the kubelet on each node joins with a bootstrap token and the node's IAM role is what the authenticator maps to `system:nodes`. Add-ons are ordinary Deployments and DaemonSets AWS manages. Production failure: `aws-auth` edited wrong, locking every human out of a running cluster.
**See it in Kubernetes:**
```bash
kubectl config view --minify -o jsonpath='{.users[0].user.exec.args}'
kubectl get pods -A -o wide | head         # pod IPs are VPC IPs
```
**Say it:** "The control plane is elsewhere but its ENIs are in my subnets, and my kubectl token is a presigned STS call."
**Ladder:** lifecycle, upgrades, HA · authn, authz, admission · rung 3.

### Lab 2 — IRSA · [lab](week-16/labs/LABS.md) · [figure 16.3](week-16/labs/FIGURES.md)
**Relates:** strong
**How:** The lab decodes the token. Underneath is the TokenRequest API from week 12, a mutating webhook that adds a projected volume, and a discovery document EKS publishes so STS can verify a key it has never been given.
**The mechanism:** The pod identity webhook is a MutatingAdmissionWebhook that sees the ServiceAccount annotation and adds to the pod a `projected` volume with a `serviceAccountToken` source, `audience: sts.amazonaws.com`, and an expiry, plus the two environment variables. The kubelet asks the API server for that token through `TokenRequest`, bound to the pod's UID, and rewrites the file before it expires. STS fetches the signing keys from `oidc.eks.<region>.amazonaws.com/id/<cluster>/keys`, which EKS serves from the same `--service-account-jwks-uri` the API server exposes, so the trust chain is: cluster signing key, published JWKS, STS verifying signature then matching `sub` against the role's condition. EKS Pod Identity replaces the webhook with a DaemonSet agent on the link-local address 169.254.170.23 and the SDK's container-credentials provider, so no OIDC provider and no annotation on the trust policy. Production failure: a long-running process that read the token file once at startup and keeps presenting an expired JWT.
**See it in Kubernetes:**
```bash
kubectl -n shop get pod awscli -o jsonpath='{.spec.volumes[?(@.name=="aws-iam-token")].projected}' | jq
kubectl get --raw /openid/v1/jwks | jq '.keys[0].kid'
```
**Say it:** "A webhook adds a projected token with the STS audience; STS verifies it against keys the cluster publishes."
**Ladder:** authn, authz, admission · rung 4.

### Lab 3 — Controllers and External Secrets · [lab](week-16/labs/LABS.md) · [figure 16.4](week-16/labs/FIGURES.md)
**Relates:** strong
**How:** Two controllers turn annotations into cloud resources. Underneath they are controller-runtime programs with the same loop as the Deployment controller, and they use finalizers and owner references to keep cloud and cluster consistent.
**The mechanism:** The load balancer controller watches Ingresses with class `alb`, Services, and EndpointSlices; for `target-type: ip` it creates a `TargetGroupBinding` custom resource and keeps the AWS target group's registered pod IPs equal to the ready endpoints, re-registering on every slice change. It discovers subnets by tag and adds the finalizer `ingress.k8s.aws/resources` so the ALB is deleted before the Ingress object can go. External Secrets reconciles each `ExternalSecret` on its `refreshInterval`, reads Secrets Manager with the IRSA identity of its own ServiceAccount, and writes a Kubernetes Secret with an `ownerReference` to the ExternalSecret, so deleting the ExternalSecret garbage-collects the Secret. From there the kubelet's secret watcher from week 14 updates file mounts in place. Production failure: a Secret the operator owns edited by hand and silently overwritten on the next refresh.
**See it in Kubernetes:**
```bash
kubectl get targetgroupbindings -A
kubectl -n shop get secret db-credentials -o jsonpath='{.metadata.ownerReferences}' | jq
```
**Say it:** "Each controller watches its object, calls AWS, and leaves a finalizer or an owner reference so the two sides cannot drift apart."
**Ladder:** controllers · rung 3.

### Lab 4 — ArgoCD · [lab](week-16/labs/LABS.md) · [figure 16.5](week-16/labs/FIGURES.md)
**Relates:** strong
**How:** The figure is the pull loop. Underneath, ArgoCD is three components, its diff is computed against a cache of every kind in the cluster, and sync is the same `apply` you type.
**The mechanism:** The repo-server clones Git and renders Helm or Kustomize into plain manifests. The application controller keeps informers on every resource kind that exists in the cluster, so its cache is the live state; it diffs rendered against live, normalizing defaulted fields, and reports `OutOfSync`. Sync is `kubectl apply` per object, optionally server-side, in waves ordered by the annotation, with hooks before and after, and health is judged by built-in and Lua checks on each kind's status. `selfHeal` is the controller reacting to a live-state watch event rather than a Git poll, which is why a hand scale is reverted in seconds while a Git change waits for the poll interval. `prune` deletes live objects absent from Git. An immutable field, a Deployment's selector, makes `apply` fail with a 422, and `Replace=true` turns it into a delete and create. The credential story is RBAC: the controller's ServiceAccount is cluster-admin by default, and ArgoCD projects narrow which repos may write which namespaces. Production failure: an `OutOfSync` that never clears because a mutating webhook changes the object after every apply.
**See it in Kubernetes:**
```bash
argocd app diff shop
kubectl -n argocd get application shop -o jsonpath='{.status.sync.status} {.status.health.status}'
```
**Say it:** "Render, diff against a live cache, apply in waves, and react to live changes faster than to Git."
**Ladder:** controllers · rung 3.

### Lab 5 — Break/Fix + Cost · [lab](week-16/labs/LABS.md) · [figure 16.6](week-16/labs/FIGURES.md)
**Relates:** medium
**How:** Three failures and a bill. The bill's trap is the finalizer lesson from week 13 run backwards: delete the cluster first and the controller that would have deleted the load balancer is gone.
**The mechanism:** `terraform destroy` removes the EKS cluster, and with it the load balancer controller, before any Ingress object was deleted; the ALB, target groups and security groups it created were never in Terraform state and remain, billing by the hour. The correct order is objects first (so finalizers run and the controller deletes the cloud resource), wait for the Ingress to disappear, then the cluster; week 23 Lab 5 makes that the deprovisioning sequence. The IRSA failure is a trust-policy `sub` mismatch surfacing as `AccessDenied` from STS; the ALB failure is the controller unable to find tagged subnets, visible only in its logs; the ArgoCD failure is the immutable field from Lab 4. Production failure: a cluster deleted in a hurry and a load balancer bill discovered a month later.
**See it in Kubernetes:**
```bash
kubectl get ingress -A; kubectl delete ingress -A --all --wait=true     # before destroy
aws elbv2 describe-load-balancers --query 'LoadBalancers[].LoadBalancerName'
```
**Say it:** "Delete the objects so their finalizers run, then the cluster; the other order orphans what a controller made."
**Ladder:** controllers · lifecycle, upgrades, HA · rung 2.

<a id="week-17"></a>

## Week 17 — Consolidation ★ GATE 4 · KCNA decision · Bravo design

### Lab 1 — Rebuild From Memory · [lab](week-17/labs/LABS.md) · [figure 17.2](week-17/labs/FIGURES.md)
**Relates:** medium
**How:** The lab allows one reference, `kubectl explain`. That reference is served by the API server itself, which is why it knows about every CRD installed and the docs site does not.
**The mechanism:** `kubectl explain` reads the OpenAPI v3 document at `/openapi/v3/apis/<group>/<version>`, generated by the API server from the Go types of built-in kinds and from the `schema` of every CRD; the discovery API at `/apis` lists which groups and versions exist. That is also what `kubectl apply --validate` checks against, and what `kubectl` uses to know a resource's short names and whether it is namespaced. Production failure: a CRD installed with no schema, so `explain` shows nothing and `apply` accepts typos.
**See it in Kubernetes:**
```bash
kubectl explain statefulset.spec.volumeClaimTemplates --recursive | head -20
kubectl get --raw /openapi/v3 | jq -r '.paths | keys[]' | head
```
**Say it:** "`explain` is the API server describing itself, including every CRD it has been taught."
**Ladder:** API machinery · rung 2.

### Lab 2 — Gate 4 Rehearsal · [lab](week-17/labs/LABS.md) · [figure 17.3](week-17/labs/FIGURES.md)
**Relates:** strong
**How:** Nine symptoms, nine first commands. Underneath, the row the figure cannot drill on kind, `Node NotReady`, is a timeline of leases, taints and evictions that an expert can narrate to the second.
**The mechanism:** Every kubelet renews a `Lease` in `kube-node-lease` every ten seconds and posts a full status every minute. When the node lifecycle controller sees no renewal for the monitor grace period, about forty seconds by default, it sets the node's `Ready` condition to `Unknown` and taints it `node.kubernetes.io/unreachable:NoExecute`. Every pod carries a default toleration of 300 seconds for that taint, so five minutes later the controller evicts the pods and the ReplicaSet controller recreates them elsewhere; StatefulSet pods are not recreated until the old one is confirmed gone, because two `db-0` must never exist. Meanwhile the scheduler's TaintToleration filter keeps new pods off the node. The other eight rows are the mechanisms of weeks 14 and 15: the kubelet backoff, the scheduler filter, the EndpointSlice conditions, the RBAC 403, the provisioner's event. Production failure: a network partition that evicts a database pod after five minutes while the original is still running and writing on the isolated node.
**See it in Kubernetes:**
```bash
docker stop mastery-worker; kubectl get nodes -w     # Unknown after ~40 s, pods evicted after ~5 min
kubectl get node mastery-worker -o jsonpath='{.spec.taints}' | jq
```
**Say it:** "A missed Lease becomes an Unknown condition, then a NoExecute taint, then five minutes of toleration, then eviction."
**Ladder:** controllers · lifecycle, upgrades, HA · rung 3.

### Lab 3 — ⚑ Project Bravo: Design First · [lab](week-17/labs/LABS.md) · [figure 17.4](week-17/labs/FIGURES.md)
**Relates:** medium
**How:** Threat model, control, evidence. Half the controls in the table are Kubernetes admission and runtime mechanisms, and the threat model's trust boundaries are the cluster's own: who can reach the API server, who can reach a kubelet, who can reach etcd.
**The mechanism:** The cluster has three doors an attacker wants. The API server on 6443, guarded by authentication, RBAC and admission; the kubelet's own API on 10250, which can exec into any pod on the node and is why kubeadm sets `--anonymous-auth=false` and authorizes it through the API server via `Webhook` mode; and etcd on 2379, which holds every Secret in plaintext and is guarded only by its client certificates. STRIDE on those boundaries produces the controls Bravo builds: signed images and admission verification against tampering, NetworkPolicy against lateral movement, Falco's syscall view against a shell nobody should have opened, audit logs against repudiation. Production failure: a kubelet with anonymous auth and read-only port left on, which is a full node compromise from any pod.
**See it in Kubernetes:**
```bash
sudo grep -E 'anonymous|authorization' /var/lib/kubelet/config.yaml     # on a kubeadm node
kubectl get --raw /api/v1/nodes/k8s-w1/proxy/pods | head -c 300          # the kubelet API, through the server
```
**Say it:** "Three ports, three doors: 6443 through RBAC, 10250 through the kubelet's own authorizer, 2379 through certificates alone."
**Ladder:** isolation and security · authn, authz, admission · rung 3.

### Lab 4 — CKA foundations: kubeadm, by hand, once · [lab](week-17/labs/LABS.md) · [figure 17.5](week-17/labs/FIGURES.md)
**Relates:** strong
**How:** The lab types `kubeadm init` and reads what it wrote. Underneath, kubeadm is a sequence of phases you can run one at a time, and the join is a certificate bootstrap the kubelet performs for itself.
**The mechanism:** `kubeadm init` runs phases in order: preflight; certs (a CA, then a client and server certificate for every component, under `/etc/kubernetes/pki`); kubeconfig (one file per component, each a server address, a CA and a client certificate); kubelet-start (writes the kubelet's config and starts it so it can run static pods); control-plane (the four manifests into `/etc/kubernetes/manifests`, which the kubelet watches as a directory, not through the API); etcd; upload-config (a ConfigMap in `kube-system` recording how the cluster was built, which `upgrade` reads later); bootstrap-token; and the addons CoreDNS and kube-proxy. A join uses the bootstrap token to authenticate as a member of `system:bootstrappers`, submits a CertificateSigningRequest for its own kubelet client certificate, and a ClusterRoleBinding kubeadm created lets the signer approve it automatically; from then on the kubelet rotates its own certificate. The node stays NotReady until a CNI writes a config into `/etc/cni/net.d`, because the kubelet reports the network as unconfigured. Production failure: a kubelet client certificate that expired because rotation was disabled, taking the node NotReady exactly a year after install.
**See it in Kubernetes:**
```bash
sudo kubeadm init phase --help                       # the phase list
kubectl get csr; sudo ls /var/lib/kubelet/pki/       # the kubelet's own certificate, rotated
```
**Say it:** "kubeadm is phases that write files; a join is the kubelet getting its own certificate signed."
**Ladder:** lifecycle, upgrades, HA · rung 3.

<a id="week-18"></a>

## Week 18 — Supply Chain Security

### Lab 1 — SAST, SCA, Secret Scanning · [lab](week-18/labs/LABS.md) · [figure 18.2](week-18/labs/FIGURES.md)
**Relates:** medium
**How:** Three scanners before the registry. The Kubernetes relation is where the gate sits and what the cluster does after the image passes: the kubelet pulls anything it is told to, so a gate in CI is the only thing between a known CVE and a node unless admission checks too.
**The mechanism:** Nothing in the kubelet or containerd inspects an image for vulnerabilities; a pod spec naming a vulnerable image is pulled and run. The cluster-side counterpart to this lab is an operator that scans what is actually running: the Trivy operator watches workloads and writes `VulnerabilityReport` custom resources per image, so the SARIF the lab uploads to GitHub has a live twin in the cluster, and week 18 Lab 3 adds the admission gate that refuses an unsigned image before scheduling. Production failure: a dependency with a critical CVE that passed CI months ago, still running because nothing rescans deployed images.
**See it in Kubernetes:**
```bash
kubectl get vulnerabilityreports -A 2>/dev/null | head     # if the Trivy operator is installed
```
**Say it:** "CI gates what enters the registry; only an operator or admission gates what the kubelet will run."
**Ladder:** isolation and security · rung 2.

### Lab 2 — Image Hardening, Measured · [lab](week-18/labs/LABS.md) · [figure 18.3](week-18/labs/FIGURES.md)
**Relates:** strong
**How:** The lab measures size and CVEs through five Dockerfiles. Every line of the hardening checklist is enforced by the kubelet translating a pod's `securityContext` into the OCI runtime spec, and the lab's distroless trade-off is answered by a pod subresource.
**The mechanism:** The kubelet (`pkg/kubelet/kuberuntime`) turns `securityContext` into the CRI's `LinuxContainerSecurityContext`: `runAsNonRoot` makes the kubelet check the image's configured user, and a username rather than a numeric UID fails with `CreateContainerConfigError` because the kubelet cannot resolve names inside an image it has not run; `readOnlyRootFilesystem` mounts the overlay root read-only; `capabilities.drop: ALL` empties the bounding set runc hands the process; `allowPrivilegeEscalation: false` sets `no_new_privs`; `seccompProfile: RuntimeDefault` applies containerd's default syscall filter. Layers become an overlayfs snapshot per image, shared across containers using the same digest. `kubectl debug --target` creates an ephemeral container through the `pods/ephemeralcontainers` subresource, sharing the target's PID namespace, which is how a shell-less image is debugged without changing it. Production failure: `runAsNonRoot: true` added to a workload whose image says `USER app`, every pod failing with a reason nobody reads.
**See it in Kubernetes:**
```bash
kubectl get pod web -o jsonpath='{.status.containerStatuses[0].state.waiting.reason}'   # CreateContainerConfigError
sudo crictl inspect <id> | jq '.info.runtimeSpec.process.capabilities.bounding'      # on a node
```
**Say it:** "The securityContext becomes the OCI spec: user, mount flags, capability set, no_new_privs, seccomp."
**Ladder:** isolation and security · kubelet and runtime · rung 3.

### Lab 3 — SBOM, Signing, Verification · [lab](week-18/labs/LABS.md) · [figure 18.4](week-18/labs/FIGURES.md)
**Relates:** strong
**How:** Sign the digest in CI, refuse unsigned images at admission. Underneath, the Kyverno rule is a mutating and a validating webhook in one, and the mutation is what makes the verification mean anything.
**The mechanism:** `verifyImages` runs in the admission chain: mutating webhooks first, then schema validation, then validating admission policies and webhooks. For each container image Kyverno resolves the tag to a digest at the registry, fetches the signature stored beside it (a `sha256-<digest>.sig` tag or an OCI referrer), verifies the certificate chain against Fulcio for the stated subject and issuer, checks the Rekor inclusion proof, and then mutates the pod's image reference to the digest it verified. Without that mutation the kubelet could pull a different image under the same tag seconds later; with it, what was verified is what runs. The whole exchange must fit the webhook's `timeoutSeconds`, thirty at most, so a slow registry becomes an admission failure, and `failurePolicy` decides whether that blocks or admits. Admission happens before scheduling, so a rejected pod never reaches a node and `ImagePullBackOff` never appears; the error is in the `apply` response. Production failure: a registry outage that stops every deployment in the cluster because the verifying webhook cannot reach it.
**See it in Kubernetes:**
```bash
kubectl -n shop get pod app -o jsonpath='{.spec.containers[0].image}'     # mutated to @sha256:...
kubectl get validatingwebhookconfigurations kyverno-resource-validating-webhook-cfg -o jsonpath='{.webhooks[0].timeoutSeconds} {.webhooks[0].failurePolicy}'
```
**Say it:** "Verify the signature, then rewrite the image to the digest you verified; otherwise the tag can change under you."
**Ladder:** authn, authz, admission · rung 3.

### Lab 4 — SLSA and the Real Attacks · [lab](week-18/labs/LABS.md) · [figure 18.5](week-18/labs/FIGURES.md)
**Relates:** medium
**How:** A ladder of build trust and four attack classes. The cluster's role is the last check: provenance is an attestation attached to the digest, and the same admission rule that checks a signature can require it.
**The mechanism:** A SLSA provenance attestation is a signed statement about how the digest was built; Kyverno's `verifyImages` can require an attestation of a given type and evaluate conditions on its fields, such as the builder identity, before admitting the pod. That turns the ladder from a document into a gate: an image built outside the trusted workflow has no provenance from that builder and is refused. The attack classes map to cluster-side controls the week already built: a tampered artifact fails signature verification, a compromised build step is visible in provenance, a malicious dependency is in the SBOM attestation, and a runtime exploit is Falco's domain in week 19.
**See it in Kubernetes:**
```bash
cosign verify-attestation --type slsaprovenance "$IMAGE@$DIGEST" --certificate-identity-regexp '.*' --certificate-oidc-issuer https://token.actions.githubusercontent.com | jq -r .payload | base64 -d | jq .predicate.builder
```
**Say it:** "Provenance is an attestation on the digest, and admission can require it the same way it requires a signature."
**Ladder:** authn, authz, admission · rung 2.

### Lab 5 — Break/Fix + ⚑ Bravo Evidence · [lab](week-18/labs/LABS.md) · [figure 18.6](week-18/labs/FIGURES.md)
**Relates:** medium
**How:** An unfixable CVE and a signature that stayed behind. The first is a question about what is reachable from a running container; the second is admission refusing before the kubelet ever pulls.
**The mechanism:** Whether a CVE is reachable depends on the process, its capabilities and its network, which is exactly what the securityContext and NetworkPolicy limit: a vulnerable library in a container with no shell, all capabilities dropped, a read-only root and egress only to the database has a much smaller exploit path than the CVSS score suggests, and that is the argument an expiring exception should make. The moved-registry case fails at admission: Kyverno looks for `sha256-<digest>.sig` next to the image in the new registry, finds nothing, and denies; the pod never exists, so there is nothing to describe. `cosign copy` moves signature and attestations with the image. Production failure: an image promoted between registries by a tool that copied only the manifest.
**See it in Kubernetes:**
```bash
kubectl -n shop run t --image=$NEWREG/app@sha256:... 2>&1 | grep -i 'no matching signatures'
```
**Say it:** "Reachability is the securityContext and the policy around the process; a missing signature fails at admission, before any pull."
**Ladder:** isolation and security · rung 2.

<a id="week-19"></a>

## Week 19 — Policy, Runtime Security, and Secrets

### Lab 1 — Policy as Code for Terraform · [lab](week-19/labs/LABS.md) · [figure 19.2](week-19/labs/FIGURES.md)
**Relates:** medium
**How:** Rego against a plan, between plan and apply. The same engine sits inside the cluster as Gatekeeper, and Kubernetes now ships its own policy language in the API server.
**The mechanism:** OPA Gatekeeper is a validating webhook whose policies are `ConstraintTemplate` custom resources carrying Rego, instantiated as constraints; the `input` document is the AdmissionReview, so the lab's `input.resource_changes` becomes `input.review.object`. In-tree, `ValidatingAdmissionPolicy` (GA since 1.30) evaluates CEL expressions inside the API server with no webhook, no network hop and no `failurePolicy` dilemma, which makes it the right first tool for simple rules. Conftest itself tests Kubernetes manifests as readily as plans, so the "test the policy" discipline carries over as `conftest verify` and `kyverno test`. Production failure: a policy that passes its own tests but is never attached to a binding, enforcing nothing.
**See it in Kubernetes:**
```bash
kubectl get validatingadmissionpolicies,validatingadmissionpolicybindings
conftest test --policy policies/k8s deploy.yaml
```
**Say it:** "A plan gate in Rego is an admission gate in Rego, and CEL in the API server is the version with no webhook to fail."
**Ladder:** authn, authz, admission · rung 2.

### Lab 2 — Kyverno and Pod Security Standards · [lab](week-19/labs/LABS.md) · [figure 19.3](week-19/labs/FIGURES.md)
**Relates:** strong
**How:** The figure draws the admission path and the lockout. Underneath, Pod Security is an in-tree plugin that only ever sees Pods, Kyverno is a webhook registration with a selector, and the control plane must be able to reach the webhook over the network.
**The mechanism:** Admission runs after authentication and authorization: mutating plugins and webhooks first, then the object is validated against its schema, then validating policies and webhooks, in parallel, and any denial rejects the write. Pod Security Admission is compiled into the API server (`k8s.io/pod-security-admission`) and reads the namespace's labels on each Pod write; `enforce` applies only to Pods, so a Deployment is accepted and its ReplicaSet then fails to create pods, visible as a `FailedCreate` event on the ReplicaSet and zero ready replicas, while `warn` and `audit` also evaluate workload templates so you see the problem at the Deployment. Kyverno registers `MutatingWebhookConfiguration` and `ValidatingWebhookConfiguration` objects whose `rules` and `namespaceSelector` decide which requests the API server forwards as AdmissionReviews, with `timeoutSeconds` and `failurePolicy` per webhook. The lockout is BF-52: a cluster-wide validating rule with no exclusion catches `kube-system` too, and with `failurePolicy: Fail` a Kyverno outage blocks every write that matches. On EKS the API server reaches the webhook through its ENIs, so a node security group that drops 9443 from the cluster security group produces `context deadline exceeded` on every apply. Production failure: that security group change, made for an unrelated reason.
**See it in Kubernetes:**
```bash
kubectl get validatingwebhookconfigurations -o custom-columns=NAME:.metadata.name,FP:.webhooks[0].failurePolicy,T:.webhooks[0].timeoutSeconds
kubectl -n shop describe rs -l app=app | grep -A3 FailedCreate      # PSS enforce seen at the ReplicaSet
```
**Say it:** "PSA judges Pods inside the server; a webhook is a network call the server must complete in thirty seconds or decide without it."
**Ladder:** authn, authz, admission · rung 3.

### Lab 3 — NetworkPolicies · [lab](week-19/labs/LABS.md) · [figure 19.4](week-19/labs/FIGURES.md)
**Relates:** strong
**How:** Default deny, the DNS trap, and the CNI that must enforce. Underneath, a NetworkPolicy is an object nothing in Kubernetes acts on; the CNI's agent on each node turns it into packet filters, and the filters are stateful.
**The mechanism:** The API server stores the policy and that is all; kube-proxy ignores it. Calico's felix agent watches policies, pods and namespaces, computes which pods are selected, and programs iptables or nftables chains (or eBPF, in its eBPF data plane) attached to each pod's veth on the node that hosts it; Cilium compiles policies into eBPF programs keyed by a numeric identity derived from the pod's labels, so a packet's allowed-ness is a map lookup rather than a rule walk. Both treat policies as additive allow-lists and both track connections, so a reply packet to an allowed egress is admitted without an ingress rule. The DNS trap is egress: default-deny egress drops the UDP 53 packet to CoreDNS in `kube-system`, and because every connection starts with a lookup, everything appears to fail at once. `hostNetwork` pods are not selected by any policy, which is a classic bypass. kind's default CNI has historically not enforced policies, and some newer releases add an experimental enforcer, so the rule is to test with a pod rather than assume. Production failure: a policy applied in a cluster whose CNI ignores it, giving the team a security control that exists only in YAML.
**See it in Kubernetes:**
```bash
kubectl -n shop run t --rm -it --image=nicolaka/netshoot -- nc -zvw2 db 5432   # the only honest test
sudo calicoctl get networkpolicy -A 2>/dev/null || kubectl get networkpolicies -A
```
**Say it:** "The policy is data; the CNI agent on each node is the firewall, and conntrack lets replies through."
**Ladder:** networking datapath · rung 3.

### Lab 4 — Secrets and Runtime Detection · [lab](week-19/labs/LABS.md) · [figure 19.5](week-19/labs/FIGURES.md)
**Relates:** strong
**How:** A rotated value reaches a file but not an env var, and Falco sees a shell. Underneath are the kubelet's volume update path from week 14 with its two exceptions, and an eBPF program that watches syscalls and labels them with pod names.
**The mechanism:** External Secrets rewrites the Kubernetes Secret; the kubelet's watch on that Secret fires; the atomic writer creates a new timestamped directory in the tmpfs and swaps the `..data` symlink, so a process that opens the path reads the new value on its next open, with no restart. Two paths never update: `subPath` mounts, which are bind mounts of one file from the old directory, and environment variables, which were strings in the process environment from `execve` onwards. Falco's modern eBPF driver attaches to syscall tracepoints in the kernel, streams events such as `execve` with `sh` to user space, and enriches them with the container ID from cgroups and the pod and namespace from the CRI socket and the API server, so a rule can say `k8s.ns.name`. The rule engine then matches; a `kubectl exec` is an `execve` of a shell inside a container, which is exactly what the default rule looks for, hence the storm. Production failure: a `subPath` mount for a certificate that rotates, expiring in place while the Secret is current.
**See it in Kubernetes:**
```bash
kubectl -n shop exec deploy/app -- sh -c 'ls -la /etc/app/; readlink /etc/app/..data'
kubectl -n falco logs -l app.kubernetes.io/name=falco --tail=5 | jq '.output_fields | {proc: ."proc.cmdline", ns: ."k8s.ns.name"}'
```
**Say it:** "A file mount follows a symlink the kubelet swaps; subPath and env never do; Falco reads syscalls and names the pod."
**Ladder:** kubelet and runtime · isolation and security · rung 3.

### Lab 5 — Break/Fix and Compliance Mapping · [lab](week-19/labs/LABS.md) · [figure 19.6](week-19/labs/FIGURES.md)
**Relates:** medium
**How:** Control, implementation, evidence, requirement. For the Kubernetes rows the evidence comes from two places the lab names but does not open: the benchmark checks on node files, and the API server's audit log.
**The mechanism:** `kube-bench` implements the CIS Kubernetes Benchmark by reading what kubeadm wrote: flags in the static-pod manifests, the kubelet's config file, and the permissions and owners of files under `/etc/kubernetes`, which is why it must run on the node. The audit log is produced by the API server when started with `--audit-policy-file` and `--audit-log-path`; the policy chooses a level per rule (None, Metadata, Request, RequestResponse), and every request is logged with the authenticated user, verb, resource and response code, which is the evidence for "who changed what" that SOC 2 CC7.2 and NIST AU-2 ask for. Kyverno's background scans write `PolicyReport` objects, which are the evidence for the policy rows. Production failure: an audit policy at `RequestResponse` for Secrets, writing their values into the log it was meant to protect.
**See it in Kubernetes:**
```bash
sudo grep -E 'audit-policy-file|audit-log-path' /etc/kubernetes/manifests/kube-apiserver.yaml
kubectl get policyreports -A | head
```
**Say it:** "Evidence is the files kubeadm wrote, the audit log the API server writes, and the reports the policy engine writes."
**Ladder:** isolation and security · lifecycle, upgrades, HA · rung 2.

<a id="week-20"></a>

## Week 20 — Observability

### Lab 1 — The Three Signals and Instrumentation · [lab](week-20/labs/LABS.md) · [figure 20.2](week-20/labs/FIGURES.md)
**Relates:** strong
**How:** The stack you install is the Prometheus Operator plus the exporters that make a cluster observable, and the `ServiceMonitor` you write is a custom resource an operator turns into scrape configuration. The lab explains the `release:` label but not what the operator does with the object, nor where the cluster's own metrics come from.
**The mechanism:** The operator watches `ServiceMonitor` objects, renders them into a Prometheus configuration with `kubernetes_sd_configs` of role `endpoints`, and writes it into a Secret the Prometheus pod reloads. Your Service's EndpointSlices are therefore the scrape targets, which is why a pod that fails readiness also disappears from Prometheus. The cluster's numbers come from three places: the kubelet's `/metrics/cadvisor` endpoint, which reads the pod's cgroup files and is where `container_memory_working_set_bytes` is born; `kube-state-metrics`, which watches the API like any controller and republishes object state as series; and `node-exporter`, a DaemonSet with host namespaces. A high-cardinality label (BF-56) grows the TSDB head series, which is Prometheus memory, which is a pod with a memory limit, which is an OOMKill of your monitoring during the incident it was meant to catch.
**See it in Kubernetes:**
```bash
kubectl -n monitoring get secret -l app.kubernetes.io/name=prometheus -o name   # the rendered config lives here
kubectl get --raw "/api/v1/nodes/$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')/proxy/metrics/cadvisor" | grep -m3 container_memory_working_set_bytes
```
**Say it:** A ServiceMonitor is a CRD an operator turns into scrape config, and the targets are my Service's EndpointSlices, so readiness decides what gets measured.
**Ladder:** controllers (an operator you consume) · resources and scale (cardinality as memory) · kubelet and runtime (cAdvisor reads cgroups). Rung 2, with rung 3 on the operator pattern.

### Lab 2 — PromQL by Hand · [lab](week-20/labs/LABS.md) · [figure 20.3](week-20/labs/FIGURES.md)
**Relates:** medium
**How:** The metric types and functions are generic, but the series you query on a cluster are produced by the kubelet and by `kube-state-metrics`, and their names encode the mechanism that produced them.
**The mechanism:** `container_cpu_usage_seconds_total` is a counter the kubelet reads from the pod's cgroup `cpu.stat`, so `rate()` over it is CPU time per second, and `container_cpu_cfs_throttled_periods_total` rising while usage is flat is the CFS quota from a CPU limit refusing the process time. `container_memory_working_set_bytes` is the number the kernel OOM killer compares to the limit; RSS is not. `kube_pod_container_status_restarts_total` is `kube-state-metrics` republishing the field `kubectl describe` shows you, which is why the two agree to the second.
**See it in Kubernetes:**
```bash
kubectl exec -n shop deploy/app -- cat /sys/fs/cgroup/cpu.stat        # nr_throttled: the source of the throttling series
kubectl exec -n shop deploy/app -- cat /sys/fs/cgroup/memory.current   # what working set is computed from
```
**Say it:** The cluster metrics I graph are cgroup files read by the kubelet, so a throttling series is a CPU limit and a working-set series is the OOM killer's own number.
**Ladder:** resources and scale · kubelet and runtime. Rung 2.

### Lab 3 — Grafana and Alertmanager · [lab](week-20/labs/LABS.md) · [figure 20.4](week-20/labs/FIGURES.md)
**Relates:** medium
**How:** The stack ships a large set of Kubernetes alert rules as `PrometheusRule` custom resources, and the inhibition and grouping you configure is what keeps one node failure from paging fifteen times.
**The mechanism:** `PrometheusRule` is another CRD the operator renders; the shipped rules (`KubePodCrashLooping`, `KubeNodeNotReady`, `KubeDeploymentReplicasMismatch`) are all computed from `kube-state-metrics`, which means they are the API's object state rephrased as thresholds. A node going NotReady produces, in order: the node condition, every pod on it Unknown, every Deployment short of replicas, every Service short of endpoints. Without an inhibit rule keyed on the node alert, each of those is its own page, and the symptom-first rule the lab teaches is exactly the choice of which layer in that chain a human should hear about.
**See it in Kubernetes:**
```bash
kubectl -n monitoring get prometheusrules -o name | head
kubectl -n monitoring get prometheusrule -o yaml | grep -c 'alert: Kube'
```
**Say it:** The Kubernetes alerts are object state from kube-state-metrics, and one node failure fans out through pods, Deployments and Services unless inhibition collapses it.
**Ladder:** controllers (object state as a signal). Rung 2.

### Lab 4 — Tracing and Structured Logging · [lab](week-20/labs/LABS.md) · [figure 20.5](week-20/labs/FIGURES.md)
**Relates:** medium
**How:** The collector you send spans to is reached by a Service name, the two services talk through cluster DNS, and the choice between a collector sidecar and a DaemonSet is a pod-networking choice.
**The mechanism:** A sidecar collector shares the pod's network namespace, so the app reaches it on `localhost:4317` with no DNS and no Service; a DaemonSet collector is reached through a Service or the node IP, and every pod on the node shares it. The `traceparent` header crosses the Service's iptables or IPVS DNAT untouched, because kube-proxy works at layer 4 and never sees HTTP; a Gateway or Ingress proxy, which does, must be configured to propagate it. Logs written to stdout are captured by the runtime into `/var/log/pods/<ns>_<name>_<uid>/`, which is what `kubectl logs` and the log shipper both read.
**See it in Kubernetes:**
```bash
kubectl exec -n shop deploy/app -- cat /etc/resolv.conf                    # how the app finds the collector Service
sudo ls /var/log/pods/ | head                                              # on a node: where stdout actually lands
```
**Say it:** A sidecar is localhost because containers share a network namespace, and `kubectl logs` reads the same node files the shipper does.
**Ladder:** networking datapath · DNS · kubelet and runtime. Rung 2.

### Lab 5 — SLOs, Error Budgets, Burn Rate · [lab](week-20/labs/LABS.md) · [figure 20.6](week-20/labs/FIGURES.md)
**Relates:** medium
**How:** The SLI is measured at a Service, the fast-burn alert is what fires on a bad rollout, and the mitigation the alert leads to is a Deployment rollback.
**The mechanism:** A rollout with `maxUnavailable: 0` keeps capacity but says nothing about correctness: a new ReplicaSet whose pods pass readiness and return 500s is fully rolled out and burning budget at the same time. The SLO alert is the only thing that notices, and `kubectl rollout undo` is instant because the previous ReplicaSet is still there at zero. The lab's two windows (1 h and 5 m) are also the rollout's timescale: a progressive rollout that pauses on a burn-rate signal is the mechanism Argo Rollouts and Flagger add on top of the Deployment, by driving the ReplicaSet scale themselves.
**See it in Kubernetes:**
```bash
kubectl -n shop rollout history deploy/app          # the ReplicaSets the undo would return to
kubectl -n monitoring get prometheusrule -o yaml | grep -B2 -A6 'ErrorBudgetBurn'
```
**Say it:** Readiness proves a pod answers, not that it answers correctly, so the burn-rate alert is the rollout's real health check and undo is the mitigation.
**Ladder:** controllers (Deployment and ReplicaSet). Rung 2.

<a id="week-21"></a>

## Week 21 — SRE Practice and ⚑ Project Bravo ★ GATE 5

### Lab 1 — Incident Response · [lab](week-21/labs/LABS.md) · [figure 21.2](week-21/labs/FIGURES.md)
**Relates:** medium
**How:** "Mitigate before you diagnose" is possible because Kubernetes keeps the previous version running at zero and makes rollback a scale operation; the rollback-unsafe exception is where that stops being true.
**The mechanism:** `kubectl rollout undo` scales the old ReplicaSet up and the new one down under the Deployment's strategy, so a 30-second mitigation is the rolling update in reverse. It is unsafe only when something outside the pods changed irreversibly: a schema migration the old image cannot read, or a CRD version bump. The Incident Commander not debugging is the human version of the controller pattern the week keeps returning to: one role watches the whole state, others act on one part of it.
**See it in Kubernetes:**
```bash
kubectl -n shop get rs -o custom-columns=NAME:.metadata.name,DESIRED:.spec.replicas,REV:.metadata.annotations.deployment\.kubernetes\.io/revision
```
**Say it:** Rollback is fast because the old ReplicaSet never left, and it is unsafe only when something outside the pods will not roll back with them.
**Ladder:** controllers. Rung 2.

### Lab 2 — Run Three Real Incidents · [lab](week-21/labs/LABS.md) · [figure 21.3](week-21/labs/FIGURES.md)
**Relates:** strong
**How:** All three injected incidents are Kubernetes failures seen from the outside: a bad rollout, a Service with no endpoints, and a node or volume under pressure. The lab times the phases; it does not say which controller produced each symptom.
**The mechanism:** Incident one is a Deployment doing exactly what it was asked: the new pods pass `/ready`, the ReplicaSet reaches three, and the 500s are invisible to every controller. Incident two is `scale --replicas=0` on the database: the ReplicaSet deletes the pod, the EndpointSlice controller removes its address, the app's readiness probe starts failing on its own DB check, the app leaves its Service's EndpointSlices too, and the Ingress returns 503 for a reason two layers removed from the cause. That cascade is why week 15 forbids database checks in liveness. Incident three is the one controllers handle worst: a full PVC produces Postgres errors, not events, while a full node filesystem crosses the kubelet's `nodefs.available` eviction threshold and evicts pods by QoS class, BestEffort first, so the detection is a slow error rate followed by an eviction event you were not watching for.
**See it in Kubernetes:**
```bash
kubectl -n shop get endpointslices -l kubernetes.io/service-name=db     # incident two, in one line
kubectl get events -A --field-selector reason=Evicted                     # incident three, if it reached the node
```
**Say it:** Scaling the database to zero empties an EndpointSlice, which fails the app's readiness, which empties another one, so the 503 is two controllers away from the cause.
**Ladder:** controllers · kubelet and runtime (eviction) · networking datapath (EndpointSlices). Rung 3.

### Lab 3 — Runbooks, Chaos, DORA · [lab](week-21/labs/LABS.md) · [figure 21.4](week-21/labs/FIGURES.md)
**Relates:** strong
**How:** Every chaos experiment in the lab is a controller being asked to do its job: kill a pod, drain a node, kill the database, add latency, fill a disk. The hypothesis is a prediction about reconciliation, and the surprise is where the prediction was wrong.
**The mechanism:** Killing a pod with `kubectl delete` bypasses the PodDisruptionBudget entirely; only the eviction API, which `drain` uses, consults it. That distinction is the first thing a chaos run teaches, and it means a PDB protects you from upgrades and autoscalers, not from a human with delete rights. Draining asks the eviction subresource for each pod, waits while the PDB says no, and the ReplicaSet controller recreates the evicted pod elsewhere once the scheduler finds room. Killing the database pod exercises the StatefulSet controller, which recreates `db-0` by name, and the attach/detach controller, which must detach the volume from the old node before the new pod can mount it; that detach is most of the recovery time. Filling the disk crosses the kubelet's eviction thresholds (`nodefs.available` 10 % by default, `imagefs.available` 15 %) and the kubelet also garbage-collects images at `imageGCHighThresholdPercent`, which is why a disk-full incident sometimes clears itself.
**See it in Kubernetes:**
```bash
kubectl -n shop get pdb                                                         # ALLOWED DISRUPTIONS is what drain reads
kubectl create --raw /api/v1/namespaces/shop/pods/<pod>/eviction -f - <<< '{"apiVersion":"policy/v1","kind":"Eviction","metadata":{"name":"<pod>","namespace":"shop"}}'
```
**Say it:** A PDB is consulted by the eviction API, so drain and the autoscaler respect it and `kubectl delete` never does.
**Ladder:** controllers · storage and CSI (attach and detach) · resources and scale (eviction thresholds). Rung 3.

### Lab 4 — ⚑ Project Bravo to Acceptance · [lab](week-21/labs/LABS.md) · [figure 21.5](week-21/labs/FIGURES.md)
**Relates:** medium
**How:** The second demonstration, an unsigned image refused, happens inside the API server's admission chain; the first, a CVE blocked in CI, happens before Kubernetes is involved at all.
**The mechanism:** Kyverno's `verifyImages` rule runs as a validating admission webhook: the API server has authenticated and authorized the request, then calls the webhook with the object, and the webhook fetches the signature from the registry and checks it against the expected identity before answering. The rejection text `no matching signatures` comes back through the API server as the error on `kubectl run`, which is why it looks like a client error and is not. ArgoCD's self-heal reverting a manual scale is the same loop at a different level: a controller compares Git to the live object and writes the difference back.
**See it in Kubernetes:**
```bash
kubectl get validatingwebhookconfigurations -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.webhooks[0].failurePolicy}{"\n"}{end}'
```
**Say it:** The unsigned image is refused by a webhook inside the admission chain, after authentication and authorization and before etcd.
**Ladder:** authn, authz, admission · controllers (self-heal). Rung 2.

<a id="week-22"></a>

## Week 22 — Platform Engineering Foundations

### Lab 1 — What an IDP Actually Is · [lab](week-22/labs/LABS.md) · [figure 22.2](week-22/labs/FIGURES.md)
**Relates:** background
**How:** The nine domains a developer would otherwise have to know include most of this thread; the golden path exists because Deployment, Service, Ingress, NetworkPolicy, RBAC and quota are six objects a product team should not have to learn. The lab is the argument for hiding them, which only works if the platform team understands them well enough to hide them correctly.
**Say it:** The paved road is a set of Kubernetes objects someone else wrote, and the platform team owns the mechanism so the developer can own the service.
**Ladder:** none directly; it motivates every topic.

### Lab 2 — The Product Brief · [lab](week-22/labs/LABS.md) · [figure 22.3](week-22/labs/FIGURES.md)
**Relates:** background
**How:** The brief's numbers (days to first deploy, tickets per month) are measurements of how hard the cluster is to use without a platform; nothing in the lab touches a Kubernetes mechanism.

### Lab 3 — The Contract · [lab](week-22/labs/LABS.md) · [figure 22.4](week-22/labs/FIGURES.md)
**Relates:** medium
**How:** The contract's derived values are Kubernetes facts: the name becomes a namespace and a DNS name, the tier becomes replicas and a PodDisruptionBudget, and the name regex is Kubernetes' own object-name rule.
**The mechanism:** The DNS-1123 label rule in the schema is the rule the API server enforces on namespace and Service names, because both become DNS labels in `<svc>.<ns>.svc.cluster.local`; a name the contract accepts is a name the cluster accepts. Deriving `replicas` and a PDB `minAvailable` from the tier is a decision about the eviction API: a `critical` tier with two replicas and `minAvailable: 1` survives a drain, while a one-replica service with the same PDB blocks every upgrade forever (week 15). The error-message discipline maps onto admission: a Kyverno `message` is the same product surface as the validator's "did you mean".
**See it in Kubernetes:**
```bash
kubectl create ns Invalid_Name 2>&1 | head -1                              # the API server's own version of the contract's regex
```
**Say it:** The contract's name rule is the API server's name rule, and the tier is a PodDisruptionBudget decision in disguise.
**Ladder:** API machinery (names and validation) · lifecycle, upgrades, HA (PDB). Rung 2.

### Lab 4 — Module Registry and Template Repo · [lab](week-22/labs/LABS.md) · [figure 22.5](week-22/labs/FIGURES.md)
**Relates:** medium
**How:** The `service-runtime` module is a namespace, a ResourceQuota, a LimitRange, RBAC, a ServiceAccount and a NetworkPolicy; the hardened Dockerfile in the template is what makes the generated `securityContext` work.
**The mechanism:** A ResourceQuota is enforced by an admission plugin that counts at creation time, so a pod that would exceed it is refused with a 403, not scheduled and evicted. A LimitRange is a mutating admission plugin that injects default requests and limits into pods that omit them, which is the only way a namespace-wide quota on requests can work for workloads that never set any. The template's `USER 65532` matters because `runAsNonRoot: true` makes the kubelet refuse to start a container whose image runs as root; a template that gets this right is the same control as a Kyverno mutation, applied one step earlier.
**See it in Kubernetes:**
```bash
kubectl -n shop describe quota                                              # used versus hard, counted at admission
kubectl -n shop get limitrange -o yaml | grep -A4 defaultRequest
```
**Say it:** Quota refuses at admission and LimitRange defaults at admission, so the namespace's limits exist before any pod runs.
**Ladder:** authn, authz, admission · resources and scale · isolation and security. Rung 2.

### Lab 5 — Backstage: the Build/Buy Decision · [lab](week-22/labs/LABS.md) · [figure 22.6](week-22/labs/FIGURES.md)
**Relates:** background
**How:** Backstage's Kubernetes plugin reads your cluster through the API with a ServiceAccount token and a read-only ClusterRole, so the evaluation's "two weeks" includes an RBAC and token-handling decision the build-it-yourself path avoids by reading Git instead of the cluster.
**Say it:** Any portal that shows cluster state is one more identity with a ClusterRole, and that is part of the cost.
**Ladder:** authn, authz, admission. Rung 1.

<a id="week-23"></a>

## Week 23 — The Platform Build

### Lab 1 — The Platform Controller · [lab](week-23/labs/LABS.md) · [figure 23.2](week-23/labs/FIGURES.md)
**Relates:** strong
**How:** The lab calls the PR-driven flow a "controller" and asks why Actions plus Terraform was chosen over Crossplane or kubebuilder. The honest answer is a Kubernetes answer about what a reconcile loop gives you and what this flow lacks.
**The mechanism:** A Kubernetes controller is level-triggered: it watches objects through an informer, keeps a cache, and on every event compares desired to observed and acts, so a change made behind its back is corrected on the next pass and a missed event costs nothing because the next resync sees the state. The PR flow is edge-triggered: it runs when a merge happens and never again, so drift is invisible until the next PR, and idempotency on re-run is a property you have to prove by hand rather than one the loop gives you. Crossplane turns the same contract into a custom resource with a real reconciler; the price is a controller to operate. `kubectl apply` itself sits between the two: server-side apply records field ownership in `managedFields`, so two actors writing one object can be told apart, which is the thing the PR flow cannot do for a resource someone edited in the console.
**See it in Kubernetes:**
```bash
kubectl -n shop get deploy app --show-managed-fields -o yaml | grep -A8 managedFields | head -12
kubectl -n argocd get application -o jsonpath='{.items[0].status.sync.status}{"\n"}'    # a real reconciler's view of drift
```
**Say it:** A controller converges on every pass and a pipeline runs once on merge, so the pipeline cannot see drift and the controller cannot help seeing it.
**Ladder:** controllers · API machinery (server-side apply). Rung 3.

### Lab 2 — Generated Infrastructure · [lab](week-23/labs/LABS.md) · [figure 23.3](week-23/labs/FIGURES.md)
**Relates:** strong
**How:** Five of the nine generated resources are Kubernetes objects, and each one is enforced by a different part of the system. The lab proves the IAM scoping; the Kubernetes side is enforced by admission plugins, a CNI, and a mutating webhook.
**The mechanism:** The namespace is a name scope and an RBAC boundary and nothing else. The ResourceQuota and LimitRange are admission plugins, refusing and defaulting respectively, so they bind before scheduling. The NetworkPolicy is a declaration the API server stores and the CNI enforces, which is why week 19 proved enforcement on a CNI that does it and the platform must run one. The ServiceAccount carries an IRSA annotation that a mutating webhook reads to inject a projected token volume and two environment variables into every pod using it, which is the only reason a pod can assume the generated role; EKS Pod Identity does the same with an agent and an association object instead of an annotation. The ArgoCD Application is a custom resource whose controller reconciles the service's Git path into the namespace, and it is the piece that turns the other eight from a one-time apply into a maintained state.
**See it in Kubernetes:**
```bash
kubectl -n <svc> get pod -o jsonpath='{.items[0].spec.volumes[?(@.name=="aws-iam-token")]}' ; echo   # the webhook's work
kubectl -n <svc> get netpol,quota,limitrange,sa
```
**Say it:** The contract becomes a namespace with quota at admission, policy at the CNI, and an identity a webhook injects, and ArgoCD keeps all of it true.
**Ladder:** authn, authz, admission · isolation and security · controllers. Rung 3.

### Lab 3 — Generated Observability · [lab](week-23/labs/LABS.md) · [figure 23.4](week-23/labs/FIGURES.md)
**Relates:** medium
**How:** The tier becomes a `ServiceMonitor`, a `PrometheusRule` and a dashboard, all generated; the first two are custom resources the operator reconciles, so observability is "armed" the same way the namespace is: by a controller noticing an object.
**The mechanism:** Because `ServiceMonitor` and `PrometheusRule` are objects, they can be generated, labelled and garbage-collected with the service, and the operator's `serviceMonitorSelector` is the only coupling between the platform's monitoring and the tenant's namespace. A tier that pages at 99.9 % is a `PrometheusRule` with the week 20 burn-rate expression and a `severity: page` label the Alertmanager route reads. The dashboard is the one piece that is not a Kubernetes object unless you use a sidecar that watches ConfigMaps with a label and loads them into Grafana, which is how the stack ships it.
**See it in Kubernetes:**
```bash
kubectl -n monitoring get prometheus -o jsonpath='{.items[0].spec.serviceMonitorSelector}{"\n"}'
kubectl -n monitoring get cm -l grafana_dashboard=1 | head -3
```
**Say it:** A tier is a PrometheusRule and a ServiceMonitor generated with the service, so alerting exists because an operator saw two objects, not because someone configured Prometheus.
**Ladder:** controllers. Rung 2.

### Lab 4 — Pipeline and FinOps · [lab](week-23/labs/LABS.md) · [figure 23.5](week-23/labs/FIGURES.md)
**Relates:** medium
**How:** The pipeline ends by updating the GitOps repo, which ArgoCD reconciles, and it signs the image the admission webhook will verify; the cost half of the lab prices cloud resources, and the Kubernetes cost it does not price is requests.
**The mechanism:** Inside a cluster you pay for what pods request, not what they use: the scheduler subtracts `requests` from node allocatable, the autoscaler adds nodes when requests no longer fit, and a pod requesting 2 CPUs and using 0.1 costs 2 CPUs of node. Tag coverage attributes nodes to teams; attributing nodes to services needs the requests per namespace, which is what `kubectl top` cannot tell you and `kube-state-metrics` can. The pipeline's digest-pinned image reference is what makes the signature verifiable and the rollout reproducible, because a tag can move and a digest cannot.
**See it in Kubernetes:**
```bash
kubectl describe node <node> | sed -n '/Allocated resources/,/Events/p'       # requests versus allocatable: the cluster's bill
```
**Say it:** A cluster bills by requests, so right-sizing requests is the FinOps lever the cloud bill cannot show.
**Ladder:** resources and scale · scheduling. Rung 2.

### Lab 5 — Deprovisioning, Errors, Examples · [lab](week-23/labs/LABS.md) · [figure 23.6](week-23/labs/FIGURES.md)
**Relates:** strong
**How:** The teardown order the lab insists on exists because of finalizers and garbage collection, and the orphaned load balancer it warns about is a finalizer that never ran. The lab gives the order; this is why it is the order.
**The mechanism:** Deleting an object sets `deletionTimestamp` and the object stays until its `metadata.finalizers` list is empty; each finalizer names a controller that must do cleanup and remove its entry. An Ingress managed by the AWS Load Balancer Controller carries `ingress.k8s.aws/resources`, and the controller deletes the ALB before removing it. The ArgoCD Application carries `resources-finalizer.argocd.argoproj.io`, which makes deleting the Application cascade to everything it synced. Destroy the cluster first and no controller is alive to run either finalizer, so the ALB keeps billing with nothing pointing at it. Ownership runs the other way through `ownerReferences`: delete a Deployment and the garbage collector deletes its ReplicaSets and pods, foreground or background depending on `propagationPolicy`. A namespace stuck in `Terminating` is the same story: one object in it still has a finalizer whose controller is gone.
**See it in Kubernetes:**
```bash
kubectl -n <svc> get ingress -o jsonpath='{.items[0].metadata.finalizers}{"\n"}'
kubectl get ns <svc> -o jsonpath='{.status.conditions[*].message}{"\n"}'        # when it sticks in Terminating, this names the object
```
**Say it:** Delete order is finalizer order: the controllers that created cloud resources must still be running when the objects that own them are deleted.
**Ladder:** API machinery (finalizers, ownerReferences, garbage collection) · controllers. Rung 3.

<a id="week-24"></a>

## Week 24 — Charlie Completion and KCSA Prep

### Lab 1 — The Documentation Set · [lab](week-24/labs/LABS.md) · [figure 24.2](week-24/labs/FIGURES.md)
**Relates:** background
**How:** Two of the runbooks are Kubernetes runbooks: "stuck OutOfSync" is ArgoCD refusing to patch an immutable field (a Service's `clusterIP`, a Job's template), and "provisioning failed halfway" ends with a namespace whose finalizers must be inspected. Writing them well is writing the week 16 and week 23 mechanisms down.
**Say it:** The runbooks that get used are the ones that name the field or the finalizer, not the symptom.
**Ladder:** controllers · API machinery. Rung 2.

### Lab 2 — The Stranger Test · [lab](week-24/labs/LABS.md) · [figure 24.3](week-24/labs/FIGURES.md)
**Relates:** background
**How:** The errors a stranger hits are the platform's admission messages and validator output; a hesitation at an error is a message a webhook or schema wrote badly. The test measures the product; the mechanism it indirectly measures is how readable your Kyverno `message` fields and CRD validation errors are.
**Say it:** Every error the stranger reads was written by a schema or a webhook, and those are product copy.
**Ladder:** authn, authz, admission. Rung 1.

### Lab 3 — The Demo Video and README · [lab](week-24/labs/LABS.md) · [figure 24.4](week-24/labs/FIGURES.md)
**Relates:** none
**How:** A recording and a README; the Kubernetes content is whatever the demo shows, which is week 23.

### Lab 4 — KCSA Prep · [lab](week-24/labs/LABS.md) · [figure 24.5](week-24/labs/FIGURES.md)
**Relates:** medium
**How:** Two of the five KCSA domains are the cluster's own security surface, which weeks 15, 19 and 27 touch from the operator's side. The lab maps domains to reading; the mechanisms worth owning are the flags.
**The mechanism:** The API server's trust is a set of flags in its static-pod manifest: `--client-ca-file` for certificates, `--authorization-mode=Node,RBAC` for who may do what, `--enable-admission-plugins` for what is checked after that, and `--encryption-provider-config` for whether Secrets sit in etcd as plaintext. The kubelet has the same two questions on port 10250: `--anonymous-auth=false` and `--authorization-mode=Webhook` make the kubelet ask the API server whether a caller may read logs or exec, which is why `kubectl exec` is an RBAC decision on `pods/exec` and not a node-local one. Pod Security Admission is the built-in admission plugin that enforces the three profiles per namespace label; the 4Cs frame it as the cluster layer sitting on the container layer below it.
**See it in Kubernetes:**
```bash
sudo grep -E -- '--(authorization-mode|enable-admission-plugins|encryption-provider-config|anonymous-auth)' /etc/kubernetes/manifests/kube-apiserver.yaml
grep -A3 -E 'anonymous|authorization' /var/lib/kubelet/config.yaml
```
**Say it:** Cluster security is a short list of API server and kubelet flags, and `exec` is an RBAC verb because the kubelet asks the API server before it opens the shell.
**Ladder:** authn, authz, admission · isolation and security. Rung 2.

<a id="week-25"></a>

## Week 25 — Interview Conversion

### Lab 1 — The Eight STAR Stories · [lab](week-25/labs/LABS.md) · [figure 25.2](week-25/labs/FIGURES.md)
**Relates:** background
**How:** Three of the eight stories are Kubernetes stories told well only if the mechanism is in them: BF-52 is a validating webhook with `failurePolicy: Fail` and no namespace exclusion blocking every write including the one that would fix it; BF-56 is label cardinality becoming Prometheus memory; the RDS and ASG stories are not Kubernetes. "Tell me about a mistake" is answered with the admission chain, not with "I locked myself out".
**Say it:** The mistake story is a webhook the API server could not reach, and the fix was changing the policy's failure mode from outside the cluster's own API.
**Ladder:** authn, authz, admission. Rung 3 when told right.

### Lab 2 — System Design · [lab](week-25/labs/LABS.md) · [figure 25.3](week-25/labs/FIGURES.md)
**Relates:** medium
**How:** "Design a Kubernetes platform for 20 teams" is a question about which boundaries Kubernetes actually provides and which it does not; the method is generic, the content is this thread.
**The mechanism:** A namespace isolates names and RBAC scope, nothing else, so tenancy is built from four other things: ResourceQuota and LimitRange for capacity, NetworkPolicy on an enforcing CNI for traffic, Pod Security Admission labels for what a pod may do, and node pools with taints for workloads that must not share a kernel. Cluster-per-environment versus one shared cluster is a decision about blast radius of the control plane itself, because etcd, the API server and the admission chain are shared by everything in a cluster. Scaling is three loops that must agree: the HPA on pods, the autoscaler or Karpenter on nodes, and PDBs deciding what either may evict. The ingress tier is one Gateway the platform owns with HTTPRoutes the teams own. Saying those boundaries, and which one a namespace is not, is the difference between a senior answer and a diagram.
**See it in Kubernetes:**
```bash
kubectl get ns shop -o jsonpath='{.metadata.labels}{"\n"}'                 # the PSA labels: one of the four real boundaries
```
**Say it:** A namespace is a name scope, so a multi-tenant design is quota, NetworkPolicy, Pod Security and taints on top of it.
**Ladder:** isolation and security · resources and scale · scheduling. Rung 3.

### Lab 3 — Live Exercises · [lab](week-25/labs/LABS.md) · [figure 25.4](week-25/labs/FIGURES.md)
**Relates:** medium
**How:** "Debug a broken Kubernetes manifest" under fifteen minutes is a question about where the API server refuses and what it says when it does.
**The mechanism:** A manifest fails at three places and each has a different message: client-side decoding (a tab in YAML, a wrong indent), server-side validation against the OpenAPI schema (an unknown field, which strict field validation now rejects instead of silently dropping), and admission (a quota, a policy, a webhook). `kubectl apply --dry-run=server` runs the second and third without creating anything, and `kubectl explain` answers "is this field real and where does it go" faster than the docs. The fifteen-minute budget is spent well only if the first command classifies the error into one of those three.
**See it in Kubernetes:**
```bash
kubectl apply --dry-run=server --validate=strict -f broken.yaml
kubectl explain deployment.spec.template.spec.containers.resources --recursive
```
**Say it:** A manifest is refused by decoding, by schema, or by admission, and the error names which, so read it before touching the file.
**Ladder:** API machinery. Rung 2.

### Lab 4 — Mock Interviews · [lab](week-25/labs/LABS.md) · [figure 25.5](week-25/labs/FIGURES.md)
**Relates:** background
**How:** "You don't have professional experience in this" is answered by the kubeadm cluster of weeks 27 to 30 once it exists: initialised, backed up, restored, upgraded and broken six ways is operating experience, and the numbers from those labs are the proof.
**Say it:** I have not run a cluster for an employer; I have restored etcd and upgraded a control plane, and here are the timings.
**Ladder:** none directly.

<a id="week-26"></a>

## Week 26 — Full-Time Conversion ★ GATE 6

### Activity 1 — The Application Engine · [lab](week-26/labs/LABS.md) · [figure 26.2](week-26/labs/FIGURES.md)
**Relates:** none
**How:** The funnel is about applications and conversion rates; nothing in it is a Kubernetes mechanism.

### Activity 2 — Interview Execution · [lab](week-26/labs/LABS.md) · [figure 26.3](week-26/labs/FIGURES.md)
**Relates:** background
**How:** Two of the questions to ask them are cluster questions in disguise: "how often do you deploy" is a question about their rollout strategy and PDBs, and "what breaks most often" is usually a node, a certificate, or a webhook, which is weeks 27 and 19. Asking the follow-up shows the mechanism is yours.
**Say it:** What breaks most often tells me which controller they do not trust, and that is where I would start.
**Ladder:** none directly.

### Activity 3 — Networking · [lab](week-26/labs/LABS.md) · [figure 26.4](week-26/labs/FIGURES.md)
**Relates:** none
**How:** People, conversations, events; no cluster involved.

### Activity 4 — Keep Building · [lab](week-26/labs/LABS.md) · [figure 26.5](week-26/labs/FIGURES.md)
**Relates:** background
**How:** The lab's own example of a thing to build after a failed question is ApplicationSets, which is a generator-driven controller that stamps out ArgoCD Applications from a list, a Git directory tree, or a cluster list; building one is a Saturday of the controller pattern applied to itself. Whatever the interview exposed, the fix is a mechanism added to the kubeadm cluster or to Charlie.
**Say it:** The rejection names the controller I do not yet own, and Saturday is for owning it.
**Ladder:** controllers. Rung 2.

### Activity 5 — The Retrospective and the Plan · [lab](week-26/labs/LABS.md) · [figure 26.6](week-26/labs/FIGURES.md)
**Relates:** none
**How:** Funnel numbers and a weekly plan; the Kubernetes content it schedules is weeks 27 to 30.

<a id="week-27"></a>

## Week 27 — CKA I: Cluster Architecture, on kubeadm

### Lab 1 — kubeadm init, Calico, join, and read what it wrote · [lab](week-27/labs/LABS.md) · [figure 27.2](week-27/labs/FIGURES.md)
**Relates:** strong
**How:** The lab reads every file kubeadm wrote and says what breaks if each is wrong. What it does not say is how the kubelet gets from "no cluster" to "running the API server", or how a worker proves who it is to a control plane it has never met.
**The mechanism:** The kubelet starts from a systemd drop-in (`/usr/lib/systemd/system/kubelet.service.d/10-kubeadm.conf`) with `--config=/var/lib/kubelet/config.yaml` and two kubeconfigs: `--bootstrap-kubeconfig`, used once, and `--kubeconfig`, which it writes itself after bootstrapping. `init` runs ordered phases (`kubeadm init phase --help` lists them: preflight, certs, kubeconfig, kubelet-start, control-plane, etcd, upload-config, upload-certs, mark-control-plane, bootstrap-token, kubelet-finalize, addon) and the control plane exists because the kubelet's file source reads `staticPodPath` and runs whatever is there, then registers a mirror pod for each so the API can show it. A worker joins with a bootstrap token whose identity is the group `system:bootstrappers`, which RBAC allows to create one thing, a CertificateSigningRequest; the `csrapproving` controller auto-approves requests from that group for `system:node:<name>` identities, and the kubelet writes the result to `/var/lib/kubelet/pki/kubelet-client-current.pem`. The CA hash in the join command pins the discovery so a token cannot be used against an impostor control plane. The node stays NotReady until a CNI writes a config into `/etc/cni/net.d`, because the kubelet's runtime status reports the network as not ready; Calico's operator then runs `calico-node` as a DaemonSet and, by default, uses its own IPAM rather than the per-node `podCIDR` the controller manager allocates. Code: `cmd/kubeadm/app/phases/`, `pkg/kubelet/config/file.go`.
**See it in Kubernetes:**
```bash
sudo cat /usr/lib/systemd/system/kubelet.service.d/10-kubeadm.conf; cat /var/lib/kubelet/kubeadm-flags.env
kubectl get csr -o custom-columns=NAME:.metadata.name,REQUESTOR:.spec.username,SIGNER:.spec.signerName,COND:.status.conditions[0].type
```
**Say it:** The control plane is static pods the kubelet runs from files, and a worker joins by turning a bootstrap token into a signed node certificate through the CSR API.
**Ladder:** lifecycle, upgrades, HA · kubelet and runtime · authn, authz, admission. Rung 3.

### Lab 2 — Certificates and kubeconfigs · [lab](week-27/labs/LABS.md) · [figure 27.3](week-27/labs/FIGURES.md)
**Relates:** strong
**How:** The lab builds a user from a CSR and renews the control plane's certificates. Underneath is the whole of Kubernetes authentication: there are no user objects, only authenticators, and a certificate is the simplest one.
**The mechanism:** The API server runs a chain of authenticators and the first to succeed wins: client certificates against `--client-ca-file` (CN is the user, O fields are the groups), bearer tokens (ServiceAccount JWTs validated against the issuer, bootstrap tokens, static tokens), OIDC, and webhook. `kubectl auth whoami` is the `SelfSubjectReview` API returning what the chain decided. The CSR API has named signers; `kubernetes.io/kube-apiserver-client` is signed by the controller manager's `csrsigning` controller with `--cluster-signing-cert-file`, which is why the cluster CA key must be on the control plane and why a cluster with an external CA cannot approve CSRs. The kubelet's own client certificate rotates through the same API because `rotateCertificates: true` makes it request a new one at about 80 % of its lifetime, and `csrapproving` approves node identities automatically; its serving certificate on 10250 stays self-signed unless `serverTLSBootstrap` asks for one, which is why the API server is told to skip verification for kubelets by default. `kubeadm certs renew` rewrites files that static pods read only at start, so the running process keeps the old certificate until the manifest is touched; a cluster with a one-year-old control plane and no upgrade is BF-60 on its anniversary. Three CAs exist because three trust domains do: `ca` for the cluster, `etcd-ca` so etcd peers trust each other and nobody else, `front-proxy-ca` so the API server can prove to an aggregated API server that it is the proxy forwarding a user's identity in headers.
**See it in Kubernetes:**
```bash
sudo grep -E -- '--(client-ca-file|requestheader-client-ca-file|service-account-issuer)' /etc/kubernetes/manifests/kube-apiserver.yaml
sudo openssl x509 -in /var/lib/kubelet/pki/kubelet-client-current.pem -noout -dates -subject
```
**Say it:** Kubernetes has no users, only a chain of authenticators, and a certificate's subject is the identity, so the CA key is the thing that mints people.
**Ladder:** authn, authz, admission · lifecycle, upgrades, HA. Rung 3, rung 4 when you build the user from a CSR without the file.

### Lab 3 — etcd: snapshot, restore, prove it · [lab](week-27/labs/LABS.md) · [figure 27.4](week-27/labs/FIGURES.md)
**Relates:** strong
**How:** The lab takes a snapshot and restores it to a new directory. Underneath is what the API server actually does with etcd: a key per object, a revision per write, and a watch stream every controller depends on.
**The mechanism:** Every object is one key, `/registry/<resource>/<namespace>/<name>`, stored as protobuf; `resourceVersion` on an object is etcd's global revision at its last write. Writes go through Raft on a single-member cluster trivially and through a quorum otherwise, which is why a restored snapshot is a new member with a new cluster ID and must be told its own name and peer URL. Reads with `resourceVersion=0` are served from the API server's watch cache, which is itself a watch on etcd from a revision; a `watch` from a client streams events from a revision forward, and after a restore every watcher's revision is in the future relative to the new history, so informers get "too old resource version" or a disconnect and relist, which is the storm you see in the controller manager's logs after a restore. The API server compacts etcd history every five minutes by default (`--etcd-compaction-interval`) and compaction leaves fragmentation that `etcdctl defrag` reclaims; a database over the 2 GB default quota goes read-only with `mvcc: database space exceeded`, which presents as every write failing while reads succeed. Objects created after the snapshot vanish on restore, and the kubelet then kills their containers because pods not in the API are garbage to it; objects deleted after the snapshot reappear and their controllers run again. Code: `staging/src/k8s.io/apiserver/pkg/storage/etcd3/`, etcd `server/storage/mvcc/`.
**See it in Kubernetes:**
```bash
sudo -E etcdctl get /registry/deployments/shop/app --print-value-only | head -c 200 | strings | head -3
sudo -E etcdctl endpoint status -w table          # DB SIZE, RAFT INDEX, the revision you are about to restore to
```
**Say it:** An object is one etcd key at a revision, controllers watch from a revision, and a restore moves history under them, so they relist and the kubelet removes what the API no longer has.
**Ladder:** etcd and state · API machinery (watch, resourceVersion). Rung 3.

### Lab 4 — Upgrade one minor version · [lab](week-27/labs/LABS.md) · [figure 27.5](week-27/labs/FIGURES.md)
**Relates:** strong
**How:** The lab gives the order and the skew table. The mechanism is what `kubeadm upgrade apply` rewrites, why the order cannot be reversed, and what the drain in the middle is actually asking for.
**The mechanism:** `upgrade apply` pulls the new images, then rewrites the four static-pod manifests one at a time, waiting for each new pod to pass its health endpoint and rolling the manifest back if it does not, which is why the control plane stays up through its own upgrade on a single node. It renews every leaf certificate, uploads a new versioned `kubelet-config` ConfigMap, and re-applies the CoreDNS and kube-proxy addons, which is where a hand-edited Corefile gets reconciled away unless it was kept in the ConfigMap. The kubelet is upgraded afterwards because the skew policy is one-directional: the API server speaks every API version a three-minor-older kubelet needs, but an older API server does not know what a newer kubelet will send, and a kubelet two minors ahead is refused at registration. `drain` cordons the node by setting `spec.unschedulable`, which the scheduler reads as a taint, then calls the eviction API per pod, where the PodDisruptionBudget can say no; DaemonSet pods are skipped because their controller would put them straight back. API removals happen on the minor boundary, so `upgrade plan` lists deprecated versions in use because objects stored at a removed version become unreadable until migrated. Code: `cmd/kubeadm/app/phases/upgrade/`.
**See it in Kubernetes:**
```bash
kubectl -n kube-system get cm -o name | grep kubelet-config                 # the versioned config the next worker upgrade reads
kubectl get node k8s-w1 -o jsonpath='{.spec.unschedulable}{"\n"}{.spec.taints}{"\n"}'   # what cordon wrote
```
**Say it:** The control plane upgrades itself one static pod at a time with a health check and a rollback, and workers follow because the skew policy only reads one way.
**Ladder:** lifecycle, upgrades, HA · scheduling (cordon and eviction). Rung 3.

### Lab 5 — Break/Fix on nodes: the BF-59 to BF-64 set · [lab](week-27/labs/LABS.md) · [figure 27.6](week-27/labs/FIGURES.md)
**Relates:** strong
**How:** Six node failures, each with a first command. What the lab does not spell out is how the cluster decides a node is gone, what it does to the pods on it, and why the control-plane breaks are diagnosed with a container runtime CLI rather than kubectl.
**The mechanism:** A kubelet proves it is alive two ways: a `Lease` in `kube-node-lease` renewed every ten seconds, and a `NodeStatus` written when something changes or every five minutes. The node lifecycle controller marks the node `NotReady` after `--node-monitor-grace-period` (40 s by default) without a lease, then adds `node.kubernetes.io/not-ready:NoExecute`; every pod carries a default toleration of 300 s for that taint, so pods on a dead node are deleted by the taint manager after about five minutes and their controllers recreate them elsewhere, except StatefulSet pods, which are never force-deleted automatically because two copies of `db-0` would be worse than none. A stopped kubelet (BF-59) therefore costs five minutes of stale pods; a stopped containerd (BF-63) leaves the kubelet alive and reporting `ContainerRuntimeNotReady`. The cgroup driver mismatch is the kubelet and containerd disagreeing about who owns the cgroup tree, so every container start fails at creation. Control-plane breaks (BF-61, BF-64) are diagnosed with `crictl` and `/var/log/pods` because the API server is the thing that is down and the kubelet still runs the static pods and still writes their logs to disk. The CNI break (BF-62) is a pod sandbox failing at `RunPodSandbox` when the kubelet calls the CNI plugin named in `/etc/cni/net.d`, which is the ContainerCreating event text.
**See it in Kubernetes:**
```bash
kubectl -n kube-node-lease get lease k8s-w1 -o jsonpath='{.spec.renewTime}{"\n"}'
kubectl get pod -A -o jsonpath='{.items[0].spec.tolerations}' | tr ',' '\n' | grep -A2 not-ready
```
**Say it:** A node is dead when its lease stops, NotReady after forty seconds, and its pods are evicted by a taint after five minutes, so every node failure is a timer you can name.
**Ladder:** kubelet and runtime · controllers (node lifecycle) · lifecycle, upgrades, HA. Rung 3.

<a id="week-28"></a>

## Week 28 — CKA II: Workloads, Networking, Storage — the Gap-Fill

### Lab 1 — Kustomize, and Helm as an install tool · [lab](week-28/labs/LABS.md) · [figure 28.2](week-28/labs/FIGURES.md)
**Relates:** strong
**How:** The lab contrasts the two patch types and installs a chart. Underneath, strategic merge is the API's own merge semantics, generator hashes are a rollout trigger, and a Helm release is a Secret the API server stores like any other object.
**The mechanism:** A strategic merge patch works because the OpenAPI schema marks lists with `x-kubernetes-patch-merge-key` (containers merge by `name`, ports by `containerPort`), which is the same metadata server-side apply uses to attribute fields to managers; a JSON patch addresses by index because it ignores the schema entirely. A `configMapGenerator` suffixes the name with a content hash and rewrites every reference, so changing a value changes the pod template, and a changed template is the only thing that makes a Deployment roll; editing a ConfigMap in place changes nothing a controller watches, which is why pods keep the old value until something else restarts them. Helm stores each release revision as a Secret of type `helm.sh/release.v1` in the namespace, and `upgrade` performs a three-way merge between the last applied manifest, the new one and the live object, so a field someone changed by hand survives an upgrade unless the chart also changes it; `rollback` applies an older revision's manifest and creates a new revision number, never reusing the old one.
**See it in Kubernetes:**
```bash
kubectl get --raw /openapi/v3/apis/apps/v1 | python3 -c 'import sys,json; print(json.load(sys.stdin)["components"]["schemas"]["io.k8s.api.core.v1.PodSpec"]["properties"]["containers"]["x-kubernetes-patch-merge-key"])'
kubectl -n helm-demo get secret -l owner=helm -o custom-columns=NAME:.metadata.name,STATUS:.metadata.labels.status
```
**Say it:** Strategic merge is the schema's merge key, a generator hash is a pod-template change, and a Helm release is a Secret with a revision number.
**Ladder:** API machinery (merge semantics, server-side apply) · controllers (what triggers a rollout). Rung 3.

### Lab 2 — Gateway API, CoreDNS, and a Service with no selector · [lab](week-28/labs/LABS.md) · [figure 28.3](week-28/labs/FIGURES.md)
**Relates:** strong
**How:** Three mechanisms in one lab: a route object becoming proxy configuration, a resolver watching the API, and a Service with its endpoints written by hand. The lab proves each with curl; this is the path between the object and the packet.
**The mechanism:** A Gateway implementation is a controller that watches `GatewayClass` objects naming its `controllerName`, then `Gateway` and `HTTPRoute` objects attached to them, and programs its data plane: NGINX Gateway Fabric rewrites an nginx configuration and reloads it, Envoy-based ones push xDS. It reports back through status conditions, `Accepted` and `Programmed` on the Gateway and `ResolvedRefs` on the Route, which is why a Route pointing at a missing Service is visible in status rather than silently 503. `allowedRoutes` and `ReferenceGrant` are the namespace boundary Ingress never had, enforced by the controller refusing to attach. CoreDNS's `kubernetes` plugin runs an informer on Services and EndpointSlices and answers from its cache: a ClusterIP Service gets one A record, a headless Service gets the pod addresses, and the pod's `/etc/resolv.conf` was written by the kubelet from `--cluster-dns` with the namespace search path and `ndots:5`, so a lookup of `example.com` tries four cluster suffixes first. A selectorless Service shows what a Service is: a ClusterIP and a port that kube-proxy turns into DNAT rules from whatever EndpointSlices carry the `kubernetes.io/service-name` label; with a selector the EndpointSlice controller writes them, without one you do, and kube-proxy cannot tell the difference. Code: `pkg/proxy/`, CoreDNS `plugin/kubernetes/`.
**See it in Kubernetes:**
```bash
kubectl -n web get httproute shop -o jsonpath='{.status.parents[0].conditions[*].type}{"\n"}'
sudo iptables-save -t nat | grep -A3 'KUBE-SVC.*web/outside'           # kube-proxy's rules for the Service you gave endpoints by hand
```
**Say it:** A Service is DNAT rules keyed on EndpointSlices, CoreDNS is an informer that answers from cache, and a Gateway is a controller that turns Route objects into proxy config and says so in status.
**Ladder:** networking datapath · DNS · controllers. Rung 3.

### Lab 3 — CRDs and operators · [lab](week-28/labs/LABS.md) · [figure 28.4](week-28/labs/FIGURES.md)
**Relates:** strong
**How:** The lab installs an operator and writes a CRD with a schema. What a CRD costs the API server, how defaulting and validation happen without a controller, and what an operator is made of are the parts under it.
**The mechanism:** Applying a CRD makes the API server create a new REST endpoint, add the kind to discovery (`kubectl api-resources` reads this), publish its schema at `/openapi/v3`, and store objects of that kind in etcd under its own prefix; every CRD also adds an informer to every controller that lists all types, which is why thousands of CRDs slow a cluster down. Structural schema validation, defaulting and pruning of unknown fields run inside the API server on every write, and `x-kubernetes-validations` adds CEL rules without a webhook; conversion between versions is `None` (rename nothing) or a webhook. An operator is an ordinary controller: an informer per watched kind, a cache, a workqueue keyed by name, and a reconcile function that reads the custom resource and creates owned objects with `ownerReferences` so garbage collection deletes them with it, which is why deleting the CRD deletes every custom resource and everything they own. cert-manager's chain (Certificate → CertificateRequest → Secret) is three reconcilers, each watching the previous object's status. The sample-controller repository and kubebuilder are the two canonical skeletons. Code: `staging/src/k8s.io/apiextensions-apiserver/`, `staging/src/k8s.io/client-go/tools/cache/`.
**See it in Kubernetes:**
```bash
kubectl get --raw /openapi/v3 | python3 -c 'import sys,json; [print(k) for k in json.load(sys.stdin)["paths"] if "ops.example.com" in k]'
kubectl -n web get secret shop-tls -o jsonpath='{.metadata.ownerReferences[0].kind}{"\n"}'
```
**Say it:** A CRD is a new endpoint with a schema the API server enforces itself, and an operator is an informer, a queue and a reconcile function that owns what it creates.
**Ladder:** API machinery · controllers. Rung 3, rung 4 once the week 28 "go deeper" controller is written.

### Lab 4 — Workloads and scheduling, under exam conditions · [lab](week-28/labs/LABS.md) · [figure 28.5](week-28/labs/FIGURES.md)
**Relates:** strong
**How:** Six ways to place a pod and three kinds of batch workload, each in three minutes. The speed hides the scheduler framework underneath, which is the thing to own once the speed is there.
**The mechanism:** Each pending pod goes through a scheduling cycle of plugins: `PreFilter` and `Filter` remove nodes (resources, taints via `TaintToleration`, `nodeSelector` and required affinity via `NodeAffinity`, `VolumeBinding`), `PostFilter` runs preemption when nothing fits and the pod's `PriorityClass` outranks running pods, `Score` ranks what is left, and a binding cycle writes `nodeName`. `nodeName` set by you skips all of it, including taints, which is why the lab's `n4` runs on a tainted node and `n5` does not; the kubelet still admits the pod against its own resources. `NoExecute` is not the scheduler's: the node lifecycle controller's taint manager evicts running pods lacking a toleration, after `tolerationSeconds` if set. DaemonSet pods are scheduled by the default scheduler since 1.12 through a node-affinity term the controller injects per node, so a DaemonSet can go Pending on a node full of requests. The Job controller counts completions by pod phase and tracks pods with a finalizer so a deleted pod is not miscounted; the CronJob controller computes the next run from the schedule and `lastScheduleTime` and skips runs older than `startingDeadlineSeconds`. Code: `pkg/scheduler/framework/`, `pkg/controller/job/`.
**See it in Kubernetes:**
```bash
kubectl get events --field-selector reason=FailedScheduling -o jsonpath='{.items[-1].message}{"\n"}'   # the Filter plugins, by name
kubectl get pod n1 -o jsonpath='{.spec.schedulerName}{"|"}{.spec.nodeName}{"\n"}'                    # empty scheduler, chosen node
```
**Say it:** Scheduling is filter, score, bind by named plugins, nodeName skips all three, and NoExecute is a controller evicting, not the scheduler refusing.
**Ladder:** scheduling · controllers. Rung 3.

### Lab 5 — Storage on kubeadm, and Break/Fix · [lab](week-28/labs/LABS.md) · [figure 28.6](week-28/labs/FIGURES.md)
**Relates:** strong
**How:** The lab shows a cluster with no storage, a provisioner, binding, reclaim and expansion. Each of those is a different controller, and on a cloud most of them are CSI sidecars you have never seen.
**The mechanism:** The PV controller in the controller manager binds claims to volumes by class, size and access mode and sets `claimRef` both ways; a claim with no class and no default stays Pending forever because nothing is responsible for it. Dynamic provisioning is a separate controller named in the class's `provisioner` field; for CSI drivers it is the `external-provisioner` sidecar watching PVCs and calling the driver's `CreateVolume`. `WaitForFirstConsumer` makes the scheduler's `VolumeBinding` plugin choose the node first and write the `volume.kubernetes.io/selected-node` annotation, so the volume is created where the pod will run; local-path then pins the PV with `nodeAffinity`, which is the whole reason a local RWO claim cannot follow a pod. On a cloud the attach step is the attach/detach controller creating a `VolumeAttachment` object that the `external-attacher` turns into an API call, and the mount step is the kubelet calling the driver's node plugin over a Unix socket; both are absent on `local-path`, which is why it is fast and why it is not production storage. Reclaim is the PV controller acting on `persistentVolumeReclaimPolicy` when the claim goes away; expansion is gated by `allowVolumeExpansion` at the API, done by `external-resizer` for the volume and by the kubelet for the filesystem. Code: `pkg/controller/volume/persistentvolume/`, `pkg/controller/volume/attachdetach/`.
**See it in Kubernetes:**
```bash
kubectl get pvc data -o jsonpath='{.metadata.annotations}{"\n"}'              # selected-node and the provisioner's bookkeeping
kubectl get csidrivers,volumeattachments 2>/dev/null                           # empty here; populated on EKS with the EBS driver
```
**Say it:** Binding, provisioning, attaching, mounting and resizing are five different controllers, and the class tells each one whether it is allowed to act.
**Ladder:** storage and CSI · scheduling (volume binding). Rung 3.

<a id="week-29"></a>

## Week 29 — Troubleshooting and Speed

### Lab 1 — The Exam Terminal · [lab](week-29/labs/LABS.md) · [figure 29.2](week-29/labs/FIGURES.md)
**Relates:** medium
**How:** The generators, `explain`, jsonpath and contexts are kubectl features, and each one is a thin layer over an API call worth knowing about, because that is what makes them predictable under a clock.
**The mechanism:** `--dry-run=client` builds the object in kubectl and never contacts the server, so it cannot catch a schema error; `--dry-run=server` sends it through validation and admission and returns what would have been stored, defaults included. `kubectl explain` reads the OpenAPI document the API server publishes, which is why it knows about CRDs installed five minutes ago. jsonpath and custom-columns are evaluated client-side on the JSON the server returned, so a field that is empty prints nothing rather than erroring. A context is a tuple of cluster, user and namespace in a kubeconfig file, and `use-context` changes which tuple every later command reads; the wrong-context mistake is a correct request authenticated as the right user against the wrong API server.
**See it in Kubernetes:**
```bash
kubectl run x --image=nginx $do | kubectl apply --dry-run=server -f - -o yaml | grep -A3 'resources: {}'   # server defaults appear, client ones do not
kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}{"\n"}'
```
**Say it:** A client dry run never leaves my terminal, a server dry run runs admission, and a context is which server my next command hits.
**Ladder:** API machinery. Rung 2.

### Lab 2 — Troubleshooting on Real Nodes, Timed · [lab](week-29/labs/LABS.md) · [figure 29.3](week-29/labs/FIGURES.md)
**Relates:** strong
**How:** Twelve breaks in four families. The first commands are in the lab; the reason each family has a different first command is which component is lying to you.
**The mechanism:** Application failures leave evidence in the API because the API is healthy: events, container statuses, EndpointSlices. Control-plane failures remove the API, so evidence moves to the node: the kubelet keeps running static pods from the manifests directory and re-reads it on a short interval, `crictl` talks to containerd directly, and `/var/log/pods` holds the logs the kubelet wrote. Case 5 is the Node authorizer: `kubelet.conf` authenticates as `system:node:k8s-cp`, and `--authorization-mode=Node,RBAC` restricts that identity to the objects bound to its own node, so most commands return Forbidden with a healthy API server. Worker failures are visible from the API as conditions and events, but fixed on the node, and the "across a reboot" clause is `systemctl is-enabled`, because the kubelet is a systemd unit before it is anything else. Networking failures split by layer: a CoreDNS `forward` pointing nowhere breaks external names and keeps cluster names, a NetworkPolicy is enforced by the CNI and invisible to kube-proxy, and a `calico-node` DaemonSet with an impossible `nodeSelector` leaves the CNI binary and config on disk but no agent, which the kubelet reports as `network plugin not ready` at sandbox creation.
**See it in Kubernetes:**
```bash
sudo crictl ps -a --name kube-apiserver; sudo crictl logs "$(sudo crictl ps -a -q --name kube-apiserver | head -1)" 2>&1 | tail -5
kubectl --kubeconfig /etc/kubernetes/kubelet.conf get pods -A 2>&1 | head -1      # the Node authorizer, in one line
```
**Say it:** The family tells me which component can still answer, so the first command goes to the one that is not lying: the API, the runtime, systemd, or the CNI.
**Ladder:** kubelet and runtime · authn, authz, admission (Node authorizer) · networking datapath · DNS. Rung 3.

### Lab 3 — Mock Exam 1 · [lab](week-29/labs/LABS.md) · [figure 29.4](week-29/labs/FIGURES.md)
**Relates:** medium
**How:** Eighteen tasks across the five domains, each one a mechanism from this thread under a clock. The setup script plants states by editing the same files and objects weeks 27 and 28 taught; a task you cannot start is an entry in this document to reread.
**Say it:** Every task is a component I can name, and naming it first is what makes the three-minute version possible.
**Ladder:** all twelve, at rung 2 by design: the exam measures use and debug.

### Lab 4 — killer.sh Session 1 · [lab](week-29/labs/LABS.md) · [figure 29.5](week-29/labs/FIGURES.md)
**Relates:** background
**How:** The simulator is harder than the exam and its solutions name the docs page each task maps to; the weak-domain tally it produces is a map of which rows of the mastery rubric are still at rung 1.
**Say it:** The missed tasks are the rubric rows to drill, not the tasks to memorise.
**Ladder:** none directly; a measurement of all of them.

### Lab 5 — Break/Fix and the Triage Drill · [lab](week-29/labs/LABS.md) · [figure 29.6](week-29/labs/FIGURES.md)
**Relates:** background
**How:** Triage is exam technique, not Kubernetes; the one mechanism in it is why an etcd restore and a node upgrade are the long tasks: each one restarts a control-plane component and waits for it to come back, and that wait is the kubelet's manifest re-read plus the component's own startup, which you cannot hurry.
**Say it:** The long tasks are long because a static pod has to die and come back, so they go in the middle of the clock.
**Ladder:** lifecycle, upgrades, HA. Rung 2.

<a id="week-30"></a>

## Week 30 — Exam Week ★ GATE 7

### Lab 1 — killer.sh Session 2: the Gate 7 Attempt · [lab](week-30/labs/LABS.md) · [figure 30.2](week-30/labs/FIGURES.md)
**Relates:** background
**How:** The gate is a measurement under exam conditions; the mechanisms are weeks 27 to 29. A near miss by family is a rubric row at rung 2 that the exam needs at rung 2 with speed, so the drill is repetition rather than new understanding.
**Say it:** The score is the rubric read at exam speed.
**Ladder:** none directly.

### Lab 2 — Weak-Domain Drills · [lab](week-30/labs/LABS.md) · [figure 30.3](week-30/labs/FIGURES.md)
**Relates:** medium
**How:** The three sets group the mechanisms by family: Set A is the four troubleshooting families and their components, Set B is kubeadm, etcd, certificates, upgrades, RBAC and the storage controllers, Set C is Services, Gateway, NetworkPolicy, DNS, rollouts, scheduling, Jobs, Helm and Kustomize. Redrawing the family's figure between runs is retrieval of the mechanism; the third run's time is whether the mechanism has become a reflex.
**Say it:** A set is a family of components, and the figure I redraw between runs is where each one lives.
**Ladder:** the rows the tally named, from rung 2 toward rung 3 through repetition.

### Lab 3 — The Exam Checklist · [lab](week-30/labs/LABS.md) · [figure 30.4](week-30/labs/FIGURES.md)
**Relates:** none
**How:** Logistics, the room, the proctor and the first five minutes; no cluster mechanism.

### Lab 4 — Exam Day · [lab](week-30/labs/LABS.md) · [figure 30.5](week-30/labs/FIGURES.md)
**Relates:** none
**How:** The ritual and the triage rules; the Kubernetes content is whatever the tasks ask, which is weeks 14 to 28.

### Lab 5 — After · [lab](week-30/labs/LABS.md) · [figure 30.6](week-30/labs/FIGURES.md)
**Relates:** background
**How:** The CKS decision is a decision about which mechanisms come next: Pod Security Admission and seccomp profiles, RuntimeClass and gVisor, audit logging and the API server's audit policy, image signing at admission, and the kubelet's own hardening. All of them are rung 3 topics in this thread's isolation and security row, and the retrospective's "which figure saved the most time" is the row to keep redrawing monthly whether or not CKS is booked.
**Say it:** The exam is a line; the restored etcd, the upgraded control plane and the six node failures are the stories, and the security row is what comes after.
**Ladder:** isolation and security, as the next row to raise.
