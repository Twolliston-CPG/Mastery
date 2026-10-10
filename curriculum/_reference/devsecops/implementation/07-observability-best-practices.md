# Observability Best Practices

## Strengths

### Comprehensive Three-Pillar Observability
- **Metrics**: Full Prometheus stack with kube-prometheus-stack Helm chart providing out-of-the-box Kubernetes, node, and application monitoring. ServiceMonitor CRDs enable declarative scrape target management without editing Prometheus configuration directly.
- **Logging**: Fluent Bit DaemonSet with structured log collection, Kubernetes metadata enrichment, and dual output to Cloud Logging [GCP-SPECIFIC] and Elasticsearch/OpenSearch.
- **Tracing**: Cloud Trace [GCP-SPECIFIC] integration with OpenTelemetry SDK, enabling vendor-neutral instrumentation that can be redirected to Jaeger or Tempo on other platforms.

### Security-First Observability
- Dedicated security dashboards (Security Overview, Security Dashboard) tracking Falco events, authentication failures, vulnerability counts, network policy drops, and policy compliance in real time.
- Supply Chain Security dashboard provides gauges for signed image coverage, SBOM coverage, and SLSA Level 3 provenance, directly supporting SEC540 DevSecOps requirements.
- SIEM rules mapped to MITRE ATT&CK framework enable structured threat detection with clear escalation paths.

### Multi-Layer SIEM Integration
- Three complementary SIEM rule sets: Elastic SIEM Detection Engine (Kibana), OpenSearch Security Analytics, and platform-level alert rules. This layered approach provides defense-in-depth for security event correlation.
- OpenSearch rules use Painless scripting for complex aggregation-based detection (credential stuffing velocity, payment fraud, refund abuse patterns).
- Elastic SIEM rules leverage threshold and query types with MITRE ATT&CK mapping for incident classification.

### ILM Policies with Security-Aware Retention
- Application logs: 90-day retention with hot/warm/cold/delete lifecycle (1d rollover, 7d warm, 30d cold).
- Security logs: 365-day retention for compliance audit trails.
- Separate ILM policies ensure security data is preserved longer than operational data without inflating storage costs.

### Resource-Conscious Design
- All components have explicit resource requests and limits, preventing noisy-neighbor issues.
- Prometheus retention is bounded both by time (15 days) and size (10GB).
- Fluent Bit runs with 128Mi memory limit as a DaemonSet, keeping per-node overhead minimal.

### Declarative Alert Management
- PrometheusRule CRDs enable GitOps-managed alert definitions. Alert rules are version-controlled alongside infrastructure manifests.
- 22 supply-chain-specific alert rules cover the full software supply chain lifecycle from image signing through incident response.
- Inhibit rules prevent warning-level alerts from firing when critical alerts are already active for the same alertname/namespace.

## Limitations

### Alertmanager Receiver Configuration is Skeletal
- The Alertmanager configuration has receiver stubs for `critical`, `warning`, and `default` receivers but lacks actual PagerDuty, Slack, or webhook endpoint configuration. These are commented out, requiring manual setup for each deployment.
- **Impact**: Alerts are defined but will not reach responders until receivers are configured with real integration keys.

### No Long-Term Metric Storage
- Prometheus retention is 15 days / 10GB. There is no remote write configuration for long-term metric storage (e.g., Thanos, Cortex, Mimir, or VictoriaMetrics).
- **Impact**: Historical trend analysis beyond 15 days is impossible. Capacity planning and month-over-month comparisons require additional tooling.

### Single Prometheus Instance
- No high-availability configuration for Prometheus (no sharding, no federation, no Thanos sidecar). A single Prometheus instance is a single point of failure for the entire metrics pipeline.
- **Impact**: During Prometheus pod restarts or node failures, metric collection and alerting stop.

### GCP-Specific Logging Output
- Fluent Bit's primary output plugin is `stackdriver` [GCP-SPECIFIC]. Non-GCP deployments require replacing the output section with appropriate alternatives (e.g., `es` for Elasticsearch, `opensearch` for OpenSearch, `s3` for AWS).
- The `iam.gke.io/gcp-service-account` annotation on the Fluent Bit service account is GCP-only.

### No Structured Log Format Enforcement
- While JSON parsers are defined in Fluent Bit, there is no enforcement mechanism ensuring applications emit structured (JSON) logs. Applications emitting unstructured logs will not benefit from field-level indexing in Elasticsearch/OpenSearch.

### Limited Tracing Coverage
- Tracing relies on Cloud Trace [GCP-SPECIFIC] without explicit Kubernetes manifests for a self-hosted tracing backend. Teams not on GCP must provision Jaeger or Tempo separately.
- No trace sampling configuration is defined, which may result in excessive trace storage costs at scale.

### SIEM Rules Lack Automated Tuning
- Detection thresholds (e.g., 5 failed logins, 10 payment attempts, 100 record accesses) are hardcoded. There is no baseline-learning or anomaly-detection layer to auto-tune thresholds based on normal traffic patterns.

## Recommendations

### Short-Term (Sprint 1-2)

1. **Configure Alertmanager receivers**: Complete the PagerDuty and Slack integration in Alertmanager config. Use ExternalSecrets for integration keys. Wire `critical` severity to PagerDuty, `warning` to Slack, and `default` to a low-urgency channel.

2. **Add Elasticsearch/OpenSearch output to Fluent Bit**: Supplement the GCP-specific `stackdriver` output with an `es` or `opensearch` output plugin pointing to the Elasticsearch cluster. This enables log-based SIEM rules to function regardless of cloud provider.

3. **Enable Grafana alerting**: Configure Grafana contact points to mirror Alertmanager's routes. This provides a secondary alerting path and enables dashboard-driven alert management for non-Prometheus data sources.

4. **Add namespace-scoped dashboards**: Current dashboards hardcode namespace selectors. Add Grafana template variables for `$namespace` and `$service` to enable multi-tenant dashboard reuse.

### Medium-Term (Sprint 3-5)

5. **Deploy Thanos or Mimir for long-term storage**: Add a Thanos sidecar to Prometheus for object-storage-backed long-term retention. This addresses the 15-day retention limitation and enables cross-cluster metric federation.

6. **Implement Prometheus HA**: Deploy at least two Prometheus replicas with Thanos or use Prometheus Agent mode with remote write for high-availability metric collection.

7. **Deploy self-hosted tracing**: Provision Grafana Tempo (preferred for Grafana ecosystem integration) or Jaeger as a self-hosted tracing backend. Configure OpenTelemetry Collector as the trace ingestion point for cloud-agnostic trace collection.

8. **Enforce structured logging**: Implement an OPA/Gatekeeper policy or Kyverno policy requiring pods to have a structured logging sidecar or to declare a `logging.format: json` annotation. Add Fluent Bit parser validation.

### Long-Term (Sprint 6+)

9. **Implement SLO-based alerting**: Replace threshold-based alerts with SLO-based alerts using Sloth or Pyrra. Define error budgets for each service and alert when burn rate exceeds acceptable levels.

10. **Add ML-based anomaly detection**: Integrate Elasticsearch ML jobs or Prometheus recording rules with statistical functions to establish baselines and detect anomalies in authentication, payment, and API traffic patterns. This replaces hardcoded SIEM thresholds.

11. **Unified observability with OpenTelemetry Collector**: Replace the direct Prometheus scraping + Fluent Bit + Cloud Trace setup with an OpenTelemetry Collector that handles metrics, logs, and traces through a single pipeline. This simplifies configuration and enables vendor-neutral telemetry routing.

12. **Dashboard-as-Code**: Adopt Grafonnet (Jsonnet library for Grafana) or Grafana Dashboard-as-Code tools to generate dashboards programmatically. This prevents dashboard configuration drift and enables per-service dashboard generation from templates.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Comprehensive Three-Pillar Observability
- Security-First Observability
- Multi-Layer SIEM Integration
- ILM Policies with Security-Aware Retention

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
