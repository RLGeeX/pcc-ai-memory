# Phase 1.3: Validate Terraform Configuration

**Phase**: 1.3 (Network Infrastructure - Validation)
**Duration**: 10-15 minutes
**Type**: Validation
**Status**: 📋 Planning (Not Started)
**Date**: TBD (10/20+)

---

## Objective

Execute terraform validation commands to verify correctness of network infrastructure changes: 2 renamed DevOps subnets + 2 new subnets (App Devtest main + Overflow) before deployment.

## Prerequisites

✅ Phase 1.1 completed (DevOps subnet names updated in terraform)
✅ Phase 1.2 completed (App Devtest subnets added to terraform)
✅ Terraform code updated in `pcc-foundation-infra`
✅ Terraform CLI available (`terraform --version`)

---

## Expected Changes Summary

### Resources to Replace (2)
1. Production DevOps subnet: `pcc-subnet-prod-use4` → `pcc-prj-devops-prod`
2. NonProduction DevOps subnet: `pcc-subnet-nonprod-use4` → `pcc-prj-devops-nonprod`

### Resources to Add (2)
3. App Devtest subnet: `pcc-prj-app-devtest` (10.28.0.0/20)
4. App Devtest overflow subnet: `pcc-prj-app-devtest-overflow` (10.28.48.0/20)

**Total Plan**: 4 to add, 0 to change, 2 to destroy

---

## Validation Steps

### Step 1: Navigate to Terraform Directory

```bash
cd ~/pcc/core/pcc-foundation-infra/terraform
```

---

### Step 2: Format Check

```bash
terraform fmt -check
```

**Expected Result**: No formatting issues

**If issues found**:
```bash
terraform fmt
```

**Purpose**: Ensures code follows HCL formatting standards

---

### Step 3: Initialize Terraform (if needed)

```bash
terraform init
```

**Expected Output**:
```
Terraform has been successfully initialized!
```

**Purpose**: Downloads provider plugins, initializes backend

---

### Step 4: Syntax Validation

```bash
terraform validate
```

**Expected Output**:
```
Success! The configuration is valid.
```

**Purpose**: Catches syntax errors, missing variables, invalid resource types

**Common Issues to Watch For**:
- Typos in resource types
- Missing required fields (purpose, role for PSC)
- Invalid attribute names
- Incorrect variable references
- Invalid CIDR ranges

---

### Step 5: Terraform Plan (Dry Run)

```bash
terraform plan -out=network-update.tfplan
```

**Expected Plan Summary**:
```
Plan: 4 to add, 0 to change, 2 to destroy.
```

**Detailed Expected Resources**:

1. **Replace**: `google_compute_subnetwork.prod_use4`
   - Old name: `pcc-subnet-prod-use4`
   - New name: `pcc-prj-devops-prod`
   - CIDR: `10.16.128.0/20` (unchanged)
   - Secondary ranges: 2 (renamed)

2. **Replace**: `google_compute_subnetwork.nonprod_use4`
   - Old name: `pcc-subnet-nonprod-use4`
   - New name: `pcc-prj-devops-nonprod`
   - CIDR: `10.24.128.0/20` (unchanged)
   - Secondary ranges: 2 (renamed)

3. **Add**: `google_compute_subnetwork.app_devtest_use4`
   - Name: `pcc-prj-app-devtest`
   - CIDR: `10.28.0.0/20`
   - Secondary ranges: 2 (pods, services)

4. **Add**: `google_compute_subnetwork.app_devtest_overflow_use4`
   - Name: `pcc-prj-app-devtest-overflow`
   - CIDR: `10.28.48.0/20`
   - No secondary ranges
   - Purpose: PSC endpoints and expansion

---

### Step 6: Review Plan Output

```bash
terraform show network-update.tfplan > network-update-plan.txt
```

**Manual Review Checklist**:

#### DevOps Subnets (Replacements)
- [ ] Name changes shown: `pcc-subnet-{env}-use4` → `pcc-prj-devops-{env}`
- [ ] CIDR ranges unchanged (10.16.128.0/20, 10.24.128.0/20)
- [ ] Secondary range names updated (pods, services)
- [ ] Flow logs configuration preserved
- [ ] Private Google Access preserved
- [ ] **Forces replacement** annotation present

#### App Devtest Subnet (New)
- [ ] Name: `pcc-prj-app-devtest`
- [ ] CIDR: `10.28.0.0/20`
- [ ] Secondary range names: `pcc-prj-app-devtest-sub-pod`, `pcc-prj-app-devtest-sub-svc`
- [ ] Secondary CIDRs: `10.28.16.0/20`, `10.28.32.0/20`
- [ ] Flow logs enabled
- [ ] Private Google Access enabled
- [ ] Network: NonProduction VPC

#### App Devtest Overflow Subnet (New)
- [ ] Name: `pcc-prj-app-devtest-overflow`
- [ ] CIDR: `10.28.48.0/20`
- [ ] No secondary ranges
- [ ] Flow logs enabled
- [ ] Private Google Access enabled
- [ ] Network: NonProduction VPC

#### Global Checks
- [ ] No unexpected changes to VPCs, firewalls, or other resources
- [ ] Labels present on all resources
- [ ] No warnings about deprecated attributes

---

## Validation Failure Scenarios

### Scenario 1: Invalid CIDR Range
**Error**: `Error: invalid CIDR address`

**Resolution**:
- Verify CIDR syntax in terraform code
- Confirm no typos in IP addresses
- Check prefix length is valid (/20)

---

### Scenario 2: Network Not Found
**Error**: `Error: network "pcc-vpc-nonprod" not found`

**Resolution**:
- Verify VPC name spelling
- Confirm project ID is correct
- Check data source configuration

---

### Scenario 3: IP Range Overlap
**Error**: `Error: IP range overlaps with existing allocation`

**Resolution**:
- Review GCP_Network_Subnets.pdf
- Verify no conflicts with 10.28.0.0/20 (App Devtest main and overflow)
- Check against existing subnets

---

### Scenario 4: Replacement Will Cause Downtime
**Warning**: Name change forces resource replacement

**Resolution**:
- **Expected behavior** - name changes require destroy/create
- **Safe condition**: No resources using these subnets yet
- Document that brief connectivity loss is acceptable

---

## Post-Validation Actions

**If validation passes**:
1. Save plan file: `network-update.tfplan`
2. Review plan output for accuracy
3. Verify expected resource counts (4 add, 2 destroy)
4. Commit terraform changes to git (but don't apply yet)
5. Proceed to Phase 1.4 (WARP deployment)

**If validation fails**:
1. Document specific errors
2. Review Phase 1.1-1.2 terraform code
3. Correct issues
4. Re-run validation steps
5. Iterate until clean

---

## Validation Commands Reference

```bash
# Navigate to terraform directory
cd ~/pcc/core/pcc-foundation-infra/terraform

# Format check and auto-fix
terraform fmt

# Initialize (if needed)
terraform init

# Validate syntax
terraform validate

# Generate plan
terraform plan -out=network-update.tfplan

# Review plan in human-readable format
terraform show network-update.tfplan

# Save plan to file for review
terraform show network-update.tfplan > network-update-plan.txt

# Check for specific resource changes
terraform show network-update.tfplan | grep -A 20 "google_compute_subnetwork"
```

---

## Expected Terraform Output Sample

```
Terraform will perform the following actions:

  # google_compute_subnetwork.prod_use4 must be replaced
-/+ resource "google_compute_subnetwork" "prod_use4" {
      ~ name = "pcc-subnet-prod-use4" -> "pcc-prj-devops-prod" # forces replacement
        # (6 unchanged attributes hidden)

      ~ secondary_ip_range {
          ~ range_name = "pcc-subnet-prod-use4-pods" -> "pcc-prj-devops-prod-sub-pod"
            # (1 unchanged attribute hidden)
        }
      ~ secondary_ip_range {
          ~ range_name = "pcc-subnet-prod-use4-services" -> "pcc-prj-devops-prod-sub-svc"
            # (1 unchanged attribute hidden)
        }
    }

  # google_compute_subnetwork.nonprod_use4 must be replaced
-/+ resource "google_compute_subnetwork" "nonprod_use4" {
      ~ name = "pcc-subnet-nonprod-use4" -> "pcc-prj-devops-nonprod" # forces replacement
        # (similar to above)
    }

  # google_compute_subnetwork.app_devtest_use4 will be created
  + resource "google_compute_subnetwork" "app_devtest_use4" {
      + name          = "pcc-prj-app-devtest"
      + ip_cidr_range = "10.28.0.0/20"
      + region        = "us-east4"
      # (additional attributes)
    }

  # google_compute_subnetwork.app_devtest_overflow_use4 will be created
  + resource "google_compute_subnetwork" "app_devtest_overflow_use4" {
      + name          = "pcc-prj-app-devtest-overflow"
      + ip_cidr_range = "10.28.48.0/20"
      + region        = "us-east4"
      # (additional attributes)
    }

Plan: 4 to add, 0 to change, 2 to destroy.
```

---

## Deliverables

- [ ] Validation executed (terraform fmt, validate, plan)
- [ ] Plan output reviewed and saved
- [ ] No validation errors
- [ ] Expected resource changes confirmed (4 add, 2 destroy)
- [ ] CIDR ranges verified against PDF
- [ ] Overflow subnet validated
- [ ] Ready for Phase 1.4 (WARP deployment)

---

## References

- Phase 1.1 (DevOps subnet naming)
- Phase 1.2 (App Devtest subnet creation)
- GCP_Network_Subnets.pdf (CIDR allocations)
- Terraform docs: https://developer.hashicorp.com/terraform/cli/commands

---

## Notes

- **Replacement Risk**: DevOps subnet renames force destroy/create (safe - no dependencies yet)
- **New Subnets**: App Devtest and Overflow are brand new subnets
- **Overflow Subnet**: Provides network space for AlloyDB PSC endpoint (created in Phase 2)
- **Secondary Ranges**: Critical to verify exact names (referenced by GKE in Phase 5)
- **No Testing Yet**: Cannot test PSC connectivity until AlloyDB exists (Phase 2)

---

## Time Estimate

**Validation**: 10-15 minutes
- 2 min: Format check
- 2 min: Initialize (if needed)
- 2 min: Syntax validation
- 3 min: Generate plan
- 4 min: Review plan output thoroughly
- 2 min: Document findings and verify against expectations

---

**Next Phase**: 1.4 - Deploy via WARP
