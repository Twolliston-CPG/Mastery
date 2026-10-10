# Exercise 1: Build a Production Image

## Objective

Build an optimized, production-ready Node.js container image following best practices for security, size, and maintainability.

## Prerequisites

- Docker installed and running
- Basic understanding of Dockerfile syntax
- Node.js application code (provided below)

## Scenario

You're tasked with containerizing a Node.js REST API for production deployment. The image must be:
- Secure (non-root user, minimal attack surface)
- Small (under 200MB)
- Properly tagged with metadata
- Health check enabled

## Starter Application

Create the following files in a new directory called `api-service`:

### package.json
```json
{
  "name": "api-service",
  "version": "1.0.0",
  "description": "Production API Service",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "test": "node test.js"
  },
  "dependencies": {
    "express": "^4.18.2"
  },
  "devDependencies": {
    "jest": "^29.7.0"
  }
}
```

### server.js
```javascript
const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'healthy', timestamp: new Date().toISOString() });
});

// API endpoint
app.get('/api/info', (req, res) => {
  res.json({
    service: 'api-service',
    version: process.env.APP_VERSION || '1.0.0',
    environment: process.env.NODE_ENV || 'development'
  });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on port ${PORT}`);
});
```

## Tasks

### Task 1: Create a Basic Dockerfile

Create a Dockerfile that:
1. Uses a specific Node.js Alpine base image (not `latest`)
2. Sets the working directory to `/app`
3. Copies package files and installs production dependencies only
4. Copies the application code
5. Exposes port 3000
6. Sets the start command

### Task 2: Add Security Hardening

Modify your Dockerfile to:
1. Create a non-root user and group
2. Set proper file ownership
3. Run as the non-root user
4. Add a security context

### Task 3: Add Health Check

Add a HEALTHCHECK instruction that:
1. Checks the `/health` endpoint every 30 seconds
2. Times out after 3 seconds
3. Allows 5 seconds for startup
4. Fails after 3 retries

### Task 4: Add Metadata Labels

Add OCI-compliant labels:
1. `org.opencontainers.image.source` - Repository URL
2. `org.opencontainers.image.version` - Application version
3. `org.opencontainers.image.description` - Service description
4. `org.opencontainers.image.created` - Build timestamp

### Task 5: Optimize Layer Caching

Ensure your Dockerfile:
1. Copies dependency files before source code
2. Uses `npm ci` instead of `npm install`
3. Cleans npm cache in the same layer
4. Minimizes the number of layers

## Validation

Build and test your image:

```bash
# Build the image
docker build -t api-service:1.0.0 .

# Check image size (should be < 200MB)
docker images api-service:1.0.0

# Run the container
docker run -d --name api-test -p 3000:3000 api-service:1.0.0

# Test health endpoint
curl http://localhost:3000/health

# Test API endpoint
curl http://localhost:3000/api/info

# Verify running as non-root
docker exec api-test whoami

# Check labels
docker inspect api-service:1.0.0 --format='{{json .Config.Labels}}' | jq

# Cleanup
docker rm -f api-test
```

## Success Criteria

- [ ] Image builds successfully
- [ ] Image size is under 200MB
- [ ] Container runs as non-root user
- [ ] Health check passes
- [ ] All metadata labels present
- [ ] API endpoints respond correctly

## Solution

<details>
<summary>Click to reveal solution</summary>

```dockerfile
# Dockerfile

# Use specific Alpine-based Node.js image
FROM node:20.10-alpine3.18

# Set metadata labels
LABEL org.opencontainers.image.source="https://github.com/your-org/api-service" \
      org.opencontainers.image.version="1.0.0" \
      org.opencontainers.image.description="Production API Service" \
      org.opencontainers.image.created="2024-01-01T00:00:00Z"

# Set working directory
WORKDIR /app

# Create non-root user and group
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup

# Copy dependency files first (layer caching optimization)
COPY package*.json ./

# Install production dependencies only and clean cache
RUN npm ci --only=production && \
    npm cache clean --force

# Copy application code with proper ownership
COPY --chown=appuser:appgroup . .

# Switch to non-root user
USER appuser

# Document the exposed port
EXPOSE 3000

# Set environment variables
ENV NODE_ENV=production \
    APP_VERSION=1.0.0

# Add health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

# Use exec form for CMD
CMD ["node", "server.js"]
```

</details>

## Bonus Challenges

1. **Add .dockerignore**: Create a `.dockerignore` file to exclude unnecessary files
2. **Add build arguments**: Use `ARG` to make version configurable at build time
3. **Add multi-architecture support**: Build for both amd64 and arm64

## Next Exercise

Continue to [Exercise 2: Multi-Stage Build](./02-multi-stage.md) to learn how to further optimize image size.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Starter Application
- server.js
- Create a Basic Dockerfile
- Add Security Hardening

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
