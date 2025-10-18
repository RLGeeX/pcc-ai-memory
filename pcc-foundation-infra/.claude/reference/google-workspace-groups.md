# Google Workspace Groups for PCC GCP Foundation

This document lists all required Google Workspace groups for the PCC GCP Foundation infrastructure. These groups must be created in Google Workspace before applying IAM bindings.

**Total Groups Required:** 5 core groups (simplified for 6-person team)

---

## Team Member Assignments

| Name | Email | Role | Groups |
|------|-------|------|--------|
| **J Fogarty** | jfogarty@pcconnect.ai | Admin/DevOps | gcp-admins, gcp-break-glass, gcp-auditors |
| **C Fogarty** | cfogarty@pcconnect.ai | Developer/Admin | gcp-admins, gcp-break-glass |
| **S Lanning** | slanning@pcconnect.ai | Developer | gcp-developers |

---

## Core Groups (Required)

### 1. gcp-admins@pcconnect.ai
**Members:**
- jfogarty@pcconnect.ai
- cfogarty@pcconnect.ai

**Purpose:** Full administrative access to all GCP resources

**IAM Roles:**
- **Organization Level:**
  - `roles/resourcemanager.organizationAdmin`
  - `roles/billing.admin`
  - `roles/compute.xpnAdmin`
  - `roles/iam.securityAdmin`
- **All Projects:**
  - `roles/owner`

**Use Case:** Day-to-day infrastructure management, deployments, troubleshooting

---

### 2. gcp-developers@pcconnect.ai
**Members:**
- slanning@pcconnect.ai

**Purpose:** Full access to dev/test projects, read-only access to all other projects

**IAM Roles:**
- **Dev/Test Projects (Full Access - Editor):**
  - `pcc-prj-app-devtest` → `roles/editor`
  - `pcc-prj-data-devtest` → `roles/editor`
- **All Other Projects (Read-Only):**
  - All prod, staging, SI, devops, systems projects → `roles/viewer`
- **Network Projects:**
  - `pcc-prj-network-nonprod` → `roles/compute.networkUser` (can use subnets)
  - `pcc-prj-network-prod` → `roles/compute.networkViewer` (read-only)

**Use Case:** Development, testing, production troubleshooting (read-only)

---

### 3. gcp-break-glass@pcconnect.ai
**Members:**
- jfogarty@pcconnect.ai
- cfogarty@pcconnect.ai

**Purpose:** Emergency-only organization admin access

**IAM Roles:**
- **Organization Level:**
  - `roles/resourcemanager.organizationAdmin`

**Use Case:**
- **Emergency scenarios only** (e.g., primary admin locked out, critical incident)
- **Alert on usage:** Configure Cloud Monitoring alert when this group is used
- **Review monthly:** Check audit logs for any break-glass access

⚠️ **Security Note:** Same members as gcp-admins but monitored separately for emergency access patterns

---

### 4. gcp-auditors@pcconnect.ai
**Members:**
- jfogarty@pcconnect.ai

**Purpose:** Read-only access for compliance, security reviews, and auditing

**IAM Roles:**
- **Organization Level:**
  - `roles/iam.securityReviewer`
  - `roles/logging.privateLogViewer`
- **All Projects:**
  - `roles/viewer`

**Use Case:** Quarterly access reviews, security audits, compliance reporting

---

### 5. gcp-cicd@pcconnect.ai
**Members:** None (used for service account associations via Workload Identity)

**Purpose:** CI/CD pipeline automation

**IAM Roles:**
- **Artifact Registry Project (pcc-prj-artifact-prod):**
  - `roles/artifactregistry.writer`
  - `roles/artifactregistry.reader`
- **Build Project:**
  - `roles/cloudbuild.builds.editor`
- **Deployment Projects:**
  - `roles/run.developer` (Cloud Run deployments)
  - `roles/cloudfunctions.developer` (Cloud Functions)
  - `roles/container.developer` (GKE deployments)

**Use Case:** GitHub Actions, Cloud Build, automated deployments

---

## Optional Groups (For Future Growth)

### 6. gcp-viewers@pcconnect.ai *(Not needed initially)*
**Members:** TBD (future non-technical stakeholders)

**Purpose:** Read-only access to dashboards and billing

**IAM Roles:**
- **Monitoring Project:** `roles/monitoring.viewer`
- **Logging Project:** `roles/logging.viewer`
- **Organization Level:** `roles/billing.viewer`

**Use Case:** Business stakeholders viewing dashboards, costs, and application health

---

## Project Access Summary

### Projects by Environment

**Dev/Test Projects (Full Access for gcp-developers):**
- `pcc-prj-app-devtest` - Application development and testing
- `pcc-prj-data-devtest` - Data development and testing

**All Other Projects (Read-Only for gcp-developers, Full Access for gcp-admins):**
- `pcc-prj-app-prod` - Production applications
- `pcc-prj-app-staging` - Staging applications
- `pcc-prj-data-prod` - Production data
- `pcc-prj-data-staging` - Staging data
- `pcc-prj-devops-prod` - Production DevOps (GKE, CI/CD)
- `pcc-prj-devops-nonprod` - Non-production DevOps
- `pcc-prj-logging-prod` - Centralized logging
- `pcc-prj-monitoring-prod` - Centralized monitoring
- `pcc-prj-secrets-prod` - Secret management
- `pcc-prj-artifact-prod` - Container/artifact registry
- `pcc-prj-systems-prod` - Production systems management
- `pcc-prj-systems-nonprod` - Non-production systems management

---

## Group Creation Instructions

### Prerequisites
- Google Workspace Admin access
- Groups admin role or equivalent

### Option 1: Bulk Creation via CLI (Recommended)

```bash
#!/bin/bash
# create-groups.sh - Create all PCC GCP Foundation groups

# Authenticate as Google Workspace admin
gcloud auth login

# Create core groups
echo "Creating gcp-admins@pcconnect.ai..."
gcloud identity groups create gcp-admins@pcconnect.ai \
  --display-name="GCP Administrators" \
  --description="Full access to all GCP resources (jfogarty, cfogarty)" \
  --labels="cloudidentity.googleapis.com/groups.security="

echo "Creating gcp-developers@pcconnect.ai..."
gcloud identity groups create gcp-developers@pcconnect.ai \
  --display-name="GCP Developers" \
  --description="Full access to devtest projects, read-only to all others (slanning)" \
  --labels="cloudidentity.googleapis.com/groups.security="

echo "Creating gcp-break-glass@pcconnect.ai..."
gcloud identity groups create gcp-break-glass@pcconnect.ai \
  --display-name="GCP Break Glass" \
  --description="Emergency-only organization admin access (jfogarty, cfogarty)" \
  --labels="cloudidentity.googleapis.com/groups.security="

echo "Creating gcp-auditors@pcconnect.ai..."
gcloud identity groups create gcp-auditors@pcconnect.ai \
  --display-name="GCP Auditors" \
  --description="Read-only access for compliance and security reviews (jfogarty)" \
  --labels="cloudidentity.googleapis.com/groups.security="

echo "Creating gcp-cicd@pcconnect.ai..."
gcloud identity groups create gcp-cicd@pcconnect.ai \
  --display-name="GCP CI/CD" \
  --description="Service account associations for automated deployments" \
  --labels="cloudidentity.googleapis.com/groups.security="

echo "✅ All groups created successfully!"
```

### Option 2: Manual Creation via Google Admin Console

1. Navigate to: https://admin.google.com
2. Go to **Directory** → **Groups**
3. Click **Create group**
4. For each group:
   - **Group type:** Security
   - **Access type:** Restricted (only members can view membership)
   - **Who can join:** Only invited users
   - **Who can post:** Anyone in the organization

| Group Email | Display Name | Description |
|-------------|--------------|-------------|
| gcp-admins@pcconnect.ai | GCP Administrators | Full access to all GCP resources (jfogarty, cfogarty) |
| gcp-developers@pcconnect.ai | GCP Developers | Full access to devtest projects, read-only to all others (slanning) |
| gcp-break-glass@pcconnect.ai | GCP Break Glass | Emergency-only organization admin access (jfogarty, cfogarty) |
| gcp-auditors@pcconnect.ai | GCP Auditors | Read-only access for compliance and security reviews (jfogarty) |
| gcp-cicd@pcconnect.ai | GCP CI/CD | Service account associations for automated deployments |

---

## Adding Group Members

### Option 1: Add Members via CLI (Recommended)

```bash
#!/bin/bash
# add-members.sh - Add members to PCC GCP Foundation groups

# Add admins (jfogarty and cfogarty)
echo "Adding admins to gcp-admins@pcconnect.ai..."
for email in jfogarty@pcconnect.ai cfogarty@pcconnect.ai; do
  gcloud identity groups memberships add \
    --group-email=gcp-admins@pcconnect.ai \
    --member-email="$email" \
    --roles=MEMBER
done

# Add developer (slanning)
echo "Adding developer to gcp-developers@pcconnect.ai..."
gcloud identity groups memberships add \
  --group-email=gcp-developers@pcconnect.ai \
  --member-email=slanning@pcconnect.ai \
  --roles=MEMBER

# Add break-glass (same as admins: jfogarty and cfogarty)
echo "Adding break-glass members..."
for email in jfogarty@pcconnect.ai cfogarty@pcconnect.ai; do
  gcloud identity groups memberships add \
    --group-email=gcp-break-glass@pcconnect.ai \
    --member-email="$email" \
    --roles=MEMBER
done

# Add auditor (jfogarty)
echo "Adding auditor to gcp-auditors@pcconnect.ai..."
gcloud identity groups memberships add \
  --group-email=gcp-auditors@pcconnect.ai \
  --member-email=jfogarty@pcconnect.ai \
  --roles=MEMBER

# gcp-cicd group remains empty (for Workload Identity bindings only)

echo "✅ All members added successfully!"
echo ""
echo "Verifying group memberships..."
for group in gcp-admins gcp-developers gcp-break-glass gcp-auditors gcp-cicd; do
  echo ""
  echo "═══════════════════════════════════════════════════════"
  echo "Members of ${group}@pcconnect.ai:"
  echo "═══════════════════════════════════════════════════════"
  gcloud identity groups memberships list \
    --group-email="${group}@pcconnect.ai" \
    --format="table(preferredMemberKey.id, role)"
done
```

### Option 2: Add Members via Google Admin Console

1. Navigate to: https://admin.google.com
2. Go to **Directory** → **Groups**
3. Click on each group
4. Click **Members** → **Add members**
5. Enter email addresses (comma or space-separated for multiple)
6. Click **Add**

**Member Assignments:**
- **gcp-admins@pcconnect.ai:** jfogarty@pcconnect.ai, cfogarty@pcconnect.ai
- **gcp-developers@pcconnect.ai:** slanning@pcconnect.ai
- **gcp-break-glass@pcconnect.ai:** jfogarty@pcconnect.ai, cfogarty@pcconnect.ai
- **gcp-auditors@pcconnect.ai:** jfogarty@pcconnect.ai
- **gcp-cicd@pcconnect.ai:** (leave empty)

---

## Validation

After creating groups and adding members, validate the setup:

```bash
# List all groups
echo "All groups in pcconnect.ai organization:"
gcloud identity groups list --organization=pcconnect.ai

# Expected output: 5 groups (gcp-admins, gcp-developers, gcp-break-glass, gcp-auditors, gcp-cicd)

# Verify specific group memberships
echo ""
echo "Verifying gcp-admins@pcconnect.ai:"
gcloud identity groups memberships list \
  --group-email=gcp-admins@pcconnect.ai \
  --format="table(preferredMemberKey.id, role)"
# Expected: jfogarty@pcconnect.ai, cfogarty@pcconnect.ai

echo ""
echo "Verifying gcp-developers@pcconnect.ai:"
gcloud identity groups memberships list \
  --group-email=gcp-developers@pcconnect.ai \
  --format="table(preferredMemberKey.id, role)"
# Expected: slanning@pcconnect.ai
```

---

## Security Recommendations

### 🔐 Access Control Best Practices

1. **Enforce Multi-Factor Authentication (MFA)**
   - **Mandatory for all users:** jfogarty@pcconnect.ai, cfogarty@pcconnect.ai, slanning@pcconnect.ai
   - Path: Google Workspace Admin Console → Security → Authentication → 2-Step Verification → Enforcement
   - **No exceptions**

2. **Use Groups, Not Direct User Bindings**
   - Always assign IAM roles to groups, never directly to users
   - Better audit trail, easier to manage, scales as team grows

3. **Regular Access Reviews**
   - **Frequency:** Quarterly (every 3 months)
   - **Process:** Review group membership, verify access is still appropriate
   - **Tool:** `gcloud identity groups memberships list --group-email=<group>`

4. **Monitor Break-Glass Usage**
   - Set up Cloud Monitoring alert when `gcp-break-glass@pcconnect.ai` is used
   - Alert should notify jfogarty@pcconnect.ai immediately
   - Review audit logs monthly for any break-glass access

### 🛡️ Service Account Best Practices

1. **Workload Identity for GKE/Cloud Run**
   - Never create service account keys for application workloads
   - Use Workload Identity to bind Kubernetes/Cloud Run service accounts to GCP service accounts
   - Organization policy `iam.disableServiceAccountKeyCreation` enforces this

2. **Service Account Key Rotation** (if keys are unavoidable)
   - Rotate every 90 days
   - Store in Secret Manager, never in git
   - Audit key usage regularly

### 📊 Monitoring & Auditing

1. **Enable Cloud Audit Logs**
   - **Admin Activity:** Enabled by default (no cost)
   - **Data Access:** Enable for prod projects (pcc-prj-app-prod, pcc-prj-data-prod)
   - **System Event:** Enabled by default
   - **Policy Denied:** Enable to see denied access attempts

2. **Weekly Admin Activity Review**
   - Path: Logging → Logs Explorer → Admin Activity
   - Filter: `protoPayload.authenticationInfo.principalEmail=~"@pcconnect.ai"`
   - Look for: Unusual project creation, IAM changes, network modifications

3. **Billing Alerts**
   - Set up at **$100, $300, $500** thresholds
   - Monthly budget alert at 50%, 90%, 100%
   - Email to jfogarty@pcconnect.ai and cfogarty@pcconnect.ai

---

## Growth Path: When to Add More Groups

| Team Size | Recommended Groups | Notes |
|-----------|-------------------|-------|
| **1-6 people** | 5 groups (current) | Start simple, room for growth |
| **7-10 people** | Add `gcp-developers-senior` | Separate junior/senior developers |
| **11-15 people** | Add `gcp-data-engineers` | If dedicated data team forms |
| **16-25 people** | Add `gcp-network-admins` | When dedicated network engineer hired |
| **26-50 people** | Add `gcp-security-admins` | Security specialist hired |
| **51+ people** | Split by team/product | E.g., `gcp-team-alpha-admins` |

---

## Notes

- **Naming Convention:** All groups follow `gcp-<function>@pcconnect.ai`
- **Security Groups:** All groups are marked as security groups for IAM binding
- **Membership:** Start with minimal membership (3 people assigned initially)
- **Audit:** Review group membership quarterly
- **Service Accounts:** Do NOT add service accounts to groups; use Workload Identity instead
- **Simplified Structure:** 5 groups instead of 31 (84% reduction for small team)
- **Project-Specific Access:** Developers have editor on `pcc-prj-app-devtest` and `pcc-prj-data-devtest` only

---

## Quick Reference: Complete Setup Commands

```bash
#!/bin/bash
# complete-setup.sh - One-shot script to create groups and add members

set -e  # Exit on error

echo "🚀 Starting PCC GCP Foundation group setup..."
echo ""

# Create groups
echo "📁 Creating groups..."
gcloud identity groups create gcp-admins@pcconnect.ai \
  --display-name="GCP Administrators" \
  --description="Full access to all GCP resources" \
  --labels="cloudidentity.googleapis.com/groups.security="

gcloud identity groups create gcp-developers@pcconnect.ai \
  --display-name="GCP Developers" \
  --description="Full access to devtest projects, read-only to all others" \
  --labels="cloudidentity.googleapis.com/groups.security="

gcloud identity groups create gcp-break-glass@pcconnect.ai \
  --display-name="GCP Break Glass" \
  --description="Emergency-only organization admin access" \
  --labels="cloudidentity.googleapis.com/groups.security="

gcloud identity groups create gcp-auditors@pcconnect.ai \
  --display-name="GCP Auditors" \
  --description="Read-only access for compliance and security reviews" \
  --labels="cloudidentity.googleapis.com/groups.security="

gcloud identity groups create gcp-cicd@pcconnect.ai \
  --display-name="GCP CI/CD" \
  --description="Service account associations for automated deployments" \
  --labels="cloudidentity.googleapis.com/groups.security="

echo "✅ Groups created"
echo ""

# Add members
echo "👥 Adding members..."
for email in jfogarty@pcconnect.ai cfogarty@pcconnect.ai; do
  gcloud identity groups memberships add \
    --group-email=gcp-admins@pcconnect.ai \
    --member-email="$email" \
    --roles=MEMBER
done

gcloud identity groups memberships add \
  --group-email=gcp-developers@pcconnect.ai \
  --member-email=slanning@pcconnect.ai \
  --roles=MEMBER

for email in jfogarty@pcconnect.ai cfogarty@pcconnect.ai; do
  gcloud identity groups memberships add \
    --group-email=gcp-break-glass@pcconnect.ai \
    --member-email="$email" \
    --roles=MEMBER
done

gcloud identity groups memberships add \
  --group-email=gcp-auditors@pcconnect.ai \
  --member-email=jfogarty@pcconnect.ai \
  --roles=MEMBER

echo "✅ Members added"
echo ""

# Verify
echo "🔍 Verifying setup..."
for group in gcp-admins gcp-developers gcp-break-glass gcp-auditors gcp-cicd; do
  echo ""
  echo "Members of ${group}@pcconnect.ai:"
  gcloud identity groups memberships list \
    --group-email="${group}@pcconnect.ai" \
    --format="table(preferredMemberKey.id, role)"
done

echo ""
echo "🎉 Setup complete! All 5 groups created and members assigned."
```

**Save as:** `/home/cfogarty/git/pcc-foundation-infra/scripts/setup-google-workspace-groups.sh`

**Usage:**
```bash
chmod +x scripts/setup-google-workspace-groups.sh
./scripts/setup-google-workspace-groups.sh
```

---

**End of Document** | Last Updated: 2025-10-01 | 5 Groups Total
