# Teach-back: <CONCEPT NAME>

**Date:** YYYY-MM-DD
**Domain:** <1-6 or cross-cutting>
**Linked lab:** <week/day folder>

---

## 1. Explain it to a smart friend who has never used Terraform

Pretend they know programming but not IaC. Use no Terraform jargon in the first paragraph — define every term the first time it appears.

<write here>

## 2. The analogy

One non-technical analogy that captures the core mental model. If you can't come up with one, steal from `analogies.md` — then try to improve it.

<write here>

## 3. The gotcha

What would a careful engineer still get wrong? What's the trap in the MCQs?

<write here>

## 4. Working example (HCL)

Write HCL from memory. Don't copy from the domain file.

```hcl
<write here>
```

## 5. Self-test — answer cold

Pull the self-test prompt from the domain file. Answer it without looking.

**Q:** <paste the prompt>
**A:** <your answer>

## 6. Where did I hesitate?

List every point where you had to think "wait, is it…" or checked a reference. These are candidate entries for `gaps-log.md`.

- <hesitation 1>
- <hesitation 2>

## 7. Confidence after this pass

`[ ]` shaky — still hand-waving
`[~]` okay — I got there with one reference peek
`[x]` solid — cold, clean, could field follow-ups

Update `00-mastery-tracker.md` to match.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Explain it to a smart friend who has never used Terraform
- The analogy
- The gotcha
- Working example (HCL)

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
