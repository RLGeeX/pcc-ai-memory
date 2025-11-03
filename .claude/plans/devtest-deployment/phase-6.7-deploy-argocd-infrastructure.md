# Phase 6.7: Deploy ArgoCD Infrastructure

**Tool**: [WARP] Partner Execution
**Estimated Duration**: 15 minutes

## Purpose

Deploy Terraform infrastructure: 6 GCP service accounts, 6 Workload Identity bindings, 1 SSL certificate, 1 GCS bucket for Velero backups.

## Prerequisites

- Phase 6.4 completed (Terraform configuration exists)
- gcloud CLI authenticated with appropriate permissions
- kubectl configured for pcc-prj-devops-nonprod cluster
- Terraform >= 1.6.0 installed

## Detailed Steps

### Step 1: Navigate to Configuration Directory

```bash
cd /home/jfogarty/pcc/infra/pcc-devops-infra/argocd-nonprod/devtest
```

### Step 2: Initialize Terraform

```bash
# Always use -upgrade with force-pushed tags
terraform init -upgrade
```

Expected output:
```
Terraform has been successfully initialized!
```

### Step 3: Review Plan

```bash
terraform plan -out=tfplan
```

Review the plan output. Should show approximately:
- **6** `google_service_account` resources to add
- **6** `google_service_account_iam_binding` resources to add (Workload Identity)
- **5** `google_project_iam_member` resources to add (IAM roles)
- **1** `google_storage_bucket` resource to add (Velero backups)
- **1** `google_storage_bucket_iam_member` resource to add
- **1** `google_compute_managed_ssl_certificate` resource to add

**Total**: ~20 resources to add, 0 to change, 0 to destroy

### Step 4: Apply Infrastructure

```bash
terraform apply tfplan
```

Monitor output for errors. Application should complete in ~2-3 minutes.

Expected final message:
```
Apply complete! Resources: 20 added, 0 changed, 0 destroyed.
```

### Step 5: Verify Outputs

```bash
terraform output
```

Verify all service account emails are displayed:
- `argocd_controller_sa_email`
- `argocd_server_sa_email`
- `argocd_dex_sa_email`
- `argocd_redis_sa_email`
- `externaldns_sa_email`
- `velero_sa_email`

### Step 6: Verify GCS Bucket

```bash
gsutil ls -L gs://pcc-argocd-backups-nonprod | grep -A2 "Lifecycle"
```

Expected output showing 3-day deletion rule:
```
Lifecycle Configuration:
  Delete: [age: 3]
```

### Step 7: Verify SSL Certificate Status

```bash
gcloud compute ssl-certificates describe argocd-nonprod-cert --global --format='get(managed.status)'
```

Expected: `PROVISIONING` (will transition to ACTIVE after Ingress created in Phase 6.16)

## Success Criteria

- ✅ `terraform apply` completes without errors
- ✅ All 20 resources created successfully
- ✅ All 6 service account emails displayed in outputs
- ✅ GCS bucket exists with 3-day lifecycle policy
- ✅ SSL certificate in PROVISIONING state
- ✅ No IAM permission errors

## HALT Conditions

**HALT if**:
- terraform apply fails with errors
- GCS bucket name conflict (already exists)
- IAM permission denied errors
- Service account creation fails

**Resolution**:
- Check terraform state for partial deployments: `terraform state list`
- Verify bucket name is globally unique
- Validate IAM permissions: `gcloud projects get-iam-policy pcc-prj-devops-nonprod`
- Review terraform error messages for specific resource failures

## Next Phase

Proceed to **Phase 6.8**: Pre-flight Validation

## Notes

- Infrastructure creation is idempotent - safe to re-run if needed
- SSL certificate will remain in PROVISIONING until Ingress is created (Phase 6.16)
- GCS bucket lifecycle applies to all objects (Velero backups deleted after 3 days)
- Workload Identity bindings allow K8s service accounts to authenticate as GCP service accounts
- This phase does NOT deploy ArgoCD itself - only infrastructure prerequisites
