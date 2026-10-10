# Week 18 Labs

---

# Lab 1 — SAST, SCA, Secret Scanning (3h)

## The three scanner categories — know what each does

| Type | Looks at | Finds | Tool here |
|---|---|---|---|
| **SAST** | Your source code | SQL injection, path traversal, hardcoded crypto, unsafe deserialization | Semgrep |
| **SCA** | Your dependencies | Known CVEs in libraries you pull in | Trivy |
| **Secret scanning** | Files and git history | Credentials committed | gitleaks |
| (DAST) | A running app | Runtime issues — out of scope this week | OWASP ZAP |

**Most real vulnerabilities come from dependencies, not your code.** A typical application is 90%+
third-party by line count. That's why SCA matters more than SAST for most teams, and why supply
chain attacks work.

## Semgrep
```bash
semgrep --config=auto app/
semgrep --config=p/security-audit --config=p/secrets --config=p/owasp-top-ten app/
semgrep --config=auto --sarif --output=semgrep.sarif app/
```

Write a custom rule — this is what separates "I ran a tool" from "I understand the tool":
```yaml
# .semgrep/no-hardcoded-db-url.yml
rules:
  - id: hardcoded-database-url
    patterns:
      - pattern-either:
          - pattern: $X = "postgresql://...:...@..."
          - pattern: $X = "mysql://...:...@..."
    message: >
      Database URL with embedded credentials. Use an environment variable
      sourced from Secrets Manager via External Secrets.
    languages: [python, javascript, go]
    severity: ERROR
```

## Trivy
```bash
trivy fs --scanners vuln,secret,misconfig .
trivy image --severity HIGH,CRITICAL myapp:latest
trivy image --ignore-unfixed myapp:latest       # only what you can actually fix
trivy config ./infra                             # Terraform/K8s misconfiguration
trivy image --format sarif --output trivy.sarif myapp:latest
```

**`--ignore-unfixed` is worth thinking about carefully.** It hides CVEs with no available patch —
which stops your build failing on things you cannot fix, and also hides real risk. The defensible
position is: fail on fixable HIGH/CRITICAL, *report* unfixable ones, and triage them explicitly
(Lab 5 / BF-51).

## gitleaks
```bash
gitleaks detect --source . --verbose
gitleaks detect --source . --log-opts="--all"    # the ENTIRE history
gitleaks protect --staged                         # pre-commit
```

**Scan the full history, not just the working tree.** A secret removed in a later commit is still in
history, still cloneable, and still valid unless it was rotated.

## Wire them into CI

```yaml
  security:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      security-events: write      # to upload SARIF
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }  # gitleaks needs full history

      - name: gitleaks
        uses: gitleaks/gitleaks-action@v2
        env: { GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }} }

      - name: semgrep
        uses: semgrep/semgrep-action@v1
        with: { config: p/security-audit p/secrets }

      - name: trivy filesystem
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: fs
          severity: HIGH,CRITICAL
          exit-code: '1'          # HARD GATE
          format: sarif
          output: trivy-fs.sarif

      - uses: github/codeql-action/upload-sarif@v3
        if: always()
        with: { sarif_file: trivy-fs.sarif }
```

**SARIF upload puts findings in the GitHub Security tab** with inline annotations on the PR diff.
It's a small thing that makes the output usable rather than a wall of CI log text — and it's the kind
of developer-experience detail a platform engineer thinks about.

## Task: prove the gate works
```bash
# Add a known-vulnerable dependency
echo "requests==2.19.1" >> app/requirements.txt    # CVE-2018-18074
git commit -am "test: introduce a known CVE" && git push
```
**Screenshot the failed build with the CVE named. Put it in `evidence/`.** This is an acceptance
criterion, not decoration.

---

# Lab 2 — Image Hardening, Measured (3h)

## Measure first

```bash
docker build -t app:v1 -f Dockerfile.v1 .
docker images app:v1 --format '{{.Size}}'
trivy image --severity HIGH,CRITICAL --format json app:v1 | \
  jq '[.Results[].Vulnerabilities // [] | length] | add'
```

Record the baseline. Then harden through the progression, measuring each step:

| Step | Change | Size | HIGH+CRIT |
|---|---|---|---|
| v1 | `FROM python:3.12` | | |
| v2 | `-slim` + `.dockerignore` + layer order | | |
| v3 | multi-stage venv | | |
| v4 | non-root, read-only, healthcheck | | |
| v5 | distroless (or `-alpine` with no shell) | | |

**These numbers go in your README and your interview answers.** "I reduced the image from 1.02 GB to
155 MB and HIGH/CRITICAL CVEs from 45 to 8" is memorable. "I optimized the Dockerfile" is not.

## The hardening checklist

```dockerfile
FROM gcr.io/distroless/python3-debian12:nonroot
# - no shell        -> no `kubectl exec sh`, and no shell for an attacker either
# - no package manager
# - no OS packages  -> near-zero CVE surface
# - runs as nonroot (UID 65532) by default
```

| Control | Why |
|---|---|
| Minimal base (distroless / alpine / scratch) | Every package is attack surface and a CVE source |
| **Numeric** `USER` | Kubernetes `runAsNonRoot` cannot verify a username (week 4) |
| `readOnlyRootFilesystem` | An attacker with RCE can't write a payload to disk |
| `cap_drop: ALL` | Containers almost never need capabilities |
| `no-new-privileges` | Blocks setuid escalation |
| Pinned base image **digest** | `FROM python:3.12-slim@sha256:...` — reproducible, and immune to a tag being repointed |
| No secrets in build args | `docker history` reveals them |

**The distroless tradeoff, worth being able to state:** no shell means you cannot `kubectl exec` into
it to debug. The answer is **ephemeral debug containers**:
```bash
kubectl debug -it POD --image=busybox --target=app
```
That's a genuinely good detail — it shows you've thought past the recommendation to its operational
consequence.

---

# Lab 3 — SBOM, Signing, Verification (3h)

## SBOM

```bash
syft myapp:latest -o spdx-json > sbom.spdx.json
syft myapp:latest -o cyclonedx-json > sbom.cdx.json
syft myapp:latest -o table | head -30

# The question an SBOM answers in seconds instead of days:
jq -r '.packages[] | select(.name | test("log4j|requests|openssl")) |
       "\(.name) \(.versionInfo)"' sbom.spdx.json

# Scan the SBOM instead of the image -- much faster, and works offline
grype sbom:./sbom.spdx.json
```

**Why it matters, concretely:** when Log4Shell dropped, organizations without SBOMs spent days or
weeks grepping repositories and manually inspecting images to answer "are we affected, and where?"
Organizations with SBOMs ran a query and had the answer in minutes. That is the entire value
proposition, and it is a much better answer than "it's a compliance requirement."

## Signing with cosign (keyless)

```bash
# Keyless: uses your OIDC identity, logs to the Rekor transparency ledger.
# No key to manage, no key to lose, no key to leak.
cosign sign --yes $IMAGE

cosign verify $IMAGE \
  --certificate-identity-regexp "https://github.com/myorg/.*" \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com

# Attach the SBOM as an attestation
cosign attest --yes --predicate sbom.spdx.json --type spdxjson $IMAGE
cosign verify-attestation $IMAGE --type spdxjson \
  --certificate-identity-regexp "https://github.com/myorg/.*" \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com

cosign tree $IMAGE     # shows the signature and attestation artifacts
```

In CI:
```yaml
      - uses: sigstore/cosign-installer@v3
      - name: sign and attest
        env: { COSIGN_EXPERIMENTAL: '1' }
        run: |
          cosign sign --yes "$IMAGE@$DIGEST"
          syft "$IMAGE@$DIGEST" -o spdx-json > sbom.json
          cosign attest --yes --predicate sbom.json --type spdxjson "$IMAGE@$DIGEST"
```

**Note `$IMAGE@$DIGEST`, not `$IMAGE:tag`.** Signatures attach to the **digest** — that's the entire
point, because a tag is mutable and a digest is not.

## Enforce it at admission

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-image-signatures
spec:
  validationFailureAction: Enforce
  webhookTimeoutSeconds: 30
  rules:
    - name: verify-signature
      match:
        any:
          - resources:
              kinds: [Pod]
              namespaces: [shop]
      verifyImages:
        - imageReferences: ["123456789012.dkr.ecr.us-east-1.amazonaws.com/*"]
          attestors:
            - entries:
                - keyless:
                    subject: "https://github.com/myorg/bravo-secure-delivery/*"
                    issuer: "https://token.actions.githubusercontent.com"
```

## Task: prove it blocks
```bash
docker pull nginx:alpine
docker tag nginx:alpine $REGISTRY/unsigned-test:latest
docker push $REGISTRY/unsigned-test:latest
kubectl -n shop run test --image=$REGISTRY/unsigned-test:latest
# Error from server: admission webhook "mutate.kyverno.svc-fail" denied the request:
#   ... failed to verify image ... no matching signatures
```
**Screenshot it. `evidence/unsigned-image-rejected.png`.**

---

# Lab 4 — SLSA and the Real Attacks (2h)

## SLSA levels — know the shape, not the detail

| Level | Requirement |
|---|---|
| L1 | Provenance exists — you can say how the artifact was built |
| L2 | Provenance is **signed** and generated by a hosted build service |
| L3 | The build runs on **hardened, isolated infrastructure**; provenance is non-forgeable |
| L4 | Two-person review; hermetic, reproducible builds |

GitHub Actions with `provenance: true` on `docker/build-push-action` gets you roughly L2 for free.
**Say "roughly L2" rather than claiming a level precisely** — overclaiming compliance is worse than
not mentioning it.

## The four cases to be able to discuss

Read `_reference/devsecops/threat-modeling/case-studies-*.md` (anonymized).

| Attack | What happened | Which control would have caught it |
|---|---|---|
| **Build-system compromise** (OrionSoft-class) | Malicious code injected into the **build process**, so the source looked clean | Reproducible builds; signed provenance from a hardened builder (SLSA L3); monitoring build-output diffs |
| **CI credential exfiltration** (Codecov-class) | A modified CI script exfiltrated environment variables from thousands of pipelines | OIDC instead of static secrets; pinning actions by digest; egress restrictions on runners |
| **Dependency takeover** (`event-stream`-class) | A maintainer handed over a popular package; the new maintainer added a malicious dependency | Dependency pinning with lockfiles; SCA; review of dependency *changes*, not just additions |
| **Widespread vulnerable library** (Log4Shell) | A critical RCE in a ubiquitous logging library | **SBOM** — instant answer to "where are we affected"; SCA to find it; fast patch pipeline |

**Being able to name one of these and say which control addresses it is a strong DevSecOps interview
answer.** It demonstrates that your controls come from a threat model rather than a vendor list.

---

# Lab 5 — Break/Fix + ⚑ Bravo Evidence (3h)

## BF-51 — the unfixable transitive CVE

**This is a judgment exercise, not a technical one, and it is the one interviewers love.**

```bash
trivy image --severity CRITICAL --format json $IMAGE | \
  jq -r '.Results[].Vulnerabilities[] | "\(.VulnerabilityID) \(.PkgName) \(.InstalledVersion) fixed:\(.FixedVersion // "NONE")"'
```

Work the triage:
1. **Is it reachable?** Does your code path ever invoke the vulnerable function?
2. **Is there any fix?** Patched version, backport, alternative library, remove the dependency
3. **Can you mitigate?** WAF rule, NetworkPolicy, dropped capability, feature disabled
4. **If none — accept explicitly**, with an expiry and an owner:

```yaml
# .trivyignore.yaml
vulnerabilities:
  - id: CVE-2024-12345
    paths: ["usr/local/lib/python3.12/site-packages/foo"]
    statement: >
      Not reachable: the vulnerable XML parser is only invoked by the SAML login
      path, which is disabled in this deployment (AUTH_MODE=oidc). Compensating
      control: NetworkPolicy denies all egress from this pod except to the
      database and the OIDC issuer.
    expires: 2026-12-31
    owner: platform-team
```

**The answer that wins:** *"I don't disable the scanner. I document a time-boxed, owned exception
with a compensating control, and the expiry forces it back onto the board."* The two wrong answers —
both common — are "turn off the check" and "block the release indefinitely."

## BF-53 — signature verification fails after a registry move

```bash
crane copy $OLD_IMAGE $NEW_IMAGE     # brings referring artifacts
# vs
docker pull $OLD_IMAGE && docker tag ... && docker push $NEW_IMAGE   # does NOT
cosign tree $NEW_IMAGE
```
Signatures are **separate OCI artifacts tagged by digest** (`sha256-<digest>.sig`). A pull/push
copies the image and leaves the signature behind. Use `cosign copy` or `crane copy`.

## ⚑ Bravo evidence checklist for this week

- [ ] `evidence/cve-blocked-build.png` — CI failing with the CVE named
- [ ] `evidence/gitleaks-blocked-commit.png` — pre-commit refusing a secret
- [ ] `evidence/unsigned-image-rejected.png` — admission denying an unsigned image
- [ ] `evidence/image-hardening.md` — the before/after size and CVE table
- [ ] `evidence/sbom-query.txt` — an SBOM query answering "do we use library X?"
