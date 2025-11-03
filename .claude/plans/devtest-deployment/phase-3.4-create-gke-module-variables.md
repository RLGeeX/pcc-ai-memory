# Phase 3.4: Create GKE Module - variables.tf

**Phase**: 3.4 (GKE Infrastructure - Module Inputs)
**Duration**: 15-20 minutes
**Type**: Implementation
**Status**: Ready for Execution

---

## Execution Tool

**Use Claude Code for this phase** - Creating terraform variables file.

---

## Objective

Create `variables.tf` file for GKE Autopilot module with all required input parameters for cluster configuration, networking, features, and labels.

## Prerequisites

✅ Phase 3.3 completed (versions.tf created)
✅ Understanding of GKE Autopilot parameters
✅ Familiarity with Workload Identity and Connect Gateway

**Verify Prerequisites**:
```bash
# Verify versions.tf exists
ls -l ~/pcc/core/pcc-tf-library/modules/gke-autopilot/versions.tf

# Should show file created in Phase 3.3
```

---

## Variable Categories

1. **Required Core Variables** (4)
   - project_id, cluster_name, region, environment

2. **Networking Variables** (2)
   - network_id, subnet_id

3. **Feature Flags** (2)
   - enable_workload_identity, enable_connect_gateway

4. **GKE Configuration** (2)
   - release_channel, cluster_display_name

5. **Labels** (1)
   - cluster_labels

---

## Step 1: Create variables.tf

**File**: `pcc-tf-library/modules/gke-autopilot/variables.tf`

```hcl
# Core Configuration
variable "project_id" {
  description = "GCP project ID where GKE cluster will be created"
  type        = string
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,39}$", var.cluster_name))
    error_message = "Cluster name must start with lowercase letter, contain only lowercase letters, numbers, hyphens, max 40 chars"
  }
}

variable "region" {
  description = "GCP region for the GKE cluster"
  type        = string
  default     = "us-east4"
}

variable "environment" {
  description = "Environment name (devtest, dev, staging, prod, nonprod)"
  type        = string

  validation {
    condition     = contains(["devtest", "dev", "staging", "prod", "nonprod"], var.environment)
    error_message = "Environment must be one of: devtest, dev, staging, prod, nonprod"
  }
}

# Networking Configuration
variable "network_id" {
  description = "Full VPC network ID (projects/{project}/global/networks/{name})"
  type        = string

  validation {
    condition     = can(regex("^projects/[^/]+/global/networks/[^/]+$", var.network_id))
    error_message = "Network ID must be in format: projects/{project}/global/networks/{name}"
  }
}

variable "subnet_id" {
  description = "Full subnet ID (projects/{project}/regions/{region}/subnetworks/{name})"
  type        = string

  validation {
    condition     = can(regex("^projects/[^/]+/regions/[^/]+/subnetworks/[^/]+$", var.subnet_id))
    error_message = "Subnet ID must be in format: projects/{project}/regions/{region}/subnetworks/{name}"
  }
}

# GKE Features
variable "enable_workload_identity" {
  description = "Enable Workload Identity for pod-level GCP authentication (ADR-005)"
  type        = bool
  default     = true
}

variable "enable_connect_gateway" {
  description = "Enable Connect Gateway for kubectl access via PSC (ADR-002)"
  type        = bool
  default     = true
}

# Cluster Configuration
variable "release_channel" {
  description = "GKE release channel for cluster version management"
  type        = string
  default     = "STABLE"

  validation {
    condition     = contains(["RAPID", "REGULAR", "STABLE", "UNSPECIFIED"], var.release_channel)
    error_message = "Release channel must be one of: RAPID, REGULAR, STABLE, UNSPECIFIED"
  }
}

variable "cluster_display_name" {
  description = "Human-readable name for the cluster (defaults to cluster_name)"
  type        = string
  default     = ""
}

# Labels
variable "cluster_labels" {
  description = "Labels to apply to the GKE cluster"
  type        = map(string)
  default     = {}

  validation {
    condition     = alltrue([for k, v in var.cluster_labels : can(regex("^[a-z][a-z0-9_-]{0,62}$", k))])
    error_message = "Label keys must start with lowercase letter, contain only lowercase letters, numbers, underscores, hyphens, max 63 chars"
  }
}
```

---

## Variable Design Decisions

### Why These Validations?

1. **cluster_name regex**: GKE naming restrictions
2. **environment enum**: Enforces ADR-007 environment naming
3. **network_id/subnet_id format**: Prevents partial resource IDs
4. **cluster_labels**: Enforces GCP label naming rules

### Default Values

- `enable_workload_identity = true`: ADR-005 requirement
- `enable_connect_gateway = true`: ADR-002 requirement
- `release_channel = "STABLE"`: Balance stability and features
- `region = "us-east4"`: PCC standard region

---

## Validation Checklist

- [ ] File created: `variables.tf`
- [ ] 11 variables defined
- [ ] 5 required variables (no defaults)
- [ ] 6 optional variables (with defaults)
- [ ] All validations include error messages
- [ ] Descriptions reference ADRs where applicable
- [ ] 2-space indentation throughout
- [ ] No syntax errors

---

## Variable Summary

| Variable | Type | Required | Default | Validation |
|----------|------|----------|---------|------------|
| project_id | string | ✅ | - | None |
| cluster_name | string | ✅ | - | Regex |
| region | string | ❌ | us-east4 | None |
| environment | string | ✅ | - | Enum |
| network_id | string | ✅ | - | Regex |
| subnet_id | string | ✅ | - | Regex |
| enable_workload_identity | bool | ❌ | true | None |
| enable_connect_gateway | bool | ❌ | true | None |
| release_channel | string | ❌ | STABLE | Enum |
| cluster_display_name | string | ❌ | "" | None |
| cluster_labels | map(string) | ❌ | {} | Regex |

---

## Next Phase Dependencies

**Phase 3.5** will create `outputs.tf` using:
- `google_container_cluster.cluster.id`
- `google_container_cluster.cluster.endpoint`
- `google_gke_hub_membership.cluster.id`

---

## References

- **GKE Naming**: https://cloud.google.com/kubernetes-engine/docs/reference/rest/v1/projects.locations.clusters#Cluster
- **ADR-005**: Workload Identity Pattern
- **ADR-007**: Four Environment Architecture

---

## Time Estimate

- **Create core variables**: 5 minutes (4 variables)
- **Create networking variables**: 3 minutes (2 variables)
- **Create feature flags**: 2 minutes (2 variables - Binary Auth removed)
- **Create config variables**: 2 minutes (2 variables)
- **Create labels**: 2 minutes (1 variable)
- **Add validations**: 3-4 minutes
- **Total**: 14-17 minutes

---

**Status**: Ready for execution
**Next**: Phase 3.5 - Create GKE Module (outputs.tf)
