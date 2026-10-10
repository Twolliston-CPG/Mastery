# Exercise 3: Container Image Builds

## Objectives

- Build container images in Kubernetes
- Use Kaniko for rootless builds
- Configure BuildKit for advanced builds
- Implement multi-architecture builds

## Prerequisites

- Completed Exercises 1-2
- Tekton or GitHub Actions configured
- Container registry access

---

## Part 1: Build Strategies Overview

### 1.1 Container Build Options

**Container Build Strategies**

**Docker-in-Docker (DinD):**

- Full Docker daemon inside container
- Requires privileged mode
- Security concerns in shared clusters

**Kaniko:**

- Builds images from Dockerfile
- No Docker daemon required
- Runs in userspace
- Recommended for Kubernetes builds

**BuildKit:**

- Next-gen Docker build engine
- Supports rootless mode
- Efficient caching
- Parallel build stages

**Buildah:**

- OCI-compliant image builder
- Daemonless
- Supports Dockerfile and native commands


---

## Part 2: Kaniko Builds

### 2.1 Basic Kaniko Build

```yaml
# kaniko-build-task.yaml
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: kaniko-build
spec:
  params:
    - name: IMAGE
      description: Name of the image to build
    - name: DOCKERFILE
      default: ./Dockerfile
    - name: CONTEXT
      default: .
    - name: EXTRA_ARGS
      type: array
      default: []
  workspaces:
    - name: source
    - name: dockerconfig
      description: Docker config for registry auth
  results:
    - name: IMAGE_DIGEST
    - name: IMAGE_URL
  steps:
    - name: build-and-push
      image: gcr.io/kaniko-project/executor:latest
      args:
        - --dockerfile=$(params.DOCKERFILE)
        - --context=$(workspaces.source.path)/$(params.CONTEXT)
        - --destination=$(params.IMAGE)
        - --digest-file=$(results.IMAGE_DIGEST.path)
        - $(params.EXTRA_ARGS[*])
      env:
        - name: DOCKER_CONFIG
          value: $(workspaces.dockerconfig.path)
```

### 2.2 Kaniko with Cache

```yaml
# kaniko-cached-build.yaml
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: kaniko-cached-build
spec:
  params:
    - name: IMAGE
    - name: CACHE_REPO
      description: Repository for cache layers
  workspaces:
    - name: source
    - name: dockerconfig
  steps:
    - name: build
      image: gcr.io/kaniko-project/executor:latest
      args:
        - --dockerfile=./Dockerfile
        - --context=$(workspaces.source.path)
        - --destination=$(params.IMAGE)
        # Cache configuration
        - --cache=true
        - --cache-repo=$(params.CACHE_REPO)
        - --cache-ttl=24h
        # Performance optimizations
        - --snapshot-mode=redo
        - --use-new-run
```

### 2.3 Multi-Stage Kaniko Build

```dockerfile
# Dockerfile
# Stage 1: Build
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /app/main .

# Stage 2: Runtime
FROM gcr.io/distroless/static-debian12
COPY --from=builder /app/main /main
ENTRYPOINT ["/main"]
```

```yaml
# kaniko-multistage.yaml
apiVersion: tekton.dev/v1beta1
kind: TaskRun
metadata:
  name: build-go-app
spec:
  taskRef:
    name: kaniko-build
  params:
    - name: IMAGE
      value: registry.example.com/myapp:$(context.taskRun.uid)
    - name: EXTRA_ARGS
      value:
        - --build-arg=VERSION=1.0.0
        - --label=org.opencontainers.image.source=https://github.com/org/repo
  workspaces:
    - name: source
      persistentVolumeClaim:
        claimName: source-pvc
    - name: dockerconfig
      secret:
        secretName: docker-credentials
```

---

## Part 3: BuildKit

### 3.1 BuildKit Daemon Deployment

```yaml
# buildkit-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: buildkitd
  namespace: build-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: buildkitd
  template:
    metadata:
      labels:
        app: buildkitd
    spec:
      containers:
        - name: buildkitd
          image: moby/buildkit:latest
          args:
            - --addr
            - unix:///run/buildkit/buildkitd.sock
            - --addr
            - tcp://0.0.0.0:1234
          securityContext:
            privileged: true  # Required for BuildKit
          volumeMounts:
            - name: buildkit-socket
              mountPath: /run/buildkit
            - name: cache
              mountPath: /var/lib/buildkit
          ports:
            - containerPort: 1234
      volumes:
        - name: buildkit-socket
          emptyDir: {}
        - name: cache
          persistentVolumeClaim:
            claimName: buildkit-cache
---
apiVersion: v1
kind: Service
metadata:
  name: buildkitd
  namespace: build-system
spec:
  selector:
    app: buildkitd
  ports:
    - port: 1234
      targetPort: 1234
```

### 3.2 BuildKit Task

```yaml
# buildkit-task.yaml
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: buildkit-build
spec:
  params:
    - name: IMAGE
    - name: DOCKERFILE
      default: Dockerfile
    - name: CONTEXT
      default: .
    - name: BUILDKIT_HOST
      default: tcp://buildkitd.build-system:1234
  workspaces:
    - name: source
    - name: dockerconfig
  results:
    - name: IMAGE_DIGEST
  steps:
    - name: build
      image: moby/buildkit:latest
      workingDir: $(workspaces.source.path)
      env:
        - name: BUILDKITD_FLAGS
          value: --addr $(params.BUILDKIT_HOST)
        - name: DOCKER_CONFIG
          value: $(workspaces.dockerconfig.path)
      script: |
        #!/bin/sh
        buildctl build \
          --frontend dockerfile.v0 \
          --local context=$(params.CONTEXT) \
          --local dockerfile=$(params.CONTEXT) \
          --opt filename=$(params.DOCKERFILE) \
          --output type=image,name=$(params.IMAGE),push=true \
          --export-cache type=inline \
          --import-cache type=registry,ref=$(params.IMAGE):buildcache \
          --metadata-file /tmp/metadata.json

        # Extract digest
        cat /tmp/metadata.json | jq -r '."containerimage.digest"' > $(results.IMAGE_DIGEST.path)
```

### 3.3 Rootless BuildKit

```yaml
# buildkit-rootless.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: buildkitd-rootless
  namespace: build-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: buildkitd-rootless
  template:
    metadata:
      labels:
        app: buildkitd-rootless
    spec:
      securityContext:
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
      containers:
        - name: buildkitd
          image: moby/buildkit:rootless
          args:
            - --addr
            - unix:///run/user/1000/buildkit/buildkitd.sock
            - --oci-worker-no-process-sandbox
          securityContext:
            seccompProfile:
              type: Unconfined
            allowPrivilegeEscalation: false
          volumeMounts:
            - name: buildkit-state
              mountPath: /home/user/.local/share/buildkit
      volumes:
        - name: buildkit-state
          persistentVolumeClaim:
            claimName: buildkit-state
```

---

## Part 4: Multi-Architecture Builds

### 4.1 Multi-Arch Kaniko

```yaml
# multi-arch-pipeline.yaml
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: multi-arch-build
spec:
  params:
    - name: IMAGE
    - name: GIT_URL
    - name: GIT_REVISION
      default: main
  workspaces:
    - name: source
    - name: dockerconfig
  tasks:
    - name: clone
      taskRef:
        name: git-clone
      params:
        - name: url
          value: $(params.GIT_URL)
        - name: revision
          value: $(params.GIT_REVISION)
      workspaces:
        - name: output
          workspace: source

    # Build AMD64
    - name: build-amd64
      runAfter: [clone]
      taskRef:
        name: kaniko-build
      params:
        - name: IMAGE
          value: $(params.IMAGE):$(params.GIT_REVISION)-amd64
        - name: EXTRA_ARGS
          value:
            - --customPlatform=linux/amd64
      workspaces:
        - name: source
          workspace: source
        - name: dockerconfig
          workspace: dockerconfig

    # Build ARM64
    - name: build-arm64
      runAfter: [clone]
      taskRef:
        name: kaniko-build
      params:
        - name: IMAGE
          value: $(params.IMAGE):$(params.GIT_REVISION)-arm64
        - name: EXTRA_ARGS
          value:
            - --customPlatform=linux/arm64
      workspaces:
        - name: source
          workspace: source
        - name: dockerconfig
          workspace: dockerconfig

    # Create manifest
    - name: create-manifest
      runAfter: [build-amd64, build-arm64]
      taskRef:
        name: create-manifest
      params:
        - name: IMAGE
          value: $(params.IMAGE):$(params.GIT_REVISION)
        - name: IMAGES
          value:
            - $(params.IMAGE):$(params.GIT_REVISION)-amd64
            - $(params.IMAGE):$(params.GIT_REVISION)-arm64
```

### 4.2 Manifest Task

```yaml
# manifest-task.yaml
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: create-manifest
spec:
  params:
    - name: IMAGE
    - name: IMAGES
      type: array
  workspaces:
    - name: dockerconfig
  steps:
    - name: create-manifest
      image: mplatform/manifest-tool:alpine
      env:
        - name: DOCKER_CONFIG
          value: $(workspaces.dockerconfig.path)
      script: |
        #!/bin/sh
        manifest-tool push from-args \
          --platforms linux/amd64,linux/arm64 \
          --template $(params.IMAGE)-ARCH \
          --target $(params.IMAGE)
```

### 4.3 BuildKit Multi-Arch

```yaml
# buildkit-multiarch.yaml
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: buildkit-multiarch
spec:
  params:
    - name: IMAGE
    - name: PLATFORMS
      default: linux/amd64,linux/arm64
  workspaces:
    - name: source
    - name: dockerconfig
  steps:
    - name: build
      image: moby/buildkit:latest
      workingDir: $(workspaces.source.path)
      script: |
        #!/bin/sh
        buildctl build \
          --frontend dockerfile.v0 \
          --local context=. \
          --local dockerfile=. \
          --opt platform=$(params.PLATFORMS) \
          --output type=image,name=$(params.IMAGE),push=true
```

---

## Part 5: GitHub Actions Builds

### 5.1 Basic Build Workflow

```yaml
# .github/workflows/build.yaml
name: Build and Push

on:
  push:
    branches: [main]
    tags: ['v*']
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

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up QEMU
        uses: docker/setup-qemu-action@v3

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to Registry
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
            type=ref,event=branch
            type=ref,event=pr
            type=semver,pattern={{version}}
            type=sha,prefix=

      - name: Build and Push
        uses: docker/build-push-action@v5
        with:
          context: .
          platforms: linux/amd64,linux/arm64
          push: ${{ github.event_name != 'pull_request' }}
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

### 5.2 Build with Testing

```yaml
# .github/workflows/build-test.yaml
name: Build, Test, and Push

on:
  push:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run Tests
        run: |
          docker build --target test -t test .
          docker run --rm test

  build:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Build and Push
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ghcr.io/${{ github.repository }}:${{ github.sha }}
```

---

## Part 6: Image Security

### 6.1 SBOM Generation

```yaml
# sbom-task.yaml
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: generate-sbom
spec:
  params:
    - name: IMAGE
  workspaces:
    - name: output
  steps:
    - name: generate-sbom
      image: anchore/syft:latest
      script: |
        syft $(params.IMAGE) \
          -o spdx-json \
          > $(workspaces.output.path)/sbom.spdx.json

        syft $(params.IMAGE) \
          -o cyclonedx-json \
          > $(workspaces.output.path)/sbom.cyclonedx.json

    - name: attest-sbom
      image: gcr.io/projectsigstore/cosign:latest
      script: |
        cosign attest \
          --predicate $(workspaces.output.path)/sbom.spdx.json \
          --type spdx \
          $(params.IMAGE)
```

### 6.2 Image Signing

```yaml
# signing-task.yaml
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: sign-image
spec:
  params:
    - name: IMAGE
    - name: DIGEST
  steps:
    - name: sign
      image: gcr.io/projectsigstore/cosign:latest
      env:
        - name: COSIGN_EXPERIMENTAL
          value: "1"
      script: |
        # Keyless signing with Fulcio
        cosign sign \
          --yes \
          $(params.IMAGE)@$(params.DIGEST)
```

### 6.3 Vulnerability Scanning

```yaml
# scan-task.yaml
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: scan-image
spec:
  params:
    - name: IMAGE
    - name: SEVERITY_THRESHOLD
      default: HIGH
  results:
    - name: SCAN_RESULT
  steps:
    - name: scan
      image: aquasec/trivy:latest
      script: |
        trivy image \
          --severity $(params.SEVERITY_THRESHOLD),CRITICAL \
          --exit-code 1 \
          --no-progress \
          --format json \
          --output /tmp/scan-results.json \
          $(params.IMAGE)

        # Store result
        echo "passed" > $(results.SCAN_RESULT.path)
      onError: continue

    - name: check-results
      image: stedolan/jq
      script: |
        if [ -f /tmp/scan-results.json ]; then
          vulns=$(cat /tmp/scan-results.json | jq '.Results[].Vulnerabilities | length')
          if [ "$vulns" -gt 0 ]; then
            echo "failed" > $(results.SCAN_RESULT.path)
            exit 1
          fi
        fi
```

---

## Part 7: Caching Strategies

### 7.1 Registry Cache

```yaml
# kaniko-with-registry-cache.yaml
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: kaniko-registry-cache
spec:
  params:
    - name: IMAGE
    - name: CACHE_IMAGE
  steps:
    - name: build
      image: gcr.io/kaniko-project/executor:latest
      args:
        - --dockerfile=./Dockerfile
        - --destination=$(params.IMAGE)
        - --cache=true
        - --cache-repo=$(params.CACHE_IMAGE)
        - --cache-copy-layers
```

### 7.2 Layer Caching with PVC

```yaml
# buildkit-pvc-cache.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: buildkit-cache
  namespace: build-system
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 50Gi
---
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: buildkit-cached
spec:
  params:
    - name: IMAGE
  workspaces:
    - name: source
    - name: cache
  steps:
    - name: build
      image: moby/buildkit:latest
      volumeMounts:
        - name: cache
          mountPath: /var/lib/buildkit
      script: |
        buildctl build \
          --frontend dockerfile.v0 \
          --local context=$(workspaces.source.path) \
          --local dockerfile=$(workspaces.source.path) \
          --output type=image,name=$(params.IMAGE),push=true
```

---

## Part 8: Best Practices

### 8.1 Dockerfile Optimization

```dockerfile
# Optimized Dockerfile
# Use specific versions
FROM node:20.10-alpine AS base

# Install dependencies in separate layer
FROM base AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

# Build application
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

# Production image
FROM base AS runner
WORKDIR /app
ENV NODE_ENV=production

# Run as non-root
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs
USER nextjs

COPY --from=builder --chown=nextjs:nodejs /app/dist ./dist
COPY --from=deps --chown=nextjs:nodejs /app/node_modules ./node_modules

EXPOSE 3000
CMD ["node", "dist/index.js"]
```

### 8.2 Build Arguments

```yaml
# build-args-task.yaml
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: build-with-args
spec:
  params:
    - name: IMAGE
    - name: VERSION
    - name: GIT_SHA
  steps:
    - name: build
      image: gcr.io/kaniko-project/executor:latest
      args:
        - --destination=$(params.IMAGE)
        - --build-arg=VERSION=$(params.VERSION)
        - --build-arg=GIT_SHA=$(params.GIT_SHA)
        - --build-arg=BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        - --label=org.opencontainers.image.version=$(params.VERSION)
        - --label=org.opencontainers.image.revision=$(params.GIT_SHA)
```

---

## Part 9: Hands-on Challenges

### Challenge 1: Optimized Build Pipeline

Create efficient build pipeline:
1. Implement layer caching
2. Add parallel builds
3. Generate SBOM
4. Sign images

### Challenge 2: Multi-Arch Production

Build for multiple architectures:
1. Configure QEMU emulation
2. Build for AMD64 and ARM64
3. Create multi-arch manifest
4. Test on different platforms

### Challenge 3: Security-First Builds

Implement secure build process:
1. Rootless builds only
2. Image scanning gate
3. SBOM attestation
4. Signature verification

---

## Verification Tasks

1. [ ] Built image with Kaniko
2. [ ] Configured BuildKit
3. [ ] Implemented multi-arch builds
4. [ ] Set up caching strategy
5. [ ] Added image scanning
6. [ ] Configured image signing

---

## Key Takeaways

- Use Kaniko for rootless Kubernetes builds
- BuildKit provides advanced caching
- Multi-arch builds support diverse infrastructure
- Always scan images for vulnerabilities
- Sign images for supply chain security
- Optimize Dockerfiles for faster builds

---

## Next Steps

Continue to [Exercise 4: Image Scanning](04-image-scanning.md)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Build Strategies Overview
- Kaniko Builds
- BuildKit
- Multi-Architecture Builds

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
