# Week 1 · Day 1 — Complex Types, Validation, Preconditions/Postconditions

**Exam domains covered:** 2 (Dynamic Configuration) — objectives on complex types, validation, custom conditions.

## Learning goals

By the end of this lab you can:

1. Declare **complex variable types** — `object`, `map(object)`, `list(object)`, nested, with **`optional()`** attributes and **default values** inside `optional()`.
2. Write **multiple `validation` blocks** on a single variable, using `can()`, `alltrue()`, `contains()`, and regex.
3. Use **`precondition`** in a `data` source or resource `lifecycle` to guard *inputs* — catch problems before the plan is applied.
4. Use **`postcondition`** to guarantee *outputs* — catch silent provider/data drift.
5. Use **`check` blocks** (Terraform 1.5+) for non-blocking assertions that produce warnings.
6. Understand *when* each mechanism runs (plan vs apply vs refresh) and *which* the exam expects for a given scenario.

## Why this matters for the exam

The Professional exam tests you on **writing** and **debugging** dynamic config. A typical lab task: "this module accepts a malformed input and silently fails; add the correct guard." Knowing the difference between `validation`, `precondition`, `postcondition`, and `check` is often the delta between full credit and zero.

| Mechanism | Where | When it runs | Effect on run |
|---|---|---|---|
| `validation {}` | `variable` block | Before plan (input parse) | Hard fail |
| `precondition {}` | `resource.lifecycle` / `data.lifecycle` / `output` | During plan | Hard fail |
| `postcondition {}` | same as above | During apply (after create/read) | Hard fail |
| `check {}` block | top-level | During plan + apply | **Warning only** |

## Exercises

### 1. Build the typed variable
Open `variables.tf`. The `app_config` variable uses a nested `object` with `optional()` attributes. Plan the config — notice how defaults fill in.

### 2. Break the validation
Try `terraform plan -var='app_config={name="x",tier="enterprise"}'` — the validation should reject `tier="enterprise"`. Read the exact error.

### 3. Trip a precondition
In `main.tf`, the `aws_ami` data source has a `precondition` ensuring the AMI exists and is owned by Amazon. Temporarily change the `owners` filter to an invalid account — observe that the failure happens at **plan time**, not apply.

### 4. Trip a postcondition
The `aws_instance` has a postcondition asserting `public_ip != ""`. Set `associate_public_ip_address = false` — observe the failure happens at **apply time** after creation.

### 5. Add a `check` block
Uncomment the `check "ami_is_recent"` block. Intentionally reference an older AMI — see a warning, not a failure.

## Commands

```bash
terraform init
terraform fmt -recursive
terraform validate
terraform plan
# apply only if you want to trip postcondition #4 — costs pennies, destroy right after
terraform apply -auto-approve
terraform destroy -auto-approve
```

## Cleanup

```bash
terraform destroy -auto-approve
rm -rf .terraform .terraform.lock.hcl terraform.tfstate*
```

## Self-check (write answers in a scratchpad, don't peek)

1. What's the difference between `validation` and `precondition` if both can reject bad input?
2. Why would you use a `check` block instead of a `postcondition`?
3. Can a `precondition` reference another resource's attributes? What about a `validation`?
4. In what order do `validation`, `precondition`, and `postcondition` fire during `apply`?

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Self-check (write answers in a scratchpad, don't peek)
- Build the typed variable
- Break the validation
- Trip a precondition

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
