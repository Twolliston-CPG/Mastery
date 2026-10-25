# Week 4 — Python for Ops, Docker, and Gate 1

> **Thesis:** a container is not a small VM. It is a Linux process with restricted visibility —
> namespaces for what it can see, cgroups for what it can use. Understand that this week and
> Kubernetes in week 14 is a scheduling problem, not a magic problem.

| | |
|---|---|
| **Hours** | 35–45 |
| **Deliverable** | Public Compose stack: app + Postgres + Nginx, with README, diagram, RUNBOOK |
| **Break/Fix** | BF-19 – BF-24 |
| **★ GATE 1** | From a fresh VM, docs only: deploy the stack behind Nginx with TLS, managed by systemd, correct firewall rules — then explain the packet path browser → Python process. Plus CIDR math, no calculator. |

## The week in one figure

**Figure 4.1 — What a container actually is, and the stack Gate 1 asks you to deploy.** Top row: an image is built and becomes a process the kernel isolates. Bottom row: three of those processes behind the week-3 Nginx, managed by systemd. The gate is the whole picture, from a fresh VM, with docs only.

![Figure 4.1 — What a container actually is, and the stack Gate 1 asks you to deploy](content/figure-4.1-what-a-container-actually-is-and.png)

**Say it, badge by badge:** [`content/FIGURE.md`](content/FIGURE.md) — the spoken script for each of the 11 badges, about three and a half minutes; [`content/figure-4.1-numbered-spoken.pdf`](content/figure-4.1-numbered-spoken.pdf) is the printable two-page version. Read the figure before the day plan; say the script on Friday.

---

## Day plan
| Day | Focus | Lab |
|---|---|---|
| Mon | Python for ops: CLI, files, HTTP, errors | Lab 1 |
| Tue | Python: testing, packaging, `boto3` preview | Lab 2 |
| Wed | Docker fundamentals + what a container really is | Lab 3 |
| Thu | Dockerfiles: multi-stage, hardening, size | Lab 4 |
| Fri | Break/Fix + Compose stack | Lab 5, 6 |
| Sat | **Gate 1** + ship the deliverable | — |
| Sun | Month 1 retrospective; plan month 2 | — |

## Reading map
- `_reference/containers/01-container-concepts.md`
- `_reference/containers/02-docker-architecture.md`
- `_reference/containers/03-docker-images.md`
- `_reference/containers/04-dockerfile-best-practices.md`
- `_reference/containers/05-container-networking.md`
- `_reference/containers/06-container-storage.md`
- `_reference/containers/module/labs-lab-01-docker-fundamentals.md` … `labs-lab-04-docker-compose.md`
- `_reference/linux-networking/python/PYTHON_DEVOPS_ROADMAP.md` (skim for the Python-for-ops arc)

## Labs
[labs/LABS.md](labs/LABS.md) · [labs/FIGURES.md](labs/FIGURES.md) (figures 4.2 to 4.7, one per lab) · [solutions/SOLUTIONS.md](solutions/SOLUTIONS.md)

| # | Lab | Time |
|---|---|---|
| 1 | Python ops CLI — rewrite `sysreport` properly | 3h |
| 2 | Testing, packaging, and HTTP clients | 2h |
| 3 | Docker fundamentals: namespaces and cgroups | 3h |
| 4 | Dockerfiles: 1.2 GB → 20 MB | 3h |
| 5 | Break/Fix Friday #4 | 2h |
| 6 | The Compose stack (deliverable) | 4h |

## Exit criteria — this is Gate 1
- [ ] Python CLI with `argparse`, type hints, logging, tests, and JSON output
- [ ] Explain namespaces and cgroups and name which does what
- [ ] Explain every Docker exit code in BF-19
- [ ] Multi-stage build with a **measured** size reduction recorded in the README
- [ ] Compose stack with healthchecks, named volumes, and a non-root user
- [ ] **Gate 1 passed** (see [assessment.md](assessment.md))
- [ ] Month 1 retrospective written
