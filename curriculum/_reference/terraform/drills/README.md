# Terraform Authoring and Operations Professional — Study Repo

Lab workspace for the 4-week prep (2026-04-20 → ~2026-05-18).

## Layout

```
week1-authoring-modules/   Domains 2 & 4 — dynamic HCL + modules
week2-state-providers/     Domains 1 & 5 — lifecycle + providers
week3-hcp-collab/          Domains 3 & 6 — HCP Terraform + collaboration
week4-cicd-mock/           Cross-cutting + mock exam
```

## Conventions

- Every lab has its own `README.md` with a **Learning goal**, **Exercises**, and **Cleanup**.
- Always run `terraform destroy` after a lab — AWS free tier only goes so far.
- Commit progress at end of each day: `git add . && git commit -m "weekN-dayM: topic"`.

## Tooling baseline

- Terraform `>= 1.6` (exam baseline). Local: pin via `required_version`.
- AWS account: `546544527454` (iamadmin user verified on 2026-04-20).
- HCP Terraform account: create at https://app.terraform.io/signup (needed from Week 3).

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Layout
- Conventions
- Tooling baseline

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
