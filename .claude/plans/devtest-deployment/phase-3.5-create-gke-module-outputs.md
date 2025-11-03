# Phase 3.5: Create GKE Module - outputs.tf

**Phase**: 3.5 (GKE Infrastructure - Module Outputs)
**Duration**: 10 minutes
**Type**: Implementation
**Status**: Ready for Execution

---

## Execution Tool

**Use Claude Code for this phase** - Creating terraform outputs file.

---

## Objective

Create `outputs.tf` file for GKE Autopilot module exposing cluster metadata, connectivity details, and feature configurations.

## Prerequisites

✅ Phase 3.4 completed (variables.tf created)
✅ Understanding of GKE cluster attributes
✅ Knowledge of required outputs for downstream configs

---

## Required Outputs

1. **Cluster Identification** (3)
   - cluster_id, cluster_name, cluster_uid

2. **Connectivity** (2)
   - cluster_endpoint, cluster_ca_certificate

3. **Features** (2)
   - workload_identity_pool, gke_hub_membership_id

---

## Step 1: Create outputs.tf

**File**: `pcc-tf-library/modules/gke-autopilot/outputs.tf`

```hcl
# Cluster Identification
output "cluster_id" {
  description = "The ID of the GKE cluster (projects/{project}/locations/{location}/clusters/{name})"
  value       = google_container_cluster.cluster.id
}

output "cluster_name" {
  description = "The name of the GKE cluster"
  value       = google_container_cluster.cluster.name
}

output "cluster_uid" {
  description = "The system-generated unique identifier for the cluster"
  value       = google_container_cluster.cluster.uid
}

# Cluster Connectivity
output "cluster_endpoint" {
  description = "The IP address of the cluster master endpoint (sensitive)"
  value       = google_container_cluster.cluster.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Base64 encoded public certificate for cluster master (sensitive)"
  value       = google_container_cluster.cluster.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

# Workload Identity
output "workload_identity_pool" {
  description = "The Workload Identity pool for this cluster (format: {project}.svc.id.goog)"
  value       = var.enable_workload_identity ? "${var.project_id}.svc.id.goog" : null
}

# Connect Gateway
output "gke_hub_membership_id" {
  description = "The GKE Hub membership ID for Connect Gateway access"
  value       = var.enable_connect_gateway ? google_gke_hub_membership.cluster[0].id : null
}
```

---

## Output Design Decisions

### Sensitive Outputs

**Why endpoint and ca_certificate are sensitive**:
- Contains cluster access credentials
- Hidden from terraform logs and console output
- Prevents accidental exposure in CI/CD pipelines

### Conditional Outputs

**Why use `var.enable_*` checks**:
- `workload_identity_pool`: Only output if feature enabled
- `gke_hub_membership_id`: Only exists if Connect Gateway enabled

**Why use `[0]` index**:
- `google_gke_hub_membership.cluster[0]`: Resource uses `count = var.enable_connect_gateway ? 1 : 0`
- Access first (and only) instance when count = 1

### Workload Identity Pool Format

**Standard format**: `{project-id}.svc.id.goog`

Example: `pcc-prj-devops-nonprod.svc.id.goog`

Used for:
- Kubernetes ServiceAccount annotations
- IAM policy bindings in Phase 3.12

---

## Validation Checklist

- [ ] File created: `outputs.tf`
- [ ] 6 outputs defined (not 8 - PSC output removed)
- [ ] 2 outputs marked sensitive
- [ ] 2 outputs have conditional logic
- [ ] All descriptions include purpose
- [ ] 2-space indentation
- [ ] No syntax errors

---

## Output Summary

| Output | Type | Sensitive | Conditional | Purpose |
|--------|------|-----------|-------------|---------|
| cluster_id | string | ❌ | ❌ | Resource identification |
| cluster_name | string | ❌ | ❌ | Display name |
| cluster_uid | string | ❌ | ❌ | Unique system ID |
| cluster_endpoint | string | ✅ | ❌ | kubectl API endpoint |
| cluster_ca_certificate | string | ✅ | ❌ | TLS certificate |
| workload_identity_pool | string | ❌ | ✅ | Pod authentication |
| gke_hub_membership_id | string | ❌ | ✅ | Connect Gateway |

---

## Usage Example

**Accessing outputs in environment configuration**:

```hcl
# environments/nonprod/gke.tf
module "gke_devops" {
  source = "git::https://github.com/portco-connect/pcc-tf-library.git//modules/gke-autopilot?ref=main"
  # ... module inputs
}

# Use outputs for IAM bindings, ArgoCD config, etc.
output "cluster_endpoint" {
  value     = module.gke_devops.cluster_endpoint
  sensitive = true
}
```

---

## Next Phase Dependencies

**Phase 3.6** will:
- Create `main.tf` with `google_container_cluster` and `google_gke_hub_membership` resources
- Reference these outputs in module documentation

---

## References

- **GKE Cluster Outputs**: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster#attributes-reference
- **ADR-002**: Apigee GKE Ingress Strategy (PSC outputs)
- **ADR-005**: Workload Identity Pattern (pool format)

---

## Time Estimate

- **Create cluster outputs**: 4 minutes (5 outputs)
- **Create feature outputs**: 2 minutes (2 outputs)
- **Add conditional logic**: 2 minutes
- **Total**: 8 minutes

---

**Status**: Ready for execution
**Next**: Phase 3.6 - Create GKE Module (main.tf)
