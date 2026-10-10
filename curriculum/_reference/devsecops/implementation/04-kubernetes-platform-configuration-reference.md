# Domain 4: Kubernetes Platform -- Configuration Reference

> ArgoCD, Image Updater, External Secrets, and Kustomize configuration patterns.

---

## Table of Contents

- [ArgoCD Configuration](#argocd-configuration)
- [ArgoCD Image Updater Configuration](#argocd-image-updater-configuration)
- [External Secrets Operator Configuration](#external-secrets-operator-configuration)
- [Kustomize Patterns](#kustomize-patterns)
- [Istio Configuration Patterns](#istio-configuration-patterns)
- [Pod Security Configuration](#pod-security-configuration)

---

## ArgoCD Configuration

### argocd-cm (Core Config)

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  # URL for ArgoCD server (used in notifications and status badges)
  url: https://argocd.{{DOMAIN}}

  # Enable status badge for README embeds
  statusbadge.enabled: "true"

  # Use annotation-based resource tracking (safer than label-based)
  application.resourceTrackingMethod: annotation

  # Ignore Cilium identity objects (high churn, not user-managed)
  resource.exclusions: |
    - apiGroups:
        - cilium.io
      kinds:
        - CiliumIdentity
      clusters:
        - "*"

  # Allow Kustomize to render Helm charts
  kustomize.buildOptions: --enable-helm

  # Ignore aggregated ClusterRole differences
  resource.compareoptions: |
    ignoreAggregatedRoles: true

  # Custom health check for nested ArgoCD Applications (App-of-Apps)
  resource.customizations.health.argoproj.io_Application: |
    hs = {}
    hs.status = "Progressing"
    hs.message = ""
    if obj.status ~= nil then
      if obj.status.health ~= nil then
        hs.status = obj.status.health.status
        if obj.status.health.message ~= nil then
          hs.message = obj.status.health.message
        end
      end
    end
    return hs
```

### argocd-rbac-cm (RBAC Policy)

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  # Default role for unauthenticated/unknown users
  policy.default: role:readonly

  policy.csv: |
    # Admin group - full access
    g, admins, role:admin

    # Developer role - can view and sync, but not delete or modify settings
    p, role:developer, applications, get, */*, allow
    p, role:developer, applications, sync, */*, allow
    p, role:developer, logs, get, */*, allow
    g, developers, role:developer
```

### AppProject Definitions

```yaml
# Bootstrap project: unrestricted, for initial infrastructure
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: bootstrap
  namespace: argocd
spec:
  description: Bootstrap project for initial infrastructure tooling
  sourceRepos:
    - 'git@github.com:{{ORG_NAME}}/{{INFRASTRUCTURE_REPO}}.git'
  destinations:
    - namespace: '*'
      server: https://kubernetes.default.svc
  clusterResourceWhitelist:
    - group: '*'
      kind: '*'

---
# Platform project: infrastructure tools
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: platform
  namespace: argocd
spec:
  description: Platform infrastructure tools
  sourceRepos:
    - 'git@github.com:{{ORG_NAME}}/{{INFRASTRUCTURE_REPO}}.git'
    - 'https://charts.jetstack.io'
    - 'https://charts.external-secrets.io'
    - 'https://istio-release.storage.googleapis.com/charts'
  destinations:
    - namespace: '*'
      server: https://kubernetes.default.svc
  clusterResourceWhitelist:
    - group: '*'
      kind: '*'

---
# Applications project: restricted to app namespaces
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: applications
  namespace: argocd
spec:
  description: Application services
  sourceRepos:
    - 'git@github.com:{{ORG_NAME}}/{{INFRASTRUCTURE_REPO}}.git'
  destinations:
    - namespace: {{APP_NAMESPACE}}
      server: https://kubernetes.default.svc
    - namespace: {{APP_NAMESPACE}}-system
      server: https://kubernetes.default.svc
  clusterResourceWhitelist:
    - group: ''
      kind: Namespace
  namespaceResourceWhitelist:
    - group: '*'
      kind: '*'
```

### Application Template (Sync Policy)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: {{APP_NAME}}
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "{{WAVE_NUMBER}}"
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: {{PROJECT_NAME}}
  source:
    repoURL: git@github.com:{{ORG_NAME}}/{{INFRASTRUCTURE_REPO}}.git
    targetRevision: main
    path: k8s-manifests/{{MANIFEST_PATH}}
  destination:
    server: https://kubernetes.default.svc
    namespace: {{TARGET_NAMESPACE}}
  syncPolicy:
    automated:
      prune: true           # Delete resources removed from Git
      selfHeal: true         # Revert manual changes to match Git
    syncOptions:
      - CreateNamespace=true
      - ApplyOutOfSyncOnly=true
    retry:
      limit: 5
      backoff:
        duration: 5s         # Initial retry delay
        factor: 2            # Exponential multiplier
        maxDuration: 3m      # Maximum retry delay
```

### ApplicationSet (Matrix Generator)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: {{APP_NAMESPACE}}-services
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "3"
spec:
  generators:
    - matrix:
        generators:
          - list:
              elements:
                - env: staging
                - env: production
          - list:
              elements:
                - name: {{SERVICE_NAME}}
                  runtime: go
  template:
    metadata:
      name: '{{name}}-{{env}}'
      labels:
        environment: '{{env}}'
        runtime: '{{runtime}}'
    spec:
      project: applications
      source:
        repoURL: git@github.com:{{ORG_NAME}}/{{INFRASTRUCTURE_REPO}}.git
        targetRevision: main
        path: 'k8s-manifests/overlays/{{env}}/{{name}}'
      destination:
        server: https://kubernetes.default.svc
        namespace: {{APP_NAMESPACE}}
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
          - ApplyOutOfSyncOnly=true
```

---

## ArgoCD Image Updater Configuration

### ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-image-updater-config
  namespace: argocd
data:
  log.level: info

  # Git write-back configuration
  git.user: argocd-image-updater
  git.email: image-updater@{{DOMAIN}}
  git.commit-message-template: |
    build: update image {{ .AppName }} to {{ .NewImage }}

    Updates:
    {{- range .AppChanges }}
    - {{ .Image }}:{{ .OldTag }} -> {{ .NewTag }}
    {{- end }}

  # Registry configuration [GCP-SPECIFIC]
  registries.conf: |
    registries:
      - name: Google Artifact Registry
        prefix: {{REGISTRY_REGION}}-docker.pkg.dev
        api_url: https://{{REGISTRY_REGION}}-docker.pkg.dev
        default: true
        # Workload Identity provides authentication

  # Application polling settings
  applications.conf: |
    check-interval: 2m
    max-concurrency: 10
```

### Image Updater Annotations on Applications

To enable image updating for a specific ArgoCD Application, add these annotations:

```yaml
metadata:
  annotations:
    # Enable image updater for this application
    argocd-image-updater.argoproj.io/image-list: >-
      {{SERVICE_NAME}}={{REGISTRY_URL}}/{{SERVICE_NAME}}
    # Use semver constraint
    argocd-image-updater.argoproj.io/{{SERVICE_NAME}}.update-strategy: semver
    argocd-image-updater.argoproj.io/{{SERVICE_NAME}}.allow-tags: regexp:^v[0-9]+\.[0-9]+\.[0-9]+$
    # Write back to Git (Kustomize image override)
    argocd-image-updater.argoproj.io/write-back-method: git:secret:argocd/argocd-image-updater-git-creds
    argocd-image-updater.argoproj.io/write-back-target: kustomization
```

### Git Credentials (ExternalSecret)

```yaml
# [GCP-SPECIFIC] Fetches GitHub token from Secret Manager
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: argocd-image-updater-git-creds
  namespace: argocd
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: gcp-secret-manager    # [GCP-SPECIFIC]
    kind: ClusterSecretStore
  target:
    name: argocd-image-updater-git-creds
    template:
      type: Opaque
      data:
        git.username: "x-access-token"
        git.password: "{{ .github_app_token }}"
  data:
    - secretKey: github_app_token
      remoteRef:
        key: github-app-image-updater-token
```

---

## External Secrets Operator Configuration

### ClusterSecretStore

```yaml
# [GCP-SPECIFIC] GCP Secret Manager provider
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: gcp-secret-manager
spec:
  provider:
    gcpsm:
      projectID: {{GCP_PROJECT_ID}}
      auth:
        workloadIdentity:
          clusterLocation: {{GCP_REGION}}
          clusterName: {{CLUSTER_NAME}}
          serviceAccountRef:
            name: external-secrets
            namespace: external-secrets
```

### ExternalSecret Patterns

**Pattern 1: Standard application secret (1h refresh)**

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: {{SERVICE_NAME}}-secrets
  namespace: {{APP_NAMESPACE}}
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: gcp-secret-manager
    kind: ClusterSecretStore
  target:
    name: {{SERVICE_NAME}}-secrets
    creationPolicy: Owner
  data:
    - secretKey: DATABASE_URL
      remoteRef:
        key: {{APP_NAMESPACE}}-database-url
    - secretKey: JWT_SECRET
      remoteRef:
        key: {{APP_NAMESPACE}}-jwt-secret
```

**Pattern 2: High-rotation secret with Reloader (5m-15m refresh)**

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: {{SECRET_NAME}}
  namespace: {{NAMESPACE}}
  labels:
    platform.io/secret-rotation: enabled
    platform.io/rotation-frequency: high
spec:
  refreshInterval: 5m
  secretStoreRef:
    name: gcp-secret-manager
    kind: ClusterSecretStore
  target:
    name: {{SECRET_NAME}}
    creationPolicy: Owner
    template:
      metadata:
        annotations:
          # Triggers pod restart when secret changes
          reloader.stakater.com/match: "true"
      type: Opaque
  data:
    - secretKey: AUTH_SERVICE_TOKEN
      remoteRef:
        key: {{APP_NAMESPACE}}-auth-service-token
        version: latest    # Always fetch latest version
```

### Refresh Interval Guide

| Interval | Use Case | Example |
|---|---|---|
| `5m` | Service-to-service tokens, high-churn secrets | `service-auth-tokens` |
| `15m` | Database credentials | `postgres-credentials`, `redis-credentials` |
| `30m` | Application secrets | JWT, encryption keys |
| `1h` | Third-party API keys, Git credentials | Stripe, SendGrid, GitHub tokens |

---

## Kustomize Patterns

### Base Layer (Service Definition)

```yaml
# kustomization.yaml for a service base
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: {{APP_NAMESPACE}}

resources:
  - serviceaccount.yaml
  - deployment.yaml
  - service.yaml
  - hpa.yaml
  - pdb.yaml

labels:
  - pairs:
      app.kubernetes.io/name: {{SERVICE_NAME}}
      app.kubernetes.io/component: {{COMPONENT_TYPE}}
      app.kubernetes.io/part-of: {{APP_NAMESPACE}}
    includeSelectors: false

images:
  - name: {{REGISTRY_URL}}/{{SERVICE_NAME}}
    newTag: v1.0.0
```

### Overlay Layer (Per Environment)

```yaml
# overlays/staging/{{SERVICE_NAME}}/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../../apps/{{RUNTIME}}-services/{{SERVICE_NAME}}

images:
  - name: {{REGISTRY_URL}}/{{SERVICE_NAME}}
    newName: {{STAGING_REGISTRY_URL}}/{{SERVICE_NAME}}
    newTag: staging

patches:
  - patch: |-
      # Remove production node affinity for staging
      - op: remove
        path: /spec/template/spec/affinity/nodeAffinity
      # Add image pull secret for private registry
      - op: add
        path: /spec/template/spec/imagePullSecrets
        value:
          - name: artifact-registry-secret
    target:
      kind: Deployment
      name: {{SERVICE_NAME}}

# Override replica count for staging (lower than production)
replicas:
  - name: {{SERVICE_NAME}}
    count: 1
```

### Shared Base (Common ConfigMap/Secrets)

```yaml
# apps/go-services/base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: {{APP_NAMESPACE}}

resources:
  - namespace.yaml
  - configmap.yaml
  - secret.yaml
  - external-secret.yaml

labels:
  - pairs:
      app.kubernetes.io/part-of: {{APP_NAMESPACE}}
      app.kubernetes.io/managed-by: kustomize
    includeSelectors: false
```

### Top-Level Overlay (Environment Aggregator)

```yaml
# overlays/staging/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: {{APP_NAMESPACE}}

resources:
  # Include each service overlay
  - api-gateway
  - auth-service
  - booking-service
  # ... all services

commonLabels:
  environment: staging
```

---

## Istio Configuration Patterns

### Namespace Enrollment (Ambient Mode)

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: {{APP_NAMESPACE}}
  labels:
    istio.io/dataplane-mode: ambient
```

### Mesh-Wide mTLS

```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system
spec:
  mtls:
    mode: STRICT
```

### Per-Service Authorization Policy

```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: {{SERVICE_NAME}}-policy
  namespace: {{APP_NAMESPACE}}
spec:
  selector:
    matchLabels:
      app: {{SERVICE_NAME}}
  action: ALLOW
  rules:
    - from:
        - source:
            principals:
              - "cluster.local/ns/{{APP_NAMESPACE}}/sa/{{ALLOWED_CALLER}}"
      to:
        - operation:
            ports: ["{{SERVICE_PORT}}"]
```

### Circuit Breaker (DestinationRule)

```yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: {{SERVICE_NAME}}-circuit-breaker
spec:
  host: "*.{{APP_NAMESPACE}}.svc.cluster.local"
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        h2UpgradePolicy: UPGRADE
        http1MaxPendingRequests: 100
        http2MaxRequests: 1000
    outlierDetection:
      consecutive5xxErrors: 5
      interval: 30s
      baseEjectionTime: 30s
      maxEjectionPercent: 50
```

---

## Pod Security Configuration

### Namespace Labels

```yaml
metadata:
  labels:
    # Application namespaces: most restrictive
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

### Container Security Context (Required)

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  runAsGroup: 1000
  fsGroup: 1000

containers:
  - securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
          - ALL
```

### Volume Mounts for Read-Only Rootfs

When using read-only root filesystem, mount emptyDir volumes for writable paths:

```yaml
volumeMounts:
  - name: tmp
    mountPath: /tmp
volumes:
  - name: tmp
    emptyDir: {}
```

Node.js services typically need `/tmp` writable; Go services compiled as static binaries may not need any writable volumes.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- ArgoCD Configuration
- ArgoCD Image Updater Configuration
- External Secrets Operator Configuration
- Kustomize Patterns

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"We scan for vulnerabilities in the pipeline."* |
| ✓ | *"SAST reads source without running it, SCA resolves the dependency tree against an advisory database, and image scanning compares installed package versions to that same database. All three report what was known at build time — which is why the registry is re-scanned: the image does not change, the database does."* |

**Trace it:** A CVE published today against your base image → a blocked deploy. Name every component between the advisory and the refused `apply`.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** the [SLSA threat model](https://slsa.dev/spec/v1.2/threats) — it names every point at which a build can be subverted, and most teams defend three of them.
Full list per domain: [`SOURCES.md`](../../SOURCES.md#devsecops)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../../MASTERY.md)

<!-- /feynman-check -->
