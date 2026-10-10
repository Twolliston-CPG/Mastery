# Route 53 and ELB Cheat Sheet

Quick reference for Route 53 routing policies, record types, and ELB comparison.

---

## Route 53 Essentials

| Fact | Detail |
|---|---|
| Service type | Authoritative DNS (you control the records) |
| Scope | Global (not Region-specific) |
| SLA | **100%** (only AWS service with this SLA) |
| Port | 53 (TCP/UDP) |
| Hosted zone cost | $0.50/month per hosted zone |
| Query cost | $0.40 per million queries (standard), Alias queries to AWS resources: **free** |

---

## Record Types

| Type | Maps To | Zone Apex? | Notes |
|---|---|---|---|
| **A** | IPv4 address | Yes | Most common |
| **AAAA** | IPv6 address | Yes | |
| **CNAME** | Another domain name | **No** | Cannot be at zone apex |
| **Alias** | AWS resource | **Yes** | Route 53 extension. Free queries. |
| **MX** | Mail server | N/A | Priority + mail server hostname |
| **NS** | Name servers | N/A | Auto-created with hosted zone |
| **SOA** | Zone metadata | N/A | Auto-created with hosted zone |
| **TXT** | Text data | N/A | SPF, domain verification |
| **SRV** | Service locator | N/A | Host + port for services |
| **PTR** | Reverse DNS (IP -> name) | N/A | |

---

## Alias vs. CNAME

| Feature | Alias Record | CNAME Record |
|---|---|---|
| Zone apex (naked domain) | **Yes** | **No** |
| Target | AWS resources only | Any domain name |
| DNS query charge | **Free** (AWS targets) | Charged |
| TTL | Set automatically | You configure |
| Looks like | A or AAAA record | CNAME record |

**Alias targets:** ALB, NLB, CloudFront, S3 website, API Gateway, Elastic Beanstalk, VPC Endpoint, Global Accelerator, another Route 53 record.

**NOT Alias targets:** EC2 instances, RDS endpoints (use CNAME).

---

## Routing Policies Comparison

| Policy | What It Does | Health Checks? | Key Use Case |
|---|---|---|---|
| **Simple** | Returns one or more values (random order) | No | Single resource, basic setup |
| **Weighted** | Distributes by % (weight / total weight) | Yes | A/B testing, gradual migration |
| **Latency** | Routes to lowest-latency Region | Yes | Multi-Region, best performance |
| **Failover** | Primary/Secondary (active-passive) | Yes (required for primary) | Disaster recovery |
| **Geolocation** | Routes by user's country/continent | Yes | Content localization, compliance |
| **Geoproximity** | Routes by location + adjustable bias | Yes | Fine-tuned geographic control |
| **Multivalue** | Returns up to 8 healthy IPs | Yes | Client-side LB with health filtering |

### Choosing a Routing Policy

```
Need active-passive DR?           --> Failover
Need traffic split by percentage? --> Weighted
Need best performance globally?   --> Latency
Need compliance by location?      --> Geolocation
Need adjustable geographic zones? --> Geoproximity
Need basic multi-IP with health?  --> Multivalue
Just one resource, nothing fancy? --> Simple
```

---

## Health Checks

| Type | Monitors | Use Case |
|---|---|---|
| **Endpoint** | IP or domain name (HTTP/HTTPS/TCP) | Public-facing resources |
| **Calculated** | Combines child health checks (AND/OR/threshold) | Multi-tier health |
| **CloudWatch alarm** | CloudWatch alarm state | **Private resources** (not reachable by health checkers) |

**Cannot monitor private IPs directly.** Use CloudWatch alarm health check as a bridge.

### Health Check Settings

| Setting | Default | Range |
|---|---|---|
| Interval | 30 seconds | 10s (fast) or 30s (standard) |
| Failure threshold | 3 | 1-10 |
| Regions | Auto (3+) | Choose specific or auto |
| String matching | None | Check first 5,120 bytes of response body |

---

## DNS Failover Patterns

### Active-Passive

```
Route 53 Failover
  Primary -----> ALB us-east-1 (health check: ON)
  Secondary ---> S3 static site or ALB us-west-2
```

### Active-Active

```
Route 53 Weighted/Latency (with health checks)
  Record 1 --> ALB us-east-1 (weight: 50 or latency)
  Record 2 --> ALB us-west-2 (weight: 50 or latency)
  (Unhealthy records automatically excluded)
```

---

## Elastic Load Balancer Types

| Feature | ALB | NLB | GLB | CLB |
|---|---|---|---|---|
| **Layer** | 7 (HTTP/HTTPS) | 4 (TCP/UDP/TLS) | 3 (IP/GENEVE) | 4 + limited 7 |
| **Best for** | Web apps, APIs | Extreme perf, static IP | Network appliances | Legacy (avoid) |
| **Targets** | Instance, IP, Lambda, Container | Instance, IP, ALB | Instance, IP | Instance |
| **Static IP** | No | **Yes** (per AZ) | No | No |
| **Content routing** | **Yes** (path, host, header, query) | No | No | No |
| **WebSocket** | Yes | Yes | N/A | No |
| **gRPC** | Yes | No | No | No |
| **SNI (multi-cert)** | Yes | Yes | N/A | **No** |
| **Source IP preserved** | No (use X-Forwarded-For) | **Yes** | Yes | No |
| **Cross-zone LB default** | **Enabled** (free) | Disabled (charged) | Disabled (charged) | Disabled (free) |
| **PrivateLink** | No | **Yes** (endpoint service) | Yes | No |
| **Cost** | ~$0.0225/hr + LCU | ~$0.0225/hr + NLCU | ~$0.0125/hr + GLCU | ~$0.025/hr + data |

---

## ALB Routing Rules

```
Listener (HTTPS:443)
  Rule 1: IF path = /api/*        THEN forward -> api-target-group
  Rule 2: IF host = admin.example THEN forward -> admin-target-group
  Rule 3: IF header X-Custom = v2 THEN forward -> v2-target-group
  Rule 4: IF path = /old/*        THEN redirect -> /new/*
  Rule 5: IF path = /maintenance  THEN fixed-response 503 "Down"
  Default:                         THEN forward -> web-target-group
```

**Condition types:** Path pattern, Host header, HTTP header, HTTP method, Query string, Source IP.

**Action types:** Forward, Redirect, Fixed response, Authenticate (Cognito/OIDC).

---

## Key ELB Concepts

### Sticky Sessions

| Type | Cookie | Set By |
|---|---|---|
| Duration-based | `AWSALB` (ALB) / `AWSELB` (CLB) | Load balancer |
| Application-based | Custom name (not `AWSALB*`) | Your application |

**Better alternative:** Externalize session state to ElastiCache or DynamoDB.

### Connection Draining / Deregistration Delay

- Allows in-flight requests to complete when a target is removed.
- Default: 300 seconds. Range: 0-3600 seconds.
- Set to 0 to disable (immediate termination).
- Match to your longest request processing time.

### Cross-Zone Load Balancing

| Without Cross-Zone | With Cross-Zone |
|---|---|
| Each AZ node routes to its own AZ only | All nodes route to all targets across AZs |
| Uneven distribution if AZs have different target counts | Even distribution regardless of per-AZ target count |

---

## Choosing an ELB

```
Need HTTP routing (path, host, headers)?      --> ALB
Need static IP or Elastic IP on LB?           --> NLB
Need ultra-low latency (<1ms)?                --> NLB
Need non-HTTP protocol (TCP, UDP, custom)?    --> NLB
Need to front a PrivateLink endpoint service? --> NLB
Need ALB features + static IP?                --> NLB in front of ALB
Need third-party firewall/IDS inspection?     --> GLB
See "Classic Load Balancer" in an answer?     --> Probably a distractor; use ALB or NLB
```

---

## Cost Awareness

| Component | Rate | Tip |
|---|---|---|
| Route 53 hosted zone | $0.50/month | Delete after labs |
| Route 53 queries (standard) | $0.40/million | Alias to AWS resources = free |
| Route 53 health check (basic) | $0.50/month | Delete after labs |
| Route 53 health check (fast, 10s) | $1.00/month | Use 30s for labs |
| ALB | ~$0.0225/hour + LCU | Tear down after labs |
| NLB | ~$0.0225/hour + NLCU | Tear down after labs |

---

## Exam Quick Tips

1. **"Naked domain to ALB?"** --> Alias A record. CNAME won't work at zone apex.
2. **"Best performance globally?"** --> Latency-based routing.
3. **"A/B testing with DNS?"** --> Weighted routing (e.g., 90/10 split).
4. **"Active-passive DR?"** --> Failover routing with health check on primary.
5. **"Monitor private endpoint health for DNS failover?"** --> CloudWatch alarm health check.
6. **"Need static IP on load balancer?"** --> NLB.
7. **"Multiple SSL certs on one LB?"** --> ALB or NLB with SNI. CLB cannot.
8. **"Network appliance inspection?"** --> GLB (GENEVE protocol, port 6081).
9. **"Users losing sessions behind ALB?"** --> Use ElastiCache for session state (better than sticky sessions).
10. **"Cross-zone LB default?"** --> ALB: on (free). NLB: off (charged if enabled).
11. **"ALB not seeing client IP?"** --> Check `X-Forwarded-For` header.
12. **"Lower TTL before migration"** --> Allows DNS changes to propagate quickly.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Route 53 Essentials
- Record Types
- Alias vs. CNAME
- Routing Policies Comparison

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
