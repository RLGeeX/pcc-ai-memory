# Phase 3.6: Create GKE Module - main.tf

**Phase**: 3.6 (GKE Infrastructure - Module Resources)
**Duration**: 15-18 minutes
**Type**: Implementation
**Status**: Ready for Execution

---

## Execution Tool

**Use Claude Code for this phase** - Creating terraform resource files.

---

## Objective

Create `main.tf` with GKE Autopilot cluster and Connect Gateway resources for DevOps cluster (system services, ArgoCD, monitoring).

## Prerequisites

✅ Phase 3.5 completed (outputs.tf created)
✅ Understanding of GKE Autopilot configuration
✅ Knowledge of Connect Gateway setup (ADR-002)

---

## Resources to Create

**main.tf** (2 resources):
1. `google_container_cluster.cluster` - GKE Autopilot cluster
2. `google_gke_hub_membership.cluster` - Connect Gateway registration

---

## Step 1: Create main.tf

**File**: `pcc-tf-library/modules/gke-autopilot/main.tf`

```hcl
# GKE Autopilot Cluster
# Private cluster with Workload Identity and Connect Gateway
resource "google_container_cluster" "cluster" {
  name     = var.cluster_name
  location = var.region
  project  = var.project_id

  # Display name defaults to cluster name if not provided
  display_name = var.cluster_display_name != "" ? var.cluster_display_name : var.cluster_name

  # Autopilot mode
  enable_autopilot = true

  # Release channel for version management
  release_channel {
    channel = var.release_channel
  }

  # Private cluster configuration
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = true   # Private endpoint with Connect Gateway
    # master_ipv4_cidr_block omitted - Google auto-allocates /28 from 172.16.0.0/16 for Autopilot
  }

  # IP allocation policy (required for private cluster)
  ip_allocation_policy {
    cluster_ipv4_cidr_block  = ""  # Auto-allocated
    services_ipv4_cidr_block = ""  # Auto-allocated
  }

  # Network and subnetwork
  network    = var.network_id
  subnetwork = var.subnet_id

  # Workload Identity
  workload_identity_config {
    workload_pool = var.enable_workload_identity ? "${var.project_id}.svc.id.goog" : null
  }

  # Cloud Audit Logging
  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  # Binary Authorization (disabled initially, to be configured in Phase 6)
  binary_authorization {
    evaluation_mode = "DISABLED"
  }

  # Maintenance policy (weekends only)
  maintenance_policy {
    recurring_window {
      start_time = "2025-01-04T00:00:00Z"  # Saturday midnight UTC
      end_time   = "2025-01-04T06:00:00Z"  # Saturday 6 AM UTC
      recurrence = "FREQ=WEEKLY;BYDAY=SA"
    }
  }

  # Labels
  resource_labels = merge(
    var.cluster_labels,
    {
      managed_by  = "terraform"
      environment = var.environment
    }
  )

  # Deletion protection
  deletion_protection = var.environment == "prod" ? true : false
}

# GKE Hub Membership for Connect Gateway
resource "google_gke_hub_membership" "cluster" {
  count = var.enable_connect_gateway ? 1 : 0

  project       = var.project_id
  membership_id = "${var.cluster_name}-membership"
  location      = "global"  # GKE Hub is a global service

  endpoint {
    gke_cluster {
      resource_link = google_container_cluster.cluster.id
    }
  }

  labels = {
    cluster     = var.cluster_name
    environment = var.environment
  }
}
```

**Key Configuration Decisions**:
- **enable_autopilot = true**: Fully managed nodes (ADR-003)
- **enable_private_endpoint = true**: Private endpoint with Connect Gateway (ADR-002)
- **master_ipv4_cidr_block**: Omitted - Google auto-allocates /28 from 172.16.0.0/16 for Autopilot
- **Maintenance window**: Saturdays only (low traffic)
- **deletion_protection**: True for prod, false for devtest/dev/staging
- **Binary Authorization**: Disabled initially (to be configured in Phase 6)

---

## Validation Checklist

- [ ] File created: `main.tf`
- [ ] `google_container_cluster.cluster` resource defined
- [ ] `enable_autopilot = true` set
- [ ] Private cluster config correct (no master_ipv4_cidr_block)
- [ ] Workload Identity conditional on flag
- [ ] Connect Gateway Hub membership conditional
- [ ] Maintenance window configured
- [ ] Labels include environment

---

## GKE Autopilot Features

| Feature | Enabled | Configuration |
|---------|---------|---------------|
| Autopilot Mode | ✅ | enable_autopilot = true |
| Private Nodes | ✅ | enable_private_nodes = true |
| Private Endpoint | ✅ | Private with Connect Gateway |
| Workload Identity | ✅ | Conditional (default: true) |
| Binary Authorization | ❌ | Disabled (to be configured in Phase 6) |
| Connect Gateway | ✅ | Conditional (default: true) |
| Maintenance Window | ✅ | Saturdays 00:00-06:00 UTC |
| Deletion Protection | 🔵 | Prod only |

---

## Next Phase Dependencies

**Phase 3.7** will:
- Create `pcc-devops-infra` repository structure
- Use Git to initialize new infrastructure repo
- WARP execution (not Claude Code)

**Phase 3.8** will:
- Create environment folder configuration
- Reference this module via Git source (ref=v0.1.0)

---

## References

- **GKE Autopilot**: https://cloud.google.com/kubernetes-engine/docs/concepts/autopilot-overview
- **Connect Gateway**: https://cloud.google.com/anthos/multicluster-management/gateway
- **ADR-002**: Apigee GKE Ingress Strategy (Connect Gateway)
- **ADR-003**: GKE Autopilot Strategy (assumed)
- **ADR-005**: Workload Identity Pattern

---

## Time Estimate

- **Create main.tf**: 15-18 minutes (cluster config + Hub membership)
- **Review/validate**: 3 minutes
- **Total**: 15-18 minutes

---

## Step 2: Commit and Tag Module

After creating `main.tf`, commit the GKE Autopilot module and create version tag:

```bash
cd ~/pcc/core/pcc-tf-library

# Validate module syntax before committing
terraform -chdir=modules/gke-autopilot init
terraform -chdir=modules/gke-autopilot validate

# Add all module files
git add modules/gke-autopilot/

# Commit with conventional commit message
git commit -m "feat: add GKE Autopilot module with Connect Gateway support

- Add GKE Autopilot cluster resource
- Add Connect Gateway Hub membership
- Configure private endpoint with Connect Gateway
- Add Workload Identity configuration
- Add audit logging for system and workload components
- Disable Binary Authorization initially (to be configured in Phase 6)"

# Update v0.1.0 tag to include GKE module resources
git tag -f v0.1.0

# Push main branch normally (no force)
git push origin main

# Force-push only the v0.1.0 tag (not main branch)
git push --force-with-lease origin refs/tags/v0.1.0
```

⚠️ **IMPORTANT**: Force-pushing tags can affect other developers. This is safe here because:
- v0.1.0 is being extended with new modules (not changing existing ones)
- Library is in active development (not production-stable yet)
- **Team members who already used v0.1.0 must run `terraform init -upgrade`** to download the updated tag

**For team members in other environments**:
```bash
# In any workspace that already pulled v0.1.0
cd ~/pcc/infra/<your-project>/environments/<env>
terraform init -upgrade  # Force re-download of updated v0.1.0 tag
```

📝 **TEMPORARY TECHNICAL DEBT**: This force-push tag strategy is acceptable during active development with a single deployer. This approach will be replaced with proper semantic versioning (v0.1.1, v0.1.2, etc.) before:
- Adding CI/CD pipelines
- Second person starts deploying
- Infrastructure reaches production stability

**Why same version (v0.1.0)?**
- v0.1.0 already exists (AlloyDB module from earlier phases)
- Adding GKE Autopilot module extends v0.1.0 library
- No need to bump version just for adding new modules

**Verification**:
```bash
# Verify tag updated
git tag -l "v0.1.*"

# Verify remote tag
git ls-remote --tags origin | grep v0.1.0
```

---

**Status**: Ready for execution
**Next**: Phase 3.7 - Create DevOps Infra Repo Structure (WARP)
