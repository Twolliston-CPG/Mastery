# Sources

> **Not the provenance record.** This is the reading list: where to go to learn more. For how
> this curriculum's content was assembled and anonymized, see [`../SOURCES.md`](../SOURCES.md).

The reference library gets you to level 2 — mechanism. These get you to level 3, because they are
written by the people who built the thing, and they say what happens when it fails.

## Two rules

**1. Open a source to close a named gap.** Not to "learn Kubernetes." A source consumed without a
question produces the same familiarity-without-understanding that re-reading does — it just costs
more hours. If you cannot finish the sentence *"I am opening this because I cannot explain ___"*,
close the tab.

**2. Read the spec, not the blog post about the spec.** The blog post already threw away the edge
case you are about to hit. Primary sources are shorter than they look, and the section you need is
usually four pages.

Every link below goes to **a specific page**, not a documentation homepage. That is deliberate: a
nav menu is not an answer.

> **Link conventions.** Living docs use the vendor's floating-current URL (`.../latest/...`), so they
> stay right without maintenance. A version appears in a URL only where the version *is* the content.
> Books and dated reports carry their edition. Verify the whole file with
> `../_shared/diagrams/check-diagrams.py --links .`

---

<a id="linux-networking"></a>
## Linux & networking

| Source | Type | Open it when |
|---|---|---|
| [`man 7 namespaces`](https://man7.org/linux/man-pages/man7/namespaces.7.html) | Reference · free | You want to know what isolation *is*. Then [`man 7 cgroups`](https://man7.org/linux/man-pages/man7/cgroups.7.html) and [`man 7 capabilities`](https://man7.org/linux/man-pages/man7/capabilities.7.html) — the other two legs |
| [`man 2 clone`](https://man7.org/linux/man-pages/man2/clone.2.html) | Reference · free | You need the actual syscall that creates a "container". Read the `CLONE_NEW*` flags list |
| [Kernel docs — cgroup v2](https://docs.kernel.org/admin-guide/cgroup-v2.html) | Spec · free | **v2 is what your clusters run.** Most cgroup material online is v1 and now actively misleading. The `memory.*` and `cpu.*` interface sections are the ones |
| [Beej's Guide to Network Programming](https://beej.us/guide/bgnet/html/) | Guide · free | Sockets, and why a connection is identified by four numbers, not two |
| [Brendan Gregg — the USE method](https://www.brendangregg.com/usemethod.html) | Method · free | Something is slow and you are guessing. Utilisation, saturation, errors — for every resource, in order. [Linux perf tools](https://www.brendangregg.com/linuxperf.html) is the map of what to run |
| [What is eBPF?](https://ebpf.io/what-is-ebpf/) | Primer · free | You need the substrate under Cilium, Falco, Pixie and modern kernel observability. Programs in the kernel, verified, without modules |
| [*Bite Size Networking*](https://wizardzines.com/zines/bite-size-networking/) — Evans | Zine · paid | You want the working mental model in an evening rather than a month |
| *The Linux Programming Interface* — Kerrisk, 2010 | Book | The definitive one. 1500 pages; read chapters, never covers |

**Start here:** `man 7 namespaces`, then trace `docker run` against it and name each flag.

---

<a id="aws"></a>
## AWS

| Source | Type | Open it when |
|---|---|---|
| [Timeouts, retries and backoff with jitter](https://aws.amazon.com/builders-library/timeouts-retries-and-backoff-with-jitter/) | Essay · free | **Read this one first.** 15 minutes, and it changes how you write every client you touch afterwards |
| [Static stability using Availability Zones](https://aws.amazon.com/builders-library/static-stability-using-availability-zones/) | Essay · free | You need to explain why Multi-AZ is not "a copy in another building" |
| [Workload isolation using shuffle sharding](https://aws.amazon.com/builders-library/workload-isolation-using-shuffle-sharding/) | Essay · free | You need blast-radius reduction that is not just "add more instances" |
| [Avoiding fallback in distributed systems](https://aws.amazon.com/builders-library/avoiding-fallback-in-distributed-systems/) | Essay · free | Your retry logic is about to make an outage worse |
| [IAM policy evaluation logic](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_evaluation-logic.html) | Docs · free | **The exact order: SCP → resource policy → boundary → session → identity.** The one page that ends all IAM guesswork |
| [Instance Metadata Service (IMDSv2)](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/configuring-instance-metadata-service.html) | Docs · free | You need to say precisely what IMDSv2 changed and which attack it closed |
| [How a VPC works](https://docs.aws.amazon.com/vpc/latest/userguide/how-it-works.html) | Docs · free | You want "what makes a subnet public" answered by routing, not by a checkbox |
| [Well-Architected Framework](https://docs.aws.amazon.com/wellarchitected/latest/framework/welcome.html) | Framework · free | You need the vocabulary the exam and the design review both use |
| [AWS Architecture Center](https://aws.amazon.com/architecture/) | Patterns · free | You need a reference architecture to argue with |

The [full Builders' Library index](https://aws.amazon.com/builders-library/) is ~30 essays by principal
engineers and is the highest-value free AWS material that exists. For conference talks, search
re:Invent sessions by code — take `300` and `400` level, skip `200`.

**Start here:** *Timeouts, retries and backoff with jitter*.

---

<a id="terraform"></a>
## Terraform

| Source | Type | Open it when |
|---|---|---|
| [Purpose of Terraform state](https://developer.hashicorp.com/terraform/language/state/purpose) | Docs · free | **Start here.** Almost every confusing Terraform result is a three-way disagreement, and this is where that is spelled out. Then the [state overview](https://developer.hashicorp.com/terraform/language/state) |
| [`import` blocks](https://developer.hashicorp.com/terraform/language/import) | Docs · free | You are adopting existing infrastructure. Config-driven import, plannable, reviewable — not the old CLI command |
| [`moved` blocks](https://developer.hashicorp.com/terraform/language/moved) | Docs · free | You are refactoring modules and do not want `state mv` in anyone's shell history |
| [The test framework](https://developer.hashicorp.com/terraform/language/tests) | Docs · free | You want `terraform test` — native `.tftest.hcl`, no third-party harness |
| [`for_each`](https://developer.hashicorp.com/terraform/language/meta-arguments/for_each) | Docs · free | You need why `count` and `for_each` differ, and why it only bites you on deletion |
| [Associate (003) tutorial track](https://developer.hashicorp.com/terraform/tutorials/certification-003) | Labs · free | The official exam-aligned hands-on path |
| [`terraform-aws-modules/vpc` source](https://github.com/terraform-aws-modules/terraform-aws-vpc) | Code · free | **Read a well-made module's source.** Teaches composition, validation and `for_each` better than any tutorial |
| [AWS provider — `internal/service`](https://github.com/hashicorp/terraform-provider-aws/tree/main/internal/service) | Code · free | A resource behaves strangely. The Go source tells you exactly what it sends and when it forces replacement |
| *Terraform: Up & Running*, 3rd ed. — Brikman, 2022 | Book | You want opinions on layout, testing and state separation from someone who has been wrong before |

---

<a id="containers"></a>
## Containers

| Source | Type | Open it when |
|---|---|---|
| [LWN — namespaces in operation](https://lwn.net/Articles/531114/) | Articles · free | **The primary source.** Seven parts by the man-pages maintainer. This is where containers stop being magic |
| [OCI image-spec](https://github.com/opencontainers/image-spec/blob/main/spec.md) | Spec · free | You need to know what an image *is*, exactly. Shorter than you expect |
| [OCI runtime-spec — Linux config](https://github.com/opencontainers/runtime-spec/blob/main/config-linux.md) | Spec · free | The exact namespaces, cgroups, capabilities and seccomp a runtime is told to apply |
| [Kernel docs — cgroup v2](https://docs.kernel.org/admin-guide/cgroup-v2.html) | Spec · free | Limits, requests and OOM kills, at the level the kernel actually implements them |
| [Docker — build cache](https://docs.docker.com/build/cache/) | Docs · free | Your builds are slow. Layer invalidation rules, in order |
| [Docker — multi-stage builds](https://docs.docker.com/build/building/multi-stage/) | Docs · free | Your image is 1.2 GB and ships a compiler |
| [container.training](https://container.training/) | Slides · free | Free, deep, maintained workshop decks |
| *Container Security* — Liz Rice, 2020 | Book | You want the escape tree: what each isolation feature does, and how each one is defeated |

**Start here:** LWN part 1. Then explain why `privileged: true` is not "more access."

---

<a id="kubernetes"></a>
## Kubernetes

| Source | Type | Open it when |
|---|---|---|
| [Kubernetes the Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way) | Lab · free | **Do this once.** One weekend, every certificate generated and every component started by hand, and "the control plane" stops being a word |
| [Cluster architecture](https://kubernetes.io/docs/concepts/architecture/) | Docs · free | You need every component named and its job stated in one sentence |
| [Controllers](https://kubernetes.io/docs/concepts/architecture/controller/) and [workload controllers](https://kubernetes.io/docs/concepts/workloads/controllers/) | Docs · free | Your explanation of "reconciliation loop" is still a phrase rather than a mechanism |
| [API concepts — watch & resourceVersion](https://kubernetes.io/docs/reference/using-api/api-concepts/) | Docs · free | **Underread and important.** Everyone says "it watches the API." This is what that actually is: chunking, bookmarks, resource versions, and how a watch resumes |
| [Scheduling framework](https://kubernetes.io/docs/concepts/scheduling-eviction/scheduling-framework/) | Docs · free | You need the extension points by name — filter, score, reserve, permit, bind |
| [Service](https://kubernetes.io/docs/concepts/services-networking/service/) | Docs · free | You need why a Service has no logs and cannot be pinged |
| [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/) | Docs · free | You need what `baseline` and `restricted` each forbid, field by field |
| [Authorization](https://kubernetes.io/docs/reference/access-authn-authz/authorization/) | Docs · free | The full chain: authentication → authorization → admission, and what each can and cannot see |
| [Gateway API](https://gateway-api.sigs.k8s.io/) | Docs · free | **Ingress is effectively frozen; this is the successor.** Role-oriented: infrastructure, cluster operator and developer own different objects |
| [KEPs](https://github.com/kubernetes/enhancements/tree/master/keps) | Design docs · free | You want *why* a feature is shaped this way. Each has a motivation and a rejected-alternatives section |
| [`pkg/scheduler` source](https://github.com/kubernetes/kubernetes/tree/master/pkg/scheduler) | Code · free | Readable Go. Reading the filter plugins ends all vagueness about scheduling |
| *Programming Kubernetes* — Hausenblas & Schimanski, 2019 | Book | You want to understand controllers by writing one. The informer/workqueue chapter is the one |

---

<a id="cicd-gitops"></a>
## CI/CD & GitOps

| Source | Type | Open it when |
|---|---|---|
| [The four GitOps principles](https://opengitops.dev/#principles) | Spec · free | You need what separates GitOps from "we keep YAML in git". [Full text](https://github.com/open-gitops/documents/blob/main/PRINCIPLES.md) |
| [Argo CD — architecture](https://argo-cd.readthedocs.io/en/stable/operator-manual/architecture/) | Docs · free | You need which component does the diffing and where credentials actually live |
| [Argo CD — sync waves & hooks](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/) | Docs · free | Ordering matters and your migration ran after the deployment |
| [Flux — core concepts](https://fluxcd.io/flux/concepts/) | Docs · free | The other model. Read both; the differences are the content |
| [DORA — State of DevOps 2025](https://dora.dev/research/2025/dora-report/) | Report · free | You need current evidence, not 2018 numbers, to argue about delivery performance |
| [DORA capabilities catalogue](https://dora.dev/capabilities/) | Research · free | You want the specific practice that moves a specific metric |
| *Continuous Delivery* — Humble & Farley, 2010 | Book | The original. Deployment pipeline, build-once-promote, testing quadrants |

**Start here:** the four principles. Then say which one a `kubectl apply` inside CI violates.

---

<a id="devsecops"></a>
## DevSecOps

| Source | Type | Open it when |
|---|---|---|
| [SLSA threat model](https://slsa.dev/spec/v1.2/threats) | Framework · free | **Start here.** It names every point at which a build can be subverted; most teams defend three of them. [Current spec](https://slsa.dev/spec/) |
| [OWASP Top 10 (2025)](https://owasp.org/Top10/) | List · free | You need the shared vocabulary. It is a *awareness* document, not a standard — do not audit against it |
| [OWASP ASVS](https://owasp.org/projects/asvs) | Standard · free | You need actual, testable requirements. This is what the Top 10 is usually mistaken for |
| [OWASP Cheat Sheet Series](https://cheatsheetseries.owasp.org/) | Reference · free | You know the class of bug and need the correct fix, today |
| [NIST SP 800-218 (SSDF)](https://csrc.nist.gov/pubs/sp/800/218/final) | Standard · free | You need a secure-development control framework an auditor already accepts |
| [NIST SP 800-190](https://csrc.nist.gov/pubs/sp/800/190/final) | Standard · free | Container security risks, enumerated. The document your compliance team will cite at you |
| [NIST SP 800-207](https://csrc.nist.gov/pubs/sp/800/207/final) | Standard · free | You need what zero trust means from the source, before the vendor definition |
| [MITRE ATT&CK — Containers matrix](https://attack.mitre.org/matrices/enterprise/containers/) | Knowledge base · free | You are threat modelling and want real adversary behaviour instead of imagination. Small enough to read fully |
| [Sigstore overview](https://docs.sigstore.dev/about/overview/) | Docs · free | Keyless signing, transparency logs, and what an attestation actually contains |
| [CISA — SBOM](https://www.cisa.gov/sbom) | Policy · free | SBOM as a regulatory reality. What an SBOM answers that a scanner cannot |
| [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes) | Baseline · free | You need the hardened configuration with a rationale on every line |
| *Threat Modeling* — Shostack, 2014 | Book | You want STRIDE from the person who taught it at scale |

---

<a id="observability-sre"></a>
## Observability & SRE

| Source | Type | Open it when |
|---|---|---|
| [SRE Workbook — Alerting on SLOs](https://sre.google/workbook/alerting-on-slos/) | Chapter · **free** | **Start here.** The best thing written on why static thresholds page you at 3am for nothing. Multi-window, multi-burn-rate, with the arithmetic |
| [SRE Workbook — Implementing SLOs](https://sre.google/workbook/implementing-slos/) | Chapter · free | You have a target but no idea how to pick the window, the SLI or the threshold |
| [SRE Book — Service Level Objectives](https://sre.google/sre-book/service-level-objectives/) | Chapter · free | You need SLI vs SLO vs SLA stated properly, and why you never alert on a mean |
| [SRE Book — Postmortem Culture](https://sre.google/sre-book/postmortem-culture/) | Chapter · free | Your incident reviews are finding people instead of causes |
| [My Philosophy on Alerting](https://docs.google.com/document/d/199PqyG3UsyXlwieHaqbGiWVa8eMWi8zzAn0YfcApr8Q/preview) — Ewaschuk | Memo · free | Your alerts are noisy. Ten pages, and the origin of symptom-based alerting |
| [PromQL basics](https://prometheus.io/docs/prometheus/latest/querying/basics/) | Docs · free | PromQL is still guesswork. Instant vector vs range vector is the whole thing |
| [Prometheus configuration](https://prometheus.io/docs/prometheus/latest/configuration/configuration/) | Docs · free | A target is missing. Service discovery and `relabel_configs` live here |
| [Metric naming practices](https://prometheus.io/docs/practices/naming/) | Docs · free | Before you add a label. Cardinality is a cost you pay forever |
| [OTel — traces](https://opentelemetry.io/docs/concepts/signals/traces/) | Docs · free | Spans, context propagation, and why a trace breaks at an async boundary |
| [OTel — semantic conventions](https://opentelemetry.io/docs/concepts/semantic-conventions/) | Spec · free | **The underused half.** Agreed attribute names are what make traces queryable across services |
| [OTel Collector](https://opentelemetry.io/docs/collector/) | Docs · free | You need to know where sampling, redaction and routing actually happen |
| *Observability Engineering* — Majors, Fong-Jones, Miranda, 2022 | Book | You need the case for high-cardinality events over pre-aggregated metrics |

---

<a id="platform-engineering"></a>
## Platform engineering

| Source | Type | Open it when |
|---|---|---|
| [Team Topologies — key concepts](https://teamtopologies.com/key-concepts) | Summary · free | **Start here**, then the book. Four team types, three interaction modes, and why cognitive load is the real constraint |
| [CNCF Platforms White Paper](https://tag-app-delivery.cncf.io/whitepapers/platforms/) | Paper · free | You need the maturity model and the vocabulary for a platform proposal that gets funded |
| [Backstage — software templates](https://backstage.io/docs/features/software-templates/) | Docs · free | You are building the golden path itself. Scaffolder actions and parameter forms |
| [Backstage — software catalog](https://backstage.io/docs/features/software-catalog/) | Docs · free | You need the entity model — the part that makes or breaks adoption |
| [DORA capabilities](https://dora.dev/capabilities/) | Research · free | You need evidence that the platform work will move a number |
| *Team Topologies* — Skelton & Pais, 2019 | Book | The foundational text |
| *The DevOps Handbook*, 2nd ed. — Kim, Humble, Debois, Willis, 2021 | Book | You need the flow/feedback/learning framing to justify the work |

**Start here:** the cognitive-load concept. It is why golden paths exist at all.

---

<a id="case-studies"></a>
## Architecture & incidents

| Source | Type | Open it when |
|---|---|---|
| *Designing Data-Intensive Applications* — Kleppmann, 2017 | Book | **Read this one cover to cover.** Replication, partitioning, consistency, consensus. The book that separates senior from staff |
| [danluu/post-mortems](https://github.com/danluu/post-mortems) | Collection · free | A curated list of real public incident write-ups. Read them as case studies: name the two weaknesses that had to compose |
| [Cloudflare outage postmortems](https://blog.cloudflare.com/tag/outage/) | Postmortems · free | Unusually detailed, unusually fast, unusually candid. The current gold standard |
| [AWS post-event summaries](https://aws.amazon.com/premiumsupport/technology/pes/) | Postmortems · free | What large-scale failure looks like when written honestly |
| [SRE Book — Postmortem Culture](https://sre.google/sre-book/postmortem-culture/) | Chapter · free | You want to write one, not just read them |
| [AWS Builders' Library](https://aws.amazon.com/builders-library/) | Essays · free | The failure modes, described before they happen to you |

**Start here:** any three postmortems from `danluu/post-mortems`. For each, name the single control
that would have broken the chain. That is the skill the case studies in this library are training.

---

## The five, if you only do five

In order of change-in-thinking per hour spent:

1. **[Kubernetes the Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way)** — one weekend, and the control plane becomes concrete
2. **[SRE Workbook, *Alerting on SLOs*](https://sre.google/workbook/alerting-on-slos/)** — alerting stops being superstition
3. **[Timeouts, retries and backoff with jitter](https://aws.amazon.com/builders-library/timeouts-retries-and-backoff-with-jitter/)** — then *[Static stability](https://aws.amazon.com/builders-library/static-stability-using-availability-zones/)*
4. **[LWN namespaces series](https://lwn.net/Articles/531114/)** — containers stop being magic
5. **[*Designing Data-Intensive Applications*](https://dataintensive.net/)** — the one book that keeps paying out for a decade

Four of the five are free. The fifth is a book.

---

## What to do with a source

Same loop as everything else in [`MASTERY.md`](MASTERY.md):

1. **Arrive with the gap already named**
2. Read only the section that answers it
3. **Close it and explain the answer from memory**
4. If you cannot, you read it; you did not learn it — go back once, then stop and go build something

A source you cannot explain afterwards was entertainment. That is allowed, but do not count it as study.
