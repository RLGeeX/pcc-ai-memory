# WireGuard VPN Terraform Deployment Plan

**Project**: PortCo Connect DevOps NonProd
**Purpose**: Deploy WireGuard VPN for secure access to private AlloyDB and GKE
**Architecture**: Modular Terraform with granular, reusable modules
**Status**: Planning phase - modules need to be created

---

## Overview

This plan deploys a WireGuard VPN infrastructure using **granular Terraform modules** that can be composed in environment configurations. Unlike the previous over-engineered approach, this follows the established GKE modular deployment style.

**Source Design**: `@pcc-ai-memory/.claude/plans/2025-10-30-alloydb-vpn-access-design.md` (validated, 70KB)

---

## Architecture Summary

```
Developer Laptops (3)
    ↓ WireGuard tunnel
GCE VM (MIG, e2-small, us-east4)
    ↓ VPC routing
AlloyDB (10.24.128.0/20) + GKE (future)
```

**Key Features**:
- MIG for auto-healing (~99.5% uptime)
- Split-tunnel (only AlloyDB/GKE traffic via VPN)
- Cost: ~$7/month per environment
- 3 environments planned: nonprod us-east4, prod us-east4, prod us-central1

---

## Phase Structure

### Phase 1: Create Terraform Modules (CC)

Create 7 granular, reusable modules in `core/pcc-tf-library/modules/`:

1. **phase-1.1-create-service-account-module.md** ✅ CREATED
   - `service-account/` module
   - Handles SA creation + project-level IAM bindings
   - **Duration**: 15-20 minutes

2. **phase-1.2-create-mig-module.md** (TO CREATE)
   - `mig/` module
   - Managed Instance Group for auto-healing
   - **Duration**: 25-30 minutes

3. **phase-1.3-create-static-ip-module.md** (TO CREATE)
   - `static-ip/` module
   - Reserved external IP addresses
   - **Duration**: 15-20 minutes

4. **phase-1.4-create-firewall-rule-module.md** (TO CREATE)
   - `firewall-rule/` module
   - VPC firewall rules (ingress/egress)
   - **Duration**: 20-25 minutes

5. **phase-1.5-create-health-check-module.md** (TO CREATE)
   - `health-check/` module
   - TCP/HTTP/HTTPS health checks for MIG
   - **Duration**: 15-20 minutes

6. **phase-1.6-create-load-balancer-module.md** (TO CREATE)
   - `load-balancer/` or `network-load-balancer/` module
   - Network load balancer for static IP + forwarding
   - **Duration**: 30-35 minutes

7. **phase-1.7-create-psc-consumer-module.md** (TO CREATE)
   - `psc-consumer/` module
   - Modularize existing PSC endpoint pattern
   - **Duration**: 20-25 minutes

**Total Phase 1**: ~2.5-3 hours

---

### Phase 2: Create Environment Configuration (CC)

8. **phase-2.1-create-wireguard-vpn-terraform.md** (TO CREATE)
   - Create `wireguard-vpn.tf` in `infra/pcc-devops-infra/terraform/environments/nonprod/`
   - Composes the 7 modules created in Phase 1
   - Includes startup script (from design document)
   - **Duration**: 45-60 minutes

**Total Phase 2**: ~1 hour

---

### Phase 3: Deploy and Configure (WARP)

9. **phase-3.1-terraform-deploy.md** (TO CREATE)
   - Run `terraform init`, `plan`, `apply` in nonprod environment
   - Verify resources created
   - **Duration**: 20-30 minutes (mostly waiting for GCP)

10. **phase-3.2-generate-client-configs.md** (TO CREATE)
    - Generate 3 WireGuard client configs
    - Store in Secret Manager
    - Distribute securely to developers
    - **Duration**: 15-20 minutes

11. **phase-3.3-test-connectivity.md** (TO CREATE)
    - Test VPN connection from each developer laptop
    - Verify AlloyDB connectivity via PSC endpoint
    - Validate split-tunnel routing
    - **Duration**: 20-30 minutes

**Total Phase 3**: ~1 hour

---

## Existing Modules

The following modules **already exist** in `pcc-tf-library/modules/`:

- ✅ `alloydb-cluster/` - AlloyDB management
- ✅ `secret-manager/` - Secret storage (so no need to create this!)

---

## Deployment Paths

### Modules Location
`/home/jfogarty/pcc/core/pcc-tf-library/modules/`

### Environment Config Location
`/home/jfogarty/pcc/infra/pcc-devops-infra/terraform/environments/nonprod/`

### Pattern
- **CC** creates `.tf` files (modules + environment config)
- **WARP** runs `terraform` and `gcloud` commands

---

## Key Differences from Previous Plan

### What Changed:
1. **Granular modules** instead of monolithic `wireguard-vpn` module
2. **Reusable components** (mig, load-balancer, firewall-rule can be used elsewhere)
3. **Simpler plan structure** (~11 phases instead of 15+)
4. **Clear tool separation**: CC writes files, WARP runs commands

### What Stayed:
- Validated design document as source of truth
- Target: nonprod us-east4 first, then prod environments
- 3 developers, 3 separate WireGuard configs
- Split-tunnel for AlloyDB (10.24.128.0/20) + GKE (10.66.0.0/24)

---

## Next Steps

1. Complete Phase 1 module creation plans (1.2-1.7)
2. Create Phase 2 environment config plan
3. Create Phase 3 deployment plans
4. Review with partner before execution

---

## Design Document Reference

**Location**: `/home/jfogarty/pcc/pcc-ai-memory/.claude/plans/2025-10-30-alloydb-vpn-access-design.md`

**Key Sections**:
- Startup Script: Lines 1158-1287
- Service Account IAM: Lines 1156-1189
- Network Architecture: Lines 800-950
- Expert Review Fixes: Lines 1765-1995

**Status**: Validated by expert agents, 7 critical issues fixed

---

**Total Time Estimate**: 4.5-5 hours (broken into manageable phases)
**Created**: 2025-10-31
**Status**: In progress - Phase 1.1 complete
