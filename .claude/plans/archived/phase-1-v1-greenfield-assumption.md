# Phase 1: Foundation & GCP Infrastructure
## Apigee Pipeline Implementation - Complete Infrastructure Plan

**Document Version:** 2.0 (Updated for pcc-foundation-infra Integration)
**Phase:** 1 (Apigee Infrastructure Deployment)
**Date:** 2025-10-17
**Status:** Requires Phase 0 Completion First
**Prerequisites:** Phase 0 - Add 2 Apigee projects to pcc-foundation-infra (see pcc-foundation-infra-apigee-updates.md)

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Phase 1 Objectives](#phase-1-objectives)
3. [High-Level Architecture](#high-level-architecture)
4. [Implementation Plan](#implementation-plan)
5. [Terraform Modules](#terraform-modules)
6. [Infrastructure Configuration](#infrastructure-configuration)
7. [Deployment Workflow](#deployment-workflow)
8. [Validation & Testing](#validation--testing)
9. [Security & IAM Architecture](#security--iam-architecture)
10. [Multi-Environment Scaling](#multi-environment-scaling)
11. [Troubleshooting](#troubleshooting)
12. [Success Criteria](#success-criteria)

---

## Executive Summary

Phase 1 establishes the complete GCP infrastructure foundation for the Apigee CI/CD pipeline. This phase provisions all resources via **Terraform Infrastructure as Code**, enabling GitOps-based deployment of 7 .NET 10 microservices through Apigee X API Gateway.

### Key Deliverables

**Infrastructure Components:**
- Apigee X organization and `devtest` environment
- Artifact Registry repository for Docker images
- Secret Manager for credentials (git-token, argocd-password, apigee-access-token)
- GCS bucket for OpenAPI specifications
- IAM service accounts with least-privilege bindings
- GKE namespace with Workload Identity

**Code Artifacts:**
- 6 production-ready Terraform modules in `core/pcc-tf-library/modules/`
- Infrastructure configuration in `infra/pcc-app-shared-infra/terraform/`
- Validation scripts and testing procedures
- Complete documentation
- Apigee X Networking Specification (VPC peering, Cloud NAT, service networking)
- Traffic Routing & TLS Specification (load balancers, certificates, DNS)

### Architectural Principles

- **Terraform-First:** 100% Infrastructure as Code (no manual provisioning)
- **Workload Identity:** Zero service account key files
- **Least-Privilege IAM:** Minimal permissions per workload
- **Environment Isolation:** Dedicated API products per environment
- **GitOps Ready:** Remote state management, version control

### Business Value

- **Security:** Zero hardcoded secrets, automatic credential rotation, full audit trail
- **Scalability:** Architecture supports 50+ microservices across 4 environments (devtest, dev, staging, prod)
- **Environment Isolation:** Two-organization architecture (non-prod + prod) provides safe infrastructure testing while maintaining cost-effectiveness
- **Operational Excellence:** 5-minute environment provisioning, automated compliance

**Architecture Decision:** See [ADR 001: Two-Organization Apigee X Architecture](../docs/ADR/001-two-org-apigee-architecture.md) for detailed rationale

---

## Phase 1 Objectives

### Primary Goals

1. **Provision GCP Infrastructure**
   - Deploy Apigee X organization and devtest environment
   - Create Artifact Registry for Docker images
   - Setup Secret Manager with all required secrets
   - Provision GCS bucket for OpenAPI specs
   - Configure IAM service accounts and bindings

2. **Establish Terraform Patterns**
   - Create reusable Terraform modules
   - Implement environment-specific configurations
   - Setup remote state management in GCS
   - Document module usage and patterns

3. **Enable GitOps Workflow**
   - Configure Workload Identity for GKE
   - Create Kubernetes namespace and service accounts
   - Establish security boundaries
   - Prepare for ArgoCD integration

4. **Validate Infrastructure**
   - Automated validation scripts
   - Manual verification procedures
   - Security and compliance checks
   - Documentation of outputs

### Out of Scope (Future Phases)

- Apigee X networking infrastructure (Phase 1b): VPC peering, service networking, Cloud NAT
- Traffic routing and TLS (Phase 1b): External HTTPS load balancers, Google-managed certificates, DNS
- Cloud Build pipeline creation (Phase 2)
- ArgoCD application configuration (Phase 3)
- Apigee proxy deployment (Phase 4)
- Multi-environment rollout (Phases 5-8)

---

## High-Level Architecture

### Component Relationship Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           TERRAFORM INFRASTRUCTURE                           │
│  ┌────────────────────┐  ┌────────────────────┐  ┌────────────────────┐   │
│  │ Terraform Modules  │  │ Infrastructure     │  │ Remote State       │   │
│  │ (pcc-tf-library)   │  │ Configs            │  │ (GCS Bucket)       │   │
│  │ - apigee-iam       │  │ (pcc-app-shared-   │  │ - State locking    │   │
│  │ - artifact-registry│  │  infra/terraform)  │  │ - Versioning       │   │
│  │ - secret-manager   │  │ - main.tf          │  │ - Team access      │   │
│  │ - gcs-bucket       │  │ - variables.tf     │  │                    │   │
│  │ - apigee-resources │  │ - outputs.tf       │  │                    │   │
│  │ - k8s-namespace    │  │ - versions.tf      │  │                    │   │
│  └────────┬───────────┘  └────────┬───────────┘  └────────┬───────────┘   │
└───────────┼──────────────────────┼─────────────────────────┼───────────────┘
            │                      │                         │
            │ (imported by)        │ (terraform apply)       │ (state storage)
            ▼                      ▼                         ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                            GCP INFRASTRUCTURE                                │
│  ┌───────────────────────────────────────────────────────────────────┐     │
│  │ GCP PROJECTS: 4 projects (pcc-devtest, pcc-dev, pcc-staging,     │     │
│  │ pcc-prod) for GKE, databases, and other infrastructure           │     │
│  │                                                                    │     │
│  │ APIGEE X ORGANIZATIONS: 2 orgs hosted in 2 of 4 projects         │     │
│  │                                                                    │     │
│  │ Non-Prod Apigee Org (hosted in pcc-dev project)                  │     │
│  │ • Organization: pcc-dev (Apigee org ID)                          │     │
│  │ • Environments: devtest, dev                                      │     │
│  │ • API Product: pcc-all-services-devtest                          │     │
│  │ • Quota: 1000 req/min                                            │     │
│  │                                                                    │     │
│  │ Prod Apigee Org (hosted in pcc-prod project)                     │     │
│  │ • Organization: pcc-prod (Apigee org ID)                         │     │
│  │ • Environments: staging, prod                                     │     │
│  │ • Purpose: Customer-facing environments                           │     │
│  └───────────────────────────────────────────────────────────────────┘     │
│                                                                              │
│  ┌───────────────────────────────────────────────────────────────────┐     │
│  │ ARTIFACT REGISTRY                                                  │     │
│  │ • Repository: pcc-images                                          │     │
│  │ • Location: us-central1                                           │     │
│  │ • Format: Docker                                                  │     │
│  └───────────────────────────────────────────────────────────────────┘     │
│                                                                              │
│  ┌───────────────────────────────────────────────────────────────────┐     │
│  │ SECRET MANAGER                                                     │     │
│  │ • git-token (GitHub access)                                       │     │
│  │ • argocd-password (ArgoCD auth)                                   │     │
│  │ • apigee-access-token (Apigee Management API)                    │     │
│  └───────────────────────────────────────────────────────────────────┘     │
│                                                                              │
│  ┌───────────────────────────────────────────────────────────────────┐     │
│  │ GCS BUCKET                                                         │     │
│  │ • Name: pcc-specs-devtest-pcc-dev                                │     │
│  │ • Versioning: Enabled                                             │     │
│  │ • Purpose: OpenAPI specifications (per environment)               │     │
│  │ • Note: Separate buckets per environment in each project          │     │
│  └───────────────────────────────────────────────────────────────────┘     │
│                                                                              │
│  ┌───────────────────────────────────────────────────────────────────┐     │
│  │ IAM SERVICE ACCOUNTS                                               │     │
│  │ • pcc-cloud-build-sa (CI/CD orchestration)                        │     │
│  │ • pcc-apigee-runtime-sa (Apigee proxy runtime)                   │     │
│  │ • IAM Roles: apigee.admin, container.developer, etc.             │     │
│  └───────────────────────────────────────────────────────────────────┘     │
│                                                                              │
│  ┌───────────────────────────────────────────────────────────────────┐     │
│  │ GKE RESOURCES                                                      │     │
│  │ • Namespace: pcc-devtest                                          │     │
│  │ • Service Account: pcc-app-sa                                     │     │
│  │ • Workload Identity: Enabled                                      │     │
│  └───────────────────────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Data Flow: Infrastructure Provisioning

```
Developer         Terraform CLI        GCP APIs            Resources
    │                  │                   │                   │
    │ terraform init   │                   │                   │
    ├─────────────────>│                   │                   │
    │                  │ Download providers│                   │
    │                  ├──────────────────>│                   │
    │                  │                   │                   │
    │ terraform plan   │                   │                   │
    ├─────────────────>│                   │                   │
    │                  │ Read current state│                   │
    │                  ├──────────────────>│                   │
    │                  │                   │ Query resources   │
    │                  │                   ├──────────────────>│
    │                  │                   │ Return status     │
    │                  │                   │<──────────────────┤
    │                  │ Calculate diff    │                   │
    │<─────────────────┤                   │                   │
    │ [Review plan]    │                   │                   │
    │                  │                   │                   │
    │ terraform apply  │                   │                   │
    ├─────────────────>│                   │                   │
    │                  │ Create resources  │                   │
    │                  ├──────────────────>│                   │
    │                  │                   │ Provision Apigee  │
    │                  │                   ├──────────────────>│
    │                  │                   │ Create IAM        │
    │                  │                   ├──────────────────>│
    │                  │                   │ Setup Registry    │
    │                  │                   ├──────────────────>│
    │                  │                   │ Configure Secrets │
    │                  │                   ├──────────────────>│
    │                  │ Update state      │                   │
    │                  ├──────────────────>│                   │
    │<─────────────────┤                   │                   │
    │ [Success]        │                   │                   │
    │                  │                   │                   │
    │ Validation script│                   │                   │
    ├─────────────────────────────────────>│                   │
    │                  │                   │ Verify resources  │
    │                  │                   ├──────────────────>│
    │<─────────────────────────────────────┤                   │
    │ [All tests pass] │                   │                   │
```

---

## Implementation Plan

### Timeline & Milestones

**Total Duration:** 4-6 hours (first-time), 30 minutes (subsequent environments)

#### Milestone 1: Module Development (2 hours)

**Tasks:**
1. Create `core/pcc-tf-library/modules/apigee-iam/`
   - Service accounts (Cloud Build, Apigee Runtime)
   - IAM role bindings
   - Input validation and outputs

2. Create `core/pcc-tf-library/modules/artifact-registry/`
   - Docker repository
   - IAM bindings for Cloud Build SA
   - Enable Artifact Registry API

3. Create `core/pcc-tf-library/modules/secret-manager/`
   - Secret definitions with lifecycle management
   - IAM bindings for accessor roles
   - Placeholder values for initialization

4. Create `core/pcc-tf-library/modules/gcs-bucket/`
   - GCS bucket with versioning
   - Lifecycle policies
   - IAM bindings

5. Create `core/pcc-tf-library/modules/apigee-resources/`
   - Apigee organization
   - Environment configuration
   - API product with quotas

6. Create `core/pcc-tf-library/modules/k8s-namespace/`
   - Kubernetes namespace
   - Service account with Workload Identity
   - IAM bindings

**Deliverable:** 6 production-ready Terraform modules with complete documentation

---

#### Milestone 2: Infrastructure Configuration (1 hour)

**Tasks:**
1. Create `infra/pcc-app-shared-infra/terraform/versions.tf`
   - Terraform and provider version constraints
   - GCS backend configuration
   - Kubernetes provider setup

2. Create `infra/pcc-app-shared-infra/terraform/main.tf`
   - Module invocations
   - Enable required GCP APIs
   - Dependency management

3. Create `infra/pcc-app-shared-infra/terraform/variables.tf`
   - Input variables with validation
   - Defaults for common values
   - Environment-specific overrides

4. Create `infra/pcc-app-shared-infra/terraform/outputs.tf`
   - Export resource IDs and URLs
   - Service account emails
   - Namespace names

5. Create `infra/pcc-app-shared-infra/terraform/environments/devtest.tfvars`
   - Environment-specific values
   - API quotas and scopes
   - Resource naming

**Deliverable:** Complete infrastructure configuration ready for deployment

---

#### Milestone 3: Deployment (1-2 hours)

**Tasks:**
1. Initialize Terraform
   - Create GCS bucket for state
   - Run `terraform init`
   - Verify provider installation

2. Validate configuration
   - Run `terraform validate`
   - Run `terraform fmt`
   - Review for compliance

3. Plan infrastructure changes
   - Run `terraform plan` with devtest.tfvars
   - Review resource changes
   - Confirm no unexpected modifications

4. Apply infrastructure
   - Run `terraform apply`
   - Monitor Apigee organization provisioning (slow)
   - Verify all resources created

5. Update secret values
   - Replace placeholder values with real credentials
   - Test secret access from Cloud Build SA

**Deliverable:** Fully provisioned GCP infrastructure in devtest environment

---

#### Milestone 4: Validation & Documentation (1 hour)

**Tasks:**
1. Run automated validation script
   - 9 validation tests
   - Verify all resources exist
   - Check IAM bindings

2. Manual verification
   - gcloud commands for each resource
   - kubectl commands for K8s resources
   - Test Workload Identity bindings

3. Security audit
   - Verify no service account keys
   - Check uniform bucket-level access
   - Review IAM least-privilege

4. Update documentation
   - Capture Terraform outputs
   - Document deployment steps
   - Create troubleshooting guide

**Deliverable:** Validated infrastructure with complete documentation

---

## Terraform Modules

### Module 1: Apigee IAM

**Purpose:** Provision service accounts and IAM bindings for Cloud Build and Apigee Runtime.

**Location:** `core/pcc-tf-library/modules/apigee-iam/`

**Resources:**
- `google_service_account.cloud_build` - Cloud Build pipeline SA
- `google_service_account.apigee_runtime` - Apigee proxy runtime SA
- `google_project_iam_member.*` - IAM role bindings

**Inputs:**
- `project_id` (required) - GCP project ID
- `cloud_build_sa_name` (default: "pcc-cloud-build-sa")
- `apigee_runtime_sa_name` (default: "pcc-apigee-runtime-sa")

**Outputs:**
- `cloud_build_sa_email` - Email of Cloud Build SA
- `cloud_build_sa_id` - Unique ID of Cloud Build SA
- `apigee_runtime_sa_email` - Email of Apigee Runtime SA
- `apigee_runtime_sa_id` - Unique ID of Apigee Runtime SA

**IAM Roles (Cloud Build SA):**
- `roles/apigee.admin` - Create/update Apigee proxies
- `roles/container.developer` - Push Docker images
- `roles/secretmanager.secretAccessor` - Read secrets
- `roles/storage.admin` - Upload OpenAPI specs
- `roles/logging.logWriter` - Write build logs

**Reference:** See complete implementation in `.claude/plans/phase-1a-gcp-preflight-checklist.md` lines 148-266

---

### Module 2: Artifact Registry

**Purpose:** Create Docker repository for microservice images with Cloud Build SA write access.

**Location:** `core/pcc-tf-library/modules/artifact-registry/`

**Resources:**
- `google_project_service.artifact_registry` - Enable API
- `google_artifact_registry_repository.main` - Docker repository
- `google_artifact_registry_repository_iam_member.cloud_build_writer` - IAM binding

**Inputs:**
- `project_id` (required)
- `location` (required) - Region for repository
- `repository_id` (required) - Repository name
- `description` (default: "Docker repository for PCC microservices")
- `immutable_tags` (default: false)
- `cloud_build_sa_email` (required) - For IAM binding

**Outputs:**
- `repository_id` - Repository ID
- `repository_location` - Repository region
- `repository_url` - Full URL (e.g., us-central1-docker.pkg.dev/PROJECT/pcc-images)

**Reference:** See complete implementation in `.claude/plans/phase-1a-gcp-preflight-checklist.md` lines 270-374

---

### Module 3: Secret Manager

**Purpose:** Create secrets with placeholder values and automatic rotation lifecycle.

**Location:** `core/pcc-tf-library/modules/secret-manager/`

**Resources:**
- `google_project_service.secret_manager` - Enable API
- `google_secret_manager_secret.secrets` - Secret definitions
- `google_secret_manager_secret_version.initial` - Placeholder versions
- `google_secret_manager_secret_iam_member.cloud_build_accessor` - IAM binding

**Inputs:**
- `project_id` (required)
- `environment` (required)
- `secrets` (map) - Secret configurations with placeholder values
- `cloud_build_sa_email` (required)

**Outputs:**
- `secret_ids` - Map of secret names to IDs
- `secret_versions` - Map of secret names to latest version resource names

**Secrets to Create:**
- `git-token` - GitHub API access
- `argocd-password` - ArgoCD admin password
- `apigee-access-token` - Apigee Management API token

**Reference:** See complete implementation in `.claude/plans/phase-1a-gcp-preflight-checklist.md` lines 378-485

---

### Module 4: GCS Bucket

**Purpose:** Create GCS bucket for OpenAPI specifications with versioning and lifecycle policies.

**Location:** `core/pcc-tf-library/modules/gcs-bucket/`

**Resources:**
- `google_project_service.storage` - Enable API
- `google_storage_bucket.main` - GCS bucket
- `google_storage_bucket_iam_member.cloud_build_admin` - IAM binding

**Inputs:**
- `project_id` (required)
- `bucket_name` (required) - Must be globally unique
- `location` (required)
- `environment` (required)
- `versioning_enabled` (default: true)
- `lifecycle_age_days` (default: 30)
- `force_destroy` (default: false)
- `cloud_build_sa_email` (required)

**Outputs:**
- `bucket_name` - Bucket name
- `bucket_url` - Bucket URL
- `bucket_self_link` - Self link

**Reference:** See complete implementation in `.claude/plans/phase-1a-gcp-preflight-checklist.md` lines 489-620

---

### Module 5: Apigee Resources

**Purpose:** Provision Apigee organization, environment, and API product.

**Location:** `core/pcc-tf-library/modules/apigee-resources/`

**Resources:**
- `google_project_service.apigee` - Enable API
- `google_apigee_organization.main` - Apigee X organization
- `google_apigee_environment.main` - Environment
- `google_apigee_product.main` - API product

**Inputs:**
- `project_id` (required)
- `analytics_region` (default: "us-central1")
- `environment` (required) - Must be: devtest, dev, staging, prod
- `api_product_name` (required)
- `api_product_display_name` (required)
- `quota_limit` (default: "1000")
- `quota_interval` (default: "1")
- `quota_time_unit` (default: "minute")
- `api_scopes` (list) - API access scopes

**Outputs:**
- `apigee_org_id` - Organization ID
- `apigee_org_name` - Organization name
- `apigee_environment_name` - Environment name
- `api_product_name` - API product name
- `api_product_id` - API product ID

**Note:** Apigee organization provisioning can take 30-45 minutes.

**Reference:** See complete implementation in `.claude/plans/phase-1a-gcp-preflight-checklist.md` lines 624-781

---

### Module 6: Kubernetes Namespace

**Purpose:** Create GKE namespace with service account and Workload Identity binding.

**Location:** `core/pcc-tf-library/modules/k8s-namespace/`

**Resources:**
- `kubernetes_namespace.main` - K8s namespace
- `kubernetes_service_account.main` - K8s service account
- `google_service_account_iam_member.workload_identity` - Workload Identity binding

**Inputs:**
- `project_id` (required)
- `namespace_name` (required) - Must be valid DNS label
- `environment` (required)
- `service_account_name` (default: "pcc-app-sa")
- `workload_identity_enabled` (default: true)
- `gcp_service_account_email` (required if WI enabled)
- `gcp_service_account_id` (required if WI enabled)

**Outputs:**
- `namespace_name` - K8s namespace name
- `service_account_name` - K8s service account name

**Reference:** See complete implementation in `.claude/plans/phase-1a-gcp-preflight-checklist.md` lines 785-901

---

## Infrastructure Configuration

### Directory Structure

```
infra/pcc-app-shared-infra/terraform/
├── main.tf                 # Module invocations
├── variables.tf            # Input variables
├── outputs.tf              # Exported values
├── versions.tf             # Provider versions and backend
├── terraform.tfvars        # Default values (optional)
└── environments/
    ├── devtest.tfvars      # Devtest environment config
    ├── dev.tfvars          # Dev environment config (future)
    ├── staging.tfvars      # Staging environment config (future)
    └── prod.tfvars         # Production environment config (future)
```

### Module Orchestration

**File:** `infra/pcc-app-shared-infra/terraform/main.tf`

**Pattern:**
1. Enable required GCP APIs
2. Invoke Apigee IAM module (creates service accounts)
3. Invoke Artifact Registry module (uses Cloud Build SA)
4. Invoke Secret Manager module (uses Cloud Build SA)
5. Invoke GCS Bucket module (uses Cloud Build SA)
6. Invoke Apigee Resources module (creates org/env/product)
7. Invoke K8s Namespace module (uses Apigee Runtime SA)

**Dependencies:**
- All modules depend on API enablement
- Modules 3-5 depend on module 2 (Cloud Build SA)
- Module 7 depends on module 2 (Apigee Runtime SA)

**Reference:** See complete configuration in `.claude/plans/phase-1a-gcp-preflight-checklist.md` lines 974-1096

---

### Backend Configuration

**File:** `infra/pcc-app-shared-infra/terraform/versions.tf`

**GCS Backend:**
- Nonprod Apigee org: `pcc-terraform-state-dev` (in pcc-dev project)
- Prod Apigee org: `pcc-terraform-state-prod` (in pcc-prod project)
- Prefix: `shared-infra/terraform.tfstate`
- Versioning: Enabled
- State locking: Automatic

**Provider Versions:**
- Terraform: >= 1.6.0
- Google Provider: >= 5.0.0
- Kubernetes Provider: >= 2.20.0

**Reference:** See complete configuration in `.claude/plans/phase-1a-gcp-preflight-checklist.md` lines 927-971

---

### Environment Configuration

**File:** `infra/pcc-app-shared-infra/terraform/environments/nonprod/devtest.tfvars`

**Key Values:**
- `project_id`: "pcc-dev" (hosts nonprod Apigee org)
- `apigee_org_id`: "pcc-dev"
- `region`: "us-central1"
- `zone`: "us-central1-a"
- `environment`: "devtest"
- `cluster_name`: "pcc-cluster-dev"
- `api_quota_limit`: "1000"
- `api_scopes`: [auth.read, auth.write, user.read, user.write, ...]

**File:** `infra/pcc-app-shared-infra/terraform/environments/prod/staging.tfvars`

**Key Values:**
- `project_id`: "pcc-prod" (hosts prod Apigee org)
- `apigee_org_id`: "pcc-prod"
- `environment`: "staging"
- `api_quota_limit`: "10000"

**Note:** 4 GCP projects exist (pcc-devtest, pcc-dev, pcc-staging, pcc-prod) but only pcc-dev and pcc-prod host Apigee organizations

**Reference:** See complete configuration in `.claude/plans/phase-1a-gcp-preflight-checklist.md` lines 1205-1227

---

## Deployment Workflow

### Prerequisites

**Required Tools:**
- Terraform >= 1.6.0
- gcloud CLI >= 450.0.0
- kubectl >= 1.28.0
- jq >= 1.6

**Authentication:**
```bash
# GCP authentication
gcloud auth login
gcloud auth application-default login

# Set project (use pcc-dev for devtest/dev environments, pcc-prod for staging/prod)
export PROJECT_ID="pcc-dev"  # or "pcc-prod" for staging/prod
gcloud config set project $PROJECT_ID
```

**Permissions Required:**
- `roles/owner` OR granular roles:
  - `roles/apigee.admin` (for organization/instance provisioning)
  - `roles/iam.serviceAccountAdmin`
  - `roles/iam.securityAdmin`
  - `roles/storage.admin` (for Terraform state bucket)
  - `roles/artifactregistry.admin`
  - `roles/secretmanager.admin`
  - `roles/serviceusage.serviceUsageAdmin`
  - `roles/compute.networkAdmin`

---

### Step-by-Step Deployment

#### Step 1: Create State Bucket (One-Time)

```bash
# Create GCS bucket for Terraform state (one per Apigee org)
# Non-prod Apigee org state (in pcc-dev project)
gsutil mb -p pcc-dev -c STANDARD -l us-central1 gs://pcc-terraform-state-dev
gsutil versioning set on gs://pcc-terraform-state-dev

# Prod Apigee org state (in pcc-prod project)
gsutil mb -p pcc-prod -c STANDARD -l us-central1 gs://pcc-terraform-state-prod
gsutil versioning set on gs://pcc-terraform-state-prod
```

---

#### Step 2: Initialize Terraform

```bash
cd $HOME/pcc/pcc-project/infra/pcc-app-shared-infra/terraform

terraform init
```

**Expected Output:**
```
Initializing modules...
Initializing the backend...
Initializing provider plugins...

Terraform has been successfully initialized!
```

---

#### Step 3: Validate Configuration

```bash
terraform validate
terraform fmt -recursive
```

**Expected Output:**
```
Success! The configuration is valid.
```

---

#### Step 4: Plan Infrastructure

```bash
terraform plan -var-file="environments/nonprod/devtest.tfvars" -out=tfplan
```

**Expected Output:**
```
Plan: 25 to add, 0 to change, 0 to destroy.
```

**Review carefully:**
- Correct project ID and region
- Service accounts being created
- IAM bindings are correct
- No unexpected deletions

---

#### Step 5: Apply Infrastructure

```bash
terraform apply tfplan
```

**Expected Output:**
```
Apply complete! Resources: 25 added, 0 changed, 0 destroyed.

Outputs:
cloud_build_sa_email = "pcc-cloud-build-sa@pcc-dev.iam.gserviceaccount.com"
artifact_registry_url = "us-central1-docker.pkg.dev/pcc-dev/pcc-images"
gcs_bucket_name = "pcc-specs-devtest-pcc-dev"
apigee_org_id = "organizations/pcc-dev"
apigee_environment = "devtest"
api_product_name = "pcc-all-services-devtest"
k8s_namespace = "pcc-devtest"
```

**Duration:** 15-30 minutes (Apigee provisioning is slow)

---

#### Step 6: Update Secret Values

```bash
# Replace placeholder values with real credentials
echo -n "ghp_REAL_GITHUB_TOKEN" | gcloud secrets versions add git-token --data-file=-
echo -n "REAL_ARGOCD_PASSWORD" | gcloud secrets versions add argocd-password --data-file=-
echo -n "REAL_APIGEE_TOKEN" | gcloud secrets versions add apigee-access-token --data-file=-
```

---

#### Step 7: Commit Changes

```bash
git add .terraform.lock.hcl *.tf environments/*.tfvars
git commit -m "feat: provision Phase 1 GCP infrastructure via Terraform"
git push
```

---

## Validation & Testing

### Automated Validation Script

**Location:** Create `/tmp/validate-terraform-deployment.sh`

**Tests (9 total):**
1. Apigee organization exists
2. Apigee environment 'devtest' exists
3. Artifact Registry 'pcc-images' exists
4. GCS bucket exists
5. Cloud Build SA exists
6. 3 secrets exist in Secret Manager
7. GKE namespace 'pcc-devtest' exists
8. K8s service account 'pcc-app-sa' exists
9. Workload Identity annotation configured

**Usage:**
```bash
chmod +x /tmp/validate-terraform-deployment.sh
/tmp/validate-terraform-deployment.sh
```

**Expected Output:**
```
=========================================
Terraform Deployment Validation
Project: pcc-dev (nonprod Apigee org)
Environment: devtest
=========================================

Test 1: Apigee organization exists... PASS
Test 2: Apigee environment 'devtest' exists... PASS
Test 3: Artifact Registry 'pcc-images' exists... PASS
Test 4: GCS bucket exists... PASS
Test 5: Cloud Build SA exists... PASS
Test 6: Secret Manager secrets exist... PASS (3/3 secrets)
Test 7: GKE namespace 'pcc-devtest' exists... PASS
Test 8: K8s service account 'pcc-app-sa' exists... PASS
Test 9: Workload Identity annotation configured... PASS

=========================================
Results: 9 passed, 0 failed
=========================================
✓ Terraform deployment validation PASSED
```

**Reference:** See complete script in `.claude/plans/phase-1a-gcp-preflight-checklist.md` lines 1360-1485

---

### Manual Verification

#### Verify Apigee Organization

```bash
gcloud apigee organizations describe $PROJECT_ID
```

**Expected:** Organization details with `runtimeType: CLOUD`

---

#### Verify Artifact Registry

```bash
gcloud artifacts repositories describe pcc-images --location=us-central1
```

**Expected:** Repository format: DOCKER

---

#### Verify Secret Manager

```bash
gcloud secrets list --filter="labels.environment=devtest"
```

**Expected:** 3 secrets (git-token, argocd-password, apigee-access-token)

---

#### Verify GCS Bucket

```bash
gsutil ls -L gs://pcc-specs-devtest-${PROJECT_ID}
```

**Expected:** Bucket with uniform bucket-level access enabled

---

#### Verify IAM Bindings

```bash
gcloud projects get-iam-policy $PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:pcc-cloud-build-sa@*" \
  --format="table(bindings.role)"
```

**Expected Roles:**
- roles/apigee.admin
- roles/container.developer
- roles/secretmanager.secretAccessor
- roles/storage.admin
- roles/logging.logWriter

---

#### Verify Kubernetes Resources

```bash
# Namespace
kubectl get namespace pcc-devtest

# Service account
kubectl get sa pcc-app-sa -n pcc-devtest

# Workload Identity annotation
kubectl get sa pcc-app-sa -n pcc-devtest -o yaml | grep iam.gke.io
```

**Expected:** Annotation pointing to `pcc-apigee-runtime-sa@PROJECT_ID.iam.gserviceaccount.com`

---

## Security & IAM Architecture

### Service Account Hierarchy

```
PROJECT (pcc-portcon-prod)
│
├── CLOUD BUILD SERVICE ACCOUNT
│   └── pcc-cloud-build-sa@PROJECT.iam.gserviceaccount.com
│       • Purpose: Execute CI/CD pipeline
│       • Roles: apigee.admin, container.developer, secretAccessor, storage.admin
│       • Authentication: Workload Identity Pool (GitHub Actions)
│
├── APIGEE RUNTIME SERVICE ACCOUNT
│   └── pcc-apigee-runtime-sa@PROJECT.iam.gserviceaccount.com
│       • Purpose: Apigee proxy runtime operations
│       • Roles: apigee.runtimeAgent
│       • Bound to K8s SA: pcc-app-sa (namespace: pcc-devtest)
│
└── KUBERNETES SERVICE ACCOUNT
    └── pcc-app-sa (namespace: pcc-devtest)
        • Purpose: GKE workload identity
        • Annotation: iam.gke.io/gcp-service-account = pcc-apigee-runtime-sa@...
```

### Security Principles

**1. Zero Service Account Keys**
- All authentication via Workload Identity
- No JSON key files stored anywhere
- Automatic credential rotation

**2. Least-Privilege IAM**
- Service accounts granted minimum required permissions
- Resource-level IAM bindings where possible
- Regular permission audits

**3. Secret Management**
- All credentials in Secret Manager
- Placeholder values in Terraform
- Manual updates after provisioning
- Automatic rotation lifecycle

**4. Network Security**
- Uniform bucket-level access on GCS
- Private GKE endpoints (future)
- Authorized networks for Apigee (future)

**Reference:** See complete security architecture in `.claude/plans/phase-1a-architecture-design.md` lines 318-349

---

## Multi-Environment Scaling

### Architecture Decision: Two-Organization Strategy

**Important:** This project uses **two Apigee Organizations** hosted in 2 of 4 GCP projects, as documented in [ADR 001](../docs/ADR/001-two-org-apigee-architecture.md):

**GCP Project Structure:**
- **4 GCP projects exist:** pcc-devtest, pcc-dev, pcc-staging, pcc-prod (for GKE, databases, and other infrastructure)
- **2 projects host Apigee:** pcc-dev (nonprod Apigee org), pcc-prod (prod Apigee org)

**Non-Prod Apigee Organization** (hosted in `pcc-dev` project):
- **devtest** environment → Internal development and infrastructure testing
- **dev** environment → Stable development testing
- **Purpose:** Safe environment for org-level infrastructure changes (networking, IAM, scaling)

**Prod Apigee Organization** (hosted in `pcc-prod` project):
- **staging** environment → Customer integration testing (production-identical)
- **prod** environment → Live customer traffic
- **Purpose:** Customer-facing environments with production SLAs

This architecture balances cost-effectiveness with critical isolation needs, enabling safe org-level infrastructure testing while maintaining seamless staging-to-production promotion.

### Environment Promotion Flow

```
GCP PROJECTS: pcc-devtest, pcc-dev, pcc-staging, pcc-prod
APIGEE ORGS:  (none)        nonprod org  (none)          prod org

NON-PROD APIGEE ORG          PROD APIGEE ORG
(hosted in pcc-dev project)  (hosted in pcc-prod project)
┌────────────────┐           ┌────────────────┐
│    devtest     │           │    staging     │
│  (infra test)  │           │ (customer test)│
└───────┬────────┘           └───────┬────────┘
        │                            │
        ▼                            ▼
┌────────────────┐           ┌────────────────┐
│      dev       │           │      prod      │
│ (stable dev)   │           │  (live traffic)│
└───────┬────────┘           └────────────────┘
        │
        └─────────[CROSS-ORG PROMOTION]────────►
                  (export/import artifacts)
```

**Promotion Path:**
- **devtest → dev:** Within non-prod org (simple environment promotion)
- **dev → staging:** Cross-org promotion (artifact export/import, infrastructure parity validation)
- **staging → prod:** Within prod org (simple environment promotion, manual approval)

**Key Benefits:**
- Org-level changes tested in non-prod org before prod
- Staging → prod is seamless (same org, same infrastructure)
- Customer integration testing in production-identical staging environment

### Environment Configuration Matrix

| Attribute | devtest | dev | staging | prod |
|-----------|---------|-----|---------|------|
| **GCP Project (infrastructure)** | **pcc-devtest** | **pcc-dev** | **pcc-staging** | **pcc-prod** |
| **Apigee Org Hosting** | pcc-dev | **pcc-dev** | pcc-prod | **pcc-prod** |
| **Apigee Organization** | **Non-Prod** | **Non-Prod** | **Prod** | **Prod** |
| **Organization Boundary** | ← Same Org → | ← Same Org → | ← Same Org → | ← Same Org → |
| **Cross-Org Transition** |  | dev → staging (export/import) |  |  |
| **API Product Approval** | Auto | Auto | Manual | Manual |
| **Quota (req/min)** | 1000 | 5000 | 10000 | 50000 |
| **Terraform Config Path** | nonprod/devtest.tfvars | nonprod/dev.tfvars | prod/staging.tfvars | prod/prod.tfvars |
| **GKE Namespace** | pcc-devtest | pcc-dev | pcc-staging | pcc-prod |
| **GCS Bucket** | pcc-specs-devtest-dev | pcc-specs-dev-dev | pcc-specs-staging-prod | pcc-specs-prod-prod |
| **Customer-Facing** | No | No | Yes (integration testing) | Yes (live traffic) |

**Note:** 4 GCP projects exist for infrastructure (GKE, databases, etc.), but only 2 host Apigee organizations (pcc-dev and pcc-prod)

### Scaling to New Environments

**To deploy additional environments within existing organizations:**

**Deploy `dev` environment (within non-prod org):**
```bash
cd $HOME/pcc/pcc-project/infra/pcc-app-shared-infra/terraform

# Plan with dev config (same non-prod project, adds dev environment)
terraform plan -var-file="environments/nonprod/dev.tfvars" -out=tfplan-dev

# Review and apply
terraform apply tfplan-dev
```

**Deploy `staging` environment (within prod org):**
```bash
# Plan with staging config (prod project, adds staging environment)
terraform plan -var-file="environments/prod/staging.tfvars" -out=tfplan-staging

# Review and apply
terraform apply tfplan-staging
```

**Note:** Environments within the same organization (devtest/dev, staging/prod) share org-level infrastructure (networking, IAM, instance configuration) but have isolated API products and quotas.

**Reference:** See complete scaling strategy in `.claude/plans/phase-1a-architecture-design.md` lines 287-314

---

### Cross-Org Artifact Promotion Strategy

The two-organization architecture requires a well-defined strategy for promoting API proxies, shared flows, and configuration between the non-prod and prod Apigee organizations.

#### Promotion Workflow: dev → staging

**Challenge:** dev environment (non-prod org) and staging environment (prod org) are in different Apigee organizations, requiring export/import rather than simple environment promotion.

**Solution:** Automated CI/CD pipeline with validation gates

```
┌──────────────┐
│ dev env      │
│ (nonprod org)│
└──────┬───────┘
       │
       │ 1. Export API proxy bundle
       │ 2. Export shared flows
       │ 3. Export environment config
       │
       ▼
┌──────────────┐
│ CI/CD        │
│ Validation   │  ← Automated tests, policy checks
└──────┬───────┘
       │
       │ 4. Import to staging org
       │ 5. Deploy to staging env
       │ 6. Smoke tests
       │
       ▼
┌──────────────┐
│ staging env  │
│ (prod org)   │
└──────────────┘
```

#### Export/Import Process

**1. Export from dev environment:**
```bash
# Export API proxy from non-prod org (in pcc-dev project)
apigee-cli apis export --org pcc-dev --proxy pcc-auth-api \
  --revision latest --output /tmp/pcc-auth-api.zip

# Export shared flow
apigee-cli sharedflows export --org pcc-dev --sharedflow common-error-handling \
  --revision latest --output /tmp/common-error-handling.zip
```

**2. Validation & Testing:**
```bash
# Static analysis
apigee-lint /tmp/pcc-auth-api.zip

# Security scan
apigee-security-scan /tmp/pcc-auth-api.zip

# Regression tests (against dev environment)
newman run integration-tests.json --env dev
```

**3. Import to prod org (staging environment):**
```bash
# Import API proxy to prod org
apigee-cli apis import --org pcc-prod --proxy /tmp/pcc-auth-api.zip

# Deploy to staging environment
apigee-cli apis deploy --org pcc-prod --env staging --proxy pcc-auth-api \
  --revision latest --wait

# Import shared flow
apigee-cli sharedflows import --org pcc-prod --sharedflow /tmp/common-error-handling.zip
apigee-cli sharedflows deploy --org pcc-prod --env staging \
  --sharedflow common-error-handling --revision latest
```

**4. Post-Deployment Validation:**
```bash
# Smoke tests against staging
newman run smoke-tests.json --env staging

# Health check
curl https://api-staging.portcon.com/health
```

#### Terraform Workspace Strategy

To manage infrastructure for both organizations, use Terraform workspaces or separate state files:

**Option 1: Separate State Files (Recommended)**
```
infra/pcc-app-shared-infra/terraform/
├── nonprod/
│   ├── main.tf        # References shared modules
│   ├── devtest.tfvars
│   ├── dev.tfvars
│   └── backend.tf     # State: gs://pcc-terraform-state-dev/
└── prod/
    ├── main.tf        # References shared modules
    ├── staging.tfvars
    ├── prod.tfvars
    └── backend.tf     # State: gs://pcc-terraform-state-prod/
```

**Option 2: Terraform Workspaces**
```bash
# Initialize and create workspaces
terraform workspace new nonprod
terraform workspace new prod

# Deploy to non-prod org
terraform workspace select nonprod
terraform apply -var-file="environments/nonprod/devtest.tfvars"

# Deploy to prod org
terraform workspace select prod
terraform apply -var-file="environments/prod/staging.tfvars"
```

#### Configuration Parity Validation

Before promoting from dev to staging, ensure infrastructure parity:

**Automated Checks:**
1. **Apigee instance configuration** (regions, IP ranges) must match
2. **Environment groups** (hostnames, TLS certs) must be configured
3. **Target servers** (backend endpoints) must exist in staging
4. **KVM entries** (key-value maps) must be synchronized
5. **Product/Developer apps** must exist for integration tests

**Terraform Validation:**
```bash
# Compare non-prod and prod configurations
terraform show -json > nonprod-state.json
terraform workspace select prod
terraform show -json > prod-state.json

# Diff critical resources
jq '.values.root_module.resources[] | select(.type=="google_apigee_instance")' \
  nonprod-state.json prod-state.json
```

#### CI/CD Pipeline Integration

The cross-org promotion will be automated in Phase 2 (Cloud Build pipeline):

**Pipeline Steps:**
1. **Build:** Generate API proxy bundle from source code
2. **Test (dev):** Deploy to dev environment, run integration tests
3. **Export:** Extract validated artifacts from dev
4. **Gate:** Manual approval for promotion to staging
5. **Import:** Upload artifacts to prod org
6. **Deploy (staging):** Deploy to staging environment
7. **Validate:** Run smoke tests and health checks
8. **Notify:** Alert team of successful promotion

**Reference:** Phase 2 pipeline implementation will include cross-org promotion automation.

#### Rollback Strategy

If staging deployment fails or introduces issues:

**1. Immediate Rollback (within prod org):**
```bash
# Revert to previous proxy revision in staging
apigee-cli apis deploy --org pcc-prod --env staging \
  --proxy pcc-auth-api --revision <previous-revision>
```

**2. Hotfix from dev:**
- Apply fix in dev environment
- Re-run export/validation/import process
- Deploy patched version to staging

**3. Emergency Bypass:**
- For critical fixes, develop directly in staging (discouraged)
- Back-port changes to dev afterward
- Document in incident report

#### Trade-offs & Considerations

**Advantages of Cross-Org Promotion:**
- Infrastructure changes tested in non-prod org before prod
- Dev/staging environment differences catch configuration issues early
- Clear audit trail of what was promoted and when

**Challenges:**
- More complex than same-org promotion
- Requires export/import automation
- Configuration drift possible between orgs
- KVM/cache synchronization must be managed

**Mitigation:**
- Automated CI/CD pipeline (Phase 2)
- Infrastructure-as-code for parity (Terraform)
- Regular configuration drift detection
- Clear promotion runbooks and rollback procedures

---

## Troubleshooting

### Common Issues

#### Issue 1: Apigee Organization Creation Timeout

**Symptom:**
```
Error: timeout while waiting for state to become 'DONE'
```

**Solution:**
Apigee provisioning takes 30-45 minutes. Increase timeout in module:
```hcl
resource "google_apigee_organization" "main" {
  timeouts {
    create = "60m"
  }
}
```

---

#### Issue 2: Insufficient Permissions

**Symptom:**
```
Error: Error creating ServiceAccount: googleapi: Error 403: Permission denied
```

**Solution:**
```bash
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="user:YOUR_EMAIL" \
  --role="roles/owner"
```

---

#### Issue 3: GKE Cluster Not Found

**Symptom:**
```
Error: The resource 'projects/PROJECT/zones/ZONE/clusters/CLUSTER' was not found
```

**Solution:**
```bash
# Verify cluster exists
gcloud container clusters list

# Update variables.tf with correct cluster name/zone
```

---

#### Issue 4: Workload Identity Not Enabled

**Symptom:**
```
Error: Error setting IAM policy for service account: invalid argument
```

**Solution:**
```bash
# Check Workload Identity status
gcloud container clusters describe $CLUSTER_NAME --zone=$ZONE \
  --format="value(workloadIdentityConfig.workloadPool)"

# Enable if needed
gcloud container clusters update $CLUSTER_NAME --zone=$ZONE \
  --workload-pool=$PROJECT_ID.svc.id.goog
```

---

#### Issue 5: Terraform State Conflict

**Symptom:**
```
Error: state snapshot was created by Terraform v1.X, which is newer than current v1.Y
```

**Solution:**
```bash
# Ensure consistent Terraform version
terraform version

# Using mise
mise use terraform@1.6.0
```

**Reference:** See complete troubleshooting guide in `.claude/plans/phase-1a-gcp-preflight-checklist.md` lines 1569-1753

---

## Success Criteria

Phase 1 is complete when all criteria are met:

### Infrastructure Provisioning
- ✅ All 6 Terraform modules created in `core/pcc-tf-library/modules/`
- ✅ Infrastructure configs created in `infra/pcc-app-shared-infra/terraform/`
- ✅ `terraform apply` completes successfully with 0 errors
- ✅ Remote state stored in GCS bucket with versioning

### Resource Verification
- ✅ Apigee organization `pcc-dev` exists (runtime type: CLOUD, nonprod org)
- ✅ Apigee environment `devtest` exists
- ✅ API product `pcc-all-services-devtest` exists (quota: 1000 req/min)
- ✅ Artifact Registry repository `pcc-images` accessible
- ✅ GCS bucket `pcc-specs-devtest-pcc-dev` exists with versioning enabled
- ✅ All 3 secrets exist in Secret Manager with real values (not placeholders)
- ✅ GKE namespace `pcc-devtest` exists
- ✅ Kubernetes service account `pcc-app-sa` exists with Workload Identity annotation

### IAM & Security
- ✅ Service accounts created: `pcc-cloud-build-sa`, `pcc-apigee-runtime-sa`
- ✅ IAM bindings verified (5 roles for Cloud Build SA)
- ✅ Workload Identity binding configured correctly
- ✅ No service account key files exist
- ✅ Uniform bucket-level access enabled on GCS bucket

### Validation & Testing
- ✅ All 9 automated validation tests pass
- ✅ Manual verification commands successful
- ✅ Security audit completed (no violations)

### Documentation & Code Quality
- ✅ Terraform code follows PCC conventions (`.editorconfig`)
- ✅ `terraform fmt` passes
- ✅ `terraform validate` passes
- ✅ Terraform state committed to Git
- ✅ All outputs documented
- ✅ Troubleshooting guide complete

### Readiness for Phase 2
- ✅ Cloud Build SA can access Artifact Registry
- ✅ Cloud Build SA can access Secret Manager
- ✅ Cloud Build SA can access GCS bucket
- ✅ Cloud Build SA can manage Apigee resources
- ✅ Infrastructure outputs available for pipeline configuration

---

## Production Requirements Roadmap

**Note:** Phase 1 focuses on dev-test environment. The following requirements apply to production deployment and should be implemented in later phases:

### Monitoring & Observability

**Cloud Monitoring (Phase 2+):**
- Apigee proxy request rate, latency (p50/p95/p99), error rates
- Artifact Registry pull counts and errors
- GCS bucket access patterns
- Secret Manager access audit logs
- Alert policies for SLO violations (>5% error rate, >2s p95 latency)

**Cloud Logging (Phase 2+):**
- Centralized log sink to BigQuery for analysis
- 30-day retention for audit logs
- Export to external SIEM for compliance (if required)

**Reference:** See `.claude/docs/apigee-x-traffic-routing-specification.md` lines 1409-1430 for load balancer monitoring patterns

---

### Security & Compliance

**TLS Certificates (Phase 1b):**
- Google-managed certificates for environment group hostnames
- Automatic renewal (no manual intervention)
- Reference: `.claude/docs/apigee-x-traffic-routing-specification.md` section "TLS Certificate Management"

**DNS Configuration (Phase 1b):**
- Cloud DNS managed zones for `portcon.com`
- A records for environment group hostnames:
  - `api-devtest.portcon.com` → Load balancer IP
  - `api-dev.portcon.com` → Load balancer IP
  - `api-staging.portcon.com` → Load balancer IP
  - `api.portcon.com` → Load balancer IP (prod)
- Reference: `.claude/docs/apigee-x-traffic-routing-specification.md` section "DNS Configuration"

**Artifact Registry (Phase 2+):**
- Vulnerability scanning enabled (automatic on push)
- Binary authorization policies (require signed images for prod)
- Immutable tags for production releases

**Organization Policies (Already in pcc-foundation-infra):**
- Forbid service account key creation (`iam.disableServiceAccountKeyCreation`)
- Require OS Login (`compute.requireOsLogin`)
- Restrict public IP assignment (`compute.vmExternalIpAccess`)

**Audit Logging (Phase 2+):**
- Admin activity logs (enabled by default)
- Data access logs for Secret Manager, Artifact Registry
- Log sink to dedicated GCS bucket for compliance (7-year retention)

---

### Cost Management

**Budgets & Alerts (Phase 2+):**
- Monthly budget alerts at 50%, 80%, 100% thresholds
- Per-environment cost tracking via labels
- BigQuery for cost analysis dashboards

**Cost Optimization:**
- Apigee evaluation tier for dev-test (free)
- Artifact Registry automatic cleanup (delete images >90 days old)
- GCS lifecycle policies (delete specs >30 days old)
- Right-sized Cloud NAT (auto-allocated IPs vs reserved)

**Estimated Monthly Costs (dev-test):**
- Apigee evaluation: $0 (90-day trial)
- Artifact Registry: ~$0.10/GB storage
- Secret Manager: ~$0.06/10K access ops
- GCS: ~$0.02/GB storage
- **Total:** ~$50-100/month

**Estimated Monthly Costs (prod):**
- Apigee subscription: $2,000-10,000+ (contract required)
- Artifact Registry: ~$20/month (20GB)
- Secret Manager: ~$5/month
- GCS + Cloud NAT: ~$100/month
- Load balancer: ~$20/month
- **Total:** ~$2,150-10,150/month

---

### Disaster Recovery & Business Continuity

**Backup Strategy (Phase 2+):**
- Terraform state: GCS bucket with versioning (30 versions)
- Secret Manager: Automatic replication (us-central1 + us-east1)
- Apigee proxies: Stored in Git (source of truth)
- Artifact Registry: Multi-region replication for prod

**Runbooks (Phase 2+):**
- Secret rotation procedures (quarterly for non-production, monthly for prod)
- Failed Terraform apply recovery (state rollback)
- Apigee instance failure (multi-region failover)
- Incident response playbook

**RTO/RPO Targets (Production):**
- RTO: 4 hours (restore full Apigee service)
- RPO: 1 hour (maximum data loss for config changes)

---

### Operational Excellence

**Validation Scripts (Phase 1d):**
- Automated 9-test validation (already defined)
- Integration tests for end-to-end API flow (Phase 4)
- Chaos engineering tests (Phase 5+)

**Documentation Requirements:**
- Architecture decision records (ADRs) for major changes
- Runbook for each operational procedure
- Troubleshooting guides (already documented)
- Onboarding guide for new team members

**Deployment Automation (Phase 2):**
- Cloud Build for Terraform apply (no manual applies in prod)
- Approval gates for production changes
- Automated rollback on validation failure

---

**Summary:** Phase 1 establishes dev-test infrastructure. Production requirements will be implemented incrementally in Phases 2-8 as the system matures and traffic patterns are understood.

---

## Next Steps

After Phase 1 completion, proceed to:

**Phase 2: Cloud Build Pipeline Creation**
- Create `pcc-pipeline-library` with 5 reusable bash scripts
- Implement 9-step Cloud Build pipeline
- Create `cloudbuild.yaml` templates for each microservice
- Test end-to-end pipeline execution

**Phase 3: ArgoCD Configuration**
- Configure ArgoCD applications for 7 microservices
- Setup GitOps sync with `pcc-app-argo-config`
- Implement automated deployment triggers

**Phase 4: POC Deployment**
- Deploy first microservice (pcc-auth-api) through full pipeline
- Validate Apigee proxy creation and routing
- Test end-to-end API access

---

## References

### Source Documents
- **Architecture Design:** `.claude/plans/phase-1a-architecture-design.md` (434 lines)
- **Terraform Guide:** `.claude/plans/phase-1a-gcp-preflight-checklist.md` (1,852 lines)
- **Master Plan:** `.claude/plans/apigee-pipeline-implementation-plan.md` (1,585 lines)

### Apigee X Networking & Traffic Routing Specifications
- **Networking Specification:** `.claude/docs/apigee-x-networking-specification.md`
  - VPC peering with Service Networking API
  - Apigee instance IP range requirements (/22 + /28)
  - Cloud NAT configuration for outbound connectivity
  - Complete Terraform examples and production-ready patterns
- **Traffic Routing Specification:** `.claude/docs/apigee-x-traffic-routing-specification.md`
  - Google-managed TLS certificates with automatic renewal
  - External HTTPS Load Balancer (12-step configuration)
  - Environment group hostnames and DNS A records
  - Complete Terraform examples for production traffic management

### Related Documentation
- **Project Root:** `CLAUDE.md` (project overview)
- **AI CLI Guide:** `.claude/quick-reference/ai-cli-commands.md` (gemini integration)
- **Status Files:** `.claude/status/brief.md`, `.claude/status/current-progress.md`

### External Resources
- [Terraform Google Provider Docs](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [Apigee X Documentation](https://cloud.google.com/apigee/docs)
- [GKE Workload Identity](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity)

---

**Document Status:** Phase 1 Implementation Plan Complete
**Next Phase:** Phase 2 - Cloud Build Pipeline Creation
**Estimated Duration:** 4-6 hours (first deployment), 30 minutes (subsequent environments)
**Team:** Cloud Architecture, Deployment Engineering, DevOps
