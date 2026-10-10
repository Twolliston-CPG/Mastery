# Lab 7: Identity and Access Management

## Objectives

- Implement OAuth 2.0/OIDC authentication flows
- Deploy and configure Keycloak identity provider
- Implement RBAC and ABAC authorization patterns
- Configure service mesh authentication with Istio

## Prerequisites

- Kubernetes cluster
- Docker installed
- Basic understanding of OAuth 2.0/OIDC

## Duration

3 hours

## Part 1: Keycloak Setup (45 minutes)

### Task 1.1: Deploy Keycloak

```yaml
# keycloak/deployment.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: keycloak
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: keycloak
  namespace: keycloak
spec:
  replicas: 1
  selector:
    matchLabels:
      app: keycloak
  template:
    metadata:
      labels:
        app: keycloak
    spec:
      containers:
      - name: keycloak
        image: quay.io/keycloak/keycloak:23.0
        args: ["start-dev"]
        env:
        - name: KEYCLOAK_ADMIN
          value: admin
        - name: KEYCLOAK_ADMIN_PASSWORD
          valueFrom:
            secretKeyRef:
              name: keycloak-secret
              key: admin-password
        - name: KC_PROXY
          value: "edge"
        ports:
        - containerPort: 8080
        readinessProbe:
          httpGet:
            path: /realms/master
            port: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: keycloak
  namespace: keycloak
spec:
  ports:
  - port: 8080
    targetPort: 8080
  selector:
    app: keycloak
```

```bash
# Create secret
kubectl create secret generic keycloak-secret \
  --from-literal=admin-password=admin123 \
  -n keycloak

# Apply deployment
kubectl apply -f keycloak/

# Port forward
kubectl port-forward svc/keycloak 8080:8080 -n keycloak &
```

### Task 1.2: Configure Keycloak Realm

```bash
# Access Keycloak admin console at http://localhost:8080
# Login with admin/admin123

# Create realm configuration JSON
cat > realm-export.json << 'EOF'
{
  "realm": "myapp",
  "enabled": true,
  "sslRequired": "external",
  "registrationAllowed": false,
  "loginWithEmailAllowed": true,
  "duplicateEmailsAllowed": false,
  "resetPasswordAllowed": true,
  "editUsernameAllowed": false,
  "bruteForceProtected": true,
  "permanentLockout": false,
  "maxFailureWaitSeconds": 900,
  "minimumQuickLoginWaitSeconds": 60,
  "waitIncrementSeconds": 60,
  "quickLoginCheckMilliSeconds": 1000,
  "maxDeltaTimeSeconds": 43200,
  "failureFactor": 5,
  "roles": {
    "realm": [
      {"name": "user", "description": "Regular user"},
      {"name": "admin", "description": "Administrator"},
      {"name": "developer", "description": "Developer access"}
    ]
  },
  "clients": [
    {
      "clientId": "webapp",
      "enabled": true,
      "publicClient": true,
      "directAccessGrantsEnabled": true,
      "redirectUris": ["http://localhost:3000/*"],
      "webOrigins": ["http://localhost:3000"],
      "defaultClientScopes": ["openid", "profile", "email", "roles"]
    },
    {
      "clientId": "api-service",
      "enabled": true,
      "publicClient": false,
      "secret": "api-service-secret",
      "serviceAccountsEnabled": true,
      "directAccessGrantsEnabled": false,
      "authorizationServicesEnabled": true
    }
  ],
  "users": [
    {
      "username": "testuser",
      "enabled": true,
      "email": "test@example.com",
      "emailVerified": true,
      "credentials": [{"type": "password", "value": "test123"}],
      "realmRoles": ["user"]
    },
    {
      "username": "admin",
      "enabled": true,
      "email": "admin@example.com",
      "emailVerified": true,
      "credentials": [{"type": "password", "value": "admin123"}],
      "realmRoles": ["admin", "user"]
    }
  ]
}
EOF

# Import realm via API
curl -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $(curl -s -X POST 'http://localhost:8080/realms/master/protocol/openid-connect/token' \
    -d 'client_id=admin-cli&username=admin&password=admin123&grant_type=password' | jq -r '.access_token')" \
  -d @realm-export.json \
  http://localhost:8080/admin/realms
```

## Part 2: OAuth 2.0/OIDC Implementation (45 minutes)

### Task 2.1: Backend API with JWT Validation

```python
# app/main.py
from flask import Flask, request, jsonify, g
from functools import wraps
import jwt
import requests
from jwt import PyJWKClient

app = Flask(__name__)

KEYCLOAK_URL = "http://keycloak:8080"
REALM = "myapp"
JWKS_URL = f"{KEYCLOAK_URL}/realms/{REALM}/protocol/openid-connect/certs"

# Cache JWKS client
jwks_client = PyJWKClient(JWKS_URL)

def get_token_from_header():
    auth_header = request.headers.get('Authorization', '')
    if auth_header.startswith('Bearer '):
        return auth_header[7:]
    return None

def validate_token(token):
    try:
        signing_key = jwks_client.get_signing_key_from_jwt(token)
        decoded = jwt.decode(
            token,
            signing_key.key,
            algorithms=["RS256"],
            audience="account",
            issuer=f"{KEYCLOAK_URL}/realms/{REALM}"
        )
        return decoded
    except jwt.exceptions.InvalidTokenError as e:
        return None

def require_auth(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        token = get_token_from_header()
        if not token:
            return jsonify({"error": "Missing authorization token"}), 401

        claims = validate_token(token)
        if not claims:
            return jsonify({"error": "Invalid token"}), 401

        g.user = claims
        return f(*args, **kwargs)
    return decorated

def require_role(role):
    def decorator(f):
        @wraps(f)
        def decorated(*args, **kwargs):
            if not hasattr(g, 'user'):
                return jsonify({"error": "Unauthorized"}), 401

            user_roles = g.user.get('realm_access', {}).get('roles', [])
            if role not in user_roles:
                return jsonify({"error": "Forbidden - insufficient permissions"}), 403

            return f(*args, **kwargs)
        return decorated
    return decorator

@app.route('/api/public')
def public():
    return jsonify({"message": "Public endpoint"})

@app.route('/api/user')
@require_auth
def user_info():
    return jsonify({
        "user": g.user.get('preferred_username'),
        "email": g.user.get('email'),
        "roles": g.user.get('realm_access', {}).get('roles', [])
    })

@app.route('/api/admin')
@require_auth
@require_role('admin')
def admin_only():
    return jsonify({"message": "Admin content", "user": g.user.get('preferred_username')})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
```

### Task 2.2: Frontend OIDC Integration

```javascript
// frontend/src/auth.js
import Keycloak from 'keycloak-js';

const keycloak = new Keycloak({
  url: 'http://localhost:8080',
  realm: 'myapp',
  clientId: 'webapp'
});

export const initKeycloak = (onAuthenticatedCallback) => {
  keycloak.init({
    onLoad: 'check-sso',
    silentCheckSsoRedirectUri: window.location.origin + '/silent-check-sso.html',
    pkceMethod: 'S256'
  })
  .then((authenticated) => {
    if (authenticated) {
      console.log('User authenticated');
      onAuthenticatedCallback();
    } else {
      console.log('User not authenticated');
    }
  })
  .catch((error) => {
    console.error('Keycloak init error:', error);
  });
};

export const doLogin = keycloak.login;
export const doLogout = keycloak.logout;
export const getToken = () => keycloak.token;
export const isAuthenticated = () => keycloak.authenticated;
export const getUsername = () => keycloak.tokenParsed?.preferred_username;
export const hasRole = (role) => keycloak.hasRealmRole(role);

export const updateToken = (minValidity) => {
  return keycloak.updateToken(minValidity);
};

// Axios interceptor for adding token
export const setupAxiosInterceptor = (axios) => {
  axios.interceptors.request.use(
    async (config) => {
      if (keycloak.authenticated) {
        await updateToken(30);
        config.headers.Authorization = `Bearer ${keycloak.token}`;
      }
      return config;
    },
    (error) => Promise.reject(error)
  );
};

export default keycloak;
```

## Part 3: RBAC Implementation (45 minutes)

### Task 3.1: Kubernetes RBAC for Users

```yaml
# rbac/user-roles.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: developer
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
- apiGroups: [""]
  resources: ["pods/log", "pods/exec"]
  verbs: ["get", "create"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: developers-binding
subjects:
- kind: Group
  name: "developers"
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: developer
  apiGroup: rbac.authorization.k8s.io
```

### Task 3.2: OIDC Authentication for Kubernetes

```yaml
# Configure kube-apiserver with OIDC flags
# /etc/kubernetes/manifests/kube-apiserver.yaml (add to command)
spec:
  containers:
  - command:
    - kube-apiserver
    - --oidc-issuer-url=http://keycloak:8080/realms/myapp
    - --oidc-client-id=kubernetes
    - --oidc-username-claim=preferred_username
    - --oidc-groups-claim=groups
    - --oidc-ca-file=/etc/kubernetes/pki/oidc-ca.crt
```

```bash
# Configure kubectl for OIDC
kubectl config set-credentials oidc-user \
  --exec-api-version=client.authentication.k8s.io/v1beta1 \
  --exec-command=kubectl \
  --exec-arg=oidc-login \
  --exec-arg=get-token \
  --exec-arg=--oidc-issuer-url=http://keycloak:8080/realms/myapp \
  --exec-arg=--oidc-client-id=kubernetes \
  --exec-arg=--oidc-client-secret=kubernetes-secret
```

## Part 4: OPA/ABAC Authorization (45 minutes)

### Task 4.1: Deploy OPA Gatekeeper

```bash
# Install Gatekeeper
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.14/deploy/gatekeeper.yaml
```

### Task 4.2: Create Constraint Templates

```yaml
# opa/require-owner-label.yaml
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8srequireowner
spec:
  crd:
    spec:
      names:
        kind: K8sRequireOwner
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequireowner

        violation[{"msg": msg}] {
          not input.review.object.metadata.labels.owner
          msg := "Resources must have an owner label"
        }
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequireOwner
metadata:
  name: require-owner-label
spec:
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
      - apiGroups: ["apps"]
        kinds: ["Deployment"]
```

### Task 4.3: OPA for API Authorization

```rego
# policy/authz.rego
package authz

default allow = false

# Allow admins everything
allow {
    input.user.roles[_] == "admin"
}

# Users can read their own data
allow {
    input.method == "GET"
    input.path = ["api", "users", user_id]
    input.user.sub == user_id
}

# Developers can access development resources
allow {
    input.user.roles[_] == "developer"
    input.resource.environment == "development"
}

# Time-based access
allow {
    input.user.roles[_] == "operator"
    is_business_hours
}

is_business_hours {
    now := time.clock([time.now_ns(), "America/New_York"])
    now[0] >= 9
    now[0] < 17
}
```

## Verification

Complete the following checklist:

- [ ] Deployed and configured Keycloak
- [ ] Created realm with users and roles
- [ ] Implemented JWT validation in backend
- [ ] Configured frontend OIDC flow
- [ ] Set up Kubernetes RBAC
- [ ] Deployed OPA Gatekeeper
- [ ] Created ABAC policies with OPA

## Summary

In this lab, you:
- Deployed Keycloak as identity provider
- Implemented OAuth 2.0/OIDC authentication
- Created RBAC policies for Kubernetes
- Implemented ABAC with OPA

## Next Steps

- Lab 8: Compliance as Code
- Review OAuth 2.0 Security Best Practices
- Study Zero Trust Architecture

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Keycloak Setup
- OAuth 2.0/OIDC Implementation
- RBAC Implementation
- OPA/ABAC Authorization

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
