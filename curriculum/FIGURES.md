# Figures

> Every week opens with one figure and a spoken walkthrough, numbered badge by badge, so the
> week's mechanism can be explained out loud in about three minutes. The platform that runs the
> labs has its own set in [`_setup/ARCHITECTURE.md`](_setup/ARCHITECTURE.md).

## How to use a figure

1. **Read the figure first**, before the day plan. Follow the blue path, then the dashed context.
2. **Say the walkthrough out loud**, pointing at each badge. The target is the stated time at a
   normal pace; if a badge takes longer, that is the badge you do not own yet.
3. **Close the file and redraw it** on Friday. The exit criteria of most weeks are the badges.
4. **Reuse it in interviews.** Each walkthrough is a three-minute answer to "explain X to me."

The visual language is one system across the curriculum: gray is structure, **blue is the path
to follow first**, orange-red is where something refuses or fails, washed boxes are stores. See
[`_shared/diagrams/STYLE.md`](_shared/diagrams/STYLE.md).

## The 26 weekly figures

| Figure | Title | Badges |
|---|---|---|
| 1.1 | [A process on a Linux system, from the shell to the commit](week-01/README.md#the-week-in-one-figure) | 10 |
| 2.1 | [From a URL to a packet, and the service that answers](week-02/README.md#the-week-in-one-figure) | 10 |
| 3.1 | [Browser to backend: routing, NAT, firewall, TLS, and the reverse proxy](week-03/README.md#the-week-in-one-figure) | 10 |
| 4.1 | [What a container actually is, and the stack Gate 1 asks you to deploy](week-04/README.md#the-week-in-one-figure) | 11 |
| 5.1 | [How AWS decides, and how an instance gets credentials with no keys on disk](week-05/README.md#the-week-in-one-figure) | 11 |
| 6.1 | [A two-AZ VPC, and what makes a subnet public](week-06/README.md#the-week-in-one-figure) | 11 |
| 7.1 | [ALB to ASG to RDS, with the two numbers you measure](week-07/README.md#the-week-in-one-figure) | 10 |
| 8.1 | [Decouple, encrypt, observe, and know what it costs](week-08/README.md#the-week-in-one-figure) | 11 |
| 9.1 | [The consolidation loop that produces an 80 percent](week-09/README.md#the-week-in-one-figure) | 11 |
| 10.1 | [What Terraform does when you type apply](week-10/README.md#the-week-in-one-figure) | 11 |
| 11.1 | [Module contract, environments, and the count index shift](week-11/README.md#the-week-in-one-figure) | 10 |
| 12.1 | [OIDC: how a workflow gets AWS credentials with no secret anywhere](week-12/README.md#the-week-in-one-figure) | 11 |
| 13.1 | [Project Alpha as a reviewer sees it](week-13/README.md#the-week-in-one-figure) | 13 |
| 14.1 | [What happens when you kubectl apply a Deployment](week-14/README.md#the-week-in-one-figure) | 11 |
| 15.1 | [Nine ways a pod fails to start, and where each one lives](week-15/README.md#the-week-in-one-figure) | 11 |
| 16.1 | [IRSA: how a pod gets AWS credentials without any credentials](week-16/README.md#the-week-in-one-figure) | 12 |
| 17.1 | [The diagnostic ladder you narrate at Gate 4](week-17/README.md#the-week-in-one-figure) | 11 |
| 18.1 | [The pipeline that refuses](week-18/README.md#the-week-in-one-figure) | 12 |
| 19.1 | [Where each control sits: before the plan, at the door, on the wire, at runtime](week-19/README.md#the-week-in-one-figure) | 10 |
| 20.1 | [From a request to an alert that means users are hurting](week-20/README.md#the-week-in-one-figure) | 12 |
| 21.1 | [An incident, from the first alert to the postmortem that changes something](week-21/README.md#the-week-in-one-figure) | 11 |
| 22.1 | [The golden path, as a product](week-22/README.md#the-week-in-one-figure) | 11 |
| 23.1 | [One pull request to a running service](week-23/README.md#the-week-in-one-figure) | 10 |
| 24.1 | [The documentation set and the stranger test](week-24/README.md#the-week-in-one-figure) | 12 |
| 25.1 | [The interview kit, and where every piece of it comes from](week-25/README.md#the-week-in-one-figure) | 11 |
| 26.1 | [The weekly cadence that carries months 6 to 10](week-26/README.md#the-week-in-one-figure) | 10 |

## The lab platform and its guardrails

| Figure | Title |
|---|---|
| S.1 | [The repository as a system](_setup/ARCHITECTURE.md#figure-1--the-repository-as-a-system) |
| S.2 | [Commit to merge](_setup/ARCHITECTURE.md#figure-2--commit-to-merge) |
| S.3 | [The repository as code](_setup/ARCHITECTURE.md#figure-3--the-repository-as-code) |
| S.4 | [GCP lab topology](_setup/ARCHITECTURE.md#figure-4--gcp-lab-topology) |
| S.5 | [GCP state and image supply chain](_setup/ARCHITECTURE.md#figure-5--gcp-state-and-image-supply-chain) |
| S.6 | [AWS lab topology](_setup/ARCHITECTURE.md#figure-6--aws-lab-topology) |
| S.7 | [The kind cluster](_setup/ARCHITECTURE.md#figure-7--the-kind-cluster) |
| S.8 | [Nightly teardown](_setup/ARCHITECTURE.md#figure-8--nightly-teardown) |
| S.9 | [The review](_setup/ARCHITECTURE.md#figure-9--the-review) |
| S.10 | [The link resolver](_setup/ARCHITECTURE.md#figure-10--the-link-resolver) |

## Adding or changing a figure

- Weekly figures are plain Mermaid in the week README under `## The week in one figure`, kept as
  the first H2 so a reader meets the mechanism before the schedule. Use the one-line theme header
  from `_shared/diagrams/theme.mmd`, circled numbers ① to ⑭ in node labels, and declare the
  blue-path edges first so `linkStyle 0,1,2…` stays correct.
- The walkthrough is a list: **Open**, one line per badge in badge order, **Close**. Quotes are
  spoken language, not documentation; numbers go in the lines, not in a separate table.
- Validate with `python3 _shared/diagrams/check-diagrams.py` (one second) and
  `bash _shared/diagrams/render.sh` (real render, a minute) before committing.
