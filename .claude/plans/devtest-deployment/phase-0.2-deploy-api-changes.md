# Phase 0.2: Deploy API Changes

**Phase**: 0.2 (Foundation Prerequisites - Deployment)
**Duration**: 5-7 minutes
**Type**: Implementation
**Status**: Ready for Execution

---

## Execution Tool

**Use WARP for this phase** - CLI commands only, no file editing.

---

## Objective

Deploy API enablement changes to GCP using Terraform. Enables Secret Manager API in `pcc-prj-app-devtest` and GKE Hub/Connect Gateway APIs in DevOps projects.

## Prerequisites

✅ Phase 0.1 completed (main.tf edited with new APIs)
✅ Terraform initialized in `pcc-foundation-infra`
✅ GCP credentials configured

---

## Deployment Steps

### Step 1: Navigate to Directory

```bash
cd ~/pcc/core/pcc-foundation-infra/terraform
```

---

### Step 2: Format Code

```bash
terraform fmt
```

**Expected Output**:
```
main.tf
```
(or no output if already formatted)

---

### Step 3: Validate Configuration

```bash
terraform validate
```

**Expected Output**:
```
Success! The configuration is valid.
```

**If validation fails**: Review Phase 0.1 changes for syntax errors (missing commas, brackets, quotes)

---

### Step 4: Generate Terraform Plan

```bash
terraform plan -out=phase0-apis.tfplan
```

**Expected Plan**:
```
Terraform will perform the following actions:

  # google_project_service.apis["pcc-prj-app-devtest-secretmanager.googleapis.com"] will be created
  + resource "google_project_service" "apis" {
      + id                     = (known after apply)
      + project                = "pcc-prj-app-devtest"
      + service                = "secretmanager.googleapis.com"
      + disable_on_destroy     = false
    }

  # google_project_service.apis["pcc-prj-devops-nonprod-connectgateway.googleapis.com"] will be created
  + resource "google_project_service" "apis" {
      + id                     = (known after apply)
      + project                = "pcc-prj-devops-nonprod"
      + service                = "connectgateway.googleapis.com"
      + disable_on_destroy     = false
    }

  # google_project_service.apis["pcc-prj-devops-nonprod-gkehub.googleapis.com"] will be created
  + resource "google_project_service" "apis" {
      + id                     = (known after apply)
      + project                = "pcc-prj-devops-nonprod"
      + service                = "gkehub.googleapis.com"
      + disable_on_destroy     = false
    }

  # google_project_service.apis["pcc-prj-devops-prod-connectgateway.googleapis.com"] will be created
  + resource "google_project_service" "apis" {
      + id                     = (known after apply)
      + project                = "pcc-prj-devops-prod"
      + service                = "connectgateway.googleapis.com"
      + disable_on_destroy     = false
    }

  # google_project_service.apis["pcc-prj-devops-prod-gkehub.googleapis.com"] will be created
  + resource "google_project_service" "apis" {
      + id                     = (known after apply)
      + project                = "pcc-prj-devops-prod"
      + service                = "gkehub.googleapis.com"
      + disable_on_destroy     = false
    }

Plan: 5 to add, 0 to change, 0 to destroy.
```

**Verify**: Exactly 5 new API resources to add

---

### Step 5: Apply Changes

```bash
terraform apply phase0-apis.tfplan
```

**Expected Duration**: 2-3 minutes (API enablement is fast)

**Expected Output**:
```
google_project_service.apis["pcc-prj-app-devtest-secretmanager.googleapis.com"]: Creating...
google_project_service.apis["pcc-prj-devops-nonprod-connectgateway.googleapis.com"]: Creating...
google_project_service.apis["pcc-prj-devops-nonprod-gkehub.googleapis.com"]: Creating...
google_project_service.apis["pcc-prj-devops-prod-connectgateway.googleapis.com"]: Creating...
google_project_service.apis["pcc-prj-devops-prod-gkehub.googleapis.com"]: Creating...

google_project_service.apis["pcc-prj-app-devtest-secretmanager.googleapis.com"]: Creation complete after 5s [id=pcc-prj-app-devtest/secretmanager.googleapis.com]
google_project_service.apis["pcc-prj-devops-nonprod-gkehub.googleapis.com"]: Creation complete after 7s [id=pcc-prj-devops-nonprod/gkehub.googleapis.com]
google_project_service.apis["pcc-prj-devops-nonprod-connectgateway.googleapis.com"]: Creation complete after 8s [id=pcc-prj-devops-nonprod/connectgateway.googleapis.com]
google_project_service.apis["pcc-prj-devops-prod-gkehub.googleapis.com"]: Creation complete after 9s [id=pcc-prj-devops-prod/gkehub.googleapis.com]
google_project_service.apis["pcc-prj-devops-prod-connectgateway.googleapis.com"]: Creation complete after 10s [id=pcc-prj-devops-prod/connectgateway.googleapis.com]

Apply complete! Resources: 5 added, 0 changed, 0 destroyed.
```

---

## Verification Steps

### Verify Secret Manager API (App Devtest)

```bash
gcloud services list --project=pcc-prj-app-devtest --filter="name:secretmanager"
```

**Expected Output**:
```
NAME                           TITLE
secretmanager.googleapis.com   Secret Manager API
```

---

### Verify GKE Hub APIs (DevOps NonProd)

```bash
gcloud services list --project=pcc-prj-devops-nonprod --filter="name:gkehub OR name:connectgateway"
```

**Expected Output**:
```
NAME                            TITLE
connectgateway.googleapis.com   Connect Gateway API
gkehub.googleapis.com          GKE Hub API
```

---

### Verify GKE Hub APIs (DevOps Prod)

```bash
gcloud services list --project=pcc-prj-devops-prod --filter="name:gkehub OR name:connectgateway"
```

**Expected Output**:
```
NAME                            TITLE
connectgateway.googleapis.com   Connect Gateway API
gkehub.googleapis.com          GKE Hub API
```

---

## Validation Checklist

- [ ] `terraform fmt` completed without errors
- [ ] `terraform validate` passed
- [ ] `terraform plan` showed exactly 5 new API resources
- [ ] `terraform apply` completed successfully
- [ ] Secret Manager API enabled in pcc-prj-app-devtest
- [ ] GKE Hub API enabled in pcc-prj-devops-nonprod
- [ ] Connect Gateway API enabled in pcc-prj-devops-nonprod
- [ ] GKE Hub API enabled in pcc-prj-devops-prod
- [ ] Connect Gateway API enabled in pcc-prj-devops-prod

---

## Troubleshooting

### Issue: "API not found"
**Resolution**: Verify API name spelling matches Google Cloud exactly
```bash
gcloud services list --available | grep -i secretmanager
gcloud services list --available | grep -i gkehub
gcloud services list --available | grep -i connectgateway
```

---

### Issue: "Insufficient permissions"
**Resolution**: Ensure service account has `roles/serviceusage.serviceUsageAdmin`
```bash
gcloud projects get-iam-policy pcc-prj-app-devtest --flatten="bindings[].members" --filter="bindings.role:roles/serviceusage.serviceUsageAdmin"
```

---

### Issue: "API already enabled"
**Resolution**: Terraform will import existing state automatically. No action needed.

---

## Next Phase Dependencies

**Phase 2** can proceed after:
- ✅ `secretmanager.googleapis.com` enabled in `pcc-prj-app-devtest`

**Phase 3** can proceed after:
- ✅ `container.googleapis.com` already enabled (was there)

**Phase 4** can proceed after:
- ✅ `gkehub.googleapis.com` enabled in devops projects
- ✅ `connectgateway.googleapis.com` enabled in devops projects

---

## Time Estimate

- **Navigate + format**: 1 minute
- **Validate**: 30 seconds
- **Plan**: 1 minute
- **Apply**: 2-3 minutes
- **Verify**: 1-2 minutes
- **Total**: 5-7 minutes

---

## References

- **Secret Manager**: https://cloud.google.com/secret-manager/docs
- **GKE Hub**: https://cloud.google.com/anthos/fleet-management/docs/fleet-concepts
- **Connect Gateway**: https://cloud.google.com/anthos/multicluster-management/gateway

---

**Status**: Ready for execution
**Tool**: WARP (CLI commands only)
**Next**: Phase 2.1 - Create AlloyDB Module Skeleton (Claude Code)
