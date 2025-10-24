# Phase 2.1: Create AlloyDB Module Skeleton

**Phase**: 2.1 (AlloyDB Infrastructure - Module Foundation)
**Duration**: 20-30 minutes
**Type**: Implementation
**Status**: Ready for Execution

---

## Execution Tool

**Use Claude Code for this phase** - Creating terraform module files only, no CLI commands.

---

## Objective

Create reusable AlloyDB module structure in `pcc-tf-library` with variables, outputs, and basic cluster configuration. This provides the foundation for Phase 2.2 (instance configuration).

## Prerequisites

✅ Phase 0 completed (APIs enabled)
✅ Phase 1 completed (network subnets deployed)
✅ `pcc-tf-library` repository cloned
✅ Access to create new module directory

---

## Module Structure

**Location**: `pcc-tf-library/modules/alloydb-cluster/`

**Files to Create**:
1. `versions.tf` - Provider requirements
2. `variables.tf` - Input parameters
3. `outputs.tf` - Exported values
4. `main.tf` - Cluster resource (skeleton only)

---

## Step 1: Create Module Directory

```bash
cd ~/pcc/core/pcc-tf-library
mkdir -p modules/alloydb-cluster
cd modules/alloydb-cluster
```

---

## Step 2: Create versions.tf

**File**: `pcc-tf-library/modules/alloydb-cluster/versions.tf`

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

**Purpose**: Pin terraform and provider versions for stability

---

## Step 3: Create variables.tf

**File**: `pcc-tf-library/modules/alloydb-cluster/variables.tf`

```hcl
variable "project_id" {
  description = "GCP project ID where AlloyDB cluster will be created"
  type        = string
}

variable "cluster_id" {
  description = "Unique identifier for the AlloyDB cluster"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,62}$", var.cluster_id))
    error_message = "Cluster ID must start with lowercase letter, contain only lowercase letters, numbers, hyphens, max 63 chars"
  }
}

variable "region" {
  description = "GCP region for the AlloyDB cluster"
  type        = string
  default     = "us-east4"
}

variable "network_id" {
  description = "Full VPC network ID (projects/{project}/global/networks/{name})"
  type        = string
}

variable "cluster_labels" {
  description = "Labels to apply to the AlloyDB cluster"
  type        = map(string)
  default     = {}
}

variable "cluster_display_name" {
  description = "Human-readable name for the cluster"
  type        = string
  default     = ""
}

variable "automated_backup_policy" {
  description = "Automated backup configuration"
  type = object({
    enabled                 = bool
    backup_window           = string # 4-hour window, e.g., "03:00-07:00"
    location                = string # Backup storage location
    retention_count         = number # Number of backups to retain
    retention_period_days   = number # Days to retain backups
    weekly_schedule_enabled = bool
    weekly_schedule_days    = list(string) # e.g., ["MONDAY", "WEDNESDAY", "FRIDAY"]
  })
  default = {
    enabled                 = true
    backup_window           = "03:00-07:00"
    location                = "us-east4"
    retention_count         = 7
    retention_period_days   = 30
    weekly_schedule_enabled = false
    weekly_schedule_days    = []
  }
}

variable "continuous_backup_enabled" {
  description = "Enable continuous backup for point-in-time recovery (PITR)"
  type        = bool
  default     = true
}

variable "continuous_backup_retention_days" {
  description = "Number of days to retain continuous backups (1-35)"
  type        = number
  default     = 7

  validation {
    condition     = var.continuous_backup_retention_days >= 1 && var.continuous_backup_retention_days <= 35
    error_message = "Retention days must be between 1 and 35"
  }
}

variable "encryption_config" {
  description = "Customer-managed encryption key configuration (optional)"
  type = object({
    kms_key_name = string
  })
  default = null
}
```

**Key Decisions**:
- Backup window defaults to 3-7am (low traffic)
- 30-day backup retention (standard)
- 7-day PITR window (cost-optimized for devtest)
- CMEK optional (can add later for production)

---

## Step 4: Create outputs.tf

**File**: `pcc-tf-library/modules/alloydb-cluster/outputs.tf`

```hcl
output "cluster_id" {
  description = "The ID of the AlloyDB cluster"
  value       = google_alloydb_cluster.cluster.cluster_id
}

output "cluster_name" {
  description = "The fully-qualified name of the AlloyDB cluster"
  value       = google_alloydb_cluster.cluster.name
}

output "cluster_uid" {
  description = "The system-generated UID of the cluster"
  value       = google_alloydb_cluster.cluster.uid
}

output "network_id" {
  description = "The VPC network associated with the cluster"
  value       = google_alloydb_cluster.cluster.network
}

output "automated_backup_policy" {
  description = "The automated backup policy configuration"
  value       = google_alloydb_cluster.cluster.automated_backup_policy
}

output "continuous_backup_config" {
  description = "The continuous backup configuration"
  value       = google_alloydb_cluster.cluster.continuous_backup_config
}

output "encryption_config" {
  description = "The encryption configuration (if CMEK enabled)"
  value       = google_alloydb_cluster.cluster.encryption_config
}
```

**Purpose**: Expose cluster metadata for use in Phase 2.2 (instances) and downstream modules

---

## Step 5: Create main.tf (Skeleton)

**File**: `pcc-tf-library/modules/alloydb-cluster/main.tf`

```hcl
# AlloyDB Cluster
# Note: Instances are added in Phase 2.2 via separate instance resources
resource "google_alloydb_cluster" "cluster" {
  cluster_id   = var.cluster_id
  project      = var.project_id
  location     = var.region
  network      = var.network_id
  display_name = var.cluster_display_name != "" ? var.cluster_display_name : var.cluster_id

  labels = merge(
    var.cluster_labels,
    {
      managed_by = "terraform"
    }
  )

  # Automated daily backups
  automated_backup_policy {
    enabled = var.automated_backup_policy.enabled
    location = var.automated_backup_policy.location

    backup_window = var.automated_backup_policy.backup_window

    quantity_based_retention {
      count = var.automated_backup_policy.retention_count
    }

    time_based_retention {
      retention_period = "${var.automated_backup_policy.retention_period_days}d"
    }

    dynamic "weekly_schedule" {
      for_each = var.automated_backup_policy.weekly_schedule_enabled ? [1] : []
      content {
        days_of_week = var.automated_backup_policy.weekly_schedule_days
      }
    }

    labels = {
      backup_type = "automated"
      cluster_id  = var.cluster_id
    }
  }

  # Continuous backup for PITR (7-day window for devtest)
  continuous_backup_config {
    enabled              = var.continuous_backup_enabled
    recovery_window_days = var.continuous_backup_retention_days
  }

  # Optional: Customer-managed encryption
  dynamic "encryption_config" {
    for_each = var.encryption_config != null ? [var.encryption_config] : []
    content {
      kms_key_name = encryption_config.value.kms_key_name
    }
  }
}
```

**Key Features**:
- Daily automated backups (3-7am)
- 30-day retention (quantity + time-based)
- PITR enabled (7-day window)
- Optional weekly backup schedule
- Optional CMEK encryption
- Managed by terraform label

**What's Missing**:
- ❌ AlloyDB instances (added in Phase 2.2)
- ❌ Database creation (handled by Flyway in Phase 2.7)
- ❌ IAM bindings (added in Phase 2.6)

---

## Validation Checklist

- [ ] Directory created: `pcc-tf-library/modules/alloydb-cluster/`
- [ ] `versions.tf` created with provider ~> 5.0
- [ ] `variables.tf` created with 11 input variables
- [ ] `outputs.tf` created with 7 outputs
- [ ] `main.tf` created with cluster resource only
- [ ] All files use 2-space indentation
- [ ] No syntax errors (manual review)

---

## Module Interface

**Inputs**:
- `project_id` (required)
- `cluster_id` (required)
- `region` (default: us-east4)
- `network_id` (required - VPC network)
- `cluster_labels` (optional)
- `cluster_display_name` (optional)
- `automated_backup_policy` (object with defaults)
- `continuous_backup_enabled` (default: true)
- `continuous_backup_retention_days` (default: 7)
- `encryption_config` (optional CMEK)

**Outputs**:
- `cluster_id` - For instance resources
- `cluster_name` - For IAM bindings
- `cluster_uid` - For monitoring
- `network_id` - For PSC setup
- `automated_backup_policy` - For verification
- `continuous_backup_config` - For PITR validation
- `encryption_config` - For security audits

---

## Next Phase Dependencies

**Phase 2.2** will add:
- `google_alloydb_instance` resource (primary)
- Optional read replica instance (for production)
- Machine type configuration
- Availability type (REGIONAL for prod, ZONAL for devtest)

**Phase 2.3** will call this module from:
- `pcc-app-shared-infra/terraform/alloydb.tf`

---

## References

- **Google Provider**: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/alloydb_cluster
- **AlloyDB Backups**: https://cloud.google.com/alloydb/docs/backup-restore
- **PITR**: https://cloud.google.com/alloydb/docs/backup-restore/pitr

---

## Cost Optimization Notes

**Devtest Configuration**:
- 7-day PITR window (vs 14-35 for production)
- Daily backups only (no weekly schedule)
- 30-day retention (balance recovery vs cost)

**Estimated Backup Storage Cost**:
- ~$0.10/GB/month for backup storage
- Typical devtest database: 10-50 GB
- Monthly backup cost: $1-5 (negligible)

---

## Time Estimate

- **Create directory**: 1 minute
- **Create versions.tf**: 2 minutes
- **Create variables.tf**: 8-10 minutes (11 variables with validation)
- **Create outputs.tf**: 5 minutes (7 outputs)
- **Create main.tf**: 8-10 minutes (cluster resource with dynamic blocks)
- **Review/validate**: 5 minutes
- **Total**: 20-30 minutes

---

**Status**: Ready for execution
**Next**: Phase 2.2 - Implement AlloyDB Instances
