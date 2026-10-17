# Week 5 — AWS Foundations: IAM and EC2

> **Thesis:** IAM breaks in production more than anything else in AWS. Over-invest here. Every
> "AccessDenied" you will ever debug, every cross-account question in an interview, every
> least-privilege discussion traces back to the policy evaluation logic you learn this week.

| | |
|---|---|
| **Hours** | 35–45 |
| **Deliverable** | Blog post #3 — "IAM policy evaluation, explained with the four times I got AccessDenied" |
| **Break/Fix** | BF-25, BF-26 |
| **Exit check** | Write an IAM policy from scratch; explain why an EC2 instance can call AWS APIs with no keys on disk |

> ## ⚠ BEFORE YOU CREATE ANY AWS RESOURCE
> ```bash
> EMAIL=you@example.com bash ../_setup/01-aws-guardrails.sh
> ```
> Budget alarms at $25/$50/$100, billing alerts on, root MFA, no root access keys.
> **Then put a recurring Monday reminder in your calendar: "check AWS bill."** For 26 weeks.
> A surprise $400 bill in week 6 ends programs.

## The week in one figure

**Figure 5.1 — How AWS decides, and how an instance gets credentials with no keys on disk.** Two blue paths. The top one is the IAM evaluation every request goes through. The bottom one is the mechanism that gives an EC2 instance credentials it never stores: the instance profile and IMDSv2. Badges are numbered in the order to walk them; the blue path is the one to follow first.

```mermaid
%%{init: {'theme':'base','themeVariables':{'fontFamily':'Helvetica, Arial, sans-serif','fontSize':'13px','primaryColor':'#ffffff','primaryTextColor':'#2d3436','primaryBorderColor':'#9aa3ab','lineColor':'#9aa3ab','textColor':'#2d3436','clusterBkg':'#fbfcfd','clusterBorder':'#d4dae0','edgeLabelBackground':'#ffffff','tertiaryColor':'#eef4fb'},'flowchart':{'curve':'basis','padding':14,'nodeSpacing':42,'rankSpacing':58}}}%%
flowchart LR
  classDef default fill:#ffffff,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef n    fill:#ffffff,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef crit fill:#eef4fb,stroke:#2f6fb8,stroke-width:1.8px,color:#1b3a5c
  classDef data fill:#f4f7fa,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef mut  fill:#ffffff,stroke:#cfd6dc,stroke-width:1.1px,color:#7a8288
  classDef warn fill:#fdf0ec,stroke:#c0522d,stroke-width:1.6px,color:#8a3a1e

  subgraph EVAL["IAM evaluation · every request, in this order"]
    direction LR
    E1["① principal + request<br/><small>who · action · resource · conditions</small>"]:::crit
    E2["② explicit Deny?<br/><small>anywhere wins</small>"]:::warn
    E3["③ SCP · permission boundary<br/><small>ceilings, not grants</small>"]:::n
    E4["④ identity or resource policy Allow?<br/><small>no Allow = implicit deny</small>"]:::crit
    E5["⑤ allowed<br/><small>or AccessDenied, with the reason in CloudTrail</small>"]:::crit
  end
  subgraph INST["EC2 · credentials without a credential"]
    direction LR
    I1["⑥ instance profile<br/><small>wraps a role · attached at launch</small>"]:::n
    I2["⑦ IMDSv2<br/><small>PUT token, TTL ≤ 6 h · hop limit 1 · 169.254.169.254</small>"]:::crit
    I3["⑧ temporary credentials<br/><small>rotated about every 6 h · never on disk</small>"]:::data
    I4["⑨ SDK credential chain<br/><small>env → profile → container → IMDS</small>"]:::n
  end
  X["⑩ cross-account AssumeRole<br/><small>trust policy + ExternalId · STS</small>"]:::n
  G["⑪ guardrails first<br/><small>budgets $25 · $50 · $100 · root MFA · no root keys</small>"]:::warn
  E1 ==> E2 ==> E3 ==> E4 ==> E5
  I1 ==> I2 ==> I3 ==> I4
  I4 --> E1
  X -.-> E1
  G -.-> I1
  linkStyle 0,1,2,3,4,5,6 stroke:#2f6fb8,stroke-width:2px
```

**What to say, badge by badge** · about three and a half minutes at a normal pace. Point at each badge as you say its line.

- **Open.** “IAM breaks in production more than anything else in AWS. The top row is the decision AWS makes on every call. The bottom row is how a machine gets to make calls at all, without a key on disk. Both are exam material and both are interview material.”
- **① principal and request.** “A principal, an action, a resource, and conditions. Every AccessDenied is one of those four being different from what you assumed. The policy simulator lets you test the four without making the call.”
- **② explicit Deny.** “An explicit Deny anywhere wins, over any Allow, from any policy. This is the first thing evaluated and the first thing to look for when a user with AdministratorAccess still gets denied.”
- **③ SCP and permission boundary.** “These are ceilings. An SCP from Organizations and a permission boundary on the identity can only take permissions away. A boundary that does not mention S3 means no S3, however generous the identity policy is.”
- **④ identity or resource policy Allow.** “Within the same account, an Allow from either the identity's policy or the resource's policy is enough. Across accounts, you need both. No Allow at all is an implicit deny, and it is the common case.”
- **⑤ allowed.** “Or denied, and the reason is in CloudTrail. Four AccessDenied stories become blog post 3.”
- **⑥ instance profile.** “A role needs a vehicle to ride on an instance. The instance profile is that vehicle, attached at launch. The role has the permissions; the profile is just the attachment.”
- **⑦ IMDSv2.** “The instance asks the metadata service at 169.254.169.254. Version 2 requires a PUT to get a session token first, with a TTL up to six hours, and a hop limit of one so a container on the instance cannot reach it. Version 1 is a plain GET, and that is the SSRF story.”
- **⑧ temporary credentials.** “The answer is an access key, a secret, and a session token, rotated roughly every six hours. Nothing is written to disk. Lose the instance, lose the credentials.”
- **⑨ SDK credential chain.** “The SDK looks in order: environment variables, a profile file, the container endpoint, then IMDS. Knowing the order explains why a stray key in a profile file silently overrides the role.”
- **⑩ cross-account AssumeRole.** “A role in account B trusts a principal in account A. STS issues temporary credentials. ExternalId stops the confused-deputy problem when a third party does the assuming.”
- **⑪ guardrails first.** “Before any of this exists: three budgets, alerts tested, MFA on root, root access keys deleted. The script does the budgets. The rest is a five-minute console task you do once.”
- **Close.** “Deny first, ceilings next, then an Allow or nothing. And a machine earns credentials by being who it is, not by holding a key. Week 12 and week 16 are the same idea for a GitHub workflow and for a pod.”

---

## Day plan
| Day | Focus | Lab |
|---|---|---|
| Mon | Guardrails, account structure, CLI, SAA course start | Lab 1 |
| Tue | **IAM deep** — policies, roles, evaluation logic | Lab 2 |
| Wed | Cross-account roles, permission boundaries | Lab 3 |
| Thu | EC2, EBS, AMIs, security groups, user data | Lab 4 |
| Fri | Instance profiles + IMDSv2 + Break/Fix | Lab 5 |
| Sat | SAA course: IAM + EC2 domains; practice questions | — |
| Sun | Review, Anki, plan week 6 | — |

## Reading map

**Primary — the reference library has a full SAA course. Use it.**
- `_reference/aws/phase-1-foundations-notes-01-cloud-fundamentals.md`
- `_reference/aws/phase-1-foundations-notes-02-iam-deep-dive.md`
- `_reference/aws/phase-2-compute-storage-notes-01-ec2-deep-dive.md`
- `_reference/aws/phase-2-compute-storage-notes-03-ebs-volumes.md`
- **Cheat sheets:** `phase-1-foundations-cheat-sheets-iam-cheat-sheet.md`,
  `phase-2-compute-storage-cheat-sheets-ec2-compute-cheat-sheet.md`
- **Practice questions:** `phase-1-foundations-practice-questions-questions.md`
- **Existing labs worth doing:** `phase-1-foundations-labs-lab-01-iam-policies.md`,
  `phase-2-compute-storage-labs-lab-01-ec2-launch-configure.md`
- **Study plan:** `_reference/aws/AWS_SAA_STUDY_PLAN.md`

**Choose ONE video course as your spine** — Stephane Maarek (faster) or Adrian Cantrill (deeper,
better labs). Not both. See `../CERTIFICATIONS.md`.

**Free and authoritative:** the AWS SAA exam guide (use as a coverage checklist), AWS Skill Builder,
the FAQ pages for IAM and EC2.

## Method for month 2

**Build every service by hand in the console before automating it.** This is deliberate and it
inverts in month 3. Console-first builds the mental model that makes Terraform legible; going
straight to Terraform means learning two things at once and understanding neither.

## Labs
[labs/LABS.md](labs/LABS.md) · [solutions/SOLUTIONS.md](solutions/SOLUTIONS.md)

| # | Lab | Time | Cost |
|---|---|---|---|
| 1 | Account guardrails and the CLI | 1h | $0 |
| 2 | IAM policies from scratch | 3h | $0 |
| 3 | Roles, assume-role, boundaries | 3h | $0 |
| 4 | EC2, EBS, AMIs, security groups | 3h | ~$1 |
| 5 | Instance profiles, IMDSv2, Break/Fix | 3h | ~$1 |

**Destroy everything each night.** `bash ../_setup/03-teardown.sh`

## Drills
- `_shared/drills/aws-comparisons.md` — IAM and Compute sections, daily
- Subnetting: 10/day (maintenance now, not acquisition)
- Anki: import `_reference/aws/anki-README.md` decks + write your own

## Exit criteria
- [ ] Budget alarms firing to your email (test one)
- [ ] Recite the IAM policy evaluation order from memory
- [ ] Write a policy granting read-only on one S3 prefix, from scratch, and test both allow and deny
- [ ] Cross-account role assumption working between two roles
- [ ] EC2 instance calling AWS APIs with **no credentials on disk** — and explain the mechanism
- [ ] Explain IMDSv1 vs IMDSv2 and why it matters for SSRF
- [ ] Blog post #3 published
- [ ] Everything destroyed; bill checked
