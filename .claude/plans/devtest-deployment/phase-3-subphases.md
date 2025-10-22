# Phase 3 Subphase Breakdown: GKE Clusters

**Total Subphases**: 7
**Estimated Duration**: 2-3 sessions
**Dependencies**: Phase 1 (networking), Phase 2 (AlloyDB)
**Scope**: Single service deployment (pcc-client-api only)

---

## Terraform Planning

### Phase 3.1: Review Existing GKE Infrastructure

**Objective**: Audit current foundation state and identify prerequisites

**Repositories to Review**:
- `core/pcc-foundation-infra` (existing VPC subnets)
- `infra/pcc-app-shared-infra` (target for Phase 3 terraform)

**Activities**:
- Review `pcc-foundation-infra` terraform state
- Identify existing subnets:
  - DevOps nonprod: 10.24.128.0/20 (existing)
  - DevOps prod: 10.16.128.0/20 (existing)
  - App devtest: 10.28.0.0/20 + secondary ranges (created in Phase 1)
- Document prerequisites
- Review GKE Autopilot requirements

**Deliverables**:
- Infrastructure audit summary
- Subnet verification complete
- Prerequisites checklist

**Duration**: 15-20 minutes

---

### Phase 3.2: GKE Cluster Terraform

**Objective**: Document terraform module for 3 Autopilot GKE clusters

**Repository**: `core/pcc-tf-library`
**Module Location**: `modules/gke-autopilot-cluster/`

**Clusters**:
1. **pcc-prj-devops-nonprod** (system services)
   - Subnet: 10.24.128.0/20
   - Purpose: Nonprod monitoring, utilities

2. **pcc-prj-devops-prod** (ArgoCD primary)
   - Subnet: 10.16.128.0/20
   - Purpose: ArgoCD, production system services

3. **pcc-prj-app-devtest** (application workloads)
   - Subnet: 10.28.0.0/20 (primary)
   - Secondary ranges: pods (10.28.16.0/20), services (10.28.32.0/20)
   - Purpose: 7 microservices

**Configuration**:
- Autopilot mode (Google-managed nodes)
- Private clusters (no external node IPs)
- Workload Identity enabled
- Region: us-east4

**Deliverables**:
- Terraform module for GKE Autopilot clusters
- Cluster configurations for all 3 clusters
- Network integration documented

**Duration**: 30-40 minutes

---

### Phase 3.3: Cross-Project IAM Bindings

**Objective**: Document terraform for 3 cross-project IAM binding patterns

**Repository**: `infra/pcc-app-shared-infra`
**Location**: `terraform/iam.tf` (cross-project bindings)

**IAM Bindings**:

1. **Cloud Build SA → pcc-prj-devops-prod**:
   - Role: `roles/artifactregistry.writer`
   - Purpose: Push Docker images to Artifact Registry

2. **Cloud Build SA → pcc-app-shared-infra**:
   - Role: `roles/secretmanager.secretAccessor`
   - Purpose: Read database credentials during build (for Flyway migrations)

3. **ArgoCD SA → pcc-prj-app-devtest**:
   - Role: `roles/container.admin`
   - Purpose: Manage Kubernetes deployments via GitOps

**Note**: Cloud Build does NOT need GKE access - ArgoCD handles all deployments via GitOps. Service account → Secret Manager IAM binding will be configured in Phase 6 (service-specific infrastructure).

**Deliverables**:
- Terraform for 3 IAM binding patterns
- Cross-project permissions documented
- Service account references

**Duration**: 20-25 minutes

---

## Terraform Deployment

### Phase 3.4: Terraform Validation

**Objective**: Validate all terraform configurations before deployment

**Repository**: `infra/pcc-app-shared-infra`
**Working Directory**: `terraform/`

**Activities**:
- Run `terraform fmt -recursive` on all terraform files
- Run `terraform validate` to check syntax
- Run `terraform plan` and review output
- Verify resource counts:
  - 3 GKE clusters
  - 2 ArgoCD service accounts
  - 10 cross-project IAM bindings (4 container.admin + 4 gkehub.gatewayAdmin + 2 Cloud Build)

**Validation Checklist**:
- [ ] No terraform format issues
- [ ] No validation errors
- [ ] Plan shows expected resource counts
- [ ] No unexpected deletions or changes

**Deliverables**:
- Terraform validation complete
- Plan output reviewed
- Ready for deployment

**Duration**: 15-20 minutes

---

### Phase 3.5: WARP Deployment - Clusters & IAM

**Objective**: Deploy GKE clusters, ArgoCD service accounts, and cross-project IAM bindings via WARP

**Repository**: `infra/pcc-app-shared-infra`
**Working Directory**: `terraform/`

**Deployment Steps**:
1. Switch to WARP terminal
2. Run `terraform apply` for all resources
3. Wait for cluster provisioning (~10-15 minutes for 3 clusters)
4. Verify clusters appear in GCP Console
5. Configure kubectl access via Connect Gateway

**Commands**:
```bash
cd ~/pcc/infra/pcc-app-shared-infra/terraform
terraform apply
# Review and approve
# Wait for cluster provisioning
```

**Testing Limitations**:
- Cannot test namespaces/RBAC yet (ArgoCD not deployed until Phase 4)
- Cannot test Workload Identity yet (Kubernetes service accounts not created until Phase 4)
- Can verify: Clusters exist, ArgoCD service accounts created, cross-project IAM bindings applied

**Deliverables**:
- 3 GKE clusters operational
- 2 ArgoCD service accounts created
- 10 cross-project IAM bindings applied (4 container.admin + 4 gkehub.gatewayAdmin + 2 Cloud Build)
- kubectl contexts configured for all 3 clusters

**Duration**: 20-30 minutes (plus 10-15 min cluster provisioning)

**Note**: Namespace and RBAC configuration deferred to Phase 6 (service-specific infrastructure). Namespace `pcc-devtest` will be created when deploying pcc-client-api service.

---

## Summary

**Total Resources Created in Phase 3**:
- 3 GKE Autopilot clusters (devops-nonprod, devops-prod, app-devtest)
- 2 ArgoCD service accounts (argocd-controller in devops-nonprod and devops-prod projects)
- 10 cross-project IAM bindings:
  - 4 container.admin (ArgoCD SAs → all 3 GKE clusters)
  - 4 gkehub.gatewayAdmin (ArgoCD SAs → Connect Gateway for all clusters)
  - 2 Cloud Build bindings (→ Artifact Registry, → Secret Manager)

**Total Subphases**: 5
1. Phase 3.1: Review Existing GKE Infrastructure (15-20 min)
2. Phase 3.2: GKE Cluster Terraform Module (30-40 min)
3. Phase 3.3: Cross-Project IAM Bindings (20-25 min)
4. Phase 3.4: Terraform Validation (15-20 min)
5. Phase 3.5: WARP Deployment (20-30 min + 10-15 min provisioning)

**Deferred to Later Phases**:
- **Namespace creation**: Phase 6 (service-specific infrastructure)
  - Namespace `pcc-devtest` created when deploying pcc-client-api
- **RBAC configuration**: Phase 6 (service-specific infrastructure)
  - Google group bindings (gcp-developers@pcconnect.ai, gcp-devops@pcconnect.ai)
- **Workload Identity bindings**: Phase 6 (requires Kubernetes service accounts)
- **Service accounts (GCP)**: Phase 6 (one per microservice)

**Key Architectural Decisions**:
- ArgoCD service accounts created in Phase 3 for use in Phase 4 (ArgoCD deployment)
- Clusters fully private (no public endpoints) - access via Connect Gateway
- Cloud Build does NOT get GKE access (ArgoCD handles all deployments via GitOps)
- Developer RBAC access configured as `edit` role (enables debugging with kubectl exec/port-forward)
- Single service scope for end-to-end deployment (pcc-client-api only)

**Dependencies for Phase 4**:
- All 3 clusters operational and healthy
- kubectl contexts configured via Connect Gateway
- Cross-project IAM bindings applied (ArgoCD SAs have container.admin + gkehub.gatewayAdmin)
- ArgoCD service accounts ready for Workload Identity binding in Phase 4
