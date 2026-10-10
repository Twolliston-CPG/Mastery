# Week 3 · Day 2 — HCP Run Workflows

**Exam domain:** 6.

## Learning goals

1. Three workflows — **CLI-driven**, **VCS-driven**, **API-driven** — and when each wins.
2. What a **run** actually is — a plan + optional apply + optional policy check + optional cost estimation.
3. **Speculative plans** — triggered by PRs in VCS workflows; they don't apply.
4. **Auto-apply** vs **manual confirmation** — and why production workspaces should stay manual.
5. **Run triggers** — workspace A's apply triggers workspace B's run.
6. **Notifications** — Slack, email, generic webhook on run state changes.

## The three workflows compared

| Feature | CLI-driven | VCS-driven | API-driven |
|---|---|---|---|
| How code reaches the workspace | `terraform plan/apply` uploads | Git push / PR webhook | HTTP POST of a tarball |
| Who/what initiates | Developer, locally | Git provider | Any HTTP client (CI/CD) |
| Speculative plans | No | Yes (on PRs) | Optional |
| Good for | Iteration, exam labs | Team collaboration | Custom pipelines, monorepos |

## Speculative plans

- **VCS workspaces:** every PR to a watched branch triggers a speculative plan. Results posted as PR comments. No apply button — it's read-only.
- Toggle in workspace settings → "Automatic speculative plans".

## Auto-apply

- Workspace setting. Off by default.
- When on: a successful plan on the tracked branch auto-applies. No approval gate.
- **Exam trap:** "How do you ensure every production change is human-approved?" → keep auto-apply OFF.

## Run triggers

- Workspace `app-prd` can depend on workspace `network-prd` — when `network-prd` applies, `app-prd` kicks off a run automatically.
- Configure in workspace settings → "Run triggers".
- Exam favorite for multi-workspace orchestration questions.

## Exercises

1. Take the same config from Day 1. Commit it to a GitHub repo.
2. In HCP, create a second workspace `fundamentals-vcs`, choose **Version control workflow**, connect GitHub.
3. Push a change (e.g. new tag). Watch the run fire.
4. Open a PR that changes `cidr_block`. See the speculative plan posted back to the PR.
5. Merge — run fires. Leave auto-apply OFF; manually confirm.
6. Create a downstream workspace `fundamentals-consumer` that reads the VPC id via `terraform_remote_state`, and add a **run trigger** so it reruns when the network workspace applies.

## Self-check

1. You want CI to decide when to apply, not humans. Which workflow + setting?
2. A speculative plan failed on a PR. Does the run "block" the merge? How?
3. If you push to `main` with auto-apply ON and bad HCL, what happens?
4. Can a CLI-driven workspace have run triggers to other workspaces?

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- The three workflows compared
- Speculative plans
- Auto-apply
- Run triggers

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"Terraform manages your infrastructure."* |
| ✓ | *"`plan` is a three-way comparison: the configuration (desired), the state file (what Terraform believes it created), and a refresh against the real API (what exists). Almost every confusing result is one of those three drifting from the other two."* |

**Trace it:** `terraform apply` on one resource: config → plan → API call → state write. Then say what happens if the process dies between the API call and the state write.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** [the purpose of Terraform state](https://developer.hashicorp.com/terraform/language/state/purpose) — almost every confusing result is a three-way disagreement, spelled out there.
Full list per domain: [`SOURCES.md`](../../SOURCES.md#terraform)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../../MASTERY.md)

<!-- /feynman-check -->
