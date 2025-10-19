# Phase 1a: Terraform Infrastructure Provisioning Guide
## Apigee Pipeline Implementation - GCP Infrastructure as Code

**Document Version:** 2.0 (Terraform-First Rewrite)
**Phase:** 1a (Infrastructure Provisioning)
**Source:** deployment-engineer subagent
**Date:** 2025-10-16

---

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Terraform Module Development](#terraform-module-development)
4. [Infrastructure Configuration](#infrastructure-configuration)
5. [Deployment Workflow](#deployment-workflow)
6. [Post-Deployment Validation](#post-deployment-validation)
7. [Troubleshooting Guide](#troubleshooting-guide)
8. [Appendix: Manual Fallback Commands](#appendix-manual-fallback-commands)

---

## Overview

This guide provides a **Terraform-first approach** to provisioning all GCP infrastructure required for Phase 1 of the Apigee pipeline implementation. All resources are managed as Infrastructure as Code (IaC), ensuring repeatability, version control, and GitOps best practices.

**CRITICAL MANDATE**: All infrastructure MUST be provisioned via Terraform. Manual gcloud/kubectl commands are ONLY for post-deployment verification.

### Infrastructure to Provision

**Core Resources:**
- Apigee X organization and devtest environment
- Artifact Registry repository for Docker images
- Secret Manager secrets (git-token, argocd-password, apigee-access-token)
- GCS bucket for OpenAPI specs
- Service accounts with IAM bindings
- GKE namespace and Workload Identity bindings

**Architecture Pattern:**
```
Terraform Modules (core/pcc-tf-library/modules/)
    ↓
Infrastructure Configs (infra/pcc-app-shared-infra/terraform/)
    ↓
GCP Resources (Apigee, GCS, IAM, Secret Manager, Artifact Registry)
    ↓
Validation (gcloud/kubectl read-only commands)
```

**Estimated Time:** 4-6 hours (first-time setup), 30 minutes (subsequent applies)

---

## Prerequisites

### Required Tools

Verify all required tools are installed:

```bash
# Terraform version
terraform version
# Required: Terraform v1.6.0 or later

# GCP CLI
gcloud version
# Required: Google Cloud SDK 450.0.0 or later

# Kubernetes CLI
kubectl version --client
# Required: Client Version v1.28.0 or later

# jq for JSON processing
jq --version
# Required: jq-1.6 or later

# mise for tool management (optional)
mise --version
```

### GCP Authentication

Authenticate with GCP and configure default project:

```bash
# Authenticate with GCP
gcloud auth login

# Set default project
export PROJECT_ID="pcc-portcon-prod"
gcloud config set project $PROJECT_ID

# Verify authentication
gcloud auth list
# Expected: Active account shown

# Application Default Credentials (for Terraform)
gcloud auth application-default login
```

### GCP Permissions Required

Your GCP user or service account needs these IAM roles:

- `roles/owner` OR the following granular roles:
  - `roles/apigee.admin`
  - `roles/iam.serviceAccountAdmin`
  - `roles/iam.securityAdmin`
  - `roles/storage.admin`
  - `roles/artifactregistry.admin`
  - `roles/secretmanager.admin`
  - `roles/serviceusage.serviceUsageAdmin`
  - `roles/compute.networkAdmin`

### Environment Variables

Set required environment variables:

```bash
export PROJECT_ID="pcc-portcon-prod"
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")
export REGION="us-central1"
export ZONE="us-central1-a"
export ENVIRONMENT="devtest"
export CLUSTER_NAME="pcc-cluster"

# Verify variables
echo "Project ID: $PROJECT_ID"
echo "Project Number: $PROJECT_NUMBER"
echo "Region: $REGION"
echo "Environment: $ENVIRONMENT"
```

---

## Terraform Module Development

All Terraform modules are stored in `core/pcc-tf-library/modules/`. This section provides complete module definitions.

### Module 1: Apigee IAM

**Location:** `@core/pcc-tf-library/modules/apigee-iam/`

#### `main.tf`

```hcl
# core/pcc-tf-library/modules/apigee-iam/main.tf

# Cloud Build Service Account
resource "google_service_account" "cloud_build" {
  project      = var.project_id
  account_id   = var.cloud_build_sa_name
  display_name = "PCC Cloud Build Pipeline Service Account"
  description  = "Orchestrates CI/CD pipeline: Docker build, Apigee deployment, ArgoCD sync"
}

# Grant Apigee admin role to Cloud Build SA
resource "google_project_iam_member" "cloud_build_apigee_admin" {
  project = var.project_id
  role    = "roles/apigee.admin"
  member  = "serviceAccount:${google_service_account.cloud_build.email}"
}

# Grant container developer role to Cloud Build SA
resource "google_project_iam_member" "cloud_build_container_developer" {
  project = var.project_id
  role    = "roles/container.developer"
  member  = "serviceAccount:${google_service_account.cloud_build.email}"
}

# Grant secret accessor role to Cloud Build SA
resource "google_project_iam_member" "cloud_build_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.cloud_build.email}"
}

# Grant storage admin role to Cloud Build SA
resource "google_project_iam_member" "cloud_build_storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.cloud_build.email}"
}

# Grant logging writer role to Cloud Build SA
resource "google_project_iam_member" "cloud_build_logging_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.cloud_build.email}"
}

# Apigee Runtime Service Account (for microservices)
resource "google_service_account" "apigee_runtime" {
  project      = var.project_id
  account_id   = var.apigee_runtime_sa_name
  display_name = "Apigee Runtime Service Account"
  description  = "Service account for Apigee proxy runtime operations"
}

# Grant runtime agent role to Apigee Runtime SA
resource "google_project_iam_member" "apigee_runtime_agent" {
  project = var.project_id
  role    = "roles/apigee.runtimeAgent"
  member  = "serviceAccount:${google_service_account.apigee_runtime.email}"
}
```

#### `variables.tf`

```hcl
# core/pcc-tf-library/modules/apigee-iam/variables.tf

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "cloud_build_sa_name" {
  description = "Name for Cloud Build service account"
  type        = string
  default     = "pcc-cloud-build-sa"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{5,28}[a-z0-9]$", var.cloud_build_sa_name))
    error_message = "Service account name must be 6-30 characters, lowercase letters, numbers, and hyphens."
  }
}

variable "apigee_runtime_sa_name" {
  description = "Name for Apigee runtime service account"
  type        = string
  default     = "pcc-apigee-runtime-sa"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{5,28}[a-z0-9]$", var.apigee_runtime_sa_name))
    error_message = "Service account name must be 6-30 characters, lowercase letters, numbers, and hyphens."
  }
}
```

#### `outputs.tf`

```hcl
# core/pcc-tf-library/modules/apigee-iam/outputs.tf

output "cloud_build_sa_email" {
  description = "Email address of the Cloud Build service account"
  value       = google_service_account.cloud_build.email
}

output "cloud_build_sa_id" {
  description = "Unique ID of the Cloud Build service account"
  value       = google_service_account.cloud_build.unique_id
}

output "apigee_runtime_sa_email" {
  description = "Email address of the Apigee runtime service account"
  value       = google_service_account.apigee_runtime.email
}

output "apigee_runtime_sa_id" {
  description = "Unique ID of the Apigee runtime service account"
  value       = google_service_account.apigee_runtime.unique_id
}
```

---

### Module 2: Artifact Registry

**Location:** `@core/pcc-tf-library/modules/artifact-registry/`

#### `main.tf`

```hcl
# core/pcc-tf-library/modules/artifact-registry/main.tf

# Enable Artifact Registry API
resource "google_project_service" "artifact_registry" {
  project = var.project_id
  service = "artifactregistry.googleapis.com"

  disable_on_destroy = false
}

# Create Docker repository
resource "google_artifact_registry_repository" "main" {
  project       = var.project_id
  location      = var.location
  repository_id = var.repository_id
  description   = var.description
  format        = "DOCKER"

  docker_config {
    immutable_tags = var.immutable_tags
  }

  depends_on = [google_project_service.artifact_registry]
}

# Grant Cloud Build SA write access to repository
resource "google_artifact_registry_repository_iam_member" "cloud_build_writer" {
  project    = var.project_id
  location   = google_artifact_registry_repository.main.location
  repository = google_artifact_registry_repository.main.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${var.cloud_build_sa_email}"
}
```

#### `variables.tf`

```hcl
# core/pcc-tf-library/modules/artifact-registry/variables.tf

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "location" {
  description = "Location for the Artifact Registry repository"
  type        = string
}

variable "repository_id" {
  description = "ID of the Artifact Registry repository"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,62}[a-z0-9]$", var.repository_id))
    error_message = "Repository ID must be 1-63 characters, lowercase letters, numbers, and hyphens."
  }
}

variable "description" {
  description = "Description of the repository"
  type        = string
  default     = "Docker repository for PCC microservices"
}

variable "immutable_tags" {
  description = "Whether tags are immutable"
  type        = bool
  default     = false
}

variable "cloud_build_sa_email" {
  description = "Email of Cloud Build service account for IAM binding"
  type        = string
}
```

#### `outputs.tf`

```hcl
# core/pcc-tf-library/modules/artifact-registry/outputs.tf

output "repository_id" {
  description = "ID of the Artifact Registry repository"
  value       = google_artifact_registry_repository.main.repository_id
}

output "repository_location" {
  description = "Location of the Artifact Registry repository"
  value       = google_artifact_registry_repository.main.location
}

output "repository_url" {
  description = "URL of the Artifact Registry repository"
  value       = "${google_artifact_registry_repository.main.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.main.repository_id}"
}
```

---

### Module 3: Secret Manager

**Location:** `@core/pcc-tf-library/modules/secret-manager/`

#### `main.tf`

```hcl
# core/pcc-tf-library/modules/secret-manager/main.tf

# Enable Secret Manager API
resource "google_project_service" "secret_manager" {
  project = var.project_id
  service = "secretmanager.googleapis.com"

  disable_on_destroy = false
}

# Create secrets
resource "google_secret_manager_secret" "secrets" {
  for_each = var.secrets

  project   = var.project_id
  secret_id = each.key

  replication {
    auto {}
  }

  labels = merge(
    {
      environment = var.environment
      managed_by  = "terraform"
    },
    each.value.labels
  )

  depends_on = [google_project_service.secret_manager]
}

# Add initial secret versions with placeholder values
resource "google_secret_manager_secret_version" "initial" {
  for_each = var.secrets

  secret      = google_secret_manager_secret.secrets[each.key].id
  secret_data = each.value.placeholder_value

  lifecycle {
    ignore_changes = [secret_data]
  }
}

# Grant accessor role to Cloud Build SA
resource "google_secret_manager_secret_iam_member" "cloud_build_accessor" {
  for_each = var.secrets

  project   = var.project_id
  secret_id = google_secret_manager_secret.secrets[each.key].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.cloud_build_sa_email}"
}
```

#### `variables.tf`

```hcl
# core/pcc-tf-library/modules/secret-manager/variables.tf

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "secrets" {
  description = "Map of secrets to create with placeholder values"
  type = map(object({
    placeholder_value = string
    labels            = map(string)
  }))

  default = {}
}

variable "cloud_build_sa_email" {
  description = "Email of Cloud Build service account for IAM binding"
  type        = string
}
```

#### `outputs.tf`

```hcl
# core/pcc-tf-library/modules/secret-manager/outputs.tf

output "secret_ids" {
  description = "Map of secret names to their IDs"
  value       = { for k, v in google_secret_manager_secret.secrets : k => v.secret_id }
}

output "secret_versions" {
  description = "Map of secret names to their latest version resource names"
  value       = { for k, v in google_secret_manager_secret_version.initial : k => v.name }
}
```

---

### Module 4: GCS Bucket

**Location:** `@core/pcc-tf-library/modules/gcs-bucket/`

#### `main.tf`

```hcl
# core/pcc-tf-library/modules/gcs-bucket/main.tf

# Enable Storage API
resource "google_project_service" "storage" {
  project = var.project_id
  service = "storage.googleapis.com"

  disable_on_destroy = false
}

# Create GCS bucket
resource "google_storage_bucket" "main" {
  project  = var.project_id
  name     = var.bucket_name
  location = var.location

  uniform_bucket_level_access = true
  force_destroy               = var.force_destroy

  versioning {
    enabled = var.versioning_enabled
  }

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age                   = var.lifecycle_age_days
      with_state            = "ARCHIVED"
      matches_storage_class = []
    }
  }

  labels = {
    environment = var.environment
    managed_by  = "terraform"
    purpose     = "openapi-specs"
  }

  depends_on = [google_project_service.storage]
}

# Grant Cloud Build SA admin access to bucket
resource "google_storage_bucket_iam_member" "cloud_build_admin" {
  bucket = google_storage_bucket.main.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${var.cloud_build_sa_email}"
}
```

#### `variables.tf`

```hcl
# core/pcc-tf-library/modules/gcs-bucket/variables.tf

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "bucket_name" {
  description = "Name of the GCS bucket (must be globally unique)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-_]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "Bucket name must be 3-63 characters, lowercase letters, numbers, hyphens, and underscores."
  }
}

variable "location" {
  description = "Location for the GCS bucket"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "versioning_enabled" {
  description = "Enable versioning for the bucket"
  type        = bool
  default     = true
}

variable "lifecycle_age_days" {
  description = "Age in days for lifecycle deletion policy"
  type        = number
  default     = 30
}

variable "force_destroy" {
  description = "Allow bucket deletion even if not empty"
  type        = bool
  default     = false
}

variable "cloud_build_sa_email" {
  description = "Email of Cloud Build service account for IAM binding"
  type        = string
}
```

#### `outputs.tf`

```hcl
# core/pcc-tf-library/modules/gcs-bucket/outputs.tf

output "bucket_name" {
  description = "Name of the GCS bucket"
  value       = google_storage_bucket.main.name
}

output "bucket_url" {
  description = "URL of the GCS bucket"
  value       = google_storage_bucket.main.url
}

output "bucket_self_link" {
  description = "Self link of the GCS bucket"
  value       = google_storage_bucket.main.self_link
}
```

---

### Module 5: Apigee Resources

**Location:** `@core/pcc-tf-library/modules/apigee-resources/`

#### `main.tf`

```hcl
# core/pcc-tf-library/modules/apigee-resources/main.tf

# Enable Apigee API
resource "google_project_service" "apigee" {
  project = var.project_id
  service = "apigee.googleapis.com"

  disable_on_destroy = false
}

# Create Apigee Organization
resource "google_apigee_organization" "main" {
  project_id       = var.project_id
  analytics_region = var.analytics_region
  runtime_type     = "CLOUD"

  # Authorized network must be configured separately
  # authorized_network = var.authorized_network

  depends_on = [google_project_service.apigee]
}

# Create Apigee Environment
resource "google_apigee_environment" "main" {
  org_id       = google_apigee_organization.main.id
  name         = var.environment
  display_name = "${var.environment} Environment"
  description  = "Apigee environment for ${var.environment}"
}

# Create Apigee API Product
resource "google_apigee_product" "main" {
  name         = var.api_product_name
  display_name = var.api_product_display_name
  description  = var.api_product_description

  approval_type = var.environment == "devtest" ? "auto" : "manual"

  # Quota configuration
  quota          = var.quota_limit
  quota_interval = var.quota_interval
  quota_time_unit = var.quota_time_unit

  # Scopes for API access control
  scopes = var.api_scopes

  environments = [
    google_apigee_environment.main.name
  ]

  org_id = google_apigee_organization.main.id
}
```

#### `variables.tf`

```hcl
# core/pcc-tf-library/modules/apigee-resources/variables.tf

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "analytics_region" {
  description = "Region for Apigee analytics"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Environment name (devtest, dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["devtest", "dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: devtest, dev, staging, prod."
  }
}

variable "api_product_name" {
  description = "Name of the API product"
  type        = string
}

variable "api_product_display_name" {
  description = "Display name of the API product"
  type        = string
}

variable "api_product_description" {
  description = "Description of the API product"
  type        = string
  default     = "PCC microservices API product"
}

variable "quota_limit" {
  description = "API quota limit"
  type        = string
  default     = "1000"
}

variable "quota_interval" {
  description = "API quota interval"
  type        = string
  default     = "1"
}

variable "quota_time_unit" {
  description = "API quota time unit (minute, hour, day)"
  type        = string
  default     = "minute"
}

variable "api_scopes" {
  description = "List of API scopes"
  type        = list(string)
  default     = []
}
```

#### `outputs.tf`

```hcl
# core/pcc-tf-library/modules/apigee-resources/outputs.tf

output "apigee_org_id" {
  description = "ID of the Apigee organization"
  value       = google_apigee_organization.main.id
}

output "apigee_org_name" {
  description = "Name of the Apigee organization"
  value       = google_apigee_organization.main.name
}

output "apigee_environment_name" {
  description = "Name of the Apigee environment"
  value       = google_apigee_environment.main.name
}

output "api_product_name" {
  description = "Name of the API product"
  value       = google_apigee_product.main.name
}

output "api_product_id" {
  description = "ID of the API product"
  value       = google_apigee_product.main.id
}
```

---

### Module 6: Kubernetes Resources

**Location:** `@core/pcc-tf-library/modules/k8s-namespace/`

#### `main.tf`

```hcl
# core/pcc-tf-library/modules/k8s-namespace/main.tf

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.20.0"
    }
  }
}

# Create namespace
resource "kubernetes_namespace" "main" {
  metadata {
    name = var.namespace_name

    labels = {
      environment = var.environment
      managed_by  = "terraform"
    }
  }
}

# Create service account in namespace
resource "kubernetes_service_account" "main" {
  metadata {
    name      = var.service_account_name
    namespace = kubernetes_namespace.main.metadata[0].name

    annotations = var.workload_identity_enabled ? {
      "iam.gke.io/gcp-service-account" = var.gcp_service_account_email
    } : {}
  }
}

# Workload Identity binding
resource "google_service_account_iam_member" "workload_identity" {
  count = var.workload_identity_enabled ? 1 : 0

  service_account_id = var.gcp_service_account_id
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${kubernetes_namespace.main.metadata[0].name}/${kubernetes_service_account.main.metadata[0].name}]"
}
```

#### `variables.tf`

```hcl
# core/pcc-tf-library/modules/k8s-namespace/variables.tf

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "namespace_name" {
  description = "Name of the Kubernetes namespace"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{0,61}[a-z0-9]$", var.namespace_name))
    error_message = "Namespace name must be valid DNS label (lowercase, alphanumeric, hyphens)."
  }
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "service_account_name" {
  description = "Name of the Kubernetes service account"
  type        = string
  default     = "pcc-app-sa"
}

variable "workload_identity_enabled" {
  description = "Enable Workload Identity binding"
  type        = bool
  default     = true
}

variable "gcp_service_account_email" {
  description = "Email of GCP service account for Workload Identity"
  type        = string
  default     = ""
}

variable "gcp_service_account_id" {
  description = "ID of GCP service account for Workload Identity"
  type        = string
  default     = ""
}
```

#### `outputs.tf`

```hcl
# core/pcc-tf-library/modules/k8s-namespace/outputs.tf

output "namespace_name" {
  description = "Name of the Kubernetes namespace"
  value       = kubernetes_namespace.main.metadata[0].name
}

output "service_account_name" {
  description = "Name of the Kubernetes service account"
  value       = kubernetes_service_account.main.metadata[0].name
}
```

---

## Infrastructure Configuration

All infrastructure configurations are stored in `infra/pcc-app-shared-infra/terraform/`. This section shows how to use the modules.

### Directory Structure

```
infra/pcc-app-shared-infra/terraform/
├── main.tf
├── variables.tf
├── outputs.tf
├── versions.tf
├── terraform.tfvars
└── environments/
    ├── devtest.tfvars
    ├── dev.tfvars
    ├── staging.tfvars
    └── prod.tfvars
```

### `versions.tf`

```hcl
# infra/pcc-app-shared-infra/terraform/versions.tf

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.20.0"
    }
  }

  # Backend configuration for remote state
  backend "gcs" {
    bucket = "pcc-terraform-state-prod"
    prefix = "shared-infra/terraform.tfstate"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Configure Kubernetes provider to use GKE cluster
data "google_container_cluster" "main" {
  name     = var.cluster_name
  location = var.zone
}

provider "kubernetes" {
  host  = "https://${data.google_container_cluster.main.endpoint}"
  token = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(
    data.google_container_cluster.main.master_auth[0].cluster_ca_certificate
  )
}

data "google_client_config" "default" {}
```

### `main.tf`

```hcl
# infra/pcc-app-shared-infra/terraform/main.tf

# Enable required GCP APIs
resource "google_project_service" "required_apis" {
  for_each = toset([
    "apigee.googleapis.com",
    "container.googleapis.com",
    "cloudbuild.googleapis.com",
    "artifactregistry.googleapis.com",
    "secretmanager.googleapis.com",
    "storage.googleapis.com",
  ])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

# Module: Apigee IAM
module "apigee_iam" {
  source = "../../../core/pcc-tf-library/modules/apigee-iam"

  project_id              = var.project_id
  cloud_build_sa_name     = "pcc-cloud-build-sa"
  apigee_runtime_sa_name  = "pcc-apigee-runtime-sa"

  depends_on = [google_project_service.required_apis]
}

# Module: Artifact Registry
module "artifact_registry" {
  source = "../../../core/pcc-tf-library/modules/artifact-registry"

  project_id            = var.project_id
  location              = var.region
  repository_id         = "pcc-images"
  description           = "Docker images for PCC microservices"
  immutable_tags        = false
  cloud_build_sa_email  = module.apigee_iam.cloud_build_sa_email

  depends_on = [google_project_service.required_apis]
}

# Module: Secret Manager
module "secret_manager" {
  source = "../../../core/pcc-tf-library/modules/secret-manager"

  project_id            = var.project_id
  environment           = var.environment
  cloud_build_sa_email  = module.apigee_iam.cloud_build_sa_email

  secrets = {
    git-token = {
      placeholder_value = "PLACEHOLDER_GITHUB_TOKEN"
      labels = {
        purpose = "github-access"
      }
    }
    argocd-password = {
      placeholder_value = "PLACEHOLDER_ARGOCD_PASSWORD"
      labels = {
        purpose = "argocd-auth"
      }
    }
    apigee-access-token = {
      placeholder_value = "PLACEHOLDER_APIGEE_TOKEN"
      labels = {
        purpose = "apigee-api"
      }
    }
  }

  depends_on = [google_project_service.required_apis]
}

# Module: GCS Bucket
module "gcs_bucket" {
  source = "../../../core/pcc-tf-library/modules/gcs-bucket"

  project_id            = var.project_id
  bucket_name           = "pcc-specs-${var.environment}-${var.project_id}"
  location              = var.region
  environment           = var.environment
  versioning_enabled    = true
  lifecycle_age_days    = 30
  force_destroy         = var.environment == "devtest"
  cloud_build_sa_email  = module.apigee_iam.cloud_build_sa_email

  depends_on = [google_project_service.required_apis]
}

# Module: Apigee Resources
module "apigee_resources" {
  source = "../../../core/pcc-tf-library/modules/apigee-resources"

  project_id                 = var.project_id
  analytics_region           = var.region
  environment                = var.environment
  api_product_name           = "pcc-all-services-${var.environment}"
  api_product_display_name   = "PCC All Services - ${title(var.environment)}"
  api_product_description    = "API product for all PCC microservices in ${var.environment}"
  quota_limit                = var.api_quota_limit
  quota_interval             = "1"
  quota_time_unit            = "minute"
  api_scopes                 = var.api_scopes

  depends_on = [google_project_service.required_apis]
}

# Module: Kubernetes Namespace
module "k8s_namespace" {
  source = "../../../core/pcc-tf-library/modules/k8s-namespace"

  project_id                = var.project_id
  namespace_name            = "pcc-${var.environment}"
  environment               = var.environment
  service_account_name      = "pcc-app-sa"
  workload_identity_enabled = true
  gcp_service_account_email = module.apigee_iam.apigee_runtime_sa_email
  gcp_service_account_id    = module.apigee_iam.apigee_runtime_sa_id
}
```

### `variables.tf`

```hcl
# infra/pcc-app-shared-infra/terraform/variables.tf

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for resources"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone for GKE cluster"
  type        = string
  default     = "us-central1-a"
}

variable "environment" {
  description = "Environment name (devtest, dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["devtest", "dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: devtest, dev, staging, prod."
  }
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
  default     = "pcc-cluster"
}

variable "api_quota_limit" {
  description = "API quota limit per minute"
  type        = string
  default     = "1000"
}

variable "api_scopes" {
  description = "List of API scopes for the API product"
  type        = list(string)
  default = [
    "auth.read",
    "auth.write",
    "user.read",
    "user.write",
    "client.read",
    "client.write",
  ]
}
```

### `outputs.tf`

```hcl
# infra/pcc-app-shared-infra/terraform/outputs.tf

output "cloud_build_sa_email" {
  description = "Email of Cloud Build service account"
  value       = module.apigee_iam.cloud_build_sa_email
}

output "artifact_registry_url" {
  description = "URL of Artifact Registry repository"
  value       = module.artifact_registry.repository_url
}

output "gcs_bucket_name" {
  description = "Name of GCS bucket for OpenAPI specs"
  value       = module.gcs_bucket.bucket_name
}

output "apigee_org_id" {
  description = "ID of Apigee organization"
  value       = module.apigee_resources.apigee_org_id
}

output "apigee_environment" {
  description = "Name of Apigee environment"
  value       = module.apigee_resources.apigee_environment_name
}

output "api_product_name" {
  description = "Name of API product"
  value       = module.apigee_resources.api_product_name
}

output "k8s_namespace" {
  description = "Name of Kubernetes namespace"
  value       = module.k8s_namespace.namespace_name
}

output "secret_ids" {
  description = "Map of secret names to IDs"
  value       = module.secret_manager.secret_ids
}
```

### `environments/devtest.tfvars`

```hcl
# infra/pcc-app-shared-infra/terraform/environments/devtest.tfvars

project_id      = "pcc-portcon-prod"
region          = "us-central1"
zone            = "us-central1-a"
environment     = "devtest"
cluster_name    = "pcc-cluster"
api_quota_limit = "1000"

api_scopes = [
  "auth.read",
  "auth.write",
  "user.read",
  "user.write",
  "client.read",
  "client.write",
  "metric.read",
  "metric.write",
  "task.read",
  "task.write",
]
```

---

## Deployment Workflow

### Step 1: Initialize Terraform Backend

Create GCS bucket for Terraform state (one-time setup):

```bash
# Create state bucket (manual step, only if not exists)
gsutil mb -p $PROJECT_ID -c STANDARD -l $REGION gs://pcc-terraform-state-prod

# Enable versioning on state bucket
gsutil versioning set on gs://pcc-terraform-state-prod
```

### Step 2: Navigate to Infrastructure Directory

```bash
cd $HOME/pcc/pcc-project/infra/pcc-app-shared-infra/terraform
```

### Step 3: Initialize Terraform

```bash
terraform init
```

**Expected Output:**
```
Initializing modules...
Initializing the backend...
Initializing provider plugins...
- Reusing previous version of hashicorp/google from the dependency lock file
- Reusing previous version of hashicorp/kubernetes from the dependency lock file

Terraform has been successfully initialized!
```

### Step 4: Validate Configuration

```bash
terraform validate
```

**Expected Output:**
```
Success! The configuration is valid.
```

### Step 5: Format Code

```bash
terraform fmt -recursive
```

### Step 6: Plan Infrastructure Changes

```bash
terraform plan -var-file="environments/devtest.tfvars" -out=tfplan
```

**Expected Output:**
```
Plan: 25 to add, 0 to change, 0 to destroy.
```

**Review the plan carefully** before proceeding. Ensure:
- Correct project ID and region
- Service accounts being created
- IAM bindings are correct
- No unexpected deletions

### Step 7: Apply Infrastructure

```bash
terraform apply tfplan
```

**Expected Output:**
```
Apply complete! Resources: 25 added, 0 changed, 0 destroyed.

Outputs:

cloud_build_sa_email = "pcc-cloud-build-sa@pcc-portcon-prod.iam.gserviceaccount.com"
artifact_registry_url = "us-central1-docker.pkg.dev/pcc-portcon-prod/pcc-images"
gcs_bucket_name = "pcc-specs-devtest-pcc-portcon-prod"
apigee_org_id = "organizations/pcc-portcon-prod"
apigee_environment = "devtest"
api_product_name = "pcc-all-services-devtest"
k8s_namespace = "pcc-devtest"
```

**Deployment Time:** Approximately 15-30 minutes (Apigee organization provisioning is slow)

### Step 8: Update Secret Values

After infrastructure is provisioned, update secret values with real credentials:

```bash
# Update git-token
echo -n "ghp_REAL_GITHUB_TOKEN" | gcloud secrets versions add git-token --data-file=-

# Update argocd-password
echo -n "REAL_ARGOCD_PASSWORD" | gcloud secrets versions add argocd-password --data-file=-

# Update apigee-access-token
echo -n "REAL_APIGEE_TOKEN" | gcloud secrets versions add apigee-access-token --data-file=-
```

### Step 9: Commit Terraform State

```bash
# Commit terraform.lock.hcl and any updated .tf files
git add .terraform.lock.hcl *.tf environments/*.tfvars
git commit -m "feat: provision Phase 1a GCP infrastructure via Terraform"
git push
```

---

## Post-Deployment Validation

After Terraform apply completes, verify all resources using read-only gcloud/kubectl commands.

### Validation Script

Create `/tmp/validate-terraform-deployment.sh`:

```bash
#!/bin/bash
set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

PROJECT_ID=${PROJECT_ID:-"pcc-portcon-prod"}
ENVIRONMENT=${ENVIRONMENT:-"devtest"}
REGION=${REGION:-"us-central1"}

echo "========================================="
echo "Terraform Deployment Validation"
echo "Project: $PROJECT_ID"
echo "Environment: $ENVIRONMENT"
echo "========================================="
echo ""

PASS_COUNT=0
FAIL_COUNT=0

# Test 1: Verify Apigee organization
echo -n "Test 1: Apigee organization exists... "
if gcloud apigee organizations describe $PROJECT_ID &>/dev/null; then
  echo -e "${GREEN}PASS${NC}"
  ((PASS_COUNT++))
else
  echo -e "${RED}FAIL${NC}"
  ((FAIL_COUNT++))
fi

# Test 2: Verify Apigee environment
echo -n "Test 2: Apigee environment '${ENVIRONMENT}' exists... "
if gcloud apigee environments describe $ENVIRONMENT --organization=$PROJECT_ID &>/dev/null; then
  echo -e "${GREEN}PASS${NC}"
  ((PASS_COUNT++))
else
  echo -e "${RED}FAIL${NC}"
  ((FAIL_COUNT++))
fi

# Test 3: Verify Artifact Registry
echo -n "Test 3: Artifact Registry 'pcc-images' exists... "
if gcloud artifacts repositories describe pcc-images --location=$REGION &>/dev/null; then
  echo -e "${GREEN}PASS${NC}"
  ((PASS_COUNT++))
else
  echo -e "${RED}FAIL${NC}"
  ((FAIL_COUNT++))
fi

# Test 4: Verify GCS bucket
echo -n "Test 4: GCS bucket 'pcc-specs-${ENVIRONMENT}-${PROJECT_ID}' exists... "
if gsutil ls gs://pcc-specs-${ENVIRONMENT}-${PROJECT_ID} &>/dev/null; then
  echo -e "${GREEN}PASS${NC}"
  ((PASS_COUNT++))
else
  echo -e "${RED}FAIL${NC}"
  ((FAIL_COUNT++))
fi

# Test 5: Verify Cloud Build service account
echo -n "Test 5: Cloud Build SA 'pcc-cloud-build-sa' exists... "
if gcloud iam service-accounts describe pcc-cloud-build-sa@${PROJECT_ID}.iam.gserviceaccount.com &>/dev/null; then
  echo -e "${GREEN}PASS${NC}"
  ((PASS_COUNT++))
else
  echo -e "${RED}FAIL${NC}"
  ((FAIL_COUNT++))
fi

# Test 6: Verify secrets
echo -n "Test 6: Secret Manager secrets exist... "
SECRETS_COUNT=$(gcloud secrets list --filter="name:git-token OR name:argocd-password OR name:apigee-access-token" --format="value(name)" | wc -l)
if [ "$SECRETS_COUNT" -eq 3 ]; then
  echo -e "${GREEN}PASS${NC} (3/3 secrets)"
  ((PASS_COUNT++))
else
  echo -e "${RED}FAIL${NC} ($SECRETS_COUNT/3 secrets)"
  ((FAIL_COUNT++))
fi

# Test 7: Verify GKE namespace
echo -n "Test 7: GKE namespace 'pcc-${ENVIRONMENT}' exists... "
if kubectl get namespace pcc-${ENVIRONMENT} &>/dev/null; then
  echo -e "${GREEN}PASS${NC}"
  ((PASS_COUNT++))
else
  echo -e "${RED}FAIL${NC}"
  ((FAIL_COUNT++))
fi

# Test 8: Verify Kubernetes service account
echo -n "Test 8: K8s service account 'pcc-app-sa' exists... "
if kubectl get serviceaccount pcc-app-sa -n pcc-${ENVIRONMENT} &>/dev/null; then
  echo -e "${GREEN}PASS${NC}"
  ((PASS_COUNT++))
else
  echo -e "${RED}FAIL${NC}"
  ((FAIL_COUNT++))
fi

# Test 9: Verify Workload Identity annotation
echo -n "Test 9: Workload Identity annotation configured... "
WI_ANNOTATION=$(kubectl get sa pcc-app-sa -n pcc-${ENVIRONMENT} -o jsonpath='{.metadata.annotations.iam\.gke\.io/gcp-service-account}')
if [ ! -z "$WI_ANNOTATION" ]; then
  echo -e "${GREEN}PASS${NC}"
  ((PASS_COUNT++))
else
  echo -e "${RED}FAIL${NC}"
  ((FAIL_COUNT++))
fi

echo ""
echo "========================================="
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed"
echo "========================================="

if [ $FAIL_COUNT -eq 0 ]; then
  echo -e "${GREEN}✓ Terraform deployment validation PASSED${NC}"
  exit 0
else
  echo -e "${RED}✗ Terraform deployment validation FAILED${NC}"
  exit 1
fi
```

Make script executable and run:

```bash
chmod +x /tmp/validate-terraform-deployment.sh
/tmp/validate-terraform-deployment.sh
```

### Manual Validation Commands

#### Verify Apigee Organization

```bash
gcloud apigee organizations describe $PROJECT_ID
```

**Expected:** Organization details with `runtimeType: CLOUD`

#### Verify Artifact Registry

```bash
gcloud artifacts repositories describe pcc-images --location=$REGION
```

**Expected:** Repository format: DOCKER

#### Verify Secret Manager

```bash
gcloud secrets list --filter="labels.environment=$ENVIRONMENT"
```

**Expected:** 3 secrets (git-token, argocd-password, apigee-access-token)

#### Verify GCS Bucket

```bash
gsutil ls -L gs://pcc-specs-${ENVIRONMENT}-${PROJECT_ID}
```

**Expected:** Bucket with uniform bucket-level access enabled

#### Verify Service Accounts

```bash
gcloud iam service-accounts list --filter="email:pcc-*"
```

**Expected:** pcc-cloud-build-sa and pcc-apigee-runtime-sa

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

#### Verify Kubernetes Resources

```bash
# Namespace
kubectl get namespace pcc-${ENVIRONMENT}

# Service account
kubectl get sa pcc-app-sa -n pcc-${ENVIRONMENT}

# Workload Identity annotation
kubectl get sa pcc-app-sa -n pcc-${ENVIRONMENT} -o yaml | grep iam.gke.io
```

**Expected:** Annotation pointing to pcc-apigee-runtime-sa@PROJECT_ID.iam.gserviceaccount.com

---

## Troubleshooting Guide

### Issue 1: Terraform Backend Initialization Fails

**Symptom:**
```
Error: Failed to get existing workspaces: querying Cloud Storage failed: storage: bucket doesn't exist
```

**Solution:**
Create the GCS bucket for Terraform state:
```bash
gsutil mb -p $PROJECT_ID -c STANDARD -l $REGION gs://pcc-terraform-state-prod
gsutil versioning set on gs://pcc-terraform-state-prod
```

---

### Issue 2: Apigee Organization Creation Timeout

**Symptom:**
```
Error: timeout while waiting for state to become 'DONE'
```

**Solution:**
Apigee organization provisioning can take 30-45 minutes. Increase Terraform timeout:
```hcl
resource "google_apigee_organization" "main" {
  # ... other config

  timeouts {
    create = "60m"
    update = "60m"
    delete = "60m"
  }
}
```

---

### Issue 3: Insufficient Permissions

**Symptom:**
```
Error: Error creating ServiceAccount: googleapi: Error 403: Permission iam.serviceAccounts.create denied
```

**Solution:**
Ensure your GCP user has required roles:
```bash
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="user:YOUR_EMAIL" \
  --role="roles/owner"
```

Or grant granular roles listed in Prerequisites section.

---

### Issue 4: GKE Cluster Not Found

**Symptom:**
```
Error: googleapi: Error 404: The resource 'projects/PROJECT/zones/ZONE/clusters/CLUSTER' was not found
```

**Solution:**
Verify GKE cluster exists and update `cluster_name` and `zone` variables:
```bash
gcloud container clusters list
```

---

### Issue 5: Kubernetes Provider Authentication Fails

**Symptom:**
```
Error: Failed to configure kubernetes provider: invalid configuration: no configuration has been provided
```

**Solution:**
Get GKE credentials before running Terraform:
```bash
gcloud container clusters get-credentials $CLUSTER_NAME --zone=$ZONE
```

---

### Issue 6: Secret Manager Secret Already Exists

**Symptom:**
```
Error: Error creating Secret: googleapi: Error 409: Secret [secret-name] already exists
```

**Solution:**
Import existing secret into Terraform state:
```bash
terraform import 'module.secret_manager.google_secret_manager_secret.secrets["git-token"]' projects/$PROJECT_ID/secrets/git-token
```

---

### Issue 7: GCS Bucket Name Conflict

**Symptom:**
```
Error: googleapi: Error 409: You already own this bucket
```

**Solution:**
Bucket names are globally unique. Import existing bucket or choose different name:
```bash
terraform import module.gcs_bucket.google_storage_bucket.main pcc-specs-devtest-$PROJECT_ID
```

---

### Issue 8: Workload Identity Binding Fails

**Symptom:**
```
Error: Error setting IAM policy for service account: googleapi: Error 400: Request contains an invalid argument
```

**Solution:**
Verify Workload Identity is enabled on GKE cluster:
```bash
gcloud container clusters describe $CLUSTER_NAME --zone=$ZONE \
  --format="value(workloadIdentityConfig.workloadPool)"
```

Expected: `PROJECT_ID.svc.id.goog`

If not enabled:
```bash
gcloud container clusters update $CLUSTER_NAME --zone=$ZONE \
  --workload-pool=$PROJECT_ID.svc.id.goog
```

---

### Issue 9: Module Source Path Errors

**Symptom:**
```
Error: Module not found: module "apigee_iam" (at main.tf:X) cannot be found
```

**Solution:**
Verify module paths are correct relative to working directory:
```bash
cd $HOME/pcc/pcc-project/infra/pcc-app-shared-infra/terraform
ls -la ../../../core/pcc-tf-library/modules/
```

Update source paths in `main.tf` if structure differs.

---

### Issue 10: Terraform State Corruption

**Symptom:**
```
Error: state snapshot was created by Terraform v1.X, which is newer than current v1.Y
```

**Solution:**
Ensure consistent Terraform version across team:
```bash
# Using mise
mise use terraform@1.6.0

# Or update Terraform
terraform version
```

If state is corrupted, restore from GCS bucket versioning:
```bash
gsutil ls -a gs://pcc-terraform-state-prod/shared-infra/
gsutil cp gs://pcc-terraform-state-prod/shared-infra/terraform.tfstate#VERSION ./terraform.tfstate
```

---

## Appendix: Manual Fallback Commands

**Use ONLY if Terraform fails completely and manual intervention is required.**

### Enable APIs Manually

```bash
gcloud services enable \
  apigee.googleapis.com \
  container.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com \
  secretmanager.googleapis.com \
  storage.googleapis.com \
  --project=$PROJECT_ID
```

### Create Service Account Manually

```bash
gcloud iam service-accounts create pcc-cloud-build-sa \
  --display-name="PCC Cloud Build SA" \
  --project=$PROJECT_ID

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:pcc-cloud-build-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/apigee.admin"
```

### Create Artifact Registry Manually

```bash
gcloud artifacts repositories create pcc-images \
  --repository-format=docker \
  --location=$REGION \
  --project=$PROJECT_ID
```

### Create Secret Manager Secret Manually

```bash
echo -n "PLACEHOLDER" | gcloud secrets create git-token \
  --data-file=- \
  --replication-policy="automatic" \
  --project=$PROJECT_ID
```

### Create GCS Bucket Manually

```bash
gsutil mb -p $PROJECT_ID -c STANDARD -l $REGION \
  gs://pcc-specs-${ENVIRONMENT}-${PROJECT_ID}

gsutil uniformbucketlevelaccess set on \
  gs://pcc-specs-${ENVIRONMENT}-${PROJECT_ID}
```

### Create GKE Namespace Manually

```bash
kubectl create namespace pcc-${ENVIRONMENT}
kubectl label namespace pcc-${ENVIRONMENT} environment=${ENVIRONMENT} managed-by=manual
kubectl create serviceaccount pcc-app-sa -n pcc-${ENVIRONMENT}
```

**IMPORTANT:** After using manual commands, import resources into Terraform state:
```bash
terraform import <resource_address> <resource_id>
```

---

## Phase 1a Completion Criteria

Phase 1a is complete when:

- ✅ All Terraform modules created in `core/pcc-tf-library/modules/`
- ✅ Infrastructure configs created in `infra/pcc-app-shared-infra/terraform/`
- ✅ `terraform apply` completes successfully with 0 errors
- ✅ All validation tests pass (9/9)
- ✅ Apigee organization and devtest environment exist
- ✅ Artifact Registry repository accessible
- ✅ All 3 secrets exist in Secret Manager (with real values)
- ✅ GCS bucket accessible with uniform bucket-level access
- ✅ Service accounts created with correct IAM bindings
- ✅ GKE namespace exists with Workload Identity configured
- ✅ Terraform state committed to Git
- ✅ Documentation updated with infrastructure outputs

**Next Step:** Proceed to Phase 1b (Cloud Build pipeline creation and testing)

---

**Document Status:** Terraform Infrastructure Provisioning Guide Complete
**Ready For:** Phase 1b Implementation
**Reviewed By:** Deployment Engineering Team
