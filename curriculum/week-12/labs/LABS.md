# Week 12 Labs

---

# Lab 1 — GitHub Actions Fundamentals (3h)

```yaml
# .github/workflows/learn.yml
name: learn
on:
  push:
    branches: [main]
    paths: ['src/**']
  pull_request:
  workflow_dispatch:
    inputs:
      environment:
        type: choice
        options: [dev, prod]
  schedule:
    - cron: '0 6 * * *'

env:
  GLOBAL: value

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        python: ['3.10', '3.11', '3.12']
        os: [ubuntu-latest, macos-latest]
        exclude:
          - { os: macos-latest, python: '3.10' }
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: ${{ matrix.python }}
          cache: pip
      - run: pip install -e '.[dev]'
      - run: pytest --cov --cov-report=xml
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: coverage-${{ matrix.os }}-${{ matrix.python }}
          path: coverage.xml

  build:
    needs: test
    runs-on: ubuntu-latest
    outputs:
      version: ${{ steps.meta.outputs.version }}
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }
      - id: meta
        run: echo "version=$(git describe --tags --always)" >> "$GITHUB_OUTPUT"
```

## Tasks
1. Build the matrix workflow and watch all five jobs run in parallel
2. Add `fail-fast: false` and observe the difference when one fails
3. Cache dependencies and measure the speedup
4. Pass a value between jobs with `outputs`
5. Use `if: always()`, `if: failure()`, `if: github.event_name == 'pull_request'`
6. Write a **composite action** in `.github/actions/setup/action.yml` and use it
7. Write a **reusable workflow** with `workflow_call` and call it from another repo

## The security rules for workflows

| Rule | Why |
|---|---|
| Pin actions to a **SHA**, not a tag, for anything touching credentials | Tags are mutable — `@v4` can be repointed at malicious code |
| Never use `pull_request_target` with a checkout of the PR head | It runs with **write** permissions and repo secrets against untrusted code. This is the #1 GitHub Actions vulnerability. |
| Set `permissions:` explicitly, least privilege, per job | The default token is broadly scoped |
| Never `echo` a secret | It is masked in logs, but `base64` or a partial echo defeats masking |
| Treat `github.event.*` as untrusted input | Script injection via a PR title is real: `run: echo "${{ github.event.pull_request.title }}"` |

```yaml
# Script injection -- VULNERABLE
- run: echo "Title: ${{ github.event.pull_request.title }}"

# Safe: pass through an environment variable
- env:
    TITLE: ${{ github.event.pull_request.title }}
  run: echo "Title: $TITLE"
```

---

# Lab 2 — OIDC Federation (3h) — the week's centerpiece

## Part 1 — Create the identity provider

```bash
# One per AWS account. GitHub's OIDC issuer.
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```
(Thumbprint verification is no longer enforced by AWS for this provider, but the argument is still
required.)

## Part 2 — Two roles, deliberately different

```bash
ACCT=$(aws sts get-caller-identity --query Account --output text)
ORG=your-github-org
REPO=alpha-cloud-foundation

# PLAN role -- read-only, any branch (PRs must be able to plan)
cat > trust-plan.json <<JSON
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Federated": "arn:aws:iam::${ACCT}:oidc-provider/token.actions.githubusercontent.com"},
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {"token.actions.githubusercontent.com:aud": "sts.amazonaws.com"},
      "StringLike":   {"token.actions.githubusercontent.com:sub": "repo:${ORG}/${REPO}:*"}
    }
  }]
}
JSON

# APPLY role -- pinned to a PROTECTED GitHub Environment
cat > trust-apply.json <<JSON
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Federated": "arn:aws:iam::${ACCT}:oidc-provider/token.actions.githubusercontent.com"},
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
        "token.actions.githubusercontent.com:sub": "repo:${ORG}/${REPO}:environment:prod"
      }
    }
  }]
}
JSON

aws iam create-role --role-name gha-plan  --assume-role-policy-document file://trust-plan.json
aws iam create-role --role-name gha-apply --assume-role-policy-document file://trust-apply.json
aws iam attach-role-policy --role-name gha-plan --policy-arn arn:aws:iam::aws:policy/ReadOnlyAccess
```

**Read the difference carefully.** The plan role uses `StringLike` with `repo:org/repo:*` — any
branch. The apply role uses `StringEquals` on `environment:prod` — only a run targeting the protected
`prod` environment.

`repo:org/repo:*` on an **apply** role means **anyone who can open a pull request can change your
production infrastructure.** That is the single most important sentence in this lab.

## Part 3 — Use it

```yaml
permissions:
  id-token: write      # REQUIRED -- without it the token request fails
  contents: read

jobs:
  plan:
    runs-on: ubuntu-latest
    steps:
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/gha-plan
          aws-region: us-east-1
          role-session-name: gha-${{ github.run_id }}
      - run: aws sts get-caller-identity
```

## Part 4 — Break it deliberately (BF-37)

Reproduce each failure and read the error:
1. Remove `id-token: write` → the token request fails
2. Use `StringEquals` with `ref:refs/heads/main` and run it from a PR → `sub` is
   `repo:org/repo:pull_request`, so it fails
3. Omit the `aud` condition → understand what an attacker could do with a token minted for a
   different audience
4. Point at the wrong account ID in the provider ARN

**Inspect the actual claims:**
```yaml
- name: show the OIDC token claims
  run: |
    TOKEN=$(curl -sH "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
      "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=sts.amazonaws.com" | jq -r .value)
    echo "$TOKEN" | cut -d. -f2 | base64 -d 2>/dev/null | jq .
```
This prints `sub`, `aud`, `repository`, `ref`, `environment`, `job_workflow_ref`, and more. **Seeing
the real claims is what makes trust policies stop being guesswork.**

## Part 5 — Prove there are no keys

```bash
git grep -InE 'AKIA[0-9A-Z]{16}'
git log -p --all | grep -cE 'AKIA[0-9A-Z]{16}' || echo "clean in history too"
gh secret list      # should contain role ARNs, not keys
```

---

# Lab 3 — The Terraform Pipeline (3h)

Build the full pipeline. Reference:
[`../projects/alpha-cloud-foundation/.github/workflows/terraform.yml`](../../projects/alpha-cloud-foundation/.github/workflows/terraform.yml)

## Requirements
- [ ] On PR: `fmt -check` → `validate` → `tflint` → `checkov` → `plan`, all environments in a matrix
- [ ] The plan posted as a PR comment (collapsed in a `<details>` block)
- [ ] On merge to main: `apply`, gated by a GitHub Environment with required reviewers
- [ ] `concurrency` group, **`cancel-in-progress: false`**
- [ ] `max-parallel: 1` on the apply matrix so dev applies before prod
- [ ] checkov results uploaded as SARIF to the Security tab

## The two settings people get wrong

```yaml
concurrency:
  group: terraform-${{ github.ref }}
  cancel-in-progress: false
```
**Cancelling a running `terraform apply` leaves a stuck state lock and possibly half-created
infrastructure** (BF-33 + BF-39). Queue; never cancel.

```yaml
environment: prod      # a GitHub Environment with required reviewers
```
This is what makes the OIDC `sub` claim contain `environment:prod`, which is what the apply role's
trust policy pins. **The approval gate and the credential scope are the same mechanism** — that's the
elegant part, and it's worth explaining in an interview.

## Tasks
1. Build it, open a PR, confirm the plan comment appears
2. Merge and confirm the apply waits for approval
3. **Reproduce BF-39:** merge two PRs within a minute and watch the concurrency group queue them
4. **Reproduce BF-38:** delete `.terraform.lock.hcl`, push, and watch CI resolve different provider
   versions than your laptop. Then fix it:
   ```bash
   terraform providers lock -platform=linux_amd64 -platform=darwin_arm64
   git add .terraform.lock.hcl
   ```

---

# Lab 4 — Containers, ECR, Reusable Workflows (3h)

```yaml
name: build
on:
  push:
    tags: ['v*']
    branches: [main]

permissions:
  id-token: write
  contents: read

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ECR_ROLE_ARN }}
          aws-region: us-east-1

      - id: ecr
        uses: aws-actions/amazon-ecr-login@v2

      - uses: docker/setup-qemu-action@v3
      - uses: docker/setup-buildx-action@v3

      - id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ steps.ecr.outputs.registry }}/alpha-app
          tags: |
            type=semver,pattern={{version}}
            type=sha,format=long
            type=ref,event=branch

      - uses: docker/build-push-action@v6
        with:
          context: .
          platforms: linux/amd64,linux/arm64
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
          provenance: true
          sbom: true
```

**Tasks:**
1. Build multi-arch and confirm both platforms in the manifest:
   `docker manifest inspect <image> | jq '.manifests[].platform'`
2. Tag with **both** a semver tag and the **git SHA**. Explain why the SHA tag matters (it's
   immutable and traceable; `latest` is neither).
3. Enable `cache-from`/`cache-to` and measure the build-time improvement
4. Note that `provenance: true` and `sbom: true` already give you attestations — week 18 builds on
   this
5. Write a **reusable workflow** (`on: workflow_call`) and call it from a second repo

## Semantic release
```yaml
- uses: googleapis/release-please-action@v4
  with:
    release-type: simple
```
Conventional commits (week 1) → automatic version bumps and changelog. The habit you started in week
1 pays off here.

---

# Lab 5 — Break/Fix, Branch Protection, ⚑ Alpha (3h)

## Break/Fix
**BF-37** (OIDC trust policy) · **BF-38** (works locally, fails in CI) · **BF-39** (concurrent applies).

## Branch protection
```bash
gh api -X PUT repos/:owner/:repo/branches/main/protection \
  --input - <<'JSON'
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["validate", "plan (dev)", "plan (prod)"]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": true
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_conversation_resolution": true
}
JSON
```
**`enforce_admins: true`** is the one people skip. Without it, protection is advisory for exactly the
people most likely to bypass it at 6pm on a Friday.

## ⚑ Alpha milestone
- [ ] Every push runs the gates; every PR gets a plan comment
- [ ] Merge to main applies dev, then prod, each behind approval
- [ ] `git grep AKIA` clean in tree and history
- [ ] `.terraform.lock.hcl` committed with both platforms
- [ ] Branch protection on, `enforce_admins: true`
