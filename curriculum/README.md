# The Curriculum

> Complete content, labs, and **worked solutions** for all 26 weeks of
> [`../WEEK-BY-WEEK.md`](../WEEK-BY-WEEK.md), plus the four-week CKA module (weeks 27–30).

**New here? Read [START-HERE.md](START-HERE.md) first.** It is the day-one setup and the rules that
make the rest work. Then [**STEP-BY-STEP.md**](STEP-BY-STEP.md) — the operating manual for the whole
26 weeks: the daily loop, the weekly loop, the seven gates, and what to do when one of them fails.

---

## What's here

| Directory | What it is |
|---|---|
| **[`week-01/`](week-01/) … [`week-30/`](week-30/)** | One directory per week (27–30 are the CKA module): `README.md` (objectives, day plan, reading map, exit criteria), `labs/` (the work), `solutions/` (worked answers **and running code**), `assessment.md` (self-test with an answer key) |
| **[`FIGURES.md`](FIGURES.md)** | Index of the 30 weekly figures, the lab figures underneath them, and the 10 platform figures, each with a numbered spoken walkthrough. Read a week's figure before its day plan |
| **[`_setup/`](_setup/)** | Runnable environment scripts — toolchain, AWS cost guardrails, local Kubernetes, nightly teardown, verification. [`ARCHITECTURE.md`](_setup/ARCHITECTURE.md) explains the lab platform and its guardrails in ten figures |
| **[`_shared/`](_shared/)** | Cross-cutting assets used every week: break/fix library, drills, Anki decks, interview bank, templates |
| **[`_reference/`](_reference/)** | 623 files of curated, **anonymized** long-form reference material, organized by topic |
| **[`projects/`](projects/)** | The three flagship projects — starter structure plus validated reference implementations |

---

## The three flagship projects

| | Project | Weeks | Status |
|---|---|---|---|
| **ALPHA** | [`projects/alpha-cloud-foundation/`](projects/alpha-cloud-foundation/) | 10–13 | **Complete reference implementation.** 7 Terraform configs, all `validate`-clean and `fmt`-clean, tflint-clean. |
| **BRAVO** | [`projects/bravo-secure-delivery/`](projects/bravo-secure-delivery/) | 17–21 | Structure + threat model + control narrative. Pipeline and policies live in weeks 18–19 solutions. |
| **CHARLIE** | [`projects/charlie-platform/`](projects/charlie-platform/) | 22–24 | Contract, JSON schema, **working validator**, CLI, workflows, docs. |

---

## The `_shared/` assets

| | Contents |
|---|---|
| [`breakfix/`](_shared/breakfix/) | **64 break/fix scenarios** with full diagnosis and solutions, across Linux, networking, containers, AWS, Terraform/CI, Kubernetes, security/observability, and cluster nodes |
| [`drills/`](_shared/drills/) | Subnetting (with answer key and a generator), kubectl speed, bash one-liners, PromQL, Terraform recall, AWS comparisons |
| [`anki/`](_shared/anki/) | Four importable TSV decks |
| [`interview-bank/`](_shared/interview-bank/) | ~60 questions with **model answers** across fundamentals, cloud/IaC, Kubernetes/security, system design, and behavioral |
| [`templates/`](_shared/templates/) | Project README, ADR, postmortem, runbook, STAR story, `service.yaml` |
| [`cheatsheets/`](_shared/cheatsheets/) | Index into the reference library's 13+ cheat sheets |

---

## The `_reference/` library

623 files, ~338,000 lines, curated from an existing curriculum corpus and **fully anonymized**
(see [SOURCES.md](SOURCES.md)).

| Topic | Files | Lines |
|---|---|---|
| `aws/` | 118 | 43k |
| `devsecops/` | 138 | 63k |
| `kubernetes/` | 92 | 58k |
| `terraform/` | 97 | 15k |
| `linux-networking/` | 43 | 41k |
| `cicd-gitops/` | 41 | 29k |
| `observability-sre/` | 29 | 30k |
| `platform-engineering/` | 23 | 25k |
| `containers/` | 31 | 21k |
| `case-studies/` | 16 | 12k |

Each week's README maps directly to the specific reference files for that week — you are never asked
to find something.

**Start at [`_reference/README.md`](_reference/README.md)** for the map, and
**[`_reference/MASTERY.md`](_reference/MASTERY.md)** for how to turn 342,000 lines of input into
something you can actually explain: the Feynman loop, the three levels of knowing, and the ten traces
that separate *using* these tools from understanding them.

> **The one rule for this library: read to answer a question you already have.** Reading to "cover" a
> domain produces the feeling of understanding without the thing itself, and from the inside the two
> are identical.

---

## How a week works

**`week-NN/`**

| File | What it is |
|---|---|
| `README.md` | objectives · day-by-day plan · reading map · drills · exit criteria |
| `labs/` | the actual work, with commands |
| `solutions/` | worked answers, plus RUNNING CODE where relevant |
| `assessment.md` | self-test with a full answer key and a scoring rubric |


**Open the solutions only after a genuine attempt.** Reading a solution feels like learning and
isn't — that's the 70/30 rule from [`../ROADMAP.md`](../ROADMAP.md) R2.

---

## The six gates

Progress is gated, not assumed. Each gate is **demonstrated**, not self-assessed.

| Gate | Week | Criterion |
|---|---|---|
| **1** | [4](week-04/assessment.md) | Fresh VM → containerized app behind Nginx with TLS, systemd-managed. Explain the full packet path. CIDR math, no calculator. |
| **2** | [9](week-09/assessment.md) | 80%+ on two different full-length SAA practice exams |
| **3** | [13](week-13/assessment.md) | `terraform apply` from a clean AWS account produces a working Alpha; zero static credentials |
| **4** | [17](week-17/assessment.md) | Five broken-cluster scenarios diagnosed unaided, under 15 min each, narrated |
| **5** | [21](week-21/assessment.md) | Pipeline blocks a critical CVE and refuses an unsigned image, live |
| **6** | [26](week-26/assessment.md) | A stranger deploys a service via PR in under 10 minutes |

---

## Verified, not just written

Everything executable in this curriculum was checked:

| | |
|---|---|
| Project Alpha Terraform | `terraform validate` × 7 configs — all pass · `fmt -check` clean · `tflint` clean |
| Week 19 Rego policies | `conftest verify` — **6 tests, 6 passed** |
| Charlie validator | Runs; correctly accepts both examples and reports 7 distinct problems in a bad one |
| Charlie CLI | `bash -n` clean; `validate` and `tiers` execute |
| Week 1 `sysreport.sh` | `bash -n` clean; `--help` and error paths exercised |
| Week 4 Compose stack | `docker compose config` valid; `app.py` compiles |
| Week 14 Kubernetes manifests | `kubectl kustomize` builds 12 resources |
| All YAML | Parsed with `yaml.safe_load` — workflows, policies, manifests, SLO rules |
| All JSON | Parsed — IAM policies, the service schema |
