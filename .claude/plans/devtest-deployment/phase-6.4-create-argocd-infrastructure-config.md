# Phase 6.4: Create DevOps ArgoCD Infrastructure Configuration

**Tool**: [CC] Claude Code
**Estimated Duration**: 45 minutes

## Purpose

Create Terraform configuration that calls the 3 generic modules (service-account, workload-identity, managed-certificate) to provision ArgoCD infrastructure: 6 GCP service accounts, 6 Workload Identity bindings, 3 Secret Manager secrets for OAuth credentials and admin password, IAM bindings for secret access, 1 SSL certificate, and 1 GCS bucket for Velero backups.

## Prerequisites

- Phase 6.1, 6.2, 6.3 completed (all 3 modules exist and tagged v0.1.0)
- `infra/pcc-devops-infra` repository access
- Understanding of ArgoCD components and their GCP permissions

## Directory Structure

Create:
```
infra/pcc-devops-infra/argocd-nonprod/devtest/
├── versions.tf
├── variables.tf
├── outputs.tf
├── main.tf
└── terraform.tfvars
```

## Detailed Steps

### Step 1: Create Directory

```bash
cd /home/jfogarty/pcc/infra/pcc-devops-infra
mkdir -p argocd-nonprod/devtest
cd argocd-nonprod/devtest
```

### Step 2: Create versions.tf

```hcl
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }

  backend "gcs" {
    bucket = "pcc-tf-state-devtest"
    prefix = "argocd-nonprod"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
```

### Step 3: Create variables.tf

```hcl
variable "project_id" {
  description = "GCP project ID for DevOps NonProd environment"
  type        = string
}

variable "region" {
  description = "Primary GCP region"
  type        = string
  default     = "us-east4"
}

variable "argocd_namespace" {
  description = "Kubernetes namespace for ArgoCD"
  type        = string
  default     = "argocd"
}

variable "argocd_domain" {
  description = "Domain name for ArgoCD Ingress"
  type        = string
  default     = "argocd.nonprod.pcconnect.ai"
}

variable "backup_retention_days" {
  description = "Velero backup retention in days (nonprod)"
  type        = number
  default     = 3
}
```

### Step 4: Create main.tf

```hcl
# ArgoCD Infrastructure Configuration for DevOps NonProd
# Creates: 6 SAs, 6 WI bindings, 1 SSL cert, 1 GCS bucket

# -------------------------------------------------------------------
# Service Accounts (6 total)
# -------------------------------------------------------------------

# ArgoCD Application Controller
module "argocd_controller_sa" {
  source = "git::https://github.com/ORG/pcc-tf-library.git//modules/service-account?ref=v0.1.0"

  project_id         = var.project_id
  service_account_id = "argocd-controller"
  display_name       = "ArgoCD Application Controller"
  description        = "Controller that syncs Git state to Kubernetes cluster"
}

# ArgoCD Server
module "argocd_server_sa" {
  source = "git::https://github.com/ORG/pcc-tf-library.git//modules/service-account?ref=v0.1.0"

  project_id         = var.project_id
  service_account_id = "argocd-server"
  display_name       = "ArgoCD API Server"
  description        = "API server and UI for ArgoCD"
}

# ArgoCD Dex (OIDC connector)
module "argocd_dex_sa" {
  source = "git::https://github.com/ORG/pcc-tf-library.git//modules/service-account?ref=v0.1.0"

  project_id         = var.project_id
  service_account_id = "argocd-dex"
  display_name       = "ArgoCD Dex"
  description        = "OIDC connector for Google Workspace authentication"
}

# ArgoCD Redis (state storage)
module "argocd_redis_sa" {
  source = "git::https://github.com/ORG/pcc-tf-library.git//modules/service-account?ref=v0.1.0"

  project_id         = var.project_id
  service_account_id = "argocd-redis"
  display_name       = "ArgoCD Redis"
  description        = "Redis for ArgoCD state and caching"
}

# ExternalDNS (Cloudflare DNS automation)
module "externaldns_sa" {
  source = "git::https://github.com/ORG/pcc-tf-library.git//modules/service-account?ref=v0.1.0"

  project_id         = var.project_id
  service_account_id = "externaldns"
  display_name       = "ExternalDNS"
  description        = "Watches Ingress resources and creates DNS records in Cloudflare"
}

# Velero (backup and restore)
module "velero_sa" {
  source = "git::https://github.com/ORG/pcc-tf-library.git//modules/service-account?ref=v0.1.0"

  project_id         = var.project_id
  service_account_id = "velero"
  display_name       = "Velero Backup"
  description        = "Backs up ArgoCD resources to GCS"
}

# -------------------------------------------------------------------
# Workload Identity Bindings (6 total)
# -------------------------------------------------------------------

# ArgoCD Controller WI
module "argocd_controller_wi" {
  source = "git::https://github.com/ORG/pcc-tf-library.git//modules/workload-identity?ref=v0.1.0"

  project_id                 = var.project_id
  gcp_service_account_email  = module.argocd_controller_sa.email
  namespace                  = var.argocd_namespace
  ksa_name                   = "argocd-application-controller"
}

# ArgoCD Server WI
module "argocd_server_wi" {
  source = "git::https://github.com/ORG/pcc-tf-library.git//modules/workload-identity?ref=v0.1.0"

  project_id                 = var.project_id
  gcp_service_account_email  = module.argocd_server_sa.email
  namespace                  = var.argocd_namespace
  ksa_name                   = "argocd-server"
}

# ArgoCD Dex WI
module "argocd_dex_wi" {
  source = "git::https://github.com/ORG/pcc-tf-library.git//modules/workload-identity?ref=v0.1.0"

  project_id                 = var.project_id
  gcp_service_account_email  = module.argocd_dex_sa.email
  namespace                  = var.argocd_namespace
  ksa_name                   = "argocd-dex-server"
}

# ArgoCD Redis WI
module "argocd_redis_wi" {
  source = "git::https://github.com/ORG/pcc-tf-library.git//modules/workload-identity?ref=v0.1.0"

  project_id                 = var.project_id
  gcp_service_account_email  = module.argocd_redis_sa.email
  namespace                  = var.argocd_namespace
  ksa_name                   = "argocd-redis"
}

# ExternalDNS WI
module "externaldns_wi" {
  source = "git::https://github.com/ORG/pcc-tf-library.git//modules/workload-identity?ref=v0.1.0"

  project_id                 = var.project_id
  gcp_service_account_email  = module.externaldns_sa.email
  namespace                  = var.argocd_namespace
  ksa_name                   = "external-dns"
}

# Velero WI
module "velero_wi" {
  source = "git::https://github.com/ORG/pcc-tf-library.git//modules/workload-identity?ref=v0.1.0"

  project_id                 = var.project_id
  gcp_service_account_email  = module.velero_sa.email
  namespace                  = "velero"
  ksa_name                   = "velero"
}

# -------------------------------------------------------------------
# IAM Role Bindings
# -------------------------------------------------------------------

# ArgoCD Controller - read GKE cluster info
resource "google_project_iam_member" "argocd_controller_container_viewer" {
  project = var.project_id
  role    = "roles/container.viewer"
  member  = module.argocd_controller_sa.member
}

resource "google_project_iam_member" "argocd_controller_compute_viewer" {
  project = var.project_id
  role    = "roles/compute.viewer"
  member  = module.argocd_controller_sa.member
}

# ArgoCD Server - write logs
resource "google_project_iam_member" "argocd_server_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = module.argocd_server_sa.member
}

# ExternalDNS - manage DNS records (Note: Cloudflare, not Cloud DNS)
# No GCP IAM roles needed - Cloudflare API token stored in K8s secret

# Velero - read/write backup bucket
resource "google_storage_bucket_iam_member" "velero_bucket_admin" {
  bucket = google_storage_bucket.argocd_backups.name
  role   = "roles/storage.objectAdmin"
  member = module.velero_sa.member
}

# -------------------------------------------------------------------
# GCS Bucket for Velero Backups
# -------------------------------------------------------------------

resource "google_storage_bucket" "argocd_backups" {
  name     = "pcc-argocd-backups-nonprod"
  location = var.region

  # 3-day retention for nonprod cost optimization
  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = var.backup_retention_days
    }
  }

  versioning {
    enabled = false
  }

  uniform_bucket_level_access = true

  labels = {
    environment = "nonprod"
    managed_by  = "terraform"
    purpose     = "argocd-velero-backups"
  }
}

# -------------------------------------------------------------------
# Secret Manager for OAuth Credentials
# -------------------------------------------------------------------

# OAuth Client ID Secret (value populated in Phase 6.6)
resource "google_secret_manager_secret" "argocd_oauth_client_id" {
  secret_id = "argocd-oauth-client-id"
  project   = var.project_id

  replication {
    auto {}
  }

  labels = {
    environment = "nonprod"
    managed_by  = "terraform"
    purpose     = "argocd-oidc"
  }
}

# OAuth Client Secret (value populated in Phase 6.6)
resource "google_secret_manager_secret" "argocd_oauth_client_secret" {
  secret_id = "argocd-oauth-client-secret"
  project   = var.project_id

  replication {
    auto {}
  }

  labels = {
    environment = "nonprod"
    managed_by  = "terraform"
    purpose     = "argocd-oidc"
  }
}

# Admin Password Secret (value populated in Phase 6.12)
resource "google_secret_manager_secret" "argocd_admin_password" {
  secret_id = "argocd-admin-password"
  project   = var.project_id

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }

  labels = {
    environment = "nonprod"
    managed_by  = "terraform"
    purpose     = "argocd-admin-emergency-access"
  }
}

# Grant ArgoCD Server SA permission to write admin password to Secret Manager
# Note: This is scoped to the single secret, not project-wide admin
resource "google_secret_manager_secret_iam_member" "argocd_server_admin_password_writer" {
  secret_id = google_secret_manager_secret.argocd_admin_password.id
  role      = "roles/secretmanager.secretVersionAdder"
  member    = module.argocd_server_sa.member
}

# Note: OAuth credentials are populated manually in Phase 6.6 using workstation gcloud credentials
# Dex reads OAuth credentials from K8s secret (populated in Phase 6.12), not directly from Secret Manager
# Therefore, no IAM bindings needed for Dex SA to access Secret Manager

# -------------------------------------------------------------------
# GCP-Managed SSL Certificate
# -------------------------------------------------------------------

module "argocd_cert" {
  source = "git::https://github.com/ORG/pcc-tf-library.git//modules/managed-certificate?ref=v0.1.0"

  project_id       = var.project_id
  certificate_name = "argocd-nonprod-cert"
  domains          = [var.argocd_domain]
  description      = "SSL certificate for ArgoCD NonProd Ingress"
}
```

### Step 5: Create outputs.tf

```hcl
# Service Account Emails (for Helm values annotation)
output "argocd_controller_sa_email" {
  description = "ArgoCD controller service account email"
  value       = module.argocd_controller_sa.email
}

output "argocd_server_sa_email" {
  description = "ArgoCD server service account email"
  value       = module.argocd_server_sa.email
}

output "argocd_dex_sa_email" {
  description = "ArgoCD dex service account email"
  value       = module.argocd_dex_sa.email
}

output "argocd_redis_sa_email" {
  description = "ArgoCD redis service account email"
  value       = module.argocd_redis_sa.email
}

output "externaldns_sa_email" {
  description = "ExternalDNS service account email"
  value       = module.externaldns_sa.email
}

output "velero_sa_email" {
  description = "Velero service account email"
  value       = module.velero_sa.email
}

# Backup Bucket
output "backup_bucket_name" {
  description = "GCS bucket name for Velero backups"
  value       = google_storage_bucket.argocd_backups.name
}

output "backup_bucket_url" {
  description = "GCS bucket URL"
  value       = google_storage_bucket.argocd_backups.url
}

# SSL Certificate
output "ssl_certificate_name" {
  description = "GCP-managed SSL certificate name"
  value       = module.argocd_cert.name
}

output "ssl_certificate_domains" {
  description = "Domains covered by SSL certificate"
  value       = module.argocd_cert.domains
}

# Secret Manager Resources
output "oauth_client_id_secret_name" {
  description = "Secret Manager secret name for OAuth client ID"
  value       = google_secret_manager_secret.argocd_oauth_client_id.secret_id
}

output "oauth_client_secret_secret_name" {
  description = "Secret Manager secret name for OAuth client secret"
  value       = google_secret_manager_secret.argocd_oauth_client_secret.secret_id
}

output "admin_password_secret_name" {
  description = "Secret Manager secret name for ArgoCD admin password"
  value       = google_secret_manager_secret.argocd_admin_password.secret_id
}
```

### Step 6: Create terraform.tfvars

```hcl
project_id = "pcc-prj-devops-nonprod"
region     = "us-east4"

argocd_namespace        = "argocd"
argocd_domain           = "argocd.nonprod.pcconnect.ai"
backup_retention_days   = 3
```

### Step 7: Validate Configuration

```bash
# Initialize Terraform (use -upgrade for force-pushed tags)
terraform init -upgrade

# Validate syntax
terraform validate

# Format code
terraform fmt -recursive
```

Expected output:
```
Success! The configuration is valid.
```

### Step 8: Git Workflow

```bash
# Stage all files
git add infra/pcc-devops-infra/argocd-nonprod/

# Commit
git commit -m "feat(infra): add ArgoCD infrastructure config for DevOps NonProd

Create Terraform configuration for ArgoCD deployment on GKE Autopilot.

Infrastructure created:
- 6 GCP service accounts (controller, server, dex, redis, externaldns, velero)
- 6 Workload Identity bindings for K8s SA → GCP SA auth
- IAM roles: container.viewer, compute.viewer, logging.logWriter
- Secret-scoped IAM: secretVersionAdder on admin password secret only
- 3 Secret Manager secrets (OAuth client ID/secret, admin password)
- GCS bucket for Velero backups (3-day retention)
- GCP-managed SSL certificate for argocd.nonprod.pcconnect.ai

Uses generic modules from pcc-tf-library v0.1.0.

"

# Push to remote
git push origin main
```

## Success Criteria

- ✅ All 5 Terraform files created with correct syntax
- ✅ `terraform validate` passes
- ✅ Configuration references all 3 generic modules with v0.1.0 tag
- ✅ 6 service accounts + 6 WI bindings configured
- ✅ IAM roles match requirements (scoped Secret Manager access for argocd-server)
- ✅ 3 Secret Manager secrets configured (OAuth credentials + admin password)
- ✅ ArgoCD Server SA granted secretVersionAdder on admin password secret only
- ✅ GCS bucket has 3-day lifecycle policy
- ✅ SSL certificate targets correct domain
- ✅ Git commit follows conventional format
- ✅ Code pushed to remote repository

## HALT Conditions

**HALT if**:
- Terraform validate fails
- Module references are missing v0.1.0 tag
- Git repository is not accessible
- Backend GCS bucket does not exist

**Resolution**: Fix validation errors, verify module tags, check Git access, or create state bucket.

## Next Phase

Proceed to **Phase 6.5**: Create Helm Values Configuration

## Notes

- **CRITICAL**: This configuration does NOT deploy infrastructure yet (Phase 6.7 does that)
- **Secret Manager secrets created empty**: Values populated manually in Phase 6.6 (OAuth) and Phase 6.12 (admin password)
- **IAM Least Privilege**: ArgoCD server SA has `secretmanager.secretVersionAdder` on admin password secret ONLY (not project-wide admin)
- **No Dex Secret Manager Access**: Dex reads OAuth credentials from K8s secret, not directly from Secret Manager
- **OAuth Population**: Phase 6.6 and 6.12 use workstation gcloud credentials (not Workload Identity) to populate secrets
- ExternalDNS does NOT need GCP DNS roles (uses Cloudflare API token instead)
- Velero SA has `storage.objectAdmin` on backup bucket (not project-wide)
- terraform init -upgrade is REQUIRED because v0.1.0 tags may be force-pushed
- Service account emails will be used in Phase 6.5 Helm values (referenced by name, not output)
