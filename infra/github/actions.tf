# GitHub Actions hardening.
#
# Only GitHub-authored actions (actions/*, github/*) may run. The workflows in
# .github/workflows/ use those plus a checksum-verified gitleaks binary, so nothing
# third-party executes with a repository token. Widen `patterns_allowed` deliberately,
# one action at a time, pinned by full commit SHA in the workflow.
resource "github_actions_repository_permissions" "this" {
  for_each = github_repository.this

  repository      = each.value.name
  enabled         = true
  allowed_actions = "selected"

  allowed_actions_config {
    github_owned_allowed = true
    verified_allowed     = false
    patterns_allowed     = []
  }
}

# No other repository (even your own) may call this repository's workflows or actions.
resource "github_actions_repository_access_level" "this" {
  for_each = github_repository.this

  repository   = each.value.name
  access_level = "none"
}

# NOTE: the repository-level "default GITHUB_TOKEN permissions = read-only" and "Actions may
# create/approve PRs = off" toggles have no Terraform resource in the integrations/github provider.
# Every workflow therefore declares `permissions: contents: read` at the top level, and the
# README shows the one-line `gh api` call that flips the account-level default too.
