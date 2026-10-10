# Domain 8: Developer Experience -- Best Practices

## Strengths

### 1. Comprehensive Shift-Left Security

The pre-commit hook suite covers every major attack surface before code reaches CI:

- **Secret detection** (gitleaks + detect-private-key): Two layers prevent secrets from being committed.
  Gitleaks uses pattern-based detection on staged changes while detect-private-key catches key files.
- **IaC security** (Checkov): Infrastructure misconfigurations are caught during development,
  not after deployment.
- **Go security** (gosec + golangci-lint with gosec linter): Both static analysis tools run
  locally, so security findings surface in seconds instead of minutes in CI.
- **Docker security** (hadolint): Dockerfile best practices are enforced before images are built.

### 2. Tiered Dependency Management Strategy

The combination of Renovate and Dependabot provides defense-in-depth for dependency management:

- **Security updates auto-merge at any time**: Vulnerability fixes are never delayed by schedules.
  This minimizes the window of exposure to known CVEs.
- **Minor/patch updates group and auto-merge on Monday mornings**: Reduces PR noise while ensuring
  weekly freshness. The 3-day stability window prevents adopting broken releases.
- **Major updates require manual review**: Breaking changes are never auto-merged, preserving
  service stability.
- **OpenSSF Scorecard integration**: Renovate evaluates the security posture of upstream dependencies.

### 3. Backstage as Single Pane of Glass

The Backstage portal integrates six distinct data sources into a unified view:

- Developers can see their service's Kubernetes pods, ArgoCD sync status, Prometheus metrics,
  CI pipeline results, and documentation without leaving a single interface.
- The catalog hierarchy (Domain > System > Component) provides organizational clarity
  at scale.
- TechDocs generates documentation from existing Markdown files, encouraging documentation
  as code without requiring a separate documentation platform.

### 4. Ephemeral PR Preview Environments

PR previews enable real testing before merge:

- Each PR gets an isolated namespace, preventing cross-PR interference.
- Integration tests and DAST scans run against the actual deployed service.
- Automatic cleanup on PR merge/close prevents resource waste.
- PR comments provide direct access instructions, reducing friction.

### 5. Automated Hook Maintenance via pre-commit.ci

Weekly autoupdate of hook versions and autofix PRs eliminate a common source of maintenance
drift. Developers do not need to manually track when hook tools release new versions.

### 6. Conventional Commits Enforcement

The commitizen hook enforces conventional commit format (`feat:`, `fix:`, `chore:`, etc.),
enabling automated changelog generation, semantic versioning, and consistent git history.

---

## Limitations

### 1. Pre-Commit Hook Execution Time

Running 20 hooks sequentially on every commit can be slow. In particular:

- `golangci-lint` with 30+ linters and a 5-minute timeout can take 30-60 seconds on large codebases.
- `terraform_checkov` downloads policy databases on first run.
- `check-kubernetes-json-schema` validates against remote schemas.

**Impact**: Developers may bypass hooks with `--no-verify` if commit time exceeds 60 seconds.

### 2. Cloud Provider Lock-In in PR Previews

The PR preview workflow is tightly coupled to GCP:

- Image registry: `us-east1-docker.pkg.dev` (GCP Artifact Registry)
- Authentication: `google-github-actions/auth@v2` and `google-github-actions/setup-gcloud@v2`
- Cluster management: Calls `reusable-staging-cluster.yml` for GKE-specific cluster operations
- Secrets: `GCP_STAGING_SA_KEY`, `GCP_STAGING_PROJECT_ID`

**Impact**: Migrating to AWS or Azure requires rewriting the entire preview workflow.

### 3. Renovate and Dependabot Overlap

Both tools manage overlapping ecosystems (GitHub Actions, Docker), which can produce duplicate
PRs for the same dependency update.

**Impact**: Reviewers may see conflicting PRs; one must be closed manually.

### 4. Backstage Operational Overhead

Backstage requires:

- A PostgreSQL database for the catalog and search
- A Redis cache for performance
- GitHub OAuth app for authentication
- Ongoing plugin version maintenance
- A dedicated Node.js deployment

**Impact**: For small teams (fewer than 10 developers), the operational cost may outweigh the
discoverability benefits.

### 5. Preview Environment Resource Consumption

Each PR creates a new Kubernetes namespace with a deployment. In organizations with many
concurrent PRs:

- Staging cluster resources can be exhausted.
- The `ensure-staging` job starts the cluster if stopped, but does not scale it.
- No TTL-based automatic cleanup for stale previews (only merge/close triggers cleanup).

**Impact**: Abandoned PRs leave orphaned namespaces until manually cleaned.

### 6. golangci-lint Configuration Aggressiveness

The configuration enables experimental linters (`gocritic` experimental tag) and strict
checks (`govet` with `check-shadowing` and `enable-all`). This can produce false positives,
especially:

- `wrapcheck` flags every unwrapped error, even in simple CLI tools.
- `exportloopref` is deprecated in Go 1.22+ (loop variable semantics changed).
- `cyclop` with `max-complexity: 15` is restrictive for complex business logic.

**Impact**: Developers may disable linters they perceive as noisy rather than addressing findings.

### 7. No Local Preview Equivalent

PR previews are cloud-only. There is no `docker-compose` or local Kubernetes equivalent
for testing the full service graph locally.

**Impact**: Developers must push to a PR to test integration behavior.

---

## Recommendations

### Short-Term Improvements

1. **Parallelize pre-commit hooks**: Configure independent hook groups to run concurrently
   using `stages` and selective file matching. Consider splitting into a "fast" group
   (formatting, validation) and a "thorough" group (security, linting).

2. **Add TTL-based preview cleanup**: Implement a cron job that deletes preview namespaces
   older than 72 hours, preventing resource leaks from abandoned PRs:

   ```yaml
   # Example CronJob for namespace cleanup
   schedule: "0 6 * * *"  # Daily at 6 AM
   command: |
     kubectl get ns -l {{APP_NAME}}.io/preview=true \
       --no-headers -o custom-columns=":metadata.name,:metadata.creationTimestamp" |
     awk -v cutoff=$(date -d '72 hours ago' -Iseconds) '$2 < cutoff {print $1}' |
     xargs -r kubectl delete ns
   ```

3. **Resolve Renovate/Dependabot overlap**: Disable overlapping ecosystems in one tool.
   Recommended split:
   - **Renovate**: Go modules, Docker images, Terraform providers, Helm charts
   - **Dependabot**: GitHub Actions workflows, npm packages

4. **Remove deprecated golangci-lint linters**: Remove `exportloopref` (fixed in Go 1.22),
   adjust `wrapcheck` exclusions for simpler packages, and tune `cyclop` thresholds.

5. **Add pre-commit hook timing**: Use `pre-commit run --all-files --verbose` in CI to
   track hook execution times and identify slow hooks for optimization.

### Medium-Term Improvements

6. **Abstract cloud provider from PR previews**: Create a provider abstraction layer using
   environment variables for registry URL, auth method, and cluster configuration. This
   enables multi-cloud support without rewriting the workflow:

   ```yaml
   env:
     REGISTRY: ${{ vars.CONTAINER_REGISTRY }}       # Instead of hardcoded GCP registry
     AUTH_ACTION: ${{ vars.CLOUD_AUTH_ACTION }}       # Instead of google-github-actions/auth
   ```

7. **Add Backstage software templates**: Use Backstage's scaffolder plugin to generate
   new service repositories with pre-configured `catalog-info.yaml`, `renovate.json`,
   `.pre-commit-config.yaml`, Dockerfile, and CI/CD workflows.

8. **Implement developer satisfaction metrics**: Track:
   - Pre-commit hook pass rate and average execution time
   - Time from PR open to preview deployment ready
   - Dependency update merge latency (time from Renovate PR to merge)
   - Backstage portal daily active users

9. **Add local development environment**: Create a `docker-compose.yml` or Tilt
   configuration that mirrors the PR preview environment locally, reducing the
   dependency on cloud resources for integration testing.

### Long-Term Improvements

10. **Implement golden path templates in Backstage**: Define opinionated service templates
    (Go microservice, Node.js API, React frontend) that come pre-configured with all
    DevEx tooling. New services inherit best practices by default.

11. **Add developer portal analytics**: Track which Backstage features are used most,
    which services have stale documentation, and which teams are most active in the
    portal. Use this data to prioritize portal improvements.

12. **Consider Backstage-managed pre-commit configs**: Instead of copying `.pre-commit-config.yaml`
    to each repo, manage it centrally through Backstage and distribute via a shared
    preset repository.

---

## Security Considerations

| Area | Risk | Mitigation |
|------|------|-----------|
| Pre-commit bypass | Developers use `--no-verify` | CI pipeline runs the same checks; hooks are not the sole gate |
| Renovate auto-merge | Compromised dependency auto-merges | 3-day stability window; OpenSSF Scorecard; security-critical packages require review |
| PR preview access | Preview namespace accessible within cluster | Namespace isolation; RBAC; no external ingress by default |
| Backstage GitHub token | Token has broad repo access | Use fine-grained PAT with minimal scopes; rotate regularly |
| Dependabot NPM_TOKEN | Private registry token in workflow | Stored as encrypted GitHub secret; scoped to org packages only |
| pre-commit.ci access | Third-party service has repo access | Only reads `.pre-commit-config.yaml`; no write access to source code |

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Security Considerations
- Comprehensive Shift-Left Security
- Tiered Dependency Management Strategy
- Backstage as Single Pane of Glass

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
