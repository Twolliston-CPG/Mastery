# Break/Fix: Security & Observability (BF-51 – BF-58)

---

## BF-51 — Pipeline blocked by an unfixable transitive CVE

**SYMPTOM:** Trivy fails the build on a CRITICAL CVE in a transitive dependency. No patched version
exists. The release is due today.

**THIS IS NOT A TECHNICAL PROBLEM — IT IS A JUDGMENT PROBLEM,** which is exactly why it's here.
Interviewers love it because there is no clean answer, only a defensible process.

**DIAGNOSIS:**
```bash
trivy image --severity CRITICAL --format json myapp:latest | jq '.Results[].Vulnerabilities[]'
syft myapp:latest -o json | jq '.artifacts[] | select(.name=="<lib>")'
npm ls <package>          # or: go mod graph | grep <pkg>  /  pip show <pkg>
```

**THE TRIAGE PROCESS — say these steps out loud:**
1. **Is it reachable?** A CVE in a code path your app never executes is a different risk than one in
   your request handler. Severity alone is a bad gate; *exploitability in context* is the real
   question.
2. **Is there any fix?** Patched version, backport, or a different library.
3. **Can it be mitigated?** WAF rule, network policy, dropped capability, or disabling the feature.
4. **If none of the above — accept it explicitly, with an expiry and an owner.**

**FIX — a documented, expiring waiver, not a disabled scanner:**
```yaml
# .trivyignore.yaml
vulnerabilities:
  - id: CVE-2024-12345
    paths: ["usr/local/lib/node_modules/foo"]
    statement: >
      Not reachable: the vulnerable XML parser is only invoked by the SAML login
      path, which is disabled in this deployment (AUTH_MODE=oidc). Compensating
      control: NetworkPolicy blocks egress from this pod.
    expires: 2026-12-31
    owner: platform-team
```

**THE ANSWER THAT WINS:** *"I don't disable the scanner. I document a time-boxed, owned exception
with a compensating control, and the expiry forces it back onto the board."* The wrong answers —
which are common — are "turn off the check" and "block the release indefinitely."

---

## BF-52 — Admission policy locks you out of your own cluster

**SYMPTOM:** You applied a Kyverno policy requiring resource limits. Now **nothing** can deploy —
including `kube-system` DaemonSets and the CNI.

**BREAK:**
```yaml
spec:
  validationFailureAction: Enforce
  rules:
    - name: require-limits
      match: { any: [{ resources: { kinds: ["Pod"] } }] }
      validate:
        message: "Resource limits are required"
        pattern:
          spec:
            containers:
              - resources: { limits: { memory: "?*", cpu: "?*" } }
```

**DIAGNOSIS:**
```bash
kubectl get events -A --field-selector reason=PolicyViolation
kubectl get clusterpolicy
kubectl describe clusterpolicy require-limits
```

**FIX — immediate:**
```bash
kubectl patch clusterpolicy require-limits --type merge \
  -p '{"spec":{"validationFailureAction":"Audit"}}'
```

**FIX — correct, and this is the lesson:**
```yaml
spec:
  validationFailureAction: Enforce
  rules:
    - name: require-limits
      match:
        any: [{ resources: { kinds: ["Pod"] } }]
      exclude:
        any:
          - resources:
              namespaces: ["kube-system", "kyverno", "projectcontour", "monitoring"]
```

**THE THREE RULES OF ADMISSION CONTROL — this is the transferable lesson:**
1. **Always roll out in `Audit` mode first.** Look at what it *would* have blocked for a week.
2. **Always exclude system namespaces.** You will otherwise break the CNI and lock yourself out.
3. **Know your `failurePolicy`.** A webhook with `failurePolicy: Fail` that becomes unavailable
   blocks **every** API write cluster-wide. That's a total outage caused by a security control.

**THIS IS A GREAT INTERVIEW STORY** precisely because it's a self-inflicted outage with a clear
lesson. "I broke my own cluster with a policy, and here's the rollout process I use now" is a
genuinely strong answer to "tell me about a time you made a mistake."

---

## BF-53 — cosign verification fails after a registry move

**SYMPTOM:** Images verified fine in staging; after moving to a new registry, `cosign verify` fails
with "no matching signatures."

**DIAGNOSIS:**
```bash
cosign verify --certificate-identity-regexp '.*' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  <image> 2>&1
crane digest <image>                   # digest changed?
cosign tree <image>                    # are the signature artifacts even present?
```

**ROOT CAUSES:**
1. **Signatures are stored as separate OCI artifacts tagged by digest** (`sha256-<digest>.sig`).
   A `docker pull && docker push` to a new registry copies the image but **not** the signature.
   Use `crane copy` or `cosign copy`, which bring the referring artifacts.
2. The image was rebuilt, so the digest changed and the old signature no longer applies
3. `--certificate-identity` regex doesn't match the new workflow's identity
4. Keyless verification requires reaching Fulcio/Rekor — blocked in an air-gapped runner

**FIX:** `cosign copy <src-image> <dst-image>`

**THE INSIGHT WORTH STATING:** signatures attach to the **digest**, not the tag. That is the whole
point — a tag is mutable, a digest is not. Which is also why production deployments should pin
digests, not tags.

---

## BF-54 — NetworkPolicy blocks legitimate traffic

**SYMPTOM:** You applied a default-deny NetworkPolicy. The app can no longer reach its database —
**and DNS stopped working**, so everything fails with resolution errors.

**BREAK:**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: default-deny, namespace: app }
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
```

**DIAGNOSIS:**
```bash
kubectl get networkpolicy -n app
kubectl run tmp --rm -it --image=nicolaka/netshoot -n app -- nslookup kubernetes.default
# fails -> DNS egress is blocked
```

**ROOT CAUSE:** A default-deny **egress** policy blocks UDP/TCP 53 to CoreDNS in `kube-system`.
Every name lookup fails, so every outbound connection fails, and the symptom looks like "the network
is broken" rather than "I wrote a policy."

**FIX — always pair default-deny with a DNS allowance:**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: allow-dns, namespace: app }
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

**TWO THINGS TO KNOW:**
- **NetworkPolicies are additive allow-lists.** There is no deny rule; you deny by not allowing.
- **They require a CNI that enforces them.** Calico and Cilium do. Flannel does **not** — your
  policy applies cleanly and does absolutely nothing. Silently. Knowing that is a real
  differentiator.

---

## BF-55 — Falco alert storm

**SYMPTOM:** Falco fires thousands of alerts an hour. Nobody reads them anymore.

**DIAGNOSIS:**
```bash
kubectl logs -n falco -l app.kubernetes.io/name=falco --tail=200 \
  | jq -r '.rule' | sort | uniq -c | sort -rn | head
```

**ROOT CAUSE:** Default rules like "Terminal shell in container" fire on every legitimate `kubectl
exec`, every debug sidecar, and every CI job. Signal drowns in noise.

**FIX — tune with exceptions, don't disable the rule:**
```yaml
- rule: Terminal shell in container
  append: true
  exceptions:
    - name: ci_debug_containers
      fields: [container.image.repository, k8s.ns.name]
      comps: [startswith, "="]
      values:
        - [ghcr.io/myorg/debug, ci]
```

**THE PRINCIPLE THAT GENERALIZES:** an alert nobody acts on is worse than no alert — it trains the
team to ignore the channel, so the one real alert gets ignored too. Every alert must be
**actionable**, **owned**, and have a **runbook**. If you can't write a runbook for it, it should be
a dashboard panel, not an alert.

This is the same lesson as BF-58 and is worth stating in any SRE interview.

---

## BF-56 — Prometheus OOM from cardinality explosion

**SYMPTOM:** Prometheus pod OOMKilled repeatedly. Memory climbs steadily after a deploy.

**BREAK:** Add a label with unbounded values — `user_id`, `request_id`, `session_id`, or a raw URL
path with IDs in it.

**DIAGNOSIS:**
```promql
topk(10, count by (__name__)({__name__=~".+"}))     # which metrics have the most series
prometheus_tsdb_head_series                          # total active series
topk(10, count by (job)({__name__=~".+"}))
```
```bash
curl -s localhost:9090/api/v1/status/tsdb | jq '.data.seriesCountByMetricName[:10]'
```

**ROOT CAUSE:** **Every unique label-value combination is a separate time series.** A
`http_requests_total{user_id="..."}` metric with 100,000 users is 100,000 series from one metric.
Multiply by other labels and it explodes combinatorially.

**FIX:**
1. Remove high-cardinality labels. IDs never belong in metric labels — they belong in **logs** or
   **traces**.
2. Normalize paths: `/users/{id}` not `/users/12345`
3. Drop at scrape time:
```yaml
metric_relabel_configs:
  - source_labels: [__name__]
    regex: 'app_request_duration_seconds_bucket'
    action: drop
```
4. Cap it: `sample_limit` on the scrape config.

**THE ONE-SENTENCE RULE:** *"Metrics are for aggregates and must be low-cardinality; logs and traces
are where you put the unique identifiers."* That sentence is a complete, senior-sounding answer to a
question most juniors have never considered — and "I OOMed Prometheus with a user_id label" is a
genuinely great war story.

---

## BF-57 — Alert that fires constantly

**SYMPTOM:** `HighCPU` alert flaps every few minutes. The team muted the channel three weeks ago.

**DIAGNOSIS:** Look at the alert definition and ask: *does this describe a symptom users feel, or a
cause I happened to be able to measure?*

**ROOT CAUSE — cause-based alerting:**
```yaml
- alert: HighCPU
  expr: node_cpu_seconds_total > 0.8        # CPU being busy is not an incident
  for: 1m                                   # no debounce
```
High CPU is not a problem. High CPU **with degraded latency** is a problem. High CPU with normal
latency means the machine is doing its job efficiently.

**FIX — symptom-based, with burn rate:**
```yaml
- alert: HighErrorRateBurn
  expr: |
    (
      sum(rate(http_requests_total{status=~"5.."}[5m]))
      / sum(rate(http_requests_total[5m]))
    ) > (14.4 * 0.001)
  for: 5m
  labels: { severity: page }
  annotations:
    summary: "Burning 30-day error budget 14.4x -- budget exhausted in ~2 days"
    runbook_url: "https://runbooks.example/high-error-rate"
```

**THE FOUR GOLDEN SIGNALS — alert on these, dashboard the rest:**
latency · traffic · **errors** · saturation

**MULTI-WINDOW BURN RATE** (14.4× over 1h for a page, 6× over 6h for a ticket) is the modern standard
and comes from Google's SRE workbook. Naming it correctly in an interview is a strong signal.

**THE RULE:** **Page on symptoms, diagnose with causes.** If a human can't do something about it at
3am, it is not a page.

---

## BF-58 — Dashboard looks fine during an outage

**SYMPTOM:** Users are reporting errors. Every dashboard panel is green.

**ROOT CAUSES:**
1. **Averages hide outliers.** Mean latency of 200ms is compatible with 5% of users at 10 seconds.
   Use **p50/p95/p99**, never `avg`.
2. **Aggregating across everything** hides one broken instance among twenty healthy ones.
3. Dashboard shows *infrastructure* health (CPU, memory) rather than *user* experience (errors,
   latency).
4. The metric is scraped from the thing that's down, so it stopped updating — a flat line reads as
   "fine." Alert on `absent()` too.
5. Time range too wide — a 6-hour view flattens a 5-minute spike into nothing.

**FIX:**
```promql
# not this:
avg(rate(http_request_duration_seconds_sum[5m]))

# this:
histogram_quantile(0.99,
  sum by (le, service) (rate(http_request_duration_seconds_bucket[5m]))
)

# and watch for the metric disappearing entirely:
absent(up{job="api"}) == 1
```

**THE TEST FOR A GOOD DASHBOARD:** *Can someone tell whether users are having a bad time, within five
seconds of looking at it?* If the top row isn't error rate and p99 latency, the answer is no.

**BUILD THE DASHBOARD DURING AN INCIDENT, NOT BEFORE.** The panels you actually reach for while
debugging are the ones that belong on it. Everything else is decoration. Saying this shows you've
actually used a dashboard under pressure.
