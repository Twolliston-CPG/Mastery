# Sources and Anonymization

> **Not the reading list.** This file records where the curriculum's *content* came from and
> how it was anonymized. For where to go and *learn more* — primary docs, specs and books per
> domain — see [`_reference/SOURCES.md`](_reference/SOURCES.md).

## What this curriculum is built from

Two kinds of content:

**1. Written for this curriculum.** All 26 week READMEs, all labs, all solutions, all assessments,
the 58-scenario break/fix library, the drills, the Anki decks, the interview bank, the templates, the
setup scripts, and the three project implementations. ~21,000 lines.

**2. Curated from an existing corpus** into [`_reference/`](_reference/). 623 files, ~338,000 lines,
drawn from curriculum material that already existed in this workspace: multi-phase programs covering
DevOps, Kubernetes, AWS SAA, Terraform, ArgoCD, DevSecOps, threat modeling, observability, platform
engineering, and Python for operations.

Each week's README maps to the specific reference files for that week, so the corpus is navigable
rather than a pile.

---

## Anonymization

Everything in `_reference/` was processed to remove identifying names, in **file contents and in
filenames**.

### What was replaced

| Original | Replaced with |
|---|---|
| A client project name appearing ~1,350 times | `northwind` / `Northwind` |
| Real public-company case studies (streaming, audio, retail, banking, marketplace, apparel, CDN, social) | Fictional archetypes: `StreamCo`, `AudioWave`, `NorthStar Retail`, `Meridian Bank`, `CraftMarket`, `StayNest`, `PinBoard`, `ShopStack`, `Apex Athletics`, `EdgeNet`, `SocialGraph` |
| Named employers and clients from prior engagements | `Regional Financial Group`, `Oceanic Lines`, `Continental Insurance`, `Vantage Consulting`, `MedRx Systems`, `Clinical Research Institute`, `SafeHarbor`, `BrightLead`, `Requisite`, `CargoLink`, `AssistAI` |
| Named breach/incident case studies | `OrionSoft`, `IdentityCo`, `ThreatGroup-A`, `ThreatGroup-B`, `FileTransferApp` |
| Email domains | `@northwind.example` |

Filenames were renamed to match (e.g. `01-netflix-chaos-engineering.md` →
`01-streamco-chaos-engineering.md`).

### What was deliberately **not** anonymized

**Tool, product, and vendor names** — Kubernetes, Terraform, Prometheus, Grafana, ArgoCD, Falco,
Trivy, Kyverno, AWS, Azure, GCP, GitHub, HashiCorp, Datadog, and so on.

These are the vocabulary of the job. A student must be able to name them in an interview, and
anonymizing them would destroy the curriculum's usefulness. The request was to anonymize *company
identities in case studies and client work*, which is what was done.

### Excluded entirely

Nothing personal was drawn on. The following were excluded from sourcing:

- Financial and personal directories (tax records, health, payroll, legal)
- Résumés, CVs, and personal experience documents
- Named individuals' coaching and interview-prep directories
- Real client engagement work — statements of work, discovery notes, meeting transcripts,
  deliverables
- Company-specific interview preparation
- Anything containing personal identifiers

### Verification

The command below is the audit check. It necessarily contains the original names — that is the only
place in this curriculum they appear, and they appear as a *search pattern*, not as content.

```bash
grep -rliE '(tidyup|netflix|spotify|capital[ -]?one|airbnb|pinterest|shopify|\betsy\b|adidas|cloudflare|solarwinds|\bokta\b)' _reference/
# -> 0 files

find _reference/ -iname '*netflix*' -o -iname '*capital-one*' -o -iname '*spotify*' -o -iname '*tidyup*'
# -> nothing
```

Both checks return empty.

---

## Provenance of the worked code

Everything executable was written for this curriculum and verified:

| Artifact | Verification |
|---|---|
| `projects/alpha-cloud-foundation/` — 7 Terraform configurations | `terraform validate` all pass · `fmt -check` clean · `tflint --recursive` clean |
| `week-19/solutions/policies/*.rego` | `conftest verify` — 6 tests, 6 passed |
| `projects/charlie-platform/cli/validate.py` | Executed: accepts both valid examples, reports 7 distinct problems in an invalid one |
| `projects/charlie-platform/cli/platform` | `bash -n` clean; subcommands execute |
| `week-01/solutions/sysreport/sysreport.sh` | `bash -n` clean; `--help` and error paths exercised |
| `week-04/solutions/compose-stack/` | `docker compose config` valid; `app.py` compiles |
| `week-14/solutions/k8s-stack/` | `kubectl kustomize` builds 12 resources |
| All workflow, policy, and manifest YAML | Parsed with `yaml.safe_load` |
| All IAM policies and the service schema | Parsed as JSON |

Two real bugs were found and fixed during verification: YAML anchors do not cross `---` document
boundaries (Kyverno policies), and a markdown table at column 0 inside a block scalar breaks YAML
parsing (a GitHub Actions workflow). Both are noted because they are exactly the kind of thing that
looks fine until it runs.

---

## External resources referenced

The curriculum points to free primary sources throughout rather than reproducing them: vendor
documentation, `man` pages, the Google SRE Book and Workbook, the CNCF exam curricula, the AWS
Well-Architected Framework, CIS Benchmarks, NSA/CISA Kubernetes hardening guidance, the CNCF
Platforms White Paper, and *Team Topologies*.

Paid resources are named as options in [`../CERTIFICATIONS.md`](../CERTIFICATIONS.md) §6, with the
explicit advice to pick **one** spine per exam rather than collecting several.
