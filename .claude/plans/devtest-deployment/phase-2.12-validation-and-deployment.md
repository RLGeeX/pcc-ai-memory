# Phase 2.12: Validation and End-to-End Deployment

**Phase**: 2.12 (Integration - Complete Deployment)
**Duration**: 25-30 minutes
**Type**: Orchestration
**Status**: Ready for Execution

---

## Execution Tool

**Use WARP for this phase** - Running terraform apply, gcloud validation, and database verification commands only, no file editing.

---

## Objective

Execute complete end-to-end deployment of Phase 2 (AlloyDB + Secret Manager + IAM) with validation checkpoints at each stage. Phase 2.11 (Flyway migrations) execute locally on developer's machine. Ensures all components integrate correctly before proceeding to Phase 3 (GKE).

## Prerequisites

✅ Phase 0 completed (API enablement code ready)
✅ Phase 2.1-2.11 implementation files created
✅ Access to `pcc-foundation-infra` terraform
✅ Access to `pcc-tf-library` modules
✅ Access to `pcc-app-shared-infra` terraform
✅ Access to `pcc-client-api` repository (for SQL scripts)
✅ Flyway CLI and AlloyDB Auth Proxy installed locally (or will install in Phase 2.11)

---

## Deployment Architecture

**Phase 2 Components**:
1. **Foundation**: API enablement (secretmanager.googleapis.com)
2. **Modules**: AlloyDB cluster + Secret Manager (pcc-tf-library)
3. **Infrastructure**: AlloyDB instance + secrets + IAM (pcc-app-shared-infra)
4. **Migrations**: Flyway SQL scripts (local execution)

**Dependencies**:
```
Phase 0.1-0.2 (APIs) → Phase 2.1-2.2 (Modules) → Phase 2.3-2.11 (Infrastructure + Migrations)
```

---

## Deployment Order

### Stage 1: Foundation (5 minutes)
**Phase 0.1-0.2**: Edit and deploy API enablement

### Stage 2: Modules (0 minutes)
**Phase 2.1-2.2**: Create AlloyDB module (no deployment, just code)
**Phase 2.5**: Create Secret Manager module (no deployment, just code)

### Stage 3: Infrastructure (20 minutes)
**Phase 2.3-2.4**: Create and deploy AlloyDB cluster (~15 min)
**Phase 2.6-2.7**: Create and deploy secrets (~1 min)
**Phase 2.8-2.9**: Create and deploy IAM (~1 min)

### Stage 4: Migrations (5 minutes)
**Phase 2.10-2.11**: Create SQL scripts and execute locally (~5 min)

**Total Expected Duration**: 30 minutes

---

## Pre-Deployment Validation

### 1. Verify Prerequisites

```bash
# Check terraform installed
terraform version  # Should be >= 1.5.0

# Check gcloud authenticated
gcloud auth list

# Check repo structure
ls ~/pcc/core/pcc-foundation-infra/terraform/main.tf
ls ~/pcc/core/pcc-tf-library/modules/alloydb-cluster/
ls ~/pcc/core/pcc-tf-library/modules/secret-manager/
ls ~/pcc/infra/pcc-app-shared-infra/terraform/
```

**Expected**: All files/directories exist, terraform >= 1.5.0

---

### 2. Verify API Enablement Code

```bash
cd ~/pcc/core/pcc-foundation-infra/terraform

# Check for secretmanager API in devtest project
grep -A 10 "pcc-prj-app-devtest" main.tf | grep secretmanager

# Expected: "secretmanager.googleapis.com"
```

---

### 3. Verify Module Code

```bash
# AlloyDB module
ls ~/pcc/core/pcc-tf-library/modules/alloydb-cluster/*.tf

# Expected: versions.tf, variables.tf, outputs.tf, main.tf, instances.tf

# Secret Manager module
ls ~/pcc/core/pcc-tf-library/modules/secret-manager/*.tf

# Expected: versions.tf, variables.tf, outputs.tf, main.tf
```

---

### 4. Verify Infrastructure Code

```bash
cd ~/pcc/infra/pcc-app-shared-infra/terraform

# Check for AlloyDB module call
ls alloydb.tf

# Check for Secret Manager module calls
ls secrets.tf

# Check for IAM bindings
ls iam.tf

# Expected: All 3 files exist
```

---

### 5. Verify Flyway SQL Scripts

```bash
cd ~/pcc/src/pcc-client-api/PortfolioConnect.Client.Api/Migrations/Scripts/v1

# Check SQL migration files
ls *.sql

# Expected: V1__create_schema.sql, V2__create_tables.sql

# Check Flyway configuration
ls flyway.conf

# Verify SQL syntax
cat V1__create_schema.sql
cat V2__create_tables.sql
```

---

## Stage 1: Deploy Foundation (Phase 0)

### Step 1.1: API Enablement

```bash
cd ~/pcc/core/pcc-foundation-infra/terraform

# Format and validate
terraform fmt
terraform validate

# Plan
terraform plan -out=phase0-apis.tfplan

# Verify plan
grep "google_project_service" phase0-apis.tfplan || terraform show phase0-apis.tfplan | grep "google_project_service"

# Apply
terraform apply phase0-apis.tfplan
```

**Expected Resources**: 1× `google_project_service.apis["pcc-prj-app-devtest-secretmanager.googleapis.com"]`

**Duration**: 2-3 minutes

---

### Step 1.2: Verify API Enablement

```bash
# Verify Secret Manager API
gcloud services list --project=pcc-prj-app-devtest --filter="name:secretmanager"

# Expected output:
# NAME                           TITLE
# secretmanager.googleapis.com   Secret Manager API
```

**✅ Checkpoint 1**: Secret Manager API enabled

---

## Stage 2: Validate Modules (Phase 2.1-2.2, 2.4)

**Note**: Modules are library code only, no deployment required

### Step 2.1: Validate AlloyDB Module

```bash
cd ~/pcc/core/pcc-tf-library/modules/alloydb-cluster

# Validate module syntax
terraform init
terraform validate

# Expected: Success! The configuration is valid.
```

---

### Step 2.2: Validate Secret Manager Module

```bash
cd ~/pcc/core/pcc-tf-library/modules/secret-manager

# Validate module syntax
terraform init
terraform validate

# Expected: Success! The configuration is valid.
```

**✅ Checkpoint 2**: Modules validated successfully

---

## Stage 3: Deploy Infrastructure (Phase 2.3-2.6)

### Step 3.1: Generate Strong Password

```bash
# Generate 24-character password
export ALLOYDB_PASSWORD=$(openssl rand -base64 24)

# Verify password set
echo "Password length: ${#ALLOYDB_PASSWORD}"

# Expected: Password length: 32
```

---

### Step 3.2: Deploy AlloyDB + Secrets + IAM

```bash
cd ~/pcc/infra/pcc-app-shared-infra/terraform

# Initialize terraform (first time only)
terraform init

# Format and validate
terraform fmt
terraform validate

# Plan (with password variable)
terraform plan \
  -var="alloydb_password=$ALLOYDB_PASSWORD" \
  -out=phase2-infrastructure.tfplan

# Review plan
terraform show phase2-infrastructure.tfplan | less

# Expected resources:
# - 1× google_alloydb_cluster.cluster
# - 1× google_alloydb_instance.primary
# - 3× google_secret_manager_secret (via module)
# - 3× google_secret_manager_secret_version (via module)
# - 2× google_service_account
# - 8× IAM bindings
# Total: 18 resources

# Apply
terraform apply phase2-infrastructure.tfplan
```

**Duration**: 15-20 minutes (AlloyDB cluster creation is slow)

---

### Step 3.3: Verify AlloyDB Cluster

```bash
# Check cluster status
gcloud alloydb clusters describe pcc-alloydb-devtest \
  --region=us-east4 \
  --project=pcc-prj-app-devtest \
  --format="value(state)"

# Expected: READY

# Get primary instance IP
gcloud alloydb instances describe primary \
  --cluster=pcc-alloydb-devtest \
  --region=us-east4 \
  --project=pcc-prj-app-devtest \
  --format="value(ipAddress)"

# Note the IP address (e.g., 10.0.0.5)
```

**✅ Checkpoint 3**: AlloyDB cluster is READY

---

### Step 3.4: Verify Secrets

```bash
# List secrets
gcloud secrets list --project=pcc-prj-app-devtest

# Expected secrets:
# - alloydb-devtest-password
# - alloydb-devtest-connection-string
# - alloydb-devtest-connection-name

# Verify password secret (should match generated password)
PASSWORD_FROM_SECRET=$(gcloud secrets versions access latest \
  --secret=alloydb-devtest-password \
  --project=pcc-prj-app-devtest)

# Compare with generated password
test "$PASSWORD_FROM_SECRET" = "$ALLOYDB_PASSWORD" && echo "✅ Passwords match" || echo "❌ Password mismatch"
```

**✅ Checkpoint 4**: Secrets created and accessible

---

### Step 3.5: Verify IAM Bindings

```bash
# Verify Flyway SA has secret access
gcloud secrets get-iam-policy alloydb-devtest-password \
  --project=pcc-prj-app-devtest | grep flyway-sa

# Expected: member: serviceAccount:flyway-sa@pcc-prj-app-devtest.iam.gserviceaccount.com

# Verify Flyway SA has AlloyDB access
gcloud alloydb clusters get-iam-policy pcc-alloydb-devtest \
  --region=us-east4 \
  --project=pcc-prj-app-devtest | grep flyway-sa

# Expected: member: serviceAccount:flyway-sa@pcc-prj-app-devtest.iam.gserviceaccount.com
```

**✅ Checkpoint 5**: IAM bindings configured correctly

---

## Stage 4: Execute Migrations Locally (Phase 2.10-2.11)

### Step 4.1: Install Flyway CLI and Auth Proxy (if not installed)

**Note**: This step is for developer's local machine preparation

```bash
# Check if Flyway CLI installed
flyway -v || echo "⚠️  Flyway CLI not installed"

# Check if Auth Proxy installed
alloydb-auth-proxy --version || echo "⚠️  Auth Proxy not installed"

# If not installed, follow Phase 2.11 installation steps
```

**Reference**: See Phase 2.11 for detailed installation instructions

---

### Step 4.2: Start Auth Proxy and Execute Migrations

**Note**: These commands run on developer's local machine, not in GKE

```bash
# Get AlloyDB connection name
CONNECTION_NAME=$(gcloud alloydb clusters describe pcc-alloydb-devtest \
  --region=us-east4 \
  --project=pcc-prj-app-devtest \
  --format="value(name)")

# Start Auth Proxy in background
alloydb-auth-proxy "$CONNECTION_NAME" --address=0.0.0.0 --port=5432 &
PROXY_PID=$!

# Wait for Auth Proxy to be ready
sleep 5

# Fetch password from Secret Manager
export FLYWAY_PASSWORD=$(gcloud secrets versions access latest \
  --secret=alloydb-devtest-password \
  --project=pcc-prj-app-devtest)

# Create database (first time only)
PGPASSWORD=$FLYWAY_PASSWORD psql -h localhost -p 5432 -U postgres -d postgres \
  -c "CREATE DATABASE client_api_db;"

# Execute Flyway migrations
cd ~/pcc/src/pcc-client-api
flyway migrate \
  -url=jdbc:postgresql://localhost:5432/client_api_db \
  -user=postgres \
  -password="$FLYWAY_PASSWORD" \
  -locations=filesystem:./PortfolioConnect.Client.Api/Migrations/Scripts/v1 \
  -schemas=client_api

# Stop Auth Proxy
kill $PROXY_PID
```

**Expected Output**:
```
Successfully validated 2 migrations
Migrating schema [client_api] to version "1 - create schema"
Migrating schema [client_api] to version "2 - create tables"
Successfully applied 2 migrations
```

**Duration**: 3-5 minutes

---

### Step 4.3: Verify Database Schema

```bash
# Get AlloyDB IP
ALLOYDB_IP=$(gcloud alloydb instances describe primary \
  --cluster=pcc-alloydb-devtest \
  --region=us-east4 \
  --project=pcc-prj-app-devtest \
  --format="value(ipAddress)")

# Get password
PASSWORD=$(gcloud secrets versions access latest \
  --secret=alloydb-devtest-password \
  --project=pcc-prj-app-devtest)

# Connect via psql (if available locally)
PGPASSWORD=$PASSWORD psql \
  -h $ALLOYDB_IP \
  -U postgres \
  -d client_api_db \
  -c "\dt client_api.*"

# Expected tables:
# - users
# - clients
# - flyway_schema_history
```

**✅ Checkpoint 6**: Database schema initialized

---

## Post-Deployment Validation

### Validation Summary

```bash
# Generate validation report
cat << 'EOF' > /tmp/phase2-validation.sh
#!/bin/bash
echo "=== Phase 2 Validation Report ==="
echo ""

# API Enablement
echo "1. Secret Manager API:"
gcloud services list --project=pcc-prj-app-devtest --filter="name:secretmanager" --format="value(name)" || echo "❌ Not enabled"
echo ""

# AlloyDB Cluster
echo "2. AlloyDB Cluster:"
gcloud alloydb clusters describe pcc-alloydb-devtest --region=us-east4 --project=pcc-prj-app-devtest --format="value(state)" || echo "❌ Not found"
echo ""

# AlloyDB Instance
echo "3. AlloyDB Primary Instance:"
gcloud alloydb instances describe primary --cluster=pcc-alloydb-devtest --region=us-east4 --project=pcc-prj-app-devtest --format="value(state,ipAddress)" || echo "❌ Not found"
echo ""

# Secrets
echo "4. Secrets:"
gcloud secrets list --project=pcc-prj-app-devtest --format="value(name)" | grep alloydb-devtest || echo "❌ No secrets found"
echo ""

# Service Accounts
echo "5. Service Accounts:"
gcloud iam service-accounts list --project=pcc-prj-app-devtest --format="value(email)" | grep -E "(flyway-sa|client-api-sa)" || echo "❌ No service accounts found"
echo ""

# Flyway Migrations (check database)
echo "6. Flyway Migration Status:"
PGPASSWORD=$(gcloud secrets versions access latest --secret=alloydb-devtest-password --project=pcc-prj-app-devtest) \
  psql -h $(gcloud alloydb instances describe primary --cluster=pcc-alloydb-devtest --region=us-east4 --project=pcc-prj-app-devtest --format="value(ipAddress)") \
  -U postgres -d client_api_db -c "SELECT COUNT(*) FROM client_api.flyway_schema_history;" 2>/dev/null || echo "⚠️  Not executed yet (run Phase 2.11)"
echo ""

echo "=== End of Report ==="
EOF

chmod +x /tmp/phase2-validation.sh
/tmp/phase2-validation.sh
```

---

## Troubleshooting

### Issue: Terraform plan shows unexpected changes

**Resolution**: Check terraform state
```bash
cd ~/pcc/infra/pcc-app-shared-infra/terraform
terraform state list
terraform show
```

---

### Issue: AlloyDB cluster creation timeout

**Resolution**: AlloyDB cluster takes 15-20 minutes, be patient
```bash
# Check cluster creation progress
gcloud alloydb clusters describe pcc-alloydb-devtest \
  --region=us-east4 \
  --project=pcc-prj-app-devtest \
  --format="value(state)"
```

---

### Issue: Secret already exists

**Resolution**: Import existing secret
```bash
terraform import \
  module.alloydb_password.google_secret_manager_secret.secret \
  projects/pcc-prj-app-devtest/secrets/alloydb-devtest-password
```

---

### Issue: IAM binding permission denied

**Resolution**: Verify service account has required permissions
```bash
gcloud projects get-iam-policy pcc-prj-app-devtest \
  --flatten="bindings[].members" \
  --filter="bindings.members:YOUR_SERVICE_ACCOUNT"
```

---

### Issue: Flyway migration fails with "permission denied"

**Resolution**: Verify developer gcloud authentication
```bash
# Check current authentication
gcloud auth list

# Re-authenticate if needed
gcloud auth login

# Verify project access
gcloud projects describe pcc-prj-app-devtest
```

---

## Rollback Procedures

### Rollback Stage 4 (Flyway)

**Note**: Flyway migrations cannot be automatically rolled back. Use Flyway undo migrations or manual SQL scripts.

```bash
# Manual rollback via psql (if needed)
# Connect to database and drop schema
PGPASSWORD=$PASSWORD psql \
  -h $ALLOYDB_IP \
  -U postgres \
  -d client_api_db \
  -c "DROP SCHEMA client_api CASCADE;"

# This will remove all tables and data
```

**Warning**: This is destructive. Only use in development.

---

### Rollback Stage 3 (Infrastructure)

```bash
cd ~/pcc/infra/pcc-app-shared-infra/terraform
terraform destroy -target=module.alloydb
terraform destroy -target=module.alloydb_password
terraform destroy -target=module.alloydb_connection_string
terraform destroy -target=module.alloydb_connection_name
```

**Warning**: This will delete AlloyDB cluster and all data

---

### Rollback Stage 1 (API Enablement)

```bash
cd ~/pcc/core/pcc-foundation-infra/terraform
terraform destroy -target='google_project_service.apis["pcc-prj-app-devtest-secretmanager.googleapis.com"]'
```

---

## Connection Information for Phase 3

**Save these outputs for Phase 3 (application deployment)**:

```bash
cd ~/pcc/infra/pcc-app-shared-infra/terraform

# Get AlloyDB connection info
terraform output alloydb_primary_instance_ip
terraform output alloydb_primary_connection_name

# Get secret names
terraform output alloydb_connection_string_secret_name
terraform output alloydb_password_secret_name

# Get service account emails
terraform output client_api_service_account_email
```

**Document in Phase 3 handoff**:
- AlloyDB IP: `<output from above>`
- Connection name: `<output from above>`
- Connection string secret: `alloydb-devtest-connection-string`
- Client API SA: `client-api-sa@pcc-prj-app-devtest.iam.gserviceaccount.com`

---

## Cost Tracking

**Monthly Cost Estimate** (Devtest):
- AlloyDB db-standard-2 ZONAL: ~$200
- AlloyDB backup storage (10GB): ~$1
- Secret Manager storage (3 secrets): ~$0.20
- Secret Manager API calls (negligible): ~$0.10
- **Total**: ~$201/month

**Compare to Production** (REGIONAL HA with replica): ~$800/month

---

## Time Estimate

- **Pre-deployment validation**: 5 minutes
- **Stage 1 (Foundation)**: 5 minutes
- **Stage 2 (Module validation)**: 3 minutes
- **Stage 3 (Infrastructure)**: 18-20 minutes
- **Stage 4 (Flyway)**: 5 minutes (local execution)
- **Post-deployment validation**: 3 minutes
- **Total**: 25-30 minutes (without GKE cluster wait)

---

## Success Criteria

**Phase 2 is complete when**:
- ✅ Secret Manager API enabled
- ✅ AlloyDB cluster status = READY
- ✅ AlloyDB primary instance status = READY
- ✅ 3 secrets created and accessible
- ✅ 2 service accounts created
- ✅ 8 IAM bindings configured
- ✅ Flyway migrations executed successfully (2 migrations applied)
- ✅ Database schema initialized (users, clients, flyway_schema_history tables exist)
- ✅ Connection information documented for Phase 3

---

## Next Steps

**Phase 3**: GKE Cluster Deployment
- Create GKE devtest cluster
- Configure Workload Identity for applications
- Deploy microservices with database access

**Phase 4**: ArgoCD Setup
- Install ArgoCD in GKE
- Configure GKE Hub
- Connect to Git repositories
- Deploy applications

---

## References

- **AlloyDB**: https://cloud.google.com/alloydb/docs
- **Secret Manager**: https://cloud.google.com/secret-manager/docs
- **Flyway**: https://flywaydb.org/documentation
- **AlloyDB Auth Proxy**: https://cloud.google.com/alloydb/docs/auth-proxy/overview

---

**Status**: Ready for execution
**Next**: Phase 3.0 - GKE Cluster Planning and Architecture
