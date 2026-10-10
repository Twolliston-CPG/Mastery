# Break/Fix: Kubernetes (BF-41 – BF-50)

> **These ten are the Gate 4 set.** By week 17 you must diagnose any five of them, unaided,
> under 15 minutes each, narrating aloud. They are also the most commonly asked junior K8s
> interview questions, nearly verbatim.

## The universal first three commands

```bash
kubectl get pods -o wide                      # state, restarts, node, age
kubectl describe pod <pod>                    # EVENTS at the bottom -- read these FIRST
kubectl logs <pod> --previous                 # --previous = the crashed container's logs
```

**`kubectl describe` events answer roughly 70% of Kubernetes problems.** Beginners run `logs`
first and miss that the container never started, so there are no logs to read.

---

## BF-41 — ImagePullBackOff

**SYMPTOM:** Pod stuck in `ImagePullBackOff` or `ErrImagePull`.

**BREAK:** `kubectl set image deploy/web web=nginx:doesnotexist`

**DIAGNOSIS:** `kubectl describe pod <pod>` → the event names it exactly:
| Event message | Cause |
|---|---|
| `manifest unknown` / `not found` | Tag doesn't exist — typo or never pushed |
| `unauthorized` / `authentication required` | Missing or wrong `imagePullSecrets` |
| `no such host` | Registry DNS wrong |
| `i/o timeout` | Node has no egress to the registry (NAT/firewall) |
| `toomanyrequests` | Docker Hub rate limit — authenticate or mirror |

**FIX:** Correct the tag, or attach a pull secret:
```bash
kubectl create secret docker-registry regcred \
  --docker-server=<registry> --docker-username=<u> --docker-password=<p>
kubectl patch serviceaccount default \
  -p '{"imagePullSecrets":[{"name":"regcred"}]}'
```

**THE DOCKER HUB RATE LIMIT IS REAL** and catches people in CI constantly. Naming it is a small,
credible detail.

---

## BF-42 — CrashLoopBackOff

**SYMPTOM:** Pod restarts endlessly, restart count climbing.

**DIAGNOSIS:**
```bash
kubectl logs <pod> --previous              # THE crashed container's output -- start here
kubectl describe pod <pod> | grep -A5 'Last State'
#   Reason: Error     -> the app itself exited. Read the logs.
#   Reason: OOMKilled -> memory limit. Go to BF-43.
kubectl get pod <pod> -o jsonpath='{.status.containerStatuses[0].lastState.terminated.exitCode}'
```

**THE DECISION TREE:**
```
Exit code 0     -> process finished; it isn't a long-running server (see BF-19)
Exit code 1     -> application error -> read logs -> usually config or a missing dependency
Exit code 137   -> OOMKilled -> BF-43
Exit code 139   -> segfault -> wrong CPU architecture is a common cause (arm64 image on amd64)
No logs at all  -> container never started -> describe events -> bad command, missing mount
Restarts but logs look FINE -> the LIVENESS PROBE is killing it -> BF-44
```

**THE "LOGS LOOK FINE BUT IT KEEPS RESTARTING" CASE IS THE ONE THAT SEPARATES PEOPLE.** If the app
logs normal startup and then dies with no error, something *external* is killing it — almost always
a liveness probe or the OOM killer.

---

## BF-43 — OOMKilled

**SYMPTOM:** Container restarts with exit code 137. `Last State: Terminated, Reason: OOMKilled`.

**BREAK:** Set `resources.limits.memory: 32Mi` on an app that needs 200Mi.

**DIAGNOSIS:**
```bash
kubectl describe pod <pod> | grep -A3 'Last State'
kubectl top pod <pod>                                  # needs metrics-server
kubectl get pod <pod> -o jsonpath='{.spec.containers[0].resources}'
```

**FIX:** Raise the limit — or fix the leak. Measure first:
```bash
kubectl top pod <pod> --containers    # observe real usage under load
```

**REQUESTS vs LIMITS — you must be able to explain this cleanly:**
| | Purpose |
|---|---|
| **request** | What the **scheduler** reserves. Determines *where* the pod lands. |
| **limit** | What the **kernel cgroup** enforces. Exceed memory → killed. Exceed CPU → throttled. |

**QoS CLASSES — and why they matter:**
| Class | Condition | Evicted |
|---|---|---|
| `Guaranteed` | requests == limits, for every container | Last |
| `Burstable` | requests < limits | Middle |
| `BestEffort` | neither set | **First** |

**CPU IS THROTTLED, MEMORY IS KILLED.** That asymmetry is the single most useful sentence about
Kubernetes resources, and it explains why a CPU-limited app gets slow while a memory-limited app
dies.

---

## BF-44 — Liveness probe restart loop

**SYMPTOM:** Healthy-looking app restarts every ~30 seconds. Logs show normal startup each time.

**BREAK:**
```yaml
livenessProbe:
  httpGet: { path: /health, port: 8080 }
  initialDelaySeconds: 1        # app takes 20s to start
  periodSeconds: 5
  failureThreshold: 1
```

**DIAGNOSIS:** `kubectl describe pod` → `Liveness probe failed: Get "http://...": dial tcp: connection refused`

**ROOT CAUSE:** The probe starts before the app is listening, fails once, and kubelet kills the
container. Forever.

**FIX — use the right probe for the right job:**
```yaml
startupProbe:                       # protects slow starters
  httpGet: { path: /health, port: 8080 }
  failureThreshold: 30
  periodSeconds: 10                 # allows up to 5 minutes to start
livenessProbe:                      # "is it wedged? restart it"
  httpGet: { path: /health, port: 8080 }
  periodSeconds: 10
  failureThreshold: 3
readinessProbe:                     # "should it get traffic?"
  httpGet: { path: /ready, port: 8080 }
  periodSeconds: 5
```

**THE THREE PROBES — know exactly what each does:**
| Probe | Failure action | Use for |
|---|---|---|
| **startup** | Kills, but suppresses the other two until it passes | Slow-booting apps |
| **liveness** | **Restarts the container** | Deadlock detection only |
| **readiness** | **Removes from Service endpoints** (no restart) | Dependency checks, warmup |

**THE CLASSIC PRODUCTION DISASTER:** a liveness probe that checks a *database* connection. The
database has a blip → every pod fails liveness → every pod restarts simultaneously → the outage is
now much worse than the blip. **Liveness should check only the process itself. Dependency checks
belong in readiness.** That answer is worth real credibility in an interview.

---

## BF-45 — Pod stuck Pending

**SYMPTOM:** Pod never gets scheduled. `STATUS: Pending`, no node assigned.

**DIAGNOSIS:** `kubectl describe pod <pod>` → the `FailedScheduling` event states the reason verbatim:

| Event text | Cause | Fix |
|---|---|---|
| `Insufficient cpu` / `Insufficient memory` | No node has room for the **requests** | Lower requests, or add nodes |
| `had untolerated taint` | Node taints, pod has no toleration | Add toleration or remove taint |
| `didn't match Pod's node affinity` | `nodeSelector`/affinity matches nothing | Fix labels or the selector |
| `pod has unbound immediate PersistentVolumeClaims` | PVC not bound — go to BF-46 | |
| `had volume node affinity conflict` | EBS volume in AZ-a, pod scheduled to AZ-b | Topology-aware provisioning |
| `Too many pods` | Node's pod-count limit hit (ENI limits on EKS) | Bigger instance type |

```bash
kubectl describe node <node> | grep -A5 'Allocated resources'
kubectl describe node <node> | grep Taints
kubectl get events --sort-by='.lastTimestamp' | tail -20
```

**KEY INSIGHT:** Scheduling is based on **requests**, not actual usage. A cluster with 10% real CPU
usage can be 100% unschedulable if requests are set too high. Explaining that gap is a genuinely
senior observation.

---

## BF-46 — PVC stuck Pending

**SYMPTOM:** `kubectl get pvc` → `Pending`. The pod is Pending too, waiting on it.

**DIAGNOSIS:**
```bash
kubectl describe pvc <pvc>
kubectl get storageclass                      # is there a DEFAULT one?
kubectl get pv
kubectl logs -n kube-system -l app=ebs-csi-controller
```

**ROOT CAUSES:**
1. **No default StorageClass** and the PVC didn't name one — the most common on a fresh cluster
2. StorageClass name typo'd
3. CSI driver not installed (bare EKS has no EBS CSI driver by default)
4. `volumeBindingMode: WaitForFirstConsumer` — this is **correct behavior**, not a bug; the PVC
   stays Pending until a pod is scheduled so the volume lands in the right AZ
5. Access mode unsupported — `ReadWriteMany` on EBS is impossible; EBS is `ReadWriteOnce`. Use EFS.

**FIX:**
```bash
kubectl patch storageclass gp3 \
  -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

**`ReadWriteOnce` vs `ReadWriteMany` IS A FAVORITE QUESTION.** EBS = block storage = one node at a
time. EFS/NFS = shared filesystem = many nodes. Trying to scale a Deployment with an RWO volume to
3 replicas across nodes fails, and knowing *why* matters.

---

## BF-47 — Service returns nothing

**SYMPTOM:** Pods are Running and healthy, but `curl <service>` times out or connection-refuses.

**BREAK:** Change the Service `selector` to `app: web-v2` while pods are labeled `app: web`.

**DIAGNOSIS — this is the single most valuable command:**
```bash
kubectl get endpoints <service>
# NO ENDPOINTS  -> the selector matches no pods.  That's your answer.
```
Then:
```bash
kubectl get svc <service> -o yaml | grep -A3 selector
kubectl get pods --show-labels
kubectl describe svc <service>
kubectl run tmp --rm -it --image=nicolaka/netshoot -- \
  curl -v http://<service>.<ns>.svc.cluster.local:80
```

**ROOT CAUSES:**
1. **Selector doesn't match pod labels** — no endpoints. Most common by far.
2. `targetPort` ≠ the port the container actually listens on
3. App bound to `127.0.0.1` instead of `0.0.0.0` (BF-20 all over again)
4. Readiness probe failing → pods excluded from endpoints (they're Running but not Ready)
5. NetworkPolicy blocking the traffic

**THE ONE-LINE RULE:** *"No endpoints = selector problem. Endpoints present but connection refused =
port or bind-address problem."* That sentence bisects the problem instantly and sounds like
experience.

---

## BF-48 — RBAC Forbidden

**SYMPTOM:** `Error from server (Forbidden): pods is forbidden: User "system:serviceaccount:app:deploy"
cannot list resource "pods" in API group "" in the namespace "prod"`

**DIAGNOSIS — read the error, it names all four variables:** who, verb, resource, namespace.
```bash
kubectl auth can-i list pods --as=system:serviceaccount:app:deploy -n prod
kubectl auth can-i --list --as=system:serviceaccount:app:deploy -n prod
kubectl get rolebinding,clusterrolebinding -A -o wide | grep deploy
kubectl describe clusterrole <role>
```

**ROOT CAUSES:**
1. **`Role` + `RoleBinding` grants only within one namespace**; the request was for another
2. Used a `ClusterRole` but bound it with a `RoleBinding` (that scopes it to one namespace — which
   is legal and often intended, but surprising)
3. Wrong `apiGroup` — core resources use `""`, deployments use `"apps"`
4. Missing the sub-resource — `pods/log` and `pods/exec` are separate from `pods`
5. Pod isn't using the ServiceAccount you think — check `spec.serviceAccountName`

**FIX:**
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata: { namespace: prod, name: pod-reader }
rules:
  - apiGroups: [""]
    resources: ["pods", "pods/log"]
    verbs: ["get", "list", "watch"]
```

**THE FOUR-WAY MATRIX YOU MUST BE ABLE TO DRAW:**
| | RoleBinding | ClusterRoleBinding |
|---|---|---|
| **Role** | permissions in that namespace | *not allowed* |
| **ClusterRole** | permissions in **that one namespace** | permissions **cluster-wide** |

The bottom-left cell is the one people get wrong, and it's the one interviewers ask about.

---

## BF-49 — Ingress returns 404 / 503

**SYMPTOM:** Service works via `kubectl port-forward`, but the Ingress URL returns 404 or 503.

**DIAGNOSIS:**
```bash
kubectl describe ingress <ing>
kubectl get ingressclass
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=50
kubectl get endpoints <backend-service>
```

**ROOT CAUSES:**
1. **No `ingressClassName`** — the controller ignores the resource entirely, which looks like 404
2. Backend Service name or port wrong in the Ingress spec
3. `Host:` header mismatch — you're hitting an IP, the rule matches a hostname
4. **Ingress is in a different namespace from the Service** — Ingress backends are namespace-local
5. Path type confusion: `Prefix` vs `Exact` vs `ImplementationSpecific`
6. Rewrite annotation missing, so the backend gets a path it doesn't serve

**FIX:**
```yaml
spec:
  ingressClassName: nginx
  rules:
    - host: app.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service: { name: web, port: { number: 80 } }
```
Test with an explicit host header: `curl -H 'Host: app.local' http://localhost/`

**#4 IS THE SNEAKY ONE.** An Ingress cannot route to a Service in another namespace. People lose
hours to it.

---

## BF-50 — Node NotReady

**SYMPTOM:** `kubectl get nodes` → one node `NotReady`. Pods on it stuck `Terminating`.

**DIAGNOSIS:**
```bash
kubectl describe node <node>          # Conditions section names it
#   MemoryPressure / DiskPressure / PIDPressure = True
#   KubeletNotReady with a message
# On the node itself:
systemctl status kubelet
journalctl -u kubelet -n 100 --no-pager
df -h /var/lib/containerd            # disk full is extremely common
```

**ROOT CAUSES:**
1. **kubelet crashed or can't reach the API server** (cert expiry, network, security group)
2. **Disk pressure** — image layers filled `/var/lib/containerd`. Very common on long-lived nodes.
3. Memory pressure — node-level OOM
4. Container runtime (containerd) died
5. Node genuinely gone (spot reclaim, hardware)

**FIX:**
```bash
kubectl cordon <node>                              # stop new scheduling
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data
# fix (restart kubelet / clear images / replace node)
kubectl uncordon <node>
```

**WHY PODS HANG IN `Terminating`:** the node is unreachable, so kubelet can't confirm the pods are
gone, and the control plane won't assume they are — deleting the Pod object while the container may
still be running risks a split-brain double-write. For a StatefulSet that would be data corruption.
`--force --grace-period=0` overrides it, and knowing *why that's dangerous* is the real answer.

**PREVENT:** disk-pressure alarms, image garbage collection (`--image-gc-high-threshold`), node
auto-repair, `PodDisruptionBudgets` so drains don't take down a whole service.
