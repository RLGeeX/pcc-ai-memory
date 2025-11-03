# Phase 3.1: Add GKE API Configurations

**Phase**: 3.1 (GKE Infrastructure - API Prerequisites)
**Duration**: 10-15 minutes
**Type**: Configuration
**Status**: Ready for Execution

---

## Execution Tool

**Use Claude Code for this phase** - Adding API configurations to terraform files.

---

## Objective

Add required GKE API configurations to `pcc-foundation-infra` **repository** to enable Kubernetes APIs in the **`pcc-prj-devops-nonprod` project** before deploying GKE cluster in Phase 3.9.

**Clarification**: `pcc-foundation-infra` is a repository that manages foundation resources across projects. This phase adds API enablement terraform code to that repository, which will enable APIs in the target GCP project (`pcc-prj-devops-nonprod`).

## Prerequisites

✅ Phase 1 completed (networking subnets deployed)
✅ Phase 2 completed (AlloyDB operational)
✅ Access to `pcc-foundation-infra` repository
✅ Understanding of GCP API enablement pattern

---

## Required APIs

The following APIs must be enabled in **project `pcc-prj-devops-nonprod`** (managed via `pcc-foundation-infra` repository):

1. **container.googleapis.com** - Google Kubernetes Engine API
   - Purpose: Create and manage GKE clusters
   - Required for: `google_container_cluster` resource

2. **gkehub.googleapis.com** - GKE Hub API
   - Purpose: Manage GKE Hub memberships for Connect Gateway
   - Required for: `google_gke_hub_membership` resource

3. **connectgateway.googleapis.com** - Connect Gateway API
   - Purpose: Enable kubectl access via PSC without VPN
   - Required for: Connect Gateway feature (ADR-002)

4. **anthosconfigmanagement.googleapis.com** - Anthos Config Management API
   - Purpose: Future ArgoCD and Config Sync integration
   - Required for: Phase 6 (ArgoCD deployment)

---

## Step 1: Locate API Configuration File

Navigate to the foundation infrastructure API configuration:

```bash
cd ~/pcc/pcc-foundation-infra/terraform
```

Expected file structure:
```
terraform/
├── apis.tf             # ← Add APIs here
├── backend.tf
├── providers.tf
└── terraform.tfvars
```

---

## Step 2: Add GKE APIs to apis.tf

**File**: `pcc-foundation-infra/terraform/apis.tf`

Add the following API resources:

```hcl
# GKE Cluster API
# NOTE: var.project_id must be set to "pcc-prj-devops-nonprod" in terraform.tfvars
resource "google_project_service" "container" {
  project = var.project_id
  service = "container.googleapis.com"

  disable_on_destroy = false
}

# GKE Hub API (for Connect Gateway)
resource "google_project_service" "gkehub" {
  project = var.project_id
  service = "gkehub.googleapis.com"

  disable_on_destroy = false
}

# Connect Gateway API (for kubectl access)
resource "google_project_service" "connectgateway" {
  project = var.project_id
  service = "connectgateway.googleapis.com"

  disable_on_destroy = false
}

# Anthos Config Management API (for ArgoCD - Phase 6)
resource "google_project_service" "anthosconfigmanagement" {
  project = var.project_id
  service = "anthosconfigmanagement.googleapis.com"

  disable_on_destroy = false
}
```

**Important Notes**:
- `disable_on_destroy = false` prevents API disruption during terraform destroy
- APIs must be enabled before deploying GKE resources in Phase 3.9
- **All APIs are enabled in project `pcc-prj-devops-nonprod`** (where the GKE cluster will be created)
- The `var.project_id` variable in `pcc-foundation-infra` terraform.tfvars must be set to `"pcc-prj-devops-nonprod"`

---

## Step 3: Verify Terraform Syntax

**Command** (Claude Code will execute):
```bash
cd ~/pcc/pcc-foundation-infra/terraform
terraform fmt apis.tf
terraform validate
```

Expected output:
```
Success! The configuration is valid.
```

---

## Validation Checklist

- [ ] 4 API resources added to `apis.tf`
- [ ] All APIs use `disable_on_destroy = false`
- [ ] `terraform fmt` applied successfully
- [ ] `terraform validate` passes without errors
- [ ] No other files modified (only `apis.tf`)

---

## API Details

| API | Service Name | Purpose | Required By |
|-----|--------------|---------|-------------|
| GKE | container.googleapis.com | Create/manage GKE clusters | Phase 3.9 |
| GKE Hub | gkehub.googleapis.com | Hub membership for Connect Gateway | Phase 3.11 |
| Connect Gateway | connectgateway.googleapis.com | kubectl access via PSC | Phase 3.11 |
| Config Management | anthosconfigmanagement.googleapis.com | ArgoCD integration | Phase 6 |

---

## File Impact

**Modified Files**: 1
- `pcc-foundation-infra/terraform/apis.tf` (+24 lines)

**No Changes To**:
- `backend.tf`
- `providers.tf`
- `terraform.tfvars`
- Network resources

---

## Next Phase Dependencies

**Phase 3.2** will:
- Deploy these API configurations using WARP
- Run `terraform apply` to enable APIs in GCP
- Verify API activation before proceeding to module creation

---

## References

- **GKE APIs**: https://cloud.google.com/kubernetes-engine/docs/reference/rest
- **Connect Gateway**: https://cloud.google.com/anthos/multicluster-management/gateway
- **ADR-002**: Apigee GKE Ingress Strategy (PSC connectivity)

---

## Time Estimate

- **Locate file**: 2 minutes
- **Add API resources**: 5-8 minutes (4 resources)
- **Validate syntax**: 2-3 minutes
- **Total**: 10-15 minutes

---

**Status**: Ready for execution
**Next**: Phase 3.2 - Deploy Foundation API Changes
