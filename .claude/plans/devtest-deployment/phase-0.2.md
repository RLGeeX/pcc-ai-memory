# Phase 0.2: Plan Terraform Configuration for Apigee Projects

**Parent Phase**: Phase 0 - Foundation - Add Apigee Projects
**Implementation Date**: 10/20/2025 or later
**Estimated Duration**: 20-30 minutes

## Objective

Design terraform configuration for creating `pcc-prj-apigee-nonprod` and `pcc-prj-apigee-prod` projects under the `pcc-fldr-si` folder.

## Prerequisites

- Phase 0.1 complete (repository structure understood)
- Folder ID for `pcc-fldr-si` known
- Billing account ID confirmed
- Terraform patterns documented

## Planned Configuration

### Project 1: pcc-prj-apigee-nonprod

```hcl
resource "google_project" "pcc_prj_apigee_nonprod" {
  project_id      = "pcc-prj-apigee-nonprod"
  name            = "PCC Apigee Nonprod"
  folder_id       = "folders/XXXXXXXXXX"  # pcc-fldr-si folder ID
  billing_account = "01AFEA-2B972B-00C55F"

  labels = {
    environment = "nonprod"
    purpose     = "apigee"
    managed_by  = "terraform"
  }

  auto_create_network = false
}
```

### Project 2: pcc-prj-apigee-prod

```hcl
resource "google_project" "pcc_prj_apigee_prod" {
  project_id      = "pcc-prj-apigee-prod"
  name            = "PCC Apigee Prod"
  folder_id       = "folders/XXXXXXXXXX"  # pcc-fldr-si folder ID
  billing_account = "01AFEA-2B972B-00C55F"

  labels = {
    environment = "prod"
    purpose     = "apigee"
    managed_by  = "terraform"
  }

  auto_create_network = false
}
```

## Configuration Details

### Minimal Scope
- **Only project creation** - no API enablement yet
- **No subnets** - deferred to Phase 7
- **No IAM bindings** - deferred to Phase 7
- **No service accounts** - deferred to Phase 7

### Why Minimal?
- Keeps Phase 0 focused and quick
- Reduces blast radius for foundation changes
- Allows Phase 7 to be self-contained for Apigee-specific work

### Required Fields
- `project_id`: Unique GCP project identifier
- `name`: Human-readable project name
- `folder_id`: Parent folder (pcc-fldr-si)
- `billing_account`: Billing account for costs

### Recommended Settings
- `auto_create_network = false`: Prevents default VPC creation
  - We'll create custom VPC subnets in Phase 7
  - Follows GCP security best practices
  - Consistent with other PCC projects

### Labels Strategy
Standard labels for all PCC projects:
- `environment`: "nonprod" or "prod"
- `purpose`: "apigee"
- `managed_by`: "terraform"

## File Location

Determine where to add this code in `pcc-foundation-infra`:
- Option A: Append to existing `terraform/main.tf`
- Option B: New file `terraform/apigee-projects.tf`
- Option C: Within existing organizational pattern

**Decision**: Follow the pattern identified in Phase 0.1

## Terraform State Considerations

- These projects will be added to existing terraform state
- State file: `core/pcc-foundation-infra/terraform/terraform.tfstate`
- Changes will be tracked in version control

## Implementation Checklist (for 10/20)

- [ ] Insert terraform code in identified location
- [ ] Replace placeholder folder_id with actual pcc-fldr-si ID
- [ ] Replace placeholder billing_account with actual ID
- [ ] Follow exact naming/formatting of existing project resources
- [ ] Verify `auto_create_network = false` is set
- [ ] Ensure labels match existing project label patterns

## Expected Terraform Plan Output (10/20)

```
Terraform will perform the following actions:

  # google_project.pcc_prj_apigee_nonprod will be created
  + resource "google_project" "pcc_prj_apigee_nonprod" {
      + auto_create_network = false
      + billing_account     = "01AFEA-2B972B-00C55F"
      + folder_id           = "folders/XXXXXXXXXX"
      + id                  = (known after apply)
      + name                = "PCC Apigee Nonprod"
      + number              = (known after apply)
      + project_id          = "pcc-prj-apigee-nonprod"
      + skip_delete         = (known after apply)
      + labels              = {
          + "environment" = "nonprod"
          + "purpose"     = "apigee"
          + "managed_by"  = "terraform"
        }
    }

  # google_project.pcc_prj_apigee_prod will be created
  + resource "google_project" "pcc_prj_apigee_prod" {
      + auto_create_network = false
      + billing_account     = "01AFEA-2B972B-00C55F"
      + folder_id           = "folders/XXXXXXXXXX"
      + id                  = (known after apply)
      + name                = "PCC Apigee Prod"
      + number              = (known after apply)
      + project_id          = "pcc-prj-apigee-prod"
      + skip_delete         = (known after apply)
      + labels              = {
          + "environment" = "prod"
          + "purpose"     = "apigee"
          + "managed_by"  = "terraform"
        }
    }

Plan: 2 to add, 0 to change, 0 to destroy.
```

## Deliverables

- [ ] Terraform code designed (~20-30 lines)
- [ ] Code follows existing foundation patterns
- [ ] Placeholder values identified for replacement
- [ ] Implementation checklist created
- [ ] Ready for Phase 0.3 (validation planning)

## Success Criteria

- Configuration matches existing project patterns exactly
- All required fields planned
- Minimal scope maintained (no extra resources)
- Clear path to implementation on 10/20

## References

- `.claude/plans/devtest-deployment-phases.md` (Phase 0 scope)
- Phase 0.1 findings (terraform patterns)
- `core/pcc-foundation-infra/terraform/main.tf` (existing projects)

## Notes

- This is PLANNING ONLY - no code written until 10/20
- Document design decisions for implementation
- Ensure consistency with existing foundation infrastructure
