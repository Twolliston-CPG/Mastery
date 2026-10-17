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

**Figure 8.1 — Decouple, encrypt, observe, and know what it costs.** Three short paths rather than one: a queue that absorbs load, a key that can say no, and an alarm that you force to fire. The DR strategies are the table under the figure. Badges are numbered in the order to walk them; the blue path is the one to follow first.

```mermaid
%%{init: {'theme':'base','themeVariables':{'fontFamily':'Helvetica, Arial, sans-serif','fontSize':'13px','primaryColor':'#ffffff','primaryTextColor':'#2d3436','primaryBorderColor':'#9aa3ab','lineColor':'#9aa3ab','textColor':'#2d3436','clusterBkg':'#fbfcfd','clusterBorder':'#d4dae0','edgeLabelBackground':'#ffffff','tertiaryColor':'#eef4fb'},'flowchart':{'curve':'basis','padding':14,'nodeSpacing':42,'rankSpacing':58}}}%%
flowchart LR
  classDef default fill:#ffffff,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef n    fill:#ffffff,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef crit fill:#eef4fb,stroke:#2f6fb8,stroke-width:1.8px,color:#1b3a5c
  classDef data fill:#f4f7fa,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef mut  fill:#ffffff,stroke:#cfd6dc,stroke-width:1.1px,color:#7a8288
  classDef warn fill:#fdf0ec,stroke:#c0522d,stroke-width:1.6px,color:#8a3a1e

  subgraph Q["Decoupling"]
    direction LR
    API["① producer<br/><small>API or event</small>"]:::crit
    SQS["② SQS queue<br/><small>visibility timeout 30 s · at-least-once · BF-31</small>"]:::crit
    LAM["③ consumer Lambda<br/><small>idempotent · deletes on success</small>"]:::crit
    DLQ["④ dead-letter queue<br/><small>after maxReceiveCount · the poison pill lands here</small>"]:::warn
  end
  subgraph K["Keys and secrets"]
    direction LR
    KMS["⑤ KMS customer-managed key<br/><small>key policy is the root of trust · deny beats full S3 access</small>"]:::warn
    SEC["⑥ Secrets Manager · Parameter Store<br/><small>rotation · versions · IAM-scoped reads</small>"]:::data
  end
  subgraph O["Observability"]
    direction LR
    CW["⑦ CloudWatch metric → alarm<br/><small>forced with set-alarm-state</small>"]:::crit
    SNS["⑧ SNS → email<br/><small>an untested alarm is decoration</small>"]:::crit
    CT["⑨ CloudTrail → Logs Insights<br/><small>who did what · all 5xx in the last hour</small>"]:::data
  end
  CF["⑩ CloudFront + OAC<br/><small>serves a private bucket · the bucket allows the distribution only</small>"]:::n
  ORG["⑪ Organizations SCP<br/><small>a ceiling on every account below it</small>"]:::n
  API ==> SQS ==> LAM
  SQS --> DLQ
  CW ==> SNS
  LAM -.-> KMS
  LAM -.-> SEC
  LAM -.-> CT
  CF -.-> KMS
  ORG -.-> API
  linkStyle 0,1,3 stroke:#2f6fb8,stroke-width:2px
```

**What to say, badge by badge** · about four minutes at a normal pace. Point at each badge as you say its line.

- **Open.** “The last of the SAA surface area, and the services you will touch every day afterwards. Three small stories: a queue that protects a consumer, a key that can refuse an administrator, and an alarm you do not trust until you have forced it to fire.”
- **① producer.** “Anything that emits work: an API, an event, a schedule. It writes to the queue and returns immediately. It never waits on the consumer.”
- **② SQS queue.** “Messages are delivered at least once. When a consumer reads one, it becomes invisible for the visibility timeout, 30 seconds by default. If the consumer takes longer and does not extend it, the message reappears and is processed twice. That is BF-31, and you reproduce it on purpose.”
- **③ consumer Lambda.** “Because delivery is at-least-once, the consumer must be idempotent: doing the work twice must be safe. It deletes the message only after success.”
- **④ dead-letter queue.** “A message that fails maxReceiveCount times moves here instead of blocking the queue forever. Send a poison pill and watch it land. Without a DLQ, one bad message can stall everything behind it.”
- **⑤ KMS customer-managed key.** “The key policy, not IAM, is the root of trust for a key. The lab gives a principal full S3 access and then denies it in the key policy. The object reads fail. That is the demonstration that encryption is an access control, not just a checkbox.”
- **⑥ Secrets Manager and Parameter Store.** “Secrets Manager rotates and costs per secret. Parameter Store is cheaper and fine for configuration. Either way, the application reads at runtime with an IAM-scoped call and nothing lives in an environment file.”
- **⑦ CloudWatch alarm.** “A metric crosses a threshold for N periods and the alarm changes state. Force the state with `set-alarm-state` and watch the notification arrive. If you have not forced it, you do not know it works.”
- **⑧ SNS to email.** “The alarm publishes to a topic; the topic fans out to email, SMS, Lambda, or a queue. Confirm the subscription or nothing arrives.”
- **⑨ CloudTrail and Logs Insights.** “CloudTrail is who did what, to which resource, from where. Logs Insights is a query language over log groups. The exit criterion is one query: all 5xx in the last hour.”
- **⑩ CloudFront with OAC.** “A distribution in front of a private bucket. Origin Access Control signs the requests, and the bucket policy allows that distribution and nobody else. The bucket stays private and the content is public.”
- **⑪ Organizations SCP.** “A service control policy is a ceiling applied to every account under an OU. It grants nothing; it only removes. Deny leaving the organization, deny disabling CloudTrail, deny regions you do not use.”
- **Close.** “Four disaster-recovery strategies finish the week, and the one-line version is this: backup and restore is hours and cheap, pilot light is tens of minutes, warm standby is minutes, multi-site is seconds and costs double. RTO and RPO are what you are buying.”

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
