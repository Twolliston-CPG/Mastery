#!/usr/bin/env bash
# Mock Exam 2 setup: `mock-exam-2-setup.sh A|B|C`. Run on k8s-cp as root by someone who is not the
# candidate. Assumes week 29's mock-exam-1-setup.sh has run once (contexts, namespaces, etcdctl,
# the Gateway API CRDs and the mock-gw class) and that the shop namespace is healthy.
set -euo pipefail
export KUBECONFIG=/etc/kubernetes/admin.conf
set_="${1:-}"
say() { printf '==> %s\n' "$*"; }
mkdir -p /opt/answers
rm -f /opt/answers/[abc][0-9].*

case "$set_" in
  A)
    say "A1: a liveness probe that can never pass, so the rollout stalls at 2/3"
    kubectl -n shop patch deploy web --type=json -p \
      '[{"op":"add","path":"/spec/template/spec/containers/0/livenessProbe","value":{"httpGet":{"path":"/nope","port":80},"initialDelaySeconds":2,"periodSeconds":3,"failureThreshold":1}}]' >/dev/null
    say "A2: service web targets a port nginx does not listen on"
    kubectl -n shop patch svc web -p '{"spec":{"ports":[{"port":80,"targetPort":8080}]}}' >/dev/null
    say "A3: k8s-w1 loses its CNI config"
    ssh k8s-w1 'sudo mkdir -p /root/cni-backup && sudo mv /etc/cni/net.d/10-calico.conflist /root/cni-backup/'
    say "A4: a validating webhook nobody answers, failurePolicy Fail"
    kubectl apply -f - <<'EOF' >/dev/null
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
metadata: { name: mock-block-pods }
webhooks:
  - name: block.mock.example.com
    admissionReviewVersions: [v1]
    sideEffects: None
    failurePolicy: Fail
    timeoutSeconds: 5
    clientConfig:
      service: { name: nonexistent, namespace: default, path: /validate }
    rules:
      - apiGroups: [""]
        apiVersions: [v1]
        resources: [pods]
        operations: [CREATE]
EOF
    say "A5: controller-manager manifest typo"
    sed -i 's/    - kube-controller-manager$/    - kube-controller-managerr/' /etc/kubernetes/manifests/kube-controller-manager.yaml
    say "A6: no CoreDNS replicas"
    kubectl -n kube-system scale deploy coredns --replicas=0 >/dev/null
    say "A7: k8s-w2 cordoned"
    kubectl cordon k8s-w2 >/dev/null
    say "A8: pod-reader loses pods/log"
    kubectl -n shop patch role pod-reader --type=json -p '[{"op":"replace","path":"/rules/0/resources","value":["pods"]}]' >/dev/null
    ;;
  B)
    say "B3: a PodDisruptionBudget on web"
    kubectl -n shop apply -f - <<'EOF' >/dev/null
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata: { name: web-pdb }
spec: { minAvailable: 2, selector: { matchLabels: { app: web } } }
EOF
    say "B6: a Released PV with a stale claimRef"
    kubectl get ns data >/dev/null 2>&1 || kubectl create ns data >/dev/null
    kubectl delete pvc -n data orphan-claim --ignore-not-found >/dev/null
    kubectl delete pv pv-orphan --ignore-not-found >/dev/null
    kubectl apply -f - <<'EOF' >/dev/null
apiVersion: v1
kind: PersistentVolume
metadata: { name: pv-orphan }
spec:
  capacity: { storage: 500Mi }
  accessModes: [ReadWriteOnce]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath: { path: /mnt/orphan }
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata: { name: orphan-claim, namespace: data }
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: manual
  resources: { requests: { storage: 500Mi } }
EOF
    kubectl wait -n data pvc/orphan-claim --for=jsonpath='{.status.phase}'=Bound --timeout=60s >/dev/null
    kubectl delete pvc -n data orphan-claim >/dev/null
    say "B7: make sure no default StorageClass is set"
    for sc in $(kubectl get sc -o name); do
      kubectl annotate "$sc" storageclass.kubernetes.io/is-default-class- >/dev/null 2>&1 || true
    done
    ;;
  C)
    say "C8: a Kustomize base"
    rm -rf /opt/mock/kustomize && mkdir -p /opt/mock/kustomize/base
    cat > /opt/mock/kustomize/base/deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata: { name: kz }
spec:
  replicas: 1
  selector: { matchLabels: { app: kz } }
  template:
    metadata: { labels: { app: kz } }
    spec:
      containers: [{ name: kz, image: nginx:1.27, ports: [{ containerPort: 80 }] }]
EOF
    cat > /opt/mock/kustomize/base/service.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata: { name: kz }
spec: { selector: { app: kz }, ports: [{ port: 80 }] }
EOF
    cat > /opt/mock/kustomize/base/kustomization.yaml <<'EOF'
resources:
  - deployment.yaml
  - service.yaml
EOF
    kubectl get ns apps >/dev/null 2>&1 || kubectl create ns apps >/dev/null
    ;;
  *)
    echo "usage: $0 A|B|C" >&2
    exit 2
    ;;
esac
say "set $set_ ready. Forty minutes."
