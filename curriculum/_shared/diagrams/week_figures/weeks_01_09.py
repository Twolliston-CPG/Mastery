# Weeks 1-9. Each entry: title, intro, direction, mermaid body (nodes/edges only), linkStyle, minutes, open, badges, close.
F = {}

F[1] = dict(
 title="A process on a Linux system, from the shell to the commit",
 intro="Everything the week teaches is one of four mechanisms: how a command becomes a process, how the kernel decides what it may touch, how text flows between processes, and how Git records the result.",
 body='''
  subgraph HOST["The VM · one user, one shell, one kernel"]
    direction LR
    A1["① bash<br/><small>PATH lookup · fork then exec</small>"]:::crit
    A2["② the process<br/><small>PID · /proc/PID · ps and top</small>"]:::crit
    A3["③ permission check<br/><small>uid, gid · rwx bits · 644 vs 755</small>"]:::crit
    A4["④ the filesystem<br/><small>/etc config · /var state · /proc the kernel talking</small>"]:::data
    A5["⑤ the pipeline<br/><small>grep then awk then sort then uniq -c</small>"]:::n
    A6["⑥ the script<br/><small>set -euo pipefail · traps · argparse by hand</small>"]:::n
    A7["⑦ special bits<br/><small>setuid passwd · sticky /tmp · umask 022</small>"]:::warn
  end
  subgraph GIT["Git · the record"]
    direction LR
    G1["⑧ working tree to index to commit<br/><small>a commit is a snapshot plus a parent SHA</small>"]:::data
    G2["⑨ remote<br/><small>push · branch · PR · public repo</small>"]:::n
  end
  BF["⑩ Break/Fix BF-01 to BF-04<br/><small>disk full · wrong perms · zombie · PATH</small>"]:::warn
  A1 ==> A2 ==> A3 ==> A4
  A4 --> A5 --> A6
  A3 -.-> A7
  A6 --> G1 --> G2
  A2 -.-> BF
''',
 link="linkStyle 0,1,2 stroke:#2f6fb8,stroke-width:2px",
 minutes="three",
 open="This is one week of Linux in one picture: a command becomes a process, the kernel checks what it may touch, text flows through a pipeline, and Git records what you built. Follow the blue path first.",
 badges=[
  ("bash", "Every command starts here. The shell searches PATH, forks itself, and the child execs the program. That is why a typo in PATH breaks everything at once, and why `which` is the first debugging command."),
  ("the process", "The result is a process with a PID. /proc/PID is not a file on disk; it is the kernel describing that process. `ps` and `top` read it. When a lab says inspect a process, this is the directory to open."),
  ("permission check", "Before any read or write, the kernel compares the file's owner, group, and mode bits to the process's uid and gid. 644 means owner writes, everyone reads. On a directory, execute means enter, which is why 755 matters there."),
  ("the filesystem", "The hierarchy is a convention worth memorizing: /etc is configuration, /var is state that grows, /proc and /sys are the kernel. Where a file lives tells you who owns the problem."),
  ("the pipeline", "Text processing is processes connected by pipes. grep selects lines, awk picks fields and counts into an associative array, sort and uniq -c aggregate. A 100,000-line log becomes a top-10 report with four processes."),
  ("the script", "A real script starts with `set -euo pipefail`: exit on error, error on an unset variable, fail the pipeline if any stage fails. Traps clean up. Arguments are parsed by hand. This is `sysreport.sh`."),
  ("special bits", "Three bits that are classic interview and escalation material. setuid lets `passwd` edit /etc/shadow as root. The sticky bit lets everyone write /tmp but delete only their own files. umask 022 is why new files are 644, not 666."),
  ("working tree to index to commit", "A commit is not a diff. It is a snapshot plus the SHA of its parent, which is why history is a chain and why rewriting one commit changes every SHA after it. The index is the staging step in between."),
  ("remote", "push sends the chain. A branch is a pointer, a pull request is a conversation about a pointer. The deliverable is public, which means the README has to work for a stranger."),
  ("Break/Fix", "Four scenarios, forty minutes, narrated out loud: disk full, wrong permissions, a zombie, a broken PATH. Each one is logged in the incident journal. That journal is the interview story bank."),
 ],
 close="So: shell to process to permission check to filesystem, text through pipes, a script that fails loudly, and Git recording it. Nothing in the next 25 weeks is not one of these in a costume.",
)

F[2] = dict(
 title="From a URL to a packet, and the service that answers",
 intro="The blue path is the request: name resolution, the three-way handshake, HTTP. Around it are the things that make the server answer at all: a systemd unit, a hardened sshd, and the CIDR math that decides where the packet goes.",
 body='''
  U["① the URL<br/><small>scheme · host · port 443 · path</small>"]:::crit
  D["② DNS resolution<br/><small>stub to recursive to root to TLD to authoritative · dig +trace</small>"]:::crit
  C["③ CIDR decision<br/><small>same subnet? 10.0.0.0/24 = 254 hosts · else the default route</small>"]:::crit
  T["④ TCP handshake<br/><small>SYN · SYN-ACK · ACK · seen in tcpdump</small>"]:::crit
  H["⑤ HTTP<br/><small>GET / · status · headers · the body</small>"]:::crit
  subgraph SRV["The server · what makes it answer"]
    direction TB
    S1["⑥ systemd unit<br/><small>ExecStart · Restart=on-failure · a timer, not cron</small>"]:::n
    S2["⑦ journald<br/><small>journalctl -u name -f · -p err · --since</small>"]:::data
    S3["⑧ sshd hardened<br/><small>keys only · no root login · two sessions open</small>"]:::warn
    S4["⑨ disks<br/><small>lsblk · mkfs · mount · fstab · a loopback to practice on</small>"]:::data
  end
  B["⑩ blog post 1<br/><small>what happens when you hit enter</small>"]:::mut
  U ==> D ==> C ==> T ==> H
  H --> S1
  S1 -.-> S2
  S3 -.-> S1
  S1 -.-> S4
  H -.-> B
''',
 link="linkStyle 0,1,2,3 stroke:#2f6fb8,stroke-width:2px",
 minutes="three and a half",
 open="This is the week's deliverable drawn out: what happens when you type a URL and hit enter, and what has to be true on the server for anything to come back. Left to right is the request. The box is the server.",
 badges=[
  ("the URL", "Four parts: a scheme that implies a port, a host that needs resolving, a path the server interprets. 443 is a number you say without thinking by Friday."),
  ("DNS resolution", "Your stub resolver asks a recursive resolver. It walks root, then the TLD, then the authoritative server, caching each answer for its TTL. `dig +trace` shows every hop. A wrong answer is almost always a stale cache or the wrong authoritative server."),
  ("CIDR decision", "Before a packet leaves, the kernel asks one question: is the destination in my subnet? A /24 is 256 addresses, 254 usable, network and broadcast reserved. If it is not local, the packet goes to the default route. One hundred problems this week make that question automatic."),
  ("TCP handshake", "SYN, SYN-ACK, ACK. Three packets, one round trip, before a single byte of HTTP. In tcpdump you can point at all three. A connection that hangs at SYN is a firewall or a routing problem, never the application."),
  ("HTTP", "Now the request: a method, a path, headers, a body. The status code is the server's one-word answer. Everything above this line was plumbing; everything the user sees starts here."),
  ("systemd unit", "The server answers because a unit file says ExecStart and Restart=on-failure, and systemd keeps it running. A timer unit replaces cron with logging, dependencies, and `systemctl list-timers`. Write both from blank."),
  ("journald", "`journalctl -u name -f` follows one service. `-p err --since today` filters. This is where you look before you look anywhere else."),
  ("sshd hardened", "Keys only, no root login, no passwords. The rule that matters: keep two sessions open while you change sshd, and test from a third before you close anything. Lockouts are the week's classic self-inflicted incident."),
  ("disks", "lsblk, mkfs, mount, fstab. Practice on a loopback file so a mistake costs nothing. A full disk is BF-01; knowing the layout is how you find what filled it."),
  ("blog post", "Saturday you write all of this down for a stranger. If a step is hard to explain, that is the step you do not yet own."),
 ],
 close="Name, route, handshake, request. Then a unit that keeps the service alive and logs you can read. Every VPC and every Kubernetes Service later is this picture with different names on the boxes.",
)

F[3] = dict(
 title="Browser to backend: routing, NAT, firewall, TLS, and the reverse proxy",
 intro="Follow the blue path from a client on the internet to the Python process behind Nginx. Every box is something you build by hand this week, and every box is something AWS will later sell you under a different name.",
 body='''
  CL["① client<br/><small>browser · curl -v</small>"]:::crit
  DN["② DNS<br/><small>your own domain · an A record · TTL</small>"]:::crit
  RT["③ router and NAT<br/><small>ip route · MASQUERADE · a network namespace as the lab</small>"]:::crit
  FW["④ firewall<br/><small>nftables · ct state established,related first · order matters</small>"]:::warn
  NG["⑤ Nginx :443<br/><small>TLS terminates here · Let's Encrypt · 90-day cert, auto-renew</small>"]:::crit
  UP["⑥ upstream pool<br/><small>two backends · health checks · failover on 502</small>"]:::crit
  AP["⑦ backend app<br/><small>:8000 on localhost · never exposed directly</small>"]:::crit
  AC["⑧ ACME HTTP-01<br/><small>:80 must be reachable · /.well-known/acme-challenge</small>"]:::mut
  TF["⑨ three TLS failures<br/><small>expired · name mismatch · untrusted chain</small>"]:::warn
  GT["⑩ Git collaboration<br/><small>rebase · 3-way conflict · bisect · 12 commits to 3</small>"]:::data
  CL ==> DN ==> RT ==> FW ==> NG ==> UP ==> AP
  AC -.-> NG
  NG -.-> TF
  AP -.-> GT
''',
 link="linkStyle 0,1,2,3,4,5 stroke:#2f6fb8,stroke-width:2px",
 minutes="three and a half",
 open="This is the packet path you will be asked to explain at Gate 1: a browser on the internet to a Python process on your VM. Seven boxes on the blue line, each one built by hand this week.",
 badges=[
  ("client", "Start with `curl -v`. It prints the DNS answer, the TCP connect, the TLS handshake, and the HTTP exchange, in order. When something breaks, the line where curl stops names the layer."),
  ("DNS", "Your own domain, bought this week for about twelve dollars. One A record points at the VM. The TTL you choose is how long a wrong answer lives in every cache on the internet."),
  ("router and NAT", "A packet that leaves a private address needs its source rewritten. MASQUERADE does that at the router, and the conntrack table remembers the mapping so the reply finds its way back. You build this with a network namespace, so you can see both sides."),
  ("firewall", "nftables evaluates rules in order and stops at the first match. The stateful rule, `ct state established,related accept`, goes first; without it every reply is dropped. BF-13 is exactly this: a correct rule in the wrong position. Stateful versus stateless is the whole SG versus NACL conversation in week 6."),
  ("Nginx on 443", "TLS terminates here. The certificate is from Let's Encrypt, valid 90 days, renewed by a timer. Nginx is the only process that listens on a public port."),
  ("upstream pool", "Two backends behind one name. Health checks mark one down; traffic fails over on a 502. Kill a backend and watch the other take the load. That is a load balancer, and you now know what the ALB does."),
  ("backend app", "The Python process listens on 8000, on localhost only. It never sees the internet. If it did, the firewall and the proxy would be decoration."),
  ("ACME HTTP-01", "Let's Encrypt proves you own the name by fetching a token over port 80. If 80 is closed, issuance fails. That is the reason the firewall opens 80 even though users use 443."),
  ("three TLS failures", "Expired, name mismatch, untrusted chain. They look identical in a browser and completely different in `openssl s_client`. Break each one on purpose so you recognize it on sight."),
  ("Git collaboration", "Friday afternoon: resolve a real three-way conflict, squash twelve commits into three with an interactive rebase, and find a breaking commit with bisect in log-two-n steps."),
 ],
 close="Name, route, rewrite, filter, terminate, balance, serve. Weeks 6 and 7 are this diagram with AWS names: Route 53, NAT gateway, security group, ALB, target group.",
)

F[4] = dict(
 title="What a container actually is, and the stack Gate 1 asks you to deploy",
 intro="Top row: an image is built and becomes a process the kernel isolates. Bottom row: three of those processes behind the week-3 Nginx, managed by systemd. The gate is the whole picture, from a fresh VM, with docs only.",
 body='''
  subgraph BUILD["Build · Dockerfile"]
    direction LR
    B1["① build stage<br/><small>compiler, dev deps · discarded</small>"]:::n
    B2["② runtime stage<br/><small>slim base · non-root · measured size</small>"]:::crit
    B3["③ image layers<br/><small>content-addressed · cached · pulled once</small>"]:::data
  end
  subgraph RUN["Run · the kernel"]
    direction LR
    R1["④ the process<br/><small>PID 1 in its own view</small>"]:::crit
    R2["⑤ namespaces<br/><small>pid · net · mnt · uts · ipc · user · what it can SEE</small>"]:::crit
    R3["⑥ cgroups<br/><small>cpu · memory · what it can USE · OOM = exit 137</small>"]:::warn
  end
  subgraph STACK["Compose · the Gate 1 stack"]
    direction LR
    C1["⑦ Python app<br/><small>argparse · logging · pytest · JSON out</small>"]:::crit
    C2["⑧ Postgres<br/><small>named volume · healthcheck</small>"]:::data
    C3["⑨ Nginx<br/><small>TLS from week 3 · the only public port</small>"]:::crit
    C4["⑩ systemd + firewall<br/><small>compose up on boot · 80/443 only</small>"]:::n
  end
  EX["⑪ exit codes<br/><small>0 · 1 · 137 killed · 139 segfault · 143 SIGTERM</small>"]:::warn
  B2 ==> B3 ==> R1 ==> R2
  R1 --> R3
  B1 --> B2
  R2 --> C1
  C3 ==> C1 --> C2
  C4 -.-> C3
  R3 -.-> EX
''',
 link="linkStyle 0,1,2,6 stroke:#2f6fb8,stroke-width:2px",
 minutes="three and a half",
 open="A container is not a small VM. It is a Linux process with restricted visibility and a budget. This figure shows the build, the isolation, and the three-container stack Gate 1 asks you to deploy from nothing.",
 badges=[
  ("build stage", "The first stage has the compiler and every dev dependency. Nothing from it ships except the artifact you copy out. This is why multi-stage builds shrink images by hundreds of megabytes."),
  ("runtime stage", "A slim base, a non-root user, only the artifact. Measure before and after and put the two numbers in the README. Size is attack surface, and a number is proof."),
  ("image layers", "Each instruction is a layer, addressed by content hash. Unchanged layers are cached and pulled once. Order the Dockerfile so the things that change most come last."),
  ("the process", "`docker run` starts one process. Inside, it is PID 1. From the host, `ps` shows it as an ordinary process with a strange parent. There is no hypervisor anywhere in this picture."),
  ("namespaces", "Six namespaces decide what the process can see: its own PIDs, its own network stack, its own mounts, hostname, IPC, and user mapping. `nsenter` lets you step into each one and prove it."),
  ("cgroups", "cgroups decide what it can use. CPU over the limit is throttled; memory over the limit is killed, exit code 137. Week 15 shows the same rule in Kubernetes. Learn it here where it is cheap."),
  ("Python app", "The week's first two days: a CLI with argparse, type hints, logging to stderr, JSON to stdout, and tests. It also exposes a Prometheus-format metrics endpoint, a preview of week 20."),
  ("Postgres", "A named volume so data survives the container. A healthcheck so Compose knows when it is actually ready, not just started. Depends-on without a healthcheck is a race."),
  ("Nginx", "The week-3 proxy, now in a container, still the only thing on a public port. TLS terminates here exactly as before."),
  ("systemd and firewall", "A unit runs `compose up` on boot and restarts it on failure. The firewall allows 80 and 443 and nothing else. The gate checks both."),
  ("exit codes", "0 is success, 1 is the app's own failure, 137 is the kernel killing it, 139 is a segfault, 143 is a clean SIGTERM. Reading the code is the first diagnostic step in BF-19."),
 ],
 close="Build small, run isolated, budget enforced, three containers behind one proxy, managed by systemd. Then the Gate 1 question: narrate the packet from the browser to the Python process, box by box.",
)

F[5] = dict(
 title="How AWS decides, and how an instance gets credentials with no keys on disk",
 intro="Two blue paths. The top one is the IAM evaluation every request goes through. The bottom one is the mechanism that gives an EC2 instance credentials it never stores: the instance profile and IMDSv2.",
 body='''
  subgraph EVAL["IAM evaluation · every request, in this order"]
    direction LR
    E1["① principal + request<br/><small>who · action · resource · conditions</small>"]:::crit
    E2["② explicit Deny?<br/><small>anywhere wins</small>"]:::warn
    E3["③ SCP · permission boundary<br/><small>ceilings, not grants</small>"]:::n
    E4["④ identity or resource policy Allow?<br/><small>no Allow = implicit deny</small>"]:::crit
    E5["⑤ allowed<br/><small>or AccessDenied, with the reason in CloudTrail</small>"]:::crit
  end
  subgraph INST["EC2 · credentials without a credential"]
    direction LR
    I1["⑥ instance profile<br/><small>wraps a role · attached at launch</small>"]:::n
    I2["⑦ IMDSv2<br/><small>PUT token, TTL ≤ 6 h · hop limit 1 · 169.254.169.254</small>"]:::crit
    I3["⑧ temporary credentials<br/><small>rotated about every 6 h · never on disk</small>"]:::data
    I4["⑨ SDK credential chain<br/><small>env → profile → container → IMDS</small>"]:::n
  end
  X["⑩ cross-account AssumeRole<br/><small>trust policy + ExternalId · STS</small>"]:::n
  G["⑪ guardrails first<br/><small>budgets $25 · $50 · $100 · root MFA · no root keys</small>"]:::warn
  E1 ==> E2 ==> E3 ==> E4 ==> E5
  I1 ==> I2 ==> I3 ==> I4
  I4 --> E1
  X -.-> E1
  G -.-> I1
''',
 link="linkStyle 0,1,2,3,4,5,6 stroke:#2f6fb8,stroke-width:2px",
 minutes="three and a half",
 open="IAM breaks in production more than anything else in AWS. The top row is the decision AWS makes on every call. The bottom row is how a machine gets to make calls at all, without a key on disk. Both are exam material and both are interview material.",
 badges=[
  ("principal and request", "A principal, an action, a resource, and conditions. Every AccessDenied is one of those four being different from what you assumed. The policy simulator lets you test the four without making the call."),
  ("explicit Deny", "An explicit Deny anywhere wins, over any Allow, from any policy. This is the first thing evaluated and the first thing to look for when a user with AdministratorAccess still gets denied."),
  ("SCP and permission boundary", "These are ceilings. An SCP from Organizations and a permission boundary on the identity can only take permissions away. A boundary that does not mention S3 means no S3, however generous the identity policy is."),
  ("identity or resource policy Allow", "Within the same account, an Allow from either the identity's policy or the resource's policy is enough. Across accounts, you need both. No Allow at all is an implicit deny, and it is the common case."),
  ("allowed", "Or denied, and the reason is in CloudTrail. Four AccessDenied stories become blog post 3."),
  ("instance profile", "A role needs a vehicle to ride on an instance. The instance profile is that vehicle, attached at launch. The role has the permissions; the profile is just the attachment."),
  ("IMDSv2", "The instance asks the metadata service at 169.254.169.254. Version 2 requires a PUT to get a session token first, with a TTL up to six hours, and a hop limit of one so a container on the instance cannot reach it. Version 1 is a plain GET, and that is the SSRF story."),
  ("temporary credentials", "The answer is an access key, a secret, and a session token, rotated roughly every six hours. Nothing is written to disk. Lose the instance, lose the credentials."),
  ("SDK credential chain", "The SDK looks in order: environment variables, a profile file, the container endpoint, then IMDS. Knowing the order explains why a stray key in a profile file silently overrides the role."),
  ("cross-account AssumeRole", "A role in account B trusts a principal in account A. STS issues temporary credentials. ExternalId stops the confused-deputy problem when a third party does the assuming."),
  ("guardrails first", "Before any of this exists: three budgets, alerts tested, MFA on root, root access keys deleted. The script does the budgets. The rest is a five-minute console task you do once."),
 ],
 close="Deny first, ceilings next, then an Allow or nothing. And a machine earns credentials by being who it is, not by holding a key. Week 12 and week 16 are the same idea for a GitHub workflow and for a pod.",
)

F[6] = dict(
 title="A two-AZ VPC, and what makes a subnet public",
 intro="The week-2 subnetting and the week-3 router, NAT, and firewall, now as AWS resources. Follow the blue line from the internet to the data tier and notice where it stops.",
 body='''
  NET["internet"]:::mut
  subgraph VPC["① VPC 10.20.0.0/16 · two AZs · three tiers · 75 % of the range left free"]
    direction TB
    IG["② internet gateway<br/><small>one per VPC · no bandwidth limit</small>"]:::crit
    subgraph PUB["③ public /24 per AZ · rtb → 0.0.0.0/0 via igw"]
      direction LR
      NAT["④ NAT gateway<br/><small>one per AZ in prod · billed per hour + per GB</small>"]:::crit
      BAS["⑤ bastion<br/><small>ssh -J · ProxyJump · SG allows your IP only</small>"]:::n
    end
    subgraph APP["⑥ app /20 per AZ · rtb → 0.0.0.0/0 via nat"]
      direction LR
      A["instances<br/><small>private IPs only</small>"]:::crit
    end
    subgraph DAT["⑦ data /24 per AZ · rtb has NO default route"]
      direction LR
      D["RDS<br/><small>reachable from app SG only</small>"]:::data
    end
    EP["⑧ S3 gateway endpoint<br/><small>free · a route-table entry · replaces the NAT path for S3</small>"]:::crit
    FL["⑨ Flow Logs<br/><small>ACCEPT and REJECT · find the rejected connection</small>"]:::data
  end
  SG["⑩ SG vs NACL<br/><small>stateful, allow-only, on the ENI · stateless, ordered, on the subnet</small>"]:::warn
  S3["⑪ S3<br/><small>bucket policy denies unencrypted uploads · presigned URL · lifecycle to IA and Glacier</small>"]:::data
  NET ==> IG ==> NAT ==> A
  A ==> EP ==> S3
  A --> D
  NET -.-> BAS -.-> A
  SG -.-> A
  A -.-> FL
''',
 link="linkStyle 0,1,2,3,4 stroke:#2f6fb8,stroke-width:2px",
 minutes="three and a half",
 open="This is the diagram you draw by hand this week and clean up for Project Alpha. Three tiers, two availability zones, and one question that decides everything: what route table is a subnet attached to.",
 badges=[
  ("VPC", "A /16 gives you 65,536 addresses. The tiers here use about a quarter of them, deliberately, so there is room to add tiers later without renumbering. Renumbering a VPC is a migration."),
  ("internet gateway", "One per VPC, horizontally scaled, no bandwidth to size. Attaching it does nothing by itself. A route has to point at it."),
  ("public subnets", "What makes a subnet public is not a checkbox. It is a route table with 0.0.0.0/0 pointing at the internet gateway, plus an instance with a public IP. Say that sentence in an interview and you are ahead of most candidates."),
  ("NAT gateway", "Private instances reach the internet through NAT in a public subnet, exactly like the week-3 namespace lab. One per AZ in production, because a NAT in AZ-a does nothing for AZ-b when AZ-a is down. It bills per hour and per gigabyte."),
  ("bastion", "The only SSH door, in the public tier, security group open to your IP alone. `ssh -J bastion private-host` with ProxyJump in your SSH config, so the private key never leaves your laptop."),
  ("app subnets", "A /20 per AZ, 4,096 addresses, because this tier will hold pods one day and pods eat IPs. Default route to the NAT. No public IPs."),
  ("data subnets", "No default route at all. Not to NAT, not to anything. The database cannot initiate a connection to the internet, which means a compromised database cannot phone home."),
  ("S3 gateway endpoint", "A route-table entry that sends S3 traffic over AWS's network instead of through the NAT. It is free. The exit criterion asks you to replace the NAT for S3 and compare the bill."),
  ("Flow Logs", "Every accepted and rejected connection, per ENI. The lab asks you to find one rejected connection. In an incident, this is how you prove a security group is the cause."),
  ("SG versus NACL", "A security group is stateful, allow-only, and attached to the interface: the reply is allowed automatically. A NACL is stateless, ordered, allow and deny, on the subnet: you must allow the ephemeral reply ports yourself. This is the week-3 `ct state` rule, sold twice."),
  ("S3", "A bucket policy that denies any upload without server-side encryption. A presigned URL that grants one object for fifteen minutes. A lifecycle rule to Infrequent Access at 30 days and Glacier at 90. Numbers an exam asks for."),
 ],
 close="Route table decides public. NAT per AZ. Data tier with no way out. Endpoints instead of NAT where you can. And the diagram goes into the Alpha repo this Sunday.",
)

F[7] = dict(
 title="ALB to ASG to RDS, with the two numbers you measure",
 intro="The first real architecture: traffic in at the top, compute that replaces itself, a database that fails over. The week is about measuring the two recovery times, not reading about them.",
 body='''
  U["users"]:::mut
  R53["① Route 53<br/><small>alias record at the apex · health-checked</small>"]:::crit
  ALB["② Application Load Balancer<br/><small>listener rules · HTTPS · path and host routing</small>"]:::crit
  TG["③ target group<br/><small>health check every 30 s · 2 healthy, 2 unhealthy thresholds</small>"]:::crit
  subgraph ASG["④ Auto Scaling group · min 2 · desired 2 · max 6 · two AZs"]
    direction LR
    I1["instance AZ-a<br/><small>launch template · IMDSv2</small>"]:::crit
    I2["instance AZ-b<br/><small>target tracking · CPU 50 %</small>"]:::crit
  end
  M1["⑤ measurement one<br/><small>terminate an instance · time to InService · grace period 300 s</small>"]:::warn
  subgraph RDS["⑥ RDS PostgreSQL · Multi-AZ"]
    direction LR
    P["primary"]:::data
    S["standby<br/><small>synchronous · same data, other AZ</small>"]:::data
    RR["⑦ read replica<br/><small>asynchronous · scales reads · not HA</small>"]:::mut
  end
  M2["⑧ measurement two<br/><small>force failover · DNS flips · 60 to 120 s of errors, counted</small>"]:::warn
  DDB["⑨ DynamoDB<br/><small>partition key + sort key · one GSI for the second access pattern</small>"]:::data
  LAM["⑩ Lambda in a VPC<br/><small>public subnet, still no internet: no public IP, needs NAT</small>"]:::n
  U ==> R53 ==> ALB ==> TG ==> I1
  TG ==> I2
  I1 ==> P
  I2 --> P
  P --> S
  P -.-> RR
  I1 -.-> M1
  P -.-> M2
  I2 -.-> DDB
  LAM -.-> DDB
''',
 link="linkStyle 0,1,2,3,4,5 stroke:#2f6fb8,stroke-width:2px",
 minutes="three and a half",
 open="Week 7 is where architecture starts, and the point of the week is two numbers you measure yourself: how long the fleet takes to heal, and how long the database is gone during a failover. Follow the blue line, then look at the two orange boxes.",
 badges=[
  ("Route 53", "An alias record at the apex of your domain, pointing at the ALB. Alias, not CNAME, because the apex cannot hold a CNAME. Health-checked, so a dead endpoint is removed from the answer."),
  ("Application Load Balancer", "Layer 7. Listener rules route by path and host. It terminates HTTPS with an ACM certificate. Compare it to the NLB in the lab: layer 4, static IPs, millions of connections, no routing rules."),
  ("target group", "Health checks every 30 seconds. Two consecutive passes mark a target healthy, two failures mark it unhealthy. That window is the floor on how fast anything above can react."),
  ("Auto Scaling group", "Minimum two, one per AZ, maximum six. A launch template defines the instance. Target tracking at 50 percent CPU scales out under load and, the part people forget to watch, scales back in afterwards."),
  ("measurement one", "Terminate an instance on purpose. Time it from termination to the replacement reporting InService. The 300-second grace period is part of that number. Write it down. It goes in blog post 4."),
  ("RDS Multi-AZ", "A primary and a standby in another AZ, replicated synchronously. Every commit lands on both before it is acknowledged. The standby takes no reads; it exists to take over."),
  ("read replica", "Asynchronous. It scales reads and it can lag. It is not high availability. One sentence for each: Multi-AZ is for failover, a replica is for read capacity."),
  ("measurement two", "Force a failover while a loop hammers the database and timestamps every result. The DNS name flips to the standby. Count the seconds of errors. Typically 60 to 120. That is your number, and it is the honest answer to how much downtime Multi-AZ costs."),
  ("DynamoDB", "A partition key and a sort key serve the first access pattern. A global secondary index serves the second. Design the table from the queries, not from the data."),
  ("Lambda in a VPC", "A Lambda attached to a public subnet still has no internet, because its interface has no public IP. It needs a NAT, like any private instance. This is a favourite exam trap and the week-6 route-table lesson again."),
 ],
 close="Traffic in, fleet that heals, database that fails over. Two measured numbers in your own words beat any diagram you copied, and both go into Project Alpha's README.",
)

F[8] = dict(
 title="Decouple, encrypt, observe, and know what it costs",
 intro="Three short paths rather than one: a queue that absorbs load, a key that can say no, and an alarm that you force to fire. The DR strategies are the table under the figure.",
 body='''
  subgraph Q["Decoupling"]
    direction LR
    API["① producer<br/><small>API or event</small>"]:::crit
    SQS["② SQS queue<br/><small>visibility timeout 30 s · at-least-once · BF-31</small>"]:::crit
    LAM["③ consumer Lambda<br/><small>idempotent · deletes on success</small>"]:::crit
    DLQ["④ dead-letter queue<br/><small>after maxReceiveCount · the poison pill lands here</small>"]:::warn
  end
  subgraph K["Keys and secrets"]
    direction LR
    KMS["⑤ KMS customer-managed key<br/><small>key policy is the root of trust · deny beats full S3 access</small>"]:::warn
    SEC["⑥ Secrets Manager · Parameter Store<br/><small>rotation · versions · IAM-scoped reads</small>"]:::data
  end
  subgraph O["Observability"]
    direction LR
    CW["⑦ CloudWatch metric → alarm<br/><small>forced with set-alarm-state</small>"]:::crit
    SNS["⑧ SNS → email<br/><small>an untested alarm is decoration</small>"]:::crit
    CT["⑨ CloudTrail → Logs Insights<br/><small>who did what · all 5xx in the last hour</small>"]:::data
  end
  CF["⑩ CloudFront + OAC<br/><small>serves a private bucket · the bucket allows the distribution only</small>"]:::n
  ORG["⑪ Organizations SCP<br/><small>a ceiling on every account below it</small>"]:::n
  API ==> SQS ==> LAM
  SQS --> DLQ
  CW ==> SNS
  LAM -.-> KMS
  LAM -.-> SEC
  LAM -.-> CT
  CF -.-> KMS
  ORG -.-> API
''',
 link="linkStyle 0,1,3 stroke:#2f6fb8,stroke-width:2px",
 minutes="four",
 open="The last of the SAA surface area, and the services you will touch every day afterwards. Three small stories: a queue that protects a consumer, a key that can refuse an administrator, and an alarm you do not trust until you have forced it to fire.",
 badges=[
  ("producer", "Anything that emits work: an API, an event, a schedule. It writes to the queue and returns immediately. It never waits on the consumer."),
  ("SQS queue", "Messages are delivered at least once. When a consumer reads one, it becomes invisible for the visibility timeout, 30 seconds by default. If the consumer takes longer and does not extend it, the message reappears and is processed twice. That is BF-31, and you reproduce it on purpose."),
  ("consumer Lambda", "Because delivery is at-least-once, the consumer must be idempotent: doing the work twice must be safe. It deletes the message only after success."),
  ("dead-letter queue", "A message that fails maxReceiveCount times moves here instead of blocking the queue forever. Send a poison pill and watch it land. Without a DLQ, one bad message can stall everything behind it."),
  ("KMS customer-managed key", "The key policy, not IAM, is the root of trust for a key. The lab gives a principal full S3 access and then denies it in the key policy. The object reads fail. That is the demonstration that encryption is an access control, not just a checkbox."),
  ("Secrets Manager and Parameter Store", "Secrets Manager rotates and costs per secret. Parameter Store is cheaper and fine for configuration. Either way, the application reads at runtime with an IAM-scoped call and nothing lives in an environment file."),
  ("CloudWatch alarm", "A metric crosses a threshold for N periods and the alarm changes state. Force the state with `set-alarm-state` and watch the notification arrive. If you have not forced it, you do not know it works."),
  ("SNS to email", "The alarm publishes to a topic; the topic fans out to email, SMS, Lambda, or a queue. Confirm the subscription or nothing arrives."),
  ("CloudTrail and Logs Insights", "CloudTrail is who did what, to which resource, from where. Logs Insights is a query language over log groups. The exit criterion is one query: all 5xx in the last hour."),
  ("CloudFront with OAC", "A distribution in front of a private bucket. Origin Access Control signs the requests, and the bucket policy allows that distribution and nobody else. The bucket stays private and the content is public."),
  ("Organizations SCP", "A service control policy is a ceiling applied to every account under an OU. It grants nothing; it only removes. Deny leaving the organization, deny disabling CloudTrail, deny regions you do not use."),
 ],
 close="Four disaster-recovery strategies finish the week, and the one-line version is this: backup and restore is hours and cheap, pilot light is tens of minutes, warm standby is minutes, multi-site is seconds and costs double. RTO and RPO are what you are buying.",
)

F[9] = dict(
 title="The consolidation loop that produces an 80 percent",
 intro="One week of exam prep, capped by design. The figure is the loop: take an exam cold, find the two weakest domains, rebuild them by hand, and test again. The gate is the number at the end.",
 body='''
  E1["① practice exam 1, cold<br/><small>Monday · 4 h · score it honestly</small>"]:::crit
  CAT["② categorize every miss<br/><small>by SAA domain · a miss you guessed right is still a miss</small>"]:::crit
  WK["③ the two weakest domains<br/><small>only two · remediation, not re-reading</small>"]:::crit
  RB["④ rebuild by hand<br/><small>the services from weeks 5 to 8, from blank</small>"]:::crit
  AN["⑤ Anki cards<br/><small>one card per miss · reviewed daily</small>"]:::data
  E2["⑥ practice exam 2<br/><small>Thursday · review every question, including the ones you got right</small>"]:::crit
  E3["⑦ practice exam 3 + sweep<br/><small>comparison pairs · service limits · the commonly-confused list, twice</small>"]:::n
  WB["⑧ whiteboard from memory<br/><small>the 3-tier architecture · out loud · justify every choice</small>"]:::crit
  GATE["⑨ ★ Gate 2<br/><small>80 %+ on two different full-length exams</small>"]:::warn
  SUN["⑩ Sunday: rest<br/><small>no cramming · the rule, not a suggestion</small>"]:::mut
  BK["⑪ book the exam<br/><small>week 10, Tuesday · a date makes it real</small>"]:::n
  E1 ==> CAT ==> WK ==> RB ==> E2 ==> WB ==> GATE
  CAT --> AN
  E2 --> E3 --> WB
  GATE -.-> BK
  GATE -.-> SUN
''',
 link="linkStyle 0,1,2,3,4,5 stroke:#2f6fb8,stroke-width:2px",
 minutes="three",
 open="This is the only week where exam prep is allowed to dominate, and it is one week on purpose. The picture is a loop, not a reading list: measure, find the two weak spots, rebuild them with your hands, measure again.",
 badges=[
  ("practice exam 1, cold", "Monday morning, no review first. The point is a true baseline. Score it, and write the score down before you rationalize it."),
  ("categorize every miss", "Every wrong answer goes into a domain bucket. So does every right answer you were not sure of. A guess that landed is a gap you have not seen yet."),
  ("the two weakest domains", "Two, not five. Remediation spread across everything is re-reading, and re-reading feels like progress without being any."),
  ("rebuild by hand", "For those two domains, build the services again from a blank console or CLI, the way you did in weeks 5 to 8. The exam asks what a thing is for; building it is how you remember."),
  ("Anki cards", "One card per miss, in your own words, reviewed every day for the rest of the program. The exam is in nine days; the cards outlast it."),
  ("practice exam 2", "Thursday. Different provider from Monday if you can. Review every question, including the ones you got right, because the explanation is where the comparisons live."),
  ("practice exam 3 and the sweep", "Friday: a third exam plus the comparison pairs and the service limits. The commonly-confused-services guide is read twice this week because the exam is built from it."),
  ("whiteboard from memory", "Saturday: draw the month-2 three-tier architecture with nothing open, out loud, and say why each choice is there. This is what the exam measures underneath the multiple choice."),
  ("Gate 2", "Eighty percent or better on two different full-length exams. Not one. If you are under, move the exam; a two-week slip costs less than a failed attempt."),
  ("Sunday rest", "No cramming. Fatigue costs more points than one more practice exam gains. The rule is written down because everyone breaks it."),
  ("book the exam", "A booked date is what turns prep into a deadline. Week 10, Tuesday."),
 ],
 close="Measure, narrow, rebuild, measure again. Then one more week and back to building, because certification that displaces building is how this whole program fails.",
)
