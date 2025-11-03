# Phase 1.1: Create Service Account Module

**Phase**: 1.1 (VPN Infrastructure - Generic Module)
**Duration**: 15-20 minutes
**Type**: Implementation
**Tool**: Claude Code (CC)
**Status**: Ready for Execution

---

## Objective

Create reusable Service Account module in `pcc-tf-library` for creating GCP service accounts with IAM role bindings. Module is generic and not specific to WireGuard VPN.

## Prerequisites

✅ `pcc-tf-library` repository available
✅ Understanding of GCP service accounts and IAM roles

---

## Module Structure

**Location**: `pcc-tf-library/modules/service-account/`

**Files to Create**:
1. `versions.tf` - Provider requirements
2. `variables.tf` - Input parameters
3. `outputs.tf` - Exported values
4. `main.tf` - Service account and IAM binding resources

---

## Step 1: Create versions.tf

**File**: `pcc-tf-library/modules/service-account/versions.tf`

```hcl
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}
```

---

## Step 2: Create variables.tf

**File**: `pcc-tf-library/modules/service-account/variables.tf`

```hcl
variable "project_id" {
  description = "GCP project ID where service account will be created"
  type        = string
}

variable "account_id" {
  description = "Unique identifier for the service account (lowercase, max 30 chars)"
  type        = string

  validation {
    condition     = can(regex("^[a-z]([-a-z0-9]{4,28}[a-z0-9])$", var.account_id))
    error_message = "Account ID must be lowercase alphanumeric with hyphens, 6-30 chars, start with letter"
  }
}

variable "display_name" {
  description = "Human-readable display name for the service account"
  type        = string
}

variable "description" {
  description = "Description of the service account's purpose"
  type        = string
  default     = ""
}

variable "project_roles" {
  description = "List of IAM roles to grant at project level (e.g., roles/compute.viewer)"
  type        = list(string)
  default     = []
}

variable "disabled" {
  description = "Whether the service account is disabled"
  type        = bool
  default     = false
}
```

---

## Step 3: Create outputs.tf

**File**: `pcc-tf-library/modules/service-account/outputs.tf`

```hcl
output "email" {
  description = "Email address of the service account"
  value       = google_service_account.sa.email
}

output "name" {
  description = "Fully-qualified name of the service account"
  value       = google_service_account.sa.name
}

output "account_id" {
  description = "The account id (short name) of the service account"
  value       = google_service_account.sa.account_id
}

output "unique_id" {
  description = "Unique numeric ID of the service account"
  value       = google_service_account.sa.unique_id
}

output "member" {
  description = "IAM member string for use in IAM bindings"
  value       = "serviceAccount:${google_service_account.sa.email}"
}
```

---

## Step 4: Create main.tf

**File**: `pcc-tf-library/modules/service-account/main.tf`

```hcl
# Service Account resource
resource "google_service_account" "sa" {
  project      = var.project_id
  account_id   = var.account_id
  display_name = var.display_name
  description  = var.description
  disabled     = var.disabled
}

# Project-level IAM role bindings
resource "google_project_iam_member" "project_roles" {
  for_each = toset(var.project_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.sa.email}"

  depends_on = [google_service_account.sa]
}
```

---

## Validation Checklist

- [ ] Directory created: `pcc-tf-library/modules/service-account/`
- [ ] `versions.tf` created with provider ~> 5.0
- [ ] `variables.tf` created with 6 input variables
- [ ] `outputs.tf` created with 5 outputs
- [ ] `main.tf` created with service account + IAM binding resources
- [ ] Account ID validation enforces GCP naming rules
- [ ] Project roles are optional (default empty list)
- [ ] No syntax errors

---

## Module Interface

**Required Inputs**:
- `project_id` - Where to create service account
- `account_id` - Unique identifier (6-30 chars, lowercase)
- `display_name` - Human-readable name

**Optional Inputs**:
- `description` - Purpose documentation
- `project_roles` - List of IAM roles to grant
- `disabled` - Disable the account (default: false)

**Outputs**:
- `email` - For IAM bindings and workload identity
- `name` - Full resource name
- `account_id` - Short name
- `unique_id` - Numeric ID
- `member` - Formatted IAM member string

---

## Usage Example

```hcl
module "wireguard_sa" {
  source = "../../modules/service-account"

  project_id   = "pcc-prj-devops-nonprod"
  account_id   = "wireguard-vpn-sa"
  display_name = "WireGuard VPN Service Account"
  description  = "Service account for WireGuard VPN MIG instances"

  project_roles = [
    "roles/secretmanager.secretAccessor",
    "roles/compute.instanceAdmin.v1",
    "roles/logging.logWriter"
  ]
}
```

---

## Design Considerations

### IAM Scope
- Module only handles **project-level** IAM roles
- For resource-specific IAM (e.g., secret-level), handle in calling config
- Uses `for_each` to create individual bindings (not `google_project_iam_binding`)

### Validation
- Account ID regex enforces GCP requirements:
  - 6-30 characters
  - Lowercase letters, numbers, hyphens
  - Must start with letter, end with letter or number

### Simplicity
- No support for keys (use Workload Identity instead)
- No support for custom IAM conditions
- Focus on common use case: SA + project roles

---

## Next Phase Dependencies

**Phase 1.2-1.7** will create other infrastructure modules (mig, load-balancer, etc.)

**Phase 2.1** will compose this module in `wireguard-vpn.tf` to create the VPN service account

---

## Time Estimate

- **Create directory**: 1 minute
- **Create versions.tf**: 2 minutes
- **Create variables.tf**: 5-6 minutes (6 variables with validation)
- **Create outputs.tf**: 3-4 minutes (5 outputs)
- **Create main.tf**: 4-5 minutes (SA + IAM bindings)
- **Review/validate**: 2-3 minutes
- **Total**: 15-20 minutes

---

**Status**: Ready for execution by CC
**Next**: Phase 1.2 - Create MIG Module
