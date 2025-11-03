# Phase 1.2: Create MIG Module

**Phase**: 1.2 (VPN Infrastructure - Generic Module)
**Duration**: 25-30 minutes
**Type**: Implementation
**Tool**: Claude Code (CC)
**Status**: Ready for Execution

---

## Objective

Create reusable Managed Instance Group (MIG) module in `pcc-tf-library` for regional auto-healing instance groups. Module is generic and not specific to WireGuard VPN.

## Prerequisites

✅ `pcc-tf-library` repository available
✅ Understanding of GCP MIGs and auto-healing

---

## Module Structure

**Location**: `pcc-tf-library/modules/mig/`

**Files to Create**:
1. `versions.tf` - Provider requirements
2. `variables.tf` - Input parameters
3. `outputs.tf` - Exported values
4. `main.tf` - Regional MIG resource

---

## Step 1: Create versions.tf

**File**: `pcc-tf-library/modules/mig/versions.tf`

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

**File**: `pcc-tf-library/modules/mig/variables.tf`

```hcl
variable "project_id" {
  description = "GCP project ID where MIG will be created"
  type        = string
}

variable "name" {
  description = "Name of the managed instance group"
  type        = string

  validation {
    condition     = can(regex("^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$", var.name))
    error_message = "Name must be lowercase, alphanumeric with hyphens, max 63 chars"
  }
}

variable "region" {
  description = "GCP region for the regional MIG (e.g., us-east4)"
  type        = string
}

variable "base_instance_name" {
  description = "Prefix for instance names created by MIG"
  type        = string
  default     = null
}

variable "instance_template" {
  description = "Self-link to the instance template (from google_compute_instance_template.self_link)"
  type        = string
}

variable "target_size" {
  description = "Target number of instances in the MIG"
  type        = number
  default     = 1

  validation {
    condition     = var.target_size >= 1
    error_message = "Target size must be at least 1"
  }
}

variable "auto_healing_policies" {
  description = "Auto-healing configuration with health check and initial delay"
  type = object({
    health_check      = string  # Self-link to health check
    initial_delay_sec = number  # Seconds to wait before auto-healing kicks in
  })
  default = null
}

variable "update_policy" {
  description = "Update policy for rolling updates"
  type = object({
    type                         = string  # PROACTIVE or OPPORTUNISTIC
    minimal_action               = string  # REPLACE or RESTART
    max_surge_fixed              = number  # Max instances to create during update
    max_unavailable_fixed        = number  # Max instances unavailable during update
    replacement_method           = string  # SUBSTITUTE or RECREATE
  })
  default = {
    type                  = "PROACTIVE"
    minimal_action        = "REPLACE"
    max_surge_fixed       = 1
    max_unavailable_fixed = 0
    replacement_method    = "SUBSTITUTE"
  }
}

variable "named_ports" {
  description = "List of named ports for load balancing"
  type = list(object({
    name = string
    port = number
  }))
  default = []
}

variable "distribution_policy_zones" {
  description = "List of zones to distribute instances across (e.g., ['us-east4-a', 'us-east4-b'])"
  type        = list(string)
  default     = []
}

variable "wait_for_instances" {
  description = "Whether to wait for all instances to be created/updated"
  type        = bool
  default     = false
}

variable "timeouts" {
  description = "Timeout configuration for MIG operations"
  type = object({
    create = string
    update = string
    delete = string
  })
  default = {
    create = "15m"
    update = "15m"
    delete = "15m"
  }
}
```

---

## Step 3: Create outputs.tf

**File**: `pcc-tf-library/modules/mig/outputs.tf`

```hcl
output "id" {
  description = "Identifier of the managed instance group"
  value       = google_compute_region_instance_group_manager.mig.id
}

output "self_link" {
  description = "Self-link of the managed instance group"
  value       = google_compute_region_instance_group_manager.mig.self_link
}

output "instance_group" {
  description = "Instance group URL (for load balancer backend)"
  value       = google_compute_region_instance_group_manager.mig.instance_group
}

output "name" {
  description = "Name of the managed instance group"
  value       = google_compute_region_instance_group_manager.mig.name
}

output "region" {
  description = "Region where the MIG is deployed"
  value       = google_compute_region_instance_group_manager.mig.region
}

output "status" {
  description = "Status information about the MIG"
  value       = google_compute_region_instance_group_manager.mig.status
}
```

---

## Step 4: Create main.tf

**File**: `pcc-tf-library/modules/mig/main.tf`

```hcl
# Regional Managed Instance Group
resource "google_compute_region_instance_group_manager" "mig" {
  project = var.project_id
  name    = var.name
  region  = var.region

  base_instance_name = var.base_instance_name != null ? var.base_instance_name : var.name

  version {
    instance_template = var.instance_template
  }

  target_size = var.target_size

  # Auto-healing with health check
  dynamic "auto_healing_policies" {
    for_each = var.auto_healing_policies != null ? [var.auto_healing_policies] : []
    content {
      health_check      = auto_healing_policies.value.health_check
      initial_delay_sec = auto_healing_policies.value.initial_delay_sec
    }
  }

  # Update policy for rolling updates
  update_policy {
    type                         = var.update_policy.type
    minimal_action               = var.update_policy.minimal_action
    max_surge_fixed              = var.update_policy.max_surge_fixed
    max_unavailable_fixed        = var.update_policy.max_unavailable_fixed
    replacement_method           = var.update_policy.replacement_method
  }

  # Named ports for load balancing
  dynamic "named_port" {
    for_each = var.named_ports
    content {
      name = named_port.value.name
      port = named_port.value.port
    }
  }

  # Distribution policy (zone selection)
  dynamic "distribution_policy_zones" {
    for_each = length(var.distribution_policy_zones) > 0 ? [1] : []
    content {
      zones = var.distribution_policy_zones
    }
  }

  wait_for_instances = var.wait_for_instances

  timeouts {
    create = var.timeouts.create
    update = var.timeouts.update
    delete = var.timeouts.delete
  }
}
```

---

## Validation Checklist

- [ ] Directory created: `pcc-tf-library/modules/mig/`
- [ ] `versions.tf` created with provider ~> 5.0
- [ ] `variables.tf` created with 11 input variables
- [ ] `outputs.tf` created with 6 outputs
- [ ] `main.tf` created with regional MIG resource
- [ ] Auto-healing is optional (dynamic block)
- [ ] Update policy has sensible defaults
- [ ] No syntax errors

---

## Module Interface

**Required Inputs**:
- `project_id` - Where to create MIG
- `name` - MIG identifier
- `region` - GCP region (e.g., us-east4)
- `instance_template` - Self-link from instance template resource

**Optional Inputs**:
- `target_size` - Number of instances (default: 1)
- `base_instance_name` - Prefix for instance names (default: same as `name`)
- `auto_healing_policies` - Health check + initial delay
- `update_policy` - Rolling update configuration
- `named_ports` - For load balancer backends
- `distribution_policy_zones` - Spread instances across zones
- `wait_for_instances` - Block until all instances ready
- `timeouts` - Operation timeouts

**Outputs**:
- `id` - MIG identifier
- `self_link` - For resource references
- `instance_group` - For load balancer backends
- `name` - MIG name
- `region` - Deployment region
- `status` - MIG status info

---

## Usage Example

```hcl
module "wireguard_mig" {
  source = "../../modules/mig"

  project_id        = "pcc-prj-devops-nonprod"
  name              = "wireguard-vpn-mig"
  region            = "us-east4"
  instance_template = google_compute_instance_template.wireguard.self_link

  target_size = 1

  # Auto-healing with health check
  auto_healing_policies = {
    health_check      = google_compute_health_check.wireguard.self_link
    initial_delay_sec = 300  # Wait 5 minutes for VM to boot
  }

  # Proactive rolling updates
  update_policy = {
    type                  = "PROACTIVE"
    minimal_action        = "REPLACE"
    max_surge_fixed       = 1
    max_unavailable_fixed = 0
    replacement_method    = "SUBSTITUTE"
  }

  # Named port for health checks
  named_ports = [
    {
      name = "wireguard"
      port = 51820
    }
  ]

  # Distribute across 2 zones for availability
  distribution_policy_zones = ["us-east4-a", "us-east4-b"]
}
```

---

## Design Considerations

### Regional vs Zonal
- Module creates **regional** MIG (higher availability)
- Spreads instances across zones automatically
- Use `distribution_policy_zones` to control zone selection

### Auto-Healing
- Requires a health check resource
- `initial_delay_sec` prevents premature termination during boot
- Typical values: 300s (5 min) for VMs with startup scripts

### Update Policy
- **PROACTIVE**: Immediately replace instances when template changes
- **OPPORTUNISTIC**: Replace only when manually triggered
- **max_surge_fixed=1, max_unavailable_fixed=0**: Zero-downtime updates

### Named Ports
- Required for load balancer backends
- Maps service name to port number
- Example: `{name = "http", port = 80}`

---

## Next Phase Dependencies

**Phase 1.3-1.6** will create other infrastructure modules (static-ip, firewall-rule, etc.)

**Phase 2.1** will compose this module in `wireguard-vpn.tf` to create the VPN MIG with auto-healing

---

## Time Estimate

- **Create directory**: 1 minute
- **Create versions.tf**: 2 minutes
- **Create variables.tf**: 10-12 minutes (11 variables with validation)
- **Create outputs.tf**: 4-5 minutes (6 outputs)
- **Create main.tf**: 8-10 minutes (regional MIG with dynamic blocks)
- **Review/validate**: 3-4 minutes
- **Total**: 25-30 minutes

---

**Status**: Ready for execution by CC
**Next**: Phase 1.3 - Create Static IP Module
