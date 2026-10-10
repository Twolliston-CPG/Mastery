# AWS Global Accelerator

## Why This Matters for the Exam

Global Accelerator vs CloudFront is one of the most common comparison questions on the SAA-C03. You must know when to use each. Expect 1-2 questions specifically about Global Accelerator, and 1-2 more comparing it to CloudFront.

---

## What Global Accelerator Does

AWS Global Accelerator is a networking service that improves the performance and availability of your applications by routing traffic through the AWS global network instead of the public internet.

**The problem it solves:** When a user in Tokyo connects to your application in us-east-1, their traffic crosses many public internet hops, each adding latency and potential packet loss. Global Accelerator routes traffic onto the AWS backbone at the nearest edge location, then carries it over the private AWS network to your origin.

```
WITHOUT Global Accelerator:
  User (Tokyo) --> Public Internet (many hops, variable latency) --> us-east-1

WITH Global Accelerator:
  User (Tokyo) --> Nearest Edge Location --> AWS Global Network (optimized) --> us-east-1
```

---

## Key Concepts

### Anycast IP Addresses

Global Accelerator provides you with **two static Anycast IPv4 addresses** (or you can bring your own IPs).

**What is Anycast?** A single IP address is advertised from multiple locations. The network automatically routes the user to the nearest location advertising that IP.

**Why this matters:**
- Your application gets a **fixed, static IP** that never changes, regardless of backend changes.
- Clients always connect to the same two IPs, simplifying DNS, firewall rules, and allowlisting.
- Traffic is automatically routed to the nearest AWS edge location.

### How Traffic Flows

```
1. Client resolves your application to the Anycast IP
2. Client's traffic enters the AWS network at the nearest edge location
3. Global Accelerator routes traffic to the optimal healthy endpoint
4. Response follows the same optimized path back

Client --> Anycast IP --> Edge Location --> AWS Backbone --> Endpoint Group --> Endpoint
```

### Listeners

A listener processes inbound connections based on the **port** and **protocol** you configure.

| Protocol Support | Ports |
|---|---|
| TCP | Any port (e.g., 80, 443, 8080) |
| UDP | Any port (e.g., 53, 5000) |

**Key point:** Global Accelerator works at Layer 4 (TCP/UDP). It does NOT inspect HTTP headers, URLs, or cookies.

### Endpoint Groups

An endpoint group is associated with a specific **AWS Region**. You can have multiple endpoint groups (one per region).

**Traffic dial:** Each endpoint group has a traffic dial (0-100%) that controls the percentage of traffic routed to that region. Useful for blue/green deployments or gradual regional shifts.

### Endpoints

Endpoints are the actual resources that receive traffic within an endpoint group:

| Endpoint Type | Example |
|---|---|
| Application Load Balancer (ALB) | ALB in us-east-1 |
| Network Load Balancer (NLB) | NLB in eu-west-1 |
| EC2 Instance | Individual EC2 instance |
| Elastic IP Address | Static IP on an EC2 instance |

Each endpoint has a **weight** (0-255) that determines how much traffic it receives relative to other endpoints in the same group.

### Health Checks

Global Accelerator continuously monitors the health of each endpoint:

- Uses health checks (TCP, HTTP, or HTTPS) to determine endpoint health.
- Automatically routes traffic away from unhealthy endpoints within seconds.
- If all endpoints in a region are unhealthy, traffic is routed to the next closest healthy region.
- Failover happens in **less than 30 seconds** (compared to DNS-based failover which depends on TTL).

**Exam tip:** If the question asks about "instant failover" or "failover faster than DNS TTL," Global Accelerator is the answer.

---

## Global Accelerator vs CloudFront -- Critical Exam Comparison

This is one of the most important comparison tables for the SAA-C03.

| Feature | CloudFront | Global Accelerator |
|---|---|---|
| **Type** | Content Delivery Network (CDN) | Network accelerator |
| **Layer** | Layer 7 (HTTP/HTTPS) | Layer 4 (TCP/UDP) |
| **Caching** | Yes (caches content at edge locations) | **No caching** (proxies all traffic to origin) |
| **Static IP** | No (uses DNS names, IPs change) | **Yes** (2 static Anycast IPs) |
| **Protocol** | HTTP, HTTPS, WebSocket | **TCP, UDP** (any protocol) |
| **Content type** | HTTP-based content (web pages, APIs, media) | **Any TCP/UDP traffic** (gaming, IoT, VoIP, non-HTTP) |
| **Edge processing** | CloudFront Functions, Lambda@Edge | No edge processing |
| **SSL termination** | At the edge | At the endpoint (pass-through) |
| **Health checks** | Origin health checks | Endpoint health checks (faster failover) |
| **Failover speed** | Depends on TTL | **< 30 seconds** |
| **DDoS protection** | AWS Shield Standard (free) | AWS Shield Standard (free) |
| **Pricing model** | Per GB data transfer + per request | Per accelerator + per GB data transfer |
| **IP allowlisting** | Not practical (IPs change) | **Easy** (2 static IPs) |

### When to Use CloudFront

- Serving **cacheable HTTP content** (static websites, images, videos, API responses).
- Need **edge-side processing** (CloudFront Functions, Lambda@Edge).
- Distributing content to users worldwide with **reduced latency through caching**.
- Serving a **static website** from S3.
- Need **signed URLs/cookies** for content access control.

### When to Use Global Accelerator

- Application uses **non-HTTP protocols** (gaming UDP, IoT MQTT over TCP, VoIP).
- Need **static IP addresses** for firewall allowlisting or DNS simplification.
- Need **instant failover** (< 30 seconds) between regions (faster than DNS TTL).
- Application is **not cacheable** (every request must reach the origin).
- Need to accelerate **TCP/UDP traffic** that CloudFront cannot handle.
- Running a **multi-region active-active** architecture that needs deterministic routing.

### Exam Decision Guide

```
Does the content need caching?
  |
  +-- Yes --> CloudFront
  +-- No  --> Continue
          |
          Is it HTTP/HTTPS traffic?
            |
            +-- No (UDP, TCP, non-HTTP) --> Global Accelerator
            +-- Yes --> Continue
                    |
                    Do you need static IPs?
                      |
                      +-- Yes --> Global Accelerator
                      +-- No  --> Continue
                              |
                              Do you need instant failover (< 30s)?
                                |
                                +-- Yes --> Global Accelerator
                                +-- No  --> CloudFront (if caching helps) or Global Accelerator
```

---

## Exam Scenarios

| Scenario | Answer | Why |
|---|---|---|
| "Serve a static website globally with low latency" | CloudFront | Cacheable HTTP content |
| "Multiplayer game server needs low-latency UDP connections" | Global Accelerator | UDP protocol, not HTTP |
| "Company needs static IPs for partner firewall allowlisting" | Global Accelerator | Static Anycast IPs |
| "Reduce latency for an API that returns unique, non-cacheable responses" | Global Accelerator | No caching benefit, TCP acceleration |
| "Serve video content to worldwide users" | CloudFront | Cacheable media, edge caching |
| "Need to failover between two regions in under a minute" | Global Accelerator | < 30 second failover |
| "Resize images at the edge before serving to users" | CloudFront | Lambda@Edge can process at edge |
| "IoT devices send telemetry over TCP from worldwide locations" | Global Accelerator | TCP acceleration, non-HTTP |
| "Restrict video access to paid subscribers using signed URLs" | CloudFront | Signed URL support |
| "Blue/green deployment across two regions with traffic dial" | Global Accelerator | Endpoint group traffic dials |

---

## Global Accelerator Architecture Example

```
                    Global Accelerator
                    Anycast IPs: 1.2.3.4, 5.6.7.8
                           |
              +------------+------------+
              |                         |
       Endpoint Group            Endpoint Group
       (us-east-1, 70%)         (eu-west-1, 30%)
              |                         |
        +-----+-----+            +-----+-----+
        |           |            |           |
       ALB         ALB          ALB         ALB
     (weight:     (weight:    (weight:    (weight:
      200)         50)         200)         50)
        |           |            |           |
    EC2 (ASG)   EC2 (ASG)   EC2 (ASG)   EC2 (ASG)
```

---

## Pricing Overview

| Component | Cost |
|---|---|
| Fixed fee | $0.025/hour per accelerator (~$18/month) |
| Data transfer | $0.015-$0.035 per GB (varies by region) |
| Dominant Traffic Flow (DT-Premium) | Charged based on AWS edge to endpoint region |

**Budget tip for labs:** Global Accelerator costs ~$0.025/hour. If you create one for a lab, tear it down within an hour to keep costs under $0.05.

---

## Key Takeaways

1. **Global Accelerator provides 2 static Anycast IPs** -- this is its defining feature for IP allowlisting scenarios.
2. **No caching.** Global Accelerator is a network proxy, not a CDN. Every request reaches the origin.
3. **TCP and UDP support** -- this is the key differentiator from CloudFront (HTTP/HTTPS only).
4. **< 30 second failover** -- faster than DNS-based failover (which depends on TTL propagation).
5. **CloudFront for cacheable HTTP content; Global Accelerator for non-cacheable, non-HTTP, or static-IP requirements.**
6. **Traffic dials on endpoint groups** enable gradual regional traffic shifts (useful for blue/green).

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- What Global Accelerator Does
- Key Concepts
- Global Accelerator vs CloudFront -- Critical Exam Comparison
- Exam Scenarios

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
