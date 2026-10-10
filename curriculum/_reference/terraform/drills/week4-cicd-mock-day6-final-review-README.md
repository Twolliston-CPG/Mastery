# Week 4 · Day 6 — Final Review & Exam Day

## The night before

- Early light dinner. No cramming past 8pm — you retain more from sleep than the last hour of review.
- Re-skim the 4 README "self-check" sections across weeks. If any answer doesn't come fluently, star it.
- Verify exam logistics: booking time, ID ready, proctor software installed.
- Charger plugged in. Phone on silent.

## Morning of

- Normal breakfast.
- **30-min warm-up:** rebuild from scratch:
  - A variable with `object({...optional(...)...})` and 2 `validation` blocks.
  - A resource with `for_each` over a `map(object)` and a nested `dynamic` block.
  - A `.tftest.hcl` with `mock_provider` and `expect_failures`.
  If any feels rusty, do the flash cards for that domain for 10 minutes.

## During the exam

- **Read the whole lab scenario first.** Don't start typing until you know the target state.
- **Watch the clock.** 4 hours / 12 questions = ~20 min each. Flag and skip if stuck past 25.
- **Never destroy without a snapshot.** `terraform state pull > backup.json` first.
- **Run `validate` and `plan` constantly.** Never write 50 lines then hit enter.
- Use the 15-min break — actually take it. Stretch, hydrate.
- Check outputs carefully — many questions grade on output correctness.

## Traps on exam day

- CloudFront cert must be in **us-east-1** — you'll lose time if you forget.
- `backend` blocks **cannot use variables** — use `-backend-config`.
- `for_each` with attribute-derived keys → not known at plan time → error.
- `moved` blocks require the `from` to have been there, `to` to be the current config.
- Policies at `hard-mandatory` cannot be overridden — match the enforcement to the scenario.

## After

- Breathe. Whatever the result, you'll have learned a tremendous amount.
- Schedule a retake within 14 days if you miss — the material is freshest now.
- If you pass: update your LinkedIn, tell your team, take the afternoon off.

## Quick reference card (print before the exam day if allowed)

```
State ops:        list, show, mv, rm, pull, push, replace-provider
Refactor blocks:  moved, removed, import
Lifecycle:        create_before_destroy, prevent_destroy, ignore_changes, replace_triggered_by
Conditions:       validation (var), precondition/postcondition (resource/data/output), check {} (top-level)
Providers:        source, version, configuration_aliases, providers = {} in module call
For_each:         set(string) OR map(any); keys must be known at plan time
Test file:        run { command = plan|apply }, variables {}, assert { condition, error_message }, expect_failures
HCP:              cloud {} block, org → project → workspace, CLI/VCS/API workflows
OIDC to AWS:      TFC_AWS_PROVIDER_AUTH=true + TFC_AWS_RUN_ROLE_ARN
Backend config:   partial + -backend-config=, never variables
Version ranges:   = , != , > , >= , < , <= , ~> (right-most lock)
Debug:            TF_LOG=DEBUG|TRACE, TF_LOG_PATH, terraform console
```

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- The night before
- Morning of
- During the exam
- Traps on exam day

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
