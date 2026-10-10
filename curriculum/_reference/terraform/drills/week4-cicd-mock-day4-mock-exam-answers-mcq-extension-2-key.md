# MCQ Extension 2 Answer Key

61. **b** — `-reconfigure` = start over; `-migrate-state` = copy to new backend
62. **a** — times out with an error; the resource is marked tainted on the next run (subject to provider behavior)
63. **b** — S3 key becomes `env:/<workspace>/<key>`
64. **b** — `for_each` and `count` are mutually exclusive
65. **b** — skip backend init; useful for `terraform validate` in CI without backend creds
66. **d** — both `terraform show -json tfplan` and `terraform plan -out=...` + show work
67. **b** — provider bug OR feeding unknown values where plan-time was expected
68. **b** — constraints intersect; effective is `~> 5.40`
69. **b** — one resource, reference its attribute
70. **b** — works with local+path, but usually only useful for demos
71. **b** — `var.region` ternary produces inconsistent numeric/null types; always wrap in the same type
72. **b** — `moved` is no-op once applied; safe to delete
73. **b** — STS credentials with TTL
74. **b** — for_each uses `["key"]`, not `[0]`
75. **b** — refresh-only mode, no resource changes
76. **b** — appends flags to plan runs globally
77. **a** — all outputs from state
78. **c** — both valid; `for_each` preferred for readable addresses
79. **b** — projects are groupings within an org with their own access scope
80. **b** — `moved` blocks per resource + convert to `for_each`

## Combined scoring (across all 80 MCQ)

| Score | Verdict |
|---|---|
| 72+ / 80 (90%) | Pass territory on MCQ section |
| 60–71 (75–89%) | Borderline; drill weak domains |
| 48–59 (60–74%) | Extend prep 1–2 weeks |
| <48 | Foundational gaps — don't book the exam yet |

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Combined scoring (across all 80 MCQ)

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
