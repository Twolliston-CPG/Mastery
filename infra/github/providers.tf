# The provider block: one GitHub account, one token, talking to github.com (no `base_url`, which
# only GitHub Enterprise Server would set).
#
# Authentication comes from the GITHUB_TOKEN environment variable. Never put a token in a
# .tf, .tfvars, or .auto.tfvars file; see README.md for the fine-grained PAT scopes.
#
# `owner` decides whose namespace the repository names in var.repositories resolve under. Null
# means the user the token belongs to, which is the personal-account case this root is built
# for; an organization name here would create the repositories there instead, and the
# collaborator roles in collaborators.tf would then gain their read-only and triage forms.
provider "github" {
  owner = var.github_owner # null -> the user the token belongs to
}
