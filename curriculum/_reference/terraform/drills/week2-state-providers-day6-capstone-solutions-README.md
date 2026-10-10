# Capstone Solution — Inherit, Import, Refactor, Migrate

**Look at this AFTER you've attempted the assignment yourself.**

## Layout

```
envs/dev/                    # root module
  versions.tf
  main.tf                    # wires modules + moved blocks
  outputs.tf
modules/
  network/                   # VPC + subnets + routing
  compute/                   # SG + instance + EIP
    tests/                   # native tests with override_resource
scripts/
  create-inherited.sh        # bash: hand-create baseline infra to import
RUNBOOK.md                   # reproducible bring-up
```

## How to use as reference

1. Read `scripts/create-inherited.sh` — see the boundary between "infra that exists" and "infra we're importing into TF".
2. Read `envs/dev/main.tf` — this is what your **final** root config should look like after all refactors.
3. Read the `moved` blocks at the bottom of `main.tf` — these are what preserve state through the imports.
4. Read `RUNBOOK.md` — this is the playbook your coworker would use to reproduce from zero.
5. `cd modules/compute && terraform init && terraform test` — the tests should pass.

## Key decisions

- **Compute vs network split:** anything that lives *inside* the VPC (SG, instance, EIP) went to compute; the VPC shell (VPC + subnets + routing + IGW) went to network.
- **EIP association:** kept as a separate resource inside compute rather than using the legacy `aws_instance.associate_public_ip_address` flag — decouples lifecycle.
- **`for_each` vs `count`:** subnets use `for_each` keyed by AZ suffix so adding/removing AZs doesn't churn the others.
- **`moved` blocks:** one per resource that migrated from the flat import layout to the modular layout. After **one** successful apply, they become no-ops and can be deleted — we've kept them here for clarity.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Layout
- Key decisions

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
