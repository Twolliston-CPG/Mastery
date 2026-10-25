#!/usr/bin/env bash
# Installs the full 26-week workstation toolchain on Linux: Debian/Ubuntu (including
# WSL 2) or Arch. Self-contained: the tool list is in this file.
#
# How it installs:
#   - system packages and Docker Engine   from the distro's own package manager,
#                                         using signed repositories
#   - the ~40 command-line tools          with Homebrew, the same list as macos-setup.sh,
#                                         so both platforms get the same current versions
#   - nothing is piped from the internet into a root shell
#
# Idempotent: a tool already on PATH -- however it was installed -- is left exactly as it
# is. One failed install does not stop the rest.
#
# Usage: bash linux-setup.sh          install whatever is missing
#        bash linux-setup.sh --check  report what is missing, install nothing
#
# Run as your normal user. It calls sudo itself for the few steps that need root.
# The labs for weeks 1-4 run on the lab VM, not on your workstation -- see DISTRO.md.
set -euo pipefail

# kind|package|command that proves it is present
#   brew    Homebrew formula
#   native  handled by a function below, per distro
# Lines starting with "#" are group headings, in the order the curriculum needs them.
TOOLS='
# Lab VM (week 1)
native|gcloud|gcloud
brew|hashicorp/tap/terraform|terraform
# Core CLI (week 1)
brew|gh|gh
brew|jq|jq
brew|yq|yq
brew|shellcheck|shellcheck
brew|pre-commit|pre-commit
# Python (week 4)
brew|python@3.12|python3.12
brew|pipx|pipx
# Containers (week 4)
native|docker|docker
brew|hadolint|hadolint
brew|dive|dive
# Cloud + IaC (weeks 5-11)
brew|awscli|aws
native|tflint|tflint
brew|terraform-docs|terraform-docs
brew|checkov|checkov
brew|conftest|conftest
# Kubernetes + GitOps (weeks 14-17)
brew|kubectl|kubectl
brew|kind|kind
brew|helm|helm
brew|kustomize|kustomize
brew|k9s|k9s
brew|kubectx|kubectx
brew|argocd|argocd
brew|kubeseal|kubeseal
brew|kyverno|kyverno
# Policy as code (weeks 13, 19, 23, 28; conftest above covers week 19 Lab 1)
brew|hashicorp/tap/sentinel|sentinel
brew|opa|opa
brew|regal|regal
brew|gator|gator
# Security tooling (weeks 18-19)
brew|trivy|trivy
brew|syft|syft
brew|grype|grype
brew|cosign|cosign
brew|gitleaks|gitleaks
brew|semgrep|semgrep
brew|age|age
# Observability + load (week 20)
brew|prometheus|prometheus
brew|grafana|grafana
brew|hey|hey
# Curriculum toolchain (diagrams, banner)
brew|node|node
brew|librsvg|rsvg-convert
'
# Not in the list because the distro already provides them, or the base step below does:
#   git curl wget tree unzip, GNU coreutils and sed, watch, bash-completion

BREW_HOME=/home/linuxbrew/.linuxbrew

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '  \033[0;32mOK\033[0m     %-30s %s\n' "$1" "$2"; }
note() { printf '  \033[0;33m%-6s\033[0m %-30s %s\n' "$1" "$2" "${3:-}"; }
bad()  { printf '  \033[0;31m%-6s\033[0m %-30s %s\n' "$1" "$2" "${3:-}"; }

usage() { sed -n '2,19p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

mode=install
case "${1:-}" in
  "")        ;;
  --check)   mode=check ;;
  -h|--help) usage; exit 0 ;;
  *)         usage >&2; exit 2 ;;
esac

[[ "$(uname -s)" == "Linux" ]] || { echo "Linux only. On macOS use macos-setup.sh." >&2; exit 1; }
[[ "$EUID" -ne 0 ]] || { echo "Run as your normal user, not root or sudo. Homebrew refuses to run as root; the script asks for sudo when it needs it." >&2; exit 1; }

# --- Which distro family -------------------------------------------------------

# shellcheck source=/dev/null
. /etc/os-release
family=unknown
case " ${ID:-} ${ID_LIKE:-} " in
  *" debian "*|*" ubuntu "*) family=debian ;;
  *" arch "*)                family=arch ;;
esac
if [[ "$family" == unknown ]]; then
  cat >&2 <<MSG
Unsupported distribution: ${PRETTY_NAME:-unknown}. This script handles Debian/Ubuntu and Arch.
On anything else: install git, curl, a C toolchain, and Docker from your distro, install
Homebrew (https://docs.brew.sh/Homebrew-on-Linux), then run this script with --check to see
what is left and 'brew install' it.
MSG
  exit 1
fi

case "$(uname -m)" in
  x86_64)        arch=amd64 ;;
  aarch64|arm64) arch=arm64 ;;
  *) echo "Unsupported CPU architecture: $(uname -m)" >&2; exit 1 ;;
esac

# Downloads and scratch files go to a private directory, removed on any exit.
work="$(mktemp -d)"
logfile="$(mktemp -t linux-setup.XXXXXX)"
trap 'rm -rf "$work"' EXIT

# --- Homebrew ------------------------------------------------------------------

load_brew() {
  if ! command -v brew >/dev/null 2>&1 && [[ -x "$BREW_HOME/bin/brew" ]]; then
    eval "$("$BREW_HOME/bin/brew" shellenv)"
  fi
  command -v brew >/dev/null 2>&1
}

# Present if its command is on PATH (however it got there), or Homebrew has it installed.
have() { # kind package command
  command -v "$3" >/dev/null 2>&1 && return 0
  [[ "$1" == brew ]] && command -v brew >/dev/null 2>&1 && brew list --formula "$2" >/dev/null 2>&1
}

# --- Native installers ---------------------------------------------------------
# Each returns 0 on success, 1 on failure, 2 when it has to be done by hand.
#
# They are called as "fn || rc=$?", and bash switches off "set -e" inside a function
# called that way. So every step is chained with && explicitly: a failed download or a
# checksum mismatch must stop the function, not fall through to the install line.

install_base() {
  if [[ "$family" == debian ]]; then
    sudo apt-get update &&
      sudo apt-get install -y build-essential procps curl file git ca-certificates gnupg tree wget unzip
  else
    # No "pacman -Sy": installing against a refreshed database without upgrading is a
    # partial upgrade. If this fails on stale mirrors, run "sudo pacman -Syu" and re-run.
    sudo pacman -S --needed --noconfirm base-devel procps-ng curl file git tree wget unzip
  fi
}

install_docker() {
  if [[ "$family" == debian ]]; then
    # Docker's own apt repository, pinned to its signing key (not get.docker.com | sh).
    local repo_os=ubuntu codename="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"
    if [[ "${ID:-}" == debian ]]; then repo_os=debian; codename="${VERSION_CODENAME:-}"; fi
    [[ -n "$codename" ]] || return 1
    sudo install -m 0755 -d /etc/apt/keyrings &&
      sudo curl -fsSL "https://download.docker.com/linux/${repo_os}/gpg" -o /etc/apt/keyrings/docker.asc &&
      sudo chmod a+r /etc/apt/keyrings/docker.asc &&
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/${repo_os} ${codename} stable" \
        | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null &&
      sudo apt-get update &&
      sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin ||
      return 1
  else
    sudo pacman -S --needed --noconfirm docker docker-compose docker-buildx || return 1
  fi
  # No systemd under some WSL setups and in containers; the daemon is started another way there.
  if command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]; then
    sudo systemctl enable --now docker || return 1
  fi
  sudo usermod -aG docker "$USER" || return 1
  docker_group_added=1
}

install_gcloud() {
  if [[ "$family" == arch ]]; then
    # Not in the Arch repositories, and this script does not build AUR packages for you.
    manual_hint="https://cloud.google.com/sdk/docs/install#linux  (only needed for the GCP lab VM)"
    return 2
  fi
  # Google's apt repository, pinned to its signing key.
  curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg -o "$work/google.asc" &&
    sudo gpg --dearmor --yes -o /usr/share/keyrings/cloud.google.gpg "$work/google.asc" &&
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" \
      | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list >/dev/null &&
    sudo apt-get update &&
    sudo apt-get install -y google-cloud-cli
}

install_tflint() {
  if [[ "$family" == arch ]]; then
    sudo pacman -S --needed --noconfirm tflint
    return
  fi
  # No apt package and no Homebrew formula: take the release binary and refuse it
  # unless it matches the checksum published with the release.
  local zip="tflint_linux_${arch}.zip" base=https://github.com/terraform-linters/tflint/releases/latest/download
  curl -fsSL "$base/$zip" -o "$work/$zip" &&
    curl -fsSL "$base/checksums.txt" -o "$work/checksums.txt" &&
    (cd "$work" && grep " ${zip}\$" checksums.txt | sha256sum --check --status) &&
    unzip -oq "$work/$zip" -d "$work" &&
    sudo install -m 0755 "$work/tflint" /usr/local/bin/tflint
}

# --- Run -----------------------------------------------------------------------

docker_group_added=0
manual_hint=""
present=0; installed=0; failed=(); manual=()

if [[ "$mode" == install ]]; then
  log "Base packages (compiler toolchain, git, curl -- Homebrew needs these)"
  install_base >>"$logfile" 2>&1 || { echo "Base package install failed. See $logfile" >&2; exit 1; }

  if ! load_brew; then
    log "Installing Homebrew (asks for your sudo password)"
    # Homebrew's documented installer. Downloaded to a file first so that what runs is
    # exactly what was fetched, then run as you -- not as root.
    curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$work/brew-install.sh"
    /bin/bash "$work/brew-install.sh"
    load_brew || { echo "Homebrew installed but not found at $BREW_HOME. Open a new terminal and re-run." >&2; exit 1; }
  fi
else
  load_brew || echo "Homebrew is not installed. Tools already on PATH are still reported below."
fi

# The list is read on fd 3 so that an installer cannot swallow it from stdin.
while IFS='|' read -r -u 3 kind pkg cmd; do
  [[ -z "$kind" ]] && continue
  if [[ "$kind" == \#* ]]; then printf '\n%s\n' "${kind#\# }"; continue; fi

  if have "$kind" "$pkg" "$cmd"; then
    ok "$pkg" "$(command -v "$cmd" 2>/dev/null || echo 'installed (Homebrew)')"
    present=$((present + 1))
    continue
  fi
  if [[ "$mode" == check ]]; then
    bad MISS "$pkg"; failed+=("$pkg")
    continue
  fi

  rc=0
  if [[ "$kind" == brew ]]; then
    brew install --formula "$pkg" </dev/null >>"$logfile" 2>&1 || rc=1
  else
    "install_$pkg" </dev/null >>"$logfile" 2>&1 || rc=$?
  fi
  case "$rc" in
    0) ok "$pkg" "installed now"; installed=$((installed + 1)) ;;
    2) note MANUAL "$pkg" "$manual_hint"; manual+=("$pkg") ;;
    *) bad FAIL "$pkg" "see $logfile"; failed+=("$pkg") ;;
  esac
done 3<<< "$TOOLS"

echo
if [[ "$mode" == check ]]; then
  rm -f "$logfile"
  log "present: $present   missing: ${#failed[@]}"
  [[ ${#failed[@]} -eq 0 ]] || { echo "Run without --check to install them."; exit 1; }
  exit 0
fi

if command -v pipx >/dev/null 2>&1; then pipx ensurepath >/dev/null 2>&1 || true; fi

log "already present: $present   installed now: $installed   manual: ${#manual[@]}   failed: ${#failed[@]}"

cat <<NEXT

Next:
  1. Put Homebrew on your PATH for future shells -- add this line to ~/.bashrc or ~/.zshrc:
       eval "\$($BREW_HOME/bin/brew shellenv)"
  2. gcloud auth login / gcloud auth application-default login   (GCP lab VM)
     or sign in to AWS                                           (AWS lab VM)
  3. Build the lab VM: gcp-lab/README.md or aws-lab/README.md
NEXT

if [[ "$docker_group_added" -eq 1 ]]; then
  cat <<NOTE

Docker: you were added to the "docker" group so the labs can run docker without sudo.
Log out and back in for it to take effect. Know what this means: anyone who can talk to
the Docker daemon can become root on this machine. That is normal for a personal
workstation and wrong for a shared one -- undo it with: sudo gpasswd -d $USER docker
NOTE
fi

if [[ ${#failed[@]} -gt 0 ]]; then
  printf '\nFailed: %s\n' "${failed[*]}"
  echo "Full output: $logfile"
  echo "Fix the cause and re-run; everything that succeeded is skipped next time."
  exit 1
fi
rm -f "$logfile"
