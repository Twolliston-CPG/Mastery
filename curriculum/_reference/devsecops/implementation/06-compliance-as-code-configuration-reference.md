# Compliance as Code -- Configuration Reference

## Table of Contents

1. [OSCAL Document Structure](#oscal-document-structure)
2. [DefectDojo Configuration](#defectdojo-configuration)
3. [Dependency-Track Configuration](#dependency-track-configuration)
4. [CISO Assistant Configuration](#ciso-assistant-configuration)
5. [Script Parameters](#script-parameters)
6. [Workflow Configuration](#workflow-configuration)

---

## OSCAL Document Structure

### Component Definition Schema

Component definitions map technical implementations to compliance controls. Each component definition file follows this structure:

```json
{
  "component-definition": {
    "uuid": "<unique-uuid>",
    "metadata": {
      "title": "Component Title",
      "last-modified": "2025-01-01T00:00:00Z",
      "version": "1.0.0",
      "oscal-version": "1.1.2",
      "roles": [
        { "id": "provider", "title": "Security Policy Provider" }
      ],
      "parties": [
        {
          "uuid": "<party-uuid>",
          "type": "organization",
          "name": "{{ORG_NAME}} Platform Team"
        }
      ]
    },
    "components": [
      {
        "uuid": "<component-uuid>",
        "type": "policy | software",
        "title": "Component Title",
        "description": "What this component does",
        "props": [
          { "name": "implementation-status", "value": "implemented" },
          { "name": "source-file", "value": "path/to/source.rego" }
        ],
        "control-implementations": [
          {
            "uuid": "<impl-uuid>",
            "source": "https://...catalog-url... | soc2-trust-services-criteria | iso-27001-2022",
            "description": "Framework description",
            "implemented-requirements": [
              {
                "uuid": "<req-uuid>",
                "control-id": "ac-6",
                "description": "How this implementation satisfies the control"
              }
            ]
          }
        ]
      }
    ]
  }
}
```

**Component Types**:
- `policy`: OPA/Rego policies enforced via admission controllers
- `software`: Security tools integrated into CI/CD pipelines

**Control Implementation Sources**:
- NIST 800-53: `https://raw.githubusercontent.com/usnistgov/oscal-content/main/nist.gov/SP800-53/rev5/json/NIST_SP-800-53_rev5_catalog.json`
- SOC2: `soc2-trust-services-criteria`
- ISO 27001: `iso-27001-2022`

### Profile Schema

Profiles tailor a catalog to organizational requirements:

```json
{
  "profile": {
    "uuid": "<profile-uuid>",
    "metadata": {
      "title": "{{APP_NAME}} SOC2 Type II Security Profile",
      "last-modified": "2025-01-01T00:00:00Z",
      "version": "1.0.0",
      "oscal-version": "1.1.2"
    },
    "imports": [
      {
        "href": "https://...catalog-url...",
        "include-controls": [
          { "with-ids": ["ac-2", "ac-3", "..."] }
        ]
      }
    ],
    "merge": {
      "combine": { "method": "merge" },
      "as-is": true
    },
    "modify": {
      "set-parameters": [
        {
          "param-id": "ra-5_prm_1",
          "values": ["daily for critical systems"]
        }
      ],
      "alters": [
        {
          "control-id": "ra-5",
          "adds": [
            {
              "position": "ending",
              "parts": [
                {
                  "id": "ra-5_impl",
                  "name": "implementation",
                  "prose": "Organization-specific implementation details"
                }
              ]
            }
          ]
        }
      ]
    }
  }
}
```

### System Security Plan Schema

```json
{
  "system-security-plan": {
    "uuid": "<ssp-uuid>",
    "metadata": { "...same as above..." },
    "import-profile": {
      "href": "../../profiles/{{APP_NAME}}-production/profile.json"
    },
    "system-characteristics": {
      "system-ids": [{ "id": "{{APP_NAME}}-platform-prod" }],
      "system-name": "{{APP_NAME}} Platform",
      "description": "System description",
      "security-sensitivity-level": "moderate",
      "system-information": {
        "information-types": [
          {
            "uuid": "<info-type-uuid>",
            "title": "Information Type Name",
            "confidentiality-impact": { "base": "moderate" },
            "integrity-impact": { "base": "moderate" },
            "availability-impact": { "base": "low" }
          }
        ]
      },
      "security-impact-level": {
        "security-objective-confidentiality": "moderate",
        "security-objective-integrity": "moderate",
        "security-objective-availability": "moderate"
      },
      "status": { "state": "operational" },
      "authorization-boundary": { "description": "..." },
      "network-architecture": { "description": "..." },
      "data-flow": { "description": "..." }
    },
    "system-implementation": {
      "users": [ "..." ],
      "components": [ "..." ]
    },
    "control-implementation": {
      "description": "...",
      "implemented-requirements": [
        {
          "uuid": "<req-uuid>",
          "control-id": "ac-2",
          "statements": [
            {
              "statement-id": "ac-2_smt",
              "uuid": "<stmt-uuid>",
              "description": "How the control is implemented"
            }
          ]
        }
      ]
    }
  }
}
```

### Assessment Results Schema

```json
{
  "assessment-results": {
    "uuid": "<ar-uuid>",
    "metadata": { "...standard metadata..." },
    "import-ap": { "href": "#assessment-plan" },
    "results": [
      {
        "uuid": "<result-uuid>",
        "title": "Assessment Results - YYYY-MM-DD",
        "start": "2025-01-01T02:00:00Z",
        "end": "2025-01-01T02:00:00Z",
        "props": [
          { "name": "total-findings", "value": "5" },
          { "name": "findings-not-satisfied", "value": "0" },
          { "name": "compliance-score", "value": "100.0%" }
        ],
        "findings": [
          {
            "uuid": "<finding-uuid>",
            "title": "Finding Title",
            "description": "Finding details",
            "target": {
              "type": "objective-id",
              "target-id": "ra-5",
              "status": { "state": "satisfied | not-satisfied | partially-satisfied" }
            }
          }
        ],
        "observations": [
          {
            "uuid": "<obs-uuid>",
            "title": "Observation Title",
            "description": "...",
            "methods": ["AUTOMATED"],
            "collected": "2025-01-01T02:00:00Z"
          }
        ]
      }
    ]
  }
}
```

---

## DefectDojo Configuration

### ConfigMap (`defectdojo-config`)

| Key | Default | Description |
|-----|---------|-------------|
| `DD_DEBUG` | `False` | Django debug mode (never enable in production) |
| `DD_DJANGO_ADMIN_ENABLED` | `True` | Enable Django admin interface |
| `DD_ALLOWED_HOSTS` | `defectdojo.{{APP_NAME}}.internal,localhost,*` | Allowed HTTP host headers |
| `DD_TIME_ZONE` | `UTC` | Application time zone |
| `DD_DATABASE_ENGINE` | `django.db.backends.postgresql` | Database backend |
| `DD_DATABASE_NAME` | `defectdojo` | PostgreSQL database name |
| `DD_DATABASE_USER` | `defectdojo` | PostgreSQL username |
| `DD_DATABASE_HOST` | `defectdojo-db` | PostgreSQL service name |
| `DD_DATABASE_PORT` | `5432` | PostgreSQL port |
| `DD_CELERY_BROKER_URL` | `redis://defectdojo-redis:6379/0` | Redis broker URL |
| `DD_CELERY_RESULT_BACKEND` | `redis://defectdojo-redis:6379/0` | Redis result backend |
| `DD_CSRF_TRUSTED_ORIGINS` | `https://defectdojo.{{APP_NAME}}.internal` | CSRF trusted origins |
| `DD_SECURE_SSL_REDIRECT` | `False` | SSL redirect (handle at ingress) |
| `DD_SESSION_COOKIE_SECURE` | `True` | Secure session cookies |
| `DD_CSRF_COOKIE_SECURE` | `True` | Secure CSRF cookies |
| `DD_SOCIAL_AUTH_GOOGLE_OAUTH2_ENABLED` | `False` | Google OAuth2 |
| `DD_WHITENOISE_ENABLED` | `True` | Static file serving |
| `DD_UWSGI_NUM_OF_PROCESSES` | `2` | uWSGI process count |
| `DD_UWSGI_NUM_OF_THREADS` | `2` | uWSGI thread count |

### Secret (`defectdojo-secrets`)

| Key | Description |
|-----|-------------|
| `DD_SECRET_KEY` | Django secret key (generate a unique 64+ character random string) |
| `DD_DATABASE_PASSWORD` | PostgreSQL password |
| `DD_CREDENTIAL_AES_256_KEY` | AES-256 key for credential encryption (32 hex characters) |
| `DD_ADMIN_USER` | Initial admin username |
| `DD_ADMIN_PASSWORD` | Initial admin password (change after first login) |
| `DD_ADMIN_MAIL` | Admin email address |

### Service Configuration

| Service | Type | Port | NodePort | Target |
|---------|------|------|----------|--------|
| `defectdojo` | NodePort | 8080 | 30080 | Django uwsgi |
| `defectdojo-internal` | ClusterIP | 8080 | -- | Django uwsgi |
| `defectdojo-db` | ClusterIP (headless) | 5432 | -- | PostgreSQL |
| `defectdojo-redis` | ClusterIP | 6379 | -- | Redis |

### Health Checks

| Component | Liveness | Readiness |
|-----------|----------|-----------|
| Django | GET `/login?force_login_form` :8080 (120s init, 30s period) | GET `/login?force_login_form` :8080 (60s init, 10s period) |
| PostgreSQL | `pg_isready -U defectdojo` (30s init, 10s period) | `pg_isready -U defectdojo` (5s init, 5s period) |
| Redis | `redis-cli ping` (10s init, 10s period) | `redis-cli ping` (5s init, 5s period) |

---

## Dependency-Track Configuration

### Helm Values (via HelmRelease)

| Parameter | Value | Description |
|-----------|-------|-------------|
| `apiserver.image.repository` | `dependencytrack/apiserver` | API server image |
| `apiserver.image.tag` | `4.10.1` | API server version |
| `apiserver.resources.requests.memory` | `2Gi` | Minimum memory (DTrack is memory-heavy) |
| `apiserver.resources.limits.memory` | `4Gi` | Maximum memory |
| `apiserver.persistentVolume.size` | `10Gi` | Data persistence volume |
| `frontend.image.tag` | `4.10.1` | Frontend version |
| `postgresql.auth.username` | `dtrack` | Database username |
| `postgresql.auth.database` | `dtrack` | Database name |
| `postgresql.primary.persistence.size` | `10Gi` | Database storage |
| `service.type` | `ClusterIP` | Internal service type |
| `service.port` | `8080` | API server port |
| `serviceMonitor.enabled` | `true` | Prometheus monitoring |

### Environment Variables

| Variable | Value | Description |
|----------|-------|-------------|
| `ALPINE_DATABASE_MODE` | `external` | Use external PostgreSQL |
| `ALPINE_DATABASE_URL` | `jdbc:postgresql://dependency-track-postgresql:5432/dtrack` | JDBC connection URL |
| `ALPINE_DATABASE_DRIVER` | `org.postgresql.Driver` | JDBC driver class |
| `ALPINE_OIDC_ENABLED` | `false` | OIDC authentication (enable for SSO) |
| `ALPINE_ENFORCE_AUTHENTICATION` | `true` | Require API key for access |

### External Secrets [GCP-SPECIFIC]

| ExternalSecret | Secret Manager Key | Target Secret |
|----------------|-------------------|---------------|
| `dependency-track-db-credentials` | `{{APP_NAME}}-dtrack-db-username`, `{{APP_NAME}}-dtrack-db-password` | `dependency-track-db-credentials` |
| `dependency-track-api-key` | `{{APP_NAME}}-dtrack-api-key` | `dependency-track-api-key` |

### Service Configuration

| Service | Type | Port | NodePort |
|---------|------|------|----------|
| `dependency-track` (Helm) | ClusterIP | 8080 | -- |
| `dependency-track-external` | NodePort | 8080 | 30082 |

---

## CISO Assistant Configuration

### ConfigMap (`ciso-assistant-config`)

| Key | Default | Description |
|-----|---------|-------------|
| `DJANGO_SETTINGS_MODULE` | `ciso_assistant.settings` | Django settings module |
| `DJANGO_DEBUG` | `False` | Debug mode |
| `ALLOWED_HOSTS` | `ciso-assistant.{{APP_NAME}}.internal,localhost` | Allowed hosts |
| `POSTGRES_NAME` | `ciso_assistant` | Database name |
| `POSTGRES_USER` | `ciso_assistant` | Database username |
| `POSTGRES_HOST` | `ciso-assistant-db` | Database service |
| `POSTGRES_PORT` | `5432` | Database port |
| `CSRF_TRUSTED_ORIGINS` | `https://ciso-assistant.{{APP_NAME}}.internal` | CSRF origins |
| `SECURE_SSL_REDIRECT` | `False` | SSL redirect |
| `SESSION_COOKIE_SECURE` | `True` | Secure session cookies |
| `CSRF_COOKIE_SECURE` | `True` | Secure CSRF cookies |

### Secret (`ciso-assistant-secrets`)

| Key | Description |
|-----|-------------|
| `DJANGO_SECRET_KEY` | Django secret key (generate unique random string) |
| `POSTGRES_PASSWORD` | PostgreSQL password |
| `DJANGO_SUPERUSER_EMAIL` | Initial admin email |
| `DJANGO_SUPERUSER_PASSWORD` | Initial admin password (change after first login) |

### Service Configuration

| Service | Type | Port | NodePort | Target |
|---------|------|------|----------|--------|
| `ciso-assistant-backend` | ClusterIP | 8000 | -- | Backend API |
| `ciso-assistant-frontend` | ClusterIP | 3000 | -- | Frontend app |
| `ciso-assistant` | NodePort | 80 | 30081 | Frontend (external) |
| `ciso-assistant-db` | ClusterIP (headless) | 5432 | -- | PostgreSQL |

### Health Checks

| Component | Liveness | Readiness |
|-----------|----------|-----------|
| Backend | GET `/api/health/` :8000 (60s init, 30s period) | GET `/api/health/` :8000 (30s init, 10s period) |
| Frontend | GET `/` :3000 (30s init, 30s period) | GET `/` :3000 (10s init, 10s period) |
| PostgreSQL | `pg_isready -U ciso_assistant` (30s init, 10s period) | `pg_isready -U ciso_assistant` (5s init, 5s period) |

---

## Script Parameters

### collect-defectdojo-evidence.py

```
usage: collect-defectdojo-evidence.py [-h] --url URL --output OUTPUT

Environment: DEFECTDOJO_TOKEN (required)

Arguments:
  --url URL        DefectDojo base URL (e.g., http://defectdojo:30080)
  --output OUTPUT  Output directory for evidence files

Output files:
  defectdojo-summary.json       Findings summary with severity counts
  vulnerability-summary.json    Simplified vulnerability counts
  defectdojo-engagements.json   Recent security engagements
```

### collect-github-evidence.py

```
usage: collect-github-evidence.py [-h] --org ORG --output OUTPUT

Environment: GITHUB_TOKEN (required)

Arguments:
  --org ORG        GitHub organization name
  --output OUTPUT  Output directory for evidence files

Output files:
  github-alerts.json            Detailed alerts per repository
  vulnerability-summary.json    Summary with severity counts
```

### generate-assessment-results.py

```
usage: generate-assessment-results.py [-h] --ssp SSP --evidence EVIDENCE
                                       --output OUTPUT --timestamp TIMESTAMP

Arguments:
  --ssp SSP             SSP JSON file path
  --evidence EVIDENCE   Evidence directory path
  --output OUTPUT       Output assessment results JSON file
  --timestamp TIMESTAMP Assessment timestamp (ISO 8601)
```

### generate-assessment-summary.py

```
usage: generate-assessment-summary.py [-h] --results RESULTS --output OUTPUT

Arguments:
  --results RESULTS  Assessment results JSON file
  --output OUTPUT    Output summary markdown file
```

### generate-control-matrix.py

```
usage: generate-control-matrix.py [-h] --components COMPONENTS --output OUTPUT

Arguments:
  --components, -c COMPONENTS  Component definitions directory
  --output, -o OUTPUT          Output control matrix markdown file
```

### generate-ssp-markdown.py

```
usage: generate-ssp-markdown.py [-h] --input INPUT --output OUTPUT

Arguments:
  --input, -i INPUT    SSP JSON file path
  --output, -o OUTPUT  Output directory for markdown files

Output files:
  ssp-overview.md              Main SSP document
  control-implementations.md   Detailed control implementation statements
```

### sync-defectdojo-to-assessment.py

```
usage: sync-defectdojo-to-assessment.py [-h] --defectdojo-url URL
                                         --output OUTPUT [--existing EXISTING]

Environment: DEFECTDOJO_TOKEN (required)

Arguments:
  --defectdojo-url URL  DefectDojo base URL
  --output OUTPUT       Output assessment results JSON file
  --existing EXISTING   Existing assessment results to update (optional)
```

### sync-to-ciso-assistant.py

```
usage: sync-to-ciso-assistant.py [-h] --url URL --components COMPONENTS
                                  [--assessment ASSESSMENT] [--project PROJECT]

Environment: CISO_ASSISTANT_TOKEN (required)

Arguments:
  --url URL                CISO Assistant base URL
  --components COMPONENTS  Component definitions directory
  --assessment ASSESSMENT  Assessment results file (optional)
  --project PROJECT        Project name (default: "{{APP_NAME}} Platform")
```

---

## Workflow Configuration

### GitHub Actions Secrets Required

| Secret | Used By | Description |
|--------|---------|-------------|
| `DEFECTDOJO_TOKEN` | trestle-assess, trestle-sync-tools | DefectDojo API token |
| `CISO_ASSISTANT_TOKEN` | trestle-sync-tools | CISO Assistant API token |
| `GITHUB_TOKEN` | trestle-assess | Auto-provided by GitHub Actions |

### GitHub Actions Variables Required

| Variable | Used By | Description |
|----------|---------|-------------|
| `DEFECTDOJO_URL` | trestle-assess, trestle-sync-tools | DefectDojo base URL |
| `CISO_ASSISTANT_URL` | trestle-sync-tools | CISO Assistant base URL |

### Python Dependencies

| Package | Version | Used By |
|---------|---------|---------|
| `compliance-trestle` | latest | All validation and assembly workflows |
| `requests` | latest | DefectDojo, CISO Assistant, GitHub API scripts |
| `pyyaml` | latest | Evidence loading (YAML format) |
| `jinja2` | latest | SSP assembly (template rendering) |

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- OSCAL Document Structure
- DefectDojo Configuration
- Dependency-Track Configuration
- CISO Assistant Configuration

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
