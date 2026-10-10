# 05 -- Elastic Load Balancing (ELB)

## Table of Contents
1. [ELB Overview](#elb-overview)
2. [Application Load Balancer (ALB)](#application-load-balancer-alb)
3. [Network Load Balancer (NLB)](#network-load-balancer-nlb)
4. [Gateway Load Balancer (GLB)](#gateway-load-balancer-glb)
5. [Classic Load Balancer (CLB)](#classic-load-balancer-clb)
6. [Cross-Zone Load Balancing](#cross-zone-load-balancing)
7. [Sticky Sessions (Session Affinity)](#sticky-sessions-session-affinity)
8. [Connection Draining / Deregistration Delay](#connection-draining--deregistration-delay)
9. [SSL/TLS Termination and SNI](#ssltls-termination-and-sni)
10. [ELB Access Logs and Monitoring](#elb-access-logs-and-monitoring)
11. [ELB Comparison Table](#elb-comparison-table)
12. [Key Takeaways for the SAA-C03 Exam](#key-takeaways-for-the-saa-c03-exam)

---

## ELB Overview

Elastic Load Balancing automatically distributes incoming traffic across multiple targets (EC2 instances, containers, IP addresses, Lambda functions) in one or more Availability Zones.

**Why use a load balancer?**
- **High availability** -- Distributes traffic across multiple AZs. If one AZ goes down, traffic is routed to healthy targets in other AZs.
- **Scalability** -- Works with Auto Scaling to handle varying traffic loads.
- **Health checks** -- Automatically stops sending traffic to unhealthy targets.
- **SSL termination** -- Offloads encryption/decryption from your application servers.
- **Single point of access** -- Exposes a single DNS name for your application.

**Key facts about all ELB types:**
- ELBs are **managed services** -- AWS handles scaling, patching, and availability.
- ELBs are **Regional** -- they operate within a single Region but span multiple AZs.
- ELBs **scale automatically** but not instantaneously. For sudden massive traffic spikes, you can "pre-warm" by contacting AWS support.
- ELB nodes get **public IPs** (internet-facing) or **private IPs** (internal). The DNS name resolves to these IPs.

---

## Application Load Balancer (ALB)

The ALB operates at **Layer 7 (HTTP/HTTPS)** and is the best choice for most web applications.

### Key Features

| Feature | Detail |
|---|---|
| Layer | 7 (HTTP/HTTPS) |
| Target types | EC2 instances, IP addresses, Lambda functions, containers (ECS/EKS) |
| Content-based routing | Route based on URL path, host header, HTTP headers, query strings, source IP |
| WebSocket support | Native support |
| HTTP/2 | Supported |
| gRPC | Supported |
| Redirect actions | HTTP to HTTPS redirect, URL redirect |
| Fixed response | Return a custom HTTP response (e.g., maintenance page) directly from the ALB |
| Authentication | Integrates with Cognito and OIDC identity providers |

### Routing Rules

ALB uses **listeners** and **rules** to route traffic:

1. A **listener** checks for connection requests on a configured protocol and port (e.g., HTTPS:443).
2. Each listener has **rules** evaluated in priority order.
3. Each rule has **conditions** (path pattern, host header, etc.) and **actions** (forward to target group, redirect, fixed response).

**Example rules:**

```
Listener: HTTPS:443
  Rule 1 (priority 1): IF path = /api/*    THEN forward to api-target-group
  Rule 2 (priority 2): IF host = admin.*    THEN forward to admin-target-group
  Rule 3 (priority 3): IF path = /health    THEN fixed-response 200 "OK"
  Default rule:                              THEN forward to web-target-group
```

### Target Groups

A **target group** is a logical grouping of targets that receive traffic from the ALB.

- Each target group has its own health check configuration.
- Targets can be registered in multiple target groups.
- Target groups support **weighted target groups** for blue/green deployments.
- ALB can route to targets in **different AZs within the same Region**.

### Health Checks

| Setting | Default | Notes |
|---|---|---|
| Protocol | HTTP | Can be HTTP or HTTPS |
| Path | `/` | Configure to a dedicated health endpoint (e.g., `/health`) |
| Healthy threshold | 5 | Number of consecutive successes to mark healthy |
| Unhealthy threshold | 2 | Number of consecutive failures to mark unhealthy |
| Interval | 30 seconds | Time between health checks |
| Timeout | 5 seconds | Time to wait for a response |
| Success codes | 200 | Can specify a range (e.g., 200-299) |

### X-Forwarded Headers

Because the ALB terminates the client's connection and opens a new one to the target, the target sees the ALB's IP as the source. To get the original client information:

| Header | Contains |
|---|---|
| `X-Forwarded-For` | Client's original IP address |
| `X-Forwarded-Proto` | Client's original protocol (HTTP or HTTPS) |
| `X-Forwarded-Port` | Client's original port |

[TODO: Add a diagram showing traffic flow through ALB with listener rules and target groups]

---

## Network Load Balancer (NLB)

The NLB operates at **Layer 4 (TCP/UDP/TLS)** and is designed for ultra-high performance and low latency.

### Key Features

| Feature | Detail |
|---|---|
| Layer | 4 (TCP, UDP, TLS) |
| Performance | Millions of requests per second, ultra-low latency (~100 microseconds) |
| Static IP | Each NLB gets a **static IP per AZ**. You can also assign an Elastic IP. |
| Target types | EC2 instances, IP addresses, ALB (yes, NLB can front an ALB) |
| Preserve source IP | The target sees the **client's original IP** (no X-Forwarded-For needed for TCP) |
| TLS termination | Supported (TLS listener) |
| Zonal failover | Fails over to healthy AZs automatically |
| Cross-zone LB | Disabled by default (unlike ALB) |

### When to Use NLB Over ALB

| Scenario | Use |
|---|---|
| HTTP/HTTPS web application with routing rules | ALB |
| Need static IP or Elastic IP on the load balancer | NLB |
| Non-HTTP protocol (TCP, UDP, custom protocol) | NLB |
| Extreme performance (millions of RPS, sub-millisecond latency) | NLB |
| Need to front a PrivateLink endpoint service | NLB (required) |
| Gaming servers, IoT, VoIP | NLB |
| Need ALB features + static IP | NLB -> ALB (NLB in front of ALB) |

### NLB Health Checks

- NLB supports TCP, HTTP, and HTTPS health checks.
- For TCP health checks, the NLB attempts a TCP connection. If successful, the target is healthy.
- NLB health checks are more basic than ALB health checks.

[TODO: Add performance comparison benchmarks between ALB and NLB]

---

## Gateway Load Balancer (GLB)

The GLB operates at **Layer 3 (Network layer)** and is used to deploy, scale, and manage third-party virtual network appliances.

### Key Features

| Feature | Detail |
|---|---|
| Layer | 3 (IP) |
| Protocol | GENEVE (port 6081) |
| Purpose | Route traffic through network appliances (firewalls, IDS/IPS, deep packet inspection) |
| Transparency | Traffic is sent to the appliance and returned to the original path transparently |
| Target types | EC2 instances, IP addresses |

### How GLB Works

```
Internet -> IGW -> GLB Endpoint (in your VPC)
                       |
                       v
              GLB (in appliance VPC)
                       |
                       v
              Network Appliance (firewall, IDS)
                       |
                       v
              GLB (returns traffic)
                       |
                       v
              GLB Endpoint -> Your application
```

1. Traffic enters your VPC and is routed to a **GLB Endpoint** (a VPC endpoint powered by PrivateLink).
2. The GLB Endpoint sends traffic to the Gateway Load Balancer.
3. The GLB distributes traffic to registered network appliances.
4. The appliance processes the traffic (inspects, filters, etc.) and sends it back to the GLB.
5. The GLB returns the traffic through the GLB Endpoint back to the original route.

### When to Use GLB

- You need to inspect all traffic entering or leaving your VPC.
- You are deploying third-party virtual appliances (Palo Alto, Fortinet, Check Point, etc.).
- You want to centralize network appliance management.

**Exam tip:** If a question mentions third-party firewalls, IDS/IPS, or network appliances at scale, think Gateway Load Balancer.

[TODO: Add a more detailed traffic flow diagram with route table entries]

---

## Classic Load Balancer (CLB)

The CLB is the **legacy** load balancer. AWS recommends migrating to ALB or NLB.

| Feature | Detail |
|---|---|
| Layer | 4 and 7 (limited Layer 7) |
| Status | Legacy -- not recommended for new deployments |
| Target types | EC2 instances only |
| Features | Basic round-robin, TCP and HTTP health checks, sticky sessions |
| Missing features | No content-based routing, no target groups, no WebSocket, no HTTP/2 |

**Exam tip:** If the exam mentions CLB, the correct answer is usually "migrate to ALB or NLB." CLB may appear as a distractor.

---

## Cross-Zone Load Balancing

Cross-zone load balancing determines how the load balancer distributes traffic across targets in different Availability Zones.

### Without Cross-Zone Load Balancing

Each load balancer node in an AZ distributes traffic **only to targets in its own AZ**.

**Problem:** If AZ-A has 2 instances and AZ-B has 8 instances, each AZ gets 50% of traffic. The 2 instances in AZ-A each handle 25% of total traffic, while the 8 instances in AZ-B each handle only 6.25%.

```
AZ-A (50% traffic)          AZ-B (50% traffic)
  Instance 1: 25%             Instance 3: 6.25%
  Instance 2: 25%             Instance 4: 6.25%
                              Instance 5: 6.25%
                              Instance 6: 6.25%
                              Instance 7: 6.25%
                              Instance 8: 6.25%
                              Instance 9: 6.25%
                              Instance 10: 6.25%
```

### With Cross-Zone Load Balancing

Traffic is distributed evenly across **all registered targets in all AZs**.

```
AZ-A + AZ-B (all 10 instances)
  Each instance: 10% of total traffic
```

### Default Settings by ELB Type

| ELB Type | Cross-Zone LB Default | Data Transfer Charge for Cross-Zone |
|---|---|---|
| ALB | **Enabled** (always on at the target group level; can now be disabled per target group) | No charge |
| NLB | **Disabled** | Charged for inter-AZ data transfer |
| GLB | **Disabled** | Charged for inter-AZ data transfer |
| CLB | **Disabled** (can be enabled) | No charge if enabled |

**Exam tip:** Know the defaults. ALB has cross-zone enabled by default and does not charge for it. NLB has it disabled by default and charges for inter-AZ data if enabled.

[TODO: Add a visual showing the traffic distribution difference with and without cross-zone LB]

---

## Sticky Sessions (Session Affinity)

Sticky sessions ensure that a user's requests are always routed to the **same target** for the duration of the session.

### How It Works

The load balancer sets a cookie that identifies the target. Subsequent requests from the same client include this cookie, and the load balancer routes the request to the same target.

### Cookie Types

| Cookie Type | Generated By | Cookie Name | Duration |
|---|---|---|---|
| **Duration-based** (LB-generated) | Load balancer | `AWSALB` (ALB) or `AWSELB` (CLB) | Configurable (1 second to 7 days) |
| **Application-based** (custom) | Your application | You choose the name (cannot use `AWSALB*` prefix) | Set by the application |
| **Application-based** (LB-generated) | Load balancer for app-based stickiness | `AWSALBAPP` | Configurable |

### Considerations

- Sticky sessions can cause **uneven load distribution** -- if one user generates much more traffic than others, the target handling that user becomes a hotspot.
- **Best practice:** Design stateless applications that do not require sticky sessions. Store session data in ElastiCache (Redis/Memcached) or DynamoDB instead.
- Stickiness is configured at the **target group level**.

**Exam tip:** If a question says users are losing session data when routed to different instances, the options are: (1) enable sticky sessions or (2) externalize session state to ElastiCache/DynamoDB. Option 2 is almost always the better architectural answer.

[TODO: Add a comparison of session management approaches: sticky sessions vs. ElastiCache vs. DynamoDB]

---

## Connection Draining / Deregistration Delay

When a target is deregistered from a target group (e.g., during a scale-in event or deployment), existing in-flight requests need time to complete.

### How It Works

- **Deregistration delay** (ALB/NLB term) or **Connection draining** (CLB term): The load balancer stops sending **new** requests to the deregistering target but allows **existing** connections to complete.
- **Default timeout:** 300 seconds (5 minutes).
- **Range:** 0-3600 seconds.
- Setting it to **0** disables the feature (connections are terminated immediately).

### Best Practice

- Set the deregistration delay to match your application's longest request processing time.
- For short-lived requests (e.g., API calls): 30-60 seconds is usually sufficient.
- For long-lived connections (e.g., file uploads, WebSocket): Set a higher value.
- For Auto Scaling events: A lower value means instances are released faster, reducing cost.

[TODO: Show how deregistration delay interacts with Auto Scaling lifecycle hooks]

---

## SSL/TLS Termination and SNI

### SSL/TLS Termination

The load balancer can decrypt HTTPS traffic (SSL/TLS termination), reducing the encryption burden on your application servers.

- Requires an SSL/TLS certificate managed by **AWS Certificate Manager (ACM)** or uploaded as an IAM server certificate.
- The connection between the load balancer and the target can be HTTP (faster, no encryption overhead) or HTTPS (end-to-end encryption).

### Server Name Indication (SNI)

**SNI** allows a single load balancer to serve **multiple SSL certificates** for different domains.

- The client indicates which hostname it is connecting to in the TLS handshake.
- The load balancer selects the correct certificate based on the hostname.

| ELB Type | SNI Support |
|---|---|
| ALB | Yes |
| NLB | Yes |
| CLB | **No** (one certificate per CLB -- need multiple CLBs for multiple domains) |

**Exam tip:** If a question asks about hosting multiple HTTPS websites on a single load balancer, the answer is ALB or NLB with SNI. CLB does not support SNI.

[TODO: Show a practical example with two domains sharing one ALB using SNI]

---

## ELB Access Logs and Monitoring

### Access Logs

- ELB can log all requests to an **S3 bucket**.
- Logs include: timestamp, client IP, target IP, request processing time, target response time, ELB status code, target status code, request URL, user agent, SSL cipher, and more.
- Logs are stored in a compressed format.
- **Cost:** No additional charge for access logging (you pay for S3 storage).

### CloudWatch Metrics

Key metrics to monitor:

| Metric | Description |
|---|---|
| `RequestCount` | Number of requests processed |
| `HealthyHostCount` / `UnHealthyHostCount` | Number of healthy/unhealthy targets |
| `TargetResponseTime` | Time taken by the target to respond |
| `HTTPCode_ELB_5XX` | 5xx errors generated by the load balancer (e.g., no healthy targets) |
| `HTTPCode_Target_5XX` | 5xx errors generated by targets |
| `ActiveConnectionCount` | Number of active TCP connections |
| `SurgeQueueLength` (CLB) | Number of requests waiting to be routed |
| `SpilloverCount` (CLB) | Number of requests rejected because the surge queue is full |

### Request Tracing

ALB adds an `X-Amzn-Trace-Id` header to each request, which can be used for tracing requests through your application.

[TODO: Show a sample access log entry and explain each field]

---

## ELB Comparison Table

| Feature | ALB | NLB | GLB | CLB |
|---|---|---|---|---|
| Layer | 7 (HTTP/HTTPS) | 4 (TCP/UDP/TLS) | 3 (IP/GENEVE) | 4 + limited 7 |
| Use case | Web apps, microservices | Ultra-high performance, static IP, non-HTTP | Network appliances | Legacy |
| Target types | Instances, IPs, Lambda, containers | Instances, IPs, ALB | Instances, IPs | Instances |
| Static IP | No (use NLB in front) | Yes (one per AZ) | No | No |
| Content-based routing | Yes (path, host, header, etc.) | No | No | No |
| WebSocket | Yes | Yes | N/A | No |
| SNI (multiple SSL certs) | Yes | Yes | N/A | No |
| Cross-zone LB default | Enabled (free) | Disabled (charged) | Disabled (charged) | Disabled (free) |
| Preserve source IP | No (use X-Forwarded-For) | Yes | Yes | No (use X-Forwarded-For) |
| PrivateLink support | No (not as endpoint service) | Yes (required for endpoint services) | Yes (GLB endpoints) | No |
| Health checks | HTTP/HTTPS | TCP/HTTP/HTTPS | TCP/HTTP/HTTPS | TCP/HTTP |

---

## Key Takeaways for the SAA-C03 Exam

1. **ALB for HTTP/HTTPS, NLB for TCP/UDP/performance, GLB for network appliances.**
2. **ALB supports content-based routing** (path, host header, query string, etc.). NLB does not.
3. **NLB provides static IPs** per AZ. Use NLB in front of ALB if you need static IP + Layer 7 features.
4. **Cross-zone load balancing is enabled by default on ALB** and disabled by default on NLB/GLB.
5. **Sticky sessions** route the same client to the same target. Better to externalize session state.
6. **Connection draining / deregistration delay** allows in-flight requests to complete before a target is removed.
7. **SNI** enables multiple SSL certificates on one ALB or NLB. CLB does not support SNI.
8. **GLB uses GENEVE protocol** on port 6081 and is used with third-party virtual appliances.
9. **Health checks** are per target group. Unhealthy targets stop receiving traffic automatically.
10. **X-Forwarded-For header** is needed on ALB to get the client's real IP address.
11. **NLB is required for PrivateLink endpoint services.** ALB cannot serve as a PrivateLink service directly.
12. **CLB is legacy.** If it appears in an answer, look for a better option with ALB or NLB.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- ELB Overview
- Application Load Balancer (ALB)
- Network Load Balancer (NLB)
- Gateway Load Balancer (GLB)

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
