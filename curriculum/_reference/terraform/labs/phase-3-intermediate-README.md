# Phase 3: Intermediate Skills

Master data sources, functions, expressions, and modules for dynamic configurations.

## Labs in This Phase

| Lab | Topic | Duration | Difficulty |
|-----|-------|----------|------------|
| 3.1 | Data Sources & Queries | 60 min | Intermediate |
| 3.2 | Functions & Expressions | 90 min | Intermediate |
| 3.3 | Module Development | 120 min | Intermediate |
| 3.4 | Dynamic Blocks & Advanced Patterns | 60 min | Intermediate |

## Learning Objectives

By the end of this phase, you will be able to:

- [ ] Query infrastructure with data sources
- [ ] Use all HCL function categories
- [ ] Create production-ready modules
- [ ] Implement dynamic configurations
- [ ] Apply advanced HCL patterns

---

## Start with Lab 3.1: Data Sources & Queries

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Intermediate Skills

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
