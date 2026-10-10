# Domain 5: Runtime Security & Network Security -- Best Practices

## Strengths

### 1. Multi-Layer Defense-in-Depth

The architecture implements **six distinct security layers** that overlap and reinforce each other:

- **Admission control** (Gatekeeper + Kyverno + Pod Security Standards) prevents insecure workloads from being deployed.
- **Runtime monitoring** (Falco + KubeArmor) detects and blocks malicious behavior at the syscall and process level.
- **Continuous verification** (Runtime Verifier) ensures image integrity does not degrade after deployment.
- **Network security** (Cilium + Istio mTLS + ModSecurity WAF) segments traffic and filters attacks at L3-L7.
- **Data and API security** (DLP + OPA API authorization) protects sensitive data in transit and at rest.
- **Automated incident response** closes the loop between detection and remediation without human delay.

If any single layer is bypassed (e.g., Falco is disabled due to kernel incompatibility), the remaining layers continue to provide protection.

### 2. Automated Incident Response

The Incident Responder service automates the full detection-to-remediation pipeline:

- **Sub-minute response time** for critical incidents (reverse shell, container escape).
- **Graduated actions** based on severity: from logging (low) to pod quarantine/kill (critical).
- **Automatic image blocking** via Gatekeeper deny list prevents re-deployment of compromised images.
- **Forensics collection** captures evidence before pods are terminated.
- **Multi-channel notification** ensures the right team is alerted via Slack, PagerDuty, and Jira.

### 3. Supply Chain Security (SLSA L3)

The supply chain constraints form a complete verification pipeline:

- Images must use **digest references** (no mutable tags).
- Images must be **signed** via Cosign keyless signing (GitHub Actions OIDC).
- Images must have **SLSA L3 provenance** from trusted builders.
- Images must have an attached **SBOM** (SPDX or CycloneDX).
- The Runtime Verifier **continuously re-verifies** running images post-deployment.
- The image deny list provides a **kill switch** for incident response.

### 4. Comprehensive RBAC with Least Privilege

The RBAC model implements strict separation of duties:

- **Six distinct roles** with clearly scoped permissions.
- **Developers cannot exec** into production pods (staging only).
- **Platform Admin** requires approval and has a 4-hour time limit.
- **CI/CD service account** is scoped to deploy operations only.
- **Security Auditor** has read-only access to all security resources.
- **Comprehensive audit logging** covers secrets, RBAC changes, pod exec, and network policies.

### 5. Data Loss Prevention

DLP is implemented at multiple levels:

- **[GCP-SPECIFIC] Google Cloud DLP** scans data at rest (GCS, BigQuery) on a schedule.
- **Presidio** provides real-time PII detection in API responses.
- **Envoy filters** intercept responses before they reach the client.
- **Custom recognizers** detect application-specific sensitive data patterns.
- **De-identification templates** mask PII using character masking, hashing, and date shifting.

### 6. Proactive Security Governance

- **Automated security scanning** in CI/CD (Checkov, tfsec, Trivy, kubesec, Gitleaks).
- **Scheduled security reviews** (monthly vulnerability assessments, quarterly access reviews, annual penetration tests).
- **SIEM rules** for continuous monitoring of authentication attacks, payment fraud, data exfiltration, and infrastructure anomalies.
- **Threat model validation** integrated into CI/CD.

---

## Known Limitations

### 1. Falco BTF/eBPF Incompatibility on GCP Kernel 6.14.0

**Impact:** Falco's `modern_ebpf` driver fails to load on GCP nodes running kernel 6.14.0 because the kernel lacks the required BTF (BPF Type Format) data.

**Symptoms:**
- Falco DaemonSet pods enter CrashLoopBackOff.
- Error: `unable to find a BTF file for current kernel`.

**Mitigations currently in place:**
- KubeArmor provides overlapping runtime enforcement.
- Gatekeeper admission control prevents deployment of insecure workloads.
- Runtime Verifier continues image verification.

**Recommended remediation:**
- Pin GKE node pool to a kernel version with BTF support (e.g., kernel 5.15 LTS or 6.1 LTS).
- Alternatively, use the Falco `module` driver (kernel module) instead of `modern_ebpf`, though this requires kernel headers.
- Monitor the Falco project for updated eBPF probe compatibility.
- Consider [GCP-SPECIFIC] GKE Container-Optimized OS (COS) versions that include BTF data.

### 2. External Data Provider Dependencies

Several Gatekeeper constraint templates reference external data providers (cosign-verifier, attestation-provider, sbom-verifier) that require additional infrastructure:

- If the external verifier endpoints are not deployed, the constraints fall back to less strict behavior (e.g., trusting all images by default).
- The `verifierEndpoint` and `attestationStore` parameters are currently commented out in constraints.

**Recommendation:** Deploy the external data providers (Ratify, Sigstore Policy Controller) and uncomment the verifier endpoint parameters.

### 3. Incident Responder is a Prototype

The current Incident Responder implementation uses a simple webhook receiver (netcat-based). In production:

- Replace with a proper Go binary that implements the full remediation logic.
- Add retry logic, circuit breakers, and dead-letter queues.
- Implement mutual TLS for webhook communication.
- Add rate limiting to prevent alert storms from overwhelming the responder.

### 4. Runtime Verifier Requires Privileged Access

The Runtime Verifier DaemonSet requires `privileged: true` and `hostPID: true` to access the containerd socket and verify running images. This is an intentional security trade-off but should be:

- Isolated in a dedicated namespace with ResourceQuota.
- Monitored by Falco and KubeArmor for any unexpected behavior.
- Replaced with a non-privileged approach (e.g., Ratify, Kyverno image verification) when mature.

### 5. ModSecurity WAF Performance Overhead

ModSecurity with OWASP CRS at Paranoia Level 2 may introduce latency:

- Request body inspection adds 1-5ms per request depending on payload size.
- Response body inspection for DLP adds additional latency.
- The HPA mitigates throughput issues but does not reduce per-request latency.

**Recommendation:** Profile WAF latency under production load and consider tuning Paranoia Level or excluding high-traffic, low-risk endpoints.

### 6. DLP False Positives

Presidio's PII detection may generate false positives for:

- Numeric strings that resemble SSNs or credit card numbers.
- Application IDs that match PII patterns.
- Geographic names that match person names.

**Recommendation:** Tune custom recognizers, adjust score thresholds, and implement allowlists for known false-positive patterns.

---

## Recommendations

### Short-Term (1-3 Months)

1. **Resolve Falco kernel incompatibility:** Pin GKE node pools to a supported kernel version or deploy the Falco kernel module driver as a fallback.
2. **Deploy external data providers:** Set up Ratify or Sigstore Policy Controller to enable full signature and attestation verification in Gatekeeper constraints.
3. **Implement the Incident Responder properly:** Replace the prototype with a production-grade Go service with proper error handling, retries, and observability.
4. **Enable Kyverno enforcement:** Move `require-labels`, `require-resource-limits`, and `restrict-image-registries` from Audit to Enforce mode after validating no false positives in production.
5. **Set up network policy testing:** Use a tool like Illuminatio or Goldpinger to validate that Cilium network policies are correctly enforced.

### Medium-Term (3-6 Months)

6. **Integrate Kyverno image verification:** Kyverno supports native Cosign signature verification, which could replace or supplement the Gatekeeper supply chain constraints.
7. **Deploy Falco Talon:** Falco Talon provides native automated response actions without requiring a custom Incident Responder.
8. **Implement DLP feedback loop:** Create a process for security teams to review Presidio findings, confirm/dismiss false positives, and tune recognizers.
9. **Add runtime anomaly detection:** Use machine learning-based anomaly detection (e.g., Falco plugins, Tetragon) to identify previously unknown attack patterns.
10. **Expand SIEM rules:** Add rules for insider threat detection, API abuse patterns, and cloud control plane anomalies.

### Long-Term (6-12 Months)

11. **Move to eBPF-native security:** Consider Tetragon (Cilium's runtime enforcement agent) as a unified eBPF-based runtime security solution that combines Falco-like detection with KubeArmor-like enforcement.
12. **Implement zero-trust networking:** Extend Cilium and Istio policies to enforce identity-based network access for all services, including external dependencies.
13. **Adopt CNAPP:** Evaluate Cloud-Native Application Protection Platforms that unify runtime security, posture management, and vulnerability management.
14. **Automate compliance evidence collection:** Build automated evidence collection for SOC 2, PCI DSS, and other compliance frameworks from the existing security controls.
15. **Implement chaos security testing:** Use Litmus or similar tools to regularly test that security controls (Falco rules, KubeArmor policies, network policies) behave correctly under failure conditions.

---

## Security Control Mapping

| MITRE ATT&CK Tactic | Controls |
|---|---|
| Initial Access | ModSecurity WAF, Geo-blocking, Rate Limiting |
| Execution | Falco syscall monitoring, KubeArmor process blocking |
| Persistence | Runtime Verifier (image drift detection), Gatekeeper admission |
| Privilege Escalation | KubeArmor capability restrictions, PSS restricted profile |
| Defense Evasion | Runtime Verifier (re-verification), KubeArmor file blocking |
| Credential Access | Falco (service account token access), OPA API authorization |
| Discovery | Falco (K8s API connections), RBAC audit |
| Lateral Movement | Cilium network policies, Istio mTLS |
| Collection | DLP (Presidio + Cloud DLP), Falco (sensitive file reads) |
| Exfiltration | Falco (large data transfers, DNS tunneling), DLP |
| Impact | KubeArmor (crypto miner blocking), Incident Responder (quarantine) |

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Known Limitations
- Security Control Mapping
- Multi-Layer Defense-in-Depth
- Automated Incident Response

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
