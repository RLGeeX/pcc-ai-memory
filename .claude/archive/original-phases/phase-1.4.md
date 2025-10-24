# Phase 1.4: Deploy Network Changes via WARP

**Phase**: 1.4 (Network Infrastructure - Deployment)
**Duration**: 15-20 minutes
**Type**: Deployment
**Status**: 📋 Planning (Not Started)
**Date**: TBD (10/20+)

---

## Objective

Execute terraform deployment of network infrastructure updates via WARP: rename 2 DevOps subnets + create 2 new subnets (App Devtest main + Overflow), validate successful deployment.

## Prerequisites

✅ Phase 1.3 completed (terraform validated, plan generated)
✅ `network-update.tfplan` file exists (from Phase 1.3)
✅ WARP terminal available
✅ GCP credentials configured
✅ No existing resources depend on DevOps subnets (safe to replace)

---

## Deployment Summary

### Changes to Apply
- **Replace**: 2 DevOps subnets (name changes force replacement)
- **Create**: 2 new subnets (App Devtest main + Overflow)
- **Total**: 4 resources to add, 2 to destroy

### Expected Duration
- Subnet replacements: ~30 seconds each
- Subnet creations: ~30 seconds each
- Total deployment: 2-3 minutes

---

## WARP Deployment Steps

### Step 1: Switch to WARP Terminal

Open WARP terminal and navigate to terraform directory:
```bash
cd ~/pcc/core/pcc-foundation-infra/terraform
```

---

### Step 2: Pre-Deployment Baseline

```bash
# List current subnets (baseline)
gcloud compute networks subnets list \
  --filter="region:us-east4" \
  --project=pcc-prj-net-shared \
  --format="table(name,network,region,ipCidrRange,purpose)" > subnets-before.txt
```

**Note**: State is stored in GCS with versioning enabled - manual backup not needed.

---

### Step 3: Apply Terraform Plan

```bash
terraform apply network-update.tfplan
```

**Expected Duration**: 2-3 minutes

**Expected Output**:
```
google_compute_subnetwork.prod_use4: Destroying... [id=projects/pcc-prj-net-shared/regions/us-east4/subnetworks/pcc-subnet-prod-use4]
google_compute_subnetwork.prod_use4: Destruction complete after 15s
google_compute_subnetwork.prod_use4: Creating...
google_compute_subnetwork.prod_use4: Creation complete after 25s [id=projects/pcc-prj-net-shared/regions/us-east4/subnetworks/pcc-prj-devops-prod]

google_compute_subnetwork.nonprod_use4: Destroying... [id=...]
google_compute_subnetwork.nonprod_use4: Destruction complete after 15s
google_compute_subnetwork.nonprod_use4: Creating...
google_compute_subnetwork.nonprod_use4: Creation complete after 25s [id=.../pcc-prj-devops-nonprod]

google_compute_subnetwork.app_devtest_use4: Creating...
google_compute_subnetwork.app_devtest_use4: Creation complete after 30s [id=.../pcc-prj-app-devtest]

google_compute_subnetwork.app_devtest_overflow_use4: Creating...
google_compute_subnetwork.app_devtest_overflow_use4: Creation complete after 30s [id=.../pcc-prj-app-devtest-overflow]

Apply complete! Resources: 4 added, 0 changed, 2 destroyed.
```

---

### Step 4: Post-Deployment Validation

```bash
# List subnets (after deployment)
gcloud compute networks subnets list \
  --filter="region:us-east4" \
  --project=pcc-prj-net-shared \
  --format="table(name,network,region,ipCidrRange,purpose)" > subnets-after.txt

# Compare before/after
diff subnets-before.txt subnets-after.txt
```

**Expected Changes**:
- 2 subnet names changed (DevOps)
- 2 new subnets created (App Devtest main + Overflow)

---

### Step 5: Verify DevOps Subnets (Renamed)

```bash
# Verify Production DevOps subnet
gcloud compute networks subnets describe pcc-prj-devops-prod \
  --region=us-east4 \
  --project=pcc-prj-net-shared \
  --format=json | jq '{name, ipCidrRange, secondaryIpRanges, privateIpGoogleAccess}'
```

**Expected Output**:
```json
{
  "name": "pcc-prj-devops-prod",
  "ipCidrRange": "10.16.128.0/20",
  "secondaryIpRanges": [
    {
      "rangeName": "pcc-prj-devops-prod-sub-pod",
      "ipCidrRange": "10.16.144.0/20"
    },
    {
      "rangeName": "pcc-prj-devops-prod-sub-svc",
      "ipCidrRange": "10.16.160.0/20"
    }
  ],
  "privateIpGoogleAccess": true
}
```

```bash
# Verify NonProduction DevOps subnet
gcloud compute networks subnets describe pcc-prj-devops-nonprod \
  --region=us-east4 \
  --project=pcc-prj-net-shared \
  --format=json | jq '{name, ipCidrRange, secondaryIpRanges}'
```

**Validation Checklist**:
- [ ] Name: `pcc-prj-devops-prod` (not `pcc-subnet-prod-use4`)
- [ ] Name: `pcc-prj-devops-nonprod` (not `pcc-subnet-nonprod-use4`)
- [ ] CIDR ranges unchanged
- [ ] Secondary range names updated (pods, services)
- [ ] Private Google Access enabled

---

### Step 6: Verify App Devtest Subnet (New)

```bash
gcloud compute networks subnets describe pcc-prj-app-devtest \
  --region=us-east4 \
  --project=pcc-prj-net-shared \
  --format=json | jq '{name, ipCidrRange, secondaryIpRanges, privateIpGoogleAccess, enableFlowLogs}'
```

**Validation Checklist**:
- [ ] Name: `pcc-prj-app-devtest`
- [ ] CIDR: `10.28.0.0/20`
- [ ] Secondary range (pods): `pcc-prj-app-devtest-sub-pod` (10.28.16.0/20)
- [ ] Secondary range (services): `pcc-prj-app-devtest-sub-svc` (10.28.32.0/20)
- [ ] Private Google Access: `true`
- [ ] Flow logs: enabled

---

### Step 7: Verify App Devtest Overflow Subnet (New)

```bash
gcloud compute networks subnets describe pcc-prj-app-devtest-overflow \
  --region=us-east4 \
  --project=pcc-prj-net-shared \
  --format=json | jq '{name, ipCidrRange, privateIpGoogleAccess, enableFlowLogs}'
```

**Validation Checklist**:
- [ ] Name: `pcc-prj-app-devtest-overflow`
- [ ] CIDR: `10.28.48.0/20`
- [ ] Private Google Access: `true`
- [ ] Flow logs: enabled
- [ ] No secondary ranges (overflow is for PSC endpoints, not GKE)

---

### Step 8: Verify Terraform State

```bash
# List all subnet resources in state
terraform state list | grep google_compute_subnetwork

# Show details of each subnet
terraform show | grep -A 15 "resource \"google_compute_subnetwork\""
```

**Expected State**:
- 4 subnet resources in state
- All with correct names and CIDRs
- No orphaned resources

---

### Step 9: Validate Network Connectivity

```bash
# Check VPC peering status (should be unchanged)
gcloud compute networks peerings list \
  --project=pcc-prj-net-shared

# Verify firewall rules still apply
gcloud compute firewall-rules list \
  --project=pcc-prj-net-shared \
  --filter="network:pcc-vpc-nonprod" \
  --format="table(name,sourceRanges,allowed[])"
```

**Validation**:
- [ ] VPC peering unchanged
- [ ] Firewall rules still active
- [ ] No broken network references

---

### Step 10: Git Commit

```bash
git add terraform/
git commit -m "feat: update network infrastructure for devtest

Network changes:
- Renamed DevOps subnets to match PDF naming convention
  - pcc-subnet-prod-use4 → pcc-prj-devops-prod
  - pcc-subnet-nonprod-use4 → pcc-prj-devops-nonprod
  - Updated secondary range names (pods, services)

- Created App Devtest subnet (10.28.0.0/20)
  - Primary: pcc-prj-app-devtest
  - Secondary ranges for GKE pods and services
  - Flow logs and Private Google Access enabled

- Created App Devtest overflow subnet (10.28.48.0/20)
  - Name: pcc-prj-app-devtest-overflow
  - Purpose: PSC endpoints and expansion
  - Flow logs and Private Google Access enabled

Phase 1 complete. Ready for Phase 2 (AlloyDB + PSC endpoint deployment)."

git push origin main
```

---

## Success Criteria

### Infrastructure State
- [ ] 2 DevOps subnets renamed successfully
- [ ] 2 new subnets created (App Devtest main + Overflow)
- [ ] Terraform state updated successfully
- [ ] No errors during apply
- [ ] All validation checks passed

### Validation Commands Pass
```bash
# All 4 subnets exist
gcloud compute networks subnets list --filter="region:us-east4" --project=pcc-prj-net-shared

# DevOps subnets have new names
gcloud compute networks subnets describe pcc-prj-devops-prod --region=us-east4 --project=pcc-prj-net-shared
gcloud compute networks subnets describe pcc-prj-devops-nonprod --region=us-east4 --project=pcc-prj-net-shared

# App Devtest subnet exists
gcloud compute networks subnets describe pcc-prj-app-devtest --region=us-east4 --project=pcc-prj-net-shared

# Overflow subnet exists
gcloud compute networks subnets describe pcc-prj-app-devtest-overflow --region=us-east4 --project=pcc-prj-net-shared
```

---

## Testing Limitations (Phase 1)

### Cannot Test Yet

❌ **PSC Connectivity**: Cannot verify PSC functionality until AlloyDB cluster + PSC endpoint created (Phase 2)

❌ **GKE Cluster**: Cannot test secondary ranges until GKE cluster deployed (Phase 5)

❌ **Application Connectivity**: No workloads to test subnet isolation yet

### Can Validate Now

✅ **Subnets Exist**: All 4 subnets created in GCP

✅ **Naming Convention**: Matches PDF standard

✅ **CIDR Allocations**: Match PDF exactly

✅ **Configuration**: Flow logs and Private Google Access enabled

✅ **Terraform State**: Resources tracked correctly

---

## Phase 2 Readiness

**AlloyDB Deployment + PSC Endpoint** (Phase 2) can now proceed with:

1. **Overflow Subnet**: `pcc-prj-app-devtest-overflow` (10.28.48.0/20)
   - Phase 2 will create PSC endpoint at 10.28.48.10 in this subnet
   - Subnet provides network space for PSC connectivity

2. **Network Context**: `pcc-prj-app-devtest` subnet (10.28.0.0/20)
   - GKE workloads will connect to AlloyDB from this subnet via PSC
   - Firewall rules can reference these ranges

3. **VPC**: NonProduction VPC in `pcc-prj-net-shared`
   - Shared VPC ready for multi-project access

---

## Troubleshooting (if needed)

### Issue: "Subnet already exists"
- Check if old subnet names still exist
- Verify terraform state matches reality
- May need to import existing subnets

### Issue: "IP range already allocated"
- Verify 10.28.0.0/20 through 10.28.48.0/20 are not in use
- Review GCP Console for hidden allocations

### Issue: "Replacement failed - resource in use"
- Identify what's using the DevOps subnets
- If VMs/GKE exist: **DO NOT PROCEED** (requires migration)
- If nothing exists: Force refresh and retry

---

## Rollback (if needed)

**Complete Rollback**:
```bash
# Step 1: Remove new resources from state
terraform state rm google_compute_subnetwork.app_devtest_use4
terraform state rm google_compute_subnetwork.app_devtest_overflow_use4

# Step 2: Delete new subnets from GCP
gcloud compute networks subnets delete pcc-prj-app-devtest --region=us-east4 --project=pcc-prj-net-shared --quiet
gcloud compute networks subnets delete pcc-prj-app-devtest-overflow --region=us-east4 --project=pcc-prj-net-shared --quiet

# Step 3: Verify rollback
terraform plan  # Should show 4 to add (new subnets removed)
```

**Note**:
- DevOps subnet renames harder to rollback (requires another replacement)
- State versioning in GCS allows recovery if needed: `gsutil ls -a gs://bucket/path/to/terraform.tfstate`

---

## Post-Implementation Actions

### Documentation Updates
- [ ] Update `.claude/status/brief.md` (Phase 1 complete)
- [ ] Update `.claude/status/current-progress.md` (log implementation)
- [ ] Update `core/pcc-foundation-infra/.claude/status/brief.md` (network updates)

### What's Next
- **Phase 2**: AlloyDB cluster + PSC endpoint deployment (will use overflow subnet at 10.28.48.10)
- **Phase 5**: GKE cluster deployment (will use App Devtest subnet secondary ranges)
- **Phase 2**: Test PSC connectivity between GKE and AlloyDB

---

## Deliverables

- [ ] Terraform apply executed successfully
- [ ] 2 DevOps subnets renamed (match PDF)
- [ ] App Devtest subnet created (10.28.0.0/20)
- [ ] App Devtest overflow subnet created (10.28.48.0/20)
- [ ] Post-deployment validation passed
- [ ] Terraform state updated
- [ ] Git commit pushed to main
- [ ] Documentation updated
- [ ] Phase 1 complete

---

## References

- Phase 1.1 (DevOps subnet naming)
- Phase 1.2 (App Devtest subnet creation)
- Phase 1.3 (validation)
- GCP_Network_Subnets.pdf (CIDR allocations)

---

## Notes

- **WARP Assistance**: Use WARP AI for real-time troubleshooting if issues arise
- **Deployment Time**: Typically 2-3 minutes (subnet operations are fast)
- **Replacement Safety**: DevOps subnets safe to replace (no dependencies yet)
- **Testing Limitation**: Cannot verify PSC until AlloyDB + PSC endpoint created (Phase 2)
- **Phase 2 Dependency**: AlloyDB cluster will create PSC endpoint in overflow subnet (10.28.48.10)
- **GKE Dependency**: Future GKE cluster will use secondary ranges from App Devtest subnet

---

**Next Phase**: 2.1 - Plan AlloyDB Cluster Configuration
