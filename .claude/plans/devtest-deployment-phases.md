# Devtest Environment Deployment Phases

**Scope**: Initial deployment targeting devtest environment only
**Timeline**: Planning 10/17-10/19, Implementation starts 10/20
**Status**: ⏳ Planning in progress

---

## Overview

This plan outlines the 9 phases required to deploy the complete Apigee X pipeline infrastructure for the devtest environment. Each phase is designed to be focused, executable in 1-2 sessions, and properly sequenced with clear dependencies.

### Key Architectural Decisions

**Apigee Organizations:**
- Nonprod Apigee org: devtest + dev + staging environments
- Prod Apigee org: prod environment only (deferred to later)

**Database Strategy:**
- Single AlloyDB cluster in pcc-app-shared-infra (us-east4)
- 7 databases: auth_db_devtest, client_db_devtest, user_db_devtest, metric_builder_db_devtest, metric_tracker_db_devtest, task_builder_db_devtest, task_tracker_db_devtest
- Flyway schema migrations in CI/CD pipeline

**Container Strategy:**
- Image naming: `pcc-app-{service}` (NO environment suffix)
- Tag format: `v{major}.{minor}.{patch}.{buildid}` (e.g., v1.2.3.abc123)
- Single Artifact Registry in pcc-prj-devops-prod
- ArgoCD references specific tag per environment

**Network Architecture:**
- Existing foundation: 16 projects, 2 VPCs (prod 10.16.0.0/12, nonprod 10.24.0.0/12)
- DevOps subnets already allocated: 10.16.128.0/20 (prod), 10.24.128.0/20 (nonprod)
- Apigee nonprod subnets: 10.24.192.0/20, 10.24.208.0/20, 10.24.224.0/20, 10.24.240.0/20
- App devtest subnets (new): 10.28.0.0/20 (nodes), 10.28.16.0/20 (pods), 10.28.32.0/20 (services), 10.28.48.0/20 (overflow)

---

## Phase Breakdown

### Phase 0: Foundation - Add Apigee Projects

**Objective**: Add 2 Apigee projects to pcc-foundation-infra terraform

**Scope (Minimal):**
- Create `pcc-prj-apigee-nonprod` under pcc-fldr-si
- Create `pcc-prj-apigee-prod` under pcc-fldr-si
- Folder assignment only

**Out of Scope:**
- Subnets (deferred to Phase 7)
- API enablement (deferred to Phase 7)
- IAM bindings (deferred to Phase 7)

**Dependencies**: None

**Deliverables:**
- Updated terraform in pcc-foundation-infra/terraform/main.tf
- 2 new GCP projects created
- Projects visible in pcc-fldr-si folder

**Validation:**
- `gcloud projects list --filter="parent.id=<pcc-fldr-si-id>"`
- Verify both Apigee projects exist

**Size Estimate**: 200-300 lines of planning, ~10 new terraform resources

---

### Phase 1: Networking for Devtest

**Objective**: Configure networking for devtest application workloads and database connectivity

**Scope:**
- Create subnet for pcc-prj-app-devtest GKE cluster
- Configure Private Service Connect for AlloyDB access
- VPC configuration for service communication

**Existing Infrastructure:**
- DevOps nonprod subnet: 10.24.128.0/20 (already exists)
- DevOps prod subnet: 10.16.128.0/20 (already exists)

**New Subnets Required:**
- **pcc-prj-app-devtest** (GKE cluster subnets):
  - Primary range (nodes): 10.28.0.0/20 (pcc-prj-app-devtest)
  - Secondary range (pods): 10.28.16.0/20 (pcc-prj-app-devtest-sub-pod)
  - Secondary range (services): 10.28.32.0/20 (pcc-prj-app-devtest-sub-svc)
  - Overflow/reserved: 10.28.48.0/20 (pcc-prj-app-devtest-overflow)

**Dependencies**: Phase 0 complete (projects exist)

**Deliverables:**
- Subnet configurations in terraform
- Private Service Connect setup for AlloyDB
- Service networking configuration (PSC/VPC Service Controls)
- Firewall rules for inter-service communication

**Validation:**
- `gcloud compute networks subnets list --filter="network:nonprod"`
- Verify app-devtest subnet exists with secondary ranges
- Test Private Service Connect connectivity

**Size Estimate**: 300-400 lines of planning

---

### Phase 2: AlloyDB Cluster + 7 Databases

**Objective**: Deploy shared AlloyDB cluster with databases for all 7 microservices, including IAM and connectivity configuration

**Scope:**
- AlloyDB cluster in pcc-app-shared-infra (us-east4, high availability)
- Create 7 databases:
  - auth_db_devtest
  - client_db_devtest
  - user_db_devtest
  - metric_builder_db_devtest
  - metric_tracker_db_devtest
  - task_builder_db_devtest
  - task_tracker_db_devtest

**Database Configuration:**
- PostgreSQL compatible (AlloyDB)
- Private connectivity via Private Service Connect
- Automated backups enabled
- High availability (primary + replica):
  - Multi-zone HA: Primary and standby in different zones (us-east4-a, us-east4-b)
  - Automated daily backups with 30-day retention
  - Point-in-time recovery (PITR): 7-day window
  - RTO/RPO targets: <5min RTO, <5min RPO for HA failover

**Database Credentials & IAM:**
- 7 secrets in Secret Manager (one per database):
  - `alloydb-auth-db-devtest-creds`
  - `alloydb-client-db-devtest-creds`
  - `alloydb-user-db-devtest-creds`
  - `alloydb-metric-builder-db-devtest-creds`
  - `alloydb-metric-tracker-db-devtest-creds`
  - `alloydb-task-builder-db-devtest-creds`
  - `alloydb-task-tracker-db-devtest-creds`
- PostgreSQL username/password stored in each secret
- Automatic rotation policy (30-90 days)
- Rotation handling strategy:
  - Connection pooling: Npgsql connection pooling (built-in for .NET + PostgreSQL/AlloyDB)
  - Graceful credential refresh implementation:
    - Services monitor Secret Manager for rotation events via Cloud Logging or polling
    - On credential rotation detected:
      1. Fetch new credentials from Secret Manager
      2. Update in-memory connection string
      3. **Flush existing connection pool**: Call `NpgsqlConnection.ClearPool()` or `NpgsqlConnection.ClearAllPools()`
      4. New connections will use updated credentials
      5. Existing connections gracefully drain (max lifetime: 300s default)
    - No service restart required
    - Zero-downtime rotation with graceful connection migration
  - Connection string management:
    - Use ADO.NET connection pooling (enabled by default in .NET)
    - Configure `Max Pool Size=100`, `Connection Lifetime=300` (5 min max connection age)
  - Monitoring: Cloud Logging alerts for Secret Manager rotation events
  - Circuit breaker: Retry logic for credential refresh failures (use Polly library with exponential backoff)
  - Testing: Rotation simulation included in Phase 6 validation (trigger rotation, verify no service disruption)

**IAM Database Access (Google Groups):**
- Grant `roles/alloydb.client` to:
  - `gcp-developers@pcconnect.ai`
  - `gcp-devops@pcconnect.ai`
  - `gcp-admins@pcconnect.ai`
- Database-level grants: `CONNECT`, `CREATE`, `SELECT`, `INSERT`, `UPDATE`, `DELETE`

**Developer Local Access:**
- AlloyDB Auth Proxy setup instructions
- Connection string format for local development
- IAM authentication configuration
- Access via Google group membership (gcp-developers@pcconnect.ai)

**GKE Workload Connectivity:**
- Direct connection via Private Service Connect (configured in Phase 1)
- Services read credentials from Secret Manager at runtime
- Workload Identity bindings configured in Phase 3

**Flyway Integration:**
- Schema migrations executed via CI/CD pipeline
- Migration scripts in service repositories (infra/{service}-api-infra)
- Version-controlled schema evolution

**Dependencies**: Phase 1 complete (networking configured)

**Deliverables:**
- AlloyDB cluster terraform in pcc-app-shared-infra
- 7 database resources
- 7 Secret Manager entries with database credentials
- IAM bindings for 3 Google groups (developers, devops, admins)
- Cloud Audit Logs enabled for Secret Manager (track all access)
- Developer access documentation
- Connection configuration for services

**Validation:**
- AlloyDB cluster operational
- All 7 databases created
- Secret Manager credentials created and accessible
- IAM bindings validated for Google groups
- Connectivity test from pcc-prj-app-devtest
- Developer local connection successful via Auth Proxy
- Flyway baseline migration successful

**Size Estimate**: 400-500 lines of planning

---

### Phase 3: GKE Clusters (3 Total)

**Objective**: Deploy Autopilot GKE clusters for devops and devtest workloads with IAM, Workload Identity, and namespace configuration

**Clusters to Create:**

1. **pcc-prj-devops-nonprod** (system services)
   - Subnet: 10.24.128.0/20 (existing)
   - Purpose: Nonprod system utilities, monitoring
   - Autopilot mode

2. **pcc-prj-devops-prod** (ArgoCD primary)
   - Subnet: 10.16.128.0/20 (existing)
   - Purpose: ArgoCD, production system services
   - Autopilot mode

3. **pcc-prj-app-devtest** (application workloads)
   - Subnet: Created in Phase 1
   - Purpose: 7 microservices running in devtest
   - Autopilot mode

**Cluster Configuration:**
- Autopilot mode (Google-managed nodes)
- Private clusters (no external IPs on nodes)
- Workload Identity enabled
- Binary Authorization (future)

**Workload Identity Bindings:**
- Kubernetes SA → GCP SA mapping for each microservice (7 total):
  - `pcc-auth-api-sa` → `pcc-auth-api@pcc-prj-app-devtest.iam.gserviceaccount.com`
  - `pcc-client-api-sa` → `pcc-client-api@pcc-prj-app-devtest.iam.gserviceaccount.com`
  - `pcc-user-api-sa` → `pcc-user-api@pcc-prj-app-devtest.iam.gserviceaccount.com`
  - `pcc-metric-builder-api-sa` → `pcc-metric-builder-api@pcc-prj-app-devtest.iam.gserviceaccount.com`
  - `pcc-metric-tracker-api-sa` → `pcc-metric-tracker-api@pcc-prj-app-devtest.iam.gserviceaccount.com`
  - `pcc-task-builder-api-sa` → `pcc-task-builder-api@pcc-prj-app-devtest.iam.gserviceaccount.com`
  - `pcc-task-tracker-api-sa` → `pcc-task-tracker-api@pcc-prj-app-devtest.iam.gserviceaccount.com`

**Cross-Project IAM Bindings:**

1. **Cloud Build SA → pcc-prj-devops-prod:**
   - Role: `roles/artifactregistry.writer`
   - Purpose: Push Docker images to Artifact Registry

2. **Cloud Build SA → pcc-prj-app-devtest:**
   - Role: `roles/container.developer`
   - Purpose: Deploy container images to GKE

3. **Cloud Build SA → pcc-app-shared-infra:**
   - Role: `roles/secretmanager.secretAccessor`
   - Purpose: Read database credentials during build/deploy

4. **ArgoCD SA → pcc-prj-app-devtest:**
   - Role: `roles/container.admin`
   - Purpose: Manage Kubernetes deployments

5. **GKE Service Accounts (7) → pcc-app-shared-infra:**
   - Role: `roles/secretmanager.secretAccessor`
   - Purpose: Read database credentials at runtime

**Kubernetes Namespaces & RBAC:**

1. **Namespaces (7 total):**
   - `pcc-auth-api`
   - `pcc-client-api`
   - `pcc-user-api`
   - `pcc-metric-builder-api`
   - `pcc-metric-tracker-api`
   - `pcc-task-builder-api`
   - `pcc-task-tracker-api`

2. **RBAC Policies:**
   - ArgoCD service account: `cluster-admin` in each namespace
   - gcp-developers@pcconnect.ai: read-only access (view pods, logs)
   - gcp-devops@pcconnect.ai: admin access (all operations)
   - gcp-admins@pcconnect.ai: cluster-admin access

**Dependencies**: Phase 1 complete (app-devtest subnet exists), Phase 2 complete (service accounts need Secret Manager access)

**Deliverables:**
- 3 GKE Autopilot clusters
- 7 GCP service accounts (one per microservice)
- 7 Workload Identity bindings
- 5 cross-project IAM binding patterns (Apigee IAM deferred to Phase 7)
- 7 Kubernetes namespaces
- RBAC policies for 3 Google groups
- Cluster access configured for CI/CD
- kubectl context configurations

**Validation:**
- `kubectl get nodes` on all 3 clusters
- Workload Identity functional (test with sample pod)
- **Cross-project IAM validation checklist**:
  - [ ] Cloud Build SA can write to Artifact Registry in pcc-prj-devops-prod
    - Test: Trigger build, verify image push succeeds
  - [ ] Cloud Build SA can deploy to GKE in pcc-prj-app-devtest
    - Test: Cloud Build can run `kubectl apply` commands
  - [ ] Cloud Build SA can read secrets from pcc-app-shared-infra
    - Test: Cloud Build can fetch Secret Manager value during build
  - [ ] ArgoCD SA can manage deployments in pcc-prj-app-devtest
    - Test: ArgoCD can sync application successfully
  - [ ] GKE service accounts (7) can access Secret Manager in pcc-app-shared-infra
    - Test: Deploy test pod with Workload Identity, verify Secret Manager read succeeds
    - Verify all 7 service accounts have `roles/secretmanager.secretAccessor`
- Namespaces created: `kubectl get namespaces`
- RBAC validated: ArgoCD can deploy, developers can view
- Internal connectivity between clusters and AlloyDB

**Size Estimate**: 450-550 lines of planning

---

### Phase 4: ArgoCD on DevOps Prod Cluster

**Objective**: Deploy ArgoCD GitOps controller for automated deployments

**Scope:**
- ArgoCD installation on pcc-prj-devops-prod cluster
- App-of-apps pattern configuration
- Repository connections (GitHub)
- RBAC and access control

**ArgoCD Configuration:**
- Deploy via Helm chart
- Configure GitHub integration
- Set up application projects (one per microservice)
- Configure sync policies (automated for devtest)

**GitOps Repositories:**
- `core/pcc-app-argo-config` (ArgoCD application manifests)
- `infra/{service}-api-infra` (Kubernetes manifests per service)

**Dependencies**: Phase 3 complete (devops-prod cluster exists)

**Deliverables:**
- ArgoCD running on pcc-prj-devops-prod
- App-of-apps root application configured
- GitHub repository connections
- ArgoCD UI accessible (internal only)

**Validation:**
- ArgoCD UI accessible
- Repository connections healthy
- Can sync test application successfully

**Size Estimate**: 250-300 lines of planning

---

### Phase 5: Pipeline Library (pcc-pipeline-library)

**Objective**: Create reusable Cloud Build pipeline scripts for all microservices

**Scope:**
- Create `core/pcc-pipeline-library` repository
- 5 reusable bash scripts:
  1. `build.sh` - Build .NET 10 service, run tests, push Docker image
  2. `generate-spec.sh` - Extract OpenAPI spec from build artifacts
  3. `update-config.sh` - Update ArgoCD manifests with new image tag
  4. `wait-argocd.sh` - Wait for ArgoCD sync completion
  5. `deploy-apigee.sh` - Deploy OpenAPI spec to Apigee, create API proxy

**Cloud Build Integration:**
- Standardized cloudbuild.yaml template
- 9-step pipeline: checkout → build → test → docker → spec → argo → wait → apigee → notify
- Parameterized for service-specific configuration

**Dependencies**: Phase 4 complete (ArgoCD operational)

**Deliverables:**
- pcc-pipeline-library repository created
- 5 bash scripts with comprehensive error handling
- cloudbuild.yaml template
- Documentation for service onboarding

**Validation:**
- Scripts pass shellcheck linting
- Dry-run test with mock service
- Documentation complete

**Size Estimate**: 300-400 lines of planning

---

### Phase 6: First Service Deployment (End-to-End)

**Objective**: Deploy one microservice to Kubernetes through the CI/CD pipeline (Apigee deployment deferred to Phase 7)

**Service Selection**: `pcc-auth-api` (recommended - foundational service)

**Scope:** Phase 6 focuses on Kubernetes deployment only. API proxy deployment to Apigee (deploy-apigee.sh) is deferred to Phase 7 when Apigee infrastructure is operational.

**End-to-End Flow (Steps 1-8 only):**
1. GitHub commit triggers Cloud Build
2. build.sh: Compile .NET, run xUnit tests, build Docker image
3. Tag image: `pcc-app-auth:v1.0.0.abc123`
4. Push to Artifact Registry (pcc-prj-devops-prod)
5. generate-spec.sh: Extract OpenAPI spec from build, store in `infra/pcc-auth-api-infra/openapi.yaml`
6. update-config.sh: Update `infra/pcc-auth-api-infra` Kubernetes manifests with new image tag
7. wait-argocd.sh: ArgoCD detects change, syncs to pcc-prj-app-devtest
8. Kubernetes deployment successful, service running on GKE

**Step 9 Deferred:** deploy-apigee.sh (API proxy deployment) will be enabled in Phase 7 after Apigee nonprod org is operational.

**Validation Criteria:**
- Service healthy in GKE
- Database migrations applied via Flyway
- Health check endpoint returns 200 OK
- Logs visible in Cloud Logging
- Can manually curl service from within cluster

**Dependencies**: Phase 5 complete (pipeline library ready)

**Deliverables:**
- pcc-auth-api deployed to devtest
- Cloud Build pipeline functional
- ArgoCD GitOps sync working
- Database schema initialized

**Validation:**
- Service pods running: `kubectl get pods -n pcc-auth-api`
- Health check: `curl http://pcc-auth-api.pcc-auth-api.svc.cluster.local/health`
- Database tables created
- ArgoCD shows sync success

**Size Estimate**: 300-400 lines of planning

---

### Phase 7: Apigee Nonprod Org + Devtest Environment

**Objective**: Deploy Apigee X nonprod organization with devtest environment as API gateway, including API Product configuration

**Scope:**

1. **Network Configuration:**
   - Add 4 Apigee subnets to nonprod VPC:
     - 10.24.192.0/20 (pcc-prj-apigee-nonprod-runtime)
     - 10.24.208.0/20 (pcc-prj-apigee-nonprod-management)
     - 10.24.224.0/20 (pcc-prj-apigee-nonprod-troubleshooting)
     - 10.24.240.0/20 (pcc-prj-apigee-nonprod-overflow)

2. **Apigee Organization:**
   - Create Apigee X organization in pcc-prj-apigee-nonprod
   - Configure billing (pay-as-you-go)
   - Enable Apigee API

3. **Apigee Runtime Instance:**
   - Instance size: **SMALL** (10-50 req/s)
   - Note: Scale to MEDIUM/LARGE as needed post-deployment
   - Region: us-east4
   - Private connectivity to nonprod VPC

4. **Apigee Devtest Environment:**
   - Create devtest environment
   - Attach to runtime instance
   - Configure environment group
   - Internal hostname for GKE backend routing

5. **API Proxy Deployment:**
   - Deploy pcc-auth-api OpenAPI spec to Apigee
   - Create API proxy (auto-generated from spec)
   - Configure target backend (GKE service endpoint)
   - Test API proxy routing to GKE backend

6. **API Product Configuration:**
   - Create Apigee API product: `pcc-devtest-all-services`
   - Scopes: Define per-service scopes:
     - `auth:read`, `auth:write`
     - `client:read`, `client:write`
     - `user:read`, `user:write`
     - (Additional scopes for other services)
   - OAuth 2.0 / JWT configuration

7. **Authentication Policies (JWT Validation):**

   **Descope JWT Validation Configuration:**
   - **JWKS URL**: `https://auth.descope.com/.well-known/jwks.json`
   - **Algorithm**: RS256 (RSA signature verification)
   - **Issuer Validation**: Verify `iss` claim matches Descope issuer URL
   - **Audience Validation**: Verify `aud` claim matches expected audience (specify per environment)
   - **Expiration Validation**: Verify `exp` claim (reject expired tokens)
   - **Key Rotation**: Automatic via JWKS refresh (Apigee default behavior)

   **Header Transformation:**
   - Extract from JWT: `sub` (subject), `iss` (issuer), `aud` (audience), `exp` (expiration)
   - Pass to backend services:
     - `X-Auth-Subject`: User identifier from `sub` claim
     - `X-Auth-Issuer`: Issuer from `iss` claim
     - `X-Auth-Audience`: Audience from `aud` claim
   - Do NOT pass: Raw JWT token, `exp` timestamp (security best practice)

   **Error Handling:**
   - Expired token: 401 Unauthorized with message "Token expired"
   - Invalid signature: 401 Unauthorized with message "Invalid token signature"
   - Missing token: 401 Unauthorized with message "Authorization header required"
   - Invalid claims: 401 Unauthorized with message "Invalid token claims"

   **Cache Policy:**
   - JWT validation results: NO CACHING (validate on every request for security)
   - JWKS endpoint: Cache for 1 hour (standard practice)

8. **Developer App (for testing):**
   - Create test developer app in Apigee
   - Generate API key for devtest validation
   - Document credential usage for pipeline testing

9. **Apigee to GKE Connectivity (Private Service Connect):**
   - **PSC Service Attachment** (Producer side - GKE):
     - Expose GKE Internal HTTP(S) Load Balancer to PSC consumers
     - Service attachment in pcc-prj-app-devtest
     - Allow Apigee project (pcc-prj-apigee-nonprod) as consumer
   - **PSC Endpoint** (Consumer side - Apigee):
     - Create PSC endpoint in Apigee VPC (pcc-vpc-nonprod)
     - Target: GKE service attachment
     - Static IP allocation: 10.24.200.10 (in Apigee subnet range)
   - **GKE Ingress Configuration**:
     - Internal HTTP(S) Load Balancer auto-provisioned by GKE Ingress
     - Ingress class: `gce-internal`
     - Ingress resources for all 7 microservices
     - Path-based routing (e.g., `/auth-api/*`, `/user-api/*`)
   - **Backend Target Configuration** (see ADR-002):
     - Target type: PSC endpoint IP (10.24.200.10)
     - Protocol: HTTPS (GKE Ingress terminates TLS)
     - Port: 443
     - Connection: Private (through PSC tunnel)

10. **Apigee Service Account IAM Bindings:**
   - **Apigee Service Account → pcc-prj-app-devtest:**
     - Network access for API proxy → GKE backend routing via PSC
     - Required permissions for PSC endpoint connectivity
     - Service attachment consumer authorization

**Dependencies**: Phase 6 complete (pcc-auth-api running on GKE)

**Deliverables:**
- Apigee nonprod organization operational
- Apigee runtime instance (SMALL) deployed
- Devtest environment configured
- PSC service attachment + PSC endpoint established (Apigee ↔ GKE)
- GKE Ingress resources configured for all 7 services
- Apigee Service Account IAM bindings configured
- pcc-auth-api proxy deployed and routing to GKE via PSC
- API product `pcc-devtest-all-services` created
- Descope JWT validation policy configured
- Test developer app with API key
- Internal API endpoint accessible (via Apigee, before external LB in Phase 8)

**Validation:**
- Apigee organization healthy
- Runtime instance operational (SMALL size confirmed)
- PSC service attachment created and active
- PSC endpoint created with IP 10.24.200.10, connection status: ACCEPTED
- GKE Ingress resources created for all services
- API proxy deployed
- Internal API test: `curl http://<apigee-internal-endpoint>/devtest/auth/health`
- Request routed: Apigee → PSC Endpoint (10.24.200.10) → PSC tunnel → GKE Ingress → Service
- OpenAPI spec deployed correctly
- API product visible in Apigee console
- JWT validation policy working (test with valid/invalid tokens)
- Test API key can access endpoints
- Backend connectivity: Apigee can reach GKE service endpoints via PSC

**Size Estimate**: 450-550 lines of planning

---

### Phase 8: External HTTPS Load Balancer & Connectivity

**Objective**: Configure external HTTPS connectivity to make Apigee devtest environment accessible from the internet

**Scope:**

1. **Network Endpoint Group (NEG):**
   - **Type**: Private Service Connect NEG for Apigee
   - **Region**: us-east4 (matches Apigee runtime instance region)
   - **Target**: Apigee nonprod runtime instance (service attachment from Phase 7)
   - **Configuration**:
     - Obtain Apigee service attachment URI from Apigee org
     - Create PSC NEG in pcc-prj-apigee-nonprod or separate network project
     - NEG automatically discovers Apigee instance endpoints
   - **Note**: This NEG is for external LB → Apigee (not Apigee → GKE, which uses PSC)

2. **Backend Service:**
   - Backend service configuration for Apigee NEG
   - **Health Check Configuration**:
     - Protocol: HTTPS
     - Path: `/healthz/ingress` (Apigee X documented health endpoint for load balancer integration)
     - Port: 443
     - Check interval: 10 seconds
     - Timeout: 5 seconds
     - Healthy threshold: 2 consecutive successes
     - Unhealthy threshold: 2 consecutive failures
     - **Note**: Verify endpoint path with Apigee X documentation for your specific org configuration
   - **Session Affinity**: CLIENT_IP (recommended for consistent routing)
   - **Connection Draining**: 30 seconds timeout
   - **Protocol**: HTTPS (encrypted connection to Apigee)

3. **HTTPS Load Balancer:**
   - External Application Load Balancer (global)
   - URL map for routing:
     - Default service: Apigee backend
     - Path-based routing rules (if needed)
   - Frontend configuration:
     - Protocol: HTTPS
     - Port: 443
     - HTTP-to-HTTPS redirect enabled (port 80 → 443)

4. **SSL Certificate:**
   - Google-managed SSL certificate for `api-devtest.pcconnect.ai`
   - Certificate provisioning (automatic DNS validation)
   - Auto-renewal enabled
   - Certificate map attachment to load balancer

5. **DNS Configuration:**
   - Cloud DNS zone: `pcconnect.ai` (create if doesn't exist)
   - A record: `api-devtest.pcconnect.ai` → Load Balancer external IP
   - TTL: 300 seconds (5 minutes)
   - Verify DNS propagation

6. **SSL Policy:**
   - TLS version: 1.2 minimum (TLS 1.3 preferred)
   - Cipher suites: MODERN profile
   - HSTS (HTTP Strict Transport Security) enabled

7. **Cloud Armor (Security Configuration):**
   - Basic DDoS protection (enabled by default with external LB)
   - **Recommended for devtest**: IP allowlist to restrict access during testing
   - **Allowlist Configuration**:
     - Priority 1000: ALLOW from office IP ranges (for manual testing)
     - Priority 2000: ALLOW from GCP Cloud NAT IPs (for internal services)
     - Priority 9999: DENY all (default deny for security)
   - **Rate Limiting**: Defer for devtest (not needed for low-volume testing)
   - **Future Production**: Add rate limiting (1000 req/min per IP)

**Dependencies**: Phase 7 complete (Apigee nonprod org and runtime instance operational)

**Deliverables:**
- Network Endpoint Group (NEG) for Apigee instances
- Backend service with health checks
- External HTTPS Load Balancer configured
- Google-managed SSL certificate for `api-devtest.pcconnect.ai`
- DNS A record pointing to load balancer IP
- SSL policy configured (TLS 1.2+)
- External endpoint: `https://api-devtest.pcconnect.ai`

**Validation:**
- Load balancer provisioned and healthy
- SSL certificate ACTIVE status (DNS validation complete)
- DNS resolution: `nslookup api-devtest.pcconnect.ai` returns LB IP
- External HTTPS test: `curl https://api-devtest.pcconnect.ai/devtest/auth/health` returns 200 OK
- SSL certificate valid (not self-signed): `openssl s_client -connect api-devtest.pcconnect.ai:443`
- End-to-end flow: External client → LB → Apigee → GKE → AlloyDB
- Response time acceptable (<500ms for health check)
- HTTP-to-HTTPS redirect working: `curl -L http://api-devtest.pcconnect.ai/devtest/auth/health`

**Size Estimate**: 250-350 lines of planning

**Security Notes:**
- Load balancer is external (public internet facing)
- SSL/TLS termination at load balancer
- Apigee instance remains private (no public IP)
- Traffic flow: Internet → LB (HTTPS) → Apigee Private NEG → Apigee (internal) → GKE
- Cloud Armor provides Layer 7 DDoS protection
- Consider IP allowlist for devtest if needed (restrict to office IPs)

---

## Dependencies Summary

```
Phase 0 (Apigee Projects)
  ↓
Phase 1 (Networking)
  ↓
Phase 2 (AlloyDB + IAM + Credentials) ← also depends on Phase 0 (projects exist)
  ↓
Phase 3 (GKE Clusters + Workload Identity + IAM) ← depends on Phase 1 & Phase 2
  ↓
Phase 4 (ArgoCD)
  ↓
Phase 5 (Pipeline Library)
  ↓
Phase 6 (First Service)
  ↓
Phase 7 (Apigee Nonprod + Devtest + API Products)
  ↓
Phase 8 (External HTTPS Load Balancer)
```

---

## Success Criteria

**End-to-End Validation:**
1. GitHub commit to pcc-auth-api triggers Cloud Build
2. Pipeline builds, tests, and deploys Docker image
3. ArgoCD syncs new image to pcc-prj-app-devtest
4. Service running on GKE, connected to AlloyDB via Secret Manager credentials
5. OpenAPI spec deployed to Apigee devtest environment
6. External API call from internet routes through full stack:
   - `https://api-devtest.pcconnect.ai/devtest/auth/health`
   - External HTTPS LB → Apigee → GKE → AlloyDB
7. Response returns successfully with expected data
8. JWT authentication validates correctly through Apigee
9. Developer can connect to AlloyDB locally via Auth Proxy

**Infrastructure Health:**
- All 3 GKE clusters operational
- AlloyDB cluster with 7 databases accessible
- Workload Identity bindings functional
- Cross-project IAM permissions validated
- Secret Manager credentials accessible to services
- ArgoCD syncing successfully
- Apigee nonprod org serving API traffic
- External HTTPS Load Balancer healthy
- SSL certificate valid and active
- DNS resolving correctly (`api-devtest.pcconnect.ai`)
- Cloud Build pipelines green

---

## Future Expansion (Post-Devtest)

**Additional Environments:**
- Dev environment (nonprod Apigee, pcc-prj-app-dev GKE)
- Staging environment (nonprod Apigee, pcc-prj-app-staging GKE)
- Prod environment (separate plan - prod Apigee, pcc-prj-app-prod GKE, multi-region AlloyDB)

**Additional Services:**
- Deploy remaining 6 microservices using established pipeline
- Client API, User API, Metric Builder/Tracker, Task Builder/Tracker

**Operational Maturity:**
- Monitoring and alerting (Cloud Monitoring, Prometheus)
- Security scanning (Binary Authorization, Container Analysis)
- Cost optimization and quota management
- Disaster recovery and backup strategies

---

## Timeline

**Planning Period**: 10/17-10/19 (Fri-Sun)
- Finalize phase plans
- Review specifications
- Prepare terraform configurations

**Implementation Period**: Starting 10/20 (Mon)
- Execute phases sequentially
- 1-2 sessions per phase
- Validation gates between phases

**Estimated Duration**: 2-3 weeks for all 9 phases (Phases 0-8)

---

## References

- 📋 **Requirements**: `.claude/reference/apigee-pipeline-requirements.markdown`
- 🏗️ **ADR 001**: `.claude/docs/ADR/001-two-org-apigee-architecture.md`
- ✅ **ADR 002**: `.claude/docs/ADR/002-apigee-gke-ingress-strategy.md` (DECIDED - GKE Ingress + PSC Strategy)
- 📊 **Subnet Design**: `core/pcc-foundation-infra/.claude/reference/GCP Network Subnets - GKE Subnet Assignment Redesign.pdf`
- ✅ **Foundation State**: `core/pcc-foundation-infra/.claude/status/brief.md`
- 📝 **Phase 0 Spec**: `.claude/docs/pcc-foundation-infra-apigee-updates.md`
- 📝 **Handoff**: `.claude/handoffs/Claude-2025-10-17-14-54.md`

---

**Document Status**: ✅ Updated with agent-organizer review fixes applied
**Last Updated**: 2025-10-17 17:30 EDT
**Changes Applied:**
- Phase 1: Confirmed CIDR allocations, updated to PSC/service networking (not VPC peering)
- Phase 2: Enhanced Npgsql connection pool flush details with `ClearPool()` implementation
- Phase 3: Moved Apigee-GKE IAM bindings to Phase 7, added cross-project IAM validation checklist
- Phase 7: Complete rewrite for GKE Ingress + PSC (per ADR-002 decision, 2025-10-18)
  - PSC service attachment (producer side - GKE)
  - PSC endpoint (consumer side - Apigee, IP 10.24.200.10)
  - GKE Ingress configuration (gce-internal, path-based routing)
  - Backend target: PSC endpoint IP via HTTPS
  - Removed VPC peering references
- Phase 8: Updated to documented Apigee health endpoint `/healthz/ingress`, PSC connectivity
- ADR-002: ✅ DECIDED - GKE Ingress + PSC (2025-10-18, three-way AI consultation: Claude, Gemini, Codex)

**Previous Updates (2025-10-17 17:00 EDT):**
- Phase 2: AlloyDB HA details, credentials rotation handling, Cloud Audit Logs
- Phase 3: Cloud Build → Artifact Registry IAM
- Phase 6: Clarified deployment scope (defer Apigee to Phase 7)
- Phase 8: Cloud Armor IP allowlist, detailed NEG configuration

**Next Action**: Begin Phase 0 detailed planning (ADR-002 decision complete: GKE Ingress + PSC)
