# Phase 3: Application Sources

**Goal:** Master different ways to define Kubernetes manifests - plain YAML, Kustomize, Helm, and multiple sources.

**Duration:** 2-3 hours

---

## Overview

This phase covers:
- Plain manifest directories
- Kustomize overlays for environments
- Helm charts with values
- Multiple sources pattern

---

## Concepts

### Source Types

Argo CD supports multiple ways to define your Kubernetes resources:

| Application Sources |  |  |
|---|---|---|
| Plain YAML | Kustomize | Helm |
| Raw manifests | Base + overlays | Charts + values |
| No templating | Patches | Templating engine |
| Simple | Environment | Package management |
|  | specific |  |


### Plain Manifests

The simplest approach - raw YAML files in a directory:

```yaml
source:
  repoURL: https://github.com/your-org/your-repo.git
  targetRevision: HEAD
  path: manifests/
  directory:
    recurse: false        # Include subdirectories?
    exclude: '{*.md}'     # Exclude patterns
```

**When to use:**
- Simple applications
- Learning Kubernetes
- When you need full control

### Kustomize

Layer-based customization without templates:

**`kustomize-demo/`**

- `base/` — Common resources
  - `deployment.yaml`
  - `service.yaml`
  - `kustomization.yaml`
- `overlays/` — Environment-specific
  - `dev/`
    - `kustomization.yaml`
  - `staging/`
    - `kustomization.yaml`
  - `prod/`
    - `kustomization.yaml`


**Kustomization features:**
- `namePrefix/nameSuffix` - Add prefixes/suffixes to names
- `commonLabels` - Add labels to all resources
- `patches` - JSON patches for modifications
- `images` - Override image tags
- `configMapGenerator` - Generate ConfigMaps
- `secretGenerator` - Generate Secrets

**Application pointing to overlay:**

```yaml
source:
  repoURL: https://github.com/your-org/your-repo.git
  targetRevision: HEAD
  path: kustomize-demo/overlays/dev
  # Argo CD auto-detects Kustomize from kustomization.yaml
```

### Helm Charts

Package manager for Kubernetes:

```yaml
source:
  # From Helm repository
  repoURL: https://charts.bitnami.com/bitnami
  chart: nginx
  targetRevision: 15.0.0
  helm:
    releaseName: my-nginx
    values: |
      replicaCount: 2
      service:
        type: ClusterIP
    parameters:
      - name: image.tag
        value: "1.25"
```

**Helm options:**

| Option | Purpose |
|--------|---------|
| `releaseName` | Override Helm release name |
| `values` | Inline values (values.yaml format) |
| `valueFiles` | List of values files to use |
| `parameters` | Individual value overrides |
| `skipCrds` | Skip CRD installation |
| `passCredentials` | Pass credentials to dependencies |

**Value precedence (highest to lowest):**
1. `parameters` - Individual overrides
2. `values` - Inline values block
3. `valueFiles` - External files (later files override earlier)
4. Chart defaults

### Multiple Sources

Combine sources - common for Helm charts with Git-stored values:

```yaml
sources:          # Note: 'sources' (plural)
  # Source 1: Helm chart
  - repoURL: https://charts.bitnami.com/bitnami
    chart: nginx
    targetRevision: 15.0.0
    helm:
      valueFiles:
        - $values/helm-values/common.yaml
        - $values/helm-values/prod.yaml

  # Source 2: Values repository
  - repoURL: https://github.com/your-org/config.git
    targetRevision: HEAD
    ref: values    # Creates $values reference
```

**Why multiple sources?**
- Separate chart versioning from config
- Store values in Git for versioning
- Different teams manage chart vs config
- Environment-specific configs in different repos

---

## Labs

### Lab 3.1: Plain Manifests

#### Step 1: Explore the Manifests

```bash
# View the manifest files
ls -la plain-manifests/

# Check the namespace
cat plain-manifests/namespace.yaml

# Check the deployment
cat plain-manifests/deployment.yaml

# Check the service
cat plain-manifests/service.yaml

# Check the configmap
cat plain-manifests/configmap.yaml
```

#### Step 2: Understand the Application Manifest

```bash
cat plain-manifests-app.yaml
```

Key observations:
- Uses `directory.recurse: false` - only reads files in the specified path
- Has `automated` sync policy with `prune` and `selfHeal`
- Creates namespace automatically

#### Step 3: Deploy (After Setting Up Your Repo)

To deploy this lab, you need to:

1. Fork or create a repository with these files
2. Update `YOUR_USERNAME` in the app manifests:

```bash
# Replace with your GitHub username
sed -i '' 's/YOUR_USERNAME/your-github-username/g' plain-manifests-app.yaml
```

3. Apply and sync:

```bash
kubectl apply -f plain-manifests-app.yaml
argocd app sync plain-manifests-demo
```

4. Verify:

```bash
kubectl get all -n plain-demo
```

### Lab 3.2: Kustomize Overlays

#### Step 1: Explore the Base

```bash
# View base structure
ls -la kustomize-demo/base/

# Check base kustomization
cat kustomize-demo/base/kustomization.yaml

# Check base deployment
cat kustomize-demo/base/deployment.yaml
```

The base contains:
- Common deployment configuration
- Service definition
- Labels applied to all resources

#### Step 2: Compare Overlays

```bash
# Dev overlay - minimal resources
cat kustomize-demo/overlays/dev/kustomization.yaml

# Staging overlay - medium resources
cat kustomize-demo/overlays/staging/kustomization.yaml

# Prod overlay - full resources
cat kustomize-demo/overlays/prod/kustomization.yaml
```

Notice the differences:
- `namePrefix` - dev-, staging-, prod-
- `replicas` - 1, 2, 3 respectively
- `commonLabels.env` - environment identifier

#### Step 3: Preview Kustomize Output

```bash
# See what Kustomize generates for each environment
kubectl kustomize kustomize-demo/overlays/dev
kubectl kustomize kustomize-demo/overlays/staging
kubectl kustomize kustomize-demo/overlays/prod
```

#### Step 4: Deploy Dev Environment

```bash
# Update repository URL first
sed -i '' 's/YOUR_USERNAME/your-github-username/g' kustomize-dev-app.yaml

# Apply and sync
kubectl apply -f kustomize-dev-app.yaml
argocd app sync kustomize-dev
```

#### Step 5: Create Apps for All Environments

Create staging and prod apps following the same pattern:

```yaml
# kustomize-staging-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kustomize-staging
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/YOUR_USERNAME/argocd-learning.git
    targetRevision: HEAD
    path: phase-3-application-sources/kustomize-demo/overlays/staging
  destination:
    server: https://kubernetes.default.svc
    namespace: kustomize-staging
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### Lab 3.3: Helm Charts

#### Step 1: Understanding Helm Source

```bash
cat helm-nginx-app.yaml
```

Key points:
- `repoURL` points to Helm repository (not Git)
- `chart` specifies the chart name
- `targetRevision` is the chart version
- `helm.values` contains inline overrides
- `helm.parameters` for individual values

#### Step 2: Add Helm Repository to Argo CD

```bash
argocd repo add https://charts.bitnami.com/bitnami --type helm --name bitnami
```

#### Step 3: Deploy Helm Application

```bash
kubectl apply -f helm-nginx-app.yaml
argocd app sync helm-nginx
```

#### Step 4: Explore Helm in Argo CD

```bash
# View the application
argocd app get helm-nginx

# See the generated manifests
argocd app manifests helm-nginx
```

#### Step 5: Modify Values

Try changing values and see Argo CD detect drift:

```bash
# Edit helm-nginx-app.yaml and change replicaCount to 3
# Then:
kubectl apply -f helm-nginx-app.yaml
argocd app diff helm-nginx
argocd app sync helm-nginx
```

### Lab 3.4: Multiple Sources

#### Step 1: Understand the Pattern

```bash
cat helm-multi-source-app.yaml
```

This pattern:
1. First source: Helm chart from registry
2. Second source: Git repo with `ref: values`
3. First source references values via `$values/path`

#### Step 2: Explore Values Files

```bash
# Common values shared by all environments
cat helm-values/values-common.yaml

# Production-specific overrides
cat helm-values/values-prod.yaml
```

#### Step 3: Deploy Multi-Source Application

```bash
# Update repository URL
sed -i '' 's/YOUR_USERNAME/your-github-username/g' helm-multi-source-app.yaml

# Apply and sync
kubectl apply -f helm-multi-source-app.yaml
argocd app sync helm-multi-source
```

#### Step 4: Test Values Changes

1. Modify `helm-values/values-prod.yaml`
2. Commit and push to Git
3. Refresh and observe Argo CD detecting changes:

```bash
argocd app get helm-multi-source --refresh
argocd app diff helm-multi-source
```

---

## Source Detection

Argo CD automatically detects source type:

| Detection | Source Type |
|-----------|-------------|
| `chart` field present | Helm chart from repo |
| `kustomization.yaml` in path | Kustomize |
| `Chart.yaml` in path | Helm chart from Git |
| None of above | Plain manifests |

You can explicitly set the type:

```yaml
source:
  path: my-app/
  directory:
    # Force plain manifests even if kustomization.yaml exists
    include: '{*.yaml,*.yml}'
```

---

## Best Practices

### Kustomize

1. **Keep bases generic** - No environment-specific values in base
2. **Use overlays for environments** - dev, staging, prod
3. **Prefer patches over replacements** - More maintainable
4. **Version your bases** - Use Git refs for base versioning

### Helm

1. **Pin chart versions** - Don't use `latest`
2. **Externalize values** - Use multi-source pattern
3. **Use releaseName** - Explicit release naming
4. **Test locally first** - `helm template` before deploying

### Multi-Source

1. **Separate concerns** - Charts vs values in different repos
2. **Use consistent naming** - `$values`, `$secrets`, etc.
3. **Document dependencies** - Which sources depend on which

---

## Knowledge Check

Answer these questions before proceeding:

1. **How does Argo CD detect if a source is Kustomize?**
   <details>
   <summary>Answer</summary>
   It looks for a kustomization.yaml file in the source path. If found, it uses Kustomize to render manifests.
   </details>

2. **What's the difference between helm.values and helm.parameters?**
   <details>
   <summary>Answer</summary>
   `values` is a YAML block for multiple values (like values.yaml). `parameters` is a list of individual key-value overrides with higher precedence.
   </details>

3. **In multi-source apps, what does `ref: values` do?**
   <details>
   <summary>Answer</summary>
   It creates a reference named "values" that other sources can use with $values to access files from that repository.
   </details>

4. **Why use multi-source instead of inline Helm values?**
   <details>
   <summary>Answer</summary>
   Multi-source allows storing values in Git for versioning, enables different teams to manage chart vs config, and provides cleaner separation of concerns.
   </details>

5. **What happens if you have both kustomization.yaml and plain YAML in a directory?**
   <details>
   <summary>Answer</summary>
   Argo CD will use Kustomize because kustomization.yaml is detected. The kustomization.yaml must reference which files to include.
   </details>

---

## Common Mistakes

1. **Forgetting to add Helm repos** - Argo CD needs repository access
2. **Using `source` instead of `sources`** - Multi-source requires plural
3. **Wrong $ref syntax** - Reference must match exactly: `$values/path`
4. **Not pinning chart versions** - Leads to unexpected upgrades
5. **Kustomize patches on wrong target** - Name must match base resource name

---

## Files in This Directory

| File/Directory | Purpose |
|----------------|---------|
| `plain-manifests/` | Raw YAML manifests |
| `plain-manifests-app.yaml` | Application for plain manifests |
| `kustomize-demo/` | Kustomize base and overlays |
| `kustomize-dev-app.yaml` | Application for dev overlay |
| `helm-nginx-app.yaml` | Helm chart application |
| `helm-values/` | External values files |
| `helm-multi-source-app.yaml` | Multi-source application |

---

## What's Next?

Now that you can define applications with different source types, proceed to **Phase 4: Sync Lifecycle** to learn about sync waves, hooks, and policies.

```bash
cd ../phase-4-sync-lifecycle
cat README.md
```

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Source Detection
- Source Types
- Plain Manifests
- Kustomize

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
