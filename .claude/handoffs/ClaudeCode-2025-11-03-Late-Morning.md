# Handoff: AlloyDB IAM Authentication & WireGuard VPN Fix

**Date**: 2025-11-03
**Time**: 10:51 EST (Late Morning session)
**Tool**: Claude Code
**Duration**: ~30 minutes
**Status**: ✅ Complete - Ready for Testing

---

## Project Overview

**Project**: PortCo Connect (PCC) Infrastructure
**Component**: Two critical fixes for Phase 2 deployment
**Objective**:
1. Fix AlloyDB IAM authentication Terraform count issue
2. Remove Network Load Balancer from WireGuard VPN (assign static IP directly to instance)

**Context**: Continuation of Nov 3 morning session. User encountered Terraform plan error where `count` depended on computed value from `random_password` resource. Additionally, discovered NLB doesn't work with WireGuard UDP protocol.

---

## Current State

### ✅ Completed Tasks

#### 1. **AlloyDB Module Terraform Count Fix** (pcc-tf-library)
**Problem**: Terraform plan failed because `count = var.postgres_password != null ? 1 : 0` depended on computed value from `random_password.postgres_password.result`

**Root Cause**: Terraform cannot evaluate null checks on computed values during plan phase

**Solution Implemented**:
- Replaced null check with explicit boolean flag `enable_postgres_user`
- Modified `modules/alloydb-cluster/users.tf`:
  - Line 12: Changed to `count = var.enable_postgres_user ? 1 : 0`
- Modified `modules/alloydb-cluster/variables.tf`:
  - Added `enable_postgres_user` variable (default: true) after `postgres_password`
- Modified `pcc-app-shared-infra/terraform/environments/devtest/alloydb.tf`:
  - Line 61: Added `enable_postgres_user = true` parameter

**Git Actions**:
- Committed to pcc-tf-library: `fix(alloydb-cluster): replace computed count with explicit boolean flag`
- Commit hash: `3ded83b`
- Force-updated tag v0.1.0 to include fix
- Pushed to remote repository

#### 2. **WireGuard VPN NLB Removal** (pcc-devops-infra)
**Problem**: Network Load Balancer doesn't work properly with WireGuard UDP protocol

**Solution Implemented**:
- Removed NLB module entirely from `wireguard-vpn.tf`
- Assigned static external IP directly to VM instance
- Modified `terraform/environments/nonprod/wireguard-vpn.tf`:
  - Lines 1-15: Updated architecture comment (removed NLB reference)
  - Lines 190-193: Added static IP assignment to instance template:
    - `enable_external_ip = true`
    - `nat_ip = module.wireguard_ip.address`
    - `network_tier = "STANDARD"`
  - Lines 230-246: Deleted entire `module "wireguard_nlb"` block

**Architecture Change**:
- **Before**: Internet → Static IP → NLB (UDP/51820) → MIG Instance (no external IP) → WireGuard
- **After**: Internet → Static IP (assigned to instance) → MIG Instance → WireGuard

**Benefits**:
- Simpler architecture (fewer resources)
- Direct connection (no NAT translation, better for UDP)
- Cost savings (~$18/month from NLB removal)
- Easier troubleshooting

**Status**: Changes applied, not yet committed or deployed

---

## Key Decisions

### 1. AlloyDB Count Fix: Boolean Flag Instead of Computed Null Check
**Decision**: Use explicit `enable_postgres_user` boolean variable
**Rationale**:
- Separates "should we create?" decision (plan time) from password value (apply time)
- Follows Terraform best practices for conditional resources
- Backwards compatible (default = true)
- Prevents future issues with computed values in count

### 2. WireGuard VPN: Direct IP Assignment Instead of NLB
**Decision**: Remove NLB, assign static IP directly to VM instance
**Rationale**:
- NLB doesn't work properly with WireGuard UDP protocol
- Direct IP assignment is simpler and more reliable
- Reduces infrastructure complexity
- Eliminates NAT translation issues
- Cost optimization benefit

### 3. AlloyDB Fix Tag Version: v0.1.0 (Force Push)
**Decision**: Force-push v0.1.0 tag instead of creating v0.1.1
**Rationale**:
- User explicitly requested "please push it as 0.1.0"
- Consolidates bootstrap implementation and count fix into single version
- Avoids version fragmentation during initial module development

---

## Pending Tasks

### Immediate (User/Christine)

#### 1. **Test AlloyDB Terraform Fix**
```bash
cd $HOME/pcc/infra/pcc-app-shared-infra/terraform/environments/devtest
terraform init -upgrade  # Pull updated v0.1.0 module
terraform plan           # Should succeed now (no computed count error)
terraform apply          # Deploy if plan looks good
```
**Expected**: Plan should show ~6-8 resources to add (IAM bindings, secrets, postgres user)

#### 2. **Commit WireGuard VPN Changes**
```bash
cd $HOME/pcc/infra/pcc-devops-infra/terraform/environments/nonprod
git add wireguard-vpn.tf
git commit -m "fix(wireguard): remove NLB and assign static IP directly to instance"
git push origin main
```

#### 3. **Deploy WireGuard VPN Updates**
```bash
cd $HOME/pcc/infra/pcc-devops-infra/terraform/environments/nonprod
terraform plan   # Review changes (will destroy NLB, update instance template)
terraform apply  # Deploy when ready
```
**Expected Resources**:
- Destroy: wireguard_nlb module resources (backend service, forwarding rule)
- Update: wireguard_instance_template with external IP configuration
- MIG will recreate instance with new template

#### 4. **Execute AlloyDB IAM Bootstrap Process**
- Follow guide: `$HOME/pcc/infra/pcc-app-shared-infra/docs/alloydb-iam-bootstrap.md`
- Connect as postgres user via PSC endpoint (10.24.128.3)
- Create PostgreSQL users for each developer
- Grant database permissions via GRANT statements
- Test IAM authentication

#### 5. **Execute Flyway Migrations** (Phase 2.11)
- Start AlloyDB Auth Proxy locally
- Run Flyway migrations via PSC connection
- Verify 15 tables created in `client_api_db`
- Complete Phase 2.11 validation checklist

### Future Tasks

- Add more developers: Repeat bootstrap steps for each new user
- Password rotation: Increment `postgres_password_version` when needed
- Monitor IAM group membership via Google Workspace Admin
- Phase 3: GKE DevOps Cluster deployment
- Phase 6: ArgoCD deployment

---

## Blockers or Challenges

### ✅ Resolved Blockers

1. **Terraform Count with Computed Values** (resolved)
   - ✅ Fixed with explicit boolean flag
   - ✅ Module updated and tagged v0.1.0
   - ✅ Ready for deployment

2. **WireGuard NLB Incompatibility** (resolved)
   - ✅ NLB removed from configuration
   - ✅ Static IP assigned directly to instance
   - ✅ Changes applied, ready for commit

### No Current Blockers

All infrastructure is configured and ready for deployment. No technical blockers remain.

---

## Next Steps

### Recommended Order

1. **Test AlloyDB fix** (terraform init -upgrade && terraform plan in app-shared-infra)
2. **Commit WireGuard changes** (git commit in pcc-devops-infra)
3. **Deploy AlloyDB updates** (terraform apply in app-shared-infra/devtest)
4. **Deploy WireGuard updates** (terraform apply in devops-infra/nonprod)
5. **Run bootstrap process** (Christine creates PostgreSQL users)
6. **Test IAM authentication** (verify end-to-end connectivity)
7. **Execute Flyway migrations** (Phase 2.11)

### High Priority

- **AlloyDB deployment** - Blocks all database access testing
- **WireGuard deployment** - Blocks VPN connectivity testing
- **Bootstrap execution** - Blocks IAM authentication testing

### Normal Priority

- Flyway migrations (creates database schema)
- Phase 3 GKE cluster deployment
- Phase 6 ArgoCD deployment

---

## Technical Reference

### File Locations (All Paths Portable)

**AlloyDB Module** (pcc-tf-library):
- `$HOME/pcc/core/pcc-tf-library/modules/alloydb-cluster/users.tf`
- `$HOME/pcc/core/pcc-tf-library/modules/alloydb-cluster/variables.tf`

**App Infrastructure** (pcc-app-shared-infra):
- `$HOME/pcc/infra/pcc-app-shared-infra/terraform/environments/devtest/alloydb.tf`

**DevOps Infrastructure** (pcc-devops-infra):
- `$HOME/pcc/infra/pcc-devops-infra/terraform/environments/nonprod/wireguard-vpn.tf`

**Documentation**:
- Bootstrap guide: `$HOME/pcc/infra/pcc-app-shared-infra/docs/alloydb-iam-bootstrap.md`
- Phase 2.11 plan: `$HOME/pcc/.claude/plans/devtest-deployment/phase-2.11-execute-flyway-migrations.md`

### Git Commits

**pcc-tf-library**:
- Commit: `fix(alloydb-cluster): replace computed count with explicit boolean flag`
- Commit hash: `3ded83b`
- Tag: v0.1.0 (force-pushed to include fix)

**pcc-devops-infra**:
- Changes applied but NOT committed yet
- Recommended commit: `fix(wireguard): remove NLB and assign static IP directly to instance`

### Code Changes Summary

#### AlloyDB Module Fix
```hcl
# Before (BROKEN):
count = var.postgres_password != null ? 1 : 0

# After (FIXED):
count = var.enable_postgres_user ? 1 : 0

# New variable added:
variable "enable_postgres_user" {
  description = "Enable built-in postgres superuser (password must be provided if true)"
  type        = bool
  default     = true
}

# Usage in app-shared-infra:
enable_postgres_user = true
postgres_password    = random_password.postgres_password.result
```

#### WireGuard VPN Fix
```hcl
# Instance template changes:
module "wireguard_instance_template" {
  # ... existing config ...

  # NEW: Assign static external IP directly to instance
  enable_external_ip = true
  nat_ip             = module.wireguard_ip.address
  network_tier       = "STANDARD"

  # ... existing config ...
}

# REMOVED: Entire NLB module (lines 230-246)
```

---

## Key Learnings

### 1. Terraform Count Limitations with Computed Values
**Problem**: Cannot use computed values (like `random_password.result`) in count conditions
**Solution**: Separate decision logic (boolean flag) from value computation
**Best Practice**: Use explicit boolean flags for conditional resource creation when depending on computed values

### 2. WireGuard UDP Protocol Requirements
**Problem**: Network Load Balancers don't work well with WireGuard's UDP protocol
**Solution**: Direct IP assignment to instances provides better reliability
**Best Practice**: For UDP-based VPN protocols, prefer direct IP assignment over load balancers

### 3. Terraform Module Versioning During Development
**Approach**: Force-push tags during initial development to consolidate related changes
**Rationale**: v0.1.0 includes both bootstrap implementation and count fix
**Future**: Use semantic versioning (v0.1.1, v0.2.0) once module stabilizes

---

## Infrastructure Summary

### AlloyDB Configuration (environments/devtest/)
- Backend: GCS `pcc-terraform-state`, prefix `app-shared-infra/devtest`
- Project: `pcc-prj-app-devtest`
- Connectivity: Private Service Connect (PSC) - NO VPC peering
- Configuration: ZONAL, db-standard-2, 7-day PITR, no read replica
- Cost: ~$400/month

### WireGuard VPN Configuration (environments/nonprod/)
- Backend: GCS `pcc-terraform-state`, prefix `devops-infra/nonprod`
- Project: `pcc-prj-devops-nonprod`
- Architecture: MIG with target_size=1, static IP on instance
- Machine: e2-small Debian 11
- Port: UDP 51820
- Cost: ~$15/month (after removing NLB)

---

## Contact Information

**Session Lead**: Claude Code (AI Assistant)
**Handoff Recipient**: Christine Fogarty / User
**Project**: PortCo Connect Infrastructure
**Repositories**:
- github-pcc:PORTCoCONNECT/pcc-tf-library (AlloyDB module)
- github-pcc:PORTCoCONNECT/pcc-app-shared-infra (AlloyDB infrastructure)
- github-pcc:PORTCoCONNECT/pcc-devops-infra (WireGuard VPN)

**For Questions**:
- AlloyDB fix: Review this handoff and test terraform plan
- WireGuard changes: Review wireguard-vpn.tf diff before committing
- Bootstrap process: Refer to `docs/alloydb-iam-bootstrap.md`
- Technical context: Review morning handoff `ClaudeCode-2025-11-03-Morning.md`

---

**Session End**: 2025-11-03 10:51 EST
**Status**: ✅ All fixes complete, ready for testing and deployment
**Next Session**: User tests AlloyDB fix, commits WireGuard changes, then deploys both
