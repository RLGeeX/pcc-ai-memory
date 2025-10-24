# Phase 2.9: Deploy IAM Bindings

**Phase**: 2.9 (Security - IAM Deployment)
**Duration**: 8-12 minutes
**Type**: Implementation
**Status**: Ready for Execution

---

## Execution Tool

**Use WARP for this phase** - Running terraform and gcloud commands only, no file editing.

---

## Objective

Deploy IAM bindings for AlloyDB and Secret Manager access. Creates service accounts and grants minimum necessary permissions following principle of least privilege.

## Prerequisites

✅ Phase 2.8 completed (iam.tf configuration created)
✅ `pcc-app-shared-infra` repository with iam.tf
✅ AlloyDB cluster deployed (Phase 2.4)
✅ Secrets created (Phase 2.7)
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
iam.tf
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
- Check syntax errors in iam.tf
- Verify module references are correct
- Ensure all secret and cluster IDs exist

---

## Step 3: Generate Deployment Plan

```bash
terraform plan -var="environment=devtest" -out=iam-bindings.tfplan
```

**Expected Resources**:
```
Terraform will perform the following actions:

  # google_service_account.flyway will be created
  + resource "google_service_account" "flyway" {
      + account_id   = "flyway-devtest-sa"
      + display_name = "Flyway Database Migration Service Account - Devtest"
      + email        = (known after apply)
      + project      = "pcc-prj-app-devtest"
      ...
    }

  # google_service_account.client_api will be created
  + resource "google_service_account" "client_api" {
      + account_id   = "client-api-devtest-sa"
      + display_name = "Client API Application Service Account - Devtest"
      + email        = (known after apply)
      + project      = "pcc-prj-app-devtest"
      ...
    }

  # google_secret_manager_secret_iam_member.flyway_password_access will be created
  + resource "google_secret_manager_secret_iam_member" "flyway_password_access" {
      + member    = "serviceAccount:flyway-devtest-sa@pcc-prj-app-devtest.iam.gserviceaccount.com"
      + role      = "roles/secretmanager.secretAccessor"
      + secret_id = "alloydb-devtest-password"
      ...
    }

  # google_secret_manager_secret_iam_member.flyway_connection_name_access will be created
  ...

  # google_secret_manager_secret_iam_member.client_api_connection_string_access will be created
  ...

  # google_secret_manager_secret_iam_member.client_api_connection_name_access will be created
  ...

  # google_alloydb_cluster_iam_member.flyway_cluster_client will be created
  + resource "google_alloydb_cluster_iam_member" "flyway_cluster_client" {
      + cluster  = "pcc-alloydb-devtest"
      + location = "us-east4"
      + member   = "serviceAccount:flyway-devtest-sa@pcc-prj-app-devtest.iam.gserviceaccount.com"
      + role     = "roles/alloydb.client"
      ...
    }

  # google_alloydb_cluster_iam_member.client_api_cluster_client will be created
  ...

  # google_alloydb_instance_iam_member.flyway_instance_viewer will be created
  + resource "google_alloydb_instance_iam_member" "flyway_instance_viewer" {
      + cluster  = "pcc-alloydb-devtest"
      + instance = "primary"
      + location = "us-east4"
      + member   = "serviceAccount:flyway-devtest-sa@pcc-prj-app-devtest.iam.gserviceaccount.com"
      + role     = "roles/alloydb.viewer"
      ...
    }

  # google_alloydb_instance_iam_member.client_api_instance_viewer will be created
  ...

Plan: 10 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + client_api_service_account_email     = (known after apply)
  + client_api_service_account_unique_id = (known after apply)
  + flyway_service_account_email         = (known after apply)
  + flyway_service_account_unique_id     = (known after apply)
```

**Verify**:
- 10 resources to add (2 service accounts + 8 IAM bindings)
- Service account IDs include environment: `flyway-devtest-sa`, `client-api-devtest-sa`
- 4 Secret Manager bindings (2 per SA)
- 2 AlloyDB cluster bindings (1 per SA)
- 2 AlloyDB instance bindings (1 per SA)
- 4 new outputs

---

## Step 4: Apply Deployment Plan

```bash
terraform apply iam-bindings.tfplan
```

**Expected Duration**: 2-3 minutes

**Progress Indicators**:
```
google_service_account.flyway: Creating...
google_service_account.flyway: Creation complete after 2s
google_service_account.client_api: Creating...
google_service_account.client_api: Creation complete after 2s

google_secret_manager_secret_iam_member.flyway_password_access: Creating...
google_secret_manager_secret_iam_member.flyway_password_access: Creation complete after 3s
google_secret_manager_secret_iam_member.flyway_connection_name_access: Creating...
google_secret_manager_secret_iam_member.flyway_connection_name_access: Creation complete after 3s
google_secret_manager_secret_iam_member.client_api_connection_string_access: Creating...
google_secret_manager_secret_iam_member.client_api_connection_string_access: Creation complete after 3s
google_secret_manager_secret_iam_member.client_api_connection_name_access: Creating...
google_secret_manager_secret_iam_member.client_api_connection_name_access: Creation complete after 3s

google_alloydb_cluster_iam_member.flyway_cluster_client: Creating...
google_alloydb_cluster_iam_member.flyway_cluster_client: Creation complete after 5s
google_alloydb_cluster_iam_member.client_api_cluster_client: Creating...
google_alloydb_cluster_iam_member.client_api_cluster_client: Creation complete after 5s

google_alloydb_instance_iam_member.flyway_instance_viewer: Creating...
google_alloydb_instance_iam_member.flyway_instance_viewer: Creation complete after 5s
google_alloydb_instance_iam_member.client_api_instance_viewer: Creating...
google_alloydb_instance_iam_member.client_api_instance_viewer: Creation complete after 5s

Apply complete! Resources: 10 added, 0 changed, 0 destroyed.

Outputs:

client_api_service_account_email = "client-api-devtest-sa@pcc-prj-app-devtest.iam.gserviceaccount.com"
client_api_service_account_unique_id = "123456789012345678901"
flyway_service_account_email = "flyway-devtest-sa@pcc-prj-app-devtest.iam.gserviceaccount.com"
flyway_service_account_unique_id = "123456789012345678902"
```

**Success Indicators**:
- ✅ "Apply complete! Resources: 10 added"
- ✅ All 4 outputs displayed
- ✅ No errors in terraform output

---

## Step 5: Verify Service Accounts

### List Service Accounts
```bash
gcloud iam service-accounts list \
  --project=pcc-prj-app-devtest \
  --filter="email:*-devtest-sa@*"
```

**Expected Output**:
```
DISPLAY NAME                                             EMAIL                                                   DISABLED
Flyway Database Migration Service Account - Devtest       flyway-devtest-sa@pcc-prj-app-devtest.iam...           False
Client API Application Service Account - Devtest          client-api-devtest-sa@pcc-prj-app-devtest.iam...       False
```

### Describe Flyway Service Account
```bash
gcloud iam service-accounts describe \
  flyway-devtest-sa@pcc-prj-app-devtest.iam.gserviceaccount.com \
  --project=pcc-prj-app-devtest
```

**Expected Output**:
```
displayName: Flyway Database Migration Service Account - Devtest
email: flyway-devtest-sa@pcc-prj-app-devtest.iam.gserviceaccount.com
name: projects/pcc-prj-app-devtest/serviceAccounts/flyway-devtest-sa@pcc-prj-app-devtest.iam.gserviceaccount.com
```

---

## Step 6: Verify Secret Manager IAM Bindings

### Check Password Secret Policy
```bash
gcloud secrets get-iam-policy alloydb-devtest-password \
  --project=pcc-prj-app-devtest
```

**Expected Output**:
```
bindings:
- members:
  - serviceAccount:flyway-devtest-sa@pcc-prj-app-devtest.iam.gserviceaccount.com
  role: roles/secretmanager.secretAccessor
```

### Check Connection String Secret Policy
```bash
gcloud secrets get-iam-policy alloydb-devtest-connection-string \
  --project=pcc-prj-app-devtest
```

**Expected Output**:
```
bindings:
- members:
  - serviceAccount:client-api-devtest-sa@pcc-prj-app-devtest.iam.gserviceaccount.com
  role: roles/secretmanager.secretAccessor
```

### Check Connection Name Secret Policy
```bash
gcloud secrets get-iam-policy alloydb-devtest-connection-name \
  --project=pcc-prj-app-devtest
```

**Expected Output**:
```
bindings:
- members:
  - serviceAccount:flyway-devtest-sa@pcc-prj-app-devtest.iam.gserviceaccount.com
  - serviceAccount:client-api-devtest-sa@pcc-prj-app-devtest.iam.gserviceaccount.com
  role: roles/secretmanager.secretAccessor
```

---

## Step 7: Verify AlloyDB IAM Bindings

### Check Cluster IAM Policy
```bash
gcloud alloydb clusters get-iam-policy pcc-alloydb-devtest \
  --region=us-east4 \
  --project=pcc-prj-app-devtest
```

**Expected Output**:
```
bindings:
- members:
  - serviceAccount:flyway-devtest-sa@pcc-prj-app-devtest.iam.gserviceaccount.com
  - serviceAccount:client-api-devtest-sa@pcc-prj-app-devtest.iam.gserviceaccount.com
  role: roles/alloydb.client
```

### Check Instance IAM Policy
```bash
gcloud alloydb instances get-iam-policy primary \
  --cluster=pcc-alloydb-devtest \
  --region=us-east4 \
  --project=pcc-prj-app-devtest
```

**Expected Output**:
```
bindings:
- members:
  - serviceAccount:flyway-devtest-sa@pcc-prj-app-devtest.iam.gserviceaccount.com
  - serviceAccount:client-api-devtest-sa@pcc-prj-app-devtest.iam.gserviceaccount.com
  role: roles/alloydb.viewer
```

---

## Step 8: Test Service Account Access (Optional)

### Test Flyway SA Secret Access
```bash
# Impersonate Flyway SA and access password secret
gcloud secrets versions access latest \
  --secret=alloydb-devtest-password \
  --project=pcc-prj-app-devtest \
  --impersonate-service-account=flyway-devtest-sa@pcc-prj-app-devtest.iam.gserviceaccount.com
```

**Expected**: Password string (if you have impersonation permissions)
**If Permission Denied**: This is expected if you don't have `roles/iam.serviceAccountTokenCreator` on the SA

### Test Client API SA Secret Access
```bash
# Impersonate Client API SA and access connection string
gcloud secrets versions access latest \
  --secret=alloydb-devtest-connection-string \
  --project=pcc-prj-app-devtest \
  --impersonate-service-account=client-api-devtest-sa@pcc-prj-app-devtest.iam.gserviceaccount.com
```

**Expected**: Connection string (if you have impersonation permissions)

---

## Validation Checklist

- [ ] Terraform plan shows 10 resources to add
- [ ] Terraform apply completed successfully
- [ ] 2 service accounts created with environment-specific names
- [ ] Service accounts visible via `gcloud iam service-accounts list`
- [ ] 4 Secret Manager IAM bindings created
- [ ] Password secret: Flyway SA has access
- [ ] Connection string secret: Client API SA has access
- [ ] Connection name secret: Both SAs have access
- [ ] 2 AlloyDB cluster IAM bindings created
- [ ] 2 AlloyDB instance IAM bindings created
- [ ] 4 outputs available
- [ ] No errors in terraform or gcloud output

---

## IAM Binding Summary

### Flyway Service Account
**Access Granted**:
- ✅ `alloydb-devtest-password` (Secret Manager)
- ✅ `alloydb-devtest-connection-name` (Secret Manager)
- ✅ `pcc-alloydb-devtest` cluster (AlloyDB client)
- ✅ `primary` instance (AlloyDB viewer)

**Purpose**: Database migrations via Flyway

---

### Client API Service Account
**Access Granted**:
- ✅ `alloydb-devtest-connection-string` (Secret Manager)
- ✅ `alloydb-devtest-connection-name` (Secret Manager)
- ✅ `pcc-alloydb-devtest` cluster (AlloyDB client)
- ✅ `primary` instance (AlloyDB viewer)

**Purpose**: Application runtime database access

---

## Troubleshooting

### Issue: "Service account already exists"
**Resolution**: Import existing service account
```bash
terraform import google_service_account.flyway \
  projects/pcc-prj-app-devtest/serviceAccounts/flyway-devtest-sa@pcc-prj-app-devtest.iam.gserviceaccount.com
```

### Issue: "Permission denied on secret"
**Resolution**: Verify IAM binding was created
```bash
gcloud secrets get-iam-policy alloydb-devtest-password \
  --project=pcc-prj-app-devtest \
  --flatten="bindings[].members" \
  --filter="bindings.members:flyway-devtest-sa"
```

### Issue: "AlloyDB cluster IAM binding failed"
**Resolution**: Verify cluster exists and is in READY state
```bash
gcloud alloydb clusters describe pcc-alloydb-devtest \
  --region=us-east4 \
  --project=pcc-prj-app-devtest \
  --format="value(state)"
```
**Expected**: `READY`

### Issue: "Terraform state out of sync"
**Resolution**: Refresh state
```bash
terraform refresh -var="environment=devtest"
```

---

## Security Notes

### No Service Account Keys Created
- ✅ Service accounts created WITHOUT keys
- ✅ Workload Identity will be configured in Phase 2.10
- ✅ No long-lived credentials stored

### Principle of Least Privilege Applied
- ✅ Per-secret Secret Manager bindings (not project-wide)
- ✅ Per-cluster AlloyDB bindings (not project-wide)
- ✅ Per-instance AlloyDB bindings (not cluster-wide)
- ✅ Separate SAs for different purposes (Flyway vs Application)

---

## Post-Deployment Actions

**DO NOT PROCEED** until:
- ✅ All 10 resources created successfully
- ✅ All 4 outputs are populated
- ✅ IAM bindings verified via gcloud

**Next Steps**:
1. **Phase 2.10**: Create Flyway migration scripts (local execution)
2. **Phase 2.11**: Execute Flyway migrations locally on developer's machine
3. **Phase 2.12**: Validate end-to-end connectivity

---

## References

- **Service Account CLI**: https://cloud.google.com/sdk/gcloud/reference/iam/service-accounts
- **IAM Policy CLI**: https://cloud.google.com/sdk/gcloud/reference/secrets/get-iam-policy
- **AlloyDB IAM**: https://cloud.google.com/alloydb/docs/manage-iam-authn

---

## Time Estimate

- **Format**: 1 minute
- **Validate**: 1 minute
- **Generate plan**: 2-3 minutes
- **Apply plan**: 2-3 minutes (IAM provisioning)
- **Verify service accounts**: 2-3 minutes
- **Verify IAM bindings**: 3-4 minutes
- **Total**: 8-12 minutes

---

**Status**: Ready for execution
**Next**: Phase 2.10 - Create Flyway Configuration
