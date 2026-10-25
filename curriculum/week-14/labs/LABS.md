# Week 14 Labs

> **Figures:** one numbered mechanism figure per lab, with the spoken script, the numbers to own and
> the command that proves each badge, in [`FIGURES.md`](FIGURES.md) (14.2 to 14.6). Read a lab's figure
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
