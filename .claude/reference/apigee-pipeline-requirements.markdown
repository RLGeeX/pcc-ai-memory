# Apigee Pipeline Requirements for .NET Microservices Project (Devtest Focus)

## Overview
This document defines the CI/CD pipeline requirements for a new project deploying multiple .NET microservices to Google Kubernetes Engine (GKE) with ArgoCD, fronted by a single Apigee instance for API management. The initial focus is on the `devtest` environment, with all artifacts (Docker images, Apigee proxies, Kubernetes manifests) deployed to `devtest`, tied to the `devtest` branch. Future environments (`dev`, `staging`, `prod`) will be supported, tied to branches: `dev` (dev), `staging` (staging), `main` (prod). Each service repository (e.g., `pcc-auth-api`) imports standardized pipeline logic from a central `pcc-pipeline-library` repository to ensure consistency and ease of new service creation. Terraform configurations are centralized in `pcc-tf-library`, while `pcc-app-shared-infra` manages deployed shared infrastructure. The setup is parameter-driven, uses GitHub and Cloud Build, and supports a developer portal.

## Scope
- **Objective**: Automated pipelines deploying to `devtest` initially, with support for `dev`, `staging`, and `prod`, updating a shared Apigee instance (single domain, developer portal).
- **Components**:
  - .NET Core microservices (ASP.NET Core, generating OpenAPI specs via Swashbuckle).
  - GKE cluster with ArgoCD for container deployments.
  - Apigee for API management (proxies per service, shared API product).
  - Cloud Build for CI/CD, GitHub for source control.
  - Artifact Registry, GCS, Secret Manager for storage and secrets.
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
    - `build.sh`: Builds .NET project.
    - `generate-spec.sh`: Generates service-specific OpenAPI spec (e.g., paths `/auth/*` for `pcc-auth-api`).
    - `update-config.sh`: Updates `pcc-app-argo-config` for ArgoCD.
    - `wait-argocd.sh`: Polls ArgoCD for healthy deployment.
    - `deploy-apigee.sh`: Creates/deploys Apigee proxy, attaches to shared product.
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
- **GKE Cluster**:
  - ArgoCD installed (via Helm or manifests).
  - Workload Identity enabled for Cloud Build access.
  - Namespaces: `devtest` (initial), `dev`, `staging`, `prod` (future).
  - Stable LoadBalancer/Ingress URL per service/env (e.g., `auth.devtest.svc.cluster.local`).
- **Artifact Registry**: Stores Docker images (e.g., `gcr.io/$PROJECT_ID/pcc-app-$SERVICE_NAME-$ENVIRONMENT:$SHORT_SHA`).
- **GCS Bucket**: Stores OpenAPI specs (e.g., `gs://pcc-specs-bucket/devtest/$SERVICE_NAME/openapi.json`).
- **Secret Manager**:
  - `git-token`: GitHub PAT for cloning `pcc-pipeline-library` and `pcc-app-argo-config`.
  - `argocd-password`: ArgoCD admin password.
  - `apigee-access-token`: Apigee CLI access token.
- **Apigee**:
  - One organization (`pcc-org`), managed via `pcc-tf-library`.
  - Environment: `devtest` (initial), `dev`, `staging`, `prod` (future).
  - Shared API product: `pcc-all-services-devtest` (e.g., `devtest-api.pccdomain.com`).

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
1. **Build .NET**: Compile project, run tests (if applicable).
2. **Generate OpenAPI Spec**: Run app briefly, curl Swagger endpoint (e.g., `/swagger/v1/swagger.json`), filter to service paths (e.g., `/auth/*`), upload to GCS (`gs://pcc-specs-bucket/devtest/auth/openapi.json`).
3. **Build/Push Docker Image**: Build image, push to Artifact Registry (e.g., `gcr.io/$PROJECT_ID/pcc-app-auth-devtest:$SHORT_SHA`).
4. **Update Config Repo**: Update manifest in `pcc-app-argo-config/devtest/auth/deployment.yaml` to trigger ArgoCD.
5. **Wait for ArgoCD**: Poll for healthy deployment (`Healthy` and `Synced`, 5 min timeout) for `argocd-app-auth-devtest`.
6. **Deploy Apigee Proxy**: Download spec from GCS, use `apigeecli` to create/deploy proxy (e.g., `auth-devtest` proxy), attach to `pcc-all-services-devtest` product.

- **Parameters** (Cloud Build substitutions):
  - `_SERVICE_NAME`: e.g., `auth`, `client`.
  - `_DOCKER_REPO`: e.g., `pcc-app-auth-devtest`, `pcc-app-client-devtest`.
  - `_ARGO_APP_NAME`: e.g., `auth-app-devtest`, `client-app-devtest`.
  - `_ENVIRONMENT`: `devtest` (initial), `dev`, `staging`, `prod` (future).
  - `_REGION`: e.g., `us-central1`.
- **Trigger**: Push to `devtest` branch in service repo (e.g., `pcc-auth-api/devtest`).

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
- **Current**: Deploy to `devtest` environment (`devtest` branch, `devtest` namespace, `devtest` Apigee env).
- **Future**:
  - `dev`: `dev` branch, `dev` namespace, `dev` Apigee env.
  - `staging`: `staging` branch, `staging` namespace, `staging` Apigee env.
  - `prod`: `main` branch, `prod` namespace, `prod` Apigee env.
- **Approvals**: Manual for `staging` and `prod` in Cloud Build (e.g., approval step).
- **Substitutions**: `_ENVIRONMENT` to vary namespaces, buckets, and Apigee envs.

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

### 12. Next Steps
- **Week 1-2**: Set up `pcc-pipeline-library` and `pcc-tf-library`, POC with `pcc-auth-api` and `pcc-client-api` in `devtest`, enable Apigee evaluation.
- **Week 3**: Configure dev portal, test JWT auth for React client.
- **Month 2**: Roll out remaining services (`pcc-user-api`, etc.), deploy Terraform in `pcc-tf-library` to `pcc-app-shared-infra`.
- **Month 3**: Plan `dev`, `staging`, `prod` environments (new branches, namespaces, Apigee envs).
- **DevOps Team**:
  - Create GCS buckets, Secret Manager secrets.
  - Set up Cloud Build triggers for `devtest` branch in each service repo.
  - Validate ArgoCD setup in `pcc-app-argo-config` (auto-sync enabled).
  - Test pipeline with a small code change in `pcc-auth-api/devtest`.
  - Initialize Terraform in `pcc-tf-library` for Apigee setup.
- **Documentation**: Update runbooks with pipeline flow, share Apigee endpoint for client integration.

### 13. Assumptions & Notes
- GKE backend URLs are stable; if dynamic, use Terraform data sources in `pcc-tf-library`.
- Apigee org/env setup is one-time via Terraform in `pcc-tf-library`.
- Pipeline runtime: ~10-15 minutes (includes clone, build, deploy).
- Team has GitLab CI experience, easing transition to clone-based library.
- All artifacts deploy to `devtest` initially; multi-branch strategy to be implemented later.

For questions, refer to GCP Apigee docs or GitHub/Cloud Build guides.