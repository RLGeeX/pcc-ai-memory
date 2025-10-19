# Phase 2.5: Plan Secret Manager & Credential Rotation

**Phase**: 2.5 (AlloyDB Infrastructure - Secrets Management)
**Duration**: 25-30 minutes
**Type**: Planning + Configuration
**Status**: 📋 Planning (Not Started)
**Date**: TBD (10/20+)

---

## Objective

Design Secret Manager configuration for AlloyDB database credentials, including 7 service users, admin users, rotation strategy, and IAM bindings for secure access.

## Prerequisites

✅ Phase 2.4 completed (7 databases planned)
✅ Understanding of Secret Manager concepts
✅ Database user strategy from Phase 2.4
✅ Workload Identity configuration (Phase 3 reference)

---

## Secret Manager Design

### Overview

**Project**: `pcc-prj-app-devtest`
**Total Secrets**: 9
- 7 service user credentials (one per database)
- 1 admin user credential (superuser)
- 1 Flyway user credential (migrations)

**Rotation**: 30-90 day automatic rotation
**Access**: Workload Identity (GKE service accounts) + Developer group

---

## Secret Specifications

### 1. Database Service User Secrets

**Pattern**: `{service}-db-credentials-{env}`

#### auth-db-credentials-devtest
```json
{
  "username": "auth_api_user",
  "password": "<generated-32-char>",
  "database": "auth_db_devtest",
  "host": "10.28.48.10",
  "port": "5432",
  "connection_string": "Host=10.28.48.10;Port=5432;Database=auth_db_devtest;Username=auth_api_user;Password=<password>;Pooling=true;MinPoolSize=5;MaxPoolSize=20"
}
```

**Permissions**: Read-write on `auth_db_devtest`

---

#### client-db-credentials-devtest
```json
{
  "username": "client_api_user",
  "password": "<generated-32-char>",
  "database": "client_db_devtest",
  "host": "10.28.48.10",
  "port": "5432",
  "connection_string": "Host=10.28.48.10;Port=5432;Database=client_db_devtest;Username=client_api_user;Password=<password>;Pooling=true;MinPoolSize=5;MaxPoolSize=20"
}
```

**Permissions**: Read-write on `client_db_devtest`

---

#### user-db-credentials-devtest
```json
{
  "username": "user_api_user",
  "password": "<generated-32-char>",
  "database": "user_db_devtest",
  "host": "10.28.48.10",
  "port": "5432",
  "connection_string": "Host=10.28.48.10;Port=5432;Database=user_db_devtest;Username=user_api_user;Password=<password>;Pooling=true;MinPoolSize=5;MaxPoolSize=20"
}
```

**Permissions**: Read-write on `user_db_devtest`

---

#### metric-builder-db-credentials-devtest
```json
{
  "username": "metric_builder_api_user",
  "password": "<generated-32-char>",
  "database": "metric_builder_db_devtest",
  "host": "10.28.48.10",
  "port": "5432",
  "connection_string": "Host=10.28.48.10;Port=5432;Database=metric_builder_db_devtest;Username=metric_builder_api_user;Password=<password>;Pooling=true;MinPoolSize=5;MaxPoolSize=20"
}
```

**Permissions**: Read-write on `metric_builder_db_devtest`

---

#### metric-tracker-db-credentials-devtest
```json
{
  "username": "metric_tracker_api_user",
  "password": "<generated-32-char>",
  "database": "metric_tracker_db_devtest",
  "host": "10.28.48.10",
  "port": "5432",
  "connection_string": "Host=10.28.48.10;Port=5432;Database=metric_tracker_db_devtest;Username=metric_tracker_api_user;Password=<password>;Pooling=true;MinPoolSize=5;MaxPoolSize=20"
}
```

**Permissions**: Read-write on `metric_tracker_db_devtest`

---

#### task-builder-db-credentials-devtest
```json
{
  "username": "task_builder_api_user",
  "password": "<generated-32-char>",
  "database": "task_builder_db_devtest",
  "host": "10.28.48.10",
  "port": "5432",
  "connection_string": "Host=10.28.48.10;Port=5432;Database=task_builder_db_devtest;Username=task_builder_api_user;Password=<password>;Pooling=true;MinPoolSize=5;MaxPoolSize=20"
}
```

**Permissions**: Read-write on `task_builder_db_devtest`

---

#### task-tracker-db-credentials-devtest
```json
{
  "username": "task_tracker_api_user",
  "password": "<generated-32-char>",
  "database": "task_tracker_db_devtest",
  "host": "10.28.48.10",
  "port": "5432",
  "connection_string": "Host=10.28.48.10;Port=5432;Database=task_tracker_db_devtest;Username=task_tracker_api_user;Password=<password>;Pooling=true;MinPoolSize=5;MaxPoolSize=20"
}
```

**Permissions**: Read-write on `task_tracker_db_devtest`

---

### 2. Admin User Secret

#### alloydb-admin-credentials-devtest
```json
{
  "username": "pcc_admin",
  "password": "<generated-32-char>",
  "host": "10.28.48.10",
  "port": "5432",
  "connection_string": "Host=10.28.48.10;Port=5432;Username=pcc_admin;Password=<password>;Database=postgres"
}
```

**Permissions**: Superuser (all databases)
**Usage**: Manual administration, emergency access, schema changes

---

### 3. Flyway User Secret

#### alloydb-flyway-credentials-devtest
```json
{
  "username": "flyway_user",
  "password": "<generated-32-char>",
  "host": "10.28.48.10",
  "port": "5432",
  "connection_string": "Host=10.28.48.10;Port=5432;Username=flyway_user;Password=<password>"
}
```

**Permissions**: Schema management (CREATE, ALTER, DROP) on all 7 databases
**Usage**: CI/CD pipeline (Cloud Build) for Flyway migrations

---

## Credential Rotation Strategy

### Rotation Policy

**Rotation Period**: 30-90 days
- **Devtest**: 90 days (lower risk, fewer disruptions)
- **Production** (future): 30 days (higher security)

**Rotation Method**: Automatic rotation with Cloud Functions
- Generate new password
- Update PostgreSQL user password
- Update Secret Manager secret
- Trigger pod restart (Kubernetes) for microservices

**Rotation Window**: Sunday 2:00 AM - 4:00 AM EST (matches backup window)

---

### Rotation Architecture

```
Cloud Scheduler (every 90 days)
    ↓
Cloud Function (rotation-handler)
    ↓
Secret Manager (update secret)
    ↓
AlloyDB (ALTER USER ... PASSWORD)
    ↓
Kubernetes (restart pods via annotation)
    ↓
Microservices (reconnect with new password)
```

**Implementation**: Phase 3 (Kubernetes deployment)

---

### Password Generation

**Format**: 32-character random string
**Character Set**: `[a-zA-Z0-9!@#$%^&*()-_=+]`
**Entropy**: ~191 bits

**Generation Command**:
```bash
openssl rand -base64 32 | tr -d '/+=' | head -c 32
```

---

## Terraform Configuration

### Secret Manager Resources

**Module Location**: `pcc-tf-library/modules/secret-manager-database/`
**Caller**: `pcc-app-shared-infra/terraform/secrets.tf`

#### Module Call (Example)

```hcl
module "alloydb_secrets_devtest" {
  source = "git::https://github.com/your-org/pcc-tf-library.git//modules/secret-manager-database?ref=v1.0.0"

  project_id  = "pcc-prj-app-devtest"
  environment = "devtest"

  # Database connection info (from Phase 2.3 outputs)
  alloydb_host = module.alloydb_cluster_devtest.primary_ip_address
  alloydb_port = 5432

  # Service user secrets (7 microservices)
  service_secrets = [
    {
      name     = "auth-db-credentials-devtest"
      username = "auth_api_user"
      database = "auth_db_devtest"
    },
    {
      name     = "client-db-credentials-devtest"
      username = "client_api_user"
      database = "client_db_devtest"
    },
    {
      name     = "user-db-credentials-devtest"
      username = "user_api_user"
      database = "user_db_devtest"
    },
    {
      name     = "metric-builder-db-credentials-devtest"
      username = "metric_builder_api_user"
      database = "metric_builder_db_devtest"
    },
    {
      name     = "metric-tracker-db-credentials-devtest"
      username = "metric_tracker_api_user"
      database = "metric_tracker_db_devtest"
    },
    {
      name     = "task-builder-db-credentials-devtest"
      username = "task_builder_api_user"
      database = "task_builder_db_devtest"
    },
    {
      name     = "task-tracker-db-credentials-devtest"
      username = "task_tracker_api_user"
      database = "task_tracker_db_devtest"
    }
  ]

  # Admin secrets
  admin_secret = {
    name     = "alloydb-admin-credentials-devtest"
    username = "pcc_admin"
  }

  # Flyway secret
  flyway_secret = {
    name     = "alloydb-flyway-credentials-devtest"
    username = "flyway_user"
  }

  # Rotation configuration
  rotation_period_days = 90

  labels = {
    environment = "devtest"
    purpose     = "database-credentials"
  }
}
```

---

### Terraform Module Structure

**Files**:
```
pcc-tf-library/modules/secret-manager-database/
├── main.tf           # Secret Manager resources
├── variables.tf      # Module inputs
├── outputs.tf        # Secret IDs and versions
├── versions.tf       # Provider requirements
└── README.md         # Usage documentation
```

**Resources**:
- `google_secret_manager_secret` (for each secret)
- `google_secret_manager_secret_version` (initial version)
- `google_secret_manager_secret_iam_member` (access control)

---

## IAM Bindings for Secrets

### Workload Identity (GKE Service Accounts)

**Pattern**: `{service}-sa` → `{service}-db-credentials-{env}`

| GKE Service Account | Secret | Permission |
|---------------------|--------|------------|
| `pcc-auth-api-sa` | `auth-db-credentials-devtest` | `roles/secretmanager.secretAccessor` |
| `pcc-client-api-sa` | `client-db-credentials-devtest` | `roles/secretmanager.secretAccessor` |
| `pcc-user-api-sa` | `user-db-credentials-devtest` | `roles/secretmanager.secretAccessor` |
| `pcc-metric-builder-api-sa` | `metric-builder-db-credentials-devtest` | `roles/secretmanager.secretAccessor` |
| `pcc-metric-tracker-api-sa` | `metric-tracker-db-credentials-devtest` | `roles/secretmanager.secretAccessor` |
| `pcc-task-builder-api-sa` | `task-builder-db-credentials-devtest` | `roles/secretmanager.secretAccessor` |
| `pcc-task-tracker-api-sa` | `task-tracker-db-credentials-devtest` | `roles/secretmanager.secretAccessor` |

**Note**: Workload Identity setup in Phase 3 (Kubernetes deployment)

---

### Developer Access

**Group**: `pcc-developers@portcon.com`
**Permission**: `roles/secretmanager.secretAccessor` (read-only)
**Scope**: All 9 secrets

**Rationale**: Developers need credentials for local testing with Auth Proxy (Phase 2.7)

---

### CI/CD Access (Cloud Build)

**Service Account**: `pcc-cloudbuild-sa@pcc-prj-app-devtest.iam.gserviceaccount.com`
**Permission**: `roles/secretmanager.secretAccessor`
**Scope**: `alloydb-flyway-credentials-devtest` only

**Rationale**: Cloud Build needs Flyway credentials for schema migrations

---

## Connection String Format

### Npgsql (.NET) Connection String

```
Host={host};Port={port};Database={database};Username={username};Password={password};Pooling=true;MinPoolSize=5;MaxPoolSize=20;SSL Mode=Require;Trust Server Certificate=false
```

**Connection Pool Settings**:
- **MinPoolSize**: 5 (maintain 5 idle connections)
- **MaxPoolSize**: 20 (max 20 connections per pod)
- **Pooling**: Enabled (reuse connections)
- **SSL**: Required (encrypted in-transit)

---

### Environment Variables (Kubernetes)

**Pattern**: Inject secret as environment variable

```yaml
env:
  - name: DATABASE_CONNECTION_STRING
    valueFrom:
      secretKeyRef:
        name: auth-db-credentials-devtest
        key: connection_string
```

**Alternative**: Mount secret as file (more secure, recommended)

```yaml
volumeMounts:
  - name: db-credentials
    mountPath: /secrets/db
    readOnly: true
volumes:
  - name: db-credentials
    secret:
      secretName: auth-db-credentials-devtest
```

---

## Tasks (Planning + Configuration)

1. **Secret Design**:
   - [x] Document 9 secret specifications
   - [x] Define JSON structure for each secret
   - [x] Establish naming convention

2. **Rotation Strategy**:
   - [x] Define rotation period (90 days devtest)
   - [x] Document rotation architecture (Cloud Function)
   - [x] Plan rotation window (Sunday 2-4 AM)

3. **IAM Bindings**:
   - [x] Map GKE service accounts to secrets (Workload Identity)
   - [x] Grant developer access (pcc-developers group)
   - [x] Grant CI/CD access (Flyway secret only)

4. **Terraform Module**:
   - [x] Plan module structure (secret-manager-database)
   - [x] Define module inputs (service_secrets, admin_secret, flyway_secret)
   - [x] Plan IAM bindings in module

---

## Dependencies

**Upstream**:
- Phase 2.4: Database user list (7 service users)
- Phase 2.3: AlloyDB IP address (for connection strings)

**Downstream**:
- Phase 2.6: IAM bindings for secret access
- Phase 2.7: Flyway uses flyway_user credentials
- Phase 3: Kubernetes workloads access secrets via Workload Identity

---

## Validation Criteria

- [x] 9 secrets designed (7 service, 1 admin, 1 flyway)
- [x] JSON structure defined for all secrets
- [x] Connection strings include Npgsql pooling parameters
- [x] Rotation strategy documented (90 days)
- [x] IAM bindings planned (Workload Identity + developers)
- [x] Terraform module structure defined

---

## Deliverables

- [x] Secret Manager design document (this file)
- [x] 9 secret specifications with JSON structure
- [x] Rotation strategy (Cloud Function architecture)
- [x] IAM binding plan
- [x] Terraform module design (input for Phase 2.6)

---

## References

- Phase 2.4 (database user strategy)
- Phase 2.3 (AlloyDB connection details)
- Phase 2.6 (IAM bindings implementation)
- Phase 2.7 (Flyway credentials usage)
- Phase 3 (Workload Identity setup)
- 🔗 Secret Manager Docs: https://cloud.google.com/secret-manager/docs
- 🔗 Npgsql Connection Strings: https://www.npgsql.org/doc/connection-string-parameters.html

---

## Notes

- **Password Generation**: Use strong random passwords (32 chars, high entropy)
- **Rotation**: Automatic rotation requires Cloud Function + Cloud Scheduler (Phase 3)
- **Pooling**: Npgsql connection pooling reduces connection overhead
- **Workload Identity**: Recommended over service account keys (Phase 3 setup)
- **Developer Access**: Auth Proxy requires credentials (Phase 2.7)
- **CI/CD Access**: Cloud Build needs Flyway credentials for migrations
- **Secret Versioning**: Secret Manager maintains version history (rollback capability)

---

## Time Estimate

**Planning + Configuration**: 25-30 minutes
- 10 min: Document 9 secret specifications with JSON structure
- 5 min: Define rotation strategy and architecture
- 5 min: Plan IAM bindings (Workload Identity, developers, CI/CD)
- 5 min: Design terraform module structure

---

**Next Phase**: 2.6 - Plan IAM Bindings
