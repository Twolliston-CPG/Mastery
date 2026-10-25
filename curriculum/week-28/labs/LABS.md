# Week 28 Labs

> **Figures:** one numbered mechanism figure per lab, with the spoken script, the numbers to own and
> the command that proves each badge, in [`FIGURES.md`](FIGURES.md) (28.2 to 28.6; 28.7 to 28.9 for the "Go deeper" labs at the end). Read a lab's figure
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

---

# Go deeper — Write the controller (4h · ladder: controllers, rung 4; API machinery, rung 4)

**Optional inside the week, mandatory for the ladder** ([`KUBERNETES-MASTERY.md`](../../../KUBERNETES-MASTERY.md)).
Lab 3 taught the API server a kind and watched cert-manager reconcile one. This lab is the other half:
the `Backup` kind gets a controller you wrote, with every part a production operator has. Nothing here
is on the exam. All of it is what "I understand how Kubernetes works" means in an interview.

**Setup.** Go (the version kubebuilder's release notes require; 1.23 or newer at the time of writing,
check the project's README) and kubebuilder on the laptop. The controller runs **on the laptop** against
the kubeadm cluster through the IAP tunnel, so the edit-run loop is seconds:

```bash
gcloud compute start-iap-tunnel k8s-cp 6443 --local-host-port=localhost:6443 &   # from _setup/gcp-lab: terraform output kubeadm_api_tunnel
gcloud compute ssh k8s-cp --tunnel-through-iap -- sudo cat /etc/kubernetes/admin.conf > ~/.kube/k8s-cp.conf
# The serving certificate names `kubernetes` and the node's addresses, not localhost:
kubectl --kubeconfig ~/.kube/k8s-cp.conf config set-cluster kubernetes --server=https://localhost:6443 --tls-server-name=kubernetes
export KUBECONFIG=~/.kube/k8s-cp.conf
kubectl get nodes          # three nodes; you are talking to the real cluster from the laptop
kubectl delete crd backups.ops.example.com   # Lab 3's hand-written CRD; kubebuilder generates its own with the same name
```

## Part 1 — Scaffold, then read everything it generated (45 min)

```bash
mkdir backup-operator && cd backup-operator
kubebuilder init --domain example.com --repo example.com/backup-operator
kubebuilder create api --group ops --version v1 --kind Backup --resource --controller
tree -L 3 api internal config cmd
```

Group `ops` plus domain `example.com` is the API group `ops.example.com`, so the CRD it generates has
the same name as Lab 3's. Now read, in this order, because each file answers the previous one's question:

| File | What it is | The question it answers |
|---|---|---|
| `api/v1/backup_types.go` | the Go structs that **are** the schema | where does `kubectl explain backup.spec` come from |
| `api/v1/zz_generated.deepcopy.go` | generated `DeepCopy` methods | why the cache can hand you a copy without you corrupting it |
| `config/crd/bases/ops.example.com_backups.yaml` | the CRD, generated from the markers | the YAML you wrote by hand in Lab 3, now a build artefact |
| `config/rbac/role.yaml` | a ClusterRole, generated from `+kubebuilder:rbac` markers | week 15 Lab 4, applied to a controller instead of a person |
| `internal/controller/backup_controller.go` | an empty `Reconcile` and `SetupWithManager` | the loop |
| `cmd/main.go` | the manager: scheme, metrics, health, leader election flags | the process that owns the loop |

Replace the generated spec and status with Lab 3's schema, as markers:

```go
// api/v1/backup_types.go
type BackupSpec struct {
	// +kubebuilder:validation:Enum=etcd;postgres;s3
	Target string `json:"target"`
	// +kubebuilder:validation:Pattern=`^(\S+\s+){4}\S+$`
	Schedule string `json:"schedule"`
	// +kubebuilder:default=7
	// +kubebuilder:validation:Minimum=1
	// +kubebuilder:validation:Maximum=365
	// +optional
	RetainDays int32 `json:"retainDays,omitempty"`
}

type BackupStatus struct {
	// The generation the controller last acted on. Equal to metadata.generation when the spec has been reconciled.
	ObservedGeneration int64 `json:"observedGeneration,omitempty"`
	// Copied from the CronJob so `kubectl get bk` can show it.
	LastScheduleTime *metav1.Time `json:"lastScheduleTime,omitempty"`
	// +listType=map
	// +listMapKey=type
	Conditions []metav1.Condition `json:"conditions,omitempty"`
}

// +kubebuilder:object:root=true
// +kubebuilder:subresource:status
// +kubebuilder:resource:shortName=bk
// +kubebuilder:printcolumn:name="Target",type=string,JSONPath=`.spec.target`
// +kubebuilder:printcolumn:name="Schedule",type=string,JSONPath=`.spec.schedule`
// +kubebuilder:printcolumn:name="Ready",type=string,JSONPath=`.status.conditions[?(@.type=="Ready")].status`
type Backup struct { /* generated: TypeMeta, ObjectMeta, Spec, Status */ }
```

```bash
make manifests generate       # regenerates the CRD YAML and the deepcopy from the markers
git diff config/crd            # read what changed: enum, pattern, default, the status subresource, the printer columns
make install                   # applies the CRD; `kubectl explain backup.spec.target` now says the enum
```

**Say it:** the status **subresource** is why `kubectl apply` of a spec cannot touch status and why the
controller writes status through a different endpoint (`/status`). Two writers, two endpoints, no
fight. Week 14's ReplicaSet does exactly this.

## Part 2 — The reconcile loop (75 min)

A controller does one thing: given the name of an object, make the world match that object, then
return. It does not know *why* it was called. It may be called ten times for one change, or once for
ten changes. So reconcile is **level-triggered** (look at the current state, not the event) and
**idempotent** (running it twice changes nothing the second time). Write it that way and every other
property follows.

```go
// internal/controller/backup_controller.go
package controller

import (
	"context"
	"fmt"

	batchv1 "k8s.io/api/batch/v1"
	corev1 "k8s.io/api/core/v1"
	apierrors "k8s.io/apimachinery/pkg/api/errors"
	"k8s.io/apimachinery/pkg/api/meta"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	logf "sigs.k8s.io/controller-runtime/pkg/log"

	opsv1 "example.com/backup-operator/api/v1"
)

type BackupReconciler struct {
	client.Client
	Scheme *runtime.Scheme
}

// +kubebuilder:rbac:groups=ops.example.com,resources=backups,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=ops.example.com,resources=backups/status,verbs=get;update;patch
// +kubebuilder:rbac:groups=batch,resources=cronjobs,verbs=get;list;watch;create;update;patch;delete

func (r *BackupReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	log := logf.FromContext(ctx)

	// 1. Read the object. Not found means deleted: the CronJob carries an owner reference,
	//    so garbage collection removes it. There is nothing for us to do.
	var backup opsv1.Backup
	if err := r.Get(ctx, req.NamespacedName, &backup); err != nil {
		return ctrl.Result{}, client.IgnoreNotFound(err)
	}

	// 2. Compute what should exist, from the spec alone.
	desired := cronJobFor(&backup)
	if err := ctrl.SetControllerReference(&backup, desired, r.Scheme); err != nil {
		return ctrl.Result{}, err
	}

	// 3. Compare with what does exist. Create, update, or leave alone.
	var current batchv1.CronJob
	err := r.Get(ctx, client.ObjectKeyFromObject(desired), &current)
	switch {
	case apierrors.IsNotFound(err):
		if err := r.Create(ctx, desired); err != nil {
			return ctrl.Result{}, err // returning an error requeues with backoff
		}
		log.Info("created CronJob", "cronjob", desired.Name)
		current = *desired
	case err != nil:
		return ctrl.Result{}, err
	default:
		if current.Spec.Schedule != desired.Spec.Schedule ||
			current.Spec.JobTemplate.Spec.Template.Spec.Containers[0].Args[0] != desired.Spec.JobTemplate.Spec.Template.Spec.Containers[0].Args[0] {
			current.Spec.Schedule = desired.Spec.Schedule
			current.Spec.JobTemplate = desired.Spec.JobTemplate
			if err := r.Update(ctx, &current); err != nil {
				return ctrl.Result{}, err // a 409 conflict lands here; the requeue retries against a fresh read
			}
			log.Info("updated CronJob", "cronjob", current.Name)
		}
	}

	// 4. Report. Status goes through the /status subresource, never with the spec.
	backup.Status.ObservedGeneration = backup.Generation
	backup.Status.LastScheduleTime = current.Status.LastScheduleTime
	meta.SetStatusCondition(&backup.Status.Conditions, metav1.Condition{
		Type:               "Ready",
		Status:             metav1.ConditionTrue,
		Reason:             "CronJobExists",
		Message:            fmt.Sprintf("CronJob %s is scheduled %q", current.Name, current.Spec.Schedule),
		ObservedGeneration: backup.Generation,
	})
	if err := r.Status().Update(ctx, &backup); err != nil {
		return ctrl.Result{}, err
	}
	return ctrl.Result{}, nil
}

func cronJobFor(b *opsv1.Backup) *batchv1.CronJob {
	return &batchv1.CronJob{
		ObjectMeta: metav1.ObjectMeta{Name: "backup-" + b.Name, Namespace: b.Namespace},
		Spec: batchv1.CronJobSpec{
			Schedule:          b.Spec.Schedule,
			ConcurrencyPolicy: batchv1.ForbidConcurrent,
			JobTemplate: batchv1.JobTemplateSpec{
				Spec: batchv1.JobSpec{
					Template: corev1.PodTemplateSpec{
						Spec: corev1.PodSpec{
							RestartPolicy: corev1.RestartPolicyNever,
							Containers: []corev1.Container{{
								Name:    "backup",
								Image:   "busybox:1.36",
								Command: []string{"sh", "-c"},
								Args:    []string{fmt.Sprintf("echo backing up %s, keeping %d days", b.Spec.Target, b.Spec.RetainDays)},
							}},
						},
					},
				},
			},
		},
	}
}

func (r *BackupReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&opsv1.Backup{}).
		Owns(&batchv1.CronJob{}). // Part 3
		Named("backup").
		Complete(r)
}
```

```bash
make manifests          # the rbac markers became config/rbac/role.yaml; read the diff
make run                # runs the manager on the laptop; logs say "Starting workers"
# second terminal
kubectl -n web apply -f - <<'EOF'
apiVersion: ops.example.com/v1
kind: Backup
metadata: { name: nightly }
spec: { target: etcd, schedule: "0 2 * * *" }
EOF
kubectl -n web get bk,cronjob                               # READY True · backup-nightly 0 2 * * *
kubectl -n web get cronjob backup-nightly -o jsonpath='{.metadata.ownerReferences[0].kind}{"\n"}'   # Backup
kubectl -n web patch bk nightly --type=merge -p '{"spec":{"schedule":"0 3 * * *"}}'
kubectl -n web get cronjob backup-nightly -o jsonpath='{.spec.schedule}{"\n"}'                      # 0 3 * * *: the update branch
kubectl -n web get bk nightly -o jsonpath='{.metadata.generation} {.status.observedGeneration}{"\n"}'   # 2 2
kubectl -n web delete bk nightly && sleep 2 && kubectl -n web get cronjob                            # gone: the owner reference, not your code
```

**What you did not write, and must be able to explain:**

- **The informer and the cache.** `r.Get` did not call the API server. The manager opened one
  list-then-watch per kind you touch (`Backup`, `CronJob`), keeps a local copy of every object, and
  answers reads from it. Writes go to the server. That is why a controller is cheap to the API server
  at steady state and expensive at startup (the list), and why a thousand controllers listing pods is a
  real scaling problem.
- **The workqueue.** Every event from the watch becomes a key (`namespace/name`) on a queue. Keys are
  de-duplicated: ten edits while you are busy become one reconcile. That is the "may be called once
  for ten changes" above, and it is why reconcile reads the current state instead of the event.
- **Rate limiting and requeue.** Return an error and the key goes back on the queue with exponential
  backoff (5 ms doubling toward about 17 minutes by default). Return `ctrl.Result{RequeueAfter: time.Hour}`
  to come back on a timer with no error. A crash loop in a controller is a reconcile that errors forever
  on the same key; the queue protects the API server from it.
- **Optimistic concurrency.** Your `Update` sends the object's `resourceVersion`. If someone else wrote
  in between, the server answers 409 and the requeue retries with a fresh read. No locks anywhere in
  the system; this is the whole concurrency model, and `kubectl edit` races the same way.

Read `pkg/controller/deployment/deployment_controller.go` in the Kubernetes source: the same shape,
`syncDeployment` as the reconcile, a workqueue, informers, and the ReplicaSets it owns. Then
`kubernetes/sample-controller` (the pattern with no framework) and the `controller-runtime` book
(the framework you just used).

## Part 3 — Watches: owning what you create (20 min)

`Owns(&batchv1.CronJob{})` registers a second watch and maps any CronJob event back to the Backup in
its owner reference. Delete the child and the parent is reconciled:

```bash
kubectl -n web apply -f nightly.yaml
kubectl -n web delete cronjob backup-nightly && sleep 1 && kubectl -n web get cronjob     # back, with a new creationTimestamp
# watch the manager's log: a reconcile for web/nightly, "created CronJob"
```

Without `Owns`, the CronJob would stay deleted until the next Backup event. That is the difference
between "I created it once" and "I keep it existing", and it is what the word *controller* means.

## Part 4 — Leader election (30 min)

Two copies of a controller both reconciling is two writers racing. The manager takes a Lease and only
the holder runs workers. Do it in-cluster, where the scaffold already passes `--leader-elect`:

```bash
make docker-build docker-push IMG=<your-registry>/backup-operator:dev     # ECR from week 12, or any registry the nodes can pull from
make deploy IMG=<your-registry>/backup-operator:dev
kubectl -n backup-operator-system scale deploy backup-operator-controller-manager --replicas=2
kubectl -n backup-operator-system get lease                               # one Lease; HOLDER is one pod's identity
kubectl -n backup-operator-system get lease -o jsonpath='{.items[0].spec.holderIdentity}{"\n"}'
kubectl -n backup-operator-system delete pod <the holder>
watch -n1 'kubectl -n backup-operator-system get lease -o jsonpath="{.items[0].spec.holderIdentity}{\"\n\"}"'   # moves within leaseDurationSeconds (15 s default)
kubectl -n backup-operator-system logs deploy/backup-operator-controller-manager --all-pods | grep -i 'leader'
```

Say what the non-leader does: nothing. It holds the informers warm and waits. The control plane's own
controller-manager and scheduler use exactly this Lease in `kube-system`; `kubectl -n kube-system get
lease` shows them, and a control-plane failover in week 27 was this object changing hands.

## Part 5 — A validating webhook (45 min)

The schema's pattern accepts `0 2 * * *` and also `a b c d e`. Validation that needs code lives in a
webhook: the API server calls your HTTPS endpoint during admission and refuses the write if you say so.

```bash
kubebuilder create webhook --group ops --version v1 --kind Backup --programmatic-validation
go get github.com/robfig/cron/v3
```

```go
// internal/webhook/v1/backup_webhook.go (the generated validator; fill in the two methods)
func (v *BackupCustomValidator) ValidateCreate(ctx context.Context, obj runtime.Object) (admission.Warnings, error) {
	return nil, validateSchedule(obj.(*opsv1.Backup))
}
func (v *BackupCustomValidator) ValidateUpdate(ctx context.Context, _, newObj runtime.Object) (admission.Warnings, error) {
	return nil, validateSchedule(newObj.(*opsv1.Backup))
}
func validateSchedule(b *opsv1.Backup) error {
	if _, err := cron.ParseStandard(b.Spec.Schedule); err != nil {
		return field.Invalid(field.NewPath("spec", "schedule"), b.Spec.Schedule, err.Error())
	}
	return nil
}
```

The webhook needs a serving certificate the API server trusts. The scaffold expects cert-manager, which
Lab 3 installed: in `config/default/kustomization.yaml` uncomment the `[WEBHOOK]` and `[CERTMANAGER]`
sections, then:

```bash
make manifests && make docker-build docker-push IMG=... && make deploy IMG=...
kubectl -n backup-operator-system get certificate,validatingwebhookconfiguration
kubectl -n web apply -f - <<'EOF'
apiVersion: ops.example.com/v1
kind: Backup
metadata: { name: bad }
spec: { target: etcd, schedule: "a b c d e" }
EOF
# Error from server (Forbidden): admission webhook "vbackup-v1.kb.io" denied the request: spec.schedule: Invalid value: "a b c d e": ...
```

Read the `ValidatingWebhookConfiguration`: `failurePolicy`, `timeoutSeconds`, the `caBundle` that
cert-manager injected. Then say week 19's lesson again, now that you own one: a webhook with
`failurePolicy: Fail` that is down blocks every write to its kinds, and a webhook that matches all
kinds can block the cluster.

## Part 6 — What a controller costs (15 min)

```bash
kubectl get --raw /metrics | grep -E '^apiserver_(registered_watchers|longrunning_requests)' | grep -iE 'backups|cronjobs'
kubectl -n backup-operator-system top pod       # the informer cache is memory: every CronJob in the cluster, if you watch cluster-wide
```

Two watches, cluster-wide, because the scaffold's manager has no namespace restriction. A controller
that watches Pods on a 5,000-node cluster holds every Pod in memory and receives every Pod event. The
fixes are cache options (`cache.Options{ByObject: ...}` with label selectors, or a namespace list) and
owning less. Say why "just write an operator" is a cost before it is a feature.

**Do it again, from memory, timed.** Parts 1 to 3 (scaffold, types with markers, the reconcile with
create-or-update and status, `Owns`) in 60 minutes, with the controller-runtime docs open. The code
above is the answer key; the skill is knowing which markers and which calls.

---

# Go deeper — The Service datapath, three ways (3h · ladder: networking datapath, rung 3)

**Optional inside the week, mandatory for the ladder.** Week 14 said "kube-proxy writes iptables rules"
and left it there. This lab reads those rules for one Service, traces one packet through them, then
replaces the mechanism twice (IPVS, nftables) and once more with eBPF, so the sentence "a Service is a
virtual IP" becomes four specific things you have seen. On the kubeadm cluster, as root on the nodes.

```bash
kubectl -n web create deploy web --image=nginx:1.27-alpine --replicas=2 && kubectl -n web expose deploy web --port=80
kubectl -n web get svc web -o jsonpath='{.spec.clusterIP}{"\n"}'          # the virtual IP, call it $VIP
kubectl -n web get endpointslices -l kubernetes.io/service-name=web -o wide  # two pod IPs, call them $POD1 $POD2
kubectl -n web run client --image=nicolaka/netshoot --restart=Never -- sleep 1d
```

## Part 1 — iptables: the chain you can read (60 min)

On `k8s-cp` (or whichever node runs `client`):

```bash
sudo apt-get install -y conntrack
sudo iptables -t nat -S KUBE-SERVICES | grep $VIP
#   -A KUBE-SERVICES -d $VIP/32 -p tcp -m comment --comment "web/web cluster IP" -m tcp --dport 80 -j KUBE-SVC-XXXX
sudo iptables -t nat -S KUBE-SVC-XXXX
#   -A KUBE-SVC-XXXX ! -s 192.168.0.0/16 -d $VIP/32 ... -j KUBE-MARK-MASQ        <- traffic from outside the pod CIDR gets SNAT on the way back
#   -A KUBE-SVC-XXXX -m statistic --mode random --probability 0.50000000000 -j KUBE-SEP-AAAA
#   -A KUBE-SVC-XXXX -j KUBE-SEP-BBBB
sudo iptables -t nat -S KUBE-SEP-AAAA
#   -A KUBE-SEP-AAAA -s $POD1/32 -j KUBE-MARK-MASQ                                   <- hairpin: a pod talking to its own Service
#   -A KUBE-SEP-AAAA -p tcp -m tcp -j DNAT --to-destination $POD1:80
```

Say the path out loud: PREROUTING (or OUTPUT for a local process) → `KUBE-SERVICES` matches the
destination VIP and port → `KUBE-SVC-*` picks an endpoint with a **random probability per rule**
(first rule 1/2, then the remainder, so 1/N each; for three endpoints the probabilities are 0.333,
0.5, 1.0) → `KUBE-SEP-*` **DNATs** the destination to a pod IP. The reply is un-NATed by conntrack,
not by a rule:

```bash
kubectl -n web exec client -- curl -s -o /dev/null web
sudo conntrack -L -d $VIP 2>/dev/null | head -3
#   tcp 6 ... src=<client pod> dst=$VIP sport=... dport=80 src=$POD1 dst=<client pod> sport=80 ...   <- one entry, both directions, the translation remembered
```

Trace one request on the wire. The client pod's veth on the node is the interface whose index matches
the pod's `eth0` peer:

```bash
IDX=$(kubectl -n web exec client -- cat /sys/class/net/eth0/iflink)
VETH=$(ip -o link | awk -v i="$IDX:" '$1==i {print $2}' | cut -d@ -f1)       # cali... on Calico
sudo tcpdump -ni "$VETH" port 80 &                                             # before DNAT: dst is $VIP
sudo tcpdump -ni any "host $POD1 and port 80" &                                # after DNAT: dst is $POD1
kubectl -n web exec client -- curl -s -o /dev/null web; sleep 1; sudo pkill tcpdump
```

The same packet, two addresses, one on each side of the nat table. That is the whole of "virtual".

**`externalTrafficPolicy` lives here too.** Make the Service a NodePort and read `KUBE-NODEPORTS`
and `KUBE-EXT-*`. With the default `Cluster`, a packet arriving on `k8s-w2` for a pod on `k8s-w1`
is SNATed to `k8s-w2`'s address (`KUBE-MARK-MASQ`, then `MASQUERADE` in POSTROUTING) so the reply
comes back through the same node; the pod sees the node's IP, not the client's. With `Local`, the
masquerade rule is gone, only local endpoints are in the chain, and a node with no endpoint drops
the packet: source IP preserved, at the cost of uneven balancing and a health-check port
(`healthCheckNodePort`) the load balancer must use. Say both halves.

## Part 2 — IPVS: a hash table instead of a list (40 min)

Every Service adds rules to the chain, and every packet walks the list. IPVS is the kernel's load
balancer: a hash lookup per packet, and real scheduling algorithms.

```bash
# on every node
sudo apt-get install -y ipset ipvsadm
for m in ip_vs ip_vs_rr ip_vs_wrr ip_vs_sh nf_conntrack; do sudo modprobe $m; done
# then
kubectl -n kube-system edit cm kube-proxy          # mode: "ipvs"
kubectl -n kube-system rollout restart ds kube-proxy
kubectl -n kube-system logs -l k8s-app=kube-proxy --tail=5 | grep -i 'proxier'   # "Using ipvs Proxier"
sudo ipvsadm -Ln | grep -A2 $VIP
#   TCP  $VIP:80 rr
#     -> $POD1:80   Masq    1      0          0
#     -> $POD2:80   Masq    1      0          0
ip addr show kube-ipvs0 | grep inet | head          # every ClusterIP, bound to a dummy interface so the kernel accepts them locally
sudo ipset list KUBE-CLUSTER-IP | head -12           # iptables is still there, for the masquerade decision, but it matches an ipset: one rule, not one per Service
```

`rr` is round robin; `kube-proxy`'s `ipvs.scheduler` can be `lc`, `sh` (source hash, which gives
you sticky clients for free) and others. Say why this scales: ten thousand Services are ten thousand
hash entries, not ten thousand rules walked in order, and conntrack still does the replies.

## Part 3 — nftables: the one kube-proxy is moving to (30 min)

nftables is the kernel's replacement for iptables; the proxy's nftables backend went GA in a recent
release (check the kube-proxy page for your version). It uses **verdict maps**: a single lookup of
the destination address and port returns the chain to jump to, which is the hash-table property IPVS
had, inside the firewall that iptables mode had.

```bash
sudo apt-get install -y nftables                      # every node
kubectl -n kube-system edit cm kube-proxy             # mode: "nftables"
kubectl -n kube-system rollout restart ds kube-proxy
sudo nft list table ip kube-proxy | less
#   map service-ips { type ipv4_addr . inet_proto . inet_service : verdict ... elements = { $VIP . tcp . 80 : goto service-XXXX-web/web/tcp/ } }
#   chain service-XXXX-web/web/tcp/ { ... numgen random mod 2 vmap { 0 : goto endpoint-AAAA..., 1 : goto endpoint-BBBB... } }
#   chain endpoint-AAAA... { ... dnat to $POD1:80 }
```

Compare to Part 1: the `KUBE-SERVICES` chain of N rules became one map lookup; the probability rules
became `numgen random mod N vmap`; the DNAT is the same. `conntrack -L` shows the same entry as before,
because the kernel's connection tracking did not change. Three mechanisms, one conntrack.

## Part 4 — EndpointSlices: what feeds all three (15 min)

```bash
kubectl -n web get endpointslices -l kubernetes.io/service-name=web -o yaml | head -40
kubectl -n web scale deploy web --replicas=5 && kubectl -n web get endpointslices -l kubernetes.io/service-name=web
```

kube-proxy does not watch Pods. It watches EndpointSlices, written by the endpointslice controller
(`pkg/controller/endpointslice`) from the Service's selector and the pods' readiness. Each slice holds
up to 100 endpoints by default (`--max-endpoints-per-slice`), so a change to one pod rewrites one
slice, not one object with every address in it; that is what made large Services cheap. The older
`Endpoints` object is still written for compatibility and is on its way out. A Service with no
endpoints, week 14 badge ⑪, is an empty slice; `-o yaml` shows you exactly why (no matching pods,
or `conditions.ready: false`).

## Part 5 — Cilium: no kube-proxy at all (30 min, on kind)

```bash
cat > kind-cilium.yaml <<'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking: { disableDefaultCNI: true, kubeProxyMode: none }
nodes: [{ role: control-plane }, { role: worker }]
EOF
kind create cluster --name cilium --config kind-cilium.yaml
cilium install --set kubeProxyReplacement=true \
  --set k8sServiceHost=$(docker inspect cilium-control-plane -f '{{.NetworkSettings.Networks.kind.IPAddress}}') --set k8sServicePort=6443
cilium status --wait
kubectl create deploy web --image=nginx:1.27-alpine --replicas=2 && kubectl expose deploy web --port=80
kubectl -n kube-system exec ds/cilium -- cilium-dbg service list | grep -A2 web        # the Service, as Cilium sees it
kubectl -n kube-system exec ds/cilium -- cilium-dbg bpf lb list | grep -A3 "$(kubectl get svc web -o jsonpath='{.spec.clusterIP}')"
kubectl -n kube-system exec ds/cilium -- iptables -t nat -S | grep -c KUBE-SVC            # 0
```

What moved: the translation happens in eBPF programs attached to the pod's veth and, for pod-originated
connections, at the socket layer (`connect()` is rewritten to the pod IP before any packet exists), so
there is no per-packet NAT and no conntrack entry for the Service at all. kube-proxy's job is gone; the
rules are maps in the kernel, updated by the agent. Say why the ecosystem went this way: fewer hops,
observability at the same hook (Hubble), and policy enforced in the same program. Then `kind delete
cluster --name cilium`.

**Do it again, from memory, timed.** Part 1 for a new Service in 15 minutes: find the three chains,
read the probability, show the DNAT, show the conntrack entry, trace the packet on both sides.

---

# Go deeper — DNS, five queries for one name (2h · ladder: DNS, rung 3)

**Optional inside the week, mandatory for the ladder.** Lab 2 edited the Corefile. This lab is what a
pod actually sends when it asks for a name, why one lookup can be ten packets, how CoreDNS decides
which plugin answers, and the cache that exists because of a kernel race. On the kubeadm cluster.

```bash
kubectl -n web run dns --image=nicolaka/netshoot --restart=Never -- sleep 1d
```

## Part 1 — resolv.conf, and the cost of a short name (30 min)

```bash
kubectl -n web exec dns -- cat /etc/resolv.conf
#   search web.svc.cluster.local svc.cluster.local cluster.local
#   nameserver 10.96.0.10
#   options ndots:5
```

The kubelet wrote that file. `ndots:5` means: a name with fewer than five dots is tried with each
search suffix **first**, and as typed **last**. Turn on query logging and watch:

```bash
kubectl -n kube-system get cm coredns -o yaml | sed 's/^\(\s*\)errors$/\1errors\n\1log/' | kubectl apply -f -
kubectl -n kube-system rollout restart deploy coredns && sleep 10
kubectl -n kube-system logs -f deploy/coredns &
kubectl -n web exec dns -- getent hosts web                   # 1 query: web.web.svc.cluster.local, NOERROR
kubectl -n web exec dns -- getent hosts example.com           # 5 queries: example.com.web.svc.cluster.local NXDOMAIN, .svc.cluster.local NXDOMAIN, .cluster.local NXDOMAIN, then example.com. NOERROR; and the AAAA twins
```

`example.com` has one dot, so the resolver tries three suffixes and gets three NXDOMAINs before
asking the real question, and most resolvers send A and AAAA in parallel, so it is eight packets to
get an answer that could have been two. In a service that makes ten thousand outbound calls a minute
this is the DNS load, and it is self-inflicted. Two fixes, say both:

```bash
kubectl -n web exec dns -- getent hosts example.com.          # the trailing dot: fully qualified, 1 query (plus AAAA)
kubectl -n web run dns1 --image=nicolaka/netshoot --restart=Never --overrides='{"spec":{"dnsConfig":{"options":[{"name":"ndots","value":"1"}]}}}' -- sleep 1d
kubectl -n web exec dns1 -- cat /etc/resolv.conf | tail -1    # options ndots:1
```

With `ndots:1`, `web` still resolves through the search list (zero dots), and `example.com` goes
straight out. That is the setting most clusters should ship; the default of 5 exists so that
`web.other-ns` and `web.other-ns.svc` also work without a suffix.

If you want the packets rather than the log: `kubectl -n kube-system debug -it <coredns pod>
--image=nicolaka/netshoot --target=coredns -- tcpdump -ni any udp port 53` (an ephemeral container in
the pod's network namespace, because the CoreDNS image has no shell).

## Part 2 — The plugin chain (20 min)

The Corefile lists plugins; **their order in the file does not matter.** CoreDNS compiles a fixed
order from `plugin.cfg` in its source, and a query walks that order: among the ones you have
enabled, `errors` and `log` first (they wrap everything), then `health` and `ready` (not in the query
path), `prometheus`, `loadbalance`, **`cache`**, `rewrite`, `hosts`, `kubernetes`, `loop`, `forward`.
So `cache` sits in front of `kubernetes` and `forward`: a cached answer never reaches the plugin
that would compute it, which is what `cache 30` in Lab 2 Task 6 did to a changed Service IP.

```bash
kubectl -n kube-system logs deploy/coredns | tail -3
#   [INFO] 192.168.1.7:41203 - 3412 "A IN example.com. udp 29 false 512" NOERROR qr,rd,ra 45 0.012s
```

Read one line: client, query id, type, name, protocol, size, DNSSEC flag, response code, flags, answer
size, time. `rd,ra` means the client asked for recursion and CoreDNS said it provides it; the `forward`
plugin did the recursion through the node's resolver. Read the `kubernetes` plugin's source once
(`plugin/kubernetes/`): it is an informer on Services, Endpoints (slices), and Pods, exactly the
pattern from the controller lab, answering from its cache.

## Part 3 — What the kubernetes plugin answers (25 min)

```bash
kubectl -n web exec dns -- dig +short web.web.svc.cluster.local                 # the ClusterIP
kubectl -n web create svc clusterip web-headless --clusterip=None --tcp=80:80 && kubectl -n web patch svc web-headless -p '{"spec":{"selector":{"app":"web"}}}'
kubectl -n web exec dns -- dig +short web-headless.web.svc.cluster.local        # every ready pod IP: headless = no VIP, DNS does the balancing (badly, by design)
kubectl -n web exec dns -- dig +short SRV _http._tcp.web.web.svc.cluster.local  # needs a named port: patch the Service's port with name: http, then: "0 50 80 web.web.svc.cluster.local."
kubectl -n web exec dns -- dig +short 192-168-1-7.web.pod.cluster.local         # a pod record, if the Corefile has `pods insecure`; dashes for dots
kubectl -n web exec dns -- dig +short -x 10.96.0.10                             # kube-dns.kube-system.svc.cluster.local: in-addr.arpa in the plugin's zone list
```

For a StatefulSet behind a headless Service, each pod also gets `<pod>.<svc>.<ns>.svc.cluster.local`,
which is how week 14 Lab 5 addressed `postgres-0`. Say what each record type is for: A for a Service,
A-per-pod for headless, SRV for "which port is `http` on this Service", PTR for logs that show an IP.

## Part 4 — dnsPolicy, and the hostNetwork trap (15 min)

| `dnsPolicy` | resolv.conf comes from | When |
|---|---|---|
| `ClusterFirst` (default) | the kubelet: cluster DNS, the search list, `ndots:5` | every ordinary pod |
| `Default` | the node's `/etc/resolv.conf` | a pod that must resolve like the node |
| `ClusterFirstWithHostNet` | cluster DNS, even with `hostNetwork: true` | node agents that still need Service names |
| `None` | `dnsConfig` only | you own every line |

```bash
kubectl -n web run hn --image=nicolaka/netshoot --restart=Never --overrides='{"spec":{"hostNetwork":true}}' -- sleep 1d
kubectl -n web exec hn -- cat /etc/resolv.conf              # the NODE's resolver: hostNetwork + ClusterFirst silently behaves as Default
kubectl -n web exec hn -- getent hosts web || echo "no cluster DNS"
```

A `hostNetwork` pod with the default policy cannot resolve Services. That is the trap, and
`ClusterFirstWithHostNet` is the one-line fix; Calico's and kube-proxy's own pods are examples of
when it is needed.

## Part 5 — NodeLocal DNSCache: a cache that exists because of a race (30 min)

Every lookup in Part 1 left the pod as a UDP packet to a ClusterIP, was DNATed by one of the three
mechanisms from the datapath lab, and got a conntrack entry. Two packets sent at the same instant from
the same source port (the parallel A and AAAA) can race to insert that entry; the loser is dropped,
and the resolver waits its full timeout, five seconds by default, before retrying. Clusters saw this
as "DNS randomly takes five seconds" for years. NodeLocal DNSCache runs a CoreDNS on every node at a
link-local address, so pods talk to it with no DNAT and no conntrack, and it talks upstream over TCP.

```bash
# the manifest ships in the Kubernetes repository under cluster/addons/dns/nodelocaldns/; its placeholders are filled by hand
KUBEDNS=$(kubectl -n kube-system get svc kube-dns -o jsonpath='{.spec.clusterIP}')
curl -sL https://raw.githubusercontent.com/kubernetes/kubernetes/master/cluster/addons/dns/nodelocaldns/nodelocaldns.yaml \
 | sed -e "s/__PILLAR__LOCAL__DNS__/169.254.20.10/g" -e "s/__PILLAR__DNS__DOMAIN__/cluster.local/g" -e "s/__PILLAR__DNS__SERVER__/$KUBEDNS/g" \
 | kubectl apply -f -
kubectl -n kube-system get ds node-local-dns
# Point the kubelets at it: on kubeadm, edit the kubelet ConfigMap's clusterDNS, then restart each kubelet (week 27 Lab 2 territory)
kubectl -n kube-system get cm kubelet-config -o yaml | grep -A1 clusterDNS
```

Measure before and after, from a fresh pod: `for i in $(seq 1 50); do dig example.com | grep 'Query time'; done | sort | uniq -c`.
In iptables mode the gain is small until the cluster is busy; the point is the tail, not the median.
Say the whole chain: `ndots` multiplies queries, UDP to a VIP needs DNAT, DNAT needs conntrack,
conntrack races, the cache removes the DNAT. Four layers, one five-second stall.

**Do it again, from memory, timed.** Parts 1 and 3 in 15 minutes: show the five queries, fix them two
ways, and produce A, headless A, SRV, and PTR answers with `dig`.
