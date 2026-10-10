# Phase 1: Terraform Foundations

Master the fundamentals of Terraform and Infrastructure as Code.

## Labs in This Phase

| Lab | Topic | Duration | Difficulty |
|-----|-------|----------|------------|
| 1.1 | Environment Setup | 30 min | Beginner |
| 1.2 | HCL Syntax Deep Dive | 45 min | Beginner |
| 1.3 | Core Workflow Mastery | 60 min | Beginner |
| 1.4 | Your First Infrastructure | 90 min | Beginner |

## Prerequisites

- AWS Account (Free Tier eligible)
- Terminal/CLI access
- Code editor (VS Code recommended with HashiCorp Terraform extension)

## Learning Objectives

By the end of this phase, you will be able to:

- [ ] Explain the benefits of Infrastructure as Code
- [ ] Install and configure Terraform CLI
- [ ] Write valid HCL configuration files
- [ ] Execute the core Terraform workflow (init, plan, apply, destroy)
- [ ] Deploy basic AWS resources
- [ ] Read and interpret Terraform output and state

---

## Start with Lab 1.1: Environment Setup

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Terraform Foundations

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
