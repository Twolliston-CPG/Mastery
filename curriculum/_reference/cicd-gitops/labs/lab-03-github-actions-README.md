# Lab 03: GitHub Actions Workflows

## Overview

In this lab, you'll master GitHub Actions by building comprehensive CI/CD workflows. You'll learn workflow syntax, create reusable workflows, implement matrix strategies, and set up self-hosted runners.

**Duration**: 3-4 hours
**Difficulty**: Intermediate

## Prerequisites

- GitHub account
- Git installed locally
- Docker installed
- Basic understanding of YAML syntax

## Learning Objectives

- Create and configure GitHub Actions workflows
- Implement matrix builds for multi-platform testing
- Build reusable workflows and composite actions
- Set up self-hosted runners
- Implement OIDC authentication for cloud deployments

## Lab Environment Setup

```bash
# Create lab repository
mkdir -p ~/github-actions-lab && cd ~/github-actions-lab

# Initialize Git
git init

# Create directory structure
mkdir -p .github/workflows .github/actions/setup-app src tests

# Create sample application
cat > src/main.py << 'EOF'
import os
from typing import Optional

def greet(name: Optional[str] = None) -> str:
    """Return a greeting message."""
    if name:
        return f"Hello, {name}!"
    return "Hello, World!"

def calculate(a: float, b: float, operation: str) -> float:
    """Perform basic arithmetic operations."""
    operations = {
        'add': lambda x, y: x + y,
        'subtract': lambda x, y: x - y,
        'multiply': lambda x, y: x * y,
        'divide': lambda x, y: x / y if y != 0 else float('inf'),
    }
    if operation not in operations:
        raise ValueError(f"Unknown operation: {operation}")
    return operations[operation](a, b)

def get_version() -> str:
    """Return application version."""
    return os.getenv("APP_VERSION", "1.0.0")

if __name__ == "__main__":
    print(greet())
    print(f"Version: {get_version()}")
EOF

# Create tests
cat > tests/test_main.py << 'EOF'
import pytest
from src.main import greet, calculate, get_version

class TestGreet:
    def test_greet_default(self):
        assert greet() == "Hello, World!"

    def test_greet_with_name(self):
        assert greet("GitHub") == "Hello, GitHub!"

class TestCalculate:
    def test_add(self):
        assert calculate(2, 3, 'add') == 5

    def test_subtract(self):
        assert calculate(10, 4, 'subtract') == 6

    def test_multiply(self):
        assert calculate(3, 4, 'multiply') == 12

    def test_divide(self):
        assert calculate(10, 2, 'divide') == 5

    def test_divide_by_zero(self):
        assert calculate(10, 0, 'divide') == float('inf')

    def test_invalid_operation(self):
        with pytest.raises(ValueError):
            calculate(1, 1, 'invalid')

class TestVersion:
    def test_default_version(self, monkeypatch):
        monkeypatch.delenv("APP_VERSION", raising=False)
        assert get_version() == "1.0.0"

    def test_custom_version(self, monkeypatch):
        monkeypatch.setenv("APP_VERSION", "2.0.0")
        assert get_version() == "2.0.0"
EOF

# Create requirements
cat > requirements.txt << 'EOF'
pytest==7.4.3
pytest-cov==4.1.0
ruff==0.1.9
mypy==1.8.0
EOF

# Create pyproject.toml
cat > pyproject.toml << 'EOF'
[project]
name = "github-actions-demo"
version = "1.0.0"
requires-python = ">=3.9"

[tool.pytest.ini_options]
testpaths = ["tests"]
python_files = "test_*.py"

[tool.ruff]
line-length = 100
target-version = "py39"

[tool.mypy]
python_version = "3.9"
strict = true
EOF

# Create Dockerfile
cat > Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY src/ ./src/

ENV PYTHONPATH=/app

CMD ["python", "-m", "src.main"]
EOF
```

---

## Part 1: Guided Exercise - Basic CI Workflow

### Step 1: Create Basic CI Workflow

```bash
cat > .github/workflows/ci.yml << 'EOF'
name: CI Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]
  workflow_dispatch:
    inputs:
      debug:
        description: 'Enable debug mode'
        required: false
        default: false
        type: boolean

env:
  PYTHON_VERSION: '3.11'

jobs:
  lint:
    name: Lint Code
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: ${{ env.PYTHON_VERSION }}
          cache: 'pip'

      - name: Install dependencies
        run: pip install -r requirements.txt

      - name: Run Ruff linter
        run: ruff check src/ tests/

      - name: Run type checking
        run: mypy src/

  test:
    name: Run Tests
    runs-on: ubuntu-latest
    needs: lint
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: ${{ env.PYTHON_VERSION }}
          cache: 'pip'

      - name: Install dependencies
        run: pip install -r requirements.txt

      - name: Run tests with coverage
        run: |
          pytest tests/ -v \
            --cov=src \
            --cov-report=xml \
            --cov-report=html \
            --junitxml=test-results.xml

      - name: Upload coverage report
        uses: actions/upload-artifact@v4
        with:
          name: coverage-report
          path: htmlcov/

      - name: Upload test results
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: test-results
          path: test-results.xml

  build:
    name: Build Docker Image
    runs-on: ubuntu-latest
    needs: test
    outputs:
      image_tag: ${{ steps.meta.outputs.tags }}
      image_digest: ${{ steps.build.outputs.digest }}
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ghcr.io/${{ github.repository }}
          tags: |
            type=sha,prefix=
            type=ref,event=branch
            type=ref,event=pr

      - name: Build image
        id: build
        uses: docker/build-push-action@v5
        with:
          context: .
          push: false
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
          outputs: type=docker,dest=/tmp/image.tar

      - name: Upload image artifact
        uses: actions/upload-artifact@v4
        with:
          name: docker-image
          path: /tmp/image.tar
          retention-days: 1
EOF
```

### Step 2: Create Matrix Build Workflow

```bash
cat > .github/workflows/matrix-test.yml << 'EOF'
name: Matrix Tests

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    name: Test Python ${{ matrix.python-version }} on ${{ matrix.os }}
    runs-on: ${{ matrix.os }}
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
        python-version: ['3.9', '3.10', '3.11', '3.12']
        exclude:
          - os: macos-latest
            python-version: '3.9'
          - os: windows-latest
            python-version: '3.9'
        include:
          - os: ubuntu-latest
            python-version: '3.11'
            coverage: true

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Python ${{ matrix.python-version }}
        uses: actions/setup-python@v5
        with:
          python-version: ${{ matrix.python-version }}
          cache: 'pip'

      - name: Install dependencies
        run: pip install -r requirements.txt

      - name: Run tests
        run: |
          pytest tests/ -v ${{ matrix.coverage && '--cov=src --cov-report=xml' || '' }}

      - name: Upload coverage
        if: matrix.coverage
        uses: codecov/codecov-action@v4
        with:
          files: coverage.xml
          fail_ci_if_error: true
EOF
```

### Step 3: Create Release Workflow

```bash
cat > .github/workflows/release.yml << 'EOF'
name: Release

on:
  push:
    tags:
      - 'v*.*.*'

permissions:
  contents: write
  packages: write
  id-token: write

jobs:
  release:
    name: Create Release
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Generate changelog
        id: changelog
        uses: orhun/git-cliff-action@v3
        with:
          config: cliff.toml
          args: --latest --strip all

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Build package
        run: |
          pip install build
          python -m build

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v1
        with:
          body: ${{ steps.changelog.outputs.content }}
          files: |
            dist/*.whl
            dist/*.tar.gz
          draft: false
          prerelease: ${{ contains(github.ref, '-rc') || contains(github.ref, '-beta') }}

  publish-docker:
    name: Publish Docker Image
    runs-on: ubuntu-latest
    needs: release
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract version
        id: version
        run: echo "VERSION=${GITHUB_REF#refs/tags/v}" >> $GITHUB_OUTPUT

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: |
            ghcr.io/${{ github.repository }}:${{ steps.version.outputs.VERSION }}
            ghcr.io/${{ github.repository }}:latest
          build-args: |
            APP_VERSION=${{ steps.version.outputs.VERSION }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
          provenance: true
          sbom: true
EOF
```

---

## Part 2: Semi-Guided Exercise - Reusable Workflows

### Objective

Create reusable workflows for common CI/CD patterns:
- Standardized testing workflow
- Docker build and push workflow
- Deployment workflow with approvals

### Requirements

1. **Create reusable test workflow**

<details>
<summary>Click for reusable workflow hint</summary>

```yaml
# .github/workflows/reusable-test.yml
name: Reusable Test Workflow

on:
  workflow_call:
    inputs:
      python-version:
        required: false
        type: string
        default: '3.11'
      working-directory:
        required: false
        type: string
        default: '.'
    secrets:
      codecov-token:
        required: false

jobs:
  test:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: ${{ inputs.working-directory }}
    steps:
      # ... test steps
```
</details>

2. **Create reusable Docker workflow**

<details>
<summary>Click for Docker workflow hint</summary>

```yaml
on:
  workflow_call:
    inputs:
      image-name:
        required: true
        type: string
      push:
        required: false
        type: boolean
        default: false
    outputs:
      image-digest:
        description: 'Image digest'
        value: ${{ jobs.build.outputs.digest }}
```
</details>

3. **Create caller workflow**

<details>
<summary>Click for caller workflow hint</summary>

```yaml
jobs:
  test:
    uses: ./.github/workflows/reusable-test.yml
    with:
      python-version: '3.11'
    secrets:
      codecov-token: ${{ secrets.CODECOV_TOKEN }}

  build:
    needs: test
    uses: ./.github/workflows/reusable-docker.yml
    with:
      image-name: my-app
      push: ${{ github.ref == 'refs/heads/main' }}
```
</details>

### Tasks

1. Create a reusable test workflow that accepts:
   - Python version
   - Test command
   - Coverage threshold
   - Working directory

2. Create a reusable Docker workflow that:
   - Builds multi-arch images
   - Pushes to GHCR
   - Returns image digest
   - Supports build args

3. Create a deployment workflow that:
   - Uses environments
   - Requires approval for production
   - Supports rollback

4. Create a caller workflow that orchestrates all workflows

### Validation

```bash
# Create test workflow call
cat > .github/workflows/main.yml << 'EOF'
name: Main Pipeline

on:
  push:
    branches: [main]

jobs:
  test:
    uses: ./.github/workflows/reusable-test.yml
    with:
      python-version: '3.11'
      coverage-threshold: 80

  build:
    needs: test
    uses: ./.github/workflows/reusable-docker.yml
    with:
      image-name: ${{ github.repository }}
      push: true
    permissions:
      packages: write

  deploy-staging:
    needs: build
    uses: ./.github/workflows/reusable-deploy.yml
    with:
      environment: staging
      image-digest: ${{ needs.build.outputs.image-digest }}
EOF

# Verify workflow syntax
# Push and check GitHub Actions tab
```

---

## Part 3: Challenge - Composite Actions & Self-Hosted Runners

### Objective

Build production-ready GitHub Actions infrastructure:
- Custom composite actions
- Self-hosted runner on Kubernetes
- OIDC authentication for AWS/GCP
- Workflow security hardening

### Requirements

1. **Create composite action for application setup**

```yaml
# .github/actions/setup-app/action.yml
name: 'Setup Application'
description: 'Set up Python environment with caching'

inputs:
  python-version:
    description: 'Python version'
    required: false
    default: '3.11'
  install-dev:
    description: 'Install dev dependencies'
    required: false
    default: 'true'

outputs:
  cache-hit:
    description: 'Cache hit status'
    value: ${{ steps.cache.outputs.cache-hit }}

runs:
  using: 'composite'
  steps:
    - name: Set up Python
      uses: actions/setup-python@v5
      with:
        python-version: ${{ inputs.python-version }}

    - name: Get pip cache dir
      id: pip-cache
      shell: bash
      run: echo "dir=$(pip cache dir)" >> $GITHUB_OUTPUT

    - name: Cache pip dependencies
      id: cache
      uses: actions/cache@v4
      with:
        path: ${{ steps.pip-cache.outputs.dir }}
        key: ${{ runner.os }}-pip-${{ hashFiles('**/requirements*.txt') }}
        restore-keys: |
          ${{ runner.os }}-pip-

    - name: Install dependencies
      shell: bash
      run: |
        pip install --upgrade pip
        pip install -r requirements.txt
        ${{ inputs.install-dev == 'true' && 'pip install -r requirements-dev.txt' || '' }}
```

2. **Deploy self-hosted runner on Kubernetes**

3. **Implement OIDC authentication**

4. **Add workflow security measures**

### Success Criteria

- [ ] Composite action works in workflows
- [ ] Self-hosted runner is registered and running jobs
- [ ] OIDC authentication works for cloud deployments
- [ ] Workflow uses minimal permissions
- [ ] Secrets are properly managed
- [ ] Dependabot is configured for actions

### Starting Point - Self-Hosted Runner

```yaml
# runner-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: github-runner
  namespace: actions-runner
spec:
  replicas: 2
  selector:
    matchLabels:
      app: github-runner
  template:
    metadata:
      labels:
        app: github-runner
    spec:
      containers:
        - name: runner
          image: ghcr.io/actions/actions-runner:latest
          env:
            - name: RUNNER_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: REPO_URL
              value: "https://github.com/YOUR_ORG/YOUR_REPO"
            - name: RUNNER_TOKEN
              valueFrom:
                secretKeyRef:
                  name: runner-secret
                  key: token
          resources:
            requests:
              cpu: "500m"
              memory: "512Mi"
            limits:
              cpu: "2"
              memory: "2Gi"
```

### Starting Point - OIDC Authentication

```yaml
# .github/workflows/deploy-aws.yml
name: Deploy to AWS

on:
  push:
    branches: [main]

permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/GitHubActionsRole
          aws-region: us-east-1

      - name: Deploy to ECS
        run: |
          aws ecs update-service \
            --cluster production \
            --service my-app \
            --force-new-deployment
```

### Validation Script

```bash
#!/bin/bash
# validate-actions.sh

echo "Validating GitHub Actions Setup..."

# Check workflow files
if ls .github/workflows/*.yml 1> /dev/null 2>&1; then
    WORKFLOWS=$(ls .github/workflows/*.yml | wc -l)
    echo "✓ Found $WORKFLOWS workflow files"
else
    echo "✗ No workflow files found"
    exit 1
fi

# Validate YAML syntax
for workflow in .github/workflows/*.yml; do
    if python -c "import yaml; yaml.safe_load(open('$workflow'))" 2>/dev/null; then
        echo "✓ Valid YAML: $workflow"
    else
        echo "✗ Invalid YAML: $workflow"
    fi
done

# Check for composite actions
if [ -d ".github/actions" ]; then
    ACTIONS=$(find .github/actions -name "action.yml" | wc -l)
    echo "✓ Found $ACTIONS composite actions"
else
    echo "⚠ No composite actions found"
fi

# Check for reusable workflows
REUSABLE=$(grep -l "workflow_call" .github/workflows/*.yml 2>/dev/null | wc -l)
echo "✓ Found $REUSABLE reusable workflows"

# Check for security best practices
for workflow in .github/workflows/*.yml; do
    if grep -q "permissions:" "$workflow"; then
        echo "✓ Permissions defined in $workflow"
    else
        echo "⚠ No permissions block in $workflow"
    fi
done

echo "Validation complete!"
```

---

## Cleanup

```bash
# Remove local lab files
cd ~
rm -rf github-actions-lab

# Delete GitHub repository (if test)
# gh repo delete <repo-name> --yes

# Remove self-hosted runners
# kubectl delete namespace actions-runner
```

## Summary

In this lab, you learned:
- Creating comprehensive GitHub Actions workflows
- Implementing matrix builds for cross-platform testing
- Building reusable workflows and composite actions
- Setting up self-hosted runners
- Implementing OIDC for secure cloud deployments

## Next Steps

- Explore GitHub Actions for CI/CD at scale
- Implement custom JavaScript/TypeScript actions
- Set up actions-runner-controller for Kubernetes
- Configure advanced caching strategies

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Challenge - Composite Actions & Self-Hosted Runners
- Create Basic CI Workflow
- Create Matrix Build Workflow
- Create Release Workflow

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
