# Phase 3.8: Create Environment Configuration

**Phase**: 3.8 (GKE Infrastructure - Environment Files)
**Duration**: 16-18 minutes
**Type**: Implementation
**Status**: Ready for Execution

---

## Execution Tool

**Use Claude Code for this phase** - Creating all terraform files for nonprod environment.

---

## Objective

Create complete terraform configuration in `environments/nonprod/` directory using environment folder pattern (ADR-008) with all required files for GKE deployment.

## Prerequisites

✅ Phase 3.7 completed (repository structure created)
✅ Understanding of environment folder pattern (ADR-008)
✅ GKE module completed (Phase 3.6)

**Verify Prerequisites**:
```bash
# Verify repo structure exists
ls -ld ~/pcc/infra/pcc-devops-infra/environments/nonprod/

# Verify GKE module is tagged and available
cd ~/pcc/core/pcc-tf-library
git tag -l "v0.1.*"
git ls-remote --tags origin | grep v0.1.0

# Should show v0.1.0 tag exists locally and remotely
```

---

## Files to Create (6 files)

1. **backend.tf** - GCS backend with unique state prefix
2. **providers.tf** - Terraform and Google provider configuration
3. **variables.tf** - Variable declarations (no defaults)
4. **terraform.tfvars** - NonProd-specific values
5. **gke.tf** - GKE module call
6. **outputs.tf** - Output declarations

---

## Step 1: Create backend.tf

**File**: `pcc-devops-infra/environments/nonprod/backend.tf`

```hcl
terraform {
  backend "gcs" {
    bucket = "pcc-terraform-state"
    prefix = "devops-infra/nonprod"  # Unique prefix for state isolation
  }
}
```

**Key Point**: Different from prod prefix (`devops-infra/prod`)

---

## Step 2: Create providers.tf

**File**: `pcc-devops-infra/environments/nonprod/providers.tf`

```hcl
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
```

---

## Step 3: Create variables.tf

**File**: `pcc-devops-infra/environments/nonprod/variables.tf`

```hcl
variable "project_id" {
  description = "GCP project ID for DevOps NonProd infrastructure"
  type        = string
}

variable "region" {
  description = "GCP region for resources"
  type        = string
  default     = "us-east4"
}

variable "network_project_id" {
  description = "Project ID for Shared VPC network"
  type        = string
}

variable "vpc_network_name" {
  description = "VPC network name"
  type        = string
}

variable "gke_subnet_name" {
  description = "Subnet name for GKE cluster"
  type        = string
}
```

---

## Step 4: Create terraform.tfvars

**File**: `pcc-devops-infra/environments/nonprod/terraform.tfvars`

```hcl
# DevOps NonProd Configuration
project_id         = "pcc-prj-devops-nonprod"
network_project_id = "pcc-prj-net-shared"
region             = "us-east4"

# Networking
vpc_network_name = "pcc-vpc-nonprod"
gke_subnet_name  = "pcc-subnet-devops-nonprod"
```

**Important Values**:
- `project_id`: NonProd DevOps project
- `network_project_id`: Shared VPC host project

---

## Step 5: Create gke.tf

**File**: `pcc-devops-infra/environments/nonprod/gke.tf`

```hcl
# GKE Autopilot Cluster for DevOps NonProd
# Hosts ArgoCD, monitoring, and system services

module "gke_devops" {
  source = "git::https://github.com/portco-connect/pcc-tf-library.git//modules/gke-autopilot?ref=v0.1.0"

  # Core Configuration
  project_id   = var.project_id
  region       = var.region
  cluster_name = "pcc-gke-devops-nonprod"
  environment  = "nonprod"

  # Networking (Shared VPC)
  network_id = "projects/${var.network_project_id}/global/networks/${var.vpc_network_name}"
  subnet_id  = "projects/${var.network_project_id}/regions/${var.region}/subnetworks/${var.gke_subnet_name}"

  # GKE Features
  enable_workload_identity       = true
  enable_connect_gateway         = true
  # Binary Authorization disabled initially (will be configured in Phase 6)

  # Release Channel
  release_channel = "STABLE"

  # Labels
  cluster_labels = {
    environment = "nonprod"
    purpose     = "devops-system-services"
    cost_center = "engineering"
    managed_by  = "terraform"
  }

  cluster_display_name = "PCC DevOps NonProd Cluster"
}
```

**Module Configuration**:
- **cluster_name**: `pcc-gke-devops-nonprod`
- **environment**: `nonprod` (affects deletion protection)
- **Workload Identity**: Enabled (ADR-005)
- **Connect Gateway**: Enabled (ADR-002)
- **Binary Authorization**: Disabled initially (to be configured in Phase 6)

---

## Step 6: Create outputs.tf

**File**: `pcc-devops-infra/environments/nonprod/outputs.tf`

```hcl
# GKE Cluster Outputs

output "cluster_id" {
  description = "GKE cluster ID"
  value       = module.gke_devops.cluster_id
}

output "cluster_name" {
  description = "GKE cluster name"
  value       = module.gke_devops.cluster_name
}

output "cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = module.gke_devops.cluster_endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "GKE cluster CA certificate"
  value       = module.gke_devops.cluster_ca_certificate
  sensitive   = true
}

output "workload_identity_pool" {
  description = "Workload Identity pool"
  value       = module.gke_devops.workload_identity_pool
}

output "gke_hub_membership_id" {
  description = "GKE Hub membership ID for Connect Gateway"
  value       = module.gke_devops.gke_hub_membership_id
}
```

---

## Validation Checklist

- [ ] 6 files created in `environments/nonprod/`
- [ ] `backend.tf` has unique prefix: `devops-infra/nonprod`
- [ ] `providers.tf` uses `~> 5.0` provider
- [ ] `variables.tf` has 5 variables
- [ ] `terraform.tfvars` has nonprod values
- [ ] `gke.tf` references module via Git source
- [ ] `outputs.tf` has 6 outputs (2 sensitive)
- [ ] All files use 2-space indentation
- [ ] No hardcoded credentials

---

## Environment Folder Pattern (ADR-008)

**Directory Structure**:
```
environments/
├── nonprod/
│   ├── backend.tf           # Unique state: devops-infra/nonprod
│   ├── providers.tf         # Provider config
│   ├── variables.tf         # Variable declarations
│   ├── terraform.tfvars     # NonProd values
│   ├── gke.tf               # Module call
│   └── outputs.tf           # Output declarations
└── prod/
    └── [Future: same files with prod values]
```

**Benefits**:
- ✅ Complete state isolation (separate GCS prefixes)
- ✅ No tfvars flag needed (`cd environments/nonprod && terraform apply`)
- ✅ Impossible to accidentally target wrong environment
- ✅ Simple CI/CD: `cd environments/${ENV} && terraform init -upgrade  # Always use -upgrade with force-pushed tags && terraform apply`

---

## CI/CD Pattern

```bash
# Simple deployment command
export ENVIRONMENT=nonprod
cd environments/${ENVIRONMENT}
terraform init -upgrade  # Always use -upgrade with force-pushed tags
terraform plan -out=tfplan
terraform apply tfplan
```

---

## Next Phase Dependencies

**Phase 3.9** will:
- Use WARP to deploy this configuration
- Run `terraform init -upgrade  # Always use -upgrade with force-pushed tags`, `terraform plan`, `terraform apply`
- Create GKE cluster in `pcc-prj-devops-nonprod`

---

## References

- **ADR-008**: Terraform Environment Folder Pattern
- **Module Source**: pcc-tf-library/modules/gke-autopilot
- **ADR-002**: Apigee GKE Ingress Strategy (Connect Gateway)
- **ADR-005**: Workload Identity Pattern

---

## Time Estimate

- **Create backend.tf**: 2 minutes
- **Create providers.tf**: 2 minutes
- **Create variables.tf**: 3 minutes (5 variables)
- **Create terraform.tfvars**: 3 minutes
- **Create gke.tf**: 5-6 minutes (module call)
- **Create outputs.tf**: 3-4 minutes (6 outputs)
- **Total**: 16-18 minutes

---

**Status**: Ready for execution
**Next**: Phase 3.9 - Deploy NonProd Infrastructure (WARP)
