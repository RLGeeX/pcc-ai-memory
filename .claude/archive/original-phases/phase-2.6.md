# Phase 2.6: Plan IAM Bindings

**Phase**: 2.6 (AlloyDB Infrastructure - Access Control)
**Duration**: 20-25 minutes
**Type**: Planning + Configuration
**Status**: 📋 Planning (Not Started)
**Date**: TBD (10/20+)

---

## Objective

Design IAM bindings for AlloyDB cluster access, Secret Manager access, and developer tools (Auth Proxy), ensuring least-privilege access for microservices, developers, and CI/CD.

## Prerequisites

✅ Phase 2.5 completed (Secret Manager design)
✅ Understanding of IAM roles and bindings
✅ GKE service account names (Workload Identity pattern)
✅ Developer and CI/CD access requirements

---

## IAM Design Overview

### Access Control Scope

**Resources**:
- AlloyDB cluster and instances (Phase 2.1-2.3)
- Secret Manager secrets (Phase 2.5)
- Developer tools (Auth Proxy)

**Principals**:
- GKE service accounts (1 microservice: pcc-client-api) - Workload Identity
- Developer group (`gcp-developers@pcconnect.ai`)
- CI/CD service account (Cloud Build)

**Principle**: Least privilege (grant minimum required permissions)

---

## IAM Bindings for AlloyDB

### 1. Developer Group - Auth Proxy Access

**Principal**: `group:gcp-developers@pcconnect.ai`
**Role**: `roles/alloydb.client`
**Project**: `pcc-prj-app-devtest`

**Purpose**: Allow developers to connect via AlloyDB Auth Proxy for local testing

**Terraform**:
```hcl
resource "google_project_iam_member" "alloydb_client_devs" {
  project = "pcc-prj-app-devtest"
  role    = "roles/alloydb.client"
  member  = "group:gcp-developers@pcconnect.ai"
}
```

**Permissions Granted**:
- `alloydb.instances.get`
- `alloydb.instances.connect`

**Rationale**: Developers need Auth Proxy access for local development (Phase 2.7)

---

### 2. CI/CD Service Account - Flyway Migrations

**Principal**: `serviceAccount:pcc-cloudbuild-sa@pcc-prj-app-devtest.iam.gserviceaccount.com`
**Role**: `roles/alloydb.client`
**Project**: `pcc-prj-app-devtest`

**Purpose**: Allow Cloud Build to run Flyway migrations via Auth Proxy

**Terraform**:
```hcl
resource "google_project_iam_member" "alloydb_client_cicd" {
  project = "pcc-prj-app-devtest"
  role    = "roles/alloydb.client"
  member  = "serviceAccount:pcc-cloudbuild-sa@pcc-prj-app-devtest.iam.gserviceaccount.com"
}
```

**Rationale**: CI/CD pipeline runs Flyway migrations (Phase 2.7)

---

### 3. GKE Service Accounts - Application Access

**Pattern**: Each microservice GKE service account gets `alloydb.client` role

**Note**: Microservices use **database credentials** (not IAM authentication)
- This binding is **optional** for devtest (IAM auth not required)
- Recommended for production (defense-in-depth)

**Terraform** (optional):
```hcl
# Example for client-api
resource "google_project_iam_member" "alloydb_client_client_api" {
  project = "pcc-prj-app-devtest"
  role    = "roles/alloydb.client"
  member  = "serviceAccount:pcc-client-api-sa@pcc-prj-app-devtest.iam.gserviceaccount.com"
}
```

**Decision**: Skip for devtest (use credentials only), add for production

---

## IAM Bindings for Secret Manager

### 1. GKE Service Accounts - Secret Access (Workload Identity)

**Pattern**: Each service account gets `secretAccessor` role for its secret

| GKE Service Account | Secret | Role |
|---------------------|--------|------|
| `pcc-client-api-sa` | `client-api-db-credentials-devtest` | `roles/secretmanager.secretAccessor` |

**Note**: Additional service account bindings created in Phase 10 when remaining services are deployed

**Terraform** (in secret-manager-database module):
```hcl
resource "google_secret_manager_secret_iam_member" "client_api_accessor" {
  secret_id = google_secret_manager_secret.client_api_db_credentials.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:pcc-client-api-sa@pcc-prj-app-devtest.iam.gserviceaccount.com"
}
```

**Permissions Granted**:
- `secretmanager.versions.access` (read secret value)

---

### 2. Developer Group - Secret Access

**Principal**: `group:gcp-developers@pcconnect.ai`
**Role**: `roles/secretmanager.secretAccessor`
**Secrets**: All 3 secrets (1 service (pcc-client-api) + admin + flyway)

**Purpose**: Developers need credentials for local testing with Auth Proxy

**Terraform**:
```hcl
# Grant developer access to SERVICE SECRETS ONLY (not admin or Flyway)
resource "google_secret_manager_secret_iam_member" "devs_accessor_client_api" {
  secret_id = google_secret_manager_secret.client_api_db_credentials.id  # Only service secret
  role      = "roles/secretmanager.secretAccessor"
  member    = "group:gcp-developers@pcconnect.ai"
}

# Note: Additional service secret bindings will be added in Phase 10 when remaining services are deployed

# Admin credentials - DevOps access only
resource "google_secret_manager_secret_iam_member" "devops_admin_accessor" {
  secret_id = google_secret_manager_secret.admin_credentials.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "group:gcp-devops@pcconnect.ai"
}
```

**Rationale**: Local development requires database credentials

---

### 3. CI/CD Service Account - Flyway Secret Access

**Principal**: `serviceAccount:pcc-cloudbuild-sa@pcc-prj-app-devtest.iam.gserviceaccount.com`
**Role**: `roles/secretmanager.secretAccessor`
**Secret**: `alloydb-flyway-credentials-devtest` only

**Purpose**: Cloud Build needs Flyway credentials for schema migrations

**Terraform**:
```hcl
resource "google_secret_manager_secret_iam_member" "cicd_flyway_accessor" {
  secret_id = google_secret_manager_secret.flyway_credentials.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:pcc-cloudbuild-sa@pcc-prj-app-devtest.iam.gserviceaccount.com"
}
```

**Principle**: CI/CD only needs Flyway secret (not service secrets)

---

## IAM Bindings for Admin Access

### 1. Admin User - Secret Manager Admin

**Principal**: `group:gcp-devops@pcconnect.ai`
**Role**: `roles/secretmanager.admin`
**Scope**: AlloyDB secrets only (resource-level, not project-level)

**Purpose**: Rotate passwords, update secrets, manage secret lifecycle

**Terraform**:
```hcl
# Resource-level admin bindings for AlloyDB secrets only
resource "google_secret_manager_secret_iam_member" "admin_client_api_creds" {
  secret_id = google_secret_manager_secret.client_api_db_credentials.id
  role      = "roles/secretmanager.admin"
  member    = "group:gcp-devops@pcconnect.ai"
}

resource "google_secret_manager_secret_iam_member" "admin_admin_creds" {
  secret_id = google_secret_manager_secret.admin_credentials.id
  role      = "roles/secretmanager.admin"
  member    = "group:gcp-devops@pcconnect.ai"
}

resource "google_secret_manager_secret_iam_member" "admin_flyway_creds" {
  secret_id = google_secret_manager_secret.flyway_credentials.id
  role      = "roles/secretmanager.admin"
  member    = "group:gcp-devops@pcconnect.ai"
}
```

**Permissions Granted** (resource-level):
- Create, update, delete secret versions for AlloyDB secrets
- Manage secret versions for AlloyDB secrets
- Configure rotation for AlloyDB secrets

**Security**: Resource-level bindings prevent access to non-AlloyDB secrets in project

---

### 2. Admin User - AlloyDB Admin

**Principal**: `group:gcp-devops@pcconnect.ai`
**Role**: `roles/alloydb.admin`
**Project**: `pcc-prj-app-devtest`

**Purpose**: Manage AlloyDB cluster, instances, databases

**Terraform**:
```hcl
resource "google_project_iam_member" "alloydb_admin" {
  project = "pcc-prj-app-devtest"
  role    = "roles/alloydb.admin"
  member  = "group:gcp-devops@pcconnect.ai"
}
```

**Permissions Granted**:
- Cluster management (create, update, delete)
- Instance management
- Backup management
- Monitoring access

---

## Audit Logging Configuration

### Cloud Audit Logs for Secret Manager and AlloyDB

**Requirement**: Enable Cloud Audit Logs for all IAM operations on secrets and AlloyDB resources (Phase 2.5 reference: line 400)

**Log Types**:
- **DATA_READ**: Log secret access and AlloyDB queries
- **DATA_WRITE**: Log secret modifications and AlloyDB writes
- **ADMIN_READ**: Log administrative read operations

**Retention**: 90 days (matches Phase 2.5 requirement)

**Terraform**:
```hcl
# Enable audit logging for Secret Manager
resource "google_project_iam_audit_config" "secret_manager_audit" {
  project = "pcc-prj-app-devtest"
  service = "secretmanager.googleapis.com"

  audit_log_config {
    log_type = "DATA_READ"  # Log secret access
  }

  audit_log_config {
    log_type = "DATA_WRITE"  # Log secret modifications
  }

  audit_log_config {
    log_type = "ADMIN_READ"  # Log admin operations
  }
}

# Enable audit logging for AlloyDB
resource "google_project_iam_audit_config" "alloydb_audit" {
  project = "pcc-prj-app-devtest"
  service = "alloydb.googleapis.com"

  audit_log_config {
    log_type = "ADMIN_READ"
  }

  audit_log_config {
    log_type = "DATA_READ"
  }

  audit_log_config {
    log_type = "DATA_WRITE"
  }
}

# Configure log retention in Cloud Logging
resource "google_logging_project_bucket_config" "audit_logs" {
  project        = "pcc-prj-app-devtest"
  location       = "global"
  retention_days = 90
  bucket_id      = "_Default"
}
```

**Security Benefits**:
- Track who accessed secrets and when
- Detect unauthorized access attempts
- Support forensic investigations
- Compliance with audit requirements

---

## Workload Identity Setup

### GKE Service Account → Google Service Account Binding

**Pattern**: Link Kubernetes service account to Google Cloud service account

**Example** (client-api):
```hcl
# Create Google service account
resource "google_service_account" "client_api" {
  account_id   = "pcc-client-api-sa"
  display_name = "Service account for pcc-client-api"
  project      = "pcc-prj-app-devtest"
}

# Bind Kubernetes service account to Google service account
resource "google_service_account_iam_member" "client_api_workload_identity" {
  service_account_id = google_service_account.client_api.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:pcc-prj-app-devtest.svc.id.goog[devtest/pcc-client-api-sa]"  # devtest namespace
}
```

**Kubernetes Service Account Annotation** (Phase 3):
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: pcc-client-api-sa
  namespace: devtest  # Environment-specific namespace
  annotations:
    iam.gke.io/gcp-service-account: pcc-client-api-sa@pcc-prj-app-devtest.iam.gserviceaccount.com
```

**Note**: Workload Identity setup is Phase 3 (Kubernetes deployment)

---

## IAM Binding Summary

### AlloyDB Access

| Principal | Role | Purpose |
|-----------|------|---------|
| `gcp-developers@pcconnect.ai` | `alloydb.client` | Auth Proxy access |
| `pcc-cloudbuild-sa` | `alloydb.client` | Flyway migrations |
| `gcp-devops@pcconnect.ai` | `alloydb.admin` | Cluster management |

---

### Secret Manager Access

| Principal | Role | Secrets | Purpose |
|-----------|------|---------|---------|
| `pcc-client-api-sa` | `secretAccessor` | `client-api-db-credentials-devtest` | App access |
| `gcp-developers@pcconnect.ai` | `secretAccessor` | `client-api-db-credentials-devtest` ONLY | Local testing (service secrets only) |
| `pcc-cloudbuild-sa` | `secretAccessor` | `alloydb-flyway-credentials-devtest` | Flyway migrations |
| `gcp-devops@pcconnect.ai` | `secretAccessor` | `alloydb-admin-credentials-devtest` | Admin operations |
| `gcp-devops@pcconnect.ai` | `secretmanager.admin` | AlloyDB secrets (resource-level) | Secret management |

**Note**: Additional service account bindings created in Phase 10 when remaining services are deployed

---

## Terraform Module Integration

### Module: secret-manager-database (from Phase 2.5)

**Enhanced with IAM Bindings**:

```hcl
module "alloydb_secrets_devtest" {
  source = "git::https://github.com/your-org/pcc-tf-library.git//modules/secret-manager-database?ref=v1.0.0"

  project_id  = "pcc-prj-app-devtest"
  environment = "devtest"

  # ... other parameters from Phase 2.5 ...

  # Granular IAM bindings per secret (CORRECTED from simple group-based approach)
  secret_iam_bindings = {
    # Service secret bindings
    "client-api-db-credentials-devtest" = {
      "roles/secretmanager.secretAccessor" = [
        "serviceAccount:pcc-client-api-sa@pcc-prj-app-devtest.iam.gserviceaccount.com",
        "group:gcp-developers@pcconnect.ai"  # Developers get service secrets ONLY
      ]
      "roles/secretmanager.admin" = [
        "group:gcp-devops@pcconnect.ai"
      ]
    }

    # Admin secret bindings
    "alloydb-admin-credentials-devtest" = {
      "roles/secretmanager.secretAccessor" = [
        "group:gcp-devops@pcconnect.ai"  # DevOps only, NOT developers
      ]
      "roles/secretmanager.admin" = [
        "group:gcp-devops@pcconnect.ai"
      ]
    }

    # Flyway secret bindings
    "alloydb-flyway-credentials-devtest" = {
      "roles/secretmanager.secretAccessor" = [
        "serviceAccount:pcc-cloudbuild-sa@pcc-prj-app-devtest.iam.gserviceaccount.com"  # CI/CD only
      ]
      "roles/secretmanager.admin" = [
        "group:gcp-devops@pcconnect.ai"
      ]
    }
  }

  # Workload Identity bindings
  workload_identity_bindings = [
    {
      secret_name     = "client-api-db-credentials-devtest"
      service_account = "pcc-client-api-sa@pcc-prj-app-devtest.iam.gserviceaccount.com"
      k8s_namespace   = "devtest"  # Environment-specific namespace
    }
  ]
}
```

---

## Tasks (Planning + Configuration)

1. **AlloyDB IAM**:
   - [x] Design developer group binding (Auth Proxy access)
   - [x] Design CI/CD binding (Flyway access)
   - [x] Design admin group binding (cluster management)
   - [x] Decide on GKE service account bindings (optional for devtest)

2. **Secret Manager IAM**:
   - [x] Design Workload Identity bindings (1 service (pcc-client-api) → 1 secret)
   - [x] Design developer group binding (all secrets)
   - [x] Design CI/CD binding (Flyway secret only)
   - [x] Design admin group binding (secret management)

3. **Workload Identity**:
   - [x] Document GKE service account → Google service account binding
   - [x] Document Kubernetes service account annotation pattern
   - [x] Note Phase 3 dependency for Kubernetes setup

4. **Terraform Integration**:
   - [x] Enhance secret-manager-database module with IAM bindings
   - [x] Plan module variables for IAM configuration
   - [x] Document module call with IAM parameters

---

## Dependencies

**Upstream**:
- Phase 2.5: Secret Manager design (3 secrets)
- Phase 2.3: AlloyDB cluster (project and resources)

**Downstream**:
- Phase 2.7: Developer Auth Proxy access requires `alloydb.client` role
- Phase 3: Workload Identity bindings for GKE service accounts
- Phase 3: Kubernetes service account annotations

---

## Validation Criteria

- [x] AlloyDB IAM bindings designed (3 principals)
- [x] Secret Manager IAM bindings designed (1 service (pcc-client-api) + developers + CI/CD + admins)
- [x] Workload Identity pattern documented
- [x] Least privilege principle applied (minimal permissions)
- [x] Terraform module enhanced with IAM bindings
- [x] IAM binding summary table created

---

## Deliverables

- [x] IAM binding design document (this file)
- [x] AlloyDB IAM bindings (3 principals)
- [x] Secret Manager IAM bindings (1 service (pcc-client-api) + 3 groups)
- [x] Workload Identity binding pattern
- [x] Terraform module enhancement plan

---

## References

- Phase 2.5 (Secret Manager design)
- Phase 2.3 (AlloyDB cluster)
- Phase 2.7 (Auth Proxy usage)
- Phase 3 (Workload Identity setup)
- 🔗 Workload Identity: https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity
- 🔗 AlloyDB IAM: https://cloud.google.com/alloydb/docs/auth
- 🔗 Secret Manager IAM: https://cloud.google.com/secret-manager/docs/access-control

---

## Notes

- **Least Privilege**: Each principal gets minimum required permissions
- **Workload Identity**: Preferred over service account keys (more secure)
- **Developer Access**: Required for local testing with Auth Proxy
- **CI/CD Access**: Only Flyway secret (not service secrets)
- **Admin Access**: Separate admin group for cluster and secret management
- **Production**: Add GKE service accounts to `alloydb.client` for defense-in-depth
- **Phase 3 Dependency**: Kubernetes service account annotations created in Phase 3

---

## Time Estimate

**Planning + Configuration**: 20-25 minutes
- 5 min: Design AlloyDB IAM bindings (3 principals)
- 10 min: Design Secret Manager IAM bindings (1 service (pcc-client-api) + 3 groups)
- 5 min: Document Workload Identity pattern
- 5 min: Enhance terraform module with IAM configuration

---

**Next Phase**: 2.7 - Plan Developer Access & Flyway
