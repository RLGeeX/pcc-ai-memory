# pcc-foundation-infra Terraform Updates for Apigee Projects

**Date**: 2025-10-17
**Purpose**: Add 2 new Apigee projects to existing foundation infrastructure

## Context

Following the architectural decision in [ADR 001](.//ADR/001-two-org-apigee-architecture.md), we need to create 2 new GCP projects in the existing `pcc-foundation-infra` repository to host Apigee X organizations:

- `pcc-prj-apigee-nonprod` (hosts nonprod Apigee org with devtest + dev environments)
- `pcc-prj-apigee-prod` (hosts prod Apigee org with staging + prod environments)

## Rationale for Placement

**Why `pcc-fldr-si` (Shared Infrastructure)?**
- Apigee is platform-level shared infrastructure (not app-specific)
- Serves all backend microservices (API gateway/facade pattern)
- Managed by platform team, consumed by app teams
- Consistent with existing shared services (networking, logging, devops)
- Gemini 2.5 Pro + OpenAI Codex consensus recommendation

**Why dedicated projects (not in existing devops/sys projects)?**
- Clean IAM boundaries (Apigee admin vs. CI/CD admin)
- Isolated quotas (Apigee runtime vs. Cloud Build)
- Cost transparency (dedicated billing for API platform)
- Clear blast radius (Apigee incidents don't affect CI/CD)
- Hub-and-spoke network pattern (Apigee hub, app spokes)

## Terraform Changes Required

### File: `pcc-foundation-infra/terraform/main.tf`

Add 2 new projects to the `locals.projects` map:

```hcl
locals {
  # ... existing projects ...

  projects = {
    # Existing projects (15 total)
    "pcc-prj-logging-monitoring" = { ... }
    "pcc-prj-network-nonprod" = { ... }
    "pcc-prj-network-prod" = { ... }
    # ... other existing projects ...

    # NEW: Apigee Projects (2 total)
    "pcc-prj-apigee-nonprod" = {
      name       = "pcc-prj-apigee-nonprod"
      folder_key = "si"  # Under pcc-fldr-si (Shared Infrastructure)
      apis = [
        "apigee.googleapis.com",              # Apigee API Management
        "apigeeconnect.googleapis.com",       # Apigee Connect (hybrid)
        "compute.googleapis.com",             # Compute Engine (Apigee runtime instances)
        "servicenetworking.googleapis.com",   # Service Networking (VPC peering)
        "dns.googleapis.com",                 # Cloud DNS (for environment groups)
        "certificatemanager.googleapis.com",  # Certificate Manager (TLS certs)
        "cloudresourcemanager.googleapis.com",
        "logging.googleapis.com",
        "monitoring.googleapis.com",
        "iam.googleapis.com"
      ]
      labels = {
        environment = "nonprod"
        service     = "apigee"
        managed_by  = "terraform"
      }
    }

    "pcc-prj-apigee-prod" = {
      name       = "pcc-prj-apigee-prod"
      folder_key = "si"  # Under pcc-fldr-si (Shared Infrastructure)
      apis = [
        "apigee.googleapis.com",
        "apigeeconnect.googleapis.com",
        "compute.googleapis.com",
        "servicenetworking.googleapis.com",
        "dns.googleapis.com",
        "certificatemanager.googleapis.com",
        "cloudresourcemanager.googleapis.com",
        "logging.googleapis.com",
        "monitoring.googleapis.com",
        "iam.googleapis.com"
      ]
      labels = {
        environment = "prod"
        service     = "apigee"
        managed_by  = "terraform"
      }
    }
  }
}
```

### IAM Bindings

The Apigee projects should follow the same IAM pattern as other shared infrastructure projects:

```hcl
# In the IAM bindings section (Stage 3 deployment)

# Apigee NonProd Project
"pcc-prj-apigee-nonprod" = [
  {
    role   = "roles/owner"
    member = "group:gcp-admins@pcconnect.ai"
  },
  {
    role   = "roles/viewer"
    member = "group:gcp-auditors@pcconnect.ai"
  },
  {
    role   = "roles/viewer"
    member = "group:gcp-developers@pcconnect.ai"
  },
  # Apigee-specific roles will be added in Phase 1 Apigee deployment
]

# Apigee Prod Project
"pcc-prj-apigee-prod" = [
  {
    role   = "roles/owner"
    member = "group:gcp-admins@pcconnect.ai"
  },
  {
    role   = "roles/viewer"
    member = "group:gcp-auditors@pcconnect.ai"
  },
  {
    role   = "roles/viewer"
    member = "group:gcp-developers@pcconnect.ai"
  },
  # Apigee-specific roles will be added in Phase 1 Apigee deployment
]
```

## Deployment Strategy

### Phase 0: Add Projects to Foundation (This Step)

1. **Update terraform/main.tf** with 2 new Apigee projects
2. **Run terraform plan** to validate changes
3. **Deploy using phased approach**:
   - Stage 1: No changes (org-level IAM unchanged)
   - Stage 2: No changes (network unchanged)
   - Stage 3: Add IAM bindings for 2 new projects
   - Stage 4: Validation

### Phase 1: Deploy Apigee Infrastructure (Separate Step)

After projects exist, deploy Apigee resources in new `infra/pcc-apigee-infra` repo:
- Apigee organizations (2)
- Apigee instances (runtime)
- Environment groups (hostnames + TLS)
- Environments (devtest, dev, staging, prod)
- VPC peering to app/data projects

## Impact Assessment

**Projects Added**: 2 (total: 15 → 17)
**Resources Added** (foundation only): ~10
- 2 projects
- 2 API enablement groups (8 APIs each)
- 6 IAM bindings (3 per project)

**Cost Impact** (foundation only): Minimal
- Project creation: free
- API enablement: free
- IAM: free

**Apigee Runtime Costs** (Phase 1): Significant
- 2 Apigee organizations: ~$5,000-10,000/month per org (depending on usage)
- Will be tracked separately in dedicated project billing

## Validation Steps

After deployment:

1. **Verify Projects Created**:
   ```bash
   gcloud projects list --filter="projectId:pcc-prj-apigee-*"
   ```

2. **Verify Folder Placement**:
   ```bash
   gcloud projects describe pcc-prj-apigee-nonprod --format="value(parent.id)"
   # Should return folder ID for pcc-fldr-si
   ```

3. **Verify APIs Enabled**:
   ```bash
   gcloud services list --project=pcc-prj-apigee-nonprod
   # Should include apigee.googleapis.com, servicenetworking.googleapis.com, etc.
   ```

4. **Verify IAM Bindings**:
   ```bash
   gcloud projects get-iam-policy pcc-prj-apigee-nonprod
   # Should show gcp-admins@pcconnect.ai as owner
   ```

## Next Steps

1. ✅ Document architectural decision (ADR 001) - COMPLETE
2. ✅ Document Terraform changes required - COMPLETE (this file)
3. ⏳ Update `pcc-foundation-infra/terraform/main.tf` with new projects
4. ⏳ Run terraform plan and validate changes
5. ⏳ Deploy to GCP (phased deployment, Stage 3)
6. ⏳ Validate deployment
7. ⏳ Proceed to Phase 1 Apigee infrastructure deployment

## References

- [ADR 001: Two-Organization Apigee X Architecture](./ADR/001-two-org-apigee-architecture.md)
- [Phase 1 Foundation Infrastructure Plan](../plans/phase-1-foundation-infrastructure.md) - needs update
- `pcc-foundation-infra/terraform/main.tf` - existing foundation config
- `pcc-foundation-infra/.claude/status/brief.md` - current deployed state (220 resources)

---

**Note**: This is Phase 0 (foundation updates). The actual Apigee infrastructure (organizations, instances, environments) will be deployed in Phase 1 after these foundation projects exist.
