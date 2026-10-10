# Lab 11: Feature Flags and Progressive Delivery

## Overview

In this lab, you'll implement feature flags for progressive delivery. You'll learn to safely roll out features, run A/B experiments, and implement operational flags for system control.

**Duration**: 3-4 hours
**Difficulty**: Intermediate to Advanced

## Prerequisites

- Node.js 20+ installed
- Docker installed
- Kubernetes cluster (minikube or kind)
- Basic understanding of deployment strategies

## Learning Objectives

- Implement feature flags with different strategies
- Integrate feature flags in CI/CD pipelines
- Run A/B experiments with proper analysis
- Implement operational flags for system control
- Set up feature flag lifecycle management

## Lab Environment Setup

```bash
# Create lab directory
mkdir -p ~/feature-flags-lab && cd ~/feature-flags-lab

# Initialize project
npm init -y

# Install dependencies
npm install express
npm install -D jest supertest

# Install feature flag SDKs
npm install @openfeature/server-sdk \
  @openfeature/flagd-provider \
  unleash-client \
  launchdarkly-node-server-sdk

# Create project structure
mkdir -p src/{flags,middleware,routes} tests

# Create sample application
cat > src/app.js << 'EOF'
const express = require('express');
const { featureFlags } = require('./flags/feature-flags');

const app = express();
app.use(express.json());

// Feature flag middleware
app.use(async (req, res, next) => {
  // Attach feature flag context to request
  req.flagContext = {
    userId: req.headers['x-user-id'] || 'anonymous',
    userEmail: req.headers['x-user-email'] || '',
    country: req.headers['x-country'] || 'US',
    percentage: Math.random() * 100
  };
  next();
});

// Home route with feature flag
app.get('/', async (req, res) => {
  const newHomepage = await featureFlags.isEnabled('new-homepage', req.flagContext);

  if (newHomepage) {
    res.json({
      message: 'Welcome to the NEW homepage!',
      version: 'v2',
      features: ['dark-mode', 'quick-actions', 'recommendations']
    });
  } else {
    res.json({
      message: 'Welcome to the homepage!',
      version: 'v1'
    });
  }
});

// Pricing route with percentage rollout
app.get('/pricing', async (req, res) => {
  const newPricing = await featureFlags.isEnabled('new-pricing-tier', req.flagContext);

  const plans = newPricing ? [
    { name: 'Starter', price: 9 },
    { name: 'Pro', price: 29 },
    { name: 'Enterprise', price: 99 },
    { name: 'Ultimate', price: 199 }  // New tier
  ] : [
    { name: 'Starter', price: 9 },
    { name: 'Pro', price: 29 },
    { name: 'Enterprise', price: 99 }
  ];

  res.json({ plans, experimentGroup: newPricing ? 'treatment' : 'control' });
});

// Search route with A/B test
app.get('/search', async (req, res) => {
  const searchAlgorithm = await featureFlags.getVariant('search-algorithm', req.flagContext);

  const query = req.query.q || '';
  let results;

  switch (searchAlgorithm) {
    case 'ml-v2':
      results = { algorithm: 'ml-v2', query, results: ['ML result 1', 'ML result 2'] };
      break;
    case 'semantic':
      results = { algorithm: 'semantic', query, results: ['Semantic result 1', 'Semantic result 2'] };
      break;
    default:
      results = { algorithm: 'default', query, results: ['Default result 1', 'Default result 2'] };
  }

  res.json(results);
});

// Feature flag status endpoint (for debugging)
app.get('/flags', async (req, res) => {
  const flags = await featureFlags.getAllFlags(req.flagContext);
  res.json(flags);
});

// Health check with circuit breaker flag
app.get('/health', async (req, res) => {
  const maintenanceMode = await featureFlags.isEnabled('maintenance-mode', {});

  if (maintenanceMode) {
    res.status(503).json({
      status: 'maintenance',
      message: 'System is under maintenance'
    });
  } else {
    res.json({ status: 'healthy' });
  }
});

module.exports = app;
EOF

# Create feature flag implementation
cat > src/flags/feature-flags.js << 'EOF'
// Feature flag implementation with multiple strategies

class FeatureFlags {
  constructor() {
    this.flags = new Map();
    this.initializeFlags();
  }

  initializeFlags() {
    // Boolean flag - simple on/off
    this.flags.set('new-homepage', {
      type: 'boolean',
      enabled: process.env.FLAG_NEW_HOMEPAGE === 'true',
      description: 'Enable new homepage design'
    });

    // Percentage rollout flag
    this.flags.set('new-pricing-tier', {
      type: 'percentage',
      percentage: parseInt(process.env.FLAG_NEW_PRICING_PERCENTAGE || '0'),
      description: 'Gradually roll out new pricing tier'
    });

    // A/B test with variants
    this.flags.set('search-algorithm', {
      type: 'variant',
      variants: {
        'default': 60,
        'ml-v2': 20,
        'semantic': 20
      },
      description: 'A/B test for search algorithm'
    });

    // Operational flag
    this.flags.set('maintenance-mode', {
      type: 'boolean',
      enabled: process.env.FLAG_MAINTENANCE === 'true',
      description: 'Enable maintenance mode'
    });

    // User targeting flag
    this.flags.set('beta-features', {
      type: 'targeting',
      rules: [
        { attribute: 'userEmail', pattern: /@internal\.com$/, enabled: true },
        { attribute: 'country', values: ['US', 'CA'], enabled: true }
      ],
      defaultEnabled: false,
      description: 'Enable beta features for specific users'
    });
  }

  async isEnabled(flagName, context = {}) {
    const flag = this.flags.get(flagName);
    if (!flag) return false;

    switch (flag.type) {
      case 'boolean':
        return flag.enabled;

      case 'percentage':
        const hash = this.hashContext(context.userId || 'default', flagName);
        return (hash % 100) < flag.percentage;

      case 'targeting':
        return this.evaluateTargeting(flag, context);

      default:
        return false;
    }
  }

  async getVariant(flagName, context = {}) {
    const flag = this.flags.get(flagName);
    if (!flag || flag.type !== 'variant') return 'default';

    const hash = this.hashContext(context.userId || 'default', flagName);
    const bucket = hash % 100;

    let cumulative = 0;
    for (const [variant, percentage] of Object.entries(flag.variants)) {
      cumulative += percentage;
      if (bucket < cumulative) return variant;
    }

    return 'default';
  }

  async getAllFlags(context = {}) {
    const result = {};
    for (const [name, flag] of this.flags) {
      if (flag.type === 'variant') {
        result[name] = await this.getVariant(name, context);
      } else {
        result[name] = await this.isEnabled(name, context);
      }
    }
    return result;
  }

  evaluateTargeting(flag, context) {
    for (const rule of flag.rules) {
      const value = context[rule.attribute];
      if (!value) continue;

      if (rule.pattern && new RegExp(rule.pattern).test(value)) {
        return rule.enabled;
      }
      if (rule.values && rule.values.includes(value)) {
        return rule.enabled;
      }
    }
    return flag.defaultEnabled;
  }

  hashContext(userId, flagName) {
    // Simple hash function for consistent bucketing
    const str = `${userId}-${flagName}`;
    let hash = 0;
    for (let i = 0; i < str.length; i++) {
      const char = str.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash;
    }
    return Math.abs(hash);
  }

  // For testing and dynamic updates
  updateFlag(flagName, updates) {
    const flag = this.flags.get(flagName);
    if (flag) {
      this.flags.set(flagName, { ...flag, ...updates });
    }
  }
}

const featureFlags = new FeatureFlags();

module.exports = { featureFlags, FeatureFlags };
EOF

# Create server
cat > src/server.js << 'EOF'
const app = require('./app');

const port = process.env.PORT || 3000;

app.listen(port, () => {
  console.log(`Server running on port ${port}`);
  console.log('Feature flags loaded');
});
EOF
```

---

## Part 1: Guided Exercise - Basic Feature Flags

### Step 1: Create Feature Flag Tests

```javascript
// tests/feature-flags.test.js
const request = require('supertest');
const app = require('../src/app');
const { featureFlags } = require('../src/flags/feature-flags');

describe('Feature Flags', () => {
  describe('Boolean flags', () => {
    test('returns v1 homepage when flag is disabled', async () => {
      featureFlags.updateFlag('new-homepage', { enabled: false });

      const response = await request(app).get('/');

      expect(response.body.version).toBe('v1');
      expect(response.body.features).toBeUndefined();
    });

    test('returns v2 homepage when flag is enabled', async () => {
      featureFlags.updateFlag('new-homepage', { enabled: true });

      const response = await request(app).get('/');

      expect(response.body.version).toBe('v2');
      expect(response.body.features).toContain('dark-mode');
    });
  });

  describe('Percentage rollout', () => {
    test('respects percentage rollout', async () => {
      featureFlags.updateFlag('new-pricing-tier', { percentage: 50 });

      let treatmentCount = 0;
      const iterations = 100;

      // Test with different user IDs
      for (let i = 0; i < iterations; i++) {
        const response = await request(app)
          .get('/pricing')
          .set('X-User-ID', `user-${i}`);

        if (response.body.experimentGroup === 'treatment') {
          treatmentCount++;
        }
      }

      // Should be roughly 50% (with some variance)
      expect(treatmentCount).toBeGreaterThan(30);
      expect(treatmentCount).toBeLessThan(70);
    });
  });

  describe('Variant flags (A/B tests)', () => {
    test('returns consistent variant for same user', async () => {
      const responses = await Promise.all([
        request(app).get('/search?q=test').set('X-User-ID', 'user-123'),
        request(app).get('/search?q=test').set('X-User-ID', 'user-123'),
        request(app).get('/search?q=test').set('X-User-ID', 'user-123')
      ]);

      const algorithms = responses.map(r => r.body.algorithm);
      expect(new Set(algorithms).size).toBe(1); // All same
    });
  });

  describe('Operational flags', () => {
    test('returns 503 in maintenance mode', async () => {
      featureFlags.updateFlag('maintenance-mode', { enabled: true });

      const response = await request(app).get('/health');

      expect(response.status).toBe(503);
      expect(response.body.status).toBe('maintenance');
    });
  });
});
```

### Step 2: Create CI/CD Integration

```yaml
# .github/workflows/feature-flags.yml
name: Feature Flag Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  FLAG_NEW_HOMEPAGE: 'false'
  FLAG_NEW_PRICING_PERCENTAGE: '0'
  FLAG_MAINTENANCE: 'false'

jobs:
  test:
    name: Test with Feature Flags
    runs-on: ubuntu-latest
    strategy:
      matrix:
        flag-config:
          - name: 'all-flags-off'
            env:
              FLAG_NEW_HOMEPAGE: 'false'
              FLAG_NEW_PRICING_PERCENTAGE: '0'
          - name: 'all-flags-on'
            env:
              FLAG_NEW_HOMEPAGE: 'true'
              FLAG_NEW_PRICING_PERCENTAGE: '100'
          - name: 'partial-rollout'
            env:
              FLAG_NEW_HOMEPAGE: 'true'
              FLAG_NEW_PRICING_PERCENTAGE: '50'
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install dependencies
        run: npm ci

      - name: Run tests (${{ matrix.flag-config.name }})
        env: ${{ matrix.flag-config.env }}
        run: npm test

  deploy-staging:
    needs: test
    runs-on: ubuntu-latest
    environment: staging
    steps:
      - uses: actions/checkout@v4

      - name: Deploy with flag configuration
        run: |
          echo "Deploying with staging feature flags"
          # kubectl apply with staging ConfigMap

  progressive-rollout:
    needs: deploy-staging
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment: production
    steps:
      - name: Enable flag for 10%
        run: |
          # Update flag to 10%
          echo "Rolling out to 10%"
          sleep 60  # Monitor metrics

      - name: Enable flag for 50%
        run: |
          # Update flag to 50%
          echo "Rolling out to 50%"
          sleep 60  # Monitor metrics

      - name: Enable flag for 100%
        run: |
          # Update flag to 100%
          echo "Full rollout complete"
```

### Step 3: Deploy Flagd (OpenFeature Provider)

```bash
# Deploy Flagd to Kubernetes
cat > flagd-deployment.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: flagd-config
data:
  flags.json: |
    {
      "$schema": "https://flagd.dev/schema/v0/flags.json",
      "flags": {
        "new-homepage": {
          "state": "ENABLED",
          "variants": {
            "on": true,
            "off": false
          },
          "defaultVariant": "off",
          "targeting": {
            "if": [
              { "in": ["@internal.com", { "var": "email" }] },
              "on",
              "off"
            ]
          }
        },
        "new-pricing-tier": {
          "state": "ENABLED",
          "variants": {
            "on": true,
            "off": false
          },
          "defaultVariant": "off",
          "targeting": {
            "fractional": [
              { "var": "userId" },
              ["on", 20],
              ["off", 80]
            ]
          }
        },
        "search-algorithm": {
          "state": "ENABLED",
          "variants": {
            "default": "default",
            "ml-v2": "ml-v2",
            "semantic": "semantic"
          },
          "defaultVariant": "default",
          "targeting": {
            "fractional": [
              { "var": "userId" },
              ["default", 60],
              ["ml-v2", 20],
              ["semantic", 20]
            ]
          }
        }
      }
    }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: flagd
spec:
  replicas: 2
  selector:
    matchLabels:
      app: flagd
  template:
    metadata:
      labels:
        app: flagd
    spec:
      containers:
        - name: flagd
          image: ghcr.io/open-feature/flagd:latest
          ports:
            - containerPort: 8013
          args:
            - start
            - --uri
            - file:/etc/flagd/flags.json
          volumeMounts:
            - name: config
              mountPath: /etc/flagd
      volumes:
        - name: config
          configMap:
            name: flagd-config
---
apiVersion: v1
kind: Service
metadata:
  name: flagd
spec:
  selector:
    app: flagd
  ports:
    - port: 8013
      targetPort: 8013
EOF

kubectl apply -f flagd-deployment.yaml
```

---

## Part 2: Semi-Guided Exercise - A/B Testing with Metrics

### Objective

Implement A/B testing with:
- Experiment assignment
- Metrics collection
- Statistical analysis
- Automated decisions

### Requirements

1. **Create experiment tracking**

<details>
<summary>Click for experiment tracking hint</summary>

```javascript
// Experiment event tracking
class ExperimentTracker {
  async trackExposure(experimentId, variant, userId) {
    await this.emit('exposure', {
      experimentId,
      variant,
      userId,
      timestamp: Date.now()
    });
  }

  async trackConversion(experimentId, conversionType, userId, value) {
    await this.emit('conversion', {
      experimentId,
      conversionType,
      userId,
      value,
      timestamp: Date.now()
    });
  }
}
```
</details>

2. **Implement metrics collection**

<details>
<summary>Click for metrics hint</summary>

```javascript
// Prometheus metrics
const { Counter, Histogram } = require('prom-client');

const experimentExposures = new Counter({
  name: 'experiment_exposures_total',
  help: 'Total experiment exposures',
  labelNames: ['experiment', 'variant']
});

const experimentConversions = new Counter({
  name: 'experiment_conversions_total',
  help: 'Total experiment conversions',
  labelNames: ['experiment', 'variant', 'type']
});
```
</details>

3. **Set up analysis pipeline**

### Tasks

1. Implement experiment exposure tracking
2. Track conversion events
3. Calculate statistical significance
4. Create experiment dashboard
5. Implement automatic rollout based on results

### Validation

```bash
# Check experiment metrics
curl localhost:9090/api/v1/query?query=experiment_exposures_total

# Verify conversion tracking
curl localhost:3000/metrics | grep experiment_conversions

# Check experiment results API
curl localhost:3000/experiments/search-algorithm/results
```

---

## Part 3: Challenge - Enterprise Feature Flag Platform

### Objective

Build a complete feature flag platform with:
- Centralized flag management
- Environment promotion
- Audit logging
- Stale flag detection

### Requirements

1. **Deploy Unleash**

```bash
# Deploy Unleash to Kubernetes
cat > unleash-deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: unleash
spec:
  replicas: 2
  selector:
    matchLabels:
      app: unleash
  template:
    metadata:
      labels:
        app: unleash
    spec:
      containers:
        - name: unleash
          image: unleashorg/unleash-server:latest
          ports:
            - containerPort: 4242
          env:
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: unleash-secrets
                  key: database-url
            - name: DATABASE_SSL
              value: "false"
---
apiVersion: v1
kind: Service
metadata:
  name: unleash
spec:
  selector:
    app: unleash
  ports:
    - port: 4242
      targetPort: 4242
EOF

kubectl apply -f unleash-deployment.yaml
```

2. **Implement flag lifecycle management**

3. **Create promotion workflow**

4. **Set up stale flag detection**

### Success Criteria

- [ ] Centralized flag management UI
- [ ] Flag promotion across environments
- [ ] Audit log for all changes
- [ ] Stale flag alerts
- [ ] Integration with CI/CD
- [ ] SDK integration working

### Starting Point - Flag Lifecycle Management

```javascript
// Flag lifecycle management
class FlagLifecycle {
  constructor(client) {
    this.client = client;
    this.staleDays = 30;
  }

  async detectStaleFlags() {
    const flags = await this.client.getAllFlags();
    const now = Date.now();
    const staleFlags = [];

    for (const flag of flags) {
      const lastUsed = flag.lastSeenAt || flag.createdAt;
      const daysSinceUse = (now - new Date(lastUsed)) / (1000 * 60 * 60 * 24);

      if (daysSinceUse > this.staleDays) {
        staleFlags.push({
          name: flag.name,
          daysSinceUse: Math.floor(daysSinceUse),
          createdAt: flag.createdAt,
          type: flag.type
        });
      }
    }

    return staleFlags;
  }

  async notifyStaleFlags() {
    const staleFlags = await this.detectStaleFlags();

    if (staleFlags.length > 0) {
      console.log('Stale flags detected:', staleFlags);
      // Send Slack notification
      // Create Jira tickets
      // Update dashboard
    }
  }

  async promoteFlag(flagName, fromEnv, toEnv) {
    // Get flag config from source environment
    const sourceConfig = await this.client.getFlagConfig(flagName, fromEnv);

    // Validate flag exists and is stable
    if (!sourceConfig.stable) {
      throw new Error(`Flag ${flagName} is not marked as stable`);
    }

    // Apply to target environment
    await this.client.updateFlagConfig(flagName, toEnv, sourceConfig);

    // Log promotion
    await this.client.logAudit({
      action: 'promote',
      flag: flagName,
      from: fromEnv,
      to: toEnv,
      user: process.env.USER,
      timestamp: new Date().toISOString()
    });

    return { success: true, flag: flagName, environment: toEnv };
  }
}
```

### Starting Point - CI/CD Flag Promotion

```yaml
# .github/workflows/flag-promotion.yml
name: Feature Flag Promotion

on:
  workflow_dispatch:
    inputs:
      flag_name:
        description: 'Flag to promote'
        required: true
      source_env:
        description: 'Source environment'
        required: true
        type: choice
        options:
          - development
          - staging
      target_env:
        description: 'Target environment'
        required: true
        type: choice
        options:
          - staging
          - production

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - name: Validate promotion path
        run: |
          if [[ "${{ inputs.source_env }}" == "development" && "${{ inputs.target_env }}" == "production" ]]; then
            echo "Cannot promote directly from development to production"
            exit 1
          fi

      - name: Check flag exists
        run: |
          FLAG_EXISTS=$(curl -s -o /dev/null -w "%{http_code}" \
            -H "Authorization: Bearer ${{ secrets.UNLEASH_TOKEN }}" \
            "${{ secrets.UNLEASH_URL }}/api/admin/features/${{ inputs.flag_name }}")

          if [ "$FLAG_EXISTS" != "200" ]; then
            echo "Flag ${{ inputs.flag_name }} not found"
            exit 1
          fi

  approve:
    needs: validate
    runs-on: ubuntu-latest
    environment: ${{ inputs.target_env }}
    steps:
      - name: Approval received
        run: echo "Promotion to ${{ inputs.target_env }} approved"

  promote:
    needs: approve
    runs-on: ubuntu-latest
    steps:
      - name: Promote flag
        run: |
          # Get flag config from source
          SOURCE_CONFIG=$(curl -s \
            -H "Authorization: Bearer ${{ secrets.UNLEASH_TOKEN }}" \
            "${{ secrets.UNLEASH_URL }}/api/admin/features/${{ inputs.flag_name }}")

          # Update in target environment
          curl -X PUT \
            -H "Authorization: Bearer ${{ secrets.UNLEASH_TOKEN }}" \
            -H "Content-Type: application/json" \
            -d "$SOURCE_CONFIG" \
            "${{ secrets.UNLEASH_URL }}/api/admin/projects/default/features/${{ inputs.flag_name }}/environments/${{ inputs.target_env }}"

      - name: Notify promotion
        run: |
          echo "Flag ${{ inputs.flag_name }} promoted to ${{ inputs.target_env }}"
```

### Validation Script

```bash
#!/bin/bash
# validate-feature-flags.sh

echo "Validating Feature Flags Setup..."

# Check feature flag service
if curl -s http://localhost:4242/health > /dev/null 2>&1; then
    echo "✓ Unleash is running"
elif curl -s http://localhost:8013 > /dev/null 2>&1; then
    echo "✓ Flagd is running"
else
    echo "⚠ No feature flag service detected"
fi

# Check application integration
if [ -f "src/flags/feature-flags.js" ]; then
    echo "✓ Feature flag module exists"
fi

# Check for flag tests
FLAG_TESTS=$(find tests -name "*.test.js" -exec grep -l "feature" {} \; | wc -l)
echo "✓ Found $FLAG_TESTS test files with feature flag tests"

# Check for stale flags (mock check)
echo "Checking for stale flags..."
if command -v curl &> /dev/null; then
    # Would check against actual service
    echo "⚠ Stale flag check requires running service"
fi

# Verify CI/CD workflow
if [ -f ".github/workflows/feature-flags.yml" ]; then
    echo "✓ Feature flag workflow exists"
else
    echo "⚠ No feature flag workflow found"
fi

# Check for metrics integration
if grep -r "prom-client" package.json > /dev/null 2>&1; then
    echo "✓ Prometheus metrics integration available"
fi

echo ""
echo "Validation complete!"
```

---

## Cleanup

```bash
# Stop services
kubectl delete -f unleash-deployment.yaml
kubectl delete -f flagd-deployment.yaml

# Remove lab files
cd ~
rm -rf feature-flags-lab
```

## Summary

In this lab, you learned:
- Implementing different feature flag types
- Integrating feature flags in CI/CD pipelines
- Running A/B experiments with proper tracking
- Managing flag lifecycle and detecting stale flags
- Promoting flags across environments
- Using OpenFeature and Unleash for feature management

## Next Steps

- Implement feature flag analytics dashboard
- Set up automated flag cleanup
- Configure flag dependencies
- Implement kill switches for incidents

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Challenge - Enterprise Feature Flag Platform
- Create Feature Flag Tests
- Create CI/CD Integration
- Deploy Flagd (OpenFeature Provider)

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
