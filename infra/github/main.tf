resource "github_repository" "this" {
  # checkov:skip=CKV_GIT_3: False positive. Vulnerability alerts are enabled by the github_repository_vulnerability_alerts resource below; the deprecated inline argument is not used.
  for_each = var.repositories

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

  lifecycle {
    prevent_destroy = true
  }
}

# Dependabot alerts (free on private repositories).
resource "github_repository_vulnerability_alerts" "this" {
  for_each = github_repository.this

  repository = each.value.name
}

# Dependabot *security updates* (auto-PRs for vulnerable dependencies). Alerts must be on first.
resource "github_repository_dependabot_security_updates" "this" {
  for_each = github_repository.this

  repository = each.value.name
  enabled    = true

  depends_on = [github_repository_vulnerability_alerts.this]
}
