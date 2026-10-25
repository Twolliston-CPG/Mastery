# GitHub Actions hardening.
#
# Only GitHub-authored actions (actions/*, github/*) may run. The workflows in
# .github/workflows/ use those plus a checksum-verified gitleaks binary, so nothing
# third-party executes with a repository token. Widen `patterns_allowed` deliberately,
# one action at a time, pinned by full commit SHA in the workflow.
# What the Actions policy below does, argument by argument: `enabled` keeps Actions switched on at
# all (false would disable every workflow); `allowed_actions = "selected"` is what makes the
# allowed_actions_config block apply ("all" ignores it, "local_only" allows nothing from
# outside the repository); inside it, github_owned_allowed admits actions/* and github/*,
# verified_allowed = false means a Marketplace "verified creator" badge earns no trust here, and
# patterns_allowed is the explicit allowlist, empty, in the form "owner/repo@*" when a third-party
# action is ever adopted. The local composite action ./.github/actions/fetch-tool is not governed
# by this policy: actions in the repository itself always run. The plan shows these three fields
# as a change whenever someone flips the toggle on the settings page.
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
# The alternatives are "user" (every repository of this account) and "organization"; "none" means a
# `workflow_call` or a `uses: SerginoDelia/twots/...` from elsewhere is refused, so nothing can
# borrow this repository's token through a reusable workflow.
resource "github_actions_repository_access_level" "this" {
  for_each = github_repository.this

  repository   = each.value.name
  access_level = "none"
}

# NOTE: the repository-level "default GITHUB_TOKEN permissions = read-only" and "Actions may
# create/approve PRs = off" toggles have no Terraform resource in the integrations/github provider.
# Every workflow therefore declares `permissions: contents: read` at the top level, and the
# README shows the one-line `gh api` call that flips the account-level default too.
