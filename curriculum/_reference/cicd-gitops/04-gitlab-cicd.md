# Module 04: GitLab CI/CD

## Learning Objectives

By the end of this module, you will be able to:
- Configure GitLab CI/CD pipelines using `.gitlab-ci.yml`
- Implement advanced pipeline features like DAG, rules, and includes
- Use GitLab's Auto DevOps and built-in security scanning
- Configure GitLab Runners for different environments
- Manage environments and deployments with GitLab
- Integrate GitLab CI/CD with Kubernetes and cloud providers

## Introduction

GitLab CI/CD is a powerful continuous integration and deployment tool built directly into GitLab. It offers a comprehensive DevOps platform with features like built-in container registry, security scanning, and Kubernetes integration, making it a complete solution for the entire software development lifecycle.

## GitLab CI/CD Architecture

### Core Components

<!-- figure: generated from the Mermaid below by _shared/diagrams/embed-figures.py — do not edit the image -->
![Core Components — diagram](../../../_figures/curriculum-_reference-cicd-gitops-04-gitlab-cicd-0-dcd0ccbf.png)

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
  subgraph SRV["GitLab server"]
    direction LR
    PE["Pipeline engine"]
    CR["Container registry"]
    PR["Package registry"]
    SS["Security scanning"]
  end
  SH["Shared runner<br/><i>SaaS, shared with everyone</i>"]
  GR["Group runner<br/><i>organisation-wide</i>"]
  PJ["Project runner<br/><i>dedicated</i>"]
  SRV ==> SH
  SRV ==> GR
  SRV ==> PJ
  class PE crit
  class CR,PR n
  class SS crit
  class SH mut
  class GR n
  class PJ crit
  linkStyle 0,1,2 stroke:#2f6fb8,stroke-width:2px
```

</details>

**Runner executors**

| Executor | Runs the job |
|---|---|
| `shell` | Directly on the runner host — fast, and it shares state between builds |
| `docker` | In a container, from a clean image each time |
| `docker+machine` | The same, on a VM provisioned per job and destroyed after (auto-scaling) |
| `kubernetes` | As a pod, so the cluster does the scaling |
| `custom` | Whatever you script |

`shell` is the one to avoid by default: a build that leaves a file behind, or changes a global
package, silently changes the next build on that runner.

### Pipeline Concepts

```yaml
# .gitlab-ci.yml structure
# Global configuration
default:
  image: node:20-alpine
  tags:
    - docker

# Stage definitions
stages:
  - build
  - test
  - security
  - deploy

# Variables
variables:
  APP_NAME: myapp
  DOCKER_DRIVER: overlay2

# Job definitions
build:
  stage: build
  script:
    - npm ci
    - npm run build
  artifacts:
    paths:
      - dist/

test:
  stage: test
  script:
    - npm test
```

## Pipeline Configuration

### Complete Pipeline Example

```yaml
# .gitlab-ci.yml
# Default settings for all jobs
default:
  image: node:20-alpine
  before_script:
    - npm config set cache /cache/npm --global
  interruptible: true
  retry:
    max: 2
    when:
      - runner_system_failure
      - stuck_or_timeout_failure

# Workflow rules
workflow:
  rules:
    - if: $CI_MERGE_REQUEST_IID
    - if: $CI_COMMIT_TAG
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH

# Stage definitions
stages:
  - prepare
  - build
  - test
  - security
  - package
  - deploy

# Global variables
variables:
  DOCKER_HOST: tcp://docker:2375
  DOCKER_TLS_CERTDIR: ""
  FF_USE_FASTZIP: "true"
  ARTIFACT_COMPRESSION_LEVEL: "fast"
  CACHE_COMPRESSION_LEVEL: "fast"

# Prepare stage
install-dependencies:
  stage: prepare
  script:
    - npm ci --prefer-offline
  cache:
    key:
      files:
        - package-lock.json
    paths:
      - node_modules/
    policy: pull-push
  artifacts:
    paths:
      - node_modules/
    expire_in: 1 hour

# Build stage
build:
  stage: build
  needs: [install-dependencies]
  script:
    - npm run build
  artifacts:
    paths:
      - dist/
    expire_in: 1 week

# Test stage with parallel jobs
unit-test:
  stage: test
  needs: [install-dependencies]
  parallel: 3
  script:
    - npm run test:unit -- --shard=$CI_NODE_INDEX/$CI_NODE_TOTAL
  coverage: '/Lines\s*:\s*(\d+\.\d+)%/'
  artifacts:
    reports:
      junit: junit.xml
      coverage_report:
        coverage_format: cobertura
        path: coverage/cobertura-coverage.xml

integration-test:
  stage: test
  needs: [install-dependencies, build]
  services:
    - postgres:15
    - redis:7
  variables:
    POSTGRES_DB: test
    POSTGRES_USER: test
    POSTGRES_PASSWORD: test
    DATABASE_URL: postgres://test:test@postgres:5432/test
    REDIS_URL: redis://redis:6379
  script:
    - npm run test:integration

e2e-test:
  stage: test
  needs: [build]
  image: mcr.microsoft.com/playwright:v1.40.0-focal
  script:
    - npm run test:e2e
  artifacts:
    when: always
    paths:
      - playwright-report/
    expire_in: 1 week
  rules:
    - if: $CI_MERGE_REQUEST_IID
      when: manual
      allow_failure: true
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH

# Security stage
sast:
  stage: security
  include:
    - template: Security/SAST.gitlab-ci.yml

dependency-scan:
  stage: security
  needs: [install-dependencies]
  script:
    - npm audit --audit-level=high
    - npx snyk test
  allow_failure: true

container-scan:
  stage: security
  needs: [build-image]
  include:
    - template: Security/Container-Scanning.gitlab-ci.yml

# Package stage
build-image:
  stage: package
  image: docker:24
  services:
    - docker:24-dind
  needs: [build]
  before_script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
  script:
    - docker build -t $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA .
    - docker push $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
    - |
      if [ "$CI_COMMIT_BRANCH" == "$CI_DEFAULT_BRANCH" ]; then
        docker tag $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA $CI_REGISTRY_IMAGE:latest
        docker push $CI_REGISTRY_IMAGE:latest
      fi
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
    - if: $CI_MERGE_REQUEST_IID

# Deploy stages
.deploy-template: &deploy-template
  stage: deploy
  image: bitnami/kubectl:latest
  needs: [build-image, unit-test, integration-test]
  before_script:
    - kubectl config use-context $KUBE_CONTEXT
  script:
    - |
      helm upgrade --install $APP_NAME ./chart \
        --namespace $KUBE_NAMESPACE \
        --set image.tag=$CI_COMMIT_SHA \
        --set environment=$CI_ENVIRONMENT_NAME \
        --wait

deploy-staging:
  <<: *deploy-template
  environment:
    name: staging
    url: https://staging.example.com
    on_stop: stop-staging
  variables:
    KUBE_CONTEXT: staging-cluster
    KUBE_NAMESPACE: staging
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
      when: on_success

stop-staging:
  stage: deploy
  image: bitnami/kubectl:latest
  script:
    - helm uninstall $APP_NAME -n staging
  environment:
    name: staging
    action: stop
  when: manual
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH

deploy-production:
  <<: *deploy-template
  environment:
    name: production
    url: https://app.example.com
  variables:
    KUBE_CONTEXT: production-cluster
    KUBE_NAMESPACE: production
  rules:
    - if: $CI_COMMIT_TAG =~ /^v\d+\.\d+\.\d+$/
      when: manual
  resource_group: production
```

## Rules and Conditions

### Rules Syntax

```yaml
# Complex rule examples
job-with-rules:
  script: echo "Hello"
  rules:
    # Run on merge requests
    - if: $CI_MERGE_REQUEST_IID
      when: on_success

    # Run on tags matching pattern
    - if: $CI_COMMIT_TAG =~ /^v\d+\.\d+\.\d+$/
      when: always

    # Run on default branch
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
      when: on_success

    # Never run on feature branches
    - if: $CI_COMMIT_BRANCH =~ /^feature\//
      when: never

    # Run when specific files change
    - changes:
        - src/**/*
        - package.json
      when: on_success

    # Combination of conditions
    - if: $CI_PIPELINE_SOURCE == "schedule"
      changes:
        - Dockerfile
      when: always

    # Allow failure for specific conditions
    - if: $CI_COMMIT_BRANCH =~ /^experiment\//
      allow_failure: true

    # Default - never run
    - when: never

# Using variables in rules
conditional-deploy:
  script: deploy.sh
  rules:
    - if: $DEPLOY_ENABLED == "true"
      when: on_success
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
      variables:
        DEPLOY_TARGET: staging
    - when: never
```

### Only/Except (Legacy)

```yaml
# Legacy syntax (use rules instead)
legacy-job:
  script: echo "Legacy"
  only:
    - main
    - /^release-.*$/
    - merge_requests
  except:
    - schedules
    - triggers
```

## DAG Pipelines

### Directed Acyclic Graph

```yaml
# DAG pipeline with needs keyword
stages:
  - build
  - test
  - deploy

# Build jobs (parallel)
build-frontend:
  stage: build
  script: npm run build:frontend
  artifacts:
    paths:
      - frontend/dist/

build-backend:
  stage: build
  script: go build -o backend ./...
  artifacts:
    paths:
      - backend

build-docs:
  stage: build
  script: mkdocs build
  artifacts:
    paths:
      - site/

# Test jobs with specific dependencies
test-frontend:
  stage: test
  needs: [build-frontend]
  script: npm run test:frontend

test-backend:
  stage: test
  needs: [build-backend]
  script: go test ./...

test-integration:
  stage: test
  needs: [build-frontend, build-backend]
  script: ./run-integration-tests.sh

# Deploy doesn't wait for docs
deploy:
  stage: deploy
  needs: [test-frontend, test-backend, test-integration]
  script: ./deploy.sh
  # Optional: include artifacts from needs
  # needs:
  #   - job: build-frontend
  #     artifacts: true
```

### Pipeline Visualization

<!-- figure: generated from the Mermaid below by _shared/diagrams/embed-figures.py — do not edit the image -->
![Pipeline Visualization — diagram](../../../_figures/curriculum-_reference-cicd-gitops-04-gitlab-cicd-1-97a61f5f.png)

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
  BF["build-frontend"]
  BB["build-backend"]
  BD["build-docs"]
  TF["test-frontend"]
  TB["test-backend"]
  TI["test-integration"]
  DP["deploy"]
  BF ==> TF
  BB ==> TB
  TF ==> TI
  TB ==> TI
  TI ==> DP
  class BF,BB,TF,TB n
  class BD mut
  class TI crit
  class DP crit
  linkStyle 0,1,2,3,4 stroke:#2f6fb8,stroke-width:2px

%% `build-docs` has no edge at all, and that is the point of a DAG pipeline: with
%% plain stages it would sit in the "build" stage and hold up every test until it
%% finished. Declaring `needs:` turns the stage list into a dependency graph, and
%% anything not on the critical path stops being on the critical path.
```

</details>

## Include and Extends

### Including Templates

```yaml
# Main .gitlab-ci.yml
include:
  # Local file
  - local: '.gitlab/ci/build.yml'

  # Remote file
  - remote: 'https://example.com/ci-templates/deploy.yml'

  # Project file
  - project: 'company/ci-templates'
    ref: main
    file:
      - '/templates/docker.yml'
      - '/templates/kubernetes.yml'

  # GitLab templates
  - template: Security/SAST.gitlab-ci.yml
  - template: Security/Secret-Detection.gitlab-ci.yml

# Override included jobs
sast:
  variables:
    SAST_EXCLUDED_PATHS: "spec, test, tests, tmp"
```

### Extends and Anchors

```yaml
# Hidden job templates
.node-template:
  image: node:20-alpine
  before_script:
    - npm ci
  cache:
    key: ${CI_COMMIT_REF_SLUG}
    paths:
      - node_modules/

.deploy-template:
  image: bitnami/kubectl:latest
  before_script:
    - kubectl config use-context $KUBE_CONTEXT
  script:
    - helm upgrade --install $APP_NAME ./chart
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH

# Using extends
build:
  extends: .node-template
  stage: build
  script:
    - npm run build

test:
  extends: .node-template
  stage: test
  script:
    - npm test

deploy-staging:
  extends: .deploy-template
  environment:
    name: staging
  variables:
    KUBE_CONTEXT: staging

deploy-prod:
  extends: .deploy-template
  environment:
    name: production
  variables:
    KUBE_CONTEXT: production
  when: manual

# YAML anchors (alternative)
.base-config: &base-config
  tags:
    - docker
  retry: 2

job-using-anchor:
  <<: *base-config
  script: echo "Using anchor"
```

## Environments and Deployments

### Environment Configuration

```yaml
# Environment management
deploy-review:
  stage: deploy
  script:
    - helm upgrade --install review-$CI_MERGE_REQUEST_IID ./chart \
        --set host=$CI_ENVIRONMENT_URL
  environment:
    name: review/$CI_MERGE_REQUEST_IID
    url: https://$CI_MERGE_REQUEST_IID.review.example.com
    on_stop: stop-review
    auto_stop_in: 1 week
  rules:
    - if: $CI_MERGE_REQUEST_IID

stop-review:
  stage: deploy
  script:
    - helm uninstall review-$CI_MERGE_REQUEST_IID
  environment:
    name: review/$CI_MERGE_REQUEST_IID
    action: stop
  when: manual
  rules:
    - if: $CI_MERGE_REQUEST_IID

deploy-staging:
  stage: deploy
  script:
    - helm upgrade --install staging ./chart
  environment:
    name: staging
    url: https://staging.example.com
    deployment_tier: staging
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH

deploy-production:
  stage: deploy
  script:
    - helm upgrade --install production ./chart
  environment:
    name: production
    url: https://example.com
    deployment_tier: production
  resource_group: production
  rules:
    - if: $CI_COMMIT_TAG
      when: manual
```

### Release Management

```yaml
# Automated releases
release:
  stage: deploy
  image: registry.gitlab.com/gitlab-org/release-cli:latest
  script:
    - echo "Creating release $CI_COMMIT_TAG"
  release:
    tag_name: $CI_COMMIT_TAG
    name: 'Release $CI_COMMIT_TAG'
    description: './CHANGELOG.md'
    assets:
      links:
        - name: 'Docker Image'
          url: 'https://registry.example.com/app:$CI_COMMIT_TAG'
        - name: 'Helm Chart'
          url: 'https://charts.example.com/app-$CI_COMMIT_TAG.tgz'
  rules:
    - if: $CI_COMMIT_TAG =~ /^v\d+\.\d+\.\d+$/
```

## GitLab Runners

### Runner Registration

```bash
# Register a Docker runner
gitlab-runner register \
  --non-interactive \
  --url "https://gitlab.example.com/" \
  --registration-token "$REGISTRATION_TOKEN" \
  --executor "docker" \
  --docker-image "alpine:latest" \
  --description "Docker Runner" \
  --tag-list "docker,linux" \
  --run-untagged="true" \
  --locked="false"

# Register a Kubernetes runner
gitlab-runner register \
  --non-interactive \
  --url "https://gitlab.example.com/" \
  --registration-token "$REGISTRATION_TOKEN" \
  --executor "kubernetes" \
  --kubernetes-namespace "gitlab-runner" \
  --kubernetes-service-account "gitlab-runner"
```

### Runner Configuration

```toml
# /etc/gitlab-runner/config.toml
concurrent = 10
check_interval = 0

[[runners]]
  name = "docker-runner"
  url = "https://gitlab.example.com/"
  token = "runner-token"
  executor = "docker"

  [runners.docker]
    tls_verify = false
    image = "alpine:latest"
    privileged = true
    disable_cache = false
    volumes = ["/cache", "/var/run/docker.sock:/var/run/docker.sock"]
    shm_size = 0

  [runners.cache]
    Type = "s3"
    Shared = true

    [runners.cache.s3]
      ServerAddress = "s3.amazonaws.com"
      BucketName = "gitlab-runner-cache"
      BucketLocation = "us-east-1"

[[runners]]
  name = "kubernetes-runner"
  url = "https://gitlab.example.com/"
  token = "runner-token"
  executor = "kubernetes"

  [runners.kubernetes]
    namespace = "gitlab-runner"
    image = "alpine:latest"
    privileged = true

    [[runners.kubernetes.volumes.host_path]]
      name = "docker"
      mount_path = "/var/run/docker.sock"
      host_path = "/var/run/docker.sock"

    [runners.kubernetes.node_selector]
      "node.kubernetes.io/instance-type" = "m5.large"
```

## Security Features

### Built-in Security Scanning

```yaml
# Complete security pipeline
include:
  - template: Security/SAST.gitlab-ci.yml
  - template: Security/Secret-Detection.gitlab-ci.yml
  - template: Security/Dependency-Scanning.gitlab-ci.yml
  - template: Security/Container-Scanning.gitlab-ci.yml
  - template: Security/DAST.gitlab-ci.yml
  - template: Security/License-Scanning.gitlab-ci.yml

# Customize SAST
sast:
  variables:
    SAST_EXCLUDED_PATHS: "spec, test, tests, tmp, vendor"
    SEARCH_MAX_DEPTH: 4

# Container scanning
container_scanning:
  variables:
    CS_IMAGE: $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA

# DAST (Dynamic Application Security Testing)
dast:
  variables:
    DAST_WEBSITE: https://staging.example.com
    DAST_FULL_SCAN_ENABLED: "true"
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH

# Custom security job
security-audit:
  stage: security
  script:
    - npm audit --audit-level=high
    - trivy image $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
  artifacts:
    reports:
      sast: gl-sast-report.json
```

### Compliance Pipeline

```yaml
# Compliance framework enforcement
include:
  - project: 'company/compliance'
    file: '/templates/compliance-pipeline.yml'

# Required jobs that can't be overridden
compliance:
  stage: .pre
  script:
    - ./check-compliance.sh
  rules:
    - when: always

# Security approval gate
security-gate:
  stage: security
  script:
    - |
      CRITICAL=$(cat gl-sast-report.json | jq '.vulnerabilities | map(select(.severity == "Critical")) | length')
      if [ "$CRITICAL" -gt 0 ]; then
        echo "Found $CRITICAL critical vulnerabilities"
        exit 1
      fi
  artifacts:
    reports:
      sast: gl-sast-report.json
```

## Kubernetes Integration

### Kubernetes Agent

```yaml
# Deploy using GitLab Kubernetes Agent
deploy:
  stage: deploy
  image:
    name: bitnami/kubectl:latest
    entrypoint: ['']
  script:
    - kubectl config use-context $CI_PROJECT_PATH:production-agent
    - kubectl apply -f k8s/
  environment:
    name: production
    kubernetes:
      namespace: production

# GitOps with Flux/ArgoCD
gitops-deploy:
  stage: deploy
  script:
    - |
      yq -i '.spec.template.spec.containers[0].image = "$CI_REGISTRY_IMAGE:$CI_COMMIT_SHA"' \
        kubernetes/deployment.yaml
    - git add .
    - git commit -m "Deploy $CI_COMMIT_SHA"
    - git push origin HEAD:deploy
```

## Variables and Secrets

### Variable Hierarchy

```yaml
# Variable precedence (lowest to highest):
# 1. GitLab CI/CD variables
# 2. Project CI/CD variables
# 3. Group CI/CD variables
# 4. Instance CI/CD variables
# 5. .gitlab-ci.yml variables
# 6. Job variables
# 7. Pipeline trigger variables

variables:
  GLOBAL_VAR: "global"

job:
  variables:
    JOB_VAR: "job"
    GLOBAL_VAR: "overridden"  # Overrides global
  script:
    - echo "$GLOBAL_VAR"  # Outputs: overridden
```

### Protected and Masked Variables

```yaml
# Referencing protected variables
deploy:
  script:
    - echo $DEPLOY_PASSWORD  # Masked in logs
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
      # Protected variables only available on protected branches

# File-type variables
use-file-variable:
  script:
    - cat $KUBECONFIG  # File path
    - kubectl --kubeconfig=$KUBECONFIG get pods
```

## Auto DevOps

### Enabling Auto DevOps

```yaml
# Minimal configuration with Auto DevOps
include:
  - template: Auto-DevOps.gitlab-ci.yml

variables:
  # Customize Auto DevOps
  AUTO_DEVOPS_PLATFORM_TARGET: EKS
  KUBE_INGRESS_BASE_DOMAIN: example.com

  # Build customization
  AUTO_DEVOPS_BUILD_IMAGE_EXTRA_ARGS: "--build-arg NODE_ENV=production"

  # Test customization
  TEST_DISABLED: "false"
  CODE_QUALITY_DISABLED: "false"

  # Deploy customization
  STAGING_ENABLED: "true"
  CANARY_ENABLED: "true"
  INCREMENTAL_ROLLOUT_MODE: "manual"
```

## Hands-On Exercise

### Exercise: Build a Complete GitLab Pipeline

1. Create a multi-stage pipeline with:
   - Build, test, security, and deploy stages
   - DAG optimization for parallel execution
   - Matrix testing across Node versions
   - Security scanning integration

2. Configure environments for staging and production
3. Implement review apps for merge requests
4. Add release automation with changelog

## Summary

- GitLab CI/CD provides integrated DevOps capabilities
- Pipelines are defined in `.gitlab-ci.yml` with stages and jobs
- Rules and conditions control when jobs run
- DAG pipelines enable efficient parallel execution
- Includes and extends promote configuration reuse
- Built-in security scanning covers SAST, DAST, and more
- GitLab Runners execute jobs with various executors
- Auto DevOps provides zero-configuration CI/CD

## Additional Resources

- [GitLab CI/CD Documentation](https://docs.gitlab.com/ee/ci/)
- [GitLab CI/CD YAML Syntax](https://docs.gitlab.com/ee/ci/yaml/)
- [GitLab Runner Documentation](https://docs.gitlab.com/runner/)
- [Auto DevOps](https://docs.gitlab.com/ee/topics/autodevops/)

## Next Steps

In the next module, we'll explore ArgoCD and GitOps principles, learning how to implement declarative, Git-based continuous deployment.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- GitLab CI/CD Architecture
- Pipeline Configuration
- Rules and Conditions
- DAG Pipelines

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
