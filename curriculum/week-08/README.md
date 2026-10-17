# Week 8 — Integration, Security, Monitoring, Cost

> **Thesis:** the remaining SAA surface area, plus the services you will actually use every day.
> The decoupling patterns here are also the backbone of every "design an event-driven system"
> interview question.

| | |
|---|---|
| **Hours** | 35–45 |
| **Deliverable** | Blog post #5 — "Four DR strategies and what each one actually costs" |
| **Break/Fix** | BF-31, BF-32 |
| **Exit check** | Decouple with SQS + DLQ; encrypt with a CMK and break it on purpose; build an alarm and force it to fire |

## The week in one figure

**Figure 8.1 — Decouple, encrypt, observe, and know what it costs.** Three short paths rather than one: a queue that absorbs load, a key that can say no, and an alarm that you force to fire. The DR strategies are the table under the figure.

![Figure 8.1 — Decouple, encrypt, observe, and know what it costs](content/figure-8.1-decouple-encrypt-observe-and-know-what.png)

**Say it, badge by badge:** [`content/FIGURE.md`](content/FIGURE.md) — the spoken script for each of the 11 badges, about four minutes; [`content/figure-8.1-numbered-spoken.pdf`](content/figure-8.1-numbered-spoken.pdf) is the printable two-page version. Read the figure before the day plan; say the script on Friday.

---

## Day plan
| Day | Focus | Lab |
|---|---|---|
| Mon | SQS, SNS, EventBridge, decoupling patterns | Lab 1 |
| Tue | KMS, Secrets Manager, Parameter Store | Lab 2 |
| Wed | CloudWatch, CloudTrail, Logs Insights | Lab 3 |
| Thu | CloudFront, Route 53, Organizations/SCPs | Lab 4 |
| Fri | Well-Architected, DR strategies, cost + Break/Fix | Lab 5 |
| Sat | SAA: remaining domains; 50 questions | — |
| Sun | Blog post #5; **week 9 is exam prep — plan it** | — |

## Reading map
- `_reference/aws/phase-3-databases-integration-notes-06-sqs.md`, `-07-sns-eventbridge.md`,
  `-09-api-gateway-step-functions.md`
- `_reference/aws/phase-4-security-monitoring-notes-01-kms-encryption.md`, `-02-secrets-certificates.md`,
  `-06-cloudwatch.md`, `-07-cloudtrail-logging.md`, `-04-threat-detection-compliance.md`
- `_reference/aws/phase-5-advanced-architectures-notes-02-disaster-recovery.md`, `-03-cloudfront-cdn.md`
- **Cheat sheets:** `phase-4-security-monitoring-cheat-sheets-security-services-cheat-sheet.md`,
  `-monitoring-logging-cheat-sheet.md`, `phase-3-databases-integration-cheat-sheets-messaging-integration-cheat-sheet.md`
- **Labs:** `phase-4-security-monitoring-labs-lab-01-kms-encryption.md`, `-lab-05-cloudwatch-monitoring.md`,
  `phase-3-databases-integration-labs-lab-03-sqs-sns-messaging.md`

## Labs
[labs/LABS.md](labs/LABS.md) · [solutions/SOLUTIONS.md](solutions/SOLUTIONS.md)

| # | Lab | Time |
|---|---|---|
| 1 | Decoupling: SQS, SNS, EventBridge, DLQ | 3h |
| 2 | KMS and secrets | 3h |
| 3 | CloudWatch, alarms, Logs Insights, CloudTrail | 3h |
| 4 | CloudFront + OAC, Route 53, Organizations | 2h |
| 5 | DR strategies, cost, Break/Fix | 3h |

## Exit criteria
- [ ] API → SQS → Lambda with a DLQ; poison-pill a message and watch it land
- [ ] Reproduce BF-31 (visibility timeout) deliberately
- [ ] KMS CMK with a key policy; deny a principal that has full S3 access
- [ ] CloudWatch alarm → SNS → email, **tested by forcing the state**
- [ ] Logs Insights query finding all 5xx in the last hour
- [ ] CloudFront + OAC serving from a **private** bucket
- [ ] Name the four DR strategies with RTO/RPO and relative cost
- [ ] Cost Explorer view broken down by tag
