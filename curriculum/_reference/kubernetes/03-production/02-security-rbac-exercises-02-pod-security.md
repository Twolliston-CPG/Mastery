# Exercise 2: Pod Security Standards

## Objectives

- Understand Pod Security Standards (PSS)
- Implement Pod Security Admission (PSA)
- Configure security contexts
- Migrate from PodSecurityPolicies

## Prerequisites

- Completed Exercise 1 (RBAC Configuration)
- Kubernetes 1.25+ cluster
- Cluster admin access

---

## Part 1: Pod Security Standards

### 1.1 Security Levels

**Pod Security Standards**

**PRIVILEGED**

- No restrictions
- Full host access
- Use for: System components, trusted workloads

**BASELINE**

- Prevents known privilege escalations
- Allows common workloads
- Use for: Most applications

**RESTRICTED**

- Heavily restricted
- Best practices enforced
- Use for: Security-sensitive workloads

**Enforcement Modes:**

- enforce: Reject pods that violate
- audit: Log violations, allow pods
- warn: Warn user, allow pods


### 1.2 Restricted Profile Constraints

```yaml
# Restricted profile requires:
spec:
  containers:
  - name: app
    securityContext:
      # Must run as non-root
      runAsNonRoot: true
      runAsUser: 1000  # Non-zero UID

      # Must drop ALL capabilities
      capabilities:
        drop: ["ALL"]

      # Must be read-only root filesystem
      readOnlyRootFilesystem: true

      # Must not allow privilege escalation
      allowPrivilegeEscalation: false

      # Seccomp profile required
      seccompProfile:
        type: RuntimeDefault

  # No host namespaces
  hostNetwork: false
  hostPID: false
  hostIPC: false

  # No host paths
  volumes: []  # No hostPath volumes

  # No privileged containers
  # privileged: false (implicit)
```

---

## Part 2: Pod Security Admission

### 2.1 Namespace-Level Enforcement

```yaml
# namespace-psa.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    # Enforce restricted profile
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: latest

    # Audit baseline violations
    pod-security.kubernetes.io/audit: baseline
    pod-security.kubernetes.io/audit-version: latest

    # Warn on baseline violations
    pod-security.kubernetes.io/warn: baseline
    pod-security.kubernetes.io/warn-version: latest
---
apiVersion: v1
kind: Namespace
metadata:
  name: staging
  labels:
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/enforce-version: latest
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/warn-version: latest
---
apiVersion: v1
kind: Namespace
metadata:
  name: kube-system
  labels:
    # System namespace - privileged
    pod-security.kubernetes.io/enforce: privileged
    pod-security.kubernetes.io/enforce-version: latest
```

### 2.2 Cluster-Wide Configuration

```yaml
# psa-config.yaml (AdmissionConfiguration)
apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration
plugins:
  - name: PodSecurity
    configuration:
      apiVersion: pod-security.admission.config.k8s.io/v1
      kind: PodSecurityConfiguration
      defaults:
        enforce: "baseline"
        enforce-version: "latest"
        audit: "restricted"
        audit-version: "latest"
        warn: "restricted"
        warn-version: "latest"
      exemptions:
        # Exempt specific users
        usernames:
          - system:serviceaccount:kube-system:replicaset-controller
        # Exempt namespaces
        namespaces:
          - kube-system
          - istio-system
        # Exempt runtime classes
        runtimeClasses:
          - kata-containers
```

---

## Part 3: Security Contexts

### 3.1 Pod Security Context

```yaml
# pod-security-context.yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
spec:
  # Pod-level security context
  securityContext:
    # Run as non-root user
    runAsUser: 1000
    runAsGroup: 3000
    fsGroup: 2000

    # Supplemental groups for volumes
    supplementalGroups: [4000]

    # SELinux options
    seLinuxOptions:
      level: "s0:c123,c456"

    # Seccomp profile
    seccompProfile:
      type: RuntimeDefault

    # Sysctls (limited set)
    sysctls:
      - name: net.core.somaxconn
        value: "1024"

  containers:
  - name: app
    image: myapp:1.0
    # Container-level overrides
    securityContext:
      runAsNonRoot: true
      readOnlyRootFilesystem: true
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
```

### 3.2 Capability Management

```yaml
# capabilities.yaml
apiVersion: v1
kind: Pod
metadata:
  name: capabilities-demo
spec:
  containers:
  - name: minimal-caps
    image: myapp:1.0
    securityContext:
      capabilities:
        # Drop all capabilities
        drop: ["ALL"]

  - name: net-admin
    image: network-tool:1.0
    securityContext:
      capabilities:
        drop: ["ALL"]
        # Add only what's needed
        add:
          - NET_ADMIN
          - NET_RAW

  - name: bind-low-port
    image: nginx:1.25
    securityContext:
      capabilities:
        drop: ["ALL"]
        add:
          - NET_BIND_SERVICE  # Bind to ports < 1024
```

### 3.3 Read-Only Filesystem

```yaml
# readonly-fs.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: readonly-app
spec:
  template:
    spec:
      containers:
      - name: app
        image: myapp:1.0
        securityContext:
          readOnlyRootFilesystem: true
        volumeMounts:
        # Writable tmp directory
        - name: tmp
          mountPath: /tmp
        # Writable cache
        - name: cache
          mountPath: /app/cache
        # Writable logs
        - name: logs
          mountPath: /var/log/app
      volumes:
      - name: tmp
        emptyDir: {}
      - name: cache
        emptyDir: {}
      - name: logs
        emptyDir: {}
```

---

## Part 4: Seccomp Profiles

### 4.1 Using RuntimeDefault

```yaml
# seccomp-default.yaml
apiVersion: v1
kind: Pod
metadata:
  name: seccomp-default
spec:
  securityContext:
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: myapp:1.0
```

### 4.2 Custom Seccomp Profile

```json
// /var/lib/kubelet/seccomp/profiles/custom.json
{
  "defaultAction": "SCMP_ACT_ERRNO",
  "architectures": ["SCMP_ARCH_X86_64"],
  "syscalls": [
    {
      "names": [
        "accept4", "access", "arch_prctl", "bind", "brk",
        "close", "connect", "epoll_create1", "epoll_ctl",
        "epoll_pwait", "execve", "exit_group", "fcntl",
        "fstat", "futex", "getdents64", "getpeername",
        "getpid", "getsockname", "getsockopt", "listen",
        "lseek", "mmap", "mprotect", "munmap", "nanosleep",
        "newfstatat", "openat", "pipe2", "prctl", "pread64",
        "read", "readlink", "recvfrom", "rt_sigaction",
        "rt_sigprocmask", "sendto", "set_robust_list",
        "set_tid_address", "setsockopt", "socket", "stat",
        "uname", "write"
      ],
      "action": "SCMP_ACT_ALLOW"
    }
  ]
}
```

```yaml
# Using custom profile
apiVersion: v1
kind: Pod
metadata:
  name: seccomp-custom
spec:
  securityContext:
    seccompProfile:
      type: Localhost
      localhostProfile: profiles/custom.json
  containers:
  - name: app
    image: myapp:1.0
```

### 4.3 Security Profile Operator

```bash
# Install Security Profile Operator
kubectl apply -f https://github.com/kubernetes-sigs/security-profiles-operator/releases/download/v0.8.0/install.yaml
```

```yaml
# seccomp-profile-crd.yaml
apiVersion: security-profiles-operator.x-k8s.io/v1beta1
kind: SeccompProfile
metadata:
  name: nginx-profile
  namespace: default
spec:
  defaultAction: SCMP_ACT_ERRNO
  architectures:
    - SCMP_ARCH_X86_64
  syscalls:
    - action: SCMP_ACT_ALLOW
      names:
        - accept4
        - bind
        - clone
        - close
        - connect
        - epoll_create
        - epoll_ctl
        - epoll_wait
        - exit_group
        - fcntl
        - fstat
        - futex
        - getpeername
        - getsockname
        - getsockopt
        - ioctl
        - listen
        - mmap
        - mprotect
        - munmap
        - nanosleep
        - openat
        - prctl
        - pread64
        - read
        - recvfrom
        - recvmsg
        - rt_sigaction
        - rt_sigprocmask
        - sendmsg
        - setsockopt
        - socket
        - write
        - writev
```

---

## Part 5: AppArmor Profiles

### 5.1 AppArmor Integration

```yaml
# apparmor-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: apparmor-pod
  annotations:
    # Apply AppArmor profile to container
    container.apparmor.security.beta.kubernetes.io/app: localhost/custom-profile
spec:
  containers:
  - name: app
    image: myapp:1.0
```

### 5.2 Custom AppArmor Profile

```
# /etc/apparmor.d/custom-profile
#include <tunables/global>

profile custom-profile flags=(attach_disconnected,mediate_deleted) {
  #include <abstractions/base>
  #include <abstractions/nameservice>

  # Deny all file writes except specific paths
  deny /** w,

  # Allow reading necessary paths
  /etc/passwd r,
  /etc/group r,
  /etc/nsswitch.conf r,
  /etc/hosts r,
  /etc/resolv.conf r,

  # Allow app directory
  /app/** r,
  /app/cache/** rw,

  # Allow tmp
  /tmp/** rw,

  # Network access
  network inet stream,
  network inet dgram,
  network inet6 stream,
  network inet6 dgram,

  # Deny raw network access
  deny network raw,
}
```

---

## Part 6: Compliance Examples

### 6.1 Restricted Deployment Template

```yaml
# restricted-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: compliant-app
  namespace: production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: compliant-app
  template:
    metadata:
      labels:
        app: compliant-app
    spec:
      # Non-root user
      securityContext:
        runAsNonRoot: true
        runAsUser: 10000
        runAsGroup: 10000
        fsGroup: 10000
        seccompProfile:
          type: RuntimeDefault

      # No automount of service account token
      automountServiceAccountToken: false

      containers:
      - name: app
        image: myapp:1.0
        ports:
        - containerPort: 8080

        # Container security
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop: ["ALL"]

        # Resource limits (required for some policies)
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 256Mi

        # Writable volumes
        volumeMounts:
        - name: tmp
          mountPath: /tmp
        - name: cache
          mountPath: /var/cache

      volumes:
      - name: tmp
        emptyDir:
          sizeLimit: 100Mi
      - name: cache
        emptyDir:
          sizeLimit: 500Mi
```

### 6.2 Validation Script

```bash
#!/bin/bash
# validate-pod-security.sh

NAMESPACE=${1:-default}

echo "=== Pod Security Validation for namespace: $NAMESPACE ==="

# Check namespace labels
echo -e "\n--- Namespace PSA Labels ---"
kubectl get namespace $NAMESPACE -o jsonpath='{.metadata.labels}' | jq '.'

# Check pods for security context
echo -e "\n--- Pod Security Contexts ---"
kubectl get pods -n $NAMESPACE -o json | jq -r '
  .items[] |
  "Pod: \(.metadata.name)\n" +
  "  runAsNonRoot: \(.spec.containers[0].securityContext.runAsNonRoot // "not set")\n" +
  "  readOnlyRootFilesystem: \(.spec.containers[0].securityContext.readOnlyRootFilesystem // "not set")\n" +
  "  allowPrivilegeEscalation: \(.spec.containers[0].securityContext.allowPrivilegeEscalation // "not set")\n" +
  "  capabilities.drop: \(.spec.containers[0].securityContext.capabilities.drop // ["not set"])\n"
'

# Test pod creation with violations
echo -e "\n--- Testing Privileged Pod Creation ---"
kubectl run test-privileged \
  --image=nginx \
  --dry-run=server \
  -n $NAMESPACE \
  --overrides='{"spec":{"containers":[{"name":"nginx","image":"nginx","securityContext":{"privileged":true}}]}}' \
  2>&1 || echo "Correctly rejected privileged pod"

echo -e "\n--- Testing Root Pod Creation ---"
kubectl run test-root \
  --image=nginx \
  --dry-run=server \
  -n $NAMESPACE \
  --overrides='{"spec":{"containers":[{"name":"nginx","image":"nginx","securityContext":{"runAsUser":0}}]}}' \
  2>&1 || echo "Correctly rejected root pod"
```

---

## Part 7: Hands-on Challenges

### Challenge 1: Namespace Migration

Migrate namespace to restricted:
1. Audit current pods for violations
2. Fix non-compliant workloads
3. Enable warn mode first
4. Enable enforce mode

### Challenge 2: Custom Seccomp Profile

Create minimal seccomp profile:
1. Use profile recording
2. Run application workload
3. Generate minimal profile
4. Test application functionality

### Challenge 3: Zero-Trust Pod Security

Implement maximum security:
1. Restricted PSS enforcement
2. Custom seccomp profiles
3. AppArmor profiles
4. Network policies

---

## Verification Tasks

1. [ ] Configured namespace-level PSA
2. [ ] Created compliant pod security contexts
3. [ ] Implemented capability restrictions
4. [ ] Set up read-only filesystems
5. [ ] Configured seccomp profiles
6. [ ] Tested PSA enforcement

---

## Key Takeaways

- Pod Security Standards replace PodSecurityPolicies
- Three levels: Privileged, Baseline, Restricted
- Use warn/audit before enforce
- Security contexts define pod permissions
- Drop all capabilities, add only needed ones
- Read-only filesystems improve security

---

## Next Steps

Continue to [Exercise 3: Network Policies](03-network-policies.md)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Pod Security Standards
- Pod Security Admission
- Security Contexts
- Seccomp Profiles

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
