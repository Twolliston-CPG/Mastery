# Threagile: Threat Modeling as Code

## Overview

Threagile is an open-source threat modeling tool that allows you to define your architecture as YAML code and automatically generate threat models, risk assessments, and security reports.

**Key Benefits for DevSecOps:**
- Infrastructure as Code approach to threat modeling
- CI/CD integration for automated security analysis
- Version-controlled threat models
- Consistent, repeatable threat identification
- Multiple output formats (PDF, Excel, JSON)

---

## Installation

### Docker (Recommended)

```bash
# Pull the latest image
docker pull threagile/threagile

# Run Threagile
docker run --rm -it \
  -v "$(pwd)":/app/work \
  threagile/threagile

# Create a new model
docker run --rm -it \
  -v "$(pwd)":/app/work \
  threagile/threagile create-stub-model --output /app/work/threagile.yaml

# Analyze a model
docker run --rm -it \
  -v "$(pwd)":/app/work \
  threagile/threagile analyze-model \
    --model /app/work/threagile.yaml \
    --output /app/work/output
```

### Binary Installation

```bash
# Download from GitHub releases
# https://github.com/Threagile/threagile/releases

# Linux
wget https://github.com/Threagile/threagile/releases/latest/download/threagile-linux-amd64
chmod +x threagile-linux-amd64
sudo mv threagile-linux-amd64 /usr/local/bin/threagile

# macOS
brew install threagile
```

---

## Model Structure

### Basic YAML Structure

```yaml
threagile_version: 1.0.0

title: My Application Threat Model
date: 2026-01-17

author:
  name: Security Team
  homepage: https://example.com

management_summary_comment: >
  This threat model covers the core application architecture.

business_criticality: critical  # archive, operational, important, critical, mission-critical

business_overview:
  description: E-commerce platform processing customer orders
  images:
    - architecture-overview.png

technical_overview:
  description: Cloud-native microservices on Kubernetes
  images:
    - technical-architecture.png

questions:
  How are secrets managed?: Using HashiCorp Vault with Kubernetes integration
  What encryption is used?: AES-256 for data at rest, TLS 1.3 in transit

abuse_cases:
  Attacker steals customer data: >
    An external attacker exploits a vulnerability to access
    the customer database and exfiltrate PII.
  Insider threat: >
    A malicious insider with database access exports
    customer records.

security_requirements:
  Input Validation: All user input must be validated
  Authentication: MFA required for admin access
  Encryption: All PII encrypted at rest

# Data Assets, Technical Assets, Trust Boundaries follow...
```

### Defining Data Assets

```yaml
data_assets:

  Customer PII:
    id: customer-pii
    description: Customer personal information
    usage: business
    tags:
      - pii
      - gdpr
    origin: Customer
    owner: Data Team
    quantity: many  # very-few, few, many, very-many
    confidentiality: confidential  # public, internal, restricted, confidential, strictly-confidential
    integrity: critical  # archive, operational, important, critical, mission-critical
    availability: operational
    justification_cia_rating: >
      Contains names, addresses, and email addresses.
      Must be protected under GDPR.

  Payment Card Data:
    id: payment-card-data
    description: Customer credit card information
    usage: business
    tags:
      - pci
      - financial
    origin: Customer
    owner: Payment Team
    quantity: many
    confidentiality: strictly-confidential
    integrity: mission-critical
    availability: critical
    justification_cia_rating: >
      PCI DSS regulated data. Breach would be catastrophic.

  Session Tokens:
    id: session-tokens
    description: User authentication session tokens
    usage: devops
    tags:
      - auth
    origin: Auth Service
    owner: Security Team
    quantity: very-many
    confidentiality: confidential
    integrity: critical
    availability: important
```

### Defining Technical Assets

```yaml
technical_assets:

  API Gateway:
    id: api-gateway
    description: Kong API Gateway handling all external traffic
    type: process
    usage: business
    used_as_client_by_human: false
    out_of_scope: false
    justification_out_of_scope:
    size: service  # system, service, application, component
    technology: web-service-rest
    tags:
      - kubernetes
      - kong
    internet: true
    machine: container
    encryption: none
    owner: Platform Team
    confidentiality: internal
    integrity: important
    availability: critical
    justification_cia_rating: Single point of entry, high availability needed
    multi_tenant: false
    redundant: true
    custom_developed_parts: false
    data_assets_processed:
      - customer-pii
      - session-tokens
    data_assets_stored:
    data_formats_accepted:
      - json
      - xml
    communication_links:
      API Gateway to Auth Service:
        target: auth-service
        description: Authentication validation
        protocol: https
        authentication: token
        authorization: technical-user
        tags:
        vpn: false
        ip_filtered: false
        readonly: true
        usage: business
        data_assets_sent:
          - session-tokens
        data_assets_received:
          - session-tokens

  Auth Service:
    id: auth-service
    description: Authentication and authorization service
    type: process
    usage: business
    used_as_client_by_human: false
    out_of_scope: false
    size: service
    technology: web-service-rest
    tags:
      - kubernetes
      - java
    internet: false
    machine: container
    encryption: none
    owner: Identity Team
    confidentiality: confidential
    integrity: critical
    availability: critical
    multi_tenant: false
    redundant: true
    custom_developed_parts: true
    data_assets_processed:
      - customer-pii
      - session-tokens
    data_assets_stored:
    communication_links:
      Auth Service to User DB:
        target: user-database
        description: User credential verification
        protocol: jdbc-encrypted
        authentication: credentials
        authorization: technical-user
        readonly: false
        data_assets_sent:
          - customer-pii
        data_assets_received:
          - customer-pii

  User Database:
    id: user-database
    description: PostgreSQL database for user accounts
    type: datastore
    usage: business
    out_of_scope: false
    size: component
    technology: database
    tags:
      - postgresql
      - rds
    internet: false
    machine: virtual
    encryption: data-with-symmetric-shared-key
    owner: DBA Team
    confidentiality: confidential
    integrity: critical
    availability: critical
    multi_tenant: false
    redundant: true
    custom_developed_parts: false
    data_assets_stored:
      - customer-pii
```

### Defining Trust Boundaries

```yaml
trust_boundaries:

  Internet Boundary:
    id: internet-boundary
    description: Boundary between internet and DMZ
    type: network-cloud-provider
    tags:
    technical_assets_inside:
      - api-gateway

  Internal Network:
    id: internal-network
    description: Internal application network
    type: network-cloud-security-group
    tags:
    technical_assets_inside:
      - auth-service
      - user-service
      - order-service

  Data Zone:
    id: data-zone
    description: Database tier
    type: network-cloud-security-group
    tags:
    technical_assets_inside:
      - user-database
      - order-database
```

---

## Running Analysis

### Command Line

```bash
# Basic analysis
threagile analyze-model --model threagile.yaml --output ./output

# With verbose output
threagile analyze-model \
  --model threagile.yaml \
  --output ./output \
  --verbose

# Generate specific outputs
threagile analyze-model \
  --model threagile.yaml \
  --output ./output \
  --generate-data-flow-diagram \
  --generate-data-asset-diagram \
  --generate-report-pdf

# List all available risk rules
threagile list-risk-rules

# Explain a specific risk
threagile explain-risk --risk-id sql-injection
```

### Output Files

**`output/`**

| File | What it is |
|---|---|
| `data-asset-diagram.png` | Visual data flow |
| `data-flow-diagram.png` | Component relationships |
| `risks.json` | Machine-readable risks |
| `risks.xlsx` | Excel risk report |
| `tags.xlsx` | Tag analysis |
| `technical-assets.json` | Asset inventory |
| `report.pdf` | Full threat report |


---

## CI/CD Integration

### GitHub Actions

```yaml
# .github/workflows/threat-model.yml
name: Threat Model Analysis

on:
  push:
    paths:
      - 'security/threagile.yaml'
      - '.github/workflows/threat-model.yml'
  pull_request:
    paths:
      - 'security/threagile.yaml'

jobs:
  analyze:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run Threagile Analysis
        run: |
          docker run --rm \
            -v "${{ github.workspace }}:/app/work" \
            threagile/threagile analyze-model \
              --model /app/work/security/threagile.yaml \
              --output /app/work/security/output

      - name: Check for High/Critical Risks
        run: |
          HIGH_RISKS=$(jq '[.[] | select(.severity == "high" or .severity == "critical")] | length' security/output/risks.json)
          if [ "$HIGH_RISKS" -gt 0 ]; then
            echo "Found $HIGH_RISKS high/critical risks!"
            jq '.[] | select(.severity == "high" or .severity == "critical")' security/output/risks.json
            exit 1
          fi

      - name: Upload Report
        uses: actions/upload-artifact@v4
        with:
          name: threat-model-report
          path: security/output/
```

### GitLab CI

```yaml
# .gitlab-ci.yml
threat-model:
  stage: security
  image: threagile/threagile:latest
  script:
    - threagile analyze-model
        --model security/threagile.yaml
        --output security/output
  artifacts:
    paths:
      - security/output/
    reports:
      # Custom parsing for GitLab security dashboard
  only:
    changes:
      - security/threagile.yaml
```

---

## Built-in Risk Rules

Threagile includes 40+ built-in risk rules:

### Authentication & Access

| Rule ID | Description |
|---------|-------------|
| `missing-authentication` | Service accessible without authentication |
| `missing-authentication-second-factor` | Sensitive service without MFA |
| `missing-authorization` | No authorization checks |
| `weak-authentication` | Weak authentication mechanism |

### Data Protection

| Rule ID | Description |
|---------|-------------|
| `unencrypted-asset` | Data stored without encryption |
| `unencrypted-communication` | Communication without encryption |
| `missing-vault` | Secrets not in secure vault |
| `accidental-secret-leak` | Potential secret exposure |

### Injection & Input

| Rule ID | Description |
|---------|-------------|
| `sql-injection` | SQL injection risk |
| `code-injection` | Code injection risk |
| `xml-external-entity` | XXE vulnerability risk |
| `path-traversal` | Path traversal risk |

### Infrastructure

| Rule ID | Description |
|---------|-------------|
| `container-platform-escape` | Container escape risk |
| `missing-network-segmentation` | Flat network detected |
| `missing-waf` | No Web Application Firewall |
| `server-side-request-forgery` | SSRF risk |

---

## Custom Risk Rules

### Creating Custom Rules

```yaml
# custom-rules/my-rule.yaml
id: gdpr-data-without-encryption
description: GDPR-regulated data stored without encryption
detection: |
  Check if data assets tagged with 'gdpr' are stored
  in technical assets without encryption.
severity: critical
exploitation_likelihood: likely
exploitation_impact: high
risk_category: data-protection
action: Encrypt all GDPR data at rest using AES-256
mitigation: |
  1. Enable encryption on database
  2. Use encrypted storage volumes
  3. Implement application-level encryption
check: |
  for each data_asset where tags contains 'gdpr':
    for each technical_asset that stores data_asset:
      if encryption is 'none':
        create_risk()
```

### Running with Custom Rules

```bash
threagile analyze-model \
  --model threagile.yaml \
  --custom-risk-rules-plugins ./custom-rules/ \
  --output ./output
```

---

## Example: Complete Model

```yaml
# Complete example for an e-commerce platform
threagile_version: 1.0.0
title: E-Commerce Platform Threat Model
date: 2026-01-17

author:
  name: Security Engineering
  homepage: https://example.com/security

business_criticality: critical

business_overview:
  description: |
    Online marketplace handling $10M+ monthly transactions.
    Processes customer PII and payment card data.

technical_overview:
  description: |
    Cloud-native architecture on AWS EKS.
    Microservices with API gateway pattern.

questions:
  What compliance frameworks apply?: PCI DSS Level 1, SOC 2 Type II
  How is cardholder data protected?: Tokenization via Stripe, no CHD storage

abuse_cases:
  Data Breach: Attacker exfiltrates customer database
  Payment Fraud: Attacker manipulates payment amounts
  Account Takeover: Attacker compromises customer accounts

security_requirements:
  Authentication: OAuth 2.0 with MFA for admin
  Encryption: TLS 1.3 in transit, AES-256 at rest
  Logging: All access logged to SIEM

data_assets:
  Customer PII:
    id: customer-pii
    description: Customer personal data
    usage: business
    tags: [pii, gdpr]
    origin: Customer
    owner: Data Team
    quantity: many
    confidentiality: confidential
    integrity: critical
    availability: operational
    justification_cia_rating: GDPR regulated personal data

  Order Data:
    id: order-data
    description: Customer orders and history
    usage: business
    tags: [business]
    origin: Customer
    owner: Order Team
    quantity: very-many
    confidentiality: internal
    integrity: critical
    availability: important

technical_assets:
  Load Balancer:
    id: load-balancer
    description: AWS ALB
    type: process
    usage: business
    size: service
    technology: load-balancer
    internet: true
    machine: serverless
    encryption: transparent
    owner: Platform Team
    confidentiality: public
    integrity: important
    availability: mission-critical
    redundant: true
    communication_links:
      LB to API Gateway:
        target: api-gateway
        protocol: https
        authentication: none
        readonly: true
        data_assets_sent: []
        data_assets_received: []

  API Gateway:
    id: api-gateway
    description: Kong API Gateway
    type: process
    usage: business
    size: service
    technology: web-service-rest
    internet: false
    machine: container
    encryption: none
    owner: Platform Team
    confidentiality: internal
    integrity: critical
    availability: critical
    redundant: true
    data_assets_processed: [customer-pii]
    communication_links:
      Gateway to Order Service:
        target: order-service
        protocol: https
        authentication: token
        data_assets_sent: [customer-pii, order-data]
        data_assets_received: [order-data]

  Order Service:
    id: order-service
    description: Order management microservice
    type: process
    usage: business
    size: service
    technology: web-service-rest
    tags: [kubernetes, java]
    internet: false
    machine: container
    encryption: none
    owner: Order Team
    confidentiality: internal
    integrity: critical
    availability: critical
    custom_developed_parts: true
    data_assets_processed: [customer-pii, order-data]
    communication_links:
      Order to Database:
        target: order-database
        protocol: jdbc-encrypted
        authentication: credentials
        data_assets_sent: [customer-pii, order-data]
        data_assets_received: [customer-pii, order-data]

  Order Database:
    id: order-database
    description: PostgreSQL on RDS
    type: datastore
    usage: business
    size: component
    technology: database
    tags: [rds, postgresql]
    internet: false
    machine: virtual
    encryption: data-with-symmetric-shared-key
    owner: DBA Team
    confidentiality: confidential
    integrity: critical
    availability: critical
    redundant: true
    data_assets_stored: [customer-pii, order-data]

trust_boundaries:
  Internet:
    id: internet
    type: network-cloud-provider
    technical_assets_inside: [load-balancer]

  DMZ:
    id: dmz
    type: network-cloud-security-group
    technical_assets_inside: [api-gateway]

  Application:
    id: application
    type: network-cloud-security-group
    technical_assets_inside: [order-service]

  Data:
    id: data
    type: network-cloud-security-group
    technical_assets_inside: [order-database]
```

---

## Key Takeaways

1. **Code-based approach** - Version control your threat models
2. **Automated analysis** - Consistent threat identification
3. **CI/CD integration** - Security gates in your pipeline
4. **Extensible** - Custom rules for your organization
5. **Multiple outputs** - Reports for different audiences

---

## Next Steps

→ [OWASP Threat Dragon Guide](threat-dragon.md)
→ [CI/CD Integration Patterns](cicd-integration.md)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Model Structure
- Running Analysis
- CI/CD Integration
- Built-in Risk Rules

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
