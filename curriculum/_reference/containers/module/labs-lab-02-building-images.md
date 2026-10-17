# Lab 3.2: Building Container Images

> **Duration:** 90-120 minutes
> **Environment:** Docker with BuildKit enabled
> **Difficulty:** Intermediate

---

## Objectives

- Write production-ready Dockerfiles
- Implement multi-stage builds
- Optimize image size and build time
- Use .dockerignore effectively
- Understand layer caching

---

## Part 1: Dockerfile Basics

### Exercise 1.1: Simple Dockerfile

```bash
mkdir -p ~/docker-lab/basic-app
cd ~/docker-lab/basic-app

# Create a simple Python app
cat > app.py << 'EOF'
from http.server import HTTPServer, SimpleHTTPRequestHandler
import json

class Handler(SimpleHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        response = {"message": "Hello from Docker!", "version": "1.0.0"}
        self.wfile.write(json.dumps(response).encode())

if __name__ == '__main__':
    server = HTTPServer(('0.0.0.0', 8080), Handler)
    print("Server running on port 8080...")
    server.serve_forever()
EOF

# Create Dockerfile
cat > Dockerfile << 'EOF'
# Base image
FROM python:3.12-slim

# Set working directory
WORKDIR /app

# Copy application
COPY app.py .

# Expose port (documentation)
EXPOSE 8080

# Run the application
CMD ["python", "app.py"]
EOF

# Build the image
docker build -t basic-app:v1 .

# Run and test
docker run -d --name basic -p 8080:8080 basic-app:v1
curl http://localhost:8080

# Clean up
docker rm -f basic
```

### Exercise 1.2: Understanding Dockerfile Instructions

```bash
mkdir -p ~/docker-lab/instructions
cd ~/docker-lab/instructions

cat > Dockerfile << 'EOF'
# FROM: Base image
FROM ubuntu:22.04

# LABEL: Metadata
LABEL maintainer="you@example.com"
LABEL version="1.0"
LABEL description="Demo of Dockerfile instructions"

# ARG: Build-time variable
ARG APP_VERSION=1.0.0

# ENV: Environment variable (persists at runtime)
ENV APP_HOME=/app \
    APP_VERSION=${APP_VERSION}

# RUN: Execute commands during build
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# WORKDIR: Set working directory
WORKDIR ${APP_HOME}

# COPY: Copy files from build context
COPY . .

# ADD: Like COPY but can extract tarballs and fetch URLs
# ADD app.tar.gz .
# ADD https://example.com/file.txt .

# USER: Switch to non-root user
RUN useradd -m appuser
USER appuser

# EXPOSE: Document ports
EXPOSE 8080

# VOLUME: Create mount point
VOLUME ["/data"]

# ENTRYPOINT: Main executable (harder to override)
ENTRYPOINT ["echo"]

# CMD: Default arguments to ENTRYPOINT (easy to override)
CMD ["Hello from Docker!"]
EOF

# Create a test file
echo "test content" > testfile.txt

# Build with build args
docker build -t instructions:v1 --build-arg APP_VERSION=2.0.0 .

# Run
docker run instructions:v1
# Output: Hello from Docker!

# Override CMD
docker run instructions:v1 "Custom message"
# Output: Custom message

# Check environment
docker run --entrypoint env instructions:v1 | grep APP

docker rmi instructions:v1
```

### Exercise 1.3: The .dockerignore File

```bash
mkdir -p ~/docker-lab/ignore-demo
cd ~/docker-lab/ignore-demo

# Create various files
mkdir -p node_modules .git logs
echo "node code" > node_modules/module.js
echo "git stuff" > .git/config
echo "log data" > logs/app.log
echo "secret" > .env
echo "app code" > app.js

cat > Dockerfile << 'EOF'
FROM alpine:3.19
WORKDIR /app
COPY . .
CMD ["ls", "-la"]
EOF

# Build without .dockerignore
docker build -t ignore-test:without .
docker run ignore-test:without
# Shows all files including node_modules, .git, etc.

# Create .dockerignore
cat > .dockerignore << 'EOF'
# Dependencies
node_modules/
vendor/

# Git
.git/
.gitignore

# Logs
logs/
*.log

# Environment
.env
.env.*
*.secret

# IDE
.idea/
.vscode/
*.swp

# Docker
Dockerfile
docker-compose*.yml
.docker/

# Build artifacts
dist/
build/
*.pyc
__pycache__/

# Tests
tests/
test/
*.test.js
EOF

# Rebuild
docker build -t ignore-test:with .
docker run ignore-test:with
# Only shows app.js

# Compare sizes
docker images | grep ignore-test

docker rmi ignore-test:without ignore-test:with
```

---

## Part 2: Multi-Stage Builds

### Exercise 2.1: Go Application

```bash
mkdir -p ~/docker-lab/go-multi-stage
cd ~/docker-lab/go-multi-stage

# Create Go app
cat > main.go << 'EOF'
package main

import (
    "encoding/json"
    "log"
    "net/http"
    "os"
)

type Response struct {
    Message string `json:"message"`
    Version string `json:"version"`
    Host    string `json:"hostname"`
}

func main() {
    http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
        hostname, _ := os.Hostname()
        resp := Response{
            Message: "Hello from Go!",
            Version: "1.0.0",
            Host:    hostname,
        }
        w.Header().Set("Content-Type", "application/json")
        json.NewEncoder(w).Encode(resp)
    })

    http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
        w.WriteHeader(http.StatusOK)
        w.Write([]byte("OK"))
    })

    log.Println("Starting server on :8080")
    log.Fatal(http.ListenAndServe(":8080", nil))
}
EOF

cat > go.mod << 'EOF'
module goapp
go 1.21
EOF

# Single-stage Dockerfile (for comparison)
cat > Dockerfile.single << 'EOF'
FROM golang:1.21
WORKDIR /app
COPY . .
RUN go build -o server .
CMD ["./server"]
EOF

# Multi-stage Dockerfile
cat > Dockerfile << 'EOF'
# Stage 1: Build
FROM golang:1.21-alpine AS builder
WORKDIR /build
COPY go.mod ./
COPY main.go ./
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o server .

# Stage 2: Runtime
FROM scratch
COPY --from=builder /build/server /server
EXPOSE 8080
ENTRYPOINT ["/server"]
EOF

# Build both
docker build -t go-single -f Dockerfile.single .
docker build -t go-multi .

# Compare sizes
docker images | grep go-
# go-single: ~800MB+
# go-multi: ~5MB

# Test multi-stage
docker run -d --name gotest -p 8080:8080 go-multi
curl http://localhost:8080
curl http://localhost:8080/health

docker rm -f gotest
docker rmi go-single go-multi
```

### Exercise 2.2: Node.js Application

```bash
mkdir -p ~/docker-lab/node-multi-stage
cd ~/docker-lab/node-multi-stage

# Create package.json
cat > package.json << 'EOF'
{
  "name": "node-app",
  "version": "1.0.0",
  "main": "dist/index.js",
  "scripts": {
    "build": "tsc",
    "start": "node dist/index.js"
  },
  "dependencies": {
    "express": "^4.18.2"
  },
  "devDependencies": {
    "typescript": "^5.3.3",
    "@types/express": "^4.17.21",
    "@types/node": "^20.10.6"
  }
}
EOF

# Create TypeScript config
cat > tsconfig.json << 'EOF'
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "commonjs",
    "outDir": "./dist",
    "strict": true,
    "esModuleInterop": true
  },
  "include": ["src/**/*"]
}
EOF

# Create source
mkdir -p src
cat > src/index.ts << 'EOF'
import express, { Request, Response } from 'express';

const app = express();
const PORT = process.env.PORT || 3000;

app.get('/', (req: Request, res: Response) => {
  res.json({
    message: 'Hello from TypeScript!',
    version: '1.0.0',
    timestamp: new Date().toISOString()
  });
});

app.get('/health', (req: Request, res: Response) => {
  res.status(200).send('OK');
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
EOF

# Multi-stage Dockerfile
cat > Dockerfile << 'EOF'
# Stage 1: Install dependencies
FROM node:20-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci

# Stage 2: Build
FROM node:20-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

# Stage 3: Production
FROM node:20-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Copy production files only
COPY --from=deps /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
COPY package*.json ./

# Remove dev dependencies
RUN npm prune --production

# Change ownership
RUN chown -R nodejs:nodejs /app
USER nodejs

EXPOSE 3000
CMD ["node", "dist/index.js"]
EOF

# Create .dockerignore
cat > .dockerignore << 'EOF'
node_modules
dist
*.log
.git
Dockerfile
EOF

# Build
docker build -t node-multi .

# Run
docker run -d --name nodetest -p 3000:3000 node-multi
curl http://localhost:3000

docker rm -f nodetest
docker rmi node-multi
```

### Exercise 2.3: Python Application

```bash
mkdir -p ~/docker-lab/python-multi-stage
cd ~/docker-lab/python-multi-stage

# Create requirements
cat > requirements.txt << 'EOF'
fastapi==0.109.0
uvicorn[standard]==0.27.0
EOF

# Create app
cat > main.py << 'EOF'
from fastapi import FastAPI
from datetime import datetime

app = FastAPI()

@app.get("/")
async def root():
    return {
        "message": "Hello from FastAPI!",
        "version": "1.0.0",
        "timestamp": datetime.utcnow().isoformat()
    }

@app.get("/health")
async def health():
    return {"status": "healthy"}
EOF

# Multi-stage Dockerfile
cat > Dockerfile << 'EOF'
# Stage 1: Builder
FROM python:3.12-slim AS builder

WORKDIR /app

# Create virtual environment
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Stage 2: Runtime
FROM python:3.12-slim AS runtime

# Create non-root user
RUN useradd -m -u 1000 appuser

WORKDIR /app

# Copy virtual environment from builder
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Copy application
COPY --chown=appuser:appuser main.py .

USER appuser

EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF

# Build
docker build -t python-multi .

# Check size
docker images python-multi

# Run
docker run -d --name pytest -p 8000:8000 python-multi
curl http://localhost:8000
curl http://localhost:8000/health

docker rm -f pytest
docker rmi python-multi
```

---

## Part 3: Build Optimization

### Exercise 3.1: Layer Caching

```bash
mkdir -p ~/docker-lab/caching
cd ~/docker-lab/caching

# Create app files
cat > app.py << 'EOF'
print("Hello, World!")
EOF

cat > requirements.txt << 'EOF'
requests==2.31.0
EOF

# Bad: Source changes invalidate dependency cache
cat > Dockerfile.bad << 'EOF'
FROM python:3.12-slim
WORKDIR /app
COPY . .
RUN pip install -r requirements.txt
CMD ["python", "app.py"]
EOF

# Good: Dependencies installed before source
cat > Dockerfile.good << 'EOF'
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["python", "app.py"]
EOF

# Build both
time docker build -t cache-bad -f Dockerfile.bad .
time docker build -t cache-good -f Dockerfile.good .

# Modify app.py
echo 'print("Modified!")' >> app.py

# Rebuild - bad version reinstalls dependencies
time docker build -t cache-bad -f Dockerfile.bad .
# Slow - pip install runs again

# Rebuild - good version uses cached dependencies
time docker build -t cache-good -f Dockerfile.good .
# Fast - pip install is cached

docker rmi cache-bad cache-good
```

### Exercise 3.2: Reducing Image Size

```bash
mkdir -p ~/docker-lab/size-optimization
cd ~/docker-lab/size-optimization

# Create test script
cat > app.sh << 'EOF'
#!/bin/sh
echo "Hello from Alpine!"
curl --version
EOF
chmod +x app.sh

# Large image
cat > Dockerfile.large << 'EOF'
FROM ubuntu:22.04
RUN apt-get update && apt-get install -y curl
COPY app.sh /app.sh
CMD ["/app.sh"]
EOF

# Medium image (clean up apt)
cat > Dockerfile.medium << 'EOF'
FROM ubuntu:22.04
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*
COPY app.sh /app.sh
CMD ["/app.sh"]
EOF

# Small image (Alpine)
cat > Dockerfile.small << 'EOF'
FROM alpine:3.19
RUN apk add --no-cache curl
COPY app.sh /app.sh
CMD ["/app.sh"]
EOF

# Build all
docker build -t size-large -f Dockerfile.large .
docker build -t size-medium -f Dockerfile.medium .
docker build -t size-small -f Dockerfile.small .

# Compare sizes
docker images | grep size-
# size-large: ~150MB
# size-medium: ~90MB
# size-small: ~15MB

# All work the same
docker run size-large
docker run size-medium
docker run size-small

docker rmi size-large size-medium size-small
```

### Exercise 3.3: BuildKit Features

```bash
mkdir -p ~/docker-lab/buildkit
cd ~/docker-lab/buildkit

# Enable BuildKit
export DOCKER_BUILDKIT=1

# Create files
cat > app.py << 'EOF'
print("BuildKit Demo")
EOF

cat > requirements.txt << 'EOF'
requests>=2.31.0
EOF

# Using cache mounts
cat > Dockerfile << 'EOF'
# syntax=docker/dockerfile:1.4
FROM python:3.12-slim

WORKDIR /app

# Cache pip downloads
COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt

COPY . .
CMD ["python", "app.py"]
EOF

# Build with BuildKit
docker build -t buildkit-demo .

# Second build is faster due to cache mount
docker build -t buildkit-demo .

# Using build secrets (for private registries, etc.)
cat > Dockerfile.secrets << 'EOF'
# syntax=docker/dockerfile:1.4
FROM python:3.12-slim
RUN --mount=type=secret,id=mysecret \
    cat /run/secrets/mysecret > /tmp/secret_was_here && \
    echo "Secret used during build" && \
    rm /tmp/secret_was_here
CMD ["echo", "Built with secret"]
EOF

echo "my-secret-value" > mysecret.txt
docker build --secret id=mysecret,src=mysecret.txt -t secret-demo -f Dockerfile.secrets .

# Verify secret is not in image
docker history secret-demo
docker run secret-demo

docker rmi buildkit-demo secret-demo
rm mysecret.txt
```

---

## Part 4: Practical Challenges

### Challenge 1: Optimize This Dockerfile

```dockerfile
FROM python:3.12
RUN apt-get update
RUN apt-get install -y gcc
RUN pip install flask
RUN pip install gunicorn
RUN pip install requests
COPY . /app
WORKDIR /app
RUN apt-get install -y curl
CMD python app.py
```

<details>
<summary>Solution</summary>

```dockerfile
FROM python:3.12-slim AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

FROM python:3.12-slim
WORKDIR /app
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/* && \
    useradd -m appuser
COPY --from=builder /usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
COPY --chown=appuser:appuser . .
USER appuser
CMD ["gunicorn", "-b", "0.0.0.0:8000", "app:app"]
```
</details>

### Challenge 2: Create Multi-Arch Build

Build an image that works on both AMD64 and ARM64.

<details>
<summary>Solution</summary>

```bash
# Create buildx builder
docker buildx create --name multiarch --use

# Build for multiple platforms
docker buildx build \
    --platform linux/amd64,linux/arm64 \
    -t myapp:multiarch \
    --push \  # Requires pushing to registry
    .

# Or build and load locally (single platform)
docker buildx build \
    --platform linux/amd64 \
    -t myapp:amd64 \
    --load \
    .
```
</details>

---

## Validation Checklist

- [ ] I can write a basic Dockerfile
- [ ] I understand all common Dockerfile instructions
- [ ] I can create effective .dockerignore files
- [ ] I can implement multi-stage builds
- [ ] I understand layer caching and optimization
- [ ] I can reduce image sizes significantly
- [ ] I can use BuildKit features

---

## Next Lab

Continue to [Lab 3.3: Security Scanning](labs-lab-03-security-scanning.md)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Dockerfile Basics
- Multi-Stage Builds
- Build Optimization
- Practical Challenges

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
