# Phase 3.5: Terraform Validation

**Phase**: 3.5 (GKE Clusters - Terraform Validation)
**Duration**: 15-20 minutes
**Type**: Validation
**Status**: 📋 Planning (Not Started)
**Date**: TBD (10/21+)

---

## Objective

Validate all terraform configurations for GKE clusters and cross-project IAM bindings before deployment via WARP.

## Prerequisites

✅ Phase 3.3 completed (GKE cluster terraform documented)
✅ Phase 3.4 completed (Cross-project IAM bindings documented)
✅ Terraform code written in `infra/pcc-app-shared-infra/terraform/`
✅ Access to WARP terminal

---

## Repository

**Working Directory**: `infra/pcc-app-shared-infra/terraform/`

**Files to Validate**:
- `main.tf` (3 GKE cluster module calls)
- `iam.tf` (3 cross-project IAM binding patterns)
- `variables.tf` (input variables)
- `outputs.tf` (cluster outputs)
- `backend.tf` (GCS state backend)
- `versions.tf` (terraform/provider versions)

---

## Validation Steps

### Step 1: Terraform Format

**Purpose**: Ensure consistent formatting across all terraform files

**Commands** (from WARP):
```bash
cd ~/pcc/infra/pcc-app-shared-infra/terraform

# Format all terraform files recursively
terraform fmt -recursive

# Verify no changes (should show no output if already formatted)
terraform fmt -check -recursive
```

**Expected Result**: No output (all files already formatted)

**If Changes**: Files will be reformatted automatically. Review changes and commit.

---

### Step 2: Terraform Init

**Purpose**: Initialize terraform working directory and download providers

**Commands**:
```bash
cd ~/pcc/infra/pcc-app-shared-infra/terraform

# Initialize terraform (download providers, configure backend)
terraform init

# Expected output:
# - Provider google downloaded
# - Backend configured (GCS bucket)
# - Terraform initialized successfully
```

**Expected Output**:
```
Initializing the backend...
Initializing provider plugins...
- Finding latest version of hashicorp/google...
- Installing hashicorp/google vX.X.X...

Terraform has been successfully initialized!
```

**Troubleshooting**:
- If backend error: Verify GCS bucket exists and is accessible
- If provider error: Check internet connection, verify provider version in `versions.tf`

---

### Step 3: Terraform Validate

**Purpose**: Check terraform syntax and configuration errors

**Commands**:
```bash
cd ~/pcc/infra/pcc-app-shared-infra/terraform

# Validate terraform configuration
terraform validate

# Expected output: "Success! The configuration is valid."
```

**Expected Output**:
```
Success! The configuration is valid.
```

**Common Errors**:
- Missing required variables
- Invalid resource references
- Syntax errors in HCL
- Module source not found

**If Errors**: Fix syntax errors, verify module sources, check variable definitions.

---

### Step 4: Terraform Plan

**Purpose**: Preview changes terraform will make (dry run)

**Commands**:
```bash
cd ~/pcc/infra/pcc-app-shared-infra/terraform

# Generate terraform plan
terraform plan -out=tfplan

# Review plan output
# Expected: 3 GKE clusters + 2 SAs + 6 IAM bindings = 11 resources to create
# Note: WI bindings (2 resources) moved to Phase 4 after K8s SAs created
```

**Expected Resource Counts**:

**GKE Clusters** (3 total):
- `module.gke_devops_nonprod.google_container_cluster.autopilot_cluster`
- `module.gke_devops_prod.google_container_cluster.autopilot_cluster`
- `module.gke_app_devtest.google_container_cluster.autopilot_cluster`

**ArgoCD Service Accounts** (2 total):
- `google_service_account.argocd_prod` (ArgoCD Prod)
- `google_service_account.argocd_nonprod` (ArgoCD Nonprod)

**Workload Identity Bindings** (2 total):
- `google_service_account_iam_member.argocd_prod_workload_identity`
- `google_service_account_iam_member.argocd_nonprod_workload_identity`

**ArgoCD IAM Bindings** (4 total):
- `google_project_iam_member.argocd_prod_to_gke_devops_nonprod`
- `google_project_iam_member.argocd_prod_to_gke_devops_prod`
- `google_project_iam_member.argocd_prod_to_gke_app_devtest`
- `google_project_iam_member.argocd_nonprod_to_gke_devops_nonprod`

**Cloud Build IAM Bindings** (2 total):
- `google_project_iam_member.cloudbuild_to_artifact_registry`
- `google_project_iam_member.cloudbuild_to_secret_manager`

**Total**: 11 resources to create
**Note**: Workload Identity bindings (2 resources) moved to Phase 4

**Plan Output Review**:
```
Terraform will perform the following actions:

  # module.gke_devops_nonprod.google_container_cluster.autopilot_cluster will be created
  + resource "google_container_cluster" "autopilot_cluster" {
      + name               = "pcc-gke-devops-nonprod"
      + project            = "pcc-prj-devops-nonprod"
      + location           = "us-east4"
      + enable_autopilot   = true
      ...
    }

  # module.gke_devops_prod.google_container_cluster.autopilot_cluster will be created
  + resource "google_container_cluster" "autopilot_cluster" {
      + name               = "pcc-gke-devops-prod"
      + project            = "pcc-prj-devops-prod"
      + location           = "us-east4"
      + enable_autopilot   = true
      ...
    }

  # module.gke_app_devtest.google_container_cluster.autopilot_cluster will be created
  + resource "google_container_cluster" "autopilot_cluster" {
      + name               = "pcc-gke-app-devtest"
      + project            = "pcc-prj-app-devtest"
      + location           = "us-east4"
      + enable_autopilot   = true
      ...
    }

  # google_project_iam_member.cloudbuild_to_artifact_registry will be created
  + resource "google_project_iam_member" "cloudbuild_to_artifact_registry" {
      + project = "pcc-prj-devops-prod"
      + role    = "roles/artifactregistry.writer"
      + member  = "serviceAccount:<NUMBER>@cloudbuild.gserviceaccount.com"
      ...
    }

  # google_project_iam_member.cloudbuild_to_secret_manager will be created
  + resource "google_project_iam_member" "cloudbuild_to_secret_manager" {
      + project = "pcc-prj-app-devtest"
      + role    = "roles/secretmanager.secretAccessor"
      + member  = "serviceAccount:<NUMBER>@cloudbuild.gserviceaccount.com"
      ...
    }

  # google_service_account.argocd_prod will be created
  + resource "google_service_account" "argocd_prod" {
      + account_id   = "argocd-controller"
      + display_name = "ArgoCD Controller (Production)"
      + project      = "pcc-prj-devops-prod"
      ...
    }

  # google_service_account.argocd_nonprod will be created
  + resource "google_service_account" "argocd_nonprod" {
      + account_id   = "argocd-controller"
      + display_name = "ArgoCD Controller (Nonprod)"
      + project      = "pcc-prj-devops-nonprod"
      ...
    }

  # google_service_account_iam_member.argocd_prod_workload_identity will be created
  + resource "google_service_account_iam_member" "argocd_prod_workload_identity" {
      + role    = "roles/iam.workloadIdentityUser"
      + member  = "serviceAccount:pcc-prj-devops-prod.svc.id.goog[argocd/argocd-application-controller]"
      ...
    }

  # google_service_account_iam_member.argocd_nonprod_workload_identity will be created
  + resource "google_service_account_iam_member" "argocd_nonprod_workload_identity" {
      + role    = "roles/iam.workloadIdentityUser"
      + member  = "serviceAccount:pcc-prj-devops-nonprod.svc.id.goog[argocd/argocd-application-controller]"
      ...
    }

  # google_project_iam_member.argocd_prod_to_gke_devops_nonprod will be created
  + resource "google_project_iam_member" "argocd_prod_to_gke_devops_nonprod" {
      + project = "pcc-prj-devops-nonprod"
      + role    = "roles/container.admin"
      + member  = "serviceAccount:argocd-controller@pcc-prj-devops-prod.iam.gserviceaccount.com"
      ...
    }

  # google_project_iam_member.argocd_prod_to_gke_devops_prod will be created
  + resource "google_project_iam_member" "argocd_prod_to_gke_devops_prod" {
      + project = "pcc-prj-devops-prod"
      + role    = "roles/container.admin"
      + member  = "serviceAccount:argocd-controller@pcc-prj-devops-prod.iam.gserviceaccount.com"
      ...
    }

  # google_project_iam_member.argocd_prod_to_gke_app_devtest will be created
  + resource "google_project_iam_member" "argocd_prod_to_gke_app_devtest" {
      + project = "pcc-prj-app-devtest"
      + role    = "roles/container.admin"
      + member  = "serviceAccount:argocd-controller@pcc-prj-devops-prod.iam.gserviceaccount.com"
      ...
    }

  # google_project_iam_member.argocd_nonprod_to_gke_devops_nonprod will be created
  + resource "google_project_iam_member" "argocd_nonprod_to_gke_devops_nonprod" {
      + project = "pcc-prj-devops-nonprod"
      + role    = "roles/container.admin"
      + member  = "serviceAccount:argocd-controller@pcc-prj-devops-nonprod.iam.gserviceaccount.com"
      ...
    }

Plan: 15 to add, 0 to change, 0 to destroy.
```

---

### Step 5: Verify Plan Details

**Cluster Configuration Validation**:

**DevOps Nonprod**:
- [ ] Name: `pcc-gke-devops-nonprod`
- [ ] Project: `pcc-prj-devops-nonprod`
- [ ] Region: `us-east4`
- [ ] Autopilot: `true`
- [ ] Private nodes: `true`
- [ ] Workload Identity: enabled
- [ ] Network: `pcc-vpc-shared`
- [ ] Subnetwork: `pcc-subnet-devops-nonprod`
- [ ] Secondary ranges: pods and services (from Phase 1.1)

**DevOps Prod**:
- [ ] Name: `pcc-gke-devops-prod`
- [ ] Project: `pcc-prj-devops-prod`
- [ ] Region: `us-east4`
- [ ] Autopilot: `true`
- [ ] Private nodes: `true`
- [ ] Workload Identity: enabled
- [ ] Network: `pcc-vpc-shared`
- [ ] Subnetwork: `pcc-subnet-devops-prod`
- [ ] Secondary ranges: pods and services (from Phase 1.1)

**App Devtest**:
- [ ] Name: `pcc-gke-app-devtest`
- [ ] Project: `pcc-prj-app-devtest`
- [ ] Region: `us-east4`
- [ ] Autopilot: `true`
- [ ] Private nodes: `true`
- [ ] Workload Identity: enabled
- [ ] Network: `pcc-vpc-shared`
- [ ] Subnetwork: `pcc-subnet-app-devtest`
- [ ] Secondary ranges: pods and services (from Phase 1)

**IAM Binding Validation**:
- [ ] Cloud Build → Artifact Registry (role: `artifactregistry.writer`)
- [ ] Cloud Build → Secret Manager (role: `secretmanager.secretAccessor`)
- [ ] ArgoCD → DevOps Nonprod GKE (role: `container.admin`)
- [ ] ArgoCD → DevOps Prod GKE (role: `container.admin`)
- [ ] ArgoCD → App Devtest GKE (role: `container.admin`)

---

### Step 6: Check for Unexpected Changes

**No Deletions Expected**:
- Plan should show `0 to destroy`
- If deletions shown: STOP and investigate

**No Modifications Expected**:
- Plan should show `0 to change`
- If modifications shown: Review carefully (may indicate drift)

**Only Additions Expected**:
- Plan should show `15 to add` (3 clusters + 2 SAs + 10 IAM bindings: 4 container.admin + 4 gkehub.gatewayAdmin + 2 Cloud Build)
- Note: Workload Identity bindings (2 resources) moved to Phase 4 when K8s SAs exist

---

## Validation Checklist

### Terraform Format
- [ ] No formatting issues (`terraform fmt -check` shows no changes)

### Terraform Init
- [ ] Terraform initialized successfully
- [ ] Google provider downloaded
- [ ] Backend configured (GCS)

### Terraform Validate
- [ ] Validation successful (`terraform validate` passes)
- [ ] No syntax errors
- [ ] All modules found

### Terraform Plan
- [ ] Plan generated successfully (`terraform plan -out=tfplan`)
- [ ] 15 resources to add (3 clusters + 2 SAs + 10 IAM bindings: 4 container.admin + 4 gkehub.gatewayAdmin + 2 Cloud Build)
- [ ] 0 resources to change
- [ ] 0 resources to destroy
- [ ] All cluster names correct
- [ ] All cluster projects correct
- [ ] All cluster regions correct (us-east4)
- [ ] All clusters have Autopilot enabled
- [ ] All clusters have Workload Identity enabled
- [ ] App devtest cluster has secondary ranges
- [ ] DevOps clusters have secondary ranges
- [ ] All IAM bindings have correct roles
- [ ] All IAM bindings have correct principals
- [ ] ArgoCD bindings target all 3 projects

---

## Troubleshooting

### Common Issues

**Issue 1: Module Not Found**
```
Error: Module not installed
```
**Solution**: Run `terraform init` to download modules

**Issue 2: Backend Not Configured**
```
Error: Backend initialization required
```
**Solution**: Verify `backend.tf` exists, run `terraform init`

**Issue 3: Invalid Credentials**
```
Error: google: could not find default credentials
```
**Solution**: Verify WARP terminal has GCP credentials configured

**Issue 4: Resource Already Exists**
```
Error: Error creating Cluster: googleapi: Error 409: Already exists
```
**Solution**: Review terraform state, may need to import existing resources

**Issue 5: Permission Denied**
```
Error: Error creating IAM binding: Permission denied
```
**Solution**: Verify your user account has `resourcemanager.projectIamAdmin` role

---

## Deliverables

- [ ] Terraform formatted (`terraform fmt`)
- [ ] Terraform initialized (`terraform init`)
- [ ] Terraform validated (`terraform validate`)
- [ ] Terraform plan generated (`terraform plan -out=tfplan`)
- [ ] Plan reviewed and approved
- [ ] All validation criteria met

---

## Validation Criteria

- [ ] No terraform format issues
- [ ] No validation errors
- [ ] Plan shows expected resource counts (11 resources total)
- [ ] No unexpected deletions or modifications
- [ ] All cluster configurations correct
- [ ] All ArgoCD service accounts configured
- [ ] All Workload Identity bindings configured
- [ ] All IAM bindings correct
- [ ] Ready for Phase 3.6 (WARP deployment)

---

## Dependencies

**Upstream**:
- Phase 3.3: GKE cluster terraform
- Phase 3.4: Cross-project IAM bindings

**Downstream**:
- Phase 3.6: WARP deployment (apply terraform plan)

---

## Notes

- **Plan file**: Saved as `tfplan` for use in Phase 3.6
- **Review carefully**: Once deployed, clusters take 10-15 minutes to provision
- **No rollback**: GKE clusters cannot be easily rolled back (destructive operation)
- **Cost implications**: 3 Autopilot clusters will incur costs (even without workloads)
- **Validation only**: No changes made to infrastructure in this phase

---

## Time Estimate

**Total**: 15-20 minutes
- 2 min: `terraform fmt -recursive`
- 3 min: `terraform init`
- 2 min: `terraform validate`
- 5 min: `terraform plan` (generate plan)
- 5 min: Review plan output and verify configurations

---

**Next Phase**: 3.6 - WARP Deployment (Clusters & IAM)
