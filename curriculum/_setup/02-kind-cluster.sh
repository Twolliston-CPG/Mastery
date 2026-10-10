#!/usr/bin/env bash
# Local Kubernetes for weeks 14-26. Free. Use this instead of EKS by default.
# Usage: bash 02-kind-cluster.sh [cluster-name]
set -euo pipefail
NAME="${1:-mastery}"

CONFIG="$(mktemp)"
trap 'rm -f "$CONFIG"' EXIT

cat > "$CONFIG" <<'YAML'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    kubeadmConfigPatches:
      - |
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true"
    extraPortMappings:
      # listenAddress 127.0.0.1: reachable from this machine only, not from the network it is on
      - containerPort: 80
        hostPort: 80
        listenAddress: "127.0.0.1"
        protocol: TCP
      - containerPort: 443
        hostPort: 443
        listenAddress: "127.0.0.1"
        protocol: TCP
  - role: worker
  - role: worker
YAML

kind create cluster --name "$NAME" --config "$CONFIG"
kubectl cluster-info --context "kind-${NAME}"

echo "==> Installing ingress-nginx"
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=180s

echo "==> Installing metrics-server (needed for HPA labs)"
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl patch -n kube-system deployment metrics-server --type=json \
  -p '[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'

echo
echo "Cluster '${NAME}' ready. Ingress on http://localhost"
echo "Teardown: kind delete cluster --name ${NAME}"
