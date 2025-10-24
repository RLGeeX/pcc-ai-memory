# Phase 2.8: Create IAM Configuration

**Phase**: 2.8 (Security - IAM Configuration Files)
**Duration**: 18-22 minutes
**Type**: Implementation
**Status**: Ready for Execution

---

## Execution Tool

**Use Claude Code for this phase** - Creating terraform configuration files only, no CLI commands.

---

## Objective

Create `iam.tf` configuration file with service accounts and IAM bindings for AlloyDB and Secret Manager access. Implements principle of least privilege with resource-specific permissions.

## Prerequisites

✅ Phase 2.4 completed (AlloyDB cluster deployed)
✅ Phase 2.7 completed (secrets created)
✅ `pcc-app-shared-infra` repository available

---

## IAM Strategy

**Principle of Least Privilege**:
- Grant minimum permissions required for each service account
- No broad project-level roles
- Resource-specific bindings where possible
- Separate service accounts for different purposes

**Service Accounts**:
1. **Flyway Service Account** (`flyway-${var.environment}-sa@pcc-prj-app-${var.environment}.iam.gserviceaccount.com`)
   - Access: Database password secret, AlloyDB cluster
   - Purpose: Run database migrations

2. **Application Service Account** (`client-api-${var.environment}-sa@pcc-prj-app-${var.environment}.iam.gserviceaccount.com`)
   - Access: Connection string secret, AlloyDB instance
   - Purpose: Application runtime database access

---

## File Location

**Repository**: `pcc-app-shared-infra`
**File**: `terraform/iam.tf` (create new file)

---

## Step 1: Create Service Accounts

**File**: `pcc-app-shared-infra/terraform/iam.tf`

```hcl
# Service Accounts for AlloyDB Access
# Environment-specific configuration using variable

# Flyway Migration Service Account
resource "google_service_account" "flyway" {
  project      = "pcc-prj-app-${var.environment}"
  account_id   = "flyway-${var.environment}-sa"
  display_name = "Flyway Database Migration Service Account - ${title(var.environment)}"
  description  = "Service account for running Flyway database migrations against AlloyDB in ${var.environment} environment"
}

# Client API Application Service Account
resource "google_service_account" "client_api" {
  project      = "pcc-prj-app-${var.environment}"
  account_id   = "client-api-${var.environment}-sa"
  display_name = "Client API Application Service Account - ${title(var.environment)}"
  description  = "Service account for client API runtime access to AlloyDB in ${var.environment} environment"
}
```

**Key Configuration**:
- Uses `${var.environment}` for dynamic service account naming
- Environment-specific descriptions for clarity
- Follows naming pattern: `{purpose}-${environment}-sa`

---

## Step 2: Grant Secret Manager Access

**File**: `pcc-app-shared-infra/terraform/iam.tf`

**Append to existing file**:

```hcl
# Secret Manager IAM Bindings

# Grant Flyway SA access to database password secret
resource "google_secret_manager_secret_iam_member" "flyway_password_access" {
  project   = "pcc-prj-app-${var.environment}"
  secret_id = module.alloydb_password.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.flyway.email}"
}

# Grant Flyway SA access to connection name secret
resource "google_secret_manager_secret_iam_member" "flyway_connection_name_access" {
  project   = "pcc-prj-app-${var.environment}"
  secret_id = module.alloydb_connection_name.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.flyway.email}"
}

# Grant Client API SA access to connection string secret
resource "google_secret_manager_secret_iam_member" "client_api_connection_string_access" {
  project   = "pcc-prj-app-${var.environment}"
  secret_id = module.alloydb_connection_string.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.client_api.email}"
}

# Grant Client API SA access to connection name secret
resource "google_secret_manager_secret_iam_member" "client_api_connection_name_access" {
  project   = "pcc-prj-app-${var.environment}"
  secret_id = module.alloydb_connection_name.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.client_api.email}"
}
```

**Access Pattern**:
- Flyway SA: Password + connection name (for migrations)
- Client API SA: Connection string + connection name (for runtime)
- Per-secret bindings (not project-wide)

---

## Step 3: Grant AlloyDB Cluster Access

**File**: `pcc-app-shared-infra/terraform/iam.tf`

**Append to existing file**:

```hcl
# AlloyDB Cluster IAM Bindings

# Grant Flyway SA client access to AlloyDB cluster
resource "google_alloydb_cluster_iam_member" "flyway_cluster_client" {
  project  = "pcc-prj-app-${var.environment}"
  location = "us-east4"
  cluster  = module.alloydb.cluster_id
  role     = "roles/alloydb.client"
  member   = "serviceAccount:${google_service_account.flyway.email}"
}

# Grant Client API SA client access to AlloyDB cluster
resource "google_alloydb_cluster_iam_member" "client_api_cluster_client" {
  project  = "pcc-prj-app-${var.environment}"
  location = "us-east4"
  cluster  = module.alloydb.cluster_id
  role     = "roles/alloydb.client"
  member   = "serviceAccount:${google_service_account.client_api.email}"
}
```

**Purpose**: Allow database connections via Auth Proxy or PSC

---

## Step 4: Grant AlloyDB Instance Access

**File**: `pcc-app-shared-infra/terraform/iam.tf`

**Append to existing file**:

```hcl
# AlloyDB Instance IAM Bindings

# Grant Flyway SA viewer access to primary instance
resource "google_alloydb_instance_iam_member" "flyway_instance_viewer" {
  project  = "pcc-prj-app-${var.environment}"
  location = "us-east4"
  cluster  = module.alloydb.cluster_id
  instance = module.alloydb.primary_instance_id
  role     = "roles/alloydb.viewer"
  member   = "serviceAccount:${google_service_account.flyway.email}"
}

# Grant Client API SA viewer access to primary instance
resource "google_alloydb_instance_iam_member" "client_api_instance_viewer" {
  project  = "pcc-prj-app-${var.environment}"
  location = "us-east4"
  cluster  = module.alloydb.cluster_id
  instance = module.alloydb.primary_instance_id
  role     = "roles/alloydb.viewer"
  member   = "serviceAccount:${google_service_account.client_api.email}"
}
```

**Purpose**: View instance metadata (IP, connection name, state)

---

## Step 5: Add Outputs

**File**: `pcc-app-shared-infra/terraform/iam.tf`

**Append to existing file**:

```hcl
# Outputs for Phase 2.10 (Flyway configuration)

output "flyway_service_account_email" {
  description = "Email of Flyway service account (for future Cloud Build integration)"
  value       = google_service_account.flyway.email
}

output "flyway_service_account_unique_id" {
  description = "Unique ID of Flyway service account"
  value       = google_service_account.flyway.unique_id
}

output "client_api_service_account_email" {
  description = "Email of Client API service account (for future application runtime)"
  value       = google_service_account.client_api.email
}

output "client_api_service_account_unique_id" {
  description = "Unique ID of Client API service account"
  value       = google_service_account.client_api.unique_id
}
```

**Purpose**: These service account emails reserved for future use (Cloud Build, application runtime)

---

## Validation Checklist

- [ ] `iam.tf` created in pcc-app-shared-infra/terraform/
- [ ] 2 service accounts created with environment-specific names
- [ ] Service account IDs use pattern: `{purpose}-${environment}-sa`
- [ ] 4 Secret Manager IAM bindings defined
- [ ] 2 AlloyDB cluster IAM bindings defined
- [ ] 2 AlloyDB instance IAM bindings defined
- [ ] 4 outputs defined
- [ ] All resources reference `module.alloydb` (not `module.alloydb_devtest`)
- [ ] No syntax errors (manual review)

---

## IAM Roles Explained

### roles/secretmanager.secretAccessor
**Permissions**: Read secret versions
**Purpose**: Allow service accounts to fetch database credentials
**Scope**: Per-secret (not project-wide)

**Granted To**:
- Flyway SA: Password secret + connection name
- Client API SA: Connection string + connection name

---

### roles/alloydb.client
**Permissions**: Connect to AlloyDB instances
**Purpose**: Allow database connections via Auth Proxy or PSC
**Scope**: Per-cluster

**Granted To**:
- Flyway SA: For migrations
- Client API SA: For application queries

---

### roles/alloydb.viewer
**Permissions**: View instance metadata
**Purpose**: Discover instance IP, connection name, state
**Scope**: Per-instance

**Granted To**:
- Flyway SA: View primary instance
- Client API SA: View primary instance

---

## Security Best Practices

### Service Account Keys
❌ **Never create service account keys**
✅ **Use Workload Identity instead** (Phase 2.10)

**Why**: Keys are long-lived credentials that can be stolen. Workload Identity provides automatic, short-lived tokens.

### Principle of Least Privilege
- Grant `roles/secretmanager.secretAccessor` per-secret (not project-wide)
- Grant `roles/alloydb.client` per-cluster (not project-wide)
- Grant `roles/alloydb.viewer` per-instance (not cluster-wide)

### Separation of Concerns
- **Flyway SA**: Migration-only access (password secret)
- **Client API SA**: Runtime-only access (connection string secret)
- **NO shared service accounts** between applications

---

## Environment-Specific Service Accounts

### Devtest Environment
```
flyway-devtest-sa@pcc-prj-app-devtest.iam.gserviceaccount.com
client-api-devtest-sa@pcc-prj-app-devtest.iam.gserviceaccount.com
```

### Dev Environment
```
flyway-dev-sa@pcc-prj-app-dev.iam.gserviceaccount.com
client-api-dev-sa@pcc-prj-app-dev.iam.gserviceaccount.com
```

### Staging Environment
```
flyway-staging-sa@pcc-prj-app-staging.iam.gserviceaccount.com
client-api-staging-sa@pcc-prj-app-staging.iam.gserviceaccount.com
```

---

## Local Flyway Execution (Phase 2.11)

**Flyway Authentication**: Developers use their own gcloud credentials

**NO Workload Identity binding needed** - Flyway runs locally on developer's machine, not in Kubernetes.

**Authentication flow**:
1. Developer authenticates: `gcloud auth login`
2. Flyway uses Auth Proxy (local process)
3. Auth Proxy uses developer's gcloud credentials
4. Secrets fetched via developer's IAM permissions

**Future (Phase 4+)**: When Flyway moves to Cloud Build pipeline, will use Cloud Build service account (not Workload Identity).

---

## Optional: Developer Access (Development Only)

For local development, developers can access secrets/database with:

```hcl
# Grant developer group access to secrets (development only)
resource "google_secret_manager_secret_iam_member" "developers_password_access" {
  project   = "pcc-prj-app-${var.environment}"
  secret_id = module.alloydb_password.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "group:developers@portcon.com"
}

# Grant developer group AlloyDB client access
resource "google_alloydb_cluster_iam_member" "developers_cluster_client" {
  project  = "pcc-prj-app-${var.environment}"
  location = "us-east4"
  cluster  = module.alloydb.cluster_id
  role     = "roles/alloydb.client"
  member   = "group:developers@portcon.com"
}
```

**Important**: Only add if local development requires direct database access

---

## Next Phase Dependencies

**Phase 2.9** will:
- Run terraform fmt, validate, and plan
- Verify configuration is ready to deploy

**Phase 2.10** will:
- Create SQL migration scripts in `pcc-client-api` repository
- Create Flyway configuration file
- NO Kubernetes manifests (Flyway runs locally, not in K8s)

**Phase 2.11** will:
- Execute Flyway migrations locally using developer's gcloud credentials
- Verify database schema created successfully

---

## References

- **Service Accounts**: https://cloud.google.com/iam/docs/service-accounts
- **AlloyDB IAM**: https://cloud.google.com/alloydb/docs/manage-iam-authn
- **Secret Manager IAM**: https://cloud.google.com/secret-manager/docs/access-control
- **AlloyDB Auth Proxy**: https://cloud.google.com/alloydb/docs/auth-proxy/overview

---

## Time Estimate

- **Create service accounts**: 3-4 minutes
- **Add Secret Manager IAM bindings**: 6-8 minutes (4 bindings)
- **Add AlloyDB cluster IAM bindings**: 4-5 minutes (2 bindings)
- **Add AlloyDB instance IAM bindings**: 4-5 minutes (2 bindings)
- **Add outputs**: 3-4 minutes (4 outputs)
- **Total**: 18-22 minutes

---

**Status**: Ready for execution
**Next**: Phase 2.9 - Deploy IAM Bindings
