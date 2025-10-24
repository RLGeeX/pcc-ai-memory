# Phase 2.3: Create Module Call in pcc-app-shared-infra

**Phase**: 2.3 (AlloyDB Infrastructure - Module Instantiation)
**Duration**: 15-20 minutes
**Type**: Planning + Configuration
**Status**: 📋 Planning (Not Started)
**Date**: TBD (10/20+)

---

## Objective

Create the module call in `pcc-app-shared-infra` repository to instantiate the AlloyDB cluster module for the devtest environment.

## Prerequisites

✅ Phase 2.2 completed (terraform module created in pcc-tf-library)
✅ `pcc-app-shared-infra` repository cloned
✅ Understanding of module calls and variable passing
✅ PSC network configuration from Phase 1.2

---

## Module Call Location

### Repository Structure

**Repository**: `pcc-app-shared-infra`
**File Location**: `terraform/alloydb.tf` (new file) or `terraform/databases.tf`

**Working Directory**: `~/pcc/infra/pcc-app-shared-infra/terraform/`

---

## Module Call Implementation

### alloydb.tf

```hcl
# AlloyDB Cluster for Devtest Environment
# Module source: pcc-tf-library/modules/alloydb-cluster
# Resources created in: pcc-prj-app-devtest
# PSC Endpoint: Auto-created by AlloyDB cluster (psc_enabled = true)
# Overflow Subnet: pcc-prj-app-devtest-overflow (10.28.48.0/20)
# Connection: Use AlloyDB Auth Proxy or direct PSC DNS from cluster

module "alloydb_cluster_devtest" {
  source = "git::https://github.com/your-org/pcc-tf-library.git//modules/alloydb-cluster?ref=v1.0.0"

  # Project and Location
  project_id = "pcc-prj-app-devtest"
  region     = "us-east4"

  # Cluster Configuration
  cluster_id = "pcc-alloydb-cluster-devtest"

  # Network Configuration
  network_self_link = "projects/pcc-prj-net-shared/global/networks/pcc-vpc-nonprod"

  # Instance Configuration
  primary_instance_id = "pcc-alloydb-instance-devtest-primary"
  replica_instance_id = "pcc-alloydb-instance-devtest-replica"
  cpu_count           = 2

  # Backup and Recovery
  backup_window_start_hour   = 2   # 2 AM EST
  backup_retention_days      = 30  # 30-day retention
  pitr_recovery_window_days  = 7   # 7-day PITR

  # Labels
  labels = {
    environment = "devtest"
    purpose     = "shared-database"
    cost_center = "engineering"
  }
}

# NOTE: PSC endpoints are automatically created by AlloyDB when psc_enabled = true
# No manual google_compute_forwarding_rule needed - AlloyDB handles PSC internally
# Applications connect via AlloyDB Auth Proxy or using the cluster's PSC DNS name

# Outputs for downstream usage
output "alloydb_devtest_cluster_id" {
  description = "AlloyDB devtest cluster ID"
  value       = module.alloydb_cluster_devtest.cluster_id
}

output "alloydb_devtest_primary_ip" {
  description = "AlloyDB devtest primary instance IP address"
  value       = module.alloydb_cluster_devtest.primary_ip_address
}

output "alloydb_devtest_primary_connection_string" {
  description = "AlloyDB devtest primary instance connection string (for Auth Proxy)"
  value       = module.alloydb_cluster_devtest.primary_connection_string
  sensitive   = true
}

output "alloydb_devtest_cluster_name" {
  description = "AlloyDB devtest cluster full resource name"
  value       = module.alloydb_cluster_devtest.cluster_name
}

output "alloydb_devtest_primary_instance_id" {
  description = "AlloyDB devtest primary instance ID"
  value       = module.alloydb_cluster_devtest.primary_instance_id
}

output "alloydb_devtest_primary_instance_name" {
  description = "AlloyDB devtest primary instance full resource name"
  value       = module.alloydb_cluster_devtest.primary_instance_name
}

output "alloydb_devtest_replica_instance_id" {
  description = "AlloyDB devtest replica instance ID (if created)"
  value       = module.alloydb_cluster_devtest.replica_instance_id
}

output "alloydb_devtest_replica_ip" {
  description = "AlloyDB devtest replica instance IP address (if created)"
  value       = module.alloydb_cluster_devtest.replica_ip_address
}

output "alloydb_devtest_psc_dns" {
  description = "AlloyDB devtest PSC DNS name (use with Auth Proxy or direct connection)"
  value       = module.alloydb_cluster_devtest.psc_dns_name
}
```

---

## Configuration Details

### Project Reference

**Target Project**: `pcc-prj-app-devtest`
- AlloyDB cluster will be created in this project
- Workload Identity bindings (Phase 3) will reference this project
- Secret Manager secrets (Phase 2.5) will be created in this project

### Network Reference

**PSC Configuration**:
- **VPC Network**: `pcc-vpc-nonprod` (in `pcc-prj-net-shared`)
- **PSC Auto-Creation**: AlloyDB cluster automatically creates PSC service attachments when `psc_enabled = true`
- **Connection Method**: Use AlloyDB Auth Proxy (recommended) or direct connection via PSC DNS name
- **No Manual Forwarding Rule**: AlloyDB handles PSC internally - no `google_compute_forwarding_rule` needed

### Database Name

**Auto-Created Database**: AlloyDB automatically creates a default `postgres` database upon cluster creation.

**Application Databases**: Additional databases (e.g., `client_api_db_devtest`) will be created via Flyway migrations in Phase 2.7, NOT via Terraform. This is because:
- No `google_alloydb_database` Terraform resource exists
- Database schema management is better handled by migration tools (Flyway)
- Allows for proper versioning and rollback of database changes

**Note**: Phase 2.4 will plan the database schema for Flyway migration scripts.

---

## Variable Configuration

### Module Source

**Git Repository**: `git::https://github.com/your-org/pcc-tf-library.git//modules/alloydb-cluster`
**Ref/Tag**: `?ref=v1.0.0` (use tagged version for stability)

**Alternative** (local development):
```hcl
source = "../../pcc-tf-library/modules/alloydb-cluster"
```

### Sizing Parameters

**CPU Count**: `2` (2 vCPUs per instance)
- Sufficient for devtest workload (pcc-client-api)
- Can scale up for production or additional services

**Memory**: Automatically configured (8 GB for 2 vCPUs)
- Google-managed based on cpu_count

### Backup Parameters

**Backup Window**: `2` (2 AM EST)
- Low-traffic period for devtest
- Daily backups

**Retention**: `30` days
- Meets typical compliance requirements

**PITR Window**: `7` days
- Point-in-time recovery for last 7 days

---

## Tasks (Planning + Configuration)

1. **File Setup**:
   - [ ] Navigate to `pcc-app-shared-infra/terraform/`
   - [ ] Create `alloydb.tf` file
   - [ ] Add module call with parameters

2. **Module Configuration**:
   - [ ] Set project_id: `pcc-prj-app-devtest`

3. **Outputs**:
   - [ ] Define cluster_id output
   - [ ] Define cluster_name output
   - [ ] Define primary_instance_id output
   - [ ] Define primary_instance_name output
   - [ ] Define primary_ip_address output
   - [ ] Define primary_connection_string output (sensitive)
   - [ ] Define replica_instance_id output
   - [ ] Define replica_ip_address output
   - [ ] Define psc_dns_name output

4. **Validation**:
   - [ ] Verify module source reference
   - [ ] Verify all required variables provided
   - [ ] Verify network references correct
   - [ ] Verify database names match service names

---

## Dependencies

**Upstream**:
- Phase 2.2: Terraform module exists in pcc-tf-library
- Phase 1.2: Overflow subnet created (10.28.48.0/20)

**Downstream**:
- Phase 2.4: Database schema planning (for Flyway migrations, not Terraform)
- Phase 2.5: Secret Manager will reference these databases
- Phase 2.7: Flyway migrations will create application databases
- Phase 2.8: Terraform validation will test this module call
- Phase 2.9: Terraform apply will create cluster via this module

---

## Validation Criteria

- [ ] Module call created in `pcc-app-shared-infra/terraform/alloydb.tf`
- [ ] All required variables provided (project_id, cluster_id, network_self_link, primary_instance_id)
- [ ] All 9 module outputs defined
- [ ] Module source references pcc-tf-library
- [ ] Configuration matches Phase 2.1 design
- [ ] PSC configuration relies on AlloyDB auto-creation (no manual forwarding rule)

---

## Deliverables

- [ ] `pcc-app-shared-infra/terraform/alloydb.tf` (module call)
- [ ] 9 module outputs defined (cluster, instances, connection details)
- [ ] Configuration ready for validation (Phase 2.8)

---

## References

- Phase 2.1 (cluster configuration design)
- Phase 2.2 (terraform module)
- 🔗 Terraform Module Calls: https://www.terraform.io/docs/language/modules/syntax.html
- 🔗 AlloyDB PSC Documentation: https://cloud.google.com/alloydb/docs/configure-private-service-connect

---

## Notes

- **Module Source**: Use git ref/tag for version control (`?ref=v1.0.0`)
- **Local Development**: Can use relative path during development (`../../pcc-tf-library/...`)
- **PSC Auto-Creation**: AlloyDB automatically creates PSC service attachments when `psc_enabled = true`
- **No Manual PSC Resources**: AlloyDB handles PSC internally - no manual forwarding rules needed
- **Connection Methods**: Use AlloyDB Auth Proxy (recommended) or direct PSC DNS connection
- **Outputs**: Connection string marked sensitive (contains cluster path)
- **Phase 2.4**: Database schema planning for Flyway migrations (not Terraform resource creation)
- **Phase 2.7**: Flyway will create application databases (e.g., client_api_db_devtest)

---

## Time Estimate

**Planning + Configuration**: 15-20 minutes
- 5 min: Create alloydb.tf file
- 7 min: Configure module call with all parameters
- 5 min: Define 9 module outputs
- 2 min: Verify configuration against Phase 2.1 design

---

**Next Phase**: 2.4 - Plan 1 Database Resource
