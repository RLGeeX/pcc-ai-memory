# Apigee Pipeline Requirements for .NET Microservices Project (Devtest Focus)

**Last Updated**: 2025-10-17
**Status**: ⏳ Planning phase (10/17-10/19), implementation starts 10/20

## Overview
This document defines the CI/CD pipeline requirements for deploying multiple .NET microservices to Google Kubernetes Engine (GKE) with ArgoCD, fronted by Apigee X for API management. The initial focus is on the `devtest` environment, with all artifacts (Docker images, Apigee proxies, Kubernetes manifests) deployed to `devtest`. Future environments (`dev`, `staging`, `prod`) will be supported incrementally.

**Key Architectural Decisions:**
- **Two Apigee Organizations**: Nonprod org (devtest, dev, staging environments), Prod org (prod environment only)
- **Single AlloyDB Cluster**: Shared cluster in pcc-app-shared-infra with 7 databases (one per microservice)
- **Environment-Agnostic Images**: Docker images named `pcc-app-{service}` (no environment suffix), tagged with `v{major}.{minor}.{patch}.{buildid}`
- **Three GKE Clusters**: 2 devops clusters (nonprod/prod for system services), 1 app cluster (pcc-prj-app-devtest for workloads)
- **Existing Foundation**: 16 GCP projects already deployed (220 resources, 9/10 security score), only 2 Apigee projects need to be added

Each service repository (e.g., `pcc-auth-api`) imports standardized pipeline logic from `pcc-pipeline-library` for consistency. Terraform configurations are centralized in `pcc-tf-library`, while `pcc-app-shared-infra` manages deployed shared infrastructure. Setup is parameter-driven using GitHub and Cloud Build.

## Scope
- **Objective**: Automated pipelines deploying to `devtest` initially, with incremental support for `dev`, `staging`, and `prod` environments.
- **Components**:
  - .NET 10 microservices (ASP.NET Core, pre-built OpenAPI specs).
  - 3 GKE Autopilot clusters: pcc-prj-devops-nonprod, pcc-prj-devops-prod (ArgoCD host), pcc-prj-app-devtest (workloads).
  - AlloyDB cluster with 7 PostgreSQL databases (auth_db_devtest, client_db_devtest, user_db_devtest, metric_builder_db_devtest, metric_tracker_db_devtest, task_builder_db_devtest, task_tracker_db_devtest).
  - Flyway for database schema migrations in CI/CD pipeline.
  - 2 Apigee X organizations: pcc-prj-apigee-nonprod (devtest/dev/staging), pcc-prj-apigee-prod (prod only).
  - Cloud Build for CI/CD, GitHub for source control.
  - Artifact Registry in pcc-prj-devops-prod, GCS, Secret Manager for storage and secrets.
- **Repositories**:
  - `pcc-pipeline-library`: Central pipeline templates and scripts.
  - Service repos: `pcc-auth-api`, `pcc-client-api`, `pcc-user-api`, `pcc-metric-builder-api`, `pcc-metric-tracker-api`, `pcc-task-builder-api`, `pcc-task-tracker-api`.
  - Infrastructure repos: `pcc-auth-api-infra`, `pcc-client-api-infra`, `pcc-user-api-infra`, `pcc-metric-builder-api-infra`, `pcc-metric-tracker-api-infra`, `pcc-task-builder-api-infra`, `pcc-task-tracker-api-infra`, `pcc-app-shared-infra`.
  - Config repo: `pcc-app-argo-config` (Kubernetes manifests, ArgoCD Apps).
  - Terraform repo: `pcc-tf-library` (all Terraform configurations).
- **Scale**: Supports 7+ microservices, each with independent pipelines.
- **Environment Strategy**:
  - **Devtest**: Initial environment, `devtest` branch, `devtest` namespace, `devtest` Apigee env.
  - **Future**: `dev` (dev branch), `staging` (staging branch), `prod` (main branch).

## Requirements

### 1. Repository Structure
- **pcc-pipeline-library**:
  - `dotnet-apigee-pipeline.yaml`: Pipeline template for build, test, deploy, and Apigee proxy update.
  - `scripts/`:
    - `build.sh`: Builds .NET 10 project, runs xUnit tests, executes Flyway migrations.
    - `generate-spec.sh`: Locates pre-built OpenAPI spec from build artifacts, filters service-specific paths (e.g., `/auth/*` for `pcc-auth-api`).
    - `update-config.sh`: Updates `pcc-app-argo-config` with new image tag for ArgoCD sync.
    - `wait-argocd.sh`: Polls ArgoCD for healthy deployment (5 min timeout).
    - `deploy-apigee.sh`: Creates/deploys Apigee proxy to nonprod org, configures routing.
  - `services-config.yaml`: List of services (e.g., `auth`, `client`, `user`, `metric-builder`, `metric-tracker`, `task-builder`, `task-tracker`).
- **Service Repos** (`pcc-auth-api`, `pcc-client-api`, etc.):
  - .NET project files (e.g., `YourProject.sln`, `src/YourProject.WebAPI.csproj`).
  - `Dockerfile` for containerization.
  - `cloudbuild.yaml`: Clones `pcc-pipeline-library`, executes scripts with parameters.
  - Variables: `SERVICE_NAME`, `DOCKER_REPO`, `ARGO_APP_NAME`, `ENVIRONMENT`, `REGION`.
- **Infrastructure Repos** (`pcc-auth-api-infra`, `pcc-client-api-infra`, etc.):
  - Optional service-specific configurations (e.g., unique GKE settings, if needed).
  - Can be empty if all shared infra is in `pcc-app-shared-infra`.
- **pcc-app-shared-infra**:
  - Manages deployed shared infrastructure resources (e.g., Apigee org, environments, API product, GCS buckets, Secret Manager configs).
  - References Terraform modules from `pcc-tf-library` for deployment.
- **pcc-app-argo-config**:
  - `devtest/auth/deployment.yaml`, `devtest/client/deployment.yaml`, etc.: Kubernetes manifests per service/env.
  - `argocd-app-auth-devtest.yaml`, `argocd-app-client-devtest.yaml`, etc.: ArgoCD Apps per service/env.
- **pcc-tf-library**:
  - `apigee/main.tf`: Terraform for Apigee org, environments, and shared product.
  - `terraform.tfvars`: Project settings (e.g., `project_id`, `region`).
  - Other shared Terraform modules (e.g., for GCS, Secret Manager, if needed).

### 2. GCP Resources

**Existing Foundation (pcc-foundation-infra):**
- 16 GCP projects: 4 app, 4 data, 2 devops, 2 network, 2 systems, 1 logging, 1 bootstrap
- 2 VPCs: prod (10.16.0.0/12), nonprod (10.24.0.0/12) with Shared VPC architecture
- DevOps subnets already allocated: 10.16.128.0/20 (prod), 10.24.128.0/20 (nonprod)
- 220 resources deployed, 9/10 security score

**New Resources for Devtest:**

- **GKE Clusters** (3 Autopilot clusters):
  1. **pcc-prj-devops-nonprod**: System services, monitoring (subnet: 10.24.128.0/20 existing)
  2. **pcc-prj-devops-prod**: ArgoCD primary instance (subnet: 10.16.128.0/20 existing)
  3. **pcc-prj-app-devtest**: Application workloads (subnet: TBD from 10.24.0.0/12 range)
  - Workload Identity enabled for Cloud Build access
  - Namespaces per service (e.g., `pcc-auth-api`, `pcc-client-api`)
  - Internal service endpoints (e.g., `pcc-auth-api.pcc-auth-api.svc.cluster.local`)

- **AlloyDB Cluster** (pcc-app-shared-infra):
  - Single cluster in us-east4, high availability
  - 7 databases: auth_db_devtest, client_db_devtest, user_db_devtest, metric_builder_db_devtest, metric_tracker_db_devtest, task_builder_db_devtest, task_tracker_db_devtest
  - Private Service Connect for GKE access
  - Flyway manages schema migrations via CI/CD

- **Artifact Registry** (pcc-prj-devops-prod):
  - Stores Docker images (e.g., `gcr.io/$PROJECT_ID/pcc-app-auth:v1.2.3.abc123`)
  - **NO environment suffix in image name**, only in tags
  - Tag format: `v{major}.{minor}.{patch}.{buildid}` (e.g., v1.2.3.abc123)
  - ArgoCD references specific tags per environment

- **GCS Bucket**: Stores OpenAPI specs (e.g., `gs://pcc-specs-bucket/devtest/$SERVICE_NAME/openapi.json`)

- **Secret Manager**:
  - `git-token`: GitHub PAT for cloning repositories
  - `argocd-password`: ArgoCD admin password
  - `apigee-access-token`: Apigee CLI access token
  - `alloydb-credentials`: Database connection credentials per service

- **Apigee X Organizations**:
  - **Nonprod org** (pcc-prj-apigee-nonprod): Environments for devtest, dev, staging
    - Subnets: 10.24.192.0/20 (runtime), 10.24.208.0/20 (management), 10.24.224.0/20 (troubleshooting), 10.24.240.0/20 (overflow)
  - **Prod org** (pcc-prj-apigee-prod): Environment for prod only (deferred)
    - Subnets: 10.16.192.0/20 (runtime), 10.16.208.0/20 (management), 10.16.224.0/20 (troubleshooting), 10.16.240.0/20 (overflow)
  - Initial focus: Nonprod org with devtest environment only

### 3. Service Account Permissions
- **Cloud Build Service Account** (`PROJECT_NUMBER@cloudbuild.gserviceaccount.com`):
  - Roles: `roles/apigee.admin`, `roles/container.developer`, `roles/secretmanager.secretAccessor`, `roles/storage.admin`, `roles/iam.serviceAccountUser` (for Workload Identity).
  - Bind to Kubernetes Service Account in ArgoCD namespace:
    ```bash
    gcloud iam service-accounts add-iam-policy-binding \
      PROJECT_NUMBER@cloudbuild.gserviceaccount.com \
      --member="serviceAccount:pcc-project.svc.id.goog[argocd/argocd-k8s-sa]" \
      --role="roles/iam.workloadIdentityUser"
    ```
- **Apigee Service Account**:
  - Generate access token for `apigeecli`, stored in Secret Manager.

### 4. Pipeline Steps
Each service pipeline (e.g., `pcc-auth-api/cloudbuild.yaml`) targets the `devtest` environment, triggered on push to the `devtest` branch:

1. **Build .NET**: Compile .NET 10 project, run xUnit tests, Flyway migrations.
2. **Extract OpenAPI Spec**: Locate pre-built OpenAPI spec from build artifacts (NOT generated at runtime), filter to service-specific paths (e.g., `/auth/*`), upload to GCS (`gs://pcc-specs-bucket/devtest/auth/openapi.json`).
3. **Build/Push Docker Image**:
   - Build image with environment-agnostic name: `pcc-app-auth` (NO environment suffix)
   - Tag with semantic version + buildid: `v1.2.3.abc123`
   - Push to Artifact Registry: `gcr.io/$PROJECT_ID/pcc-app-auth:v1.2.3.abc123`
4. **Update Config Repo**: Update manifest in `pcc-app-argo-config` with new image tag, commit to trigger ArgoCD sync.
5. **Wait for ArgoCD**: Poll ArgoCD for healthy deployment (`Healthy` and `Synced`, 5 min timeout).
6. **Deploy Apigee Proxy**: Download spec from GCS, use `apigeecli` to create/deploy proxy to nonprod Apigee org devtest environment.

- **Parameters** (Cloud Build substitutions):
  - `_SERVICE_NAME`: e.g., `auth`, `client`, `user`
  - `_IMAGE_NAME`: e.g., `pcc-app-auth` (NO environment suffix)
  - `_VERSION`: Semantic version from repo (e.g., `1.2.3`)
  - `_BUILD_ID`: Cloud Build ID for unique tagging
  - `_ENVIRONMENT`: `devtest` (for targeting correct Apigee env and namespace)
  - `_REGION`: `us-east4`
- **Trigger**: Push to `devtest` branch in service repo (e.g., `pcc-auth-api/devtest`)

### 5. Terraform Configuration (pcc-tf-library)
- **Purpose**: Centralize all Terraform configurations for Apigee and other shared resources.
- **Key Resources**:
  - Apigee organization (`pcc-org`).
  - Environment (`devtest` initially).
  - API product (`pcc-all-services-devtest`).
  - Optional: GCS buckets, Secret Manager configs.
- **Execution**: Run manually or via a separate Cloud Build pipeline in `pcc-tf-library` for shared changes.
- **Deployment**: Applied to create resources managed in `pcc-app-shared-infra`.

### 6. ArgoCD Configuration (pcc-app-argo-config)
- **Per-Service Application**:
  - `argocd-app-auth-devtest.yaml`, `argocd-app-client-devtest.yaml`, etc.: Points to `devtest/$SERVICE_NAME/deployment.yaml`, auto-sync enabled.
- **Manifests**: Deployment and Service per service/env (e.g., `devtest/auth/deployment.yaml`), targeting `devtest` namespace.

### 7. New Service Process
- **Steps**:
  1. Create service repo (e.g., `pcc-new-service-api`) from template.
  2. Set substitutions in `cloudbuild.yaml` (e.g., `_SERVICE_NAME=new-service`, `_ENVIRONMENT=devtest`).
  3. Add `devtest/new-service/deployment.yaml` and `argocd-app-new-service-devtest.yaml` to `pcc-app-argo-config`.
  4. Create optional `pcc-new-service-api-infra` for service-specific configs (if needed).
  5. Connect Cloud Build trigger to `pcc-new-service-api/devtest`.
- **Time**: ~15 minutes per service.

### 8. Testing & Validation
- **Trigger**: Push to `devtest` branch (e.g., `pcc-auth-api/devtest`).
- **Checks**:
  - Verify Docker image in Artifact Registry (e.g., `gcr.io/$PROJECT_ID/pcc-app-auth-devtest`).
  - Confirm ArgoCD sync/health in UI or CLI for `argocd-app-auth-devtest`.
  - Test Apigee proxy (`devtest-api.pccdomain.com/auth`) with JWT from React client.
  - Validate dev portal exposure (proxy metadata, docs).
- **Failure Handling**:
  - Fail on empty OpenAPI spec.
  - Timeout ArgoCD polling after 5 minutes.
  - Log errors in Cloud Build.

### 9. Multi-Environment Support

**Apigee Organization Mapping:**
- **Nonprod Apigee org** (pcc-prj-apigee-nonprod): Hosts devtest, dev, staging environments
- **Prod Apigee org** (pcc-prj-apigee-prod): Hosts prod environment only

**Environment Roadmap:**
- **Current Phase**: Deploy to `devtest` environment only
  - Branch: `devtest`
  - GKE cluster: pcc-prj-app-devtest
  - AlloyDB databases: *_devtest suffix
  - Apigee: nonprod org, devtest environment

- **Future Phases**:
  - **Dev**: `dev` branch → pcc-prj-app-dev cluster → nonprod Apigee org, dev environment
  - **Staging**: `staging` branch → pcc-prj-app-staging cluster → nonprod Apigee org, staging environment
  - **Prod**: `main` branch → pcc-prj-app-prod cluster → prod Apigee org, prod environment

**Key Strategy:**
- Staging uses nonprod Apigee org (not prod)
- Image tags differentiate environments (same image name: `pcc-app-auth`, different tags: `v1.2.3.abc123`)
- ArgoCD manifests per environment reference appropriate image tag
- Approvals required for staging and prod deployments
- `_ENVIRONMENT` substitution varies namespaces, Apigee envs, database connections

### 10. Maintenance
- **Updates**: Modify `pcc-pipeline-library` for pipeline changes; services adopt on next build.
- **Security**:
  - Rotate Secret Manager tokens (GitHub PAT, ArgoCD, Apigee).
  - Use Workload Identity for GKE access.
  - Enforce HTTPS in Apigee.
- **Monitoring**:
  - Cloud Logging for pipeline logs.
  - Apigee Analytics for API usage.
  - Alerts for build failures or ArgoCD sync issues.
- **Cleanup**: Delete old images in Artifact Registry periodically.

### 11. Apigee Pay-as-You-Go Pricing (Oct 2025)
- **Evaluation**: Free for 60 days.
- **Environments**: $0.05–$0.20/hour (~$36–$144/month per env, single region).
- **API Calls**: $0.0005–$0.001/call (~$500–$1,000 for 1M calls/month).
- **Analytics**: $0.0001/request.
- **Networking**: ~$0.08/GB egress.
- Use [GCP Pricing Calculator](https://cloud.google.com/products/calculator) for estimates.

### 12. Deployment Phases

Detailed phase-by-phase deployment plan documented in: `.claude/plans/devtest-deployment-phases.md`

**Summary:**
- **Phase 0**: Add 2 Apigee projects to pcc-foundation-infra
- **Phase 1**: Networking for devtest (app-devtest subnet, Private Service Connect)
- **Phase 2**: AlloyDB cluster + 7 databases
- **Phase 3**: 3 GKE clusters (devops-nonprod, devops-prod, app-devtest)
- **Phase 4**: ArgoCD on devops-prod cluster
- **Phase 5**: Pipeline library (pcc-pipeline-library)
- **Phase 6**: First service deployment (pcc-auth-api end-to-end)
- **Phase 7**: Apigee nonprod org + devtest environment

**Timeline:**
- **Planning**: 10/17-10/19 (Fri-Sun) - Requirements finalization, phase planning
- **Implementation**: Starting 10/20 (Mon) - Sequential phase execution
- **Duration**: 2-3 weeks for all 7 phases

### 13. Next Steps

**Immediate (Planning Phase 10/17-10/19):**
- Review and refine phase plans in `.claude/plans/devtest-deployment-phases.md`
- Finalize network subnet allocation for pcc-prj-app-devtest
- Prepare terraform configurations for each phase
- Document validation criteria per phase

**Implementation Phase (Starting 10/20):**
- Execute Phase 0: Add Apigee projects to foundation
- Execute Phase 1: Configure networking
- Execute Phase 2: Deploy AlloyDB cluster
- Continue through Phase 7 sequentially

**Post-Devtest:**
- Expand to dev environment (nonprod Apigee, pcc-prj-app-dev)
- Deploy remaining 6 microservices using established pipeline
- Configure staging environment (nonprod Apigee, pcc-prj-app-staging)
- Plan prod environment (separate deployment plan)

### 14. Assumptions & Notes

**Architecture Assumptions:**
- 16 GCP projects already exist in pcc-foundation-infra (220 resources deployed)
- DevOps GKE subnets already allocated (10.16.128.0/20 prod, 10.24.128.0/20 nonprod)
- Shared VPC architecture in place with 2 VPC hosts
- 9/10 security score on existing foundation (production-ready)

**Technical Assumptions:**
- .NET 10 services with pre-built OpenAPI specs (not runtime-generated)
- AlloyDB Private Service Connect provides database connectivity to GKE
- ArgoCD in pcc-prj-devops-prod manages all environment deployments
- Flyway handles database schema migrations via CI/CD pipeline
- Pipeline runtime: ~10-15 minutes per service deployment

**Deployment Strategy:**
- Initial focus: devtest environment only (Phases 0-7)
- Sequential phase execution with validation gates
- No manual GCP console operations (100% Terraform + GitOps)
- Image tags (not image names) differentiate environments

**References:**
- Detailed phases: `.claude/plans/devtest-deployment-phases.md`
- ADR 001: `.claude/docs/ADR/001-two-org-apigee-architecture.md`
- Foundation state: `core/pcc-foundation-infra/.claude/status/brief.md`
- Network design: `core/pcc-foundation-infra/.claude/reference/GCP Network Subnets - GKE Subnet Assignment Redesign.pdf`

For questions, refer to GCP Apigee X docs, Cloud Build guides, or project documentation in `.claude/` directory.