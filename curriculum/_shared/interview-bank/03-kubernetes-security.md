# Interview Bank: Kubernetes, DevSecOps, Observability

---

### Q1. A pod is in CrashLoopBackOff. Walk me through it.

**This is the most-asked Kubernetes question at junior level.** They want the *method*.

**Model answer:**
> First, `kubectl logs <pod> --previous` — the `--previous` flag is the important part, because
> that's the crashed container's output, not the one currently starting.
>
> Then `kubectl describe pod` and read the events and the `Last State` block, which gives me the exit
> code. That branches the whole investigation:
>
> - **Exit 0** means the process finished normally — so it isn't a long-running server. Usually the
>   command runs and returns instead of staying in the foreground.
> - **Exit 1** is an application error. The logs will say.
> - **Exit 137** is SIGKILL, and in a container that's almost always the OOM killer. I'd confirm with
>   `OOMKilled: true` in describe, then either raise the memory limit or find the leak.
> - **Exit 139** is a segfault — and a surprisingly common cause is an architecture mismatch, an
>   arm64 image on amd64 nodes.
> - **No logs at all** means the container never started. Back to events: bad command, missing
>   volume, failed mount.
>
> And there's one case that trips people up: **logs look completely normal and it still restarts.**
> That means something external is killing it — almost always a liveness probe whose
> `initialDelaySeconds` is shorter than the app's startup time.

**That last case is what separates a good answer from a recited one.**

---

### Q2. Requests vs limits. What happens if you exceed each?

**Model answer:**
> The **request** is what the scheduler reserves — it decides *where* the pod can be placed. The
> **limit** is what the kernel cgroup enforces at runtime.
>
> The asymmetry is the part to know: **exceeding a CPU limit gets you throttled; exceeding a memory
> limit gets you killed.** CPU is compressible, memory isn't. So a CPU-limited app gets slow and a
> memory-limited app dies with exit 137.
>
> The combination also sets your QoS class. Requests equal to limits everywhere is `Guaranteed`.
> Requests below limits is `Burstable`. Neither set is `BestEffort` — and under node memory pressure,
> `BestEffort` pods are evicted first.
>
> Worth adding: scheduling is based on **requests, not actual usage**. I've seen a cluster sitting at
> 10% real CPU utilization that couldn't schedule anything, because requests were set far above what
> the workloads used.

---

### Q3. Liveness vs readiness probes. Why does the distinction matter?

**Model answer:**
> **Liveness failure restarts the container. Readiness failure removes it from Service endpoints
> without restarting it.**
>
> That difference matters enormously in one specific scenario. If you put a database connectivity
> check in a **liveness** probe, then a brief database blip fails liveness on every pod at once, and
> Kubernetes restarts your entire fleet simultaneously. You've turned a five-second database hiccup
> into a full outage, and the restarts hammer the database further as everything reconnects.
>
> So: liveness checks only whether the process itself is wedged — and honestly, if you can't name a
> deadlock it would catch, you may not need one. Dependency checks belong in **readiness**, where
> failing just takes the pod out of rotation until things recover.
>
> And `startupProbe` exists for slow-booting apps — it suppresses the other two until the app is up,
> so you don't have to set a huge `initialDelaySeconds` on liveness and lose fast failure detection
> forever after.

---

### Q4. A Service isn't routing traffic. How do you debug it?

**Model answer:**
> One command bisects it: `kubectl get endpoints <service>`.
>
> **No endpoints** means the Service's selector doesn't match any pod labels — or the pods exist but
> are failing readiness, so they're excluded. Compare `kubectl get svc -o yaml` selector against
> `kubectl get pods --show-labels`.
>
> **Endpoints present but connections refused** is a port or bind problem: `targetPort` doesn't match
> what the container listens on, or the app is bound to `127.0.0.1` instead of `0.0.0.0` — which is
> the single most common container networking bug and means it's only reachable from inside its own
> network namespace.
>
> If both look right, I'd check for a NetworkPolicy blocking it, and test from inside the cluster
> with a netshoot pod rather than assuming.

---

### Q5. What is IRSA and what problem does it solve?

**Model answer:**
> IAM Roles for Service Accounts. The problem it solves is that without it, a pod needing AWS access
> either uses the **node's** instance role — which means every pod on that node shares those
> permissions — or has static credentials mounted as a secret.
>
> With IRSA, the cluster has an OIDC identity provider registered in IAM. You annotate a Kubernetes
> ServiceAccount with a role ARN, and Kubernetes projects a signed service account token into the
> pod. The AWS SDK exchanges that token via `AssumeRoleWithWebIdentity` for temporary credentials
> scoped to that role.
>
> So each pod gets exactly the permissions it needs, credentials are short-lived and auto-rotated,
> and nothing sensitive is stored anywhere.
>
> EKS Pod Identity is the newer alternative — same goal, simpler setup, no OIDC provider per cluster
> and no trust policy editing, at the cost of being EKS-specific.

**When it breaks**, it's one of: missing role annotation on the SA, the trust policy's `sub` doesn't
match `system:serviceaccount:<ns>:<name>`, the OIDC provider isn't registered, or the pod isn't
actually using that ServiceAccount.

---

### Q6. What's an SBOM and why would you generate one?

**Model answer:**
> A Software Bill of Materials — a machine-readable inventory of every component in an artifact,
> in SPDX or CycloneDX format.
>
> The value is concrete and it's easiest to explain with a real scenario. When Log4Shell dropped,
> the urgent question at every company was "are we affected, and where?" Organizations without SBOMs
> spent days or weeks grepping through repositories and manually inspecting images. Organizations
> with SBOMs ran a query and had the answer in minutes.
>
> Practically: `syft` generates it in CI, you attach it to the image as an OCI artifact, and it
> becomes queryable. It's also increasingly a compliance requirement — US federal software
> procurement requires it.

---

### Q7. How does image signing work, and what does it actually protect against?

**Model answer:**
> `cosign` signs the image and stores the signature as a **separate OCI artifact in the registry**,
> tagged by the image's digest. Keyless signing uses an OIDC identity — your CI workflow's identity —
> and logs to a transparency ledger, so there's no key to manage or lose.
>
> Then admission control in the cluster verifies the signature before allowing the deployment, and
> refuses anything unsigned or signed by an unexpected identity.
>
> What it protects against is **registry compromise and image substitution** — someone pushing a
> malicious image to a tag you trust. It's supply-chain integrity, not vulnerability scanning; those
> are separate controls.
>
> The subtlety worth knowing: signatures attach to the **digest**, not the tag. So a `docker pull`
> and `push` to a different registry copies the image but leaves the signature behind — you need
> `cosign copy` or `crane copy`. It's also the argument for pinning digests rather than tags in
> production manifests.

---

### Q8. A critical CVE is blocking your release and there's no patched version. What do you do?

**This is a judgment question, not a technical one. They want to see your process.**

**Model answer:**
> First I'd establish whether it's actually exploitable in our context. Severity scores are
> context-free — a critical CVE in a code path we never execute is a very different risk from a
> medium one in our request handler. So: is the vulnerable function reachable from our code?
>
> Then, is there any fix at all — a patched version, a backport, a different library, or dropping the
> dependency.
>
> If not, can I mitigate rather than fix? A WAF rule, a NetworkPolicy blocking the relevant egress,
> dropping a capability, disabling the feature that reaches the vulnerable path.
>
> And if none of those work, I'd document an explicit exception with three things: a written
> justification of why it isn't exploitable here, the compensating control, and **an expiry date and
> an owner** so it comes back on the board rather than quietly becoming permanent.
>
> What I wouldn't do is disable the scanner, and I wouldn't block the release indefinitely either —
> both of those are ways of avoiding the decision rather than making it.

**The expiry date and named owner are what make this answer good.** They show you understand that
risk acceptance is a process, not a shrug.

---

### Q9. What are the four golden signals, and how would you alert on them?

**Model answer:**
> Latency, traffic, errors, and saturation.
>
> The principle I'd apply is **page on symptoms, diagnose with causes.** High CPU is a cause — and on
> its own it isn't an incident, it might just mean the machine is working efficiently. High error rate
> and high p99 latency are symptoms users actually feel, and those are what should wake someone up.
>
> Concretely I'd define an SLO — say 99.9% availability over 30 days, which is a 43-minute error
> budget — and alert on **burn rate** rather than a raw threshold. Multi-window: page if we're burning
> 14.4× over an hour, which means the budget is gone in about two days; open a ticket at 6× over six
> hours. That catches genuine fast burns without paging on every brief blip.
>
> And every alert needs a runbook. If I can't write down what a person should do at 3am, it shouldn't
> be a page — it should be a dashboard panel.

---

### Q10. Why should you never put a user ID in a Prometheus metric label?

**Model answer:**
> Because every unique combination of label values is a separate time series. A metric with a
> `user_id` label and a hundred thousand users is a hundred thousand series from one metric, and it
> multiplies combinatorially with every other label. That's a cardinality explosion, and it will OOM
> your Prometheus.
>
> The general rule is: **metrics are for aggregates and must be low cardinality. Unique identifiers
> belong in logs and traces.** If you need to answer "what happened to this specific request," that's
> a tracing question, not a metrics question.
>
> Same reason you normalize URL paths — `/users/{id}`, never `/users/12345`.

---

### Q11. How would you secure a Kubernetes cluster? Where would you start?

**Model answer (work outward through the 4 Cs):**
> I'd think about it in layers.
>
> **Code and image:** scan dependencies and images in CI, build minimal images — distroless, non-root,
> read-only root filesystem, all capabilities dropped — generate an SBOM, and sign the images.
>
> **Cluster:** RBAC with least privilege and no wildcard cluster-admin bindings; enforce the
> `restricted` Pod Security Standard on application namespaces; admission policy with Kyverno for
> things PSS doesn't cover, like requiring signed images and resource limits; NetworkPolicies with a
> default-deny posture; encrypt secrets at rest and prefer External Secrets over Kubernetes Secrets
> holding real values; audit logging on.
>
> **Cloud:** IRSA so pods get scoped credentials rather than the node role; private API endpoint;
> node IMDS locked down so pods can't reach the node's instance role.
>
> **Runtime:** Falco or equivalent for behavioral detection.
>
> If I had to pick where to *start*, it's RBAC and removing over-broad permissions — because it's the
> highest-impact and it's usually where the real exposure is.

**Then add the operational caveat:** roll out every admission policy in audit mode first, and exclude
system namespaces, because an enforcing policy applied cluster-wide will break the CNI and lock you
out. Saying that shows you've actually done it rather than read about it.
