# Phase 1.2: Create App Devtest Subnet

**Phase**: 1.2 (Network Infrastructure - App Devtest Subnet)
**Duration**: 10-15 minutes
**Type**: Planning + Implementation
**Status**: 📋 Planning (Not Started)
**Date**: TBD (10/20+)

---

## Objective

Create new GKE-ready subnet for `pcc-prj-app-devtest` with primary range and secondary ranges for pods and services, plus overflow subnet for PSC endpoints and future expansion. This enables Phase 2 AlloyDB deployment and future GKE cluster creation.

## Prerequisites

✅ Phase 1.1 completed (DevOps subnets renamed)
✅ `pcc-foundation-infra` repository available
✅ GCP_Network_Subnets.pdf reviewed (10.28.x.x allocation)
✅ NonProduction VPC exists

## Subnet Specification (from PDF)

**Project**: `pcc-prj-app-devtest`
**VPC**: NonProduction VPC (in `pcc-prj-net-shared`)
**Region**: `us-east4`

### IP Allocations

| Purpose | Range Name | CIDR | IPs |
|---------|-----------|------|-----|
| Primary (nodes) | `pcc-prj-app-devtest` | `10.28.0.0/20` | 4,096 |
| Pods | `pcc-prj-app-devtest-sub-pod` | `10.28.16.0/20` | 4,096 |
| Services | `pcc-prj-app-devtest-sub-svc` | `10.28.32.0/20` | 4,096 |
| Overflow (PSC + expansion) | `pcc-prj-app-devtest-overflow` | `10.28.48.0/20` | 4,096 |

## Terraform Configuration

### File Location
`pcc-foundation-infra/terraform/modules/network/subnets.tf`

### New Resources

#### Main GKE Subnet

```hcl
resource "google_compute_subnetwork" "app_devtest_use4" {
  project       = var.network_projects.nonprod
  name          = "pcc-prj-app-devtest"
  ip_cidr_range = "10.28.0.0/20"
  region        = var.primary_region
  network       = google_compute_network.nonprod.id

  description = "App Devtest subnet - us-east4 (GKE nodes)"

  secondary_ip_range {
    range_name    = "pcc-prj-app-devtest-sub-pod"
    ip_cidr_range = "10.28.16.0/20"
  }

  secondary_ip_range {
    range_name    = "pcc-prj-app-devtest-sub-svc"
    ip_cidr_range = "10.28.32.0/20"
  }

  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_10_MIN"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }

  labels = {
    environment = "devtest"
    purpose     = "gke-nodes"
    managed_by  = "terraform"
  }
}
```

#### Overflow Subnet (PSC + Expansion)

```hcl
resource "google_compute_subnetwork" "app_devtest_overflow_use4" {
  project       = var.network_projects.nonprod
  name          = "pcc-prj-app-devtest-overflow"
  ip_cidr_range = "10.28.48.0/20"
  region        = var.primary_region
  network       = google_compute_network.nonprod.id

  description = "App Devtest overflow subnet - us-east4 (PSC endpoints, expansion)"

  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_10_MIN"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }

  labels = {
    environment = "devtest"
    purpose     = "overflow-psc"
    managed_by  = "terraform"
  }
}
```

## Key Configuration Details

### 1. VPC Flow Logs
- **Aggregation**: 10-minute intervals
- **Sampling**: 50% (balance observability vs. cost)
- **Metadata**: Full metadata for troubleshooting
- **Purpose**: Network analysis, security monitoring

### 2. Private Google Access
- **Enabled**: `true`
- **Purpose**: Access Google APIs without public IPs
- **Use Cases**: Artifact Registry, Cloud Storage, AlloyDB Auth Proxy

### 3. Secondary Range Naming
- **Pods**: `pcc-prj-app-devtest-sub-pod` (matches PDF convention)
- **Services**: `pcc-prj-app-devtest-sub-svc` (matches PDF convention)
- **Critical**: GKE cluster config in Phase 5 must reference these exact names

### 4. IP Capacity Planning
- **Nodes**: 4,096 IPs - supports large GKE cluster
- **Pods**: 4,096 IPs - ~256 nodes × 16 pods/node
- **Services**: 4,096 IPs - sufficient for microservices architecture
- **Overflow**: 4,096 IPs - PSC endpoints (AlloyDB @ 10.28.48.10) + future expansion

### 5. Network References
- Uses NonProduction VPC: `google_compute_network.nonprod.id`
- Project: `var.network_projects.nonprod` (resolves to `pcc-prj-net-shared`)

### 6. Firewall Rules
- **Note**: Firewall rules for GKE communication (pod-to-pod, node-to-pod, node-to-control-plane) will be created in Phase 5 when the GKE cluster is deployed
- **Current Scope**: These subnets provide the network space only
- **Future Work**: Firewall rules will be added alongside GKE cluster creation to ensure proper connectivity
- **Why Deferred**: Firewall rules are tightly coupled to GKE cluster configuration and should be managed together

## IP Overlap Validation

**No Conflicts With:**
- ✅ DevOps NonProd: `10.24.128.0/20` (different /13 block)
- ✅ Apigee NonProd: `10.24.192.0/20 - 10.24.240.0/20` (not being created)
- ✅ Apigee PSC: `10.29.0.0/20` (different /13 block, for Apigee connectivity)

**Allocation Boundary:**
- App Devtest uses: `10.28.0.0/20` through `10.28.48.0/20` (4 /20 blocks - all created)
- Next available: `10.29.0.0/20` (allocated for Apigee PSC connectivity)

## Tasks

1. **Add Main Terraform Resource**:
   - [ ] Create new `google_compute_subnetwork` resource for main subnet
   - [ ] Set name to `pcc-prj-app-devtest` (no region)
   - [ ] Configure 2 secondary ranges (pods, services)
   - [ ] Enable VPC Flow Logs and Private Google Access
   - [ ] Add labels for environment tracking

2. **Add Overflow Terraform Resource**:
   - [ ] Create new `google_compute_subnetwork` resource for overflow
   - [ ] Set name to `pcc-prj-app-devtest-overflow`
   - [ ] Configure CIDR as `10.28.48.0/20`
   - [ ] Enable VPC Flow Logs and Private Google Access
   - [ ] Add labels (purpose: overflow-psc)

3. **Validate Configuration**:
   - [ ] Verify CIDR ranges match PDF (4 total ranges)
   - [ ] Confirm secondary range names match convention
   - [ ] Check network reference points to NonProduction VPC
   - [ ] Validate no IP overlaps with existing subnets

4. **Documentation**:
   - [ ] Note overflow subnet for Phase 2 (AlloyDB PSC endpoint will be created there)
   - [ ] Document secondary range names for Phase 5 (GKE cluster)
   - [ ] Update network diagram (if applicable)

## Dependencies

**Upstream**:
- Phase 1.1: DevOps subnets renamed (clears namespace)
- NonProduction VPC exists in `pcc-prj-net-shared`

**Downstream**:
- Phase 2: AlloyDB cluster + PSC endpoint (will use overflow subnet for PSC endpoint at 10.28.48.10)
- Phase 5: GKE cluster (will use secondary ranges for pods/services)

## Validation Criteria

- [ ] Terraform plan shows exactly 2 new resources to add
- [ ] Main subnet: Primary CIDR is `10.28.0.0/20`
- [ ] Main subnet: Two secondary ranges defined (pods: 10.28.16.0/20, services: 10.28.32.0/20)
- [ ] Overflow subnet: CIDR is `10.28.48.0/20`
- [ ] Both subnets: VPC Flow Logs enabled
- [ ] Both subnets: Private Google Access enabled
- [ ] No IP conflicts with existing allocations
- [ ] Labels include environment, purpose, managed_by

## Expected Terraform Plan Output

```
Terraform will perform the following actions:

  # google_compute_subnetwork.app_devtest_use4 will be created
  + resource "google_compute_subnetwork" "app_devtest_use4" {
      + name          = "pcc-prj-app-devtest"
      + ip_cidr_range = "10.28.0.0/20"
      + region        = "us-east4"
      + network       = (reference to nonprod VPC)
      + project       = "pcc-prj-net-shared"

      + secondary_ip_range {
          + range_name    = "pcc-prj-app-devtest-sub-pod"
          + ip_cidr_range = "10.28.16.0/20"
        }

      + secondary_ip_range {
          + range_name    = "pcc-prj-app-devtest-sub-svc"
          + ip_cidr_range = "10.28.32.0/20"
        }

      # (flow logs, labels, etc.)
    }

  # google_compute_subnetwork.app_devtest_overflow_use4 will be created
  + resource "google_compute_subnetwork" "app_devtest_overflow_use4" {
      + name          = "pcc-prj-app-devtest-overflow"
      + ip_cidr_range = "10.28.48.0/20"
      + region        = "us-east4"
      + network       = (reference to nonprod VPC)
      + project       = "pcc-prj-net-shared"

      # (flow logs, labels, etc.)
    }

Plan: 2 to add, 0 to change, 0 to destroy.
```

## Outputs for Downstream Phases

**Phase 2 (AlloyDB Cluster + PSC) Needs:**
- Overflow subnet: `pcc-prj-app-devtest-overflow` (for PSC endpoint)
- Overflow CIDR: `10.28.48.0/20`
- Target IP: `10.28.48.10` (will be created by AlloyDB terraform)
- VPC: NonProduction VPC in `pcc-prj-net-shared`
- Region: `us-east4`

**Phase 5 (GKE Cluster) Needs:**
- Subnet: `pcc-prj-app-devtest`
- Pods secondary range: `pcc-prj-app-devtest-sub-pod`
- Services secondary range: `pcc-prj-app-devtest-sub-svc`

## References

- 📊 Subnet Allocation: `$HOME/pcc/pcc-ai-memory/pcc-foundation-infra/.claude/reference/GCP_Network_Subnets.pdf`
- 📁 Foundation Repo: `pcc-foundation-infra/terraform/modules/network/subnets.tf`
- 🔗 GKE Alias IPs: https://cloud.google.com/kubernetes-engine/docs/concepts/alias-ips
- 🔗 VPC Subnets: https://cloud.google.com/vpc/docs/subnets

## Notes

- **Naming**: Follows PDF convention `pcc-prj-{project}` with no region suffix
- **Secondary Ranges**: Critical for GKE - must match exactly in Phase 5 cluster config
- **Overflow Subnet**: Created for PSC endpoints (AlloyDB at 10.28.48.10) and future expansion
- **AlloyDB PSC**: PSC endpoint will be created in Phase 2 alongside AlloyDB cluster
- **Flow Logs**: 50% sampling balances observability needs with logging costs
- **Two Subnets**: Main for GKE workloads, overflow for PSC and expansion

## Time Estimate

**Planning + Implementation**: 15-20 minutes
- 7 min: Add both terraform resources with correct configuration
- 4 min: Validate CIDR ranges and naming
- 4 min: Run terraform plan and review (expecting 2 adds)
- 5 min: Document outputs for downstream phases

---

**Next Phase**: 1.3 - Validate Terraform Configuration
