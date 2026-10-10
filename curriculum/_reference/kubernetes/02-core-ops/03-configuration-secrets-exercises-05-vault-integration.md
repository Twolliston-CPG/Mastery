# Exercise 5: HashiCorp Vault Integration

## Objectives

- Deploy Vault in Kubernetes
- Configure Kubernetes authentication
- Implement the Vault Agent Injector
- Use dynamic secrets

## Prerequisites

- Completed Exercises 1-4
- Understanding of Vault concepts
- Helm installed

---

## Part 1: Vault Deployment

### 1.1 Install Vault with Helm

```bash
# Add HashiCorp repo
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

# Install Vault
helm install vault hashicorp/vault \
  --namespace vault \
  --create-namespace \
  --set server.dev.enabled=true  # Dev mode for learning

# Production installation
helm install vault hashicorp/vault \
  --namespace vault \
  --create-namespace \
  --values vault-values.yaml
```

### 1.2 Production Vault Values

```yaml
# vault-values.yaml
global:
  enabled: true

server:
  # High availability
  ha:
    enabled: true
    replicas: 3
    raft:
      enabled: true
      setNodeId: true

  # Resources
  resources:
    requests:
      memory: 256Mi
      cpu: 250m
    limits:
      memory: 512Mi
      cpu: 500m

  # Storage
  dataStorage:
    enabled: true
    size: 10Gi
    storageClass: fast-ssd

  # Audit logging
  auditStorage:
    enabled: true
    size: 10Gi

  # Service
  service:
    type: ClusterIP

  # Ingress
  ingress:
    enabled: true
    ingressClassName: nginx
    hosts:
    - host: vault.example.com

injector:
  enabled: true
  replicas: 2

ui:
  enabled: true
```

### 1.3 Initialize and Unseal

```bash
# Initialize Vault
kubectl exec -n vault vault-0 -- vault operator init \
  -key-shares=5 \
  -key-threshold=3 \
  -format=json > vault-keys.json

# Unseal (repeat for each pod in HA)
kubectl exec -n vault vault-0 -- vault operator unseal <key1>
kubectl exec -n vault vault-0 -- vault operator unseal <key2>
kubectl exec -n vault vault-0 -- vault operator unseal <key3>

# Check status
kubectl exec -n vault vault-0 -- vault status
```

---

## Part 2: Kubernetes Authentication

### 2.1 Enable Kubernetes Auth

```bash
# Port forward to Vault
kubectl port-forward -n vault svc/vault 8200:8200 &

# Login with root token
export VAULT_ADDR='http://127.0.0.1:8200'
vault login <root-token>

# Enable Kubernetes auth
vault auth enable kubernetes

# Configure Kubernetes auth
vault write auth/kubernetes/config \
  kubernetes_host="https://kubernetes.default.svc:443" \
  kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
```

### 2.2 Create Vault Policy

```bash
# Create policy
vault policy write myapp-policy - <<EOF
path "secret/data/myapp/*" {
  capabilities = ["read"]
}

path "database/creds/myapp-role" {
  capabilities = ["read"]
}
EOF
```

### 2.3 Create Kubernetes Role

```bash
# Create role for service account
vault write auth/kubernetes/role/myapp \
  bound_service_account_names=myapp-sa \
  bound_service_account_namespaces=default \
  policies=myapp-policy \
  ttl=1h
```

### 2.4 Service Account Setup

```yaml
# vault-serviceaccount.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: myapp-sa
  namespace: default
  annotations:
    # For Vault Agent Injector
    vault.hashicorp.com/agent-inject: "true"
```

---

## Part 3: Vault Agent Injector

### 3.1 Basic Injection

```yaml
# injected-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 1
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
      annotations:
        vault.hashicorp.com/agent-inject: "true"
        vault.hashicorp.com/role: "myapp"
        vault.hashicorp.com/agent-inject-secret-database: "secret/data/myapp/database"
    spec:
      serviceAccountName: myapp-sa
      containers:
      - name: app
        image: myapp:1.0
        # Secrets available at /vault/secrets/database
```

### 3.2 Custom Templates

```yaml
# templated-injection.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-templated
spec:
  template:
    metadata:
      annotations:
        vault.hashicorp.com/agent-inject: "true"
        vault.hashicorp.com/role: "myapp"

        # Custom template for config file
        vault.hashicorp.com/agent-inject-secret-config: "secret/data/myapp/database"
        vault.hashicorp.com/agent-inject-template-config: |
          {{- with secret "secret/data/myapp/database" -}}
          database:
            host: {{ .Data.data.host }}
            port: {{ .Data.data.port }}
            username: {{ .Data.data.username }}
            password: {{ .Data.data.password }}
          {{- end }}

        # Render as JSON
        vault.hashicorp.com/agent-inject-secret-creds: "secret/data/myapp/api"
        vault.hashicorp.com/agent-inject-template-creds: |
          {{- with secret "secret/data/myapp/api" -}}
          {
            "api_key": "{{ .Data.data.key }}",
            "api_secret": "{{ .Data.data.secret }}"
          }
          {{- end }}
```

### 3.3 Environment Variables via Template

```yaml
# env-injection.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-env
spec:
  template:
    metadata:
      annotations:
        vault.hashicorp.com/agent-inject: "true"
        vault.hashicorp.com/role: "myapp"
        vault.hashicorp.com/agent-inject-secret-env: "secret/data/myapp/env"
        vault.hashicorp.com/agent-inject-template-env: |
          {{- with secret "secret/data/myapp/env" -}}
          export DB_HOST="{{ .Data.data.db_host }}"
          export DB_USER="{{ .Data.data.db_user }}"
          export DB_PASS="{{ .Data.data.db_pass }}"
          {{- end }}
    spec:
      serviceAccountName: myapp-sa
      containers:
      - name: app
        image: myapp:1.0
        command: ["/bin/sh", "-c"]
        args:
        - source /vault/secrets/env && /app/start.sh
```

---

## Part 4: Dynamic Secrets

### 4.1 Database Secrets Engine

```bash
# Enable database secrets engine
vault secrets enable database

# Configure PostgreSQL connection
vault write database/config/postgresql \
  plugin_name=postgresql-database-plugin \
  allowed_roles="myapp-role" \
  connection_url="postgresql://{{username}}:{{password}}@postgres:5432/mydb?sslmode=disable" \
  username="vault" \
  password="vault-password"

# Create role for dynamic credentials
vault write database/roles/myapp-role \
  db_name=postgresql \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
    GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
  revocation_statements="DROP ROLE IF EXISTS \"{{name}}\";" \
  default_ttl="1h" \
  max_ttl="24h"
```

### 4.2 Using Dynamic Database Credentials

```yaml
# dynamic-db-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-dynamic-db
spec:
  template:
    metadata:
      annotations:
        vault.hashicorp.com/agent-inject: "true"
        vault.hashicorp.com/role: "myapp"

        # Dynamic credentials with auto-renewal
        vault.hashicorp.com/agent-inject-secret-db-creds: "database/creds/myapp-role"
        vault.hashicorp.com/agent-inject-template-db-creds: |
          {{- with secret "database/creds/myapp-role" -}}
          {
            "username": "{{ .Data.username }}",
            "password": "{{ .Data.password }}"
          }
          {{- end }}

        # Enable auto-auth token renewal
        vault.hashicorp.com/agent-pre-populate-only: "false"
```

### 4.3 AWS Secrets Engine

```bash
# Enable AWS secrets engine
vault secrets enable aws

# Configure AWS
vault write aws/config/root \
  access_key=$AWS_ACCESS_KEY \
  secret_key=$AWS_SECRET_KEY \
  region=us-west-2

# Create role
vault write aws/roles/myapp-s3 \
  credential_type=iam_user \
  policy_document=-<<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:*",
      "Resource": ["arn:aws:s3:::my-bucket", "arn:aws:s3:::my-bucket/*"]
    }
  ]
}
EOF
```

---

## Part 5: PKI Secrets Engine

### 5.1 Configure PKI

```bash
# Enable PKI
vault secrets enable pki

# Configure max TTL
vault secrets tune -max-lease-ttl=87600h pki

# Generate root CA
vault write -field=certificate pki/root/generate/internal \
  common_name="My Root CA" \
  ttl=87600h > CA_cert.crt

# Configure URLs
vault write pki/config/urls \
  issuing_certificates="http://vault.vault.svc:8200/v1/pki/ca" \
  crl_distribution_points="http://vault.vault.svc:8200/v1/pki/crl"

# Create role for issuing certificates
vault write pki/roles/myapp \
  allowed_domains="myapp.svc.cluster.local,myapp.default.svc" \
  allow_subdomains=true \
  max_ttl=72h
```

### 5.2 Using PKI with Injector

```yaml
# pki-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-tls
spec:
  template:
    metadata:
      annotations:
        vault.hashicorp.com/agent-inject: "true"
        vault.hashicorp.com/role: "myapp"

        # Inject certificate
        vault.hashicorp.com/agent-inject-secret-tls: "pki/issue/myapp"
        vault.hashicorp.com/agent-inject-template-tls: |
          {{- with secret "pki/issue/myapp" "common_name=myapp.default.svc" -}}
          {{ .Data.certificate }}
          {{ .Data.ca_chain }}
          {{- end }}

        # Inject private key
        vault.hashicorp.com/agent-inject-secret-key: "pki/issue/myapp"
        vault.hashicorp.com/agent-inject-template-key: |
          {{- with secret "pki/issue/myapp" "common_name=myapp.default.svc" -}}
          {{ .Data.private_key }}
          {{- end }}
```

---

## Part 6: Vault CSI Provider

### 6.1 Install CSI Provider

```bash
# Install Vault CSI provider
helm install vault hashicorp/vault \
  --namespace vault \
  --set "server.enabled=false" \
  --set "injector.enabled=false" \
  --set "csi.enabled=true"
```

### 6.2 SecretProviderClass

```yaml
# vault-secretproviderclass.yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: vault-database
spec:
  provider: vault
  parameters:
    vaultAddress: "http://vault.vault.svc:8200"
    roleName: "myapp"
    objects: |
      - objectName: "db-password"
        secretPath: "secret/data/myapp/database"
        secretKey: "password"
      - objectName: "db-username"
        secretPath: "secret/data/myapp/database"
        secretKey: "username"
  secretObjects:
  - secretName: vault-db-creds
    type: Opaque
    data:
    - objectName: db-password
      key: password
    - objectName: db-username
      key: username
```

### 6.3 Using CSI Volume

```yaml
# csi-volume-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: vault-csi-demo
spec:
  serviceAccountName: myapp-sa
  containers:
  - name: app
    image: myapp:1.0
    volumeMounts:
    - name: secrets
      mountPath: /mnt/secrets
      readOnly: true
    env:
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: vault-db-creds
          key: password
  volumes:
  - name: secrets
    csi:
      driver: secrets-store.csi.k8s.io
      readOnly: true
      volumeAttributes:
        secretProviderClass: vault-database
```

---

## Part 7: Hands-on Challenges

### Challenge 1: Complete Vault Setup

Deploy production Vault with:
1. HA with Raft storage
2. Auto-unseal with cloud KMS
3. Audit logging enabled
4. TLS enabled

### Challenge 2: Zero-Trust Application

Create an application that:
1. Uses dynamic database credentials
2. Auto-renews credentials before expiry
3. Uses PKI for mTLS
4. Rotates all secrets automatically

### Challenge 3: Multi-Cluster Vault

Configure Vault for multiple clusters:
1. Single Vault serving multiple clusters
2. Namespace isolation
3. Cluster-specific policies
4. Cross-cluster secret sync

---

## Verification Tasks

1. [ ] Deployed Vault in Kubernetes
2. [ ] Configured Kubernetes auth
3. [ ] Used Agent Injector for secrets
4. [ ] Implemented dynamic database credentials
5. [ ] Configured PKI for certificates
6. [ ] Tested CSI provider

---

## Key Takeaways

- Vault provides centralized secrets management
- Kubernetes auth enables pod authentication
- Agent Injector transparently provides secrets
- Dynamic secrets reduce exposure risk
- PKI engine automates certificate management
- Multiple integration options (injector, CSI, ESO)

---

## Module Complete!

You've completed the Configuration & Secrets module. Continue to:
- [Phase 3: Production Readiness](../../phase-3-production-readiness/README.md)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Vault Deployment
- Kubernetes Authentication
- Vault Agent Injector
- Dynamic Secrets

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
