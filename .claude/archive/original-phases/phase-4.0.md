# Phase 4.0: Enable Required GCP APIs for ArgoCD Deployment

**Phase**: 4.0 (ArgoCD Infrastructure - API Enablement)
**Duration**: 10-15 minutes
**Type**: Infrastructure Update
**Status**: 📋 Planning (Not Started)
**Date**: TBD (before Phase 4.1)

---

## Objective

Enable required GCP APIs in foundation infrastructure for Phase 4 ArgoCD deployment across devops-nonprod and devops-prod projects, including static IPs, DNS, SSL certificates, Cloud Armor, and backup storage.

## Prerequisites

✅ Phase 0 completed (Projects created)
✅ Phase 3 completed (GKE clusters deployed)
✅ Access to `pcc-foundation-infra` repository
✅ Terraform state accessible for foundation
✅ Understanding of API service enablement

---

## Required APIs

### Phase 4 API Requirements

**For pcc-prj-devops-nonprod** (currently has: container, cloudbuild, artifactregistry):
- ✅ `compute.googleapis.com` - Already enabled in Phase 3.0 (static IPs, SSL certificates, Cloud Armor)
- `dns.googleapis.com` - DNS A record management
- `storage.googleapis.com` - Cloud Storage buckets for ArgoCD backups

**For pcc-prj-devops-prod** (currently has: container, cloudbuild, artifactregistry, storage):
- ✅ `compute.googleapis.com` - Already enabled in Phase 3.0 (static IPs, SSL certificates, Cloud Armor)
- `dns.googleapis.com` - DNS A record management
- ✅ `storage.googleapis.com` - Already enabled in foundation (backup buckets)

**For pcc-prj-app-devtest** (no additional APIs needed):
- ✅ `gkehub.googleapis.com` - Already enabled in Phase 3.1 (Connect Gateway membership)
- ✅ `container.googleapis.com` - Already enabled in Phase 3.0 (cluster operations)

**API Count**: 2 new APIs needed
- `dns.googleapis.com` for both devops projects (2 resources)

---

## Implementation

### Repository

**Target**: `core/pcc-foundation-infra`
**File to Modify**: `terraform/api-services.tf`

### Terraform Changes

**Add to `api-services.tf`**:

```hcl
# Phase 4.0: DNS and Storage APIs for ArgoCD deployment

# DNS API for devops projects (ArgoCD ingress DNS records)
resource "google_project_service" "dns" {
  for_each = toset([
    "pcc-prj-devops-nonprod",
    "pcc-prj-devops-prod"
  ])

  project            = each.key
  service            = "dns.googleapis.com"
  disable_on_destroy = false
}

# Storage API for nonprod devops project (ArgoCD backup buckets)
# Note: prod already has storage.googleapis.com enabled in foundation
resource "google_project_service" "storage_nonprod" {
  project            = "pcc-prj-devops-nonprod"
  service            = "storage.googleapis.com"
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

Add the terraform resources shown above to enable DNS and storage APIs.

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
#   # google_project_service.dns["pcc-prj-devops-nonprod"] will be created
#   # google_project_service.dns["pcc-prj-devops-prod"] will be created
#   # google_project_service.storage_nonprod will be created
#
#   Plan: 3 to add, 0 to change, 0 to destroy.
```

### 4. Apply API Enablement

```bash
terraform apply

# Review the plan and type 'yes' to confirm
# Expected output:
#   google_project_service.dns["pcc-prj-devops-nonprod"]: Creating...
#   google_project_service.dns["pcc-prj-devops-prod"]: Creating...
#   google_project_service.storage_nonprod: Creating...
#
#   Apply complete! Resources: 3 added, 0 changed, 0 destroyed.
```

### 5. Verify API Enablement

```bash
# Verify DNS API enabled
gcloud services list --enabled --project=pcc-prj-devops-nonprod | grep dns
gcloud services list --enabled --project=pcc-prj-devops-prod | grep dns

# Verify storage API enabled
gcloud services list --enabled --project=pcc-prj-devops-nonprod | grep storage
gcloud services list --enabled --project=pcc-prj-devops-prod | grep storage

# Expected: All commands return enabled API entries
```

---

## API Requirements by Phase 4 Subphase

**Phase 4.5 (Create Terraform)**: No APIs needed (planning only)

**Phase 4.6 (Apply Nonprod)**:
- ✅ `compute.googleapis.com` (static IPs, SSL certs, Cloud Armor) - Phase 3.0
- ✅ `dns.googleapis.com` (DNS A records) - Phase 4.0

**Phase 4.9 (Apply Prod)**:
- ✅ `compute.googleapis.com` (static IPs, SSL certs, Cloud Armor) - Phase 3.0
- ✅ `dns.googleapis.com` (DNS A records) - Phase 4.0

**Phase 4.11 (Backup Automation)**:
- ✅ `storage.googleapis.com` (backup buckets) - Phase 4.0 (nonprod), foundation (prod)
- ✅ `gkehub.googleapis.com` (Connect Gateway) - Phase 3.1
- ✅ `container.googleapis.com` (cluster operations) - Phase 3.0

---

## Validation Checklist

- [ ] `api-services.tf` updated with Phase 4 APIs
- [ ] Terraform validate passes
- [ ] Terraform plan shows 3 new API service resources
- [ ] Terraform apply succeeds
- [ ] DNS API verified enabled in both devops projects
- [ ] Storage API verified enabled in devops-nonprod
- [ ] No terraform errors or warnings

---

## Deliverables

- [x] Updated `core/pcc-foundation-infra/terraform/api-services.tf` with Phase 4 APIs
- [ ] 3 `google_project_service` resources created
- [ ] Verification output showing APIs enabled
- [ ] Foundation infrastructure ready for Phase 4 ArgoCD deployment

---

## Dependencies

**Upstream**:
- Phase 0: Projects created
- Phase 3.0: Compute API enabled (required for Cloud Armor, SSL certs)
- Phase 3.1: GKE Hub and Connect Gateway APIs enabled (required for Phase 4.11)

**Downstream**:
- Phase 4.5: Terraform creation (requires APIs as documentation reference)
- Phase 4.6: Nonprod deployment (requires DNS + compute APIs enabled)
- Phase 4.9: Prod deployment (requires DNS + compute APIs enabled)
- Phase 4.11: Backup automation (requires storage + gkehub APIs enabled)

---

## Notes

- **API Propagation**: APIs typically enable within 30-60 seconds but can take up to 5 minutes
- **No Cost**: Enabling APIs is free; costs only incurred when resources are created
- **Idempotent**: Re-running terraform apply is safe if APIs already enabled
- **Foundation Scope**: This modifies central foundation infrastructure in `pcc-foundation-infra`
- **Compute API**: Already enabled in Phase 3.0, reused for ArgoCD ingress resources
- **Storage API (Prod)**: Already enabled in foundation, no additional resource needed
- **Connect Gateway**: APIs enabled in Phase 3.1, reused for ArgoCD Connect Gateway access to app-devtest
- **Test Coverage**: Phase 4.6 and 4.9 will fail explicitly if APIs not enabled

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

**Next Phase**: 4.1 - Core Architecture Planning
