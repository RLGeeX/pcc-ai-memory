# Phase 3.3: GKE Cluster Terraform

**Phase**: 3.3 (GKE Clusters - Terraform Module)
**Duration**: 30-40 minutes
**Type**: Planning/Documentation
**Status**: 📋 Planning (Not Started)
**Date**: TBD (10/21+)

---

## Objective

Document terraform module for creating 3 GKE Autopilot clusters across devops-nonprod, devops-prod, and app-devtest projects.

## Prerequisites

✅ **Phase 3.1 completed** - Connect Gateway APIs enabled (BLOCKING)
✅ Phase 3.2 completed (infrastructure audit, network details collected)
✅ Terraform module structure reviewed
✅ Network self_links and project numbers available

---

## Repository Structure

### core/pcc-tf-library

**Module Location**: `modules/gke-autopilot-cluster/`

**Expected Files**:
```
core/pcc-tf-library/modules/gke-autopilot-cluster/
├── main.tf          (cluster resource definitions)
├── variables.tf     (input variables)
├── outputs.tf       (cluster endpoints, credentials)
├── versions.tf      (terraform/provider versions)
└── README.md        (module documentation)
```

---

## Terraform Module Design

### main.tf (Cluster Resource)

**Primary Resource**: `google_container_cluster`

```hcl
# core/pcc-tf-library/modules/gke-autopilot-cluster/main.tf

resource "google_container_cluster" "autopilot_cluster" {
  name     = var.cluster_name
  location = var.region
  project  = var.project_id

  # Autopilot mode (Google-managed nodes)
  enable_autopilot = true

  # Network configuration
  network    = var.network
  subnetwork = var.subnetwork

  # Private cluster configuration
  # NOTE: GKE 1.29+ Autopilot uses Private Service Connect (PSC) for control plane.
  # PSC eliminates the legacy control plane CIDR configuration requirement.
  private_cluster_config {
    enable_private_nodes    = true   # Nodes have no public IPs
    enable_private_endpoint = true   # Control plane API is private (access via Connect Gateway)
  }

  # Connect Gateway (enables private cluster access from anywhere)
  # Allows kubectl access without VPN, bastion hosts, or authorized networks
  gateway_api_config {
    channel = "CHANNEL_STANDARD"  # Enables GKE Connect Gateway
  }

  # IP allocation policy (for pods and services)
  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  # Workload Identity configuration
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Release channel
  release_channel {
    channel = var.release_channel  # REGULAR, RAPID, or STABLE
  }

  # Maintenance window
  maintenance_policy {
    daily_maintenance_window {
      start_time = var.maintenance_start_time  # e.g., "03:00"
    }
  }

  # Disable basic auth and client certificate
  master_auth {
    client_certificate_config {
      issue_client_certificate = false
    }
  }

  # Addons configuration
  addons_config {
    http_load_balancing {
      disabled = false  # Enable GCP Load Balancer integration
    }
    horizontal_pod_autoscaling {
      disabled = false  # Enable HPA
    }
  }

  # Resource labels
  resource_labels = var.labels
}
```

---

### variables.tf (Input Variables)

```hcl
# core/pcc-tf-library/modules/gke-autopilot-cluster/variables.tf

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
}

variable "project_id" {
  description = "GCP project ID where cluster will be created"
  type        = string
}

variable "region" {
  description = "GCP region for the cluster"
  type        = string
  default     = "us-east4"
}

variable "network" {
  description = "VPC network self_link"
  type        = string
}

variable "subnetwork" {
  description = "Subnet self_link for cluster nodes"
  type        = string
}

# NOTE: GKE 1.29+ Autopilot uses Private Service Connect (PSC) for control plane connectivity.
# PSC eliminates the need for legacy control plane CIDR allocation.

# NOTE: authorized_cidr removed - Connect Gateway provides secure access without IP allowlists
# kubectl access via: gcloud container fleet memberships get-credentials

variable "pods_range_name" {
  description = "Name of secondary range for pods"
  type        = string
  default     = null
}

variable "services_range_name" {
  description = "Name of secondary range for services"
  type        = string
  default     = null
}

variable "release_channel" {
  description = "GKE release channel (REGULAR, RAPID, STABLE)"
  type        = string
  default     = "REGULAR"
}

variable "maintenance_start_time" {
  description = "Daily maintenance window start time (HH:MM format)"
  type        = string
  default     = "03:00"
}

variable "labels" {
  description = "Resource labels for the cluster"
  type        = map(string)
  default     = {}
}
```

---

### outputs.tf (Cluster Outputs)

```hcl
# core/pcc-tf-library/modules/gke-autopilot-cluster/outputs.tf

output "cluster_name" {
  description = "Name of the GKE cluster"
  value       = google_container_cluster.autopilot_cluster.name
}

output "cluster_endpoint" {
  description = "Cluster API endpoint"
  value       = google_container_cluster.autopilot_cluster.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Cluster CA certificate (base64 encoded)"
  value       = google_container_cluster.autopilot_cluster.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "cluster_id" {
  description = "Cluster unique identifier"
  value       = google_container_cluster.autopilot_cluster.id
}

output "cluster_location" {
  description = "Cluster location (region)"
  value       = google_container_cluster.autopilot_cluster.location
}
```

---

## Module Calls (infra/pcc-app-shared-infra)

### File: infra/pcc-app-shared-infra/terraform/main.tf

**Notes**:
- Network and subnetwork values shown below are examples - use actual self_links from Phase 3.2

```hcl
# Cluster 1: DevOps Nonprod (system services)
module "gke_devops_nonprod" {
  source = "../../core/pcc-tf-library/modules/gke-autopilot-cluster"

  cluster_name = "pcc-gke-devops-nonprod"
  project_id   = "pcc-prj-devops-nonprod"
  region       = "us-east4"

  network    = "projects/pcc-prj-shared-infra/global/networks/pcc-vpc-shared"
  subnetwork = "projects/pcc-prj-shared-infra/regions/us-east4/subnetworks/pcc-subnet-devops-nonprod"

  # Secondary ranges for DevOps cluster (from Phase 1.1)
  pods_range_name     = "pcc-prj-devops-nonprod-sub-pod"
  services_range_name = "pcc-prj-devops-nonprod-sub-svc"

  release_channel         = "REGULAR"
  maintenance_start_time  = "03:00"

  labels = {
    environment = "nonprod"
    project     = "devops"
    managed-by  = "terraform"
  }
}

# Cluster 2: DevOps Prod (ArgoCD primary)
module "gke_devops_prod" {
  source = "../../core/pcc-tf-library/modules/gke-autopilot-cluster"

  cluster_name = "pcc-gke-devops-prod"
  project_id   = "pcc-prj-devops-prod"
  region       = "us-east4"

  network    = "projects/pcc-prj-shared-infra/global/networks/pcc-vpc-shared"
  subnetwork = "projects/pcc-prj-shared-infra/regions/us-east4/subnetworks/pcc-subnet-devops-prod"

  # Secondary ranges for DevOps cluster (from Phase 1.1)
  pods_range_name     = "pcc-prj-devops-prod-sub-pod"
  services_range_name = "pcc-prj-devops-prod-sub-svc"

  release_channel         = "REGULAR"
  maintenance_start_time  = "03:00"

  labels = {
    environment = "prod"
    project     = "devops"
    managed-by  = "terraform"
  }
}

# Cluster 3: App Devtest (microservices)
module "gke_app_devtest" {
  source = "../../core/pcc-tf-library/modules/gke-autopilot-cluster"

  cluster_name = "pcc-gke-app-devtest"
  project_id   = "pcc-prj-app-devtest"
  region       = "us-east4"

  network    = "projects/pcc-prj-shared-infra/global/networks/pcc-vpc-shared"
  subnetwork = "projects/pcc-prj-shared-infra/regions/us-east4/subnetworks/pcc-subnet-app-devtest"

  # Secondary ranges for pods and services (from Phase 1)
  pods_range_name     = "pcc-subnet-app-devtest-pods"
  services_range_name = "pcc-subnet-app-devtest-services"

  release_channel         = "REGULAR"
  maintenance_start_time  = "03:00"

  labels = {
    environment = "devtest"
    project     = "app"
    managed-by  = "terraform"
  }
}
```

---

### File: infra/pcc-app-shared-infra/terraform/backend.tf

```hcl
terraform {
  backend "gcs" {
    bucket  = "pcc-terraform-state"
    prefix  = "pcc-app-shared-infra"
  }
}
```

**Note**: GCS bucket `pcc-terraform-state` must exist before `terraform init`. Create with:
```bash
gsutil mb -p pcc-app-shared-infra -l us-east4 gs://pcc-terraform-state/
```

---

## Cluster Configurations

### 1. pcc-gke-devops-nonprod

**Purpose**: Nonprod monitoring and utilities

**Configuration**:
- **Project**: pcc-prj-devops-nonprod
- **Subnet**: 10.24.128.0/20
- **Secondary Ranges**:
  - Pods: pcc-prj-devops-nonprod-sub-pod
  - Services: pcc-prj-devops-nonprod-sub-svc
- **Workloads**: Monitoring tools, utilities

---

### 2. pcc-gke-devops-prod

**Purpose**: ArgoCD primary cluster

**Configuration**:
- **Project**: pcc-prj-devops-prod
- **Subnet**: 10.16.128.0/20
- **Secondary Ranges**:
  - Pods: pcc-prj-devops-prod-sub-pod
  - Services: pcc-prj-devops-prod-sub-svc
- **Workloads**: ArgoCD, production system services

---

### 3. pcc-gke-app-devtest

**Purpose**: Microservices application workloads

**Configuration**:
- **Project**: pcc-prj-app-devtest
- **Subnet**: 10.28.0.0/20 (primary)
- **Secondary Ranges**:
  - Pods: 10.28.16.0/20 (pcc-subnet-app-devtest-pods)
  - Services: 10.28.32.0/20 (pcc-subnet-app-devtest-services)
- **Workloads**: 7 microservices (starting with pcc-client-api-devtest)

---

## Network Integration

### VPC Configuration

**Shared VPC**: `pcc-vpc-shared` (created in Phase 1)

**Cluster Networking**:
- All clusters in same VPC (private networking)
- Private nodes (no external IPs)
- Private API endpoint (access via Connect Gateway)
- Workload Identity enabled (GCP IAM integration)

---

## Autopilot Features

### Google-Managed

- **Node management**: Google provisions and manages nodes
- **Scaling**: Auto-scales based on workload
- **Security**: Automatic security updates
- **Cost**: Pay only for running pods (not idle nodes)

### Enabled by Default

- Workload Identity
- Shielded GKE nodes
- Secure boot
- Binary authorization
- Container-Optimized OS

### Limitations

- Cannot SSH to nodes
- No DaemonSets (except Google-managed)
- No privileged containers
- No hostPath volumes

---

## Deliverables

- [ ] Terraform module created in `core/pcc-tf-library/modules/gke-autopilot-cluster/`
- [ ] Module calls created in `infra/pcc-app-shared-infra/terraform/main.tf`
- [ ] All 3 cluster configurations documented
- [ ] Network integration verified
- [ ] Private Service Connect (PSC) configuration validated

---

## Validation Criteria

- [ ] Module follows terraform best practices
- [ ] All required variables defined
- [ ] Outputs include cluster endpoint and credentials
- [ ] 3 module calls configured (devops-nonprod, devops-prod, app-devtest)
- [ ] Network references correct (VPC, subnets, secondary ranges)
- [ ] PSC configuration eliminates need for master CIDR blocks

---

## Dependencies

**Upstream**:
- Phase 3.2: Network details collected

**Downstream**:
- Phase 3.4: Cross-project IAM (ArgoCD SA needs cluster endpoints)
- Phase 3.5: Terraform validation

---

## Notes

### Cluster Configuration

- **Autopilot mode**: Simplifies cluster management (Google handles nodes)
- **Fully private clusters**: Both nodes AND control plane endpoints are private
- **Workload Identity**: Required for GCP service account integration
- **Secondary ranges**: All 3 clusters require secondary ranges for pods and services
- **DevOps clusters**: Secondary ranges created in Phase 1.1 foundation
- **App-devtest cluster**: Secondary ranges created in Phase 1
- **Module versioning**: Use git tags (e.g., `v1.0.0`) for module source

### Private Service Connect (PSC) - GKE 1.29+

**What Changed:**
- **Before GKE 1.29**: Private clusters required a `/28` CIDR block (`master_ipv4_cidr_block`) for control plane VPC peering
- **After GKE 1.29**: Private Service Connect (PSC) replaced VPC peering - NO CIDR block needed
- **Why This Matters**: Eliminates CIDR overlap issues, simplifies networking, and reduces VPC peering complexity

**IMPORTANT**: The `master_ipv4_cidr_block` parameter has been **removed** from this configuration because:
1. ✅ We're using GKE 1.29+ (REGULAR release channel)
2. ✅ PSC handles control plane connectivity automatically
3. ✅ No risk of CIDR overlap with existing subnet ranges
4. ✅ Cleaner, simpler configuration

**Reference**: [GKE Private Clusters Documentation](https://cloud.google.com/kubernetes-engine/docs/concepts/private-cluster-concept)

### Connect Gateway (Private Cluster Access)

**What It Does:**
- Enables kubectl access to **fully private clusters** (private endpoint + private nodes)
- No VPN, bastion hosts, or authorized network IP allowlists required
- Secure proxy managed by Google, authenticated via IAM

**How to Use:**
```bash
# Register cluster with Connect Gateway (one-time setup per cluster)
gcloud container fleet memberships register CLUSTER_NAME \
  --gke-cluster=REGION/CLUSTER_NAME \
  --enable-workload-identity

# Get kubectl credentials (uses Connect Gateway automatically)
gcloud container fleet memberships get-credentials CLUSTER_NAME

# kubectl commands route through Connect Gateway proxy
kubectl get nodes
kubectl get pods -A
```

**Why We Use It:**
- ✅ Access private clusters from WARP terminal (no VPN needed)
- ✅ Works from Cloud Build for ArgoCD deployments
- ✅ Better security than public endpoints + IP allowlists
- ✅ No infrastructure to manage (no bastion VMs)

**IMPORTANT**: The `master_authorized_networks_config` block has been **removed** because Connect Gateway provides secure access without IP allowlists

---

## Time Estimate

**Total**: 30-40 minutes
- 10 min: Create terraform module structure
- 15 min: Document module resource and variables
- 10 min: Create 3 module calls in `pcc-app-shared-infra`
- 5 min: Verify network references and CIDRs

---

**Next Phase**: 3.4 - Cross-Project IAM Bindings
