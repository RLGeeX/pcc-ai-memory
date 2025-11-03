# AlloyDB PSC Cross-Project Connectivity - Implementation Summary

**Date**: 2025-10-30
**Status**: ✅ COMPLETE - All terraform changes implemented and validated
**Purpose**: Enable Headscale VM in `pcc-prj-devops-nonprod` to connect to AlloyDB in `pcc-prj-app-devtest` via Private Service Connect (PSC)

## Overview

Implemented cross-project PSC connectivity to allow developers to access AlloyDB via Headscale VPN without requiring VPC peering. This enables Phase 2 (AlloyDB) to integrate with the VPN access design.

## Changes Implemented

### Phase 1: AlloyDB Module Updates ✅

**File**: `core/pcc-tf-library/modules/alloydb-cluster/outputs.tf`

**Changes**:
- Added `psc_service_attachment_link` output (line 79-82)
- Exposes the PSC service attachment URI needed by consumer projects

**Validation**: ✅ `terraform validate` passed

### Phase 2: AlloyDB Deployment Updates ✅

**File**: `infra/pcc-app-shared-infra/terraform/environments/devtest/alloydb.tf`

**Changes**:
1. **Updated PSC Allowlist** (lines 53-56):
   ```hcl
   psc_allowed_consumer_projects = [
     var.app_project_number,  # pcc-prj-app-devtest
     "1019482455655"          # pcc-prj-devops-nonprod
   ]
   ```

2. **Added PSC Output** (lines 101-105):
   ```hcl
   output "alloydb_psc_service_attachment" {
     description = "PSC service attachment for cross-project connectivity"
     value       = module.alloydb.psc_service_attachment_link
   }
   ```

**Key Data**:
- DevOps NonProd Project Number: `1019482455655`
- Retrieved via: `gcloud projects describe pcc-prj-devops-nonprod --format="value(projectNumber)"`

### Phase 3: PSC Consumer Configuration ✅

**Directory**: `infra/pcc-devops-infra/terraform/environments/nonprod/`

**Files Created**:

1. **backend.tf**: GCS state backend configuration
   - Bucket: `pcc-tfstate-shared-us-east4`
   - Prefix: `devops-infra/nonprod`

2. **providers.tf**: Google provider configuration
   - Version: `~> 5.0`
   - Terraform: `>= 1.5`

3. **variables.tf**: Variable definitions
   - Project: `pcc-prj-devops-nonprod` (1019482455655)
   - Region: `us-east4`
   - Network: `pcc-vpc-nonprod` (from `pcc-prj-network-nonprod`)
   - Subnet: `pcc-prj-devops-nonprod` (10.24.128.0/20)

4. **terraform.tfvars**: Variable values
   - All defaults properly configured
   - Remote state bucket: `pcc-tfstate-shared-us-east4`

5. **alloydb-psc-consumer.tf**: Main PSC resources
   - **google_compute_address**: Static internal IP for PSC endpoint
   - **google_compute_forwarding_rule**: PSC connection to AlloyDB
   - **terraform_remote_state**: Reads service attachment from app-shared-infra

6. **outputs.tf**: PSC endpoint information
   - `alloydb_psc_endpoint_ip`: IP address for connections
   - `alloydb_connection_string_example`: Connection string template

7. **README.md**: Comprehensive documentation
   - Architecture diagram
   - Deployment instructions
   - Troubleshooting guide

**Validation**: ✅ `terraform init` and `terraform validate` passed

## Network Architecture

```
┌─────────────────────────────────────────────┐
│ pcc-prj-app-devtest (Source)                │
│                                             │
│  AlloyDB Cluster (PSC Enabled)              │
│  └─ PSC Service Attachment                  │◄────┐
│     (Auto-created by AlloyDB)               │     │
│     Allowlist: [app-devtest, devops-nonprod]│     │
└─────────────────────────────────────────────┘     │
                                                    │
                                                    │ PSC Connection
                                                    │ (Cross-Project)
                                                    │
┌─────────────────────────────────────────────┐     │
│ pcc-prj-devops-nonprod (Consumer)           │     │
│                                             │     │
│  PSC Forwarding Rule ──────────────────────┼─────┘
│  └─ Internal IP: 10.24.128.x                │
│                                             │
│  Headscale VM                               │
│  └─ Connects to PSC endpoint                │
│     Routes to developers via VPN            │
└─────────────────────────────────────────────┘
```

## Key Technical Details

### PSC Service Attachment
- **Type**: Automatically created by AlloyDB when `psc_enabled = true`
- **URI Format**: `projects/{project}/regions/{region}/serviceAttachments/{name}`
- **Security**: Project number allowlist (1019482455655 added)

### PSC Forwarding Rule
- **Type**: `google_compute_forwarding_rule`
- **Scheme**: Empty (PSC-specific)
- **Target**: AlloyDB service attachment (cross-project reference)
- **IP**: Static internal address in consumer VPC

### Remote State Access
- **Method**: `terraform_remote_state` data source
- **Bucket**: `pcc-tfstate-shared-us-east4`
- **Prefix**: `app-shared-infra/devtest`
- **Permission Required**: `roles/storage.objectViewer` on state bucket

## Deployment Sequence

### Step 1: Update AlloyDB Module (DONE)
```bash
cd /home/jfogarty/pcc/core/pcc-tf-library
# Changes already applied and validated
```

### Step 2: Update AlloyDB Deployment (READY)
```bash
cd /home/jfogarty/pcc/infra/pcc-app-shared-infra/terraform/environments/devtest

# Initialize with updated module
terraform init -upgrade

# Review changes
terraform plan -out=tfplan

# Apply updates
terraform apply tfplan

# Verify PSC service attachment output
terraform output alloydb_psc_service_attachment
```

### Step 3: Deploy PSC Consumer (READY)
```bash
cd /home/jfogarty/pcc/infra/pcc-devops-infra/terraform/environments/nonprod

# Initialize
terraform init

# Review plan
terraform plan -out=tfplan

# Apply configuration
terraform apply tfplan

# Get PSC endpoint IP
PSC_ENDPOINT_IP=$(terraform output -raw alloydb_psc_endpoint_ip)
echo "AlloyDB PSC Endpoint: $PSC_ENDPOINT_IP"
```

### Step 4: Update Headscale Configuration (PENDING)
```bash
# Use PSC endpoint IP instead of AlloyDB VPC IP
# Connection string: postgresql://user@${PSC_ENDPOINT_IP}:5432/database
```

## Testing & Validation

### Verify PSC Connection
```bash
# From Headscale VM (after PSC deployed)
ping <psc_endpoint_ip>

# Test AlloyDB connection
psql -h <psc_endpoint_ip> -p 5432 -U postgres -d client_api_db
```

### Check PSC Forwarding Rule Status
```bash
gcloud compute forwarding-rules describe alloydb-psc-forwarding-rule \
  --region=us-east4 \
  --project=pcc-prj-devops-nonprod
```

### Verify Service Attachment
```bash
# List service attachments in AlloyDB project
gcloud compute service-attachments list \
  --project=pcc-prj-app-devtest \
  --region=us-east4
```

## Security Considerations

### Allowlist Security
- PSC uses project **numbers** (not IDs) for allowlist
- Only `pcc-prj-app-devtest` and `pcc-prj-devops-nonprod` can connect
- No additional firewall rules needed (PSC bypasses VPC firewall)

### Authentication
- AlloyDB authentication still required (username/password)
- PSC only provides network connectivity
- Secrets stored in Secret Manager

### Network Isolation
- PSC endpoint is internal IP only (no public exposure)
- Requires VPN access (via Headscale) to reach PSC endpoint
- No VPC peering required

## Files Modified

| File | Type | Lines Changed |
|------|------|---------------|
| `core/pcc-tf-library/modules/alloydb-cluster/outputs.tf` | Modified | +4 (lines 79-82) |
| `infra/pcc-app-shared-infra/terraform/environments/devtest/alloydb.tf` | Modified | +9 (lines 53-56, 101-105) |
| `infra/pcc-devops-infra/terraform/environments/nonprod/backend.tf` | Created | 9 lines |
| `infra/pcc-devops-infra/terraform/environments/nonprod/providers.tf` | Created | 17 lines |
| `infra/pcc-devops-infra/terraform/environments/nonprod/variables.tf` | Created | 49 lines |
| `infra/pcc-devops-infra/terraform/environments/nonprod/terraform.tfvars` | Created | 16 lines |
| `infra/pcc-devops-infra/terraform/environments/nonprod/alloydb-psc-consumer.tf` | Created | 73 lines |
| `infra/pcc-devops-infra/terraform/environments/nonprod/outputs.tf` | Created | 23 lines |
| `infra/pcc-devops-infra/terraform/environments/nonprod/README.md` | Created | 150+ lines |

**Total**: 2 files modified, 7 files created

## Validation Results

✅ **AlloyDB Module**: `terraform validate` - Success
✅ **PSC Consumer**: `terraform init` - Success
✅ **PSC Consumer**: `terraform validate` - Success
✅ **Terraform Formatting**: All files formatted

## Next Steps

1. **Deploy AlloyDB Updates**:
   - Run `terraform init -upgrade` in app-shared-infra/devtest
   - Apply changes to add devops-nonprod to allowlist
   - Verify `alloydb_psc_service_attachment` output

2. **Deploy PSC Consumer**:
   - Run `terraform apply` in devops-infra/nonprod
   - Record PSC endpoint IP address

3. **Update Headscale Configuration**:
   - Modify connection strings to use PSC endpoint IP
   - Test connectivity from Headscale VM
   - Update VPN access documentation

4. **Complete Phase 2**:
   - Run Flyway migrations (PCC-119)
   - Validate database connectivity via PSC

## Related Documentation

- **VPN Design**: `.claude/plans/2025-10-30-alloydb-vpn-access-design.md`
- **Phase 2 Plans**: `.claude/plans/devtest-deployment/phase-2.*.md`
- **PSC Consumer README**: `infra/pcc-devops-infra/terraform/environments/nonprod/README.md`

## Success Criteria

- [x] AlloyDB module outputs PSC service attachment
- [x] AlloyDB deployment allows devops-nonprod project
- [x] PSC consumer configuration created
- [x] All terraform configurations validated
- [ ] PSC forwarding rule deployed (pending terraform apply)
- [ ] Headscale VM can connect to AlloyDB via PSC
- [ ] Developers can access AlloyDB via Headscale VPN

**Status**: Implementation complete, ready for deployment

---

**Implementation Time**: ~45 minutes
**Token Usage**: 133k/200k (67%)
**Validation**: All configurations validated successfully
