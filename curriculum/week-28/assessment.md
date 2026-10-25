# Week 28 Assessment

> Closed book, 30 min. Exam facts are planning estimates; confirm them in the candidate handbook.

## Part A (20 min)
1. Strategic merge patch versus JSON patch: when is each the only option?
2. Why does `configMapGenerator` put a hash in the name, and what does that do to a Deployment that references it?
3. The three Kustomize overlay fields you use in every overlay.
4. `helm history` shows `superseded` and `deployed`. What does `helm rollback web 1` do to that list?
5. What does `helm template x chart | kubectl apply --dry-run=server -f -` prove that `helm template` alone does not?
6. Name the three Gateway API roles and the object each one owns.
7. What does `allowedRoutes.namespaces.from: Same` do, and why did Ingress need it?
8. Four status reasons to read when a Gateway or HTTPRoute does not serve traffic.
9. Where does traffic enter a Gateway on a cluster with no LoadBalancer, and how do you find the port?
10. In a pod's `resolv.conf`: the nameserver, the search list, and what `ndots:5` does to a lookup of `example.com`.
11. Name the CoreDNS plugin that answers for Services, and the one that handles everything else.
12. A Service with no selector: what is missing, what do you write, and which label makes the link?
13. What does a CRD need for exactly one of its versions, and what happens to objects when you delete the CRD?
14. Give four schema constraints the API server enforces on a custom resource with no controller present.
15. Describe cert-manager's reconcile for a Certificate, object by object.
16. `backoffLimit` versus `activeDeadlineSeconds`: which wins, and what are the defaults?
17. `concurrencyPolicy: Forbid` versus `Replace`, and the command that runs a CronJob now.
18. Why is there no `kubectl create daemonset`, and what do you do instead? Which toleration does it need to run on the control plane?
19. `nodeName` versus `nodeSelector`: which one ignores taints, and which one produces an event when it cannot place the pod?
20. The three taint effects and which one affects running pods.
21. What makes a static pod's mirror name, and what happens when you delete the mirror pod?
22. Why is a fresh kubeadm cluster's PVC Pending, and what two things fix it?
23. Why is `is-default-class` applied at claim creation and not retroactively?
24. `WaitForFirstConsumer`: what does the resulting PV carry that `Immediate` would not?
25. A Retain PV after its claim is deleted: phase, what it still holds, and the patch that makes it reusable.
26. `allowVolumeExpansion` gates what, exactly, and what does it not guarantee?

## Part B — Write it (10 min)
27. A prod overlay `kustomization.yaml`: namespace `shop-prod`, prefix `prod-`, a JSON patch setting replicas to 3.
28. An HTTPRoute for host `shop.local` sending `/api` to `v2:80` and everything else 90/10 to `v1`/`v2`.
29. A CoreDNS `hosts` block mapping `10.10.0.250` to `printer.lab.internal`, with fallthrough.
30. An EndpointSlice for Service `outside` in namespace `web` pointing at `10.10.0.7:9000`.
31. A Job running `perl -e 'print 1'` five times, two at a time, giving up after 600 seconds.
32. A toleration for `team=data:NoSchedule`.
33. A static PV: 1Gi, RWO, Retain, class `manual`, hostPath `/mnt/keep`, pinned to node `k8s-w2`.

---

# Answer key

**A1.** Strategic merge when you want to change fields of an object without restating it; list
items (containers) are matched by `name`. JSON patch is the only option to **remove** a field, or to
address a list element **by index** (`/spec/template/spec/containers/0/...`).

**A2.** The hash is derived from the content. A new value gives a new name; Kustomize rewrites the
Deployment's reference to the new name, so the pod template changes and a rollout happens. Editing a
ConfigMap in place changes nothing in the pod template, so pods keep the old values until restarted.

**A3.** `namespace`, `namePrefix` (or `nameSuffix`), `resources: [../../base]`. Then `patches`.

**A4.** Creates revision 4, a copy of revision 1's values, with status `deployed`; revisions 1 to 3
become `superseded`. History is append-only; rollback never deletes a revision.

**A5.** Server-side dry run validates every rendered object against the real API: unknown fields,
missing CRDs, admission webhooks, RBAC. `helm template` alone only proves the templates render.

**A6.** Infrastructure provider: GatewayClass. Cluster operator: Gateway (listeners). Application
developer: HTTPRoute (and other Routes), in their own namespace.

**A7.** Only Routes in the Gateway's own namespace may attach (alternatives: `All`, or a `Selector`).
Ingress had no attachment control: any Ingress in any namespace could claim any host on the
controller, so one team's typo could capture another's traffic.

**A8.** Gateway: `Accepted`, `Programmed`. HTTPRoute (in `status.parents[].conditions`): `Accepted`,
`ResolvedRefs`. A false `ResolvedRefs` usually means a backend Service name or port is wrong.

**A9.** The implementation creates a Service for the Gateway (type from its install, here NodePort);
`kubectl -n <ns> get svc` and read the NodePort, or select by the
`gateway.networking.k8s.io/gateway-name` label. Send the Host header to any node on that port.

**A10.** `nameserver 10.96.0.10` (the CoreDNS Service); `search <ns>.svc.cluster.local svc.cluster.local cluster.local`;
`options ndots:5`. A name with fewer than five dots is tried with each search suffix first, so
`example.com` costs up to three failing cluster lookups before the real one.

**A11.** `kubernetes` (Services, Pods, `cluster.local`); `forward . /etc/resolv.conf` for the rest,
with `cache 30` in front.

**A12.** Endpoints: nothing creates them without a selector. Write an `EndpointSlice` with
`addressType: IPv4`, `ports`, `endpoints[].addresses`, and the label
`kubernetes.io/service-name: <service>`, which is what ties the slice to the Service.

**A13.** Exactly one version with `storage: true` (others may be `served`). Deleting the CRD deletes
every custom resource of that kind in every namespace.

**A14.** `required`, `enum`, `pattern`, `minimum`/`maximum` (also `type`, `default`, `x-kubernetes-validations`).
The API server validates on admission; no controller is involved.

**A15.** Certificate (yours) → cert-manager creates a CertificateRequest → the Issuer/ClusterIssuer
signs it → cert-manager writes the Secret named in `spec.secretName` with `tls.crt` and `tls.key`.
Events on the Certificate: Issuing, Generated, Requested, Ready.

**A16.** `activeDeadlineSeconds` wins: when the deadline passes the Job is terminated regardless of
retries left. Defaults: `backoffLimit: 6`, no deadline.

**A17.** `Forbid`: if the previous Job is still running, skip this run. `Replace`: kill the running
Job and start the new one. `kubectl create job <name> --from=cronjob/<cj>`.

**A18.** DaemonSet has no imperative create. Generate a Deployment with `--dry-run=client -o yaml`,
change `kind`, remove `replicas` and `strategy`. Toleration: key `node-role.kubernetes.io/control-plane`,
operator `Exists`, effect `NoSchedule`.

**A19.** `nodeName` bypasses the scheduler entirely: no taint check, no affinity, and a wrong name
leaves the pod Pending with no event. `nodeSelector` goes through the scheduler, respects taints,
and a miss produces a `FailedScheduling` event naming the reason.

**A20.** `NoSchedule`, `PreferNoSchedule`, `NoExecute`. Only `NoExecute` evicts running pods that
lack a toleration (after `tolerationSeconds` if set).

**A21.** `<pod name>-<node name>`. Deleting the mirror pod removes the API object briefly; the
kubelet recreates it from the file. The container never stops. Remove the file to stop it.

**A22.** No StorageClass exists, so no provisioner and no default. Install a provisioner (its class
appears) and annotate that class as default; or create a static PV that matches the claim.

**A23.** The default class name is written into `spec.storageClassName` by an admission plugin when
the claim is **created** with none set. Existing claims keep their (empty) value, so they never pick
up a class added later; delete and recreate.

**A24.** `nodeAffinity` to the node the first pod was scheduled on, because the volume was
provisioned there. With `Immediate` the volume is created before any pod exists, which on
topology-bound storage can put it where the pod cannot go.

**A25.** `Released`; it still holds the `claimRef` to the deleted claim and all the data. Remove the
claimRef: `kubectl patch pv keep --type=json -p '[{"op":"remove","path":"/spec/claimRef"}]'` →
`Available`.

**A26.** Whether the API accepts a larger `resources.requests.storage` on a claim of that class. It
does not guarantee the driver can grow the volume; the driver reports via PVC conditions
(`Resizing`, `FileSystemResizePending`), and a provisioner that cannot resize simply does nothing.

**B27.**
```yaml
namespace: shop-prod
namePrefix: prod-
resources: [../../base]
patches:
  - target: { kind: Deployment, name: web }
    patch: |-
      - op: replace
        path: /spec/replicas
        value: 3
```

**B28.**
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata: { name: shop, namespace: web }
spec:
  parentRefs: [{ name: shop }]
  hostnames: [shop.local]
  rules:
    - matches: [{ path: { type: PathPrefix, value: /api } }]
      backendRefs: [{ name: v2, port: 80 }]
    - matches: [{ path: { type: PathPrefix, value: / } }]
      backendRefs:
        - { name: v1, port: 80, weight: 90 }
        - { name: v2, port: 80, weight: 10 }
```

**B29.**
```
        hosts {
          10.10.0.250 printer.lab.internal
          fallthrough
        }
```

**B30.**
```yaml
apiVersion: discovery.k8s.io/v1
kind: EndpointSlice
metadata:
  name: outside-1
  namespace: web
  labels: { kubernetes.io/service-name: outside }
addressType: IPv4
ports: [{ name: "", port: 9000, protocol: TCP }]
endpoints: [{ addresses: ["10.10.0.7"] }]
```

**B31.**
```yaml
apiVersion: batch/v1
kind: Job
metadata: { name: five }
spec:
  completions: 5
  parallelism: 2
  activeDeadlineSeconds: 600
  template:
    spec:
      restartPolicy: OnFailure
      containers: [{ name: p, image: perl:5.34, command: [perl, -e, "print 1"] }]
```

**B32.**
```yaml
tolerations:
  - { key: team, operator: Equal, value: data, effect: NoSchedule }
```

**B33.**
```yaml
apiVersion: v1
kind: PersistentVolume
metadata: { name: keep }
spec:
  capacity: { storage: 1Gi }
  accessModes: [ReadWriteOnce]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath: { path: /mnt/keep }
  nodeAffinity:
    required:
      nodeSelectorTerms:
        - matchExpressions: [{ key: kubernetes.io/hostname, operator: In, values: [k8s-w2] }]
```
