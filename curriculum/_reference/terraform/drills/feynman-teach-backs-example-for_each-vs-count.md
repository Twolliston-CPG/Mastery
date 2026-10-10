# Teach-back: `for_each` vs `count` (seeded example)

**Date:** 2026-04-20
**Domain:** 2 (Dynamic Configuration) + 4 (Modules)
**Linked lab:** `week1/day2-foreach-dynamic-meta`

> This is a seeded example so you can see the bar. Your own teach-backs should be longer, messier in the gaps section, and have stronger "where did I hesitate" notes — that's where the learning is.

---

## 1. Explain it to a smart friend who has never used Terraform

Terraform configurations describe cloud resources — things like virtual machines, networks, databases. If you want three nearly-identical VMs, you don't want to copy-paste the block three times. Terraform gives you two looping mechanisms for this: `count` and `for_each`.

`count` says "make N copies of this." It uses positional indexing: copies live at `resource.name[0]`, `[1]`, `[2]`.

`for_each` says "make one copy per key in this set or map." Copies live at `resource.name["dev"]`, `resource.name["stg"]`, `resource.name["prd"]` — keyed by name, not position.

The difference becomes painful when you insert or remove items. Deleting index 1 from a `count`-ed list causes every element from index 2 onward to shift down — Terraform sees position 2 as a "different" resource now and will destroy + recreate everything downstream. `for_each` is stable: deleting `"stg"` leaves `"dev"` and `"prd"` exactly where they were.

## 2. The analogy

`count` is naming your children "Kid 1, Kid 2, Kid 3." If Kid 2 moves out, Kid 3 is now Kid 2 — chaos.

`for_each` is naming them Alice, Bob, Carol. Bob leaves and nobody else has an identity crisis.

## 3. The gotcha

`for_each` requires the key set to be known **at plan time**. If your keys come from a resource attribute that doesn't exist until after apply (e.g., generated IDs), you'll hit:

> The "for_each" map includes keys derived from resource attributes that cannot be determined until apply.

Workaround: derive keys from inputs, not outputs. If you truly need dynamic keys, split the graph into two applies (first apply creates the parents, second reads them as inputs).

Second trap: switching a resource from `count` to `for_each` changes the address (`res[0]` → `res["dev"]`). Without a `moved` block, Terraform will destroy and recreate.

## 4. Working example (HCL)

```hcl
variable "envs" {
  type = set(string)
  default = ["dev", "stg", "prd"]
}

resource "aws_s3_bucket" "logs" {
  for_each = var.envs
  bucket   = "acme-logs-${each.key}"
}

# Migrating from count? Add moved blocks:
moved {
  from = aws_s3_bucket.logs[0]
  to   = aws_s3_bucket.logs["dev"]
}
moved {
  from = aws_s3_bucket.logs[1]
  to   = aws_s3_bucket.logs["stg"]
}
# ...
```

## 5. Self-test — answer cold

**Q:** You want one security group per environment, with SG IDs later wired into instances. Why `for_each = toset(["dev","stg","prd"])` and not `for_each = aws_vpc.envs`?

**A:** Because `aws_vpc.envs` is a resource reference whose attributes (like `id`) aren't known at plan time — `for_each` keys must resolve at plan. The string set resolves instantly. If you needed SG-to-VPC mapping, key the SGs by the same environment name and look up the VPC with `aws_vpc.envs[each.key].id` inside the SG block.

## 6. Where did I hesitate?

- Had to stop and check whether `for_each` accepts `list(string)` (it doesn't — `set(string)` or `map`).
- Wasn't sure whether `moved` on a count→for_each conversion needs one block per index, or a single glob-style one. (Answer: one per index.)
- Forgot whether `each.key` in a `set(string)` gives the value or the index. (It gives the string — for sets, `each.key == each.value`.)

## 7. Confidence after this pass

`[~]` okay — the mental model is clear, but I should redo the `count→for_each` migration exercise in `week1/day2-foreach-dynamic-meta` before calling it `[x]`.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Explain it to a smart friend who has never used Terraform
- The analogy
- The gotcha
- Working example (HCL)

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
