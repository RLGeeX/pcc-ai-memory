# Phase 3.11: Configure Connect Gateway Access

**Phase**: 3.11 (GKE Infrastructure - Connect Gateway Setup)
**Duration**: 20-23 minutes
**Type**: Configuration
**Status**: Ready for Execution

---

## Execution Tool

**Use Claude Code for Step 2** (creating iam.tf) and **WARP for Steps 1, 3-5** (verification commands).

---

## Objective

Configure Connect Gateway for kubectl access to GKE cluster without VPN or bastion host (ADR-002).

## Prerequisites

✅ Phase 3.10 completed (cluster validated)
✅ Hub membership created in Phase 3.9
✅ `connectgateway.googleapis.com` API enabled (Phase 3.2)
✅ GCloud CLI configured

---

## Step 1: Verify Hub Membership

```bash
gcloud container fleet memberships list --project=pcc-prj-devops-nonprod
```

**Expected Output**:
```
NAME                                    EXTERNAL_ID
pcc-gke-devops-nonprod-membership       xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

✅ Hub membership registered

---

## Step 2: Configure IAM Permissions via Terraform Module

Create a reusable `iam-member` module in `pcc-tf-library`, then use it to grant Connect Gateway access.

### Step 2a: Create IAM Member Module

**File**: `pcc-tf-library/modules/iam-member/versions.tf`

```hcl
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}
```

**File**: `pcc-tf-library/modules/iam-member/variables.tf`

```hcl
variable "project" {
  description = "GCP project ID where IAM bindings will be created"
  type        = string
}

variable "members" {
  description = "List of members to grant roles (e.g., 'group:team@domain.com', 'serviceAccount:sa@project.iam.gserviceaccount.com')"
  type        = list(string)
}

variable "roles" {
  description = "List of IAM roles to grant to members (e.g., 'roles/container.viewer')"
  type        = list(string)
}
```

**File**: `pcc-tf-library/modules/iam-member/main.tf`

```hcl
# IAM Member Bindings (Non-Authoritative)
# Grants specified members to specified roles without affecting other members

locals {
  # Create a cartesian product of members x roles
  member_role_pairs = flatten([
    for member in var.members : [
      for role in var.roles : {
        member = member
        role   = role
      }
    ]
  ])
}

resource "google_project_iam_member" "member" {
  for_each = {
    for pair in local.member_role_pairs :
    "${pair.member}-${pair.role}" => pair
  }

  project = var.project
  role    = each.value.role
  member  = each.value.member
}
```

**File**: `pcc-tf-library/modules/iam-member/outputs.tf`

```hcl
output "member_ids" {
  description = "Map of member-role pairs to IAM binding IDs"
  value       = { for k, v in google_project_iam_member.member : k => v.id }
}
```

**Commit and Tag Module**:

```bash
cd ~/pcc/core/pcc-tf-library

# Validate module syntax before committing
terraform -chdir=modules/iam-member init
terraform -chdir=modules/iam-member validate

# Add module files
git add modules/iam-member/

# Commit with conventional commit message
git commit -m "feat: add iam-member module for non-authoritative IAM bindings

- Add versions.tf with Terraform and provider requirements
- Add variables for project, members, roles
- Create cartesian product for member-role pairs
- Use for_each to create individual IAM member bindings
- Add outputs for binding IDs"

# Update existing v0.1.0 tag to include new module
git tag -f v0.1.0

# Push main branch normally (no force)
git push origin main

# Force-push only the v0.1.0 tag (not main branch)
git push --force-with-lease origin refs/tags/v0.1.0
```

⚠️ **IMPORTANT**: Force-pushing tags can affect other developers. This is safe here because:
- v0.1.0 is being extended with new modules (not changing existing ones)
- Library is in active development (not production-stable yet)
- **Team members who already used v0.1.0 must run `terraform init -upgrade`** to download the updated tag

**For team members in other environments**:
```bash
# In any workspace that already pulled v0.1.0
cd ~/pcc/infra/<your-project>/environments/<env>
terraform init -upgrade  # Force re-download of updated v0.1.0 tag
```

📝 **TEMPORARY TECHNICAL DEBT**: This force-push tag strategy is acceptable during active development with a single deployer. This approach will be replaced with proper semantic versioning (v0.1.1, v0.1.2, etc.) before:
- Adding CI/CD pipelines
- Second person starts deploying
- Infrastructure reaches production stability

**Why same version (v0.1.0)?**
- v0.1.0 already exists (AlloyDB + GKE Autopilot modules)
- Adding iam-member module extends v0.1.0 library
- No need to bump version just for adding new modules

### Step 2b: Use IAM Member Module in Environment

**File**: `pcc-devops-infra/environments/nonprod/iam.tf`

```hcl
# Connect Gateway IAM Access for DevOps Team
module "gke_connect_gateway_iam" {
  source = "git::https://github.com/portco-connect/pcc-tf-library.git//modules/iam-member?ref=v0.1.0"

  project = "pcc-prj-devops-nonprod"

  members = [
    "group:gcp-devops@pcconnect.ai"
  ]

  roles = [
    "roles/gkehub.gatewayAdmin",      # Connect Gateway access
    "roles/container.clusterViewer"    # View cluster metadata
  ]
}
```

**Apply IAM Configuration**:

```bash
cd ~/pcc/infra/pcc-devops-infra/environments/nonprod

# Initialize to download iam-member module
# IMPORTANT: Use -upgrade flag to force re-download of v0.1.0 tag
# Without -upgrade, cached version won't have the new iam-member module
terraform init -upgrade

# Review IAM changes (should create 2 IAM bindings)
terraform plan

# Apply IAM bindings
terraform apply -auto-approve

# Commit IAM configuration
git add iam.tf
git commit -m "feat: add Connect Gateway IAM bindings for DevOps team"
git push origin main
```

**Expected Output**:
```
Plan: 2 to add, 0 to change, 0 to destroy.

module.gke_connect_gateway_iam.google_project_iam_member.member["group:gcp-devops@pcconnect.ai-roles/gkehub.gatewayAdmin"]: Creating...
module.gke_connect_gateway_iam.google_project_iam_member.member["group:gcp-devops@pcconnect.ai-roles/container.clusterViewer"]: Creating...
```

⚠️ **IAM Propagation Delay**: After applying IAM bindings, wait **60-90 seconds** before proceeding to Step 3. IAM changes can take time to propagate globally. If you get permission errors in Step 3, wait another minute and retry.

**Required Roles**:
- `roles/gkehub.gatewayAdmin`: Access Connect Gateway for kubectl
- `roles/container.clusterViewer`: View cluster metadata

**Access Granted To**:
- `gcp-devops@pcconnect.ai`: DevOps team only (developers do not need access to DevOps cluster)

---

## Step 3: Get Connect Gateway Credentials

```bash
gcloud container fleet memberships get-credentials pcc-gke-devops-nonprod-membership \
  --project=pcc-prj-devops-nonprod
```

**Expected Output**:
```
Fetching cluster endpoint and auth data.
kubeconfig entry generated for connectgateway_pcc-prj-devops-nonprod_global_pcc-gke-devops-nonprod-membership.
```

**What This Does**:
- Updates `~/.kube/config` with Connect Gateway endpoint
- Uses `gke-gcloud-auth-plugin` for authentication
- Enables kubectl access via PSC (no direct cluster endpoint)

---

## Step 4: Verify kubectl Access

Test kubectl connectivity:

```bash
kubectl get nodes
```

**Expected Output**:
```
NAME                                               STATUS   ROLES    AGE   VERSION
gk3-pcc-gke-devops-no-default-pool-xxxxxxxx-xxxx  Ready    <none>   5m    v1.28.x-gke.xxx
gk3-pcc-gke-devops-no-default-pool-yyyyyyyy-yyyy  Ready    <none>   5m    v1.28.x-gke.xxx
```

✅ Nodes visible
✅ Status: Ready

```bash
kubectl get namespaces
```

**Expected Output**:
```
NAME              STATUS   AGE
default           Active   10m
kube-node-lease   Active   10m
kube-public       Active   10m
kube-system       Active   10m
gke-managed-system   Active   9m
```

✅ Default namespaces present

---

## Step 5: Verify Connect Gateway Context

```bash
kubectl config current-context
```

**Expected Output**:
```
connectgateway_pcc-prj-devops-nonprod_global_pcc-gke-devops-nonprod-membership
```

**Context Format**: `connectgateway_{project}_{location}_{membership}`

✅ Using Connect Gateway (not direct cluster endpoint)

---

## Validation Checklist

- [ ] Hub membership listed
- [ ] iam-member module created in pcc-tf-library
- [ ] Module committed and v0.1.0 tag updated (force push)
- [ ] iam.tf created calling iam-member module
- [ ] Terraform init downloads module successfully
- [ ] Terraform plan shows 2 IAM bindings to create
- [ ] Terraform apply successful (2 IAM bindings created)
- [ ] Connect Gateway credentials retrieved
- [ ] kubectl can list nodes
- [ ] kubectl can list namespaces
- [ ] Current context uses Connect Gateway

---

## Connect Gateway vs Direct Access

| Access Method | Endpoint | Authentication | Network Path |
|---------------|----------|----------------|--------------|
| **Direct** | Cluster endpoint (34.x.x.x) | gcloud auth | Internet → GKE |
| **Connect Gateway** | connectgateway.googleapis.com | gcloud auth | Internet → PSC → GKE |

**Advantages of Connect Gateway**:
- ✅ No VPN required
- ✅ No bastion host needed
- ✅ Audit logging via IAM
- ✅ Centralized access control
- ✅ Works with private clusters

---

## Troubleshooting

### Issue: Permission Denied

**Symptom**:
```
Error: User does not have permission to access GKE Hub
```

**Resolution**:
```bash
# Verify module IAM bindings were applied
cd ~/pcc/infra/pcc-devops-infra/environments/nonprod
terraform show | grep -A 10 "module.gke_connect_gateway_iam"

# Check module outputs
terraform output -module=gke_connect_gateway_iam

# Verify IAM binding in GCP
gcloud projects get-iam-policy pcc-prj-devops-nonprod \
  --flatten="bindings[].members" \
  --filter="bindings.role:roles/gkehub.gatewayAdmin"
```

### Issue: Membership Not Found

**Symptom**:
```
ERROR: (gcloud.container.fleet.memberships.get-credentials) NOT_FOUND: Membership not found
```

**Resolution**:
- Verify Phase 3.9 completed successfully
- Check: `gcloud container fleet memberships list --project=pcc-prj-devops-nonprod`
- Wait 2-3 minutes for Hub membership registration

---

## Next Phase Dependencies

**Phase 3.12** will:
- Validate Workload Identity configuration
- Test pod-level GCP authentication
- Verify ServiceAccount annotations

**Note**: Workload Identity **feature flag** is validated, not bindings. Bindings are deferred to Phase 6 (ArgoCD).

---

## References

- **Connect Gateway**: https://cloud.google.com/anthos/multicluster-management/gateway
- **IAM Roles**: https://cloud.google.com/kubernetes-engine/docs/how-to/iam
- **ADR-002**: Apigee GKE Ingress Strategy (Connect Gateway pattern)

---

## Time Estimate

- **Verify Hub membership**: 1 minute
- **Create iam-member module**: 8-10 minutes (Claude Code - 3 files + commit/tag)
- **Create iam.tf**: 3 minutes (Claude Code - call module)
- **Apply IAM bindings**: 3 minutes (terraform init + apply)
- **Get credentials**: 2 minutes
- **Test kubectl**: 3-4 minutes
- **Total**: 20-23 minutes

---

**Status**: Ready for execution
**Next**: Phase 3.12 - Validate Workload Identity (WARP)
