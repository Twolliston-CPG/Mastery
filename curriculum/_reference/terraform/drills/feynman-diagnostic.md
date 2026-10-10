# Diagnostic — 80-MCQ Calibration

**Purpose:** before burning study hours uniformly, measure where you actually stand per domain. Your weak domains get 3× the time; solid ones only get flashcard maintenance.

Takes ~90 min. Do it in one sitting, closed-book.

---

## Rules

1. **Closed book.** No `FLASHCARDS.md`, no `feynman/`, no Terraform docs. You may not scroll to the answer keys.
2. **One sitting, timer on.** 90 minutes for all 80. (The real exam is ~90s/question; this is slightly more generous since your repo MCQs are harder than average.)
3. **Write your answer for every question**, even if you're guessing. A wrong guess on something you thought you knew is more valuable than a blank — it reveals false confidence.
4. **Don't second-guess in pass 2.** After you finish, go back and mark any answer you weren't confident on (the "I think it's B but could be C" feeling) — that's the **uncertainty set**. These need teach-backs even if you got them right.

## Inputs

- `week4-cicd-mock/day4-mock-exam/mcq.md` — Q1–40
- `week4-cicd-mock/day4-mock-exam/mcq-extension.md` — Q41–60
- `week4-cicd-mock/day4-mock-exam/mcq-extension-2.md` — Q61–80

## Grading

After finishing, open the keys **one at a time, per file**:
- `answers/mcq-key.md` for Q1–40
- `answers/mcq-extension-key.md` for Q41–60
- `answers/mcq-extension-2-key.md` for Q61–80

Mark each row below with:
- `✓` correct and confident
- `~` correct but uncertain (the "lucky guess" — these need teach-backs)
- `✗` wrong

---

## Answer sheet + domain map

Each question is pre-tagged with the domain it primarily tests. When you tally, **count uncertain (`~`) and wrong (`✗`) together** as "needs work" — lucky guesses don't prove mastery.

### Q1–40 (mcq.md)

| Q | Domain | Topic | Your answer | Result |
|---|---|---|---|---|
| 1 | D1 | state migration (`-migrate-state`) | | |
| 2 | D5 | version constraint `~> 5.2` | | |
| 3 | D1 | `moved {}` block | | |
| 4 | D1 | `removed {}` block | | |
| 5 | D3 | backend can't reference `var.X` | | |
| 6 | D2 | `for_each` types | | |
| 7 | D2 | count→for_each for stable keys | | |
| 8 | D2 | `check` block semantics | | |
| 9 | D2 | `can()` function | | |
| 10 | X  | CloudFront ACM us-east-1 | | |
| 11 | D2 | `sensitive` redaction scope | | |
| 12 | D3 | `terraform_remote_state` + state sharing | | |
| 13 | D3 | `cloud {}` vs `backend "remote" {}` | | |
| 14 | D6 | HCP OIDC env vars | | |
| 15 | D6 | Sentinel soft-mandatory | | |
| 16 | D4 | registry module repo naming | | |
| 17 | D1 | `-detailed-exitcode` | | |
| 18 | D6 | HCP run workflow modes | | |
| 19 | D6 | agent pool for private network | | |
| 20 | D4 | `configuration_aliases` purpose | | |
| 21 | D3 | backend resolves before variables | | |
| 22 | D1 | CLI `terraform import` | | |
| 23 | D1 | `import {}` + `-generate-config-out` | | |
| 24 | D1 | `create_before_destroy` | | |
| 25 | D1 | `ignore_changes = all` | | |
| 26 | D3 | CLI vs HCP workspaces | | |
| 27 | D2 | `dynamic` iterator | | |
| 28 | D2 | postcondition timing | | |
| 29 | D5 | provider install order | | |
| 30 | D5 | commit lock file | | |
| 31 | D5 | `providers lock -platform` | | |
| 32 | D4 | `mock_provider` | | |
| 33 | D4 | `expect_failures` | | |
| 34 | D6 | run triggers | | |
| 35 | D1 | `-detailed-exitcode` in CI | | |
| 36 | D5 | provider alias selection | | |
| 37 | D1 | `terraform show -json` | | |
| 38 | D5 | AWS auth `assume_role`/OIDC | | |
| 39 | D1 | imported resource diff | | |
| 40 | D1 | `init -migrate-state` key change | | |

### Q41–60 (mcq-extension.md)

| Q | Domain | Topic | Your answer | Result |
|---|---|---|---|---|
| 41 | D2 | `try()` for unreachable data | | |
| 42 | D4 | caller's `providers = {}` block | | |
| 43 | D2 | sensitive vs `state show` | | |
| 44 | D3 | `remote_state` auth in HCP | | |
| 45 | D6 | var set vs workspace var precedence | | |
| 46 | D1 | `-replace` semantics | | |
| 47 | D1 | `ignore_changes = [tags]` | | |
| 48 | D5 | multi-platform lock file | | |
| 49 | D1 | `terraform taint` deprecated | | |
| 50 | D1 | `removed {}` for prod DB | | |
| 51 | D5 | `providers lock` platform scope | | |
| 52 | D5 | CI checksum mismatch fix | | |
| 53 | D1 | `terraform output -json` | | |
| 54 | D6 | Run Task phases | | |
| 55 | D4 | `configuration_aliases` w/o caller providers | | |
| 56 | D6 | hard-mandatory Sentinel override | | |
| 57 | D6 | agent execution mode | | |
| 58 | D2 | `terraform console` + `split` | | |
| 59 | D3 | envs/dev/prd vs `terraform.workspace` | | |
| 60 | D2 | `default = null` semantics | | |

### Q61–80 (mcq-extension-2.md)

| Q | Domain | Topic | Your answer | Result |
|---|---|---|---|---|
| 61 | D3 | `-reconfigure` vs `-migrate-state` | | |
| 62 | D1 | resource timeout behavior | | |
| 63 | D3 | CLI workspace S3 path scheme | | |
| 64 | D2 | `for_each` + `count` conflict | | |
| 65 | D3 | `init -backend=false` | | |
| 66 | D1 | `plan -out` + `show -json` | | |
| 67 | D5 | "inconsistent final plan" | | |
| 68 | D5 | version intersection | | |
| 69 | D2 | `random_password` reference | | |
| 70 | D3 | `remote_state` with local backend | | |
| 71 | D2 | conditional type error | | |
| 72 | D1 | `moved` block lifecycle | | |
| 73 | X  | Vault short-lived AWS creds | | |
| 74 | D1 | `-target` with for_each syntax | | |
| 75 | D1 | `apply -refresh-only` | | |
| 76 | X  | `TF_CLI_ARGS_plan` | | |
| 77 | D1 | `terraform output` default | | |
| 78 | D2 | conditional resource pattern | | |
| 79 | D6 | HCP project vs org | | |
| 80 | D2 | count→for_each with `moved` | | |

---

## Per-domain score

Fill in after grading. **"Needs work"** = count of `~` + `✗` in that domain.

| Domain | Total Qs | Correct (`✓`) | Needs work (`~` + `✗`) | % solid | Priority |
|---|---|---|---|---|---|
| D1 — Resource Lifecycle | 23 | | | | |
| D2 — Dynamic Config | 16 | | | | |
| D3 — Collab Workflows | 11 | | | | |
| D4 — Modules | 6 | | | | |
| D5 — Providers | 11 | | | | |
| D6 — HCP Terraform | 10 | | | | |
| X — Cross-cutting | 3 | | | | |
| **Total** | **80** | | | | — |

**Priority rule:**
- **High** — `% solid < 60%` in that domain. Teach-backs for every "needs work" question, then redo the lab.
- **Medium** — `60–80% solid`. Teach-backs for each `~` and `✗`. Skip flashcards you already know.
- **Low** — `>80% solid`. Flashcard maintenance only. Revisit if you miss on the retest.

---

## Output of the diagnostic

After grading, do three things:

1. **Tag tracker rows.** Every `~` or `✗` question's topic goes `[ ]` shaky in `00-mastery-tracker.md`. Every `✓` goes `[~]` okay (not solid — one right answer isn't mastery yet). Record evidence as `diagnostic: Q<n> correct` or `diagnostic: Q<n> missed`.
2. **Seed `gaps-log.md`.** One entry per `✗`. Use the structured template.
3. **Queue work.** List domains in priority order. That's the teach-back sequence for the next N sessions.

Then we start session 1 with your highest-priority domain.

---

## Retest

Plan to retake this diagnostic 10 days after the first pass, on the same 80 questions. Target: **≥ 90% solid across all domains**. The delta between passes is the real measure of mastery — not the absolute score on either.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Rules
- Inputs
- Answer sheet + domain map
- Per-domain score

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
