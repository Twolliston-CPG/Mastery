# Lab 11: Kubernetes Configuration Management

## Objectives

- Create and use ConfigMaps for application configuration
- Manage sensitive data with Secrets
- Implement Sealed Secrets for GitOps workflows
- Use External Secrets for centralized secret management

## Prerequisites

- Completed Lab 10
- Running Kubernetes cluster
- kubectl configured

---

## Part 1: ConfigMaps (Guided)

### Step 1: Create ConfigMaps

```bash
# From literal values
kubectl create configmap app-config \
  --from-literal=APP_ENV=production \
  --from-literal=LOG_LEVEL=info \
  --from-literal=MAX_CONNECTIONS=100

# View ConfigMap
kubectl get configmap app-config -o yaml
kubectl describe configmap app-config
```

```bash
# From file
cat > config.properties << 'EOF'
database.host=postgres
database.port=5432
database.name=myapp
cache.enabled=true
cache.ttl=3600
EOF

kubectl create configmap file-config --from-file=config.properties

# View
kubectl get configmap file-config -o yaml
```

```yaml
# From YAML manifest
# configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: webapp-config
data:
  # Simple key-value
  APP_NAME: "My Application"
  APP_VERSION: "1.0.0"

  # Multi-line configuration file
  nginx.conf: |
    server {
        listen 80;
        server_name localhost;

        location / {
            root /usr/share/nginx/html;
            index index.html;
        }

        location /api {
            proxy_pass http://api-service:8080;
        }
    }

  # JSON configuration
  app-settings.json: |
    {
      "features": {
        "darkMode": true,
        "analytics": false
      },
      "api": {
        "timeout": 30,
        "retries": 3
      }
    }
```

```bash
kubectl apply -f configmap.yaml
kubectl get configmap webapp-config -o yaml
```

### Step 2: Use ConfigMaps in Pods

```yaml
# pod-configmap.yaml
apiVersion: v1
kind: Pod
metadata:
  name: configmap-demo
spec:
  containers:
  - name: app
    image: nginx:alpine

    # Environment variables from ConfigMap
    env:
    - name: APPLICATION_NAME
      valueFrom:
        configMapKeyRef:
          name: webapp-config
          key: APP_NAME
    - name: APPLICATION_VERSION
      valueFrom:
        configMapKeyRef:
          name: webapp-config
          key: APP_VERSION

    # All keys as environment variables
    envFrom:
    - configMapRef:
        name: app-config
        # Optional prefix
        # prefix: CONFIG_

    # Mount as files
    volumeMounts:
    - name: config-volume
      mountPath: /etc/nginx/conf.d
      readOnly: true
    - name: settings-volume
      mountPath: /app/config
      readOnly: true

  volumes:
  - name: config-volume
    configMap:
      name: webapp-config
      items:
      - key: nginx.conf
        path: default.conf
  - name: settings-volume
    configMap:
      name: webapp-config
      items:
      - key: app-settings.json
        path: settings.json
```

```bash
kubectl apply -f pod-configmap.yaml

# Verify environment variables
kubectl exec configmap-demo -- env | grep -E "APP|LOG|MAX"

# Verify mounted files
kubectl exec configmap-demo -- cat /etc/nginx/conf.d/default.conf
kubectl exec configmap-demo -- cat /app/config/settings.json
```

### Step 3: ConfigMap Updates

```bash
# Update ConfigMap
kubectl patch configmap app-config -p '{"data":{"LOG_LEVEL":"debug"}}'

# ConfigMaps mounted as volumes are updated automatically (may take ~1 min)
# Environment variables require pod restart

# Watch for changes
kubectl exec configmap-demo -- cat /etc/nginx/conf.d/default.conf

# Force pod restart to update env vars
kubectl delete pod configmap-demo
kubectl apply -f pod-configmap.yaml
```

### Validation

```bash
#!/bin/bash
# validate-part1.sh

echo "=== Part 1 Validation ==="

# Check ConfigMaps exist
for CM in app-config file-config webapp-config; do
    if kubectl get configmap $CM &> /dev/null; then
        echo "✓ ConfigMap $CM exists"
    else
        echo "✗ ConfigMap $CM not found"
    fi
done

# Check environment variables in pod
APP_NAME=$(kubectl exec configmap-demo -- printenv APPLICATION_NAME 2>/dev/null)
if [ "$APP_NAME" = "My Application" ]; then
    echo "✓ Environment variable from ConfigMap works"
else
    echo "✗ Environment variable not set correctly"
fi

# Check mounted file
if kubectl exec configmap-demo -- cat /etc/nginx/conf.d/default.conf 2>/dev/null | grep -q "server"; then
    echo "✓ ConfigMap mounted as file"
else
    echo "✗ ConfigMap file mount failed"
fi

echo "Part 1 validation complete!"
```

---

## Part 2: Secrets (Semi-Guided)

### Objective

Manage sensitive data using Kubernetes Secrets.

### Tasks

1. Create Secrets using different methods
2. Use Secrets in pods
3. Understand Secret types

### Create Secrets

```bash
# From literal (values are base64 encoded automatically)
kubectl create secret generic db-credentials \
  --from-literal=username=admin \
  --from-literal=password='S3cur3P@ss!'

# View (data is base64 encoded)
kubectl get secret db-credentials -o yaml

# Decode secret
kubectl get secret db-credentials -o jsonpath='{.data.password}' | base64 -d
```

```bash
# From file
echo -n 'admin' > ./username
echo -n 'S3cur3P@ss!' > ./password

kubectl create secret generic file-secret \
  --from-file=username=./username \
  --from-file=password=./password

rm ./username ./password
```

```yaml
# From YAML (values must be base64 encoded)
# secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
type: Opaque
data:
  # echo -n 'myuser' | base64
  DB_USER: bXl1c2Vy
  # echo -n 'mypassword' | base64
  DB_PASSWORD: bXlwYXNzd29yZA==
  # API key
  API_KEY: c2VjcmV0LWFwaS1rZXktMTIzNDU=
---
# Using stringData (plain text, encoded on apply)
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets-plain
type: Opaque
stringData:
  DB_USER: myuser
  DB_PASSWORD: mypassword
  API_KEY: secret-api-key-12345
```

### Secret Types

```yaml
# Docker registry secret
apiVersion: v1
kind: Secret
metadata:
  name: docker-registry-secret
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: eyJhdXRocyI6eyJodHRwczovL2luZGV4LmRvY2tlci5pby92MS8iOnsidXNlcm5hbWUiOiJ1c2VyIiwicGFzc3dvcmQiOiJwYXNzIiwiYXV0aCI6ImRYTmxjanB3WVhOeiJ9fX0=
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
# Basic auth secret
apiVersion: v1
kind: Secret
metadata:
  name: basic-auth
type: kubernetes.io/basic-auth
stringData:
  username: admin
  password: secret123
```

```bash
# Create TLS secret from files
kubectl create secret tls my-tls-secret \
  --cert=tls.crt \
  --key=tls.key

# Create docker registry secret
kubectl create secret docker-registry my-registry \
  --docker-server=registry.example.com \
  --docker-username=user \
  --docker-password=password \
  --docker-email=user@example.com
```

### Use Secrets in Pods

```yaml
# pod-secrets.yaml
apiVersion: v1
kind: Pod
metadata:
  name: secret-demo
spec:
  containers:
  - name: app
    image: nginx:alpine

    # Single secret as env var
    env:
    - name: DATABASE_PASSWORD
      valueFrom:
        secretKeyRef:
          name: db-credentials
          key: password

    # All secrets as env vars
    envFrom:
    - secretRef:
        name: app-secrets

    # Mount as files
    volumeMounts:
    - name: secrets-volume
      mountPath: /etc/secrets
      readOnly: true

  volumes:
  - name: secrets-volume
    secret:
      secretName: db-credentials
      defaultMode: 0400  # Read-only for owner
      items:
      - key: username
        path: db-username
      - key: password
        path: db-password

  # Use registry secret for private images
  imagePullSecrets:
  - name: docker-registry-secret
```

```bash
kubectl apply -f secret.yaml
kubectl apply -f pod-secrets.yaml

# Verify
kubectl exec secret-demo -- env | grep -E "DB_|API_"
kubectl exec secret-demo -- cat /etc/secrets/db-password

# Check file permissions
kubectl exec secret-demo -- ls -la /etc/secrets/
```

### Validation

```bash
#!/bin/bash
# validate-part2.sh

echo "=== Part 2 Validation ==="

# Check Secrets exist
for SECRET in db-credentials app-secrets; do
    if kubectl get secret $SECRET &> /dev/null; then
        TYPE=$(kubectl get secret $SECRET -o jsonpath='{.type}')
        echo "✓ Secret $SECRET exists (type: $TYPE)"
    else
        echo "✗ Secret $SECRET not found"
    fi
done

# Check secret is not visible in plain text via kubectl get
OUTPUT=$(kubectl get secret db-credentials -o yaml)
if echo "$OUTPUT" | grep -q "password: S3cur3P@ss!"; then
    echo "✗ Secret visible in plain text (encoding issue)"
else
    echo "✓ Secret properly encoded"
fi

# Verify secret in pod
PASSWORD=$(kubectl exec secret-demo -- cat /etc/secrets/db-password 2>/dev/null)
if [ "$PASSWORD" = "S3cur3P@ss!" ]; then
    echo "✓ Secret mounted correctly in pod"
else
    echo "✗ Secret mount failed"
fi

echo "Part 2 validation complete!"
```

---

## Part 3: Sealed Secrets (Semi-Guided)

### Objective

Use Sealed Secrets for secure GitOps workflows.

### Tasks

1. Install Sealed Secrets controller
2. Encrypt secrets for Git storage
3. Manage secret lifecycle

### Install Sealed Secrets

```bash
# Install controller
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# Wait for controller
kubectl wait --for=condition=ready pod -l name=sealed-secrets-controller -n kube-system --timeout=120s

# Install kubeseal CLI (Linux)
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/kubeseal-0.24.0-linux-amd64.tar.gz
tar xzf kubeseal-0.24.0-linux-amd64.tar.gz
sudo mv kubeseal /usr/local/bin/

# Verify
kubeseal --version
```

### Create Sealed Secret

```bash
# Create a regular secret YAML (don't apply!)
cat > my-secret.yaml << 'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: my-sealed-secret
  namespace: default
type: Opaque
stringData:
  username: admin
  password: supersecretpassword123
EOF

# Seal the secret
kubeseal --format yaml < my-secret.yaml > my-sealed-secret.yaml

# View sealed secret (safe to commit to Git)
cat my-sealed-secret.yaml

# Apply sealed secret
kubectl apply -f my-sealed-secret.yaml

# Controller decrypts to regular secret
kubectl get secret my-sealed-secret
kubectl get secret my-sealed-secret -o jsonpath='{.data.password}' | base64 -d

# Clean up plain secret file
rm my-secret.yaml
```

### Sealed Secret Scopes

```bash
# Strict scope (default) - secret name and namespace must match
kubeseal --format yaml < secret.yaml > sealed.yaml

# Namespace-wide scope - can change secret name within namespace
kubeseal --format yaml --scope namespace-wide < secret.yaml > sealed.yaml

# Cluster-wide scope - can be used anywhere
kubeseal --format yaml --scope cluster-wide < secret.yaml > sealed.yaml
```

### Update Sealed Secret

```bash
# Fetch current public key
kubeseal --fetch-cert > pub-cert.pem

# Create new secret value
echo -n "newpassword456" | kubectl create secret generic temp-secret \
  --dry-run=client \
  --from-file=password=/dev/stdin \
  -o yaml | kubeseal --cert pub-cert.pem --merge-into my-sealed-secret.yaml

# Apply updated sealed secret
kubectl apply -f my-sealed-secret.yaml
```

### Validation

```bash
#!/bin/bash
# validate-part3.sh

echo "=== Part 3 Validation ==="

# Check Sealed Secrets controller
if kubectl get deployment sealed-secrets-controller -n kube-system &> /dev/null; then
    READY=$(kubectl get deployment sealed-secrets-controller -n kube-system -o jsonpath='{.status.readyReplicas}')
    echo "✓ Sealed Secrets controller running (replicas: $READY)"
else
    echo "✗ Sealed Secrets controller not found"
fi

# Check kubeseal CLI
if command -v kubeseal &> /dev/null; then
    VERSION=$(kubeseal --version)
    echo "✓ kubeseal installed: $VERSION"
else
    echo "✗ kubeseal not installed"
fi

# Check sealed secret was decrypted
if kubectl get secret my-sealed-secret &> /dev/null; then
    echo "✓ Sealed secret decrypted to regular secret"

    # Verify value
    PASSWORD=$(kubectl get secret my-sealed-secret -o jsonpath='{.data.password}' | base64 -d)
    if [ -n "$PASSWORD" ]; then
        echo "✓ Secret value accessible"
    fi
else
    echo "✗ Secret not found"
fi

echo "Part 3 validation complete!"
```

---

## Part 4: External Secrets (Semi-Guided)

### Objective

Use External Secrets Operator for centralized secret management.

### Tasks

1. Install External Secrets Operator
2. Configure AWS Secrets Manager (or other backend)
3. Sync external secrets to Kubernetes

### Install External Secrets Operator

```bash
# Add Helm repo
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

# Install
helm install external-secrets \
  external-secrets/external-secrets \
  -n external-secrets \
  --create-namespace \
  --wait

# Verify
kubectl get pods -n external-secrets
```

### Configure Secret Store (AWS Example)

```yaml
# aws-secret-store.yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secrets-manager
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1
      auth:
        secretRef:
          accessKeyIDSecretRef:
            name: aws-credentials
            key: access-key-id
          secretAccessKeySecretRef:
            name: aws-credentials
            key: secret-access-key
---
# Create AWS credentials secret first
apiVersion: v1
kind: Secret
metadata:
  name: aws-credentials
type: Opaque
stringData:
  access-key-id: AKIAIOSFODNN7EXAMPLE
  secret-access-key: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```

### Configure Secret Store (Vault Example)

```yaml
# vault-secret-store.yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
spec:
  provider:
    vault:
      server: "https://vault.example.com"
      path: "secret"
      version: "v2"
      auth:
        tokenSecretRef:
          name: vault-token
          key: token
```

### Configure ClusterSecretStore (Cluster-wide)

```yaml
# cluster-secret-store.yaml
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: global-secrets
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
```

### Create External Secret

```yaml
# external-secret.yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: database-credentials
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: SecretStore
  target:
    name: db-secret
    creationPolicy: Owner
    template:
      type: Opaque
      data:
        # Transform if needed
        connection-string: "postgresql://{{ .username }}:{{ .password }}@db.example.com:5432/mydb"
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

### Sync Multiple Secrets

```yaml
# external-secret-find.yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: all-app-secrets
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: SecretStore
  target:
    name: app-secrets
  dataFrom:
  - find:
      name:
        regexp: "^myapp/.*"
```

### Local Testing with Fake Provider

```yaml
# For testing without cloud provider
# fake-store.yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: fake-store
spec:
  provider:
    fake:
      data:
      - key: "/fake/database"
        value: '{"username": "admin", "password": "fakepassword123"}'
      - key: "/fake/api-key"
        value: "fake-api-key-12345"
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: fake-external-secret
spec:
  refreshInterval: 1m
  secretStoreRef:
    name: fake-store
    kind: SecretStore
  target:
    name: synced-secret
  data:
  - secretKey: db-username
    remoteRef:
      key: /fake/database
      property: username
  - secretKey: db-password
    remoteRef:
      key: /fake/database
      property: password
  - secretKey: api-key
    remoteRef:
      key: /fake/api-key
```

```bash
kubectl apply -f fake-store.yaml

# Check sync status
kubectl get externalsecret
kubectl describe externalsecret fake-external-secret

# View synced secret
kubectl get secret synced-secret
kubectl get secret synced-secret -o jsonpath='{.data.db-password}' | base64 -d
```

### Validation

```bash
#!/bin/bash
# validate-part4.sh

echo "=== Part 4 Validation ==="

# Check External Secrets Operator
if kubectl get deployment external-secrets -n external-secrets &> /dev/null; then
    READY=$(kubectl get deployment external-secrets -n external-secrets -o jsonpath='{.status.readyReplicas}')
    echo "✓ External Secrets Operator running (replicas: $READY)"
else
    echo "! External Secrets Operator not installed (optional)"
fi

# Check SecretStore
if kubectl get secretstore fake-store &> /dev/null; then
    STATUS=$(kubectl get secretstore fake-store -o jsonpath='{.status.conditions[0].status}')
    echo "✓ SecretStore exists (ready: $STATUS)"
else
    echo "! SecretStore not configured"
fi

# Check ExternalSecret sync
if kubectl get externalsecret fake-external-secret &> /dev/null; then
    SYNC_STATUS=$(kubectl get externalsecret fake-external-secret -o jsonpath='{.status.conditions[0].reason}')
    echo "✓ ExternalSecret status: $SYNC_STATUS"

    # Verify synced secret
    if kubectl get secret synced-secret &> /dev/null; then
        echo "✓ Secret synced successfully"
    fi
else
    echo "! ExternalSecret not configured"
fi

echo "Part 4 validation complete!"
```

---

## Part 5: Challenge - Production Configuration Management

### Objective

Implement a complete configuration management solution:
- Environment-specific configurations
- Secure secret handling
- GitOps-ready setup
- Automatic secret rotation

### Architecture

<!-- figure: generated from the Mermaid below by _shared/diagrams/embed-figures.py — do not edit the image -->
![Architecture — diagram](../../../../_figures/curriculum-_reference-containers-labs-lab-11-configuration-README-0-25633a7d.png)

<details>
<summary>Diagram source (Mermaid)</summary>

```mermaid
%%{init: {'theme':'base','themeVariables':{'fontFamily':'Helvetica, Arial, sans-serif','fontSize':'13px','primaryColor':'#ffffff','primaryTextColor':'#2d3436','primaryBorderColor':'#9aa3ab','lineColor':'#9aa3ab','textColor':'#2d3436','clusterBkg':'#fbfcfd','clusterBorder':'#d4dae0','edgeLabelBackground':'#ffffff','tertiaryColor':'#eef4fb'},'flowchart':{'curve':'basis','padding':14,'nodeSpacing':42,'rankSpacing':58}}}%%
flowchart TB
  classDef default fill:#ffffff,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef n    fill:#ffffff,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef crit fill:#eef4fb,stroke:#2f6fb8,stroke-width:1.8px,color:#1b3a5c
  classDef data fill:#f4f7fa,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef mut  fill:#ffffff,stroke:#cfd6dc,stroke-width:1.1px,color:#7a8288
  classDef warn fill:#fdf0ec,stroke:#c0522d,stroke-width:1.6px,color:#8a3a1e
  subgraph GIT["Git repository"]
    direction TB
    G1["base/ — configmap.yaml · sealed-secret.yaml"]
    G2["overlays/ — dev · staging · production"]
    G3["kustomization.yaml"]
  end
  SSC["Sealed Secrets controller<br/><i>decrypts <b>only</b> inside the cluster</i>"]
  CM["ConfigMaps"]
  SEC["Secrets<br/><i>decrypted</i>"]
  ES["External Secrets<br/><i>synced from Vault / AWS Secrets Manager</i>"]
  PODS["Application pods<br/><i>env vars from ConfigMaps and Secrets ·<br/>mounted configuration files · reloaded on change</i>"]
  GIT ==> SSC
  SSC ==> SEC
  GIT --> CM
  ES --> PODS
  CM ==> PODS
  SEC ==> PODS
  class G1,G2,G3 n
  class SSC crit
  class CM data
  class SEC crit
  class ES mut
  class PODS n
  linkStyle 0,1,4,5 stroke:#2f6fb8,stroke-width:2px

%% Two ways to keep a secret out of Git, side by side. SealedSecrets keep the
%% ciphertext IN the repo; External Secrets keep only a reference and fetch the
%% value at runtime. The second is easier to rotate, the first works with no
%% external dependency.
```

</details>

### Requirements

1. **ConfigMaps:**
   - Base configuration for all environments
   - Environment-specific overrides (dev, staging, prod)
   - Application settings as files
   - Feature flags

2. **Secrets:**
   - Database credentials per environment
   - API keys
   - TLS certificates
   - All secrets as Sealed Secrets

3. **External Secrets (Optional):**
   - Connect to fake provider for demo
   - Sync production secrets
   - 1-hour refresh interval

4. **Application:**
   - Deployment that uses all configurations
   - ConfigMap watcher for auto-reload
   - Health check that verifies config

5. **Validation:**
   - Verify each environment has correct config
   - Test secret rotation
   - Verify no plain secrets in Git

### Kustomize Structure

**`config-management/`**

- `base/`
  - `kustomization.yaml`
  - `configmap.yaml`
  - `sealed-secret.yaml`
  - `deployment.yaml`
- `overlays/`
  - `dev/`
    - `kustomization.yaml`
    - `configmap-patch.yaml`
    - `sealed-secret.yaml`
  - `staging/`
    - `kustomization.yaml`
    - `configmap-patch.yaml`
    - `sealed-secret.yaml`
  - `production/`
    - `kustomization.yaml`
    - `configmap-patch.yaml`
    - `sealed-secret.yaml`
- `scripts/`
  - `seal-secrets.sh`
  - `validate.sh`


### Validation Script

```bash
#!/bin/bash
# validate-challenge.sh

echo "=== Challenge Validation ==="

# Test each environment
for ENV in dev staging production; do
    echo ""
    echo "Testing $ENV environment..."

    # Apply environment config
    kubectl apply -k overlays/$ENV/ --dry-run=server

    if [ $? -eq 0 ]; then
        echo "✓ $ENV configuration valid"
    else
        echo "✗ $ENV configuration invalid"
    fi
done

# Check for plain secrets in files
echo ""
echo "Checking for plain secrets..."
if grep -r "password:" --include="*.yaml" . | grep -v "sealed-secret" | grep -v "secretKeyRef"; then
    echo "✗ WARNING: Plain secrets found in YAML files!"
else
    echo "✓ No plain secrets in YAML files"
fi

# Verify Sealed Secrets
echo ""
echo "Verifying Sealed Secrets..."
SEALED_COUNT=$(find . -name "sealed-secret*.yaml" | wc -l)
echo "Found $SEALED_COUNT sealed secret files"

for FILE in $(find . -name "sealed-secret*.yaml"); do
    if grep -q "kind: SealedSecret" "$FILE"; then
        echo "✓ $FILE is properly sealed"
    else
        echo "✗ $FILE is not a valid SealedSecret"
    fi
done

# Test ConfigMap variations
echo ""
echo "Testing ConfigMap variations..."

kubectl apply -k overlays/dev/
DEV_ENV=$(kubectl get configmap app-config -o jsonpath='{.data.APP_ENV}')

kubectl apply -k overlays/production/
PROD_ENV=$(kubectl get configmap app-config -o jsonpath='{.data.APP_ENV}')

if [ "$DEV_ENV" != "$PROD_ENV" ]; then
    echo "✓ Environment-specific configs work (dev: $DEV_ENV, prod: $PROD_ENV)"
else
    echo "✗ Configs are not environment-specific"
fi

# Test secret decryption
echo ""
echo "Testing secret decryption..."
if kubectl get secret app-secrets &> /dev/null; then
    echo "✓ Secrets decrypted successfully"
else
    echo "✗ Secrets not decrypted"
fi

# Test application can read config
echo ""
echo "Testing application config access..."
POD=$(kubectl get pod -l app=config-demo -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$POD" ]; then
    CONFIG_VALUE=$(kubectl exec $POD -- printenv APP_ENV 2>/dev/null)
    if [ -n "$CONFIG_VALUE" ]; then
        echo "✓ Application reads config: APP_ENV=$CONFIG_VALUE"
    else
        echo "✗ Application cannot read config"
    fi
else
    echo "! Demo application not deployed"
fi

echo ""
echo "Challenge validation complete!"
```

---

## Deliverables

1. Complete Kustomize directory structure
2. Base ConfigMaps and Sealed Secrets
3. Environment-specific overlays
4. Secret sealing script
5. Validation documentation

## Commands Reference

```bash
# ConfigMaps
kubectl create configmap <name> --from-literal=key=value
kubectl create configmap <name> --from-file=config.yaml
kubectl get configmap <name> -o yaml
kubectl patch configmap <name> -p '{"data":{"key":"value"}}'

# Secrets
kubectl create secret generic <name> --from-literal=key=value
kubectl create secret tls <name> --cert=cert.pem --key=key.pem
kubectl get secret <name> -o jsonpath='{.data.key}' | base64 -d

# Sealed Secrets
kubeseal --format yaml < secret.yaml > sealed-secret.yaml
kubeseal --fetch-cert > pub-cert.pem
kubeseal --cert pub-cert.pem < secret.yaml > sealed-secret.yaml

# External Secrets
kubectl get secretstore
kubectl get externalsecret
kubectl describe externalsecret <name>

# Kustomize
kubectl apply -k overlays/dev/
kubectl kustomize overlays/dev/
```

## Resources

- [ConfigMaps](https://kubernetes.io/docs/concepts/configuration/configmap/)
- [Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)
- [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)
- [External Secrets](https://external-secrets.io/)
- [Kustomize](https://kustomize.io/)

## Next Lab

Continue to [Lab 12: Production Patterns](../lab-12-production-patterns/)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- ConfigMaps
- Secrets
- Sealed Secrets
- External Secrets

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"A container isolates the application."* |
| ✓ | *"A container is an ordinary Linux process started with namespaces (what it can see), cgroups (what it can use) and usually seccomp (what it may ask the kernel). There is no container object in the kernel — only a process with those features switched on."* |

**Trace it:** `docker run` → an isolated process. Name the namespaces in the order they are created, and which component actually calls `clone()`.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** the [LWN namespaces series](https://lwn.net/Articles/531114/) — seven parts by the man-pages maintainer, and the reason containers stop being magic.
Full list per domain: [`SOURCES.md`](../../SOURCES.md#containers)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../../MASTERY.md)

<!-- /feynman-check -->
