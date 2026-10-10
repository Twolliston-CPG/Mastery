# pytm: Pythonic Threat Modeling

## Overview

pytm is a Python library for threat modeling that allows you to define your system architecture in code and automatically generate data flow diagrams and threat analysis.

**Key Benefits:**
- Code-based threat models (version controlled)
- Automatic DFD generation
- Customizable threat library
- CI/CD integration
- Multiple output formats

---

## Installation

```bash
# Install via pip
pip install pytm

# Install with graphviz for diagram generation
# macOS
brew install graphviz

# Ubuntu/Debian
sudo apt-get install graphviz

# Windows
choco install graphviz
```

---

## Basic Usage

### Simple Example

```python
#!/usr/bin/env python3
from pytm import TM, Actor, Boundary, Datastore, Dataflow, Server

# Create threat model
tm = TM("Web Application Threat Model")
tm.description = "Threat model for customer portal"
tm.isOrdered = True

# Define trust boundaries
internet = Boundary("Internet")
dmz = Boundary("DMZ")
internal = Boundary("Internal Network")

# Define actors
user = Actor("User")
user.inBoundary = internet

# Define servers/processes
web_server = Server("Web Server")
web_server.inBoundary = dmz
web_server.OS = "Linux"
web_server.isHardened = True

api_server = Server("API Server")
api_server.inBoundary = internal
api_server.OS = "Linux"
api_server.protocol = "HTTPS"

# Define data stores
database = Datastore("Customer Database")
database.inBoundary = internal
database.isSQL = True
database.isShared = False

# Define data flows
user_to_web = Dataflow(user, web_server, "HTTPS Request")
user_to_web.protocol = "HTTPS"
user_to_web.isEncrypted = True

web_to_api = Dataflow(web_server, api_server, "API Call")
web_to_api.protocol = "HTTPS"
web_to_api.isEncrypted = True

api_to_db = Dataflow(api_server, database, "SQL Query")
api_to_db.protocol = "PostgreSQL"
api_to_db.isEncrypted = True

# Generate outputs
tm.process()
```

### Running the Model

```bash
# Generate DFD diagram
python threat_model.py --dfd

# Generate threat report
python threat_model.py --report report.md

# Generate sequence diagram
python threat_model.py --seq

# List all threats
python threat_model.py --list

# All outputs
python threat_model.py --dfd --seq --report threats.md
```

---

## Element Types

### Actors

```python
from pytm import Actor

# External user
user = Actor("Customer")
user.inBoundary = internet_boundary
user.levels = [1]  # Trust level

# Internal user
admin = Actor("Administrator")
admin.inBoundary = corporate_boundary
admin.levels = [2]

# Third party
partner = Actor("Partner API")
partner.inBoundary = internet_boundary
```

### Servers/Processes

```python
from pytm import Server, Process

# Web application
web_app = Server("Web Application")
web_app.OS = "Linux"
web_app.isHardened = True
web_app.sanitizesInput = True
web_app.encodesOutput = True
web_app.authorizesSource = True

# Lambda function
lambda_fn = Process("Data Processor")
lambda_fn.implementsAuthenticationScheme = True
lambda_fn.environment = "AWS Lambda"

# Microservice
auth_service = Server("Auth Service")
auth_service.protocol = "gRPC"
auth_service.usesEncryptionAlgorithm = "AES-256"
```

### Data Stores

```python
from pytm import Datastore

# SQL database
user_db = Datastore("User Database")
user_db.isSQL = True
user_db.isShared = False
user_db.storesCredentials = True
user_db.isEncrypted = True
user_db.storesPII = True

# NoSQL database
document_store = Datastore("Document Store")
document_store.isSQL = False
document_store.type = "MongoDB"

# Cache
cache = Datastore("Redis Cache")
cache.type = "Cache"
cache.isEncrypted = False
```

### Data Flows

```python
from pytm import Dataflow

# HTTP flow
web_request = Dataflow(user, web_server, "HTTP Request")
web_request.protocol = "HTTPS"
web_request.isEncrypted = True
web_request.authenticatesDestination = True
web_request.data = "User credentials, session tokens"

# Database query
db_query = Dataflow(api_server, database, "SQL Query")
db_query.protocol = "PostgreSQL"
db_query.isEncrypted = True
db_query.sanitizesInput = True

# Message queue
event_publish = Dataflow(order_service, message_queue, "Order Event")
event_publish.protocol = "AMQP"
event_publish.isEncrypted = True
```

### Boundaries

```python
from pytm import Boundary

# Network boundaries
internet = Boundary("Internet")
dmz = Boundary("DMZ")
internal = Boundary("Internal Network")
data_tier = Boundary("Data Tier")

# Cloud boundaries
aws_vpc = Boundary("AWS VPC")
private_subnet = Boundary("Private Subnet")
public_subnet = Boundary("Public Subnet")

# Kubernetes boundaries
k8s_cluster = Boundary("Kubernetes Cluster")
namespace_prod = Boundary("Production Namespace")
```

---

## Element Properties

### Security Properties

```python
server = Server("API Server")

# Authentication
server.implementsAuthenticationScheme = True
server.authenticationScheme = "OAuth2"

# Authorization
server.authorizesSource = True
server.checksDestinationRevocation = True

# Input handling
server.sanitizesInput = True
server.validatesInput = True
server.encodesOutput = True

# Encryption
server.usesEncryptionAlgorithm = "AES-256"
server.protocol = "HTTPS"

# Hardening
server.isHardened = True
server.OS = "Linux"
server.hasAccessControl = True

# Logging
server.implementsNonce = True
server.providesIntegrity = True
```

### Data Properties

```python
dataflow = Dataflow(source, dest, "Sensitive Data")

# Classification
dataflow.data = "Customer PII, payment info"
dataflow.classification = "Confidential"

# Protection
dataflow.isEncrypted = True
dataflow.protocol = "TLS 1.3"

# Validation
dataflow.sanitizesInput = True
dataflow.validatesContentType = True
```

---

## Complete Example: Microservices Architecture

```python
#!/usr/bin/env python3
from pytm import TM, Actor, Boundary, Datastore, Dataflow, Server, Lambda

# Initialize threat model
tm = TM("E-Commerce Microservices")
tm.description = "Threat model for e-commerce platform"
tm.isOrdered = True
tm.mergeResponses = True

# Trust Boundaries
internet = Boundary("Internet")
aws_vpc = Boundary("AWS VPC")
eks_cluster = Boundary("EKS Cluster")
data_tier = Boundary("Data Tier")

# External Actors
customer = Actor("Customer")
customer.inBoundary = internet

partner_api = Actor("Partner API")
partner_api.inBoundary = internet

# Edge Layer
api_gateway = Server("API Gateway")
api_gateway.inBoundary = aws_vpc
api_gateway.OS = "Linux"
api_gateway.protocol = "HTTPS"
api_gateway.isHardened = True
api_gateway.sanitizesInput = True
api_gateway.implementsAuthenticationScheme = True

# Application Layer
user_service = Server("User Service")
user_service.inBoundary = eks_cluster
user_service.OS = "Linux"
user_service.protocol = "gRPC"
user_service.isHardened = True
user_service.sanitizesInput = True
user_service.validatesInput = True

order_service = Server("Order Service")
order_service.inBoundary = eks_cluster
order_service.OS = "Linux"
order_service.protocol = "gRPC"
order_service.isHardened = True

payment_service = Server("Payment Service")
payment_service.inBoundary = eks_cluster
payment_service.OS = "Linux"
payment_service.protocol = "gRPC"
payment_service.isHardened = True
payment_service.handlesCardholderData = True

# Data Stores
user_db = Datastore("User Database")
user_db.inBoundary = data_tier
user_db.isSQL = True
user_db.isEncrypted = True
user_db.storesPII = True
user_db.storesCredentials = True

order_db = Datastore("Order Database")
order_db.inBoundary = data_tier
order_db.isSQL = True
order_db.isEncrypted = True

redis_cache = Datastore("Redis Cache")
redis_cache.inBoundary = data_tier
redis_cache.type = "Cache"
redis_cache.isEncrypted = False

# Message Queue
kafka = Server("Kafka")
kafka.inBoundary = eks_cluster
kafka.protocol = "Kafka"

# Data Flows
# Customer → API Gateway
customer_request = Dataflow(customer, api_gateway, "HTTPS Request")
customer_request.protocol = "HTTPS"
customer_request.isEncrypted = True
customer_request.authenticatesDestination = True
customer_request.data = "User requests, credentials"

# API Gateway → Services
gateway_to_user = Dataflow(api_gateway, user_service, "gRPC Call")
gateway_to_user.protocol = "gRPC"
gateway_to_user.isEncrypted = True
gateway_to_user.authenticatesSource = True

gateway_to_order = Dataflow(api_gateway, order_service, "gRPC Call")
gateway_to_order.protocol = "gRPC"
gateway_to_order.isEncrypted = True

# Service to Service
order_to_payment = Dataflow(order_service, payment_service, "Payment Request")
order_to_payment.protocol = "gRPC"
order_to_payment.isEncrypted = True
order_to_payment.data = "Payment amount, order ID"

# Services to Databases
user_service_to_db = Dataflow(user_service, user_db, "SQL Query")
user_service_to_db.protocol = "PostgreSQL"
user_service_to_db.isEncrypted = True
user_service_to_db.sanitizesInput = True

order_service_to_db = Dataflow(order_service, order_db, "SQL Query")
order_service_to_db.protocol = "PostgreSQL"
order_service_to_db.isEncrypted = True
order_service_to_db.sanitizesInput = True

# Event publishing
order_to_kafka = Dataflow(order_service, kafka, "Order Events")
order_to_kafka.protocol = "Kafka"
order_to_kafka.isEncrypted = True

if __name__ == "__main__":
    tm.process()
```

---

## Custom Threat Rules

### Adding Custom Threats

```python
from pytm import TM, Threat

# Define custom threat
class CustomThreats:
    ContainerEscape = Threat(
        id="CUSTOM-001",
        description="Container escape vulnerability",
        condition="target.isContainer and not target.usesSeccompProfile",
        target=["Server", "Process"],
        severity="High",
        mitigations="Enable seccomp profiles, avoid privileged containers"
    )

    HardcodedSecrets = Threat(
        id="CUSTOM-002",
        description="Hardcoded secrets in code",
        condition="target.hasHardcodedSecrets",
        target=["Server", "Process", "Lambda"],
        severity="Critical",
        mitigations="Use secrets manager, environment variables from secure source"
    )

# Register custom threats
tm.threatsExcluded = []
tm.threats.extend([
    CustomThreats.ContainerEscape,
    CustomThreats.HardcodedSecrets
])
```

### Threat Conditions

```python
# Common conditions for threat rules
conditions = {
    # Input handling
    "not target.sanitizesInput": "Missing input sanitization",
    "not target.validatesInput": "Missing input validation",

    # Encryption
    "not target.isEncrypted": "Unencrypted data",
    "not target.usesEncryptionAlgorithm": "Missing encryption",

    # Authentication
    "not target.implementsAuthenticationScheme": "No authentication",
    "not target.authorizesSource": "No authorization",

    # Boundaries
    "target.crossesBoundary": "Crosses trust boundary",

    # Data sensitivity
    "target.storesPII": "Stores PII data",
    "target.storesCredentials": "Stores credentials",
}
```

---

## CI/CD Integration

### GitHub Actions

```yaml
# .github/workflows/threat-model.yml
name: Threat Model Analysis

on:
  push:
    paths:
      - 'security/threat_model.py'
  pull_request:
    paths:
      - 'security/threat_model.py'

jobs:
  analyze:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Install dependencies
        run: |
          pip install pytm
          sudo apt-get install -y graphviz

      - name: Generate threat model
        run: |
          cd security
          python threat_model.py --dfd --report threats.md

      - name: Check for high severity threats
        run: |
          if grep -q "Severity: High\|Severity: Critical" security/threats.md; then
            echo "::warning::High/Critical severity threats found"
          fi

      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: threat-model
          path: |
            security/*.png
            security/threats.md
```

### Pre-commit Hook

```yaml
# .pre-commit-config.yaml
repos:
  - repo: local
    hooks:
      - id: threat-model
        name: Update Threat Model
        entry: python security/threat_model.py --report security/THREATS.md
        language: python
        files: ^security/threat_model\.py$
        additional_dependencies: ['pytm']
```

---

## Output Formats

### Data Flow Diagram

```bash
python threat_model.py --dfd
# Generates: tm.png
```

### Sequence Diagram

```bash
python threat_model.py --seq
# Generates: tm_seq.png
```

### Markdown Report

```bash
python threat_model.py --report threats.md
# Generates detailed threat report in Markdown
```

### JSON Output

```bash
python threat_model.py --json threats.json
# Generates machine-readable threat data
```

---

## Best Practices

### Model Organization

```python
# Organize by layer/domain
class EdgeLayer:
    cdn = Server("CDN")
    waf = Server("WAF")
    api_gateway = Server("API Gateway")

class ApplicationLayer:
    user_service = Server("User Service")
    order_service = Server("Order Service")

class DataLayer:
    user_db = Datastore("User DB")
    cache = Datastore("Cache")

# Use in main model
tm = TM("Organized Model")
# ... use EdgeLayer.cdn, ApplicationLayer.user_service, etc.
```

### Documentation

```python
# Document assumptions and decisions
server = Server("Payment Service")
server.description = """
Handles payment processing via Stripe API.
PCI DSS scope - handles cardholder data in memory only.
No CHD stored locally.
"""
server.assumptions = [
    "Stripe handles card storage",
    "Only tokenized data stored",
    "TLS 1.3 enforced"
]
```

---

## Next Steps

→ [MITRE ATT&CK Integration](mitre-attack.md)
→ [CI/CD Integration Patterns](cicd-integration.md)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Basic Usage
- Element Types
- Element Properties
- Complete Example: Microservices Architecture

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
