# Domain 2 — Dynamic Configuration (the Teacher's Voice)

---

## 1. Variable types that actually catch bugs

```hcl
variable "subnets" {
  type = map(object({
    cidr       = string
    public     = optional(bool, false)
    az_suffix  = optional(string)
  }))
  validation {
    condition     = alltrue([for k, v in var.subnets : can(cidrhost(v.cidr, 0))])
    error_message = "Every subnet cidr must be valid CIDR notation."
  }
}
```

**Analogy:** TypeScript for Terraform. `optional(T, default)` is `arg?: T` with a fallback.

**Gotcha:** `validation` runs at parse time; if your condition needs another variable, fine — but it cannot reference resources. For cross-resource rules, use `precondition`.

**Self-test:** Which of `validation`, `precondition`, `postcondition`, `check` can reference another resource's attributes?

**Lab:** `week1/day1-types-validation`

---

## 2. The four condition blocks — order of evaluation

1. **`validation`** (inside `variable`) — at parse, catches bad inputs.
2. **`precondition`** (inside `lifecycle` of a resource/data/output) — at plan, before the provider is called. Stop if assumption is wrong.
3. **`postcondition`** (same) — at apply, after provider returns. Stop if result is wrong.
4. **`check` block** (top-level) — at plan and apply, **warning only**. Never blocks.

**Analogy:** `validation` = TSA at the gate. `precondition` = the pilot checking weather before takeoff. `postcondition` = air traffic control confirming you landed. `check` = the airline's internal dashboard — a problem, but doesn't ground the plane.

**Gotcha:** `check` never fails a run. If you want to block, it's pre/post, not check.

**Self-test:** Which block catches "this AMI isn't in this region" at plan time?

---

## 3. `for_each` — the apply-time key trap

```hcl
# BAD — keys unknown until apply
for_each = toset([for b in aws_s3_bucket.logs : b.id])

# GOOD — keys known at plan
for_each = var.log_bucket_names  # set(string) from input
```

**Analogy:** A seating chart written in pen before guests arrive vs. scribbled during the entrée.

**Gotcha:** `for_each` requires `set(string)` or `map(any)`. Keys must resolve at plan. If you need dynamic keys, break into two applies or re-model the graph.

**Self-test:** You want one security group per environment, SG IDs later wired into instances. Why `for_each = toset(["dev","stg","prd"])` not `for_each = aws_vpc.envs`?

**Lab:** `week1/day2-foreach-dynamic-meta`

---

## 4. `dynamic` blocks

```hcl
dynamic "ingress" {
  for_each = var.rules
  content {
    from_port   = ingress.value.from
    to_port     = ingress.value.to
    protocol    = "tcp"
    cidr_blocks = ingress.value.cidrs
  }
}
```

**Analogy:** A `for` loop that generates nested blocks instead of top-level resources.

**Gotcha:** Only block-shaped attributes (like `ingress`, `setting`, `logging`) need `dynamic`. Scalar args don't.

**Self-test:** If `var.rules` is empty, how many `ingress` blocks does the SG get?

---

## 5. `for` expressions — three shapes

| Shape | Syntax | Returns |
|---|---|---|
| List | `[for x in xs : f(x)]` | list |
| Map | `{for k,v in m : k => f(v)}` | map |
| Grouping | `{for u in users : u.team => u.name...}` | map of lists (note the `...`) |

**Self-test:** Given `users = [{team="a",name="x"},{team="a",name="y"},{team="b",name="z"}]`, what does `{for u in users : u.team => u.name...}` produce?

**Lab:** `week1/day3-functions-expressions`

---

## 6. `templatefile` + directives

```hcl
user_data = templatefile("${path.module}/cloud-init.tpl", {
  hostname = var.name
  packages = var.packages
})
```

Inside the `.tpl`:
```
%{ for p in packages ~}
apt-get install -y ${p}
%{ endfor ~}
```

**Gotcha:** `${}` is interpolation (Terraform). `%{}` is a directive (loop/if). The `~` strips the newline on that side so you don't get blank lines in rendered output.

**Self-test:** Why does `%{if x}yes%{else}no%{endif}` render with a newline gap if you omit the `~`?

---

## 7. `can()` vs `try()`

- `can(expr)` → `bool`. Did `expr` evaluate without error?
- `try(e1, e2, e3)` → the first expression that evaluates cleanly.

```hcl
# Condition
condition = can(regex("^arn:", var.role_arn))

# Defensive lookup
name = try(aws_iam_role.x.name, var.fallback_name, "unnamed")
```

**Self-test:** In a `validation` block, which one do you reach for?

---

## 8. `sensitive` vs `ephemeral`

- `sensitive = true` on a variable/output/resource attr — redacts from CLI output and logs. **Still written to state.**
- `ephemeral = true` (1.10+) on ephemeral resources/variables — never stored in state, never in plan output.

**Analogy:** `sensitive` is blurring a face on live TV; the footage still exists on tape. `ephemeral` is not recording at all.

**Gotcha:** A sensitive value in state is still plaintext in the backend. Encrypt at rest and limit S3 bucket access.

**Self-test:** You need to pass a short-lived Vault token to a provider. `sensitive` or `ephemeral`? Why?

**Lab:** `week4/day1-sensitive-vault`

---

## Flashcards

Domain 2 in `/FLASHCARDS.md` — 8 cards.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Variable types that actually catch bugs
- The four condition blocks — order of evaluation
- foreach — the apply-time key trap
- dynamic blocks

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
