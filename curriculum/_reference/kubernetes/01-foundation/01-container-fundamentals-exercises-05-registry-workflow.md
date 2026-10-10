# Exercise 5: Registry Workflow

## Objective

Master container registry workflows including authentication, tagging strategies, image lifecycle management, and multi-registry deployments across AWS ECR, Google Artifact Registry, and Azure ACR.

## Prerequisites

- Completed Exercises 1-4
- Cloud CLI tools installed (aws, gcloud, az)
- Account access to at least one cloud provider

## Tagging Strategy

A consistent tagging strategy is essential for production deployments:

| Tag Type | Format | Example | Use Case |
|----------|--------|---------|----------|
| Semantic Version | `v{major}.{minor}.{patch}` | `v1.2.3` | Release versions |
| Git SHA | `sha-{short-hash}` | `sha-abc1234` | Exact commit tracking |
| Branch | `branch-{name}` | `branch-main` | Development builds |
| Latest | `latest` | `latest` | Current stable (use cautiously) |
| Environment | `{env}-{version}` | `prod-v1.2.3` | Environment-specific |

## Tasks

### Task 1: Set Up Local Registry for Practice

```bash
# Start a local registry
docker run -d -p 5000:5000 --name registry registry:2

# Tag and push an image
docker tag myapp:1.0.0 localhost:5000/myapp:1.0.0
docker push localhost:5000/myapp:1.0.0

# List images in registry
curl http://localhost:5000/v2/_catalog
curl http://localhost:5000/v2/myapp/tags/list

# Cleanup
docker rm -f registry
```

### Task 2: AWS ECR Workflow

**Prerequisites:**
```bash
# Install AWS CLI
brew install awscli

# Configure credentials
aws configure
```

**Create and Configure Repository:**
```bash
# Set variables
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION="us-west-2"
REPO_NAME="myapp"

# Create repository
aws ecr create-repository \
    --repository-name ${REPO_NAME} \
    --image-scanning-configuration scanOnPush=true \
    --encryption-configuration encryptionType=AES256

# Set lifecycle policy (keep last 10 images)
aws ecr put-lifecycle-policy \
    --repository-name ${REPO_NAME} \
    --lifecycle-policy-text '{
        "rules": [
            {
                "rulePriority": 1,
                "description": "Keep last 10 images",
                "selection": {
                    "tagStatus": "any",
                    "countType": "imageCountMoreThan",
                    "countNumber": 10
                },
                "action": {
                    "type": "expire"
                }
            }
        ]
    }'
```

**Authenticate and Push:**
```bash
# Get login token (valid for 12 hours)
aws ecr get-login-password --region ${AWS_REGION} | \
    docker login --username AWS --password-stdin \
    ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

# Tag image
docker tag myapp:1.0.0 \
    ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPO_NAME}:v1.0.0

# Push image
docker push \
    ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPO_NAME}:v1.0.0

# Verify scan results
aws ecr describe-image-scan-findings \
    --repository-name ${REPO_NAME} \
    --image-id imageTag=v1.0.0
```

**Create ECR Pull Secret for Kubernetes:**
```bash
# Create secret
kubectl create secret docker-registry ecr-secret \
    --docker-server=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com \
    --docker-username=AWS \
    --docker-password=$(aws ecr get-login-password --region ${AWS_REGION})
```

### Task 3: Google Artifact Registry Workflow

**Prerequisites:**
```bash
# Install gcloud CLI
brew install google-cloud-sdk

# Authenticate
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
```

**Create and Configure Repository:**
```bash
PROJECT_ID=$(gcloud config get-value project)
REGION="us-central1"
REPO_NAME="docker-repo"

# Enable Artifact Registry API
gcloud services enable artifactregistry.googleapis.com

# Create repository
gcloud artifacts repositories create ${REPO_NAME} \
    --repository-format=docker \
    --location=${REGION} \
    --description="Docker repository"

# Configure Docker authentication
gcloud auth configure-docker ${REGION}-docker.pkg.dev
```

**Push Images:**
```bash
# Tag image
docker tag myapp:1.0.0 \
    ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/myapp:v1.0.0

# Push image
docker push \
    ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/myapp:v1.0.0

# List images
gcloud artifacts docker images list \
    ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}
```

**Set Up Vulnerability Scanning:**
```bash
# Enable Container Analysis API
gcloud services enable containeranalysis.googleapis.com

# View scan results
gcloud artifacts docker images describe \
    ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/myapp:v1.0.0 \
    --show-package-vulnerability
```

### Task 4: Azure ACR Workflow

**Prerequisites:**
```bash
# Install Azure CLI
brew install azure-cli

# Login
az login
```

**Create and Configure Registry:**
```bash
RESOURCE_GROUP="myapp-rg"
ACR_NAME="myappregistry"
LOCATION="eastus"

# Create resource group
az group create --name ${RESOURCE_GROUP} --location ${LOCATION}

# Create ACR
az acr create \
    --resource-group ${RESOURCE_GROUP} \
    --name ${ACR_NAME} \
    --sku Standard \
    --admin-enabled false

# Enable content trust
az acr config content-trust update \
    --registry ${ACR_NAME} \
    --status enabled
```

**Authenticate and Push:**
```bash
# Login to ACR
az acr login --name ${ACR_NAME}

# Tag image
docker tag myapp:1.0.0 ${ACR_NAME}.azurecr.io/myapp:v1.0.0

# Push image
docker push ${ACR_NAME}.azurecr.io/myapp:v1.0.0

# List images
az acr repository list --name ${ACR_NAME}
az acr repository show-tags --name ${ACR_NAME} --repository myapp
```

**Enable Security Scanning:**
```bash
# Enable Defender for Containers
az security pricing create \
    --name Containers \
    --tier Standard

# View vulnerabilities
az acr repository show-manifests \
    --name ${ACR_NAME} \
    --repository myapp \
    --detail
```

### Task 5: Multi-Registry CI/CD Pipeline

Create a GitHub Actions workflow that pushes to multiple registries:

**.github/workflows/multi-registry.yml**
```yaml
name: Multi-Registry Push

on:
  push:
    tags:
      - 'v*'

env:
  IMAGE_NAME: myapp

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
      id-token: write  # For OIDC auth

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Extract version
        id: version
        run: echo "VERSION=${GITHUB_REF#refs/tags/}" >> $GITHUB_OUTPUT

      # AWS ECR
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: us-west-2

      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2

      # Google Artifact Registry
      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY }}
          service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}

      - name: Configure Docker for GCR
        run: gcloud auth configure-docker us-central1-docker.pkg.dev

      # Azure ACR
      - name: Login to Azure ACR
        uses: azure/docker-login@v1
        with:
          login-server: ${{ secrets.ACR_LOGIN_SERVER }}
          username: ${{ secrets.ACR_USERNAME }}
          password: ${{ secrets.ACR_PASSWORD }}

      # GitHub Container Registry
      - name: Login to GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      # Build and push to all registries
      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: |
            ${{ steps.login-ecr.outputs.registry }}/${{ env.IMAGE_NAME }}:${{ steps.version.outputs.VERSION }}
            ${{ steps.login-ecr.outputs.registry }}/${{ env.IMAGE_NAME }}:latest
            us-central1-docker.pkg.dev/${{ secrets.GCP_PROJECT }}/${{ env.IMAGE_NAME }}:${{ steps.version.outputs.VERSION }}
            ${{ secrets.ACR_LOGIN_SERVER }}/${{ env.IMAGE_NAME }}:${{ steps.version.outputs.VERSION }}
            ghcr.io/${{ github.repository_owner }}/${{ env.IMAGE_NAME }}:${{ steps.version.outputs.VERSION }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
          build-args: |
            VERSION=${{ steps.version.outputs.VERSION }}
            BUILD_TIME=${{ github.event.head_commit.timestamp }}
            GIT_COMMIT=${{ github.sha }}
```

### Task 6: Image Signing with Cosign

```bash
# Install cosign
brew install cosign

# Generate key pair
cosign generate-key-pair

# Sign an image
cosign sign --key cosign.key ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/myapp:v1.0.0

# Verify signature
cosign verify --key cosign.pub ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/myapp:v1.0.0
```

### Task 7: Registry Cleanup Automation

**cleanup-ecr.sh**
```bash
#!/bin/bash

REPO_NAME="myapp"
KEEP_COUNT=10

# Get all image tags sorted by push date
IMAGES=$(aws ecr describe-images \
    --repository-name ${REPO_NAME} \
    --query 'sort_by(imageDetails,& imagePushedAt)[*].imageDigest' \
    --output text)

# Count total images
TOTAL=$(echo $IMAGES | wc -w)

# Delete old images if we have more than KEEP_COUNT
if [ $TOTAL -gt $KEEP_COUNT ]; then
    DELETE_COUNT=$((TOTAL - KEEP_COUNT))
    DELETE_IMAGES=$(echo $IMAGES | cut -d' ' -f1-${DELETE_COUNT})

    for digest in $DELETE_IMAGES; do
        echo "Deleting image: $digest"
        aws ecr batch-delete-image \
            --repository-name ${REPO_NAME} \
            --image-ids imageDigest=$digest
    done
fi
```

## Validation

```bash
# Verify images are accessible from all registries
# ECR
docker pull ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/myapp:v1.0.0

# GCR
docker pull ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/myapp:v1.0.0

# ACR
docker pull ${ACR_NAME}.azurecr.io/myapp:v1.0.0

# Verify all have same digest
docker images --digests | grep myapp
```

## Success Criteria

- [ ] Successfully pushed to local registry
- [ ] Configured and pushed to AWS ECR
- [ ] Configured and pushed to Google Artifact Registry
- [ ] Configured and pushed to Azure ACR
- [ ] Implemented consistent tagging strategy
- [ ] Set up vulnerability scanning on at least one registry
- [ ] Created multi-registry CI/CD pipeline
- [ ] Implemented image signing (optional)

## Best Practices Summary

1. **Never use `latest` in production** - Always use specific versions
2. **Enable vulnerability scanning** - All major registries support this
3. **Implement lifecycle policies** - Prevent registry bloat
4. **Use immutable tags** - Prevent tag mutation attacks
5. **Sign your images** - Use cosign or Docker Content Trust
6. **Rotate credentials regularly** - Use short-lived tokens where possible
7. **Use OIDC authentication** - Avoid storing long-lived credentials

## Exercises Complete!

Congratulations! You've completed all container fundamentals exercises. You should now be able to:

- Build production-ready container images
- Use multi-stage builds for optimization
- Scan and fix security vulnerabilities
- Use minimal distroless base images
- Work with multiple container registries

## Next Steps

Continue to [Phase 1 Project: Microservices Application](../../project-microservices-app/) to apply these skills in a real-world scenario.

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- Tagging Strategy
- Best Practices Summary
- Set Up Local Registry for Practice
- AWS ECR Workflow

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
