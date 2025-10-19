# Phase 0.1: Review Foundation Repository Structure

**Parent Phase**: Phase 0 - Foundation - Add Apigee Projects
**Implementation Date**: 10/20/2025 or later
**Estimated Duration**: 15-20 minutes

## Objective

Understand the existing `pcc-foundation-infra` repository structure and terraform patterns to properly add 2 new Apigee projects.

## Prerequisites

- Access to `core/pcc-foundation-infra` repository
- Git credentials configured
- Local development environment set up

## Tasks

### 1. Clone/Update Repository
```bash
cd ~/pcc/core/pcc-foundation-infra
git pull origin main
```

### 2. Review Terraform Structure
- Examine `terraform/main.tf` for existing project definitions
- **Identify existing project module/pattern to reuse** (shared locals, label maps)
- Review folder structure patterns (how projects are organized under folders)
- Note naming conventions for:
  - Project IDs
  - Project names
  - Resource naming patterns
- **Goal**: New resources should slot into existing structure, not introduce bespoke config

### 3. Locate pcc-fldr-si Folder
- Find the folder ID for `pcc-fldr-si` (Shared Infrastructure folder)
- Verify it exists in terraform state
- Confirm billing account association
- Document folder hierarchy

### 4. Document Current Patterns

Create notes on:
- **Project Resource Pattern**: How existing projects are defined
  - Example: `google_project` resource syntax
  - Required fields: project_id, name, folder_id, billing_account
  - Optional fields: labels, auto_create_network, etc.

- **Naming Convention**:
  - Project ID format: `pcc-prj-{purpose}-{environment}`
  - Project name format: Often matches project ID

- **Folder Assignment**:
  - Method for assigning projects to folders
  - Whether using `google_folder` data sources or hardcoded IDs

## Deliverables

- [ ] Repository cloned/updated to latest
- [ ] Terraform structure documented (location of project definitions)
- [ ] Existing project patterns identified
- [ ] `pcc-fldr-si` folder ID confirmed
- [ ] Notes document created with patterns to follow

## Example Existing Project Structure to Find

Look for existing projects like:
```hcl
resource "google_project" "pcc_prj_devops_nonprod" {
  project_id      = "pcc-prj-devops-nonprod"
  name            = "pcc-prj-devops-nonprod"
  folder_id       = "folders/123456789"
  billing_account = "ABCDEF-123456-789012"

  labels = {
    environment = "nonprod"
    purpose     = "devops"
  }
}
```

## Questions to Answer

1. Where exactly in the repo are project resources defined?
2. Are there terraform modules for project creation, or inline resources?
3. What's the folder ID for `pcc-fldr-si`?
4. What billing account is used for shared infrastructure projects?
5. Are there any required labels or tags?
6. Is `auto_create_network = false` used (should be)?

## Success Criteria

- Complete understanding of terraform patterns
- Clear path identified for adding 2 new projects
- All necessary IDs and values documented (folder ID, billing account)
- Ready to proceed to Phase 0.2 (terraform code creation)

## References

- `.claude/plans/devtest-deployment-phases.md` (Phase 0 definition)
- `core/pcc-foundation-infra/terraform/main.tf`
- `core/pcc-foundation-infra/.claude/status/brief.md` (foundation state)

## Notes

- This is PLANNING ONLY - no terraform changes until 10/20
- Document findings for implementation team
- If patterns are unclear, document questions for clarification
