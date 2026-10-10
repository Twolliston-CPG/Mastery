# kubectl Cheat Sheet for Enterprise Kubernetes

## Quick Reference

### Configuration & Context

```bash
# View current context
kubectl config current-context

# List all contexts
kubectl config get-contexts

# Switch context
kubectl config use-context <context-name>

# Set default namespace
kubectl config set-context --current --namespace=<namespace>

# View config
kubectl config view
kubectl config view --minify  # Current context only
```

### Resource Information

```bash
# Get resources
kubectl get pods                          # List pods in current namespace
kubectl get pods -A                       # All namespaces
kubectl get pods -o wide                  # More details
kubectl get pods -o yaml                  # YAML output
kubectl get pods -o json                  # JSON output
kubectl get pods --show-labels            # Show labels
kubectl get pods -l app=nginx             # Filter by label
kubectl get pods --field-selector=status.phase=Running

# Common resources
kubectl get nodes
kubectl get deployments
kubectl get services
kubectl get ingress
kubectl get configmaps
kubectl get secrets
kubectl get pv,pvc
kubectl get events --sort-by='.lastTimestamp'

# All resources in namespace
kubectl get all -n <namespace>

# API resources
kubectl api-resources                     # List all resource types
kubectl api-resources --namespaced=true   # Only namespaced resources
kubectl explain pods                      # Describe a resource type
kubectl explain pods.spec.containers      # Nested fields
```

### Creating Resources

```bash
# Imperative creation
kubectl create namespace <name>
kubectl create deployment nginx --image=nginx
kubectl create service clusterip nginx --tcp=80:80
kubectl create configmap <name> --from-literal=key=value
kubectl create secret generic <name> --from-literal=password=secret

# From YAML
kubectl apply -f manifest.yaml
kubectl apply -f directory/
kubectl apply -f https://example.com/manifest.yaml

# Dry run (client-side)
kubectl apply -f manifest.yaml --dry-run=client

# Dry run (server-side - validates against API)
kubectl apply -f manifest.yaml --dry-run=server

# Generate YAML without creating
kubectl create deployment nginx --image=nginx --dry-run=client -o yaml > deployment.yaml
```

### Editing Resources

```bash
# Edit in place
kubectl edit deployment nginx

# Patch resources
kubectl patch deployment nginx -p '{"spec":{"replicas":3}}'
kubectl patch deployment nginx --type=json -p='[{"op":"replace","path":"/spec/replicas","value":5}]'

# Replace
kubectl replace -f manifest.yaml

# Scale
kubectl scale deployment nginx --replicas=5

# Set image
kubectl set image deployment/nginx nginx=nginx:1.25

# Set environment variables
kubectl set env deployment/nginx LOG_LEVEL=debug
```

### Deleting Resources

```bash
# Delete by name
kubectl delete pod nginx
kubectl delete deployment nginx

# Delete from file
kubectl delete -f manifest.yaml

# Delete all pods in namespace
kubectl delete pods --all -n <namespace>

# Force delete (stuck pods)
kubectl delete pod nginx --grace-period=0 --force

# Delete namespace (and all resources in it)
kubectl delete namespace <name>
```

### Debugging & Troubleshooting

```bash
# Describe (detailed info + events)
kubectl describe pod nginx
kubectl describe node <node-name>

# Logs
kubectl logs nginx                        # Current logs
kubectl logs nginx --previous             # Previous container
kubectl logs nginx -f                     # Follow/stream
kubectl logs nginx --since=1h             # Last hour
kubectl logs nginx --tail=100             # Last 100 lines
kubectl logs -l app=nginx                 # By label selector
kubectl logs -l app=nginx --all-containers

# Exec into container
kubectl exec -it nginx -- /bin/bash
kubectl exec -it nginx -c container-name -- /bin/sh

# Port forwarding
kubectl port-forward pod/nginx 8080:80
kubectl port-forward svc/nginx 8080:80
kubectl port-forward deployment/nginx 8080:80

# Copy files
kubectl cp nginx:/path/to/file ./local-file
kubectl cp ./local-file nginx:/path/to/file

# Debug with ephemeral container
kubectl debug nginx -it --image=busybox

# Resource usage
kubectl top nodes
kubectl top pods
kubectl top pods --containers
```

### RBAC

```bash
# Check permissions
kubectl auth can-i create pods
kubectl auth can-i create pods --as=developer
kubectl auth can-i create pods -n production --as=developer
kubectl auth can-i --list                 # All permissions
kubectl auth can-i --list --as=developer

# View RBAC resources
kubectl get roles,rolebindings -n <namespace>
kubectl get clusterroles,clusterrolebindings
kubectl describe clusterrole admin
```

### Labels & Annotations

```bash
# Add/update labels
kubectl label pods nginx env=production
kubectl label pods nginx env=staging --overwrite

# Remove labels
kubectl label pods nginx env-

# Add annotations
kubectl annotate pods nginx description="My nginx pod"

# Remove annotations
kubectl annotate pods nginx description-
```

### Rollouts

```bash
# Status
kubectl rollout status deployment/nginx

# History
kubectl rollout history deployment/nginx
kubectl rollout history deployment/nginx --revision=2

# Undo
kubectl rollout undo deployment/nginx
kubectl rollout undo deployment/nginx --to-revision=2

# Pause/Resume
kubectl rollout pause deployment/nginx
kubectl rollout resume deployment/nginx

# Restart
kubectl rollout restart deployment/nginx
```

### Taints & Tolerations

```bash
# Add taint
kubectl taint nodes node1 key=value:NoSchedule

# Remove taint
kubectl taint nodes node1 key=value:NoSchedule-

# View taints
kubectl describe node node1 | grep -A5 Taints
```

### Node Management

```bash
# Cordon (mark unschedulable)
kubectl cordon node1

# Uncordon
kubectl uncordon node1

# Drain (evict pods)
kubectl drain node1 --ignore-daemonsets --delete-emptydir-data
```

### JSONPath & Output Formatting

```bash
# Get specific fields
kubectl get pods -o jsonpath='{.items[*].metadata.name}'
kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'
kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}'

# Custom columns
kubectl get pods -o custom-columns=NAME:.metadata.name,STATUS:.status.phase

# Sort
kubectl get pods --sort-by='.status.containerStatuses[0].restartCount'
kubectl get pods --sort-by='.metadata.creationTimestamp'
```

### Useful Aliases

```bash
# Add to ~/.bashrc or ~/.zshrc
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgpa='kubectl get pods -A'
alias kgs='kubectl get svc'
alias kgd='kubectl get deployments'
alias kgn='kubectl get nodes'
alias kd='kubectl describe'
alias kdp='kubectl describe pod'
alias kl='kubectl logs'
alias klf='kubectl logs -f'
alias ke='kubectl exec -it'
alias ka='kubectl apply -f'
alias kd='kubectl delete -f'
alias kctx='kubectl config use-context'
alias kns='kubectl config set-context --current --namespace'

# Enable bash completion
source <(kubectl completion bash)
complete -F __start_kubectl k
```

### Emergency Commands

```bash
# Force delete stuck namespace
kubectl get namespace <namespace> -o json | jq '.spec.finalizers = []' | kubectl replace --raw "/api/v1/namespaces/<namespace>/finalize" -f -

# Get all failed pods
kubectl get pods -A --field-selector=status.phase=Failed

# Get pods not ready
kubectl get pods -A | grep -v "Running\|Completed"

# Find pods using most resources
kubectl top pods -A --sort-by=cpu
kubectl top pods -A --sort-by=memory

# Events sorted by time
kubectl get events -A --sort-by='.lastTimestamp'

# Get all images in cluster
kubectl get pods -A -o jsonpath='{range .items[*]}{.spec.containers[*].image}{"\n"}{end}' | sort -u
```

### Security-Focused Commands

```bash
# Find privileged pods
kubectl get pods -A -o json | jq '.items[] | select(.spec.containers[].securityContext.privileged==true) | .metadata.name'

# Find pods running as root
kubectl get pods -A -o json | jq '.items[] | select(.spec.securityContext.runAsNonRoot!=true) | .metadata.name'

# Check PSS labels on namespaces
kubectl get namespaces -o custom-columns=NAME:.metadata.name,PSS:.metadata.labels."pod-security\.kubernetes\.io/enforce"

# View secrets (base64 decoded)
kubectl get secret <secret-name> -o jsonpath='{.data.password}' | base64 -d
```

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Quick Reference
- Configuration & Context
- Resource Information
- Creating Resources

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
