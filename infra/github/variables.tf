# Inputs for this root. Every default here is the live configuration of the `twots` repository;
# terraform.tfvars (gitignored) overrides them, and terraform.tfvars.example records what the
# full-enforcement values look like. The two opt-in flags, enable_rulesets and
# manage_collaborators, each gate a resource that is dangerous or impossible to apply before a
# precondition is met; both are false until it is.

variable "github_owner" {
  description = "GitHub user that owns the repositories. Leave null to use the token's own account."
  type        = string
  default     = null
}

# A map rather than a single repository so a second one can be added as a new key. The key is
# load-bearing: it is the repository's name on GitHub, the instance key of every per-repository
# resource (github_repository.this["twots"]), and the id the import blocks adopt by.
variable "repositories" {
  description = "Repositories to manage. Keyed by repository name (`twots` is the repo that exists on GitHub; imports.tf adopts it). All are created private."
  type = map(object({
    description  = string
    topics       = optional(list(string), [])
    homepage_url = optional(string)
  }))
  default = {
    twots = {
      description = "26-week DevOps / DevSecOps / Platform Engineering curriculum: weekly labs, break/fix library, anonymized reference corpus, and the Python toolchain that validates it."
      topics      = ["devops", "devsecops", "platform-engineering", "kubernetes", "terraform", "curriculum"]
    }
  }

  validation {
    condition     = alltrue([for k, _ in var.repositories : can(regex("^[a-z0-9][a-z0-9._-]{0,99}$", k))])
    error_message = "Repository names must be lowercase, start alphanumeric, and use only [a-z0-9._-]."
  }
}

# While false, rulesets.tf contributes nothing to the plan and nothing server-side stops a push
# to main: on the Free plan the only guards are the local pre-push hook and the squash-only
# setting in main.tf. Flipping it to true plans exactly one create (the ruleset) and fails with
# 403 until the account is on Pro or the repository is public.
variable "enable_rulesets" {
  description = <<-EOT
    Create the branch ruleset that protects the default branch (no deletion, no force-push, linear
    history, PR + green CI required). GitHub only honours rulesets on PRIVATE repositories for
    accounts on Pro / Team / Enterprise; on the Free plan the API returns 403 for private repos.
    Set to true once the account is on Pro (or the repository is public).
  EOT
  type        = bool
  default     = false
}

variable "require_signed_commits" {
  description = "Add 'required signatures' to the default-branch ruleset. Enable only after SSH or GPG commit signing is configured locally, or every push to main is rejected."
  type        = bool
  default     = false
}

# Consumed only by rulesets.tf, so on Free it is recorded here and not enforced. Each entry is
# matched against the check-run name GitHub receives, which for Actions is the job's `name:`
# exactly, not the workflow name; a name that no job ever reports blocks every merge forever,
# which is why a job joins the list only after it has been seen green.
variable "required_status_checks" {
  description = <<-EOT
    Job names that must pass before a PR can merge into the default branch. Each must match the
    `name:` of a job in .github/workflows/ci.yml or security.yml. A job is added here only after
    it has been seen green on the runner, because a required check that fails for an environmental
    reason blocks every merge. All seven ran green on PR #9 (2026-10-17, ubuntu-24.04-arm).
  EOT
  type        = list(string)
  default = [
    "secrets-scan", "content-checks", "terraform-validate", "figures-fresh",
    "actions-lint", "shell-lint", "iac-scan",
  ]
}

# The dangerous one. Setting it true before importing the live list (collaborators.tf, steps
# 1 to 4) makes the first apply remove every collaborator not in var.collaborators, which with
# the empty default is everyone but the owner.
variable "manage_collaborators" {
  description = "Make var.collaborators the complete, authoritative list of people with access (anyone not listed is removed). Off by default; see collaborators.tf for the adoption steps."
  type        = bool
  default     = false
}

# Login -> permission. Empty by default so the import step, not this file, decides who is in;
# the live roster lives in terraform.tfvars, which is gitignored because it names people.
variable "collaborators" {
  description = "GitHub login -> permission for everyone except the owner. On a personal account the only meaningful value is \"push\" (write); pull/triage/maintain exist for organization repositories."
  type        = map(string)
  default     = {}

  validation {
    condition     = alltrue([for _, p in var.collaborators : contains(["pull", "triage", "push", "maintain", "admin"], p)])
    error_message = "Permissions must be one of pull, triage, push, maintain, admin."
  }
}
