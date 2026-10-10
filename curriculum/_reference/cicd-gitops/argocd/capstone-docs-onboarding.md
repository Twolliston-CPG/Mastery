# Team Onboarding Guide

## Welcome to the GitOps Platform

This guide helps new teams get started with deploying applications using Argo CD.

## Prerequisites

Before you begin:
- [ ] Request access to your team's GitHub repository
- [ ] Get added to your team's OIDC group (contact Platform team)
- [ ] Install the Argo CD CLI: `brew install argocd`

## Step 1: Access the Argo CD UI

1. Navigate to: https://argocd.example.com
2. Click "Login via SSO"
3. Authenticate with your company credentials

## Step 2: Understand Your Project

Your team has a dedicated Argo CD Project with specific permissions:

| Team | Project Name | Allowed Namespaces |
|------|--------------|-------------------|
| Frontend | team-frontend | frontend-* |
| Backend | team-backend | backend-* |
| Data | team-data | data-* |

## Step 3: Create Your First Application

### Option A: Use the UI

1. Click "New App"
2. Fill in:
   - Application Name: `<team>-<app-name>`
   - Project: `team-<your-team>`
   - Repository: Your team's repo
   - Path: Path to your manifests
   - Cluster: `https://kubernetes.default.svc`
   - Namespace: `<your-team>-dev`

### Option B: Create Application YAML

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: <team>-<app-name>
  namespace: argocd
spec:
  project: team-<your-team>
  source:
    repoURL: https://github.com/org/<your-repo>.git
    targetRevision: HEAD
    path: kubernetes/overlays/dev
  destination:
    server: https://kubernetes.default.svc
    namespace: <your-team>-dev
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

## Step 4: Structure Your Repository

Recommended structure:

**`your-app/`**

- `base/`
  - `kustomization.yaml`
  - `deployment.yaml`
  - `service.yaml`
- `overlays/`
  - `dev/`
    - `kustomization.yaml`
  - `staging/`
    - `kustomization.yaml`
  - `prod/`
    - `kustomization.yaml`


## Step 5: Deploy to Different Environments

### Development
- Automatic sync enabled
- Push to main branch triggers deployment
- Namespace: `<team>-dev`

### Staging
- Automatic sync enabled
- Push to main branch triggers deployment
- Namespace: `<team>-staging`

### Production
- Manual sync required (or PR-based)
- Sync windows may apply (check with Platform team)
- Namespace: `<team>-prod`

## Common Operations

### View Application Status
```bash
argocd app get <app-name>
```

### Sync Application
```bash
argocd app sync <app-name>
```

### View Logs
```bash
argocd app logs <app-name>
```

### Rollback
```bash
argocd app history <app-name>
argocd app rollback <app-name> <revision>
```

## Getting Help

- **Slack**: #platform-support
- **Documentation**: https://wiki.example.com/gitops
- **On-call**: Check PagerDuty for platform on-call

## FAQ

**Q: My sync is stuck. What do I do?**
A: Check the sync status in the UI. Look for error messages. If stuck, try a hard refresh: `argocd app get <app> --hard-refresh`

**Q: I need a new namespace. How do I request it?**
A: Add the namespace to your Kustomize overlay with `CreateNamespace=true` sync option.

**Q: How do I view my application's pods?**
A: Click on your application in the UI, then click on the Deployment resource to see pods.

**Q: Can I deploy to production on Friday?**
A: Check with your team lead. Some teams have change freezes before weekends.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Welcome to the GitOps Platform
- Access the Argo CD UI
- Understand Your Project
- Create Your First Application

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
