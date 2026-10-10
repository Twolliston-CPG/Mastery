# Week 14 Solutions

Working manifests: [`k8s-stack/`](k8s-stack/) — `kubectl apply -k k8s-stack/`

---

## Lab 1 — Architecture

### The sentence to have ready

> *"Kubernetes is a set of control loops. Every controller watches the API server for a difference
> between desired state and observed state, and acts to close it. Nothing is imperative — when you
> delete a pod you're deleting an **object**, and a controller notices the divergence and creates a
> replacement."*

That single framing explains: why `kubectl delete pod` on a Deployment-managed pod appears to do
nothing, why editing a ReplicaSet directly is pointless, why the whole system is eventually
consistent, and why `kubectl get events` is the primary debugging tool.

### `readOnlyRootFilesystem` and nginx

Without the `emptyDir` mounts nginx fails with:
```
nginx: [emerg] mkdir() "/var/cache/nginx/client_temp" failed (30: Read-only file system)
```
Finding the required paths is the exercise. For `nginx:alpine`: `/var/cache/nginx`, `/var/run`, and
`/tmp`. For most applications it is `/tmp` and a cache directory.

**This matters beyond the lab.** `readOnlyRootFilesystem: true` is a Pod Security Standard
`restricted` requirement and a Kyverno policy in week 19. An app that can't run read-only will block
your own security policy, so you learn to make apps read-only-compatible *before* you enforce it.

### Init containers vs readiness probes

| | Init container | Readiness probe |
|---|---|---|
| Runs | Once, before app containers | Continuously, after start |
| On failure | Pod restarts and retries | Pod removed from Service endpoints |
| Use for | One-time setup, waiting for a dependency **at startup** | Ongoing "should I get traffic?" |

You often want both: an init container so the app doesn't start before the database exists, and a
readiness probe so it leaves rotation if the database *later* goes away.

---

## Lab 2 — Deployments and Services

### Why rollback is instant

```bash
kubectl get rs
# NAME             DESIRED   CURRENT   READY
# web-5f4b8c9d7    3         3         3      <- current
# web-7d9f2a1b3    0         0         0      <- previous, kept
```
A Deployment keeps old ReplicaSets (10 by default, `revisionHistoryLimit`). `rollout undo` scales the
old one up and the new one down. No image pull, no rebuild — seconds.

**The caveat worth knowing:** rollback reverts the *Pod template*, not the *data*. If the new version
ran a forward-incompatible database migration, rolling back the pods leaves the old code against the
new schema. That's why expand/contract migrations exist, and it's a good thing to raise when asked
about deployment safety.

### `maxSurge` / `maxUnavailable`

| Config | Behavior |
|---|---|
| `maxSurge: 1, maxUnavailable: 0` | Never below desired capacity. One extra pod's cost. **Default choice.** |
| `maxSurge: 0, maxUnavailable: 1` | Never above desired capacity. Brief capacity loss. Use when resources are tight. |
| `maxSurge: 25%, maxUnavailable: 25%` | The actual Kubernetes default. Fast, with a capacity dip. |

### How a Service actually works

```bash
kubectl get endpoints web
docker exec mastery-worker iptables-save -t nat | grep -i web
```
`kube-proxy` watches Services and Endpoints and programs iptables (or IPVS) rules on **every node**.
A packet to the ClusterIP is DNAT'd to a randomly chosen pod IP. There is no proxy process in the
path — it's kernel-level packet rewriting.

**Consequences worth knowing:**
- The ClusterIP is virtual; you cannot ping it meaningfully
- Load balancing is per-connection, random, and **not** aware of pod load
- Long-lived connections (gRPC, database pools) pin to one pod and **do not rebalance** — which is
  exactly why service meshes exist

That last point is a strong answer to "when would you need a service mesh?"

### The endpoints rule

```
No endpoints           -> the Service selector matches no pods, OR pods are failing readiness
Endpoints, conn refused -> targetPort wrong, or the app is bound to 127.0.0.1
Endpoints, timeout      -> NetworkPolicy, or the app is not responding
```

---

## Lab 3 — Secrets

### Why `base64` is not security

```bash
kubectl get secret db -o jsonpath='{.data.password}' | base64 -d
# s3cr3t
```
Secrets are **base64-encoded, not encrypted**, and stored in etcd in plaintext by default. Base64
exists so binary values can live in a YAML string field. Anyone with `get secrets` RBAC — or an etcd
backup, or a snapshot of the control plane volume — has every secret.

### Env var vs mounted file

```yaml
# Weaker
env:
  - name: DB_PASSWORD
    valueFrom: { secretKeyRef: { name: db, key: password } }

# Stronger
volumeMounts:
  - { name: db, mountPath: /etc/secrets, readOnly: true }
```

| | Env var | File |
|---|---|---|
| Visible in `/proc/<pid>/environ` | **Yes** | No |
| Inherited by child processes | **Yes** | No |
| In crash dumps and error reporters | **Often** | No |
| Updated when the Secret changes | **No — needs a restart** | **Yes, automatically** |

That last row is practically useful: External Secrets rotating a credential updates the mounted file
in place, and an app that re-reads it picks up the new value without a deploy.

---

## Lab 4 — Break/Fix

### The three CrashLoopBackOff variants, distinguished

```bash
kubectl get pod crash1 -o jsonpath='{.status.containerStatuses[0].lastState.terminated}' | jq
```

| Pod | Exit code | Reason | Diagnosis |
|---|---|---|---|
| `crash1` | 1 | `Error` | Application error — `kubectl logs --previous` |
| `crash2` | 0 | `Completed` | **Finished normally.** The command isn't long-running. |
| `crash3` | 137 | **`OOMKilled`** | Memory limit too low, or a leak |

**`crash2` is the one that confuses people.** Exit 0 looks like success, and the pod still restarts —
because a Deployment's `restartPolicy` is `Always`, and "always" includes successful exits. If you
genuinely want run-to-completion, that's a `Job`, not a `Deployment`.

### The universal first three

```bash
kubectl describe pod <pod>          # EVENTS first, always
kubectl logs <pod> --previous       # the CRASHED container's output
kubectl get events --sort-by=.lastTimestamp | tail -20
```

`describe` events answer roughly 70% of Kubernetes problems. Reaching for `logs` first is the
beginner tell, because a container that never started has no logs.

---

## Lab 5 — The ported stack

Full manifests in [`k8s-stack/`](k8s-stack/).

### Why Postgres is a StatefulSet

| | Deployment | StatefulSet |
|---|---|---|
| Pod names | Random (`web-5f4b-x7k2`) | **Ordinal and stable** (`db-0`, `db-1`) |
| Storage | Shared or none | **One PVC per pod, retained across restarts** |
| DNS | One Service VIP | **Per-pod DNS** via a headless Service |
| Ordering | Parallel | Sequential create and delete |

A database needs a stable identity and its own persistent volume. A Deployment with a PVC gives every
replica the *same* volume, which for a database is data corruption.

**The honest caveat, worth saying in an interview:** running a production database on Kubernetes is a
real operational commitment — backups, failover, major-version upgrades. For most teams, managed RDS
is the right answer, and Postgres-on-Kubernetes here is a learning exercise. Knowing when *not* to
use Kubernetes is itself a signal.

### The probe set

```yaml
startupProbe:                    # protects a slow boot
  httpGet: { path: /health, port: 8080 }
  failureThreshold: 30
  periodSeconds: 5               # up to 150s to start
livenessProbe:                   # is the PROCESS wedged?
  httpGet: { path: /health, port: 8080 }
  periodSeconds: 10
  failureThreshold: 3
readinessProbe:                  # can it SERVE? -- checks the database
  httpGet: { path: /ready, port: 8080 }
  periodSeconds: 5
  failureThreshold: 2
```

`/health` checks only the process. `/ready` checks the database. **Never the other way round** — a
database blip failing liveness restarts every replica simultaneously and turns a five-second hiccup
into an outage (BF-44). The week-4 app was written with exactly this split, which is why it ports
cleanly.
