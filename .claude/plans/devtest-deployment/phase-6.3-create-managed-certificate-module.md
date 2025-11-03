# Phase 6.3: Create Managed Certificate Module

**Tool**: [CC] Claude Code
**Estimated Duration**: 15 minutes

## Purpose

Create a generic, reusable Terraform module for GCP-managed SSL certificates. These certificates are automatically provisioned and renewed by Google Cloud, used for HTTPS Ingress termination.

## Prerequisites

- Phase 6.1 and 6.2 completed (service-account and workload-identity modules exist)
- Understanding of GCP-managed SSL certificates
- Git configured for commits

## Module Structure

Create the following directory structure:
```
core/pcc-tf-library/modules/managed-certificate/
├── versions.tf
├── variables.tf
├── outputs.tf
└── main.tf
```

## Detailed Steps

### Step 1: Create Module Directory

```bash
cd /home/jfogarty/pcc/core/pcc-tf-library/modules
mkdir -p managed-certificate
cd managed-certificate
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
  description = "GCP project ID where the certificate will be created"
  type        = string
}

variable "certificate_name" {
  description = "Name of the managed SSL certificate resource"
  type        = string

  validation {
    condition     = can(regex("^[a-z][-a-z0-9]*$", var.certificate_name))
    error_message = "Certificate name must start with lowercase letter, contain only lowercase letters, numbers, and hyphens."
  }
}

variable "domains" {
  description = "List of domain names to include in the certificate (max 100)"
  type        = list(string)

  validation {
    condition     = length(var.domains) > 0 && length(var.domains) <= 100
    error_message = "Must specify between 1 and 100 domains."
  }

  validation {
    condition     = alltrue([for d in var.domains : can(regex("^[a-z0-9][-a-z0-9.]*[a-z0-9]$", d))])
    error_message = "Domains must be valid DNS names (lowercase alphanumeric, hyphens, and dots)."
  }
}

variable "description" {
  description = "Optional description of the certificate"
  type        = string
  default     = "Managed by Terraform"
}
```

### Step 4: Create outputs.tf

```hcl
output "id" {
  description = "The ID of the managed SSL certificate"
  value       = google_compute_managed_ssl_certificate.cert.id
}

output "name" {
  description = "The name of the managed SSL certificate"
  value       = google_compute_managed_ssl_certificate.cert.name
}

output "certificate_id" {
  description = "The unique numeric ID of the certificate"
  value       = google_compute_managed_ssl_certificate.cert.certificate_id
}

output "domains" {
  description = "The list of domains covered by this certificate"
  value       = google_compute_managed_ssl_certificate.cert.managed[0].domains
}

output "domain_status" {
  description = "Status of each domain's certificate provisioning"
  value       = google_compute_managed_ssl_certificate.cert.managed[0].domain_status
}

output "self_link" {
  description = "The self-link of the certificate for use in Ingress annotations"
  value       = google_compute_managed_ssl_certificate.cert.self_link
}
```

### Step 5: Create main.tf

```hcl
# Generic GCP Managed SSL Certificate Module
# Automatically provisioned and renewed by Google Cloud

resource "google_compute_managed_ssl_certificate" "cert" {
  project     = var.project_id
  name        = var.certificate_name
  description = var.description

  managed {
    domains = var.domains
  }

  lifecycle {
    create_before_destroy = true
  }
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
git add core/pcc-tf-library/modules/managed-certificate/

# Commit with conventional commit message
git commit -m "feat(terraform): add generic managed-certificate module

Add reusable Terraform module for GCP-managed SSL certificates.
Certificates are automatically provisioned and renewed by Google Cloud
for use with HTTPS Ingress.

Module features:
- Input validation for certificate name and domain formats
- Support for up to 100 domains per certificate
- Domain status output for monitoring provisioning
- Self-link output for Ingress annotations
- Create-before-destroy lifecycle for zero-downtime updates

"

# Push to remote
git push origin main
```

## Success Criteria

- ✅ All 4 module files created with correct syntax
- ✅ `terraform validate` passes
- ✅ Module follows Terraform best practices (inputs validated, outputs documented)
- ✅ Module is generic and reusable (supports any domain names)
- ✅ Git commit follows conventional commit format
- ✅ Code pushed to remote repository

## HALT Conditions

**HALT if**:
- Terraform validate fails with syntax errors
- Git repository is not accessible
- managed-certificate module directory already exists with different content

**Resolution**: Fix validation errors, verify Git access, or review existing module for compatibility.

## Next Phase

Proceed to **Phase 6.4**: Create DevOps ArgoCD Infrastructure Configuration

## Notes

- GCP-managed certificates are **automatically provisioned** after Ingress is created
- DNS must point to the Ingress IP **before** certificate provisioning completes
- Provisioning can take 15-60 minutes after DNS propagation
- Certificates are **automatically renewed** before expiration
- Maximum 100 domains per certificate (GCP limit)
- Use `domain_status` output to monitor provisioning progress
- Certificate provisioning flow:
  1. Terraform creates certificate resource (PROVISIONING state)
  2. Ingress references certificate via annotation
  3. DNS A record points to Ingress IP
  4. Google Cloud validates domain ownership via HTTP challenge
  5. Certificate transitions to ACTIVE state
- If provisioning fails, check:
  - DNS A record points to correct Ingress IP
  - Domain is publicly accessible on port 80
  - No firewall blocking port 80
