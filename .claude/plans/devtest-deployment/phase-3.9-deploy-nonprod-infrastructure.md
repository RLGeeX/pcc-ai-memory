# Phase 3.9: Deploy NonProd Infrastructure

**Phase**: 3.9 (GKE Infrastructure - Cluster Deployment)
**Duration**: 15-20 minutes
**Type**: Deployment
**Status**: Ready for Execution

---

## Execution Tool

**Use WARP for this phase** - Terraform deployment commands.

---

## Objective

Deploy GKE Autopilot cluster to `pcc-prj-devops-nonprod` using terraform apply.

## Prerequisites

✅ Phase 3.8 completed (environment configuration files created)
✅ Phase 3.2 completed (APIs enabled and propagated)
✅ GCP credentials configured
✅ Terraform installed (>= 1.5.0)

---

## Step 1: Navigate to NonProd Environment

```bash
cd ~/pcc/infra/pcc-devops-infra/environments/nonprod
```

---

## Step 1.5: Verify API Propagation from Phase 3.2

**CRITICAL**: Verify APIs enabled in Phase 3.2 have fully propagated before running `terraform init -upgrade  # Always use -upgrade with force-pushed tags`.

```bash
# Verify container.googleapis.com is fully propagated
gcloud container clusters list --project=pcc-prj-devops-nonprod 2>&1

# Verify gkehub.googleapis.com is fully propagated
gcloud container fleet memberships list --project=pcc-prj-devops-nonprod 2>&1
```

**Expected Output** (for both commands):
```
Listed 0 items.
```

**If you see API errors**:
```
ERROR: (gcloud.container.clusters.list) PERMISSION_DENIED: container.googleapis.com is not enabled
```

**Resolution**:
- Wait 2-3 minutes for API propagation
- Retry verification commands
- Do NOT proceed to `terraform init -upgrade  # Always use -upgrade with force-pushed tags` until both APIs return "Listed 0 items"

**Why This Step?**
- APIs enabled in Phase 3.2 may take 2-5 minutes to fully propagate
- Terraform init will fail if APIs are not propagated
- This verification prevents wasted time debugging API errors

---

## Step 2: Initialize Terraform

```bash
terraform init -upgrade  # Always use -upgrade with force-pushed tags
```

**Expected Output**:
```
Initializing the backend...

Successfully configured the backend "gcs"! Terraform will automatically
use this backend unless the backend configuration changes.

Initializing provider plugins...
- Finding hashicorp/google versions matching "~> 5.0"...
- Installing hashicorp/google v5.x.x...
- Installed hashicorp/google v5.x.x (signed by HashiCorp)

Terraform has been successfully initialized!
```

---

## Step 3: Review Terraform Plan

```bash
terraform plan
```

**Expected Resources (2 to create)**:
1. `module.gke_devops.google_container_cluster.cluster` - GKE Autopilot cluster
2. `module.gke_devops.google_gke_hub_membership.cluster[0]` - Connect Gateway membership

**Note**: PSC service attachment is NOT created in Phase 3 (deferred to Phase 6 when GKE Ingress exists)

**Plan Validation**:
```
Plan: 2 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + cluster_endpoint         = (sensitive value)
  + cluster_id              = (known after apply)
  + cluster_name            = "pcc-gke-devops-nonprod"
  + gke_hub_membership_id   = (known after apply)
  + workload_identity_pool  = "pcc-prj-devops-nonprod.svc.id.goog"
```

**Verify**:
- ✅ Exactly 2 resources to add (cluster + Hub membership)
- ✅ Cluster name: `pcc-gke-devops-nonprod`
- ✅ Workload Identity pool: `pcc-prj-devops-nonprod.svc.id.goog`
- ✅ Connect Gateway Hub membership included
- ✅ PSC service attachment NOT included (deferred to Phase 6)

---

## Step 4: Apply Terraform

```bash
terraform apply
```

**Expected Duration**: 10-15 minutes (GKE cluster creation)

**Expected Output**:
```
module.gke_devops.google_container_cluster.cluster: Creating...
module.gke_devops.google_container_cluster.cluster: Still creating... [1m0s elapsed]
module.gke_devops.google_container_cluster.cluster: Still creating... [2m0s elapsed]
...
module.gke_devops.google_container_cluster.cluster: Still creating... [10m0s elapsed]
module.gke_devops.google_container_cluster.cluster: Creation complete after 10m15s [id=projects/pcc-prj-devops-nonprod/locations/us-east4/clusters/pcc-gke-devops-nonprod]

module.gke_devops.google_gke_hub_membership.cluster[0]: Creating...
module.gke_devops.google_gke_hub_membership.cluster[0]: Still creating... [10s elapsed]
module.gke_devops.google_gke_hub_membership.cluster[0]: Creation complete after 45s [id=projects/pcc-prj-devops-nonprod/locations/us-east4/memberships/pcc-gke-devops-nonprod-membership]

Apply complete! Resources: 2 added, 0 changed, 0 destroyed.

Outputs:

cluster_endpoint = <sensitive>
cluster_id = "projects/pcc-prj-devops-nonprod/locations/us-east4/clusters/pcc-gke-devops-nonprod"
cluster_name = "pcc-gke-devops-nonprod"
gke_hub_membership_id = "projects/pcc-prj-devops-nonprod/locations/us-east4/memberships/pcc-gke-devops-nonprod-membership"
workload_identity_pool = "pcc-prj-devops-nonprod.svc.id.goog"
```

---

## Step 5: Verify Terraform State

```bash
terraform output
```

**Expected Output**:
```
cluster_ca_certificate = <sensitive>
cluster_endpoint = <sensitive>
cluster_id = "projects/pcc-prj-devops-nonprod/locations/us-east4/clusters/pcc-gke-devops-nonprod"
cluster_name = "pcc-gke-devops-nonprod"
gke_hub_membership_id = "projects/pcc-prj-devops-nonprod/locations/us-east4/memberships/pcc-gke-devops-nonprod-membership"
workload_identity_pool = "pcc-prj-devops-nonprod.svc.id.goog"
```

**Note**: No PSC outputs since PSC service attachment is not created in Phase 3.

---

## Troubleshooting

### Issue: API Not Enabled

**Symptom**:
```
Error: Error creating Cluster: googleapi: Error 403: container.googleapis.com is not enabled
```

**Resolution**:
- Verify Phase 3.2 completed successfully
- Check: `gcloud services list --enabled --project=pcc-prj-devops-nonprod | grep container`
- If needed: Wait 5 minutes for API propagation

### Issue: Quota Exceeded

**Symptom**:
```
Error: Error creating Cluster: googleapi: Error 429: Quota exceeded for quota metric 'gke_clusters'
```

**Resolution**:
- Request quota increase: https://console.cloud.google.com/iam-admin/quotas
- Check existing clusters: `gcloud container clusters list --project=pcc-prj-devops-nonprod`

### Issue: Network Not Found

**Symptom**:
```
Error: Error creating Cluster: googleapi: Error 404: The resource 'projects/pcc-prj-net-shared/global/networks/pcc-vpc-nonprod' was not found
```

**Resolution**:
- Verify Phase 1 completed (networking deployed)
- Check network exists: `gcloud compute networks describe pcc-vpc-nonprod --project=pcc-prj-net-shared`

---

## Validation Checklist

- [ ] `terraform init -upgrade  # Always use -upgrade with force-pushed tags` completed successfully
- [ ] `terraform plan` shows 2 resources to add
- [ ] `terraform apply` completed without errors
- [ ] 2 resources created (cluster, hub membership)
- [ ] PSC service attachment NOT created (expected - deferred to Phase 6)
- [ ] `terraform output` shows all expected outputs (no PSC outputs)
- [ ] State file saved to GCS: `pcc-terraform-state/devops-infra/nonprod/default.tfstate`

---

## GKE Cluster Details

**Created Resources**:
- **Cluster Name**: `pcc-gke-devops-nonprod`
- **Project**: `pcc-prj-devops-nonprod`
- **Region**: `us-east4`
- **Mode**: Autopilot
- **Network**: `pcc-vpc-nonprod` (Shared VPC)
- **Subnet**: `pcc-subnet-devops-nonprod`
- **Workload Identity**: Enabled (`pcc-prj-devops-nonprod.svc.id.goog`)
- **Connect Gateway**: Enabled (Hub membership created)
- **PSC**: NOT created in Phase 3 (deferred to Phase 6 after GKE Ingress deployment)

---

## Next Phase Dependencies

**Phase 3.10** will:
- Validate cluster creation in GCP Console
- Verify cluster status is RUNNING
- Check node pools auto-created by Autopilot

---

## References

- **GKE Autopilot**: https://cloud.google.com/kubernetes-engine/docs/concepts/autopilot-overview
- **Terraform State**: Stored at `gs://pcc-terraform-state/devops-infra/nonprod/default.tfstate`

---

## Time Estimate

- **Init and plan**: 3-5 minutes
- **Apply (cluster creation)**: 10-15 minutes
- **Verify outputs**: 2 minutes
- **Total**: 15-20 minutes

---

**Status**: Ready for execution
**Next**: Phase 3.10 - Validate GKE Cluster Creation (WARP)
