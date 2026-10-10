# Week 19 Assessment

> Closed book, 30 min.

## Part A (20 min)
1. Why does policy beat scanning? State the shift in one sentence.
2. Conftest/OPA vs checkov — what does each give you, and why use both?
3. `deny` vs `warn` in Rego — and what's the rollout discipline?
4. Why test your policies, and what's the failure mode if you don't?
5. Name the three Pod Security Standard profiles and what `restricted` adds over `baseline`.
6. How do you roll out PSS safely? Which labels, in what order?
7. When do you need Kyverno rather than PSS? Give three cases.
8. Why is **mutation** better than validation where it's possible?
9. State the three rules for rolling out an admission policy.
10. `failurePolicy: Fail` vs `Ignore` — state **both** sides of the tradeoff.
11. Why does a default-deny NetworkPolicy break everything, and what must ship with it?
12. Are NetworkPolicies allow-lists or deny-lists? What happens with two overlapping policies?
13. Which CNIs enforce NetworkPolicies? What happens with one that doesn't?
14. Secret as a file vs an env var — trace the consequence chain for **rotation**.
15. Falco is producing 847 alerts of one rule. What do you do, and what's the general principle?

## Part B — Write it (10 min)
16. A Rego `deny` rule failing any unencrypted `aws_db_instance`
17. A Rego test asserting that rule fires
18. A Kyverno policy requiring resource limits, in the **safe** initial mode, excluding system namespaces
19. A Kyverno **mutation** adding `runAsNonRoot` only when absent
20. A default-deny NetworkPolicy **and** the DNS allowance
21. The namespace labels enabling PSS `restricted` in warn-only mode

---

# Answer key

**A1.** Scanning **detects** insecure things after they exist; policy **prevents** them being created.
The shift is from *"we find insecure deployments"* to *"insecure deployments cannot happen."*

**A2.** **checkov** gives ~1,000 rules encoding the industry baseline immediately and free.
**Conftest/OPA** lets you write organization-specific invariants checkov could never know — required
tags matching a team roster, approved regions only, `prevent_destroy` on production databases.
Use both: checkov for the baseline, Conftest for your own rules.

**A3.** `deny` exits non-zero and blocks the pipeline; `warn` is visible and does not. **Ship every
new policy as `warn` first**, measure how much it fires, then promote to `deny`. Same discipline as
Kyverno's Audit mode.

**A4.** A policy with a typo in its condition matches nothing and **silently allows everything** —
the pipeline goes green and you believe you are protected. `conftest verify` with tests asserting the
rule *fires* on a violation is the only way to know. (Same idea as `expect_failures` in week 11.)

**A5.** `privileged` (no restrictions), `baseline` (blocks privileged containers, host namespaces,
hostPath, most capabilities), **`restricted`** (baseline **plus** must run non-root, drop ALL
capabilities, seccomp RuntimeDefault, no privilege escalation, restricted volume types).

**A6.** Set `pod-security.kubernetes.io/warn` and `/audit` to `restricted` **first**, leave `enforce`
unset or at `baseline`. Observe for a week. Then set `/enforce`. That gives you the list of things
that will break *before* they break.

**A7.** (1) **Image signature verification** (`verifyImages`). (2) **Mutation** — PSS can only
reject. (3) Organization-specific rules: required labels, registry allow-lists, naming conventions.

**A8.** Validation rejects a deployment and makes the platform an **obstacle**; mutation applies a
safe default silently and makes it a **service**. A developer who has never heard of
`seccompProfile` still gets one. *The platform should make the secure thing the default, not the
thing you get rejected for forgetting.*

**A9.** (1) **Audit mode first**, for at least a week; read the PolicyReports. (2) **Always exclude
system namespaces** — otherwise you break the CNI and lock yourself out. (3) **Know your
`failurePolicy`**.

**A10.** **`Fail`:** a webhook outage blocks **every API write in the cluster** — your security
control has caused a total outage. **`Ignore`:** a webhook outage silently admits unverified
workloads — a silent security gap. Neither is obviously right. In practice: `Ignore` plus an HA
Kyverno deployment, a PDB, and **monitoring on webhook health**; or `Fail` with a tight
`namespaceSelector` so the blast radius is bounded.

**A11.** The egress deny blocks **UDP/TCP 53 to CoreDNS in kube-system**, so every name lookup fails
and therefore every connection fails — presenting as "the network is broken." **Ship `default-deny`
and `allow-dns` as one change.**

**A12.** **Allow-lists.** There is no deny rule — you deny by not allowing. Multiple policies
selecting the same pod are **unioned**, so a permissive policy cannot be overridden by adding a
restrictive one.

**A13.** **Calico and Cilium enforce them. Flannel does not, and kind's default `kindnet` does not.**
With a non-enforcing CNI the policy applies successfully, `kubectl get netpol` shows it, and it does
**absolutely nothing — silently.** Always verify a policy actually blocks something before believing
it.

**A14.** A mounted file updates **in place** when the Secret changes; an env var is fixed at process
start. So with env vars, rotation requires a rolling restart of every consumer → rotation is
operationally expensive → it happens rarely → credentials are long-lived → which is the risk you were
trying to reduce. (Also: env vars appear in `/proc/<pid>/environ`, are inherited by child processes,
and show up in crash dumps.)

**A15.** **Tune with `exceptions`, don't disable the rule.** 847 of one rule is one misconfigured
rule, not 847 incidents. **The general principle:** an alert nobody acts on is *worse* than no alert,
because it trains the team to ignore the channel — and then the one real alert is ignored too. Every
alert must be actionable, owned, and have a runbook; if you can't write a runbook for it, it belongs
on a dashboard.

---

**B16–B21:** see [`solutions/policies/`](solutions/policies/) —
`conftest-terraform.rego`, `conftest-terraform_test.rego`, `kyverno-baseline.yaml`,
`networkpolicies.yaml`. The tests pass with `conftest verify --policy solutions/policies`.

**B21.**
```yaml
metadata:
  labels:
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/audit: restricted
    # enforce deliberately omitted -- add it after a week of clean reports
```

## Scoring
| | |
|---|---|
| 17–21 | Move on. |
| 13–16 | Review Labs 2 and 3. Admission control and NetworkPolicies are the two most-probed DevSecOps topics. |
| < 13 | Redo the week. **This month is your differentiator** — the depth is worth the extra days. |

**And: did you actually lock yourself out in BF-52?** Do it. It's blog post #10 and one of your best
STAR stories.
