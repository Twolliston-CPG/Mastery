# Authentication comes from the GITHUB_TOKEN environment variable. Never put a token in a
# .tf, .tfvars, or .auto.tfvars file; see README.md for the fine-grained PAT scopes.
provider "github" {
  owner = var.github_owner # null -> the user the token belongs to
}
