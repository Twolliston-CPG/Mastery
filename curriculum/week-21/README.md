# Week 21 — SRE Practice and ⚑ Project Bravo ★ GATE 5

> **Thesis:** three blameless postmortems you actually wrote are worth more in a behavioral interview
> than any project README. They are the only artifact that proves you have operated something under
> pressure.

| | |
|---|---|
| **Hours** | 35–45 (incl. ~5h job search — you're 8 weeks into the pipeline) |
| **⚑ Deliverable** | **Project BRAVO shipped** |
| **★ GATE 5** | The pipeline **blocks a critical CVE** and **refuses an unsigned image**, demonstrated live. A PromQL query and a valid SLO written from scratch. |

## The week in one figure

**Figure 21.1 — An incident, from the first alert to the postmortem that changes something.** Three real incidents you ran and three blameless postmortems you wrote are worth more in a behavioral interview than any README. The blue path is the incident; the loop at the end is what makes the next one shorter.

![Figure 21.1 — An incident, from the first alert to the postmortem that changes something](content/figure-21.1-an-incident-from-the-first-alert.png)

**Say it, badge by badge:** [`content/FIGURE.md`](content/FIGURE.md) — the spoken script for each of the 11 badges, about three and a half minutes; [`content/figure-21.1-numbered-spoken.pdf`](content/figure-21.1-numbered-spoken.pdf) is the printable two-page version. Read the figure before the day plan; say the script on Friday.

---

## Day plan
| Day | Focus | Lab |
|---|---|---|
| Mon | Incident response, severity levels, on-call | Lab 1 |
| Tue | **Run three real incidents** — detect, diagnose, mitigate, postmortem | Lab 2 |
| Wed | Runbooks, chaos engineering, DORA metrics | Lab 3 |
| Thu | ⚑ Bravo: finish to acceptance criteria | Lab 4 |
| Fri | ⚑ Bravo: docs, evidence, control narrative. **Gate 5.** | Lab 4 |
| Sat | ⚑ Bravo demo video; 15 applications | — |
| Sun | Month 5 retrospective; **read week 22 — Charlie starts** | — |

## Reading map
- `_reference/observability-sre/content-08-sre-practices.md`
- `_reference/observability-sre/content-09-incident-management.md`
- `_reference/observability-sre/content-10-chaos-engineering.md`
- `_reference/observability-sre/labs-lab-07-sre-practices-README.md`
- `_reference/observability-sre/labs-lab-08-incident-management-README.md`
- `_reference/devsecops/implementation/09-resilience-dr-best-practices.md`
- **Free primary source:** the Google SRE Book, chapters on incident management and postmortem
  culture. Short, and the source for everything here.

**Templates:** `_shared/templates/POSTMORTEM-template.md`, `_shared/templates/RUNBOOK-template.md`

## Labs
[labs/LABS.md](labs/LABS.md) · [solutions/SOLUTIONS.md](solutions/SOLUTIONS.md)

## ★ GATE 5 — [assessment.md](assessment.md)
