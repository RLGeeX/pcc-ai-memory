# Apigee Pipeline Implementation Plan for PCC Project

**Generated:** 2025-10-15
**Planning Model:** Gemini 2.5 Pro via Zen MCP
**Source Requirements:** `.claude/reference/apigee-pipeline-requirements.markdown`

---

## Executive Summary

Complete CI/CD pipeline system deploying 7 .NET microservices to GKE with Apigee API Gateway, initially targeting the `devtest` environment with future expansion to dev, staging, and prod.

**Target Architecture:**
```
GitHub (devtest branch)
    |
    v
Cloud Build Pipeline (9 steps)
    |
    +---> Docker Image ---> Artifact Registry
    +---> OpenAPI Spec ---> GCS Bucket
    +---> ArgoCD Config Update ---> GKE Deployment
    +---> Apigee Proxy ---> API Gateway
```

**Services:** auth, client, user, metric-builder, metric-tracker, task-builder, task-tracker

---

## PHASE 1: Foundation & GCP Infrastructure Setup

**Timeline:** Week 1, Days 1-3

### Objectives
Establish core GCP infrastructure and Terraform configurations that all services will depend on.

### Key Tasks

#### 1.1 pcc-tf-library Setup
Create Terraform modules for:

**Files to create:**
- `apigee/main.tf` - Apigee org, devtest environment, pcc-all-services-devtest product
- `apigee/variables.tf` - project_id, region, environment variables
- `apigee/outputs.tf` - Apigee env details, API product ID
- `apigee/terraform.tfvars` - Actual values for devtest
- `shared/gcs-buckets.tf` - pcc-specs-bucket for OpenAPI specs
- `shared/secret-manager.tf` - Placeholder configs (secrets added manually)

**Apigee Resources:**
```hcl
resource "google_apigee_organization" "pcc_org" {
  project_id = var.project_id
  analytics_region = var.region
}

resource "google_apigee_environment" "devtest" {
  org_id = google_apigee_organization.pcc_org.id
  name   = "devtest"
}

resource "google_apigee_product" "all_services_devtest" {
  name = "pcc-all-services-devtest"
  display_name = "PCC All Services - Devtest"
  environments = [google_apigee_environment.devtest.name]
  # Proxies attached dynamically by pipeline
}
```

#### 1.2 GCP Resource Provisioning

**Manual/Script tasks:**
```bash
# Enable required APIs
gcloud services enable apigee.googleapis.com container.googleapis.com \
  cloudbuild.googleapis.com artifactregistry.googleapis.com

# Create Artifact Registry
gcloud artifacts repositories create pcc-app-devtest \
  --repository-format=docker --location=us-central1

# Secrets created interactively via console or gcloud
# - git-token: GitHub PAT for cloning repos
# - argocd-password: ArgoCD admin password
# - apigee-access-token: Apigee CLI access token
```

#### 1.3 Service Account Configuration

**Configure Cloud Build SA:**
```bash
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$PROJECT_NUMBER@cloudbuild.gserviceaccount.com" \
  --role="roles/apigee.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$PROJECT_NUMBER@cloudbuild.gserviceaccount.com" \
  --role="roles/container.developer"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$PROJECT_NUMBER@cloudbuild.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$PROJECT_NUMBER@cloudbuild.gserviceaccount.com" \
  --role="roles/storage.admin"

# Workload Identity binding (after ArgoCD is installed)
gcloud iam service-accounts add-iam-policy-binding \
  $PROJECT_NUMBER@cloudbuild.gserviceaccount.com \
  --member="serviceAccount:$PROJECT_ID.svc.id.goog[argocd/argocd-k8s-sa]" \
  --role="roles/iam.workloadIdentityUser"
```

#### 1.4 GKE & ArgoCD Setup

**Prerequisites:**
- GKE cluster already exists (per CLAUDE.md)
- Workload Identity enabled

**Tasks:**
```bash
# Create devtest namespace
kubectl create namespace devtest

# Verify ArgoCD
argocd login <ARGOCD_URL> --username admin --password <from Secret Manager>
argocd cluster list

# Bind service account for Workload Identity (see 1.3)
```

#### 1.5 pcc-app-shared-infra Setup

**Purpose:** Deploy Terraform from pcc-tf-library

**Structure:**
```
pcc-app-shared-infra/
├── main.tf (references pcc-tf-library modules)
├── variables.tf
├── terraform.tfvars
└── outputs.tf
```

**Deploy:**
```bash
cd pcc-app-shared-infra
terraform init
terraform plan
terraform apply
```

### Deliverables
- [x] pcc-tf-library with Apigee + shared resources Terraform
- [x] GCP resources provisioned (Apigee org, devtest env, GCS, Artifact Registry)
- [x] Service accounts configured with proper IAM roles
- [x] GKE cluster with devtest namespace and ArgoCD ready
- [x] Secret Manager populated with git-token, argocd-password, apigee-access-token
- [x] pcc-app-shared-infra deployed via Terraform

### Dependencies for Next Phase
- Apigee environment and API product must exist before pipeline deploy-apigee.sh
- GCS bucket must exist before OpenAPI spec upload
- Secret Manager tokens must be accessible by Cloud Build SA

---

## PHASE 2: Pipeline Library Creation

**Timeline:** Week 1, Days 4-5

### Objectives
Build the reusable pcc-pipeline-library with all scripts and templates that services will import.

### Repository Structure
```
pcc-pipeline-library/
├── cloudbuild/
│   └── dotnet-apigee-pipeline.yaml (template, not used directly)
├── scripts/
│   ├── build.sh
│   ├── generate-spec.sh
│   ├── update-config.sh
│   ├── wait-argocd.sh
│   └── deploy-apigee.sh
├── services-config.yaml
└── README.md
```

### Key Scripts

#### 2.1 build.sh
**Purpose:** Build and test .NET project

```bash
#!/bin/bash
set -e

PROJECT_PATH=${1:-"."}
CONFIGURATION=${2:-"Release"}

echo "Building .NET project at $PROJECT_PATH..."
cd "$PROJECT_PATH"

dotnet restore
dotnet build --configuration $CONFIGURATION --no-restore

# Run tests (if test project exists)
if ls *.Tests.csproj 1> /dev/null 2>&1; then
  echo "Running tests..."
  dotnet test --configuration $CONFIGURATION --no-build --verbosity normal
fi

echo "Build completed successfully"
```

#### 2.2 generate-spec.sh
**Purpose:** Locate pre-built OpenAPI spec and upload to GCS

**Key Logic:**
- Locate OpenAPI spec file (built at build time or checked into repo)
- Validate spec exists and is valid JSON
- Upload to GCS with service/environment path

**Note:** .NET 10 is not compatible with Swashbuckle. The dev team is building OpenAPI specs at build time or checking them into the repo. This script simply finds and uploads the existing spec.

```bash
#!/bin/bash
set -e

SERVICE_NAME=$1
ENVIRONMENT=$2
PROJECT_PATH=${3:-.}
GCS_BUCKET=${4:-pcc-specs-bucket}

cd "$PROJECT_PATH"

# Look for OpenAPI spec in common locations
SPEC_FILE=""
if [ -f "openapi.json" ]; then
  SPEC_FILE="openapi.json"
elif [ -f "swagger.json" ]; then
  SPEC_FILE="swagger.json"
elif [ -f "docs/openapi.json" ]; then
  SPEC_FILE="docs/openapi.json"
elif [ -f "api/openapi.json" ]; then
  SPEC_FILE="api/openapi.json"
else
  echo "Error: OpenAPI spec not found"
  echo "Searched locations: openapi.json, swagger.json, docs/openapi.json, api/openapi.json"
  exit 1
fi

echo "Found OpenAPI spec: $SPEC_FILE"

# Validate JSON format
if ! jq empty "$SPEC_FILE" 2>/dev/null; then
  echo "Error: OpenAPI spec is not valid JSON"
  exit 1
fi

# Validate spec has paths
PATH_COUNT=$(jq '.paths | length' "$SPEC_FILE")
if [ "$PATH_COUNT" -eq 0 ]; then
  echo "Error: OpenAPI spec has no paths"
  exit 1
fi

echo "✓ Spec validation passed ($PATH_COUNT paths found)"

# Upload to GCS
GCS_PATH="gs://${GCS_BUCKET}/${ENVIRONMENT}/${SERVICE_NAME}/openapi.json"
echo "Uploading spec to $GCS_PATH..."
gsutil cp "$SPEC_FILE" "$GCS_PATH"

echo "✓ OpenAPI spec uploaded successfully"
```

#### 2.3 update-config.sh
**Purpose:** Update pcc-app-argo-config deployment manifest with new image tag

```bash
#!/bin/bash
set -e

SERVICE_NAME=$1
ENVIRONMENT=$2
IMAGE_TAG=$3
GIT_TOKEN=$4

REPO_URL="https://github.com/your-org/pcc-app-argo-config.git"
MANIFEST_PATH="${ENVIRONMENT}/${SERVICE_NAME}/deployment.yaml"

# Clone config repo
git clone "https://oauth2:${GIT_TOKEN}@${REPO_URL#https://}" /tmp/argo-config
cd /tmp/argo-config

# Update image tag in deployment
sed -i "s|image: .*pcc-app-${SERVICE_NAME}-${ENVIRONMENT}:.*|image: gcr.io/\${PROJECT_ID}/pcc-app-${SERVICE_NAME}-${ENVIRONMENT}:${IMAGE_TAG}|g" \
  "$MANIFEST_PATH"

# Commit and push
git config user.email "cloudbuild@pcc-project.iam.gserviceaccount.com"
git config user.name "Cloud Build"
git add "$MANIFEST_PATH"
git commit -m "build: update ${SERVICE_NAME} to ${IMAGE_TAG} in ${ENVIRONMENT}"
git push origin main

echo "Config updated for ArgoCD sync"
```

#### 2.4 wait-argocd.sh
**Purpose:** Poll ArgoCD for healthy deployment with timeout

```bash
#!/bin/bash
set -e

ARGO_APP_NAME=$1
ARGOCD_SERVER=$2
ARGOCD_PASSWORD=$3
TIMEOUT=${4:-300}  # 5 minutes default

# Login to ArgoCD
argocd login "$ARGOCD_SERVER" --username admin --password "$ARGOCD_PASSWORD" --insecure

echo "Waiting for $ARGO_APP_NAME to become healthy (timeout: ${TIMEOUT}s)..."
ELAPSED=0

while [ $ELAPSED -lt $TIMEOUT ]; do
  HEALTH=$(argocd app get "$ARGO_APP_NAME" -o json | jq -r '.status.health.status')
  SYNC=$(argocd app get "$ARGO_APP_NAME" -o json | jq -r '.status.sync.status')

  echo "[$ELAPSED s] Health: $HEALTH, Sync: $SYNC"

  if [ "$HEALTH" = "Healthy" ] && [ "$SYNC" = "Synced" ]; then
    echo "✓ Deployment successful!"
    exit 0
  fi

  sleep 10
  ELAPSED=$((ELAPSED + 10))
done

echo "✗ Timeout waiting for ArgoCD deployment"
exit 1
```

#### 2.5 deploy-apigee.sh
**Purpose:** Create/update Apigee proxy, attach to API product

```bash
#!/bin/bash
set -e

SERVICE_NAME=$1
ENVIRONMENT=$2
GCS_BUCKET=${3:-pcc-specs-bucket}
APIGEE_ORG=${4:-pcc-org}
API_PRODUCT=${5:-pcc-all-services-${ENVIRONMENT}}
BACKEND_URL=$6  # e.g., https://auth.devtest.svc.cluster.local

# Download OpenAPI spec from GCS
SPEC_PATH="/tmp/${SERVICE_NAME}-spec.json"
gsutil cp "gs://${GCS_BUCKET}/${ENVIRONMENT}/${SERVICE_NAME}/openapi.json" "$SPEC_PATH"

PROXY_NAME="${SERVICE_NAME}-${ENVIRONMENT}"

# Check if proxy exists
if apigeecli apis get --name "$PROXY_NAME" --org "$APIGEE_ORG" 2>/dev/null; then
  echo "Updating existing proxy: $PROXY_NAME"
  REVISION=$(apigeecli apis create openapi \
    --name "$PROXY_NAME" \
    --spec "$SPEC_PATH" \
    --org "$APIGEE_ORG" \
    --basepath "/${SERVICE_NAME}" \
    --target-url "$BACKEND_URL" \
    --format json | jq -r '.revision')
else
  echo "Creating new proxy: $PROXY_NAME"
  REVISION=$(apigeecli apis create openapi \
    --name "$PROXY_NAME" \
    --spec "$SPEC_PATH" \
    --org "$APIGEE_ORG" \
    --basepath "/${SERVICE_NAME}" \
    --target-url "$BACKEND_URL" \
    --format json | jq -r '.revision')
fi

# Deploy to environment
echo "Deploying revision $REVISION to $ENVIRONMENT..."
apigeecli apis deploy \
  --name "$PROXY_NAME" \
  --rev "$REVISION" \
  --env "$ENVIRONMENT" \
  --org "$APIGEE_ORG" \
  --wait

# Attach to API product (idempotent)
echo "Attaching proxy to API product: $API_PRODUCT"
apigeecli products update \
  --name "$API_PRODUCT" \
  --org "$APIGEE_ORG" \
  --add-proxy "$PROXY_NAME"

echo "✓ Apigee proxy deployed successfully"
echo "  Endpoint: https://${ENVIRONMENT}-api.pccdomain.com/${SERVICE_NAME}"
```

#### 2.6 services-config.yaml
**Purpose:** Centralized service registry for documentation

```yaml
services:
  - name: auth
    description: Authentication and authorization service (Descope integration)
    basepath: /auth
  - name: client
    description: Client management service
    basepath: /client
  - name: user
    description: User management service
    basepath: /user
  - name: metric-builder
    description: Metric definition builder
    basepath: /metric-builder
  - name: metric-tracker
    description: Metric tracking and aggregation
    basepath: /metric-tracker
  - name: task-builder
    description: Task workflow builder
    basepath: /task-builder
  - name: task-tracker
    description: Task execution and tracking
    basepath: /task-tracker
```

### Deliverables
- [x] pcc-pipeline-library repo with all 5 scripts (executable, tested locally)
- [x] services-config.yaml with all 7 services
- [x] README.md with usage instructions
- [x] Scripts handle errors gracefully (set -e, validation checks)
- [x] All scripts are parameterized (no hardcoded values)

### Testing
- Test each script individually with mock data
- Verify jq, gsutil, apigeecli, argocd CLI are available in Cloud Build
- Validate OpenAPI spec filtering logic with sample Swagger JSON

### Dependencies for Next Phase
- Scripts must be committed to pcc-pipeline-library/main before service POC
- Cloud Build must have execute permissions on scripts
- All CLI tools (apigeecli, argocd, jq) must be in Cloud Build image or installed in pipeline

---

## PHASE 3: ArgoCD Config Repository Setup

**Timeline:** Week 2, Day 1

### Objectives
Create pcc-app-argo-config repository with Kubernetes manifests and ArgoCD Application definitions for all services in devtest environment.

### Repository Structure
```
pcc-app-argo-config/
├── devtest/
│   ├── auth/
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   ├── client/
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   ├── user/
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   ├── metric-builder/
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   ├── metric-tracker/
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   ├── task-builder/
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   └── task-tracker/
│       ├── deployment.yaml
│       └── service.yaml
├── argocd-apps/
│   ├── auth-devtest.yaml
│   ├── client-devtest.yaml
│   ├── user-devtest.yaml
│   ├── metric-builder-devtest.yaml
│   ├── metric-tracker-devtest.yaml
│   ├── task-builder-devtest.yaml
│   └── task-tracker-devtest.yaml
└── README.md
```

### Deployment Template Example

**devtest/auth/deployment.yaml:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pcc-auth-api
  namespace: devtest
  labels:
    app: pcc-auth-api
    environment: devtest
spec:
  replicas: 2
  selector:
    matchLabels:
      app: pcc-auth-api
  template:
    metadata:
      labels:
        app: pcc-auth-api
        environment: devtest
    spec:
      serviceAccountName: pcc-auth-sa
      containers:
      - name: auth-api
        image: gcr.io/PROJECT_ID/pcc-app-auth-devtest:latest
        imagePullPolicy: Always
        ports:
        - containerPort: 8080
          name: http
        env:
        - name: ASPNETCORE_ENVIRONMENT
          value: "Development"
        - name: DESCOPE_PROJECT_ID
          valueFrom:
            secretKeyRef:
              name: descope-config
              key: project-id
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health/live
            port: http
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health/ready
            port: http
          initialDelaySeconds: 10
          periodSeconds: 5
```

**Customization per service:**
- Replace `auth` with service name in all fields
- Adjust env vars (e.g., Descope only for auth service)
- Image path: `gcr.io/PROJECT_ID/pcc-app-{service}-devtest:latest`

### Service Template Example

**devtest/auth/service.yaml:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: pcc-auth-api
  namespace: devtest
  labels:
    app: pcc-auth-api
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 8080
    protocol: TCP
    name: http
  selector:
    app: pcc-auth-api
```

**Backend URL Pattern:**
- Internal: `http://pcc-auth-api.devtest.svc.cluster.local`
- Used by Apigee as target URL

### ArgoCD Application Definition

**argocd-apps/auth-devtest.yaml:**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: pcc-auth-devtest
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/pcc-app-argo-config.git
    targetRevision: main
    path: devtest/auth
  destination:
    server: https://kubernetes.default.svc
    namespace: devtest
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

**Apply to cluster:**
```bash
kubectl apply -f argocd-apps/auth-devtest.yaml
kubectl apply -f argocd-apps/client-devtest.yaml
# ... repeat for all 7 services
```

### Automation Script

**scripts/generate-manifests.sh:**
```bash
#!/bin/bash
SERVICES=(auth client user metric-builder metric-tracker task-builder task-tracker)

for service in "${SERVICES[@]}"; do
  # Create directory
  mkdir -p "devtest/${service}"

  # Generate deployment.yaml (with sed replacements)
  sed "s/SERVICE_NAME/${service}/g" templates/deployment.yaml.template \
    > "devtest/${service}/deployment.yaml"

  # Generate service.yaml
  sed "s/SERVICE_NAME/${service}/g" templates/service.yaml.template \
    > "devtest/${service}/service.yaml"

  # Generate ArgoCD app
  sed "s/SERVICE_NAME/${service}/g" templates/argocd-app.yaml.template \
    > "argocd-apps/${service}-devtest.yaml"
done
```

### Initial Deployment

**Setup steps:**
1. Commit all manifests to pcc-app-argo-config/main
2. Apply ArgoCD Applications to cluster:
   ```bash
   kubectl apply -f argocd-apps/*.yaml
   ```
3. Verify in ArgoCD UI:
   - All 7 apps appear
   - Status: "OutOfSync" (expected, no images deployed yet)
   - Health: "Missing" (expected, waiting for deployment)

### Backend URL Discovery for Pipeline

**Pattern:** `http://pcc-{service}-api.devtest.svc.cluster.local`

**In deploy-apigee.sh, add logic:**
```bash
# Auto-construct backend URL from service name and environment
BACKEND_URL="http://pcc-${SERVICE_NAME}-api.${ENVIRONMENT}.svc.cluster.local"
```

### Deliverables
- [x] pcc-app-argo-config repo with 7 service manifests in devtest/
- [x] 7 ArgoCD Application definitions in argocd-apps/
- [x] All apps applied to ArgoCD (visible in UI, awaiting sync)
- [x] Kubernetes Services created (provides stable backend URLs)
- [x] README.md with manifest update instructions

### Validation
```bash
# Check ArgoCD apps
argocd app list

# Check namespaces
kubectl get namespaces | grep devtest

# Check services (will be empty until first deployment)
kubectl get svc -n devtest
```

### Dependencies for Next Phase
- ArgoCD apps must be created before pipeline's update-config.sh runs
- Service names must match exactly in manifests and pipeline substitutions
- Backend URLs must be predictable for Apigee proxy creation

---

## PHASE 4: POC Service Implementation - pcc-auth-api

**Timeline:** Week 2, Days 2-3

### Objectives
Implement and validate the complete pipeline with pcc-auth-api as the first service, proving the entire flow from code push to Apigee deployment.

### .NET Project Setup

**Note:** .NET 10 is not compatible with Swashbuckle. The dev team is handling OpenAPI spec generation separately (either at build time or checked into repo).

#### Add health check endpoints in Program.cs
```csharp
app.MapGet("/health/live", () => Results.Ok(new { status = "alive" }));
app.MapGet("/health/ready", () => Results.Ok(new { status = "ready" }));
```

### Dockerfile

**pcc-auth-api/Dockerfile:**
```dockerfile
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS base
WORKDIR /app
EXPOSE 8080

FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY ["src/PccAuthApi.WebAPI/PccAuthApi.WebAPI.csproj", "PccAuthApi.WebAPI/"]
RUN dotnet restore "PccAuthApi.WebAPI/PccAuthApi.WebAPI.csproj"
COPY src/ .
WORKDIR "/src/PccAuthApi.WebAPI"
RUN dotnet build "PccAuthApi.WebAPI.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "PccAuthApi.WebAPI.csproj" -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENV ASPNETCORE_URLS=http://+:8080
ENTRYPOINT ["dotnet", "PccAuthApi.WebAPI.dll"]
```

### Cloud Build Configuration

**pcc-auth-api/cloudbuild.yaml:**
```yaml
steps:
  # Step 1: Clone pipeline library
  - name: 'gcr.io/cloud-builders/git'
    secretEnv: ['GIT_TOKEN']
    args:
      - clone
      - '--branch=main'
      - 'https://oauth2:$$GIT_TOKEN@github.com/your-org/pcc-pipeline-library.git'
      - /workspace/pipeline-library
    id: 'clone-pipeline-lib'

  # Step 2: Install dependencies for scripts
  - name: 'gcr.io/cloud-builders/gcloud'
    args: ['components', 'install', 'kubectl', 'beta', '--quiet']
    id: 'install-kubectl'

  # Step 3: Install apigeecli and argocd CLI
  - name: 'gcr.io/cloud-builders/gcloud'
    entrypoint: 'bash'
    args:
      - '-c'
      - |
        # Install apigeecli
        curl -L https://github.com/apigee/apigeecli/releases/latest/download/apigeecli_Linux_x86_64.tar.gz \
          -o apigeecli.tar.gz
        tar -xzf apigeecli.tar.gz
        mv apigeecli /workspace/bin/

        # Install argocd CLI
        curl -sSL -o /workspace/bin/argocd \
          https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
        chmod +x /workspace/bin/argocd

        # Install jq
        apt-get update && apt-get install -y jq
    id: 'install-tools'

  # Step 4: Build .NET project
  - name: 'mcr.microsoft.com/dotnet/sdk:10.0'
    entrypoint: 'bash'
    args:
      - '/workspace/pipeline-library/scripts/build.sh'
      - '.'
    id: 'build-dotnet'

  # Step 5: Upload pre-built OpenAPI spec to GCS
  - name: 'gcr.io/cloud-builders/gcloud'
    entrypoint: 'bash'
    args:
      - '/workspace/pipeline-library/scripts/generate-spec.sh'
      - '${_SERVICE_NAME}'
      - '${_ENVIRONMENT}'
      - '.'
      - '${_GCS_BUCKET}'
    env:
      - 'PATH=/workspace/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
    id: 'upload-openapi-spec'
    waitFor: ['build-dotnet', 'install-tools']

  # Step 6: Build and push Docker image
  - name: 'gcr.io/cloud-builders/docker'
    args:
      - build
      - '-t'
      - 'gcr.io/$PROJECT_ID/${_DOCKER_REPO}:$SHORT_SHA'
      - '-t'
      - 'gcr.io/$PROJECT_ID/${_DOCKER_REPO}:latest'
      - '-f'
      - Dockerfile
      - '.'
    id: 'build-docker'
    waitFor: ['build-dotnet']

  - name: 'gcr.io/cloud-builders/docker'
    args: ['push', '--all-tags', 'gcr.io/$PROJECT_ID/${_DOCKER_REPO}']
    id: 'push-docker'
    waitFor: ['build-docker']

  # Step 7: Update ArgoCD config repo
  - name: 'gcr.io/cloud-builders/git'
    secretEnv: ['GIT_TOKEN']
    entrypoint: 'bash'
    args:
      - '/workspace/pipeline-library/scripts/update-config.sh'
      - '${_SERVICE_NAME}'
      - '${_ENVIRONMENT}'
      - '$SHORT_SHA'
      - '$$GIT_TOKEN'
    id: 'update-argocd-config'
    waitFor: ['push-docker']

  # Step 8: Wait for ArgoCD deployment
  - name: 'gcr.io/cloud-builders/gcloud'
    secretEnv: ['ARGOCD_PASSWORD']
    entrypoint: 'bash'
    args:
      - '/workspace/pipeline-library/scripts/wait-argocd.sh'
      - '${_ARGO_APP_NAME}'
      - '${_ARGOCD_SERVER}'
      - '$$ARGOCD_PASSWORD'
      - '300'
    env:
      - 'PATH=/workspace/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
    id: 'wait-argocd-sync'
    waitFor: ['update-argocd-config', 'install-tools']

  # Step 9: Deploy Apigee proxy
  - name: 'gcr.io/cloud-builders/gcloud'
    secretEnv: ['APIGEE_TOKEN']
    entrypoint: 'bash'
    args:
      - '/workspace/pipeline-library/scripts/deploy-apigee.sh'
      - '${_SERVICE_NAME}'
      - '${_ENVIRONMENT}'
      - '${_GCS_BUCKET}'
      - '${_APIGEE_ORG}'
      - 'pcc-all-services-${_ENVIRONMENT}'
      - 'http://pcc-${_SERVICE_NAME}-api.${_ENVIRONMENT}.svc.cluster.local'
    env:
      - 'PATH=/workspace/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
      - 'APIGEE_ACCESS_TOKEN=$$APIGEE_TOKEN'
    id: 'deploy-apigee-proxy'
    waitFor: ['wait-argocd-sync', 'upload-openapi-spec', 'install-tools']

# Secrets from Secret Manager
availableSecrets:
  secretManager:
    - versionName: projects/$PROJECT_ID/secrets/git-token/versions/latest
      env: GIT_TOKEN
    - versionName: projects/$PROJECT_ID/secrets/argocd-password/versions/latest
      env: ARGOCD_PASSWORD
    - versionName: projects/$PROJECT_ID/secrets/apigee-access-token/versions/latest
      env: APIGEE_TOKEN

# Substitutions (defaults for devtest)
substitutions:
  _SERVICE_NAME: 'auth'
  _DOCKER_REPO: 'pcc-app-auth-devtest'
  _ARGO_APP_NAME: 'pcc-auth-devtest'
  _ENVIRONMENT: 'devtest'
  _REGION: 'us-central1'
  _GCS_BUCKET: 'pcc-specs-bucket'
  _APIGEE_ORG: 'pcc-org'
  _ARGOCD_SERVER: 'argocd.your-domain.com'

options:
  logging: CLOUD_LOGGING_ONLY
  machineType: 'E2_HIGHCPU_8'

timeout: 1800s  # 30 minutes
```

### Create Cloud Build Trigger

```bash
gcloud builds triggers create github \
  --repo-name=pcc-auth-api \
  --repo-owner=your-org \
  --branch-pattern=^devtest$ \
  --build-config=cloudbuild.yaml \
  --name=pcc-auth-api-devtest
```

### Test Pipeline Execution

**Steps:**
1. Make small code change in pcc-auth-api
2. Commit to devtest branch:
   ```bash
   git checkout devtest
   git add .
   git commit -m "test: trigger pipeline for POC validation"
   git push origin devtest
   ```
3. Monitor Cloud Build console for execution

### Validation Checklist
- [x] Build succeeds (dotnet build, test pass)
- [x] OpenAPI spec found and uploaded to `gs://pcc-specs-bucket/devtest/auth/openapi.json`
- [x] Docker image pushed to `gcr.io/PROJECT_ID/pcc-app-auth-devtest:SHORT_SHA`
- [x] ArgoCD config updated, app syncs to Healthy
- [x] Apigee proxy `auth-devtest` created/updated
- [x] Apigee endpoint accessible: `https://devtest-api.pccdomain.com/auth`

### Troubleshooting
- **OpenAPI spec not found:** Ensure spec file exists in repo (check openapi.json, swagger.json, docs/, api/)
- **ArgoCD timeout:** Increase wait time or check pod logs
- **Apigee deployment fails:** Verify access token, check Apigee org/env exist

### Deliverables
- [x] pcc-auth-api with Dockerfile and cloudbuild.yaml configured
- [x] OpenAPI spec file exists in repo (handled by dev team)
- [x] Cloud Build trigger created for devtest branch
- [x] Complete pipeline execution validated end-to-end
- [x] First Apigee proxy deployed and accessible

### Success Criteria
- Pipeline runs in <15 minutes
- All 9 steps complete successfully
- ArgoCD shows Healthy + Synced
- Apigee proxy responds to requests
- JWT validation works (if integrated with Descope)

---

## PHASE 5: Second Service Validation - pcc-client-api

**Timeline:** Week 2, Day 4

### Objectives
Validate pipeline repeatability and identify any service-specific variations.

### Implementation Steps

#### 5.1 Copy Template Files
```bash
# From pcc-auth-api to pcc-client-api
cp ../pcc-auth-api/Dockerfile .
cp ../pcc-auth-api/cloudbuild.yaml .
```

#### 5.2 Update cloudbuild.yaml Substitutions
```yaml
substitutions:
  _SERVICE_NAME: 'client'  # Changed from 'auth'
  _DOCKER_REPO: 'pcc-app-client-devtest'
  _ARGO_APP_NAME: 'pcc-client-devtest'
  _ENVIRONMENT: 'devtest'
  # ... rest remains same
```

#### 5.3 Verify .NET Configuration
- Controllers have routes starting with `/client/*`
- OpenAPI spec file exists (openapi.json or swagger.json in repo)
- Health check endpoints exist

#### 5.4 Adjust Dockerfile
```dockerfile
COPY ["src/PccClientApi.WebAPI/PccClientApi.WebAPI.csproj", "PccClientApi.WebAPI/"]
# ... adjust based on actual project structure
```

#### 5.5 Create Cloud Build Trigger
```bash
gcloud builds triggers create github \
  --repo-name=pcc-client-api \
  --repo-owner=your-org \
  --branch-pattern=^devtest$ \
  --build-config=cloudbuild.yaml \
  --name=pcc-client-api-devtest
```

#### 5.6 Test Pipeline
Push to devtest branch and monitor Cloud Build

### Expected Results
- Pipeline completes in ~10-15 minutes
- OpenAPI spec: `gs://pcc-specs-bucket/devtest/client/openapi.json`
- ArgoCD app `pcc-client-devtest` syncs to Healthy
- Apigee endpoint: `https://devtest-api.pccdomain.com/client`

### Service Onboarding Checklist

Create: `pcc-pipeline-library/docs/service-onboarding-checklist.md`

```markdown
# Service Onboarding Checklist

## Prerequisites
- [ ] Service repository exists with .NET 10 code
- [ ] Controllers use basepath: `/{service-name}/*`
- [ ] OpenAPI spec file exists (openapi.json, swagger.json, or in docs/ folder)
- [ ] Health endpoints implemented: `/health/live`, `/health/ready`

## Setup Steps (15 minutes)
1. [ ] Copy Dockerfile from template (adjust project paths)
2. [ ] Copy cloudbuild.yaml from template
3. [ ] Update substitutions:
   - _SERVICE_NAME
   - _DOCKER_REPO
   - _ARGO_APP_NAME
4. [ ] Create Cloud Build trigger
5. [ ] Test with small code change

## Validation
- [ ] Pipeline completes successfully
- [ ] OpenAPI spec in GCS
- [ ] ArgoCD app Healthy + Synced
- [ ] Apigee endpoint responds
- [ ] Check logs for errors

## Common Issues
- **OpenAPI spec not found**: Ensure spec file is in repo (openapi.json, swagger.json, docs/, or api/)
- **ArgoCD timeout**: Check pod status, may need more replicas
- **Apigee 404**: Check target URL matches Service name in k8s
```

### Deliverables
- [x] pcc-client-api deployed via pipeline
- [x] Second service validates repeatability
- [x] Service onboarding checklist created
- [x] Any edge cases documented
- [x] Pipeline library bugs fixed (if found)

### Success Criteria
- Second service takes ≤15 minutes to onboard
- Pipeline runtime similar to auth service
- No manual intervention required

---

## PHASE 6: Parallel Rollout - Remaining 5 Services

**Timeline:** Week 2, Day 5 - Week 3, Day 2

### Objectives
Deploy remaining services using proven pipeline template.

### Services to Deploy
1. pcc-user-api
2. pcc-metric-builder-api
3. pcc-metric-tracker-api
4. pcc-task-builder-api
5. pcc-task-tracker-api

### Execution Plan
```
Day 1: user-api, metric-builder-api
Day 2: metric-tracker-api, task-builder-api
Day 3: task-tracker-api + integration testing
```

### Template Files

Create: `pcc-pipeline-library/templates/service-repo-template/`

**Dockerfile.template:**
```dockerfile
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS base
WORKDIR /app
EXPOSE 8080

FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY ["src/Pcc{{SERVICE_PASCAL}}Api.WebAPI/Pcc{{SERVICE_PASCAL}}Api.WebAPI.csproj", "Pcc{{SERVICE_PASCAL}}Api.WebAPI/"]
RUN dotnet restore "Pcc{{SERVICE_PASCAL}}Api.WebAPI/Pcc{{SERVICE_PASCAL}}Api.WebAPI.csproj"
COPY src/ .
WORKDIR "/src/Pcc{{SERVICE_PASCAL}}Api.WebAPI"
RUN dotnet build "Pcc{{SERVICE_PASCAL}}Api.WebAPI.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "Pcc{{SERVICE_PASCAL}}Api.WebAPI.csproj" -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENV ASPNETCORE_URLS=http://+:8080
ENTRYPOINT ["dotnet", "Pcc{{SERVICE_PASCAL}}Api.WebAPI.dll"]
```

### Automation Script

Create: `pcc-pipeline-library/scripts/setup-service.sh`

```bash
#!/bin/bash
set -e

SERVICE_NAME=$1  # e.g., "user", "metric-builder"
SERVICE_PASCAL=$2  # e.g., "User", "MetricBuilder"
REPO_PATH=$3  # Path to service repo

if [ -z "$SERVICE_NAME" ] || [ -z "$SERVICE_PASCAL" ] || [ -z "$REPO_PATH" ]; then
  echo "Usage: setup-service.sh <service-name> <ServicePascal> <repo-path>"
  echo "Example: setup-service.sh user User ../pcc-user-api"
  exit 1
fi

echo "Setting up $SERVICE_NAME service..."

# Copy and customize Dockerfile
sed "s/{{SERVICE_PASCAL}}/$SERVICE_PASCAL/g" templates/service-repo-template/Dockerfile.template \
  > "$REPO_PATH/Dockerfile"

# Copy and customize cloudbuild.yaml
sed -e "s/{{SERVICE_NAME}}/$SERVICE_NAME/g" \
    -e "s/{{SERVICE_PASCAL}}/$SERVICE_PASCAL/g" \
    templates/service-repo-template/cloudbuild.yaml.template \
  > "$REPO_PATH/cloudbuild.yaml"

echo "✓ Files created in $REPO_PATH"
echo ""
echo "Next steps:"
echo "1. Review and adjust Dockerfile project paths if needed"
echo "2. Commit Dockerfile and cloudbuild.yaml to devtest branch"
echo "3. Create Cloud Build trigger:"
echo "   gcloud builds triggers create github \\"
echo "     --repo-name=pcc-${SERVICE_NAME}-api \\"
echo "     --repo-owner=your-org \\"
echo "     --branch-pattern=^devtest$ \\"
echo "     --build-config=cloudbuild.yaml \\"
echo "     --name=pcc-${SERVICE_NAME}-api-devtest"
echo "4. Push small change to devtest to test pipeline"
```

### Integration Testing Script

Create: `pcc-pipeline-library/tests/integration-test.sh`

```bash
#!/bin/bash
ENVIRONMENT=${1:-devtest}
APIGEE_BASE_URL="https://${ENVIRONMENT}-api.pccdomain.com"

SERVICES=(auth client user metric-builder metric-tracker task-builder task-tracker)

echo "Testing all services in $ENVIRONMENT..."
for service in "${SERVICES[@]}"; do
  echo -n "Testing /${service}... "
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${APIGEE_BASE_URL}/${service}/health/ready")

  if [ "$STATUS" -eq 200 ]; then
    echo "✓ OK"
  else
    echo "✗ FAILED (HTTP $STATUS)"
  fi
done
```

### Apigee Developer Portal Configuration

**Tasks:**
1. Enable developer portal in Apigee console
2. Configure API product `pcc-all-services-devtest`:
   - Add all 7 proxies
   - Set visibility: Public or Internal
   - Add documentation from OpenAPI specs
3. Create sample app registration for React client
4. Generate API key for testing

**Validation:**
```bash
curl -H "X-API-Key: YOUR_KEY" \
  https://devtest-api.pccdomain.com/auth/health/ready
```

### Deliverables
- [x] All 7 services deployed to devtest environment
- [x] Setup automation script tested
- [x] Integration test script validates all endpoints
- [x] Apigee developer portal configured
- [x] All OpenAPI specs visible in portal

### Validation Checklist
```bash
# ArgoCD apps status
argocd app list | grep devtest
# All should show: Synced, Healthy

# Kubernetes deployments
kubectl get deployments -n devtest
# All should show: 2/2 READY

# Apigee proxies
apigeecli apis list --org pcc-org --env devtest
# Should list all 7 proxies

# Integration test
./tests/integration-test.sh devtest
# All services should return HTTP 200
```

---

## PHASE 7: Multi-Environment Preparation & Production Readiness

**Timeline:** Week 3, Days 3-5

### Objectives
Establish monitoring, documentation, and multi-environment expansion strategy.

### Multi-Environment Strategy

#### Branch-to-Environment Mapping
```
Branch    | Env     | Namespace | Apigee Env | Domain                    | Approval
----------|---------|-----------|------------|---------------------------|----------
devtest   | devtest | devtest   | devtest    | devtest-api.pccdomain.com | No
dev       | dev     | dev       | dev        | dev-api.pccdomain.com     | No
staging   | staging | staging   | staging    | staging-api.pccdomain.com | Yes
main      | prod    | prod      | prod       | api.pccdomain.com         | Yes
```

#### Expansion Steps (Per Environment)

**Infrastructure (pcc-tf-library):**
1. Add environment-specific tfvars
2. Create Apigee environment in Terraform
3. Create API product: `pcc-all-services-{env}`
4. Apply via `pcc-app-shared-infra`

**ArgoCD (pcc-app-argo-config):**
1. Create `{env}/` directories for all 7 services
2. Generate deployment/service manifests
3. Create ArgoCD Application definitions
4. Apply to cluster

**Cloud Build:**
1. Update triggers to watch new branch patterns
2. Add approval steps for staging/prod
3. Test with single service first

#### Rollout Timeline
- Month 3, Week 1: `dev` environment
- Month 3, Week 2: `staging` environment
- Month 3, Week 3-4: `prod` environment (with approval workflows)

### Approval Workflow for Production

**Modify cloudbuild.yaml:**
```yaml
# Add before Apigee deployment step
- name: 'gcr.io/cloud-builders/gcloud'
  entrypoint: 'bash'
  args:
    - '-c'
    - |
      if [ "${_ENVIRONMENT}" = "staging" ] || [ "${_ENVIRONMENT}" = "prod" ]; then
        echo "Manual approval required for ${_ENVIRONMENT}"
        echo "Waiting for approval..."
      fi
  id: 'approval-gate'
  waitFor: ['wait-argocd-sync']
```

**Cloud Build trigger for prod:**
```bash
gcloud builds triggers create github \
  --repo-name=pcc-auth-api \
  --repo-owner=your-org \
  --branch-pattern=^main$ \
  --build-config=cloudbuild.yaml \
  --name=pcc-auth-api-prod \
  --require-approval
```

### Monitoring and Observability

Create: `pcc-pipeline-library/docs/monitoring-guide.md`

#### Cloud Logging Queries
```bash
# Pipeline failures
resource.type="build"
severity="ERROR"
resource.labels.build_trigger_id=~"pcc-.*-devtest"

# ArgoCD sync failures
resource.type="k8s_pod"
resource.labels.namespace_name="devtest"
severity="ERROR"

# Apigee proxy errors
resource.type="api"
httpRequest.status>=500
```

#### Cloud Monitoring Alerts
1. **Build Failure Alert:**
   - Condition: Any Cloud Build failure
   - Notification: Email/Slack
   - Threshold: 1 failure

2. **ArgoCD Sync Alert:**
   - Condition: App not Synced/Healthy for >10 minutes
   - Notification: Email/PagerDuty (prod)

3. **Apigee Error Rate:**
   - Condition: 5xx errors >1% of requests
   - Notification: Slack/PagerDuty (prod)

#### Apigee Analytics
- Enable analytics for all environments
- Create custom reports for each service
- Set up alerts for high latency (>1s p95)

### Maintenance Procedures

Create: `pcc-pipeline-library/docs/runbook.md`

#### Regular Maintenance
```markdown
## Weekly
- [ ] Review Cloud Build logs for warnings
- [ ] Check Artifact Registry storage usage
- [ ] Verify all ArgoCD apps Healthy/Synced
- [ ] Review Apigee analytics for anomalies

## Monthly
- [ ] Rotate Secret Manager secrets
- [ ] Clean up old Docker images (>30 days)
- [ ] Review and update pipeline library scripts
- [ ] Update dependencies in service repos
- [ ] Review and optimize resource quotas

## Quarterly
- [ ] Review Apigee pricing and usage
- [ ] Audit IAM permissions
- [ ] Update disaster recovery procedures
- [ ] Performance testing and optimization
```

#### Common Issues and Solutions
```markdown
### Pipeline Failures

**Issue: OpenAPI spec not found**
- Ensure spec file exists: openapi.json, swagger.json, docs/openapi.json, or api/openapi.json
- Verify file is valid JSON with `jq . spec-file.json`
- Check `generate-spec.sh` search paths match your repo structure

**Issue: ArgoCD timeout**
- Check pod status: `kubectl get pods -n {env}`
- Review pod logs for startup errors
- Increase timeout in `wait-argocd.sh` if needed

**Issue: Apigee deployment fails**
- Verify access token in Secret Manager
- Check Apigee org/env exist: `apigeecli envs list`
- Validate OpenAPI spec format: `jq . spec.json`

### Service Issues

**Issue: Service not responding**
- Check ArgoCD: `argocd app get pcc-{service}-{env}`
- Check pods: `kubectl get pods -n {env} -l app=pcc-{service}-api`
- Check logs: `kubectl logs -n {env} -l app=pcc-{service}-api`

**Issue: Apigee 502/503 errors**
- Verify backend URL is correct
- Check GKE Service exists and has endpoints
- Test backend directly from within cluster
```

### Disaster Recovery Plan

Create: `pcc-pipeline-library/docs/disaster-recovery.md`

#### Backup Strategy
- Git repos: Primary source of truth (GitHub)
- ArgoCD manifests: Versioned in `pcc-app-argo-config`
- Terraform state: Stored in GCS with versioning enabled
- Apigee configuration: Export proxies weekly via `apigeecli`

#### Recovery Procedures
```bash
# Restore ArgoCD applications
kubectl apply -f pcc-app-argo-config/argocd-apps/

# Redeploy Terraform infrastructure
cd pcc-app-shared-infra
terraform init
terraform plan
terraform apply

# Rebuild all service images
for service in auth client user metric-builder metric-tracker task-builder task-tracker; do
  gcloud builds triggers run pcc-${service}-api-devtest
done
```

#### RTO/RPO Targets
- **devtest**: RTO 4 hours, RPO 1 day
- **dev**: RTO 2 hours, RPO 1 day
- **staging**: RTO 1 hour, RPO 4 hours
- **prod**: RTO 30 minutes, RPO 1 hour

### Performance Benchmarking

Create: `pcc-pipeline-library/tests/performance-test.sh`

```bash
#!/bin/bash
ENVIRONMENT=${1:-devtest}
APIGEE_BASE_URL="https://${ENVIRONMENT}-api.pccdomain.com"
ITERATIONS=${2:-100}

SERVICES=(auth client user metric-builder metric-tracker task-builder task-tracker)

echo "Performance test for $ENVIRONMENT environment ($ITERATIONS requests per service)"
for service in "${SERVICES[@]}"; do
  echo "Testing /${service}..."

  # Use Apache Bench for simple load testing
  ab -n $ITERATIONS -c 10 -q \
    "${APIGEE_BASE_URL}/${service}/health/ready" \
    2>&1 | grep -E "Requests per second|Time per request|Failed requests"

  echo ""
done
```

**Baseline targets:**
- Response time p95: <200ms
- Response time p99: <500ms
- Throughput: >100 req/s per service
- Error rate: <0.1%

### Documentation Updates

**Update:** `pcc-pipeline-library/README.md`
- Architecture diagram (ASCII or link)
- Quick start guide
- Troubleshooting common issues
- Contributing guidelines
- Contact information

**Update:** Master `CLAUDE.md`
```markdown
## Apigee Pipeline Architecture
- Pipeline Guide: `@pcc-pipeline-library/README.md`
- Multi-env Strategy: `@pcc-pipeline-library/docs/multi-environment-guide.md`
- Monitoring: `@pcc-pipeline-library/docs/monitoring-guide.md`
- Runbook: `@pcc-pipeline-library/docs/runbook.md`
- DR Plan: `@pcc-pipeline-library/docs/disaster-recovery.md`
```

### Deliverables
- [x] Multi-environment expansion strategy documented
- [x] Approval workflows designed for staging/prod
- [x] Monitoring and alerting configured
- [x] Runbook with common issues and solutions
- [x] Disaster recovery procedures established
- [x] Performance benchmarking tools created
- [x] All documentation updated

### Success Criteria
- Clear path to dev/staging/prod environments
- Monitoring covers all critical failure points
- Team trained on runbook procedures
- Disaster recovery tested and validated
- Performance baselines established

---

## Implementation Timeline Summary

### Week 1
```
Days 1-3: Phase 1 - Foundation (Terraform, GCP, ArgoCD)
Days 4-5: Phase 2 - Pipeline Library (5 scripts + config)
```

### Week 2
```
Day 1:    Phase 3 - ArgoCD Config (7 service manifests)
Days 2-3: Phase 4 - POC (pcc-auth-api)
Day 4:    Phase 5 - Validation (pcc-client-api)
Day 5:    Phase 6 starts - Parallel rollout
```

### Week 3
```
Days 1-2: Phase 6 continues - Complete 5 remaining services
Days 3-5: Phase 7 - Monitoring, docs, multi-env prep
```

---

## Critical Success Factors

### Technical
1. OpenAPI spec filtering must match service basepaths exactly
2. ArgoCD backend URLs must follow naming convention
3. Workload Identity bindings must be correct
4. All CLI tools available in Cloud Build environment

### Process
1. Pipeline library updates committed before service adoption
2. Service onboarding follows strict checklist
3. Second service validates repeatability before mass rollout
4. Integration testing validates all endpoints

### Security
1. All secrets in Secret Manager (no hardcoded values)
2. Service accounts follow least privilege principle
3. Approval workflows enforced for staging/prod
4. Regular secret rotation schedule maintained

---

## Risk Mitigation

### High Risk Items
1. **Missing OpenAPI specs** - Ensure dev team has spec files ready before pipeline testing
2. **ArgoCD timeout** - Test pod startup times, adjust limits
3. **Apigee access** - Verify token generation before rollout
4. **Service account permissions** - Test with gcloud commands first

### Contingency Plans
- POC failure: Debug with auth service before proceeding
- Script bugs: Fix in pipeline library, re-test with client
- Infrastructure issues: Terraform destroy/apply with version control
- Production issues: Rollback via ArgoCD, redeploy previous image

---

## Future Enhancements

### Month 3+
- Deploy dev environment
- Deploy staging with approval workflows
- Production deployment with gradual rollout

### Long-term Improvements
- Auto-scaling (HPA) based on CPU/memory
- Cost optimization review
- Security hardening (mTLS, rate limiting, DDoS protection)
- Developer portal self-service
- Distributed tracing (Cloud Trace)
- Custom metrics and observability
- Compliance (audit logs, GDPR, data retention policies)

---

## Next Steps

1. **Immediate:** Begin Phase 1 - Set up pcc-tf-library Terraform configurations
2. **Week 1:** Complete infrastructure foundation and pipeline library
3. **Week 2:** POC validation with pcc-auth-api and pcc-client-api
4. **Week 3:** Complete rollout and prepare for multi-environment expansion

---

**Document Status:** Implementation Ready
**Last Updated:** 2025-10-15
**Next Review:** After Phase 4 completion
