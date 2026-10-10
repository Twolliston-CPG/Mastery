# Phase 2: Core Competencies

Master providers, resources, meta-arguments, variables, and state management.

## Labs in This Phase

| Lab | Topic | Duration | Difficulty |
|-----|-------|----------|------------|
| 2.1 | Providers Deep Dive | 60 min | Intermediate |
| 2.2 | Resources & Meta-Arguments | 90 min | Intermediate |
| 2.3 | Variables & Validation | 60 min | Intermediate |
| 2.4 | State Management Mastery | 120 min | Intermediate |

## Learning Objectives

By the end of this phase, you will be able to:

- [ ] Configure multiple providers with aliases
- [ ] Use all meta-arguments effectively
- [ ] Create complex variable types with validation
- [ ] Configure and manage remote state
- [ ] Perform state operations safely
- [ ] Import existing resources

---

## Start with Lab 2.1: Providers Deep Dive

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Core Competencies

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
