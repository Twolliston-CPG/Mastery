# Week-by-Week Execution Plan

> 26 weeks. Each week: a focus, concrete labs, one shipped deliverable, recall drills, and an exit check.
> Daily shape and weekly rhythm are in [ROADMAP.md §3](ROADMAP.md#3-the-operating-system--how-a-day-and-a-week-are-built).

**Legend:** ★ = exam or milestone · ⚑ = flagship project work · ⚡ = Break/Fix Friday theme

---

## Month 1 · Foundations (weeks 1–4)

### Week 1 — Linux I + Git basics + environment

**Focus:** Stop being afraid of a terminal. Everything after this assumes fluency here.

**Learn:** filesystem hierarchy · permissions (rwx, octal, ownership, umask, setuid) · processes (`ps`, `top`, signals, `kill`, foreground/background, exit codes) · package management (apt/dnf) · pipes, redirection, `grep`, `find`, `sed`, `awk`, `jq` · vim survival (edit, save, quit, search) · Bash: variables, conditionals, loops, functions, arguments, `set -euo pipefail`.

**Labs:**
1. Provision a Ubuntu VM (Multipass, UTM, VirtualBox, or a $6/mo cloud VM). Do *not* use WSL only — learn a real VM lifecycle.
2. Write `sysreport.sh`: disk usage, memory, top 5 processes by CPU, failed systemd units, logged-in users. Must handle errors and accept `--json`.
3. Parse a 100k-line sample log with grep/awk to produce a top-10 IP-by-request-count table.
4. Set up dotfiles in a Git repo: `.bashrc`/`.zshrc`, aliases, `.gitconfig`.

**Git:** init, add, commit, log, diff, branch, checkout, merge, remote, push, pull, `.gitignore`. Conventional commit messages from day one — it is a free habit that reads as professional forever.

**⚡ Break/fix:** full disk (`/var` at 100%) · a process pinned at 100% CPU · a file that won't execute (permissions) · broken `$PATH`.

**Ship:** `sysreport.sh` in a public GitHub repo with a real README. First commit of the six months.

**Exit check:** navigate, inspect, and modify a Linux system without googling basic commands.

---

### Week 2 — Linux II + Networking I

**Focus:** systemd and the network stack. Subnetting gets drilled to automaticity this week.

**Learn:** systemd (units, services, targets, `systemctl`, writing a unit file, `journalctl` filtering) · users/groups/sudoers · SSH (keypairs, `~/.ssh/config`, agent forwarding, hardening sshd) · cron vs systemd timers · disks, partitions, filesystems, mounting, `/etc/fstab` · **networking:** OSI and TCP/IP models, MAC vs IP, **IPv4 addressing, CIDR, subnetting**, ports, TCP handshake and states, UDP, DHCP, ARP · tools: `ip`, `ss`, `dig`, `curl -v`, `traceroute`, `tcpdump`, `nc`.

**Labs:**
1. Write a systemd unit for last week's script, on a timer, logging to journald. Verify with `journalctl -u`.
2. Harden sshd: key-only auth, no root login, non-standard port. Confirm you can still get in *before* closing the old session.
3. **Subnetting drill — 100 problems.** Given a CIDR: network address, broadcast, usable host count, first/last host. Then: split a /16 into 8 subnets. Repeat daily until instant.
4. `tcpdump` a `curl` request; identify the DNS query, the TCP handshake, and the HTTP exchange in the capture.

**⚡ Break/fix:** service fails on boot (bad unit file) · SSH locked out (wrong permissions on `~/.ssh`) · "the network is down" (it's DNS).

**Ship:** blog post #1 — "What actually happens when you type a URL and hit enter." Force the explanation end to end.

**Exit check:** CIDR math without a calculator. Explain a TCP handshake from a packet capture.

---

### Week 3 — Networking II + Git collaboration + Nginx

**Focus:** routing, firewalls, proxies, and the collaboration workflow every job runs on.

**Learn:** routing tables and default gateways · NAT (SNAT/DNAT, why private subnets need it) · firewalls (nftables/ufw, stateful vs stateless — the mental model behind SG vs NACL later) · DNS deeply (record types, resolution path, TTL, caching, split-horizon) · HTTP/1.1 vs HTTP/2, methods, status codes, headers, cookies · TLS (handshake, certificates, chain of trust, SNI, Let's Encrypt) · load balancing (L4 vs L7, algorithms, health checks, sticky sessions) · reverse proxy concepts.

**Git:** rebase vs merge (and when each is correct) · interactive rebase and squashing · conflict resolution · PR workflow with review · tags and semantic versioning · `git bisect` · pre-commit hooks · branching strategies (trunk-based vs GitFlow, and why trunk-based won).

**Labs:**
1. Nginx as a reverse proxy in front of two backend servers; round-robin; health checks; observe failover when one dies.
2. TLS with a self-signed cert, then a real Let's Encrypt cert on a cheap domain (buy one — it's ~$12/yr and used for the rest of the program).
3. Deliberately create a 3-way merge conflict and resolve it. Then squash a 12-commit branch into 3 meaningful commits.
4. Trace DNS for a domain you own: `dig +trace`, understand every hop.

**⚡ Break/fix:** 502 Bad Gateway · expired certificate · firewall rule ordering blocking legitimate traffic · wrong default gateway.

**Ship:** blog post #2 — "Reverse proxies and TLS, explained by breaking them." Diagram included.

**Exit check:** explain SG-vs-NACL-style stateful/stateless firewalling before ever touching AWS.

---

### Week 4 — Python for ops + Docker ★ Gate 1

**Focus:** the automation language and the packaging format.

**Learn (Python):** types, collections, comprehensions · functions, modules, packages · file and JSON/YAML handling · `requests` · `argparse` CLIs · exceptions and logging · virtualenv and `requirements.txt` · `pytest` basics · type hints.

**Learn (Docker):** images vs containers vs registries · Dockerfile instructions and layer caching · **multi-stage builds** · `.dockerignore` · volumes and bind mounts · networks · port publishing · `docker compose` · image size optimization · non-root users · why containers are just namespaces + cgroups.

**Labs:**
1. Rewrite `sysreport.sh` in Python with `argparse`, logging, tests, and `--format json|table`.
2. Build a FastAPI or Flask app with a `/health` endpoint and one real route backed by a database.
3. Containerize it: naive Dockerfile first, then multi-stage + slim base + non-root. **Measure and record the size reduction** — that number goes in the README.
4. Compose stack: app + Postgres + Nginx, with a healthcheck and a named volume.

**⚡ Break/fix:** container exits immediately (bad CMD/ENTRYPOINT) · can't reach the container (port vs bind address) · data lost on restart (no volume) · image is 1.2 GB (no multi-stage).

**⚑ Ship:** the Compose stack, public, with README, architecture diagram, and RUNBOOK.md.

**★ GATE 1:** from a *fresh* VM with docs only — install Docker, deploy the stack behind Nginx with TLS, managed by systemd, correct firewall rules. Then explain the packet path from browser to Python process. Plus: CIDR math, no calculator.

---

## Month 2 · AWS core (weeks 5–9)

### Week 5 — AWS foundations, IAM, EC2

**Focus:** IAM is the thing that breaks in production more than anything else. Over-invest here.

**Day-one setup (before anything else):** budget alarms at $25/$50/$100 · billing alerts on · root MFA and no root keys · daily IAM user with MFA · admin role to assume · Cost Explorer enabled. Check the bill every Monday for 26 weeks.

**Learn:** global infrastructure (regions, AZs, edge) · the shared responsibility model · **IAM: users, groups, roles, policies, policy evaluation logic, trust policies, `sts:AssumeRole`, instance profiles, permission boundaries** · AWS CLI and profiles · EC2 (instance families, purchasing options, user data, metadata service and IMDSv2) · EBS volume types, snapshots · AMIs · security groups · key pairs.

**Labs:**
1. Write an IAM policy from scratch granting read-only access to one specific S3 prefix. Test it. Break it. Understand the error.
2. Set up cross-account role assumption between two accounts (or two roles in one).
3. Launch an EC2 instance with user data that installs and starts the week-4 app automatically.
4. Attach a role to the instance; call AWS APIs from it with no credentials on disk. **Understand exactly why that works.**

**⚡ Break/fix:** `AccessDenied` (walk the policy evaluation chain) · can't SSH (SG, NACL, route table, or key?) · instance can't reach the internet.

**Ship:** blog post #3 — "IAM policy evaluation, explained with the four times I got AccessDenied."

---

### Week 6 — VPC and S3

**Focus:** the network layer. Everything else in AWS lives inside decisions made here.

**Learn:** VPC, CIDR planning, subnets (public vs private — and what actually makes one "public") · route tables · internet gateway · NAT gateway vs NAT instance (and their cost difference) · security groups vs NACLs (stateful vs stateless — week 3 pays off) · VPC endpoints (gateway vs interface) · VPC peering and Transit Gateway at concept level · VPC Flow Logs · DNS in a VPC · **S3:** buckets, keys, storage classes, lifecycle policies, versioning, encryption (SSE-S3/SSE-KMS), bucket policies vs IAM policies vs ACLs, static website hosting, presigned URLs, S3 event notifications.

**Labs:**
1. Build a VPC by hand: 2 AZs, public + private subnets, IGW, NAT, route tables. **Draw it before building it.**
2. Place an instance in the private subnet; reach the internet through NAT; SSH via a bastion in the public subnet.
3. Replace the NAT gateway with a VPC endpoint for S3; confirm private-subnet S3 access with no NAT. Compare costs.
4. S3: enable versioning, set a lifecycle rule to Glacier at 30 days, write a bucket policy denying unencrypted uploads, generate a presigned URL.
5. Enable Flow Logs; find a rejected connection in them.

**⚡ Break/fix:** private instance can't reach the internet (missing NAT route) · S3 access denied (bucket policy vs IAM precedence) · overlapping CIDRs block a peering connection.

**Ship:** a hand-drawn-then-cleaned VPC architecture diagram. This becomes the Project Alpha diagram.

---

### Week 7 — Compute, scaling, databases

**Learn:** ELB family (ALB vs NLB vs GWLB — when each) · target groups, health checks, listener rules, path/host routing · Auto Scaling Groups, launch templates, scaling policies, lifecycle hooks · ECS on Fargate (task definitions, services) · Lambda (execution model, cold starts, layers, concurrency, event sources) · API Gateway basics · **RDS** (engines, Multi-AZ vs read replicas — a classic exam and interview distinction, backups, parameter groups) · Aurora · **DynamoDB** (partition/sort keys, capacity modes, GSI vs LSI, when NoSQL is right) · ElastiCache · Route 53 (record types, routing policies, health checks).

**Labs:**
1. ALB → ASG across 2 AZs, with a scaling policy. Load-test it and watch it scale.
2. Terminate an instance and watch the ASG replace it. Time the recovery.
3. RDS Multi-AZ: trigger a failover, measure the downtime, record the number.
4. DynamoDB table with a GSI; query by both access patterns from Python/boto3.
5. Deploy the week-4 container to ECS Fargate behind the ALB.

**⚡ Break/fix:** ALB returns 503 (unhealthy targets — why?) · ASG launches and immediately terminates · Lambda times out reaching RDS (VPC config + ENI).

**Ship:** blog post #4 — "Multi-AZ vs read replicas: I failed over an RDS instance to find out."

---

### Week 8 — Integration, security, monitoring, cost

**Learn:** SQS (standard vs FIFO, visibility timeout, DLQs) · SNS · EventBridge · Step Functions at concept level · decoupling patterns · CloudFront (origins, behaviors, caching, OAC) · **KMS** (CMKs, key policies, envelope encryption) · Secrets Manager vs Parameter Store · CloudWatch (metrics, logs, alarms, dashboards, Logs Insights) · CloudTrail · AWS Config · GuardDuty, Security Hub, Inspector at concept level · Organizations, OUs, SCPs · Well-Architected Framework's six pillars · **DR strategies: backup-restore → pilot light → warm standby → multi-site** with their RTO/RPO tradeoffs · cost: Savings Plans vs Reserved Instances vs Spot, tagging, Cost Explorer, Trusted Advisor.

**Labs:**
1. Decouple: API → SQS → Lambda worker, with a DLQ. Poison-pill a message and watch it land in the DLQ.
2. Encrypt an S3 bucket with a customer-managed KMS key; write the key policy; deny access from a role that has S3 permissions but no KMS permissions. **Understand why that fails.**
3. CloudWatch alarm on a custom metric → SNS → email. Trigger it deliberately.
4. Logs Insights query to find all 5xx responses in the last hour.
5. Tag everything; build a Cost Explorer view broken down by tag.

**⚡ Break/fix:** messages stuck invisible (visibility timeout) · KMS `AccessDenied` despite S3 permissions · alarm that never fires (wrong metric dimension).

**Ship:** blog post #5 — "Four DR strategies and what each one actually costs."

---

### Week 9 — SAA consolidation ★ Gate 2

**Focus:** exam readiness. This is the only week where exam prep dominates, and it is capped at one week by design.

**Plan:**
- Mon: full practice exam #1 cold. Score it. Categorize every miss by domain.
- Tue–Wed: targeted remediation on the two weakest domains only. Rebuild those services by hand.
- Thu: full practice exam #2. Review **every** question — including correct answers reached by guessing.
- Fri: practice exam #3 + a flashcard sweep of service limits, defaults, and the comparison pairs (ALB/NLB, Multi-AZ/read replica, SG/NACL, SQS/SNS/EventBridge, EBS/EFS/S3, Savings Plan/RI/Spot).
- Sat: whiteboard the full 3-tier architecture from memory, out loud, explaining every tradeoff.
- Sun: rest. Genuinely. Do not cram the day before.

**★ GATE 2:** 80%+ on two different full-length practice exams. Whiteboard the architecture from memory.

If the gate fails, **move the exam a week** rather than sitting it underprepared. A retake costs more time than a delay.

---

## Month 3 · IaC and CI/CD (weeks 10–13)

### Week 10 — ★ SAA EXAM · Terraform I

**Mon–Tue:** final review, then **sit the exam**. Take the rest of exam day off.

**Wed–Sun — Terraform fundamentals:** why IaC (and why not just scripts) · HCL syntax · providers and version constraints · resources, data sources · variables, `tfvars`, locals, outputs · expressions and functions · **state: what it contains, why it's sensitive, why it corrupts** · `init`/`plan`/`apply`/`destroy` · the dependency graph, implicit vs explicit (`depends_on`) · remote backend on S3 with locking · `terraform import`, `state mv`, `state rm` · drift.

**Labs:**
1. Terraform the week-5 EC2 instance. Then destroy and re-apply until it's muscle memory.
2. Set up the S3 remote backend with locking. **Deliberately corrupt local state and recover from remote.**
3. Import an existing console-created resource into Terraform. This is a real job skill and a common interview question.
4. Change a resource in the console, run `plan`, and read the drift.

**⚑ Project ALPHA kickoff** — see [PROJECTS.md](PROJECTS.md).

**⚡ Break/fix:** state lock stuck after a killed apply · `plan` shows a destroy-and-recreate you didn't want (which attribute forces replacement?) · provider version drift between machines.

---

### Week 11 — Terraform II: modules, patterns, testing ⚑

**Learn:** module authoring (inputs, outputs, versioning, composition) · root vs child modules · the registry · `count` vs `for_each` (and why `for_each` is almost always right) · dynamic blocks · `lifecycle` (`create_before_destroy`, `prevent_destroy`, `ignore_changes`) · environment strategies: **directories vs workspaces**, and why directories usually win for real environments · remote state data sources · secrets handling in Terraform (and what never goes in state) · validation: `fmt`, `validate`, `tflint`, `terraform-docs` · security scanning: `checkov` or `tfsec` · `terraform test`.

**Labs:**
1. Refactor Alpha into modules: `network/`, `compute/`, `database/`, `security/`.
2. Build `dev/` and `prod/` environments consuming the same modules with different inputs. Make prod Multi-AZ and dev single-AZ.
3. Add `for_each` to create subnets from a map. Delete one from the middle of the map and **observe that nothing else is destroyed** — then explain why `count` would have destroyed three.
4. Wire `tflint` + `checkov` + `terraform-docs` into pre-commit.

**⚑ Alpha:** networking and compute modules complete.

**⚡ Break/fix:** `count` index shift destroying the wrong resources · circular module dependency · a secret leaked into state (and what the actual remediation is).

**Ship:** blog post #6 — "count vs for_each: the day I deleted three subnets by removing one."

---

### Week 12 — CI/CD with GitHub Actions + OIDC ⚑

**Focus:** the pipeline, and killing static credentials forever.

**Learn:** CI/CD concepts, pipeline stages, fail-fast · GitHub Actions: workflows, events, jobs, steps, runners, matrices, artifacts, caching, reusable workflows, composite actions · secrets and environments with required reviewers · **OIDC federation from GitHub Actions to an AWS IAM role — no long-lived access keys, ever** · `terraform plan` on PR with the plan posted as a comment; `apply` on merge to main with approval · branch protection and required checks · trunk-based development · semantic versioning and automated releases · Docker build + push to ECR from CI.

**Labs:**
1. Set up the GitHub OIDC provider in AWS, an IAM role with a scoped trust policy, and a workflow that assumes it. **`grep -ri "AKIA"` must return nothing for the rest of the program.**
2. Pipeline: `fmt` → `validate` → `tflint` → `checkov` → `plan` → comment on PR → manual approval → `apply`.
3. Matrix build of the app container for amd64 and arm64; push to ECR with both a semver tag and the git SHA.
4. Add branch protection requiring all checks to pass.

**⚑ Alpha:** fully CI-deployed.

**⚡ Break/fix:** OIDC trust policy rejects the token (read the `sub` claim carefully) · workflow passes locally, fails in CI (environment differences) · apply races between two merged PRs.

**Ship:** blog post #7 — "Deleting every AWS access key from my CI, with OIDC." This post reliably gets read.

---

### Week 13 — Alpha completion + Terraform Associate prep ★ Gate 3 ⚑

**Mon–Thu — finish Project Alpha to acceptance criteria:** monitoring and alarms, a real README, architecture diagram, cost breakdown, teardown instructions, and a **"what broke"** section. Deploy it into a *clean* AWS account to prove the one-command claim.

**Fri–Sun — Terraform Associate prep** (~15 hrs is enough after 4 weeks of real use): sweep the official exam objectives, close gaps on the topics real work skips — Terraform Cloud/HCP workspaces, Sentinel at concept level, the exact CLI workflow questions — then two practice exams.

**★ GATE 3:** `terraform apply` from a clean account produces a working Alpha. CI runs plan-on-PR and apply-on-merge. Zero static credentials. State remote and locked.

---

## Month 4 · Kubernetes (weeks 14–17)

### Week 14 — ★ TERRAFORM ASSOCIATE EXAM ★ APPLICATIONS BEGIN · Kubernetes I

> **This is the hinge week.** Two certs done, Alpha shipped. The résumé is now true. Applications start — see [JOB-SEARCH.md](JOB-SEARCH.md). Do not postpone this.

**Mon:** sit the Terraform Associate exam.

**Tue–Wed — the job-search infrastructure (this is the week's real deliverable):** résumé built around Alpha and the two certs · LinkedIn rewritten, open-to-work on · GitHub profile README · a target list of 50 companies · the referral outreach script · a tracking spreadsheet. Then send the **first 10 applications.**

From here on: **10–15 quality applications per week, every week**, as a fixed cost of ~4 hrs. It does not come out of study time; it comes out of the week's slack.

**Thu–Sun — Kubernetes core:** why orchestration · control plane (API server, etcd, scheduler, controller manager) and node components (kubelet, kube-proxy, CRI/containerd) · the declarative model and reconciliation loops · Pods (lifecycle, multi-container patterns, init containers) · ReplicaSets, Deployments, rolling updates and rollbacks · Services (ClusterIP, NodePort, LoadBalancer) and how kube-proxy implements them · Ingress and ingress controllers · ConfigMaps and Secrets · namespaces, labels, selectors, annotations · `kubectl` fluency and imperative-to-YAML generation (`--dry-run=client -o yaml`).

**Labs:** kind or k3d cluster locally · deploy the week-4 app: Deployment + Service + Ingress · scale it, roll it out, roll it back · break the image tag and diagnose ImagePullBackOff · a multi-container pod with a sidecar.

**⚡ Break/fix:** `ImagePullBackOff` · `CrashLoopBackOff` · Pending pod (why? — unschedulable, resources, or taints) · Service returns nothing (selector mismatch — check the endpoints).

---

### Week 15 — Kubernetes II: operations and debugging

**Learn:** liveness / readiness / startup probes (and the damage a wrong liveness probe does) · resource requests and limits, QoS classes, OOMKilled · HorizontalPodAutoscaler · PodDisruptionBudgets · StatefulSets and headless Services · PersistentVolumes, PVCs, StorageClasses, reclaim policies · Jobs and CronJobs · DaemonSets · **RBAC** (Roles, ClusterRoles, bindings, ServiceAccounts) · taints, tolerations, node affinity, pod affinity/anti-affinity, topology spread · **Helm** (charts, values, templating, releases, upgrade/rollback) · the debugging toolkit: `describe`, events, `logs --previous`, `exec`, ephemeral containers, `port-forward`.

**Labs:**
1. Add probes to the app. Deliberately misconfigure the liveness probe and watch the restart loop. Fix it.
2. Set memory limits below what the app needs; get OOMKilled; read the exit code; fix it.
3. StatefulSet with persistent storage for Postgres. Delete the pod; confirm the data survives.
4. RBAC: a ServiceAccount that can read pods in one namespace and nothing else. Test both the allowed and denied paths.
5. Package the app as a Helm chart with dev and prod values files.

**⚡ Break/fix (build the five-scenario set for Gate 4 here):** OOMKilled · liveness restart loop · unschedulable due to taints · PVC stuck Pending · RBAC forbidden.

**Ship:** blog post #8 — "Nine ways a pod fails to start, and how to tell them apart." A decision tree diagram. This is the single most useful post for a junior's credibility.

---

### Week 16 — EKS + GitOps with ArgoCD

**Focus:** managed Kubernetes on AWS and declarative delivery. **EKS is billable — destroy nightly.**

**Learn:** EKS architecture, the managed control plane · cluster provisioning with Terraform (the community EKS module) · node groups: managed vs self-managed vs Fargate · authentication (access entries / `aws-auth`) · **IRSA and EKS Pod Identity — what problem they solve and how the token projection works** · AWS Load Balancer Controller · EBS/EFS CSI drivers · External Secrets Operator · cluster autoscaling concepts (Cluster Autoscaler vs Karpenter) · **GitOps:** pull vs push delivery, drift detection and self-healing, ArgoCD (Applications, projects, sync policies, sync waves, app-of-apps), Helm and Kustomize as ArgoCD sources.

**Labs:**
1. EKS cluster via Terraform. Managed node group on spot. **`terraform destroy` every single night.**
2. IRSA: a pod that reads a specific S3 bucket with no credentials mounted. Explain the full token exchange.
3. Install the ALB controller; expose the app via a real internet-facing ALB with TLS from ACM.
4. ArgoCD with app-of-apps. Change a manifest in Git → watch it sync. Change the cluster by hand → watch it revert.
5. External Secrets pulling from AWS Secrets Manager into a Kubernetes Secret.

**⚡ Break/fix:** IRSA returns `AccessDenied` (trust policy? annotation? OIDC provider?) · ALB never provisions (subnet tags) · ArgoCD stuck `OutOfSync` on an immutable field.

**Ship:** blog post #9 — "IRSA explained: how a pod gets AWS credentials without any credentials."

---

### Week 17 — Consolidation ★ Gate 4 · optional ★ KCNA

**Mon–Wed:** Kubernetes consolidation. Rebuild the whole app stack in a fresh kind cluster from memory. Run the five broken-cluster scenarios under a timer. Write Deployment + Service + Ingress + RBAC from a blank file, no reference.

**Thu–Fri:** **Decision point on KCNA** — see [ROADMAP.md R3](ROADMAP.md#r3--certs-get-past-the-filter-projects-win-the-room-budget-accordingly) and [CERTIFICATIONS.md](CERTIFICATIONS.md). If Kubernetes has clicked, skip it and bank the hours toward CKA. If it hasn't, take KCNA this week as a forcing function.

**Sat–Sun:** Project Bravo design — architecture diagram and threat model before any code.

**★ GATE 4:** five broken-cluster scenarios diagnosed unaided, under 15 minutes each, narrated aloud. Core manifests written from memory.

---

## Month 5 · DevSecOps and observability (weeks 18–21)

### Week 18 — Supply chain security ⚑

**Focus:** the month-5 thesis — this is what makes a junior beat other juniors.

**Learn:** the DevSecOps model, shift-left, security as a pipeline gate · SAST with Semgrep · SCA and container scanning with Trivy/Grype · CVE, CVSS, and **why severity alone is a bad gate** (reachability and exploitability matter) · secret scanning with gitleaks and pre-commit · dependency pinning and lockfiles · image hardening: distroless, non-root, read-only root filesystem, dropped capabilities, minimal base images · **SBOM generation with syft** (SPDX vs CycloneDX) · **image signing and verification with cosign** (keyless/OIDC) · SLSA provenance levels at concept level · the real-world attack cases worth being able to discuss: SolarWinds, Codecov, `event-stream`, `xz-utils`.

**Labs:**
1. Add Semgrep, Trivy, and gitleaks to the Alpha pipeline. Deliberately introduce a vulnerable dependency and **prove the pipeline blocks it.** Screenshot it.
2. Harden the app image: distroless, non-root, read-only fs. Re-scan. Record the before/after CVE count.
3. Generate an SBOM in CI; attach it to the image; sign the image with cosign; verify the signature.
4. Write an admission policy that refuses unsigned images. Try to deploy an unsigned one. Capture the rejection.

**⚡ Break/fix:** pipeline blocked by an unfixable transitive CVE (how do you triage, waive, and document that decision?) · signature verification fails after a registry move.

**⚑ Bravo:** supply chain controls complete.

---

### Week 19 — Policy, runtime, and secrets ⚑

**Learn:** policy as code — **OPA/Rego and Conftest** for Terraform plans, **Kyverno or Gatekeeper** for Kubernetes admission · Pod Security Standards (privileged / baseline / restricted) and namespace enforcement · NetworkPolicies and default-deny posture · runtime detection with Falco · secrets management: AWS Secrets Manager + External Secrets, or Vault (auth methods, dynamic secrets, leasing) · rotation · threat modeling with STRIDE, applied to the student's own architecture · compliance literacy: CIS Benchmarks, and enough NIST 800-53 / SOC 2 vocabulary to be conversational · least privilege in practice — scoping down an over-permissive IAM role using CloudTrail evidence.

**Labs:**
1. Conftest policy: fail any Terraform plan with a public S3 bucket or an unencrypted volume. Wire it into CI.
2. Kyverno policies: require non-root, require resource limits, disallow `:latest`, require signed images. Test each one against a violating manifest.
3. Enforce `restricted` Pod Security Standard on a namespace; watch a privileged pod get rejected.
4. Default-deny NetworkPolicy; then allow only the specific flows needed. Prove that a blocked flow is blocked.
5. Falco: trigger an alert with a shell spawned inside a container.
6. STRIDE threat model of Project Bravo, written up as a document.

**⚡ Break/fix:** a policy that blocks legitimate deploys (how do you scope an exception without opening a hole?) · Falco alert storm from a noisy default rule.

**⚑ Bravo:** policy and runtime layers complete.

**Ship:** blog post #10 — "I wrote an admission policy that locked me out of my own cluster."

---

### Week 20 — Observability

**Learn:** metrics vs logs vs traces, and what each is *for* · Prometheus architecture (scraping, service discovery, TSDB), exporters, the four metric types · **PromQL written by hand** — rate, increase, histogram_quantile, aggregation operators · Grafana dashboard design (and why most dashboards are useless) · Alertmanager: routing, grouping, inhibition, and **symptom-based rather than cause-based alerting** · OpenTelemetry: instrumentation, collector, exporters · distributed tracing and span context propagation · log aggregation (Loki or CloudWatch Logs) and structured logging · **SLIs, SLOs, error budgets, burn-rate alerting** · the four golden signals and RED/USE methods.

**Labs:**
1. kube-prometheus-stack on the cluster.
2. Instrument the app with a Prometheus client: request count, latency histogram, error count.
3. Write 10 PromQL queries from scratch — p99 latency, error rate, saturation. No copy-paste.
4. Build one dashboard that answers "is the service healthy?" in under 5 seconds of looking.
5. Define an SLO (99.5% availability, 30-day window), compute the error budget, and write a burn-rate alert.
6. OpenTelemetry tracing across the app and its database; find the slow span.

**⚡ Break/fix:** an alert that fires constantly (bad threshold vs bad metric) · a dashboard that looks fine during an outage (missing the right signal) · Prometheus OOM from cardinality explosion — a genuinely great interview story.

**Ship:** blog post #11 — "Your dashboard is lying to you: cause-based vs symptom-based alerting."

---

### Week 21 — SRE practice + Bravo completion ★ Gate 5 ⚑

**Learn:** incident command, severity levels, roles · the on-call model · **blameless postmortems** · runbooks that are actually usable at 3am · chaos engineering basics · capacity planning · toil and its elimination · **DORA metrics** (deployment frequency, lead time, change failure rate, MTTR) — and be ready to quote your own numbers for the projects.

**Labs:**
1. **Run three full incidents.** A partner (or a script) breaks something without warning; the student detects via alert, diagnoses, mitigates, and writes a blameless postmortem. Time every phase.
2. Write runbooks for the three most likely Bravo failures.
3. Measure the real DORA metrics of the Alpha and Bravo pipelines. Put the numbers in the READMEs.
4. Finish Bravo to acceptance criteria: README, diagram, threat model, control narrative, evidence screenshots.

**★ GATE 5:** the Bravo pipeline blocks a critical CVE and refuses an unsigned image, demonstrated live. A PromQL query and a valid SLO written from scratch.

---

## Month 6 · Platform engineering and conversion (weeks 22–26)

### Week 22 — Platform engineering foundations ⚑

**Learn:** what an internal developer platform is and what problem it solves · **platform as a product** — users, feedback, adoption metrics · **golden paths and paved roads** (the central concept; be able to explain it in 60 seconds) · self-service and the "you build it, you run it" tension · cognitive load as the real design constraint (Team Topologies) · service catalogs and scaffolding · Backstage vs a lighter custom approach · platform contracts and interface design · developer experience metrics (time-to-first-deploy, time-to-production, onboarding time) · multi-tenancy models · environment promotion strategies.

**⚑ Project CHARLIE design.** Before building: write a one-page product brief. Who is the user? What is their current pain? What does the paved road look like? What does it deliberately *not* support? That brief is itself an interview artifact — most candidates cannot produce one.

**Labs:** a shared Terraform module registry with versioned, documented modules · a `template-service/` repo that scaffolds a new service · design the `service.yaml` contract that a developer fills in.

**Ship:** blog post #12 — "Golden paths: why the easy way has to be the right way."

---

### Week 23 — Platform build ⚑

**Build Charlie:** PR-driven onboarding — a developer adds `services/my-app/service.yaml` and opens a PR; CI validates the schema, plans infrastructure, and on merge provisions everything (ECR repo, IAM role, Kubernetes namespace, ArgoCD Application, DNS, dashboard, alerts) with no manual steps and no platform-team ticket.

Everything from months 1–5 composes here: Terraform modules, GitHub Actions with OIDC, ArgoCD, the security gates, the Prometheus dashboards and SLOs.

**Also this week:** FinOps basics — a tagging strategy, cost allocation per service, and a cost report surfaced back to the developer in the PR. Cost visibility in a self-service platform is a detail that signals real judgment.

**⚡ Break/fix:** a malformed `service.yaml` that breaks the pipeline (validate the contract, fail fast, return a *useful error message* — error message quality is a platform product decision).

---

### Week 24 — Charlie completion + KCSA prep ⚑

**Mon–Thu:** finish Charlie. Documentation is the deliverable here as much as the code: a getting-started guide, the contract reference, ADRs for every significant choice, runbooks, an architecture diagram, and a **5-minute demo video** walking through a service going from PR to production.

Then the real test: hand the README to someone who has never seen it and watch them try. Every place they stumble is a bug. Fix all of them. **This exercise is the difference between a repo and a platform.**

**Fri–Sun:** KCSA prep if taking it — the four domains map almost entirely onto weeks 18–19, so this is consolidation, not new learning. Two practice exams.

---

### Week 25 — ★ KCSA EXAM · interview conversion begins

**Mon:** sit KCSA (if taking it).

**Tue–Sun — interviewing becomes the primary activity.** Build the interview kit:

1. **Eight STAR stories** drawn from the incident journal and the three projects: a hard bug, a tradeoff decision, a security find, a performance fix, a time something was broken in production-like conditions, a time of learning something fast, a collaboration story, a failure with a lesson.
2. **System design reps** — three scenarios, whiteboarded out loud, 45 min each: *design a CI/CD platform for 50 engineers* · *design a multi-account AWS landing zone* · *design a Kubernetes platform for 20 teams*.
3. **Live exercise practice:** write a Bash script under time pressure · write a Python script that calls AWS APIs · write a Terraform module from blank · debug a broken Kubernetes manifest · answer "how would you troubleshoot X" out loud without freezing.
4. **Six mock interviews**, at least three with real engineers, recorded and reviewed.
5. Prepare the questions to ask *them* — on-call load, deployment frequency, how the platform team is structured, what breaks most often.

---

### Week 26 — Full-time conversion ★ Gate 6

**The week's shape:** 20+ applications, all follow-ups worked, every interview prepared for individually, mocks continuing, and **building never stops** — a candidate who is still shipping during their job search interviews differently than one who is waiting.

**★ GATE 6:** a person who has never seen the repo follows the README and deploys a new service via pull request in under 10 minutes, unaided.

**Then: this plan does not end at week 26.** It converts into a maintenance cadence — see [JOB-SEARCH.md § After week 26](JOB-SEARCH.md#after-week-26--the-cadence-that-carries-you-to-the-offer). Weeks 27+ are: interviewing as the primary job, one new blog post a week, continued project iteration driven by whatever the interviews reveal as weak, and the CKA module below, run alongside that cadence.

---

## Month 7 · The CKA module (weeks 27–30)

Optional, and the recommended track ([CERTIFICATIONS.md §3](CERTIFICATIONS.md#3-the-kcna-and-kcsa-question--my-actual-recommendation)). About 17 hours of labs a week beside the week-26 cadence. The kubeadm nodes are in `curriculum/_setup/gcp-lab/` (`kubeadm_nodes = 2`). Book the exam on the Monday of week 27 for the end of week 30. Every exam fact in these weeks is a planning estimate; the candidate handbook is the contract.

### Week 27 — Cluster architecture, on kubeadm

**Focus:** the quarter of the exam kind cannot teach. **Labs:** `kubeadm init`, Calico, join two workers and read what kubeadm wrote · certificates and kubeconfigs · etcd snapshot and restore · upgrade one minor, control plane then workers · node break/fix (BF-59 to BF-64). **Exit:** restore etcd and upgrade a worker from memory, timed.

### Week 28 — Workloads, networking, storage: the gap-fill

**Focus:** everything the 2025 blueprint added. **Labs:** Kustomize and Helm as install tools · Gateway API and CoreDNS · CRDs and an operator · scheduling, Jobs, CronJobs, DaemonSets under exam conditions · dynamic provisioning. **Exit:** every lab repeated with the file closed, against its target time.

### Week 29 — Troubleshooting and speed

**Focus:** the exam is a speed test on top of a knowledge test. **Labs:** the exam terminal and the per-task ritual · the four troubleshooting families on real nodes, timed · mock exam 1 (18 weighted tasks, two hours) · killer.sh session 1 · triage and the weak-domain tally. **Exit:** the tally names two domains for week 30.

### Week 30 — Exam week ★ Gate 7

**Focus:** nothing new. **Labs:** killer.sh session 2 (the gate) · two weak-domain drill days · the exam checklist · the exam · the retrospective and the retake rule. **★ GATE 7:** the second simulator session finished inside two hours at or above the pass mark without opening the solutions; then the exam is sat.

---

## Summary table

| Wk | Focus | Deliverable | Milestone |
|---|---|---|---|
| 1 | Linux I, Git, environment | `sysreport.sh` | |
| 2 | Linux II, Networking I | systemd timer, subnetting drills | Post #1 |
| 3 | Networking II, Git collab, Nginx | Reverse proxy + TLS | Post #2 |
| 4 | Python, Docker | Compose stack | **★ Gate 1** |
| 5 | AWS IAM, EC2 | Cross-account role, EC2 w/ user data | Post #3 |
| 6 | VPC, S3 | Hand-built VPC + diagram | |
| 7 | Compute, scaling, databases | ALB + ASG + RDS failover | Post #4 |
| 8 | Integration, security, cost | SQS/Lambda/KMS/CloudWatch labs | Post #5 |
| 9 | SAA consolidation | 3 practice exams | **★ Gate 2** |
| 10 | **SAA EXAM**, Terraform I | Alpha kickoff | **★ SAA** |
| 11 | Terraform II: modules | Alpha modules | Post #6 |
| 12 | GitHub Actions + OIDC | Alpha CI/CD | Post #7 |
| 13 | Alpha completion, TF prep | **⚑ Project ALPHA** | **★ Gate 3** |
| 14 | **TF ASSOC**, K8s I | Résumé, LinkedIn, **first 10 applications** | **★ TF · ★ APPLY** |
| 15 | K8s II: ops + debugging | Helm chart, 5 break scenarios | Post #8 |
| 16 | EKS + ArgoCD | EKS via TF, GitOps delivery | Post #9 |
| 17 | Consolidation | Bravo design + threat model | **★ Gate 4** · KCNA? |
| 18 | Supply chain security | SBOM, cosign, hardened images | |
| 19 | Policy, runtime, secrets | OPA + Kyverno + Falco | Post #10 |
| 20 | Observability | Prometheus, SLOs, tracing | Post #11 |
| 21 | SRE practice | **⚑ Project BRAVO** + 3 postmortems | **★ Gate 5** |
| 22 | Platform foundations | Charlie brief, module registry | Post #12 |
| 23 | Platform build | PR-driven onboarding | |
| 24 | Charlie completion | Docs, demo video, KCSA prep | |
| 25 | **KCSA**, interview kit | 8 STAR stories, 6 mocks | **★ KCSA** |
| 26 | Full-time conversion | 20+ applications | **★ Gate 6** |
| 27 | CKA: cluster architecture on kubeadm | etcd restored, cluster upgraded | |
| 28 | CKA: workloads, networking, storage | Gateway API, CRDs, Kustomize on your cluster | |
| 29 | CKA: troubleshooting and speed | Mock exam 1, killer.sh session 1 | |
| 30 | CKA: exam week | killer.sh session 2, the exam | **★ Gate 7 · ★ CKA** |
