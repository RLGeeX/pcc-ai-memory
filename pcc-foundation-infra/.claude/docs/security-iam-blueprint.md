# PCC GCP Foundation - Security & IAM Blueprint

**Document Version:** 1.0
**Date:** 2025-10-01
**Organization:** pcconnect.ai (ID: 146990108557)
**Deployment Method:** Service account impersonation via `pcc-sa-terraform@pcc-prj-bootstrap.iam.gserviceaccount.com`

## Executive Summary

This document provides a comprehensive security and IAM blueprint for the PCC GCP Foundation infrastructure. It follows defense-in-depth principles, implements least privilege access, and establishes a robust security posture across organization, folder, and project levels.

**Key Security Principles:**
- **No Individual Users at Org Level:** All permissions granted via Google Workspace groups
- **Defense in Depth:** Multiple layers of security controls (IAM, Org Policies, Network Security)
- **Least Privilege:** Minimal permissions required for each role
- **Separation of Duties:** Distinct groups for billing, security, operations, and development
- **No Service Account Keys:** Enforce Workload Identity and short-lived tokens only
- **Audit Everything:** Comprehensive logging of all administrative actions

---

## Table of Contents

1. [IAM Role Bindings](#1-iam-role-bindings)
   - [Organization Level](#organization-level-iam)
   - [Folder Level](#folder-level-iam)
   - [Project Level](#project-level-iam)
2. [Google Workspace Groups](#2-google-workspace-groups)
3. [Organization Policies](#3-organization-policies)
4. [Service Account Strategy](#4-service-account-strategy)
5. [Shared VPC Security Architecture](#5-shared-vpc-security-architecture)
6. [Implementation Checklist](#6-implementation-checklist)

---

## 1. IAM Role Bindings

### Organization Level IAM

**Organization:** pcconnect.ai (146990108557)

| Google Workspace Group | IAM Role | Purpose | Member Count |
|------------------------|----------|---------|--------------|
| gcp-org-admins@pcconnect.ai | roles/resourcemanager.organizationAdmin | Break-glass super admins (EMERGENCY ONLY) | 2-3 max |
| gcp-security-admins@pcconnect.ai | roles/orgpolicy.policyAdmin | Manage organization policies | 3-5 |
| gcp-billing-admins@pcconnect.ai | roles/billing.admin | Billing account management | 2-4 |
| gcp-security-auditors@pcconnect.ai | roles/iam.securityReviewer | Security audit and review (read-only) | 5-10 |
| gcp-org-viewers@pcconnect.ai | roles/browser | Organization-wide visibility | 10-20 |
| gcp-logging-viewers@pcconnect.ai | roles/logging.viewer | Access audit logs | 10-15 |
| gcp-sharedvpc-admins-prod@pcconnect.ai | roles/compute.xpnAdmin | Shared VPC administration (prod) | 2-3 |
| gcp-sharedvpc-admins-nonprod@pcconnect.ai | roles/compute.xpnAdmin | Shared VPC administration (nonprod) | 3-5 |

**Critical Security Notes:**
- `gcp-org-admins` should be used ONLY for emergency break-glass scenarios
- Regular operations should NEVER require organization admin access
- Implement alerting on any usage of organization admin role
- Consider time-bound access elevation (Just-In-Time access) for future implementation

---

### Folder Level IAM

#### Folder: pcc-fldr (Root Folder)

| Google Workspace Group | IAM Role | Purpose |
|------------------------|----------|---------|
| gcp-security-auditors@pcconnect.ai | roles/viewer | Visibility across all folders |

#### Folder: pcc-fldr-si (Systems Integration)

| Google Workspace Group | IAM Role | Purpose |
|------------------------|----------|---------|
| gcp-network-admins-prod@pcconnect.ai | roles/viewer | Visibility for prod network resources |
| gcp-network-admins-nonprod@pcconnect.ai | roles/viewer | Visibility for nonprod network resources |

**Note:** Most permissions should be granted at project level, not folder level. Folders primarily provide organizational structure and org policy inheritance.

#### Folder: pcc-fldr-app (Applications)

| Google Workspace Group | IAM Role | Purpose |
|------------------------|----------|---------|
| gcp-app-developers-nonprod@pcconnect.ai | roles/viewer | Visibility across app projects |

#### Folder: pcc-fldr-data (Data)

| Google Workspace Group | IAM Role | Purpose |
|------------------------|----------|---------|
| gcp-data-engineers-prod@pcconnect.ai | roles/viewer | Visibility across data projects |
| gcp-data-engineers-nonprod@pcconnect.ai | roles/viewer | Visibility across data projects |

---

### Project Level IAM

#### Network Projects (Host Projects for Shared VPC)

**Project: pcc-prj-network-prod**

| Google Workspace Group | IAM Role | Purpose |
|------------------------|----------|---------|
| gcp-network-admins-prod@pcconnect.ai | roles/compute.networkAdmin | Full network management |
| gcp-network-admins-prod@pcconnect.ai | roles/compute.securityAdmin | Firewall rule management |
| gcp-network-viewers@pcconnect.ai | roles/compute.networkViewer | Read-only network visibility |
| gcp-security-admins@pcconnect.ai | roles/compute.securityAdmin | Security policy management |

**Project: pcc-prj-network-nonprod**

| Google Workspace Group | IAM Role | Purpose |
|------------------------|----------|---------|
| gcp-network-admins-nonprod@pcconnect.ai | roles/compute.networkAdmin | Full network management |
| gcp-network-admins-nonprod@pcconnect.ai | roles/compute.securityAdmin | Firewall rule management |
| gcp-network-viewers@pcconnect.ai | roles/compute.networkViewer | Read-only network visibility |
| gcp-app-developers-nonprod@pcconnect.ai | roles/compute.networkViewer | View available subnets |

**Shared VPC Subnet-Level Permissions:**
Grant `roles/compute.networkUser` at **subnet level** (not project level) to service project administrators:
- GKE administrators: Access to gke-subnet-{region}
- App administrators: Access to app-subnet-{region}
- Data administrators: Access to data-subnet-{region}

---

#### DevOps Projects

**Project: pcc-prj-devops-prod**

| Google Workspace Group | IAM Role | Purpose |
|------------------------|----------|---------|
| gcp-devops-admins-prod@pcconnect.ai | roles/editor | Full project management |
| gcp-gke-admins-prod@pcconnect.ai | roles/container.admin | GKE cluster administration |
| gcp-cicd-operators-prod@pcconnect.ai | roles/cloudbuild.builds.editor | Cloud Build pipeline management |
| gcp-cicd-operators-prod@pcconnect.ai | roles/artifactregistry.admin | Artifact Registry management |
| gcp-cicd-operators-prod@pcconnect.ai | roles/iam.serviceAccountUser | Service account impersonation for deployments |
| gcp-app-deployers-prod@pcconnect.ai | roles/container.developer | Deploy to GKE (no cluster admin) |
| gcp-security-auditors@pcconnect.ai | roles/viewer | Read-only audit access |

**Service Accounts:**
- pcc-sa-cloudbuild-prod@pcc-prj-devops-prod.iam.gserviceaccount.com
  - roles/cloudbuild.builds.builder
  - roles/storage.admin (for artifacts)
  - roles/iam.serviceAccountUser (to deploy as app service accounts)

**Project: pcc-prj-devops-nonprod**

| Google Workspace Group | IAM Role | Purpose |
|------------------------|----------|---------|
| gcp-devops-admins-nonprod@pcconnect.ai | roles/editor | Full project management |
| gcp-gke-admins-nonprod@pcconnect.ai | roles/container.admin | GKE cluster administration |
| gcp-cicd-operators-nonprod@pcconnect.ai | roles/cloudbuild.builds.editor | Cloud Build pipeline management |
| gcp-cicd-operators-nonprod@pcconnect.ai | roles/artifactregistry.admin | Artifact Registry management |
| gcp-app-developers-nonprod@pcconnect.ai | roles/container.developer | Deploy to GKE clusters |
| gcp-security-auditors@pcconnect.ai | roles/viewer | Read-only audit access |

---

#### Logging-Monitoring Project

**Project: pcc-prj-logging-monitoring**

| Google Workspace Group | IAM Role | Purpose |
|------------------------|----------|---------|
| gcp-logging-admins@pcconnect.ai | roles/logging.admin | Manage log sinks, exclusions |
| gcp-monitoring-admins@pcconnect.ai | roles/monitoring.admin | Manage monitoring configs, dashboards |
| gcp-logging-viewers@pcconnect.ai | roles/logging.viewer | Read logs for troubleshooting |
| gcp-logging-viewers@pcconnect.ai | roles/monitoring.viewer | View metrics and dashboards |
| gcp-security-auditors@pcconnect.ai | roles/logging.privateLogViewer | Access audit logs |

**Service Accounts:**
- pcc-sa-monitoring@pcc-prj-logging-monitoring.iam.gserviceaccount.com
  - roles/monitoring.metricWriter (write custom metrics)
  - roles/logging.logWriter (write custom logs)

---

#### Application Projects

**Project: pcc-prj-app-prod**

| Google Workspace Group | IAM Role | Purpose |
|------------------------|----------|---------|
| gcp-app-operators-prod@pcconnect.ai | roles/editor | Manage application resources |
| gcp-app-deployers-prod@pcconnect.ai | roles/iam.serviceAccountUser | Deploy applications |
| gcp-app-developers-prod@pcconnect.ai | roles/viewer | Read-only access (NO deployment in prod) |
| gcp-security-auditors@pcconnect.ai | roles/viewer | Security audit access |

**Project: pcc-prj-app-nonprod** (dev, staging, test)

| Google Workspace Group | IAM Role | Purpose |
|------------------------|----------|---------|
| gcp-app-developers-nonprod@pcconnect.ai | roles/editor | Full development access |
| gcp-app-developers-nonprod@pcconnect.ai | roles/iam.serviceAccountUser | Deploy and test applications |
| gcp-security-auditors@pcconnect.ai | roles/viewer | Security audit access |

---

#### Data Projects

**Project: pcc-prj-data-prod**

| Google Workspace Group | IAM Role | Purpose |
|------------------------|----------|---------|
| gcp-data-engineers-prod@pcconnect.ai | roles/bigquery.dataEditor | Manage BigQuery datasets |
| gcp-data-engineers-prod@pcconnect.ai | roles/storage.admin | Manage Cloud Storage buckets |
| gcp-database-admins-prod@pcconnect.ai | roles/cloudsql.admin | Manage Cloud SQL instances |
| gcp-data-analysts@pcconnect.ai | roles/bigquery.dataViewer | Read-only BigQuery access |
| gcp-data-analysts@pcconnect.ai | roles/storage.objectViewer | Read-only storage access |
| gcp-security-auditors@pcconnect.ai | roles/viewer | Security audit access |

**Project: pcc-prj-data-nonprod**

| Google Workspace Group | IAM Role | Purpose |
|------------------------|----------|---------|
| gcp-data-engineers-nonprod@pcconnect.ai | roles/bigquery.admin | Full BigQuery management |
| gcp-data-engineers-nonprod@pcconnect.ai | roles/storage.admin | Full storage management |
| gcp-database-admins-nonprod@pcconnect.ai | roles/cloudsql.admin | Manage Cloud SQL instances |
| gcp-app-developers-nonprod@pcconnect.ai | roles/bigquery.dataViewer | Query data for development |
| gcp-security-auditors@pcconnect.ai | roles/viewer | Security audit access |

---

#### Systems Projects

**Project: pcc-prj-systems-prod**

| Google Workspace Group | IAM Role | Purpose |
|------------------------|----------|---------|
| gcp-systems-admins@pcconnect.ai | roles/editor | Manage system resources |
| gcp-backup-operators@pcconnect.ai | roles/storage.admin | Manage backups |
| gcp-security-auditors@pcconnect.ai | roles/viewer | Security audit access |

**Project: pcc-prj-systems-nonprod**

| Google Workspace Group | IAM Role | Purpose |
|------------------------|----------|---------|
| gcp-systems-admins@pcconnect.ai | roles/editor | Manage system resources |
| gcp-security-auditors@pcconnect.ai | roles/viewer | Security audit access |

---

## 2. Google Workspace Groups

### Group Naming Convention
Format: `gcp-<function>-<environment>@pcconnect.ai`

### Complete Group List

#### Organization-Level Groups (31 total groups)

| Group Email | Purpose | Typical Member Count |
|-------------|---------|---------------------|
| gcp-org-admins@pcconnect.ai | Break-glass super admins (EMERGENCY ONLY) | 2-3 |
| gcp-security-admins@pcconnect.ai | Organization policy administrators | 3-5 |
| gcp-billing-admins@pcconnect.ai | Billing account management | 2-4 |
| gcp-security-auditors@pcconnect.ai | Security reviewers and auditors | 5-10 |
| gcp-org-viewers@pcconnect.ai | Organization-wide visibility | 10-20 |

#### Network Groups

| Group Email | Purpose | Typical Member Count |
|-------------|---------|---------------------|
| gcp-network-admins-prod@pcconnect.ai | Production network administration | 2-3 |
| gcp-network-admins-nonprod@pcconnect.ai | Non-production network administration | 3-5 |
| gcp-network-viewers@pcconnect.ai | Read-only network visibility (all environments) | 15-25 |
| gcp-sharedvpc-admins-prod@pcconnect.ai | Shared VPC administration (prod) | 2-3 |
| gcp-sharedvpc-admins-nonprod@pcconnect.ai | Shared VPC administration (nonprod) | 3-5 |

#### DevOps Groups

| Group Email | Purpose | Typical Member Count |
|-------------|---------|---------------------|
| gcp-devops-admins-prod@pcconnect.ai | Production DevOps platform management | 2-4 |
| gcp-devops-admins-nonprod@pcconnect.ai | Non-production DevOps platform management | 4-8 |
| gcp-gke-admins-prod@pcconnect.ai | Production GKE cluster administration | 2-4 |
| gcp-gke-admins-nonprod@pcconnect.ai | Non-production GKE cluster administration | 4-8 |
| gcp-cicd-operators-prod@pcconnect.ai | Production CI/CD pipeline operations | 3-6 |
| gcp-cicd-operators-nonprod@pcconnect.ai | Non-production CI/CD pipeline operations | 5-10 |

#### Logging & Monitoring Groups

| Group Email | Purpose | Typical Member Count |
|-------------|---------|---------------------|
| gcp-logging-admins@pcconnect.ai | Logging configuration management | 2-4 |
| gcp-logging-viewers@pcconnect.ai | Log access for troubleshooting | 20-40 |
| gcp-monitoring-admins@pcconnect.ai | Monitoring and alerting configuration | 3-6 |

#### Application Groups

| Group Email | Purpose | Typical Member Count |
|-------------|---------|---------------------|
| gcp-app-developers-nonprod@pcconnect.ai | Non-production application development | 20-50 |
| gcp-app-developers-prod@pcconnect.ai | Production read-only access for developers | 20-50 |
| gcp-app-deployers-prod@pcconnect.ai | Production deployment authorization | 5-10 |
| gcp-app-operators-prod@pcconnect.ai | Production application operations | 5-10 |

#### Data Groups

| Group Email | Purpose | Typical Member Count |
|-------------|---------|---------------------|
| gcp-data-engineers-prod@pcconnect.ai | Production data engineering | 5-10 |
| gcp-data-engineers-nonprod@pcconnect.ai | Non-production data engineering | 8-15 |
| gcp-data-analysts@pcconnect.ai | Read-only data analysis (all environments) | 10-30 |
| gcp-database-admins-prod@pcconnect.ai | Production database administration | 2-4 |
| gcp-database-admins-nonprod@pcconnect.ai | Non-production database administration | 3-6 |

#### Systems Groups

| Group Email | Purpose | Typical Member Count |
|-------------|---------|---------------------|
| gcp-systems-admins@pcconnect.ai | Systems infrastructure management | 3-6 |
| gcp-backup-operators@pcconnect.ai | Backup and recovery operations | 2-4 |

---

### Group Membership Guidelines

1. **Review Frequency:** Quarterly access reviews for all groups
2. **Onboarding:** New members should be added via standardized request process
3. **Offboarding:** Immediate removal upon role change or departure
4. **Documentation:** Maintain group membership rationale in central documentation
5. **Audit Trail:** Log all membership changes via Google Workspace audit logs

---

## 3. Organization Policies

### Network Security Policies

| Policy Constraint | Enforcement | Rationale | Exceptions |
|-------------------|-------------|-----------|------------|
| constraints/compute.restrictVpcPeering | Deny all except specified project IDs | Prevent unauthorized VPC peering | List approved partner VPC projects |
| constraints/compute.vmExternalIpAccess | Deny all except specific instances | Minimize attack surface, enforce Cloud NAT | Allow for NAT gateways, bastion hosts |
| constraints/compute.skipDefaultNetworkCreation | Enforce | Force use of Shared VPC architecture | None |
| constraints/compute.requireShieldedVm | Enforce | Enhanced security (Secure Boot, vTPM, Integrity Monitoring) | None |
| constraints/compute.restrictLoadBalancerCreationForTypes | Allow only INTERNAL, EXTERNAL_MANAGED | Control load balancer types for security | None |

**Implementation:**
```hcl
resource "google_organization_policy" "restrict_vpc_peering" {
  org_id     = "146990108557"
  constraint = "constraints/compute.restrictVpcPeering"

  list_policy {
    deny {
      all = true
    }
  }
}

resource "google_organization_policy" "skip_default_network" {
  org_id     = "146990108557"
  constraint = "constraints/compute.skipDefaultNetworkCreation"

  boolean_policy {
    enforced = true
  }
}
```

---

### Compute & Instance Policies

| Policy Constraint | Enforcement | Rationale | Exceptions |
|-------------------|-------------|-----------|------------|
| constraints/compute.disableSerialPortAccess | Enforce | Prevent serial port console access (security risk) | None |
| constraints/compute.requireOsLogin | Enforce | Integrate SSH with Workspace identity, disable SSH keys | None |
| constraints/compute.restrictProtocolForwardingCreationForTypes | Deny INTERNAL, EXTERNAL | Limit protocol forwarding capabilities | Specific networking projects |
| constraints/compute.vmCanIpForward | Deny all except NAT instances | Control IP forwarding | NAT gateway instances only |
| constraints/compute.setNewProjectDefaultToZonalDNSOnly | Enforce | Use zonal DNS for better performance | None |

---

### Service Account Security Policies

| Policy Constraint | Enforcement | Rationale | Exceptions |
|-------------------|-------------|-----------|------------|
| **constraints/iam.disableServiceAccountKeyCreation** | **ENFORCE (CRITICAL)** | **Prevent service account key downloads, enforce Workload Identity** | **pcc-prj-bootstrap only (for Terraform SA)** |
| constraints/iam.disableServiceAccountCreation | Enforce except for project owners | Require approval for new service accounts | None |
| constraints/iam.allowedPolicyMemberDomains | Allow only: C01n9vwkg (pcconnect.ai Workspace) | Prevent external identity access | None |

**CRITICAL SECURITY NOTE:** Service account key creation should be DISABLED across the entire organization except in the bootstrap project. This forces the use of:
- Workload Identity for GKE workloads
- Service account impersonation for Terraform
- Short-lived tokens via gcloud for temporary access

---

### Resource Location Policies

| Policy Constraint | Enforcement | Rationale | Exceptions |
|-------------------|-------------|-----------|------------|
| constraints/gcp.resourceLocations | Allow only: us-east4, us-central1 | Data residency, compliance, latency optimization | None |

**Implementation:**
```hcl
resource "google_organization_policy" "resource_locations" {
  org_id     = "146990108557"
  constraint = "constraints/gcp.resourceLocations"

  list_policy {
    allow {
      values = [
        "in:us-locations",
        "us-east4",
        "us-central1"
      ]
    }
  }
}
```

---

### Storage & Data Security Policies

| Policy Constraint | Enforcement | Rationale | Exceptions |
|-------------------|-------------|-----------|------------|
| constraints/storage.uniformBucketLevelAccess | Enforce | Consistent IAM-based access control | None |
| constraints/storage.publicAccessPrevention | Enforce | Prevent public bucket access (data leakage risk) | Public website assets bucket (if needed) |
| constraints/sql.restrictPublicIp | Enforce | Prevent Cloud SQL public IP addresses | None |
| constraints/sql.restrictAuthorizedNetworks | Enforce | Control Cloud SQL network access via VPC | None |

---

### General Security & Compliance Policies

| Policy Constraint | Enforcement | Rationale | Exceptions |
|-------------------|-------------|-----------|------------|
| constraints/essentialcontacts.allowedContactDomains | Allow only: pcconnect.ai | Ensure notifications go to company email | None |
| constraints/compute.trustedImageProjects | Allow only: approved project IDs | Prevent use of untrusted VM images | List approved image projects |
| constraints/iam.workloadIdentityPoolProviders | Deny all except approved OIDC providers | Control external identity federation | CI/CD GitHub Actions provider |

---

### Policy Enforcement Summary

**Total Policies:** 20 organization-wide policies
**Critical Policies (Security):** 8
**Network Policies:** 5
**IAM/Identity Policies:** 3
**Data/Storage Policies:** 4

**Recommended Review Frequency:** Quarterly review of all policies for effectiveness and exceptions

---

## 4. Service Account Strategy

### Core Principles

1. **NO Service Account Keys:** Enforce `constraints/iam.disableServiceAccountKeyCreation`
2. **Workload Identity:** Use Workload Identity for all GKE workloads
3. **Service Account Impersonation:** Use for Terraform and CI/CD
4. **Least Privilege:** Grant minimal permissions per service account
5. **One Service Account Per Workload:** Avoid shared service accounts
6. **Short-Lived Tokens:** Use `gcloud auth print-access-token` with max TTL

---

### Service Account Naming Convention

Format: `pcc-sa-{purpose}-{environment}@{project-id}.iam.gserviceaccount.com`

Examples:
- `pcc-sa-terraform@pcc-prj-bootstrap.iam.gserviceaccount.com`
- `pcc-sa-gke-prod-us-east4@pcc-prj-devops-prod.iam.gserviceaccount.com`
- `pcc-sa-app-frontend-prod@pcc-prj-app-prod.iam.gserviceaccount.com`

---

### Terraform Service Accounts

**Existing Service Account:**
- **Email:** pcc-sa-terraform@pcc-prj-bootstrap.iam.gserviceaccount.com
- **Purpose:** Infrastructure provisioning via service account impersonation
- **Access Method:** `gcloud auth application-default login --impersonate-service-account=pcc-sa-terraform@pcc-prj-bootstrap.iam.gserviceaccount.com`
- **Required Roles:**
  - Organization level: roles/resourcemanager.organizationAdmin (only if creating folders/projects)
  - Folder level: roles/resourcemanager.folderAdmin (for folder/project creation)
  - Project level: roles/owner (on projects it manages)
  - roles/iam.serviceAccountTokenCreator (for impersonation)

**Security Configuration:**
```hcl
# Allow specific users to impersonate Terraform service account
resource "google_service_account_iam_member" "terraform_impersonation" {
  service_account_id = "projects/pcc-prj-bootstrap/serviceAccounts/pcc-sa-terraform@pcc-prj-bootstrap.iam.gserviceaccount.com"
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "group:gcp-devops-admins-prod@pcconnect.ai"
}

# Audit all impersonation events
resource "google_logging_project_sink" "terraform_audit" {
  name        = "terraform-sa-audit-sink"
  destination = "logging.googleapis.com/projects/pcc-prj-logging-monitoring/locations/global/buckets/audit-logs"

  filter = <<-EOT
    protoPayload.serviceData.policyDelta.bindingDeltas.action="ADD"
    protoPayload.authenticationInfo.serviceAccountDelegationInfo!=""
    protoPayload.authenticationInfo.principalEmail="pcc-sa-terraform@pcc-prj-bootstrap.iam.gserviceaccount.com"
  EOT
}
```

---

### GKE Service Accounts (Node Pools)

**Purpose:** GKE node pool identity (NOT for application workloads - use Workload Identity instead)

**Naming:**
- `pcc-sa-gke-prod-us-east4@pcc-prj-devops-prod.iam.gserviceaccount.com`
- `pcc-sa-gke-nonprod-us-central1@pcc-prj-devops-nonprod.iam.gserviceaccount.com`

**Required Roles (Minimal):**
- roles/logging.logWriter (write container logs)
- roles/monitoring.metricWriter (write metrics)
- roles/artifactregistry.reader (pull container images)

**Configuration:**
```hcl
resource "google_service_account" "gke_node_pool" {
  account_id   = "pcc-sa-gke-prod-us-east4"
  display_name = "GKE Node Pool Service Account (prod, us-east4)"
  project      = "pcc-prj-devops-prod"
}

resource "google_project_iam_member" "gke_logging" {
  project = "pcc-prj-devops-prod"
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.gke_node_pool.email}"
}

resource "google_project_iam_member" "gke_monitoring" {
  project = "pcc-prj-devops-prod"
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.gke_node_pool.email}"
}

resource "google_project_iam_member" "gke_artifact_registry" {
  project = "pcc-prj-devops-prod"
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.gke_node_pool.email}"
}
```

---

### Workload Identity Service Accounts (GKE Applications)

**Purpose:** Application workload identity for GKE pods

**Naming:**
- `pcc-sa-app-{appname}-{environment}@pcc-prj-app-{environment}.iam.gserviceaccount.com`

**Example: Frontend Application**
- `pcc-sa-app-frontend-prod@pcc-prj-app-prod.iam.gserviceaccount.com`
- Kubernetes namespace: `frontend`
- Kubernetes service account: `frontend-sa`

**Configuration:**
```hcl
resource "google_service_account" "app_frontend" {
  account_id   = "pcc-sa-app-frontend-prod"
  display_name = "Frontend Application Service Account (prod)"
  project      = "pcc-prj-app-prod"
}

# Allow Kubernetes service account to impersonate GCP service account
resource "google_service_account_iam_member" "workload_identity_binding" {
  service_account_id = google_service_account.app_frontend.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:pcc-prj-devops-prod.svc.id.goog[frontend/frontend-sa]"
}

# Grant app-specific permissions
resource "google_project_iam_member" "app_storage_access" {
  project = "pcc-prj-data-prod"
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.app_frontend.email}"
}
```

**Kubernetes Configuration:**
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: frontend-sa
  namespace: frontend
  annotations:
    iam.gke.io/gcp-service-account: pcc-sa-app-frontend-prod@pcc-prj-app-prod.iam.gserviceaccount.com

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: frontend
spec:
  template:
    spec:
      serviceAccountName: frontend-sa
      containers:
      - name: frontend
        image: us-east4-docker.pkg.dev/pcc-prj-devops-prod/apps/frontend:v1.0.0
```

---

### CI/CD Pipeline Service Accounts

**Purpose:** Cloud Build and CI/CD pipeline execution

**Naming:**
- `pcc-sa-cloudbuild-prod@pcc-prj-devops-prod.iam.gserviceaccount.com`
- `pcc-sa-cloudbuild-nonprod@pcc-prj-devops-nonprod.iam.gserviceaccount.com`

**Required Roles:**
- roles/cloudbuild.builds.builder (execute builds)
- roles/storage.admin (artifact storage)
- roles/artifactregistry.writer (push container images)
- roles/iam.serviceAccountUser (impersonate deployment service accounts)
- roles/container.developer (deploy to GKE)

**Configuration:**
```hcl
resource "google_service_account" "cloudbuild" {
  account_id   = "pcc-sa-cloudbuild-prod"
  display_name = "Cloud Build Service Account (prod)"
  project      = "pcc-prj-devops-prod"
}

resource "google_project_iam_member" "cloudbuild_builder" {
  project = "pcc-prj-devops-prod"
  role    = "roles/cloudbuild.builds.builder"
  member  = "serviceAccount:${google_service_account.cloudbuild.email}"
}

# Allow Cloud Build to deploy as application service accounts
resource "google_service_account_iam_member" "cloudbuild_app_impersonation" {
  service_account_id = "projects/pcc-prj-app-prod/serviceAccounts/pcc-sa-app-frontend-prod@pcc-prj-app-prod.iam.gserviceaccount.com"
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.cloudbuild.email}"
}
```

---

### Application-Specific Service Accounts

#### Database Access Service Accounts

**Purpose:** Application-specific database access (Cloud SQL, Spanner)

**Naming:**
- `pcc-sa-db-{appname}-{environment}@pcc-prj-data-{environment}.iam.gserviceaccount.com`

**Example:**
```hcl
resource "google_service_account" "app_database" {
  account_id   = "pcc-sa-db-frontend-prod"
  display_name = "Frontend Database Service Account (prod)"
  project      = "pcc-prj-data-prod"
}

resource "google_project_iam_member" "cloudsql_client" {
  project = "pcc-prj-data-prod"
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.app_database.email}"
}
```

#### Storage Access Service Accounts

**Purpose:** Application-specific Cloud Storage access

**Naming:**
- `pcc-sa-storage-{appname}-{environment}@pcc-prj-data-{environment}.iam.gserviceaccount.com`

**Example:**
```hcl
resource "google_service_account" "app_storage" {
  account_id   = "pcc-sa-storage-uploads-prod"
  display_name = "User Uploads Storage Service Account (prod)"
  project      = "pcc-prj-data-prod"
}

# Grant access to specific bucket only
resource "google_storage_bucket_iam_member" "uploads_access" {
  bucket = "pcc-user-uploads-prod"
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.app_storage.email}"
}
```

---

### Monitoring & Logging Service Accounts

**Purpose:** Centralized monitoring and logging agents

**Naming:**
- `pcc-sa-monitoring@pcc-prj-logging-monitoring.iam.gserviceaccount.com`
- `pcc-sa-log-export@pcc-prj-logging-monitoring.iam.gserviceaccount.com`

**Configuration:**
```hcl
resource "google_service_account" "monitoring" {
  account_id   = "pcc-sa-monitoring"
  display_name = "Centralized Monitoring Service Account"
  project      = "pcc-prj-logging-monitoring"
}

resource "google_project_iam_member" "monitoring_writer" {
  project = "pcc-prj-logging-monitoring"
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.monitoring.email}"
}

resource "google_service_account" "log_export" {
  account_id   = "pcc-sa-log-export"
  display_name = "Log Export Service Account"
  project      = "pcc-prj-logging-monitoring"
}

resource "google_project_iam_member" "log_sink_writer" {
  project = "pcc-prj-logging-monitoring"
  role    = "roles/logging.bucketWriter"
  member  = "serviceAccount:${google_service_account.log_export.email}"
}
```

---

### Service Account Security Best Practices

1. **Regular Audit:** Quarterly review of all service accounts and their permissions
2. **Unused Service Accounts:** Disable or delete service accounts unused for 90+ days
3. **Key Rotation:** If keys must exist (avoid!), rotate every 90 days
4. **Alerting:** Alert on service account key creation events
5. **Documentation:** Document purpose and owner for every service account

**Security Monitoring:**
```hcl
resource "google_logging_metric" "service_account_key_creation" {
  name   = "service_account_key_creation_alert"
  filter = <<-EOT
    protoPayload.methodName="google.iam.admin.v1.CreateServiceAccountKey"
    protoPayload.request.keyAlgorithm!="KEY_ALG_UNSPECIFIED"
  EOT

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
  }
}

resource "google_monitoring_alert_policy" "key_creation_alert" {
  display_name = "CRITICAL: Service Account Key Created"
  combiner     = "OR"
  conditions {
    display_name = "Service account key creation detected"
    condition_threshold {
      filter          = "resource.type = \"iam_service_account\" AND metric.type = \"logging.googleapis.com/user/service_account_key_creation_alert\""
      duration        = "0s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0
    }
  }

  notification_channels = [google_monitoring_notification_channel.security_team.name]

  alert_strategy {
    auto_close = "604800s" # 7 days
  }
}
```

---

## 5. Shared VPC Security Architecture

### Overview

**Host Projects:**
- pcc-prj-network-prod (production Shared VPC)
- pcc-prj-network-nonprod (non-production Shared VPC)

**Service Projects (to be attached):**
- pcc-prj-devops-{environment}
- pcc-prj-app-{environment}
- pcc-prj-data-{environment}
- pcc-prj-systems-{environment}

---

### Shared VPC IAM Configuration

#### Step 1: Enable Shared VPC on Host Projects

```hcl
resource "google_compute_shared_vpc_host_project" "network_prod" {
  project = "pcc-prj-network-prod"
}

resource "google_compute_shared_vpc_host_project" "network_nonprod" {
  project = "pcc-prj-network-nonprod"
}
```

#### Step 2: Grant Shared VPC Admin Permissions

```hcl
# Organization-level XPN admin (required to attach service projects)
resource "google_organization_iam_member" "xpn_admin_prod" {
  org_id = "146990108557"
  role   = "roles/compute.xpnAdmin"
  member = "group:gcp-sharedvpc-admins-prod@pcconnect.ai"
}

# Host project network admin
resource "google_project_iam_member" "network_admin_prod" {
  project = "pcc-prj-network-prod"
  role    = "roles/compute.networkAdmin"
  member  = "group:gcp-network-admins-prod@pcconnect.ai"
}

resource "google_project_iam_member" "security_admin_prod" {
  project = "pcc-prj-network-prod"
  role    = "roles/compute.securityAdmin"
  member  = "group:gcp-network-admins-prod@pcconnect.ai"
}
```

#### Step 3: Attach Service Projects

```hcl
resource "google_compute_shared_vpc_service_project" "devops_prod" {
  host_project    = "pcc-prj-network-prod"
  service_project = "pcc-prj-devops-prod"
}

resource "google_compute_shared_vpc_service_project" "app_prod" {
  host_project    = "pcc-prj-network-prod"
  service_project = "pcc-prj-app-prod"
}

resource "google_compute_shared_vpc_service_project" "data_prod" {
  host_project    = "pcc-prj-network-prod"
  service_project = "pcc-prj-data-prod"
}
```

#### Step 4: Grant Subnet-Level Network User Permissions

**CRITICAL:** Grant `roles/compute.networkUser` at **subnet level**, not project level.

```hcl
# GKE administrators need access to GKE subnets
resource "google_compute_subnetwork_iam_member" "gke_subnet_access_prod" {
  project    = "pcc-prj-network-prod"
  region     = "us-east4"
  subnetwork = "gke-subnet-us-east4"
  role       = "roles/compute.networkUser"
  member     = "group:gcp-gke-admins-prod@pcconnect.ai"
}

# GKE service accounts need subnet access
resource "google_compute_subnetwork_iam_member" "gke_sa_subnet_access" {
  project    = "pcc-prj-network-prod"
  region     = "us-east4"
  subnetwork = "gke-subnet-us-east4"
  role       = "roles/compute.networkUser"
  member     = "serviceAccount:pcc-sa-gke-prod-us-east4@pcc-prj-devops-prod.iam.gserviceaccount.com"
}

# Cloud Build needs subnet access for private pools
resource "google_compute_subnetwork_iam_member" "cloudbuild_subnet_access" {
  project    = "pcc-prj-network-prod"
  region     = "us-east4"
  subnetwork = "build-subnet-us-east4"
  role       = "roles/compute.networkUser"
  member     = "serviceAccount:pcc-sa-cloudbuild-prod@pcc-prj-devops-prod.iam.gserviceaccount.com"
}
```

---

### Network Architecture

#### Subnet Design

**Production Network (pcc-prj-network-prod):**

| Subnet Name | CIDR | Purpose | Private Google Access | Flow Logs |
|-------------|------|---------|----------------------|-----------|
| gke-subnet-us-east4 | 10.0.0.0/20 | GKE nodes | Enabled | Enabled |
| gke-pods-us-east4 | 10.4.0.0/14 | GKE pods (secondary range) | N/A | Enabled |
| gke-services-us-east4 | 10.8.0.0/20 | GKE services (secondary range) | N/A | Enabled |
| app-subnet-us-east4 | 10.1.0.0/20 | Application VMs | Enabled | Enabled |
| data-subnet-us-east4 | 10.2.0.0/20 | Database proxies, data services | Enabled | Enabled |
| systems-subnet-us-east4 | 10.3.0.0/20 | System services, monitoring | Enabled | Enabled |
| build-subnet-us-east4 | 10.9.0.0/24 | Cloud Build private pools | Enabled | Enabled |

**Configuration:**
```hcl
resource "google_compute_subnetwork" "gke_subnet_prod" {
  name          = "gke-subnet-us-east4"
  ip_cidr_range = "10.0.0.0/20"
  region        = "us-east4"
  network       = google_compute_network.vpc_prod.id
  project       = "pcc-prj-network-prod"

  secondary_ip_range {
    range_name    = "gke-pods-us-east4"
    ip_cidr_range = "10.4.0.0/14"
  }

  secondary_ip_range {
    range_name    = "gke-services-us-east4"
    ip_cidr_range = "10.8.0.0/20"
  }

  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}
```

---

### Firewall Rules (Defense in Depth)

#### Principle: Deny by Default

**Base Rule:**
```hcl
resource "google_compute_firewall" "deny_all_ingress" {
  name     = "deny-all-ingress"
  network  = google_compute_network.vpc_prod.id
  project  = "pcc-prj-network-prod"
  priority = 65534

  deny {
    protocol = "all"
  }

  direction = "INGRESS"

  source_ranges = ["0.0.0.0/0"]
}
```

#### Allow Rules (Specific and Minimal)

**1. Internal GKE Communication**
```hcl
resource "google_compute_firewall" "allow_gke_internal" {
  name    = "allow-gke-internal-prod"
  network = google_compute_network.vpc_prod.id
  project = "pcc-prj-network-prod"

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = [
    "10.0.0.0/20",   # GKE nodes
    "10.4.0.0/14",   # GKE pods
    "10.8.0.0/20"    # GKE services
  ]

  direction = "INGRESS"
}
```

**2. Load Balancer Health Checks**
```hcl
resource "google_compute_firewall" "allow_health_checks" {
  name    = "allow-health-checks-prod"
  network = google_compute_network.vpc_prod.id
  project = "pcc-prj-network-prod"

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "8080"]
  }

  source_ranges = [
    "35.191.0.0/16",   # Google Cloud load balancer health checks
    "130.211.0.0/22"   # Legacy health checks
  ]

  direction = "INGRESS"
}
```

**3. Application to Database (Service Account-Based)**
```hcl
resource "google_compute_firewall" "allow_app_to_db" {
  name    = "allow-app-to-db-prod"
  network = google_compute_network.vpc_prod.id
  project = "pcc-prj-network-prod"

  allow {
    protocol = "tcp"
    ports    = ["5432", "3306"]
  }

  source_service_accounts = [
    "pcc-sa-app-frontend-prod@pcc-prj-app-prod.iam.gserviceaccount.com",
    "pcc-sa-app-backend-prod@pcc-prj-app-prod.iam.gserviceaccount.com"
  ]

  target_service_accounts = [
    "pcc-sa-cloudsql-proxy-prod@pcc-prj-data-prod.iam.gserviceaccount.com"
  ]

  direction = "INGRESS"
}
```

---

### Private Google Access & Cloud NAT

**Enable Private Google Access on All Subnets:**
```hcl
# Already configured in subnet definition above
private_ip_google_access = true
```

**Cloud NAT Configuration (Outbound Internet Access):**
```hcl
resource "google_compute_router" "nat_router_prod" {
  name    = "nat-router-prod-us-east4"
  region  = "us-east4"
  network = google_compute_network.vpc_prod.id
  project = "pcc-prj-network-prod"
}

resource "google_compute_router_nat" "nat_prod" {
  name                               = "nat-prod-us-east4"
  router                             = google_compute_router.nat_router_prod.name
  region                             = "us-east4"
  project                            = "pcc-prj-network-prod"
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
```

---

### VPC Service Controls (Future Enhancement)

**Purpose:** Protect sensitive data in data projects from exfiltration

**Recommended Perimeter:**
- pcc-prj-data-prod
- pcc-prj-logging-monitoring (for log storage)

**Configuration Example:**
```hcl
resource "google_access_context_manager_service_perimeter" "data_perimeter" {
  parent = "accessPolicies/${var.access_policy_id}"
  name   = "accessPolicies/${var.access_policy_id}/servicePerimeters/data_prod"
  title  = "PCC Data Production Perimeter"

  status {
    resources = [
      "projects/pcc-prj-data-prod",
      "projects/pcc-prj-logging-monitoring"
    ]

    restricted_services = [
      "bigquery.googleapis.com",
      "storage.googleapis.com",
      "sqladmin.googleapis.com"
    ]

    vpc_accessible_services {
      enable_restriction = true
      allowed_services = [
        "bigquery.googleapis.com",
        "storage.googleapis.com"
      ]
    }
  }
}
```

---

## 6. Implementation Checklist

### Phase 1: Organization Setup (Week 1)

- [ ] **Create Google Workspace Groups** (all 31 groups listed in Section 2)
  - [ ] Organization-level groups (5)
  - [ ] Network groups (5)
  - [ ] DevOps groups (6)
  - [ ] Logging/Monitoring groups (3)
  - [ ] Application groups (4)
  - [ ] Data groups (5)
  - [ ] Systems groups (2)

- [ ] **Assign Initial Group Members**
  - [ ] gcp-org-admins: 2-3 break-glass admins
  - [ ] gcp-security-admins: Security team
  - [ ] gcp-billing-admins: Finance team
  - [ ] gcp-devops-admins-prod: Senior DevOps engineers

- [ ] **Configure Organization-Level IAM**
  - [ ] Bind gcp-org-admins to roles/resourcemanager.organizationAdmin
  - [ ] Bind gcp-security-admins to roles/orgpolicy.policyAdmin
  - [ ] Bind gcp-billing-admins to roles/billing.admin
  - [ ] Bind gcp-security-auditors to roles/iam.securityReviewer
  - [ ] Bind gcp-sharedvpc-admins to roles/compute.xpnAdmin

- [ ] **Implement Critical Organization Policies**
  - [ ] constraints/iam.disableServiceAccountKeyCreation (CRITICAL)
  - [ ] constraints/iam.allowedPolicyMemberDomains (pcconnect.ai only)
  - [ ] constraints/compute.skipDefaultNetworkCreation
  - [ ] constraints/compute.requireOsLogin
  - [ ] constraints/gcp.resourceLocations (us-east4, us-central1)

---

### Phase 2: Network Foundation (Week 2)

- [ ] **Create Network Projects**
  - [ ] pcc-prj-network-prod
  - [ ] pcc-prj-network-nonprod

- [ ] **Enable Shared VPC**
  - [ ] Enable Shared VPC on pcc-prj-network-prod
  - [ ] Enable Shared VPC on pcc-prj-network-nonprod

- [ ] **Configure Network Project IAM**
  - [ ] Bind gcp-network-admins-prod to roles/compute.networkAdmin
  - [ ] Bind gcp-network-admins-prod to roles/compute.securityAdmin
  - [ ] Bind gcp-network-viewers to roles/compute.networkViewer

- [ ] **Create VPC Networks**
  - [ ] Create vpc-prod with subnets (GKE, app, data, systems, build)
  - [ ] Create vpc-nonprod with subnets

- [ ] **Configure Private Google Access**
  - [ ] Enable on all subnets in vpc-prod
  - [ ] Enable on all subnets in vpc-nonprod

- [ ] **Deploy Cloud NAT**
  - [ ] Cloud NAT for us-east4 (prod)
  - [ ] Cloud NAT for us-central1 (prod)
  - [ ] Cloud NAT for nonprod regions

- [ ] **Implement Firewall Rules**
  - [ ] Deny-all baseline rule (priority 65534)
  - [ ] Allow internal GKE communication
  - [ ] Allow health checks
  - [ ] Allow app-to-db (service account-based)

---

### Phase 3: DevOps Projects (Week 3)

- [ ] **Create DevOps Projects**
  - [ ] pcc-prj-devops-prod
  - [ ] pcc-prj-devops-nonprod

- [ ] **Attach to Shared VPC**
  - [ ] Attach pcc-prj-devops-prod to vpc-prod
  - [ ] Attach pcc-prj-devops-nonprod to vpc-nonprod

- [ ] **Configure DevOps Project IAM**
  - [ ] Bind gcp-devops-admins-prod to roles/editor
  - [ ] Bind gcp-gke-admins-prod to roles/container.admin
  - [ ] Bind gcp-cicd-operators-prod to roles/cloudbuild.builds.editor

- [ ] **Create Service Accounts**
  - [ ] pcc-sa-gke-prod-us-east4 (GKE node pools)
  - [ ] pcc-sa-cloudbuild-prod (CI/CD pipelines)
  - [ ] Assign minimal IAM roles to service accounts

- [ ] **Grant Subnet Access**
  - [ ] GKE SA: roles/compute.networkUser on gke-subnet-us-east4
  - [ ] Cloud Build SA: roles/compute.networkUser on build-subnet-us-east4

- [ ] **Enable Required APIs**
  - [ ] container.googleapis.com (GKE)
  - [ ] cloudbuild.googleapis.com (Cloud Build)
  - [ ] artifactregistry.googleapis.com (Artifact Registry)

---

### Phase 4: Logging & Monitoring (Week 3)

- [ ] **Create Logging-Monitoring Project**
  - [ ] pcc-prj-logging-monitoring

- [ ] **Configure Logging Project IAM**
  - [ ] Bind gcp-logging-admins to roles/logging.admin
  - [ ] Bind gcp-monitoring-admins to roles/monitoring.admin
  - [ ] Bind gcp-logging-viewers to roles/logging.viewer

- [ ] **Create Service Accounts**
  - [ ] pcc-sa-monitoring (metrics collection)
  - [ ] pcc-sa-log-export (log sink destination)

- [ ] **Configure Organization-Level Log Sinks**
  - [ ] Admin Activity logs to BigQuery
  - [ ] Data Access logs to Cloud Storage
  - [ ] All logs to centralized logging bucket

- [ ] **Implement Security Monitoring**
  - [ ] Alert on service account key creation
  - [ ] Alert on organization policy changes
  - [ ] Alert on IAM binding changes at org level
  - [ ] Alert on Terraform service account impersonation

---

### Phase 5: Application & Data Projects (Week 4)

- [ ] **Create Application Projects**
  - [ ] pcc-prj-app-prod
  - [ ] pcc-prj-app-nonprod

- [ ] **Create Data Projects**
  - [ ] pcc-prj-data-prod
  - [ ] pcc-prj-data-nonprod

- [ ] **Create Systems Projects**
  - [ ] pcc-prj-systems-prod
  - [ ] pcc-prj-systems-nonprod

- [ ] **Attach to Shared VPC**
  - [ ] Attach all service projects to appropriate host projects

- [ ] **Configure Project IAM**
  - [ ] Application projects: Bind developer/deployer groups
  - [ ] Data projects: Bind data engineer/analyst groups
  - [ ] Systems projects: Bind systems admin groups

- [ ] **Grant Subnet Access**
  - [ ] App projects: roles/compute.networkUser on app-subnet
  - [ ] Data projects: roles/compute.networkUser on data-subnet
  - [ ] Systems projects: roles/compute.networkUser on systems-subnet

---

### Phase 6: Additional Security Policies (Week 4)

- [ ] **Implement Network Policies**
  - [ ] constraints/compute.vmExternalIpAccess
  - [ ] constraints/compute.restrictVpcPeering
  - [ ] constraints/compute.requireShieldedVm
  - [ ] constraints/compute.disableSerialPortAccess

- [ ] **Implement Storage Policies**
  - [ ] constraints/storage.uniformBucketLevelAccess
  - [ ] constraints/storage.publicAccessPrevention
  - [ ] constraints/sql.restrictPublicIp

- [ ] **Implement Compute Policies**
  - [ ] constraints/compute.vmCanIpForward
  - [ ] constraints/compute.trustedImageProjects
  - [ ] constraints/compute.setNewProjectDefaultToZonalDNSOnly

---

### Phase 7: Validation & Documentation (Week 5)

- [ ] **Security Validation**
  - [ ] Verify no service account keys exist (except bootstrap)
  - [ ] Verify all projects use Shared VPC
  - [ ] Verify firewall rules are restrictive
  - [ ] Verify Private Google Access enabled
  - [ ] Verify Cloud NAT operational

- [ ] **IAM Validation**
  - [ ] Review all org-level bindings
  - [ ] Review all project-level bindings
  - [ ] Verify least privilege implementation
  - [ ] Verify no individual user bindings (groups only)

- [ ] **Compliance Validation**
  - [ ] Verify all organization policies enforced
  - [ ] Verify resource locations constrained to us-east4, us-central1
  - [ ] Verify OS Login enforced
  - [ ] Verify logging/monitoring operational

- [ ] **Documentation**
  - [ ] Document all service accounts and their purpose
  - [ ] Document network architecture and subnet allocation
  - [ ] Document IAM group membership and responsibilities
  - [ ] Document organization policies and exceptions
  - [ ] Create runbooks for common operations

---

### Phase 8: Ongoing Operations

- [ ] **Quarterly Reviews**
  - [ ] Review Google Workspace group memberships
  - [ ] Review service account usage and permissions
  - [ ] Review organization policy effectiveness
  - [ ] Review security alerts and incidents
  - [ ] Review firewall rules for obsolete entries

- [ ] **Monthly Security Scans**
  - [ ] Scan for unused service accounts
  - [ ] Scan for service account keys
  - [ ] Review Cloud Asset Inventory for misconfigurations
  - [ ] Review Security Command Center findings

- [ ] **Continuous Monitoring**
  - [ ] Monitor alerts for policy violations
  - [ ] Monitor alerts for IAM changes
  - [ ] Monitor alerts for network anomalies
  - [ ] Review audit logs weekly

---

## Security Audit Summary

### Critical Security Controls Implemented

1. **Identity & Access Management**
   - 31 Google Workspace groups for role-based access
   - No individual user permissions at organization level
   - Separation of duties (billing, security, operations)
   - Service account impersonation for Terraform (no keys)

2. **Network Security**
   - Shared VPC architecture with centralized network management
   - Defense-in-depth firewall rules (deny-all baseline)
   - Service account-based firewall rules (not IP-based)
   - Private Google Access enabled on all subnets
   - Cloud NAT for outbound internet (no public IPs)

3. **Service Account Security**
   - Service account key creation DISABLED organization-wide
   - Workload Identity for all GKE workloads
   - One service account per application per environment
   - Least privilege permissions per service account

4. **Organization Policies**
   - 20 organization policies for defense-in-depth
   - Resource location restrictions (us-east4, us-central1)
   - OS Login enforced (Workspace identity integration)
   - Shielded VMs required for compute instances

5. **Audit & Compliance**
   - Centralized logging to dedicated project
   - Organization-level log sinks for audit trails
   - Security monitoring and alerting
   - Quarterly access reviews

### Compliance Alignment

| Framework | Coverage | Notes |
|-----------|----------|-------|
| OWASP Top 10 | High | IAM, logging, secure configuration |
| NIST CSF | High | Identify, Protect, Detect, Respond, Recover |
| ISO 27001 | Medium | Access control, logging, asset management |
| PCI DSS | Medium | Network segmentation, access control, logging |

### Risk Assessment

| Risk Category | Severity (Before) | Severity (After) | Mitigation |
|---------------|-------------------|------------------|------------|
| Unauthorized Access | Critical | Low | Group-based IAM, least privilege |
| Data Exfiltration | Critical | Medium | VPC Service Controls (future), network segmentation |
| Service Account Key Leakage | Critical | Minimal | Key creation disabled, Workload Identity enforced |
| Lateral Movement | High | Low | Service account-based firewall rules, segmentation |
| Privilege Escalation | High | Low | Separation of duties, audit logging |

### Recommendations for Continued Improvement

1. **Implement VPC Service Controls** around data projects (Phase 6+)
2. **Deploy Cloud Armor** for DDoS protection and WAF capabilities
3. **Implement Just-In-Time Access** for elevated permissions (reduce standing access)
4. **Deploy Security Command Center Premium** for advanced threat detection
5. **Implement Binary Authorization** for GKE container image validation
6. **Regular Penetration Testing** (annual external, quarterly internal)
7. **Implement Cloud Data Loss Prevention (DLP)** for sensitive data scanning

---

## Document Control

**Prepared by:** Security & IAM Architecture Team
**Reviewed by:** [Pending]
**Approved by:** [Pending]
**Next Review Date:** 2025-12-31

**Change History:**

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-10-01 | Security Auditor | Initial blueprint creation |

---

**END OF DOCUMENT**
