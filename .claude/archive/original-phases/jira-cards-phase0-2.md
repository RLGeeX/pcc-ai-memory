# Devtest Deployment - Jira Cards (Phases 0-2)

## Project Overview
**Project**: PCC Devtest Environment Deployment  
**Scope**: Foundation infrastructure, networking, AlloyDB database setup, security, and developer tools  
**Timeline**: 6-8.5 hours estimated total effort  
**Team**: Platform Engineering  

---

## Epic 1: Foundation Infrastructure Setup
**Epic ID**: DEV-001  
**Priority**: High  
**Story Points**: 8  
**Duration**: 1-2 hours  
**Dependencies**: None  

### Story 1.1: Foundation Analysis & Planning
**Story ID**: DEV-001-01  
**Priority**: High  
**Story Points**: 3  
**Duration**: 15-20 minutes  
**Assignee**: Platform Engineer  

**Description:**
Review and document the existing pcc-foundation-infra repository structure to understand Terraform patterns for adding 2 new Apigee projects.

**Acceptance Criteria:**
- [ ] Repository cloned/updated to latest version
- [ ] Terraform structure documented (location of project definitions)
- [ ] Existing project patterns identified and documented
- [ ] pcc-fldr-si folder ID confirmed and documented
- [ ] Billing account ID confirmed
- [ ] Notes document created with patterns to follow

**Technical Requirements:**
- Access to core/pcc-foundation-infra repository
- Git credentials configured
- Local development environment set up

**Definition of Done:**
- Complete understanding of terraform patterns documented
- Clear path identified for adding 2 new projects
- All necessary IDs and values documented (folder ID, billing account)
- Ready to proceed to terraform code creation

---

### Story 1.2: Apigee Project Creation
**Story ID**: DEV-001-02  
**Priority**: High  
**Story Points**: 5  
**Duration**: 35-50 minutes  
**Assignee**: Platform Engineer  
**Dependencies**: DEV-001-01

**Description:**
Design, validate, and deploy Terraform configuration for creating pcc-prj-apigee-nonprod and pcc-prj-apigee-prod projects under the pcc-fldr-si folder.

**Acceptance Criteria:**
- [ ] Terraform code designed following existing foundation patterns
- [ ] Configuration validates successfully (terraform fmt, validate, plan)
- [ ] 2 new projects deployed via WARP
- [ ] Projects assigned to correct folder (pcc-fldr-si)
- [ ] Billing enabled on both projects
- [ ] Projects in ACTIVE lifecycle state
- [ ] No default VPC created (auto_create_network = false)
- [ ] Labels correctly applied
- [ ] Git commit pushed to main branch

**Technical Requirements:**
- Terraform configuration matches existing project patterns
- Placeholder values replaced with actual IDs
- WARP terminal available for deployment
- GCP credentials configured

**Definition of Done:**
- 2 Apigee projects exist in GCP
- Terraform state updated successfully
- Post-deployment validation passed
- Documentation updated
- Phase 0 complete

---

## Epic 2: Network Infrastructure
**Epic ID**: DEV-002  
**Priority**: High  
**Story Points**: 8  
**Duration**: 1-1.5 hours  
**Dependencies**: Epic 1 complete  

### Story 2.1: DevOps Subnet Standardization
**Story ID**: DEV-002-01  
**Priority**: High  
**Story Points**: 3  
**Duration**: 15-20 minutes  
**Assignee**: Platform Engineer  

**Description:**
Rename existing DevOps subnets in pcc-foundation-infra to match PDF naming convention while preserving all CIDR ranges and functionality.

**Acceptance Criteria:**
- [ ] Production subnet renamed: pcc-subnet-prod-use4 → pcc-prj-devops-prod
- [ ] NonProduction subnet renamed: pcc-subnet-nonprod-use4 → pcc-prj-devops-nonprod
- [ ] Secondary range names updated to match PDF convention (sub-pod, sub-svc)
- [ ] CIDR ranges unchanged (10.16.128.0/20, 10.24.128.0/20)
- [ ] Flow logs configuration preserved
- [ ] Private Google Access preserved
- [ ] Terraform plan shows exactly 2 resources to replace
- [ ] No unintended changes to other resources

**Technical Requirements:**
- Understanding that name changes force resource replacement
- Confirmation that no existing resources use these subnets
- Access to GCP_Network_Subnets.pdf for naming standards

**Definition of Done:**
- Terraform code updated with new naming convention
- Validation passed (no existing dependencies affected)
- Ready for deployment in next story

---

### Story 2.2: App Devtest Network Creation & Deployment
**Story ID**: DEV-002-02  
**Priority**: High  
**Story Points**: 5  
**Duration**: 25-35 minutes  
**Assignee**: Platform Engineer  
**Dependencies**: DEV-002-01

**Description:**
Create new GKE-ready subnet infrastructure for pcc-prj-app-devtest and deploy all network changes via WARP.

**Acceptance Criteria:**
- [ ] Main GKE subnet created: pcc-prj-app-devtest (10.28.0.0/20)
- [ ] Secondary ranges configured: pods (10.28.16.0/20), services (10.28.32.0/20)
- [ ] Overflow subnet created: pcc-prj-app-devtest-overflow (10.28.48.0/20)
- [ ] VPC Flow Logs enabled on both subnets
- [ ] Private Google Access enabled on both subnets
- [ ] All network changes deployed successfully via WARP
- [ ] 2 DevOps subnets renamed successfully
- [ ] No IP conflicts with existing allocations
- [ ] Terraform state updated correctly

**Technical Requirements:**
- Terraform plan shows 4 to add, 2 to destroy
- No existing resources depend on DevOps subnets
- Network connectivity validated post-deployment

**Definition of Done:**
- All 4 subnets exist in GCP with correct names and CIDRs
- Post-deployment validation passed
- Git commit pushed to main
- Network infrastructure ready for AlloyDB deployment
- Phase 1 complete

---

## Epic 3: AlloyDB Database Infrastructure
**Epic ID**: DEV-003  
**Priority**: High  
**Story Points**: 13  
**Duration**: 2-3 hours  
**Dependencies**: Epic 2 complete  

### Story 3.1: AlloyDB Module Development
**Story ID**: DEV-003-01  
**Priority**: High  
**Story Points**: 8  
**Duration**: 45-55 minutes  
**Assignee**: Platform Engineer  

**Description:**
Create a reusable Terraform module for AlloyDB clusters and design the complete database infrastructure for the devtest environment.

**Acceptance Criteria:**
- [ ] Terraform module created in pcc-tf-library/modules/alloydb-cluster/
- [ ] All 5 files created (main.tf, variables.tf, outputs.tf, versions.tf, README.md)
- [ ] Cluster configuration supports HA, automated backups, and PITR
- [ ] Module supports configurable sizing, backup settings, and database list
- [ ] Module supports optional read replica
- [ ] All variables and outputs documented
- [ ] README.md provides clear usage example
- [ ] 7 databases planned with proper naming convention
- [ ] Database specifications documented for each microservice

**Technical Requirements:**
- Module follows Terraform best practices
- Supports PSC connectivity (psc_enabled = true)
- Regional availability for HA
- Database creation via for_each loop
- Connection string outputs for downstream usage

**Module Features:**
- Configurable cluster sizing (2 vCPUs, 8 GB for devtest)
- Daily backups with 30-day retention
- 7-day PITR window
- 7 databases: auth_db_devtest, client_db_devtest, user_db_devtest, metric_builder_db_devtest, metric_tracker_db_devtest, task_builder_db_devtest, task_tracker_db_devtest

**Definition of Done:**
- Complete AlloyDB terraform module ready for use
- Database design documented
- Module ready for instantiation in pcc-app-shared-infra

---

### Story 3.2: Database Infrastructure Deployment
**Story ID**: DEV-003-02  
**Priority**: High  
**Story Points**: 5  
**Duration**: 75-90 minutes  
**Assignee**: Platform Engineer  
**Dependencies**: DEV-003-01

**Description:**
Create module call in pcc-app-shared-infra, validate terraform configuration, and deploy AlloyDB cluster with all databases via WARP.

**Acceptance Criteria:**
- [ ] Module call created in pcc-app-shared-infra/terraform/alloydb.tf
- [ ] All required variables provided (project_id, cluster_id, network_self_link)
- [ ] 7 database names configured in module call
- [ ] Module source references pcc-tf-library correctly
- [ ] Outputs defined for downstream usage (including PSC DNS name)
- [ ] Terraform validation passed (fmt, validate, plan)
- [ ] AlloyDB cluster deployed successfully via WARP
- [ ] Primary and replica instances created (2 vCPUs each)
- [ ] All 7 databases created in cluster
- [ ] PSC connectivity auto-configured by AlloyDB
- [ ] Post-deployment validation passed

**Technical Requirements:**
- Terraform plan shows ~10 resources to add
- AlloyDB cluster creation can take 15-20 minutes
- PSC DNS name available for connections
- Internal IPs assigned (not for direct connection)

**Validation Requirements:**
- [ ] Cluster ID: pcc-alloydb-cluster-devtest
- [ ] Network: pcc-vpc-nonprod
- [ ] PSC enabled with auto-created service attachment
- [ ] Backup policy enabled (30-day retention)
- [ ] PITR enabled (7-day window)
- [ ] Primary instance: REGIONAL availability
- [ ] Replica instance: READ_POOL type
- [ ] All 7 databases listed successfully

**Definition of Done:**
- AlloyDB cluster fully deployed and operational
- All databases accessible via PSC
- Connection information available for next phase
- Terraform state updated
- Git commit pushed
- Ready for security configuration

---

## Epic 4: Security & Access Management
**Epic ID**: DEV-004  
**Priority**: High  
**Story Points**: 10  
**Duration**: 1.5-2 hours  
**Dependencies**: Epic 3 complete  

### Story 4.1: Secret Management Setup
**Story ID**: DEV-004-01  
**Priority**: High  
**Story Points**: 5  
**Duration**: 25-30 minutes  
**Assignee**: Platform Engineer  

**Description:**
Design and implement Secret Manager configuration for AlloyDB database credentials with automatic rotation strategy.

**Acceptance Criteria:**
- [ ] 9 secrets designed with JSON structure:
  - 7 service user credentials (auth, client, user, metric-builder, metric-tracker, task-builder, task-tracker)
  - 1 admin user credential (pcc_admin)
  - 1 Flyway user credential (flyway_user)
- [ ] Connection strings include Npgsql pooling parameters
- [ ] Secret naming convention established: {service}-db-credentials-devtest
- [ ] Rotation strategy documented (90 days for devtest)
- [ ] Password generation method defined (32-char, high entropy)
- [ ] Terraform module structure planned for secret-manager-database

**Secret Structure Requirements:**
Each secret contains:
- username
- password (auto-generated 32-char)
- database name
- host (PSC endpoint)
- port (5432)
- connection_string (with pooling config)

**Connection Pool Settings:**
- MinPoolSize: 5
- MaxPoolSize: 20
- Pooling: enabled
- SSL Mode: Require

**Definition of Done:**
- Complete secret specifications documented
- Rotation architecture designed (Cloud Function + Scheduler)
- Ready for IAM binding implementation

---

### Story 4.2: IAM & Access Control Implementation
**Story ID**: DEV-004-02  
**Priority**: High  
**Story Points**: 5  
**Duration**: 20-25 minutes  
**Assignee**: Platform Engineer  
**Dependencies**: DEV-004-01

**Description:**
Configure comprehensive IAM bindings for AlloyDB access, Secret Manager access, and Workload Identity setup following least-privilege principles.

**Acceptance Criteria:**

**AlloyDB Access:**
- [ ] Developer group (pcc-developers@portcon.com): roles/alloydb.client
- [ ] CI/CD service account: roles/alloydb.client  
- [ ] Admin group (pcc-admins@portcon.com): roles/alloydb.admin

**Secret Manager Access:**
- [ ] 7 GKE service accounts: secretAccessor role for respective secrets
- [ ] Developer group: secretAccessor role for all 9 secrets
- [ ] CI/CD service account: secretAccessor role for Flyway secret only
- [ ] Admin group: secretmanager.admin role for all secrets

**Workload Identity Pattern:**
- [ ] GKE service account → Google service account binding documented
- [ ] Kubernetes service account annotation pattern defined
- [ ] Service account naming convention: pcc-{service}-api-sa

**IAM Binding Summary:**
- 3 principals for AlloyDB access
- 7 service accounts + 3 groups for Secret Manager access
- Minimal permissions (least privilege principle)
- Workload Identity preferred over service account keys

**Definition of Done:**
- Complete IAM binding design documented
- Terraform module enhanced with IAM configuration
- Access patterns documented for Phase 3 Kubernetes setup
- Ready for developer tools setup

---

## Epic 5: Developer Tools & Migration Framework  
**Epic ID**: DEV-005  
**Priority**: Medium  
**Story Points**: 5  
**Duration**: 1 hour  
**Dependencies**: Epic 4 complete  

### Story 5.1: Developer Access & Flyway Planning
**Story ID**: DEV-005-01  
**Priority**: Medium  
**Story Points**: 5  
**Duration**: 25-30 minutes  
**Assignee**: Platform Engineer  

**Description:**
Document AlloyDB Auth Proxy setup for local development and create Flyway migration strategy for CI/CD-based schema management.

**Acceptance Criteria:**

**Auth Proxy Setup:**
- [ ] Developer prerequisites documented (gcloud CLI, Auth Proxy binary, IAM permissions)
- [ ] Connection string format documented for devtest cluster
- [ ] Auth Proxy startup commands and options documented
- [ ] Database connection methods documented (psql, DBeaver, DataGrip)
- [ ] Developer workflow documented (daily usage pattern)
- [ ] Troubleshooting guide created (common issues and solutions)
- [ ] Alias setup documented for convenience

**Flyway Migration Strategy:**
- [ ] CI/CD architecture documented (Git → Cloud Build → Flyway → AlloyDB)
- [ ] Migration file structure defined (src/{service}-api/migrations/)
- [ ] Flyway configuration files created for each service
- [ ] Cloud Build pipeline template documented
- [ ] Flyway baseline strategy documented
- [ ] Environment variable configuration for credentials
- [ ] Migration example provided (V1__initial_schema.sql)

**Technical Requirements:**
- Auth Proxy connection via projects/pcc-prj-app-devtest/locations/us-east4/clusters/pcc-alloydb-cluster-devtest/instances/pcc-alloydb-instance-devtest-primary
- Local proxy port: 5433 (avoid conflict with local PostgreSQL)
- Flyway credentials from Secret Manager (alloydb-flyway-credentials-devtest)
- CI/CD uses AlloyDB Auth Proxy for secure connections

**Developer Workflow:**
1. Start Auth Proxy locally
2. Retrieve credentials from Secret Manager
3. Connect via preferred database tool
4. Run queries, test migrations, explore schema
5. Stop Auth Proxy

**Flyway Workflow:**
1. Developer commits SQL migration
2. Git push triggers Cloud Build
3. Cloud Build retrieves Flyway credentials
4. Flyway applies migrations via Auth Proxy
5. Schema history updated automatically

**Definition of Done:**
- Complete developer documentation created
- Auth Proxy setup guide ready
- Flyway migration strategy documented
- Cloud Build pipeline templates ready
- Troubleshooting guides available
- Ready for Phase 3 (Kubernetes deployment)

---

## Summary

### Epic Overview
| Epic | Story Points | Duration | Key Deliverables |
|------|--------------|----------|------------------|
| **Epic 1**: Foundation Infrastructure | 8 | 1-2 hours | 2 Apigee projects deployed |
| **Epic 2**: Network Infrastructure | 8 | 1-1.5 hours | 4 subnets configured |
| **Epic 3**: AlloyDB Infrastructure | 13 | 2-3 hours | Database cluster + 7 databases |
| **Epic 4**: Security & Access | 10 | 1.5-2 hours | Secrets + IAM configured |
| **Epic 5**: Developer Tools | 5 | 1 hour | Auth Proxy + Flyway documented |

### Total Project Scope
- **44 Story Points**
- **6-8.5 Hours Estimated**
- **5 Epics, 9 User Stories**
- **Dependencies**: Linear progression (Epic 1 → 2 → 3 → 4 → 5)

### Key Milestones
1. **Phase 0 Complete**: Foundation projects deployed
2. **Phase 1 Complete**: Network infrastructure ready
3. **Phase 2 Complete**: AlloyDB cluster operational with security configured
4. **Ready for Phase 3**: Kubernetes deployment can begin

### Risk Mitigation
- AlloyDB deployment is the longest operation (15-25 minutes)
- Network changes involve resource replacement (safe due to no dependencies)
- WARP terminal used for all deployments to minimize errors
- Comprehensive validation steps included in each story

### Next Phase
After completion of these epics, the infrastructure will be ready for:
- **Phase 3**: Kubernetes/GKE cluster deployment
- **Phase 4**: Microservice deployment
- **Phase 5**: CI/CD pipeline setup
- **Phase 6**: Monitoring and alerting