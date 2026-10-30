# Week 22 Labs

> **Figures:** one numbered mechanism figure per lab, with the spoken script, the numbers to own and
> the command that proves each badge, in [`FIGURES.md`](FIGURES.md) (22.2 to 22.6). Read a lab's figure
> before you start it; redraw it after.

---

# Lab 1 — What an IDP Actually Is (3h)

## The problem it solves

Without a platform, shipping a new service means a developer knowing: Terraform, AWS IAM, VPC
networking, Kubernetes manifests, Helm, CI/CD, Prometheus, alert routing, and your organization's
conventions for all nine.

That is an enormous **cognitive load** for someone whose actual job is writing the payments service.
The *Team Topologies* argument is that cognitive load is the binding constraint on team
effectiveness — and a platform exists to reduce it, not to add a tool.

## The golden path — the sixty-second explanation

> *"A golden path is the opinionated, supported, well-lit route to production. It isn't the only way
> to do things — you can go off it — but it's the way that's paved: it comes with a pipeline,
> monitoring, alerting, security controls, and someone who supports it. The goal is that the easiest
> thing to do is also the right thing, so nobody has to choose between shipping fast and doing it
> properly."*

**Note what that answer does not say:** it doesn't list tools. Platform engineering questions are
usually answered with a tool list, and the tool list is the least interesting part.

## Platform as a product

| Infrastructure team | Platform team |
|---|---|
| Takes tickets | Has **users** |
| Success = uptime | Success = **adoption** and developer outcomes |
| Gatekeeps | **Paves** |
| "You can't do that" | "Here's the easy way to do that" |
| Measured by incidents | Measured by time-to-first-deploy, DORA, adoption % |

**The adoption metric is the load-bearing one.** A platform nobody uses is a failed product,
regardless of how good the engineering is. And adoption you *mandate* gets routed around; adoption
you *earn* survives. That's why the golden path has to genuinely be the easiest option — if it isn't,
people will build their own, and now you have two platforms.

## Developer experience metrics — measure these

| Metric | Why it's the right measure |
|---|---|
| **Time to first deploy** (a new engineer, day one → production) | The single best proxy for platform quality |
| Time to provision a new service | What Charlie optimizes |
| Lead time for changes (DORA) | End-to-end delivery speed |
| **Platform adoption %** | Services on the golden path vs bespoke |
| Support ticket volume | Should **fall** as the platform matures |
| Developer satisfaction (survey) | The thing all the others are proxies for |

## Tasks
1. Write the golden-path explanation in your own words. Time yourself saying it. **Under 60 seconds.**
2. Read the anonymized platform case study in `_reference/case-studies/`. What was the *organizational*
   problem, not the technical one?
3. List everything a developer at your imaginary company must currently know to ship a new service.
   That list is your product requirements.

---

# Lab 2 — The Product Brief (3h) ⚑

**Write this before any code.** One page. It is itself an interview artifact — most candidates
cannot produce one, and it's the clearest evidence that you think about users rather than tools.

```markdown
# Charlie — Internal Developer Platform: product brief

## Who is the user?
A backend engineer on a product team. Comfortable with their language and with Docker.
Has used Kubernetes but does not want to become an expert in it. Is measured on
shipping product features, not on infrastructure quality.

**Explicitly NOT the user:** the platform team itself, or an infrastructure
specialist who would rather write Terraform directly.

## What is their pain today?
Shipping a new service takes 3–5 days and requires:
  - a ticket to the infrastructure team for an AWS account role and ECR repo
  - copying CI config from another repo and adapting it (usually incorrectly)
  - hand-writing Kubernetes manifests, usually by copying a service that has
    since drifted
  - a second ticket for DNS
  - no dashboard or alerts unless they remember to ask, which they do not

The infrastructure team spends ~40% of its time on these tickets, and every
service ends up subtly different, so nothing can be fixed in one place.

## What does the paved road look like?
A developer adds `services/<name>/service.yaml` to the platform repo and opens a
pull request. On merge, the service exists: repository scaffolded, pipeline
running, infrastructure provisioned, DNS resolving, dashboard live, alerts and an
SLO configured, runbook stub created.

**Target: under 10 minutes from merge to a running service. Zero tickets.**

## What does it deliberately NOT support?
- Anything other than a stateless HTTP service with an optional Postgres or S3
  dependency. A team needing Kafka, a GPU, or a custom networking topology goes
  off the paved road and talks to us. That is a supported outcome, not a failure.
- Multi-region. Single region only.
- Custom Kubernetes manifests. If you need one, you have outgrown the path.

**Being explicit about non-goals is what makes a platform shippable.** A platform
that supports everything is just Kubernetes with extra steps.

## How will we know it worked?
- Time to provision: 3–5 days -> under 10 minutes
- Infrastructure tickets for new services: ~8/month -> 0
- Services on the golden path: 0 -> 80% within two quarters
- **Every** provisioned service has a dashboard, alerts, and an SLO (today: ~30%)

## What is the riskiest assumption?
That developers will accept the constraints of the paved road rather than
demanding exceptions. Mitigation: make the path genuinely faster, and make going
off it possible rather than forbidden.
```

**The last section is the one that reads as product thinking.** Naming your riskiest assumption —
and that it's a human one, not a technical one — is unusual and memorable.

---

# Lab 3 — The Contract (3h) ⚑

## Design `service.yaml`

Start from `_shared/templates/service.yaml`. The design questions:

| Question | The tradeoff |
|---|---|
| What must the developer specify? | Every required field is friction; every optional one is a decision you make for them |
| What can be **derived**? | Name → namespace, repo, DNS, dashboard. Derive everything you can. |
| What is a **tier** vs an individual knob? | `tier: critical` is one decision; replicas + PDB + SLO + paging is four. Bundle them. |
| What is deliberately **not** configurable? | Security controls. If `runAsNonRoot` is a knob, it will be turned off. |

**The tier abstraction is the key move.** `tier: critical | standard | experimental` lets a developer
make one meaningful decision instead of twelve technical ones, and lets the platform encode what each
tier means (and change it later in one place).

## The JSON schema

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["apiVersion", "kind", "metadata", "spec"],
  "properties": {
    "metadata": {
      "type": "object",
      "required": ["name", "owner"],
      "properties": {
        "name": {
          "type": "string",
          "pattern": "^[a-z]([-a-z0-9]{0,38}[a-z0-9])?$",
          "description": "DNS-1123 label. Becomes the namespace, DNS name, and ECR repo."
        },
        "owner": {
          "type": "string",
          "description": "Must exist in platform/teams.yaml"
        }
      }
    },
    "spec": {
      "type": "object",
      "required": ["language", "port", "tier"],
      "properties": {
        "tier": { "enum": ["critical", "standard", "experimental"] },
        "language": { "enum": ["python", "go", "node", "java"] },
        "port": { "type": "integer", "minimum": 1024, "maximum": 65535 }
      }
    }
  }
}
```

## Error messages are a product decision

```
# BAD
Error: validation failed

# ALSO BAD
Error: services/payments/service.yaml: .spec.tier: must be one of [critical standard experimental]

# GOOD
services/payments-api/service.yaml line 14:
  spec.tier: "high" is not a valid tier.

  Valid tiers:
    critical      2+ replicas across AZs, PDB, 99.9% SLO, pages on-call
    standard      1+ replica, 99.5% SLO, creates tickets
    experimental  no SLO, no paging, auto-expires after 30 days

  Did you mean "critical"?

  Docs: https://platform.internal/docs/tiers
```

**A validation error is the most-read documentation in your platform.** It arrives at the exact
moment someone needs it, and it is the only docs a developer will definitely see. Spending an hour on
error messages returns more than a day on the docs site — and noticing that is a genuine
platform-engineering instinct worth saying out loud.

## Tasks
1. Design the contract. Justify every required field.
2. Write the JSON schema.
3. Write a validator producing errors in the "GOOD" format above, including the "did you mean"
   suggestion (Levenshtein distance against the enum).
4. Write 6 invalid `service.yaml` files and confirm each produces a helpful message.

---

# Lab 4 — Module Registry and Template Repo (3h) ⚑

## The versioned module registry

**`platform-modules/`**

| File | What it is |
|---|---|
| `service-runtime/` | namespace, quota, RBAC, ServiceAccount, NetworkPolicy |
| `service-pipeline/` | ECR repo, OIDC role, branch protection |
| `service-database/` | RDS instance, secret, security group rule |
| `service-storage/` | S3 bucket, least-privilege IAM policy |
| `service-observability/` | dashboard, alerts, SLO recording rules |


Each module: documented variables, `terraform-docs` README, **tagged releases**, and a `CHANGELOG`.

```hcl
module "runtime" {
  source  = "git::https://github.com/org/platform-modules.git//service-runtime?ref=v1.4.0"
  # NEVER ?ref=main -- your consumers' builds would change with no commit of theirs
}
```

## The template repo

`template-service/` — a GitHub template repository containing:
```
.github/workflows/ci.yml       generated from the language, not copied
Dockerfile                     hardened by default: non-root, distroless, read-only
src/                           a working hello-world with /health and /ready
tests/
service.yaml                   pre-filled with the developer's answers
README.md                      generated, with links to the platform docs
```

**The Dockerfile ships hardened.** A developer who has never heard of `runAsNonRoot` gets it. This is
the same idea as Kyverno mutation in week 19 — **make the secure thing the default, not the thing
you get rejected for forgetting.**

## Tasks
1. Build three modules with versioned releases
2. Build the template repo with a working service including `/health` and `/ready`
3. Write the scaffolding script: `platform new-service --name X --language python`
4. **Time it.** From running the command to a PR being open — target under 2 minutes.

---

# Lab 5 — Backstage: the Build/Buy Decision (2h)

Spend two hours evaluating Backstage. Then **write the decision down**, either way.

```bash
npx @backstage/create-app@latest
cd my-backstage-app && yarn dev
```

## The honest evaluation

| | Backstage | Build it |
|---|---|---|
| Time to a working demo | ~2 weeks | ~4 days |
| What it demonstrates | You can follow Backstage's docs | **You understand what a golden path is** |
| Plugin ecosystem | Large | None |
| At a company already running it | **Directly relevant** | Irrelevant |
| Maintenance | A TypeScript app to own | A script and some Terraform |
| Interview explainability | "I set up Backstage" | "Here's why I built it this way" |

## The recommendation, and the reasoning

**Build it, unless your target employers name Backstage in their postings.**

The point of Charlie is to demonstrate that you understand **platform-as-product thinking** — the
contract, the tier abstraction, the error messages, the non-goals. Backstage is a substantial
framework that can consume two weeks producing a demo that shows framework-following rather than
judgment.

**But make it a real decision, not a default.** Check 20 job postings in your target list. If
Backstage appears in several, learn it — relevance beats elegance. Write the decision as an ADR
either way; *"I evaluated Backstage and chose not to use it, here's why"* is a stronger interview
answer than either tool alone.

## Task
Write `docs/adr/0001-build-vs-backstage.md` using `_shared/templates/ADR-template.md`. Include the
"do nothing" option and what would make you revisit.
