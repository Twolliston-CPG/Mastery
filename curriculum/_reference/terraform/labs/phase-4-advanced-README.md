# Phase 4: Advanced Topics

Master workspaces, provisioners, testing, and CI/CD integration.

## Labs in This Phase

| Lab | Topic | Duration | Difficulty |
|-----|-------|----------|------------|
| 4.1 | Workspaces & Environment Management | 60 min | Advanced |
| 4.2 | Testing & Validation | 90 min | Advanced |
| 4.3 | CI/CD Integration | 120 min | Advanced |

## Learning Objectives

By the end of this phase, you will be able to:

- [ ] Manage multiple environments with workspaces
- [ ] Write comprehensive tests for infrastructure
- [ ] Integrate Terraform into CI/CD pipelines
- [ ] Implement GitOps workflows
- [ ] Handle drift detection and remediation

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Advanced Topics

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
