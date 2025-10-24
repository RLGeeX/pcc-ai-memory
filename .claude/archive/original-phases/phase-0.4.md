# Phase 0.4: Deploy via WARP

**Phase**: 0.4 (Foundation - WARP Deployment)
**Duration**: 15-20 minutes
**Type**: Deployment
**Status**: 📋 Planning (Not Started)
**Date**: TBD (10/20+)

---

## Objective

Execute the terraform deployment of the 2 Apigee projects using WARP terminal assistant, validate successful creation, and commit changes to git.

## Prerequisites

✅ Phase 0.3 completed (terraform validated, implementation plan documented)
✅ `apigee-projects.tfplan` file exists (from Phase 0.3)
✅ WARP terminal available
✅ GCP credentials configured
✅ Git working tree clean

---

## WARP Deployment Steps

### Step 1: Switch to WARP Terminal

Open WARP terminal and navigate to terraform directory:
```bash
cd ~/pcc/core/pcc-foundation-infra/terraform
```

---

### Step 2: Pre-Deployment Baseline

```bash
# List current projects (baseline)
gcloud projects list --filter="parent.id=folders/XXXXXXXXXX" > projects-before.txt
```

**Note**: State is stored in GCS with versioning enabled - manual backup not needed.

---

### Step 3: Apply Terraform Plan

```bash
terraform apply apigee-projects.tfplan
```

**Expected Duration**: 2-5 minutes

**Expected Output**:
```
google_project.pcc_prj_apigee_nonprod: Creating...
google_project.pcc_prj_apigee_prod: Creating...
google_project.pcc_prj_apigee_nonprod: Creation complete after 2m15s
google_project.pcc_prj_apigee_prod: Creation complete after 2m18s

Apply complete! Resources: 2 added, 0 changed, 0 destroyed.
```

---

### Step 4: Post-Deployment Validation

```bash
# List projects (after)
gcloud projects list --filter="parent.id=folders/XXXXXXXXXX" > projects-after.txt

# Verify both projects exist
gcloud projects describe pcc-prj-apigee-nonprod
gcloud projects describe pcc-prj-apigee-prod

# Compare before/after
diff projects-before.txt projects-after.txt
```

**Expected**: Exactly 2 new projects added

---

### Step 5: Verify Project Configuration

```bash
# Check pcc-prj-apigee-nonprod
gcloud projects describe pcc-prj-apigee-nonprod --format=json | jq '{projectId, name, parent, lifecycleState, labels}'

# Check pcc-prj-apigee-prod
gcloud projects describe pcc-prj-apigee-prod --format=json | jq '{projectId, name, parent, lifecycleState, labels}'
```

**Validation Checklist**:
- [ ] `lifecycleState`: "ACTIVE"
- [ ] `parent`: Folder ID for pcc-fldr-si
- [ ] `labels`: Contains environment, purpose, managed_by
- [ ] Billing account linked (verify in Cloud Console)

---

### Step 6: Verify Terraform State

```bash
# Verify terraform state matches reality
terraform show | grep google_project.pcc_prj_apigee

# Verify no default networks created
gcloud compute networks list --project=pcc-prj-apigee-nonprod
gcloud compute networks list --project=pcc-prj-apigee-prod
```

**Expected**:
- 2 resources in terraform state
- No networks listed (or only 'default' if auto_create_network was ignored - should be deleted)

---

### Step 7: Git Commit

```bash
git add terraform/
git commit -m "feat: add pcc-prj-apigee-nonprod and pcc-prj-apigee-prod projects

Added 2 Apigee projects to foundation infrastructure:
- pcc-prj-apigee-nonprod (nonprod Apigee org)
- pcc-prj-apigee-prod (prod Apigee org)

Both projects created in pcc-fldr-si folder with billing enabled.
No APIs enabled, no subnets created (deferred to Phase 7).

Phase 0 implementation complete."

git push origin main
```

---

## Success Criteria

### Infrastructure State
- [ ] 2 new projects exist in GCP
- [ ] Projects assigned to correct folder (`pcc-fldr-si`)
- [ ] Billing enabled on both projects
- [ ] Projects in ACTIVE lifecycle state
- [ ] No default VPC created (`auto_create_network = false` worked)
- [ ] Labels correctly applied
- [ ] Terraform state updated successfully

### Validation Commands Pass
```bash
# Both projects exist and are active
gcloud projects describe pcc-prj-apigee-nonprod --format="value(lifecycleState)" # Returns: ACTIVE
gcloud projects describe pcc-prj-apigee-prod --format="value(lifecycleState)"    # Returns: ACTIVE

# Terraform state matches reality
terraform show | grep google_project.pcc_prj_apigee  # Shows 2 resources

# No default networks created
gcloud compute networks list --project=pcc-prj-apigee-nonprod  # Empty
gcloud compute networks list --project=pcc-prj-apigee-prod     # Empty
```

---

## Troubleshooting (if needed)

### Issue: "Error creating project: Project ID already exists"
```bash
# Import existing project
terraform import google_project.pcc_prj_apigee_nonprod pcc-prj-apigee-nonprod
terraform import google_project.pcc_prj_apigee_prod pcc-prj-apigee-prod

# Verify state
terraform plan  # Should show no changes
```

### Issue: Default VPC Created Despite auto_create_network = false
```bash
# Delete default network
gcloud compute networks delete default --project=pcc-prj-apigee-nonprod
gcloud compute networks delete default --project=pcc-prj-apigee-prod
```

### Issue: Terraform Apply Fails
- Review error message in WARP
- Ask WARP for troubleshooting assistance
- Refer to Phase 0.3 rollback procedures if needed
- Fix issue and re-run `terraform apply`

---

## Rollback (if needed)

**Complete Rollback**:
```bash
# Step 1: Remove projects from terraform state
terraform state rm google_project.pcc_prj_apigee_nonprod
terraform state rm google_project.pcc_prj_apigee_prod

# Step 2: Delete projects from GCP (30-day soft delete)
gcloud projects delete pcc-prj-apigee-nonprod
gcloud projects delete pcc-prj-apigee-prod

# Step 3: Verify rollback
terraform plan  # Should show 2 to add (projects removed)
```

**Note**:
- Projects enter 30-day soft delete. Recover with `gcloud projects undelete PROJECT_ID`
- State versioning in GCS allows recovery if needed: `gsutil ls -a gs://bucket/path/to/terraform.tfstate`

---

## Post-Implementation Actions

### Documentation Updates
- [ ] Update `.claude/status/brief.md` (Phase 0 complete)
- [ ] Update `.claude/status/current-progress.md` (log implementation)
- [ ] Update `core/pcc-foundation-infra/.claude/status/brief.md` (2 projects added)

### What's Next
- **Phase 1**: GKE network infrastructure (subnets, PSC, firewall rules)
- **No action** on Apigee projects until Phase 7 (Apigee org creation)

### Cost Implications
- **Empty projects**: ~$0/month (no resources deployed)
- **Billing**: Enabled but no charges until resources created
- **First bill**: Phase 7+ (Apigee runtime instance)

---

## Deliverables

- [ ] Terraform apply executed successfully
- [ ] 2 Apigee projects created in GCP
- [ ] Post-deployment validation passed
- [ ] Terraform state updated
- [ ] Git commit pushed to main
- [ ] Documentation updated
- [ ] Phase 0 complete

## References

- Phase 0.3 (validation & implementation plan)
- `.claude/plans/devtest-deployment-phases.md` (Phase 0 overview)
- Phase 0.3 rollback procedures (if needed)

## Notes

- **WARP Assistance**: Use WARP AI for real-time troubleshooting if issues arise
- **Deployment Time**: Typically 2-5 minutes for 2 projects
- **Low Risk**: Only creating empty projects, easily reversible
- **Recovery Window**: 30-day soft delete allows project recovery if needed

---

**Next Phase**: 1.1 - Plan GKE Devtest Subnet Configuration
