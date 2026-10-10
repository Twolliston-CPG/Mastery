# Week 7 — Compute, Scaling, and Databases

> **Thesis:** this is where "architecture" starts. Every question from here on is a tradeoff between
> availability, cost, and operational overhead — and the SAA exam is almost entirely about which
> qualifier the question used.

| | |
|---|---|
| **Hours** | 35–45 |
| **Deliverable** | Blog post #4 — "Multi-AZ vs read replicas: I failed over an RDS instance to find out" |
| **Break/Fix** | BF-28, BF-29, BF-30 |
| **Exit check** | Measure a real RDS failover and a real ASG recovery. Write the numbers down. |

## Day plan
| Day | Focus | Lab |
|---|---|---|
| Mon | ALB, target groups, listener rules | Lab 1 |
| Tue | ASG, launch templates, scaling policies | Lab 2 |
| Wed | RDS: Multi-AZ, replicas, **measured failover** | Lab 3 |
| Thu | DynamoDB: keys, indexes, capacity | Lab 4 |
| Fri | Lambda + ECS Fargate + Break/Fix | Lab 5 |
| Sat | SAA: compute + database domains; 40 questions | — |
| Sun | Blog post #4; plan week 8 | — |

## Reading map
- `_reference/aws/phase-1-foundations-notes-05-elastic-load-balancing.md`
- `_reference/aws/phase-2-compute-storage-notes-02-auto-scaling.md`
- `_reference/aws/phase-2-compute-storage-notes-05-lambda-serverless.md`
- `_reference/aws/phase-2-compute-storage-notes-04-containers-ecs-eks.md`
- `_reference/aws/phase-3-databases-integration-notes-01-rds.md`, `-02-aurora.md`, `-03-dynamodb.md`
- **Cheat sheets:** `phase-3-databases-integration-cheat-sheets-databases-cheat-sheet.md`
- **Labs:** `phase-2-compute-storage-labs-lab-02-auto-scaling-group.md`,
  `phase-3-databases-integration-labs-lab-01-rds-mysql-setup.md`,
  `phase-3-databases-integration-labs-lab-02-dynamodb-crud.md`

## Labs
[labs/LABS.md](labs/LABS.md) · [solutions/SOLUTIONS.md](solutions/SOLUTIONS.md)

| # | Lab | Time | Cost |
|---|---|---|---|
| 1 | ALB and target groups | 3h | ~$1 |
| 2 | ASG, launch templates, scaling | 3h | ~$1 |
| 3 | RDS Multi-AZ and measured failover | 3h | ~$3 |
| 4 | DynamoDB access patterns | 2h | <$1 |
| 5 | Lambda, Fargate, Break/Fix | 3h | <$1 |

**Destroy nightly.** An ALB is ~$0.55/day and an RDS Multi-AZ `db.t3.micro` is ~$1.20/day.

## Exit criteria
- [ ] ALB → ASG across 2 AZs, load-tested, observed scaling out **and back in**
- [ ] Terminated an instance and **measured** ASG recovery time
- [ ] Triggered an RDS failover and **measured** downtime
- [ ] Explain Multi-AZ vs read replica in one sentence each
- [ ] DynamoDB table with a GSI queried by both access patterns from boto3
- [ ] Explain why a VPC Lambda in a public subnet still has no internet
- [ ] Blog post #4 with your real numbers
