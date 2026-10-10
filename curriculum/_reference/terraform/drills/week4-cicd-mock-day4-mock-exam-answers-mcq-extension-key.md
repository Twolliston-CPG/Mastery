# MCQ Extension Answer Key

41. **b** — `try()` returns a fallback; keeps plan usable. Important: `try` does not help if the provider itself throws — only when the expression errors.
42. **b** — `providers = { aws.audit = aws.audit }` in the module block.
43. **c** — `state show` prints the value; `sensitive` hides only in plan/apply/error output.
44. **b** — `terraform login` caches a token in `~/.terraform.d/credentials.tfrc.json`.
45. **b** — lower-scope wins (workspace > variable set default).
46. **b** — `-replace=` forces destroy + recreate on next apply.
47. **c** — drift is ignored for that attribute; plan stays clean.
48. **a** — commit lock file + run `terraform providers lock -platform=...` for each target platform.
49. **b** — deprecated; `apply -replace=` is canonical.
50. **b** — `removed { lifecycle { destroy = false } }` keeps cloud object, updates state only.
51. **b** — only the current platform unless `-platform` flags are passed.
52. **b** — classic exam trap: lock hashes are per-platform. `terraform providers lock -platform=linux_amd64 -platform=darwin_arm64 ...`.
53. **b** — structured JSON, `value` + `sensitive` keys.
54. **d** — configurable: pre-plan, post-plan, pre-apply.
55. **b** — `configuration_aliases` forces the caller to pass providers explicitly.
56. **c** — hard-mandatory cannot be overridden.
57. **b** — your agent polls HCP, HCP sends run jobs, agent executes locally and reports back.
58. **b** — `split` returns a list of strings.
59. **a** — separate env roots with shared modules is the scalable, exam-preferred pattern.
60. **b** — nullable optional string. (In Terraform 1.3+, default = null means nullable unless you add `nullable = false`.)

## Scoring

- 18–20: excellent, ship it
- 14–17: solid, drill the misses
- 10–13: shaky — review the relevant domain READMEs
- <10: spend another week; avoid booking the exam

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- MCQ Extension Answer Key

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
