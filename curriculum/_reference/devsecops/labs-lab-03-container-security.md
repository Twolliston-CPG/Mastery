# Lab 3: Container Security

## Objectives

- Build secure container images using best practices
- Scan container images for vulnerabilities
- Sign and verify container images
- Implement runtime security controls

## Prerequisites

- Docker installed
- Access to a container registry
- Trivy and Cosign installed
- Kubernetes cluster access (optional)

## Duration

3 hours

## Lab Environment Setup

```bash
# Create lab directory
mkdir -p ~/security-lab/containers
cd ~/security-lab/containers

# Install required tools
# Trivy
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin

# Cosign
curl -O -L "https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64"
mv cosign-linux-amd64 /usr/local/bin/cosign
chmod +x /usr/local/bin/cosign

# Dive (image analysis)
curl -OL https://github.com/wagoodman/dive/releases/download/v0.12.0/dive_0.12.0_linux_amd64.deb
dpkg -i dive_0.12.0_linux_amd64.deb
```

## Part 1: Secure Dockerfile Practices (45 minutes)

### Task 1.1: Analyze Insecure Dockerfile

Review this intentionally insecure Dockerfile:

```dockerfile
# BAD: insecure.Dockerfile
FROM ubuntu:latest

RUN apt-get update && apt-get install -y \
    nodejs \
    npm \
    curl \
    wget \
    vim \
    telnet

COPY . /app
WORKDIR /app

RUN npm install

# BAD: Running as root
# BAD: Exposing environment variables with secrets
ENV DATABASE_PASSWORD=mysecretpassword
ENV API_KEY=sk-1234567890abcdef

EXPOSE 3000

CMD ["npm", "start"]
```

### Task 1.2: Create Secure Dockerfile

Rewrite the Dockerfile following security best practices:

```dockerfile
# GOOD: secure.Dockerfile

# Use specific version, not latest
FROM node:20.10.0-alpine3.19 AS builder

# Set working directory
WORKDIR /app

# Copy package files first for better caching
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production && \
    npm cache clean --force

# Copy source code
COPY --chown=node:node . .

# Build application
RUN npm run build

# Production stage - use distroless
FROM gcr.io/distroless/nodejs20-debian12:nonroot

# Copy built application
COPY --from=builder /app/dist /app
COPY --from=builder /app/node_modules /app/node_modules

WORKDIR /app

# Use non-root user (65532 is nonroot user in distroless)
USER 65532:65532

# Document exposed port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ["/nodejs/bin/node", "-e", "require('http').get('http://localhost:8080/health')"]

# Start application
CMD ["/app/server.js"]
```

### Task 1.3: Create Multi-Stage Build for Go Application

```dockerfile
# Dockerfile.go-secure

# Build stage
FROM golang:1.21-alpine AS builder

# Install ca-certificates for HTTPS
RUN apk add --no-cache ca-certificates git

# Create non-root user
RUN adduser -D -g '' appuser

WORKDIR /build

# Copy go mod files first
COPY go.mod go.sum ./
RUN go mod download

# Copy source
COPY . .

# Build with security flags
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags='-w -s -extldflags "-static"' \
    -a -installsuffix cgo \
    -o /app/server ./cmd/server

# Final stage - scratch (empty) image
FROM scratch

# Copy ca-certificates
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Copy passwd for non-root user
COPY --from=builder /etc/passwd /etc/passwd

# Copy binary
COPY --from=builder /app/server /server

# Use non-root user
USER appuser

EXPOSE 8080

ENTRYPOINT ["/server"]
```

### Task 1.4: Analyze Image Layers with Dive

```bash
# Build the secure image
docker build -t secure-app:latest -f secure.Dockerfile .

# Analyze layers with Dive
dive secure-app:latest

# Check image efficiency
dive secure-app:latest --ci --lowestEfficiency=0.9
```

## Part 2: Container Image Scanning (45 minutes)

### Task 2.1: Scan with Trivy

```bash
# Scan local image
trivy image secure-app:latest

# Scan with severity filter
trivy image --severity CRITICAL,HIGH secure-app:latest

# Generate JSON report
trivy image --format json --output trivy-report.json secure-app:latest

# Generate SARIF for GitHub Security
trivy image --format sarif --output trivy.sarif secure-app:latest

# Scan filesystem
trivy fs --security-checks vuln,secret,config .

# Scan with ignore file
cat > .trivyignore << EOF
# Ignore specific CVEs
CVE-2023-12345
CVE-2023-67890
EOF

trivy image --ignorefile .trivyignore secure-app:latest
```

### Task 2.2: Scan with Grype

```bash
# Install Grype
curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin

# Scan image
grype secure-app:latest

# Output in JSON
grype secure-app:latest -o json > grype-report.json

# Fail on severity threshold
grype secure-app:latest --fail-on high
```

### Task 2.3: Generate SBOM

```bash
# Generate SBOM with Syft
curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin

# Generate SPDX format
syft secure-app:latest -o spdx-json > sbom.spdx.json

# Generate CycloneDX format
syft secure-app:latest -o cyclonedx-json > sbom.cyclonedx.json

# Scan SBOM for vulnerabilities
grype sbom:sbom.spdx.json
```

### Task 2.4: CI/CD Integration Script

```bash
#!/bin/bash
# scan-image.sh - Container security scanning in CI/CD

set -e

IMAGE_NAME="${1:-app:latest}"
SEVERITY_THRESHOLD="${2:-HIGH}"
EXIT_CODE=0

echo "=== Scanning Container Image: $IMAGE_NAME ==="

# Run Trivy scan
echo "Running Trivy vulnerability scan..."
trivy image \
    --severity CRITICAL,HIGH,MEDIUM \
    --format table \
    --exit-code 0 \
    "$IMAGE_NAME"

# Check for critical vulnerabilities
CRITICAL_COUNT=$(trivy image \
    --severity CRITICAL \
    --format json \
    "$IMAGE_NAME" | jq '[.Results[].Vulnerabilities // [] | length] | add')

if [ "$CRITICAL_COUNT" -gt 0 ]; then
    echo "❌ CRITICAL: $CRITICAL_COUNT critical vulnerabilities found!"
    EXIT_CODE=1
fi

# Run Dockle for best practices
echo "Running Dockle lint..."
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
    goodwithtech/dockle:latest \
    --exit-code 1 \
    --exit-level fatal \
    "$IMAGE_NAME" || EXIT_CODE=1

# Generate SBOM
echo "Generating SBOM..."
syft "$IMAGE_NAME" -o spdx-json > sbom.json

echo "=== Scan Complete ==="
exit $EXIT_CODE
```

## Part 3: Container Image Signing (45 minutes)

### Task 3.1: Generate Cosign Key Pair

```bash
# Generate key pair (will prompt for password)
cosign generate-key-pair

# This creates:
# - cosign.key (private key - keep secure!)
# - cosign.pub (public key - distribute for verification)

# Store private key securely (example: AWS Secrets Manager)
aws secretsmanager create-secret \
    --name cosign-private-key \
    --secret-string file://cosign.key
```

### Task 3.2: Sign Container Images

```bash
# Build and tag image
docker build -t myregistry.com/secure-app:v1.0.0 .

# Push to registry
docker push myregistry.com/secure-app:v1.0.0

# Sign the image
cosign sign --key cosign.key myregistry.com/secure-app:v1.0.0

# Sign with annotations
cosign sign --key cosign.key \
    -a "commit=$(git rev-parse HEAD)" \
    -a "build_date=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    -a "builder=ci-pipeline" \
    myregistry.com/secure-app:v1.0.0
```

### Task 3.3: Verify Container Images

```bash
# Verify signature
cosign verify --key cosign.pub myregistry.com/secure-app:v1.0.0

# Verify with annotations check
cosign verify --key cosign.pub \
    -a "builder=ci-pipeline" \
    myregistry.com/secure-app:v1.0.0

# Verify in CI/CD script
#!/bin/bash
if cosign verify --key cosign.pub "$IMAGE" 2>/dev/null; then
    echo "✅ Image signature verified"
else
    echo "❌ Image signature verification failed!"
    exit 1
fi
```

### Task 3.4: Keyless Signing with Sigstore

```bash
# Sign with OIDC (GitHub Actions, Google, etc.)
cosign sign --identity-token=$(cat $ACTIONS_ID_TOKEN_REQUEST_TOKEN) \
    myregistry.com/secure-app:v1.0.0

# Verify keyless signature
cosign verify \
    --certificate-identity="https://github.com/myorg/myrepo/.github/workflows/build.yml@refs/heads/main" \
    --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
    myregistry.com/secure-app:v1.0.0
```

## Part 4: Runtime Security (45 minutes)

### Task 4.1: Create Seccomp Profile

```json
{
    "defaultAction": "SCMP_ACT_ERRNO",
    "architectures": [
        "SCMP_ARCH_X86_64"
    ],
    "syscalls": [
        {
            "names": [
                "read", "write", "close", "fstat", "lseek",
                "mmap", "mprotect", "munmap", "brk",
                "access", "pipe", "select", "sched_yield",
                "dup", "dup2", "nanosleep", "getpid",
                "socket", "connect", "accept", "sendto",
                "recvfrom", "bind", "listen", "getsockname",
                "getpeername", "socketpair", "setsockopt",
                "getsockopt", "clone", "fork", "vfork",
                "execve", "exit", "wait4", "kill",
                "uname", "fcntl", "flock", "fsync",
                "fdatasync", "truncate", "ftruncate",
                "getcwd", "chdir", "rename", "mkdir",
                "rmdir", "link", "unlink", "symlink",
                "readlink", "chmod", "fchmod", "chown",
                "fchown", "lchown", "umask", "gettimeofday",
                "getrlimit", "getrusage", "sysinfo", "times",
                "getuid", "getgid", "setuid", "setgid",
                "geteuid", "getegid", "setpgid", "getppid",
                "getpgrp", "setsid", "setreuid", "setregid",
                "getgroups", "setgroups", "setresuid",
                "getresuid", "setresgid", "getresgid",
                "sigaltstack", "rt_sigaction", "rt_sigprocmask",
                "rt_sigreturn", "ioctl", "pread64", "pwrite64",
                "readv", "writev", "poll", "epoll_create",
                "epoll_ctl", "epoll_wait", "epoll_create1",
                "epoll_pwait", "eventfd", "eventfd2",
                "futex", "set_robust_list", "get_robust_list",
                "clock_gettime", "clock_getres", "exit_group",
                "tgkill", "openat", "mkdirat", "newfstatat",
                "unlinkat", "renameat", "faccessat", "pselect6",
                "ppoll", "set_tid_address", "arch_prctl",
                "getrandom", "statx", "rseq"
            ],
            "action": "SCMP_ACT_ALLOW"
        }
    ]
}
```

### Task 4.2: Run Container with Security Options

```bash
# Run with seccomp profile
docker run --rm \
    --security-opt seccomp=seccomp-profile.json \
    secure-app:latest

# Run with AppArmor
docker run --rm \
    --security-opt apparmor=docker-default \
    secure-app:latest

# Run with all security options
docker run --rm \
    --security-opt no-new-privileges:true \
    --security-opt seccomp=seccomp-profile.json \
    --cap-drop ALL \
    --cap-add NET_BIND_SERVICE \
    --read-only \
    --tmpfs /tmp:rw,noexec,nosuid \
    --user 1000:1000 \
    secure-app:latest
```

### Task 4.3: Kubernetes Security Context

```yaml
# k8s/secure-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secure-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: secure-app
  template:
    metadata:
      labels:
        app: secure-app
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 65532
        runAsGroup: 65532
        fsGroup: 65532
        seccompProfile:
          type: RuntimeDefault

      containers:
      - name: app
        image: myregistry.com/secure-app:v1.0.0
        imagePullPolicy: Always

        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
              - ALL

        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"

        volumeMounts:
        - name: tmp
          mountPath: /tmp

      volumes:
      - name: tmp
        emptyDir: {}

      automountServiceAccountToken: false
```

### Task 4.4: Kyverno Policy for Container Security

```yaml
# kyverno/require-security-context.yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-security-context
spec:
  validationFailureAction: Enforce
  background: true
  rules:
  - name: require-run-as-non-root
    match:
      any:
      - resources:
          kinds:
          - Pod
    validate:
      message: "Running as root is not allowed"
      pattern:
        spec:
          securityContext:
            runAsNonRoot: true
          containers:
          - securityContext:
              runAsNonRoot: true
              allowPrivilegeEscalation: false

  - name: drop-all-capabilities
    match:
      any:
      - resources:
          kinds:
          - Pod
    validate:
      message: "Containers must drop all capabilities"
      pattern:
        spec:
          containers:
          - securityContext:
              capabilities:
                drop:
                - ALL

  - name: require-read-only-root
    match:
      any:
      - resources:
          kinds:
          - Pod
    validate:
      message: "Root filesystem must be read-only"
      pattern:
        spec:
          containers:
          - securityContext:
              readOnlyRootFilesystem: true
```

## Verification

Complete the following checklist:

- [ ] Created secure Dockerfile with multi-stage build
- [ ] Built image with non-root user
- [ ] Scanned image with Trivy (0 critical vulnerabilities)
- [ ] Scanned image with Grype
- [ ] Generated SBOM in SPDX format
- [ ] Signed image with Cosign
- [ ] Verified image signature
- [ ] Created and applied seccomp profile
- [ ] Deployed to Kubernetes with security context
- [ ] Applied Kyverno policies

## Challenge Tasks

1. **Custom Seccomp Profile**: Create a minimal seccomp profile by tracing system calls with `strace`

2. **Vulnerability Auto-Remediation**: Create a script that automatically rebuilds images when base image vulnerabilities are detected

3. **Supply Chain Security**: Implement SLSA Level 2 provenance attestations with Cosign

## Summary

In this lab, you:
- Built secure container images using best practices
- Scanned images for vulnerabilities with multiple tools
- Generated Software Bills of Materials (SBOMs)
- Signed and verified container images
- Implemented runtime security controls
- Created Kubernetes security contexts and admission policies

## Next Steps

- Lab 4: Kubernetes Security
- Review Docker Security Best Practices
- Study NIST Container Security Guide

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Secure Dockerfile Practices
- Container Image Scanning
- Container Image Signing
- Runtime Security

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
