# Interview Bank: Cloud, IaC, CI/CD

---

### Q1. What makes an AWS subnet public?

**Model answer:**
> Its route table has a route to an internet gateway. "Public" isn't a checkbox — it's a property of
> routing. A subnet with `0.0.0.0/0 → igw-xxx` is public; one with `0.0.0.0/0 → nat-xxx` is private.
>
> An instance also needs a public IP to be reachable inbound, which is the `map_public_ip_on_launch`
> setting or an Elastic IP.

**Follow-up:** "Instance in a public subnet with a public IP still can't be reached. Why?" → Security
group, NACL, or the OS firewall. Or nothing is listening. Walk them in that order.

---

### Q2. Security groups vs NACLs.

**Model answer:**
> Security groups are **stateful** and attach to an ENI. Allow rules only — there's no deny. All
> rules are evaluated together, so ordering doesn't exist. Because they're stateful, if you allow
> inbound 443, the response goes out automatically.
>
> NACLs are **stateless** and attach to a subnet. They have both allow and deny, and they're
> **numbered** — evaluated in order, first match wins. Because they're stateless you must
> explicitly allow the return traffic, which in practice means allowing inbound on the ephemeral
> port range 1024–65535.
>
> In practice I reach for security groups for almost everything, and NACLs only as a coarse subnet-
> level guardrail — like blocking a known-bad CIDR — because stateless rules are easy to get wrong.

**The detail that lands:** naming the ephemeral port range for NACL return traffic. That's the thing
people actually get burned by.

---

### Q3. How does an EC2 instance get AWS credentials without any keys on disk?

**Model answer:**
> Through an instance profile. You attach an IAM role to the instance, and the **instance metadata
> service** — a link-local endpoint at 169.254.169.254 — vends temporary STS credentials that the
> SDKs pick up automatically through the default credential chain. They rotate on their own and
> there's nothing to leak.
>
> Worth adding: you should enforce **IMDSv2**, which requires a PUT to get a session token before
> reading metadata. IMDSv1 was a plain GET, and that's what made SSRF vulnerabilities so dangerous —
> an attacker who could make the app fetch an arbitrary URL could fetch the credentials. IMDSv2's
> token requirement plus a hop limit of 1 closes that.

**Why this is a great question:** the IMDSv1/v2 detail connects an AWS feature to a real breach class,
and very few junior candidates can make that connection.

**The Kubernetes version of the same question:** IRSA, which is the same idea — a projected service
account token exchanged via the cluster's OIDC provider for temporary AWS credentials.

---

### Q4. RDS Multi-AZ vs read replicas.

**Model answer:**
> Completely different purposes, and people conflate them constantly.
>
> **Multi-AZ is for availability.** There's a synchronous standby in another AZ, AWS handles failover
> automatically by flipping the DNS endpoint, and in the classic single-standby setup the standby is
> **not readable** — it's sitting there purely so you survive an AZ failure. Typical failover is
> 60–120 seconds.
>
> **Read replicas are for scaling reads.** Asynchronous replication, so there's replication lag. They
> *are* readable, you can have several, they can live in other regions, and promotion is manual.
>
> You often want both: Multi-AZ for the availability requirement, read replicas for the read load.
> And Aurora blurs the line, because its replicas serve reads *and* act as failover targets.

**They will follow up:** "How would you scale writes?" → You can't with replicas. Options are vertical
scaling, sharding, moving write-heavy workloads to something horizontally scalable like DynamoDB, or
reducing writes with batching and caching.

---

### Q5. SQS vs SNS vs EventBridge.

**Model answer:**
> **SQS** is a queue — messages sit there until a consumer pulls them. One logical consumer group.
> You use it to decouple and to buffer, so a downstream slowdown doesn't propagate back as failure.
>
> **SNS** is pub/sub push fan-out — one message goes to many subscribers simultaneously. The classic
> pattern is SNS fanning out to several SQS queues, which gives you both broadcast and per-consumer
> buffering.
>
> **EventBridge** is pub/sub with content-based routing. You write rules that match on the event
> payload, and it has schema discovery, SaaS partner sources, and scheduling. It's the right choice
> for event-driven architecture where routing logic would otherwise live in application code.
>
> One thing worth stating: SQS standard queues are **at-least-once** by design, so consumers must be
> idempotent. That's not a bug to eliminate; it's a property to handle.

---

### Q6. What's in Terraform state and why does it matter?

**Model answer:**
> It's a JSON file mapping your configuration to real resource IDs, plus metadata and the dependency
> graph. Terraform needs it because there's no other way to know that `aws_instance.web` in your code
> is `i-0abc123` in the account.
>
> Three things make it matter operationally. It's stored **in plaintext**, including any secrets that
> passed through — and `sensitive = true` only hides values from CLI output, it doesn't encrypt
> anything. It's **shared mutable state**, so two concurrent applies will corrupt it, which is why
> locking exists. And it can **drift** from reality if someone changes things in the console.
>
> So the baseline is: remote backend on S3, encryption on, versioning on, locking enabled, and access
> restricted to the CI role.

**Follow-up:** "Someone deleted the state file." → If versioning is on, restore the previous version.
If not, you're rebuilding it with `terraform import` for every resource, which is genuinely painful —
and that's the argument for versioning.

---

### Q7. `count` vs `for_each`.

**Model answer:**
> `count` creates resources at positional indexes — `[0]`, `[1]`, `[2]`. `for_each` creates them at
> string keys from a map or set — `["a"]`, `["b"]`.
>
> The difference bites when you remove something from the middle. With `count`, removing the second
> of three items shifts index 2 down to index 1, so Terraform sees two resources whose configuration
> changed and destroys and recreates them. With `for_each`, removing key `"b"` destroys exactly
> `["b"]` and leaves the others untouched.
>
> So: `for_each` for a set of distinct named things, which is most of the time. `count` for "N
> identical copies" or the conditional `count = var.enabled ? 1 : 0` pattern.

**This is the most commonly asked Terraform question.** Have the subnet example ready — it's concrete
and it's break/fix BF-34.

---

### Q8. How do you handle secrets in Terraform?

**Model answer:**
> The honest answer is: avoid putting them there at all where you can.
>
> The layers I'd use, best to worst. Best is letting the provider generate and manage it so Terraform
> never sees the value — RDS has `manage_master_user_password` which puts it straight into Secrets
> Manager. Next is referencing an existing secret with a data source, so it's not in your code,
> though it does still land in state. Worst but sometimes necessary is generating it in Terraform
> with `random_password`.
>
> Either way the state backend must be encrypted with KMS, versioned, and locked down to the CI role,
> because **state is plaintext**. And if a secret does leak, the first action is rotation — the
> credential is burned, and no amount of cleaning up state changes that.

---

### Q9. Walk me through your CI/CD pipeline.

**Model answer (use your actual Project Alpha):**
> On a pull request: `terraform fmt -check`, `validate`, `tflint` for correctness, `checkov` for
> security policy, then `plan`, and the plan gets posted as a PR comment so the reviewer sees exactly
> what will change. Branch protection requires all of those to pass.
>
> On merge to main: a GitHub Environment with a required reviewer gates the `apply`. A concurrency
> group with `cancel-in-progress: false` queues runs, because cancelling a running apply leaves a
> stuck state lock and half-created infrastructure.
>
> The part I'd call out is authentication. There are **no AWS access keys anywhere** — the workflow
> requests an OIDC token from GitHub and exchanges it for a short-lived role via
> `AssumeRoleWithWebIdentity`. The trust policy pins the `sub` claim so only this repo, on a
> protected environment, can assume the production role.

**Then have your numbers:** total pipeline time, plan time, apply time, and how long from PR open to
production.

---

### Q10. Why OIDC instead of access keys in CI?

**Model answer:**
> Static access keys are long-lived credentials sitting in a secret store. If they leak — a log, a
> compromised action, a misconfigured fork — they work until someone notices and rotates them. And
> rotation is manual, so in practice it doesn't happen.
>
> With OIDC, GitHub mints a short-lived JWT for the specific workflow run. AWS trusts GitHub's OIDC
> provider and exchanges that token for STS credentials valid for an hour. Nothing is stored, nothing
> to rotate, nothing to leak.
>
> The important part is scoping the trust policy. The `sub` claim identifies the repo, and optionally
> the branch or environment. If you write `repo:org/repo:*`, **any branch in that repo can assume the
> role** — which means anyone who can open a PR reaches your AWS account. For a production role I pin
> it to `environment:production` and use a protected GitHub environment with required reviewers.

**That last paragraph is what makes this a strong answer** rather than a repeated blog post.

---

### Q11. Blue/green vs canary vs rolling.

**Model answer:**
> **Rolling** replaces instances gradually in place. Cheapest — no duplicate infrastructure — but both
> versions serve traffic during the rollout, and rollback means rolling forward again.
>
> **Blue/green** stands up a complete second environment, tests it, then switches traffic all at once.
> Instant rollback by switching back, which is its real value. Costs double during the cutover, and
> database schema changes are the hard part because both versions may need to work against one schema.
>
> **Canary** sends a small percentage — say 5% — to the new version, watches error rate and latency,
> and progressively increases if the metrics hold. It gives you the smallest blast radius, but it
> requires good observability, because a canary with no metrics is just a slower rolling deploy.
>
> Which I'd pick depends on what I can measure. Without solid SLI metrics, canary gives you nothing.

---

### Q12. Your Terraform plan shows it will destroy the production database. What do you do?

**Model answer:**
> Stop and don't apply. Then read the plan — Terraform marks the exact attribute with `# forces
> replacement`, so it tells you what changed.
>
> Usually it's one of a few things: someone changed an immutable attribute like the AZ or the
> identifier; a provider upgrade changed a default; or something drifted in the console and the plan
> is trying to reconcile it.
>
> Depending on which, the fix is reverting the config change, adding `ignore_changes` for an attribute
> managed elsewhere, or `terraform import` if state lost track of it.
>
> And the preventive answer: `prevent_destroy = true` on every production database, so this fails at
> plan time instead of depending on somebody reading carefully at 5pm on a Friday.
