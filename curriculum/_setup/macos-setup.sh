#!/usr/bin/env bash
# Installs the full 26-week workstation toolchain on macOS with Homebrew.
# Self-contained: the tool list is in this file; nothing else needs to be present.
#
# Idempotent: a tool already on this Mac -- from Homebrew or anywhere else -- is left
# exactly as it is, never upgraded or relinked. One failed install does not stop the rest.
#
# Usage: bash macos-setup.sh          install whatever is missing
#        bash macos-setup.sh --check  report what is missing, install nothing
#
# The labs for weeks 1-4 run on the Linux VM, not on the Mac -- see DISTRO.md.
set -euo pipefail

# type|package|command that proves it is present ("-" = ask Homebrew instead)
# Lines starting with "#" are group headings, in the order the curriculum needs them.
TOOLS='
# Lab VM (week 1)
cask|gcloud-cli|gcloud
formula|hashicorp/tap/terraform|terraform
# Core CLI (week 1)
formula|git|git
formula|gh|gh
formula|jq|jq
formula|yq|yq
formula|tree|tree
formula|watch|watch
formula|wget|wget
formula|coreutils|gls
formula|gnu-sed|gsed
formula|bash-completion|-
formula|shellcheck|shellcheck
formula|pre-commit|pre-commit
# Python (week 4)
formula|python@3.12|python3.12
formula|pipx|pipx
# Containers (week 4)
cask|docker-desktop|docker
formula|hadolint|hadolint
formula|dive|dive
# Cloud + IaC (weeks 5-11)
formula|awscli|aws
cask|terraform-linters/tap/tflint|tflint
formula|terraform-docs|terraform-docs
formula|checkov|checkov
formula|conftest|conftest
# Kubernetes + GitOps (weeks 14-17)
formula|kubectl|kubectl
formula|kind|kind
formula|helm|helm
formula|kustomize|kustomize
formula|k9s|k9s
formula|kubectx|kubectx
formula|argocd|argocd
formula|kubeseal|kubeseal
formula|kyverno|kyverno
# Security tooling (weeks 18-19)
formula|trivy|trivy
formula|syft|syft
formula|grype|grype
formula|cosign|cosign
formula|gitleaks|gitleaks
formula|semgrep|semgrep
formula|age|age
# Observability + load (week 20)
formula|prometheus|prometheus
formula|grafana|grafana
formula|hey|hey
# Curriculum toolchain (diagrams, banner)
formula|node|node
formula|librsvg|rsvg-convert
'
# Notes on the list:
#   terraform  from HashiCorp's tap: homebrew-core is frozen at 1.5.x, the configs need >= 1.9
#   tflint     from its maintainers' tap: there is no tflint formula in homebrew-core
#   multipass  not listed: only the Ubuntu path uses it. brew install --cask multipass
#   qemu, gnupg  not listed: only the Arch-on-GCP path uses them, to import the Arch cloud image
#              (gcp-lab/README.md step 8). brew install qemu gnupg

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '  \033[0;32mOK\033[0m    %-34s %s\n' "$1" "$2"; }
miss() { printf '  \033[0;31m%-5s\033[0m %-34s %s\n' "$1" "$2" "${3:-}"; }

usage() { sed -n '2,11p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

mode=install
case "${1:-}" in
  "")        ;;
  --check)   mode=check ;;
  -h|--help) usage; exit 0 ;;
  *)         usage >&2; exit 2 ;;
esac

[[ "$(uname -s)" == "Darwin" ]] || { echo "macOS only. On Debian/Ubuntu use 00-toolchain.sh." >&2; exit 1; }
[[ "$EUID" -ne 0 ]] || { echo "Run as your normal user, not with sudo. Homebrew refuses to run as root." >&2; exit 1; }

have_brew() { command -v brew >/dev/null 2>&1; }

# Present if its command is on PATH (however it got there), or Homebrew has it installed.
have() { # type package command
  if [[ "$3" != "-" ]] && command -v "$3" >/dev/null 2>&1; then return 0; fi
  have_brew && brew list "--$1" "$2" >/dev/null 2>&1
}

if ! have_brew; then
  if [[ "$mode" == check ]]; then
    echo "Homebrew is not installed. Tools already on PATH are still reported below."
  else
    log "Installing Homebrew"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if   [[ -x /opt/homebrew/bin/brew ]]; then eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x /usr/local/bin/brew    ]]; then eval "$(/usr/local/bin/brew shellenv)"
    fi
    have_brew || { echo "Homebrew installed but not on PATH. Open a new terminal and re-run." >&2; exit 1; }
  fi
fi

logfile="$(mktemp -t macos-setup)"
present=0; installed=0; failed=()

# The list is read on fd 3 so that brew cannot swallow it from stdin.
while IFS='|' read -r -u 3 type pkg cmd; do
  [[ -z "$type" ]] && continue
  if [[ "$type" == \#* ]]; then printf '\n%s\n' "${type#\# }"; continue; fi

  if have "$type" "$pkg" "$cmd"; then
    where="$(command -v "$cmd" 2>/dev/null || echo 'installed (Homebrew)')"
    ok "$pkg" "$where"; present=$((present + 1))
  elif [[ "$mode" == check ]]; then
    miss MISS "$pkg"; failed+=("$pkg")
  elif brew install "--$type" "$pkg" </dev/null >>"$logfile" 2>&1; then
    ok "$pkg" "installed now"; installed=$((installed + 1))
  else
    miss FAIL "$pkg" "see $logfile"; failed+=("$pkg")
  fi
done 3<<< "$TOOLS"

echo
if [[ "$mode" == check ]]; then
  rm -f "$logfile"
  log "present: $present   missing: ${#failed[@]}"
  [[ ${#failed[@]} -eq 0 ]] || { echo "Run without --check to install them."; exit 1; }
  exit 0
fi

command -v pipx >/dev/null 2>&1 && pipx ensurepath >/dev/null 2>&1 || true

log "already present: $present   installed now: $installed   failed: ${#failed[@]}"
if [[ ${#failed[@]} -gt 0 ]]; then
  printf '  failed: %s\n' "${failed[*]}"
  echo "  Full output: $logfile"
  echo "  Fix the cause and re-run; everything that succeeded is skipped next time."
  exit 1
fi
rm -f "$logfile"

cat <<'NEXT'

Next:
  1. Start Docker Desktop once so the docker CLI can reach it.
  2. gcloud auth login                           for gcloud commands
     gcloud auth application-default login       for Terraform
  3. Build the lab VM: gcp-lab/README.md
NEXT
