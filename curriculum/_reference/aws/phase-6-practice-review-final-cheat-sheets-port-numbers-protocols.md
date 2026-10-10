# Port Numbers and Protocols for Security Group / NACL Questions

Knowing these ports is essential for any question involving security groups, NACLs, or network connectivity troubleshooting.

---

## Critical Ports to Memorize

### Web Traffic
| Port | Protocol | Service |
|---|---|---|
| 80 | TCP | HTTP |
| 443 | TCP | HTTPS (SSL/TLS) |
| 8080 | TCP | HTTP Alternate (common for application servers, proxies) |
| 8443 | TCP | HTTPS Alternate |

### Remote Access
| Port | Protocol | Service |
|---|---|---|
| 22 | TCP | SSH (Linux remote access) |
| 3389 | TCP | RDP (Windows Remote Desktop Protocol) |

### Database Ports
| Port | Protocol | Service |
|---|---|---|
| 3306 | TCP | MySQL / Aurora MySQL / MariaDB |
| 5432 | TCP | PostgreSQL / Aurora PostgreSQL |
| 1433 | TCP | Microsoft SQL Server |
| 1521 | TCP | Oracle |
| 27017 | TCP | MongoDB (DocumentDB uses this) |
| 6379 | TCP | Redis (ElastiCache for Redis) |
| 11211 | TCP/UDP | Memcached (ElastiCache for Memcached) |

### Email
| Port | Protocol | Service |
|---|---|---|
| 25 | TCP | SMTP (blocked by AWS by default on EC2) |
| 465 | TCP | SMTPS (SMTP over SSL) |
| 587 | TCP | SMTP with STARTTLS (recommended for SES) |

### File Transfer
| Port | Protocol | Service |
|---|---|---|
| 21 | TCP | FTP (control) |
| 20 | TCP | FTP (data) |
| 22 | TCP | SFTP (SSH File Transfer — same port as SSH) |
| 990 | TCP | FTPS (FTP over SSL) |

### DNS
| Port | Protocol | Service |
|---|---|---|
| 53 | TCP/UDP | DNS (Route 53 uses this) |

### Other Important Ports
| Port | Protocol | Service |
|---|---|---|
| 443 | TCP | HTTPS (also used by AWS API endpoints) |
| 9090 | TCP | Common for management consoles, Prometheus |
| 2049 | TCP | NFS (used by EFS mount targets) |
| 445 | TCP | SMB (used by FSx for Windows) |
| 88 | TCP/UDP | Kerberos (Active Directory authentication) |
| 389 | TCP/UDP | LDAP (Active Directory) |
| 636 | TCP | LDAPS (LDAP over SSL) |

---

## Ephemeral Ports (Critical for NACLs)

Since NACLs are **stateless**, you must explicitly allow return traffic on ephemeral ports.

| System | Ephemeral Port Range |
|---|---|
| Linux / Amazon Linux | 32768 - 60999 |
| Windows | 49152 - 65535 |
| NAT Gateway | 1024 - 65535 |
| AWS ELB | 1024 - 65535 |
| Best practice for NACLs | 1024 - 65535 (covers all) |

**Example NACL configuration for a web server:**

Inbound rules:
| Rule # | Type | Port | Source | Action |
|---|---|---|---|---|
| 100 | HTTP | 80 | 0.0.0.0/0 | ALLOW |
| 110 | HTTPS | 443 | 0.0.0.0/0 | ALLOW |
| 120 | SSH | 22 | Admin CIDR | ALLOW |
| 130 | Custom TCP | 1024-65535 | 0.0.0.0/0 | ALLOW |
| * | All traffic | All | 0.0.0.0/0 | DENY |

Outbound rules:
| Rule # | Type | Port | Destination | Action |
|---|---|---|---|---|
| 100 | HTTP | 80 | 0.0.0.0/0 | ALLOW |
| 110 | HTTPS | 443 | 0.0.0.0/0 | ALLOW |
| 120 | Custom TCP | 1024-65535 | 0.0.0.0/0 | ALLOW |
| * | All traffic | All | 0.0.0.0/0 | DENY |

The ephemeral port range (1024-65535) in the inbound rules allows return traffic from web requests made by the server. The same range in outbound allows response traffic to clients.

---

## Protocol Numbers (for NACL rules)

| Protocol Number | Protocol |
|---|---|
| 6 | TCP |
| 17 | UDP |
| 1 | ICMP (ping) |
| -1 | All protocols |

---

## Common Security Group Patterns

### Web Server SG
```
Inbound:
  - HTTP (80) from 0.0.0.0/0
  - HTTPS (443) from 0.0.0.0/0
  - SSH (22) from admin CIDR (e.g., 10.0.0.0/24)

Outbound:
  - All traffic to 0.0.0.0/0 (default)
```

### Application Server SG
```
Inbound:
  - Custom TCP (8080) from Web-Server-SG
  - SSH (22) from admin CIDR

Outbound:
  - All traffic to 0.0.0.0/0 (default)
```

### Database Server SG
```
Inbound:
  - MySQL (3306) from App-Server-SG
  - PostgreSQL (5432) from App-Server-SG
  (Use the appropriate port for your database engine)

Outbound:
  - All traffic to 0.0.0.0/0 (default, or restrict to needed)
```

### ElastiCache SG
```
Inbound:
  - Redis (6379) from App-Server-SG
  - Memcached (11211) from App-Server-SG

Outbound:
  - All traffic (default)
```

### EFS Mount Target SG
```
Inbound:
  - NFS (2049) from EC2-Instance-SG

Outbound:
  - All traffic (default)
```

---

## AWS Service-Specific Ports

### VPC Endpoints (Interface)
- All interface endpoints communicate over HTTPS (port 443)
- The ENI in your subnet accepts connections on port 443

### Systems Manager (Session Manager)
- Uses HTTPS (port 443) — does NOT require port 22 (SSH)
- This is a common exam question: "How to connect without opening port 22?"
- Answer: Use SSM Session Manager (requires IAM role + SSM agent + outbound 443)

### ELB Health Checks
- Default health check port matches the target group port
- Can be overridden to a custom port
- ALB health check: HTTP/HTTPS
- NLB health check: TCP, HTTP, HTTPS

---

## Exam Tips for Port Questions

1. **"Application cannot connect to RDS MySQL"** → Check SG allows port 3306 from the application SG.
2. **"Cannot SSH into EC2 instance"** → Check SG allows port 22 from your IP. Check NACL allows port 22 inbound AND ephemeral ports outbound.
3. **"NACL is blocking return traffic"** → You forgot to allow ephemeral ports (1024-65535) in the outbound rules.
4. **"EFS mount fails"** → Check SG allows NFS port 2049 from the EC2 SG.
5. **"FSx for Windows cannot connect"** → Check SG allows SMB port 445.
6. **"Want to eliminate SSH key management"** → Use SSM Session Manager (port 443 only, no port 22 needed).
7. **"SMTP email sending from EC2"** → AWS blocks port 25 by default. Use SES with port 587 instead.
8. **"Redis connection refused"** → Check SG allows port 6379.
9. **"Active Directory integration"** → Ports 88 (Kerberos), 389 (LDAP), 636 (LDAPS), 445 (SMB), 53 (DNS).
10. **"DNS resolution failing"** → Check SG/NACL allows port 53 (both TCP and UDP).

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Critical Ports to Memorize
- Ephemeral Ports (Critical for NACLs)
- Protocol Numbers (for NACL rules)
- Common Security Group Patterns

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
