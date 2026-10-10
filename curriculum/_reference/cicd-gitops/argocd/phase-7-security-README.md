# Phase 7: Security & Access Control

**Goal:** Master Argo CD security including RBAC, local users, SSO, secrets management, and repository credentials.

**Duration:** 2-3 hours

---

## Overview

This phase covers:
- RBAC policy configuration
- Local user management
- SSO integration (OIDC, LDAP, GitHub)
- Repository credentials (HTTPS, SSH)
- Secret management (Sealed Secrets, External Secrets)

---

## Concepts

### RBAC Overview

Argo CD uses Casbin-based RBAC with a policy model:

<!-- figure: generated from the Mermaid below by _shared/diagrams/embed-figures.py — do not edit the image -->
![RBAC Overview — diagram](../../../../_figures/curriculum-_reference-cicd-gitops-argocd-phase-7-security-README-0-f983f742.png)

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
  U["User or group"]
  R["Role"]
  P["Policy"]
  A["<code>resource : action : object</code>"]
  U ==> R ==> P ==> A
  class U n
  class R n
  class P crit
  class A crit
  linkStyle 0,1,2 stroke:#2f6fb8,stroke-width:2px

%% Worked example:
%%
%%   jane@example.com  ->  role:developer  ->  applications:sync:myapp
%%
%% The object is the part people leave as `*`. `applications:sync:*` lets a
%% developer sync every application in the instance, including the one that
%% manages Argo CD itself.
```

</details>

### Policy Syntax

```
# Policy format
p, <subject>, <resource>, <action>, <object>, <effect>

# Group assignment
g, <user/group>, <role>
```

**Resources:**
| Resource | Description |
|----------|-------------|
| `applications` | Argo CD Applications |
| `clusters` | Registered clusters |
| `projects` | AppProjects |
| `repositories` | Git/Helm repositories |
| `logs` | Application logs |
| `exec` | Pod exec access |
| `accounts` | User accounts |
| `certificates` | TLS certificates |
| `gpgkeys` | GPG keys |

**Actions:**
| Action | Description |
|--------|-------------|
| `get` | View/read |
| `create` | Create new |
| `update` | Modify existing |
| `delete` | Remove |
| `sync` | Sync applications |
| `override` | Override sync window |
| `action` | Run resource actions |
| `*` | All actions |

**Object patterns:**
- `*/*` - All projects, all apps
- `myproject/*` - All apps in myproject
- `myproject/myapp` - Specific app
- `*/prod-*` - Apps matching pattern in any project

### Built-in Roles

| Role | Access |
|------|--------|
| `role:readonly` | View all, no changes |
| `role:admin` | Full access to everything |

### Local Users

Configure in `argocd-cm`:

```yaml
data:
  # Format: accounts.<username>: <capabilities>
  accounts.developer: apiKey, login    # Can get API key and login
  accounts.ci-bot: apiKey              # API key only (no UI)
  accounts.viewer: login               # Login only (no API key)
```

Capabilities:
- `apiKey` - Can generate API tokens for CLI/automation
- `login` - Can log in via UI

### SSO Configuration

**OIDC (IdentityCo, Auth0, etc.):**

```yaml
data:
  url: https://argocd.example.com
  oidc.config: |
    name: IdentityCo
    issuer: https://your-org.identityco.com
    clientID: your-client-id
    clientSecret: $oidc.identityco.clientSecret
    requestedScopes: ["openid", "profile", "email", "groups"]
    requestedIDTokenClaims:
      groups:
        essential: true
```

**Dex (GitHub, LDAP, SAML):**

```yaml
data:
  dex.config: |
    connectors:
      - type: github
        id: github
        name: GitHub
        config:
          clientID: $dex.github.clientID
          clientSecret: $dex.github.clientSecret
          orgs:
            - name: your-github-org
```

### Repository Credentials

**HTTPS with token:**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: private-repo
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  url: https://github.com/org/repo.git
  username: git
  password: ghp_YOUR_TOKEN
```

**SSH key:**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: private-repo-ssh
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  url: git@github.com:org/repo.git
  sshPrivateKey: |
    -----BEGIN OPENSSH PRIVATE KEY-----
    ...
    -----END OPENSSH PRIVATE KEY-----
```

**Credential templates (apply to multiple repos):**

```yaml
metadata:
  labels:
    argocd.argoproj.io/secret-type: repo-creds  # Note: repo-creds
stringData:
  url: https://github.com/myorg  # Pattern matches all repos under myorg
```

### Secret Management

**Option 1: Sealed Secrets**

Encrypt secrets locally, safe to store in Git:

```bash
# Encrypt a secret
kubeseal --controller-name=sealed-secrets \
  --controller-namespace=kube-system \
  --format yaml < secret.yaml > sealed-secret.yaml
```

**Option 2: External Secrets Operator**

Sync secrets from external providers:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: app-secrets
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: app-secrets
  data:
    - secretKey: db-password
      remoteRef:
        key: /database/credentials
        property: password
```

---

## Labs

### Lab 7.1: Configure RBAC

#### Step 1: Review Current RBAC

```bash
# View current RBAC config
kubectl get configmap argocd-rbac-cm -n argocd -o yaml
```

#### Step 2: Review the RBAC Policy

```bash
cat rbac/argocd-rbac-cm.yaml
```

Key policies:
- Default role: `role:readonly`
- Custom roles: `developer`, `deployer`, `project-admin`
- Team policies: `team-frontend-devs`, etc.
- Deny rules for production protection

#### Step 3: Apply RBAC Configuration

```bash
kubectl apply -f rbac/argocd-rbac-cm.yaml
```

#### Step 4: Test RBAC (with local user)

First, create a local user:

```bash
# Apply local user config
kubectl apply -f rbac/local-users.yaml

# Set password for developer user
argocd account update-password \
  --account developer \
  --new-password 'DevPass123!'

# Login as developer
argocd login localhost:8080 \
  --username developer \
  --password 'DevPass123!' \
  --insecure
```

#### Step 5: Verify Permissions

```bash
# As developer, try to list apps (should work)
argocd app list

# Try to delete an app (should fail if not allowed)
argocd app delete guestbook
```

### Lab 7.2: Create Local Users

#### Step 1: Review User Configuration

```bash
cat rbac/local-users.yaml
```

Users defined:
- `developer` - Can login and use API
- `ci-bot` - API only (for automation)
- `viewer` - Login only

#### Step 2: Apply and Create Accounts

```bash
# Apply the config
kubectl apply -f rbac/local-users.yaml

# Restart API server to pick up changes
kubectl rollout restart deployment argocd-server -n argocd
```

#### Step 3: Set Passwords

```bash
# Set password for developer
argocd account update-password \
  --account developer \
  --new-password 'SecurePass123!'

# Generate API token for ci-bot
argocd account generate-token --account ci-bot
```

#### Step 4: List Accounts

```bash
argocd account list
```

### Lab 7.3: Configure Repository Credentials

#### Step 1: HTTPS Credentials

```bash
cat repo-credentials/repo-https.yaml
```

Update with your credentials:

```bash
# Edit with your token
sed -i '' 's/YOUR_USERNAME/your-username/g' repo-credentials/repo-https.yaml
sed -i '' 's/ghp_YOUR_GITHUB_TOKEN/ghp_your_actual_token/g' repo-credentials/repo-https.yaml
```

#### Step 2: Apply Credentials

```bash
kubectl apply -f repo-credentials/repo-https.yaml
```

#### Step 3: Verify Repository Access

```bash
# List repos - should show your private repo
argocd repo list

# Test connection
argocd repo get https://github.com/your-username/private-repo.git
```

#### Step 4: SSH Credentials (Alternative)

```bash
cat repo-credentials/repo-ssh.yaml
```

For SSH:
1. Generate SSH key: `ssh-keygen -t ed25519 -f argocd-key`
2. Add public key to GitHub/GitLab
3. Add private key to the secret

### Lab 7.4: External Secrets (Advanced)

#### Step 1: Install External Secrets Operator

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets \
  external-secrets/external-secrets \
  -n external-secrets \
  --create-namespace
```

#### Step 2: Review External Secret Config

```bash
cat secrets/external-secret-example.yaml
```

Components:
- `SecretStore` - Connection to secret provider
- `ExternalSecret` - What secrets to sync
- `ClusterSecretStore` - Cluster-wide secret store

#### Step 3: Create a Test SecretStore

```bash
# Apply the fake store for testing
kubectl apply -f secrets/external-secret-example.yaml
```

#### Step 4: Verify Secret Created

```bash
# Check ExternalSecret status
kubectl get externalsecret app-secrets

# View the created secret
kubectl get secret app-secrets -o yaml
```

### Lab 7.5: Sealed Secrets (Alternative)

#### Step 1: Install Sealed Secrets Controller

```bash
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm install sealed-secrets sealed-secrets/sealed-secrets \
  -n kube-system
```

#### Step 2: Install kubeseal CLI

```bash
brew install kubeseal
```

#### Step 3: Create and Seal a Secret

```bash
# Create a regular secret
cat <<EOF > /tmp/my-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-secret
  namespace: default
stringData:
  api-key: "super-secret-value"
EOF

# Seal it
kubeseal --format yaml < /tmp/my-secret.yaml > secrets/my-sealed-secret.yaml

# View the sealed secret (safe for Git)
cat secrets/my-sealed-secret.yaml
```

#### Step 4: Apply Sealed Secret

```bash
kubectl apply -f secrets/my-sealed-secret.yaml

# The controller decrypts it to a regular secret
kubectl get secret my-secret -o yaml
```

---

## Security Best Practices

### RBAC

1. **Least privilege** - Start with `role:readonly`, add permissions as needed
2. **Use groups** - Map SSO groups to roles, not individual users
3. **Protect production** - Deny rules for prod app deletion
4. **Audit policies** - Review RBAC periodically

### Credentials

1. **Use credential templates** - Avoid duplicating credentials
2. **Prefer SSH** - More secure than HTTPS tokens
3. **Rotate regularly** - Tokens should have expiration
4. **GitHub Apps** - More secure than personal access tokens

### Secrets

1. **Never commit plain secrets** - Use Sealed Secrets or External Secrets
2. **Use external providers** - Vault, AWS Secrets Manager, etc.
3. **Limit access** - Only apps that need secrets should access them
4. **Rotate secrets** - Set up rotation policies

### SSO

1. **Enable SSO** - Don't rely on local users in production
2. **Require groups** - Map permissions to SSO groups
3. **Use OIDC** - Preferred over Dex for simplicity
4. **Audit logins** - Monitor authentication events

---

## Knowledge Check

Answer these questions before proceeding:

1. **What's the difference between `role:readonly` and a custom policy?**
   <details>
   <summary>Answer</summary>
   `role:readonly` is a built-in role with view-only access to everything. Custom policies let you define specific access to specific resources/actions/objects.
   </details>

2. **How do credential templates differ from repository secrets?**
   <details>
   <summary>Answer</summary>
   Repository secrets (`argocd.argoproj.io/secret-type: repository`) are for specific repos. Credential templates (`argocd.argoproj.io/secret-type: repo-creds`) apply to all repos matching the URL pattern.
   </details>

3. **Why use External Secrets instead of regular Kubernetes secrets?**
   <details>
   <summary>Answer</summary>
   External Secrets sync from external providers (Vault, AWS SM), enabling centralized secret management, automatic rotation, and audit trails. Regular secrets in Git are a security risk.
   </details>

4. **What does `apiKey` capability mean for a local user?**
   <details>
   <summary>Answer</summary>
   It allows the user to generate API tokens via `argocd account generate-token`. These tokens are used for CLI access and automation.
   </details>

5. **How do deny rules work in RBAC?**
   <details>
   <summary>Answer</summary>
   Deny rules take precedence over allow rules. If a user has both `allow` and `deny` policies for the same resource/action, the deny wins.
   </details>

---

## Common Mistakes

1. **Default `role:admin`** - Everyone has full access (dangerous)
2. **Committing plain secrets** - Security breach waiting to happen
3. **Using personal tokens** - Use service accounts or GitHub Apps
4. **Not testing RBAC** - Policies may not work as expected
5. **Forgetting password management** - Local users need password rotation

---

## Files in This Directory

| File/Directory | Purpose |
|----------------|---------|
| `rbac/argocd-rbac-cm.yaml` | Comprehensive RBAC configuration |
| `rbac/local-users.yaml` | Local user and SSO configuration |
| `secrets/sealed-secret-example.yaml` | Sealed Secrets example |
| `secrets/external-secret-example.yaml` | External Secrets example |
| `repo-credentials/repo-https.yaml` | HTTPS repository credentials |
| `repo-credentials/repo-ssh.yaml` | SSH repository credentials |

---

## What's Next?

Now that you understand security, proceed to **Phase 8: Observability** to learn about metrics, notifications, and health checks.

```bash
cd ../phase-8-observability
cat README.md
```

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Security Best Practices
- RBAC Overview
- Policy Syntax
- Built-in Roles

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"The pipeline deploys the application."* |
| ✓ | *"CI writes a new image tag into a config repository and stops. A controller running *inside* the cluster polls that repo, diffs the rendered manifests against live state, and applies the difference — so nothing outside the cluster ever holds credentials to it."* |

**Trace it:** `git push` → the new version serving traffic, with nothing else typed. Name where the handoff between CI and CD happens, and what that handoff physically is.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** the four [OpenGitOps principles](https://opengitops.dev/#principles) — then say which one a `kubectl apply` inside CI violates.
Full list per domain: [`SOURCES.md`](../../SOURCES.md#cicd-gitops)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../../MASTERY.md)

<!-- /feynman-check -->
