# Week 3 · Day 1 — HCP Terraform Fundamentals

**Exam domain:** 6 (HCP Terraform collaboration).

## Learning goals

1. Understand the HCP object hierarchy: **Organization → Project → Workspace**.
2. Know what a **workspace** holds: code source, variables, state, runs, policies, notifications.
3. The **`cloud {}`** block — replacement for `backend "remote" {}`.
4. Three ways to connect a workspace to Terraform code: **CLI, VCS, API** (Day 2 drills).
5. **Execution modes**: `remote` (default — runs on HCP), `local` (HCP only stores state, runs happen on your machine), `agent` (runs on self-hosted agents).
6. **Workspace permissions**: read, plan, write, admin; custom project permissions.
7. **State sharing between workspaces** via `terraform_remote_state` data source.

## `cloud {}` block vs `backend "remote" {}`

Both work. New syntax (1.1+):

```hcl
terraform {
  cloud {
    organization = "my-org"
    hostname     = "app.terraform.io"   # default; set for TFE self-hosted

    workspaces {
      name = "dev"
      # OR
      # tags = ["aws", "dev"]    # workspace set — match-all
    }
  }
}
```

- `name` → single workspace.
- `tags` → multiple workspaces, run `terraform workspace select <name>` locally.
- You **cannot** have a `cloud {}` block *and* a `backend {}` block — pick one.

## Execution modes

| Mode | Where runs execute | Where state lives | When to use |
|---|---|---|---|
| **Remote** (default) | HCP runners | HCP | 95% of cases |
| **Local** | Your machine/CI | HCP | Air-gapped providers, local tools in pipeline |
| **Agent** | Self-hosted agent | HCP | Private networks, VPN-only providers |

## Sharing state — `terraform_remote_state`

From a *consumer* workspace, read outputs of a *producer* workspace:

```hcl
data "terraform_remote_state" "network" {
  backend = "remote"
  config = {
    organization = "my-org"
    workspaces = { name = "network-dev" }
  }
}

resource "aws_instance" "app" {
  subnet_id = data.terraform_remote_state.network.outputs.public_subnet_ids[0]
}
```

- The consumer must have **state sharing** enabled on the producer workspace (workspace settings → remote state sharing → allow specific workspaces).

## Exercises

1. Sign up + `terraform login`.
2. Create an organization (free tier).
3. Create a project `tfpro-study` and two workspaces in it: `fundamentals-dev`, `fundamentals-stg`.
4. Use the skeleton in this folder. Edit `terraform.tf` — set `organization` to yours. Edit `terraform.tfvars` as needed.
5. `terraform init` → it prompts to upload to HCP → `terraform plan` runs remotely.
6. Open the workspace in the HCP UI — inspect the run details.
7. In the UI, enable state sharing for `fundamentals-dev` toward `fundamentals-stg`.
8. Add a `terraform_remote_state` data source to a local test to read `fundamentals-dev`'s outputs.

## Self-check

1. When would you use `tags = [...]` instead of `name = "..."` in the `workspaces` block?
2. Execution mode = `local`, state mode = remote. What runs where?
3. Two workspaces in the *same* organization — can one read the other's outputs by default? What setting governs it?
4. You have a `cloud {}` block and accidentally added `backend "s3"`. What happens on `terraform init`?

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- cloud {} block vs backend "remote" {}
- Execution modes
- Sharing state — terraformremotestate

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"Terraform manages your infrastructure."* |
| ✓ | *"`plan` is a three-way comparison: the configuration (desired), the state file (what Terraform believes it created), and a refresh against the real API (what exists). Almost every confusing result is one of those three drifting from the other two."* |

**Trace it:** `terraform apply` on one resource: config → plan → API call → state write. Then say what happens if the process dies between the API call and the state write.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** [the purpose of Terraform state](https://developer.hashicorp.com/terraform/language/state/purpose) — almost every confusing result is a three-way disagreement, spelled out there.
Full list per domain: [`SOURCES.md`](../../SOURCES.md#terraform)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../../MASTERY.md)

<!-- /feynman-check -->
