# Module 03: Container Security

## Learning Objectives

By the end of this module, you will be able to:
- Build secure container images
- Implement container image scanning
- Apply container runtime security
- Configure secure container registries
- Implement image signing and verification

## Secure Container Images

### Dockerfile Best Practices

```dockerfile
# Bad: Insecure Dockerfile
FROM ubuntu:latest
RUN apt-get update && apt-get install -y python3 curl
COPY . /app
WORKDIR /app
RUN pip install -r requirements.txt
USER root
EXPOSE 80
CMD ["python3", "app.py"]
```

```dockerfile
# Good: Secure Dockerfile
# Use specific version, not latest
FROM python:3.11-slim-bookworm@sha256:abc123...

# Create non-root user early
RUN groupadd -r appgroup && useradd -r -g appgroup appuser

# Set working directory
WORKDIR /app

# Install dependencies first (caching)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY --chown=appuser:appgroup . .

# Remove unnecessary packages and clean up
RUN apt-get purge -y --auto-remove \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Use non-root user
USER appuser

# Use unprivileged port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Don't run as PID 1 - use tini or dumb-init
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["python3", "app.py"]
```

### Multi-Stage Builds

```dockerfile
# Build stage
FROM golang:1.21-alpine AS builder

# Install security updates
RUN apk update && apk upgrade

WORKDIR /build

# Copy go mod files first for caching
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build with security flags
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -ldflags="-w -s" -o /app/server ./cmd/server

# Runtime stage - minimal image
FROM gcr.io/distroless/static-debian12:nonroot

# Copy only the binary
COPY --from=builder /app/server /server

# Use non-root user (distroless default)
USER nonroot:nonroot

EXPOSE 8080

ENTRYPOINT ["/server"]
```

### Base Image Selection

```yaml
# Image security hierarchy (most to least secure)
base_images:
  most_secure:
    - name: "scratch"
      description: "Empty image, for statically compiled binaries"
      use_case: "Go, Rust binaries"
      vulnerabilities: "None (no OS)"

    - name: "gcr.io/distroless/*"
      description: "Google's minimal images"
      use_case: "Production workloads"
      vulnerabilities: "Minimal"

    - name: "alpine"
      description: "Minimal Linux with musl libc"
      use_case: "When you need a shell"
      vulnerabilities: "Low"

  moderate:
    - name: "debian-slim"
      description: "Minimal Debian"
      use_case: "When you need glibc"
      vulnerabilities: "Moderate"

    - name: "ubuntu"
      description: "Full Ubuntu"
      use_case: "Development, debugging"
      vulnerabilities: "Higher"

  avoid_in_production:
    - name: "*:latest"
      reason: "Unpredictable, may change"

    - name: "unverified images"
      reason: "May contain malware"
```

## Container Image Scanning

### Trivy Scanner

```yaml
# GitHub Actions with Trivy
name: Container Security Scan
on:
  push:
    branches: [main]
  pull_request:

jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

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
          ignore-unfixed: true

      - name: Upload Trivy scan results
        uses: github/codeql-action/upload-sarif@v2
        if: always()
        with:
          sarif_file: 'trivy-results.sarif'

      - name: Run Trivy in table format
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: 'myapp:${{ github.sha }}'
          format: 'table'
          severity: 'CRITICAL,HIGH,MEDIUM'
```

### Custom Scanning Policy

```yaml
# .trivy.yaml - Custom Trivy configuration
severity:
  - CRITICAL
  - HIGH

exit-code: 1

ignore-unfixed: true

# Ignore specific vulnerabilities
ignorefile: .trivyignore

# Scan configuration
scan:
  security-checks:
    - vuln
    - config
    - secret

# Output format
format: json
output: trivy-report.json
```

```text
# .trivyignore - Ignored vulnerabilities with justification
# CVE-XXXX-YYYY: Accepted risk - not applicable to our use case
CVE-2023-12345

# Temporary ignore until patch available (expires 2024-03-01)
CVE-2023-67890 exp:2024-03-01
```

### Grype Scanner

```bash
# Install Grype
curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin

# Scan an image
grype myapp:latest

# Scan with specific output format
grype myapp:latest -o json > grype-results.json

# Fail on high/critical
grype myapp:latest --fail-on high
```

## Container Runtime Security

### Docker Security Options

```yaml
# docker-compose.yml with security options
version: '3.8'

services:
  app:
    image: myapp:latest
    security_opt:
      - no-new-privileges:true
      - seccomp:./seccomp-profile.json
      - apparmor:docker-default
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE  # Only if needed
    read_only: true
    tmpfs:
      - /tmp
      - /var/run
    user: "1000:1000"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
        reservations:
          cpus: '0.25'
          memory: 256M
```

### Seccomp Profile

```json
{
  "defaultAction": "SCMP_ACT_ERRNO",
  "architectures": [
    "SCMP_ARCH_X86_64",
    "SCMP_ARCH_X86",
    "SCMP_ARCH_AARCH64"
  ],
  "syscalls": [
    {
      "names": [
        "accept",
        "accept4",
        "bind",
        "clone",
        "close",
        "connect",
        "dup",
        "dup2",
        "execve",
        "exit",
        "exit_group",
        "fcntl",
        "fstat",
        "futex",
        "getdents64",
        "getpid",
        "getsockname",
        "getsockopt",
        "listen",
        "lseek",
        "mmap",
        "mprotect",
        "munmap",
        "nanosleep",
        "open",
        "openat",
        "poll",
        "read",
        "recvfrom",
        "recvmsg",
        "rt_sigaction",
        "rt_sigprocmask",
        "rt_sigreturn",
        "sendmsg",
        "sendto",
        "setsockopt",
        "shutdown",
        "socket",
        "stat",
        "write"
      ],
      "action": "SCMP_ACT_ALLOW"
    }
  ]
}
```

### AppArmor Profile

```text
# /etc/apparmor.d/docker-myapp
#include <tunables/global>

profile docker-myapp flags=(attach_disconnected,mediate_deleted) {
  #include <abstractions/base>

  # Deny all network access by default
  deny network,

  # Allow specific network access
  network inet tcp,
  network inet udp,

  # Deny all file access by default, then allow specific
  deny /** w,

  # Allow read access to application files
  /app/** r,
  /app/config/* r,

  # Allow write to tmp
  /tmp/** rw,

  # Allow reading SSL certificates
  /etc/ssl/** r,

  # Deny sensitive file access
  deny /etc/shadow r,
  deny /etc/passwd w,
  deny /root/** rwx,

  # Deny capabilities
  deny capability sys_admin,
  deny capability net_admin,
  deny capability sys_ptrace,
}
```

## Image Signing and Verification

### Cosign for Image Signing

```bash
# Install cosign
curl -sSfL https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64 -o /usr/local/bin/cosign
chmod +x /usr/local/bin/cosign

# Generate key pair
cosign generate-key-pair

# Sign an image
cosign sign --key cosign.key myregistry.com/myapp:v1.0.0

# Verify signature
cosign verify --key cosign.pub myregistry.com/myapp:v1.0.0
```

### Keyless Signing with Sigstore

```yaml
# GitHub Actions with keyless signing
name: Build and Sign
on:
  push:
    tags: ['v*']

jobs:
  build-sign:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
      id-token: write  # Required for keyless signing

    steps:
      - uses: actions/checkout@v4

      - name: Install Cosign
        uses: sigstore/cosign-installer@main

      - name: Login to Registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build and Push
        id: build
        uses: docker/build-push-action@v5
        with:
          push: true
          tags: ghcr.io/${{ github.repository }}:${{ github.ref_name }}

      - name: Sign image with Cosign
        run: |
          cosign sign --yes ghcr.io/${{ github.repository }}@${{ steps.build.outputs.digest }}

      - name: Generate SBOM
        uses: anchore/sbom-action@v0
        with:
          image: ghcr.io/${{ github.repository }}:${{ github.ref_name }}
          format: spdx-json
          output-file: sbom.spdx.json

      - name: Attest SBOM
        run: |
          cosign attest --yes --predicate sbom.spdx.json --type spdxjson \
            ghcr.io/${{ github.repository }}@${{ steps.build.outputs.digest }}
```

### Policy Enforcement with Kyverno

```yaml
# Require signed images
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-image-signature
spec:
  validationFailureAction: Enforce
  background: false
  rules:
    - name: verify-signature
      match:
        any:
          - resources:
              kinds:
                - Pod
      verifyImages:
        - imageReferences:
            - "ghcr.io/myorg/*"
          attestors:
            - entries:
                - keyless:
                    subject: "https://github.com/myorg/*"
                    issuer: "https://token.actions.githubusercontent.com"
                    rekor:
                      url: https://rekor.sigstore.dev

---
# Require vulnerability scan attestation
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-vulnerability-scan
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
            - type: https://cosign.sigstore.dev/attestation/vuln/v1
              conditions:
                - all:
                    - key: "{{ scanner }}"
                      operator: Equals
                      value: "trivy"
                    - key: "{{ critical_count }}"
                      operator: LessThanOrEquals
                      value: "0"
                    - key: "{{ high_count }}"
                      operator: LessThanOrEquals
                      value: "5"
```

## Registry Security

### Private Registry with Authentication

```yaml
# Harbor registry deployment with security
apiVersion: v1
kind: Secret
metadata:
  name: harbor-tls
  namespace: harbor
type: kubernetes.io/tls
data:
  tls.crt: <base64-cert>
  tls.key: <base64-key>

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: harbor-core
  namespace: harbor
spec:
  template:
    spec:
      containers:
        - name: core
          image: goharbor/harbor-core:v2.9.0
          env:
            - name: CONFIG_PATH
              value: /etc/core/app.conf
            - name: CORE_SECRET
              valueFrom:
                secretKeyRef:
                  name: harbor-core-secret
                  key: secret
          securityContext:
            runAsNonRoot: true
            runAsUser: 10000
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop:
                - ALL
```

### Registry Scanning Policy

```yaml
# Harbor vulnerability scanning policy
vulnerability_scanning:
  # Scan on push
  scan_on_push: true

  # Prevent vulnerable images from being pulled
  prevent_vulnerable_images:
    enabled: true
    severity_threshold: "high"  # Block high and critical

  # Scan schedule
  scan_schedule:
    cron: "0 0 * * *"  # Daily scan

  # Allowlist
  allowlist:
    items:
      - cve_id: "CVE-2023-12345"
        expires_at: "2024-03-01"
```

## Container Security Scanning in CI/CD

```yaml
# Complete container security pipeline
name: Container Security Pipeline
on:
  push:
    branches: [main]
  pull_request:

jobs:
  dockerfile-lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Lint Dockerfile
        uses: hadolint/hadolint-action@v3.1.0
        with:
          dockerfile: Dockerfile
          failure-threshold: warning

  build-scan:
    needs: dockerfile-lint
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build image
        run: docker build -t myapp:${{ github.sha }} .

      - name: Scan for vulnerabilities
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: 'myapp:${{ github.sha }}'
          format: 'sarif'
          output: 'trivy-results.sarif'
          severity: 'CRITICAL,HIGH'
          exit-code: '1'

      - name: Scan for secrets
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: 'myapp:${{ github.sha }}'
          scanners: 'secret'
          exit-code: '1'

      - name: Scan for misconfigurations
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: 'myapp:${{ github.sha }}'
          scanners: 'config'
          exit-code: '1'

      - name: Upload scan results
        uses: github/codeql-action/upload-sarif@v2
        if: always()
        with:
          sarif_file: 'trivy-results.sarif'

  sign-push:
    needs: build-scan
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
      id-token: write
    steps:
      - uses: actions/checkout@v4

      - name: Install Cosign
        uses: sigstore/cosign-installer@main

      - name: Login to Registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build and Push
        id: build
        uses: docker/build-push-action@v5
        with:
          push: true
          tags: ghcr.io/${{ github.repository }}:${{ github.sha }}

      - name: Sign image
        run: |
          cosign sign --yes ghcr.io/${{ github.repository }}@${{ steps.build.outputs.digest }}
```

## Summary

Container security requires attention at every stage:

1. **Build Secure Images** - Use minimal base images, non-root users, multi-stage builds
2. **Scan for Vulnerabilities** - Automate scanning with Trivy, Grype, or similar tools
3. **Runtime Security** - Apply seccomp, AppArmor, drop capabilities
4. **Sign and Verify** - Use Cosign/Sigstore for image integrity
5. **Registry Security** - Implement scanning policies and access controls

## Additional Resources

- [Docker Security Best Practices](https://docs.docker.com/develop/security-best-practices/)
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)
- [Sigstore Documentation](https://docs.sigstore.dev/)
- [Trivy Documentation](https://aquasecurity.github.io/trivy/)

## Next Module

Continue to [Module 04: Kubernetes Security](module-04-kubernetes-security.md) to learn about securing Kubernetes clusters.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Secure Container Images
- Container Image Scanning
- Container Runtime Security
- Image Signing and Verification

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"We scan for vulnerabilities in the pipeline."* |
| ✓ | *"SAST reads source without running it, SCA resolves the dependency tree against an advisory database, and image scanning compares installed package versions to that same database. All three report what was known at build time — which is why the registry is re-scanned: the image does not change, the database does."* |

**Trace it:** A CVE published today against your base image → a blocked deploy. Name every component between the advisory and the refused `apply`.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** the [SLSA threat model](https://slsa.dev/spec/v1.2/threats) — it names every point at which a build can be subverted, and most teams defend three of them.
Full list per domain: [`SOURCES.md`](../SOURCES.md#devsecops)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../MASTERY.md)

<!-- /feynman-check -->
