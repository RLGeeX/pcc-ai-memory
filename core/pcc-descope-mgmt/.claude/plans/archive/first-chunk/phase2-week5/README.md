# Phase 2 Week 5 Implementation Plan

**Feature**: Flow Deployment - Templates, sync, apply, rollback
**Total Chunks**: 5
**Target**: 20+ tests passing by end of week
**Estimated Time**: 6-7 hours total
**Prerequisites**: Phase 1 Week 1-4 complete (156 tests passing)

---

## Chunk Overview

### Chunk 1: Flow Template System (60 min)
**Dependencies**: phase1-week4 complete
**Tasks**: 3 | **Tests**: 6

- FlowTemplate model
- Template variable substitution
- Template validation
- Template library structure

**Deliverables**:
- ✅ FlowTemplate with Jinja2 rendering
- ✅ Variable substitution and validation
- ✅ 6 tests passing

---

### Chunk 2: Flow Sync Command (Dry-Run) (45-60 min)
**Dependencies**: chunk-001
**Tasks**: 2 | **Tests**: 4

- flow sync --dry-run command
- Diff calculation for flows
- Multi-flow batch preview
- Rich diff display

**Deliverables**:
- ✅ flow sync --dry-run working
- ✅ Batch diff display
- ✅ 4 tests passing

---

### Chunk 3: Flow Apply Command (60 min)
**Dependencies**: chunk-001, chunk-002
**Tasks**: 2 | **Tests**: 5

- flow sync --apply (actually apply changes)
- flow import --apply (actually import)
- Automatic backup before apply
- Progress tracking for batch operations

**Deliverables**:
- ✅ Flow apply mode working
- ✅ Auto-backup integration
- ✅ 5 integration tests passing

---

### Chunk 4: Flow Validation & Testing (45 min)
**Dependencies**: chunk-003
**Tasks**: 2 | **Tests**: 3

- Flow schema validation
- Screen structure validation
- Action validation
- Test mode for flows

**Deliverables**:
- ✅ Comprehensive flow validation
- ✅ 3 tests passing

---

### Chunk 5: Rollback Mechanism (45 min)
**Dependencies**: chunk-003
**Tasks**: 2 | **Tests**: 2

- flow rollback command
- Restore from backup
- Rollback confirmation
- Rollback history

**Deliverables**:
- ✅ flow rollback command
- ✅ Backup restore integration
- ✅ 2 integration tests passing
- ✅ **Phase 2 Week 5 COMPLETE**

---

## Total Test Count: 20 Tests

- Chunk 1: 6 tests (template system)
- Chunk 2: 4 tests (sync dry-run)
- Chunk 3: 5 tests (apply mode)
- Chunk 4: 3 tests (validation)
- Chunk 5: 2 tests (rollback)

**Total: 20 tests** (meets target)

---

## Key Features

### Flow Commands Enhanced

**flow sync**:
```bash
descope-mgmt flow sync --config flows.yaml --dry-run
descope-mgmt flow sync --config flows.yaml --apply
```
- Synchronize flows to match configuration
- Batch operations with progress tracking
- Automatic backup before apply

**flow import --apply**:
```bash
descope-mgmt flow import --file flow.json --apply
```
- Actually import the flow (Week 4 was dry-run only)
- Validation before import
- Automatic backup

**flow rollback**:
```bash
descope-mgmt flow rollback --flow-id sign-up-or-in --backup 2025-01-15T10:30:00
descope-mgmt flow rollback --all --latest
```
- Restore flows from backup
- Select specific backup timestamp
- Confirmation prompts

### Template System

```yaml
# flows/sign-up-template.yaml
flow_id: "${TENANT_ID}-sign-up"
name: "Sign Up for ${TENANT_NAME}"
screens:
  - id: email-screen
    title: "Welcome to ${TENANT_NAME}"
```

- Jinja2 variable substitution
- Environment variable support
- Validation before rendering

---

## Success Criteria

**Phase 2 Week 5 is complete when:**

- ✅ All 5 chunks completed
- ✅ 20+ tests passing (plan has 20)
- ✅ Flow template system working
- ✅ flow sync --apply functional
- ✅ flow import --apply working
- ✅ Flow validation comprehensive
- ✅ flow rollback command implemented
- ✅ mypy type checking passes
- ✅ ruff formatting/linting passes
- ✅ All code committed with conventional commits

**Expected deliverables**:
- Flow template system with variable substitution
- Flow sync and apply commands
- Flow validation
- Rollback mechanism
- 20 tests passing
- ~500 lines of code + tests

---

## What's NOT in Week 5

Deferred to future weeks:
- ❌ Advanced batch operations → Week 6
- ❌ Drift detection → Week 7
- ❌ Error recovery → Week 8

---

**Status**: Ready for execution after Week 4 complete
**Next Session**: Execute `/cc-unleashed:plan-next` in `.claude/plans/phase2-week5/`
