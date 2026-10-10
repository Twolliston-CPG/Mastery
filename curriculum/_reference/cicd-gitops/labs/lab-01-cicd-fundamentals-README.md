# Lab 01: CI/CD Fundamentals

## Overview

In this lab, you'll build a complete CI/CD pipeline from scratch, learning the fundamental concepts of continuous integration and continuous delivery through hands-on practice.

**Duration**: 2-3 hours
**Difficulty**: Beginner to Intermediate

## Prerequisites

- Git installed and configured
- Docker and Docker Compose
- Basic understanding of version control
- Text editor or IDE

## Learning Objectives

- Understand the CI/CD workflow components
- Create automated build processes
- Implement automated testing
- Set up deployment automation
- Configure pipeline triggers and notifications

## Lab Environment Setup

```bash
# Create lab directory
mkdir -p ~/cicd-lab && cd ~/cicd-lab

# Clone the starter project
git clone https://github.com/your-org/cicd-lab-starter.git .
# Or create from scratch
```

### Sample Application

```bash
# Create a simple Node.js application
mkdir -p src tests

# Create package.json
cat > package.json << 'EOF'
{
  "name": "cicd-demo-app",
  "version": "1.0.0",
  "description": "Demo application for CI/CD lab",
  "main": "src/index.js",
  "scripts": {
    "start": "node src/index.js",
    "test": "jest",
    "test:coverage": "jest --coverage",
    "lint": "eslint src/",
    "build": "echo 'Build complete'"
  },
  "dependencies": {
    "express": "^4.18.2"
  },
  "devDependencies": {
    "jest": "^29.7.0",
    "eslint": "^8.56.0",
    "supertest": "^6.3.3"
  }
}
EOF

# Create main application
cat > src/index.js << 'EOF'
const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

app.get('/', (req, res) => {
  res.json({ message: 'Hello from CI/CD Demo!' });
});

app.get('/health', (req, res) => {
  res.json({ status: 'healthy', version: process.env.VERSION || '1.0.0' });
});

app.get('/api/calculate', (req, res) => {
  const { a, b, op } = req.query;
  const numA = parseFloat(a);
  const numB = parseFloat(b);

  if (isNaN(numA) || isNaN(numB)) {
    return res.status(400).json({ error: 'Invalid numbers' });
  }

  let result;
  switch (op) {
    case 'add': result = numA + numB; break;
    case 'subtract': result = numA - numB; break;
    case 'multiply': result = numA * numB; break;
    case 'divide':
      if (numB === 0) return res.status(400).json({ error: 'Division by zero' });
      result = numA / numB;
      break;
    default:
      return res.status(400).json({ error: 'Invalid operation' });
  }

  res.json({ result });
});

if (require.main === module) {
  app.listen(port, () => {
    console.log(`Server running on port ${port}`);
  });
}

module.exports = app;
EOF

# Create unit tests
cat > tests/app.test.js << 'EOF'
const request = require('supertest');
const app = require('../src/index');

describe('API Tests', () => {
  test('GET / returns welcome message', async () => {
    const response = await request(app).get('/');
    expect(response.status).toBe(200);
    expect(response.body.message).toBe('Hello from CI/CD Demo!');
  });

  test('GET /health returns healthy status', async () => {
    const response = await request(app).get('/health');
    expect(response.status).toBe(200);
    expect(response.body.status).toBe('healthy');
  });

  describe('Calculator API', () => {
    test('adds two numbers', async () => {
      const response = await request(app)
        .get('/api/calculate?a=5&b=3&op=add');
      expect(response.body.result).toBe(8);
    });

    test('subtracts two numbers', async () => {
      const response = await request(app)
        .get('/api/calculate?a=10&b=4&op=subtract');
      expect(response.body.result).toBe(6);
    });

    test('handles division by zero', async () => {
      const response = await request(app)
        .get('/api/calculate?a=10&b=0&op=divide');
      expect(response.status).toBe(400);
    });
  });
});
EOF

# Create Dockerfile
cat > Dockerfile << 'EOF'
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

FROM node:20-alpine
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY src/ ./src/
EXPOSE 3000
USER node
CMD ["node", "src/index.js"]
EOF
```

---

## Part 1: Guided Exercise - Building a Basic Pipeline

### Step 1: Initialize Version Control

```bash
# Initialize Git repository
git init

# Create .gitignore
cat > .gitignore << 'EOF'
node_modules/
coverage/
*.log
.env
dist/
EOF

# Make initial commit
git add .
git commit -m "Initial commit: basic application setup"
```

### Step 2: Create Local CI Script

```bash
# Create a local CI script to understand the workflow
cat > ci.sh << 'EOF'
#!/bin/bash
set -e  # Exit on any error

echo "=== CI Pipeline Started ==="
echo "Commit: $(git rev-parse --short HEAD)"
echo "Branch: $(git branch --show-current)"
echo ""

# Stage 1: Install dependencies
echo "=== Stage 1: Install Dependencies ==="
npm ci
echo "✓ Dependencies installed"
echo ""

# Stage 2: Lint code
echo "=== Stage 2: Lint ==="
npm run lint || echo "Warning: Linting issues found"
echo "✓ Linting complete"
echo ""

# Stage 3: Run tests
echo "=== Stage 3: Tests ==="
npm test
echo "✓ Tests passed"
echo ""

# Stage 4: Build
echo "=== Stage 4: Build ==="
npm run build
echo "✓ Build complete"
echo ""

# Stage 5: Build Docker image
echo "=== Stage 5: Docker Build ==="
docker build -t cicd-demo:$(git rev-parse --short HEAD) .
echo "✓ Docker image built"
echo ""

echo "=== CI Pipeline Complete ==="
EOF

chmod +x ci.sh
```

### Step 3: Create GitHub Actions Workflow

```bash
# Create workflow directory
mkdir -p .github/workflows

# Create CI workflow
cat > .github/workflows/ci.yml << 'EOF'
name: CI Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  NODE_VERSION: '20'

jobs:
  lint:
    name: Lint Code
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run linter
        run: npm run lint

  test:
    name: Run Tests
    runs-on: ubuntu-latest
    needs: lint
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run tests with coverage
        run: npm run test:coverage

      - name: Upload coverage report
        uses: actions/upload-artifact@v4
        with:
          name: coverage-report
          path: coverage/

  build:
    name: Build Application
    runs-on: ubuntu-latest
    needs: test
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Build
        run: npm run build

      - name: Build Docker image
        run: |
          docker build -t cicd-demo:${{ github.sha }} .

  deploy-staging:
    name: Deploy to Staging
    runs-on: ubuntu-latest
    needs: build
    if: github.ref == 'refs/heads/main'
    environment: staging
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Deploy to staging
        run: |
          echo "Deploying to staging environment..."
          echo "Version: ${{ github.sha }}"
          # Add actual deployment commands here
EOF
```

### Step 4: Test the Pipeline Locally

```bash
# Install dependencies
npm install

# Run ESLint setup
npx eslint --init

# Create ESLint config
cat > .eslintrc.json << 'EOF'
{
  "env": {
    "node": true,
    "es2021": true,
    "jest": true
  },
  "extends": "eslint:recommended",
  "parserOptions": {
    "ecmaVersion": "latest"
  },
  "rules": {
    "indent": ["error", 2],
    "quotes": ["error", "single"],
    "semi": ["error", "always"]
  }
}
EOF

# Run the local CI script
./ci.sh
```

### Step 5: Push and Verify

```bash
# Create a GitHub repository and push
git add .
git commit -m "Add CI pipeline configuration"
git remote add origin <your-repo-url>
git push -u origin main

# Verify the workflow runs in GitHub Actions
```

---

## Part 2: Semi-Guided Exercise - Multi-Stage Pipeline

### Objective

Extend the pipeline to include:
- Parallel test execution
- Code coverage requirements
- Docker image publishing
- Environment-based deployments

### Requirements

1. **Parallel Testing**
   - Split tests into unit and integration tests
   - Run them in parallel

2. **Coverage Gates**
   - Fail if coverage drops below 80%

3. **Docker Publishing**
   - Push image to GitHub Container Registry
   - Tag with commit SHA and latest

4. **Multi-Environment Deployment**
   - Deploy to staging automatically
   - Deploy to production with manual approval

### Hints

<details>
<summary>Click for matrix testing hint</summary>

```yaml
test:
  strategy:
    matrix:
      test-type: [unit, integration]
  steps:
    - run: npm run test:${{ matrix.test-type }}
```
</details>

<details>
<summary>Click for Docker publishing hint</summary>

```yaml
- name: Login to GHCR
  uses: docker/login-action@v3
  with:
    registry: ghcr.io
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}
```
</details>

<details>
<summary>Click for environment hint</summary>

```yaml
deploy-production:
  environment:
    name: production
    url: https://app.example.com
  steps:
    - run: ./deploy.sh production
```
</details>

### Validation

```bash
# Test your pipeline by:
# 1. Creating a PR with a failing test
# 2. Verify the pipeline blocks the merge
# 3. Fix the test and verify pipeline passes
# 4. Merge and watch deployment to staging
```

---

## Part 3: Challenge - Complete CI/CD Implementation

### Objective

Build a production-ready CI/CD pipeline with:
- Branch protection rules
- Automated versioning
- Release management
- Notifications
- Rollback capability

### Requirements

1. **Branch Protection**
   - Require status checks before merge
   - Require at least one approval
   - No direct pushes to main

2. **Automated Versioning**
   - Use conventional commits
   - Automatically bump version based on commit messages
   - Generate changelog

3. **Release Process**
   - Create GitHub releases on version tags
   - Attach build artifacts
   - Generate release notes

4. **Notifications**
   - Send Slack/Discord notification on deployment
   - Alert on pipeline failures

5. **Rollback**
   - Implement one-click rollback mechanism
   - Store previous deployment versions

### Success Criteria

- [ ] Pipeline completes in under 10 minutes
- [ ] All tests pass with >80% coverage
- [ ] Docker image is signed and published
- [ ] Staging deployment is automatic
- [ ] Production deployment requires approval
- [ ] Notifications are sent correctly
- [ ] Rollback works reliably

### Validation Script

```bash
#!/bin/bash
# validate-pipeline.sh

echo "Validating CI/CD Pipeline..."

# Check workflow files exist
if [ -f ".github/workflows/ci.yml" ]; then
  echo "✓ CI workflow exists"
else
  echo "✗ CI workflow missing"
  exit 1
fi

# Check for required jobs
JOBS=$(yq '.jobs | keys' .github/workflows/ci.yml)
for job in lint test build deploy-staging; do
  if echo "$JOBS" | grep -q "$job"; then
    echo "✓ Job '$job' exists"
  else
    echo "✗ Job '$job' missing"
  fi
done

# Check for environment usage
if grep -q "environment:" .github/workflows/ci.yml; then
  echo "✓ Environment deployments configured"
else
  echo "✗ Environment deployments not configured"
fi

# Check for secrets usage
if grep -q "secrets\." .github/workflows/ci.yml; then
  echo "✓ Secrets are being used"
else
  echo "⚠ No secrets found (may be expected)"
fi

echo "Validation complete!"
```

---

## Cleanup

```bash
# Remove local lab files
cd ~
rm -rf cicd-lab

# Delete GitHub repository (if test)
# gh repo delete <repo-name> --yes
```

## Summary

In this lab, you learned:
- Basic CI/CD pipeline structure and components
- How to create automated build, test, and deploy workflows
- Parallel test execution and coverage gates
- Docker image building and publishing
- Environment-based deployments with approvals
- Release management and notifications

## Next Steps

- Explore Jenkins for on-premises CI/CD
- Learn GitLab CI/CD for integrated DevOps
- Implement ArgoCD for GitOps deployments

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Challenge - Complete CI/CD Implementation
- Sample Application
- Initialize Version Control
- Create Local CI Script

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
