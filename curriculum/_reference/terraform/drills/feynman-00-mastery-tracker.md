# Mastery Tracker

Confidence key:
- `[ ]` **shaky** — can't explain cold, missed flashcard/MCQ, or haven't tried
- `[~]` **okay** — explain with a reference open, some gaps
- `[x]` **solid** — explain cold, pass self-test, apply unprompted in a lab

**Evidence column** — a row promoted to `[~]` or `[x]` must cite proof. Accepted forms:
- `teach-back: <file.md>` — you wrote a clean explanation
- `lab: <path> clean` — the lab validates/plans cleanly and you ran it without peeking
- `diagnostic: Q<n> correct` — you got the MCQ right closed-book
- `capstone: <name>` — rebuilt the capstone without the solutions folder

No evidence = no promotion. A promoted row with no evidence is a lie to your future self.

Update after every teach-back or flashcard session. Date format: `YYYY-MM-DD`.

---

## Domain 1 — Resource Lifecycle (Week 2)

| Topic | Confidence | Last reviewed | Linked lab | Evidence |
|---|---|---|---|---|
| State backends (S3 + DynamoDB lock) | `[ ]` | — | `week2/day1-state-backends` | — |
| State CLI ops (list, show, mv, rm, pull, push, replace-provider) | `[ ]` | — | `week2/day2-state-ops` | — |
| Import (CLI + `import {}` + `-generate-config-out`) | `[ ]` | — | `week2/day3-import` | — |
| `moved {}` vs `removed {}` blocks | `[ ]` | — | `week2/day4-moved-removed` | — |
| `-detailed-exitcode` CI gating | `[ ]` | — | `week4/day2-cicd-gha` | — |
| Forcing replacement (`-replace`, `replace_triggered_by`) | `[ ]` | — | `week1/day2-foreach-dynamic-meta` | — |
| `-refresh-only` vs normal plan | `[ ]` | — | `week2/day2-state-ops` | — |
| `force-unlock` safety | `[ ]` | — | `week2/day1-state-backends` | — |

## Domain 2 — Dynamic Configuration (Week 1)

| Topic | Confidence | Last reviewed | Linked lab | Evidence |
|---|---|---|---|---|
| Variable types + `optional()` + `validation` | `[ ]` | — | `week1/day1-types-validation` | — |
| Precondition vs postcondition vs `check` block | `[ ]` | — | `week1/day1-types-validation` | — |
| `for_each` safe keys (plan-time vs apply-time) | `[ ]` | — | `week1/day2-foreach-dynamic-meta` | — |
| `dynamic` blocks | `[ ]` | — | `week1/day2-foreach-dynamic-meta` | — |
| `for` expressions (list / map / grouping `...`) | `[ ]` | — | `week1/day3-functions-expressions` | — |
| `templatefile` + directives (`%{~}`, `%{if}`) | `[ ]` | — | `week1/day3-functions-expressions` | — |
| `can()` vs `try()` | `[ ]` | — | `week1/day1-types-validation` | — |
| `sensitive` vs `ephemeral` | `[ ]` | — | `week4/day1-sensitive-vault` | — |

## Domain 3 — Collaborative Workflows (Weeks 2–3)

| Topic | Confidence | Last reviewed | Linked lab | Evidence |
|---|---|---|---|---|
| Partial backend config + `-backend-config` | `[ ]` | — | `week2/day1-state-backends` | — |
| `terraform_remote_state` + state sharing | `[ ]` | — | `week4/day4-mock-exam` scenario 4 | — |
| `cloud {}` vs `backend "remote" {}` | `[ ]` | — | `week3/day1-hcp-fundamentals` | — |
| Workspace selection (`name` vs `tags`) | `[ ]` | — | `week3/day1-hcp-fundamentals` | — |
| Run workflows (CLI / VCS / API) | `[ ]` | — | `week3/day2-run-workflows` | — |
| Provider lock file multi-platform | `[ ]` | — | `week2/day5-providers-deep-dive` | — |

## Domain 4 — Modules (Week 1)

| Topic | Confidence | Last reviewed | Linked lab | Evidence |
|---|---|---|---|---|
| Idiomatic layout (main/variables/outputs/versions/README) | `[ ]` | — | `week1/day4-module-design` | — |
| `configuration_aliases` + provider pass-through | `[ ]` | — | `week1/day4-module-design` | — |
| Module source types (local / git / registry / HCP / S3) | `[ ]` | — | `week1/day4-module-design` | — |
| `moved {}` for refactor without destroy | `[ ]` | — | `week1/day4-module-design` | — |
| `for_each` on modules (1.2+) | `[ ]` | — | `week1/day4-module-design` | — |
| `terraform test` + `mock_provider` + `expect_failures` | `[ ]` | — | `week1/day5-terraform-test` | — |
| Version pinning (`~>` semantics) | `[ ]` | — | `week1/day4-module-design` | — |

## Domain 5 — Providers (Week 2)

| Topic | Confidence | Last reviewed | Linked lab | Evidence |
|---|---|---|---|---|
| Version constraints (`~> 5.2` vs `~> 5.2.3`) | `[ ]` | — | `week2/day5-providers-deep-dive` | — |
| Lock file (`.terraform.lock.hcl`) — commit / `init -upgrade` | `[ ]` | — | `week2/day5-providers-deep-dive` | — |
| AWS auth (profile, `assume_role`, OIDC) | `[ ]` | — | `week2/day5-providers-deep-dive` | — |
| Provider aliases (multi-region / multi-account) | `[ ]` | — | `week1/day4-module-design` | — |
| `TF_LOG` debugging | `[ ]` | — | `week4/day3-troubleshooting` | — |
| `terraform providers schema -json` | `[ ]` | — | `week2/day5-providers-deep-dive` | — |

## Domain 6 — HCP Terraform (Week 3)

| Topic | Confidence | Last reviewed | Linked lab | Evidence |
|---|---|---|---|---|
| Organizations / projects / workspaces | `[ ]` | — | `week3/day1-hcp-fundamentals` | — |
| Speculative plan on PR | `[ ]` | — | `week3/day2-run-workflows` | — |
| Variable sets + precedence | `[ ]` | — | `week3/day3-varsets-oidc` | — |
| OIDC dynamic AWS credentials | `[ ]` | — | `week3/day3-varsets-oidc` | — |
| Private registry + no-code modules | `[ ]` | — | `week3/day4-private-registry` | — |
| Sentinel levels (advisory / soft / hard) + OPA | `[ ]` | — | `week3/day5-sentinel-opa` | — |
| Run tasks + agent execution | `[ ]` | — | `week3/day2-run-workflows` | — |
| State sharing + run triggers | `[ ]` | — | `week3/day6-capstone` | — |

## Cross-cutting

| Topic | Confidence | Last reviewed | Linked lab | Evidence |
|---|---|---|---|---|
| Vault provider + `vault_kv_secret_v2` | `[ ]` | — | `week4/day1-sensitive-vault` | — |
| GitHub Actions plan → apply pipeline | `[ ]` | — | `week4/day2-cicd-gha` | — |
| Troubleshooting playbook (TF_LOG flow) | `[ ]` | — | `week4/day3-troubleshooting` | — |

## Capstones & Scenarios (the real gates)

| Artifact | Status | Date | Evidence |
|---|---|---|---|
| Week 1 capstone — `static_site` module | `[ ]` | — | — |
| Week 2 capstone — state/import/refactor | `[ ]` | — | — |
| Week 3 capstone — HCP OIDC + Sentinel end-to-end | `[ ]` | — | — |
| Mock scenario 1 — state migration | `[ ]` | — | — |
| Mock scenario 2 — import & refactor | `[ ]` | — | — |
| Mock scenario 3 — SG factory module + tests | `[ ]` | — | — |
| Mock scenario 4 — `terraform_remote_state` | `[ ]` | — | — |
| Mock scenario 5 — policy-gated run | `[ ]` | — | — |
| Mock scenario 6 — troubleshooting | `[ ]` | — | — |

Capstone status key:
- `[ ]` not attempted
- `[~]` attempted with solution peek
- `[x]` rebuilt from scratch, plan-clean, zero peeks

---

## Target — definition of done

By **2026-05-18**:
- ≥ 90% on all 80 MCQs closed-book (all three files: mcq.md, mcq-extension.md, mcq-extension-2.md)
- All 6 mock scenarios solved without looking at answers/solutions/
- Every tracker row at `[~]` or `[x]` with evidence
- All 3 capstones at `[x]`

---

## Weekly rollup

Copy this block at the end of each study week to make trend visible.

```
Week of YYYY-MM-DD
  Solid:   <count>
  Okay:    <count>
  Shaky:   <count>
  Demoted (appeared twice in gaps-log): <topic list>
  Capstones completed: <list>
```

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Domain 1 — Resource Lifecycle (Week 2)
- Domain 2 — Dynamic Configuration (Week 1)
- Domain 3 — Collaborative Workflows (Weeks 2–3)
- Domain 4 — Modules (Week 1)

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
