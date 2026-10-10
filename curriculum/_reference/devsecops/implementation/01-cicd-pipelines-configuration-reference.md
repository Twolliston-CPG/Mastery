# CI/CD Pipelines — Configuration Reference

## Reusable Workflow Inputs

### reusable-go-ci.yml

```yaml
inputs:
  service-name:          # REQUIRED. Service identifier (e.g., "api-gateway-go")
    type: string
  go-version:            # Go compiler version
    type: string
    default: '1.22'
  needs-postgres:        # Spin up PostgreSQL service container for tests
    type: boolean
    default: false
  needs-redis:           # Spin up Redis service container for tests
    type: boolean
    default: false
  coverage-threshold:    # Minimum test coverage % (fail if below)
    type: number
    default: 60          # Go default is lower than Node.js (60 vs 80)
                         # because Go's coverage tooling counts differently
```

**Service containers** (when enabled):
```yaml
services:
  postgres:
    image: postgres:15
    env:
      POSTGRES_USER: test
      POSTGRES_PASSWORD: test
      POSTGRES_DB: test_db
    ports: ['5432:5432']
    options: >-          # Health check ensures DB is ready before tests run
      --health-cmd pg_isready
      --health-interval 10s
      --health-timeout 5s
      --health-retries 5

  redis:
    image: redis:7-alpine
    ports: ['6379:6379']
    options: >-
      --health-cmd "redis-cli ping"
      --health-interval 10s
      --health-timeout 5s
      --health-retries 5
```

### reusable-ci.yml (Node.js)

```yaml
inputs:
  service-name:          # REQUIRED. Service identifier (e.g., "auth-service")
    type: string
  node-version:          # Node.js version
    type: string
    default: '18'
  needs-postgres:        # PostgreSQL service container
    type: boolean
    default: false
  needs-redis:           # Redis service container
    type: boolean
    default: false
  coverage-threshold:    # Minimum test coverage %
    type: number
    default: 80          # Higher than Go because Node.js coverage tools
                         # count line coverage more precisely

secrets:
  NPM_TOKEN:             # GitHub Packages token for @{{ORG_NAME}} scope
    required: true
  CODECOV_TOKEN:          # Codecov upload token
    required: false
```

### reusable-go-slsa-build.yml

```yaml
inputs:
  service-name:          # REQUIRED. Service identifier
    type: string
  go-version:            # Go compiler version (must match CI)
    type: string
    default: '1.22'
  dockerfile:            # Path to Dockerfile
    type: string
    default: './Dockerfile'
  registry:              # Container registry URL
    type: string
    default: ''          # Uses {{REGISTRY_URL}} when empty
```

**Build arguments injected automatically**:
- `CGO_ENABLED=0` — static binary, no C dependencies
- `GOPROXY=off` — hermetic, no network fetches during build
- `--network none` — Docker build with no network access

### reusable-deploy-staging.yml / reusable-go-deploy-staging.yml

```yaml
inputs:
  service-name:          # REQUIRED. Service identifier
    type: string
  environment:           # Deployment environment
    type: string
    default: 'staging'
  smoke-test-endpoints:  # Comma-separated health check paths
    type: string
    default: '/health/live,/health/ready,/health'
  run-integration-tests: # Run integration tests post-deploy
    type: boolean
    default: true
  run-dast:              # Run DAST scan post-deploy
    type: boolean
    default: true
```

### reusable-deploy-production.yml / reusable-go-deploy-production.yml

```yaml
inputs:
  service-name:          # REQUIRED. Service identifier
    type: string
  version:               # Specific commit SHA to deploy (optional)
    type: string
    default: ''          # Uses latest when empty
  rollback:              # Trigger rollback instead of deploy
    type: boolean
    default: false
  canary-percentage:     # Initial canary traffic percentage
    type: number
    default: 10
  canary-duration:       # Observation window before full rollout
    type: string
    default: '30m'
```

## Caching Configuration

### GitHub Actions Cache

```yaml
# Go module cache
- uses: actions/cache@v4
  with:
    path: ~/go/pkg/mod
    key: ${{ runner.os }}-go-${{ hashFiles('**/go.sum') }}
    restore-keys: ${{ runner.os }}-go-

# npm cache
- uses: actions/cache@v4
  with:
    path: ~/.npm
    key: ${{ runner.os }}-npm-${{ hashFiles('**/package-lock.json') }}
    restore-keys: ${{ runner.os }}-npm-
```

**Limits**:
- 10GB per repository
- 7-day retention for unused cache entries
- LRU eviction when limit reached

### Docker BuildKit Cache

```yaml
- uses: docker/build-push-action@v5
  with:
    cache-from: type=gha          # Use GitHub Actions cache backend
    cache-to: type=gha,mode=max   # Cache all layers, not just final
```

## Cosign Signing Configuration

```yaml
# Keyless signing using GitHub Actions OIDC
- uses: sigstore/cosign-installer@v3

- run: cosign sign --yes ${{ env.IMAGE_REF }}
  env:
    COSIGN_EXPERIMENTAL: 1        # Enable keyless mode
    # OIDC identity is automatically provided by GitHub Actions
    # No COSIGN_KEY or COSIGN_PASSWORD needed
```

**Verification**:
```bash
# Verify an image signature
cosign verify \
  --certificate-identity-regexp="https://github.com/{{ORG_NAME}}/" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  {{REGISTRY_URL}}/{{SERVICE_NAME}}:v1.0.0
```

## SBOM Generation Configuration

```yaml
# Syft generates both SPDX and CycloneDX
- uses: anchore/sbom-action@v0
  with:
    image: ${{ env.IMAGE_REF }}
    output-file: sbom-spdx.json
    format: spdx-json

- uses: anchore/sbom-action@v0
  with:
    image: ${{ env.IMAGE_REF }}
    output-file: sbom-cyclonedx.json
    format: cyclonedx-json

# Attach SBOMs to image in registry
- run: |
    cosign attach sbom --sbom sbom-spdx.json ${{ env.IMAGE_REF }}
    cosign attach sbom --sbom sbom-cyclonedx.json ${{ env.IMAGE_REF }}
```

## ArgoCD Image Updater Configuration

```yaml
# Annotation on ArgoCD Application
metadata:
  annotations:
    argocd-image-updater.argoproj.io/image-list: >-
      {{SERVICE_NAME}}={{REGISTRY_URL}}/{{SERVICE_NAME}}
    argocd-image-updater.argoproj.io/{{SERVICE_NAME}}.update-strategy: semver
    argocd-image-updater.argoproj.io/write-back-method: git
    argocd-image-updater.argoproj.io/git-branch: main
```

**Polling interval**: 2 minutes (configured in Image Updater deployment)

## Environment Variables

### Required for Go Services

| Variable | Purpose | Example |
|----------|---------|---------|
| `SERVICE_NAME` | Service identifier | `api-gateway` |
| `PORT` | Listen port | `3000` |
| `LOG_LEVEL` | Zerolog level | `info` |
| `REDIS_URL` | Redis connection | `redis://redis:6379` |
| `DATABASE_URL` | PostgreSQL connection | `postgres://user:pass@host/db` |

### Required for Node.js Services

| Variable | Purpose | Example |
|----------|---------|---------|
| `SERVICE_NAME` | Service identifier | `auth-service` |
| `PORT` | Listen port | `3001` |
| `NODE_ENV` | Runtime environment | `production` |
| `DATABASE_URL` | Prisma connection string | `postgresql://user:pass@host/db` |
| `REDIS_URL` | Redis connection | `redis://redis:6379` |

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Reusable Workflow Inputs
- Caching Configuration
- Cosign Signing Configuration
- SBOM Generation Configuration

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"We scan for vulnerabilities in the pipeline."* |
| ✓ | *"SAST reads source without running it, SCA resolves the dependency tree against an advisory database, and image scanning compares installed package versions to that same database. All three report what was known at build time — which is why the registry is re-scanned: the image does not change, the database does."* |

**Trace it:** A CVE published today against your base image → a blocked deploy. Name every component between the advisory and the refused `apply`.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** the [SLSA threat model](https://slsa.dev/spec/v1.2/threats) — it names every point at which a build can be subverted, and most teams defend three of them.
Full list per domain: [`SOURCES.md`](../../SOURCES.md#devsecops)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../../MASTERY.md)

<!-- /feynman-check -->
