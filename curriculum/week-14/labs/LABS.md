# Week 14 Labs

> **Figures:** one numbered mechanism figure per lab, with the spoken script, the numbers to own and
> the command that proves each badge, in [`FIGURES.md`](FIGURES.md) (14.2 to 14.7). Read a lab's figure
> before you start it; redraw it after.

---

# Lab 1 — Architecture and Pods (3h)

## Part 1 — Look at the control plane

```bash
kubectl get nodes -o wide
kubectl get pods -n kube-system

# On kind, the control plane runs as static pods on the node
docker exec -it mastery-control-plane ls /etc/kubernetes/manifests/
# etcd.yaml  kube-apiserver.yaml  kube-controller-manager.yaml  kube-scheduler.yaml

docker exec -it mastery-control-plane crictl ps | head
```

| Component | Job |
|---|---|
| **kube-apiserver** | The only thing that talks to etcd. Every read and write goes through it. Authn, authz, admission. |
| **etcd** | The datastore. Consistent, watchable key-value. **The only stateful component.** |
| **kube-scheduler** | Watches for Pods with no `nodeName` and picks a node. Filtering, then scoring. |
| **kube-controller-manager** | Runs the reconciliation loops — Deployment→ReplicaSet→Pod, node lifecycle, endpoints |
| **kubelet** | On each node. Watches for Pods assigned to it, tells the CRI to run containers, reports status. |
| **kube-proxy** | Programs iptables/IPVS so a Service ClusterIP routes to pod IPs |
| **CRI (containerd)** | Actually runs containers, via runc |

**The mental model that matters:** Kubernetes is a set of **control loops** reconciling *observed
state* toward *desired state* through the API server. Nothing is imperative. When you
`kubectl delete pod`, you are not deleting a container — you are deleting an object, and a controller
notices the divergence and acts.

```bash
# Watch it happen
kubectl run nginx --image=nginx
kubectl get events --sort-by=.lastTimestamp | tail -10
# Scheduled -> Pulling -> Pulled -> Created -> Started
```

## Part 2 — Pods

```bash
kubectl run demo --image=nginx:alpine --dry-run=client -o yaml > pod.yaml
kubectl apply -f pod.yaml
kubectl get pod demo -o yaml | less
kubectl describe pod demo
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: demo
  labels: { app: demo }
spec:
  containers:
    - name: web
      image: nginx:1.27-alpine
      ports:
        - containerPort: 80
      resources:
        requests: { cpu: 50m, memory: 64Mi }
        limits:   { cpu: 200m, memory: 128Mi }
      securityContext:
        runAsNonRoot: true
        runAsUser: 101
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities: { drop: ["ALL"] }
      volumeMounts:
        - { name: cache, mountPath: /var/cache/nginx }
        - { name: run,   mountPath: /var/run }
  volumes:
    - { name: cache, emptyDir: {} }
    - { name: run,   emptyDir: {} }
```

**Note the `emptyDir` volumes.** `readOnlyRootFilesystem: true` means nginx cannot write its cache or
pid file, so it crashes. Mounting writable `emptyDir`s at exactly the paths it needs is the standard
pattern — and finding out *which* paths is a real debugging exercise. Try it without them first.

## Part 3 — Multi-container patterns

```yaml
spec:
  initContainers:
    - name: wait-for-db
      image: busybox:1.36
      command: ['sh', '-c', 'until nc -z db 5432; do echo waiting; sleep 2; done']
  containers:
    - name: app
      image: myapp
    - name: log-shipper           # sidecar
      image: fluent-bit
      volumeMounts:
        - { name: logs, mountPath: /var/log/app }
```

**Init containers run to completion, in order, before any app container starts.** They're the answer
to "how do I wait for a dependency" — the same problem `depends_on: service_healthy` solved in week 4.

**Tasks:** build a pod with an init container that waits, a main container, and a sidecar sharing an
`emptyDir`. Watch the ordering in `kubectl get pods -w`.

---

# Lab 2 — Deployments, Services, Ingress (3h)

## Deployments

```bash
kubectl create deploy web --image=nginx:1.27-alpine --replicas=3 --dry-run=client -o yaml > deploy.yaml
kubectl apply -f deploy.yaml
kubectl get deploy,rs,pods
```

**The chain:** Deployment → ReplicaSet → Pods. A Deployment manages *ReplicaSets*; each rollout
creates a **new ReplicaSet** and scales the old one down. That's why rollback is instant — the old
ReplicaSet still exists at scale 0.

```bash
kubectl set image deploy/web nginx=nginx:1.27
kubectl rollout status deploy/web
kubectl get rs                        # two ReplicaSets, one at 0
kubectl rollout history deploy/web
kubectl rollout undo deploy/web
kubectl annotate deploy/web kubernetes.io/change-cause="upgrade to 1.27"
```

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1           # how many EXTRA pods during the rollout
    maxUnavailable: 0     # how many BELOW desired -- 0 means no capacity loss
```
`maxUnavailable: 0` with `maxSurge: 1` gives a zero-capacity-loss rollout at the cost of one extra
pod's resources. That's usually the right default for anything user-facing.

## Services

```bash
kubectl expose deploy web --port=80 --target-port=80
kubectl get svc,endpoints web
```

| Type | What it does |
|---|---|
| `ClusterIP` | A virtual IP inside the cluster. **Default.** |
| `NodePort` | Opens the same high port (30000–32767) on **every** node |
| `LoadBalancer` | NodePort + asks the cloud for an external LB |
| `ExternalName` | A CNAME. No proxying at all. |
| Headless (`clusterIP: None`) | No virtual IP; DNS returns **pod IPs directly**. For StatefulSets. |

```bash
# Prove the mechanism
kubectl get endpoints web              # THE diagnostic command
kubectl run tmp --rm -it --image=nicolaka/netshoot -- \
  sh -c 'nslookup web; curl -s web'
docker exec mastery-worker iptables-save | grep web | head
```

**The one-line rule:** *no endpoints = selector problem. Endpoints present but connection refused =
port or bind-address problem.* (BF-47)

## Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web
spec:
  ingressClassName: contour      # WITHOUT this the controller ignores it entirely
  rules:
    - host: web.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: web
                port: { number: 80 }
```
```bash
curl -H 'Host: web.local' http://localhost/
```

**Tasks:** add a second service and route `/api` to it. Then break it four ways — remove
`ingressClassName`, wrong service name, wrong port, put the Ingress in a different namespace from the
Service — and read each failure. (BF-49)

**CKA thread — the same route as Gateway API (30 min).** The CKA blueprint lists Gateway API beside
Ingress, and Contour implements both. Install the standard CRDs, then say the same routing as three
role-separated objects: a `GatewayClass` (the implementation, owned by whoever runs the cluster), a
`Gateway` (the listener, owned by the platform team), an `HTTPRoute` (the rule, owned by the app team).

```bash
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/latest/download/standard-install.yaml
kubectl get gatewayclass          # a class named for Contour must show ACCEPTED True
```

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata: { name: web, namespace: default }
spec:
  gatewayClassName: contour
  listeners:
    - { name: http, protocol: HTTP, port: 80 }
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata: { name: web, namespace: default }
spec:
  parentRefs: [{ name: web }]
  hostnames: ["web.local"]
  rules:
    - matches: [{ path: { type: PathPrefix, value: / } }]
      backendRefs: [{ name: web, port: 80 }]
```

If no GatewayClass is accepted, the kind setup installed Contour's static mode; install Contour's
Gateway provisioner from its docs and apply a `GatewayClass` with `controllerName:
projectcontour.io/gateway-controller`. Hit it with the same `curl -H 'Host: web.local'`, then say
what changed: one Ingress became three objects with three owners. Week 28 does the full lab.

---

# Lab 3 — Config, Secrets, Namespaces (2h)

```bash
kubectl create cm app-config --from-literal=LOG_LEVEL=debug --from-file=./app.conf --dry-run=client -o yaml
kubectl create secret generic db --from-literal=password=s3cr3t --dry-run=client -o yaml
```

```yaml
envFrom:
  - configMapRef: { name: app-config }
  - secretRef:    { name: db }
volumeMounts:
  - { name: config, mountPath: /etc/app, readOnly: true }
```

## The two things to understand about Secrets

```bash
kubectl get secret db -o jsonpath='{.data.password}' | base64 -d
```
**1. `base64` is encoding, not encryption.** By default Secrets are stored in etcd **unencrypted**.
Anyone with `get secrets` RBAC, or read access to an etcd backup, has them in plaintext.

**2. The mitigations, in increasing order of strength:**
| Mitigation | What it fixes |
|---|---|
| RBAC restricting `get secrets` | Casual access |
| Encryption at rest (`EncryptionConfiguration`) | etcd backups |
| **External Secrets Operator** + AWS Secrets Manager | The value never lives in etcd as the source of truth (week 16) |
| Mount as a file, not an env var | Env vars leak into crash dumps, `/proc/<pid>/environ`, and child processes |

**Env var vs file matters more than people think.** A crash handler that dumps the environment, or a
subprocess that inherits it, leaks the secret. A mounted file is read only by code that asks for it,
and ESO can rotate it in place without a pod restart.

## Namespaces
```bash
kubectl create ns app
kubectl config set-context --current --namespace=app
kubectl get all -A
```
Namespaces scope **names**, not network or nodes. Two pods in different namespaces can still talk to
each other unless a NetworkPolicy says otherwise (week 19).

---

# Lab 4 — Break/Fix Friday #5 (2h)

**BF-41** (ImagePullBackOff) · **BF-42** (CrashLoopBackOff) · **BF-47** (Service returns nothing).

```bash
# BF-41
kubectl set image deploy/web nginx=nginx:doesnotexist

# BF-42 -- three variants, diagnose each
kubectl run crash1 --image=busybox --command -- /bin/false            # exit 1
kubectl run crash2 --image=busybox --command -- echo hello            # exit 0
kubectl run crash3 --image=busybox --limits=memory=1Mi --command -- \
  sh -c 'dd if=/dev/zero of=/dev/null bs=100M count=1'                # OOM

# BF-47
kubectl patch svc web -p '{"spec":{"selector":{"app":"nope"}}}'
```

**Start every diagnosis with `kubectl describe pod` and read the events.** Beginners run `logs`
first and miss that the container never started, so there are no logs.

---

# Lab 5 — Port the Week-4 Stack (4h)

Rebuild the week-4 Compose stack on Kubernetes: **Nginx Ingress → Flask app → Postgres**.

## Requirements
- [ ] `Namespace`, `Deployment`, `Service`, `Ingress` for the app
- [ ] `StatefulSet` + headless `Service` + `PersistentVolumeClaim` for Postgres
- [ ] `ConfigMap` for app config, `Secret` for the DB password (**mounted as a file**)
- [ ] Init container waiting for Postgres
- [ ] `readinessProbe` on `/ready`, `livenessProbe` on `/health`, `startupProbe` for slow boot
- [ ] Resource requests **and** limits on every container
- [ ] `securityContext`: non-root, read-only root filesystem, all capabilities dropped
- [ ] Data survives `kubectl delete pod`

## The comparison to write down

| Compose | Kubernetes |
|---|---|
| `depends_on: condition: service_healthy` | `initContainers` + `readinessProbe` |
| `healthcheck` | `livenessProbe` / `readinessProbe` / `startupProbe` |
| named volume | `PersistentVolumeClaim` |
| user-defined network DNS | cluster DNS (CoreDNS), `svc.namespace.svc.cluster.local` |
| `deploy.resources.limits` | `resources.requests` / `resources.limits` |
| `read_only: true` | `securityContext.readOnlyRootFilesystem` |
| `environment` | `ConfigMap` / `Secret` |
| — | RBAC, NetworkPolicy, PodDisruptionBudget, HPA |

**Filling this table in yourself is the fastest way to make Kubernetes feel like a known thing.**
Almost every concept has a Compose analogue you already understand.

---

# Go deeper — The API, watched and audited (3h · ladder: API machinery, rung 3; authn, authz, admission, rung 3)

**Optional inside the week, mandatory for the ladder** ([`KUBERNETES-MASTERY.md`](../../../KUBERNETES-MASTERY.md)).
The week's labs use the API server the way a client uses a bank: you hand it an object and trust it.
This lab opens the counter. By the end, "the controllers watch the API server" is a sentence you can
replace with the HTTP requests it stands for, and "admission" is a chain you have read one request
through, line by line, in the audit log. On kind.

## Part 1 — A watch, by hand (40 min)

`kubectl get -w` is two HTTP requests. Make it print them:

```bash
kubectl get pods -w -v=9 2>&1 | grep -E 'curl -v|HTTP/|resourceVersion|watch=true' | head -20
```

Read what you see, in order:

1. **The list.** `GET /api/v1/namespaces/default/pods?limit=500&resourceVersion=0`. The response body
   carries `metadata.resourceVersion`, a number. It is not a timestamp and not a version of any one
   pod; it is the cluster-wide ordinal of the etcd revision the list was served at.
2. **The watch.** `GET ...pods?allowWatchBookmarks=true&resourceVersion=<that number>&watch=true`,
   with `timeoutSeconds` in the query. This request does not return. The server holds it open and
   streams one JSON object per change: `{"type":"ADDED"|"MODIFIED"|"DELETED"|"BOOKMARK","object":...}`.
   "Starting at `resourceVersion`" is what makes the stream gap-free: the server replays everything
   after the list, so nothing between the two requests is lost.
3. **The events.** In a second terminal, `kubectl run w1 --image=nginx:alpine && kubectl delete pod w1`.
   Watch the stream: ADDED, several MODIFIED as status changes, DELETED. Every MODIFIED carries the
   whole object and a new `resourceVersion`.

Now do it with no kubectl at all:

```bash
kubectl proxy --port=8001 &                      # authenticates for you, speaks plain HTTP on localhost
RV=$(curl -s 'http://127.0.0.1:8001/api/v1/namespaces/default/pods' | jq -r .metadata.resourceVersion)
echo "list served at $RV"
curl -sN "http://127.0.0.1:8001/api/v1/namespaces/default/pods?watch=1&resourceVersion=$RV" | jq -c '{type, name: .object.metadata.name, rv: .object.metadata.resourceVersion}'
```

`-N` turns off curl's buffering, so events print as they arrive. Create and delete a pod in the other
terminal and watch the stream. Then kill the watch, wait, and start it again with a **very old**
`resourceVersion` (subtract a few thousand):

```bash
curl -sN "http://127.0.0.1:8001/api/v1/namespaces/default/pods?watch=1&resourceVersion=$((RV-5000))"
# {"type":"ERROR","object":{"kind":"Status","status":"Failure","reason":"Expired","code":410,
#   "message":"too old resource version: ... "}}
```

**410 Gone.** The API server keeps a window of recent history (the watch cache, bounded in size and
time; etcd itself is compacted every five minutes by default, `--etcd-compaction-interval`). Ask for a
point before the window and the server cannot replay what it no longer has. A correct client responds
by **re-listing** and watching from the new `resourceVersion`. That re-list is the single most
important behaviour of an informer, and it is why every controller survives an API server restart.

## Part 2 — Optimistic concurrency: the 409 (25 min)

The API server never locks an object. It compares.

```bash
kubectl create deploy web --image=nginx:1.27-alpine --replicas=2
kubectl get deploy web -o yaml > a.yaml && cp a.yaml b.yaml
# terminal 1: edit a.yaml, replicas: 3            terminal 2: edit b.yaml, replicas: 4
kubectl replace -f a.yaml                         # ok, writes a new resourceVersion
kubectl replace -f b.yaml
# Error from server (Conflict): error when replacing "b.yaml": Operation cannot be fulfilled on
# deployments.apps "web": the object has been modified; please apply your changes to the latest
# version and try again
```

`metadata.resourceVersion` is a compare-and-swap key. `replace` sends the whole object including the
`resourceVersion` it read; the server writes only if the stored version still matches, otherwise HTTP
409. That is the whole concurrency model, and it is why a controller's update loop is **read, mutate,
write, and on 409 read again** (`retry.RetryOnConflict` in client-go; you will write one in week 28).

Why `kubectl apply` did not conflict when you used it all week: client-side apply sends a **patch**
with no `resourceVersion` precondition, so the server merges it onto whatever is current. Server-side
apply (`--server-side`) brings conflicts back in a different form: two **field managers** claiming the
same field get a 409 until one passes `--force-conflicts`. `kubectl get deploy web --show-managed-fields -o yaml`
shows who owns what.

## Part 3 — One request through the admission chain, in the audit log (60 min)

kind's control plane is a container, and the API server is a static pod inside it. Auditing needs two
flags and two files, so the clean route is a **second, throwaway kind cluster** created with the
flags in place (recreating `mastery` would cost you the week's state):

```bash
mkdir -p /tmp/audit && cat > /tmp/audit/policy.yaml <<'EOF'
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  - level: RequestResponse
    resources: [{ group: "", resources: ["pods", "pods/status"] }]
    namespaces: ["default"]
  - level: Metadata
EOF
cat > /tmp/audit/kind.yaml <<'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    extraMounts:
      - { hostPath: /tmp/audit, containerPath: /etc/kubernetes/audit }
    kubeadmConfigPatches:
      - |
        kind: ClusterConfiguration
        apiServer:
          extraArgs:
            audit-policy-file: /etc/kubernetes/audit/policy.yaml
            audit-log-path: /etc/kubernetes/audit/audit.log
          extraVolumes:
            - { name: audit, hostPath: /etc/kubernetes/audit, mountPath: /etc/kubernetes/audit, readOnly: false, pathType: DirectoryOrCreate }
EOF
kind create cluster --name audit --config /tmp/audit/kind.yaml
```

The alternative, if you would rather not create a cluster: `docker exec -it mastery-control-plane sh`,
write the policy under `/etc/kubernetes/audit/`, and edit `/etc/kubernetes/manifests/kube-apiserver.yaml`
to add the two flags, a `hostPath` volume and a `volumeMount`. The kubelet restarts the API server
when the manifest changes (that is Figure 14.2, badge ③, used in anger). The log then lives inside
the container and is lost when the cluster is recreated; the kind-config route keeps it on your disk.

Now make **one** request and find it:

```bash
kubectl --context kind-audit run audited --image=nginx:alpine
AUDIT=/tmp/audit/audit.log                         # docker-exec route: cat it out of the container
jq -c 'select(.objectRef.name=="audited" and .verb=="create" and .stage=="ResponseComplete")' $AUDIT \
  | jq '{user: .user.username, groups: .user.groups, verb, uri: .requestURI,
         decision: .annotations["authorization.k8s.io/decision"],
         reason:   .annotations["authorization.k8s.io/reason"],
         psa:      (.annotations | with_entries(select(.key | startswith("pod-security")))),
         code: .responseStatus.code, rv: .responseObject.metadata.resourceVersion}'
```

Read it as the chain the API server ran, in order:

| Stage | What the entry shows | Where it is decided |
|---|---|---|
| **authn** | `user.username: kubernetes-admin`, `groups: [kubeadm:cluster-admins, system:authenticated]` | the client certificate in your kubeconfig, mapped to a user and groups |
| **authz** | `authorization.k8s.io/decision: allow`, `reason: "RBAC: allowed by ClusterRoleBinding \"kubeadm:cluster-admins\" ..."` | the RBAC authorizer; the reason names the binding |
| **mutating admission** | the stored `responseObject` differs from your `requestObject`: `serviceAccountName`, a projected token volume, default tolerations, `restartPolicy`, scheduler name | built-in mutating plugins (ServiceAccount, DefaultTolerationSeconds, ...) then mutating webhooks |
| **validating admission** | `pod-security.admission.k8s.io/...` annotations if the namespace is labelled; a webhook's `*.webhook.admission.k8s.io/round_0_index_0` annotation when one exists | Pod Security Admission, then validating webhooks |
| **the write** | `responseStatus.code: 201` and the object's first `resourceVersion` | etcd, through the API server, the only writer |

Then make a request that is **refused** at each of three stages and find each one:

```bash
kubectl --context kind-audit --as=nobody get pods                   # authz: decision "forbid", reason "RBAC: no rules"
kubectl --context kind-audit label ns default pod-security.kubernetes.io/enforce=restricted
kubectl --context kind-audit run bad --image=nginx:alpine           # validating: PSA refuses; code 403, no write
kubectl --context kind-audit run bad2 --image=nginx:alpine --overrides='{"spec":{"nodeName":"nope"}}' # written, never runs: not admission's job
```

The last one is the lesson most people miss: admission validates the **object**, not the world.
`nodeName: nope` is a valid field with an invalid value; nothing refuses it, and the pod sits forever.
That is the kubelet's problem, and Figure 14.5's.

## Part 4 — An informer you wrote (40 min)

Python, because week 4 taught it and week 28 writes the Go version with kubebuilder. The pattern is
exactly Part 1 with the 410 handled:

```python
# informer.py -- list, then watch from that resourceVersion; on 410 relist. pip install kubernetes
from kubernetes import client, config, watch
from kubernetes.client.exceptions import ApiException

config.load_kube_config()
v1 = client.CoreV1Api()
cache = {}                                   # name -> phase: the informer's store

def relist():
    cache.clear()
    pods = v1.list_namespaced_pod("default")
    for p in pods.items:
        cache[p.metadata.name] = p.status.phase
    print(f"LIST rv={pods.metadata.resource_version} cached={len(cache)}")
    return pods.metadata.resource_version

rv = relist()
while True:
    try:
        for ev in watch.Watch().stream(v1.list_namespaced_pod, "default",
                                       resource_version=rv, timeout_seconds=60):
            p = ev["object"]; rv = p.metadata.resource_version
            if ev["type"] == "DELETED":
                cache.pop(p.metadata.name, None)
            else:
                cache[p.metadata.name] = p.status.phase
            print(f'{ev["type"]:9} {p.metadata.name:20} {p.status.phase or "":10} rv={rv}  cached={len(cache)}')
        # the 60 s timeout is the resync: the loop re-enters with the last rv, nothing is lost
    except ApiException as e:
        if e.status == 410:                  # too old: the window is gone, start over
            rv = relist()
        else:
            raise
```

Run it, create and delete pods, then restart the API server under it (`docker exec mastery-control-plane
sh -c 'mv /etc/kubernetes/manifests/kube-apiserver.yaml /tmp/ && sleep 20 && mv /tmp/kube-apiserver.yaml /etc/kubernetes/manifests/'`)
and watch it recover. That is what every controller in `kube-controller-manager` does, with three
additions you now know the names of: a **shared** cache so one watch serves many controllers, an
**index** so lookups by namespace or label are O(1), and a **workqueue** that dedupes the keys
handed to the reconcile function.

## Part 5 — Lists that hurt (15 min)

```bash
kubectl get pods -A --chunk-size=50 -v=6 2>&1 | grep -oE 'limit=[0-9]+|continue=[^&]{8}' | head
```

A list is paged: `limit=N` and a `continue` token in `metadata.continue`. Two facts decide whether a
list is cheap or expensive. A list with `resourceVersion=0` is served from the **watch cache** in the
API server's memory; a list with no `resourceVersion` is a quorum read straight from etcd, and a
large one from many clients at once is the classic way to take a cluster down. The cache has a size
per resource (`--watch-cache-sizes`) and **API Priority and Fairness** meters what gets through:

```bash
kubectl get flowschemas,prioritylevelconfigurations
kubectl get --raw /metrics | grep -E '^apiserver_flowcontrol_(current_inqueue_requests|rejected_requests_total)' | head
```

A 429 from the API server is APF saying no. Week 30's scale lab makes it say so on purpose.

**From memory, timed (20 min):** with the file closed, start a raw watch with curl from a fresh list,
produce a 409 with `replace`, and find one `create` in the audit log and name its five stages from
the entry. Target: under twenty minutes, and the five stages in order without looking.
