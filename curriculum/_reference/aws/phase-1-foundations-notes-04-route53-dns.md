# 04 -- Route 53 and DNS

## Table of Contents
1. [DNS Fundamentals](#dns-fundamentals)
2. [Route 53 Overview](#route-53-overview)
3. [Hosted Zones](#hosted-zones)
4. [Record Types](#record-types)
5. [Alias Records](#alias-records)
6. [Routing Policies](#routing-policies)
7. [Health Checks](#health-checks)
8. [DNS Failover Architectures](#dns-failover-architectures)
9. [Route 53 Resolver](#route-53-resolver)
10. [Key Takeaways for the SAA-C03 Exam](#key-takeaways-for-the-saa-c03-exam)

---

## DNS Fundamentals

DNS (Domain Name System) translates human-readable domain names (e.g., `www.example.com`) into IP addresses (e.g., `93.184.216.34`).

### DNS Hierarchy

```
Root (.)
  |
  +-- Top-Level Domain (TLD): .com, .org, .net, .io
        |
        +-- Second-Level Domain (SLD): example.com
              |
              +-- Subdomain: www.example.com, api.example.com
```

### DNS Resolution Flow (Simplified)

1. User types `www.example.com` in their browser.
2. Browser checks its local cache. If not found, asks the **OS resolver**.
3. OS resolver checks its cache. If not found, asks the **Recursive Resolver** (typically provided by the ISP or a public DNS like 8.8.8.8).
4. Recursive Resolver asks the **Root Name Server** -- "Where is `.com`?"
5. Root Name Server responds with the address of the **.com TLD Name Server**.
6. Recursive Resolver asks the TLD Name Server -- "Where is `example.com`?"
7. TLD Name Server responds with the address of the **Authoritative Name Server** (e.g., Route 53).
8. Recursive Resolver asks the Authoritative Name Server -- "What is the IP for `www.example.com`?"
9. Authoritative Name Server responds with the IP address.
10. Recursive Resolver caches the result (for the duration of the TTL) and returns it to the user.

### TTL (Time to Live)

TTL tells the recursive resolver how long to cache a DNS response (in seconds).

| TTL Value | Trade-off |
|---|---|
| High (e.g., 86400 = 24 hours) | Fewer DNS queries, lower cost, but changes take longer to propagate |
| Low (e.g., 60 = 1 minute) | Changes propagate quickly, but more DNS queries and higher cost |

**Exam tip:** Before a migration or failover, lower the TTL well in advance so that DNS changes propagate quickly when you make the switch.

[TODO: Add a detailed sequence diagram of DNS resolution with cache hits and misses]

---

## Route 53 Overview

Amazon Route 53 is a highly available, scalable **authoritative DNS** web service. The name refers to TCP/UDP port 53, which is used for DNS.

**Key capabilities:**
1. **Domain registration** -- Register new domain names directly through Route 53.
2. **DNS routing** -- Route traffic to AWS resources or external endpoints.
3. **Health checking** -- Monitor the health of your resources and route traffic away from unhealthy endpoints.

**Key characteristics:**
- **100% SLA** -- Route 53 is one of the few AWS services with a 100% availability SLA.
- **Global service** -- Route 53 is not Region-specific. Hosted zones and records are global.
- **Supports both public and private DNS.**
- **Answers DNS queries from the nearest edge location** for low latency.

---

## Hosted Zones

A **hosted zone** is a container for DNS records for a domain. It is analogous to a traditional DNS zone file.

### Public Hosted Zone

- Contains records that define how to route traffic **on the internet**.
- When you register a domain with Route 53 (or transfer DNS to Route 53), a public hosted zone is created.
- Route 53 assigns 4 name servers to each hosted zone (the NS records).
- **Cost:** $0.50/month per hosted zone.

### Private Hosted Zone

- Contains records that define how to route traffic **within one or more VPCs**.
- Useful for internal service discovery (e.g., `db.internal.example.com` resolves to a private IP).
- Must be associated with at least one VPC.
- Requires `enableDnsHostnames` and `enableDnsSupport` to be set to `true` on the VPC.

**Exam tip:** If a question mentions internal DNS resolution within a VPC, the answer involves a private hosted zone.

[TODO: Show how to associate a private hosted zone with a VPC using the CLI]

---

## Record Types

| Record Type | Purpose | Example |
|---|---|---|
| **A** | Maps a domain name to an IPv4 address | `www.example.com` -> `93.184.216.34` |
| **AAAA** | Maps a domain name to an IPv6 address | `www.example.com` -> `2001:db8::1` |
| **CNAME** | Maps a domain name to another domain name | `blog.example.com` -> `myblog.hosting.com` |
| **MX** | Specifies mail servers for the domain | `example.com` -> `10 mail.example.com` |
| **NS** | Specifies the authoritative name servers for the zone | `example.com` -> `ns-1234.awsdns-56.org` |
| **SOA** | Start of Authority -- contains zone metadata | Created automatically with every hosted zone |
| **TXT** | Contains text data, often for verification | SPF records, domain verification for SES |
| **SRV** | Specifies host and port for services | Used by some applications for service discovery |
| **PTR** | Reverse DNS lookup (IP to domain name) | `34.216.184.93.in-addr.arpa` -> `www.example.com` |

### CNAME Restrictions

- A CNAME record **cannot be created for the zone apex** (naked domain). For example, you CANNOT create a CNAME for `example.com` -- only for subdomains like `www.example.com`.
- This is a DNS protocol restriction, not an AWS restriction.
- **Solution: Use a Route 53 Alias record instead** (see below).

[TODO: Add examples of when to use each record type in real-world scenarios]

---

## Alias Records

An **Alias record** is a Route 53-specific extension to DNS. It maps a domain name to an AWS resource.

### Alias vs. CNAME

| Feature | CNAME | Alias |
|---|---|---|
| Zone apex (naked domain) | **NOT allowed** | **Allowed** |
| Targets | Any domain name | AWS resources only |
| DNS query charge | Charged | **Free** for AWS resource targets |
| TTL | You set it | Set by Route 53 automatically |
| Record type | CNAME | A or AAAA (looks like a regular A record to clients) |

### Supported Alias Targets

- Elastic Load Balancers (ALB, NLB, CLB)
- Amazon CloudFront distributions
- Amazon API Gateway
- Elastic Beanstalk environments
- Amazon S3 buckets (configured as static websites)
- VPC Interface Endpoints
- Another Route 53 record in the same hosted zone
- AWS Global Accelerator

### NOT Supported as Alias Targets

- EC2 instances (use an A record with the IP address or put an ELB in front)
- RDS instances (use a CNAME -- RDS provides a DNS endpoint, not an IP)

**Exam tip:** When a question asks about pointing a naked domain (`example.com`) to an ELB or CloudFront distribution, the answer is **Alias record**. CNAME will not work for zone apex.

[TODO: Explain how Alias records work under the hood -- Route 53 resolves the target and returns the IP directly]

---

## Routing Policies

Route 53 supports several routing policies that determine how it responds to DNS queries.

### 1. Simple Routing

- **One record, one or more values.**
- If multiple values are specified, Route 53 returns all of them in random order to the client.
- The client typically uses the first IP in the list.
- **No health checks** can be associated with simple routing records.
- **Use case:** Single resource, no special requirements.

### 2. Weighted Routing

- **Distribute traffic across multiple resources by percentage.**
- Each record has a weight (0-255). The percentage of traffic sent to a record is `weight / sum of all weights`.
- Setting a weight to 0 stops sending traffic to that resource.
- **Health checks supported** -- unhealthy records are excluded from responses.
- **Use case:** A/B testing, gradual migration (shift 10% of traffic to a new version, then 25%, then 50%, etc.).

**Example:**
| Record | Target | Weight | Traffic % |
|---|---|---|---|
| www.example.com | 10.0.1.1 | 70 | 70% |
| www.example.com | 10.0.2.1 | 20 | 20% |
| www.example.com | 10.0.3.1 | 10 | 10% |

### 3. Latency-Based Routing

- **Route traffic to the Region with the lowest latency** for the user.
- Route 53 maintains a latency database between users' locations and AWS Regions.
- You create records specifying which Region each resource is in.
- **Health checks supported.**
- **Use case:** Multi-Region deployments where you want users to hit the closest Region.

**Exam tip:** Latency-based routing does NOT look at geographic proximity. It measures actual network latency, which can differ from physical distance due to network topology.

### 4. Failover Routing

- **Active-passive failover.**
- You designate one record as **Primary** and another as **Secondary**.
- Route 53 returns the Primary record unless its health check fails, in which case it returns the Secondary.
- **Health checks required** for the Primary record.
- **Use case:** DR scenarios where you have a standby environment.

### 5. Geolocation Routing

- **Route based on the geographic location of the user.**
- You define records for continents, countries, or US states.
- If no matching location is found, the **default record** is returned (always create a default).
- **Health checks supported.**
- **Use case:** Content localization, regulatory compliance (keep European users in the EU Region), restricting content distribution.

**Note:** Geolocation is different from latency-based. Geolocation routes based on WHERE the user is. Latency-based routes based on which Region has the LOWEST LATENCY.

### 6. Geoproximity Routing

- **Route based on geographic location of users AND resources.**
- Allows you to define a **bias** to expand or shrink the geographic area that routes to a resource.
- Positive bias: Attract more traffic to the resource.
- Negative bias: Route traffic away from the resource.
- Requires **Route 53 Traffic Flow** (visual editor for complex routing).
- **Use case:** Fine-tuned geographic routing with bias control.

[TODO: Add a visual example showing how bias shifts the geographic routing boundary]

### 7. Multivalue Answer Routing

- **Return multiple values (up to 8) for a record, each with its own health check.**
- Route 53 returns only healthy records.
- Not a substitute for a load balancer (no intelligent traffic distribution), but improves availability over Simple Routing.
- **Use case:** Client-side load balancing across multiple resources with health-check filtering.

### Routing Policy Comparison Table

| Policy | Health Checks | Use Case | Key Differentiator |
|---|---|---|---|
| Simple | No | Single resource | Simplest option |
| Weighted | Yes | Traffic distribution by percentage | A/B testing, gradual migration |
| Latency | Yes | Multi-Region, lowest latency | Based on actual network latency |
| Failover | Yes (required for primary) | Active-passive DR | Primary/secondary designation |
| Geolocation | Yes | Location-based routing | User's physical location |
| Geoproximity | Yes | Location + bias control | Adjustable geographic boundaries |
| Multivalue | Yes | Improved simple routing | Returns up to 8 healthy IPs |

[TODO: Add a decision flowchart for choosing the right routing policy]

---

## Health Checks

Route 53 health checks monitor the health of your endpoints and can trigger DNS failover.

### Types of Health Checks

| Type | What It Monitors |
|---|---|
| **Endpoint health check** | Monitors an IP address or domain name. Route 53 sends requests to the endpoint at a configurable interval. |
| **Calculated health check** | Combines the results of multiple health checks using AND, OR, or a threshold (e.g., "healthy if at least 2 of 3 child checks are healthy"). |
| **CloudWatch alarm health check** | Monitors a CloudWatch alarm state. Useful for monitoring private resources that Route 53 health checkers cannot reach. |

### Endpoint Health Check Configuration

| Setting | Options |
|---|---|
| Protocol | HTTP, HTTPS, or TCP |
| Request interval | 30 seconds (standard) or 10 seconds (fast, costs more) |
| Failure threshold | Number of consecutive failures before marking unhealthy (1-10, default 3) |
| Health checker regions | Choose which Route 53 health checker Regions to use (at least 3) |
| String matching (HTTP/HTTPS) | Check if the response body contains a specific string (first 5,120 bytes) |
| Latency measurement | Optionally measure and graph latency |

### Monitoring Private Resources

Route 53 health checkers are on the public internet and **cannot access private endpoints** (e.g., a private IP inside a VPC).

**Solution:**
1. Create a CloudWatch metric that monitors your private resource (e.g., via a Lambda function or CloudWatch agent).
2. Create a CloudWatch alarm based on that metric.
3. Create a Route 53 health check that monitors the CloudWatch alarm.

[TODO: Show a concrete example with a Lambda function monitoring a private RDS instance]

---

## DNS Failover Architectures

### Active-Passive Failover

```
Route 53 (Failover routing)
  |
  +-- Primary: ALB in us-east-1 (health check: healthy)
  |
  +-- Secondary: S3 static website (sorry page) or ALB in us-west-2
```

- Normal operation: Route 53 returns the Primary endpoint.
- Primary fails health check: Route 53 returns the Secondary endpoint.
- When Primary recovers: Route 53 automatically switches back.

### Active-Active Failover

```
Route 53 (Weighted, Latency, or Multivalue routing with health checks)
  |
  +-- us-east-1 ALB (weight: 50, health check: healthy)
  |
  +-- us-west-2 ALB (weight: 50, health check: healthy)
```

- Normal operation: Traffic is distributed across both endpoints.
- One endpoint fails: Route 53 returns only the healthy endpoint.
- Both healthy again: Traffic is redistributed.

### Multi-Tier Failover with Calculated Health Checks

```
Route 53 (Failover routing)
  |
  +-- Primary: ALB in us-east-1
  |     Health check: Calculated (healthy if ALL child checks pass)
  |       +-- Child 1: Web tier health
  |       +-- Child 2: App tier health
  |       +-- Child 3: DB tier health
  |
  +-- Secondary: ALB in us-west-2
```

[TODO: Expand each architecture with concrete CloudFormation/Terraform configurations]

---

## Route 53 Resolver

Route 53 Resolver provides DNS resolution for hybrid cloud environments where you need DNS queries to flow between your VPC and on-premises networks.

### Components

| Component | Direction | Purpose |
|---|---|---|
| **Inbound Endpoint** | On-premises -> VPC | Allows on-premises DNS resolvers to forward queries to Route 53 Resolver |
| **Outbound Endpoint** | VPC -> On-premises | Allows Route 53 Resolver to forward queries to on-premises DNS servers |
| **Resolver Rules** | N/A | Define which domain queries are forwarded and where |

### Common Use Case

You have `corp.example.com` managed by an on-premises DNS server and `aws.example.com` managed by Route 53.

- Create an **Outbound Endpoint** and a forwarding rule: queries for `corp.example.com` are forwarded to the on-premises DNS server.
- Create an **Inbound Endpoint**: on-premises servers forward queries for `aws.example.com` to Route 53 through this endpoint.

[TODO: Add a network diagram showing bidirectional DNS resolution in a hybrid environment]

---

## Key Takeaways for the SAA-C03 Exam

1. **Alias records are free and work at the zone apex.** Use them for AWS resources instead of CNAME.
2. **CNAME cannot be used at the zone apex** (naked domain like `example.com`).
3. **Know all 7 routing policies** and when to use each one.
4. **Latency-based routing uses actual latency, not geography.** Geolocation routing uses geography.
5. **Failover routing requires a health check** on the primary record.
6. **Health checks cannot directly monitor private resources.** Use CloudWatch alarms as a bridge.
7. **Lower TTL before migrations** so DNS changes propagate quickly.
8. **Route 53 has a 100% SLA** -- the only AWS service with this guarantee.
9. **Private hosted zones** are used for internal DNS resolution within VPCs.
10. **Route 53 Resolver** enables hybrid DNS (on-premises <-> VPC).

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- DNS Fundamentals
- Route 53 Overview
- Hosted Zones
- Record Types

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
