# The repository itself, plus the two Dependabot switches that live on it. This is the bootstrap
# pattern: the configuration that creates and hardens the repository is stored inside it. The
# live `twots` repository predates this file, so imports.tf adopts it; from then on every
# settings change is a plan, and `terraform destroy` archives rather than deletes.

# trivy: same false positive as the CKV_GIT_3 skip inside (AVD-GIT-0003 only reads the inline argument).
# The ignore must sit directly above the block; trivy does not read it from inside.
#trivy:ignore:AVD-GIT-0003
resource "github_repository" "this" {
  # checkov:skip=CKV_GIT_3: False positive. Vulnerability alerts are enabled by the github_repository_vulnerability_alerts resource below; the deprecated inline argument is not used.
  # One instance per key of var.repositories. The key becomes the resource address and the
  # repository name, which is why imports.tf can adopt by that same string.
  for_each = var.repositories

  # Identity and metadata. `visibility` is private for every repository in the map: the parent
  # workspace this curriculum sits in holds personal data, and the collaborator roster means
  # "private" is the only setting under which write access is a deliberate grant.
  name         = each.key
  description  = each.value.description
  homepage_url = each.value.homepage_url
  topics       = each.value.topics
  visibility   = "private"

  # Minimal surface: issues for a personal backlog, nothing else.
  has_issues      = true
  has_discussions = false
  has_projects    = false
  has_wiki        = false

  # One merge strategy -> linear, readable history on a content repo.
  # With squash as the only method, each pull request becomes exactly one commit on main, and PR_TITLE / PR_BODY make
  # the PR's title and description that commit's message: the rationale written for review is
  # the rationale `git log` shows, which is what this repository's commit-message rule relies on.
  # allow_update_branch lets GitHub offer "update branch" on a stale PR (the ruleset's strict
  # status-check policy needs branches current with main); auto-merge stays off so a merge is
  # always a human click after the checks, not a queued one; delete_branch_on_merge removes the
  # head branch on merge, which is also why a stacked PR's base disappears and GitHub closes it.
  allow_merge_commit          = false
  allow_rebase_merge          = false
  allow_squash_merge          = true
  squash_merge_commit_title   = "PR_TITLE"
  squash_merge_commit_message = "PR_BODY"
  allow_update_branch         = true
  allow_auto_merge            = false
  delete_branch_on_merge      = true

  # The codebase already exists locally and is pushed as the first commit, so GitHub must not
  # seed main with its own README (that would force a merge or a force-push on day one).
  auto_init = false

  # `terraform destroy` or removing the key from var.repositories ARCHIVES the repo instead of
  # deleting it. Deleting is a deliberate, manual act in the GitHub UI.
  archive_on_destroy = true

  # Secret scanning + push protection are NOT configurable here on purpose: on a private repo
  # owned by a personal account they require GitHub Advanced Security, and setting the
  # security_and_analysis block without it fails the apply. The compensating controls are the
  # gitleaks pre-commit hook and the `secrets-scan` CI job, both pinned to the same release.

  # Two guards against losing the repository. prevent_destroy makes any plan that would destroy
  # this resource fail before it runs, whether from `terraform destroy` or from removing the key
  # from var.repositories. archive_on_destroy above is the second guard, for the day someone
  # deliberately removes this lifecycle block: the repository is archived, never deleted.
  lifecycle {
    prevent_destroy = true
  }
}

# Dependabot alerts (free on private repositories).
# GitHub builds a dependency graph from the
# manifests it recognises here (.terraform.lock.hcl, the hash-locked requirements .txt files,
# the workflows' `uses:` lines) and raises an alert in the Security tab when one matches the
# advisory database. This is the resource that enables it; the deprecated inline argument on
# github_repository is what the two scanner suppressions above are about. Alerts are a
# precondition for security updates below, and the imports.tf block adopts the live switch.
resource "github_repository_vulnerability_alerts" "this" {
  for_each = github_repository.this

  repository = each.value.name
}

# Dependabot *security updates* (auto-PRs for vulnerable dependencies). Alerts must be on first.
# The API refuses to enable updates on a repository without alerts, hence the explicit
# depends_on, which the implicit for_each reference on github_repository would not provide.
# These are distinct from the scheduled version updates configured in .github/dependabot.yml;
# a security update is raised as soon as an alert has a fix, regardless of that schedule, and
# the one with no installable fix is handled by the dismissal policy in CLAUDE.md.
resource "github_repository_dependabot_security_updates" "this" {
  for_each = github_repository.this

  repository = each.value.name
  enabled    = true

  depends_on = [github_repository_vulnerability_alerts.this]
}
