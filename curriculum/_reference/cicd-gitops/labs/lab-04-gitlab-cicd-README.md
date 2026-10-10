# Lab 04: GitLab CI/CD

## Overview

In this lab, you'll master GitLab CI/CD by building comprehensive pipelines. You'll learn GitLab-specific features including DAG pipelines, includes, rules, environments, and Auto DevOps.

**Duration**: 3-4 hours
**Difficulty**: Intermediate

## Prerequisites

- GitLab account (gitlab.com or self-hosted)
- Git installed locally
- Docker installed
- kubectl configured (for deployment exercises)

## Learning Objectives

- Create multi-stage GitLab CI/CD pipelines
- Implement DAG (Directed Acyclic Graph) pipelines
- Use includes, extends, and anchors for DRY configurations
- Configure environments and deployment strategies
- Implement security scanning with GitLab SAST/DAST

## Lab Environment Setup

```bash
# Create lab project
mkdir -p ~/gitlab-cicd-lab && cd ~/gitlab-cicd-lab

# Initialize Git
git init

# Create directory structure
mkdir -p src tests scripts

# Create sample Go application
cat > src/main.go << 'EOF'
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
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(map[string]string{"status": "healthy"})
}

func mainHandler(w http.ResponseWriter, r *http.Request) {
    version := os.Getenv("APP_VERSION")
    if version == "" {
        version = "1.0.0"
    }

    response := Response{
        Message: "Hello from GitLab CI/CD!",
        Version: version,
    }

    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(response)
}

func main() {
    port := os.Getenv("PORT")
    if port == "" {
        port = "8080"
    }

    http.HandleFunc("/", mainHandler)
    http.HandleFunc("/health", healthHandler)

    log.Printf("Server starting on port %s", port)
    log.Fatal(http.ListenAndServe(":"+port, nil))
}
EOF

# Create tests
cat > src/main_test.go << 'EOF'
package main

import (
    "encoding/json"
    "net/http"
    "net/http/httptest"
    "testing"
)

func TestHealthHandler(t *testing.T) {
    req, err := http.NewRequest("GET", "/health", nil)
    if err != nil {
        t.Fatal(err)
    }

    rr := httptest.NewRecorder()
    handler := http.HandlerFunc(healthHandler)
    handler.ServeHTTP(rr, req)

    if status := rr.Code; status != http.StatusOK {
        t.Errorf("handler returned wrong status code: got %v want %v", status, http.StatusOK)
    }

    var response map[string]string
    json.Unmarshal(rr.Body.Bytes(), &response)

    if response["status"] != "healthy" {
        t.Errorf("handler returned unexpected body: got %v want healthy", response["status"])
    }
}

func TestMainHandler(t *testing.T) {
    req, err := http.NewRequest("GET", "/", nil)
    if err != nil {
        t.Fatal(err)
    }

    rr := httptest.NewRecorder()
    handler := http.HandlerFunc(mainHandler)
    handler.ServeHTTP(rr, req)

    if status := rr.Code; status != http.StatusOK {
        t.Errorf("handler returned wrong status code: got %v want %v", status, http.StatusOK)
    }

    var response Response
    json.Unmarshal(rr.Body.Bytes(), &response)

    if response.Message != "Hello from GitLab CI/CD!" {
        t.Errorf("unexpected message: %v", response.Message)
    }
}
EOF

# Create go.mod
cat > go.mod << 'EOF'
module gitlab-demo

go 1.21
EOF

# Create Dockerfile
cat > Dockerfile << 'EOF'
# Build stage
FROM golang:1.21-alpine AS builder

WORKDIR /app

COPY go.mod ./
RUN go mod download

COPY src/ ./src/

RUN CGO_ENABLED=0 GOOS=linux go build -o /app/server ./src/

# Runtime stage
FROM alpine:3.19

RUN apk --no-cache add ca-certificates

WORKDIR /app

COPY --from=builder /app/server .

EXPOSE 8080

USER nobody

CMD ["./server"]
EOF
```

---

## Part 1: Guided Exercise - Basic GitLab CI/CD Pipeline

### Step 1: Create Basic Pipeline

```bash
cat > .gitlab-ci.yml << 'EOF'
# Define stages
stages:
  - build
  - test
  - security
  - package
  - deploy

# Global variables
variables:
  GO_VERSION: "1.21"
  DOCKER_DRIVER: overlay2
  DOCKER_TLS_CERTDIR: "/certs"

# Default settings
default:
  image: golang:${GO_VERSION}-alpine
  before_script:
    - go version

# Cache configuration
cache:
  key: ${CI_COMMIT_REF_SLUG}
  paths:
    - .go/pkg/mod/

# Build job
build:
  stage: build
  script:
    - mkdir -p .go
    - export GOPATH="$CI_PROJECT_DIR/.go"
    - go build -o bin/server ./src/
  artifacts:
    paths:
      - bin/
    expire_in: 1 hour

# Unit tests
test:unit:
  stage: test
  script:
    - go test -v -race -coverprofile=coverage.out ./src/...
    - go tool cover -func=coverage.out
  coverage: '/total:\s+\(statements\)\s+(\d+\.\d+)%/'
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage.xml

# Integration tests
test:integration:
  stage: test
  services:
    - name: postgres:15
      alias: db
  variables:
    POSTGRES_DB: test
    POSTGRES_USER: test
    POSTGRES_PASSWORD: test
    DATABASE_URL: "postgres://test:test@db:5432/test"
  script:
    - echo "Running integration tests..."
    - go test -v -tags=integration ./src/...

# Security scanning
sast:
  stage: security
  image: registry.gitlab.com/security-products/sast:latest
  variables:
    SAST_EXCLUDED_PATHS: "vendor, .go"
  artifacts:
    reports:
      sast: gl-sast-report.json

# Build Docker image
docker:build:
  stage: package
  image: docker:24
  services:
    - docker:24-dind
  variables:
    DOCKER_HOST: tcp://docker:2376
    DOCKER_TLS_VERIFY: "1"
  before_script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
  script:
    - docker build -t $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA .
    - docker push $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
    - |
      if [ "$CI_COMMIT_BRANCH" == "main" ]; then
        docker tag $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA $CI_REGISTRY_IMAGE:latest
        docker push $CI_REGISTRY_IMAGE:latest
      fi
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
    - if: $CI_COMMIT_BRANCH == "develop"
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"

# Deploy to staging
deploy:staging:
  stage: deploy
  image: bitnami/kubectl:latest
  environment:
    name: staging
    url: https://staging.example.com
  script:
    - kubectl set image deployment/app app=$CI_REGISTRY_IMAGE:$CI_COMMIT_SHA -n staging
  rules:
    - if: $CI_COMMIT_BRANCH == "develop"

# Deploy to production
deploy:production:
  stage: deploy
  image: bitnami/kubectl:latest
  environment:
    name: production
    url: https://app.example.com
  script:
    - kubectl set image deployment/app app=$CI_REGISTRY_IMAGE:$CI_COMMIT_SHA -n production
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
      when: manual
  allow_failure: false
EOF
```

### Step 2: Create DAG Pipeline

```bash
cat > .gitlab-ci-dag.yml << 'EOF'
stages:
  - prepare
  - build
  - test
  - deploy

# Jobs can run in parallel when dependencies allow
prepare:deps:
  stage: prepare
  script:
    - go mod download
  artifacts:
    paths:
      - .go/

build:binary:
  stage: build
  needs: [prepare:deps]
  script:
    - go build -o bin/server ./src/
  artifacts:
    paths:
      - bin/

build:docker:
  stage: build
  needs: [prepare:deps]
  image: docker:24
  services:
    - docker:24-dind
  script:
    - docker build -t $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA .
    - docker push $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA

# Tests run in parallel after build:binary
test:unit:
  stage: test
  needs: [build:binary]
  script:
    - go test -v ./src/...

test:lint:
  stage: test
  needs: [prepare:deps]
  image: golangci/golangci-lint:latest
  script:
    - golangci-lint run ./src/...

test:security:
  stage: test
  needs: [prepare:deps]
  script:
    - go install golang.org/x/vuln/cmd/govulncheck@latest
    - govulncheck ./...

# Deploy only needs docker image, not tests (tests run in parallel)
deploy:staging:
  stage: deploy
  needs:
    - job: build:docker
    - job: test:unit
      artifacts: false
    - job: test:security
      artifacts: false
  environment: staging
  script:
    - echo "Deploying to staging..."
EOF
```

### Step 3: Create Pipeline with Rules

```bash
cat > .gitlab-ci-rules.yml << 'EOF'
# Workflow rules - when to create pipeline
workflow:
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH == "main"
    - if: $CI_COMMIT_BRANCH == "develop"
    - if: $CI_COMMIT_TAG

stages:
  - build
  - test
  - deploy

variables:
  DEPLOY_TO_PROD: "false"

# Build always runs
build:
  stage: build
  script:
    - go build -o bin/server ./src/
  rules:
    - when: always

# Tests run on MRs and protected branches
test:
  stage: test
  script:
    - go test ./src/...
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH =~ /^(main|develop)$/

# Deploy staging on develop
deploy:staging:
  stage: deploy
  environment: staging
  script:
    - echo "Deploying to staging..."
  rules:
    - if: $CI_COMMIT_BRANCH == "develop"
      when: on_success
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
      when: manual
      allow_failure: true

# Deploy production on main with tag
deploy:production:
  stage: deploy
  environment: production
  script:
    - echo "Deploying to production..."
  rules:
    - if: $CI_COMMIT_TAG =~ /^v\d+\.\d+\.\d+$/
      when: manual
    - if: $CI_COMMIT_BRANCH == "main" && $DEPLOY_TO_PROD == "true"
      when: manual

# Cleanup on MR close
cleanup:
  stage: deploy
  script:
    - echo "Cleaning up review environment..."
  environment:
    name: review/$CI_MERGE_REQUEST_IID
    action: stop
  rules:
    - if: $CI_MERGE_REQUEST_EVENT_TYPE == "close"
EOF
```

---

## Part 2: Semi-Guided Exercise - Includes and Templates

### Objective

Create a modular GitLab CI/CD configuration using:
- Template files for reusable jobs
- Includes for shared configurations
- Extends for job inheritance
- YAML anchors for DRY code

### Requirements

1. **Create template files**

<details>
<summary>Click for templates structure hint</summary>

```yaml
# templates/go.yml
.go:setup:
  image: golang:1.21-alpine
  before_script:
    - go version
    - go mod download

.go:build:
  extends: .go:setup
  script:
    - go build -o bin/$CI_PROJECT_NAME ./src/

.go:test:
  extends: .go:setup
  script:
    - go test -v -coverprofile=coverage.out ./src/...
  coverage: '/total:\s+\(statements\)\s+(\d+\.\d+)%/'
```
</details>

2. **Create Docker template**

<details>
<summary>Click for Docker template hint</summary>

```yaml
# templates/docker.yml
.docker:build:
  image: docker:24
  services:
    - docker:24-dind
  variables:
    DOCKER_HOST: tcp://docker:2376
  before_script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
  script:
    - docker build -t $IMAGE_NAME:$CI_COMMIT_SHA .
    - docker push $IMAGE_NAME:$CI_COMMIT_SHA
```
</details>

3. **Create deployment template**

<details>
<summary>Click for deployment template hint</summary>

```yaml
# templates/deploy.yml
.deploy:kubernetes:
  image: bitnami/kubectl:latest
  before_script:
    - kubectl config set-cluster k8s --server=$K8S_SERVER
    - kubectl config set-credentials gitlab --token=$K8S_TOKEN
  script:
    - envsubst < k8s/deployment.yml | kubectl apply -f -
```
</details>

### Tasks

1. Create a `templates/` directory with:
   - `go.yml` - Go build and test templates
   - `docker.yml` - Docker build templates
   - `deploy.yml` - Kubernetes deployment templates
   - `security.yml` - Security scanning templates

2. Create a main `.gitlab-ci.yml` that includes templates

3. Use `extends` to inherit from templates

4. Use YAML anchors for repeated configurations

5. Configure remote includes from GitLab's template repository

### Validation

```yaml
# .gitlab-ci.yml
include:
  # Local templates
  - local: 'templates/go.yml'
  - local: 'templates/docker.yml'
  - local: 'templates/deploy.yml'

  # Remote templates
  - remote: 'https://gitlab.com/gitlab-org/gitlab/-/raw/master/lib/gitlab/ci/templates/SAST.gitlab-ci.yml'

  # Project templates
  - project: 'devops/ci-templates'
    ref: main
    file: '/templates/base.yml'

stages:
  - build
  - test
  - security
  - package
  - deploy

build:app:
  extends: .go:build
  stage: build

test:unit:
  extends: .go:test
  stage: test

package:docker:
  extends: .docker:build
  stage: package

deploy:staging:
  extends: .deploy:kubernetes
  stage: deploy
  variables:
    K8S_NAMESPACE: staging
```

---

## Part 3: Challenge - GitLab Auto DevOps and Review Apps

### Objective

Implement a complete GitLab DevOps workflow with:
- Auto DevOps configuration
- Review Apps for merge requests
- Dynamic environments
- Canary deployments
- Feature flags

### Requirements

1. **Configure Auto DevOps**

```yaml
# .gitlab-ci.yml
include:
  - template: Auto-DevOps.gitlab-ci.yml

variables:
  AUTO_DEVOPS_PLATFORM_TARGET: "EC2"
  POSTGRES_ENABLED: "false"
  TEST_DISABLED: "false"
  CODE_QUALITY_DISABLED: "false"
  SAST_DISABLED: "false"
  DAST_DISABLED: "true"
  CONTAINER_SCANNING_DISABLED: "false"
  DEPENDENCY_SCANNING_DISABLED: "false"
  LICENSE_MANAGEMENT_DISABLED: "true"
```

2. **Implement Review Apps**

3. **Configure canary deployments**

4. **Set up feature flags**

### Success Criteria

- [ ] Auto DevOps runs all stages
- [ ] Review apps created for MRs
- [ ] Environments properly configured
- [ ] Canary deployments work
- [ ] Feature flags integrated
- [ ] Cleanup jobs remove old environments

### Starting Point - Review Apps

```yaml
# .gitlab-ci.yml
stages:
  - build
  - test
  - review
  - staging
  - canary
  - production
  - cleanup

variables:
  KUBE_NAMESPACE: $CI_PROJECT_NAME-$CI_ENVIRONMENT_SLUG

# Review app deployment
review:
  stage: review
  image: bitnami/kubectl:latest
  environment:
    name: review/$CI_COMMIT_REF_SLUG
    url: https://$CI_ENVIRONMENT_SLUG.review.example.com
    on_stop: stop_review
    auto_stop_in: 1 week
  script:
    - kubectl create namespace $KUBE_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    - envsubst < k8s/review.yml | kubectl apply -f -
  rules:
    - if: $CI_MERGE_REQUEST_IID

stop_review:
  stage: cleanup
  image: bitnami/kubectl:latest
  environment:
    name: review/$CI_COMMIT_REF_SLUG
    action: stop
  script:
    - kubectl delete namespace $KUBE_NAMESPACE --ignore-not-found
  rules:
    - if: $CI_MERGE_REQUEST_IID
      when: manual
  allow_failure: true

# Canary deployment
canary:
  stage: canary
  image: bitnami/kubectl:latest
  environment:
    name: production
  script:
    - kubectl set image deployment/app-canary app=$CI_REGISTRY_IMAGE:$CI_COMMIT_SHA -n production
    - kubectl scale deployment/app-canary --replicas=1 -n production
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
      when: manual

# Full production deployment
production:
  stage: production
  image: bitnami/kubectl:latest
  environment:
    name: production
    url: https://app.example.com
  script:
    - kubectl set image deployment/app app=$CI_REGISTRY_IMAGE:$CI_COMMIT_SHA -n production
    - kubectl scale deployment/app-canary --replicas=0 -n production
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
      when: manual
  needs: [canary]
```

### Starting Point - Feature Flags

```yaml
# Feature flag integration
.feature_flags:
  before_script:
    - |
      export FEATURE_FLAGS=$(curl -s -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
        "$CI_API_V4_URL/projects/$CI_PROJECT_ID/feature_flags")

deploy:with_flags:
  extends: .feature_flags
  script:
    - |
      if echo $FEATURE_FLAGS | jq -e '.[] | select(.name=="new_feature" and .active==true)'; then
        echo "New feature enabled"
        kubectl set env deployment/app ENABLE_NEW_FEATURE=true -n $KUBE_NAMESPACE
      fi
    - kubectl set image deployment/app app=$CI_REGISTRY_IMAGE:$CI_COMMIT_SHA -n $KUBE_NAMESPACE
```

### Validation Script

```bash
#!/bin/bash
# validate-gitlab-ci.sh

echo "Validating GitLab CI/CD Configuration..."

# Check .gitlab-ci.yml exists
if [ -f ".gitlab-ci.yml" ]; then
    echo "✓ .gitlab-ci.yml exists"
else
    echo "✗ .gitlab-ci.yml not found"
    exit 1
fi

# Validate YAML syntax
if python3 -c "import yaml; yaml.safe_load(open('.gitlab-ci.yml'))" 2>/dev/null; then
    echo "✓ Valid YAML syntax"
else
    echo "✗ Invalid YAML syntax"
    exit 1
fi

# Check for required stages
for stage in build test deploy; do
    if grep -q "stage: $stage" .gitlab-ci.yml; then
        echo "✓ Stage '$stage' defined"
    else
        echo "⚠ Stage '$stage' not found"
    fi
done

# Check for includes
if grep -q "^include:" .gitlab-ci.yml; then
    INCLUDES=$(grep -A 100 "^include:" .gitlab-ci.yml | grep -c "local:\|remote:\|project:")
    echo "✓ Found $INCLUDES includes"
else
    echo "⚠ No includes found"
fi

# Check for environments
ENVS=$(grep -c "environment:" .gitlab-ci.yml)
echo "✓ Found $ENVS environment definitions"

# Check for rules
if grep -q "rules:" .gitlab-ci.yml; then
    echo "✓ Rules-based pipeline configuration"
else
    echo "⚠ Consider using rules instead of only/except"
fi

# Lint with GitLab CI Lint API (requires GITLAB_TOKEN)
if [ -n "$GITLAB_TOKEN" ]; then
    LINT_RESULT=$(curl -s --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
        "$CI_API_V4_URL/projects/$CI_PROJECT_ID/ci/lint" \
        --data-urlencode "content=$(cat .gitlab-ci.yml)")

    if echo "$LINT_RESULT" | jq -e '.valid' > /dev/null; then
        echo "✓ GitLab CI lint passed"
    else
        echo "✗ GitLab CI lint failed:"
        echo "$LINT_RESULT" | jq '.errors[]'
    fi
fi

echo "Validation complete!"
```

---

## Cleanup

```bash
# Remove local lab files
cd ~
rm -rf gitlab-cicd-lab

# Delete GitLab project (if test)
# Via GitLab UI or API

# Clean up Kubernetes resources
# kubectl delete namespace review-* staging production
```

## Summary

In this lab, you learned:
- Creating multi-stage GitLab CI/CD pipelines
- Implementing DAG pipelines for parallel execution
- Using includes, extends, and anchors for DRY configurations
- Configuring environments and review apps
- Implementing canary deployments
- Integrating feature flags

## Next Steps

- Explore GitLab's built-in security scanning
- Implement GitLab Pages for documentation
- Set up GitLab Runners on Kubernetes
- Configure GitLab CI/CD for monorepos

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Challenge - GitLab Auto DevOps and Review Apps
- Create Basic Pipeline
- Create DAG Pipeline
- Create Pipeline with Rules

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
