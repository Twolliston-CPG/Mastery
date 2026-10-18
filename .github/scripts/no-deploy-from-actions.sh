#!/usr/bin/env bash
#
# GitHub Actions in this repository never deploys anything. It validates: `terraform fmt`,
# `init -backend=false`, `validate`, scanners. Applying infrastructure is a human at a laptop with
# their own credentials, and the repository holds no cloud credentials, no OIDC trust, no
# environments, and no secrets to make it otherwise.
#
# This script keeps that true by construction. It fails if any workflow GitHub actually runs
# (.github/workflows/) contains a deploy verb, a cloud login action, an OIDC token grant, or a
# credential variable. Comment lines are ignored. The teaching projects' workflows under
# curriculum/projects/*/.github/ are content, not executed by GitHub, and are not scanned.
#
#   bash .github/scripts/no-deploy-from-actions.sh      # or: make lint-workflows
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

# Each alternative is one way infrastructure gets changed or authenticated from a runner.
PATTERN='terraform (apply|destroy|plan|import|state (mv|rm|push))'
PATTERN+='|tofu (apply|destroy|plan|import)'
PATTERN+='|terragrunt (apply|destroy|run-all)'
PATTERN+='|id-token:[[:space:]]*write'
PATTERN+='|aws-actions/configure-aws-credentials'
PATTERN+='|google-github-actions/auth'
PATTERN+='|azure/login'
PATTERN+='|hashicorp/setup-terraform'
PATTERN+='|AWS_ACCESS_KEY_ID|AWS_SECRET_ACCESS_KEY|AWS_SESSION_TOKEN'
PATTERN+='|GOOGLE_CREDENTIALS|GOOGLE_APPLICATION_CREDENTIALS|CLOUDSDK_AUTH'
PATTERN+='|ARM_CLIENT_SECRET|ARM_CLIENT_ID'
PATTERN+='|TF_TOKEN_|TF_API_TOKEN|TF_CLOUD_ORGANIZATION'

hits=0
while IFS= read -r -d '' f; do
  # Strip comment-only lines so documentation of the rule cannot trip the rule.
  if out="$(grep -nE "$PATTERN" "$f" | grep -vE '^[0-9]+:[[:space:]]*#')" && [[ -n "$out" ]]; then
    hits=1
    while IFS= read -r line; do
      echo "::error file=$f::deploy path in a workflow GitHub runs: $line"
    done <<< "$out"
  fi
done < <(git ls-files -z -- '.github/workflows/*.yml' '.github/workflows/*.yaml' '.github/actions/**/action.yml')

if (( hits )); then
  echo
  echo "GitHub Actions is validate-only in this repository (see infra/github/README.md, 'What is enforced')."
  echo "Infrastructure is applied by a human with their own credentials, never from a runner."
  exit 1
fi
echo "no-deploy-from-actions: ok (no apply, no cloud login, no OIDC grant, no credential variables in .github/)"
