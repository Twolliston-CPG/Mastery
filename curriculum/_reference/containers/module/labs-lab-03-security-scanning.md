# Lab 3.3: Container Security Scanning

> **Duration:** 60-90 minutes
> **Environment:** Docker, Trivy installed
> **Difficulty:** Intermediate

---

## Objectives

- Scan container images for vulnerabilities
- Scan Dockerfiles for misconfigurations
- Implement security best practices
- Integrate scanning into CI/CD

---

## Prerequisites

```bash
# Install Trivy
brew install trivy
# or
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin

# Verify
trivy --version
```

---

## Part 1: Image Vulnerability Scanning

### Exercise 1.1: Basic Image Scan

```bash
# Scan an image
trivy image nginx:1.25

# Scan with severity filter
trivy image --severity HIGH,CRITICAL nginx:1.25

# Output in different formats
trivy image -f json nginx:1.25 > nginx-report.json
trivy image -f table nginx:1.25
trivy image -f template --template "@contrib/html.tpl" nginx:1.25 > report.html

# Ignore unfixed vulnerabilities
trivy image --ignore-unfixed nginx:1.25

# Scan specific image layers
trivy image --list-all-pkgs nginx:1.25
```

### Exercise 1.2: Compare Image Security

```bash
# Scan different base images
echo "=== Scanning Ubuntu ===" && trivy image --severity HIGH,CRITICAL ubuntu:22.04 2>/dev/null | tail -20
echo "=== Scanning Alpine ===" && trivy image --severity HIGH,CRITICAL alpine:3.19 2>/dev/null | tail -20
echo "=== Scanning Distroless ===" && trivy image --severity HIGH,CRITICAL gcr.io/distroless/static-debian12 2>/dev/null | tail -20

# Compare vulnerability counts
echo "Ubuntu:" && trivy image -q ubuntu:22.04 | grep -E "^Total:"
echo "Alpine:" && trivy image -q alpine:3.19 | grep -E "^Total:"
echo "Distroless:" && trivy image -q gcr.io/distroless/static-debian12 | grep -E "^Total:"
```

### Exercise 1.3: SBOM Generation

```bash
# Generate Software Bill of Materials
trivy image --format spdx-json nginx:1.25 > nginx-sbom.json

# Generate CycloneDX format
trivy image --format cyclonedx nginx:1.25 > nginx-cyclonedx.json

# View SBOM
cat nginx-sbom.json | jq '.packages[:5]'
```

---

## Part 2: Dockerfile Scanning

### Exercise 2.1: Scan Dockerfile

```bash
mkdir -p ~/docker-lab/security-scan
cd ~/docker-lab/security-scan

# Create an insecure Dockerfile
cat > Dockerfile.insecure << 'EOF'
FROM ubuntu:latest
RUN apt-get update && apt-get install -y curl
RUN echo "secret_password" > /secret.txt
USER root
EXPOSE 22
ADD https://example.com/app.tar.gz /app/
CMD ["bash"]
EOF

# Scan for misconfigurations
trivy config Dockerfile.insecure

# Issues found:
# - Using 'latest' tag
# - Running as root
# - Exposing SSH port
# - Using ADD instead of COPY
# - Hardcoded secret
```

### Exercise 2.2: Fix Security Issues

```bash
# Create a secure Dockerfile
cat > Dockerfile.secure << 'EOF'
# Use specific version
FROM ubuntu:22.04

# Install dependencies and clean up
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m -u 1000 appuser

# Copy files (not ADD)
COPY app/ /app/

# Set ownership
RUN chown -R appuser:appuser /app

# Switch to non-root user
USER appuser
WORKDIR /app

# Don't expose unnecessary ports
EXPOSE 8080

# Use exec form
CMD ["./app"]
EOF

# Scan again
trivy config Dockerfile.secure
# Should have fewer or no issues
```

### Exercise 2.3: Hadolint

```bash
# Install hadolint
brew install hadolint
# or
docker pull hadolint/hadolint

# Lint Dockerfile
hadolint Dockerfile.insecure

# Lint with Docker
docker run --rm -i hadolint/hadolint < Dockerfile.insecure

# Ignore specific rules
hadolint --ignore DL3008 --ignore DL3015 Dockerfile.insecure

# Create hadolint config
cat > .hadolint.yaml << 'EOF'
ignored:
  - DL3008  # Pin versions in apt-get
  - DL3018  # Pin versions in apk
trustedRegistries:
  - docker.io
  - gcr.io
  - ghcr.io
EOF

hadolint --config .hadolint.yaml Dockerfile.insecure
```

---

## Part 3: Runtime Security Analysis

### Exercise 3.1: Security Options

```bash
cd ~/docker-lab/security-scan

# Create test image
cat > Dockerfile << 'EOF'
FROM alpine:3.19
RUN adduser -D appuser
USER appuser
CMD ["sh", "-c", "while true; do echo 'Running...'; sleep 60; done"]
EOF

docker build -t secure-test .

# Run with security options
docker run -d --name secure-container \
    --read-only \
    --tmpfs /tmp \
    --cap-drop ALL \
    --security-opt no-new-privileges:true \
    --user 1000:1000 \
    secure-test

# Verify read-only filesystem
docker exec secure-container touch /test 2>&1 || echo "Cannot write to root filesystem (good!)"

# Verify capabilities dropped
docker exec secure-container cat /proc/1/status | grep Cap

docker rm -f secure-container
```

### Exercise 3.2: Analyze Running Container

```bash
# Run a container
docker run -d --name analyze-me nginx:1.25

# Check security configuration
docker inspect analyze-me --format '{{json .HostConfig.SecurityOpt}}'
docker inspect analyze-me --format '{{.Config.User}}'
docker inspect analyze-me --format '{{json .HostConfig.CapAdd}}'
docker inspect analyze-me --format '{{json .HostConfig.CapDrop}}'
docker inspect analyze-me --format '{{.HostConfig.ReadonlyRootfs}}'

# Use docker scout (if available)
docker scout cves analyze-me 2>/dev/null || echo "Docker Scout not available"

docker rm -f analyze-me
```

---

## Part 4: CI/CD Integration

### Exercise 4.1: GitHub Actions Workflow

```yaml
# .github/workflows/container-security.yml
name: Container Security

on:
  push:
    paths:
      - '**/Dockerfile'
      - '**/*.dockerfile'

jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Hadolint
        uses: hadolint/hadolint-action@v3.1.0
        with:
          dockerfile: Dockerfile
          failure-threshold: warning

      - name: Build image
        run: docker build -t myapp:${{ github.sha }} .

      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: 'myapp:${{ github.sha }}'
          format: 'sarif'
          output: 'trivy-results.sarif'
          severity: 'CRITICAL,HIGH'
          exit-code: '1'

      - name: Upload Trivy scan results
        uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: 'trivy-results.sarif'
```

### Exercise 4.2: Pre-commit Hook

```bash
# Add to .pre-commit-config.yaml
cat >> ~/.pre-commit-config.yaml << 'EOF'
  - repo: https://github.com/hadolint/hadolint
    rev: v2.12.0
    hooks:
      - id: hadolint-docker
        args: ['--ignore', 'DL3008']

  - repo: local
    hooks:
      - id: trivy-dockerfile
        name: Trivy Dockerfile scan
        entry: bash -c 'trivy config --exit-code 1 --severity HIGH,CRITICAL "$@"'
        language: system
        files: Dockerfile
        pass_filenames: true
EOF
```

### Exercise 4.3: Local Scanning Script

```bash
cat > scan-image.sh << 'EOF'
#!/bin/bash
set -euo pipefail

IMAGE="${1:-}"
SEVERITY="${2:-HIGH,CRITICAL}"

if [[ -z "$IMAGE" ]]; then
    echo "Usage: $0 <image> [severity]"
    exit 1
fi

echo "=== Scanning $IMAGE ==="
echo ""

echo "1. Vulnerability Scan..."
trivy image --severity "$SEVERITY" --exit-code 0 "$IMAGE"

VULN_COUNT=$(trivy image --severity "$SEVERITY" -q -f json "$IMAGE" | jq '[.Results[].Vulnerabilities // [] | length] | add // 0')
echo ""
echo "Found $VULN_COUNT vulnerabilities at $SEVERITY level"

if [[ "$VULN_COUNT" -gt 0 ]]; then
    echo ""
    read -p "Continue anyway? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo ""
echo "2. Checking image configuration..."
docker inspect "$IMAGE" --format '
User: {{.Config.User}}
Exposed Ports: {{json .Config.ExposedPorts}}
Entrypoint: {{json .Config.Entrypoint}}
Cmd: {{json .Config.Cmd}}
'

echo ""
echo "3. Image size: $(docker images "$IMAGE" --format '{{.Size}}')"

echo ""
echo "=== Scan Complete ==="
EOF

chmod +x scan-image.sh
./scan-image.sh nginx:1.25
```

---

## Part 5: Practical Challenges

### Challenge 1: Secure Image Pipeline

Create a complete secure image build pipeline:
1. Scan Dockerfile with Hadolint
2. Build image
3. Scan with Trivy
4. Generate SBOM
5. Sign image (optional)

<details>
<summary>Solution</summary>

```bash
#!/bin/bash
set -euo pipefail

IMAGE_NAME="${1:-myapp}"
IMAGE_TAG="${2:-latest}"
FULL_IMAGE="${IMAGE_NAME}:${IMAGE_TAG}"

echo "=== Step 1: Lint Dockerfile ==="
hadolint Dockerfile || { echo "Dockerfile linting failed"; exit 1; }

echo "=== Step 2: Build Image ==="
docker build -t "$FULL_IMAGE" .

echo "=== Step 3: Vulnerability Scan ==="
trivy image --exit-code 1 --severity CRITICAL "$FULL_IMAGE" || {
    echo "Critical vulnerabilities found!"
    exit 1
}

echo "=== Step 4: Generate SBOM ==="
trivy image --format cyclonedx "$FULL_IMAGE" > "${IMAGE_NAME}-sbom.json"
echo "SBOM saved to ${IMAGE_NAME}-sbom.json"

echo "=== Step 5: Sign Image (requires cosign) ==="
if command -v cosign &> /dev/null; then
    cosign sign "$FULL_IMAGE" || echo "Signing skipped"
else
    echo "Cosign not installed, skipping signing"
fi

echo "=== Pipeline Complete ==="
echo "Image: $FULL_IMAGE"
echo "SBOM: ${IMAGE_NAME}-sbom.json"
```
</details>

### Challenge 2: Fix All Vulnerabilities

Given this vulnerable image, create a secure version:

```dockerfile
FROM node:16
WORKDIR /app
COPY . .
RUN npm install
EXPOSE 3000
CMD ["npm", "start"]
```

<details>
<summary>Solution</summary>

```dockerfile
# Multi-stage build
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

FROM node:20-alpine
WORKDIR /app

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Copy dependencies
COPY --from=builder --chown=nodejs:nodejs /app/node_modules ./node_modules
COPY --chown=nodejs:nodejs . .

# Remove dev files
RUN rm -rf tests/ *.md

USER nodejs
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s \
    CMD wget -q --spider http://localhost:3000/health || exit 1

CMD ["node", "index.js"]
```
</details>

---

## Validation Checklist

- [ ] I can scan images with Trivy
- [ ] I can scan Dockerfiles for misconfigurations
- [ ] I can use Hadolint for Dockerfile linting
- [ ] I understand security best practices
- [ ] I can generate SBOMs
- [ ] I can integrate scanning into CI/CD

---

## Next Lab

Continue to [Lab 3.4: Docker Compose](labs-lab-04-docker-compose.md)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Image Vulnerability Scanning
- Dockerfile Scanning
- Runtime Security Analysis
- CI/CD Integration

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"A container isolates the application."* |
| ✓ | *"A container is an ordinary Linux process started with namespaces (what it can see), cgroups (what it can use) and usually seccomp (what it may ask the kernel). There is no container object in the kernel — only a process with those features switched on."* |

**Trace it:** `docker run` → an isolated process. Name the namespaces in the order they are created, and which component actually calls `clone()`.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** the [LWN namespaces series](https://lwn.net/Articles/531114/) — seven parts by the man-pages maintainer, and the reason containers stop being magic.
Full list per domain: [`SOURCES.md`](../../SOURCES.md#containers)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../../MASTERY.md)

<!-- /feynman-check -->
