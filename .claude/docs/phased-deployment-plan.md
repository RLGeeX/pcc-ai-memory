# PCC Foundation Infrastructure - Phased Deployment Plan

**Generated:** 2025-10-02
**Organization:** 146990108557 (pcconnect.ai)
**Total Resources to Deploy:** 68 create, 1 update
**Terraform State:** GCS backend configured
**Service Account:** pcc-sa-terraform@pcc-prj-bootstrap.iam.gserviceaccount.com

---

## Executive Summary

This document outlines a 5-stage phased deployment strategy for the PCC foundation infrastructure. The deployment builds upon already-deployed organization policies (17 total), folders (7), projects (15), network infrastructure, and logging configuration.

### Current State (Already Deployed - 139 Resources)
- **Organization Policies:** 17 security policies enforced
- **Folders:** 7 (root, app, data, devops, network, systems, si)
- **Projects:** 15 (app: 4, data: 4, devops: 2, network: 2, systems: 2, logging: 1)
- **Project APIs:** 65 APIs enabled across all projects
- **Network Infrastructure:**
  - VPCs: 2 (prod, nonprod)
  - Subnets: 4 (2 regional + 2 devops)
  - Routers: 4 (2 regions × 2 environments)
  - Cloud NAT: 4 instances
  - Firewall Rules: 7 (internal, IAP, health checks, egress controls)
  - Shared VPC: 2 host projects, 12 service projects attached
- **Logging:** Organization sink to BigQuery configured

### Remaining Deployment (69 Resources)
- **IAM Bindings:** 66 resources (7 org-level + 59 project-level)
- **Network Subnets:** 2 primary use4 subnets (nonprod + prod)
- **Logging IAM:** 1 service account permission

---

## Deployment Stages

### Stage 1: Organization-Level IAM (Low Risk)
**Purpose:** Establish organization-level permissions for admin, auditor, and break-glass groups

**Resources:** 7 IAM bindings
- `module.iam.google_organization_iam_member.admins_org_admin`
- `module.iam.google_organization_iam_member.admins_billing_admin`
- `module.iam.google_organization_iam_member.admins_security_admin`
- `module.iam.google_organization_iam_member.admins_xpn_admin`
- `module.iam.google_organization_iam_member.auditors_security_reviewer`
- `module.iam.google_organization_iam_member.auditors_logging_viewer`
- `module.iam.google_organization_iam_member.break_glass_org_admin`

**Dependencies:** None (org policies and groups already exist)

**Estimated Duration:** 2-3 minutes

**Risk Level:** LOW
- Read-only and admin permissions for existing groups
- No infrastructure changes
- Easily reversible

**Validation Steps:**
```bash
# Verify IAM bindings
gcloud organizations get-iam-policy 146990108557 \
  --filter="bindings.members:group:gcp-admins@pcconnect.ai" \
  --flatten="bindings[].members" \
  --format="table(bindings.role)"

gcloud organizations get-iam-policy 146990108557 \
  --filter="bindings.members:group:gcp-auditors@pcconnect.ai" \
  --flatten="bindings[].members" \
  --format="table(bindings.role)"

gcloud organizations get-iam-policy 146990108557 \
  --filter="bindings.members:group:gcp-break-glass@pcconnect.ai" \
  --flatten="bindings[].members" \
  --format="table(bindings.role)"
```

**Rollback Plan:**
```bash
# Remove specific IAM binding
gcloud organizations remove-iam-policy-binding 146990108557 \
  --member="group:gcp-admins@pcconnect.ai" \
  --role="roles/resourcemanager.organizationAdmin"

# OR use Terraform to remove all
cd /home/cfogarty/git/pcc-foundation-infra/terraform
../scripts/terraform-with-impersonation.sh destroy \
  -target=module.iam.google_organization_iam_member.admins_org_admin \
  -target=module.iam.google_organization_iam_member.admins_billing_admin \
  -target=module.iam.google_organization_iam_member.admins_security_admin \
  -target=module.iam.google_organization_iam_member.admins_xpn_admin \
  -target=module.iam.google_organization_iam_member.auditors_security_reviewer \
  -target=module.iam.google_organization_iam_member.auditors_logging_viewer \
  -target=module.iam.google_organization_iam_member.break_glass_org_admin
```

**Deployment Command:**
```bash
cd /home/cfogarty/git/pcc-foundation-infra/terraform
../scripts/terraform-with-impersonation.sh apply \
  -target=module.iam.google_organization_iam_member.admins_org_admin \
  -target=module.iam.google_organization_iam_member.admins_billing_admin \
  -target=module.iam.google_organization_iam_member.admins_security_admin \
  -target=module.iam.google_organization_iam_member.admins_xpn_admin \
  -target=module.iam.google_organization_iam_member.auditors_security_reviewer \
  -target=module.iam.google_organization_iam_member.auditors_logging_viewer \
  -target=module.iam.google_organization_iam_member.break_glass_org_admin
```

---

### Stage 2: Network Completion (Low Risk)
**Purpose:** Complete network infrastructure by adding primary use4 subnets

**Resources:** 2 subnets + 1 log export IAM update
- `module.network.google_compute_subnetwork.nonprod_use4`
- `module.network.google_compute_subnetwork.prod_use4`
- `module.log_export.google_bigquery_dataset.org_logs` (update retention)

**Dependencies:**
- Stage 1 (optional - can run independently)
- Network host projects (already deployed)
- VPCs (already deployed)

**Estimated Duration:** 3-5 minutes

**Risk Level:** LOW
- Additive changes only (new subnets)
- No modifications to existing network infrastructure
- Subnets configured with flow logs and private Google access

**Subnet Configuration:**
- **nonprod_use4:** 10.10.1.0/24 (us-east4)
- **prod_use4:** 10.20.1.0/24 (us-east4)

**Validation Steps:**
```bash
# Verify nonprod subnet
gcloud compute networks subnets describe pcc-subnet-nonprod-use4 \
  --region=us-east4 \
  --project=pcc-prj-network-nonprod \
  --format="table(name,ipCidrRange,privateIpGoogleAccess,enableFlowLogs)"

# Verify prod subnet
gcloud compute networks subnets describe pcc-subnet-prod-use4 \
  --region=us-east4 \
  --project=pcc-prj-network-prod \
  --format="table(name,ipCidrRange,privateIpGoogleAccess,enableFlowLogs)"

# Verify log export dataset retention update
bq show --format=prettyjson pcc-prj-logging-monitoring:pcc_organization_logs | \
  jq '.defaultTableExpirationMs'
```

**Rollback Plan:**
```bash
# Delete subnets if issues arise
gcloud compute networks subnets delete pcc-subnet-nonprod-use4 \
  --region=us-east4 \
  --project=pcc-prj-network-nonprod \
  --quiet

gcloud compute networks subnets delete pcc-subnet-prod-use4 \
  --region=us-east4 \
  --project=pcc-prj-network-prod \
  --quiet

# OR use Terraform
cd /home/cfogarty/git/pcc-foundation-infra/terraform
../scripts/terraform-with-impersonation.sh destroy \
  -target=module.network.google_compute_subnetwork.nonprod_use4 \
  -target=module.network.google_compute_subnetwork.prod_use4
```

**Deployment Command:**
```bash
cd /home/cfogarty/git/pcc-foundation-infra/terraform
../scripts/terraform-with-impersonation.sh apply \
  -target=module.network.google_compute_subnetwork.nonprod_use4 \
  -target=module.network.google_compute_subnetwork.prod_use4 \
  -target=module.log_export.google_bigquery_dataset.org_logs
```

---

### Stage 3: Non-Production Project IAM (Medium Risk)
**Purpose:** Grant admin group owner permissions to non-production projects

**Resources:** 29 IAM bindings
- Network projects: 2 (pcc-prj-network-nonprod, pcc-prj-network-prod)
- App projects: 3 (app-dev, app-devtest, app-staging)
- Data projects: 3 (data-dev, data-devtest, data-staging)
- DevOps projects: 2 (devops-nonprod, devops-prod)
- Systems projects: 2 (sys-nonprod, sys-prod)
- Logging project: 1 (logging-monitoring)

**Dependencies:**
- Stage 1 (org-level IAM should be in place)
- Projects (already deployed)

**Estimated Duration:** 5-7 minutes

**Risk Level:** MEDIUM
- Grants owner permissions to gcp-admins group
- Affects all non-production environments
- Production projects included but low impact (no workloads yet)

**Validation Steps:**
```bash
# Verify network project IAM
gcloud projects get-iam-policy pcc-prj-network-nonprod \
  --filter="bindings.members:group:gcp-admins@pcconnect.ai" \
  --flatten="bindings[].members" \
  --format="table(bindings.role)"

# Verify app dev project IAM
gcloud projects get-iam-policy pcc-prj-app-dev \
  --filter="bindings.members:group:gcp-admins@pcconnect.ai" \
  --flatten="bindings[].members" \
  --format="table(bindings.role)"

# Verify data dev project IAM
gcloud projects get-iam-policy pcc-prj-data-dev \
  --filter="bindings.members:group:gcp-admins@pcconnect.ai" \
  --flatten="bindings[].members" \
  --format="table(bindings.role)"

# Count total IAM bindings applied
for project in pcc-prj-network-nonprod pcc-prj-network-prod \
              pcc-prj-app-dev pcc-prj-app-devtest pcc-prj-app-staging pcc-prj-app-prod \
              pcc-prj-data-dev pcc-prj-data-devtest pcc-prj-data-staging pcc-prj-data-prod \
              pcc-prj-devops-nonprod pcc-prj-devops-prod \
              pcc-prj-sys-nonprod pcc-prj-sys-prod \
              pcc-prj-logging-monitoring; do
  echo "=== $project ==="
  gcloud projects get-iam-policy $project \
    --filter="bindings.members:group:gcp-admins@pcconnect.ai" \
    --flatten="bindings[].members" \
    --format="value(bindings.role)"
done
```

**Rollback Plan:**
```bash
# Remove IAM binding from specific project
gcloud projects remove-iam-policy-binding pcc-prj-app-dev \
  --member="group:gcp-admins@pcconnect.ai" \
  --role="roles/owner"

# OR use Terraform to remove all project IAM in batch
cd /home/cfogarty/git/pcc-foundation-infra/terraform
../scripts/terraform-with-impersonation.sh destroy \
  -target=module.iam.google_project_iam_member.admins_owner
```

**Deployment Command:**
```bash
cd /home/cfogarty/git/pcc-foundation-infra/terraform

# Option 1: Deploy all project IAM at once (recommended)
../scripts/terraform-with-impersonation.sh apply \
  -target=module.iam.google_project_iam_member.admins_owner

# Option 2: Deploy incrementally by project type
# Network projects first
../scripts/terraform-with-impersonation.sh apply \
  -target='module.iam.google_project_iam_member.admins_owner["pcc-prj-network-nonprod"]' \
  -target='module.iam.google_project_iam_member.admins_owner["pcc-prj-network-prod"]'

# Then app projects
../scripts/terraform-with-impersonation.sh apply \
  -target='module.iam.google_project_iam_member.admins_owner["pcc-prj-app-dev"]' \
  -target='module.iam.google_project_iam_member.admins_owner["pcc-prj-app-devtest"]' \
  -target='module.iam.google_project_iam_member.admins_owner["pcc-prj-app-staging"]' \
  -target='module.iam.google_project_iam_member.admins_owner["pcc-prj-app-prod"]'

# Continue for data, devops, systems, logging...
```

---

### Stage 4: Developer & Network User IAM (Medium Risk)
**Purpose:** Grant environment-specific permissions to developer and network user groups

**Resources:** 30 IAM bindings
- Developer group permissions to dev/devtest/staging environments
- Network user permissions for Shared VPC access
- DevOps group permissions

**Dependencies:**
- Stage 3 (project admin IAM should be in place)
- Shared VPC configuration (already deployed)

**Estimated Duration:** 5-7 minutes

**Risk Level:** MEDIUM
- Grants permissions to developer groups
- Enables Shared VPC network user access
- Read-only and editor roles (not owner)

**IAM Roles Applied:**
- `roles/editor` - Developers on dev/devtest projects
- `roles/viewer` - Developers on staging projects
- `roles/compute.networkUser` - Network users on Shared VPC
- `roles/container.developer` - DevOps on GKE clusters

**Validation Steps:**
```bash
# Verify developer permissions on dev project
gcloud projects get-iam-policy pcc-prj-app-dev \
  --filter="bindings.members:group:gcp-developers@pcconnect.ai" \
  --flatten="bindings[].members" \
  --format="table(bindings.role)"

# Verify network user permissions
gcloud projects get-iam-policy pcc-prj-network-nonprod \
  --filter="bindings.members:group:gcp-network-users@pcconnect.ai" \
  --flatten="bindings[].members" \
  --format="table(bindings.role)"

# Verify DevOps permissions
gcloud projects get-iam-policy pcc-prj-devops-nonprod \
  --filter="bindings.members:group:gcp-devops@pcconnect.ai" \
  --flatten="bindings[].members" \
  --format="table(bindings.role)"
```

**Rollback Plan:**
```bash
# Remove developer IAM bindings
cd /home/cfogarty/git/pcc-foundation-infra/terraform
../scripts/terraform-with-impersonation.sh destroy \
  -target=module.iam.google_project_iam_member.developers_editor \
  -target=module.iam.google_project_iam_member.network_users_compute_network_user \
  -target=module.iam.google_project_iam_member.devops_container_developer
```

**Deployment Command:**
```bash
cd /home/cfogarty/git/pcc-foundation-infra/terraform

# Deploy developer IAM bindings
../scripts/terraform-with-impersonation.sh apply \
  -target=module.iam.google_project_iam_member.developers_editor \
  -target=module.iam.google_project_iam_member.developers_viewer

# Deploy network user IAM bindings
../scripts/terraform-with-impersonation.sh apply \
  -target=module.iam.google_project_iam_member.network_users_compute_network_user

# Deploy DevOps IAM bindings
../scripts/terraform-with-impersonation.sh apply \
  -target=module.iam.google_project_iam_member.devops_container_developer \
  -target=module.iam.google_project_iam_member.devops_artifact_registry_writer
```

---

### Stage 5: Full Deployment & Validation (All Remaining Resources)
**Purpose:** Deploy all remaining resources and perform comprehensive validation

**Resources:** All remaining IAM bindings not covered in Stages 1-4

**Dependencies:**
- Stages 1-4 completed
- All prerequisite infrastructure deployed

**Estimated Duration:** 5-10 minutes

**Risk Level:** LOW
- Only remaining IAM bindings
- Most critical resources already deployed in earlier stages
- Validation phase included

**Validation Steps:**
```bash
# Full state verification
cd /home/cfogarty/git/pcc-foundation-infra/terraform
../scripts/terraform-with-impersonation.sh state list | wc -l
# Expected: ~208 resources (139 existing + 69 new)

# Verify plan shows no changes
../scripts/terraform-with-impersonation.sh plan -detailed-exitcode
# Exit code 0 = no changes needed (success)
# Exit code 2 = changes needed (failure)

# Comprehensive IAM audit
gcloud organizations get-iam-policy 146990108557 \
  --format=json > /tmp/org-iam-policy.json

# Count IAM bindings per group
for group in gcp-admins gcp-developers gcp-devops gcp-network-users gcp-auditors gcp-break-glass; do
  echo "=== $group@pcconnect.ai ==="
  jq -r --arg group "group:$group@pcconnect.ai" \
    '.bindings[] | select(.members[] | contains($group)) | .role' \
    /tmp/org-iam-policy.json | sort | uniq
done

# Verify network infrastructure
gcloud compute networks list --project=pcc-prj-network-nonprod
gcloud compute networks list --project=pcc-prj-network-prod
gcloud compute networks subnets list --project=pcc-prj-network-nonprod
gcloud compute networks subnets list --project=pcc-prj-network-prod

# Verify logging configuration
bq ls --project_id=pcc-prj-logging-monitoring pcc_organization_logs
gcloud logging sinks list --organization=146990108557
```

**Rollback Plan:**
```bash
# Full rollback to Stage 4 state
cd /home/cfogarty/git/pcc-foundation-infra/terraform
../scripts/terraform-with-impersonation.sh destroy \
  -target=module.iam

# Selective rollback (if specific resources fail)
../scripts/terraform-with-impersonation.sh state list | \
  grep "module.iam.google_project_iam_member" | \
  tail -n 10 | \
  xargs -I {} ../scripts/terraform-with-impersonation.sh destroy -target={}
```

**Deployment Command:**
```bash
cd /home/cfogarty/git/pcc-foundation-infra/terraform

# Apply full plan (recommended at this stage)
../scripts/terraform-with-impersonation.sh apply tfplan-full

# OR apply any remaining targeted resources
../scripts/terraform-with-impersonation.sh apply
```

---

## Alternative: Single-Stage Full Deployment

For environments where phased deployment is not required, deploy all 69 resources at once:

```bash
cd /home/cfogarty/git/pcc-foundation-infra/terraform
../scripts/terraform-with-impersonation.sh apply tfplan-full
```

**Estimated Duration:** 10-15 minutes
**Risk Level:** MEDIUM (all changes at once)
**Recommendation:** Use phased approach for production deployments

---

## Deployment Timeline

| Stage | Description | Resources | Duration | Cumulative Time |
|-------|-------------|-----------|----------|-----------------|
| 0 | Current State | 139 | - | - |
| 1 | Org IAM | 7 | 2-3 min | 2-3 min |
| 2 | Network Completion | 3 | 3-5 min | 5-8 min |
| 3 | Project IAM (Admins) | 29 | 5-7 min | 10-15 min |
| 4 | Project IAM (Dev/Ops) | 30 | 5-7 min | 15-22 min |
| 5 | Final Validation | 0 | 5-10 min | 20-32 min |
| **Total** | **Complete Infrastructure** | **208** | **20-32 min** | - |

---

## Pre-Deployment Checklist

- [ ] Terraform state backend configured and accessible
- [ ] Service account impersonation working
- [ ] Google Workspace groups exist and members assigned:
  - [ ] gcp-admins@pcconnect.ai
  - [ ] gcp-developers@pcconnect.ai
  - [ ] gcp-devops@pcconnect.ai
  - [ ] gcp-network-users@pcconnect.ai
  - [ ] gcp-auditors@pcconnect.ai
  - [ ] gcp-break-glass@pcconnect.ai
- [ ] Billing account active (01AFEA-2B972B-00C55F)
- [ ] Organization policies validated (17 policies deployed)
- [ ] Current state verified: `terraform state list` shows 139 resources

---

## Post-Deployment Validation

### 1. State Verification
```bash
cd /home/cfogarty/git/pcc-foundation-infra/terraform
../scripts/terraform-with-impersonation.sh state list | wc -l
# Expected: 208 resources
```

### 2. IAM Verification
```bash
# Organization-level IAM
gcloud organizations get-iam-policy 146990108557 \
  --format="table(bindings.role,bindings.members.flatten())" \
  --filter="bindings.members:group:gcp-*" > /tmp/org-iam-report.txt

# Project-level IAM (sample projects)
for project in pcc-prj-app-dev pcc-prj-data-prod pcc-prj-devops-nonprod; do
  echo "=== $project ==="
  gcloud projects get-iam-policy $project \
    --format="table(bindings.role,bindings.members.flatten())" \
    --filter="bindings.members:group:gcp-*"
done
```

### 3. Network Verification
```bash
# VPCs
gcloud compute networks list --format="table(name,project,subnetworks.len())"

# Subnets (should be 6 total: 2 regions × 2 envs + 2 devops)
gcloud compute networks subnets list \
  --format="table(name,region,ipCidrRange,network,privateIpGoogleAccess)" \
  --filter="project:(pcc-prj-network-nonprod OR pcc-prj-network-prod)"

# Shared VPC attachments
gcloud compute shared-vpc list-associated-resources pcc-prj-network-nonprod
gcloud compute shared-vpc list-associated-resources pcc-prj-network-prod
```

### 4. Logging Verification
```bash
# Organization sink
gcloud logging sinks describe pcc-org-logs-to-bigquery \
  --organization=146990108557 \
  --format="table(name,destination,filter)"

# BigQuery dataset
bq show pcc-prj-logging-monitoring:pcc_organization_logs
bq ls pcc-prj-logging-monitoring:pcc_organization_logs
```

### 5. Compliance Check
```bash
# Organization policies
gcloud resource-manager org-policies list \
  --organization=146990108557 \
  --format="table(constraint,listPolicy.allowedValues,listPolicy.deniedValues,booleanPolicy.enforced)"
# Expected: 17 policies
```

---

## Troubleshooting

### Common Issues

**Issue:** IAM binding fails with "Error 403: Permission denied"
```bash
# Solution: Verify service account has necessary permissions
gcloud projects get-iam-policy pcc-prj-bootstrap \
  --flatten="bindings[].members" \
  --filter="bindings.members:pcc-sa-terraform@pcc-prj-bootstrap.iam.gserviceaccount.com"

# Check impersonation is working
gcloud auth list
```

**Issue:** Subnet creation fails with "IP range overlaps"
```bash
# Solution: Verify existing subnet CIDR ranges
gcloud compute networks subnets list \
  --project=pcc-prj-network-nonprod \
  --format="table(name,ipCidrRange)"

# Check for conflicts in terraform.tfvars
grep "subnet_cidr" /home/cfogarty/git/pcc-foundation-infra/terraform/terraform.tfvars
```

**Issue:** Shared VPC attachment fails
```bash
# Solution: Verify host project is enabled
gcloud compute shared-vpc get-host-project pcc-prj-network-nonprod

# Enable if needed (should already be done)
gcloud compute shared-vpc enable pcc-prj-network-nonprod
```

**Issue:** Terraform state lock error
```bash
# Solution: Check for stale locks
gsutil ls gs://pcc-tfstate-foundation-us-east4/**/*.lock

# Force unlock if necessary (use with caution)
cd /home/cfogarty/git/pcc-foundation-infra/terraform
../scripts/terraform-with-impersonation.sh force-unlock <LOCK_ID>
```

---

## Rollback Strategy

### Emergency Rollback (Complete)
```bash
# WARNING: This will destroy all IAM bindings deployed in this session
cd /home/cfogarty/git/pcc-foundation-infra/terraform
../scripts/terraform-with-impersonation.sh destroy \
  -target=module.iam \
  -target=module.network.google_compute_subnetwork.nonprod_use4 \
  -target=module.network.google_compute_subnetwork.prod_use4
```

### Stage-Specific Rollback
See individual stage rollback commands above.

### Partial Rollback (Specific Resource)
```bash
# List resources to identify target
cd /home/cfogarty/git/pcc-foundation-infra/terraform
../scripts/terraform-with-impersonation.sh state list | grep <resource_name>

# Destroy specific resource
../scripts/terraform-with-impersonation.sh destroy -target=<resource_address>
```

---

## Success Criteria

- [ ] All 69 resources deployed successfully
- [ ] `terraform plan` shows 0 changes needed
- [ ] IAM audit shows all expected group bindings
- [ ] Network audit shows 6 subnets configured correctly
- [ ] Organization sink collecting logs in BigQuery
- [ ] No drift detected in state
- [ ] All validation commands return expected results

---

## Next Steps After Deployment

1. **Application Deployment:**
   - Deploy GKE clusters in devops projects
   - Configure Artifact Registry repositories
   - Set up Cloud Build pipelines

2. **Monitoring Setup:**
   - Create custom dashboards in Cloud Monitoring
   - Configure alerting policies
   - Set up log-based metrics

3. **Security Hardening:**
   - Enable Security Command Center
   - Configure VPC Service Controls (if required)
   - Set up Cloud Armor policies (if needed)

4. **Cost Optimization:**
   - Set up billing budgets and alerts
   - Configure committed use discounts
   - Review resource quotas

5. **Documentation:**
   - Update architecture diagrams
   - Document IAM role assignments
   - Create runbooks for common operations

---

## Appendix: Resource Summary by Module

### Already Deployed (139 resources)
- **module.org_policies:** 17 organization policies
- **module.folders:** 7 folders
- **module.projects:** 93 resources
  - 15 projects
  - 65 API enablements
  - 2 Shared VPC host configurations
  - 12 Shared VPC service project attachments
- **module.network:** 19 resources
  - 2 VPCs
  - 4 subnets (2 regional + 2 devops)
  - 4 routers
  - 4 Cloud NAT instances
  - 7 firewall rules
- **module.log_export:** 3 resources
  - 1 BigQuery dataset
  - 1 organization sink
  - 1 IAM binding

### To Be Deployed (69 resources)
- **module.iam:** 66 IAM bindings
  - 7 organization-level bindings
  - 59 project-level bindings
- **module.network:** 2 subnets
  - 1 nonprod use4 primary subnet
  - 1 prod use4 primary subnet
- **module.log_export:** 1 update
  - BigQuery dataset retention update

### Total Final State: 208 resources
