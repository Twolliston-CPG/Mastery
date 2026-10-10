# Default-branch protection as a ruleset (the successor to classic branch protection).
#
# Gated behind var.enable_rulesets because GitHub returns 403 for rulesets on private
# repositories under the Free plan. Everything else in this configuration applies on Free.
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

  # Repository admins (you) may bypass. On a solo repo this is the escape hatch for emergency
  # fixes; every bypass is recorded in the audit log. Remove the block for zero exceptions.
  bypass_actors {
    actor_id    = 5 # RepositoryRole: admin
    actor_type  = "RepositoryRole"
    bypass_mode = "always"
  }

  rules {
    deletion                = true # main cannot be deleted
    non_fast_forward        = true # no force-push
    required_linear_history = true # pairs with squash-only merges
    required_signatures     = var.require_signed_commits

    pull_request {
      # 0 approvals: a solo author cannot approve their own PR. The gate is CI, not review.
      required_approving_review_count   = 0
      dismiss_stale_reviews_on_push     = true
      require_code_owner_review         = false
      require_last_push_approval        = false
      required_review_thread_resolution = true
    }

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
