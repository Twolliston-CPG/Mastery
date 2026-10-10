# MCQ Answer Key

1. **b** — `terraform init -migrate-state`
2. **c** — `~>` locks the rightmost component; `~> 5.2` allows 5.2, 5.3, …, 5.99
3. **b** — `moved {}` is declarative; `state mv` is imperative
4. **b** — removes from state but keeps cloud resource
5. **c** — variables cannot be used inside backend blocks (resolved before variable evaluation)
6. **b** — `set(string)` or `map(any)`
7. **b** — `for_each` with stable keys
8. **c** — warnings, non-blocking
9. **b** — `can()` returns boolean
10. **b** — ACM certs for CloudFront must be in us-east-1
11. **b** — redacted in output, still plaintext in state
12. **b** — state sharing must be enabled on the producer
13. **c** — cannot coexist; pick one
14. **b** — `TFC_AWS_PROVIDER_AUTH=true` plus role ARN
15. **c** — soft-mandatory is overridable by admins
16. **b** — `terraform-<provider>-<name>`
17. **b** — exit 2 means there's a diff
18. **d** — SSH-driven isn't a thing
19. **b** — HCP Agent pool
20. **a** — required when the module needs explicit aliases passed by caller
21. **b** — backend is resolved before variables
22. **b** — import updates state only
23. **a** — 1.5+ feature
24. **a** — works best when paired with `name_prefix` for unique-name resources
25. **b** — drift detection turned off
26. **b** — CLI workspaces share config + backend key prefix; HCP workspaces are fully separate
27. **b** — `iterator` renames the loop variable
28. **c** — postcondition fires after apply
29. **c** — install methods per CLI config; defaults are fs mirror then registry
30. **b** — commit it
31. **b** — multi-platform checksum locking
32. **b** — mocks the provider in tests
33. **b** — validates that variable-level validation fails
34. **a** — chain runs across workspaces
35. **b** — `-detailed-exitcode`
36. **a** — `provider = aws.euw1`
37. **b** — structured JSON
38. **b** — OIDC preferred
39. **b** — match HCL or ignore
40. **b** — state moves to the new key

## Grading

- 36–40 correct → strong pass territory
- 30–35 → borderline, drill weak domains
- <30 → you need another week of prep; don't book the exam yet

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- MCQ Answer Key

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
