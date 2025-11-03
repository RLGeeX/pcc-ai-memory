# PCC AI Memory - Current Progress

**Last Updated**: 2025-10-24

---

## ✅ Deployed Infrastructure

### Phase 0: Apigee Projects (Oct 20)
**Deployed**: 2 projects (pcc-prj-apigee-nonprod/prod), 22 resources, terraform validated

### Phase 1: Foundation Infrastructure (Oct 1-23)
**Deployed**: 15 GCP projects, 229 resources, 2 VPCs, AlloyDB APIs enabled, centralized terraform state bucket

---

## Phase 2: AlloyDB Cluster (Oct 22-24) - READY FOR DEPLOYMENT

**Module Created**: `alloydb-cluster` (5 files, HA, PSC, backups, PITR)
**Module Call**: `pcc-app-shared-infra/alloydb.tf` (devtest cluster, 2 vCPU, 30-day retention)
**Database Planning**: client_api_db_devtest, Flyway creates DB (not Terraform), SSL required
**Secret Manager**: 3 secrets (service/admin/flyway), SSL enforcement, 90-day rotation, Workload Identity
**IAM**: 13 bindings (least privilege, audit logging, resource-level)
**Auth Proxy**: Developer access documented
**Security**: Fixed 2 CRITICAL, 5 HIGH issues (passwords, SSL, credential handling)
**Status**: Ready for terraform validation and deployment

### Phase 2 Jira Subtasks (Oct 24)
**Created 14 Subtasks** (PCC-107 through PCC-120):
- PCC-107-108: Phase 0 prerequisites (API enablement, network validation)
- PCC-109-120: Phase 2.1-2.12 (AlloyDB deployment)
- All subtasks: Christine Fogarty, Medium priority, DevOps label, To Do status

**Configuration**:
- 1 ZONAL primary instance (cost-optimized ~$200/month)
- Database: `client_api_db` (no environment suffix)
- Schema: `public` (developer confirmed)
- Flyway local execution with Auth Proxy

---

## ✅ Phase 2: AlloyDB Module Implementation (Oct 25)

### PCC-109: Phase 2.1 - Create AlloyDB Module Skeleton ✅ COMPLETE
**Date**: 2025-10-25 | **Duration**: ~30 minutes  
**Status**: Completed and validated  
**Files**: 4 files in `core/pcc-tf-library/modules/alloydb-cluster/` (versions, variables, outputs, main)  
**Key Fix**: Corrected `automated_backup_policy` API structure (backup_window_start_hour + weekly_schedule)  
**Backup**: Daily at 7 AM UTC, 30-day retention, 7-day PITR  
**Validation**: ✅ terraform init, fmt, validate

### PCC-110: Phase 2.2 - Add Instance Configuration ✅ COMPLETE
**Date**: 2025-10-25 | **Duration**: ~25 minutes  
**Status**: Completed and validated  
**Files**: Added `instances.tf` + modified variables/outputs  
**Instance**: Primary ZONAL, db-standard-2 (2 vCPU, 16GB RAM), optional read replica, PSC enabled  
**Cost**: ZONAL saves 50% (~$200/month vs $400), no replica for devtest  
**Validation**: ✅ terraform fmt, init, validate

### PCC-107: Phase 0.1 - Foundation Prerequisites ✅ COMPLETE
**Date**: 2025-10-25 | **Duration**: ~20 minutes  
**Status**: Completed and verified  
**Changes**: Added 2 APIs to `pcc-foundation-infra/terraform/main.tf` for `pcc-prj-app-devtest`  
**APIs Added**: `secretmanager.googleapis.com`, `servicenetworking.googleapis.com`  
**Total APIs**: 6 (alloydb, compute, logging, monitoring, secretmanager, servicenetworking)  
**Note**: Configured in terraform, deployed in Phase 0.2 (PCC-108)

---

### PCC-111: Phase 2.3 - Create AlloyDB Configuration ✅ COMPLETE
**Date**: 2025-10-25 | **Duration**: ~15 minutes  
**Status**: Completed and validated  
**File**: `infra/pcc-app-shared-infra/terraform/alloydb.tf` (rewritten with module call)  
**Variables**: 4 added (availability_type=ZONAL, enable_read_replica=false, machine_type=db-standard-2, pitr_days=7)  
**Config**: us-east4, shared VPC, backups at 7 AM UTC, 30-day retention  
**Outputs**: 6 (cluster/instance IDs, IP, connection name, network)  
**Cost**: ZONAL + db-standard-2 + no replica = ~$200/month  
**Validation**: ✅ terraform fmt, init, validate

---

### PCC-112: Phase 2.4 - Deploy AlloyDB Infrastructure ✅ COMPLETE
**Date**: 2025-10-25 | **Status**: Completed by user  
**Changes**: Fixed module for PSC, removed conflicting `network_config`, cluster deployed

---

### PCC-113: Phase 2.5 - Create Secret Manager Module ✅ COMPLETE
**Date**: 2025-10-25 | **Duration**: ~25 minutes  
**Status**: Completed and validated  
**Files**: 4 files in `core/pcc-tf-library/modules/secret-manager/` (versions, variables, outputs, main)  
**Variables**: 12 total (3 required: project_id, secret_id, secret_data; 9 optional including rotation, replication, expiration)  
**Outputs**: 6 (secret ID/name, version ID/name, create time, rotation config)  
**Key Fix**: Topics at top level (not nested in rotation), replication uses dynamic blocks, version_aliases not supported  
**Validation**: ✅ terraform fmt, init, validate (after 3 fix iterations)

---

### PCC-114: Phase 2.6 - Create Secrets Configuration ✅ COMPLETE
**Date**: 2025-10-25 | **Duration**: ~20 minutes  
**Status**: Completed and validated  
**Files**: Created `secrets.tf` (111 lines, 3 module calls, 6 outputs), updated `variables.tf`, created `terraform.tfvars.example`  
**Secrets**: password (90-day rotation), connection_string (90-day rotation), connection_name (no rotation)  
**Database**: `client_api_db` (NO environment suffix - cluster-level differentiation)  
**Replication**: Changed to user-managed single-region (us-east4) due to org policy  
**Validation**: ✅ terraform fmt, init, validate

---

### PCC-116: Phase 2.8 - Create IAM Configuration ✅ COMPLETE
**Date**: 2025-10-25 | **Duration**: ~20 minutes  
**Status**: Completed, validated, and deployed  
**File**: `infra/pcc-app-shared-infra/terraform/environments/devtest/iam.tf` (155 lines)

**Service Accounts Created** (2):
- `flyway-devtest-sa`: Flyway migrations (password + connection name secrets, AlloyDB client/viewer)
- `client-api-devtest-sa`: Runtime API access (connection string + connection name secrets, AlloyDB client/viewer)

**IAM Bindings**: 8 total (4 Secret Manager, 2 AlloyDB client, 2 AlloyDB viewer)

**Critical Fix**: AlloyDB IAM roles are project-level only. Replaced non-existent `google_alloydb_cluster_iam_member` and `google_alloydb_instance_iam_member` resources with `google_project_iam_member` (unlike Secret Manager, AlloyDB has no resource-specific IAM bindings).

**Validation**: ✅ terraform fmt, init, validate all passed (after fix)

**Access Patterns**:
- Flyway: Direct password access for migrations
- Client API: Connection string for runtime
- Both: Least privilege, purpose-specific secret access

**Outputs**: 4 service account emails and unique IDs

---

### PCC-118: Phase 2.10 - Create Flyway Configuration ✅ COMPLETE
**Date**: 2025-10-25 | **Duration**: ~15 minutes (verification)  
**Status**: Verified existing configuration from developer (2025-10-24)

**Files Verified**:
- Flyway config: `pcc-client-api/.../v1/flyway.conf`
- Migration script: `01_InitialCreation.sql` (313 lines, EF Core generated 2025-10-05)

**Key Configuration**:
- Database: `client_api_db` (NO environment suffix - cluster-level differentiation)
- Schema: `public` (PostgreSQL default)
- Expected tables: 15 total (7 entities, 6 audits, 1 EF history, 1 Flyway history)
- Features: 19 indexes, 19 seed lookup records, UTC timestamps

**Technical Decisions**:
- Database name consistent across environments
- Clean disabled for safety, baseline on migrate enabled
- Filesystem location: `./PortfolioConnect.Client.Api/Migrations/Scripts/v1`

**Validation**: ✅ Configuration verified, ready for Phase 2.11 (Execute Flyway Migrations)

---

---

## Phase 3: GKE DevOps Cluster (Oct 25) - PLANNING COMPLETE

**Status**: Ready for execution - Documentation complete, Jira subtasks created
**Jira**: PCC-124 through PCC-135 (12 subtasks for Christine Fogarty)

**Configuration**:
- Cluster: pcc-gke-devops-nonprod (GKE Autopilot)
- Region: us-east4
- Features: Connect Gateway, Workload Identity, private endpoint
- Purpose: DevOps services (ArgoCD, monitoring, system services)

**Planning Files**: `.claude/plans/devtest-deployment/phase-3.*.md`

---

---

## Phase 6: ArgoCD Deployment (Oct 26) - PLANNING COMPLETE

**Status**: Ready for execution - All 29 planning files validated
**Jira**: PCC-136 through PCC-164 (29 subtasks for Christine Fogarty)

**Infrastructure Planning**:
- Modules: service-account, workload-identity, managed-certificate
- Resources: 6 SAs, 6 WI bindings, 1 SSL cert, 1 GCS bucket
- Validation: NetworkPolicies (wide-open egress), Velero (CSI snapshots), Workload Identity

**Key Decisions**:
- NetworkPolicy egress: Wide-open (nonprod philosophy)
- Backup retention: 3-day (cost-optimized for nonprod)
- Phase ordering: Helm values reference SA emails from terraform config

**Planning Files**: `.claude/plans/devtest-deployment/phase-6.*.md`

---

## Phase VPN: WireGuard + AlloyDB PSC Access (Oct 30 - Nov 3) ✅ COMPLETE

**Status**: Deployed and validated

**Key Implementations**:
1. **PSC Cross-Project**: AlloyDB PSC endpoint 10.24.128.3, consumer pcc-prj-devops-nonprod
2. **DNS Architecture**: Private zones in foundation-infra, *.alloydb-psc.goog → 10.24.128.3, module dns-psc-record
3. **AlloyDB IAM Bootstrap**: Postgres password via Terraform, IAM roles (Google Workspace groups), PostgreSQL users (manual)
4. **WireGuard VPN**: Direct static IP 35.212.69.2, e2-small instance, MIG target_size=1, no NLB

**Modules**: dns-psc-record, service-account, instance-template updates (pcc-tf-library)  
**Validation**: ✅ VPN connectivity, PSC endpoint, DNS resolution, psql connection  
**Cost**: ~$15/month

---

**End of Document** | Last Updated: 2025-11-03
