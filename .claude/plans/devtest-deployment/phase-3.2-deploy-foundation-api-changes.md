# Phase 3.2: Deploy Foundation API Changes

**Phase**: 3.2 (GKE Infrastructure - API Deployment)
**Duration**: 5-10 minutes
**Type**: Deployment
**Status**: Ready for Execution

---

## Execution Tool

**Use WARP for this phase** - Executing terraform commands for API enablement.

---

## Objective

Deploy GKE API configurations to foundation infrastructure using terraform, enabling required APIs before GKE module creation.

## Prerequisites

✅ Phase 3.1 completed (API configurations added to `apis.tf`)
✅ `pcc-foundation-infra` repository accessible
✅ Terraform initialized in foundation infra
✅ GCP credentials configured for foundation project

---

## Step 1: Navigate to Foundation Infrastructure

```bash
cd ~/pcc/pcc-foundation-infra/terraform
```

---

## Step 2: Review Terraform Plan

Run terraform plan to review API changes:

```bash
terraform plan
```

**Expected Output**:
```
Terraform will perform the following actions:

  # google_project_service.anthosconfigmanagement will be created
  + resource "google_project_service" "anthosconfigmanagement" {
      + id                   = (known after apply)
      + project              = "pcc-prj-foundation"
      + service              = "anthosconfigmanagement.googleapis.com"
      + disable_on_destroy   = false
    }

  # google_project_service.connectgateway will be created
  + resource "google_project_service" "connectgateway" {
      + id                   = (known after apply)
      + project              = "pcc-prj-foundation"
      + service              = "connectgateway.googleapis.com"
      + disable_on_destroy   = false
    }

  # google_project_service.container will be created
  + resource "google_project_service" "container" {
      + id                   = (known after apply)
      + project              = "pcc-prj-foundation"
      + service              = "container.googleapis.com"
      + disable_on_destroy   = false
    }

  # google_project_service.gkehub will be created
  + resource "google_project_service" "gkehub" {
      + id                   = (known after apply)
      + project              = "pcc-prj-foundation"
      + service              = "gkehub.googleapis.com"
      + disable_on_destroy   = false
    }

Plan: 4 to add, 0 to change, 0 to destroy.
```

**Validation**:
- ✅ Exactly 4 resources to add
- ✅ 0 to change, 0 to destroy
- ✅ All services use `disable_on_destroy = false`
- ✅ Correct project ID displayed

---

## Step 3: Apply Terraform Changes

Deploy the API configurations:

```bash
terraform apply
```

**Expected Prompts**:
```
Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes
```

Type `yes` to proceed.

**Expected Output**:
```
google_project_service.container: Creating...
google_project_service.gkehub: Creating...
google_project_service.connectgateway: Creating...
google_project_service.anthosconfigmanagement: Creating...
google_project_service.container: Creation complete after 45s [id=pcc-prj-foundation/container.googleapis.com]
google_project_service.gkehub: Creation complete after 48s [id=pcc-prj-foundation/gkehub.googleapis.com]
google_project_service.connectgateway: Creation complete after 52s [id=pcc-prj-foundation/connectgateway.googleapis.com]
google_project_service.anthosconfigmanagement: Creation complete after 55s [id=pcc-prj-foundation/anthosconfigmanagement.googleapis.com]

Apply complete! Resources: 4 added, 0 changed, 0 destroyed.
```

**Note**: API enablement can take 30-60 seconds per API.

---

## Step 4: Verify API Enablement

Verify APIs are enabled in GCP:

```bash
gcloud services list --enabled --project=pcc-prj-foundation | grep -E "(container|gkehub|connectgateway|anthosconfigmanagement)"
```

**Expected Output**:
```
anthosconfigmanagement.googleapis.com  Anthos Config Management API
connectgateway.googleapis.com          Connect Gateway API
container.googleapis.com               Kubernetes Engine API
gkehub.googleapis.com                  GKE Hub API
```

**Validation**:
- ✅ All 4 APIs listed as enabled
- ✅ No error messages
- ✅ Services show correct display names

---

## Troubleshooting

### Issue: API Already Enabled

**Symptom**:
```
Error: Error creating Service: googleapi: Error 409: Service container.googleapis.com has already been enabled
```

**Resolution**:
```bash
terraform import google_project_service.container pcc-prj-foundation/container.googleapis.com
terraform apply
```

Repeat for each pre-enabled API.

### Issue: Permission Denied

**Symptom**:
```
Error: Error creating Service: googleapi: Error 403: The caller does not have permission
```

**Resolution**:
- Verify you have `roles/serviceusage.serviceUsageAdmin` role
- Check `gcloud auth list` shows correct account
- Re-authenticate: `gcloud auth application-default login`

---

## Validation Checklist

- [ ] `terraform plan` shows 4 resources to add
- [ ] `terraform apply` completes successfully
- [ ] All 4 APIs created without errors
- [ ] `gcloud services list` confirms APIs enabled
- [ ] No permission or quota errors
- [ ] State file updated in GCS backend

---

## API Propagation Time

**Important**: Allow 2-3 minutes for API propagation before Phase 3.3

APIs are enabled immediately, but:
- IAM bindings may take 1-2 minutes to propagate
- Resource quota allocations may take 2-3 minutes
- Best practice: Wait 5 minutes before creating GKE resources

---

## Next Phase Dependencies

**Phase 3.3** will:
- Begin creating GKE Autopilot module in `pcc-tf-library`
- Rely on these APIs being enabled in foundation
- Use `container.googleapis.com` for GKE resources

---

## References

- **API Enablement**: https://cloud.google.com/service-usage/docs/enable-disable
- **Terraform google_project_service**: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_service

---

## Time Estimate

- **Review plan**: 2 minutes
- **Apply changes**: 3-5 minutes (API enablement time)
- **Verify APIs**: 2-3 minutes
- **Total**: 5-10 minutes (+ 5 minute wait for propagation)

---

**Status**: Ready for execution
**Next**: Phase 3.3 - Create GKE Module (versions.tf)
