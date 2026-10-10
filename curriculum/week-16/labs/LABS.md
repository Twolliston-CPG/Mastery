# Week 16 Labs

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
