# Figure 22.1 — The golden path, as a product

> Week 22 · badges ① to ⑪ · about three and a half minutes at a normal pace. Point at each badge as you say its line. Blue is the path to follow first; orange-red is where something refuses or fails.

![Figure 22.1 — The golden path, as a product](figure-22.1-the-golden-path-as-a-product.png)

Platform engineering is product management applied to infrastructure. The figure reads like a product: a user with a pain, a contract they write, a paved road that does the rest, and the metrics that say whether it worked.

## What to say, badge by badge

- **Open.** “Explain a golden path in sixty seconds without saying self-service more than once. This figure is the sixty seconds. It starts with a person and a pain, not with a technology.”
- **① the user.** “A product engineer who wants to ship a feature. They do not know Kubernetes and the platform's job is to keep it that way. Every design decision is tested against this person.”
- **② the pain today.** “Count it: how many tickets to get a service running, how many days, how much copying from the last repository. The brief quantifies the pain so the platform can be measured against it.”
- **③ service.yaml.** “The contract. Name, owner, language, port, tier, dependencies. It is the only file the user writes, and every field exists because something downstream needs it. The charlie project in _reference shows the shape.”
- **④ JSON schema and validation.** “The schema rejects a bad file, and the error says exactly what to change. The error message is the product: a validation that says 'invalid' makes the user ask you, and then it is not a platform.”
- **⑤ template-service.** “A repository scaffold with the Dockerfile, the pipeline, and the health endpoints already correct. Hardened by default, so the easy way is the right way without the user choosing it.”
- **⑥ module registry.** “Versioned Terraform modules for runtime, pipeline, database, storage, and observability. The weeks 10 to 13 modules, now consumed by a controller instead of a person.”
- **⑦ the paved road.** “What the contract turns into: a namespace with quotas, a pipeline, a dashboard, alerts, an SLO, a runbook stub. All of it generated. The user opts out of nothing because nothing is opt-in.”
- **⑧ non-goals and escape hatches.** “The brief says what the platform will not do, and the docs say how to go off the paved road with support rather than in secret. Platforms die when the only way off is to work around them.”
- **⑨ DX metrics.** “Time to first deploy, tickets per service, and the cognitive load the user carries. Measure before and after. A platform that cannot show the number did not move it.”
- **⑩ build versus Backstage.** “A written decision. Backstage is a portal with a learning curve; for one person and three services it is overhead. Say why, in an ADR, so the decision can be revisited when the answer changes.”
- **⑪ the product brief.** “Tuesday's deliverable: user, pain, paved road, non-goals, how you will know it worked, and the riskiest assumption. Everything in weeks 23 and 24 is checked against this page.”
- **Close.** “A person, a pain, one file, a road that makes the right thing the easy thing, and a number that says it worked. That is a golden path, and most candidates cannot explain it.”

**Print it:** [`figure-22.1-numbered-spoken.pdf`](figure-22.1-numbered-spoken.pdf) is the two-page version, the figure on page one and this script on page two.

## Use it

- Read the figure before the day plan. Say the script out loud on Friday with the file closed.
- Each badge line is a thirty-second interview answer; the whole script is the three-minute version.
- Regenerate after editing the spec in `_shared/diagrams/week_figures/`:

```bash
python3 ../../_shared/diagrams/generate-week-figures.py --only 22
```
