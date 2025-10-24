# Phase 2.7: Plan Developer Access & Flyway

**Phase**: 2.7 (AlloyDB Infrastructure - Developer Tools & Migrations)
**Duration**: 25-30 minutes
**Type**: Planning + Documentation
**Status**: 📋 Planning (Not Started)
**Date**: TBD (10/20+)

---

## Objective

Design AlloyDB Auth Proxy setup for developer local access, and document Flyway migration strategy for CI/CD-based schema management (not terraform-managed).

## Prerequisites

✅ Phase 2.6 completed (IAM bindings designed)
✅ Phase 2.5 completed (credentials in Secret Manager)
✅ Understanding of AlloyDB Auth Proxy
✅ Understanding of Flyway migrations

---

## Part A: AlloyDB Auth Proxy for Developers

### Overview

**Purpose**: Enable secure local database access for developers
**Authentication**: IAM-based (no password needed)
**Connectivity**: Private IP via Auth Proxy tunnel
**Use Cases**: Local testing, schema exploration, manual queries

---

### Auth Proxy Architecture

```
Developer Workstation
    ↓
AlloyDB Auth Proxy (local)
    ↓
Google IAM Authentication
    ↓
PSC Endpoint (10.28.48.10)
    ↓
AlloyDB Primary Instance (Google-managed VPC)
```

**Benefits**:
- Encrypted connection (TLS)
- No VPN required
- IAM-based access control
- No hardcoded IPs

---

### Developer Prerequisites

**Requirements**:
1. **gcloud CLI**: Latest version installed
2. **Auth Proxy Binary**: `alloydb-auth-proxy` downloaded
3. **IAM Permission**: `roles/alloydb.client` (Phase 2.6)
4. **Database Credentials**: Service secret only (client-api-db-credentials-devtest) from Secret Manager (Phase 2.5). NOT admin or Flyway credentials (least privilege per Phase 2.6).

**Installation** (macOS/Linux):
```bash
# Download Auth Proxy binary
curl -o alloydb-auth-proxy https://storage.googleapis.com/alloydb-auth-proxy/v1.6.1/alloydb-auth-proxy.darwin.amd64
chmod +x alloydb-auth-proxy
sudo mv alloydb-auth-proxy /usr/local/bin/

# Verify installation
alloydb-auth-proxy --version
```

---

### Auth Proxy Connection String

**Format**: `projects/{project}/locations/{region}/clusters/{cluster}/instances/{instance}`

**Devtest Connection String**:
```
projects/pcc-prj-app-devtest/locations/us-east4/clusters/pcc-alloydb-cluster-devtest/instances/pcc-alloydb-instance-devtest-primary
```

**Terraform Output** (from Phase 2.3):
```hcl
output "alloydb_devtest_primary_connection_string" {
  description = "AlloyDB devtest primary instance connection string (for Auth Proxy)"
  value       = module.alloydb_cluster_devtest.primary_connection_string
  sensitive   = true
}
```

**Retrieve Connection String**:
```bash
cd ~/pcc/infra/pcc-app-shared-infra/terraform
terraform output alloydb_devtest_primary_connection_string
```

---

### Auth Proxy Startup

**Command** (local development):
```bash
alloydb-auth-proxy \
  "projects/pcc-prj-app-devtest/locations/us-east4/clusters/pcc-alloydb-cluster-devtest/instances/pcc-alloydb-instance-devtest-primary" \
  --port=5433
```

**Options**:
- `--port=5433`: Local port (avoid conflict with local PostgreSQL on 5432)
- `--credentials-file`: Optional (uses gcloud default credentials)

**Expected Output**:
```
2025/10/20 10:00:00 Listening on 127.0.0.1:5433
2025/10/20 10:00:00 The AlloyDB Auth Proxy has started successfully
```

---

### Database Connection via Auth Proxy

**Connection Details**:
- **Host**: `127.0.0.1` (local proxy)
- **Port**: `5433` (proxy listening port)
- **Database**: `{db_name}` (e.g., `client_api_db_devtest`)
- **Username**: From Secret Manager (e.g., `client_api_user`)
- **Password**: From Secret Manager
- **Encryption**: SSL/TLS required (enforced in connection string from Secret Manager per Phase 2.5)

**Retrieve Credentials from Secret Manager**:
```bash
# Get client_api_user credentials
gcloud secrets versions access latest \
  --secret=client-api-db-credentials-devtest \
  --project=pcc-prj-app-devtest \
  --format=json | jq -r '.username, .password'
```

**psql Connection** (with SSL enforcement per Phase 2.5):
```bash
psql "host=127.0.0.1 port=5433 dbname=client_api_db_devtest user=client_api_user sslmode=require"
```

**DBeaver/DataGrip Connection**:
- Host: `127.0.0.1`
- Port: `5433`
- Database: `client_api_db_devtest`
- Username: `client_api_user`
- Password: `<from Secret Manager>`
- SSL Mode: require (enable in Advanced/SSL settings)
- SSL Factory: org.postgresql.ssl.DefaultJavaSSLFactory

---

### Developer Workflow

**Daily Workflow**:
1. Start Auth Proxy: `alloydb-auth-proxy "projects/..." --port=5433`
2. Retrieve credentials: `gcloud secrets versions access ...`
3. Connect via psql/DBeaver: `psql -h 127.0.0.1 -p 5433 ...`
4. Run queries, test migrations, explore schema
5. Stop Auth Proxy: `Ctrl+C`

**Alias Setup** (optional, for convenience):
```bash
# Add to ~/.zshrc or ~/.bashrc
alias alloydb-devtest='alloydb-auth-proxy "projects/pcc-prj-app-devtest/locations/us-east4/clusters/pcc-alloydb-cluster-devtest/instances/pcc-alloydb-instance-devtest-primary" --port=5433'

# Usage
alloydb-devtest  # Starts proxy on port 5433
```

**Credential Rotation Note**: Credentials rotate every 90 days (Phase 2.5). If connection fails, re-fetch credentials from Secret Manager using the gcloud command above.

---

### Troubleshooting Auth Proxy

**Issue 1: Permission Denied**
```
Error: Access denied for user ... on resource ...
```

**Solution**: Verify IAM binding (Phase 2.6)
```bash
gcloud projects get-iam-policy pcc-prj-app-devtest \
  --flatten="bindings[].members" \
  --filter="bindings.role:roles/alloydb.client"
```

**Issue 2: Connection Refused**
```
Error: dial tcp 127.0.0.1:5433: connect: connection refused
```

**Solution**: Ensure Auth Proxy is running on correct port

**Issue 3: Credentials Not Found**
```
Error: could not find default credentials
```

**Solution**: Login with gcloud
```bash
gcloud auth application-default login
```

---

## Part B: Flyway Migration Strategy

### Overview

**Purpose**: Create AlloyDB database AND manage schema migrations (tables, indexes, constraints)
**Execution**: CI/CD pipeline (Cloud Build), not terraform
**Version Control**: Flyway SQL migrations in `src/{service}-api/migrations/`
**Authentication**: Flyway user credentials from Secret Manager (Phase 2.5)
**Kubernetes Namespace**: devtest (Workload Identity binding from Phase 2.6)
**Important**: V1 migration creates the database itself (AlloyDB only has default `postgres` DB after Terraform)

---

### Flyway Architecture

```
Developer commits SQL migration
    ↓
Git push to main branch
    ↓
Cloud Build trigger (CI/CD)
    ↓
Retrieve Flyway credentials (Secret Manager)
    ↓
Run Flyway migrate via Auth Proxy
    ↓
Apply migration to AlloyDB
    ↓
Update flyway_schema_history table
```

**Benefits**:
- Version-controlled schema changes
- Automated migration on deploy
- Rollback capability
- Audit trail (flyway_schema_history)

---

### Flyway Migration Files

**Location**: `src/{service}-api/migrations/`
**Naming Convention**: `V{version}__{description}.sql`

**Example** (client-api):
```
src/pcc-client-api/migrations/
├── V1__create_database_and_initial_schema.sql   (Creates DB + initial tables)
├── V2__add_indexes_and_constraints.sql
├── V3__add_audit_columns.sql
└── V4__add_additional_tables.sql
```

---

### Flyway Configuration

**Location**: `src/{service}-api/flyway.conf`

**Example** (client-api):
```properties
# Flyway configuration for client-api devtest

# Connection URL (via Auth Proxy in CI/CD)
# SSL enforced per Phase 2.5 security requirements
flyway.url=jdbc:postgresql://127.0.0.1:5433/client_api_db_devtest?ssl=true&sslmode=require&sslrootcert=verify-full

# Credentials from environment variables (Cloud Build)
flyway.user=${DB_USER}
flyway.password=${DB_PASSWORD}

# Migration settings
flyway.locations=filesystem:./migrations
flyway.schemas=public
flyway.table=flyway_schema_history
flyway.baselineOnMigrate=true
flyway.validateOnMigrate=true

# Retry settings (for transient failures)
flyway.connectRetries=3
flyway.connectRetriesInterval=10

# Security: Minimize logging verbosity to prevent credential exposure
flyway.outputType=json
flyway.logLevel=WARN
```

**Environment Variables** (Cloud Build):
- `DB_USER`: From Secret Manager (`flyway_user`)
- `DB_PASSWORD`: From Secret Manager (Flyway credentials)

---

### Cloud Build Pipeline for Flyway

**Location**: `src/{service}-api/cloudbuild-flyway.yaml`

**Example** (client-api):
```yaml
# Cloud Build pipeline for Flyway migrations (client-api devtest)

steps:
  # Step 1: Download AlloyDB Auth Proxy
  - name: 'gcr.io/cloud-builders/curl'
    args:
      - '-o'
      - 'alloydb-auth-proxy'
      - 'https://storage.googleapis.com/alloydb-auth-proxy/v1.6.1/alloydb-auth-proxy.linux.amd64'
    id: 'download-auth-proxy'

  # Step 2: Make Auth Proxy executable
  - name: 'gcr.io/cloud-builders/docker'
    entrypoint: 'chmod'
    args: ['+x', 'alloydb-auth-proxy']
    id: 'chmod-auth-proxy'

  # Step 3: Start Auth Proxy in background
  - name: 'gcr.io/cloud-builders/docker'
    entrypoint: 'bash'
    args:
      - '-c'
      - |
        ./alloydb-auth-proxy \
          "projects/pcc-prj-app-devtest/locations/us-east4/clusters/pcc-alloydb-cluster-devtest/instances/pcc-alloydb-instance-devtest-primary" \
          --port=5433 &
        sleep 5
    id: 'start-auth-proxy'

  # Step 4: Run Flyway migrate with credentials from Secret Manager
  - name: 'flyway/flyway:9.22'
    entrypoint: 'bash'
    args:
      - '-c'
      - |
        export DB_USER=$(gcloud secrets versions access latest --secret=alloydb-flyway-credentials-devtest --project=pcc-prj-app-devtest --format=json | jq -r '.username')
        export DB_PASSWORD=$(gcloud secrets versions access latest --secret=alloydb-flyway-credentials-devtest --project=pcc-prj-app-devtest --format=json | jq -r '.password')
        flyway -configFiles=/workspace/flyway.conf migrate
    id: 'flyway-migrate'

options:
  logging: CLOUD_LOGGING_ONLY

# IAM service account (Phase 2.6)
serviceAccount: 'projects/pcc-prj-app-devtest/serviceAccounts/pcc-cloudbuild-sa@pcc-prj-app-devtest.iam.gserviceaccount.com'

# Timeout
timeout: '600s'
```

---

### Flyway Baseline (Initial Setup)

**Purpose**: Mark existing schema as baseline (skip V1__initial_schema.sql)

**Command** (after AlloyDB deployment):
```bash
# Start Auth Proxy locally
alloydb-auth-proxy "projects/..." --port=5433

# Run Flyway baseline
flyway -configFiles=flyway.conf baseline -baselineVersion=0

# Apply migrations
flyway -configFiles=flyway.conf migrate
```

**Note**: Baseline run once per database, then CI/CD handles migrations

---

### Flyway Migration Example

**File**: `src/pcc-client-api/migrations/V1__create_database_and_initial_schema.sql`

```sql
-- V1: Create database and initial schema for pcc-client-api
-- Author: PCC Team
-- Date: 2025-10-20

-- Create the database (AlloyDB only has default 'postgres' DB after Terraform deployment)
CREATE DATABASE client_api_db_devtest;

-- Connect to the new database
\c client_api_db_devtest

-- Users table (local auth fallback)
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Sessions table (JWT token tracking)
CREATE TABLE sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash VARCHAR(255) NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_user_id (user_id),
    INDEX idx_expires_at (expires_at)
);

-- Refresh tokens
CREATE TABLE refresh_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash VARCHAR(255) NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_user_id (user_id)
);

-- OAuth provider mappings (Descope)
CREATE TABLE oauth_providers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    provider VARCHAR(50) NOT NULL,
    provider_user_id VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (provider, provider_user_id)
);

-- Grant permissions to service user (client_api_user)
GRANT CONNECT ON DATABASE client_api_db_devtest TO client_api_user;
GRANT USAGE ON SCHEMA public TO client_api_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO client_api_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO client_api_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO client_api_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO client_api_user;
```

**Important Notes**:
- `CREATE DATABASE` must be the first command in V1 migration
- `\c client_api_db_devtest` switches connection to the new database
- All subsequent migrations (V2, V3, etc.) run against `client_api_db_devtest` automatically

---

### Flyway History Table

**Table**: `flyway_schema_history` (auto-created by Flyway)

**Columns**:
- `installed_rank`: Migration order
- `version`: Migration version (e.g., "1", "2", "3")
- `description`: Migration description
- `type`: "SQL" (migration file type)
- `script`: Migration filename
- `checksum`: Migration file hash (for validation)
- `installed_by`: Database user (flyway_user)
- `installed_on`: Timestamp
- `execution_time`: Migration duration (ms)
- `success`: true/false

**Query History**:
```sql
SELECT version, description, installed_on, execution_time, success
FROM flyway_schema_history
ORDER BY installed_rank;
```

---

### Flyway Rollback Strategy

**Approach**: Version-controlled rollback migrations

**Rollback File**: `U{version}__{description}.sql` (undo migration)

**Example**:
```
migrations/
├── V3__add_refresh_tokens.sql  (forward migration)
└── U3__remove_refresh_tokens.sql  (rollback migration)
```

**Rollback Command** (manual):
```bash
flyway -configFiles=flyway.conf undo
```

**Note**: Flyway Pro required for undo (not available in Community Edition)

**Alternative**: Create forward migration to reverse changes (V4__undo_v3.sql)

---

## Tasks (Planning + Documentation)

1. **Auth Proxy Documentation**:
   - [x] Document Auth Proxy installation (macOS/Linux)
   - [x] Document connection string retrieval (terraform output)
   - [x] Document Auth Proxy startup command
   - [x] Document database connection (psql, DBeaver)
   - [x] Document developer workflow
   - [x] Document troubleshooting steps

2. **Flyway Strategy**:
   - [x] Document Flyway architecture (CI/CD execution)
   - [x] Define migration file naming convention
   - [x] Document Flyway configuration (flyway.conf)
   - [x] Document Cloud Build pipeline (cloudbuild-flyway.yaml)
   - [x] Document Flyway baseline setup
   - [x] Provide migration example (V1__initial_schema.sql)

3. **Developer Onboarding**:
   - [x] Create Auth Proxy setup guide
   - [x] Create Flyway migration guide
   - [x] Document common workflows

---

## Dependencies

**Upstream**:
- Phase 2.6: IAM bindings (`alloydb.client` for developers and CI/CD)
- Phase 2.5: Credentials in Secret Manager (service users + flyway_user)
- Phase 2.3: AlloyDB connection string (terraform output)

**Downstream**:
- Phase 2.9: Initial Flyway baseline run (after deployment)
- Phase 3: CI/CD pipeline integration for automatic migrations

---

## Validation Criteria

- [x] Auth Proxy setup documented (installation, connection, workflow)
- [x] Flyway strategy documented (CI/CD, not terraform)
- [x] Migration file naming convention defined
- [x] Cloud Build pipeline example provided
- [x] Flyway baseline strategy documented
- [x] Developer onboarding guide created

---

## Deliverables

- [x] Auth Proxy setup guide (this file, Part A)
- [x] Flyway migration strategy (this file, Part B)
- [x] Cloud Build pipeline example (cloudbuild-flyway.yaml)
- [x] Flyway configuration example (flyway.conf)
- [x] Migration file example (V1__initial_schema.sql)

---

## References

- Phase 2.6 (IAM bindings for Auth Proxy)
- Phase 2.5 (Secret Manager credentials)
- Phase 2.3 (AlloyDB connection string output)
- 🔗 AlloyDB Auth Proxy: https://cloud.google.com/alloydb/docs/auth-proxy/overview
- 🔗 Flyway Documentation: https://flywaydb.org/documentation
- 🔗 Flyway Cloud Build: https://cloud.google.com/build/docs/building/build-containers

---

## Notes

- **Auth Proxy**: Secure local access without VPN
- **IAM Authentication**: No passwords required for Auth Proxy (IAM-based)
- **Flyway Execution**: CI/CD only (not terraform-managed)
- **Database Creation**: V1 migration must create database via `CREATE DATABASE` (Terraform doesn't create databases)
- **Default Database**: AlloyDB clusters only have `postgres` database after Terraform deployment
- **Baseline**: Run once per database after deployment (Phase 2.9)
- **Migration Versioning**: Sequential (V1, V2, V3, ...)
- **Rollback**: Create forward migration (V4__undo_v3.sql) or use Flyway Pro undo
- **Cloud Build**: Retrieves Flyway credentials from Secret Manager
- **Developer Workflow**: Auth Proxy + psql/DBeaver for local testing

---

## Time Estimate

**Planning + Documentation**: 25-30 minutes
- 10 min: Document Auth Proxy setup and workflow
- 10 min: Document Flyway strategy and CI/CD pipeline
- 5 min: Create migration examples
- 5 min: Document developer onboarding

---

**Next Phase**: 2.8 - Validate Terraform
