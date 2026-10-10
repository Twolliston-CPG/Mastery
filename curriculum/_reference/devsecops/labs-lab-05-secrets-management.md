# Lab 5: Secrets Management

## Objectives

- Deploy and configure HashiCorp Vault
- Implement dynamic secrets and credential rotation
- Integrate Vault with Kubernetes applications
- Use External Secrets Operator for GitOps-friendly secrets

## Prerequisites

- Kubernetes cluster
- Helm 3.x installed
- kubectl configured
- Basic understanding of PKI and encryption

## Duration

3 hours

## Lab Environment Setup

```bash
# Create lab namespace
kubectl create namespace vault
kubectl create namespace secrets-lab

# Add Helm repos
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo add external-secrets https://charts.external-secrets.io
helm repo update
```

## Part 1: HashiCorp Vault Setup (45 minutes)

### Task 1.1: Install Vault

```bash
# Install Vault in dev mode (for learning)
helm install vault hashicorp/vault \
  --namespace vault \
  --set "server.dev.enabled=true" \
  --set "injector.enabled=true"

# Wait for Vault to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=vault -n vault --timeout=120s

# Get Vault root token (dev mode only)
kubectl logs vault-0 -n vault | grep "Root Token"

# Port forward to access Vault UI
kubectl port-forward svc/vault 8200:8200 -n vault &

# Set environment variables
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='root'  # Dev mode token
```

### Task 1.2: Configure Vault Secrets Engines

```bash
# Enable KV secrets engine
vault secrets enable -path=secret kv-v2

# Create application secrets
vault kv put secret/app/database \
    username="app_user" \
    password="s3cr3t_p@ssw0rd" \
    host="postgres.database.svc"

vault kv put secret/app/api-keys \
    stripe_key="sk_test_abc123" \
    sendgrid_key="SG.xyz789"

# Verify secrets
vault kv get secret/app/database

# Enable versioning and get metadata
vault kv metadata get secret/app/database
```

### Task 1.3: Configure AppRole Authentication

```bash
# Enable AppRole auth method
vault auth enable approle

# Create policy for application
vault policy write app-policy - <<EOF
path "secret/data/app/*" {
  capabilities = ["read", "list"]
}

path "secret/metadata/app/*" {
  capabilities = ["list"]
}

path "database/creds/app-role" {
  capabilities = ["read"]
}
EOF

# Create AppRole
vault write auth/approle/role/app-role \
    token_policies="app-policy" \
    token_ttl=1h \
    token_max_ttl=4h \
    secret_id_ttl=720h

# Get Role ID and Secret ID
vault read auth/approle/role/app-role/role-id
vault write -f auth/approle/role/app-role/secret-id

# Store these values
ROLE_ID=$(vault read -field=role_id auth/approle/role/app-role/role-id)
SECRET_ID=$(vault write -f -field=secret_id auth/approle/role/app-role/secret-id)

# Test AppRole login
vault write auth/approle/login \
    role_id="$ROLE_ID" \
    secret_id="$SECRET_ID"
```

### Task 1.4: Configure Kubernetes Authentication

```bash
# Enable Kubernetes auth method
vault auth enable kubernetes

# Configure Kubernetes auth
vault write auth/kubernetes/config \
    kubernetes_host="https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_SERVICE_PORT" \
    kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt

# Or from outside the cluster
vault write auth/kubernetes/config \
    kubernetes_host="$(kubectl config view --raw --minify --flatten --output='jsonpath={.clusters[].cluster.server}')" \
    kubernetes_ca_cert="$(kubectl config view --raw --minify --flatten --output='jsonpath={.clusters[].cluster.certificate-authority-data}' | base64 --decode)"

# Create role for application pods
vault write auth/kubernetes/role/app \
    bound_service_account_names=app-sa \
    bound_service_account_namespaces=secrets-lab \
    policies=app-policy \
    ttl=1h
```

## Part 2: Dynamic Secrets (45 minutes)

### Task 2.1: Configure Database Secrets Engine

```bash
# Enable database secrets engine
vault secrets enable database

# Configure PostgreSQL connection
vault write database/config/postgres \
    plugin_name=postgresql-database-plugin \
    allowed_roles="app-role,readonly-role" \
    connection_url="postgresql://{{username}}:{{password}}@postgres.database.svc:5432/app?sslmode=disable" \
    username="vault_admin" \
    password="vault_admin_password"

# Create role for application
vault write database/roles/app-role \
    db_name=postgres \
    creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
        GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
    default_ttl="1h" \
    max_ttl="24h"

# Create read-only role
vault write database/roles/readonly-role \
    db_name=postgres \
    creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
        GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
    default_ttl="1h" \
    max_ttl="24h"

# Generate dynamic credentials
vault read database/creds/app-role
# Each call generates new, time-limited credentials
```

### Task 2.2: Configure AWS Secrets Engine

```bash
# Enable AWS secrets engine
vault secrets enable aws

# Configure AWS root credentials
vault write aws/config/root \
    access_key=$AWS_ACCESS_KEY_ID \
    secret_key=$AWS_SECRET_ACCESS_KEY \
    region=us-east-1

# Create IAM role for S3 access
vault write aws/roles/s3-readonly \
    credential_type=iam_user \
    policy_document=-<<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::my-bucket",
        "arn:aws:s3:::my-bucket/*"
      ]
    }
  ]
}
EOF

# Generate dynamic AWS credentials
vault read aws/creds/s3-readonly
```

### Task 2.3: PKI Secrets Engine

```bash
# Enable PKI secrets engine
vault secrets enable pki

# Set max TTL
vault secrets tune -max-lease-ttl=87600h pki

# Generate root CA
vault write -field=certificate pki/root/generate/internal \
    common_name="My Root CA" \
    issuer_name="root-2024" \
    ttl=87600h > root_ca.crt

# Enable intermediate PKI
vault secrets enable -path=pki_int pki
vault secrets tune -max-lease-ttl=43800h pki_int

# Generate intermediate CSR
vault write -format=json pki_int/intermediate/generate/internal \
    common_name="My Intermediate CA" \
    issuer_name="intermediate-2024" \
    | jq -r '.data.csr' > pki_intermediate.csr

# Sign intermediate with root
vault write -format=json pki/root/sign-intermediate \
    issuer_ref="root-2024" \
    csr=@pki_intermediate.csr \
    format=pem_bundle \
    ttl="43800h" \
    | jq -r '.data.certificate' > intermediate.cert.pem

# Set signed intermediate
vault write pki_int/intermediate/set-signed certificate=@intermediate.cert.pem

# Create role for issuing certificates
vault write pki_int/roles/app-certs \
    allowed_domains="svc.cluster.local,app.company.com" \
    allow_subdomains=true \
    max_ttl="720h"

# Issue certificate
vault write pki_int/issue/app-certs \
    common_name="myapp.svc.cluster.local" \
    ttl="24h"
```

## Part 3: Vault Agent Integration (45 minutes)

### Task 3.1: Create Application with Vault Agent Sidecar

```yaml
# app/deployment-vault-agent.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-sa
  namespace: secrets-lab
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-with-vault
  namespace: secrets-lab
spec:
  replicas: 1
  selector:
    matchLabels:
      app: app-with-vault
  template:
    metadata:
      labels:
        app: app-with-vault
      annotations:
        vault.hashicorp.com/agent-inject: "true"
        vault.hashicorp.com/role: "app"
        vault.hashicorp.com/agent-inject-secret-database.txt: "secret/data/app/database"
        vault.hashicorp.com/agent-inject-template-database.txt: |
          {{- with secret "secret/data/app/database" -}}
          DATABASE_URL=postgresql://{{ .Data.data.username }}:{{ .Data.data.password }}@{{ .Data.data.host }}:5432/app
          {{- end }}
        vault.hashicorp.com/agent-inject-secret-api-keys.json: "secret/data/app/api-keys"
        vault.hashicorp.com/agent-inject-template-api-keys.json: |
          {{- with secret "secret/data/app/api-keys" -}}
          {
            "stripe_key": "{{ .Data.data.stripe_key }}",
            "sendgrid_key": "{{ .Data.data.sendgrid_key }}"
          }
          {{- end }}
    spec:
      serviceAccountName: app-sa
      containers:
      - name: app
        image: busybox:1.35
        command: ["sh", "-c", "while true; do cat /vault/secrets/database.txt; sleep 60; done"]
        volumeMounts:
        - name: secrets
          mountPath: /vault/secrets
          readOnly: true
      volumes:
      - name: secrets
        emptyDir:
          medium: Memory
```

### Task 3.2: Dynamic Database Credentials with Vault Agent

```yaml
# app/deployment-dynamic-creds.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-dynamic-creds
  namespace: secrets-lab
spec:
  replicas: 1
  selector:
    matchLabels:
      app: app-dynamic-creds
  template:
    metadata:
      labels:
        app: app-dynamic-creds
      annotations:
        vault.hashicorp.com/agent-inject: "true"
        vault.hashicorp.com/role: "app"
        vault.hashicorp.com/agent-inject-secret-db-creds: "database/creds/app-role"
        vault.hashicorp.com/agent-inject-template-db-creds: |
          {{- with secret "database/creds/app-role" -}}
          export DB_USERNAME="{{ .Data.username }}"
          export DB_PASSWORD="{{ .Data.password }}"
          {{- end }}
        # Auto-renew credentials before expiry
        vault.hashicorp.com/agent-cache-enable: "true"
        vault.hashicorp.com/agent-run-as-user: "1000"
    spec:
      serviceAccountName: app-sa
      containers:
      - name: app
        image: postgres:15
        command: ["sh", "-c", "source /vault/secrets/db-creds && psql -h postgres -U $DB_USERNAME"]
```

## Part 4: External Secrets Operator (45 minutes)

### Task 4.1: Install External Secrets Operator

```bash
# Install External Secrets Operator
helm install external-secrets external-secrets/external-secrets \
  --namespace external-secrets \
  --create-namespace

# Wait for deployment
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=external-secrets -n external-secrets --timeout=120s
```

### Task 4.2: Configure SecretStore

```yaml
# external-secrets/vault-secret-store.yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
  namespace: secrets-lab
spec:
  provider:
    vault:
      server: "http://vault.vault.svc:8200"
      path: "secret"
      version: "v2"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "app"
          serviceAccountRef:
            name: "app-sa"
---
# Cluster-wide secret store
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: vault-cluster-store
spec:
  provider:
    vault:
      server: "http://vault.vault.svc:8200"
      path: "secret"
      version: "v2"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "app"
          serviceAccountRef:
            name: "app-sa"
            namespace: "secrets-lab"
```

### Task 4.3: Create ExternalSecrets

```yaml
# external-secrets/database-external-secret.yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: database-credentials
  namespace: secrets-lab
spec:
  refreshInterval: "1h"
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: database-credentials
    creationPolicy: Owner
    template:
      type: Opaque
      data:
        DATABASE_URL: "postgresql://{{ .username }}:{{ .password }}@{{ .host }}:5432/app"
  data:
  - secretKey: username
    remoteRef:
      key: app/database
      property: username
  - secretKey: password
    remoteRef:
      key: app/database
      property: password
  - secretKey: host
    remoteRef:
      key: app/database
      property: host
---
# external-secrets/api-keys-external-secret.yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: api-keys
  namespace: secrets-lab
spec:
  refreshInterval: "1h"
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: api-keys
    creationPolicy: Owner
  dataFrom:
  - extract:
      key: app/api-keys
```

### Task 4.4: Use Secrets in Application

```yaml
# app/deployment-external-secrets.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-with-external-secrets
  namespace: secrets-lab
spec:
  replicas: 1
  selector:
    matchLabels:
      app: app-external-secrets
  template:
    metadata:
      labels:
        app: app-external-secrets
    spec:
      containers:
      - name: app
        image: nginx:1.25
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: database-credentials
              key: DATABASE_URL
        - name: STRIPE_KEY
          valueFrom:
            secretKeyRef:
              name: api-keys
              key: stripe_key
        - name: SENDGRID_KEY
          valueFrom:
            secretKeyRef:
              name: api-keys
              key: sendgrid_key
```

### Task 4.5: AWS Secrets Manager Integration

```yaml
# external-secrets/aws-secret-store.yaml
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: aws-secrets-manager
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets-sa
            namespace: external-secrets
---
# external-secrets/aws-external-secret.yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: aws-database-secret
  namespace: secrets-lab
spec:
  refreshInterval: "1h"
  secretStoreRef:
    name: aws-secrets-manager
    kind: ClusterSecretStore
  target:
    name: aws-database-secret
    creationPolicy: Owner
  data:
  - secretKey: password
    remoteRef:
      key: prod/database/credentials
      property: password
```

## Part 5: Secrets Rotation (30 minutes)

### Task 5.1: Automatic Rotation with Vault

```bash
# Configure automatic rotation for database
vault write database/config/postgres \
    plugin_name=postgresql-database-plugin \
    allowed_roles="*" \
    connection_url="postgresql://{{username}}:{{password}}@postgres:5432/app" \
    username="vault_admin" \
    password="initial_password" \
    password_policy="app-password-policy"

# Create password policy
vault write sys/policies/password/app-password-policy policy=-<<EOF
length=32
rule "charset" {
  charset = "abcdefghijklmnopqrstuvwxyz"
  min-chars = 5
}
rule "charset" {
  charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
  min-chars = 5
}
rule "charset" {
  charset = "0123456789"
  min-chars = 5
}
rule "charset" {
  charset = "!@#$%^&*"
  min-chars = 2
}
EOF

# Rotate root credentials
vault write -force database/rotate-root/postgres
```

### Task 5.2: External Secrets Rotation

```yaml
# external-secrets/rotating-secret.yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: rotating-api-key
  namespace: secrets-lab
spec:
  # Short refresh interval for rotation
  refreshInterval: "5m"
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: rotating-api-key
    creationPolicy: Owner
    # Delete the secret if ExternalSecret is deleted
    deletionPolicy: Delete
    template:
      metadata:
        annotations:
          # Trigger pod restart on secret change
          reloader.stakater.com/match: "true"
  data:
  - secretKey: api-key
    remoteRef:
      key: app/rotating-key
      property: key
```

## Verification

Complete the following checklist:

- [ ] Installed and configured Vault
- [ ] Created static secrets in KV engine
- [ ] Configured AppRole authentication
- [ ] Configured Kubernetes authentication
- [ ] Set up dynamic database credentials
- [ ] Deployed application with Vault Agent sidecar
- [ ] Installed External Secrets Operator
- [ ] Created SecretStore and ExternalSecrets
- [ ] Verified secrets are synced to Kubernetes
- [ ] Tested secrets rotation

## Challenge Tasks

1. **Transit Encryption**: Use Vault's Transit secrets engine for application-level encryption

2. **SSH Certificates**: Configure Vault to issue SSH certificates for server access

3. **Multi-Cluster Secrets**: Set up secrets synchronization across multiple Kubernetes clusters

## Summary

In this lab, you:
- Deployed and configured HashiCorp Vault
- Implemented static and dynamic secrets
- Integrated Vault with Kubernetes using multiple methods
- Used External Secrets Operator for GitOps workflows
- Implemented automatic secrets rotation

## Next Steps

- Lab 6: Security Scanning Pipeline
- Review Vault Security Best Practices
- Study NIST Guidelines for Secrets Management

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- HashiCorp Vault Setup
- Dynamic Secrets
- Vault Agent Integration
- External Secrets Operator

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"We scan for vulnerabilities in the pipeline."* |
| ✓ | *"SAST reads source without running it, SCA resolves the dependency tree against an advisory database, and image scanning compares installed package versions to that same database. All three report what was known at build time — which is why the registry is re-scanned: the image does not change, the database does."* |

**Trace it:** A CVE published today against your base image → a blocked deploy. Name every component between the advisory and the refused `apply`.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** the [SLSA threat model](https://slsa.dev/spec/v1.2/threats) — it names every point at which a build can be subverted, and most teams defend three of them.
Full list per domain: [`SOURCES.md`](../SOURCES.md#devsecops)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../MASTERY.md)

<!-- /feynman-check -->
