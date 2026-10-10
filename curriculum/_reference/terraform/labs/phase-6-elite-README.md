# Phase 6: Elite Challenges

Master-level challenges to prove your Terraform expertise.

## Challenge Projects

| Challenge | Topic | Duration | Difficulty |
|-----------|-------|----------|------------|
| 1 | Multi-Region Disaster Recovery | 8-10 hrs | Expert |
| 2 | Enterprise Landing Zone | 10-15 hrs | Expert |
| 3 | Kubernetes Platform | 8-10 hrs | Expert |
| 4 | Complete GitOps Pipeline | 6-8 hrs | Expert |
| 5 | Multi-Cloud Architecture | 10-12 hrs | Expert |

## Prerequisites

- Complete all previous phases
- Strong understanding of AWS services
- Experience with CI/CD pipelines
- Familiarity with Kubernetes (for Challenge 3)

## Certification Exam Simulation

After completing these challenges, you should be ready for the **Terraform Authoring and Operations Professional** certification exam.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Challenge Projects
- Certification Exam Simulation

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
