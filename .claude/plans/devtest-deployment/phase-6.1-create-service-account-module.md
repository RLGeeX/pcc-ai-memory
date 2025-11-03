# Phase 6.1: Create Service Account Module

**Tool**: [CC] Claude Code
**Estimated Duration**: 20 minutes

## Purpose

Create a generic, reusable Terraform module for GCP service account creation. This module will be used across multiple applications (ArgoCD, Velero, ExternalDNS, etc.) to maintain DRY principles and simplify infrastructure management.

## Prerequisites

- Access to `core/pcc-tf-library` repository
- Understanding of Terraform module structure
- Git configured for commits

## Module Structure

Create the following directory structure:
```
core/pcc-tf-library/modules/service-account/
├── versions.tf
├── variables.tf
├── outputs.tf
└── main.tf
```

## Detailed Steps

### Step 1: Create Module Directory

```bash
cd /home/jfogarty/pcc/core/pcc-tf-library/modules
mkdir -p service-account
cd service-account
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
  description = "GCP project ID where the service account will be created"
  type        = string
}

variable "service_account_id" {
  description = "The service account ID (the part before @PROJECT.iam.gserviceaccount.com)"
  type        = string

  validation {
    condition     = can(regex("^[a-z][-a-z0-9]{5,29}$", var.service_account_id))
    error_message = "Service account ID must be 6-30 chars, start with lowercase letter, contain only lowercase letters, numbers, and hyphens."
  }
}

variable "display_name" {
  description = "Human-readable display name for the service account"
  type        = string
}

variable "description" {
  description = "Optional description of the service account's purpose"
  type        = string
  default     = ""
}
```

### Step 4: Create outputs.tf

```hcl
output "email" {
  description = "The email address of the service account (format: SA_ID@PROJECT.iam.gserviceaccount.com)"
  value       = google_service_account.sa.email
}

output "name" {
  description = "The fully-qualified name of the service account"
  value       = google_service_account.sa.name
}

output "unique_id" {
  description = "The unique numeric ID of the service account"
  value       = google_service_account.sa.unique_id
}

output "member" {
  description = "The IAM member format for use in IAM bindings (format: serviceAccount:EMAIL)"
  value       = "serviceAccount:${google_service_account.sa.email}"
}
```

### Step 5: Create main.tf

```hcl
# Generic GCP Service Account Module
# Used across multiple applications: ArgoCD, Velero, ExternalDNS, etc.

resource "google_service_account" "sa" {
  project      = var.project_id
  account_id   = var.service_account_id
  display_name = var.display_name
  description  = var.description != "" ? var.description : "Managed by Terraform"
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
git add core/pcc-tf-library/modules/service-account/

# Commit with conventional commit message
git commit -m "feat(terraform): add generic service-account module

Add reusable Terraform module for GCP service account creation.
This module will be used across ArgoCD, Velero, and ExternalDNS
deployments to maintain DRY principles.

Module features:
- Input validation for service account ID format
- Standard outputs (email, name, unique_id, member)
- Optional description field
- Terraform 1.6+ and Google provider 6.x compatible

"

# Push to remote
git push origin main
```

## Success Criteria

- ✅ All 4 module files created with correct syntax
- ✅ `terraform validate` passes
- ✅ Module follows Terraform best practices (inputs validated, outputs documented)
- ✅ Module is generic and reusable (no hardcoded ArgoCD-specific values)
- ✅ Git commit follows conventional commit format
- ✅ Code pushed to remote repository

## HALT Conditions

**HALT if**:
- Terraform validate fails with syntax errors
- Git repository is not accessible
- service-account module directory already exists with different content

**Resolution**: Fix validation errors, verify Git access, or review existing module for compatibility.

## Next Phase

Proceed to **Phase 6.2**: Create Workload Identity Module

## Notes

- This module is intentionally generic - it does NOT create IAM role bindings
- IAM roles will be assigned in the consuming Terraform configuration (Phase 6.4)
- The `member` output is a convenience for IAM binding syntax
- Module supports GCP projects only (not folders/organizations)
