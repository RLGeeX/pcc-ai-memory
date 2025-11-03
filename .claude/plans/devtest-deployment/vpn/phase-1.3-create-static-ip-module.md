# Phase 1.3: Create Static IP Module

**Phase**: 1.3 (VPN Infrastructure - Generic Module)
**Duration**: 15-20 minutes
**Type**: Implementation
**Tool**: Claude Code (CC)
**Status**: Ready for Execution

---

## Objective

Create reusable Static IP module in `pcc-tf-library` for reserving external and internal IP addresses. Module is generic and not specific to WireGuard VPN.

## Prerequisites

✅ `pcc-tf-library` repository available
✅ Understanding of GCP address types (EXTERNAL vs INTERNAL)

---

## Module Structure

**Location**: `pcc-tf-library/modules/static-ip/`

**Files to Create**:
1. `versions.tf` - Provider requirements
2. `variables.tf` - Input parameters
3. `outputs.tf` - Exported values
4. `main.tf` - Compute address resource

---

## Step 1: Create versions.tf

**File**: `pcc-tf-library/modules/static-ip/versions.tf`

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

**File**: `pcc-tf-library/modules/static-ip/variables.tf`

```hcl
variable "project_id" {
  description = "GCP project ID where IP address will be created"
  type        = string
}

variable "name" {
  description = "Name of the IP address resource"
  type        = string

  validation {
    condition     = can(regex("^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$", var.name))
    error_message = "Name must be lowercase, alphanumeric with hyphens, max 63 chars"
  }
}

variable "description" {
  description = "Description of the IP address's purpose"
  type        = string
  default     = ""
}

variable "region" {
  description = "GCP region for regional IP address (e.g., us-east4). Required for regional addresses."
  type        = string
  default     = null
}

variable "address_type" {
  description = "Type of address: EXTERNAL or INTERNAL"
  type        = string
  default     = "EXTERNAL"

  validation {
    condition     = contains(["EXTERNAL", "INTERNAL"], var.address_type)
    error_message = "Address type must be EXTERNAL or INTERNAL"
  }
}

variable "ip_version" {
  description = "IP version: IPV4 or IPV6"
  type        = string
  default     = "IPV4"

  validation {
    condition     = contains(["IPV4", "IPV6"], var.ip_version)
    error_message = "IP version must be IPV4 or IPV6"
  }
}

variable "network_tier" {
  description = "Network tier for EXTERNAL addresses: PREMIUM or STANDARD"
  type        = string
  default     = "PREMIUM"

  validation {
    condition     = contains(["PREMIUM", "STANDARD"], var.network_tier)
    error_message = "Network tier must be PREMIUM or STANDARD"
  }
}

variable "purpose" {
  description = "Purpose for INTERNAL addresses (GCE_ENDPOINT, VPC_PEERING, SHARED_LOADBALANCER_VIP, etc.)"
  type        = string
  default     = null
}

variable "subnetwork" {
  description = "Self-link to subnetwork for INTERNAL addresses. Required for INTERNAL address_type."
  type        = string
  default     = null
}

variable "address" {
  description = "Static IP address value. If not specified, an available address is automatically chosen."
  type        = string
  default     = null
}

variable "prefix_length" {
  description = "Prefix length for IP address (only for specific purpose types)"
  type        = number
  default     = null
}

variable "labels" {
  description = "Labels to apply to the IP address"
  type        = map(string)
  default     = {}
}
```

---

## Step 3: Create outputs.tf

**File**: `pcc-tf-library/modules/static-ip/outputs.tf`

```hcl
output "id" {
  description = "Identifier of the address"
  value       = google_compute_address.ip.id
}

output "self_link" {
  description = "Self-link of the address"
  value       = google_compute_address.ip.self_link
}

output "address" {
  description = "The static IP address value"
  value       = google_compute_address.ip.address
}

output "name" {
  description = "Name of the IP address resource"
  value       = google_compute_address.ip.name
}

output "region" {
  description = "Region of the IP address (null for global)"
  value       = google_compute_address.ip.region
}

output "address_type" {
  description = "Type of address (EXTERNAL or INTERNAL)"
  value       = google_compute_address.ip.address_type
}
```

---

## Step 4: Create main.tf

**File**: `pcc-tf-library/modules/static-ip/main.tf`

```hcl
# Static IP Address
resource "google_compute_address" "ip" {
  project      = var.project_id
  name         = var.name
  description  = var.description
  region       = var.region
  address_type = var.address_type
  ip_version   = var.ip_version

  # Network tier (only for EXTERNAL addresses)
  network_tier = var.address_type == "EXTERNAL" ? var.network_tier : null

  # Purpose and subnetwork (only for INTERNAL addresses)
  purpose    = var.address_type == "INTERNAL" ? var.purpose : null
  subnetwork = var.address_type == "INTERNAL" ? var.subnetwork : null

  # Optional: Specific IP address
  address = var.address

  # Optional: Prefix length
  prefix_length = var.prefix_length

  labels = merge(
    var.labels,
    {
      managed_by = "terraform"
    }
  )
}
```

---

## Validation Checklist

- [ ] Directory created: `pcc-tf-library/modules/static-ip/`
- [ ] `versions.tf` created with provider ~> 5.0
- [ ] `variables.tf` created with 12 input variables
- [ ] `outputs.tf` created with 6 outputs
- [ ] `main.tf` created with compute address resource
- [ ] EXTERNAL vs INTERNAL logic handled correctly
- [ ] Network tier only applied to EXTERNAL addresses
- [ ] No syntax errors

---

## Module Interface

**Required Inputs**:
- `project_id` - Where to create IP address
- `name` - Resource identifier

**Optional Inputs**:
- `description` - Purpose documentation
- `region` - For regional addresses (required for regional)
- `address_type` - EXTERNAL (default) or INTERNAL
- `ip_version` - IPV4 (default) or IPV6
- `network_tier` - PREMIUM (default) or STANDARD (EXTERNAL only)
- `purpose` - Purpose type (INTERNAL only)
- `subnetwork` - Subnet self-link (INTERNAL, required)
- `address` - Specific IP value (optional)
- `prefix_length` - IP prefix length
- `labels` - For organization

**Outputs**:
- `id` - Address identifier
- `self_link` - For resource references
- `address` - The actual IP address value
- `name` - Resource name
- `region` - Deployment region
- `address_type` - EXTERNAL or INTERNAL

---

## Usage Examples

### Example 1: External IP for Load Balancer

```hcl
module "wireguard_external_ip" {
  source = "../../modules/static-ip"

  project_id   = "pcc-prj-devops-nonprod"
  name         = "wireguard-vpn-external-ip"
  description  = "Static external IP for WireGuard VPN load balancer"
  region       = "us-east4"
  address_type = "EXTERNAL"
  network_tier = "STANDARD"  # Lower cost for VPN

  labels = {
    purpose     = "wireguard-vpn"
    environment = "nonprod"
  }
}
```

### Example 2: Internal IP for PSC Endpoint

```hcl
module "alloydb_psc_ip" {
  source = "../../modules/static-ip"

  project_id   = "pcc-prj-devops-nonprod"
  name         = "alloydb-psc-endpoint"
  description  = "Internal IP for AlloyDB PSC endpoint"
  region       = "us-east4"
  address_type = "INTERNAL"
  subnetwork   = "projects/pcc-prj-network/regions/us-east4/subnetworks/pcc-subnet-nonprod"

  labels = {
    purpose     = "alloydb-psc"
    environment = "nonprod"
  }
}
```

---

## Design Considerations

### Address Types

**EXTERNAL**:
- For load balancers, VPN endpoints, public-facing services
- Requires network tier (PREMIUM or STANDARD)
- Can be regional or global
- Billable when reserved (even if not attached)

**INTERNAL**:
- For PSC endpoints, internal load balancers
- Requires subnetwork
- Optional purpose field
- Free when not attached

### Network Tier (EXTERNAL only)

**PREMIUM** (default):
- Uses Google's global network
- Lower latency, higher reliability
- Higher cost (~$18/month for reserved IP)

**STANDARD**:
- Uses regional internet routes
- Acceptable for VPN and non-critical services
- Lower cost (~$5/month for reserved IP)

### Regional vs Global

- **Regional**: Specify `region` parameter (e.g., "us-east4")
- **Global**: Omit `region` parameter (for global load balancers)

---

## Next Phase Dependencies

**Phase 1.4-1.7** will create other infrastructure modules (firewall-rule, health-check, etc.)

**Phase 2.1** will compose this module in `wireguard-vpn.tf` to reserve the external IP for the WireGuard VPN load balancer

---

## Time Estimate

- **Create directory**: 1 minute
- **Create versions.tf**: 2 minutes
- **Create variables.tf**: 8-10 minutes (12 variables with validation)
- **Create outputs.tf**: 3-4 minutes (6 outputs)
- **Create main.tf**: 4-5 minutes (address resource with conditional logic)
- **Review/validate**: 2-3 minutes
- **Total**: 15-20 minutes

---

**Status**: Ready for execution by CC
**Next**: Phase 1.4 - Create Firewall Rule Module
