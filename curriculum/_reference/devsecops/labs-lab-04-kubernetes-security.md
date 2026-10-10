# Lab 4: Kubernetes Security

## Objectives

- Implement Kubernetes RBAC with least privilege
- Configure Pod Security Standards
- Deploy and configure Network Policies
- Set up admission controllers for security enforcement
- Implement runtime security monitoring

## Prerequisites

- Kubernetes cluster (minikube, kind, or cloud-based)
- kubectl configured
- Helm 3.x installed
- Basic Kubernetes knowledge

## Duration

3 hours

## Lab Environment Setup

```bash
# Create lab namespace
kubectl create namespace security-lab

# Verify cluster access
kubectl cluster-info
kubectl get nodes

# Install Kyverno (admission controller)
helm repo add kyverno https://kyverno.github.io/kyverno/
helm install kyverno kyverno/kyverno -n kyverno --create-namespace
```

## Part 1: RBAC Configuration (45 minutes)

### Task 1.1: Create Service Accounts and Roles

```yaml
# rbac/service-accounts.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-reader
  namespace: security-lab
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-deployer
  namespace: security-lab
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-admin
  namespace: security-lab
```

```yaml
# rbac/roles.yaml
# Read-only role for viewing resources
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: security-lab
rules:
- apiGroups: [""]
  resources: ["pods", "pods/log", "services", "configmaps"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch"]
---
# Deployer role - can manage deployments
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: deployment-manager
  namespace: security-lab
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
- apiGroups: ["apps"]
  resources: ["replicasets"]
  verbs: ["get", "list", "watch"]
---
# Admin role - full access within namespace
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: namespace-admin
  namespace: security-lab
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
```

### Task 1.2: Create Role Bindings

```yaml
# rbac/role-bindings.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods
  namespace: security-lab
subjects:
- kind: ServiceAccount
  name: app-reader
  namespace: security-lab
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: manage-deployments
  namespace: security-lab
subjects:
- kind: ServiceAccount
  name: app-deployer
  namespace: security-lab
roleRef:
  kind: Role
  name: deployment-manager
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: admin-access
  namespace: security-lab
subjects:
- kind: ServiceAccount
  name: app-admin
  namespace: security-lab
roleRef:
  kind: Role
  name: namespace-admin
  apiGroup: rbac.authorization.k8s.io
```

### Task 1.3: Test RBAC Permissions

```bash
# Apply RBAC resources
kubectl apply -f rbac/

# Test as app-reader (should succeed)
kubectl auth can-i get pods --as=system:serviceaccount:security-lab:app-reader -n security-lab
# Output: yes

kubectl auth can-i create pods --as=system:serviceaccount:security-lab:app-reader -n security-lab
# Output: no

# Test as app-deployer (should succeed for deployments)
kubectl auth can-i create deployments --as=system:serviceaccount:security-lab:app-deployer -n security-lab
# Output: yes

kubectl auth can-i delete secrets --as=system:serviceaccount:security-lab:app-deployer -n security-lab
# Output: no

# Test cross-namespace access (should fail)
kubectl auth can-i get pods --as=system:serviceaccount:security-lab:app-reader -n default
# Output: no
```

### Task 1.4: Audit RBAC with rakkess

```bash
# Install rakkess
kubectl krew install access-matrix

# Check what a service account can do
kubectl access-matrix --as=system:serviceaccount:security-lab:app-deployer -n security-lab

# Generate RBAC report
kubectl access-matrix -n security-lab --verbs=create,delete,update
```

## Part 2: Pod Security Standards (45 minutes)

### Task 2.1: Configure Namespace Labels

```yaml
# namespaces/production.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: latest
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/audit-version: latest
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/warn-version: latest
---
apiVersion: v1
kind: Namespace
metadata:
  name: development
  labels:
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/enforce-version: latest
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/warn-version: latest
```

### Task 2.2: Test Pod Security Standards

```yaml
# test-pods/insecure-pod.yaml (will be rejected in production)
apiVersion: v1
kind: Pod
metadata:
  name: insecure-pod
  namespace: production
spec:
  containers:
  - name: test
    image: nginx:latest
    securityContext:
      privileged: true  # Will be rejected
      runAsUser: 0      # Will be rejected
```

```yaml
# test-pods/secure-pod.yaml (will be accepted)
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
  namespace: production
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 65534
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: test
    image: nginx:latest
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
          - ALL
    volumeMounts:
    - name: tmp
      mountPath: /tmp
    - name: cache
      mountPath: /var/cache/nginx
    - name: run
      mountPath: /var/run
  volumes:
  - name: tmp
    emptyDir: {}
  - name: cache
    emptyDir: {}
  - name: run
    emptyDir: {}
```

```bash
# Test pod creation
kubectl apply -f test-pods/insecure-pod.yaml
# Error: pods "insecure-pod" is forbidden: violates PodSecurity "restricted:latest"

kubectl apply -f test-pods/secure-pod.yaml
# pod/secure-pod created
```

## Part 3: Network Policies (45 minutes)

### Task 3.1: Default Deny Policy

```yaml
# network-policies/default-deny.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

### Task 3.2: Allow DNS Egress

```yaml
# network-policies/allow-dns.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
      podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
```

### Task 3.3: Application-Specific Policies

```yaml
# network-policies/frontend-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-policy
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: frontend
  policyTypes:
  - Ingress
  - Egress
  ingress:
  # Allow from ingress controller
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: ingress-nginx
    ports:
    - protocol: TCP
      port: 8080
  egress:
  # Allow to backend
  - to:
    - podSelector:
        matchLabels:
          app: backend
    ports:
    - protocol: TCP
      port: 8080
---
# network-policies/backend-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-policy
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: database
    ports:
    - protocol: TCP
      port: 5432
---
# network-policies/database-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: database-policy
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: database
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: backend
    ports:
    - protocol: TCP
      port: 5432
  egress: []  # Database should not initiate connections
```

### Task 3.4: Test Network Policies

```bash
# Apply network policies
kubectl apply -f network-policies/

# Deploy test pods
kubectl run frontend --image=nginx --labels="app=frontend" -n production
kubectl run backend --image=nginx --labels="app=backend" -n production
kubectl run attacker --image=nginx --labels="app=attacker" -n production

# Test connectivity (from frontend to backend - should work)
kubectl exec -n production frontend -- wget -qO- --timeout=2 http://backend:8080
# Success

# Test connectivity (from attacker to backend - should fail)
kubectl exec -n production attacker -- wget -qO- --timeout=2 http://backend:8080
# Connection timed out
```

## Part 4: Admission Controllers (45 minutes)

### Task 4.1: Kyverno Policies

```yaml
# kyverno/disallow-privileged.yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: disallow-privileged-containers
spec:
  validationFailureAction: Enforce
  background: true
  rules:
  - name: deny-privileged
    match:
      any:
      - resources:
          kinds:
          - Pod
    validate:
      message: "Privileged containers are not allowed"
      pattern:
        spec:
          containers:
          - =(securityContext):
              =(privileged): false
---
# kyverno/require-labels.yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-labels
spec:
  validationFailureAction: Enforce
  background: true
  rules:
  - name: require-team-label
    match:
      any:
      - resources:
          kinds:
          - Pod
          - Deployment
    validate:
      message: "Resources must have 'team' label"
      pattern:
        metadata:
          labels:
            team: "?*"
---
# kyverno/require-resource-limits.yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-resource-limits
spec:
  validationFailureAction: Enforce
  background: true
  rules:
  - name: require-limits
    match:
      any:
      - resources:
          kinds:
          - Pod
    validate:
      message: "CPU and memory limits are required"
      pattern:
        spec:
          containers:
          - resources:
              limits:
                memory: "?*"
                cpu: "?*"
---
# kyverno/disallow-latest-tag.yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: disallow-latest-tag
spec:
  validationFailureAction: Enforce
  background: true
  rules:
  - name: require-image-tag
    match:
      any:
      - resources:
          kinds:
          - Pod
    validate:
      message: "Using 'latest' tag is not allowed"
      pattern:
        spec:
          containers:
          - image: "!*:latest"
---
# kyverno/verify-image-signature.yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-image-signature
spec:
  validationFailureAction: Enforce
  background: false
  rules:
  - name: verify-signature
    match:
      any:
      - resources:
          kinds:
          - Pod
    verifyImages:
    - imageReferences:
      - "myregistry.com/*"
      attestors:
      - count: 1
        entries:
        - keys:
            publicKeys: |-
              -----BEGIN PUBLIC KEY-----
              YOUR_COSIGN_PUBLIC_KEY_HERE
              -----END PUBLIC KEY-----
```

### Task 4.2: Mutation Policies

```yaml
# kyverno/add-default-security-context.yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: add-default-security-context
spec:
  rules:
  - name: add-security-context
    match:
      any:
      - resources:
          kinds:
          - Pod
    mutate:
      patchStrategicMerge:
        spec:
          securityContext:
            runAsNonRoot: true
            seccompProfile:
              type: RuntimeDefault
          containers:
          - (name): "*"
            securityContext:
              allowPrivilegeEscalation: false
              readOnlyRootFilesystem: true
              capabilities:
                drop:
                - ALL
---
# kyverno/add-resource-defaults.yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: add-resource-defaults
spec:
  rules:
  - name: add-default-resources
    match:
      any:
      - resources:
          kinds:
          - Pod
    mutate:
      patchStrategicMerge:
        spec:
          containers:
          - (name): "*"
            resources:
              limits:
                +(memory): "256Mi"
                +(cpu): "200m"
              requests:
                +(memory): "128Mi"
                +(cpu): "100m"
```

### Task 4.3: Test Admission Policies

```bash
# Apply Kyverno policies
kubectl apply -f kyverno/

# Test privileged container (should be blocked)
kubectl run test-priv --image=nginx:1.25 --privileged -n security-lab
# Error: admission webhook denied the request

# Test without labels (should be blocked)
kubectl run test-no-labels --image=nginx:1.25 -n security-lab
# Error: Resources must have 'team' label

# Test with latest tag (should be blocked)
kubectl run test-latest --image=nginx:latest --labels="team=platform" -n security-lab
# Error: Using 'latest' tag is not allowed

# Test compliant pod (should succeed)
kubectl run test-compliant --image=nginx:1.25 --labels="team=platform" -n security-lab
# pod/test-compliant created
```

## Part 5: Runtime Security with Falco (30 minutes)

### Task 5.1: Install Falco

```bash
# Add Falco Helm repo
helm repo add falcosecurity https://falcosecurity.github.io/charts

# Install Falco
helm install falco falcosecurity/falco \
  --namespace falco \
  --create-namespace \
  --set falcosidekick.enabled=true \
  --set falcosidekick.webui.enabled=true
```

### Task 5.2: Custom Falco Rules

```yaml
# falco/custom-rules.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: falco-custom-rules
  namespace: falco
data:
  custom-rules.yaml: |
    - rule: Terminal Shell in Container
      desc: Detect shell opened in a container
      condition: >
        spawned_process and
        container and
        shell_procs and
        proc.pname != sshd
      output: >
        Shell opened in container
        (user=%user.name container=%container.name
        shell=%proc.name parent=%proc.pname)
      priority: WARNING
      tags: [container, shell]

    - rule: Sensitive File Access
      desc: Detect access to sensitive files
      condition: >
        open_read and
        container and
        (fd.name startswith /etc/passwd or
         fd.name startswith /etc/shadow or
         fd.name startswith /etc/kubernetes)
      output: >
        Sensitive file accessed in container
        (file=%fd.name container=%container.name
        user=%user.name)
      priority: WARNING
      tags: [container, filesystem]

    - rule: Outbound Network Connection
      desc: Detect outbound connections from containers
      condition: >
        outbound and
        container and
        fd.l4proto = tcp and
        not (fd.sport in (80, 443, 8080, 8443))
      output: >
        Suspicious outbound connection
        (container=%container.name ip=%fd.sip port=%fd.sport)
      priority: NOTICE
      tags: [container, network]

    - rule: Crypto Mining Detection
      desc: Detect potential crypto mining
      condition: >
        spawned_process and
        container and
        (proc.name in (xmrig, minerd, cgminer, cpuminer) or
         proc.args contains "stratum+tcp")
      output: >
        Crypto mining detected
        (container=%container.name process=%proc.name)
      priority: CRITICAL
      tags: [container, cryptomining]
```

### Task 5.3: Test Falco Detection

```bash
# Open shell in container (will trigger alert)
kubectl exec -it test-compliant -n security-lab -- /bin/bash

# Check Falco logs
kubectl logs -l app.kubernetes.io/name=falco -n falco | grep "Shell opened"

# Access Falco Sidekick UI
kubectl port-forward svc/falco-falcosidekick-ui 2802:2802 -n falco
# Open http://localhost:2802
```

## Verification

Complete the following checklist:

- [ ] Created and tested RBAC roles and bindings
- [ ] Configured Pod Security Standards on namespaces
- [ ] Created and tested Network Policies
- [ ] Deployed Kyverno admission controller
- [ ] Created validation and mutation policies
- [ ] Installed and configured Falco
- [ ] Created custom Falco rules
- [ ] Verified all security controls work as expected

## Challenge Tasks

1. **OPA Gatekeeper**: Install Gatekeeper and create ConstraintTemplates for custom policies

2. **Service Mesh Security**: Implement Istio mTLS for service-to-service communication

3. **Secrets Encryption**: Configure etcd encryption for Kubernetes secrets at rest

## Summary

In this lab, you:
- Implemented RBAC with least privilege principles
- Configured Pod Security Standards for namespace-level enforcement
- Created Network Policies for microsegmentation
- Deployed admission controllers for policy enforcement
- Set up runtime security monitoring with Falco

## Next Steps

- Lab 5: Secrets Management
- Review CIS Kubernetes Benchmark
- Study Kubernetes Security Best Practices

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- RBAC Configuration
- Pod Security Standards
- Network Policies
- Admission Controllers

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"We scan for vulnerabilities in the pipeline."* |
| ✓ | *"SAST reads source without running it, SCA resolves the dependency tree against an advisory database, and image scanning compares installed package versions to that same database. All three report what was known at build time — which is why the registry is re-scanned: the image does not change, the database does."* |

**Trace it:** A CVE published today against your base image → a blocked deploy. Name every component between the advisory and the refused `apply`.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** the [SLSA threat model](https://slsa.dev/spec/v1.2/threats) — it names every point at which a build can be subverted, and most teams defend three of them.
Full list per domain: [`SOURCES.md`](../SOURCES.md#devsecops)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../MASTERY.md)

<!-- /feynman-check -->
