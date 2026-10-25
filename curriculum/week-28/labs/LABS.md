# Week 28 Labs

> **Figures:** one numbered mechanism figure per lab, with the spoken script, the numbers to own and
> the command that proves each badge, in [`FIGURES.md`](FIGURES.md) (28.2 to 28.6). Read a lab's figure
> before you start it; redraw it after.

> **Exam habit for the whole week:** generate, never type from scratch. `kubectl create <kind> ...
> --dry-run=client -o yaml > x.yaml`, edit, apply. The docs are open; copy the example, change the
> names. Speed is the skill being tested, and typing YAML from memory is the slow way to show it.

---

# Lab 1 — Kustomize, and Helm as an install tool (3h)

## Part 1 — A base and two overlays

```bash
mkdir -p shop/{base,overlays/dev,overlays/prod} && cd shop
kubectl create deploy web --image=nginx:1.27-alpine --replicas=1 --dry-run=client -o yaml > base/deployment.yaml
kubectl create service clusterip web --tcp=80:80 --dry-run=client -o yaml > base/service.yaml
cat > base/kustomization.yaml <<'EOF'
resources: [deployment.yaml, service.yaml]
commonLabels: { app.kubernetes.io/part-of: shop }
EOF
kubectl kustomize base | head -20          # rendered, nothing applied
```

```bash
cat > overlays/dev/kustomization.yaml <<'EOF'
namespace: shop-dev
namePrefix: dev-
resources: [../../base]
patches:
  - path: replicas.yaml               # strategic merge: a partial object, merged by field
configMapGenerator:
  - name: app-config
    literals: [LOG_LEVEL=debug]       # the name gets a content hash suffix: change the value, roll the pods
EOF
cat > overlays/dev/replicas.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata: { name: web }
spec: { replicas: 2 }
EOF

cat > overlays/prod/kustomization.yaml <<'EOF'
namespace: shop-prod
namePrefix: prod-
resources: [../../base]
patches:
  - target: { kind: Deployment, name: web }
    patch: |-                         # JSON patch: an operation on a path; the only way to touch list items by index
      - op: replace
        path: /spec/replicas
        value: 3
      - op: replace
        path: /spec/template/spec/containers/0/image
        value: nginx:1.27
      - op: add
        path: /spec/template/spec/containers/0/resources
        value: { requests: { cpu: 100m, memory: 64Mi }, limits: { cpu: 500m, memory: 128Mi } }
images:
  - name: nginx
    newTag: "1.27"                    # the kustomize-native way to do the second op above
EOF
kubectl create ns shop-dev shop-prod
kubectl apply -k overlays/dev && kubectl apply -k overlays/prod
kubectl get deploy,svc,cm -n shop-dev
kubectl get deploy -n shop-prod -o jsonpath='{.items[0].spec.replicas} {.items[0].spec.template.spec.containers[0].image}{"\n"}'
```

**Strategic merge vs JSON patch, the one sentence each:** a strategic merge patch is a fragment of the
object that Kubernetes merges by field name, with list items matched by their `name` key, so you
write what you want and the rest is left alone. A JSON patch is a list of operations with explicit
paths, which is the only way to say "the first container" or "remove this item". When a task says
"change X in the overlay", strategic merge; when it says "remove" or names an index, JSON.

**Tasks:**
1. `kubectl diff -k overlays/prod` after changing the prod replica count. Read the diff; that is the
   review step the exam does not give you time for and real life always should.
2. Add a `secretGenerator` to dev with a `password` literal and mount it as a file (week 14's rule).
3. Change `LOG_LEVEL` and re-apply. Watch the ConfigMap name change and the pods roll. Explain why a
   generator-named ConfigMap beats editing one in place.

## Part 2 — Helm as the exam uses it

The exam does not ask you to author charts (week 15 did). It asks you to **install, upgrade, roll back
and inspect** them.

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami && helm repo update
helm search repo bitnami/nginx --versions | head -4
helm show values bitnami/nginx | grep -n -E '^replicaCount|^service:' -A2 | head -12
helm install web bitnami/nginx -n helm-demo --create-namespace --set replicaCount=2 --set service.type=ClusterIP
helm list -A
helm get values web -n helm-demo                  # only what you set
helm get manifest web -n helm-demo | grep -c '^kind:'
helm upgrade web bitnami/nginx -n helm-demo --set replicaCount=3 --reuse-values
helm history web -n helm-demo
helm rollback web 1 -n helm-demo && helm history web -n helm-demo
helm template web bitnami/nginx --set replicaCount=1 | kubectl apply --dry-run=server -f -   # render then validate, without a release
helm uninstall web -n helm-demo
```

**Tasks:**
4. Install a specific chart **version** with `--version` and then `helm upgrade` to the next one.
   Read `helm history` and say what `superseded` and `deployed` mean.
5. `helm get manifest` and `kubectl get all -n helm-demo -l app.kubernetes.io/instance=web` must
   agree. Count the objects both ways.
6. A task says "the chart is at `/opt/chart`; install it as release `x` with values file `/opt/v.yaml`".
   Write the command without looking: `helm install x /opt/chart -f /opt/v.yaml -n <ns>`.

**Do it again, from memory, timed.** Part 1 (base, two overlays, both applied) in 8 minutes; the
Helm install/upgrade/rollback sequence in 4.

---

# Lab 2 — Gateway API, CoreDNS, and a Service with no selector (3h)

## Part 1 — Why Gateway API, in three sentences

Ingress is one object trying to be a listener, a route and an annotation bag for every controller's
extensions, and `ingressClassName` is all the structure it has. Gateway API splits the roles: the
**infrastructure provider** ships a GatewayClass, the **cluster operator** creates a Gateway (the
listeners), the **application developer** attaches HTTPRoutes (the rules) from their own namespace.
The blueprint added it in 2025 because that split is how multi-team clusters actually run.

## Part 2 — Install the CRDs and one implementation

The standard channel CRDs are a single manifest from the project's releases. The implementation is
**NGINX Gateway Fabric**, chosen because it is one Helm install, it supports a `NodePort` service
with a flag (no LoadBalancer exists on three VMs), and it implements the standard channel without
extras to learn. Any conformant implementation works the same way from the Route's point of view.

```bash
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/latest/download/standard-install.yaml
kubectl get crd | grep gateway.networking.k8s.io        # gatewayclasses, gateways, httproutes, grpcroutes, referencegrants
helm install ngf oci://ghcr.io/nginx/charts/nginx-gateway-fabric -n nginx-gateway --create-namespace --set service.type=NodePort
kubectl -n nginx-gateway get pods,svc
kubectl get gatewayclass                                  # nginx · controller gateway.nginx.org/nginx-gateway-controller · Accepted True
```

## Part 3 — Gateway, two backends, one HTTPRoute

```bash
kubectl create ns web
kubectl -n web create deploy v1 --image=nginx:1.27-alpine && kubectl -n web expose deploy v1 --port=80
kubectl -n web create deploy v2 --image=nginx:1.27-alpine && kubectl -n web expose deploy v2 --port=80
kubectl -n web exec deploy/v1 -- sh -c 'echo v1 > /usr/share/nginx/html/index.html'
kubectl -n web exec deploy/v2 -- sh -c 'echo v2 > /usr/share/nginx/html/index.html'
cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata: { name: shop, namespace: web }
spec:
  gatewayClassName: nginx
  listeners:
    - name: http
      port: 80
      protocol: HTTP
      allowedRoutes: { namespaces: { from: Same } }     # Same · All · Selector: the namespace boundary Ingress never had
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata: { name: shop, namespace: web }
spec:
  parentRefs: [{ name: shop }]
  hostnames: [shop.local]
  rules:
    - matches:
        - path: { type: PathPrefix, value: /api }
      backendRefs: [{ name: v2, port: 80 }]
    - matches:
        - headers: [{ name: x-canary, value: "true" }]
      backendRefs: [{ name: v2, port: 80 }]
    - matches:
        - path: { type: PathPrefix, value: / }
      backendRefs:
        - { name: v1, port: 80, weight: 90 }
        - { name: v2, port: 80, weight: 10 }
EOF
kubectl -n web get gateway shop -o jsonpath='{.status.conditions[*].type}{"\n"}'   # Accepted Programmed
kubectl -n web get httproute shop -o jsonpath='{.status.parents[0].conditions[*].reason}{"\n"}'   # Accepted ResolvedRefs
```

Where does traffic enter? The implementation created a Service for the Gateway; find its NodePort:

```bash
kubectl -n web get svc                      # shop-nginx (or similar): NodePort 3xxxx
NP=$(kubectl -n web get svc -l gateway.networking.k8s.io/gateway-name=shop -o jsonpath='{.items[0].spec.ports[0].nodePort}')
curl -s -H 'Host: shop.local' http://localhost:$NP/            # v1 (mostly)
curl -s -H 'Host: shop.local' http://localhost:$NP/api         # v2
curl -s -H 'Host: shop.local' -H 'x-canary: true' http://localhost:$NP/   # v2
for i in $(seq 20); do curl -s -H 'Host: shop.local' http://localhost:$NP/; done | sort | uniq -c   # ~18 v1, ~2 v2
```

**Tasks:**
1. Add a second listener on port 8080 named `alt` and an HTTPRoute attached only to it
   (`parentRefs[].sectionName`). Prove the host on port 80 does not serve it.
2. Put a Route in a different namespace and watch it be **rejected** until `allowedRoutes` says
   `All` (or a selector matches). This is the feature; say why it matters for a shared cluster.
3. Add a `filters: [{ type: RequestRedirect, requestRedirect: { scheme: https, statusCode: 301 } }]`
   rule and read the 301 with `curl -I`.
4. Describe the three-role split out loud, and name which object each role owns.

## Part 4 — CoreDNS, by hand

```bash
kubectl -n kube-system get cm coredns -o yaml | sed -n '/Corefile/,/kind/p'
```
Read the server block: `errors`, `health`, `ready`, `kubernetes cluster.local in-addr.arpa ip6.arpa`
(the plugin that answers for Services and Pods), `prometheus`, `forward . /etc/resolv.conf` (everything
else goes to the node's resolver), `cache 30`, `loop`, `reload`, `loadbalance`.

```bash
kubectl -n kube-system edit cm coredns
```
Add, **before** the `kubernetes` plugin line inside the `.:53 { ... }` block:
```
        rewrite name legacy.web.svc.cluster.local v1.web.svc.cluster.local
        hosts {
          10.10.0.250 printer.lab.internal
          fallthrough
        }
```
and a second server block **after** the first:
```
    lab.example:53 {
        errors
        forward . 10.10.0.2
    }
```
`reload` picks the file up within about 30 seconds; `kubectl -n kube-system rollout restart deploy coredns`
is faster and is what you do on the exam.

```bash
kubectl run -n web dns --rm -it --image=nicolaka/netshoot --restart=Never -- sh -c 'nslookup legacy.web; nslookup printer.lab.internal; cat /etc/resolv.conf'
```
`resolv.conf` in the pod: `nameserver 10.96.0.10`, `search web.svc.cluster.local svc.cluster.local cluster.local`,
`options ndots:5`. Say what `ndots:5` does to a lookup of `example.com` (four search-suffixed
queries before the real one) and why it matters at scale.

**Tasks:**
5. Break CoreDNS with a syntax error in the Corefile, watch the pods crash, read `kubectl -n kube-system logs deploy/coredns`,
   fix it. Every cluster you ever run will do this to someone.
6. Change `cache 30` to `cache 300` and explain what a Service IP change looks like to a pod for the
   next five minutes.

## Part 5 — A Service with no selector

```bash
# on k8s-w2: something listening outside Kubernetes
ssh k8s-w2 'nohup python3 -m http.server 9000 --directory /etc >/dev/null 2>&1 &'
W2=$(kubectl get node k8s-w2 -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata: { name: outside, namespace: web }
spec:
  ports: [{ port: 80, targetPort: 9000 }]         # no selector: nothing will create endpoints for it
---
apiVersion: discovery.k8s.io/v1
kind: EndpointSlice
metadata:
  name: outside-1
  namespace: web
  labels: { kubernetes.io/service-name: outside }   # this label is the whole link
addressType: IPv4
ports: [{ name: "", port: 9000, protocol: TCP }]
endpoints: [{ addresses: ["$W2"] }]
EOF
kubectl -n web get endpointslices -l kubernetes.io/service-name=outside
kubectl run -n web t --rm -it --image=nicolaka/netshoot --restart=Never -- curl -s outside/hostname | head -2
```

**Task 7:** delete the EndpointSlice and watch the Service go dark; recreate it with a wrong port and
read "connection refused". This is the week 14 one-line rule (no endpoints vs refused) with the
endpoints written by hand, which is exactly what makes the rule obvious.

**Do it again, from memory, timed.** Gateway + HTTPRoute with host, path, header and a split, proven
with curl, in 10 minutes. The CoreDNS edit in 4.

---

# Lab 3 — CRDs and operators (2h)

## Part 1 — Install an operator, read its CRDs

cert-manager: real, small enough to read, and its objects (Issuer, Certificate) are the kind of thing
an exam task says "create a Certificate resource named x using Issuer y" about.

```bash
helm repo add jetstack https://charts.jetstack.io && helm repo update
helm install cert-manager jetstack/cert-manager -n cert-manager --create-namespace --set crds.enabled=true
kubectl get crd | grep cert-manager.io
kubectl api-resources --api-group=cert-manager.io          # the short names the exam lets you use: cert, issuer, clusterissuer
kubectl explain certificate.spec | head -40
kubectl explain certificate.spec.privateKey                # the schema, from the CRD, exactly like a built-in type
```

## Part 2 — A custom resource, and watching the reconcile

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata: { name: selfsigned }
spec: { selfSigned: {} }
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata: { name: shop-tls, namespace: web }
spec:
  secretName: shop-tls
  dnsNames: [shop.local]
  issuerRef: { name: selfsigned, kind: ClusterIssuer }
EOF
kubectl -n web get certificate,certificaterequest,secret shop-tls
kubectl -n web describe certificate shop-tls | tail -8       # Events: Issuing → Generated → Requested → Ready
kubectl -n web get secret shop-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -subject -dates
```

**What just happened is the whole operator pattern:** a CRD taught the API server a new kind, a
controller watched for objects of that kind, and it created ordinary objects (a CertificateRequest,
then a Secret) to make the world match the spec. Week 14's control loop, with a kind you added.

## Part 3 — Your own CRD, with a schema that refuses

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata: { name: backups.ops.example.com }
spec:
  group: ops.example.com
  scope: Namespaced
  names: { plural: backups, singular: backup, kind: Backup, shortNames: [bk] }
  versions:
    - name: v1
      served: true
      storage: true
      additionalPrinterColumns:
        - { name: Target, type: string, jsonPath: .spec.target }
        - { name: Schedule, type: string, jsonPath: .spec.schedule }
      schema:
        openAPIV3Schema:
          type: object
          required: [spec]
          properties:
            spec:
              type: object
              required: [target, schedule]
              properties:
                target:   { type: string, enum: [etcd, postgres, s3] }
                schedule: { type: string, pattern: '^(\S+\s+){4}\S+$' }
                retainDays: { type: integer, minimum: 1, maximum: 365, default: 7 }
EOF
kubectl explain backup.spec
kubectl apply -f - <<'EOF'
apiVersion: ops.example.com/v1
kind: Backup
metadata: { name: nightly, namespace: web }
spec: { target: etcd, schedule: "0 2 * * *" }
EOF
kubectl -n web get bk                          # TARGET etcd · SCHEDULE 0 2 * * *
kubectl -n web get backup nightly -o jsonpath='{.spec.retainDays}{"\n"}'   # 7: the default was applied on write
kubectl apply -f - <<'EOF'
apiVersion: ops.example.com/v1
kind: Backup
metadata: { name: bad, namespace: web }
spec: { target: mysql, schedule: "whenever" }
EOF
# The server refuses with two reasons: not in enum, does not match pattern. No controller exists yet and the schema already protects you.
```

**Tasks:**
1. Add a second version `v2` with a renamed field, mark it `storage: true` and `v1` `storage: false`,
   and read what `kubectl get backup -o yaml` returns for the object you created as v1 (served at
   v2, converted by `None` strategy, so the renamed field is empty). Say why conversion webhooks exist.
2. `kubectl get crd backups.ops.example.com -o jsonpath='{.status.storedVersions}'`.
3. Delete the CRD and watch every Backup object vanish with it. Say it out loud before you do it.

**Do it again, from memory, timed.** The CRD with a required field, an enum and a printer column, plus
one valid and one rejected object, in 8 minutes. You will copy the skeleton from the docs page; the
skill is knowing which page.

---

# Lab 4 — Workloads and scheduling, under exam conditions (3h)

Every item below: generate with `--dry-run=client -o yaml`, edit, apply, verify, **under 3 minutes**.
Set a timer. Note the time in the journal. The reference files in the reading map explain each; this
lab is the speed, not the explanation.

## Part 1 — Jobs and CronJobs

```bash
kubectl create job pi --image=perl:5.34 -- perl -Mbignum=bpi -wle 'print bpi(2000)' --dry-run=client -o yaml > job.yaml
# edit: completions: 3, parallelism: 2, backoffLimit: 2, activeDeadlineSeconds: 120, ttlSecondsAfterFinished: 300
kubectl apply -f job.yaml && kubectl get job pi -w
kubectl create cronjob tick --image=busybox:1.36 --schedule='*/2 * * * *' -- date --dry-run=client -o yaml > cj.yaml
# edit: concurrencyPolicy: Forbid, successfulJobsHistoryLimit: 2, failedJobsHistoryLimit: 1, startingDeadlineSeconds: 60, and the jobTemplate's backoffLimit
kubectl apply -f cj.yaml
kubectl create job --from=cronjob/tick tick-now      # run one now: the exam's favourite CronJob question
kubectl get jobs,pods -l job-name
```

| Field | Default | Means |
|---|---|---|
| `completions` | 1 | how many pods must succeed |
| `parallelism` | 1 | how many run at once |
| `backoffLimit` | 6 | failed pods before the Job is marked Failed (exponential delay between) |
| `activeDeadlineSeconds` | none | wall clock after which the Job is killed, succeeded or not; beats backoffLimit |
| `ttlSecondsAfterFinished` | none | when the finished Job and its pods are deleted |
| `restartPolicy` | must be `Never` or `OnFailure` | `Always` is invalid in a Job |
| `concurrencyPolicy` | `Allow` | `Forbid` skips a run if the previous is still going; `Replace` kills it |
| `successfulJobsHistoryLimit` / `failed...` | 3 / 1 | how many finished Jobs the CronJob keeps |
| `startingDeadlineSeconds` | none | how late a missed run may start; past it the run is skipped and counted missed |

## Part 2 — DaemonSets

```bash
kubectl create deploy ds-skel --image=fluent/fluent-bit:latest --dry-run=client -o yaml | sed -e 's/kind: Deployment/kind: DaemonSet/' -e '/replicas:/d' -e '/strategy:/d' > ds.yaml
# There is no `kubectl create daemonset`; this sed trick, or the docs example, is the exam move.
# edit: add tolerations for the control-plane taint so it runs on k8s-cp too
kubectl apply -f ds.yaml && kubectl get ds,pods -o wide
```
```yaml
      tolerations:
        - key: node-role.kubernetes.io/control-plane
          operator: Exists
          effect: NoSchedule
```

## Part 3 — Placing pods, six ways

```bash
# 1 nodeName: bypasses the scheduler entirely. Pending never; wrong node name = stuck forever with no event.
kubectl run n1 --image=nginx:alpine --overrides='{"spec":{"nodeName":"k8s-w2"}}'
# 2 nodeSelector
kubectl label node k8s-w1 disk=ssd
kubectl run n2 --image=nginx:alpine --overrides='{"spec":{"nodeSelector":{"disk":"ssd"}}}'
# 3 required affinity (generate, then add the block from the docs)
kubectl run n3 --image=nginx:alpine --dry-run=client -o yaml > n3.yaml
# 4 taint and toleration
kubectl taint node k8s-w2 team=data:NoSchedule
kubectl run n4 --image=nginx:alpine --overrides='{"spec":{"nodeName":"k8s-w2"}}'            # nodeName ignores taints too: it runs
kubectl run n5 --image=nginx:alpine --overrides='{"spec":{"nodeSelector":{"kubernetes.io/hostname":"k8s-w2"}}}'   # Pending: untolerated taint
kubectl run n6 --image=nginx:alpine --overrides='{"spec":{"nodeSelector":{"kubernetes.io/hostname":"k8s-w2"},"tolerations":[{"key":"team","operator":"Equal","value":"data","effect":"NoSchedule"}]}}'
kubectl taint node k8s-w2 team-
# 5 PriorityClass
kubectl create priorityclass high --value=100000 --description="pre-empts the rest"
kubectl run n7 --image=nginx:alpine --overrides='{"spec":{"priorityClassName":"high"}}'
kubectl get priorityclass                      # system-cluster-critical and system-node-critical at 2000000000 and 2000001000
# 6 a static pod on a worker
ssh k8s-w1 'grep staticPodPath /var/lib/kubelet/config.yaml'                            # /etc/kubernetes/manifests
ssh k8s-w1 'sudo tee /etc/kubernetes/manifests/static-web.yaml >/dev/null <<EOF
apiVersion: v1
kind: Pod
metadata: { name: static-web }
spec: { containers: [{ name: web, image: nginx:alpine }] }
EOF'
kubectl get pods | grep static-web             # static-web-k8s-w1: the mirror pod carries the node name
kubectl delete pod static-web-k8s-w1 && kubectl get pods | grep static-web    # back: the file owns it, not the API
```

**Three effects of a taint:** `NoSchedule` (new pods stay away), `PreferNoSchedule` (soft),
`NoExecute` (running pods without a toleration are evicted, after `tolerationSeconds` if set). The
control plane's own taint is `node-role.kubernetes.io/control-plane:NoSchedule`, which is why your
DaemonSet needed a toleration and your Deployments never land on `k8s-cp`.

**Tasks:**
1. Required anti-affinity on a 3-replica Deployment with 2 workers: one pod Pending, and the event
   names the rule. Then preferred: all three schedule. Week 15 Lab 2, timed.
2. `kubectl get pod n1 -o yaml | grep -c schedulerName`: zero. Explain.
3. Taint `k8s-w1` with `NoExecute` and watch the pods leave in `get pods -w`. Remove it.

**Do it again, from memory, timed.** All of Parts 1 to 3 as a single run: fourteen objects in 30 minutes.

---

# Lab 5 — Storage on kubeadm, and Break/Fix (4h)

## Part 1 — There is no StorageClass

```bash
kubectl get sc                                   # No resources found. kubeadm ships none; a cloud did that for you in week 16.
kubectl create -f - <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata: { name: orphan }
spec: { accessModes: [ReadWriteOnce], resources: { requests: { storage: 1Gi } } }
EOF
kubectl get pvc orphan                           # Pending forever: no default class, no provisioner, no PV
kubectl describe pvc orphan | tail -3            # "no persistent volumes available for this claim and no storage class is set"
```

## Part 2 — A provisioner, and a default class

```bash
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
kubectl -n local-path-storage get pods
kubectl get sc                                   # local-path · rancher.io/local-path · Delete · WaitForFirstConsumer
kubectl patch sc local-path -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
kubectl get sc                                   # local-path (default)
kubectl get pvc orphan                           # still Pending: the class is resolved at CREATION; delete and recreate it
kubectl delete pvc orphan && kubectl create -f - <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata: { name: data }
spec: { accessModes: [ReadWriteOnce], resources: { requests: { storage: 1Gi } } }
EOF
kubectl get pvc data                             # Pending, correctly: WaitForFirstConsumer
kubectl run writer --image=busybox:1.36 --overrides='{"spec":{"containers":[{"name":"w","image":"busybox:1.36","command":["sh","-c","echo hello > /data/f; sleep 3600"],"volumeMounts":[{"name":"d","mountPath":"/data"}]}],"volumes":[{"name":"d","persistentVolumeClaim":{"claimName":"data"}}]}}'
kubectl get pvc data; kubectl get pv             # Bound, and a PV named pvc-<uid> on the node the pod landed on
kubectl get pv -o jsonpath='{.items[0].spec.nodeAffinity}{"\n"}'   # the PV is pinned to that node: this is why local storage is RWO and the pod cannot move
```

## Part 3 — Retain, by hand

```bash
ssh k8s-w2 'sudo mkdir -p /mnt/keep && echo kept | sudo tee /mnt/keep/file'
kubectl create -f - <<'EOF'
apiVersion: v1
kind: PersistentVolume
metadata: { name: keep }
spec:
  capacity: { storage: 1Gi }
  accessModes: [ReadWriteOnce]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath: { path: /mnt/keep }
  nodeAffinity: { required: { nodeSelectorTerms: [{ matchExpressions: [{ key: kubernetes.io/hostname, operator: In, values: [k8s-w2] }] }] } }
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata: { name: keep }
spec: { accessModes: [ReadWriteOnce], storageClassName: manual, resources: { requests: { storage: 1Gi } } }
EOF
kubectl get pv keep pvc keep                     # Bound to each other: class name + size + mode matched
kubectl delete pvc keep && kubectl get pv keep   # Released, not deleted; claimRef still set
kubectl patch pv keep --type=json -p '[{"op":"remove","path":"/spec/claimRef"}]'   # make it Available again, data intact
kubectl get pv keep                              # Available
```

## Part 4 — Expansion, and the field that refuses it

```bash
kubectl get sc local-path -o jsonpath='{.allowVolumeExpansion}{"\n"}'   # empty: false
kubectl patch pvc data -p '{"spec":{"resources":{"requests":{"storage":"2Gi"}}}}'
# persistentvolumeclaims "data" is forbidden: only dynamically provisioned pvc can be resized and the storageclass that provisions the pvc must support resize
kubectl patch sc local-path -p '{"allowVolumeExpansion":true}'
kubectl patch pvc data -p '{"spec":{"resources":{"requests":{"storage":"2Gi"}}}}'   # accepted by the API; the provisioner may not actually grow it
kubectl get pvc data -o jsonpath='{.status.conditions}{"\n"}'
```
The lesson is the **field**: `allowVolumeExpansion` on the class gates the API; whether the volume
grows is up to the CSI driver (EBS does, with a `FileSystemResizePending` step; local-path does not
really). Read `describe pvc` events either way.

**Tasks:**
1. Access modes on a real node: scale a Deployment with the `data` PVC to 2 replicas and force the
   second onto the other node with anti-affinity. It stays Pending; `describe` names the node affinity
   conflict. RWO on local storage means **one node**, and the PV knows which.
2. `reclaimPolicy: Delete` on the dynamic class: delete the `data` PVC, watch the PV go with it, and
   `ssh k8s-w1 ls /opt/local-path-provisioner/` to see the directory gone.
3. Set `volumeBindingMode: Immediate` on a copy of the class and show a PVC bind with no pod.

## Part 5 — Break/Fix (90 minutes)

Replay on the kubeadm cluster, timed, narrated, journaled:

| Scenario | Break | The node-level twist |
|---|---|---|
| BF-45 unschedulable | taint a worker `NoSchedule` | one of two workers: half the capacity, not a kind toy |
| BF-46 PVC Pending | `storageClassName: nonexistent` | and the Part 1 variant: no default class at all |
| BF-62 CNI | move the Calico conflist on `k8s-w2` | your Lab 4 pods on that node stop starting |
| BF-63 runtime | `systemctl stop containerd` on `k8s-w1` | the local-path PV on that node is unreachable: a storage symptom with a node cause |

The loop is [Figure BF.0](../../_shared/breakfix/FIGURE.md); the node scenarios are in
[`../../_shared/breakfix/08-cluster-nodes.md`](../../_shared/breakfix/08-cluster-nodes.md).

**Do it again, from memory, timed.** Parts 1 to 3 in 15 minutes: provisioner installed, default set,
a bound dynamic PVC, a Retain PV released and made Available again.
