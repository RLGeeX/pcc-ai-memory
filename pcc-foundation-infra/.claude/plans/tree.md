# Terraform Code Structure - Proposed Layout

**Date:** 2025-10-02
**Status:** Proposed (Not Yet Generated)
**Purpose:** Visualization of Terraform infrastructure code to be generated

---

## Directory Tree

```
pcc-foundation-infra/
├── .claude/
│   ├── docs/
│   ├── handoffs/
│   ├── plans/
│   │   ├── foundation-setup.md
│   │   └── workloads.md
│   ├── quick-reference/
│   ├── reference/
│   │   ├── google-workspace-groups.md
│   │   ├── network-layout.md
│   │   └── project-layout.md
│   └── status/
│       ├── brief.md
│       ├── current-progress.md
│       └── service-account-validation.md
│
├── terraform/
│   ├── modules/
│   │   ├── folders/
│   │   │   ├── main.tf              # Folder resources
│   │   │   ├── variables.tf
│   │   │   ├── outputs.tf
│   │   │   └── versions.tf
│   │   │
│   │   ├── projects/
│   │   │   ├── main.tf              # Project factory pattern
│   │   │   ├── variables.tf
│   │   │   ├── outputs.tf
│   │   │   └── versions.tf
│   │   │
│   │   ├── network/
│   │   │   ├── main.tf              # VPCs, subnets, firewall rules
│   │   │   ├── vpcs.tf              # VPC definitions
│   │   │   ├── subnets.tf           # Subnet configurations
│   │   │   ├── gke-subnets.tf       # GKE secondary ranges (devops only)
│   │   │   ├── cloud-nat.tf         # Cloud Routers & NAT gateways
│   │   │   ├── firewall.tf          # Firewall rules
│   │   │   ├── shared-vpc.tf        # Shared VPC host/service attachments
│   │   │   ├── variables.tf
│   │   │   ├── outputs.tf
│   │   │   └── versions.tf
│   │   │
│   │   ├── iam/
│   │   │   ├── main.tf              # IAM binding orchestration
│   │   │   ├── org-iam.tf           # Organization-level bindings
│   │   │   ├── project-iam.tf       # Project-level bindings
│   │   │   ├── variables.tf
│   │   │   ├── outputs.tf
│   │   │   └── versions.tf
│   │   │
│   │   ├── org-policies/
│   │   │   ├── main.tf              # Organization policy resources
│   │   │   ├── compute-policies.tf  # Compute-related policies
│   │   │   ├── iam-policies.tf      # IAM-related policies
│   │   │   ├── storage-policies.tf  # Storage-related policies
│   │   │   ├── network-policies.tf  # Network-related policies
│   │   │   ├── variables.tf
│   │   │   ├── outputs.tf
│   │   │   └── versions.tf
│   │   │
│   │   └── log-export/
│   │       ├── main.tf              # Organization log sink
│   │       ├── bigquery.tf          # BigQuery dataset for logs
│   │       ├── variables.tf
│   │       ├── outputs.tf
│   │       └── versions.tf
│   │
│   ├── environments/                 # Optional: environment-specific overrides
│   │   └── foundation/
│   │       └── terraform.tfvars     # Foundation-specific values
│   │
│   ├── backend.tf                   # GCS backend configuration
│   ├── providers.tf                 # Google provider with impersonation
│   ├── versions.tf                  # Terraform & provider version constraints
│   ├── variables.tf                 # Root-level input variables
│   ├── main.tf                      # Module invocations
│   ├── outputs.tf                   # Root-level outputs
│   ├── terraform.tfvars.example     # Example variable values
│   ├── .gitignore                   # Ignore .tfvars, .terraform/, etc.
│   ├── .terraform-version           # Pin Terraform version (mise/tfenv)
│   ├── .tflint.hcl                  # TFLint configuration
│   └── README.md                    # Terraform-specific README
│
├── scripts/
│   ├── create-state-bucket.sh       # Helper script for state bucket creation
│   ├── validate-prereqs.sh          # Pre-deployment validation
│   └── setup-google-workspace-groups.sh  # (Already documented)
│
├── README.md                        # Repository overview and usage
└── CLAUDE.md                        # (Already exists)
```

---

## Summary

### File Count
- **Terraform root:** 11 files (7 .tf files + 1 example + 3 config files)
- **Modules:** ~40 .tf files across 6 modules
- **Scripts:** 3 shell scripts
- **Documentation:** 2 READMEs (repo + terraform)
- **TOTAL:** ~56 new files

### Lines of Code (Estimated)
- **Terraform root:** ~300 lines
- **Modules:** ~2,000-2,500 lines
- **Scripts:** ~200 lines
- **Documentation:** ~400 lines (2 READMEs)
- **TOTAL:** ~2,900-3,400 lines of code + documentation

---

## Key Structure Changes

### All Terraform Code in terraform/ Folder
- **Root terraform/**: Backend, providers, main orchestration
- **terraform/modules/**: All 6 reusable modules
- **terraform/environments/**: Environment-specific overrides
- **Scripts stay at root**: scripts/ for helper scripts
- **Docs stay at root**: .claude/ and README.md

### Benefits of terraform/ Folder
1. **Clear separation**: Infrastructure code isolated from docs/scripts
2. **Standard practice**: Common pattern in multi-purpose repos
3. **Clean root**: Repository root less cluttered
4. **Module reusability**: Easier to reference from other repos
5. **Workspace support**: Can add other infra directories later (ansible/, k8s/, etc.)

---

## Terraform Root Files (terraform/)

| File | Purpose | Key Contents |
|------|---------|--------------|
| **backend.tf** | Backend configuration | GCS backend (pcc-tfstate-foundation-us-east4), impersonation |
| **providers.tf** | Google provider setup | Service account impersonation, default labels |
| **versions.tf** | Version constraints | Terraform ~> 1.5, google ~> 5.0 |
| **variables.tf** | Root input variables | org_id, billing_account, domain, regions |
| **main.tf** | Module orchestration | Invokes 6 modules (folders, projects, network, iam, org-policies, log-export) |
| **outputs.tf** | Root outputs | Folder IDs, project IDs, VPC IDs, subnet IDs |
| **terraform.tfvars.example** | Example values | Template for actual terraform.tfvars (not committed) |
| **README.md** | Terraform guide | How to use this Terraform code |
| **.gitignore** | Git ignore | .terraform/, *.tfstate, *.tfvars |
| **.terraform-version** | Version pin | 1.5.0 |
| **.tflint.hcl** | Linting config | TFLint rules |

---

## MODULES (terraform/modules/)

### 1. folders/ (4 files)
**Purpose:** Create organizational folder hierarchy

**Resources:**
- 7 folders (1 root + 6 sub-folders)
- Folder structure: pcc-fldr (root), pcc-fldr-si, pcc-fldr-app, pcc-fldr-data, pcc-fldr-devops, pcc-fldr-systems, pcc-fldr-network

**Files:**
- `main.tf` - Folder resources
- `variables.tf` - org_id, folder names
- `outputs.tf` - Folder IDs for downstream modules
- `versions.tf` - Provider version constraints

---

### 2. projects/ (4 files)
**Purpose:** Project factory pattern for creating 14 projects

**Resources:**
- 14 projects across SI (7), app (4), data (4) domains
- Shared VPC service project attachments
- API enablement (compute, container, logging, monitoring, etc.)
- Billing account association

**Files:**
- `main.tf` - Project factory logic with for_each
- `variables.tf` - Project list, billing account, folder IDs
- `outputs.tf` - Project IDs, project numbers
- `versions.tf` - Provider version constraints

---

### 3. network/ (10 files)
**Purpose:** Comprehensive VPC networking infrastructure

**Resources:**
- 2 VPCs (pcc-vpc-prod, pcc-vpc-nonprod)
- 12 subnets (10 primary + 2 GKE with secondary ranges)
- 4 Cloud Routers (2 per VPC, us-east4 + us-central1)
- 4 NAT Gateways (1 per router)
- ~20 firewall rules (internal, IAP, health checks, deny)
- Shared VPC host project configuration
- VPC flow logs, Private Google Access

**Files:**
- `main.tf` - Module orchestration
- `vpcs.tf` - VPC resources
- `subnets.tf` - Standard subnet configurations
- `gke-subnets.tf` - GKE subnets with secondary ranges (devops only)
- `cloud-nat.tf` - Cloud Routers and NAT gateways
- `firewall.tf` - Firewall rules
- `shared-vpc.tf` - Shared VPC host/service attachments
- `variables.tf` - Network ranges, project IDs
- `outputs.tf` - VPC IDs, subnet IDs, self-links
- `versions.tf` - Provider version constraints

---

### 4. iam/ (6 files)
**Purpose:** IAM bindings for 5 Google Workspace groups

**Resources:**
- Organization-level IAM bindings (admins, break-glass, auditors)
- Project-level IAM bindings:
  - Admins → roles/owner on all 14 projects
  - Developers → roles/editor on devtest projects, roles/viewer on others
  - Auditors → roles/viewer on all projects
  - CI/CD → deployment roles (artifact registry, cloud build, etc.)

**Files:**
- `main.tf` - IAM binding orchestration
- `org-iam.tf` - Organization-level bindings
- `project-iam.tf` - Project-level bindings
- `variables.tf` - Group emails, project IDs, org_id
- `outputs.tf` - Applied IAM bindings summary
- `versions.tf` - Provider version constraints

---

### 5. org-policies/ (8 files)
**Purpose:** 20 organization policies for security and compliance

**Policies:**
- **Compute:** requireOsLogin, vmExternalIpAccess (deny), requireShieldedVm, skipDefaultNetworkCreation, disableSerialPortAccess
- **IAM:** disableServiceAccountKeyCreation, allowedPolicyMemberDomains
- **Storage:** publicAccessPrevention, uniformBucketLevelAccess, restrictAuthTypes
- **Network:** resourceLocations (us-east4, us-central1), restrictVpnPeerIPs
- **SQL:** restrictPublicIp
- Additional policies for comprehensive security posture

**Files:**
- `main.tf` - Organization policy orchestration
- `compute-policies.tf` - Compute-related policies (OS Login, external IPs, Shielded VMs)
- `iam-policies.tf` - IAM-related policies (SA key creation, domain restrictions)
- `storage-policies.tf` - Storage-related policies (public access, uniform access)
- `network-policies.tf` - Network-related policies (resource locations, VPN)
- `variables.tf` - org_id, allowed regions, domain
- `outputs.tf` - Applied policies summary
- `versions.tf` - Provider version constraints

---

### 6. log-export/ (5 files)
**Purpose:** Centralized logging to BigQuery

**Resources:**
- Organization-level log sink
- BigQuery dataset (pcc_organization_logs) in pcc-prj-logging-prod
- Log routing configuration
- Data retention (14-day TTL on logs)

**Files:**
- `main.tf` - Log sink orchestration
- `bigquery.tf` - BigQuery dataset for logs
- `variables.tf` - org_id, project_id, dataset settings
- `outputs.tf` - Log sink ID, BigQuery dataset ID
- `versions.tf` - Provider version constraints

---

## SCRIPTS (scripts/)

### 1. create-state-bucket.sh
**Purpose:** Manual state bucket creation for Week 1 deployment

**Actions:**
- Create `pcc-tfstate-foundation-us-east4` bucket in pcc-prj-bootstrap
- Enable versioning
- Set IAM permissions (Terraform SA only)
- Configure access logging
- Set lifecycle policy (retain 90 days)

---

### 2. validate-prereqs.sh
**Purpose:** Pre-flight checks before Terraform deployment

**Checks:**
- Service account exists and has required permissions
- Billing account is active
- All 5 Google Workspace groups exist
- Group memberships are correct
- Organization ID is accessible
- Required APIs enabled on bootstrap project

**Exit codes:**
- 0 = All checks passed
- 1 = One or more checks failed

---

### 3. setup-google-workspace-groups.sh
**Purpose:** Bulk creation of 5 Google Workspace groups with members

**Note:** Already documented in `.claude/reference/google-workspace-groups.md`

---

## DOCUMENTATION

### Repository README.md (Root)
**Sections:**
1. Project Overview
2. Repository Structure
3. Quick Start
4. Prerequisites
5. Documentation Links
6. Scripts Usage
7. Contributing Guidelines

### Terraform README.md (terraform/)
**Sections:**
1. Terraform Overview
2. Prerequisites (service account, billing, groups)
3. Quick Start (configure, deploy)
4. Deployment Guide (Week 1-5 steps)
5. Module Documentation
6. State Management (two-bucket strategy)
7. Validation Commands
8. Troubleshooting
9. Cost Estimates
10. Security Considerations

---

## Module Dependency Graph

```
┌─────────────────┐
│  org-policies   │  (Week 1)
└────────┬────────┘
         │
         v
┌─────────────────┐
│     folders     │  (Week 2)
└────────┬────────┘
         │
         v
┌─────────────────┐
│   log-export    │  (Week 2)
└─────────────────┘

┌─────────────────┐
│    projects     │  (Weeks 2-4)
└────────┬────────┘
         │
         v
┌─────────────────┐
│     network     │  (Week 3-4)
└────────┬────────┘
         │
         v
┌─────────────────┐
│       iam       │  (Week 5)
└─────────────────┘
```

**Deployment Order:**
1. Organization policies (establish guardrails)
2. Folders (create hierarchy)
3. Log export (enable centralized logging)
4. Projects (provision 14 projects)
5. Network (VPCs, subnets, routers, NAT)
6. IAM (group-based access control)

---

## Terraform Commands (from terraform/ directory)

```bash
# Navigate to terraform directory
cd terraform/

# Initialize backend
terraform init

# Validate configuration
terraform validate
terraform fmt -recursive

# Plan deployment
terraform plan -out=tfplan

# Week 1: Organization policies
terraform apply -target=module.org_policies

# Week 2: Folders and logging
terraform apply -target=module.folders
terraform apply -target=module.log_export

# Week 3: Network infrastructure
terraform apply -target=module.network

# Week 4: Service projects
terraform apply -target=module.projects

# Week 5: IAM bindings
terraform apply -target=module.iam

# Full apply (after phased deployment)
terraform apply
```

---

## Estimated Effort

| Phase | Time | Files | Lines of Code |
|-------|------|-------|---------------|
| **Terraform root** | 30 min | 11 | ~300 |
| **modules/folders** | 15 min | 4 | ~150 |
| **modules/projects** | 30 min | 4 | ~300 |
| **modules/network** | 60 min | 10 | ~800 |
| **modules/iam** | 30 min | 6 | ~400 |
| **modules/org-policies** | 45 min | 8 | ~500 |
| **modules/log-export** | 15 min | 5 | ~200 |
| **Scripts** | 20 min | 3 | ~200 |
| **Documentation** | 30 min | 2 | ~400 |
| **Validation** | 30 min | - | - |
| **TOTAL** | **4-5 hours** | **56 files** | **~3,250 lines** |

---

## Next Steps After Code Generation

1. **Validate Terraform Code**
   ```bash
   cd terraform/
   terraform fmt -recursive
   terraform validate
   tflint --init && tflint
   ```

2. **Create State Bucket**
   ```bash
   cd ../
   scripts/create-state-bucket.sh
   ```

3. **Initialize Backend**
   ```bash
   cd terraform/
   terraform init
   ```

4. **Plan Deployment**
   ```bash
   terraform plan -out=tfplan
   ```

5. **Review Plan Output**
   - Expected resources: ~100-120 resources
   - Folders: 7
   - Projects: 14
   - Network resources: ~30
   - IAM bindings: ~40
   - Organization policies: 20
   - Log sinks: 1

6. **Begin Week 1 Deployment**
   ```bash
   terraform apply -target=module.org_policies
   ```

---

**Document Version:** 2.0
**Last Updated:** 2025-10-02
**Status:** Proposed structure with terraform/ folder, code generation pending approval
**Change:** Moved all Terraform code into terraform/ directory for better organization
