# Exercise 4: External Secrets Operator

## Objectives

- Deploy External Secrets Operator
- Configure various secret backends
- Implement secret synchronization
- Set up automatic secret refresh

## Prerequisites

- Completed Exercises 1-3
- Access to external secret store (AWS SM, Vault, etc.)
- kubectl proficiency

---

## Part 1: External Secrets Operator Setup

### 1.1 Installation

```bash
# Add Helm repo
helm repo add external-secrets https://charts.external-secrets.io

# Install operator
helm install external-secrets \
  external-secrets/external-secrets \
  --namespace external-secrets \
  --create-namespace \
  --set installCRDs=true
```

### 1.2 Verify Installation

```bash
# Check pods
kubectl get pods -n external-secrets

# Check CRDs
kubectl get crds | grep external-secrets
# externalsecrets.external-secrets.io
# secretstores.external-secrets.io
# clustersecretstores.external-secrets.io
```

---

## Part 2: AWS Secrets Manager

### 2.1 IAM Setup

```json
// secrets-manager-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetResourcePolicy",
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret",
        "secretsmanager:ListSecretVersionIds"
      ],
      "Resource": "arn:aws:secretsmanager:*:*:secret:myapp/*"
    }
  ]
}
```

### 2.2 SecretStore Configuration

```yaml
# aws-secretstore.yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secretsmanager
  namespace: default
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-west-2
      auth:
        # Option 1: Service Account (EKS IRSA)
        jwt:
          serviceAccountRef:
            name: external-secrets-sa

        # Option 2: Static credentials
        # secretRef:
        #   accessKeyIDSecretRef:
        #     name: aws-credentials
        #     key: access-key
        #   secretAccessKeySecretRef:
        #     name: aws-credentials
        #     key: secret-key
```

### 2.3 ExternalSecret Resource

```yaml
# aws-externalsecret.yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: database-credentials
  namespace: default
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secretsmanager
    kind: SecretStore

  target:
    name: db-creds          # Kubernetes secret name
    creationPolicy: Owner   # Delete secret when ExternalSecret deleted
    template:
      type: Opaque
      data:
        # Template the secret data
        connection-string: "postgresql://{{ .username }}:{{ .password }}@postgres:5432/mydb"

  data:
  - secretKey: username
    remoteRef:
      key: myapp/database    # AWS Secrets Manager secret name
      property: username     # JSON key in secret

  - secretKey: password
    remoteRef:
      key: myapp/database
      property: password
```

### 2.4 Fetching Entire Secret

```yaml
# aws-full-secret.yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: api-keys
spec:
  refreshInterval: 30m
  secretStoreRef:
    name: aws-secretsmanager
    kind: SecretStore
  target:
    name: api-keys
  dataFrom:
  - extract:
      key: myapp/api-keys   # Fetch all key-value pairs
```

---

## Part 3: HashiCorp Vault

### 3.1 Vault SecretStore

```yaml
# vault-secretstore.yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
  namespace: default
spec:
  provider:
    vault:
      server: "https://vault.example.com:8200"
      path: "secret"
      version: "v2"
      auth:
        # Kubernetes auth method
        kubernetes:
          mountPath: "kubernetes"
          role: "external-secrets"
          serviceAccountRef:
            name: vault-auth
        # Or token auth
        # tokenSecretRef:
        #   name: vault-token
        #   key: token
```

### 3.2 Vault ExternalSecret

```yaml
# vault-externalsecret.yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: vault-secrets
spec:
  refreshInterval: 15m
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: app-secrets
  data:
  - secretKey: db-password
    remoteRef:
      key: secret/data/myapp/database
      property: password

  - secretKey: api-key
    remoteRef:
      key: secret/data/myapp/api
      property: key
```

### 3.3 Dynamic Vault Secrets

```yaml
# vault-dynamic-secret.yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: vault-db-creds
spec:
  refreshInterval: 5m        # Refresh before TTL expires
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: dynamic-db-creds
  data:
  - secretKey: username
    remoteRef:
      key: database/creds/myapp-role  # Dynamic secret path
      property: username

  - secretKey: password
    remoteRef:
      key: database/creds/myapp-role
      property: password
```

---

## Part 4: Google Secret Manager

### 4.1 GCP SecretStore

```yaml
# gcp-secretstore.yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: gcp-secretmanager
spec:
  provider:
    gcpsm:
      projectID: my-gcp-project
      auth:
        # Workload Identity
        workloadIdentity:
          clusterLocation: us-central1
          clusterName: my-cluster
          clusterProjectID: my-gcp-project
          serviceAccountRef:
            name: gcp-sa
```

### 4.2 GCP ExternalSecret

```yaml
# gcp-externalsecret.yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: gcp-secrets
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: gcp-secretmanager
    kind: SecretStore
  target:
    name: app-secrets
  data:
  - secretKey: api-key
    remoteRef:
      key: projects/my-project/secrets/api-key
      version: latest
```

---

## Part 5: Azure Key Vault

### 5.1 Azure SecretStore

```yaml
# azure-secretstore.yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: azure-keyvault
spec:
  provider:
    azurekv:
      vaultUrl: "https://my-vault.vault.azure.net"
      authType: WorkloadIdentity
      serviceAccountRef:
        name: azure-sa
```

### 5.2 Azure ExternalSecret

```yaml
# azure-externalsecret.yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: azure-secrets
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: azure-keyvault
    kind: SecretStore
  target:
    name: app-secrets
  data:
  - secretKey: connection-string
    remoteRef:
      key: database-connection-string
```

---

## Part 6: ClusterSecretStore

### 6.1 Cluster-Wide Store

```yaml
# cluster-secretstore.yaml
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: global-vault
spec:
  provider:
    vault:
      server: "https://vault.example.com:8200"
      path: "secret"
      version: "v2"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "global-reader"
          serviceAccountRef:
            name: vault-auth
            namespace: external-secrets
```

### 6.2 Using ClusterSecretStore

```yaml
# using-cluster-store.yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: app-secrets
  namespace: production  # Any namespace
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: global-vault
    kind: ClusterSecretStore  # Reference ClusterSecretStore
  target:
    name: app-secrets
  data:
  - secretKey: api-key
    remoteRef:
      key: secret/data/production/api
      property: key
```

---

## Part 7: Advanced Patterns

### 7.1 Secret Templates

```yaml
# templated-secret.yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: templated-secret
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: app-config
    template:
      type: Opaque
      metadata:
        labels:
          app: myapp
        annotations:
          managed-by: external-secrets
      data:
        config.yaml: |
          database:
            host: postgres
            port: 5432
            username: {{ .username }}
            password: {{ .password }}
          api:
            key: {{ .apikey }}
  data:
  - secretKey: username
    remoteRef:
      key: myapp/database
      property: username
  - secretKey: password
    remoteRef:
      key: myapp/database
      property: password
  - secretKey: apikey
    remoteRef:
      key: myapp/api
      property: key
```

### 7.2 Push Secrets (Reverse Sync)

```yaml
# push-secret.yaml
apiVersion: external-secrets.io/v1alpha1
kind: PushSecret
metadata:
  name: push-to-vault
spec:
  refreshInterval: 10s
  secretStoreRefs:
  - name: vault-backend
    kind: SecretStore
  selector:
    secret:
      name: local-secret  # K8s secret to push
  data:
  - match:
      secretKey: password
      remoteRef:
        remoteKey: secret/data/myapp/pushed
        property: password
```

### 7.3 Generator (Create Secrets)

```yaml
# password-generator.yaml
apiVersion: generators.external-secrets.io/v1alpha1
kind: Password
metadata:
  name: generated-password
spec:
  length: 32
  digits: 6
  symbols: 4
  symbolCharacters: "!@#$%"
  noUpper: false
  allowRepeat: false
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: generated-secret
spec:
  refreshInterval: 0  # Never refresh (one-time generation)
  target:
    name: generated-secret
  dataFrom:
  - sourceRef:
      generatorRef:
        apiVersion: generators.external-secrets.io/v1alpha1
        kind: Password
        name: generated-password
```

---

## Part 8: Hands-on Challenges

### Challenge 1: Multi-Backend Setup

Configure External Secrets with:
1. AWS Secrets Manager for production
2. Vault for development
3. Automatic sync every 15 minutes
4. Templated secrets for application config

### Challenge 2: Secret Migration

Migrate secrets from Kubernetes to external store:
1. Export existing secrets
2. Import to Vault/AWS SM
3. Create ExternalSecrets
4. Verify applications work
5. Remove old secrets

### Challenge 3: Disaster Recovery

Implement DR for secrets:
1. Sync secrets across regions
2. Test failover procedures
3. Document recovery steps
4. Automate health checks

---

## Verification Tasks

1. [ ] Installed External Secrets Operator
2. [ ] Configured AWS Secrets Manager backend
3. [ ] Set up Vault SecretStore
4. [ ] Created ExternalSecrets with refresh
5. [ ] Implemented secret templates
6. [ ] Tested ClusterSecretStore

---

## Key Takeaways

- ESO syncs external secrets to Kubernetes
- Multiple backends supported
- Refresh intervals enable auto-rotation
- Templates transform secret data
- ClusterSecretStore enables multi-namespace
- PushSecrets enable reverse sync

---

## Next Steps

Continue to [Exercise 5: Vault Integration](05-vault-integration.md)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- External Secrets Operator Setup
- AWS Secrets Manager
- HashiCorp Vault
- Google Secret Manager

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
