# Phase 2.7: Deploy Secrets

**Phase**: 2.7 (Secret Management - Deployment)
**Duration**: 5-8 minutes
**Type**: Implementation
**Status**: Ready for Execution

---

## Execution Tool

**Use WARP for this phase** - Running terraform commands only, no file editing.

---

## Objective

Deploy Secret Manager secrets for AlloyDB credentials to the environment. Stores password, connection string, and connection name for use by Flyway and applications.

## Prerequisites

✅ Phase 2.6 completed (secrets.tf configuration created)
✅ `pcc-app-shared-infra` repository with secrets.tf
✅ AlloyDB cluster deployed (Phase 2.4)
✅ Terraform initialized in pcc-app-shared-infra

---

## Working Directory

```bash
cd ~/pcc/infra/pcc-app-shared-infra/terraform
```

---

## Step 1: Format Configuration

```bash
terraform fmt
```

**Expected Output**:
```
secrets.tf
variables.tf
terraform.tfvars.example
```

**Purpose**: Ensure consistent code formatting

---

## Step 2: Validate Configuration

```bash
terraform validate
```

**Expected Output**:
```
Success! The configuration is valid.
```

**If validation fails**:
- Check syntax errors in secrets.tf
- Verify module source path is correct
- Ensure all required variables are defined

---

## Step 3: Generate Strong Password

```bash
# Generate 24-character password and store in environment variable
export TF_VAR_alloydb_password="$(openssl rand -base64 24)"

# Verify password is set (first 5 characters only)
echo "Password set: ${TF_VAR_alloydb_password:0:5}..."
```

**Expected Output**:
```
Password set: Ab3Xy...
```

**Important**:
- Password is 24 characters, base64 encoded
- Stored in environment variable (not committed to git)
- Meets 16-character minimum requirement

---

## Step 4: Generate Deployment Plan

```bash
terraform plan -var="environment=devtest" -out=secrets.tfplan
```

**Expected Resources**:
```
Terraform will perform the following actions:

  # module.alloydb_password.google_secret_manager_secret.secret will be created
  + resource "google_secret_manager_secret" "secret" {
      + secret_id = "alloydb-devtest-password"
      + project   = "pcc-prj-app-devtest"
      + rotation {
          + rotation_period = "7776000s"
        }
      ...
    }

  # module.alloydb_password.google_secret_manager_secret_version.secret_version will be created
  + resource "google_secret_manager_secret_version" "secret_version" {
      + secret_data = (sensitive value)
      ...
    }

  # module.alloydb_connection_string.google_secret_manager_secret.secret will be created
  + resource "google_secret_manager_secret" "secret" {
      + secret_id = "alloydb-devtest-connection-string"
      + project   = "pcc-prj-app-devtest"
      ...
    }

  # module.alloydb_connection_string.google_secret_manager_secret_version.secret_version will be created
  + resource "google_secret_manager_secret_version" "secret_version" {
      + secret_data = (sensitive value)
      ...
    }

  # module.alloydb_connection_name.google_secret_manager_secret.secret will be created
  + resource "google_secret_manager_secret" "secret" {
      + secret_id = "alloydb-devtest-connection-name"
      + project   = "pcc-prj-app-devtest"
      ...
    }

  # module.alloydb_connection_name.google_secret_manager_secret_version.secret_version will be created
  + resource "google_secret_manager_secret_version" "secret_version" {
      + secret_data = (sensitive value)
      ...
    }

Plan: 6 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + alloydb_connection_name_secret_id     = "alloydb-devtest-connection-name"
  + alloydb_connection_name_secret_name   = (known after apply)
  + alloydb_connection_string_secret_id   = "alloydb-devtest-connection-string"
  + alloydb_connection_string_secret_name = (known after apply)
  + alloydb_password_secret_id            = "alloydb-devtest-password"
  + alloydb_password_secret_name          = (known after apply)
```

**Verify**:
- 6 resources to add (3 secrets + 3 versions)
- Secret IDs include environment: `alloydb-devtest-*`
- Rotation period: 7776000s (90 days) for password and connection string
- No rotation for connection name
- 6 new outputs
- Secret data is marked as sensitive

---

## Step 5: Apply Deployment Plan

```bash
terraform apply secrets.tfplan
```

**Expected Duration**: 1-2 minutes

**Progress Indicators**:
```
module.alloydb_password.google_secret_manager_secret.secret: Creating...
module.alloydb_password.google_secret_manager_secret.secret: Creation complete after 2s
module.alloydb_password.google_secret_manager_secret_version.secret_version: Creating...
module.alloydb_password.google_secret_manager_secret_version.secret_version: Creation complete after 1s

module.alloydb_connection_string.google_secret_manager_secret.secret: Creating...
module.alloydb_connection_string.google_secret_manager_secret.secret: Creation complete after 2s
module.alloydb_connection_string.google_secret_manager_secret_version.secret_version: Creating...
module.alloydb_connection_string.google_secret_manager_secret_version.secret_version: Creation complete after 1s

module.alloydb_connection_name.google_secret_manager_secret.secret: Creating...
module.alloydb_connection_name.google_secret_manager_secret.secret: Creation complete after 2s
module.alloydb_connection_name.google_secret_manager_secret_version.secret_version: Creating...
module.alloydb_connection_name.google_secret_manager_secret_version.secret_version: Creation complete after 1s

Apply complete! Resources: 6 added, 0 changed, 0 destroyed.

Outputs:

alloydb_connection_name_secret_id = "alloydb-devtest-connection-name"
alloydb_connection_name_secret_name = "projects/pcc-prj-app-devtest/secrets/alloydb-devtest-connection-name"
alloydb_connection_string_secret_id = "alloydb-devtest-connection-string"
alloydb_connection_string_secret_name = "projects/pcc-prj-app-devtest/secrets/alloydb-devtest-connection-string"
alloydb_password_secret_id = "alloydb-devtest-password"
alloydb_password_secret_name = "projects/pcc-prj-app-devtest/secrets/alloydb-devtest-password"
```

**Success Indicators**:
- ✅ "Apply complete! Resources: 6 added"
- ✅ All 6 outputs displayed
- ✅ No errors in terraform output

---

## Step 6: Verify Secrets Deployment

### List Secrets
```bash
gcloud secrets list \
  --project=pcc-prj-app-devtest \
  --filter="name:alloydb"
```

**Expected Output**:
```
NAME                                     CREATED              REPLICATION_POLICY  LOCATIONS
alloydb-devtest-connection-name          2025-01-20T10:30:00  automatic           -
alloydb-devtest-connection-string        2025-01-20T10:30:00  automatic           -
alloydb-devtest-password                 2025-01-20T10:30:00  automatic           -
```

### Describe Password Secret
```bash
gcloud secrets describe alloydb-devtest-password \
  --project=pcc-prj-app-devtest
```

**Expected Output**:
```
createTime: '2025-01-20T10:30:00.000000Z'
labels:
  database: alloydb
  environment: devtest
  managed_by: terraform
  purpose: database-credentials
name: projects/pcc-prj-app-devtest/secrets/alloydb-devtest-password
replication:
  automatic: {}
rotation:
  nextRotationTime: '2025-04-20T10:30:00.000000Z'
  rotationPeriod: 7776000s
```

### Verify Secret Version
```bash
gcloud secrets versions list alloydb-devtest-password \
  --project=pcc-prj-app-devtest
```

**Expected Output**:
```
NAME  STATE    CREATED              DESTROYED
1     ENABLED  2025-01-20T10:30:00  -
```

### Test Secret Access (Verify You Have Access)
```bash
# Access password secret (should succeed for you)
gcloud secrets versions access latest \
  --secret=alloydb-devtest-password \
  --project=pcc-prj-app-devtest

# Access connection string (should succeed)
gcloud secrets versions access latest \
  --secret=alloydb-devtest-connection-string \
  --project=pcc-prj-app-devtest
```

**Expected Output**:
- Password: 24-character base64 string
- Connection string: `postgresql://postgres:PASSWORD@IP:5432/client_api_db`

---

## Validation Checklist

- [ ] Terraform plan shows 6 resources to add
- [ ] Terraform apply completed successfully
- [ ] 3 secrets created: password, connection-string, connection-name
- [ ] 3 secret versions created (1 per secret)
- [ ] All secrets include "devtest" in name
- [ ] Password secret has rotation policy (90 days)
- [ ] Connection string secret has rotation policy (90 days)
- [ ] Connection name secret has NO rotation policy
- [ ] 6 outputs available
- [ ] Secrets visible via `gcloud secrets list`
- [ ] Secret versions state: ENABLED
- [ ] No errors in terraform or gcloud output

---

## Secret Verification

### Password Secret
```bash
gcloud secrets describe alloydb-devtest-password \
  --project=pcc-prj-app-devtest \
  --format="value(rotation.rotationPeriod)"
```
**Expected**: `7776000s` (90 days)

### Connection String Secret
```bash
# Verify format (should show postgresql:// connection string)
gcloud secrets versions access latest \
  --secret=alloydb-devtest-connection-string \
  --project=pcc-prj-app-devtest | head -c 50
```
**Expected**: `postgresql://postgres:...`

### Connection Name Secret
```bash
# Verify format (should show PROJECT:REGION:CLUSTER:INSTANCE)
gcloud secrets versions access latest \
  --secret=alloydb-devtest-connection-name \
  --project=pcc-prj-app-devtest
```
**Expected**: `pcc-prj-app-devtest:us-east4:pcc-alloydb-devtest:primary`

---

## Troubleshooting

### Issue: "Variable alloydb_password not set"
**Resolution**: Set password via environment variable
```bash
export TF_VAR_alloydb_password="$(openssl rand -base64 24)"
```

### Issue: "Secret already exists"
**Resolution**: Import existing secret or use different secret_id
```bash
terraform import module.alloydb_password.google_secret_manager_secret.secret \
  projects/pcc-prj-app-devtest/secrets/alloydb-devtest-password
```

### Issue: "Permission denied: Secret Manager API"
**Resolution**: Verify API is enabled and permissions are granted
```bash
gcloud services list --enabled \
  --project=pcc-prj-app-devtest \
  --filter="name:secretmanager.googleapis.com"
```

### Issue: "Invalid connection string format"
**Resolution**: Verify AlloyDB IP address is available
```bash
terraform output alloydb_primary_instance_ip
```

---

## Security Notes

### Password Management
- Password is stored in environment variable during deployment
- After deployment, retrieve from Secret Manager
- Never log or display passwords in plaintext
- Use `terraform output -json` to avoid displaying sensitive values

### Access Control
Phase 2.8 will add IAM bindings to grant access to:
- Flyway service account (for migrations)
- Application service accounts (for runtime)
- DevOps group (for management)

Until then, only your user account has access.

---

## Post-Deployment Actions

**DO NOT PROCEED** until:
- ✅ All 3 secrets are ENABLED
- ✅ All 6 outputs are populated
- ✅ Secret versions are accessible

**Next Steps**:
1. **Phase 2.8**: Add IAM bindings for secret access
2. **Phase 2.10**: Configure Flyway to use secrets
3. **Phase 2.12**: Validate end-to-end connectivity

---

## References

- **Secret Manager CLI**: https://cloud.google.com/sdk/gcloud/reference/secrets
- **Secret Rotation**: https://cloud.google.com/secret-manager/docs/rotation
- **PostgreSQL Connection Strings**: https://www.postgresql.org/docs/current/libpq-connect.html

---

## Time Estimate

- **Format**: 1 minute
- **Validate**: 1 minute
- **Generate password**: 1 minute
- **Generate plan**: 1-2 minutes
- **Apply plan**: 1-2 minutes (Secret Manager provisioning)
- **Verify deployment**: 2-3 minutes
- **Total**: 5-8 minutes

---

**Status**: Ready for execution
**Next**: Phase 2.8 - Create IAM Configuration
