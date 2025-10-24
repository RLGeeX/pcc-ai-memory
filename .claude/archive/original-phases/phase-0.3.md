# Phase 0.3: Validate Terraform & Document Implementation Plan

**Phase**: 0.3 (Foundation - Validation & Documentation)
**Duration**: 25-35 minutes
**Type**: Planning + Validation
**Status**: 📋 Planning (Not Started)
**Date**: TBD (10/20+)

---

## Objective

Validate the Terraform configuration for the 2 Apigee projects, document validation results, and create a comprehensive implementation runbook including prerequisites, execution steps, and rollback procedures.

## Prerequisites

✅ Phase 0.2 completed (terraform code designed)
✅ Terraform CLI available (`terraform --version`)
✅ GCP credentials configured
✅ Access to `pcc-fldr-si` folder and billing account

---

## Part A: Terraform Validation (10-15 min)

### Step 1: Format Check
```bash
cd ~/pcc/core/pcc-foundation-infra/terraform
terraform fmt -check
```

**Expected Result**: No formatting issues (or auto-fix with `terraform fmt`)

**Purpose**: Ensures code follows HCL formatting standards

---

### Step 2: Syntax Validation
```bash
terraform init  # If not already initialized
terraform validate
```

**Expected Output**:
```
Success! The configuration is valid.
```

**Purpose**: Catches syntax errors, missing variables, invalid resource types

**Common Issues to Watch For**:
- Typos in resource types (`google_project` vs `google_projects`)
- Missing required fields
- Invalid attribute names
- Incorrect variable references

---

### Step 3: Terraform Plan (Dry Run)
```bash
terraform plan -out=apigee-projects.tfplan
```

**Expected Output**: Plan showing 2 new projects to be created

**Review Checklist**:
- [ ] Exactly 2 resources to add (no unexpected changes)
- [ ] 0 resources to change
- [ ] 0 resources to destroy
- [ ] Project IDs match: `pcc-prj-apigee-nonprod`, `pcc-prj-apigee-prod`
- [ ] Folder ID correctly points to `pcc-fldr-si`
- [ ] Billing account ID is correct
- [ ] Labels are present and accurate
- [ ] `auto_create_network = false` is set

**Sample Plan Output to Expect**:
```
Plan: 2 to add, 0 to change, 0 to destroy.
```

---

### Step 4: Plan Review
Save the plan output for review:
```bash
terraform show apigee-projects.tfplan > apigee-projects-plan.txt
```

**Manual Review**:
- Verify all resource attributes
- Check for any warnings or notes
- Confirm no side effects on existing resources
- Validate folder hierarchy is correct

---

### Validation Failure Scenarios

**Scenario 1: Folder ID Not Found**
- **Error**: `Error: folder "folders/XXXXXXXXXX" not found`
- **Resolution**: Verify folder ID with `gcloud resource-manager folders list`, update terraform code, re-run validation

**Scenario 2: Billing Account Access Denied**
- **Error**: `Error: insufficient permissions for billing account`
- **Resolution**: Verify billing account ID, confirm service account has `roles/billing.user`, check account not closed

**Scenario 3: Project ID Already Exists**
- **Error**: `Error: project "pcc-prj-apigee-nonprod" already exists`
- **Resolution**: Import existing project or use different project ID

**Scenario 4: Quota Exceeded**
- **Error**: `Error: quota exceeded for new projects`
- **Resolution**: Review organization project quota, request increase if needed, clean up unused projects

---

## Part B: Implementation Planning & Runbook (15-20 min)

### Implementation Prerequisites

**Required Information**:
- [ ] Folder ID for `pcc-fldr-si` (from Phase 0.1)
- [ ] Billing account ID (from Phase 0.1)
- [ ] Terraform version confirmed (>= 1.6.0)
- [ ] GCP credentials configured and tested
- [ ] Git working tree clean (no uncommitted changes)

**Required Permissions**:
- [ ] Organization Admin or Folder Admin on `pcc-fldr-si`
- [ ] Billing Account User on billing account
- [ ] Service Account User (if using service account for terraform)
- [ ] Project Creator permission at folder level

**Verification Commands**:
```bash
# Verify terraform version
terraform --version

# Verify GCP authentication
gcloud auth list

# Verify folder access
gcloud resource-manager folders describe folders/XXXXXXXXXX

# Verify billing account access
gcloud billing accounts list

# Verify current project count (baseline)
gcloud projects list --filter="parent.id=folders/XXXXXXXXXX" --format="table(projectId,name)"
```

---

### Implementation Steps (Execute on 10/20 via WARP)

**Step 1: Pre-Implementation Baseline**
```bash
cd ~/pcc/core/pcc-foundation-infra/terraform

# List current projects (before)
gcloud projects list --filter="parent.id=folders/XXXXXXXXXX" > projects-before.txt
```

**Note**: State is in GCS with versioning - manual backup not needed.

**Step 2: Add Terraform Code**
- Insert project resources from Phase 0.2 design
- Replace placeholder values with actual IDs
- Follow exact patterns from Phase 0.1 findings

**Step 3: Apply Changes** (Deferred to Phase 0.4 - WARP)

---

### Success Criteria

**Infrastructure State**:
- [ ] 2 new projects exist in GCP
- [ ] Projects assigned to correct folder (`pcc-fldr-si`)
- [ ] Billing enabled on both projects
- [ ] Projects in ACTIVE lifecycle state
- [ ] No default VPC created (`auto_create_network = false` worked)
- [ ] Labels correctly applied
- [ ] Terraform state updated successfully

**Validation Commands**:
```bash
# Both projects exist
gcloud projects describe pcc-prj-apigee-nonprod --format="value(lifecycleState)" # Returns: ACTIVE
gcloud projects describe pcc-prj-apigee-prod --format="value(lifecycleState)"    # Returns: ACTIVE

# Terraform state matches reality
terraform show | grep google_project.pcc_prj_apigee  # Shows 2 resources

# No default networks created
gcloud compute networks list --project=pcc-prj-apigee-nonprod  # Empty
gcloud compute networks list --project=pcc-prj-apigee-prod     # Empty
```

---

### Rollback Strategy

**Scenario 1: Terraform Apply Fails Midway**
- Review error message
- Fix terraform code if syntax/permission issue
- Re-run `terraform apply`
- If unfixable: Proceed to full rollback

**Scenario 2: Projects Created But Incorrect Configuration**
```bash
# Destroy projects via terraform
terraform destroy -target=google_project.pcc_prj_apigee_nonprod
terraform destroy -target=google_project.pcc_prj_apigee_prod

# Fix terraform code and re-run
terraform plan
terraform apply
```

**Scenario 3: Complete Rollback Required**
```bash
# Step 1: Remove projects from terraform state
terraform state rm google_project.pcc_prj_apigee_nonprod
terraform state rm google_project.pcc_prj_apigee_prod

# Step 2: Delete projects from GCP (30-day soft delete)
gcloud projects delete pcc-prj-apigee-nonprod
gcloud projects delete pcc-prj-apigee-prod

# Step 3: Verify rollback
terraform plan  # Should show 2 to add (projects removed from state)

# Step 4: Revert git commit (if pushed)
git revert HEAD
git push origin main
```

**Note**:
- Projects enter 30-day soft delete state. Can be recovered with `gcloud projects undelete PROJECT_ID`
- State stored in GCS with versioning - can recover if needed via GCS console

---

## Troubleshooting Guide

### Issue: "Error creating project: Project ID already exists"
**Resolution**:
```bash
# Import existing project
terraform import google_project.pcc_prj_apigee_nonprod pcc-prj-apigee-nonprod
terraform import google_project.pcc_prj_apigee_prod pcc-prj-apigee-prod

# Verify state
terraform plan  # Should show no changes
```

### Issue: "Error: insufficient permissions"
**Resolution**: Verify user/service account has required roles:
- `roles/resourcemanager.folderAdmin` (on pcc-fldr-si)
- `roles/billing.user` (on billing account)
- `roles/resourcemanager.projectCreator`

### Issue: Default VPC Created Despite auto_create_network = false
**Resolution**:
```bash
# Delete default network
gcloud compute networks delete default --project=pcc-prj-apigee-nonprod
gcloud compute networks delete default --project=pcc-prj-apigee-prod
```

---

## Post-Validation Actions

**If validation passes**:
1. Save plan file: `apigee-projects.tfplan`
2. Document validation results and prerequisites
3. Commit terraform changes to git (but don't apply yet)
4. Create PR for review
5. Proceed to Phase 0.4 (WARP deployment)

**If validation fails**:
1. Document specific errors
2. Review Phase 0.2 design
3. Correct terraform code
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
terraform plan -out=apigee-projects.tfplan

# Review plan in human-readable format
terraform show apigee-projects.tfplan

# Save plan to file for review
terraform show apigee-projects.tfplan > apigee-projects-plan.txt

# List existing projects (compare before/after)
gcloud projects list --filter="parent.id=$(gcloud organizations list --format='value(name)')"
```

---

## Deliverables

- [ ] Validation executed (terraform fmt, validate, plan)
- [ ] Plan output reviewed and saved
- [ ] Prerequisites documented and verified
- [ ] Implementation runbook complete
- [ ] Success criteria defined
- [ ] Rollback procedures documented
- [ ] Troubleshooting guide created
- [ ] Ready for Phase 0.4 (WARP deployment)

## Post-Implementation Notes

### What's Next (Phase 1)
- Phase 1 will create networking for devtest app workloads
- These Apigee projects won't be used until Phase 7
- No action needed on these projects until Phase 7 (Apigee org creation)

### Cost Implications
- **Empty projects**: ~$0/month (no resources deployed)
- **Billing**: Enabled but no charges until resources created
- **First bill**: Phase 7+ (Apigee runtime instance)

### Documentation Updates
After successful implementation:
- [ ] Update `.claude/status/brief.md` (Phase 0 complete)
- [ ] Update `.claude/status/current-progress.md` (log implementation)
- [ ] Update `core/pcc-foundation-infra/.claude/status/brief.md` (2 projects added)

---

## References

- Phase 0.1 (repository structure)
- Phase 0.2 (terraform design)
- `.claude/plans/devtest-deployment-phases.md` (Phase 0 overview)
- Terraform docs: https://developer.hashicorp.com/terraform/cli/commands

## Notes

- This is PLANNING ONLY - validation/documentation on 10/17-10/19, execution on 10/20
- Combined validation and documentation into one phase for efficiency
- Low risk: Only creating empty projects
- Easily reversible: Soft delete with 30-day recovery window

---

**Next Phase**: 0.4 - Deploy via WARP
