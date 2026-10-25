# Week 19 Labs

> **Figures:** one numbered mechanism figure per lab, with the spoken script, the numbers to own and
> the command that proves each badge, in [`FIGURES.md`](FIGURES.md) (19.2 to 19.6; 19.7 for the "Go deeper" lab at the end). Read a lab's figure
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

---

# Go deeper — OPA as a decision engine (3h · ladder: policy as code, rung 3 and 4)

Optional inside this week, mandatory for the ladder ([`../../../KUBERNETES-MASTERY.md`](../../../KUBERNETES-MASTERY.md)).
Lab 1 used OPA the way most people meet it: Conftest reads a plan, a `deny` rule prints a line, the
build goes red. That is one input shape of one engine. This lab takes the engine out of the pipeline:
what a Rego rule actually computes, where policy and data part ways, how a policy reaches a running
OPA without a redeploy, and OPA deciding every HTTP request of the week-20 app. Every Rego block
below was run with `conftest verify` and `conftest test` before it was written here; the `opa`
commands need the binary (the setup scripts install it; otherwise `brew install opa`), which is the same evaluator Conftest embeds.

## Part 1 — What a rule computes (45 min)

Put Lab 1's thinking on a clean page. A policy directory, one rule file, one test file:

```bash
mkdir -p ~/opa-lab/policy && cd ~/opa-lab
```

```rego
# policy/main.rego
package main

import rego.v1

# A deny rule is a PARTIAL SET: every body that succeeds contributes one element.
# `deny` is the set of all messages; an empty set means "nothing wrong".
deny contains msg if {
	some r in input.resource_changes
	r.type == "aws_instance"
	not r.change.after.metadata_options[0].http_tokens == "required"
	msg := sprintf("%s: IMDSv2 must be required", [r.address])
}

deny contains msg if {
	some r in input.resource_changes
	r.type == "aws_instance"
	not r.change.after.ami in data.allowlist.amis
	msg := sprintf("%s: ami %q is not in data.allowlist.amis", [r.address, r.change.after.ami])
}

deny contains msg if {
	some r in input.resource_changes
	region := r.change.after.region
	not region in data.allowlist.regions
	msg := sprintf("%s: region %q is not approved", [r.address, region])
}

# A COMPLETE rule produces one value. Without `default`, `allow` is undefined
# (not false) when no body succeeds -- and undefined is what trips people.
default allow := false

allow if count(deny) == 0

# `every` is the universal quantifier: true only if every element satisfies the body.
all_tagged if {
	every r in input.resource_changes {
		r.change.after.tags.Owner
	}
}
```

Three things to say out loud, because they are the whole language:

- **A rule defines a document, not a function.** `data.main.deny` is a set that exists whether or
  not anyone asks for it; `data.main.allow` is a single value. Evaluation is asking "what is the
  value of this path", and the engine works out which rule bodies make it true.
- **A body is a conjunction, and variables unify.** In `some r in input.resource_changes`, `r` is
  not assigned, it is bound to each element in turn and the rest of the body is tried for each. A
  body that fails for one `r` contributes nothing for that `r` and the next is tried. That is why
  there are no loops and no `if/else`: iteration is what unification does.
- **Undefined is not false.** A complete rule with no `default` whose bodies all fail has no value
  at all. `count(deny) == 0` works because an empty set is a value; `allow` without a default would
  be *missing* from the response, and a caller testing `if result == false` would never see it.

Now watch it:

```bash
cat > input-bad.json <<'EOF'
{"resource_changes": [{"address": "aws_instance.web", "type": "aws_instance", "change": {"after": {"ami": "ami-9999", "region": "eu-west-1", "tags": {}, "metadata_options": [{"http_tokens": "optional"}]}}}]}
EOF
cat > data.json <<'EOF'
{"allowlist": {"amis": ["ami-0abc"], "regions": ["us-east-1", "us-west-2"]}}
EOF

opa eval -i input-bad.json -d policy/ -d data.json --format pretty 'data.main.deny'
#   [ "aws_instance.web: IMDSv2 must be required",
#     "aws_instance.web: ami \"ami-9999\" is not in data.allowlist.amis",
#     "aws_instance.web: region \"eu-west-1\" is not approved" ]
opa eval -i input-bad.json -d policy/ -d data.json --format pretty 'data.main.allow'      # false
opa eval -i input-bad.json -d policy/ -d data.json --format pretty 'data.main'            # the whole document: deny, allow, all_tagged
opa eval -i input-bad.json -d policy/ -d data.json --explain full 'data.main.allow' | head -40   # every binding the engine tried
conftest test -p policy -d data.json input-bad.json                                       # the same three lines, as Lab 1 showed them
```

The `--explain full` output is unification made visible: each `Enter`, `Eval`, `Fail` line is one
binding being tried. Read it once for one rule; after that you can predict it.

Unit tests are rules whose names start with `test_`; `with` substitutes `input` or any `data` path:

```rego
# policy/main_test.rego
package main

import rego.v1

good := {"resource_changes": [{
	"address": "aws_instance.web",
	"type": "aws_instance",
	"change": {"after": {
		"ami": "ami-0abc",
		"region": "us-east-1",
		"tags": {"Owner": "platform"},
		"metadata_options": [{"http_tokens": "required"}],
	}},
}]}

allowlist := {"amis": ["ami-0abc"], "regions": ["us-east-1", "us-west-2"]}

test_good_instance_allowed if {
	allow with input as good with data.allowlist as allowlist
}

test_imdsv1_denied if {
	count(deny) == 1 with input as json.patch(good, [{"op": "replace", "path": "/resource_changes/0/change/after/metadata_options/0/http_tokens", "value": "optional"}])
		with data.allowlist as allowlist
}

test_unlisted_ami_denied if {
	deny["aws_instance.web: ami \"ami-9999\" is not in data.allowlist.amis"] with input as json.patch(good, [{"op": "replace", "path": "/resource_changes/0/change/after/ami", "value": "ami-9999"}])
		with data.allowlist as allowlist
}

test_allow_is_false_not_undefined if {
	allow == false with input as {"resource_changes": [{"address": "x", "type": "aws_instance", "change": {"after": {"ami": "ami-x", "region": "eu-west-1", "metadata_options": [{"http_tokens": "optional"}]}}}]}
		with data.allowlist as allowlist
}

test_every_tagged if {
	all_tagged with input as good
	not all_tagged with input as json.patch(good, [{"op": "remove", "path": "/resource_changes/0/change/after/tags/Owner"}])
}
```

```bash
opa test -v policy/            # 5 tests, PASS, with timings
opa fmt --diff policy/         # the one formatting; `opa fmt -w` rewrites in place
conftest verify -p policy -d data.json
```

`json.patch` is the trick: one good input, each test mutates one field, so a test says exactly
which field it is about. Delete the `default allow := false` line and run the tests again:
`test_allow_is_false_not_undefined` fails, and the failure message is the lesson.

## Part 2 — Data is not policy (20 min)

The two allowlists live in `data.json`, loaded with `-d`, addressed as `data.allowlist.amis`. Policy
says "the AMI must be approved"; data says which ones are. They change on different schedules and
are owned by different people: the rule is reviewed like code, the list is updated like
configuration. Prove the separation:

```bash
# the same policy, a different allowlist, no Rego changed
echo '{"allowlist": {"amis": ["ami-9999"], "regions": ["eu-west-1"]}}' > data-eu.json
opa eval -i input-bad.json -d policy/ -d data-eu.json --format pretty 'data.main.deny'
#   [ "aws_instance.web: IMDSv2 must be required" ]      only the hard rule is left
```

Then the question that separates rung 2 from rung 3: what does the engine know before it sees any
input? Ask it with partial evaluation:

```bash
opa eval -d policy/ -d data.json --partial --unknowns input --format pretty 'data.main.allow'
```

The output is the residual: the conditions on `input` that remain once everything knowable from
`data` has been folded in. That residual is what OPA compiles down to a SQL `WHERE` clause or a
filter in data-filtering deployments. One sentence to own: *partial evaluation turns a policy plus
known data into a smaller policy over the unknowns.*

## Part 3 — A bundle, and policy delivered without a redeploy (30 min)

An OPA server does not read files from disk forever; it pulls a **bundle**, a tarball of policy
and data, from a service, on a schedule. That is how a policy change reaches a hundred OPAs
without touching their deployments.

```bash
opa build -b policy/ data.json -o bundle.tar.gz      # -b: bundle mode, includes data.json as data
tar tzf bundle.tar.gz                                 # /policy/main.rego, /policy/main_test.rego, /data.json, /.manifest

# the "bucket": any HTTP server will do for the lab
(cd ~/opa-lab && python3 -m http.server 8000 >/dev/null 2>&1 &)

cat > config.yaml <<'EOF'
services:
  local:
    url: http://127.0.0.1:8000
bundles:
  main:
    resource: bundle.tar.gz
    polling:
      min_delay_seconds: 10
      max_delay_seconds: 20
EOF
opa run --server --addr :8181 -c config.yaml &
sleep 2
curl -s localhost:8181/v1/data/main/allow -d @<(jq '{input: .}' input-bad.json) | jq .   # {"result": false}
curl -s localhost:8181/v1/status | jq '.result.bundles'                                      # which bundle, which revision, when
```

Now change the policy without touching the server: edit `data.json` to approve `ami-9999` and
`eu-west-1`, rebuild the bundle, and watch:

```bash
opa build -b policy/ data.json -o bundle.tar.gz
sleep 20
curl -s localhost:8181/v1/data/main/deny -d @<(jq '{input: .}' input-bad.json) | jq .   # only the IMDSv2 line remains
```

In production the service is a bucket or the OPA control plane, the bundle is signed
(`opa build --signing-key`), and the `.manifest` carries a revision you can see in `/v1/status`.
The mechanism is the same: policy is a versioned artefact that OPAs pull.

## Part 4 — OPA as the authorization service for the week-20 app (60 min)

The step most people never take. The week-20 Flask app gets a `before_request` hook that asks OPA
whether this user may do this thing, and OPA answers from a policy plus a roles document.

```rego
# authz/authz.rego
package authz

import rego.v1

# Called by the Flask before_request hook with
#   {"input": {"method": "GET", "path": ["orders", "42"], "user": "sam"}}
# Roles live in data, not in the policy: data.roles.sam == ["reader"].

default allow := false

# Anyone may read health.
allow if {
	input.method == "GET"
	input.path == ["health"]
}

# Readers may GET under /orders; writers may do anything under /orders.
allow if {
	input.method == "GET"
	input.path[0] == "orders"
	"reader" in data.roles[input.user]
}

allow if {
	input.path[0] == "orders"
	"writer" in data.roles[input.user]
}
```

```bash
cat > roles.json <<'EOF'
{"roles": {"sam": ["reader"], "ana": ["reader", "writer"]}}
EOF
opa test -v authz/     # write the five tests first: health open, reader GET, reader POST refused, writer POST, unknown user false
pkill -f 'opa run' ; opa run --server --addr :8181 authz/ roles.json &
curl -s localhost:8181/v1/data/authz/allow -d '{"input":{"method":"POST","path":["orders"],"user":"sam"}}'   # {"result":false}
curl -s localhost:8181/v1/data/authz/allow -d '{"input":{"method":"POST","path":["orders"],"user":"ana"}}'   # {"result":true}
```

The hook, in the app from week 20 Lab 1 (the user comes from a header here; in week 16's EKS
version it comes from the OIDC token the Ingress validated):

```python
import requests
from flask import request, abort

OPA = "http://127.0.0.1:8181/v1/data/authz/allow"

@app.before_request
def authorize():
    path = [p for p in request.path.split("/") if p]
    decision = requests.post(OPA, json={"input": {
        "method": request.method,
        "path": path,
        "user": request.headers.get("X-User", "anonymous"),
    }}, timeout=0.2).json()
    if not decision.get("result", False):      # undefined and false both land here, on purpose
        abort(403)
```

Measure what a decision costs, because this is the question a reviewer asks first:

```bash
time (for i in $(seq 100); do curl -s -o /dev/null -H 'X-User: sam' localhost:8080/orders; done)   # with the hook
# comment the decorator out, restart the app, run it again: the difference / 100 is the per-request price
```

On a laptop the difference is around a millisecond a request, because OPA evaluates in memory
against data it already holds; the cost that matters in production is the network hop, which is why
OPA runs as a sidecar or a library, never across a region. Then say why this is the step that changes
what policy is: in the pipeline, a policy refuses a change once, at merge time; here it decides every
request, from the same language, with the same tests, with roles that are data. Authorization has
left the application's code.

## Part 5 — Regal, and the three style rules that matter (15 min)

```bash
brew install regal                 # the setup scripts install it too
regal lint policy/ authz/
```

Fix what it reports, then keep three rules from the Rego style guide and let the linter hold the
rest: one package per directory and the package name is the path; booleans get a `default`; iterate
with `some ... in`, never with a bare `_` you will not be able to explain in review.

## Part 6 — One engine, four input shapes (10 min)

Say it, then draw figure 19.7: Conftest hands OPA a plan JSON and asks for `deny`; Gatekeeper hands
it an `AdmissionReview` and asks for `violation`; the server hands it an HTTP request and asks for
`allow`; HCP Terraform hands it a `tfplan` and asks for a rule. The evaluator, the language, the tests
and the bundles are identical. What changes is the input document and which path you ask for. That
sentence is the rung-three answer to "what is OPA".

**Do it again, from memory, timed.** Parts 1 and 4 in 30 minutes: the three deny rules with tests
passing, and the authz policy answering `curl` correctly for a reader, a writer, and a stranger.
