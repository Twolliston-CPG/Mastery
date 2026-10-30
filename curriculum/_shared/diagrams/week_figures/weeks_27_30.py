F = {}

# The CKA module: month 7, weeks 27 to 30, run alongside the week-26 cadence.
# Exam facts in these scripts are planning estimates; the candidate handbook is the contract.

F[27] = dict(
 title="A cluster you built by hand, and what kubeadm wrote",
 intro="kind hides the quarter of the exam that lives on real nodes. The blue path is one cluster from kubeadm init to an upgraded worker; every box is a file or a command you can point at on k8s-cp.",
 body='''
  INIT["① kubeadm init<br/><small>k8s-cp · preflight wants 2 CPUs · --pod-network-cidr · the join command it prints</small>"]:::crit
  STATIC["② four static pods<br/><small>/etc/kubernetes/manifests · the kubelet starts apiserver, controller-manager, scheduler, etcd</small>"]:::crit
  PKI["③ PKI and kubeconfigs<br/><small>/etc/kubernetes/pki · admin.conf · certs check-expiration · client certs last one year</small>"]:::crit
  CNI["④ Calico<br/><small>VXLAN · nodes go Ready · NetworkPolicy is enforced, unlike kind's default</small>"]:::crit
  JOIN["⑤ kubeadm join<br/><small>token lives 24 h · CA hash proves the control plane · k8s-w1, k8s-w2</small>"]:::crit
  ETCD["⑥ etcd snapshot and restore<br/><small>etcdctl with --cacert --cert --key · restore to a new data-dir · repoint the manifest</small>"]:::data
  UPG["⑦ upgrade one minor<br/><small>control plane first: upgrade plan, apply, kubelet · each worker: drain, upgrade, uncordon</small>"]:::crit
  HA["⑧ HA control plane<br/><small>three control planes · stacked or external etcd · a load balancer on 6443 · a reading, not a build</small>"]:::mut
  BF["⑨ node break/fix · BF-59 to BF-64<br/><small>kubelet · certificate · manifest typo · CNI · containerd · etcd</small>"]:::warn
  BOOK["⑩ book the exam now<br/><small>for the end of week 30 · two killer.sh sessions · one free retake</small>"]:::data
  INIT ==> STATIC ==> PKI ==> CNI ==> JOIN ==> ETCD ==> UPG
  UPG -.-> BF
  JOIN -.-> HA
  UPG -.-> BOOK
''',
 link="linkStyle 0,1,2,3,4,5 stroke:#2f6fb8,stroke-width:2px",
 minutes="three and a half",
 open="Week 17 you ran kubeadm once, by hand. This week you own it. Two or three VMs in the lab project, no kind, and by Saturday you have initialised, joined, backed up, restored, upgraded and broken the cluster, and you can say what every file under /etc/kubernetes is for. That is the quarter of the exam kind could not teach.",
 badges=[
  ("kubeadm init", "On k8s-cp. Preflight wants two CPUs and a few gigabytes; the pod network CIDR has to match the CNI you install next; and the join command it prints is the token plus the CA hash, so save it. Everything the next four badges describe is what this one command wrote."),
  ("four static pods", "The kubelet reads /etc/kubernetes/manifests and runs whatever is there with no API server involved. That is how the API server itself starts. A typo in one of those files takes the control plane down, and kubectl cannot tell you, because kubectl needs the thing that is down. crictl can."),
  ("PKI and kubeconfigs", "A CA in /etc/kubernetes/pki, client certificates for every component, and admin.conf for you. kubeadm certs check-expiration shows the dates; the client certificates last a year and renew with one command. A kubeconfig is three things: a server, a CA to trust it by, and a credential."),
  ("Calico", "Nodes stay NotReady until a CNI runs. Calico in VXLAN mode here, chosen because it enforces NetworkPolicy, which week 19 showed the kind default does not. Every pod gets an address from the CIDR you passed to init."),
  ("kubeadm join", "A worker joins with a token that lives twenty-four hours and a hash of the CA, so the worker can prove it is talking to the right control plane. Lose the token and kubeadm token create prints a new one; the hash does not change."),
  ("etcd snapshot and restore", "etcdctl snapshot save, with the three certificate flags, because etcd listens with TLS and nothing else. Restore into a new data directory, point the static-pod manifest at it, and prove it: an object created after the snapshot must be gone. Do it twice; the exam asks for exactly this."),
  ("upgrade one minor", "The nodes are installed one minor below the exam's version on purpose. kubeadm upgrade plan, then apply on the control plane, then its kubelet. Each worker: drain, upgrade the packages, kubeadm upgrade node, restart the kubelet, uncordon. The order is the content."),
  ("HA control plane", "Three control planes behind a load balancer on 6443, etcd either stacked on them or external. You read it and can draw it; you do not build it here. The exam asks you to know the shape."),
  ("node break/fix", "Six new scenarios, BF-59 to BF-64, all on real nodes: the kubelet stopped or using the wrong cgroup driver, an expired or mis-pathed certificate in a kubeconfig, a manifest typo, the CNI gone, containerd stopped, etcd unreachable. Each one starts with systemctl and journalctl, not kubectl."),
  ("book the exam now", "Monday of this week, for the end of week 30. An unbooked exam slips. The package carries two simulator sessions and a free retake, so the risk of booking early is small and the cost of not booking is the whole module."),
 ],
 close="Init, static pods, certificates, CNI, join, snapshot, upgrade. Seven things kubeadm did or you did, in order, each one a file you can open. Next week fills in the objects the 2025 blueprint added; this week is the cluster they run on.",
)

F[28] = dict(
 title="Everything the 2025 blueprint added, on your own cluster",
 intro="The exam blueprint was revised in 2025 to add Kustomize, Helm, Gateway API, CRDs and operators, and dynamic provisioning. Weeks 14 to 19 touched most of it; this week does each one properly, on the kubeadm cluster, and then again from memory.",
 body='''
  KUST["① Kustomize<br/><small>base and overlays · strategic-merge and JSON patches · kubectl apply -k</small>"]:::crit
  HELM["② Helm as an install tool<br/><small>repo add · install --set · upgrade · rollback · template to read what it will do</small>"]:::crit
  GW["③ Gateway API<br/><small>GatewayClass → Gateway → HTTPRoute · host, path and header matches · a traffic split</small>"]:::crit
  DNS["④ CoreDNS<br/><small>the Corefile is a ConfigMap · a stub domain · nslookup proves it</small>"]:::n
  CRD["⑤ CRDs and an operator<br/><small>kubectl explain the CRD · create a custom resource · watch it reconcile · write your own with a schema</small>"]:::crit
  SCHED["⑥ scheduling, under exam conditions<br/><small>nodeName · nodeSelector · affinity · taints · PriorityClass · a static pod on a worker</small>"]:::crit
  JOBS["⑦ Jobs, CronJobs, DaemonSets<br/><small>completions and parallelism · backoffLimit · concurrencyPolicy · one pod per node</small>"]:::n
  STOR["⑧ dynamic provisioning<br/><small>a provisioner · the default StorageClass · reclaim policy · expand a claim</small>"]:::data
  BF["⑨ break/fix<br/><small>BF-45 and BF-46 again, plus two of the node set</small>"]:::warn
  MEM["⑩ from memory, timed<br/><small>every lab repeated with the file closed · the target time on each</small>"]:::data
  KUST ==> HELM ==> GW ==> CRD ==> SCHED ==> STOR
  GW --> DNS
  SCHED --> JOBS
  STOR -.-> BF
  BF -.-> MEM
''',
 link="linkStyle 0,1,2,3,4 stroke:#2f6fb8,stroke-width:2px",
 minutes="three",
 open="Last week was the cluster. This week is the list of objects the exam added in 2025, each one built on that cluster, each one timed. Nothing here is new to you except the Gateway split and the operator; everything else is a week-15 topic done at exam speed.",
 badges=[
  ("Kustomize", "A base directory of plain manifests and overlays that patch it: replicas and an image tag for dev, something else for prod. One strategic-merge patch and one JSON patch, so you have written both forms. kubectl apply -k; no release object, no history, no templating."),
  ("Helm as an install tool", "The exam does not ask you to author a chart. It asks you to add a repository, install a chart with a value overridden, upgrade it, roll it back, and read helm template before you apply. Four commands and the discipline of reading first."),
  ("Gateway API", "Three objects where Ingress had one, split by who owns them: the class is the implementation, the Gateway is the listener the platform runs, the HTTPRoute is the rule the application team writes. Match on host, path, and a header; split traffic between two Services by weight."),
  ("CoreDNS", "The cluster's resolver is a Deployment reading a ConfigMap called the Corefile. Add a stub domain that forwards to another server, restart nothing, and prove it with nslookup from a pod. Most DNS tasks on the exam are this ConfigMap."),
  ("CRDs and an operator", "Install a small, real operator with Helm. kubectl explain its custom resource the same way you explain a Pod. Create one and watch the operator make the underlying objects. Then write a CRD of your own with a validation schema and watch the API server reject a bad field."),
  ("scheduling, under exam conditions", "nodeName bypasses the scheduler entirely. nodeSelector and affinity ask for a node; taints refuse pods that do not tolerate them; a PriorityClass decides who is evicted. A static pod on a worker is a manifest in that worker's manifests directory, and the API server shows it with the node name appended."),
  ("Jobs, CronJobs, DaemonSets", "completions and parallelism, a backoffLimit that decides when a Job gives up, a CronJob's concurrencyPolicy and history limits, a DaemonSet that puts one pod on every node and tolerates the control plane taint if you tell it to."),
  ("dynamic provisioning", "On kubeadm nothing provisions storage until you install something. A provisioner, a StorageClass marked default, a claim that binds without naming a class, the reclaim policy on the volume, and an expansion that only works if the class allows it."),
  ("break/fix", "BF-45 and BF-46 from week 15 again, now on real nodes, plus two scenarios from the node set. Timed, narrated, journaled."),
  ("from memory, timed", "Saturday: every lab in this week repeated with the file closed, against the target time written at the end of each. The exam has no notes; this is the first week that trains that."),
 ],
 close="Kustomize, Helm, Gateway, CoreDNS, CRDs, scheduling, Jobs, storage. Eight objects, all on your cluster, all timed. Week 29 is where the speed comes from.",
)

F[29] = dict(
 title="The exam is a speed test, and this is the speed",
 intro="The knowledge is weeks 14 to 28. The exam measures how fast you can turn it into objects in a terminal you do not control, with a clock running. The blue path is the week: the terminal, the ritual, the four families of failure, a mock exam, and the first simulator session that tells you what to drill in week 30.",
 body='''
  TERM["① the exam terminal<br/><small>alias k · $do for dry-run YAML · kubectl explain · vim set for YAML</small>"]:::crit
  RIT["② the per-task ritual<br/><small>read the expected end state · use-context · verify · do · verify again</small>"]:::crit
  DOCS["③ the docs in thirty seconds<br/><small>twenty pages you can reach by search term · the only reference allowed</small>"]:::n
  FAM["④ four troubleshooting families<br/><small>application · control plane · worker node · networking</small>"]:::crit
  FIRST["⑤ the first command per family<br/><small>describe pod · crictl ps on the control plane · systemctl status kubelet · get endpoints</small>"]:::crit
  MOCK["⑥ mock exam 1<br/><small>18 tasks · weights sum to 100 · two hours · self-scored</small>"]:::crit
  KS["⑦ killer.sh session 1<br/><small>two hours cold, then the solutions · 36 hours of access · redo every miss</small>"]:::crit
  TALLY["⑧ weak-domain tally<br/><small>decides Tuesday and Thursday of week 30</small>"]:::data
  TRI["⑨ triage<br/><small>weights first · two minutes before you flag · never a zero on a cheap task</small>"]:::warn
  BF["⑩ BF-41 to BF-64, timed<br/><small>break.sh on the kubeadm cluster · under ten minutes each</small>"]:::n
  TERM ==> RIT ==> FAM ==> FIRST ==> MOCK ==> KS ==> TALLY
  RIT --> DOCS
  MOCK -.-> TRI
  FAM -.-> BF
''',
 link="linkStyle 0,1,2,3,4,5 stroke:#2f6fb8,stroke-width:2px",
 minutes="three and a half",
 open="You know Kubernetes. The question this week answers is whether you can prove it in two hours, in a remote desktop, with the docs as your only reference and a context switch at the top of every task. Speed is a skill, and it is trained the same way the diagnostic loop was: timed, repeated, logged.",
 badges=[
  ("the exam terminal", "An alias for kubectl, a shell variable holding the dry-run flags so YAML comes out of one short command, kubectl explain for any field you have forgotten, and a vim that indents YAML with two spaces. Set these up in the first minute of the exam; they pay for themselves on the second task."),
  ("the per-task ritual", "Read the task to the end and name the end state before touching anything. Switch to the context the task names, and verify you did. Do the task. Verify the end state, with a command, not a feeling. The ritual is what stops a correct answer landing in the wrong cluster."),
  ("the docs in thirty seconds", "The Kubernetes documentation is allowed and it is the only thing that is. Twenty pages you can reach by a search term you already know: PersistentVolume, NetworkPolicy, Ingress, CronJob, kubeadm upgrade, etcd backup. Finding a page is a scored skill in practice."),
  ("four troubleshooting families", "The exam's largest domain, and every task in it is one of four: the application is wrong, the control plane is wrong, the worker node is wrong, or the network between them is wrong. Classifying first is what makes the next badge possible."),
  ("the first command per family", "describe pod for the application. crictl ps and the static-pod logs on the control plane, because kubectl is the thing that is down. systemctl status kubelet and journalctl on a worker. get endpoints and a NetworkPolicy list for the network. One command each, and it halves the problem."),
  ("mock exam 1", "Eighteen tasks with weights that sum to a hundred, spread like the blueprint, two hours, no notes. Score it honestly against the sheet. It is harder than you want it to be and that is the point."),
  ("killer.sh session 1", "The simulator that ships with the exam, harder than the exam. Two hours cold, then the rest of the thirty-six-hour window on the solutions, redoing every task you missed until it is fast. The score matters less than the list it produces."),
  ("weak-domain tally", "Count the misses by domain across the mock and the simulator. The two worst are Tuesday and Thursday of week 30. Everything else is done."),
  ("triage", "Tasks have weights and the clock does not care. Read the weights first, take the cheap sure ones, give any task two minutes before you flag it and move on, and never leave a cheap task at zero because an expensive one ate the time."),
  ("break/fix, timed", "Every scenario from BF-41 to BF-64 run from a script on the kubeadm cluster, under ten minutes each, narrated. By Friday the four families are reflex."),
 ],
 close="Terminal, ritual, four families, one command each, a mock, a simulator, a list of what to drill. Week 30 drills the list and sits the exam.",
)

F[30] = dict(
 title="Exam week: the second simulator session is the gate",
 intro="Nothing new is learned this week. The second killer.sh session is Gate 7; two drill days close the weak domains it names; the checklist removes the avoidable ways to fail; then the exam, and the cadence continues either way.",
 body='''
  KS2["① ★ Gate 7: killer.sh session 2<br/><small>Monday · two hours · no notes · at or above the pass mark without the solutions</small>"]:::crit
  WEAK["② weak-domain sets<br/><small>Tuesday and Thursday · eight tasks in forty minutes · the two domains the tally named</small>"]:::crit
  CHK["③ the checklist<br/><small>ID · room and desk · the secure-browser check-in · what is allowed · the context ritual</small>"]:::crit
  REST["④ the day before<br/><small>no new material · a light review · sleep</small>"]:::mut
  EXAM["⑤ exam day<br/><small>use-context first · triage by weight · flag and move · the last ten minutes verify</small>"]:::crit
  RES["⑥ results<br/><small>within about a day · pass mark 66 percent</small>"]:::data
  PASS["⑦ pass<br/><small>résumé and LinkedIn the same day · CKS is a year-2 decision</small>"]:::n
  FAIL["⑧ fail<br/><small>book the free retake within two weeks · rebuild the two weakest domains with weeks 27 and 28</small>"]:::warn
  CAD["⑨ the cadence continues<br/><small>20 h interviewing · 10 h building · the cert is a line, the cluster you built is the story</small>"]:::data
  GATES["⑩ seven gates<br/><small>a stack from a fresh VM · SAA 80 % · Alpha one command · five clusters narrated · Bravo refuses · Charlie in 10 min · the simulator at the pass mark</small>"]:::data
  KS2 ==> WEAK ==> CHK ==> EXAM ==> RES
  CHK --> REST
  RES --> PASS
  RES -.-> FAIL
  FAIL -.-> WEAK
  PASS --> CAD
  GATES -.-> KS2
''',
 link="linkStyle 0,1,2,3 stroke:#2f6fb8,stroke-width:2px",
 minutes="three",
 open="This is the week the module was for. Monday's simulator session is the gate: at or above the pass mark, inside two hours, without opening a solution. Pass it and the exam is a formality with a clock; miss it and the week still runs, because the exam is booked and the retake is free.",
 badges=[
  ("Gate 7", "The second killer.sh session, Monday, run exactly like the exam: two hours, no notes, the solutions closed. The pass mark is sixty-six percent. The score is written in the progress file with the domain of every miss, and it is the last number the program records."),
  ("weak-domain sets", "Tuesday and Thursday: eight tasks in forty minutes, built for the two domains the tally named. Nothing else is drilled. A domain you are already fast in does not get faster in two days."),
  ("the checklist", "A government ID that matches the registration name, a clear desk and a room you can show on camera, the secure browser installed and tested the day before, nothing on the desk but what is allowed, and the context ritual written on nothing because you will not have paper."),
  ("the day before", "No new material; it displaces what is already loaded. A light pass over the ritual and the first commands, then sleep. Cramming the night before measurably lowers scores, and this exam is already timed against you."),
  ("exam day", "Set the aliases in the first minute. Every task: switch context, verify, read to the end, do it, verify. Take the cheap tasks first, give the rest two minutes before you flag them, and spend the last ten minutes verifying flagged work rather than starting new work."),
  ("results", "Within about a day. Either way the next badge applies, and either way you keep interviewing this week."),
  ("pass", "Update the résumé and the LinkedIn headline the same day, with a sentence about the cluster you built rather than the badge. The CKS is a year-two decision, after real operating experience; it is not next."),
  ("fail", "The package includes one free retake. Book it within two weeks while the material is loaded, and spend the gap rebuilding the two weakest domains with weeks 27 and 28, not re-reading. A fail costs a fortnight; quitting costs the module."),
  ("the cadence continues", "Twenty hours interviewing, ten building, the same loop as week 26. The certificate is a line on a page that gets past a filter; the kubeadm cluster, the etcd restore and the upgrade are the stories you tell once you are in the room."),
  ("seven gates", "A stack from a fresh VM, the SAA at eighty percent, Alpha in one command, five broken clusters narrated, Bravo refusing a CVE and an unsigned image, Charlie in ten minutes, and the simulator at the pass mark. Seven proofs; the seventh is the one hiring managers filter on."),
 ],
 close="Gate, drills, checklist, rest, exam, result. Then back to the cadence that converts. The program ended at week 26; the module ends here; neither one was the finish line.",
)
