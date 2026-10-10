# Phase 1 Practice Questions -- SAA-C03 Style

20 scenario-based questions covering IAM, VPC, Route 53, and Elastic Load Balancing.
Choose the single best answer for each question. Answers and detailed explanations are at the bottom.

---

## Questions

### Question 1 -- IAM Policy Evaluation

A developer has an IAM user that belongs to two groups. Group A has a policy that allows `s3:PutObject` on all S3 buckets. Group B has a policy that explicitly denies `s3:PutObject` on the bucket `arn:aws:s3:::confidential-data/*`. The developer tries to upload a file to the `confidential-data` bucket.

What happens?

- A) The upload succeeds because the Allow from Group A takes precedence.
- B) The upload is denied because explicit Deny always overrides Allow.
- C) The upload succeeds because group policies are evaluated independently.
- D) The upload is denied because Group B was created after Group A.

---

### Question 2 -- Shared Responsibility Model

A company is running a fleet of Amazon RDS PostgreSQL instances. A security audit requires that the database engine is patched to the latest minor version. Who is responsible for applying this patch?

- A) The customer must manually apply the patch during a maintenance window.
- B) AWS automatically applies the patch during the configured maintenance window.
- C) The customer must create a new RDS instance with the updated engine version and migrate data.
- D) AWS and the customer share responsibility -- AWS provides the patch and the customer schedules application.

---

### Question 3 -- VPC Subnet Design

A solutions architect is designing a VPC. The architect creates a subnet with CIDR `10.0.1.0/24` in us-east-1a. How many IP addresses are available for EC2 instances in this subnet?

- A) 256
- B) 254
- C) 251
- D) 250

---

### Question 4 -- NAT Gateway Placement

An application in a private subnet needs to download software updates from the internet. The solutions architect needs to configure outbound internet access. Where should the NAT Gateway be placed?

- A) In the private subnet with the application instances.
- B) In a public subnet with an Elastic IP attached.
- C) In any subnet, as long as it has a route to the Internet Gateway.
- D) The NAT Gateway does not need to be in any subnet; it is a VPC-level resource.

---

### Question 5 -- Security Groups vs. NACLs

A web application is experiencing a DDoS attack from a specific IP range (203.0.113.0/24). The operations team needs to block this traffic immediately. Which approach is most appropriate?

- A) Add a deny rule to the Security Group attached to the web servers.
- B) Add a deny rule to the Network ACL of the subnet where the web servers reside.
- C) Modify the route table to blackhole the IP range.
- D) Remove the Internet Gateway temporarily.

---

### Question 6 -- VPC Peering

A company has three VPCs: VPC-A is peered with VPC-B, and VPC-B is peered with VPC-C. An instance in VPC-A needs to communicate with an instance in VPC-C. What must be done?

- A) Nothing -- traffic will route through VPC-B since it is peered with both.
- B) Create a new VPC peering connection directly between VPC-A and VPC-C.
- C) Enable transitive peering on VPC-B.
- D) Create a NAT Gateway in VPC-B to forward traffic between VPC-A and VPC-C.

---

### Question 7 -- Route 53 Alias Records

A company wants to point their naked domain (example.com) to an Application Load Balancer. Which Route 53 record type should they use?

- A) CNAME record pointing to the ALB DNS name.
- B) A record with the ALB's IP address.
- C) Alias A record pointing to the ALB.
- D) TXT record with the ALB ARN.

---

### Question 8 -- Route 53 Routing Policy

A global application is deployed in us-east-1 and eu-west-1. The team wants users to be automatically directed to the Region that provides the fastest response time. Which Route 53 routing policy should be used?

- A) Geolocation routing
- B) Latency-based routing
- C) Weighted routing
- D) Multivalue answer routing

---

### Question 9 -- ELB Type Selection

A company needs a load balancer for a real-time multiplayer gaming application that uses a custom TCP protocol on port 7777. The load balancer must provide ultra-low latency and a static IP address for players to connect to. Which ELB type is most appropriate?

- A) Application Load Balancer (ALB)
- B) Network Load Balancer (NLB)
- C) Gateway Load Balancer (GLB)
- D) Classic Load Balancer (CLB)

---

### Question 10 -- Cross-Zone Load Balancing

A solutions architect has deployed an NLB with targets in two Availability Zones. AZ-a has 2 targets and AZ-b has 8 targets. After monitoring, the architect notices the 2 targets in AZ-a are receiving significantly more traffic per instance than the 8 targets in AZ-b. What is the most likely cause?

- A) The NLB health checks are failing for some targets in AZ-b.
- B) Cross-zone load balancing is disabled, which is the default for NLB.
- C) The targets in AZ-a have larger instance types, so they attract more traffic.
- D) NLB does not support multiple AZs.

---

### Question 11 -- IAM Roles for EC2

A developer hard-coded AWS access keys in an application running on an EC2 instance. The security team has flagged this as a critical risk. What is the recommended remediation?

- A) Encrypt the access keys and store them in the application configuration file.
- B) Store the access keys in AWS Secrets Manager and retrieve them at runtime.
- C) Create an IAM role with the required permissions and attach it to the EC2 instance via an instance profile.
- D) Create a new IAM user with limited permissions and rotate the keys monthly.

---

### Question 12 -- VPC Endpoints

An application running on EC2 instances in a private subnet (no NAT Gateway) needs to access objects in Amazon S3. The solutions architect wants to keep traffic within the AWS network and minimize cost. What should the architect do?

- A) Create a VPC Gateway Endpoint for S3 and add it to the route tables of the private subnets.
- B) Create a VPC Interface Endpoint for S3 in the private subnets.
- C) Add a NAT Gateway so the instances can reach S3 over the internet.
- D) Create a VPC peering connection between the VPC and the S3 service VPC.

---

### Question 13 -- STS and Cross-Account Access

Company A needs to grant Company B (a different AWS account) access to an S3 bucket in Company A's account. The access should be temporary and follow the principle of least privilege. What is the recommended approach?

- A) Create an IAM user in Company A and share the access keys with Company B.
- B) Make the S3 bucket public so Company B can access it.
- C) Create an IAM role in Company A with a trust policy that allows Company B's account to assume it, and attach a policy granting S3 access.
- D) Add Company B's account root user to a group in Company A's account.

---

### Question 14 -- Service Control Policies

An organization has an SCP attached to the Production OU that denies all actions in the `ap-southeast-1` Region. A developer in a Production account has an IAM policy that allows `ec2:RunInstances` in all Regions. What happens when the developer tries to launch an EC2 instance in ap-southeast-1?

- A) The request succeeds because the IAM policy explicitly allows it.
- B) The request is denied because the SCP restricts it, and SCPs take precedence over IAM policies.
- C) The request succeeds because SCPs only apply to the root user of member accounts.
- D) The request is denied, but only if the SCP was applied after the IAM policy.

---

### Question 15 -- ALB Health Checks

An Application Load Balancer's target group has two registered EC2 instances. The health check is configured to check `HTTP GET /health` every 30 seconds with an unhealthy threshold of 2. Instance A's `/health` endpoint starts returning HTTP 500. What happens?

- A) The ALB immediately stops sending traffic to Instance A.
- B) The ALB marks Instance A as unhealthy after 2 consecutive failed health checks (~60 seconds) and stops routing new requests to it.
- C) The ALB removes Instance A from the target group permanently.
- D) The ALB continues sending traffic to Instance A because HTTP 500 is still a valid response.

---

### Question 16 -- Route 53 Health Checks for Private Resources

A solutions architect needs to set up Route 53 DNS failover for an application running on EC2 instances in a private subnet. Route 53 health checkers cannot reach the private IP addresses. How should the architect monitor the health of these instances for DNS failover?

- A) Create health checks using the private IP addresses; Route 53 can access private IPs within VPCs.
- B) Create a CloudWatch alarm that monitors the instances, then create a Route 53 health check that monitors the CloudWatch alarm.
- C) Use a Network Load Balancer with a public IP as a health check proxy.
- D) Disable health checks and use simple routing instead.

---

### Question 17 -- Well-Architected Framework

A team is redesigning their application to run on AWS Lambda instead of EC2 instances to reduce the operational burden of managing servers and patching operating systems. Which two Well-Architected Framework pillars does this decision most directly support?

- A) Security and Reliability
- B) Operational Excellence and Performance Efficiency
- C) Cost Optimization and Sustainability
- D) Operational Excellence and Sustainability

---

### Question 18 -- Sticky Sessions

Users of a web application report losing their shopping cart data when they refresh the page. The application stores session data in memory on the web server. The application runs behind an ALB with two target instances. What is the BEST long-term solution?

- A) Enable sticky sessions on the ALB target group.
- B) Store session data in Amazon ElastiCache (Redis) and remove the in-memory session store.
- C) Use a single EC2 instance instead of two to avoid session loss.
- D) Increase the ALB idle timeout to prevent connection resets.

---

### Question 19 -- NACLs and Ephemeral Ports

A solutions architect creates a custom NACL for a public subnet. The architect adds an inbound rule allowing HTTP (port 80) from 0.0.0.0/0 but forgets to add any outbound rules (the default deny-all remains). Web users report that the website is unreachable. What is the issue?

- A) The security group is also blocking the traffic.
- B) The NACL is stateless, so outbound response traffic on ephemeral ports (1024-65535) is being denied.
- C) The NACL inbound rule should allow port 443 instead of port 80.
- D) The route table is missing a route to the Internet Gateway.

---

### Question 20 -- AWS PrivateLink

A SaaS company wants to expose their service to customers in different AWS accounts. Customer VPC CIDR blocks may overlap with the SaaS company's VPC CIDR. The solution must keep traffic on the AWS network. What should the SaaS company use?

- A) VPC Peering between the SaaS VPC and each customer VPC.
- B) AWS Transit Gateway connecting all VPCs.
- C) AWS PrivateLink with a Network Load Balancer and VPC Endpoint Service.
- D) A public API endpoint with IAM authentication.

---

## Answers and Explanations

### Question 1: B

**Explicit Deny always wins.** When multiple policies apply, AWS evaluates all of them. If any policy has an explicit Deny, the request is denied regardless of any Allow statements. The order in which groups or policies were created is irrelevant. This is a fundamental IAM principle.

### Question 2: B

**AWS is responsible for patching the RDS database engine.** Under the Shared Responsibility Model, RDS is a managed (PaaS) service. AWS handles the underlying OS and database engine patching. The customer configures the maintenance window, but AWS applies the patches. The customer is responsible for their data, schema design, and query optimization.

### Question 3: C

**251 usable IPs.** A /24 subnet has 256 total IP addresses (2^8). AWS reserves 5 IPs in every subnet: the network address (.0), VPC router (.1), DNS server (.2), future use (.3), and broadcast (.255). So 256 - 5 = 251 usable IPs.

### Question 4: B

**NAT Gateway must be in a public subnet with an Elastic IP.** The NAT Gateway needs internet access itself (via the IGW) to translate private-to-public traffic. Placing it in a private subnet would mean it has no internet access and cannot perform NAT. The Elastic IP provides a static public IP for outbound traffic.

### Question 5: B

**Use a NACL deny rule.** Security Groups do not support deny rules (only allow rules), so option A is not possible. NACLs support both allow and deny rules and are evaluated at the subnet level, making them ideal for blocking specific IP ranges. Route table blackholing and removing the IGW would affect all traffic, not just the malicious range.

### Question 6: B

**VPC Peering is NOT transitive.** Traffic cannot flow from VPC-A through VPC-B to VPC-C. You must create a direct peering connection between VPC-A and VPC-C. There is no "transitive peering" setting. If you need transitive routing, use AWS Transit Gateway instead.

### Question 7: C

**Alias A record.** CNAME records cannot be used for the zone apex (naked domain like example.com) -- this is a DNS protocol restriction. Alias records are Route 53's solution: they work at the zone apex, resolve to the ALB's IP addresses directly, and DNS queries for Alias records to AWS resources are free. You cannot use an A record with the ALB's IP because ALB IPs change dynamically.

### Question 8: B

**Latency-based routing.** This policy routes users to the Region with the lowest measured network latency. Geolocation routing routes based on the user's physical location (country/continent), which does not necessarily correlate with the lowest latency. Weighted routing distributes traffic by percentage, not by performance. Multivalue routing returns multiple IPs for client-side selection.

### Question 9: B

**Network Load Balancer.** NLB operates at Layer 4 (TCP/UDP), supports custom protocols, provides ultra-low latency (~100 microseconds), and offers static IP addresses per AZ. ALB only handles HTTP/HTTPS (Layer 7). GLB is for network appliances. CLB is legacy and does not provide static IPs.

### Question 10: B

**Cross-zone load balancing is disabled by default for NLB.** Without cross-zone LB, each NLB node in an AZ distributes traffic only to targets in its own AZ. Since traffic is split 50/50 between the two AZ nodes, the 2 targets in AZ-a each receive 25% of total traffic, while the 8 targets in AZ-b each receive only 6.25%. Enabling cross-zone LB would distribute traffic evenly across all 10 targets. Note: ALB has cross-zone LB enabled by default.

### Question 11: C

**Use an IAM role with an instance profile.** This is the AWS best practice. IAM roles provide temporary credentials that are automatically rotated by the EC2 instance metadata service. Hard-coding keys (even encrypted) is an anti-pattern. Secrets Manager adds unnecessary complexity for this use case. Rotating keys monthly still leaves a window of exposure.

### Question 12: A

**VPC Gateway Endpoint for S3.** Gateway Endpoints are free and allow private subnets to access S3 without a NAT Gateway. Traffic stays on the AWS network. Interface Endpoints would also work but cost money (~$0.01/hour per AZ). A NAT Gateway would work but costs ~$0.045/hour plus data processing charges. VPC peering to S3 is not a valid concept.

### Question 13: C

**Cross-account IAM role.** This is the AWS-recommended pattern for cross-account access. Company B assumes the role via STS, receiving temporary credentials. Sharing access keys (A) violates security best practices. Making the bucket public (B) exposes it to everyone. You cannot add cross-account users to groups (D).

### Question 14: B

**SCPs restrict the maximum available permissions.** Even though the IAM policy allows the action, the SCP denies it at the organizational level. SCPs are evaluated before IAM policies in the policy evaluation logic. If the SCP does not allow (or explicitly denies) an action, the request is denied regardless of IAM policies. Note: SCPs affect all users and roles in member accounts, not just the root user.

### Question 15: B

**ALB waits for the unhealthy threshold to be reached.** With a 30-second interval and an unhealthy threshold of 2, the ALB will mark Instance A as unhealthy after approximately 60 seconds (2 consecutive failures). During this time, some traffic may still be sent to Instance A. Once marked unhealthy, the ALB stops routing NEW requests to it but does not remove it from the target group. The instance can return to healthy status if the health check starts passing again.

### Question 16: B

**Use CloudWatch alarms as a bridge.** Route 53 health checkers are on the public internet and cannot reach private IP addresses. The solution is to create a CloudWatch metric (e.g., via CloudWatch agent or a Lambda function) that monitors the private instance, create a CloudWatch alarm based on that metric, and then create a Route 53 health check that watches the alarm state.

### Question 17: B

**Operational Excellence and Performance Efficiency.** Moving to Lambda reduces operational burden (no server management, patching, or scaling decisions), which is Operational Excellence. Using a serverless, managed service is also Performance Efficiency (choosing the right technology, democratizing advanced technologies). While there may be cost and sustainability benefits, the question emphasizes reducing operational burden and choosing a managed service, which map most directly to these two pillars.

### Question 18: B

**Store session data in ElastiCache.** While sticky sessions (A) would solve the immediate problem, they create uneven load distribution and do not survive if the target instance fails. Externalizing session state to ElastiCache (Redis) is the best long-term architectural solution because it decouples session data from the web server, supports HA, and allows any instance to serve any user. Option C (single instance) eliminates high availability. Option D (idle timeout) does not address the root cause.

### Question 19: B

**NACLs are stateless.** Unlike Security Groups (which are stateful), NACLs evaluate inbound and outbound traffic independently. Even though inbound HTTP on port 80 is allowed, the outbound response traffic (which uses ephemeral ports 1024-65535) is being denied by the default deny-all outbound rule. The fix is to add an outbound rule allowing TCP on ports 1024-65535 to 0.0.0.0/0.

### Question 20: C

**AWS PrivateLink with NLB and VPC Endpoint Service.** PrivateLink is designed for exactly this scenario: exposing a service to other VPCs/accounts securely, without VPC peering, and without CIDR overlap concerns (because PrivateLink uses ENIs, not IP routing). VPC Peering (A) does not work with overlapping CIDRs. Transit Gateway (B) also has CIDR overlap issues and provides more network connectivity than needed. A public API (D) does not keep traffic on the AWS network.

---

## Score Tracker

| Score Range | Assessment |
|---|---|
| 18-20 correct | Excellent -- you are well prepared for Phase 1 topics on the exam |
| 14-17 correct | Good -- review the explanations for questions you missed |
| 10-13 correct | Fair -- re-read the relevant notes and redo labs for weak areas |
| Below 10 | Needs work -- spend more time with the notes before moving to Phase 2 |

**Your score: ___ / 20**

Focus areas for review:
- [ ] IAM (Questions 1, 11, 13, 14)
- [ ] VPC (Questions 3, 4, 5, 6, 12, 19, 20)
- [ ] Route 53 (Questions 7, 8, 16)
- [ ] ELB (Questions 9, 10, 15, 18)
- [ ] Fundamentals (Questions 2, 17)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Score Tracker
- IAM Policy Evaluation
- Shared Responsibility Model
- VPC Subnet Design

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
