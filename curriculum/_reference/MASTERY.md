# Mastery

Reading is input. Mastery is output. This file is the forcing function.

**On the 70/30 rule.** Elsewhere the split is 70% hands-on, 30% reading, and it holds. Here it is
relaxed — not because reading suddenly works, but because **every file in this library now ends with
a Feynman check.** Reading a page and then closing it and explaining it from a blank page is not
reading; it is retrieval practice with a reading step attached. The 70/30 rule exists to stop passive
input. A file that ends by demanding output is no longer passive input.

The relaxation has one condition: **you do the check.** Skip it and you are back to re-reading, which
is the single most convincing way to feel ready and not be.

---

## The three levels of knowing

Most people stop at level 1 and cannot tell, because level 1 *feels* like understanding.

| Level | You can say | Interview result |
|---|---|---|
| **1 — Name** | *"Kubernetes schedules the pod."* | You are eliminated in round one |
| **2 — Mechanism** | *"The scheduler filters nodes by predicates, scores what survives, and writes `nodeName` into the pod spec. The kubelet on that node is watching for it."* | You pass the screen |
| **3 — Failure** | *"…and if no node passes the filter the pod sits `Pending` with an event naming the predicate that failed — which is how you tell insufficient CPU apart from a taint."* | You get the offer |

**Level 3 is the target.** The reference library gets you to 2. Break/fix and the drill below get you
to 3.

The gap between 1 and 2 is always the same thing: **a word standing in for a mechanism.** "Schedules",
"handles", "manages", "takes care of". Every one of those is a place you stopped.

---

## The Feynman loop

Four steps. Twenty minutes. Do it for one idea, not five.

### 1. Write the name on a blank page
No notes. No tabs open. If you need the notes to start, you are not ready to test — you are ready to
read, which is a different activity.

### 2. Explain it to a specific person
Not "explain it simply" — that is too vague to act on. Explain it to **a competent engineer who has
never used this tool.** They know what a process and a TCP connection are. They have never seen
Kubernetes. They will interrupt.

Constraints that make it work:
- **Under five minutes**, written or out loud
- **No jargon you cannot define on the spot.** You may say "control loop" only if you would survive
  *"what's a control loop?"*
- **Say what happens, in order, naming what does it**

### 3. Mark the gaps — and know what a gap looks like
The gap is **not** what you left out. It is where you used a word instead of a mechanism.

Mark every place you:
- reached for a term to skip past something (*"it handles service discovery"*)
- said "basically", "it just", "somehow", "under the hood"
- got vague exactly when it got interesting
- could not answer the imagined interruption

Those marks are your reading list. **They are the only reason to open the reference library.**

### 4. Go back for those spots only — then rewrite
Read the specific section. Close it. Rewrite the explanation from memory.

Then add an analogy — and immediately **find where the analogy breaks.** That boundary is the real
content. *"A pod is like a tiny VM"* is useful for thirty seconds and then actively wrong, and being
able to say exactly why is the difference between levels 2 and 3.

### Loop until boring
You are done with an idea when explaining it is boring. Boredom is the signal, not confidence —
confidence arrives much earlier and means nothing.

---

## The trace drill — for understanding implementations

The Feynman loop tests concepts. This tests **mechanism**, which is what "understand the
implementation" actually means.

**Pick one. Trace what happens, step by step, naming every component that acts. Stop at the first
thing you cannot name. That is today's reading — and only that.**

1. `kubectl apply -f pod.yaml` → a container running on a node
2. `terraform apply` → a cloud API call → a resource → a line in state
3. `curl https://example.com` → bytes on your terminal
4. `git push` → a pod running the new image, with nothing else typed
5. A metric crosses a threshold → a phone rings
6. A request arrives at a pod IP from a pod on a **different node**
7. `docker run` → an isolated process *(which namespaces, in what order, and who calls `clone`)*
8. An IAM request → allow or deny *(the full evaluation order, including the SCP)*
9. A TLS handshake → an encrypted session *(1.3, and why it is one round trip and 1.2 was two)*
10. A rotation schedule fires → an application using a new database password, with no restart

**A trace is finished when every arrow has a subject.** If any step is "and then it gets deployed",
you have found the gap, not the end.

---

## A worked example, end to end

The topic: **why a Kubernetes Service has no logs.**

### Attempt 1 — what most people write

> *A Service gives your pods a stable IP and load-balances traffic to them. kube-proxy handles it.*

Three words are doing all the work and none of them is a mechanism: **gives**, **load-balances**,
**handles**. Ask *"handles it how?"* and there is nothing underneath. This is level 1, and it reads as
competent right up until someone asks a second question.

### Attempt 2 — after marking the gaps

The gaps were: *what is the IP attached to?*, *who writes the rules?*, *where does balancing happen?*
Reading only those:

> *A Service gets a virtual IP from the service CIDR, and that IP is not assigned to any interface —
> nothing owns it. The endpoints controller watches pods matching the selector and maintains an
> EndpointSlice. kube-proxy on **every** node watches those slices and programs iptables or IPVS rules
> locally. When a pod sends a packet to the virtual IP, the rule on **that node** rewrites the
> destination to one of the pod IPs before the packet leaves.*

Level 2. Every arrow has a subject.

### Attempt 3 — the failure mode makes it level 3

> *…which is why a Service has no logs and you cannot ping it: there is no process in the path. The
> balancing is a packet-rewrite on the client's own node. So when a Service "isn't working", the
> first command is `kubectl get endpoints` — an empty list means the selector matches nothing, and
> that is a label typo, not a networking problem.*

That last paragraph is what separates someone who has used Kubernetes from someone who understands
it. It is also the answer that ends the interview question.

### What the loop actually cost
Twenty minutes, three passes, and roughly two pages of reference material — read *after* the first
attempt, not before. Reading those two pages first would have produced attempt 1 with more vocabulary
in it.

---

## Three more, compressed

Same shape every time: a word → a mechanism → the failure that proves you own it.

| | ✗ Level 1 | ✓ Level 2 + 3 |
|---|---|---|
| **Terraform state** | *"State tracks your infrastructure."* | *"`plan` compares three things — config, state, and a refresh of the real API. State is Terraform's belief about what it created. So `terraform import` writes belief without changing reality, and a resource deleted in the console shows as a **create**, not a no-op, because reality and belief disagree."* |
| **Container isolation** | *"Containers are isolated from the host."* | *"A container is a process with namespaces, cgroups and seccomp switched on. There is no container object in the kernel. So a process that escapes its namespace is just a process on the host — which is why `privileged: true` is not 'more access', it is **no boundary at all**."* |
| **Error budget** | *"An SLO defines your reliability target."* | *"An SLO of 99.9% over 30 days is 43 minutes of allowed failure — that is the budget. Burn rate is how fast you are spending it; a 14.4× burn over an hour exhausts a month's budget in that hour, which is why fast-burn and slow-burn alerts need different windows. When the budget is gone, feature work stops. A target with no consequence attached is a number, not an objective."* |

---

## The three questions that find any gap

When you get stuck mid-explanation, one of these always applies:

1. **"What actually does that?"** — turns a verb into a component
2. **"What does it write, and where?"** — turns a component into state you can inspect
3. **"What happens when it doesn't?"** — turns knowledge into the answer that gets hired

---

## What you must be able to explain, per domain

Blank page, five minutes, no notes. If you cannot, that domain is not done — whatever the week
number says.

| Domain | Explain on a blank page |
|---|---|
| **Linux** | What a process *is* · why `D` state cannot be killed · what a directory actually contains · why `available` matters and `free` does not · what `x` means on a directory |
| **Networking** | Why an IP without a mask tells you nothing · what a Service IP is attached to *(nothing)* · why DROP and REJECT debug differently · what a trust boundary is |
| **AWS** | What makes a subnet public · Multi-AZ vs read replica · when the answer is a customer-managed key · what IMDSv2 changed and what attack it closed |
| **Terraform** | Why a plan is a **three-way** comparison · what is in state that is not in your config · `count` vs `for_each`, and why the difference only shows up on deletion · when `moved` beats `state mv` |
| **Containers** | Which kernel features make a container · why two containers in a pod cannot bind the same port · why `CrashLoopBackOff` is a *waiting* state |
| **Kubernetes** | What a controller does, in a sentence containing the word "loop" · why a StatefulSet exists · what admission control runs *before* · why `kubectl get endpoints` is the first debug command |
| **CI/CD** | Why the plan belongs on the pull request · why push and pull models differ in **credentials**, not convenience · why you re-tag an image instead of rebuilding it |
| **DevSecOps** | Why `restricted` closes three branches of an escape tree at once · what an SBOM answers that a scanner cannot · why secret detection is the one control that cannot be applied retroactively |
| **Observability** | Why you never alert on a mean · what cardinality costs · what an exemplar links · why multi-window burn rate beats a static threshold |
| **Platform** | Why a golden path needs an escape hatch · what cognitive load means operationally · why adoption bends at the early-majority gap |

---

## What does not work

Named plainly, because all three feel productive:

| | Why it fails |
|---|---|
| **Re-reading** | Maximises *familiarity*, which the brain reports as understanding. It is the single most common way to feel ready and not be |
| **Highlighting** | Defers the thinking. You are marking what you would have to understand later, and later never comes |
| **Watching** | Someone else does the retrieval. You get their fluency, not yours |

All three share one property: **no output.** If an hour of study produced nothing you could hand to
someone — a page, a diagram, a working lab, a failed command you then fixed — it was input, and input
is the cheap half.

---

## The weekly rhythm

| | |
|---|---|
| **Daily, 20 min** | One Feynman page. One idea. Pick the thing you were vaguest about yesterday |
| **Daily, 10 min** | One trace, until you hit a gap. Read only that |
| **Weekly** | Re-explain last week's page **without looking at it.** What survived is yours |
| **Weekly** | One break/fix scenario, timed. Diagnose before you fix |
| **Before a gate** | Explain the week's three hardest ideas out loud, recorded. Listen back. You will hear every "basically" |

**A ready-made scaffold exists** for one domain — see
[`terraform/drills/feynman-README.md`](terraform/drills/feynman-README.md): a tracker, teach-back
templates, an analogies file, and a dated gaps log. Copy that layout for any domain you are serious
about.

Keep the pages. A folder of them at week 26 is the most honest record of what you actually know — and
re-reading your own week-3 explanation is the fastest way to see how far you have come.

---

## When this library runs out

It will. A reference library is a summary, and a summary has already discarded the edge case you are
about to hit. [**`SOURCES.md`**](SOURCES.md) has the primary sources per domain — the specs, the
free books, the code — with a line on *when* to open each one.

The order matters and it is the opposite of intuition:

1. **Attempt the explanation first.** Sources read before an attempt just give you better vocabulary
   for the same level-1 answer
2. **Name the gap**
3. **Open the source at that section only**
4. **Close it and explain from memory**

If you skip step 1, a primary source is just re-reading with more prestige attached.
