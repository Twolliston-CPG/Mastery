# Lab 09: Testing in CI/CD Pipelines

## Overview

In this lab, you'll implement comprehensive testing strategies within CI/CD pipelines. You'll learn about the test pyramid, parallel test execution, coverage gates, and handling flaky tests.

**Duration**: 3-4 hours
**Difficulty**: Intermediate

## Prerequisites

- Git and GitHub account
- Node.js 20+ installed
- Docker installed
- Basic understanding of testing concepts

## Learning Objectives

- Implement the test pyramid in CI/CD
- Configure parallel test execution
- Set up coverage gates and quality thresholds
- Handle flaky tests effectively
- Implement contract testing

## Lab Environment Setup

```bash
# Create lab directory
mkdir -p ~/testing-pipelines-lab && cd ~/testing-pipelines-lab

# Initialize project
npm init -y

# Install dependencies
npm install express
npm install -D jest supertest @playwright/test \
  jest-junit @pact-foundation/pact

# Create project structure
mkdir -p src tests/{unit,integration,e2e,contract}
mkdir -p .github/workflows

# Create sample application
cat > src/app.js << 'EOF'
const express = require('express');
const app = express();

app.use(express.json());

// In-memory data store
const users = new Map();
let nextId = 1;

// Utility functions (testable)
const validateEmail = (email) => {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
};

const validateUser = (user) => {
  const errors = [];
  if (!user.name || user.name.length < 2) {
    errors.push('Name must be at least 2 characters');
  }
  if (!user.email || !validateEmail(user.email)) {
    errors.push('Valid email is required');
  }
  return errors;
};

// Routes
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', timestamp: new Date().toISOString() });
});

app.get('/users', (req, res) => {
  res.json(Array.from(users.values()));
});

app.get('/users/:id', (req, res) => {
  const user = users.get(parseInt(req.params.id));
  if (!user) {
    return res.status(404).json({ error: 'User not found' });
  }
  res.json(user);
});

app.post('/users', (req, res) => {
  const errors = validateUser(req.body);
  if (errors.length > 0) {
    return res.status(400).json({ errors });
  }

  const user = {
    id: nextId++,
    name: req.body.name,
    email: req.body.email,
    createdAt: new Date().toISOString()
  };
  users.set(user.id, user);
  res.status(201).json(user);
});

app.delete('/users/:id', (req, res) => {
  const id = parseInt(req.params.id);
  if (!users.has(id)) {
    return res.status(404).json({ error: 'User not found' });
  }
  users.delete(id);
  res.status(204).send();
});

// Export for testing
module.exports = { app, validateEmail, validateUser, users };
EOF

# Create server entry point
cat > src/server.js << 'EOF'
const { app } = require('./app');

const port = process.env.PORT || 3000;

app.listen(port, () => {
  console.log(`Server running on port ${port}`);
});
EOF

# Configure Jest
cat > jest.config.js << 'EOF'
module.exports = {
  testEnvironment: 'node',
  collectCoverageFrom: ['src/**/*.js'],
  coverageDirectory: 'coverage',
  coverageReporters: ['text', 'lcov', 'html', 'cobertura'],
  coverageThreshold: {
    global: {
      branches: 80,
      functions: 80,
      lines: 80,
      statements: 80
    }
  },
  reporters: [
    'default',
    ['jest-junit', {
      outputDirectory: 'reports',
      outputName: 'junit.xml'
    }]
  ],
  projects: [
    {
      displayName: 'unit',
      testMatch: ['<rootDir>/tests/unit/**/*.test.js'],
      testEnvironment: 'node'
    },
    {
      displayName: 'integration',
      testMatch: ['<rootDir>/tests/integration/**/*.test.js'],
      testEnvironment: 'node'
    }
  ]
};
EOF
```

---

## Part 1: Guided Exercise - Test Pyramid Implementation

### Step 1: Create Unit Tests

```javascript
// tests/unit/validators.test.js
const { validateEmail, validateUser } = require('../../src/app');

describe('Validators', () => {
  describe('validateEmail', () => {
    test.each([
      ['test@example.com', true],
      ['user.name@domain.org', true],
      ['invalid-email', false],
      ['@nodomain.com', false],
      ['spaces in@email.com', false],
      ['', false],
    ])('validateEmail(%s) should return %s', (email, expected) => {
      expect(validateEmail(email)).toBe(expected);
    });
  });

  describe('validateUser', () => {
    test('returns empty array for valid user', () => {
      const user = { name: 'John Doe', email: 'john@example.com' };
      expect(validateUser(user)).toHaveLength(0);
    });

    test('returns error for short name', () => {
      const user = { name: 'J', email: 'john@example.com' };
      const errors = validateUser(user);
      expect(errors).toContain('Name must be at least 2 characters');
    });

    test('returns error for invalid email', () => {
      const user = { name: 'John Doe', email: 'invalid' };
      const errors = validateUser(user);
      expect(errors).toContain('Valid email is required');
    });

    test('returns multiple errors for invalid user', () => {
      const user = { name: 'J', email: 'invalid' };
      const errors = validateUser(user);
      expect(errors).toHaveLength(2);
    });
  });
});
```

### Step 2: Create Integration Tests

```javascript
// tests/integration/api.test.js
const request = require('supertest');
const { app, users } = require('../../src/app');

describe('API Integration Tests', () => {
  beforeEach(() => {
    // Clear users before each test
    users.clear();
  });

  describe('GET /health', () => {
    test('returns healthy status', async () => {
      const response = await request(app).get('/health');

      expect(response.status).toBe(200);
      expect(response.body.status).toBe('healthy');
      expect(response.body.timestamp).toBeDefined();
    });
  });

  describe('POST /users', () => {
    test('creates user with valid data', async () => {
      const userData = {
        name: 'John Doe',
        email: 'john@example.com'
      };

      const response = await request(app)
        .post('/users')
        .send(userData)
        .set('Content-Type', 'application/json');

      expect(response.status).toBe(201);
      expect(response.body.id).toBeDefined();
      expect(response.body.name).toBe(userData.name);
      expect(response.body.email).toBe(userData.email);
    });

    test('returns 400 for invalid data', async () => {
      const response = await request(app)
        .post('/users')
        .send({ name: 'J', email: 'invalid' })
        .set('Content-Type', 'application/json');

      expect(response.status).toBe(400);
      expect(response.body.errors).toBeDefined();
      expect(response.body.errors.length).toBeGreaterThan(0);
    });
  });

  describe('GET /users', () => {
    test('returns empty array when no users', async () => {
      const response = await request(app).get('/users');

      expect(response.status).toBe(200);
      expect(response.body).toEqual([]);
    });

    test('returns all users', async () => {
      // Create users first
      await request(app)
        .post('/users')
        .send({ name: 'User One', email: 'one@example.com' });
      await request(app)
        .post('/users')
        .send({ name: 'User Two', email: 'two@example.com' });

      const response = await request(app).get('/users');

      expect(response.status).toBe(200);
      expect(response.body).toHaveLength(2);
    });
  });

  describe('GET /users/:id', () => {
    test('returns user by id', async () => {
      const createResponse = await request(app)
        .post('/users')
        .send({ name: 'John Doe', email: 'john@example.com' });

      const response = await request(app)
        .get(`/users/${createResponse.body.id}`);

      expect(response.status).toBe(200);
      expect(response.body.name).toBe('John Doe');
    });

    test('returns 404 for non-existent user', async () => {
      const response = await request(app).get('/users/999');

      expect(response.status).toBe(404);
      expect(response.body.error).toBe('User not found');
    });
  });

  describe('DELETE /users/:id', () => {
    test('deletes existing user', async () => {
      const createResponse = await request(app)
        .post('/users')
        .send({ name: 'John Doe', email: 'john@example.com' });

      const deleteResponse = await request(app)
        .delete(`/users/${createResponse.body.id}`);

      expect(deleteResponse.status).toBe(204);

      // Verify user is deleted
      const getResponse = await request(app)
        .get(`/users/${createResponse.body.id}`);
      expect(getResponse.status).toBe(404);
    });

    test('returns 404 for non-existent user', async () => {
      const response = await request(app).delete('/users/999');
      expect(response.status).toBe(404);
    });
  });
});
```

### Step 3: Create E2E Tests with Playwright

```javascript
// tests/e2e/app.spec.js
const { test, expect } = require('@playwright/test');

test.describe('Application E2E Tests', () => {
  const baseUrl = process.env.APP_URL || 'http://localhost:3000';

  test('health check returns healthy', async ({ request }) => {
    const response = await request.get(`${baseUrl}/health`);

    expect(response.ok()).toBeTruthy();
    const body = await response.json();
    expect(body.status).toBe('healthy');
  });

  test('complete user lifecycle', async ({ request }) => {
    // Create user
    const createResponse = await request.post(`${baseUrl}/users`, {
      data: {
        name: 'E2E Test User',
        email: 'e2e@example.com'
      }
    });
    expect(createResponse.ok()).toBeTruthy();
    const user = await createResponse.json();
    expect(user.id).toBeDefined();

    // Read user
    const getResponse = await request.get(`${baseUrl}/users/${user.id}`);
    expect(getResponse.ok()).toBeTruthy();
    const fetchedUser = await getResponse.json();
    expect(fetchedUser.email).toBe('e2e@example.com');

    // List users
    const listResponse = await request.get(`${baseUrl}/users`);
    expect(listResponse.ok()).toBeTruthy();
    const users = await listResponse.json();
    expect(users.some(u => u.id === user.id)).toBeTruthy();

    // Delete user
    const deleteResponse = await request.delete(`${baseUrl}/users/${user.id}`);
    expect(deleteResponse.status()).toBe(204);

    // Verify deletion
    const verifyResponse = await request.get(`${baseUrl}/users/${user.id}`);
    expect(verifyResponse.status()).toBe(404);
  });
});
```

### Step 4: Create CI Workflow

```yaml
# .github/workflows/test.yml
name: Test Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  unit-tests:
    name: Unit Tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run unit tests
        run: npm test -- --selectProjects=unit --coverage

      - name: Upload coverage
        uses: codecov/codecov-action@v4
        with:
          files: coverage/lcov.info
          flags: unit

      - name: Upload test results
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: unit-test-results
          path: reports/junit.xml

  integration-tests:
    name: Integration Tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run integration tests
        run: npm test -- --selectProjects=integration

      - name: Upload test results
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: integration-test-results
          path: reports/junit.xml

  e2e-tests:
    name: E2E Tests
    runs-on: ubuntu-latest
    needs: [unit-tests, integration-tests]
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Install Playwright browsers
        run: npx playwright install --with-deps

      - name: Start application
        run: |
          npm start &
          npx wait-on http://localhost:3000/health

      - name: Run E2E tests
        run: npx playwright test
        env:
          APP_URL: http://localhost:3000

      - name: Upload Playwright report
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: playwright-report
          path: playwright-report/
```

---

## Part 2: Semi-Guided Exercise - Parallel Test Execution

### Objective

Optimize test execution with:
- Parallel job execution
- Test sharding
- Smart test selection
- Caching strategies

### Requirements

1. **Configure test sharding**

<details>
<summary>Click for Jest sharding hint</summary>

```yaml
# Matrix strategy for parallel tests
jobs:
  test:
    strategy:
      fail-fast: false
      matrix:
        shard: [1, 2, 3, 4]
    steps:
      - run: npm test -- --shard=${{ matrix.shard }}/4
```
</details>

2. **Implement smart test selection**

<details>
<summary>Click for smart test hint</summary>

```yaml
# Run only affected tests
- name: Get changed files
  id: changed
  uses: tj-actions/changed-files@v41

- name: Run affected tests
  run: |
    npx jest --findRelatedTests ${{ steps.changed.outputs.all_changed_files }}
```
</details>

3. **Configure test caching**

<details>
<summary>Click for caching hint</summary>

```yaml
- name: Cache Jest
  uses: actions/cache@v4
  with:
    path: |
      .jest-cache
      node_modules/.cache
    key: jest-${{ runner.os }}-${{ hashFiles('**/package-lock.json') }}
```
</details>

### Tasks

1. Split tests across multiple runners using matrix strategy
2. Implement test sharding for large test suites
3. Add smart test selection based on changed files
4. Configure caching to speed up test runs
5. Aggregate test results from all shards

### Validation

```yaml
# Verify parallel execution
- name: Merge test results
  if: always()
  run: |
    mkdir -p merged-reports
    for report in reports-*/junit.xml; do
      cat "$report" >> merged-reports/all-tests.xml
    done

# Check total test count matches expected
- name: Verify all tests ran
  run: |
    EXPECTED_TESTS=100
    ACTUAL_TESTS=$(grep -c "testcase" merged-reports/all-tests.xml)
    if [ "$ACTUAL_TESTS" -ne "$EXPECTED_TESTS" ]; then
      echo "Expected $EXPECTED_TESTS tests but found $ACTUAL_TESTS"
      exit 1
    fi
```

---

## Part 3: Challenge - Contract Testing with Pact

### Objective

Implement contract testing between services:
- Consumer-driven contracts
- Provider verification
- Contract broker integration
- Breaking change detection

### Requirements

1. **Set up consumer tests**

```javascript
// tests/contract/consumer.test.js
const { Pact } = require('@pact-foundation/pact');
const path = require('path');

describe('User Service Contract', () => {
  const provider = new Pact({
    consumer: 'WebApp',
    provider: 'UserService',
    port: 1234,
    log: path.resolve(process.cwd(), 'logs', 'pact.log'),
    dir: path.resolve(process.cwd(), 'pacts'),
    logLevel: 'warn',
  });

  beforeAll(() => provider.setup());
  afterAll(() => provider.finalize());
  afterEach(() => provider.verify());

  describe('get user', () => {
    test('returns user when exists', async () => {
      await provider.addInteraction({
        state: 'user with id 1 exists',
        uponReceiving: 'a request for user 1',
        withRequest: {
          method: 'GET',
          path: '/users/1',
        },
        willRespondWith: {
          status: 200,
          headers: {
            'Content-Type': 'application/json',
          },
          body: {
            id: 1,
            name: 'John Doe',
            email: 'john@example.com',
          },
        },
      });

      const response = await fetch('http://localhost:1234/users/1');
      const user = await response.json();

      expect(user.id).toBe(1);
      expect(user.name).toBe('John Doe');
    });
  });
});
```

2. **Set up provider verification**

3. **Configure Pactflow broker**

4. **Implement can-i-deploy check**

### Success Criteria

- [ ] Consumer tests generate pacts
- [ ] Provider verifies pacts
- [ ] Contracts published to broker
- [ ] can-i-deploy checks in pipeline
- [ ] Breaking changes detected
- [ ] Webhook notifications configured

### Starting Point - Provider Verification

```javascript
// tests/contract/provider.test.js
const { Verifier } = require('@pact-foundation/pact');
const path = require('path');
const { app } = require('../../src/app');

describe('Pact Provider Verification', () => {
  let server;

  beforeAll((done) => {
    server = app.listen(3001, done);
  });

  afterAll((done) => {
    server.close(done);
  });

  test('validates the expectations of the consumer', async () => {
    const opts = {
      providerBaseUrl: 'http://localhost:3001',
      provider: 'UserService',
      // Local pacts
      pactUrls: [path.resolve(process.cwd(), 'pacts', 'webapp-userservice.json')],
      // Or from broker
      // pactBrokerUrl: process.env.PACT_BROKER_URL,
      // pactBrokerToken: process.env.PACT_BROKER_TOKEN,
      publishVerificationResult: process.env.CI === 'true',
      providerVersion: process.env.GIT_COMMIT,
      stateHandlers: {
        'user with id 1 exists': async () => {
          // Set up state
          const { users } = require('../../src/app');
          users.set(1, {
            id: 1,
            name: 'John Doe',
            email: 'john@example.com',
            createdAt: new Date().toISOString()
          });
        },
      },
    };

    await new Verifier(opts).verifyProvider();
  });
});
```

### Starting Point - CI Workflow with Contract Testing

```yaml
# .github/workflows/contract-tests.yml
name: Contract Tests

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

env:
  PACT_BROKER_URL: ${{ secrets.PACT_BROKER_URL }}
  PACT_BROKER_TOKEN: ${{ secrets.PACT_BROKER_TOKEN }}

jobs:
  consumer-tests:
    name: Consumer Contract Tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run consumer tests
        run: npm run test:contract:consumer

      - name: Publish pacts
        run: |
          npx pact-broker publish pacts \
            --consumer-app-version ${{ github.sha }} \
            --branch ${{ github.ref_name }} \
            --broker-base-url $PACT_BROKER_URL \
            --broker-token $PACT_BROKER_TOKEN

  provider-tests:
    name: Provider Contract Tests
    runs-on: ubuntu-latest
    needs: consumer-tests
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Verify provider
        run: npm run test:contract:provider
        env:
          GIT_COMMIT: ${{ github.sha }}

  can-i-deploy:
    name: Can I Deploy?
    runs-on: ubuntu-latest
    needs: [consumer-tests, provider-tests]
    steps:
      - name: Check deployment safety
        run: |
          npx pact-broker can-i-deploy \
            --pacticipant WebApp \
            --version ${{ github.sha }} \
            --to production \
            --broker-base-url $PACT_BROKER_URL \
            --broker-token $PACT_BROKER_TOKEN
```

### Validation Script

```bash
#!/bin/bash
# validate-testing-pipeline.sh

echo "Validating Testing Pipeline..."

# Check test files exist
echo "=== Test Structure ==="
for dir in unit integration e2e contract; do
    COUNT=$(find tests/$dir -name "*.test.js" 2>/dev/null | wc -l)
    if [ "$COUNT" -gt 0 ]; then
        echo "✓ Found $COUNT test files in tests/$dir"
    else
        echo "⚠ No tests in tests/$dir"
    fi
done

# Run tests and check coverage
echo ""
echo "=== Running Tests ==="
npm test -- --coverage 2>/dev/null

if [ -f "coverage/lcov.info" ]; then
    COVERAGE=$(grep -A 3 "end_of_record" coverage/lcov.info | grep "LF:" | awk -F: '{sum+=$2} END {print sum}')
    echo "✓ Coverage report generated"
else
    echo "⚠ No coverage report"
fi

# Check jest config
if [ -f "jest.config.js" ]; then
    echo "✓ Jest configuration exists"
    if grep -q "coverageThreshold" jest.config.js; then
        echo "✓ Coverage thresholds configured"
    fi
fi

# Check for CI workflow
if [ -f ".github/workflows/test.yml" ]; then
    echo "✓ Test workflow exists"
else
    echo "⚠ No test workflow found"
fi

# Check for pact files
if [ -d "pacts" ] && ls pacts/*.json 1> /dev/null 2>&1; then
    PACTS=$(ls pacts/*.json | wc -l)
    echo "✓ Found $PACTS pact contracts"
else
    echo "⚠ No pact contracts found"
fi

echo ""
echo "Validation complete!"
```

---

## Cleanup

```bash
# Remove lab files
cd ~
rm -rf testing-pipelines-lab

# Clean npm cache
npm cache clean --force
```

## Summary

In this lab, you learned:
- Implementing the test pyramid (unit, integration, E2E)
- Configuring parallel test execution and sharding
- Setting up coverage gates and quality thresholds
- Implementing contract testing with Pact
- Handling flaky tests with retries
- Optimizing test performance with caching

## Next Steps

- Explore mutation testing with Stryker
- Implement visual regression testing
- Set up performance testing in CI
- Configure test impact analysis

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Challenge - Contract Testing with Pact
- Create Unit Tests
- Create Integration Tests
- Create E2E Tests with Playwright

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
