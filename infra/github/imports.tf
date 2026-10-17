# Adopt the repository that already exists on GitHub instead of creating it.
#
# `twots` was created in the GitHub UI on or before 2026-10-17 and pushed to before this
# configuration was ever applied. Without these blocks the first `terraform apply` would try to
# create a second repository (and fail on the name collision). Import blocks are declarative
# imports: `terraform plan` shows them as "to import", and once the resources are in state they
# are no-ops, so the file can stay.
#
# Every per-repository settings resource in this configuration is keyed by the repository name,
# and each one's import id is also the repository name.

import {
  to = github_repository.this["twots"]
  id = "twots"
}

import {
  to = github_repository_vulnerability_alerts.this["twots"]
  id = "twots"
}

import {
  to = github_repository_dependabot_security_updates.this["twots"]
  id = "twots"
}

import {
  to = github_actions_repository_permissions.this["twots"]
  id = "twots"
}

import {
  to = github_actions_repository_access_level.this["twots"]
  id = "twots"
}
