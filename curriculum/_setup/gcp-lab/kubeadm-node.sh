#!/usr/bin/env bash
# Startup script for the kubeadm nodes (kubeadm.tf). Runs as root on every boot, so every
# step is idempotent. It prepares a node and stops: no `kubeadm init`, no `kubeadm join`.
# That is week 27, Lab 1, done by hand.
#
# The Kubernetes minor comes from instance metadata (kubernetes_minor in variables.tf), so
# this file carries no version and the upgrade lab decides what "current" means.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

META="http://metadata.google.internal/computeMetadata/v1/instance/attributes"
MINOR="$(curl -fsS -H 'Metadata-Flavor: Google' "${META}/kubernetes-minor")"
case "$MINOR" in
  1.[0-9][0-9]) ;;
  *) echo "kubernetes-minor metadata is '${MINOR}', expected 1.NN" >&2; exit 1 ;;
esac

# --- Kernel: no swap, bridged traffic visible to iptables, forwarding on -------------
# GCE Ubuntu images ship without swap; the guard is for anyone who added some.
swapoff -a
sed -i.bak '/\sswap\s/s/^/#/' /etc/fstab

cat > /etc/modules-load.d/k8s.conf <<'EOF'
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

cat > /etc/sysctl.d/99-kubernetes.conf <<'EOF'
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system >/dev/null

# --- containerd from Ubuntu's archive, with the systemd cgroup driver ---------------
# kubelet and containerd must agree on the cgroup driver; on a systemd host that is
# systemd. The default config.toml says cgroupfs, which is the classic "nodes flap
# NotReady every few minutes" mistake.
apt-get update -q
apt-get install -y -q apt-transport-https ca-certificates curl gpg containerd

if ! grep -q 'SystemdCgroup = true' /etc/containerd/config.toml 2>/dev/null; then
  mkdir -p /etc/containerd
  containerd config default \
    | sed 's/SystemdCgroup = false/SystemdCgroup = true/' \
    > /etc/containerd/config.toml
  systemctl restart containerd
fi
systemctl enable --now containerd

# --- kubelet, kubeadm, kubectl from pkgs.k8s.io, pinned to one minor ---------------
# The repo is per minor: a node installed from v1.34 can only ever apt-upgrade within
# 1.34. The upgrade lab changes this line by hand, which is the point.
KEYRING=/etc/apt/keyrings/kubernetes-apt-keyring.gpg
mkdir -p /etc/apt/keyrings
if [[ ! -s "$KEYRING" ]]; then
  curl -fsSL "https://pkgs.k8s.io/core:/stable:/v${MINOR}/deb/Release.key" \
    | gpg --dearmor -o "$KEYRING"
fi
echo "deb [signed-by=${KEYRING}] https://pkgs.k8s.io/core:/stable:/v${MINOR}/deb/ /" \
  > /etc/apt/sources.list.d/kubernetes.list

apt-get update -q
apt-get install -y -q kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl
systemctl enable --now kubelet   # crash-loops until kubeadm init/join writes its config; expected

echo "kubeadm node ready: containerd $(containerd --version | awk '{print $3}'), kubeadm $(kubeadm version -o short), kubelet $(kubelet --version | awk '{print $2}'). Next: kubeadm init (week 27, Lab 1)."
