# Mock Exam 1 — solutions and scoring sheet

> Setup: [`mock-exam-1-setup.sh`](mock-exam-1-setup.sh), run on `k8s-cp` as root by someone who is
> not the candidate. Scoring: run the **verify** command for each task; award the full weight only
> when it passes exactly, otherwise zero (the real exam awards partial credit per check; this sheet
> is stricter on purpose).

| # | Weight | Verify (run as admin on k8s-cp) | Score |
|---|---|---|---|
| 1 | 8 | `kubectl get node k8s-w2 \| grep -w Ready && ssh k8s-w2 systemctl is-enabled kubelet \| grep -x enabled` | |
| 2 | 5 | `kubectl -n shop get deploy web -o jsonpath='{.status.readyReplicas}' \| grep -x 3` | |
| 3 | 5 | `[ "$(kubectl -n shop get endpoints api -o jsonpath='{.subsets[0].addresses[*].ip}' \| wc -w)" = 2 ] && grep -qx "$(kubectl -n shop get svc api -o jsonpath='{.spec.clusterIP}')" /opt/answers/task3.txt` | |
| 4 | 7 | `kubectl -n kube-system get pod kube-scheduler-k8s-cp -o jsonpath='{.status.phase}' \| grep -x Running && grep -q kube-scheduler.yaml /opt/answers/task4.txt` | |
| 5 | 5 | `kubectl -n shop exec deploy/web -- nslookup kubernetes.io >/dev/null` | |
| 6 | 8 | `etcdutl snapshot status /opt/answers/etcd-snapshot.db >/dev/null && kubectl get ns restored-ns >/dev/null && [ "$(kubectl -n kube-system get pods -l tier=control-plane --field-selector status.phase!=Running --no-headers \| wc -l)" = 0 ]` | |
| 7 | 4 | `grep -qx yes /opt/answers/task7.txt && kubectl auth can-i delete secrets --as=system:serviceaccount:shop:auditor -n shop \| grep -x no` | |
| 8 | 7 | `[ "$(kubectl get nodes -o jsonpath='{.items[*].status.nodeInfo.kubeletVersion}' \| tr ' ' '\n' \| sort -u \| wc -l)" = 1 ] && kubectl get node k8s-w1 -o jsonpath='{.spec.unschedulable}' \| grep -vq true` | |
| 9 | 6 | `helm -n apps status hello -o json \| grep -q '"status":"deployed"' && [ "$(kubectl -n apps get deploy hello -o jsonpath='{.status.readyReplicas}')" = 2 ] && diff <(kubectl get crd -o name \| grep projectcalico.org \| sed 's#.*/##' \| sort) <(sort /opt/answers/task9.txt)` | |
| 10 | 6 | `kubectl -n shop exec deploy/web -- wget -qO- --timeout=3 api:8080 >/dev/null && ! kubectl -n shop exec deploy/web -- wget -qO- --timeout=3 db:5432 >/dev/null 2>&1 && kubectl -n shop get netpol deny-all >/dev/null` | |
| 11 | 6 | `[ "$(kubectl -n apps get gateway apps-gw -o jsonpath='{.spec.gatewayClassName}/{.spec.listeners[0].port}/{.spec.listeners[0].protocol}')" = mock-gw/80/HTTP ] && kubectl -n apps get httproute hello -o jsonpath='{.spec.parentRefs[0].name}/{.spec.hostnames[0]}/{.spec.rules[0].backendRefs[0].name}' \| grep -x apps-gw/hello.local/hello` | |
| 12 | 4 | `curl -s "http://$(kubectl get node k8s-w1 -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}'):30080" \| grep -q nginx` | |
| 13 | 4 | `kubectl -n apps get ingress hello -o jsonpath='{.spec.ingressClassName}/{.spec.rules[0].host}/{.spec.rules[0].http.paths[0].backend.service.name}' \| grep -x nginx/hello.local/hello` | |
| 14 | 5 | `kubectl -n shop rollout history deploy web \| grep -q alpine && kubectl -n shop get deploy web -o jsonpath='{.spec.template.spec.containers[0].image}' \| grep -vq 1.27-alpine && [ "$(kubectl -n shop get deploy web -o jsonpath='{.spec.strategy.rollingUpdate.maxUnavailable}')" = 0 ]` | |
| 15 | 4 | `[ "$(kubectl -n apps get cj report -o jsonpath='{.spec.schedule}/{.spec.concurrencyPolicy}/{.spec.successfulJobsHistoryLimit}/{.spec.failedJobsHistoryLimit}')" = '*/10 * * * */Forbid/3/1' ]` | |
| 16 | 6 | `[ "$(kubectl -n apps get pod logger -o jsonpath='{.spec.nodeName}/{.status.phase}')" = k8s-cp/Running ] && kubectl -n apps logs logger -c shipper \| grep -q 20` | |
| 17 | 6 | `[ "$(kubectl -n data get pvc pvc-mock -o jsonpath='{.status.phase}/{.spec.volumeName}')" = Bound/pv-mock ] && ssh "$(kubectl -n data get pod writer -o jsonpath='{.spec.nodeName}')" cat /mnt/mock/hello.txt \| grep -x hello` | |
| 18 | 4 | `[ "$(kubectl get sc slow -o jsonpath='{.volumeBindingMode}')" = WaitForFirstConsumer ] && [ "$(kubectl -n data get pvc slow-claim -o jsonpath='{.status.phase}')" = Pending ] && grep -qi consumer /opt/answers/task18.txt` | |
| | **100** | | **total** |

Task 17's verify runs `cat` on the pod's node; when the pod landed on `k8s-cp`, drop the `ssh`.

---

## Task 1 — kubelet on k8s-w2 (Troubleshooting, 8)

```bash
kubectl config use-context mock-a
kubectl describe node k8s-w2 | sed -n '/Conditions/,/Addresses/p'    # Ready Unknown, "Kubelet stopped posting"
ssh k8s-w2
sudo systemctl status kubelet          # inactive (dead), and "disabled" in the Loaded line
sudo systemctl enable --now kubelet    # both halves of the task in one command
systemctl is-enabled kubelet           # enabled
exit
kubectl get nodes -w                   # k8s-w2 Ready within ~40 s
```

The clause "survive a reboot" is `enable`. `start` alone scores the first check and fails the
second. BF-59.

## Task 2 — web rollout (Troubleshooting, 5)

```bash
kubectl -n shop get pods -l app=web            # new ReplicaSet's pod in ImagePullBackOff
kubectl -n shop describe pod <pod> | tail -5   # manifest unknown: the tag does not exist
kubectl -n shop rollout undo deploy/web        # or: set image deploy/web web=nginx:1.27
kubectl -n shop rollout status deploy/web
```

`rollout undo` is the fastest correct answer; the old ReplicaSet is still there at scale 2. BF-41.

## Task 3 — api endpoints (Troubleshooting, 5)

```bash
kubectl -n shop get endpoints api                      # <none>: a selector problem (figure 14.3, badge ⑪)
kubectl -n shop get pods -l app=api --show-labels      # pods carry app=api
kubectl -n shop get svc api -o jsonpath='{.spec.selector}'   # {"app":"api-v2"}
kubectl -n shop patch svc api -p '{"spec":{"selector":{"app":"api"}}}'
kubectl -n shop get endpoints api                      # two IPs
kubectl -n shop get svc api -o jsonpath='{.spec.clusterIP}{"\n"}' > /opt/answers/task3.txt
```

## Task 4 — the scheduler (Troubleshooting, 7)

```bash
kubectl run probe --image=busybox:1.36 -- sleep 60
kubectl describe pod probe | tail -3             # Events: <none>  -> nothing even tried to schedule it
kubectl -n kube-system get pods | grep scheduler # kube-scheduler-k8s-cp CrashLoopBackOff or missing
sudo crictl ps -a | grep scheduler               # exited; crictl logs <id> shows "executable file not found"
sudo vi /etc/kubernetes/manifests/kube-scheduler.yaml   # command: - kube-schedulerr  -> kube-scheduler
# the kubelet notices the file change within seconds and recreates the static pod
kubectl -n kube-system get pod kube-scheduler-k8s-cp -w
echo /etc/kubernetes/manifests/kube-scheduler.yaml > /opt/answers/task4.txt
```

"Pending with no event" is the signature of a scheduler that is not running: every other Pending
cause writes a `FailedScheduling` event. BF-61's family.

## Task 5 — CoreDNS (Troubleshooting, 5)

```bash
kubectl -n shop exec deploy/web -- nslookup kubernetes.io       # SERVFAIL or timeout
kubectl -n shop exec deploy/web -- nslookup api                 # works: the cluster zone is fine
kubectl -n kube-system get cm coredns -o yaml | grep forward    # forward . 10.255.255.1
kubectl -n kube-system edit cm coredns                           # forward . /etc/resolv.conf
kubectl -n kube-system rollout restart deploy coredns
kubectl -n shop exec deploy/web -- nslookup kubernetes.io
```

Cluster names resolving while external names fail splits the problem: CoreDNS is alive, the
upstream it forwards to is wrong. BF-62's family.

## Task 6 — etcd snapshot and restore (Cluster Architecture, 8)

```bash
export ETCDCTL_API=3
C="--endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt \
   --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key"
etcdctl $C snapshot save /opt/answers/etcd-snapshot.db
etcdutl snapshot status /opt/answers/etcd-snapshot.db

# restore into a NEW data dir, then point the static pod at it
etcdutl snapshot restore /opt/mock/etcd-before.db --data-dir /var/lib/etcd-restored
sudo vi /etc/kubernetes/manifests/etcd.yaml
#   volumes: -> hostPath: path: /var/lib/etcd  ==>  /var/lib/etcd-restored   (the etcd-data volume)
# the kubelet restarts etcd on the new dir; the API server reconnects on its own
watch kubectl get ns restored-ns
kubectl -n kube-system get pods
```

The three cert flags come from the etcd static-pod manifest (`grep -- --cert /etc/kubernetes/manifests/etcd.yaml`),
which is faster than remembering them. Restore never overwrites the live data dir; it writes a new
one and you swap the mount. Week 27 Lab 3.

## Task 7 — RBAC (Cluster Architecture, 4)

```bash
kubectl -n shop create sa auditor
kubectl -n shop create role secret-lister --verb=get,list --resource=secrets
kubectl -n shop create rolebinding auditor-secrets --role=secret-lister --serviceaccount=shop:auditor
kubectl auth can-i list secrets --as=system:serviceaccount:shop:auditor -n shop > /opt/answers/task7.txt
kubectl auth can-i delete secrets --as=system:serviceaccount:shop:auditor -n shop    # no
```

## Task 8 — worker upgrade (Cluster Architecture, 7)

```bash
kubectl get nodes                              # k8s-w1 one patch behind
kubectl drain k8s-w1 --ignore-daemonsets --delete-emptydir-data
ssh k8s-w1
V="$(kubectl version 2>/dev/null | sed -n 's/Server Version: v//p' || true)"   # or read it off `kubectl get nodes` on cp
sudo apt-mark unhold kubeadm kubelet
sudo apt-get install -y "kubeadm=${V}-1.1" "kubelet=${V}-1.1"       # the -1.1 suffix is the pkgs.k8s.io revision; check apt-cache madison
sudo apt-mark hold kubeadm kubelet
sudo kubeadm upgrade node
sudo systemctl daemon-reload && sudo systemctl restart kubelet
exit
kubectl uncordon k8s-w1
kubectl get nodes                              # versions match, k8s-w1 Ready
```

Order is the task: drain, kubeadm, `kubeadm upgrade node`, kubelet, restart, uncordon. The docs
page `upgrading kubeadm clusters` has it verbatim; week 27 Lab 4 is the full version.

## Task 9 — Helm and CRDs (Cluster Architecture, 6)

```bash
kubectl config use-context mock-c
kubectl create ns apps
helm install hello /opt/mock/charts/hello -n apps -f /opt/mock/charts/hello-values.yaml --set replicaCount=2
helm -n apps status hello
kubectl get crd -o name | grep projectcalico.org | sed 's#.*/##' > /opt/answers/task9.txt
```

`--set` after `-f` wins; that is the override. `kubectl get crd` lists names as `plural.group`, so
the grep on the group suffix is the whole filter.

## Task 10 — NetworkPolicy (Services and Networking, 6)

```bash
kubectl config use-context mock-a
kubectl -n shop apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: allow-dns }
spec:
  podSelector: {}
  policyTypes: [Egress]
  egress:
    - to:
        - namespaceSelector: { matchLabels: { kubernetes.io/metadata.name: kube-system } }
          podSelector: { matchLabels: { k8s-app: kube-dns } }
      ports: [{ protocol: UDP, port: 53 }, { protocol: TCP, port: 53 }]
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: web-to-api }
spec:
  podSelector: { matchLabels: { app: api } }
  policyTypes: [Ingress]
  ingress:
    - from: [{ podSelector: { matchLabels: { app: web } } }]
      ports: [{ protocol: TCP, port: 8080 }]
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: web-egress-api }
spec:
  podSelector: { matchLabels: { app: web } }
  policyTypes: [Egress]
  egress:
    - to: [{ podSelector: { matchLabels: { app: api } } }]
      ports: [{ protocol: TCP, port: 8080 }]
EOF
kubectl -n shop exec deploy/web -- wget -qO- api:8080 | head -1
kubectl -n shop exec deploy/web -- wget -qO- --timeout=3 db:5432   # fails: nothing allows it
```

Policies are additive allow-lists over a deny; `deny-all` sets both directions, so the flow needs
an egress rule on `web` and an ingress rule on `api`, plus DNS egress for everyone. Week 19 Lab 3,
BF-54.

## Task 11 — Gateway API (Services and Networking, 6)

```bash
kubectl config use-context mock-c
kubectl -n apps apply -f - <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata: { name: apps-gw }
spec:
  gatewayClassName: mock-gw
  listeners: [{ name: http, protocol: HTTP, port: 80 }]
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata: { name: hello }
spec:
  parentRefs: [{ name: apps-gw }]
  hostnames: [hello.local]
  rules:
    - matches: [{ path: { type: PathPrefix, value: / } }]
      backendRefs: [{ name: hello, port: 80 }]
EOF
```

The mock's class has no controller, so `PROGRAMMED` stays `Unknown`; on week 28's cluster with a
real controller it goes `True` within seconds. The spec is what is scored here.

## Task 12 — NodePort (Services and Networking, 4)

```bash
kubectl config use-context mock-a
kubectl -n shop create svc nodeport web-np --tcp=80:80 --node-port=30080 --dry-run=client -o yaml > np.yaml
# edit: spec.selector -> app: web   (create svc nodeport sets selector app=web-np)
kubectl -n shop apply -f np.yaml
curl -s http://<node-ip>:30080 | head -3
```

`kubectl expose deploy web --type=NodePort --name=web-np --port=80` is shorter but cannot set the
node port; the generator plus one edit can.

## Task 13 — Ingress (Services and Networking, 4)

```bash
kubectl -n apps create ingress hello --class=nginx --rule='hello.local/*=hello:80'
```

## Task 14 — rollout and rollback (Workloads and Scheduling, 5)

```bash
kubectl config use-context mock-a
kubectl -n shop patch deploy web -p '{"spec":{"strategy":{"rollingUpdate":{"maxUnavailable":0,"maxSurge":1}}}}'
kubectl -n shop set image deploy/web web=nginx:1.27-alpine
kubectl -n shop annotate deploy web kubernetes.io/change-cause="alpine"
kubectl -n shop rollout status deploy/web
kubectl -n shop rollout undo deploy/web
kubectl -n shop rollout history deploy/web
```

## Task 15 — CronJob (Workloads and Scheduling, 4)

```bash
kubectl -n apps create cj report --image=busybox:1.36 --schedule='*/10 * * * *' $do -- date > cj.yaml
# add under spec:  concurrencyPolicy: Forbid / successfulJobsHistoryLimit: 3 / failedJobsHistoryLimit: 1
kubectl -n apps apply -f cj.yaml
```

## Task 16 — two containers, a selector, a toleration (Workloads and Scheduling, 6)

```bash
kubectl -n apps apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata: { name: logger }
spec:
  nodeSelector: { tier: apps }
  tolerations:
    - { key: node-role.kubernetes.io/control-plane, operator: Exists, effect: NoSchedule }
  volumes: [{ name: log, emptyDir: {} }]
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "while true; do date >> /var/log/app/out.log; sleep 5; done"]
      volumeMounts: [{ name: log, mountPath: /var/log/app }]
    - name: shipper
      image: busybox:1.36
      command: ["sh", "-c", "touch /var/log/app/out.log; tail -f /var/log/app/out.log"]
      volumeMounts: [{ name: log, mountPath: /var/log/app }]
EOF
kubectl -n apps get pod logger -o wide
kubectl -n apps logs logger -c shipper
```

The only node labelled `tier=apps` is the control plane, and the control plane carries a
`NoSchedule` taint; the task never says so, the cluster does. Read the labels before writing.

## Task 17 — PV, PVC, pod (Storage, 6)

```bash
kubectl config use-context mock-b
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolume
metadata: { name: pv-mock }
spec:
  capacity: { storage: 1Gi }
  accessModes: [ReadWriteOnce]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath: { path: /mnt/mock }
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata: { name: pvc-mock, namespace: data }
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: manual
  resources: { requests: { storage: 1Gi } }
---
apiVersion: v1
kind: Pod
metadata: { name: writer, namespace: data }
spec:
  volumes: [{ name: d, persistentVolumeClaim: { claimName: pvc-mock } }]
  containers:
    - name: w
      image: busybox:1.36
      command: ["sh", "-c", "echo hello > /data/hello.txt; sleep 3600"]
      volumeMounts: [{ name: d, mountPath: /data }]
EOF
kubectl -n data get pvc pvc-mock
```

The PVC's `storageClassName: manual` must match the PV's; leave it off and the default class claims
it (or nothing does). Week 15 Lab 3.

## Task 18 — WaitForFirstConsumer (Storage, 4)

```bash
kubectl apply -f - <<'EOF'
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata: { name: slow }
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata: { name: slow-claim, namespace: data }
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: slow
  resources: { requests: { storage: 500Mi } }
EOF
echo "WaitForFirstConsumer delays binding until a pod using the claim is scheduled; a pod mounting slow-claim (and a matching PV, since the provisioner creates nothing) would bind it." > /opt/answers/task18.txt
```

---

## After scoring

Tally the misses by cause, not by task: wrong context · wrong namespace · wrong field · skipped
verification · out of time · did not know. The cause decides the fix. "Did not know" sends you to
the week that taught it; "out of time" sends you to the triage drill; the other four send you to
the ritual.
