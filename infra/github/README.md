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
git remote add origin git@github.com:<you>/mastery.git
git push -u origin main
```

## Second pass (after the first CI run is green)

```bash
# Private-repo rulesets need GitHub Pro. On Free the API returns 403.
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
| No deletion / force-push on `main`; PR + required CI checks | `rulesets.tf` (Pro) |
| Secret scanning (gitleaks) pre-commit and in CI, pinned + checksummed | repo root, `.github/workflows/ci.yml` |

## Importing an existing repository

If the repository already exists (created in the UI), adopt it instead of recreating it:

```bash
terraform import 'github_repository.this["mastery"]' mastery
terraform plan   # should show only in-place settings changes
```

## Adding another repository

Add a key to `var.repositories` (for example the public portfolio repo). Every control above
applies to it automatically; override visibility per repo only by extending the variable.
