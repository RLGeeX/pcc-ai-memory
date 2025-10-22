# Phase 2.5: Plan Secret Manager & Credential Rotation

**Phase**: 2.5 (AlloyDB Infrastructure - Secrets Management)
**Duration**: 25-30 minutes
**Type**: Planning + Configuration
**Status**: 📋 Planning (Not Started)
**Date**: TBD (10/20+)

---

## Objective

Design Secret Manager configuration for AlloyDB database credentials, including 1 service user (pcc-client-api), admin users, rotation strategy, and IAM bindings for secure access.

## Prerequisites

✅ Phase 2.4 completed (1 database planned)
✅ Understanding of Secret Manager concepts
✅ Database user strategy from Phase 2.4
✅ Workload Identity configuration (Phase 3 reference)

---

## Secret Manager Design

### Overview

**Project**: `pcc-prj-app-devtest`
**Total Secrets**: 3
- 1 service user (pcc-client-api) credential
- 1 admin user credential (superuser)
- 1 Flyway user credential (migrations)

**Rotation**: 30-90 day automatic rotation
**Access**: Workload Identity (GKE service accounts) + Developer group

---

## Secret Specifications

### 1. Database Service User Secrets

**Pattern**: `{service}-db-credentials-{env}`

#### client-api-db-credentials-devtest
```json
{
  "connection_string": "Host=10.28.48.10;Port=5432;Database=client_api_db_devtest;Username=client_api_user;Password=<password>;Pooling=true;MinPoolSize=5;MaxPoolSize=20;Connection Idle Lifetime=300;Connection Lifetime=1800;SSL Mode=Require;Trust Server Certificate=false"
}
```

**Permissions**: Read-write on `client_api_db_devtest`

**Note**: Additional service user secrets will be created in Phase 10 when remaining services are deployed.

---

### 2. Admin User Secret

#### alloydb-admin-credentials-devtest
```json
{
  "connection_string": "Host=10.28.48.10;Port=5432;Username=pcc_admin;Password=<password>;Database=postgres;SSL Mode=Require;Trust Server Certificate=false"
}
```

**Permissions**: Database administration (CREATEDB, CREATEROLE, all privileges on application databases)
**Usage**: Manual administration, emergency access, schema changes
**Note**: NOT a PostgreSQL SUPERUSER - uses granular privileges for security

---

### 3. Flyway User Secret

#### alloydb-flyway-credentials-devtest
```json
{
  "connection_string": "Host=10.28.48.10;Port=5432;Username=flyway_user;Password=<password>;SSL Mode=Require;Trust Server Certificate=false"
}
```

**Permissions**: Schema management (CREATE, ALTER, DROP) on 1 database (client_api_db_devtest)
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
# Python-based generation with guaranteed character diversity
python3 -c "import secrets, string; charset = string.ascii_letters + string.digits + '!@#\$%^&*()-_=+'; print(''.join(secrets.choice(charset) for _ in range(32)))"
```

---

## Terraform Configuration

### Secret Manager Resources

**Module Location**: `pcc-tf-library/modules/secret-manager-database/`
**Caller**: `pcc-app-shared-infra/terraform/secrets.tf`

#### Module Call (Example)

```hcl
terraform {
  backend "gcs" {
    bucket         = "pcc-terraform-state-devtest"
    prefix         = "secrets"
    encryption_key = "projects/pcc-prj-kms/locations/us-central1/keyRings/terraform/cryptoKeys/state"
  }
}

module "alloydb_secrets_devtest" {
  source = "git::https://github.com/your-org/pcc-tf-library.git//modules/secret-manager-database?ref=v1.0.0"

  project_id  = "pcc-prj-app-devtest"
  environment = "devtest"

  # Database connection info (from Phase 2.3 outputs)
  alloydb_host = module.alloydb_cluster_devtest.primary_ip_address
  alloydb_port = 5432

  # Service user secrets (1 microservice: pcc-client-api)
  service_secrets = [
    {
      name     = "client-api-db-credentials-devtest"
      username = "client_api_user"
      database = "client_api_db_devtest"
    }
  ]

  # Note: Additional service secrets will be added in Phase 10

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
| `pcc-client-api-sa` | `client-api-db-credentials-devtest` | `roles/secretmanager.secretAccessor` |

**Note**: Workload Identity setup in Phase 3 (Kubernetes deployment)
**Note**: Additional service account bindings created in Phase 10 when remaining services are deployed

---

### Developer Access

**Group**: `gcp-developers@pcconnect.ai`
**Permission**: `roles/secretmanager.secretAccessor` (read-only)
**Scope**: Service user secrets ONLY (e.g., client-api-db-credentials-devtest)

**Rationale**: Developers need credentials for local testing with Auth Proxy (Phase 2.7)
**Security Note**: Admin credentials accessible only to `gcp-devops@pcconnect.ai` group (least privilege)

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

### Kubernetes Secret Injection via Secrets Store CSI Driver

**Method**: Secrets Store CSI Driver with GCP provider (recommended for security)

**Secret Provider Class**:
```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: client-api-db-credentials
  namespace: devtest
spec:
  provider: gcp
  parameters:
    secrets: |
      - resourceName: "projects/pcc-prj-app-devtest/secrets/client-api-db-credentials-devtest/versions/latest"
        path: "connection_string"
```

**Pod Volume Mount** (file-based, most secure):
```yaml
volumes:
  - name: db-credentials
    csi:
      driver: secrets-store.csi.k8s.io
      readOnly: true
      volumeAttributes:
        secretProviderClass: "client-api-db-credentials"
volumeMounts:
  - name: db-credentials
    mountPath: /secrets/db
    readOnly: true
```

**Application Code** (.NET):
```csharp
// Read connection string from mounted file
var connectionString = File.ReadAllText("/secrets/db/connection_string");
```

**Security Benefits**:
- No Kubernetes Secret resource created (direct access to Secret Manager)
- Secrets never stored in etcd
- Automatic refresh when secrets rotate
- Workload Identity authentication (no service account keys)

---

## Tasks (Planning + Configuration)

1. **Secret Design**:
   - [x] Document 3 secret specifications
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
- Phase 2.4: Database user list (1 service user: pcc-client-api)
- Phase 2.3: AlloyDB IP address (for connection strings)

**Downstream**:
- Phase 2.6: IAM bindings for secret access
- Phase 2.7: Flyway uses flyway_user credentials
- Phase 3: Kubernetes workloads access secrets via Workload Identity

---

## Validation Criteria

- [x] 3 secrets designed (1 service (pcc-client-api), 1 admin, 1 flyway)
- [x] JSON structure defined for all secrets
- [x] Connection strings include Npgsql pooling parameters
- [x] Rotation strategy documented (90 days)
- [x] IAM bindings planned (Workload Identity + developers)
- [x] Terraform module structure defined

---

## Deliverables

- [x] Secret Manager design document (this file)
- [x] 3 secret specifications with JSON structure
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

- **Password Generation**: Use Python-based strong random passwords (32 chars, high entropy, mixed character types)
- **Rotation**: Automatic rotation requires Cloud Function + Cloud Scheduler (Phase 3)
- **Pooling**: Npgsql connection pooling reduces connection overhead
- **Workload Identity**: Recommended over service account keys (Phase 3 setup)
- **Developer Access**: Auth Proxy requires credentials (Phase 2.7) - service secrets only, NOT admin
- **CI/CD Access**: Cloud Build needs Flyway credentials for migrations
- **Secret Versioning**: Secret Manager maintains version history (rollback capability)
- **Audit Logging**: Enable Cloud Audit Logs for Secret Manager (DATA_READ + DATA_WRITE) with 90-day retention
- **State Encryption**: Terraform state stored in GCS with customer-managed encryption keys (CMEK)
- **K8s Integration**: Secrets Store CSI Driver with GCP provider (no service account keys, automatic rotation)
- **Admin Privileges**: pcc_admin uses granular privileges (CREATEDB, CREATEROLE), NOT PostgreSQL SUPERUSER
- **SSL/TLS**: All connections require SSL Mode=Require with server certificate validation

---

## Time Estimate

**Planning + Configuration**: 25-30 minutes
- 10 min: Document 3 secret specifications with JSON structure
- 5 min: Define rotation strategy and architecture
- 5 min: Plan IAM bindings (Workload Identity, developers, CI/CD)
- 5 min: Design terraform module structure

---

**Next Phase**: 2.6 - Plan IAM Bindings
