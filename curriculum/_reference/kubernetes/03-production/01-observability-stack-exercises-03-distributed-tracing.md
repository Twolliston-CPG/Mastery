# Exercise 3: Distributed Tracing with Jaeger/Tempo

## Objectives

- Understand distributed tracing concepts
- Deploy Jaeger and Grafana Tempo
- Instrument applications for tracing
- Correlate traces with logs and metrics

## Prerequisites

- Completed Exercises 1-2
- Understanding of microservices architecture
- Prometheus and Loki deployed

---

## Part 1: Distributed Tracing Concepts

### 1.1 Key Terminology

**Trace anatomy**

```text
Trace abc123
├─ api-gateway ..................................... 120 ms   (root span)
│  ├─ auth-service ....... 30 ms
│  └─ user-service ..................... 80 ms
│     └─ database query ......... 40 ms              (grandchild)
```

A **trace** is one request. A **span** is one unit of work inside it, with a start time, a duration,
a parent, and attributes. Spans nest, and the nesting is what tells you that the 40 ms database query
is *inside* the 80 ms user-service call rather than beside it.

**Context propagation** — how the child knows its parent:

```text
traceparent: 00-abc123-def456-01
             │  │      │      └── flags (01 = sampled)
             │  │      └── parent span id
             │  └── trace id
             └── version
tracestate:  vendor=value
```

The header is W3C Trace Context, and propagating it is the whole job. One service in the chain that
drops it does not produce a gap in the trace — it produces **two unrelated traces**, and nothing in
either one says the other exists.

### 1.2 OpenTelemetry Standard

```yaml
# OpenTelemetry trace context headers
traceparent: "00-{trace-id}-{parent-span-id}-{trace-flags}"
tracestate: "vendor1=value1,vendor2=value2"

# Example
traceparent: "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"
```

---

## Part 2: Deploy Jaeger

### 2.1 Jaeger Operator Installation

```bash
# Install cert-manager (required for Jaeger Operator)
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Wait for cert-manager
kubectl wait --for=condition=Available deployment --all -n cert-manager --timeout=300s

# Install Jaeger Operator
kubectl create namespace observability
kubectl apply -f https://github.com/jaegertracing/jaeger-operator/releases/download/v1.51.0/jaeger-operator.yaml -n observability
```

### 2.2 Production Jaeger Instance

```yaml
# jaeger-production.yaml
apiVersion: jaegertracing.io/v1
kind: Jaeger
metadata:
  name: jaeger
  namespace: observability
spec:
  strategy: production

  # Collector configuration
  collector:
    replicas: 3
    maxReplicas: 5
    resources:
      requests:
        cpu: 500m
        memory: 512Mi
      limits:
        cpu: 1000m
        memory: 1Gi
    options:
      collector:
        num-workers: 100
        queue-size: 10000

  # Query service
  query:
    replicas: 2
    resources:
      requests:
        cpu: 250m
        memory: 256Mi
    options:
      query:
        base-path: /jaeger

  # Storage configuration (Elasticsearch)
  storage:
    type: elasticsearch
    options:
      es:
        server-urls: https://elasticsearch:9200
        index-prefix: jaeger
        num-shards: 5
        num-replicas: 1
    esIndexCleaner:
      enabled: true
      numberOfDays: 7
      schedule: "55 23 * * *"

  # Ingester for Kafka buffering
  ingester:
    replicas: 3
    options:
      kafka:
        consumer:
          topic: jaeger-spans
          brokers: kafka:9092

  # Sampling configuration
  sampling:
    options:
      default_strategy:
        type: probabilistic
        param: 0.1  # 10% sampling
      service_strategies:
        - service: critical-service
          type: probabilistic
          param: 1.0  # 100% sampling
        - service: high-volume-service
          type: ratelimiting
          param: 100  # 100 traces/second
```

### 2.3 Simple Jaeger for Development

```yaml
# jaeger-development.yaml
apiVersion: jaegertracing.io/v1
kind: Jaeger
metadata:
  name: jaeger-dev
  namespace: observability
spec:
  strategy: allInOne
  allInOne:
    image: jaegertracing/all-in-one:1.51
    options:
      memory:
        max-traces: 100000
  storage:
    type: memory
  ingress:
    enabled: true
```

---

## Part 3: Deploy Grafana Tempo

### 3.1 Tempo Installation

```bash
# Install Tempo with Helm
helm repo add grafana https://grafana.github.io/helm-charts
helm install tempo grafana/tempo \
  --namespace observability \
  --create-namespace
```

### 3.2 Production Tempo Configuration

```yaml
# tempo-values.yaml
tempo:
  # Storage backend
  storage:
    trace:
      backend: s3
      s3:
        bucket: tempo-traces
        endpoint: s3.amazonaws.com
        region: us-west-2
        access_key: ${AWS_ACCESS_KEY}
        secret_key: ${AWS_SECRET_KEY}

  # Receivers
  receivers:
    jaeger:
      protocols:
        thrift_http:
          endpoint: 0.0.0.0:14268
        grpc:
          endpoint: 0.0.0.0:14250
    otlp:
      protocols:
        grpc:
          endpoint: 0.0.0.0:4317
        http:
          endpoint: 0.0.0.0:4318
    zipkin:
      endpoint: 0.0.0.0:9411

  # Retention
  compactor:
    compaction:
      block_retention: 168h  # 7 days

  # Query
  querier:
    max_concurrent_queries: 20
    search:
      prefer_self: 10

  # Resources
  resources:
    requests:
      cpu: 500m
      memory: 1Gi
    limits:
      cpu: 2000m
      memory: 4Gi

# Tempo distributed mode
distributor:
  replicas: 3

ingester:
  replicas: 3
  persistence:
    enabled: true
    size: 50Gi

querier:
  replicas: 2

queryFrontend:
  replicas: 2
```

### 3.3 Tempo with Grafana

```yaml
# grafana-tempo-datasource.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-datasources
  namespace: monitoring
  labels:
    grafana_datasource: "1"
data:
  tempo-datasource.yaml: |
    apiVersion: 1
    datasources:
      - name: Tempo
        type: tempo
        access: proxy
        url: http://tempo:3100
        jsonData:
          tracesToLogsV2:
            datasourceUid: loki
            spanStartTimeShift: '-1h'
            spanEndTimeShift: '1h'
            filterByTraceID: true
            filterBySpanID: false
            tags:
              - key: service.name
                value: app
          tracesToMetrics:
            datasourceUid: prometheus
            spanStartTimeShift: '-1h'
            spanEndTimeShift: '1h'
            tags:
              - key: service.name
                value: service
            queries:
              - name: Request rate
                query: 'sum(rate(http_server_requests_seconds_count{$$__tags}[1m]))'
          serviceMap:
            datasourceUid: prometheus
          nodeGraph:
            enabled: true
          search:
            hide: false
          lokiSearch:
            datasourceUid: loki
```

---

## Part 4: Application Instrumentation

### 4.1 OpenTelemetry Collector

```yaml
# otel-collector.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: otel-collector-config
  namespace: observability
data:
  collector.yaml: |
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
          http:
            endpoint: 0.0.0.0:4318
      jaeger:
        protocols:
          grpc:
            endpoint: 0.0.0.0:14250
          thrift_http:
            endpoint: 0.0.0.0:14268

    processors:
      batch:
        timeout: 1s
        send_batch_size: 1024

      memory_limiter:
        check_interval: 1s
        limit_percentage: 75
        spike_limit_percentage: 15

      resource:
        attributes:
          - key: environment
            value: production
            action: upsert

      tail_sampling:
        decision_wait: 10s
        num_traces: 100000
        expected_new_traces_per_sec: 10000
        policies:
          - name: errors
            type: status_code
            status_code: {status_codes: [ERROR]}
          - name: slow-traces
            type: latency
            latency: {threshold_ms: 1000}
          - name: probabilistic
            type: probabilistic
            probabilistic: {sampling_percentage: 10}

    exporters:
      otlp/tempo:
        endpoint: tempo:4317
        tls:
          insecure: true

      prometheus:
        endpoint: 0.0.0.0:8889
        namespace: traces

    extensions:
      health_check:
        endpoint: 0.0.0.0:13133
      pprof:
        endpoint: 0.0.0.0:1777

    service:
      extensions: [health_check, pprof]
      pipelines:
        traces:
          receivers: [otlp, jaeger]
          processors: [memory_limiter, batch, tail_sampling]
          exporters: [otlp/tempo]
        metrics:
          receivers: [otlp]
          processors: [memory_limiter, batch]
          exporters: [prometheus]
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: otel-collector
  namespace: observability
spec:
  replicas: 3
  selector:
    matchLabels:
      app: otel-collector
  template:
    metadata:
      labels:
        app: otel-collector
    spec:
      containers:
      - name: collector
        image: otel/opentelemetry-collector-contrib:0.88.0
        args:
        - --config=/etc/otel/collector.yaml
        ports:
        - containerPort: 4317
          name: otlp-grpc
        - containerPort: 4318
          name: otlp-http
        - containerPort: 14250
          name: jaeger-grpc
        - containerPort: 14268
          name: jaeger-http
        volumeMounts:
        - name: config
          mountPath: /etc/otel
        resources:
          requests:
            cpu: 500m
            memory: 512Mi
          limits:
            cpu: 1000m
            memory: 1Gi
      volumes:
      - name: config
        configMap:
          name: otel-collector-config
```

### 4.2 Auto-Instrumentation with OTel Operator

```bash
# Install OpenTelemetry Operator
kubectl apply -f https://github.com/open-telemetry/opentelemetry-operator/releases/latest/download/opentelemetry-operator.yaml
```

```yaml
# auto-instrumentation.yaml
apiVersion: opentelemetry.io/v1alpha1
kind: Instrumentation
metadata:
  name: auto-instrumentation
  namespace: production
spec:
  exporter:
    endpoint: http://otel-collector.observability:4317
  propagators:
    - tracecontext
    - baggage
  sampler:
    type: parentbased_traceidratio
    argument: "0.1"

  # Java instrumentation
  java:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-java:latest
    env:
      - name: OTEL_INSTRUMENTATION_JDBC_ENABLED
        value: "true"

  # Node.js instrumentation
  nodejs:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-nodejs:latest

  # Python instrumentation
  python:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-python:latest
```

### 4.3 Instrumented Deployment

```yaml
# instrumented-app.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-java-app
  namespace: production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-java-app
  template:
    metadata:
      labels:
        app: my-java-app
      annotations:
        # Auto-instrumentation
        instrumentation.opentelemetry.io/inject-java: "true"
    spec:
      containers:
      - name: app
        image: my-java-app:1.0
        ports:
        - containerPort: 8080
        env:
        - name: OTEL_SERVICE_NAME
          value: my-java-app
        - name: OTEL_RESOURCE_ATTRIBUTES
          value: "service.namespace=production,deployment.environment=prod"
```

### 4.4 Manual Instrumentation (Python Example)

```python
# app.py
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor
from flask import Flask

# Set up tracing
trace.set_tracer_provider(TracerProvider())
tracer = trace.get_tracer(__name__)

# Configure exporter
otlp_exporter = OTLPSpanExporter(
    endpoint="otel-collector:4317",
    insecure=True
)
trace.get_tracer_provider().add_span_processor(
    BatchSpanProcessor(otlp_exporter)
)

app = Flask(__name__)

# Auto-instrument Flask
FlaskInstrumentor().instrument_app(app)
RequestsInstrumentor().instrument()

@app.route('/api/users/<user_id>')
def get_user(user_id):
    # Create custom span
    with tracer.start_as_current_span("fetch_user_data") as span:
        span.set_attribute("user.id", user_id)

        # Nested span for database call
        with tracer.start_as_current_span("database_query") as db_span:
            db_span.set_attribute("db.system", "postgresql")
            db_span.set_attribute("db.statement", "SELECT * FROM users WHERE id = ?")
            user = fetch_from_database(user_id)

        return user
```

---

## Part 5: Trace Analysis

### 5.1 TraceQL Queries (Tempo)

```traceql
# Find traces by service
{ resource.service.name = "api-gateway" }

# Find slow traces
{ span.http.status_code >= 500 } | duration > 1s

# Find traces with errors
{ status = error }

# Find traces by attribute
{ span.user.id = "12345" }

# Complex query
{ resource.service.name = "api-gateway" && span.http.method = "POST" } | duration > 500ms

# Aggregate
{ } | count() by (resource.service.name)

# Find traces spanning multiple services
{ resource.service.name = "frontend" } >> { resource.service.name = "backend" }
```

### 5.2 Span Metrics

```yaml
# Generate metrics from traces
metrics_generator:
  enabled: true
  registry:
    external_labels:
      source: tempo
  storage:
    path: /var/tempo/generator/wal
  traces_storage:
    path: /var/tempo/generator/traces
  processor:
    span_metrics:
      dimensions:
        - service.name
        - span.name
        - http.method
        - http.status_code
      histogram_buckets: [0.002, 0.004, 0.008, 0.016, 0.032, 0.064, 0.128, 0.256, 0.512, 1.02, 2.048, 4.096, 8.192]
    service_graphs:
      dimensions:
        - service.name
```

---

## Part 6: Correlation

### 6.1 Trace-Log Correlation

```yaml
# Application logs with trace context
{
  "timestamp": "2024-01-15T10:30:00Z",
  "level": "INFO",
  "message": "Processing order",
  "trace_id": "4bf92f3577b34da6a3ce929d0e0e4736",
  "span_id": "00f067aa0ba902b7",
  "service": "order-service",
  "order_id": "12345"
}
```

### 6.2 Exemplars in Prometheus

```yaml
# PrometheusRule with exemplars
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: exemplar-rules
spec:
  groups:
  - name: request-metrics
    rules:
    - record: http_request_duration_seconds:rate5m
      expr: rate(http_request_duration_seconds_sum[5m]) / rate(http_request_duration_seconds_count[5m])
      # Exemplars automatically attached when available
```

---

## Part 7: Hands-on Challenges

### Challenge 1: End-to-End Tracing

Implement tracing across services:
1. Instrument 3+ services
2. Propagate context across HTTP and message queues
3. Add custom attributes for business context
4. Visualize service dependencies

### Challenge 2: Performance Analysis

Use traces for optimization:
1. Identify slowest endpoints
2. Find database query bottlenecks
3. Detect N+1 query patterns
4. Measure external API latencies

### Challenge 3: Error Investigation

Debug production issues:
1. Find all traces with errors
2. Correlate with logs
3. Identify error patterns
4. Set up alerting on trace errors

---

## Verification Tasks

1. [ ] Tracing backend deployed (Jaeger or Tempo)
2. [ ] OTel Collector receiving traces
3. [ ] Applications instrumented
4. [ ] Traces visible in Grafana
5. [ ] Trace-log correlation working
6. [ ] Service map generated

---

## Key Takeaways

- Distributed tracing reveals request flow across services
- OpenTelemetry provides vendor-neutral instrumentation
- Sampling is crucial for high-volume systems
- Correlate traces, logs, and metrics for full observability
- Tail-based sampling catches important traces
- Auto-instrumentation reduces developer effort

---

## Next Steps

Continue to [Exercise 4: Grafana Dashboards](04-grafana-dashboards.md)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Distributed Tracing Concepts
- Deploy Jaeger
- Deploy Grafana Tempo
- Application Instrumentation

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"Kubernetes schedules the pod."* |
| ✓ | *"The scheduler watches for pods with no `nodeName`, filters nodes by predicates, scores the survivors, and writes `nodeName` into the pod spec. The kubelet on that node is watching the API for pods bound to it, and starts the containers."* |

**Trace it:** `kubectl apply -f pod.yaml` → a running container. Name every component that acts, in order, and what each one writes.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** [Kubernetes the Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way) — one weekend, and "the control plane" stops being a word.
Full list per domain: [`SOURCES.md`](../../SOURCES.md#kubernetes)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../../MASTERY.md)

<!-- /feynman-check -->
