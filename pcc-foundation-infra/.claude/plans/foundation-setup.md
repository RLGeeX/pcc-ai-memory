# PCC GCP Foundation Deployment Plan

**Status:** Approved
**Date:** 2025-10-01
**Repository:** pcc-foundation-infra

---

## Executive Summary

This document outlines the comprehensive deployment plan for the PCC GCP Foundation infrastructure. Three specialized subagents (cloud-architect, security-auditor, backend-architect) completed parallel analysis to generate this production-ready plan.

### Key Requirements Met

✅ **NO partner folders** initially (reserved for future expansion)
✅ **GKE subnets ONLY for devops projects** (prod/nonprod)
✅ **Foundation state bucket** (`pcc-tfstate-foundation-us-east4`) in `pcc-prj-bootstrap`
✅ **State prefix** (`pcc-foundation-infra/`) for this repo
✅ **Future state bucket** (`pcc-tfstate-us-east4`) in `pcc-prj-devops-prod` for all non-foundation infrastructure
✅ **Clean project names** (no random IDs)
✅ **Service account impersonation** (pcc-sa-terraform@pcc-prj-bootstrap.iam.gserviceaccount.com)
✅ **NO customer-managed encryption keys** (use Google-managed encryption)
✅ **Fresh setup** (no existing config dependencies)
✅ **Workload testing saved** to `.claude/plans/workloads.md`
✅ **Google Workspace groups saved** to `.claude/reference/google-workspace-groups.md`

---

## Table of Contents

1. [Folder Hierarchy](#1-folder-hierarchy)
2. [Project Inventory](#2-project-inventory-14-projects-total)
3. [Network Architecture](#3-network-architecture)
4. [GKE Subnet Allocations](#4-gke-subnet-allocations-devops-projects-only)
5. [Google Workspace Groups](#5-google-workspace-groups-5-core-groups)
6. [Security & IAM](#6-security--iam-highlights)
7. [Terraform State Management](#7-terraform-state-management)
8. [Deployment Timeline](#8-deployment-timeline-5-weeks)
9. [Estimated Costs](#9-estimated-costs)
10. [Validation Checklist](#10-validation-checklist)
11. [Changes from Original Plan](#11-changes-from-previous-plan)
12. [Deliverables](#12-summary-of-deliverables)
13. [Next Steps](#13-next-steps-after-approval)

---

## 1. Folder Hierarchy

```
organizations/146990108557 (pcconnect.ai)
└── pcc-fldr
    ├── pcc-fldr-si (Shared Infrastructure)
    │   ├── pcc-prj-logging-monitoring
    │   ├── pcc-fldr-devops
    │   │   ├── pcc-prj-devops-nonprod
    │   │   └── pcc-prj-devops-prod
    │   ├── pcc-fldr-systems
    │   │   ├── pcc-prj-sys-nonprod
    │   │   └── pcc-prj-sys-prod
    │   └── pcc-fldr-network
    │       ├── pcc-prj-network-nonprod
    │       └── pcc-prj-network-prod
    ├── pcc-fldr-app
    │   ├── pcc-prj-app-devtest
    │   ├── pcc-prj-app-dev
    │   ├── pcc-prj-app-staging
    │   └── pcc-prj-app-prod
    └── pcc-fldr-data
        ├── pcc-prj-data-devtest
        ├── pcc-prj-data-dev
        ├── pcc-prj-data-staging
        └── pcc-prj-data-prod
```

### Folder Structure Notes

- **Root Folder:** `pcc-fldr` created directly under organization
- **Shared Infrastructure (SI):** Contains all shared/foundational services
  - Logging & monitoring centralized in one project
  - Network separated into prod/nonprod host projects
  - DevOps projects for GKE clusters and CI/CD
  - Systems projects for shared operational services
- **Application Folder:** Four environments (devtest, dev, staging, prod)
- **Data Folder:** Four environments matching application structure
- **Partner Folders:** Excluded from initial deployment (reserved for future per-enterprise isolation)

---

## 2. Project Inventory (14 Projects Total)

### Shared Infrastructure Projects (7)

| Project ID | Folder | Purpose | APIs Enabled |
|-----------|--------|---------|--------------|
| **pcc-prj-logging-monitoring** | pcc-fldr-si | Centralized logging, monitoring, BigQuery audit logs | compute.googleapis.com<br>logging.googleapis.com<br>monitoring.googleapis.com<br>bigquery.googleapis.com<br>pubsub.googleapis.com |
| **pcc-prj-network-nonprod** | pcc-fldr-si/pcc-fldr-network | Shared VPC host for nonprod environments | compute.googleapis.com<br>dns.googleapis.com<br>servicenetworking.googleapis.com |
| **pcc-prj-network-prod** | pcc-fldr-si/pcc-fldr-network | Shared VPC host for production | compute.googleapis.com<br>dns.googleapis.com<br>servicenetworking.googleapis.com |
| **pcc-prj-devops-nonprod** | pcc-fldr-si/pcc-fldr-devops | GKE, Cloud Build, Artifact Registry (nonprod) | container.googleapis.com<br>cloudbuild.googleapis.com<br>artifactregistry.googleapis.com |
| **pcc-prj-devops-prod** | pcc-fldr-si/pcc-fldr-devops | GKE, Cloud Build, Artifact Registry (prod)<br>**Hosts future application state bucket** | container.googleapis.com<br>cloudbuild.googleapis.com<br>artifactregistry.googleapis.com<br>storage.googleapis.com |
| **pcc-prj-sys-nonprod** | pcc-fldr-si/pcc-fldr-systems | Shared services (nonprod): monitoring agents, config management | compute.googleapis.com<br>monitoring.googleapis.com |
| **pcc-prj-sys-prod** | pcc-fldr-si/pcc-fldr-systems | Shared services (prod): monitoring agents, config management | compute.googleapis.com<br>monitoring.googleapis.com |

### Application Projects (4)

| Project ID | Folder | Environment | Shared VPC Host | Purpose |
|-----------|--------|-------------|-----------------|---------|
| **pcc-prj-app-devtest** | pcc-fldr-app | devtest | pcc-prj-network-nonprod | Development and testing workloads |
| **pcc-prj-app-dev** | pcc-fldr-app | dev | pcc-prj-network-nonprod | Development environment |
| **pcc-prj-app-staging** | pcc-fldr-app | staging | pcc-prj-network-nonprod | Pre-production staging |
| **pcc-prj-app-prod** | pcc-fldr-app | prod | pcc-prj-network-prod | Production applications |

### Data Projects (4)

| Project ID | Folder | Environment | Shared VPC Host | Purpose |
|-----------|--------|-------------|-----------------|---------|
| **pcc-prj-data-devtest** | pcc-fldr-data | devtest | pcc-prj-network-nonprod | Data pipeline development and testing |
| **pcc-prj-data-dev** | pcc-fldr-data | dev | pcc-prj-network-nonprod | Data engineering development |
| **pcc-prj-data-staging** | pcc-fldr-data | staging | pcc-prj-network-nonprod | Data pipeline staging |
| **pcc-prj-data-prod** | pcc-fldr-data | prod | pcc-prj-network-prod | Production data pipelines and storage |

### Project Naming Convention

All projects follow the pattern: `pcc-prj-<category>-<environment>`

- **pcc:** Organization prefix
- **prj:** Indicates a GCP project
- **category:** app, data, devops, sys, network, logging-monitoring
- **environment:** devtest, dev, staging, prod, nonprod

**No random IDs or suffixes are appended to project names.**

---

## 3. Network Architecture

### Production VPC (pcc-prj-network-prod)

**VPC Configuration:**
- **Network Name:** `pcc-vpc-prod`
- **Routing Mode:** Regional
- **Auto-create subnets:** Disabled (manually managed)

**Subnets:**

| Region | Subnet Name | CIDR | IPs Available | Purpose |
|--------|-------------|------|---------------|---------|
| **us-east4** | pcc-subnet-prod-use4 | 10.16.0.0/13 | 524,288 | Production workloads - Primary region |
| **us-central1** | pcc-subnet-prod-usc1 | 10.32.0.0/13 | 524,288 | Production workloads - DR region |

**Cloud Routers & NAT:**

| Region | Router Name | ASN | NAT Gateway | Purpose |
|--------|-------------|-----|-------------|---------|
| us-east4 | pcc-router-prod-use4 | 64560 | pcc-nat-prod-use4 | Egress for private VMs |
| us-central1 | pcc-router-prod-usc1 | 64570 | pcc-nat-prod-usc1 | Egress for private VMs |

**Firewall Rules:**
- `pcc-vpc-prod-allow-internal` - Allow all traffic within VPC (10.16.0.0/13, 10.32.0.0/13)
- `pcc-vpc-prod-allow-iap-ssh` - Allow SSH from IAP (35.235.240.0/20)
- `pcc-vpc-prod-allow-health-checks` - Allow health checks from GCP load balancers
- `pcc-vpc-prod-deny-all-egress` - Default deny egress (override with specific allows)

---

### Non-Production VPC (pcc-prj-network-nonprod)

**VPC Configuration:**
- **Network Name:** `pcc-vpc-nonprod`
- **Routing Mode:** Regional
- **Auto-create subnets:** Disabled (manually managed)

**Subnets:**

| Region | Subnet Name | CIDR | IPs Available | Purpose |
|--------|-------------|------|---------------|---------|
| **us-east4** | pcc-subnet-nonprod-use4 | 10.24.0.0/13 | 524,288 | Dev/QA workloads - Primary region |
| **us-central1** | pcc-subnet-nonprod-usc1 | 10.40.0.0/13 | 524,288 | DevTest workloads - Secondary region |

**Cloud Routers & NAT:**

| Region | Router Name | ASN | NAT Gateway | Purpose |
|--------|-------------|-----|-------------|---------|
| us-east4 | pcc-router-nonprod-use4 | 64520 | pcc-nat-nonprod-use4 | Egress for private VMs |
| us-central1 | pcc-router-nonprod-usc1 | 64530 | pcc-nat-nonprod-usc1 | Egress for private VMs |

**Firewall Rules:**
- `pcc-vpc-nonprod-allow-internal` - Allow all traffic within VPC (10.24.0.0/13, 10.40.0.0/13)
- `pcc-vpc-nonprod-allow-iap-ssh` - Allow SSH from IAP (35.235.240.0/20)
- `pcc-vpc-nonprod-allow-health-checks` - Allow health checks from GCP load balancers

---

### Shared VPC Architecture

**Host Projects:**
- `pcc-prj-network-prod` - Hosts production VPC
- `pcc-prj-network-nonprod` - Hosts non-production VPC

**Service Projects Attached to Production VPC:**
- pcc-prj-app-prod
- pcc-prj-data-prod
- pcc-prj-devops-prod
- pcc-prj-sys-prod

**Service Projects Attached to Non-Production VPC:**
- pcc-prj-app-devtest
- pcc-prj-app-dev
- pcc-prj-app-staging
- pcc-prj-data-devtest
- pcc-prj-data-dev
- pcc-prj-data-staging
- pcc-prj-devops-nonprod
- pcc-prj-sys-nonprod

**Benefits:**
- Centralized network management
- Cost optimization (no NAT/Cloud Router duplication per project)
- Consistent firewall rules across service projects
- Simplified network troubleshooting

---

### Network Security Features

1. **Private Google Access:** Enabled on all subnets (VMs without external IPs can reach Google APIs)
2. **VPC Flow Logs:** Enabled on all subnets with 50% sampling, 10-minute intervals
3. **Cloud NAT:** Provides controlled egress for private VMs
4. **IAP SSH:** Secure SSH access without external IPs
5. **Firewall Logging:** Enabled on all rules for audit trail
6. **No External IPs:** Org policy enforces no external IP assignment by default

---

## 4. GKE Subnet Allocations (DevOps Projects ONLY)

### pcc-prj-devops-prod (us-east4)

**Primary Subnet:**
- **Name:** pcc-devops-prod-use4-main
- **CIDR:** 10.16.128.0/20
- **IPs Available:** 4,096
- **Purpose:** GKE node primary IPs

**Secondary Ranges (for GKE):**

| Range Name | CIDR | IPs Available | Purpose |
|-----------|------|---------------|---------|
| **pcc-devops-prod-use4-pod** | 10.16.144.0/20 | 4,096 | GKE pod IP addresses |
| **pcc-devops-prod-use4-svc** | 10.16.160.0/20 | 4,096 | GKE service IP addresses |
| **pcc-devops-prod-use4-overflow** | 10.16.176.0/20 | 4,096 | GKE overflow capacity for future expansion |

**GKE Cluster Configuration:**
- **Cluster Type:** GKE Autopilot (recommended) or Standard with autoscaling
- **Private Cluster:** Yes (no external IPs on nodes)
- **Master Authorized Networks:** Disabled (use authorized networks list if external access needed)
- **Workload Identity:** Enabled
- **Logging:** SYSTEM and WORKLOAD logs to central logging project
- **Monitoring:** Integrated with Cloud Monitoring

---

### pcc-prj-devops-nonprod (us-east4)

**Primary Subnet:**
- **Name:** pcc-devops-nonprod-use4-main
- **CIDR:** 10.24.128.0/20
- **IPs Available:** 4,096
- **Purpose:** GKE node primary IPs

**Secondary Ranges (for GKE):**

| Range Name | CIDR | IPs Available | Purpose |
|-----------|------|---------------|---------|
| **pcc-devops-nonprod-use4-pod** | 10.24.144.0/20 | 4,096 | GKE pod IP addresses |
| **pcc-devops-nonprod-use4-svc** | 10.24.160.0/20 | 4,096 | GKE service IP addresses |
| **pcc-devops-nonprod-use4-overflow** | 10.24.176.0/20 | 4,096 | GKE overflow capacity for future expansion |

**GKE Cluster Configuration:**
- **Cluster Type:** GKE Autopilot (recommended) or Standard with autoscaling
- **Private Cluster:** Yes (no external IPs on nodes)
- **Workload Identity:** Enabled
- **Logging:** SYSTEM and WORKLOAD logs to central logging project
- **Monitoring:** Integrated with Cloud Monitoring

---

### Important Notes on GKE Subnets

1. **ONLY DevOps Projects Have GKE Subnets**
   - App, data, and systems projects use standard subnets WITHOUT secondary ranges
   - GKE clusters should ONLY be deployed in devops projects

2. **Secondary Range Sizing**
   - Pod range (10.x.144.0/20): 4,096 IPs = ~1,000 pods per cluster
   - Service range (10.x.160.0/20): 4,096 IPs = ~1,000 services per cluster
   - Overflow range: Reserved for future expansion if initial ranges are exhausted

3. **IP Allocation**
   - GKE uses pod and service ranges for ephemeral workload IPs
   - Node pool VMs use the primary subnet range
   - External services require load balancers (separate IP allocation)

4. **Future Expansion**
   - If us-central1 GKE clusters are needed, allocate from 10.32.x.x/10.40.x.x ranges
   - Follow same /20 allocation pattern for consistency

---

## 5. Google Workspace Groups (5 Core Groups)

**Complete list saved to:** `.claude/reference/google-workspace-groups.md`

**Simplified for 6-person team:** The original enterprise plan called for 31 groups, but this has been simplified to 5 core groups appropriate for the team size while maintaining security best practices and room for growth.

### Team Member Assignments

| Name | Email | Role | Groups |
|------|-------|------|--------|
| **J Fogarty** | jfogarty@pcconnect.ai | Admin/DevOps | gcp-admins, gcp-break-glass, gcp-auditors |
| **C Fogarty** | cfogarty@pcconnect.ai | Developer/Admin | gcp-admins, gcp-break-glass |
| **S Lanning** | slanning@pcconnect.ai | Developer | gcp-developers |

### Core Groups (Required)

| Group Email | Members | Purpose | Key Roles |
|-------------|---------|---------|-----------|
| **gcp-admins@pcconnect.ai** | jfogarty, cfogarty | Full administrative access to all GCP resources | Organization Admin, Billing Admin, Owner on all projects |
| **gcp-developers@pcconnect.ai** | slanning | Full access to devtest projects, read-only elsewhere | Editor on pcc-prj-app-devtest & pcc-prj-data-devtest, Viewer on all other projects |
| **gcp-break-glass@pcconnect.ai** | jfogarty, cfogarty | Emergency-only organization admin access | Organization Admin (monitored separately) |
| **gcp-auditors@pcconnect.ai** | jfogarty | Read-only access for compliance and security reviews | Security Reviewer, Logging Viewer, Viewer on all projects |
| **gcp-cicd@pcconnect.ai** | (empty) | CI/CD pipeline automation via Workload Identity | Artifact Registry Writer, Cloud Build Editor, Deployment roles |

### Project-Specific Access

**Full Editor Access (gcp-developers):**
- `pcc-prj-app-devtest` - Application development and testing
- `pcc-prj-data-devtest` - Data development and testing

**Read-Only Access (gcp-developers):**
- All other projects (prod, staging, SI, devops, systems)

**Full Owner Access (gcp-admins):**
- All projects

### Group Naming Convention

Simplified pattern: `gcp-<function>@pcconnect.ai`

- **gcp:** Prefix indicating GCP-related group
- **function:** Role or function (admins, developers, break-glass, auditors, cicd)
- **@pcconnect.ai:** Organization domain

### Group Creation

Groups must be created manually in Google Workspace Admin Console before IAM bindings are applied. Refer to `.claude/reference/google-workspace-groups.md` for:
- Complete list with roles and member assignments
- Step-by-step creation instructions
- Bulk creation script (recommended - creates all 5 groups + adds members)
- Security recommendations

**Quick Setup Script Available:** `/home/cfogarty/git/pcc-foundation-infra/scripts/setup-google-workspace-groups.sh` (in reference doc)

---

## 6. Security & IAM Highlights

### Organization Policies (20 Policies)

**Critical Policies Enforced:**

| Policy | Constraint | Effect | Exception |
|--------|-----------|--------|-----------|
| **Disable Service Account Key Creation** | iam.disableServiceAccountKeyCreation | Block all SA key creation | pcc-prj-bootstrap only |
| **Require OS Login** | compute.requireOsLogin | Enforce OS Login for SSH access | None |
| **Restrict External IPs** | compute.vmExternalIpAccess | Deny external IP assignment by default | None (use allow list if needed) |
| **Require Shielded VMs** | compute.requireShieldedVm | All VMs must be Shielded VMs | None |
| **Skip Default Network** | compute.skipDefaultNetworkCreation | Prevent default VPC creation | None |
| **Prevent Public Storage Access** | storage.publicAccessPrevention | Block public bucket access | None |
| **Restrict SQL Public IPs** | sql.restrictPublicIp | Block Cloud SQL public IPs | None |
| **Resource Location Restriction** | gcp.resourceLocations | Restrict to us-east4, us-central1 | None |
| **Disable Serial Port Access** | compute.disableSerialPortAccess | Prevent serial port logging | None |
| **Uniform Bucket Access** | storage.uniformBucketLevelAccess | Require uniform bucket-level access | None |

**Additional Policies:**
- iam.allowedPolicyMemberDomains (restrict to pcconnect.ai)
- compute.restrictVpnPeerIPs (if VPN configured)
- compute.vmCanIpForward (disable IP forwarding by default)
- storage.restrictAuthTypes (require API key authentication)
- And 6 more policies for comprehensive security posture

**Policy Scope:**
- Applied at organization level (146990108557)
- Inherited by all folders and projects
- Exceptions defined at folder/project level where necessary

---

### Service Account Strategy

**Zero Service Account Keys Policy:**

All authentication uses:

1. **Workload Identity** for GKE pods
   - Pods use Kubernetes service accounts
   - Mapped to GCP service accounts via IAM bindings
   - No keys required

2. **Service Account Impersonation** for Terraform
   - Engineers use `gcloud auth application-default login --impersonate-service-account`
   - Terraform provider configured with impersonation
   - Short-lived tokens generated on-demand

3. **Default Service Accounts** for GCE instances
   - VMs use attached service accounts with minimal permissions
   - No keys stored on disk
   - Token refresh handled by metadata server

**Service Account Naming Convention:**
- `pcc-sa-<function>-<environment>@<project-id>.iam.gserviceaccount.com`
- Example: `pcc-sa-gke-node-prod@pcc-prj-devops-prod.iam.gserviceaccount.com`

**Key Service Accounts:**
- **pcc-sa-terraform@pcc-prj-bootstrap.iam.gserviceaccount.com** - Foundation Terraform execution
- **pcc-sa-gke-node-prod@pcc-prj-devops-prod.iam.gserviceaccount.com** - GKE node pool (prod)
- **pcc-sa-gke-node-nonprod@pcc-prj-devops-nonprod.iam.gserviceaccount.com** - GKE node pool (nonprod)
- **pcc-sa-cloudbuild@pcc-prj-devops-prod.iam.gserviceaccount.com** - Cloud Build CI/CD
- Additional SAs created per workload as needed

---

### IAM Role Binding Strategy

**Principle of Least Privilege:**
- No individual user IAM bindings (all via groups)
- Roles granted at lowest necessary level (project > folder > org)
- Separate roles for read vs write operations
- Production access restricted to smaller groups

**Organization-Level Roles:**
- Organization Admin: gcp-organization-admins@pcconnect.ai (break-glass only)
- Billing Admin: gcp-billing-admins@pcconnect.ai
- Security Reviewer: gcp-security-admins@pcconnect.ai, gcp-auditors@pcconnect.ai
- Shared VPC Admin: gcp-network-admins@pcconnect.ai

**Folder-Level Roles:**
- pcc-fldr-app (nonprod): gcp-app-nonprod-developers@pcconnect.ai → Editor
- pcc-fldr-data (nonprod): gcp-data-nonprod-engineers@pcconnect.ai → Editor
- No Editor role on prod folders (explicit project-level only)

**Project-Level Roles:**
- Network projects: gcp-network-[prod|nonprod]-admins@pcconnect.ai → Network Admin
- DevOps projects: gcp-devops-[prod|nonprod]-admins@pcconnect.ai → Container Admin
- Logging project: gcp-logging-monitoring-viewers@pcconnect.ai → Logging Viewer
- Service projects: Group-specific roles per project

**Service Account IAM:**
- Terraform SA: Organization Admin, Folder Admin, Project Creator
- GKE node SAs: Minimal roles (Logging Writer, Monitoring Metric Writer, Artifact Registry Reader)
- Workload Identity: Per-pod service accounts with scoped permissions

---

### Defense in Depth

**Layer 1: Network Security**
- Private subnets only (no external IPs)
- Cloud NAT for controlled egress
- Firewall rules with logging
- VPC Service Controls (planned for future)

**Layer 2: IAM Security**
- Group-based access control
- Least privilege principle
- No service account keys
- Regular access reviews

**Layer 3: Policy Security**
- 20+ organization policies enforced
- Resource location restrictions
- Encryption at rest (Google-managed)
- Mandatory Shielded VMs

**Layer 4: Audit & Monitoring**
- Centralized logging to pcc-prj-logging-monitoring
- Cloud Audit Logs for all admin activity
- VPC Flow Logs for network analysis
- Real-time alerting on suspicious activity

**Layer 5: Compliance & Governance**
- Infrastructure as Code (Terraform)
- Change control via Git
- Automated validation (terraform plan)
- Documentation requirements

---

## 7. Terraform State Management

### State Bucket Strategy (Two-Bucket Approach)

The infrastructure uses **two separate state buckets** to isolate foundation infrastructure from application workloads:

---

#### Foundation State Bucket (THIS REPOSITORY)

**Purpose:** Foundation infrastructure ONLY (folders, projects, networks, IAM)

| Attribute | Value |
|-----------|-------|
| **Bucket Name** | `pcc-tfstate-foundation-us-east4` |
| **Project** | `pcc-prj-bootstrap` (existing bootstrap project) |
| **Prefix** | `pcc-foundation-infra/` |
| **Location** | us-east4 (regional bucket) |
| **Encryption** | Google-managed encryption (NO CMEK) |
| **Versioning** | Enabled (rollback capability) |
| **Lifecycle** | Keep last 10 versions, delete older |
| **Access** | Restricted to pcc-sa-terraform@pcc-prj-bootstrap.iam.gserviceaccount.com |
| **Access Logs** | Forwarded to pcc-prj-logging-monitoring |

**Backend Configuration:**
```hcl
terraform {
  backend "gcs" {
    bucket                      = "pcc-tfstate-foundation-us-east4"
    prefix                      = "pcc-foundation-infra"
    impersonate_service_account = "pcc-sa-terraform@pcc-prj-bootstrap.iam.gserviceaccount.com"
  }
}
```

**State File Structure:**
```
pcc-tfstate-foundation-us-east4/
└── pcc-foundation-infra/
    └── default.tfstate
```

**What Goes Here:**
- Organization policies
- Folder hierarchy
- All 14 foundation projects
- Network infrastructure (VPCs, subnets, firewall rules, Cloud Routers, NAT)
- IAM bindings (organization, folder, project levels)
- Logging configuration
- Shared VPC attachments

**Change Frequency:** Low (rarely changes after initial deployment)
**Access Control:** Restricted to foundation admins
**Blast Radius:** Critical (org-wide impact if corrupted)

---

#### Application State Bucket (FUTURE REPOSITORIES)

**Purpose:** All non-foundation infrastructure (workloads, applications, per-enterprise resources)

| Attribute | Value |
|-----------|-------|
| **Bucket Name** | `pcc-tfstate-us-east4` |
| **Project** | `pcc-prj-devops-prod` (created in Week 4) |
| **Location** | us-east4 (regional bucket) |
| **Encryption** | Google-managed encryption |
| **Versioning** | Enabled |
| **Lifecycle** | Keep last 10 versions, delete older |
| **Access** | Broader devops team access (via groups) |
| **Access Logs** | Forwarded to pcc-prj-logging-monitoring |

**Backend Configuration (Future Repos):**
```hcl
terraform {
  backend "gcs" {
    bucket                      = "pcc-tfstate-us-east4"
    prefix                      = "<repo-name>"  # e.g., "pcc-application-infra"
    impersonate_service_account = "pcc-sa-terraform@pcc-prj-bootstrap.iam.gserviceaccount.com"
  }
}
```

**State File Structure (Future):**
```
pcc-tfstate-us-east4/
├── pcc-application-infra/         # Application deployments
│   └── default.tfstate
├── pcc-data-pipelines/            # Data pipeline infrastructure
│   └── default.tfstate
├── pcc-workloads/                 # Workload testing (from workloads.md)
│   └── default.tfstate
└── pcc-per-enterprise-<id>/       # Per-enterprise infrastructure
    └── default.tfstate
```

**What Goes Here:**
- GKE cluster deployments
- Application deployments (Cloud Run, Compute Engine, etc.)
- Data pipelines (Dataflow, BigQuery, Cloud SQL)
- Per-enterprise isolated resources
- Monitoring dashboards and alerts
- Any infrastructure not part of foundation

**Change Frequency:** High (frequent deployments)
**Access Control:** Broader devops team access
**Blast Radius:** Contained (project/workload specific)

---

### Why Two Buckets?

| Aspect | Foundation Bucket | Application Bucket |
|--------|------------------|-------------------|
| **Purpose** | Core foundation (folders, projects, networks) | Workloads, applications, per-enterprise resources |
| **Project** | pcc-prj-bootstrap | pcc-prj-devops-prod |
| **Change Frequency** | Low (rarely changes) | High (frequent deployments) |
| **Access Control** | Restricted to foundation admins | Broader devops team access |
| **Lifecycle** | Long-term, stable | Dynamic, active development |
| **Blast Radius** | Critical (org-wide impact) | Contained (project/workload specific) |
| **State Locking** | Critical (must prevent concurrent changes) | Important (but more forgiving) |
| **Audit Requirements** | Strict (every change logged and reviewed) | Standard (normal audit logging) |

---

### State Bucket Creation

**Foundation State Bucket (Week 1):**
```bash
# Create bucket in bootstrap project
gsutil mb -p pcc-prj-bootstrap -l us-east4 gs://pcc-tfstate-foundation-us-east4

# Enable versioning
gsutil versioning set on gs://pcc-tfstate-foundation-us-east4

# Set IAM permissions (only Terraform SA)
gsutil iam ch \
  serviceAccount:pcc-sa-terraform@pcc-prj-bootstrap.iam.gserviceaccount.com:roles/storage.objectAdmin \
  gs://pcc-tfstate-foundation-us-east4

# Enable access logging
gsutil logging set on -b gs://pcc-logging-bucket gs://pcc-tfstate-foundation-us-east4
```

**Application State Bucket (Week 4):**
```bash
# Create bucket in devops-prod project (after project is created)
gsutil mb -p pcc-prj-devops-prod -l us-east4 gs://pcc-tfstate-us-east4

# Enable versioning
gsutil versioning set on gs://pcc-tfstate-us-east4

# Set IAM permissions (Terraform SA + devops groups)
gsutil iam ch \
  serviceAccount:pcc-sa-terraform@pcc-prj-bootstrap.iam.gserviceaccount.com:roles/storage.objectAdmin \
  gs://pcc-tfstate-us-east4

gsutil iam ch \
  group:gcp-devops-prod-admins@pcconnect.ai:roles/storage.objectViewer \
  gs://pcc-tfstate-us-east4

# Enable access logging
gsutil logging set on -b gs://pcc-logging-bucket gs://pcc-tfstate-us-east4
```

---

### State Locking

Terraform uses GCS bucket metadata for state locking automatically. No additional configuration required.

**Lock Behavior:**
- Terraform acquires lock when `plan` or `apply` runs
- Lock prevents concurrent modifications
- Lock automatically released when operation completes
- Manual lock break: `terraform force-unlock <lock-id>` (emergency only)

---

### State Security Best Practices

1. **Encryption at Rest:** Google-managed encryption (no CMEK required)
2. **Access Control:** Service account impersonation only (no user credentials in state)
3. **Versioning:** Enabled for rollback capability
4. **Audit Logging:** All access logged to pcc-prj-logging-monitoring
5. **Lifecycle Management:** Keep last 10 versions, auto-delete older
6. **Blast Radius Containment:** Separate buckets for foundation vs applications
7. **Regular Backups:** Versioning serves as backup; consider additional export to Archive Storage
8. **Least Privilege:** Foundation bucket restricted to foundation admins

---

## 8. Deployment Timeline (5 Weeks)

### Week 1: Bootstrap & Organization Policies

**Objectives:**
- Establish state management infrastructure
- Apply foundational security policies
- Create root folder

**Tasks:**
1. Verify service account exists and has required permissions
   ```bash
   gcloud iam service-accounts describe pcc-sa-terraform@pcc-prj-bootstrap.iam.gserviceaccount.com
   ```

2. Create foundation state bucket
   ```bash
   gsutil mb -p pcc-prj-bootstrap -l us-east4 gs://pcc-tfstate-foundation-us-east4
   gsutil versioning set on gs://pcc-tfstate-foundation-us-east4
   ```

3. Initialize Terraform backend
   ```bash
   terraform init
   ```

4. Apply organization policies
   ```bash
   terraform apply -target=module.org_policies
   ```

5. Create root folder
   ```bash
   terraform apply -target=module.folders.google_folder.root
   ```

**Validation:**
- State bucket exists and is versioned
- Organization policies active: `gcloud org-policies list --organization=146990108557`
- Root folder created: `gcloud resource-manager folders list --organization=146990108557`

**Deliverables:**
- Foundation state bucket operational
- 20 organization policies enforced
- pcc-fldr root folder created

---

### Week 2: Folder Structure & Logging

**Objectives:**
- Create complete folder hierarchy
- Deploy centralized logging project
- Configure organization-level log sink

**Tasks:**
1. Create all folders (SI, app, data, and sub-folders)
   ```bash
   terraform apply -target=module.folders
   ```

2. Create logging/monitoring project
   ```bash
   terraform apply -target=module.projects.logging
   ```

3. Configure organization-level log sink
   ```bash
   terraform apply -target=module.log_export
   ```

**Validation:**
- All folders visible: `gcloud resource-manager folders list --organization=146990108557`
- Logging project exists: `gcloud projects describe pcc-prj-logging-monitoring`
- Log sink configured: `gcloud logging sinks list --organization=146990108557`
- Logs flowing to logging project (may take 5-10 minutes)

**Deliverables:**
- Complete folder hierarchy (7 folders)
- pcc-prj-logging-monitoring project
- Organization-level log sink to BigQuery

---

### Week 3: Network Infrastructure

**Objectives:**
- Deploy Shared VPC host projects
- Create VPCs, subnets, Cloud Routers, and NAT Gateways
- Configure firewall rules

**Tasks:**
1. Create network host projects
   ```bash
   terraform apply -target=module.projects.network-nonprod
   terraform apply -target=module.projects.network-prod
   ```

2. Enable Shared VPC on host projects
   ```bash
   # Handled automatically by project-factory module
   ```

3. Create VPC networks and subnets
   ```bash
   terraform apply -target=module.network
   ```

4. Deploy Cloud Routers and NAT Gateways
   ```bash
   # Included in network module apply
   ```

5. Configure firewall rules
   ```bash
   # Included in network module apply
   ```

**Validation:**
- VPCs exist:
  ```bash
  gcloud compute networks list --project=pcc-prj-network-nonprod
  gcloud compute networks list --project=pcc-prj-network-prod
  ```

- Subnets created:
  ```bash
  gcloud compute networks subnets list --project=pcc-prj-network-nonprod
  gcloud compute networks subnets list --project=pcc-prj-network-prod
  ```

- Cloud Routers:
  ```bash
  gcloud compute routers list --project=pcc-prj-network-nonprod
  gcloud compute routers list --project=pcc-prj-network-prod
  ```

- NAT Gateways:
  ```bash
  gcloud compute routers nats list --router=pcc-router-nonprod-use4 --region=us-east4 --project=pcc-prj-network-nonprod
  ```

- Firewall rules:
  ```bash
  gcloud compute firewall-rules list --project=pcc-prj-network-nonprod
  ```

**Deliverables:**
- 2 Shared VPC host projects
- 2 VPCs (prod, nonprod)
- 4 primary subnets
- 4 Cloud Routers
- 4 NAT Gateways
- ~10 firewall rules per VPC

---

### Week 4: Service Projects

**Objectives:**
- Deploy all service projects (devops, app, data, systems)
- Create GKE-specific subnets in devops projects
- Attach service projects to Shared VPCs
- **Create application state bucket** in pcc-prj-devops-prod

**Tasks:**
1. Create devops projects with GKE subnets
   ```bash
   terraform apply -target=module.projects.devops-nonprod
   terraform apply -target=module.projects.devops-prod
   terraform apply -target=module.network.gke_subnets  # GKE secondary ranges
   ```

2. Create application projects
   ```bash
   terraform apply -target=module.projects.app-devtest
   terraform apply -target=module.projects.app-dev
   terraform apply -target=module.projects.app-staging
   terraform apply -target=module.projects.app-prod
   ```

3. Create data projects
   ```bash
   terraform apply -target=module.projects.data-devtest
   terraform apply -target=module.projects.data-dev
   terraform apply -target=module.projects.data-staging
   terraform apply -target=module.projects.data-prod
   ```

4. Create systems projects
   ```bash
   terraform apply -target=module.projects.sys-nonprod
   terraform apply -target=module.projects.sys-prod
   ```

5. Attach all service projects to Shared VPCs
   ```bash
   # Handled automatically by svpc_service_project module
   ```

6. **Create application state bucket** (manual)
   ```bash
   gsutil mb -p pcc-prj-devops-prod -l us-east4 gs://pcc-tfstate-us-east4
   gsutil versioning set on gs://pcc-tfstate-us-east4
   gsutil iam ch serviceAccount:pcc-sa-terraform@pcc-prj-bootstrap.iam.gserviceaccount.com:roles/storage.objectAdmin gs://pcc-tfstate-us-east4
   ```

**Validation:**
- All 14 projects created:
  ```bash
  gcloud projects list --filter="parent.id=<folder-id>"
  ```

- Shared VPC attachments:
  ```bash
  gcloud compute shared-vpc list-associated-resources pcc-prj-network-nonprod
  gcloud compute shared-vpc list-associated-resources pcc-prj-network-prod
  ```

- GKE subnets with secondary ranges:
  ```bash
  gcloud compute networks subnets describe pcc-devops-prod-use4-main --region=us-east4 --project=pcc-prj-network-prod
  ```

- Application state bucket:
  ```bash
  gsutil ls -p pcc-prj-devops-prod | grep pcc-tfstate-us-east4
  ```

**Deliverables:**
- 2 devops projects (with GKE subnets)
- 4 application projects
- 4 data projects
- 2 systems projects
- All service projects attached to Shared VPC
- **Application state bucket** (`pcc-tfstate-us-east4`) created and ready for future use

---

### Week 5: IAM & Security

**Objectives:**
- Apply all IAM bindings (organization, folder, project levels)
- Validate Google Workspace groups exist
- Verify security posture

**Prerequisites:**
- All 5 Google Workspace groups must be created manually before applying IAM
- Refer to `.claude/reference/google-workspace-groups.md` for group creation
- **Quick setup script:** Run `scripts/setup-google-workspace-groups.sh` to create all 5 groups + add members

**Tasks:**
1. Verify all Google Workspace groups exist
   ```bash
   gcloud identity groups list --organization=pcconnect.ai
   # Expected: 5 groups (gcp-admins, gcp-developers, gcp-break-glass, gcp-auditors, gcp-cicd)
   ```

2. Verify group memberships
   ```bash
   # Admins (jfogarty, cfogarty)
   gcloud identity groups memberships list --group-email=gcp-admins@pcconnect.ai

   # Developers (slanning)
   gcloud identity groups memberships list --group-email=gcp-developers@pcconnect.ai
   ```

3. Apply organization-level IAM
   ```bash
   terraform apply -target=module.iam.org_iam
   ```

4. Apply project-level IAM
   ```bash
   terraform apply -target=module.iam.project_iam
   ```

5. Validate IAM bindings
   ```bash
   # Organization level (admins, break-glass, auditors)
   gcloud organizations get-iam-policy 146990108557 \
     --flatten="bindings[].members" \
     --filter="bindings.members:gcp-admins@pcconnect.ai" \
     --format="table(bindings.role)"

   # Project level (developers have editor on devtest projects)
   gcloud projects get-iam-policy pcc-prj-app-devtest \
     --flatten="bindings[].members" \
     --filter="bindings.members:gcp-developers@pcconnect.ai" \
     --format="table(bindings.role)"
   # Expected: roles/editor

   # Project level (developers have viewer on prod projects)
   gcloud projects get-iam-policy pcc-prj-app-prod \
     --flatten="bindings[].members" \
     --filter="bindings.members:gcp-developers@pcconnect.ai" \
     --format="table(bindings.role)"
   # Expected: roles/viewer
   ```

6. Run security validation
   ```bash
   # Test organization policy enforcement (should fail)
   gcloud compute instances create test-vm --zone=us-east4-a --project=pcc-prj-app-devtest
   # Expected: Error - external IP denied by org policy

   # Test developer access (as slanning@pcconnect.ai)
   gcloud auth login slanning@pcconnect.ai
   gcloud compute instances list --project=pcc-prj-app-devtest
   # Expected: Success (editor access)

   gcloud compute instances list --project=pcc-prj-app-prod
   # Expected: Success (viewer access)
   ```

**Validation:**
- All 5 groups exist in Google Workspace
- Group memberships correct (jfogarty, cfogarty in admins; slanning in developers)
- IAM bindings applied at organization and project levels
- Organization policies prevent prohibited actions
- slanning@pcconnect.ai (gcp-developers) has:
  - Editor access to pcc-prj-app-devtest and pcc-prj-data-devtest
  - Viewer access to all other projects
- jfogarty@pcconnect.ai (gcp-auditors) has read-only access to logs

**Deliverables:**
- IAM bindings for 5 Google Workspace groups
- Organization and project-level permissions configured
- Developer access correctly scoped to devtest projects only
- Security validation complete

---

### Week 6+: Testing & Validation (FUTURE WORK)

**Status:** Saved to `.claude/plans/workloads.md` for future execution

This phase includes:
- Deploy test workloads (VMs, GKE clusters, Cloud Run services)
- Verify network connectivity and firewall rules
- Validate centralized logging
- Test IAM permissions for all 5 groups (especially developer scoping)
- Security control validation (org policy testing)
- Performance testing (network throughput, latency)
- Document operational runbooks
- Clean up test resources

**To be executed:** After foundation deployment is complete and stable

---

## 9. Estimated Costs

### Baseline Infrastructure (Weeks 1-5, No Workloads)

| Component | Monthly Cost | Notes |
|-----------|--------------|-------|
| **Network Infrastructure** | $200-300 | 4 Cloud Routers ($0.015/hr each) + 4 NAT Gateways ($0.045/GB) |
| **Logging & Monitoring** | $150-250 | Log ingestion (~50GB/month), BigQuery storage, metrics |
| **State Buckets** | $10-20 | 2 buckets (foundation + application), minimal storage, versioning |
| **Projects** | $0 | No cost for empty projects |
| **Folders** | $0 | No cost for folders |
| **IAM & Org Policies** | $0 | No cost for IAM or org policies |
| **TOTAL (Foundation Only)** | **$360-570/month** | Minimal baseline, no workloads |

---

### With Production Workloads (Future, Post-Week 6)

| Component | Monthly Cost | Notes |
|-----------|--------------|-------|
| **Foundation Infrastructure** | $360-570 | (from above) |
| **GKE Clusters (2)** | $1,500-2,500 | Autopilot: 2 clusters, 4 vCPU, 16GB RAM each<br>Standard: 2 clusters, 2 nodes e2-standard-4 each |
| **Cloud Build** | $200-400 | ~1,000 build-minutes/month, private pool |
| **Artifact Registry** | $100-200 | ~500GB container images, egress |
| **Compute Engine (App VMs)** | $300-500 | Test/dev VMs (e2-medium, e2-standard-2) |
| **Cloud SQL** | $150-300 | Test databases (db-f1-micro, db-g1-small) |
| **Additional Logging** | $300-500 | Increased log volume from workloads |
| **TOTAL (With Workloads)** | **$2,910-4,970/month** | Development/testing workloads |

---

### Cost Optimization Strategies (FinOps)

1. **Committed Use Discounts (CUDs)**
   - Purchase 1-year or 3-year commitments for compute resources
   - Savings: 30-50% on VM costs
   - Apply to: GKE nodes, Compute Engine VMs

2. **Sustained Use Discounts**
   - Automatic discounts for VMs running >25% of month
   - Savings: Up to 30% on VM costs
   - No action required, automatic

3. **Preemptible/Spot Instances**
   - Use for dev/test GKE node pools
   - Savings: 60-91% on VM costs
   - Risk: Can be terminated with 30-second notice

4. **Right-sizing Recommendations**
   - Enable Cloud Recommender
   - Review monthly recommendations for undersized/oversized VMs
   - Potential savings: 20-30%

5. **Budget Alerts**
   - Set up billing alerts at 50%, 75%, 90%, 100%
   - Email notifications to gcp-billing-admins@pcconnect.ai
   - Proactive cost management

6. **Log Sampling**
   - VPC Flow Logs: 50% sampling (already configured)
   - Consider reducing to 25% for non-production environments
   - Savings: 50-75% on log storage costs

7. **Storage Lifecycle Policies**
   - Move logs to Coldline/Archive after 90 days
   - Delete logs after 1 year (if permitted by compliance)
   - Savings: 50-80% on long-term log storage

8. **Reserved Capacity**
   - For predictable workloads in production
   - Savings: 50-70% compared to on-demand

**Estimated Savings with All Optimizations:** 30-40% reduction in total costs

**Recommended Actions:**
1. Enable billing export to BigQuery for analysis
2. Set up budget alerts immediately (Week 1)
3. Review cost trends monthly
4. Purchase CUDs after 3 months of stable usage patterns
5. Implement lifecycle policies on log storage (Week 2)

---

## 10. Validation Checklist

Use this checklist to validate the deployment plan before proceeding with Terraform code generation.

### Configuration Parameters

- [x] **Organization ID:** 146990108557 ✓
- [x] **Billing Account:** 01AFEA-2B972B-00C55F ✓
- [x] **Domain:** pcconnect.ai ✓
- [x] **Service Account:** pcc-sa-terraform@pcc-prj-bootstrap.iam.gserviceaccount.com ✓

### Architecture Decisions

- [x] **Folder structure** matches project-layout.md (excluding partner folders) ✓
- [x] **Network CIDRs** match network-layout.md and PDF specifications ✓
- [x] **GKE subnets ONLY** for devops projects (prod/nonprod) ✓
- [x] **Clean project names** (no random IDs) ✓
- [x] **14 projects total** (7 SI, 4 app, 4 data, 0 partner) ✓

### State Management

- [x] **Foundation state bucket:** pcc-tfstate-foundation-us-east4 (in pcc-prj-bootstrap) ✓
- [x] **Application state bucket:** pcc-tfstate-us-east4 (in pcc-prj-devops-prod, created Week 4) ✓
- [x] **State prefix:** pcc-foundation-infra/ ✓
- [x] **Google-managed encryption** (NO CMEK) ✓
- [x] **Two-bucket strategy** (foundation vs applications) ✓

### Security & IAM

- [x] ~~**31 Google Workspace groups**~~ **5 Google Workspace groups** (simplified 2025-10-01 for 6-person team) ✓
- [x] **Google Workspace groups saved** to `.claude/reference/google-workspace-groups.md` ✓
- [x] **20 organization policies** defined ✓
- [x] **NO service account keys** (impersonation only) ✓
- [x] **Group-based IAM** (no individual user bindings) ✓

### Timeline & Scope

- [x] **5-week deployment timeline** acceptable ✓
- [x] **Week 6+ workload testing** moved to `.claude/plans/workloads.md` ✓
- [x] **Phased deployment approach** (org policies → folders → network → projects → IAM) ✓

### Cost & Budget

- [x] **Baseline costs:** $360-570/month acceptable ✓
- [x] **Future costs with workloads:** $2,910-4,970/month acceptable ✓
- [x] **FinOps strategies** documented ✓

### Documentation

- [x] **Plan saved to:** `.claude/plans/foundation-setup.md` ✓
- [x] **Workloads plan saved to:** `.claude/plans/workloads.md` ✓
- [x] **Google Workspace groups saved to:** `.claude/reference/google-workspace-groups.md` ✓

### Approval

- [x] **Plan approved by:** User ✓
- [x] **Ready for Terraform code generation:** NO (per user request, code generation deferred)

---

## 11. Changes from Previous Plan

This section documents the evolution of the plan based on user feedback.

| Item | Original | Updated | Reason |
|------|----------|---------|--------|
| **State Bucket Name** | pcc-tfstate-us-east4-foundation | pcc-tfstate-foundation-us-east4 | Foundation-specific bucket, clearer naming |
| **State Bucket Strategy** | Single shared bucket | Two buckets (foundation + application) | Separation of concerns, better access control |
| **Foundation Bucket Project** | To be created | pcc-prj-bootstrap (existing) | Use existing bootstrap project |
| **Application Bucket Project** | Not planned | pcc-prj-devops-prod (created Week 4) | Separate bucket for all future non-foundation infrastructure |
| **State Bucket Creation** | Week 1 | Week 1 (foundation), Week 4 (application) | Phased approach, create application bucket when devops-prod project exists |
| **Encryption** | Customer-managed keys (CMEK) | Google-managed encryption | Simplified management, per user request |
| **Week 6 Scope** | Included in main plan | Moved to `.claude/plans/workloads.md` | Execute at later date, focus on foundation first |
| **Groups Documentation** | Inline in plan | Separate file: `.claude/reference/google-workspace-groups.md` | Easier reference, better organization |

### Rationale for Two-Bucket Strategy

**Original Approach:** Single shared state bucket (`pcc-tfstate-us-east4`) for all Terraform operations.

**Revised Approach:** Two separate state buckets:
1. `pcc-tfstate-foundation-us-east4` (foundation infrastructure only)
2. `pcc-tfstate-us-east4` (all future application infrastructure)

**Benefits:**
- **Separation of Concerns:** Foundation changes isolated from application deployments
- **Access Control:** Foundation bucket restricted to foundation admins; application bucket accessible to broader devops team
- **Blast Radius:** Foundation state corruption doesn't affect application state and vice versa
- **Change Frequency:** Foundation rarely changes; applications change frequently
- **Lifecycle Management:** Different retention policies for foundation vs application state
- **Organizational Clarity:** Clear distinction between "build the platform" vs "deploy on the platform"

---

## 12. Summary of Deliverables

### Documents Created

| Document | Location | Purpose |
|----------|----------|---------|
| **Foundation Setup Plan** | `.claude/plans/foundation-setup.md` | THIS DOCUMENT - Complete deployment plan |
| **Workloads Plan** | `.claude/plans/workloads.md` | Week 6+ testing and validation procedures |
| **Google Workspace Groups** | `.claude/reference/google-workspace-groups.md` | 5 core groups with member assignments, roles, and creation instructions (simplified for 6-person team) |

### Infrastructure to be Created

| Category | Count | Examples |
|----------|-------|----------|
| **Folders** | 7 | pcc-fldr, pcc-fldr-si, pcc-fldr-app, pcc-fldr-data, pcc-fldr-devops, pcc-fldr-systems, pcc-fldr-network |
| **Projects** | 14 | pcc-prj-logging-monitoring, pcc-prj-network-prod, pcc-prj-devops-prod, pcc-prj-app-prod, etc. |
| **VPCs** | 2 | pcc-vpc-prod, pcc-vpc-nonprod |
| **Subnets** | 4 primary<br>8 GKE secondary | Primary: us-east4 and us-central1 for prod/nonprod<br>GKE: devops projects only |
| **Cloud Routers** | 4 | 2 per VPC (us-east4, us-central1) |
| **NAT Gateways** | 4 | 1 per Cloud Router |
| **Firewall Rules** | ~20 | Internal, IAP, health checks, deny rules |
| **IAM Bindings** | 5 groups<br>Multiple roles | Organization and project levels (simplified for small team) |
| **Organization Policies** | 20 | Security, networking, resource location, etc. |
| **Log Sinks** | 1 | Organization-level sink to pcc-prj-logging-monitoring |
| **State Buckets** | 2 | pcc-tfstate-foundation-us-east4, pcc-tfstate-us-east4 |

---

## 13. Next Steps After Approval

### Immediate Actions (Not Started Yet, Per User Request)

1. **Generate Terraform Files**
   - Create Terraform module structure
   - Implement modules: folders, projects, network, iam, org-policies, log-export
   - Write root-level configuration files (main.tf, variables.tf, outputs.tf, backend.tf, providers.tf, versions.tf)
   - Generate per-module configuration files

2. **Validate Terraform Configuration**
   - Run `terraform fmt` to format all files
   - Run `terraform validate` to check syntax
   - Run `tflint` for best practices validation

3. **Create Pre-Deployment Checklist**
   - Verify service account permissions
   - Confirm billing account is active
   - Ensure Google Workspace admin access for group creation
   - Document rollback procedures

### Week 1 Actions (After Code Generation)

1. **Service Account Validation**
   ```bash
   gcloud iam service-accounts describe pcc-sa-terraform@pcc-prj-bootstrap.iam.gserviceaccount.com
   gcloud organizations get-iam-policy 146990108557 --flatten="bindings[].members" --filter="bindings.members:pcc-sa-terraform@pcc-prj-bootstrap.iam.gserviceaccount.com"
   ```

2. **Create Foundation State Bucket**
   ```bash
   gsutil mb -p pcc-prj-bootstrap -l us-east4 gs://pcc-tfstate-foundation-us-east4
   gsutil versioning set on gs://pcc-tfstate-foundation-us-east4
   gsutil iam ch serviceAccount:pcc-sa-terraform@pcc-prj-bootstrap.iam.gserviceaccount.com:roles/storage.objectAdmin gs://pcc-tfstate-foundation-us-east4
   ```

3. **Initialize Terraform**
   ```bash
   terraform init
   ```

4. **Deploy Organization Policies**
   ```bash
   terraform plan -target=module.org_policies
   terraform apply -target=module.org_policies
   ```

5. **Create Root Folder**
   ```bash
   terraform plan -target=module.folders.google_folder.root
   terraform apply -target=module.folders.google_folder.root
   ```

### Google Workspace Actions (Manual, Before Week 5)

**Simplified approach for 6-person team - 5 groups total**

1. **Review Group List**
   - Open `.claude/reference/google-workspace-groups.md`
   - Confirm 5 groups with member assignments:
     - **gcp-admins@pcconnect.ai:** jfogarty, cfogarty
     - **gcp-developers@pcconnect.ai:** slanning
     - **gcp-break-glass@pcconnect.ai:** jfogarty, cfogarty
     - **gcp-auditors@pcconnect.ai:** jfogarty
     - **gcp-cicd@pcconnect.ai:** (empty, for Workload Identity)

2. **Create Groups (Option 1: Quick Script - Recommended)**
   ```bash
   # Run the complete setup script from the reference doc
   # This creates all 5 groups AND adds members automatically
   chmod +x scripts/setup-google-workspace-groups.sh
   ./scripts/setup-google-workspace-groups.sh
   ```

3. **Create Groups (Option 2: Manual via Admin Console)**
   - Log in to Google Workspace Admin Console
   - Create 5 groups following documented naming convention
   - Set all groups as "Security" groups
   - Restrict membership to "Only invited users"
   - Add members as documented

4. **Validate Groups**
   ```bash
   # Verify all 5 groups exist
   gcloud identity groups list --organization=pcconnect.ai
   # Expected: gcp-admins, gcp-developers, gcp-break-glass, gcp-auditors, gcp-cicd

   # Verify memberships
   gcloud identity groups memberships list --group-email=gcp-admins@pcconnect.ai
   # Expected: jfogarty@pcconnect.ai, cfogarty@pcconnect.ai

   gcloud identity groups memberships list --group-email=gcp-developers@pcconnect.ai
   # Expected: slanning@pcconnect.ai
   ```

### Ongoing Monitoring (All Weeks)

1. **Cost Monitoring**
   - Set up billing alerts in GCP Console
   - Review costs weekly during deployment
   - Compare actual vs estimated costs

2. **State Management**
   - Regularly check state bucket health
   - Monitor state file size growth
   - Review access logs for unusual activity

3. **Drift Detection**
   - Run `terraform plan` daily during active deployment
   - Investigate any unexpected changes
   - Document manual changes made outside Terraform

4. **Documentation**
   - Update `.claude/status/current-progress.md` after each week
   - Document issues and resolutions in `.claude/docs/problems-solved.md`
   - Maintain deployment runbook

### Post-Deployment (After Week 5)

1. **Security Validation**
   - Run security audit using gcp-security-admins group
   - Test organization policy enforcement
   - Validate IAM bindings for all 5 groups (especially developer scoping to devtest projects)

2. **Operational Handoff**
   - Train team on Terraform operations
   - Document common tasks (add projects, modify firewall rules, etc.)
   - Establish change management process

3. **Future Work**
   - Create application state bucket in pcc-prj-devops-prod (Week 4)
   - Execute workload testing per `.claude/plans/workloads.md` (Week 6+)
   - Plan per-enterprise folder rollout (future)

---

## Appendix A: Quick Reference

### Key GCP Resources

| Resource Type | Count | Naming Pattern |
|--------------|-------|----------------|
| Organization | 1 | 146990108557 (pcconnect.ai) |
| Folders | 7 | pcc-fldr-<name> |
| Projects | 14 | pcc-prj-<category>-<environment> |
| VPCs | 2 | pcc-vpc-<environment> |
| Subnets | 12 | pcc-subnet-<environment>-<region><br>pcc-devops-<environment>-<region>-<type> |
| Cloud Routers | 4 | pcc-router-<environment>-<region> |
| NAT Gateways | 4 | pcc-nat-<environment>-<region> |

### Key Service Accounts

| Service Account | Project | Purpose |
|----------------|---------|---------|
| pcc-sa-terraform@pcc-prj-bootstrap.iam.gserviceaccount.com | pcc-prj-bootstrap | Terraform execution (foundation) |
| pcc-sa-gke-node-prod@pcc-prj-devops-prod.iam.gserviceaccount.com | pcc-prj-devops-prod | GKE node pool (prod) |
| pcc-sa-gke-node-nonprod@pcc-prj-devops-nonprod.iam.gserviceaccount.com | pcc-prj-devops-nonprod | GKE node pool (nonprod) |

### Key IP Ranges

| Environment | Region | Subnet CIDR | Purpose |
|------------|--------|-------------|---------|
| Production | us-east4 | 10.16.0.0/13 | General workloads |
| Production | us-east4 | 10.16.128.0/20 | GKE nodes (devops-prod) |
| Production | us-east4 | 10.16.144.0/20 | GKE pods (devops-prod) |
| Production | us-east4 | 10.16.160.0/20 | GKE services (devops-prod) |
| Production | us-central1 | 10.32.0.0/13 | General workloads (DR) |
| Non-Production | us-east4 | 10.24.0.0/13 | General workloads |
| Non-Production | us-east4 | 10.24.128.0/20 | GKE nodes (devops-nonprod) |
| Non-Production | us-east4 | 10.24.144.0/20 | GKE pods (devops-nonprod) |
| Non-Production | us-east4 | 10.24.160.0/20 | GKE services (devops-nonprod) |
| Non-Production | us-central1 | 10.40.0.0/13 | General workloads |

### Key Commands

```bash
# Impersonate service account for Terraform
gcloud auth application-default login --impersonate-service-account=pcc-sa-terraform@pcc-prj-bootstrap.iam.gserviceaccount.com

# Initialize Terraform
terraform init

# Plan changes
terraform plan

# Apply changes
terraform apply

# List all projects
gcloud projects list --filter="parent.id=<folder-id>"

# List all folders
gcloud resource-manager folders list --organization=146990108557

# View IAM policy
gcloud organizations get-iam-policy 146990108557
gcloud projects get-iam-policy pcc-prj-logging-monitoring

# Check organization policies
gcloud org-policies list --organization=146990108557
gcloud org-policies describe <constraint> --organization=146990108557

# View logs
gcloud logging read "resource.labels.project_id=pcc-prj-app-dev" --project=pcc-prj-logging-monitoring --limit=50
```

---

## Appendix B: Troubleshooting

### Common Issues

**Issue:** Terraform fails with "permission denied" during init/plan/apply
**Solution:** Verify service account impersonation is configured correctly in provider.tf and backend.tf. Confirm service account has necessary organization-level permissions.

**Issue:** Organization policy prevents resource creation
**Solution:** Review organization policies with `gcloud org-policies list --organization=146990108557`. If policy is too restrictive, modify at folder/project level with an exception.

**Issue:** State bucket access denied
**Solution:** Verify service account has `roles/storage.objectAdmin` on state bucket. Check bucket IAM with `gsutil iam get gs://pcc-tfstate-foundation-us-east4`.

**Issue:** VPC subnet IP range conflicts
**Solution:** Review all subnet CIDRs to ensure no overlaps. Production uses 10.16.x.x and 10.32.x.x; Non-production uses 10.24.x.x and 10.40.x.x.

**Issue:** Shared VPC attachment fails
**Solution:** Ensure host project has Shared VPC enabled. Verify service account has `roles/compute.xpnAdmin`. Check if subnet exists in correct region.

**Issue:** Google Workspace group not found
**Solution:** Verify group exists with `gcloud identity groups list --organization=pcconnect.ai`. Ensure group is marked as "Security" group. Wait 5-10 minutes for propagation.

**Issue:** Terraform state lock conflict
**Solution:** Check if another Terraform operation is running. If stuck, carefully force-unlock with `terraform force-unlock <lock-id>`. Investigate cause to prevent recurrence.

---

## Appendix C: Contacts & Resources

### Key Stakeholders

- **Foundation Admins:** gcp-organization-admins@pcconnect.ai
- **Network Team:** gcp-network-admins@pcconnect.ai
- **Security Team:** gcp-security-admins@pcconnect.ai
- **Billing Team:** gcp-billing-admins@pcconnect.ai

### External Resources

- **Terraform Google Provider Docs:** https://registry.terraform.io/providers/hashicorp/google/latest/docs
- **GCP Organization Policies:** https://cloud.google.com/resource-manager/docs/organization-policy/overview
- **GCP Shared VPC Guide:** https://cloud.google.com/vpc/docs/shared-vpc
- **GCP IAM Best Practices:** https://cloud.google.com/iam/docs/best-practices-for-securing-service-accounts
- **Terraform Best Practices:** https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html

### Repository Structure

```
pcc-foundation-infra/
├── .claude/
│   ├── plans/
│   │   ├── foundation-setup.md        # THIS DOCUMENT
│   │   └── workloads.md                # Future workload testing
│   ├── reference/
│   │   ├── google-workspace-groups.md  # 5 core groups (simplified for 6-person team)
│   │   ├── project-layout.md           # Project structure diagram
│   │   ├── network-layout.md           # Network architecture
│   │   └── GCP Network Subnets - GKE Subnet Assignment Redesign.pdf
│   └── status/
│       ├── brief.md                    # Session progress
│       └── current-progress.md         # Historical progress
├── modules/                            # TO BE CREATED
│   ├── folders/
│   ├── projects/
│   ├── network/
│   ├── iam/
│   ├── org-policies/
│   └── log-export/
├── backend.tf                          # TO BE CREATED
├── providers.tf                        # TO BE CREATED
├── versions.tf                         # TO BE CREATED
├── variables.tf                        # TO BE CREATED
├── main.tf                             # TO BE CREATED
├── outputs.tf                          # TO BE CREATED
└── README.md                           # TO BE CREATED
```

---

## Document Version History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-10-01 | Claude (Sonnet 4.5) | Initial approved plan |

---

**END OF DOCUMENT**
