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

# Pinned versions. A manifest fetched from a branch or "latest" is a different
# cluster every week, and ingress-nginx -- the controller this script used to install
# -- was retired upstream in 2026; its repository no longer exists. Contour is CNCF
# graduated, and its Envoy DaemonSet binds hostPorts 80/443, which is what the
# extraPortMappings above expose on localhost.
CONTOUR_VERSION="v1.33.7"
METRICS_SERVER_VERSION="v0.9.0"

echo "==> Installing Contour ${CONTOUR_VERSION} (ingress controller)"
kubectl apply -f "https://raw.githubusercontent.com/projectcontour/contour/${CONTOUR_VERSION}/examples/render/contour.yaml"
# Envoy must run on the node that owns the port mappings (the control-plane, labelled
# ingress-ready=true in the config above), and that node is tainted.
kubectl patch daemonset -n projectcontour envoy --type=merge -p '{"spec":{"template":{"spec":{
  "nodeSelector":{"ingress-ready":"true"},
  "tolerations":[{"key":"node-role.kubernetes.io/control-plane","operator":"Equal","effect":"NoSchedule"}]}}}}'
# The class name the labs use. Contour also serves Ingresses with no class set.
kubectl apply -f - <<'YAML'
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: contour
spec:
  controller: projectcontour.io/ingress-controller
YAML
kubectl wait --namespace projectcontour \
  --for=condition=ready pod \
  --selector=app=envoy \
  --timeout=180s

echo "==> Installing metrics-server ${METRICS_SERVER_VERSION} (needed for HPA labs)"
kubectl apply -f "https://github.com/kubernetes-sigs/metrics-server/releases/download/${METRICS_SERVER_VERSION}/components.yaml"
kubectl patch -n kube-system deployment metrics-server --type=json \
  -p '[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'

echo
echo "Cluster '${NAME}' ready. Ingress on http://localhost"
echo "Teardown: kind delete cluster --name ${NAME}"
