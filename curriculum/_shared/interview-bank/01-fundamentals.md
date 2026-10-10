# Interview Bank: Fundamentals

---

### Q1. Walk me through what happens when you type a URL and press enter.

**Why they ask:** It is the single best breadth probe in existence. Your answer reveals how many
layers you actually understand, and they can stop you at any layer to go deep.

**Model answer (~2 min, go layer by layer):**

> The browser first checks whether it already knows the address — its own cache, then the OS cache,
> then `/etc/hosts`. If not, it asks the configured resolver. That resolver walks the hierarchy if
> needed: root servers, then the `.com` TLD servers, then the domain's authoritative nameservers,
> which return an A or AAAA record. Each response has a TTL that controls caching.
>
> With an IP, the browser opens a TCP connection — SYN, SYN-ACK, ACK. If the destination isn't on
> the local subnet, the packet goes to the default gateway, which requires an ARP lookup for the
> gateway's MAC.
>
> For HTTPS there's a TLS handshake on top: client hello with supported ciphers and the SNI
> hostname, server responds with its certificate, the client validates the chain up to a trusted
> root and checks the SAN covers the hostname, then they agree a session key.
>
> Then the actual HTTP request goes over that connection. In a real deployment it probably hits a
> CDN edge first, then a load balancer, which picks a healthy backend based on its health checks,
> and the backend may hit a cache or database before responding.
>
> The browser gets HTML, parses it, and fires more requests for CSS, JS, and images — which repeats
> this whole process, often to different hosts.

**How to handle it well:** Pause after DNS and after TLS and ask *"want me to go deeper on any of
these?"* That shows you know there's more depth and lets them steer. It also stops you rambling for
six minutes, which is the common failure.

**Follow-ups to be ready for:** What if DNS resolves but the page doesn't load? (→ routing or
firewall — prove IP connectivity with ping, then test the port with curl.) What's in the TLS
certificate? What's the difference between HTTP/1.1 and HTTP/2?

---

### Q2. A server is slow. How do you diagnose it?

**Model answer:**

> First I'd establish what "slow" means and for whom — is it one endpoint, all requests, one user?
> And what changed recently, because that resolves most incidents.
>
> Then I'd work the resource dimensions in order. `uptime` for load average relative to core count.
> `top` to separate CPU-bound from I/O wait — high load with low CPU usually means I/O wait, and
> that's a completely different investigation. `free -h` for memory, and I'd check whether it's
> swapping, because swap thrash looks like a CPU problem but isn't. `iostat -x 1` for disk latency
> and queue depth. `ss -s` and `ss -tn` for connection counts — running out of ephemeral ports or
> sitting in TIME_WAIT is a classic.
>
> If the machine looks healthy, the problem is probably downstream — a slow database query, a
> dependency timing out, or DNS. I'd check the application's own latency metrics and, if there's
> tracing, find the slow span rather than guessing.

**The detail that lands:** naming the load-average-vs-CPU% distinction. Most juniors treat load
average as a CPU metric.

---

### Q3. What's the difference between a process and a thread? And what's a container?

**Model answer:**

> A process has its own memory address space; threads share one within a process. That makes threads
> cheaper to create and to switch between, but it means they can corrupt each other's memory, which
> is why you need locking.
>
> A container isn't a kind of virtual machine — it's just a normal Linux process with restricted
> visibility. Two kernel features do the work. **Namespaces** control what the process can *see*: PID
> namespace so it thinks it's PID 1, network namespace for its own interfaces and routing table,
> mount namespace for its own filesystem view, plus UTS, IPC, and user namespaces. **cgroups**
> control what it can *use*: CPU shares, memory limits, I/O.
>
> That's why a container shares the host kernel and a VM doesn't, which is why containers start in
> milliseconds and VMs take tens of seconds — and also why container isolation is weaker, since a
> kernel vulnerability crosses the boundary.

**The payoff:** this single answer explains why images are layers, why a container exits when PID 1
exits, why `OOMKilled` happens, and why you can't run a different kernel in a container. Interviewers
notice when someone understands the mechanism rather than the metaphor.

---

### Q4. Explain the Linux permission model.

**Model answer:**

> Three classes — owner, group, other — each with read, write, execute. Octal notation: 644 is
> owner read/write, everyone else read; 755 adds execute for all, which is what you want for a
> directory or a script.
>
> The thing people miss is that on a **directory**, the bits mean something different: read lists the
> contents, write creates and deletes entries in it, and **execute means you can traverse it**. So you
> can be unable to reach a file you have full permissions on because a parent directory lacks the
> traverse bit. `namei -l` on the full path is how you see that.
>
> Beyond the basic bits there's setuid — run as the file's owner, which is how `passwd` works and
> also a classic privilege-escalation vector — setgid, and the sticky bit, which is why in `/tmp`
> you can only delete your own files.

**Follow-up they'll ask:** "Permission denied on a script you can see — what are the possibilities?"
→ (1) no execute bit, (2) no traverse on a parent directory, (3) filesystem mounted `noexec`.
Naming all three is the signal.

---

### Q5. Explain DNS. What's the difference between an A record, a CNAME, and an alias?

**Model answer:**

> DNS is a distributed hierarchical database mapping names to records. Resolution walks from root →
> TLD → authoritative nameserver, with caching at every layer governed by TTL.
>
> An **A record** maps a name to an IPv4 address (AAAA for IPv6). A **CNAME** maps a name to another
> *name*, and the resolver then has to resolve that — which costs an extra lookup and, importantly,
> **a CNAME cannot exist at the zone apex.** So you can't CNAME `example.com` itself, only
> `www.example.com`.
>
> That apex restriction is exactly why Route 53 has **alias records** — a Route 53-specific type that
> points at an AWS resource like an ALB or CloudFront distribution, works at the apex, resolves to
> the IP directly with no extra lookup, and is free to query.

**Why this question:** it separates people who have configured DNS from people who have read about
it. The apex/CNAME problem is something you only know if you've hit it.

---

### Q6. What's the difference between TCP and UDP, and when would you choose each?

**Model answer:**

> TCP is connection-oriented and reliable: three-way handshake, sequence numbers, acknowledgements,
> retransmission, ordering, flow control, and congestion control. UDP is fire-and-forget — no
> handshake, no ordering, no retransmission, much lower overhead and latency.
>
> You choose TCP when every byte must arrive in order — HTTP, SSH, databases. You choose UDP when
> late data is worthless anyway, so retransmission is pointless: DNS queries, real-time video and
> voice, and telemetry like StatsD. QUIC is interesting here because it's HTTP/3 running over UDP
> and rebuilding reliability in userspace to avoid TCP head-of-line blocking.

**Follow-up:** "Why does DNS use UDP but sometimes TCP?" → Queries are small and fit one datagram, so
UDP is faster. It falls back to TCP when the response exceeds the size limit — zone transfers and
large DNSSEC responses.

---

### Q7. Explain the difference between merge and rebase. When would you use each?

**Model answer:**

> Merge takes two branches and creates a merge commit joining them — history is preserved exactly as
> it happened, including the fact that work was parallel. Rebase replays your commits on top of a new
> base, producing linear history but **rewriting commit hashes**.
>
> I use rebase to keep a feature branch current with main while I'm working on it, and to clean up a
> messy local branch before opening a PR — squashing "fix typo" commits into something reviewable.
> I use merge to bring a finished branch into main.
>
> The rule I hold to is: **never rebase a branch other people have pulled.** Rewriting shared history
> forces everyone else into a painful recovery.

**Follow-up:** "You committed a secret and pushed. What now?" → **Rotate the credential first** — it
is compromised the moment it's pushed, and history rewriting doesn't un-leak it. Then remove it from
history with `git filter-repo` or BFG, force-push, and get every collaborator to re-clone. Then add
a `gitleaks` pre-commit hook so it can't recur. **Leading with rotation rather than history-rewriting
is what makes this answer good** — plenty of candidates describe an elaborate git surgery and never
mention that the secret is already burned.

---

### Q8. What does `set -euo pipefail` do?

**Model answer:**

> `-e` exits on any command returning non-zero. `-u` errors on an undefined variable, which catches
> typos in variable names. `-o pipefail` makes a pipeline return failure if **any** stage fails, not
> just the last one.
>
> `pipefail` is the one that matters most. Without it, `false | true` succeeds, so something like
> `generate_data | tee output.txt` reports success even when the generator crashed — and you've just
> written an empty file over good data and told the pipeline everything is fine.

**Why this is asked:** it's a one-line proxy for "do you write careful shell or dangerous shell."
