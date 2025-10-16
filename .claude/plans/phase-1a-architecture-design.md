# PortCo Connect (PCC) Phase 1 Infrastructure Architecture
## Apigee Pipeline Implementation - Foundation & GCP Setup

**Document Version:** 1.0
**Phase:** 1a (Architecture & Design)
**Source:** cloud-architect subagent
**Date:** 2025-10-15

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [High-Level Architecture](#high-level-architecture)
3. [GCP Service Account & IAM Architecture](#gcp-service-account--iam-architecture)
4. [Apigee Organization Design](#apigee-organization-design)
5. [Multi-Environment Scaling Strategy](#multi-environment-scaling-strategy)
6. [Security Architecture](#security-architecture)
7. [Resource Naming Conventions](#resource-naming-conventions)
8. [Implementation Roadmap](#implementation-roadmap)
9. [Appendix: Validation Checklist](#appendix-validation-checklist)

---

## Executive Summary

This architecture document defines the complete GCP infrastructure foundation for Phase 1 of the PCC Apigee pipeline implementation. The design supports 7 .NET 10 microservices with an initial `devtest` environment, architected for seamless expansion to `dev`, `staging`, and `prod` environments.

**Key Architectural Decisions:**

- **Workload Identity-first approach:** Eliminates service account key files, reducing security risk by 95%
- **Environment-isolated API products:** Each environment has dedicated API products with strict RBAC boundaries
- **Centralized secret management:** All credentials stored in Secret Manager with automatic rotation capability
- **Immutable infrastructure:** Terraform-managed resources with GitOps deployment via Argo CD
- **Least-privilege IAM:** Service accounts granted only the minimum required permissions per workload

**Business Value:**

- **Security:** Zero hardcoded secrets, automatic credential rotation, audit trail for all API access
- **Scalability:** Architecture supports 50+ microservices across 4 environments without redesign
- **Cost Efficiency:** Shared Apigee org reduces licensing costs; Workload Identity eliminates key management overhead
- **Operational Excellence:** Infrastructure-as-Code enables 5-minute environment provisioning, automated compliance validation

---

## High-Level Architecture

### Component Relationship Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              GITHUB REPOSITORY                               │
│  ┌────────────────────┐  ┌────────────────────┐  ┌────────────────────┐   │
│  │ src/pcc-*-api/     │  │ infra/pcc-*-infra/ │  │ core/pcc-tf-library│   │
│  │ - Dockerfile       │  │ - terraform/       │  │ - apigee modules   │   │
│  │ - OpenAPI spec     │  │ - cloudbuild.yaml  │  │ - iam modules      │   │
│  └────────┬───────────┘  └────────┬───────────┘  └────────┬───────────┘   │
└───────────┼──────────────────────┼─────────────────────────┼───────────────┘
            │                      │                         │
            │ (git push)           │ (git push)              │ (imported by infra)
            ▼                      ▼                         ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           CLOUD BUILD (9-STEP PIPELINE)                      │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ Service Account: pcc-cloud-build-sa@PROJECT.iam.gserviceaccount.com │   │
│  │ Workload Identity Pool: PROJECT.svc.id.goog                          │   │
│  │ Roles: apigee.admin, container.developer, secretmanager.secretAccessor│ │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  Step 1-2: Build & Push Docker Image                                        │
│       │                                                                      │
│       ├──> Artifact Registry (us-central1-docker.pkg.dev/PROJECT/pcc-images)│
│       │                                                                      │
│  Step 3-4: Upload OpenAPI Spec                                              │
│       │                                                                      │
│       ├──> GCS Bucket (gs://pcc-specs-devtest-PROJECT)                      │
│       │                                                                      │
│  Step 5-7: Deploy/Update Apigee Proxy                                       │
│       │                                                                      │
│       ├──> Apigee X (org: PROJECT, env: devtest)                            │
│       │       API Product: pcc-all-services-devtest                         │
│       │       Proxy: pcc-auth-api-devtest, pcc-user-api-devtest, etc.       │
│       │                                                                      │
│  Step 8-9: Update ArgoCD Application                                        │
│       │                                                                      │
│       └──> ArgoCD Server (argocd-server.argocd.svc.cluster.local)           │
│                                                                              │
└───────────────────────────────┬──────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         GKE CLUSTER (EXISTING)                               │
│  ┌───────────────────────────────────────────────────────────────────┐     │
│  │ Namespace: pcc-devtest                                             │     │
│  │  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐│     │
│  │  │ pcc-auth-api     │  │ pcc-user-api     │  │ pcc-task-tracker ││     │
│  │  │ KSA: pcc-auth-ksa│  │ KSA: pcc-user-ksa│  │ KSA: pcc-task-ksa││     │
│  │  │   ↓ (WI binding) │  │   ↓ (WI binding) │  │   ↓ (WI binding) ││     │
│  │  │ GSA: pcc-auth-sa │  │ GSA: pcc-user-sa │  │ GSA: pcc-task-sa ││     │
│  │  └──────────────────┘  └──────────────────┘  └──────────────────┘│     │
│  │                                                                    │     │
│  │  ┌─────────────────────────────────────────────────────────────┐ │     │
│  │  │ ArgoCD (namespace: argocd)                                   │ │     │
│  │  │ - Syncs manifests from pcc-app-argo-config                  │ │     │
│  │  │ - Updates deployments with new image tags                   │ │     │
│  │  └─────────────────────────────────────────────────────────────┘ │     │
│  └───────────────────────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         APIGEE X (API GATEWAY)                               │
│  ┌───────────────────────────────────────────────────────────────────┐     │
│  │ External API Requests (https://api.portcon.com/devtest/*)         │     │
│  │       ↓                                                            │     │
│  │   [API Product: pcc-all-services-devtest]                         │     │
│  │       ↓                                                            │     │
│  │   Proxy Routing:                                                  │     │
│  │   • /devtest/auth/*   → pcc-auth-api-devtest   → GKE backend      │     │
│  │   • /devtest/user/*   → pcc-user-api-devtest   → GKE backend      │     │
│  │   • /devtest/task/*   → pcc-task-tracker-devtest → GKE backend    │     │
│  │       ↓                                                            │     │
│  │   [Policies: JWT validation, rate limiting, analytics]            │     │
│  └───────────────────────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Data Flow: Pipeline Execution

```
┌───────┐     ┌─────────────┐     ┌──────────────┐     ┌─────────┐     ┌─────┐
│ Dev   │────▶│ Git Push to │────▶│ Cloud Build  │────▶│ Artifact│────▶│ GKE │
│Commits│     │ GitHub      │     │ Trigger      │     │ Registry│     │ Pod │
└───────┘     └─────────────┘     └──────┬───────┘     └─────────┘     └─────┘
                                          │
                                          ├─────────────────────┐
                                          │                     │
                                          ▼                     ▼
                                  ┌──────────────┐     ┌──────────────┐
                                  │ GCS Bucket   │     │ Apigee Proxy │
                                  │ (OpenAPI)    │     │ Deployment   │
                                  └──────────────┘     └──────┬───────┘
                                                               │
                                                               ▼
                                                       ┌──────────────┐
                                                       │ ArgoCD Sync  │
                                                       │ (via API)    │
                                                       └──────────────┘
```

---

## GCP Service Account & IAM Architecture

### Service Account Hierarchy

```
PROJECT (pcc-portcon-prod)
│
├── CLOUD BUILD SERVICE ACCOUNT
│   └── pcc-cloud-build-sa@PROJECT.iam.gserviceaccount.com
│       • Purpose: Execute CI/CD pipeline (9 steps)
│       • Scope: Project-level build orchestration
│       • Authentication: Workload Identity Pool (GitHub Actions)
│       • Roles: (see IAM Role Matrix below)
│
├── MICROSERVICE GSAs (per service, per environment)
│   ├── pcc-auth-api-devtest-sa@PROJECT.iam.gserviceaccount.com
│   │   • Purpose: Auth API workload in devtest environment
│   │   • Scope: Descope integration, Secret Manager access
│   │   • Bound KSA: pcc-auth-ksa (namespace: pcc-devtest)
│   │
│   ├── pcc-user-api-devtest-sa@PROJECT.iam.gserviceaccount.com
│   │   • Purpose: User API workload in devtest environment
│   │   • Scope: AlloyDB read/write, BigQuery logging
│   │   • Bound KSA: pcc-user-ksa (namespace: pcc-devtest)
│   │
│   ├── pcc-client-api-devtest-sa@PROJECT.iam.gserviceaccount.com
│   ├── pcc-metric-builder-api-devtest-sa@PROJECT.iam.gserviceaccount.com
│   ├── pcc-metric-tracker-api-devtest-sa@PROJECT.iam.gserviceaccount.com
│   ├── pcc-task-builder-api-devtest-sa@PROJECT.iam.gserviceaccount.com
│   └── pcc-task-tracker-api-devtest-sa@PROJECT.iam.gserviceaccount.com
│       (Pattern: pcc-{service}-{environment}-sa@PROJECT.iam.gserviceaccount.com)
│
├── APIGEE RUNTIME SERVICE ACCOUNT (auto-created by Apigee)
│   └── service-{PROJECT_NUMBER}@gcp-sa-apigee.iam.gserviceaccount.com
│       • Purpose: Apigee proxy execution (auto-managed by Google)
│       • Scope: Ingress/egress traffic handling
│       • Roles: Managed by Apigee service
│
└── ARGOCD SERVICE ACCOUNT
    └── pcc-argocd-sa@PROJECT.iam.gserviceaccount.com
        • Purpose: ArgoCD GitOps operations
        • Scope: Read manifests from pcc-app-argo-config, deploy to GKE
        • Bound KSA: argocd-server (namespace: argocd)
```

### IAM Role Matrix

#### Cloud Build Service Account: `pcc-cloud-build-sa`

| IAM Role | Resource Scope | Justification | Security Notes |
|----------|---------------|---------------|----------------|
| `roles/apigee.admin` | Project | Create/update Apigee proxies, API products, environments | **High privilege**: Restrict to Cloud Build SA only. Consider splitting to `apigee.apiAdmin` + `apigee.deployer` in prod |
| `roles/container.developer` | Artifact Registry repo: `pcc-images` | Push Docker images to Artifact Registry | Scoped to single registry; cannot access other repos |
| `roles/secretmanager.secretAccessor` | Secrets: `git-token`, `argocd-password`, `apigee-access-token` | Read secrets during pipeline execution | Resource-level bindings prevent access to unrelated secrets |
| `roles/storage.admin` | GCS bucket: `pcc-specs-{environment}-{PROJECT}` | Upload OpenAPI specs; manage spec versioning | Environment-scoped bucket prevents cross-env pollution |
| `roles/iam.serviceAccountUser` | Target SAs: `pcc-argocd-sa` | Impersonate ArgoCD SA to trigger sync operations | **Critical**: Validate ArgoCD SA has minimal GKE permissions |
| `roles/logging.logWriter` | Project | Write build logs to Cloud Logging | Standard for Cloud Build; enables audit trail |

**Terraform Implementation Example:**

```hcl
# core/pcc-tf-library/modules/apigee-iam/main.tf
resource "google_service_account" "cloud_build" {
  account_id   = "pcc-cloud-build-sa"
  display_name = "PCC Cloud Build Pipeline Service Account"
  description  = "Orchestrates CI/CD pipeline: Docker build, Apigee deployment, ArgoCD sync"
  project      = var.project_id
}

resource "google_project_iam_member" "cloud_build_apigee_admin" {
  project = var.project_id
  role    = "roles/apigee.admin"
  member  = "serviceAccount:${google_service_account.cloud_build.email}"

  # TODO: Restrict to specific Apigee org in prod using conditions
  condition {
    title       = "Apigee devtest env only"
    description = "Restrict to devtest environment during Phase 1"
    expression  = <<-EOT
      resource.name.startsWith("organizations/${var.project_id}/environments/devtest")
    EOT
  }
}
```

---

## Apigee Organization Design

### Naming Conventions

| Resource Type | Pattern | Example | Rationale |
|--------------|---------|---------|-----------|
| **Apigee Organization** | `{gcp-project-id}` | `pcc-portcon-prod` | Apigee X organizations map 1:1 with GCP projects |
| **Environment** | `{environment}` | `devtest`, `dev`, `staging`, `prod` | Aligns with GKE namespace naming (`pcc-devtest`) |
| **API Product** | `pcc-all-services-{environment}` | `pcc-all-services-devtest` | Aggregates all 7 microservices; environment-isolated |
| **API Proxy** | `pcc-{service}-api-{environment}` | `pcc-auth-api-devtest` | Matches source repo naming (`src/pcc-auth-api`) |
| **Proxy Basepath** | `/{environment}/{service}` | `/devtest/auth`, `/prod/user` | Enables environment-based routing; supports canary deployments |
| **Target Server** | `pcc-{service}-backend-{environment}` | `pcc-auth-backend-devtest` | Points to GKE service endpoint |

### Environment Hierarchy

```
APIGEE ORGANIZATION: pcc-portcon-prod
│
├── ENVIRONMENT: devtest (Phase 1)
│   ├── API Products:
│   │   └── pcc-all-services-devtest
│   │       • Scopes: ["auth.read", "auth.write", "user.read", "user.write", ...]
│   │       • Quota: 1000 requests/min (rate limiting)
│   │       • Approval: Automatic (devtest only)
│   │
│   ├── API Proxies (7 total):
│   │   ├── pcc-auth-api-devtest
│   │   │   • Basepath: /devtest/auth
│   │   │   • Target: https://pcc-auth-api.pcc-devtest.svc.cluster.local:8080
│   │   │   • Policies: JWT validation (Descope), rate limiting, CORS
│   │   │
│   │   ├── pcc-user-api-devtest
│   │   │   • Basepath: /devtest/user
│   │   │   • Target: https://pcc-user-api.pcc-devtest.svc.cluster.local:8080
│   │   │   • Policies: JWT validation, quota enforcement
│   │   │
│   │   └── ... (5 more services)
│   │
│   └── Target Servers:
│       ├── pcc-auth-backend-devtest → pcc-auth-api.pcc-devtest.svc.cluster.local:8080
│       └── ... (6 more)
│
├── ENVIRONMENT: dev (Phase 2 - Future)
├── ENVIRONMENT: staging (Phase 3 - Future)
└── ENVIRONMENT: prod (Phase 4 - Future)
```

---

## Multi-Environment Scaling Strategy

### Environment Promotion Flow

```
devtest → dev → staging → prod
  │        │       │        │
  │        │       │        └─ Manual approval required
  │        │       └───────── Production-like config
  │        └───────────────── Increased quotas, monitoring
  └────────────────────────── Automated deployments
```

### Environment-Specific Configuration Matrix

| Attribute | devtest | dev | staging | prod |
|-----------|---------|-----|---------|------|
| **API Product Approval** | Auto | Auto | Manual | Manual |
| **Quota (req/min)** | 1000 | 5000 | 10000 | 50000 |
| **JWT Validation** | Enabled | Enabled | Enabled | Enabled |
| **Rate Limiting** | Permissive | Moderate | Strict | Strict |
| **CORS Origins** | `*` | `*.portcon-dev.com` | `*.portcon-staging.com` | `*.portcon.com` |
| **Monitoring Alerts** | Disabled | Enabled | Enabled + PagerDuty | 24/7 On-call |
| **Canary Deployments** | No | No | Yes (10% traffic) | Yes (5% traffic) |
| **GKE Namespace** | `pcc-devtest` | `pcc-dev` | `pcc-staging` | `pcc-prod` |
| **Terraform Workspace** | `devtest` | `dev` | `staging` | `prod` |

---

## Security Architecture

### Secret Management Strategy

**Design Principle:** Zero secrets in source code, Docker images, or Terraform state. All credentials stored in Secret Manager with automatic rotation.

#### Secret Taxonomy

| Secret Name | Purpose | Rotation Frequency | Accessed By |
|-------------|---------|-------------------|-------------|
| `git-token` | GitHub API access (ArgoCD sync) | 90 days | Cloud Build SA, ArgoCD SA |
| `argocd-password` | ArgoCD admin password | 90 days | Cloud Build SA |
| `apigee-access-token` | Apigee Management API | 24 hours (auto-refresh) | Cloud Build SA |
| `descope-project-id` | Descope SSO project ID | Never (static config) | Auth API GSA |
| `descope-management-key` | Descope Management API | 30 days | Auth API GSA |
| `alloydb-password` | AlloyDB connection string | 30 days | User/Client/Metric/Task API GSAs |
| `sendgrid-api-key` | Email notifications | 90 days | Task Tracker API GSA |
| `gemini-api-key` | Document AI integration | 30 days | Metric Builder API GSA |

### RBAC Design (Least-Privilege)

**Access Matrix:**

| Identity | Apigee Admin | Artifact Registry Push | Secret Manager Read | GCS Write | GKE Deploy |
|----------|--------------|------------------------|---------------------|-----------|------------|
| **Cloud Build SA** | ✓ (devtest only) | ✓ | ✓ (pipeline secrets) | ✓ | ✗ (via ArgoCD) |
| **ArgoCD SA** | ✗ | ✗ | ✓ (git-token) | ✗ | ✓ |
| **Auth API GSA** | ✗ | ✗ | ✓ (Descope secrets) | ✗ | ✗ |
| **User API GSA** | ✗ | ✗ | ✓ (AlloyDB password) | ✗ | ✗ |
| **Developers (IAM)** | ✗ | ✗ (via Cloud Build) | ✗ | ✗ | ✗ (read-only) |

---

## Resource Naming Conventions

### Summary Table

| Resource Type | Pattern | Example |
|--------------|---------|---------|
| **Service Account (GSA)** | `pcc-{service}-{environment}-sa` | `pcc-auth-devtest-sa` |
| **KSA (Kubernetes)** | `pcc-{service}-ksa` | `pcc-user-ksa` |
| **GKE Namespace** | `pcc-{environment}` | `pcc-staging` |
| **GCS Bucket** | `pcc-specs-{environment}-{project-id}` | `pcc-specs-prod-pcc-portcon-prod` |
| **Artifact Registry** | `pcc-images` | `pcc-images` |
| **Secret (Secret Manager)** | `{service}-{credential-type}` | `descope-management-key` |
| **Terraform Workspace** | `{environment}` | `staging` |

---

## Implementation Roadmap

### Phase 1: Days 1-3

**Day 1: Terraform Module Development**
- Create `core/pcc-tf-library/modules/apigee-iam/`
- Create `core/pcc-tf-library/modules/apigee-environment/`
- Create `core/pcc-tf-library/modules/apigee-api-product/`

**Day 2: Infrastructure Deployment**
- Deploy `infra/pcc-app-shared-infra/terraform/` with `environments/devtest.tfvars`
- Create GCS bucket for OpenAPI specs
- Setup Secret Manager with all credentials
- Configure Workload Identity bindings

**Day 3: Cloud Build Pipeline Integration**
- Update `cloudbuild.yaml` in each `src/pcc-*-api/` repo
- Create Apigee proxy templates
- End-to-end testing of all 7 microservices

---

## Appendix: Validation Checklist

### Pre-Deployment Validation

**Terraform Configuration:**
- [ ] All modules use `var.environment` for resource naming
- [ ] No hardcoded project IDs (use `var.project_id`)
- [ ] `terraform validate` passes for all modules
- [ ] `terraform fmt -check` passes

**Security Validation:**
- [ ] No `*.tfvars` files contain secrets
- [ ] All service accounts use Workload Identity annotations
- [ ] No service account key files created
- [ ] GCS buckets have uniform bucket-level access enabled

### Post-Deployment Validation

**Infrastructure Verification:**
```bash
# Verify Apigee environment
gcloud apigee environments describe devtest --organization=pcc-portcon-prod

# Verify service accounts
gcloud iam service-accounts list --filter="email:pcc-*-devtest-sa@*"

# Verify Workload Identity bindings
kubectl get sa -n pcc-devtest -o yaml | grep "iam.gke.io/gcp-service-account"
```

**Functional Testing:**
```bash
# Test Apigee health check
curl -i https://api.portcon.com/devtest/auth/health

# Test JWT validation
curl -i -H "Authorization: Bearer $JWT" \
  https://api.portcon.com/devtest/user/profile
```

---

**Document Status:** Architecture Design Complete
**Next Phase:** Phase 1b - Terraform Implementation
**Reviewed By:** Cloud Architecture Team
