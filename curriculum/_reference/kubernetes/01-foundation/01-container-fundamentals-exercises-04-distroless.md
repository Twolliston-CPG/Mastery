# Exercise 4: Distroless Migration

## Objective

Migrate an application from a traditional base image to a distroless image to minimize attack surface, reduce vulnerabilities, and improve security posture.

## Prerequisites

- Completed Exercises 1-3
- Understanding of multi-stage builds
- Familiarity with security scanning

## What is Distroless?

Distroless images contain only your application and its runtime dependencies. They do NOT contain:
- Package managers (apt, apk, yum)
- Shells (bash, sh)
- Common utilities (ls, cat, curl)

This dramatically reduces:
- Image size
- Vulnerability count
- Attack surface

## Available Distroless Images

| Image | Use Case | Size |
|-------|----------|------|
| `gcr.io/distroless/static-debian12` | Statically compiled binaries (Go, Rust) | ~2MB |
| `gcr.io/distroless/base-debian12` | Dynamically linked binaries | ~20MB |
| `gcr.io/distroless/cc-debian12` | C++ applications | ~25MB |
| `gcr.io/distroless/python3-debian12` | Python applications | ~50MB |
| `gcr.io/distroless/java21-debian12` | Java applications | ~90MB |
| `gcr.io/distroless/nodejs20-debian12` | Node.js applications | ~130MB |

## Tasks

### Task 1: Compare Image Sizes and Vulnerabilities

Create a simple Go application and build it with different bases:

**main.go**
```go
package main

import (
    "fmt"
    "net/http"
    "os"
)

func main() {
    http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
        hostname, _ := os.Hostname()
        fmt.Fprintf(w, "Hello from %s\n", hostname)
    })
    http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
        w.WriteHeader(http.StatusOK)
        fmt.Fprintf(w, "OK")
    })
    fmt.Println("Server starting on :8080")
    http.ListenAndServe(":8080", nil)
}
```

Create three Dockerfiles:

**Dockerfile.ubuntu**
```dockerfile
FROM golang:1.21 AS builder
WORKDIR /app
COPY . .
RUN CGO_ENABLED=0 go build -o server .

FROM ubuntu:22.04
COPY --from=builder /app/server /server
EXPOSE 8080
CMD ["/server"]
```

**Dockerfile.alpine**
```dockerfile
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY . .
RUN CGO_ENABLED=0 go build -o server .

FROM alpine:3.19
RUN adduser -D -u 1001 appuser
USER appuser
COPY --from=builder /app/server /server
EXPOSE 8080
CMD ["/server"]
```

**Dockerfile.distroless**
```dockerfile
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY . .
RUN CGO_ENABLED=0 go build -ldflags="-w -s" -o server .

FROM gcr.io/distroless/static-debian12
COPY --from=builder /app/server /server
USER nonroot:nonroot
EXPOSE 8080
CMD ["/server"]
```

Build and compare:
```bash
docker build -f Dockerfile.ubuntu -t app:ubuntu .
docker build -f Dockerfile.alpine -t app:alpine .
docker build -f Dockerfile.distroless -t app:distroless .

# Compare sizes
docker images | grep app

# Compare vulnerabilities
trivy image --severity HIGH,CRITICAL app:ubuntu
trivy image --severity HIGH,CRITICAL app:alpine
trivy image --severity HIGH,CRITICAL app:distroless
```

### Task 2: Migrate a Node.js Application

Migrate a Node.js application to distroless:

**server.js**
```javascript
const http = require('http');
const port = process.env.PORT || 3000;

const server = http.createServer((req, res) => {
    if (req.url === '/health') {
        res.writeHead(200);
        res.end('OK');
        return;
    }
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ message: 'Hello from Node.js', timestamp: new Date() }));
});

server.listen(port, () => {
    console.log(`Server running on port ${port}`);
});
```

**Dockerfile.node-distroless**
```dockerfile
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .

FROM gcr.io/distroless/nodejs20-debian12
WORKDIR /app
COPY --from=builder /app .
USER nonroot
EXPOSE 3000
CMD ["server.js"]
```

### Task 3: Migrate a Python Application

**app.py**
```python
from http.server import HTTPServer, BaseHTTPRequestHandler
import json
import os

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/health':
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b'OK')
            return

        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        response = {
            'message': 'Hello from Python',
            'hostname': os.uname().nodename
        }
        self.wfile.write(json.dumps(response).encode())

if __name__ == '__main__':
    server = HTTPServer(('0.0.0.0', 8000), Handler)
    print('Server running on port 8000')
    server.serve_forever()
```

**Dockerfile.python-distroless**
```dockerfile
FROM python:3.11-slim AS builder
WORKDIR /app
COPY requirements.txt ./
RUN pip install --target=/app/deps -r requirements.txt

FROM gcr.io/distroless/python3-debian12
WORKDIR /app
COPY --from=builder /app/deps /app/deps
COPY . .
ENV PYTHONPATH=/app/deps
USER nonroot
EXPOSE 8000
CMD ["app.py"]
```

### Task 4: Migrate a Java Application

**App.java**
```java
import com.sun.net.httpserver.HttpServer;
import java.io.OutputStream;
import java.net.InetSocketAddress;

public class App {
    public static void main(String[] args) throws Exception {
        HttpServer server = HttpServer.create(new InetSocketAddress(8080), 0);

        server.createContext("/health", exchange -> {
            String response = "OK";
            exchange.sendResponseHeaders(200, response.length());
            try (OutputStream os = exchange.getResponseBody()) {
                os.write(response.getBytes());
            }
        });

        server.createContext("/", exchange -> {
            String response = "{\"message\": \"Hello from Java\"}";
            exchange.getResponseHeaders().set("Content-Type", "application/json");
            exchange.sendResponseHeaders(200, response.length());
            try (OutputStream os = exchange.getResponseBody()) {
                os.write(response.getBytes());
            }
        });

        server.start();
        System.out.println("Server running on port 8080");
    }
}
```

**Dockerfile.java-distroless**
```dockerfile
FROM eclipse-temurin:21-jdk-alpine AS builder
WORKDIR /app
COPY App.java .
RUN javac App.java && \
    jar cfe app.jar App *.class

FROM gcr.io/distroless/java21-debian12
COPY --from=builder /app/app.jar /app.jar
USER nonroot
EXPOSE 8080
CMD ["app.jar"]
```

### Task 5: Handle Debugging Without Shell

Since distroless images have no shell, debugging requires different techniques:

**Option 1: Debug sidecar**
```yaml
# debug-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: debug-pod
spec:
  shareProcessNamespace: true
  containers:
  - name: app
    image: myapp:distroless
  - name: debug
    image: busybox
    stdin: true
    tty: true
    securityContext:
      capabilities:
        add: ["SYS_PTRACE"]
```

**Option 2: Ephemeral debug container (Kubernetes 1.23+)**
```bash
kubectl debug -it mypod --image=busybox --target=app
```

**Option 3: Use distroless debug image**
```dockerfile
# For development/debugging only
FROM gcr.io/distroless/base-debian12:debug
# This variant includes busybox shell at /busybox/sh
```

### Task 6: Create a Production-Ready Distroless Image

Create a complete, production-ready distroless image with:

1. Health check (without wget/curl)
2. Proper signal handling
3. Graceful shutdown
4. Non-root user

**main.go (production version)**
```go
package main

import (
    "context"
    "encoding/json"
    "log"
    "net/http"
    "os"
    "os/signal"
    "syscall"
    "time"
)

type Response struct {
    Status    string    `json:"status"`
    Timestamp time.Time `json:"timestamp"`
    Hostname  string    `json:"hostname"`
}

func main() {
    hostname, _ := os.Hostname()

    mux := http.NewServeMux()

    mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
        w.WriteHeader(http.StatusOK)
        json.NewEncoder(w).Encode(Response{
            Status:    "healthy",
            Timestamp: time.Now().UTC(),
            Hostname:  hostname,
        })
    })

    mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
        w.Header().Set("Content-Type", "application/json")
        json.NewEncoder(w).Encode(Response{
            Status:    "ok",
            Timestamp: time.Now().UTC(),
            Hostname:  hostname,
        })
    })

    server := &http.Server{
        Addr:         ":8080",
        Handler:      mux,
        ReadTimeout:  5 * time.Second,
        WriteTimeout: 10 * time.Second,
        IdleTimeout:  120 * time.Second,
    }

    // Graceful shutdown
    done := make(chan bool, 1)
    quit := make(chan os.Signal, 1)
    signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)

    go func() {
        <-quit
        log.Println("Server shutting down...")

        ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
        defer cancel()

        if err := server.Shutdown(ctx); err != nil {
            log.Fatalf("Server forced to shutdown: %v", err)
        }

        close(done)
    }()

    log.Println("Server starting on :8080")
    if err := server.ListenAndServe(); err != http.ErrServerClosed {
        log.Fatalf("Server error: %v", err)
    }

    <-done
    log.Println("Server stopped")
}
```

**Dockerfile.production**
```dockerfile
FROM golang:1.21-alpine AS builder

RUN apk add --no-cache ca-certificates tzdata

WORKDIR /build
COPY go.mod go.sum* ./
RUN go mod download

COPY . .

ARG VERSION=1.0.0
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-w -s -X main.version=${VERSION}" \
    -o /app .

FROM gcr.io/distroless/static-debian12

# Copy timezone data
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo
# Copy CA certificates
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
# Copy the binary
COPY --from=builder /app /app

USER nonroot:nonroot

EXPOSE 8080

ENTRYPOINT ["/app"]
```

## Validation

```bash
# Build all variants
docker build -f Dockerfile.ubuntu -t app:ubuntu .
docker build -f Dockerfile.alpine -t app:alpine .
docker build -f Dockerfile.distroless -t app:distroless .

# Size comparison
echo "=== Image Sizes ==="
docker images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}" | grep app

# Vulnerability comparison
echo "=== Vulnerabilities ==="
for tag in ubuntu alpine distroless; do
    echo "--- $tag ---"
    trivy image --severity HIGH,CRITICAL --quiet app:$tag 2>/dev/null | tail -1
done

# Test functionality
docker run -d --name test -p 8080:8080 app:distroless
curl http://localhost:8080/health
docker rm -f test

# Verify no shell
docker run --rm -it app:distroless /bin/sh
# Expected: Error - no shell available
```

## Success Criteria

- [ ] Successfully migrated application to distroless
- [ ] Image size reduced by 80%+ compared to Ubuntu
- [ ] Zero or minimal vulnerabilities
- [ ] Application functions correctly
- [ ] Graceful shutdown implemented
- [ ] Debugging strategy documented

## Comparison Summary

| Base Image | Size | HIGH/CRITICAL CVEs | Shell | Package Manager |
|------------|------|-------------------|-------|-----------------|
| Ubuntu 22.04 | ~80MB | 10-20 | Yes | apt |
| Alpine 3.19 | ~8MB | 0-5 | Yes | apk |
| Distroless Static | ~2MB | 0 | No | No |

## Next Exercise

Continue to [Exercise 5: Registry Workflow](./05-registry-workflow.md) to learn how to push images to cloud registries.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- What is Distroless?
- Available Distroless Images
- Comparison Summary
- Compare Image Sizes and Vulnerabilities

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
