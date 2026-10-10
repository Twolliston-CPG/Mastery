# Week 16 Solutions

---

## Lab 2 — IRSA: the full mechanism

### What the trust policy actually looks like

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Federated": "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/ABCD1234"
    },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "oidc.eks.us-east-1.amazonaws.com/id/ABCD1234:sub": "system:serviceaccount:shop:s3-reader",
        "oidc.eks.us-east-1.amazonaws.com/id/ABCD1234:aud": "sts.amazonaws.com"
      }
    }
  }]
}
```

**Compare this to week 12's GitHub OIDC trust policy.** Same structure: a federated principal, the
`AssumeRoleWithWebIdentity` action, a `sub` claim pinned, an `aud` claim checked. Different identity
provider, identical pattern.

**Omitting the `aud` condition is a real vulnerability** — a token minted for a different audience
could be replayed. Always pin both.

### Debugging IRSA — the four causes and their symptoms

| Symptom | Cause |
|---|---|
| `aws sts get-caller-identity` shows the **node** role | SA annotation missing, or the pod doesn't use that SA |
| `AccessDenied` on `sts:AssumeRoleWithWebIdentity` | Trust policy `sub` doesn't match `system:serviceaccount:<ns>:<name>` |
| `InvalidIdentityToken` | OIDC provider not registered, or the wrong provider ARN |
| Works, then stops after a pod restart | The SDK version is too old to read `AWS_WEB_IDENTITY_TOKEN_FILE` |

```bash
# the diagnostic sequence
kubectl -n shop get sa s3-reader -o yaml | grep role-arn
kubectl -n shop get pod X -o jsonpath='{.spec.serviceAccountName}'
kubectl -n shop exec X -- env | grep AWS_
kubectl -n shop exec X -- sh -c 'cat $AWS_WEB_IDENTITY_TOKEN_FILE' | cut -d. -f2 | base64 -d
aws iam get-role --role-name mastery-s3-reader --query 'Role.AssumeRolePolicyDocument'
```

### The pattern worth naming out loud

The same shape appears three times in this curriculum:

| Context | Identity provider | Token | Checked claim | Result |
|---|---|---|---|---|
| EC2 (week 5) | AWS itself | IMDSv2 session token | — | STS credentials |
| GitHub Actions (week 12) | GitHub OIDC | Workflow JWT | `repo:org/repo:environment:prod` | STS credentials |
| **EKS pods (week 16)** | **Cluster OIDC** | **Projected SA token** | **`system:serviceaccount:ns:name`** | **STS credentials** |

> *"In all three cases the answer to 'how does this workload get credentials without having a
> credential' is the same: a trusted identity provider signs a short-lived token asserting who the
> workload is, and a trust policy decides which of those assertions may become AWS credentials."*

That is a genuinely strong interview answer because it shows you see the pattern rather than three
memorized procedures.

### IRSA vs Pod Identity

| | IRSA | EKS Pod Identity |
|---|---|---|
| Setup | OIDC provider per cluster; trust policy names the cluster's issuer | One association API call |
| Trust policy | Per-cluster, per-SA `sub` condition | Simple `pods.eks.amazonaws.com` principal |
| Role reuse across clusters | Needs a condition per cluster | **Works unchanged** |
| Portability | Standard OIDC — the concept works on any cluster | **EKS only** |
| Maturity | Widely deployed, universally supported | Newer |

**Pod Identity is simpler operationally; IRSA is the portable mechanism and the one you'll meet in
existing clusters.** Knowing both, and the reason to choose each, is the answer.

---

## Lab 3 — Controllers

### Why the ALB doesn't provision

Ranked by frequency:

1. **Subnet tags missing.** The controller discovers subnets by tag:
   - `kubernetes.io/role/elb = 1` on public subnets (internet-facing)
   - `kubernetes.io/role/internal-elb = 1` on private subnets
   - (older clusters also required `kubernetes.io/cluster/<name> = shared|owned`)
2. IRSA not configured for the controller's ServiceAccount — check its logs for `AccessDenied`
3. `ingressClassName: alb` missing
4. Fewer than two subnets in different AZs — an ALB requires at least two
5. `target-type: ip` without the VPC CNI assigning routable pod IPs

```bash
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --tail=100
kubectl describe ingress app        # the controller posts its errors as events here
```

**Alpha's network module already sets the tags** — which is the practical payoff of building
reusable modules.

### `target-type: ip` vs `instance`

| | `instance` | `ip` |
|---|---|---|
| Registers | Node IPs on the NodePort | **Pod IPs directly** |
| Hops | ALB → node → kube-proxy → pod | **ALB → pod** |
| Client IP | Preserved via `X-Forwarded-For` | Preserved via `X-Forwarded-For` |
| Balancing | Across **nodes** | **Across pods** |
| Works with Fargate | No | **Yes** |

`ip` mode is the better default: even load distribution across pods, one less network hop, and it
works with Fargate.

### Why External Secrets matters for GitOps

GitOps says: **everything in Git**. Secrets say: **nothing sensitive in Git**. External Secrets
resolves the contradiction — Git holds an `ExternalSecret` *reference*, and the operator resolves it
from a real secrets manager at runtime.

The alternatives and their tradeoffs:
- **Sealed Secrets** — encrypted values *are* in Git, decryptable only by the cluster's controller.
  Works, but rotation means re-sealing and re-committing.
- **SOPS + age/KMS** — same shape, more flexible, same rotation friction.
- **External Secrets** — the value never enters Git at all, and **rotation is automatic**.

ESO is the current best practice, and being able to compare the three is a good platform-engineering
answer.

---

## Lab 4 — ArgoCD

### The self-heal demo

```bash
kubectl -n shop scale deploy/app --replicas=99
# watch ArgoCD notice within ~3 minutes (or immediately with a webhook) and revert it
kubectl -n shop get deploy app -w
```

**This is the demo that makes GitOps click**, and it's worth putting in your project's demo video.
Nobody can manually change the cluster and have it stick — Git is the only way in, which is
simultaneously a security control and an audit trail.

### Sync waves

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "-2"   # lower runs first; default 0
```
Ordering for a typical stack:
```
-3  Namespace, ResourceQuota, LimitRange
-2  ExternalSecret, ServiceAccount, RBAC
-1  StatefulSet (database), PVC
 0  Deployment (app)
 1  Ingress, HPA, PDB
```
Within a wave ArgoCD applies in a sensible built-in order (namespaces before everything, CRDs before
their custom resources).

### Stuck `OutOfSync`

Usual cause: an **immutable field** changed. A Deployment's `spec.selector`, a Service's
`clusterIP`, a StatefulSet's `volumeClaimTemplates`, a Job's `spec` — the API server rejects the
update and ArgoCD retries forever.

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-options: Replace=true    # delete and recreate
```
Use it deliberately — `Replace=true` on a StatefulSet destroys and recreates pods.

Other causes: a mutating webhook (or the cluster itself) adding fields ArgoCD then sees as drift —
fix with `ignoreDifferences`:
```yaml
ignoreDifferences:
  - group: apps
    kind: Deployment
    jsonPointers: ["/spec/replicas"]    # if an HPA owns replicas, ArgoCD must not
```
**That HPA example is a real and common conflict:** without it, ArgoCD reverts the HPA's scaling
decision back to the manifest's replica count, and the two fight each other forever.

### Pull vs push, for the interview

> *"In a push model your CI system holds credentials to every cluster, so compromising CI
> compromises production. In a pull model the agent runs inside the cluster and pulls from Git —
> there are no cluster credentials in CI to steal. You also get continuous drift detection for free,
> and Git becomes the audit trail, which is exactly what an auditor wants to see."*

The counter-argument worth acknowledging: pull-based delivery makes it harder to run imperative steps
(database migrations, smoke tests) as part of a deploy, which is what ArgoCD's sync hooks —
`PreSync`, `Sync`, `PostSync` — exist for.

---

## Cost — the orphan that catches people

```bash
terraform destroy
aws elbv2 describe-load-balancers --query 'LoadBalancers[].[LoadBalancerName,CreatedTime]' --output table
```

**Load balancers created by the AWS Load Balancer Controller are created by the *controller*, not by
Terraform.** Terraform does not know they exist. Destroying the cluster can leave an ALB running at
~$16/month indefinitely.

**The correct teardown order:**
```bash
kubectl delete ingress --all -A       # let the controller delete its ALBs
kubectl delete svc --all -A --field-selector spec.type=LoadBalancer
sleep 60                              # give it time
terraform destroy
bash ../../_setup/03-teardown.sh      # then verify nothing remains
```

The same applies to PVCs → EBS volumes, and to security groups the controller created. **Delete
Kubernetes objects that own cloud resources before destroying the cluster.** This is a genuinely
useful operational detail and the kind of thing that only comes from having been billed for it.
