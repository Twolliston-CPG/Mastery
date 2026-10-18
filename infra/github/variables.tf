variable "github_owner" {
  description = "GitHub user that owns the repositories. Leave null to use the token's own account."
  type        = string
  default     = null
}

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

variable "manage_collaborators" {
  description = "Make var.collaborators the complete, authoritative list of people with access (anyone not listed is removed). Off by default; see collaborators.tf for the adoption steps."
  type        = bool
  default     = false
}

variable "collaborators" {
  description = "GitHub login -> permission for everyone except the owner. On a personal account the only meaningful value is \"push\" (write); pull/triage/maintain exist for organization repositories."
  type        = map(string)
  default     = {}

  validation {
    condition     = alltrue([for _, p in var.collaborators : contains(["pull", "triage", "push", "maintain", "admin"], p)])
    error_message = "Permissions must be one of pull, triage, push, maintain, admin."
  }
}
