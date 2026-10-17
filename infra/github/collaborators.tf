# Who has access, as code.
#
# On a personal account every collaborator has write access: there is no read-only or triage
# role. Write means push to any unprotected branch, approve pull requests, and merge them. That
# is why the review gate in rulesets.tf exists, and why the list of people who hold write access
# belongs in a diff and not only in a settings page.
#
# This resource is AUTHORITATIVE: anyone with access who is not in var.collaborators is removed
# on apply. It is therefore off by default. To adopt the current list rather than overwrite it:
#   1. gh api repos/<owner>/<repo>/collaborators --jq '.[] | "\(.login) \(.role_name)"'
#   2. put every login except the owner into var.collaborators in terraform.tfvars (gitignored)
#   3. terraform import 'github_repository_collaborators.this["<repo>"]' <repo>
#   4. set manage_collaborators = true and confirm the plan shows no changes
# After that, adding or removing a person is a one-line change, reviewed like any other.
resource "github_repository_collaborators" "this" {
  for_each = var.manage_collaborators ? github_repository.this : {}

  repository = each.value.name

  dynamic "user" {
    for_each = var.collaborators
    content {
      username   = user.key
      permission = user.value
    }
  }
}
