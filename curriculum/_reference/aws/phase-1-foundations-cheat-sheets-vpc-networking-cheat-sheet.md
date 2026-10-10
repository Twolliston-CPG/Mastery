# VPC Networking Cheat Sheet

Quick reference for VPC components, CIDR planning, security layers, and connectivity options.

---

## VPC Basics

| Fact | Detail |
|---|---|
| Scope | Regional (one Region, all AZs) |
| CIDR range | /16 (largest) to /28 (smallest) |
| Secondary CIDRs | Up to 5 (can request more) |
| Default VPC | 172.31.0.0/16, one public subnet per AZ |
| DNS | `enableDnsSupport` (default true), `enableDnsHostnames` (default false for custom VPCs) |
| Tenancy | Default (shared) or Dedicated (expensive) |

---

## CIDR Quick Reference

| CIDR | Total IPs | Usable IPs (minus 5 reserved) | Use Case |
|---|---|---|---|
| /16 | 65,536 | 65,531 | Large VPC |
| /17 | 32,768 | 32,763 | |
| /18 | 16,384 | 16,379 | |
| /19 | 8,192 | 8,187 | |
| /20 | 4,096 | 4,091 | Medium VPC / large subnet |
| /21 | 2,048 | 2,043 | |
| /22 | 1,024 | 1,019 | |
| /23 | 512 | 507 | |
| /24 | 256 | 251 | Standard subnet |
| /25 | 128 | 123 | Small subnet |
| /26 | 64 | 59 | |
| /27 | 32 | 27 | |
| /28 | 16 | 11 | Minimum VPC/subnet size |

**AWS reserves 5 IPs per subnet:** .0 (network), .1 (router), .2 (DNS), .3 (future), .255 (broadcast).

---

## Subnet Cheat Table

| Attribute | Public Subnet | Private Subnet | Isolated Subnet |
|---|---|---|---|
| Route to IGW | Yes (0.0.0.0/0 -> IGW) | No | No |
| Route to NAT GW | No (goes direct to IGW) | Yes (0.0.0.0/0 -> NAT) | No |
| Auto-assign public IP | Yes | No | No |
| Internet access | Full (inbound + outbound) | Outbound only (via NAT) | None |
| Typical use | ALB, bastion, NAT GW | App servers | Databases |

---

## Security Groups vs. NACLs

| Feature | Security Group | Network ACL |
|---|---|---|
| **Level** | Instance (ENI) | Subnet |
| **Stateful?** | Yes | **No** |
| **Rule types** | Allow only | Allow AND Deny |
| **Rule evaluation** | All rules (union) | Ordered by rule number (first match) |
| **Default inbound** | Deny all (custom SG) | Allow all (default NACL) |
| **Default outbound** | Allow all | Allow all (default NACL) |
| **Return traffic** | Automatic | Must explicitly allow (ephemeral ports!) |
| **SG references** | Yes (can reference other SGs) | No (CIDR only) |
| **Changes** | Immediate | Immediate |
| **Per subnet/instance** | Up to 5 SGs per ENI | 1 NACL per subnet |

### Ephemeral Ports Reminder (NACLs)

Because NACLs are stateless, you MUST allow ephemeral ports (1024-65535) for return traffic:
- **Inbound rule needed** for responses to outbound requests you initiate.
- **Outbound rule needed** for responses to inbound requests from clients.

---

## Gateway Comparison

| Component | Purpose | Placement | Cost |
|---|---|---|---|
| **Internet Gateway** | Inbound + outbound internet access | VPC level (attach to VPC) | Free |
| **NAT Gateway** | Outbound-only internet for private subnets | Public subnet | ~$0.045/hr + data |
| **NAT Instance** | Same as NAT GW but self-managed (legacy) | Public subnet | EC2 cost only |
| **Egress-Only IGW** | Outbound-only for IPv6 | VPC level | Free |
| **Virtual Private GW** | VPN connection to on-premises | VPC level | VPN charges |
| **Transit Gateway** | Hub for VPCs, VPNs, Direct Connect | Regional | ~$0.05/hr/attach |

---

## VPC Connectivity Options

| Method | Transitive? | Cross-Region? | Overlapping CIDR? | Best For |
|---|---|---|---|---|
| **VPC Peering** | No | Yes | No | 1:1 VPC connections (<10 VPCs) |
| **Transit Gateway** | Yes | Yes (via peering) | No | Hub-and-spoke (10+ VPCs) |
| **PrivateLink** | N/A | No (same Region) | Yes | Exposing services to other VPCs |
| **VPN (Site-to-Site)** | No | N/A | No | On-premises to AWS |
| **Direct Connect** | No | Via DX Gateway | No | Dedicated on-premises link |

---

## VPC Endpoints

| Type | Supported Services | How It Works | Cost | Cross-VPC/VPN? |
|---|---|---|---|---|
| **Gateway Endpoint** | S3, DynamoDB | Route table entry (prefix list) | **Free** | No |
| **Interface Endpoint** | 150+ services | ENI in your subnet | ~$0.01/hr/AZ + data | Yes |

**When to use which:**
- Need to access S3 or DynamoDB from private subnet? --> **Gateway Endpoint** (free).
- Need to access other services (SQS, KMS, CloudWatch, etc.) privately? --> **Interface Endpoint**.
- Need access from on-premises or peered VPCs? --> **Interface Endpoint** (Gateway Endpoints are not accessible outside the VPC).

---

## VPC Flow Logs

| Setting | Options |
|---|---|
| Level | VPC, Subnet, or ENI |
| Traffic type | ALL, ACCEPT, or REJECT |
| Destination | CloudWatch Logs, S3, Data Firehose |
| Captures | Source/dest IP, ports, protocol, packets, bytes, action, timestamp |
| Does NOT capture | DNS to Amazon DNS, DHCP, metadata (169.254.169.254), VPC router, reserved IPs |

---

## Common Troubleshooting

### "EC2 instance in public subnet can't reach the internet"

1. Does the route table have `0.0.0.0/0 -> IGW`?
2. Does the instance have a public IP or Elastic IP?
3. Does the Security Group allow outbound traffic?
4. Does the NACL allow outbound traffic AND inbound ephemeral ports?
5. Is the IGW attached to the VPC?

### "EC2 instance in private subnet can't reach the internet"

1. Does the route table have `0.0.0.0/0 -> NAT GW`?
2. Is the NAT GW in a **public** subnet?
3. Is the NAT GW in **available** state?
4. Does the NAT GW's public subnet have a route to the IGW?
5. Does the NACL allow outbound HTTP/HTTPS and inbound ephemeral ports?

### "Instances in the same VPC can't communicate"

1. Is the `local` route present in both route tables? (Always present, can't be removed.)
2. Do the Security Groups allow the traffic between instances?
3. Do the NACLs allow the traffic between subnets?

---

## VPC Cost Summary

| Resource | Free? | Approximate Cost |
|---|---|---|
| VPC, Subnets, Route Tables, SGs, NACLs | Yes | $0 |
| Internet Gateway | Yes | $0 |
| VPC Peering connection | Yes | $0 (data transfer charged) |
| Gateway Endpoint (S3/DynamoDB) | Yes | $0 |
| Elastic IP (associated with running instance) | Yes | $0 |
| NAT Gateway | No | ~$0.045/hr + $0.045/GB |
| Interface Endpoint | No | ~$0.01/hr/AZ + $0.01/GB |
| Transit Gateway | No | ~$0.05/hr/attachment + $0.02/GB |
| Elastic IP (not associated) | No | ~$0.005/hr |
| Data transfer (inter-AZ) | No | ~$0.01/GB each direction |
| Data transfer (internet out) | No | ~$0.09/GB (first 10 TB) |

---

## Exam Quick Tips

1. **"Private subnet needs S3 access without NAT?"** --> Gateway Endpoint (free).
2. **"Block a specific IP?"** --> NACL deny rule (SGs only have allow rules).
3. **"VPC Peering not working transitively?"** --> Use Transit Gateway.
4. **"CIDR overlaps?"** --> PrivateLink (not VPC Peering, not TGW).
5. **"NAT GW placement?"** --> Public subnet with EIP. Private subnet route table points to it.
6. **"Traffic logged for audit?"** --> VPC Flow Logs.
7. **"HA for NAT?"** --> One NAT GW per AZ, each AZ's private RT points to its own NAT GW.
8. **"Cheapest private connectivity to S3?"** --> Gateway Endpoint ($0).
9. **"Stateful vs stateless?"** --> SG = stateful, NACL = stateless. Always.
10. **"DB subnet needs zero internet?"** --> Isolated route table with only the local route.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- VPC Basics
- CIDR Quick Reference
- Subnet Cheat Table
- Security Groups vs. NACLs

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
