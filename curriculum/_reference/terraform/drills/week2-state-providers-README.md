# Week 2 — State, Lifecycle, Providers (Domains 1 & 5)

**Goal:** Fluency in state surgery, backend migration, importing existing infra, refactoring without destroy, and the provider plugin system. These are the highest-signal skills for the lab portion of the exam.

## Daily schedule

| Day | Topic | Folder |
|---|---|---|
| 1 | State fundamentals · local vs remote backends · S3+DynamoDB migration | `day1-state-backends/` |
| 2 | State CLI ops (`list`, `show`, `mv`, `rm`, `pull`, `push`, `replace-provider`) | `day2-state-ops/` |
| 3 | Importing existing infra — CLI `import` and `import {}` blocks · `-generate-config-out` | `day3-import/` |
| 4 | Refactoring — `moved` and `removed` blocks · safe renames · state retention | `day4-moved-removed/` |
| 5 | Provider plugin architecture · aliasing · version constraints · auth · troubleshooting | `day5-providers-deep-dive/` |
| 6 | Capstone — inherit undocumented infra, import, refactor, migrate backend | `day6-capstone/` |

## End-of-week gate

- [ ] Migrate state from local → S3+DynamoDB → HCP without losing a resource.
- [ ] Import an EC2 instance using both `terraform import` and an `import {}` block.
- [ ] Use `-generate-config-out` to scaffold HCL for an imported resource.
- [ ] Rename a resource inside a module without destroy/create.
- [ ] Remove a resource from state while keeping the cloud object alive.
- [ ] Upgrade provider major version and resolve the fallout.
- [ ] Enable `TF_LOG=TRACE` and find the HTTP request that failed.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Daily schedule
- End-of-week gate

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
