# Phase 2.3: Create AlloyDB Configuration

**Phase**: 2.3 (AlloyDB Infrastructure - Configuration Files)
**Duration**: 10-12 minutes
**Type**: Implementation
**Status**: Ready for Execution

---

## Execution Tool

**Use Claude Code for this phase** - Creating terraform configuration files only, no CLI commands.

---

## Objective

Create `alloydb.tf` configuration file in `pcc-app-shared-infra` that calls the AlloyDB module from Phases 2.1-2.2. This file defines the cluster, instance configuration, and outputs for downstream use.

## Prerequisites

✅ Phase 2.1 completed (module skeleton)
✅ Phase 2.2 completed (instances configuration)
✅ `pcc-app-shared-infra` repository available
✅ Network outputs from pcc-foundation-infra

---

## File Location

**Repository**: `pcc-app-shared-infra`
**File**: `terraform/alloydb.tf` (check if exists, may need to update or create)

---

## Step 1: Check Existing File

Check if `alloydb.tf` already exists:

**Path**: `~/pcc/infra/pcc-app-shared-infra/terraform/alloydb.tf`

**If file exists**: Update with new module call (replace old content)
**If file doesn't exist**: Create new file (Step 2)

---

## Step 2: Create/Update alloydb.tf

**File**: `pcc-app-shared-infra/terraform/alloydb.tf`

```hcl
# AlloyDB Cluster Configuration
# Environment-specific configuration using variable
# Note: environment variable should be defined in variables.tf (Phase 2.6)

variable "alloydb_availability_type" {
  description = "Availability type: ZONAL (cost-optimized) or REGIONAL (HA)"
  type        = string
  default     = "ZONAL"
}

variable "alloydb_enable_read_replica" {
  description = "Enable read replica (production only)"
  type        = bool
  default     = false
}

variable "alloydb_machine_type" {
  description = "Machine type for AlloyDB instance"
  type        = string
  default     = "db-standard-2" # devtest/dev: db-standard-2, staging/prod: db-standard-4+
}

variable "alloydb_pitr_days" {
  description = "Point-in-time recovery retention days"
  type        = number
  default     = 7 # devtest/dev: 7, staging/prod: 14+
}

variable "network_project_id" {
  description = "Project ID for the Shared VPC network"
  type        = string
  default     = "pcc-prj-net-shared"
}

variable "vpc_network_name" {
  description = "VPC network name"
  type        = string
  default     = "pcc-vpc-nonprod"
}

module "alloydb" {
  source = "git::https://github.com/portco-connect/pcc-tf-library.git//modules/alloydb-cluster?ref=main"

  # Project and region
  project_id = "pcc-prj-app-${var.environment}"
  region     = "us-east4"

  # Cluster configuration
  cluster_id           = "pcc-alloydb-${var.environment}"
  cluster_display_name = "PCC AlloyDB Cluster - ${title(var.environment)}"

  # Network configuration (NonProd VPC in pcc-prj-net-shared)
  network_id = "projects/${var.network_project_id}/global/networks/${var.vpc_network_name}"

  # Backup configuration
  automated_backup_policy = {
    enabled                 = true
    backup_window           = "03:00-07:00" # 3-7am EST (low traffic)
    location                = "us-east4"
    retention_count         = 7  # Keep last 7 backups
    retention_period_days   = 30 # 30-day retention policy
    weekly_schedule_enabled = false
    weekly_schedule_days    = []
  }

  continuous_backup_enabled        = true
  continuous_backup_retention_days = var.alloydb_pitr_days

  # Primary instance configuration
  primary_instance_id                = "primary"
  primary_instance_display_name      = "PCC AlloyDB Primary - ${title(var.environment)}"
  primary_instance_machine_type      = var.alloydb_machine_type
  primary_instance_availability_type = var.alloydb_availability_type

  # Read replica (disabled for devtest/dev, enabled for staging/prod)
  enable_read_replica = var.alloydb_enable_read_replica

  # Private Service Connect configuration
  psc_enabled                   = true
  psc_allowed_consumer_projects = ["pcc-prj-app-${var.environment}"]

  # Labels
  cluster_labels = {
    environment = var.environment
    purpose     = "application-database"
    cost_center = "engineering"
    managed_by  = "terraform"
  }
}
```

**Key Configuration**:
- Uses `${var.environment}` for dynamic resource naming
- Single ZONAL instance (~$200/month vs $400+ for REGIONAL)
- db-standard-2 machine type (sufficient for devtest/dev)
- 7-day PITR window (vs 14+ for staging/prod)
- No read replica by default (add for staging/prod)
- Daily backups during 3-7am EST

---

## Step 3: Add Outputs

**File**: `pcc-app-shared-infra/terraform/alloydb.tf`

**Append to existing file**:

```hcl
# Outputs for downstream use (Secret Manager, IAM, Flyway)
output "alloydb_cluster_id" {
  description = "AlloyDB cluster ID"
  value       = module.alloydb.cluster_id
}

output "alloydb_cluster_name" {
  description = "Fully-qualified AlloyDB cluster name"
  value       = module.alloydb.cluster_name
}

output "alloydb_primary_instance_id" {
  description = "Primary instance ID"
  value       = module.alloydb.primary_instance_id
}

output "alloydb_primary_instance_ip" {
  description = "Primary instance IP address (for PSC connection)"
  value       = module.alloydb.primary_instance_ip_address
  sensitive   = false # Not sensitive (private IP)
}

output "alloydb_primary_connection_name" {
  description = "Connection name for primary instance (for Auth Proxy)"
  value       = module.alloydb.primary_instance_connection_name
}

output "alloydb_network_id" {
  description = "VPC network ID used by AlloyDB"
  value       = module.alloydb.network_id
}
```

**Purpose**: These outputs will be used in:
- **Phase 2.6**: Secret Manager secrets (connection string)
- **Phase 2.8**: IAM bindings (cluster/instance names)
- **Phase 2.10**: Flyway configuration (connection info)

---

## Validation Checklist

- [ ] `alloydb.tf` created/updated in pcc-app-shared-infra/terraform/
- [ ] Module source points to pcc-tf-library repo
- [ ] Variables defined: alloydb_availability_type, alloydb_enable_read_replica, alloydb_machine_type, alloydb_pitr_days, network_project_id, vpc_network_name (environment variable will be in variables.tf per Phase 2.6)
- [ ] Project ID uses: `pcc-prj-app-${var.environment}`
- [ ] Cluster ID uses: `pcc-alloydb-${var.environment}`
- [ ] Network configuration uses: `network_id` with variables (not hardcoded)
- [ ] Default availability type: ZONAL (cost-optimized)
- [ ] Default machine type: db-standard-2
- [ ] Default read replica: disabled (enable_read_replica = false)
- [ ] 6 outputs defined
- [ ] No syntax errors (manual review)

---

## Module Call Breakdown

### Environment Variable Usage
```hcl
cluster_id = "pcc-alloydb-${var.environment}"
project_id = "pcc-prj-app-${var.environment}"
```
- Supports multiple environments: devtest, dev, staging, prod
- Resources will be named: pcc-alloydb-devtest, pcc-alloydb-dev, etc.

### Network Reference
```hcl
network_id = "projects/${var.network_project_id}/global/networks/${var.vpc_network_name}"
```
- Network project: `pcc-prj-net-shared` (Shared VPC host) - controlled by `var.network_project_id`
- Network name: `pcc-vpc-nonprod` - controlled by `var.vpc_network_name`
- Format: Full network ID constructed from variables (not hardcoded)
- **Why variables**: Matches existing `alloydb.tf` implementation pattern; enables environment-specific network configuration

### PSC Configuration
```hcl
psc_enabled                   = true
psc_allowed_consumer_projects = ["pcc-prj-app-${var.environment}"]
```
- Enables Private Service Connect
- Allows environment-specific project to connect
- PSC endpoint will be created in Phase 2.10 (Flyway setup)

### Cost Optimization
```hcl
primary_instance_availability_type = "ZONAL"  # 50% cost savings
primary_instance_machine_type      = "db-standard-2"  # Smallest prod-ready size
enable_read_replica                = false  # Additional 50% savings
```

**Total Monthly Cost**: ~$200 (vs $800+ for production HA config)

---

## Environment-Specific Configurations

### Devtest / Dev (Cost-Optimized)
```hcl
environment                 = "devtest" # or "dev"
alloydb_availability_type   = "ZONAL"
alloydb_enable_read_replica = false
alloydb_machine_type        = "db-standard-2"
alloydb_pitr_days          = 7
```
**Cost**: ~$200/month

### Staging (Regional HA)
```hcl
environment                 = "staging"
alloydb_availability_type   = "REGIONAL"
alloydb_enable_read_replica = true
alloydb_machine_type        = "db-standard-4"
alloydb_pitr_days          = 14
```
**Cost**: ~$600/month

### Production (Multi-Region) - Future
Production will use a separate module for PRIMARY + SECONDARY clusters with built-in replication (see ADR-003).

---

## Next Phase Dependencies

**Phase 2.4** will:
- Run terraform fmt, validate, and plan
- Verify configuration is ready to deploy

**Phase 2.5** will create:
- Secret Manager module for storing credentials

**Phase 2.6** will create:
- Secret containing AlloyDB connection string
- Uses `alloydb_primary_instance_ip` output

---

## References

- **Module Source**: `pcc-tf-library/modules/alloydb-cluster/`
- **AlloyDB Pricing**: https://cloud.google.com/alloydb/pricing
- **PSC Setup**: https://cloud.google.com/alloydb/docs/connect-private-service-connect

---

## Time Estimate

- **Check existing file**: 1 minute
- **Create/update alloydb.tf**: 6-8 minutes (module call + variables + configuration)
- **Add outputs**: 3-4 minutes (6 outputs)
- **Total**: 10-12 minutes

---

**Status**: Ready for execution
**Next**: Phase 2.4 - Deploy AlloyDB Infrastructure
