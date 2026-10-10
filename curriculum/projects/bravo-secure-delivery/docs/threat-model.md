# Threat Model — STRIDE

> Written in **week 17, before any code.** The threat model is what tells you which controls to
> build; without it you build the tools you've heard of rather than the controls the system needs.

## System decomposition

| # | Component | Trust boundary |
|---|---|---|
| 1 | Developer workstation | Untrusted-ish — the developer is trusted, the machine is not |
| 2 | Git repository (GitHub) | Trusted, with required review |
| 3 | CI runner (GitHub-hosted) | **Semi-trusted** — ephemeral, but runs third-party actions |
| 4 | Container registry (ECR) | Trusted, IAM-controlled |
| 5 | Kubernetes cluster (EKS) | Trusted control plane, **semi-trusted workloads** |
| 6 | Application pod | Untrusted — assume it can be compromised |
| 7 | Database (RDS) | Trusted, network-isolated |
| 8 | AWS control plane | Trusted |

## STRIDE, per boundary

### Boundary: developer → Git

| | Threat | Control |
|---|---|---|
| **S** | Someone pushes as another author | Signed commits (optional); branch protection with required review |
| **T** | Malicious change merged | Required PR review; CODEOWNERS |
| **R** | No record of who changed what | Git history; protected branches prevent force-push |
| **I** | **A credential committed** | gitleaks, pre-commit **and** CI, full history |
| **D** | — | |
| **E** | Someone grants themselves merge rights | GitHub org audit log; admin actions reviewed |

### Boundary: Git → CI → registry

| | Threat | Control |
|---|---|---|
| **S** | **A forged image pushed to the registry** | cosign signing; ECR IAM restricted to the CI OIDC role |
| **T** | **A malicious dependency enters the build** | Trivy SCA; lockfiles; dependency review |
| **T** | **The build process itself is compromised** | **Not fully mitigated** — requires SLSA L3. Partial: pinned action SHAs, `provenance: true` |
| **R** | Which commit produced this image? | SBOM + provenance attestation, both signed |
| **I** | **CI secrets exfiltrated by a third-party action** | **OIDC — no static secrets exist to steal**; actions pinned by SHA |
| **D** | — | |
| **E** | `pull_request_target` with untrusted checkout | Never used. `pull_request` only. |

### Boundary: registry → cluster

| | Threat | Control |
|---|---|---|
| **S** | **An unsigned or third-party image deployed** | Kyverno `verifyImages`; registry allow-list |
| **T** | A tag repointed at different content | Signatures bind to the **digest**; `mutateDigest: true` on admission |
| **R** | Who deployed this? | ArgoCD + Git history — pull-based delivery makes Git the audit trail |
| **I** | — | |
| **D** | — | |
| **E** | — | |

### Boundary: cluster → workload

| | Threat | Control |
|---|---|---|
| **S** | A pod assumes another workload's identity | IRSA scoped per ServiceAccount; `automountServiceAccountToken: false` where unused |
| **T** | An attacker with RCE writes a payload to disk | `readOnlyRootFilesystem: true` |
| **R** | — | Kubernetes audit logging |
| **I** | **Secrets readable from etcd or a crash dump** | External Secrets; mounted as files, not env vars; encryption at rest |
| **D** | **One workload starves a node** | ResourceQuota, LimitRange, Kyverno requires limits |
| **E** | **Container escape** | PSS `restricted`; drop ALL capabilities; `no-new-privileges`; seccomp RuntimeDefault |
| **E** | **A pod assumes the NODE's IAM role via IMDS** | IRSA; IMDS hop limit 1 |

### Boundary: workload → workload / database

| | Threat | Control |
|---|---|---|
| **S** | — | |
| **T** | — | |
| **I** | **Lateral movement to another namespace or the database** | NetworkPolicy default-deny + explicit allowances |
| **D** | — | PodDisruptionBudget; HPA limits |
| **E** | Over-broad database credentials | Per-service database user; least-privilege IAM |

## The highest-risk unmitigated threat

**Build-system compromise.** If an attacker gains CI execution, they obtain a valid cosign signature
and every downstream control passes. Source review, SAST, and SCA all pass too, because the source is
clean — the malicious code is injected during the build.

Mitigating it properly requires **SLSA L3**: a hardened, isolated builder producing non-forgeable
provenance, plus reproducible builds so a divergence between two independent builds is detectable.

**Naming this openly is part of the artifact.** A threat model claiming complete coverage is not
credible, and being able to say "here is the thing my controls do not address, and here is what
would" is a much stronger position than a clean-looking table.
