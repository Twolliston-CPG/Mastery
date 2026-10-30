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
#
# What a first plan looks like with these in place: "5 to import", then whatever settings differ
# between the live repository and this configuration as "to change", and "0 to add". The goal of
# adoption is that second number reaching zero, at which point the configuration describes the
# repository exactly. Not imported: the ruleset (it cannot exist on Free) and the collaborator
# list (its import is a deliberate step, in collaborators.tf, because applying it removes people).

# The repository: name, description, topics, merge settings, archive-on-destroy.
import {
  to = github_repository.this["twots"]
  id = "twots"
}

# The Dependabot alerts switch, which the UI had already turned on.
import {
  to = github_repository_vulnerability_alerts.this["twots"]
  id = "twots"
}

# The Dependabot security-updates switch, likewise.
import {
  to = github_repository_dependabot_security_updates.this["twots"]
  id = "twots"
}

# The Actions allow-list. Live is "all"; the plan shows this one as a change until applied,
# because actions.tf narrows it to GitHub-authored actions only.
import {
  to = github_actions_repository_permissions.this["twots"]
  id = "twots"
}

# Who may call this repository's workflows from outside; actions.tf sets it to nobody.
import {
  to = github_actions_repository_access_level.this["twots"]
  id = "twots"
}
