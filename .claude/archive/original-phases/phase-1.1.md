# Phase 1.1: Rename Existing DevOps Subnets

**Phase**: 1.1 (Network Infrastructure - Subnet Naming)
**Duration**: 15-20 minutes
**Type**: Planning + Implementation
**Status**: 📋 Planning (Not Started)
**Date**: TBD (10/20+)

---

## Objective

Rename existing DevOps subnets in `pcc-foundation-infra` to match PDF naming convention. This updates both primary subnet names and secondary range names to align with the GCP_Network_Subnets.pdf standard.

## Prerequisites

✅ Phase 0.4 completed (Apigee projects deployed)
✅ `pcc-foundation-infra` repository cloned
✅ GCP_Network_Subnets.pdf reviewed (subnet naming documented)
✅ Gap analysis completed (subnets need renaming)

## Current vs. Required Names

### Production Subnet

**Current Configuration:**
- Primary name: `pcc-subnet-prod-use4`
- Secondary range names:
  - `pcc-subnet-prod-use4-pods`
  - `pcc-subnet-prod-use4-services`

**Required Configuration (from PDF):**
- Primary name: `pcc-prj-devops-prod`
- Secondary range names:
  - `pcc-prj-devops-prod-sub-pod`
  - `pcc-prj-devops-prod-sub-svc`

**CIDR Ranges (NO CHANGE):**
- Primary: `10.16.128.0/20`
- Pods: `10.16.144.0/20`
- Services: `10.16.160.0/20`

### NonProduction Subnet

**Current Configuration:**
- Primary name: `pcc-subnet-nonprod-use4`
- Secondary range names:
  - `pcc-subnet-nonprod-use4-pods`
  - `pcc-subnet-nonprod-use4-services`

**Required Configuration (from PDF):**
- Primary name: `pcc-prj-devops-nonprod`
- Secondary range names:
  - `pcc-prj-devops-nonprod-sub-pod`
  - `pcc-prj-devops-nonprod-sub-svc`

**CIDR Ranges (NO CHANGE):**
- Primary: `10.24.128.0/20`
- Pods: `10.24.144.0/20`
- Services: `10.24.160.0/20`

## Terraform Changes Required

### File Location
`pcc-foundation-infra/terraform/modules/network/subnets.tf`

### Resource Changes

**Production Subnet:**
```hcl
resource "google_compute_subnetwork" "prod_use4" {
  project       = var.network_projects.prod
  name          = "pcc-prj-devops-prod"  # CHANGED: was pcc-subnet-prod-use4
  ip_cidr_range = "10.16.128.0/20"  # NO CHANGE
  region        = var.primary_region
  network       = google_compute_network.prod.id

  description = "Production DevOps subnet - us-east4"

  secondary_ip_range {
    range_name    = "pcc-prj-devops-prod-sub-pod"  # CHANGED
    ip_cidr_range = "10.16.144.0/20"  # NO CHANGE
  }

  secondary_ip_range {
    range_name    = "pcc-prj-devops-prod-sub-svc"  # CHANGED
    ip_cidr_range = "10.16.160.0/20"  # NO CHANGE
  }

  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_10_MIN"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}
```

**NonProduction Subnet:**
```hcl
resource "google_compute_subnetwork" "nonprod_use4" {
  project       = var.network_projects.nonprod
  name          = "pcc-prj-devops-nonprod"  # CHANGED: was pcc-subnet-nonprod-use4
  ip_cidr_range = "10.24.128.0/20"  # NO CHANGE
  region        = var.primary_region
  network       = google_compute_network.nonprod.id

  description = "NonProduction DevOps subnet - us-east4"

  secondary_ip_range {
    range_name    = "pcc-prj-devops-nonprod-sub-pod"  # CHANGED
    ip_cidr_range = "10.24.144.0/20"  # NO CHANGE
  }

  secondary_ip_range {
    range_name    = "pcc-prj-devops-nonprod-sub-svc"  # CHANGED
    ip_cidr_range = "10.24.160.0/20"  # NO CHANGE
  }

  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_10_MIN"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}
```

## Key Configuration Details

### What Changes
- Primary subnet names (2 resources)
- Secondary range names (4 range_name attributes)
- Description text updated for clarity

### What Stays the Same
- CIDR ranges (all IP allocations unchanged)
- Region (us-east4)
- VPC references
- Flow logs configuration
- Private Google Access setting
- All network functionality

## Impact Analysis

### Terraform Behavior
⚠️ **WARNING**: Changing subnet `name` attribute forces resource replacement
- Terraform will **destroy** existing subnets
- Terraform will **recreate** subnets with new names
- **RISK**: Downtime if subnets are in use by existing resources

### Safe Execution
✅ **SAFE CONDITION**: No existing resources currently use these subnets
- DevOps nonprod GKE cluster not yet deployed
- No VMs, Cloud SQL, or other resources using these subnets
- Renaming now avoids future migration pain

## Tasks

1. **Update Terraform Code**:
   - [ ] Edit `subnets.tf` with new primary names
   - [ ] Update all secondary range_name attributes
   - [ ] Update description fields
   - [ ] No CIDR changes required

2. **Validate Changes**:
   - [ ] Run `terraform plan` to preview changes
   - [ ] Verify plan shows 2 resources to replace
   - [ ] Confirm CIDR ranges unchanged
   - [ ] Check no other resources affected

3. **Document Risk**:
   - [ ] Note that replacement will cause brief connectivity loss
   - [ ] Confirm no downstream resources exist yet
   - [ ] Plan for Phase 1.4 validation

## Dependencies

**Upstream**:
- Phase 0.4: Foundation infrastructure deployed
- Gap analysis: Identified naming discrepancy

**Downstream**:
- Phase 1.2: App Devtest subnet creation
- Phase 1.3: PSC subnet creation
- All future phases: Will reference correct subnet names

## Validation Criteria

- [ ] Terraform plan shows exactly 2 resources to replace
- [ ] CIDR ranges match existing (10.16.128.0/20, 10.24.128.0/20)
- [ ] Secondary range names match PDF convention
- [ ] No changes to VPC, flow logs, or other configuration
- [ ] Plan shows no impact to other resources

## Expected Terraform Plan Output

```
Terraform will perform the following actions:

  # google_compute_subnetwork.prod_use4 must be replaced
-/+ resource "google_compute_subnetwork" "prod_use4" {
      ~ name          = "pcc-subnet-prod-use4" -> "pcc-prj-devops-prod" # forces replacement
      # (other attributes unchanged)
    }

  # google_compute_subnetwork.nonprod_use4 must be replaced
-/+ resource "google_compute_subnetwork" "nonprod_use4" {
      ~ name          = "pcc-subnet-nonprod-use4" -> "pcc-prj-devops-nonprod" # forces replacement
      # (other attributes unchanged)
    }

Plan: 2 to add, 0 to change, 2 to destroy.
```

## References

- 📊 Subnet Allocation: `$HOME/pcc/pcc-ai-memory/pcc-foundation-infra/.claude/reference/GCP_Network_Subnets.pdf`
- 📁 Foundation Repo: `pcc-foundation-infra/terraform/modules/network/subnets.tf`
- 🔗 Subnet Docs: https://cloud.google.com/vpc/docs/subnets

## Notes

- **Naming Convention**: PDF uses `pcc-prj-{project}-{purpose}` pattern, no region in name
- **Secondary Ranges**: Pattern is `pcc-prj-{project}-sub-{type}` (pod/svc)
- **Force Replacement**: Name changes trigger destroy+create (acceptable at this stage)
- **No Downtime Risk**: Safe because no resources using these subnets yet
- **Future-Proof**: Aligning to standard now prevents migration later

## Time Estimate

**Planning + Implementation**: 15-20 minutes
- 5 min: Update terraform code (6 name changes)
- 5 min: Run terraform plan and review
- 5 min: Validate no unintended changes
- 5 min: Document findings for Phase 1.4

---

**Next Phase**: 1.2 - Create App Devtest Subnet
