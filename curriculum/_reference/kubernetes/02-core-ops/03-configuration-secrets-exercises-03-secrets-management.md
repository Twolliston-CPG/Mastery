# Exercise 3: Secrets Management

## Objectives

- Implement secure secrets handling
- Configure encryption at rest
- Use various secret types
- Implement secret rotation patterns

## Prerequisites

- Completed Exercises 1-2
- Understanding of base64 encoding
- Access to cluster admin

---

## Part 1: Secret Types

### 1.1 Opaque Secrets (Generic)

```yaml
# opaque-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
type: Opaque
data:
  # Base64 encoded values
  username: YWRtaW4=
  password: cGFzc3dvcmQxMjM=
---
# Using stringData (auto-encodes)
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets-string
type: Opaque
stringData:
  username: admin
  password: password123
```

```bash
# Create from literals
kubectl create secret generic db-creds \
  --from-literal=username=admin \
  --from-literal=password=secretpass

# Create from file
kubectl create secret generic tls-certs \
  --from-file=cert.pem \
  --from-file=key.pem
```

### 1.2 Docker Registry Secrets

```yaml
# docker-registry-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: registry-creds
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: eyJhdXRocyI6eyJyZWdpc3RyeS5leGFtcGxlLmNvbSI6eyJ1c2VybmFtZSI6InVzZXIiLCJwYXNzd29yZCI6InBhc3MiLCJhdXRoIjoiZFhObGNqcHdZWE56In19fQ==
```

```bash
# Create registry secret
kubectl create secret docker-registry regcred \
  --docker-server=registry.example.com \
  --docker-username=user \
  --docker-password=pass \
  --docker-email=user@example.com
```

### 1.3 TLS Secrets

```yaml
# tls-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: tls-secret
type: kubernetes.io/tls
data:
  tls.crt: LS0tLS1CRUdJTi...
  tls.key: LS0tLS1CRUdJTi...
```

```bash
# Create TLS secret
kubectl create secret tls my-tls-secret \
  --cert=path/to/cert.crt \
  --key=path/to/cert.key
```

### 1.4 Service Account Token

```yaml
# sa-token-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-sa-token
  annotations:
    kubernetes.io/service-account.name: my-service-account
type: kubernetes.io/service-account-token
```

### 1.5 Basic Auth Secret

```yaml
# basic-auth-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: basic-auth
type: kubernetes.io/basic-auth
stringData:
  username: admin
  password: secretpassword
```

---

## Part 2: Encryption at Rest

### 2.1 Encryption Configuration

```yaml
# encryption-config.yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
    providers:
      # Preferred provider (encrypt with this)
      - aescbc:
          keys:
            - name: key1
              secret: <base64-encoded-32-byte-key>
      # Fallback for reading old secrets
      - identity: {}
```

### 2.2 Enable Encryption

```bash
# Generate encryption key
head -c 32 /dev/urandom | base64

# Apply encryption config to API server
# Add flag: --encryption-provider-config=/etc/kubernetes/enc/encryption-config.yaml

# Encrypt existing secrets
kubectl get secrets --all-namespaces -o json | kubectl replace -f -

# Verify encryption
etcdctl get /registry/secrets/default/my-secret | hexdump -C
```

### 2.3 KMS Provider

```yaml
# kms-encryption-config.yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
    providers:
      - kms:
          name: aws-kms
          endpoint: unix:///var/run/kmsplugin/socket.sock
          cachesize: 1000
          timeout: 3s
      - identity: {}
```

---

## Part 3: Secret Usage Patterns

### 3.1 Environment Variables

```yaml
# secret-env.yaml
apiVersion: v1
kind: Pod
metadata:
  name: secret-env-pod
spec:
  containers:
  - name: app
    image: myapp:1.0
    env:
    # Single value
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: db-creds
          key: password
    # All values as env vars
    envFrom:
    - secretRef:
        name: app-secrets
        optional: false
```

### 3.2 Volume Mounts

```yaml
# secret-volume.yaml
apiVersion: v1
kind: Pod
metadata:
  name: secret-volume-pod
spec:
  containers:
  - name: app
    image: myapp:1.0
    volumeMounts:
    - name: secrets
      mountPath: /etc/secrets
      readOnly: true
  volumes:
  - name: secrets
    secret:
      secretName: app-secrets
      defaultMode: 0400  # Restrictive permissions
      items:
      - key: password
        path: db-password
        mode: 0400
```

### 3.3 Projected Volumes

```yaml
# projected-secrets.yaml
apiVersion: v1
kind: Pod
metadata:
  name: projected-pod
spec:
  containers:
  - name: app
    image: myapp:1.0
    volumeMounts:
    - name: all-configs
      mountPath: /etc/config
      readOnly: true
  volumes:
  - name: all-configs
    projected:
      sources:
      - secret:
          name: db-creds
          items:
          - key: password
            path: db/password
      - secret:
          name: api-keys
          items:
          - key: external-api
            path: api/external-key
      - configMap:
          name: app-config
          items:
          - key: config.yaml
            path: app/config.yaml
```

---

## Part 4: Secret Rotation

### 4.1 Manual Rotation Pattern

```bash
#!/bin/bash
# rotate-secret.sh

SECRET_NAME=$1
NAMESPACE=${2:-default}

# Generate new password
NEW_PASSWORD=$(openssl rand -base64 32)

# Update secret
kubectl create secret generic $SECRET_NAME \
  --from-literal=password=$NEW_PASSWORD \
  --dry-run=client -o yaml | kubectl apply -f -

# Trigger rolling restart
kubectl rollout restart deployment -l uses-secret=$SECRET_NAME -n $NAMESPACE

echo "Secret rotated and deployments restarted"
```

### 4.2 Dual-Secret Rotation

```yaml
# dual-secret-rotation.yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-creds-primary
type: Opaque
stringData:
  username: admin
  password: current-password
---
apiVersion: v1
kind: Secret
metadata:
  name: db-creds-secondary
type: Opaque
stringData:
  username: admin
  password: new-password
---
apiVersion: v1
kind: Pod
metadata:
  name: dual-secret-app
spec:
  containers:
  - name: app
    image: myapp:1.0
    env:
    # App tries primary, falls back to secondary
    - name: DB_PASSWORD_PRIMARY
      valueFrom:
        secretKeyRef:
          name: db-creds-primary
          key: password
    - name: DB_PASSWORD_SECONDARY
      valueFrom:
        secretKeyRef:
          name: db-creds-secondary
          key: password
```

### 4.3 Automated Rotation with CronJob

```yaml
# secret-rotation-cronjob.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: rotate-secrets
spec:
  schedule: "0 0 1 * *"  # Monthly
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: secret-rotator
          containers:
          - name: rotator
            image: bitnami/kubectl:latest
            command:
            - /bin/sh
            - -c
            - |
              # Generate new secret
              NEW_PASS=$(openssl rand -base64 32)

              # Update in database first (using psql)
              # PGPASSWORD=$OLD_PASS psql -h postgres -U admin -c "ALTER USER app PASSWORD '$NEW_PASS'"

              # Update Kubernetes secret
              kubectl create secret generic app-db-creds \
                --from-literal=password=$NEW_PASS \
                --dry-run=client -o yaml | kubectl apply -f -

              # Restart apps
              kubectl rollout restart deployment/app
          restartPolicy: OnFailure
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: secret-rotator
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secret-rotator-role
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["create", "update", "patch"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: secret-rotator-binding
subjects:
- kind: ServiceAccount
  name: secret-rotator
roleRef:
  kind: Role
  name: secret-rotator-role
  apiGroup: rbac.authorization.k8s.io
```

---

## Part 5: Secret Security Best Practices

### 5.1 RBAC for Secrets

```yaml
# secret-rbac.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secret-reader
  namespace: production
rules:
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["app-config"]  # Specific secrets only
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secret-admin
  namespace: production
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list", "create", "update", "delete"]
```

### 5.2 Network Policies for Secret Access

```yaml
# secret-network-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: restrict-secret-access
spec:
  podSelector:
    matchLabels:
      access: secrets
  policyTypes:
  - Egress
  egress:
  # Only allow connection to API server
  - to:
    - ipBlock:
        cidr: 10.0.0.1/32  # API server IP
    ports:
    - protocol: TCP
      port: 6443
```

### 5.3 Audit Logging for Secrets

```yaml
# audit-policy.yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
# Log all secret access at RequestResponse level
- level: RequestResponse
  resources:
  - group: ""
    resources: ["secrets"]
  omitStages:
  - RequestReceived
```

---

## Part 6: Sealed Secrets

### 6.1 Installing Sealed Secrets

```bash
# Install controller
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# Install kubeseal CLI
brew install kubeseal  # macOS
# or download from releases

# Fetch public key
kubeseal --fetch-cert > pub-cert.pem
```

### 6.2 Creating Sealed Secrets

```bash
# Create regular secret
kubectl create secret generic my-secret \
  --from-literal=password=supersecret \
  --dry-run=client -o yaml > secret.yaml

# Seal it
kubeseal --format=yaml < secret.yaml > sealed-secret.yaml

# Apply sealed secret (can be committed to git)
kubectl apply -f sealed-secret.yaml
```

```yaml
# sealed-secret.yaml (safe to commit)
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: my-secret
spec:
  encryptedData:
    password: AgBy3i4OJSWK+PiTySYZZA9rO43cGDEq...
```

---

## Part 7: Hands-on Challenges

### Challenge 1: Zero-Trust Secret Access

Implement a system where:
1. Secrets are encrypted at rest
2. Only specific pods can access specific secrets
3. All access is audited
4. Secrets auto-rotate monthly

### Challenge 2: Multi-Environment Secrets

Set up secrets management for:
1. Development (local secrets)
2. Staging (shared secrets)
3. Production (encrypted, rotated)
4. Consistent naming across environments

### Challenge 3: Secret Leak Detection

Build a system to:
1. Scan for secrets in logs
2. Alert on potential leaks
3. Auto-rotate compromised secrets
4. Block pods that leak secrets

---

## Verification Tasks

1. [ ] Created various secret types
2. [ ] Configured encryption at rest
3. [ ] Implemented secret rotation
4. [ ] Set up RBAC for secrets
5. [ ] Deployed Sealed Secrets
6. [ ] Enabled audit logging

---

## Key Takeaways

- Use appropriate secret types
- Enable encryption at rest
- Implement secret rotation
- Follow least privilege with RBAC
- Audit all secret access
- Use Sealed Secrets for GitOps

---

## Next Steps

Continue to [Exercise 4: External Secrets](03-configuration-secrets-exercises-04-external-secrets.md)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Secret Types
- Encryption at Rest
- Secret Usage Patterns
- Secret Rotation

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
