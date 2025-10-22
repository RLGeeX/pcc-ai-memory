# Phase 4 Working Notes: ArgoCD Dual-Cluster Deployment

**Status**: Planning - Subagent Review in Progress
**Date**: 2025-10-22
**Scope**: Deploy ArgoCD to both devops-nonprod and devops-prod clusters

---

## Overview

**Total Subphases**: 12 (updated after Phase 4.1 and 4.2 splits)
**Strategy**: Test in nonprod → validate → deploy to prod
**Key Decision**: Nonprod ArgoCD is for testing ArgoCD itself (upgrades/config), Prod ArgoCD manages all application clusters

**Phase Numbering**:
- Planning: 4.1A, 4.1B, 4.1C, 4.2A, 4.2B (5 subphases)
- Nonprod Deployment: 4.3, 4.4 (2 subphases)
- Prod Deployment: 4.5, 4.6 (2 subphases)
- GitHub Integration & App-of-Apps: 4.7, 4.8, 4.9 (3 subphases)

**DNS Naming** (regional for future Active/Active):
- Nonprod: `argocd-nonprod-east4.pcconnect.ai`
- Prod: `argocd-east4.pcconnect.ai`

---

## Subphase Breakdown

### Planning Phases (4 subphases)

#### Phase 4.1A: Core Architecture Planning (15-20 min)

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
- Phase 3 complete (3 GKE clusters operational)
- ArgoCD service accounts created with IAM bindings (Phase 3)
- Connect Gateway configured (Phase 3)

---

#### Phase 4.1B: Security and Access Planning (15-20 min)

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
- Phase 4.1A complete (architecture defined)
- Google Workspace admin access available
- DNS zone management access available
- Secret Manager permissions in devops-nonprod and devops-prod projects
- Cloud KMS key for admin password encryption
- BigQuery dataset in pcc-prj-logging-monitoring for audit logs

---

#### Phase 4.1C: Repository and Integration Planning (10-15 min)

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
    - Retention: 7 days (rolling window)
    - Restore procedure: Create new PVC from snapshot, update Redis StatefulSet volume claim
  - **Disaster recovery procedure**:
    1. Restore ArgoCD Helm deployment to new cluster (Phase 4.3/4.5 procedure)
    2. Restore Redis PVC from latest snapshot (prod only)
    3. Reconfigure GitHub App credentials from Secret Manager
    4. ArgoCD auto-syncs applications from Git repository
  - **Regional failover plan**: Future Active/Active with west region (Phase 5+)

**Deliverables**:
- Repository connection strategy document (GitHub App + Workload Identity, read-only access)
- Secret management approach (Secret Manager for GitHub App credentials, mounted to GKE via Kubernetes secret)
- Monitoring and alerting requirements (Google Cloud Observability, 7 alert policies with thresholds)
- Backup and DR procedure (Git-based recovery, Redis PVC snapshots, 7-day retention)

**Dependencies**:
- Phase 4.1B complete (security strategy defined)
- GitHub organization admin access available (to create GitHub App)
- Access to `core/pcc-app-argo-config` repository
- Secret Manager API enabled
- Cloud Monitoring configured

---

#### Phase 4.2A: Plan ArgoCD Installation Configuration (20-30 min)

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
    - TLS termination: At GKE Load Balancer (Google-managed SSL certs from Phase 4.2B)
    - Hostname: `argocd-nonprod-east4.pcconnect.ai`
    - TLS policy: TLS 1.2+ minimum, HTTP redirect to HTTPS (301)
    - Annotations:
      - `ingress.gce.io/pre-shared-cert: argocd-nonprod-east4-pcconnect-ai` (from Phase 4.2B)
      - `cloud.google.com/armor-config: argocd-cloud-armor` (from Phase 4.2B)
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
    - TLS termination: At GKE Load Balancer (Google-managed SSL certs from Phase 4.2B)
    - Hostname: `argocd-east4.pcconnect.ai`
    - TLS policy: TLS 1.2+ minimum, HTTP redirect to HTTPS (301)
    - Annotations:
      - `ingress.gce.io/pre-shared-cert: argocd-east4-pcconnect-ai` (from Phase 4.2B)
      - `cloud.google.com/armor-config: argocd-cloud-armor` (from Phase 4.2B)
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
- Document Cloud Armor and SSL certificate requirements (for Phase 4.2B terraform)

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
- **GCP resource requirements** list (input for Phase 4.2B terraform):
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
- Phase 4.1A/B/C complete (architecture and security planned)
- Google Workspace OAuth 2.0 configuration available
- Understanding of ArgoCD HA requirements (3 node minimum for pod anti-affinity)

---

#### Phase 4.2B: Create Terraform for ArgoCD GCP Resources (20-30 min)

**Objective**: Create terraform for GCP resources supporting ArgoCD ingress and security

**Repository Decision**: `infra/pcc-app-shared-infra` (existing shared infrastructure repo)
- **Rationale**: ArgoCD ingress IPs and certs are foundational shared infrastructure, aligns with existing pattern, single point of management
- **File**: `terraform/argocd-ingress.tf` (single file, not modularized - only 7 resources, tightly coupled)

**Activities**:
- **Cloud Armor security policy**:
  - Create policy: `argocd-cloud-armor` (DDoS protection + rate limiting)
  - DDoS rules: Conservative thresholds (adjust post-Phase 4.3 metrics)
  - Rate limiting: 10 requests/min per IP (initial protection, tune after baseline)
  - IP allowlisting: Optional (defer to operational needs)
  - **Backend service attachment**: GKE Ingress auto-creates backend service; Cloud Armor attaches via ingress annotation (`cloud.google.com/armor-config`)
  - **Note**: Created in Phase 4.2B (not deferred) because Helm values.yaml references it in annotations
- **Reserved static external IPs** (created FIRST):
  - Nonprod: `argocd-nonprod-east4-ip` (region: us-east4)
  - Prod: `argocd-east4-ip` (region: us-east4)
  - Resource type: `google_compute_address`
  - Purpose: Load balancer frontend IP (GKE Ingress service)
- **DNS A records** (created SECOND, immediately after IPs):
  - Nonprod: `argocd-nonprod-east4.pcconnect.ai` → reserved IP address
  - Prod: `argocd-east4.pcconnect.ai` → reserved IP address
  - Zone: `pcconnect.ai` (existing Cloud DNS zone)
  - TTL: 300 seconds (5 minutes)
  - Resource type: `google_dns_record_set`
  - **CRITICAL**: DNS records MUST exist before SSL cert creation (cert validation requires DNS)
- **Google-managed SSL certificates** (created THIRD, after DNS validation):
  - Nonprod: `argocd-nonprod-east4-pcconnect-ai` (domain: argocd-nonprod-east4.pcconnect.ai)
  - Prod: `argocd-east4-pcconnect-ai` (domain: argocd-east4.pcconnect.ai)
  - Resource type: `google_compute_managed_ssl_certificate`
  - Validation: Automatic via DNS (Google validates A record exists)
  - **Deployment Strategy**: Create DNS first (`terraform apply -target=google_dns_record_set.*`), then certs
  - Auto-renewal: Managed by Google (90-day rotation, fully automated)
- **SSL Policy** (ADDITIONAL RESOURCE - missing from original plan):
  - Create SSL policy: `argocd-ssl-policy-tls12` (enforce TLS 1.2+)
  - Min TLS version: 1.2
  - Profile: MODERN (recommended ciphers)
  - Resource type: `google_compute_ssl_policy`
  - **Rationale**: Enforces TLS 1.2+ requirement from Phase 4.2A ingress spec
- **HTTP-to-HTTPS Redirect** (ADDITIONAL RESOURCE - missing from original plan):
  - Configure via GKE Ingress annotation: `kubernetes.io/ingress.allow-http: "false"`
  - Alternatively: Create HTTP URL map with 301 redirect to HTTPS
  - **Rationale**: Enforces HTTPS-only access (Phase 4.2A TLS policy requirement)
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
  - **Usage**: Phase 4.3/4.5 Helm values.yaml references these outputs in ingress annotations
- **IAM Permissions** (document required for deployer):
  - `compute.addresses.create` (reserved IPs)
  - `compute.sslCertificates.create` (Google-managed certs)
  - `compute.sslPolicies.create` (SSL policies)
  - `compute.securityPolicies.create` (Cloud Armor)
  - `dns.resourceRecordSets.create` (DNS A records)
  - **Note**: Least-privilege principle - only what terraform needs

**Deliverables**:
- **Terraform configuration** in `infra/pcc-app-shared-infra/terraform/argocd-ingress.tf`:
  - 8 GCP resources total:
    - 2 reserved static external IPs (`google_compute_address`)
    - 2 DNS A records (`google_dns_record_set`)
    - 2 Google-managed SSL certificates (`google_compute_managed_ssl_certificate`)
    - 1 Cloud Armor security policy (`google_compute_security_policy`)
    - 1 SSL policy for TLS 1.2+ enforcement (`google_compute_ssl_policy`)
  - Variables for environment/region differentiation
  - Outputs for Helm ingress annotations (IPs, cert names, policy names)
- **Resource dependency ordering** documented:
  1. Reserved IPs created first
  2. DNS A records created second (reference IPs)
  3. SSL certificates created third (require DNS validation)
  4. Cloud Armor + SSL policies (order-independent)
- **Deployment strategy** documented:
  - Phase 1: `terraform apply -target=google_compute_address.*` (IPs)
  - Phase 2: `terraform apply -target=google_dns_record_set.*` (DNS)
  - Phase 3: `terraform apply` (all remaining resources, including SSL certs)
  - **Rationale**: SSL cert validation requires DNS A record to exist
- **IAM permissions checklist** for deployer
- **Terraform validation passed**:
  - `terraform validate` (syntax check)
  - `terraform fmt` (formatting)
  - `tflint` (style violations)
  - `tfsec` (security audit)
  - `terraform plan` shows 8 new resources (0 deletions, 0 replacements)
- **Ready for Phase 4.3/4.5**: Terraform plan reviewed, outputs match ingress annotation requirements

**Dependencies**:
- Phase 4.2A complete (ingress requirements documented)
- DNS zone `pcconnect.ai` exists and accessible
- IAM permissions for Compute addresses, SSL certs, Cloud Armor, Cloud DNS

**Note**: This terraform will be applied BEFORE ArgoCD Helm installation to ensure IPs and SSL certs are available for ingress configuration

---

#### Phase 4.2C: Apply Terraform for ArgoCD Nonprod Infrastructure (15-20 min)

**Objective**: Deploy GCP resources for nonprod ArgoCD ingress and security

**Execution Structure**: Sequential terraform deployment in 3 stages
1. **Stage 1: Reserve Static IPs** (2-3 min) - Create external IP addresses
2. **Stage 2: Configure DNS** (3-5 min) - Create DNS A records pointing to IPs
3. **Stage 3: Deploy Certificates & Policies** (8-10 min) - SSL certs, Cloud Armor, SSL policy

**Key Context**:
- Terraform configuration: `infra/pcc-app-shared-infra/terraform/argocd-ingress.tf` (from Phase 4.2B)
- Target environment: Nonprod only (argocd-nonprod-east4.pcconnect.ai)
- Total resources: 4 resources for nonprod (IP, DNS, SSL cert, shared policies)
- Deployment strategy: Staged apply to ensure SSL cert DNS validation succeeds

---

##### Stage 1: Reserve Static IPs (2-3 min)

**Purpose**: Create reserved external IP addresses for ArgoCD ingress

**Pre-flight Checks**:
- **Terraform configuration verification**:
  - Command: `ls -la infra/pcc-app-shared-infra/terraform/argocd-ingress.tf`
  - Expected: File exists (created in Phase 4.2B)

- **Terraform initialization**:
  - Command: `cd infra/pcc-app-shared-infra/terraform && terraform init`
  - Expected: Backend initialized, providers downloaded

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
    -target=google_compute_address.argocd_nonprod_ip \
    -var="environment=nonprod" \
    -var="region=us-east4" \
    -var="dns_zone=pcconnect.ai" \
    -auto-approve
  ```
- **Single-line format**:
  `terraform apply -target=google_compute_address.argocd_nonprod_ip -var="environment=nonprod" -var="region=us-east4" -var="dns_zone=pcconnect.ai" -auto-approve`

- **Expected output**:
  ```
  google_compute_address.argocd_nonprod_ip: Creating...
  google_compute_address.argocd_nonprod_ip: Creation complete after 2s [id=projects/pcc-prj-devops-nonprod/regions/us-east4/addresses/argocd-nonprod-east4-ip]

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
    -target=google_dns_record_set.argocd_nonprod_a \
    -var="environment=nonprod" \
    -var="region=us-east4" \
    -var="dns_zone=pcconnect.ai" \
    -auto-approve
  ```
- **Single-line format**:
  `terraform apply -target=google_dns_record_set.argocd_nonprod_a -var="environment=nonprod" -var="region=us-east4" -var="dns_zone=pcconnect.ai" -auto-approve`

- **Expected output**:
  ```
  google_dns_record_set.argocd_nonprod_a: Creating...
  google_dns_record_set.argocd_nonprod_a: Creation complete after 3s

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
  google_compute_managed_ssl_certificate.argocd_nonprod: Creating...
  google_compute_security_policy.argocd_armor: Creating...
  google_compute_ssl_policy.argocd_ssl: Creating...

  google_compute_security_policy.argocd_armor: Creation complete after 3s
  google_compute_ssl_policy.argocd_ssl: Creation complete after 2s
  google_compute_managed_ssl_certificate.argocd_nonprod: Creation complete after 5s

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
   - Expected status: `PROVISIONING` (will transition to ACTIVE when Ingress is created in Phase 4.3)
   - Note: Certificate requires Ingress with matching domain to complete activation

2. **Cloud Armor Policy**:
   - Command: `gcloud compute security-policies describe argocd-cloud-armor --project=pcc-prj-devops-nonprod`
   - Expected: Policy exists with rate limiting rules (from Phase 4.2B configuration)

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

**Phase 4.2C Deliverables**:
- Static IP reserved: argocd-nonprod-east4-ip (us-east4)
- DNS A record created: argocd-nonprod-east4.pcconnect.ai → static IP
- Google-managed SSL certificate created: argocd-nonprod-east4-pcconnect-ai (PROVISIONING status)
- Cloud Armor security policy: argocd-cloud-armor (DDoS protection, rate limiting)
- SSL policy: argocd-ssl-policy (TLS 1.2+ enforcement)
- Terraform outputs captured for Phase 4.3 Helm values.yaml

**Dependencies**:
- Phase 4.2B complete (terraform configuration exists)
- Terraform installed and initialized
- IAM permissions for Compute Engine and Cloud DNS
- DNS zone `pcconnect.ai` exists and accessible

**Duration Estimate**: 15-20 minutes total
- Stage 1 (Static IPs): 2-3 min
- Stage 2 (DNS): 3-5 min (includes DNS propagation wait)
- Stage 3 (Certificates & Policies): 8-10 min
- Buffer: 2 min

**Phase 4.3 Readiness Criteria** (terraform outputs for Helm deployment):
- ✅ Static IP address reserved and assigned
- ✅ DNS A record resolves to static IP
- ✅ SSL certificate created (PROVISIONING status acceptable, will activate when Ingress created)
- ✅ Cloud Armor policy deployed with rate limiting rules
- ✅ SSL policy configured for TLS 1.2+ enforcement
- ✅ Terraform outputs available for ingress annotation values

**Note**: SSL certificate will remain in PROVISIONING status until Phase 4.3 creates the GKE Ingress resource. This is expected behavior - Google validates domain ownership via the Ingress.

---

### Nonprod Deployment (3 subphases)

#### Phase 4.3: Install ArgoCD on Devops Nonprod Cluster (28-40 min)

**Objective**: Deploy ArgoCD v3.1.9 to pcc-gke-devops-nonprod cluster with GKE Ingress, Google SSO, and RBAC

**Execution Structure**: Three modular sections executed sequentially
1. **Module 1: Pre-flight Checks** (3-5 min) - Verify prerequisites
2. **Module 2: Helm Deployment** (10-18 min) - Install ArgoCD via Helm
3. **Module 3: Component Verification** (5-7 min) - Essential validations

**Key Architectural Context** (from previous phases):
- ArgoCD version: v3.1.9 (Helm chart v7.7.4)
- Configuration: Single-replica (nonprod environment)
- Ingress: GKE Ingress with Google-managed SSL cert (from Phase 4.2B terraform)
- DNS: `argocd-nonprod-east4.pcconnect.ai` (from Phase 4.2B terraform)
- Auth: OAuth 2.0 via Google Workspace SSO (Dex connector)
- RBAC: gcp-devops@pcconnect.ai (admin), gcp-developers@pcconnect.ai (view + sync)
- Namespace: `argocd`

---

##### Module 1: Pre-flight Checks (3-5 min)

**Purpose**: Verify all prerequisites before Helm deployment to prevent mid-deployment failures

**Section 1.1: Cluster Context Verification**
- **Action**: Verify kubectl is configured for correct cluster
- **Expected cluster context**: `gke_pcc-prj-devops-nonprod_us-east4_pcc-gke-devops-nonprod`
- **Verification method**: `kubectl config current-context`
- **Expected GCP project**: `pcc-prj-devops-nonprod`
- **Expected region**: `us-east4`
- **Cluster info verification**: `kubectl cluster-info` should show nonprod cluster endpoints
- **Node verification**: `kubectl get nodes` should return nonprod cluster nodes without permission errors
- **Critical**: STOP if cluster context is wrong - deploying to wrong cluster is catastrophic

**Section 1.2: Phase 4.2B Terraform Outputs Verification**
- **Action**: Verify all GCP resources from Phase 4.2B exist before deployment
- **Required resources**:
  1. **Static IP**: `argocd-nonprod-east4-ip` in region `us-east4`
     - Verification: `gcloud compute addresses describe argocd-nonprod-east4-ip --region=us-east4 --project=pcc-prj-devops-nonprod`
     - Expected status: `RESERVED` (not yet in use)
  2. **DNS A record**: `argocd-nonprod-east4.pcconnect.ai` resolves to static IP
     - Verification: `dig +short argocd-nonprod-east4.pcconnect.ai` or `nslookup argocd-nonprod-east4.pcconnect.ai`
     - Expected: Returns the reserved static IP address
  3. **Google-managed SSL certificate**: `argocd-nonprod-east4-pcconnect-ai`
     - Verification: `gcloud compute ssl-certificates describe argocd-nonprod-east4-pcconnect-ai --global --project=pcc-prj-devops-nonprod`
     - Expected status: `ACTIVE` or `PROVISIONING` (cert may still be provisioning)
     - **Note**: If cert is still PROVISIONING, that's OK - it will activate when Ingress is created
  4. **Cloud Armor security policy**: `argocd-cloud-armor`
     - Verification: `gcloud compute security-policies describe argocd-cloud-armor --project=pcc-prj-devops-nonprod`
     - Expected: Policy exists with rate limiting rules
- **Critical**: All 4 resources must exist. GKE Ingress configuration will reference these by name.

**Section 1.3: Values File Validation**
- **Action**: Verify values-nonprod.yaml is ready and properly configured
- **File location**: `core/pcc-app-argo-config/helm/values-nonprod.yaml` (from Phase 4.2A)
- **Verification checks**:
  1. File exists at expected path
  2. ArgoCD version specification: Chart should reference argo-cd chart v7.7.4 (app version v3.1.9)
  3. **Ingress configuration** (critical section):
     - Ingress enabled: `true`
     - Ingress class: `gce` (GKE Ingress)
     - Hostname: `argocd-nonprod-east4.pcconnect.ai`
     - TLS enabled: `true`
     - **Annotations** (must reference Phase 4.2B terraform outputs):
       - `ingress.gce.io/pre-shared-cert: argocd-nonprod-east4-pcconnect-ai` (SSL cert name)
       - `cloud.google.com/armor-config: argocd-cloud-armor` (Cloud Armor policy name)
       - `kubernetes.io/ingress.allow-http: "false"` (HTTPS-only)
  4. **Dex OAuth 2.0 configuration** (critical section):
     - Dex enabled: `true`
     - Google connector configured with client ID and client secret reference
     - Callback URL: `https://argocd-nonprod-east4.pcconnect.ai/api/dex/callback`
  5. **RBAC policy configuration**:
     - ArgoCD RBAC ConfigMap includes role bindings for:
       - `g, gcp-devops@pcconnect.ai, role:admin` (admin all namespaces)
       - `g, gcp-developers@pcconnect.ai, role:readonly` (view + sync, small team trust)
  6. **Replica configuration**: All components set to 1 replica (single-replica nonprod config)
- **Critical**: If any configuration is missing or incorrect, STOP and fix values.yaml before deployment

**Section 1.4: Helm Repository Configuration**
- **Action**: Add ArgoCD Helm repository (if not already added)
- **Repository URL**: `https://argoproj.github.io/argo-helm`
- **Repository name**: `argo`
- **Commands**:
  - Add repo: `helm repo add argo https://argoproj.github.io/argo-helm`
  - Update repos: `helm repo update`
- **Verification**: `helm search repo argo/argo-cd --version 7.7.4` should return chart version 7.7.4

**Pre-flight Checks Output**: Go/No-Go decision
- **GO**: All checks passed → Proceed to Module 2
- **NO-GO**: Any check failed → Stop, fix issues, re-run pre-flight checks

---

##### Module 2: Helm Deployment (10-18 min)

**Purpose**: Install ArgoCD v3.1.9 using Helm chart with nonprod configuration

**Section 2.1: Namespace Creation**
- **Action**: Create `argocd` namespace with proper labels
- **Namespace name**: `argocd`
- **Labels**: Standard Kubernetes labels for ArgoCD
  - `app.kubernetes.io/name: argocd`
  - `app.kubernetes.io/component: argocd`
- **Command pattern**: `kubectl create namespace argocd` (or use `--create-namespace` flag in Helm install)
- **Verification**: `kubectl get namespace argocd` should show namespace exists with STATUS=Active

**Section 2.2: Helm Install Command**
- **Action**: Install ArgoCD using Helm chart v7.7.4
- **Release name**: `argocd`
- **Namespace**: `argocd`
- **Chart**: `argo/argo-cd`
- **Chart version**: `7.7.4` (corresponds to ArgoCD app version v3.1.9)
- **Values file**: `core/pcc-app-argo-config/helm/values-nonprod.yaml`
- **Helm install parameters**:
  - `--create-namespace`: Create namespace if it doesn't exist
  - `--wait`: Wait for all pods to be ready before marking deployment as successful
  - `--timeout 10m`: Maximum wait time for deployment (10 minutes)
- **Command structure** (multi-line format for readability):
  ```bash
  helm install argocd argo/argo-cd \
    --version 7.7.4 \
    --namespace argocd \
    --create-namespace \
    --values core/pcc-app-argo-config/helm/values-nonprod.yaml \
    --wait \
    --timeout 10m
  ```
- **Single-line executable format**:
  `helm install argocd argo/argo-cd --version 7.7.4 --namespace argocd --create-namespace --values core/pcc-app-argo-config/helm/values-nonprod.yaml --wait --timeout 10m`
- **Expected duration**: 5-8 minutes (pod startup + readiness probes)
- **Success criteria**: Helm command exits with status 0, message "STATUS: deployed"

**Section 2.3: Initial Admin Password Retrieval**
- **Action**: Retrieve auto-generated initial admin password for first-time access
- **Secret name**: `argocd-initial-admin-secret`
- **Secret namespace**: `argocd`
- **Password key**: `password` (base64-encoded)
- **Retrieval method**: `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d`
- **Usage**: This password is temporary and used only for initial admin access before SSO is configured
- **Security note**: This secret will be deleted in Phase 4.4 after SSO is confirmed working

**Section 2.4: Helm Release Verification**
- **Action**: Verify Helm release is in deployed status
- **Command**: `helm status argocd -n argocd`
- **Expected output**:
  - STATUS: `deployed`
  - REVISION: `1` (first deployment)
  - CHART: `argo-cd-7.7.4`
  - APP VERSION: `v3.1.9`
- **Additional verification**: `helm list -n argocd` should show argocd release

---

##### Module 3: Component Verification (10-17 min)

**Purpose**: Essential validations to confirm ArgoCD is operational (happy path only)

**Section 3.1: SSL Certificate Provisioning Wait**
- **Action**: Wait for Google-managed SSL certificate to provision (if not already ACTIVE)
- **Expected behavior**:
  - Certificate starts in PROVISIONING state when Ingress is created
  - Google validates DNS ownership via A record (from Phase 4.2B)
  - Certificate transitions to ACTIVE state (typically 5-10 minutes)
- **Monitoring command**: `gcloud compute ssl-certificates describe argocd-nonprod-east4-pcconnect-ai --global --project=pcc-prj-devops-nonprod`
- **Success criteria**: Certificate status shows `ACTIVE`
- **Note**: ArgoCD UI will not be accessible via HTTPS until certificate is ACTIVE
- **Timing**: This wait naturally occurs while pods are stabilizing post-deployment

**Section 3.2: Pod Readiness Verification**
- **Action**: Verify all ArgoCD component pods are running and ready
- **Expected pods (nonprod - single replica)**:

  **Required core components (must be present):**
  1. `argocd-server-*` (1 pod) - API server and UI
  2. `argocd-repo-server-*` (1 pod) - Repository management
  3. `argocd-application-controller-*` (1 pod) - Application sync controller
  4. `argocd-dex-server-*` (1 pod) - OAuth 2.0 SSO (Dex)
  5. `argocd-redis-*` (1 pod) - Redis cache (ephemeral storage OK for nonprod)

  **Optional components (presence depends on values-nonprod.yaml configuration):**
  6. `argocd-notifications-controller-*` (1 pod) - Notifications (if enabled in values)
  7. `argocd-applicationset-controller-*` (1 pod) - ApplicationSet controller (if enabled in values)

- **Verification method**: `kubectl -n argocd get pods`
- **Success criteria**: All required core component pods (1-5) show STATUS=Running, READY=1/1 (or 2/2 for multi-container pods). Optional component pods (6-7) must be Running if present.
- **Wait command**: `kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s`
- **Note**: If any required pods are not ready after 5 minutes, check pod logs for errors

**Section 3.3: GKE Ingress Verification**
- **Action**: Verify GKE Ingress resource is created and has external IP assigned
- **Ingress name**: `argocd-server` (default ArgoCD ingress name)
- **Verification method**: `kubectl -n argocd get ingress argocd-server`
- **Expected output**:
  - CLASS: `gce` (GKE Ingress controller)
  - HOSTS: `argocd-nonprod-east4.pcconnect.ai`
  - ADDRESS: External IP address (from Phase 4.2B static IP)
  - PORTS: `80, 443` (HTTP redirects to HTTPS)
- **Annotations verification**: `kubectl -n argocd get ingress argocd-server -o yaml`
  - Should include annotations for SSL cert and Cloud Armor policy from Phase 4.2B
- **Success criteria**: Ingress has ADDRESS field populated with external IP

**Section 3.4: DNS Resolution Verification**
- **Action**: Verify DNS resolves to Ingress external IP
- **DNS name**: `argocd-nonprod-east4.pcconnect.ai`
- **Verification method**: `dig +short argocd-nonprod-east4.pcconnect.ai` or `nslookup argocd-nonprod-east4.pcconnect.ai`
- **Expected result**: DNS query returns the same IP address as shown in Ingress ADDRESS field
- **Note**: DNS was configured in Phase 4.2B, this is just verification that it still resolves correctly

**Section 3.5: HTTPS Accessibility Verification**
- **Action**: Verify ArgoCD UI is accessible via HTTPS with valid SSL certificate
- **URL**: `https://argocd-nonprod-east4.pcconnect.ai`
- **Verification method**:
  1. Check HTTPS response: `curl -I https://argocd-nonprod-east4.pcconnect.ai`
  2. Verify login page content: `curl -s https://argocd-nonprod-east4.pcconnect.ai | grep -q "LOG IN VIA GOOGLE"`
- **Expected output (step 1)**:
  - HTTP response code: `307` (redirect to login) or `200` (login page)
  - SSL certificate: Valid, issued by Google Trust Services
  - No SSL errors (certificate must be ACTIVE from Section 3.1)
- **Expected output (step 2)**:
  - Exit code 0 (string "LOG IN VIA GOOGLE" found in HTML response)
- **Success criteria**: Both curl commands succeed, confirming HTTPS connection with valid certificate and login page renders correctly

**Section 3.6: Basic Google SSO Login Test**
- **Action**: Perform basic SSO login test to verify OAuth 2.0 integration works
- **Test procedure**:
  1. Navigate to `https://argocd-nonprod-east4.pcconnect.ai`
  2. Click "LOG IN VIA GOOGLE" button
  3. Authenticate with test user from `gcp-developers@pcconnect.ai` or `gcp-devops@pcconnect.ai` Google Workspace group
  4. Verify redirect back to ArgoCD dashboard after successful authentication
  5. Confirm user email is displayed in ArgoCD UI (upper right corner)
- **Success criteria**:
  - OAuth flow completes without errors
  - User is logged into ArgoCD
  - User email/name is displayed in UI
- **Note**: Detailed RBAC permission testing (verify read-only vs admin roles) is deferred to Phase 4.4

**Component Verification Output**: Pass/Fail
- **PASS**: All 6 essential validations succeeded → Phase 4.3 complete
- **FAIL**: Any validation failed → Troubleshoot (outside scope of this happy-path document)

---

**Deliverables**:
- ArgoCD v3.1.9 installed on `pcc-gke-devops-nonprod` cluster in `argocd` namespace
- GKE Ingress configured with Google-managed SSL certificate and Cloud Armor protection
- DNS `argocd-nonprod-east4.pcconnect.ai` resolves to Ingress external IP
- HTTPS access to ArgoCD UI working with valid SSL certificate
- Google Workspace SSO (OAuth 2.0) authentication functional
- Initial admin password retrieved and documented (temporary, will be removed in Phase 4.4)
- All ArgoCD component pods running and ready (single-replica configuration)

**Dependencies**:
- Phase 4.2A complete (values-nonprod.yaml created and validated)
- Phase 4.2B complete (terraform outputs: static IP, DNS, SSL cert, Cloud Armor policy)
- kubectl access to `pcc-gke-devops-nonprod` cluster
- Google Workspace OAuth 2.0 client configured for ArgoCD (from Phase 4.1B planning)
- Helm v3 installed on executor machine
- gcloud CLI installed and authenticated to `pcc-prj-devops-nonprod` project

**Duration Estimate**: 28-40 minutes total
- Module 1 (Pre-flight Checks): 3-5 min
- Module 2 (Helm Deployment): 5-8 min
- Module 3 (Component Verification): 10-17 min (includes SSL cert provisioning wait)
- Buffer: 10 min for SSL cert provisioning variance and manual observation

---

#### Phase 4.4: Configure & Test ArgoCD Nonprod (27-40 min)

**Objective**: Configure GitHub App integration, deploy test application, validate ArgoCD functionality

**Execution Structure**: Four modular sections executed sequentially
1. **Module 1: Pre-flight Checks** (3-5 min) - Verify Phase 4.3 outputs and prerequisites
2. **Module 2: GitHub Integration** (6-9 min) - Configure GitHub App with Workload Identity
3. **Module 3: Application Deployment** (10-14 min) - Deploy echoserver test app via ArgoCD
4. **Module 4: Validation & Cleanup** (8-12 min) - Test RBAC, auto-sync, cleanup admin secret

**Key Architectural Context** (from previous phases):
- GitHub integration: GitHub App with Workload Identity (NO SSH keys) - Phase 4.1C
- Secret Manager: argocd-github-app-credentials - Phase 4.1C
- Repository: core/pcc-app-argo-config (read-only access)
- Test workload: k8s.gcr.io/echoserver:1.10 (responds to HTTP requests on root path `/` for liveness/readiness probes)
- Deployment target: devops-nonprod cluster itself (NOT app-devtest - nonprod is test-only)
- RBAC: gcp-devops@pcconnect.ai (admin), gcp-developers@pcconnect.ai (view + sync)
- Auth: Google Workspace SSO only (admin password will be deleted in Module 4)

---

##### Module 1: Pre-flight Checks (3-5 min)

**Purpose**: Verify Phase 4.3 deployment is stable and all prerequisites are in place before GitHub integration

**Section 1.1: ArgoCD Operational Status Verification**
- **Action**: Confirm Phase 4.3 Module 3 validations still passing
- **Checks**:
  1. **All ArgoCD pods running**:
     - Command: `kubectl -n argocd get pods`
     - Expected: 5 core component pods STATUS=Running, READY=1/1 (or 2/2)
       - argocd-server-* (1 pod)
       - argocd-repo-server-* (1 pod)
       - argocd-application-controller-* (1 pod)
       - argocd-dex-server-* (1 pod)
       - argocd-redis-* (1 pod)
     - Note: If pods not ready, troubleshoot Phase 4.3 deployment before continuing

  2. **SSL certificate still ACTIVE**:
     - Command: `gcloud compute ssl-certificates describe argocd-nonprod-east4-pcconnect-ai --global --project=pcc-prj-devops-nonprod`
     - Expected: STATUS=ACTIVE

  3. **HTTPS accessibility**:
     - Command: `curl -I https://argocd-nonprod-east4.pcconnect.ai`
     - Expected: HTTP 200 or 307 (redirect to login), valid SSL certificate

  4. **Google SSO functional**:
     - Manual test: Navigate to https://argocd-nonprod-east4.pcconnect.ai, click "LOG IN VIA GOOGLE"
     - Expected: OAuth flow completes, user logged in successfully

- **Success criteria**: All 4 checks pass → Proceed to Section 1.2
- **Failure action**: Any check fails → Fix Phase 4.3 issues before continuing

**Section 1.2: ArgoCD CLI Setup and Authentication**
- **Action**: Install and authenticate ArgoCD CLI for command execution in Modules 2-4
- **CLI version verification**:
  - Command: `argocd version --client`
  - Expected: v2.13.x (matching ArgoCD server version from Phase 4.3)
  - Note: CLI version should match server major.minor version for API compatibility
  - Check server version: `kubectl -n argocd get deployment argocd-server -o jsonpath='{.spec.template.spec.containers[0].image}'`
  - If not installed, install from https://argo-cd.readthedocs.io/en/stable/cli_installation/

- **Authentication via SSO**:
  - Command: `argocd login argocd-nonprod-east4.pcconnect.ai --sso --grpc-web`
  - Expected behavior:
    - CLI opens browser for Google OAuth authentication
    - User authenticates with Google account (gcp-developers or gcp-devops group)
    - CLI shows "Logged in successfully"
  - Note: Use --grpc-web flag for compatibility with GKE Ingress

- **Context verification**:
  - Command: `argocd context`
  - Expected output: Shows current context `argocd-nonprod-east4.pcconnect.ai`

- **Session test**:
  - Command: `argocd app list`
  - Expected: Command succeeds (may return empty list, that's OK)
  - Note: If "permission denied", verify Google group membership for authenticated user

- **Success criteria**: ArgoCD CLI authenticated and operational

**Section 1.3: Secret Manager Credentials Verification**
- **Action**: Verify GitHub App credentials exist in Secret Manager before creating Kubernetes secret
- **Secret existence check**:
  - Command: `gcloud secrets describe argocd-github-app-credentials --project=pcc-prj-devops-nonprod`
  - Expected output: Secret exists, shows creation time and replication policy
  - Note: If secret doesn't exist, create it with GitHub App credentials (app ID, installation ID, private key PEM)

- **Secret content verification**:
  - Command: `gcloud secrets versions access latest --secret=argocd-github-app-credentials --project=pcc-prj-devops-nonprod`
  - Expected structure (JSON):
    ```json
    {
      "appId": "123456",
      "installationId": "789012",
      "privateKey": "-----BEGIN RSA PRIVATE KEY-----\n...\n-----END RSA PRIVATE KEY-----"
    }
    ```
  - Note: Do NOT create Kubernetes secret yet - that happens in Module 2 Section 2.2

- **IAM binding verification**:
  - Command: `gcloud projects get-iam-policy pcc-prj-devops-nonprod --flatten="bindings[].members" --filter="bindings.members:serviceAccount:argocd-repo-server@pcc-prj-devops-nonprod.iam.gserviceaccount.com" --format="table(bindings.role)"`
  - Expected: Shows `roles/secretmanager.secretAccessor` role
  - Note: If binding missing, ArgoCD repo-server won't be able to access GitHub App credentials

- **Success criteria**: Secret exists with valid JSON structure, IAM binding configured

**Section 1.4: Repository Structure Validation**
- **Action**: Verify core/pcc-app-argo-config repository has expected directory structure
- **Repository clone** (if not already local):
  - Command: `git clone https://github.com/ORG/pcc-app-argo-config.git /tmp/pcc-app-argo-config` (replace ORG with actual organization)
  - Expected: Repository clones successfully

- **Directory structure check**:
  - Command: `ls -la /tmp/pcc-app-argo-config/`
  - Expected directories:
    - `applications/` (contains ArgoCD Application manifests)
    - `applications/nonprod/` (nonprod-specific applications)
    - `manifests/` (Kubernetes manifests)
    - `helm/` (Helm values files)
  - Note: If directories missing, create them: `mkdir -p applications/nonprod manifests helm`

- **Helm values file check**:
  - Command: `ls -la /tmp/pcc-app-argo-config/helm/values-nonprod.yaml`
  - Expected: File exists (created in Phase 4.2A)

- **Success criteria**: Repository structure matches expected layout

**Pre-flight Checks Output**: Go/No-Go decision
- **GO**: All 4 sections passed → Proceed to Module 2
- **NO-GO**: Any section failed → Stop, fix issues, re-run pre-flight checks

---

##### Module 2: GitHub Integration (6-9 min)

**Purpose**: Configure ArgoCD repository connection using GitHub App with Workload Identity

**Section 2.1: Kubernetes Secret Creation from Secret Manager**
- **Action**: Create Kubernetes secret with GitHub App credentials for ArgoCD repo-server
- **Extract credentials from Secret Manager**:
  - Command:
    ```bash
    gcloud secrets versions access latest \
      --secret=argocd-github-app-credentials \
      --project=pcc-prj-devops-nonprod \
      --format='get(payload.data)' | base64 -d > /tmp/github-app-creds.json
    ```
  - Verify: `cat /tmp/github-app-creds.json` shows valid JSON with appId, installationId, privateKey

- **Create Kubernetes secret**:
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

- **Workload Identity annotation**:
  - Command:
    ```bash
    kubectl annotate serviceaccount argocd-repo-server \
      --namespace argocd \
      iam.gke.io/gcp-service-account=argocd-repo-server@pcc-prj-devops-nonprod.iam.gserviceaccount.com
    ```
  - Expected: `serviceaccount/argocd-repo-server annotated`
  - Note: This enables Workload Identity for Secret Manager access

- **Secret verification**:
  - Command: `kubectl -n argocd get secret argocd-repo-creds -o yaml`
  - Expected: Secret exists with data keys: githubAppID, githubAppInstallationID, githubAppPrivateKey (base64 encoded)

- **Cleanup temporary file**:
  - Command: `rm /tmp/github-app-creds.json`

- **Success criteria**: Kubernetes secret created, Workload Identity annotation applied

**Section 2.2: ArgoCD Repository Connection Configuration**
- **Action**: Add core/pcc-app-argo-config repository to ArgoCD using GitHub App authentication
- **Repository addition via ArgoCD CLI**:
  - Command structure (multi-line format):
    ```bash
    argocd repo add https://github.com/ORG/pcc-app-argo-config.git \
      --github-app-id $(kubectl -n argocd get secret argocd-repo-creds -o jsonpath='{.data.githubAppID}' | base64 -d) \
      --github-app-installation-id $(kubectl -n argocd get secret argocd-repo-creds -o jsonpath='{.data.githubAppInstallationID}' | base64 -d) \
      --github-app-private-key-path /dev/stdin \
      --name pcc-app-argo-config \
      --project default <<< $(kubectl -n argocd get secret argocd-repo-creds -o jsonpath='{.data.githubAppPrivateKey}' | base64 -d)
    ```
  - Replace `ORG` with actual GitHub organization name
  - Expected output: `Repository 'https://github.com/ORG/pcc-app-argo-config.git' added`

- **Repository list verification**:
  - Command: `argocd repo list`
  - Expected output:
    ```
    REPOSITORY                                     TYPE  NAME                PROJECT  STATUS      MESSAGE
    https://github.com/ORG/pcc-app-argo-config.git git   pcc-app-argo-config  default  Successful  Repo is accessible
    ```
  - Note: If STATUS shows "Failed", check GitHub App credentials and IAM binding

- **Repository connection test**:
  - Command: `argocd repo get https://github.com/ORG/pcc-app-argo-config.git`
  - Expected output fields:
    - Repository URL: https://github.com/ORG/pcc-app-argo-config.git
    - Type: git
    - Name: pcc-app-argo-config
    - Project: default
    - Connection Status: Successful
    - Last Refresh: <timestamp>

- **ArgoCD UI verification** (optional):
  - Navigate to Settings → Repositories in ArgoCD UI
  - Expected: pcc-app-argo-config repository shows green "Successful" connection status

- **Success criteria**: Repository connected with STATUS=Successful, can fetch from GitHub

**Section 2.3: Repository Connection Validation**
- **Action**: Verify ArgoCD can fetch repository contents
- **Check repo-server logs** (optional troubleshooting):
  - Command: `kubectl -n argocd logs deployment/argocd-repo-server --tail=50 | grep pcc-app-argo-config`
  - Expected: No authentication errors, successful git fetch messages
  - Note: If seeing "authentication failed", verify GitHub App credentials in Secret Manager

- **Test repository fetch via ArgoCD**:
  - Command: `argocd repo get https://github.com/ORG/pcc-app-argo-config.git --refresh`
  - Expected: Command succeeds, shows "Connection Status: Successful"
  - Note: --refresh flag forces immediate fetch to verify connectivity

- **Success criteria**: ArgoCD can successfully fetch from GitHub repository with no errors

**Module 2 Output**: GitHub Integration Complete
- **Deliverable**: ArgoCD connected to core/pcc-app-argo-config repository via GitHub App
- **Verification**: `argocd repo list` shows STATUS=Successful
- **Next step**: Proceed to Module 3 (Application Deployment)

---

##### Module 3: Application Deployment (10-14 min)

**Purpose**: Deploy echoserver test application via ArgoCD to validate sync functionality

**Section 3.1: Git Branch Creation and Manifest Files**
- **Action**: Create Git branch for hello-world manifests
- **Navigate to repository**:
  - Command: `cd /tmp/pcc-app-argo-config` (or your local clone path)

- **Create feature branch**:
  - Command: `git checkout -b feat/argocd-hello-world-nonprod`
  - Expected: `Switched to a new branch 'feat/argocd-hello-world-nonprod'`

- **Create manifest directory**:
  - Command: `mkdir -p manifests/hello-world`

- **Create deployment manifest** (manifests/hello-world/deployment.yaml):
  ```yaml
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: hello-world
    namespace: default
    labels:
      app: hello-world
  spec:
    replicas: 1
    selector:
      matchLabels:
        app: hello-world
    template:
      metadata:
        labels:
          app: hello-world
      spec:
        containers:
        - name: echoserver
          image: k8s.gcr.io/echoserver:1.10
          ports:
          - containerPort: 8080
          livenessProbe:
            httpGet:
              path: /
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 5
          readinessProbe:
            httpGet:
              path: /
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 3
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              cpu: 100m
              memory: 128Mi
  ```

- **Create service manifest** (manifests/hello-world/service.yaml):
  ```yaml
  apiVersion: v1
  kind: Service
  metadata:
    name: hello-world
    namespace: default
    labels:
      app: hello-world
  spec:
    selector:
      app: hello-world
    ports:
    - protocol: TCP
      port: 80
      targetPort: 8080
    type: ClusterIP
  ```

- **Create ArgoCD Application manifest** (applications/nonprod/hello-world.yaml):
  ```yaml
  apiVersion: argoproj.io/v1alpha1
  kind: Application
  metadata:
    name: hello-world-nonprod
    namespace: argocd
  spec:
    project: default
    source:
      repoURL: https://github.com/ORG/pcc-app-argo-config.git
      targetRevision: main
      path: manifests/hello-world
    destination:
      server: https://kubernetes.default.svc
      namespace: default
    syncPolicy:
      automated:
        prune: true
        selfHeal: true
      syncOptions:
        - CreateNamespace=true
  ```
  - Replace `ORG` with actual GitHub organization name

- **Success criteria**: All 3 manifest files created in correct directories

**Section 3.2: Git Commit and Pull Request**
- **Action**: Commit manifests and create pull request for review
- **Stage files**:
  - Command: `git add manifests/hello-world/ applications/nonprod/hello-world.yaml`
  - Verify: `git status` shows 3 new files staged

- **Commit with conventional format**:
  - Command:
    ```bash
    git commit -m "feat: add hello-world test application for ArgoCD nonprod validation

- Add hello-world echoserver deployment (1 replica, minimal resources)
- Add ClusterIP service for hello-world
- Add ArgoCD Application manifest with auto-sync enabled
- Target: devops-nonprod cluster, default namespace
- Purpose: Phase 4.4 ArgoCD functionality validation

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
    ```
  - Expected: Commit created successfully
  - Note: Follows conventional commits format (feat:) and includes co-authoring per CLAUDE.md

- **Push branch to remote**:
  - Command: `git push origin feat/argocd-hello-world-nonprod`
  - Expected: Branch pushed to GitHub

- **Create pull request** (using GitHub CLI):
  - Command:
    ```bash
    gh pr create \
      --title "Add hello-world test app for ArgoCD nonprod" \
      --body "Phase 4.4: ArgoCD validation application

## Summary
- Adds echoserver deployment for ArgoCD testing
- Configures auto-sync with prune and self-heal
- Targets devops-nonprod cluster, default namespace

## Test Plan
- [ ] Manifests deploy successfully
- [ ] Application syncs via ArgoCD
- [ ] Auto-sync and self-heal work correctly

🤖 Generated with [Claude Code](https://claude.com/claude-code)"
    ```
  - Expected: Pull request created, URL displayed

- **Merge pull request** (after approval, or use --auto flag):
  - Command: `gh pr merge --squash --auto`
  - Expected: PR merged to main branch
  - Note: Wait for merge to complete before proceeding

- **Success criteria**: Manifests committed to main branch, available for ArgoCD to sync

**Section 3.3: ArgoCD Application Deployment**
- **Action**: Deploy hello-world Application to ArgoCD
- **Wait for repository sync** (ArgoCD polls every 3 minutes by default):
  - Command: `sleep 180` (wait 3 minutes for ArgoCD to detect new manifests)
  - Alternative: Force immediate sync with `argocd repo get https://github.com/ORG/pcc-app-argo-config.git --refresh`

- **Deploy Application via kubectl**:
  - Command: `kubectl apply -f applications/nonprod/hello-world.yaml`
  - Expected output: `application.argoproj.io/hello-world-nonprod created`
  - Note: This creates the Application resource in ArgoCD namespace

- **Verify Application created**:
  - Command: `argocd app list`
  - Expected output:
    ```
    NAME                  CLUSTER                         NAMESPACE  PROJECT  STATUS     HEALTH   SYNCPOLICY
    hello-world-nonprod   https://kubernetes.default.svc  default    default  OutOfSync  Missing  Auto
    ```
  - Note: Initial status will be OutOfSync/Missing - that's expected before first sync

- **Success criteria**: Application resource created in ArgoCD

**Section 3.4: Initial Sync Monitoring**
- **Action**: Monitor ArgoCD's automatic sync of hello-world application
- **Watch application sync progress**:
  - Command: `argocd app get hello-world-nonprod --watch`
  - Expected behavior:
    - Status changes from OutOfSync → Syncing → Synced
    - Health changes from Missing → Progressing → Healthy
    - Sync typically completes in 1-2 minutes
  - Press Ctrl+C to exit watch mode once Synced and Healthy

- **Check sync status** (after sync completes):
  - Command: `argocd app get hello-world-nonprod`
  - Expected output fields:
    - Sync Status: Synced
    - Health Status: Healthy
    - Last Sync: <timestamp>
    - Sync Result: SUCCESS
    - Resources: Shows Deployment and Service as Healthy

- **Verify Kubernetes resources deployed**:
  - Command: `kubectl -n default get deployment,service,pod -l app=hello-world`
  - Expected output:
    - Deployment: hello-world (1/1 ready)
    - Service: hello-world (ClusterIP)
    - Pod: hello-world-* (Running, 1/1 ready)

- **Check pod logs** (verify echoserver started):
  - Command: `kubectl -n default logs -l app=hello-world --tail=10`
  - Expected: Echoserver startup logs, listening on port 8080

- **Success criteria**: Application status Synced and Healthy, pod running successfully

**Module 3 Output**: Application Deployment Complete
- **Deliverable**: hello-world-nonprod application deployed and syncing via ArgoCD
- **Verification**: `argocd app get hello-world-nonprod` shows Synced/Healthy status
- **Next step**: Proceed to Module 4 (Validation & Cleanup)

---

##### Module 4: Validation & Cleanup (8-12 min)

**Purpose**: Validate RBAC permissions, auto-sync behavior, and clean up admin secret for SSO-only access

**Section 4.1: Application Health Verification**
- **Action**: Verify echoserver is responding to requests and health checks passing
- **Test echoserver HTTP endpoint** (from within cluster):
  - Command: `kubectl -n default run curl-test --image=curlimages/curl --rm -it --restart=Never -- curl -s http://hello-world.default.svc.cluster.local`
  - Expected output: Echoserver response showing request headers and server info
  - Note: This verifies Service routing to Pod is working

- **Verify liveness probe** (check probe is succeeding):
  - Command: `kubectl -n default describe pod -l app=hello-world | grep "Liveness:"`
  - Expected: Shows HTTP GET on port 8080, no failures recorded

- **Verify readiness probe** (check probe is succeeding):
  - Command: `kubectl -n default describe pod -l app=hello-world | grep "Readiness:"`
  - Expected: Shows HTTP GET on port 8080, no failures recorded

- **Check ArgoCD application resource status**:
  - Command: `kubectl -n argocd get application hello-world-nonprod -o jsonpath='{.status.health.status}'`
  - Expected output: `Healthy`

- **Success criteria**: Echoserver responding, probes passing, ArgoCD reports Healthy status

**Section 4.2: RBAC Permission Testing (Essential)**
- **Action**: Validate developer and devops role permissions (nonprod essential testing only)
- **Test Case 1: Developer Permissions (gcp-developers@pcconnect.ai)**
  - Login to ArgoCD UI with developer group user
  - Navigate to hello-world-nonprod application
  - **Expected permissions**:
    - ✅ CAN view application details, sync status, logs
    - ✅ CAN trigger manual sync (sync button enabled - small team trust model per Phase 4.1B)
    - ❌ CANNOT delete application (delete button grayed out or shows error)
  - ArgoCD CLI test:
    - Command: `argocd app sync hello-world-nonprod --auth-token <developer-token>`
    - Expected: Sync succeeds
  - Note: If sync fails with permission denied, verify RBAC ConfigMap in values-nonprod.yaml

- **Test Case 2: DevOps Admin Permissions (gcp-devops@pcconnect.ai)**
  - Login to ArgoCD UI with devops group user
  - Navigate to hello-world-nonprod application
  - **Expected permissions**:
    - ✅ CAN view, sync, delete, modify all applications
    - ✅ CAN create new applications
  - ArgoCD CLI test:
    - Command: `argocd app list --auth-token <devops-token>`
    - Expected: Shows all applications
  - Note: DO NOT actually delete application - just verify permission exists

- **Success criteria**: Developer can view and sync, DevOps has admin access

**Section 4.3: Auto-Sync Behavior Validation**
- **Action**: Test auto-sync detects drift and self-heals application back to Git state
- **Create out-of-sync scenario**:
  - Command: `kubectl -n default scale deployment hello-world --replicas=2`
  - Expected: Deployment scaled to 2 replicas (creates drift from Git manifest which specifies 1 replica)

- **Monitor ArgoCD drift detection**:
  - Command: `argocd app get hello-world-nonprod --watch`
  - Expected behavior (within 3-5 minutes):
    - Application shows "OutOfSync" status (yellow in UI)
    - Auto-sync triggers automatically
    - Status changes back to "Synced" (green in UI)
    - Health remains "Healthy" throughout
  - Note: ArgoCD polls repository every 3 minutes by default

- **Verify self-heal occurred**:
  - Command: `kubectl -n default get deployment hello-world -o jsonpath='{.spec.replicas}'`
  - Expected output: `1` (auto-healed back to manifest specification)
  - Command: `kubectl -n default get pods -l app=hello-world`
  - Expected: Only 1 pod running (2nd pod terminated by self-heal)

- **Check sync history**:
  - Command: `argocd app history hello-world-nonprod`
  - Expected: Most recent sync shows "automated sync" in OPERATION column
  - Expected: SYNC RESULT shows "succeeded"

- **Success criteria**: Auto-sync detected drift, self-healed application back to 1 replica, sync history shows automated sync

**Section 4.4: Admin Secret Cleanup (Security Hardening)**
- **Action**: Delete initial admin password secret to enforce SSO-only authentication
- **Pre-requisite verification**:
  - Confirm Google SSO tested successfully in Sections 4.2 (both groups authenticated)
  - Confirm at least 2 users can access ArgoCD via SSO
  - Note: This is a one-way operation - admin password authentication will be disabled

- **Delete initial admin secret**:
  - Command: `kubectl -n argocd delete secret argocd-initial-admin-secret`
  - Expected output: `secret "argocd-initial-admin-secret" deleted`

- **Verify admin password authentication disabled**:
  - Command: `argocd logout`
  - Command: `argocd login argocd-nonprod-east4.pcconnect.ai --username admin --password <old-password-from-phase-4.3>`
  - Expected: Error "invalid username or password" or "local users are not enabled"

- **Verify SSO still functional**:
  - Command: `argocd login argocd-nonprod-east4.pcconnect.ai --sso --grpc-web`
  - Expected: Browser opens for Google OAuth, successful authentication

- **Emergency access note**:
  - Document in `.claude/docs/argocd-emergency-procedures.md` (NOT in this deployment doc): If SSO is down, admin password can be reset via kubectl:
    ```bash
    kubectl -n argocd patch secret argocd-secret \
      -p '{"stringData":{"admin.password":"<new-bcrypt-hash>","admin.passwordMtime":"<timestamp>"}}'
    ```

- **Success criteria**: Admin secret deleted, SSO authentication functional, admin password login disabled

**Section 4.5: Nonprod Configuration Documentation**
- **Action**: Create documentation of nonprod configuration for operational reference
- **Document location**: `.claude/docs/argocd-nonprod-configuration.md`
- **Required content sections**:

  1. **Access Information**
     - URL: https://argocd-nonprod-east4.pcconnect.ai
     - Authentication: Google SSO only (admin password disabled)
     - Groups: gcp-developers@pcconnect.ai (view + sync), gcp-devops@pcconnect.ai (admin)

  2. **GitHub Repository Configuration**
     - Repository: https://github.com/ORG/pcc-app-argo-config.git
     - Authentication: GitHub App (app ID from Secret Manager, installation ID from Secret Manager)
     - Secret Manager secret: argocd-github-app-credentials (project: pcc-prj-devops-nonprod)
     - Access level: Read-only
     - Token rotation: Automatic (GitHub App tokens auto-rotate hourly)

  3. **Deployed Applications**
     - hello-world-nonprod:
       - Source path: manifests/hello-world
       - Destination: devops-nonprod cluster, default namespace
       - Image: k8s.gcr.io/echoserver:1.10
       - Sync policy: Auto-sync enabled, prune enabled, self-heal enabled
       - Health: Healthy (last verified: <timestamp>)

  4. **RBAC Configuration**
     - gcp-developers@pcconnect.ai: role:readonly with sync permissions
     - gcp-devops@pcconnect.ai: role:admin (full access)
     - Audit retention: 90 days (Cloud Logging)

  5. **Monitoring and Alerts**
     - Platform: Google Cloud Observability (Cloud Monitoring)
     - Alert policies: 7 policies (sync failures, health degraded, API latency, etc. - see Phase 4.1C)
     - Alert destination: gcp-devops@pcconnect.ai email

  6. **Known Limitations (Nonprod vs Prod Differences)**
     - Single replica configuration (not HA)
     - Ephemeral Redis storage (session data not persisted across pod restarts)
     - No managed clusters (devops-nonprod does NOT manage app-devtest cluster)
     - Test workloads only (hello-world app for validation purposes)

- **Create documentation file**:
  - Command: `vi .claude/docs/argocd-nonprod-configuration.md` (or use preferred editor)
  - Write content with sections above
  - Commit to repository:
    ```bash
    git add .claude/docs/argocd-nonprod-configuration.md
    git commit -m "docs: add ArgoCD nonprod configuration reference

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
    git push origin main
    ```

- **Success criteria**: Documentation created, committed to repository, accessible for future reference

**Module 4 Output**: Validation & Cleanup Complete
- **Deliverables**:
  - Application health verified (echoserver responding, probes passing)
  - RBAC permissions validated (developer view+sync, devops admin)
  - Auto-sync behavior tested and working (drift detection + self-heal)
  - Admin secret deleted (SSO-only authentication enforced)
  - Nonprod configuration documented
- **Phase 4.4 Complete**: ArgoCD nonprod fully functional and validated

---

**Phase 4.4 Deliverables**:
- GitHub repository (core/pcc-app-argo-config) connected to ArgoCD via GitHub App with Workload Identity
- Kubernetes secret (argocd-repo-creds) created with GitHub App credentials
- Hello-world application (echoserver) deployed and syncing automatically
- RBAC permissions validated (developer and devops roles)
- Auto-sync and self-heal functionality verified
- Initial admin password removed (SSO-only authentication)
- Nonprod configuration documented in repository

**Dependencies**:
- Phase 4.3 Module 3 complete with all verifications passing:
  - ✅ Section 3.1: SSL certificate ACTIVE
  - ✅ Section 3.2: All ArgoCD pods Running and Ready
  - ✅ Section 3.3: GKE Ingress external IP assigned
  - ✅ Section 3.4: DNS resolution verified
  - ✅ Section 3.5: HTTPS accessibility with valid SSL
  - ✅ Section 3.6: Google SSO login test passed
- ArgoCD CLI installed (v2.13.x or later)
- kubectl access to pcc-gke-devops-nonprod cluster
- Access to Secret Manager secret: argocd-github-app-credentials (project: pcc-prj-devops-nonprod)
- GitHub CLI (gh) installed for PR creation
- Repository permissions: Can create branches and PRs in core/pcc-app-argo-config
- Google Workspace group membership (gcp-developers or gcp-devops for testing)

**Duration Estimate**: 27-40 minutes total
- Module 1 (Pre-flight Checks): 3-5 min
- Module 2 (GitHub Integration): 6-9 min
- Module 3 (Application Deployment): 10-14 min (includes PR creation, merge, sync wait)
- Module 4 (Validation & Cleanup): 8-12 min
- Buffer: 0 min (no long-running async operations)
- Note: Shorter than Phase 4.3 (28-40 min vs 45-60 min) because no infrastructure provisioning or SSL cert wait. Module 3 takes longest due to Git workflow (branch, commit, PR, merge) and ArgoCD sync monitoring.

**Phase 4.5 Readiness Criteria** (checklist for proceeding to prod deployment):
- ✅ ArgoCD nonprod accessible via HTTPS with valid SSL certificate
- ✅ Google SSO authentication working for both groups (developers + devops)
- ✅ RBAC permissions validated (view + sync for developers, admin for devops)
- ✅ GitHub repository connected successfully via GitHub App
- ✅ Hello-world application deployed and syncing
- ✅ Auto-sync behavior validated (drift detection and self-heal working)
- ✅ Admin secret cleanup completed (SSO-only authentication enforced)
- ✅ Repository connection stable for 24 hours (no authentication errors)
- ✅ Application health monitoring functional
- ✅ Documentation created and committed to repository
- ✅ No errors in ArgoCD application-controller or repo-server logs for 24 hours

**Important**: Allow a **24-hour stabilization period** after completing Phase 4.4 Module 4 before proceeding to Phase 4.5. This waiting period validates repository connection stability and ArgoCD component health under normal operation (last two readiness criteria above).

---

### Prod Deployment (4 subphases)

#### Phase 4.5A: Apply Terraform for ArgoCD Prod Infrastructure (15-20 min)

**Objective**: Deploy GCP resources for prod ArgoCD ingress and security

**Execution Structure**: Sequential terraform deployment in 3 stages
1. **Stage 1: Reserve Static IPs** (2-3 min) - Create external IP addresses
2. **Stage 2: Configure DNS** (3-5 min) - Create DNS A records pointing to IPs
3. **Stage 3: Deploy Certificates & Policies** (8-10 min) - SSL certs, Cloud Armor, SSL policy

**Key Context**:
- Terraform configuration: `infra/pcc-app-shared-infra/terraform/argocd-ingress.tf` (from Phase 4.2B)
- Target environment: Prod only (argocd-east4.pcconnect.ai)
- Total resources: 4 resources for prod (IP, DNS, SSL cert, shared policies already created in 4.2C)
- Deployment strategy: Same staged apply pattern as Phase 4.2C
- **Prerequisites**: 24-hour stabilization period after Phase 4.4 complete (nonprod validated)

---

##### Stage 1: Reserve Static IPs (2-3 min)

**Purpose**: Create reserved external IP address for prod ArgoCD ingress

**Pre-flight Checks**:
- **Terraform backend configuration note**:
  - Backend config: `infra/pcc-app-shared-infra/terraform/backend.tf`
  - **If using shared GCS backend** (same bucket for nonprod + prod):
    - Verify nonprod resources exist: `cd infra/pcc-app-shared-infra/terraform && terraform state list | grep google_compute_address`
    - Expected: Shows `argocd_nonprod_ip` (from Phase 4.2C)
  - **If using separate backends** (different buckets or workspaces per environment):
    - Each environment has isolated state
    - Skip verification of nonprod resources (prod state is independent)
  - **Common pattern**: Shared state with environment-based resource naming (recommended for this project)

- **IAM permissions verification** (prod project):
  - Required roles for deployer (same as Phase 4.2C):
    - `compute.addresses.create`
    - `compute.sslCertificates.create`
    - `compute.securityPolicies.create`
    - `compute.sslPolicies.create`
    - `dns.resourceRecordSets.create`
  - Command: `gcloud projects get-iam-policy pcc-prj-devops-prod --flatten="bindings[].members" --filter="bindings.members:user:$(gcloud config get-value account)" --format="table(bindings.role)"`
  - Expected: Shows roles/compute.networkAdmin or roles/editor (or custom role with above permissions)

**Targeted Apply - Static IP (Prod)**:
- **Command**:
  ```bash
  terraform apply \
    -target=google_compute_address.argocd_prod_ip \
    -var="environment=prod" \
    -var="region=us-east4" \
    -var="dns_zone=pcconnect.ai" \
    -auto-approve
  ```
- **Single-line format**:
  `terraform apply -target=google_compute_address.argocd_prod_ip -var="environment=prod" -var="region=us-east4" -var="dns_zone=pcconnect.ai" -auto-approve`

- **Expected output**:
  ```
  google_compute_address.argocd_prod_ip: Creating...
  google_compute_address.argocd_prod_ip: Creation complete after 2s [id=projects/pcc-prj-devops-prod/regions/us-east4/addresses/argocd-east4-ip]

  Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
  ```

**IP Address Verification**:
- **Command**: `gcloud compute addresses describe argocd-east4-ip --region=us-east4 --project=pcc-prj-devops-prod --format="value(address)"`
- **Expected**: Returns external IP address (e.g., 35.45.67.89)
- **Capture IP for next stage**: `PROD_IP=$(gcloud compute addresses describe argocd-east4-ip --region=us-east4 --project=pcc-prj-devops-prod --format="value(address)")`

**Success Criteria**: Static IP reserved and status shows RESERVED

---

##### Stage 2: Configure DNS (3-5 min)

**Purpose**: Create DNS A record pointing to reserved static IP

**DNS A Record Apply**:
- **Command**:
  ```bash
  terraform apply \
    -target=google_dns_record_set.argocd_prod_a \
    -var="environment=prod" \
    -var="region=us-east4" \
    -var="dns_zone=pcconnect.ai" \
    -auto-approve
  ```
- **Single-line format**:
  `terraform apply -target=google_dns_record_set.argocd_prod_a -var="environment=prod" -var="region=us-east4" -var="dns_zone=pcconnect.ai" -auto-approve`

- **Expected output**:
  ```
  google_dns_record_set.argocd_prod_a: Creating...
  google_dns_record_set.argocd_prod_a: Creation complete after 3s

  Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
  ```

**DNS Propagation Wait**:
- **Wait time**: 30-60 seconds for DNS propagation
- **Command**: `sleep 60`

**DNS Resolution Verification**:
- **Command**: `dig +short argocd-east4.pcconnect.ai`
- **Expected**: Returns the reserved IP address from Stage 1
- **Alternative**: `nslookup argocd-east4.pcconnect.ai`
- **Retry if needed**: DNS propagation can take up to 5 minutes, retry dig command if no result

**Success Criteria**: DNS A record resolves to correct static IP

---

##### Stage 3: Deploy Certificates & Policies (8-10 min)

**Purpose**: Deploy SSL certificate for prod (policies already created in Phase 4.2C)

**Full Terraform Apply**:
- **Command**:
  ```bash
  terraform apply \
    -var="environment=prod" \
    -var="region=us-east4" \
    -var="dns_zone=pcconnect.ai" \
    -auto-approve
  ```
- **Single-line format**:
  `terraform apply -var="environment=prod" -var="region=us-east4" -var="dns_zone=pcconnect.ai" -auto-approve`

- **Expected output**:
  ```
  google_compute_managed_ssl_certificate.argocd_prod: Creating...

  google_compute_managed_ssl_certificate.argocd_prod: Creation complete after 5s

  Apply complete! Resources: 1 added, 0 changed, 0 destroyed.

  Outputs:
  argocd_nonprod_ip = "34.23.45.67"
  argocd_nonprod_cert = "argocd-nonprod-east4-pcconnect-ai"
  argocd_prod_ip = "35.45.67.89"
  argocd_prod_cert = "argocd-east4-pcconnect-ai"
  argocd_armor_policy_name = "argocd-cloud-armor"
  argocd_ssl_policy_name = "argocd-ssl-policy"
  ```
  - Note: Cloud Armor and SSL policies already exist (shared between nonprod and prod), so only SSL cert is new

**Resource Verification**:
1. **SSL Certificate (Prod)**:
   - Command: `gcloud compute ssl-certificates describe argocd-east4-pcconnect-ai --global --project=pcc-prj-devops-prod`
   - Expected status: `PROVISIONING` (will transition to ACTIVE when Ingress is created in Phase 4.5B)
   - Note: Certificate requires Ingress with matching domain to complete activation

2. **Cloud Armor Policy** (verify still exists, shared resource):
   - Command: `gcloud compute security-policies describe argocd-cloud-armor --project=pcc-prj-devops-nonprod`
   - Expected: Policy exists with rate limiting rules (unchanged from Phase 4.2C)

3. **SSL Policy** (verify still exists, shared resource):
   - Command: `gcloud compute ssl-policies describe argocd-ssl-policy --global --project=pcc-prj-devops-nonprod`
   - Expected: Min TLS version 1.2, profile MODERN (unchanged from Phase 4.2C)

**Terraform Output Capture**:
- **Command**: `terraform output -json > /tmp/argocd-prod-terraform-outputs.json`
- **Verify outputs**:
  ```bash
  cat /tmp/argocd-prod-terraform-outputs.json | jq '{
    prod_ip: .argocd_prod_ip.value,
    prod_cert: .argocd_prod_cert.value,
    armor_policy: .argocd_armor_policy_name.value,
    ssl_policy: .argocd_ssl_policy_name.value
  }'
  ```
- **Expected**: All 4 output values present and non-empty

**Success Criteria**: Prod SSL cert created, terraform outputs captured, shared policies verified

---

**Phase 4.5A Deliverables**:
- Static IP reserved: argocd-east4-ip (us-east4)
- DNS A record created: argocd-east4.pcconnect.ai → static IP
- Google-managed SSL certificate created: argocd-east4-pcconnect-ai (PROVISIONING status)
- Cloud Armor security policy: argocd-cloud-armor (shared, verified still exists)
- SSL policy: argocd-ssl-policy (shared, verified still exists)
- Terraform outputs captured for Phase 4.5B Helm values.yaml

**Dependencies**:
- Phase 4.4 complete with 24-hour stabilization period (nonprod validated and stable)
- Phase 4.2C complete (nonprod terraform already applied, shared policies created)
- Terraform state includes nonprod resources
- IAM permissions for Compute Engine and Cloud DNS (prod project)
- DNS zone `pcconnect.ai` exists and accessible

**Duration Estimate**: 15-20 minutes total
- Stage 1 (Static IP): 2-3 min
- Stage 2 (DNS): 3-5 min (includes DNS propagation wait)
- Stage 3 (Certificate): 8-10 min
- Buffer: 2 min

**Phase 4.5B Readiness Criteria** (terraform outputs for Helm deployment):
- ✅ Static IP address reserved and assigned
- ✅ DNS A record resolves to static IP
- ✅ SSL certificate created (PROVISIONING status acceptable, will activate when Ingress created)
- ✅ Cloud Armor policy verified (shared resource from Phase 4.2C)
- ✅ SSL policy verified (shared resource from Phase 4.2C)
- ✅ Terraform outputs available for ingress annotation values

**Note**: SSL certificate will remain in PROVISIONING status until Phase 4.5B creates the GKE Ingress resource. This is expected behavior - Google validates domain ownership via the Ingress.

---

#### Phase 4.5B: Install ArgoCD on Devops Prod Cluster (50-70 min)

**Objective**: Deploy ArgoCD v3.1.9 to pcc-gke-devops-prod cluster with HA configuration, Google SSO, and comprehensive validation

**Execution Structure**: Four modular sections executed sequentially
1. **Module 1: Pre-flight Checks** (5-8 min) - Verify Phase 4.5A outputs and create values-prod.yaml
2. **Module 2: Helm Deployment** (15-20 min) - Install ArgoCD with HA configuration
3. **Module 3: Component Verification** (15-20 min) - Verify HA pods, ingress, SSL, SSO
4. **Module 4: Backup & HA Validation** (15-22 min) - Test Redis PVC, backups, leader election, pod distribution

**Key Architectural Context**:
- ArgoCD version: v3.1.9 (Helm chart v7.7.4) - same as nonprod
- **Production HA configuration**:
  - API servers: 3 replicas (vs 1 in nonprod)
  - Repo servers: 2 replicas (vs 1 in nonprod)
  - Redis: 3 replicas with HA mode (vs 1 ephemeral in nonprod)
  - Application controller: 1 replica (stateful, cannot scale horizontally)
  - Dex server: 2 replicas (vs 1 in nonprod)
- **Redis persistence**: PVC with RDB snapshots + daily Cloud Storage backups (7-day retention)
- Ingress: GKE Ingress with Google-managed SSL cert (from Phase 4.5A terraform)
- DNS: `argocd-east4.pcconnect.ai` (from Phase 4.5A terraform)
- Auth: OAuth 2.0 via Google Workspace SSO (Dex connector)
- RBAC: gcp-devops@pcconnect.ai (admin), gcp-developers@pcconnect.ai (view + sync)

**Dependencies**:
- Phase 4.5A complete (terraform outputs available)
- Phase 4.4 complete with 24-hour stabilization period
- kubectl access to devops-prod cluster (Phase 3)
- Helm v3 installed locally

---

##### Module 1: Pre-flight Checks (5-8 min)

**Purpose**: Verify all prerequisites and create production Helm values file before deployment

**Section 1.1: Cluster Context Verification**
- **Action**: Verify kubectl is configured for correct cluster
- **Expected cluster context**: `gke_pcc-prj-devops-prod_us-east4_pcc-gke-devops-prod`
- **Verification method**: `kubectl config current-context`
- **Expected GCP project**: `pcc-prj-devops-prod`
- **Expected region**: `us-east4`
- **Cluster info verification**: `kubectl cluster-info` should show prod cluster endpoints
- **Node verification**: `kubectl get nodes` should return prod cluster nodes without permission errors
- **Critical**: STOP if cluster context is wrong - deploying to wrong cluster is catastrophic

**Section 1.2: Phase 4.5A Terraform Outputs Verification**
- **Action**: Verify all GCP resources from Phase 4.5A exist before deployment
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
     - Expected: Policy exists (shared resource from Phase 4.2C)
  5. **SSL policy**: `argocd-ssl-policy`
     - Verification: `gcloud compute ssl-policies describe argocd-ssl-policy --global --project=pcc-prj-devops-nonprod`
     - Expected: TLS 1.2+ policy exists (shared resource from Phase 4.2C)

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

**Section 1.4: Create Production Helm Values File**
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
      enabled: false  # Using GKE Ingress (created separately in Phase 4.5A)
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

  ## Redis (Session Storage + Caching) - HA Configuration
  ## Using redis-ha subchart for production HA with Sentinel
  redis-ha:
    enabled: true
    replicas: 3  # 3 Redis instances with Sentinel sidecars
    persistentVolume:
      enabled: true
      size: 10Gi
      storageClassName: "standard-rwo"  # GKE standard persistent disk
    redis:
      resources:
        requests:
          cpu: 100m
          memory: 256Mi
        limits:
          cpu: 200m
          memory: 512Mi
    ## Redis Sentinel for leader election and failover
    sentinel:
      enabled: true
      replicas: 3  # 3 Sentinel instances (one per Redis pod)
      resources:
        requests:
          cpu: 50m
          memory: 64Mi
        limits:
          cpu: 100m
          memory: 128Mi
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
  ```

- **Save values file**:
  - Command: `vi core/pcc-app-argo-config/helm/values-prod.yaml`
  - Paste YAML content above
  - Save and exit

- **Validate YAML syntax**:
  - Command: `helm lint core/pcc-app-argo-config/helm/values-prod.yaml` (may show warnings, that's OK)
  - Alternative: `cat core/pcc-app-argo-config/helm/values-prod.yaml | yq eval`

**Pre-flight Checks Output**: Go/No-Go decision
- **GO**: All 4 sections passed → Proceed to Module 2
- **NO-GO**: Any section failed → Stop, fix issues, re-run pre-flight checks

---

##### Module 2: Helm Deployment (15-20 min)

**Purpose**: Deploy ArgoCD via Helm with HA configuration and progressive status monitoring

**Section 2.1: Helm Install with HA Configuration**
- **Action**: Install ArgoCD using Helm with values-prod.yaml
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
    --wait \
    --timeout 15m
  ```
- **Single-line executable format**:
  `helm install argocd argo/argo-cd --version 7.7.4 --namespace argocd --create-namespace --values core/pcc-app-argo-config/helm/values-prod.yaml --wait --timeout 15m`

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

##### Module 3: Component Verification (15-20 min)

**Purpose**: Verify GKE Ingress, SSL certificate activation, and Google SSO functionality

**Section 3.1: GKE Ingress Resource Creation**
- **Action**: Create GKE Ingress resource to expose ArgoCD UI with Google-managed SSL
- **Ingress manifest** (`core/pcc-app-argo-config/manifests/argocd-prod-ingress.yaml`):
  ```yaml
  apiVersion: networking.k8s.io/v1
  kind: Ingress
  metadata:
    name: argocd-server-ingress
    namespace: argocd
    annotations:
      kubernetes.io/ingress.class: "gce"
      kubernetes.io/ingress.global-static-ip-name: "argocd-east4-ip"
      ingress.gke.io/pre-shared-cert: "argocd-east4-pcconnect-ai"  # Use pre-shared cert for terraform-created certificate
      kubernetes.io/ingress.allow-http: "false"
      cloud.google.com/armor-config: '{"argocd-cloud-armor": ""}'
  spec:
    defaultBackend:
      service:
        name: argocd-server
        port:
          number: 443
  ```

- **Create manifest file**:
  - Command: `vi core/pcc-app-argo-config/manifests/argocd-prod-ingress.yaml`
  - Paste YAML content above, save and exit

- **Apply Ingress**:
  - Command: `kubectl apply -f core/pcc-app-argo-config/manifests/argocd-prod-ingress.yaml`
  - Expected: `ingress.networking.k8s.io/argocd-server-ingress created`

- **Verify Ingress creation**:
  - Command: `kubectl -n argocd get ingress argocd-server-ingress`
  - Expected: Shows ADDRESS assigned (static IP from Phase 4.5A)

**Section 3.2: SSL Certificate Provisioning Wait**
- **Action**: Wait for Google-managed SSL certificate to transition from PROVISIONING to ACTIVE
- **Expected behavior**:
  - Certificate starts in PROVISIONING state (from Phase 4.5A)
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
- **Expected**: Returns static IP from Phase 4.5A (matches Ingress ADDRESS)
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
- **Phase 4.5B Complete**: ArgoCD prod fully deployed with HA configuration validated

---

**Phase 4.5B Deliverables**:
- ArgoCD v3.1.9 installed on devops-prod cluster with HA configuration
- 15 pods running (3 API servers, 2 repo servers, 3 Redis-HA, 3 HAProxy, 2 Dex, 1 controller, 1 applicationset)
- GKE Ingress configured with Google-managed SSL certificate (ACTIVE)
- HTTPS accessibility verified at https://argocd-east4.pcconnect.ai
- Google SSO functional for both groups (gcp-devops admin, gcp-developers view+sync)
- Redis persistence verified with 3x 10Gi PVCs
- Redis HA with Sentinel leader election verified (3 Sentinel instances)
- Pod distribution across multiple nodes verified
- **Note**: Cloud Storage backup automation deferred to Phase 4.6

**Duration Estimate**: 50-70 minutes total
- Module 1 (Pre-flight Checks): 5-8 min
- Module 2 (Helm Deployment): 15-20 min (includes progressive HA pod status checks)
- Module 3 (Component Verification): 15-20 min (includes SSL cert ACTIVE wait)
- Module 4 (Backup & HA Validation): 15-22 min (comprehensive validation)
- Buffer: 0 min (no additional async operations)
- Note: Longer than nonprod (50-70 min vs 28-40 min) due to HA validation, backup testing, and more pods to stabilize

**Phase 4.6 Readiness Criteria** (checklist for proceeding to cluster management configuration):
- ✅ ArgoCD prod accessible via HTTPS with valid SSL certificate (ACTIVE)
- ✅ Google SSO authentication working for both groups (devops + developers)
- ✅ RBAC permissions verified (admin for devops, view+sync for developers)
- ✅ All 15 HA pods Running and Ready
- ✅ Redis PVCs created and bound (3x 10Gi)
- ✅ Redis data persistence validated (survives pod restart)
- ✅ Cloud Storage backup bucket configured with 7-day retention policy
- ✅ Backup IAM bindings verified (repo-server SA has storage.objectCreator)
- ✅ Manual snapshot chain validated (PVC → RDB → Cloud Storage successful)
- ✅ Redis Sentinel HA verified (leader election active)
- ✅ Pod distribution across multiple nodes (not concentrated on single node)
- ✅ No errors in ArgoCD component logs (API server, repo-server, application-controller)
- ✅ Ingress backend healthy (GKE load balancer health checks passing)

---

#### Phase 4.6: Configure Cluster Management & Backup Automation (Prod) (45-60 min)

**Objective**: Register app-devtest cluster with prod ArgoCD and implement automated backup infrastructure

**Execution Structure**: Three modular sections executed sequentially
1. **Module 1: Pre-flight Checks** (5-8 min) - Verify Connect Gateway, Workload Identity, and IAM prerequisites
2. **Module 2: Cluster Registration & Backup Automation** (30-40 min) - Register cluster, deploy terraform backup infrastructure, configure CronJob
3. **Module 3: Validation** (7-10 min) - Verify cluster registration, backup automation, and full backup chain

**Key Architectural Context**:
- **Cluster management**: Prod ArgoCD manages app-devtest via Connect Gateway (private GKE cluster)
- **Authentication**: Service account `argocd-controller@pcc-prj-devops-prod.iam.gserviceaccount.com` with Workload Identity
- **Backup strategy**: Daily Redis RDB snapshots → Cloud Storage (7-day retention)
- **IAM prerequisites**: container.admin + gkehub.gatewayAdmin (from Phase 3)

**Dependencies**:
- Phase 4.5B complete (ArgoCD installed on prod with HA and Workload Identity)
- Phase 3 complete (Connect Gateway configured, IAM bindings applied: container.admin + gkehub.gatewayAdmin)
- kubectl access to both devops-prod and app-devtest clusters via Connect Gateway
- Terraform v1.6+ installed locally
- ArgoCD CLI installed and authenticated to prod instance

---

##### Module 1: Pre-flight Checks (5-8 min)

**Purpose**: Verify all prerequisites before cluster registration and backup deployment

**Section 1.1: Connect Gateway Validation**
- **Action**: Verify app-devtest cluster is registered with Connect Gateway and accessible
- **Fleet membership verification**:
  - Command: `gcloud container fleet memberships list --project pcc-prj-app-devtest`
  - Expected output:
    ```
    NAME                EXTERNAL_ID
    pcc-gke-app-devtest gke://projects/pcc-prj-app-devtest/locations/us-east4/clusters/pcc-gke-app-devtest
    ```
  - Success criteria: Membership exists with correct EXTERNAL_ID

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

- **Check application-controller ServiceAccount**:
  - Command: `kubectl get serviceaccount argocd-application-controller -n argocd -o yaml | grep "iam.gke.io/gcp-service-account"`
  - Expected output: `iam.gke.io/gcp-service-account: argocd-controller@pcc-prj-devops-prod.iam.gserviceaccount.com`
  - Note: ArgoCD Helm chart creates `argocd-application-controller` ServiceAccount for the controller component

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

- **Success criteria**: Both IAM roles present on app-devtest project

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
- **Cluster registration command**:
  ```bash
  argocd cluster add connectgateway_pcc-prj-app-devtest_us-east4_pcc-gke-app-devtest \
    --name app-devtest \
    --kubeconfig ~/.kube/config \
    --server-side-emojis
  ```

  **Alternative context format** (if above fails):
  ```bash
  argocd cluster add gke_pcc-prj-app-devtest_us-east4_pcc-gke-app-devtest \
    --name app-devtest \
    --kubeconfig ~/.kube/config \
    --server-side-emojis
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

**Section 2.3: Terraform Backup Infrastructure Deployment**
- **Action**: Deploy Cloud Storage bucket and IAM bindings for automated Redis backups
- **Navigate to terraform directory**:
  - Command: `cd /home/jfogarty/pcc/infra/pcc-app-shared-infra/terraform`

- **Verify terraform file exists**:
  - Command: `ls -la argocd-backup.tf`
  - Expected: File exists (created in this phase)
  - Contents: Cloud Storage bucket resource + IAM binding for argocd-controller SA

- **Initialize terraform** (if needed):
  - Command: `terraform init`
  - Expected: Terraform initializes, downloads Google provider
  - Note: Skip if already initialized in previous phases

- **Plan terraform changes**:
  - Command: `terraform plan -out=argocd-backup.tfplan`
  - Expected output:
    ```
    Terraform will perform the following actions:

      # google_storage_bucket.argocd_prod_backups will be created
      + resource "google_storage_bucket" "argocd_prod_backups" {
          + name          = "pcc-argocd-prod-backups"
          + location      = "US-EAST4"
          + storage_class = "STANDARD"
          ...
        }

      # google_storage_bucket_iam_member.argocd_backup_writer will be created
      + resource "google_storage_bucket_iam_member" "argocd_backup_writer" {
          + bucket = "pcc-argocd-prod-backups"
          + role   = "roles/storage.objectCreator"
          + member = "serviceAccount:argocd-controller@pcc-prj-devops-prod.iam.gserviceaccount.com"
          ...
        }

    Plan: 2 to add, 0 to change, 0 to destroy.
    ```
  - Success criteria: 2 resources to add (bucket + IAM binding)

- **Apply terraform**:
  - Command: `terraform apply argocd-backup.tfplan`
  - Expected output:
    ```
    google_storage_bucket.argocd_prod_backups: Creating...
    google_storage_bucket.argocd_prod_backups: Creation complete after 3s
    google_storage_bucket_iam_member.argocd_backup_writer: Creating...
    google_storage_bucket_iam_member.argocd_backup_writer: Creation complete after 2s

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
                env:
                - name: GOOGLE_APPLICATION_CREDENTIALS
                  value: /var/run/secrets/workload-identity/token
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

- **Verify backup lifecycle policy**:
  - Command: `gcloud storage buckets describe gs://pcc-argocd-prod-backups --format="value(lifecycle_config.rule)"`
  - Expected: Shows lifecycle rule with age=7 days, action=Delete
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
- **Next step**: Phase 4.6 complete, proceed to Phase 4.7 (GitHub Integration)

---

**Phase 4.6 Deliverables**:
- app-devtest cluster registered with prod ArgoCD via Connect Gateway
- Cluster credentials configured (argocd-manager SA in app-devtest)
- Cloud Storage backup bucket created: `pcc-argocd-prod-backups` (7-day retention)
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

**Phase 4.7 Readiness Criteria**:
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

#### Phase 4.7: Configure GitHub Integration (20-25 min)

**Objective**: Connect prod ArgoCD to GitHub repository

**Execution Structure**: Three modular sections executed sequentially
1. **Module 1: Pre-flight Checks** (5-7 min) - Verify ArgoCD operational, Secret Manager credentials, IAM bindings
2. **Module 2: GitHub Integration** (8-12 min) - Configure GitHub App with Workload Identity
3. **Module 3: Validation & Documentation** (7-10 min) - Test repository connection, HA validation, create docs

**Key Architectural Context** (from previous phases):
- GitHub integration: **GitHub App with Workload Identity** (NO SSH keys or tokens) - Phase 4.1C decision
- Secret Manager: `argocd-github-app-credentials` in pcc-prj-devops-prod
- Repository: `core/pcc-app-argo-config` (read-only access)
- Authentication flow: Kubernetes SA (argocd-repo-server) → GCP SA → GitHub App → Repository access
- Pattern reference: Same as Phase 4.4 nonprod, adapted for prod environment with HA validation
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

**Section 1.1: ArgoCD Operational Status Verification**
- **Action**: Verify all prod ArgoCD pods are running and services are accessible
- **Switch to prod cluster context**:
  - Command: `kubectl config use-context gke_pcc-prj-devops-prod_us-east4_pcc-gke-devops-prod`
  - Expected: Current context switches to prod cluster
  - Note: Ensures all subsequent kubectl commands target the correct cluster

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
- **Extract credentials from Secret Manager**:
  - Command:
    ```bash
    gcloud secrets versions access latest \
      --secret=argocd-github-app-credentials \
      --project=pcc-prj-devops-prod \
      --format='get(payload.data)' | base64 -d > /tmp/github-app-creds.json
    ```
  - Verify: `cat /tmp/github-app-creds.json` shows valid JSON with appId, installationId, privateKey
  - Note: Temporary file will be cleaned up after secret creation

- **Create Kubernetes secret**:
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

- **Workload Identity annotation**:
  - Command:
    ```bash
    kubectl annotate serviceaccount argocd-repo-server \
      --namespace argocd \
      iam.gke.io/gcp-service-account=argocd-repo-server@pcc-prj-devops-prod.iam.gserviceaccount.com \
      --overwrite
    ```
  - Expected: `serviceaccount/argocd-repo-server annotated`
  - Note: This enables Workload Identity for Secret Manager access and GitHub App authentication

- **Secret verification**:
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
- **Repository addition via ArgoCD CLI**:
  - Command structure (multi-line format):
    ```bash
    argocd repo add https://github.com/ORG/pcc-app-argo-config.git \
      --github-app-id $(kubectl -n argocd get secret argocd-repo-creds -o jsonpath='{.data.githubAppID}' | base64 -d) \
      --github-app-installation-id $(kubectl -n argocd get secret argocd-repo-creds -o jsonpath='{.data.githubAppInstallationID}' | base64 -d) \
      --github-app-private-key-path /dev/stdin \
      --name pcc-app-argo-config \
      --project default <<< $(kubectl -n argocd get secret argocd-repo-creds -o jsonpath='{.data.githubAppPrivateKey}' | base64 -d)
    ```
  - Replace `ORG` with actual GitHub organization name
  - Expected output: `Repository 'https://github.com/ORG/pcc-app-argo-config.git' added`
  - Note: Command reads GitHub App private key from stdin to avoid file storage

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
  1. Test DNS resolution from repo-server pod:
     - Command: `kubectl -n argocd exec deployment/argocd-repo-server -- nslookup github.com`
     - Expected: Resolves to GitHub IP addresses
  2. Test network connectivity:
     - Command: `kubectl -n argocd exec deployment/argocd-repo-server -- curl -I https://github.com`
     - Expected: HTTP 200 or 301 response
  3. Check Cloud NAT configuration (for private GKE cluster):
     - Command: `gcloud compute routers nats list --router=pcc-nat-devops-prod --region=us-east4 --project=pcc-prj-devops-prod`
     - Expected: NAT configuration exists for egress traffic
- **Resolution**: Verify network configuration, firewall rules allow HTTPS egress to github.com

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

- **Verify cleanup**:
  - Command: `argocd repo list`
  - Expected: pcc-app-argo-config repository no longer listed
  - Command: `kubectl -n argocd get secret argocd-repo-creds`
  - Expected: Error "NotFound"

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
  3. Recreate secret from Secret Manager (follow Section 2.1 from Phase 4.7)
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
  - Phase 4.7 Documentation: `.claude/plans/devtest-deployment/phase-4-working-notes.md`
  - Phase 4.1C Architectural Decisions: GitHub App with Workload Identity
  - ArgoCD Version: 2.13.x
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
- **Phase 4.7 Complete**: GitHub integration fully operational in prod environment

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
- Phase 4.6 complete (cluster management configured, app-devtest cluster registered)
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
- Verify Phase 4.6 cluster list shows app-devtest: `argocd cluster list`

---

#### Phase 4.8: Configure App-of-Apps Pattern (25-35 min)

**Objective**: Create app-of-apps framework in core/pcc-app-argo-config

**Activities**:
- Create root application (app-of-apps) **framework only** in `core/pcc-app-argo-config`
- Define application project structure (empty/minimal for now, will be populated in Phase 6+)
- Configure sync policies:
  - Auto-sync enabled for devtest environment
  - Automated pruning (optional)
  - Self-heal enabled
- Deploy app-of-apps to prod ArgoCD
- Verify app-of-apps syncs successfully
- Document app-of-apps pattern and directory structure

**Deliverables**:
- App-of-apps root application created
- Application project structure defined
- Sync policies configured
- App-of-apps deployed and syncing
- Pattern documentation

**Dependencies**:
- Phase 4.7 complete (GitHub integration working)
- `core/pcc-app-argo-config` repository structure planned

---

#### Phase 4.9: Validate Full ArgoCD Deployment (15-20 min)

**Objective**: End-to-end validation of both ArgoCD clusters

**Activities**:
- **Test nonprod ArgoCD**:
  - Hello-world app syncing correctly
  - Google SSO login works for both groups
  - RBAC permissions correct (developers: read-only, devops: admin)
  - UI accessible via public ingress
- **Test prod ArgoCD**:
  - Can access app-devtest cluster (cluster management working)
  - GitHub repository connection healthy
  - App-of-apps framework deployed successfully
  - Google SSO login works for both groups
  - RBAC permissions correct
  - UI accessible via public ingress
- Document access procedures (URLs, SSO login, RBAC)
- Document upgrade testing workflow (nonprod → prod)

**Deliverables**:
- Nonprod ArgoCD fully validated
- Prod ArgoCD fully validated
- Access procedures documented
- Upgrade workflow documented

**Dependencies**:
- Phase 4.8 complete (app-of-apps deployed)
- All previous phases complete

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
- [x] Phase 4.1A: Core Architecture Planning (REVIEWED - feedback incorporated)
- [x] Phase 4.1B: Security and Access Planning (REVIEWED - 8 issues: 1 CRITICAL, 3 HIGH, 4 MEDIUM - incorporated with adjustments: sync OK for devs, 90-day audit retention)
- [x] Phase 4.1C: Repository and Integration Planning (REVIEWED - 8 issues: 2 CRITICAL, 3 HIGH, 3 MEDIUM - corrections applied: GitHub App + Workload Identity, Google Cloud Observability, quarterly rotation, 7 alert thresholds)
- [x] Phase 4.2A: Plan ArgoCD Installation Configuration (REVIEWED - 8 issues: 3 CRITICAL, 3 HIGH, 2 MEDIUM - incorporated)
- [x] Phase 4.2B: Create Terraform for ArgoCD GCP Resources (REVIEWED - key decisions documented)
- [x] Phase 4.3: Install ArgoCD on Devops Nonprod Cluster (REVIEWED - 25 original issues RESOLVED, 6 minor cosmetic issues fixed - POLISHED, production-ready)
- [x] Phase 4.4: Configure & Test ArgoCD Nonprod (REVIEWED - 23 original issues RESOLVED, 5 minor LOW-severity issues fixed - POLISHED, GO recommendation)
- [ ] Phase 4.5: Install ArgoCD on Devops Prod Cluster
- [ ] Phase 4.6: Configure Cluster Management (Prod)
- [ ] Phase 4.7: Configure GitHub Integration
- [ ] Phase 4.8: Configure App-of-Apps Pattern
- [ ] Phase 4.9: Validate Full ArgoCD Deployment

---

## Next Steps

1. Review Phase 4.1 with agent-organizer (careful scoping)
2. Incorporate feedback
3. Continue through remaining subphases
4. Create individual phase documents after review complete
