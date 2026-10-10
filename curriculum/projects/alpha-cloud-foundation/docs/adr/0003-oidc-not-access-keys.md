# ADR-0003: GitHub OIDC federation instead of AWS access keys

- **Status:** Accepted
- **Date:** 2026-03-03

## Context

CI needs AWS credentials. The default approach is an IAM user's access key stored as a GitHub
secret.

## Options considered

**A. Static access keys in GitHub secrets.** Simple, universally understood, and a long-lived
credential that works until someone notices it leaked. Rotation is manual, so in practice it does not
happen.

**B. OIDC federation.** GitHub mints a short-lived JWT for each workflow run; AWS trusts GitHub's
OIDC provider and exchanges it for STS credentials valid for one hour. Nothing stored, nothing to
rotate.

## Decision

**Option B.** Two roles: a read-only plan role and an apply role.

The trust policy pins the `sub` claim. This is the part that matters:

```json
"StringLike": {
  "token.actions.githubusercontent.com:sub": "repo:ORG/alpha-cloud-foundation:*"
}
```
for the **plan** role, but for the **apply** role:
```json
"StringEquals": {
  "token.actions.githubusercontent.com:sub": "repo:ORG/alpha-cloud-foundation:environment:prod"
}
```

`repo:ORG/repo:*` means **any branch in that repo can assume the role** — so anyone who can open a PR
reaches the account. That is acceptable for a read-only plan role and not acceptable for one that can
apply. The apply role is pinned to a protected GitHub Environment with required reviewers.

## Consequences

**Positive:** no long-lived credentials exist. `make verify` greps for `AKIA` and finds nothing.
Sessions are named per run, so CloudTrail attributes every action to a specific workflow run.

**Negative:** the trust policy is easy to get subtly wrong (BF-37). PR runs have
`sub = repo:org/repo:pull_request`, not `...:ref:refs/heads/main` — a mismatch fails with an
unhelpful `Not authorized to perform sts:AssumeRoleWithWebIdentity`.
