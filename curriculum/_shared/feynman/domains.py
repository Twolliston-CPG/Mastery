"""Per-domain Feynman material: a weak/strong phrasing pair, a trace prompt,
and the one primary source that closes the most gaps in that domain.

The pair is the whole point of the block. A generic "explain it simply" note is
banner blindness by the third file; a concrete example of the SAME idea stated at
level 1 and level 2 shows the reader exactly what their own hand-waving sounds
like.
"""

DOMAINS = {
    "linux-networking": dict(
        weak="The kernel manages processes.",
        strong=("A process is an entry in the kernel's task table with its own memory map and "
                "file-descriptor table. `fork()` copies it, `exec()` replaces the program inside it, "
                "and the parent must call `wait()` or the entry stays behind as a zombie."),
        trace=("`ls -l /etc` → characters on your terminal. Name every syscall and every kernel "
               "structure between the keypress and the output."),
        source='[`man 7 namespaces`](https://man7.org/linux/man-pages/man7/namespaces.7.html) and the [LWN namespaces series](https://lwn.net/Articles/531114/) — the primary sources, not summaries of them',
    ),
    "aws": dict(
        weak="The security group allows the traffic.",
        strong=("A security group is a stateful allow-list attached to an ENI. Traffic matching an "
                "inbound rule is permitted and the reply is permitted automatically, because the "
                "connection is tracked — which is why you never write an outbound rule for a reply."),
        trace=("A request from the internet to an instance in a private subnet. Name every hop, "
               "every route-table lookup, and every rule evaluated, in order."),
        source="[Timeouts, retries and backoff with jitter](https://aws.amazon.com/builders-library/timeouts-retries-and-backoff-with-jitter/) — 15 minutes from the AWS Builders' Library, and it changes how you write every client you touch afterwards",
    ),
    "terraform": dict(
        weak="Terraform manages your infrastructure.",
        strong=("`plan` is a three-way comparison: the configuration (desired), the state file (what "
                "Terraform believes it created), and a refresh against the real API (what exists). "
                "Almost every confusing result is one of those three drifting from the other two."),
        trace=("`terraform apply` on one resource: config → plan → API call → state write. Then say "
               "what happens if the process dies between the API call and the state write."),
        source='[the purpose of Terraform state](https://developer.hashicorp.com/terraform/language/state/purpose) — almost every confusing result is a three-way disagreement, spelled out there',
    ),
    "containers": dict(
        weak="A container isolates the application.",
        strong=("A container is an ordinary Linux process started with namespaces (what it can see), "
                "cgroups (what it can use) and usually seccomp (what it may ask the kernel). There is "
                "no container object in the kernel — only a process with those features switched on."),
        trace=("`docker run` → an isolated process. Name the namespaces in the order they are "
               "created, and which component actually calls `clone()`."),
        source='the [LWN namespaces series](https://lwn.net/Articles/531114/) — seven parts by the man-pages maintainer, and the reason containers stop being magic',
    ),
    "kubernetes": dict(
        weak="Kubernetes schedules the pod.",
        strong=("The scheduler watches for pods with no `nodeName`, filters nodes by predicates, "
                "scores the survivors, and writes `nodeName` into the pod spec. The kubelet on that "
                "node is watching the API for pods bound to it, and starts the containers."),
        trace=("`kubectl apply -f pod.yaml` → a running container. Name every component that acts, "
               "in order, and what each one writes."),
        source='[Kubernetes the Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way) — one weekend, and "the control plane" stops being a word',
    ),
    "cicd-gitops": dict(
        weak="The pipeline deploys the application.",
        strong=("CI writes a new image tag into a config repository and stops. A controller running "
                "*inside* the cluster polls that repo, diffs the rendered manifests against live "
                "state, and applies the difference — so nothing outside the cluster ever holds "
                "credentials to it."),
        trace=("`git push` → the new version serving traffic, with nothing else typed. Name where "
               "the handoff between CI and CD happens, and what that handoff physically is."),
        source='the four [OpenGitOps principles](https://opengitops.dev/#principles) — then say which one a `kubectl apply` inside CI violates',
    ),
    "devsecops": dict(
        weak="We scan for vulnerabilities in the pipeline.",
        strong=("SAST reads source without running it, SCA resolves the dependency tree against an "
                "advisory database, and image scanning compares installed package versions to that "
                "same database. All three report what was known at build time — which is why the "
                "registry is re-scanned: the image does not change, the database does."),
        trace=("A CVE published today against your base image → a blocked deploy. Name every "
               "component between the advisory and the refused `apply`."),
        source='the [SLSA threat model](https://slsa.dev/spec/v1.2/threats) — it names every point at which a build can be subverted, and most teams defend three of them',
    ),
    "observability-sre": dict(
        weak="Prometheus monitors the service.",
        strong=("Prometheus discovers targets from the Kubernetes API, applies relabelling rules, "
                "scrapes `/metrics` over HTTP on an interval, and appends samples to a local TSDB. "
                "Nothing is pushed — so a target missing from a dashboard is a service-discovery "
                "problem, not an application one."),
        trace=("A latency regression → a phone ringing. Name each hop: sample, rule evaluation, "
               "alert state transition, routing, notification — and where each one can silently stop."),
        source='[SRE Workbook ch. 5, *Alerting on SLOs*](https://sre.google/workbook/alerting-on-slos/) — free, and the best thing written on why static thresholds page you for nothing',
    ),
    "platform-engineering": dict(
        weak="The platform makes developers more productive.",
        strong=("A golden path is a template that produces a repository with CI, manifests, "
                "dashboards and alerts already wired, so the product team owns none of them. It "
                "reduces cognitive load by removing decisions, not by adding features — and without "
                "a documented escape hatch it is a cage."),
        trace=("A developer commits `service.yaml` → a running service with a dashboard and a paging "
               "rule. Name every system that acts, and which team owns each one."),
        source='[Team Topologies — cognitive load](https://teamtopologies.com/key-concepts) and the [CNCF Platforms White Paper](https://tag-app-delivery.cncf.io/whitepapers/platforms/) — why golden paths exist at all',
    ),
    "case-studies": dict(
        weak="The architecture was badly designed.",
        strong=("The failure needed two independent weaknesses to compose. Name both, say why each "
                "one alone was survivable, and name the single control that would have broken the "
                "chain — that is the finding, not the vulnerability."),
        trace=("The incident in this file, from entry to objective. At every step name the control "
               "that should have stopped it, and why it did not."),
        source='three postmortems from [danluu/post-mortems](https://github.com/danluu/post-mortems) — for each, name the one control that would have broken the chain',
    ),
}

# A file directly under _reference/ with no domain folder.
DEFAULT = DOMAINS["kubernetes"]


def for_path(rel_parts) -> dict:
    return DOMAINS.get(rel_parts[0] if rel_parts else "", DEFAULT)
