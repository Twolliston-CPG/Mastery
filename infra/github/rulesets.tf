# Default-branch protection as a ruleset (the successor to classic branch protection).
#
# Gated behind var.enable_rulesets because GitHub returns 403 for rulesets on private
# repositories under the Free plan. Everything else in this configuration applies on Free.
# The for_each is the opt-in guard: with the flag off the map is empty, the resource has no
# instances and nothing is in state, so flipping the flag plans one create and flipping it back
# plans one destroy. `enforcement = "active"` applies the rules; "evaluate" would dry-run them
# into the rule insights page without blocking anything, and "disabled" keeps the ruleset as a
# record only. The target is the branch named by ~DEFAULT_BRANCH, which follows a rename of main.
resource "github_repository_ruleset" "default_branch" {
  for_each = var.enable_rulesets ? github_repository.this : {}

  name        = "protect-default-branch"
  repository  = each.value.name
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["~DEFAULT_BRANCH"]
      exclude = []
    }
  }

  # Repository admins (you) may bypass, but only by merging a pull request whose checks are
  # not green -- never by pushing straight to main. "always" would let a hijacked session on
  # this account skip CI silently; "pull_request" leaves a PR and an audit-log entry behind.
  # Remove the block for zero exceptions.
  bypass_actors {
    actor_id    = 5 # RepositoryRole: admin
    actor_type  = "RepositoryRole"
    bypass_mode = "pull_request"
  }

  # The rules, in the order GitHub evaluates a push: the branch itself (no delete, no force-push,
  # linear history, optional signatures), then what a pull request must carry, then which checks
  # must have passed. required_signatures is a variable because enabling it before signing is
  # configured locally rejects every push, including the one that would fix it.
  rules {
    deletion                = true # main cannot be deleted
    non_fast_forward        = true # no force-push
    required_linear_history = true # pairs with squash-only merges
    required_signatures     = var.require_signed_commits

    pull_request {
      # Squash is the only merge method. main.tf already disables the other two on the repository
      # settings page; this repeats it as a rule so flipping the setting back cannot bypass it.
      allowed_merge_methods = ["squash"]

      # The review gate. The repository has write collaborators, so a PR needs one approval, and
      # because .github/CODEOWNERS maps every path to the owner, only the owner's approval counts.
      # A collaborator cannot approve another collaborator's PR into main; a collaborator cannot
      # push to main at all (the PR requirement covers that). The owner's own PRs cannot be
      # self-approved: they merge through the admin bypass above, which GitHub records in the
      # audit log as a bypass, so the exception is visible rather than silent.
      required_approving_review_count = 1
      require_code_owner_review       = true
      # An approval is for the commits that were reviewed. A push after approval resets it, and a
      # push by someone else than the approver needs the owner to look again.
      dismiss_stale_reviews_on_push     = true
      require_last_push_approval        = true
      required_review_thread_resolution = true
    }

    # The CI gate. One required_check block per name in var.required_status_checks; the `context`
    # must equal the check-run name GitHub receives, which for Actions is the job's `name:` in
    # ci.yml and security.yml, so renaming a job there without changing the list blocks every
    # merge. No integration_id is set, so any app may report the check; Actions is the one that
    # does. `strict` means a PR must be rebased or updated onto the current main before it can
    # merge, so the checks ran against what will actually land. do_not_enforce_on_create = false
    # keeps the requirement even for the push that creates a branch matching the ruleset.
    required_status_checks {
      strict_required_status_checks_policy = true # branch must be current with main
      do_not_enforce_on_create             = false

      dynamic "required_check" {
        for_each = toset(var.required_status_checks)
        content {
          context = required_check.value
        }
      }
    }
  }
}
