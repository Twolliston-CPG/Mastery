# GitHub repository as code

Terraform that creates and hardens the private GitHub repository for this codebase
(`integrations/github` provider). The configuration lives *inside* the repository it manages
("bootstrap" pattern): Terraform creates the empty repo, then the first `git push` uploads the
codebase including this directory. State stays local and gitignored.

## Authenticate (once)

Use a **fine-grained personal access token**, not a classic one:

| Setting | Value |
|---|---|
| Resource owner | your user |
| Repository access | **All repositories** (required to *create* a repository) |
| Repository permissions | Administration: **Read and write** · Metadata: Read |
| Expiration | 90 days or less |

```bash
export GITHUB_TOKEN='github_pat_...'   # shell env only; never in a .tf/.tfvars file
```

Alternative: `gh auth login` then `export GITHUB_TOKEN=$(gh auth token)`. That token carries the
broad `repo` scope, so prefer the fine-grained PAT and revoke it after the apply if you like.

## Apply

```bash
cd infra/github
terraform init
terraform plan -out tfplan
terraform apply tfplan
terraform output next_steps
```

Then push (from the repository root):

```bash
git remote add origin git@github.com:<you>/twots.git
git push -u origin main
```

## Second pass (after the `ci` and `security` workflows are green)

```bash
# 1. Require every job that has been seen green: copy the required_status_checks block from
#    terraform.tfvars.example into terraform.tfvars.
# 2. Private-repo rulesets need GitHub Pro. On Free the API returns 403.
terraform apply -var enable_rulesets=true

# After SSH commit signing is set up (see root README recommendations):
terraform apply -var enable_rulesets=true -var require_signed_commits=true
```

Put the two flags in `terraform.tfvars` (gitignored) once they are permanent.

## What is enforced

| Control | Where |
|---|---|
| Private visibility, wiki/projects/discussions off | `main.tf` |
| Squash-only merges, branch auto-delete, linear history | `main.tf`, `rulesets.tf` |
| Dependabot alerts + security updates | `main.tf` |
| Archive instead of delete on destroy; `prevent_destroy` | `main.tf` |
| Only GitHub-authored actions may run; no cross-repo workflow access | `actions.tf` |
| No deletion / force-push on `main`; PR + required CI checks; review threads resolved | `rulesets.tf` (Pro) |
| Direct push to `main` refused on the client (compensates for the ruleset on Free) | `.pre-commit-config.yaml` pre-push hook |
| Secret scanning (gitleaks) pre-commit and in CI, pinned + checksummed | repo root, `.github/workflows/ci.yml` |
| Workflow lint and supply-chain audit (actionlint, zizmor); shellcheck on every script | `.github/workflows/security.yml` |
| Every CI tool pinned: binaries by per-architecture sha256 (`fetch-tool`), Python by hash-locked requirements | `.github/actions/fetch-tool/`, `.github/requirements/` |
| Workflow dependency lockfile (`actions.lock`), public preview; not yet generated (needs `gh` auth) | `gh actions-lock`; see CLAUDE.md Status |
| IaC misconfiguration scan (checkov + trivy) on the whole repository, teaching content included, blocking | `.github/workflows/security.yml`, `.checkov.yaml`, `.trivyignore.yaml` |
| Author checklist (anonymization, PII, pinned actions, decoded gitleaks allowlist) on every PR | `.github/PULL_REQUEST_TEMPLATE.md` |
| Ownership of the token-bearing paths, ready for `require_code_owner_review` | `.github/CODEOWNERS` |

## Review requirements for `main`, in one place

1. Every change arrives as a pull request from a branch. Direct pushes are refused locally by the
   pre-push hook and, once `enable_rulesets=true`, by GitHub.
2. The required checks are green on the PR's head commit, and the branch is current with `main`
   (`strict_required_status_checks_policy`). Required today: `secrets-scan`, `content-checks`,
   `terraform-validate`; target set in `terraform.tfvars.example`.
3. Every review thread is resolved. Zero approvals are required because a solo author cannot
   approve their own PR; flip `required_approving_review_count` and `require_code_owner_review`
   when a second maintainer joins (`CODEOWNERS` is already in place).
4. The author has worked through the checklist in `.github/PULL_REQUEST_TEMPLATE.md`.
5. Merge is squash-only, the branch is deleted on merge, history stays linear.
6. An admin may bypass only by merging a PR (`bypass_mode = "pull_request"`), which leaves an
   audit-log entry; never by pushing to `main`.

## Adopting the existing repository (first apply)

`twots` was created in the GitHub UI before this configuration was ever applied, so the first
apply must **adopt** it rather than create it. `imports.tf` does that declaratively with `import`
blocks for the repository and the four per-repository settings resources:

```bash
terraform init
terraform plan -out tfplan   # expect: 5 to import, 0 to add, N to change (settings drift), 0 to destroy
terraform apply tfplan
```

If the plan shows anything **to add** or **to destroy**, stop: the name in `var.repositories` and
the ids in `imports.tf` disagree with what is on GitHub. The import blocks are idempotent and can
stay in place after the first apply.

## Adding another repository

Add a key to `var.repositories` (for example the public portfolio repo). Every control above
applies to it automatically; override visibility per repo only by extending the variable.
