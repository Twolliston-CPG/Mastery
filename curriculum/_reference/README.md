# The reference library

623 files, ~342,000 lines, ten domains. **Do not read it.**

This is a lookup, not a course. The 26 weeks are the course; each week's `README.md` has a
**Reading map** that names the handful of files you need that week. Everything else is here for the
moment you hit something you cannot explain — which is the only moment it is worth opening.

| Domain | Files | Covers |
|---|---|---|
| [`linux-networking/`](linux-networking/) | 38 | Processes, permissions, filesystems, packages, networking from cables to DNS, troubleshooting |
| [`aws/`](aws/) | 118 | SAA-aligned: compute, storage, databases, integration, security, monitoring — plus practice exams |
| [`terraform/`](terraform/) | 97 | HCL, state, modules, workspaces, testing, HCP — Associate-aligned, with labs and challenges |
| [`containers/`](containers/) | 31 | Images, runtimes, Compose, then Kubernetes objects from pods to operators |
| [`kubernetes/`](kubernetes/) | 92 | Foundation → core ops → production → platform. The deepest domain here |
| [`cicd-gitops/`](cicd-gitops/) | 41 | Jenkins, GitLab, GitHub Actions, Argo CD, artifacts, releases, feature flags |
| [`devsecops/`](devsecops/) | 138 | Supply chain, scanning, policy, runtime — plus a full threat-modelling curriculum |
| [`observability-sre/`](observability-sre/) | 29 | Prometheus, Loki, tracing, SLOs, alerting, incident response, APM |
| [`platform-engineering/`](platform-engineering/) | 23 | Golden paths, developer experience, adoption, leadership, career |
| [`case-studies/`](case-studies/) | 16 | Ten worked architectures, anonymised, with the trade-offs left in |

## The one rule

**Read to answer a question you already have.** Reading to "cover" a domain produces the feeling of
understanding without the thing itself, and the feeling is indistinguishable from the inside.

If you cannot say what question you are opening a file to answer, close it and go write something
instead — a lab, a diagram, or a page in [`MASTERY.md`](MASTERY.md)'s explain drill.

## Every file ends with a Feynman check

At the bottom of all 623 files is a short block built from *that file's own headings*: three or four
things to explain on a blank page, a side-by-side of the same idea stated badly and stated properly,
and one trace to walk end to end.

Do it before you decide you are finished with a file. It takes five minutes and it is the only part
of reading that produces anything. **The gap it finds is never what you forgot — it is where you used
a word instead of a mechanism.**

Because of that block, the usual 70/30 hands-on/reading split is **relaxed inside this directory**: a
page that ends by demanding an explanation is not passive reading. That holds only if you actually
write the explanation. [`MASTERY.md`](MASTERY.md) has the reasoning and the worked examples.

## How to get mastery out of it

[**MASTERY.md**](MASTERY.md) — the Feynman loop applied to this material, the three levels of
knowing, worked level-1 → level-3 examples, and the ten traces that separate *using* these tools from
*understanding* them.

[**SOURCES.md**](SOURCES.md) — where to go when this library runs out. ~85 primary sources across
the ten domains, written by the people who built the thing: the kernel cgroup-v2 docs, the OCI specs,
the free Google SRE books, the AWS Builders' Library, the LWN namespaces series, Kubernetes the Hard
Way. **Every link goes to a specific page, not a documentation homepage** — a nav menu is not an
answer at 11pm. Every file's Feynman check links straight to its own domain's section.

Links are checked, not assumed: `python3 ../_shared/diagrams/check-diagrams.py --links .` curls every
external URL in this directory and reports what broke. Anonymised case-study hosts are excluded via
[`.linkcheck-ignore`](.linkcheck-ignore) — they are *supposed* to be unresolvable.

Three other things in `_shared/` do jobs this library cannot:

| | Does |
|---|---|
| [`_shared/breakfix/`](../_shared/breakfix/) | 58 scenarios. You break it, then diagnose it. The only way to learn what a failure *looks like* |
| [`_shared/drills/`](../_shared/drills/) | Speed and recall — subnetting, `kubectl`, PromQL, bash |
| [`_shared/interview-bank/`](../_shared/interview-bank/) | ~60 questions with model answers. Use it to **check** your explanation, never to learn one |

**Reading order, first time here:** [`MASTERY.md`](MASTERY.md) → one file from your current week →
its Feynman check → [`SOURCES.md`](SOURCES.md) only if the check found a gap you cannot close.

## A note on the diagrams

Every diagram in this library is a PNG with its Mermaid source collapsed underneath it. Blue is the
path to follow; orange-red is where the system refuses; grey is context. See
[`_shared/diagrams/STYLE.md`](../_shared/diagrams/STYLE.md).
