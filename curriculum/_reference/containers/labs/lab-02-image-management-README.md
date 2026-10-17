# Lab 02: Image Management

## Objectives

- Build Docker images from Dockerfiles
- Understand image layers and caching
- Optimize images for size and security
- Work with image registries

## Prerequisites

- Completed Lab 01
- Docker installed and configured
- Basic understanding of Dockerfiles

---

## Part 1: Building Basic Images (Guided)

### Step 1: Create Project Directory

```bash
mkdir -p ~/docker-labs/lab02
cd ~/docker-labs/lab02
```

### Step 2: Create Simple Application

```bash
# Create a simple Node.js application
mkdir simple-app && cd simple-app

# Create package.json
cat > package.json << 'EOF'
{
  "name": "simple-app",
  "version": "1.0.0",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  }
}
EOF

# Create server.js
cat > server.js << 'EOF'
const http = require('http');

const server = http.createServer((req, res) => {
  res.writeHead(200, {'Content-Type': 'application/json'});
  res.end(JSON.stringify({
    message: 'Hello from Docker!',
    hostname: require('os').hostname(),
    timestamp: new Date().toISOString()
  }));
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
EOF
```

### Step 3: Create Basic Dockerfile

```dockerfile
# Dockerfile
FROM node:18

WORKDIR /app

COPY package.json ./
COPY server.js ./

EXPOSE 3000

CMD ["npm", "start"]
```

### Step 4: Build and Run

```bash
# Build image
docker build -t simple-app:v1 .

# View image
docker images simple-app

# Run container
docker run -d --name simple-app -p 3000:3000 simple-app:v1

# Test
curl http://localhost:3000

# View logs
docker logs simple-app

# Cleanup
docker stop simple-app && docker rm simple-app
```

### Step 5: Examine Layers

```bash
# View image history
docker history simple-app:v1

# View image size
docker images simple-app:v1 --format "{{.Size}}"

# Inspect image
docker inspect simple-app:v1
```

### Validation

```bash
#!/bin/bash
# validate-part1.sh

echo "=== Part 1 Validation ==="

if docker images simple-app:v1 --format "{{.Repository}}:{{.Tag}}" | grep -q "simple-app:v1"; then
    echo "✓ Image simple-app:v1 exists"
else
    echo "✗ Image simple-app:v1 not found"
    exit 1
fi

# Test the image
CONTAINER_ID=$(docker run -d -p 3001:3000 simple-app:v1)
sleep 2

RESPONSE=$(curl -s http://localhost:3001)
if echo "$RESPONSE" | grep -q "Hello from Docker"; then
    echo "✓ Application responds correctly"
else
    echo "✗ Application not responding"
fi

docker stop $CONTAINER_ID && docker rm $CONTAINER_ID

echo "Part 1 validation complete!"
```

---

## Part 2: Image Optimization (Semi-Guided)

### Objective

Optimize the image for smaller size and better caching.

### Current Issues

1. Image is too large (~1GB)
2. npm install runs on every code change
3. No .dockerignore

### Tasks

1. Create `.dockerignore` file to exclude:
   - node_modules
   - .git
   - *.md
   - Dockerfile

2. Create optimized Dockerfile with:
   - Alpine-based image
   - Proper layer ordering (dependencies before code)
   - npm ci instead of npm install
   - Non-root user

3. Compare sizes between v1 and v2

### Hints

<details>
<summary>Alpine Base Image</summary>

```dockerfile
FROM node:18-alpine
```
</details>

<details>
<summary>Layer Ordering</summary>

```dockerfile
# Copy dependencies first (changes less frequently)
COPY package*.json ./
RUN npm ci --only=production

# Then copy application code
COPY . .
```
</details>

<details>
<summary>Non-root User</summary>

```dockerfile
USER node
```
</details>

### Validation

```bash
#!/bin/bash
# validate-part2.sh

echo "=== Part 2 Validation ==="

# Check .dockerignore exists
if [ -f .dockerignore ]; then
    echo "✓ .dockerignore exists"
else
    echo "✗ .dockerignore not found"
fi

# Check v2 image exists
if docker images simple-app:v2 &> /dev/null; then
    echo "✓ Image simple-app:v2 exists"
else
    echo "✗ Image simple-app:v2 not found"
    exit 1
fi

# Compare sizes
V1_SIZE=$(docker images simple-app:v1 --format "{{.Size}}" | sed 's/MB//' | sed 's/GB/*1024/')
V2_SIZE=$(docker images simple-app:v2 --format "{{.Size}}" | sed 's/MB//' | sed 's/GB/*1024/')

echo "  v1 size: $(docker images simple-app:v1 --format '{{.Size}}')"
echo "  v2 size: $(docker images simple-app:v2 --format '{{.Size}}')"

# Check running as non-root
CONTAINER_ID=$(docker run -d simple-app:v2)
USER=$(docker exec $CONTAINER_ID whoami 2>/dev/null || echo "root")
docker stop $CONTAINER_ID && docker rm $CONTAINER_ID

if [ "$USER" != "root" ]; then
    echo "✓ Container runs as non-root user: $USER"
else
    echo "✗ Container runs as root"
fi

echo "Part 2 validation complete!"
```

---

## Part 3: Multi-Stage Builds (Semi-Guided)

### Objective

Create a multi-stage build for a Go application.

### Step 1: Create Go Application

```bash
mkdir -p ~/docker-labs/lab02/go-app && cd ~/docker-labs/lab02/go-app

# Create main.go
cat > main.go << 'EOF'
package main

import (
    "encoding/json"
    "net/http"
    "os"
    "time"
)

type Response struct {
    Message   string `json:"message"`
    Hostname  string `json:"hostname"`
    Timestamp string `json:"timestamp"`
}

func main() {
    http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
        hostname, _ := os.Hostname()
        response := Response{
            Message:   "Hello from Go!",
            Hostname:  hostname,
            Timestamp: time.Now().Format(time.RFC3339),
        }
        w.Header().Set("Content-Type", "application/json")
        json.NewEncoder(w).Encode(response)
    })

    http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
        w.WriteHeader(http.StatusOK)
        w.Write([]byte("OK"))
    })

    port := os.Getenv("PORT")
    if port == "" {
        port = "8080"
    }

    http.ListenAndServe(":"+port, nil)
}
EOF

# Create go.mod
cat > go.mod << 'EOF'
module go-app

go 1.21
EOF
```

### Tasks

1. Create a multi-stage Dockerfile:
   - Stage 1: Build using golang:1.21 image
   - Stage 2: Run using scratch or distroless image
   - Include health check

2. Build and verify the image size is under 20MB

3. Ensure the binary is statically linked

### Hints

<details>
<summary>Static Binary Build</summary>

```dockerfile
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main .
```
</details>

<details>
<summary>Scratch Image</summary>

```dockerfile
FROM scratch
COPY --from=builder /app/main /main
ENTRYPOINT ["/main"]
```
</details>

### Validation

```bash
#!/bin/bash
# validate-part3.sh

echo "=== Part 3 Validation ==="

# Check image exists
if docker images go-app:v1 &> /dev/null; then
    echo "✓ Image go-app:v1 exists"
else
    echo "✗ Image go-app:v1 not found"
    exit 1
fi

# Check size
SIZE=$(docker images go-app:v1 --format "{{.Size}}")
echo "  Image size: $SIZE"

# Check if size is under 20MB
SIZE_MB=$(docker images go-app:v1 --format "{{.Size}}" | sed 's/MB//')
if (( $(echo "$SIZE_MB < 20" | bc -l) )); then
    echo "✓ Image is under 20MB"
else
    echo "✗ Image is larger than 20MB"
fi

# Test the application
CONTAINER_ID=$(docker run -d -p 8080:8080 go-app:v1)
sleep 2

RESPONSE=$(curl -s http://localhost:8080)
if echo "$RESPONSE" | grep -q "Hello from Go"; then
    echo "✓ Application responds correctly"
else
    echo "✗ Application not responding"
fi

docker stop $CONTAINER_ID && docker rm $CONTAINER_ID

echo "Part 3 validation complete!"
```

---

## Part 4: Challenge - Production-Ready Image

### Objective

Build a production-ready Python application image with all best practices.

### Requirements

Create a Python Flask application with:

1. Application features:
   - GET / returns JSON with hostname, version, timestamp
   - GET /health returns 200 OK
   - GET /ready returns 200 when ready, 503 when not
   - Read PORT from environment variable

2. Dockerfile requirements:
   - Multi-stage build
   - Alpine or slim base
   - Non-root user (uid 1000)
   - No shell access (remove /bin/sh)
   - Health check instruction
   - OCI labels (title, version, authors)
   - Size under 100MB

3. Security:
   - No root access
   - Read-only filesystem compatible
   - Minimal packages

4. Create security scan script using Trivy

### Validation

```bash
#!/bin/bash
# validate-challenge.sh

echo "=== Challenge Validation ==="

IMAGE="python-app:prod"

# Check image exists
if ! docker images $IMAGE &> /dev/null; then
    echo "✗ Image $IMAGE not found"
    exit 1
fi
echo "✓ Image exists"

# Check size
SIZE=$(docker images $IMAGE --format "{{.Size}}" | sed 's/MB//')
echo "  Size: $(docker images $IMAGE --format '{{.Size}}')"

# Check labels
TITLE=$(docker inspect $IMAGE --format '{{index .Config.Labels "org.opencontainers.image.title"}}')
if [ -n "$TITLE" ]; then
    echo "✓ OCI labels present: $TITLE"
else
    echo "✗ OCI labels missing"
fi

# Check runs as non-root
CONTAINER_ID=$(docker run -d $IMAGE)
sleep 2
UID=$(docker exec $CONTAINER_ID id -u 2>/dev/null || echo "0")
docker stop $CONTAINER_ID && docker rm $CONTAINER_ID

if [ "$UID" = "1000" ]; then
    echo "✓ Runs as UID 1000"
else
    echo "✗ Does not run as UID 1000 (got $UID)"
fi

# Check health check defined
HEALTHCHECK=$(docker inspect $IMAGE --format '{{.Config.Healthcheck}}')
if [ -n "$HEALTHCHECK" ] && [ "$HEALTHCHECK" != "<nil>" ]; then
    echo "✓ Health check defined"
else
    echo "✗ Health check not defined"
fi

# Test read-only filesystem
CONTAINER_ID=$(docker run -d --read-only $IMAGE 2>/dev/null)
if [ $? -eq 0 ]; then
    sleep 2
    if docker exec $CONTAINER_ID curl -s http://localhost:5000/health | grep -q "OK"; then
        echo "✓ Works with read-only filesystem"
    else
        echo "✗ Does not work with read-only filesystem"
    fi
    docker stop $CONTAINER_ID && docker rm $CONTAINER_ID
else
    echo "✗ Cannot run with read-only filesystem"
fi

echo ""
echo "Challenge validation complete!"
```

---

## Deliverables

1. simple-app:v1 and simple-app:v2 images
2. go-app:v1 multi-stage build image
3. python-app:prod production image
4. All Dockerfiles and .dockerignore files
5. Security scan results

## Resources

- [Dockerfile Best Practices](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
- [Multi-stage Builds](https://docs.docker.com/build/building/multi-stage/)
- [Trivy Scanner](https://aquasecurity.github.io/trivy/)

## Next Lab

Continue to [Lab 03: Container Operations](lab-03-container-operations-README.md)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Building Basic Images
- Image Optimization
- Multi-Stage Builds
- Challenge - Production-Ready Image

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
