# Week 16 Assessment

> Closed book, 30 min. **Plus: is everything destroyed? Check the bill.**

## Part A (15 min)
1. Explain IRSA end to end: the five steps from ServiceAccount annotation to AWS credentials.
2. What claim does an IRSA trust policy pin, and what is its exact format?
3. Name the four causes of an IRSA `AccessDenied` and the symptom of each.
4. IRSA vs EKS Pod Identity — three differences and when you'd choose each.
5. What do EC2 instance profiles, GitHub OIDC, and IRSA have in common? State the general pattern.
6. Why won't the AWS Load Balancer Controller provision an ALB? Name the most common cause.
7. `target-type: ip` vs `instance` — three differences.
8. Why does GitOps need External Secrets? Compare three approaches.
9. Pull vs push delivery — give the **security** argument, and the counter-argument.
10. What do sync waves do, and give a sensible ordering for a stack with a database.
11. Why does ArgoCD get stuck `OutOfSync`, and name two fixes.
12. What cloud resources can be orphaned when you delete an EKS cluster, and why?

## Part B — Commands (10 min)
13. Update kubeconfig for an EKS cluster
14. Show the AWS identity a pod is actually using
15. Decode the projected service-account token inside a pod
16. Read the ALB controller's logs
17. Show what ArgoCD thinks is different from Git
18. Find load balancers that Terraform doesn't manage

## Part C — Judgment (5 min)
19. An HPA and ArgoCD keep fighting over replica count. What's happening and how do you fix it?
20. Your teammate wants to give CI cluster-admin kubeconfig for all environments so deploys are
    simpler. What do you say?

---

# Answer key

**A1.** (1) The cluster has an **OIDC identity provider registered in IAM**. (2) A ServiceAccount is
annotated with `eks.amazonaws.com/role-arn`. (3) A **mutating admission webhook** injects a projected
service-account token volume plus `AWS_ROLE_ARN` and `AWS_WEB_IDENTITY_TOKEN_FILE`. (4) The SDK's
credential chain finds the token file and calls `sts:AssumeRoleWithWebIdentity`. (5) STS validates the
signature against the cluster's JWKS, checks the trust policy's `sub`, and returns temporary
credentials.

**A2.** The `sub` claim, formatted `system:serviceaccount:<namespace>:<serviceaccount-name>`. The
`aud` should also be pinned to `sts.amazonaws.com`.

**A3.** Missing SA annotation → the pod silently uses the **node role**. `sub` mismatch →
`AccessDenied` on assume. OIDC provider missing or wrong ARN → `InvalidIdentityToken`. Pod using a
different SA than you think → wrong `sub`.

**A4.** IRSA: per-cluster OIDC provider, `sub` condition in the trust policy, portable to any
Kubernetes. Pod Identity: one API association, simple service-principal trust, role reusable across
clusters unchanged, **EKS only**. Pod Identity for simplicity on EKS; IRSA when you need portability
or are working in an existing cluster that already uses it.

**A5.** All three answer *"how does a workload get cloud credentials without holding a credential?"*
with the same pattern: **a trusted identity provider signs a short-lived token asserting the
workload's identity, and a trust policy decides which assertions may be exchanged for STS
credentials.**

**A6.** **Missing subnet tags** — `kubernetes.io/role/elb=1` on public subnets and
`kubernetes.io/role/internal-elb=1` on private. Also: IRSA not set up for the controller,
`ingressClassName` missing, or fewer than two subnets in different AZs.

**A7.** `ip` registers **pod IPs directly** (one fewer hop, balances across pods, works with
Fargate). `instance` registers node IPs on the NodePort (balances across nodes, extra kube-proxy hop,
no Fargate).

**A8.** GitOps requires everything in Git; secrets must not be in Git. **External Secrets** keeps the
value in a real secrets manager and syncs it at runtime — the value never enters Git and rotation is
automatic. **Sealed Secrets** puts an encrypted value in Git, decryptable only by the cluster —
rotation means re-sealing and re-committing. **SOPS** is similar with more flexibility and the same
rotation friction. ESO is the current best practice.

**A9.** **Security:** in a push model CI holds credentials to every cluster, so compromising CI
compromises production; in a pull model the agent runs inside the cluster and there is nothing in CI
to steal. **Counter-argument:** pull-based delivery makes imperative steps (migrations, smoke tests)
awkward — which is what ArgoCD's `PreSync`/`PostSync` hooks exist for.

**A10.** They order resource application within a sync. Lower numbers first.
`-3` namespace/quota → `-2` secrets/RBAC → `-1` database StatefulSet → `0` app Deployment →
`1` Ingress/HPA/PDB.

**A11.** An **immutable field** changed (Deployment `selector`, Service `clusterIP`, StatefulSet
`volumeClaimTemplates`) — the API server rejects the update and ArgoCD retries forever. Fixes:
`argocd.argoproj.io/sync-options: Replace=true`, or `ignoreDifferences` if the field is legitimately
owned by something else.

**A12.** **ALBs/NLBs created by the AWS Load Balancer Controller** (from Ingress and
`type: LoadBalancer` Services), **EBS volumes** from PVCs, and security groups the controller created.
Terraform doesn't know they exist because the *controller* created them. Delete the Kubernetes
objects first, then destroy the cluster.

---

**B13.** `aws eks update-kubeconfig --name mastery --region us-east-1`
**B14.** `kubectl -n ns exec POD -- aws sts get-caller-identity`
**B15.** `kubectl -n ns exec POD -- sh -c 'cat $AWS_WEB_IDENTITY_TOKEN_FILE' | cut -d. -f2 | base64 -d`
**B16.** `kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --tail=100`
**B17.** `argocd app diff <app>`
**B18.** `aws elbv2 describe-load-balancers --query 'LoadBalancers[].LoadBalancerName'` — compare
against `terraform state list`

---

**C19.** The manifest in Git specifies `replicas`, the HPA changes it at runtime, and ArgoCD reverts
it back — an infinite loop. **Fix:** remove `replicas` from the manifest entirely and add
`ignoreDifferences` on `/spec/replicas` so ArgoCD does not manage that field. Whoever owns a field
must be the *only* thing that owns it.

**C20.** *"That means our CI system holds credentials to every cluster including production — so
compromising a CI runner, or a malicious action in a workflow, compromises production directly. I'd
rather run ArgoCD in each cluster and have it pull from Git: cluster credentials never leave the
cluster, we get drift detection and self-healing for free, and Git history becomes the deployment
audit trail, which is what an auditor will ask for anyway. If we need imperative steps like
migrations, ArgoCD sync hooks cover them."*

## Scoring
| | |
|---|---|
| 16–20 | Move on to Gate 4. |
| 12–15 | Redo Lab 2. IRSA is the week's centerpiece and a common interview question. |
| < 12 | Redo Labs 2 and 4. |

**And: `aws eks list-clusters` — is it empty? `make cost` — under $20?**
