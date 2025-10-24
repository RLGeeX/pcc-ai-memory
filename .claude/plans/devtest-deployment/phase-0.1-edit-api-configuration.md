# Phase 0.1: Edit API Configuration

**Phase**: 0.1 (Foundation Prerequisites - Configuration)
**Duration**: 5-8 minutes
**Type**: Implementation
**Status**: Ready for Execution

---

## Execution Tool

**Use Claude Code for this phase** - File editing only, no CLI commands.

---

## Objective

Edit `pcc-foundation-infra/terraform/main.tf` to add required GCP APIs for Phase 2 (AlloyDB + Secret Manager), Phase 3 (GKE), and Phase 4 (ArgoCD).

## Prerequisites

✅ Phase 1 completed (network subnets deployed)
✅ `pcc-foundation-infra` repository available
✅ Terraform state intact after destroy
✅ Access to edit `main.tf`

---

## APIs to Add

### Phase 2 Prerequisite (AlloyDB + Secret Manager)

**Target Project**: `pcc-prj-app-devtest`

**Add**:
- `secretmanager.googleapis.com` - Store AlloyDB credentials

---

### Phase 4 Prerequisite (ArgoCD GKE Integration)

**Target Projects**: `pcc-prj-devops-nonprod`, `pcc-prj-devops-prod`

**Add**:
- `gkehub.googleapis.com` - GKE Hub for fleet management
- `connectgateway.googleapis.com` - Connect Gateway for ArgoCD access

---

## Implementation Steps

### Step 1: Edit App Devtest Project

**File**: `pcc-foundation-infra/terraform/main.tf`

**Location**: Around line 90-99

**Current**:
```hcl
"pcc-prj-app-devtest" = {
  name       = "pcc-prj-app-devtest"
  folder_key = "app"
  apis = [
    "alloydb.googleapis.com",
    "compute.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com"
  ]
  shared_vpc = "nonprod"
}
```

**Updated** (add secretmanager, alphabetize):
```hcl
"pcc-prj-app-devtest" = {
  name       = "pcc-prj-app-devtest"
  folder_key = "app"
  apis = [
    "alloydb.googleapis.com",
    "compute.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "secretmanager.googleapis.com"  # ADD THIS LINE
  ]
  shared_vpc = "nonprod"
}
```

---

### Step 2: Edit DevOps NonProd Project

**File**: `pcc-foundation-infra/terraform/main.tf`

**Location**: Around line 45-53

**Current**:
```hcl
"pcc-prj-devops-nonprod" = {
  name       = "pcc-prj-devops-nonprod"
  folder_key = "devops"
  apis = [
    "container.googleapis.com",
    "cloudbuild.googleapis.com",
    "artifactregistry.googleapis.com"
  ]
  shared_vpc = "nonprod"
}
```

**Updated** (add gkehub and connectgateway, alphabetize):
```hcl
"pcc-prj-devops-nonprod" = {
  name       = "pcc-prj-devops-nonprod"
  folder_key = "devops"
  apis = [
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "connectgateway.googleapis.com",  # ADD THIS LINE
    "container.googleapis.com",
    "gkehub.googleapis.com"           # ADD THIS LINE
  ]
  shared_vpc = "nonprod"
}
```

---

### Step 3: Edit DevOps Prod Project

**File**: `pcc-foundation-infra/terraform/main.tf`

**Location**: Around line 56-65

**Current**:
```hcl
"pcc-prj-devops-prod" = {
  name       = "pcc-prj-devops-prod"
  folder_key = "devops"
  apis = [
    "container.googleapis.com",
    "cloudbuild.googleapis.com",
    "artifactregistry.googleapis.com",
    "storage.googleapis.com"
  ]
  shared_vpc = "prod"
}
```

**Updated** (add gkehub and connectgateway, alphabetize):
```hcl
"pcc-prj-devops-prod" = {
  name       = "pcc-prj-devops-prod"
  folder_key = "devops"
  apis = [
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "connectgateway.googleapis.com",  # ADD THIS LINE
    "container.googleapis.com",
    "gkehub.googleapis.com",          # ADD THIS LINE
    "storage.googleapis.com"
  ]
  shared_vpc = "prod"
}
```

---

## Validation Checklist

- [ ] `secretmanager.googleapis.com` added to pcc-prj-app-devtest
- [ ] `gkehub.googleapis.com` added to pcc-prj-devops-nonprod
- [ ] `connectgateway.googleapis.com` added to pcc-prj-devops-nonprod
- [ ] `gkehub.googleapis.com` added to pcc-prj-devops-prod
- [ ] `connectgateway.googleapis.com` added to pcc-prj-devops-prod
- [ ] All APIs alphabetically sorted within each project
- [ ] No syntax errors (commas, brackets)

---

## Why These APIs?

### secretmanager.googleapis.com
**Phase 2 Dependency**: AlloyDB requires credentials stored securely
- Database password for AlloyDB cluster
- Connection strings for applications
- Automatic encryption at rest, audit logging

**Alternative Considered**: Environment variables (rejected - not secure for production)

---

### gkehub.googleapis.com
**Phase 4 Dependency**: ArgoCD requires GKE Hub for fleet management
- Registers GKE clusters with centralized hub
- Enables cross-cluster visibility
- Required for Connect Gateway authentication

**Use Case**: ArgoCD in `pcc-prj-devops-prod` manages applications across multiple clusters

---

### connectgateway.googleapis.com
**Phase 4 Dependency**: ArgoCD uses Connect Gateway for secure kubectl access
- Provides authenticated API access without direct cluster credentials
- Integrates with Google SSO (developers, devops groups)
- Required for ArgoCD to deploy to remote clusters

**Security Benefit**: No long-lived cluster certificates or tokens needed

---

## Next Phase

**Phase 0.2**: Deploy API changes using WARP (terraform commands)

---

## Time Estimate

- **Edit pcc-prj-app-devtest**: 2 minutes
- **Edit pcc-prj-devops-nonprod**: 2 minutes
- **Edit pcc-prj-devops-prod**: 2 minutes
- **Review/validate**: 1-2 minutes
- **Total**: 5-8 minutes

---

**Status**: Ready for execution
**Tool**: Claude Code (file editing only)
**Next**: Phase 0.2 - Deploy API Changes (WARP)
