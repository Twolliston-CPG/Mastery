# Exercise 1: ConfigMaps and Secrets Management

## Objective

Master configuration management in Kubernetes using ConfigMaps and Secrets, including creation methods, mounting strategies, and best practices for secure handling.

## Prerequisites

- Running Kubernetes cluster
- `kubectl` configured
- Basic understanding of environment variables and file systems

## Tasks

### Task 1: Create ConfigMaps

**From literal values:**
```bash
kubectl create configmap app-config \
  --from-literal=DATABASE_HOST=postgres \
  --from-literal=DATABASE_PORT=5432 \
  --from-literal=LOG_LEVEL=info
```

**From files:**
```bash
# Create config file
cat > app.properties <<EOF
database.host=postgres
database.port=5432
database.pool.size=10
cache.enabled=true
cache.ttl=3600
EOF

kubectl create configmap app-properties --from-file=app.properties
```

**From directory:**
```bash
mkdir -p config-files
echo "server.port=8080" > config-files/server.conf
echo "logging.level=DEBUG" > config-files/logging.conf

kubectl create configmap multi-config --from-file=config-files/
```

**From YAML:**
```yaml
# configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: detailed-config
  labels:
    app: myapp
data:
  # Simple key-value
  DATABASE_URL: "postgres://localhost:5432/mydb"
  CACHE_SIZE: "100"

  # Multi-line config file
  nginx.conf: |
    server {
        listen 80;
        server_name localhost;

        location / {
            proxy_pass http://backend:8080;
        }
    }

  # JSON configuration
  config.json: |
    {
      "database": {
        "host": "postgres",
        "port": 5432
      },
      "features": {
        "newUI": true,
        "darkMode": false
      }
    }
```

### Task 2: Create Secrets

**Generic secrets:**
```bash
kubectl create secret generic db-credentials \
  --from-literal=username=admin \
  --from-literal=password='S3cr3tP@ssw0rd!'
```

**From files (certificates, keys):**
```bash
# Generate sample TLS cert
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=myapp.example.com"

kubectl create secret tls myapp-tls \
  --cert=tls.crt \
  --key=tls.key
```

**Docker registry secret:**
```bash
kubectl create secret docker-registry regcred \
  --docker-server=registry.example.com \
  --docker-username=myuser \
  --docker-password=mypassword \
  --docker-email=myemail@example.com
```

**From YAML (base64 encoded):**
```yaml
# secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: api-keys
type: Opaque
data:
  # echo -n 'my-api-key' | base64
  api-key: bXktYXBpLWtleQ==
  # echo -n 'my-api-secret' | base64
  api-secret: bXktYXBpLXNlY3JldA==
---
# Using stringData (no base64 encoding required)
apiVersion: v1
kind: Secret
metadata:
  name: api-keys-string
type: Opaque
stringData:
  api-key: my-api-key
  api-secret: my-api-secret
```

### Task 3: Use ConfigMaps in Pods

```yaml
# pod-with-configmap.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: config-lab
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-env
  namespace: config-lab
data:
  DATABASE_HOST: postgres
  DATABASE_PORT: "5432"
  LOG_LEVEL: info
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-files
  namespace: config-lab
data:
  config.yaml: |
    server:
      port: 8080
      host: 0.0.0.0
    database:
      host: postgres
      port: 5432
    logging:
      level: info
      format: json
---
apiVersion: v1
kind: Pod
metadata:
  name: config-demo
  namespace: config-lab
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "env && cat /config/config.yaml && sleep 3600"]

    # Method 1: Environment variables from ConfigMap
    envFrom:
    - configMapRef:
        name: app-env

    # Method 2: Individual env vars
    env:
    - name: CUSTOM_VAR
      valueFrom:
        configMapKeyRef:
          name: app-env
          key: LOG_LEVEL

    # Method 3: Mount as files
    volumeMounts:
    - name: config-volume
      mountPath: /config
      readOnly: true

  volumes:
  - name: config-volume
    configMap:
      name: app-files
```

**Test:**
```bash
kubectl apply -f pod-with-configmap.yaml
kubectl logs -n config-lab config-demo
kubectl exec -n config-lab config-demo -- cat /config/config.yaml
```

### Task 4: Use Secrets in Pods

```yaml
# pod-with-secrets.yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-secret
  namespace: config-lab
type: Opaque
stringData:
  username: postgres
  password: "SuperSecretPassword123!"
  connection-string: "postgresql://postgres:SuperSecretPassword123!@postgres:5432/mydb"
---
apiVersion: v1
kind: Pod
metadata:
  name: secret-demo
  namespace: config-lab
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "echo DB_USER=$DB_USER && ls -la /secrets && sleep 3600"]

    # Method 1: Environment variables from Secret
    env:
    - name: DB_USER
      valueFrom:
        secretKeyRef:
          name: db-secret
          key: username
    - name: DB_PASS
      valueFrom:
        secretKeyRef:
          name: db-secret
          key: password

    # Method 2: Mount as files
    volumeMounts:
    - name: secret-volume
      mountPath: /secrets
      readOnly: true

  volumes:
  - name: secret-volume
    secret:
      secretName: db-secret
      # Optional: set file permissions
      defaultMode: 0400
```

### Task 5: Subpath Mounting

Mount specific keys to specific paths:

```yaml
# subpath-demo.yaml
apiVersion: v1
kind: Pod
metadata:
  name: subpath-demo
  namespace: config-lab
spec:
  containers:
  - name: app
    image: nginx:alpine
    volumeMounts:
    # Mount only nginx.conf to the expected location
    - name: config
      mountPath: /etc/nginx/conf.d/default.conf
      subPath: nginx.conf
    # Mount only index.html
    - name: content
      mountPath: /usr/share/nginx/html/index.html
      subPath: index.html
  volumes:
  - name: config
    configMap:
      name: nginx-config
  - name: content
    configMap:
      name: nginx-content
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
  namespace: config-lab
data:
  nginx.conf: |
    server {
        listen 80;
        location / {
            root /usr/share/nginx/html;
        }
    }
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-content
  namespace: config-lab
data:
  index.html: |
    <html><body><h1>Hello from ConfigMap!</h1></body></html>
```

### Task 6: Immutable ConfigMaps and Secrets

```yaml
# immutable-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: immutable-config
  namespace: config-lab
immutable: true  # Cannot be modified after creation
data:
  version: "1.0.0"
  release-date: "2024-01-01"
---
apiVersion: v1
kind: Secret
metadata:
  name: immutable-secret
  namespace: config-lab
immutable: true
type: Opaque
stringData:
  api-key: never-change-this
```

**Benefits of immutable configs:**
- Protection from accidental updates
- Better cluster performance (no watch overhead)
- Requires deletion and recreation to update

### Task 7: Live Updates with ConfigMap Reloading

```yaml
# live-reload-demo.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: live-config
  namespace: config-lab
data:
  feature-flags.json: |
    {
      "newFeature": false,
      "betaMode": false
    }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: live-reload-app
  namespace: config-lab
spec:
  replicas: 1
  selector:
    matchLabels:
      app: live-reload
  template:
    metadata:
      labels:
        app: live-reload
      annotations:
        # Force redeployment when config changes
        checksum/config: "initial"
    spec:
      containers:
      - name: app
        image: busybox
        command: ["sh", "-c", "while true; do cat /config/feature-flags.json; sleep 10; done"]
        volumeMounts:
        - name: config
          mountPath: /config
      volumes:
      - name: config
        configMap:
          name: live-config
```

**Update and observe:**
```bash
# Watch logs
kubectl logs -f -n config-lab -l app=live-reload &

# Update ConfigMap
kubectl patch configmap live-config -n config-lab -p '{"data":{"feature-flags.json":"{\"newFeature\": true, \"betaMode\": false}"}}'

# Wait ~30-60 seconds for automatic update (kubelet sync period)
```

### Task 8: Secret Encryption at Rest

Check if encryption is enabled:
```bash
# On the control plane node
cat /etc/kubernetes/manifests/kube-apiserver.yaml | grep encryption
```

Create encryption config:
```yaml
# encryption-config.yaml (for cluster admin)
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
- resources:
  - secrets
  providers:
  - aescbc:
      keys:
      - name: key1
        secret: <base64-encoded-32-byte-key>
  - identity: {}
```

## Success Criteria

- [ ] ConfigMaps created from various sources
- [ ] Secrets created securely
- [ ] ConfigMaps mounted as environment variables
- [ ] ConfigMaps mounted as files
- [ ] Secrets mounted securely with proper permissions
- [ ] Subpath mounting works correctly
- [ ] Immutable configs prevent modifications
- [ ] Live updates propagate to pods

## Security Best Practices

1. **Never commit secrets to git** - Use external secret managers
2. **Use RBAC to restrict access** - Limit who can read secrets
3. **Enable encryption at rest** - Protect etcd data
4. **Rotate secrets regularly** - Implement rotation policies
5. **Audit secret access** - Enable audit logging
6. **Use short-lived tokens** - Prefer bound service account tokens

## Cleanup

```bash
kubectl delete namespace config-lab
rm -rf config-files app.properties tls.key tls.crt
```

## Next Exercise

Continue to [Exercise 2: External Secrets](./02-external-secrets.md) to learn about integrating with external secret managers.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Security Best Practices
- Create ConfigMaps
- Create Secrets
- Use ConfigMaps in Pods

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
