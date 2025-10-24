# Phase 3.4: Cross-Project IAM Bindings

**Phase**: 3.4 (GKE Clusters - Cross-Project IAM)
**Duration**: 20-25 minutes
**Type**: Planning/Documentation
**Status**: 📋 Planning (Not Started)
**Date**: TBD (10/21+)

---

## Objective

Document terraform for ArgoCD service accounts, Workload Identity bindings, and cross-project IAM patterns to enable CI/CD and GitOps workflows across devops-nonprod, devops-prod, and app-devtest projects.

## Prerequisites

✅ Phase 3.3 completed (GKE cluster terraform documented)
✅ Understanding of service account principals
✅ Understanding of cross-project IAM requirements

---

## IAM Binding Patterns

### Pattern 1: Cloud Build → Artifact Registry

**Principal**: Cloud Build service account from `pcc-prj-app-devtest`
**Target Project**: `pcc-prj-devops-prod`
**Role**: `roles/artifactregistry.writer`
**Purpose**: Allow CI/CD pipeline to push Docker images to Artifact Registry

**Service Account**:
```
<PROJECT_NUMBER>@cloudbuild.gserviceaccount.com
```
Where `<PROJECT_NUMBER>` is the project number of `pcc-prj-app-devtest`

**Use Case**:
- Cloud Build builds Docker images in `pcc-prj-app-devtest`
- Images pushed to Artifact Registry in `pcc-prj-devops-prod`
- Cross-project access required (build in one project, store in another)

---

### Pattern 2: Cloud Build → Secret Manager

**Principal**: Cloud Build service account from `pcc-prj-app-devtest`
**Target Project**: `pcc-prj-app-devtest`
**Role**: `roles/secretmanager.secretAccessor`
**Purpose**: Allow CI/CD pipeline to read database credentials during Flyway migrations

**Service Account**:
```
<PROJECT_NUMBER>@cloudbuild.gserviceaccount.com
```
Where `<PROJECT_NUMBER>` is the project number of `pcc-prj-app-devtest`

**Use Case**:
- Cloud Build runs Flyway migrations during build
- Flyway needs AlloyDB credentials from Secret Manager
- Credentials stored in `pcc-prj-app-devtest` project
- Same-project secret access (not cross-project)

---

### Pattern 3: ArgoCD Service Accounts & Workload Identity

**Purpose**: Create dedicated GCP service accounts for ArgoCD instances and bind them to Kubernetes service accounts via Workload Identity

**Why Dedicated GCP SAs?** (Google Best Practice)
- Clear separation between Kubernetes (K8s SA) and GCP (GSA) identities
- Better auditing: logs show `argocd-controller@...` instead of K8s principal
- Easier to manage, rotate, and reuse across projects
- Standard Workload Identity pattern recommended by Google

#### 3a. ArgoCD Prod Service Account

**GCP Service Account**: `argocd-controller@pcc-prj-devops-prod.iam.gserviceaccount.com`
**Project**: `pcc-prj-devops-prod`
**Purpose**: Primary ArgoCD instance that manages all 3 GKE clusters

**Workload Identity Binding**:
- **K8s Service Account**: `argocd/argocd-application-controller` (in devops-prod cluster)
- **GCP Service Account**: `argocd-controller@pcc-prj-devops-prod.iam.gserviceaccount.com`
- **Role**: `roles/iam.workloadIdentityUser`

#### 3b. ArgoCD Nonprod Service Account

**GCP Service Account**: `argocd-controller@pcc-prj-devops-nonprod.iam.gserviceaccount.com`
**Project**: `pcc-prj-devops-nonprod`
**Purpose**: Test ArgoCD instance for testing updates before rolling to production

**Workload Identity Binding**:
- **K8s Service Account**: `argocd/argocd-application-controller` (in devops-nonprod cluster)
- **GCP Service Account**: `argocd-controller@pcc-prj-devops-nonprod.iam.gserviceaccount.com`
- **Role**: `roles/iam.workloadIdentityUser`

---

### Pattern 4: ArgoCD Cross-Project IAM

**Purpose**: Grant ArgoCD service accounts permissions to manage GKE clusters AND access them via Connect Gateway

**Required Roles** (per project):
1. `roles/container.admin` - GKE cluster management (deploy, manage workloads)
2. `roles/gkehub.gatewayAdmin` - Connect Gateway access (required for private clusters)

**Why Both Roles?**
- **container.admin**: Allows ArgoCD to deploy applications, manage namespaces, create services
- **gkehub.gatewayAdmin**: Allows ArgoCD to connect to private cluster endpoints via Connect Gateway
- Without Gateway role: ArgoCD cannot access clusters (they have fully private endpoints)

#### 4a. ArgoCD Prod → All 3 GKE Clusters

**Principal**: `argocd-controller@pcc-prj-devops-prod.iam.gserviceaccount.com`
**Target Projects**: All 3 projects (devops-nonprod, devops-prod, app-devtest)
**Roles**:
- `roles/container.admin` (cluster management)
- `roles/gkehub.gatewayAdmin` (Connect Gateway access)

**Why All 3 Clusters?**
1. **DevOps Nonprod**: Deploy monitoring tools, utilities
2. **DevOps Prod**: Self-managed ArgoCD via GitOps
3. **App Devtest**: Deploy all 7 microservices

#### 4b. ArgoCD Nonprod → DevOps Nonprod Cluster Only

**Principal**: `argocd-controller@pcc-prj-devops-nonprod.iam.gserviceaccount.com`
**Target Project**: `pcc-prj-devops-nonprod` only
**Roles**:
- `roles/container.admin` (cluster management)
- `roles/gkehub.gatewayAdmin` (Connect Gateway access)

**Why Only Nonprod?**
- Test ArgoCD updates in isolated environment
- Cannot affect production clusters
- Safe testing before promoting to prod

---

## Terraform Implementation

### File: infra/pcc-app-shared-infra/terraform/iam.tf

```hcl
# Get project numbers for service account references
data "google_project" "app_devtest" {
  project_id = "pcc-prj-app-devtest"
}

data "google_project" "devops_nonprod" {
  project_id = "pcc-prj-devops-nonprod"
}

data "google_project" "devops_prod" {
  project_id = "pcc-prj-devops-prod"
}

# ============================================================================
# Pattern 1: Cloud Build → Artifact Registry
# ============================================================================
resource "google_project_iam_member" "cloudbuild_to_artifact_registry" {
  project = "pcc-prj-devops-prod"
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${data.google_project.app_devtest.number}@cloudbuild.gserviceaccount.com"
}

# ============================================================================
# Pattern 2: Cloud Build → Secret Manager
# ============================================================================
resource "google_project_iam_member" "cloudbuild_to_secret_manager" {
  project = "pcc-prj-app-devtest"
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${data.google_project.app_devtest.number}@cloudbuild.gserviceaccount.com"
}

# ============================================================================
# Pattern 3: ArgoCD Service Accounts & Workload Identity
# ============================================================================

# 3a. Create ArgoCD Prod GCP Service Account
resource "google_service_account" "argocd_prod" {
  project      = "pcc-prj-devops-prod"
  account_id   = "argocd-controller"
  display_name = "ArgoCD Controller (Production)"
  description  = "Service account for ArgoCD to manage deployments across all GKE clusters"
}

# 3b. Create ArgoCD Nonprod GCP Service Account
resource "google_service_account" "argocd_nonprod" {
  project      = "pcc-prj-devops-nonprod"
  account_id   = "argocd-controller"
  display_name = "ArgoCD Controller (Nonprod)"
  description  = "Service account for testing ArgoCD updates in nonprod cluster"
}

# NOTE: Workload Identity bindings moved to Phase 4
# The K8s service accounts (argocd/argocd-application-controller) are created
# when ArgoCD is deployed in Phase 4. WI bindings will be created then via:
#
# resource "google_service_account_iam_member" "argocd_prod_workload_identity" {
#   service_account_id = google_service_account.argocd_prod.name
#   role               = "roles/iam.workloadIdentityUser"
#   member             = "serviceAccount:pcc-prj-devops-prod.svc.id.goog[argocd/argocd-application-controller]"
# }
#
# resource "google_service_account_iam_member" "argocd_nonprod_workload_identity" {
#   service_account_id = google_service_account.argocd_nonprod.name
#   role               = "roles/iam.workloadIdentityUser"
#   member             = "serviceAccount:pcc-prj-devops-nonprod.svc.id.goog[argocd/argocd-application-controller]"
# }

# ============================================================================
# Pattern 4: ArgoCD Cross-Project IAM
# ============================================================================

# 4a. ArgoCD Prod → DevOps Nonprod cluster
resource "google_project_iam_member" "argocd_prod_to_gke_devops_nonprod" {
  project = "pcc-prj-devops-nonprod"
  role    = "roles/container.admin"
  member  = "serviceAccount:${google_service_account.argocd_prod.email}"

  depends_on = [module.gke_devops_nonprod]
}

# 4a. ArgoCD Prod → DevOps Prod cluster
resource "google_project_iam_member" "argocd_prod_to_gke_devops_prod" {
  project = "pcc-prj-devops-prod"
  role    = "roles/container.admin"
  member  = "serviceAccount:${google_service_account.argocd_prod.email}"

  depends_on = [module.gke_devops_prod]
}

# 4a. ArgoCD Prod → App Devtest cluster
resource "google_project_iam_member" "argocd_prod_to_gke_app_devtest" {
  project = "pcc-prj-app-devtest"
  role    = "roles/container.admin"
  member  = "serviceAccount:${google_service_account.argocd_prod.email}"

  depends_on = [module.gke_app_devtest]
}

# 4b. ArgoCD Nonprod → DevOps Nonprod cluster only
resource "google_project_iam_member" "argocd_nonprod_to_gke_devops_nonprod" {
  project = "pcc-prj-devops-nonprod"
  role    = "roles/container.admin"
  member  = "serviceAccount:${google_service_account.argocd_nonprod.email}"

  depends_on = [module.gke_devops_nonprod]
}

# ============================================================================
# Pattern 5: ArgoCD Connect Gateway Access
# ============================================================================
# Required for ArgoCD to access private GKE clusters via Connect Gateway.
# Without these bindings, ArgoCD cannot connect to clusters (fully private endpoints).

# 5a. ArgoCD Prod → Connect Gateway access to all 3 projects
resource "google_project_iam_member" "argocd_prod_gateway_devops_nonprod" {
  project = "pcc-prj-devops-nonprod"
  role    = "roles/gkehub.gatewayAdmin"
  member  = "serviceAccount:${google_service_account.argocd_prod.email}"

  depends_on = [module.gke_devops_nonprod]
}

resource "google_project_iam_member" "argocd_prod_gateway_devops_prod" {
  project = "pcc-prj-devops-prod"
  role    = "roles/gkehub.gatewayAdmin"
  member  = "serviceAccount:${google_service_account.argocd_prod.email}"

  depends_on = [module.gke_devops_prod]
}

resource "google_project_iam_member" "argocd_prod_gateway_app_devtest" {
  project = "pcc-prj-app-devtest"
  role    = "roles/gkehub.gatewayAdmin"
  member  = "serviceAccount:${google_service_account.argocd_prod.email}"

  depends_on = [module.gke_app_devtest]
}

# 5b. ArgoCD Nonprod → Connect Gateway access to nonprod project only
resource "google_project_iam_member" "argocd_nonprod_gateway_devops_nonprod" {
  project = "pcc-prj-devops-nonprod"
  role    = "roles/gkehub.gatewayAdmin"
  member  = "serviceAccount:${google_service_account.argocd_nonprod.email}"

  depends_on = [module.gke_devops_nonprod]
}
```

---

## IAM Binding Details

### Cloud Build Service Account

**Format**: `<PROJECT_NUMBER>@cloudbuild.gserviceaccount.com`

**Automatically Created**: When Cloud Build API is enabled

**Get Project Number**:
```bash
gcloud projects describe pcc-prj-app-devtest --format="value(projectNumber)"
```

**Example**:
- Project Number: 123456789012
- Service Account: `123456789012@cloudbuild.gserviceaccount.com`

---

### ArgoCD GCP Service Accounts

**ArgoCD Prod**:
- **Email**: `argocd-controller@pcc-prj-devops-prod.iam.gserviceaccount.com`
- **Project**: pcc-prj-devops-prod
- **Created**: Terraform (Phase 3)
- **Purpose**: Manage all 3 GKE clusters (nonprod, prod, app-devtest)

**ArgoCD Nonprod**:
- **Email**: `argocd-controller@pcc-prj-devops-nonprod.iam.gserviceaccount.com`
- **Project**: pcc-prj-devops-nonprod
- **Created**: Terraform (Phase 3)
- **Purpose**: Test ArgoCD updates in nonprod cluster only

---

### Workload Identity Bindings

**How It Works**:
1. Terraform creates GCP service account (e.g., `argocd-controller@pcc-prj-devops-prod.iam.gserviceaccount.com`)
2. Terraform grants `roles/iam.workloadIdentityUser` to K8s SA principal
3. When ArgoCD pod starts (Phase 4), K8s SA `argocd/argocd-application-controller` can impersonate the GCP SA
4. GCP logs show `argocd-controller@...` performed actions (not K8s principal)

**Prod Binding**:
- **K8s SA**: `argocd/argocd-application-controller` (in pcc-prj-devops-prod cluster)
- **GCP SA**: `argocd-controller@pcc-prj-devops-prod.iam.gserviceaccount.com`
- **K8s Principal**: `serviceAccount:pcc-prj-devops-prod.svc.id.goog[argocd/argocd-application-controller]`

**Nonprod Binding**:
- **K8s SA**: `argocd/argocd-application-controller` (in pcc-prj-devops-nonprod cluster)
- **GCP SA**: `argocd-controller@pcc-prj-devops-nonprod.iam.gserviceaccount.com`
- **K8s Principal**: `serviceAccount:pcc-prj-devops-nonprod.svc.id.goog[argocd/argocd-application-controller]`

**Note**: K8s service accounts created in Phase 4 when ArgoCD is deployed. Workload Identity binding takes effect when K8s SA exists.

---

## Cross-Project IAM Architecture

### Flow Diagram

```
┌─────────────────────┐
│ pcc-prj-app-devtest │
│                     │
│  Cloud Build SA     │────────┐
│  (Builds images)    │        │
└─────────────────────┘        │
                               │ (1) Push images
                               ▼
                    ┌──────────────────────┐
                    │ pcc-prj-devops-prod  │
                    │                      │
                    │ Artifact Registry    │
                    │ (Stores images)      │
                    └──────────────────────┘

┌─────────────────────┐
│ pcc-prj-app-devtest │
│                     │
│  Cloud Build SA     │────────┐
│  (Runs Flyway)      │        │
└─────────────────────┘        │
                               │ (2) Read secrets
                               ▼
                    ┌──────────────────────┐
                    │ pcc-prj-app-devtest  │
                    │                      │
                    │ Secret Manager       │
                    │ (DB credentials)     │
                    └──────────────────────┘

┌──────────────────────┐
│ pcc-prj-devops-prod  │
│                      │
│  ArgoCD Controller   │────────┐
│  (GitOps engine)     │        │
└──────────────────────┘        │
                                │ (3) Deploy to all 3 clusters
                                ▼
        ┌───────────────────────────────────────┐
        │                                       │
        ▼                                       ▼
┌───────────────────┐               ┌────────────────────┐
│ pcc-prj-devops-   │               │ pcc-prj-app-       │
│ nonprod           │               │ devtest            │
│                   │               │                    │
│ GKE Cluster       │               │ GKE Cluster        │
│ (Monitoring)      │               │ (Microservices)    │
└───────────────────┘               └────────────────────┘
```

---

## Security Considerations

### Principle of Least Privilege

**Cloud Build**:
- Only `writer` to Artifact Registry (can push, not delete repos)
- Only `secretAccessor` to Secret Manager (read-only, cannot create/delete secrets)
- Scoped to specific projects only

**ArgoCD**:
- `container.admin` role (required for full deployment management)
- Limited to GKE clusters only (not broader project access)
- Uses Workload Identity (no long-lived credentials)

### Workload Identity Benefits

- No service account keys (no credentials to manage/rotate)
- Automatic token exchange (K8s SA → GCP SA)
- Auditable (GCP IAM logs show which K8s SA made requests)
- Revocable (delete K8s SA or IAM binding)

---

## Validation

### After Terraform Apply

**Verify Cloud Build Bindings**:
```bash
# Check Artifact Registry access
gcloud projects get-iam-policy pcc-prj-devops-prod \
  --flatten="bindings[].members" \
  --format="table(bindings.role)" \
  --filter="bindings.members:<PROJECT_NUMBER>@cloudbuild.gserviceaccount.com"

# Check Secret Manager access
gcloud projects get-iam-policy pcc-prj-app-devtest \
  --flatten="bindings[].members" \
  --format="table(bindings.role)" \
  --filter="bindings.members:<PROJECT_NUMBER>@cloudbuild.gserviceaccount.com"
```

**Verify ArgoCD Service Accounts Created**:
```bash
# Check ArgoCD Prod SA
gcloud iam service-accounts describe argocd-controller@pcc-prj-devops-prod.iam.gserviceaccount.com \
  --project=pcc-prj-devops-prod

# Check ArgoCD Nonprod SA
gcloud iam service-accounts describe argocd-controller@pcc-prj-devops-nonprod.iam.gserviceaccount.com \
  --project=pcc-prj-devops-nonprod
```

**Note**: Workload Identity bindings are deferred to Phase 4 when Kubernetes service accounts are created by ArgoCD deployment. No validation needed in this phase.

**Verify ArgoCD Cross-Project IAM**:
```bash
# ArgoCD Prod should have container.admin in all 3 projects
gcloud projects get-iam-policy pcc-prj-devops-nonprod \
  --flatten="bindings[].members" \
  --format="table(bindings.role)" \
  --filter="bindings.members:*argocd-controller@pcc-prj-devops-prod*"

gcloud projects get-iam-policy pcc-prj-devops-prod \
  --flatten="bindings[].members" \
  --format="table(bindings.role)" \
  --filter="bindings.members:*argocd-controller@pcc-prj-devops-prod*"

gcloud projects get-iam-policy pcc-prj-app-devtest \
  --flatten="bindings[].members" \
  --format="table(bindings.role)" \
  --filter="bindings.members:*argocd-controller@pcc-prj-devops-prod*"

# ArgoCD Nonprod should have container.admin only in nonprod
gcloud projects get-iam-policy pcc-prj-devops-nonprod \
  --flatten="bindings[].members" \
  --format="table(bindings.role)" \
  --filter="bindings.members:*argocd-controller@pcc-prj-devops-nonprod*"
```

**Verify ArgoCD Connect Gateway Access**:
```bash
# ArgoCD Prod should have gkehub.gatewayAdmin in all 3 projects
gcloud projects get-iam-policy pcc-prj-devops-nonprod \
  --flatten="bindings[].members" \
  --format="table(bindings.role)" \
  --filter="bindings.members:*argocd-controller@pcc-prj-devops-prod*"
# Expected: roles/container.admin AND roles/gkehub.gatewayAdmin

gcloud projects get-iam-policy pcc-prj-devops-prod \
  --flatten="bindings[].members" \
  --format="table(bindings.role)" \
  --filter="bindings.members:*argocd-controller@pcc-prj-devops-prod*"
# Expected: roles/container.admin AND roles/gkehub.gatewayAdmin

gcloud projects get-iam-policy pcc-prj-app-devtest \
  --flatten="bindings[].members" \
  --format="table(bindings.role)" \
  --filter="bindings.members:*argocd-controller@pcc-prj-devops-prod*"
# Expected: roles/container.admin AND roles/gkehub.gatewayAdmin

# ArgoCD Nonprod should have gkehub.gatewayAdmin only in nonprod
gcloud projects get-iam-policy pcc-prj-devops-nonprod \
  --flatten="bindings[].members" \
  --format="table(bindings.role)" \
  --filter="bindings.members:*argocd-controller@pcc-prj-devops-nonprod*"
# Expected: roles/container.admin AND roles/gkehub.gatewayAdmin
```

---

## Deliverables

- [ ] 2 ArgoCD GCP service accounts created (prod, nonprod)
- [ ] 8 ArgoCD cross-project IAM bindings (4 container.admin + 4 gkehub.gatewayAdmin)
- [ ] 2 Cloud Build IAM bindings (Artifact Registry, Secret Manager)
- [ ] All terraform code in `infra/pcc-app-shared-infra/terraform/iam.tf`
- [ ] Note: Workload Identity bindings deferred to Phase 4 (when K8s SAs exist)

**Total Resources in Phase 3.4**: 12 IAM/SA resources
- 2 GCP service accounts (google_service_account)
- 8 ArgoCD IAM bindings (4 container.admin + 4 gkehub.gatewayAdmin via google_project_iam_member)
- 2 Cloud Build IAM bindings (google_project_iam_member)

**Note**: Phase 3 total is 15 resources (3 GKE clusters from Phase 3.3 + 12 IAM/SA resources from Phase 3.4)
**Note**: Workload Identity bindings (2 resources) moved to Phase 4 when K8s service accounts are created

---

## Validation Criteria

- [ ] 2 ArgoCD GCP service accounts exist (prod, nonprod)
- [ ] ArgoCD Prod SA has `container.admin` in all 3 GKE projects
- [ ] ArgoCD Nonprod SA has `container.admin` only in nonprod project
- [ ] ArgoCD Prod SA has `gkehub.gatewayAdmin` in all 3 GKE projects
- [ ] ArgoCD Nonprod SA has `gkehub.gatewayAdmin` only in nonprod project
- [ ] Cloud Build SA has `artifactregistry.writer` in pcc-prj-devops-prod
- [ ] Cloud Build SA has `secretmanager.secretAccessor` in pcc-prj-app-devtest
- [ ] All IAM bindings use correct service account emails
- [ ] Dependencies on GKE clusters configured (prevent race conditions)
- [ ] Workload Identity bindings deferred to Phase 4 (documented in Phase 4 plan)

---

## Dependencies

**Upstream**:
- Phase 3.3: GKE clusters defined (needed for module references)
- Phase 0: Cloud Build API enabled (creates Cloud Build SA)

**Downstream**:
- Phase 3.5: Terraform validation
- Phase 4: ArgoCD deployment (creates K8s service account that uses Workload Identity)
- Phase 5: Cloud Build pipelines (use Artifact Registry and Secret Manager access)

---

## Notes

- **GCP Service Accounts First**: Create GCP SAs (argocd-controller) in Phase 3
- **K8s SA Created Later**: K8s service accounts created in Phase 4 when ArgoCD deployed
- **Workload Identity Bindings Moved**: WI bindings (google_service_account_iam_member) moved to Phase 4
- **Why Move WI Bindings**: K8s SAs must exist before creating WI bindings; prevents terraform errors
- **Phase 3 Creates**: GCP service accounts (2) + cross-project IAM (10: 4 container.admin + 4 gkehub.gatewayAdmin + 2 Cloud Build) = 12 IAM resources
- **Phase 4 Adds**: Workload Identity bindings (2) after K8s SAs created
- **Two ArgoCD Instances**: Prod (manages all 3 clusters), Nonprod (manages only nonprod cluster)
- **ArgoCD Nonprod Purpose**: Test ArgoCD upgrades safely before rolling to production
- **No Cloud Build → GKE binding**: ArgoCD handles all deployments via GitOps
- **Service-specific IAM**: Service account → Secret Manager moved to Phase 6
- **Dependencies**: IAM bindings depend on clusters existing (use `depends_on`)
- **Audit Logs**: Show `argocd-controller@...` instead of K8s principal (better auditing)

---

## Time Estimate

**Total**: 30-35 minutes
- 5 min: Document Cloud Build IAM bindings (2 patterns)
- 10 min: Create ArgoCD GCP service accounts (2 SAs + Workload Identity)
- 10 min: Document ArgoCD cross-project IAM (4 bindings)
- 5 min: Review and validate terraform configuration

---

**Next Phase**: 3.5 - Terraform Validation
