# Week 22 — Platform Engineering Foundations

> **Thesis:** platform engineering is a **product** discipline applied to infrastructure. The concept
> to be able to explain in sixty seconds is the **golden path**: an opinionated, paved, self-service
> route that makes the right thing the easy thing. Most candidates cannot explain it. One who can —
> with a working demo — interviews above their level.

| | |
|---|---|
| **Hours** | 35–45 (incl. ~6h job search) |
| **Deliverable** | Blog post #12 — "Golden paths: why the easy way has to be the right way" |
| **⚑ Charlie** | Product brief, module registry, the `service.yaml` contract |

## The week in one figure

**Figure 22.1 — The golden path, as a product.** Platform engineering is product management applied to infrastructure. The figure reads like a product: a user with a pain, a contract they write, a paved road that does the rest, and the metrics that say whether it worked.

![Figure 22.1 — The golden path, as a product](content/figure-22.1-the-golden-path-as-a-product.png)

**Say it, badge by badge:** [`content/FIGURE.md`](content/FIGURE.md) — the spoken script for each of the 11 badges, about three and a half minutes; [`content/figure-22.1-numbered-spoken.pdf`](content/figure-22.1-numbered-spoken.pdf) is the printable two-page version. Read the figure before the day plan; say the script on Friday.

---

## Day plan
| Day | Focus | Lab |
|---|---|---|
| Mon | What an IDP is; platform-as-product; cognitive load | Lab 1 |
| Tue | **Write the product brief** — users, pain, paved road, non-goals | Lab 2 |
| Wed | The `service.yaml` contract and its JSON schema | Lab 3 |
| Thu | Terraform module registry; the template repo | Lab 4 |
| Fri | Backstage evaluation + the build/buy decision | Lab 5 |
| Sat | ⚑ Charlie scaffolding; 20 applications | — |
| Sun | Blog post #12; plan week 23 | — |

## Reading map
- `_reference/platform-engineering/content-module-01-platform-engineering-fundamentals.md`
- `_reference/platform-engineering/content-module-02-developer-experience-design.md`
- `_reference/platform-engineering/content-module-03-internal-developer-platforms.md`
- `_reference/platform-engineering/labs-lab-04-golden-paths-software-templates.md`
- `_reference/platform-engineering/labs-lab-07-self-service-infrastructure-workflows.md`
- `_reference/platform-engineering/labs-lab-05-platform-metrics-developer-productivity.md`
- `_reference/devsecops/implementation/08-developer-experience-architecture.md`
- `_reference/kubernetes/04-platform/03-developer-platform-README.md`
- **Case study:** `_reference/case-studies/03-audiowave-platform-engineering.md` (anonymized)

**Free primary sources:** *Team Topologies* (the cognitive-load argument), the CNCF Platforms White
Paper, and platformengineering.org's maturity model.

## Labs
[labs/LABS.md](labs/LABS.md) · [solutions/SOLUTIONS.md](solutions/SOLUTIONS.md)

## Exit criteria
- [ ] Explain a golden path in 60 seconds, without saying "self-service" more than once
- [ ] A written **product brief** for Charlie: user, current pain, paved road, explicit non-goals
- [ ] `service.yaml` contract designed, with a JSON schema and validation that produces **useful**
      error messages
- [ ] A versioned, documented Terraform module registry
- [ ] A `template-service/` repo that scaffolds a new service
- [ ] A written build-vs-Backstage decision, with reasons
