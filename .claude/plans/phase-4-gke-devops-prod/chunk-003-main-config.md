# Chunk 3: Create Main Configuration with GKE Module

**Status:** pending
**Dependencies:** chunk-002-providers-config
**Complexity:** simple
**Estimated Time:** 15 minutes
**Tasks:** 2
**Phase:** Configuration
**Story:** STORY-4.1
**Jira:** PCC-274

---

## Task 1: Create Main Configuration with Module Call

**Agent:** terraform-specialist
**Files:**
- Create: `infra/pcc-devops-infra/environments/prod/gke.tf`

**Step 1: Write GKE module configuration**

File: `infra/pcc-devops-infra/environments/prod/gke.tf`

```hcl
# GKE Autopilot cluster for DevOps prod environment
module "gke_devops_prod" {
  source = "git@github-pcc:PORTCoCONNECT/pcc-tf-library.git//modules/gke-autopilot?ref=v0.1.0"

  project_id  = var.project_id
  region      = var.region
  environment = "prod"

  cluster_name = "pcc-gke-devops-prod"

  # Shared VPC configuration
  network_id = "projects/${var.network_project_id}/global/networks/${var.vpc_network_name}"
  subnet_id  = "projects/${var.network_project_id}/regions/${var.region}/subnetworks/${var.gke_subnet_name}"

  # Secondary ranges for pods and services
  pods_secondary_range_name     = "${var.gke_subnet_name}-sub-pod"
  services_secondary_range_name = "${var.gke_subnet_name}-sub-svc"

  # Features
  enable_workload_identity = true
  enable_connect_gateway   = true

  # Production settings
  release_channel = "STABLE"

  # Labels
  cluster_labels = {
    environment = "prod"
    managed_by  = "terraform"
    purpose     = "devops-cluster"
    phase       = "4"
  }
}
```

**Step 2: Format and validate syntax**

```bash
cd ~/pcc/infra/pcc-devops-infra/environments/prod
terraform fmt gke.tf
```

Expected: File formatted correctly

---

## Task 2: Create Outputs Configuration

**Agent:** terraform-specialist
**Files:**
- Create: `infra/pcc-devops-infra/environments/prod/outputs.tf`

**Step 1: Write outputs configuration**

File: `infra/pcc-devops-infra/environments/prod/outputs.tf`

```hcl
output "cluster_id" {
  description = "Full cluster ID"
  value       = module.gke_devops_prod.cluster_id
}

output "cluster_name" {
  description = "The cluster name"
  value       = module.gke_devops_prod.cluster_name
}

output "cluster_endpoint" {
  description = "Cluster control plane endpoint"
  value       = module.gke_devops_prod.cluster_endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Cluster CA certificate"
  value       = module.gke_devops_prod.cluster_ca_certificate
  sensitive   = true
}

output "workload_identity_pool" {
  description = "Workload Identity pool"
  value       = module.gke_devops_prod.workload_identity_pool
}

output "gke_hub_membership_id" {
  description = "GKE Hub membership ID for Connect Gateway"
  value       = module.gke_devops_prod.gke_hub_membership_id
}
```

**Step 2: Format and commit**

```bash
terraform fmt outputs.tf
git add gke.tf outputs.tf
git commit -m "feat(infra): add GKE module call and outputs for prod cluster"
```

---

## Chunk Complete Checklist

- [ ] GKE module call created with prod configuration
- [ ] Deletion protection enabled via environment = "prod"
- [ ] Connect Gateway and Workload Identity enabled
- [ ] STABLE release channel configured
- [ ] Outputs file created with all cluster outputs
- [ ] Files formatted and committed
- [ ] Ready for chunk 4 (terraform.tfvars)
