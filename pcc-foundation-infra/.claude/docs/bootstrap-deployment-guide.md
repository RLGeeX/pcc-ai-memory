# PCC Foundation Infrastructure - Bootstrap & Deployment Guide

**Version:** 1.0
**Last Updated:** 2025-10-02
**Status:** Production Ready

---

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Phase 1: Bootstrap Execution](#phase-1-bootstrap-execution)
4. [Phase 2: Foundation Deployment](#phase-2-foundation-deployment)
5. [Validation Procedures](#validation-procedures)
6. [Troubleshooting](#troubleshooting)
7. [Rollback Procedures](#rollback-procedures)

---

## Overview

This guide walks through the complete deployment of PCC's foundational GCP infrastructure using a two-phase approach:

1. **Bootstrap Phase**: Creates the Terraform service account, state bucket, and required IAM permissions
2. **Foundation Phase**: Deploys the complete infrastructure (folders, projects, networking, IAM, org policies)

**Key Principles:**
- Bootstrap and foundation are **completely separated**
- The service account **cannot modify its own permissions** (security best practice)
- All Terraform operations use **service account impersonation** via short-lived tokens
- Zero manual IAM binding in Terraform for the service account itself

**Estimated Total Time:** 45-60 minutes

---

## Prerequisites

### 1. Access Requirements

Verify you have the following:

- [ ] **Google Cloud Organization Admin** access to org `146990108557`
- [ ] **Billing Account Administrator** access to billing account `01AFEA-2B972B-00C55F`
- [ ] SSH/terminal access to the deployment machine (`/home/cfogarty/git/pcc-foundation-infra`)

### 2. Tool Validation

Run these checks to ensure all required tools are installed:

```bash
# Check gcloud CLI (required version: 400.0.0+)
gcloud --version

# Check Terraform CLI (required version: 1.5.0+)
terraform --version

# Verify gcloud authentication
gcloud auth list

# Verify correct GCP organization access
gcloud organizations list
# Expected output: 146990108557  pcconnect.ai
```

**Expected Output:**
```
Google Cloud SDK 400.0.0+
Terraform v1.5.0+
Credentialed Accounts: [your-email@pcconnect.ai]
```

### 3. Google Workspace Groups

**CRITICAL:** Verify these groups exist in Google Workspace before deployment:

```bash
# Run the group validation script
cd /home/cfogarty/git/pcc-foundation-infra
./check-groups.sh
```

**Expected Output:**
```
✅ gcp-admins@pcconnect.ai - exists
✅ gcp-developers@pcconnect.ai - exists
✅ gcp-break-glass@pcconnect.ai - exists
✅ gcp-auditors@pcconnect.ai - exists
✅ gcp-cicd@pcconnect.ai - exists
```

⚠️ **WARNING:** If any group is missing, create it in Google Workspace Admin Console before proceeding.

### 4. Repository Validation

Verify the codebase is ready:

```bash
cd /home/cfogarty/git/pcc-foundation-infra

# Check for required files
ls -lh bootstrap-foundation.sh terraform-with-impersonation.sh

# Verify Terraform configuration
cd terraform
terraform validate
```

**Expected Output:**
```
-rwxr-xr-x bootstrap-foundation.sh
-rwxr-xr-x terraform-with-impersonation.sh
Success! The configuration is valid.
```

---

## Phase 1: Bootstrap Execution

**Estimated Time:** 10-15 minutes

This phase creates the foundational resources needed to run Terraform:
- Bootstrap project (`pcc-prj-bootstrap`)
- Terraform service account (`pcc-sa-terraform@pcc-prj-bootstrap.iam.gserviceaccount.com`)
- GCS state bucket (`pcc-tfstate-foundation-us-east4`)
- Organization-level IAM permissions for the service account

### Step 1.1: Review Bootstrap Configuration

```bash
cd /home/cfogarty/git/pcc-foundation-infra

# Review the bootstrap script
cat bootstrap-foundation.sh | grep -E "^(ORG_ID|BILLING_ACCOUNT|BOOTSTRAP_PROJECT_ID|STATE_BUCKET)="
```

**Expected Output:**
```bash
ORG_ID="146990108557"
BILLING_ACCOUNT="01AFEA-2B972B-00C55F"
BOOTSTRAP_PROJECT_ID="pcc-prj-bootstrap"
STATE_BUCKET="pcc-tfstate-foundation-us-east4"
```

⚠️ **Verify these values match your environment before proceeding.**

### Step 1.2: Execute Bootstrap Script

```bash
# Make script executable (if not already)
chmod +x bootstrap-foundation.sh

# Run the bootstrap script
./bootstrap-foundation.sh
```

**Interactive Prompts:**
```
============================================================================
PCC Foundation Infrastructure - Bootstrap
============================================================================

This script will create:
  1. Bootstrap project: pcc-prj-bootstrap
  2. Terraform service account: pcc-sa-terraform@pcc-prj-bootstrap.iam.gserviceaccount.com
  3. Terraform state bucket: gs://pcc-tfstate-foundation-us-east4
  4. Required IAM permissions for automation

Organization: 146990108557
Billing Account: 01AFEA-2B972B-00C55F

Continue? (yes/no):
```

**Type:** `yes` and press Enter

### Step 1.3: Monitor Bootstrap Progress

The script will execute the following steps (with progress indicators):

```
Step 1: Creating bootstrap project...
  ✅ Project pcc-prj-bootstrap created

Step 2: Enabling required APIs...
  Enabling cloudresourcemanager.googleapis.com...
  Enabling iam.googleapis.com...
  Enabling storage.googleapis.com...
  Enabling serviceusage.googleapis.com...
  Enabling cloudbilling.googleapis.com...
  ✅ APIs enabled

Step 3: Creating Terraform service account...
  ✅ Service account created

Step 4: Granting organization-level IAM permissions...
  Granting roles/resourcemanager.organizationAdmin...
  Granting roles/resourcemanager.folderAdmin...
  Granting roles/resourcemanager.projectCreator...
  Granting roles/orgpolicy.policyAdmin...
  Granting roles/compute.networkAdmin...
  Granting roles/compute.securityAdmin...
  Granting roles/iam.organizationRoleAdmin...
  Granting roles/logging.configWriter...
  Granting roles/billing.user...
  ✅ Organization permissions granted

Step 5: Enabling user impersonation...
  Granting roles/iam.serviceAccountTokenCreator to [your-email@pcconnect.ai]...
  ✅ Impersonation enabled for [your-email@pcconnect.ai]

Step 6: Creating Terraform state bucket...
  Creating bucket gs://pcc-tfstate-foundation-us-east4...
  Enabling versioning...
  Setting lifecycle policy (delete versions older than 30 days)...
  Granting service account access...
  ✅ State bucket created
```

**Expected Completion Time:** 3-5 minutes

### Step 1.4: Verify Bootstrap Resources

```bash
# Verify project exists
gcloud projects describe pcc-prj-bootstrap --format="value(projectId,lifecycleState)"

# Verify service account exists
gcloud iam service-accounts describe \
  pcc-sa-terraform@pcc-prj-bootstrap.iam.gserviceaccount.com \
  --project=pcc-prj-bootstrap

# Verify state bucket exists
gsutil ls -L gs://pcc-tfstate-foundation-us-east4 | head -20

# Verify impersonation permission
gcloud iam service-accounts get-iam-policy \
  pcc-sa-terraform@pcc-prj-bootstrap.iam.gserviceaccount.com \
  --project=pcc-prj-bootstrap \
  --flatten="bindings[].members" \
  --filter="bindings.role:roles/iam.serviceAccountTokenCreator"
```

**Expected Output:**
```
pcc-prj-bootstrap  ACTIVE
Created service account [pcc-sa-terraform]
gs://pcc-tfstate-foundation-us-east4/:
  Versioning enabled: True
- members:
  - user:[your-email@pcconnect.ai]
  role: roles/iam.serviceAccountTokenCreator
```

✅ **Phase 1 Complete** - Bootstrap resources are ready.

---

## Phase 2: Foundation Deployment

**Estimated Time:** 30-45 minutes

This phase deploys the complete foundation infrastructure using the bootstrap resources.

### Step 2.1: Initialize Terraform

```bash
cd /home/cfogarty/git/pcc-foundation-infra/terraform

# Initialize Terraform (downloads providers, configures backend)
terraform init
```

**Expected Output:**
```
Initializing the backend...
Initializing modules...
Initializing provider plugins...
- Finding hashicorp/google versions matching "~> 5.45.0"...
- Installing hashicorp/google v5.45.2...

Terraform has been successfully initialized!
```

⚠️ **If initialization fails**, see [Troubleshooting - Terraform Init Failures](#terraform-init-failures)

### Step 2.2: Review Terraform Configuration

```bash
# Verify terraform.tfvars values
cat terraform.tfvars

# Review the deployment plan size
terraform plan -no-color | grep -E "(Plan:|will be created)"
```

**Expected Values in terraform.tfvars:**
```
org_id          = "146990108557"
billing_account = "01AFEA-2B972B-00C55F"
domain          = "pcconnect.ai"
primary_region  = "us-east4"
log_retention_days = 365
```

### Step 2.3: Generate Deployment Plan

Use the impersonation wrapper to generate the plan:

```bash
cd /home/cfogarty/git/pcc-foundation-infra

# Generate plan using service account impersonation
./terraform-with-impersonation.sh plan -out=current.tfplan
```

**Expected Output:**
```
============================================================================
Terraform with Service Account Impersonation
============================================================================

Service Account: pcc-sa-terraform@pcc-prj-bootstrap.iam.gserviceaccount.com
Terraform Dir:   /home/cfogarty/git/pcc-foundation-infra/terraform
Command:         terraform plan -out=current.tfplan

Generating access token (lifetime: 3600s)...
Access token generated successfully

Executing terraform command...
============================================================================

Terraform will perform the following actions:
  ...
  [resource plan output]
  ...

Plan: 200 to add, 0 to change, 0 to destroy.
```

⚠️ **CRITICAL VALIDATION:** Verify the plan shows approximately **200 resources to add**

### Step 2.4: Review Plan Details

```bash
cd /home/cfogarty/git/pcc-foundation-infra/terraform

# Generate human-readable plan summary
terraform show current.tfplan | grep -E "# (google_|module\.)" | head -50

# Count resources by type
terraform show -json current.tfplan | jq -r '.resource_changes[].type' | sort | uniq -c
```

**Expected Resource Breakdown (approximate):**
```
  50+ google_project_iam_member (IAM bindings)
  30+ google_org_policy_policy (organization policies)
  20+ google_compute_* (network resources)
  15+ google_folder (folder structure)
  10+ google_project (projects)
  ...
```

### Step 2.5: Deploy Foundation Infrastructure

**⚠️ WARNING: This step makes real changes to your GCP organization**

You have two deployment options:

#### Option A: Full Deployment (Recommended for Automation)

```bash
cd /home/cfogarty/git/pcc-foundation-infra

# Deploy all 200 resources in one operation
./terraform-with-impersonation.sh apply current.tfplan
```

**Estimated Time:** 20-30 minutes

#### Option B: Phased Deployment (Recommended for First-Time)

Deploy in logical phases for better control and troubleshooting:

```bash
cd /home/cfogarty/git/pcc-foundation-infra

# Phase 1: Organization Policies (safeguards first)
./terraform-with-impersonation.sh apply -target=module.org_policies

# Phase 2: Folder Structure
./terraform-with-impersonation.sh apply -target=module.folders

# Phase 3: Projects
./terraform-with-impersonation.sh apply -target=module.projects

# Phase 4: Networking
./terraform-with-impersonation.sh apply -target=module.network

# Phase 5: IAM (after all resources exist)
./terraform-with-impersonation.sh apply -target=module.iam

# Phase 6: Log Export
./terraform-with-impersonation.sh apply -target=module.log_export

# Final: Apply all (catches any dependencies)
./terraform-with-impersonation.sh apply
```

**Estimated Time per Phase:** 3-5 minutes each (30 minutes total)

### Step 2.6: Monitor Deployment Progress

**During Full Deployment:**
```
Apply complete! Resources: 200 added, 0 changed, 0 destroyed.

Outputs:

audit_log_sink = "pcc-org-sink-audit-logs"
folder_ids = {
  "prod" = "folders/123456789012"
  "nonprod" = "folders/123456789013"
  ...
}
network_names = {
  "prod" = "pcc-vpc-prod"
  "nonprod" = "pcc-vpc-nonprod"
}
...
```

**Success Indicators:**
- ✅ No errors in output
- ✅ "Apply complete!" message
- ✅ Resource count matches plan (200 added)
- ✅ Outputs display folder IDs, network names, etc.

### Step 2.7: Verify Deployment Success

```bash
cd /home/cfogarty/git/pcc-foundation-infra

# Run validation script
./terraform-with-impersonation.sh output -json > /tmp/tf-outputs.json

# Check key resources
cat /tmp/tf-outputs.json | jq -r '.folder_ids.value'
cat /tmp/tf-outputs.json | jq -r '.network_names.value'
cat /tmp/tf-outputs.json | jq -r '.audit_log_sink.value'
```

**Expected Output:**
```json
{
  "prod": "folders/123456789012",
  "nonprod": "folders/123456789013",
  "shared": "folders/123456789014"
}
{
  "prod": "pcc-vpc-prod",
  "nonprod": "pcc-vpc-nonprod"
}
"pcc-org-sink-audit-logs"
```

✅ **Phase 2 Complete** - Foundation infrastructure is deployed.

---

## Validation Procedures

### Post-Deployment Validation Checklist

Run these commands to verify the deployment:

#### 1. Verify Folder Structure

```bash
gcloud resource-manager folders list --organization=146990108557

# Expected:
# - pcc-prod
# - pcc-nonprod
# - pcc-shared
```

#### 2. Verify Projects

```bash
gcloud projects list --filter="parent.id=* AND parent.type=folder" --format="table(projectId,parent.id,parent.type)"

# Expected projects:
# - pcc-prj-prod-core
# - pcc-prj-nonprod-dev
# - pcc-prj-nonprod-staging
# - pcc-prj-shared-network
# - pcc-prj-shared-monitoring
# - pcc-prj-shared-security
# - pcc-prj-shared-cicd
```

#### 3. Verify Network Configuration

```bash
# List VPCs
gcloud compute networks list --format="table(name,autoCreateSubnetworks,routingMode)"

# Expected:
# pcc-vpc-prod       False  REGIONAL
# pcc-vpc-nonprod    False  REGIONAL

# List subnets
gcloud compute networks subnets list --format="table(name,region,ipCidrRange,network)"

# Expected: Multiple subnets in us-east4 and us-central1
```

#### 4. Verify IAM Bindings

```bash
# Check org-level IAM for groups
gcloud organizations get-iam-policy 146990108557 \
  --flatten="bindings[].members" \
  --filter="bindings.members:group:gcp-*@pcconnect.ai" \
  --format="table(bindings.role,bindings.members)"

# Expected: IAM bindings for all 5 Google Workspace groups
```

#### 5. Verify Organization Policies

```bash
# List organization policies
gcloud org-policies list --organization=146990108557

# Expected: ~19 organization policies including:
# - compute.requireOsLogin
# - compute.restrictVpcPeering
# - iam.allowedPolicyMemberDomains
# - storage.uniformBucketLevelAccess
```

#### 6. Verify Log Export

```bash
# Check BigQuery dataset for logs
gcloud logging sinks list --organization=146990108557

# Expected: pcc-org-sink-audit-logs -> BigQuery dataset

# Verify BigQuery dataset
gcloud alpha logging sinks describe pcc-org-sink-audit-logs --organization=146990108557
```

#### 7. Verify Terraform State

```bash
# Check state bucket versioning
gsutil versioning get gs://pcc-tfstate-foundation-us-east4

# Expected: Enabled

# List state files
gsutil ls -lh gs://pcc-tfstate-foundation-us-east4/
```

### Automated Validation Script

```bash
cd /home/cfogarty/git/pcc-foundation-infra

# Run comprehensive validation
./scripts/validate-deployment.sh
```

**Expected Output:**
```
✅ Folder structure: OK
✅ Projects: 7/7 created
✅ Networks: 2/2 created
✅ Subnets: 8/8 created
✅ IAM bindings: OK
✅ Organization policies: 19/19 active
✅ Log export: OK
✅ State bucket: OK

Deployment validation: PASSED
```

---

## Troubleshooting

### Common Issues and Solutions

#### Issue 1: Bootstrap Script Fails - Permission Denied

**Error:**
```
ERROR: (gcloud.projects.create) User [your-email] does not have permission to access organizations instance [146990108557]
```

**Solution:**
```bash
# Verify you have Organization Admin role
gcloud organizations get-iam-policy 146990108557 \
  --flatten="bindings[].members" \
  --filter="bindings.members:user:$(gcloud config get-value account)" \
  --format="table(bindings.role)"

# If missing, ask an existing Org Admin to grant you:
# roles/resourcemanager.organizationAdmin
```

#### Issue 2: Service Account Impersonation Fails

**Error:**
```
ERROR: Failed to generate access token
```

**Solution:**
```bash
# Check if you have Token Creator role
gcloud iam service-accounts get-iam-policy \
  pcc-sa-terraform@pcc-prj-bootstrap.iam.gserviceaccount.com \
  --format=json | jq '.bindings[] | select(.role=="roles/iam.serviceAccountTokenCreator")'

# If missing, re-run Step 5 of bootstrap script:
gcloud iam service-accounts add-iam-policy-binding \
  pcc-sa-terraform@pcc-prj-bootstrap.iam.gserviceaccount.com \
  --member="user:$(gcloud config get-value account)" \
  --role="roles/iam.serviceAccountTokenCreator" \
  --project=pcc-prj-bootstrap
```

#### Issue 3: Terraform Init Fails - Backend Configuration

**Error:**
```
Error: Failed to get existing workspaces: querying Cloud Storage failed: storage: bucket doesn't exist
```

**Solution:**
```bash
# Verify state bucket exists
gsutil ls gs://pcc-tfstate-foundation-us-east4

# If missing, re-run Step 6 of bootstrap script:
cd /home/cfogarty/git/pcc-foundation-infra
./bootstrap-foundation.sh
# (Script is idempotent - safe to re-run)
```

#### Issue 4: Terraform Plan Fails - Google Workspace Groups Missing

**Error:**
```
Error: Error retrieving IAM policy for organization "146990108557": Error setting IAM policy for organization "146990108557":
Policy bindings with condition for group "gcp-admins@pcconnect.ai" does not exist.
```

**Solution:**
```bash
# Verify groups exist
./check-groups.sh

# If any group is missing, create it in Google Workspace Admin Console:
# https://admin.google.com/ac/groups
# Group email format: gcp-[role]@pcconnect.ai
```

#### Issue 5: Terraform Apply Fails - Quota Exceeded

**Error:**
```
Error: Error creating Network: googleapi: Error 403: Quota 'NETWORKS' exceeded. Limit: 5
```

**Solution:**
```bash
# Request quota increase via Cloud Console:
# Navigation: IAM & Admin > Quotas > Filter: "Networks" > Select > Edit Quotas

# Or use gcloud:
gcloud compute project-info describe --project=pcc-prj-prod-core

# Temporary workaround: Delete unused default networks
gcloud compute networks list --filter="name=default" --format="value(name,project)"
```

#### Issue 6: Access Token Expires During Long Apply

**Error:**
```
Error: Error creating [resource]: invalid_grant: Invalid JWT Signature.
```

**Cause:** Access tokens expire after 1 hour (3600s)

**Solution:**
```bash
# For long-running operations, use phased deployment (Option B)
# OR manually refresh token mid-apply:

# 1. Note which resources failed
# 2. Generate new plan with impersonation
./terraform-with-impersonation.sh plan -out=current.tfplan

# 3. Apply remaining resources
./terraform-with-impersonation.sh apply current.tfplan
```

#### Issue 7: State Lock Error

**Error:**
```
Error: Error acquiring the state lock: ConflictError: 409
Lock Info:
  ID:        [lock-id]
  Operation: OperationTypeApply
  Who:       [user]@[host]
  Created:   [timestamp]
```

**Solution:**
```bash
# If you're certain no other operation is running:
cd /home/cfogarty/git/pcc-foundation-infra/terraform
terraform force-unlock [lock-id]

# If unsure, check for other terraform processes:
ps aux | grep terraform
```

---

## Rollback Procedures

### Emergency Rollback - Destroy All Resources

⚠️ **DANGER: This destroys all foundation infrastructure**

```bash
cd /home/cfogarty/git/pcc-foundation-infra

# Generate destroy plan
./terraform-with-impersonation.sh plan -destroy -out=destroy.tfplan

# Review what will be destroyed
terraform show destroy.tfplan | grep "# google_" | wc -l

# Execute destroy (requires manual confirmation)
./terraform-with-impersonation.sh destroy

# Type 'yes' when prompted
```

**Expected Time:** 15-20 minutes

### Partial Rollback - Destroy Specific Module

```bash
cd /home/cfogarty/git/pcc-foundation-infra

# Example: Destroy only network resources
./terraform-with-impersonation.sh destroy -target=module.network

# Example: Destroy only a specific project
./terraform-with-impersonation.sh destroy -target=module.projects.google_project.nonprod_dev
```

### Rollback Bootstrap Resources

**⚠️ WARNING: Only do this if you're completely starting over**

```bash
# Delete state bucket
gsutil -m rm -r gs://pcc-tfstate-foundation-us-east4

# Delete service account
gcloud iam service-accounts delete \
  pcc-sa-terraform@pcc-prj-bootstrap.iam.gserviceaccount.com \
  --project=pcc-prj-bootstrap

# Delete bootstrap project
gcloud projects delete pcc-prj-bootstrap

# Remove org-level IAM bindings
ORG_ROLES=(
  "roles/resourcemanager.organizationAdmin"
  "roles/resourcemanager.folderAdmin"
  "roles/resourcemanager.projectCreator"
  "roles/orgpolicy.policyAdmin"
  "roles/compute.networkAdmin"
  "roles/compute.securityAdmin"
  "roles/iam.organizationRoleAdmin"
  "roles/logging.configWriter"
  "roles/billing.user"
)

for role in "${ORG_ROLES[@]}"; do
  gcloud organizations remove-iam-policy-binding 146990108557 \
    --member="serviceAccount:pcc-sa-terraform@pcc-prj-bootstrap.iam.gserviceaccount.com" \
    --role="${role}"
done
```

### State Recovery - Restore from Backup

If you need to restore Terraform state from a previous version:

```bash
# List available state versions
gsutil ls -la gs://pcc-tfstate-foundation-us-east4/default.tfstate

# Download a specific version
gsutil cp gs://pcc-tfstate-foundation-us-east4/default.tfstate#[generation-number] \
  /tmp/terraform.tfstate.backup

# Restore state (DANGER: overwrites current state)
gsutil cp /tmp/terraform.tfstate.backup \
  gs://pcc-tfstate-foundation-us-east4/default.tfstate

# Verify state
cd /home/cfogarty/git/pcc-foundation-infra/terraform
terraform state list
```

---

## Appendix

### Key Files Reference

| File | Purpose | Location |
|------|---------|----------|
| `bootstrap-foundation.sh` | Creates bootstrap resources | `/home/cfogarty/git/pcc-foundation-infra/` |
| `terraform-with-impersonation.sh` | Wrapper for Terraform with SA impersonation | `/home/cfogarty/git/pcc-foundation-infra/` |
| `terraform.tfvars` | Deployment configuration values | `/home/cfogarty/git/pcc-foundation-infra/terraform/` |
| `check-groups.sh` | Validates Google Workspace groups | `/home/cfogarty/git/pcc-foundation-infra/` |
| `current.tfplan` | Generated Terraform plan (binary) | `/home/cfogarty/git/pcc-foundation-infra/terraform/` |

### Service Account Permissions

The Terraform service account (`pcc-sa-terraform@pcc-prj-bootstrap.iam.gserviceaccount.com`) has these **organization-level** roles:

- `roles/resourcemanager.organizationAdmin`
- `roles/resourcemanager.folderAdmin`
- `roles/resourcemanager.projectCreator`
- `roles/orgpolicy.policyAdmin`
- `roles/compute.networkAdmin`
- `roles/compute.securityAdmin`
- `roles/iam.organizationRoleAdmin`
- `roles/logging.configWriter`
- `roles/billing.user`

**Security Note:** The service account **cannot** grant itself additional permissions. All IAM bindings for the service account are managed outside of Terraform via the bootstrap script.

### State Bucket Configuration

**Bucket:** `gs://pcc-tfstate-foundation-us-east4`

**Features:**
- Versioning: Enabled (keeps last 3 versions)
- Region: `us-east4` (single region for cost optimization)
- Access: Uniform bucket-level access
- Lifecycle: Deletes non-current versions after 3 newer versions exist

### Phased Deployment Timeline

| Phase | Resources | Time | Description |
|-------|-----------|------|-------------|
| Bootstrap | 3 | 10m | Project, SA, bucket |
| Org Policies | 19 | 3m | Security guardrails |
| Folders | 3 | 2m | Organizational structure |
| Projects | 7 | 5m | Environment projects |
| Network | 20+ | 8m | VPCs and subnets |
| IAM | 50+ | 10m | Access control |
| Log Export | 5 | 2m | Audit logging |
| **TOTAL** | **~200** | **40m** | Full deployment |

### Contact Information

**Primary Operators:**
- Chris Fogarty: cfogarty@pcconnect.ai

**Escalation Path:**
1. Check this troubleshooting guide
2. Review Terraform logs: `/home/cfogarty/git/pcc-foundation-infra/terraform/terraform.log`
3. Contact GCP support (Premium Support SLA: 1 hour response)

---

**Document Version Control:**
- v1.0 (2025-10-02): Initial deployment guide
- Next Review: 2025-11-02 (monthly)

---

**End of Bootstrap & Deployment Guide**
