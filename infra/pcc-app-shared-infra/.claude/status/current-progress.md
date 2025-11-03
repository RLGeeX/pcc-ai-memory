# pcc-app-shared-infra - Progress History

This file maintains a comprehensive historical record of all project progress. New session summaries are appended here.

---

## October 25, 2025 - Environment Folder Restructuring

### Task: Restructure Terraform to Environment Folder Pattern (ADR-008)

**Context**: After completing PCC-111 (AlloyDB configuration creation), user identified critical requirement for environment separation to support CI/CD pipelines. Original flat terraform structure with hardcoded backend and single tfvars file would not support multi-environment deployments.

**Decision**: Implement Environment Folder Pattern per ADR-008 with four environments (devtest, dev, staging, prod).

**Implementation**:

1. **Directory Structure Created**:
   ```
   terraform/
   └── environments/
       ├── devtest/ (fully configured, validated)
       ├── dev/ (placeholder)
       ├── staging/ (placeholder)
       └── prod/ (placeholder)
   ```

2. **Backend Configuration** (Unique GCS Prefixes):
   - DevTest: `app-shared-infra/devtest`
   - Dev: `app-shared-infra/dev`
   - Staging: `app-shared-infra/staging`
   - Prod: `app-shared-infra/prod`

3. **Environment-Specific Configurations**:

   **DevTest** (cost-optimized):
   - Project: `pcc-prj-app-devtest`
   - Network: `pcc-vpc-nonprod`
   - AlloyDB: ZONAL, db-standard-2, no read replica, 7-day PITR
   - Cost: ~$400/month

   **Dev** (cost-optimized):
   - Project: `pcc-prj-app-dev`
   - Network: `pcc-vpc-nonprod`
   - AlloyDB: ZONAL, db-standard-2, no read replica, 7-day PITR

   **Staging** (production-like):
   - Project: `pcc-prj-app-staging`
   - Network: `pcc-vpc-nonprod`
   - AlloyDB: REGIONAL, db-standard-4, read replica enabled, 14-day PITR
   - Cost: ~$1200/month

   **Prod** (high availability):
   - Project: `pcc-prj-app-prod`
   - Network: `pcc-vpc-prod`
   - AlloyDB: REGIONAL, db-standard-8, read replica enabled, 30-day PITR
   - Cost: ~$1500+/month

4. **Module Path Update**:
   - Changed from `../../../core/pcc-tf-library/modules/alloydb-cluster`
   - To: `../../../../../core/pcc-tf-library/modules/alloydb-cluster`
   - Accommodates new `environments/devtest/` directory depth

5. **Validation** (DevTest only):
   - ✅ `terraform fmt -check` passed
   - ✅ `terraform init` successful
   - ✅ `terraform validate` passed
   - ✅ Old flat structure files removed

**Benefits Achieved**:
- Complete state isolation (separate GCS prefixes prevent cross-environment corruption)
- Human error prevention (impossible to accidentally apply to wrong environment)
- CI/CD simplicity (just `cd environments/${ENV} && terraform apply`)
- Audit trail (Git history shows exact per-environment changes)
- Industry standard pattern (matches Google Cloud and HashiCorp recommendations)

**References**:
- ADR-008: Terraform Environment Folder Pattern
- ADR-007: Four Environment Architecture
- Template: `core/pcc-tf-library/.claude/quick-reference/terraform-environment-template/`

**Status**: ✅ Complete - Ready for PCC-112 (AlloyDB deployment)

---

## October 25, 2025 - AlloyDB PSC Fix & PCC-112 Completion

### Issue: AlloyDB Instance Creation Failed with VPC Peering Error

**Problem Reported**: User attempted PCC-112 (Deploy AlloyDB Infrastructure) and encountered error: "The AlloyDB cluster was created successfully, but the instance creation failed because the VPC network is not peered with Service Networking."

**Root Cause Analysis**:
- AlloyDB module (`pcc-tf-library/modules/alloydb-cluster`) had hardcoded `network = var.network_id` parameter
- This forced the use of **Private Services Access (PSA)** - the OLD connectivity method
- PSA requires VPC peering with `servicenetworking.googleapis.com`
- User correctly identified that **Private Service Connect (PSC)** does NOT require VPC peering

**Technical Context**:
- **PSA (Private Services Access)** - Legacy method:
  - Cluster requires `network = <vpc-network-id>` parameter
  - Requires `google_compute_global_address` for IP range reservation
  - Requires `google_service_networking_connection` for VPC peering
  - Deprecated for new AlloyDB deployments

- **PSC (Private Service Connect)** - Modern method:
  - Cluster requires `psc_config { psc_enabled = true }` block
  - Cluster must NOT have `network` parameter
  - Instances require `psc_instance_config { allowed_consumer_projects = [...] }`
  - NO VPC peering required
  - NO service networking connection required

**Fix Implementation**:

1. **Updated `pcc-tf-library/modules/alloydb-cluster/main.tf`** (lines 7-21):
   ```hcl
   # Network configuration depends on connectivity method
   # PSC (Private Service Connect): Use psc_config, NO network parameter
   # PSA (Private Services Access): Use network parameter, NO psc_config
   network = var.psc_enabled ? null : var.network_id

   # Private Service Connect configuration (if enabled)
   dynamic "psc_config" {
     for_each = var.psc_enabled ? [1] : []
     content {
       psc_enabled = true
     }
   }
   ```

2. **Updated `pcc-tf-library/modules/alloydb-cluster/instances.tf`** (lines 17-23, 56-62):
   - Added `psc_instance_config` to primary instance
   - Added `psc_instance_config` to read replica instance
   - Both configured with `allowed_consumer_projects = var.psc_allowed_consumer_projects`

3. **Removed Incorrect Files**:
   - Deleted `/home/cfogarty/pcc/core/pcc-foundation-infra/terraform/modules/network/service-networking.tf`
   - Reverted outputs.tf changes in foundation infrastructure

**Validation**:
- ✅ AlloyDB module: `terraform fmt`, `terraform validate` passed
- ✅ app-shared-infra: `terraform init -upgrade` successful
- ✅ app-shared-infra: `terraform validate` passed

**Deployment Result**:
- ✅ **PCC-112 COMPLETED**: User successfully deployed AlloyDB cluster using fixed PSC configuration
- Cluster created with Private Service Connect
- NO VPC peering required
- NO service networking connection required

**Key Learnings**:
1. Always verify connectivity method (PSC vs PSA) before deployment
2. PSC is the modern, recommended approach for AlloyDB
3. PSC simplifies network configuration - no peering, no IP range reservation
4. Module should support both PSC and PSA for backward compatibility
5. Clear documentation in code comments prevents confusion

**Status**: ✅ Fixed and Deployed - Ready for PCC-113 (Secret Manager Module)

---
