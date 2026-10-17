# API Security for Threat Modeling

## Overview

APIs are the backbone of modern applications and a primary attack surface. This guide covers API-specific threats and how to model them effectively.

---

## API Threat Landscape

### OWASP API Security Top 10 (2023)

| Rank | Vulnerability | Description |
|------|---------------|-------------|
| API1 | Broken Object Level Authorization (BOLA) | Access other users' resources |
| API2 | Broken Authentication | Weak/missing authentication |
| API3 | Broken Object Property Level Authorization | Expose/modify object properties |
| API4 | Unrestricted Resource Consumption | No rate limiting |
| API5 | Broken Function Level Authorization | Access admin functions |
| API6 | Unrestricted Access to Sensitive Business Flows | Abuse business logic |
| API7 | Server Side Request Forgery (SSRF) | Make requests to internal resources |
| API8 | Security Misconfiguration | Insecure defaults |
| API9 | Improper Inventory Management | Shadow/zombie APIs |
| API10 | Unsafe Consumption of APIs | Trusting third-party APIs |

---

## API Threat Modeling Framework

### 1. Identify API Endpoints

```yaml
api_inventory:
  - endpoint: POST /api/v1/auth/login
    authentication: None (public)
    authorization: N/A
    data: Credentials
    rate_limit: 5/min

  - endpoint: GET /api/v1/users/{id}
    authentication: JWT
    authorization: User can access own data
    data: PII
    rate_limit: 100/min

  - endpoint: POST /api/v1/orders
    authentication: JWT
    authorization: Authenticated user
    data: Payment info
    rate_limit: 10/min

  - endpoint: DELETE /api/v1/admin/users/{id}
    authentication: JWT + MFA
    authorization: Admin role
    data: User deletion
    rate_limit: 5/min
```

### 2. Map STRIDE to API Endpoints

```yaml
endpoint: GET /api/v1/users/{id}

threats:
  spoofing:
    - JWT token theft
    - Session hijacking
    - API key compromise

  tampering:
    - Parameter manipulation (change {id})
    - Request body modification
    - Header injection

  repudiation:
    - Missing audit logs
    - Log injection

  information_disclosure:
    - Excessive data in response
    - Error message leakage
    - BOLA (access other user's data)

  denial_of_service:
    - No rate limiting
    - Large response payloads
    - Resource exhaustion

  elevation_of_privilege:
    - Role manipulation in token
    - Admin function access
    - BFLA
```

---

## Common API Vulnerabilities

### BOLA (Broken Object Level Authorization)

```python
# VULNERABLE
@app.route('/api/orders/<order_id>')
def get_order(order_id):
    order = Order.query.get(order_id)  # No ownership check!
    return jsonify(order.to_dict())

# SECURE
@app.route('/api/orders/<order_id>')
@jwt_required
def get_order(order_id):
    current_user = get_jwt_identity()
    order = Order.query.get(order_id)

    # Verify ownership
    if order.user_id != current_user['id']:
        return jsonify({'error': 'Forbidden'}), 403

    return jsonify(order.to_dict())
```

### BFLA (Broken Function Level Authorization)

```python
# VULNERABLE - No role check
@app.route('/api/admin/users/<user_id>', methods=['DELETE'])
@jwt_required
def delete_user(user_id):
    user = User.query.get(user_id)
    db.session.delete(user)  # Any authenticated user can delete!
    return jsonify({'status': 'deleted'})

# SECURE - Role verification
@app.route('/api/admin/users/<user_id>', methods=['DELETE'])
@jwt_required
@admin_required  # Decorator checks admin role
def delete_user(user_id):
    user = User.query.get(user_id)
    db.session.delete(user)
    return jsonify({'status': 'deleted'})
```

### Mass Assignment

```python
# VULNERABLE
@app.route('/api/users/me', methods=['PUT'])
@jwt_required
def update_user():
    user = current_user
    data = request.get_json()
    for key, value in data.items():
        setattr(user, key, value)  # Can set 'is_admin': true!
    db.session.commit()
    return jsonify(user.to_dict())

# SECURE - Explicit allowed fields
ALLOWED_FIELDS = ['name', 'email', 'phone']

@app.route('/api/users/me', methods=['PUT'])
@jwt_required
def update_user():
    user = current_user
    data = request.get_json()
    for key, value in data.items():
        if key in ALLOWED_FIELDS:
            setattr(user, key, value)
    db.session.commit()
    return jsonify(user.to_dict())
```

---

## Authentication Security

### JWT Threats

```yaml
jwt_threats:
  - name: Algorithm confusion
    attack: Change alg to 'none' or HS256 with public key
    mitigation: Explicit algorithm validation

  - name: Token theft
    attack: XSS, logging, network interception
    mitigation: HttpOnly cookies, short expiry

  - name: Weak signing key
    attack: Brute force HMAC secret
    mitigation: Strong key, RS256 asymmetric

  - name: Token replay
    attack: Reuse stolen token
    mitigation: Short expiry, token binding

  - name: Claim manipulation
    attack: Modify claims if signature weak
    mitigation: Signature verification
```

### Secure JWT Implementation

```python
import jwt
from datetime import datetime, timedelta

# Configuration
JWT_ALGORITHM = 'RS256'  # Use asymmetric
JWT_EXPIRY_MINUTES = 15  # Short-lived
JWT_ISSUER = 'https://api.example.com'
JWT_AUDIENCE = 'https://api.example.com'

def create_token(user):
    payload = {
        'sub': str(user.id),
        'iat': datetime.utcnow(),
        'exp': datetime.utcnow() + timedelta(minutes=JWT_EXPIRY_MINUTES),
        'iss': JWT_ISSUER,
        'aud': JWT_AUDIENCE,
        'jti': str(uuid.uuid4()),  # Unique ID for revocation
        'roles': user.roles
    }
    return jwt.encode(payload, PRIVATE_KEY, algorithm=JWT_ALGORITHM)

def verify_token(token):
    try:
        payload = jwt.decode(
            token,
            PUBLIC_KEY,
            algorithms=[JWT_ALGORITHM],  # Explicit algorithm
            issuer=JWT_ISSUER,
            audience=JWT_AUDIENCE,
            options={'require': ['exp', 'iat', 'sub', 'iss', 'aud']}
        )
        return payload
    except jwt.InvalidTokenError:
        return None
```

---

## Rate Limiting

### Strategy by Endpoint Type

| Endpoint Type | Rate Limit | Window | By |
|---------------|------------|--------|-----|
| Login | 5 | 15 min | IP + Account |
| Password reset | 3 | 1 hour | Account |
| Standard API | 100 | 1 min | API Key/User |
| Search | 20 | 1 min | User |
| File upload | 10 | 1 hour | User |
| Admin actions | 30 | 1 min | User |

### Implementation

```python
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address

limiter = Limiter(
    app,
    key_func=get_remote_address,
    default_limits=["100 per minute"]
)

@app.route('/api/auth/login', methods=['POST'])
@limiter.limit("5 per 15 minutes", key_func=lambda: request.json.get('email'))
def login():
    # Login logic
    pass

@app.route('/api/search')
@limiter.limit("20 per minute")
def search():
    # Search logic
    pass
```

---

## Input Validation

### Validation Strategy

```python
from pydantic import BaseModel, validator, constr
from typing import Optional
import re

class CreateUserRequest(BaseModel):
    email: constr(max_length=255)
    password: constr(min_length=12, max_length=128)
    name: constr(min_length=1, max_length=100)
    phone: Optional[str]

    @validator('email')
    def validate_email(cls, v):
        if not re.match(r'^[\w\.-]+@[\w\.-]+\.\w+$', v):
            raise ValueError('Invalid email format')
        return v.lower()

    @validator('phone')
    def validate_phone(cls, v):
        if v and not re.match(r'^\+?[1-9]\d{1,14}$', v):
            raise ValueError('Invalid phone format')
        return v

    @validator('name')
    def validate_name(cls, v):
        if re.search(r'[<>"\']', v):  # Prevent XSS
            raise ValueError('Invalid characters in name')
        return v.strip()
```

---

## API Threat Model Template

```yaml
api: Customer Management API
version: v2
base_url: https://api.example.com/v2

authentication:
  type: JWT (RS256)
  token_expiry: 15 minutes
  refresh_mechanism: Refresh token (7 days)

endpoints:
  - path: POST /auth/login
    threats:
      - Credential stuffing (API4)
      - Brute force (API2)
    controls:
      - Rate limiting: 5/15min per IP+email
      - Account lockout after 5 failures
      - CAPTCHA after 3 failures

  - path: GET /users/{id}
    threats:
      - BOLA (API1): Access other user data
      - Information disclosure (API3)
    controls:
      - Object-level authorization check
      - Response filtering (no sensitive fields)

  - path: PUT /users/{id}
    threats:
      - BOLA (API1): Modify other user
      - Mass assignment (API3): Modify admin fields
    controls:
      - Ownership verification
      - Whitelist of modifiable fields

  - path: POST /orders
    threats:
      - Price manipulation
      - Inventory manipulation
      - Replay attacks
    controls:
      - Server-side price calculation
      - Inventory lock during checkout
      - Idempotency keys

global_controls:
  - TLS 1.3 required
  - CORS restricted to known origins
  - Request size limits (1MB)
  - Response size limits (10MB)
  - Security headers (CSP, HSTS, etc.)
```

---

## API Security Checklist

```
Authentication:
□ Strong authentication mechanism
□ Secure token storage and transmission
□ Token expiration and refresh
□ MFA for sensitive operations
□ Session invalidation on logout

Authorization:
□ Object-level authorization (BOLA)
□ Function-level authorization (BFLA)
□ Property-level authorization
□ Role-based access control
□ Consistent authorization across endpoints

Input Validation:
□ Schema validation for all inputs
□ Type checking
□ Length limits
□ Format validation
□ Reject unknown fields

Rate Limiting:
□ Per-endpoint limits
□ Per-user/API key limits
□ Authentication endpoint protection
□ Graceful degradation
□ Rate limit headers

Data Protection:
□ Minimal data in responses
□ No sensitive data in URLs
□ Encryption in transit (TLS)
□ Sensitive data masking in logs
□ Proper error handling (no stack traces)

API Security Headers:
□ Content-Type validation
□ CORS properly configured
□ Security headers set
□ No version info exposure
□ Proper cache headers
```

---

## Next Steps

→ [Cloud Security](content-03-technical-skills-cloud-security.md)
→ [Return to Technical Skills](threat-modeling-roadmap.md#technical-skills)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- API Threat Landscape
- API Threat Modeling Framework
- Common API Vulnerabilities
- Authentication Security

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"We scan for vulnerabilities in the pipeline."* |
| ✓ | *"SAST reads source without running it, SCA resolves the dependency tree against an advisory database, and image scanning compares installed package versions to that same database. All three report what was known at build time — which is why the registry is re-scanned: the image does not change, the database does."* |

**Trace it:** A CVE published today against your base image → a blocked deploy. Name every component between the advisory and the refused `apply`.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** the [SLSA threat model](https://slsa.dev/spec/v1.2/threats) — it names every point at which a build can be subverted, and most teams defend three of them.
Full list per domain: [`SOURCES.md`](../../SOURCES.md#devsecops)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../../MASTERY.md)

<!-- /feynman-check -->
