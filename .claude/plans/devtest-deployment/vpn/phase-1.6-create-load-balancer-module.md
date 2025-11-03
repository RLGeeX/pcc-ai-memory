# Phase 1.6: Create Load Balancer Module

**Phase**: 1.6 (VPN Infrastructure - Generic Module)
**Duration**: 30-35 minutes
**Type**: Implementation
**Tool**: Claude Code (CC)
**Status**: Ready for Execution

---

## Objective

Create reusable Network Load Balancer (NLB) module in `pcc-tf-library` for regional L4 load balancing with static IP forwarding. Module is generic and not specific to WireGuard VPN.

## Prerequisites

✅ `pcc-tf-library` repository available
✅ Understanding of GCP Network Load Balancers (regional, external)
✅ `static-ip` module created (Phase 1.3)
✅ `health-check` module created (Phase 1.5)

---

## Module Structure

**Location**: `pcc-tf-library/modules/network-load-balancer/`

**Files to Create**:
1. `versions.tf` - Provider requirements
2. `variables.tf` - Input parameters
3. `outputs.tf` - Exported values
4. `main.tf` - Backend service and forwarding rule resources

---

## Step 1: Create versions.tf

**File**: `pcc-tf-library/modules/network-load-balancer/versions.tf`

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

**File**: `pcc-tf-library/modules/network-load-balancer/variables.tf`

```hcl
variable "project_id" {
  description = "GCP project ID where load balancer will be created"
  type        = string
}

variable "name" {
  description = "Name of the load balancer (used for backend service and forwarding rule)"
  type        = string
}

variable "region" {
  description = "GCP region for regional load balancer"
  type        = string
}

variable "protocol" {
  description = "Protocol for load balancing (TCP or UDP)"
  type        = string
  default     = "TCP"

  validation {
    condition     = contains(["TCP", "UDP"], var.protocol)
    error_message = "Protocol must be TCP or UDP"
  }
}

variable "port_range" {
  description = "Port range for forwarding rule (e.g., '51820' or '80-443')"
  type        = string
}

variable "ip_address" {
  description = "Self-link of static IP address for forwarding rule"
  type        = string
}

variable "backend_instance_group" {
  description = "Self-link of the instance group for backend service"
  type        = string
}

variable "health_check" {
  description = "Self-link of health check resource"
  type        = string
}

variable "session_affinity" {
  description = "Session affinity option (CLIENT_IP, CLIENT_IP_PROTO, or NONE)"
  type        = string
  default     = "NONE"

  validation {
    condition     = contains(["CLIENT_IP", "CLIENT_IP_PROTO", "NONE"], var.session_affinity)
    error_message = "Session affinity must be CLIENT_IP, CLIENT_IP_PROTO, or NONE"
  }
}

variable "timeout_sec" {
  description = "Backend service timeout in seconds"
  type        = number
  default     = 10

  validation {
    condition     = var.timeout_sec >= 1 && var.timeout_sec <= 3600
    error_message = "Timeout must be between 1 and 3600 seconds"
  }
}

variable "description" {
  description = "Description of the load balancer's purpose"
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

**File**: `pcc-tf-library/modules/network-load-balancer/outputs.tf`

```hcl
output "backend_service_self_link" {
  description = "The self_link of the backend service"
  value       = google_compute_region_backend_service.backend.self_link
}

output "forwarding_rule_self_link" {
  description = "The self_link of the forwarding rule"
  value       = google_compute_forwarding_rule.frontend.self_link
}

output "forwarding_rule_ip" {
  description = "The IP address of the forwarding rule"
  value       = google_compute_forwarding_rule.frontend.ip_address
}

output "id" {
  description = "The ID of the forwarding rule"
  value       = google_compute_forwarding_rule.frontend.id
}

output "backend_service_id" {
  description = "The ID of the backend service"
  value       = google_compute_region_backend_service.backend.id
}

output "backend_service_name" {
  description = "The name of the backend service"
  value       = google_compute_region_backend_service.backend.name
}
```

---

## Step 4: Create main.tf

**File**: `pcc-tf-library/modules/network-load-balancer/main.tf`

```hcl
# Backend service with instance group
resource "google_compute_region_backend_service" "backend" {
  project     = var.project_id
  name        = "${var.name}-backend"
  region      = var.region
  description = var.description

  protocol         = var.protocol
  timeout_sec      = var.timeout_sec
  session_affinity = var.session_affinity

  backend {
    group = var.backend_instance_group
  }

  health_checks = [var.health_check]
}

# Forwarding rule (frontend)
resource "google_compute_forwarding_rule" "frontend" {
  project     = var.project_id
  name        = "${var.name}-frontend"
  region      = var.region
  description = var.description

  ip_protocol           = var.protocol
  port_range            = var.port_range
  ip_address            = var.ip_address
  load_balancing_scheme = "EXTERNAL"
  backend_service       = google_compute_region_backend_service.backend.self_link

  labels = var.labels
}
```

---

## Validation Checklist

- [ ] Directory created: `pcc-tf-library/modules/network-load-balancer/`
- [ ] `versions.tf` created with provider ~> 5.0
- [ ] `variables.tf` created with 10 input variables
- [ ] `outputs.tf` created with 6 outputs
- [ ] `main.tf` created with backend service + forwarding rule
- [ ] Protocol validation enforces TCP or UDP
- [ ] Session affinity validation enforces valid options
- [ ] Timeout validation enforces 1-3600 second range
- [ ] Backend service references health check
- [ ] Forwarding rule references static IP
- [ ] No syntax errors

---

## Module Interface

**Required Inputs**:
- `project_id` - GCP project
- `name` - Load balancer name (prefix for backend/frontend)
- `region` - Regional NLB location
- `port_range` - Port(s) to forward (e.g., "51820" or "80-443")
- `ip_address` - Static IP self_link
- `backend_instance_group` - MIG instance group self_link
- `health_check` - Health check self_link

**Key Optional Inputs**:
- `protocol` - TCP or UDP (default: TCP)
- `session_affinity` - CLIENT_IP, CLIENT_IP_PROTO, or NONE (default: NONE)
- `timeout_sec` - Backend timeout (default: 10)
- `description` - Purpose documentation
- `labels` - Resource labels

**Outputs**:
- `forwarding_rule_ip` - The public IP address
- `forwarding_rule_self_link` - For use in other resources
- `backend_service_self_link` - For monitoring/debugging
- `backend_service_id` - Resource identifier
- `id` - Forwarding rule identifier

---

## Usage Example

```hcl
module "wireguard_nlb" {
  source = "../../modules/network-load-balancer"

  project_id   = "pcc-prj-devops-nonprod"
  name         = "wireguard-vpn-nlb"
  region       = "us-east4"
  description  = "Network load balancer for WireGuard VPN"

  protocol              = "UDP"
  port_range            = "51820"
  ip_address            = module.wireguard_ip.self_link
  backend_instance_group = module.wireguard_mig.instance_group
  health_check          = module.wireguard_health_check.self_link

  session_affinity = "CLIENT_IP"  # Sticky sessions for VPN
  timeout_sec      = 10

  labels = {
    terraform   = "true"
    component   = "wireguard-vpn"
    environment = "nonprod"
  }
}

# Output the public IP for client configuration
output "vpn_endpoint" {
  description = "WireGuard VPN public endpoint"
  value       = "${module.wireguard_nlb.forwarding_rule_ip}:51820"
}
```

---

## Design Considerations

### Regional vs Global Load Balancers
- This module creates **regional** Network Load Balancer (L4)
- Regional NLB for single-region backends (like WireGuard MIG in us-east4)
- For global distribution, use Google Cloud Load Balancer (L7) instead
- Regional NLB has lower latency for regional traffic

### UDP Load Balancing
- **UDP protocol** fully supported for WireGuard VPN
- No connection tracking like TCP (stateless)
- Session affinity recommended for VPN use cases
- Health checks validate backend availability (HTTP on port 8080, not UDP)

### Session Affinity Options
- **NONE**: No session stickiness (random distribution)
- **CLIENT_IP**: Same client IP → same backend (5-tuple hash)
- **CLIENT_IP_PROTO**: Client IP + protocol → same backend
- **WireGuard recommendation**: CLIENT_IP for connection persistence

### Backend Service Configuration
- **timeout_sec**: How long backend has to respond (default 10s)
- **health_checks**: Single health check required for auto-healing
- **backend.group**: MIG instance group (not individual instances)
- Single backend block sufficient for single-zone MIG

### Static IP Binding
- Forwarding rule binds to static IP created separately
- IP persists even if load balancer recreated
- Critical for VPN client configuration stability
- Pass `self_link` not `address` value

### Load Balancing Scheme
- **EXTERNAL**: Public internet-facing (default for WireGuard)
- **INTERNAL**: VPC-internal only (for private services)
- WireGuard uses EXTERNAL to accept connections from developer laptops

### Port Range Syntax
- Single port: `"51820"`
- Port range: `"8000-9000"`
- Multiple ports not supported (create multiple forwarding rules)
- WireGuard uses single UDP port 51820

---

## Next Phase Dependencies

**Phase 2.1** will compose this module in `wireguard-vpn.tf` to create the complete load balancer stack

**Phase 3.1** will deploy the infrastructure via Terraform apply

**Phase 3.2** will generate client configs using the public IP from `forwarding_rule_ip` output

---

## Time Estimate

- **Create directory**: 1 minute
- **Create versions.tf**: 2 minutes
- **Create variables.tf**: 6-7 minutes (10 variables with validation)
- **Create outputs.tf**: 3-4 minutes (6 outputs)
- **Create main.tf**: 6-7 minutes (backend service + forwarding rule)
- **Review/validate**: 4-5 minutes
- **Total**: 30-35 minutes

---

**Status**: Ready for execution by CC
**Next**: Phase 1.7 - Create PSC Consumer Module
