# Jira DevOps Task Reorganization Design

**Date**: 2025-10-20
**Purpose**: Restructure Jira DevOps tasks to align with Phase 0-10 deployment structure
**Status**: Approved for implementation

## Problem Statement

Current Jira DevOps tasks (Epic 7: CI/CD Integration, Epic 8: DevTest Environment Standup) were created in a vacuum before detailed phase planning was complete. The existing structure:

- Doesn't align with the Phase 0-10 deployment structure documented in `plans/devtest-deployment-phases.md`
- Contains placeholder stories (PCC-65-68) that lack actionable details
- Groups tasks by technology/epic rather than sequential deployment phases
- Makes it unclear what order to execute work in
- Has too broad/vague stories (e.g., PCC-64 covers all CI/CD pipelines)

## Design Goals

1. **Phase Alignment**: Jira structure matches Phase 0-10 deployment phases exactly
2. **Clean & Focused**: Single epic for deploying pcc-client-api end-to-end (Phase 0-9)
3. **Actionable Tasks**: Each task references specific planning documents with clear deliverables
4. **Sequential Clarity**: Stories ordered by deployment sequence, making execution order obvious
5. **Maintainability**: Tasks link to planning docs as single source of truth

## Proposed Structure

### Epic Structure

**New Epic**: "DevTest Deployment - pcc-client-api End-to-End"
- **Scope**: Phase 0-9 (everything needed to deploy pcc-client-api)
- **Excludes**: Phase 10 (remaining services - placeholder for future work)
- **Assignee**: Christine Fogarty
- **Label**: DevOps

### Story Structure

**10 Stories** (one per phase):

1. **Phase 0**: Apigee Projects [**In Progress**]
2. **Phase 1**: Networking [To Do]
3. **Phase 2**: AlloyDB + IAM + Credentials [To Do]
4. **Phase 3**: GKE Clusters [To Do]
5. **Phase 4**: ArgoCD [To Do]
6. **Phase 5**: Pipeline Library [To Do]
7. **Phase 6**: Service Infrastructure (pcc-client-api) [To Do]
8. **Phase 7**: First Service Deployment (pcc-client-api) [To Do]
9. **Phase 8**: Apigee Nonprod + Devtest [To Do]
10. **Phase 9**: External HTTPS Load Balancer [To Do]

All stories assigned to Christine Fogarty with DevOps label.

### Story Format Template

**Summary**: "Phase X: [Title]"

**Description**:
```
[Objective from devtest-deployment-phases.md]

**Scope:**
- [Key scope items from phase overview]
- [Additional scope items]
- [...]

**Acceptance Criteria**:
- [Success criteria summary]
- [Key deliverables]
- [Ready-for state]
```

**Tasks**: Child tasks for each subphase, referencing specific planning documents

### Task Structure

**Tasks to Create Immediately** (planning docs exist):

- **Phase 0**: 4 tasks (0.1-0.4)
  - Each references `plans/devtest-deployment/phase-0.X.md`

- **Phase 1**: 4 tasks (1.1-1.4)
  - Each references `plans/devtest-deployment/phase-1.X.md`

- **Phase 2**: 9 tasks (2.1-2.9)
  - Each references `plans/devtest-deployment/phase-2.X.md`

**Tasks to Add Later** (planning in progress):

- **Phase 3**: 7 tasks (3.1-3.7) - Add after phase-3.1 through phase-3.7.md created
- **Phase 4-9**: Tasks TBD - Add after planning documents completed

Each task:
- Assigned to Christine Fogarty
- Labeled DevOps
- References specific planning document

### Example Story: Phase 1

**Summary**: "Phase 1: Networking"

**Description**:
```
Deploy VPC network infrastructure for pcc-prj-app-devtest with subnets and secondary ranges for GKE pods and services.

**Scope:**
- Create VPC network in pcc-prj-app-devtest
- Deploy primary subnet (10.28.0.0/20)
- Configure secondary ranges for pods and services
- Set up Private Google Access

**Acceptance Criteria**:
- VPC network operational in pcc-prj-app-devtest
- Primary subnet and secondary ranges configured
- Private Google Access enabled
- Network ready for GKE cluster deployment
```

**Tasks** (4):
- Phase 1.1: Review existing foundation → plans/devtest-deployment/phase-1.1.md
- Phase 1.2: VPC network terraform → plans/devtest-deployment/phase-1.2.md
- Phase 1.3: Terraform validation → plans/devtest-deployment/phase-1.3.md
- Phase 1.4: WARP deployment → plans/devtest-deployment/phase-1.4.md

## What Gets Deleted

**Delete from Jira** (all in To Do status):

- **Epic 7**: CI/CD Integration (PCC-40)
  - PCC-41: Configure Cloud Build in DevOps projects
  - PCC-42: Integrate Cloud Build with Bitbucket
  - PCC-43: Create pipeline templates for Application folder
  - PCC-44: Secure Cloud Build with IAM
  - PCC-45: Integrate Cloud Build with GKE

- **Epic 8**: DevTest Environment Standup (PCC-61)
  - PCC-63: AlloyDB PostgreSQL Database Setup
  - PCC-64: CI/CD Pipeline Configuration
  - PCC-65: Observability Deployment (placeholder)
  - PCC-66: Auth Platform Deployment (placeholder)
  - PCC-67: GKE Deployment (placeholder)
  - PCC-68: Apigee Deployment (placeholder)

**Total to delete**: 2 epics + 11 stories

## What Gets Kept

**Keep as-is** (unlinked from new structure):

- **Epic 9**: Foundation Improvements (PCC-69) - Cost optimization backlog
- **PCC-70**: Create PCC Core Infrastructure Repositories [Done]
- **PCC-71**: Create PCC Infrastructure Repositories [Done]
- **PCC-72**: Create PCC Source Code Repositories [Done]

These completed tasks remain as historical record but don't link to new epic.

## Implementation Plan

### Phase 1: Cleanup
1. Delete Epic 7 (PCC-40) and all child stories
2. Delete Epic 8 (PCC-61) and stories PCC-63-68
3. Keep PCC-62 if Done status (verify first)
4. Keep Epic 9 (PCC-69) and PCC-70, 71, 72

### Phase 2: Create Epic
1. Create epic: "DevTest Deployment - pcc-client-api End-to-End"
2. Assign to Christine Fogarty
3. Add DevOps label

### Phase 3: Create Stories
For each phase 0-9:
1. Create story with phase title
2. Populate description from `plans/devtest-deployment-phases.md`
3. Add acceptance criteria summary
4. Assign to Christine Fogarty
5. Add DevOps label
6. Set status (Phase 0 = In Progress, rest = To Do)
7. Link to epic

### Phase 4: Create Tasks (Phases 0-2 only)
For phases with completed planning docs:
1. Create task for each subphase
2. Set task summary from subphase document
3. Add reference to specific planning document
4. Assign to Christine Fogarty
5. Add DevOps label
6. Link to parent story

### Phase 5: Future Tasks
- Phase 3 tasks: Add after phase-3.1 through phase-3.7.md created
- Phase 4-9 tasks: Add as planning documents are completed

## Benefits

1. **Clear Execution Path**: Sequential phase ordering makes it obvious what to work on next
2. **Single Source of Truth**: Planning documents contain details, Jira references them
3. **Incremental Planning**: Can add tasks as planning documents are completed
4. **Focused Scope**: One epic for pcc-client-api keeps work focused
5. **Maintainability**: Changes to planning docs don't require Jira updates (tasks just reference docs)

## Risks & Mitigations

**Risk**: Tasks reference planning docs that don't exist yet (Phase 3-9)
**Mitigation**: Create stories now, add tasks incrementally as planning completes

**Risk**: Descriptions become stale if phase docs change
**Mitigation**: Descriptions are high-level summaries; detailed changes in docs don't require Jira updates

**Risk**: Losing visibility into completed work (deleting Epic 7/8)
**Mitigation**: Keep PCC-70, 71, 72 as historical record; repository creation work is documented

## Success Criteria

- [ ] Epic 7 and Epic 8 deleted from Jira
- [ ] New epic created with 10 stories (Phase 0-9)
- [ ] All stories assigned to Christine Fogarty with DevOps label
- [ ] Phase 0 marked In Progress, Phase 1-9 marked To Do
- [ ] 17 tasks created for Phase 0-2 (4 + 4 + 9)
- [ ] All tasks reference specific planning documents
- [ ] Epic 9 (PCC-69) and completed tasks (PCC-70, 71, 72) remain unchanged

## References

- **Phase Planning**: `plans/devtest-deployment-phases.md`
- **Phase 0 Subphases**: `plans/devtest-deployment/phase-0.{1-4}.md`
- **Phase 1 Subphases**: `plans/devtest-deployment/phase-1.{1-4}.md`
- **Phase 2 Subphases**: `plans/devtest-deployment/phase-2.{1-9}.md`
- **Phase 3 Temp**: `plans/devtest-deployment/phase-3-subphases.md` (awaiting breakdown)
