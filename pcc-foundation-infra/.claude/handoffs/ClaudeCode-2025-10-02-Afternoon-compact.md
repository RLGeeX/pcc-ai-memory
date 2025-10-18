# PCC Foundation Infrastructure - Handoff Document (Compact)

**Date:** 2025-10-02
**Time:** 12:41 PM EDT (Afternoon Session)
**Tool:** Claude Code
**Session Type:** Critical Fixes - Service Account Permissions & IAM Policy Resolution
**Previous Handoff:** ClaudeCode-2025-10-02-Morning-Part3-compact.md

---

## 1. Project Overview

**Project:** PCC GCP Foundation Infrastructure
**Repository:** pcc-foundation-infra
**Current Phase:** ⚠️ **PARTIALLY DEPLOYED** - Folders Created, Projects Blocked on Missing Permission

**Objective:** Deploy production-ready GCP foundation infrastructure with 14 projects, networking, IAM, security policies, and centralized logging using Terraform.

**Session Summary:** Successfully resolved two critical blockers (service account folder creation permission and IAM policy format), deployed 7 folders successfully, but discovered service account lacks `projectCreator` permission. Deployment is 95% ready pending one final permission grant.

---

## 2. Current State

### ✅ Completed This Session

**Critical Fixes:**
- [x] Discovered root cause: Service account needed `roles/resourcemanager.folderAdmin` (not just organizationAdmin)
- [x] Fixed IAM `allowedPolicyMemberDomains` policy format - customer ID requires `is:` prefix
- [x] Corrected Terraform IAM policy to: `is:C03k8ps0n` and `is:principalSet://iam.googleapis.com/organizations/146990108557`
- [x] Fixed Terraform projects module - conditional logic for `org_id` vs `folder_id` (both cannot be set)
- [x] Successfully deployed 7 folders (1 root + 6 category folders)

**Service Account Roles Added:**
- [x] `roles/resourcemanager.folderAdmin` - for folder creation
- [x] `roles/iam.serviceAccountUser` - for impersonation at org level

**Infrastructure Deployed:**
- ✅ Root folder: `pcc-fldr` (folders/173302232499)
- ✅ App folder: `pcc-fldr-app` (folders/372430857945)
- ✅ Data folder: `pcc-fldr-data` (folders/732182060621)
- ✅ DevOps folder: `pcc-fldr-devops` (folders/631536203389)
- ✅ Network folder: `pcc-fldr-network` (folders/731501014515)
- ✅ SI folder: `pcc-fldr-si` (folders/70347239999)
- ✅ Systems folder: `pcc-fldr-systems` (folders/1073232942327)

### ⚠️ Current Blocker

**ISSUE:** Service account lacks `roles/resourcemanager.projectCreator` permission

**Error:**
```
Error 403: Permission 'resourcemanager.projects.create' denied on resource
```

**Impact:** Blocks creation of all 14 projects (and subsequent networking, IAM, etc.)

**Solution Required:** Grant `roles/resourcemanager.projectCreator` to service account

---

## 3. Key Discoveries & Solutions

### Discovery 1: Service Account Impersonation Worked After Correct Roles

**Problem:** Impersonation via `--impersonate-service-account` and `GOOGLE_OAUTH_ACCESS_TOKEN` failed with permission denied

**Root Cause:** Service account had `roles/owner` and `roles/organizationAdmin` but these do NOT include `resourcemanager.folders.create` permission

**Solution:** Added `roles/resourcemanager.folderAdmin` which includes the required permission

**Testing:** Verified folder creation works with impersonation after adding the role

### Discovery 2: IAM Policy Customer ID Format

**Problem:** IAM `allowedPolicyMemberDomains` policy accepted `C03k8ps0n` via gcloud but deployment still failed with "users do not belong to permitted customer"

**Root Cause:** The customer ID value MUST have `is:` prefix - documentation was unclear

**Incorrect Format:**
```yaml
allowedValues:
  - "C03k8ps0n"  # ❌ WRONG
```

**Correct Format:**
```yaml
allowedValues:
  - "is:C03k8ps0n"  # ✅ CORRECT
```

**Solution:** Updated both gcloud policy AND Terraform configuration with `is:` prefix

### Discovery 3: Terraform Projects Module Conflict

**Problem:** Terraform error: `"org_id": conflicts with folder_id`

**Root Cause:** The `google_project` resource accepts EITHER `org_id` OR `folder_id` as parent, not both

**Solution:** Implemented conditional logic in `terraform/modules/projects/main.tf`:
```hcl
org_id    = each.value.folder_key == null ? var.org_id : null
folder_id = each.value.folder_key != null ? var.folders[each.value.folder_key] : null
```

---

## 4. Files Modified This Session

**Terraform Modules:**
1. `terraform/modules/org-policies/iam-policies.tf:22-23` - Added `is:` prefix to customer ID
2. `terraform/modules/projects/main.tf:7,9` - Conditional org_id vs folder_id logic

**Status Files:**
- Not yet updated (pending full deployment)

**Manual Policy Changes:**
- Applied via gcloud: IAM allowedPolicyMemberDomains with correct `is:` prefixes

---

## 5. Pending Tasks

### 🔴 CRITICAL - Immediate Next Step

**Grant projectCreator Permission**
```bash
gcloud organizations add-iam-policy-binding 146990108557 \
  --member="serviceAccount:pcc-sa-terraform@pcc-prj-bootstrap.iam.gserviceaccount.com" \
  --role="roles/resourcemanager.projectCreator"
```

**Then Resume Deployment**
```bash
cd /home/cfogarty/git/pcc-foundation-infra
./terraform-with-impersonation.sh apply -auto-approve
```

### 🟡 Medium Priority - Post-Deployment

**Complete Deployment (After Permission Grant)**
- [ ] Create all 14 projects in their designated folders
- [ ] Deploy networking (2 VPCs, 6 subnets)
- [ ] Configure Cloud NAT and Cloud Router (4 each)
- [ ] Apply ~70 IAM bindings
- [ ] Enable APIs on all projects
- [ ] Deploy centralized logging sink to BigQuery
- [ ] Estimated time: 15-20 minutes

**Validation**
- [ ] Verify all 14 projects created
- [ ] Verify VPCs and subnets deployed
- [ ] Verify Shared VPC attachments
- [ ] Validate organization policies (16 active)
- [ ] Test IAM permissions for groups

### 🟢 Low Priority - Future Work

**Organization Policy Research**
- [ ] Research `compute.restrictLoadBalancerCreationForTypes` valid values
- [ ] Research `storage.restrictAuthTypes` valid values
- [ ] Re-enable commented policies

**Infrastructure Enhancements**
- [ ] Create application state bucket (Week 4)
- [ ] Deploy Week 6+ test workloads

---

## 6. Blockers or Challenges

### ✅ Resolved Issues (This Session)

**1. Service Account Folder Creation Permission**
- **Was:** Service account with `roles/owner` + `roles/organizationAdmin` couldn't create folders
- **Fix:** Added `roles/resourcemanager.folderAdmin`
- **Result:** Folder creation via impersonation works ✅

**2. IAM Policy Format Blocking Folder IAM Bindings**
- **Was:** Policy value `C03k8ps0n` rejected during folder creation
- **Fix:** Changed to `is:C03k8ps0n` with `is:` prefix
- **Result:** Policy accepts domain users and org service accounts ✅

**3. Terraform Project Parent Conflict**
- **Was:** Both `org_id` and `folder_id` set on projects
- **Fix:** Conditional logic - use folder_id when folder specified, else org_id
- **Result:** Terraform validation passes ✅

### 🚫 Active Blocker

**Service Account Project Creation Permission**
- **Issue:** Service account lacks `roles/resourcemanager.projectCreator`
- **Impact:** Blocks creation of all 14 projects
- **Solution:** One gcloud command to grant permission

---

## 7. Important Context

### Configuration Parameters

| Parameter | Value |
|-----------|-------|
| **Organization ID** | 146990108557 |
| **Billing Account** | 01AFEA-2B972B-00C55F |
| **Domain** | pcconnect.ai |
| **Workspace Customer ID** | C03k8ps0n (requires `is:` prefix in policies) |
| **Primary Region** | us-east4 |
| **Secondary Region** | us-central1 |
| **Service Account** | pcc-sa-terraform@pcc-prj-bootstrap.iam.gserviceaccount.com |
| **State Bucket** | pcc-tfstate-foundation-us-east4 |
| **gcloud Config** | pcc |
| **User** | cfogarty@pcconnect.ai |

### Service Account Roles (Current)

On `pcc-sa-terraform@pcc-prj-bootstrap.iam.gserviceaccount.com`:
- `roles/owner` (organization level)
- `roles/resourcemanager.organizationAdmin` (organization level)
- `roles/orgpolicy.policyAdmin` (organization level)
- `roles/resourcemanager.folderAdmin` (organization level) ✅ **ADDED THIS SESSION**

**MISSING (Blocking Deployment):**
- `roles/resourcemanager.projectCreator` ❌ **NEED TO ADD**

### IAM Policy Configuration (CORRECTED)

**Applied Policy:**
```yaml
constraint: constraints/iam.allowedPolicyMemberDomains
listPolicy:
  allowedValues:
  - is:C03k8ps0n  # Workspace customer (requires is: prefix)
  - is:principalSet://iam.googleapis.com/organizations/146990108557  # Org service accounts
```

**Terraform Configuration (MATCHES):**
```hcl
resource "google_organization_policy" "allowed_policy_member_domains" {
  org_id     = var.org_id
  constraint = "iam.allowedPolicyMemberDomains"

  list_policy {
    allow {
      values = [
        "is:C03k8ps0n",
        "is:principalSet://iam.googleapis.com/organizations/${var.org_id}",
      ]
    }
  }
}
```

### Deployed Folder Structure

```
organizations/146990108557
└── folders/173302232499 (pcc-fldr) ← ROOT
    ├── folders/372430857945 (pcc-fldr-app)
    ├── folders/732182060621 (pcc-fldr-data)
    ├── folders/631536203389 (pcc-fldr-devops)
    ├── folders/731501014515 (pcc-fldr-network)
    ├── folders/70347239999 (pcc-fldr-si)
    └── folders/1073232942327 (pcc-fldr-systems)
```

### Infrastructure Statistics (Remaining to Deploy)

- **Projects:** 14 (0 deployed, 14 pending) ❌
- **VPCs:** 2 (pending)
- **Subnets:** 6 (pending)
- **Cloud Routers:** 4 (pending)
- **NAT Gateways:** 4 (pending)
- **Firewall Rules:** ~20 (pending)
- **Org Policies:** 16 active (2 commented out for research)
- **IAM Bindings:** ~70 (pending)
- **API Enablements:** ~42 (pending)
- **Log Sink:** 1 (pending)
- **Total Remaining Resources:** ~175

---

## 8. Technical Notes

### Terraform State

- **Backend:** GCS bucket `gs://pcc-tfstate-foundation-us-east4/pcc-foundation-infra`
- **Lock Status:** Currently unlocked
- **Last Apply:** Partial - folders only (7 resources created)
- **State Includes:** 7 folders + 16 organization policies

### Impersonation Working

✅ **Confirmed Working:**
- Folder creation via `--impersonate-service-account` ✅
- Folder creation via `GOOGLE_OAUTH_ACCESS_TOKEN` ✅
- Organization policy management ✅

❌ **Not Yet Tested:**
- Project creation (blocked on missing permission)
- Networking resource creation
- IAM binding creation

### Code Quality

- ✅ All code follows HashiCorp Terraform Style Guide
- ✅ Formatted with `terraform fmt`
- ✅ Validated with `terraform validate`
- ✅ Modular, reusable design
- ✅ IAM policy matches manual configuration

---

## 9. Lessons Learned

### What Worked

1. **Using Specialized Subagents:** deployment-engineer and cloud-architect provided accurate solutions
2. **Iterative Permission Testing:** Testing folder creation with gcloud before Terraform saved time
3. **Policy Format Research:** cloud-architect MCP tools found the `is:` prefix requirement in documentation
4. **Conditional Terraform Logic:** Proper use of ternary operators resolved org_id/folder_id conflict

### What Didn't Work

1. **Assuming `roles/owner` Includes All Permissions:** It doesn't - need specific resource manager roles
2. **Relying on Documentation Examples:** IAM policy examples didn't show `is:` prefix requirement clearly
3. **Manual Policy Changes Without Terraform Updates:** Had to update Terraform to match manual fixes

### Key Insights

1. **GCP IAM Granularity:** Even `roles/owner` doesn't include all organization-level permissions - need specific roles:
   - `folderAdmin` for folders
   - `projectCreator` for projects
   - `organizationAdmin` for org policies

2. **IAM Policy Format Strictness:** The `is:` prefix is REQUIRED for:
   - Customer IDs: `is:C03k8ps0n`
   - Organization principals: `is:principalSet://iam.googleapis.com/organizations/ID`

3. **Terraform Resource Exclusivity:** Many GCP resources have mutually exclusive parameters - read provider docs carefully

---

## 10. Quick Start for Next Session

```bash
# Step 1: Grant missing permission
gcloud organizations add-iam-policy-binding 146990108557 \
  --member="serviceAccount:pcc-sa-terraform@pcc-prj-bootstrap.iam.gserviceaccount.com" \
  --role="roles/resourcemanager.projectCreator"

# Step 2: Resume deployment
cd /home/cfogarty/git/pcc-foundation-infra
./terraform-with-impersonation.sh apply -auto-approve

# Step 3: Monitor progress (15-20 minutes expected)
# Watch for completion of 175 resources

# Step 4: Validate deployment
gcloud resource-manager folders list --organization=146990108557  # Expect 7 folders
gcloud projects list | wc -l  # Expect 15 projects (14 + bootstrap)
gcloud compute networks list --filter="name~^pcc-vpc"  # Expect 2 VPCs

# Step 5: Update status files
# Update: .claude/status/brief.md
# Update: .claude/status/current-progress.md
```

---

**Status:** ⚠️ 95% Ready - One Permission Away from Full Deployment
**Blocker:** Service account needs `roles/resourcemanager.projectCreator`
**Action Required:** One gcloud command to grant permission, then resume apply
**Estimated Completion:** 15-20 minutes after permission granted
**Session Duration:** ~5.5 hours
**Context Consumed:** ~112K tokens

**Last Updated:** 2025-10-02 12:41 PM EDT
