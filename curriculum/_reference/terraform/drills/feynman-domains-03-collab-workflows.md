# Domain 3 — Collaborative Workflows (the Teacher's Voice)

---

## 1. Partial backend config

**Simply:** `backend {}` blocks can't reference variables — backends resolve before Terraform has evaluated any expressions. Partial config lets you commit the bare skeleton and supply the rest at init.

```hcl
# backend.tf (committed)
terraform {
  backend "s3" {}
}

# init:
terraform init \
  -backend-config="bucket=tf-state-acme" \
  -backend-config="key=prod/vpc.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=tf-lock"
```

**Analogy:** You file an apartment lease with blanks. The landlord fills rent/address when signing — but there's only one lease template in the cabinet.

**Gotcha:** `-backend-config=file.hcl` also works. Don't mix CLI flags and `.hcl` casually — last one wins silently.

**Self-test:** Why can't `bucket = var.state_bucket` work directly in the backend block?

**Lab:** `week2/day1-state-backends`

---

## 2. `terraform_remote_state` — consume one workspace's outputs from another

```hcl
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "tf-state-acme"
    key    = "prod/vpc.tfstate"
    region = "us-east-1"
  }
}

resource "aws_instance" "app" {
  subnet_id = data.terraform_remote_state.network.outputs.private_subnet_ids[0]
}
```

**Gotcha:** The producer must `output` the field (outputs are the only thing remote_state can read). On HCP, the producer must explicitly list the consumer in **state sharing** settings.

**Self-test:** Workspace A has `output "vpc_id"`. Workspace B tries `data.terraform_remote_state.a.outputs.vpc_id` and gets permission denied. What's missing on A?

**Lab:** `week4/day4-mock-exam` scenario 4

---

## 3. `cloud {}` vs `backend "remote" {}`

- `cloud {}` — newer, HCP Terraform / Terraform Enterprise only. Supports tag-based workspace selection, agent pools, config beyond remote backend.
- `backend "remote" {}` — older. Still works but can't do tag selection.

**They are mutually exclusive in one config.**

```hcl
terraform {
  cloud {
    organization = "acme"
    workspaces { tags = ["prod", "vpc"] }
  }
}
```

**Gotcha:** A config with *both* errors out at init. Migrate old `backend "remote"` configs by replacing the block — state auto-migrates on `init`.

**Self-test:** What does `workspaces { name = "foo" }` vs `workspaces { tags = ["foo","bar"] }` do differently?

**Lab:** `week3/day1-hcp-fundamentals`

---

## 4. Workspaces — CLI workspaces vs HCP workspaces

CLI workspaces (`terraform workspace new`) share a backend, separate state *files*. Cheap env separation but same config.

HCP workspaces are full entities: their own config, variables, run history, and RBAC. Distinct.

**Gotcha:** `terraform.workspace` works in both, but in HCP multi-workspace (tag mode) you select with `terraform workspace select <name>` before running — there's no default.

**Self-test:** You use CLI `workspace new stg`. Which file changes in your S3 backend?

---

## 5. Run workflows — the three HCP modes

| Mode | Trigger | Speculative plan? | Apply? |
|---|---|---|---|
| CLI-driven | `terraform apply` locally | No | Yes |
| VCS-driven | PR / push | Yes on PR | Yes on merge |
| API-driven | POST to `/runs` | Configurable | Configurable |

**Analogy:** CLI = driving yourself. VCS = GitHub pulls the trigger. API = a scheduler or CI tool drives it.

**Gotcha:** Speculative plans fire on every PR against the tracked branch and can't apply — they're a preview. Once merged, a real plan runs and can apply.

**Self-test:** A team wants every PR to show an HCP plan in the PR comments but nothing else. Which mode, and what do they configure?

**Lab:** `week3/day2-run-workflows`

---

## 6. Provider lock file — `-platform` for multi-OS teams

```bash
terraform providers lock \
  -platform=linux_amd64 \
  -platform=darwin_arm64 \
  -platform=windows_amd64
```

**Why:** Lock file records checksums per-platform. Without multi-platform generation, a teammate on a different OS will fail init on checksum mismatch.

**Gotcha:** Commit `.terraform.lock.hcl`. Bump with `terraform init -upgrade`. Don't `.gitignore` it.

**Self-test:** A Mac dev commits the lockfile. Linux CI fails init with "checksum missing." Fix?

---

## Flashcards

Domain 3 in `/FLASHCARDS.md` — 6 cards.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Partial backend config
- terraformremotestate — consume one workspace's outputs from another
- cloud {} vs backend "remote" {}
- Workspaces — CLI workspaces vs HCP workspaces

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
