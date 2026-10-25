# Kubernetes Mastery

> The CKA certifies that you can operate a cluster under a clock. Mastery is being able to explain any
> behaviour of the system from the mechanism up, predict a failure before it happens, and change the
> system rather than operate it. This file is the ladder, the rubric, and the process that make that a
> measured part of the program rather than a hope. It runs beside the weeks from week 1, becomes the
> centre of gravity from week 14, and continues after week 30, because the top two rungs are measured
> in months.

**The three artefacts**

| Artefact | What it is |
|---|---|
| This file | The five rungs, the twelve topics, the rubric, the schedule, the reading, the scoring table |
| [`curriculum/KUBERNETES-THREAD.md`](curriculum/KUBERNETES-THREAD.md) | Every lab in the program, weeks 1 to 30, read as Kubernetes: what in it is the same mechanism, explained one level under the lab, with a command that shows it on a cluster and a sentence to say aloud. Read the entry after each lab |
| The eleven **Go deeper** labs | Appended to weeks 14, 15, 16, 27, 28 and 30. Each opens machinery the week's labs use without looking inside, and each has a figure. Optional inside the week; mandatory for the ladder |

---

## 1. The five rungs

| Rung | Name | The test |
|---|---|---|
| **1** | Use | You can create, change and remove the thing with the API, from memory, and read its status |
| **2** | Debug | Given a symptom, you reach the cause with a first command, a second, and a proof. The CKA certifies this rung under a clock |
| **3** | Explain | You can say what component does what, in what order, touching which file, flag, field or syscall, and what breaks at each step. Fifteen minutes on a whiteboard, no notes, no hand-waving at the hard part |
| **4** | Modify | You have changed the mechanism: configured it differently and shown the difference, replaced a piece of it, or written a piece of it |
| **5** | Teach | You have taught it to someone who did not know it, from a blank page, and they could then do rung 2. A published post with a figure counts; a recorded fifteen-minute explanation a stranger followed counts |

The program as written reaches rung 2 on everything and rung 3 on the figures. This file is the path to rungs 3, 4 and 5 on twelve topics, and the way to know which rung you are on.

---

## 2. The twelve topics, and the rubric

One row per topic. The cell is the test for that rung; passing it is binary and demonstrated.

| Topic | 1 · Use | 2 · Debug | 3 · Explain | 4 · Modify | 5 · Teach |
|---|---|---|---|---|---|
| **API machinery** | CRUD with kubectl, `-o yaml`, `explain`, labels and selectors | A 409, 410, 403, 422 and 429 each traced to its cause | list-then-watch, `resourceVersion` as compare-and-swap, the admission order, the watch cache, pagination | An informer you wrote; a validating webhook you deployed | The path of one request from kubectl to etcd and back, with the failure possible at each stage |
| **Controllers** | Deployment, ReplicaSet, rollout, undo, owner references | A stuck rollout; a controller doing nothing (leader, RBAC, a crashed informer) | Level-triggered reconcile, the workqueue, rate limiting, idempotence, garbage collection by owner | A kubebuilder controller with status, a watch on its children, leader election, a webhook | "Kubernetes is a set of loops," with one core controller's code open |
| **Scheduling** | nodeSelector, affinity, taints, topology spread, PDB, priority | Pending with its event; a preemption; a drain that hangs | The framework's phases, the plugins that filter and score, the queues and backoff | A second scheduler profile with a plugin disabled and a different scoring strategy, and a pod that lands differently | One pod's decision, plugin by plugin, from the logs |
| **Kubelet and runtime** | Probes, requests and limits, QoS, static pods | CrashLoopBackOff by exit code; OOMKilled; eviction; "PLEG is not healthy" | cgroup v2 files per pod, the CRI calls, image GC, eviction thresholds and order, the mirror pod | Kubelet config changed and proven (eviction, GC); a RuntimeClass | "What the kubelet does every ten seconds" |
| **Networking datapath** | Service types, Ingress, Gateway API, NetworkPolicy | No endpoints vs refused vs timeout; a policy that blocks DNS; a CNI that does not enforce | kube-proxy's chain and conntrack, EndpointSlices, the CNI contract, VXLAN or BGP between nodes | kube-proxy switched to IPVS and nftables with proof; a CNI plugin written by hand; Cilium with proxy replacement | One packet from `curl` to the container and back, naming every hop |
| **DNS** | Service names, FQDNs, headless records | ndots cost, a stub domain, SERVFAIL, a hostNetwork pod | The Corefile plugin chain, the `kubernetes` plugin's records, NodeLocal DNSCache and why it exists | Corefile and `dnsConfig` changes, measured | "Five queries for one name" |
| **Storage and CSI** | PVC, StorageClass, StatefulSet claims, access modes | Pending claim, stuck attach, RWO across nodes, expansion refused | Provision, attach, stage, publish; the sidecars and the gRPC calls; reclaim; topology-aware binding | A provisioner installed on bare nodes; a snapshot class; expansion end to end | The life of a volume from claim to unmount |
| **etcd and state** | Nothing directly; everything through the API | Snapshot and restore proven; the space alarm; slow fsync seen in the API server | MVCC and revisions, compaction, defragmentation, Raft quorum, the watch cache and the 410 | Compaction and retention tuned; an external etcd topology | "What etcd does with one write" |
| **Authn, authz, admission** | kubeconfigs, RBAC, ServiceAccounts, `auth can-i` | Forbidden traced to verb, resource, group and namespace; a webhook outage; an expired token | The chain: x509 CN and O, bound tokens, RBAC evaluation, mutating then validating admission | A user issued through a CSR; a webhook with a failure policy you chose and defended; OIDC authentication | One request through the three gates, with what each refuses |
| **Isolation and security** | securityContext, Pod Security Admission labels | A PSA rejection, a seccomp denial, a missing capability, a read-only root crash | Namespaces, cgroups, capabilities, seccomp, AppArmor, user namespaces; what a shared node does and does not isolate | A seccomp profile from a trace; a RuntimeClass with a sandboxed runtime | "What a container isolates, and what it does not" |
| **Lifecycle, upgrades, HA** | kubeadm init, join, upgrade; certificate renewal | Expired certificates; a failed upgrade; version skew | Static pods, the PKI fan-out, the skew policy, stacked and external etcd, the load balancer on 6443 | A cluster built with no kubeadm; a custom CA; an external etcd | "What kubeadm wrote, and why" |
| **Resources and scale** | Requests and limits, HPA, quotas, LimitRange | Throttling vs OOM; eviction order; an autoscaler that does not scale | QoS and the cgroup math, the HPA algorithm, node autoscaling, the published scalability thresholds | A thousand simulated nodes; a load test; API server and etcd flags tuned with a measured effect | "What happens at ten thousand pods" |

**Scoring rule.** A rung is held only if every rung below it is held. Rung 3 is passed by a recorded fifteen-minute explanation checked against the cell; rung 4 by the artefact and its proof; rung 5 by the student of your explanation reaching rung 2.

---

## 3. The process

### After every lab: the thread

Every lab from week 1 has an entry in [`curriculum/KUBERNETES-THREAD.md`](curriculum/KUBERNETES-THREAD.md). After the lab, read its entry, run the **See it in Kubernetes** command when a cluster is at hand, and say the **Say it** sentence aloud. It takes five minutes and it is how the Linux, networking, AWS and Terraform weeks become Kubernetes understanding rather than prerequisites you once did. The entry's **Ladder** line says which topic and rung the lab fed.

### The eleven Go deeper labs

| Week | Lab | Hours | Topic · rung |
|---|---|---|---|
| 14 | The API, watched and audited | 3 | API machinery 3 · authn, authz, admission 3 |
| 15 | The scheduler, plugin by plugin | 3 | Scheduling 4 |
| 16 | CSI, sidecar by sidecar | 2 | Storage and CSI 3 |
| 27 | The kubelet, every ten seconds | 3 | Kubelet and runtime 3 · resources and scale 3 |
| 27 | A CNI plugin in forty lines of bash | 2 | Networking datapath 4 |
| 27 | etcd under the cluster | 3 | etcd and state 3 |
| 27 | Lab 1, the hard way: a cluster with no kubeadm | a day | Lifecycle, upgrades, HA 4 · authn 3 |
| 28 | Write the controller | 4 | Controllers 4 · API machinery 4 |
| 28 | The Service datapath, three ways | 3 | Networking datapath 3 |
| 28 | DNS, five queries for one name | 2 | DNS 3 |
| 30 | The cluster you cannot afford | 3 | Resources and scale 3 · scheduling 3 |

**When.** Inside the week if the week is ahead of schedule; otherwise one per week after week 30, in the order above, while the cadence continues. None of them is exam preparation; all of them are what the exam leaves out. Each ends with a "from memory, timed" line because rung 4 includes doing it again without the file.

### The explanation drill, at three depths

The week-25 discipline for stories, applied to mechanisms. For each of the twelve topics, three versions: **thirty seconds** (the sentence an interviewer hears first), **three minutes** (the figure, badge by badge), **fifteen minutes** (rung 3: the whiteboard, no notes, the hard part included). From week 14, one topic a week in the table's order, recorded on a phone, the fifteen-minute version scored against the rung-3 cell. After week 30 the cycle repeats monthly. The figures are the retrieval cue; the recording is the evidence.

### Scoring, at the gates

Score the rubric at Gate 4 (week 17), Gate 5 (21), Gate 6 (26), Gate 7 (30), and on the first Sunday of every month after that. Copy the table in §6 into `progress.md` under the gate's retrospective. A topic that has not moved in two scorings names the next Go deeper lab.

### The long-lived cluster

Everything in the program is destroyed nightly by design. That is right for cost and wrong for depth: certificate expiry, disk pressure, etcd growth, version skew and a forgotten CronJob are failures only time produces. From week 27, set `kubeadm_keep = true` in the GCP lab so the kubeadm nodes are excluded from the nightly stop, and keep the week-14 stack running on them through ArgoCD. Budget it: two e2-medium nodes around the clock cost roughly what the lab VM would, about fifty dollars a month, estimate it for your region. Then, on the first Sunday of each month:

1. `kubeadm certs check-expiration`; renew anything under ninety days and say why the kubelet's own certificate is not in the list.
2. `etcdctl endpoint status`: database size and revision; compact and defragment if the size has grown; check the alarm list.
3. Disk and image garbage collection on every node; eviction thresholds against actual usage.
4. The version skew page against the running versions; upgrade one minor when one is available, control plane first.
5. Break one thing from BF-41 to BF-64 that you have not broken this quarter, and time the diagnosis.
6. Write the five lines in the incident journal, including the **Surprised** line.

### Primary sources, on a schedule

Mastery of a system includes knowing where its code and its decisions live. One item a week from week 14, in topic order; after week 30, one a week continues. Paths are as of recent releases; `grep` for the package name if one has moved.

| Topic | Read | Code |
|---|---|---|
| API machinery | The API conventions document in the community repository (`contributors/devel/sig-architecture/api-conventions.md`) | `staging/src/k8s.io/apiserver/pkg/admission`; `staging/src/k8s.io/client-go/tools/cache` |
| Controllers | The `sample-controller` repository, top to bottom; the kubebuilder book | `pkg/controller/deployment`, `pkg/controller/replicaset` |
| Scheduling | The scheduling framework enhancement proposal (KEP-624) | `pkg/scheduler/framework`, `pkg/scheduler/framework/plugins` |
| Kubelet and runtime | The evented PLEG proposal (KEP-3386); the CRI API protobuf | `pkg/kubelet/pleg`, `pkg/kubelet/eviction`, `pkg/kubelet/cm` |
| Networking datapath | The CNI specification (`containernetworking/cni`, `SPEC.md`); the nftables proxy proposal (KEP-3866); EndpointSlices (KEP-752) | `pkg/proxy/iptables`, `pkg/proxy/ipvs`, `pkg/proxy/nftables`, `pkg/controller/endpointslice` |
| DNS | The Kubernetes DNS specification in the `kubernetes/dns` repository; the CoreDNS `kubernetes` plugin documentation | CoreDNS `plugin/kubernetes` |
| Storage and CSI | The CSI specification (`container-storage-interface/spec`) | `pkg/controller/volume/attachdetach`, `pkg/volume/csi` |
| etcd and state | etcd's "learning" documentation: data model, API guarantees; the Raft paper | `etcd/server/storage/mvcc` |
| Authn, authz, admission | The authentication and authorization reference pages; the Pod Security Admission proposal (KEP-2579) | `plugin/pkg/auth/authorizer/rbac`, `pkg/registry/rbac` |
| Isolation and security | `namespaces(7)`, `cgroups(7)` and `user_namespaces(7)`; the cgroup v2 kernel documentation; user namespaces for pods (KEP-127) | `pkg/kubelet/cm` (the cgroup managers) |
| Lifecycle, upgrades, HA | The kubeadm implementation-details page; the version skew policy; the upstream "Kubernetes the Hard Way" | `cmd/kubeadm/app/phases` |
| Resources and scale | The SIG Scalability thresholds document; the HPA algorithm page; the kwok and kube-burner documentation | `pkg/controller/podautoscaler`, `pkg/kubelet/cm/cgroup_manager_linux.go` |

### Write it down: the series

Rung 5 needs a student. The cheapest one is the public: twelve posts, one per topic, each with its figure, each written from the fifteen-minute recording. Weeks 14 to 30 produce the first five or six alongside the planned posts; the rest follow one a month. A post that a stranger used to debug something is a rung-5 pass. The posts are also the only rung an interviewer can see before the interview.

---

## 4. What the rungs sound like

The same question at three rungs, so the difference is audible. *"A Service returns nothing."*

- **Rung 2.** "`kubectl get endpoints`. No endpoints is the selector or readiness; endpoints but refused is the port or the bind address."
- **Rung 3.** "A Service is a selector and a virtual IP. The EndpointSlice controller watches pods matching the selector and writes their addresses with a `ready` condition taken from the readiness probe; kube-proxy on every node watches the slices and writes iptables rules that DNAT the ClusterIP to one of the ready addresses with a per-rule probability, and conntrack pins the choice for the connection's life. So no endpoints means the slice controller found nothing matching or nothing ready; refused means the DNAT happened and the container's socket is not on that port or is bound to loopback; a timeout means the DNAT happened and something between the nodes dropped it, which is a NetworkPolicy, a CNI that is not routing, or a node firewall. The one command splits the first two; `tcpdump` on the veth splits the third."
- **Rung 5.** The rung-3 answer, as a figure the listener redraws afterwards, and the listener then diagnoses BF-47 without you.

---

## 5. Where it sits in the program

| Week | What happens on the ladder |
|---|---|
| 1 to 13 | The thread, after every lab. The mechanisms are Linux, networking, AWS and Terraform; the thread says which Kubernetes component is made of each |
| 14 to 17 | The thread; the drill begins (one topic a week); Go deeper 14, 15, 16 if ahead; first scoring at Gate 4 |
| 18 to 26 | The thread; the drill continues; scoring at Gates 5 and 6; posts one to five |
| 27 to 30 | The module; Go deeper 27, 28, 30 if ahead; the long-lived cluster begins; scoring at Gate 7 |
| 31 on | One Go deeper lab a week until the eleven are done; the drill cycles monthly; the monthly checklist on the long-lived cluster; a post a month; scoring on the first Sunday |

---

## 6. The scoring table

Copy under each gate's retrospective in `progress.md`. The **Evidence** is a link or a file: a recording, a repository, a post, a journal entry.

```markdown
### Kubernetes ladder — <gate or month>, <date>

| Topic | Rung | Evidence | The next rung's test | Target date |
|---|---|---|---|---|
| API machinery | | | | |
| Controllers | | | | |
| Scheduling | | | | |
| Kubelet and runtime | | | | |
| Networking datapath | | | | |
| DNS | | | | |
| Storage and CSI | | | | |
| etcd and state | | | | |
| Authn, authz, admission | | | | |
| Isolation and security | | | | |
| Lifecycle, upgrades, HA | | | | |
| Resources and scale | | | | |

Moved since last time: <topics>. Stuck for two scorings: <topics> → next Go deeper lab: <which>.
```
