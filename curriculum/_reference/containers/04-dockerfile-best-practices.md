# Dockerfile Best Practices

## Introduction

Writing efficient, secure, and maintainable Dockerfiles is crucial for production-ready container deployments. This module covers best practices for creating optimized Docker images.

## Dockerfile Instruction Reference

### Instruction Overview

**Dockerfile Instructions**

**Build-time Instructions:**

| Item | What it is |
|---|---|
| FROM | - Base image |
| ARG | - Build-time variables |
| RUN | - Execute commands |
| COPY | - Copy files from context |
| ADD | - Copy with extraction/URL support |
| WORKDIR | - Set working directory |
| ENV | - Environment variables |
| EXPOSE | - Document ports |
| USER | - Set user/group |
| VOLUME | - Define mount points |
| CMD | - Default command |
| ENTRYPOINT | - Container executable |
| HEALTHCHECK - Container health check |  |
| LABEL | - Image metadata |
| MAINTAINER | - Author (deprecated) |
| ONBUILD | - Trigger for child images |


### Instruction Details

```dockerfile
# FROM - Base image (required first instruction)
FROM ubuntu:22.04
FROM node:18-alpine AS builder
FROM scratch  # Empty base image

# ARG - Build-time variables (before FROM for base image)
ARG BASE_IMAGE=node:18-alpine
FROM ${BASE_IMAGE}

# ARG - Build-time variables (after FROM for build process)
ARG APP_VERSION=1.0.0
ARG BUILD_DATE

# ENV - Runtime environment variables
ENV NODE_ENV=production
ENV APP_HOME=/app \
    PORT=3000

# WORKDIR - Set working directory (creates if not exists)
WORKDIR /app
WORKDIR $APP_HOME

# COPY - Copy files from build context
COPY package*.json ./
COPY --chown=node:node . .
COPY --from=builder /app/dist ./dist

# ADD - Copy with extra features (prefer COPY)
ADD https://example.com/file.tar.gz /tmp/
ADD archive.tar.gz /app/  # Auto-extracts

# RUN - Execute commands during build
RUN apt-get update && apt-get install -y curl
RUN --mount=type=cache,target=/root/.npm npm install
RUN --mount=type=secret,id=api_key cat /run/secrets/api_key

# EXPOSE - Document ports (doesn't publish)
EXPOSE 3000
EXPOSE 3000/tcp 3000/udp

# USER - Set user for subsequent instructions
USER node
USER 1000:1000

# VOLUME - Create mount point
VOLUME /data
VOLUME ["/data", "/logs"]

# ENTRYPOINT - Container executable
ENTRYPOINT ["node"]
ENTRYPOINT ["./docker-entrypoint.sh"]

# CMD - Default arguments to ENTRYPOINT
CMD ["server.js"]
CMD ["--port", "3000"]

# HEALTHCHECK - Container health monitoring
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

# LABEL - Image metadata
LABEL org.opencontainers.image.title="My App"
LABEL org.opencontainers.image.version="${APP_VERSION}"
LABEL org.opencontainers.image.created="${BUILD_DATE}"

# STOPSIGNAL - Signal to stop container
STOPSIGNAL SIGTERM

# SHELL - Default shell for RUN
SHELL ["/bin/bash", "-c"]
```

## Layer Optimization

### Understanding Layers

**Which instructions create a layer**

| Creates a layer | Metadata only |
|---|---|
| `FROM` — the base layer | `ENV` |
| `RUN` — the command's output | `EXPOSE` |
| `COPY` — the copied files | `LABEL` |
| `ADD` — the added files | `USER` |
| | `WORKDIR` |
| | `ARG` (build-time only) |
| | `CMD` |
| | `ENTRYPOINT` |

Only the left column costs you image size and cache invalidation.

### Minimizing Layers

```dockerfile
# Bad: Multiple RUN instructions (multiple layers)
FROM ubuntu:22.04
RUN apt-get update
RUN apt-get install -y curl
RUN apt-get install -y wget
RUN apt-get install -y vim
RUN apt-get clean
RUN rm -rf /var/lib/apt/lists/*

# Good: Single RUN instruction (single layer)
FROM ubuntu:22.04
RUN apt-get update && \
    apt-get install -y \
        curl \
        wget \
        vim && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
```

### Ordering for Cache Efficiency

```dockerfile
# Bad: Code changes invalidate npm install cache
FROM node:18-alpine
WORKDIR /app
COPY . .
RUN npm install
CMD ["node", "server.js"]

# Good: Dependencies cached separately from code
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
CMD ["node", "server.js"]
```

**Why dependency-first ordering matters**

| Step | dependency changed | code changed only |
|---|---|---|
| `FROM node:18-alpine` | cache | cache |
| `COPY package*.json ./` | **rebuild** | cache |
| `RUN npm ci` | **rebuild** | **cache** ← the win |
| `COPY . .` | **rebuild** | rebuild |

The third row is the point. With `COPY . .` above `npm ci`, every code change
reinstalls every dependency.

## Multi-Stage Builds

### Basic Multi-Stage

```dockerfile
# Stage 1: Build
FROM node:18 AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Stage 2: Production
FROM node:18-alpine AS production
WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY package*.json ./
USER node
EXPOSE 3000
CMD ["node", "dist/server.js"]
```

### Advanced Multi-Stage Patterns

```dockerfile
# Pattern 1: Separate test stage
FROM node:18 AS base
WORKDIR /app
COPY package*.json ./
RUN npm ci

FROM base AS test
COPY . .
RUN npm run lint && npm run test

FROM base AS builder
COPY . .
RUN npm run build

FROM node:18-alpine AS production
WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
USER node
CMD ["node", "dist/server.js"]
```

```dockerfile
# Pattern 2: Development and production from same Dockerfile
FROM node:18 AS base
WORKDIR /app
COPY package*.json ./

FROM base AS development
RUN npm install
COPY . .
CMD ["npm", "run", "dev"]

FROM base AS builder
RUN npm ci
COPY . .
RUN npm run build

FROM node:18-alpine AS production
WORKDIR /app
RUN addgroup -g 1001 appgroup && \
    adduser -u 1001 -G appgroup -D appuser
COPY --from=builder --chown=appuser:appgroup /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
USER appuser
EXPOSE 3000
CMD ["node", "dist/server.js"]
```

```dockerfile
# Pattern 3: Multi-architecture builds
FROM --platform=$BUILDPLATFORM node:18 AS builder
ARG TARGETPLATFORM
ARG BUILDPLATFORM
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:18-alpine
WORKDIR /app
COPY --from=builder /app/dist ./dist
CMD ["node", "dist/server.js"]
```

```bash
# Build for multiple architectures
docker buildx build --platform linux/amd64,linux/arm64 -t myapp:multi .
```

### Static Binary Builds

```dockerfile
# Go application with scratch base
FROM golang:1.21 AS builder
WORKDIR /app
COPY go.* ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main .

FROM scratch
COPY --from=builder /app/main /main
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
ENTRYPOINT ["/main"]
```

```dockerfile
# Rust application
FROM rust:1.70 AS builder
WORKDIR /app
COPY Cargo.* ./
RUN mkdir src && echo "fn main() {}" > src/main.rs
RUN cargo build --release
COPY src ./src
RUN touch src/main.rs && cargo build --release

FROM debian:bookworm-slim
COPY --from=builder /app/target/release/myapp /usr/local/bin/
CMD ["myapp"]
```

## Image Size Optimization

### Choosing Base Images

| Base Image Comparison |  |  |
|---|---|---|
| Image | Size | Use Case |
| ubuntu:22.04 | ~77MB | General purpose |
| debian:bookworm-slim | ~50MB | Smaller Debian |
| alpine:3.18 | ~5MB | Minimal Linux |
| distroless/static | ~2MB | Static binaries |
| scratch | 0MB | Bare minimum |
| node:18 | ~1GB | Full Node.js |
| node:18-slim | ~200MB | Slimmer Node.js |
| node:18-alpine | ~170MB | Alpine-based Node.js |
| python:3.11 | ~1GB | Full Python |
| python:3.11-slim | ~150MB | Slimmer Python |
| python:3.11-alpine | ~50MB | Alpine-based Python |


### Alpine Considerations

```dockerfile
# Alpine uses musl libc instead of glibc
# Some packages may have compatibility issues

# If you encounter issues, try:
FROM python:3.11-slim-bookworm

# Or install glibc compatibility layer in Alpine
FROM alpine:3.18
RUN apk add --no-cache libc6-compat
```

### Removing Unnecessary Files

```dockerfile
FROM ubuntu:22.04

# Bad: Package cache remains
RUN apt-get update
RUN apt-get install -y curl

# Good: Clean up in same layer
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
```

```dockerfile
FROM python:3.11-slim

# Install with cleanup
RUN pip install --no-cache-dir -r requirements.txt

# Remove unnecessary files
RUN find /usr/local -type d -name __pycache__ -exec rm -rf {} + && \
    find /usr/local -type f -name '*.pyc' -delete
```

### Using .dockerignore

```
# .dockerignore
# Version control
.git
.gitignore
.svn

# Build outputs
node_modules
dist
build
*.egg-info
__pycache__

# Development files
*.md
!README.md
.env
.env.*
docker-compose*.yml
Dockerfile*

# IDE and editor
.idea
.vscode
*.swp
*.swo
*~

# Testing
coverage
.coverage
.pytest_cache
.nyc_output
tests
__tests__

# Documentation
docs
*.pdf

# OS files
.DS_Store
Thumbs.db

# Logs
*.log
logs
```

## Security Best Practices

### Running as Non-Root

```dockerfile
# Pattern 1: Use existing user
FROM node:18-alpine
WORKDIR /app
COPY --chown=node:node . .
USER node
CMD ["node", "server.js"]

# Pattern 2: Create specific user
FROM ubuntu:22.04
RUN groupadd -r appgroup && useradd -r -g appgroup appuser
WORKDIR /app
COPY --chown=appuser:appgroup . .
USER appuser
CMD ["./app"]

# Pattern 3: Alpine user creation
FROM alpine:3.18
RUN addgroup -g 1001 appgroup && \
    adduser -u 1001 -G appgroup -D appuser
WORKDIR /app
COPY --chown=appuser:appgroup . .
USER appuser
```

### Handling Secrets

```dockerfile
# Bad: Secrets in environment or layers
ENV API_KEY=secret123
RUN curl -H "Authorization: $API_KEY" https://api.example.com

# Good: Build-time secrets (BuildKit)
# syntax=docker/dockerfile:1.4
FROM alpine:3.18
RUN --mount=type=secret,id=api_key \
    export API_KEY=$(cat /run/secrets/api_key) && \
    curl -H "Authorization: $API_KEY" https://api.example.com/setup
```

```bash
# Build with secrets
docker build --secret id=api_key,src=./api_key.txt -t myapp .
```

### Using Specific Image Tags

```dockerfile
# Bad: Mutable tag
FROM node:latest

# Bad: Major version only
FROM node:18

# Good: Specific version
FROM node:18.17.1-alpine3.18

# Best: SHA256 digest (immutable)
FROM node@sha256:abc123def456...
```

### Minimizing Attack Surface

```dockerfile
FROM node:18-alpine

# Remove unnecessary packages
RUN apk del --no-cache \
    apk-tools \
    alpine-keys

# Drop all capabilities
# (runtime: docker run --cap-drop=ALL)

# Read-only root filesystem
# (runtime: docker run --read-only)

# No new privileges
# (runtime: docker run --security-opt=no-new-privileges)
```

### Vulnerability Scanning

```dockerfile
# Add scanning in CI/CD
# Dockerfile.scan
FROM myapp:latest
RUN apk add --no-cache trivy && \
    trivy filesystem --exit-code 1 --severity HIGH,CRITICAL /
```

```bash
# Scan during build
docker build -t myapp .
trivy image myapp:latest

# Scan with Docker Scout
docker scout cves myapp:latest
```

## ENTRYPOINT vs CMD

### Understanding the Difference

**`ENTRYPOINT` vs `CMD`**

`ENTRYPOINT` is the executable. `CMD` is the default arguments to it.

| Dockerfile | `docker run myapp arg1` runs |
|---|---|
| `CMD ["echo","hello"]` | `arg1` — CMD is **replaced entirely** |
| `ENTRYPOINT ["echo"]` | `echo arg1` — the argument is appended |
| Both | `echo arg1` — CMD is replaced, ENTRYPOINT stays |

Always use the exec (JSON array) form. The shell form wraps the command in
`/bin/sh -c`, so the shell becomes PID 1, your process never receives SIGTERM,
and graceful shutdown silently stops working.

### Common Patterns

```dockerfile
# Pattern 1: CMD only (most flexible)
FROM nginx:alpine
CMD ["nginx", "-g", "daemon off;"]
# Override: docker run myimage custom-command

# Pattern 2: ENTRYPOINT only (fixed executable)
FROM python:3.11-alpine
ENTRYPOINT ["python"]
# Run: docker run myimage script.py

# Pattern 3: ENTRYPOINT + CMD (recommended)
FROM node:18-alpine
ENTRYPOINT ["node"]
CMD ["server.js"]
# Default: docker run myimage → node server.js
# Override: docker run myimage other.js → node other.js
```

### Entrypoint Scripts

```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh
COPY . .
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["node", "server.js"]
```

```bash
#!/bin/sh
# docker-entrypoint.sh
set -e

# Wait for dependencies
if [ -n "$DATABASE_HOST" ]; then
    echo "Waiting for database..."
    while ! nc -z "$DATABASE_HOST" "${DATABASE_PORT:-5432}"; do
        sleep 1
    done
    echo "Database is ready!"
fi

# Run migrations
if [ "$RUN_MIGRATIONS" = "true" ]; then
    echo "Running migrations..."
    npm run migrate
fi

# Execute CMD
exec "$@"
```

## Health Checks

### HEALTHCHECK Instruction

```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY . .

# Basic health check
HEALTHCHECK CMD curl -f http://localhost:3000/health || exit 1

# With options
HEALTHCHECK --interval=30s \
            --timeout=3s \
            --start-period=5s \
            --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

CMD ["node", "server.js"]
```

### Custom Health Check Scripts

```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY healthcheck.js ./
COPY . .

HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
  CMD node healthcheck.js

CMD ["node", "server.js"]
```

```javascript
// healthcheck.js
const http = require('http');

const options = {
  hostname: 'localhost',
  port: process.env.PORT || 3000,
  path: '/health',
  method: 'GET',
  timeout: 5000
};

const req = http.request(options, (res) => {
  process.exit(res.statusCode === 200 ? 0 : 1);
});

req.on('error', () => process.exit(1));
req.on('timeout', () => {
  req.destroy();
  process.exit(1);
});

req.end();
```

## BuildKit Features

### Enabling BuildKit

```bash
# Enable BuildKit
export DOCKER_BUILDKIT=1

# Or in daemon.json
{
  "features": {
    "buildkit": true
  }
}
```

### BuildKit Syntax

```dockerfile
# Enable BuildKit features
# syntax=docker/dockerfile:1.4

FROM node:18-alpine
WORKDIR /app

# Cache mounts (persist between builds)
RUN --mount=type=cache,target=/root/.npm \
    npm ci

# Secret mounts (not stored in layers)
RUN --mount=type=secret,id=npmrc,target=/root/.npmrc \
    npm ci

# SSH mounts (for private repos)
RUN --mount=type=ssh \
    git clone git@github.com:private/repo.git

# Bind mounts (from build context)
RUN --mount=type=bind,source=package.json,target=/tmp/package.json \
    cat /tmp/package.json
```

### Build Cache

```dockerfile
# syntax=docker/dockerfile:1.4
FROM python:3.11-slim

WORKDIR /app

# Cache pip downloads
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --upgrade pip

COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt

COPY . .
CMD ["python", "app.py"]
```

```bash
# Export/import build cache
docker buildx build --cache-to=type=local,dest=./cache .
docker buildx build --cache-from=type=local,src=./cache .

# Registry cache
docker buildx build \
  --cache-to=type=registry,ref=myregistry.com/myapp:cache \
  --cache-from=type=registry,ref=myregistry.com/myapp:cache \
  -t myapp .
```

## Labels and Metadata

### OCI Image Spec Labels

```dockerfile
FROM node:18-alpine

# OCI Image Spec labels
LABEL org.opencontainers.image.title="My Application"
LABEL org.opencontainers.image.description="A sample application"
LABEL org.opencontainers.image.version="1.0.0"
LABEL org.opencontainers.image.vendor="My Company"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.source="https://github.com/myorg/myapp"
LABEL org.opencontainers.image.documentation="https://docs.myapp.com"
LABEL org.opencontainers.image.authors="team@example.com"

# Build-time labels (pass via --build-arg)
ARG BUILD_DATE
ARG VCS_REF
ARG VERSION

LABEL org.opencontainers.image.created="${BUILD_DATE}"
LABEL org.opencontainers.image.revision="${VCS_REF}"
LABEL org.opencontainers.image.version="${VERSION}"
```

```bash
# Build with labels
docker build \
  --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
  --build-arg VCS_REF=$(git rev-parse --short HEAD) \
  --build-arg VERSION=$(git describe --tags) \
  -t myapp .
```

## Complete Examples

### Node.js Application

```dockerfile
# syntax=docker/dockerfile:1.4
FROM node:18-alpine AS base
WORKDIR /app
RUN apk add --no-cache tini

FROM base AS dependencies
COPY package*.json ./
RUN --mount=type=cache,target=/root/.npm \
    npm ci --only=production && \
    cp -R node_modules /tmp/prod_modules && \
    npm ci

FROM base AS builder
COPY --from=dependencies /app/node_modules ./node_modules
COPY . .
RUN npm run build && npm run test

FROM base AS production
ENV NODE_ENV=production
RUN addgroup -g 1001 nodejs && \
    adduser -u 1001 -G nodejs -D nodejs
COPY --from=dependencies /tmp/prod_modules ./node_modules
COPY --from=builder --chown=nodejs:nodejs /app/dist ./dist
COPY --chown=nodejs:nodejs package*.json ./
USER nodejs
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "dist/server.js"]
```

### Python Application

```dockerfile
# syntax=docker/dockerfile:1.4
FROM python:3.11-slim AS base
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

FROM base AS builder
WORKDIR /app
RUN pip install poetry && \
    poetry config virtualenvs.in-project true
COPY pyproject.toml poetry.lock ./
RUN --mount=type=cache,target=/root/.cache/pypoetry \
    poetry install --no-dev --no-root

FROM base AS production
WORKDIR /app
RUN groupadd -r appgroup && useradd -r -g appgroup appuser
COPY --from=builder /app/.venv ./.venv
COPY --chown=appuser:appgroup . .
ENV PATH="/app/.venv/bin:$PATH"
USER appuser
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')"
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "app:app"]
```

### Go Application

```dockerfile
# syntax=docker/dockerfile:1.4
FROM golang:1.21-alpine AS builder
WORKDIR /app
RUN apk add --no-cache git ca-certificates tzdata
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download
COPY . .
RUN --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=linux go build \
    -ldflags="-w -s -X main.version=${VERSION}" \
    -o /app/main .

FROM scratch AS production
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=builder /app/main /main
EXPOSE 8080
ENTRYPOINT ["/main"]
```

## Summary

Key best practices:

1. **Layer Optimization**
   - Minimize number of layers
   - Order instructions by change frequency
   - Leverage build cache

2. **Size Optimization**
   - Use appropriate base images
   - Multi-stage builds
   - Remove unnecessary files

3. **Security**
   - Run as non-root
   - Use specific image tags
   - Handle secrets properly
   - Scan for vulnerabilities

4. **Maintainability**
   - Use meaningful labels
   - Document with comments
   - Follow consistent patterns

## Practice Exercises

1. Optimize an existing Dockerfile for size
2. Implement multi-stage build
3. Add health checks and proper signal handling
4. Set up vulnerability scanning in CI/CD

## Next Module

Continue to [Container Networking](./05-container-networking.md) to learn about Docker network configurations.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Dockerfile Instruction Reference
- Layer Optimization
- Multi-Stage Builds
- Image Size Optimization

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"A container isolates the application."* |
| ✓ | *"A container is an ordinary Linux process started with namespaces (what it can see), cgroups (what it can use) and usually seccomp (what it may ask the kernel). There is no container object in the kernel — only a process with those features switched on."* |

**Trace it:** `docker run` → an isolated process. Name the namespaces in the order they are created, and which component actually calls `clone()`.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** the [LWN namespaces series](https://lwn.net/Articles/531114/) — seven parts by the man-pages maintainer, and the reason containers stop being magic.
Full list per domain: [`SOURCES.md`](../SOURCES.md#containers)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../MASTERY.md)

<!-- /feynman-check -->
