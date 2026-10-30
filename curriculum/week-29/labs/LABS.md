# Week 29 Labs

> **Figures:** one numbered mechanism figure per lab, with the spoken script, the numbers to own and
> the command that proves each badge, in [`FIGURES.md`](FIGURES.md) (29.2 to 29.6). Read a lab's figure
> before you start it; redraw it after.

> **Exam facts used in this file are planning estimates.** Two hours, about 15 to 20 weighted tasks,
> pass mark 66 %, a remote Linux desktop inside the PSI secure browser, the Kubernetes and Helm docs
> allowed. Confirm every one of them in the candidate handbook at registration.

---

# Lab 1 — The Exam Terminal (Mon, 3h)

The exam terminal is a remote desktop inside a browser. You get one window: a terminal, a browser
tab for the docs, and the task pane. The ritual below is what you do in it, the same way, every
task. By Friday it should be reflex.

## Part 1 — The setup you type in the first ninety seconds

The exam environment ships with `kubectl` completion and `k` already aliased on recent versions;
confirm it, and set the rest yourself. Type these from memory; do not paste them from a note you will
not have.

```bash
alias k=kubectl
export do="--dry-run=client -o yaml"
export now="--force --grace-period=0"
complete -o default -F __start_kubectl k      # keeps completion working on the alias
kn() { kubectl config set-context --current --namespace="$1"; }

cat > ~/.vimrc <<'EOF'
set tabstop=2 shiftwidth=2 expandtab
set number
syntax on
EOF
```

`expandtab` is not cosmetic. A tab character in YAML is a parse error, and `kubectl apply` says so
in a way that costs a minute to read. The `.vimrc` makes the mistake impossible.

## Part 2 — Generate, never hand-write

The speed drill's Tier 1 is the list; this part is the habit. For every task that creates an
object, the first command is an imperative generator with `$do`, redirected to a file, then edited.

```bash
k create deploy web --image=nginx:1.27 --replicas=3 $do > web.yaml
k expose deploy web --port=80 --target-port=8080 $do > svc.yaml
k run probe --image=busybox:1.36 --command $do -- sleep 3600 > pod.yaml
k create job once --image=busybox:1.36 $do -- sh -c 'date' > job.yaml
k create cj nightly --image=busybox:1.36 --schedule='0 2 * * *' $do -- sh -c 'date' > cj.yaml
k create ingress web --rule='shop.local/*=web:80' --class=nginx $do > ing.yaml
k create role pod-reader --verb=get,list,watch --resource=pods $do > role.yaml
k create rolebinding rb --role=pod-reader --serviceaccount=shop:deployer $do > rb.yaml
```

What the generators cannot produce, you add in vim with `kubectl explain` open in a second terminal
tab. These are the fields that come up every time:

```bash
k explain pod.spec.containers.livenessProbe --recursive | less
k explain pod.spec.affinity.nodeAffinity --recursive
k explain pod.spec.tolerations
k explain deployment.spec.strategy.rollingUpdate
k explain pvc.spec
k explain networkpolicy.spec --recursive
```

**Task:** generate each of the eight objects above, add the fields the generator cannot (a probe, a
toleration, a nodeSelector, a securityContext, a volume), apply them to kind, and time the whole
set. Target: under twelve minutes for all eight, applied and verified.

## Part 3 — Reading the cluster fast

```bash
k get pods -A -o wide --sort-by=.metadata.creationTimestamp | tail
k get pods -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName,IP:.status.podIP,RESTARTS:.status.containerStatuses[0].restartCount
k get pod X -o jsonpath='{.status.containerStatuses[0].lastState.terminated.exitCode}{"\n"}'
k get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.nodeInfo.kubeletVersion}{"\n"}{end}'
k get svc web -o jsonpath='{.spec.clusterIP}:{.spec.ports[0].port}{"\n"}'
k get events -A --sort-by=.lastTimestamp | tail -20
k get pods -A --field-selector status.phase!=Running
```

Several exam tasks ask you to write a result to a file on the node (`/opt/answers/...`). The
pattern is the same every time: the query, then `> file`, then `cat file` to prove it. Practise
writing the file, not just the query.

## Part 4 — The docs in thirty seconds

The docs search box is slow and the results are ranked oddly. The fast path is the search term that
lands on the right page first time, then `Ctrl-F` for the example. Twenty pages, each with the term
that finds it. Time each one; anything over thirty seconds goes on the Sunday list.

| Need | Search term | What you copy from the page |
|---|---|---|
| A pod with two containers and a shared volume | `communicate between containers same pod` | the `emptyDir` example |
| Probes | `configure liveness readiness startup probes` | the three probe blocks |
| Put a pod on a node | `assign pods nodes` | `nodeSelector`, `nodeAffinity` |
| Taints | `taints and tolerations` | the `tolerations` block |
| Deployment rollout fields | `deployments` | `strategy.rollingUpdate`, `kubectl rollout` |
| DaemonSet | `daemonset` | the manifest, the toleration for control-plane nodes |
| Job | `jobs run to completion` | `completions`, `parallelism`, `backoffLimit` |
| CronJob | `cronjob` | `concurrencyPolicy`, `successfulJobsHistoryLimit` |
| Service types | `service` | the `NodePort` and headless examples |
| Ingress | `ingress` | the `pathType: Prefix` rule, `ingressClassName` |
| Gateway API | `gateway api` | `Gateway` and `HTTPRoute` examples |
| NetworkPolicy | `network policies` | the default-deny and the `namespaceSelector` examples |
| DNS names | `dns for services and pods` | the FQDN form `svc.ns.svc.cluster.local` |
| PV and PVC | `configure pod persistentvolume storage` | the hostPath PV and the PVC |
| StorageClass | `storage classes` | `volumeBindingMode`, `reclaimPolicy` |
| RBAC | `using rbac authorization` | Role, RoleBinding, `kubectl auth can-i` |
| etcd backup | `operating etcd clusters` | `etcdctl snapshot save` with the three cert flags |
| Upgrade | `upgrading kubeadm clusters` | the control-plane and worker sequences |
| Certificates | `certificate management kubeadm` | `kubeadm certs check-expiration`, `renew` |
| Debug a service | `debug services` | the endpoints and DNS checks |

The Helm docs are allowed too: `helm install --values`, `helm upgrade`, `helm rollback`, and
`helm template` are the four commands; the page is `helm.sh/docs/helm/helm_install` and its
siblings.

## Part 5 — The per-task ritual

Every task in the exam starts with a line naming the context to use. Half of the stories about
"I did the task perfectly and got zero" are a task done in the wrong cluster. The ritual:

```
1. Read the context line. Read the END STATE the task describes. Only then read the middle.
2. kubectl config use-context <name>
3. kubectl config current-context          # say it out loud, compare to the task pane
4. Do the task. Generate, edit, apply.
5. Verify the END STATE with a command, not with your memory of having typed it.
6. One line in the notes: task number, done or flagged, anything to come back to.
```

**Task:** run the ritual twelve times on kind with twelve trivial tasks (a namespace, a pod, a
configmap, a secret, a service, a scale, a label, a rollout, a role, a binding, a quota, a
cronjob). Time the ritual overhead per task; it should settle under forty seconds. That forty seconds,
times eighteen tasks, is the twelve minutes that the ritual costs and that the wrong-context mistake
costs ten times over.

---

# Lab 2 — Troubleshooting on Real Nodes, Timed (Tue, 3h)

Thirty percent of the exam, and the part kind cannot teach. Four families, three scenarios each,
on the kubeadm cluster, with a partner or a script choosing. Each scenario is a break from BF-41 to
BF-64 wearing exam clothes: a task description, an expected end state, and a timer.

## The four families and their first command

| Family | You see | First command | Then |
|---|---|---|---|
| **Application** | a pod not Running or not Ready, a Service returning nothing | `k describe pod`, events first | `logs --previous` → `get endpoints` → `auth can-i` |
| **Control plane** | `kubectl` times out or refuses; the API answers but nothing reconciles | `ssh k8s-cp`, then `crictl ps` and `ls /etc/kubernetes/manifests` | `journalctl -u kubelet`, the static-pod manifest you edited last, `crictl logs` |
| **Worker node** | a node `NotReady`; pods on it stuck or evicted | `k describe node`, Conditions | `ssh` to it: `systemctl status kubelet containerd`, `journalctl -u kubelet -n 50`, `df -h` |
| **Networking** | pods Running, nothing reachable; DNS fails | `k get endpoints`, then `k get netpol -A` | CoreDNS pods and ConfigMap, CNI pods in `kube-system`, `crictl` on the node for the CNI binary |

The families are also figure 29.3. Learn the first command cold; the rest is the ladder from figure 17.3.

## The discipline that scores points

Before touching anything, read the task's **expected end state** and write it as a command:
"`k get nodes` shows `k8s-w2 Ready`", "`k -n shop get endpoints web` lists three IPs",
"`k get pods -n kube-system` shows `kube-apiserver-k8s-cp Running`". That command is both your
finish line and your proof. Fixing the wrong thing beautifully scores zero.

## The twelve scenarios

Build `break.sh` on the control plane. A partner runs it, or you run it with the output hidden.
Each case is one line of narrative in the exam's voice.

```bash
cat > break.sh <<'SH'
#!/usr/bin/env bash
# Twelve exam-shaped breaks on the kubeadm cluster. Run on k8s-cp as root.
# A partner runs this and reads you ONLY the task line. Diagnose under a timer.
set -euo pipefail
W="${WORKER:-k8s-w2}"
case "${1:-$((RANDOM % 12))}" in
  # --- application -------------------------------------------------------------
  0) kubectl -n shop set image deploy/web web=nginx:1.27-nonexistent
     echo "TASK: the web deployment in namespace shop is not rolling out. Make all replicas Ready." ;;
  1) kubectl -n shop set env deploy/api APP_PORT=80 ; kubectl -n shop patch svc api -p '{"spec":{"selector":{"app":"api-v2"}}}'
     echo "TASK: service api in namespace shop returns connection errors. Make 'curl api.shop' from any pod return 200." ;;
  2) kubectl -n shop patch role pod-reader --type=json -p '[{"op":"replace","path":"/rules/0/verbs","value":["get"]}]'
     echo "TASK: the deployer ServiceAccount in shop must be able to list and watch pods. It cannot. Fix the RBAC." ;;
  # --- control plane -----------------------------------------------------------
  3) sed -i 's/--etcd-servers=https:\/\/127.0.0.1:2379/--etcd-servers=https:\/\/127.0.0.1:2378/' /etc/kubernetes/manifests/kube-apiserver.yaml
     echo "TASK: kubectl on the control plane returns 'connection refused'. Restore the API server." ;;
  4) sed -i 's/    - kube-scheduler/    - kube-schedulerr/' /etc/kubernetes/manifests/kube-scheduler.yaml
     echo "TASK: new pods stay Pending with no FailedScheduling event. Find out why and fix it." ;;
  5) mv /etc/kubernetes/admin.conf /etc/kubernetes/admin.conf.bak; cp /etc/kubernetes/kubelet.conf /etc/kubernetes/admin.conf
     echo "TASK: kubectl on the control plane now gets 'Forbidden' for most commands. Restore admin access." ;;
  # --- worker node -------------------------------------------------------------
  6) ssh "$W" 'sudo systemctl stop kubelet'
     echo "TASK: node $W is NotReady. Make it Ready and keep it Ready across a reboot." ;;
  7) ssh "$W" 'sudo systemctl stop containerd'
     echo "TASK: pods scheduled to $W are stuck ContainerCreating. Fix the node." ;;
  8) ssh "$W" 'sudo dd if=/dev/zero of=/var/lib/fill.img bs=1M count=$(( $(df --output=avail -m /var/lib | tail -1) - 200 )) status=none'
     echo "TASK: pods on $W are being evicted. Find the cause and clear it." ;;
  # --- networking ------------------------------------------------------------------
  9) kubectl -n kube-system get cm coredns -o yaml | sed 's/forward \. \/etc\/resolv.conf/forward . 10.255.255.1/' | kubectl apply -f -
     kubectl -n kube-system rollout restart deploy coredns
     echo "TASK: pods cannot resolve external names; cluster names still work. Fix DNS." ;;
  10) kubectl -n shop apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: deny-all }
spec: { podSelector: {}, policyTypes: [Ingress, Egress] }
EOF
     echo "TASK: nothing in namespace shop can talk to anything. The deny-all policy must stay. Allow DNS and allow web -> api on 8080 only." ;;
  11) kubectl -n kube-system patch ds calico-node --type=json -p '[{"op":"add","path":"/spec/template/spec/nodeSelector","value":{"nope":"true"}}]'
     echo "TASK: new pods on every node are stuck ContainerCreating with 'network plugin not ready'. Fix it." ;;
esac
echo "timer started: $(date +%T)"
SH
chmod +x break.sh
```

The `shop` namespace with `web`, `api`, the `pod-reader` role and the `deployer` ServiceAccount is
the week-14 stack; `solutions/SOLUTIONS.md` has a one-shot `seed.sh` that creates it.

**Tasks:**
1. Run all twelve, in random order, timed. Target under ten minutes each; log every one in the
   incident journal with the family, the first command, and the Surprised line.
2. For the three control-plane breaks, write down the **one file** you edited to fix it. The exam
   asks for that file path as often as it asks for the fix.
3. For case 6, prove the "across a reboot" clause: `systemctl is-enabled kubelet`. A fix that does
   not survive the reboot scores zero on that clause.
4. Re-run the three you were slowest on. The second time is the time that counts.

---

# Lab 3 — Mock Exam 1 (Thu, 3h)

[`MOCK-EXAM-1.md`](MOCK-EXAM-1.md) is eighteen tasks with weights summing to 100, split in the
blueprint's proportions: Troubleshooting 30, Cluster Architecture 25, Services and Networking 20,
Workloads and Scheduling 15, Storage 10. Each task names a context, a namespace, and a precise end
state. Nothing in it is a trick; everything in it is weeks 14 to 28.

## Setup

A partner, or you with your eyes on the ceiling, runs `solutions/mock-exam-1-setup.sh` on `k8s-cp`.
It creates the contexts and namespaces and plants the broken states. Do not read it; it tells you
what is broken.

## The rules

- Two hours on a visible timer. No notes, no shell history from earlier labs (`history -c`).
- The docs are allowed. Nothing else is.
- Say the ritual out loud for every task. Flag with a line in `/opt/answers/notes.txt`.
- When the timer stops, stop. A task finished at 2:01 is a task not finished.

## Scoring

`solutions/MOCK-EXAM-1-SOLUTIONS.md` has the solution and a verification command for each task.
Run the verification; award the task's full weight only when it passes exactly. Add them up. Write
the score, the time per task, and the missed tasks in the journal.

Then the part that improves the score: **redo every missed task from the solution, without the
timer, and say why the first attempt missed.** Wrong context, wrong namespace, wrong field name,
skipped verification, ran out of time: five different causes with five different fixes. Tally
them. That tally is the first input to Sunday's weak-domain list.

---

# Lab 4 — killer.sh Session 1 (Fri, 3h)

The exam package includes two simulator sessions, each with 36 hours of access once started
(confirm at registration). The simulator is deliberately harder than the exam. It is the single
most predictive practice you will do, so the way you take it matters.

## How to take it

1. Start the session at a time you can give it two uninterrupted hours **and** come back to it the
   next day. The 36 hours start when you click.
2. The two hours: exam conditions. The ritual, the triage order from Lab 5, no notes, the docs only.
3. Score it. The simulator scores itself; write the number down and the time you had left.
4. The remaining access window is where the learning is. Open the solutions. For **every task you
   missed or guessed at**, read the solution, understand which field or command you did not know,
   then **reset the environment and do it again from the task text**. Twice for the ones that
   surprised you.
5. The solutions page for each task also lists the docs page the task maps to. Add any you did not
   know to Lab 1's table.

## The weak-domain tally

The simulator tells you which tasks you missed. Map each to one of the four troubleshooting families
or one of the five blueprint domains and count. Two counts win. Those two are week 30's Tuesday and
Thursday, drilled from `week-30/labs/MOCK-EXAM-2.md`.

A fair warning that is in every candidate's story: a first simulator score well under the pass mark
is normal and predicts nothing. The second session, in week 30, is the one that predicts.

---

# Lab 5 — Break/Fix and the Triage Drill (Sat, 4h)

## Part 1 — Rebuild the weak domains (2h)

Take the two weakest families from Lab 4 and go back to the week that taught them: week 27 for
cluster architecture and node failures, week 28 for workloads, networking and storage, weeks 14 to
15 for application failures. Redo that week's lab for the domain, from the lab text, with the
figure closed. Then redraw the figure.

## Part 2 — The triage drill (1h)

The exam gives you about eighteen tasks of unequal weight and one clock. Order matters more than
most candidates believe, because the long tasks (an etcd restore, a node upgrade) can eat twenty
minutes each, and a flagged task returned to with five minutes left scores nothing.

Print the task list of Mock Exam 1 with the weights and nothing else. Five minutes: read every
task once, write the family and a difficulty mark next to each, and produce an order. The rules:

1. **High weight and known** first. These are the points you are certain of; bank them.
2. **The two-minute rule.** Two minutes into any task with no progress, flag it and move on. Not
   five; two. The feeling that you are nearly there is exactly the feeling that costs forty minutes.
3. **The long ones in the middle,** not last. An etcd restore at 1:50 is a panic; at 0:45 it is a
   task.
4. **Skip the unknown low-weight entirely.** A 3-point task you do not know how to start is a task
   you do not do. Say so out loud; it is the hardest rule to follow.
5. **The last ten minutes** are for flagged tasks you half-finished, and for verification. Nothing
   new starts after 1:50.
6. **Partial credit is real.** A task scored on three checks awards the checks you passed. Leave a
   half-done task applied; do not delete it in frustration.

Do the drill three times with three different random weightings (the solutions file has two more).
Each time, compare your order against the rules. The drill is figure 29.6.

## Part 3 — The loop, one more time (1h)

Run `break.sh` from Lab 2 three times on cases you have not seen twice. Narrate, time, log. Then
`bash ../_setup/03-teardown.sh`, and let the nodes stop at midnight.
