# Figure 12.1 — OIDC: how a workflow gets AWS credentials with no secret anywhere

> Week 12 · badges ① to ⑪ · about three and a half minutes at a normal pace. Point at each badge as you say its line. Blue is the path to follow first; orange-red is where something refuses or fails.

![Figure 12.1 — OIDC: how a workflow gets AWS credentials with no secret anywhere](figure-12.1-oidc-how-a-workflow-gets-aws.png)

Static keys in GitHub secrets are the most common amateur tell. The blue path replaces them with a short-lived token that AWS verifies by signature and by claim. Two roles, deliberately different, sit at the end.

## What to say, badge by badge

- **Open.** “Three hours of work this week read as three years of experience, and this is the picture of it. No access key exists. A workflow proves who it is with a signed token, and AWS decides what that identity may do. Follow the blue path, then look at the two roles.”
- **① pull request or merge.** “The workflow starts with a context: which repository, which branch or environment, which event. That context is about to become the identity.”
- **② GitHub OIDC issuer.** “GitHub runs an OpenID Connect issuer. On request, it signs a JSON Web Token with its private key and publishes the public key at a well-known URL. Anyone can verify; only GitHub can sign.”
- **③ the token.** “The claims are the whole story. `sub` says repo, and ref or environment. `aud` says who the token is for: sts.amazonaws.com. It expires in minutes. There is nothing in it worth stealing for long.”
- **④ IAM OIDC provider.** “One per AWS account, pointing at GitHub's issuer. This is AWS agreeing to check signatures from that issuer. It grants nothing by itself.”
- **⑤ AssumeRoleWithWebIdentity.** “The workflow hands the token to STS. STS verifies the signature against the published key, then evaluates the role's trust policy against the claims. The condition on `sub` is the access control. STS returns temporary credentials, and the job runs.”
- **⑥ plan role.** “Read-only. Trusted for any branch, because a pull request from any branch must be able to produce a plan. Read-only means a malicious PR can look but not touch.”
- **⑦ apply role.** “Trusted only for `environment:prod`, a GitHub environment with required reviewers. Merging is not enough; a human approves the deployment, and only then does a token with that claim exist.”
- **⑧ the pipeline.** “fmt, validate, tflint, checkov, plan, a comment on the PR with the plan, approval, apply. Cheap checks first, so a formatting error does not spend a plan. The plan comment is what the reviewer actually reads.”
- **⑨ container build.** “Multi-arch, pushed to ECR with two tags: a semver for humans and the git SHA for provenance. Week 18 signs the digest; this is where the digest is born.”
- **⑩ branch protection.** “Every check green before merge. The concurrency group has cancel-in-progress false, because cancelling an apply halfway through is how you get a half-built environment.”
- **⑪ the dangerous trust policy.** “`repo:org/repo:*` matches every branch and every PR. On the plan role it is fine. On the apply role it means anyone who can push a branch can deploy to production. Say this in the interview; it is the question they ask.”
- **Close.** “So: no key exists, identity is a signed claim, and the claim decides the role. The exit criterion is a grep for AKIA that returns nothing, in the tree and in the history.”

**Print it:** [`figure-12.1-numbered-spoken.pdf`](figure-12.1-numbered-spoken.pdf) is the two-page version, the figure on page one and this script on page two.

## Use it

- Read the figure before the day plan. Say the script out loud on Friday with the file closed.
- Each badge line is a thirty-second interview answer; the whole script is the three-minute version.
- Regenerate after editing the spec in `_shared/diagrams/week_figures/`:

```bash
python3 ../../_shared/diagrams/generate-week-figures.py --only 12
```
