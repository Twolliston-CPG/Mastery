# Figure 7.1 — ALB to ASG to RDS, with the two numbers you measure

> Week 7 · badges ① to ⑩ · about three and a half minutes at a normal pace. Point at each badge as you say its line. Blue is the path to follow first; orange-red is where something refuses or fails.

![Figure 7.1 — ALB to ASG to RDS, with the two numbers you measure](figure-7.1-alb-to-asg-to-rds-with.png)

The first real architecture: traffic in at the top, compute that replaces itself, a database that fails over. The week is about measuring the two recovery times, not reading about them.

## What to say, badge by badge

- **Open.** “Week 7 is where architecture starts, and the point of the week is two numbers you measure yourself: how long the fleet takes to heal, and how long the database is gone during a failover. Follow the blue line, then look at the two orange boxes.”
- **① Route 53.** “An alias record at the apex of your domain, pointing at the ALB. Alias, not CNAME, because the apex cannot hold a CNAME. Health-checked, so a dead endpoint is removed from the answer.”
- **② Application Load Balancer.** “Layer 7. Listener rules route by path and host. It terminates HTTPS with an ACM certificate. Compare it to the NLB in the lab: layer 4, static IPs, millions of connections, no routing rules.”
- **③ target group.** “Health checks every 30 seconds. Two consecutive passes mark a target healthy, two failures mark it unhealthy. That window is the floor on how fast anything above can react.”
- **④ Auto Scaling group.** “Minimum two, one per AZ, maximum six. A launch template defines the instance. Target tracking at 50 percent CPU scales out under load and, the part people forget to watch, scales back in afterwards.”
- **⑤ measurement one.** “Terminate an instance on purpose. Time it from termination to the replacement reporting InService. The 300-second grace period is part of that number. Write it down. It goes in blog post 4.”
- **⑥ RDS Multi-AZ.** “A primary and a standby in another AZ, replicated synchronously. Every commit lands on both before it is acknowledged. The standby takes no reads; it exists to take over.”
- **⑦ read replica.** “Asynchronous. It scales reads and it can lag. It is not high availability. One sentence for each: Multi-AZ is for failover, a replica is for read capacity.”
- **⑧ measurement two.** “Force a failover while a loop hammers the database and timestamps every result. The DNS name flips to the standby. Count the seconds of errors. Typically 60 to 120. That is your number, and it is the honest answer to how much downtime Multi-AZ costs.”
- **⑨ DynamoDB.** “A partition key and a sort key serve the first access pattern. A global secondary index serves the second. Design the table from the queries, not from the data.”
- **⑩ Lambda in a VPC.** “A Lambda attached to a public subnet still has no internet, because its interface has no public IP. It needs a NAT, like any private instance. This is a favourite exam trap and the week-6 route-table lesson again.”
- **Close.** “Traffic in, fleet that heals, database that fails over. Two measured numbers in your own words beat any diagram you copied, and both go into Project Alpha's README.”

**Print it:** [`figure-7.1-numbered-spoken.pdf`](figure-7.1-numbered-spoken.pdf) is the two-page version, the figure on page one and this script on page two.

## Use it

- Read the figure before the day plan. Say the script out loud on Friday with the file closed.
- Each badge line is a thirty-second interview answer; the whole script is the three-minute version.
- Regenerate after editing the spec in `_shared/diagrams/week_figures/`:

```bash
python3 ../../_shared/diagrams/generate-week-figures.py --only 7
```
