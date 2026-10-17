# Exercise 1: ArgoCD Setup

## Objective

Deploy and configure a production-ready ArgoCD installation with high availability, SSO integration, and proper RBAC.

## Prerequisites

- Running Kubernetes cluster
- Helm 3 installed
- Domain for ArgoCD UI (optional but recommended)

## Tasks

### Task 1: Install ArgoCD with Helm

```bash
# Add Argo Helm repo
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Create namespace
kubectl create namespace argocd

# Install ArgoCD
helm install argocd argo/argo-cd \
  --namespace argocd \
  --values argocd-values.yaml
```

**argocd-values.yaml:**
```yaml
# High Availability Configuration
global:
  domain: argocd.example.com

# Server configuration
server:
  replicas: 2

  # Enable insecure mode if terminating TLS at ingress
  extraArgs:
  - --insecure

  ingress:
    enabled: true
    ingressClassName: nginx
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-prod
      nginx.ingress.kubernetes.io/ssl-passthrough: "false"
      nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
    hosts:
    - argocd.example.com
    tls:
    - secretName: argocd-server-tls
      hosts:
      - argocd.example.com

  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Mi

  # Pod disruption budget
  pdb:
    enabled: true
    minAvailable: 1

# Controller configuration
controller:
  replicas: 1

  resources:
    requests:
      cpu: 250m
      memory: 512Mi
    limits:
      cpu: 1000m
      memory: 1Gi

  # Metrics
  metrics:
    enabled: true
    serviceMonitor:
      enabled: true

# Repo Server configuration
repoServer:
  replicas: 2

  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Mi

  pdb:
    enabled: true
    minAvailable: 1

# Redis HA
redis-ha:
  enabled: true
  replicas: 3

redis:
  enabled: false

# Application Set Controller
applicationSet:
  enabled: true
  replicas: 2

# Notifications Controller
notifications:
  enabled: true

# ConfigMap settings
configs:
  cm:
    # URL for ArgoCD
    url: https://argocd.example.com

    # Enable status badge
    statusbadge.enabled: "true"

    # Application resync period
    timeout.reconciliation: 180s

    # Resource tracking method
    application.resourceTrackingMethod: annotation

  params:
    # Server-side diff
    server.diff.format: "structured"

    # Disable TLS on gRPC
    server.disable.auth: "false"

  # RBAC configuration
  rbac:
    policy.default: role:readonly
    policy.csv: |
      # Admin role
      p, role:admin, applications, *, */*, allow
      p, role:admin, clusters, *, *, allow
      p, role:admin, repositories, *, *, allow
      p, role:admin, projects, *, *, allow
      p, role:admin, accounts, *, *, allow
      p, role:admin, gpgkeys, *, *, allow
      p, role:admin, logs, get, */*, allow
      p, role:admin, exec, *, */*, allow

      # Developer role - can sync and view
      p, role:developer, applications, get, */*, allow
      p, role:developer, applications, sync, */*, allow
      p, role:developer, applications, action/*, */*, allow
      p, role:developer, logs, get, */*, allow
      p, role:developer, repositories, get, *, allow
      p, role:developer, projects, get, *, allow

      # Viewer role
      p, role:viewer, applications, get, */*, allow
      p, role:viewer, repositories, get, *, allow
      p, role:viewer, projects, get, *, allow

      # Group mappings
      g, admins, role:admin
      g, developers, role:developer
      g, viewers, role:viewer
```

### Task 2: Configure ArgoCD CLI

```bash
# Install ArgoCD CLI
# macOS
brew install argocd

# Linux
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64

# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Login to ArgoCD
argocd login argocd.example.com

# Change admin password
argocd account update-password
```

### Task 3: Create ArgoCD Project

```yaml
# project.yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: production
  namespace: argocd
  finalizers:
  - resources-finalizer.argocd.argoproj.io
spec:
  description: Production applications

  # Source repositories
  sourceRepos:
  - 'https://github.com/myorg/*'
  - 'https://charts.helm.sh/*'

  # Allowed destinations
  destinations:
  - namespace: production
    server: https://kubernetes.default.svc
  - namespace: production-*
    server: https://kubernetes.default.svc

  # Allowed cluster resources
  clusterResourceWhitelist:
  - group: ''
    kind: Namespace
  - group: 'rbac.authorization.k8s.io'
    kind: ClusterRole
  - group: 'rbac.authorization.k8s.io'
    kind: ClusterRoleBinding

  # Namespace resources (allow all by default)
  namespaceResourceWhitelist:
  - group: '*'
    kind: '*'

  # Denied resources
  namespaceResourceBlacklist:
  - group: ''
    kind: ResourceQuota
  - group: ''
    kind: LimitRange

  # Roles within the project
  roles:
  - name: developer
    description: Developer access to production apps
    policies:
    - p, proj:production:developer, applications, get, production/*, allow
    - p, proj:production:developer, applications, sync, production/*, allow
    groups:
    - dev-team

  - name: admin
    description: Admin access to production apps
    policies:
    - p, proj:production:admin, applications, *, production/*, allow
    groups:
    - platform-team

  # Sync windows
  syncWindows:
  - kind: allow
    schedule: '0 6-22 * * 1-5'
    duration: 16h
    applications:
    - '*'
    manualSync: true

  - kind: deny
    schedule: '0 0 * * 0'
    duration: 24h
    applications:
    - '*'
```

### Task 4: Add Git Repository

```yaml
# repository-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: private-repo
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: git
  url: https://github.com/myorg/k8s-manifests.git
  # For HTTPS with token
  username: git
  password: <github-token>

---
# Or with SSH key
apiVersion: v1
kind: Secret
metadata:
  name: private-repo-ssh
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: git
  url: git@github.com:myorg/k8s-manifests.git
  sshPrivateKey: |
    -----BEGIN OPENSSH PRIVATE KEY-----
    ...
    -----END OPENSSH PRIVATE KEY-----
```

### Task 5: Create First Application

```yaml
# application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: demo-app
  namespace: argocd
  finalizers:
  - resources-finalizer.argocd.argoproj.io
spec:
  project: production

  source:
    repoURL: https://github.com/myorg/k8s-manifests.git
    targetRevision: main
    path: apps/demo-app

    # For Kustomize
    kustomize:
      namePrefix: prod-
      commonLabels:
        environment: production

  destination:
    server: https://kubernetes.default.svc
    namespace: production

  # Sync policy
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false

    syncOptions:
    - CreateNamespace=true
    - PrunePropagationPolicy=foreground
    - PruneLast=true
    - ApplyOutOfSyncOnly=true

    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m

  # Ignore differences
  ignoreDifferences:
  - group: apps
    kind: Deployment
    jsonPointers:
    - /spec/replicas

  # Health checks
  info:
  - name: url
    value: https://demo.example.com
```

### Task 6: Configure Notifications

```yaml
# notifications-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-notifications-cm
  namespace: argocd
data:
  # Slack configuration
  service.slack: |
    token: $slack-token

  # Templates
  template.app-deployed: |
    message: |
      Application {{.app.metadata.name}} is now {{.app.status.sync.status}}.
      Revision: {{.app.status.sync.revision}}
    slack:
      attachments: |
        [{
          "color": "#18be52",
          "fields": [
            {"title": "Application", "value": "{{.app.metadata.name}}", "short": true},
            {"title": "Environment", "value": "{{.app.spec.destination.namespace}}", "short": true},
            {"title": "Status", "value": "{{.app.status.sync.status}}", "short": true}
          ]
        }]

  template.app-health-degraded: |
    message: |
      Application {{.app.metadata.name}} health is {{.app.status.health.status}}.
    slack:
      attachments: |
        [{
          "color": "#f4c030",
          "fields": [
            {"title": "Application", "value": "{{.app.metadata.name}}", "short": true},
            {"title": "Health", "value": "{{.app.status.health.status}}", "short": true}
          ]
        }]

  # Triggers
  trigger.on-deployed: |
    - description: Application is synced and healthy
      send:
      - app-deployed
      when: app.status.operationState.phase in ['Succeeded'] and app.status.health.status == 'Healthy'

  trigger.on-health-degraded: |
    - description: Application health degraded
      send:
      - app-health-degraded
      when: app.status.health.status == 'Degraded'

  # Default subscriptions
  subscriptions: |
    - recipients:
      - slack:deployments
      triggers:
      - on-deployed
      - on-health-degraded
```

## Validation

```bash
# Check ArgoCD components
kubectl get pods -n argocd

# Verify server is accessible
curl -k https://argocd.example.com/api/v1/applications

# Check application status
argocd app list
argocd app get demo-app

# Verify sync status
argocd app sync demo-app --dry-run

# Check project
argocd proj get production
```

## Success Criteria

- [ ] ArgoCD installed with HA configuration
- [ ] Ingress accessible with TLS
- [ ] CLI configured and authenticated
- [ ] Project created with proper RBAC
- [ ] Repository connected successfully
- [ ] Application deployed and syncing
- [ ] Notifications configured

## Troubleshooting

```bash
# Check ArgoCD server logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server

# Check application controller logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller

# Check repo server logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server

# Verify repository connectivity
argocd repo list
argocd repo get https://github.com/myorg/k8s-manifests.git

# Debug application sync
argocd app get demo-app --show-operation
argocd app diff demo-app
```

## Cleanup

```bash
# Delete application
argocd app delete demo-app

# Uninstall ArgoCD
helm uninstall argocd -n argocd
kubectl delete namespace argocd
```

## Next Exercise

Continue to [Exercise 2: App of Apps Pattern](01-gitops-argocd-exercises-02-app-of-apps.md) to implement hierarchical application management.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Install ArgoCD with Helm
- Configure ArgoCD CLI
- Create ArgoCD Project
- Add Git Repository

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
