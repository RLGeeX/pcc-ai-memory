# Phase 3.0: Enable Required GCP APIs for GKE Deployment

**Phase**: 3.0 (GKE Infrastructure - API Enablement)
**Duration**: 10-15 minutes
**Type**: Infrastructure Update
**Status**: 📋 Planning (Not Started)
**Date**: TBD (before Phase 3.1)

---

## Objective

Enable required GCP APIs in foundation infrastructure for Phase 3 GKE cluster deployment across devops-nonprod, devops-prod, and app-devtest projects.

## Prerequisites

✅ Phase 0 completed (Projects created)
✅ Access to `pcc-foundation-infra` repository
✅ Terraform state accessible for foundation
✅ Understanding of API service enablement

---

## Required APIs

### Phase 3 API Requirements

**For pcc-prj-devops-nonprod**:
- `container.googleapis.com` - GKE cluster creation and management
- `compute.googleapis.com` - Compute Engine resources (nodes, IPs, firewalls)

**For pcc-prj-devops-prod**:
- `container.googleapis.com` - GKE cluster creation and management
- `compute.googleapis.com` - Compute Engine resources (nodes, IPs, firewalls)

**For pcc-prj-app-devtest**:
- `container.googleapis.com` - GKE cluster creation and management
- `compute.googleapis.com` - Compute Engine resources (nodes, IPs, firewalls)

**Note**: `gkehub.googleapis.com` and `connectgateway.googleapis.com` are enabled separately in Phase 3.1 for Connect Gateway functionality.

---

## Implementation

### Repository

**Target**: `core/pcc-foundation-infra`
**File to Modify**: `terraform/api-services.tf`

### Terraform Changes

**Add to `api-services.tf`**:

```hcl
# Phase 3.0: GKE and Compute APIs for cluster deployment

# Container (GKE) API for all 3 projects
resource "google_project_service" "container" {
  for_each = toset([
    "pcc-prj-devops-nonprod",
    "pcc-prj-devops-prod",
    "pcc-prj-app-devtest"
  ])

  project            = each.key
  service            = "container.googleapis.com"
  disable_on_destroy = false
}

# Compute Engine API for all 3 projects
resource "google_project_service" "compute" {
  for_each = toset([
    "pcc-prj-devops-nonprod",
    "pcc-prj-devops-prod",
    "pcc-prj-app-devtest"
  ])

  project            = each.key
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}
```

---

## Execution Steps

### 1. Navigate to Foundation Infrastructure

```bash
cd ~/pcc/core/pcc-foundation-infra/terraform
```

### 2. Update api-services.tf

Add the terraform resources shown above to enable container and compute APIs.

**Expected file structure**:
```
terraform/
├── api-services.tf        # Update this file
├── main.tf
├── variables.tf
└── ...
```

### 3. Verify Terraform Configuration

```bash
# Format terraform
terraform fmt

# Validate configuration
terraform validate
# Expected: Success! The configuration is valid.

# Review planned changes
terraform plan
# Expected output:
#   # google_project_service.container["pcc-prj-devops-nonprod"] will be created
#   # google_project_service.container["pcc-prj-devops-prod"] will be created
#   # google_project_service.container["pcc-prj-app-devtest"] will be created
#   # google_project_service.compute["pcc-prj-devops-nonprod"] will be created
#   # google_project_service.compute["pcc-prj-devops-prod"] will be created
#   # google_project_service.compute["pcc-prj-app-devtest"] will be created
#
#   Plan: 6 to add, 0 to change, 0 to destroy.
```

### 4. Apply API Enablement

```bash
terraform apply

# Review the plan and type 'yes' to confirm
# Expected output:
#   google_project_service.container["pcc-prj-devops-nonprod"]: Creating...
#   google_project_service.container["pcc-prj-devops-prod"]: Creating...
#   google_project_service.container["pcc-prj-app-devtest"]: Creating...
#   google_project_service.compute["pcc-prj-devops-nonprod"]: Creating...
#   google_project_service.compute["pcc-prj-devops-prod"]: Creating...
#   google_project_service.compute["pcc-prj-app-devtest"]: Creating...
#
#   Apply complete! Resources: 6 added, 0 changed, 0 destroyed.
```

### 5. Verify API Enablement

```bash
# Verify container API enabled
gcloud services list --enabled --project=pcc-prj-devops-nonprod | grep container
gcloud services list --enabled --project=pcc-prj-devops-prod | grep container
gcloud services list --enabled --project=pcc-prj-app-devtest | grep container

# Verify compute API enabled
gcloud services list --enabled --project=pcc-prj-devops-nonprod | grep compute
gcloud services list --enabled --project=pcc-prj-devops-prod | grep compute
gcloud services list --enabled --project=pcc-prj-app-devtest | grep compute

# Expected: All commands return enabled API entries
```

---

## Validation Checklist

- [ ] `api-services.tf` updated with Phase 3 APIs
- [ ] Terraform validate passes
- [ ] Terraform plan shows 6 new API service resources
- [ ] Terraform apply succeeds
- [ ] Container API verified enabled in all 3 projects
- [ ] Compute API verified enabled in all 3 projects
- [ ] No terraform errors or warnings

---

## Deliverables

- [x] Updated `core/pcc-foundation-infra/terraform/api-services.tf` with Phase 3 APIs
- [ ] 6 `google_project_service` resources created
- [ ] Verification output showing APIs enabled
- [ ] Foundation infrastructure ready for Phase 3 GKE deployment

---

## Dependencies

**Upstream**:
- Phase 0: Projects created

**Downstream**:
- Phase 3.1: Connect Gateway API enablement (separate, gkehub + connectgateway)
- Phase 3.2: GKE infrastructure review (requires container + compute APIs)
- Phase 3.3: GKE cluster terraform creation (requires APIs enabled)

---

## Notes

- **API Propagation**: APIs typically enable within 30-60 seconds but can take up to 5 minutes
- **No Cost**: Enabling APIs is free; costs only incurred when resources are created
- **Idempotent**: Re-running terraform apply is safe if APIs already enabled
- **Foundation Scope**: This modifies central foundation infrastructure in `pcc-foundation-infra`
- **Phase 3.1**: Connect Gateway APIs (gkehub, connectgateway) handled separately in Phase 3.1
- **Test Coverage**: Phase 3.2 will verify API enablement during infrastructure review

---

## Time Estimate

**Total**: 10-15 minutes
- 3 min: Navigate to foundation repo and update api-services.tf
- 2 min: Run terraform fmt and validate
- 3 min: Run terraform plan and review changes
- 3 min: Run terraform apply (API enablement takes ~1-2 min)
- 2 min: Verify APIs enabled via gcloud
- 2 min: Commit changes to git

---

**Next Phase**: 3.1 - Enable Connect Gateway APIs (gkehub, connectgateway)
