# Week 18 Solutions

Working pipeline: [`pipeline/ci.yml`](pipeline/ci.yml) · Policies: [`pipeline/`](pipeline/)

---

## The security pipeline, in order, and why that order

```
1. gitleaks         (seconds)   fail fast, and a leaked secret invalidates everything downstream
2. Semgrep SAST     (~1 min)    your code
3. Trivy fs         (~30s)      dependencies, BEFORE spending time on a build
4. docker build                 hardened Dockerfile
5. Trivy image      (~1 min)    the OS layer and anything the build pulled in
6. syft             (seconds)   SBOM
7. cosign sign                  sign the DIGEST
8. cosign attest                attach the SBOM as a signed attestation
9. push
```

**Order is a developer-experience decision, not a security one.** Everything cheap and
fast runs first so a developer learns about a committed secret in 20 seconds rather than after a
four-minute image build. A pipeline that takes ten minutes to tell you about a typo is a pipeline
people route around.

---

## Lab 1 — Scanners

### What each one actually catches

The three are **not** redundant:

```python
# SAST (Semgrep) catches this -- YOUR code
query = f"SELECT * FROM users WHERE id = {user_input}"    # SQL injection

# SCA (Trivy) catches this -- SOMEONE ELSE'S code
requests==2.19.1                                          # CVE-2018-18074

# Secret scanning (gitleaks) catches this
AWS_SECRET_ACCESS_KEY = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
```

**Most real vulnerabilities come from dependencies.** A typical application is 90%+ third-party by
line count, and you review approximately none of it. That asymmetry is why supply chain attacks work
and why SCA usually matters more than SAST.

### The gate policy that survives contact with a team

```yaml
severity: HIGH,CRITICAL      # not MEDIUM -- that's noise at first
exit-code: '1'               # HARD FAIL
ignore-unfixed: true         # only fail on what can actually be fixed
```

**Why not `--severity MEDIUM`:** a typical image has dozens of MEDIUMs and the team learns to ignore
the gate within a week. Start at HIGH/CRITICAL-and-fixable, get to zero, *then* tighten. A gate
people respect is worth more than a strict gate people bypass.

**Why `--ignore-unfixed` needs care:** it hides real risk. The defensible position is to **fail** on
fixable HIGH/CRITICAL and **report** unfixable ones to the Security tab, then triage them explicitly
(BF-51). Hiding them entirely is how you end up with a critical unpatched CVE nobody knows about.

### SARIF is the DX detail

```yaml
- uses: github/codeql-action/upload-sarif@v3
  if: always()
  with: { sarif_file: trivy.sarif }
```
Findings appear in the **Security tab** and as **inline annotations on the PR diff**, rather than
buried in CI log output. Developers fix what they can see next to the line of code. This is a small
thing that changes whether a security tool is used or tolerated — and noticing it is a platform
engineering instinct.

---

## Lab 2 — Hardening

### The numbers (Python app; yours will differ)

| Step | Size | HIGH+CRIT | What changed |
|---|---|---|---|
| `python:3.12` | ~1.02 GB | ~45 | Full Debian + build toolchain |
| `python:3.12-slim` + `.dockerignore` | ~210 MB | ~12 | Minimal Debian, no `.git` |
| multi-stage venv | ~155 MB | ~8 | Build tools left behind |
| + non-root, read-only | ~155 MB | ~8 | No size change, large risk change |
| distroless | ~95 MB | **~0–2** | No shell, no package manager, no OS packages |

**Most of the CVE reduction comes from removing an OS, not from patching one.** That reframing is the
point: the cheapest way to fix OS CVEs is to not ship an OS.

### Pinning by digest

```dockerfile
FROM python:3.12-slim@sha256:2e6a0f6e9fb0f9c12d1ea9e79f83f56e70e0bbae8b0c60f0e6c2d70ea4e9a1b2
```
A tag can be repointed; a digest cannot. This makes builds reproducible and immune to a base image
being swapped under you. The cost is that you must update it deliberately — which is what Dependabot
and Renovate are for.

### The distroless tradeoff

No shell means no `kubectl exec -- sh`. The answer:
```bash
kubectl debug -it POD --image=busybox:1.36 --target=app
```
An **ephemeral debug container** shares the target's process and network namespaces, so you get a
shell *next to* the process without one being in the image.

**Being able to state the tradeoff and its mitigation is better than just recommending distroless.**
It shows you've thought about the on-call engineer at 3am, not just the scanner output.

---

## Lab 3 — SBOM and signing

### Why signatures attach to digests

```
myapp:v1.2.3                         -> sha256:abc123...
myapp:sha256-abc123....sig           <- the signature, a SEPARATE OCI artifact
myapp:sha256-abc123....att           <- attestations (SBOM, provenance)
```

A tag is a mutable pointer. Signing a tag would mean the signature stays valid when the tag is
repointed at different content — which defeats the entire purpose. Signing the **digest** binds the
signature to exact bytes.

**Two practical consequences:**
1. `docker pull` + `push` to a new registry copies the image but **not** the signature (BF-53). Use
   `cosign copy` or `crane copy`.
2. Production manifests should reference **digests**, not tags:
   ```yaml
   image: registry/app@sha256:abc123...
   ```
   That is also what makes a deploy reproducible and a rollback exact.

### Keyless signing

```bash
cosign sign --yes $IMAGE@$DIGEST
```
No key exists. cosign gets an OIDC token (from GitHub Actions, or a browser flow locally), Fulcio
issues a short-lived certificate binding that identity to a signing key, the signature and
certificate are recorded in the **Rekor transparency log**, and the key is discarded.

Verification checks: is there a signature? does its certificate chain to Fulcio? does the identity
match what we expect? is it in Rekor?

**The reason keyless matters:** a long-lived signing key is a long-lived secret — it must be stored,
rotated, and protected, and if it leaks, every signature it ever made is suspect. Keyless replaces
"protect this key forever" with "prove this identity for 10 minutes." Same shift as OIDC in week 12
and IRSA in week 16 — **the pattern recurs, and noticing it is the point.**

### What signing does and does not protect against

| Protects against | Does **not** protect against |
|---|---|
| Registry compromise / image substitution | A vulnerability in the image |
| Someone deploying an image you didn't build | A malicious commit that you then signed |
| A tag repointed at different content | A compromised build system (that's SLSA L3) |

**Signing is integrity and provenance, not safety.** An attacker who compromises your CI gets a
perfectly valid signature. Saying that distinction out loud is what separates understanding from
tool-name recall.

---

## Lab 4 — SLSA and the attacks

### Why a build-system compromise defeats source review

In the OrionSoft-class attack, the **source code in version control was clean**. The malicious code
was injected into the build process, so the artifact differed from what the source described. Code
review, SAST, and SCA all pass — they all look at the source.

**The controls that address it:**
- **Reproducible builds** — two independent builds of the same source produce bit-identical output,
  so a divergence is detectable
- **Signed provenance from a hardened builder** (SLSA L3) — the attestation says which source commit
  and which builder produced this artifact, and is non-forgeable by the build itself
- Monitoring the build output, not just the input

This is the concrete answer to "why isn't code review enough?" and it's a genuinely good thing to be
able to explain.

### Log4Shell and the SBOM argument

The question every organization asked in December 2021 was not "how do we patch Log4j" — that part
was easy. It was **"where are we running it?"** Without an SBOM that is a manual archaeology
exercise across every repository and every image. With one it is:

```bash
grype sbom:./sbom.spdx.json
jq -r '.packages[] | select(.name | test("log4j")) | "\(.name) \(.versionInfo)"' sbom.spdx.json
```

**That framing — SBOM as an incident-response tool, not a compliance checkbox — is the right answer
in an interview.**

---

## BF-51 — the triage, once more

The four questions, in order:
1. **Reachable?** A CVE in a code path you never execute is a different risk from one in your request
   handler. Severity scores are context-free; exploitability in *your* context is the real question.
2. **Fixable?** Patched version, backport, different library, drop the dependency.
3. **Mitigable?** WAF rule, NetworkPolicy, dropped capability, disabled feature.
4. **Accept explicitly** — written justification, compensating control, **expiry date, named owner.**

The expiry is what stops an exception becoming permanent. The owner is what stops it becoming
nobody's problem. Both are what make this a *process* rather than a shrug — and that is what the
question is actually testing.
