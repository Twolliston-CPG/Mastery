# Outputs are for the human running the apply from a laptop; nothing else reads this state.

# Consumed by the first push (`git remote add origin <ssh_clone_url>`) and by the README's
# status line. node_id is the GraphQL id, handy for `gh api graphql` queries about the repository.
output "repositories" {
  description = "Clone URLs and metadata for every managed repository."
  value = {
    for name, repo in github_repository.this : name => {
      html_url       = repo.html_url
      ssh_clone_url  = repo.ssh_clone_url
      http_clone_url = repo.http_clone_url
      visibility     = repo.visibility
      node_id        = repo.node_id
    }
  }
}

# Printed after every apply as the checklist of what Terraform cannot do: the push itself, the
# account-level token default (no provider resource for it), and the two opt-in flags in the
# order their preconditions are met. The try() keeps the output valid on a plan where the
# repository does not exist yet.
output "next_steps" {
  description = "What Terraform cannot do for you, in order."
  value       = <<-EOT
    1. Push the existing codebase (from the repository root):
         git remote add origin ${try(github_repository.this["twots"].ssh_clone_url, "<ssh_clone_url>")}
         git push -u origin main
    2. Set the account-level Actions token default to read-only (no Terraform resource for this):
         gh api -X PUT repos/{owner}/twots/actions/permissions/workflow \
           -f default_workflow_permissions=read -F can_approve_pull_request_reviews=false
    3. After the ci and security workflows have each run green, if the account is on GitHub Pro:
         set required_status_checks in terraform.tfvars to the full list in terraform.tfvars.example, then
         terraform apply -var enable_rulesets=true
    4. Configure SSH commit signing, upload the key as a *signing* key, then:
         terraform apply -var enable_rulesets=true -var require_signed_commits=true
  EOT
}
