# Module 12: CI/CD Best Practices and Patterns

## Learning Objectives

By the end of this module, you will be able to:
- Apply industry best practices to CI/CD implementations
- Identify and avoid common anti-patterns
- Design scalable and maintainable pipelines
- Implement effective monitoring and observability
- Build a culture of continuous improvement
- Create documentation and runbooks for CI/CD systems

## Introduction

This module consolidates the lessons learned throughout Phase 4, providing a comprehensive reference for CI/CD best practices. These patterns and practices have been proven in production environments across organizations of all sizes.

## Pipeline Design Principles

### Core Principles

**CI/CD design principles**

| | Principle | In practice |
|---|---|---|
| **1** | **Fast feedback** | Target under 10 minutes for CI · run the fast tests first · fail immediately on lint and compile errors |
| **2** | **Reproducibility** | Same input, same output · pin every version — dependencies, tools, base images · no network fetches you do not control |
| **3** | **Visibility** | Clear status at every stage · logs and artifacts one click away · notify on failure *and* on recovery |
| **4** | **Security** | Least privilege · no secrets in code or logs · artifacts signed and verified |
| **5** | **Maintainability** | Reusable components and templates · pipeline definitions in version control · names that explain themselves |

Principle 1 is a constraint on the others, not a peer of them. Every feature you add to a pipeline
costs seconds, and past about ten minutes developers stop waiting for the result and start context
switching — at which point the feedback is no longer feedback, it is a notification they will read
later.

### Pipeline Architecture Patterns

```yaml
# Pattern 1: Sequential with Fail-Fast
# Best for: Simple projects, quick feedback
stages:
  - lint      # Fail fast on code quality
  - build     # Compile/package
  - test      # Run tests
  - deploy    # Deploy to environment

# Pattern 2: Parallel with Fan-In
# Best for: Complex projects, multiple test types
stages:
  - prepare
  - build
  - test      # Multiple parallel test jobs
  - merge     # Fan-in point
  - deploy

test-unit:
  stage: test
  parallel: 4

test-integration:
  stage: test

test-e2e:
  stage: test

deploy:
  stage: deploy
  needs: [test-unit, test-integration, test-e2e]

# Pattern 3: DAG Pipeline
# Best for: Microservices, independent components
# Jobs run as soon as dependencies are met

build-api:
  stage: build

build-web:
  stage: build

test-api:
  needs: [build-api]

test-web:
  needs: [build-web]

deploy-api:
  needs: [test-api]

deploy-web:
  needs: [test-web, deploy-api]  # Web depends on API
```

## Best Practices Checklist

### Build Stage

```yaml
# Best practices for build stage
build:
  stage: build
  script:
    # Use lock files for reproducible builds
    - npm ci --prefer-offline  # Not npm install

    # Cache dependencies
    - npm run build

  cache:
    key:
      files:
        - package-lock.json
    paths:
      - node_modules/

  # Store build artifacts
  artifacts:
    paths:
      - dist/
    expire_in: 1 week

  # Resource limits prevent runaway builds
  timeout: 15m

  # Retry transient failures
  retry:
    max: 2
    when:
      - runner_system_failure
      - stuck_or_timeout_failure
```

### Test Stage

```yaml
# Best practices for testing
test:
  stage: test
  script:
    - npm test -- --ci --coverage

  # Parallel execution for faster feedback
  parallel: 4

  # Test reports for visibility
  artifacts:
    reports:
      junit: junit.xml
      coverage_report:
        coverage_format: cobertura
        path: coverage/cobertura-coverage.xml

  # Coverage requirements
  coverage: '/Lines\s*:\s*(\d+\.\d+)%/'

  # Don't block on flaky tests, but track them
  allow_failure: false
  retry:
    max: 2
    when:
      - script_failure
```

### Deploy Stage

```yaml
# Best practices for deployment
deploy:
  stage: deploy
  script:
    - ./deploy.sh

  # Environment tracking
  environment:
    name: production
    url: https://app.example.com

  # Require approval for production
  when: manual

  # Prevent concurrent deployments
  resource_group: production

  # Only deploy from protected branches
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
      when: manual

  # Deployment timeout
  timeout: 30m

  # Rollback capability
  after_script:
    - |
      if [ "$CI_JOB_STATUS" == "failed" ]; then
        ./rollback.sh
      fi
```

## Anti-Patterns to Avoid

### Common Anti-Patterns

**CI/CD Anti-Patterns**

❌ Long-Running Builds
   Problem: Slow feedback, context switching
   Solution: Optimize, parallelize, cache
❌ Flaky Tests
   Problem: Erodes trust, wastes time
   Solution: Quarantine, fix, or remove
❌ Manual Steps
   Problem: Human error, inconsistency
   Solution: Automate everything
❌ Secrets in Code
   Problem: Security vulnerability
   Solution: Secret management, environment variables
❌ Ignoring Failed Builds
   Problem: Technical debt, broken main
   Solution: Fix immediately, block merges
❌ Snowflake Pipelines
   Problem: Maintenance burden, inconsistency
   Solution: Templates, shared libraries
❌ No Rollback Strategy
   Problem: Extended outages
   Solution: Automated rollback, blue-green
❌ Tight Coupling
   Problem: Cascading failures, blocked deployments
   Solution: Independent deployability


### Anti-Pattern Examples and Fixes

```yaml
# ❌ Anti-pattern: Sequential when parallel is possible
bad-pipeline:
  script:
    - npm run lint
    - npm run test:unit
    - npm run test:integration
    - npm run test:e2e

# ✅ Better: Parallel execution
lint:
  stage: validate
  script: npm run lint

test-unit:
  stage: test
  script: npm run test:unit

test-integration:
  stage: test
  script: npm run test:integration

test-e2e:
  stage: test
  script: npm run test:e2e

---
# ❌ Anti-pattern: Hardcoded values
bad-deploy:
  script:
    - docker push myregistry.com/myapp:latest
    - kubectl set image deployment/myapp myapp=myregistry.com/myapp:latest

# ✅ Better: Variables and proper tagging
good-deploy:
  variables:
    REGISTRY: $CI_REGISTRY
    IMAGE: $CI_REGISTRY_IMAGE
    TAG: $CI_COMMIT_SHA
  script:
    - docker push $IMAGE:$TAG
    - kubectl set image deployment/$CI_PROJECT_NAME app=$IMAGE:$TAG

---
# ❌ Anti-pattern: No caching
bad-build:
  script:
    - npm install  # Downloads everything every time
    - npm run build

# ✅ Better: Effective caching
good-build:
  cache:
    key: ${CI_COMMIT_REF_SLUG}
    paths:
      - node_modules/
      - .npm/
  script:
    - npm ci --cache .npm --prefer-offline
    - npm run build
```

## Pipeline Optimization

### Performance Optimization

```yaml
# Optimization techniques
optimized-pipeline:
  variables:
    # Enable faster artifact compression
    FF_USE_FASTZIP: "true"
    ARTIFACT_COMPRESSION_LEVEL: fast
    CACHE_COMPRESSION_LEVEL: fast

    # Docker optimizations
    DOCKER_DRIVER: overlay2
    DOCKER_BUILDKIT: 1

  # Use smallest possible base image
  image: alpine:3.18

  # Conditional job execution
  rules:
    - changes:
        - src/**/*
        - package.json
      when: on_success
    - when: never

  script:
    # Parallel npm install
    - npm ci --maxsockets 10

    # Incremental builds
    - npm run build -- --incremental

  cache:
    # Distributed cache for shared runners
    key:
      files:
        - package-lock.json
      prefix: ${CI_JOB_NAME}
    paths:
      - node_modules/
      - .npm/
    policy: pull-push

  artifacts:
    # Only upload what's needed
    paths:
      - dist/
    exclude:
      - dist/**/*.map
    expire_in: 1 day
```

### Resource Optimization

```yaml
# Resource-aware pipeline
resource-optimized:
  # Right-size runners
  tags:
    - small  # For lint/simple tasks

build:
  tags:
    - medium  # For compilation

test-e2e:
  tags:
    - large  # For browser tests

# Interruptible for cost savings
interruptible: true

# Auto-cancel redundant pipelines
workflow:
  auto_cancel:
    on_new_commit: interruptible
```

## Monitoring and Observability

### Pipeline Metrics

```yaml
# Export pipeline metrics
metrics-export:
  stage: .post
  script:
    - |
      cat << EOF | curl --data-binary @- http://pushgateway:9091/metrics/job/ci_pipeline
      # HELP ci_pipeline_duration_seconds Pipeline duration
      # TYPE ci_pipeline_duration_seconds gauge
      ci_pipeline_duration_seconds{project="$CI_PROJECT_NAME",status="$CI_PIPELINE_STATUS"} $CI_PIPELINE_DURATION

      # HELP ci_job_count Total jobs in pipeline
      # TYPE ci_job_count gauge
      ci_job_count{project="$CI_PROJECT_NAME"} $CI_JOB_COUNT
      EOF
```

### Dashboard Metrics

**CI/CD Dashboard Metrics**

**Lead Time Metrics:**

- Commit to deployment time
- Build duration (p50, p95, p99)
- Test duration by type
- Queue wait time

**Quality Metrics:**

- Build success rate
- Test pass rate
- Code coverage trend
- Flaky test count

**Deployment Metrics:**

- Deployment frequency
- Change failure rate
- Mean time to recovery (MTTR)
- Rollback rate

**Resource Metrics:**

- Runner utilization
- Cache hit rate
- Artifact storage usage
- Concurrent job count


### Alerting Rules

```yaml
# Prometheus alerting rules
groups:
  - name: ci-cd-alerts
    rules:
      - alert: PipelineFailureRate
        expr: |
          sum(rate(ci_pipeline_status{status="failed"}[1h])) /
          sum(rate(ci_pipeline_status[1h])) > 0.2
        for: 15m
        labels:
          severity: warning
        annotations:
          summary: "High pipeline failure rate"
          description: "More than 20% of pipelines are failing"

      - alert: SlowPipeline
        expr: |
          histogram_quantile(0.95, ci_pipeline_duration_seconds_bucket) > 1800
        for: 30m
        labels:
          severity: warning
        annotations:
          summary: "Slow pipeline execution"
          description: "P95 pipeline duration exceeds 30 minutes"

      - alert: QueueBacklog
        expr: ci_pending_jobs > 50
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Large job queue backlog"
```

## Documentation

### Pipeline Documentation Template

```markdown
# CI/CD Pipeline Documentation

## Overview

Brief description of the pipeline purpose and flow.

## Architecture

```
[Diagram showing pipeline stages and flow]
```

## Stages

### 1. Build Stage
- **Purpose**: Compile and package the application
- **Duration**: ~5 minutes
- **Artifacts**: `dist/`, `build/`

### 2. Test Stage
- **Purpose**: Run automated tests
- **Duration**: ~10 minutes
- **Reports**: JUnit XML, Coverage

### 3. Deploy Stage
- **Purpose**: Deploy to target environment
- **Duration**: ~5 minutes
- **Environments**: staging, production

## Configuration

### Required Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `NPM_TOKEN` | npm registry token | Yes |
| `DEPLOY_KEY` | SSH key for deployment | Yes |

### Optional Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SKIP_TESTS` | `false` | Skip test stage |
| `DEPLOY_ENV` | `staging` | Target environment |

## Troubleshooting

### Common Issues

1. **Build fails with npm error**
   - Check npm registry connectivity
   - Verify package-lock.json is up to date

2. **Tests timeout**
   - Check for flaky tests
   - Increase timeout if needed

### Getting Help

- Slack: #ci-cd-support
- Wiki: [CI/CD Troubleshooting Guide]
```

### Runbook Template

````markdown
# Runbook: Production Deployment Failure

## Overview
Steps to handle failed production deployments.

## Detection
- Alert: `DeploymentFailed`
- Slack notification to #deployments

## Impact
- **Severity**: High
- **Affected Users**: All production users
- **SLA**: 15 minutes to rollback

## Response Steps

### 1. Verify Failure (2 min)
```bash
kubectl get pods -n production
kubectl describe deployment myapp -n production
```

### 2. Assess Impact (3 min)
- Check error logs
- Verify service availability
- Check metrics dashboard

### 3. Rollback if Needed (5 min)
```bash
# Automated rollback
kubectl rollout undo deployment/myapp -n production

# Or restore previous version
helm rollback myapp 1 -n production
```

### 4. Notify Stakeholders
- Update #incidents channel
- Create incident ticket

### 5. Post-Incident
- Root cause analysis
- Update runbooks if needed
- Implement preventive measures

## Escalation
- After 15 min: Page on-call engineer
- After 30 min: Escalate to engineering lead
````

## Culture and Process

### CI/CD Culture

**CI/CD Culture Principles**

**Everyone Commits Daily**

- Small, frequent changes
- Feature flags for incomplete features
- Trunk-based development

**Broken Builds are Priority**

- Fix or revert immediately
- No new commits on broken main
- Automated notifications

**Shared Ownership**

- Everyone can deploy
- Everyone monitors production
- Blameless postmortems

**Continuous Improvement**

- Regular retrospectives
- Metrics-driven decisions
- Investment in tooling


### Maturity Model

**Level 1: Basic**

- Version control for code
- Automated builds
- Some automated tests
- Manual deployments

**Level 2: Defined**

- Standardized pipeline templates
- Automated testing (unit, integration)
- Staging environments
- Semi-automated deployments

**Level 3: Managed**

- Comprehensive test coverage
- Automated deployments
- Environment parity
- Metrics tracking

**Level 4: Optimized**

- Continuous deployment
- Canary/blue-green deployments
- Self-service platforms
- Proactive optimization

**Level 5: Elite**

- Multiple deploys per day
- < 1 hour lead time
- < 15% change failure rate
- < 1 hour recovery time


## Summary

### Key Takeaways

1. **Fast Feedback**: Optimize for quick developer feedback
2. **Reproducibility**: Same inputs should produce same outputs
3. **Security**: Protect credentials and verify artifacts
4. **Observability**: Measure and alert on pipeline health
5. **Documentation**: Maintain runbooks and troubleshooting guides
6. **Culture**: Foster shared ownership and continuous improvement

### Implementation Checklist

```
Pipeline Setup:
□ Version-controlled pipeline definitions
□ Standardized templates/shared libraries
□ Proper branching strategy

Build:
□ Reproducible builds with pinned versions
□ Effective caching strategy
□ Reasonable timeout limits

Testing:
□ Test pyramid implementation
□ Coverage requirements
□ Flaky test management

Deployment:
□ Environment-based approvals
□ Rollback capability
□ Health checks and smoke tests

Security:
□ Secret management
□ OIDC authentication
□ Artifact signing

Monitoring:
□ Pipeline metrics
□ Alerting rules
□ Dashboard visibility

Documentation:
□ Pipeline documentation
□ Runbooks
□ Troubleshooting guides
```

## Additional Resources

- [DORA Research](https://dora.dev/)
- [Accelerate Book](https://itrevolution.com/book/accelerate/)
- [Continuous Delivery](https://continuousdelivery.com/)
- [The DevOps Handbook](https://itrevolution.com/book/the-devops-handbook/)

## Conclusion

Effective CI/CD is not just about tools—it's about practices, culture, and continuous improvement. Apply these best practices incrementally, measure progress with metrics, and foster a culture of shared ownership and learning.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Pipeline Design Principles
- Best Practices Checklist
- Anti-Patterns to Avoid
- Pipeline Optimization

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
