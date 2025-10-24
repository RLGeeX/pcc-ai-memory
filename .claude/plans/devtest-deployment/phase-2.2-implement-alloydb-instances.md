# Phase 2.2: Implement AlloyDB Instances

**Phase**: 2.2 (AlloyDB Infrastructure - Instance Configuration)
**Duration**: 25-35 minutes
**Type**: Implementation
**Status**: Ready for Execution

---

## Execution Tool

**Use Claude Code for this phase** - Adding terraform configuration to existing module, no CLI commands.

---

## Objective

Add AlloyDB instance resources to the module created in Phase 2.1. Configure cost-optimized single primary instance for devtest with proper machine type and availability settings.

## Prerequisites

✅ Phase 2.1 completed (module skeleton created)
✅ `pcc-tf-library/modules/alloydb-cluster/` directory exists
✅ Cluster resource defined in main.tf

---

## Configuration Strategy

**Devtest (Cost-Optimized)**:
- ✅ Single primary instance (ZONAL)
- ✅ Machine type: `db-standard-2` (2 vCPU, 16 GB RAM)
- ❌ NO read replica
- ❌ NO high availability (REGIONAL)

**Production (Future)**:
- Primary instance (REGIONAL)
- Read replica for load distribution
- Machine type: `db-standard-4` or higher

**Cost Impact**:
- Devtest: ~$200/month (single ZONAL instance)
- Production: ~$600-800/month (REGIONAL + replica)

---

## Step 1: Add Instance Variables

**File**: `pcc-tf-library/modules/alloydb-cluster/variables.tf`

**Append to existing file**:

```hcl
# Primary Instance Configuration
variable "primary_instance_id" {
  description = "Instance ID for the primary AlloyDB instance"
  type        = string
  default     = "primary"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,62}$", var.primary_instance_id))
    error_message = "Instance ID must start with lowercase letter, contain only lowercase letters, numbers, hyphens, max 63 chars"
  }
}

variable "primary_instance_display_name" {
  description = "Human-readable name for the primary instance"
  type        = string
  default     = ""
}

variable "primary_instance_machine_type" {
  description = "Machine type for primary instance (e.g., db-standard-2, db-standard-4)"
  type        = string
  default     = "db-standard-2" # 2 vCPU, 16 GB RAM - cost-optimized for devtest
}

variable "primary_instance_availability_type" {
  description = "Availability type: ZONAL (cost-optimized) or REGIONAL (HA)"
  type        = string
  default     = "ZONAL"

  validation {
    condition     = contains(["ZONAL", "REGIONAL"], var.primary_instance_availability_type)
    error_message = "Availability type must be ZONAL or REGIONAL"
  }
}

variable "primary_instance_database_flags" {
  description = "Database flags for primary instance"
  type        = map(string)
  default     = {}
}

variable "enable_read_replica" {
  description = "Enable read replica instance (production only, adds cost)"
  type        = bool
  default     = false
}

variable "read_replica_instance_id" {
  description = "Instance ID for read replica (if enabled)"
  type        = string
  default     = "read-replica"
}

variable "read_replica_machine_type" {
  description = "Machine type for read replica"
  type        = string
  default     = "db-standard-2"
}

variable "psc_enabled" {
  description = "Enable Private Service Connect for AlloyDB access"
  type        = bool
  default     = true
}

variable "psc_allowed_consumer_projects" {
  description = "List of project IDs allowed to connect via PSC"
  type        = list(string)
  default     = []
}
```

---

## Step 2: Create instances.tf

**File**: `pcc-tf-library/modules/alloydb-cluster/instances.tf`

```hcl
# Primary AlloyDB Instance
resource "google_alloydb_instance" "primary" {
  cluster       = google_alloydb_cluster.cluster.name
  instance_id   = var.primary_instance_id
  instance_type = "PRIMARY"
  display_name  = var.primary_instance_display_name != "" ? var.primary_instance_display_name : "${var.cluster_id}-${var.primary_instance_id}"

  machine_config {
    cpu_count = tonumber(regex("db-standard-(\\d+)", var.primary_instance_machine_type)[0])
  }

  availability_type = var.primary_instance_availability_type

  # Database flags (PostgreSQL configuration)
  dynamic "database_flags" {
    for_each = var.primary_instance_database_flags
    content {
      name  = database_flags.key
      value = database_flags.value
    }
  }

  labels = merge(
    var.cluster_labels,
    {
      instance_type = "primary"
      managed_by    = "terraform"
    }
  )

  depends_on = [google_alloydb_cluster.cluster]
}

# Read Replica Instance (Optional - Production Only)
resource "google_alloydb_instance" "read_replica" {
  count = var.enable_read_replica ? 1 : 0

  cluster       = google_alloydb_cluster.cluster.name
  instance_id   = var.read_replica_instance_id
  instance_type = "READ_POOL"
  display_name  = "${var.cluster_id}-${var.read_replica_instance_id}"

  machine_config {
    cpu_count = tonumber(regex("db-standard-(\\d+)", var.read_replica_machine_type)[0])
  }

  # Read replicas automatically match primary availability
  availability_type = var.primary_instance_availability_type

  read_pool_config {
    node_count = 1
  }

  labels = merge(
    var.cluster_labels,
    {
      instance_type = "read-replica"
      managed_by    = "terraform"
    }
  )

  depends_on = [
    google_alloydb_instance.primary
  ]
}
```

**Key Features**:
- Primary instance with configurable machine type
- CPU count derived from machine type string
- ZONAL availability for devtest (cost-optimized)
- Read replica optional (disabled for devtest)
- Labels distinguish instance types

---

## Step 3: Add Instance Outputs

**File**: `pcc-tf-library/modules/alloydb-cluster/outputs.tf`

**Append to existing file**:

```hcl
# Primary Instance Outputs
output "primary_instance_id" {
  description = "The ID of the primary AlloyDB instance"
  value       = google_alloydb_instance.primary.instance_id
}

output "primary_instance_name" {
  description = "The fully-qualified name of the primary instance"
  value       = google_alloydb_instance.primary.name
}

output "primary_instance_ip_address" {
  description = "The IP address of the primary instance (for PSC connection)"
  value       = google_alloydb_instance.primary.ip_address
}

output "primary_instance_state" {
  description = "The state of the primary instance"
  value       = google_alloydb_instance.primary.state
}

output "primary_instance_connection_name" {
  description = "Connection name for primary instance (format: project:region:cluster:instance)"
  value       = "${var.project_id}:${var.region}:${var.cluster_id}:${var.primary_instance_id}"
}

# Read Replica Outputs (Optional)
output "read_replica_instance_id" {
  description = "The ID of the read replica instance (if enabled)"
  value       = var.enable_read_replica ? google_alloydb_instance.read_replica[0].instance_id : null
}

output "read_replica_instance_name" {
  description = "The fully-qualified name of the read replica (if enabled)"
  value       = var.enable_read_replica ? google_alloydb_instance.read_replica[0].name : null
}

output "read_replica_ip_address" {
  description = "The IP address of the read replica (if enabled)"
  value       = var.enable_read_replica ? google_alloydb_instance.read_replica[0].ip_address : null
}
```

---

## Step 4: Update Module README (Optional)

**File**: `pcc-tf-library/modules/alloydb-cluster/README.md` (create if doesn't exist)

```markdown
# AlloyDB Cluster Module

Terraform module for deploying AlloyDB clusters with configurable instances.

## Features

- Automated daily backups (30-day retention)
- Point-in-time recovery (PITR) with 7-day window
- Configurable machine types and availability
- Optional read replicas for production
- Private Service Connect support

## Usage

```hcl
module "alloydb" {
  source = "../../modules/alloydb-cluster"

  project_id  = "pcc-prj-app-devtest"
  cluster_id  = "pcc-alloydb-devtest"
  region      = "us-east4"
  network_id  = "projects/pcc-prj-net-shared/global/networks/pcc-vpc-nonprod"

  # Cost-optimized for devtest
  primary_instance_availability_type = "ZONAL"
  primary_instance_machine_type      = "db-standard-2"
  enable_read_replica                = false

  cluster_labels = {
    environment = "devtest"
    purpose     = "application-database"
  }
}
```

## Inputs

See `variables.tf` for full list.

## Outputs

See `outputs.tf` for full list.
```

---

## Validation Checklist

- [ ] `variables.tf` updated with 11 new instance variables
- [ ] `instances.tf` created with primary instance resource
- [ ] `instances.tf` includes optional read replica (disabled by default)
- [ ] `outputs.tf` updated with 8 instance-related outputs
- [ ] Primary instance uses ZONAL availability
- [ ] Machine type defaults to db-standard-2
- [ ] Read replica disabled by default (enable_read_replica = false)
- [ ] CPU count derived from machine type string
- [ ] No syntax errors (manual review)

---

## Machine Type Options

| Machine Type | vCPU | RAM | Use Case | Monthly Cost (ZONAL) |
|--------------|------|-----|----------|----------------------|
| db-standard-2 | 2 | 16 GB | Devtest | ~$200 |
| db-standard-4 | 4 | 32 GB | Small prod | ~$400 |
| db-standard-8 | 8 | 64 GB | Medium prod | ~$800 |
| db-standard-16 | 16 | 128 GB | Large prod | ~$1,600 |

**Recommendation**: Use `db-standard-2` for devtest, `db-standard-4+` for production

---

## Availability Types

| Type | Description | Use Case | Cost |
|------|-------------|----------|------|
| ZONAL | Single zone | Devtest, cost-sensitive | 1× |
| REGIONAL | Multi-zone HA | Production, high availability | 2× |

**Devtest Choice**: ZONAL (acceptable RTO/RPO, 50% cost savings)

---

## Database Flags (Optional)

Common PostgreSQL flags for AlloyDB:

```hcl
primary_instance_database_flags = {
  "max_connections"           = "200"
  "shared_buffers"            = "4096MB"
  "work_mem"                  = "64MB"
  "maintenance_work_mem"      = "512MB"
  "effective_cache_size"      = "12GB"
  "log_statement"             = "all" # For debugging (disable in prod)
  "log_min_duration_statement" = "1000" # Log queries > 1s
}
```

**Note**: AlloyDB has optimized defaults; only set flags if needed

---

## Next Phase Dependencies

**Phase 2.3** will:
- Call this module from `pcc-app-shared-infra/terraform/alloydb.tf`
- Pass network, project, and configuration parameters

**Phase 2.6** will:
- Add IAM bindings for database access
- Grant roles to service accounts and groups

**Phase 2.7** will:
- Use `primary_instance_ip_address` for connection string
- Configure Auth Proxy to connect via PSC

---

## Troubleshooting

### Issue: "Invalid machine_config"
**Resolution**: Ensure machine type follows `db-standard-N` format
```bash
# Valid: db-standard-2, db-standard-4, db-standard-8
# Invalid: standard-2, db-highmem-2
```

### Issue: "cpu_count derivation fails"
**Resolution**: Verify regex matches machine type
```hcl
# Test regex locally
tonumber(regex("db-standard-(\\d+)", "db-standard-2")[0]) # Returns 2
```

---

## References

- **AlloyDB Instances**: https://cloud.google.com/alloydb/docs/instance-primary
- **Machine Types**: https://cloud.google.com/alloydb/pricing#machine_type
- **Availability Types**: https://cloud.google.com/alloydb/docs/instance-high-availability

---

## Time Estimate

- **Add variables**: 8-10 minutes (11 new variables)
- **Create instances.tf**: 12-15 minutes (primary + optional replica)
- **Add outputs**: 6-8 minutes (8 outputs)
- **Create/update README**: 3-5 minutes
- **Review/validate**: 3-5 minutes
- **Total**: 25-35 minutes

---

**Status**: Ready for execution
**Next**: Phase 2.3 - Implement Module Call in pcc-app-shared-infra
