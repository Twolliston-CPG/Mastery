# Week 28 Solutions

> Worked commands and manifests for every lab task, with what a correct run prints. Runs on the
> week 27 kubeadm cluster. Chart and image versions are whatever is current; nothing is pinned.

---

## Lab 1 — Kustomize and Helm

### Task 1 — diff before apply

```bash
sed -i 's/value: 3/value: 4/' overlays/prod/kustomization.yaml
kubectl diff -k overlays/prod
```
```
-  replicas: 3
+  replicas: 4
```
Exit code 1 when there is a diff, 0 when none: usable in a pipeline as "would this change anything".

### Task 2 — a generated Secret, mounted

```yaml
# overlays/dev/kustomization.yaml, add:
secretGenerator:
  - name: db
    literals: [password=s3cr3t]
patches:
  - path: replicas.yaml
  - path: mount.yaml
```
```yaml
# overlays/dev/mount.yaml
apiVersion: apps/v1
kind: Deployment
metadata: { name: web }
spec:
  template:
    spec:
      containers:
        - name: nginx
          volumeMounts: [{ name: db, mountPath: /etc/app, readOnly: true }]
      volumes: [{ name: db, secret: { secretName: db } }]
```
Kustomize rewrites `secretName: db` to the hashed name in the rendered output. Check with
`kubectl kustomize overlays/dev | grep secretName`.

### Task 3 — change the value, roll the pods

```bash
sed -i 's/LOG_LEVEL=debug/LOG_LEVEL=info/' overlays/dev/kustomization.yaml
kubectl apply -k overlays/dev
kubectl -n shop-dev get cm                 # two: app-config-<old> and app-config-<new> (prune with --prune or delete)
kubectl -n shop-dev rollout history deploy/dev-web   # a new revision
```
Editing the ConfigMap in place changes data but not the pod template hash, so no rollout; the new
value is only seen by pods restarted for some other reason, at unpredictable times. The generator
makes the change atomic and visible.

### Task 4 — versions and history

```bash
helm search repo bitnami/nginx --versions | sed -n 2,3p        # two most recent chart versions
helm install web bitnami/nginx -n helm-demo --create-namespace --version <older>
helm upgrade web bitnami/nginx -n helm-demo --version <newer>
helm history web -n helm-demo
```
```
REVISION  STATUS      CHART          DESCRIPTION
1         superseded  nginx-<older>  Install complete
2         deployed    nginx-<newer>  Upgrade complete
```
`superseded`: a revision that is no longer live but is kept for rollback. `deployed`: the one the
cluster currently reflects.

### Task 5 — the two counts agree

```bash
helm get manifest web -n helm-demo | grep -c '^kind:'
kubectl get all,cm,secret,sa -n helm-demo -l app.kubernetes.io/instance=web --no-headers | wc -l
```
Both counts match once you include the kinds `get all` omits (ConfigMaps, Secrets, ServiceAccounts).
The label `app.kubernetes.io/instance=<release>` is how you find a release's objects without Helm.

### Task 6 — the one-line install from a local chart

```bash
helm install x /opt/chart -f /opt/v.yaml -n team --create-namespace
```

---

## Lab 2 — Gateway API, CoreDNS, no-selector Service

### Task 1 — a second listener and a route pinned to it

```yaml
# add to spec.listeners of Gateway shop
    - name: alt
      port: 8080
      protocol: HTTP
      allowedRoutes: { namespaces: { from: Same } }
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata: { name: alt, namespace: web }
spec:
  parentRefs: [{ name: shop, sectionName: alt }]
  hostnames: [alt.local]
  rules:
    - backendRefs: [{ name: v2, port: 80 }]
```
```bash
NP80=$(kubectl -n web get svc -l gateway.networking.k8s.io/gateway-name=shop -o jsonpath='{.items[0].spec.ports[?(@.port==80)].nodePort}')
NP8080=$(kubectl -n web get svc -l gateway.networking.k8s.io/gateway-name=shop -o jsonpath='{.items[0].spec.ports[?(@.port==8080)].nodePort}')
curl -s -H 'Host: alt.local' http://localhost:$NP8080/     # v2
curl -s -o /dev/null -w '%{http_code}\n' -H 'Host: alt.local' http://localhost:$NP80/   # 404: the route is attached to the alt listener only
```

### Task 2 — a Route from another namespace

```bash
kubectl create ns other
kubectl -n other create deploy v3 --image=nginx:1.27-alpine && kubectl -n other expose deploy v3 --port=80
kubectl apply -f - <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata: { name: cross, namespace: other }
spec:
  parentRefs: [{ name: shop, namespace: web }]
  hostnames: [other.local]
  rules: [{ backendRefs: [{ name: v3, port: 80 }] }]
EOF
kubectl -n other get httproute cross -o jsonpath='{.status.parents[0].conditions[?(@.type=="Accepted")].reason}{"\n"}'
```
```
NotAllowedByListeners
```
Change the listener to `allowedRoutes: { namespaces: { from: All } }` and the reason becomes
`Accepted`. On a shared cluster `Same` (or a selector on a namespace label such as `team=shop`) is
what stops one team attaching routes to another team's listener.

### Task 3 — a redirect filter

```yaml
    - matches: [{ path: { type: PathPrefix, value: /old } }]
      filters:
        - type: RequestRedirect
          requestRedirect: { scheme: https, statusCode: 301 }
```
```bash
curl -sI -H 'Host: shop.local' http://localhost:$NP80/old | head -2
```
```
HTTP/1.1 301 Moved Permanently
Location: https://shop.local/old
```

### Task 4 — the three roles, spoken

Provider ships the GatewayClass (what controller, what capabilities). Operator creates Gateways
(which ports, which hostnames, which namespaces may attach). Developers create HTTPRoutes in their
own namespace and attach them. Each role changes its own object and never the others'.

### Task 5 — a broken Corefile

```bash
kubectl -n kube-system edit cm coredns     # delete the closing brace of the hosts block
kubectl -n kube-system rollout restart deploy coredns
kubectl -n kube-system get pods -l k8s-app=kube-dns    # CrashLoopBackOff
kubectl -n kube-system logs deploy/coredns
```
```
/etc/coredns/Corefile:14 - Error during parsing: Unknown directive 'kubernetes'   (or: Unexpected token)
```
Fix the brace, restart again. Name resolution across the whole cluster was down meanwhile: this is
the one ConfigMap edit that deserves `kubectl diff` first.

### Task 6 — cache 300

A pod that resolved `v1.web` gets the Service's ClusterIP from CoreDNS, which caches it for up to
300 s. ClusterIPs rarely change, but if the Service is deleted and recreated, pods see the old IP
and get connection refused or a timeout for up to five minutes. `cache 30` bounds that at thirty
seconds.

### Task 7 — the hand-written rule

```bash
kubectl -n web delete endpointslice outside-1
kubectl run -n web t --rm -it --image=nicolaka/netshoot --restart=Never -- curl -s -m 3 outside/ ; echo "exit $?"
# exit 28: timed out. No endpoints: the ClusterIP has no DNAT target, packets go nowhere.
# recreate with port 9001:
# curl: (7) Failed to connect ... Connection refused. Endpoints present, nothing listening on that port.
```

---

## Lab 3 — CRDs and operators

### Task 1 — a second version

```yaml
  versions:
    - name: v1
      served: true
      storage: false
      schema: { ... as before ... }
    - name: v2
      served: true
      storage: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              properties:
                target: { type: string, enum: [etcd, postgres, s3] }
                cron:   { type: string }          # renamed from schedule
                retainDays: { type: integer }
  conversion: { strategy: None }
```
```bash
kubectl -n web get backup nightly -o yaml | grep -A3 '^spec'
```
```
spec:
  retainDays: 7
  target: etcd
```
`schedule` is gone from the v2 view and `cron` is empty: `None` conversion only rewrites
`apiVersion`. A conversion webhook is a service the API server calls to translate between versions,
which is the only way a rename is invisible to clients.

### Task 2 — stored versions

```bash
kubectl get crd backups.ops.example.com -o jsonpath='{.status.storedVersions}{"\n"}'
```
```
["v1","v2"]
```
Objects written before the switch are still v1 on disk. Rewriting each object (a no-op `kubectl
replace`) migrates it; then v1 can be dropped from the list.

### Task 3 — delete the CRD

```bash
kubectl -n web get backups --no-headers | wc -l        # 1
kubectl delete crd backups.ops.example.com
kubectl -n web get backups
```
```
error: the server doesn't have a resource type "backups"
```
The objects are gone with the definition. In production, a CRD is deleted after the operator and
every instance, never before.

---

## Lab 4 — Workloads and scheduling

### Task 1 — anti-affinity, required then preferred

```yaml
# required: 3 replicas, 2 workers
spec:
  replicas: 3
  template:
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector: { matchLabels: { app: spread } }
              topologyKey: kubernetes.io/hostname
```
```bash
kubectl describe pod <the pending one> | tail -2
```
```
Warning  FailedScheduling  0/3 nodes are available: 1 node(s) had untolerated taint {node-role.kubernetes.io/control-plane: },
2 node(s) didn't match pod anti-affinity rules.
```
Change `required...` to `preferredDuringSchedulingIgnoredDuringExecution` (with `weight: 100` and
`podAffinityTerm:`) and the third pod lands on a node that already has one.

### Task 2 — no scheduler

```bash
kubectl get pod n1 -o yaml | grep -c schedulerName
```
```
0
```
A pod with `nodeName` set at creation is never seen by the scheduler: the kubelet on that node picks
it up directly. The field the scheduler would have written (`nodeName`) was already there, so nothing
ran, nothing scored, and nothing was recorded.

### Task 3 — NoExecute

```bash
kubectl taint node k8s-w1 drain=now:NoExecute
kubectl get pods -o wide -w          # every pod on k8s-w1 without a toleration goes Terminating within seconds; DaemonSet pods stay (they tolerate NoExecute by default)
kubectl taint node k8s-w1 drain-
```

### The timed run, as a checklist

| # | Object | Verify |
|---|---|---|
| 1 | Job pi | `get job pi` COMPLETIONS 3/3 |
| 2 | CronJob tick | `get cj` SCHEDULE */2 |
| 3 | Job from CronJob | `get jobs tick-now` |
| 4 | DaemonSet | one pod per node including cp |
| 5 | n1 nodeName | on k8s-w2 |
| 6 | n2 nodeSelector | on k8s-w1 |
| 7 | n3 required affinity | placed or Pending with the rule named |
| 8 | n4 nodeName through a taint | Running |
| 9 | n5 nodeSelector against a taint | Pending, `untolerated taint` |
| 10 | n6 with toleration | Running on k8s-w2 |
| 11 | PriorityClass high | `get priorityclass high` |
| 12 | n7 with priority | `get pod n7 -o jsonpath='{.spec.priority}'` 100000 |
| 13 | static-web on w1 | `static-web-k8s-w1` in `get pods` |
| 14 | delete the mirror | it returns |

---

## Lab 5 — Storage

### Task 1 — RWO on local storage across nodes

```yaml
spec:
  replicas: 2
  template:
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector: { matchLabels: { app: writer } }
              topologyKey: kubernetes.io/hostname
      volumes: [{ name: d, persistentVolumeClaim: { claimName: data } }]
```
```bash
kubectl describe pod <second> | tail -2
```
```
Warning  FailedScheduling  0/3 nodes are available: 1 node(s) had volume node affinity conflict, ...
```
The PV's `nodeAffinity` pins it to the first pod's node; anti-affinity forbids that node; nothing
satisfies both. On EBS the message is the same (a volume lives in one AZ); on EFS (`ReadWriteMany`)
it would not happen.

### Task 2 — Delete reclaim

```bash
kubectl delete pod writer; kubectl delete pvc data
kubectl get pv                                          # the pvc-<uid> PV is gone
ssh k8s-w1 'ls /opt/local-path-provisioner/'            # the directory is gone with it
```

### Task 3 — Immediate binding

```bash
kubectl get sc local-path -o yaml | sed -e 's/name: local-path$/name: local-path-now/' -e 's/WaitForFirstConsumer/Immediate/' -e '/is-default-class/d' -e '/resourceVersion\|uid:\|creationTimestamp/d' | kubectl apply -f -
kubectl create -f - <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata: { name: now }
spec: { accessModes: [ReadWriteOnce], storageClassName: local-path-now, resources: { requests: { storage: 1Gi } } }
EOF
kubectl get pvc now     # Bound within seconds, no pod; the PV is on whichever node the provisioner chose
```

### Break/Fix diagnoses

| BF | On kubeadm, what you see | Proof | Fix |
|---|---|---|---|
| 45 | half the Deployment Pending | `describe pod`: untolerated taint; `describe node k8s-w1 \| grep Taints` | remove the taint or tolerate it |
| 46 | PVC Pending | `describe pvc`: `storageclass.storage.k8s.io "nonexistent" not found`; the no-class variant: `no storage class is set` | fix the class name, or set a default and recreate |
| 62 | pods on w2 ContainerCreating | `describe pod`: `cni config uninitialized`; `ls /etc/cni/net.d` on w2 | restore the conflist |
| 63 | writer pod on w1 unreachable, node NotReady | `journalctl -u kubelet`: runtime status refused; `systemctl status containerd` | `systemctl start containerd`; the local volume is readable again |
