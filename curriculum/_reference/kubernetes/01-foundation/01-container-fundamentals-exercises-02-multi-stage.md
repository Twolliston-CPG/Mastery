# Exercise 2: Multi-Stage Build

## Objective

Convert a single-stage Dockerfile to a multi-stage build to dramatically reduce image size and remove build-time dependencies from the production image.

## Prerequisites

- Completed Exercise 1
- Understanding of build vs runtime dependencies
- Docker BuildKit enabled

## Scenario

You have a Go application that compiles to a static binary. The current Dockerfile produces a 1.2GB image because it includes the entire Go toolchain. Your task is to use multi-stage builds to reduce the image to under 20MB.

## Starter Application

Create the following files in a new directory called `go-api`:

### main.go
```go
package main

import (
    "encoding/json"
    "log"
    "net/http"
    "os"
    "runtime"
    "time"
)

var (
    version   = "1.0.0"
    buildTime = "unknown"
    gitCommit = "unknown"
)

type HealthResponse struct {
    Status    string `json:"status"`
    Timestamp string `json:"timestamp"`
}

type InfoResponse struct {
    Service   string `json:"service"`
    Version   string `json:"version"`
    BuildTime string `json:"build_time"`
    GitCommit string `json:"git_commit"`
    GoVersion string `json:"go_version"`
    OS        string `json:"os"`
    Arch      string `json:"arch"`
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
    response := HealthResponse{
        Status:    "healthy",
        Timestamp: time.Now().UTC().Format(time.RFC3339),
    }
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(response)
}

func infoHandler(w http.ResponseWriter, r *http.Request) {
    response := InfoResponse{
        Service:   "go-api",
        Version:   version,
        BuildTime: buildTime,
        GitCommit: gitCommit,
        GoVersion: runtime.Version(),
        OS:        runtime.GOOS,
        Arch:      runtime.GOARCH,
    }
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(response)
}

func main() {
    port := os.Getenv("PORT")
    if port == "" {
        port = "8080"
    }

    http.HandleFunc("/health", healthHandler)
    http.HandleFunc("/api/info", infoHandler)

    log.Printf("Starting server on port %s", port)
    log.Fatal(http.ListenAndServe(":"+port, nil))
}
```

### go.mod
```go
module go-api

go 1.21
```

### Bad Dockerfile (single-stage)
```dockerfile
# Dockerfile.bad - DO NOT USE IN PRODUCTION
FROM golang:1.21

WORKDIR /app
COPY . .
RUN go build -o server .

EXPOSE 8080
CMD ["./server"]
```

## Tasks

### Task 1: Analyze the Problem

Build the bad Dockerfile and measure its size:

```bash
docker build -f Dockerfile.bad -t go-api:bad .
docker images go-api:bad
```

Expected: ~1.2GB image containing the entire Go toolchain.

### Task 2: Create a Two-Stage Dockerfile

Create a multi-stage Dockerfile with:
1. **Build stage**: Use `golang:1.21-alpine` to compile the application
2. **Runtime stage**: Use `alpine:3.19` as the minimal base

Requirements for build stage:
- Install git and ca-certificates
- Copy go.mod first for better caching
- Build with optimizations: `-ldflags="-w -s"`

Requirements for runtime stage:
- Copy only the binary from the build stage
- Copy CA certificates for HTTPS
- Run as non-root user
- Add health check

### Task 3: Use Distroless Base

Modify your Dockerfile to use `gcr.io/distroless/static-debian12` instead of Alpine for the runtime stage.

Benefits:
- No shell (reduced attack surface)
- No package manager
- Smaller image
- Better security scanning results

### Task 4: Add Build-Time Variables

Inject build-time information using `--build-arg` and `-ldflags`:
- Version number
- Build timestamp
- Git commit hash

```bash
docker build \
  --build-arg VERSION=1.0.0 \
  --build-arg BUILD_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
  --build-arg GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown") \
  -t go-api:1.0.0 .
```

### Task 5: Optimize for Caching

Ensure your Dockerfile:
1. Downloads dependencies in a separate step
2. Only rebuilds when source code changes
3. Uses `--mount=type=cache` for Go module cache (BuildKit)

## Validation

```bash
# Build multi-stage image
docker build -t go-api:multi .

# Compare sizes
docker images | grep go-api

# Expected output:
# go-api    bad      1.2GB
# go-api    multi    ~15-20MB (Alpine)
# go-api    multi    ~7-10MB (Distroless)

# Run and test
docker run -d --name go-test -p 8080:8080 go-api:multi
curl http://localhost:8080/health
curl http://localhost:8080/api/info

# Verify build info is injected
curl http://localhost:8080/api/info | jq '.build_time, .git_commit'

# Cleanup
docker rm -f go-test
```

## Success Criteria

- [ ] Multi-stage build works correctly
- [ ] Final image is under 20MB
- [ ] Build information is properly injected
- [ ] Health endpoint responds
- [ ] No shell access in distroless version

## Solution

<details>
<summary>Click to reveal solution (Alpine)</summary>

```dockerfile
# Dockerfile.alpine

# ============ Build Stage ============
FROM golang:1.21-alpine AS builder

# Install git for version info and ca-certificates
RUN apk add --no-cache git ca-certificates

WORKDIR /build

# Copy go mod files first for better caching
COPY go.mod go.sum* ./
RUN go mod download

# Copy source code
COPY . .

# Build arguments for version info
ARG VERSION=dev
ARG BUILD_TIME=unknown
ARG GIT_COMMIT=unknown

# Build with optimizations and version info
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-w -s -X main.version=${VERSION} -X main.buildTime=${BUILD_TIME} -X main.gitCommit=${GIT_COMMIT}" \
    -o /app ./...

# ============ Runtime Stage ============
FROM alpine:3.19

# Install ca-certificates for HTTPS
RUN apk add --no-cache ca-certificates && \
    addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup

WORKDIR /app

# Copy binary from builder
COPY --from=builder /app .

# Use non-root user
USER appuser

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

ENTRYPOINT ["./app"]
```

</details>

<details>
<summary>Click to reveal solution (Distroless)</summary>

```dockerfile
# Dockerfile.distroless

# ============ Build Stage ============
FROM golang:1.21-alpine AS builder

RUN apk add --no-cache git ca-certificates tzdata

WORKDIR /build

COPY go.mod go.sum* ./
RUN go mod download

COPY . .

ARG VERSION=dev
ARG BUILD_TIME=unknown
ARG GIT_COMMIT=unknown

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-w -s -X main.version=${VERSION} -X main.buildTime=${BUILD_TIME} -X main.gitCommit=${GIT_COMMIT}" \
    -o /app ./...

# ============ Runtime Stage ============
FROM gcr.io/distroless/static-debian12

# Copy timezone data for time operations
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo
# Copy CA certificates
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
# Copy the binary
COPY --from=builder /app /app

# Run as non-root (distroless includes nonroot user)
USER nonroot:nonroot

EXPOSE 8080

ENTRYPOINT ["/app"]
```

</details>

<details>
<summary>Click to reveal solution (With BuildKit caching)</summary>

```dockerfile
# Dockerfile.buildkit
# syntax=docker/dockerfile:1.4

FROM golang:1.21-alpine AS builder

RUN apk add --no-cache git ca-certificates

WORKDIR /build

COPY go.mod go.sum* ./

# Use BuildKit cache mount for Go modules
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download

COPY . .

ARG VERSION=dev
ARG BUILD_TIME=unknown
ARG GIT_COMMIT=unknown

RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-w -s -X main.version=${VERSION} -X main.buildTime=${BUILD_TIME} -X main.gitCommit=${GIT_COMMIT}" \
    -o /app ./...

FROM gcr.io/distroless/static-debian12

COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /app /app

USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/app"]
```

Build with: `DOCKER_BUILDKIT=1 docker build -f Dockerfile.buildkit -t go-api:buildkit .`

</details>

## Bonus Challenges

1. **Multi-architecture build**: Build for both `linux/amd64` and `linux/arm64`
2. **Scratch base**: Try using `FROM scratch` (requires static binary + CA certs)
3. **Debug image**: Create a variant with shell for debugging

## Next Exercise

Continue to [Exercise 3: Security Scanning](01-container-fundamentals-exercises-03-security-scanning.md) to learn how to scan your images for vulnerabilities.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Starter Application
- main.go
- go.mod
- Bad Dockerfile (single-stage)

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
