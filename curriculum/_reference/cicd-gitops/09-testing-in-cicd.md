# Module 09: Testing in CI/CD

## Learning Objectives

By the end of this module, you will be able to:
- Design a comprehensive test strategy for CI/CD pipelines
- Implement different test types at appropriate pipeline stages
- Configure parallel test execution for faster feedback
- Manage test data and environments effectively
- Handle flaky tests and improve test reliability
- Implement test reporting and coverage tracking

## Introduction

Testing is a critical component of CI/CD pipelines, providing confidence that code changes don't introduce regressions and meet quality standards. An effective test strategy balances coverage, speed, and reliability to enable frequent, safe deployments.

## The Test Pyramid

### Test Types and Distribution

**The test pyramid**

<!-- figure: generated from the Mermaid below by _shared/diagrams/embed-figures.py — do not edit the image -->
![Test Types and Distribution — diagram](../../../_figures/curriculum-_reference-cicd-gitops-09-testing-in-cicd-0-499bd854.png)

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
  E2E["<b>End-to-end</b><br/><i>slow · expensive · few</i>"]
  INT["<b>Integration</b><br/><i>medium speed · medium count</i>"]
  UNIT["<b>Unit</b><br/><i>fast · cheap · many</i>"]
  UNIT --> INT --> E2E
  class E2E crit
  class INT n
  class UNIT n
  linkStyle 0,1 stroke:#aeb6be,stroke-dasharray:4 3
```

</details>

| Layer | Share of your suite | Runs in |
|---|---|---|
| Unit | 70% | Seconds |
| Integration | 20% | Minutes |
| End-to-end | 10% | 10–30+ minutes |

The ratio is not a style preference — it is a consequence of the runtimes in the third column. An
inverted pyramid does not fail because it is wrong in principle; it fails because the suite takes
forty minutes, so developers stop running it, so it only runs in CI, so a failure arrives long after
the context that caused it is gone.

### Test Types in CI/CD

```yaml
# Complete test pipeline
name: Test Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  # Fast feedback - run first
  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - run: npm ci
      - run: npm run test:unit -- --coverage
      - uses: codecov/codecov-action@v4
        with:
          files: coverage/lcov.info

  # Lint and static analysis
  static-analysis:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - run: npm ci
      - run: npm run lint
      - run: npm run type-check

  # Integration tests - need services
  integration-tests:
    runs-on: ubuntu-latest
    needs: [unit-tests, static-analysis]
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: test
        ports:
          - 5432:5432
      redis:
        image: redis:7
        ports:
          - 6379:6379
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
      - run: npm ci
      - run: npm run test:integration
        env:
          DATABASE_URL: postgres://postgres:test@localhost:5432/test
          REDIS_URL: redis://localhost:6379

  # E2E tests - slower, run after integration
  e2e-tests:
    runs-on: ubuntu-latest
    needs: integration-tests
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
      - run: npm ci
      - run: npx playwright install --with-deps
      - run: npm run build
      - run: npm run test:e2e
      - uses: actions/upload-artifact@v4
        if: failure()
        with:
          name: playwright-report
          path: playwright-report/

  # Performance tests - run on main only
  performance-tests:
    runs-on: ubuntu-latest
    needs: e2e-tests
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npm run test:performance
```

## Unit Testing

### Fast and Isolated Tests

```javascript
// Example unit test with Jest
describe('OrderService', () => {
  let orderService;
  let mockPaymentGateway;
  let mockInventoryService;

  beforeEach(() => {
    // Mock dependencies
    mockPaymentGateway = {
      processPayment: jest.fn(),
    };
    mockInventoryService = {
      checkStock: jest.fn(),
      reserveItems: jest.fn(),
    };

    orderService = new OrderService(
      mockPaymentGateway,
      mockInventoryService
    );
  });

  describe('createOrder', () => {
    it('should create order when items are in stock', async () => {
      mockInventoryService.checkStock.mockResolvedValue(true);
      mockInventoryService.reserveItems.mockResolvedValue(true);
      mockPaymentGateway.processPayment.mockResolvedValue({
        success: true,
        transactionId: 'txn-123',
      });

      const order = await orderService.createOrder({
        items: [{ id: 'item-1', quantity: 2 }],
        payment: { amount: 100 },
      });

      expect(order.status).toBe('confirmed');
      expect(mockInventoryService.checkStock).toHaveBeenCalled();
      expect(mockPaymentGateway.processPayment).toHaveBeenCalled();
    });

    it('should reject order when items are out of stock', async () => {
      mockInventoryService.checkStock.mockResolvedValue(false);

      await expect(
        orderService.createOrder({
          items: [{ id: 'item-1', quantity: 100 }],
        })
      ).rejects.toThrow('Insufficient stock');

      expect(mockPaymentGateway.processPayment).not.toHaveBeenCalled();
    });
  });
});
```

### Parallel Unit Test Execution

```yaml
# Parallel test sharding
unit-tests:
  runs-on: ubuntu-latest
  strategy:
    matrix:
      shard: [1, 2, 3, 4]
  steps:
    - uses: actions/checkout@v4
    - uses: actions/setup-node@v4
    - run: npm ci
    - run: npm test -- --shard=${{ matrix.shard }}/4

# Jest configuration for sharding
# jest.config.js
module.exports = {
  testMatch: ['**/*.test.js'],
  maxWorkers: '50%',
  collectCoverage: true,
  coverageReporters: ['json', 'lcov', 'text-summary'],
};
```

## Integration Testing

### Database Integration Tests

```javascript
// Integration test with real database
const { Pool } = require('pg');
const { UserRepository } = require('./UserRepository');

describe('UserRepository Integration', () => {
  let pool;
  let userRepository;

  beforeAll(async () => {
    pool = new Pool({
      connectionString: process.env.DATABASE_URL,
    });
    userRepository = new UserRepository(pool);

    // Run migrations
    await pool.query(`
      CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        email VARCHAR(255) UNIQUE NOT NULL,
        name VARCHAR(255),
        created_at TIMESTAMP DEFAULT NOW()
      )
    `);
  });

  beforeEach(async () => {
    // Clean up before each test
    await pool.query('DELETE FROM users');
  });

  afterAll(async () => {
    await pool.end();
  });

  it('should create and retrieve user', async () => {
    const user = await userRepository.create({
      email: 'test@example.com',
      name: 'Test User',
    });

    expect(user.id).toBeDefined();
    expect(user.email).toBe('test@example.com');

    const retrieved = await userRepository.findById(user.id);
    expect(retrieved.name).toBe('Test User');
  });

  it('should handle duplicate emails', async () => {
    await userRepository.create({ email: 'dupe@example.com' });

    await expect(
      userRepository.create({ email: 'dupe@example.com' })
    ).rejects.toThrow(/duplicate key/);
  });
});
```

### API Integration Tests

```javascript
// API integration tests with supertest
const request = require('supertest');
const app = require('../app');

describe('API Integration Tests', () => {
  let authToken;

  beforeAll(async () => {
    // Get auth token for protected endpoints
    const response = await request(app)
      .post('/api/auth/login')
      .send({ email: 'test@example.com', password: 'password123' });

    authToken = response.body.token;
  });

  describe('GET /api/users', () => {
    it('should return users list', async () => {
      const response = await request(app)
        .get('/api/users')
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200);

      expect(Array.isArray(response.body)).toBe(true);
    });

    it('should return 401 without auth', async () => {
      await request(app).get('/api/users').expect(401);
    });
  });

  describe('POST /api/orders', () => {
    it('should create order', async () => {
      const response = await request(app)
        .post('/api/orders')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          items: [{ productId: 1, quantity: 2 }],
        })
        .expect(201);

      expect(response.body.id).toBeDefined();
      expect(response.body.status).toBe('pending');
    });
  });
});
```

## End-to-End Testing

### Playwright E2E Tests

```javascript
// e2e/checkout.spec.js
const { test, expect } = require('@playwright/test');

test.describe('Checkout Flow', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
  });

  test('complete purchase flow', async ({ page }) => {
    // Add item to cart
    await page.click('[data-testid="product-1"]');
    await page.click('[data-testid="add-to-cart"]');

    // Verify cart
    await page.click('[data-testid="cart-icon"]');
    await expect(page.locator('[data-testid="cart-count"]')).toHaveText('1');

    // Proceed to checkout
    await page.click('[data-testid="checkout-button"]');

    // Fill shipping info
    await page.fill('[name="firstName"]', 'John');
    await page.fill('[name="lastName"]', 'Doe');
    await page.fill('[name="address"]', '123 Main St');
    await page.fill('[name="city"]', 'New York');
    await page.selectOption('[name="state"]', 'NY');
    await page.fill('[name="zip"]', '10001');

    // Fill payment info
    await page.fill('[name="cardNumber"]', '4242424242424242');
    await page.fill('[name="expiry"]', '12/25');
    await page.fill('[name="cvv"]', '123');

    // Submit order
    await page.click('[data-testid="place-order"]');

    // Verify confirmation
    await expect(page).toHaveURL(/\/order-confirmation/);
    await expect(
      page.locator('[data-testid="order-number"]')
    ).toBeVisible();
  });

  test('shows error for invalid card', async ({ page }) => {
    // Navigate to checkout with item in cart
    await page.click('[data-testid="product-1"]');
    await page.click('[data-testid="add-to-cart"]');
    await page.click('[data-testid="checkout-button"]');

    // Fill with invalid card
    await page.fill('[name="cardNumber"]', '4000000000000002');
    await page.fill('[name="expiry"]', '12/25');
    await page.fill('[name="cvv"]', '123');

    await page.click('[data-testid="place-order"]');

    await expect(
      page.locator('[data-testid="payment-error"]')
    ).toContainText('Card declined');
  });
});

// playwright.config.js
module.exports = {
  testDir: './e2e',
  timeout: 30000,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 4 : undefined,

  use: {
    baseURL: process.env.BASE_URL || 'http://localhost:3000',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },

  projects: [
    { name: 'chromium', use: { browserName: 'chromium' } },
    { name: 'firefox', use: { browserName: 'firefox' } },
    { name: 'webkit', use: { browserName: 'webkit' } },
  ],

  webServer: {
    command: 'npm run start',
    port: 3000,
    reuseExistingServer: !process.env.CI,
  },
};
```

### Visual Regression Testing

```javascript
// Visual regression with Playwright
test('homepage visual regression', async ({ page }) => {
  await page.goto('/');

  // Wait for dynamic content
  await page.waitForSelector('[data-testid="hero-section"]');

  // Take screenshot
  await expect(page).toHaveScreenshot('homepage.png', {
    fullPage: true,
    animations: 'disabled',
  });
});

// Component visual testing
test('button states', async ({ page }) => {
  await page.goto('/design-system');

  const button = page.locator('[data-testid="primary-button"]');

  // Default state
  await expect(button).toHaveScreenshot('button-default.png');

  // Hover state
  await button.hover();
  await expect(button).toHaveScreenshot('button-hover.png');

  // Focus state
  await button.focus();
  await expect(button).toHaveScreenshot('button-focus.png');
});
```

## Contract Testing

### Pact Consumer Test

```javascript
// Consumer test (frontend)
const { Pact } = require('@pact-foundation/pact');
const { UserClient } = require('./UserClient');

describe('User API Contract', () => {
  const provider = new Pact({
    consumer: 'Frontend',
    provider: 'UserService',
    port: 1234,
  });

  beforeAll(() => provider.setup());
  afterAll(() => provider.finalize());
  afterEach(() => provider.verify());

  describe('get user by id', () => {
    it('returns user when exists', async () => {
      await provider.addInteraction({
        state: 'user 123 exists',
        uponReceiving: 'a request for user 123',
        withRequest: {
          method: 'GET',
          path: '/api/users/123',
          headers: { Accept: 'application/json' },
        },
        willRespondWith: {
          status: 200,
          headers: { 'Content-Type': 'application/json' },
          body: {
            id: 123,
            email: Matchers.email(),
            name: Matchers.string('John Doe'),
          },
        },
      });

      const client = new UserClient(provider.mockService.baseUrl);
      const user = await client.getUser(123);

      expect(user.id).toBe(123);
    });
  });
});
```

## Test Data Management

### Test Data Factory

```javascript
// factories/user.factory.js
const { faker } = require('@faker-js/faker');

const createUser = (overrides = {}) => ({
  id: faker.string.uuid(),
  email: faker.internet.email(),
  name: faker.person.fullName(),
  createdAt: faker.date.past(),
  ...overrides,
});

const createOrder = (overrides = {}) => ({
  id: faker.string.uuid(),
  userId: faker.string.uuid(),
  items: [
    {
      productId: faker.string.uuid(),
      quantity: faker.number.int({ min: 1, max: 10 }),
      price: faker.number.float({ min: 10, max: 1000, precision: 0.01 }),
    },
  ],
  status: 'pending',
  createdAt: faker.date.recent(),
  ...overrides,
});

module.exports = { createUser, createOrder };
```

### Database Seeding

```javascript
// seeds/test-data.js
const { createUser, createOrder } = require('./factories');
const db = require('./db');

async function seedTestData() {
  // Create users
  const users = Array.from({ length: 10 }, () => createUser());
  await db('users').insert(users);

  // Create orders for each user
  const orders = users.flatMap((user) =>
    Array.from({ length: 3 }, () =>
      createOrder({ userId: user.id })
    )
  );
  await db('orders').insert(orders);

  return { users, orders };
}

async function cleanupTestData() {
  await db('orders').delete();
  await db('users').delete();
}

module.exports = { seedTestData, cleanupTestData };
```

## Test Reliability

### Handling Flaky Tests

```yaml
# Retry configuration
name: Tests with Retry

jobs:
  tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
      - run: npm ci

      # Retry flaky tests up to 3 times
      - run: npm test -- --retries=3

      # Quarantine flaky tests
      - run: npm test -- --grep @flaky --skip
        continue-on-error: true
```

```javascript
// Jest retry configuration
// jest.config.js
module.exports = {
  testRetry: {
    retries: 2,
    retryStrategy: 'isolate',
  },
};

// Playwright retry
module.exports = {
  retries: process.env.CI ? 2 : 0,
  reporter: [
    ['list'],
    ['json', { outputFile: 'test-results.json' }],
  ],
};
```

### Flaky Test Detection

```yaml
# Track test stability
- name: Run tests with timing
  run: |
    npm test -- --json --outputFile=results.json

- name: Analyze flaky tests
  run: |
    node << 'EOF'
    const results = require('./results.json');
    const flaky = results.testResults
      .flatMap(r => r.assertionResults)
      .filter(t => t.retryReasons && t.retryReasons.length > 0);

    if (flaky.length > 0) {
      console.log('Flaky tests detected:');
      flaky.forEach(t => console.log(`  - ${t.fullName}`));
    }
    EOF
```

## Test Reporting

### Coverage and Reports

```yaml
# Test reporting
- name: Run tests with coverage
  run: npm test -- --coverage --reporters=default --reporters=jest-junit

- name: Upload coverage to Codecov
  uses: codecov/codecov-action@v4
  with:
    files: coverage/lcov.info
    fail_ci_if_error: true

- name: Upload test results
  uses: dorny/test-reporter@v1
  if: always()
  with:
    name: Jest Tests
    path: junit.xml
    reporter: jest-junit

- name: Comment on PR with coverage
  uses: romeovs/lcov-reporter-action@v0.3.1
  if: github.event_name == 'pull_request'
  with:
    lcov-file: coverage/lcov.info
    github-token: ${{ secrets.GITHUB_TOKEN }}
```

### Coverage Gates

```yaml
# Coverage threshold enforcement
- name: Check coverage threshold
  run: |
    COVERAGE=$(cat coverage/coverage-summary.json | jq '.total.lines.pct')
    if (( $(echo "$COVERAGE < 80" | bc -l) )); then
      echo "Coverage $COVERAGE% is below 80% threshold"
      exit 1
    fi
```

## Hands-On Exercise

### Exercise: Build a Complete Test Pipeline

1. Set up unit tests with Jest and coverage reporting
2. Configure integration tests with database services
3. Implement E2E tests with Playwright
4. Add visual regression testing
5. Configure test sharding for parallel execution
6. Set up coverage gates and reporting

## Summary

- The test pyramid guides test distribution for optimal coverage and speed
- Unit tests provide fast feedback and should be the foundation
- Integration tests verify component interactions with real dependencies
- E2E tests validate complete user flows but are slower and costlier
- Test data factories ensure consistent, realistic test data
- Flaky test management is essential for reliable pipelines
- Coverage reporting enables tracking of quality metrics

## Additional Resources

- [Jest Documentation](https://jestjs.io/docs/getting-started)
- [Playwright Documentation](https://playwright.dev/docs/intro)
- [Pact Contract Testing](https://docs.pact.io/)
- [Testing Best Practices](https://testingjavascript.com/)

## Next Steps

In the next module, we'll explore release management, learning how to manage versions, changelogs, and releases effectively.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- The Test Pyramid
- Unit Testing
- Integration Testing
- End-to-End Testing

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
