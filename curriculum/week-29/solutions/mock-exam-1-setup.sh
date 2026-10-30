#!/usr/bin/env bash
# Mock Exam 1 setup. Run on k8s-cp as root, with /etc/kubernetes/admin.conf as the kubeconfig.
# Someone other than the candidate runs this: it plants the broken states the tasks describe.
#
# Assumes the week-27 kubeadm cluster: k8s-cp, k8s-w1, k8s-w2, Calico, helm on k8s-cp, and
# passwordless ssh from k8s-cp to the workers (set up in week 27 Lab 1).
set -euo pipefail
export KUBECONFIG=/etc/kubernetes/admin.conf

say() { printf '==> %s\n' "$*"; }

# --- contexts: one cluster, three names, three default namespaces ------------------------
say "contexts"
kubectl config set-context mock-a --cluster=kubernetes --user=kubernetes-admin --namespace=shop >/dev/null
kubectl config set-context mock-b --cluster=kubernetes --user=kubernetes-admin --namespace=default >/dev/null
kubectl config set-context mock-c --cluster=kubernetes --user=kubernetes-admin --namespace=apps >/dev/null
kubectl config use-context mock-a >/dev/null
mkdir -p /opt/answers /opt/mock/charts
rm -f /opt/answers/*

# --- namespaces and the shop stack ---------------------------------------------------------
say "namespaces and workloads"
for ns in shop data restored-ns; do
  kubectl get ns "$ns" >/dev/null 2>&1 || kubectl create ns "$ns" >/dev/null
done
kubectl delete ns apps --ignore-not-found --wait=true >/dev/null   # task 9 asks the candidate to create it

kubectl -n shop apply -f - <<'EOF' >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata: { name: web, labels: { app: web } }
spec:
  replicas: 3
  selector: { matchLabels: { app: web } }
  template:
    metadata: { labels: { app: web } }
    spec:
      containers:
        - { name: web, image: nginx:1.27, ports: [{ containerPort: 80 }] }
---
apiVersion: v1
kind: Service
metadata: { name: web }
spec: { selector: { app: web }, ports: [{ port: 80, targetPort: 80 }] }
---
apiVersion: apps/v1
kind: Deployment
metadata: { name: api, labels: { app: api } }
spec:
  replicas: 2
  selector: { matchLabels: { app: api } }
  template:
    metadata: { labels: { app: api } }
    spec:
      containers:
        - { name: api, image: nginxinc/nginx-unprivileged:1.27, ports: [{ containerPort: 8080 }] }
---
apiVersion: v1
kind: Service
metadata: { name: api }
spec: { selector: { app: api }, ports: [{ port: 8080, targetPort: 8080 }] }
---
apiVersion: apps/v1
kind: Deployment
metadata: { name: db, labels: { app: db } }
spec:
  replicas: 1
  selector: { matchLabels: { app: db } }
  template:
    metadata: { labels: { app: db } }
    spec:
      containers:
        - name: db
          image: busybox:1.36
          command: ["sh", "-c", "while true; do echo ok | nc -l -p 5432; done"]
          ports: [{ containerPort: 5432 }]
---
apiVersion: v1
kind: Service
metadata: { name: db }
spec: { selector: { app: db }, ports: [{ port: 5432, targetPort: 5432 }] }
---
apiVersion: v1
kind: ServiceAccount
metadata: { name: deployer }
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata: { name: pod-reader }
rules: [{ apiGroups: [""], resources: [pods, pods/log], verbs: [get, list, watch] }]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: { name: deployer-reader }
subjects: [{ kind: ServiceAccount, name: deployer, namespace: shop }]
roleRef: { kind: Role, name: pod-reader, apiGroup: rbac.authorization.k8s.io }
EOF
kubectl -n shop rollout status deploy/web --timeout=180s >/dev/null
kubectl -n shop rollout status deploy/api --timeout=180s >/dev/null

# --- task 6: the "before" snapshot, with restored-ns present ------------------------------
say "etcd: install etcdctl/etcdutl matching the running etcd, take the before-snapshot"
if ! command -v etcdctl >/dev/null 2>&1; then
  tag="$(kubectl -n kube-system get pod -l component=etcd -o jsonpath='{.items[0].spec.containers[0].image}' | sed 's/.*://; s/-.*//')"
  arch="$(dpkg --print-architecture)"
  tmp="$(mktemp -d)"
  curl -fsSL "https://github.com/etcd-io/etcd/releases/download/v${tag}/etcd-v${tag}-linux-${arch}.tar.gz" | tar -xz -C "$tmp"
  install -m 0755 "$tmp"/etcd-v"${tag}"-linux-"${arch}"/etcdctl "$tmp"/etcd-v"${tag}"-linux-"${arch}"/etcdutl /usr/local/bin/
  rm -rf "$tmp"
fi
ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save /opt/mock/etcd-before.db >/dev/null
kubectl delete ns restored-ns --wait=true >/dev/null

# --- task 9: a chart and a values file ----------------------------------------------------
say "helm chart"
rm -rf /opt/mock/charts/hello
(cd /opt/mock/charts && helm create hello >/dev/null)
cat > /opt/mock/charts/hello-values.yaml <<'EOF'
image:
  repository: nginx
  tag: "1.27-alpine"
service:
  type: ClusterIP
  port: 80
EOF

# --- task 11: Gateway API CRDs and a class with no controller --------------------------------
say "gateway api"
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/latest/download/standard-install.yaml >/dev/null
kubectl apply -f - <<'EOF' >/dev/null
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata: { name: mock-gw }
spec: { controllerName: example.com/mock-controller }
EOF

# --- task 16: label the control plane -----------------------------------------------------
kubectl label node k8s-cp tier=apps --overwrite >/dev/null

# --- task 17: the hostPath directory on every node ---------------------------------------
for n in k8s-w1 k8s-w2; do ssh "$n" 'sudo mkdir -p /mnt/mock && sudo rm -f /mnt/mock/hello.txt'; done
mkdir -p /mnt/mock && rm -f /mnt/mock/hello.txt

# --- task 8: put k8s-w1 one patch behind ---------------------------------------------------
say "downgrade kubelet on k8s-w1 by one patch (skipped if only one patch exists for this minor)"
ssh k8s-w1 'sudo bash -s' <<'EOF'
set -euo pipefail
v="$(apt-cache madison kubeadm | awk "{print \$3}" | sed -n 2p || true)"
if [ -n "$v" ]; then
  apt-mark unhold kubelet kubeadm >/dev/null
  DEBIAN_FRONTEND=noninteractive apt-get install -y -q --allow-downgrades "kubelet=$v" "kubeadm=$v" >/dev/null
  apt-mark hold kubelet kubeadm >/dev/null
  systemctl restart kubelet
else
  echo "   no previous patch in the apt index; task 8 will already be satisfied"
fi
EOF

# --- the breaks ---------------------------------------------------------------------------
say "task 2: web image"
kubectl -n shop set image deploy/web web=nginx:1.27-nonexistent >/dev/null
say "task 3: api selector"
kubectl -n shop patch svc api -p '{"spec":{"selector":{"app":"api-v2"}}}' >/dev/null
say "task 10: deny-all"
kubectl -n shop apply -f - <<'EOF' >/dev/null
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: deny-all }
spec: { podSelector: {}, policyTypes: [Ingress, Egress] }
EOF
say "task 5: coredns forward"
kubectl -n kube-system get cm coredns -o yaml \
  | sed 's#forward \. /etc/resolv.conf#forward . 10.255.255.1#' \
  | kubectl apply -f - >/dev/null
kubectl -n kube-system rollout restart deploy coredns >/dev/null
say "task 1: kubelet on k8s-w2"
ssh k8s-w2 'sudo systemctl disable --now kubelet'
say "task 4: scheduler manifest"
sed -i 's/    - kube-scheduler$/    - kube-schedulerr/' /etc/kubernetes/manifests/kube-scheduler.yaml

say "done. Start the candidate's timer. Expected: 2 hours."
