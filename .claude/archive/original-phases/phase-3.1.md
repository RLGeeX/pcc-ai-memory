# Phase 3.1: Foundation Prerequisites

**Phase**: 3.1 (GKE Deployment - Foundation Prerequisites)
**Duration**: 10-15 minutes
**Type**: Implementation (Foundation)
**Status**: 📋 Planning (Not Started)
**Date**: TBD (10/21+)

---

## Objective

Enable required APIs in the foundation infrastructure to support GKE Connect Gateway for fully private GKE clusters.

**This phase MUST be completed before starting Phase 3.3 (GKE cluster documentation).**

---

## Prerequisites

✅ **Phase 3.0 completed** - Core GKE APIs enabled (container, compute) (BLOCKING)
✅ Phase 0 completed (foundation infrastructure deployed)
✅ Access to `core/pcc-foundation-infra` repository
✅ WARP terminal access with GCP credentials
✅ Terraform installed and configured

---

## What This Phase Does

Enables two additional Google Cloud APIs in all 3 GKE projects to support **Connect Gateway**, which provides secure kubectl access to fully private GKE clusters without VPN or bastion hosts.

**APIs to Enable**:
- `gkehub.googleapis.com` - GKE Hub for fleet management
- `connectgateway.googleapis.com` - Connect Gateway for private cluster access

**Projects**:
- `pcc-prj-devops-nonprod`
- `pcc-prj-devops-prod`
- `pcc-prj-app-devtest`

---

## Repository

**Working Directory**: `core/pcc-foundation-infra/terraform/`

**File to Modify**: `api-services.tf` (or create if doesn't exist)

---

## Implementation Steps

### Step 1: Navigate to Foundation Repo

```bash
cd ~/pcc/core/pcc-foundation-infra/terraform
```

**Verify Location**:
```bash
pwd
# Expected: /home/<user>/pcc/core/pcc-foundation-infra/terraform

ls -la
# Should see: main.tf, variables.tf, backend.tf, etc.
```

---

### Step 2: Add Connect Gateway API Resources

**Option A: If `api-services.tf` already exists**:

Open the file and add these resources:

```bash
# Edit existing file
vim api-services.tf  # or your preferred editor
```

**Option B: If `api-services.tf` doesn't exist**:

Create a new file:

```bash
# Create new file
touch api-services.tf
vim api-services.tf
```

**Add This Content**:

```hcl
# core/pcc-foundation-infra/terraform/api-services.tf

# ============================================================================
# Connect Gateway APIs for Private GKE Clusters
# ============================================================================
# These APIs enable GKE Connect Gateway, which provides secure kubectl access
# to fully private GKE clusters (private nodes + private endpoints) without
# requiring VPN, bastion hosts, or IP allowlists.
#
# Required for: Phase 3 GKE cluster deployment
# ============================================================================

# GKE Hub API (for fleet management)
resource "google_project_service" "gkehub" {
  for_each = toset([
    "pcc-prj-devops-nonprod",
    "pcc-prj-devops-prod",
    "pcc-prj-app-devtest"
  ])

  project            = each.key
  service            = "gkehub.googleapis.com"
  disable_on_destroy = false
}

# Connect Gateway API (for private cluster access)
resource "google_project_service" "connectgateway" {
  for_each = toset([
    "pcc-prj-devops-nonprod",
    "pcc-prj-devops-prod",
    "pcc-prj-app-devtest"
  ])

  project            = each.key
  service            = "connectgateway.googleapis.com"
  disable_on_destroy = false
}
```

**Save and Exit**

---

### Step 3: Terraform Format

```bash
cd ~/pcc/core/pcc-foundation-infra/terraform

# Format all terraform files
terraform fmt -recursive

# Verify formatting
terraform fmt -check -recursive
```

**Expected Output**: No output (all files formatted correctly)

---

### Step 4: Terraform Validate

```bash
cd ~/pcc/core/pcc-foundation-infra/terraform

# Validate configuration
terraform validate
```

**Expected Output**:
```
Success! The configuration is valid.
```

**If Errors**: Fix syntax errors, check project IDs match existing foundation projects

---

### Step 5: Terraform Plan

```bash
cd ~/pcc/core/pcc-foundation-infra/terraform

# Generate plan
terraform plan -out=tfplan-phase3-prereqs

# Review plan output
```

**Expected Resource Changes**:
```
Plan: 6 to add, 0 to change, 0 to destroy.

# 3 gkehub API resources (one per project)
+ google_project_service.gkehub["pcc-prj-devops-nonprod"]
+ google_project_service.gkehub["pcc-prj-devops-prod"]
+ google_project_service.gkehub["pcc-prj-app-devtest"]

# 3 connectgateway API resources (one per project)
+ google_project_service.connectgateway["pcc-prj-devops-nonprod"]
+ google_project_service.connectgateway["pcc-prj-devops-prod"]
+ google_project_service.connectgateway["pcc-prj-app-devtest"]
```

**Validation Checklist**:
- [ ] Exactly 6 resources to add
- [ ] 0 resources to change
- [ ] 0 resources to destroy
- [ ] All 3 projects listed (devops-nonprod, devops-prod, app-devtest)
- [ ] Both API services listed (gkehub, connectgateway)

---

### Step 6: Apply Terraform Changes

**IMPORTANT**: Run in WARP terminal with GCP credentials

```bash
cd ~/pcc/core/pcc-foundation-infra/terraform

# Apply the plan
terraform apply tfplan-phase3-prereqs
```

**Expected Output**:
```
google_project_service.gkehub["pcc-prj-devops-nonprod"]: Creating...
google_project_service.gkehub["pcc-prj-devops-prod"]: Creating...
google_project_service.gkehub["pcc-prj-app-devtest"]: Creating...
google_project_service.connectgateway["pcc-prj-devops-nonprod"]: Creating...
google_project_service.connectgateway["pcc-prj-devops-prod"]: Creating...
google_project_service.connectgateway["pcc-prj-app-devtest"]: Creating...

google_project_service.gkehub["pcc-prj-devops-nonprod"]: Creation complete after 5s
google_project_service.gkehub["pcc-prj-devops-prod"]: Creation complete after 5s
google_project_service.gkehub["pcc-prj-app-devtest"]: Creation complete after 5s
google_project_service.connectgateway["pcc-prj-devops-nonprod"]: Creation complete after 6s
google_project_service.connectgateway["pcc-prj-devops-prod"]: Creation complete after 6s
google_project_service.connectgateway["pcc-prj-app-devtest"]: Creation complete after 6s

Apply complete! Resources: 6 added, 0 changed, 0 destroyed.
```

**Expected Duration**: 5-10 seconds (APIs enable quickly)

---

### Step 7: Verify API Enablement

**Verify All 3 Projects**:

```bash
# Check all 3 projects for required APIs
for PROJECT in pcc-prj-devops-nonprod pcc-prj-devops-prod pcc-prj-app-devtest; do
  echo "=== Checking $PROJECT ==="
  gcloud services list \
    --project=$PROJECT \
    --filter="name:(gkehub.googleapis.com OR connectgateway.googleapis.com)" \
    --format="table(name)"
  echo ""
done
```

**Expected Output** (for each project):
```
=== Checking pcc-prj-devops-nonprod ===
NAME
connectgateway.googleapis.com
gkehub.googleapis.com

=== Checking pcc-prj-devops-prod ===
NAME
connectgateway.googleapis.com
gkehub.googleapis.com

=== Checking pcc-prj-app-devtest ===
NAME
connectgateway.googleapis.com
gkehub.googleapis.com
```

**Validation**:
- [ ] Both APIs listed for devops-nonprod
- [ ] Both APIs listed for devops-prod
- [ ] Both APIs listed for app-devtest

**If APIs Missing**: Re-run `terraform apply`, check for errors

---

## Commit Changes

```bash
cd ~/pcc/core/pcc-foundation-infra

# Stage changes
git add terraform/api-services.tf

# Commit with conventional commit message
git commit -m "feat: enable connect gateway APIs for GKE private clusters

- Add gkehub.googleapis.com for fleet management
- Add connectgateway.googleapis.com for private cluster access
- Enable in devops-nonprod, devops-prod, app-devtest projects
- Required for Phase 3 GKE deployment with private endpoints

Relates-to: Phase 3.1 GKE foundation prerequisites"

# Push to remote (if applicable)
git push origin main
```

---

## Rollback Plan (If Needed)

**If APIs Need to be Disabled**:

```bash
cd ~/pcc/core/pcc-foundation-infra/terraform

# Remove or comment out the API resources in api-services.tf
# Then run:

terraform plan -out=rollback-plan
terraform apply rollback-plan
```

**NOTE**: Disabling these APIs will break Connect Gateway access to private GKE clusters

---

## Deliverables

- [ ] `api-services.tf` created or updated with 2 API resources
- [ ] Terraform formatted (`terraform fmt`)
- [ ] Terraform validated (`terraform validate`)
- [ ] Terraform plan generated and reviewed (6 resources to add)
- [ ] Terraform applied successfully
- [ ] APIs verified enabled in all 3 projects via gcloud
- [ ] Changes committed to git

---

## Validation Criteria

- [ ] File exists: `core/pcc-foundation-infra/terraform/api-services.tf`
- [ ] 6 API resources created (2 APIs × 3 projects)
- [ ] `gkehub.googleapis.com` enabled in all 3 projects
- [ ] `connectgateway.googleapis.com` enabled in all 3 projects
- [ ] No terraform errors
- [ ] Terraform state updated
- [ ] Git commit created

---

## Dependencies

**Upstream**:
- Phase 0: Foundation infrastructure (projects exist)
- **Phase 3.0: Core GKE APIs enabled** (container, compute)

**Downstream**:
- Phase 3.3: GKE cluster terraform (requires these APIs for Connect Gateway)
- Phase 3.6: WARP deployment (will register clusters with fleet)

---

## Notes

### Why These APIs Are Required

**GKE Hub (`gkehub.googleapis.com`)**:
- Manages GKE fleets (groups of clusters)
- Required for registering clusters with Connect Gateway
- Enables centralized cluster management

**Connect Gateway (`connectgateway.googleapis.com`)**:
- Provides secure proxy to fully private GKE clusters
- Eliminates need for VPN, bastion hosts, or IP allowlists
- Works from WARP terminal, Cloud Build, developer machines

### Alternative Approaches NOT Used

❌ **Public Control Plane + Authorized Networks**: Less secure, requires IP allowlist maintenance
❌ **Bastion Host + IAP**: Requires managing additional infrastructure
❌ **Cloud VPN**: Complex, expensive, overkill for kubectl access

### API Propagation Time

- APIs typically enable in 5-10 seconds
- Some services may take 1-2 minutes to fully propagate
- If Phase 3.6 deployment fails with "API not enabled" errors, wait 2 minutes and retry

### Cost Impact

- Both APIs are **FREE** (no charges for enablement or usage)
- Connect Gateway incurs no additional costs beyond cluster costs

---

## Troubleshooting

### Issue 1: Permission Denied

**Error**:
```
Error: Error enabling service: Permission denied
```

**Solution**: Verify your GCP account has `serviceusage.services.enable` permission or `roles/serviceusage.serviceUsageAdmin` role

### Issue 2: Project Not Found

**Error**:
```
Error: Error enabling service: Project not found
```

**Solution**: Verify project IDs match foundation project names. Check with:
```bash
gcloud projects list --format="table(projectId)"
```

### Issue 3: API Already Enabled

**Output**:
```
google_project_service.gkehub: Creation complete (no changes)
```

**Status**: Normal - APIs were previously enabled, no action needed

---

## Time Estimate

**Total**: 10-15 minutes
- 2 min: Create/edit `api-services.tf`
- 2 min: `terraform fmt` and `terraform validate`
- 2 min: `terraform plan` (review output)
- 1 min: `terraform apply`
- 2 min: Verify APIs enabled via gcloud
- 2 min: Git commit

---

**Next Phase**: 3.2 - Infrastructure Audit
