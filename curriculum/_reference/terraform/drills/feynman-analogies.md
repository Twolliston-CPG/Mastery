# Analogies — Memory Hooks for Terraform Pro Concepts

Add new ones as you invent them. If a memory is sticky it belongs here.

---

## State

- **State file** = the bank's **ledger**. Cloud resources = dollars in the vault. Lose the ledger, and the money exists but the bank can't prove who owns what.
- **DynamoDB lock** = the **conch shell** in *Lord of the Flies*. Whoever holds it speaks.
- **`terraform state rm`** = unassigning an employee's desk. They still work here, just not at that cube.
- **`terraform destroy`** = firing them.
- **`terraform import`** = **adoption papers**. The child exists; you're just officially bringing them into the family.

## Refactoring

- **`moved {}`** = **mail forwarding**. Same person, new address.
- **`removed {}`** = **retirement**. The employee stays, payroll stops.
- **`-refresh-only`** = checking **Zillow** for your house's value — no renovation, just syncing what reality says.

## Conditions

- **`validation`** = **TSA at the gate**.
- **`precondition`** = **pilot checking weather** before takeoff.
- **`postcondition`** = **air traffic control** confirming you landed.
- **`check` block** = airline's **internal dashboard** — flags a problem, doesn't ground the plane.

## Dynamic config

- **`count`** = naming your kids "Kid 1, Kid 2." If Kid 2 leaves, Kid 3 becomes Kid 2 — chaos.
- **`for_each`** = naming them Alice, Bob, Carol. One leaves, others unchanged.
- **`dynamic` block** = a for-loop that generates **nested blocks** instead of top-level resources.
- **`sensitive`** = **blurring a face** on live TV; the footage still exists on tape.
- **`ephemeral`** = **not recording at all**.

## Modules

- **Module** = a **library with a public API**. `variables.tf` is the function signature, `outputs.tf` is the return, `main.tf` is the body, `README.md` is the docstring.
- **`configuration_aliases`** = a function that takes **two DB connections as parameters** — caller must supply both, by name.
- **Version `~> 1.2`** = "anything in the 1.x family, starting at 1.2."

## Providers

- **`assume_role`** = a **hotel keycard**: limited, dated, revocable.
- **Static AWS keys** = a **house key**.
- **Provider lock file** = `package-lock.json` for Terraform.
- **`TF_LOG=TRACE`** = Chrome DevTools **Network tab** for Terraform.

## HCP Terraform

- **Organization / project / workspace** = **company / team / repo**.
- **Speculative plan on a PR** = the "**review changes**" screen before checkout.
- **Variable precedence** = **layered water** — each pour displaces earlier ones for the same key.
- **OIDC for AWS creds** = your workspace's JWT is a **student ID**; AWS STS is the library letting you check out a book because it trusts the school's issuer.
- **Sentinel levels** = three gates: **warning sign / locked gate with a manager's key / locked gate no key**.
- **Agent execution mode** = a **remote desk** inside your network, because HCP's normal desk can't see your private resources.
- **Run trigger** = a **doorbell that rings next door** when yours does.
- **State sharing** = publishing your phone number to a list of friends.

## Backend config

- **Partial backend config** = an **apartment lease with blanks** — landlord fills rent and address at signing.
- **`cloud {}` vs `backend "remote" {}`** = iPhone vs Blackberry. Both work, one's current.

## Exam-day traps

- **`backend` can't reference `var.X`** because backends resolve **before** the rest of Terraform boots. (Like setting your WiFi password from a file that's on a network share you need the WiFi to reach.)
- **ACM for CloudFront must be us-east-1** — CloudFront's control plane is there, period.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- State
- Refactoring
- Conditions
- Dynamic config

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
