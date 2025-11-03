# Phase 1.4: Create Firewall Rule Module

**Phase**: 1.4 (VPN Infrastructure - Generic Module)
**Duration**: 20-25 minutes
**Type**: Implementation
**Tool**: Claude Code (CC)
**Status**: Ready for Execution

---

## Objective

Create reusable Firewall Rule module in `pcc-tf-library` for VPC firewall rules (ingress/egress). Module is generic and not specific to WireGuard VPN.

## Prerequisites

✅ `pcc-tf-library` repository available
✅ Understanding of GCP VPC firewall rules and network tags

---

## Module Structure

**Location**: `pcc-tf-library/modules/firewall-rule/`

**Files to Create**:
1. `versions.tf` - Provider requirements
2. `variables.tf` - Input parameters
3. `outputs.tf` - Exported values
4. `main.tf` - Firewall rule resource

---

## Step 1: Create versions.tf

**File**: `pcc-tf-library/modules/firewall-rule/versions.tf`

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

**File**: `pcc-tf-library/modules/firewall-rule/variables.tf`

```hcl
variable "project_id" {
  description = "GCP project ID where firewall rule will be created"
  type        = string
}

variable "name" {
  description = "Name of the firewall rule"
  type        = string
}

variable "network" {
  description = "VPC network self_link (e.g., projects/PROJECT/global/networks/NETWORK)"
  type        = string
}

variable "direction" {
  description = "Direction of traffic (INGRESS or EGRESS)"
  type        = string
  default     = "INGRESS"

  validation {
    condition     = contains(["INGRESS", "EGRESS"], var.direction)
    error_message = "Direction must be INGRESS or EGRESS"
  }
}

variable "priority" {
  description = "Priority for this rule (0-65535, lower is higher priority)"
  type        = number
  default     = 1000

  validation {
    condition     = var.priority >= 0 && var.priority <= 65535
    error_message = "Priority must be between 0 and 65535"
  }
}

variable "source_ranges" {
  description = "List of source IP ranges (CIDR notation) for INGRESS rules"
  type        = list(string)
  default     = []
}

variable "destination_ranges" {
  description = "List of destination IP ranges (CIDR notation) for EGRESS rules"
  type        = list(string)
  default     = []
}

variable "source_tags" {
  description = "List of source network tags for INGRESS rules"
  type        = list(string)
  default     = []
}

variable "target_tags" {
  description = "List of target network tags to which rule applies"
  type        = list(string)
  default     = []
}

variable "allow_rules" {
  description = "List of allow rules with protocol and ports"
  type = list(object({
    protocol = string
    ports    = optional(list(string))
  }))
  default = []
}

variable "deny_rules" {
  description = "List of deny rules with protocol and ports"
  type = list(object({
    protocol = string
    ports    = optional(list(string))
  }))
  default = []
}

variable "disabled" {
  description = "Whether the firewall rule is disabled"
  type        = bool
  default     = false
}

variable "description" {
  description = "Description of the firewall rule's purpose"
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

**File**: `pcc-tf-library/modules/firewall-rule/outputs.tf`

```hcl
output "self_link" {
  description = "The self_link of the firewall rule"
  value       = google_compute_firewall.rule.self_link
}

output "id" {
  description = "The ID of the firewall rule"
  value       = google_compute_firewall.rule.id
}

output "name" {
  description = "The name of the firewall rule"
  value       = google_compute_firewall.rule.name
}
```

---

## Step 4: Create main.tf

**File**: `pcc-tf-library/modules/firewall-rule/main.tf`

```hcl
resource "google_compute_firewall" "rule" {
  project  = var.project_id
  name        = var.name
  network     = var.network
  description = var.description

  direction = var.direction
  priority  = var.priority
  disabled  = var.disabled

  labels = var.labels
  
  dynamic "allow" {
    for_each = var.allow_rules
    content {
      protocol = allow.value.protocol
      ports    = allow.value.ports
    }
  }
  
  dynamic "deny" {
    for_each = var.deny_rules
    content {
      protocol = deny.value.protocol
      ports    = deny.value.ports
    }
  }
  
  source_ranges      = var.direction == "INGRESS" ? var.source_ranges : null
  destination_ranges = var.direction == "EGRESS" ? var.destination_ranges : null
  source_tags        = var.source_tags
  target_tags        = var.target_tags
}
```

---

## Validation Checklist

- [ ] Directory created: `pcc-tf-library/modules/firewall-rule/`
- [ ] `versions.tf` created with provider ~> 5.0
- [ ] `variables.tf` created with 12 input variables
- [ ] `outputs.tf` created with 3 outputs
- [ ] `main.tf` created with firewall rule resource
- [ ] Direction validation enforces INGRESS or EGRESS
- [ ] Priority validation enforces 0-65535 range
- [ ] Conditional logic for source/destination ranges based on direction
- [ ] Dynamic blocks for allow and deny rules
- [ ] No syntax errors

---

## Module Interface

**Required Inputs**:
- `project_id` - GCP project
- `name` - Firewall rule name
- `network` - VPC network self_link

**Key Optional Inputs**:
- `direction` - INGRESS or EGRESS (default: INGRESS)
- `priority` - Rule priority 0-65535 (default: 1000)
- `source_ranges` - Source CIDRs for INGRESS
- `destination_ranges` - Dest CIDRs for EGRESS
- `target_tags` - Apply rule to tagged instances
- `allow_rules` - List of protocol/port allow rules
- `deny_rules` - List of protocol/port deny rules

**Outputs**:
- `self_link` - For use in other resources
- `id` - Resource identifier
- `name` - Rule name

---

## Usage Example

```hcl
module "wireguard_ingress" {
  source = "../../modules/firewall-rule"
  
  project_id = "pcc-prj-devops-nonprod"
  name       = "allow-wireguard-udp"
  network    = "projects/pcc-prj-network/global/networks/pcc-vpc-nonprod"
  
  direction      = "INGRESS"
  source_ranges  = ["0.0.0.0/0"]
  
  allow_rules = [{
    protocol = "udp"
    ports    = ["51820"]
  }]
}
```

---

## Design Considerations

### Direction-Based Logic
- **INGRESS rules** use `source_ranges` and `source_tags`
- **EGRESS rules** use `destination_ranges`
- Module uses conditional logic to set correct fields based on direction

### Allow vs Deny Rules
- Both `allow_rules` and `deny_rules` support multiple protocol/port combinations
- Cannot mix allow and deny in same rule (GCP limitation)
- Use `dynamic` blocks to support 0-N rules per firewall resource

### Priority and Rule Ordering
- Lower priority number = higher precedence (0 is highest)
- Default 1000 allows room for higher (100-500) and lower (1500-2000) priority rules
- Deny rules should typically have higher priority than allow rules

### Network Tags
- `target_tags` - Instances with these tags get the rule applied
- `source_tags` - Traffic from instances with these tags (INGRESS only)
- If no target_tags specified, rule applies to all instances in VPC

### Protocol/Port Syntax
- Protocol: "tcp", "udp", "icmp", "esp", "ah", "sctp", "ipip", "all"
- Ports: List of strings like ["80", "443", "8000-9000"]
- Ports optional - if omitted, applies to all ports for protocol

### Use Cases
- **Allow specific traffic**: WireGuard UDP 51820, SSH tcp/22, health checks
- **Deny risky traffic**: Block outbound to suspicious IPs
- **Tag-based microsegmentation**: Different rules for web-tier vs db-tier

---

## Next Phase Dependencies

**Phase 1.5** will create health-check module (for validating allowed traffic)

**Phase 2.1** will compose this module in `wireguard-vpn.tf` to create:
- Ingress rule allowing UDP/51820 from 0.0.0.0/0
- Ingress rule allowing health check probes from GCP ranges
- Potential egress rules if needed

---

## Time Estimate

- **Create directory**: 1 minute
- **Create versions.tf**: 2 minutes
- **Create variables.tf**: 6-7 minutes (12 variables with validation)
- **Create outputs.tf**: 2 minutes (3 outputs)
- **Create main.tf**: 5-6 minutes (dynamic blocks + conditional logic)
- **Review/validate**: 3-4 minutes
- **Total**: 20-25 minutes

---

**Status**: Ready for execution by CC
**Next**: Phase 1.5 - Create Health Check Module
