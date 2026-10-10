# Week 12 Assessment

> Closed book, 35 min.

## Part A (15 min)
1. Why OIDC instead of static access keys? Give three reasons.
2. What is the `sub` claim for a **pull request** run? For a push to main? For a run with
   `environment: prod`?
3. Why is `repo:org/repo:*` acceptable on a plan role and dangerous on an apply role?
4. What permission must a workflow declare to request an OIDC token?
5. Why `cancel-in-progress: false` on a Terraform workflow? Name two consequences of cancelling.
6. Why must `.terraform.lock.hcl` be committed, and why does the platform matter?
7. What is `pull_request_target` and why is it dangerous?
8. Show the safe and unsafe way to use `github.event.pull_request.title` in a `run:` step.
9. Why pin an action to a SHA rather than a tag?
10. Three tag types on a container image and what each is for.

## Part B — Write it (10 min)
11. The `permissions:` block for a job that assumes an AWS role and comments on a PR
12. A `concurrency` block correct for Terraform
13. The trust policy condition pinning a role to the `prod` environment of one repo
14. The command that generates a lock file for both Linux and macOS ARM
15. A matrix that runs on three Python versions with `fail-fast` disabled

## Part C — Diagnose (10 min)
16. `Not authorized to perform sts:AssumeRoleWithWebIdentity`. Walk through your diagnosis.
17. The pipeline passes on main but fails on every PR. Most likely cause?
18. `terraform apply` works on your laptop and fails in CI with a checksum error. What happened?
19. Two PRs merged a minute apart; the second apply fails with a state lock error. What went wrong
    and what's the fix?
20. A teammate proposes `soft_fail: true` on checkov because "it's blocking us." What do you say?

---

# Answer key

**A1.** (1) No long-lived credential exists to leak — the token lives minutes. (2) Nothing to rotate,
so rotation actually happens. (3) Scoped per repo/branch/environment by the trust policy, so a
compromise is bounded. (Also: sessions are named per run, so CloudTrail attributes every action.)

**A2.** PR → `repo:ORG/REPO:pull_request`. Push to main → `repo:ORG/REPO:ref:refs/heads/main`.
With an environment → `repo:ORG/REPO:environment:prod`.

**A3.** `repo:org/repo:*` matches **any branch**. On a read-only plan role that's necessary (PRs must
plan) and harmless. On an apply role it means **anyone who can open a PR can change production**,
because they can push a branch with a workflow that assumes the role. Pin apply to
`environment:prod` behind a protected GitHub Environment.

**A4.** `permissions: id-token: write`.

**A5.** Because cancelling a running `terraform apply` (1) **leaves the state lock held**, so the next
run fails until someone force-unlocks, and (2) can leave infrastructure **half-created** with state
not matching reality — possibly orphaning billing resources. Applies are not idempotent mid-flight.
Queue, never cancel.

**A6.** It pins provider versions **and checksums**, so CI and laptops resolve identically. The
platform matters because the lock records per-platform hashes — a lock generated only on
`darwin_arm64` makes Linux CI fail with "does not match any of the checksums recorded." Generate with
`-platform` for every platform you build on.

**A7.** A trigger that runs in the **base repository's** context — write token, repo secrets — while
typically being used to check out the **PR's** code. That combination lets anyone who can open a PR
execute code with your secrets. It is the #1 GitHub Actions vulnerability. Use `pull_request`
instead.

**A8.**
```yaml
# UNSAFE -- expression is substituted into the shell before it runs
- run: echo "Title: ${{ github.event.pull_request.title }}"

# SAFE
- env: { TITLE: "${{ github.event.pull_request.title }}" }
  run: echo "Title: $TITLE"
```

**A9.** Tags are **mutable**. `@v4` can be repointed at malicious code without you changing anything.
A SHA is immutable. Pin SHAs for any action that touches credentials.

**A10.** `latest` — mutable, ambiguous, avoid. `v1.2.3` semver — human-meaningful release identity.
**`sha-<commit>`** — immutable and traceable to an exact commit; this is what deploy manifests should
reference (or better, the digest).

---

**B11.**
```yaml
permissions:
  id-token: write
  contents: read
  pull-requests: write
```

**B12.**
```yaml
concurrency:
  group: terraform-${{ github.ref }}
  cancel-in-progress: false
```

**B13.**
```json
"Condition": {
  "StringEquals": {
    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
    "token.actions.githubusercontent.com:sub": "repo:ORG/REPO:environment:prod"
  }
}
```

**B14.** `terraform providers lock -platform=linux_amd64 -platform=darwin_arm64`

**B15.**
```yaml
strategy:
  fail-fast: false
  matrix:
    python: ['3.10', '3.11', '3.12']
```

---

**C16.** (1) Print the actual token claims in the workflow and compare the `sub` character by
character with the trust policy. (2) Confirm `permissions: id-token: write`. (3) Confirm the `aud`
condition is `sts.amazonaws.com`. (4) Confirm the OIDC provider ARN has the right account ID. (5) If
it works on main but not PRs, the policy uses a `ref:` pattern and PRs use `:pull_request`.

**C17.** The trust policy uses `StringEquals` on `ref:refs/heads/main`. PR runs have
`sub = repo:org/repo:pull_request`, so they can't assume the role. Fix: use `StringLike` with
`repo:org/repo:*` for the **read-only plan** role.

**C18.** `.terraform.lock.hcl` is missing the Linux platform hashes — it was generated only on your
Mac. Fix with `terraform providers lock -platform=linux_amd64 -platform=darwin_arm64` and commit it.

**C19.** Both applies raced for the same state. The concurrency group either wasn't set, or was set
with `cancel-in-progress: true` and the first was cancelled mid-apply leaving the lock held. Fix:
`concurrency: { group: terraform-${{ github.ref }}, cancel-in-progress: false }` so runs queue.
If a lock is genuinely stuck, confirm no apply is running, then `terraform force-unlock`.

**C20.** *"A gate that never fails isn't a gate — and the moment a real finding appears nobody will
notice, because the build stays green. If it's too noisy, let's fix the noise: I'll triage the
findings now, fix the cheap real ones, and add per-check inline skips with written justifications
and owners for anything we genuinely can't fix today. That unblocks us today and keeps the gate
working tomorrow."* Then actually do the triage — the objection only lands if you offer the
alternative.

## Scoring
| | |
|---|---|
| 17–20 | Move on. Alpha should be CI-deployed. |
| 13–16 | Redo Lab 2. OIDC is the single most differentiating thing in this month. |
| < 13 | Redo Labs 2 and 3 before week 13. Alpha's acceptance criteria depend on both. |
