# Exercise 2: GitHub Actions for Kubernetes

## Objective

Create production-ready GitHub Actions workflows for building, testing, and deploying applications to Kubernetes with proper security and GitOps integration.

## Prerequisites

- GitHub repository
- Container registry (GHCR, ECR, or Docker Hub)
- Kubernetes cluster
- ArgoCD for GitOps (optional)

## Tasks

### Task 1: Basic Build and Push Workflow

```yaml
# .github/workflows/build.yaml
name: Build and Push

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    outputs:
      image-digest: ${{ steps.build.outputs.digest }}
      image-tag: ${{ steps.meta.outputs.tags }}

    steps:
    - name: Checkout repository
      uses: actions/checkout@v4

    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v3

    - name: Log in to Container Registry
      uses: docker/login-action@v3
      with:
        registry: ${{ env.REGISTRY }}
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}

    - name: Extract metadata for Docker
      id: meta
      uses: docker/metadata-action@v5
      with:
        images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
        tags: |
          type=sha,prefix=
          type=ref,event=branch
          type=ref,event=pr
          type=semver,pattern={{version}}
          type=semver,pattern={{major}}.{{minor}}

    - name: Build and push Docker image
      id: build
      uses: docker/build-push-action@v5
      with:
        context: .
        push: ${{ github.event_name != 'pull_request' }}
        tags: ${{ steps.meta.outputs.tags }}
        labels: ${{ steps.meta.outputs.labels }}
        cache-from: type=gha
        cache-to: type=gha,mode=max
        platforms: linux/amd64,linux/arm64
```

### Task 2: Complete CI/CD Pipeline

```yaml
# .github/workflows/ci-cd.yaml
name: CI/CD Pipeline

on:
  push:
    branches: [main, develop]
    tags: ['v*']
  pull_request:
    branches: [main]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  # Job 1: Lint and Test
  test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4

    - name: Set up Go
      uses: actions/setup-go@v5
      with:
        go-version-file: go.mod
        cache: true

    - name: Run linters
      uses: golangci/golangci-lint-action@v3
      with:
        version: latest

    - name: Run tests
      run: |
        go test -v -race -coverprofile=coverage.out ./...
        go tool cover -func=coverage.out

    - name: Upload coverage
      uses: codecov/codecov-action@v3
      with:
        files: ./coverage.out
        fail_ci_if_error: true

  # Job 2: Build Container Image
  build:
    needs: test
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
      id-token: write  # For signing

    outputs:
      image: ${{ steps.build.outputs.imageid }}
      digest: ${{ steps.build.outputs.digest }}

    steps:
    - uses: actions/checkout@v4

    - name: Set up QEMU
      uses: docker/setup-qemu-action@v3

    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v3

    - name: Log in to registry
      if: github.event_name != 'pull_request'
      uses: docker/login-action@v3
      with:
        registry: ${{ env.REGISTRY }}
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}

    - name: Extract metadata
      id: meta
      uses: docker/metadata-action@v5
      with:
        images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
        tags: |
          type=sha,prefix=
          type=ref,event=branch
          type=ref,event=pr
          type=semver,pattern={{version}}

    - name: Build and push
      id: build
      uses: docker/build-push-action@v5
      with:
        context: .
        push: ${{ github.event_name != 'pull_request' }}
        tags: ${{ steps.meta.outputs.tags }}
        labels: ${{ steps.meta.outputs.labels }}
        cache-from: type=gha
        cache-to: type=gha,mode=max
        platforms: linux/amd64,linux/arm64
        provenance: true
        sbom: true

    - name: Install Cosign
      if: github.event_name != 'pull_request'
      uses: sigstore/cosign-installer@v3

    - name: Sign image
      if: github.event_name != 'pull_request'
      env:
        DIGEST: ${{ steps.build.outputs.digest }}
      run: |
        cosign sign --yes ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}@${DIGEST}

  # Job 3: Security Scanning
  scan:
    needs: build
    runs-on: ubuntu-latest
    if: github.event_name != 'pull_request'
    permissions:
      security-events: write

    steps:
    - name: Run Trivy vulnerability scanner
      uses: aquasecurity/trivy-action@master
      with:
        image-ref: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}@${{ needs.build.outputs.digest }}
        format: 'sarif'
        output: 'trivy-results.sarif'
        severity: 'CRITICAL,HIGH'

    - name: Upload Trivy scan results
      uses: github/codeql-action/upload-sarif@v2
      with:
        sarif_file: 'trivy-results.sarif'

  # Job 4: Deploy to Staging
  deploy-staging:
    needs: [build, scan]
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/develop'
    environment:
      name: staging
      url: https://staging.example.com

    steps:
    - name: Checkout manifests repo
      uses: actions/checkout@v4
      with:
        repository: ${{ github.repository_owner }}/k8s-manifests
        token: ${{ secrets.MANIFEST_REPO_TOKEN }}
        path: manifests

    - name: Setup Kustomize
      uses: imranismail/setup-kustomize@v2

    - name: Update image tag
      working-directory: manifests
      run: |
        cd overlays/staging/api
        kustomize edit set image \
          api=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}@${{ needs.build.outputs.digest }}

    - name: Commit and push
      working-directory: manifests
      run: |
        git config user.name "GitHub Actions"
        git config user.email "actions@github.com"
        git add .
        git diff --staged --quiet || git commit -m "Update api image to ${{ github.sha }}"
        git push

  # Job 5: Deploy to Production
  deploy-production:
    needs: [build, scan]
    runs-on: ubuntu-latest
    if: startsWith(github.ref, 'refs/tags/v')
    environment:
      name: production
      url: https://api.example.com

    steps:
    - name: Checkout manifests repo
      uses: actions/checkout@v4
      with:
        repository: ${{ github.repository_owner }}/k8s-manifests
        token: ${{ secrets.MANIFEST_REPO_TOKEN }}
        path: manifests

    - name: Setup Kustomize
      uses: imranismail/setup-kustomize@v2

    - name: Update image tag
      working-directory: manifests
      run: |
        cd overlays/production/api
        kustomize edit set image \
          api=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}@${{ needs.build.outputs.digest }}

    - name: Create Pull Request
      uses: peter-evans/create-pull-request@v5
      with:
        token: ${{ secrets.MANIFEST_REPO_TOKEN }}
        path: manifests
        commit-message: "Release ${{ github.ref_name }}"
        title: "Release ${{ github.ref_name }} to production"
        body: |
          ## Release ${{ github.ref_name }}

          This PR updates the production deployment to:
          - Image: `${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}@${{ needs.build.outputs.digest }}`
          - Commit: ${{ github.sha }}

          ### Pre-deployment Checklist
          - [ ] Staging deployment verified
          - [ ] Security scan passed
          - [ ] Changelog reviewed

        branch: release/${{ github.ref_name }}
        labels: |
          release
          automated
```

### Task 3: Reusable Workflow

```yaml
# .github/workflows/reusable-deploy.yaml
name: Reusable Deploy

on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string
      image-digest:
        required: true
        type: string
      app-name:
        required: true
        type: string
    secrets:
      MANIFEST_REPO_TOKEN:
        required: true
      KUBECONFIG:
        required: false

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment }}

    steps:
    - name: Checkout manifests
      uses: actions/checkout@v4
      with:
        repository: ${{ github.repository_owner }}/k8s-manifests
        token: ${{ secrets.MANIFEST_REPO_TOKEN }}

    - name: Setup Kustomize
      uses: imranismail/setup-kustomize@v2

    - name: Update manifest
      run: |
        cd overlays/${{ inputs.environment }}/${{ inputs.app-name }}
        kustomize edit set image \
          ${{ inputs.app-name }}=ghcr.io/${{ github.repository }}@${{ inputs.image-digest }}

    - name: Commit changes
      run: |
        git config user.name "GitHub Actions"
        git config user.email "actions@github.com"
        git add .
        git diff --staged --quiet || git commit -m "Deploy ${{ inputs.app-name }} to ${{ inputs.environment }}"
        git push

---
# Usage in another workflow
# .github/workflows/deploy.yaml
name: Deploy

on:
  workflow_dispatch:
    inputs:
      environment:
        type: choice
        options: [staging, production]
      image-digest:
        required: true
        type: string

jobs:
  deploy:
    uses: ./.github/workflows/reusable-deploy.yaml
    with:
      environment: ${{ inputs.environment }}
      image-digest: ${{ inputs.image-digest }}
      app-name: api
    secrets: inherit
```

### Task 4: Matrix Strategy for Multi-Service

```yaml
# .github/workflows/monorepo.yaml
name: Monorepo CI/CD

on:
  push:
    branches: [main]
    paths:
    - 'services/**'

jobs:
  detect-changes:
    runs-on: ubuntu-latest
    outputs:
      services: ${{ steps.changes.outputs.services }}

    steps:
    - uses: actions/checkout@v4
      with:
        fetch-depth: 2

    - name: Detect changed services
      id: changes
      run: |
        CHANGED=$(git diff --name-only HEAD~1 | grep '^services/' | cut -d'/' -f2 | sort -u | jq -R -s -c 'split("\n") | map(select(length > 0))')
        echo "services=${CHANGED}" >> $GITHUB_OUTPUT

  build:
    needs: detect-changes
    if: needs.detect-changes.outputs.services != '[]'
    runs-on: ubuntu-latest
    strategy:
      matrix:
        service: ${{ fromJson(needs.detect-changes.outputs.services) }}
      fail-fast: false

    steps:
    - uses: actions/checkout@v4

    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v3

    - name: Log in to registry
      uses: docker/login-action@v3
      with:
        registry: ghcr.io
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}

    - name: Build and push ${{ matrix.service }}
      uses: docker/build-push-action@v5
      with:
        context: ./services/${{ matrix.service }}
        push: true
        tags: ghcr.io/${{ github.repository }}/${{ matrix.service }}:${{ github.sha }}
        cache-from: type=gha,scope=${{ matrix.service }}
        cache-to: type=gha,scope=${{ matrix.service }},mode=max
```

### Task 5: Direct Kubernetes Deployment

```yaml
# .github/workflows/deploy-k8s.yaml
name: Deploy to Kubernetes

on:
  workflow_dispatch:
    inputs:
      environment:
        type: choice
        options: [staging, production]

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment }}

    steps:
    - uses: actions/checkout@v4

    - name: Set up kubectl
      uses: azure/setup-kubectl@v3

    - name: Configure kubeconfig
      run: |
        mkdir -p ~/.kube
        echo "${{ secrets.KUBECONFIG }}" | base64 -d > ~/.kube/config
        chmod 600 ~/.kube/config

    - name: Deploy with Kustomize
      run: |
        kubectl apply -k overlays/${{ inputs.environment }}

    - name: Wait for rollout
      run: |
        kubectl rollout status deployment/api -n ${{ inputs.environment }} --timeout=300s

    - name: Verify deployment
      run: |
        kubectl get pods -n ${{ inputs.environment }} -l app=api
        kubectl get svc -n ${{ inputs.environment }}

    - name: Run smoke tests
      run: |
        SERVICE_IP=$(kubectl get svc api -n ${{ inputs.environment }} -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
        curl -f http://${SERVICE_IP}/health || exit 1
```

## Validation

```bash
# Test workflow locally with act
act -j build

# Trigger workflow manually
gh workflow run ci-cd.yaml

# Check workflow runs
gh run list
gh run view <run-id>

# View logs
gh run view <run-id> --log
```

## Success Criteria

- [ ] Build workflow triggers on push
- [ ] Multi-platform images built and pushed
- [ ] Security scan results uploaded to GitHub
- [ ] Staging deployment automated on develop branch
- [ ] Production PR created on tag push
- [ ] Image signing with Cosign

## Best Practices

1. **Use workflow_call** for reusable workflows
2. **Pin action versions** with SHA for security
3. **Use environments** for deployment protection
4. **Enable OIDC** for cloud provider authentication
5. **Cache dependencies** for faster builds
6. **Use matrix** for parallel builds

## Next Exercise

Continue to [Exercise 3: Security Scanning Pipeline](./03-security-scanning.md) for comprehensive security integration.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Basic Build and Push Workflow
- Complete CI/CD Pipeline
- Reusable Workflow
- Matrix Strategy for Multi-Service

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
