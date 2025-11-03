# Phase 3.3: Create GKE Module - versions.tf

**Phase**: 3.3 (GKE Infrastructure - Module Foundation)
**Duration**: 5 minutes
**Type**: Implementation
**Status**: Ready for Execution

---

## Execution Tool

**Use Claude Code for this phase** - Creating terraform module file.

---

## Objective

Create `versions.tf` file for GKE Autopilot module with terraform and provider version constraints.

## Prerequisites

✅ Phase 3.2 completed (APIs enabled and propagated)
✅ `pcc-tf-library` repository cloned
✅ Access to create new module directory

---

## Step 1: Create Module Directory

```bash
cd ~/pcc/core/pcc-tf-library
mkdir -p modules/gke-autopilot
cd modules/gke-autopilot
```

---

## Step 2: Create versions.tf

**File**: `pcc-tf-library/modules/gke-autopilot/versions.tf`

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
```

**Version Rationale**:
- **Terraform >= 1.5.0**: Supports new GKE Autopilot features
- **Google provider ~> 5.0**: Includes `google_container_cluster` autopilot mode
- **Flexible minor versions**: Allows 5.x updates (5.1, 5.2, etc.) for bug fixes
- **Major version pinning**: Prevents breaking changes from 6.0

---

## Validation Checklist

- [ ] Directory created: `modules/gke-autopilot/`
- [ ] File created: `versions.tf`
- [ ] Terraform version >= 1.5.0
- [ ] Google provider ~> 5.0
- [ ] 2-space indentation
- [ ] No syntax errors

---

## File Content

**Lines of Code**: 10
**Format**: HCL

---

## Next Phase Dependencies

**Phase 3.4** will create `variables.tf` with:
- Cluster configuration inputs
- Networking parameters
- Workload Identity settings
- Connect Gateway flags

---

## References

- **Terraform Versions**: https://developer.hashicorp.com/terraform/language/expressions/version-constraints
- **Google Provider**: https://registry.terraform.io/providers/hashicorp/google/latest

---

## Time Estimate

- **Create directory**: 1 minute
- **Create versions.tf**: 2 minutes
- **Validate**: 2 minutes
- **Total**: 5 minutes

---

**Status**: Ready for execution
**Next**: Phase 3.4 - Create GKE Module (variables.tf)
