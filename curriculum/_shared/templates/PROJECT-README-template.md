# <Project Name>

> One sentence stating the **problem this solves**, not the tech used.
> Good: "Provisions a new service from a pull request in under 10 minutes, with no platform-team ticket."
> Bad:  "Built with Terraform, AWS, Docker, and Kubernetes."

[![CI](https://github.com/<user>/<repo>/actions/workflows/ci.yml/badge.svg)](…)

**Demo:** [5-minute walkthrough](<video-link>)

## Architecture

![architecture](docs/architecture.png)

<Explain the flow in 3-5 sentences. Name the trade-off you made and why.>

## Quick start

```bash
git clone https://github.com/<user>/<repo> && cd <repo>
cp terraform.tfvars.example terraform.tfvars   # set your values
make deploy                                    # or: terraform init && terraform apply
```
Deploys in ~<N> minutes into a clean AWS account.

## What this demonstrates

- <capability 1, with the measurable outcome>
- <capability 2>
- <capability 3>

## Key decisions

| Decision | Chose | Rejected | Why |
|---|---|---|---|
| CI auth | OIDC federation | Static access keys | No long-lived credentials to leak or rotate |
| … | | | |

Full ADRs in [`docs/adr/`](docs/adr/).

## Measured results

| Metric | Value |
|---|---|
| Deploy time (PR → production) | |
| Recovery time after instance termination | |
| Image size (before → after hardening) | |
| CVE count (before → after) | |
| Monthly cost (dev / prod) | |

## What broke and how I fixed it

> **Do not skip this section.** It is the highest-signal part of the whole repo: it proves the
> project was built rather than copied, and it hands the interviewer a question you're ready for.

### 1. <Symptom in one line>
**What I saw:** …
**What was actually wrong:** …
**How I found it:** …
**Prevention:** …

### 2. …
### 3. …

## Cost

| Environment | Monthly | Notes |
|---|---|---|
| dev | $X | single AZ, spot, NAT instance |
| prod | $Y | Multi-AZ, managed NAT |

## Teardown

```bash
make destroy        # leaves nothing billable
```
Verify with `_setup/03-teardown.sh`.

## Repo layout

**`.`**

| File | What it is |
|---|---|
| `.github/workflows/` | CI pipelines |
| `docs/` | architecture, ADRs, runbooks |
| `modules/` | reusable Terraform modules |
| `environments/` | dev/ and prod/ root modules |

