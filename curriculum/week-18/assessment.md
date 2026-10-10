# Week 18 Assessment

> Closed book, 30 min.

## Part A (20 min)
1. SAST vs SCA vs secret scanning — what does each look at and find? Give an example of each.
2. Why do most real vulnerabilities come from dependencies rather than your own code?
3. Why start a gate at HIGH/CRITICAL rather than MEDIUM?
4. What does `--ignore-unfixed` do, and what is the risk of using it naively?
5. Why does pipeline **order** matter? Give the ordering and the reason.
6. What is an SBOM and what question does it answer in seconds that otherwise takes days?
7. Does cosign sign the tag or the digest? Give two practical consequences.
8. What is keyless signing and why is it better than a long-lived key?
9. What does image signing protect against, and what does it **not** protect against?
10. Name the four SLSA levels, roughly.
11. In a build-system compromise, why do code review, SAST, and SCA all pass? What catches it?
12. Give the four-step triage for an unfixable transitive CVE.
13. What are the three rules for rolling out an admission policy?
14. What's the tradeoff of a distroless image, and how do you mitigate it?
15. Why must a Kyverno `verifyImages` policy exclude system namespaces?

## Part B — Commands (10 min)
16. Generate an SBOM in SPDX format
17. Query an SBOM for whether a library is present
18. Sign an image keylessly and attach an SBOM attestation
19. Verify a signature, checking the identity
20. Copy an image to another registry **with** its signature
21. Scan an SBOM instead of an image
22. Show what signature and attestation artifacts exist for an image

---

# Answer key

**A1.** **SAST** reads your source for vulnerable patterns — e.g. an f-string SQL query.
**SCA** reads your dependency manifest for known CVEs — e.g. `requests==2.19.1`.
**Secret scanning** reads files and git history for credentials — e.g. a committed AWS key.

**A2.** A typical application is 90%+ third-party code by line count, and essentially none of it is
reviewed by you. That asymmetry is why supply-chain attacks are effective and why SCA usually matters
more than SAST.

**A3.** A typical image has dozens of MEDIUM findings. A gate that fires constantly gets ignored or
bypassed within a week. Start at HIGH/CRITICAL-and-fixable, reach zero, then tighten. **A gate people
respect beats a strict gate people route around.**

**A4.** It suppresses CVEs with no published fix, so the build doesn't fail on things you can't
action. The risk: it **hides real, exploitable risk**. The defensible position is to *fail* on
fixable HIGH/CRITICAL and *report* unfixable ones to the Security tab, then triage them explicitly.

**A5.** Cheapest and fastest first: gitleaks (seconds) → SAST (~1 min) → SCA (~30s) → build → image
scan → SBOM → sign. **It's a developer-experience decision** — a dev should learn about a committed
secret in 20 seconds, not after a four-minute image build.

**A6.** A machine-readable inventory of everything in an artifact (SPDX or CycloneDX). It answers
**"where are we running this vulnerable library?"** — the question every organization asked during
Log4Shell. Without one that's days of manual archaeology; with one it's a query.

**A7.** **The digest.** Consequences: (1) `docker pull` + `push` to another registry copies the image
but **not** the signature — use `cosign copy`/`crane copy`. (2) Production manifests should reference
digests, not tags, so what runs is exactly what was verified.

**A8.** cosign obtains an OIDC token, Fulcio issues a short-lived certificate binding that identity
to an ephemeral signing key, the signature goes into the Rekor transparency log, and **the key is
discarded**. Better because a long-lived signing key is a long-lived secret to store, rotate, and
protect — and if it leaks, every signature it ever made is suspect. Same shift as OIDC in CI and
IRSA in EKS: *"protect this key forever"* becomes *"prove this identity for ten minutes."*

**A9.** **Protects:** registry compromise, image substitution, a tag repointed at different content,
deploying an image you didn't build. **Does not protect:** a vulnerability inside the image, a
malicious commit you then signed, or a **compromised build system** — an attacker with CI access gets
a perfectly valid signature. That last one is what SLSA L3 addresses.

**A10.** L1 provenance exists · L2 provenance is signed by a hosted build service · L3 hardened,
isolated builder with non-forgeable provenance · L4 two-person review and hermetic, reproducible
builds.

**A11.** Because all three examine the **source**, and in a build-system compromise the source is
clean — the malicious code is injected during the build. What catches it: **reproducible builds**
(two independent builds should be bit-identical), **signed provenance from a hardened builder**
(SLSA L3), and monitoring build *output* rather than only input.

**A12.** (1) **Is it reachable** in our code path? (2) **Is there any fix** — patched version,
backport, alternative library, remove the dependency? (3) **Can we mitigate** — WAF, NetworkPolicy,
dropped capability, disabled feature? (4) **Accept explicitly** with a written justification, a
compensating control, an **expiry date**, and a **named owner**.

**A13.** (1) **Audit mode first** — observe what it would have blocked. (2) **Always exclude system
namespaces** — otherwise you break the CNI and lock yourself out. (3) **Know your `failurePolicy`** —
`Fail` plus an unavailable webhook blocks every API write cluster-wide, turning a security control
into a total outage.

**A14.** No shell means no `kubectl exec -- sh` for debugging. **Mitigate with ephemeral debug
containers:** `kubectl debug -it POD --image=busybox --target=app` shares the target's namespaces, so
you get a shell next to the process without shipping one in the image.

**A15.** Because system namespaces run the CNI, DNS, and the policy engine itself. An enforcing
policy applied cluster-wide can prevent those pods being recreated — at which point the cluster
cannot schedule anything and you cannot fix it. (BF-52.)

---

**B16.** `syft myapp:latest -o spdx-json > sbom.spdx.json`
**B17.** `jq -r '.packages[] | select(.name | test("log4j")) | "\(.name) \(.versionInfo)"' sbom.spdx.json`
**B18.**
```bash
cosign sign --yes "$IMAGE@$DIGEST"
cosign attest --yes --predicate sbom.spdx.json --type spdxjson "$IMAGE@$DIGEST"
```
**B19.**
```bash
cosign verify "$IMAGE@$DIGEST" \
  --certificate-identity-regexp "https://github.com/myorg/.*" \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```
**B20.** `cosign copy $SRC $DST` (or `crane copy`) — a `docker pull`/`push` leaves the signature behind
**B21.** `grype sbom:./sbom.spdx.json`
**B22.** `cosign tree $IMAGE`

## Scoring
| | |
|---|---|
| 18–22 | Move on. |
| 14–17 | Review signing and the CVE triage. Both are high-frequency interview topics. |
| < 14 | Redo Labs 3 and 5. **This month is your differentiator** — it's worth the extra days. |

**And: is the evidence captured?** `evidence/cve-blocked-build.png` and
`evidence/unsigned-image-rejected.png` are acceptance criteria for Project Bravo, and reconstructing
them in week 21 is much harder than capturing them now.
