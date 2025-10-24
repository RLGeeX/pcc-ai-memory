# Phase 2.6: Create Secrets Configuration

**Phase**: 2.6 (Secret Management - Configuration Files)
**Duration**: 12-15 minutes
**Type**: Implementation
**Status**: Ready for Execution

---

## Execution Tool

**Use Claude Code for this phase** - Creating terraform configuration files only, no CLI commands.

---

## Objective

Create `secrets.tf` configuration file that calls the Secret Manager module to store AlloyDB credentials (password, connection string, connection name). Uses module from Phase 2.5 and outputs from Phase 2.3.

## Prerequisites

✅ Phase 0 completed (`secretmanager.googleapis.com` enabled)
✅ Phase 2.4 completed (AlloyDB cluster deployed with outputs)
✅ Phase 2.5 completed (Secret Manager module exists)
✅ `pcc-app-shared-infra` repository available

---

## File Location

**Repository**: `pcc-app-shared-infra`
**File**: `terraform/secrets.tf` (create new file)

---

## Step 1: Create secrets.tf

**File**: `pcc-app-shared-infra/terraform/secrets.tf`

```hcl
# Secret Manager Secrets for AlloyDB
# Stores database credentials and connection information
# Environment-specific configuration using variable

# Database Password Secret
module "alloydb_password" {
  source = "git::https://github.com/portco-connect/pcc-tf-library.git//modules/secret-manager?ref=main"

  project_id  = "pcc-prj-app-${var.environment}"
  secret_id   = "alloydb-${var.environment}-password"
  secret_data = var.alloydb_password # Provided at apply time

  labels = {
    purpose     = "database-credentials"
    environment = var.environment
    database    = "alloydb"
    managed_by  = "terraform"
  }

  # Automatic rotation every 90 days
  rotation_period = 7776000 # 90 days in seconds

  # Automatic replication (multi-region)
  replication_policy = "automatic"
}

# Database Connection String Secret
module "alloydb_connection_string" {
  source = "git::https://github.com/portco-connect/pcc-tf-library.git//modules/secret-manager?ref=main"

  project_id = "pcc-prj-app-${var.environment}"
  secret_id  = "alloydb-${var.environment}-connection-string"

  # Format: postgresql://USER:PASSWORD@IP_ADDRESS:5432/DATABASE_NAME
  # Note: Database name is 'client_api_db' (no environment suffix)
  secret_data = format(
    "postgresql://postgres:%s@%s:5432/client_api_db",
    var.alloydb_password,
    module.alloydb.primary_instance_ip_address
  )

  labels = {
    purpose     = "database-connection"
    environment = var.environment
    database    = "alloydb"
    managed_by  = "terraform"
  }

  # Sync rotation with password (90 days)
  rotation_period = 7776000

  # Automatic replication
  replication_policy = "automatic"

  depends_on = [module.alloydb_password]
}

# Database Connection Name Secret (for Auth Proxy)
module "alloydb_connection_name" {
  source = "git::https://github.com/portco-connect/pcc-tf-library.git//modules/secret-manager?ref=main"

  project_id = "pcc-prj-app-${var.environment}"
  secret_id  = "alloydb-${var.environment}-connection-name"

  # Format: project:region:cluster:instance
  secret_data = module.alloydb.primary_instance_connection_name

  labels = {
    purpose     = "database-metadata"
    environment = var.environment
    database    = "alloydb"
    managed_by  = "terraform"
  }

  # No rotation needed for connection name (static metadata)
  rotation_period = null

  # Automatic replication
  replication_policy = "automatic"
}
```

**Key Configuration**:
- Uses `${var.environment}` for dynamic secret naming
- Database name is `client_api_db` (NO environment suffix)
- Same database name across all environments
- 90-day rotation for password and connection string
- No rotation for connection name (static metadata)

---

## Step 2: Add Variables

**File**: `pcc-app-shared-infra/terraform/variables.tf`

**Append to existing file** (or update if environment variable already exists):

```hcl
# AlloyDB Database Password
# NOTE: Password MUST be generated using the method in Phase 2.7 (openssl rand -base64 32)
# Do NOT manually create passwords - use the approved generation script
variable "alloydb_password" {
  description = "Password for AlloyDB postgres user (generated in Phase 2.7)"
  type        = string
  sensitive   = true
}
```

**Note**: The `environment` variable should already exist from Phase 2.3. If not, add it:

```hcl
variable "environment" {
  description = "Environment name (devtest, dev, staging, prod)"
  type        = string
  default     = "devtest"
}
```

---

## Step 3: Add Outputs

**File**: `pcc-app-shared-infra/terraform/secrets.tf`

**Append to existing file**:

```hcl
# Outputs for Phase 2.8 (IAM bindings) and Phase 2.10 (Flyway)
output "alloydb_password_secret_id" {
  description = "Secret ID for AlloyDB password (for IAM bindings)"
  value       = module.alloydb_password.secret_id
}

output "alloydb_password_secret_name" {
  description = "Full secret name for AlloyDB password"
  value       = module.alloydb_password.secret_name
}

output "alloydb_connection_string_secret_id" {
  description = "Secret ID for connection string (for IAM bindings)"
  value       = module.alloydb_connection_string.secret_id
}

output "alloydb_connection_string_secret_name" {
  description = "Full secret name for connection string"
  value       = module.alloydb_connection_string.secret_name
}

output "alloydb_connection_name_secret_id" {
  description = "Secret ID for connection name (for IAM bindings)"
  value       = module.alloydb_connection_name.secret_id
}

output "alloydb_connection_name_secret_name" {
  description = "Full secret name for connection name"
  value       = module.alloydb_connection_name.secret_name
}
```

**Purpose**: These outputs will be used in:
- **Phase 2.8**: IAM bindings (grant secret access)
- **Phase 2.10**: Flyway configuration (fetch secrets at runtime)

---

## Step 4: Create terraform.tfvars.example

**File**: `pcc-app-shared-infra/terraform/terraform.tfvars.example`

**Create or append**:

```hcl
# Environment Configuration
environment = "devtest" # Change to: dev, staging, prod

# AlloyDB Configuration (see alloydb.tf for options)
alloydb_availability_type   = "ZONAL"         # ZONAL or REGIONAL
alloydb_enable_read_replica = false           # true or false
alloydb_machine_type        = "db-standard-2" # db-standard-2, db-standard-4, etc.
alloydb_pitr_days          = 7                # 7 (devtest/dev), 14+ (staging/prod)

# AlloyDB Database Password
# NOTE: Use Phase 2.7 generation method - do NOT manually create
# Phase 2.7 generates: openssl rand -base64 32 | tr -d "=+/" | cut -c1-32
alloydb_password = "GENERATED_IN_PHASE_2.7"
```

**Important**:
- Password will be generated during Phase 2.7 deployment
- Add `terraform.tfvars` to `.gitignore` (should already exist)
- Never commit actual passwords to git
- Do NOT manually create passwords

---

## Validation Checklist

- [ ] `secrets.tf` created in pcc-app-shared-infra/terraform/
- [ ] 3 module calls (password, connection string, connection name)
- [ ] All secrets use `${var.environment}` in secret_id
- [ ] Database name is `client_api_db` (NO environment suffix)
- [ ] Connection string references `module.alloydb.primary_instance_ip_address`
- [ ] `alloydb_password` variable added to variables.tf
- [ ] Password variable marked sensitive
- [ ] Password generation method documented (Phase 2.7 generates with openssl)
- [ ] 6 outputs defined
- [ ] `terraform.tfvars.example` created with all configuration options
- [ ] No syntax errors (manual review)

---

## Module Call Breakdown

### Password Secret
```hcl
secret_id   = "alloydb-${var.environment}-password"
secret_data = var.alloydb_password  # Provided at apply time
rotation_period = 7776000  # 90 days
```
- Environment-specific: alloydb-devtest-password, alloydb-dev-password, etc.
- Plain password string
- Used by Flyway for migrations
- Rotated every 90 days (best practice)

### Connection String Secret
```hcl
secret_id   = "alloydb-${var.environment}-connection-string"
secret_data = "postgresql://postgres:PASSWORD@IP:5432/client_api_db"
```
- Environment-specific secret ID
- Database name is SAME across all environments: `client_api_db`
- Full PostgreSQL connection string
- Uses password and IP from other resources
- Format: `postgresql://USER:PASSWORD@HOST:PORT/DATABASE`
- Rotated with password (90 days)

### Connection Name Secret
```hcl
secret_id   = "alloydb-${var.environment}-connection-name"
secret_data = "pcc-prj-app-${var.environment}:us-east4:pcc-alloydb-${var.environment}:primary"
```
- Environment-specific: pcc-prj-app-devtest:us-east4:pcc-alloydb-devtest:primary
- Connection name for Auth Proxy
- Format: `PROJECT:REGION:CLUSTER:INSTANCE`
- Static metadata (no rotation needed)

---

## Database Naming Convention

**IMPORTANT**: Database names do NOT include environment suffix

✅ **Correct**:
```
Database: client_api_db
Cluster: pcc-alloydb-devtest (environment in cluster name)
Connection string: postgresql://postgres:pass@ip:5432/client_api_db
```

❌ **Incorrect**:
```
Database: client_api_db_devtest (NO environment suffix in DB name)
```

**Rationale**:
- Differentiation happens at the cluster level
- Same database name across all environments
- Simplifies application configuration
- Each microservice gets its own database in the AlloyDB cluster

---

## Security Considerations

### Password Generation

**IMPORTANT**: Passwords MUST be generated using the approved method in Phase 2.7.

```bash
# Phase 2.7 generates secure 32-character passwords
openssl rand -base64 32 | tr -d "=+/" | cut -c1-32
```

**Why this method:**
- Generates cryptographically secure random data
- Base64 encoding ensures mix of uppercase, lowercase, and numbers
- 32 characters provides 192 bits of entropy
- Automatic compliance with complexity requirements

**Do NOT:**
- ❌ Manually create passwords
- ❌ Use weak passwords like "Password123456789"
- ❌ Reuse passwords from other systems
- ❌ Add custom validation rules (generation ensures security)

### Password Storage
- ❌ Never commit `terraform.tfvars` to git
- ✅ Use environment variable: `export TF_VAR_alloydb_password="..."`
- ✅ Or use terraform workspace secrets
- ✅ Or prompt at apply time: `terraform apply -var="alloydb_password=..."`

### Rotation Policy
- **Database passwords**: 90 days (industry standard)
- **Connection strings**: 90 days (sync with password)
- **Connection names**: No rotation (static metadata)

**Rotation Notification**: Future enhancement can add Pub/Sub topic for rotation alerts

---

## Environment-Specific Secret Examples

### Devtest Environment
```
alloydb-devtest-password
alloydb-devtest-connection-string
alloydb-devtest-connection-name
```

### Dev Environment
```
alloydb-dev-password
alloydb-dev-connection-string
alloydb-dev-connection-name
```

### Staging Environment
```
alloydb-staging-password
alloydb-staging-connection-string
alloydb-staging-connection-name
```

---

## Next Phase Dependencies

**Phase 2.7** will:
- Run terraform fmt, validate, and plan
- Verify configuration is ready to deploy

**Phase 2.8** will:
- Grant `roles/secretmanager.secretAccessor` to Flyway service account
- Grant `roles/secretmanager.secretAccessor` to application service accounts
- Use `secret_id` outputs for IAM bindings

**Phase 2.10** will:
- Reference `alloydb_password_secret_name` in Flyway configuration
- Reference `alloydb_connection_string_secret_name` for application config
- Fetch secrets at runtime for migrations

---

## References

- **Module Source**: `pcc-tf-library/modules/secret-manager/`
- **Secret Manager**: https://cloud.google.com/secret-manager/docs
- **Connection Strings**: https://www.postgresql.org/docs/current/libpq-connect.html#LIBPQ-CONNSTRING
- **Password Best Practices**: https://cloud.google.com/alloydb/docs/manage-users

---

## Time Estimate

- **Create secrets.tf**: 6-8 minutes (3 module calls)
- **Add variables**: 2 minutes
- **Add outputs**: 3-4 minutes (6 outputs)
- **Create tfvars.example**: 2 minutes
- **Total**: 12-15 minutes

---

**Status**: Ready for execution
**Next**: Phase 2.7 - Deploy Secrets
