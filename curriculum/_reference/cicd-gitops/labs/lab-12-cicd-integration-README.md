# Lab 12: CI/CD Integration and Best Practices

## Overview

In this capstone lab, you'll integrate all CI/CD concepts learned throughout Phase 4 into a comprehensive, production-ready pipeline. You'll implement best practices for pipeline design, optimization, monitoring, and maintenance.

**Duration**: 4-5 hours
**Difficulty**: Advanced

## Prerequisites

- Completed Labs 01-11
- GitHub account with repository
- Kubernetes cluster access
- Docker and Docker Compose installed
- Understanding of all previous concepts

## Learning Objectives

- Design end-to-end CI/CD pipelines
- Implement pipeline optimization techniques
- Set up comprehensive monitoring and alerting
- Apply security best practices throughout
- Document and maintain pipeline infrastructure

## Lab Environment Setup

```bash
# Create lab directory
mkdir -p ~/cicd-integration-lab && cd ~/cicd-integration-lab

# Clone a complete project template
git init

# Create comprehensive project structure
mkdir -p {src,tests/{unit,integration,e2e},scripts}
mkdir -p {.github/workflows,k8s/{base,overlays/{dev,staging,prod}}}
mkdir -p {docs,monitoring}

# Create sample microservice
cat > src/main.go << 'EOF'
package main

import (
    "encoding/json"
    "log"
    "net/http"
    "os"
    "time"

    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
    requestsTotal = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "http_requests_total",
            Help: "Total HTTP requests",
        },
        []string{"method", "endpoint", "status"},
    )

    requestDuration = prometheus.NewHistogramVec(
        prometheus.HistogramOpts{
            Name:    "http_request_duration_seconds",
            Help:    "HTTP request duration",
            Buckets: prometheus.DefBuckets,
        },
        []string{"method", "endpoint"},
    )

    appInfo = prometheus.NewGaugeVec(
        prometheus.GaugeOpts{
            Name: "app_info",
            Help: "Application information",
        },
        []string{"version", "commit"},
    )
)

func init() {
    prometheus.MustRegister(requestsTotal, requestDuration, appInfo)
}

type Response struct {
    Message   string    `json:"message"`
    Version   string    `json:"version"`
    Commit    string    `json:"commit"`
    Timestamp time.Time `json:"timestamp"`
}

func main() {
    version := getEnv("APP_VERSION", "1.0.0")
    commit := getEnv("APP_COMMIT", "unknown")
    port := getEnv("PORT", "8080")

    appInfo.WithLabelValues(version, commit).Set(1)

    http.HandleFunc("/", instrumentHandler("root", rootHandler(version, commit)))
    http.HandleFunc("/health", instrumentHandler("health", healthHandler))
    http.HandleFunc("/ready", instrumentHandler("ready", readyHandler))
    http.Handle("/metrics", promhttp.Handler())

    log.Printf("Starting server v%s (%s) on port %s", version, commit, port)
    log.Fatal(http.ListenAndServe(":"+port, nil))
}

func instrumentHandler(name string, handler http.HandlerFunc) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        start := time.Now()

        rec := &responseRecorder{ResponseWriter: w, statusCode: 200}
        handler(rec, r)

        duration := time.Since(start).Seconds()
        requestsTotal.WithLabelValues(r.Method, name, http.StatusText(rec.statusCode)).Inc()
        requestDuration.WithLabelValues(r.Method, name).Observe(duration)
    }
}

type responseRecorder struct {
    http.ResponseWriter
    statusCode int
}

func (r *responseRecorder) WriteHeader(code int) {
    r.statusCode = code
    r.ResponseWriter.WriteHeader(code)
}

func rootHandler(version, commit string) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        resp := Response{
            Message:   "Hello from CI/CD Integration Lab!",
            Version:   version,
            Commit:    commit,
            Timestamp: time.Now(),
        }
        w.Header().Set("Content-Type", "application/json")
        json.NewEncoder(w).Encode(resp)
    }
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(map[string]string{"status": "healthy"})
}

func readyHandler(w http.ResponseWriter, r *http.Request) {
    // Check dependencies here
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(map[string]string{"status": "ready"})
}

func getEnv(key, defaultValue string) string {
    if value := os.Getenv(key); value != "" {
        return value
    }
    return defaultValue
}
EOF

# Create go.mod
cat > go.mod << 'EOF'
module cicd-integration-lab

go 1.21

require github.com/prometheus/client_golang v1.18.0
EOF

# Create Dockerfile with best practices
cat > Dockerfile << 'EOF'
# Build stage
FROM golang:1.21-alpine AS builder

# Install security updates
RUN apk update && apk upgrade && apk add --no-cache ca-certificates git

WORKDIR /app

# Copy dependency files first (cache layer)
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build with security flags
ARG VERSION=dev
ARG COMMIT=unknown
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -ldflags="-w -s -X main.version=${VERSION} -X main.commit=${COMMIT}" \
    -o /app/server ./src/

# Runtime stage
FROM scratch

# Copy CA certificates
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Copy binary
COPY --from=builder /app/server /server

# Non-root user (UID 65534 is nobody)
USER 65534

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ["/server", "-health-check"]

ENTRYPOINT ["/server"]
EOF
```

---

## Part 1: Guided Exercise - Complete CI Pipeline

### Step 1: Create Comprehensive CI Workflow

```yaml
# .github/workflows/ci.yml
name: CI Pipeline

on:
  push:
    branches: [main, develop, 'release/**']
  pull_request:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read
  packages: write
  security-events: write
  id-token: write

env:
  GO_VERSION: '1.21'
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  # Quick validation jobs (parallel)
  lint:
    name: Lint
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Go
        uses: actions/setup-go@v5
        with:
          go-version: ${{ env.GO_VERSION }}
          cache: true

      - name: Run golangci-lint
        uses: golangci/golangci-lint-action@v4
        with:
          version: latest

  security-scan:
    name: Security Scan
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run Gosec
        uses: securego/gosec@master
        with:
          args: ./...

      - name: Run Trivy filesystem scan
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: '.'
          format: 'sarif'
          output: 'trivy-fs.sarif'

      - name: Upload SARIF results
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: 'trivy-fs.sarif'

  # Test jobs (parallel)
  unit-tests:
    name: Unit Tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Go
        uses: actions/setup-go@v5
        with:
          go-version: ${{ env.GO_VERSION }}
          cache: true

      - name: Run unit tests
        run: |
          go test -v -race -coverprofile=coverage.out -covermode=atomic ./...
          go tool cover -func=coverage.out

      - name: Upload coverage
        uses: codecov/codecov-action@v4
        with:
          files: coverage.out
          flags: unit

  integration-tests:
    name: Integration Tests
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_DB: test
          POSTGRES_USER: test
          POSTGRES_PASSWORD: test
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    steps:
      - uses: actions/checkout@v4

      - name: Set up Go
        uses: actions/setup-go@v5
        with:
          go-version: ${{ env.GO_VERSION }}
          cache: true

      - name: Run integration tests
        env:
          DATABASE_URL: postgres://test:test@localhost:5432/test
        run: go test -v -tags=integration ./tests/integration/...

  # Build jobs (depend on tests)
  build:
    name: Build
    runs-on: ubuntu-latest
    needs: [lint, unit-tests, security-scan]
    outputs:
      digest: ${{ steps.build.outputs.digest }}
      version: ${{ steps.meta.outputs.version }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to GHCR
        if: github.event_name != 'pull_request'
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
            type=ref,event=branch
            type=ref,event=pr
            type=semver,pattern={{version}}
            type=raw,value=latest,enable={{is_default_branch}}

      - name: Build and push
        id: build
        uses: docker/build-push-action@v5
        with:
          context: .
          push: ${{ github.event_name != 'pull_request' }}
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          build-args: |
            VERSION=${{ steps.meta.outputs.version }}
            COMMIT=${{ github.sha }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
          provenance: true
          sbom: true

      - name: Install Cosign
        if: github.event_name != 'pull_request'
        uses: sigstore/cosign-installer@v3

      - name: Sign image
        if: github.event_name != 'pull_request'
        run: |
          cosign sign --yes ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}@${{ steps.build.outputs.digest }}

  # Container security scan
  container-scan:
    name: Container Scan
    runs-on: ubuntu-latest
    needs: build
    if: github.event_name != 'pull_request'
    steps:
      - name: Run Trivy container scan
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}@${{ needs.build.outputs.digest }}
          format: 'sarif'
          output: 'trivy-container.sarif'
          severity: 'CRITICAL,HIGH'

      - name: Upload SARIF results
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: 'trivy-container.sarif'
```

### Step 2: Create CD Workflow

```yaml
# .github/workflows/cd.yml
name: CD Pipeline

on:
  workflow_run:
    workflows: ["CI Pipeline"]
    types: [completed]
    branches: [main]
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy'
        required: true
        type: choice
        options:
          - staging
          - production
      version:
        description: 'Version to deploy (image tag)'
        required: true

permissions:
  contents: read
  id-token: write

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  prepare:
    name: Prepare Deployment
    runs-on: ubuntu-latest
    if: ${{ github.event.workflow_run.conclusion == 'success' || github.event_name == 'workflow_dispatch' }}
    outputs:
      image: ${{ steps.set-image.outputs.image }}
      environment: ${{ steps.set-env.outputs.environment }}
    steps:
      - name: Set image reference
        id: set-image
        run: |
          if [ "${{ github.event_name }}" == "workflow_dispatch" ]; then
            IMAGE="${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ inputs.version }}"
          else
            IMAGE="${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}"
          fi
          echo "image=$IMAGE" >> $GITHUB_OUTPUT

      - name: Set environment
        id: set-env
        run: |
          if [ "${{ github.event_name }}" == "workflow_dispatch" ]; then
            echo "environment=${{ inputs.environment }}" >> $GITHUB_OUTPUT
          else
            echo "environment=staging" >> $GITHUB_OUTPUT
          fi

  deploy-staging:
    name: Deploy to Staging
    runs-on: ubuntu-latest
    needs: prepare
    if: needs.prepare.outputs.environment == 'staging' || github.event_name == 'workflow_run'
    environment:
      name: staging
      url: https://staging.example.com
    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_STAGING }}
          aws-region: us-east-1

      - name: Deploy to EKS
        run: |
          aws eks update-kubeconfig --name staging-cluster
          kubectl set image deployment/app app=${{ needs.prepare.outputs.image }} -n staging
          kubectl rollout status deployment/app -n staging --timeout=5m

      - name: Run smoke tests
        run: |
          sleep 30
          curl -f https://staging.example.com/health || exit 1

      - name: Notify deployment
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "Deployed to staging: ${{ needs.prepare.outputs.image }}"
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}

  deploy-production:
    name: Deploy to Production
    runs-on: ubuntu-latest
    needs: [prepare, deploy-staging]
    if: needs.prepare.outputs.environment == 'production' || github.ref == 'refs/heads/main'
    environment:
      name: production
      url: https://app.example.com
    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_PRODUCTION }}
          aws-region: us-east-1

      - name: Deploy canary (10%)
        run: |
          aws eks update-kubeconfig --name production-cluster
          kubectl set image deployment/app-canary app=${{ needs.prepare.outputs.image }} -n production
          kubectl scale deployment/app-canary --replicas=1 -n production

      - name: Monitor canary (5 min)
        run: |
          echo "Monitoring canary deployment..."
          sleep 300
          # Check error rates
          ERROR_RATE=$(curl -s "http://prometheus:9090/api/v1/query?query=rate(http_requests_total{status=~\"5..\"}[5m])" | jq '.data.result[0].value[1] // 0')
          if (( $(echo "$ERROR_RATE > 0.01" | bc -l) )); then
            echo "Error rate too high: $ERROR_RATE"
            kubectl rollout undo deployment/app-canary -n production
            exit 1
          fi

      - name: Full rollout
        run: |
          kubectl set image deployment/app app=${{ needs.prepare.outputs.image }} -n production
          kubectl rollout status deployment/app -n production --timeout=10m
          kubectl scale deployment/app-canary --replicas=0 -n production

      - name: Notify deployment
        if: always()
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "Production deployment ${{ job.status }}: ${{ needs.prepare.outputs.image }}"
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}
```

---

## Part 2: Semi-Guided Exercise - Pipeline Optimization

### Objective

Optimize the CI/CD pipeline for:
- Faster execution
- Better caching
- Reduced costs
- Improved reliability

### Requirements

1. **Implement caching strategies**

<details>
<summary>Click for caching hint</summary>

```yaml
# Advanced caching
- name: Cache Go modules
  uses: actions/cache@v4
  with:
    path: |
      ~/.cache/go-build
      ~/go/pkg/mod
    key: go-${{ runner.os }}-${{ hashFiles('**/go.sum') }}
    restore-keys: |
      go-${{ runner.os }}-

- name: Cache Docker layers
  uses: docker/build-push-action@v5
  with:
    cache-from: |
      type=gha
      type=registry,ref=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:buildcache
    cache-to: type=gha,mode=max
```
</details>

2. **Implement test sharding**

<details>
<summary>Click for sharding hint</summary>

```yaml
test:
  strategy:
    matrix:
      shard: [1, 2, 3, 4]
  steps:
    - name: Run sharded tests
      run: |
        TOTAL_SHARDS=4
        SHARD=${{ matrix.shard }}
        go test -v $(go list ./... | awk "NR % $TOTAL_SHARDS == ($SHARD - 1)")
```
</details>

3. **Set up self-hosted runners**

### Tasks

1. Analyze current pipeline timing
2. Implement parallel job execution
3. Configure intelligent caching
4. Set up self-hosted runners for heavy workloads
5. Implement test impact analysis

### Validation

```yaml
# Add timing analysis
- name: Pipeline timing
  run: |
    echo "Job: ${{ github.job }}"
    echo "Started: ${{ github.event.workflow_run.created_at }}"
    echo "Completed: $(date -Iseconds)"
```

---

## Part 3: Challenge - Production-Ready Pipeline Platform

### Objective

Build a complete CI/CD platform with:
- Multi-repository support
- Centralized configuration
- Monitoring and alerting
- Cost optimization

### Requirements

1. **Create reusable workflow library**

```yaml
# .github/workflows/reusable-build.yml
name: Reusable Build

on:
  workflow_call:
    inputs:
      go-version:
        type: string
        default: '1.21'
      image-name:
        type: string
        required: true
    outputs:
      image:
        description: 'Built image reference'
        value: ${{ jobs.build.outputs.image }}
    secrets:
      registry-token:
        required: true

jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      image: ${{ steps.build.outputs.image }}
    steps:
      - uses: actions/checkout@v4
      # ... build steps
```

2. **Implement pipeline observability**

3. **Set up cost monitoring**

4. **Create pipeline documentation**

### Success Criteria

- [ ] Pipeline completes in < 10 minutes
- [ ] All security scans pass
- [ ] Multi-environment deployment works
- [ ] Monitoring dashboards configured
- [ ] Alerting rules defined
- [ ] Cost tracking enabled
- [ ] Documentation complete

### Starting Point - Pipeline Metrics

```yaml
# monitoring/pipeline-metrics.yml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: pipeline-alerts
spec:
  groups:
    - name: pipeline
      rules:
        - alert: PipelineFailureRate
          expr: |
            rate(github_workflow_run_status{status="failure"}[1h])
            / rate(github_workflow_run_status[1h]) > 0.1
          for: 15m
          labels:
            severity: warning
          annotations:
            summary: "High pipeline failure rate"

        - alert: PipelineDuration
          expr: |
            github_workflow_run_duration_seconds{workflow="CI Pipeline"} > 900
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "Pipeline taking too long"
```

### Starting Point - Cost Dashboard

```yaml
# Grafana dashboard for pipeline costs
apiVersion: v1
kind: ConfigMap
metadata:
  name: pipeline-dashboard
data:
  dashboard.json: |
    {
      "title": "CI/CD Pipeline Costs",
      "panels": [
        {
          "title": "Runner Minutes Used",
          "type": "stat",
          "targets": [
            {
              "expr": "sum(github_actions_runner_minutes_used)"
            }
          ]
        },
        {
          "title": "Cost by Workflow",
          "type": "piechart",
          "targets": [
            {
              "expr": "sum by (workflow) (github_actions_runner_minutes_used * 0.008)"
            }
          ]
        }
      ]
    }
```

### Validation Script

```bash
#!/bin/bash
# validate-cicd-integration.sh

echo "Validating CI/CD Integration..."

# Check workflow files
echo "=== Workflow Files ==="
WORKFLOWS=$(ls .github/workflows/*.yml 2>/dev/null | wc -l)
echo "✓ Found $WORKFLOWS workflow files"

# Validate YAML syntax
for workflow in .github/workflows/*.yml; do
    if python3 -c "import yaml; yaml.safe_load(open('$workflow'))" 2>/dev/null; then
        echo "✓ Valid: $workflow"
    else
        echo "✗ Invalid: $workflow"
    fi
done

# Check for required jobs
echo ""
echo "=== Required Jobs ==="
for job in lint test build deploy; do
    if grep -rq "name:.*$job" .github/workflows/; then
        echo "✓ Job '$job' found"
    else
        echo "⚠ Job '$job' not found"
    fi
done

# Check security
echo ""
echo "=== Security Checks ==="
if grep -rq "trivy" .github/workflows/; then
    echo "✓ Container scanning configured"
fi
if grep -rq "cosign" .github/workflows/; then
    echo "✓ Image signing configured"
fi
if grep -rq "permissions:" .github/workflows/; then
    echo "✓ Permissions defined"
fi

# Check environments
echo ""
echo "=== Environments ==="
ENVS=$(grep -rh "environment:" .github/workflows/ | sort -u | wc -l)
echo "✓ $ENVS environments configured"

# Check Kubernetes manifests
echo ""
echo "=== Kubernetes Manifests ==="
if [ -d "k8s" ]; then
    MANIFESTS=$(find k8s -name "*.yaml" | wc -l)
    echo "✓ Found $MANIFESTS Kubernetes manifests"
fi

# Check monitoring
echo ""
echo "=== Monitoring ==="
if [ -d "monitoring" ]; then
    echo "✓ Monitoring configuration exists"
fi

# Check documentation
echo ""
echo "=== Documentation ==="
if [ -f "docs/pipeline.md" ]; then
    echo "✓ Pipeline documentation exists"
else
    echo "⚠ Pipeline documentation missing"
fi

echo ""
echo "Validation complete!"
```

---

## Cleanup

```bash
# Remove lab files
cd ~
rm -rf cicd-integration-lab

# Clean up Kubernetes resources
kubectl delete namespace staging production --ignore-not-found
```

## Summary

In this capstone lab, you learned:
- Designing end-to-end CI/CD pipelines
- Implementing comprehensive testing strategies
- Configuring security scanning and signing
- Setting up multi-environment deployments
- Optimizing pipeline performance
- Monitoring and alerting for pipelines
- Documenting pipeline infrastructure

## Phase 4 Completion

Congratulations! You've completed Phase 4: CI/CD & GitOps. You now have the skills to:

- Build and maintain CI/CD pipelines
- Implement GitOps workflows with ArgoCD
- Use various CI/CD platforms (Jenkins, GitHub Actions, GitLab CI)
- Implement deployment strategies (rolling, blue-green, canary)
- Secure the software supply chain
- Manage artifacts and releases
- Implement feature flags for progressive delivery

## Next Steps

- Explore advanced GitOps patterns
- Implement multi-cluster deployments
- Set up disaster recovery for CI/CD
- Continue to Phase 5: Observability & SRE

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Challenge - Production-Ready Pipeline Platform
- Phase 4 Completion
- Create Comprehensive CI Workflow
- Create CD Workflow

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
