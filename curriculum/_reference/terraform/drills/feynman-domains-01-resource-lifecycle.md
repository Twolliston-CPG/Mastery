# Domain 1 — Resource Lifecycle (the Teacher's Voice)

Read this, close it, then write a teach-back in your own words.

---

## 1. State is the ledger

**Simply:** Terraform's state file is a JSON ledger mapping every resource in your config to the cloud object it created (IDs, generated fields, provider metadata). No state = Terraform doesn't know what it owns.

**Analogy:** A bank's ledger. The dollars live in the vault (AWS). The ledger says who owns which dollar. If you burn the ledger, the money still exists — but the bank can't prove who owns what. Restoring from a backup vs. counting every coin again = restoring state vs. re-importing every resource.

**Gotcha:** State is plaintext and contains secrets. Never commit it. Always remote backend in team settings.

**Self-test:** Name three things in state that aren't in your `.tf` config.

**Lab:** `week2/day1-state-backends`

---

## 2. S3 + DynamoDB backend

**Simply:** S3 stores the ledger file. DynamoDB stores a lock row while anyone's applying, so two people can't run `apply` simultaneously.

**Analogy:** The conch shell in *Lord of the Flies*. Whoever holds it speaks. DynamoDB is the conch.

**Gotcha:** The lock row key is `<bucket>/<key>-md5`. If apply dies ungracefully the lock is stranded — `terraform force-unlock <LOCK_ID>` — but *never* if a real apply is running, you'll corrupt state.

**Self-test:** You inherit a workspace and want to move from local state to S3+DynamoDB. What's the single command?

**Lab:** `week2/day1-state-backends`

---

## 3. State CLI ops

| Command | Effect |
|---|---|
| `terraform state list` | All addresses in state |
| `terraform state show <addr>` | Full attrs of one resource |
| `terraform state mv <src> <dst>` | Rename/relocate in state only (config must match) |
| `terraform state rm <addr>` | Forget (cloud object survives) |
| `terraform state pull` / `push` | Download / upload state JSON |
| `terraform state replace-provider` | Swap `hashicorp/aws` → `my-fork/aws` everywhere |

**Analogy:** `state rm` is unassigning an employee's desk — they still work here, just not in that cube. `destroy` is firing them.

**Gotcha:** Prefer `moved {}` blocks in config over `state mv`. Blocks survive in git; CLI moves are invisible afterwards.

**Self-test:** You ran `terraform state rm aws_db_instance.prod` by accident. What's actually gone, and how do you get it back?

**Lab:** `week2/day2-state-ops`

---

## 4. Import — three flavors (since 1.5)

1. **CLI:** `terraform import aws_instance.web i-abc123` — old way, one at a time.
2. **`import {}` block:** declarative, gets committed, plan shows the import.
3. **`import {}` + `-generate-config-out=gen.tf`:** writes the `resource` block for you. Review and refine before apply.

**Analogy:** Adoption paperwork. The child (cloud resource) exists; you're just officially bringing them into your family (state).

**Gotcha:** Import matches by ID, but the resource block *must* already exist (or be generated). Mismatched attrs will plan destructive drift on the next run — especially write-only fields like RDS passwords (state can't know the real value).

**Self-test:** Why does an imported `aws_db_instance` often plan to change `password`? What two fixes?

**Lab:** `week2/day3-import`

---

## 5. `moved {}` vs `removed {}` — refactor without fireworks

- **`moved { from = ... to = ... }`** — "this resource got a new address." No destroy. Works across renames, module extraction, `for_each` conversions.
- **`removed { from = ... lifecycle { destroy = false } }`** — "stop managing this; don't nuke it." Replaces the old workflow of deleting the block + `state rm`.

**Analogy:** `moved` is forwarding mail. `removed` is retiring: the employee stays, payroll stops.

**Gotcha:** `moved` can't cross state files. If the resource is going to a different root module, use `terraform state rm` on one side and `terraform import` on the other.

**Self-test:** You lift a VPC out of root into `module.network`. What goes in the `moved` block's `from` and `to`?

**Lab:** `week2/day4-moved-removed`

---

## 6. Forcing replacement

- `terraform apply -replace=aws_instance.web` — one-off; no code change.
- `replace_triggered_by = [aws_launch_template.web.latest_version]` — declarative; replace me whenever this ref changes.

**Gotcha:** `replace_triggered_by` takes a reference expression, **not a string**. `"aws_launch_template.web.id"` will error.

**Self-test:** Production ASG needs new AMI every deploy without editing the instance block. What argument + what goes in it?

---

## 7. Plan semantics — the two you'll be tested on

- `terraform plan -detailed-exitcode` → `0` no changes, `1` error, `2` changes. CI gate.
- `terraform plan -refresh-only` — updates state from reality, does *not* propose changes.

**Analogy:** `-refresh-only` is checking Zillow for your house's value; normal plan is deciding whether to renovate.

**Self-test:** A teammate bumped the RDS instance class in the AWS console. How do you get state in sync without renaming or destroying anything?

---

## Flashcards to drill after reading

Domain 1 in `/FLASHCARDS.md` — all 9 cards. If you miss any, write to `gaps-log.md` before moving on.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- State is the ledger
- S3 + DynamoDB backend
- State CLI ops
- Import — three flavors (since 1.5)

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
