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
| **Actions never deploys.** Workflows run `fmt`, `init -backend=false`, `validate` and scanners only; no secrets, variables, environments, OIDC grants or cloud login actions exist, and `actions-lint` fails if one appears. Applies are a human with their own credentials | `.github/scripts/no-deploy-from-actions.sh`, `security.yml` |
| Workflow lint and supply-chain audit (actionlint, zizmor); shellcheck on every script | `.github/workflows/security.yml` |
| Every CI tool pinned: binaries by per-architecture sha256 (`fetch-tool`), Python by hash-locked requirements | `.github/actions/fetch-tool/`, `.github/requirements/` |
| Workflow dependency lockfile (`actions.lock`), public preview; not yet generated (needs `gh` auth) | `gh actions-lock`; see CLAUDE.md Status |
| IaC misconfiguration scan (checkov + trivy) on the whole repository, teaching content included, blocking | `.github/workflows/security.yml`, `.checkov.yaml`, `.trivyignore.yaml` |
| Author checklist (anonymization, PII, pinned actions, decoded gitleaks allowlist) on every PR | `.github/PULL_REQUEST_TEMPLATE.md` |
| Only the owner's review counts: one approval, code-owner review, re-approval after pushes; owner's own PRs merge by logged admin bypass | `rulesets.tf` (Pro), `.github/CODEOWNERS` |
| Who has access, as an authoritative list (off until imported) | `collaborators.tf`, `terraform.tfvars` |
| Ownership of the token-bearing paths, ready for `require_code_owner_review` | `.github/CODEOWNERS` |

## Review requirements for `main`, in one place

1. Every change arrives as a pull request from a branch. Direct pushes are refused locally by the
   pre-push hook and, once `enable_rulesets=true`, by GitHub.
2. The required checks are green on the PR's head commit, and the branch is current with `main`
   (`strict_required_status_checks_policy`). Required today: `secrets-scan`, `content-checks`,
   `terraform-validate`; target set in `terraform.tfvars.example`.
3. **One approval, and only the owner's counts.** `required_approving_review_count = 1` with
   `require_code_owner_review = true`, and `.github/CODEOWNERS` maps every path to the owner. A
   collaborator's approval does not satisfy the rule. A push after approval dismisses it and the
   last push must be approved by someone other than its author, so nothing slips in behind an
   approval. Every review thread is resolved.
4. **The owner's own PRs** cannot be self-approved. They merge through the admin bypass
   (`bypass_mode = "pull_request"`), which GitHub records in the audit log, so the exception is a
   visible event rather than a quiet default. Nobody else holds the bypass.
5. The author has worked through the checklist in `.github/PULL_REQUEST_TEMPLATE.md`.
6. Merge is squash-only, the branch is deleted on merge, history stays linear.
7. The repository's own policy gate passes: `infra/policy/terraform/` (Conftest, run by `iac-scan`
   and `make policy`). It has no inline skip; an exception is a rule change in the same pull request,
   reviewed as code.

### Who can merge today, and why the plan matters

On a **personal** account, every collaborator has write access; there is no read-only or triage
role to hand out. Write access means: push to any unprotected branch including `main`, approve
pull requests, and merge them. The only things that stop a write collaborator are the rules
above, and GitHub enforces rules on a **private** repository only from the Pro plan up (the API
returns 403 for both rulesets and classic branch protection on Free).

So on Free with collaborators, the gate exists only on paper and in the pre-push hook on your own
laptop. The three ways out, in order of preference:

| Option | What it gives | Cost |
|---|---|---|
| **Upgrade the account to Pro** and apply with `enable_rulesets=true` | Everything above enforced server-side; collaborators keep write but cannot touch `main` except through an approved PR | $4/month |
| Remove collaborators; they fork and open PRs | Only you can merge, even on Free, because only you have write. Private-repo forks need `allow_forking = true` (it is) | Their copies of a private repo |
| Make the repository public | Rules enforced for free | The content is public |

Review the collaborator list and pending invitations before relying on any of this:
`gh api repos/<owner>/<repo>/collaborators --jq '.[] | "\(.login) \(.role_name)"'`.

A fourth option costs nothing and needs no plan change: **transfer the repository to a GitHub
organization** you create. Organization repositories have read, triage, write, maintain and
admin roles, so collaborators can be given read or triage and contribute from forks, and only the
owner holds write. Rules on a private org repository still need the Team plan, but the role model
alone already means only you can merge. The repository URL changes (GitHub redirects the old one)
and every clone's remote should be updated.

### Collaborators as code

`collaborators.tf` declares who has access. It is authoritative and therefore off by default
(`manage_collaborators = false`); the adoption steps are in the file. The current list lives in
`terraform.tfvars` (gitignored, so the roster is not in the repository's history). Once adopted,
adding or removing a person is a one-line diff in a pull request that you review.

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
