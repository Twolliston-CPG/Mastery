# Figure 18.1 — The pipeline that refuses

> Week 18 · badges ① to ⑫ · about four minutes at a normal pace. Point at each badge as you say its line. Blue is the path to follow first; orange-red is where something refuses or fails.

![Figure 18.1 — The pipeline that refuses](figure-18.1-the-pipeline-that-refuses.png)

Supply chain security is what makes you beat other juniors. The blue path is the pipeline; the orange boxes are where it says no, with evidence. Every gate hard-fails, cheapest first.

## What to say, badge by badge

- **Open.** “Almost no candidate at this level can talk credibly about supply chain security, and hiring managers have been told to care since Log4Shell. This is a pipeline that refuses, and the two refusals come with screenshots. Follow the line; stop at every orange box.”
- **① commit.** “A pull request opens. Everything to the right runs before a human looks at it, and the cheapest checks run first so a leaked key fails in seconds, not after a ten-minute build.”
- **② gitleaks.** “Secrets, scanned across the full history, because a key deleted in the next commit is still in the repository. The same binary, the same version, runs in the pre-commit hook and in CI.”
- **③ Semgrep.** “Static analysis on the source. You write one rule yourself, no hardcoded database URL, so you understand that a scanner is a pattern someone chose, not an oracle.”
- **④ Trivy on the filesystem.** “Dependency scanning against the lockfiles. The gate fails on fixable HIGH and CRITICAL. Fixable is the key word: an unfixable finding goes to an exception with an expiry and an owner, which is the week-19 control narrative.”
- **⑤ build.** “Distroless base, non-root user, read-only filesystem. Measure the image size and CVE count before and after and write both numbers down. No shell in the image means no `kubectl exec sh`, for you and for an attacker.”
- **⑥ Trivy on the image.** “Scan what ships, not what you compiled from. Base image CVEs live here, and they are most of the count.”
- **⑦ syft SBOM.** “A software bill of materials in SPDX, attached to the image as an attestation. When the next Log4Shell lands, this is how you answer 'are we affected' in minutes instead of days.”
- **⑧ cosign sign.** “Keyless: the workflow's OIDC identity gets a short-lived certificate from Fulcio, the signature is recorded in the Rekor transparency log, and what is signed is the digest. A tag can be moved; a digest cannot.”
- **⑨ registry.** “The image, its signature, and its SBOM, all addressed by digest. Pulling by tag is convenience; verifying by digest is the control.”
- **⑩ admission verify.** “Kyverno's verifyImages checks the signature at admission against the expected identity. An unsigned image, or one signed by the wrong workflow, is refused before it runs. Push one on purpose and capture the refusal.”
- **⑪ evidence.** “Two screenshots in the repository: a deliberately introduced critical CVE blocking the build, and an unsigned image refused at admission. Evidence is what separates a control from a claim, and Gate 5 asks for it live.”
- **⑫ SLSA.** “The provenance levels give you vocabulary: who built it, from what, on what builder, with what guarantees. Thursday's case studies ask one question of each real attack: which of these boxes would have caught it.”
- **Close.** “Scan the source, harden the build, scan the image, describe it, sign the digest, verify at the door. Then prove it twice with a screenshot. That is the month that beats other juniors.”

## Use it

- Read the figure before the day plan. Say the script out loud on Friday with the file closed.
- Each badge line is a thirty-second interview answer; the whole script is the three-minute version.
- Regenerate after editing the spec in `_shared/diagrams/week_figures/`:

```bash
python3 ../../_shared/diagrams/generate-week-figures.py --only 18
```
