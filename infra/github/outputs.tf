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

output "next_steps" {
  description = "What Terraform cannot do for you, in order."
  value       = <<-EOT
    1. Push the existing codebase (from the repository root):
         git remote add origin ${try(github_repository.this["thewayofthesurge"].ssh_clone_url, "<ssh_clone_url>")}
         git push -u origin main
    2. Set the account-level Actions token default to read-only (no Terraform resource for this):
         gh api -X PUT repos/{owner}/thewayofthesurge/actions/permissions/workflow \
           -f default_workflow_permissions=read -F can_approve_pull_request_reviews=false
    3. After the first CI run succeeds, if the account is on GitHub Pro:
         terraform apply -var enable_rulesets=true
    4. Configure SSH commit signing, upload the key as a *signing* key, then:
         terraform apply -var enable_rulesets=true -var require_signed_commits=true
  EOT
}
