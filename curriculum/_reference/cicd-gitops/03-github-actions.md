# Module 03: GitHub Actions

## Learning Objectives

By the end of this module, you will be able to:
- Create and configure GitHub Actions workflows
- Use workflow triggers, events, and conditions
- Implement reusable workflows and composite actions
- Manage secrets and environment variables securely
- Optimize workflows for performance and cost
- Integrate GitHub Actions with external services

## Introduction

GitHub Actions is GitHub's integrated CI/CD platform that enables you to automate builds, tests, and deployments directly within your repository. With its native integration into the GitHub ecosystem, Actions provides a seamless developer experience for automating software workflows.

## GitHub Actions Architecture

### Core Concepts

<!-- figure: generated from the Mermaid below by _shared/diagrams/embed-figures.py — do not edit the image -->
![Core Concepts — diagram](../../../_figures/curriculum-_reference-cicd-gitops-03-github-actions-0-2b75c856.png)

<details>
<summary>Diagram source (Mermaid)</summary>

```mermaid
%%{init: {'theme':'base','themeVariables':{'fontFamily':'Helvetica, Arial, sans-serif','fontSize':'13px','primaryColor':'#ffffff','primaryTextColor':'#2d3436','primaryBorderColor':'#9aa3ab','lineColor':'#9aa3ab','textColor':'#2d3436','clusterBkg':'#fbfcfd','clusterBorder':'#d4dae0','edgeLabelBackground':'#ffffff','tertiaryColor':'#eef4fb'},'flowchart':{'curve':'basis','padding':14,'nodeSpacing':42,'rankSpacing':58}}}%%
flowchart TB
  classDef default fill:#ffffff,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef n    fill:#ffffff,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef crit fill:#eef4fb,stroke:#2f6fb8,stroke-width:1.8px,color:#1b3a5c
  classDef data fill:#f4f7fa,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef mut  fill:#ffffff,stroke:#cfd6dc,stroke-width:1.1px,color:#7a8288
  classDef warn fill:#fdf0ec,stroke:#c0522d,stroke-width:1.6px,color:#8a3a1e
  subgraph REPO["Repository"]
    direction TB
    WF[".github/workflows/<br/><small>ci.yml · cd.yml · release.yml</small>"]:::crit
    ACT[".github/actions/<br/><small>composite actions</small>"]:::n
  end
  EV["Events<br/><small>push · pull_request · schedule · workflow_dispatch</small>"]:::n
  RUN["Runners<br/><small>GitHub-hosted (ephemeral) or self-hosted</small>"]:::n
  subgraph JOBS["Jobs · parallel by default, ordered with <code>needs:</code>"]
    direction LR
    J1["test"]:::n
    J2["build"]:::n
    J3["deploy"]:::crit
  end
  OIDC["OIDC token → STS<br/><small>no static cloud credentials</small>"]:::crit

  EV --> WF --> RUN --> JOBS
  ACT -.-> JOBS
  J3 --> OIDC

  linkStyle 0,1,2,4 stroke:#2f6fb8,stroke-width:2px
```

</details>

### Key Components

| Component | Description |
|-----------|-------------|
| **Workflow** | Automated process defined in YAML |
| **Event** | Trigger that starts a workflow |
| **Job** | Set of steps running on same runner |
| **Step** | Individual task within a job |
| **Action** | Reusable unit of code |
| **Runner** | Server that executes workflows |

## Workflow Syntax

### Basic Workflow Structure

```yaml
# .github/workflows/ci.yml
name: CI Pipeline

# Workflow triggers
on:
  push:
    branches: [main, develop]
    paths:
      - 'src/**'
      - 'tests/**'
  pull_request:
    branches: [main]
  workflow_dispatch:
    inputs:
      environment:
        description: 'Target environment'
        required: true
        default: 'staging'
        type: choice
        options:
          - staging
          - production
  schedule:
    - cron: '0 6 * * 1'  # Every Monday at 6 AM

# Environment variables for entire workflow
env:
  NODE_VERSION: '20'
  REGISTRY: ghcr.io

# Concurrency control
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

# Default settings
defaults:
  run:
    shell: bash
    working-directory: ./app

# Permissions for GITHUB_TOKEN
permissions:
  contents: read
  packages: write
  pull-requests: write

jobs:
  build:
    name: Build Application
    runs-on: ubuntu-latest
    timeout-minutes: 15

    outputs:
      version: ${{ steps.version.outputs.value }}
      artifact-name: ${{ steps.build.outputs.artifact }}

    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'

      - name: Get version
        id: version
        run: echo "value=$(node -p "require('./package.json').version")" >> $GITHUB_OUTPUT

      - name: Install dependencies
        run: npm ci

      - name: Build
        id: build
        run: |
          npm run build
          echo "artifact=dist-${{ steps.version.outputs.value }}" >> $GITHUB_OUTPUT

      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: ${{ steps.build.outputs.artifact }}
          path: dist/
          retention-days: 7

  test:
    name: Run Tests
    needs: build
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        test-type: [unit, integration, e2e]
        node-version: [18, 20]

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node-version }}
          cache: 'npm'

      - run: npm ci

      - name: Run ${{ matrix.test-type }} tests
        run: npm run test:${{ matrix.test-type }}

      - name: Upload coverage
        if: matrix.test-type == 'unit'
        uses: actions/upload-artifact@v4
        with:
          name: coverage-${{ matrix.node-version }}
          path: coverage/

  deploy:
    name: Deploy
    needs: [build, test]
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    environment:
      name: production
      url: https://app.example.com

    steps:
      - name: Download artifact
        uses: actions/download-artifact@v4
        with:
          name: ${{ needs.build.outputs.artifact-name }}

      - name: Deploy to production
        run: |
          echo "Deploying version ${{ needs.build.outputs.version }}"
          # Deployment commands here
```

## Event Triggers

### Push and Pull Request Events

```yaml
on:
  push:
    branches:
      - main
      - 'releases/**'
      - '!releases/**-beta'  # Exclude beta releases
    tags:
      - 'v*'
    paths:
      - 'src/**'
      - '!src/**/*.md'  # Exclude markdown files
    paths-ignore:
      - 'docs/**'
      - '*.md'

  pull_request:
    types: [opened, synchronize, reopened, ready_for_review]
    branches:
      - main
      - develop

  pull_request_target:
    types: [opened]
    # Runs in context of base repository (for forks)
```

### Manual and Scheduled Triggers

```yaml
on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Deployment environment'
        required: true
        type: choice
        options:
          - development
          - staging
          - production
      version:
        description: 'Version to deploy'
        required: false
        type: string
      dry-run:
        description: 'Dry run mode'
        type: boolean
        default: false

  schedule:
    # Run at midnight UTC every day
    - cron: '0 0 * * *'
    # Run every 6 hours
    - cron: '0 */6 * * *'

  # Trigger from other workflows
  workflow_call:
    inputs:
      artifact-name:
        required: true
        type: string
    secrets:
      deploy-token:
        required: true
```

### Repository Events

```yaml
on:
  # Issue events
  issues:
    types: [opened, labeled]

  # Comment events
  issue_comment:
    types: [created]

  # Release events
  release:
    types: [published, created]

  # Repository events
  create:  # Branch or tag created
  delete:  # Branch or tag deleted

  # Deployment events
  deployment:
  deployment_status:

  # Package events
  registry_package:
    types: [published, updated]
```

## Job Configuration

### Job Dependencies and Conditions

```yaml
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm run lint

  test:
    runs-on: ubuntu-latest
    needs: lint  # Runs after lint
    steps:
      - uses: actions/checkout@v4
      - run: npm test

  build:
    runs-on: ubuntu-latest
    needs: [lint, test]  # Runs after both
    steps:
      - uses: actions/checkout@v4
      - run: npm run build

  deploy-staging:
    runs-on: ubuntu-latest
    needs: build
    if: github.ref == 'refs/heads/develop'
    environment: staging
    steps:
      - run: ./deploy.sh staging

  deploy-production:
    runs-on: ubuntu-latest
    needs: build
    if: |
      github.ref == 'refs/heads/main' &&
      github.event_name == 'push' &&
      !contains(github.event.head_commit.message, '[skip deploy]')
    environment:
      name: production
      url: https://app.example.com
    steps:
      - run: ./deploy.sh production
```

### Matrix Strategies

```yaml
jobs:
  test:
    runs-on: ${{ matrix.os }}
    strategy:
      fail-fast: false
      max-parallel: 4
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
        node: [18, 20, 22]
        include:
          - os: ubuntu-latest
            node: 20
            coverage: true
        exclude:
          - os: windows-latest
            node: 18

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node }}

      - run: npm ci
      - run: npm test

      - name: Upload coverage
        if: matrix.coverage
        uses: actions/upload-artifact@v4
        with:
          name: coverage
          path: coverage/
```

### Services and Containers

```yaml
jobs:
  test:
    runs-on: ubuntu-latest

    # Sidecar services
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_USER: test
          POSTGRES_PASSWORD: test
          POSTGRES_DB: testdb
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

      redis:
        image: redis:7
        ports:
          - 6379:6379
        options: --health-cmd "redis-cli ping"

    # Run entire job in container
    container:
      image: node:20
      env:
        DATABASE_URL: postgres://test:test@postgres:5432/testdb
        REDIS_URL: redis://redis:6379

    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npm test
```

## Secrets and Variables

### Using Secrets

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Deploy with secrets
        env:
          API_KEY: ${{ secrets.API_KEY }}
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        run: |
          # Secrets are masked in logs
          echo "Using API key ending in ${API_KEY: -4}"
          aws s3 sync ./dist s3://my-bucket/

      - name: Docker login
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
```

### Environment Secrets and Variables

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production

    env:
      # Repository variable
      APP_NAME: ${{ vars.APP_NAME }}
      # Environment variable (overrides repo)
      API_URL: ${{ vars.API_URL }}

    steps:
      - name: Deploy
        env:
          # Environment secret
          DATABASE_URL: ${{ secrets.DATABASE_URL }}
        run: ./deploy.sh
```

### OIDC Authentication

```yaml
jobs:
  deploy-aws:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read

    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/GitHubActionsRole
          aws-region: us-east-1

      - name: Deploy to AWS
        run: |
          aws s3 sync ./dist s3://my-bucket/
          aws cloudfront create-invalidation --distribution-id $DIST_ID --paths "/*"
```

## Reusable Workflows

### Defining Reusable Workflow

```yaml
# .github/workflows/reusable-build.yml
name: Reusable Build Workflow

on:
  workflow_call:
    inputs:
      node-version:
        description: 'Node.js version'
        required: false
        type: string
        default: '20'
      artifact-name:
        description: 'Name for the build artifact'
        required: true
        type: string
      environment:
        description: 'Target environment'
        required: false
        type: string
        default: 'development'

    secrets:
      npm-token:
        description: 'NPM authentication token'
        required: false

    outputs:
      version:
        description: 'Built version'
        value: ${{ jobs.build.outputs.version }}
      artifact-path:
        description: 'Path to artifact'
        value: ${{ jobs.build.outputs.artifact-path }}

jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      version: ${{ steps.version.outputs.value }}
      artifact-path: ${{ steps.upload.outputs.artifact-path }}

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: ${{ inputs.node-version }}
          cache: 'npm'

      - name: Configure NPM
        if: secrets.npm-token
        run: echo "//registry.npmjs.org/:_authToken=${{ secrets.npm-token }}" >> ~/.npmrc

      - name: Install dependencies
        run: npm ci

      - name: Get version
        id: version
        run: echo "value=$(node -p "require('./package.json').version")" >> $GITHUB_OUTPUT

      - name: Build
        run: npm run build
        env:
          NODE_ENV: ${{ inputs.environment }}

      - name: Upload artifact
        id: upload
        uses: actions/upload-artifact@v4
        with:
          name: ${{ inputs.artifact-name }}
          path: dist/
```

### Calling Reusable Workflow

```yaml
# .github/workflows/main.yml
name: Main Pipeline

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build:
    uses: ./.github/workflows/reusable-build.yml
    with:
      node-version: '20'
      artifact-name: 'app-build'
      environment: 'production'
    secrets:
      npm-token: ${{ secrets.NPM_TOKEN }}

  deploy:
    needs: build
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - name: Download artifact
        uses: actions/download-artifact@v4
        with:
          name: app-build

      - name: Deploy
        run: |
          echo "Deploying version ${{ needs.build.outputs.version }}"
          # Deployment steps
```

## Composite Actions

### Creating Composite Action

```yaml
# .github/actions/setup-app/action.yml
name: 'Setup Application'
description: 'Setup Node.js and install dependencies'

inputs:
  node-version:
    description: 'Node.js version'
    required: false
    default: '20'
  install-command:
    description: 'Install command to run'
    required: false
    default: 'npm ci'
  working-directory:
    description: 'Working directory'
    required: false
    default: '.'

outputs:
  cache-hit:
    description: 'Whether cache was hit'
    value: ${{ steps.cache.outputs.cache-hit }}

runs:
  using: 'composite'
  steps:
    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: ${{ inputs.node-version }}

    - name: Get npm cache directory
      id: npm-cache-dir
      shell: bash
      run: echo "dir=$(npm config get cache)" >> $GITHUB_OUTPUT

    - name: Cache npm dependencies
      id: cache
      uses: actions/cache@v4
      with:
        path: ${{ steps.npm-cache-dir.outputs.dir }}
        key: npm-${{ runner.os }}-${{ hashFiles('**/package-lock.json') }}
        restore-keys: |
          npm-${{ runner.os }}-

    - name: Install dependencies
      shell: bash
      working-directory: ${{ inputs.working-directory }}
      run: ${{ inputs.install-command }}
```

### Using Composite Action

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup application
        uses: ./.github/actions/setup-app
        with:
          node-version: '20'
          working-directory: './app'

      - name: Build
        run: npm run build
        working-directory: ./app
```

## GitHub Packages and Container Registry

### Building and Pushing Container Images

```yaml
name: Build and Push Container

on:
  push:
    branches: [main]
    tags: ['v*']

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - uses: actions/checkout@v4

      - name: Setup Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to Container Registry
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
            type=ref,event=branch
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=sha

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
          platforms: linux/amd64,linux/arm64
```

## Performance Optimization

### Caching Strategies

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      # Node.js with built-in caching
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      # Manual cache for other dependencies
      - name: Cache Playwright browsers
        uses: actions/cache@v4
        with:
          path: ~/.cache/ms-playwright
          key: playwright-${{ runner.os }}-${{ hashFiles('**/package-lock.json') }}

      # Cache dependencies between workflows
      - name: Cache build output
        uses: actions/cache@v4
        with:
          path: |
            .next/cache
            node_modules/.cache
          key: build-cache-${{ github.sha }}
          restore-keys: |
            build-cache-

      - run: npm ci
      - run: npm run build
```

### Parallel and Conditional Execution

```yaml
jobs:
  changes:
    runs-on: ubuntu-latest
    outputs:
      frontend: ${{ steps.filter.outputs.frontend }}
      backend: ${{ steps.filter.outputs.backend }}
      docs: ${{ steps.filter.outputs.docs }}
    steps:
      - uses: actions/checkout@v4
      - uses: dorny/paths-filter@v3
        id: filter
        with:
          filters: |
            frontend:
              - 'frontend/**'
            backend:
              - 'backend/**'
            docs:
              - 'docs/**'

  frontend-build:
    needs: changes
    if: needs.changes.outputs.frontend == 'true'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: cd frontend && npm ci && npm run build

  backend-build:
    needs: changes
    if: needs.changes.outputs.backend == 'true'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: cd backend && go build ./...

  docs-build:
    needs: changes
    if: needs.changes.outputs.docs == 'true'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: cd docs && npm ci && npm run build
```

## Self-Hosted Runners

### Runner Configuration

```yaml
# Using self-hosted runners
jobs:
  build:
    runs-on: [self-hosted, linux, x64, gpu]
    steps:
      - uses: actions/checkout@v4
      - run: nvidia-smi  # GPU available
      - run: ./train-model.sh

  deploy:
    runs-on: [self-hosted, production]
    environment: production
    steps:
      - name: Deploy to internal network
        run: ./deploy-internal.sh
```

### Runner Groups and Labels

```yaml
jobs:
  security-scan:
    runs-on:
      group: secure-runners
      labels: [self-hosted, linux]
    steps:
      - uses: actions/checkout@v4
      - run: ./security-scan.sh

  performance-test:
    runs-on:
      labels: [self-hosted, high-memory]
    steps:
      - uses: actions/checkout@v4
      - run: ./perf-test.sh
```

## GitHub Actions Security

### Security Best Practices

```yaml
# Secure workflow example
name: Secure CI

on:
  pull_request:
    branches: [main]

# Minimal permissions
permissions:
  contents: read

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4
        with:
          persist-credentials: false

      # Pin action versions to SHA
      - uses: actions/setup-node@8f152de45cc393bb48ce5d89d36b731f54556e65 # v4.0.0
        with:
          node-version: '20'

      # Don't expose secrets to PRs from forks
      - name: Build
        run: npm run build
        env:
          # Only use non-sensitive build config
          NODE_ENV: production

  # Separate job for deployment (main branch only)
  deploy:
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    needs: build
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    environment: production

    steps:
      - uses: actions/checkout@v4

      # Use OIDC for cloud authentication
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ vars.AWS_ROLE_ARN }}
          aws-region: us-east-1

      - run: ./deploy.sh
```

## Hands-On Exercise

### Exercise: Create a Complete CI/CD Pipeline

1. Create a workflow that:
   - Runs on push and PR to main
   - Builds and tests in parallel
   - Uses matrix strategy for multiple Node versions
   - Caches dependencies
   - Builds and pushes Docker image
   - Deploys to staging/production environments

2. Create a reusable workflow for deployment
3. Implement OIDC authentication for cloud deployment
4. Add status checks and branch protection

## Summary

- GitHub Actions provides native CI/CD integrated with GitHub
- Workflows are defined in YAML and triggered by events
- Jobs can run in parallel or sequentially with dependencies
- Matrix strategies enable testing across multiple configurations
- Reusable workflows and composite actions promote code reuse
- OIDC enables secure, keyless authentication to cloud providers
- Caching and parallel execution optimize workflow performance

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [GitHub Actions Marketplace](https://github.com/marketplace?type=actions)
- [Actions Security Hardening](https://docs.github.com/en/actions/security-guides)
- [Reusable Workflows](https://docs.github.com/en/actions/using-workflows/reusing-workflows)

## Next Steps

In the next module, we'll explore GitLab CI/CD, learning its unique features and how to build efficient pipelines in the GitLab ecosystem.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- GitHub Actions Architecture
- Workflow Syntax
- Event Triggers
- Job Configuration

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"The pipeline deploys the application."* |
| ✓ | *"CI writes a new image tag into a config repository and stops. A controller running *inside* the cluster polls that repo, diffs the rendered manifests against live state, and applies the difference — so nothing outside the cluster ever holds credentials to it."* |

**Trace it:** `git push` → the new version serving traffic, with nothing else typed. Name where the handoff between CI and CD happens, and what that handoff physically is.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** the four [OpenGitOps principles](https://opengitops.dev/#principles) — then say which one a `kubectl apply` inside CI violates.
Full list per domain: [`SOURCES.md`](../SOURCES.md#cicd-gitops)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../MASTERY.md)

<!-- /feynman-check -->
