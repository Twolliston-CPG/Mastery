#!/usr/bin/env bash
# Installs the full 26-week toolchain on macOS (Homebrew) or Debian/Ubuntu.
# Idempotent: safe to re-run. Usage: bash 00-toolchain.sh
set -euo pipefail

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }

if [[ "$(uname -s)" == "Darwin" ]]; then
  command -v brew >/dev/null || { log "Installing Homebrew"; \
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; }

  log "Core CLI"
  brew install git jq yq tree watch wget coreutils gnu-sed bash-completion

  log "Cloud + IaC"
  brew install awscli terraform tflint terraform-docs checkov

  log "Containers + Kubernetes"
  brew install docker kubectl kind k9s helm kustomize
  brew install --cask docker || true    # Docker Desktop; or: brew install colima

  log "Security tooling"
  brew install trivy syft cosign gitleaks semgrep

  log "Observability + misc"
  brew install prometheus grafana gh pre-commit

  log "Python"
  brew install python@3.12 pipx && pipx ensurepath

elif [[ -f /etc/debian_version ]]; then
  # amd64 or arm64 -- a VM on an Apple Silicon Mac is arm64, and amd64 binaries will not run there
  ARCH="$(dpkg --print-architecture)"
  # Downloads go to a private temp dir, removed on any exit, not the current directory
  WORK="$(mktemp -d)"
  trap 'rm -rf "$WORK"' EXIT
  cd "$WORK"

  log "APT base"
  sudo apt-get update
  sudo apt-get install -y git curl wget jq tree unzip build-essential \
       python3 python3-pip python3-venv ca-certificates gnupg lsb-release

  log "Docker"
  curl -fsSL https://get.docker.com | sudo sh
  sudo usermod -aG docker "$USER"

  log "kubectl"
  KVER="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
  curl -fsSLO "https://dl.k8s.io/release/${KVER}/bin/linux/${ARCH}/kubectl"
  curl -fsSLO "https://dl.k8s.io/release/${KVER}/bin/linux/${ARCH}/kubectl.sha256"
  echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check   # refuse a corrupted or tampered binary
  sudo install -m 0755 kubectl /usr/local/bin/kubectl

  log "kind"
  curl -fsSLo kind "https://kind.sigs.k8s.io/dl/latest/kind-linux-${ARCH}"
  sudo install -m 0755 kind /usr/local/bin/kind

  log "Terraform"
  wget -qO- https://apt.releases.hashicorp.com/gpg | \
    sudo gpg --dearmor --yes -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
    https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
    sudo tee /etc/apt/sources.list.d/hashicorp.list
  sudo apt-get update && sudo apt-get install -y terraform

  log "AWS CLI v2"
  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" -o awscliv2.zip
  unzip -q awscliv2.zip && sudo ./aws/install --update

  log "Security tooling"
  curl -sSfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sudo sh -s -- -b /usr/local/bin
  curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sudo sh -s -- -b /usr/local/bin
  go install github.com/sigstore/cosign/v2/cmd/cosign@latest 2>/dev/null || \
    echo "  (install cosign manually: https://docs.sigstore.dev/cosign/installation/)"

  log "Helm"
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
else
  echo "Unsupported OS. Install manually - see _setup/README.md" >&2; exit 1
fi

log "Done. Run ./verify.sh to confirm."
