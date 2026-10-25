# Week 30 Labs

> **Figures:** one numbered mechanism figure per lab, with the spoken script, the numbers to own and
> the command that proves each badge, in [`FIGURES.md`](FIGURES.md) (30.2 to 30.6; 30.7 for the "Go deeper" scale lab at the end). Read a lab's figure
> before you start it; redraw it after.

> **Exam facts used in this file are planning estimates.** Two hours, about 15 to 20 weighted tasks,
> pass mark 66 %, results within 24 hours, one free retake, a certificate valid two years. Confirm
> every one of them in the candidate handbook at registration.

---

# Lab 1 — killer.sh Session 2: the Gate 7 Attempt (Mon, 3h)

The second session is the predictor. The first one, in week 29, was a diagnosis; this one is a
rehearsal under the exact rules of the gate.

## The rules of the gate

1. Start when you can give it two uninterrupted hours and come back the next day for the solutions.
2. Exam conditions: the ritual from figure 29.2, the triage order from figure 29.6, no notes, no
   shell history, the docs only.
3. **The solutions stay closed until the timer stops.** Opening them during the attempt voids the
   gate, whatever the score.
4. Score it. Log the score, the minutes left, and the missed tasks by family in the journal.

## The gate

| Result | Means |
|---|---|
| At or above the pass mark, inside two hours, solutions closed | **Gate 7 passed.** Sit the exam as booked |
| Below the pass mark by a few points | Sit the exam as booked. The simulator is harder than the exam by design; a near miss here is the usual story of a pass there. Tuesday and Thursday work the two families that cost the points |
| Well below, or more than a third of the tasks untouched | Move the exam one week, today, while the booking window still allows it; run weeks 27 and 28's labs for the two weakest domains again; retake this gate next Monday |

The third row is not failure. A fail on the real exam during an active job search costs more than a
week; the free retake is for a surprise, not for a predicted miss.

## The remaining access window

The same discipline as week 29: every missed or guessed task from the solution, reset, redone from
the task text, twice for the ones that surprised you. Write down which docs page each one needed.
Those pages are Thursday evening's reading.

---

# Lab 2 — Weak-Domain Drills (Tue and Thu, 3h each)

[`MOCK-EXAM-2.md`](MOCK-EXAM-2.md) is three sets of eight tasks, forty minutes each, one set per
family group:

| Set | Family | For the candidate whose misses were |
|---|---|---|
| A | Troubleshooting: application, control plane, node, networking | the thirty-percent domain |
| B | Cluster architecture and storage: kubeadm, etcd, certificates, upgrades, RBAC, PV and PVC, StorageClass | the install-and-configure and storage domains |
| C | Services, networking and workloads: Service types, Ingress, Gateway API, NetworkPolicy, DNS, rollouts, scheduling, Jobs, Helm, Kustomize | the three remaining domains |

Tuesday is your weakest family's set, run **three times**: once cold, once after reading the
solutions, once the next morning before anything else. Thursday is the second family, same three
runs. The number that matters is the third run's time, not the first run's score.

Each set needs the kubeadm cluster with the week-29 `shop` namespace seeded
(`week-29/solutions/SOLUTIONS.md`, `seed.sh`). `solutions/mock-exam-2-setup.sh A` plants Set A's
breaks; `B` and `C` create the two objects those sets assume. A partner runs it.

**Between runs:** redraw the lab figure for the family (29.3 for Set A, 27.2 to 27.5 for Set B,
28.2 to 28.6 for Set C). The figure is the retrieval; the set is the application.

---

# Lab 3 — The Exam Checklist (Thu evening, 1h)

Run this once on Thursday as a rehearsal, then again on exam morning. Every item is something a
candidate has lost an attempt to. Confirm the current rules in the candidate handbook and the
technical requirements page; they change, and the handbook wins over this list.

## The week before (already done, check it)

- [ ] Exam booked for Friday or Saturday of this week, confirmation email found, time zone checked twice
- [ ] The PSI secure browser installed and its system check passed on **the machine you will use**, on **the network you will use**
- [ ] Government ID whose name matches the registration exactly, not expired
- [ ] killer.sh session 2 done (Lab 1)

## The room and the desk

- [ ] A room with a door that closes. Nobody enters for two and a half hours; tell them
- [ ] The desk cleared: no papers, no second monitor unless the handbook allows it, no phone within reach
- [ ] The walls and the desk surface visible for the room scan; the proctor will ask for a 360° view
- [ ] A clear glass of water is usually allowed; check. Nothing else to eat or drink
- [ ] Headphones off, notifications off, every other application closed, the laptop on power

## The check-in

- [ ] Log in thirty minutes early. Check-in involves ID photos, the room scan, and a wait
- [ ] The proctor communicates by chat. Keep the chat visible
- [ ] Once the exam starts, the clock runs even if you are still arranging windows

## The first five minutes, inside the exam

- [ ] Aliases, `$do`, the `.vimrc`: figure 29.2, badges ③ and ④, from memory
- [ ] Read every task once with the weights; mark each: know it, maybe, no idea (figure 29.6, badge ①)
- [ ] The order written in the notes pane

## Every task

- [ ] The context line, `use-context`, `current-context` out loud
- [ ] The end state written as a command before the first edit
- [ ] Two minutes with no progress: flag and move on
- [ ] Verify by command, one line in the notes

## 1:50

- [ ] Nothing new. Flags, then every end-state command rerun

## If something breaks

- [ ] The remote desktop freezes or the terminal dies: tell the proctor in the chat **immediately**, with the time. Do not reboot, do not close the browser; the proctor can pause and restore the session, and the chat log is the record
- [ ] Your network drops: reconnect, reopen the secure browser; the session usually resumes. Note the time lost and tell the proctor
- [ ] The proctor asks you to do something (show the desk again, move the camera): do it at once; arguing costs time and can end the session

## The day before

- [ ] No new material. One run of Tier 4 of the speed drill, one read of figures 29.2 and 29.6, and stop by early evening
- [ ] Sleep. The literature on this is not subtle: a short night costs more points than a day of study buys

---

# Lab 4 — Exam Day (Fri or Sat)

## Morning

- Eat. Water on the desk. Thirty minutes early at the laptop with the checklist from Lab 3 open.
- Say the ritual once, out loud, before the check-in: context, end state, generate, edit, apply,
  verify, note.
- Say the triage rules once: bank, two minutes, long ones in the middle, nothing new after 1:50.

## In the exam

Everything is figures 29.2 and 29.6. There is nothing else to think about, which is the point of
having drilled them.

## Within an hour afterwards

Before the result, while it is fresh, write the note to self in the journal:

- Which tasks felt like the simulator, which did not
- The task you spent longest on, and whether the two-minute rule would have saved it
- The docs lookups that took over thirty seconds
- Any wrong-context moment, caught or not
- One line: what you would tell yourself on Thursday evening

Then close the laptop. The result arrives within about 24 hours (confirm in the handbook); refreshing
the page does not shorten that.

---

# Lab 5 — After (Sun, 2h)

## The result

**Pass.** The same day: the certificate's verification link into the résumé's certifications line
and the LinkedIn certifications section, with a short post that says what the preparation actually
was (the kubeadm cluster, the twelve breaks, two simulator sessions), not just the badge. Update the
tracker; every open application with a Kubernetes mention gets a one-line follow-up.

**Fail.** The same day: book the free retake for two weeks out, before the disappointment turns into
avoidance. Read the score report's domain breakdown. Name the two weakest domains and the week that
rebuilds each (27 for cluster architecture and node troubleshooting, 28 for workloads, networking and
storage, 29 for speed). Those two weeks' labs, done again from the lab text with the figures closed,
are the next two weeks' lab hours; Mock Exam 2's sets are the check before the retake. Nothing else
changes: the cadence continues, the applications go out, and the retake is a date on the calendar,
not a verdict.

## The retrospective, either way

Three questions, in the journal:

1. **What did the simulator predict correctly?** The families, the pace, the docs lookups.
2. **What did it not predict?** The remote desktop's lag, the check-in, the thing you froze on.
3. **Which figure saved the most time?** That figure is the one to keep redrawing monthly; the
   rest can rest.

## The CKS decision

`ROADMAP.md` §8 puts CKS in year two: it assumes CKA and operating experience, and the hours it
would take belong to interviewing and building now. Two things override that. A target employer's
postings naming CKS by name, or the first job turning out to be security-platform work. Otherwise
write "CKS: revisit at month 12" in the plan and move on.

## Week 31

Monday is the week-26 cadence again: twenty hours interviewing, ten building, ten on preparation and
people. The kubeadm nodes: `terraform apply -var kubeadm_nodes=0` in `_setup/gcp-lab/` unless the
retake needs them. The figures from weeks 27 to 30 join the monthly redraw rotation; the exam, passed
or booked, becomes a line in the STAR story about learning something hard on a deadline.

---

# Go deeper — The cluster you cannot afford (3h · ladder: resources and scale, rung 3; scheduling, rung 3)

**After the exam, optional inside the week, mandatory for the ladder** ([`KUBERNETES-MASTERY.md`](../../../KUBERNETES-MASTERY.md)).
Everything so far ran on three nodes. The behaviours that define a platform engineer's judgement
(what the scheduler does with a thousand pending pods, what the API server does under a storm of
writes, what etcd's size limit means) only appear at a scale you cannot rent for a lab. kwok fakes
the nodes; kube-burner makes the load; the control plane is real. On kind, on the laptop.

```bash
cat > kind-scale.yaml <<'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    kubeadmConfigPatches:
      - |
        kind: ClusterConfiguration
        apiServer:
          extraArgs:
            max-requests-inflight: "800"            # default 400: you will see why this matters
EOF
kind create cluster --name scale --config kind-scale.yaml
```

## Part 1 — A thousand nodes with no kubelets (45 min)

kwok (Kubernetes WithOut Kubelet) is a controller that watches Nodes and Pods carrying its
annotation and plays the kubelet's part: it marks the node Ready, moves pods through Pending → Running,
and never runs a container. Install it into the cluster, then its "stages" (the state machine it
follows for nodes and pods); the flags and manifests are the project's own, read its docs for your
version:

```bash
kubectl apply -f https://github.com/kubernetes-sigs/kwok/releases/latest/download/kwok.yaml
kubectl apply -f https://github.com/kubernetes-sigs/kwok/releases/latest/download/stage-fast.yaml
kubectl -n kube-system get deploy kwok-controller
```

A node template, applied a thousand times with a different name:

```bash
cat > node.tpl <<'EOF'
apiVersion: v1
kind: Node
metadata:
  name: kwok-node-__N__
  annotations: { node.alpha.kubernetes.io/ttl: "0", kwok.x-k8s.io/node: fake }
  labels: { type: kwok, kubernetes.io/role: agent, node.kubernetes.io/instance-type: fake }
spec:
  taints: [{ key: kwok.x-k8s.io/node, value: fake, effect: NoSchedule }]
status:
  allocatable: { cpu: "32", memory: 256Gi, pods: "110" }
  capacity:    { cpu: "32", memory: 256Gi, pods: "110" }
EOF
time (for i in $(seq 1 1000); do sed "s/__N__/$i/" node.tpl; echo ---; done | kubectl apply -f - >/dev/null)
kubectl get nodes -l type=kwok --no-headers | awk '{print $2}' | sort | uniq -c       # 1000 Ready
```

Now pods. A Deployment whose template tolerates the taint and selects the fake nodes, scaled in steps,
while you watch the scheduler work:

```bash
kubectl create deploy load --image=registry.k8s.io/pause:3.10 --replicas=0 -o yaml --dry-run=client \
 | kubectl patch -f - --local -o yaml --type=merge -p '{"spec":{"template":{"spec":{"nodeSelector":{"type":"kwok"},"tolerations":[{"key":"kwok.x-k8s.io/node","operator":"Exists"}]}}}}' \
 | kubectl apply -f -
kubectl scale deploy load --replicas=2000
watch -n2 'kubectl get pods --no-headers | awk "{print \$3}" | sort | uniq -c'     # Pending drains into Running at the scheduler's pace
kubectl scale deploy load --replicas=10000                                            # if the laptop allows; stop at the first swap
```

Measure, do not guess. The API server exposes its own metrics; the scheduler's are behind its
authenticated port, so give yourself a token that may read `/metrics`:

```bash
kubectl get --raw /metrics | grep -E '^apiserver_request_total' | awk -F'[{}]' '{n[$2]++} END {print length(n), "series"}'
kubectl get --raw /metrics | grep -E '^apiserver_request_total\{.*resource="pods".*verb="(POST|PATCH|LIST|WATCH)"' | awk '{s+=$NF} END {print s, "pod requests so far"}'
kubectl get --raw /metrics | grep -E '^etcd_request_duration_seconds_(sum|count)\{operation="create".*type=".*pods"' 
kubectl get --raw /metrics | grep -E '^apiserver_current_inflight_requests'          # against max-requests-inflight

kubectl create clusterrole metrics-reader --non-resource-url=/metrics --verb=get
kubectl create clusterrolebinding metrics-reader --clusterrole=metrics-reader --serviceaccount=default:default
kubectl -n kube-system port-forward pod/kube-scheduler-scale-control-plane 10259:10259 &
curl -sk -H "Authorization: Bearer $(kubectl create token default)" https://localhost:10259/metrics \
 | grep -E '^scheduler_(schedule_attempts_total|pending_pods|scheduling_attempt_duration_seconds_count)'
```

`scheduler_schedule_attempts_total{result="scheduled"}` divided by the wall clock is your scheduler's
throughput on this laptop: on the order of a hundred or a few hundred pods a second with these fake
nodes. `scheduler_pending_pods{queue="active"}` is the queue draining. Write the numbers down; they
are the ones you quote.

## Part 2 — kube-burner: load with a report (40 min)

kube-burner creates objects from templates at a rate and measures how long pods take to become Ready
(which, with kwok, is the control plane's latency alone, since no image is pulled). The config schema
is kube-burner's; the fields below are the ones that matter, check its docs for your version:

```bash
mkdir churn && cd churn
cat > deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata: { name: churn-{{.Iteration}}-{{.Replica}} }
spec:
  replicas: {{.podReplicas}}
  selector: { matchLabels: { app: churn-{{.Iteration}}-{{.Replica}} } }
  template:
    metadata: { labels: { app: churn-{{.Iteration}}-{{.Replica}} } }
    spec:
      nodeSelector: { type: kwok }
      tolerations: [{ key: kwok.x-k8s.io/node, operator: Exists }]
      containers: [{ name: pause, image: registry.k8s.io/pause:3.10 }]
EOF
cat > config.yaml <<'EOF'
global:
  measurements:
    - name: podLatency
jobs:
  - name: churn
    jobType: create
    jobIterations: 50
    namespace: churn
    namespacedIterations: true
    qps: 20
    burst: 20
    cleanup: true
    objects:
      - objectTemplate: deployment.yaml
        replicas: 2
        inputVars: { podReplicas: 10 }
EOF
kube-burner init -c config.yaml --log-level info
ls collected-metrics/ 2>/dev/null; cat podLatency-summary* 2>/dev/null | head        # P50 / P99 for ContainersReady, Ready, PodScheduled
```

Fifty namespaces, two Deployments each, ten pods each: a thousand pods at twenty requests a second.
Raise `qps` and `burst` until the API server's `apiserver_flowcontrol_request_queue_length_after_enqueue`
climbs and `apiserver_current_inflight_requests` sits at the limit; that is Priority and Fairness
shedding load, and it is the behaviour that keeps a cluster alive during a bad deploy.

## Part 3 — The thresholds, and what you brushed (20 min)

The published limits for a single cluster (the "considerations for large clusters" page, and SIG
Scalability's thresholds document) are the numbers an interviewer expects you to know and to know
the reason for:

| Limit | Why it is the limit |
|---|---|
| 5,000 nodes | the API server's watch fan-out and the node heartbeat load (Leases made this possible at all) |
| 150,000 pods · 300,000 containers | etcd object count and the size of the lists controllers must hold in memory |
| 110 pods per node | the kubelet's PLEG and cgroup bookkeeping, and the pod CIDR per node (a /24) |
| 2 GiB etcd backend quota by default, 8 GiB recommended maximum | etcd keeps the whole keyspace in memory-mapped storage; above that, compaction and defrag cannot keep latency down |
| 100 endpoints per EndpointSlice | one pod change rewrites one slice, not the whole Service |
| 400 / 200 in-flight requests by default (read / mutating) | the API server's protection against itself, before Priority and Fairness |

Say which ones Part 1 and Part 2 touched: pods per node (110 is in your node template), inflight
requests, and the scheduler's queue. Then say which you did not: 5,000 nodes is a kind cluster's
memory away, and the etcd quota is what the next part is about.

## Part 4 — What breaks first, and in what order (30 min)

Push until something fails, and name it when it does:

```bash
kubectl scale deploy load --replicas=15000          # beyond the 110 × 1000 fake capacity: Pending with "0/1000 nodes are available: 1000 Too many pods"
docker exec scale-control-plane etcdctl --endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key endpoint status -w table   # DB SIZE climbing
kubectl get --raw /metrics | grep -E '^apiserver_watch_cache_.*(pods|events)'       # the watch cache, one per resource, in memory
kubectl -n kube-system logs kube-controller-manager-scale-control-plane | grep -i 'endpointslice' | tail -3
```

The order, in a real cluster, is usually: (1) the scheduler's queue grows but it keeps up, until
(2) the API server's inflight limit queues requests and latency climbs, then (3) controllers that
list large kinds (endpoint slices for a Service with thousands of pods, the garbage collector) fall
behind and (4) etcd's database approaches its quota, compaction stops keeping up, and `etcdserver:
mvcc: database space exceeded` turns the cluster read-only. Each one has a metric above. Meanwhile a
Cluster Autoscaler would be reading the same `Pending` pods and asking the cloud for nodes, one
scale-up loop at a time; Karpenter would be bin-packing them into the fewest, largest instances it
can launch in one call. With kwok there is nothing to launch, which is the point: you are watching
the control plane's limits with the data plane removed.

```bash
kind delete cluster --name scale
```

## Part 5 — The explanation drill (15 min)

Fifteen minutes on a whiteboard, recorded, no notes: **"What happens at ten thousand pods?"** The
expected shape: the objects (ten thousand Pod objects in etcd, each a few kilobytes), the scheduler
(one queue, filter and score per pod, throughput you measured), the watches (every kubelet, every
controller, kube-proxy on every node receiving a stream), the slices, the node capacity, and the
first three things that break in order. This is rung 3 of two topics at once, and it is the
difference between "Kubernetes scales" and knowing where it stops.

**Prove it.** Each number in your explanation has a command above that printed it. Say the command
with the number.
