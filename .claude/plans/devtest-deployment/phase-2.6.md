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
- GKE service accounts (7 microservices) - Workload Identity
- Developer group (`pcc-developers@portcon.com`)
- CI/CD service account (Cloud Build)

**Principle**: Least privilege (grant minimum required permissions)

---

## IAM Bindings for AlloyDB

### 1. Developer Group - Auth Proxy Access

**Principal**: `group:pcc-developers@portcon.com`
**Role**: `roles/alloydb.client`
**Project**: `pcc-prj-app-devtest`

**Purpose**: Allow developers to connect via AlloyDB Auth Proxy for local testing

**Terraform**:
```hcl
resource "google_project_iam_member" "alloydb_client_devs" {
  project = "pcc-prj-app-devtest"
  role    = "roles/alloydb.client"
  member  = "group:pcc-developers@portcon.com"
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
# Example for auth-api
resource "google_project_iam_member" "alloydb_client_auth_api" {
  project = "pcc-prj-app-devtest"
  role    = "roles/alloydb.client"
  member  = "serviceAccount:pcc-auth-api-sa@pcc-prj-app-devtest.iam.gserviceaccount.com"
}

# Repeat for other 6 services...
```

**Decision**: Skip for devtest (use credentials only), add for production

---

## IAM Bindings for Secret Manager

### 1. GKE Service Accounts - Secret Access (Workload Identity)

**Pattern**: Each service account gets `secretAccessor` role for its secret

| GKE Service Account | Secret | Role |
|---------------------|--------|------|
| `pcc-auth-api-sa` | `auth-db-credentials-devtest` | `roles/secretmanager.secretAccessor` |
| `pcc-client-api-sa` | `client-db-credentials-devtest` | `roles/secretmanager.secretAccessor` |
| `pcc-user-api-sa` | `user-db-credentials-devtest` | `roles/secretmanager.secretAccessor` |
| `pcc-metric-builder-api-sa` | `metric-builder-db-credentials-devtest` | `roles/secretmanager.secretAccessor` |
| `pcc-metric-tracker-api-sa` | `metric-tracker-db-credentials-devtest` | `roles/secretmanager.secretAccessor` |
| `pcc-task-builder-api-sa` | `task-builder-db-credentials-devtest` | `roles/secretmanager.secretAccessor` |
| `pcc-task-tracker-api-sa` | `task-tracker-db-credentials-devtest` | `roles/secretmanager.secretAccessor` |

**Terraform** (in secret-manager-database module):
```hcl
resource "google_secret_manager_secret_iam_member" "auth_api_accessor" {
  secret_id = google_secret_manager_secret.auth_db_credentials.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:pcc-auth-api-sa@pcc-prj-app-devtest.iam.gserviceaccount.com"
}

# Repeat for other 6 services...
```

**Permissions Granted**:
- `secretmanager.versions.access` (read secret value)

---

### 2. Developer Group - Secret Access

**Principal**: `group:pcc-developers@portcon.com`
**Role**: `roles/secretmanager.secretAccessor`
**Secrets**: All 9 secrets (7 service + admin + flyway)

**Purpose**: Developers need credentials for local testing with Auth Proxy

**Terraform**:
```hcl
# Grant developer access to all secrets
resource "google_secret_manager_secret_iam_member" "devs_accessor" {
  for_each = toset([
    google_secret_manager_secret.auth_db_credentials.id,
    google_secret_manager_secret.client_db_credentials.id,
    google_secret_manager_secret.user_db_credentials.id,
    google_secret_manager_secret.metric_builder_db_credentials.id,
    google_secret_manager_secret.metric_tracker_db_credentials.id,
    google_secret_manager_secret.task_builder_db_credentials.id,
    google_secret_manager_secret.task_tracker_db_credentials.id,
    google_secret_manager_secret.admin_credentials.id,
    google_secret_manager_secret.flyway_credentials.id
  ])

  secret_id = each.value
  role      = "roles/secretmanager.secretAccessor"
  member    = "group:pcc-developers@portcon.com"
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

**Principal**: `group:pcc-admins@portcon.com`
**Role**: `roles/secretmanager.admin`
**Project**: `pcc-prj-app-devtest`

**Purpose**: Rotate passwords, update secrets, manage secret lifecycle

**Terraform**:
```hcl
resource "google_project_iam_member" "secret_admin" {
  project = "pcc-prj-app-devtest"
  role    = "roles/secretmanager.admin"
  member  = "group:pcc-admins@portcon.com"
}
```

**Permissions Granted**:
- Create, update, delete secrets
- Manage secret versions
- Configure rotation

---

### 2. Admin User - AlloyDB Admin

**Principal**: `group:pcc-admins@portcon.com`
**Role**: `roles/alloydb.admin`
**Project**: `pcc-prj-app-devtest`

**Purpose**: Manage AlloyDB cluster, instances, databases

**Terraform**:
```hcl
resource "google_project_iam_member" "alloydb_admin" {
  project = "pcc-prj-app-devtest"
  role    = "roles/alloydb.admin"
  member  = "group:pcc-admins@portcon.com"
}
```

**Permissions Granted**:
- Cluster management (create, update, delete)
- Instance management
- Backup management
- Monitoring access

---

## Workload Identity Setup

### GKE Service Account → Google Service Account Binding

**Pattern**: Link Kubernetes service account to Google Cloud service account

**Example** (auth-api):
```hcl
# Create Google service account
resource "google_service_account" "auth_api" {
  account_id   = "pcc-auth-api-sa"
  display_name = "Service account for pcc-auth-api"
  project      = "pcc-prj-app-devtest"
}

# Bind Kubernetes service account to Google service account
resource "google_service_account_iam_member" "auth_api_workload_identity" {
  service_account_id = google_service_account.auth_api.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:pcc-prj-app-devtest.svc.id.goog[default/pcc-auth-api-sa]"
}
```

**Kubernetes Service Account Annotation** (Phase 3):
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: pcc-auth-api-sa
  namespace: default
  annotations:
    iam.gke.io/gcp-service-account: pcc-auth-api-sa@pcc-prj-app-devtest.iam.gserviceaccount.com
```

**Note**: Workload Identity setup is Phase 3 (Kubernetes deployment)

---

## IAM Binding Summary

### AlloyDB Access

| Principal | Role | Purpose |
|-----------|------|---------|
| `pcc-developers@portcon.com` | `alloydb.client` | Auth Proxy access |
| `pcc-cloudbuild-sa` | `alloydb.client` | Flyway migrations |
| `pcc-admins@portcon.com` | `alloydb.admin` | Cluster management |

---

### Secret Manager Access

| Principal | Role | Secrets | Purpose |
|-----------|------|---------|---------|
| `pcc-auth-api-sa` | `secretAccessor` | `auth-db-credentials-devtest` | App access |
| `pcc-client-api-sa` | `secretAccessor` | `client-db-credentials-devtest` | App access |
| `pcc-user-api-sa` | `secretAccessor` | `user-db-credentials-devtest` | App access |
| `pcc-metric-builder-api-sa` | `secretAccessor` | `metric-builder-db-credentials-devtest` | App access |
| `pcc-metric-tracker-api-sa` | `secretAccessor` | `metric-tracker-db-credentials-devtest` | App access |
| `pcc-task-builder-api-sa` | `secretAccessor` | `task-builder-db-credentials-devtest` | App access |
| `pcc-task-tracker-api-sa` | `secretAccessor` | `task-tracker-db-credentials-devtest` | App access |
| `pcc-developers@portcon.com` | `secretAccessor` | All 9 secrets | Local testing |
| `pcc-cloudbuild-sa` | `secretAccessor` | `alloydb-flyway-credentials-devtest` | Flyway migrations |
| `pcc-admins@portcon.com` | `secretmanager.admin` | All secrets | Secret management |

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

  # IAM bindings for Workload Identity
  workload_identity_bindings = [
    {
      secret_name         = "auth-db-credentials-devtest"
      service_account     = "pcc-auth-api-sa@pcc-prj-app-devtest.iam.gserviceaccount.com"
    },
    {
      secret_name         = "client-db-credentials-devtest"
      service_account     = "pcc-client-api-sa@pcc-prj-app-devtest.iam.gserviceaccount.com"
    },
    # ... other 5 services ...
  ]

  # IAM binding for developer group
  developer_group = "pcc-developers@portcon.com"

  # IAM binding for CI/CD
  cicd_service_account = "pcc-cloudbuild-sa@pcc-prj-app-devtest.iam.gserviceaccount.com"

  # IAM binding for admin group
  admin_group = "pcc-admins@portcon.com"
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
   - [x] Design Workload Identity bindings (7 services → 7 secrets)
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
- Phase 2.5: Secret Manager design (9 secrets)
- Phase 2.3: AlloyDB cluster (project and resources)

**Downstream**:
- Phase 2.7: Developer Auth Proxy access requires `alloydb.client` role
- Phase 3: Workload Identity bindings for GKE service accounts
- Phase 3: Kubernetes service account annotations

---

## Validation Criteria

- [x] AlloyDB IAM bindings designed (3 principals)
- [x] Secret Manager IAM bindings designed (7 services + developers + CI/CD + admins)
- [x] Workload Identity pattern documented
- [x] Least privilege principle applied (minimal permissions)
- [x] Terraform module enhanced with IAM bindings
- [x] IAM binding summary table created

---

## Deliverables

- [x] IAM binding design document (this file)
- [x] AlloyDB IAM bindings (3 principals)
- [x] Secret Manager IAM bindings (7 services + 3 groups)
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
- 10 min: Design Secret Manager IAM bindings (7 services + 3 groups)
- 5 min: Document Workload Identity pattern
- 5 min: Enhance terraform module with IAM configuration

---

**Next Phase**: 2.7 - Plan Developer Access & Flyway
