# Domain 3: Infrastructure as Code -- Implementation Checklist

## Prerequisites

- [ ] **Terraform installed** (>= 1.5.0)
  ```bash
  terraform version
  # Expected: Terraform v1.6.0 or higher
  ```

- [ ] **Packer installed** (>= 1.10.0)
  ```bash
  packer version
  # Expected: Packer v1.10.0 or higher
  ```

- [ ] **gcloud CLI installed** **[GCP-SPECIFIC]**
  ```bash
  gcloud version
  # Expected: Google Cloud SDK 450+
  ```

- [ ] **OPA / Conftest installed**
  ```bash
  conftest --version
  # Expected: Conftest v0.46.0 or higher
  ```

- [ ] **tfsec installed**
  ```bash
  tfsec --version
  ```

- [ ] **tflint installed**
  ```bash
  tflint --version
  ```

---

## Phase 1: GCP Project Setup [GCP-SPECIFIC]

- [ ] **1.1 Create GCP projects**
  ```bash
  # Create staging project
  gcloud projects create {{GCP_PROJECT_ID}}-staging --name="{{APP_NAME}} Staging"
  # Create production project
  gcloud projects create {{GCP_PROJECT_ID}} --name="{{APP_NAME}} Production"
  ```

- [ ] **1.2 Enable required APIs**
  ```bash
  for API in compute.googleapis.com \
    artifactregistry.googleapis.com \
    secretmanager.googleapis.com \
    pubsub.googleapis.com \
    logging.googleapis.com \
    monitoring.googleapis.com \
    iam.googleapis.com \
    iamcredentials.googleapis.com \
    servicenetworking.googleapis.com \
    vpcaccess.googleapis.com; do
    gcloud services enable $API --project={{GCP_PROJECT_ID}}-staging
  done
  ```
  **Verify:**
  ```bash
  gcloud services list --enabled --project={{GCP_PROJECT_ID}}-staging | grep -c "googleapis.com"
  # Expected: 10+ APIs enabled
  ```

- [ ] **1.3 Create Terraform state bucket**
  ```bash
  gsutil mb -l {{GCP_REGION}} gs://{{TERRAFORM_STATE_BUCKET}}
  gsutil versioning set on gs://{{TERRAFORM_STATE_BUCKET}}
  gsutil uniformbucketlevelaccess set on gs://{{TERRAFORM_STATE_BUCKET}}
  ```
  **Verify:**
  ```bash
  gsutil ls gs://{{TERRAFORM_STATE_BUCKET}}
  # Expected: No error, empty bucket
  ```

---

## Phase 2: Workload Identity Federation [GCP-SPECIFIC]

- [ ] **2.1 Apply github-wif module**
  ```bash
  cd environments/staging
  terraform init
  terraform apply -target=module.github_wif
  ```
  **Verify:**
  ```bash
  terraform output github_actions_secrets
  # Expected: JSON with GCP_WORKLOAD_IDENTITY_PROVIDER and service account
  ```

- [ ] **2.2 Configure GitHub repository secrets**
  ```bash
  # Set secrets from terraform output
  gh secret set GCP_WORKLOAD_IDENTITY_PROVIDER --body="<value from output>"
  gh secret set GCP_SERVICE_ACCOUNT --body="<value from output>"
  gh secret set GCP_PROJECT_ID --body="{{GCP_PROJECT_ID}}-staging"
  ```
  **Verify:**
  ```bash
  gh secret list
  # Expected: All three secrets listed
  ```

---

## Phase 3: Network Foundation

- [ ] **3.1 Apply VPC module**
  ```bash
  terraform apply -target=module.vpc
  ```
  **Verify:**
  ```bash
  terraform output -module=vpc
  # Expected: network_id, subnet_id, network_name populated
  gcloud compute networks list --project={{GCP_PROJECT_ID}}-staging
  # Expected: VPC listed
  ```

- [ ] **3.2 Verify firewall rules** (created by k8s-cluster module later)
  ```bash
  gcloud compute firewall-rules list --project={{GCP_PROJECT_ID}}-staging
  # Expected: No errors (rules created with k8s-cluster module)
  ```

---

## Phase 4: Packer Image Build [KUBEADM-SPECIFIC]

- [ ] **4.1 Validate Packer template**
  ```bash
  cd packer
  packer init kubeadm-node.pkr.hcl
  packer fmt -check kubeadm-node.pkr.hcl
  packer validate -var "project_id={{GCP_PROJECT_ID}}-staging" kubeadm-node.pkr.hcl
  ```
  **Verify:**
  ```bash
  # Expected: "The configuration is valid."
  ```

- [ ] **4.2 Build hardened image**
  ```bash
  packer build \
    -var "project_id={{GCP_PROJECT_ID}}-staging" \
    -var "zone={{GCP_ZONE}}" \
    -var "kubernetes_version=1.34.3" \
    kubeadm-node.pkr.hcl
  ```
  **Verify:**
  ```bash
  gcloud compute images list --project={{GCP_PROJECT_ID}}-staging \
    --filter="family=kubeadm-ubuntu-2404"
  # Expected: At least one image listed
  ```

---

## Phase 5: Kubernetes Cluster [KUBEADM-SPECIFIC]

- [ ] **5.1 Apply k8s-cluster module**
  ```bash
  terraform apply -target=module.k8s_cluster
  ```
  **Verify:**
  ```bash
  terraform output control_plane_name
  terraform output worker_name
  # Expected: VM names printed
  gcloud compute instances list --project={{GCP_PROJECT_ID}}-staging
  # Expected: Two VMs listed (control + worker)
  ```

- [ ] **5.2 Verify cluster health**
  ```bash
  # SSH to control plane via IAP
  gcloud compute ssh $(terraform output -raw control_plane_name) \
    --zone=$(terraform output -raw control_plane_zone) \
    --tunnel-through-iap \
    --command="sudo kubectl get nodes"
  # Expected: 2 nodes in Ready status
  ```

- [ ] **5.3 Retrieve kubeconfig**
  ```bash
  gcloud compute ssh $(terraform output -raw control_plane_name) \
    --zone=$(terraform output -raw control_plane_zone) \
    --tunnel-through-iap \
    --command="sudo cat /etc/kubernetes/admin.conf" > kubeconfig.yaml
  ```
  **Verify:**
  ```bash
  KUBECONFIG=kubeconfig.yaml kubectl get nodes
  # Expected: Both nodes shown as Ready
  ```

---

## Phase 6: Supporting Infrastructure

- [ ] **6.1 Apply artifact registry**
  ```bash
  terraform apply -target=module.artifact_registry
  ```
  **Verify:**
  ```bash
  gcloud artifacts repositories list --project={{GCP_PROJECT_ID}}-staging
  # Expected: Docker repository listed
  ```

- [ ] **6.2 Apply GCS storage**
  ```bash
  terraform apply -target=module.gcs_storage
  ```
  **Verify:**
  ```bash
  gsutil ls -p {{GCP_PROJECT_ID}}-staging
  # Expected: Multiple buckets listed (documents, evidence, recordings, etc.)
  ```

- [ ] **6.3 Apply Pub/Sub**
  ```bash
  terraform apply -target=module.pubsub
  ```
  **Verify:**
  ```bash
  gcloud pubsub topics list --project={{GCP_PROJECT_ID}}-staging
  # Expected: Topics listed
  ```

---

## Phase 7: Security Validation

- [ ] **7.1 Run OPA policy checks**
  ```bash
  cd environments/staging
  terraform plan -out=tfplan
  terraform show -json tfplan > tfplan.json
  conftest test tfplan.json --policy ../../policies/
  ```
  **Verify:**
  ```bash
  # Expected: No DENY results (warnings OK)
  ```

- [ ] **7.2 Run tfsec**
  ```bash
  tfsec . --minimum-severity HIGH
  ```
  **Verify:**
  ```bash
  # Expected: No HIGH or CRITICAL findings
  ```

- [ ] **7.3 Run Checkov**
  ```bash
  checkov -d . --framework terraform --compact --skip-path .terraform
  ```
  **Verify:**
  ```bash
  # Expected: All checks passed or known skips
  ```

- [ ] **7.4 Run Gitleaks**
  ```bash
  gitleaks detect --source . --verbose
  ```
  **Verify:**
  ```bash
  # Expected: No leaks detected
  ```

---

## Phase 8: CI/CD Pipeline Verification

- [ ] **8.1 Verify terraform-plan workflow**
  ```bash
  # Create a PR with a Terraform change
  # Expected: terraform-plan workflow runs, posts plan to PR comments
  gh pr checks <PR_NUMBER>
  ```

- [ ] **8.2 Verify terraform-apply workflow**
  ```bash
  # Merge PR to main
  # Expected: terraform-apply workflow runs, applies to staging
  gh run list --workflow=terraform-apply.yml
  ```

- [ ] **8.3 Verify drift detection**
  ```bash
  # Trigger manually
  gh workflow run terraform-drift.yml --field environment=staging
  ```
  **Verify:**
  ```bash
  gh run list --workflow=terraform-drift.yml
  # Expected: Run completed, no drift issues created (if state is current)
  ```

- [ ] **8.4 Verify packer-build workflow**
  ```bash
  gh workflow run packer-build.yml
  ```
  **Verify:**
  ```bash
  gh run list --workflow=packer-build.yml
  # Expected: Validate + Security Scan + Build completed
  ```

---

## Phase 9: Production Deployment

- [ ] **9.1 Create production environment in GitHub**
  ```bash
  # Add environment protection rules (manual approval, reviewers)
  # Configure production secrets
  gh secret set GCP_PRODUCTION_SERVICE_ACCOUNT --body="<production SA email>"
  ```

- [ ] **9.2 Apply production infrastructure**
  ```bash
  cd environments/production
  terraform init
  terraform plan -out=tfplan
  terraform apply tfplan
  ```
  **Verify:**
  ```bash
  terraform output
  # Expected: All outputs populated for production
  ```

- [ ] **9.3 Verify production cluster health**
  ```bash
  gcloud compute ssh $(terraform output -raw control_plane_name) \
    --zone=$(terraform output -raw control_plane_zone) \
    --tunnel-through-iap \
    --command="sudo kubectl get nodes && sudo kubectl get pods -A"
  # Expected: 2 Ready nodes, all system pods running
  ```

<!-- feynman-check -->

---

## Feynman check

Close the file. Blank page, no notes. Explain each of these to a competent engineer who has never
used this tool — **under five minutes, no jargon you can't define on the spot:**

- GCP Project Setup [GCP-SPECIFIC]
- Workload Identity Federation [GCP-SPECIFIC]
- Network Foundation
- Packer Image Build [KUBEADM-SPECIFIC]

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
