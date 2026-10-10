# Week 14 Assessment

> Closed book, 30 min. **Plus the job-search checklist, which is the real assessment this week.**

## Part 0 — The one that matters
- [ ] Terraform Associate sat
- [ ] Résumé rewritten: projects above work history, certs near the top, a number in every bullet
- [ ] LinkedIn headline keyword-dense, open-to-work on, Alpha in Featured
- [ ] GitHub profile README with three pinned repos
- [ ] Target list of 50 companies
- [ ] Application tracker live
- [ ] **10+ applications sent**
- [ ] 5 people identified for outreach

**If Part 0 is incomplete, nothing else in this assessment matters.** Do it before the Kubernetes
questions.

## Part A — Kubernetes (20 min)
1. Name the four control-plane components and what each does.
2. What do kubelet, kube-proxy, and the CRI do?
3. Explain Kubernetes as a control loop in one sentence.
4. Deployment → ReplicaSet → Pod. Why does that chain make rollback instant, and what does rollback
   **not** revert?
5. `maxSurge: 1, maxUnavailable: 0` — what behavior, and what does it cost?
6. How does a Service actually route traffic to a pod? Name the component and the mechanism.
7. What's the first command when a Service returns nothing, and how do you read the result?
8. A Service has endpoints but connections are refused. Two causes.
9. Why are Kubernetes Secrets not secure by default? Name three mitigations in order of strength.
10. Env var vs mounted file for a secret — three differences.
11. Init container vs readiness probe — when each?
12. Why does a pod with exit code 0 keep restarting in a Deployment?

## Part B — Write from memory (10 min)
13. A Deployment with 3 replicas, resource requests/limits, and a non-root securityContext
14. A Service selecting it, port 80 → a named container port
15. An Ingress for `app.local` with the correct class name
16. The three probes with sensible values, with `/health` and `/ready` used correctly
17. The command that generates Deployment YAML without applying it

---

# Answer key

**A1.** **kube-apiserver** — the only component that talks to etcd; handles authn, authz, admission.
**etcd** — the consistent, watchable datastore; the only stateful component.
**kube-scheduler** — assigns Pods to nodes by filtering then scoring.
**kube-controller-manager** — runs the reconciliation loops (Deployment→ReplicaSet→Pod, node
lifecycle, endpoints).

**A2.** **kubelet** — on each node; watches for Pods assigned to it, tells the CRI to run containers,
reports status back. **kube-proxy** — programs iptables/IPVS so a Service ClusterIP DNATs to pod IPs.
**CRI (containerd)** — actually runs containers, via runc.

**A3.** Every controller watches the API server for a difference between desired and observed state
and acts to close it; nothing is imperative, so deleting a pod deletes an *object* and a controller
creates a replacement.

**A4.** A Deployment manages ReplicaSets; each rollout creates a new RS and scales the old one to
zero **without deleting it**. `rollout undo` just scales the old one back up — no image pull, no
rebuild. **It does not revert data.** A forward-incompatible database migration leaves old code
against a new schema, which is why expand/contract migrations exist.

**A5.** One extra pod may exist during the rollout; the deployment **never drops below desired
capacity**. Cost: one extra pod's resources for the duration.

**A6.** **kube-proxy** watches Services and Endpoints and programs **iptables (or IPVS) DNAT rules on
every node**. A packet to the ClusterIP is rewritten to a randomly chosen pod IP in the kernel —
there is no proxy process in the data path. Consequence: load balancing is per-connection and random,
so long-lived connections (gRPC, DB pools) pin to one pod and never rebalance.

**A7.** `kubectl get endpoints <svc>`. **No endpoints** = the selector matches no pods, or pods are
failing readiness. **Endpoints present** = the selector is fine; the problem is ports, binding, or
network policy.

**A8.** (1) `targetPort` doesn't match the port the container actually listens on. (2) The app is
bound to `127.0.0.1` instead of `0.0.0.0` (BF-20, recurring).

**A9.** They are **base64-encoded, not encrypted**, and stored in etcd in plaintext by default.
Mitigations, weakest to strongest: RBAC restricting `get secrets` → encryption at rest via
`EncryptionConfiguration` → **External Secrets Operator** with a real secrets manager as the source
of truth.

**A10.** File: not visible in `/proc/<pid>/environ` · not inherited by child processes · not in crash
dumps · **updates in place when the Secret changes**, where an env var needs a pod restart.

**A11.** **Init container** — one-time, before app containers start, for setup or waiting on a
dependency at startup. **Readiness probe** — continuous, after start, for "should I receive traffic
right now?" You often want both.

**A12.** A Deployment's pods have `restartPolicy: Always`, and "always" includes **successful** exits.
Exit 0 means the command isn't long-running. If you want run-to-completion, that's a `Job`.

---

**B13–B17:** see [`solutions/k8s-stack/30-app.yaml`](solutions/k8s-stack/30-app.yaml).
**B17:** `kubectl create deploy web --image=nginx --replicas=3 --dry-run=client -o yaml`

## Scoring
| | |
|---|---|
| Part 0 complete + 14–17 | On track. |
| Part 0 complete + 10–13 | Fine. Kubernetes has three more weeks. |
| **Part 0 incomplete** | **Stop and finish Part 0 this weekend.** Kubernetes knowledge you acquire while not applying is worth much less than the same knowledge acquired while a pipeline is filling. |
