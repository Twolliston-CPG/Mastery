# Control Narrative

> **This is the key artifact of the project.** It is how security work is communicated in a regulated
> environment, and a junior who produces one unprompted is speaking the language of the job.
>
> Three columns do the work: **Threat** proves you started from risk rather than from a tool list.
> **Control** is the mechanism. **Evidence** is the thing almost nobody has, and the thing an auditor
> — or an interviewer — actually wants.

## Scope

The delivery path for containerized services: source → CI → registry → cluster → runtime.

Threat model: [`threat-model.md`](threat-model.md) (STRIDE, per component).

## Controls

| # | Threat (STRIDE) | Control | Where it runs | Evidence |
|---|---|---|---|---|
| C1 | **Spoofing** — a forged or substituted image in the registry | cosign keyless signing; Kyverno `verifyImages` with `mutateDigest` | CI + admission | `evidence/unsigned-image-rejected.png` |
| C2 | **Tampering** — a malicious or vulnerable transitive dependency | Trivy fs scan, hard-fails on fixable HIGH/CRITICAL | CI, pre-build | `evidence/cve-blocked-build.png` |
| C3 | **Tampering** — vulnerable OS packages in the base image | Trivy image scan; distroless base | CI, post-build | `evidence/image-hardening.md` |
| C4 | **Information disclosure** — a credential committed to Git | gitleaks, full history, in pre-commit and CI | local + CI | `evidence/gitleaks-blocked-commit.png` |
| C5 | **Information disclosure** — secrets readable in etcd | External Secrets; AWS Secrets Manager is the source of truth; mounted as files | runtime | `evidence/eso-sync.png` |
| C6 | **Elevation of privilege** — container escape via a privileged pod | Pod Security Standard `restricted`; Kyverno defaults | admission | `evidence/privileged-pod-rejected.png` |
| C7 | **Elevation of privilege** — a pod assuming the node's IAM role | IRSA per workload; IMDS hop limit 1 | cluster config | `evidence/irsa-scoped.txt` |
| C8 | **Lateral movement** between namespaces or to the database | NetworkPolicy default-deny plus explicit allowances | runtime (Calico) | `evidence/netpol-blocked.txt` |
| C9 | **Denial of service** — one workload starving a node | ResourceQuota, LimitRange, Kyverno requires limits | admission | `evidence/quota-enforced.png` |
| C10 | **Repudiation** — no record of who deployed what | ArgoCD pull-based delivery; Git is the audit trail | delivery | `evidence/argocd-history.png` |
| C11 | **Tampering** — undetected drift from desired state | ArgoCD `selfHeal: true` | runtime | `evidence/argocd-selfheal.png` |
| C12 | **Unknown** — "are we affected by this new CVE?" | SBOM generated with syft, attested with cosign | CI | `evidence/sbom-query.txt` |
| C13 | **Runtime compromise** — unexpected behavior in a running container | Falco, tuned | runtime | `evidence/falco-shell-alert.json` |
| C14 | **Tampering** — insecure infrastructure provisioned | Conftest/OPA gate on the Terraform plan; checkov | CI, pre-apply | `evidence/conftest-blocked-plan.png` |
| C15 | **Spoofing** — leaked long-lived cloud credentials | GitHub OIDC federation; no static keys exist | CI | `git grep AKIA` returns nothing |

## Accepted risks

| Risk | Why accepted | Compensating control | Expiry | Owner |
|---|---|---|---|---|
| *(example — replace)* CVE-2024-XXXXX in a transitive dependency, no fix published | Not reachable: the vulnerable code path is behind a disabled feature flag | NetworkPolicy denies the egress an exploit would require | 2026-09-01 | platform-team |

**Every accepted risk has an expiry and an owner.** An exception without both is a permanent
unmanaged risk wearing a justification. The file format is the one from Week 18:
[`.trivyignore.yaml`](../../../week-18/solutions/pipeline/.trivyignore.yaml).

## What this does NOT cover

Stating the gaps is part of the artifact — a control narrative claiming complete coverage is not
credible.

- **Build-system compromise.** An attacker with CI access gets a valid signature. Addressing this
  requires SLSA L3: a hardened, isolated builder with non-forgeable provenance.
- **Malicious insider with merge rights.** Mitigated partly by required review, not eliminated.
- **DAST / runtime application testing.** Out of scope; only static analysis is in the pipeline.
- **Data-layer controls.** Encryption at rest is in place; field-level encryption and data
  classification are not.
