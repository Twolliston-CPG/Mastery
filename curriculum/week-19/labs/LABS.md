# Week 19 Labs

> **Figures:** one numbered mechanism figure per lab, with the spoken script, the numbers to own and
> the command that proves each badge, in [`FIGURES.md`](FIGURES.md) (19.2 to 19.6). Read a lab's figure
> before you start it; redraw it after.

---

# Lab 1 — Policy as Code for Terraform (3h)

## Conftest + Rego against a plan

```bash
cd ~/alpha-cloud-foundation/environments/dev
terraform plan -out=tf.plan
terraform show -json tf.plan > plan.json
conftest test --policy ../../policies/conftest plan.json
```

```rego
# policies/conftest/s3.rego
package main

import future.keywords.contains
import future.keywords.if
import future.keywords.in

deny contains msg if {
	resource := input.resource_changes[_]
	resource.type == "aws_s3_bucket_public_access_block"
	not resource.change.after.block_public_acls
	msg := sprintf("%s: block_public_acls must be true", [resource.address])
}

deny contains msg if {
	resource := input.resource_changes[_]
	resource.type == "aws_db_instance"
	not resource.change.after.storage_encrypted
	msg := sprintf("%s: RDS storage must be encrypted", [resource.address])
}

deny contains msg if {
	resource := input.resource_changes[_]
	resource.type == "aws_security_group_rule"
	resource.change.after.type == "ingress"
	"0.0.0.0/0" in resource.change.after.cidr_blocks
	resource.change.after.from_port == 22
	msg := sprintf("%s: SSH open to the internet", [resource.address])
}

# Warnings do not fail the build. Use them for things you want visible
# but are not ready to enforce -- the audit-mode idea, applied to Terraform.
warn contains msg if {
	resource := input.resource_changes[_]
	resource.type == "aws_instance"
	not resource.change.after.tags.Owner
	msg := sprintf("%s: missing Owner tag", [resource.address])
}
```

**Tasks:**
1. Write five policies: no public S3, RDS encrypted, no SSH from `0.0.0.0/0`, required tags,
   no unencrypted EBS
2. Deliberately violate each and confirm the policy catches it
3. Write a **unit test** for a policy:
   ```rego
   # s3_test.rego
   test_denies_public_bucket if {
       count(deny) == 1 with input as {"resource_changes": [{
           "address": "aws_s3_bucket_public_access_block.x",
           "type": "aws_s3_bucket_public_access_block",
           "change": {"after": {"block_public_acls": false}}}]}
   }
   ```
   ```bash
   conftest verify --policy policies/conftest
   ```
4. Wire it into the Alpha pipeline between `plan` and `apply`

**Testing your policies is the part people skip.** A policy with a typo in its condition silently
allows everything — same lesson as `expect_failures` in week 11.

## Conftest vs checkov

| | Conftest/OPA | checkov |
|---|---|---|
| Rules | **You write them** in Rego | 1,000+ built in |
| Custom org rules | Natural | Possible, more awkward |
| Learning curve | Rego is genuinely strange at first | None |
| Coverage | Only what you write | Broad, immediately |

**Use both.** checkov for the industry baseline you'd never write yourself; Conftest for
organization-specific rules ("every resource must have an `Owner` tag matching a team in
`teams.yaml`"). That combination is the real-world answer.

---

# Lab 2 — Kyverno and Pod Security Standards (3h)

## Pod Security Standards — the built-in baseline

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: shop
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: latest
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/audit: restricted
```

| Profile | Blocks |
|---|---|
| `privileged` | Nothing |
| `baseline` | Privileged containers, host namespaces, hostPath, most capabilities |
| **`restricted`** | All of baseline **plus**: must run non-root, drop ALL capabilities, seccomp RuntimeDefault, no privilege escalation, restricted volume types |

**The rollout pattern:** set `warn` and `audit` to `restricted` **first**, leave `enforce` unset or
at `baseline`, observe for a week, then enforce. That gives you the list of things that will break
*before* they break.

```bash
kubectl label ns shop pod-security.kubernetes.io/warn=restricted --overwrite
kubectl apply -f a-privileged-pod.yaml     # WARNING printed, pod still created
kubectl label ns shop pod-security.kubernetes.io/enforce=restricted --overwrite
kubectl apply -f a-privileged-pod.yaml     # REJECTED
```

## Kyverno — for what PSS doesn't cover

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-resource-limits
spec:
  validationFailureAction: Audit          # START HERE. Always.
  background: true
  rules:
    - name: require-limits
      match:
        any: [{ resources: { kinds: [Pod] } }]
      exclude:
        any:
          - resources:
              namespaces: [kube-system, kyverno, projectcontour, monitoring, argocd]
      validate:
        message: "CPU and memory limits are required. See docs/runbooks/resource-limits.md"
        pattern:
          spec:
            containers:
              - resources:
                  limits:
                    memory: "?*"
                    cpu: "?*"
```

**Tasks — write all five:**
1. Require resource limits
2. Disallow the `:latest` tag
3. Require images from your registry only
4. Require `app.kubernetes.io/owner` and `team` labels
5. **Mutate**: automatically add a default `securityContext` rather than rejecting

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: add-default-securitycontext
spec:
  rules:
    - name: add-default-securitycontext
      match: { any: [{ resources: { kinds: [Pod] } }] }
      mutate:
        patchStrategicMerge:
          spec:
            securityContext:
              +(runAsNonRoot): true
              +(seccompProfile):
                type: RuntimeDefault
```

**Mutation over validation where you can.** Rejecting a deployment makes the platform an obstacle;
silently applying a safe default makes it a service. That distinction is the whole of platform
engineering in miniature, and it's a strong thing to say in a week-22 context too.

## BF-52 — lock yourself out, then recover

Apply `require-resource-limits` in **Enforce** mode with **no exclusions**, cluster-wide.
Watch everything break, including `kube-system`. Then recover:

```bash
kubectl get events -A --field-selector reason=PolicyViolation
kubectl patch clusterpolicy require-resource-limits --type merge \
  -p '{"spec":{"validationFailureAction":"Audit"}}'
```

**Do this deliberately.** It becomes blog post #10 and one of your best STAR stories — self-inflicted,
technically interesting, with a concrete and transferable lesson.

## The `failurePolicy` question

```yaml
spec:
  failurePolicy: Ignore     # vs Fail
```
A webhook with `failurePolicy: Fail` that becomes **unavailable** blocks **every API write in the
cluster**. Your security control has caused a total outage.

`Ignore` means a Kyverno outage silently allows unverified deployments. **Neither is obviously
right** — it's a genuine availability-vs-assurance tradeoff, and being able to articulate both sides
is better than picking one and asserting it. In practice: `Ignore` with high-availability Kyverno and
monitoring on the webhook's health, or `Fail` with a scoped `namespaceSelector` so the blast radius
is bounded.

---

# Lab 3 — NetworkPolicies (2h)

> **kind's default CNI does not enforce NetworkPolicies.** Use `kind create cluster --config` with
> `disableDefaultCNI: true` and install Calico or Cilium, or do this lab on EKS. Otherwise your
> policy applies cleanly and does **absolutely nothing** — silently. (That's BF-54's second half and
> a genuinely nasty real-world trap.)

## Default deny, and the DNS trap

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: default-deny, namespace: shop }
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
```
Apply this and **everything breaks** — including DNS, because CoreDNS is in `kube-system` on port 53.
Every name lookup fails, so every connection fails, and the symptom looks like "the network is
broken" rather than "I wrote a policy."

```yaml
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: allow-dns, namespace: shop }
spec:
  podSelector: {}
  policyTypes: [Egress]
  egress:
    - to:
        - namespaceSelector:
            matchLabels: { kubernetes.io/metadata.name: kube-system }
          podSelector:
            matchLabels: { k8s-app: kube-dns }
      ports:
        - { protocol: UDP, port: 53 }
        - { protocol: TCP, port: 53 }
```

**Always ship default-deny and allow-dns together.** Treat them as one change.

## Tasks
1. Apply default-deny; observe everything break; diagnose with a netshoot pod
2. Add `allow-dns`; observe DNS recover but application traffic still blocked
3. Allow ingress to the app from the ingress controller's namespace only
4. Allow egress from the app to the database on 5432 only
5. **Demonstrate a blocked flow** — capture it for `evidence/`
6. Confirm a pod in another namespace cannot reach the database

```bash
kubectl -n shop run netshoot --rm -it --image=nicolaka/netshoot -- \
  sh -c 'nslookup db; nc -zv db 5432; nc -zv google.com 443'
```

**Two facts to internalize:** NetworkPolicies are **additive allow-lists** — there is no deny rule,
you deny by not allowing. And they require a CNI that enforces them: **Calico and Cilium do, Flannel
does not.**

---

# Lab 4 — Secrets and Runtime Detection (3h)

## External Secrets (recap from week 16, now as a control)

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata: { name: db-credentials, namespace: shop }
spec:
  refreshInterval: 1h
  secretStoreRef: { name: aws, kind: SecretStore }
  target: { name: db-credentials, creationPolicy: Owner }
  dataFrom:
    - extract: { key: rds!db-abc123 }
```

**Tasks:** rotate the secret in Secrets Manager and watch ESO update the Kubernetes Secret. Then
confirm that a pod with the secret mounted **as a file** sees the new value without a restart, while
one using it as an **env var** does not.

## Falco

```bash
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm install falco falcosecurity/falco -n falco --create-namespace \
  --set driver.kind=modern_ebpf \
  --set tty=true

# trigger a detection
kubectl -n shop exec -it deploy/app -- sh
kubectl -n falco logs -l app.kubernetes.io/name=falco --tail=20
```

## BF-55 — the alert storm

```bash
kubectl -n falco logs -l app.kubernetes.io/name=falco --tail=500 | \
  jq -r '.rule' | sort | uniq -c | sort -rn | head
```
Default rules like "Terminal shell in container" fire on every legitimate `kubectl exec`, every
debug sidecar, and every CI job. Signal drowns in noise and the channel gets muted.

**Tune with exceptions, don't disable the rule:**
```yaml
customRules:
  custom-rules.yaml: |-
    - rule: Terminal shell in container
      append: true
      exceptions:
        - name: ci_debug_containers
          fields: [container.image.repository, k8s.ns.name]
          comps: [startswith, "="]
          values:
            - [ghcr.io/myorg/debug, ci]
```

**The principle that generalizes:** an alert nobody acts on is worse than no alert, because it trains
the team to ignore the channel — and then the one real alert is ignored too. Every alert needs to be
**actionable**, **owned**, and have a **runbook**. If you can't write a runbook for it, it should be
a dashboard panel. (Same lesson as BF-57, next week.)

---

# Lab 5 — Break/Fix and Compliance Mapping (2h)

## Break/Fix
**BF-52** (policy lockout) · **BF-54** (NetworkPolicy breaks DNS) · **BF-55** (Falco alert storm).

## Compliance literacy — enough vocabulary to not look blank

You do **not** need to memorize frameworks. You need to (a) know what they are, (b) map a control you
built to a requirement, and (c) not be surprised by the vocabulary.

| Framework | What it is | Where you meet it |
|---|---|---|
| **CIS Benchmarks** | Prescriptive hardening configs per technology | `kube-bench`, `checkov` defaults |
| **SOC 2** | An audited report on controls across five trust criteria | Any B2B SaaS vendor |
| **NIST 800-53** | A large US federal control catalog | Government, FedRAMP |
| **PCI-DSS** | Card data handling | Payments |
| **HIPAA** | US health information | Healthcare |

```bash
kube-bench run --targets node,policies
```

## The compliance mapping table — the actual deliverable

```markdown
| Control | Implementation | Evidence | Maps to |
|---|---|---|---|
| Encryption at rest | RDS `storage_encrypted`, KMS CMK | `terraform show` output | CIS AWS 2.3.1, SOC 2 CC6.1 |
| No public storage | Account-level Block Public Access + Conftest gate | Policy test passing | CIS AWS 2.1.5 |
| Least privilege | IRSA per workload, no node-role credentials | IAM policy JSON | NIST AC-6, SOC 2 CC6.3 |
| Change management | PR review + approval gate on apply | GitHub branch protection | SOC 2 CC8.1 |
| Vulnerability management | Trivy gate, documented expiring exceptions | `.trivyignore.yaml` + CI logs | NIST RA-5, SOC 2 CC7.1 |
| Audit logging | CloudTrail + VPC flow logs + K8s audit | Log group retention config | NIST AU-2, SOC 2 CC7.2 |
| Integrity of artifacts | cosign signing + Kyverno verification | `evidence/unsigned-rejected.png` | NIST SI-7 |
```

**Being able to produce this table is worth real money.** In a regulated environment someone spends
weeks assembling it manually. A platform engineer who generates it from the controls already in code
is solving an expensive problem — and in an interview it demonstrates that you connect technical
controls to business requirements, which very few junior candidates do.

Template: `_reference/devsecops/threat-modeling/templates-compliance-mapping-template.md`.
