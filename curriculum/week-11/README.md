# Week 11 — Terraform II: Modules, Patterns, Testing

> **Thesis:** anyone can write a `main.tf`. The skill that gets paid is **module design** — building
> something a second engineer can consume without reading your implementation, and refactoring it
> later without destroying production.

| | |
|---|---|
| **Hours** | 35–45 |
| **Deliverable** | Blog post #6 — "count vs for_each: the day I deleted three subnets by removing one" |
| **⚑ Alpha** | network, compute, and database modules complete; dev **and** prod deploying |
| **Break/Fix** | BF-34, BF-36, BF-40 |

## The week in one figure

**Figure 11.1 — Module contract, environments, and the count index shift.** The skill that gets paid is module design: a contract another engineer can consume without reading your implementation, and refactoring that never destroys production. The orange box is the bug that makes blog post 6.

![Figure 11.1 — Module contract, environments, and the count index shift](content/figure-11.1-module-contract-environments-and-the-count.png)

**Say it, badge by badge:** [`content/FIGURE.md`](content/FIGURE.md) — the spoken script for each of the 10 badges, about three and a half minutes; [`content/figure-11.1-numbered-spoken.pdf`](content/figure-11.1-numbered-spoken.pdf) is the printable two-page version. Read the figure before the day plan; say the script on Friday.

---

## Day plan
| Day | Focus | Lab |
|---|---|---|
| Mon | Module design: inputs, outputs, composition, versioning | Lab 1 |
| Tue | `for_each` vs `count`, dynamic blocks, expressions | Lab 2 |
| Wed | Environments, remote state, `moved` refactoring | Lab 3 |
| Thu | Validation and security: tflint, checkov, `terraform test` | Lab 4 |
| Fri | Break/Fix + ⚑ Alpha modules | Lab 5 |
| Sat | ⚑ Alpha: prod environment, both deploying | — |
| Sun | Blog post #6; plan week 12 | — |

## Reading map
- `_reference/terraform/labs/phase-3-intermediate-lab-3.3-modules.md`
- `_reference/terraform/labs/phase-3-intermediate-lab-3.2-functions-expressions.md`
- `_reference/terraform/labs/phase-2-core-lab-2.2-resources-meta-arguments.md`
- `_reference/terraform/labs/phase-5-professional-lab-5.2-policy-as-code.md`
- `_reference/terraform/drills/week1-authoring-modules-day4-module-design-README.md`
- `_reference/terraform/drills/week1-authoring-modules-day5-terraform-test-README.md`
- **`_reference/terraform/drills/feynman-teach-backs-example-for_each-vs-count.md`** ← read this one
- **Drill:** `_shared/drills/terraform-recall.md` — Tiers 3, 4, 6

## Labs
[labs/LABS.md](labs/LABS.md) · [labs/FIGURES.md](labs/FIGURES.md) (figures 11.2 to 11.6, one per lab) · [solutions/SOLUTIONS.md](solutions/SOLUTIONS.md) · · [Kubernetes thread](../KUBERNETES-THREAD.md#week-11)
Reference: [`../projects/alpha-cloud-foundation/modules/`](../projects/alpha-cloud-foundation/modules/)

## Exit criteria
- [ ] Alpha refactored into `network/`, `compute/`, `database/` modules
- [ ] `dev/` and `prod/` deploy from the **same modules** with different inputs
- [ ] Demonstrate the `count` index-shift bug, then fix it with `for_each`
- [ ] Refactor a resource into a module using a `moved` block — **zero destroys in the plan**
- [ ] `tflint` and `checkov` clean, or every exception documented in an ADR
- [ ] At least one `terraform test` run passing
- [ ] Blog post #6 published
