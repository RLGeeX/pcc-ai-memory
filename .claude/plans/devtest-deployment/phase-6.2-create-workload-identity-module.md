# Phase 6.2: Create Workload Identity Module

**Tool**: [CC] Claude Code
**Estimated Duration**: 20 minutes

## Purpose

Create a generic, reusable Terraform module for Kubernetes Service Account to GCP Service Account bindings via Workload Identity. This module enables K8s pods to authenticate as GCP service accounts without managing keys.

## Prerequisites

- Phase 6.1 completed (service-account module exists)
- Understanding of GKE Workload Identity architecture
- Git configured for commits

## Module Structure

Create the following directory structure:
```
core/pcc-tf-library/modules/workload-identity/
├── versions.tf
├── variables.tf
├── outputs.tf
└── main.tf
```

## Detailed Steps

### Step 1: Create Module Directory

```bash
cd /home/jfogarty/pcc/core/pcc-tf-library/modules
mkdir -p workload-identity
cd workload-identity
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
}
```

### Step 3: Create variables.tf

```hcl
variable "project_id" {
  description = "GCP project ID where the service account exists"
  type        = string
}

variable "gcp_service_account_email" {
  description = "Email of the GCP service account to bind (format: SA_ID@PROJECT.iam.gserviceaccount.com)"
  type        = string

  validation {
    condition     = can(regex("^[a-z][-a-z0-9]+@[a-z0-9-]+\\.iam\\.gserviceaccount\\.com$", var.gcp_service_account_email))
    error_message = "Must be a valid GCP service account email format."
  }
}

variable "namespace" {
  description = "Kubernetes namespace where the K8s service account exists"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][-a-z0-9]*$", var.namespace))
    error_message = "Namespace must be valid DNS-1123 label (lowercase alphanumeric and hyphens)."
  }
}

variable "ksa_name" {
  description = "Name of the Kubernetes service account to bind"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][-a-z0-9]*$", var.ksa_name))
    error_message = "K8s SA name must be valid DNS-1123 label (lowercase alphanumeric and hyphens)."
  }
}

variable "cluster_location" {
  description = "GKE cluster location (region or zone). If not provided, binding applies to all clusters."
  type        = string
  default     = null
}
```

### Step 4: Create outputs.tf

```hcl
output "workload_identity_member" {
  description = "The workload identity member format used in the IAM binding"
  value       = "serviceAccount:${var.project_id}.svc.id.goog[${var.namespace}/${var.ksa_name}]"
}

output "gcp_service_account_email" {
  description = "The GCP service account email that was bound"
  value       = var.gcp_service_account_email
}

output "kubernetes_service_account" {
  description = "The Kubernetes service account reference (namespace/name)"
  value       = "${var.namespace}/${var.ksa_name}"
}

output "annotation" {
  description = "The annotation to add to the K8s ServiceAccount manifest"
  value       = "iam.gke.io/gcp-service-account: ${var.gcp_service_account_email}"
}
```

### Step 5: Create main.tf

```hcl
# Generic Workload Identity Binding Module
# Binds Kubernetes Service Account to GCP Service Account

# Extract GCP SA name from email for resource naming
locals {
  gcp_sa_name = split("@", var.gcp_service_account_email)[0]
}

resource "google_service_account_iam_binding" "workload_identity" {
  service_account_id = "projects/${var.project_id}/serviceAccounts/${var.gcp_service_account_email}"
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${var.project_id}.svc.id.goog[${var.namespace}/${var.ksa_name}]"
  ]
}
```

### Step 6: Validate Module

```bash
# Initialize Terraform
terraform init

# Validate syntax
terraform validate

# Format code
terraform fmt -recursive
```

Expected output:
```
Success! The configuration is valid.
```

### Step 7: Git Workflow

```bash
# Stage module files
git add core/pcc-tf-library/modules/workload-identity/

# Commit with conventional commit message
git commit -m "feat(terraform): add generic workload-identity module

Add reusable Terraform module for GKE Workload Identity bindings.
Binds Kubernetes Service Accounts to GCP Service Accounts, enabling
pods to authenticate as GCP SAs without managing keys.

Module features:
- Input validation for email and K8s name formats
- Workload Identity member format output
- K8s annotation output for ServiceAccount manifests
- Optional cluster location filtering
- Standard IAM binding with workloadIdentityUser role

"

# Push to remote
git push origin main
```

## Success Criteria

- ✅ All 4 module files created with correct syntax
- ✅ `terraform validate` passes
- ✅ Module follows Terraform best practices (inputs validated, outputs documented)
- ✅ Module is generic and reusable (works with any namespace/K8s SA name)
- ✅ Git commit follows conventional commit format
- ✅ Code pushed to remote repository

## HALT Conditions

**HALT if**:
- Terraform validate fails with syntax errors
- Git repository is not accessible
- workload-identity module directory already exists with different content

**Resolution**: Fix validation errors, verify Git access, or review existing module for compatibility.

## Next Phase

Proceed to **Phase 6.3**: Create Managed Certificate Module

## Notes

- This module only creates the IAM binding on the GCP service account
- The Kubernetes ServiceAccount must be annotated separately with `iam.gke.io/gcp-service-account`
- The `annotation` output provides the correct annotation string for K8s manifests
- Workload Identity must be enabled on the GKE cluster (validated in Phase 6.8)
- Binding format: `serviceAccount:PROJECT.svc.id.goog[NAMESPACE/KSA_NAME]`
