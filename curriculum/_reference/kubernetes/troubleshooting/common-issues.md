# Kubernetes Troubleshooting Guide

## Common Issues and Solutions

### Table of Contents

1. [Pod Issues](#pod-issues)
2. [Networking Issues](#networking-issues)
3. [Storage Issues](#storage-issues)
4. [Resource Issues](#resource-issues)
5. [Security Issues](#security-issues)
6. [Performance Issues](#performance-issues)

---

## Pod Issues

### Pod Stuck in Pending State

**Symptoms:**
```bash
kubectl get pods
# NAME          READY   STATUS    RESTARTS   AGE
# my-pod        0/1     Pending   0          5m
```

**Diagnosis:**
```bash
# Check pod events
kubectl describe pod my-pod

# Check node resources
kubectl describe nodes | grep -A 5 "Allocated resources"

# Check for pending PVCs
kubectl get pvc
```

**Common Causes & Solutions:**

1. **Insufficient Resources**
   ```bash
   # Check node capacity
   kubectl top nodes

   # Solution: Scale cluster or reduce resource requests
   ```

2. **No Matching Nodes (nodeSelector/affinity)**
   ```bash
   # Check node labels
   kubectl get nodes --show-labels

   # Solution: Add correct labels to nodes or fix selector
   kubectl label nodes <node-name> <label-key>=<label-value>
   ```

3. **PVC Not Bound**
   ```bash
   # Check PVC status
   kubectl get pvc
   kubectl describe pvc <pvc-name>

   # Solution: Create StorageClass or provision PV
   ```

### Pod Stuck in CrashLoopBackOff

**Diagnosis:**
```bash
# Check pod logs
kubectl logs my-pod --previous
kubectl logs my-pod -c <container-name>

# Check pod events
kubectl describe pod my-pod
```

**Common Causes & Solutions:**

1. **Application Error**
   ```bash
   # Check logs for error messages
   kubectl logs my-pod --tail=100

   # Solution: Fix application code or configuration
   ```

2. **Missing ConfigMap/Secret**
   ```bash
   # Check if resources exist
   kubectl get configmap
   kubectl get secret

   # Solution: Create missing resources
   ```

3. **Liveness Probe Failing**
   ```yaml
   # Increase probe timeouts
   livenessProbe:
     httpGet:
       path: /health
       port: 8080
     initialDelaySeconds: 60  # Increase startup time
     periodSeconds: 10
     failureThreshold: 6
   ```

### Pod Stuck in ImagePullBackOff

**Diagnosis:**
```bash
kubectl describe pod my-pod | grep -A 10 "Events"
```

**Common Causes & Solutions:**

1. **Wrong Image Name/Tag**
   ```bash
   # Verify image exists
   docker pull <image:tag>

   # Solution: Fix image reference in deployment
   ```

2. **Private Registry Authentication**
   ```bash
   # Create image pull secret
   kubectl create secret docker-registry regcred \
     --docker-server=<registry> \
     --docker-username=<user> \
     --docker-password=<password>

   # Reference in pod spec
   # imagePullSecrets:
   # - name: regcred
   ```

---

## Networking Issues

### Service Not Accessible

**Diagnosis:**
```bash
# Check service endpoints
kubectl get endpoints <service-name>

# Test from within cluster
kubectl run test --rm -it --image=busybox -- wget -qO- <service-name>:<port>

# Check pod labels match service selector
kubectl get pods --show-labels
kubectl describe svc <service-name>
```

**Common Causes & Solutions:**

1. **No Endpoints**
   ```bash
   # Verify selector matches pod labels
   kubectl get svc <service-name> -o yaml | grep selector -A 5
   kubectl get pods -l <selector>

   # Solution: Fix selector or pod labels
   ```

2. **Pod Not Ready**
   ```bash
   # Check pod readiness
   kubectl get pods -o wide

   # Solution: Fix readiness probe or application
   ```

### DNS Resolution Failing

**Diagnosis:**
```bash
# Test DNS from pod
kubectl run test --rm -it --image=busybox -- nslookup kubernetes

# Check CoreDNS
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns
```

**Solutions:**
```bash
# Restart CoreDNS
kubectl rollout restart deployment/coredns -n kube-system

# Check CoreDNS ConfigMap
kubectl get configmap coredns -n kube-system -o yaml
```

### Ingress Not Working

**Diagnosis:**
```bash
# Check ingress controller
kubectl get pods -n ingress-nginx

# Check ingress resource
kubectl describe ingress <ingress-name>

# Check ingress controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx
```

**Solutions:**
```bash
# Verify ingress class
kubectl get ingressclass

# Check TLS secret exists
kubectl get secret <tls-secret-name>
```

---

## Storage Issues

### PVC Stuck in Pending

**Diagnosis:**
```bash
kubectl describe pvc <pvc-name>
kubectl get storageclass
kubectl get pv
```

**Common Causes & Solutions:**

1. **No StorageClass**
   ```bash
   # Create default StorageClass
   kubectl get storageclass

   # Mark as default
   kubectl patch storageclass <name> -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
   ```

2. **No Available PV (static provisioning)**
   ```yaml
   # Create PV matching PVC
   apiVersion: v1
   kind: PersistentVolume
   metadata:
     name: my-pv
   spec:
     capacity:
       storage: 10Gi
     accessModes:
       - ReadWriteOnce
     hostPath:
       path: /data/my-pv
   ```

### Volume Mount Failures

**Diagnosis:**
```bash
kubectl describe pod <pod-name>
# Look for mount errors in events
```

**Solutions:**
```bash
# Check permissions
kubectl exec <pod-name> -- ls -la /mount/path

# For hostPath, ensure directory exists on node
ssh <node> 'mkdir -p /data/path && chmod 777 /data/path'
```

---

## Resource Issues

### OOMKilled

**Symptoms:**
```bash
kubectl describe pod <pod-name>
# State: Terminated
# Reason: OOMKilled
```

**Solutions:**
```yaml
# Increase memory limits
resources:
  requests:
    memory: "256Mi"
  limits:
    memory: "512Mi"  # Increase this
```

### CPU Throttling

**Diagnosis:**
```bash
# Check CPU usage
kubectl top pods

# Check throttling metrics
kubectl get --raw /apis/metrics.k8s.io/v1beta1/pods
```

**Solutions:**
```yaml
# Increase CPU limits or remove limits
resources:
  requests:
    cpu: "100m"
  limits:
    cpu: "1000m"  # Increase or remove
```

---

## Security Issues

### RBAC Permission Denied

**Diagnosis:**
```bash
# Check what user/SA can do
kubectl auth can-i --list --as=system:serviceaccount:<namespace>:<sa-name>

# Test specific permission
kubectl auth can-i get pods --as=system:serviceaccount:<namespace>:<sa-name>
```

**Solutions:**
```yaml
# Create RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: my-rolebinding
  namespace: default
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: my-role
subjects:
- kind: ServiceAccount
  name: my-sa
  namespace: default
```

### Pod Security Policy/Standards Violations

**Diagnosis:**
```bash
kubectl describe pod <pod-name>
# Look for admission webhook errors
```

**Solutions:**
```yaml
# Add required security context
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 2000
  seccompProfile:
    type: RuntimeDefault

containers:
- name: app
  securityContext:
    allowPrivilegeEscalation: false
    capabilities:
      drop:
        - ALL
    readOnlyRootFilesystem: true
```

---

## Performance Issues

### High API Server Latency

**Diagnosis:**
```bash
# Check API server metrics
kubectl get --raw /metrics | grep apiserver_request_duration

# Check etcd performance
kubectl -n kube-system logs etcd-<master-node>
```

**Solutions:**
```bash
# Reduce API requests
# - Use informers instead of polling
# - Increase client-side caching
# - Use resource version for watches
```

### Slow Pod Scheduling

**Diagnosis:**
```bash
# Check scheduler
kubectl -n kube-system logs -l component=kube-scheduler

# Check pending pods
kubectl get pods --field-selector=status.phase=Pending
```

**Solutions:**
```bash
# Check resource fragmentation
kubectl describe nodes | grep -A 10 "Allocated resources"

# Consider pod priority and preemption
```

---

## Quick Reference Commands

```bash
# Get all unhealthy pods
kubectl get pods -A | grep -v Running | grep -v Completed

# Get pod restart counts
kubectl get pods -A --sort-by='.status.containerStatuses[0].restartCount'

# Get events sorted by time
kubectl get events --sort-by='.lastTimestamp'

# Get resource usage
kubectl top pods -A --sort-by=cpu
kubectl top pods -A --sort-by=memory

# Debug networking
kubectl run test --rm -it --image=nicolaka/netshoot -- /bin/bash

# Force delete stuck pod
kubectl delete pod <pod-name> --grace-period=0 --force

# Get all images in cluster
kubectl get pods -A -o jsonpath="{.items[*].spec.containers[*].image}" | tr ' ' '\n' | sort | uniq
```

---

## Useful Aliases

Add to `~/.bashrc` or `~/.zshrc`:

```bash
# Kubernetes aliases
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgpa='kubectl get pods -A'
alias kgs='kubectl get svc'
alias kgn='kubectl get nodes'
alias kd='kubectl describe'
alias kl='kubectl logs'
alias klf='kubectl logs -f'
alias kex='kubectl exec -it'
alias kaf='kubectl apply -f'

# Get pods with issues
alias kprob='kubectl get pods -A | grep -v Running | grep -v Completed'

# Watch pods
alias kwp='kubectl get pods -w'

# Get events
alias kev='kubectl get events --sort-by=.lastTimestamp'
```

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Common Issues and Solutions
- Pod Issues
- Networking Issues
- Storage Issues

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
