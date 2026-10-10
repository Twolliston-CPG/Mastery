# CI/CD Pipelines — Best Practices & Gaps

## What the Implementation Does Well

### 1. Two-Tier Workflow Architecture
The standalone-vs-composite pattern is excellent. Standalone workflows enable per-service customization (e.g., `needs-postgres: true/false`), while composite workflows eliminate boilerplate for standard scenarios. This avoids the common trap of either too-rigid shared pipelines or completely duplicated per-service configs.

### 2. SLSA Level 3 Supply Chain Security
The hermetic build process (`--network none`, `GOPROXY=off`) with keyless Cosign signing is a gold standard approach. By using GitHub Actions OIDC identity rather than stored keys, the system eliminates key management entirely while maintaining a verifiable trust chain through the Rekor transparency log.

### 3. Dual SBOM Format
Generating both SPDX and CycloneDX SBOMs covers the broadest compliance surface. Government contracts often require SPDX; commercial tools often prefer CycloneDX. Producing both costs near-zero in build time.

### 4. GitOps-Native Deployment
ArgoCD Image Updater polling for semver tags creates a clean separation between CI (push image) and CD (deploy image). The CI pipeline never needs cluster credentials — it just pushes a tagged image. This is both more secure and more auditable than direct `kubectl apply` from CI.

### 5. Conservative Canary Strategy
The 10% → 30 min → 100% canary pattern with automatic rollback provides a strong safety net for production deployments without requiring a full-blown progressive delivery tool like Flagger.

### 6. Aggressive Caching
The multi-layer caching strategy (npm/Go modules, Docker BuildKit, GitHub Actions Cache) achieving ~60% build time reduction is well-implemented and properly documented.

## Known Limitations

### 1. Falco Kernel Incompatibility
Falco is currently disabled on GCP kernel 6.14.0 due to BTF/eBPF incompatibility. The compensating controls (Trivy Operator + Kyverno + NetworkPolicies) provide partial coverage but miss Falco's syscall-level runtime detection. This is a platform issue that affects the security posture of the deployment target, not the CI/CD pipeline itself, but deploy workflows should be aware.

**Mitigation**: Monitor Falco releases for GCP kernel support. Consider switching to Falco's userspace driver as an interim solution.

### 2. No Matrix Strategy for Multi-Version Testing
The Go and Node.js pipelines test against a single version (Go 1.22, Node.js 18). There is no matrix strategy to test against upcoming versions (Go 1.23, Node.js 20) to catch forward-compatibility issues.

**Recommendation**: Add an optional matrix input to CI workflows:
```yaml
strategy:
  matrix:
    go-version: ['1.22', '1.23']
  fail-fast: false
```

### 3. GitHub Actions Cache Limits
The 10GB cache limit with 7-day retention can cause cache eviction in active repos. When the cache is cold, build times revert to 8-12 minutes.

**Mitigation**: Consider self-hosted runners with persistent local caches for critical services, or use GitHub's larger runners with expanded cache limits.

### 4. No Build Provenance for Node.js
The SLSA Level 3 hermetic build (`reusable-go-slsa-build.yml`) is only implemented for Go services. Node.js services use standard Docker builds without hermetic guarantees or provenance attestation.

**Recommendation**: Implement `reusable-node-slsa-build.yml` following the same 2-phase pattern: `npm ci` with network → `npm run build` without network (using `--prefer-offline`).

### 5. Workflow Versioning Inconsistency
Go workflows use `@main` (rolling) while Node.js workflows use `@v1` (pinned). This creates an inconsistent update experience: Go services automatically get workflow changes (risk of breakage), Node.js services require explicit version bumps (risk of staleness).

**Recommendation**: Standardize on semver tags (`@v1`) for all workflows. Use Renovate or Dependabot to automate version bump PRs.

### 6. No Workflow Testing
The reusable workflows themselves have no automated tests. A change to `reusable-go-ci.yml` could break all Go services simultaneously.

**Recommendation**: Add a `test-workflows.yml` that runs a minimal integration test against a sample service for each reusable workflow on every PR to the workflows repo.

### 7. SonarQube Only for Node.js
SonarQube quality gates are configured for Node.js but not Go. While CodeQL + Gosec cover security concerns, they don't provide SonarQube's code smell, duplication, and maintainability analysis.

**Recommendation**: Either add SonarQube for Go services or document the explicit decision to omit it (with rationale that golangci-lint covers code quality for Go).

## Recommendations for Improvement

1. **Add smoke test workflow**: Create a `reusable-smoke-test.yml` that can be reused across staging and production deployments, rather than embedding smoke test logic in deploy workflows
2. **Implement deployment notifications**: Add Slack/Teams notifications for deployment status (success, failure, rollback) to the deploy workflows
3. **Add workflow changelog**: Maintain a `CHANGELOG.md` in the workflows repo documenting breaking changes, so consumers know what changed in each version
4. **Consider Dagger or Earthly**: For the hermetic build requirement, tools like Dagger could provide a more ergonomic developer experience than raw Docker `--network none`
5. **Add deployment metrics**: Emit deployment frequency, lead time, and MTTR metrics from the deploy workflows to Prometheus for DORA metrics tracking

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- What the Implementation Does Well
- Known Limitations
- Recommendations for Improvement
- Two-Tier Workflow Architecture

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
