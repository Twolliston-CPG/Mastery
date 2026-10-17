# Module 05: Secrets Management

## Learning Objectives

By the end of this module, you will be able to:
- Implement centralized secrets management with HashiCorp Vault
- Use cloud-native secrets managers (AWS Secrets Manager, Azure Key Vault)
- Integrate secrets into Kubernetes workloads securely
- Implement secrets rotation strategies
- Prevent secrets exposure in code and logs

## Secrets Management Fundamentals

### The Secrets Problem

**Common Secrets Anti-Patterns**

❌ Hardcoded in source code
   password = "supersecret123"
❌ Stored in environment variables (unencrypted)
   export DB_PASSWORD=mysecret
❌ Committed to version control
   .env files, config.yaml with secrets
❌ Shared via chat/email
   "Hey, the API key is abc123..."
❌ Same secret across environments
   Production using development credentials
❌ No rotation or expiration
   5-year-old API keys still in use


### Secrets Management Best Practices

<!-- figure: generated from the Mermaid below by _shared/diagrams/embed-figures.py — do not edit the image -->
![Secrets Management Best Practices — diagram](../../../_figures/curriculum-_reference-devsecops-content-module-05-secrets-management-0-f49853dc.png)

<details>
<summary>Diagram source (Mermaid)</summary>

```mermaid
%%{init: {'theme':'base','themeVariables':{'fontFamily':'Helvetica, Arial, sans-serif','fontSize':'13px','primaryColor':'#ffffff','primaryTextColor':'#2d3436','primaryBorderColor':'#9aa3ab','lineColor':'#9aa3ab','textColor':'#2d3436','clusterBkg':'#fbfcfd','clusterBorder':'#d4dae0','edgeLabelBackground':'#ffffff','tertiaryColor':'#eef4fb'},'flowchart':{'curve':'basis','padding':14,'nodeSpacing':42,'rankSpacing':58}}}%%
flowchart LR
  classDef default fill:#ffffff,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef n    fill:#ffffff,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef crit fill:#eef4fb,stroke:#2f6fb8,stroke-width:1.8px,color:#1b3a5c
  classDef data fill:#f4f7fa,stroke:#9aa3ab,stroke-width:1.3px,color:#2d3436
  classDef mut  fill:#ffffff,stroke:#cfd6dc,stroke-width:1.1px,color:#7a8288
  classDef warn fill:#fdf0ec,stroke:#c0522d,stroke-width:1.6px,color:#8a3a1e
  subgraph STORE["Secrets store"]
    direction TB
    S1["encrypted storage"]:::n
    S2["access control"]:::n
    S3["audit logging"]:::n
    S4["rotation engine"]:::crit
  end
  AUTH["Workload identity<br/><small>IRSA · Pod Identity · Vault k8s auth<br/><b>no static credential to bootstrap with</b></small>"]:::crit
  SYNC["External Secrets Operator<br/><small>syncs into the cluster, refreshes on rotation</small>"]:::n
  APP["Application<br/><small>reads a mounted FILE, not an env var —<br/>so rotation lands without a restart</small>"]:::crit

  AUTH --> STORE --> SYNC --> APP

  linkStyle 0,1,2 stroke:#2f6fb8,stroke-width:2px
```

</details>

## HashiCorp Vault

### Vault Architecture

```yaml
# Vault Helm installation
helm repo add hashicorp https://helm.releases.hashicorp.com
helm install vault hashicorp/vault \
  --namespace vault \
  --create-namespace \
  --values vault-values.yaml
```

```yaml
# vault-values.yaml
global:
  enabled: true
  tlsDisable: false

server:
  ha:
    enabled: true
    replicas: 3
    raft:
      enabled: true
      config: |
        ui = true
        listener "tcp" {
          tls_disable = 0
          address = "[::]:8200"
          cluster_address = "[::]:8201"
          tls_cert_file = "/vault/tls/tls.crt"
          tls_key_file = "/vault/tls/tls.key"
        }
        storage "raft" {
          path = "/vault/data"
        }
        service_registration "kubernetes" {}

  dataStorage:
    enabled: true
    size: 10Gi
    storageClass: gp3

  auditStorage:
    enabled: true
    size: 10Gi

  resources:
    requests:
      memory: 256Mi
      cpu: 250m
    limits:
      memory: 512Mi
      cpu: 500m

ui:
  enabled: true
  serviceType: ClusterIP
```

### Vault Configuration

```bash
# Initialize Vault
vault operator init -key-shares=5 -key-threshold=3

# Unseal Vault (need 3 of 5 keys)
vault operator unseal <key1>
vault operator unseal <key2>
vault operator unseal <key3>

# Login with root token
vault login <root_token>

# Enable audit logging
vault audit enable file file_path=/vault/audit/audit.log

# Enable KV secrets engine
vault secrets enable -path=secret kv-v2

# Enable database secrets engine
vault secrets enable database
```

### Application Authentication

```bash
# Enable AppRole auth method
vault auth enable approle

# Create policy for application
vault policy write app-policy - <<EOF
path "secret/data/app/*" {
  capabilities = ["read"]
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
  secret_id_ttl=24h \
  secret_id_num_uses=100

# Get Role ID
vault read auth/approle/role/app-role/role-id

# Generate Secret ID
vault write -f auth/approle/role/app-role/secret-id
```

### Kubernetes Authentication

```bash
# Enable Kubernetes auth
vault auth enable kubernetes

# Configure Kubernetes auth
vault write auth/kubernetes/config \
  kubernetes_host="https://kubernetes.default.svc:443" \
  kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt

# Create role for application
vault write auth/kubernetes/role/app-role \
  bound_service_account_names=app-sa \
  bound_service_account_namespaces=production \
  policies=app-policy \
  ttl=1h
```

### Dynamic Database Credentials

```bash
# Configure database connection
vault write database/config/postgres \
  plugin_name=postgresql-database-plugin \
  allowed_roles="app-role" \
  connection_url="postgresql://{{username}}:{{password}}@postgres:5432/app?sslmode=require" \
  username="vault" \
  password="vault-password"

# Create role for dynamic credentials
vault write database/roles/app-role \
  db_name=postgres \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
    GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
  revocation_statements="DROP ROLE IF EXISTS \"{{name}}\";" \
  default_ttl="1h" \
  max_ttl="24h"

# Get dynamic credentials
vault read database/creds/app-role
```

## Vault Integration with Kubernetes

### Vault Agent Sidecar Injector

```yaml
# Deployment with Vault Agent
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
  namespace: production
spec:
  template:
    metadata:
      annotations:
        vault.hashicorp.com/agent-inject: "true"
        vault.hashicorp.com/role: "app-role"
        vault.hashicorp.com/agent-inject-secret-config: "secret/data/app/config"
        vault.hashicorp.com/agent-inject-template-config: |
          {{- with secret "secret/data/app/config" -}}
          {
            "database": {
              "host": "{{ .Data.data.db_host }}",
              "port": {{ .Data.data.db_port }},
              "username": "{{ .Data.data.db_username }}",
              "password": "{{ .Data.data.db_password }}"
            },
            "api_key": "{{ .Data.data.api_key }}"
          }
          {{- end -}}
    spec:
      serviceAccountName: app-sa
      containers:
        - name: app
          image: myapp:v1.0.0
          volumeMounts:
            - name: secrets
              mountPath: /vault/secrets
              readOnly: true
```

### External Secrets Operator

```yaml
# Install External Secrets Operator
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
  namespace: production
spec:
  provider:
    vault:
      server: "https://vault.vault.svc:8200"
      path: "secret"
      version: "v2"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "app-role"
          serviceAccountRef:
            name: app-sa

---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: app-secrets
  namespace: production
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: app-secrets
    creationPolicy: Owner
  data:
    - secretKey: DB_PASSWORD
      remoteRef:
        key: secret/data/app/database
        property: password
    - secretKey: API_KEY
      remoteRef:
        key: secret/data/app/api
        property: key
```

## Cloud Native Secrets Managers

### AWS Secrets Manager

```python
# Python application using AWS Secrets Manager
import boto3
import json
from functools import lru_cache

class SecretsManager:
    def __init__(self, region_name='us-east-1'):
        self.client = boto3.client(
            'secretsmanager',
            region_name=region_name
        )

    @lru_cache(maxsize=100)
    def get_secret(self, secret_name: str) -> dict:
        """Retrieve secret with caching."""
        try:
            response = self.client.get_secret_value(
                SecretId=secret_name
            )
            return json.loads(response['SecretString'])
        except Exception as e:
            raise Exception(f"Failed to retrieve secret: {e}")

    def get_database_credentials(self) -> dict:
        """Get database credentials."""
        return self.get_secret('production/database')

# Usage
secrets = SecretsManager()
db_creds = secrets.get_database_credentials()
connection_string = f"postgresql://{db_creds['username']}:{db_creds['password']}@{db_creds['host']}/{db_creds['database']}"
```

```hcl
# Terraform AWS Secrets Manager
resource "aws_secretsmanager_secret" "database" {
  name        = "production/database"
  description = "Database credentials"
  kms_key_id  = aws_kms_key.secrets.arn

  recovery_window_in_days = 7

  tags = {
    Environment = "production"
    Application = "myapp"
  }
}

resource "aws_secretsmanager_secret_version" "database" {
  secret_id = aws_secretsmanager_secret.database.id
  secret_string = jsonencode({
    username = "app_user"
    password = random_password.db_password.result
    host     = aws_db_instance.main.endpoint
    database = "app_db"
  })
}

# Enable automatic rotation
resource "aws_secretsmanager_secret_rotation" "database" {
  secret_id           = aws_secretsmanager_secret.database.id
  rotation_lambda_arn = aws_lambda_function.rotate_secret.arn

  rotation_rules {
    automatically_after_days = 30
  }
}
```

### Azure Key Vault

```python
# Python with Azure Key Vault
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient

class AzureSecretsManager:
    def __init__(self, vault_url: str):
        credential = DefaultAzureCredential()
        self.client = SecretClient(
            vault_url=vault_url,
            credential=credential
        )

    def get_secret(self, name: str) -> str:
        """Retrieve secret from Key Vault."""
        secret = self.client.get_secret(name)
        return secret.value

    def set_secret(self, name: str, value: str):
        """Store secret in Key Vault."""
        self.client.set_secret(name, value)

# Usage
vault = AzureSecretsManager("https://myapp-vault.vault.azure.net")
api_key = vault.get_secret("api-key")
```

```hcl
# Terraform Azure Key Vault
resource "azurerm_key_vault" "main" {
  name                        = "myapp-vault"
  location                    = azurerm_resource_group.main.location
  resource_group_name         = azurerm_resource_group.main.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "premium"
  soft_delete_retention_days  = 90
  purge_protection_enabled    = true
  enabled_for_disk_encryption = true

  network_acls {
    default_action             = "Deny"
    bypass                     = "AzureServices"
    virtual_network_subnet_ids = [azurerm_subnet.app.id]
  }
}

resource "azurerm_key_vault_access_policy" "app" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.app.principal_id

  secret_permissions = [
    "Get",
    "List"
  ]
}
```

## Secrets Rotation

### Rotation Strategy

```python
# Automated secrets rotation
import boto3
import json
import string
import secrets
from datetime import datetime

def lambda_handler(event, context):
    """AWS Lambda function for secret rotation."""

    secret_manager = boto3.client('secretsmanager')
    step = event['Step']
    secret_id = event['SecretId']

    if step == 'createSecret':
        create_secret(secret_manager, secret_id, event['ClientRequestToken'])
    elif step == 'setSecret':
        set_secret(secret_manager, secret_id, event['ClientRequestToken'])
    elif step == 'testSecret':
        test_secret(secret_manager, secret_id, event['ClientRequestToken'])
    elif step == 'finishSecret':
        finish_secret(secret_manager, secret_id, event['ClientRequestToken'])

def create_secret(client, secret_id, token):
    """Create new version of secret."""
    # Get current secret
    current = client.get_secret_value(
        SecretId=secret_id,
        VersionStage='AWSCURRENT'
    )
    current_dict = json.loads(current['SecretString'])

    # Generate new password
    new_password = generate_password()
    current_dict['password'] = new_password

    # Store as pending
    client.put_secret_value(
        SecretId=secret_id,
        ClientRequestToken=token,
        SecretString=json.dumps(current_dict),
        VersionStages=['AWSPENDING']
    )

def set_secret(client, secret_id, token):
    """Set the new credential in the database."""
    pending = client.get_secret_value(
        SecretId=secret_id,
        VersionId=token,
        VersionStage='AWSPENDING'
    )
    pending_dict = json.loads(pending['SecretString'])

    # Update password in database
    update_database_password(
        pending_dict['username'],
        pending_dict['password']
    )

def test_secret(client, secret_id, token):
    """Test the new credential."""
    pending = client.get_secret_value(
        SecretId=secret_id,
        VersionId=token,
        VersionStage='AWSPENDING'
    )
    pending_dict = json.loads(pending['SecretString'])

    # Test database connection
    test_database_connection(
        pending_dict['host'],
        pending_dict['username'],
        pending_dict['password']
    )

def finish_secret(client, secret_id, token):
    """Mark rotation as complete."""
    client.update_secret_version_stage(
        SecretId=secret_id,
        VersionStage='AWSCURRENT',
        MoveToVersionId=token,
        RemoveFromVersionId=get_current_version(client, secret_id)
    )

def generate_password(length=32):
    """Generate secure password."""
    alphabet = string.ascii_letters + string.digits + "!@#$%^&*"
    return ''.join(secrets.choice(alphabet) for _ in range(length))
```

## Preventing Secrets Exposure

### Pre-Commit Hooks for Secret Detection

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/Yelp/detect-secrets
    rev: v1.4.0
    hooks:
      - id: detect-secrets
        args: ['--baseline', '.secrets.baseline']

  - repo: https://github.com/trufflesecurity/trufflehog
    rev: v3.63.0
    hooks:
      - id: trufflehog
        entry: trufflehog git file://. --since-commit HEAD --only-verified

  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.18.0
    hooks:
      - id: gitleaks
```

### GitLeaks Configuration

```toml
# .gitleaks.toml
title = "Gitleaks Configuration"

[extend]
useDefault = true

[[rules]]
id = "custom-api-key"
description = "Custom API Key Pattern"
regex = '''(?i)(api[_-]?key|apikey)['":\s]*[=:]\s*['"]?([a-zA-Z0-9_-]{32,})['"]?'''
secretGroup = 2

[[rules]]
id = "internal-token"
description = "Internal service token"
regex = '''(?i)internal[_-]token['":\s]*[=:]\s*['"]?([a-zA-Z0-9_-]{20,})['"]?'''
secretGroup = 1

[allowlist]
description = "Global allowlist"
paths = [
    '''\.gitleaks\.toml$''',
    '''test/.*''',
    '''.*_test\.go$''',
]
```

### Secure Logging

```python
# Prevent secrets from appearing in logs
import re
import logging
from typing import Any

class SecretRedactingFormatter(logging.Formatter):
    """Custom formatter that redacts secrets from log messages."""

    PATTERNS = [
        (r'password["\']?\s*[:=]\s*["\']?([^"\'\s]+)', 'password=***REDACTED***'),
        (r'api[_-]?key["\']?\s*[:=]\s*["\']?([^"\'\s]+)', 'api_key=***REDACTED***'),
        (r'token["\']?\s*[:=]\s*["\']?([^"\'\s]+)', 'token=***REDACTED***'),
        (r'secret["\']?\s*[:=]\s*["\']?([^"\'\s]+)', 'secret=***REDACTED***'),
        (r'authorization:\s*bearer\s+([^\s]+)', 'Authorization: Bearer ***REDACTED***'),
    ]

    def format(self, record: logging.LogRecord) -> str:
        message = super().format(record)
        for pattern, replacement in self.PATTERNS:
            message = re.sub(pattern, replacement, message, flags=re.IGNORECASE)
        return message

# Configure logging
handler = logging.StreamHandler()
handler.setFormatter(SecretRedactingFormatter(
    '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
))
logger = logging.getLogger()
logger.addHandler(handler)
```

## Summary

Secrets management requires a comprehensive approach:

1. **Centralized Storage** - Use Vault or cloud-native secrets managers
2. **Dynamic Credentials** - Generate short-lived credentials when possible
3. **Secure Integration** - Use sidecars or operators for Kubernetes
4. **Rotation** - Implement automatic rotation strategies
5. **Prevention** - Use pre-commit hooks and secure logging

## Additional Resources

- [HashiCorp Vault Documentation](https://developer.hashicorp.com/vault/docs)
- [AWS Secrets Manager Best Practices](https://docs.aws.amazon.com/secretsmanager/latest/userguide/best-practices.html)
- [External Secrets Operator](https://external-secrets.io/)
- [OWASP Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)

## Next Module

Continue to [Module 06: Security Scanning](content-module-06-security-scanning.md) to learn about SAST, DAST, and vulnerability scanning.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Secrets Management Fundamentals
- HashiCorp Vault
- Vault Integration with Kubernetes
- Cloud Native Secrets Managers

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
