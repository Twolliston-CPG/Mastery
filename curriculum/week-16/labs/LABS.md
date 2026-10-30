# Week 16 Labs

> **Figures:** one numbered mechanism figure per lab, with the spoken script, the numbers to own and
> the command that proves each badge, in [`FIGURES.md`](FIGURES.md) (16.2 to 16.7). Read a lab's figure
> before you start it; redraw it after.

> **`bash ../../_setup/03-teardown.sh` before you close the laptop. Every night.**

---

# Lab 1 — EKS via Terraform (3h)

```hcl
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.24"

  cluster_name    = "mastery"
  cluster_version = "1.31"

  # Reuse Alpha's network module -- reuse is itself a signal in a portfolio.
  vpc_id     = module.network.vpc_id
  subnet_ids = module.network.app_subnet_ids

  cluster_endpoint_public_access = true
  # In production: false, with access via a VPN, Direct Connect, or a bastion.

  # Access entries replaced the old aws-auth ConfigMap. Know both exist --
  # you will meet aws-auth in any cluster older than ~2024.
  enable_cluster_creator_admin_permissions = true
  authentication_mode                      = "API_AND_CONFIG_MAP"

  eks_managed_node_groups = {
    default = {
      instance_types = ["t3.medium"]
      capacity_type  = "SPOT"       # ~70% cheaper; teaches interruption handling
      min_size       = 2
      max_size       = 4
      desired_size   = 2
      disk_size      = 30
    }
  }

  # IRSA: creates the cluster's OIDC provider in IAM.
  enable_irsa = true

  cluster_addons = {
    coredns                = { most_recent = true }
    kube-proxy             = { most_recent = true }
    vpc-cni                = { most_recent = true }
    eks-pod-identity-agent = { most_recent = true }
    aws-ebs-csi-driver     = { most_recent = true }
  }
}
```

```bash
terraform apply
aws eks update-kubeconfig --name mastery --region us-east-1
kubectl get nodes
kubectl get pods -A
```

## Tasks
1. Provision it. **Time the apply.** (Expect 12–20 minutes; the control plane dominates.)
2. Look at what the module created: `terraform state list | wc -l`
3. Inspect the node group's launch template — note `HttpTokens: required` (IMDSv2, week 5)
4. `terraform destroy`, then `apply` again. **Do this before you trust it.**
5. Compare: what does EKS give you over kubeadm, and what does it cost?

## Managed node groups vs Fargate vs Karpenter

| | Managed node groups | Fargate | Karpenter |
|---|---|---|---|
| You manage | Instance types, scaling config | Nothing | A NodePool spec |
| Scaling | Cluster Autoscaler, ASG-based | Per-pod | **Provisions right-sized nodes in ~40s** |
| Bin packing | ASG-shaped | n/a | **Chooses instance types to fit pending pods** |
| Cost | Good with spot | Highest per-pod | Usually best |
| DaemonSets | Yes | **No** | Yes |

**Karpenter is the current best practice** for anything with variable load — it looks at *pending
pods* and provisions instances that fit them, rather than scaling a fixed ASG shape. Worth knowing
by name even if you use managed node groups in the lab.

---

# Lab 2 — IRSA (3h) — the week's centerpiece

## The problem it solves

Without IRSA, a pod needing AWS access has two bad options:
1. Use the **node's** instance role — so *every pod on that node* shares those permissions
2. Mount static credentials as a Secret — a long-lived credential in etcd

## The mechanism, step by step

```
1. The cluster has an OIDC identity provider registered in IAM
     (enable_irsa = true creates it; it publishes a JWKS document)

2. A ServiceAccount is annotated with a role ARN:
     eks.amazonaws.com/role-arn: arn:aws:iam::123:role/s3-reader

3. A MUTATING ADMISSION WEBHOOK sees the annotation and injects into the pod:
     - a projected volume containing a signed service-account token
     - env: AWS_ROLE_ARN, AWS_WEB_IDENTITY_TOKEN_FILE

4. The AWS SDK's credential chain finds AWS_WEB_IDENTITY_TOKEN_FILE and calls
     sts:AssumeRoleWithWebIdentity with the token

5. STS validates the token's signature against the cluster's OIDC JWKS,
   checks the role's trust policy `sub` against
     system:serviceaccount:<namespace>:<name>
   and returns temporary credentials
```

**It is the same shape as week 12's GitHub OIDC.** A trusted identity provider, a signed token, a
`sub` claim checked by a trust policy, short-lived STS credentials. Recognizing that pattern across
GitHub Actions, EKS, and IMDSv2 is worth saying out loud in an interview.

## Build it

```hcl
module "s3_reader_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.44"

  role_name = "mastery-s3-reader"

  role_policy_arns = {
    policy = aws_iam_policy.s3_read_one_bucket.arn
  }

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["shop:s3-reader"]
    }
  }
}
```

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: s3-reader
  namespace: shop
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/mastery-s3-reader
```

## Prove it

```bash
kubectl -n shop run awscli --rm -it \
  --overrides='{"spec":{"serviceAccountName":"s3-reader"}}' \
  --image=amazon/aws-cli -- sh

# inside the pod:
env | grep AWS
# AWS_ROLE_ARN=arn:aws:iam::123:role/mastery-s3-reader
# AWS_WEB_IDENTITY_TOKEN_FILE=/var/run/secrets/eks.amazonaws.com/serviceaccount/token

cat $AWS_WEB_IDENTITY_TOKEN_FILE | cut -d. -f2 | base64 -d 2>/dev/null
# {"sub":"system:serviceaccount:shop:s3-reader","aud":["sts.amazonaws.com"],...}

aws sts get-caller-identity
# assumed-role/mastery-s3-reader/botocore-session-...

ls ~/.aws 2>/dev/null || echo "NO credentials file"
aws s3 ls s3://your-bucket        # works
aws s3 ls s3://some-other-bucket  # AccessDenied -- scoped correctly
```

**Decoding the token and seeing `system:serviceaccount:shop:s3-reader` is the moment IRSA stops
being magic.**

## Break it (the four causes)
1. Remove the SA annotation → no env vars injected, SDK falls through to the **node role**
2. Change the trust policy `sub` to a different namespace → `AccessDenied` on assume
3. Use a different ServiceAccount in the pod → wrong `sub`
4. Delete the OIDC provider → STS cannot validate the token

## EKS Pod Identity — the newer alternative

```bash
aws eks create-pod-identity-association --cluster-name mastery \
  --namespace shop --service-account s3-reader --role-arn arn:aws:iam::123:role/x
```
Same goal, simpler setup: no per-cluster OIDC provider, no trust-policy editing, and the trust policy
is a simple `pods.eks.amazonaws.com` service principal. The tradeoff is that it's EKS-specific, where
IRSA's OIDC mechanism works with any Kubernetes cluster. **Know both; mention both.**

---

# Lab 3 — Controllers and External Secrets (2h)

## AWS Load Balancer Controller
```bash
helm repo add eks https://aws.github.io/eks-charts
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system --set clusterName=mastery \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:...
    alb.ingress.kubernetes.io/ssl-redirect: '443'
spec:
  ingressClassName: alb
```

**If the ALB never provisions, it's the subnet tags** — `kubernetes.io/role/elb: 1` on public
subnets, `kubernetes.io/role/internal-elb: 1` on private. Alpha's network module already sets these,
which is why reusing it pays off. This is the #1 ALB controller failure.

**`target-type: ip` registers pod IPs directly**, bypassing the NodePort hop — which means the ALB
load-balances across pods rather than nodes, and the pod sees the real client IP.

## External Secrets Operator
```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata: { name: aws, namespace: shop }
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1
      auth:
        jwt:
          serviceAccountRef: { name: external-secrets-sa }   # IRSA again
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata: { name: db-credentials, namespace: shop }
spec:
  refreshInterval: 1h
  secretStoreRef: { name: aws, kind: SecretStore }
  target:
    name: db-credentials
    creationPolicy: Owner
  dataFrom:
    - extract:
        key: rds!db-abc123      # the secret RDS created in week 13
```

**This is the answer to week 14's Secret problem.** The value lives in Secrets Manager; ESO syncs it
into a Kubernetes Secret and refreshes it on rotation. The **Git repository never contains the
value**, which is what makes GitOps and secrets compatible at all.

---

# Lab 4 — ArgoCD (3h)

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

## Pull vs push — the thing to understand

| | Push (CI deploys) | **Pull (GitOps)** |
|---|---|---|
| Credentials | CI holds **cluster** credentials | **Cluster credentials never leave the cluster** |
| Drift | Undetected until the next deploy | **Detected and corrected continuously** |
| Audit trail | CI logs | **Git history** |
| Cluster down | Deploy fails mid-flight | Nothing deploys; running workloads unaffected |

**The credential argument is the strong one.** In a push model your CI system holds credentials to
every cluster — so compromising CI compromises production. In a pull model the agent runs *inside*
the cluster and pulls from Git; there is nothing to steal from CI.

## App of apps
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/you/gitops
    targetRevision: main
    path: apps/           # a directory of Application manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true         # delete resources removed from Git
      selfHeal: true      # revert manual cluster changes
    syncOptions:
      - CreateNamespace=true
```

## Tasks
1. Install ArgoCD; deploy the week-14/15 stack through it
2. Change a manifest in Git → watch it sync (under 3 minutes)
3. **`kubectl scale deploy/app --replicas=99` by hand → watch `selfHeal` revert it.** This is the
   demo that makes GitOps click.
4. Build an app-of-apps with three child Applications
5. Use **sync waves** to order them: namespace → secrets → database → app
   ```yaml
   annotations:
     argocd.argoproj.io/sync-wave: "-1"
   ```
6. Reproduce a stuck `OutOfSync` on an immutable field and fix it with
   `argocd.argoproj.io/sync-options: Replace=true`
7. Look at **ApplicationSets** — generate an Application per environment from a matrix generator

---

# Lab 5 — Break/Fix + Cost (2h)

## Break/Fix
- **IRSA `AccessDenied`** — work the four causes from Lab 2
- **ALB never provisions** — remove the subnet tags and diagnose from the controller logs
- **ArgoCD stuck `OutOfSync`** on an immutable field

```bash
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --tail=50
kubectl -n argocd logs deploy/argocd-application-controller --tail=100
argocd app diff shop
```

## Cost review
```bash
make cost      # or the Cost Explorer command from week 8
```
Your EKS week should be **under $20**. If it's more, you left something running overnight.

## ★ Destroy everything
```bash
terraform destroy
bash ../../_setup/03-teardown.sh
aws eks list-clusters
aws elbv2 describe-load-balancers --query 'LoadBalancers[].LoadBalancerName'
```
**Load balancers created by the ALB controller are NOT managed by Terraform** — deleting the cluster
can orphan them. Check explicitly. This is a real and expensive gotcha.

---

# Go deeper — CSI, sidecar by sidecar (2h · ladder: storage and CSI, rung 3)

**Optional inside the week, mandatory for the ladder** ([`KUBERNETES-MASTERY.md`](../../../KUBERNETES-MASTERY.md)).
Lab 1 installed the EBS CSI driver as an add-on and week 15 used claims. This lab reads the driver
as the set of small programs it is, and follows one volume from a claim to a filesystem in a pod and
back, as objects, events and gRPC calls. On EKS, before the Sunday destroy. Everything here costs
cents, and the cost note at the end says what to delete.

**First, the permission the add-on needs.** The controller calls the EC2 API (`CreateVolume`,
`AttachVolume`, ...). With the module snippet in Lab 1 it runs with the **node's** role, which has no
EBS rights, and the first claim hangs with `UnauthorizedOperation` in the provisioner's log. Give it
an IRSA role, which is Lab 2 applied to a component you did not write:

```hcl
# in the eks module call: the add-on's service account assumes a role scoped to EBS
cluster_addons = {
  aws-ebs-csi-driver = {
    most_recent              = true
    service_account_role_arn = module.ebs_csi_irsa.iam_role_arn
  }
}
module "ebs_csi_irsa" {
  source                = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version               = "~> 5.44"
  role_name             = "mastery-ebs-csi"
  attach_ebs_csi_policy = true
  oidc_providers = { main = { provider_arn = module.eks.oidc_provider_arn, namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"] } }
}
```

(The quick alternative is attaching `AmazonEBSCSIDriverPolicy` to the node role. It works and it is
the wrong shape: every pod on every node could then create volumes.)

## Part 1 — Name every container (20 min)

```bash
kubectl -n kube-system get pods -l app.kubernetes.io/name=aws-ebs-csi-driver -o wide
kubectl -n kube-system get deploy ebs-csi-controller -o jsonpath='{range .spec.template.spec.containers[*]}{.name}{"\n"}{end}'
kubectl -n kube-system get ds ebs-csi-node -o jsonpath='{range .spec.template.spec.containers[*]}{.name}{"\n"}{end}'
```

Two pods kinds, one driver. The controller Deployment and the node DaemonSet both carry the same
`ebs-plugin` container; what differs is the **sidecars** around it, each one a generic Kubernetes
controller that watches one object type and turns it into one gRPC call on the plugin:

| Container | Runs in | Watches | Calls on the plugin |
|---|---|---|---|
| `ebs-plugin` | both | nothing: it answers gRPC on a Unix socket | the EC2 and local mount work |
| `csi-provisioner` | controller | PersistentVolumeClaims | `CreateVolume`, `DeleteVolume` → creates the PV |
| `csi-attacher` | controller | VolumeAttachments | `ControllerPublishVolume` (EC2 AttachVolume), `ControllerUnpublishVolume` |
| `csi-resizer` | controller | PVCs whose request grew | `ControllerExpandVolume` (EC2 ModifyVolume) |
| `csi-snapshotter` | controller | VolumeSnapshotContents | `CreateSnapshot`, `DeleteSnapshot` |
| `node-driver-registrar` | node | nothing: registers the socket with the kubelet | writes the driver into the node's `CSINode` |
| `liveness-probe` | both | the plugin's socket | `Probe`; exposes an HTTP health endpoint for the kubelet |

The kubelet itself makes the two node-side calls, `NodeStageVolume` and `NodePublishVolume`, over
the socket the registrar advertised. Nothing in this table is EBS-specific except the plugin; swap
it for the EFS or the GCE plugin and the sidecars are the same images. That is the point of the
Container Storage Interface: the **spec** (the `container-storage-interface/spec` repository is the
reading, `spec.md`) fixes the gRPC calls, and Kubernetes supplies the controllers that make them.

Two objects describe the driver to the cluster:

```bash
kubectl get csidriver ebs.csi.aws.com -o yaml | grep -E 'attachRequired|podInfoOnMount|fsGroupPolicy|volumeLifecycleModes' 
kubectl get csinode $(kubectl get nodes -o jsonpath='{.items[0].metadata.name}') -o yaml | grep -A6 'drivers:'
```

`attachRequired: true` is why a VolumeAttachment object exists at all (EFS says false: nothing to
attach). `CSINode.spec.drivers[].allocatable.count` is the number of volumes this node can still
take; a Nitro instance's limit is the number most people learn the day a pod sits Pending with
"exceeds max volume count".

## Part 2 — One volume, from claim to mount (35 min)

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata: { name: gp3 }
provisioner: ebs.csi.aws.com
parameters: { type: gp3 }
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
reclaimPolicy: Delete
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata: { name: data }
spec: { accessModes: [ReadWriteOnce], storageClassName: gp3, resources: { requests: { storage: 10Gi } } }
---
apiVersion: v1
kind: Pod
metadata: { name: writer }
spec:
  containers: [{ name: c, image: busybox:1.36, command: [sh, -c, "date >> /data/log; sleep 3600"], volumeMounts: [{ name: d, mountPath: /data }] }]
  volumes: [{ name: d, persistentVolumeClaim: { claimName: data } }]
EOF
kubectl get pvc,pv,volumeattachment -w                     # leave this running in a second terminal
```

Watch the objects appear in this order and say who made each:

1. **PVC Pending** with reason `WaitForFirstConsumer`: the provisioner deliberately waits until the
   scheduler has chosen a node, so the volume is created in that node's **availability zone**. A
   volume provisioned before scheduling can land in a zone the pod cannot reach; this mode is the
   fix, and it is why the class sets it.
2. **PV Bound.** `csi-provisioner` saw the PVC get `volume.kubernetes.io/selected-node`, called
   `CreateVolume`, and created the PV with the EBS volume ID in `spec.csi.volumeHandle`.
3. **VolumeAttachment.** The attach/detach controller in `kube-controller-manager` created it,
   naming the PV and the node. `csi-attacher` saw it, called `ControllerPublishVolume`, and set
   `status.attached: true` when EC2 reported the device attached.
4. **Staged and published.** The kubelet called `NodeStageVolume` (format if new, mount at the
   global path) then `NodePublishVolume` (bind-mount into the pod's directory).

```bash
kubectl describe pvc data | tail -6                                           # ProvisioningSucceeded
kubectl describe pod writer | grep -E 'AttachVolume|SuccessfulAttachVolume|Mount'
NODE=$(kubectl get pod writer -o jsonpath='{.spec.nodeName}')
kubectl get volumeattachment -o custom-columns='NAME:.metadata.name,PV:.spec.source.persistentVolumeName,NODE:.spec.nodeName,ATTACHED:.status.attached'
kubectl -n kube-system logs -l app=ebs-csi-controller -c csi-provisioner --tail=50 | grep -iE 'provision|CreateVolume' | tail -3
kubectl -n kube-system logs -l app=ebs-csi-controller -c csi-attacher --tail=50 | grep -iE 'attach' | tail -3
kubectl debug node/$NODE -it --image=busybox:1.36 -- sh -c 'mount | grep -E "globalmount|kubernetes.io~csi"'    # stage path, then the pod's bind mount
aws ec2 describe-volumes --filters Name=tag:kubernetes.io/created-for/pvc/name,Values=data \
  --query 'Volumes[].{id:VolumeId,az:AvailabilityZone,state:State,attached:Attachments[0].InstanceId}'
```

The last command closes the loop: the EBS volume carries tags naming the PVC, and its zone is the
pod's node's zone.

## Part 3 — Unwind it: detach and reclaim (20 min)

```bash
kubectl delete pod writer                      # NodeUnpublish, NodeUnstage, then the VolumeAttachment is removed → ControllerUnpublish
kubectl get volumeattachment                   # gone within a minute; the PV is still Bound to the PVC
kubectl delete pvc data                        # reclaimPolicy Delete: csi-provisioner calls DeleteVolume
aws ec2 describe-volumes --filters Name=tag:kubernetes.io/created-for/pvc/name,Values=data --query 'Volumes[].State'   # [] or ["deleting"]
```

Now the other policy. Recreate the claim and pod, then **edit the PV** to `persistentVolumeReclaimPolicy: Retain`
before deleting the claim:

```bash
PV=$(kubectl get pvc data -o jsonpath='{.spec.volumeName}')
kubectl patch pv $PV -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'
kubectl delete pod writer pvc data
kubectl get pv $PV                             # STATUS Released: the data is safe and the volume is billing
```

A Released PV cannot be claimed again until someone clears `spec.claimRef`. That is the operational
meaning of Retain: a human is now in the loop, and the volume costs money until they act. Delete the
PV and the EBS volume by hand when you have read it.

## Part 4 — Expansion, controller side and node side (20 min)

```bash
kubectl apply -f - <<'EOF'      # the claim and pod again, 10Gi
...
EOF
kubectl patch pvc data -p '{"spec":{"resources":{"requests":{"storage":"20Gi"}}}}'
kubectl get pvc data -o jsonpath='{.status.conditions}{"\n"}'          # Resizing, then FileSystemResizePending
kubectl -n kube-system logs -l app=ebs-csi-controller -c csi-resizer --tail=30 | grep -iE 'expand|resize' | tail -3
kubectl exec writer -- df -h /data                                     # 20G once the node side is done
```

Two halves. `csi-resizer` calls `ControllerExpandVolume` (EC2 `ModifyVolume`), and the PVC condition
flips to `FileSystemResizePending`. The kubelet then calls `NodeExpandVolume` to grow the filesystem;
the driver does it online, so the pod never restarts. Two facts to own: expansion only works when
the class says `allowVolumeExpansion: true`, and EBS allows one modification per volume every **six
hours**, so the second resize of a demo volume waits.

## Part 5 — Snapshot and restore (20 min)

Snapshots need the snapshot CRDs and controller, which are not part of the driver: install the EKS
**snapshot-controller** add-on (or the upstream `kubernetes-csi/external-snapshotter` manifests),
then:

```bash
kubectl apply -f - <<'EOF'
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata: { name: ebs }
driver: ebs.csi.aws.com
deletionPolicy: Delete
---
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata: { name: data-snap }
spec: { volumeSnapshotClassName: ebs, source: { persistentVolumeClaimName: data } }
EOF
kubectl get volumesnapshot data-snap -w                     # READYTOUSE true when EC2 reports the snapshot completed
aws ec2 describe-snapshots --owner-ids self --query 'Snapshots[?Tags[?Key==`kubernetes.io/created-for/snapshot/name`]].{id:SnapshotId,state:State,size:VolumeSize}'
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata: { name: data-restored }
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: gp3
  resources: { requests: { storage: 20Gi } }
  dataSource: { apiGroup: snapshot.storage.k8s.io, kind: VolumeSnapshot, name: data-snap }
EOF
```

Mount `data-restored` in a new pod and `cat /data/log`: the dates the first pod wrote are there.
The chain is the same shape as provisioning: the snapshot controller creates a
`VolumeSnapshotContent`, `csi-snapshotter` calls `CreateSnapshot`, and a restore is a `CreateVolume`
with a source. The EBS console shows a snapshot and, after the restore, a volume created from it.

**Cost note.** gp3 bills per provisioned GiB-month (about $0.08 in us-east-1 at the time of writing,
check the calculator) and snapshots per stored GiB-month; a 20 GiB volume plus one snapshot for a
weekend is cents. The trap is Part 3's **Retain** and anything the Sunday destroy does not know
about: `terraform destroy` removes the cluster, not volumes the driver created. Add to the teardown:
`aws ec2 describe-volumes --filters Name=tag-key,Values=kubernetes.io/created-for/pvc/name --query 'Volumes[].VolumeId'`
and `describe-snapshots --owner-ids self`, and delete what they list.

**From memory, timed (15 min):** with the file closed, name the seven containers and the object each
one watches, then say the provisioning sequence from claim to bind mount as four gRPC calls in order.
Target: under fifteen minutes, no gaps.
