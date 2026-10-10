# 03 -- VPC Networking

## Table of Contents
1. [VPC Overview](#vpc-overview)
2. [CIDR and IP Addressing](#cidr-and-ip-addressing)
3. [Subnets](#subnets)
4. [Route Tables](#route-tables)
5. [Internet Gateway (IGW)](#internet-gateway-igw)
6. [NAT Gateway and NAT Instance](#nat-gateway-and-nat-instance)
7. [Security Groups](#security-groups)
8. [Network ACLs (NACLs)](#network-acls-nacls)
9. [Security Groups vs. NACLs -- Comparison](#security-groups-vs-nacls----comparison)
10. [Elastic Network Interfaces (ENIs)](#elastic-network-interfaces-enis)
11. [Elastic IP Addresses](#elastic-ip-addresses)
12. [VPC Peering](#vpc-peering)
13. [Transit Gateway](#transit-gateway)
14. [VPC Endpoints](#vpc-endpoints)
15. [AWS PrivateLink](#aws-privatelink)
16. [VPC Flow Logs](#vpc-flow-logs)
17. [Key Takeaways for the SAA-C03 Exam](#key-takeaways-for-the-saa-c03-exam)

---

## VPC Overview

A **Virtual Private Cloud (VPC)** is a logically isolated virtual network in AWS that you define. It is scoped to a single Region but spans all Availability Zones in that Region.

**Key characteristics:**
- **Region-scoped** -- A VPC lives in one Region. To have resources in multiple Regions, you need multiple VPCs.
- **Tenancy** -- Default (shared hardware) or Dedicated (single-tenant hardware, much more expensive).
- **Default VPC** -- Every Region comes with a default VPC (CIDR `172.31.0.0/16`) with a public subnet in each AZ. Useful for quick tests, but production workloads should use custom VPCs.
- **Custom VPC** -- You define the CIDR block, subnets, route tables, gateways, and security rules.

**What is free in a VPC:**
- VPC itself, subnets, route tables, security groups, NACLs, internet gateway, VPC peering (no charge for the peering connection itself but data transfer charges apply).

**What costs money:**
- NAT Gateway (~$0.045/hour + data processing), VPN Gateway, Transit Gateway, Elastic IPs (if not associated with a running instance), data transfer.

---

## CIDR and IP Addressing

CIDR (Classless Inter-Domain Routing) notation defines the IP address range for your VPC and subnets.

### CIDR Notation Basics

A CIDR block looks like `10.0.0.0/16`:
- `10.0.0.0` is the base IP address.
- `/16` is the subnet mask, meaning the first 16 bits are fixed and the remaining 16 bits are available for hosts.

### CIDR Block Sizes for VPCs

| CIDR | Total IPs | Usable IPs | Notes |
|---|---|---|---|
| `/16` | 65,536 | 65,531 | Maximum VPC size. Recommended for most production VPCs. |
| `/20` | 4,096 | 4,091 | Good for medium VPCs |
| `/24` | 256 | 251 | Good for small VPCs or individual subnets |
| `/28` | 16 | 11 | Minimum VPC size allowed by AWS |

### AWS-Reserved IPs in Each Subnet

AWS reserves **5 IP addresses** in every subnet:

| Address | Reserved For |
|---|---|
| First IP (e.g., 10.0.1.0) | Network address |
| Second IP (e.g., 10.0.1.1) | VPC router |
| Third IP (e.g., 10.0.1.2) | DNS server |
| Fourth IP (e.g., 10.0.1.3) | Reserved for future use |
| Last IP (e.g., 10.0.1.255) | Broadcast address (AWS does not support broadcast but reserves it) |

So a `/24` subnet (256 IPs) has only **251 usable IPs**.

### CIDR Planning Best Practice

```
VPC:      10.0.0.0/16   (65,536 IPs -- plenty of room)

Public subnets:
  AZ-a:   10.0.1.0/24   (251 usable IPs)
  AZ-b:   10.0.2.0/24
  AZ-c:   10.0.3.0/24

Private subnets (applications):
  AZ-a:   10.0.11.0/24
  AZ-b:   10.0.12.0/24
  AZ-c:   10.0.13.0/24

Private subnets (databases):
  AZ-a:   10.0.21.0/24
  AZ-b:   10.0.22.0/24
  AZ-c:   10.0.23.0/24
```

**Exam tip:** Make sure VPC CIDR blocks do not overlap if you plan to peer VPCs or connect them via Transit Gateway.

[TODO: Add a visual diagram of this subnet layout across 3 AZs]
[TODO: Add a quick-reference CIDR cheat table for /16 through /28]

---

## Subnets

A **subnet** is a range of IP addresses within a VPC. Each subnet exists in exactly **one Availability Zone** and cannot span AZs.

### Public vs. Private Subnets

There is no intrinsic "public" or "private" setting on a subnet. The distinction comes from the **route table**:

| Subnet Type | Route Table Has | Instances Need |
|---|---|---|
| **Public** | A route to an Internet Gateway (0.0.0.0/0 -> IGW) | A public IP or Elastic IP |
| **Private** | No route to IGW. May have a route to a NAT Gateway. | No public IP needed |

### Auto-Assign Public IP

When you create a subnet, you can enable "Auto-assign public IPv4 address." This means every EC2 instance launched in that subnet automatically gets a public IP. This is typically enabled for public subnets only.

**Exam tip:** If an instance in a public subnet cannot reach the internet, check:
1. Does the subnet's route table have a route to the IGW?
2. Does the instance have a public IP or Elastic IP?
3. Does the Security Group allow outbound traffic?
4. Does the NACL allow the traffic?

[TODO: Add troubleshooting flowchart for "My EC2 instance can't reach the internet"]

---

## Route Tables

A **route table** contains rules (routes) that determine where network traffic is directed. Every subnet is associated with exactly one route table.

### Key Concepts

- **Main route table** -- The default route table created with the VPC. Any subnet not explicitly associated with a custom route table uses the main route table.
- **Custom route table** -- Best practice is to create custom route tables and explicitly associate subnets. Leave the main route table with no internet route as a safety net.
- **Local route** -- Every route table automatically has a `local` route for the VPC's CIDR block. This route cannot be deleted and enables intra-VPC communication.

### Example Route Tables

**Public subnet route table:**
| Destination | Target | Notes |
|---|---|---|
| 10.0.0.0/16 | local | Intra-VPC traffic |
| 0.0.0.0/0 | igw-xxxxxxxx | All internet-bound traffic goes to the IGW |

**Private subnet route table:**
| Destination | Target | Notes |
|---|---|---|
| 10.0.0.0/16 | local | Intra-VPC traffic |
| 0.0.0.0/0 | nat-xxxxxxxx | All internet-bound traffic goes to the NAT Gateway |

**Isolated subnet route table (database tier):**
| Destination | Target | Notes |
|---|---|---|
| 10.0.0.0/16 | local | Intra-VPC traffic only. No internet access at all. |

[TODO: Explain the most-specific-route-wins rule with examples]

---

## Internet Gateway (IGW)

An **Internet Gateway** is a horizontally scaled, redundant, highly available VPC component that allows communication between your VPC and the internet.

**Key facts:**
- **One IGW per VPC.** You cannot attach multiple IGWs to a single VPC.
- **No bandwidth constraints.** AWS manages the capacity.
- **Performs NAT** for instances with public IPs (translates between private and public IPs).
- **Must be attached to the VPC** and referenced in a route table for it to work.
- An IGW alone is not enough -- instances also need a public IP address.

### Egress-Only Internet Gateway

An **Egress-Only IGW** is used for **IPv6 only**. It allows outbound IPv6 traffic to the internet but blocks inbound connections. This is the IPv6 equivalent of a NAT Gateway.

[TODO: Add a comparison table of IGW vs. Egress-Only IGW vs. NAT Gateway]

---

## NAT Gateway and NAT Instance

NAT (Network Address Translation) allows instances in a **private subnet** to initiate outbound connections to the internet (e.g., for software updates) while preventing unsolicited inbound connections.

### NAT Gateway (Recommended)

| Feature | Detail |
|---|---|
| Managed by | AWS (fully managed, highly available within one AZ) |
| Bandwidth | Up to 100 Gbps (scales automatically) |
| Availability | Deploy one per AZ for multi-AZ HA. If the AZ with your NAT GW goes down, private subnets in other AZs lose internet access. |
| Elastic IP | Required. Each NAT GW needs one. |
| Placement | Must be in a **public subnet** (it needs internet access via the IGW). |
| Cost | ~$0.045/hour + $0.045/GB data processed. This adds up -- tear down after labs! |
| Security Groups | **Cannot** attach SGs to a NAT Gateway. |

### NAT Instance (Legacy)

A NAT instance is an EC2 instance configured to perform NAT. It is **not recommended** for new deployments but may appear on the exam as a cost comparison.

| Feature | NAT Gateway | NAT Instance |
|---|---|---|
| Availability | HA within AZ (deploy per AZ) | Single instance (must script failover) |
| Bandwidth | Up to 100 Gbps | Depends on instance type |
| Maintenance | AWS managed | You manage (patching, monitoring) |
| Cost | Higher (managed service) | Lower (just EC2 cost) |
| Security Groups | No | Yes |
| Source/dest check | N/A | Must disable |
| Bastion host | No | Can double as bastion |

**Exam tip:** The exam loves to ask about NAT Gateway placement. Remember: NAT GW goes in the **public** subnet, and private subnet route tables point `0.0.0.0/0` to the NAT GW.

[TODO: Add a step-by-step traffic flow diagram showing a private instance reaching the internet via NAT GW]

---

## Security Groups

A **Security Group** acts as a virtual firewall at the **instance level** (technically at the Elastic Network Interface level).

### Key Characteristics

- **Stateful** -- If you allow inbound traffic, the return traffic is automatically allowed (and vice versa). You do not need to create a separate outbound rule for response traffic.
- **Allow rules only** -- You can only specify ALLOW rules. There are no DENY rules. If traffic is not explicitly allowed, it is implicitly denied.
- **Default behavior:**
  - Default SG: Allows all inbound from instances with the same SG. Allows all outbound.
  - Custom SG: Denies all inbound. Allows all outbound.
- **Can reference other Security Groups** as sources/destinations. This is powerful for designing tier-based access (e.g., "Allow traffic from the ALB Security Group").
- **Applied at the ENI level.** An instance can have up to 5 security groups.
- **Evaluated as a union** -- All rules across all attached SGs are combined. If any rule allows the traffic, it is allowed.
- **Changes take effect immediately.**

### Example: Web Application Security Groups

```
SG: alb-sg
  Inbound:  TCP 80 from 0.0.0.0/0
            TCP 443 from 0.0.0.0/0
  Outbound: All traffic

SG: app-sg
  Inbound:  TCP 8080 from alb-sg    <-- reference SG, not CIDR
  Outbound: All traffic

SG: db-sg
  Inbound:  TCP 3306 from app-sg    <-- only app tier can reach DB
  Outbound: All traffic
```

[TODO: Explain why referencing SGs is better than referencing CIDR blocks for multi-tier architectures]

---

## Network ACLs (NACLs)

A **Network ACL** is a firewall at the **subnet level**. Every subnet is associated with exactly one NACL.

### Key Characteristics

- **Stateless** -- Inbound and outbound rules are evaluated independently. If you allow inbound HTTP on port 80, you must also allow the outbound response on **ephemeral ports** (1024-65535).
- **Allow AND Deny rules** -- Unlike Security Groups, NACLs support both.
- **Rules are evaluated in order** (by rule number, lowest first). The first matching rule is applied and evaluation stops.
- **Default NACL** -- Allows all inbound and outbound traffic. Attached to subnets by default.
- **Custom NACL** -- Denies all inbound and outbound traffic by default. You must add rules.
- **One NACL per subnet** (but one NACL can be associated with multiple subnets).

### Example NACL Rules

**Inbound rules:**
| Rule # | Type | Port Range | Source | Allow/Deny |
|---|---|---|---|---|
| 100 | HTTP | 80 | 0.0.0.0/0 | ALLOW |
| 110 | HTTPS | 443 | 0.0.0.0/0 | ALLOW |
| 120 | SSH | 22 | 203.0.113.0/24 | ALLOW |
| * | All traffic | All | 0.0.0.0/0 | DENY |

**Outbound rules:**
| Rule # | Type | Port Range | Destination | Allow/Deny |
|---|---|---|---|---|
| 100 | Custom TCP | 1024-65535 | 0.0.0.0/0 | ALLOW |
| 110 | HTTP | 80 | 0.0.0.0/0 | ALLOW |
| 120 | HTTPS | 443 | 0.0.0.0/0 | ALLOW |
| * | All traffic | All | 0.0.0.0/0 | DENY |

**Exam tip:** Ephemeral ports (1024-65535) are the number one reason NACL configurations fail on the exam. Always allow them in the outbound direction for inbound traffic to work, and in the inbound direction for outbound traffic to work.

[TODO: Add a flow diagram showing packet flow through NACL rules with rule number evaluation]

---

## Security Groups vs. NACLs -- Comparison

| Feature | Security Group | Network ACL |
|---|---|---|
| Level | Instance (ENI) | Subnet |
| Stateful/Stateless | **Stateful** | **Stateless** |
| Rule types | Allow only | Allow and Deny |
| Rule evaluation | All rules evaluated (union) | Rules evaluated in order (first match) |
| Default behavior | Denies all inbound, allows all outbound | Allows all inbound and outbound (default NACL) |
| Applies to | Only instances assigned to it | All instances in the associated subnet |
| Return traffic | Automatically allowed | Must be explicitly allowed (ephemeral ports) |
| Use case | Primary security mechanism for instances | Additional layer of defense at the subnet level |

**When to use each:**
- **Security Groups** -- Use as your primary firewall. They are easier to manage because they are stateful.
- **NACLs** -- Use as a secondary defense layer. Useful for blocking specific IP ranges (e.g., known malicious IPs) because NACLs support deny rules.

---

## Elastic Network Interfaces (ENIs)

An **ENI** is a virtual network card attached to an instance. Every instance has a primary ENI that cannot be detached.

Key facts:
- You can attach multiple ENIs to an instance (for dual-homed setups).
- ENIs are bound to a specific AZ.
- Attributes: private IP, public IP, Elastic IP, MAC address, Security Groups, source/destination check flag.
- **Use case:** Attach a secondary ENI for management traffic, or move an ENI between instances for failover.

[TODO: Expand on ENI use cases for the exam -- management networks, licensing tied to MAC addresses]

---

## Elastic IP Addresses

An **Elastic IP (EIP)** is a static, public IPv4 address that you can associate with an instance or ENI.

Key facts:
- You own the EIP until you release it.
- **Free when associated** with a running instance. **Charged (~$0.005/hour) when not associated** or associated with a stopped instance.
- Limit: 5 EIPs per Region per account (soft limit, can request increase).
- **Best practice:** Avoid EIPs when possible. Use DNS names (Route 53) or load balancers instead.

[TODO: Explain the anti-pattern of relying on EIPs and why DNS/LB is preferred]

---

## VPC Peering

VPC Peering creates a **one-to-one networking connection** between two VPCs, enabling instances in either VPC to communicate as if they were on the same network.

### Key Facts

- Works **across accounts** and **across Regions** (inter-Region peering).
- **CIDR blocks must not overlap.** Peering will be rejected if CIDRs overlap.
- **Not transitive.** If VPC A is peered with VPC B, and VPC B is peered with VPC C, VPC A cannot communicate with VPC C through VPC B. You must create a separate peering connection between A and C.
- **Route table entries required.** You must add routes in both VPCs pointing the peer's CIDR to the peering connection.
- **Security Groups can reference peered VPC Security Groups** (same Region only).
- **No single point of failure or bandwidth bottleneck.** Peering uses the AWS backbone network.

### When VPC Peering Becomes Unwieldy

With N VPCs, you need `N*(N-1)/2` peering connections for full mesh. At 5 VPCs, that is 10 connections. At 10 VPCs, 45 connections. This is when **Transit Gateway** becomes the better choice.

[TODO: Diagram showing mesh peering vs. hub-and-spoke with Transit Gateway]

---

## Transit Gateway

**AWS Transit Gateway** is a regional network hub that connects VPCs and on-premises networks through a central gateway.

### Key Facts

- **Hub-and-spoke model** -- Simplifies complex network topologies. All VPCs and VPNs connect to the Transit Gateway.
- **Transitive routing** -- Unlike VPC Peering, routing through a Transit Gateway IS transitive. If VPC A and VPC C both connect to the same TGW, they can communicate.
- **Supports multiple route tables** -- Allows network segmentation (e.g., production VPCs cannot route to development VPCs).
- **Cross-Region peering** -- Transit Gateways in different Regions can be peered.
- **Supports VPN and Direct Connect** attachments.
- **Scales to thousands of VPCs.**
- **Cost:** ~$0.05/hour per attachment + data processing charges.

### Transit Gateway vs. VPC Peering

| Feature | VPC Peering | Transit Gateway |
|---|---|---|
| Topology | Point-to-point | Hub-and-spoke |
| Transitive routing | No | Yes |
| Scale | Manageable up to ~10 VPCs | Thousands of VPCs |
| Cost | Data transfer only | Hourly per attachment + data |
| Cross-Region | Yes (with peering) | Yes (with peering) |
| Route tables | One per VPC peering direction | Multiple (segmentation) |
| Bandwidth | No limit (AWS backbone) | Up to 50 Gbps per VPC attachment |

[TODO: Add a decision tree: "Should I use VPC Peering or Transit Gateway?"]

---

## VPC Endpoints

VPC Endpoints allow you to privately connect your VPC to supported AWS services **without** traversing the internet, NAT Gateway, or VPN. Traffic stays on the AWS network.

### Types of VPC Endpoints

| Type | How It Works | Supported Services | Cost |
|---|---|---|---|
| **Gateway Endpoint** | Entry in the route table pointing to the endpoint. No ENI needed. | **S3** and **DynamoDB** only | **Free** |
| **Interface Endpoint** (powered by PrivateLink) | Creates an ENI with a private IP in your subnet. | Most AWS services (150+) | ~$0.01/hour + data processing |

### Gateway Endpoints (S3 and DynamoDB)

- Created at the VPC level.
- You specify which route tables should have the route added.
- The route table gets a prefix list entry (e.g., `pl-xxxxxxxx`) pointing to the endpoint.
- **Free to use.**
- **Cannot be extended out of the VPC** -- only accessible from within the VPC (not over VPN or peering).

### Interface Endpoints

- Created at the subnet level (you choose which subnets).
- An ENI is created in the subnet with a private IP.
- DNS resolution can be configured so that the default AWS service DNS name resolves to the private IP.
- **Can be accessed from on-premises** over VPN or Direct Connect.
- **Can be accessed from peered VPCs** (with proper DNS configuration).

**Exam tip:** The exam loves to ask: "How can an EC2 instance in a private subnet (no NAT Gateway) access S3?" Answer: Use a **Gateway Endpoint** for S3 (free, no NAT GW cost).

[TODO: Add a decision matrix for choosing Gateway vs. Interface endpoints]

---

## AWS PrivateLink

**AWS PrivateLink** provides private connectivity between VPCs, supported AWS services, and on-premises networks without exposing traffic to the public internet.

### Key Concepts

- PrivateLink is the **technology behind Interface Endpoints**.
- You can also use PrivateLink to expose your own services to other VPCs or accounts:
  - **Service provider** creates a Network Load Balancer (NLB) and a VPC Endpoint Service.
  - **Service consumer** creates an Interface Endpoint in their VPC pointing to the service.
  - Traffic flows over the AWS network -- no VPC Peering, no Transit Gateway, no public internet.

### PrivateLink vs. VPC Peering

| Feature | PrivateLink | VPC Peering |
|---|---|---|
| Connectivity | Specific service/port | Full network connectivity |
| CIDR overlap | Allowed (uses ENIs, not routing) | Not allowed |
| Directionality | Unidirectional (consumer to provider) | Bidirectional |
| Scale | Thousands of consumers | Point-to-point |
| Use case | Exposing a service securely | General VPC-to-VPC connectivity |

**Exam tip:** If a question describes a SaaS provider wanting to securely expose a service to many customer VPCs without CIDR overlap concerns, the answer is PrivateLink.

[TODO: Add a diagram showing PrivateLink architecture: Consumer VPC -> Interface Endpoint -> Endpoint Service -> NLB -> Application]

---

## VPC Flow Logs

VPC Flow Logs capture information about the IP traffic going to and from network interfaces in your VPC.

### Where to Enable Flow Logs

| Level | What It Captures |
|---|---|
| VPC | All ENIs in the VPC |
| Subnet | All ENIs in the subnet |
| ENI | Traffic for a specific network interface |

### Where to Send Flow Logs

- Amazon CloudWatch Logs
- Amazon S3
- Amazon Data Firehose (formerly Kinesis Data Firehose)

### What Flow Logs Capture

A flow log record includes:
- Source and destination IP addresses
- Source and destination ports
- Protocol
- Number of packets and bytes
- Start and end timestamps
- Action (ACCEPT or REJECT)
- Log status

### What Flow Logs Do NOT Capture

- DNS queries to the Amazon-provided DNS server (queries to custom DNS servers are logged)
- DHCP traffic
- Traffic to the instance metadata service (169.254.169.254)
- Amazon Time Sync Service traffic
- Traffic to/from the VPC router
- Traffic to/from the reserved IP in each subnet

**Exam tip:** Flow Logs are the answer when a question asks about monitoring or troubleshooting network traffic. They tell you what traffic was accepted or rejected, which is invaluable for debugging Security Group and NACL rules.

[TODO: Show a sample flow log record and explain each field]

---

## Key Takeaways for the SAA-C03 Exam

1. **VPC is Region-scoped; subnets are AZ-scoped.**
2. **Public subnet = route to IGW + public IP. Private subnet = no route to IGW.**
3. **NAT Gateway goes in the public subnet.** Private subnet route tables point `0.0.0.0/0` to the NAT GW.
4. **Security Groups are stateful; NACLs are stateless.** Know the difference cold.
5. **NACLs require ephemeral port rules** because they are stateless.
6. **VPC Peering is not transitive.** Transit Gateway supports transitive routing.
7. **Gateway Endpoints are free** and support S3 and DynamoDB. Use them to avoid NAT GW costs.
8. **Interface Endpoints** use ENIs and support most other AWS services.
9. **PrivateLink** is the answer for securely exposing services between VPCs, especially when CIDRs overlap.
10. **VPC Flow Logs** capture traffic metadata (not packet content) and can be sent to CloudWatch Logs, S3, or Firehose.
11. **AWS reserves 5 IPs per subnet.** Account for this when planning CIDR blocks.
12. **No CIDR overlap** for VPC Peering or Transit Gateway connections.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- VPC Overview
- CIDR and IP Addressing
- Subnets
- Route Tables

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
