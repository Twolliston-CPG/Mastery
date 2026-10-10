# Domain 8: Developer Experience -- Configuration Reference

## 1. Pre-Commit Configuration (`.pre-commit-config.yaml`)

### Installation

```bash
# Install pre-commit
pip install pre-commit

# Install hooks in your repository
pre-commit install

# Install commit-msg hooks (for commitizen)
pre-commit install --hook-type commit-msg

# Run all hooks manually
pre-commit run --all-files
```

### Hook Configuration Parameters

#### Gitleaks (Secret Detection)

```yaml
- repo: https://github.com/gitleaks/gitleaks
  rev: v8.18.1
  hooks:
    - id: gitleaks
      entry: gitleaks protect --verbose --redact --staged
      language: golang
      pass_filenames: false
```

| Parameter | Value | Description |
|-----------|-------|-------------|
| `--verbose` | flag | Show detailed output for each finding |
| `--redact` | flag | Redact secret values in output |
| `--staged` | flag | Only scan staged changes (not entire repo) |
| `pass_filenames: false` | config | Gitleaks manages its own file discovery |

#### Terraform Hooks

```yaml
- repo: https://github.com/antonbabenko/pre-commit-terraform
  rev: v1.86.0
  hooks:
    - id: terraform_fmt
    - id: terraform_validate
    - id: terraform_tflint
      args:
        - --args=--config=__GIT_WORKING_DIR__/.tflint.hcl
    - id: terraform_checkov
      args:
        - --args=--quiet
        - --args=--framework terraform
        - --args=--skip-check CKV_GCP_32   # [GCP-SPECIFIC] Skip private cluster check
    - id: terraform_docs
      args:
        - --args=--config=.terraform-docs.yml
```

| Hook | Key Args | Description |
|------|----------|-------------|
| `terraform_fmt` | none | Auto-formats `.tf` files |
| `terraform_validate` | none | Validates HCL syntax and references |
| `terraform_tflint` | `--config=.tflint.hcl` | External TFLint rules file |
| `terraform_checkov` | `--skip-check CKV_GCP_32` | Skip checks not applicable to your environment |
| `terraform_docs` | `--config=.terraform-docs.yml` | Generate docs per config |

#### Go Hooks

```yaml
# golangci-lint
- repo: https://github.com/golangci/golangci-lint
  rev: v1.55.2
  hooks:
    - id: golangci-lint
      types: [go]
      args:
        - --timeout=5m
        - --config=.golangci.yml

# gosec
- repo: https://github.com/securego/gosec
  rev: v2.18.2
  hooks:
    - id: gosec
      types: [go]
      args:
        - -exclude-generated
        - -severity=medium
        - ./...
```

| Parameter | Value | Description |
|-----------|-------|-------------|
| `--timeout=5m` | golangci-lint | Maximum execution time |
| `--config=.golangci.yml` | golangci-lint | External linter config |
| `-exclude-generated` | gosec | Skip generated code files |
| `-severity=medium` | gosec | Only report medium+ severity |

#### Pre-Commit Hooks (Standard)

```yaml
- repo: https://github.com/pre-commit/pre-commit-hooks
  rev: v4.5.0
  hooks:
    - id: check-yaml
      args: ['--unsafe']              # Allow custom YAML tags (e.g., Helm templates)
    - id: check-json
    - id: check-merge-conflict
    - id: end-of-file-fixer
    - id: trailing-whitespace
    - id: no-commit-to-branch
      args: ['--branch', 'main', '--branch', 'master']
    - id: detect-private-key
```

#### Kubernetes Hooks

```yaml
# Helm lint
- repo: https://github.com/gruntwork-io/pre-commit
  rev: v0.1.23
  hooks:
    - id: helmlint

# K8s manifest validation
- repo: https://github.com/python-jsonschema/check-jsonschema
  rev: 0.27.3
  hooks:
    - id: check-kubernetes-json-schema
      files: k8s-manifests/.*\.(yaml|yml)$
      args:
        - --kubernetes-version=1.28.0
```

| Parameter | Value | Description |
|-----------|-------|-------------|
| `files` | `k8s-manifests/.*\.(yaml\|yml)$` | Only validate files in k8s-manifests directory |
| `--kubernetes-version` | `1.28.0` | Validate against specific K8s API version |

#### Docker Hook

```yaml
- repo: https://github.com/hadolint/hadolint
  rev: v2.12.0
  hooks:
    - id: hadolint-docker
      entry: hadolint
      args:
        - --ignore=DL3008     # Pin versions in apt-get install
        - --ignore=DL3018     # Pin versions in apk add
```

#### Markdown and Commit Hooks

```yaml
# Markdown linting
- repo: https://github.com/igorshubovych/markdownlint-cli
  rev: v0.38.0
  hooks:
    - id: markdownlint
      args:
        - --config=.markdownlint.json
        - --fix                # Auto-fix issues where possible

# Conventional commits
- repo: https://github.com/commitizen-tools/commitizen
  rev: v3.13.0
  hooks:
    - id: commitizen
      stages: [commit-msg]    # Runs on commit message, not on files
```

#### pre-commit.ci Configuration

```yaml
ci:
  autofix_commit_msg: |
    [pre-commit.ci] auto fixes from pre-commit hooks

    for more information, see https://pre-commit.ci
  autofix_prs: true
  autoupdate_branch: ''           # Update the default branch
  autoupdate_commit_msg: '[pre-commit.ci] pre-commit autoupdate'
  autoupdate_schedule: weekly     # Check for hook updates weekly
  skip: []                        # No hooks skipped in CI
  submodules: false
```

---

## 2. golangci-lint Configuration (`.golangci.yml`)

### Linter Categories

#### Security Linters

| Linter | Purpose |
|--------|---------|
| `gosec` | Go security checker -- finds SQL injection, hardcoded creds, insecure crypto |
| `bodyclose` | Ensures HTTP response bodies are closed |
| `noctx` | Finds HTTP requests without `context.Context` |
| `rowserrcheck` | Ensures `sql.Rows.Err()` is checked |
| `sqlclosecheck` | Ensures `sql.Rows` and `sql.Stmt` are closed |

#### Error Handling Linters

| Linter | Purpose |
|--------|---------|
| `errcheck` | Finds unchecked errors (with type assertion and blank identifier checks) |
| `errorlint` | Finds issues with error wrapping (Go 1.13+) |
| `wrapcheck` | Ensures errors from external packages are wrapped |

#### Code Quality Linters

| Linter | Purpose |
|--------|---------|
| `govet` | Official Go vet tool with all analyzers enabled |
| `staticcheck` | Advanced static analysis |
| `ineffassign` | Detects inVantage Consulting assignments |
| `unused` | Finds unused code |
| `typecheck` | Type checking |

#### Style Linters

| Linter | Purpose |
|--------|---------|
| `gofmt` | Enforces standard Go formatting |
| `goimports` | Enforces import ordering and grouping |
| `misspell` | Catches common misspellings |
| `unconvert` | Removes unnecessary type conversions |
| `unparam` | Finds unused function parameters |

#### Complexity Linters

| Linter | Threshold | Description |
|--------|-----------|-------------|
| `cyclop` | 15 | Cyclomatic complexity per function |
| `gocognit` | 20 | Cognitive complexity per function |
| `gocyclo` | 15 | Cyclomatic complexity (alternative) |
| `maintidx` | default | Maintainability index |

#### Best Practice Linters

| Linter | Purpose |
|--------|---------|
| `gocritic` | Diagnostic, style, performance, and experimental checks |
| `revive` | Configurable Go linter (replaces golint) with 22 rules enabled |
| `prealloc` | Suggests slice pre-allocation |
| `exportloopref` | Detects loop variable capture (deprecated in Go 1.22+) |

### Key Settings

```yaml
# gosec settings
gosec:
  severity: medium
  confidence: medium
  excludes:
    - G104                    # Errors unhandled -- too noisy for some patterns
  config:
    global:
      audit: enabled          # Enable audit mode for thorough analysis

# Error checking
errcheck:
  check-type-assertions: true # Check type assertion ok values
  check-blank: true           # Check blank identifier error assignments
  exclude-functions:          # Common functions where error is safely ignored
    - io.Copy
    - io.WriteTo
    - (io.Closer).Close

# Complexity thresholds
cyclop:
  max-complexity: 15
  skip-tests: true            # Don't check complexity in test files

# govet with all analyzers
govet:
  check-shadowing: true
  enable-all: true
```

### Exclusion Rules

```yaml
issues:
  exclude-rules:
    # Test files: relax security and error checks
    - path: _test\.go
      linters: [gosec, errcheck, wrapcheck, gocognit, cyclop]

    # Generated files: skip all linting
    - path: generated
      linters: [all]

    # Mock files: skip all linting
    - path: mock
      linters: [all]

  max-issues-per-linter: 50   # Cap output per linter
  max-same-issues: 3          # Cap duplicate issues
```

---

## 3. Markdown Linter Configuration (`.markdownlint.json`)

```json
{
  "default": true,
  "MD001": true,                          // Heading increment (no skipping levels)
  "MD003": { "style": "atx" },           // ATX-style headings (# not underlines)
  "MD004": { "style": "dash" },          // Unordered list style (- not * or +)
  "MD007": { "indent": 2 },              // List indent: 2 spaces
  "MD013": {
    "line_length": 120,                   // Max line length
    "code_blocks": false,                 // Don't enforce in code blocks
    "tables": false                       // Don't enforce in tables
  },
  "MD024": { "siblings_only": true },     // Allow duplicate headings in different sections
  "MD033": {
    "allowed_elements": [                 // Allow specific HTML elements
      "details", "summary", "br", "img"
    ]
  },
  "MD041": true,                          // First line must be a top-level heading
  "MD046": { "style": "fenced" },        // Code blocks must use fences (not indentation)
  "MD048": { "style": "backtick" }       // Fence style: backticks (not tildes)
}
```

---

## 4. Renovate Configuration

### Shared Preset (`renovate-go.json`)

This is the centralized configuration that all Go services extend:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": [
    "config:base",                        // Base recommended config
    "security:openssf-scorecard",         // OpenSSF supply chain security
    ":dependencyDashboard",               // Dashboard issue in repo
    ":semanticCommits",                   // Conventional commit prefixes
    ":automergeMinor",                    // Auto-merge minor updates
    ":automergePatch",                    // Auto-merge patch updates
    "go:pinDigests"                       // Pin Go module digests for reproducibility
  ]
}
```

### Key Package Rules

| Rule | Scope | Auto-Merge | Schedule | Priority |
|------|-------|-----------|----------|----------|
| Security updates | All categories | Yes | **Any time** | 10 (highest) |
| Go minor/patch | `gomod` manager | Yes | Monday before 6 AM | default |
| Go major | `gomod` manager | No (needs review) | default schedule | default |
| Go version | `gomod` golang dep | No (needs review) | default schedule | default |
| Docker minor/patch | `dockerfile` manager | Yes | Monday before 6 AM | default |
| Docker major | `dockerfile` manager | No (needs review) | default schedule | default |
| GH Actions patches | `github-actions` | Yes | default schedule | default |
| GH Actions minor/major | `github-actions` | No (needs review) | default schedule | default |
| Critical security deps | Named packages | No (needs review) | default schedule | default |

### Critical Security Packages (Always Require Review)

```json
"matchPackageNames": [
  "golang.org/x/crypto",
  "google.golang.org/grpc",
  "github.com/golang-jwt/jwt"
]
```

### Global Settings

| Setting | Value | Description |
|---------|-------|-------------|
| `prHourlyLimit` | 4 | Max PRs created per hour |
| `prConcurrentLimit` | 10 | Max open PRs at any time |
| `stabilityDays` | 3 | Wait 3 days after release before creating PR |
| `schedule` | `before 6am on monday` | Default schedule for non-security updates |
| `timezone` | `America/New_York` | Schedule timezone |

### Consumer Configuration Format

Each service repository contains a minimal `renovate.json` that extends the shared preset:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": [
    "local>{{ORG_NAME}}/{{APP_NAME}}-workflows:templates/renovate-go"
  ],
  "description": "Renovate configuration for {{SERVICE_NAME}}"
}
```

---

## 5. Dependabot Configuration (`.github/dependabot.yml`)

### Ecosystem Configuration

```yaml
version: 2

registries:
  npm-github:
    type: npm-registry
    url: https://npm.pkg.github.com
    token: ${{ secrets.NPM_TOKEN }}       # GitHub Packages auth

updates:
  # GitHub Actions -- primary Dependabot responsibility
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
    commit-message:
      prefix: "ci({{SERVICE_NAME}})"      # Conventional commit prefix
    labels: ["dependencies", "github-actions"]
    groups:
      github-actions:
        patterns: ["*"]                    # Group all actions into one PR

  # npm dependencies
  - package-ecosystem: "npm"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
    commit-message:
      prefix: "deps({{SERVICE_NAME}})"
    registries: [npm-github]
    groups:
      minor-and-patch:
        update-types: ["minor", "patch"]
      {{APP_NAME}}-packages:
        patterns: ["@{{ORG_NAME}}/*"]     # Group org packages
      testing:
        patterns: ["jest", "@types/jest", "ts-jest"]
      typescript:
        patterns: ["typescript", "@types/*", "ts-node*"]
    ignore:
      - dependency-name: "*"
        update-types: ["version-update:semver-major"]  # Never auto-update majors
    open-pull-requests-limit: 10

  # Docker base images
  - package-ecosystem: "docker"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
    commit-message:
      prefix: "docker({{SERVICE_NAME}})"
    labels: ["dependencies", "docker"]
```

### Dependency Grouping Strategy

| Group | Packages | Purpose |
|-------|----------|---------|
| `github-actions` | All (`*`) | Single PR for all action updates |
| `minor-and-patch` | All npm minor/patch | Reduce PR count |
| `{{APP_NAME}}-packages` | `@{{ORG_NAME}}/*` | Internal packages together |
| `testing` | jest, @types/jest, ts-jest | Test framework compatibility |
| `typescript` | typescript, @types/*, ts-node* | TypeScript toolchain compatibility |

---

## 6. Backstage `catalog-info.yaml` Format

### Component (Service)

```yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: {{SERVICE_NAME}}                    # Unique identifier (kebab-case)
  title: {{SERVICE_TITLE}}                  # Human-readable display name
  description: |
    Service description here.
  labels:
    {{APP_NAME}}.io/runtime: go             # or: nodejs, python, etc.
    {{APP_NAME}}.io/tier: core              # or: gateway, financial, notifications
  annotations:
    backstage.io/techdocs-ref: dir:.
    github.com/project-slug: {{ORG_NAME}}/{{SERVICE_NAME}}
    argocd/app-selector: app.kubernetes.io/name={{SERVICE_NAME}}
    prometheus.io/rule: {{SERVICE_NAME}}
    kubernetes.io/namespace: {{APP_NAME}}-{{SYSTEM}}
  tags:
    - go                                    # Runtime tag
    - api                                   # Functional tags
  links:
    - url: https://argocd.{{DOMAIN}}/applications/{{SYSTEM}}-{{SERVICE_NAME}}-production
      title: ArgoCD (Production)
      icon: dashboard
    - url: https://github.com/{{ORG_NAME}}/{{SERVICE_NAME}}
      title: GitHub Repository
      icon: github
spec:
  type: service                             # service | library | website | documentation
  lifecycle: production                     # production | experimental | deprecated
  owner: {{TEAM_NAME}}                      # Team that owns this component
  system: {{APP_NAME}}-{{SYSTEM}}           # Parent system
  dependsOn:                                # Resource dependencies
    - resource:default/postgres
    - resource:default/redis
  providesApis:                             # APIs this component exposes
    - {{SERVICE_NAME}}-api
  consumesApis:                             # APIs this component calls
    - other-service-api
```

### Domain

```yaml
apiVersion: backstage.io/v1alpha1
kind: Domain
metadata:
  name: {{APP_NAME}}
  title: {{APP_TITLE}}
  description: |
    Top-level business domain description.
spec:
  owner: {{TEAM_NAME}}
```

### System

```yaml
apiVersion: backstage.io/v1alpha1
kind: System
metadata:
  name: {{APP_NAME}}-{{SYSTEM}}
  title: {{SYSTEM_TITLE}}
  description: |
    System description.
  labels:
    {{APP_NAME}}.io/namespace: {{APP_NAME}}-{{SYSTEM}}
spec:
  owner: {{TEAM_NAME}}
  domain: {{APP_NAME}}
```

### Resource

```yaml
apiVersion: backstage.io/v1alpha1
kind: Resource
metadata:
  name: postgres                            # or: redis, pubsub, etc.
  title: PostgreSQL Database
  description: |
    Resource description.
spec:
  type: database                            # database | cache | storage | queue
  owner: {{TEAM_NAME}}
  system: {{APP_NAME}}-core
  dependencyOf:
    - component:default/auth-service
    - component:default/booking-service
```

### API

```yaml
apiVersion: backstage.io/v1alpha1
kind: API
metadata:
  name: {{SERVICE_NAME}}-api
  title: {{SERVICE_TITLE}} API
  description: API description
spec:
  type: openapi                             # openapi | grpc | graphql | asyncapi
  lifecycle: production
  owner: {{TEAM_NAME}}
  system: {{APP_NAME}}-{{SYSTEM}}
  definition: |
    openapi: 3.0.0
    info:
      title: {{SERVICE_TITLE}} API
      version: 1.0.0
    paths:
      /api/v1/resource:
        get:
          summary: Get resource
```

---

## 7. Backstage `app-config.yaml` Key Sections

### Database Configuration

```yaml
backend:
  database:
    client: pg                              # PostgreSQL client
    connection:
      host: ${POSTGRES_HOST}
      port: ${POSTGRES_PORT}
      user: ${POSTGRES_USER}
      password: ${POSTGRES_PASSWORD}
      database: backstage
      ssl:
        require: true                       # true in production, false in staging
        rejectUnauthorized: false
```

### GitHub Integration

```yaml
integrations:
  github:
    - host: github.com
      token: ${GITHUB_TOKEN}                # Fine-grained PAT with repo read access

auth:
  providers:
    github:
      production:
        clientId: ${GITHUB_OAUTH_CLIENT_ID}
        clientSecret: ${GITHUB_OAUTH_CLIENT_SECRET}
```

### Plugin Configuration

```yaml
# Kubernetes -- pod visibility
kubernetes:
  serviceLocatorMethod:
    type: multiTenant
  clusterLocatorMethods:
    - type: config
      clusters:
        - url: ${K8S_CLUSTER_URL}
          name: {{APP_NAME}}-cluster
          authProvider: serviceAccount
          serviceAccountToken: ${K8S_SERVICE_ACCOUNT_TOKEN}

# ArgoCD -- deployment status
argocd:
  baseUrl: ${ARGOCD_URL}
  appLocatorMethods:
    - type: config
      instances:
        - name: main
          url: ${ARGOCD_URL}
          token: ${ARGOCD_AUTH_TOKEN}

# Prometheus -- metrics
proxy:
  '/prometheus/api':
    target: ${PROMETHEUS_URL}
    changeOrigin: true

# TechDocs -- documentation
techdocs:
  builder: 'local'
  generator:
    runIn: 'local'
  publisher:
    type: 'local'

# Search -- PostgreSQL full-text search
search:
  pg:
    highlightOptions:
      useHighlight: true
```

### Catalog Discovery

```yaml
catalog:
  import:
    entityFilename: catalog-info.yaml
    pullRequestBranchName: backstage-integration
  rules:
    - allow: [Component, System, Domain, Resource, API, Group, User, Template, Location]
  locations:
    # Local catalog files (domains, systems, resources)
    - type: file
      target: ../../catalog/all.yaml

    # GitHub organization auto-discovery
    - type: github-discovery
      target: https://github.com/{{ORG_NAME}}

    # Explicit service registrations
    - type: url
      target: https://github.com/{{ORG_NAME}}/{{SERVICE_NAME}}/blob/main/catalog-info.yaml
```

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Pre-Commit Configuration (.pre-commit-config.yaml)
- golangci-lint Configuration (.golangci.yml)
- Markdown Linter Configuration (.markdownlint.json)
- Renovate Configuration

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
