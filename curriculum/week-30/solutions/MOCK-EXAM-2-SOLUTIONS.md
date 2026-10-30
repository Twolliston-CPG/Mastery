# Mock Exam 2 — solutions

> Setup per set: [`mock-exam-2-setup.sh`](mock-exam-2-setup.sh) `A`, `B` or `C`. Score each set out
> of eight: a task scores only when its end state holds exactly. Log the time of every run; the
> third run's time is the number that matters.

## Set A — Troubleshooting

**A1.** `describe pod` on the crashing one: `Liveness probe failed: HTTP probe failed with statuscode: 404`, path `/nope`. The image is fine; the probe kills a healthy container. Remove it:
```bash
kubectl -n shop patch deploy web --type=json -p '[{"op":"remove","path":"/spec/template/spec/containers/0/livenessProbe"}]'
kubectl -n shop rollout status deploy/web
```
(BF-44's shape; the clause "without changing the image" is there to stop a `rollout undo`, which would also remove the probe and also score.)

**A2.** `get endpoints web` lists IPs on port 8080; nginx listens on 80. The endpoints exist, so it is not the selector; it is the port. Figure 14.3, badge ⑪.
```bash
kubectl -n shop patch svc web -p '{"spec":{"ports":[{"port":80,"targetPort":80}]}}'
```

**A3.** `describe node k8s-w1`: `Ready False`, message `container runtime network not ready: cni config uninitialized`. The kubelet is up; the CNI config is gone.
```bash
ssh k8s-w1 'sudo mv /root/cni-backup/10-calico.conflist /etc/cni/net.d/'
# or: kubectl -n kube-system delete pod -l k8s-app=calico-node --field-selector spec.nodeName=k8s-w1
#     (calico-node's install-cni init container writes the file again)
kubectl get node k8s-w1 -w
```
BF-62.

**A4.** `kubectl run` says `Internal error occurred: failed calling webhook "block.mock.example.com"`. The webhook names itself.
```bash
kubectl get validatingwebhookconfigurations
kubectl delete validatingwebhookconfiguration mock-block-pods
echo mock-block-pods > /opt/answers/a4.txt
```
The exam's version of this task is sometimes a webhook whose backing service was deleted; the fix is the same, and `failurePolicy: Fail` is why the whole cluster feels broken. Week 19 Lab 2.

**A5.** `kubectl -n kube-system get pods`: the controller-manager static pod is missing or crashing; `crictl ps -a` on `k8s-cp` shows it exiting; `crictl logs` says `executable file not found`.
```bash
sudo sed -i 's/kube-controller-managerr/kube-controller-manager/' /etc/kubernetes/manifests/kube-controller-manager.yaml
echo /etc/kubernetes/manifests/kube-controller-manager.yaml > /opt/answers/a5.txt
kubectl create deploy probe2 --image=nginx:1.27 && kubectl get rs -l app=probe2
```

**A6.** `kubectl -n kube-system get deploy coredns` shows `0/0`. Nothing answers on the cluster DNS IP, so even cluster names fail (the task's tell: A6 fails everything, Mock Exam 1's Task 5 failed only external names).
```bash
kubectl -n kube-system scale deploy coredns --replicas=2
```

**A7.** `kubectl get nodes` shows `Ready,SchedulingDisabled`; `describe node` shows `Unschedulable: true` and the taint `node.kubernetes.io/unschedulable:NoSchedule`, which `cordon` adds and nobody "added".
```bash
kubectl uncordon k8s-w2
```

**A8.** `kubectl -n shop get role pod-reader -o yaml`: resources `[pods]` only. Logs are the `pods/log` sub-resource.
```bash
kubectl -n shop patch role pod-reader --type=json -p '[{"op":"replace","path":"/rules/0/resources","value":["pods","pods/log"]}]'
kubectl auth can-i get pods/log --as=system:serviceaccount:shop:deployer -n shop
```
BF-48.

## Set B — Cluster architecture and storage

**B1.**
```bash
export ETCDCTL_API=3
etcdctl --endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save /opt/answers/b1.db
etcdutl snapshot status /opt/answers/b1.db -w table        # columns: hash, revision, total keys, total size
etcdutl snapshot status /opt/answers/b1.db -w json | sed 's/.*"totalKey":\([0-9]*\).*/\1/' > /opt/answers/b1.txt
```

**B2.**
```bash
sudo kubeadm certs check-expiration | tee /opt/answers/b2.txt
sudo kubeadm certs renew apiserver
# the API server reads its cert at start; restart the static pod by moving the manifest out and back
sudo mv /etc/kubernetes/manifests/kube-apiserver.yaml /tmp/ && sleep 20 && sudo mv /tmp/kube-apiserver.yaml /etc/kubernetes/manifests/
kubectl get --raw /readyz
sudo kubeadm certs check-expiration | grep apiserver
```
Week 27 Lab 2; BF-60 is the expired version of this.

**B3.**
```bash
kubectl -n shop get deploy web -w > /opt/answers/b3.txt 2>&1 &
kubectl drain k8s-w2 --ignore-daemonsets --delete-emptydir-data
# the eviction API honours web-pdb: pods on k8s-w2 leave one at a time, each after a replacement is Ready elsewhere
kubectl uncordon k8s-w2
kill %1
```
If the drain hangs, two `web` pods are on `k8s-w2` and the replacements cannot schedule; that is the PDB doing its job, and the answer is to wait for the first replacement, not `--disable-eviction`. Week 15 Lab 2.

**B4.**
```bash
cat > /opt/answers/b4.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
V=1.X.Y-1.1            # the next patch, from: apt-cache madison kubeadm
sudo apt-mark unhold kubeadm
sudo apt-get update && sudo apt-get install -y "kubeadm=$V"
sudo apt-mark hold kubeadm
sudo kubeadm upgrade plan
sudo kubeadm upgrade apply "v${V%-*}"
kubectl drain k8s-cp --ignore-daemonsets
sudo apt-mark unhold kubelet kubectl
sudo apt-get install -y "kubelet=$V" "kubectl=$V"
sudo apt-mark hold kubelet kubectl
sudo systemctl daemon-reload && sudo systemctl restart kubelet
kubectl uncordon k8s-cp
EOF
bash -n /opt/answers/b4.sh
```
Control plane first, `upgrade apply` on the first control-plane node (`upgrade node` on the others and on workers), kubelet after kubeadm, uncordon last. Week 27 Lab 4.

**B5.**
```bash
kubectl create clusterrole node-viewer --verb=get,list,watch --resource=nodes
kubectl -n shop create rolebinding deployer-nodes --clusterrole=node-viewer --serviceaccount=shop:deployer
kubectl auth can-i list nodes --as=system:serviceaccount:shop:deployer > /opt/answers/b5.txt
echo "no: a RoleBinding grants only inside its namespace, and nodes are cluster-scoped, so the grant applies to nothing; a ClusterRoleBinding is needed" >> /opt/answers/b5.txt
```
The bottom-left cell of week 15's four-way matrix.

**B6.**
```bash
kubectl get pv pv-orphan -o jsonpath='{.spec.claimRef.name}{"\n"}'   # the deleted claim
kubectl patch pv pv-orphan -p '{"spec":{"claimRef":null}}'            # Released -> Available
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata: { name: reuse, namespace: data }
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: manual
  resources: { requests: { storage: 500Mi } }
EOF
kubectl get pv pv-orphan
```
`Retain` keeps the data and the PV; it is the stale `claimRef` that blocks rebinding. Week 15 Lab 3.

**B7.**
```bash
kubectl apply -f - <<'EOF'
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast
  annotations: { storageclass.kubernetes.io/is-default-class: "true" }
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: Immediate
EOF
kubectl -n data create -f - <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata: { name: auto }
spec: { accessModes: [ReadWriteOnce], resources: { requests: { storage: 100Mi } } }
EOF
kubectl -n data get pvc auto -o jsonpath='{.spec.storageClassName}{"\n"}'    # fast, stamped by the admission plugin
```

**B8.**
```bash
ssh k8s-w1 'sudo grep -E "^cgroupDriver|^containerRuntimeEndpoint" /var/lib/kubelet/config.yaml; sudo cat /var/lib/kubelet/kubeadm-flags.env'
# typical: cgroupDriver: systemd · unix:///var/run/containerd/containerd.sock
printf 'systemd\nunix:///var/run/containerd/containerd.sock\n' > /opt/answers/b8.txt   # with the values you actually read
```
BF-59's second variant is a cgroup-driver mismatch between kubelet and containerd; this is where you read both.

## Set C — Services, networking and workloads

**C1.**
```bash
kubectl -n shop apply -f - <<'EOF'
apiVersion: v1
kind: Service
metadata: { name: api-headless }
spec: { clusterIP: None, selector: { app: api }, ports: [{ port: 8080 }] }
EOF
kubectl -n shop exec deploy/web -- nslookup api-headless | awk '/^Address/ && !/#53/ {print $2}' > /opt/answers/c1.txt
```

**C2.**
```bash
kubectl -n shop create ingress shop --class=nginx --rule='shop.local/web*=web:80' --rule='shop.local/api*=api:8080'
```

**C3.**
```bash
openssl req -x509 -newkey rsa:2048 -nodes -keyout tls.key -out tls.crt -days 30 -subj '/CN=apps.local'
kubectl -n apps create secret tls edge-tls --cert=tls.crt --key=tls.key
kubectl -n apps apply -f - <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata: { name: edge }
spec:
  gatewayClassName: mock-gw
  listeners:
    - name: https
      protocol: HTTPS
      port: 443
      hostname: apps.local
      tls: { mode: Terminate, certificateRefs: [{ name: edge-tls }] }
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata: { name: hello-tls }
spec:
  parentRefs: [{ name: edge }]
  hostnames: [apps.local]
  rules: [{ backendRefs: [{ name: hello, port: 80 }] }]
EOF
```

**C4.**
```bash
kubectl -n shop apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: db-from-api }
spec:
  podSelector: { matchLabels: { app: db } }
  policyTypes: [Ingress]
  ingress:
    - from: [{ podSelector: { matchLabels: { app: api } } }]
      ports: [{ protocol: TCP, port: 5432 }]
EOF
kubectl -n shop exec deploy/api -- nc -zv -w2 db 5432     # busybox nc is in nginx-unprivileged? no: use `wget -qO- --timeout=2 db:5432` and read the error
```
Selecting `db` with an ingress rule makes everything not listed denied for `db`; `web` is not listed. If `shop` still carries week 29's `deny-all` plus the egress rules, `api` also needs egress to `db:5432`.

**C5.**
```bash
kubectl -n shop patch deploy web -p '{"spec":{"strategy":{"rollingUpdate":{"maxSurge":0,"maxUnavailable":1}}}}'
kubectl -n shop set image deploy/web web=nginx:1.27-alpine && kubectl -n shop rollout pause deploy/web
kubectl -n shop get rs            # one new pod, then nothing
kubectl -n shop rollout resume deploy/web && kubectl -n shop rollout status deploy/web
```

**C6.**
```bash
kubectl -n apps create job batch --image=busybox:1.36 $do -- echo done > job.yaml
# add under spec: completions: 5 / parallelism: 2 / backoffLimit: 1
kubectl -n apps apply -f job.yaml && kubectl -n apps wait job/batch --for=condition=complete --timeout=120s
```

**C7.**
```bash
kubectl -n apps create deploy node-agent --image=busybox:1.36 $do -- sleep 3600 > ds.yaml
# edit: kind: DaemonSet, delete replicas and strategy, add the control-plane toleration:
#   tolerations: [{ key: node-role.kubernetes.io/control-plane, operator: Exists, effect: NoSchedule }]
kubectl -n apps apply -f ds.yaml && kubectl -n apps get ds node-agent
```
There is no `kubectl create daemonset`; a Deployment manifest with the kind changed is the fast path.

**C8.**
```bash
mkdir -p /opt/mock/kustomize/overlays/prod
cat > /opt/mock/kustomize/overlays/prod/kustomization.yaml <<'EOF'
resources:
  - ../../base
namespace: apps
labels:
  - pairs: { env: prod }
    includeSelectors: false
replicas:
  - name: kz
    count: 3
EOF
kubectl apply -k /opt/mock/kustomize/overlays/prod
kubectl -n apps get deploy kz -o jsonpath='{.spec.replicas}/{.metadata.labels.env}{"\n"}'
```
`labels` with `includeSelectors: false` adds the label without touching the selector; the older `commonLabels` would also rewrite the selector, which is immutable on an existing Deployment. Week 28 Lab 1.
