# Lab 07: Pipeline Security

## Overview

In this lab, you'll implement comprehensive security practices for CI/CD pipelines. You'll learn about supply chain security, secrets management, container signing, and SLSA compliance.

**Duration**: 3-4 hours
**Difficulty**: Intermediate to Advanced

## Prerequisites

- GitHub or GitLab account
- Docker installed
- kubectl configured
- cosign installed
- Basic understanding of cryptographic concepts

## Learning Objectives

- Implement SLSA (Supply chain Levels for Software Artifacts) compliance
- Sign and verify container images with Cosign
- Configure OIDC authentication for pipelines
- Manage secrets securely in CI/CD
- Implement dependency scanning and SBOM generation

## Lab Environment Setup

```bash
# Create lab directory
mkdir -p ~/pipeline-security-lab && cd ~/pipeline-security-lab

# Install required tools
# Cosign for container signing
brew install cosign  # macOS
# or
go install github.com/sigstore/cosign/v2/cmd/cosign@latest

# Syft for SBOM generation
brew install syft  # macOS
# or
curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin

# Grype for vulnerability scanning
brew install grype  # macOS
# or
curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin

# Create sample application
mkdir -p src
cat > src/main.py << 'EOF'
from flask import Flask, jsonify
import os

app = Flask(__name__)

@app.route('/')
def hello():
    return jsonify({
        "message": "Secure Pipeline Demo",
        "version": os.getenv("APP_VERSION", "1.0.0")
    })

@app.route('/health')
def health():
    return jsonify({"status": "healthy"})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
EOF

cat > requirements.txt << 'EOF'
flask==3.0.0
gunicorn==21.2.0
EOF

cat > Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

# Create non-root user
RUN useradd -r -u 1001 appuser

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY src/ ./src/

USER appuser

EXPOSE 8080

CMD ["gunicorn", "-b", "0.0.0.0:8080", "src.main:app"]
EOF
```

---

## Part 1: Guided Exercise - Container Image Signing

### Step 1: Generate Signing Keys

```bash
# Generate a key pair for signing
cosign generate-key-pair

# This creates:
# - cosign.key (private key - keep secret!)
# - cosign.pub (public key - can be distributed)

# Alternatively, use keyless signing with OIDC (recommended)
# This uses your GitHub/GitLab identity
```

### Step 2: Build and Sign Container Image

```bash
# Build the image
docker build -t demo-app:v1 .

# Tag for your registry
REGISTRY="ghcr.io/YOUR_USERNAME"
docker tag demo-app:v1 $REGISTRY/demo-app:v1

# Push to registry
docker push $REGISTRY/demo-app:v1

# Sign the image with local key
cosign sign --key cosign.key $REGISTRY/demo-app:v1

# Or use keyless signing (opens browser for OIDC)
cosign sign $REGISTRY/demo-app:v1

# Verify the signature
cosign verify --key cosign.pub $REGISTRY/demo-app:v1

# Verify keyless signature
cosign verify \
  --certificate-identity "YOUR_EMAIL@example.com" \
  --certificate-oidc-issuer "https://github.com/login/oauth" \
  $REGISTRY/demo-app:v1
```

### Step 3: Add Attestations

```bash
# Create SBOM
syft $REGISTRY/demo-app:v1 -o spdx-json > sbom.spdx.json

# Attach SBOM as attestation
cosign attest --key cosign.key \
  --predicate sbom.spdx.json \
  --type spdxjson \
  $REGISTRY/demo-app:v1

# Create vulnerability scan attestation
grype $REGISTRY/demo-app:v1 -o json > vuln-report.json

cosign attest --key cosign.key \
  --predicate vuln-report.json \
  --type vuln \
  $REGISTRY/demo-app:v1

# Verify attestations
cosign verify-attestation --key cosign.pub \
  --type spdxjson \
  $REGISTRY/demo-app:v1
```

### Step 4: Create GitHub Actions Workflow with Signing

```yaml
# .github/workflows/secure-build.yml
name: Secure Build Pipeline

on:
  push:
    branches: [main]
    tags: ['v*']

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

permissions:
  contents: read
  packages: write
  id-token: write  # Required for OIDC signing

jobs:
  build-and-sign:
    runs-on: ubuntu-latest
    outputs:
      digest: ${{ steps.build.outputs.digest }}
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to GHCR
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
            type=ref,event=tag
            type=raw,value=latest,enable={{is_default_branch}}

      - name: Build and push
        id: build
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          provenance: true
          sbom: true

      - name: Install Cosign
        uses: sigstore/cosign-installer@v3

      - name: Sign image with keyless signing
        env:
          DIGEST: ${{ steps.build.outputs.digest }}
        run: |
          cosign sign --yes ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}@${DIGEST}

  generate-sbom:
    needs: build-and-sign
    runs-on: ubuntu-latest
    steps:
      - name: Install Syft
        uses: anchore/sbom-action/download-syft@v0

      - name: Generate SBOM
        uses: anchore/sbom-action@v0
        with:
          image: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}@${{ needs.build-and-sign.outputs.digest }}
          artifact-name: sbom.spdx.json
          output-file: sbom.spdx.json

      - name: Install Cosign
        uses: sigstore/cosign-installer@v3

      - name: Attest SBOM
        env:
          DIGEST: ${{ needs.build-and-sign.outputs.digest }}
        run: |
          cosign attest --yes \
            --predicate sbom.spdx.json \
            --type spdxjson \
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}@${DIGEST}

  vulnerability-scan:
    needs: build-and-sign
    runs-on: ubuntu-latest
    steps:
      - name: Run Grype scan
        uses: anchore/scan-action@v3
        id: scan
        with:
          image: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}@${{ needs.build-and-sign.outputs.digest }}
          fail-build: true
          severity-cutoff: high

      - name: Upload scan results
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: ${{ steps.scan.outputs.sarif }}
```

---

## Part 2: Semi-Guided Exercise - SLSA Compliance

### Objective

Implement SLSA Level 3 compliance:
- Hermetic builds
- Build provenance
- Source integrity verification
- Non-falsifiable provenance

### Requirements

1. **Configure SLSA GitHub Generator**

<details>
<summary>Click for SLSA workflow hint</summary>

```yaml
name: SLSA Build

on:
  push:
    tags: ['v*']

jobs:
  build:
    outputs:
      hashes: ${{ steps.hash.outputs.hashes }}
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build artifact
        run: |
          # Build your application
          go build -o my-app ./...

      - name: Generate hash
        id: hash
        run: |
          HASH=$(sha256sum my-app | base64 -w0)
          echo "hashes=$HASH" >> $GITHUB_OUTPUT

      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: my-app
          path: my-app

  provenance:
    needs: [build]
    permissions:
      actions: read
      id-token: write
      contents: write
    uses: slsa-framework/slsa-github-generator/.github/workflows/generator_generic_slsa3.yml@v1.9.0
    with:
      base64-subjects: "${{ needs.build.outputs.hashes }}"
      upload-assets: true
```
</details>

2. **Verify provenance**

<details>
<summary>Click for verification hint</summary>

```bash
# Install slsa-verifier
go install github.com/slsa-framework/slsa-verifier/v2/cli/slsa-verifier@latest

# Verify provenance
slsa-verifier verify-artifact my-app \
  --provenance-path my-app.intoto.jsonl \
  --source-uri github.com/YOUR_ORG/YOUR_REPO \
  --source-tag v1.0.0
```
</details>

3. **Configure build isolation**

### Tasks

1. Set up SLSA GitHub Generator workflow
2. Generate build provenance for releases
3. Verify provenance locally
4. Configure artifact signing
5. Document SLSA compliance level

### Validation

```bash
# Verify artifact has valid provenance
slsa-verifier verify-artifact ./my-app \
  --provenance-path ./my-app.intoto.jsonl \
  --source-uri github.com/YOUR_ORG/YOUR_REPO

# Check provenance contents
cat my-app.intoto.jsonl | jq '.payload | @base64d | fromjson'
```

---

## Part 3: Challenge - Complete Supply Chain Security

### Objective

Implement comprehensive supply chain security:
- Policy-based image admission
- Runtime verification
- Dependency management
- Secret rotation

### Requirements

1. **Deploy Kyverno for policy enforcement**

```bash
# Install Kyverno
helm repo add kyverno https://kyverno.github.io/kyverno/
helm install kyverno kyverno/kyverno -n kyverno --create-namespace

# Wait for deployment
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=kyverno -n kyverno --timeout=300s
```

2. **Create image verification policy**

```yaml
# verify-images-policy.yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-image-signatures
spec:
  validationFailureAction: Enforce
  background: false
  webhookTimeoutSeconds: 30
  rules:
    - name: verify-signature
      match:
        any:
          - resources:
              kinds:
                - Pod
      verifyImages:
        - imageReferences:
            - "ghcr.io/YOUR_ORG/*"
          attestors:
            - entries:
                - keyless:
                    subject: "YOUR_EMAIL@example.com"
                    issuer: "https://github.com/login/oauth"
                    rekor:
                      url: https://rekor.sigstore.dev
          attestations:
            - predicateType: https://spdx.dev/Document
              conditions:
                - all:
                    - key: "{{ time_since('', '{{ @.creationInfo.created }}', '') }}"
                      operator: LessThan
                      value: "168h"  # SBOM must be less than 7 days old
```

3. **Implement secret management with Vault**

4. **Configure dependency scanning**

### Success Criteria

- [ ] All images verified before deployment
- [ ] SLSA Level 3 provenance generated
- [ ] SBOM attached to all releases
- [ ] Vulnerability scanning blocks high severity
- [ ] Secrets managed via Vault/External Secrets
- [ ] Policies enforce signed images only

### Starting Point - Secure Pipeline

```yaml
# .github/workflows/secure-pipeline.yml
name: Secure Supply Chain Pipeline

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

permissions:
  contents: read
  packages: write
  id-token: write
  security-events: write

jobs:
  # Dependency scanning
  dependency-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: '.'
          format: 'sarif'
          output: 'trivy-results.sarif'
          severity: 'CRITICAL,HIGH'

      - name: Upload Trivy results
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: 'trivy-results.sarif'

  # Static analysis
  sast:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Initialize CodeQL
        uses: github/codeql-action/init@v3
        with:
          languages: python

      - name: Perform CodeQL Analysis
        uses: github/codeql-action/analyze@v3

  # Secret scanning
  secrets-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: TruffleHog scan
        uses: trufflesecurity/trufflehog@main
        with:
          path: ./
          base: ${{ github.event.repository.default_branch }}
          extra_args: --only-verified

  # Build with provenance
  build:
    needs: [dependency-scan, sast, secrets-scan]
    runs-on: ubuntu-latest
    outputs:
      digest: ${{ steps.build.outputs.digest }}
    steps:
      - uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build and push
        id: build
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ghcr.io/${{ github.repository }}:${{ github.sha }}
          provenance: true
          sbom: true

      - name: Install Cosign
        uses: sigstore/cosign-installer@v3

      - name: Sign image
        run: |
          cosign sign --yes ghcr.io/${{ github.repository }}@${{ steps.build.outputs.digest }}

  # Container scanning
  container-scan:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - name: Run Trivy container scan
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ghcr.io/${{ github.repository }}@${{ needs.build.outputs.digest }}
          format: 'sarif'
          output: 'container-trivy.sarif'
          severity: 'CRITICAL,HIGH'

      - name: Upload results
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: 'container-trivy.sarif'
```

### Starting Point - Kyverno Policies

```yaml
# require-sbom-policy.yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-sbom-attestation
spec:
  validationFailureAction: Enforce
  rules:
    - name: check-sbom
      match:
        any:
          - resources:
              kinds:
                - Pod
      verifyImages:
        - imageReferences:
            - "ghcr.io/*"
          attestations:
            - predicateType: https://spdx.dev/Document
              conditions:
                - all:
                    - key: "{{ creationInfo.created }}"
                      operator: NotEquals
                      value: ""
---
# block-vulnerable-images.yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: block-vulnerable-images
spec:
  validationFailureAction: Enforce
  rules:
    - name: check-vulnerabilities
      match:
        any:
          - resources:
              kinds:
                - Pod
      verifyImages:
        - imageReferences:
            - "*"
          attestations:
            - predicateType: https://cosign.sigstore.dev/attestation/vuln/v1
              conditions:
                - all:
                    - key: "{{ scanner.result.Summary.CriticalCount }}"
                      operator: Equals
                      value: 0
```

### Validation Script

```bash
#!/bin/bash
# validate-pipeline-security.sh

echo "Validating Pipeline Security..."

# Check cosign installation
if command -v cosign &> /dev/null; then
    echo "✓ Cosign installed: $(cosign version 2>&1 | head -1)"
else
    echo "✗ Cosign not installed"
fi

# Check syft installation
if command -v syft &> /dev/null; then
    echo "✓ Syft installed: $(syft version 2>&1 | head -1)"
else
    echo "✗ Syft not installed"
fi

# Check grype installation
if command -v grype &> /dev/null; then
    echo "✓ Grype installed: $(grype version 2>&1 | head -1)"
else
    echo "✗ Grype not installed"
fi

# Check for signing keys
if [ -f "cosign.pub" ]; then
    echo "✓ Public key exists"
else
    echo "⚠ No public key found (using keyless signing)"
fi

# Check Kyverno policies
if kubectl get clusterpolicy &>/dev/null; then
    POLICIES=$(kubectl get clusterpolicy -o name | wc -l)
    echo "✓ Found $POLICIES Kyverno policies"
else
    echo "⚠ Kyverno not installed or no policies"
fi

# Check image signatures (example)
if [ -n "$TEST_IMAGE" ]; then
    if cosign verify --certificate-identity-regexp ".*" --certificate-oidc-issuer-regexp ".*" "$TEST_IMAGE" &>/dev/null; then
        echo "✓ Image signature verified: $TEST_IMAGE"
    else
        echo "✗ Image signature verification failed"
    fi
fi

echo "Validation complete!"
```

---

## Cleanup

```bash
# Remove Kyverno
helm uninstall kyverno -n kyverno
kubectl delete namespace kyverno

# Remove signing keys (keep backup!)
# rm cosign.key cosign.pub

# Remove lab files
cd ~
rm -rf pipeline-security-lab
```

## Summary

In this lab, you learned:
- Signing container images with Cosign
- Generating and attaching SBOMs
- Implementing SLSA compliance for provenance
- Enforcing policies with Kyverno
- Scanning for vulnerabilities in dependencies and containers
- Managing secrets securely in CI/CD pipelines

## Next Steps

- Implement in-toto for full supply chain attestation
- Set up Sigstore's policy-controller
- Configure HashiCorp Vault for dynamic secrets
- Implement SPIFFE/SPIRE for workload identity

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Challenge - Complete Supply Chain Security
- Generate Signing Keys
- Build and Sign Container Image
- Add Attestations

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
