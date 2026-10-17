# Exercise 1: RBAC Configuration

## Objective

Implement comprehensive Role-Based Access Control (RBAC) for a multi-team Kubernetes environment with proper separation of concerns and least-privilege access.

## Prerequisites

- Running Kubernetes cluster
- Cluster admin access
- Understanding of Kubernetes RBAC concepts

## Scenario

Configure RBAC for an organization with:
- **Platform team**: Full cluster access
- **Development team**: Full access to dev namespace, read access to staging
- **QA team**: Full access to staging, read access to production
- **Operations team**: Read access everywhere, can scale deployments in production

## Tasks

### Task 1: Create Namespaces with Labels

```yaml
# namespaces.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: development
  labels:
    environment: development
    team: dev
---
apiVersion: v1
kind: Namespace
metadata:
  name: staging
  labels:
    environment: staging
    team: qa
---
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    environment: production
    team: ops
```

### Task 2: Create ClusterRoles

```yaml
# cluster-roles.yaml
---
# Full cluster admin (for platform team)
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: platform-admin
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
---
# Developer role - create and manage workloads
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: developer
rules:
- apiGroups: [""]
  resources: ["pods", "pods/log", "pods/exec", "pods/portforward"]
  verbs: ["get", "list", "watch", "create", "delete"]
- apiGroups: [""]
  resources: ["services", "configmaps", "secrets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["persistentvolumeclaims"]
  verbs: ["get", "list", "watch", "create", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets", "statefulsets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["batch"]
  resources: ["jobs", "cronjobs"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["autoscaling"]
  resources: ["horizontalpodautoscalers"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
# Read-only role
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: reader
rules:
- apiGroups: [""]
  resources: ["pods", "pods/log", "services", "configmaps", "endpoints", "persistentvolumeclaims", "events"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets", "statefulsets", "daemonsets"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["batch"]
  resources: ["jobs", "cronjobs"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses", "networkpolicies"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["autoscaling"]
  resources: ["horizontalpodautoscalers"]
  verbs: ["get", "list", "watch"]
---
# Operations role - scale and restart
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: operator
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch", "delete"]  # delete for restarts
- apiGroups: [""]
  resources: ["pods/log", "pods/exec"]
  verbs: ["get", "create"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets", "statefulsets"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments/scale", "replicasets/scale", "statefulsets/scale"]
  verbs: ["get", "update", "patch"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["patch"]  # for rollout restart
  resourceNames: []
---
# Secret reader (restricted)
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: secret-reader
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list", "watch"]
```

### Task 3: Create RoleBindings for Each Team

```yaml
# role-bindings.yaml
---
# Platform team - cluster-wide admin
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: platform-team-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: platform-admin
subjects:
- kind: Group
  name: platform-team
  apiGroup: rbac.authorization.k8s.io
---
# Development team - full access to development namespace
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: dev-team-developer
  namespace: development
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: developer
subjects:
- kind: Group
  name: dev-team
  apiGroup: rbac.authorization.k8s.io
---
# Development team - read access to staging
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: dev-team-staging-reader
  namespace: staging
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: reader
subjects:
- kind: Group
  name: dev-team
  apiGroup: rbac.authorization.k8s.io
---
# QA team - full access to staging
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: qa-team-staging
  namespace: staging
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: developer
subjects:
- kind: Group
  name: qa-team
  apiGroup: rbac.authorization.k8s.io
---
# QA team - read access to production
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: qa-team-production-reader
  namespace: production
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: reader
subjects:
- kind: Group
  name: qa-team
  apiGroup: rbac.authorization.k8s.io
---
# Operations team - read everywhere (cluster-wide)
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: ops-team-reader
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: reader
subjects:
- kind: Group
  name: ops-team
  apiGroup: rbac.authorization.k8s.io
---
# Operations team - operator access in production
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ops-team-production-operator
  namespace: production
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: operator
subjects:
- kind: Group
  name: ops-team
  apiGroup: rbac.authorization.k8s.io
```

### Task 4: Create Service Accounts for Applications

```yaml
# service-accounts.yaml
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-service-account
  namespace: production
---
# Role for the application
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: app-role
  namespace: production
rules:
# Read own configmaps
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list", "watch"]
  resourceNames: ["app-config"]
# Read own secrets
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get"]
  resourceNames: ["app-credentials"]
# Leader election (if needed)
- apiGroups: ["coordination.k8s.io"]
  resources: ["leases"]
  verbs: ["get", "create", "update"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-role-binding
  namespace: production
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: app-role
subjects:
- kind: ServiceAccount
  name: app-service-account
  namespace: production
```

### Task 5: Aggregate ClusterRoles

```yaml
# aggregated-roles.yaml
---
# Base role that can be extended
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: monitoring-viewer
  labels:
    rbac.example.com/aggregate-to-viewer: "true"
rules:
- apiGroups: ["monitoring.coreos.com"]
  resources: ["servicemonitors", "podmonitors", "prometheusrules"]
  verbs: ["get", "list", "watch"]
---
# Aggregated viewer role
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: aggregate-viewer
aggregationRule:
  clusterRoleSelectors:
  - matchLabels:
      rbac.example.com/aggregate-to-viewer: "true"
rules: []  # Rules are automatically filled in by the controller
```

### Task 6: Test RBAC Permissions

```bash
# Create test users (using certificates or OIDC in production)
# For testing, we can use impersonation

# Test as dev-team member
kubectl auth can-i create deployments -n development --as=dev-user --as-group=dev-team
# Expected: yes

kubectl auth can-i create deployments -n production --as=dev-user --as-group=dev-team
# Expected: no

kubectl auth can-i get pods -n staging --as=dev-user --as-group=dev-team
# Expected: yes

# Test as ops-team member
kubectl auth can-i delete pods -n production --as=ops-user --as-group=ops-team
# Expected: yes (for restarts)

kubectl auth can-i create deployments -n production --as=ops-user --as-group=ops-team
# Expected: no

kubectl auth can-i patch deployments/scale -n production --as=ops-user --as-group=ops-team
# Expected: yes

# Comprehensive check
kubectl auth can-i --list --as=dev-user --as-group=dev-team -n development
```

### Task 7: Audit RBAC Configuration

```bash
# Find all ClusterRoleBindings
kubectl get clusterrolebindings -o wide

# Find overly permissive bindings
kubectl get clusterrolebindings -o json | jq '.items[] | select(.roleRef.name == "cluster-admin") | .metadata.name'

# Check who has access to secrets
kubectl auth can-i get secrets --all-namespaces --list

# Find all subjects with cluster-admin
kubectl get clusterrolebindings -o json | jq -r '.items[] | select(.roleRef.name == "cluster-admin") | .subjects[]? | "\(.kind): \(.name)"'
```

## Success Criteria

- [ ] Namespaces created with proper labels
- [ ] ClusterRoles created for each access level
- [ ] RoleBindings correctly scoped to namespaces
- [ ] Service accounts configured for applications
- [ ] Permission tests pass for each team
- [ ] No overly permissive bindings (except intended)

## Security Best Practices

1. **Principle of least privilege** - Grant only necessary permissions
2. **Use namespaces for isolation** - Scope permissions with RoleBindings
3. **Avoid wildcards** - Be explicit about resources and verbs
4. **Regular audits** - Review RBAC configurations periodically
5. **Use groups over users** - Easier to manage at scale
6. **Service account tokens** - Use bound tokens with short TTL

## Cleanup

```bash
kubectl delete namespace development staging production
kubectl delete clusterrole platform-admin developer reader operator secret-reader
kubectl delete clusterrolebinding platform-team-admin ops-team-reader
```

## Next Exercise

Continue to [Exercise 2: Pod Security Standards](02-security-rbac-exercises-02-pod-security.md) to learn about pod-level security controls.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Security Best Practices
- Create Namespaces with Labels
- Create ClusterRoles
- Create RoleBindings for Each Team

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"Kubernetes schedules the pod."* |
| ✓ | *"The scheduler watches for pods with no `nodeName`, filters nodes by predicates, scores the survivors, and writes `nodeName` into the pod spec. The kubelet on that node is watching the API for pods bound to it, and starts the containers."* |

**Trace it:** `kubectl apply -f pod.yaml` → a running container. Name every component that acts, in order, and what each one writes.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** [Kubernetes the Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way) — one weekend, and "the control plane" stops being a word.
Full list per domain: [`SOURCES.md`](../../SOURCES.md#kubernetes)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../../MASTERY.md)

<!-- /feynman-check -->
