# Lab 2: Infrastructure Abstraction with Crossplane

## Lab Overview

In this lab, you will implement self-service infrastructure provisioning using Crossplane. You'll learn how to create composite resources that abstract cloud complexity and enable developers to provision infrastructure through simple Kubernetes manifests.

**Duration:** 3-4 hours
**Difficulty:** Advanced
**Prerequisites:**
- Kubernetes cluster (local or cloud)
- kubectl configured
- Helm 3 installed
- AWS account (or Azure/GCP - exercises adaptable)
- Basic understanding of Kubernetes CRDs

## Learning Objectives

By the end of this lab, you will be able to:
- Install and configure Crossplane
- Create Composite Resource Definitions (XRDs)
- Build Compositions that provision cloud resources
- Implement platform abstractions for self-service
- Apply policy and governance to infrastructure

## Lab Environment Setup

### Step 1: Create Kubernetes Cluster

```bash
# Using kind for local development
kind create cluster --name crossplane-lab --config - <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker
  - role: worker
EOF

# Verify cluster is running
kubectl cluster-info
```

### Step 2: Install Crossplane

```bash
# Add Crossplane Helm repository
helm repo add crossplane-stable https://charts.crossplane.io/stable
helm repo update

# Install Crossplane
helm install crossplane \
  crossplane-stable/crossplane \
  --namespace crossplane-system \
  --create-namespace \
  --set args='{--enable-composition-revisions}'

# Wait for Crossplane to be ready
kubectl wait --for=condition=Available deployment/crossplane \
  --namespace crossplane-system \
  --timeout=120s

# Verify installation
kubectl get pods -n crossplane-system
```

### Step 3: Install AWS Provider

```bash
# Install the AWS Provider
cat <<EOF | kubectl apply -f -
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-aws
spec:
  package: xpkg.upbound.io/upbound/provider-aws:v0.40.0
EOF

# Wait for provider to be healthy
kubectl wait --for=condition=Healthy provider/provider-aws --timeout=180s

# Check provider status
kubectl get providers
```

### Step 4: Configure AWS Credentials

```bash
# Create AWS credentials secret
# Replace with your credentials or use IAM roles
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: aws-credentials
  namespace: crossplane-system
type: Opaque
stringData:
  credentials: |
    [default]
    aws_access_key_id = YOUR_ACCESS_KEY
    aws_secret_access_key = YOUR_SECRET_KEY
EOF

# Create ProviderConfig
cat <<EOF | kubectl apply -f -
apiVersion: aws.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: aws-credentials
      key: credentials
EOF
```

## Exercise 1: Create Basic Composite Resources

### Step 1: Define a Database XRD

Create `xrd-database.yaml`:

```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
metadata:
  name: xdatabases.platform.company.io
spec:
  group: platform.company.io
  names:
    kind: XDatabase
    plural: xdatabases
  claimNames:
    kind: Database
    plural: databases
  versions:
    - name: v1alpha1
      served: true
      referenceable: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              required:
                - engine
                - size
              properties:
                engine:
                  type: string
                  description: Database engine type
                  enum:
                    - postgres
                    - mysql
                size:
                  type: string
                  description: Database size class
                  enum:
                    - small
                    - medium
                    - large
                  default: small
                storageGB:
                  type: integer
                  description: Storage size in GB
                  default: 20
                  minimum: 10
                  maximum: 1000
            status:
              type: object
              properties:
                endpoint:
                  type: string
                port:
                  type: integer
                status:
                  type: string
```

Apply the XRD:

```bash
kubectl apply -f xrd-database.yaml

# Verify XRD is established
kubectl get xrd xdatabases.platform.company.io
```

### Step 2: Create Database Composition

Create `composition-database.yaml`:

```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: database-aws
  labels:
    provider: aws
    engine: postgres
spec:
  compositeTypeRef:
    apiVersion: platform.company.io/v1alpha1
    kind: XDatabase

  patchSets:
    - name: common-tags
      patches:
        - type: FromCompositeFieldPath
          fromFieldPath: metadata.labels[app.kubernetes.io/name]
          toFieldPath: spec.forProvider.tags[Name]
        - type: FromCompositeFieldPath
          fromFieldPath: metadata.labels[platform.company.io/team]
          toFieldPath: spec.forProvider.tags[Team]

  resources:
    # Subnet Group for RDS
    - name: subnet-group
      base:
        apiVersion: rds.aws.upbound.io/v1beta1
        kind: SubnetGroup
        spec:
          forProvider:
            region: us-west-2
            description: "Managed by Crossplane"
            subnetIdSelector:
              matchLabels:
                network.platform.company.io/type: database
          providerConfigRef:
            name: default
      patches:
        - type: FromCompositeFieldPath
          fromFieldPath: metadata.uid
          toFieldPath: metadata.name
          transforms:
            - type: string
              string:
                fmt: "db-subnet-%s"

    # Security Group
    - name: security-group
      base:
        apiVersion: ec2.aws.upbound.io/v1beta1
        kind: SecurityGroup
        spec:
          forProvider:
            region: us-west-2
            description: "Database security group"
            vpcIdSelector:
              matchLabels:
                network.platform.company.io/name: main
          providerConfigRef:
            name: default
      patches:
        - type: FromCompositeFieldPath
          fromFieldPath: metadata.uid
          toFieldPath: metadata.name
          transforms:
            - type: string
              string:
                fmt: "db-sg-%s"

    # Security Group Rule - Allow PostgreSQL
    - name: sg-rule-postgres
      base:
        apiVersion: ec2.aws.upbound.io/v1beta1
        kind: SecurityGroupRule
        spec:
          forProvider:
            region: us-west-2
            type: ingress
            fromPort: 5432
            toPort: 5432
            protocol: tcp
            cidrBlocks:
              - "10.0.0.0/8"
            securityGroupIdSelector:
              matchControllerRef: true
          providerConfigRef:
            name: default

    # RDS Instance
    - name: rds-instance
      base:
        apiVersion: rds.aws.upbound.io/v1beta1
        kind: Instance
        spec:
          forProvider:
            region: us-west-2
            engine: postgres
            engineVersion: "15"
            publiclyAccessible: false
            skipFinalSnapshot: true
            storageType: gp3
            username: admin
            autoGeneratePassword: true
            passwordSecretRef:
              key: password
          providerConfigRef:
            name: default
          writeConnectionSecretToRef:
            namespace: crossplane-system
      patches:
        # Instance class based on size
        - type: FromCompositeFieldPath
          fromFieldPath: spec.size
          toFieldPath: spec.forProvider.instanceClass
          transforms:
            - type: map
              map:
                small: db.t3.micro
                medium: db.t3.small
                large: db.t3.medium

        # Storage size
        - type: FromCompositeFieldPath
          fromFieldPath: spec.storageGB
          toFieldPath: spec.forProvider.allocatedStorage

        # Engine type
        - type: FromCompositeFieldPath
          fromFieldPath: spec.engine
          toFieldPath: spec.forProvider.engine

        # Connection secret name
        - type: FromCompositeFieldPath
          fromFieldPath: metadata.uid
          toFieldPath: spec.writeConnectionSecretToRef.name
          transforms:
            - type: string
              string:
                fmt: "db-conn-%s"

        # Subnet group reference
        - type: FromCompositeFieldPath
          fromFieldPath: metadata.uid
          toFieldPath: spec.forProvider.dbSubnetGroupName
          transforms:
            - type: string
              string:
                fmt: "db-subnet-%s"

        # Security group reference
        - type: FromCompositeFieldPath
          fromFieldPath: metadata.uid
          toFieldPath: spec.forProvider.vpcSecurityGroupIds[0]
          transforms:
            - type: string
              string:
                fmt: "db-sg-%s"

        # Status patches
        - type: ToCompositeFieldPath
          fromFieldPath: status.atProvider.endpoint
          toFieldPath: status.endpoint

        - type: ToCompositeFieldPath
          fromFieldPath: status.atProvider.port
          toFieldPath: status.port
```

Apply the Composition:

```bash
kubectl apply -f composition-database.yaml

# Verify composition
kubectl get composition database-aws
```

### Step 3: Create a Database Claim

Create `database-claim.yaml`:

```yaml
apiVersion: platform.company.io/v1alpha1
kind: Database
metadata:
  name: myapp-db
  namespace: default
  labels:
    app.kubernetes.io/name: myapp
    platform.company.io/team: backend
spec:
  engine: postgres
  size: small
  storageGB: 50

  # Where to write connection details
  writeConnectionSecretToRef:
    name: myapp-db-connection
```

Apply and monitor:

```bash
kubectl apply -f database-claim.yaml

# Watch the resources being created
kubectl get database myapp-db -w

# Check the composite resource
kubectl get xdatabase -o wide

# Check AWS resources being created
kubectl get managed -l crossplane.io/claim-name=myapp-db
```

## Exercise 2: Create Application Environment Abstraction

### Step 1: Define Application Environment XRD

Create `xrd-appenvironment.yaml`:

```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
metadata:
  name: xappenvironments.platform.company.io
spec:
  group: platform.company.io
  names:
    kind: XAppEnvironment
    plural: xappenvironments
  claimNames:
    kind: AppEnvironment
    plural: appenvironments
  versions:
    - name: v1alpha1
      served: true
      referenceable: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              required:
                - appName
                - team
              properties:
                appName:
                  type: string
                  description: Application name
                team:
                  type: string
                  description: Team that owns this environment
                tier:
                  type: string
                  description: Environment tier
                  enum:
                    - development
                    - staging
                    - production
                  default: development
                components:
                  type: object
                  properties:
                    database:
                      type: object
                      properties:
                        enabled:
                          type: boolean
                          default: false
                        engine:
                          type: string
                          enum: [postgres, mysql]
                          default: postgres
                        size:
                          type: string
                          enum: [small, medium, large]
                          default: small
                    cache:
                      type: object
                      properties:
                        enabled:
                          type: boolean
                          default: false
                        size:
                          type: string
                          enum: [small, medium, large]
                          default: small
                    storage:
                      type: object
                      properties:
                        enabled:
                          type: boolean
                          default: false
                        sizeGB:
                          type: integer
                          default: 10
            status:
              type: object
              properties:
                databaseEndpoint:
                  type: string
                cacheEndpoint:
                  type: string
                storageBucket:
                  type: string
                status:
                  type: string
```

### Step 2: Create Application Environment Composition

Create `composition-appenvironment.yaml`:

```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: appenvironment-aws
  labels:
    provider: aws
spec:
  compositeTypeRef:
    apiVersion: platform.company.io/v1alpha1
    kind: XAppEnvironment

  resources:
    # Kubernetes Namespace
    - name: namespace
      base:
        apiVersion: kubernetes.crossplane.io/v1alpha1
        kind: Object
        spec:
          forProvider:
            manifest:
              apiVersion: v1
              kind: Namespace
              metadata:
                labels:
                  platform.company.io/managed: "true"
      patches:
        - type: FromCompositeFieldPath
          fromFieldPath: spec.appName
          toFieldPath: spec.forProvider.manifest.metadata.name
        - type: FromCompositeFieldPath
          fromFieldPath: spec.team
          toFieldPath: spec.forProvider.manifest.metadata.labels[platform.company.io/team]
        - type: FromCompositeFieldPath
          fromFieldPath: spec.tier
          toFieldPath: spec.forProvider.manifest.metadata.labels[platform.company.io/tier]

    # Database (conditional)
    - name: database
      base:
        apiVersion: platform.company.io/v1alpha1
        kind: XDatabase
        spec:
          compositionSelector:
            matchLabels:
              provider: aws
      patches:
        - type: FromCompositeFieldPath
          fromFieldPath: spec.components.database.engine
          toFieldPath: spec.engine
        - type: FromCompositeFieldPath
          fromFieldPath: spec.components.database.size
          toFieldPath: spec.size
        - type: FromCompositeFieldPath
          fromFieldPath: spec.appName
          toFieldPath: metadata.name
          transforms:
            - type: string
              string:
                fmt: "%s-db"
        # Only create if enabled
        - type: FromCompositeFieldPath
          fromFieldPath: spec.components.database.enabled
          toFieldPath: metadata.annotations[crossplane.io/paused]
          transforms:
            - type: convert
              convert:
                toType: string
            - type: map
              map:
                "true": "false"
                "false": "true"
        # Status
        - type: ToCompositeFieldPath
          fromFieldPath: status.endpoint
          toFieldPath: status.databaseEndpoint

    # ElastiCache (conditional)
    - name: cache
      base:
        apiVersion: elasticache.aws.upbound.io/v1beta1
        kind: Cluster
        spec:
          forProvider:
            region: us-west-2
            engine: redis
            nodeType: cache.t3.micro
            numCacheNodes: 1
          providerConfigRef:
            name: default
      patches:
        - type: FromCompositeFieldPath
          fromFieldPath: spec.components.cache.size
          toFieldPath: spec.forProvider.nodeType
          transforms:
            - type: map
              map:
                small: cache.t3.micro
                medium: cache.t3.small
                large: cache.t3.medium
        - type: FromCompositeFieldPath
          fromFieldPath: spec.appName
          toFieldPath: metadata.name
          transforms:
            - type: string
              string:
                fmt: "%s-cache"
        # Only create if enabled
        - type: FromCompositeFieldPath
          fromFieldPath: spec.components.cache.enabled
          toFieldPath: metadata.annotations[crossplane.io/paused]
          transforms:
            - type: convert
              convert:
                toType: string
            - type: map
              map:
                "true": "false"
                "false": "true"

    # S3 Bucket (conditional)
    - name: storage
      base:
        apiVersion: s3.aws.upbound.io/v1beta1
        kind: Bucket
        spec:
          forProvider:
            region: us-west-2
          providerConfigRef:
            name: default
      patches:
        - type: FromCompositeFieldPath
          fromFieldPath: spec.appName
          toFieldPath: metadata.name
          transforms:
            - type: string
              string:
                fmt: "platform-%s-storage"
        # Only create if enabled
        - type: FromCompositeFieldPath
          fromFieldPath: spec.components.storage.enabled
          toFieldPath: metadata.annotations[crossplane.io/paused]
          transforms:
            - type: convert
              convert:
                toType: string
            - type: map
              map:
                "true": "false"
                "false": "true"
        # Status
        - type: ToCompositeFieldPath
          fromFieldPath: status.atProvider.id
          toFieldPath: status.storageBucket
```

### Step 3: Request an Application Environment

Create `app-environment-claim.yaml`:

```yaml
apiVersion: platform.company.io/v1alpha1
kind: AppEnvironment
metadata:
  name: myapp-staging
  namespace: default
spec:
  appName: myapp
  team: backend-team
  tier: staging
  components:
    database:
      enabled: true
      engine: postgres
      size: small
    cache:
      enabled: true
      size: small
    storage:
      enabled: true
      sizeGB: 50
```

Apply and verify:

```bash
kubectl apply -f app-environment-claim.yaml

# Monitor environment creation
kubectl get appenvironment myapp-staging -w

# Check all resources
kubectl get xappenvironment,xdatabase,managed -l crossplane.io/claim-name=myapp-staging
```

## Exercise 3: Implement Composition Functions

### Step 1: Install Composition Functions

```bash
# Install the Go templating function
cat <<EOF | kubectl apply -f -
apiVersion: pkg.crossplane.io/v1beta1
kind: Function
metadata:
  name: function-go-templating
spec:
  package: xpkg.upbound.io/crossplane-contrib/function-go-templating:v0.4.0
EOF

# Wait for function to be ready
kubectl wait --for=condition=Healthy function/function-go-templating --timeout=120s
```

### Step 2: Create Composition with Functions

Create `composition-with-functions.yaml`:

```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: database-aws-functions
  labels:
    provider: aws
    type: functions
spec:
  compositeTypeRef:
    apiVersion: platform.company.io/v1alpha1
    kind: XDatabase

  mode: Pipeline
  pipeline:
    - step: render-database
      functionRef:
        name: function-go-templating
      input:
        apiVersion: gotemplating.fn.crossplane.io/v1beta1
        kind: GoTemplate
        source: Inline
        inline:
          template: |
            {{- $xr := .observed.composite.resource }}
            {{- $spec := $xr.spec }}

            # Calculate instance class based on size
            {{- $instanceClass := "" }}
            {{- if eq $spec.size "small" }}
              {{- $instanceClass = "db.t3.micro" }}
            {{- else if eq $spec.size "medium" }}
              {{- $instanceClass = "db.t3.small" }}
            {{- else if eq $spec.size "large" }}
              {{- $instanceClass = "db.t3.medium" }}
            {{- end }}

            # Set storage based on tier
            {{- $storage := $spec.storageGB }}
            {{- if eq $spec.tier "production" }}
              {{- if lt $storage 100 }}
                {{- $storage = 100 }}
              {{- end }}
            {{- end }}

            apiVersion: rds.aws.upbound.io/v1beta1
            kind: Instance
            metadata:
              name: {{ $xr.metadata.name }}-rds
              annotations:
                crossplane.io/composition-resource-name: rds-instance
            spec:
              forProvider:
                region: us-west-2
                engine: {{ $spec.engine }}
                engineVersion: "15"
                instanceClass: {{ $instanceClass }}
                allocatedStorage: {{ $storage }}
                storageType: gp3
                publiclyAccessible: false
                skipFinalSnapshot: true
                username: admin
                autoGeneratePassword: true
              providerConfigRef:
                name: default
              writeConnectionSecretToRef:
                name: {{ $xr.metadata.name }}-db-conn
                namespace: crossplane-system
```

## Exercise 4: Policy and Governance

### Step 1: Create Resource Quotas per Team

Create `composition-with-quota.yaml`:

```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: database-with-quota
  labels:
    provider: aws
    quota: enabled
spec:
  compositeTypeRef:
    apiVersion: platform.company.io/v1alpha1
    kind: XDatabase

  resources:
    # ... same as before, but with validation ...
    - name: rds-instance
      base:
        apiVersion: rds.aws.upbound.io/v1beta1
        kind: Instance
        # ... configuration ...
      patches:
        # Enforce maximum storage for non-production
        - type: FromCompositeFieldPath
          fromFieldPath: spec.storageGB
          toFieldPath: spec.forProvider.allocatedStorage
          transforms:
            - type: math
              math:
                type: ClampMax
                clampMax: 100  # Max 100GB for cost control
```

### Step 2: Create Usage Tracking

Create `usage-tracking.yaml`:

```yaml
apiVersion: apiextensions.crossplane.io/v1alpha1
kind: Usage
metadata:
  name: database-quota-backend-team
spec:
  of:
    apiVersion: platform.company.io/v1alpha1
    kind: XDatabase
    resourceSelector:
      matchLabels:
        platform.company.io/team: backend-team
  by:
    apiVersion: v1
    kind: ConfigMap
    resourceRef:
      name: team-quotas
      namespace: crossplane-system
  reason: "Team database quota tracking"
```

### Step 3: Create Gatekeeper Policies

Create `gatekeeper-policies.yaml`:

```yaml
# Constraint Template - Database Size Limit
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8sdatabasesizelimit
spec:
  crd:
    spec:
      names:
        kind: K8sDatabaseSizeLimit
      validation:
        openAPIV3Schema:
          type: object
          properties:
            maxStorageGB:
              type: integer
            allowedTiers:
              type: array
              items:
                type: string
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8sdatabasesizelimit

        violation[{"msg": msg}] {
          input.review.object.kind == "Database"
          storage := input.review.object.spec.storageGB
          storage > input.parameters.maxStorageGB
          msg := sprintf("Database storage %v exceeds limit of %v GB", [storage, input.parameters.maxStorageGB])
        }

---
# Apply the constraint
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sDatabaseSizeLimit
metadata:
  name: database-size-limit
spec:
  match:
    kinds:
      - apiGroups: ["platform.company.io"]
        kinds: ["Database"]
    namespaces: ["default", "staging"]
  parameters:
    maxStorageGB: 100
```

## Exercise 5: Self-Service Portal Integration

### Step 1: Create Backstage Template for Crossplane

Create a Backstage template that provisions infrastructure via Crossplane:

```yaml
# backstage-template-crossplane.yaml
apiVersion: scaffolder.backstage.io/v1beta3
kind: Template
metadata:
  name: application-environment
  title: Application Environment
  description: Provision a complete application environment with database and cache
spec:
  owner: platform-team
  type: environment

  parameters:
    - title: Application Details
      required:
        - name
        - team
      properties:
        name:
          title: Application Name
          type: string
          pattern: '^[a-z][a-z0-9-]*$'
        team:
          title: Team
          type: string
          ui:field: OwnerPicker

    - title: Environment Configuration
      properties:
        tier:
          title: Environment Tier
          type: string
          enum: [development, staging, production]
          default: development
        database:
          title: Database Configuration
          type: object
          properties:
            enabled:
              type: boolean
              default: true
            engine:
              type: string
              enum: [postgres, mysql]
              default: postgres
            size:
              type: string
              enum: [small, medium, large]
              default: small
        cache:
          title: Cache Configuration
          type: object
          properties:
            enabled:
              type: boolean
              default: false
            size:
              type: string
              enum: [small, medium, large]
              default: small

  steps:
    - id: generate-manifest
      name: Generate Crossplane Manifest
      action: fetch:template
      input:
        url: ./skeleton
        values:
          name: ${{ parameters.name }}
          team: ${{ parameters.team }}
          tier: ${{ parameters.tier }}
          database: ${{ parameters.database }}
          cache: ${{ parameters.cache }}

    - id: apply-manifest
      name: Apply to Kubernetes
      action: kubernetes:apply
      input:
        manifest: ${{ steps.generate-manifest.output.files['environment.yaml'] }}

  output:
    links:
      - title: View Environment
        url: /catalog/default/appenvironment/${{ parameters.name }}-${{ parameters.tier }}
```

## Verification and Testing

### Test Database Provisioning

```bash
# Create a test database
cat <<EOF | kubectl apply -f -
apiVersion: platform.company.io/v1alpha1
kind: Database
metadata:
  name: test-db
  namespace: default
spec:
  engine: postgres
  size: small
  storageGB: 20
EOF

# Watch provisioning
kubectl get database test-db -w

# Check all created resources
kubectl get managed -l crossplane.io/claim-name=test-db

# Get connection secret
kubectl get secret test-db-connection -o yaml

# Clean up
kubectl delete database test-db
```

### Test Application Environment

```bash
# Create a test environment
cat <<EOF | kubectl apply -f -
apiVersion: platform.company.io/v1alpha1
kind: AppEnvironment
metadata:
  name: testapp-dev
  namespace: default
spec:
  appName: testapp
  team: platform-team
  tier: development
  components:
    database:
      enabled: true
      engine: postgres
      size: small
    cache:
      enabled: false
    storage:
      enabled: true
      sizeGB: 10
EOF

# Monitor
kubectl get appenvironment testapp-dev -w

# Clean up
kubectl delete appenvironment testapp-dev
```

## Cleanup

```bash
# Delete all claims
kubectl delete database --all
kubectl delete appenvironment --all

# Delete compositions
kubectl delete composition --all

# Delete XRDs
kubectl delete xrd --all

# Uninstall Crossplane
helm uninstall crossplane -n crossplane-system

# Delete cluster
kind delete cluster --name crossplane-lab
```

## Summary

In this lab, you learned how to:

1. **Install Crossplane** and configure cloud providers
2. **Create XRDs** to define platform abstractions
3. **Build Compositions** that provision multiple resources
4. **Create Claims** for self-service infrastructure
5. **Implement policies** for governance and quotas
6. **Integrate with Backstage** for a complete self-service experience

## Additional Challenges

1. Add Azure provider and create multi-cloud compositions
2. Implement automatic scaling policies for databases
3. Add cost tracking annotations to all resources
4. Create compositions for Kafka clusters
5. Implement environment promotion (dev → staging → prod)

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Create Basic Composite Resources
- Create Application Environment Abstraction
- Implement Composition Functions
- Policy and Governance

**The gap is not what you forgot. It is where you used a word instead of a mechanism.**

| | |
|---|---|
| ✗ | *"The platform makes developers more productive."* |
| ✓ | *"A golden path is a template that produces a repository with CI, manifests, dashboards and alerts already wired, so the product team owns none of them. It reduces cognitive load by removing decisions, not by adding features — and without a documented escape hatch it is a cage."* |

**Trace it:** A developer commits `service.yaml` → a running service with a dashboard and a paging rule. Name every system that acts, and which team owns each one.

Stop at the first component you cannot name. Reopen this file and read **only** that.

**Go deeper — only once the gap has a name:** [Team Topologies — cognitive load](https://teamtopologies.com/key-concepts) and the [CNCF Platforms White Paper](https://tag-app-delivery.cncf.io/whitepapers/platforms/) — why golden paths exist at all.
Full list per domain: [`SOURCES.md`](../SOURCES.md#platform-engineering)

→ Protocol, the three levels of knowing, and worked examples: [`MASTERY.md`](../MASTERY.md)

<!-- /feynman-check -->
