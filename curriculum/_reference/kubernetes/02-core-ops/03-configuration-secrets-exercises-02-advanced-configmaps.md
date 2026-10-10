# Exercise 2: Advanced ConfigMap Patterns

## Objectives

- Implement advanced ConfigMap patterns
- Handle configuration updates dynamically
- Use ConfigMaps for complex configurations
- Implement environment-specific configurations

## Prerequisites

- Completed Exercise 1
- Understanding of ConfigMap basics
- kubectl proficiency

---

## Part 1: ConfigMap Data Sources

### 1.1 From Files

```bash
# Create ConfigMap from file
kubectl create configmap app-config \
  --from-file=config.yaml \
  --from-file=settings.json

# From specific key
kubectl create configmap nginx-config \
  --from-file=nginx.conf=/path/to/custom.conf

# From directory
kubectl create configmap app-configs \
  --from-file=./configs/
```

### 1.2 From Literals

```bash
# Multiple literals
kubectl create configmap app-env \
  --from-literal=DATABASE_HOST=postgres \
  --from-literal=DATABASE_PORT=5432 \
  --from-literal=LOG_LEVEL=info
```

### 1.3 From Environment File

```bash
# env file format
cat <<EOF > app.env
DATABASE_HOST=postgres
DATABASE_PORT=5432
LOG_LEVEL=info
EOF

kubectl create configmap app-env --from-env-file=app.env
```

---

## Part 2: Complex Configuration Files

### 2.1 Multi-File ConfigMap

```yaml
# multi-file-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-configuration
data:
  application.yaml: |
    server:
      port: 8080
      shutdown: graceful
    spring:
      datasource:
        url: jdbc:postgresql://${DB_HOST}:${DB_PORT}/${DB_NAME}
        username: ${DB_USER}
      jpa:
        hibernate:
          ddl-auto: validate

  logback.xml: |
    <?xml version="1.0" encoding="UTF-8"?>
    <configuration>
      <appender name="CONSOLE" class="ch.qos.logback.core.ConsoleAppender">
        <encoder>
          <pattern>%d{HH:mm:ss.SSS} [%thread] %-5level %logger{36} - %msg%n</pattern>
        </encoder>
      </appender>
      <root level="${LOG_LEVEL:-INFO}">
        <appender-ref ref="CONSOLE"/>
      </root>
    </configuration>

  prometheus.yaml: |
    global:
      scrape_interval: 15s
    scrape_configs:
      - job_name: 'kubernetes-pods'
        kubernetes_sd_configs:
          - role: pod
```

### 2.2 Binary Data ConfigMap

```yaml
# binary-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: binary-config
binaryData:
  # Base64 encoded binary file
  keystore.jks: |
    MIIKQQIBAzCCCfsGCSqGSIb3DQEHAaCCCewEggnoMIIJ5DCCBe0GCSqGSIb3
    DQEHAaCCBd4EggXaMIIF1jCCBdIGCyqGSIb3DQEMCgECoIIE+zCCBPcwKQYK
    ...
data:
  # Text data alongside binary
  keystore-password: changeit
```

---

## Part 3: ConfigMap Volume Patterns

### 3.1 SubPath Mounting

```yaml
# subpath-mount.yaml
apiVersion: v1
kind: Pod
metadata:
  name: subpath-demo
spec:
  containers:
  - name: app
    image: myapp:1.0
    volumeMounts:
    # Mount single file without overwriting directory
    - name: config
      mountPath: /app/config/application.yaml
      subPath: application.yaml
    - name: config
      mountPath: /app/config/logback.xml
      subPath: logback.xml
  volumes:
  - name: config
    configMap:
      name: app-configuration
```

### 3.2 Items Selection

```yaml
# selective-mount.yaml
apiVersion: v1
kind: Pod
metadata:
  name: selective-mount
spec:
  containers:
  - name: app
    image: myapp:1.0
    volumeMounts:
    - name: config
      mountPath: /etc/app
  volumes:
  - name: config
    configMap:
      name: app-configuration
      items:
      - key: application.yaml
        path: app.yaml      # Rename on mount
        mode: 0644
      - key: logback.xml
        path: logging.xml
        mode: 0644
```

### 3.3 Optional ConfigMaps

```yaml
# optional-configmap.yaml
apiVersion: v1
kind: Pod
metadata:
  name: optional-config
spec:
  containers:
  - name: app
    image: myapp:1.0
    envFrom:
    - configMapRef:
        name: optional-settings
        optional: true        # Pod starts even if ConfigMap missing
    volumeMounts:
    - name: optional-config
      mountPath: /etc/optional
  volumes:
  - name: optional-config
    configMap:
      name: optional-settings
      optional: true
```

---

## Part 4: Dynamic Configuration Updates

### 4.1 Automatic Reload with Volume Mount

```yaml
# auto-reload-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
data:
  nginx.conf: |
    events {
      worker_connections 1024;
    }
    http {
      server {
        listen 80;
        location / {
          return 200 'Version 1';
        }
      }
    }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-auto-reload
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        volumeMounts:
        - name: config
          mountPath: /etc/nginx/nginx.conf
          subPath: nginx.conf
      # Sidecar that watches for config changes and reloads nginx
      - name: config-reloader
        image: busybox:1.36
        command:
        - /bin/sh
        - -c
        - |
          LAST_HASH=""
          while true; do
            CURRENT_HASH=$(md5sum /etc/nginx/nginx.conf | cut -d' ' -f1)
            if [ "$CURRENT_HASH" != "$LAST_HASH" ]; then
              echo "Config changed, reloading nginx..."
              wget -q -O- http://localhost:80/healthz || true
              kill -HUP 1 2>/dev/null || true
              LAST_HASH=$CURRENT_HASH
            fi
            sleep 5
          done
        volumeMounts:
        - name: config
          mountPath: /etc/nginx/nginx.conf
          subPath: nginx.conf
          readOnly: true
      volumes:
      - name: config
        configMap:
          name: nginx-config
```

### 4.2 Hash-Based Rollout

```yaml
# hash-rollout.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: config-hash-demo
spec:
  template:
    metadata:
      annotations:
        # Forces rollout when ConfigMap changes
        configmap-hash: "{{ .Values.configmapHash }}"
    spec:
      containers:
      - name: app
        image: myapp:1.0
        envFrom:
        - configMapRef:
            name: app-config
```

```bash
# Update and trigger rollout
kubectl create configmap app-config --from-literal=key=newvalue --dry-run=client -o yaml | kubectl apply -f -
kubectl patch deployment config-hash-demo -p '{"spec":{"template":{"metadata":{"annotations":{"configmap-hash":"'$(date +%s)'"}}}}}'
```

### 4.3 Reloader Controller

```bash
# Install Reloader
kubectl apply -f https://raw.githubusercontent.com/stakater/Reloader/master/deployments/kubernetes/reloader.yaml

# Annotate deployment for auto-reload
kubectl annotate deployment myapp reloader.stakater.com/auto="true"
```

---

## Part 5: Environment-Specific Configuration

### 5.1 Kustomize Overlays

```yaml
# base/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  LOG_LEVEL: info
  CACHE_ENABLED: "true"

# overlays/dev/configmap-patch.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  LOG_LEVEL: debug
  DEBUG_MODE: "true"

# overlays/prod/configmap-patch.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  LOG_LEVEL: warn
  CACHE_ENABLED: "true"
  CACHE_TTL: "3600"
```

### 5.2 ConfigMap Generator

```yaml
# kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

configMapGenerator:
- name: app-config
  behavior: merge
  literals:
  - LOG_LEVEL=info
  files:
  - application.yaml
  envs:
  - config.env

# Generated name includes hash: app-config-abc123
# References automatically updated
```

### 5.3 Namespace-Scoped Defaults

```yaml
# namespace-defaults.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: namespace-defaults
  namespace: production
data:
  DEFAULT_REPLICAS: "3"
  DEFAULT_LOG_LEVEL: "warn"
  ENVIRONMENT: "production"
  ENABLE_DEBUG: "false"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: namespace-defaults
  namespace: staging
data:
  DEFAULT_REPLICAS: "1"
  DEFAULT_LOG_LEVEL: "info"
  ENVIRONMENT: "staging"
  ENABLE_DEBUG: "true"
```

---

## Part 6: Configuration Validation

### 6.1 Init Container Validation

```yaml
# config-validation.yaml
apiVersion: v1
kind: Pod
metadata:
  name: validated-config
spec:
  initContainers:
  - name: validate-config
    image: python:3.11-slim
    command:
    - python
    - -c
    - |
      import yaml
      import sys
      import os

      try:
          with open('/config/application.yaml') as f:
              config = yaml.safe_load(f)

          # Validate required fields
          required = ['server.port', 'database.host']
          for field in required:
              keys = field.split('.')
              value = config
              for key in keys:
                  value = value.get(key)
                  if value is None:
                      print(f"Missing required config: {field}")
                      sys.exit(1)

          print("Configuration validated successfully")
      except Exception as e:
          print(f"Configuration validation failed: {e}")
          sys.exit(1)
    volumeMounts:
    - name: config
      mountPath: /config
  containers:
  - name: app
    image: myapp:1.0
    volumeMounts:
    - name: config
      mountPath: /app/config
  volumes:
  - name: config
    configMap:
      name: app-configuration
```

### 6.2 Admission Webhook Validation

```yaml
# validating-webhook.yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
metadata:
  name: configmap-validator
webhooks:
- name: configmap.validator.example.com
  clientConfig:
    service:
      name: configmap-validator
      namespace: kube-system
      path: /validate
  rules:
  - apiGroups: [""]
    apiVersions: ["v1"]
    operations: ["CREATE", "UPDATE"]
    resources: ["configmaps"]
  namespaceSelector:
    matchLabels:
      validate-configs: "true"
```

---

## Part 7: Hands-on Challenges

### Challenge 1: Feature Flags

Implement a feature flag system:
1. ConfigMap with feature toggles
2. Application reads flags at startup
3. Support hot-reload of flags
4. Different flags per environment

### Challenge 2: Configuration Templating

Create a configuration system that:
1. Uses base templates
2. Supports variable substitution
3. Validates generated configs
4. Applies environment overrides

### Challenge 3: Config Drift Detection

Build a system to:
1. Track ConfigMap versions
2. Detect unauthorized changes
3. Alert on drift
4. Auto-remediate drift

---

## Verification Tasks

1. [ ] Created ConfigMaps from various sources
2. [ ] Implemented multi-file ConfigMaps
3. [ ] Used subPath and items for selective mounting
4. [ ] Configured automatic config reload
5. [ ] Set up environment-specific configs
6. [ ] Implemented config validation

---

## Key Takeaways

- ConfigMaps support multiple data sources
- subPath enables file-level mounting
- Volume mounts update automatically
- Environment variables require pod restart
- Kustomize helps manage environment configs
- Validation prevents runtime errors

---

## Next Steps

Continue to [Exercise 3: Secrets Management](03-secrets-management.md)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- ConfigMap Data Sources
- Complex Configuration Files
- ConfigMap Volume Patterns
- Dynamic Configuration Updates

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
