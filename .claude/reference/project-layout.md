# PCC Project Layout

## Repository Collections

The project is organized into **3 repository collections**:

### 1. `core/` - Core items for devops (@core)

**Purpose**: Centralized DevOps tooling and infrastructure-as-code templates

**Repositories**:
- **`pcc-app-argo-config`**: ArgoCD GitOps configurations
  - Application manifests for all microservices
  - ArgoCD app-of-apps pattern
  - Environment-specific Kubernetes manifests

- **`pcc-tf-library`**: Reusable Terraform modules
  - Shared modules for all infrastructure deployments
  - GKE, AlloyDB, Apigee, networking modules
  - Used by all `infra/` repositories

- **`pcc-pipeline-library`**: Cloud Build pipeline scripts and templates
  - 5 reusable bash scripts: build.sh, generate-spec.sh, update-config.sh, wait-argocd.sh, deploy-apigee.sh
  - Standardized CI/CD workflows for all microservices
  - Service configuration templates

### 2. `infra/` - Infrastructure repositories (@infra)

**Purpose**: All Terraform deployments for infrastructure provisioning

**Repositories**:
- **`pcc-app-shared-infra`**: Shared infrastructure
  - AlloyDB cluster with 7 databases
  - GCS buckets, Secret Manager
  - Shared resources used by multiple services

- **Service-specific infra repositories**: (7 total)
  - `pcc-auth-api-infra`
  - `pcc-client-api-infra`
  - `pcc-user-api-infra`
  - `pcc-metric-builder-api-infra`
  - `pcc-metric-tracker-api-infra`
  - `pcc-task-builder-api-infra`
  - `pcc-task-tracker-api-infra`

  Each contains:
  - Service-specific Kubernetes manifests
  - Database migration scripts (Flyway)
  - Service-specific configurations

**Key Pattern**: Each service in `src/` has a paired repository in `infra/`
- Example: `src/pcc-auth-api` ↔ `infra/pcc-auth-api-infra`

### 3. `src/` - Source code repositories (@src)

**Purpose**: All application source code

**7 .NET 10 Microservices**:
1. `pcc-auth-api` - Authentication and authorization (Descope integration)
2. `pcc-client-api` - Client management
3. `pcc-user-api` - User management
4. `pcc-metric-builder-api` - Metrics builder service
5. `pcc-metric-tracker-api` - Metrics tracking service
6. `pcc-task-builder-api` - Task builder service
7. `pcc-task-tracker-api` - Task tracking service

**Each service includes**:
- .NET 10 ASP.NET Core Web API
- xUnit test suite
- Pre-built OpenAPI specification
- Dockerfile for containerization
- cloudbuild.yaml (imports from `pcc-pipeline-library`)

**Database Mapping** (AlloyDB):
- auth_db_devtest
- client_db_devtest
- user_db_devtest
- metric_builder_db_devtest
- metric_tracker_db_devtest
- task_builder_db_devtest
- task_tracker_db_devtest

---

## Cross-Repository Dependencies

```
core/pcc-tf-library (modules)
    ↓ (imported by)
infra/pcc-app-shared-infra (deploys AlloyDB, shared resources)
infra/pcc-{service}-api-infra (deploys service configs)
    ↓ (used by)
src/pcc-{service}-api (application code)
    ↓ (deployed via)
core/pcc-pipeline-library (CI/CD scripts)
    ↓ (synced by)
core/pcc-app-argo-config (GitOps manifests)
```

---

## Deployment Flow

1. **Developer pushes** to `src/pcc-auth-api` devtest branch
2. **Cloud Build** triggers using `pcc-pipeline-library` scripts
3. **Build/Test/Package**: .NET build, tests, Docker image (`pcc-app-auth:v1.2.3.abc123`)
4. **OpenAPI spec** extracted and uploaded to GCS
5. **ArgoCD manifest** updated in `pcc-app-argo-config` with new image tag
6. **ArgoCD** syncs to GKE cluster (pcc-prj-app-devtest)
7. **Apigee proxy** deployed to nonprod org devtest environment
8. **Service running** on GKE, connected to AlloyDB via Private Service Connect

---

## Key Architectural Notes

- **Image naming**: `pcc-app-{service}` (NO environment suffix)
- **Image tagging**: `v{major}.{minor}.{patch}.{buildid}` (e.g., v1.2.3.abc123)
- **Single Artifact Registry**: pcc-prj-devops-prod (all images stored here)
- **Environment differentiation**: ArgoCD manifests reference different tags per environment
- **Database strategy**: Single AlloyDB cluster with multiple databases (not per-service clusters)
- **Flyway migrations**: Executed via CI/CD pipeline, managed in `infra/` repositories
