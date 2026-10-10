# Week 2 · Day 2 — State CLI Operations

**Exam domain:** 1 (Resource Lifecycle — state management).

## Learning goals

1. Every `terraform state` subcommand: `list`, `show`, `mv`, `rm`, `pull`, `push`, `replace-provider`.
2. **State addressing** — the exact grammar for a resource in state: `module.x.module.y.aws_instance.z["key"]`.
3. When `state mv` is the right tool vs when a **`moved` block** is safer (hint: `moved` is declarative — survives across clones).
4. `state rm` + `import` to swap the cloud object behind a TF-managed resource.
5. `state replace-provider` for renamed forks or source URL changes.
6. Safely handle the `.terraform.tfstate.backup` file.

## Command cheat sheet

```bash
terraform state list                              # all addresses
terraform state list -id=<id>                     # find by cloud id
terraform state show aws_vpc.this                 # pretty-print one resource
terraform state mv aws_vpc.old aws_vpc.new        # rename in state (no cloud change)
terraform state mv aws_vpc.this module.net.aws_vpc.this  # move into a module
terraform state rm aws_vpc.this                   # forget, don't destroy
terraform state pull > state.json                 # download
terraform state push state.json                   # upload (DANGEROUS — verify serial first)
terraform state replace-provider hashicorp/aws registry.custom.io/mine/aws
```

**Golden rule:** always `terraform state pull > backup.json` before any destructive state op. Even with S3 versioning.

## `state mv` vs `moved` block

| Criterion | `terraform state mv` | `moved {}` block |
|---|---|---|
| Declarative | No — CLI-only | Yes — in code |
| Works in CI | No (manual step) | Yes (plan applies it) |
| Survives other clones/runners | No | Yes |
| Good for | Urgent fixes, local surgery | Any refactor that's going into the repo |

**Prefer `moved` for anything you'd commit.** CLI state mv is a fire extinguisher, not a carpenter's tool.

## Exercises

1. `terraform apply` the starter config. Then:
   - `terraform state list`
   - `terraform state show aws_subnet.public[0]`
2. Rename `aws_subnet.public` → `aws_subnet.front` in config. Plan shows destroy/create. Revert. Use `state mv aws_subnet.public[0] aws_subnet.front[0]` (and `[1]` and `[2]`) to avoid destroy. Now plan is clean.
3. Use a `moved` block instead: revert the rename, add
   ```hcl
   moved { from = aws_subnet.public  to = aws_subnet.front }
   ```
   — plan reports "has moved to" with no destroy.
4. `state rm aws_subnet.front[2]`, then re-apply — Terraform creates a new subnet, the original remains orphaned in AWS. Find and delete the orphan manually. Use this to understand the blast radius.
5. `state replace-provider` exercise — temporarily fork the `aws` source to a fake `registry.example.com/mine/aws`, replace, run `init` (will fail), then replace back.

## Self-check

1. You ran `terraform state rm aws_db_instance.prod` on production. What just happened to the database? What's the recovery?
2. You have a resource at `module.app.aws_instance.web[0]`. Write the full state mv to move it to a new module `module.app2.aws_instance.web` keyed by `"0"` under a `for_each`.
3. `terraform state pull | jq '.serial'` — what is the serial, and why do you care?
4. When would `replace-provider` be genuinely needed?

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Command cheat sheet
- state mv vs moved block

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
