# Week 19 Solutions

Working policies: [`policies/`](policies/)

---

## Lab 1 — Conftest

### Why Rego feels strange, and the one thing to internalize

Rego is declarative and **set-oriented**: rules define what is *true*, not a procedure. `deny` is a
set — every rule body that evaluates true contributes a message.

```rego
deny contains msg if {
	resource := input.resource_changes[_]     # iterate: _ means "for all"
	resource.type == "aws_db_instance"        # filter
	not resource.change.after.storage_encrypted
	msg := sprintf("%s: unencrypted", [resource.address])
}
```
Read it as: *"`msg` is in `deny` if there exists a resource change such that all of these hold."*
The `_` is the iteration, and every expression in the body is implicitly ANDed.

To express OR, write two rules with the same name.

### `deny` vs `warn`

```rego
deny contains msg if { ... }   # exit code 1 -- blocks the pipeline
warn contains msg if { ... }   # exit code 0 -- visible, does not block
```
`warn` is the Terraform equivalent of Kyverno's Audit mode. **Ship a new policy as `warn` first**,
see how much it fires, then promote it to `deny`. The same rollout discipline applies everywhere.

### Test your policies

```bash
conftest verify --policy policies/conftest
```
A policy with a typo in its condition matches nothing and silently allows everything. That failure is
invisible — the pipeline goes green and you believe you're protected. **Testing the guardrail is the
same idea as `expect_failures` in week 11**, and it's the thing people skip.

### Conftest vs checkov — use both

checkov gives you ~1,000 rules encoding the industry baseline, immediately, for free. Conftest gives
you organization-specific rules checkov could never know: *"every resource must carry an `Owner` tag
matching a team in `teams.yaml`"*, *"no resource outside our two approved regions"*, *"production
databases must have `prevent_destroy`"*.

**The wrong answer is picking one.** The right answer is checkov for the baseline and Conftest for
your own invariants.

---

## Lab 2 — Kyverno and PSS

### PSS vs Kyverno — when each

| | Pod Security Standards | Kyverno |
|---|---|---|
| Built in | **Yes**, since 1.25 | No, install it |
| Configurable | Three fixed profiles | **Arbitrary rules** |
| Mutation | **No** | **Yes** |
| Image verification | No | **Yes** |
| Per-namespace | Yes, via labels | Yes, via match/exclude |
| Reporting | Limited | PolicyReports |

**Use PSS for the baseline** — it's free, built in, and covers the container-hardening essentials.
**Add Kyverno for everything PSS can't express:** required labels, registry restrictions, image
signature verification, and — most valuably — **mutation**.

### Mutation is the platform-engineering move

```yaml
mutate:
  patchStrategicMerge:
    spec:
      securityContext:
        +(runAsNonRoot): true          # +() means "add if absent, don't overwrite"
        +(seccompProfile):
          type: RuntimeDefault
```

Validation rejects a deployment and makes the platform an obstacle. Mutation applies a safe default
silently and makes the platform a **service**. A developer who never had to learn what
`seccompProfile` is still gets one.

**This is the single best thing to say in a week-22 platform-engineering context**, and it's a real
insight rather than a tool fact: *the platform should make the secure thing the default, not the
thing you get rejected for forgetting.*

### BF-52 — what actually happened

Applying `require-resource-limits` in Enforce mode cluster-wide with no exclusions:

```
kube-system CNI DaemonSet pod  -> rejected (no limits set on the vendor manifest)
coredns pod                     -> rejected
kyverno's own pods              -> rejected on restart
```
Nothing new can be scheduled. If the CNI pods are evicted or the node restarts, the cluster cannot
network. You have locked yourself out with a security control.

**Recovery:**
```bash
kubectl patch clusterpolicy require-resource-limits --type merge \
  -p '{"spec":{"validationFailureAction":"Audit"}}'
```
(And if Kyverno itself can't start: `kubectl delete validatingwebhookconfiguration` for its webhooks
is the break-glass, then reinstall.)

**The three rules, earned rather than memorized:**
1. **Audit mode first**, for at least a week. Read the PolicyReports.
2. **Always exclude system namespaces.**
3. **Know your `failurePolicy`.**

### `failurePolicy` — a genuine tradeoff, not a best practice

| | `Fail` | `Ignore` |
|---|---|---|
| Webhook down | **Every API write in the cluster is blocked** | Unverified workloads admitted |
| Failure mode | Total outage | Silent security gap |
| Right for | Narrowly-scoped, high-assurance policies with a `namespaceSelector` | Broad policies where availability matters more |

**The nuanced answer:** `Ignore` plus a highly-available Kyverno deployment, a PodDisruptionBudget on
it, and **monitoring on the webhook's health** — so you find out it's down rather than discovering it
months later. Or `Fail` with a tight `namespaceSelector` so the blast radius is one namespace.

Articulating both sides beats asserting one.

---

## Lab 3 — NetworkPolicies

### Why default-deny breaks everything

```yaml
spec:
  podSelector: {}                    # every pod in the namespace
  policyTypes: [Ingress, Egress]     # with no rules = deny all
```
The egress deny blocks **UDP/TCP 53 to CoreDNS in kube-system**. Every name lookup fails, so every
outbound connection fails, and the symptom presents as "the network is broken."

Diagnose with:
```bash
kubectl -n shop run netshoot --rm -it --image=nicolaka/netshoot -- \
  sh -c 'nslookup kubernetes.default; echo "---"; nc -zv 10.96.0.1 443'
```
DNS fails, direct-IP works → it's DNS, and DNS is a *network policy* problem, not a CoreDNS problem.

**Always ship `default-deny` and `allow-dns` as one change.**

### Two facts that catch people

**1. NetworkPolicies are additive allow-lists.** There is no `deny` rule. You deny by not allowing,
and multiple policies selecting the same pod are **unioned** — adding a permissive policy can't be
overridden by a restrictive one.

**2. They require an enforcing CNI.** Calico and Cilium enforce them. **Flannel does not** — and kind
ships with `kindnet`, which also does not. Your policy applies successfully, `kubectl get netpol`
shows it, and it does **absolutely nothing**. Silently.

That second one is genuinely nasty: you can build a whole "zero trust" story on a cluster where
nothing is enforced. **Always verify a policy blocks something before believing it.**

```bash
# kind with a policy-enforcing CNI
cat > kind-calico.yaml <<'YAML'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  disableDefaultCNI: true
  podSubnet: "192.168.0.0/16"
YAML
kind create cluster --config kind-calico.yaml
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/calico.yaml
```

---

## Lab 4 — Secrets and Falco

### File vs env var, demonstrated

```bash
aws secretsmanager put-secret-value --secret-id rds!db-abc --secret-string '{"password":"new"}'
# ESO refreshes within refreshInterval
kubectl -n shop exec deploy/app-file -- cat /etc/secrets/password    # NEW value
kubectl -n shop exec deploy/app-env  -- printenv DB_PASSWORD         # OLD value
```
**A mounted secret updates in place; an env var is fixed at process start.** So rotation with env
vars requires a rolling restart of every consumer — which means rotation happens rarely, which means
credentials are long-lived, which is the thing you were trying to avoid.

That chain of consequences is the real argument for file-mounted secrets, and it's more convincing
than "env vars leak into crash dumps" (though that's also true).

### Falco tuning

```bash
kubectl -n falco logs -l app.kubernetes.io/name=falco --tail=1000 | \
  jq -r '.rule' | sort | uniq -c | sort -rn
#  847 Terminal shell in container
#   23 Write below etc
#    2 Contact K8S API Server From Container
```
847 of one rule is not 847 incidents — it's one misconfigured rule. Tune it with `exceptions`, keep
the rule enabled, and the remaining 25 become readable.

**The rule that generalizes across this whole curriculum:** an alert nobody acts on is **worse** than
no alert, because it trains people to ignore the channel. Every alert must be actionable, owned, and
have a runbook. If you can't write a runbook for it, it belongs on a dashboard, not in a pager.

---

## The compliance mapping table — why it's worth more than it looks

In a regulated environment, producing evidence for an audit is a multi-week manual exercise: someone
screenshots console pages, exports IAM policies, and writes a narrative connecting them to control
requirements. Every year.

If your controls are **in code**, the evidence is generatable:

```bash
# every control, with its evidence, from the source of truth
terraform show -json | jq '[.values.root_module.resources[]
  | select(.type=="aws_db_instance")
  | {addr: .address, encrypted: .values.storage_encrypted}]'

kubectl get clusterpolicy -o json | jq -r '.items[]
  | "\(.metadata.name)\t\(.spec.validationFailureAction)"'
```

**"I can generate the audit evidence from the same code that enforces the control"** is a genuinely
valuable thing to be able to say, and almost no junior candidate says it. It also connects the whole
month: threat model → control → policy as code → evidence → compliance mapping is one chain, not five
tools.
