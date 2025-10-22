# Phase 3.2: Review Existing GKE Infrastructure

**Phase**: 3.2 (GKE Clusters - Infrastructure Review)
**Duration**: 15-20 minutes
**Type**: Planning/Audit
**Status**: 📋 Planning (Not Started)
**Date**: TBD (10/21+)

---

## Objective

Audit current foundation state and identify prerequisites for deploying 3 GKE Autopilot clusters across devops-nonprod, devops-prod, and app-devtest projects.

## Prerequisites

✅ **Phase 3.1 completed** - Connect Gateway APIs enabled (BLOCKING)
✅ Phase 0 completed (Projects created)
✅ Phase 1 completed (VPC networking with subnets)
✅ Phase 2 completed (AlloyDB cluster deployed)
✅ Understanding of GKE Autopilot requirements
✅ Access to WARP terminal for terraform operations

---

## Repositories to Review

### 1. core/pcc-foundation-infra

**Purpose**: Existing VPC and subnet configuration

**What to Review**:
- Current terraform state
- Existing VPC: `pcc-vpc-shared`
- Existing subnets created in earlier phases

**Expected Subnets**:
- **DevOps Nonprod**: 10.24.128.0/20 (pcc-prj-devops-nonprod)
- **DevOps Prod**: 10.16.128.0/20 (pcc-prj-devops-prod)
- **App Devtest**: 10.28.0.0/20 + secondary ranges (pcc-prj-app-devtest)

**Commands** (from WARP):
```bash
cd ~/pcc/core/pcc-foundation-infra/terraform
terraform state list | grep subnet
terraform show | grep -A 10 "google_compute_subnetwork"
```

---

### 2. infra/pcc-app-shared-infra

**Purpose**: Target repository for Phase 3 terraform

**What to Review**:
- Current directory structure
- Existing terraform modules (if any)
- State file location
- Backend configuration

**Expected Structure**:
```
infra/pcc-app-shared-infra/
├── terraform/
│   ├── main.tf          (module calls for 3 GKE clusters)
│   ├── variables.tf     (cluster configurations)
│   ├── outputs.tf       (cluster endpoints, credentials)
│   ├── backend.tf       (GCS state backend)
│   └── iam.tf           (cross-project IAM bindings)
```

**Commands** (from WARP):
```bash
cd ~/pcc/infra/pcc-app-shared-infra
ls -la terraform/
cat terraform/backend.tf  # Verify GCS backend
```

---

## GKE Autopilot Requirements

### Cluster Configuration

**Common Settings** (all 3 clusters):
- **Mode**: Autopilot (Google-managed nodes)
- **Visibility**: Private clusters (no external node IPs)
- **Workload Identity**: Enabled (required for GCP IAM integration)
- **Region**: us-east4
- **Release Channel**: Regular (stable updates)
- **Network**: `pcc-vpc-shared` (existing VPC)

### Network Requirements

**Each cluster requires**:
1. **Primary subnet**: For nodes
2. **Secondary range (pods)**: For pod IP allocation
3. **Secondary range (services)**: For Kubernetes service IPs

**App Devtest Cluster** (created in Phase 1):
- Primary: 10.28.0.0/20
- Pods: 10.28.16.0/20
- Services: 10.28.32.0/20

**DevOps Clusters** (existing from foundation):
- Nonprod: 10.24.128.0/20 + secondary ranges (pods: pcc-prj-devops-nonprod-sub-pod, services: pcc-prj-devops-nonprod-sub-svc)
- Prod: 10.16.128.0/20 + secondary ranges (pods: pcc-prj-devops-prod-sub-pod, services: pcc-prj-devops-prod-sub-svc)

---

## Infrastructure Audit Checklist

### Network Validation

- [ ] VPC `pcc-vpc-shared` exists
- [ ] DevOps nonprod subnet (10.24.128.0/20) exists
- [ ] DevOps prod subnet (10.16.128.0/20) exists
- [ ] App devtest subnet (10.28.0.0/20) exists
- [ ] App devtest secondary ranges configured (pods, services)
- [ ] App devtest secondary range names verified (`pcc-subnet-app-devtest-pods`, `pcc-subnet-app-devtest-services`)
- [ ] DevOps nonprod secondary range names verified (`pcc-prj-devops-nonprod-sub-pod`, `pcc-prj-devops-nonprod-sub-svc`)
- [ ] DevOps prod secondary range names verified (`pcc-prj-devops-prod-sub-pod`, `pcc-prj-devops-prod-sub-svc`)

### Project Validation

- [ ] Project `pcc-prj-devops-nonprod` exists
- [ ] Project `pcc-prj-devops-prod` exists
- [ ] Project `pcc-prj-app-devtest` exists
- [ ] GKE API enabled in all 3 projects

### Terraform State

- [ ] `core/pcc-foundation-infra` state accessible
- [ ] `infra/pcc-app-shared-infra` backend configured
- [ ] No existing GKE clusters in terraform state

---

## Prerequisites Documentation

### Required Information for Phase 3.2

**Collect for Terraform Module**:
1. **Network IDs**:
   - VPC: `pcc-vpc-shared` (self_link)
   - Subnet self_links for all 3 subnets

2. **Project Details**:
   - Project IDs for all 3 projects
   - Project numbers (for service accounts)

3. **Region/Zone**:
   - Region: us-east4
   - Zones: us-east4-a, us-east4-b, us-east4-c

4. **GCS Backend**:
   - Backend bucket name
   - State file prefix

**Backend Configuration** (`infra/pcc-app-shared-infra/terraform/backend.tf`):
```hcl
terraform {
  backend "gcs" {
    bucket  = "pcc-terraform-state"
    prefix  = "pcc-app-shared-infra"
  }
}
```

**Verify Backend Bucket Exists**:
```bash
gsutil ls gs://pcc-terraform-state/
# Should return bucket listing or create bucket if doesn't exist:
# gsutil mb -p pcc-app-shared-infra -l us-east4 gs://pcc-terraform-state/
```

**Commands to Collect**:
```bash
# Get VPC self_link
gcloud compute networks describe pcc-vpc-shared --format="value(selfLink)"

# Get subnet self_links
gcloud compute networks subnets describe pcc-subnet-devops-nonprod --region=us-east4 --format="value(selfLink)"
gcloud compute networks subnets describe pcc-subnet-devops-prod --region=us-east4 --format="value(selfLink)"
gcloud compute networks subnets describe pcc-subnet-app-devtest --region=us-east4 --format="value(selfLink)"

# Verify app-devtest secondary range names (required for GKE)
gcloud compute networks subnets describe pcc-subnet-app-devtest --region=us-east4 --format="json" | jq '.secondaryIpRanges[] | .rangeName'
# Expected output:
# "pcc-subnet-app-devtest-pods"
# "pcc-subnet-app-devtest-services"

# Verify DevOps nonprod secondary range names (required for GKE)
gcloud compute networks subnets describe pcc-subnet-devops-nonprod --region=us-east4 --format="json" | jq '.secondaryIpRanges[] | .rangeName'
# Expected output:
# "pcc-prj-devops-nonprod-sub-pod"
# "pcc-prj-devops-nonprod-sub-svc"

# Verify DevOps prod secondary range names (required for GKE)
gcloud compute networks subnets describe pcc-subnet-devops-prod --region=us-east4 --format="json" | jq '.secondaryIpRanges[] | .rangeName'
# Expected output:
# "pcc-prj-devops-prod-sub-pod"
# "pcc-prj-devops-prod-sub-svc"

# Get project numbers (required for Cloud Build service account)
gcloud projects describe pcc-prj-devops-nonprod --format="value(projectNumber)"
gcloud projects describe pcc-prj-devops-prod --format="value(projectNumber)"
gcloud projects describe pcc-prj-app-devtest --format="value(projectNumber)"

# Cloud Build service account format (auto-created when Cloud Build API enabled):
# <PROJECT_NUMBER>@cloudbuild.gserviceaccount.com
# Example: 123456789012@cloudbuild.gserviceaccount.com
```

---

## GKE API Enablement

### Verify APIs Enabled

**Required APIs** (all 3 projects):
- `container.googleapis.com` (GKE)
- `compute.googleapis.com` (Compute Engine)
- `iam.googleapis.com` (IAM)

**Commands**:
```bash
# Check if GKE API is enabled
gcloud services list --enabled --project=pcc-prj-devops-nonprod | grep container
gcloud services list --enabled --project=pcc-prj-devops-prod | grep container
gcloud services list --enabled --project=pcc-prj-app-devtest | grep container

# Enable if needed (should already be enabled from Phase 0)
gcloud services enable container.googleapis.com --project=pcc-prj-devops-nonprod
gcloud services enable container.googleapis.com --project=pcc-prj-devops-prod
gcloud services enable container.googleapis.com --project=pcc-prj-app-devtest
```

---

## Deliverables

- [x] Infrastructure audit summary (this document)
- [ ] Subnet verification complete (all 3 subnets exist)
- [ ] Network self_links collected
- [ ] Project numbers collected
- [ ] GKE APIs verified enabled
- [ ] Prerequisites checklist completed

---

## Validation Criteria

- [x] All 3 subnets exist in VPC
- [ ] All 3 projects have GKE API enabled
- [ ] Terraform state accessible for both repos
- [ ] Network details collected for Phase 3.2

---

## Dependencies

**Upstream**:
- Phase 0: Projects created
- Phase 1: VPC and subnets created (app-devtest with secondary ranges)

**Downstream**:
- Phase 3.2: Will use network details to create terraform module

---

## Notes

- **No changes to infrastructure** in this phase (audit only)
- **Existing subnets** from Phase 1 will be used (no new subnets)
- **Secondary ranges** required for all 3 clusters (pods and services)
- **DevOps clusters** have secondary ranges created in Phase 1.1 foundation
- **App-devtest cluster** has secondary ranges created in Phase 1
- **Terraform state** for GKE clusters will be in `infra/pcc-app-shared-infra`

---

## Time Estimate

**Total**: 15-20 minutes
- 5 min: Review `core/pcc-foundation-infra` state
- 5 min: Review `infra/pcc-app-shared-infra` structure
- 5 min: Collect network details and project numbers
- 5 min: Verify GKE APIs enabled

---

**Next Phase**: 3.3 - GKE Cluster Terraform
