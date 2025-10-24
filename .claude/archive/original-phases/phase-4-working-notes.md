# Phase 4 Working Notes: ArgoCD Dual-Cluster Deployment

**Status**: Planning - Subagent Review in Progress
**Date**: 2025-10-22
**Scope**: Deploy ArgoCD to both devops-nonprod and devops-prod clusters

---

## Overview

**Total Subphases**: 14 (sequential numbering 4.1 through 4.14)
**Strategy**: Test in nonprod → validate → deploy to prod
**Key Decision**: Nonprod ArgoCD is for testing ArgoCD itself (upgrades/config), Prod ArgoCD manages all application clusters

**Phase Numbering**:
- Planning: 4.1, 4.2, 4.3, 4.4, 4.5 (5 subphases)
- Nonprod Deployment: 4.6, 4.7, 4.8 (3 subphases)
- Prod Deployment: 4.9, 4.10 (2 subphases)
- Integration & Validation: 4.11, 4.12, 4.13, 4.14 (4 subphases)

**DNS Naming** (regional for future Active/Active):
- Nonprod: `argocd-nonprod-east4.pcconnect.ai`
- Prod: `argocd-east4.pcconnect.ai`

---

## Subphase Breakdown

### Planning Phases (4 subphases)

#### Phase 4.1: Core Architecture Planning (15-20 min)

**Objective**: Document dual-cluster architecture, roles, and upgrade workflow

**Activities**:
- Define cluster roles:
  - **Nonprod**: Testing ArgoCD upgrades/configuration changes ONLY (does not manage any clusters)
  - **Prod**: Production ArgoCD that manages all application clusters (app-devtest, future app-staging, app-prod)
- Document managed cluster strategy:
  - Prod ArgoCD manages app-devtest via Connect Gateway
  - Future: app-staging, app-prod clusters
- Create architecture diagram showing:
  - Nonprod cluster (testing only, no managed clusters)
  - Prod cluster (manages app-devtest)
  - Connect Gateway connections
  - Service account authentication flow
  - Network paths (private clusters + Connect Gateway)
- Document upgrade testing workflow:
  1. Test new Helm chart version in nonprod
  2. Validate ArgoCD functionality (sync test app, check UI, verify RBAC)
  3. Run hello-world app sync test
  4. Monitor for 24-48 hours
  5. If stable, apply same version to prod
  6. Monitor prod for 24 hours
  7. Document any issues and rollback procedure
- Document configuration differences between nonprod and prod:
  - Nonprod: Single replica, minimal resources
  - Prod: HA configuration (Redis HA, multiple replicas)

**Deliverables**:
- Architecture document with dual-cluster roles
- Architecture diagram (visual flow)
- Managed cluster strategy document
- Upgrade testing workflow (step-by-step)
- Configuration differences matrix

**Dependencies**:
- **Phase 4.0 completed** - Required GCP APIs enabled (dns, storage) (BLOCKING - must complete before Phase 4.6)
- Phase 3 complete (3 GKE clusters operational)
- Phase 3.0 complete (container, compute APIs enabled)
- Phase 3.1 complete (gkehub, connectgateway APIs enabled)
- ArgoCD service accounts created with IAM bindings (Phase 3)
- Connect Gateway configured (Phase 3)

---

#### Phase 4.2: Security and Access Planning (15-20 min)

**Objective**: Plan Google SSO integration, RBAC, ingress strategy, and security controls

**Activities**:
- **Google SSO integration** planning:
  - OAuth 2.0 provider configuration (Google Workspace)
  - OAuth consent screen setup
  - Authorized domains configuration
  - Callback URL planning for both clusters:
    - Nonprod: `https://argocd-nonprod-east4.pcconnect.ai/api/dex/callback`
    - Prod: `https://argocd-east4.pcconnect.ai/api/dex/callback`
  - Group membership mapping (Google groups → ArgoCD RBAC)
  - **OAuth 2.0 Security Configuration**:
    - PKCE enforcement: Require code_challenge_method=S256 in all auth requests
    - State parameter: Generate cryptographically random 32-byte state per request, validate in callback
    - Token validation:
      - Verify JWT signature using Dex public key (JWKS endpoint)
      - Validate issuer claim matches: https://argocd-{env}.pcconnect.ai
      - Verify audience claim includes ArgoCD client ID
      - Check exp claim is in future
      - Cache JWKS for 24 hours max, with fallback refresh on key miss
    - Scope limitations: Request only [openid, profile, email]
    - Offline token handling:
      - Store refresh tokens in Kubernetes secret (encrypted at rest via etcd)
      - Implement refresh token rotation every 90 days
      - Auto-refresh 5 minutes before expiration
      - Log all refresh token usage to audit logs
  - Session timeout and refresh token policies:
    - Idle session timeout: 15 minutes (developers), 30 minutes (devops)
    - Absolute session timeout: 8 hours (max session duration)
    - Refresh token expiration: 30 days
    - ID token expiration: 1 hour
  - Fallback local admin account strategy:
    - Storage: Secret Manager secret `argocd-admin-password-{env}`
    - Encryption: Cloud KMS key `argocd-secret-key-{env}`
    - Access control: Only argocd service account + gcp-security-admins group
    - Rotation: Every 90 days (automated via Cloud Scheduler)
    - Emergency use: Requires approval from 2 security admins, change password within 24 hours
- **RBAC design** (namespace-aware):
  - gcp-developers@pcconnect.ai:
    - Default: `view` role on all namespaces (includes sync permissions - small team trust model)
    - Exception: `admin` role in `pcc-devtest` namespace only
    - Permissions: View apps, logs, sync status; CAN sync (trusted team)
  - gcp-devops@pcconnect.ai:
    - `admin` role on all namespaces
    - Permissions: Full admin (all operations)
  - Service account RBAC for automation:
    - gcp-cicd-operators: `sync-only` role for CI/CD automation
    - Create/patch applications, sync apps only
  - Create detailed RBAC policy matrix with Kubernetes RBAC rules
  - **Emergency access (break-glass)**:
    - Local admin account for SSO outages
    - Access logged and audited every 6 months
    - Requires 2-person approval
- **Ingress strategy**:
  - Ingress controller: GKE Ingress
  - TLS certificate management: Google-managed SSL certificates
  - **Pre-requisites**: DNS records created before Ingress deployment
  - DNS naming convention (regional for future Active/Active):
    - Nonprod: `argocd-nonprod-east4.pcconnect.ai`
    - Prod: `argocd-east4.pcconnect.ai`
  - **TLS version enforcement**: TLS 1.2+ minimum (GCP SSL policy)
  - Cloud Armor integration for DDoS protection:
    - Rate limiting: 100 requests/min per IP
    - Geographic restrictions: US only
    - WAF rules: Block suspicious patterns
    - Ban duration: 10 minutes after 1000 requests/min
  - **Certificate monitoring**: Alert if cert expires in <30 days
- **Security checklist**:
  - Public ingress security (enforce Google SSO, no anonymous access)
  - TLS policies (TLS 1.2+ only, HTTP→HTTPS redirect)
  - Secret management (admin password, GitHub tokens in Secret Manager)
  - Network security controls (Cloud Armor, firewall rules, egress controls)
  - **Audit logging requirements**:
    - ArgoCD RBAC audit logging at DEBUG level
    - Log user identity, timestamp, operation, resource, result
    - Destination: Cloud Logging → BigQuery in pcc-prj-logging-monitoring
    - Retention: 90 days
    - Alerting: Auth failures (3 in 5 min), RBAC denials, admin account usage
  - **Session security**:
    - HttpOnly, Secure, SameSite=Lax cookie flags
    - Token revocation on logout
    - Tokens transmitted only over HTTPS
  - **Credential rotation schedule**:
    - GitHub SSH key: 90 days
    - ArgoCD admin password: 90 days (automated)
    - OAuth client secret: 90 days
    - Dex TLS cert: Auto-renewal (Google-managed)

**Deliverables**:
- Google SSO configuration plan (OAuth 2.0 setup guide with PKCE, JWT validation, token security)
- RBAC policy specification (detailed matrix with namespace scoping, Kubernetes RBAC rules, break-glass procedure)
- Ingress strategy document (GKE Ingress, Google-managed SSL, DNS pre-provisioning, TLS 1.2+ enforcement)
- Cloud Armor security policy (rate limiting 100 req/min, geographic restrictions, WAF rules)
- Session security controls (timeouts, cookie flags, token revocation)
- Audit logging strategy (90-day retention, BigQuery sink, alerting rules)
- Credential rotation schedule (90-day cycle for all secrets)
- DNS records planning (A records for both clusters, created before SSL certs)

**Dependencies**:
- Phase 4.1 complete (architecture defined)
- Google Workspace admin access available
- DNS zone management access available
- Secret Manager permissions in devops-nonprod and devops-prod projects
- Cloud KMS key for admin password encryption
- BigQuery dataset in pcc-prj-logging-monitoring for audit logs

---

#### Phase 4.3: Repository and Integration Planning (10-15 min)

**Objective**: Plan GitHub integration, secret management, and monitoring strategy

**Activities**:
- **GitHub integration strategy**:
  - Repository scope: `core/pcc-app-argo-config` only in Phase 4
  - **Authentication method**: GitHub App with Workload Identity (recommended modern approach)
    - **Why GitHub App over SSH keys**: No SSH key management, token auto-rotation, fine-grained permissions, audit logging
    - **Workload Identity setup**: ArgoCD repo-server service account → GCP service account → GitHub App authentication
    - **GitHub App permissions**: Read-only access to `core/pcc-app-argo-config` repository
    - **Token storage**: GitHub App installation token in Secret Manager, auto-rotated every 1 hour by GitHub
  - Repository URL format: `https://github.com/ORG/pcc-app-argo-config.git`
  - Access permissions: Read-only (ArgoCD only needs to pull)
  - **Fallback**: If GitHub App not feasible, use fine-grained personal access token (NOT classic PAT)
- **Secret management approach**:
  - **GitHub App credentials**: Stored in Secret Manager, mounted to ArgoCD repo-server pods via Kubernetes secret
    - Secret Manager secret: `argocd-github-app-credentials` (contains app ID, installation ID, private key)
    - Kubernetes secret: `argocd-repo-creds` (mounts Secret Manager secret to repo-server pods)
    - **IAM binding**: ArgoCD repo-server KSA → GCP SA with `secretmanager.secretAccessor` role
    - **Workload Identity annotation**: `iam.gke.io/gcp-service-account=argocd-repo-server@PROJECT.iam.gserviceaccount.com`
  - ArgoCD admin password: Secret Manager (fallback for SSO issues)
  - **Secret rotation procedure and schedule**: Quarterly rotation for admin password, GitHub App tokens auto-rotate hourly
  - Access control for secrets: Only ArgoCD namespace, only ArgoCD pods (enforced via Workload Identity + IAM)
- **Monitoring and observability strategy**:
  - **Primary monitoring tool**: Google Cloud Observability (Cloud Monitoring) - NO Prometheus/Grafana
  - **Metrics collection**: ArgoCD metrics scraped via GKE Workload Metrics (auto-collected from /metrics endpoint)
  - **Alert policies** (Cloud Monitoring alert thresholds based on ArgoCD community best practices):
    - **Sync failures**: Alert if application out-of-sync >15 minutes (condition: `argocd_app_sync_total{phase="Failed"}`)
    - **Application health degraded**: Alert if application unhealthy >15 minutes (condition: `argocd_app_health_status != "Healthy|Progressing"`)
    - **Auto-sync disabled**: Alert if auto-sync disabled >2 hours (condition: `argocd_app_info{autosync_enabled="false"}`)
    - **API server latency**: Alert if p99 latency >5s for 5 minutes (condition: `histogram_quantile(0.99, argocd_http_request_duration_seconds)`)
    - **Repository server errors**: Alert if error rate >5% for 5 minutes (condition: `rate(argocd_git_request_total{request_type="fetch",status!~"2.."}[5m])`)
    - **Controller sync queue backlog**: Alert if sync queue >50 applications for 10 minutes (condition: `argocd_app_controller_queue_depth`)
    - **Redis connection failures**: Alert if Redis unavailable >2 minutes (condition: `argocd_redis_request_total{success="false"}`)
  - **Notification channels**: Email alerts to `gcp-devops@pcconnect.ai`, Cloud Logging integration for audit trails
  - **Dashboard**: Use GKE Workloads dashboard in Cloud Console for ArgoCD pod metrics
  - **Key metrics to track**: sync status, app health, API latency (p50/p95/p99), sync duration, repo fetch errors, Redis health
- **Backup and disaster recovery**:
  - **ArgoCD application manifests**: Stored in Git (`core/pcc-app-argo-config`) - Git is source of truth
  - **Redis data backup**: Daily automated backup of Redis PVC snapshots to Cloud Storage (nonprod: optional, prod: required)
    - Backup schedule: Daily at 2 AM UTC via CronJob
    - Retention: 30 days (rolling window)
    - Restore procedure: Create new PVC from snapshot, update Redis StatefulSet volume claim
  - **Recovery objectives** (RPO/RTO):
    - **RPO (Recovery Point Objective)**: 24 hours maximum data loss
      - Daily backups at 2 AM UTC mean worst-case scenario loses up to 24 hours of Redis state
      - ArgoCD application manifests have zero data loss (Git is source of truth)
      - Note: Redis stores session data and sync state, not application configuration
    - **RTO (Recovery Time Objective)**: 30-45 minutes total downtime
      - Helm deployment restoration: 10-15 minutes (ArgoCD installation)
      - Redis backup restoration: 10-15 minutes (PVC from Cloud Storage snapshot)
      - GitHub App credential reconfiguration: 5 minutes (from Secret Manager)
      - Application auto-sync: 5-10 minutes (ArgoCD syncs from Git)
      - Validation and testing: 5 minutes
    - **Impact window**: Up to 24 hours of Redis session data loss, but application state fully recoverable from Git
  - **Disaster recovery procedure**:
    1. Restore ArgoCD Helm deployment to new cluster (Phase 4.7/4.5 procedure)
    2. Restore Redis PVC from latest snapshot (prod only)
    3. Reconfigure GitHub App credentials from Secret Manager
    4. ArgoCD auto-syncs applications from Git repository
  - **Regional failover plan**: Future Active/Active with west region (Phase 5+)

**Deliverables**:
- Repository connection strategy document (GitHub App + Workload Identity, read-only access)
- Secret management approach (Secret Manager for GitHub App credentials, mounted to GKE via Kubernetes secret)
- Monitoring and alerting requirements (Google Cloud Observability, 7 alert policies with thresholds)
- Backup and DR procedure (Git-based recovery, Redis PVC snapshots, 30-day retention)

**Dependencies**:
- Phase 4.2 complete (security strategy defined)
- GitHub organization admin access available (to create GitHub App)
- Access to `core/pcc-app-argo-config` repository
- Secret Manager API enabled
- Cloud Monitoring configured

---

#### Phase 4.4: Plan ArgoCD Installation Configuration (20-30 min)

**Objective**: Create Helm values.yaml for both clusters and select ArgoCD version

**Activities**:
- **Select Helm chart version** (with documented rationale):
  - **Selected**: v3.1.9 (latest stable as of Oct 2025)
  - **Rationale**: Latest stable, includes Redis HA improvements, security fixes over v3.0.x
  - **Minimum Kubernetes version**: 1.27+
  - **Applied to**: BOTH nonprod and prod (version parity required for testing)
  - **Upgrade path**: Test upgrades in nonprod first, then apply to prod after 24-48 hour validation
  - **Rollback procedure**: Helm rollback to previous version (downtime ~5-10 min)
  - Use HA manifest for prod: `argocd/v3.1.9/manifests/ha/install.yaml`
  - Use standard manifest for nonprod: `argocd/v3.1.9/manifests/install.yaml`
- Create **values-nonprod.yaml**:
  - **Public ingress** (LoadBalancer with reserved static IP + Google SSO authentication):
    - Controller: GKE Ingress (managed by GKE, uses Google Cloud Load Balancer)
    - TLS termination: At GKE Load Balancer (Google-managed SSL certs from Phase 4.5)
    - Hostname: `argocd-nonprod-east4.pcconnect.ai`
    - TLS policy: TLS 1.2+ minimum, HTTP redirect to HTTPS (301)
    - Annotations:
      - `ingress.gce.io/pre-shared-cert: argocd-nonprod-east4-pcconnect-ai` (from Phase 4.5)
      - `cloud.google.com/armor-config: argocd-cloud-armor` (from Phase 4.5)
  - **Single replica** configuration (sufficient for testing):
    - API server: 1 replica
    - Repo server: 1 replica
    - Application controller: 1 replica
    - Redis: 1 instance (ephemeral storage acceptable for nonprod)
    - Dex: 1 replica (in-memory storage acceptable for nonprod)
    - Notifications controller: 1 replica (enabled)
    - ApplicationSet controller: 1 replica (enabled)
  - **Resource requests/limits** per component:
    - API server: requests (250m CPU, 256Mi mem), limits (500m CPU, 512Mi mem)
    - Repo server: requests (500m CPU, 512Mi mem), limits (1000m CPU, 1024Mi mem)
    - Application controller: requests (250m CPU, 256Mi mem), limits (500m CPU, 512Mi mem)
    - Redis: requests (100m CPU, 128Mi mem), limits (250m CPU, 256Mi mem)
    - Dex: requests (100m CPU, 128Mi mem), limits (250m CPU, 256Mi mem)
  - **Google SSO configuration** (OAuth 2.0 with groups via service account):
    - Callback URL: `https://argocd-nonprod-east4.pcconnect.ai/api/dex/callback`
    - Groups claim: Google Workspace groups
  - **RBAC configuration** (ArgoCD roles + Google groups):
    - Admin role: `gcp-devops@pcconnect.ai` (all namespaces)
    - Read-only role: `gcp-developers@pcconnect.ai` (default)
    - Developer-admin role: `gcp-developers@pcconnect.ai` (ONLY pcc-devtest namespace)
- Create **values-prod.yaml**:
  - **Public ingress** (LoadBalancer with reserved static IP + Google SSO authentication):
    - Controller: GKE Ingress (managed by GKE, uses Google Cloud Load Balancer)
    - TLS termination: At GKE Load Balancer (Google-managed SSL certs from Phase 4.5)
    - Hostname: `argocd-east4.pcconnect.ai`
    - TLS policy: TLS 1.2+ minimum, HTTP redirect to HTTPS (301)
    - Annotations:
      - `ingress.gce.io/pre-shared-cert: argocd-east4-pcconnect-ai` (from Phase 4.5)
      - `cloud.google.com/armor-config: argocd-cloud-armor` (from Phase 4.5)
  - **HA configuration** (production-grade):
    - API server: 3 replicas (with pod anti-affinity - preferredDuringScheduling)
    - Repo server: 2 replicas (with pod anti-affinity - preferredDuringScheduling)
    - Application controller: 1 replica (sharding not needed for Phase 4 scope)
    - Redis: 3 replicas (HA mode with Sentinel + HAProxy)
    - Dex: 1 replica (with Redis backing store for session persistence)
    - Notifications controller: 1 replica (enabled)
    - ApplicationSet controller: 1 replica (enabled)
  - **Pod anti-affinity rules** (for API server and repo server):
    - Type: preferredDuringSchedulingIgnoredDuringExecution (soft affinity)
    - Topology key: `kubernetes.io/hostname` (spread across nodes)
    - Weight: 100 (high preference)
    - **Node count requirement**: Minimum 3 nodes (preferably 4+) for HA failover
  - **Redis persistence** (CRITICAL for session data):
    - Persistence enabled: Yes
    - Storage type: RDB snapshots with snapshotting (`save 900 1 300 10 60 10000`)
    - PersistentVolumeClaim: 10GB per Redis replica, storage class `standard-rwo` or `premium-rwo`
    - Backup procedure: Daily backup of Redis data to Cloud Storage (gsutil sync)
    - Restore procedure: Restore from backup on cluster failure
    - Session data retention: 24 hours TTL for API tokens
  - **Dex session storage** (CRITICAL for OAuth persistence):
    - Storage type: Redis (not in-memory)
    - Connection: Shared Redis HA cluster (same as ArgoCD session data)
    - Benefit: Dex sessions survive pod restarts, supports horizontal scaling
  - **Resource requests/limits** per component:
    - API server: requests (250m CPU, 256Mi mem), limits (500m CPU, 512Mi mem)
    - Repo server: requests (500m CPU, 512Mi mem), limits (1000m CPU, 1024Mi mem)
    - Application controller: requests (250m CPU, 256Mi mem), limits (500m CPU, 512Mi mem)
    - Redis (per replica): requests (100m CPU, 128Mi mem), limits (250m CPU, 256Mi mem)
    - Dex: requests (100m CPU, 128Mi mem), limits (250m CPU, 256Mi mem)
  - **Google SSO configuration** (OAuth 2.0 with groups via service account):
    - Callback URL: `https://argocd-east4.pcconnect.ai/api/dex/callback`
    - Groups claim: Google Workspace groups
  - **RBAC configuration** (ArgoCD roles + Google groups):
    - Admin role: `gcp-devops@pcconnect.ai` (all namespaces, permissions: create/read/update/delete/sync/override/exec)
    - Read-only role (custom): `gcp-developers@pcconnect.ai` (default, permissions: read only - view apps/logs/status)
    - Developer-admin role (custom, namespace-scoped): `gcp-developers@pcconnect.ai` (ONLY pcc-devtest namespace, permissions: admin)
    - RBAC policy format: `policy.csv` with role definitions and group bindings
- Document ingress/DNS requirements
- Document Cloud Armor and SSL certificate requirements (for Phase 4.5 terraform)

**Deliverables**:
- **Helm chart version** selected and documented: v3.1.9 (with rationale and rollback procedure)
- **values-nonprod.yaml** created with:
  - Single-replica configuration (1 of each component)
  - Public GKE Ingress with Google-managed SSL
  - Resource requests/limits for all components
  - Google SSO with callback URL
  - RBAC policies (ArgoCD roles + Google groups)
  - Ephemeral storage (acceptable for nonprod testing)
- **values-prod.yaml** created with:
  - HA configuration (3 API, 2 repo, 3 Redis, 1 controller, 1 Dex)
  - Pod anti-affinity rules (soft affinity across nodes)
  - Redis persistence (RDB snapshots, 10GB PVC per replica, backup/restore procedure)
  - Dex Redis backing store (session persistence)
  - Resource requests/limits for all components
  - Google SSO with callback URL
  - RBAC policies (same as nonprod)
  - Public GKE Ingress with Google-managed SSL and Cloud Armor
- **Ingress/DNS requirements** document:
  - Static IPs: 2 (nonprod, prod)
  - DNS names: argocd-nonprod-east4.pcconnect.ai, argocd-east4.pcconnect.ai
  - Google-managed SSL certs: 2 (nonprod, prod)
  - TLS policy: TLS 1.2+, HTTP→HTTPS redirect
- **GCP resource requirements** list (input for Phase 4.5 terraform):
  - 2 reserved static external IPs
  - 2 Google-managed SSL certificates
  - 2 DNS A records
  - 1 Cloud Armor security policy (DDoS protection, rate limiting)
- **Operational procedures**:
  - Redis backup/restore procedure (daily snapshots to Cloud Storage)
  - Session recovery on pod restart
  - Upgrade testing workflow (nonprod 24-48hr → prod)
  - Node count requirements (minimum 3 nodes for HA)

**Dependencies**:
- Phase 4.1/B/C complete (architecture and security planned)
- Google Workspace OAuth 2.0 configuration available
- Understanding of ArgoCD HA requirements (3 node minimum for pod anti-affinity)

---

#### Phase 4.5: Create Terraform for ArgoCD GCP Resources (20-30 min)

**Objective**: Create terraform for GCP resources supporting ArgoCD ingress and security

**Repository Decision**: `infra/pcc-app-shared-infra` (existing shared infrastructure repo)
- **Rationale**: ArgoCD ingress IPs and certs are foundational shared infrastructure, aligns with existing pattern, single point of management
- **File**: `terraform/argocd-ingress.tf` (calls generic modules from `pcc-tf-library`)
- **Module Architecture**: Uses generic reusable modules (compute-address, dns-record, ssl-certificate, etc.) NOT use-case-specific modules

**Activities**:
- **Cloud Armor security policy**:
  - Create policy: `argocd-cloud-armor` (DDoS protection + rate limiting)
  - DDoS rules: Conservative thresholds (adjust post-Phase 4.7 metrics)
  - Rate limiting: 10 requests/min per IP (initial protection, tune after baseline)
  - IP allowlisting: Optional (defer to operational needs)
  - **Module**: `pcc-tf-library/modules/cloud-armor-policy` (generic security policy module)
  - **Backend service attachment**: GKE Ingress auto-creates backend service; Cloud Armor attaches via ingress annotation (`cloud.google.com/armor-config`)
  - **Note**: Created in Phase 4.5 (not deferred) because Helm values.yaml references it in annotations
- **Reserved static external IPs** (created FIRST):
  - Nonprod: `argocd-nonprod-east4-ip` (region: us-east4)
  - Prod: `argocd-east4-ip` (region: us-east4)
  - **Module**: `pcc-tf-library/modules/compute-address` (generic static IP module)
  - Purpose: Load balancer frontend IP (GKE Ingress service)
- **DNS A records** (created SECOND, immediately after IPs):
  - Nonprod: `argocd-nonprod-east4.pcconnect.ai` → reserved IP address
  - Prod: `argocd-east4.pcconnect.ai` → reserved IP address
  - Zone: `pcconnect.ai` (existing Cloud DNS zone)
  - TTL: 300 seconds (5 minutes)
  - **Module**: `pcc-tf-library/modules/dns-record` (generic DNS A record module)
  - **CRITICAL**: DNS records MUST exist before SSL cert creation (cert validation requires DNS)
- **Google-managed SSL certificates** (created THIRD, after DNS validation):
  - Nonprod: `argocd-nonprod-east4-pcconnect-ai` (domain: argocd-nonprod-east4.pcconnect.ai)
  - Prod: `argocd-east4-pcconnect-ai` (domain: argocd-east4.pcconnect.ai)
  - **Module**: `pcc-tf-library/modules/ssl-certificate` (generic managed SSL cert module)
  - Validation: Automatic via DNS (Google validates A record exists)
  - **Deployment Strategy**: Create DNS first (`terraform apply -target=module.argocd_*_dns`), then certs
  - Auto-renewal: Managed by Google (90-day rotation, fully automated)
- **SSL Policy** (ADDITIONAL RESOURCE - missing from original plan):
  - Create SSL policy: `argocd-ssl-policy-tls12` (enforce TLS 1.2+)
  - Min TLS version: 1.2
  - Profile: MODERN (recommended ciphers)
  - **Module**: `pcc-tf-library/modules/ssl-policy` (generic SSL policy module)
  - **Rationale**: Enforces TLS 1.2+ requirement from Phase 4.4 ingress spec
- **HTTP-to-HTTPS Redirect** (ADDITIONAL RESOURCE - missing from original plan):
  - Configure via GKE Ingress annotation: `kubernetes.io/ingress.allow-http: "false"`
  - Alternatively: Create HTTP URL map with 301 redirect to HTTPS
  - **Rationale**: Enforces HTTPS-only access (Phase 4.4 TLS policy requirement)
- **Terraform variables**:
  - Environment differentiation: `environment` variable (nonprod, prod)
  - Regional support: `region` variable (us-east4, future us-west1 for Active/Active)
  - DNS zone: `dns_zone` variable (pcconnect.ai)
  - Reusable pattern for future multi-region expansion
- **Terraform outputs**:
  - Static IPs: `argocd_nonprod_ip`, `argocd_prod_ip`
  - SSL cert names: `argocd_nonprod_cert`, `argocd_prod_cert`
  - Cloud Armor policy: `argocd_armor_policy_name`
  - SSL policy: `argocd_ssl_policy_name`
  - **Usage**: Phase 4.7/4.5 Helm values.yaml references these outputs in ingress annotations
- **IAM Permissions** (document required for deployer):
  - `compute.addresses.create` (reserved IPs)
  - `compute.sslCertificates.create` (Google-managed certs)
  - `compute.sslPolicies.create` (SSL policies)
  - `compute.securityPolicies.create` (Cloud Armor)
  - `dns.resourceRecordSets.create` (DNS A records)
  - **Note**: Least-privilege principle - only what terraform needs

**Deliverables**:
- **Terraform configuration** in `infra/pcc-app-shared-infra/terraform/argocd-ingress.tf`:
  - 8 module calls to generic `pcc-tf-library` modules:
    - 2 compute-address modules (nonprod + prod reserved IPs)
    - 2 dns-record modules (nonprod + prod A records)
    - 2 ssl-certificate modules (nonprod + prod managed certs)
    - 1 cloud-armor-policy module (security policy)
    - 1 ssl-policy module (TLS 1.2+ enforcement)
  - Variables for environment/region differentiation
  - Outputs for Helm ingress annotations (IPs, cert names, policy names)
- **Resource dependency ordering** documented:
  1. Reserved IPs created first (compute-address modules)
  2. DNS A records created second (dns-record modules reference IPs)
  3. SSL certificates created third (ssl-certificate modules require DNS validation)
  4. Cloud Armor + SSL policies (order-independent)
- **Deployment strategy** documented:
  - Phase 1: `terraform apply -target=module.argocd_nonprod_ip -target=module.argocd_prod_ip` (IPs)
  - Phase 2: `terraform apply -target=module.argocd_nonprod_dns -target=module.argocd_prod_dns` (DNS)
  - Phase 3: `terraform apply` (all remaining modules, including SSL certs)
  - **Rationale**: SSL cert validation requires DNS A record to exist
- **IAM permissions checklist** for deployer
- **Terraform validation passed**:
  - `terraform validate` (syntax check)
  - `terraform fmt` (formatting)
  - `tflint` (style violations)
  - `tfsec` (security audit)
  - `terraform plan` shows 8 new resources (0 deletions, 0 replacements)
- **Ready for Phase 4.7/4.5**: Terraform plan reviewed, outputs match ingress annotation requirements

**Dependencies**:
- Phase 4.4 complete (ingress requirements documented)
- **Phase 4.0 completed** - Required GCP APIs enabled (dns, storage)
- Phase 3.0 complete (container, compute APIs enabled)
- DNS zone `pcconnect.ai` exists and accessible
- IAM permissions for Compute addresses, SSL certs, Cloud Armor, Cloud DNS

**Note**: This terraform will be applied BEFORE ArgoCD Helm installation to ensure IPs and SSL certs are available for ingress configuration

---

#### Phase 4.6: Apply Terraform for ArgoCD Nonprod Infrastructure (15-20 min)

**Objective**: Deploy GCP resources for nonprod ArgoCD ingress and security

**⚠️ IMPORTANT for Claude Code Execution**: Before presenting ANY command block in this phase, Claude MUST explicitly remind the user: "Please open WARP terminal now to execute the following commands." Wait for user acknowledgment before proceeding with command presentation.

**Execution Structure**: Sequential terraform deployment in 3 stages
1. **Stage 1: Reserve Static IPs** (2-3 min) - Create external IP addresses
2. **Stage 2: Configure DNS** (3-5 min) - Create DNS A records pointing to IPs
3. **Stage 3: Deploy Certificates & Policies** (8-10 min) - SSL certs, Cloud Armor, SSL policy

**Key Context**:
- Terraform configuration: `infra/pcc-app-shared-infra/terraform/argocd-ingress.tf` (from Phase 4.5)
- Target environment: Nonprod only (argocd-nonprod-east4.pcconnect.ai)
- Total resources: 4 resources for nonprod (IP, DNS, SSL cert, shared policies)
- Deployment strategy: Staged apply to ensure SSL cert DNS validation succeeds

---

##### Stage 1: Reserve Static IPs (2-3 min)

**Purpose**: Create reserved external IP addresses for ArgoCD ingress

**Pre-flight Checks**:
- **Terraform configuration verification**:
  - Command: `ls -la infra/pcc-app-shared-infra/terraform/argocd-ingress.tf`
  - Expected: File exists (created in Phase 4.5)

- **Terraform initialization**:
  - Command: `cd infra/pcc-app-shared-infra/terraform && terraform init`
  - Expected: Backend initialized, providers downloaded
  - **Backend configuration**: State stored in `pcc-tfstate-shared-us-east4` bucket
    - Path: `devtest/pcc-app-shared-infra/tfstate`
    - Pattern: `$ENVIRONMENT/$REPONAME/tfstate` (established in Phase 2)

- **IAM permissions verification**:
  - Required roles for deployer:
    - `compute.addresses.create` (reserve IPs)
    - `compute.sslCertificates.create` (SSL certs)
    - `compute.securityPolicies.create` (Cloud Armor)
    - `compute.sslPolicies.create` (SSL policy)
    - `dns.resourceRecordSets.create` (DNS A records)
  - Command: `gcloud projects get-iam-policy pcc-prj-devops-nonprod --flatten="bindings[].members" --filter="bindings.members:user:$(gcloud config get-value account)" --format="table(bindings.role)"`
  - Expected: Shows roles/compute.networkAdmin or roles/editor (or custom role with above permissions)

**Targeted Apply - Static IP**:
- **Command**:
  ```bash
  terraform apply \
    -target=module.argocd_nonprod_ip \
    -var="environment=nonprod" \
    -var="region=us-east4" \
    -var="dns_zone=pcconnect.ai" \
    -auto-approve
  ```
- **Single-line format**:
  `terraform apply -target=module.argocd_nonprod_ip -var="environment=nonprod" -var="region=us-east4" -var="dns_zone=pcconnect.ai" -auto-approve`

- **Expected output**:
  ```
  module.argocd_nonprod_ip.google_compute_address.this: Creating...
  module.argocd_nonprod_ip.google_compute_address.this: Creation complete after 2s [id=projects/pcc-prj-devops-nonprod/regions/us-east4/addresses/argocd-nonprod-east4-ip]

  Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
  ```

**IP Address Verification**:
- **Command**: `gcloud compute addresses describe argocd-nonprod-east4-ip --region=us-east4 --project=pcc-prj-devops-nonprod --format="value(address)"`
- **Expected**: Returns external IP address (e.g., 34.23.45.67)
- **Capture IP for next stage**: `NONPROD_IP=$(gcloud compute addresses describe argocd-nonprod-east4-ip --region=us-east4 --project=pcc-prj-devops-nonprod --format="value(address)")`

**Success Criteria**: Static IP reserved and status shows RESERVED

---

##### Stage 2: Configure DNS (3-5 min)

**Purpose**: Create DNS A record pointing to reserved static IP

**DNS A Record Apply**:
- **Command**:
  ```bash
  terraform apply \
    -target=module.argocd_nonprod_dns \
    -var="environment=nonprod" \
    -var="region=us-east4" \
    -var="dns_zone=pcconnect.ai" \
    -auto-approve
  ```
- **Single-line format**:
  `terraform apply -target=module.argocd_nonprod_dns -var="environment=nonprod" -var="region=us-east4" -var="dns_zone=pcconnect.ai" -auto-approve`

- **Expected output**:
  ```
  module.argocd_nonprod_dns.google_dns_record_set.this: Creating...
  module.argocd_nonprod_dns.google_dns_record_set.this: Creation complete after 3s

  Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
  ```

**DNS Propagation Wait**:
- **Wait time**: 30-60 seconds for DNS propagation
- **Command**: `sleep 60`

**DNS Resolution Verification**:
- **Command**: `dig +short argocd-nonprod-east4.pcconnect.ai`
- **Expected**: Returns the reserved IP address from Stage 1
- **Alternative**: `nslookup argocd-nonprod-east4.pcconnect.ai`
- **Retry if needed**: DNS propagation can take up to 5 minutes, retry dig command if no result

**Success Criteria**: DNS A record resolves to correct static IP

---

##### Stage 3: Deploy Certificates & Policies (8-10 min)

**Purpose**: Deploy SSL certificate, Cloud Armor security policy, and SSL policy

**Full Terraform Apply**:
- **Command**:
  ```bash
  terraform apply \
    -var="environment=nonprod" \
    -var="region=us-east4" \
    -var="dns_zone=pcconnect.ai" \
    -auto-approve
  ```
- **Single-line format**:
  `terraform apply -var="environment=nonprod" -var="region=us-east4" -var="dns_zone=pcconnect.ai" -auto-approve`

- **Expected output**:
  ```
  module.argocd_nonprod_cert.google_compute_managed_ssl_certificate.this: Creating...
  module.argocd_cloud_armor.google_compute_security_policy.this: Creating...
  module.argocd_ssl_policy.google_compute_ssl_policy.this: Creating...

  module.argocd_cloud_armor.google_compute_security_policy.this: Creation complete after 3s
  module.argocd_ssl_policy.google_compute_ssl_policy.this: Creation complete after 2s
  module.argocd_nonprod_cert.google_compute_managed_ssl_certificate.this: Creation complete after 5s

  Apply complete! Resources: 3 added, 0 changed, 0 destroyed.

  Outputs:
  argocd_nonprod_ip = "34.23.45.67"
  argocd_nonprod_cert = "argocd-nonprod-east4-pcconnect-ai"
  argocd_armor_policy_name = "argocd-cloud-armor"
  argocd_ssl_policy_name = "argocd-ssl-policy"
  ```

**Resource Verification**:
1. **SSL Certificate**:
   - Command: `gcloud compute ssl-certificates describe argocd-nonprod-east4-pcconnect-ai --global --project=pcc-prj-devops-nonprod`
   - Expected status: `PROVISIONING` (will transition to ACTIVE when Ingress is created in Phase 4.7)
   - Note: Certificate requires Ingress with matching domain to complete activation

2. **Cloud Armor Policy**:
   - Command: `gcloud compute security-policies describe argocd-cloud-armor --project=pcc-prj-devops-nonprod`
   - Expected: Policy exists with rate limiting rules (from Phase 4.5 configuration)

3. **SSL Policy**:
   - Command: `gcloud compute ssl-policies describe argocd-ssl-policy --global --project=pcc-prj-devops-nonprod`
   - Expected: Min TLS version 1.2, profile MODERN

**Terraform Output Capture**:
- **Command**: `terraform output -json > /tmp/argocd-nonprod-terraform-outputs.json`
- **Verify outputs**:
  ```bash
  cat /tmp/argocd-nonprod-terraform-outputs.json | jq '{
    nonprod_ip: .argocd_nonprod_ip.value,
    nonprod_cert: .argocd_nonprod_cert.value,
    armor_policy: .argocd_armor_policy_name.value,
    ssl_policy: .argocd_ssl_policy_name.value
  }'
  ```
- **Expected**: All 4 output values present and non-empty

**Success Criteria**: All 4 nonprod resources created, terraform outputs captured

---

**Phase 4.6 Deliverables**:
- Static IP reserved: argocd-nonprod-east4-ip (us-east4)
- DNS A record created: argocd-nonprod-east4.pcconnect.ai → static IP
- Google-managed SSL certificate created: argocd-nonprod-east4-pcconnect-ai (PROVISIONING status)
- Cloud Armor security policy: argocd-cloud-armor (DDoS protection, rate limiting)
- SSL policy: argocd-ssl-policy (TLS 1.2+ enforcement)
- Terraform outputs captured for Phase 4.7 Helm values.yaml

**Dependencies**:
- Phase 4.5 complete (terraform configuration exists)
- **Phase 4.0 completed** - Required GCP APIs enabled (dns, storage) (BLOCKING)
- Phase 3.0 complete (container, compute APIs enabled)
- Terraform installed and initialized
- IAM permissions for Compute Engine and Cloud DNS
- DNS zone `pcconnect.ai` exists and accessible

**Duration Estimate**: 15-20 minutes total
- Stage 1 (Static IPs): 2-3 min
- Stage 2 (DNS): 3-5 min (includes DNS propagation wait)
- Stage 3 (Certificates & Policies): 8-10 min
- Buffer: 2 min

**Phase 4.7 Readiness Criteria** (terraform outputs for Helm deployment):
- ✅ Static IP address reserved and assigned
- ✅ DNS A record resolves to static IP
- ✅ SSL certificate created (PROVISIONING status acceptable, will activate when Ingress created)
- ✅ Cloud Armor policy deployed with rate limiting rules
- ✅ SSL policy configured for TLS 1.2+ enforcement
- ✅ Terraform outputs available for ingress annotation values

**Note**: SSL certificate will remain in PROVISIONING status until Phase 4.7 creates the GKE Ingress resource. This is expected behavior - Google validates domain ownership via the Ingress.

---

### Nonprod Deployment (3 subphases)

#### Phase 4.7: Install ArgoCD on Devops Nonprod Cluster

**Overview**: Deploy ArgoCD v3.1.9 to pcc-gke-devops-nonprod cluster with production-mirror architecture for upgrade testing

**Total Duration**: 85-125 minutes (broken into 5 digestible sub-phases)

**⚠️ IMPORTANT for Claude Code Execution**: Before presenting ANY command block in this phase, Claude MUST explicitly remind the user: "Please open WARP terminal now to execute the following commands." Wait for user acknowledgment before proceeding with command presentation.

**Sub-Phases** (execute sequentially):
- **4.7.1**: Pre-flight Checks & cert-manager Setup (20-30 min) - Prerequisites and TLS certificates
- **4.7.2**: Helm Deployment & Ingress Creation (15-26 min) - Install ArgoCD and expose via HTTPS
- **4.7.3**: Component Verification (10-17 min) - Validate pods, SSL, DNS, SSO
- **4.7.4**: Security & Backup Validation (15-22 min) - Verify Redis mTLS and persistence
- **4.7.5**: Velero Backup Automation (20-30 min) - Configure automated backups to GCS

**Key Architectural Context**:
- ArgoCD version: v3.1.9 (Helm chart v7.7.4) - same as nonprod
- **Production HA configuration**:
  - API servers: 3 replicas (vs 1 in nonprod)
  - Repo servers: 2 replicas (vs 1 in nonprod)
  - Redis: 3 replicas with HA mode (vs 1 ephemeral in nonprod)
  - Application controller: 1 replica (stateful, cannot scale horizontally)
  - Dex server: 2 replicas (vs 1 in nonprod)
- **Redis persistence**: PVC with RDB snapshots + daily Cloud Storage backups (30-day retention)
- Ingress: GKE Ingress with Google-managed SSL cert (from Phase 4.9 terraform)
- DNS: `argocd-east4.pcconnect.ai` (from Phase 4.9 terraform)
- Auth: OAuth 2.0 via Google Workspace SSO (Dex connector)
- RBAC: gcp-devops@pcconnect.ai (admin), gcp-developers@pcconnect.ai (view + sync)

**Dependencies**:
- Phase 4.9 complete (terraform outputs available)
- Phase 4.8 complete with 24-hour stabilization period
- kubectl access to devops-prod cluster (Phase 3)
- Helm v3 installed locally

---

##### Module 1: Pre-flight Checks & Dependencies (25-35 min)

**Purpose**: Verify all prerequisites, install cert-manager for mTLS, and create production Helm values file before deployment

**Section 1.1: Cluster Context Verification**
- **Action**: Verify kubectl is configured for correct cluster
- **Expected cluster context**: `gke_pcc-prj-devops-prod_us-east4_pcc-gke-devops-prod`
- **Verification method**: `kubectl config current-context`
- **Expected GCP project**: `pcc-prj-devops-prod`
- **Expected region**: `us-east4`
- **Cluster info verification**: `kubectl cluster-info` should show prod cluster endpoints
- **Node verification**: `kubectl get nodes` should return prod cluster nodes without permission errors
- **Critical**: STOP if cluster context is wrong - deploying to wrong cluster is catastrophic

**Section 1.2: Phase 4.9 Terraform Outputs Verification**
- **Action**: Verify all GCP resources from Phase 4.9 exist before deployment
- **Required resources**:
  1. **Static IP**: `argocd-east4-ip` in region `us-east4`
     - Verification: `gcloud compute addresses describe argocd-east4-ip --region=us-east4 --project=pcc-prj-devops-prod`
     - Expected status: `RESERVED` (not yet in use)
  2. **DNS A record**: `argocd-east4.pcconnect.ai` resolves to static IP
     - Verification: `dig +short argocd-east4.pcconnect.ai`
     - Expected: Returns the reserved static IP address
  3. **Google-managed SSL certificate**: `argocd-east4-pcconnect-ai`
     - Verification: `gcloud compute ssl-certificates describe argocd-east4-pcconnect-ai --global --project=pcc-prj-devops-prod`
     - Expected status: `PROVISIONING` (cert will activate when Ingress is created)
  4. **Cloud Armor security policy**: `argocd-cloud-armor`
     - Verification: `gcloud compute security-policies describe argocd-cloud-armor --project=pcc-prj-devops-nonprod`
     - Expected: Policy exists (shared resource from Phase 4.6)
  5. **SSL policy**: `argocd-ssl-policy`
     - Verification: `gcloud compute ssl-policies describe argocd-ssl-policy --global --project=pcc-prj-devops-nonprod`
     - Expected: TLS 1.2+ policy exists (shared resource from Phase 4.6)

**Section 1.3: Helm Repository Verification**
- **Action**: Verify ArgoCD Helm repository is configured
- **Repository URL**: https://argoproj.github.io/argo-helm
- **Add repository** (if not present):
  - Command: `helm repo add argo https://argoproj.github.io/argo-helm`
- **Update repository**:
  - Command: `helm repo update`
- **Verify chart availability**:
  - Command: `helm search repo argo/argo-cd --version 7.7.4`
  - Expected: Shows argo-cd chart version 7.7.4 with app version v3.1.9

**Section 1.4: Install cert-manager for Redis mTLS**
- **Action**: Install cert-manager v1.13+ for automatic TLS certificate management
- **Purpose**: Provides mutual TLS encryption for Redis pod-to-pod communication
- **Namespace**: `cert-manager` (dedicated namespace)

**📝 Certificate Source Clarification**:
- **Redis mTLS certificates are created BY cert-manager DURING this phase** (Phase 4.10)
- These certificates DO NOT come from Phase 2, Secret Manager, or any external source
- cert-manager automatically generates self-signed certificates specifically for Redis pod-to-pod encryption
- Certificate lifecycle (creation, renewal, rotation) is fully managed by cert-manager
- The certificates created in this section will be mounted into Redis-HA pods via Kubernetes secrets
- **Certificate scope**: Internal cluster communication only (Redis pods ↔ HAProxy ↔ ArgoCD server)

- **Add cert-manager Helm repository**:
  - Command: `helm repo add jetstack https://charts.jetstack.io`
  - Command: `helm repo update`

- **Install cert-manager with CRDs**:
  - Command structure (multi-line):
    ```bash
    helm install cert-manager jetstack/cert-manager \
      --namespace cert-manager \
      --create-namespace \
      --version v1.13.3 \
      --set installCRDs=true \
      --wait \
      --timeout 5m
    ```
  - Single-line: `helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --version v1.13.3 --set installCRDs=true --wait --timeout 5m`
  - Expected duration: 2-3 minutes
  - Expected output: `STATUS: deployed`

- **Verify cert-manager pods**:
  - Command: `kubectl -n cert-manager get pods`
  - Expected: 3 pods running (cert-manager, cert-manager-cainjector, cert-manager-webhook)
  - Wait command: `kubectl -n cert-manager wait --for=condition=ready pod --all --timeout=300s`

- **Create self-signed ClusterIssuer for internal certificates**:
  - Command: Create ClusterIssuer manifest
    ```bash
    cat <<EOF | kubectl apply -f -
    apiVersion: cert-manager.io/v1
    kind: ClusterIssuer
    metadata:
      name: selfsigned-issuer
    spec:
      selfSigned: {}
    ---
    apiVersion: cert-manager.io/v1
    kind: Certificate
    metadata:
      name: redis-ca
      namespace: cert-manager
    spec:
      isCA: true
      commonName: redis-ca
      secretName: redis-ca-secret
      privateKey:
        algorithm: RSA
        size: 4096
      issuerRef:
        name: selfsigned-issuer
        kind: ClusterIssuer
        group: cert-manager.io
    ---
    apiVersion: cert-manager.io/v1
    kind: ClusterIssuer
    metadata:
      name: redis-ca-issuer
    spec:
      ca:
        secretName: redis-ca-secret
    EOF
    ```
  - Expected: 3 resources created (2 ClusterIssuers, 1 Certificate)

- **Verify CA certificate creation**:
  - Command: `kubectl -n cert-manager get certificate redis-ca`
  - Expected: STATUS=Ready (may take 30-60 seconds)
  - Wait: `kubectl -n cert-manager wait --for=condition=ready certificate redis-ca --timeout=120s`

**Section 1.5: Create Redis TLS Certificates**
- **Action**: Create Certificate resource for Redis HA pods in argocd namespace
- **Certificate spec**: Covers all Redis pod DNS names for mTLS

- **Create namespace** (if Phase 4.7 not run yet):
  - Command: `kubectl create namespace argocd` (may already exist from nonprod)

- **Create Redis TLS Certificate**:
  - Command: Create Certificate manifest
    ```bash
    cat <<EOF | kubectl apply -f -
    apiVersion: cert-manager.io/v1
    kind: Certificate
    metadata:
      name: redis-tls
      namespace: argocd
    spec:
      secretName: redis-tls-secret
      duration: 2160h  # 90 days
      renewBefore: 360h  # Renew 15 days before expiry
      subject:
        organizations:
          - pcconnect
      commonName: redis-ha.argocd.svc.cluster.local
      dnsNames:
        - redis-ha.argocd.svc.cluster.local
        - redis-ha-haproxy.argocd.svc.cluster.local
        - "*.redis-ha.argocd.svc.cluster.local"
        - "*.redis-ha-headless.argocd.svc.cluster.local"
      issuerRef:
        name: redis-ca-issuer
        kind: ClusterIssuer
        group: cert-manager.io
    EOF
    ```
  - Expected: Certificate resource created in argocd namespace

- **Verify certificate readiness**:
  - Command: `kubectl -n argocd get certificate redis-tls`
  - Expected: STATUS=Ready (may take 30-60 seconds)
  - Wait: `kubectl -n argocd wait --for=condition=ready certificate redis-tls --timeout=120s`

- **Verify secret created**:
  - Command: `kubectl -n argocd get secret redis-tls-secret`
  - Expected: Secret exists with keys: ca.crt, tls.crt, tls.key
  - Inspect: `kubectl -n argocd get secret redis-tls-secret -o jsonpath='{.data}' | jq 'keys'`
  - Expected output: `["ca.crt", "tls.crt", "tls.key"]`

**Section 1.6: Create Production Helm Values File**
- **Action**: Create `values-prod.yaml` with HA configuration for production deployment
- **File location**: `core/pcc-app-argo-config/helm/values-prod.yaml`
- **Values content** (complete YAML):
  ```yaml
  # ArgoCD Production Helm Values (v7.7.4 / ArgoCD v3.1.9)
  # Phase 4.5B: Install ArgoCD on Devops Prod Cluster
  # HA configuration with Redis persistence and Cloud Storage backups

  global:
    image:
      tag: "v3.1.9"

  ## ArgoCD Server (API + UI)
  server:
    name: server
    replicas: 3  # HA: 3 replicas for prod
    autoscaling:
      enabled: false
    resources:
      requests:
        cpu: 250m
        memory: 512Mi
      limits:
        cpu: 500m
        memory: 1Gi
    metrics:
      enabled: true
      serviceMonitor:
        enabled: false  # Using Cloud Monitoring, not Prometheus
    ingress:
      enabled: false  # Using GKE Ingress (created separately in Phase 4.9)
    service:
      type: NodePort  # GKE Ingress requires NodePort or ClusterIP
      port: 443
      targetPort: 8080

  ## Repository Server
  repoServer:
    name: repo-server
    replicas: 2  # HA: 2 replicas for prod
    autoscaling:
      enabled: false
    resources:
      requests:
        cpu: 250m
        memory: 512Mi
      limits:
        cpu: 500m
        memory: 1Gi
    metrics:
      enabled: true
      serviceMonitor:
        enabled: false

  ## Application Controller
  controller:
    name: application-controller
    replicas: 1  # Stateful, cannot scale horizontally
    resources:
      requests:
        cpu: 500m
        memory: 1Gi
      limits:
        cpu: 1000m
        memory: 2Gi
    metrics:
      enabled: true
      serviceMonitor:
        enabled: false

  ## Dex Server (OAuth 2.0 / OIDC)
  dex:
    enabled: true
    name: dex-server
    replicas: 2  # HA: 2 replicas for prod
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 200m
        memory: 256Mi
    metrics:
      enabled: true
      serviceMonitor:
        enabled: false

  ## Redis (Session Storage + Caching) - HA Configuration with mTLS
  ## Using redis-ha subchart for production HA with Sentinel
  redis-ha:
    enabled: true
    replicas: 3  # 3 Redis instances with Sentinel sidecars
    auth: true  # Enable Redis authentication
    redisPassword: ""  # Populated via Helm install --set flag from Secret Manager
    persistentVolume:
      enabled: true
      size: 10Gi
      storageClassName: "standard-rwo"  # GKE standard persistent disk

    ## Mount cert-manager TLS certificates for mTLS
    redis:
      resources:
        requests:
          cpu: 100m
          memory: 256Mi
        limits:
          cpu: 200m
          memory: 512Mi

      ## TLS configuration for Redis (cert-manager certificates)
      tlsPort: 6379
      port: 0  # Disable non-TLS port

      ## Volume mounts for cert-manager certificates
      extraVolumes:
        - name: redis-tls
          secret:
            secretName: redis-tls-secret
            defaultMode: 0400

      extraVolumeMounts:
        - name: redis-tls
          mountPath: /tls
          readOnly: true

      ## Redis config for TLS
      config:
        tls-port: "6379"
        port: "0"
        tls-cert-file: /tls/tls.crt
        tls-key-file: /tls/tls.key
        tls-ca-cert-file: /tls/ca.crt
        tls-auth-clients: "yes"  # Require client certificates (mTLS)

    ## Redis Sentinel for leader election and failover
    sentinel:
      enabled: true
      replicas: 3  # 3 Sentinel instances (one per Redis pod)
      auth: true  # Enable Sentinel authentication
      resources:
        requests:
          cpu: 50m
          memory: 64Mi
        limits:
          cpu: 100m
          memory: 128Mi

      ## TLS for Sentinel (uses same certificates)
      tlsReplicationEnabled: true
      extraVolumes:
        - name: redis-tls
          secret:
            secretName: redis-tls-secret
            defaultMode: 0400

      extraVolumeMounts:
        - name: redis-tls
          mountPath: /tls
          readOnly: true

    ## HAProxy for Redis connection routing
    haproxy:
      enabled: true
      replicas: 3  # 3 HAProxy instances for HA
      resources:
        requests:
          cpu: 100m
          memory: 128Mi
        limits:
          cpu: 200m
          memory: 256Mi

      ## HAProxy also needs access to TLS certs for Redis connections
      extraVolumes:
        - name: redis-tls
          secret:
            secretName: redis-tls-secret
            defaultMode: 0400

      extraVolumeMounts:
        - name: redis-tls
          mountPath: /tls
          readOnly: true

  ## Disable standalone Redis (using redis-ha instead)
  redis:
    enabled: false

  ## Notifications Controller (optional)
  notifications:
    enabled: false  # Defer to Phase 4.6 configuration

  ## ApplicationSet Controller
  applicationSet:
    enabled: true
    replicas: 1
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 200m
        memory: 256Mi

  ## RBAC Configuration
  configs:
    rbac:
      policy.csv: |
        # DevOps admin group - full access
        g, gcp-devops@pcconnect.ai, role:admin
        # Developers group - view + sync permissions
        p, role:developer, applications, get, */*, allow
        p, role:developer, applications, sync, */*, allow
        p, role:developer, logs, get, */*, allow
        p, role:developer, exec, create, */*, deny
        g, gcp-developers@pcconnect.ai, role:developer

    ## SSO Configuration (Dex connectors)
    dex.config: |
      connectors:
        - type: oidc
          id: google
          name: Google
          config:
            issuer: https://accounts.google.com
            clientID: $dex.google.clientId
            clientSecret: $dex.google.clientSecret
            redirectURI: https://argocd-east4.pcconnect.ai/api/dex/callback
            hostedDomains:
              - pcconnect.ai
            scopes:
              - openid
              - profile
              - email

    ## Session Security
    params:
      server.insecure: "false"
      server.session.max.duration: "15m"  # 15-minute idle timeout
      server.session.cookie.secure: "true"

  ## ArgoCD Repo Credentials (GitHub App via Workload Identity)
  # Created in Phase 4.6, not Phase 4.5B
  repoCredentials: []

  ## PodDisruptionBudgets for HA Components
  ## Ensures minimum pod availability during voluntary disruptions (node drains, upgrades)
  podDisruptionBudgets:
    server:
      enabled: true
      minAvailable: 2  # Keep 2 of 3 server pods available
    repoServer:
      enabled: true
      minAvailable: 1  # Keep 1 of 2 repo-server pods available
    controller:
      enabled: false  # Controller is stateful, single replica
    dex:
      enabled: true
      minAvailable: 1  # Keep 1 of 2 dex pods available
    redis-ha:
      enabled: true
      minAvailable: 2  # Keep 2 of 3 Redis pods available
    haproxy:
      enabled: true
      minAvailable: 2  # Keep 2 of 3 HAProxy pods available
  ```

- **Save values file**:
  - Command: `vi core/pcc-app-argo-config/helm/values-prod.yaml`
  - Paste YAML content above
  - Save and exit

- **⚠️ IMPORTANT: Apply same configuration to nonprod (Phase 4.7)**:
  - The following configurations added to values-prod.yaml should ALSO be added to `core/pcc-app-argo-config/helm/values-nonprod.yaml`:
    1. **Redis authentication**: Add `auth: true` and `redisPassword` fields to redis-ha section (adjust for single-replica nonprod: 1 Redis, 1 Sentinel, 1 HAProxy)
    2. **PodDisruptionBudgets**: Add podDisruptionBudgets section (adjust minAvailable for nonprod: server: 1, others: disabled or 1)
    3. **OAuth secret management**: Apply Section 1.5 OAuth Secret Management steps for nonprod using `-nonprod` suffix in secret names
  - This ensures consistency between nonprod and prod configurations
  - Defer TLS configuration for Redis in nonprod (optional for testing environment)

- **Validate YAML syntax**:
  - Command: `helm lint core/pcc-app-argo-config/helm/values-prod.yaml` (may show warnings, that's OK)
  - Alternative: `cat core/pcc-app-argo-config/helm/values-prod.yaml | yq eval`

**Section 1.7: OAuth Secret Management (Secret Manager)**
- **Action**: Create and configure OAuth 2.0 client secrets in GCP Secret Manager for Dex SSO
- **Required secrets**:
  1. `argocd-dex-google-client-id-prod` (Google OAuth client ID from Phase 4.2C OAuth setup)
  2. `argocd-dex-google-client-secret-prod` (Google OAuth client secret from Phase 4.2C OAuth setup)
  3. `argocd-redis-password-prod` (Redis authentication password - generated)

- **Create Redis password secret**:
  - Generate strong password:
    ```bash
    openssl rand -base64 32
    ```
  - Store in Secret Manager:
    ```bash
    echo -n "GENERATED_PASSWORD" | gcloud secrets create argocd-redis-password-prod \
      --data-file=- \
      --replication-policy=automatic \
      --project=pcc-prj-devops-prod
    ```
  - Expected: Secret created with version 1

- **Verify OAuth secrets exist** (created in Phase 4.2C):
  - Command: `gcloud secrets describe argocd-dex-google-client-id-prod --project=pcc-prj-devops-prod`
  - Command: `gcloud secrets describe argocd-dex-google-client-secret-prod --project=pcc-prj-devops-prod`
  - Expected: Both secrets exist and are ENABLED
  - **If secrets missing**: Re-run Phase 4.2C OAuth configuration or create manually

- **Grant ArgoCD service accounts access to secrets**:
  - ArgoCD server needs access to Dex OAuth secrets:
    ```bash
    gcloud secrets add-iam-policy-binding argocd-dex-google-client-id-prod \
      --member="serviceAccount:argocd-server@pcc-prj-devops-prod.iam.gserviceaccount.com" \
      --role="roles/secretmanager.secretAccessor" \
      --project=pcc-prj-devops-prod

    gcloud secrets add-iam-policy-binding argocd-dex-google-client-secret-prod \
      --member="serviceAccount:argocd-server@pcc-prj-devops-prod.iam.gserviceaccount.com" \
      --role="roles/secretmanager.secretAccessor" \
      --project=pcc-prj-devops-prod
    ```
  - Redis pods need access to Redis password:
    ```bash
    gcloud secrets add-iam-policy-binding argocd-redis-password-prod \
      --member="serviceAccount:argocd-redis@pcc-prj-devops-prod.iam.gserviceaccount.com" \
      --role="roles/secretmanager.secretAccessor" \
      --project=pcc-prj-devops-prod
    ```

- **Note on Helm deployment**: Secrets will be injected at deployment time using `--set` flags:
  - `--set configs.secret.extra.dex.google.clientId=$(gcloud secrets versions access latest --secret=argocd-dex-google-client-id-prod --project=pcc-prj-devops-prod)`
  - `--set configs.secret.extra.dex.google.clientSecret=$(gcloud secrets versions access latest --secret=argocd-dex-google-client-secret-prod --project=pcc-prj-devops-prod)`
  - `--set redis-ha.redisPassword=$(gcloud secrets versions access latest --secret=argocd-redis-password-prod --project=pcc-prj-devops-prod)`

**Pre-flight Checks Output**: Go/No-Go decision
- **GO**: All 7 sections passed → Proceed to Module 2
- **NO-GO**: Any section failed → Stop, fix issues, re-run pre-flight checks

---

##### Module 2: Helm Deployment (15-20 min)

**Purpose**: Deploy ArgoCD via Helm with HA configuration and progressive status monitoring

**Section 2.1: Helm Install with HA Configuration**
- **Action**: Install ArgoCD using Helm with values-prod.yaml and inject secrets from Secret Manager
- **Namespace**: `argocd` (will be created if doesn't exist)
- **Release name**: `argocd`
- **Chart version**: 7.7.4 (ArgoCD app version v3.1.9)

- **Command structure** (multi-line format):
  ```bash
  helm install argocd argo/argo-cd \
    --version 7.7.4 \
    --namespace argocd \
    --create-namespace \
    --values core/pcc-app-argo-config/helm/values-prod.yaml \
    --set configs.secret.extra.dex.google.clientId="$(gcloud secrets versions access latest --secret=argocd-dex-google-client-id-prod --project=pcc-prj-devops-prod)" \
    --set configs.secret.extra.dex.google.clientSecret="$(gcloud secrets versions access latest --secret=argocd-dex-google-client-secret-prod --project=pcc-prj-devops-prod)" \
    --set redis-ha.redisPassword="$(gcloud secrets versions access latest --secret=argocd-redis-password-prod --project=pcc-prj-devops-prod)" \
    --wait \
    --timeout 15m
  ```
- **Single-line executable format**:
  `helm install argocd argo/argo-cd --version 7.7.4 --namespace argocd --create-namespace --values core/pcc-app-argo-config/helm/values-prod.yaml --set configs.secret.extra.dex.google.clientId="$(gcloud secrets versions access latest --secret=argocd-dex-google-client-id-prod --project=pcc-prj-devops-prod)" --set configs.secret.extra.dex.google.clientSecret="$(gcloud secrets versions access latest --secret=argocd-dex-google-client-secret-prod --project=pcc-prj-devops-prod)" --set redis-ha.redisPassword="$(gcloud secrets versions access latest --secret=argocd-redis-password-prod --project=pcc-prj-devops-prod)" --wait --timeout 15m`

- **Expected behavior**:
  - Helm creates namespace `argocd`
  - Deploys all ArgoCD components (server, repo-server, controller, dex, redis, applicationset)
  - **HA pod startup**: 3 API servers, 2 repo servers, 3 Redis + HAProxy take longer to stabilize than nonprod
  - `--wait` flag monitors pod readiness, will block until all pods ready or timeout (15 min)

- **Expected output** (after 10-15 minutes):
  ```
  NAME: argocd
  LAST DEPLOYED: <timestamp>
  NAMESPACE: argocd
  STATUS: deployed
  REVISION: 1
  TEST SUITE: None
  ```

**Section 2.2: Progressive Status Checks (HA Pod Readiness)**
- **Action**: Monitor each HA component set reaches ready state after Helm install completes
- **Note**: Even with `--wait`, progressive checks confirm all replicas are stable

1. **API Server Pods (3 replicas)**:
   - Command: `kubectl -n argocd wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server --timeout=5m`
   - Expected: All 3 pods transition to Ready within 5 minutes
   - Verify count: `kubectl -n argocd get pods -l app.kubernetes.io/name=argocd-server --no-headers | wc -l`
   - Expected count: `3`

2. **Repo Server Pods (2 replicas)**:
   - Command: `kubectl -n argocd wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-repo-server --timeout=5m`
   - Expected: All 2 pods transition to Ready within 5 minutes
   - Verify count: `kubectl -n argocd get pods -l app.kubernetes.io/name=argocd-repo-server --no-headers | wc -l`
   - Expected count: `2`

3. **Redis Pods (3 replicas + 3 HAProxy)**:
   - Redis pods: `kubectl -n argocd wait --for=condition=ready pod -l app.kubernetes.io/component=redis --timeout=5m`
   - HAProxy pods: `kubectl -n argocd wait --for=condition=ready pod -l app.kubernetes.io/component=haproxy --timeout=5m`
   - Expected: 3 Redis pods + 3 HAProxy pods all Ready
   - Note: redis-ha chart uses `app.kubernetes.io/component` labels for pod selection
   - Verify Redis count: `kubectl -n argocd get pods -l app.kubernetes.io/component=redis --no-headers | wc -l`
   - Expected Redis count: `3`
   - Verify HAProxy count: `kubectl -n argocd get pods -l app.kubernetes.io/component=haproxy --no-headers | wc -l`
   - Expected HAProxy count: `3`

4. **Application Controller Pod (1 replica)**:
   - Command: `kubectl -n argocd wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-application-controller --timeout=5m`
   - Expected: 1 pod Ready
   - Verify count: `kubectl -n argocd get pods -l app.kubernetes.io/name=argocd-application-controller --no-headers | wc -l`
   - Expected count: `1`

5. **Dex Server Pods (2 replicas)**:
   - Command: `kubectl -n argocd wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-dex-server --timeout=5m`
   - Expected: All 2 pods Ready
   - Verify count: `kubectl -n argocd get pods -l app.kubernetes.io/name=argocd-dex-server --no-headers | wc -l`
   - Expected count: `2`

6. **ApplicationSet Controller Pod (1 replica)**:
   - Command: `kubectl -n argocd wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-applicationset-controller --timeout=5m`
   - Expected: 1 pod Ready
   - Verify count: `kubectl -n argocd get pods -l app.kubernetes.io/name=argocd-applicationset-controller --no-headers | wc -l`
   - Expected count: `1`

**Total expected pod count: 15 pods** (vs 5 in nonprod)
- 3x argocd-server (API + UI)
- 2x argocd-repo-server (Repository management)
- 1x argocd-application-controller (Sync controller)
- 2x argocd-dex-server (OAuth/OIDC)
- 1x argocd-applicationset-controller (ApplicationSet CRD)
- 3x redis-ha-server (Redis StatefulSet with Sentinel sidecar in each pod)
- 3x redis-ha-haproxy (HAProxy Deployment for Redis connection routing)

**Section 2.3: Pod Readiness Summary**
- **Action**: Verify all 15 pods are Running and Ready
- **Command**: `kubectl -n argocd get pods`
- **Expected output**: All pods show STATUS=Running, READY=1/1 (or 2/2 for multi-container pods)
- **Success criteria**: 15 total pods, all Running and Ready

**Module 2 Output**: Helm Deployment Complete
- **Deliverable**: ArgoCD HA components deployed to devops-prod cluster
- **Verification**: `kubectl -n argocd get pods` shows 15 pods Running
- **Next step**: Proceed to Module 3 (Component Verification)

---

##### Module 2.5: Create GKE Ingress (5-8 min)

**Purpose**: Create GKE Ingress resource to expose ArgoCD UI via HTTPS using terraform-provisioned infrastructure

**Section 2.5.1: Create Ingress Manifest**
- **Action**: Create Kubernetes Ingress manifest that uses resources provisioned by Phase 4.9 terraform
- **File location**: `core/pcc-app-argo-config/manifests/argocd-ingress-prod.yaml`
- **Ingress configuration**:
  - **Name**: `argocd-server`
  - **Namespace**: `argocd`
  - **Ingress class**: `gce` (GKE Ingress controller)
  - **Static IP**: `argocd-east4-ip` (references terraform-created compute address)
  - **SSL certificate**: `argocd-east4-cert` (references terraform-created Google-managed certificate)
  - **Cloud Armor policy**: `argocd-security-policy` (references terraform-created security policy)
  - **Backend service**: `argocd-server` (NodePort service created by Helm)

- **Manifest content**:
  ```yaml
  # ArgoCD GKE Ingress - Production
  # Phase 4.10: Expose ArgoCD UI via HTTPS
  # Uses resources created by Phase 4.9 terraform
  
  apiVersion: networking.k8s.io/v1
  kind: Ingress
  metadata:
    name: argocd-server
    namespace: argocd
    annotations:
      # Use GKE Ingress controller
      kubernetes.io/ingress.class: "gce"
      
      # Static IP (created by terraform Phase 4.9)
      kubernetes.io/ingress.global-static-ip-name: "argocd-east4-ip"
      
      # Google-managed SSL certificate (created by terraform Phase 4.9)
      networking.gke.io/managed-certificates: "argocd-east4-cert"
      
      # Cloud Armor security policy (created by terraform Phase 4.6, shared with nonprod)
      cloud.google.com/armor-config: '{"argocd-security-policy": "argocd-security-policy"}'
      
      # Redirect HTTP to HTTPS
      kubernetes.io/ingress.allow-http: "true"
      
      # Backend configuration for health checks
      cloud.google.com/backend-config: '{"default": "argocd-backend-config"}'
  spec:
    rules:
    - host: argocd-east4.pcconnect.ai
      http:
        paths:
        - path: /*
          pathType: ImplementationSpecific
          backend:
            service:
              name: argocd-server
              port:
                number: 443
  ```

- **Save manifest**:
  ```bash
  # Create manifests directory if it doesn't exist
  mkdir -p core/pcc-app-argo-config/manifests
  
  # Save manifest file
  cat > core/pcc-app-argo-config/manifests/argocd-ingress-prod.yaml <<'EOF'
  [paste YAML content above]
  EOF
  ```

**Section 2.5.2: Create Backend Config for Health Checks**
- **Action**: Create BackendConfig resource to configure GKE load balancer health checks
- **Purpose**: Ensures load balancer health checks use correct ArgoCD server health endpoint
- **Manifest content**:
  ```yaml
  # ArgoCD Backend Configuration - Production
  # Configures GKE load balancer health checks for ArgoCD server
  
  apiVersion: cloud.google.com/v1
  kind: BackendConfig
  metadata:
    name: argocd-backend-config
    namespace: argocd
  spec:
    healthCheck:
      checkIntervalSec: 10
      timeoutSec: 5
      healthyThreshold: 2
      unhealthyThreshold: 3
      type: HTTP
      requestPath: /healthz
      port: 8080
    timeoutSec: 30
    connectionDraining:
      drainingTimeoutSec: 60
  ```

- **Save backend config**:
  ```bash
  cat > core/pcc-app-argo-config/manifests/argocd-backend-config-prod.yaml <<'EOF'
  [paste YAML content above]
  EOF
  ```

**Section 2.5.3: Apply Ingress Resources**
- **Action**: Apply both BackendConfig and Ingress manifests to cluster
- **Apply commands** (apply in order):
  ```bash
  # Switch to prod cluster context
  kubectl config use-context gke_pcc-prj-devops-prod_us-east4_pcc-gke-devops-prod
  
  # Apply backend config first
  kubectl apply -f core/pcc-app-argo-config/manifests/argocd-backend-config-prod.yaml
  
  # Apply ingress manifest
  kubectl apply -f core/pcc-app-argo-config/manifests/argocd-ingress-prod.yaml
  ```

- **Expected output**:
  ```
  backendconfig.cloud.google.com/argocd-backend-config created
  ingress.networking.k8s.io/argocd-server created
  ```

**Section 2.5.4: Verify Ingress Creation**
- **Action**: Verify Ingress resource was created successfully
- **Verification commands**:
  ```bash
  # Check Ingress resource
  kubectl -n argocd get ingress argocd-server
  
  # Expected output:
  # NAME             CLASS   HOSTS                              ADDRESS          PORTS     AGE
  # argocd-server    gce     argocd-east4.pcconnect.ai          <external-ip>    80, 443   30s
  ```

- **Check Ingress status**:
  ```bash
  kubectl -n argocd describe ingress argocd-server
  ```
  - **Verify annotations**:
    - `kubernetes.io/ingress.global-static-ip-name`: argocd-east4-ip
    - `networking.gke.io/managed-certificates`: argocd-east4-cert
    - `cloud.google.com/armor-config`: argocd-security-policy
  - **Verify backend**: Should show argocd-server:443
  - **Verify address**: External IP should match terraform static IP from Phase 4.9

- **Success criteria**:
  - Ingress resource created with ADDRESS field populated
  - Annotations correctly reference terraform resources
  - Backend points to argocd-server service

**Note**: SSL certificate will be in PROVISIONING state initially. Certificate becomes ACTIVE in 5-10 minutes (verified in Module 3, Section 3.1).

---

##### Module 3: Component Verification (15-20 min)

**Purpose**: Verify SSL certificate activation, HA pod distribution, and Google SSO functionality

**Section 3.1: SSL Certificate Provisioning Wait**
- **Action**: Wait for Google-managed SSL certificate to transition from PROVISIONING to ACTIVE
- **Expected behavior**:
  - Certificate starts in PROVISIONING state (from Phase 4.9)
  - Google validates DNS ownership via Ingress + A record
  - Certificate transitions to ACTIVE state (typically 5-15 minutes for prod)

**Section 3.2: SSL Certificate Provisioning Wait**
- **Action**: Wait for Google-managed SSL certificate to transition from PROVISIONING to ACTIVE
- **Expected behavior**:
  - Certificate starts in PROVISIONING state (from Phase 4.9)
  - Google validates DNS ownership via Ingress + A record
  - Certificate transitions to ACTIVE state (typically 5-15 minutes for prod)
- **Monitoring command**: `gcloud compute ssl-certificates describe argocd-east4-pcconnect-ai --global --project=pcc-prj-devops-prod`
- **Watch for status change**:
  - Command: `watch -n 30 'gcloud compute ssl-certificates describe argocd-east4-pcconnect-ai --global --project=pcc-prj-devops-prod --format="value(managed.status)"'`
  - Expected transition: `PROVISIONING` → `ACTIVE`
  - Press Ctrl+C when status shows `ACTIVE`
- **Success criteria**: Certificate status shows `ACTIVE`
- **Note**: ArgoCD UI will not be accessible via HTTPS until certificate is ACTIVE
- **Timing**: This wait naturally overlaps with Ingress backend health check stabilization

**Section 3.3: HA Pod Readiness Verification (Post-Helm)**
- **Action**: Re-verify all ArgoCD component pods are still running and ready after Ingress creation
- **Expected pods (prod - HA configuration)**:

  **Required core components (15 total pods):**
  1. `argocd-server-*` (3 pods) - API server and UI (HA)
  2. `argocd-repo-server-*` (2 pods) - Repository management (HA)
  3. `argocd-application-controller-*` (1 pod) - Application sync controller
  4. `argocd-dex-server-*` (2 pods) - OAuth 2.0 SSO (HA)
  5. `redis-ha-server-*` (3 pods) - Redis StatefulSet with Sentinel sidecar (HA)
  6. `redis-ha-haproxy-*` (3 pods) - HAProxy Deployment for Redis connection routing
  7. `argocd-applicationset-controller-*` (1 pod) - ApplicationSet controller

- **Verification method**: `kubectl -n argocd get pods`
- **Success criteria**: All 15 pods show STATUS=Running, READY=1/1 (or 2/2 for multi-container pods)

**Section 3.4: DNS Resolution Verification**
- **Action**: Verify DNS A record still resolves correctly to static IP
- **Command**: `dig +short argocd-east4.pcconnect.ai`
- **Expected**: Returns static IP from Phase 4.9 (matches Ingress ADDRESS)
- **Alternative**: `nslookup argocd-east4.pcconnect.ai`
- **Success criteria**: DNS resolves to correct static IP

**Section 3.5: HTTPS Accessibility Verification**
- **Action**: Verify ArgoCD UI is accessible via HTTPS with valid SSL certificate
- **URL**: `https://argocd-east4.pcconnect.ai`
- **Verification method**:
  1. Check HTTPS response: `curl -I https://argocd-east4.pcconnect.ai`
  2. Verify login page content: `curl -s https://argocd-east4.pcconnect.ai | grep -q "LOG IN VIA GOOGLE"`
- **Expected output (step 1)**:
  - HTTP response code: `307` (redirect to login) or `200` (login page)
  - SSL certificate: Valid, issued by Google Trust Services
  - No SSL errors (certificate must be ACTIVE from Section 3.2)
- **Expected output (step 2)**:
  - Exit code 0 (string "LOG IN VIA GOOGLE" found in HTML response)
- **Success criteria**: Both curl commands succeed, confirming HTTPS connection with valid certificate and login page renders correctly

**Section 3.6: Google SSO Login Test**
- **Action**: Test Google SSO authentication flow for both groups
- **Test Case 1: DevOps Admin Login**:
  - Navigate to: `https://argocd-east4.pcconnect.ai`
  - Click "LOG IN VIA GOOGLE"
  - Authenticate with gcp-devops@pcconnect.ai user
  - Expected: OAuth flow completes, redirects to ArgoCD UI, user logged in with admin role
  - Verify admin access: Can see Settings menu, Repositories, Clusters

- **Test Case 2: Developer Login**:
  - Open incognito/private window
  - Navigate to: `https://argocd-east4.pcconnect.ai`
  - Click "LOG IN VIA GOOGLE"
  - Authenticate with gcp-developers@pcconnect.ai user
  - Expected: OAuth flow completes, redirects to ArgoCD UI, user logged in with developer role
  - Verify limited access: Can see Applications, cannot see Settings menu

- **Success criteria**: Both groups can authenticate via Google SSO, RBAC roles applied correctly

**Module 3 Output**: Component Verification Complete
- **Deliverable**: ArgoCD prod accessible via HTTPS, SSL active, SSO functional
- **Verification**: `https://argocd-east4.pcconnect.ai` loads with valid SSL, Google SSO works
- **Next step**: Proceed to Module 4 (Backup & HA Validation)

---

##### Module 4: Backup & HA Validation (15-22 min)

**Purpose**: Validate Redis persistence, Cloud Storage backups, HA leader election, and pod distribution

**Section 4.1: Redis PVC Verification**
- **Action**: Verify Redis persistent volume claims are created and bound
- **Expected PVCs**: 3 PVCs for 3 Redis pods (HA configuration)
- **Verification command**: `kubectl -n argocd get pvc`
- **Expected output** (redis-ha chart PVC naming):
  ```
  NAME                              STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS
  data-redis-ha-server-0            Bound    pvc-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx   10Gi       RWO            standard-rwo
  data-redis-ha-server-1            Bound    pvc-yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy   10Gi       RWO            standard-rwo
  data-redis-ha-server-2            Bound    pvc-zzzzzzzz-zzzz-zzzz-zzzz-zzzzzzzzzzzz   10Gi       RWO            standard-rwo
  ```
- **Success criteria**: 3 PVCs with STATUS=Bound, CAPACITY=10Gi, STORAGECLASS=standard-rwo

**Section 4.2: Redis Data Persistence Test**
- **Action**: Write test data to Redis, restart pod, verify data persists
- **Connect to Redis master**:
  - Command: `kubectl -n argocd exec -it redis-ha-server-0 -- redis-cli`
  - Note: redis-ha chart names pods as `redis-ha-server-*`
- **Write test key**:
  - Redis command: `SET phase4:5b:test "HA validation complete"`
  - Expected response: `OK`
  - Verify: `GET phase4:5b:test`
  - Expected: `"HA validation complete"`
  - Exit: `exit`

- **Delete Redis pod to trigger restart**:
  - Command: `kubectl -n argocd delete pod redis-ha-server-0`
  - Expected: Pod deleted, StatefulSet controller recreates it

- **Wait for pod recreation**:
  - Command: `kubectl -n argocd wait --for=condition=ready pod/redis-ha-server-0 --timeout=3m`
  - Expected: Pod returns to Ready state within 3 minutes

- **Verify data persisted**:
  - Command: `kubectl -n argocd exec -it redis-ha-server-0 -- redis-cli GET phase4:5b:test`
  - Expected output: `"HA validation complete"`

- **Cleanup test data**:
  - Command: `kubectl -n argocd exec -it redis-ha-server-0 -- redis-cli DEL phase4:5b:test`
  - Expected response: `(integer) 1`

- **Success criteria**: Test data survives pod restart, PVC provides persistence

**Section 4.3: Backup Automation Deferred to Phase 4.6**
- **Note**: Cloud Storage backup infrastructure (bucket, CronJob, IAM bindings) will be implemented in Phase 4.6: Configure Cluster Management
- **Phase 4.5B Focus**: Validates Redis persistence via PVC only (Section 4.2 above)
- **Phase 4.6 Scope**:
  - Terraform: Create `pcc-argocd-prod-backups` Cloud Storage bucket with 7-day lifecycle policy
  - Kubernetes: Deploy backup CronJob with Workload Identity for automated Redis RDB snapshots
  - IAM: Configure `roles/storage.objectCreator` for ArgoCD service account
  - Validation: Full backup chain test (PVC → RDB → Cloud Storage)
- **Rationale**: Backup automation requires additional terraform resources and CronJob manifests that are better suited to cluster management configuration phase

**Section 4.4: Redis HA Leader Election Verification**
- **Action**: Verify Redis Sentinel is managing leader election for HA
- **Check Redis Sentinel status**:
  - Command: `kubectl -n argocd exec redis-ha-server-0 -- redis-cli -p 26379 SENTINEL get-master-addr-by-name mymaster`
  - Expected: Returns IP and port of current Redis master
  - Note: redis-ha chart names pods as `redis-ha-server-*`

- **Identify current master**:
  - Command: `kubectl -n argocd exec redis-ha-server-0 -- redis-cli -p 26379 INFO`
  - Expected: Shows Sentinel info, master status

- **Test failover** (optional, adds 3-5 min):
  - Delete current master pod: `kubectl -n argocd delete pod redis-ha-server-0`
  - Wait 30 seconds: `sleep 30`
  - Check new master: `kubectl -n argocd exec redis-ha-server-1 -- redis-cli -p 26379 SENTINEL get-master-addr-by-name mymaster`
  - Expected: Different Redis pod is now master (automatic failover)
  - Note: Skipping this test is acceptable for initial deployment

- **Success criteria**: Redis Sentinel is active, managing master election

**Section 4.5: Pod Distribution Across Nodes**
- **Action**: Verify HA pods are distributed across multiple nodes (not all on same node)
- **Check pod-to-node mapping**:
  - Command: `kubectl -n argocd get pods -o wide | grep "argocd-server\|argocd-repo-server\|redis-ha"`
  - Expected: Pods distributed across different NODE names (redis-ha-server and redis-ha-haproxy pods)

- **Verify node diversity**:
  - Count unique nodes: `kubectl -n argocd get pods -o jsonpath='{.items[*].spec.nodeName}' | tr ' ' '\n' | sort -u | wc -l`
  - Expected: At least 2 unique nodes (ideally 3+)
  - Note: GKE nodepool should have 3+ nodes for proper HA distribution

- **Check for pod anti-affinity** (optional):
  - Command: `kubectl -n argocd get deploy argocd-server -o yaml | grep -A10 "affinity:"`
  - Expected: May show pod anti-affinity rules (chart default behavior)

- **Success criteria**: HA pods distributed across multiple nodes, not concentrated on single node

**Module 4 Output**: HA Validation Complete (Backup Automation Deferred)
- **Deliverables**:
  - 3 Redis PVCs verified (Bound, 10Gi each)
  - Redis data persistence validated (test key survived pod restart)
  - Redis Sentinel HA verified (leader election active)
  - Pod distribution verified (HA pods spread across multiple nodes)
- **Deferred to Phase 4.6**:
  - Cloud Storage backup bucket creation (terraform)
  - Backup CronJob deployment (kubernetes manifest)
  - IAM bindings for backup automation (Workload Identity)
  - Full backup chain validation (PVC → RDB → Cloud Storage)
---

##### Module 5: Velero Backup Automation (20-30 min)

**Purpose**: Install and configure Velero for automated ArgoCD namespace backups to GCS

**Section 5.1: Velero Installation**
- **Action**: Install Velero v1.12+ with GCS plugin for cluster backups
- **Backup strategy**: Entire `argocd` namespace (includes PVCs, configs, secrets)
- **Storage**: GCS bucket in `pcc-prj-devops-prod`

- **Create GCS backup bucket**:
  - Command:
    ```bash
    gsutil mb -p pcc-prj-devops-prod -c STANDARD -l us-east4 gs://pcc-argocd-velero-backups-prod/
    ```
  - Enable versioning:
    ```bash
    gsutil versioning set on gs://pcc-argocd-velero-backups-prod/
    ```
  - Set lifecycle (delete backups older than 30 days):
    ```bash
    cat <<EOF | gsutil lifecycle set /dev/stdin gs://pcc-argocd-velero-backups-prod/
    {
      "rule": [{
        "action": {"type": "Delete"},
        "condition": {"age": 30}
      }]
    }
    EOF
    ```

- **Create Velero GCP service account**:
  - Command:
    ```bash
    gcloud iam service-accounts create velero-backup \
      --display-name="Velero Backup Service Account" \
      --project=pcc-prj-devops-prod
    ```

- **Grant bucket access**:
  - Command:
    ```bash
    gcloud projects add-iam-policy-binding pcc-prj-devops-prod \
      --member="serviceAccount:velero-backup@pcc-prj-devops-prod.iam.gserviceaccount.com" \
      --role="roles/storage.objectAdmin"
    ```

- **Create Workload Identity binding for Velero**:
  - Command:
    ```bash
    gcloud iam service-accounts add-iam-policy-binding velero-backup@pcc-prj-devops-prod.iam.gserviceaccount.com \
      --role roles/iam.workloadIdentityUser \
      --member "serviceAccount:pcc-prj-devops-prod.svc.id.goog[velero/velero]" \
      --project=pcc-prj-devops-prod
    ```

- **Install Velero CLI** (if not installed):
  - Download: `wget https://github.com/vmware-tanzu/velero/releases/download/v1.12.3/velero-v1.12.3-linux-amd64.tar.gz`
  - Extract: `tar -xvf velero-v1.12.3-linux-amd64.tar.gz`
  - Move: `sudo mv velero-v1.12.3-linux-amd64/velero /usr/local/bin/`
  - Verify: `velero version --client-only`

- **Install Velero server components**:
  - Command structure (multi-line):
    ```bash
    velero install \
      --provider gcp \
      --plugins velero/velero-plugin-for-gcp:v1.8.0 \
      --bucket pcc-argocd-velero-backups-prod \
      --backup-location-config serviceAccount=velero-backup@pcc-prj-devops-prod.iam.gserviceaccount.com \
      --use-node-agent \
      --use-volume-snapshots=false \
      --wait
    ```
  - Single-line: `velero install --provider gcp --plugins velero/velero-plugin-for-gcp:v1.8.0 --bucket pcc-argocd-velero-backups-prod --backup-location-config serviceAccount=velero-backup@pcc-prj-devops-prod.iam.gserviceaccount.com --use-node-agent --use-volume-snapshots=false --wait`
  - Expected: Creates `velero` namespace with Velero server and node-agent pods

- **Annotate Velero service account for Workload Identity**:
  - Command:
    ```bash
    kubectl annotate serviceaccount velero \
      --namespace velero \
      iam.gke.io/gcp-service-account=velero-backup@pcc-prj-devops-prod.iam.gserviceaccount.com
    ```

- **Verify Velero installation**:
  - Command: `kubectl -n velero get pods`
  - Expected: velero pod and node-agent DaemonSet pods Running
  - Wait: `kubectl -n velero wait --for=condition=ready pod -l component=velero --timeout=300s`

**Section 5.2: Configure Scheduled Backups**
- **Action**: Create backup schedules for ArgoCD namespace

- **Create daily full backup schedule**:
  - Command:
    ```bash
    velero schedule create argocd-daily \
      --schedule="0 2 * * *" \
      --include-namespaces argocd \
      --ttl 720h0m0s \
      --snapshot-volumes=true
    ```
  - Schedule: 2 AM daily (UTC)
  - Retention: 30 days (720 hours)
  - Includes: All resources in `argocd` namespace + PVCs

- **Create hourly incremental backup schedule** (optional, for RTO < 1 hour):
  - Command:
    ```bash
    velero schedule create argocd-hourly \
      --schedule="0 * * * *" \
      --include-namespaces argocd \
      --ttl 72h0m0s \
      --snapshot-volumes=true
    ```
  - Schedule: Every hour on the hour
  - Retention: 3 days (72 hours)

- **Verify schedules created**:
  - Command: `velero schedule get`
  - Expected: Shows argocd-daily (and argocd-hourly if created) schedules

**Section 5.3: Test Backup and Restore**
- **Action**: Perform test backup and partial restore to validate Velero functionality

- **Create on-demand test backup**:
  - Command:
    ```bash
    velero backup create argocd-test-backup \
      --include-namespaces argocd \
      --wait
    ```
  - Expected: Backup completes with status=Completed
  - Duration: 2-5 minutes (depends on namespace size)

- **Verify backup in GCS**:
  - Command: `gsutil ls gs://pcc-argocd-velero-backups-prod/backups/argocd-test-backup/`
  - Expected: Shows backup metadata and restic volume snapshots

- **Verify backup status**:
  - Command: `velero backup describe argocd-test-backup --details`
  - Expected: Phase=Completed, no errors, includes PVC snapshots
  - Check resources: Should show count of backed-up resources (pods, services, secrets, PVCs, etc.)

- **Document restore procedure** (DO NOT execute, just document):
  - Restore command (for disaster recovery):
    ```bash
    # Complete namespace restore
    velero restore create --from-backup argocd-test-backup --wait

    # Selective restore (secrets only)
    velero restore create --from-backup argocd-test-backup \
      --include-resources secrets \
      --namespace-mappings argocd:argocd-restore
    ```
  - Note: Full restore testing deferred to dedicated DR drill (outside Phase 4 scope)

**Section 5.4: Cleanup Test Backup**
- **Action**: Delete test backup after validation

- **Delete test backup**:
  - Command: `velero backup delete argocd-test-backup --confirm`
  - Expected: Backup deleted from cluster and GCS

- **Verify deletion**:
  - Command: `velero backup get`
  - Expected: argocd-test-backup no longer listed

**Module 5 Deliverables**:
- Velero v1.12+ installed in `velero` namespace
- GCS bucket `pcc-argocd-velero-backups-prod` created with 30-day lifecycle
- Workload Identity configured for Velero service account
- Daily backup schedule (2 AM UTC, 30-day retention)
- Optional hourly backup schedule (every hour, 3-day retention)
- Backup validation completed (test backup created and verified in GCS)
- Restore procedure documented

**Success Criteria**:
- ✅ Velero pods Running and Ready
- ✅ Backup schedule active
- ✅ Test backup completed successfully
- ✅ Backup visible in GCS bucket
- ✅ Backup includes PVC snapshots (Redis data)

---

**Phase 4.10 Complete**: ArgoCD prod fully deployed with HA configuration, mTLS, and automated backups

---

**Phase 4.10 Deliverables**:
- **ArgoCD Core**: v3.1.9 installed on devops-prod cluster with HA configuration
- **Pods**: 15 ArgoCD pods running (3 API servers, 2 repo servers, 3 Redis-HA, 3 HAProxy, 2 Dex, 1 controller, 1 applicationset)
- **Ingress**: GKE Ingress configured with Google-managed SSL certificate (ACTIVE) at https://argocd-east4.pcconnect.ai
- **cert-manager**: v1.13+ installed in cert-manager namespace with self-signed CA issuer
- **Redis mTLS**: TLS certificates issued by cert-manager for Redis pod-to-pod encryption
  - Certificate: redis-tls covering all Redis HA DNS names
  - Authentication: Password-based auth + mTLS client certificates
  - In-transit encryption: All Redis traffic encrypted (TLS port 6379, non-TLS port disabled)
- **Velero**: v1.12+ installed for automated namespace backups
  - Backup schedules: Daily (2 AM UTC, 30-day retention) + optional hourly (3-day retention)
  - Storage: GCS bucket `pcc-argocd-velero-backups-prod` with 30-day lifecycle
  - Test backup validated (includes PVC snapshots)
- Google SSO functional for both groups (gcp-devops admin, gcp-developers view+sync)
- Redis persistence verified with 3x 10Gi PVCs
- Redis HA with Sentinel leader election verified (3 Sentinel instances)
- Pod distribution across multiple nodes verified
- **Note**: Cloud Storage backup automation deferred to Phase 4.6

**Duration Estimate**: 95-135 minutes total
- Module 1 (Pre-flight Checks & Dependencies): 25-35 min (includes cert-manager + Redis TLS setup)
- Module 2 (Helm Deployment): 15-20 min (includes progressive HA pod status checks with mTLS)
- Module 3 (Component Verification): 15-20 min (includes SSL cert ACTIVE wait)
- Module 4 (Backup & HA Validation): 15-22 min (comprehensive validation)
- Module 5 (Velero Backup Automation): 20-30 min (Velero installation + backup schedules + testing)
- Buffer: 5 min (cert-manager cert provisioning, Velero backup completion)
- Note: Significantly longer than nonprod (95-135 min vs 28-40 min) due to cert-manager, mTLS, HA validation, Velero, and more pods to stabilize

**Phase 4.11 Readiness Criteria** (checklist for proceeding to cluster management configuration):
- ✅ ArgoCD prod accessible via HTTPS with valid SSL certificate (ACTIVE)
- ✅ Google SSO authentication working for both groups (devops + developers)
- ✅ RBAC permissions verified (admin for devops, view+sync for developers)
- ✅ All 15 HA pods Running and Ready
- ✅ cert-manager installed and issuing certificates (redis-ca and redis-tls Ready)
- ✅ Redis mTLS functional (TLS port 6379 active, non-TLS port 0 disabled)
- ✅ Redis PVCs created and bound (3x 10Gi)
- ✅ Redis data persistence validated (survives pod restart)
- ✅ Redis Sentinel HA verified (leader election active)
- ✅ Velero installed and backup schedules active (daily + optional hourly)
- ✅ Velero test backup completed successfully (verified in GCS)
- ✅ Pod distribution across multiple nodes (not concentrated on single node)
- ✅ No errors in ArgoCD component logs (API server, repo-server, application-controller)
- ✅ Ingress backend healthy (GKE load balancer health checks passing)

---

#### Phase 4.11: Configure Cluster Management & Backup Automation (Prod) (45-60 min)

**Objective**: Register app-devtest cluster with prod ArgoCD and implement automated backup infrastructure

**⚠️ IMPORTANT for Claude Code Execution**: Before presenting ANY command block in this phase, Claude MUST explicitly remind the user: "Please open WARP terminal now to execute the following commands." Wait for user acknowledgment before proceeding with command presentation.

**Execution Structure**: Three modular sections executed sequentially
1. **Module 1: Pre-flight Checks** (5-8 min) - Verify Connect Gateway, Workload Identity, and IAM prerequisites
2. **Module 2: Cluster Registration & Backup Automation** (30-40 min) - Register cluster, deploy terraform backup infrastructure, configure CronJob
3. **Module 3: Validation** (7-10 min) - Verify cluster registration, backup automation, and full backup chain

**Key Architectural Context**:
- **Cluster management**: Prod ArgoCD manages app-devtest via Connect Gateway (private GKE cluster)
- **Authentication**: Service account `argocd-controller@pcc-prj-devops-prod.iam.gserviceaccount.com` with Workload Identity
- **Backup strategy**: Daily Redis RDB snapshots → Cloud Storage (30-day retention)
- **IAM prerequisites**: container.admin + gkehub.gatewayAdmin (from Phase 3)

**Dependencies**:
- Phase 4.5B complete (ArgoCD installed on prod with HA and Workload Identity)
- Phase 3 complete (Connect Gateway configured, IAM bindings applied: container.admin + gkehub.gatewayAdmin)
- **Phase 4.0 completed** - Required GCP APIs enabled (dns, storage) (BLOCKING)
- Phase 3.0 complete (container, compute APIs enabled)
- Phase 3.1 complete (gkehub, connectgateway APIs enabled)
- kubectl access to both devops-prod and app-devtest clusters via Connect Gateway
- Terraform v1.6+ installed locally
- ArgoCD CLI installed and authenticated to prod instance

---

##### Module 1: Pre-flight Checks (5-8 min)

**Purpose**: Verify all prerequisites before cluster registration and backup deployment

**Section 1.1: Connect Gateway Validation & Registration**
- **Action**: Verify app-devtest cluster is registered with Connect Gateway and accessible
- **Fleet membership verification**:
  - Command: `gcloud container fleet memberships list --project pcc-prj-app-devtest`
  - Expected output (if already registered):
    ```
    NAME                EXTERNAL_ID
    pcc-gke-app-devtest gke://projects/pcc-prj-app-devtest/locations/us-east4/clusters/pcc-gke-app-devtest
    ```
  - Success criteria: Membership exists with correct EXTERNAL_ID

**⚠️ If membership NOT found - Register Cluster with Connect Gateway**:

- **Register app-devtest cluster with GKE Hub fleet**:
  ```bash
  gcloud container fleet memberships register pcc-gke-app-devtest \
    --gke-cluster=us-east4/pcc-gke-app-devtest \
    --project=pcc-prj-app-devtest \
    --enable-workload-identity
  ```
  - Expected output: `Created membership [pcc-gke-app-devtest]`
  - Duration: 1-2 minutes

- **Verify membership registration**:
  ```bash
  gcloud container fleet memberships describe pcc-gke-app-devtest \
    --project=pcc-prj-app-devtest \
    --format="value(name,state.code)"
  ```
  - Expected: `pcc-gke-app-devtest READY`

- **Grant ArgoCD service account Connect Gateway access** (from devops-prod):
  ```bash
  # Grant gkehub.gatewayAdmin role for Connect Gateway kubectl access
  gcloud projects add-iam-policy-binding pcc-prj-app-devtest \
    --member="serviceAccount:argocd-application-controller@pcc-prj-devops-prod.iam.gserviceaccount.com" \
    --role="roles/gkehub.gatewayAdmin"
  
  # Grant container.clusterViewer role for cluster metadata access
  gcloud projects add-iam-policy-binding pcc-prj-app-devtest \
    --member="serviceAccount:argocd-application-controller@pcc-prj-devops-prod.iam.gserviceaccount.com" \
    --role="roles/container.clusterViewer"
  ```
  - Expected: 2 IAM policy bindings created
  - Note: These permissions allow ArgoCD to manage applications on app-devtest via Connect Gateway

- **Generate Connect Gateway kubeconfig context**:
  ```bash
  gcloud container fleet memberships get-credentials pcc-gke-app-devtest \
    --project=pcc-prj-app-devtest
  ```
  - Expected: Adds Connect Gateway context to ~/.kube/config
  - Context name format: `connectgateway_pcc-prj-app-devtest_us-east4_pcc-gke-app-devtest`

**✅ Cluster registration complete** - Continue with kubectl connectivity test

- **kubectl connectivity test**:
  - Command: `kubectl --context=connectgateway_pcc-prj-app-devtest_us-east4_pcc-gke-app-devtest get nodes`
  - Alternative context format: `gke_pcc-prj-app-devtest_us-east4_pcc-gke-app-devtest`
  - Expected: Returns 3+ nodes without authentication errors
  - Note: Connect Gateway context format may vary based on gcloud version

- **Namespace verification**:
  - Command: `kubectl --context=connectgateway_pcc-prj-app-devtest_us-east4_pcc-gke-app-devtest get namespaces`
  - Expected: Lists namespaces including `kube-system`, `default`
  - Success criteria: No permission errors, cluster is accessible

**Section 1.2: Workload Identity Verification**
- **Action**: Verify ArgoCD controller pods have Workload Identity annotation for backup automation
- **Switch to devops-prod cluster context**:
  - Command: `kubectl config use-context gke_pcc-prj-devops-prod_us-east4_pcc-gke-devops-prod`
  - Expected: Current context switches to prod cluster

- **List all ServiceAccounts in argocd namespace** (identify exact ServiceAccount name):
  - Command: `kubectl get serviceaccounts -n argocd`
  - Expected output: Shows all ServiceAccounts including `argocd-application-controller` or similar
  - **Note**: Helm chart ServiceAccount naming may vary depending on chart version and values configuration
  - Identify the controller ServiceAccount name from this list for use in the next step

- **Check application-controller ServiceAccount annotation**:
  - Command: `kubectl get serviceaccount argocd-application-controller -n argocd -o yaml | grep "iam.gke.io/gcp-service-account"`
  - Expected output: `iam.gke.io/gcp-service-account: argocd-controller@pcc-prj-devops-prod.iam.gserviceaccount.com`
  - **Note**: Verify the exact ServiceAccount name with the previous command, then check the annotation on that specific account
  - If ServiceAccount name differs, adjust the command: `kubectl get serviceaccount <ACTUAL_NAME> -n argocd -o yaml | grep "iam.gke.io/gcp-service-account"`

- **Verify Workload Identity binding**:
  - Command: `gcloud iam service-accounts get-iam-policy argocd-controller@pcc-prj-devops-prod.iam.gserviceaccount.com --project pcc-prj-devops-prod --flatten="bindings[].members" --filter="bindings.role:roles/iam.workloadIdentityUser"`
  - Expected: Shows binding for `serviceAccount:pcc-prj-devops-prod.svc.id.goog[argocd/argocd-application-controller]`
  - Success criteria: Workload Identity binding exists

**Section 1.3: IAM Permissions Verification**
- **Action**: Verify ArgoCD service account has required IAM roles for cluster management and backups
- **Required IAM roles** (from Phase 3):
  1. **container.admin** (app-devtest cluster management)
     - Command: `gcloud projects get-iam-policy pcc-prj-app-devtest --flatten="bindings[].members" --filter="bindings.members:serviceAccount:argocd-controller@pcc-prj-devops-prod.iam.gserviceaccount.com AND bindings.role:roles/container.admin"`
     - Expected: Returns container.admin binding

  2. **gkehub.gatewayAdmin** (Connect Gateway access)
     - Command: `gcloud projects get-iam-policy pcc-prj-app-devtest --flatten="bindings[].members" --filter="bindings.members:serviceAccount:argocd-controller@pcc-prj-devops-prod.iam.gserviceaccount.com AND bindings.role:roles/gkehub.gatewayAdmin"`
     - Expected: Returns gkehub.gatewayAdmin binding

  3. **Connect Gateway API quota verification**:
     - **Purpose**: Ensure Connect Gateway API has sufficient quota for kubectl operations
     - Command: `gcloud services list --enabled --project=pcc-prj-app-devtest --filter="name:gkehub.googleapis.com"`
     - Expected: Shows `gkehub.googleapis.com` is enabled
     - **Check API quota limits**:
       - Command: `gcloud alpha compute project-info describe --project=pcc-prj-app-devtest --format="json" | jq -r '.quotas[] | select(.metric | contains("CPUS"))' 2>/dev/null || echo "✓ Quota check not critical for Connect Gateway"`
       - Note: Connect Gateway quotas are service-level, not project-level (managed by Google)
     - **Verify recent API activity** (optional - checks if API is responsive):
       - Command: `gcloud container hub memberships list --project=pcc-prj-app-devtest --filter="name:projects/pcc-prj-app-devtest/locations/us-east4/memberships/pcc-gke-app-devtest"`
       - Expected: Shows app-devtest cluster membership (confirms API is responsive)
     - **Important notes**:
       - Connect Gateway has generous default quotas (60 requests/minute per cluster)
       - If hitting quota limits: GCP Console → APIs & Services → Connect Gateway API → Quotas
       - Quota exhaustion symptoms: 429 errors, "RESOURCE_EXHAUSTED" messages during `argocd cluster add`
       - Retry with exponential backoff if quota errors occur during registration
     - **Success criteria**: gkehub API enabled, cluster membership visible

- **Success criteria**: Both IAM roles present, Connect Gateway API accessible with sufficient quota

**Section 1.4: ArgoCD CLI Authentication**
- **Action**: Verify ArgoCD CLI is authenticated to prod instance
- **Get admin password** (if not already authenticated):
  - Command: `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d`
  - Expected: Returns admin password (store securely)

- **Login to ArgoCD**:
  - Command: `argocd login argocd-east4.pcconnect.ai --username admin --password <password-from-previous-step>`
  - Expected output: `'admin:login' logged in successfully`
  - Alternative: Use Google SSO if already configured

- **Verify authentication**:
  - Command: `argocd cluster list`
  - Expected: Returns in-cluster only (no external clusters yet)
  - Output example:
    ```
    SERVER                          NAME        VERSION  STATUS      MESSAGE
    https://kubernetes.default.svc  in-cluster  1.31     Successful
    ```

**Module 1 Output**: Pre-flight Checks Complete
- **Deliverable**: All prerequisites verified for cluster registration and backup automation
- **Verification**: Connect Gateway accessible, Workload Identity configured, IAM permissions validated, ArgoCD CLI authenticated
- **Next step**: Proceed to Module 2 (Cluster Registration & Backup Automation)

---

##### Module 2: Cluster Registration & Backup Automation (30-40 min)

**Purpose**: Register app-devtest cluster with ArgoCD and deploy automated backup infrastructure

**Section 2.1: Cluster Registration with ArgoCD**
- **Action**: Register app-devtest cluster using ArgoCD CLI with Connect Gateway context

- **Determine correct context name** (REQUIRED before running registration):
  - Command: `kubectl config get-contexts | grep -E 'connectgateway|gke.*app-devtest'`
  - Expected output: Shows context name(s) for app-devtest cluster
  - **Note**: Connect Gateway context format varies by gcloud CLI version:
    - Newer versions: `connectgateway_pcc-prj-app-devtest_us-east4_pcc-gke-app-devtest`
    - Older versions: `gke_pcc-prj-app-devtest_us-east4_pcc-gke-app-devtest`
  - **Copy the exact context name** from this output for use in the command below

- **Cluster registration command** (replace `<CONTEXT_NAME>` with value from previous step):
  ```bash
  argocd cluster add <CONTEXT_NAME> \
    --name app-devtest \
    --kubeconfig ~/.kube/config
  ```

  **Example with connectgateway format**:
  ```bash
  argocd cluster add connectgateway_pcc-prj-app-devtest_us-east4_pcc-gke-app-devtest \
    --name app-devtest \
    --kubeconfig ~/.kube/config
  ```

- **Expected output**:
  ```
  INFO[0000] ServiceAccount "argocd-manager" created in namespace "kube-system"
  INFO[0000] ClusterRole "argocd-manager-role" created
  INFO[0000] ClusterRoleBinding "argocd-manager-role-binding" created
  INFO[0002] Created bearer token secret for ServiceAccount "argocd-manager"
  Cluster 'https://connectgateway.googleapis.com/v1/projects/1234567890/locations/us-east4/gkeMemberships/pcc-gke-app-devtest' added
  ```

- **What this command does**:
  1. Creates `argocd-manager` ServiceAccount in app-devtest cluster's kube-system namespace
  2. Creates ClusterRole with admin permissions for ArgoCD to manage cluster resources
  3. Creates ClusterRoleBinding linking ServiceAccount to ClusterRole
  4. Generates bearer token secret for authentication
  5. Stores cluster credentials in ArgoCD's `argocd-cluster-<cluster-name>` Secret

- **Troubleshooting**:
  - **Error: "context not found"**: Verify context name with `kubectl config get-contexts`
  - **Error: "permission denied"**: Verify IAM roles from Module 1, Section 1.3
  - **Error: "unable to create ServiceAccount"**: Check kubectl access with command from Module 1, Section 1.1

**Section 2.2: Verify Cluster Registration**
- **Action**: Confirm cluster appears in ArgoCD with healthy status
- **ArgoCD CLI verification**:
  - Command: `argocd cluster list`
  - Expected output:
    ```
    SERVER                                                                                               NAME         VERSION  STATUS      MESSAGE
    https://kubernetes.default.svc                                                                       in-cluster   1.31     Successful
    https://connectgateway.googleapis.com/v1/projects/1234567890/locations/us-east4/gkeMemberships/...  app-devtest  1.31     Successful
    ```
  - Success criteria: app-devtest cluster shows STATUS=Successful

- **Check cluster secret in ArgoCD**:
  - Command: `kubectl -n argocd get secret -l argocd.argoproj.io/secret-type=cluster`
  - Expected output: Shows secret for app-devtest cluster
  - Example:
    ```
    NAME                                      TYPE     DATA   AGE
    cluster-app-devtest-<random-suffix>      Opaque   3      30s
    ```

- **ArgoCD UI verification**:
  - Navigate to: `https://argocd-east4.pcconnect.ai/settings/clusters`
  - Expected: app-devtest cluster listed with green "Successful" status
  - Verify connection info shows Connect Gateway URL

- **Verify RBAC permissions in app-devtest cluster**:
  - **Purpose**: Confirm `argocd cluster add` created all required Kubernetes RBAC resources
  - **Switch to app-devtest cluster context**:
    - Command: `kubectl config use-context connectgateway_pcc-prj-app-devtest_us-east4_pcc-gke-app-devtest`
    - Note: Use the same context name from Section 2.1 cluster registration
  - **Verify ServiceAccount**:
    - Command: `kubectl -n kube-system get serviceaccount argocd-manager`
    - Expected: Shows argocd-manager ServiceAccount with age matching cluster registration time
  - **Verify ClusterRole**:
    - Command: `kubectl get clusterrole argocd-manager-role`
    - Expected: Shows argocd-manager-role ClusterRole
    - Verify permissions: `kubectl get clusterrole argocd-manager-role -o yaml | grep -A 5 "rules:"`
    - Expected rules include: `apiGroups: ["*"]`, `resources: ["*"]`, `verbs: ["*"]` (admin permissions)
  - **Verify ClusterRoleBinding**:
    - Command: `kubectl get clusterrolebinding argocd-manager-role-binding`
    - Expected: Shows argocd-manager-role-binding ClusterRoleBinding
    - Verify binding: `kubectl get clusterrolebinding argocd-manager-role-binding -o yaml | grep -A 5 "subjects:"`
    - Expected: Links ServiceAccount `kube-system/argocd-manager` to ClusterRole `argocd-manager-role`
  - **Verify bearer token secret**:
    - Command: `kubectl -n kube-system get secret -l "kubernetes.io/service-account.name=argocd-manager"`
    - Expected: Shows secret with type `kubernetes.io/service-account-token`
  - **Switch back to devops-prod cluster**:
    - Command: `kubectl config use-context gke_pcc-prj-devops-prod_us-east4_pcc-gke-devops-prod`
  - **Success criteria**: All RBAC resources exist with correct configuration, ArgoCD has cluster-admin permissions

**Section 2.3: Terraform Backup Infrastructure Deployment**
- **Action**: Deploy Cloud Storage bucket and IAM bindings for automated Redis backups
- **Navigate to terraform directory**:
  - Command: `cd /home/jfogarty/pcc/infra/pcc-app-shared-infra/terraform`

- **Verify terraform file exists**:
  - Command: `ls -la argocd-backup.tf`
  - Expected: File exists (created in this phase)
  - Contents: 2 module calls to generic `pcc-tf-library` modules:
    - `gcs-bucket` module (Cloud Storage bucket for backups)
    - `storage-iam-binding` module (IAM binding for argocd-controller SA)
  - **⚠️ IMPORTANT**: Bucket module configuration must include lifecycle rule with `age = 30` days (not 7 days)
  - Lifecycle rule configuration: `condition { age = 30 }` + `action { type = "Delete" }`

- **Initialize terraform** (if needed):
  - Command: `terraform init`
  - Expected: Terraform initializes, downloads Google provider
  - Note: Skip if already initialized in previous phases

- **Plan terraform changes**:
  - Command: `terraform plan -out=argocd-backup.tfplan`
  - Expected output:
    ```
    Terraform will perform the following actions:

      # module.argocd_backup_bucket.google_storage_bucket.this will be created
      + resource "google_storage_bucket" "this" {
          + name          = "pcc-argocd-prod-backups"
          + location      = "US-EAST4"
          + storage_class = "STANDARD"
          ...
        }

      # module.argocd_backup_iam.google_storage_bucket_iam_member.this will be created
      + resource "google_storage_bucket_iam_member" "this" {
          + bucket = "pcc-argocd-prod-backups"
          + role   = "roles/storage.objectCreator"
          + member = "serviceAccount:argocd-controller@pcc-prj-devops-prod.iam.gserviceaccount.com"
          ...
        }

    Plan: 2 to add, 0 to change, 0 to destroy.
    ```
  - Success criteria: 2 module resources to add (bucket + IAM binding)

- **⚠️ Bucket Name Collision Scenario**:
  - **Issue**: Cloud Storage bucket names are globally unique across all GCP projects
  - **Symptoms**: `terraform plan` or `terraform apply` fails with error:
    ```
    Error: Error creating bucket: googleapi: Error 409: You already own this bucket.
    Please select another name., conflict
    ```
  - **Common causes**:
    1. Bucket was created in a previous deployment and not destroyed
    2. Another GCP project (possibly in another organization) owns this bucket name
    3. Bucket was recently deleted (soft-deleted buckets reserve name for 30 days)
  - **Resolution steps**:
    1. **Check if bucket exists in current project**:
       - Command: `gcloud storage buckets describe gs://pcc-argocd-prod-backups --project=pcc-prj-devops-prod 2>&1`
       - If exists: Bucket is already created, safe to import into terraform state
       - Import command: `terraform import module.argocd_backup_bucket.google_storage_bucket.this pcc-argocd-prod-backups`
    2. **Check if bucket exists in different project** (requires org-level permissions):
       - Command: `gcloud storage buckets describe gs://pcc-argocd-prod-backups 2>&1 | grep "project"`
       - If different project: Must choose different bucket name
    3. **Bucket name alternatives** (if name collision):
       - Pattern: `pcc-argocd-prod-backups-<random-suffix>`
       - Example: `pcc-argocd-prod-backups-us-east4-001`
       - Update terraform `argocd-backup.tf` with new bucket name
       - Update CronJob manifest `BACKUP_BUCKET` environment variable
  - **Prevention**: Use project-specific or region-specific naming patterns with random suffixes

- **Apply terraform**:
  - Command: `terraform apply argocd-backup.tfplan`
  - Expected output:
    ```
    module.argocd_backup_bucket.google_storage_bucket.this: Creating...
    module.argocd_backup_bucket.google_storage_bucket.this: Creation complete after 3s
    module.argocd_backup_iam.google_storage_bucket_iam_member.this: Creating...
    module.argocd_backup_iam.google_storage_bucket_iam_member.this: Creation complete after 2s

    Apply complete! Resources: 2 added, 0 changed, 0 destroyed.

    Outputs:
    argocd_backup_bucket_name = "pcc-argocd-prod-backups"
    argocd_backup_bucket_url = "gs://pcc-argocd-prod-backups"
    ```

- **Verify Cloud Storage bucket**:
  - Command: `gcloud storage buckets describe gs://pcc-argocd-prod-backups --project=pcc-prj-devops-prod`
  - Expected: Bucket exists with location=US-EAST4, lifecycle policy with 7-day delete rule

**Section 2.4: Verify IAM Binding for Backups**
- **Action**: Confirm ArgoCD service account has storage.objectCreator role
- **Check IAM binding**:
  - Command: `gcloud storage buckets get-iam-policy gs://pcc-argocd-prod-backups --project=pcc-prj-devops-prod --flatten="bindings[].members" --filter="bindings.role:roles/storage.objectCreator"`
  - Expected output:
    ```
    bindings:
    - members:
      - serviceAccount:argocd-controller@pcc-prj-devops-prod.iam.gserviceaccount.com
      role: roles/storage.objectCreator
    ```
  - Success criteria: ArgoCD SA has objectCreator role

**Section 2.5: Deploy Backup CronJob**
- **Action**: Create Kubernetes CronJob for daily Redis backups with Workload Identity
- **Create CronJob manifest file**:
  - File: `/tmp/argocd-backup-cronjob.yaml`
  - Content:
    ```yaml
    apiVersion: batch/v1
    kind: CronJob
    metadata:
      name: argocd-redis-backup
      namespace: argocd
      labels:
        app.kubernetes.io/name: argocd-redis-backup
        app.kubernetes.io/component: backup
    spec:
      schedule: "0 2 * * *"  # Daily at 2 AM UTC
      timeZone: "UTC"  # Explicit timezone (Kubernetes 1.27+ feature)
      successfulJobsHistoryLimit: 3
      failedJobsHistoryLimit: 3
      concurrencyPolicy: Forbid  # Prevent overlapping backup jobs
      jobTemplate:
        spec:
          template:
            metadata:
              labels:
                app.kubernetes.io/name: argocd-redis-backup
            spec:
              serviceAccountName: argocd-application-controller
              restartPolicy: OnFailure
              containers:
              - name: redis-backup
                image: google/cloud-sdk:alpine
                command:
                - /bin/sh
                - -c
                - |
                  set -e
                  echo "Starting ArgoCD Redis backup at $(date)"

                  # Identify Redis master pod
                  REDIS_MASTER=$(kubectl get pods -n argocd -l app.kubernetes.io/name=redis-ha,app.kubernetes.io/component=server -o jsonpath='{.items[0].metadata.name}')
                  echo "Redis master pod: $REDIS_MASTER"

                  # Trigger Redis SAVE to create RDB snapshot
                  kubectl exec -n argocd $REDIS_MASTER -- redis-cli SAVE
                  echo "Redis SAVE command completed"

                  # Copy RDB file from Redis master PVC to local temp
                  kubectl cp argocd/$REDIS_MASTER:/data/dump.rdb /tmp/dump.rdb
                  echo "RDB file copied from Redis pod"

                  # Upload to Cloud Storage with timestamp
                  TIMESTAMP=$(date +%Y%m%d-%H%M%S)
                  gsutil cp /tmp/dump.rdb gs://pcc-argocd-prod-backups/redis-backup-$TIMESTAMP.rdb
                  echo "Backup uploaded to gs://pcc-argocd-prod-backups/redis-backup-$TIMESTAMP.rdb"

                  # Verify upload
                  gsutil ls gs://pcc-argocd-prod-backups/redis-backup-$TIMESTAMP.rdb
                  echo "Backup verified successfully at $(date)"
                # Note: No environment variables needed - Workload Identity authentication
                # is handled automatically via serviceAccountName: argocd-application-controller
                # The service account annotation (iam.gke.io/gcp-service-account) configured
                # in Section 1.2 enables automatic credential injection via GKE metadata service
                resources:
                  requests:
                    cpu: 100m
                    memory: 128Mi
                  limits:
                    cpu: 200m
                    memory: 256Mi
    ```

- **Apply CronJob manifest**:
  - Command: `kubectl apply -f /tmp/argocd-backup-cronjob.yaml`
  - Expected output: `cronjob.batch/argocd-redis-backup created`

- **Verify CronJob creation**:
  - Command: `kubectl get cronjob -n argocd argocd-redis-backup`
  - Expected output:
    ```
    NAME                  SCHEDULE      SUSPEND   ACTIVE   LAST SCHEDULE   AGE
    argocd-redis-backup   0 2 * * *     False     0        <none>          10s
    ```
  - Success criteria: CronJob exists with correct schedule

- **Check CronJob details**:
  - Command: `kubectl describe cronjob -n argocd argocd-redis-backup`
  - Expected: Shows schedule, ServiceAccount (argocd-application-controller), and job history limits
  - Verify: ServiceAccount matches Workload Identity configuration from Module 1

**Module 2 Output**: Cluster Registration & Backup Automation Complete
- **Deliverable**: app-devtest cluster registered, backup infrastructure deployed, CronJob configured
- **Verification**: Cluster shows in ArgoCD, backup bucket created, IAM binding applied, CronJob scheduled
- **Next step**: Proceed to Module 3 (Validation)

---

##### Module 3: Validation (7-10 min)

**Purpose**: Comprehensive validation of cluster registration, backup automation, and full backup chain

**Section 3.1: Cluster Management Validation**
- **Action**: Verify ArgoCD can deploy applications to app-devtest cluster
- **Create test application** (lightweight NGINX deployment):
  - Command:
    ```bash
    argocd app create test-app-devtest \
      --repo https://github.com/argoproj/argocd-example-apps.git \
      --path guestbook \
      --dest-server https://connectgateway.googleapis.com/v1/projects/$(gcloud config get-value project)/locations/us-east4/gkeMemberships/pcc-gke-app-devtest \
      --dest-namespace default
    ```
  - Note: Replace server URL with actual Connect Gateway URL from `argocd cluster list`
  - Expected output: `application 'test-app-devtest' created`

- **Sync test application**:
  - Command: `argocd app sync test-app-devtest`
  - Expected: Application syncs successfully, all resources Healthy
  - Output shows: `GROUP  KIND        NAMESPACE  NAME  STATUS  HEALTH   HOOK  MESSAGE`

- **Verify deployment in app-devtest cluster**:
  - Command: `kubectl --context=connectgateway_pcc-prj-app-devtest_us-east4_pcc-gke-app-devtest get pods -n default`
  - Expected: Guestbook pods running
  - Success criteria: Pods in Running state

- **Delete test application**:
  - Command: `argocd app delete test-app-devtest --yes`
  - Expected: Application deleted cleanly
  - Note: This confirms full CRUD operations work via ArgoCD

**Section 3.2: Backup Automation Validation**
- **Action**: Trigger manual backup job to test full backup chain before waiting 24 hours

- **⚠️ PREREQUISITE: IAM Permissions for Backup Verification**:
  - The terraform configuration (`argocd-backup.tf`) grants `roles/storage.objectCreator` to allow uploading backups
  - **ADDITIONAL PERMISSION REQUIRED**: Backup verification commands (gsutil ls, gsutil du) require `roles/storage.objectViewer`
  - **Add to terraform** (`infra/pcc-app-shared-infra/terraform/argocd-backup.tf`):
    ```hcl
    # IAM binding for backup verification (list/read)
    resource "google_storage_bucket_iam_member" "argocd_backup_viewer" {
      bucket = google_storage_bucket.argocd_prod_backups.name
      role   = "roles/storage.objectViewer"
      member = "serviceAccount:argocd-application-controller@pcc-prj-devops-prod.iam.gserviceaccount.com"
    }
    ```
  - **Apply terraform changes**: Run `terraform apply` in `infra/pcc-app-shared-infra/terraform` to add this permission
  - **Without this permission**: Verification commands below will fail with "403 Forbidden" errors
  - **Alternative verification** (if IAM change is delayed): Use Cloud Console → Storage → pcc-argocd-prod-backups to manually verify backup files

- **Create manual Job from CronJob**:
  - Command: `kubectl create job --from=cronjob/argocd-redis-backup argocd-redis-backup-manual -n argocd`
  - Expected output: `job.batch/argocd-redis-backup-manual created`

- **Monitor Job execution**:
  - Command: `kubectl get job -n argocd argocd-redis-backup-manual -w`
  - Expected: STATUS progresses from 0/1 to 1/1 (Completed)
  - Wait time: 30-60 seconds for job completion

- **Check Job logs**:
  - Command: `kubectl logs -n argocd job/argocd-redis-backup-manual`
  - Expected output (key messages):
    ```
    Starting ArgoCD Redis backup at [timestamp]
    Redis master pod: redis-ha-server-0
    Redis SAVE command completed
    RDB file copied from Redis pod
    Backup uploaded to gs://pcc-argocd-prod-backups/redis-backup-[timestamp].rdb
    Backup verified successfully at [timestamp]
    ```
  - Success criteria: No errors, all steps completed

- **Verify backup in Cloud Storage**:
  - Command: `gsutil ls gs://pcc-argocd-prod-backups/`
  - Expected output: Shows backup file(s) like `redis-backup-20251022-020000.rdb`
  - Alternative: `gcloud storage ls gs://pcc-argocd-prod-backups/ --project=pcc-prj-devops-prod`

- **Check backup file size**:
  - Command: `gsutil du -h gs://pcc-argocd-prod-backups/redis-backup-*.rdb | tail -1`
  - Expected: File size > 0 bytes (typically 100KB-10MB depending on ArgoCD data)
  - Success criteria: Non-zero file size confirms successful backup

**Section 3.3: Full Backup Chain Verification**
- **Action**: Validate complete backup chain from Redis PVC → RDB → Cloud Storage
- **Verify Redis PVC exists and is bound**:
  - Command: `kubectl get pvc -n argocd -l app.kubernetes.io/name=redis-ha`
  - Expected: 3 PVCs (redis-ha-server-0/1/2) with STATUS=Bound
  - Confirms: Data persistence layer operational

- **Check Redis RDB file in PVC**:
  - Command: `kubectl exec -n argocd redis-ha-server-0 -- ls -lh /data/dump.rdb`
  - Expected output: Shows dump.rdb file with recent timestamp and size
  - Example: `-rw-r--r-- 1 redis redis 1.2M Oct 22 02:00 dump.rdb`
  - Success criteria: RDB file exists in Redis data directory

- **Verify Redis RDB file integrity** (data consistency check):
  - **Purpose**: Ensure RDB file is not corrupted and can be restored
  - Command: `kubectl exec -n argocd redis-ha-server-0 -- redis-check-rdb /data/dump.rdb`
  - Expected output:
    ```
    [offset 0] Checking RDB file dump.rdb
    [offset 26] AUX FIELD redis-ver = '7.0.15'
    [offset 40] AUX FIELD redis-bits = '64'
    ...
    [offset XXXXX] Checksum OK
    [offset XXXXX] \o/ RDB looks OK! \o/
    [info] X keys read
    [info] X expires
    [info] X already expired
    ```
  - **Alternative method** (if redis-check-rdb not available):
    - Command: `kubectl exec -n argocd redis-ha-server-0 -- sh -c 'redis-cli --rdb /tmp/test.rdb --rdb-check-mode && echo "✓ RDB integrity verified"'`
  - **Troubleshooting**:
    - If RDB check fails: Redis data may be corrupted, restore from previous backup
    - If command not found: Use backup verification via Cloud Storage instead
  - **Success criteria**: RDB checksum OK, no corruption errors
  - **Note**: This check validates Redis persistence layer integrity before relying on backups for DR

- **Verify backup lifecycle policy**:
  - Command: `gcloud storage buckets describe gs://pcc-argocd-prod-backups --format="value(lifecycle_config.rule)"`
  - Expected: Shows lifecycle rule with age=30 days, action=Delete
  - Confirms: Automatic cleanup of old backups configured

- **Test gsutil access with Workload Identity**:
  - Command: `kubectl run -n argocd gsutil-test --rm -it --image=google/cloud-sdk:alpine --serviceaccount=argocd-application-controller --command -- gsutil ls gs://pcc-argocd-prod-backups/`
  - Expected: Lists backup files without authentication errors
  - Success criteria: Workload Identity authentication works for backup operations
  - Note: Pod will be automatically deleted after command completes (--rm flag)

**Section 3.4: ArgoCD UI Cluster Status**
- **Action**: Final verification that cluster management is fully operational
- **Navigate to Clusters page**:
  - URL: `https://argocd-east4.pcconnect.ai/settings/clusters`
  - Expected: 2 clusters listed:
    1. `in-cluster` (devops-prod) - Successful
    2. `app-devtest` - Successful (green status)

- **Verify cluster connection details**:
  - Click on app-devtest cluster
  - Expected info:
    - Server URL: `https://connectgateway.googleapis.com/v1/projects/.../gkeMemberships/pcc-gke-app-devtest`
    - Status: Successful
    - Version: 1.31.x (matches app-devtest cluster version)
    - Labels/Annotations: Shows cluster metadata

- **Check cluster resource inventory**:
  - ArgoCD UI → Applications → app-devtest cluster resources
  - Expected: Shows namespaces, nodes, and available resources
  - Success criteria: ArgoCD has full visibility into app-devtest cluster

**Module 3 Output**: Validation Complete
- **Deliverable**: Cluster management and backup automation fully validated
- **Verification**: Test app deployed/deleted successfully, manual backup completed, full backup chain operational
- **Next step**: Phase 4.11 complete, proceed to Phase 4.12 (GitHub Integration)

---

**Phase 4.11 Deliverables**:
- app-devtest cluster registered with prod ArgoCD via Connect Gateway
- Cluster credentials configured (argocd-manager SA in app-devtest)
- Cloud Storage backup bucket created: `pcc-argocd-prod-backups` (30-day retention)
- IAM binding applied: `argocd-controller@pcc-prj-devops-prod.iam.gserviceaccount.com` has storage.objectCreator
- Backup CronJob deployed: Daily 2 AM UTC Redis RDB snapshots to Cloud Storage
- Full backup chain validated: Redis PVC → RDB → Cloud Storage
- Cluster shows Successful status in ArgoCD UI

**Dependencies**:
- Phase 4.5B complete (ArgoCD installed on prod with HA and Workload Identity)
- Phase 3 complete (Connect Gateway configured, IAM bindings applied: container.admin + gkehub.gatewayAdmin)
- kubectl access to both devops-prod and app-devtest clusters via Connect Gateway
- Terraform v1.6+ installed and authenticated to pcc-prj-devops-prod
- ArgoCD CLI installed and authenticated to prod instance

**Duration Estimate**: 45-60 minutes total
- Module 1 (Pre-flight): 5-8 min
- Module 2 (Registration + Backup): 30-40 min (includes terraform apply + CronJob deployment)
- Module 3 (Validation): 7-10 min
- Buffer: 5 min

**Phase 4.12 Readiness Criteria**:
- ✅ app-devtest cluster registered and accessible via ArgoCD
- ✅ Cluster status shows "Successful" in ArgoCD UI
- ✅ Test application deployed and deleted successfully
- ✅ Backup infrastructure deployed (bucket, IAM, CronJob)
- ✅ Manual backup job completed successfully
- ✅ Backup file exists in Cloud Storage with non-zero size
- ✅ Full backup chain validated (PVC → RDB → Cloud Storage)

**Critical Notes**:
- **Backup CronJob runs at 2 AM UTC daily** - first automated backup will occur ~24 hours after deployment
- **Manual backup job** (Section 3.2) validates the backup chain immediately without waiting
- **Workload Identity** is critical for backup automation - ArgoCD application-controller SA must have proper annotation
- **Connect Gateway context format** may vary by gcloud version - use `kubectl config get-contexts` to verify exact name
- **Cloud Storage lifecycle policy** automatically deletes backups older than 7 days - no manual cleanup required

---

### GitHub Integration & App-of-Apps (3 subphases)

#### Phase 4.12: Configure GitHub Integration (20-25 min)

**Objective**: Connect prod ArgoCD to GitHub repository

**⚠️ IMPORTANT for Claude Code Execution**: Before presenting ANY command block in this phase, Claude MUST explicitly remind the user: "Please open WARP terminal now to execute the following commands." Wait for user acknowledgment before proceeding with command presentation.

**Execution Structure**: Three modular sections executed sequentially
1. **Module 1: Pre-flight Checks** (5-7 min) - Verify ArgoCD operational, Secret Manager credentials, IAM bindings
2. **Module 2: GitHub Integration** (8-12 min) - Configure GitHub App with Workload Identity
3. **Module 3: Validation & Documentation** (7-10 min) - Test repository connection, HA validation, create docs

**Key Architectural Context** (from previous phases):
- GitHub integration: **GitHub App with Workload Identity** (NO SSH keys or tokens) - Phase 4.3 decision
- Secret Manager: `argocd-github-app-credentials` in pcc-prj-devops-prod
- Repository: `core/pcc-app-argo-config` (read-only access)
- Authentication flow: Kubernetes SA (argocd-repo-server) → GCP SA → GitHub App → Repository access
- Pattern reference: Same as Phase 4.8 nonprod, adapted for prod environment with HA validation
- HA Configuration: 14 pods total (3 server, 2 repo-server, 1 controller, 2 dex, 1 applicationset, 3 redis-ha-server, 3 redis-ha-haproxy)

**Security Considerations**:
- Read-only repository access via GitHub App fine-grained permissions
- No SSH keys or PATs stored
- GitHub App tokens auto-rotate hourly
- Workload Identity prevents credential extraction
- All repository access logged to Cloud Audit Logs

---

##### Module 1: Pre-flight Checks (5-7 min)

**Purpose**: Verify all prerequisites before GitHub repository integration

**ArgoCD Version Requirements**

This module requires **ArgoCD v3.1.9** (Helm chart version 7.7.4) to be deployed. Version documented here for:
- Team reference and troubleshooting
- Change tracking and upgrade planning
- Compatibility verification with GitHub App authentication

**Version verification commands**:
```bash
# Verify ArgoCD server version (from deployed pod)
kubectl -n argocd exec deployment/argocd-server -- argocd version --short --client
# Expected output: argocd: v3.1.9+<commit-sha>

# Verify Helm chart version (from release metadata)
helm list -n argocd --output json | jq -r '.[] | select(.name=="argocd") | {chart: .chart, app_version: .app_version, status: .status}'
# Expected output: {"chart":"argo-cd-7.7.4","app_version":"v3.1.9","status":"deployed"}

# Alternative: Check ArgoCD server pod image tag
kubectl -n argocd get deployment argocd-server -o jsonpath='{.spec.template.spec.containers[0].image}'
# Expected output: quay.io/argoproj/argocd:v3.1.9
```

**Why ArgoCD v3.1.9**:
- **GitHub App support**: Native GitHub App authentication (introduced v2.5+, stable in v3.1+)
- **HA improvements**: Enhanced Redis Sentinel support (3-replica HA with HAProxy)
- **Security**: CVE-2024-xxxxx patches included (multiple critical fixes in v3.1.x)
- **GKE compatibility**: Tested with GKE 1.28+ (Kubernetes 1.28 compatibility)
- **Workload Identity**: Full support for GCP Workload Identity (no sidecar injection needed)

**Compatibility notes**:
- **Kubernetes**: Requires 1.26+ (current GKE devops-prod cluster: 1.28)
- **Helm**: Requires 3.10+ (check with `helm version --short`)
- **kubectl**: Requires 1.26+ (check with `kubectl version --client --short`)
- **GitHub App**: Requires GitHub.com or GitHub Enterprise Server 3.9+

**Upgrade path** (for future reference):
- Current: v3.1.9 (deployed)
- Next minor: v3.2.x (when available, check release notes)
- Major upgrade: v4.0.x (breaking changes expected, plan migration)
- **Upgrade frequency**: Minor versions every 2-3 months, patch versions monthly
- **Testing**: Always test upgrades in nonprod (Phase 4.8) before prod

**Version change tracking**:
- Document version changes in `.claude/docs/argocd-changelog.md`
- Include: Date, old version, new version, reason for upgrade, validation results
- Template:
  ```markdown
  ## 2025-10-23: v3.1.9 Initial Production Deployment
  - **Helm chart**: argo-cd-7.7.4
  - **App version**: v3.1.9
  - **Reason**: Initial prod deployment with GitHub App + HA support
  - **Validated**: GitHub integration, Redis HA, SSO, backup automation
  - **Issues**: None
  ```

---

**Section 0: GitHub App Setup Documentation (One-Time Prerequisite)**

**⚠️ IMPORTANT**: This section documents the one-time GitHub App creation and configuration process. This setup should be completed BEFORE running the pre-flight checks in Sections 1.1-1.4. If the GitHub App already exists and credentials are in Secret Manager, skip to Section 1.1.

- **GitHub App creation overview**:
  - GitHub Apps provide secure, granular access to repositories without requiring SSH keys or personal access tokens
  - ArgoCD uses GitHub App authentication via private key (PEM format)
  - App must be created once per organization, can be installed on multiple repositories
  - Credentials stored in GCP Secret Manager (pcc-prj-devops-prod)

**Step 1: Create GitHub App**
- Navigate to GitHub organization settings:
  - URL: `https://github.com/organizations/YOUR-ORG/settings/apps`
  - Or: GitHub.com → Organization → Settings → Developer settings → GitHub Apps → New GitHub App
- Fill in GitHub App details:
  - **App name**: `PortCo-ArgoCD-Production` (or similar descriptive name)
  - **Homepage URL**: `https://argocd-east4.pcconnect.ai` (ArgoCD prod URL)
  - **Description**: `ArgoCD production instance repository access for GitOps deployments`
  - **Webhook**: Uncheck "Active" (ArgoCD does not require webhooks for basic sync)
  - **Webhook URL**: Leave blank (not needed)
- Set repository permissions (CRITICAL - read-only access only):
  - **Contents**: Read-only (allows ArgoCD to clone and read repository files)
  - **Metadata**: Read-only (default, provides basic repository info)
  - **Pull requests**: No access (ArgoCD does not need PR access)
  - **Issues**: No access (ArgoCD does not need issue access)
  - **Deployments**: No access (ArgoCD does not use GitHub Deployments API)
  - **Checks**: No access (ArgoCD does not write check runs)
  - **Actions**: No access (ArgoCD does not trigger GitHub Actions)
- Set organization permissions:
  - **All organization permissions**: No access (ArgoCD only needs repository access)
- Where can this GitHub App be installed?
  - Select: "Only on this account" (restricts to your organization)
- Click: "Create GitHub App"
- **Success criteria**: App created, redirected to app settings page showing App ID

**Step 2: Generate Private Key**
- On the GitHub App settings page (should still be there after creation):
  - Scroll to "Private keys" section
  - Click: "Generate a private key"
  - Browser downloads file: `portco-argocd-production.2025-10-23.private-key.pem` (or similar)
- **Security critical**:
  - Private key downloads automatically (PEM format, 2048-bit RSA)
  - **Store securely immediately** - this is the only time you can download this key
  - DO NOT commit to Git, DO NOT share via Slack/email
  - Move to secure location: `chmod 600 <key-file>.pem` (restrict permissions)
- Record key details:
  - **File name**: Note the exact filename (includes date for tracking)
  - **Download date**: For key rotation tracking
  - **Expiration**: GitHub recommends rotating keys annually

**Step 3: Get App ID and Installation ID**
- **Get App ID** (from GitHub App settings page):
  - Look for "App ID" field near top of settings page
  - Example: `123456` (numeric ID)
  - Copy this value - required for ArgoCD configuration
  - **Save to secure notes**: Store App ID for reference (not sensitive, but needed)

- **Install GitHub App on organization** (if not already installed):
  - Click "Install App" in left sidebar (or visit `https://github.com/organizations/YOUR-ORG/settings/apps/portco-argocd-production/installations`)
  - Select organization to install on
  - Repository access:
    - Select: "Only select repositories" (principle of least privilege)
    - Choose: `core/pcc-app-argo-config` repository (ArgoCD manifest repo)
    - **DO NOT select "All repositories"** - overly broad access
  - Click: "Install"
  - **Success criteria**: Redirected to installation page showing installation ID in URL

- **Get Installation ID** (from installation URL):
  - After installation, URL shows: `https://github.com/organizations/YOUR-ORG/settings/installations/12345678`
  - Installation ID is the number at the end: `12345678`
  - Alternative method: Via GitHub API:
    ```bash
    # Requires GitHub CLI (gh) authenticated
    gh api /orgs/YOUR-ORG/installations --jq '.installations[] | select(.app_id==123456) | .id'
    ```
  - Copy Installation ID - required for ArgoCD configuration

**Step 4: Create Secret Manager Secret**
- **Prepare JSON credential file** (local workstation):
  ```bash
  # Create JSON structure with your values
  cat > github-app-creds.json <<'EOF'
  {
    "appId": "123456",
    "installationId": "12345678",
    "privateKey": "-----BEGIN RSA PRIVATE KEY-----\n<paste-private-key-content-here>\n-----END RSA PRIVATE KEY-----"
  }
  EOF
  ```
  - **CRITICAL**: Use exact field names: `appId`, `installationId`, `privateKey` (camelCase)
  - **Private key format**: Must include `-----BEGIN RSA PRIVATE KEY-----` and `-----END RSA PRIVATE KEY-----` headers
  - **Newlines in private key**: Use `\n` literal string (not actual newlines) or paste entire key block
  - **Alternative approach** (preserves newlines automatically):
    ```bash
    APP_ID="123456"
    INSTALL_ID="12345678"
    PRIVATE_KEY=$(cat portco-argocd-production.2025-10-23.private-key.pem)

    jq -n \
      --arg appId "$APP_ID" \
      --arg installationId "$INSTALL_ID" \
      --arg privateKey "$PRIVATE_KEY" \
      '{appId: $appId, installationId: $installationId, privateKey: $privateKey}' \
      > github-app-creds.json
    ```

- **Validate JSON structure** (before uploading to Secret Manager):
  ```bash
  jq empty github-app-creds.json && echo "✅ Valid JSON" || echo "❌ Invalid JSON - fix syntax errors"

  # Verify required fields exist
  jq -e '.appId and .installationId and .privateKey' github-app-creds.json && \
    echo "✅ All required fields present" || \
    echo "❌ Missing required fields (appId, installationId, privateKey)"
  ```

- **Create Secret Manager secret**:
  ```bash
  gcloud secrets create argocd-github-app-credentials \
    --project=pcc-prj-devops-prod \
    --replication-policy=automatic \
    --data-file=github-app-creds.json
  ```
  - Expected output: `Created version [1] of the secret [argocd-github-app-credentials]`
  - Verify: `gcloud secrets describe argocd-github-app-credentials --project=pcc-prj-devops-prod`

- **Set IAM permissions** (Secret Manager access for ArgoCD service account):
  ```bash
  gcloud secrets add-iam-policy-binding argocd-github-app-credentials \
    --project=pcc-prj-devops-prod \
    --role=roles/secretmanager.secretAccessor \
    --member="serviceAccount:argocd-repo-server@pcc-prj-devops-prod.iam.gserviceaccount.com"
  ```
  - Expected output: Updated IAM policy for secret
  - Verify: Section 1.3 IAM verification will confirm this binding

- **Securely delete local credential file**:
  ```bash
  shred -vfz -n 3 github-app-creds.json
  shred -vfz -n 3 portco-argocd-production.*.private-key.pem
  ```
  - **Why shred**: Overwrites file 3 times before deletion (prevents recovery)
  - Alternative (macOS): `srm -vz github-app-creds.json`
  - Verify deletion: `ls -la github-app-creds.json` (should show "No such file")

**Step 5: Verify GitHub App Configuration**
- **Test GitHub App installation** (verify repository access):
  ```bash
  # Using GitHub CLI (requires authentication)
  gh api /repos/YOUR-ORG/pcc-app-argo-config/installation
  ```
  - Expected: Returns installation details with app ID and installation ID
  - Success criteria: No 404 errors (app successfully installed on repo)

- **Verify repository permissions** (confirm read-only):
  - Navigate to: `https://github.com/YOUR-ORG/pcc-app-argo-config/settings/installations`
  - Verify: "PortCo-ArgoCD-Production" app listed with "Contents: Read-only"
  - **Critical**: Must be read-only (Git is source of truth, ArgoCD should never push)

- **Document App details** (for team reference):
  - Create file: `.claude/docs/github-app-argocd-prod.md` (in PCC notes repo)
  - Content:
    ```markdown
    # GitHub App: PortCo-ArgoCD-Production

    - **App ID**: 123456
    - **Installation ID**: 12345678 (for ORG organization)
    - **Installed repositories**: core/pcc-app-argo-config
    - **Permissions**: Contents: Read-only, Metadata: Read-only
    - **Private key location**: GCP Secret Manager (argocd-github-app-credentials)
    - **Private key rotation**: Annually (last generated: 2025-10-23)
    - **Created by**: <your-name>
    - **Created date**: 2025-10-23

    ## Key Rotation Process
    1. Generate new private key in GitHub App settings
    2. Update Secret Manager secret version with new key
    3. ArgoCD will automatically use new key (no restart required)
    4. Delete old key from GitHub App settings (after 24h validation)
    ```

**GitHub App Setup Complete**
- **Deliverables**:
  - ✅ GitHub App created with read-only repository access
  - ✅ Private key generated and stored in Secret Manager
  - ✅ App ID and Installation ID documented
  - ✅ Secret Manager secret created with correct JSON structure
  - ✅ IAM permissions granted to ArgoCD service account
  - ✅ Local credential files securely deleted
- **Next step**: Proceed to Section 1.1 (ArgoCD Operational Status Verification)

**Troubleshooting Common Issues**:
- **"GitHub App not found" error**: Verify App ID is correct, check organization access
- **"Private key invalid" error**: Ensure PEM format includes headers, no extra whitespace
- **"Installation not found" error**: Verify Installation ID, check app is installed on repository
- **"Repository not accessible" error**: Verify repository name exact match, check app installed correctly
- **JSON parsing errors**: Validate JSON with `jq empty`, check for trailing commas or missing quotes

---

**Section 1.0: Environment Variables Setup**

**Purpose**: Define reusable environment variables for consistent command execution throughout Phase 4.12. Setting these variables once at the beginning reduces typos, improves maintainability, and makes commands easier to read and modify.

- **Export core environment variables** (run these commands in your terminal):
  ```bash
  # GCP Project and Cluster Configuration
  export PROJECT_ID="pcc-prj-devops-prod"
  export CLUSTER_NAME="pcc-gke-devops-prod"
  export CLUSTER_REGION="us-east4"
  export CLUSTER_ZONE="us-east4-a"  # Primary zone for regional cluster

  # ArgoCD Configuration
  export ARGOCD_NAMESPACE="argocd"
  export ARGOCD_VERSION="v3.1.9"
  export ARGOCD_CHART_VERSION="7.7.4"

  # GitHub Configuration
  export GITHUB_ORG="portco-connect"  # Replace with your actual GitHub organization
  export GITHUB_REPO="pcc-app-argo-config"
  export GITHUB_REPO_URL="https://github.com/${GITHUB_ORG}/${GITHUB_REPO}.git"

  # GCP Service Account Configuration
  export GCP_SA_NAME="argocd-controller"
  export GCP_SA_EMAIL="${GCP_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

  # Kubernetes Service Account Configuration
  export K8S_SA_NAME="argocd-repo-server"
  export K8S_SA_NAMESPACE="${ARGOCD_NAMESPACE}"

  # Secret Manager Configuration
  export SECRET_NAME="argocd-github-app-credentials"
  export SECRET_VERSION="latest"

  # kubectl Context Configuration
  export KUBECTL_CONTEXT="gke_${PROJECT_ID}_${CLUSTER_REGION}_${CLUSTER_NAME}"
  ```

- **Verify environment variables are set**:
  ```bash
  echo "Project ID: $PROJECT_ID"
  echo "Cluster: $CLUSTER_NAME ($CLUSTER_REGION)"
  echo "ArgoCD Version: $ARGOCD_VERSION"
  echo "GitHub Repo: $GITHUB_REPO_URL"
  echo "GCP SA: $GCP_SA_EMAIL"
  echo "K8s SA: $K8S_SA_NAME"
  echo "Secret: $SECRET_NAME"
  echo "Context: $KUBECTL_CONTEXT"
  ```
  - Expected: All variables display correct values without "$" prefix
  - **If any variable is empty**: Re-run the export command for that variable

- **Switch to prod cluster context** (using environment variable):
  ```bash
  kubectl config use-context $KUBECTL_CONTEXT
  ```
  - Expected: `Switched to context "gke_pcc-prj-devops-prod_us-east4_pcc-gke-devops-prod"`
  - **Verify current context**:
    ```bash
    kubectl config current-context
    ```
  - Expected output: `gke_pcc-prj-devops-prod_us-east4_pcc-gke-devops-prod`

**Benefits of using environment variables**:
- ✅ **Consistency**: Same values used across all commands (prevents typos)
- ✅ **Maintainability**: Change value once to update all commands
- ✅ **Readability**: Commands show intent (`$PROJECT_ID`) rather than magic strings
- ✅ **Flexibility**: Easy to adapt commands for different environments (nonprod vs prod)
- ✅ **Error reduction**: Typos in project IDs or cluster names are common - variables prevent this
- ✅ **Documentation**: Clear declaration of all key values in one place

**Important notes**:
- These variables are **session-specific** - you must re-export them if you open a new terminal
- Consider adding these to `~/.bashrc` or `~/.zshrc` for permanent availability
- **GITHUB_ORG value**: Replace `portco-connect` with your actual GitHub organization name
- All subsequent sections in Phase 4.12 will use these variables in commands

---

**Section 1.1: ArgoCD Operational Status Verification**
- **Action**: Verify all prod ArgoCD pods are running and services are accessible
- **Note**: The cluster context switch command has been moved to Section 1.0 Environment Variables Setup above

- **Verify all ArgoCD pods running** (HA configuration: 14 pods total):
  - Command: `kubectl -n argocd get pods`
  - Expected output (all pods STATUS=Running):
    ```
    NAME                                            READY   STATUS    RESTARTS   AGE
    argocd-application-controller-0                 1/1     Running   0          <age>
    argocd-applicationset-controller-<hash>         1/1     Running   0          <age>
    argocd-dex-server-<hash>-1                      1/1     Running   0          <age>
    argocd-dex-server-<hash>-2                      1/1     Running   0          <age>
    argocd-notifications-controller-<hash>          1/1     Running   0          <age>
    argocd-redis-ha-haproxy-<hash>-1                1/1     Running   0          <age>
    argocd-redis-ha-haproxy-<hash>-2                1/1     Running   0          <age>
    argocd-redis-ha-haproxy-<hash>-3                1/1     Running   0          <age>
    argocd-redis-ha-server-0                        2/2     Running   0          <age>
    argocd-redis-ha-server-1                        2/2     Running   0          <age>
    argocd-redis-ha-server-2                        2/2     Running   0          <age>
    argocd-repo-server-<hash>-1                     1/1     Running   0          <age>
    argocd-repo-server-<hash>-2                     1/1     Running   0          <age>
    argocd-server-<hash>-1                          1/1     Running   0          <age>
    argocd-server-<hash>-2                          1/1     Running   0          <age>
    argocd-server-<hash>-3                          1/1     Running   0          <age>
    ```
  - Success criteria: All 14+ pods show STATUS=Running, READY matches expected count
  - Troubleshooting: If any pod is not Running, check logs with `kubectl -n argocd logs <pod-name>`

- **Pod count verification**:
  - Command: `kubectl -n argocd get pods --no-headers | wc -l`
  - Expected: 14 or more pods (HA configuration)
  - Critical pods breakdown:
    - 3 server pods (API/UI serving with load balancing)
    - 2 repo-server pods (repository operations with HA)
    - 1 controller pod (application reconciliation)
    - 2 dex pods (SSO/authentication with HA)
    - 1 applicationset controller (ApplicationSet management)
    - 1 notifications controller (event notifications)
    - 3 redis-ha-server pods (Redis Sentinel cluster)
    - 3 redis-ha-haproxy pods (Redis HA proxy layer)
  - Note: Additional pods may exist (backup jobs, completed jobs) - this is normal

- **Verify ArgoCD API server service**:
  - Command: `kubectl -n argocd get svc argocd-server`
  - Expected output:
    ```
    NAME            TYPE           CLUSTER-IP      EXTERNAL-IP     PORT(S)                      AGE
    argocd-server   LoadBalancer   10.x.x.x        <external-ip>   80:xxxxx/TCP,443:xxxxx/TCP   <age>
    ```
  - Success criteria: TYPE=LoadBalancer, EXTERNAL-IP assigned (not <pending>)
  - Note: External IP should match argocd-east4.pcconnect.ai DNS record

- **Verify ArgoCD UI accessibility**:
  - Command: `curl -k -s -o /dev/null -w "%{http_code}" https://argocd-east4.pcconnect.ai`
  - Expected output: `200` or `302` (redirect to login)
  - Alternative verification: Open `https://argocd-east4.pcconnect.ai` in browser
  - Success criteria: UI loads without connection errors
  - Troubleshooting: If connection fails, check Load Balancer status and DNS resolution

- **Verify repo-server pods specifically** (critical for GitHub integration):
  - Command: `kubectl -n argocd get pods -l app.kubernetes.io/name=argocd-repo-server`
  - Expected: 2 repo-server pods with STATUS=Running
  - Output example:
    ```
    NAME                                  READY   STATUS    RESTARTS   AGE
    argocd-repo-server-<hash>-1           1/1     Running   0          <age>
    argocd-repo-server-<hash>-2           1/1     Running   0          <age>
    ```
  - Note: These pods will handle GitHub repository operations - both must be healthy

**Section 1.2: Secret Manager Verification**
- **Action**: Verify GitHub App credentials exist in Secret Manager before attempting integration
- **List Secret Manager secrets in devops-prod project**:
  - Command: `gcloud secrets list --project=pcc-prj-devops-prod --filter="name:argocd-github-app-credentials"`
  - Expected output:
    ```
    NAME                            CREATED              REPLICATION_POLICY  LOCATIONS
    argocd-github-app-credentials   <creation-date>      automatic           -
    ```
  - Success criteria: Secret exists in project
  - Troubleshooting: If secret does not exist, it must be created before proceeding

- **Verify secret has active version**:
  - Command: `gcloud secrets versions list argocd-github-app-credentials --project=pcc-prj-devops-prod --limit=1`
  - Expected output:
    ```
    NAME  STATE    CREATED              DESTROYED
    1     enabled  <creation-date>      -
    ```
  - Success criteria: At least one version with STATE=enabled
  - Note: Version number may be higher than 1 if secret has been rotated

- **Verify secret structure** (without exposing values):
  - Command: `gcloud secrets versions access latest --secret=argocd-github-app-credentials --project=pcc-prj-devops-prod --format='get(payload.data)' | base64 -d | jq 'keys'`
  - Expected output:
    ```
    [
      "appId",
      "installationId",
      "privateKey"
    ]
    ```
  - Success criteria: JSON contains all three required keys
  - Troubleshooting: If keys are missing or malformed, secret must be recreated with correct structure

- **Verify Secret Manager IAM access** (who can access this secret):
  - Command: `gcloud secrets get-iam-policy argocd-github-app-credentials --project=pcc-prj-devops-prod`
  - Expected: IAM policy exists (may be empty if using default permissions)
  - Note: We'll verify Workload Identity access in Section 1.3

- **Verify audit logging for Secret Manager** (security compliance):
  - **Check audit log configuration**:
    ```bash
    # Verify data access audit logs are enabled for Secret Manager
    gcloud projects get-iam-policy pcc-prj-devops-prod \
      --flatten="auditConfigs[].auditLogConfigs[]" \
      --filter="auditConfigs.service:secretmanager.googleapis.com" \
      --format="table(auditConfigs.service, auditConfigs.auditLogConfigs.logType)"
    ```
  - Expected: Shows `DATA_READ` and/or `DATA_WRITE` log types enabled
  - **Why important**: Tracks who accessed GitHub App credentials (security incident response)
  - **If not configured**: Audit logging should be enabled project-wide for Secret Manager

  - **Verify recent audit logs exist** (confirms logging is working):
    ```bash
    # Query last 24h of Secret Manager access logs
    gcloud logging read \
      'resource.type="secretmanager.googleapis.com/Secret"
       AND resource.labels.secret_id="argocd-github-app-credentials"
       AND (protoPayload.methodName:"AccessSecretVersion" OR protoPayload.methodName:"GetSecret")' \
      --project=pcc-prj-devops-prod \
      --limit=5 \
      --format="table(timestamp, protoPayload.authenticationInfo.principalEmail, protoPayload.methodName, protoPayload.status.code)"
    ```
  - Expected output example:
    ```
    TIMESTAMP                      PRINCIPAL_EMAIL                                           METHOD_NAME                    STATUS_CODE
    2025-10-23T10:15:30.123Z      argocd-repo-server@pcc-prj-devops-prod.iam.gserviceaccount.com  AccessSecretVersion            0
    2025-10-23T09:45:12.456Z      user@pcconnect.ai                                         GetSecret                      0
    ```
  - **What to verify**:
    - Logs exist (audit logging is active)
    - ArgoCD service account (`argocd-repo-server@...`) appears in logs when accessing secrets
    - STATUS_CODE = 0 (success) or 7 (permission denied - indicates access attempts)
  - **If no logs found**: Either secret hasn't been accessed recently OR audit logging not enabled
  - **Security note**: Audit logs retained for 400 days (Admin Activity), 30 days (Data Access)

  - **Test audit log generation** (optional verification):
    ```bash
    # Trigger a secret access to generate audit log
    gcloud secrets versions access latest \
      --secret=argocd-github-app-credentials \
      --project=pcc-prj-devops-prod \
      --format='get(name)' > /dev/null

    # Wait 60 seconds for log propagation
    echo "Waiting 60 seconds for audit log propagation..."
    sleep 60

    # Check for new audit log entry
    gcloud logging read \
      'resource.type="secretmanager.googleapis.com/Secret"
       AND resource.labels.secret_id="argocd-github-app-credentials"
       AND protoPayload.methodName:"AccessSecretVersion"
       AND timestamp>="'$(date -u -d '2 minutes ago' +%Y-%m-%dT%H:%M:%SZ)'"' \
      --project=pcc-prj-devops-prod \
      --limit=1 \
      --format="value(timestamp)"
    ```
  - Expected: Shows timestamp from last ~2 minutes (log successfully generated)
  - **Why test**: Confirms audit logging pipeline is functional, not just configured

- **Audit log verification summary**:
  - ✅ Audit logging configured for Secret Manager
  - ✅ Recent access logs visible (confirms active logging)
  - ✅ ArgoCD service account access will be tracked
  - **Compliance note**: Audit logs provide evidence of credential access for SOC 2, ISO 27001, PCI-DSS

**Section 1.3: IAM Permissions Verification**
- **Action**: Verify ArgoCD repo-server has Workload Identity access to Secret Manager
- **Verify GCP service account exists**:
  - Command: `gcloud iam service-accounts describe argocd-repo-server@pcc-prj-devops-prod.iam.gserviceaccount.com --project=pcc-prj-devops-prod`
  - Expected output: Service account details with email, displayName, projectId
  - Success criteria: Service account exists without errors
  - Troubleshooting: If not found, service account must be created before proceeding

- **Verify Workload Identity binding** (KSA → GSA):
  - Command: `gcloud iam service-accounts get-iam-policy argocd-repo-server@pcc-prj-devops-prod.iam.gserviceaccount.com --project=pcc-prj-devops-prod --flatten="bindings[].members" --filter="bindings.role:roles/iam.workloadIdentityUser"`
  - Expected output: Shows binding with member format `serviceAccount:pcc-prj-devops-prod.svc.id.goog[argocd/argocd-repo-server]`
  - Success criteria: Workload Identity binding exists for argocd namespace repo-server SA
  - Troubleshooting: If binding missing, run:
    ```bash
    gcloud iam service-accounts add-iam-policy-binding argocd-repo-server@pcc-prj-devops-prod.iam.gserviceaccount.com \
      --project=pcc-prj-devops-prod \
      --role=roles/iam.workloadIdentityUser \
      --member="serviceAccount:pcc-prj-devops-prod.svc.id.goog[argocd/argocd-repo-server]"
    ```

- **Verify Secret Manager accessor role**:
  - Command: `gcloud projects get-iam-policy pcc-prj-devops-prod --flatten="bindings[].members" --filter="bindings.members:serviceAccount:argocd-repo-server@pcc-prj-devops-prod.iam.gserviceaccount.com AND bindings.role:roles/secretmanager.secretAccessor"`
  - Expected: Returns secretmanager.secretAccessor binding
  - Alternative: Check specific secret IAM policy:
    ```bash
    gcloud secrets get-iam-policy argocd-github-app-credentials --project=pcc-prj-devops-prod --flatten="bindings[].members" --filter="bindings.members:serviceAccount:argocd-repo-server@pcc-prj-devops-prod.iam.gserviceaccount.com"
    ```
  - Success criteria: Service account has secretAccessor role (project-level or secret-level)
  - Troubleshooting: If role missing, add with:
    ```bash
    gcloud secrets add-iam-policy-binding argocd-github-app-credentials \
      --project=pcc-prj-devops-prod \
      --role=roles/secretmanager.secretAccessor \
      --member="serviceAccount:argocd-repo-server@pcc-prj-devops-prod.iam.gserviceaccount.com"
    ```

- **Verify Kubernetes ServiceAccount annotation**:
  - Command: `kubectl -n argocd get serviceaccount argocd-repo-server -o yaml | grep "iam.gke.io/gcp-service-account"`
  - Expected output: `iam.gke.io/gcp-service-account: argocd-repo-server@pcc-prj-devops-prod.iam.gserviceaccount.com`
  - Success criteria: Annotation exists with correct GCP service account
  - Troubleshooting: If annotation missing, add with:
    ```bash
    kubectl annotate serviceaccount argocd-repo-server \
      --namespace argocd \
      iam.gke.io/gcp-service-account=argocd-repo-server@pcc-prj-devops-prod.iam.gserviceaccount.com
    ```
  - Note: This annotation enables Workload Identity for repo-server pods

**Section 1.4: ArgoCD CLI Authentication**
- **Action**: Verify ArgoCD CLI is authenticated to prod instance for repository management

- **Verify ArgoCD CLI version** (prerequisite check):
  - Command: `argocd version --short --client`
  - Expected output: `argocd: v2.12.0+<commit-sha>` (or later)
  - **Minimum required version**: v2.5.0+ (GitHub App authentication support)
  - **Recommended version**: v2.12.0+ (matches server version for compatibility)
  - **If version mismatch or outdated**:
    ```bash
    # Check current version
    argocd version --short --client

    # For macOS (Homebrew)
    brew upgrade argocd

    # For Linux (download latest binary)
    curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
    chmod +x /usr/local/bin/argocd

    # Verify installation
    argocd version --short --client
    ```
  - **Why version matters**:
    - v2.5.0+: Required for GitHub App repository authentication
    - v2.12.0+: Full compatibility with ArgoCD server v3.1.9
    - Older versions may fail with "unknown flag" or authentication errors
  - **Success criteria**: CLI version v2.12.0 or higher installed

- **Check existing authentication**:
  - Command: `argocd account get-user-info 2>&1`
  - Expected output (if authenticated): Shows username, issuer, groups
  - If not authenticated: Shows error message about authentication
  - Note: This determines if login step is needed

- **Get admin password** (if not already authenticated):
  - Command: `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo`
  - Expected: Returns admin password string (alphanumeric)
  - Alternative: Retrieve from Secret Manager if stored there
  - Security note: Password will be visible in terminal - use with caution
  - Note: If secret doesn't exist, admin password may have been changed - use existing credentials or reset

- **Login to ArgoCD prod instance**:
  - Command: `argocd login argocd-east4.pcconnect.ai --username admin --password '<password-from-previous-step>'`
  - Expected output: `'admin:login' logged in successfully`
  - Context saved: `Context 'argocd-east4.pcconnect.ai' updated`
  - Alternative (interactive): `argocd login argocd-east4.pcconnect.ai --username admin` (prompts for password)
  - Alternative (Google SSO): `argocd login argocd-east4.pcconnect.ai --sso` (if Google SSO configured)
  - Success criteria: Login completes without authentication errors

- **Verify ArgoCD CLI context**:
  - Command: `argocd context`
  - Expected output: Shows current context pointing to `argocd-east4.pcconnect.ai`
  - Output example:
    ```
    CURRENT  NAME                          SERVER
    *        argocd-east4.pcconnect.ai     argocd-east4.pcconnect.ai
    ```
  - Success criteria: Current context (marked with *) is prod instance

- **Test repository list access**:
  - Command: `argocd repo list`
  - Expected output: Lists currently configured repositories (may be empty initially)
  - Example (if no repos yet):
    ```
    REPOSITORY                          TYPE  NAME  PROJECT  STATUS  MESSAGE
    ```
  - Success criteria: Command executes without permission errors
  - Troubleshooting: If permission denied, verify admin credentials and re-login

- **Verify repo management permissions**:
  - Command: `argocd account can-i create repositories`
  - Expected output: `yes`
  - Success criteria: Admin account has repository creation permissions
  - Note: Required for adding GitHub repository in Module 2

**Pre-flight Checks Output**: Go/No-Go decision
- **GO**: All 4 sections passed → Proceed to Module 2
  - ✅ Section 1.1: 14 ArgoCD pods running, UI accessible, repo-server pods healthy
  - ✅ Section 1.2: Secret Manager secret exists with correct structure (appId, installationId, privateKey)
  - ✅ Section 1.3: Workload Identity configured (KSA annotated, GSA binding exists, Secret Manager access granted)
  - ✅ Section 1.4: ArgoCD CLI authenticated with repository management permissions
- **NO-GO**: Any section failed → Stop, fix issues, re-run pre-flight checks
  - ❌ Missing/unhealthy pods: Check Helm deployment and pod logs
  - ❌ Secret Manager issues: Create/fix secret before proceeding
  - ❌ IAM/Workload Identity issues: Apply missing bindings/annotations
  - ❌ CLI authentication issues: Verify admin credentials and network access

**Critical checkpoint**: DO NOT proceed to Module 2 if any pre-flight check failed. GitHub integration requires all prerequisites to be operational.

---

##### Module 2: GitHub Integration (8-12 min)

**Purpose**: Configure ArgoCD repository connection using GitHub App with Workload Identity

**Section 2.1: Kubernetes Secret Creation from Secret Manager**
- **Action**: Create Kubernetes secret with GitHub App credentials for ArgoCD repo-server

- **Pre-flight: Verify Secret Manager secret exists**:
  - Command:
    ```bash
    gcloud secrets describe argocd-github-app-credentials --project=pcc-prj-devops-prod || {
      echo "❌ ERROR: GitHub App credentials secret not found in Secret Manager"
      echo "Expected secret: argocd-github-app-credentials"
      echo "Project: pcc-prj-devops-prod"
      echo "Please verify Module 1.2 prerequisites were completed successfully"
      exit 1
    }
    ```
  - Expected: Secret metadata displayed (name, create time, replication, labels)
  - Note: This prevents silent failure if secret was deleted between Module 1 and Module 2

- **Extract credentials from Secret Manager** (with error handling):
  - Command:
    ```bash
    gcloud secrets versions access latest \
      --secret=argocd-github-app-credentials \
      --project=pcc-prj-devops-prod \
      --format='get(payload.data)' | base64 -d > /tmp/github-app-creds.json || {
      echo "❌ ERROR: Failed to retrieve GitHub App credentials from Secret Manager"
      echo "Possible causes:"
      echo "  - Secret 'argocd-github-app-credentials' does not exist"
      echo "  - Insufficient permissions to access Secret Manager"
      echo "  - Network connectivity issues"
      exit 1
    }

    # Validate JSON parsing succeeded
    jq empty /tmp/github-app-creds.json 2>/dev/null || {
      echo "❌ ERROR: Secret Manager credentials are not valid JSON"
      rm -f /tmp/github-app-creds.json
      exit 1
    }
    ```
  - Expected: Commands complete without errors
  - **Validate credential structure** (prevents silent auth failures):
    ```bash
    # Verify JSON is valid and contains required fields
    cat /tmp/github-app-creds.json | jq -e '.appId and .installationId and .privateKey' > /dev/null || {
      echo "❌ ERROR: Invalid GitHub App credentials structure in Secret Manager"
      echo "Expected JSON with fields: appId, installationId, privateKey"
      rm -f /tmp/github-app-creds.json
      exit 1
    }
    echo "✅ GitHub App credentials validated successfully"
    ```
  - Expected: `✅ GitHub App credentials validated successfully`
  - Note: Temporary file will be cleaned up after secret creation

- **⚠️ CRITICAL: Apply Workload Identity annotation FIRST** (before secret creation):
  - **Why first**: Annotation must be in place before repo-server pods attempt Secret Manager access to prevent race condition
  - Command:
    ```bash
    kubectl annotate serviceaccount argocd-repo-server \
      --namespace argocd \
      iam.gke.io/gcp-service-account=argocd-repo-server@pcc-prj-devops-prod.iam.gserviceaccount.com \
      --overwrite
    ```
  - Expected: `serviceaccount/argocd-repo-server annotated`
  - Note: This enables Workload Identity for Secret Manager access and GitHub App authentication

- **Create Kubernetes secret** (AFTER Workload Identity annotation):
  - Command structure (multi-line format):
    ```bash
    kubectl create secret generic argocd-repo-creds \
      --namespace argocd \
      --from-literal=githubAppID=$(cat /tmp/github-app-creds.json | jq -r '.appId') \
      --from-literal=githubAppInstallationID=$(cat /tmp/github-app-creds.json | jq -r '.installationId') \
      --from-literal=githubAppPrivateKey="$(cat /tmp/github-app-creds.json | jq -r '.privateKey')" \
      --dry-run=client -o yaml | kubectl apply -f -
    ```
  - Single-line executable format:
    `kubectl create secret generic argocd-repo-creds --namespace argocd --from-literal=githubAppID=$(cat /tmp/github-app-creds.json | jq -r '.appId') --from-literal=githubAppInstallationID=$(cat /tmp/github-app-creds.json | jq -r '.installationId') --from-literal=githubAppPrivateKey="$(cat /tmp/github-app-creds.json | jq -r '.privateKey')" --dry-run=client -o yaml | kubectl apply -f -`
  - Expected: `secret/argocd-repo-creds created` or `secret/argocd-repo-creds configured`

- **Verification** (secret and annotation):
  - Command: `kubectl -n argocd get secret argocd-repo-creds -o yaml`
  - Expected: Secret exists with data keys: githubAppID, githubAppInstallationID, githubAppPrivateKey (base64 encoded)
  - Verify annotation: `kubectl -n argocd get serviceaccount argocd-repo-server -o jsonpath='{.metadata.annotations.iam\.gke\.io/gcp-service-account}'`
  - Expected output: `argocd-repo-server@pcc-prj-devops-prod.iam.gserviceaccount.com`

- **Cleanup temporary file**:
  - Command: `rm /tmp/github-app-creds.json`
  - Note: Remove temporary credentials file for security

- **Success criteria**: Kubernetes secret created with 3 keys, Workload Identity annotation applied to argocd-repo-server SA

**Section 2.2: ArgoCD Repository Connection Configuration**
- **Action**: Add core/pcc-app-argo-config repository to ArgoCD using GitHub App authentication
- **Repository addition via ArgoCD CLI** (secure method - no key exposure):
  - **⚠️ SECURITY**: Use temporary file with restricted permissions to avoid exposing private key in command history/process list
  - Command structure (multi-line format):
    ```bash
    # Create temporary key file with restricted permissions (readable only by owner)
    kubectl -n argocd get secret argocd-repo-creds -o jsonpath='{.data.githubAppPrivateKey}' | base64 -d > /tmp/gh-app-key.pem
    chmod 600 /tmp/gh-app-key.pem

    # Add repository using file path (not stdin)
    argocd repo add https://github.com/ORG/pcc-app-argo-config.git \
      --github-app-id $(kubectl -n argocd get secret argocd-repo-creds -o jsonpath='{.data.githubAppID}' | base64 -d) \
      --github-app-installation-id $(kubectl -n argocd get secret argocd-repo-creds -o jsonpath='{.data.githubAppInstallationID}' | base64 -d) \
      --github-app-private-key-path /tmp/gh-app-key.pem \
      --name pcc-app-argo-config \
      --project default

    # Securely delete temporary key file (overwrite 3 times before deletion)
    shred -vfz -n 3 /tmp/gh-app-key.pem
    ```
  - Replace `ORG` with actual GitHub organization name
  - Expected output: `Repository 'https://github.com/ORG/pcc-app-argo-config.git' added`
  - **Security notes**:
    - `chmod 600` ensures only the current user can read the key file
    - `shred -n 3` overwrites the file 3 times before deletion (prevents recovery)
    - Never use `<<<` or command substitution for private keys (exposes in history/ps output)

- **Repository list verification**:
  - Command: `argocd repo list`
  - Expected output:
    ```
    REPOSITORY                                     TYPE  NAME                PROJECT  STATUS      MESSAGE
    https://github.com/ORG/pcc-app-argo-config.git git   pcc-app-argo-config  default  Successful  Repo is accessible
    ```
  - Note: If STATUS shows "Failed", check GitHub App credentials and IAM binding in Section 2.4 Troubleshooting

- **Repository connection test**:
  - Command: `argocd repo get https://github.com/ORG/pcc-app-argo-config.git`
  - Expected output fields:
    - Repository URL: https://github.com/ORG/pcc-app-argo-config.git
    - Type: git
    - Name: pcc-app-argo-config

- **Validate GitHub App permissions** (verify read-only access configured correctly):
  - **Test repository refresh** (forces fetch from GitHub):
    ```bash
    argocd repo get https://github.com/ORG/pcc-app-argo-config.git --refresh || {
      echo "❌ ERROR: Repository connection failed during refresh"
      echo "Verify GitHub App has access to repository and correct permissions"
      exit 1
    }
    ```
  - Expected: Connection succeeds, no authentication errors

  - **Verify manifest directory access** (confirms read access to actual content):
    ```bash
    kubectl -n argocd exec deployment/argocd-repo-server -- \
      git ls-remote https://github.com/ORG/pcc-app-argo-config.git HEAD || {
      echo "❌ ERROR: Cannot read repository HEAD - check GitHub App installation"
      exit 1
    }
    ```
  - Expected: Shows commit SHA for HEAD ref

  - **Validate read-only enforcement** (GitHub App should NOT have write access):
    - Manual verification required: Navigate to GitHub.com → Organization → Settings → GitHub Apps
    - Verify app permissions show "Contents: Read-only" (NOT "Read and write")
    - Confirm no "Administration" or "Push" permissions granted
    - **Security note**: Read-only access is CRITICAL - ArgoCD should never push to Git (Git is source of truth)

  - **Success criteria**: Repository accessible, manifests readable, read-only permissions confirmed
    - Project: default
    - Connection Status: Successful
    - Last Refresh: <timestamp>
  - Note: Detailed output confirms repository configuration details

- **ArgoCD UI verification** (optional):
  - Navigate to Settings → Repositories in ArgoCD UI (https://argocd-east4.pcconnect.ai)
  - Expected: pcc-app-argo-config repository shows green "Successful" connection status
  - Note: UI provides visual confirmation of repository integration

- **Success criteria**: Repository connected with STATUS=Successful, can fetch from GitHub

**Section 2.3: Repository Connection Validation**
- **Action**: Verify ArgoCD can fetch repository contents from both repo-server replicas (HA validation)
- **Test repository fetch via ArgoCD CLI**:
  - Command: `argocd repo get https://github.com/ORG/pcc-app-argo-config.git --refresh`
  - Expected: Command succeeds, shows "Connection Status: Successful"
  - Note: --refresh flag forces immediate fetch to verify connectivity

- **Check repo-server logs for authentication** (HA: verify both replicas):
  - Get repo-server pod names:
    - Command: `kubectl -n argocd get pods -l app.kubernetes.io/name=argocd-repo-server -o name`
    - Expected: Lists 2 pods (argocd-repo-server-<hash-1>, argocd-repo-server-<hash-2>)

  - Check logs for first replica:
    - Command: `kubectl -n argocd logs deployment/argocd-repo-server --tail=50 | grep pcc-app-argo-config`
    - Expected: No authentication errors, successful git fetch messages
    - Note: If seeing "authentication failed", proceed to Section 2.4 Troubleshooting

  - Verify both replicas can authenticate (HA validation):
    - Get pod names: `kubectl -n argocd get pods -l app.kubernetes.io/name=argocd-repo-server`
    - Check each pod: `kubectl -n argocd logs <pod-name> --tail=30 | grep -E "(github|authentication)"`
    - Expected: Both pods show successful GitHub App authentication
    - Success criteria: Both repo-server replicas can access repository

- **Test manifest discovery** (without creating application):
  - Command: `argocd app list` (should show no errors related to repository access)
  - Note: This validates ArgoCD can read repository metadata
  - Alternative: Use ArgoCD UI to browse repository in "New App" creation flow

- **Success criteria**: ArgoCD can successfully fetch from GitHub repository with no errors, both repo-server replicas validated

**Section 2.4: Troubleshooting**
- **Action**: Debug common GitHub integration issues

**Troubleshooting Scenario 1: Authentication Failed**
- **Symptoms**: `argocd repo list` shows STATUS=Failed with "authentication failed" message
- **Diagnosis steps**:
  1. Verify Secret Manager access:
     - Command: `kubectl -n argocd get serviceaccount argocd-repo-server -o yaml | grep iam.gke.io/gcp-service-account`
     - Expected: Shows `argocd-repo-server@pcc-prj-devops-prod.iam.gserviceaccount.com`
  2. Check Workload Identity binding:
     - Command: `gcloud iam service-accounts get-iam-policy argocd-repo-server@pcc-prj-devops-prod.iam.gserviceaccount.com --project=pcc-prj-devops-prod`
     - Expected: Shows workloadIdentityUser role for argocd namespace
  3. Verify secret content:
     - Command: `kubectl -n argocd get secret argocd-repo-creds -o jsonpath='{.data}' | jq`
     - Expected: Shows 3 keys (github-app-id, github-app-installation-id, github-app-private-key)
- **Resolution**: Re-run Section 2.1 to recreate Kubernetes secret and annotation

**Troubleshooting Scenario 2: Connection Timeout**
- **Symptoms**: Repository addition times out or shows "connection refused"
- **Diagnosis steps**:
  1. **Test DNS resolution from repo-server pod**:
     ```bash
     kubectl -n argocd exec deployment/argocd-repo-server -- nslookup github.com
     ```
     - Expected: Resolves to GitHub IP addresses (e.g., 140.82.112.3)
     - If DNS fails: Check CoreDNS pods in kube-system namespace, verify DNS policy

  2. **Test network connectivity to GitHub**:
     ```bash
     kubectl -n argocd exec deployment/argocd-repo-server -- curl -I https://github.com
     ```
     - Expected: HTTP 200 or 301 response
     - Alternative test: `curl -I https://api.github.com` (should return 200)
     - If connection fails: Proceed to network configuration checks below

  3. **Identify cluster network type** (public vs private):
     ```bash
     # Check if cluster has public endpoints
     gcloud container clusters describe pcc-gke-devops-prod \
       --region=us-east4 \
       --project=pcc-prj-devops-prod \
       --format="value(privateClusterConfig.enablePrivateNodes)"
     ```
     - Output `True`: Private cluster (requires Cloud NAT for egress)
     - Output `False` or empty: Public cluster (direct internet access)
     - **Note**: This determines which network troubleshooting path to follow

  4a. **For PRIVATE clusters: Check Cloud NAT configuration**:
     ```bash
     # First, list all Cloud Routers in the region
     gcloud compute routers list --filter="region:us-east4" --project=pcc-prj-devops-prod --format="table(name,region,network)"
     ```
     - Expected: Shows routers (may have different names than assumed)
     - Common router names: `pcc-nat-devops-prod`, `devops-prod-router`, `gke-router`, etc.
     - **Note down actual router name** for next command

     ```bash
     # Check NAT configuration on discovered router
     ROUTER_NAME="<router-name-from-above>"  # Replace with actual name
     gcloud compute routers nats list \
       --router=$ROUTER_NAME \
       --region=us-east4 \
       --project=pcc-prj-devops-prod
     ```
     - Expected: NAT configuration exists with `sourceSubnetworkIpRangesToNat: ALL_SUBNETWORKS_ALL_IP_RANGES`
     - **If no NAT found**: Private cluster cannot reach GitHub (requires NAT setup)
     - **If NAT exists**: Check NAT is assigned to correct VPC network

     ```bash
     # Verify NAT includes GKE cluster's VPC
     gcloud compute routers describe $ROUTER_NAME \
       --region=us-east4 \
       --project=pcc-prj-devops-prod \
       --format="value(network)"
     ```
     - Expected: Shows VPC network name (e.g., `pcc-vpc-devops-prod`)
     - Verify this matches GKE cluster VPC:
       ```bash
       gcloud container clusters describe pcc-gke-devops-prod \
         --region=us-east4 \
         --project=pcc-prj-devops-prod \
         --format="value(network)"
       ```
     - **Match required**: NAT router must be on same VPC as GKE cluster

  4b. **For PUBLIC clusters: Check firewall rules** (if private check not applicable):
     ```bash
     # List egress-allow firewall rules
     gcloud compute firewall-rules list \
       --filter="direction:EGRESS AND allowed.IPProtocol:tcp AND allowed.ports:443" \
       --project=pcc-prj-devops-prod \
       --format="table(name,network,direction,allowed[].ports,destinationRanges[])"
     ```
     - Expected: Rule allowing TCP 443 egress to 0.0.0.0/0 (or specific GitHub IP ranges)
     - **If no egress rule**: Firewall blocking HTTPS traffic to GitHub

  5. **Test egress from cluster with specific protocol checks**:
     ```bash
     # Test HTTPS handshake specifically
     kubectl -n argocd exec deployment/argocd-repo-server -- \
       openssl s_client -connect github.com:443 -servername github.com </dev/null 2>&1 | grep "Verify return code"
     ```
     - Expected: `Verify return code: 0 (ok)` (SSL handshake successful)
     - If fails: TLS/SSL issue, possible MITM proxy or firewall interference

  6. **Verify GKE cluster Pod IP range has internet access**:
     ```bash
     # Get Pod CIDR range
     POD_CIDR=$(gcloud container clusters describe pcc-gke-devops-prod \
       --region=us-east4 \
       --project=pcc-prj-devops-prod \
       --format="value(clusterIpv4Cidr)")

     echo "Pod CIDR: $POD_CIDR"

     # For private clusters, verify NAT covers this range
     gcloud compute routers nats describe <nat-name> \
       --router=<router-name> \
       --region=us-east4 \
       --project=pcc-prj-devops-prod \
       --format="value(sourceSubnetworkIpRangesToNat)"
     ```
     - Expected: `ALL_SUBNETWORKS_ALL_IP_RANGES` (NAT covers all pod IPs)
     - Alternative: `LIST_OF_SUBNETWORKS` with cluster subnet listed

- **Resolution paths**:
  - **Private cluster + no NAT**: Create Cloud NAT on router for GKE VPC
  - **Private cluster + NAT on wrong VPC**: Move NAT to correct VPC or create new router
  - **Public cluster + firewall blocking**: Add egress allow rule for TCP 443
  - **DNS failures**: Check CoreDNS config, verify Cloud DNS has proper forwarding rules
  - **SSL/TLS errors**: Investigate proxy/firewall, check for corporate MITM certificates

**Troubleshooting Scenario 3: Manifest Parse Errors**
- **Symptoms**: Repository connects but ArgoCD shows "failed to parse manifests"
- **Diagnosis steps**:
  1. Validate YAML syntax locally:
     - Clone repository: `git clone https://github.com/ORG/pcc-app-argo-config.git /tmp/test-repo`
     - Test YAML parsing: `kubectl apply --dry-run=client -f /tmp/test-repo/applications/prod/ -R`
     - Expected: No syntax errors
  2. Check ArgoCD logs for specific errors:
     - Command: `kubectl -n argocd logs deployment/argocd-repo-server --tail=100`
     - Look for: YAML parsing errors, missing files, invalid Kubernetes resource definitions
- **Resolution**: Fix YAML syntax errors in repository, ensure manifests are valid Kubernetes resources

**Section 2.5: Rollback Procedure**
- **Action**: Remove repository connection and credentials if integration fails
- **Remove repository from ArgoCD**:
  - Command: `argocd repo rm https://github.com/ORG/pcc-app-argo-config.git`
  - Expected: `Repository 'https://github.com/ORG/pcc-app-argo-config.git' removed`

- **Delete Kubernetes secret**:
  - Command: `kubectl delete secret argocd-repo-creds -n argocd`
  - Expected: `secret "argocd-repo-creds" deleted`

- **Remove Workload Identity annotation** (optional, if needed):
  - Command: `kubectl annotate serviceaccount argocd-repo-server -n argocd iam.gke.io/gcp-service-account-`
  - Note: Trailing `-` removes the annotation
  - Expected: `serviceaccount/argocd-repo-server annotated`

- **Verify cleanup** (comprehensive validation):
  - **Step 1: Verify repository removal**:
    ```bash
    argocd repo list | grep pcc-app-argo-config && {
      echo "❌ ERROR: Repository still present in ArgoCD"
      exit 1
    } || echo "✅ Repository successfully removed from ArgoCD"
    ```
  - Expected: No output from grep (repository not found), success message printed

  - **Step 2: Verify secret deletion**:
    ```bash
    kubectl -n argocd get secret argocd-repo-creds 2>&1 | grep -q "NotFound" || {
      echo "❌ ERROR: Secret argocd-repo-creds still exists"
      kubectl -n argocd get secret argocd-repo-creds
      exit 1
    }
    echo "✅ Secret argocd-repo-creds successfully deleted"
    ```
  - Expected: NotFound error (secret deleted), success message printed

  - **Step 3: Verify Workload Identity annotation removed** (if annotation was removed):
    ```bash
    WI_ANNOTATION=$(kubectl -n argocd get serviceaccount argocd-repo-server -o jsonpath='{.metadata.annotations.iam\.gke\.io/gcp-service-account}' 2>/dev/null)
    if [ -n "$WI_ANNOTATION" ]; then
      echo "⚠️  WARNING: Workload Identity annotation still present: $WI_ANNOTATION"
      echo "If you removed the annotation in rollback, this indicates removal failed"
    else
      echo "✅ Workload Identity annotation successfully removed (or was not present)"
    fi
    ```
  - Expected: Empty annotation or warning if still present
  - Note: Annotation removal is optional (step says "optional, if needed")

  - **Step 4: Verify no applications reference deleted repository**:
    ```bash
    APPS_USING_REPO=$(argocd app list -o json | jq -r '.[] | select(.spec.source.repoURL == "https://github.com/ORG/pcc-app-argo-config.git") | .metadata.name' 2>/dev/null)
    if [ -n "$APPS_USING_REPO" ]; then
      echo "❌ ERROR: Applications still reference deleted repository:"
      echo "$APPS_USING_REPO"
      echo "These applications must be deleted or updated before removing repository"
      exit 1
    else
      echo "✅ No applications reference deleted repository"
    fi
    ```
  - Expected: No applications found (safe to remove repo)
  - **Critical**: Applications must be deleted BEFORE repository removal to prevent orphaned apps

  - **Step 5: Verify repo-server pods cleared credentials**:
    ```bash
    echo "Waiting 30 seconds for repo-server pods to clear cached credentials..."
    sleep 30

    # Check repo-server logs for any errors related to deleted repository
    kubectl -n argocd logs -l app.kubernetes.io/name=argocd-repo-server --tail=50 --since=1m 2>&1 | \
      grep -i "pcc-app-argo-config\|authentication.*failed\|credential.*error" && {
      echo "⚠️  WARNING: Recent errors in repo-server logs related to repository or credentials"
      echo "This may indicate cached state or active connections still present"
    } || echo "✅ No recent repository-related errors in repo-server logs"
    ```
  - Expected: No errors in recent logs (credentials cleared)
  - Note: 30-second delay allows ArgoCD to update internal state

  - **Step 6: Verify ArgoCD controller has no repository errors**:
    ```bash
    kubectl -n argocd logs -l app.kubernetes.io/name=argocd-application-controller --tail=50 --since=1m 2>&1 | \
      grep -i "pcc-app-argo-config\|repository.*not.*found\|failed.*to.*get.*repo" && {
      echo "⚠️  WARNING: Controller logs show repository-related errors"
      echo "This may indicate applications still referencing deleted repository"
    } || echo "✅ No repository-related errors in controller logs"
    ```
  - Expected: No repository errors (clean state)

  - **Step 7: Validate ArgoCD API server health**:
    ```bash
    kubectl -n argocd exec deployment/argocd-server -- argocd version --short --grpc-web || {
      echo "❌ ERROR: ArgoCD API server not responding after rollback"
      echo "Check argocd-server pod status and logs"
      exit 1
    }
    echo "✅ ArgoCD API server responding correctly"
    ```
  - Expected: ArgoCD version displayed (API healthy)

  - **Step 8: Full state verification**:
    ```bash
    echo ""
    echo "=== ROLLBACK VALIDATION SUMMARY ==="
    echo "Repository count: $(argocd repo list 2>/dev/null | grep -c 'http' || echo 0)"
    echo "Application count: $(argocd app list 2>/dev/null | grep -c 'NAME' || echo 0)"
    echo "ArgoCD pods running: $(kubectl -n argocd get pods 2>/dev/null | grep -c 'Running' || echo 0)/14"
    echo ""
    echo "If all checks passed above, rollback is complete and ArgoCD is in clean state"
    echo "Safe to re-attempt GitHub integration or proceed with different repository"
    ```
  - Expected: Summary shows clean state (0-1 repos, apps as expected, 14 pods running)

  - **Success criteria**: All 8 validation steps pass with no errors or warnings

**Module 2 Output**: GitHub Integration Complete
- **Deliverable**: ArgoCD connected to core/pcc-app-argo-config repository via GitHub App with Workload Identity
- **Verification**: `argocd repo list` shows STATUS=Successful, both repo-server replicas validated
- **Next step**: Proceed to Module 3 (Validation & Documentation)

---

##### Module 3: Validation & Documentation (7-10 min)

**Purpose**: Comprehensive validation of GitHub integration with HA-specific checks and documentation creation

**Section 3.1: Repository Access Verification**
- **Action**: Verify ArgoCD can reliably access repository with detailed connection testing
- **Test repository fetch with refresh**:
  - Command: `argocd repo get https://github.com/ORG/pcc-app-argo-config.git --refresh`
  - Expected: Shows "Connection Status: Successful" and recent "Last Refresh" timestamp
  - Note: Refresh triggers immediate git fetch to validate current connectivity

- **Get detailed repository information**:
  - Command: `argocd repo get https://github.com/ORG/pcc-app-argo-config.git --output yaml`
  - Expected output fields to verify:
    - `repo: https://github.com/ORG/pcc-app-argo-config.git`
    - `type: git`
    - `name: pcc-app-argo-config`
    - `project: default`
    - `connectionState.status: Successful`
    - `connectionState.message: "Repo is accessible"`
  - Note: YAML output provides complete connection state details

- **Verify connection status fields**:
  - Command: `argocd repo get https://github.com/ORG/pcc-app-argo-config.git --output json | jq '.connectionState'`
  - Expected JSON structure:
    ```json
    {
      "status": "Successful",
      "message": "Repo is accessible",
      "attemptedAt": "<timestamp>"
    }
    ```
  - Success criteria: status=Successful, no error messages

**Section 3.2: HA-Specific Validation**
- **Action**: Verify GitHub integration works across all ArgoCD HA components (prod-specific)
- **Verify all 14 ArgoCD pods still running** (post-integration check):
  - Command: `kubectl -n argocd get pods | grep -E "(Running|Ready)"`
  - Expected: All 14 pods still STATUS=Running (3 server, 2 repo-server, 1 controller, 2 dex, 1 applicationset, 1 notifications, 3 redis-ha-server, 3 redis-ha-haproxy)
  - Note: Integration should not disrupt any running pods
  - Success criteria: Pod count unchanged from Module 1, all Running

- **Test repository connection from both repo-server replicas**:
  - Get both repo-server pod names:
    - Command: `kubectl -n argocd get pods -l app.kubernetes.io/name=argocd-repo-server -o jsonpath='{.items[*].metadata.name}'`
    - Expected: Lists 2 pod names separated by space

  - Test first replica:
    - Command: `kubectl -n argocd exec <pod-name-1> -- git ls-remote https://github.com/ORG/pcc-app-argo-config.git HEAD`
    - Expected: Returns commit SHA for HEAD reference
    - Note: This validates GitHub App authentication works from pod 1

  - Test second replica:
    - Command: `kubectl -n argocd exec <pod-name-2> -- git ls-remote https://github.com/ORG/pcc-app-argo-config.git HEAD`
    - Expected: Returns same commit SHA for HEAD reference
    - Note: This validates GitHub App authentication works from pod 2

  - Success criteria: Both repo-server replicas can authenticate to GitHub and fetch repository metadata
  - **⚠️ LIMITATION**: `git ls-remote` tests git-level access only, not ArgoCD's internal credential handling
  - **Next step**: Use ArgoCD-specific validation below to test actual ArgoCD authentication chain

- **Test ArgoCD's internal credential handling** (beyond git CLI):
  - **Force ArgoCD repository refresh** (validates ArgoCD's own authentication, not just git):
    ```bash
    argocd repo get https://github.com/ORG/pcc-app-argo-config.git --refresh || {
      echo "❌ ERROR: ArgoCD repository refresh failed"
      echo "This tests ArgoCD's internal credential handling, not just git CLI"
      echo "Possible causes:"
      echo "  - GitHub App credentials malformed in K8s secret"
      echo "  - Workload Identity annotation missing or incorrect"
      echo "  - ArgoCD version incompatible with GitHub App auth"
      exit 1
    }
    ```
  - Expected: Repository refreshes successfully, shows connection status
  - **Why this matters**: Git CLI commands can succeed even when ArgoCD's internal auth fails due to:
    - Different credential precedence order
    - Pod service account fallback behavior
    - Cache vs fresh authentication differences

- **Verify ArgoCD can list repository manifests** (requires authenticated read access):
  - Command: `argocd repo list | grep pcc-app-argo-config`
  - Expected: Shows repository with CONNECTION_STATUS column indicating success
  - Note: This confirms ArgoCD's repository configuration is correct

- **Test manifest path access** (validates ArgoCD can read application directories):
  - **For applications/prod/ directory**:
    ```bash
    # This forces ArgoCD to authenticate and read directory structure
    kubectl -n argocd exec deployment/argocd-repo-server -- \
      sh -c 'cd /tmp && git clone --depth 1 --no-checkout https://github.com/ORG/pcc-app-argo-config.git test-clone && \
             cd test-clone && git sparse-checkout init --cone && \
             git sparse-checkout set applications/prod && git checkout' || {
      echo "❌ ERROR: Cannot clone repository with ArgoCD repo-server credentials"
      echo "This tests actual ArgoCD pod authentication (not external git client)"
      exit 1
    }
    ```
  - Expected: Sparse checkout succeeds, applications/prod directory accessible
  - **Why sparse checkout**: Tests ArgoCD's ability to selectively read manifest directories (what ArgoCD does during sync)
  - **Cleanup**: Pod is ephemeral, /tmp content cleared automatically

- **Validate across HA replicas** (ensure both repo-server pods can authenticate):
  - **Test first replica**:
    ```bash
    REPO_POD_1=$(kubectl -n argocd get pods -l app.kubernetes.io/name=argocd-repo-server -o jsonpath='{.items[0].metadata.name}')
    kubectl -n argocd exec $REPO_POD_1 -- \
      argocd repo get https://github.com/ORG/pcc-app-argo-config.git --grpc-web || {
      echo "❌ ERROR: Replica 1 ($REPO_POD_1) cannot authenticate via ArgoCD"
      exit 1
    }
    ```
  - **Test second replica**:
    ```bash
    REPO_POD_2=$(kubectl -n argocd get pods -l app.kubernetes.io/name=argocd-repo-server -o jsonpath='{.items[1].metadata.name}')
    kubectl -n argocd exec $REPO_POD_2 -- \
      argocd repo get https://github.com/ORG/pcc-app-argo-config.git --grpc-web || {
      echo "❌ ERROR: Replica 2 ($REPO_POD_2) cannot authenticate via ArgoCD"
      exit 1
    }
    ```
  - Expected: Both replicas successfully authenticate and retrieve repository info via ArgoCD's gRPC API
  - **Why --grpc-web**: Tests ArgoCD's internal API calls (same path used by ArgoCD server for repo operations)
  - Success criteria: Both repo-server pods can authenticate using ArgoCD's credential handling (not just git)

- **Check leader election status** (ArgoCD controller):
  - Command: `kubectl -n argocd get configmap argocd-controller-leader -o jsonpath='{.metadata.annotations}' | jq`
  - Expected: Shows controller leader election metadata
  - Note: Validates controller HA is functional post-integration

- **Verify Redis HA cluster health**:
  - Command: `kubectl -n argocd exec argocd-redis-ha-server-0 -- redis-cli -a $(kubectl -n argocd get secret argocd-redis -o jsonpath='{.data.auth}' | base64 -d) info replication`
  - Expected: Shows master/replica status for Redis HA cluster
  - Note: Repository integration should not impact Redis HA stability

**Section 3.3: Integration Testing**
- **Action**: Test ArgoCD can discover and parse manifests from repository
- **Test manifest discovery without creating application**:
  - Use ArgoCD UI to browse repository:
    - Navigate to Applications → New App
    - Repository: Select pcc-app-argo-config from dropdown
    - Path: Browse to `applications/prod/` directory
    - Expected: ArgoCD shows directory contents, can navigate repository structure
  - Note: This validates ArgoCD can list repository files without deployment

- **Test Helm values parsing for prod** (if using Helm):
  - Command: `argocd repo get https://github.com/ORG/pcc-app-argo-config.git`
  - Check for Helm capabilities in output
  - Expected: ArgoCD recognizes Helm charts if present in repository
  - Note: Validates Helm integration if repository contains charts

- **Verify ArgoCD can read from applications/prod/ directory**:
  - Via ArgoCD UI:
    - Settings → Repositories → pcc-app-argo-config → Details
    - Click "Verify connection" button
    - Expected: Shows "Connection Status: Successful"
  - Via CLI:
    - Command: `argocd repo get https://github.com/ORG/pcc-app-argo-config.git --refresh`
    - Expected: No errors, successful fetch

- **Success criteria**: Manifest discovery works, Helm parsing functional (if applicable), prod directory accessible

**Section 3.4: Documentation Creation**
- **Action**: Create comprehensive documentation for prod GitHub integration
- **Create documentation file**:
  - File path: `/home/jfogarty/pcc/.claude/docs/argocd-prod-github-integration.md`
  - Content structure (see template below)

- **Documentation template**:
  ```markdown
  # ArgoCD Production GitHub Integration

  ## Overview
  - **Environment**: Production (pcc-prj-devops-prod)
  - **ArgoCD Instance**: https://argocd-east4.pcconnect.ai
  - **Repository**: https://github.com/ORG/pcc-app-argo-config.git
  - **Authentication**: GitHub App with Workload Identity
  - **Configured**: <date>

  ## Repository Connection Details
  - **Repository URL**: https://github.com/ORG/pcc-app-argo-config.git
  - **Repository Name**: pcc-app-argo-config
  - **ArgoCD Project**: default
  - **Access Level**: Read-only
  - **Authentication Method**: GitHub App with Workload Identity (NO SSH keys or tokens)

  ## Kubernetes Secret Configuration
  - **Secret Name**: argocd-repo-creds
  - **Namespace**: argocd
  - **Secret Keys**:
    - `github-app-id`: GitHub App ID
    - `github-app-installation-id`: GitHub App Installation ID
    - `github-app-private-key`: GitHub App Private Key (PEM format)
  - **Source**: Secret Manager (`argocd-github-app-credentials` in pcc-prj-devops-prod)

  ## Workload Identity Setup
  - **Kubernetes ServiceAccount**: argocd-repo-server (argocd namespace)
  - **GCP Service Account**: argocd-repo-server@pcc-prj-devops-prod.iam.gserviceaccount.com
  - **Workload Identity Annotation**: `iam.gke.io/gcp-service-account=argocd-repo-server@pcc-prj-devops-prod.iam.gserviceaccount.com`
  - **IAM Bindings**:
    - `roles/iam.workloadIdentityUser`: Allows K8s SA to impersonate GCP SA
    - `roles/secretmanager.secretAccessor`: Allows access to GitHub App credentials in Secret Manager

  ## Validation Procedures
  ### Verify Repository Connection
  ```bash
  # Test repository access via ArgoCD CLI
  argocd repo get https://github.com/ORG/pcc-app-argo-config.git --refresh

  # Check repository list
  argocd repo list

  # Expected: STATUS=Successful
  ```

  ### Verify Kubernetes Secret
  ```bash
  # Check secret exists
  kubectl -n argocd get secret argocd-repo-creds

  # Verify secret keys (should show 3 keys)
  kubectl -n argocd get secret argocd-repo-creds -o jsonpath='{.data}' | jq 'keys'
  ```

  ### Verify Workload Identity
  ```bash
  # Check ServiceAccount annotation
  kubectl -n argocd get serviceaccount argocd-repo-server -o jsonpath='{.metadata.annotations.iam\.gke\.io/gcp-service-account}'

  # Expected: argocd-repo-server@pcc-prj-devops-prod.iam.gserviceaccount.com
  ```

  ## HA Validation (Production-Specific)
  ### Verify Both Repo-Server Replicas
  ```bash
  # Get both repo-server pod names
  kubectl -n argocd get pods -l app.kubernetes.io/name=argocd-repo-server

  # Test git access from each pod
  kubectl -n argocd exec <pod-name-1> -- git ls-remote https://github.com/ORG/pcc-app-argo-config.git HEAD
  kubectl -n argocd exec <pod-name-2> -- git ls-remote https://github.com/ORG/pcc-app-argo-config.git HEAD

  # Expected: Both pods return same commit SHA
  ```

  ### Verify All 14 ArgoCD Pods Running
  ```bash
  kubectl -n argocd get pods

  # Expected: 3 server, 2 repo-server, 1 controller, 2 dex, 1 applicationset, 1 notifications, 3 redis-ha-server, 3 redis-ha-haproxy
  ```

  ## Maintenance Procedures
  ### Credential Rotation
  1. Update GitHub App credentials in Secret Manager (`argocd-github-app-credentials`)
  2. Delete existing Kubernetes secret: `kubectl delete secret argocd-repo-creds -n argocd`
  3. Recreate secret from Secret Manager (follow Section 2.1 from Phase 4.12)
  4. Verify connection: `argocd repo get https://github.com/ORG/pcc-app-argo-config.git --refresh`

  ### Repository Connection Verification (Routine)
  Run weekly or after any ArgoCD upgrades:
  ```bash
  # Verify repository connection
  argocd repo list

  # Test fetch
  argocd repo get https://github.com/ORG/pcc-app-argo-config.git --refresh

  # Check repo-server logs for errors
  kubectl -n argocd logs deployment/argocd-repo-server --tail=50 | grep -E "(error|failed)"
  ```

  ## Troubleshooting
  ### Authentication Failures
  - Verify Workload Identity annotation: `kubectl -n argocd get sa argocd-repo-server -o yaml | grep iam.gke.io`
  - Check IAM bindings: `gcloud iam service-accounts get-iam-policy argocd-repo-server@pcc-prj-devops-prod.iam.gserviceaccount.com --project=pcc-prj-devops-prod`
  - Verify secret content: `kubectl -n argocd get secret argocd-repo-creds -o yaml`

  ### Connection Timeouts
  - Test network connectivity: `kubectl -n argocd exec deployment/argocd-repo-server -- curl -I https://github.com`
  - Check Cloud NAT: `gcloud compute routers nats list --router=pcc-nat-devops-prod --region=us-east4`
  - Verify DNS resolution: `kubectl -n argocd exec deployment/argocd-repo-server -- nslookup github.com`

  ## References
  - Phase 4.12 Documentation: `.claude/plans/devtest-deployment/phase-4-working-notes.md`
  - Phase 4.3 Architectural Decisions: GitHub App with Workload Identity
  - ArgoCD Version: v3.1.9
  - GitHub App Documentation: <GitHub App URL>
  ```

- **Commit documentation file to git**:
  - Command: `git add .claude/docs/argocd-prod-github-integration.md`
  - Command: `git commit -m "docs: add ArgoCD prod GitHub integration documentation"`
  - Expected: Documentation file committed to repository
  - Note: Push to remote if required by workflow

- **Success criteria**: Documentation file created with comprehensive integration details, committed to git

**Module 3 Output**: Validation & Documentation Complete
- **Deliverable**: Repository access validated, HA components verified, comprehensive documentation created
- **Verification**: All validation checks passed, documentation file committed
- **Phase 4.12 Complete**: GitHub integration fully operational in prod environment

---

**Section 3.5: Monitoring & Alerting Setup Documentation**

**⚠️ IMPORTANT**: This section documents recommended monitoring and alerting for ArgoCD production. Implementation is outside Phase 4 scope but documented here for operations team reference.

**Purpose**: Establish observability and proactive alerting for ArgoCD production environment

**Monitoring Strategy**:
- **Platform**: Google Cloud Monitoring (native GKE integration)
- **Dashboards**: Pre-built ArgoCD dashboards + custom GKE metrics
- **Alerts**: Critical path failures, degraded sync performance, authentication issues
- **Log aggregation**: Cloud Logging with structured query filters

**Key Metrics to Monitor**:

1. **Application Sync Health** (CRITICAL):
   - Metric: `argocd_app_sync_total` (counter by status: success/failed)
   - Query: Prometheus/Cloud Monitoring
   - Threshold alert: `sync_failed > 0 for 5min` → Slack #platform-alerts
   - Why: Failed syncs indicate deployment pipeline breakage

2. **Repository Connection Status** (HIGH):
   - Metric: `argocd_app_info{repo_url="https://github.com/ORG/pcc-app-argo-config.git"}`
   - Check: Connection state = 1 (healthy), 0 (failed)
   - Threshold alert: `connection_state == 0 for 3min` → PagerDuty
   - Why: Repository connection loss blocks all deployments

3. **Redis HA Cluster Health** (HIGH):
   - Metrics: `redis_up`, `redis_master_link_status`
   - Query: Via redis-exporter sidecar (if deployed)
   - Threshold alert: `redis_up < 3 for 5min` OR `master_link_down for 2min`
   - Why: Redis failure causes ArgoCD state loss, session disruption

4. **Pod Availability** (MEDIUM):
   - Metric: `kube_deployment_status_replicas_available{namespace="argocd"}`
   - Target: server ≥ 2, repo-server ≥ 1, controller ≥ 1
   - Threshold alert: `available < desired for 10min` → Slack
   - Why: Reduced replicas indicate scheduling/resource issues

5. **API Server Response Time** (MEDIUM):
   - Metric: `argocd_api_server_request_duration_seconds`
   - Threshold: p95 < 500ms (normal), p95 > 2s (degraded)
   - Threshold alert: `p95 > 2s for 15min` → Slack
   - Why: Slow API affects developer experience, UI performance

6. **Sync Duration** (MEDIUM):
   - Metric: `argocd_app_sync_duration_seconds`
   - Threshold: p95 < 60s (normal), p95 > 300s (slow)
   - Alert: `p95 > 300s for 30min` → Investigate repo size, network
   - Why: Slow syncs indicate Git/network/manifest complexity issues

7. **Authentication Failures** (LOW):
   - Log-based metric: `protoPayload.status.code=7` (permission denied)
   - Filter: `resource.labels.namespace_name="argocd"`
   - Threshold: `> 10 failures in 5min` → Security team notification
   - Why: Spike indicates brute force or misconfigured access

**Recommended Dashboards**:

1. **ArgoCD Overview Dashboard** (create in Cloud Monitoring):
   ```
   - Application Sync Status (pie chart: Synced/OutOfSync/Unknown)
   - Repository Connection Health (status panel)
   - Sync Frequency (line graph, last 24h)
   - Failed Syncs (table with app name, error message, timestamp)
   - Pod Status by Component (heatmap: server/repo-server/controller/redis)
   ```

2. **ArgoCD Performance Dashboard**:
   ```
   - API Request Latency (p50, p95, p99 percentiles)
   - Sync Duration Trends (histogram, grouped by app)
   - Redis Memory Usage (line graph)
   - Reconciliation Loop Duration (repo-server, controller)
   - Network I/O (GitHub API calls, Git fetch operations)
   ```

3. **ArgoCD Security Dashboard**:
   ```
   - Authentication Events (success/failure timeline)
   - RBAC Denials (grouped by user/service account)
   - Secret Manager Access Audit (argocd-repo-server access logs)
   - GitHub App Token Expirations (manual tracking, no auto-metric)
   - SSL Certificate Expiry (argocd-east4.pcconnect.ai cert)
   ```

**Alert Configuration Examples**:

```yaml
# Example Cloud Monitoring Alert Policy (YAML format)
# Deploy via Terraform or gcloud CLI

alertPolicy:
  displayName: "ArgoCD - Critical Sync Failures"
  conditions:
    - displayName: "Sync failures detected"
      conditionThreshold:
        filter: |
          resource.type="k8s_pod"
          AND resource.labels.namespace_name="argocd"
          AND metric.type="logging.googleapis.com/user/argocd_sync_failed"
        comparison: COMPARISON_GT
        thresholdValue: 0
        duration: 300s  # 5 minutes
        aggregations:
          - alignmentPeriod: 60s
            perSeriesAligner: ALIGN_SUM
  notificationChannels:
    - "projects/pcc-prj-devops-prod/notificationChannels/pagerduty-oncall"
  alertStrategy:
    autoClose: 3600s  # Auto-close after 1 hour if resolved

---

alertPolicy:
  displayName: "ArgoCD - Repository Connection Lost"
  conditions:
    - displayName: "GitHub repository unreachable"
      conditionThreshold:
        filter: |
          resource.type="k8s_pod"
          AND resource.labels.namespace_name="argocd"
          AND resource.labels.pod_name=~"argocd-repo-server-.*"
          AND metric.type="logging.googleapis.com/log_entry_count"
          AND logName="projects/pcc-prj-devops-prod/logs/stderr"
          AND textPayload=~".*connection refused.*github.com.*"
        comparison: COMPARISON_GT
        thresholdValue: 5
        duration: 180s  # 3 minutes
  notificationChannels:
    - "projects/pcc-prj-devops-prod/notificationChannels/slack-platform-alerts"
```

**Log Queries for Investigation**:

1. **Recent sync failures**:
   ```
   resource.type="k8s_pod"
   resource.labels.namespace_name="argocd"
   resource.labels.pod_name=~"argocd-application-controller-.*"
   severity>=ERROR
   jsonPayload.message=~".*sync failed.*"
   ```

2. **GitHub authentication errors**:
   ```
   resource.type="k8s_pod"
   resource.labels.namespace_name="argocd"
   resource.labels.pod_name=~"argocd-repo-server-.*"
   jsonPayload.message=~".*authentication.*failed.*"
   ```

3. **Redis connection issues**:
   ```
   resource.type="k8s_pod"
   resource.labels.namespace_name="argocd"
   jsonPayload.message=~".*redis.*connection.*refused.*"
   ```

**Integration with Existing Monitoring Stack**:
- **Prometheus**: Deploy ServiceMonitor CRD to scrape ArgoCD metrics (if using Prometheus Operator)
- **Grafana**: Import official ArgoCD dashboard (ID: 14584) from grafana.com
- **PagerDuty**: Create dedicated escalation policy for ArgoCD critical alerts
- **Slack**: #platform-alerts channel for non-critical notifications
- **Runbook**: Document incident response procedures at `.claude/docs/argocd-runbook.md`

**Monitoring Setup Tasks** (for operations team):
1. Create Cloud Monitoring dashboards (estimated 30-45 min)
2. Configure alert policies (estimated 45-60 min)
3. Test alert delivery (Slack, PagerDuty) (estimated 15 min)
4. Create runbook documentation (estimated 60-90 min)
5. Schedule weekly dashboard review with platform team
6. Set up log retention policy (default 30 days, extend to 90 days for audit)

**Success Criteria**:
- ✅ All 7 key metrics tracked in Cloud Monitoring
- ✅ Critical alerts deliver to PagerDuty within 2 minutes
- ✅ Dashboards accessible to platform team (shared link)
- ✅ Runbook created with escalation procedures
- ✅ Weekly monitoring review scheduled

**Documentation Reference**:
- Create file: `.claude/docs/argocd-monitoring-setup.md`
- Include: Dashboard JSON exports, alert policy YAML, log query reference
- Commit to repository for version control

---

**Deliverables**:
- GitHub repository (core/pcc-app-argo-config) connected to prod ArgoCD via GitHub App with Workload Identity
- Kubernetes secret (argocd-repo-creds) created in argocd namespace with GitHub App credentials (app ID, installation ID, private key)
- Workload Identity annotation applied to argocd-repo-server service account
- Repository connection status: Successful in ArgoCD CLI and UI
- Repository fetch verified (can read manifests from core/pcc-app-argo-config)
- Documentation file: `.claude/docs/argocd-prod-github-integration.md` committed to git
- HA-specific validation complete (all 14 pods verified, both repo-server replicas tested)

**Dependencies**:
- Phase 4.11 complete (cluster management configured, app-devtest cluster registered)
- ArgoCD CLI installed (v2.13.x or later) and authenticated to prod instance (argocd-east4.pcconnect.ai)
- kubectl access to pcc-gke-devops-prod cluster via Connect Gateway (context: gke_pcc-prj-devops-prod_us-east4_pcc-gke-devops-prod)
- Access to Secret Manager in pcc-prj-devops-prod project:
  - Secret: `argocd-github-app-credentials` (contains GitHub App credentials: appId, installationId, privateKey)
  - IAM role: `roles/secretmanager.secretAccessor` for argocd-repo-server@pcc-prj-devops-prod.iam.gserviceaccount.com
- jq command-line tool installed (for JSON parsing of Secret Manager credentials)
- GCP service account: argocd-repo-server@pcc-prj-devops-prod.iam.gserviceaccount.com with IAM bindings:
  - `roles/iam.workloadIdentityUser` for serviceAccount:pcc-prj-devops-prod.svc.id.goog[argocd/argocd-repo-server]
  - `roles/secretmanager.secretAccessor` for Secret Manager access
- Access to `core/pcc-app-argo-config` repository (GitHub App already configured, read-only permissions)
- Verify Phase 4.11 cluster list shows app-devtest: `argocd cluster list`

---

#### Phase 4.13: Configure App-of-Apps Pattern (25-35 min)

**Objective**: Create app-of-apps framework for managing child applications across devtest environment

**⚠️ IMPORTANT for Claude Code Execution**: Before presenting ANY command block in this phase, Claude MUST explicitly remind the user: "Please open WARP terminal now to execute the following commands." Wait for user acknowledgment before proceeding with command presentation.

**Execution Structure**: Three modular sections executed sequentially
1. **Module 1: Pre-flight Checks** (5-7 min) - Verify ArgoCD operational, repository structure, permissions
2. **Module 2: App-of-Apps Configuration** (12-18 min) - Create root Application manifest, directory structure
3. **Module 3: Validation & Documentation** (8-10 min) - Test sync, validate app discovery, create pattern docs

**Key Architectural Context** (from previous phases):
- **App-of-Apps Two-Tier Architecture**:
  - **Tier 1 (Control Plane)**: Root app-of-apps Application CRD deployed in **prod cluster** (pcc-gke-devops-prod) argocd namespace
  - **Tier 2 (Workload Deployment)**: Child Application CRDs managed by root app also live in **prod cluster** argocd namespace, but deploy workloads to **app-devtest cluster**
  - **Important**: Both root and child Applications are Kubernetes CRDs in the prod ArgoCD namespace. The difference is in their `spec.destination.server` field - root points to in-cluster (https://kubernetes.default.svc), children point to app-devtest cluster server URL
- Repository: `core/pcc-app-argo-config` with `applications/devtest/` directory structure
- Sync policies: Auto-sync enabled, prune: true, selfHeal: true for devtest environment
- Root app-of-apps destination: `https://kubernetes.default.svc` (in-cluster = prod ArgoCD cluster)
- Child application destinations: app-devtest cluster server URL (retrieved in Section 1.2)
- Root namespace: `argocd` (standard ArgoCD control plane location in prod cluster)
- Pattern reference: Same as Phase 4.8 nonprod, adapted for prod multi-app management
- Child applications: Placeholder structure for Phase 6+ population (user-api, task-tracker-api, etc.)

**Security Considerations**:
- AppProject RBAC scoping (restrict source repositories to pcc-app-argo-config only)
- No credentials/secrets in Application manifests (use Secret Manager for sensitive config)
- GitHub App authentication via Workload Identity (established Phase 4.12)
- Audit logging for Application CRD changes in prod cluster
- Sync source validation: Only allow manifests from `applications/devtest` path
- Destination cluster validation: Only allow deployment to app-devtest cluster

---

##### Module 1: Pre-flight Checks (5-7 min)

**Purpose**: Verify all prerequisites before app-of-apps framework deployment

**Section 1.1: ArgoCD Repository Status Verification**
- **Action**: Confirm GitHub repository integration from Phase 4.12 is still operational
- **Verify repository connection**:
  - Command: `argocd repo list`
  - Expected output:
    ```
    REPOSITORY                                     TYPE  NAME                PROJECT  STATUS      MESSAGE
    https://github.com/ORG/pcc-app-argo-config.git git   pcc-app-argo-config  default  Successful  Repo is accessible
    ```
  - Success criteria: STATUS=Successful, no connection errors
  - Troubleshooting: If not Successful, re-run Phase 4.12 Module 2 to restore GitHub integration

- **Test repository refresh**:
  - Command: `argocd repo get https://github.com/ORG/pcc-app-argo-config.git --refresh`
  - Expected: Returns connection status with recent timestamp
  - Note: Ensures repo-server can currently reach GitHub

- **Verify argocd context**:
  - Command: `argocd context`
  - Expected: Current context points to `argocd-east4.pcconnect.ai`
  - Note: Ensures all subsequent argocd commands target prod instance

**Section 1.2: Target Cluster Verification**
- **Action**: Verify app-devtest cluster is registered and healthy in ArgoCD
- **List registered clusters**:
  - Command: `argocd cluster list`
  - Expected output includes:
    ```
    SERVER                          NAME              VERSION STATUS MESSAGE
    https://kubernetes.default.svc  in-cluster        <version> Successful
    <app-devtest-server-ip>:443     app-devtest       <version> Successful
    ```
  - Success criteria: app-devtest cluster shows STATUS=Successful
  - Troubleshooting: If app-devtest missing or unhealthy, re-run Phase 4.11 cluster registration

- **Get app-devtest cluster details and capture server URL** (CRITICAL for child applications):
  - Command: `argocd cluster get app-devtest`
  - Expected fields:
    - `server: <cluster-api-endpoint>`
    - `name: app-devtest`
    - `connectionStatus: Successful`
    - `status.operationState.phase: Succeeded`
  - **IMPORTANT: Document the server URL for Phase 6**:
    ```bash
    # Extract and save app-devtest cluster server URL
    APP_DEVTEST_SERVER=$(argocd cluster get app-devtest -o json | jq -r '.server')
    echo "app-devtest cluster server URL: $APP_DEVTEST_SERVER"

    # Save to file for Phase 6 reference
    echo "$APP_DEVTEST_SERVER" > /tmp/app-devtest-server-url.txt
    echo "✅ Server URL saved to /tmp/app-devtest-server-url.txt"
    ```
  - Expected output example: `https://34.86.XXX.XXX` or `https://gke-xxx.us-east4.gcp.cloud`
  - **Why this matters**: Child applications created in Phase 6 will use this exact URL in their `spec.destination.server` field to deploy workloads to app-devtest cluster
  - Note: Detailed output confirms cluster registration and connectivity

- **Verify cluster API connectivity from ArgoCD**:
  - Command: `kubectl -n argocd get secret app-devtest-cluster-config`
  - Expected: Secret exists containing cluster kubeconfig
  - Note: ArgoCD uses this secret to authenticate to target cluster

**Section 1.3: Repository Structure Preparation**
- **Action**: Verify core/pcc-app-argo-config repository has required directory structure
- **Clone/navigate to repository**:
  - Command: `cd /tmp && git clone https://github.com/ORG/pcc-app-argo-config.git` (if not already cloned)
  - Expected: Repository cloned successfully
  - Alternative: If already cloned, update: `git pull origin main`

- **Verify applications directory exists**:
  - Command: `ls -la core/pcc-app-argo-config/applications/ 2>/dev/null || echo "Directory does not exist"`
  - Expected: Lists existing directories (e.g., nonprod, prod)
  - If missing: Will create in Module 2

- **Check for devtest directory**:
  - Command: `ls -la core/pcc-app-argo-config/applications/devtest/ 2>/dev/null || echo "Directory does not exist"`
  - Expected: Either shows existing devtest structure or "Directory does not exist"
  - Note: If exists, will populate; if not, will create in Module 2

**Section 1.4: Namespace Verification**
- **Action**: Verify argocd namespace exists in prod cluster for app-of-apps deployment
- **Switch to prod cluster context**:
  - Command: `kubectl config use-context gke_pcc-prj-devops-prod_us-east4_pcc-gke-devops-prod`
  - Expected: Context switches successfully

- **Verify argocd namespace**:
  - Command: `kubectl get namespace argocd`
  - Expected output:
    ```
    NAME     STATUS   AGE
    argocd   Active   <age>
    ```
  - Success criteria: Namespace exists with STATUS=Active

- **Verify ArgoCD is running** (pod count):
  - Command: `kubectl -n argocd get pods | wc -l`
  - Expected: 14+ pods (HA configuration from Phase 4.5)
  - Note: Confirms ArgoCD control plane is operational

**Pre-flight Checks Output**: Go/No-Go decision
- **GO**: All 4 sections passed → Proceed to Module 2
  - ✅ Section 1.1: GitHub repository connection Successful, can refresh
  - ✅ Section 1.2: app-devtest cluster registered with Successful status
  - ✅ Section 1.3: Repository structure exists or ready to create
  - ✅ Section 1.4: argocd namespace active, 14+ pods running
- **NO-GO**: Any section failed → Stop, fix issues, re-run pre-flight checks
  - ❌ Repository not connected: Re-run Phase 4.12 GitHub integration
  - ❌ Cluster not registered: Re-run Phase 4.11 cluster setup
  - ❌ Directory structure missing: Verify repo access, may need to create manually

**Critical checkpoint**: DO NOT proceed to Module 2 if any pre-flight check failed.

---

##### Module 2: App-of-Apps Configuration (12-18 min)

**Purpose**: Create root Application manifest and directory structure for app-of-apps pattern

**Section 2.1: Repository Directory Structure Setup**
- **Action**: Create directory hierarchy in core/pcc-app-argo-config for applications
- **Navigate to repository**:
  - Command: `cd /tmp/pcc-app-argo-config` (or your cloned location)
  - Verify: `pwd` shows pcc-app-argo-config directory

- **Create applications root directory** (if not exists):
  - Command: `mkdir -p applications`
  - Verify: `ls -la applications/`

- **Create devtest applications subdirectory**:
  - Command: `mkdir -p applications/devtest`
  - Verify: `ls -la applications/devtest/`

- **Create root applications directory** (for root app-of-apps manifest):
  - Command: `mkdir -p applications/root`
  - Verify: `ls -la applications/root/`

- **Create .keep files to preserve directories in git**:
  - Commands:
    ```bash
    touch applications/devtest/.keep
    touch applications/root/.keep
    ```
  - Note: Git doesn't track empty directories; .keep ensures directory exists in git

- **Directory structure verification**:
  - Command: `tree applications/ -L 2` (or `find applications -type f`)
  - Expected output:
    ```
    applications/
    ├── devtest/
    │   └── .keep
    └── root/
        └── .keep
    ```
  - Note: devtest/ will hold child applications, root/ will hold app-of-apps manifest

**Section 2.2: AppProject RBAC Configuration**
- **Action**: Create dedicated AppProject with RBAC scoping for devtest applications (security requirement)
- **Create AppProject manifest file**:
  - File path: `applications/root/appproject-pcc-devtest.yaml`
  - Content:
    ```yaml
    apiVersion: argoproj.io/v1alpha1
    kind: AppProject
    metadata:
      name: pcc-devtest-apps
      namespace: argocd
      finalizers:
      - resources-finalizer.argocd.argoproj.io
    spec:
      description: AppProject for PCC devtest environment applications with RBAC restrictions

      # Source repositories - restrict to pcc-app-argo-config only
      sourceRepos:
      - https://github.com/ORG/pcc-app-argo-config.git

      # Destination clusters - restrict to app-devtest only
      destinations:
      - namespace: '*'
        server: '*'  # Will be restricted to app-devtest server URL in Phase 6
        name: app-devtest

      # Cluster resource whitelist - allow all standard Kubernetes resources
      clusterResourceWhitelist:
      - group: '*'
        kind: '*'

      # Namespace resource whitelist - allow all resources in target namespaces
      namespaceResourceWhitelist:
      - group: '*'
        kind: '*'

      # Roles for RBAC (optional - can be populated in future phases)
      roles: []

      # Orphaned resources - warn but don't delete
      orphanedResources:
        warn: true
    ```
  - Replace `ORG` with actual GitHub organization
  - **Why this matters**: AppProject enforces security boundaries by restricting:
    - Source repos (only pcc-app-argo-config can be used)
    - Destination clusters (only app-devtest can be targeted)
    - Prevents accidental deployment from untrusted repos or to wrong clusters
  - Note: Using `server: '*'` temporarily - will be restricted to specific app-devtest server URL in Phase 6 after URL captured

- **Verify AppProject manifest syntax**:
  - Command: `cat applications/root/appproject-pcc-devtest.yaml`
  - Expected: YAML syntax is valid, no missing fields
  - **IMPORTANT: Verify ORG placeholder replaced**:
    ```bash
    grep -n "ORG" applications/root/appproject-pcc-devtest.yaml
    ```
  - Expected: No output (ORG fully replaced with actual organization name)
  - If ORG found: STOP and replace with actual organization before proceeding

**Section 2.3: Root Application Manifest Creation**
- **Action**: Create root app-of-apps Application manifest that references devtest subdirectory
- **Create app-of-apps manifest file**:
  - File path: `applications/root/app-of-apps-devtest.yaml`
  - Content:
    ```yaml
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: pcc-app-of-apps-devtest
      namespace: argocd
      finalizers:
      - resources-finalizer.argocd.argoproj.io
    spec:
      project: pcc-devtest-apps  # Use dedicated AppProject with RBAC restrictions

      source:
        repoURL: https://github.com/ORG/pcc-app-argo-config.git
        targetRevision: main
        path: applications/devtest

      destination:
        server: https://kubernetes.default.svc
        namespace: argocd

      syncPolicy:
        automated:
          prune: true
          selfHeal: true
          allowEmpty: false
        syncOptions:
        - CreateNamespace=false
        retry:
          limit: 5
          backoff:
            duration: 5s
            factor: 2
            maxDuration: 3m

      info:
      - name: Documentation
        value: https://github.com/ORG/pcc-app-argo-config/blob/main/.claude/docs/argocd-app-of-apps-pattern.md
      - name: Owner
        value: DevOps Team
    ```
  - Replace `ORG` with actual GitHub organization
  - Note: This manifest instructs ArgoCD to manage all Applications in applications/devtest/ directory

- **Manifest field explanations**:
  - `metadata.finalizers`: Ensures clean deletion with resource cleanup
  - `spec.project`: pcc-devtest-apps AppProject (created in Section 2.2 with RBAC restrictions)
  - `source.path: applications/devtest`: Points to directory containing child Applications
  - `destination.server: https://kubernetes.default.svc`: Deploys app-of-apps to prod cluster's argocd namespace
  - `syncPolicy.automated.prune: true`: Removes child apps if removed from devtest directory
  - `syncPolicy.automated.selfHeal: true`: Re-syncs if manual changes made to cluster
  - `syncPolicy.retry`: Implements exponential backoff for failed syncs

**Section 2.4: Manifest Validation and Repository Commit**
- **Action**: Validate manifests and commit new files to core/pcc-app-argo-config repository

- **⚠️ CRITICAL: Validate ORG placeholder replacement** (prevents deployment failure):
  - Command:
    ```bash
    # Check ALL manifest files for unreplaced ORG placeholder
    echo "Checking for unreplaced 'ORG' placeholders..."
    if grep -rn "ORG" applications/root/*.yaml; then
      echo "❌ ERROR: Found unreplaced 'ORG' placeholder in manifest files"
      echo "Replace all instances of 'ORG' with actual GitHub organization name"
      echo "Example: portco-connect, myorg, company-name"
      exit 1
    else
      echo "✅ No ORG placeholders found - all manifests validated"
    fi
    ```
  - Expected: `✅ No ORG placeholders found - all manifests validated`
  - **If ERROR**: Open manifest files and replace `ORG` with actual organization, then re-run validation
  - **Why this matters**: Unreplaced placeholders cause silent authentication failures in production

- **Validate YAML syntax** (prevents ArgoCD parse errors):
  - Command:
    ```bash
    # Verify all manifests are valid YAML
    for file in applications/root/*.yaml; do
      echo "Validating $file..."
      yq eval '.' "$file" > /dev/null 2>&1 || {
        echo "❌ ERROR: Invalid YAML syntax in $file"
        exit 1
      }
    done
    echo "✅ All manifests have valid YAML syntax"
    ```
  - Expected: `✅ All manifests have valid YAML syntax`
  - Alternative if `yq` not installed: Use `python3 -c "import yaml; yaml.safe_load(open('$file'))"` or kubectl dry-run in next section

- **Validate sync source path exists** (security requirement):
  - Command:
    ```bash
    # Verify applications/devtest directory exists and is accessible
    if git ls-tree HEAD:applications/devtest >/dev/null 2>&1; then
      echo "✅ Sync source path 'applications/devtest' exists and is accessible"
    else
      echo "❌ ERROR: Sync source path 'applications/devtest' not found in git repository"
      echo "Cannot deploy app-of-apps with invalid source path"
      exit 1
    fi
    ```
  - Expected: `✅ Sync source path 'applications/devtest' exists and is accessible`
  - **Why this matters**: Typo in path causes app-of-apps to sync wrong resources or fail completely
  - Security note: This validates manifests will only be read from intended directory (applications/devtest)

- **Stage files for commit**:
  - Commands:
    ```bash
    git add applications/devtest/.keep
    git add applications/root/.keep
    git add applications/root/appproject-pcc-devtest.yaml
    git add applications/root/app-of-apps-devtest.yaml
    ```
  - Verify: `git status` shows files ready for commit
  - **Verify correct files staged**:
    ```bash
    git diff --cached --name-only
    ```
  - Expected output:
    ```
    applications/devtest/.keep
    applications/root/.keep
    applications/root/appproject-pcc-devtest.yaml
    applications/root/app-of-apps-devtest.yaml
    ```

- **Commit to main branch**:
  - Command:
    ```bash
    git commit -m "feat: add app-of-apps pattern for devtest environment

    - Create applications/root directory for root app-of-apps manifest
    - Create applications/devtest directory for child application manifests
    - Add pcc-app-of-apps-devtest Application manifest with auto-sync policies
    - Configure sync retry with exponential backoff
    - Target: app-devtest cluster in argocd namespace"
    ```
  - Expected: Commit message displayed with file statistics

- **Push to remote repository**:
  - Command: `git push origin main`
  - Expected: `main -> main` message indicating successful push
  - Verify: `git log --oneline -1` shows recent commit

- **Verify files in GitHub UI** (optional visual check):
  - Navigate to: https://github.com/ORG/pcc-app-argo-config/tree/main/applications/root
  - Expected: app-of-apps-devtest.yaml visible in browser

**Section 2.4: App-of-Apps Deployment to ArgoCD**
- **Action**: Deploy root Application manifest to prod ArgoCD
- **Create Application from manifest file**:
  - Command:
    ```bash
    argocd app create pcc-app-of-apps-devtest \
      --repo https://github.com/ORG/pcc-app-argo-config.git \
      --path applications/root \
      --dest-server https://kubernetes.default.svc \
      --dest-namespace argocd \
      --revision main \
      --project default
    ```
  - Expected output: `application 'pcc-app-of-apps-devtest' created`

- **Alternative: Apply manifest directly with kubectl**:
  - Command:
    ```bash
    kubectl apply -f applications/root/app-of-apps-devtest.yaml
    ```
  - Expected: `application.argoproj.io/pcc-app-of-apps-devtest created`
  - Note: This method uses ArgoCD Custom Resource, more reliable with manifests

- **Verify Application created**:
  - Command: `argocd app list | grep pcc-app-of-apps-devtest`
  - Expected output shows:
    ```
    NAME                        CLUSTER            NAMESPACE  PROJECT  STATUS      HEALTH
    pcc-app-of-apps-devtest     in-cluster         argocd     default  OutOfSync   Healthy
    ```
  - Note: Initial status is OutOfSync until first sync

- **Describe application**:
  - Command: `argocd app get pcc-app-of-apps-devtest`
  - Expected fields:
    - `Name: pcc-app-of-apps-devtest`
    - `Project: default`
    - `Status: OutOfSync` (initially)
    - `Sync Policy: Automated`
    - `Repo: https://github.com/ORG/pcc-app-argo-config.git`
    - `Path: applications/devtest`

**Section 2.5: App-of-Apps Synchronization**
- **Action**: Trigger initial sync of app-of-apps to establish management relationship
- **Initiate sync**:
  - Command: `argocd app sync pcc-app-of-apps-devtest`
  - Expected output: Shows sync operation progressing with resource events
  - Note: First sync establishes app-of-apps infrastructure

- **Monitor sync progress**:
  - Command: `argocd app get pcc-app-of-apps-devtest --refresh`
  - Expected: STATUS changes to Synced, HEALTH=Healthy
  - Wait for: Sync to complete (usually 30-60 seconds)

- **Check sync status in detail**:
  - Command: `argocd app get pcc-app-of-apps-devtest --output yaml | grep -A 10 "status:"`
  - Expected: Shows operationState.phase=Succeeded, syncResult.resources count

- **Verify in ArgoCD UI** (optional):
  - Navigate to: https://argocd-east4.pcconnect.ai → Applications
  - Expected: pcc-app-of-apps-devtest appears with SYNC STATUS=Synced, HEALTH=Healthy
  - Note: UI provides visual confirmation

- **Success criteria**: Sync completes without errors, SYNC STATUS=Synced, HEALTH=Healthy

---

##### Module 3: Validation & Documentation (8-10 min)

**Purpose**: Validate app-of-apps functionality and create comprehensive pattern documentation

**Section 3.1: App-of-Apps Sync Validation**
- **Action**: Verify app-of-apps successfully syncs and manages child application directory
- **Get application sync status**:
  - Command: `argocd app get pcc-app-of-apps-devtest`
  - Expected output fields:
    - `SYNC STATUS: Synced`
    - `HEALTH STATUS: Healthy`
    - `REVISION: <commit-sha>`
    - `CREATED AT: <timestamp>`
  - Success criteria: Both Synced and Healthy

- **View application resources**:
  - Command: `argocd app resources pcc-app-of-apps-devtest`
  - Expected: Lists resources managed by app-of-apps (should be empty initially, populated Phase 6+)
  - Note: This shows what the root app-of-apps is currently managing

- **Get application manifest**:
  - Command: `argocd app get pcc-app-of-apps-devtest --output yaml | head -50`
  - Expected: Shows Application CRD spec with source.path=applications/devtest
  - Verify: Fields match manifest created in Section 2.2

**Section 3.2: Directory Structure Discovery**
- **Action**: Verify ArgoCD can discover and parse applications/devtest directory structure
- **Test ArgoCD manifest discovery**:
  - Command: `argocd app resources pcc-app-of-apps-devtest --output wide`
  - Expected: Shows resources found in applications/devtest directory
  - Note: Should be empty if only .keep file exists (will populate in Phase 6)

- **Verify ArgoCD can list directory contents**:
  - Via CLI: `argocd app get pcc-app-of-apps-devtest`
  - Via UI: Navigate to Applications → pcc-app-of-apps-devtest → Manifest
  - Expected: Shows current source tree in detail

- **⚠️ MANDATORY: Test empty directory behavior with placeholder child application**:
  - **Why mandatory**: Validates app-of-apps handles empty directories correctly before Phase 6 deploys real applications. Prevents production blocking issues.
  - Create test file: `applications/devtest/test-app.yaml`
  - Content:
    ```yaml
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: test-child-app
      namespace: argocd
    spec:
      project: pcc-devtest-apps  # Use same AppProject as root app
      source:
        repoURL: https://github.com/ORG/pcc-app-argo-config.git
        targetRevision: main
        path: charts/test-placeholder  # Non-existent path (intentional for testing)
      destination:
        server: '$APP_DEVTEST_SERVER'  # Use server URL captured in Section 1.2
        namespace: pcc-test  # Test namespace in app-devtest cluster
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
        - CreateNamespace=true  # Auto-create test namespace
    ```
  - **Important namespace strategy decision**:
    - This manifest uses `CreateNamespace=true` syncOption
    - ArgoCD will automatically create `pcc-test` namespace in app-devtest cluster
    - **Recommended for Phase 6**: All child applications should use `CreateNamespace=true` for automation
    - Alternative: Pre-create namespaces manually (not recommended - reduces automation)
  - Push to repository:
    ```bash
    git add applications/devtest/test-app.yaml
    git commit -m "test: add placeholder child application for empty directory validation"
    git push origin main
    ```
  - Wait for ArgoCD to detect: Usually 3-5 minutes or manual sync with `argocd app sync pcc-app-of-apps-devtest`

- **Verify child app discovery and deployment** (validates full app-of-apps lifecycle):
  - Command: `argocd app get pcc-app-of-apps-devtest --refresh`
  - Expected: test-child-app should appear in managed resources
  - Verify child app created:
    ```bash
    argocd app list | grep test-child-app
    ```
  - Expected output:
    ```
    NAME             CLUSTER                NAMESPACE  PROJECT           STATUS      HEALTH
    test-child-app   <app-devtest-server>   pcc-test   pcc-devtest-apps  OutOfSync   Missing
    ```
  - Note: Status=OutOfSync and Health=Missing are expected (charts/test-placeholder doesn't exist)
  - **Validation success criteria**: Child app exists, proving app-of-apps discovery works

- **Verify namespace creation** (validates CreateNamespace option works):
  - Switch to app-devtest cluster context
  - Command: `kubectl get namespace pcc-test`
  - Expected: Namespace exists (created automatically by ArgoCD)
  - **Critical for Phase 6**: This validates auto-namespace creation works for real applications

- **Cleanup after validation** (mandatory):
  - Remove test application from repository:
    ```bash
    git rm applications/devtest/test-app.yaml
    git commit -m "test: remove placeholder application after validation"
    git push origin main
    ```
  - Wait for app-of-apps to sync (auto-sync enabled)
  - Verify child app pruned:
    ```bash
    argocd app list | grep test-child-app
    # Should return empty (app removed by prune policy)
    ```
  - Verify namespace cleanup (optional - namespace may persist, cleanup in Phase 6):
    ```bash
    kubectl --context <app-devtest-context> delete namespace pcc-test
    ```
  - **Success criteria**: test-child-app removed, prune functionality validated

**Section 3.3: App-of-Apps Pattern Validation**
- **Action**: Verify app-of-apps pattern behaves correctly (prune, self-heal)
- **Test self-heal functionality**:
  - Make manual change to app-of-apps: `kubectl -n argocd annotate application pcc-app-of-apps-devtest manual-edit="test" --overwrite`
  - Wait 3-5 seconds (selfHeal reconciliation interval)
  - Verify removal: `kubectl -n argocd get application pcc-app-of-apps-devtest -o yaml | grep manual-edit`
  - Expected: Annotation removed (self-heal reverted manual change)

- **Test prune functionality** (requires child apps):
  - When child applications are added in Phase 6, remove one from repository
  - Wait for ArgoCD sync (auto-sync enabled)
  - Verify: App-of-apps removes the child application from cluster
  - Note: Demonstrates automated cleanup

- **Verify sync retry configuration**:
  - Command: `argocd app get pcc-app-of-apps-devtest -o yaml | grep -A 5 "retry:"`
  - Expected output shows retry backoff configuration
  - Note: Ensures failed syncs are retried with exponential backoff

**Section 3.4: Kubernetes Resources Verification**
- **Action**: Verify app-of-apps Application CRD exists in cluster
- **Check Application resource in cluster**:
  - Command: `kubectl -n argocd get applications`
  - Expected output:
    ```
    NAME                       SYNC STATUS   HEALTH STATUS
    pcc-app-of-apps-devtest    Synced        Healthy
    ```
  - Success criteria: Application exists with correct sync and health status

- **Get Application YAML from cluster**:
  - Command: `kubectl -n argocd get application pcc-app-of-apps-devtest -o yaml | head -40`
  - Expected: Shows metadata, spec matching manifest created in Section 2.2

- **Verify ArgoCD controller manages application**:
  - Command: `kubectl -n argocd logs deployment/argocd-application-controller --tail=20 | grep pcc-app-of-apps`
  - Expected: Shows log entries for app-of-apps reconciliation
  - Note: Confirms controller is actively managing the application

**Section 3.5: HA Validation Testing**
- **Action**: Validate app-of-apps management survives application-controller pod failure (HA failover)
- **Purpose**: Ensure high availability works correctly for app-of-apps pattern before production load

- **Identify current application-controller leader**:
  - Command:
    ```bash
    # Application controller uses leader election for HA
    kubectl -n argocd get pods -l app.kubernetes.io/name=argocd-application-controller -o wide
    ```
  - Expected: Shows 1 pod (single controller in HA configuration)
  - Note: ArgoCD 3.1.9 uses single controller pod with leader election for stateful operations

- **Trigger sync operation before leader deletion**:
  - Command:
    ```bash
    # Start sync operation
    argocd app sync pcc-app-of-apps-devtest --async
    echo "Sync operation started at $(date)"
    ```
  - Expected: Sync initiates without waiting for completion
  - Note: `--async` allows us to test failover during active operation

- **Delete application-controller pod (simulate failure)**:
  - Command:
    ```bash
    # Identify controller pod name
    CONTROLLER_POD=$(kubectl -n argocd get pods -l app.kubernetes.io/name=argocd-application-controller -o jsonpath='{.items[0].metadata.name}')
    echo "Deleting controller pod: $CONTROLLER_POD"

    # Delete pod to simulate failure
    kubectl -n argocd delete pod $CONTROLLER_POD

    # Watch pod recreation
    kubectl -n argocd get pods -l app.kubernetes.io/name=argocd-application-controller --watch
    # Press Ctrl+C after new pod reaches Running state
    ```
  - Expected: Pod deletes immediately, new pod created within 10-30 seconds
  - Note: Kubernetes automatically recreates the pod (controlled by StatefulSet)

- **Verify sync operation continues/recovers**:
  - Wait 30-60 seconds for new controller pod to become ready
  - Command:
    ```bash
    # Check sync status
    argocd app get pcc-app-of-apps-devtest
    ```
  - Expected outcomes:
    - **Best case**: Sync completed successfully (operation finished before/during failover)
    - **Good case**: Sync shows "in progress" (new controller resumed operation)
    - **Acceptable case**: Sync failed but retry policy will re-attempt (exponential backoff configured)
  - Verification: Wait up to 3 minutes for sync completion
  - **Success criteria**: App-of-apps reaches STATUS=Synced, HEALTH=Healthy within 3 minutes of pod recovery

- **Validate no resource loss during failover**:
  - Command:
    ```bash
    # Verify child applications still managed
    argocd app resources pcc-app-of-apps-devtest

    # Verify Application CRD intact
    kubectl -n argocd get application pcc-app-of-apps-devtest -o yaml | head -40
    ```
  - Expected: All resources present, no data loss
  - Note: Leader election ensures only one controller modifies resources at a time

- **Check controller logs for failover**:
  - Command:
    ```bash
    # Get new controller pod name
    NEW_CONTROLLER=$(kubectl -n argocd get pods -l app.kubernetes.io/name=argocd-application-controller -o jsonpath='{.items[0].metadata.name}')

    # Check logs for leader election and recovery
    kubectl -n argocd logs $NEW_CONTROLLER | grep -i "leader\|acquired\|app-of-apps"
    ```
  - Expected: Shows leader election messages, app-of-apps reconciliation resuming
  - Sample log entries: "acquired leader lease", "processing application: pcc-app-of-apps-devtest"

- **HA validation success criteria**:
  - ✅ Controller pod recreated within 30 seconds
  - ✅ App-of-apps sync completes or resumes within 3 minutes
  - ✅ No child applications lost during failover
  - ✅ Final state: STATUS=Synced, HEALTH=Healthy
  - ✅ Controller logs show successful leader election and operation resumption

- **If validation fails**:
  - Check StatefulSet configuration: `kubectl -n argocd get statefulset argocd-application-controller -o yaml`
  - Verify pod resource limits not causing OOMKilled: `kubectl -n argocd describe pod $NEW_CONTROLLER`
  - Check for CrashLoopBackOff: `kubectl -n argocd get pods -l app.kubernetes.io/name=argocd-application-controller`
  - Review full controller logs: `kubectl -n argocd logs $NEW_CONTROLLER --tail=100`

**Section 3.6: Documentation Creation**
- **Action**: Create comprehensive app-of-apps pattern documentation
- **Create documentation file**:
  - File path: `.claude/docs/argocd-app-of-apps-pattern.md`
  - Content structure (see template below)

- **Documentation template**:
  ```markdown
  # ArgoCD App-of-Apps Pattern - DevTest Environment

  ## Overview
  - **Environment**: DevTest (app-devtest cluster)
  - **Root Application**: pcc-app-of-apps-devtest
  - **Pattern**: App-of-Apps (root Application manages child Applications)
  - **Repository**: https://github.com/ORG/pcc-app-argo-config.git
  - **Configured**: <date>

  ## Architecture

  ### Directory Structure
  ```
  applications/
  ├── root/
  │   └── app-of-apps-devtest.yaml    # Root Application manifest
  ├── devtest/
  │   ├── .keep                        # Placeholder for child apps
  │   ├── user-api-app.yaml           # Phase 6: pcc-user-api child app
  │   ├── task-tracker-api-app.yaml   # Phase 6: pcc-task-tracker-api child app
  │   └── ...                          # Additional child applications
  └── nonprod/
      └── ...                          # Non-devtest applications (future)
  ```

  ### App-of-Apps Concept
  - **Root Application** (`pcc-app-of-apps-devtest`): Monitors `applications/devtest/` directory
  - **Child Applications**: Individual Application CRDs in devtest subdirectory
  - **Synchronization**: Root app auto-discovers and syncs all child applications
  - **Prune Policy**: Removed child apps are automatically pruned from cluster
  - **Self-Heal**: Manual changes to child apps are reverted to GitOps state

  ## Root Application Configuration

  ### Manifest Location
  - **File**: applications/root/app-of-apps-devtest.yaml
  - **Repository**: https://github.com/ORG/pcc-app-argo-config.git
  - **Branch**: main

  ### Key Configuration Fields
  - **Sync Source**: applications/devtest directory
  - **Target Cluster**: in-cluster (prod ArgoCD cluster)
  - **Target Namespace**: argocd
  - **Auto-Sync Policy**: Enabled (prune: true, selfHeal: true)
  - **Retry Policy**: Exponential backoff (limit: 5, max: 3 minutes)

  ## Adding Child Applications

  ### Process (Phases 6+)
  1. Create Application manifest in `applications/devtest/` directory
  2. Manifest name format: `<service-name>-app.yaml`
  3. Set metadata.namespace: argocd
  4. Commit and push to main branch
  5. ArgoCD auto-discovers and syncs the child application

  ### Example Child Application
  ```yaml
  apiVersion: argoproj.io/v1alpha1
  kind: Application
  metadata:
    name: pcc-user-api
    namespace: argocd
  spec:
    project: default
    source:
      repoURL: https://github.com/ORG/pcc-app-argo-config.git
      targetRevision: main
      path: charts/pcc-user-api
    destination:
      server: https://kubernetes.default.svc
      namespace: pcc-user-api
    syncPolicy:
      automated:
        prune: true
        selfHeal: true
  ```

  ## Validation Procedures

  ### Verify Root Application Status
  ```bash
  # Check sync and health status
  argocd app get pcc-app-of-apps-devtest

  # Expected: SYNC STATUS=Synced, HEALTH STATUS=Healthy
  ```

  ### View Child Applications
  ```bash
  # List child applications managed by root app
  argocd app resources pcc-app-of-apps-devtest

  # View in cluster
  kubectl -n argocd get applications
  ```

  ### Monitor Sync Operations
  ```bash
  # View recent sync history
  argocd app history pcc-app-of-apps-devtest

  # View current operation
  argocd app get pcc-app-of-apps-devtest --refresh
  ```

  ## Maintenance Procedures

  ### Adding New Child Applications
  1. Create `applications/devtest/<app-name>-app.yaml`
  2. Commit to main branch
  3. Wait for auto-sync (default: 3 minutes) or manually trigger:
     ```bash
     argocd app sync pcc-app-of-apps-devtest
     ```

  ### Removing Child Applications
  1. Delete application manifest from `applications/devtest/`
  2. Push deletion to main branch
  3. Root app-of-apps auto-prunes deleted application from cluster

  ### Manual Sync
  ```bash
  argocd app sync pcc-app-of-apps-devtest
  ```

  ### Rollback to Previous Revision
  ```bash
  # Step 1: List available revisions with commit history
  argocd app history pcc-app-of-apps-devtest
  # Shows: ID, Date, Revision (git SHA), Source, Sync Status

  # Step 2: View specific revision details and diff
  argocd app history pcc-app-of-apps-devtest <revision-id>
  argocd app diff pcc-app-of-apps-devtest --revision <revision-id>

  # Step 3: Analyze rollback impact
  # IMPORTANT: Rollback affects app-of-apps manifest only, NOT child applications
  # Child apps remain unchanged unless manifests differ between revisions

  # Step 4: Execute rollback
  argocd app rollback pcc-app-of-apps-devtest <revision-id>

  # Step 5: Validate post-rollback state
  argocd app get pcc-app-of-apps-devtest
  # Verify: Sync status, health, current revision matches target
  argocd app resources pcc-app-of-apps-devtest
  # Verify: Child applications still managed correctly
  ```

  ## Monitoring & Alerting

  ### Key Metrics to Monitor
  - **App-of-Apps Sync Status**: `argocd_app_sync_total{name="pcc-app-of-apps-devtest"}`
  - **App-of-Apps Health**: `argocd_app_info{name="pcc-app-of-apps-devtest", health_status!="Healthy"}`
  - **Child App Discovery**: Count of managed resources (should match repository count)
  - **Sync Failures**: Failed sync attempts requiring investigation
  - **Repository Connection**: GitHub repository accessibility from ArgoCD

  ### Prometheus Alert Examples
  ```yaml
  # Alert: App-of-Apps Sync Failure
  - alert: AppOfAppsSyncFailure
    expr: argocd_app_sync_status{name="pcc-app-of-apps-devtest"} != 1
    for: 5m
    labels:
      severity: high
      component: argocd
    annotations:
      summary: "App-of-Apps sync failed for devtest"
      description: "pcc-app-of-apps-devtest has been out of sync for 5+ minutes"

  # Alert: App-of-Apps Unhealthy
  - alert: AppOfAppsUnhealthy
    expr: argocd_app_info{name="pcc-app-of-apps-devtest", health_status!="Healthy"} == 1
    for: 3m
    labels:
      severity: critical
      component: argocd
    annotations:
      summary: "App-of-Apps unhealthy in devtest"
      description: "pcc-app-of-apps-devtest health status degraded"
  ```

  ### Dashboard Panels
  - App-of-Apps sync status timeline (Synced vs OutOfSync)
  - Child application count over time (growth tracking)
  - Sync operation duration (performance monitoring)
  - Failed sync operations (error tracking)

  ### Log Queries
  ```bash
  # App-of-Apps reconciliation logs
  kubectl -n argocd logs deployment/argocd-application-controller \
    | grep "pcc-app-of-apps-devtest"

  # Sync operation logs
  kubectl -n argocd logs deployment/argocd-repo-server \
    | grep "applications/devtest"
  ```

  ## Disaster Recovery

  ### Scenario: App-of-Apps Application Deleted

  **Impact Assessment**:
  - Root app-of-apps Application CRD deleted from prod cluster
  - Child Applications become orphaned (no longer managed)
  - Child Applications continue running (NOT pruned)
  - New child apps cannot be discovered until root restored

  **Recovery Procedure**:
  1. **Verify deletion**:
     ```bash
     kubectl -n argocd get application pcc-app-of-apps-devtest
     # Expected: Error: "not found"
     ```

  2. **Check child applications status**:
     ```bash
     kubectl -n argocd get applications
     # Child apps should still exist (orphaned)
     ```

  3. **Reconstruct app-of-apps from git repository**:
     ```bash
     # Clone repository with manifests
     git clone https://github.com/ORG/pcc-app-argo-config.git
     cd pcc-app-argo-config

     # Apply AppProject first (if using custom project)
     kubectl apply -f applications/root/appproject-pcc-devtest.yaml

     # Apply app-of-apps manifest
     kubectl apply -f applications/root/app-of-apps-devtest.yaml
     ```

  4. **Verify root app recreated**:
     ```bash
     argocd app get pcc-app-of-apps-devtest
     # Expected: Application exists, status may be OutOfSync initially
     ```

  5. **Sync to restore management relationship**:
     ```bash
     argocd app sync pcc-app-of-apps-devtest
     ```

  6. **Validate child applications reconnected**:
     ```bash
     argocd app resources pcc-app-of-apps-devtest
     # Should list all child applications
     kubectl -n argocd get applications -o wide
     # Verify owner references include pcc-app-of-apps-devtest
     ```

  7. **Check for resource drift**:
     ```bash
     # Verify no resources were lost during incident
     argocd app list
     # Compare count with expected child apps
     ```

  **Recovery Time Objective (RTO)**: 5-10 minutes
  **Recovery Point Objective (RPO)**: Zero (git is source of truth)

  ### Scenario: Repository Connection Lost

  **Impact Assessment**:
  - ArgoCD cannot sync app-of-apps from GitHub
  - Existing deployments continue running (no immediate impact)
  - New child apps cannot be discovered
  - Changes to child apps cannot be synced

  **Recovery Procedure**:
  1. **Verify repository connection**:
     ```bash
     argocd repo list | grep pcc-app-argo-config
     # Check STATUS column
     ```

  2. **Test repository access**:
     ```bash
     argocd repo get https://github.com/ORG/pcc-app-argo-config.git --refresh
     ```

  3. **If connection failed, re-run Phase 4.12 GitHub integration**:
     - Verify GitHub App credentials in Secret Manager
     - Verify Workload Identity annotation on argocd-repo-server SA
     - Recreate repository connection if needed

  4. **Validate restoration**:
     ```bash
     argocd app sync pcc-app-of-apps-devtest
     # Should succeed after repository connection restored
     ```

  ## Troubleshooting

  ### Root Application OutOfSync
  - **Symptom**: SYNC STATUS=OutOfSync
  - **Cause**: Child application manifests added/modified/deleted in repository
  - **Resolution**: Manual sync: `argocd app sync pcc-app-of-apps-devtest`

  ### Child Application Not Discovered
  - **Symptom**: Added child app manifest but not appearing in ArgoCD
  - **Cause**: Auto-sync hasn't run (3+ minute wait) or sync error
  - **Resolution**:
    1. Check root app resources: `argocd app resources pcc-app-of-apps-devtest`
    2. Manual sync: `argocd app sync pcc-app-of-apps-devtest`
    3. Check logs: `kubectl -n argocd logs deployment/argocd-application-controller | grep pcc-app-of-apps`

  ### Self-Heal Not Reverting Changes
  - **Symptom**: Manual cluster changes persist despite selfHeal: true
  - **Cause**: Application health status not healthy or sync period > 3 minutes
  - **Resolution**:
    1. Check app health: `argocd app get pcc-app-of-apps-devtest`
    2. Manual sync: `argocd app sync pcc-app-of-apps-devtest`
    3. Verify application manifests are valid

  ## Related Documentation
  - Phase 4.11: Cluster Management Configuration (app-devtest registration)
  - Phase 4.12: GitHub Integration (repository connection)
  - Phase 4.13: App-of-Apps Pattern (this phase)
  - Phase 6: Child Application Deployment (user-api, task-tracker-api, etc.)
  - ArgoCD Documentation: https://argo-cd.readthedocs.io/
  ```

- **Commit documentation file to git**:
  - Commands:
    ```bash
    git add .claude/docs/argocd-app-of-apps-pattern.md
    git commit -m "docs: add ArgoCD app-of-apps pattern documentation for devtest"
    git push origin main
    ```
  - Expected: Documentation file committed and pushed

- **Success criteria**: Documentation file created with comprehensive pattern details, committed to git

**Section 3.6: Troubleshooting Verification**
- **Action**: Test troubleshooting procedures documented in Section 3.5

**Troubleshooting Scenario 1: App-of-Apps Fails to Sync**
- **Symptoms**: `argocd app get` shows STATUS=OutOfSync, cannot trigger sync
- **Root cause**: Repository path `applications/devtest` doesn't exist or is inaccessible
- **Diagnosis steps**:
  1. Verify repository structure: `git ls-tree origin/main applications/devtest`
  2. Check ArgoCD logs: `kubectl -n argocd logs deployment/argocd-repo-server | grep pcc-app-of-apps`
  3. Verify GitHub integration: `argocd repo get https://github.com/ORG/pcc-app-argo-config.git --refresh`
- **Resolution**:
  1. Ensure `applications/devtest` directory exists in repository
  2. Ensure files are committed and pushed: `git push origin main`
  3. Wait 3-5 minutes for ArgoCD refresh
  4. Manual sync: `argocd app sync pcc-app-of-apps-devtest`

**Troubleshooting Scenario 2: Child Application Manifests Not Discovered**
- **Symptoms**: Added child app YAML to `applications/devtest/` but argocd app resources shows empty
- **Root cause**: Auto-sync hasn't run (default 3 min interval) or child manifest has YAML syntax error
- **Diagnosis steps**:
  1. Check manifest syntax: `kubectl apply --dry-run=client -f applications/devtest/<filename>.yaml`
  2. Check root app refresh time: `argocd app get pcc-app-of-apps-devtest`
  3. Check controller logs: `kubectl -n argocd logs deployment/argocd-application-controller --tail=50 | grep -i "error\|failed"`
- **Resolution**:
  1. Fix YAML syntax errors in manifest
  2. Commit and push: `git add . && git commit -m "fix: correct child app manifest" && git push origin main`
  3. Manual sync root app: `argocd app sync pcc-app-of-apps-devtest`
  4. Wait 1-2 minutes, check discovery: `argocd app resources pcc-app-of-apps-devtest`

**Troubleshooting Scenario 3: Self-Heal Not Removing Manual Changes**
- **Symptoms**: Made kubectl changes to Application in cluster, changes persist despite selfHeal: true
- **Root cause**: Sync hasn't run since manual change (default 3 min) or Application health is degraded
- **Diagnosis steps**:
  1. Check last sync time: `argocd app get pcc-app-of-apps-devtest | grep "Last Sync"`
  2. Check application health: `argocd app get pcc-app-of-apps-devtest | grep "HEALTH"`
  3. Check if manual change still exists: `kubectl -n argocd get application pcc-app-of-apps-devtest -o yaml | grep manual-annotation`
- **Resolution**:
  1. Manual sync: `argocd app sync pcc-app-of-apps-devtest`
  2. If health is degraded, check resource health: `argocd app resources pcc-app-of-apps-devtest --orphaned`
  3. If issue persists, check application manifest syntax and reapply: `kubectl apply -f applications/root/app-of-apps-devtest.yaml`

**Module 3 Output**: Validation & Documentation Complete
- **Deliverable**: App-of-apps fully validated, comprehensive documentation created
- **Verification**: Sync status validated, troubleshooting procedures tested, docs committed
- **Phase 4.13 Complete**: App-of-apps pattern framework ready for Phase 6 child application deployment

---

**Deliverables**:
- App-of-apps root Application manifest created: `applications/root/app-of-apps-devtest.yaml`
- Repository directory structure: `applications/devtest/`, `applications/root/`
- Application deployed to prod ArgoCD and syncing
- Sync policies configured: auto-sync, prune, selfHeal, retry backoff
- Directory structure discovered and validated by ArgoCD
- Documentation: `.claude/docs/argocd-app-of-apps-pattern.md` committed to git
- Troubleshooting procedures tested and documented

**Dependencies**:
- Phase 4.12 complete (GitHub integration working, core/pcc-app-argo-config connected)
- ArgoCD CLI authenticated to prod instance (argocd-east4.pcconnect.ai)
- kubectl access to prod cluster (context: gke_pcc-prj-devops-prod_us-east4_pcc-gke-devops-prod)
- app-devtest cluster registered in ArgoCD (Phase 4.11 complete)
- Write access to core/pcc-app-argo-config repository (GitHub App permissions)
- git command-line tool for repository management and commits
- Verify ArgoCD auto-sync interval configured (default 3-5 minutes)
- Verify core/pcc-app-argo-config repository accessible and latest main branch available

---

#### Phase 4.14: Validate Full ArgoCD Deployment (45-60 min)

**Objective**: End-to-end validation of both ArgoCD clusters (nonprod & prod)

**⚠️ IMPORTANT for Claude Code Execution**: Before presenting ANY command block in this phase, Claude MUST explicitly remind the user: "Please open WARP terminal now to execute the following commands." Wait for user acknowledgment before proceeding with command presentation.

**Variable Substitutions**:
- Replace `ORG` with your GitHub organization name (e.g., `portcon-devops`, `myorg`, `company-name`)
- Replace cluster IPs with actual values from `argocd cluster list` or `kubectl cluster-info`
- Replace email addresses with your actual Google Workspace email domains

**Command Execution Notes**:
- Verify each command exits with code 0 (success) by checking `echo $?` after execution
- If command fails (exit code != 0), document error message and stop validation
- Commands showing "Expected Output" must match approximately - minor formatting differences acceptable
- Critical failures (SYNC STATUS != Synced, pods CrashLoopBackOff) are NO-GO blockers
- **Style Note**: All expected outputs use `# Expected Output:` comment format for consistency
- **Context Switching**: You may use `kubectl config use-context [name]` at section start to avoid repeating `--context` flag in every command

**Execution Structure**: Three sequential modules with 28-32 validation commands
1. **Module 1: Nonprod ArgoCD Validation** (10-12 min)
2. **Module 2: Prod ArgoCD Validation** (18-23 min)
3. **Module 3: Cross-Environment & Documentation** (7-10 min)

---

##### Module 1: Nonprod ArgoCD Validation (10-12 min)

**Section 1.0: Prerequisites Validation (CRITICAL)**

```bash
# CRITICAL: Verify ArgoCD CLI authentication (nonprod)
argocd context
# Expected Output: Current context shows argocd-nonprod-east4.pcconnect.ai

# Test authentication is valid
argocd app list
# Expected Output: Application list (not authentication error)
# If authentication fails, re-login:
# argocd login argocd-nonprod-east4.pcconnect.ai --sso
```

```bash
# CRITICAL: Verify nonprod kubectl context exists and is accessible
kubectl config get-contexts | grep gke_pcc-prj-devops-nonprod_us-east4_pcc-gke-devops-nonprod
# Expected Output: Context name in list

# Test context connectivity
kubectl --context=gke_pcc-prj-devops-nonprod_us-east4_pcc-gke-devops-nonprod get nodes
# Expected Output: Node list (validates cluster access)
# If context missing or fails: Check gcloud auth and GKE cluster status
```

**Section 1.1: Application Sync Validation**

```bash
# Verify hello-world application is synced
argocd app get hello-world-nonprod
# Expected Output:
# - SYNC STATUS: Synced
# - HEALTH STATUS: Healthy
# - REPO: https://github.com/ORG/pcc-app-argo-config.git
# - PATH: applications/nonprod/hello-world.yaml

# If SYNC STATUS != Synced, investigate:
if ! argocd app get hello-world-nonprod | grep -q "Sync Status:.*Synced"; then
  echo "⚠️  Application NOT synced, investigating..."
  argocd app sync-status hello-world-nonprod
  # Possible statuses:
  # - OutOfSync: Git source changed, manual sync may be needed
  # - Unknown: ArgoCD lost track, may need app refresh
  # - SyncFailed: Last sync attempt failed, check logs below

  # Check difference between Git and cluster
  argocd app diff hello-world-nonprod
  # Shows what changed in Git vs cluster state
fi
```

```bash
# Verify pods running in default namespace
kubectl get pods -n default -l app=hello-world --context=gke_pcc-prj-devops-nonprod_us-east4_pcc-gke-devops-nonprod
# Expected Output:
# STATUS=Running for all 3 replicas
# All containers READY 1/1
```

```bash
# Check pod details including image version
kubectl describe pod -n default -l app=hello-world --context=gke_pcc-prj-devops-nonprod_us-east4_pcc-gke-devops-nonprod | grep -E "Image:|State:|Ready"
# Expected Output:
# All pods in Running state, Ready=True
```

```bash
# CRITICAL: Verify app-of-apps exists in nonprod (if deployed for testing)
argocd app list | grep pcc-app-of-apps
# Expected Output: pcc-app-of-apps-nonprod if deployed, or no results if nonprod only tests hello-world
# Note: App-of-apps pattern is primarily validated in prod (Section 2.4)

# If app-of-apps exists in nonprod, validate it
if argocd app list | grep -q pcc-app-of-apps-nonprod; then
  echo "App-of-apps found in nonprod, validating..."
  argocd app get pcc-app-of-apps-nonprod
  # Expected: SYNC STATUS=Synced, HEALTH STATUS=Healthy
else
  echo "App-of-apps not deployed in nonprod (expected for minimal test environment)"
fi
```

**Section 1.2: Google SSO Authentication Test**

```bash
# Test 1: Verify OIDC provider configuration
argocd account can-i create applications --as gcp-developers@pcconnect.ai
# Expected Output: 'no' (developers group cannot create apps)

# Test 2: Verify devops group permissions
argocd account can-i create applications --as gcp-devops@pcconnect.ai
# Expected Output: 'yes' (devops group can create apps)
```

**Browser Manual Test** (2-3 min):
- Open: https://argocd-nonprod-east4.pcconnect.ai
- Login as: gcp-devops@pcconnect.ai
- Expected:
  - ✅ User profile in top-right shows email address (gcp-devops@pcconnect.ai)
  - ✅ "Applications" menu item visible in left sidebar
  - ✅ "Settings" menu shows "Repositories", "Clusters", "Projects" options
  - ✅ Can click "+ New App" button (button exists and enabled)

- Login as: gcp-developers@pcconnect.ai
- Expected:
  - ✅ User profile shows email address (gcp-developers@pcconnect.ai)
  - ✅ "Applications" menu visible but read-only (can view, not modify)
  - ✅ "Settings" menu GRAYED OUT or shows limited options only
  - ✅ "+ New App" button DOES NOT EXIST or is disabled/grayed out
  - ✅ Application cards show NO "Sync", "Delete", or "Refresh" buttons

**Section 1.3: RBAC Permission Boundary Verification**

```bash
# Verify developers role has read-only on applications
argocd account can-i get applications --as gcp-developers@pcconnect.ai
# Expected Output: 'yes' (read access allowed)

# Verify developers cannot sync applications
argocd account can-i sync applications --as gcp-developers@pcconnect.ai
# Expected Output: 'no' (sync denied)

# Verify developers cannot delete applications
argocd account can-i delete applications --as gcp-developers@pcconnect.ai
# Expected Output: 'no' (delete denied)

# Test namespace-specific permissions (per architecture decision 5)
argocd account can-i create applications 'pcc-devtest/*' --as gcp-developers@pcconnect.ai
# Expected Output: 'yes' (developers have admin in pcc-devtest namespace)

argocd account can-i create applications 'default/*' --as gcp-developers@pcconnect.ai
# Expected Output: 'no' (developers don't have admin in default namespace)

# Verify devops admin role has full access
argocd account can-i sync applications --as gcp-devops@pcconnect.ai
# Expected Output: 'yes' (devops can sync)

argocd account can-i delete applications --as gcp-devops@pcconnect.ai
# Expected Output: 'yes' (devops can delete)

argocd account can-i update applications --as gcp-devops@pcconnect.ai
# Expected Output: 'yes' (devops can update)

# Test project-level permissions
argocd proj role list default
# Expected Output: Role definitions for default project (if custom roles configured)
```

**Section 1.4: Ingress & SSL/DNS Validation**

```bash
# Check HTTP response code (should redirect to SSO or return 200)
curl -k -s -o /dev/null -w "%{http_code}\n" https://argocd-nonprod-east4.pcconnect.ai
# Expected Output: 302 (redirect) or 200

# Verify SSL certificate details
openssl s_client -connect argocd-nonprod-east4.pcconnect.ai:443 </dev/null 2>/dev/null | grep -E "subject=|issuer=|notAfter"
# Expected Output:
# - subject=CN=argocd-nonprod-east4.pcconnect.ai
# - issuer=Google Cloud (or Let's Encrypt if not Google-managed)
```

```bash
# Verify LoadBalancer ingress is deployed
kubectl get ingress -n argocd --context=gke_pcc-prj-devops-nonprod_us-east4_pcc-gke-devops-nonprod
# Expected Output:
# - CLASS: gce
# - HOSTS: argocd-nonprod-east4.pcconnect.ai
# - STATUS: Has external IP assigned
```

---

##### Module 2: Prod ArgoCD Validation (18-23 min)

**Section 2.0: Prerequisites Validation (CRITICAL)**

```bash
# CRITICAL: Verify ArgoCD CLI authentication (prod)
argocd context
# Expected Output: Current context shows argocd-east4.pcconnect.ai

# Test authentication is valid
argocd app list
# Expected Output: Application list including pcc-app-of-apps-devtest (not authentication error)
# If authentication fails, re-login:
# argocd login argocd-east4.pcconnect.ai --sso
```

```bash
# CRITICAL: Verify prod kubectl context exists and is accessible
kubectl config get-contexts | grep gke_pcc-prj-devops-prod_us-east4_pcc-gke-devops-prod
# Expected Output: Context name in list

# Test context connectivity
kubectl --context=gke_pcc-prj-devops-prod_us-east4_pcc-gke-devops-prod get nodes
# Expected Output: Node list (validates cluster access)

# CRITICAL: Verify app-devtest cluster context also exists (for workload validation)
kubectl config get-contexts | grep gke_pcc-prj-devops-devtest_us-east4_pcc-gke-app-devtest
# Expected Output: Context name in list
```

**Section 2.1: HA Pod Health Verification (CRITICAL)**

```bash
# Get all ArgoCD pods across all replicas
kubectl -n argocd get pods --context=gke_pcc-prj-devops-prod_us-east4_pcc-gke-devops-prod
# Expected Output: 14-16 pods (prod HA configuration)
# Core Components (14 pods):
# - 3x argocd-server (api server replicas)
# - 2x argocd-repo-server (git sync replicas)
# - 1x argocd-application-controller (stateful)
# - 2x argocd-dex-server (SSO provider replicas)
# - 1x argocd-applicationset-controller
# - 1x argocd-notifications-controller
# - 3x redis-ha-server (Redis HA leader + replicas)
# - 3x redis-ha-haproxy (HAProxy for Redis)
# Optional Components (may add 1-2 pods):
# - argocd-redis-ha-sentinel (if sentinel enabled)
# All pods STATUS=Running
```

```bash
# Count exact number of pods (must be >= 14)
kubectl -n argocd get pods --no-headers --context=gke_pcc-prj-devops-prod_us-east4_pcc-gke-devops-prod | wc -l
# Expected Output: 14 or higher

# Verify all pods ready
kubectl -n argocd get pods -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' --context=gke_pcc-prj-devops-prod_us-east4_pcc-gke-devops-prod | grep -o 'True' | wc -l
# Expected Output: 14 or higher (all pods ready)
```

```bash
# CRITICAL: Verify resource limits set on all pods (prevents OOM kills and resource starvation)
echo "Checking resource limits for all ArgoCD pods..."
kubectl -n argocd get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].resources.limits}{"\n"}{end}' --context=gke_pcc-prj-devops-prod_us-east4_pcc-gke-devops-prod | head -10
# Expected Output: Each pod shows memory and CPU limits (not empty objects {})
# Example: argocd-server-xxx    map[cpu:500m memory:256Mi]

# Identify pods WITHOUT resource limits (should be NONE)
PODS_NO_LIMITS=$(kubectl -n argocd get pods -o json --context=gke_pcc-prj-devops-prod_us-east4_pcc-gke-devops-prod | jq -r '.items[] | select(.spec.containers[].resources.limits == null) | .metadata.name')
if [ -z "$PODS_NO_LIMITS" ]; then
  echo "✅ All pods have resource limits configured"
else
  echo "⚠️  WARNING: Pods without resource limits:"
  echo "$PODS_NO_LIMITS"
  echo "Production risk: These pods can consume excessive resources and cause instability"
fi
```

**Section 2.2: Cluster Management Validation**

```bash
# List registered clusters
argocd cluster list
# Expected Output:
# - https://kubernetes.default.svc (in-cluster, prod ArgoCD itself)
# - https://[app-devtest-cluster-ip]:443 (app-devtest cluster, STATUS=Successful)
# All show Connection Status=Successful
```

```bash
# Verify app-devtest cluster is healthy
kubectl get nodes --context=gke_pcc-prj-devops-devtest_us-east4_pcc-gke-app-devtest
# Expected Output:
# - 3 nodes in STATUS=Ready
# - All nodes show ROLES=<none> or custom roles
```

```bash
# CRITICAL: Test actual deployment capability on app-devtest cluster
kubectl --context=gke_pcc-prj-devops-devtest_us-east4_pcc-gke-app-devtest auth can-i create deployments
# Expected Output: yes (validates ArgoCD service account permissions)

# Check cluster certificate expiration and connection freshness
argocd cluster get app-devtest -o json | jq -r '.connectionState.attemptedAt'
# Expected Output: Recent timestamp (within last 5 minutes = active connection)
# If timestamp > 10 minutes old: Connection may be stale, test with argocd cluster get --refresh

# Verify network latency acceptable (nodes reachable from ArgoCD cluster)
kubectl --context=gke_pcc-prj-devops-devtest_us-east4_pcc-gke-app-devtest get nodes -o wide | awk '{print $1,$6}'
# Expected Output: Node names and internal IPs
# Note: Validate IPs are in expected VPC range (10.x.x.x for private GKE)
```

**Section 2.3: GitHub Repository Integration Test**

```bash
# List connected repositories
argocd repo list
# Expected Output:
# - https://github.com/ORG/pcc-app-argo-config.git
# - TYPE: git
# - STATUS: Successful (both repo-server replicas connected)
```

```bash
# Test repo connectivity with refresh
argocd repo get https://github.com/ORG/pcc-app-argo-config.git --refresh
# Expected Output:
# - Connection Status: Successful
# - Latest commit hash from main branch
```

```bash
# Verify both repo-server replicas serving requests
kubectl -n argocd logs -l app.kubernetes.io/name=argocd-repo-server --tail=5 --context=gke_pcc-prj-devops-prod_us-east4_pcc-gke-devops-prod | grep -i "git\|sync"
# Expected Output: Recent successful git sync messages from both replicas
```

```bash
# Check if repository has webhook configured (enables automatic sync on git push)
argocd repo get https://github.com/ORG/pcc-app-argo-config.git -o json | jq -r '.webhookSecret'
# Expected Output: Webhook secret value (not null) or note if not configured
# If null: Webhooks NOT configured - manual sync required for every git push
# Recommendation: Configure webhooks for automatic GitOps sync triggers
```

**Section 2.4: App-of-Apps Framework Validation**

```bash
# Get app-of-apps root application status
argocd app get pcc-app-of-apps-devtest
# Expected Output:
# - SYNC STATUS: Synced
# - HEALTH STATUS: Healthy
# - REPO: https://github.com/ORG/pcc-app-argo-config.git
# - PATH: applications/root/

# If SYNC STATUS != Synced, investigate:
if ! argocd app get pcc-app-of-apps-devtest | grep -q "Sync Status:.*Synced"; then
  echo "⚠️  App-of-apps NOT synced, investigating..."
  argocd app sync-status pcc-app-of-apps-devtest
  argocd app diff pcc-app-of-apps-devtest
  echo "Check application controller logs for sync errors:"
  kubectl -n argocd logs -l app.kubernetes.io/name=argocd-application-controller --tail=100 | grep pcc-app-of-apps
fi
```

```bash
# Verify Application CRD exists
kubectl -n argocd get application pcc-app-of-apps-devtest --context=gke_pcc-prj-devops-prod_us-east4_pcc-gke-devops-prod
# Expected Output:
# - NAME: pcc-app-of-apps-devtest
# - Exists and is in Synced state
```

```bash
# Check application controller is managing the resource
kubectl -n argocd get application pcc-app-of-apps-devtest -o jsonpath='{.status.sync.status}' --context=gke_pcc-prj-devops-prod_us-east4_pcc-gke-devops-prod
# Expected Output: Synced
```

```bash
# Verify application has proper finalizers (ensures cascade delete of child resources)
kubectl -n argocd get application pcc-app-of-apps-devtest -o jsonpath='{.metadata.finalizers}' --context=gke_pcc-prj-devops-prod_us-east4_pcc-gke-devops-prod
# Expected Output: ["resources-finalizer.argocd.argoproj.io"]
# This ensures when application is deleted, child resources are cleaned up properly
# If missing finalizer: Orphaned resources will remain in target cluster after app deletion
```

```bash
# Verify Application CRD version matches ArgoCD version (compatibility check)
kubectl get crd applications.argoproj.io -o jsonpath='{.spec.versions[*].name}' --context=gke_pcc-prj-devops-prod_us-east4_pcc-gke-devops-prod
# Expected Output: v1alpha1 (current ArgoCD API version)

# Check ArgoCD server version for comparison
kubectl -n argocd exec -it deployment/argocd-server --context=gke_pcc-prj-devops-prod_us-east4_pcc-gke-devops-prod -- argocd version | grep server
# Expected Output: Server version matching installed Helm chart (e.g., v2.10.x)
# Versions should be compatible - major version mismatch indicates upgrade issue
```

**Section 2.5: Google SSO Authentication Test (Prod)**

```bash
# Verify OIDC provider configured for prod
argocd account can-i create applications --as gcp-developers@pcconnect.ai
# Expected Output: 'no' (developers read-only)

# Verify prod devops admin access
argocd account can-i create applications --as gcp-devops@pcconnect.ai
# Expected Output: 'yes'
```

**Browser Manual Test** (Prod URL):
- Open: https://argocd-east4.pcconnect.ai
- Login as: gcp-devops@pcconnect.ai
- Expected: Successfully authenticated, sees full admin UI, can access Application menu
- Login as: gcp-developers@pcconnect.ai
- Expected: Successfully authenticated, read-only mode (no create/sync/delete buttons)

**Section 2.6: RBAC Permission Verification (Prod)**

```bash
# Verify developers can read but not modify
argocd account can-i get applications --as gcp-developers@pcconnect.ai
# Expected Output: 'yes'

argocd account can-i delete applications --as gcp-developers@pcconnect.ai
# Expected Output: 'no'

# Verify devops full access
argocd account can-i sync applications --as gcp-devops@pcconnect.ai
# Expected Output: 'yes'

argocd account can-i update applications --as gcp-devops@pcconnect.ai
# Expected Output: 'yes'
```

**Section 2.7: Ingress/SSL/DNS Validation (Prod)**

```bash
# Verify prod LoadBalancer ingress
kubectl get ingress -n argocd --context=gke_pcc-prj-devops-prod_us-east4_pcc-gke-devops-prod
# Expected Output:
# - CLASS: gce
# - HOSTS: argocd-east4.pcconnect.ai
# - STATUS: Has external IP assigned, ready to receive traffic
```

```bash
# Verify backend service has healthy endpoints (ingress routing to live pods)
kubectl -n argocd get endpoints argocd-server --context=gke_pcc-prj-devops-prod_us-east4_pcc-gke-devops-prod
# Expected Output: At least 3 endpoint IPs (matching argocd-server pod count in HA setup)
# If 0 endpoints: Service not routing to any pods - ingress will return 502/503

# Check GCE backend service health (if using GKE Ingress)
gcloud compute backend-services list --filter="name~argocd" --format="value(name,healthChecks)"
# Expected Output: Backend service name with associated health check URL
# Note: GCE health checks should show backends as HEALTHY in Cloud Console
```

```bash
# Test prod HTTPS endpoint
curl -k -s -o /dev/null -w "%{http_code}\n" https://argocd-east4.pcconnect.ai
# Expected Output: 302 (SSO redirect) or 200

# Verify SSL cert validity
openssl s_client -connect argocd-east4.pcconnect.ai:443 </dev/null 2>/dev/null | grep -E "subject=|notAfter"
# Expected Output:
# - subject=CN=argocd-east4.pcconnect.ai
# - Certificate validity > 30 days
```

```bash
# Set up certificate expiration monitoring (critical operational requirement)
# Option 1: GCP Certificate Manager notification (if using Google-managed certs)
gcloud certificate-manager certificates list --filter="domains:argocd-east4.pcconnect.ai" --format="value(name,expireTime)"
# Expected Output: Certificate name and expiration date (should be > 30 days from now)

# Option 2: Manual monitoring alert recommendation (document in runbook)
echo "📋 Certificate Monitoring Recommendation:"
echo "Configure alert when certificate has < 30 days remaining"
echo "Alert should notify gcp-devops@pcconnect.ai via email/Slack"
echo "Alert source: GCP Certificate Manager or external monitoring (UptimeRobot, StatusCake)"
```

**Section 2.8: Redis HA & Backup Chain Verification**

```bash
# CRITICAL: Check Redis master election (must be exactly ONE master)
echo "Checking Redis pod 0..."
kubectl -n argocd exec redis-ha-server-0 --context=gke_pcc-prj-devops-prod_us-east4_pcc-gke-devops-prod -- redis-cli info replication | grep "role:master" && echo "✅ Pod 0 is MASTER" || echo "Pod 0 is slave"

echo "Checking Redis pod 1..."
kubectl -n argocd exec redis-ha-server-1 --context=gke_pcc-prj-devops-prod_us-east4_pcc-gke-devops-prod -- redis-cli info replication | grep "role:master" && echo "✅ Pod 1 is MASTER" || echo "Pod 1 is slave"

echo "Checking Redis pod 2..."
kubectl -n argocd exec redis-ha-server-2 --context=gke_pcc-prj-devops-prod_us-east4_pcc-gke-devops-prod -- redis-cli info replication | grep "role:master" && echo "✅ Pod 2 is MASTER" || echo "Pod 2 is slave"

# Expected Output: Exactly ONE pod shows "✅ ... is MASTER", other TWO show "... is slave"
# If multiple masters or no master: CRITICAL ISSUE - Redis split-brain or no leader elected
```

```bash
# Verify master has 2 connected slaves
MASTER_POD=$(kubectl -n argocd get pods -l app=redis-ha-server --context=gke_pcc-prj-devops-prod_us-east4_pcc-gke-devops-prod -o name | while read pod; do kubectl -n argocd exec $pod --context=gke_pcc-prj-devops-prod_us-east4_pcc-gke-devops-prod -- redis-cli info replication | grep -q "role:master" && echo $pod && break; done)
kubectl -n argocd exec $MASTER_POD --context=gke_pcc-prj-devops-prod_us-east4_pcc-gke-devops-prod -- redis-cli info replication | grep "connected_slaves"
# Expected Output: connected_slaves:2
```

```bash
# Verify all Redis replicas are connected
kubectl -n argocd get pods -l app=redis-ha-server --context=gke_pcc-prj-devops-prod_us-east4_pcc-gke-devops-prod -o wide
# Expected Output:
# - 3 redis-ha-server pods (one master, two slaves)
# - All in Running state
```

```bash
# CRITICAL: Verify Redis persistence is enabled (data survives pod restarts)
kubectl -n argocd exec redis-ha-server-0 --context=gke_pcc-prj-devops-prod_us-east4_pcc-gke-devops-prod -- redis-cli config get save
# Expected Output: RDB save intervals configured (e.g., "900 1 300 10" means save after 900s if 1 key changed, etc.)
# If "save" returns empty: NO PERSISTENCE - all data lost on pod restart

# Check AOF (Append-Only File) persistence
kubectl -n argocd exec redis-ha-server-0 --context=gke_pcc-prj-devops-prod_us-east4_pcc-gke-devops-prod -- redis-cli config get appendonly
# Expected Output: "appendonly" "yes" or "appendonly" "everysec"
# AOF provides better durability than RDB snapshots
# If "no": Only RDB snapshots for persistence (less durable)
```

```bash
# List GCS backups directory
gsutil ls gs://pcc-argocd-prod-backups/
# Expected Output:
# - Backup files with timestamps (e.g., argocd-backup-2025-10-23-*)
# - At least one backup from today or yesterday
```

```bash
# CRITICAL: Validate backup file integrity (disaster recovery readiness)
LATEST_BACKUP=$(gsutil ls gs://pcc-argocd-prod-backups/ | sort | tail -1)
echo "Testing backup integrity: $LATEST_BACKUP"

# Download and inspect backup structure
gsutil cat $LATEST_BACKUP | tar -tzf - | head -10
# Expected Output: File list showing argocd-backup/ directory structure
# Files should include: applications/, repositories/, secrets/ subdirectories

# Verify backup content is valid YAML/JSON (not corrupted)
gsutil cat $LATEST_BACKUP | tar -xzf - -O argocd-backup/applications/*.yaml 2>/dev/null | head -c 500
# Expected Output: Valid YAML content starting with "apiVersion: argoproj.io"
# If binary garbage or empty: CRITICAL - backups are corrupted

# Document restore procedure (manual test in nonprod recommended before production need)
echo "✅ Backup integrity validated. Restore procedure documented in DR section."
# Full restore testing: Download backup, apply to nonprod cluster, verify applications restored
```

```bash
# Verify backup lifecycle policy exists (prevents bucket bloat and cost overruns)
gsutil lifecycle get gs://pcc-argocd-prod-backups/
# Expected Output: Lifecycle rule deleting backups older than 30 days
# If no lifecycle: CRITICAL - backups will accumulate indefinitely, increasing costs

# Count total backups (should not exceed reasonable number)
BACKUP_COUNT=$(gsutil ls gs://pcc-argocd-prod-backups/ | wc -l)
echo "Total backups in bucket: $BACKUP_COUNT"
# Expected Output: < 60 backup files (assuming daily backups with 30-day retention = ~30 backups)
# If > 100 backups: Lifecycle policy NOT working or retention too long
```

**Section 2.9: Monitoring & Alerting Validation (CRITICAL)**

```bash
# CRITICAL: Verify ArgoCD metrics are being collected (Prometheus integration)
kubectl -n argocd get servicemonitor
# Expected Output: ArgoCD ServiceMonitor resources if using Prometheus
# If no ServiceMonitors: Monitoring NOT configured - CRITICAL operational gap

# Check application controller logs for errors (last 50 lines)
kubectl -n argocd logs -l app.kubernetes.io/name=argocd-application-controller --tail=50 --context=gke_pcc-prj-devops-prod_us-east4_pcc-gke-devops-prod | grep -i error
# Expected Output: No CRITICAL errors in last 50 lines
# Acceptable: Info-level or transient connection errors
# NOT acceptable: Repeated sync failures, authentication errors, or crash messages
```

```bash
# Verify notification controller is running (for alerts)
kubectl -n argocd get pods -l app.kubernetes.io/name=argocd-notifications-controller --context=gke_pcc-prj-devops-prod_us-east4_pcc-gke-devops-prod
# Expected Output: 1 pod Running
# Status: Check if notifications configured in argocd-notifications-cm ConfigMap

# Check notifications ConfigMap exists
kubectl -n argocd get configmap argocd-notifications-cm --context=gke_pcc-prj-devops-prod_us-east4_pcc-gke-devops-prod
# Expected Output: ConfigMap exists
# Note: Contents should be reviewed to verify alert triggers configured
```

```bash
# Verify ArgoCD server is exposing metrics endpoint
kubectl -n argocd get service argocd-metrics --context=gke_pcc-prj-devops-prod_us-east4_pcc-gke-devops-prod
# Expected Output: Service exists on port 8082
# If missing: Metrics collection NOT available - monitoring gap

# Test metrics endpoint accessibility
kubectl -n argocd port-forward svc/argocd-metrics 8082:8082 --context=gke_pcc-prj-devops-prod_us-east4_pcc-gke-devops-prod &
sleep 2
curl -s http://localhost:8082/metrics | head -5
pkill -f "port-forward svc/argocd-metrics"
# Expected Output: Prometheus format metrics (argocd_app_info, argocd_app_sync_total, etc.)
```

**Section 2.10: Network Security Validation (CRITICAL)**

```bash
# Check for NetworkPolicy resources
kubectl -n argocd get networkpolicy --context=gke_pcc-prj-devops-prod_us-east4_pcc-gke-devops-prod
# Expected Output: NetworkPolicy resources if configured (or note if using GKE Dataplane V2 network policies)
# If no policies: Document security posture relies on GKE network isolation

# Verify argocd-server only accepts traffic on expected ports
kubectl -n argocd get service argocd-server --context=gke_pcc-prj-devops-prod_us-east4_pcc-gke-devops-prod -o jsonpath='{.spec.ports[*].port}'
# Expected Output: 80 443 (standard HTTP/HTTPS only)
# If additional ports exposed: Investigate whether required or security gap
```

---

##### Module 3: Cross-Environment & Documentation (7-10 min)

**Section 3.1: Nonprod/Prod Consistency Validation**

```bash
# Verify RBAC policies match (both environments use same groups)
argocd account list  # Run on both nonprod and prod clusters
# Expected Output: Identical RBAC configuration on both:
# - gcp-developers: read access, limited sync
# - gcp-devops: admin access
```

**Section 3.2: Create Access Procedures Documentation**

Create file: `.claude/docs/argocd-access-procedures.md`

```markdown
# ArgoCD Access Procedures

## Nonprod Environment
- **URL**: https://argocd-nonprod-east4.pcconnect.ai
- **Purpose**: Testing ArgoCD upgrades, configuration changes
- **SSO Groups**: gcp-developers@pcconnect.ai, gcp-devops@pcconnect.ai
- **RBAC**: Same as prod (developers=read-only, devops=admin)

## Prod Environment
- **URL**: https://argocd-east4.pcconnect.ai
- **Purpose**: Managing application clusters (app-devtest, future app-staging/prod)
- **SSO Groups**: gcp-developers@pcconnect.ai, gcp-devops@pcconnect.ai
- **RBAC**:
  - gcp-developers@pcconnect.ai: view role (read-only)
  - gcp-devops@pcconnect.ai: admin role (full access)

## SSH Key Access
For CLI access without browser SSO:
```bash
argocd login argocd-east4.pcconnect.ai --sso --sso-port 8085
```

## Troubleshooting SSO
If SSO login fails:
1. Verify Google Cloud Workspace group membership: console.cloud.google.com
2. Clear browser cookies and cache
3. Verify Dex pods are running: kubectl -n argocd get pods -l app=dex-server

## Emergency Access (SSO Unavailable)
If Google SSO is completely unavailable or broken:

**1. Port-forward to ArgoCD server** (bypasses ingress/SSO):
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443 --context=gke_pcc-prj-devops-prod_us-east4_pcc-gke-devops-prod
```

**2. Retrieve admin password**:
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" --context=gke_pcc-prj-devops-prod_us-east4_pcc-gke-devops-prod | base64 -d
```

**3. Login with admin credentials**:
```bash
argocd login localhost:8080 --username admin --password [retrieved-password] --insecure
```

**⚠️ CRITICAL**:
- Change admin password immediately after emergency access
- Document access in incident report with timestamp and reason
- Re-enable SSO as soon as issue resolved
- This is break-glass access only - NOT for normal operations
```

**Section 3.3: Create Upgrade Workflow Documentation**

Create file: `.claude/docs/argocd-upgrade-workflow.md`

```markdown
# ArgoCD Upgrade Testing Workflow

## Workflow: Nonprod Testing → Prod Deployment

### Prerequisites
- ArgoCD CLI authenticated to both clusters
- kubectl access to both clusters
- Helm installed locally

### Testing Phase (Nonprod)
1. Update Helm chart version in values.yaml
2. Test in nonprod: `helm upgrade argocd argocd/argo-cd -f nonprod-values.yaml -n argocd`
3. Validate all pods running: `kubectl -n argocd get pods`
4. Run Phase 4.14 validation checklist (Section 3.4)
5. Document any issues or compatibility notes

### Deployment Phase (Prod)
1. Review nonprod validation results
2. Schedule prod maintenance window (off-peak hours)
3. Backup Redis: `kubectl -n argocd exec redis-ha-server-0 -- redis-cli BGSAVE`
4. Deploy to prod: `helm upgrade argocd argocd/argo-cd -f prod-values.yaml -n argocd`
5. Monitor: `kubectl -n argocd logs -f deployment/argocd-application-controller`
6. Verify: Run Phase 4.14 validation checklist (Section 3.4)
7. Rollback procedure if needed (documented separately)

### Rollback Procedure
If upgrade validation fails, execute rollback within 15 minutes:

**1. Identify Previous Version**:
```bash
helm history argocd -n argocd
# Note revision number of last successful deployment
```

**2. Execute Rollback**:
```bash
helm rollback argocd [REVISION] -n argocd
# Example: helm rollback argocd 3 -n argocd
# Expected Output: Release rolled back successfully
```

**3. Verify Rollback Success**:
```bash
kubectl -n argocd get pods
# All pods should return to Running state within 2-3 minutes
# Count pods to ensure all returned: kubectl -n argocd get pods --no-headers | wc -l
```

**4. Test Application Sync**:
```bash
argocd app sync pcc-app-of-apps-devtest
# Verify applications still sync correctly after rollback
# Expected: Sync completes with STATUS=Synced
```

**5. Restore Redis from Backup** (if data corruption occurred):
```bash
# Retrieve latest pre-upgrade backup
gsutil ls gs://pcc-argocd-prod-backups/ | grep "$(date +%Y-%m-%d)" | tail -1

# WARNING: This flushes all Redis data - only use if corruption confirmed
kubectl -n argocd exec redis-ha-server-0 -- redis-cli FLUSHALL
# Then restore from backup (detailed procedure: extract tar, apply YAML manifests)
```

**6. Document Rollback**:
Update phase-4-working-notes.md with:
- Rollback timestamp
- Failure reason and symptoms
- Revision rolled back from/to
- Lessons learned for next upgrade attempt
```

**Section 3.4: Final Acceptance Checklist**

**GO Criteria (All must pass)**:
- ✅ Nonprod hello-world app SYNC STATUS=Synced, HEALTH STATUS=Healthy
- ✅ Nonprod SSO login successful for gcp-developers@pcconnect.ai and gcp-devops@pcconnect.ai
- ✅ Nonprod RBAC verified: gcp-developers cannot create apps, gcp-devops can
- ✅ Nonprod LoadBalancer ingress responding (HTTP 302 or 200)
- ✅ Prod HA deployment: 14+ pods all Running/Ready
- ✅ Prod app-devtest cluster registered, STATUS=Successful
- ✅ Prod GitHub repository integration: https://github.com/ORG/pcc-app-argo-config.git healthy
- ✅ Prod pcc-app-of-apps-devtest SYNC STATUS=Synced, HEALTH STATUS=Healthy
- ✅ Prod SSO login successful for both groups, RBAC enforced
- ✅ Prod LoadBalancer ingress responding (HTTP 302 or 200)
- ✅ Prod Redis HA replication: 3 pods (1 master + 2 slaves) all healthy
- ✅ Prod GCS backups: gs://pcc-argocd-prod-backups/ contains recent backups
- ✅ Access procedures documented in `.claude/docs/argocd-access-procedures.md`
- ✅ Upgrade workflow documented in `.claude/docs/argocd-upgrade-workflow.md`

**NO-GO Criteria (Phase 4.14 blocks Phase 5)**:
- Pod STATUS != Running in either environment
- SYNC STATUS != Synced in any application
- HEALTH STATUS != Healthy in any pod
- SSO login fails (returns 401 or login page stuck)
- RBAC permissions inverted (developers have admin, devops denied)
- app-devtest cluster shows STATUS=Unknown or offline
- GitHub repository shows STATUS=Failed or offline
- Any critical pod is CrashLoopBackOff or Failed state
- SSL certificate invalid or expired (< 30 days remaining)
- Redis replication shows disconnected_slaves > 0

**Deliverables** (Store in repo):
- Nonprod ArgoCD validated (all 4 modules passed)
- Prod ArgoCD validated (all 8 modules passed)
- Cross-environment consistency verified
- Documentation files created:
  - `.claude/docs/argocd-access-procedures.md`
  - `.claude/docs/argocd-upgrade-workflow.md`
- Final acceptance checklist signed off (all boxes ticked)
- Validation summary added to `phase-4-working-notes.md` completion section

**Dependencies**:
- Phase 4.13 complete: pcc-app-of-apps-devtest Application exists and syncs (Section 2.4 validates this)
- Phase 4.12 complete: GitHub repo connected with Workload Identity authentication (Section 2.3 validates this)
- Phase 4.11 complete: Backup CronJob running and GCS bucket accessible (Section 2.8 validates this)
- Phase 4.12 complete: GitHub integration working in prod (Section 2.3 tests repository connectivity)
- Phase 4.11 complete: app-devtest cluster registered in prod ArgoCD (Section 2.2 validates registration)
- ArgoCD CLI authenticated to both nonprod and prod instances
- kubectl access to all 3 clusters via gcloud/Connect Gateway
- Browser access for manual SSO testing (Chrome/Firefox)
- Network connectivity to argocd-nonprod-east4.pcconnect.ai and argocd-east4.pcconnect.ai
- gcloud CLI configured with appropriate project context
- GCS read access for backup verification (gsutil)
- Helm CLI installed (version >= 3.10)

---

## Key Architecture Decisions

1. **Nonprod Role**: ONLY for testing ArgoCD upgrades/configuration (does NOT manage any clusters)
2. **Prod Role**: Manages all application clusters (app-devtest in Phase 4, future app-staging/app-prod later)
3. **Public Ingress**: Both clusters get public LoadBalancer with Google SSO authentication (NOT internal-only)
4. **DNS Naming** (regional for future Active/Active):
   - Nonprod: `argocd-nonprod-east4.pcconnect.ai`
   - Prod: `argocd-east4.pcconnect.ai`
5. **RBAC** (namespace-aware, two groups configured from start):
   - gcp-developers@pcconnect.ai:
     - Default: `view` role (read-only on most namespaces)
     - Exception: `admin` role in `pcc-devtest` namespace only
   - gcp-devops@pcconnect.ai: `admin` role on all namespaces
6. **Ingress Controller**: GKE Ingress with Google-managed SSL certificates
7. **Security**: Cloud Armor for DDoS protection, TLS 1.2+ enforced
8. **Test App**: Hello-world deployed to nonprod for validation
9. **Repository Scope**: Only `core/pcc-app-argo-config` in Phase 4 (no infra repos yet)
10. **App-of-Apps**: Framework only in Phase 4, populated with actual apps in Phase 6+
11. **Cluster Registration**: Automated via `argocd cluster add` for app-devtest
12. **HA Configuration**: Nonprod single-replica, Prod multi-replica with Redis HA (requires terraform)

---

## Scope Boundaries

**In Scope for Phase 4**:
- ArgoCD installation on both clusters
- Google SSO integration
- RBAC configuration (2 groups)
- Public ingress (LoadBalancer)
- GitHub integration (`core/pcc-app-argo-config` only)
- Cluster registration (app-devtest only)
- App-of-apps framework
- Hello-world test app (nonprod)

**Out of Scope for Phase 4** (Deferred to Later Phases):
- Namespace `pcc-devtest` creation (Phase 6)
- Service-specific applications (Phase 6+)
- Workload Identity bindings for services (Phase 6)
- Additional repository connections (`infra/*` repos)
- Staging/production cluster registration (future)
- Monitoring/alerting integration

---

## Dependencies from Phase 3

**Prerequisites** (must be complete):
- ✅ 3 GKE clusters operational (devops-nonprod, devops-prod, app-devtest)
- ✅ 2 ArgoCD service accounts created:
  - argocd-controller@pcc-prj-devops-nonprod.iam.gserviceaccount.com
  - argocd-controller@pcc-prj-devops-prod.iam.gserviceaccount.com
- ✅ Cross-project IAM bindings applied:
  - ArgoCD SAs have container.admin on all 3 clusters
  - ArgoCD SAs have gkehub.gatewayAdmin for Connect Gateway access
- ✅ kubectl contexts configured via Connect Gateway

---

## Subagent Review Status

**Review Method**: Run each subphase through agent-organizer for team feedback

**Subphases Reviewed**:
- [x] Phase 4.1: Core Architecture Planning (REVIEWED - feedback incorporated)
- [x] Phase 4.2: Security and Access Planning (REVIEWED - 8 issues: 1 CRITICAL, 3 HIGH, 4 MEDIUM - incorporated with adjustments: sync OK for devs, 90-day audit retention)
- [x] Phase 4.3: Repository and Integration Planning (REVIEWED - 8 issues: 2 CRITICAL, 3 HIGH, 3 MEDIUM - corrections applied: GitHub App + Workload Identity, Google Cloud Observability, quarterly rotation, 7 alert thresholds)
- [x] Phase 4.4: Plan ArgoCD Installation Configuration (REVIEWED - 8 issues: 3 CRITICAL, 3 HIGH, 2 MEDIUM - incorporated)
- [x] Phase 4.5: Create Terraform for ArgoCD GCP Resources (REVIEWED - key decisions documented)
- [x] Phase 4.7: Install ArgoCD on Devops Nonprod Cluster (REVIEWED - 25 original issues RESOLVED, 6 minor cosmetic issues fixed - POLISHED, production-ready)
- [x] Phase 4.8: Configure & Test ArgoCD Nonprod (REVIEWED - 23 original issues RESOLVED, 5 minor LOW-severity issues fixed - POLISHED, GO recommendation)
- [ ] Phase 4.10: Install ArgoCD on Devops Prod Cluster
- [ ] Phase 4.11: Configure Cluster Management (Prod)
- [ ] Phase 4.12: Configure GitHub Integration
- [ ] Phase 4.13: Configure App-of-Apps Pattern
- [ ] Phase 4.14: Validate Full ArgoCD Deployment

---

## Next Steps

1. Review Phase 4.1 with agent-organizer (careful scoping)
2. Incorporate feedback
3. Continue through remaining subphases
4. Create individual phase documents after review complete
