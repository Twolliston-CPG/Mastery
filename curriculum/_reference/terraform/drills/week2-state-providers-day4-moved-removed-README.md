# Week 2 · Day 4 — Refactoring with `moved` and `removed`

**Exam domain:** 1 (state management), 4 (module refactoring).

## Learning goals

1. `moved {}` blocks — rename/move resources without destroy/create.
2. `removed {}` blocks (Terraform 1.7+) — delete a resource block but **keep the cloud object**.
3. The **combined refactor** pattern: flat config → module → renamed module.
4. When a `moved` block applies vs when it's ignored (after one successful apply, it becomes a no-op — safe to delete).
5. Rules you cannot break: `from` must not exist, `to` must exist, both must be in the *same* state.

## The four-move pattern

```hcl
# Rename
moved { from = aws_instance.web  to = aws_instance.frontend }

# Move into a module
moved { from = aws_instance.web  to = module.compute.aws_instance.web }

# Re-key (count → for_each)
moved { from = aws_instance.web[0]  to = aws_instance.web["primary"] }

# Move between modules
moved { from = module.old.aws_instance.web  to = module.new.aws_instance.web }
```

## `removed {}` — the newer twin

Terraform 1.7+ — remove a resource from config but tell Terraform to **forget** it (not destroy it):

```hcl
removed {
  from = aws_instance.legacy

  lifecycle {
    destroy = false   # true (default) would destroy; false keeps the cloud object alive
  }
}
```

- Before 1.7 you had to `terraform state rm aws_instance.legacy` manually.
- `removed` is **declarative** — safe to commit, applies cleanly on every runner, and is idempotent.
- Pair with documentation: add a comment explaining *why* the resource is leaving Terraform's management.

## Exercises

1. Starter config provisions `aws_vpc.flat` + `aws_subnet.flat` directly.
2. **Refactor step 1** — create `modules/network`, move the resources in. Add `moved` blocks in root. Plan shows moves, no destroy.
3. **Refactor step 2** — rename `module.network` to `module.vpc`. Another `moved` block.
4. **Refactor step 3** — the subnet was `count = 2`, convert to `for_each = { a = "10.80.0.0/24", b = "10.80.1.0/24" }`. Use `moved { from = ...[0]  to = ...["a"] }`.
5. **`removed` drill** — remove the VPC from Terraform but keep it alive (simulate handing it to another team). Apply. The VPC is still in AWS but no longer in state.

## Self-check

1. You ran `terraform apply` with a `moved` block. Can you delete the `moved` block immediately? After how long is it safe?
2. Can `moved` move a resource between two different root modules (different state files)?
3. You added `removed { from = aws_db_instance.prod, lifecycle { destroy = true } }` by mistake and ran apply. What happened? Recovery path?
4. Pre-1.7, what was the equivalent of `removed { destroy = false }`?

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- The four-move pattern
- removed {} — the newer twin

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
