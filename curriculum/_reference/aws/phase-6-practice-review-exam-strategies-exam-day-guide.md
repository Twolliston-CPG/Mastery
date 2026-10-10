# Exam Day Guide — SAA-C03

Everything you need to know about exam logistics, time management, and answering strategies.

---

## Before the Exam

### The Week Before
- Take Practice Exam 3 (your hardest exam) at least 3 days before the real exam
- Review wrong answers from all three practice exams
- Read the ultimate cheat sheet and keyword matrix
- Get good sleep for 2-3 nights before the exam
- Do NOT cram the night before — light review only

### The Day Before
- Skim the ultimate cheat sheet (30-45 minutes)
- Review commonly confused services
- Skim the service limits document
- Go to bed early
- Prepare your ID and exam logistics

### Exam Morning
- Read the last-minute review document (30 minutes)
- Eat a good meal (not too heavy)
- Arrive 15-30 minutes early for test center exams
- For online proctored exams: test your setup at least 1 hour before

---

## Exam Format

| Attribute | Detail |
|---|---|
| **Exam Code** | SAA-C03 |
| **Questions** | 65 scored + 15 unscored (you won't know which) |
| **Total Questions** | 80 (but timer is for 65) |
| **Time** | 130 minutes (2 hours 10 minutes) |
| **Question Types** | Multiple choice (1 answer from 4) and Multiple response (2 or 3 from 5-6) |
| **Passing Score** | 720 out of 1000 (scaled scoring) |
| **Cost** | $150 USD |
| **Validity** | 3 years |

### Important Notes
- There is NO penalty for wrong answers — ALWAYS answer every question
- You can flag questions and return to them
- The 15 unscored questions are experimental — you cannot identify them, so treat every question as scored

---

## Time Management Strategy

### The Math
- 130 minutes / 65 questions = **2 minutes per question**
- Target: 90 seconds per question (leaves 32 minutes for review)

### Three-Pass Strategy

**Pass 1: Quick Answers (60-70 minutes)**
- Read each question and answers
- If you know the answer immediately: select it and move on
- If you are unsure but can narrow to 2 options: select your best guess and FLAG the question
- If you are completely stuck: select your best guess and FLAG the question
- NEVER leave a question blank
- Target: 60-90 seconds per question

**Pass 2: Flagged Questions (30-40 minutes)**
- Return to flagged questions
- Re-read carefully — sometimes the second read reveals details you missed
- For "select TWO" questions: re-evaluate each option methodically
- Spend up to 3 minutes per flagged question

**Pass 3: Final Review (20-30 minutes)**
- Review any remaining flagged questions
- Skim through all answers — look for obvious mistakes
- Do NOT change answers unless you have a strong reason
- Your first instinct is usually correct

---

## Answering Strategies

### The Elimination Method
For every question, eliminate wrong answers before selecting the right one:

1. **Eliminate impossible answers** — answers that violate AWS fundamentals (e.g., "encrypt existing RDS in-place")
2. **Eliminate over-engineered answers** — if a simpler solution exists, the complex one is usually wrong
3. **Eliminate wrong-service answers** — if the question says "real-time" and the answer says "SQS", eliminate it
4. **Choose between the remaining 2** — now focus on the subtle difference

### Reading the Question

**Read the LAST sentence first.** The last sentence tells you what they are actually asking:
- "...with the LEAST operational overhead?" → Choose managed/serverless
- "...that is MOST cost-effective?" → Choose the cheapest option that meets requirements
- "...with the HIGHEST availability?" → Choose Multi-AZ, multi-region
- "...MOST secure?" → Choose the most restrictive option that works

**Identify qualifiers:**
- "LEAST" / "MINIMUM" → Simplest solution that meets requirements
- "MOST" / "MAXIMUM" → Best-in-class solution
- "Select TWO" / "Select THREE" → Read carefully, multiple correct answers

### Handling "Select TWO" Questions
- Evaluate each option independently (is this true/valid?)
- Often the two correct answers complement each other (e.g., one for compute, one for storage)
- If you are sure about one answer, the second answer is often the one that pairs logically with it
- Do NOT select options that contradict each other

### When You Are Stuck
1. Eliminate what you know is wrong
2. Look for AWS best practices (managed > unmanaged, roles > access keys, encryption > no encryption)
3. Consider "what would AWS recommend?" (AWS always favors their managed services)
4. Select your best guess, flag it, and move on — do not spend more than 3 minutes on any question

---

## Keyword Triggers — Quick Reference

When you see these words in a question, think of these services:

| Keyword in Question | Think This Service |
|---|---|
| "cost-effective" / "minimize cost" | Spot, Reserved, Savings Plans, S3 lifecycle, right-sizing |
| "least operational overhead" / "minimize management" | Managed service, serverless (Lambda, Fargate, Aurora Serverless) |
| "decouple" / "loosely coupled" | SQS, SNS, EventBridge |
| "real-time" / "streaming" | Kinesis Data Streams |
| "near-real-time" | Kinesis Data Firehose |
| "serverless" | Lambda, Fargate, API Gateway, DynamoDB, Aurora Serverless |
| "temporary credentials" | IAM Roles, STS |
| "static IP" | NLB, Global Accelerator, Elastic IP |
| "global users" / "low latency worldwide" | CloudFront, Global Accelerator, DynamoDB Global Tables |
| "HIPAA" / "PCI" / "compliance" | Encryption (KMS), CloudTrail, specific compliant services |
| "DDoS protection" | Shield (Standard = free Layer 3/4, Advanced = paid with DRT) |
| "SQL injection" / "XSS" | WAF |
| "sensitive data in S3" / "PII" | Macie |
| "threat detection" | GuardDuty |
| "migrate database" | DMS (+ SCT for schema conversion) |
| "hybrid" / "on-premises + cloud" | Storage Gateway, Direct Connect, VPN, DataSync |
| "Windows file share" / "SMB" | FSx for Windows File Server |
| "Linux file share" / "NFS" | EFS |
| "HPC" / "tightly coupled" | Cluster placement group, EFA (Elastic Fabric Adapter) |
| "data warehouse" / "OLAP" | Redshift |
| "key-value" / "millisecond latency" | DynamoDB |
| "microsecond latency" | DAX, ElastiCache |
| "session management" | ElastiCache for Redis |
| "message exactly once, in order" | SQS FIFO |
| "fan out to multiple consumers" | SNS (+ SQS queues) or Kinesis |
| "automatic failover" | Multi-AZ (RDS, ElastiCache), Aurora Replicas |
| "cross-region disaster recovery" | Cross-region read replicas, S3 CRR, Aurora Global DB |

---

## Common Traps in Exam Questions

### Distractor Patterns

1. **The "AWS-managed key" trap**: "Use SSE-S3" sounds right but does not give you key management control when the question asks for it.

2. **The "more is better" trap**: Adding unnecessary services (e.g., both SQS AND Kinesis) when only one is needed.

3. **The "CloudFormation solves everything" trap**: CloudFormation provisions infrastructure but does not solve architectural problems.

4. **The "just scale up" trap**: Vertical scaling is almost never the best answer on the SAA exam. Look for horizontal scaling, caching, or decoupling.

5. **The "Direct Connect is always better" trap**: Direct Connect takes weeks to set up. If the question says "quickly" or "within hours", use VPN.

6. **The "Lambda handles everything" trap**: Lambda has limits (15 min, 10 GB memory). If the workload exceeds these, think ECS/Fargate.

7. **The "Multi-AZ improves read performance" trap**: Multi-AZ standby cannot serve reads. Use Read Replicas for read performance.

8. **The "S3 Standard is cheapest" trap**: Standard is cheapest per request but most expensive per GB stored. Match the storage class to the access pattern.

---

## Scoring

- The exam uses **scaled scoring** from 100 to 1000
- **720 is passing** (roughly 72%)
- You do NOT need to pass each domain independently
- Different questions may have different weights
- There is NO penalty for wrong answers — always guess

### Approximate Score Calculation
- 65 scored questions, passing at ~72%
- You need approximately **47 correct out of 65**
- This gives you room for **18 wrong answers**
- If you can confidently eliminate 2 options on every question, your guessing odds go from 25% to 50%

---

## After the Exam

- You will see a preliminary pass/fail result immediately on screen
- Official score report arrives within 5 business days (usually within 24-48 hours)
- Score breakdown by domain helps identify weak areas if you plan to take another cert
- Digital badge and certificate available through Credly
- Your certification is valid for 3 years
- Recertify by passing the SAA-C03 again or by passing a professional-level exam

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Before the Exam
- Exam Format
- Time Management Strategy
- Answering Strategies

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"The security group allows the traffic."* |
| ✓ | *"A security group is a stateful allow-list attached to an ENI. Traffic matching an inbound rule is permitted and the reply is permitted automatically, because the connection is tracked — which is why you never write an outbound rule for a reply."* |

**Trace it:** A request from the internet to an instance in a private subnet. Name every hop, every route-table lookup, and every rule evaluated, in order.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** [Timeouts, retries and backoff with jitter](https://aws.amazon.com/builders-library/timeouts-retries-and-backoff-with-jitter/) — 15 minutes from the AWS Builders' Library, and it changes how you write every client you touch afterwards.
Full list per domain: [`SOURCES.md`](../SOURCES.md#aws)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../MASTERY.md)

<!-- /feynman-check -->
