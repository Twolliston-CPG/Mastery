# Common Confusions — the X vs Y Tables

HashiCorp writes trick questions around near-twins. Memorize the differences cold.

---

## 1. `moved` vs `removed` vs `import` vs `state mv`

| | Purpose | Cloud object | State | Config edit |
|---|---|---|---|---|
| `moved {}` block | rename address, no destroy | untouched | re-addressed | yes (block) |
| `removed {}` block | stop managing, keep cloud object | untouched | removed | yes (block + delete resource) |
| `terraform import` / `import {}` | start managing existing cloud object | untouched | added | yes (resource) |
| `terraform state mv` | same as `moved`, via CLI | untouched | re-addressed | no |
| `terraform state rm` | same as `removed`, via CLI | untouched | removed | no |
| `terraform destroy` | delete cloud object | **destroyed** | removed | no |

**Trap:** exam may ask "how to stop managing a resource without deleting it" — answer is `removed {}` (modern) or `state rm` (CLI). Not `destroy`, not `moved`.

---

## 2. `sensitive` vs `ephemeral`

| | In state? | In plan output? | In logs? | Use for |
|---|---|---|---|---|
| `sensitive = true` | **Yes** (plaintext) | Redacted | Redacted | Passwords, long-lived secrets where you accept state-level storage |
| `ephemeral = true` (1.10+) | **No** | Not present | Not present | Short-lived tokens, Vault leases, one-run-only credentials |

---

## 3. `cloud {}` vs `backend "remote" {}`

| | Supports tag-based workspace selection | Agent pool support | Recommended today | Coexist? |
|---|---|---|---|---|
| `cloud {}` | Yes | Yes | Yes | No |
| `backend "remote" {}` | No (name only) | Partial | Legacy | No |

**Mutually exclusive** — both in same config = init error.

---

## 4. CLI workspaces vs HCP workspaces

| | Same config? | Separate state? | Separate variables? | Separate RBAC? |
|---|---|---|---|---|
| CLI workspaces | Yes | Yes (same backend, different keys) | No | No |
| HCP workspaces | No (each has its own) | Yes | Yes | Yes |

**Trap:** "What separates a dev and prod workspace in HCP?" — not just state; variables and RBAC too.

---

## 5. `validation` vs `precondition` vs `postcondition` vs `check`

| Block | Lives in | Runs when | Can reference resources | Blocks run |
|---|---|---|---|---|
| `validation` | `variable` | Parse | No — only the variable | Yes |
| `precondition` | `resource.lifecycle` / `data.lifecycle` / `output` | Plan | Yes | Yes |
| `postcondition` | same | Apply (post-create/read) | Yes | Yes |
| `check` | top-level | Plan + apply | Yes | **No — warning only** |

---

## 6. `can()` vs `try()`

| | Returns | Use in |
|---|---|---|
| `can(expr)` | `bool` | `validation.condition`, `precondition.condition` |
| `try(e1, e2, ...)` | first successful expr | Fallback defaults, optional field lookups |

---

## 7. `count` vs `for_each` on resources & modules

| | Address style | Stable under reorder | Requires | Since (for modules) |
|---|---|---|---|---|
| `count` | `res[0]`, `res[1]` | No | integer | always |
| `for_each` | `res["dev"]`, `res["prd"]` | Yes | set(string) or map(any), keys known at plan | 1.2 |

**Converting count → for_each needs `moved` blocks for every instance.**

---

## 8. `terraform_remote_state` vs data source vs direct output

You need data from workspace A in workspace B:

| Approach | When |
|---|---|
| `data "terraform_remote_state"` | A and B are sibling TF workspaces sharing outputs |
| A native data source (e.g. `data "aws_vpc"`) | Just looking up a cloud resource by tag/name; no TF workspace involved |
| Root module passing outputs as variables | A and B are in the same TF root |

**Trap:** remote_state can only read **outputs**. It cannot reach into resources directly.

---

## 9. `~> 5.2` vs `~> 5.2.3` vs `>= 5.2, < 6.0`

| Constraint | Range | Locks |
|---|---|---|
| `~> 5.2` | `>= 5.2, < 6.0` | Major |
| `~> 5.2.3` | `>= 5.2.3, < 5.3.0` | Minor |
| `>= 5.2, < 6.0` | explicit | Same as `~> 5.2` but verbose |
| `5.2.3` | exactly | Pinned |

---

## 10. Sentinel enforcement levels

| Level | Blocks? | Override? |
|---|---|---|
| `advisory` | No | — |
| `soft-mandatory` | Yes | Org admins can override in UI |
| `hard-mandatory` | Yes | **Nobody** |

---

## 11. HCP variable precedence (low → high)

1. Variable set default (non-priority)
2. Workspace variable
3. `.auto.tfvars` / `terraform.tfvars` in repo
4. CLI `-var` / `-var-file`
5. **Priority variable set** (flips to top)

**Trap:** A priority var set overrides even workspace vars — intentional for org-mandated values.

---

## 12. Provider source strings

| Source | Means |
|---|---|
| `terraform-aws-modules/vpc/aws` | **Public** registry, module |
| `app.terraform.io/acme/vpc/aws` | **Private** (HCP) registry, module |
| `hashicorp/aws` | Provider — in `required_providers.source` |
| `registry.terraform.io/hashicorp/aws` | Same thing, fully qualified |

---

## 13. `-replace` vs `replace_triggered_by` vs taint (legacy)

| Method | Declarative? | Scope |
|---|---|---|
| `terraform apply -replace=addr` | No | One run |
| `replace_triggered_by = [ref]` | Yes | Auto-replace whenever `ref` changes |
| `terraform taint` / `untaint` | No | Deprecated; use `-replace` |

**Trap:** `replace_triggered_by` takes a **reference**, not a string. `"aws_x.y.id"` is wrong; `aws_x.y.id` (no quotes) is right.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- moved vs removed vs import vs state mv
- sensitive vs ephemeral
- cloud {} vs backend "remote" {}
- CLI workspaces vs HCP workspaces

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
