# Hybrid Connectivity

## Why This Matters for the Exam

Hybrid connectivity (connecting on-premises networks to AWS) is tested heavily on the SAA-C03. Expect 3-5 questions on VPN, Direct Connect, Transit Gateway, and edge services. The exam loves "which connectivity option" scenario questions, so you must know the trade-offs.

---

## Connectivity Options Overview

| Option | Bandwidth | Latency | Encryption | Setup Time | Cost | Use Case |
|---|---|---|---|---|---|---|
| **Site-to-Site VPN** | Up to 1.25 Gbps per tunnel | Variable (over internet) | IPsec encrypted | Minutes-hours | $ | Quick setup, encrypted, budget-friendly |
| **Direct Connect** | 1 Gbps, 10 Gbps, 100 Gbps | Consistent, low | Not encrypted by default | Weeks-months | $$$$ | High bandwidth, consistent latency |
| **Direct Connect + VPN** | 1-10 Gbps | Consistent, low | IPsec over DX | Weeks-months | $$$$$ | Encrypted + consistent performance |
| **Transit Gateway** | Aggregate of attached connections | Varies | Supports VPN encryption | Hours-days | $$ | Hub-and-spoke, multiple VPCs |
| **VPN CloudHub** | Up to 1.25 Gbps per site | Variable | IPsec encrypted | Hours | $$ | Multiple branch offices |

---

## Site-to-Site VPN (Review from Phase 1)

Creates an encrypted IPsec tunnel over the public internet between your on-premises network and an AWS VPC.

**Components:**
- **Virtual Private Gateway (VGW):** AWS side of the VPN connection, attached to a VPC.
- **Customer Gateway (CGW):** On-premises side (your router/firewall).
- **VPN Connection:** Two IPsec tunnels (for redundancy) between VGW and CGW.

**Key characteristics:**
- Encrypted by default (IPsec).
- Quick to set up (minutes to hours).
- Bandwidth limited to ~1.25 Gbps per tunnel.
- Latency is variable (goes over the public internet).
- Supports BGP (dynamic routing) or static routing.

---

## AWS Direct Connect (DX)

A dedicated, private network connection from your on-premises data center to AWS. Traffic does NOT go over the public internet.

### Connection Types

| Type | Bandwidth | Port Speed | Lead Time |
|---|---|---|---|
| **Dedicated Connection** | 1 Gbps, 10 Gbps, 100 Gbps | Physical port at DX location | 2-4 weeks (often longer) |
| **Hosted Connection** | 50 Mbps to 10 Gbps | Provided by AWS Partner | Days-weeks (via partner) |

### Virtual Interfaces (VIFs)

| VIF Type | Purpose | What It Connects To |
|---|---|---|
| **Private VIF** | Access VPC resources using private IPs | Virtual Private Gateway (VGW) |
| **Public VIF** | Access AWS public services (S3, DynamoDB, etc.) | AWS public endpoints |
| **Transit VIF** | Access VPCs through Transit Gateway | Transit Gateway |

### Direct Connect Gateway

**Problem:** A standard Direct Connect connection with a Private VIF connects to one VGW, which connects to one VPC in one region. What if you have VPCs in multiple regions?

**Solution:** Direct Connect Gateway allows a single Direct Connect connection to access VPCs in multiple AWS regions.

```
On-Premises Data Center
         |
    Direct Connect
         |
  Direct Connect Gateway
    /        |        \
   VGW       VGW       VGW
  (VPC       (VPC      (VPC
  us-east-1) eu-west-1) ap-southeast-1)
```

**Key characteristics:**
- Global resource (not region-specific).
- Connects to VGWs or Transit Gateways in any region.
- Does NOT enable VPC-to-VPC communication (only on-premises to VPC).
- For VPC-to-VPC communication, use Transit Gateway or VPC Peering.

### Direct Connect -- Encryption

**Direct Connect is NOT encrypted by default.** Data travels over a dedicated physical link but in cleartext.

**To encrypt Direct Connect traffic:**
- Set up a Site-to-Site VPN connection over the Direct Connect link.
- This gives you the bandwidth/consistency of DX with the encryption of VPN.
- Use a Transit VIF with Transit Gateway for VPN support.

### Direct Connect -- High Availability

For production workloads, AWS recommends redundant DX connections:

```
Resilience Level: Maximum (Recommended for critical workloads)

On-Premises --- DX Connection 1 --> DX Location A --> AWS
On-Premises --- DX Connection 2 --> DX Location B --> AWS
                (separate locations for device/location fault tolerance)
```

**Common pattern: DX + VPN backup.**

```
Primary:  On-Premises ---[Direct Connect]--> VPC  (high bandwidth, low latency)
Backup:   On-Premises ---[Site-to-Site VPN]--> VPC  (encrypted, over internet)

Route preference: DX is preferred via BGP. If DX fails, traffic fails over to VPN.
```

**Exam tip:** If the question says "high bandwidth, consistent latency with encrypted backup," the answer is Direct Connect with VPN as backup.

---

## AWS Transit Gateway (TGW)

Transit Gateway is a regional network hub that connects VPCs, VPN connections, and Direct Connect through a single gateway.

### The Problem It Solves

Without Transit Gateway, connecting N VPCs requires N*(N-1)/2 peering connections (full mesh). With 10 VPCs, that is 45 peering connections. This is unmanageable.

### Hub-and-Spoke Architecture

```
                    Transit Gateway
                   (Central Hub)
                  /    |    |    \
                 /     |    |     \
              VPC-A  VPC-B VPC-C  VPC-D
                              |
                          On-Premises
                          (via VPN or DX)
```

**All VPCs route traffic through Transit Gateway.** Any VPC can communicate with any other VPC (if route tables allow).

### Key Features

| Feature | Detail |
|---|---|
| **VPC Attachment** | Attach VPCs to TGW (each VPC uses a TGW ENI in a subnet) |
| **VPN Attachment** | Attach Site-to-Site VPN connections |
| **DX Attachment** | Attach Direct Connect via Transit VIF |
| **Peering** | Peer Transit Gateways across regions (inter-region) |
| **Route Tables** | TGW has its own route tables; control which attachments can communicate |
| **Multicast** | Supports IP multicast across VPCs |
| **ECMP** | Equal-Cost Multi-Path routing for VPN (aggregate bandwidth) |
| **Sharing** | Share TGW across accounts via AWS RAM |

### Transit Gateway Route Tables

You can create multiple route tables on a Transit Gateway to implement network segmentation:

```
Example: Isolate production from development

TGW Route Table: "Production"
  - Routes to VPC-Prod-A, VPC-Prod-B, On-Premises
  - NO routes to Dev VPCs

TGW Route Table: "Development"
  - Routes to VPC-Dev-A, VPC-Dev-B
  - NO routes to Prod VPCs or On-Premises
```

### ECMP (Equal-Cost Multi-Path)

**Problem:** A single VPN tunnel maxes out at ~1.25 Gbps. What if you need more VPN bandwidth?

**Solution:** With Transit Gateway, you can create multiple VPN connections, and ECMP distributes traffic across them.

- 2 VPN connections = ~2.5 Gbps aggregate.
- 4 VPN connections = ~5 Gbps aggregate.
- Each VPN connection has 2 tunnels, so 4 connections = 8 tunnels.

**Exam tip:** If the question asks "increase VPN bandwidth beyond 1.25 Gbps," the answer is Transit Gateway with ECMP.

---

## AWS Outposts

**What it is:** AWS infrastructure (compute, storage, databases) physically installed in your on-premises data center or colocation facility.

**Key characteristics:**
- Fully managed by AWS (AWS is responsible for maintenance, updates, patching).
- Runs the same AWS APIs, tools, and services as the AWS cloud.
- Connected to the nearest AWS region via a private link.
- Available services: EC2, EBS, S3 on Outposts, RDS, ECS, EKS, ALB, and more.

### When to Use Outposts

| Scenario | Why Outposts |
|---|---|
| Data residency requirements (data must stay on-premises) | Data never leaves your facility |
| Ultra-low latency to on-premises systems | Same physical location |
| Local data processing before sending to AWS | Process locally, send results to cloud |
| Migration stepping stone | Run AWS on-premises while migrating |

**Exam tip:** If the question says "run AWS services on-premises" or "data must remain in the customer's data center due to regulations," the answer is Outposts.

---

## AWS Wavelength

**What it is:** AWS infrastructure deployed within 5G carrier networks (e.g., Verizon, Vodafone). It places compute and storage at the edge of 5G networks for ultra-low latency to mobile and connected devices.

**Key characteristics:**
- Wavelength Zones are extensions of AWS Regions into carrier networks.
- Supports EC2, EBS, ECS, EKS, and more.
- Traffic from 5G devices to Wavelength never leaves the carrier network (no internet hops).

### When to Use Wavelength

| Scenario | Why Wavelength |
|---|---|
| Real-time gaming for mobile users | Single-digit millisecond latency from 5G device |
| Connected vehicles / autonomous driving | Ultra-low latency edge processing |
| AR/VR applications on mobile | Cannot tolerate internet round-trip |
| Live video streaming from mobile | Edge processing before delivery |

**Exam tip:** If the question mentions "5G," "mobile edge," or "single-digit millisecond latency from mobile devices," the answer is Wavelength.

---

## AWS Local Zones

**What it is:** Extensions of AWS Regions that place compute, storage, database, and other services closer to end users in specific metro areas. Like a mini-region in a city.

**Key characteristics:**
- Provides single-digit millisecond latency to users in the metro area.
- Parent region provides full set of AWS services; Local Zone provides a subset (EC2, EBS, ELB, etc.).
- Connected to the parent region via AWS private network.
- Examples: Los Angeles, Boston, Houston, Miami.

### When to Use Local Zones

| Scenario | Why Local Zones |
|---|---|
| Real-time video editing/rendering in a specific city | Low latency to local studios |
| Gaming servers for a metro area | Low latency to local players |
| Healthcare applications with latency requirements | Local processing |

**Exam tip:** If the question mentions "specific city" or "metro area latency" (not 5G-specific), the answer is Local Zones. If it mentions 5G mobile, the answer is Wavelength.

---

## Connectivity Decision Tree

```
Start: What is the connectivity need?
  |
  +--> Connect on-premises to ONE VPC?
  |      |
  |      +--> Need high bandwidth + consistent latency?
  |      |      |
  |      |      +-- Yes --> Direct Connect (with VPN backup for encryption)
  |      |      +-- No  --> Site-to-Site VPN (quick, encrypted, cheaper)
  |      |
  +--> Connect on-premises to MULTIPLE VPCs?
  |      |
  |      +--> Same region?
  |      |      |
  |      |      +-- Yes --> Transit Gateway + VPN or DX
  |      |
  |      +--> Multiple regions?
  |             |
  |             +-- Yes --> Direct Connect Gateway + Transit Gateway (inter-region peering)
  |
  +--> Connect MULTIPLE VPCs to each other?
  |      |
  |      +--> Few VPCs (2-3)?
  |      |      |
  |      |      +-- Yes --> VPC Peering (simple, no hub)
  |      |
  |      +--> Many VPCs (10+)?
  |             |
  |             +-- Yes --> Transit Gateway (hub-and-spoke)
  |
  +--> Need AWS services ON-PREMISES?
  |      |
  |      +-- Yes --> AWS Outposts
  |
  +--> Need ultra-low latency for 5G MOBILE devices?
  |      |
  |      +-- Yes --> AWS Wavelength
  |
  +--> Need low latency for a SPECIFIC METRO area?
         |
         +-- Yes --> AWS Local Zones
```

---

## Comparison: Outposts vs Wavelength vs Local Zones

| Feature | Outposts | Wavelength | Local Zones |
|---|---|---|---|
| **Where** | Your data center | Carrier 5G network | AWS facility in a metro area |
| **Managed by** | AWS (installed at your site) | AWS (in carrier network) | AWS |
| **Latency target** | Ultra-low to on-prem systems | Single-digit ms to 5G devices | Single-digit ms to metro users |
| **Connectivity** | Private link to parent region | Carrier network to parent region | AWS network to parent region |
| **Primary use case** | Data residency, hybrid | 5G edge compute | Metro-area latency |
| **Who owns the hardware?** | AWS (but in your building) | AWS (in carrier building) | AWS (in AWS building) |

---

## Exam Scenarios

| Scenario | Answer |
|---|---|
| "Connect on-premises to AWS with encrypted, low-cost connection" | Site-to-Site VPN |
| "Need 10 Gbps consistent bandwidth to AWS" | Direct Connect (dedicated) |
| "Encrypt traffic over Direct Connect" | VPN over Direct Connect |
| "Connect on-premises to 15 VPCs across 3 regions" | Direct Connect Gateway + Transit Gateway |
| "Connect 20 VPCs in the same region to each other and on-premises" | Transit Gateway |
| "Need more than 1.25 Gbps over VPN" | Transit Gateway with ECMP |
| "Run AWS compute in our data center due to data regulations" | Outposts |
| "Ultra-low latency for 5G mobile gaming" | Wavelength |
| "Low latency for users in Los Angeles metro area" | Local Zones |
| "Direct Connect with automatic failover to VPN if DX fails" | DX primary + VPN backup with BGP |

---

## Key Takeaways

1. **VPN = quick, encrypted, over internet, ~1.25 Gbps. DX = slow to set up, fast, consistent, not encrypted by default.**
2. **Transit Gateway is the hub-and-spoke solution** for connecting many VPCs and on-premises networks. It replaces complex VPC peering meshes.
3. **Direct Connect Gateway** enables one DX connection to reach VPCs in multiple regions.
4. **ECMP on Transit Gateway** aggregates VPN bandwidth beyond 1.25 Gbps.
5. **Outposts = AWS on-premises. Wavelength = 5G edge. Local Zones = metro area.**
6. **DX + VPN backup** is the gold standard for production hybrid connectivity (best performance with encrypted fallback).

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Connectivity Options Overview
- Site-to-Site VPN (Review from Phase 1)
- AWS Direct Connect (DX)
- AWS Transit Gateway (TGW)

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
