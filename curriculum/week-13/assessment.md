# ★ GATE 3 — Project Alpha

> **A gate, not a quiz.** Demonstrated, not self-assessed.

---

## The gate

Run each check. Every box must be genuinely true.

### Deployment
- [ ] `terraform apply` from a **clean AWS account** produces a working application
- [ ] The **only** manual step is editing `backend.tf` with the state bucket name — and that step is
      documented in the README
- [ ] `curl $(terraform output -raw url)` returns the application
- [ ] `make destroy` leaves nothing billable; `_setup/03-teardown.sh` finds no orphans

### Credentials
```bash
git grep -InE 'AKIA[0-9A-Z]{16}'                    # must be empty
git log -p --all | grep -cE 'AKIA[0-9A-Z]{16}'      # must be 0
gh secret list                                       # role ARNs only, no keys
```
- [ ] All three clean
- [ ] CI authenticates via OIDC
- [ ] The apply role is pinned to a protected GitHub Environment

### State
- [ ] Remote backend on S3
- [ ] Encryption enabled
- [ ] Versioning enabled on the bucket
- [ ] Locking enabled (`use_lockfile` or a DynamoDB table)
- [ ] Two simultaneous `plan` runs — one waits for the lock

### Pipeline
- [ ] PR triggers `fmt` → `validate` → `tflint` → `checkov` → `plan`
- [ ] The plan is posted as a PR comment
- [ ] Merge to main triggers `apply`, behind an approval gate
- [ ] `concurrency` group with `cancel-in-progress: false`
- [ ] Branch protection on, with `enforce_admins: true`
- [ ] `.terraform.lock.hcl` committed with Linux **and** macOS platform hashes

### Environments
- [ ] `dev` and `prod` deploy from the **same modules**
- [ ] `diff environments/dev/main.tf environments/prod/main.tf` shows **only input values**

### Documentation
- [ ] README opens with the **problem**, not the tech list
- [ ] Architecture diagram present
- [ ] Cost table, per environment, per month
- [ ] **Measured results** table with real numbers you collected
- [ ] **"What broke"** section, three or more genuine entries
- [ ] At least four ADRs
- [ ] Runbook per alarm
- [ ] CI badge, green

### Operations
- [ ] Alarms exist and **at least one has been forced** to confirm the notification path
- [ ] SNS subscription **confirmed** (not `PendingConfirmation`)
- [ ] ASG recovery time measured and recorded
- [ ] RDS failover measured and recorded (prod)

---

## The one-command verification

```bash
make verify ENV=dev
```
The reference Makefile's `verify` target checks credentials, backend settings, the live endpoint, and
the alarms. **Write your own version.** An acceptance test you can run is worth more than a checklist
you tick by hand, and it is itself a thing to point at in an interview.

---

## Gate result

| | |
|---|---|
| **PASS** — every box | **Sit the Terraform Associate Monday. Start applying Tuesday.** |
| **NEAR** — docs or measurements incomplete | Finish them this weekend. **Do not delay week 14.** Docs can be improved while you're applying; the application start cannot be recovered. |
| **FAIL** — clean-account deploy doesn't work | Fix it before week 14. This is the criterion that makes the project real. Everything else is presentation. |

---

## If you are behind

The temptation in week 13 is to delay week 14 "just a bit" to polish. **Don't.**

Week 14's value is the **application start**, and the pipeline has a 6–10 week lag. A week of delay
here is a week added to the end of your job search, and the thing you'd be polishing — a nicer
diagram, a fourth ADR — has far less effect on an outcome than being six weeks further into a
pipeline.

Ship it at 85%. Improve it while you apply. A project that visibly gained commits during your job
search reads *better* than one that has been static since week 13.

---

## Month 3 retrospective (write it Sunday)

In `progress/progress.md`:

1. **Hours logged** vs target. Still honest?
2. Did Alpha ship on schedule? If not, what was the actual blocker — scope, skill, or time?
3. Top 3 "Surprised" lines from the incident journal this month
4. **Which of the three certs-vs-projects tradeoffs did you actually make?** Are you happy with it?
5. Rest days taken. Weeks 14–18 are where burnout hits — if you've been skipping them, fix it now.
6. **Are you genuinely ready to apply on Tuesday?** If the honest answer is no, ask why — and check
   whether the reason is a real gap or just the feeling of not being ready. They are different, and
   only one of them is a reason to wait.
