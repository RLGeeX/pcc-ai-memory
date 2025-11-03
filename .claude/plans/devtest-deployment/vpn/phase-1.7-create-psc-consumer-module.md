# Phase 1.7: Create PSC Consumer Module

**Phase**: 1.7 (VPN Infrastructure - Generic Module)
**Duration**: 20-25 minutes
**Type**: Implementation
**Tool**: Claude Code (CC)
**Status**: Ready for Execution

---

## Objective

Create reusable Private Service Connect (PSC) consumer module in `pcc-tf-library` for connecting to managed services via PSC endpoints. Modularizes the pattern from `alloydb-psc-consumer.tf`. Module is generic and not specific to AlloyDB.

## Prerequisites

✅ `pcc-tf-library` repository available
✅ Understanding of GCP Private Service Connect
✅ Existing PSC service attachment URI from managed service (e.g., AlloyDB)

---

## Module Structure

**Location**: `pcc-tf-library/modules/psc-consumer/`

**Files to Create**:
1. `versions.tf` - Provider requirements
2. `variables.tf` - Input parameters
3. `outputs.tf` - Exported values
4. `main.tf` - Internal IP and PSC forwarding rule resources

---

## Step 1: Create versions.tf

**File**: `pcc-tf-library/modules/psc-consumer/versions.tf`

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

**File**: `pcc-tf-library/modules/psc-consumer/variables.tf`

```hcl
variable "project_id" {
  description = "GCP project ID where PSC endpoint will be created"
  type        = string
}

variable "name" {
  description = "Name for the PSC endpoint and forwarding rule"
  type        = string

  validation {
    condition     = can(regex("^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$", var.name))
    error_message = "Name must be lowercase alphanumeric with hyphens, max 63 chars"
  }
}

variable "region" {
  description = "GCP region for PSC endpoint"
  type        = string
}

variable "network" {
  description = "VPC network self_link where PSC endpoint will be created"
  type        = string
}

variable "subnetwork" {
  description = "VPC subnetwork self_link for internal IP allocation"
  type        = string
}

variable "target" {
  description = "PSC service attachment URI to connect to (e.g., projects/PROJECT/regions/REGION/serviceAttachments/SERVICE)"
  type        = string

  validation {
    condition     = can(regex("^projects/[^/]+/regions/[^/]+/serviceAttachments/[^/]+$", var.target))
    error_message = "Target must be a valid PSC service attachment URI"
  }
}

variable "ip_address" {
  description = "Specific internal IP address to use (optional, auto-allocated if not specified)"
  type        = string
  default     = null
}

variable "description" {
  description = "Description of the PSC endpoint's purpose"
  type        = string
  default     = ""
}

variable "labels" {
  description = "Resource labels"
  type        = map(string)
  default     = {}
}
```

---

## Step 3: Create outputs.tf

**File**: `pcc-tf-library/modules/psc-consumer/outputs.tf`

```hcl
output "endpoint_ip" {
  description = "The internal IP address of the PSC endpoint"
  value       = google_compute_address.psc_endpoint.address
}

output "endpoint_self_link" {
  description = "Self link of the internal IP address"
  value       = google_compute_address.psc_endpoint.self_link
}

output "endpoint_id" {
  description = "ID of the internal IP address resource"
  value       = google_compute_address.psc_endpoint.id
}

output "forwarding_rule_self_link" {
  description = "Self link of the PSC forwarding rule"
  value       = google_compute_forwarding_rule.psc.self_link
}

output "forwarding_rule_id" {
  description = "ID of the PSC forwarding rule"
  value       = google_compute_forwarding_rule.psc.id
}

output "psc_connection_status" {
  description = "Status of the PSC connection"
  value       = google_compute_forwarding_rule.psc.psc_connection_status
}
```

---

## Step 4: Create main.tf

**File**: `pcc-tf-library/modules/psc-consumer/main.tf`

```hcl
# Internal IP address for PSC endpoint
resource "google_compute_address" "psc_endpoint" {
  project     = var.project_id
  name        = "${var.name}-endpoint"
  region      = var.region
  description = var.description

  address_type = "INTERNAL"
  subnetwork   = var.subnetwork
  address      = var.ip_address  # Auto-allocate if null

  labels = var.labels
}

# PSC forwarding rule to connect to service attachment
resource "google_compute_forwarding_rule" "psc" {
  project     = var.project_id
  name        = var.name
  region      = var.region
  description = var.description

  network               = var.network
  target                = var.target
  ip_address            = google_compute_address.psc_endpoint.id
  load_balancing_scheme = ""  # Empty for PSC

  labels = var.labels
}
```

---

## Validation Checklist

- [ ] Directory created: `pcc-tf-library/modules/psc-consumer/`
- [ ] `versions.tf` created with provider ~> 5.0
- [ ] `variables.tf` created with 8 input variables
- [ ] `outputs.tf` created with 6 outputs
- [ ] `main.tf` created with internal IP + forwarding rule
- [ ] Name validation enforces GCP naming rules
- [ ] Target validation enforces PSC service attachment URI format
- [ ] Internal IP address type set to INTERNAL
- [ ] Load balancing scheme set to empty string for PSC
- [ ] No syntax errors

---

## Module Interface

**Required Inputs**:
- `project_id` - GCP project
- `name` - PSC endpoint name
- `region` - PSC endpoint region
- `network` - VPC network self_link
- `subnetwork` - VPC subnet self_link
- `target` - PSC service attachment URI

**Key Optional Inputs**:
- `ip_address` - Specific IP to use (default: auto-allocate)
- `description` - Purpose documentation
- `labels` - Resource labels

**Outputs**:
- `endpoint_ip` - The internal IP address (e.g., 10.24.128.3)
- `endpoint_self_link` - For use in other resources
- `psc_connection_status` - PSC connection health status
- `forwarding_rule_id` - Resource identifier

---

## Usage Example

```hcl
# AlloyDB PSC endpoint
module "alloydb_psc" {
  source = "../../modules/psc-consumer"

  project_id  = "pcc-prj-devops-nonprod"
  name        = "alloydb-psc-endpoint"
  region      = "us-east4"
  description = "Private Service Connect endpoint for AlloyDB cluster"

  network    = "projects/pcc-prj-network/global/networks/pcc-vpc-nonprod"
  subnetwork = "projects/pcc-prj-network/regions/us-east4/subnetworks/pcc-alloydb-subnet"

  # Service attachment from AlloyDB cluster output
  target = module.alloydb_cluster.psc_service_attachment_link

  labels = {
    terraform   = "true"
    component   = "alloydb"
    environment = "nonprod"
  }
}

# Use the PSC endpoint IP in connection strings
output "alloydb_connection_string" {
  description = "AlloyDB connection via PSC endpoint"
  value       = "postgresql://user@${module.alloydb_psc.endpoint_ip}:5432/database"
  sensitive   = true
}
```

---

## Design Considerations

### PSC vs Direct Connection
- **PSC endpoint**: Private, VPC-internal connection to managed services
- **Direct connection**: Public IP or VPN required
- AlloyDB, Cloud SQL, other managed services offer PSC attachments
- PSC provides better security and latency vs public endpoints

### AlloyDB Use Case
- AlloyDB clusters expose PSC service attachment
- Consumer creates forwarding rule targeting attachment
- Internal IP allocated in consumer's VPC subnet
- WireGuard VPN routes traffic to this internal IP (10.24.128.0/20)

### Internal IP Allocation
- **Auto-allocation** (default): GCP picks available IP from subnet
- **Manual allocation**: Specify exact IP via `ip_address` variable
- IP must be within subnet CIDR range
- Manual allocation useful for DNS records or firewall rules

### VPC Subnet Requirements
- PSC endpoint must be in a VPC subnet
- Subnet must have available IPs
- Recommended: Dedicated subnet for PSC endpoints (e.g., /24 for 251 IPs)
- AlloyDB uses 10.24.128.0/20 subnet in our architecture

### Load Balancing Scheme
- PSC forwarding rules use **empty string** for load_balancing_scheme
- Not a load balancer, just a forwarding rule
- Different from INTERNAL or EXTERNAL schemes

### Connection Status Monitoring
- `psc_connection_status` output shows connection health
- Values: ACCEPTED, PENDING, REJECTED
- Monitor in production for service availability

### Multiple PSC Endpoints
- Can create multiple PSC endpoints to same service attachment
- Useful for multi-region or multi-VPC architectures
- Each endpoint gets unique internal IP

---

## Next Phase Dependencies

**Phase 2.1** may reference this module if PSC endpoints need modularization

**Existing deployment**: AlloyDB PSC endpoint already exists, so this module can be used for future managed services (Cloud SQL, Memorystore, etc.)

**WireGuard VPN**: Routes traffic to PSC endpoint IP (10.24.128.3:5432)

---

## Time Estimate

- **Create directory**: 1 minute
- **Create versions.tf**: 2 minutes
- **Create variables.tf**: 5-6 minutes (8 variables with validation)
- **Create outputs.tf**: 3-4 minutes (6 outputs)
- **Create main.tf**: 4-5 minutes (internal IP + forwarding rule)
- **Review/validate**: 3-4 minutes
- **Total**: 20-25 minutes

---

**Status**: Ready for execution by CC
**Next**: Phase 2.1 - Compose WireGuard VPN Terraform Configuration
