# Kubernetes Troubleshooting Guide

## Quick Diagnosis Framework

```
1. Identify the problem scope (cluster, node, namespace, pod)
2. Check events: kubectl get events --sort-by='.lastTimestamp'
3. Check logs: kubectl logs <pod> or systemctl status kubelet
4. Describe resources: kubectl describe <resource> <name>
5. Check network: DNS, services, network policies
6. Review recent changes: kubectl rollout history
```

---

## Pod Issues

### Pod Stuck in Pending

**Symptoms**: Pod stays in `Pending` state

**Diagnosis**:
```bash
kubectl describe pod <pod-name>
# Look at Events section
```

**Common Causes & Solutions**:

| Cause | Event Message | Solution |
|-------|--------------|----------|
| Insufficient resources | `Insufficient cpu/memory` | Scale cluster or reduce requests |
| Node selector mismatch | `0/3 nodes are available: 3 node(s) didn't match node selector` | Fix node labels or selectors |
| Taint not tolerated | `3 node(s) had taints that the pod didn't tolerate` | Add tolerations or remove taints |
| PVC not bound | `pod has unbound immediate PersistentVolumeClaims` | Create PV or check StorageClass |
| No nodes available | `0/0 nodes are available` | Check node status, add nodes |

```bash
# Check node resources
kubectl describe nodes | grep -A 5 "Allocated resources"

# Check PVC status
kubectl get pvc

# Check node taints
kubectl describe nodes | grep Taints
```

### Pod Stuck in ImagePullBackOff

**Symptoms**: Pod shows `ImagePullBackOff` or `ErrImagePull`

**Diagnosis**:
```bash
kubectl describe pod <pod-name>
# Look for "Failed to pull image" in events
```

**Common Causes & Solutions**:

| Cause | Solution |
|-------|----------|
| Image doesn't exist | Verify image name and tag |
| Private registry, no credentials | Create imagePullSecret |
| Network issues | Check node internet connectivity |
| Rate limited (Docker Hub) | Use authenticated pulls or mirror |

```bash
# Create image pull secret
kubectl create secret docker-registry regcred \
  --docker-server=<registry> \
  --docker-username=<user> \
  --docker-password=<password>

# Add to pod spec
spec:
  imagePullSecrets:
  - name: regcred
```

### Pod Stuck in CrashLoopBackOff

**Symptoms**: Pod repeatedly crashes and restarts

**Diagnosis**:
```bash
kubectl logs <pod-name>
kubectl logs <pod-name> --previous  # Previous container logs
kubectl describe pod <pod-name>
```

**Common Causes & Solutions**:

| Cause | Solution |
|-------|----------|
| Application error | Fix application code, check logs |
| Wrong command/args | Verify entrypoint and arguments |
| Missing config/secrets | Ensure ConfigMaps/Secrets exist |
| Liveness probe failing | Adjust probe settings or fix health endpoint |
| OOMKilled | Increase memory limits |
| Permission issues | Check security context, file permissions |

```bash
# Debug with shell
kubectl debug <pod-name> -it --image=busybox

# Run pod with sleep to debug
kubectl run debug --image=<same-image> -- sleep 3600
kubectl exec -it debug -- /bin/sh
```

### Pod OOMKilled

**Symptoms**: Pod terminated with `OOMKilled` reason

**Diagnosis**:
```bash
kubectl describe pod <pod-name> | grep -A 5 "Last State"
```

**Solution**:
```yaml
# Increase memory limits
resources:
  requests:
    memory: "256Mi"
  limits:
    memory: "512Mi"  # Increase this
```

```bash
# Monitor memory usage
kubectl top pod <pod-name>
```

---

## Service Issues

### Service Not Reachable

**Symptoms**: Cannot access service from within cluster

**Diagnosis**:
```bash
# Check service exists and has endpoints
kubectl get svc <service-name>
kubectl get endpoints <service-name>

# If no endpoints, pods aren't matching selector
kubectl get pods -l <service-selector>
```

**Common Causes & Solutions**:

| Cause | Solution |
|-------|----------|
| No endpoints | Fix selector to match pod labels |
| Pods not ready | Check pod readiness probes |
| Wrong port | Verify targetPort matches container port |
| Network policy blocking | Check NetworkPolicies |

```bash
# Test service connectivity
kubectl run test --rm -it --image=busybox -- wget -qO- <service>:<port>

# Check DNS resolution
kubectl run test --rm -it --image=busybox -- nslookup <service>
```

### LoadBalancer Stuck in Pending

**Symptoms**: External IP shows `<pending>`

**Diagnosis**:
```bash
kubectl describe svc <service-name>
```

**Common Causes & Solutions**:

| Cause | Solution |
|-------|----------|
| No cloud controller | Install MetalLB for bare metal |
| No available IPs | Expand IP pool |
| Cloud provider issue | Check cloud provider logs |

---

## Ingress Issues

### Ingress Not Working

**Symptoms**: Cannot access via ingress hostname

**Diagnosis**:
```bash
kubectl describe ingress <ingress-name>
kubectl get pods -n ingress-nginx  # or your ingress namespace
kubectl logs -n ingress-nginx deploy/ingress-nginx-controller
```

**Common Causes & Solutions**:

| Cause | Solution |
|-------|----------|
| Ingress controller not running | Deploy ingress controller |
| Wrong ingressClassName | Match to controller's class |
| Backend service unavailable | Check service and endpoints |
| TLS certificate issue | Verify secret exists and is valid |
| DNS not pointing to ingress | Update DNS or /etc/hosts |

```bash
# Test ingress directly
curl -v -H "Host: example.com" http://<ingress-controller-ip>

# Check ingress controller configuration
kubectl exec -n ingress-nginx deploy/ingress-nginx-controller -- cat /etc/nginx/nginx.conf
```

---

## Node Issues

### Node NotReady

**Symptoms**: Node shows `NotReady` status

**Diagnosis**:
```bash
kubectl describe node <node-name>
# Check Conditions section

# SSH to node
systemctl status kubelet
journalctl -u kubelet -f
```

**Common Causes & Solutions**:

| Cause | Solution |
|-------|----------|
| Kubelet not running | `systemctl restart kubelet` |
| Network plugin issues | Restart CNI pods |
| Disk pressure | Free disk space |
| Memory pressure | Free memory or add capacity |
| PID pressure | Investigate runaway processes |
| Container runtime down | Restart containerd/docker |

```bash
# Check node conditions
kubectl get nodes -o json | jq '.items[].status.conditions'

# Check disk space on node
df -h

# Check memory on node
free -m
```

### Node Disk Pressure

**Symptoms**: Node has `DiskPressure` condition

**Solution**:
```bash
# Find large files/directories
du -sh /* | sort -rh | head -20

# Clean old container images
crictl rmi --prune

# Clean old logs
journalctl --vacuum-time=2d

# Clean unused containers
crictl rm $(crictl ps -a -q)
```

---

## Storage Issues

### PVC Stuck in Pending

**Symptoms**: PVC stays in `Pending` state

**Diagnosis**:
```bash
kubectl describe pvc <pvc-name>
```

**Common Causes & Solutions**:

| Cause | Solution |
|-------|----------|
| No matching PV | Create PV or use dynamic provisioning |
| No StorageClass | Create default StorageClass |
| Provisioner not running | Check CSI driver pods |
| Access mode mismatch | Match PVC to available modes |

```bash
# Check StorageClasses
kubectl get storageclass

# Check PVs
kubectl get pv

# Check CSI drivers
kubectl get pods -A | grep csi
```

---

## Network Policy Issues

### Pods Can't Communicate

**Symptoms**: Connection refused or timeout between pods

**Diagnosis**:
```bash
kubectl get networkpolicies -n <namespace>
kubectl describe networkpolicy <policy-name>
```

**Testing**:
```bash
# Test connectivity
kubectl exec -it <source-pod> -- nc -zv <target-service> <port>

# Check if CNI supports network policies
kubectl get pods -n kube-system | grep -i calico  # or cilium, etc.
```

**Common Fixes**:
```yaml
# Allow all ingress (for debugging)
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-all-ingress
spec:
  podSelector: {}
  ingress:
  - {}
  policyTypes:
  - Ingress
```

---

## DNS Issues

### DNS Resolution Failing

**Symptoms**: `nslookup` or `dig` fails for service names

**Diagnosis**:
```bash
# Check CoreDNS pods
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Check CoreDNS logs
kubectl logs -n kube-system -l k8s-app=kube-dns

# Test from pod
kubectl run test --rm -it --image=busybox -- nslookup kubernetes.default
```

**Common Causes & Solutions**:

| Cause | Solution |
|-------|----------|
| CoreDNS not running | Check CoreDNS deployment |
| ConfigMap issue | Verify CoreDNS ConfigMap |
| Network policy blocking | Allow DNS traffic (port 53) |
| Search domain issue | Check /etc/resolv.conf in pod |

---

## RBAC Issues

### Forbidden Errors

**Symptoms**: `Error from server (Forbidden)`

**Diagnosis**:
```bash
# Check what user can do
kubectl auth can-i --list
kubectl auth can-i create pods -n <namespace>

# Check as specific user
kubectl auth can-i create pods --as=<username>
```

**Common Fixes**:
```bash
# Find relevant role bindings
kubectl get rolebindings,clusterrolebindings -A | grep <subject>

# Create missing binding
kubectl create rolebinding <name> \
  --clusterrole=<role> \
  --user=<user> \
  -n <namespace>
```

---

## Debugging Commands Summary

```bash
# Cluster health
kubectl cluster-info
kubectl get componentstatuses  # deprecated but still useful
kubectl get nodes

# Pod debugging
kubectl describe pod <pod>
kubectl logs <pod> [-c container] [--previous]
kubectl exec -it <pod> -- /bin/sh
kubectl debug <pod> -it --image=busybox

# Network debugging
kubectl run debug --rm -it --image=nicolaka/netshoot
kubectl exec debug -- ping <target>
kubectl exec debug -- curl -v <service>:<port>
kubectl exec debug -- nslookup <service>
kubectl exec debug -- nc -zv <host> <port>

# Resource usage
kubectl top nodes
kubectl top pods [-A]

# Events (recent first)
kubectl get events --sort-by='.lastTimestamp'
kubectl get events -w  # Watch

# API server debugging
kubectl get --raw /api/v1/namespaces
kubectl get --raw /healthz
kubectl get --raw /metrics
```

---

## Emergency Procedures

### Force Delete Stuck Resources

```bash
# Force delete pod
kubectl delete pod <pod> --grace-period=0 --force

# Force delete namespace
kubectl get namespace <ns> -o json | \
  jq '.spec.finalizers = []' | \
  kubectl replace --raw "/api/v1/namespaces/<ns>/finalize" -f -
```

### Recover from Broken Cluster

```bash
# Check etcd health (if accessible)
etcdctl endpoint health

# Check API server logs
journalctl -u kube-apiserver

# Restart control plane components
systemctl restart kube-apiserver
systemctl restart kube-controller-manager
systemctl restart kube-scheduler
```

### Quick Health Check Script

```bash
#!/bin/bash
echo "=== Cluster Health Check ==="
echo "Nodes:"
kubectl get nodes
echo ""
echo "System Pods:"
kubectl get pods -n kube-system
echo ""
echo "Failed Pods:"
kubectl get pods -A --field-selector=status.phase=Failed
echo ""
echo "Not Running Pods:"
kubectl get pods -A | grep -v "Running\|Completed"
echo ""
echo "Recent Events:"
kubectl get events -A --sort-by='.lastTimestamp' | tail -20
```

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Quick Diagnosis Framework
- Pod Issues
- Service Issues
- Ingress Issues

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
