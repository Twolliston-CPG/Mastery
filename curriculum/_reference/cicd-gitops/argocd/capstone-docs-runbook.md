# Argo CD Operations Runbook

## Common Issues and Resolutions

---

## Issue: Application Stuck OutOfSync

### Symptoms
- Application shows "OutOfSync" status
- Sync button doesn't change status
- No error messages visible

### Diagnosis
```bash
# Check detailed diff
argocd app diff <app-name>

# Check sync status
argocd app get <app-name> -o yaml | grep -A 20 status:

# Check for ignoreDifferences issues
argocd app get <app-name> -o yaml | grep -A 10 ignoreDifferences
```

### Resolution
1. **If diff shows expected changes**: Sync the application
   ```bash
   argocd app sync <app-name>
   ```

2. **If diff shows unexpected fields** (e.g., managed by HPA):
   Add to Application spec:
   ```yaml
   ignoreDifferences:
     - group: apps
       kind: Deployment
       jsonPointers:
         - /spec/replicas
   ```

3. **If no diff but still OutOfSync**: Hard refresh
   ```bash
   argocd app get <app-name> --hard-refresh
   ```

---

## Issue: Application Health Degraded

### Symptoms
- Application shows "Degraded" health
- Red health indicator in UI
- Pods may be in CrashLoopBackOff or Error state

### Diagnosis
```bash
# Check pod status
kubectl get pods -n <namespace>

# Check pod logs
kubectl logs <pod-name> -n <namespace>

# Check pod events
kubectl describe pod <pod-name> -n <namespace>

# Check Argo CD view
argocd app get <app-name> --show-operation
```

### Resolution
1. **If pods are CrashLoopBackOff**:
   - Check application logs for errors
   - Verify ConfigMaps/Secrets exist
   - Check resource limits

2. **If pods can't schedule**:
   - Check node resources: `kubectl describe nodes`
   - Check PVC binding: `kubectl get pvc -n <namespace>`

3. **If image pull errors**:
   - Verify image exists
   - Check image pull secrets

---

## Issue: Sync Failed

### Symptoms
- Sync operation shows "Failed"
- Error message in operation details

### Diagnosis
```bash
# View sync result
argocd app get <app-name> --show-operation

# Check operation history
argocd app history <app-name>
```

### Common Errors and Fixes

| Error | Cause | Fix |
|-------|-------|-----|
| `resource already exists` | Resource managed by another app | Add `FailOnSharedResource=true` or check ownership |
| `validation error` | Invalid manifest | Fix manifest syntax |
| `quota exceeded` | Resource quota hit | Request quota increase or reduce resources |
| `forbidden` | RBAC issue | Check Project permissions |

### Resolution
1. Fix the underlying issue in Git
2. Push the fix
3. Sync again: `argocd app sync <app-name>`

---

## Issue: Repository Connection Failed

### Symptoms
- "Unable to resolve" error
- "Authentication failed" error
- New commits not detected

### Diagnosis
```bash
# Check repo status
argocd repo list

# Test repo connection
argocd repo get <repo-url>
```

### Resolution
1. **Authentication failed**:
   ```bash
   # Update credentials
   argocd repo add <repo-url> --username <user> --password <token>
   ```

2. **SSH key issues**:
   - Verify key is correct
   - Check known_hosts configuration

3. **Network issues**:
   - Check if repo is accessible from cluster
   - Verify no firewall blocking

---

## Issue: High Memory Usage on Repo Server

### Symptoms
- Repo server pods OOMKilled
- Slow manifest generation
- Timeouts during sync

### Diagnosis
```bash
# Check pod resources
kubectl top pods -n argocd

# Check repo server logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server
```

### Resolution
1. **Increase resource limits**:
   ```yaml
   resources:
     limits:
       memory: 2Gi
     requests:
       memory: 1Gi
   ```

2. **Limit parallelism**:
   ```yaml
   # In argocd-cmd-params-cm
   reposerver.parallelism.limit: "5"
   ```

3. **Use manifest generation paths** for monorepos:
   ```yaml
   metadata:
     annotations:
       argocd.argoproj.io/manifest-generate-paths: /apps/my-app
   ```

---

## Issue: Controller Not Reconciling

### Symptoms
- Changes not detected
- Applications stuck in "Unknown" state
- Controller logs show errors

### Diagnosis
```bash
# Check controller logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller

# Check controller status
kubectl get statefulset argocd-application-controller -n argocd
```

### Resolution
1. **Restart controller**:
   ```bash
   kubectl rollout restart statefulset argocd-application-controller -n argocd
   ```

2. **Check cluster connectivity**:
   ```bash
   argocd cluster list
   ```

3. **Check Redis connectivity**:
   ```bash
   kubectl logs -n argocd -l app.kubernetes.io/name=argocd-redis
   ```

---

## Emergency Procedures

### Disable Auto-Sync for All Apps
```bash
# List all apps with auto-sync
argocd app list -o name | xargs -I {} argocd app set {} --sync-policy none
```

### Force Delete Stuck Application
```bash
# Remove finalizers
kubectl patch application <app-name> -n argocd -p '{"metadata":{"finalizers":null}}' --type=merge

# Delete application
argocd app delete <app-name> --cascade=false
```

### Restore from Backup
```bash
# See backup/restore scripts in phase-9-ha-dr
./restore.sh backups/argocd-backup-YYYYMMDD.yaml
```

---

## Escalation Path

1. **L1**: Team on-call - basic troubleshooting
2. **L2**: Platform team - infrastructure issues
3. **L3**: Argo CD community/support - product issues

## Useful Links

- [Argo CD Docs](https://argo-cd.readthedocs.io/)
- [Argo CD FAQ](https://argo-cd.readthedocs.io/en/stable/faq/)
- [GitHub Issues](https://github.com/argoproj/argo-cd/issues)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Common Issues and Resolutions
- Issue: Application Stuck OutOfSync
- Issue: Application Health Degraded
- Issue: Sync Failed

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"The pipeline deploys the application."* |
| ✓ | *"CI writes a new image tag into a config repository and stops. A controller running *inside* the cluster polls that repo, diffs the rendered manifests against live state, and applies the difference — so nothing outside the cluster ever holds credentials to it."* |

**Trace it:** `git push` → the new version serving traffic, with nothing else typed. Name where the handoff between CI and CD happens, and what that handoff physically is.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** the four [OpenGitOps principles](https://opengitops.dev/#principles) — then say which one a `kubectl apply` inside CI violates.
Full list per domain: [`SOURCES.md`](../../SOURCES.md#cicd-gitops)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../../MASTERY.md)

<!-- /feynman-check -->
