# Week 1 · Day 3 — HCL Expressions & Functions Deep Dive

**Exam domain covered:** 2 (Dynamic Configuration — "Compute and interpolate data using HCL functions").

## Learning goals

1. Fluency with **for expressions** producing lists *and* objects, with filtering (`if`) and grouping (`=>... if`).
2. **Splat** expressions (`[*]` and attribute splat) and when to prefer a `for` expression.
3. **Conditional** expression edge cases — type unification, `null` coalescing.
4. **`try()` and `can()`** — when to use each, and why they're not interchangeable.
5. Top **~40 functions** you must have in your fingers for the exam, grouped by family.
6. **`templatefile`** with complex object inputs — including the directive syntax `%{for}` `%{if}`.
7. **Dynamic lookups** on collections: `lookup()`, `coalesce()`, `compact()`, `try()` chain.

## The 40 functions you must know cold

### Collection (15)
`concat`, `merge`, `distinct`, `flatten`, `compact`, `coalesce`, `coalescelist`, `lookup`, `element`, `slice`, `zipmap`, `chunklist`, `setproduct`, `setunion`, `setintersection`

### String (8)
`format`, `formatlist`, `join`, `split`, `replace`, `regex`, `regexall`, `substr`

### Type / conversion (4)
`tostring`, `tonumber`, `tolist`, `tomap` — (also `toset`)

### Numeric (3)
`min`, `max`, `abs`

### Filesystem (3)
`file`, `templatefile`, `fileset`

### Encoding (3)
`jsonencode`, `jsondecode`, `base64encode` (plus `yamlencode`/`yamldecode`)

### Hash (2)
`filemd5`, `filesha256`

### Date/time (3)
`timestamp`, `timeadd`, `formatdate`

### Network (4)
`cidrsubnet`, `cidrhost`, `cidrnetmask`, `cidrsubnets`

### Meta (3)
`try`, `can`, `sensitive`

## `try` vs `can`

```hcl
# try — return first successful expression, fallback value
value = try(var.config.nested.value, "default")

# can — returns a boolean, great for validation conditions
condition = can(regex("^[a-z]+$", var.name))
```

- `try` **evaluates and returns** — use for defensive lookups.
- `can` **returns true/false** — use inside `validation`/`precondition`/`check`.
- Chain `try(a, b, c)` — first non-erroring expression wins.

## `for` expression forms

```hcl
# list comprehension
[for u in var.users : u.name if u.enabled]

# object comprehension (note =>)
{ for u in var.users : u.name => u.email... }   # ... = grouping (values become list)

# with index
[for i, u in var.users : "${i}-${u.name}"]

# on map — two loop vars
{ for k, v in var.map : k => upper(v) if v != "" }
```

## Splat: `[*]` vs `for`

```hcl
aws_instance.web[*].id                 # splat — only works on lists/sets of resource instances
[for i in aws_instance.web : i.id]     # for — works on anything
{for k, i in aws_instance.web : k => i.id}  # for_each → object
```

- Splat is shorthand; `for` is universal. On the exam, use whatever the question gives you, but when `for_each` is in play, prefer `for` because splat on a map needs `values()` first.

## Exercise driver

`workloads.json` describes three microservices. The config:

1. Decodes JSON with `jsondecode(file(...))`.
2. Transforms with `for` expressions into AWS-shaped resources.
3. Renders a userdata script with `templatefile` and directives.
4. Carves subnet CIDRs using `cidrsubnet`.
5. Demonstrates `try()` for optional attributes and `coalesce()` for defaults.
6. Writes a local output file using `local_file` for inspection.

Run:

```bash
terraform init
terraform plan
# examine the big `debug` output to see each expression's result
terraform output debug | less
```

## Self-check

1. Given `list = ["a", "b", "a"]`, what does `length(toset(list))` return? What does the resource plan look like if you use that in `for_each`?
2. When would `try(x, "default")` fail even with a default provided?
3. What's the difference between `lookup(m, "k", "x")` and `try(m["k"], "x")`?
4. Inside `templatefile`, how do you iterate over a map and skip keys with empty values in one directive?

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- The 40 functions you must know cold
- try vs can
- for expression forms
- Splat: [] vs for

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
