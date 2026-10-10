# Configuration & Secrets Management

Secure, scalable configuration management for production Kubernetes.

## Learning Path

1. [ConfigMap Patterns](#configmap-patterns)
2. [Secrets Management](#secrets-management)
3. [External Secrets Operator](#external-secrets-operator)
4. [Vault Integration](#vault-integration)

---

## ConfigMap Patterns

### Creating ConfigMaps

```yaml
# ConfigMap with multiple data types
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  # Simple key-value
  LOG_LEVEL: "info"
  DATABASE_HOST: "postgres.default.svc.cluster.local"

  # File content
  config.yaml: |
    server:
      port: 8080
      timeout: 30s
    database:
      pool_size: 10

  nginx.conf: |
    worker_processes auto;
    events {
        worker_connections 1024;
    }
```

### Mounting ConfigMaps

```yaml
# As environment variables
env:
- name: LOG_LEVEL
  valueFrom:
    configMapKeyRef:
      name: app-config
      key: LOG_LEVEL

# All keys as env vars
envFrom:
- configMapRef:
    name: app-config

# As volume
volumes:
- name: config
  configMap:
    name: app-config
    items:
    - key: config.yaml
      path: config.yaml
      mode: 0644
```

---

## Secrets Management

### Secret Types

```yaml
# Generic secret
apiVersion: v1
kind: Secret
metadata:
  name: app-secret
type: Opaque
stringData:
  API_KEY: "secret-api-key"
  DATABASE_URL: "postgresql://user:pass@host/db"

---
# TLS secret
apiVersion: v1
kind: Secret
metadata:
  name: tls-secret
type: kubernetes.io/tls
data:
  tls.crt: <base64-cert>
  tls.key: <base64-key>

---
# Docker registry secret
apiVersion: v1
kind: Secret
metadata:
  name: regcred
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: <base64-docker-config>
```

---

## External Secrets Operator

### Installation

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets \
  -n external-secrets --create-namespace
```

### AWS Secrets Manager Integration

```yaml
# ClusterSecretStore for AWS
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: aws-secrets
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-west-2
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets-sa
            namespace: external-secrets
---
# ExternalSecret
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: database-credentials
spec:
  refreshInterval: 1h
  secretStoreRef:
    kind: ClusterSecretStore
    name: aws-secrets
  target:
    name: database-secret
    creationPolicy: Owner
  data:
  - secretKey: username
    remoteRef:
      key: production/database
      property: username
  - secretKey: password
    remoteRef:
      key: production/database
      property: password
```

---

## Vault Integration

### Vault Agent Injector

```yaml
# Pod with Vault sidecar
apiVersion: v1
kind: Pod
metadata:
  name: app
  annotations:
    vault.hashicorp.com/agent-inject: "true"
    vault.hashicorp.com/role: "app"
    vault.hashicorp.com/agent-inject-secret-config: "secret/data/app/config"
    vault.hashicorp.com/agent-inject-template-config: |
      {{- with secret "secret/data/app/config" -}}
      DATABASE_URL={{ .Data.data.database_url }}
      API_KEY={{ .Data.data.api_key }}
      {{- end }}
spec:
  serviceAccountName: app
  containers:
  - name: app
    image: myapp:1.0
    volumeMounts:
    - name: vault-secrets
      mountPath: /vault/secrets
      readOnly: true
```

---

## Exercises

1. **[Exercise 1: ConfigMap Patterns](./exercises/01-configmap-patterns.md)**
2. **[Exercise 2: Secret Rotation](./exercises/02-secret-rotation.md)**
3. **[Exercise 3: External Secrets](./exercises/03-external-secrets.md)**
4. **[Exercise 4: Vault Integration](./exercises/04-vault-integration.md)**
5. **[Exercise 5: GitOps Secrets](./exercises/05-gitops-secrets.md)**

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- ConfigMap Patterns
- Secrets Management
- External Secrets Operator
- Vault Integration

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
