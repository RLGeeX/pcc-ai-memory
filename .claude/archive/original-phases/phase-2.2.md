# Phase 2.2: Create AlloyDB Terraform Module

**Phase**: 2.2 (AlloyDB Infrastructure - Module Development)
**Duration**: 25-30 minutes
**Type**: Planning + Development
**Status**: 📋 Planning (Not Started)
**Date**: TBD (10/20+)

---

## Objective

Create a reusable Terraform module for AlloyDB clusters in `pcc-tf-library`, implementing the cluster configuration designed in Phase 2.1.

## Prerequisites

✅ Phase 2.1 completed (cluster configuration designed)
✅ `pcc-tf-library` repository cloned
✅ Understanding of Terraform module patterns
✅ AlloyDB resource documentation reviewed

---

## Module Structure

### File Location

**Repository**: `pcc-tf-library`
**Module Path**: `modules/alloydb-cluster/`

**Files to Create**:
```
pcc-tf-library/
└── modules/
    └── alloydb-cluster/
        ├── main.tf           # Cluster and instances only
        ├── variables.tf      # Module inputs
        ├── outputs.tf        # Module outputs
        ├── versions.tf       # Provider requirements
        └── README.md         # Usage documentation
```

---

## Module Design

### variables.tf

```hcl
variable "project_id" {
  description = "GCP project ID where AlloyDB cluster will be created"
  type        = string
}

variable "cluster_id" {
  description = "AlloyDB cluster identifier"
  type        = string
}

variable "region" {
  description = "GCP region for AlloyDB cluster"
  type        = string
  default     = "us-east4"
}

variable "primary_instance_id" {
  description = "Instance ID for primary instance"
  type        = string
}

variable "replica_instance_id" {
  description = "Instance ID for read replica instance"
  type        = string
  default     = null
}

variable "cpu_count" {
  description = "Number of vCPUs for instances"
  type        = number
  default     = 2
}

variable "backup_window_start_hour" {
  description = "Hour to start automated backups (0-23, EST)"
  type        = number
  default     = 2
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 30
}

variable "pitr_recovery_window_days" {
  description = "Number of days for point-in-time recovery"
  type        = number
  default     = 7
}

variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default     = {}
}

variable "network_self_link" {
  description = "VPC network self link for AlloyDB cluster (e.g., projects/pcc-prj-net-shared/global/networks/pcc-vpc-nonprod)"
  type        = string
}
```

---

### main.tf

```hcl
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# AlloyDB Cluster
resource "google_alloydb_cluster" "cluster" {
  cluster_id = var.cluster_id
  location   = var.region
  project    = var.project_id

  # Network configuration (required for private IP access)
  network_config {
    network = var.network_self_link
  }

  psc_config {
    psc_enabled = true
  }

  # Note: Cluster creates a service attachment automatically
  # PSC endpoint (forwarding rule) created in Phase 2.3 references this service attachment

  automated_backup_policy {
    enabled = true

    backup_window {
      start_times {
        hours   = var.backup_window_start_hour
        minutes = 0
      }
    }

    quantity_based_retention {
      count = var.backup_retention_days
    }

    weekly_schedule {
      days_of_week = ["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY", "SUNDAY"]
    }
  }

  continuous_backup_config {
    enabled              = true
    recovery_window_days = var.pitr_recovery_window_days
  }

  labels = merge(
    var.labels,
    {
      managed_by = "terraform"
    }
  )
}

# Primary Instance
resource "google_alloydb_instance" "primary" {
  cluster       = google_alloydb_cluster.cluster.name
  instance_id   = var.primary_instance_id
  instance_type = "PRIMARY"

  machine_config {
    cpu_count = var.cpu_count
  }

  availability_type = "REGIONAL"

  database_flags = {
    "max_connections" = "500"
  }

  labels = merge(
    var.labels,
    {
      managed_by = "terraform"
      role       = "primary"
    }
  )

  depends_on = [google_alloydb_cluster.cluster]
}

# Read Replica Instance (Optional)
resource "google_alloydb_instance" "replica" {
  count = var.replica_instance_id != null ? 1 : 0

  cluster       = google_alloydb_cluster.cluster.name
  instance_id   = var.replica_instance_id
  instance_type = "READ_POOL"

  machine_config {
    cpu_count = var.cpu_count
  }

  read_pool_config {
    node_count = 1
  }

  labels = merge(
    var.labels,
    {
      managed_by = "terraform"
      role       = "replica"
    }
  )

  depends_on = [google_alloydb_instance.primary]
}
```

**Note on Database Creation**:
- AlloyDB automatically creates a default `postgres` database when the cluster is provisioned
- Additional databases (e.g., `client_api_db_devtest`) are created by **Flyway migrations**, not Terraform
- Terraform does NOT have a `google_alloydb_database` resource to create databases

---

### outputs.tf

```hcl
output "cluster_id" {
  description = "AlloyDB cluster ID"
  value       = google_alloydb_cluster.cluster.cluster_id
}

output "cluster_name" {
  description = "AlloyDB cluster full resource name"
  value       = google_alloydb_cluster.cluster.name
}

output "primary_instance_id" {
  description = "Primary instance ID"
  value       = google_alloydb_instance.primary.instance_id
}

output "primary_instance_name" {
  description = "Primary instance full resource name"
  value       = google_alloydb_instance.primary.name
}

output "primary_ip_address" {
  description = "Primary instance internal IP address (not for direct connection - use PSC endpoint IP instead)"
  value       = google_alloydb_instance.primary.ip_address
}

output "primary_connection_string" {
  description = "Primary instance connection string (for AlloyDB Auth Proxy only, not direct JDBC)"
  value       = "projects/${var.project_id}/locations/${var.region}/clusters/${var.cluster_id}/instances/${var.primary_instance_id}"
}

output "replica_instance_id" {
  description = "Replica instance ID (if created)"
  value       = var.replica_instance_id != null ? google_alloydb_instance.replica[0].instance_id : null
}

output "replica_ip_address" {
  description = "Replica instance internal IP address (not for direct connection - use PSC endpoint IP instead)"
  value       = var.replica_instance_id != null ? google_alloydb_instance.replica[0].ip_address : null
}

output "psc_dns_name" {
  description = "PSC DNS name for AlloyDB cluster (auto-generated by AlloyDB)"
  value       = google_alloydb_cluster.cluster.psc_config[0].psc_dns_name
}
```

**Note on PSC Connection Methods**:
- **Recommended**: Use AlloyDB Auth Proxy in GKE pods (handles PSC internally)
- **PSC Auto-Creation**: AlloyDB automatically creates PSC service attachments when `psc_enabled = true`
- **No Manual Forwarding Rules**: AlloyDB handles PSC internally - no manual `google_compute_forwarding_rule` needed
- **Important**: `primary_ip_address` output is the instance's internal IP, NOT for direct connections
- **For Connections**: Applications should use AlloyDB Auth Proxy (recommended) or direct connection via PSC DNS name


---

### versions.tf

```hcl
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}
```

---

### README.md

````markdown
# AlloyDB Cluster Module

Terraform module for creating a managed AlloyDB cluster with high availability, automated backups, and point-in-time recovery.

## Features

- **High Availability**: Regional multi-zone deployment with automatic failover
- **Automated Backups**: Daily backups with configurable retention
- **Point-in-Time Recovery**: Continuous backup with 7-day recovery window (configurable)
- **Private Connectivity**: PSC-based private IP addresses
- **Read Replicas**: Optional read-only replica instances

## Usage

```hcl
module "alloydb_cluster" {
  source = "git::https://github.com/your-org/pcc-tf-library.git//modules/alloydb-cluster?ref=v1.0.0"

  project_id = "pcc-prj-app-devtest"
  cluster_id = "pcc-alloydb-cluster-devtest"
  region     = "us-east4"

  network_self_link = "projects/pcc-prj-net-shared/global/networks/pcc-vpc-nonprod"

  primary_instance_id = "pcc-alloydb-instance-devtest-primary"
  replica_instance_id = "pcc-alloydb-instance-devtest-replica"

  cpu_count = 2

  labels = {
    environment = "devtest"
    purpose     = "shared-database"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project_id | GCP project ID | string | - | yes |
| cluster_id | AlloyDB cluster identifier | string | - | yes |
| region | GCP region | string | "us-east4" | no |
| primary_instance_id | Primary instance ID | string | - | yes |
| replica_instance_id | Replica instance ID | string | null | no |
| cpu_count | Number of vCPUs | number | 2 | no |
| backup_retention_days | Backup retention days | number | 30 | no |
| pitr_recovery_window_days | PITR recovery window days | number | 7 | no |
| labels | Resource labels | map(string) | {} | no |
| network_self_link | VPC network self link | string | - | yes |

## Outputs

| Name | Description |
|------|-------------|
| cluster_id | AlloyDB cluster ID |
| cluster_name | AlloyDB cluster full resource name |
| primary_instance_id | Primary instance ID |
| primary_ip_address | Primary instance IP address (internal, not for direct connection) |
| primary_connection_string | Primary instance connection string (for Auth Proxy) |
| replica_ip_address | Replica instance IP address (if created) |
| psc_dns_name | PSC DNS name (auto-generated by AlloyDB for connections) |

## Requirements

- Terraform >= 1.6.0
- Google Provider ~> 5.0
- VPC network configured (pcc-vpc-nonprod in pcc-prj-net-shared)
- AlloyDB API must be enabled

## Notes

- Primary instance deployed with REGIONAL availability (multi-zone HA)
- Automated backups run daily at configured hour
- PITR provides second-level recovery granularity
- Default `postgres` database auto-created; additional databases created via Flyway (Phase 2.7)
````

---

## Tasks (Planning + Development)

1. **Module Structure**:
   - [ ] Create module directory: `pcc-tf-library/modules/alloydb-cluster/`
   - [ ] Create main.tf (cluster and instances resources)
   - [ ] Create variables.tf (module inputs)
   - [ ] Create outputs.tf (module outputs)
   - [ ] Create versions.tf (provider requirements)
   - [ ] Create README.md (usage documentation)

2. **Resource Implementation**:
   - [ ] Implement `google_alloydb_cluster` resource
   - [ ] Implement `google_alloydb_instance` (primary)
   - [ ] Implement `google_alloydb_instance` (replica, optional)

3. **Module Features**:
   - [ ] Support configurable sizing (cpu_count)
   - [ ] Support configurable backups (retention, window)
   - [ ] Support configurable PITR (recovery window)
   - [ ] Support optional replica instance

4. **Documentation**:
   - [ ] Document all input variables
   - [ ] Document all output values
   - [ ] Provide usage example
   - [ ] Document requirements and prerequisites

---

## Dependencies

**Upstream**:
- Phase 2.1: Cluster configuration designed
- `pcc-tf-library` repository structure

**Downstream**:
- Phase 2.3: Module will be called from pcc-app-shared-infra
- Phase 2.7: Flyway will create databases via SQL migrations

---

## Validation Criteria

- [ ] Module directory created
- [ ] All 5 files created (main.tf, variables.tf, outputs.tf, versions.tf, README.md)
- [ ] Cluster resource defined
- [ ] Primary instance resource defined
- [ ] Replica instance resource defined (optional)
- [ ] All variables documented
- [ ] All outputs documented
- [ ] README.md provides clear usage example

---

## Deliverables

- [ ] `pcc-tf-library/modules/alloydb-cluster/main.tf`
- [ ] `pcc-tf-library/modules/alloydb-cluster/variables.tf`
- [ ] `pcc-tf-library/modules/alloydb-cluster/outputs.tf`
- [ ] `pcc-tf-library/modules/alloydb-cluster/versions.tf`
- [ ] `pcc-tf-library/modules/alloydb-cluster/README.md`
- [ ] Module ready for use in Phase 2.3

---

## References

- Phase 2.1 (cluster configuration design)
- 🔗 Terraform Module Best Practices: https://www.terraform.io/docs/language/modules/develop/index.html
- 🔗 AlloyDB Terraform Resources: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/alloydb_cluster
- 🔗 AlloyDB Instance: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/alloydb_instance

---

## Notes

- **Module Location**: `pcc-tf-library/modules/alloydb-cluster/` (reusable across environments)
- **Database Creation**: Terraform creates cluster/instances only. AlloyDB auto-creates default `postgres` database. Additional databases created by Flyway (Phase 2.7)
- **No `google_alloydb_database` Resource**: This Terraform resource does not exist in the Google provider
- **Replica**: Optional via `count` pattern (can deploy cluster without replica)
- **HA**: PRIMARY instance with REGIONAL availability provides multi-zone HA
- **Outputs**: Provide connection strings and IP addresses for Phase 2.7 (Auth Proxy setup)

---

## Time Estimate

**Planning + Development**: 25-30 minutes
- 10 min: Create module directory structure and files
- 10 min: Implement resources (cluster, instances, databases)
- 5 min: Define variables and outputs
- 5 min: Write README.md with usage example

---

**Next Phase**: 2.3 - Create Module Call in pcc-app-shared-infra
