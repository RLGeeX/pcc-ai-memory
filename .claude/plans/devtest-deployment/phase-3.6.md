# Phase 3.6: WARP Deployment - Clusters & IAM

**Phase**: 3.6 (GKE Clusters - WARP Deployment)
**Duration**: 20-30 minutes (plus 10-15 min cluster provisioning)
**Type**: Deployment
**Status**: 📋 Planning (Not Started)
**Date**: TBD (10/21+)

---

## Objective

Deploy 3 GKE Autopilot clusters, 2 ArgoCD service accounts, and 10 cross-project IAM bindings (4 container.admin + 4 gkehub.gatewayAdmin + 2 Cloud Build) to Google Cloud via WARP terminal using terraform. Note: Workload Identity bindings deferred to Phase 4 when K8s service accounts exist.

## Prerequisites

✅ **Phase 3.1 completed** - Connect Gateway APIs enabled (BLOCKING)
✅ Phase 3.5 completed (terraform validation successful)
✅ Terraform plan file (`tfplan`) generated and reviewed
✅ Access to WARP terminal
✅ GCP credentials configured in WARP

---

## Pre-Deployment Checklist

### Verify Prerequisites

- [ ] Terraform plan reviewed and approved (Phase 3.5)
- [ ] Plan file exists: `~/pcc/infra/pcc-app-shared-infra/terraform/tfplan`
- [ ] 15 resources to add (3 clusters + 2 SAs + 10 IAM bindings: 4 container.admin + 4 gkehub.gatewayAdmin + 2 Cloud Build)
- [ ] 0 resources to change
- [ ] 0 resources to destroy
- [ ] WARP terminal accessible
- [ ] GCP credentials valid (`gcloud auth list`)

### Project Readiness

- [ ] **Phase 3.1 completed** - Connect Gateway APIs enabled (BLOCKING)
- [ ] All 3 projects exist (devops-nonprod, devops-prod, app-devtest)
- [ ] GKE API enabled in all 3 projects (`container.googleapis.com`)
- [ ] VPC and subnets exist (from Phase 1)
- [ ] Cloud Build SA exists (auto-created when API enabled)

---

## Deployment Steps

### Step 1: Switch to WARP Terminal

**IMPORTANT**: All terraform commands MUST run in WARP terminal (not WSL)

**Reason**: WARP has GCP credentials configured, WSL does not

**Verify WARP Access**:
```bash
# In WARP terminal
gcloud auth list
# Should show your GCP account as active

gcloud config get-value project
# Should show your default project
```

**Verify Connect Gateway APIs Enabled**:
```bash
# Quick check for Connect Gateway APIs
gcloud services list --project=pcc-prj-devops-nonprod \
  --filter="name:(gkehub.googleapis.com OR connectgateway.googleapis.com)" \
  --format="value(name)" | wc -l

# Expected output: 2 (both APIs enabled)
```

**If Output is NOT 2**:
- ❌ **STOP DEPLOYMENT** - Phase 3.1 not completed
- See: `phase-3.1.md` for API enablement instructions
- Return to this phase after completing Phase 3.1

---

### Step 2: Navigate to Terraform Directory

```bash
cd ~/pcc/infra/pcc-app-shared-infra/terraform
```

**Verify Location**:
```bash
pwd
# Expected: /home/<user>/pcc/infra/pcc-app-shared-infra/terraform

ls -la
# Expected files: main.tf, iam.tf, variables.tf, outputs.tf, backend.tf, tfplan
```

---

### Step 3: Review Terraform Plan (One Last Time)

**Optional but Recommended**: Review plan before applying

```bash
terraform show tfplan
```

**Quick Summary**:
```bash
terraform show -json tfplan | jq '.resource_changes | length'
# Expected: 15
```

**Verify No Deletions**:
```bash
terraform show -json tfplan | jq '.resource_changes[] | select(.change.actions[] == "delete")'
# Expected: No output (no deletions)
```

---

### Step 4: Apply Terraform Plan

**🚨 CRITICAL: Dual Terraform Apply Requirement**

This phase applies terraform in **`infra/pcc-app-shared-infra`** (GKE clusters and IAM bindings).

**However**, Phase 3.1 MUST have already applied terraform in **`core/pcc-foundation-infra`** (Connect Gateway APIs).

**Two Repositories, Two Applies:**
1. ✅ **Phase 3.1**: `core/pcc-foundation-infra/terraform` - Enable Connect Gateway APIs (MUST BE DONE FIRST)
2. ⏳ **Phase 3.6** (this phase): `infra/pcc-app-shared-infra/terraform` - Deploy GKE clusters + IAM

**If Phase 3.1 Not Completed:**
- ❌ **STOP** - Return to Step 1 and verify APIs enabled
- See: `phase-3.1.md` for foundation terraform apply instructions
- Clusters will fail to register with Connect Gateway if APIs not enabled

---

**Execute Deployment**:
```bash
terraform apply tfplan
```

**Expected Output**:
```
module.gke_devops_nonprod.google_container_cluster.autopilot_cluster: Creating...
module.gke_devops_prod.google_container_cluster.autopilot_cluster: Creating...
module.gke_app_devtest.google_container_cluster.autopilot_cluster: Creating...
google_service_account.argocd_prod: Creating...
google_service_account.argocd_nonprod: Creating...
google_project_iam_member.cloudbuild_to_artifact_registry: Creating...
google_project_iam_member.cloudbuild_to_secret_manager: Creating...
google_project_iam_member.argocd_prod_to_gke_devops_nonprod: Creating...
google_project_iam_member.argocd_prod_to_gke_devops_prod: Creating...
google_project_iam_member.argocd_prod_to_gke_app_devtest: Creating...
google_project_iam_member.argocd_nonprod_to_gke_devops_nonprod: Creating...
google_project_iam_member.argocd_prod_gateway_devops_nonprod: Creating...
google_project_iam_member.argocd_prod_gateway_devops_prod: Creating...
google_project_iam_member.argocd_prod_gateway_app_devtest: Creating...
google_project_iam_member.argocd_nonprod_gateway_devops_nonprod: Creating...

google_service_account.argocd_prod: Creation complete after 3s
google_service_account.argocd_nonprod: Creation complete after 3s
google_project_iam_member.cloudbuild_to_artifact_registry: Creation complete after 5s
google_project_iam_member.cloudbuild_to_secret_manager: Creation complete after 5s
google_project_iam_member.argocd_prod_to_gke_devops_nonprod: Creation complete after 6s
google_project_iam_member.argocd_prod_to_gke_devops_prod: Creation complete after 6s
google_project_iam_member.argocd_prod_to_gke_app_devtest: Creation complete after 6s
google_project_iam_member.argocd_nonprod_to_gke_devops_nonprod: Creation complete after 6s
google_project_iam_member.argocd_prod_gateway_devops_nonprod: Creation complete after 6s
google_project_iam_member.argocd_prod_gateway_devops_prod: Creation complete after 6s
google_project_iam_member.argocd_prod_gateway_app_devtest: Creation complete after 6s
google_project_iam_member.argocd_nonprod_gateway_devops_nonprod: Creation complete after 6s

module.gke_devops_nonprod.google_container_cluster.autopilot_cluster: Still creating... [10m0s elapsed]
module.gke_devops_prod.google_container_cluster.autopilot_cluster: Still creating... [10m0s elapsed]
module.gke_app_devtest.google_container_cluster.autopilot_cluster: Still creating... [10m0s elapsed]

module.gke_devops_nonprod.google_container_cluster.autopilot_cluster: Creation complete after 12m15s
module.gke_devops_prod.google_container_cluster.autopilot_cluster: Creation complete after 12m18s
module.gke_app_devtest.google_container_cluster.autopilot_cluster: Creation complete after 12m22s

Apply complete! Resources: 15 added, 0 changed, 0 destroyed.

Outputs:

devops_nonprod_cluster_name = "pcc-gke-devops-nonprod"
devops_prod_cluster_name = "pcc-gke-devops-prod"
app_devtest_cluster_name = "pcc-gke-app-devtest"
argocd_prod_sa_email = "argocd-controller@pcc-prj-devops-prod.iam.gserviceaccount.com"
argocd_nonprod_sa_email = "argocd-controller@pcc-prj-devops-nonprod.iam.gserviceaccount.com"
```

**Expected Duration**:
- IAM bindings: ~5-10 seconds each
- GKE clusters: ~10-15 minutes each (parallel creation)
- **Total**: ~12-18 minutes

---

### Step 5: Monitor Deployment Progress

**Watch Terraform Progress**:
- IAM bindings will complete quickly (~5-10 seconds)
- GKE clusters will take longer (~10-15 minutes)
- Terraform shows progress every 10 seconds for long-running operations

**Do Not Interrupt**:
- Do not press Ctrl+C during cluster creation
- If interrupted, clusters may be in partially-created state
- May require manual cleanup or `terraform apply` re-run

---

### Step 6: Verify Deployment Success

**Check Terraform Output**:
```bash
# View terraform outputs
terraform output

# Expected outputs:
# devops_nonprod_cluster_name = "pcc-gke-devops-nonprod"
# devops_prod_cluster_name = "pcc-gke-devops-prod"
# app_devtest_cluster_name = "pcc-gke-app-devtest"
```

**Verify Clusters in GCP Console**:
```bash
# List all GKE clusters
gcloud container clusters list --format="table(name,location,status)"

# Expected output:
# NAME                      LOCATION    STATUS
# pcc-gke-devops-nonprod    us-east4    RUNNING
# pcc-gke-devops-prod       us-east4    RUNNING
# pcc-gke-app-devtest       us-east4    RUNNING
```

**Verify IAM Bindings**:
```bash
# Cloud Build → Artifact Registry
gcloud projects get-iam-policy pcc-prj-devops-prod \
  --flatten="bindings[].members" \
  --filter="bindings.members:*cloudbuild*" \
  --format="table(bindings.role)"

# Cloud Build → Secret Manager
gcloud projects get-iam-policy pcc-prj-app-devtest \
  --flatten="bindings[].members" \
  --filter="bindings.members:*cloudbuild*" \
  --format="table(bindings.role)"

# ArgoCD → All 3 GKE clusters (verify BOTH roles present)
gcloud projects get-iam-policy pcc-prj-devops-nonprod \
  --flatten="bindings[].members" \
  --filter="bindings.members:*argocd*" \
  --format="table(bindings.role)"
# Expected: roles/container.admin AND roles/gkehub.gatewayAdmin for argocd-prod
# Expected: roles/container.admin AND roles/gkehub.gatewayAdmin for argocd-nonprod

gcloud projects get-iam-policy pcc-prj-devops-prod \
  --flatten="bindings[].members" \
  --filter="bindings.members:*argocd*" \
  --format="table(bindings.role)"
# Expected: roles/container.admin AND roles/gkehub.gatewayAdmin for argocd-prod

gcloud projects get-iam-policy pcc-prj-app-devtest \
  --flatten="bindings[].members" \
  --filter="bindings.members:*argocd*" \
  --format="table(bindings.role)"
# Expected: roles/container.admin AND roles/gkehub.gatewayAdmin for argocd-prod
```

---

### Step 7: Configure kubectl Access via Connect Gateway

**IMPORTANT**: Configure Connect Gateway for all 3 PRIVATE clusters immediately after deployment

**Why Connect Gateway:**
- Clusters have **fully private endpoints** (no public API access)
- Connect Gateway provides secure proxy access without VPN or bastion hosts
- Works from WARP terminal, Cloud Build, and developer machines

**Step 7a: Verify Fleet Membership (Autopilot Auto-Enrollment)**:

**IMPORTANT**: GKE Autopilot clusters **automatically enroll** in fleet when created with `gateway_api_config` enabled. Manual registration will produce `ALREADY_EXISTS` errors.

```bash
# Verify DevOps Nonprod cluster is registered
gcloud container fleet memberships describe pcc-gke-devops-nonprod \
  --project=pcc-prj-devops-nonprod

# Verify DevOps Prod cluster is registered
gcloud container fleet memberships describe pcc-gke-devops-prod \
  --project=pcc-prj-devops-prod

# Verify App Devtest cluster is registered
gcloud container fleet memberships describe pcc-gke-app-devtest \
  --project=pcc-prj-app-devtest
```

**Expected Output** (for each cluster):
```
createTime: '2025-...'
endpoint:
  gkeCluster:
    resourceLink: //container.googleapis.com/projects/.../clusters/...
name: projects/.../locations/global/memberships/pcc-gke-...
state:
  code: READY
```

**If Membership NOT Found**: Cluster may not have `gateway_api_config` configured. Check Phase 3.3 terraform module definition.

**Step 7b: Configure kubectl Credentials**:
```bash
# DevOps Nonprod cluster (via Connect Gateway)
gcloud container fleet memberships get-credentials pcc-gke-devops-nonprod \
  --project=pcc-prj-devops-nonprod

# DevOps Prod cluster (via Connect Gateway)
gcloud container fleet memberships get-credentials pcc-gke-devops-prod \
  --project=pcc-prj-devops-prod

# App Devtest cluster (via Connect Gateway)
gcloud container fleet memberships get-credentials pcc-gke-app-devtest \
  --project=pcc-prj-app-devtest
```

**Verify kubectl Contexts**:
```bash
# List all configured contexts (should show 3)
kubectl config get-contexts

# Expected output:
# CURRENT   NAME                                               CLUSTER
# *         gke_pcc-prj-app-devtest_us-east4_pcc-gke-...      gke_pcc-prj-app-devtest_us-east4_...
#           gke_pcc-prj-devops-nonprod_us-east4_pcc-gke-...   gke_pcc-prj-devops-nonprod_us-east4_...
#           gke_pcc-prj-devops-prod_us-east4_pcc-gke-...      gke_pcc-prj-devops-prod_us-east4_...
```

**Test kubectl Access**:
```bash
# Test each cluster (Autopilot may show 0 nodes until workloads deployed)
kubectl config use-context gke_pcc-prj-devops-nonprod_us-east4_pcc-gke-devops-nonprod
kubectl get namespaces

kubectl config use-context gke_pcc-prj-devops-prod_us-east4_pcc-gke-devops-prod
kubectl get namespaces

kubectl config use-context gke_pcc-prj-app-devtest_us-east4_pcc-gke-app-devtest
kubectl get namespaces

# All clusters should show default K8s namespaces:
# - default
# - kube-node-lease
# - kube-public
# - kube-system
```

**Troubleshooting kubectl Access**:
- **Error: Unable to connect**: Verify cluster is RUNNING in GCP Console
- **Error: Permission denied**: Verify your GCP account has `container.admin` role
- **Error: Cluster not found**: Double-check cluster name and region in command

---

## Post-Deployment Verification

### Cluster Health Checks

**NOTE**: kubectl credentials already configured in Step 7 via Connect Gateway

**Verify kubectl Access**:
```bash
# List all contexts
kubectl config get-contexts

# Expected: 3 contexts (one per cluster)
# CURRENT   NAME                                      CLUSTER
# *         gke_pcc-prj-devops-nonprod_us-east4_...   gke_pcc-prj-devops-nonprod_us-east4_...
#           gke_pcc-prj-devops-prod_us-east4_...      gke_pcc-prj-devops-prod_us-east4_...
#           gke_pcc-prj-app-devtest_us-east4_...      gke_pcc-prj-app-devtest_us-east4_...
```

**Check Cluster Nodes** (Autopilot has no visible nodes until workloads deployed):
```bash
# Switch to each cluster and check nodes
kubectl config use-context gke_pcc-prj-devops-nonprod_us-east4_pcc-gke-devops-nonprod
kubectl get nodes
# Expected: May show 0 nodes (Autopilot creates nodes on-demand)

kubectl config use-context gke_pcc-prj-devops-prod_us-east4_pcc-gke-devops-prod
kubectl get nodes
# Expected: May show 0 nodes (Autopilot creates nodes on-demand)

kubectl config use-context gke_pcc-prj-app-devtest_us-east4_pcc-gke-app-devtest
kubectl get nodes
# Expected: May show 0 nodes (Autopilot creates nodes on-demand)
```

**Check Namespaces**:
```bash
# Each cluster should have default namespaces
kubectl config use-context gke_pcc-prj-app-devtest_us-east4_pcc-gke-app-devtest
kubectl get namespaces

# Expected default namespaces:
# NAME              STATUS   AGE
# default           Active   5m
# kube-node-lease   Active   5m
# kube-public       Active   5m
# kube-system       Active   5m
```

**Check Cluster Health (kube-system pods)**:
```bash
# Verify core Kubernetes components are running
kubectl config use-context gke_pcc-prj-app-devtest_us-east4_pcc-gke-app-devtest
kubectl get pods -n kube-system

# Expected: All pods should be Running or Completed
# Key components to verify:
# - kube-dns or coredns
# - metrics-server
# - gke-metrics-agent
# - konnectivity-agent (for private clusters)

# Repeat for other clusters
kubectl config use-context gke_pcc-prj-devops-nonprod_us-east4_pcc-gke-devops-nonprod
kubectl get pods -n kube-system

kubectl config use-context gke_pcc-prj-devops-prod_us-east4_pcc-gke-devops-prod
kubectl get pods -n kube-system
```

---

## Testing Limitations (Phase 3)

### What CAN Be Tested Now

- [ ] Clusters exist and are RUNNING
- [ ] kubectl contexts configured
- [ ] kubectl can access clusters
- [ ] Cross-project IAM bindings applied

### What CANNOT Be Tested Yet

- [ ] **Namespaces/RBAC**: ArgoCD not deployed yet (Phase 4)
- [ ] **Workloads**: No applications deployed yet
- [ ] **ArgoCD GitOps**: ArgoCD not installed yet (Phase 4)
- [ ] **Service-specific Workload Identity**: Service accounts not created yet (Phase 6)

**Reason**: ArgoCD is deployed in Phase 4, and it will manage namespace creation via GitOps. Manual kubectl namespace creation would conflict with ArgoCD's declarative model.

---

## Rollback Plan (If Needed)

### If Deployment Fails

**Partial Failure** (some resources created, some failed):
```bash
# Re-run terraform apply (idempotent)
terraform apply tfplan
```

**Complete Failure** (need to start over):
```bash
# Destroy all resources (clusters + IAM)
terraform destroy

# Review errors, fix configuration
# Re-run validation (Phase 3.5)
# Re-run deployment (Phase 3.6)
```

**Critical Error** (manual cleanup required):
```bash
# List all GKE clusters
gcloud container clusters list --format="table(name,location,status)"

# Delete specific cluster if needed
gcloud container clusters delete pcc-gke-devops-nonprod --region=us-east4 --project=pcc-prj-devops-nonprod
gcloud container clusters delete pcc-gke-devops-prod --region=us-east4 --project=pcc-prj-devops-prod
gcloud container clusters delete pcc-gke-app-devtest --region=us-east4 --project=pcc-prj-app-devtest

# Remove ArgoCD service accounts
gcloud iam service-accounts delete argocd-controller@pcc-prj-devops-prod.iam.gserviceaccount.com --project=pcc-prj-devops-prod
gcloud iam service-accounts delete argocd-controller@pcc-prj-devops-nonprod.iam.gserviceaccount.com --project=pcc-prj-devops-nonprod

# Remove Cloud Build IAM bindings
gcloud projects remove-iam-policy-binding pcc-prj-devops-prod \
  --member="serviceAccount:<PROJECT_NUMBER>@cloudbuild.gserviceaccount.com" \
  --role="roles/artifactregistry.writer"

gcloud projects remove-iam-policy-binding pcc-prj-app-devtest \
  --member="serviceAccount:<PROJECT_NUMBER>@cloudbuild.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"

# Remove ArgoCD IAM bindings (repeat for each project)
gcloud projects remove-iam-policy-binding pcc-prj-devops-nonprod \
  --member="serviceAccount:argocd-controller@pcc-prj-devops-prod.iam.gserviceaccount.com" \
  --role="roles/container.admin"

gcloud projects remove-iam-policy-binding pcc-prj-devops-prod \
  --member="serviceAccount:argocd-controller@pcc-prj-devops-prod.iam.gserviceaccount.com" \
  --role="roles/container.admin"

gcloud projects remove-iam-policy-binding pcc-prj-app-devtest \
  --member="serviceAccount:argocd-controller@pcc-prj-devops-prod.iam.gserviceaccount.com" \
  --role="roles/container.admin"

gcloud projects remove-iam-policy-binding pcc-prj-devops-nonprod \
  --member="serviceAccount:argocd-controller@pcc-prj-devops-nonprod.iam.gserviceaccount.com" \
  --role="roles/container.admin"
```

---

## Deliverables

- [ ] 3 GKE clusters operational (RUNNING status)
- [ ] 2 ArgoCD service accounts created
- [ ] 10 cross-project IAM bindings applied (4 container.admin + 4 gkehub.gatewayAdmin + 2 Cloud Build)
- [ ] kubectl contexts configured for all 3 clusters
- [ ] Note: Workload Identity bindings deferred to Phase 4
- [ ] Cluster credentials obtained
- [ ] Terraform state updated

---

## Validation Criteria

- [ ] Terraform apply completed successfully
- [ ] 15 resources created (3 clusters + 2 SAs + 10 IAM bindings: 4 container.admin + 4 gkehub.gatewayAdmin + 2 Cloud Build)
- [ ] All clusters show RUNNING status in GCP Console
- [ ] kubectl can access all 3 clusters
- [ ] IAM bindings verified via gcloud commands
- [ ] No errors in terraform output

---

## Dependencies

**Upstream**:
- Phase 3.5: Terraform validation and plan generation

**Downstream**:
- Phase 4: ArgoCD deployment (uses devops-prod cluster)
- Phase 5: Cloud Build pipelines (use Artifact Registry and Secret Manager IAM)
- Phase 6: Service infrastructure (uses app-devtest cluster)

---

## Notes

- **Cluster provisioning time**: ~10-15 minutes per cluster (parallel creation)
- **Autopilot nodes**: Created on-demand when workloads deployed (may show 0 nodes initially)
- **IAM bindings**: Applied immediately (~5-10 seconds each)
- **Workload Identity**: ArgoCD binding created but not used until Phase 4 (ArgoCD deployment)
- **kubectl contexts**: 3 contexts created, easily switch between clusters
- **Cost implications**: Autopilot clusters incur minimal cost without workloads (~$0.10/hour per cluster)
- **No rollback needed**: If successful, clusters are ready for Phase 4 (ArgoCD deployment)

---

## Time Estimate

**Total**: 20-30 minutes (plus cluster provisioning)
- 5 min: Pre-deployment verification
- 2 min: Apply terraform plan
- 12-18 min: Wait for cluster provisioning (parallel)
- 5 min: Post-deployment verification
- 5 min: Configure kubectl contexts and test access

---

**Next Phase**: 4 - ArgoCD Deployment (to devops-prod cluster)

**Note**: Phase 3 complete after this step. Namespace and RBAC configuration moved to Phase 4 (after ArgoCD is operational).
