# Figures

> Every week opens with one figure and a spoken walkthrough, numbered badge by badge, so the
> week's mechanism can be explained out loud in about three minutes. The figure and its script
> live in that week's `content/` folder. The platform that runs the
> labs has its own set in [`_setup/ARCHITECTURE.md`](_setup/ARCHITECTURE.md).

## How to use a figure

1. **Read the figure first**, before the day plan. Follow the blue path, then the dashed context.
2. **Say the walkthrough out loud**, pointing at each badge. The target is the stated time at a
   normal pace; if a badge takes longer, that is the badge you do not own yet.
3. **Close the file and redraw it** on Friday, then again two weeks later and at the next gate.
   The exit criteria of most weeks are the badges; the schedule is below.
4. **Reuse it in interviews.** Each walkthrough is a three-minute answer to "explain X to me."

The visual language is one system across the curriculum: gray is structure, **blue is the path
to follow first**, orange-red is where something refuses or fails, washed boxes are stores. See
[`_shared/diagrams/STYLE.md`](_shared/diagrams/STYLE.md).

## The redraw schedule

A figure is retrieval practice, and retrieval only works spaced. Each figure is redrawn from memory
three times, with the file closed, and checked against its `content/FIGURE.md` afterwards:

| When | Which | Takes |
|---|---|---|
| Friday of week N, after break/fix | figure N.1 | 5 minutes |
| Sunday of week N+2, before planning the next week | figure N.1 again | 5 minutes |
| Sunday of the next gate week (4, 9, 13, 17, 21, 26; 30 for the CKA module) | every figure since the previous gate, cold | about 20 minutes |

Record each in the **Figures redrawn** column of `progress.md` with the badge where the order
slipped. The order is the argument; the badge that slipped is the mechanism you still hold as a word
rather than a cause, and it is the reading to reopen.

## The weekly figures

| Figure | Title | Badges |
|---|---|---|
| 1.1 | [A process on a Linux system, from the shell to the commit](week-01/content/FIGURE.md) | 10 |
| 2.1 | [From a URL to a packet, and the service that answers](week-02/content/FIGURE.md) | 10 |
| 3.1 | [Browser to backend: routing, NAT, firewall, TLS, and the reverse proxy](week-03/content/FIGURE.md) | 10 |
| 4.1 | [What a container actually is, and the stack Gate 1 asks you to deploy](week-04/content/FIGURE.md) | 11 |
| 5.1 | [How AWS decides, and how an instance gets credentials with no keys on disk](week-05/content/FIGURE.md) | 11 |
| 6.1 | [A two-AZ VPC, and what makes a subnet public](week-06/content/FIGURE.md) | 11 |
| 7.1 | [ALB to ASG to RDS, with the two numbers you measure](week-07/content/FIGURE.md) | 10 |
| 8.1 | [Decouple, encrypt, observe, and know what it costs](week-08/content/FIGURE.md) | 11 |
| 9.1 | [The consolidation loop that produces an 80 percent](week-09/content/FIGURE.md) | 11 |
| 10.1 | [What Terraform does when you type apply](week-10/content/FIGURE.md) | 11 |
| 11.1 | [Module contract, environments, and the count index shift](week-11/content/FIGURE.md) | 10 |
| 12.1 | [OIDC: how a workflow gets AWS credentials with no secret anywhere](week-12/content/FIGURE.md) | 11 |
| 13.1 | [Project Alpha as a reviewer sees it](week-13/content/FIGURE.md) | 13 |
| 14.1 | [What happens when you kubectl apply a Deployment](week-14/content/FIGURE.md) | 11 |
| 15.1 | [Nine ways a pod fails to start, and where each one lives](week-15/content/FIGURE.md) | 11 |
| 16.1 | [IRSA: how a pod gets AWS credentials without any credentials](week-16/content/FIGURE.md) | 12 |
| 17.1 | [The diagnostic ladder you narrate at Gate 4](week-17/content/FIGURE.md) | 11 |
| 18.1 | [The pipeline that refuses](week-18/content/FIGURE.md) | 12 |
| 19.1 | [Where each control sits: before the plan, at the door, on the wire, at runtime](week-19/content/FIGURE.md) | 10 |
| 20.1 | [From a request to an alert that means users are hurting](week-20/content/FIGURE.md) | 12 |
| 21.1 | [An incident, from the first alert to the postmortem that changes something](week-21/content/FIGURE.md) | 11 |
| 22.1 | [The golden path, as a product](week-22/content/FIGURE.md) | 11 |
| 23.1 | [One pull request to a running service](week-23/content/FIGURE.md) | 10 |
| 24.1 | [The documentation set and the stranger test](week-24/content/FIGURE.md) | 12 |
| 25.1 | [The interview kit, and where every piece of it comes from](week-25/content/FIGURE.md) | 11 |
| 26.1 | [The weekly cadence that carries months 6 to 10](week-26/content/FIGURE.md) | 10 |
| 27.1 | [A cluster you built by hand, and what kubeadm wrote](week-27/content/FIGURE.md) | 10 |
| 28.1 | [Everything the 2025 blueprint added, on your own cluster](week-28/content/FIGURE.md) | 10 |
| 29.1 | [The exam is a speed test, and this is the speed](week-29/content/FIGURE.md) | 10 |
| 30.1 | [Exam week: the second simulator session is the gate](week-30/content/FIGURE.md) | 10 |

## Lab figures

The week figure is the three-minute answer; the lab figures are the thirty-second answers underneath
it. A week that has them carries `labs/FIGURES.md`, numbered `W.2` upward (one per lab, in lab order),
each with four parts:

| Part | What it is for |
|---|---|
| The figure | Hand-written Mermaid in the house style, badges ① to ⑪ in speaking order, blue path first, orange where it refuses |
| **Say it, badge by badge** | The spoken script. Each line is a thirty-second interview answer |
| **Numbers to own** | Every concrete number in the lab, where it comes from, and why it matters. Mastery is being able to say these unprompted |
| **Prove it** | One command per badge that makes the mechanism visible on your own cluster or account |
| **The question a senior interviewer asks** | The one question the lab is secretly preparing you for, and which badges answer it |

Redraw cadence is the week's, after the week figure. Lab figures are plain Mermaid, validated by
`check-diagrams.py` and embedded as PNGs by `embed-figures.py`; they are not generated from a spec and
are edited by hand (edit the Mermaid inside the `<details>`, then re-run the embed). A struck-through
title is a lab with no mechanism to draw; its entry says why and what to redraw instead. **deeper:** marks a
Go deeper lab from the Kubernetes mastery ladder ([`../KUBERNETES-MASTERY.md`](../KUBERNETES-MASTERY.md)):
optional inside the week, mandatory for the ladder, redrawn once its lab is done. Every Friday
break/fix lab shares [Figure BF.0, the diagnostic loop](_shared/breakfix/FIGURE.md).

| Week | Lab figures |
|---|---|
| 1 | [1.2 to 1.7](week-01/labs/FIGURES.md) — the VM, the kernel as files, and a find that is safe · the mode bits, the directory x bit, and what a signal does · a log line to a report, the awk pipeline · sysreport.sh, from a strict shell to an exit code · Break/Fix Friday #1, four breaks and the loop they share · what a commit is, and the two ways to undo one |
| 2 | [2.2 to 2.6](week-02/labs/FIGURES.md) — a unit file to a restarted process, and where its logs go · the SSH door, hardened without locking yourself out, and a disk from a file · a /16 carved for three AZs, and the five addresses AWS keeps · one curl, as packets, states, and timings · Break/Fix Friday #2, four breaks and the loop they share |
| 3 | [3.2 to 3.7](week-03/labs/FIGURES.md) — a packet out of a private namespace, through NAT, past the firewall · your domain, from the registrar to a cached answer · nginx in front of two backends, and what 502 and 504 each mean · the chain of trust, and the three ways it fails · Break/Fix Friday #3, four breaks and the loop they share · rebase, conflicts, bisect, and a pull request against yourself |
| 4 | [4.2 to 4.7](week-04/labs/FIGURES.md) — a Python ops CLI, from argparse to an exit code · tests that pin the boundary, a package that installs, a client that cannot hang · a container is a process, and the four things that prove it · 1.2 GB to 20 MB, measured at every step · Break/Fix Friday #4, six container symptoms and the row each belongs to · the Compose stack, the week's deliverable |
| 5 | [5.2 to 5.6](week-05/labs/FIGURES.md) — ~~Lab 1~~ · how AWS decides, the evaluation order as a ladder · who may become a role, what it may do, and the cap on top · an instance from run-instances to a mounted disk, and a security group that names another · credentials with no keys on disk, and the SSRF that IMDSv2 closes |
| 6 | [6.2 to 6.6](week-06/labs/FIGURES.md) — what makes a subnet public · NAT, bastion versus Session Manager, and stateful versus stateless · endpoints instead of NAT, and flow logs that bisect · an object's life in a versioned bucket · the layers that keep a bucket private, and Friday |
| 7 | [7.2 to 7.6](week-07/labs/FIGURES.md) — from the client to a healthy target, and the two ways it fails · the ASG replaces what the health check condemns · the Multi-AZ failover, as a timeline you measured · the table is the index · a function with an ENI, and the timeout that must be shorter |
| 8 | [8.2 to 8.6](week-08/labs/FIGURES.md) — the life of a message, and the timeout that duplicates it · envelope encryption, and why KMS never sees your data · from a metric to a human, and every link that silently breaks · a private bucket served to the world, and the record that cannot be a CNAME · choose a DR tier, build pilot light, and know what it costs |
| 9 | [9.2 to 9.6](week-09/labs/FIGURES.md) — the whiteboard, with the badges you narrate in order · ~~Activity 2~~ · from the weakest exam domain to the thing you rebuild · ~~Activity 4~~ · ~~Activity 5~~ |
| 10 | [10.2 to 10.5](week-10/labs/FIGURES.md) — from HCL to a running instance, and the graph underneath · state, the lock, and the recovery path · import, move, drift, and who did it · Alpha kickoff, the repository skeleton |
| 11 | [11.2 to 11.6](week-11/labs/FIGURES.md) — a module is an API · count and for_each, before and after removing one · two environments, one set of modules · the gate stack, and a test that tests the guardrail · Break/Fix and the Alpha milestone — a secret in state, rotation first |
| 12 | [12.2 to 12.6](week-12/labs/FIGURES.md) — a workflow run from trigger to artifact, and the five rules · OIDC federation, the token, two trust policies, and no keys anywhere · the pipeline: gates, queue, approval, and the claim that pins prod · a container build with no keys: ECR, multi-arch, tags, attestations · branch protection that binds admins, and the Alpha milestone |
| 13 | [13.2 to 13.6](week-13/labs/FIGURES.md) — the alarm path, proven, and the teardown that finds what still bills · the measurements a hiring manager reads in ninety seconds · the clean-account test, and the measured recovery · Terraform Associate prep, the HCP run lifecycle · ~~Lab 5~~ |
| 14 | [14.2 to 14.7](week-14/labs/FIGURES.md) — a pod from manifest to running, and why delete is not kill · a rollout, and the datapath that reaches it · where a Secret lives, and where it leaks · the diagnostic ladder, describe before logs · the week-4 stack, as Kubernetes objects · **deeper:** the API, watched and audited |
| 15 | [15.2 to 15.8](week-15/labs/FIGURES.md) — what the kubelet throttles, kills, and restarts · who adds pods, who removes them, and who refuses to place them · a claim from Pending to Bound, and the modes that refuse · RBAC: who, may do what, where · the Gate 4 set, symptom to fault · a chart to a release, revision by revision · **deeper:** the scheduler, plugin by plugin |
| 16 | [16.2 to 16.7](week-16/labs/FIGURES.md) — what the EKS module creates, and what it costs · IRSA, the token's path from webhook to STS · two controllers that turn annotations into AWS resources · ArgoCD, the pull loop · three failures, and the bill · **deeper:** CSI, sidecar by sidecar |
| 17 | [17.2 to 17.4](week-17/labs/FIGURES.md) — ~~Lab 1~~ · nine symptoms, nine first commands · threat, control, evidence |
| 18 | [18.2 to 18.6](week-18/labs/FIGURES.md) — three scanners, one hard gate, and the proof that it refuses · five images, measured at every step · SBOM, a signature on the digest, and the admission check that enforces it · the SLSA ladder, and the four attacks it answers · the CVE you cannot fix, and the signature that did not move |
| 19 | [19.2 to 19.6](week-19/labs/FIGURES.md) — a plan becomes JSON, and a Rego rule refuses it · the admission path, and the two ways it locks you out · default deny, the DNS trap, and the CNI that must enforce it · a rotated secret reaching a file, and a detection rule tuned instead of silenced · a control in code, traced to the requirement an auditor will ask about |
| 20 | [20.2 to 20.6](week-20/labs/FIGURES.md) — a request becomes three signals, and the one line that keeps metrics small · metric type decides the function · one dashboard that answers in five seconds, and one page instead of fifteen · one request across two services, traced and logged as one investigation · from an SLI to a page, with the arithmetic |
| 21 | [21.2 to 21.5](week-21/labs/FIGURES.md) — the first ten minutes of an incident · six phases, timed, and the postmortem that changes something · runbooks you have run, chaos with a hypothesis, DORA you measured · the two demonstrations that are the project |
| 22 | [22.2 to 22.6](week-22/labs/FIGURES.md) — ~~Lab 1~~ · ~~Lab 2~~ · a service.yaml, validated, derived, and refused well · from one command to an open pull request · ~~Lab 5~~ |
| 23 | [23.2 to 23.6](week-23/labs/FIGURES.md) — the controller flow is already drawn · one contract, nine resources, and the policy nobody wrote by hand · one word becomes a paging decision · one pipeline for every service, and the cost before the merge · deprovisioning in the right order, and what leaks if you reverse it |
| 24 | [24.2 to 24.5](week-24/labs/FIGURES.md) — ~~Lab 1~~ · the stranger test, and what each hesitation means · ~~Lab 3~~ · ~~Lab 4~~ |
| 25 | [25.2 to 25.5](week-25/labs/FIGURES.md) — ~~Lab 1~~ · the six-step design method, with its minute budget · ~~Lab 3~~ · ~~Lab 4~~ |
| 26 | [26.2 to 26.6](week-26/labs/FIGURES.md) — the funnel, and where it stalls · ~~Activity 2~~ · ~~Activity 3~~ · ~~Activity 4~~ · ~~Activity 5~~ |
| 27 | [27.2 to 27.10](week-27/labs/FIGURES.md) — from a bare VM to three Ready nodes · who signed you, and for how long · a snapshot, a new directory, and the object that must disappear · one minor, control plane first · six ways a node fails, and the first command for each · **deeper:** the kubelet, every ten seconds · **deeper:** a CNI plugin in forty lines of bash · **deeper:** etcd under the cluster · **hard way:** the certificate and kubeconfig fan-out |
| 28 | [28.2 to 28.9](week-28/labs/FIGURES.md) — one base, many overlays, and a chart you did not write · three roles, one route, and the names that resolve · teach the API a kind, then give it a controller · fourteen objects, three minutes each · a cluster with no storage, and what each field decides · **deeper:** the controller you wrote, part by part · **deeper:** the Service datapath, three ways · **deeper:** five queries for one name |
| 29 | [29.2 to 29.6](week-29/labs/FIGURES.md) — the per-task ritual, and why the wrong context scores zero · the four troubleshooting families, and the first command of each · ~~Lab 3~~ · ~~Lab 4~~ · the triage order, and the two-minute rule |
| 30 | [30.2 to 30.7](week-30/labs/FIGURES.md) — ~~Lab 1~~ · ~~Lab 2~~ · exam day, from the day before to the note to self · ~~Lab 4~~ · after the result, both branches · **deeper:** the cluster you cannot afford |

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

- Weekly figures are rendered by `_shared/diagrams/generate-week-figures.py` from the specs in
  `_shared/diagrams/week_figures/`, in the same icon style as the project and platform figures.
  Each week's `content/` folder holds `figure-W.1-<slug>.png`, `FIGURE.md` (the spoken
  script), and `figure-W.1-numbered-spoken.pdf`: the printable two-page version, figure on page one,
  the script badge by badge on page two, printed with headless Chrome. **Edit the spec, not the generated files**, then re-run the generator; it
  rewrites the image, `FIGURE.md`, and the README section.
- The outputs are reproducible. The PNG is a pure function of the spec and the pinned toolchain
  (`_shared/diagrams/requirements.txt` plus the Graphviz version noted there); the PDF is dated from
  the last commit to the spec file, so an unchanged spec re-renders byte for byte and leaves no diff.
  CI's `figures-fresh` job runs the generator in `--docs-only` mode and fails if the committed
  `FIGURE.md` or README section has drifted from its spec, which is what a hand edit looks like.
- A spec is the figure's nodes, boundaries, and edges in a small Mermaid-shaped DSL (documented
  in the generator), an icon per node, and the script: an Open line, one spoken line per badge in
  badge order with the numbers that matter, and a Close line.
- Blue edges are the path to follow first; dashed gray is context; a crimson badge on every node
  is the number you point at.
- Validate with `python3 _shared/diagrams/check-diagrams.py` (relative links and images) before
  committing.
