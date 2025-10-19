# Phase 2.9: Deploy via WARP

**Phase**: 2.9 (AlloyDB Infrastructure - WARP Deployment)
**Duration**: 20-30 minutes
**Type**: Deployment
**Status**: 📋 Planning (Not Started)
**Date**: TBD (10/20+)

---

## Objective

Execute the terraform deployment of AlloyDB cluster infrastructure (cluster, instances, databases) using WARP terminal assistant, validate successful creation, test PSC connectivity, and run Flyway baseline.

## Prerequisites

✅ Phase 2.8 completed (terraform validated, plan generated)
✅ `alloydb-devtest.tfplan` file exists (from Phase 2.8)
✅ WARP terminal available
✅ GCP credentials configured
✅ Phase 1.5 completed (Network infrastructure deployed, PSC IP reserved)

---

## WARP Deployment Steps

### Step 1: Switch to WARP Terminal

Open WARP terminal and navigate to terraform directory:
```bash
cd ~/pcc/infra/pcc-app-shared-infra/terraform
```

---

### Step 2: Pre-Deployment Backup

```bash
# Backup current state
cp terraform.tfstate terraform.tfstate.backup.$(date +%Y%m%d-%H%M%S)

# List current AlloyDB clusters (baseline)
gcloud alloydb clusters list --region=us-east4 --project=pcc-prj-app-devtest > alloydb-before.txt
```

---

### Step 3: Apply Terraform Plan

```bash
terraform apply alloydb-devtest.tfplan
```

**Expected Duration**: 15-25 minutes (AlloyDB cluster creation is slow)

**Expected Output** (abridged):
```
module.alloydb_cluster_devtest.google_alloydb_cluster.cluster: Creating...
module.alloydb_cluster_devtest.google_alloydb_cluster.cluster: Still creating... [1m0s elapsed]
module.alloydb_cluster_devtest.google_alloydb_cluster.cluster: Still creating... [2m0s elapsed]
module.alloydb_cluster_devtest.google_alloydb_cluster.cluster: Creation complete after 3m15s

module.alloydb_cluster_devtest.google_alloydb_instance.primary: Creating...
module.alloydb_cluster_devtest.google_alloydb_instance.primary: Still creating... [1m0s elapsed]
module.alloydb_cluster_devtest.google_alloydb_instance.primary: Still creating... [5m0s elapsed]
module.alloydb_cluster_devtest.google_alloydb_instance.primary: Creation complete after 8m42s

module.alloydb_cluster_devtest.google_alloydb_instance.replica[0]: Creating...
module.alloydb_cluster_devtest.google_alloydb_instance.replica[0]: Still creating... [1m0s elapsed]
module.alloydb_cluster_devtest.google_alloydb_instance.replica[0]: Still creating... [5m0s elapsed]
module.alloydb_cluster_devtest.google_alloydb_instance.replica[0]: Creation complete after 8m15s

module.alloydb_cluster_devtest.google_alloydb_database.databases["auth_db_devtest"]: Creating...
module.alloydb_cluster_devtest.google_alloydb_database.databases["client_db_devtest"]: Creating...
module.alloydb_cluster_devtest.google_alloydb_database.databases["user_db_devtest"]: Creating...
module.alloydb_cluster_devtest.google_alloydb_database.databases["metric_builder_db_devtest"]: Creating...
module.alloydb_cluster_devtest.google_alloydb_database.databases["metric_tracker_db_devtest"]: Creating...
module.alloydb_cluster_devtest.google_alloydb_database.databases["task_builder_db_devtest"]: Creating...
module.alloydb_cluster_devtest.google_alloydb_database.databases["task_tracker_db_devtest"]: Creating...

module.alloydb_cluster_devtest.google_alloydb_database.databases["auth_db_devtest"]: Creation complete after 12s
module.alloydb_cluster_devtest.google_alloydb_database.databases["client_db_devtest"]: Creation complete after 14s
... (other databases complete) ...

Apply complete! Resources: 10 added, 0 changed, 0 destroyed.

Outputs:

alloydb_devtest_cluster_id = "pcc-alloydb-cluster-devtest"
alloydb_devtest_databases = [
  "auth_db_devtest",
  "client_db_devtest",
  "user_db_devtest",
  "metric_builder_db_devtest",
  "metric_tracker_db_devtest",
  "task_builder_db_devtest",
  "task_tracker_db_devtest",
]
alloydb_devtest_primary_connection_string = <sensitive>
alloydb_devtest_primary_ip = "10.28.0.5"  # Internal AlloyDB IP (not for direct connection)
alloydb_devtest_replica_ip = "10.28.0.6"  # Internal AlloyDB IP (not for direct connection)
alloydb_devtest_psc_dns = "xxxx.xxxx.alloydb.goog"  # PSC DNS name (use this for connections)
```

**Note**: Cluster creation can take 15-20 minutes (Google provisions infrastructure)

---

### Step 4: Post-Deployment Validation

```bash
# List AlloyDB clusters (after)
gcloud alloydb clusters list --region=us-east4 --project=pcc-prj-app-devtest > alloydb-after.txt

# Compare before/after
diff alloydb-before.txt alloydb-after.txt

# Verify cluster created
gcloud alloydb clusters describe pcc-alloydb-cluster-devtest \
  --region=us-east4 \
  --project=pcc-prj-app-devtest
```

**Expected**: New AlloyDB cluster exists

---

### Step 5: Verify Cluster Configuration

```bash
# Check cluster details
gcloud alloydb clusters describe pcc-alloydb-cluster-devtest \
  --region=us-east4 \
  --project=pcc-prj-app-devtest \
  --format=json | jq '{name, network, automatedBackupPolicy, continuousBackupConfig}'
```

**Validation Checklist**:
- [ ] **Cluster ID**: `pcc-alloydb-cluster-devtest`
- [ ] **Network**: `pcc-vpc-nonprod`
- [ ] **PSC Enabled**: Auto-created PSC service attachment (psc_config.psc_enabled = true)
- [ ] **Backup Policy**: Enabled (30-day retention)
- [ ] **PITR**: Enabled (7-day window)

---

### Step 6: Verify Primary Instance

```bash
# Check primary instance details
gcloud alloydb instances describe pcc-alloydb-instance-devtest-primary \
  --cluster=pcc-alloydb-cluster-devtest \
  --region=us-east4 \
  --project=pcc-prj-app-devtest \
  --format=json | jq '{instanceType, machineConfig, ipAddress, availabilityType}'
```

**Validation Checklist**:
- [ ] **Instance Type**: `PRIMARY`
- [ ] **CPU Count**: `2`
- [ ] **Availability**: `REGIONAL` (multi-zone HA)
- [ ] **IP Address**: Internal IP (10.28.0.x range - not for direct connection)

---

### Step 7: Verify Replica Instance

```bash
# Check replica instance details
gcloud alloydb instances describe pcc-alloydb-instance-devtest-replica \
  --cluster=pcc-alloydb-cluster-devtest \
  --region=us-east4 \
  --project=pcc-prj-app-devtest \
  --format=json | jq '{instanceType, machineConfig, ipAddress, readPoolConfig}'
```

**Validation Checklist**:
- [ ] **Instance Type**: `READ_POOL`
- [ ] **CPU Count**: `2`
- [ ] **Node Count**: `1`
- [ ] **IP Address**: Internal IP (10.28.0.x range - not for direct connection)

---

### Step 8: Verify Databases

```bash
# List all databases in cluster
gcloud alloydb databases list \
  --cluster=pcc-alloydb-cluster-devtest \
  --region=us-east4 \
  --project=pcc-prj-app-devtest
```

**Expected Output**:
```
NAME                           CLUSTER
auth_db_devtest                pcc-alloydb-cluster-devtest
client_db_devtest              pcc-alloydb-cluster-devtest
user_db_devtest                pcc-alloydb-cluster-devtest
metric_builder_db_devtest      pcc-alloydb-cluster-devtest
metric_tracker_db_devtest      pcc-alloydb-cluster-devtest
task_builder_db_devtest        pcc-alloydb-cluster-devtest
task_tracker_db_devtest        pcc-alloydb-cluster-devtest
```

**Validation**: 7 databases created

---

### Step 9: Test PSC Connectivity (Auth Proxy)

```bash
# Download AlloyDB Auth Proxy (if not already installed)
curl -o alloydb-auth-proxy https://storage.googleapis.com/alloydb-auth-proxy/v1.6.1/alloydb-auth-proxy.darwin.amd64
chmod +x alloydb-auth-proxy
sudo mv alloydb-auth-proxy /usr/local/bin/

# Get connection string from terraform output
terraform output alloydb_devtest_primary_connection_string

# Start Auth Proxy in background
alloydb-auth-proxy \
  "projects/pcc-prj-app-devtest/locations/us-east4/clusters/pcc-alloydb-cluster-devtest/instances/pcc-alloydb-instance-devtest-primary" \
  --port=5433 &

# Wait for proxy to start
sleep 5

# Test connection (using postgres user temporarily)
psql -h 127.0.0.1 -p 5433 -U postgres -d postgres -c "SELECT version();"
```

**Expected Output**:
```
PostgreSQL 15.x (Google AlloyDB)
```

**Note**: If connection fails, check:
- Auth Proxy started successfully
- IAM permissions (Phase 2.6)
- PSC connectivity (Phase 1.2)

---

### Step 10: Run Flyway Baseline (Initial Setup)

**Purpose**: Initialize Flyway schema_history table (mark V0 as baseline)

```bash
# Navigate to first microservice (auth-api)
cd ~/pcc/src/pcc-auth-api

# Retrieve Flyway credentials from Secret Manager
export DB_USER=$(gcloud secrets versions access latest \
  --secret=alloydb-flyway-credentials-devtest \
  --project=pcc-prj-app-devtest \
  --format=json | jq -r '.username')

export DB_PASSWORD=$(gcloud secrets versions access latest \
  --secret=alloydb-flyway-credentials-devtest \
  --project=pcc-prj-app-devtest \
  --format=json | jq -r '.password')

# Run Flyway baseline (V0 - empty database)
flyway -configFiles=flyway.conf baseline -baselineVersion=0

# Run Flyway migrate (apply V1__initial_schema.sql)
flyway -configFiles=flyway.conf migrate
```

**Expected Output**:
```
Flyway Community Edition 9.22.0 by Redgate

Database: jdbc:postgresql://127.0.0.1:5433/auth_db_devtest (PostgreSQL 15.x)
Creating Schema History table "public"."flyway_schema_history"...
Successfully baselined schema with version: 0

Migrating schema "public" to version "1 - initial schema"
Successfully applied 1 migration to schema "public", now at version v1 (execution time 00:00.125s)
```

**Repeat for Other 6 Services**: Run Flyway baseline and migrate for:
- client-api
- user-api
- metric-builder-api
- metric-tracker-api
- task-builder-api
- task-tracker-api

---

### Step 11: Verify Flyway Schema History

```bash
# Connect to database via Auth Proxy
psql -h 127.0.0.1 -p 5433 -U postgres -d auth_db_devtest

# Query Flyway history
SELECT installed_rank, version, description, installed_on, success
FROM flyway_schema_history
ORDER BY installed_rank;

# Exit psql
\q
```

**Expected Output**:
```
 installed_rank | version |    description     |     installed_on      | success
----------------+---------+--------------------+-----------------------+---------
              0 | 0       | << Flyway Baseline>> | 2025-10-20 14:30:00 | t
              1 | 1       | initial schema     | 2025-10-20 14:31:00 | t
```

---

### Step 12: Stop Auth Proxy

```bash
# Find Auth Proxy process
ps aux | grep alloydb-auth-proxy

# Kill process (replace PID)
kill <PID>
```

---

### Step 13: Git Commit

```bash
# Navigate to pcc-app-shared-infra
cd ~/pcc/infra/pcc-app-shared-infra

git add terraform/
git commit -m "feat: deploy AlloyDB cluster for devtest

Deployed AlloyDB infrastructure for devtest environment:
- AlloyDB cluster (pcc-alloydb-cluster-devtest)
- Primary instance (2 vCPUs, REGIONAL HA)
- Read replica (2 vCPUs, READ_POOL)
- 7 databases for microservices
- PSC auto-created (connect via AlloyDB Auth Proxy)

Phase 2 implementation complete. Cluster accessible via Auth Proxy.
Flyway baseline complete for all 7 databases."

git push origin main
```

---

## Success Criteria

### Infrastructure State
- [ ] AlloyDB cluster created (`pcc-alloydb-cluster-devtest`)
- [ ] Primary instance created (2 vCPUs, REGIONAL)
- [ ] Replica instance created (2 vCPUs, READ_POOL)
- [ ] 7 databases created (auth, client, user, metric_builder, metric_tracker, task_builder, task_tracker)
- [ ] PSC auto-created (psc_enabled = true, PSC DNS name available)
- [ ] Backup policy enabled (30-day retention)
- [ ] PITR enabled (7-day window)
- [ ] Terraform state updated successfully
- [ ] No errors during apply

### Validation Commands Pass
```bash
# Cluster exists
gcloud alloydb clusters describe pcc-alloydb-cluster-devtest --region=us-east4 --project=pcc-prj-app-devtest

# Primary instance exists
gcloud alloydb instances describe pcc-alloydb-instance-devtest-primary --cluster=pcc-alloydb-cluster-devtest --region=us-east4 --project=pcc-prj-app-devtest

# Replica instance exists
gcloud alloydb instances describe pcc-alloydb-instance-devtest-replica --cluster=pcc-alloydb-cluster-devtest --region=us-east4 --project=pcc-prj-app-devtest

# 7 databases exist
gcloud alloydb databases list --cluster=pcc-alloydb-cluster-devtest --region=us-east4 --project=pcc-prj-app-devtest
```

### Connectivity Test Passed
- [ ] Auth Proxy connected successfully
- [ ] psql connection successful
- [ ] Flyway baseline completed (all 7 databases)

---

## Testing Limitations (Phase 2)

### Cannot Test Yet

❌ **Application Connectivity**: Cannot test microservice → AlloyDB until GKE exists (Phase 5)

❌ **Workload Identity**: Cannot test Workload Identity until Kubernetes service accounts exist (Phase 3)

❌ **Connection Pooling**: Cannot test Npgsql connection pooling until microservices deployed (Phase 5)

❌ **Read Replica Queries**: Cannot test read-only queries until microservices configured to use replica (Phase 5)

### Can Validate Now

✅ **Cluster Created**: AlloyDB cluster exists with correct configuration

✅ **PSC Connectivity**: Auth Proxy successfully connects via PSC range

✅ **Database Existence**: All 7 databases created

✅ **Backup Policy**: Automated backups configured (30-day retention)

✅ **PITR**: Point-in-time recovery enabled (7-day window)

✅ **Multi-Zone HA**: Primary instance deployed with REGIONAL availability

✅ **Flyway Baseline**: Schema history initialized for all databases

---

## Phase 3+ Testing Plan

**After Kubernetes deployment** (Phase 3+), test the following:

1. **Application Connectivity**:
   - Deploy test pod in GKE (Phase 5)
   - Test microservice → AlloyDB connection via PSC
   - Verify connection pooling working

2. **Workload Identity**:
   - Test GKE service account → Secret Manager access
   - Verify credentials retrieved correctly
   - Test IAM authentication (optional)

3. **Flyway Migrations**:
   - Test CI/CD pipeline (Cloud Build)
   - Deploy new migration (V2__add_table.sql)
   - Verify migration applied successfully

4. **Read Replica**:
   - Configure microservice to use replica for read queries
   - Verify read-only queries routed to replica
   - Test failover behavior

---

## Troubleshooting (if needed)

### Issue: Cluster Creation Times Out

**Error**: Cluster creation exceeds 30-minute timeout

**Solution**:
- Normal for first cluster (can take 20+ minutes)
- Check GCP Console for detailed status
- If timeout persists, check PSC configuration (Phase 1.2)

---

### Issue: PSC Connection Error

**Error**: `Cannot connect to AlloyDB cluster`

**Solution**: Verify PSC auto-creation and use AlloyDB Auth Proxy
```bash
# Check PSC DNS name from cluster
gcloud alloydb clusters describe pcc-alloydb-cluster-devtest \
  --region=us-east4 \
  --project=pcc-prj-app-devtest \
  --format="value(pscConfig.pscDnsName)"

# Use AlloyDB Auth Proxy (recommended connection method)
./alloydb-auth-proxy "projects/pcc-prj-app-devtest/locations/us-east4/clusters/pcc-alloydb-cluster-devtest/instances/pcc-alloydb-instance-devtest-primary"
```

---

### Issue: Auth Proxy Connection Refused

**Error**: `dial tcp: connection refused`

**Solution**: Check IAM permissions (Phase 2.6)
```bash
gcloud projects get-iam-policy pcc-prj-app-devtest \
  --flatten="bindings[].members" \
  --filter="bindings.role:roles/alloydb.client"
```

---

### Issue: Flyway Baseline Fails

**Error**: `Unable to connect to database`

**Solution**:
1. Verify Auth Proxy running: `ps aux | grep alloydb-auth-proxy`
2. Check credentials: `gcloud secrets versions access latest --secret=alloydb-flyway-credentials-devtest`
3. Test connection: `psql -h 127.0.0.1 -p 5433 -U flyway_user -d postgres`

---

## Rollback (if needed)

**Complete Rollback** (only if critical failure):
```bash
# Step 1: Destroy AlloyDB resources
terraform destroy -target=module.alloydb_cluster_devtest

# Step 2: Restore state file
cp terraform.tfstate.backup.YYYYMMDD-HHMMSS terraform.tfstate

# Step 3: Verify rollback
gcloud alloydb clusters list --region=us-east4 --project=pcc-prj-app-devtest  # Should be empty
```

**Note**: AlloyDB deletion can take 10-15 minutes. Backups retained for 7 days (PITR).

---

## Post-Implementation Actions

### Documentation Updates
- [ ] Update `.claude/status/brief.md` (Phase 2 complete)
- [ ] Update `.claude/status/current-progress.md` (log implementation)
- [ ] Update `infra/pcc-app-shared-infra/.claude/status/brief.md` (AlloyDB deployed)

### What's Next
- **Phase 2.5**: Create Secret Manager secrets (database credentials)
- **Phase 2.6**: Create IAM bindings (Workload Identity)
- **Phase 3**: GKE cluster deployment (will connect to AlloyDB)
- **Phase 5**: Deploy microservices (will use AlloyDB databases)

---

## Deliverables

- [ ] Terraform apply executed successfully
- [ ] AlloyDB cluster created (10 resources)
- [ ] PSC connectivity tested (Auth Proxy working)
- [ ] 7 databases created
- [ ] Flyway baseline completed (all databases)
- [ ] Post-deployment validation passed
- [ ] Terraform state updated
- [ ] Git commit pushed to main
- [ ] Documentation updated
- [ ] Phase 2 complete

---

## References

- Phase 2.1 (cluster configuration)
- Phase 2.2 (terraform module)
- Phase 2.3 (module call)
- Phase 2.8 (validation)
- Phase 1.2 (PSC networking)
- `.claude/plans/devtest-deployment-phases.md` (Phase 2 overview)

---

## Notes

- **WARP Assistance**: Use WARP AI for real-time troubleshooting if issues arise
- **Deployment Time**: Typically 15-25 minutes (AlloyDB cluster creation is slow)
- **Testing Limitation**: Cannot verify application connectivity until GKE exists (Phase 5)
- **Cluster Deletion**: If rollback needed, deletion takes 10-15 minutes
- **Backup Retention**: PITR backups retained for 7 days after cluster deletion
- **Phase 3 Dependency**: Microservices will connect to this cluster via PSC (Phase 5)
- **Flyway Baseline**: Run once per database, then CI/CD handles migrations

---

**Next Phase**: Congratulations! Phase 2 complete. Ready to proceed with Phase 3-8 planning.
