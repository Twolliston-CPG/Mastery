#!/usr/bin/env bash
# Confirms the toolchain is installed and sane.
set -uo pipefail
pass=0; fail=0
chk() {
  if command -v "$1" >/dev/null 2>&1; then
    printf '  \033[0;32mOK\033[0m   %-16s %s\n' "$1" "$(${2:-$1 --version} 2>&1 | head -1 | cut -c1-60)"
    pass=$((pass+1))
  else
    printf '  \033[0;31mMISS\033[0m %-16s\n' "$1"; fail=$((fail+1))
  fi
}
echo "== Core =="
chk git; chk jq; chk python3; chk curl
echo "== Cloud / IaC =="
chk aws "aws --version"; chk terraform; chk tflint; chk checkov
echo "== Containers / K8s =="
chk docker "docker --version"; chk kubectl "kubectl version --client"; chk kind; chk helm; chk k9s
echo "== Security =="
chk trivy; chk syft; chk cosign; chk gitleaks; chk semgrep
echo "== Dev =="
chk gh; chk pre-commit
echo
echo "passed: $pass   missing: $fail"
[[ $fail -eq 0 ]] && echo "Toolchain ready." || echo "Run 00-toolchain.sh, or install the missing items manually."
