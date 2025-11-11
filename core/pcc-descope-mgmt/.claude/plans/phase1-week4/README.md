# Phase 1 Week 4 Implementation Plan

**Feature**: Flow Management Foundation - Models, API wrapper, basic flow commands
**Total Chunks**: 5
**Target**: 20+ tests passing by end of week
**Estimated Time**: 6-7 hours total
**Prerequisites**: Phase 1 Week 1-3 complete (136 tests passing)

---

## Chunk Overview

### Chunk 1: Flow State Models (45-60 min)
**Dependencies**: phase1-week3 complete
**Tasks**: 2 | **Tests**: 6

- FlowState model (frozen dataclass)
- FlowDiff model (ChangeType, FieldDiff)
- Conversion from API data
- FlowBackup schema

**Deliverables**:
- ✅ FlowState and FlowDiff models
- ✅ FlowBackup Pydantic schema
- ✅ 6 tests passing

---

### Chunk 2: Flow API Wrapper (60 min)
**Dependencies**: chunk-001
**Tasks**: 3 | **Tests**: 7

- DescopeFlowClient (extends DescopeApiClient)
- list_flows, get_flow, create_flow, update_flow, delete_flow
- Rate limiting integration
- Error translation

**Deliverables**:
- ✅ Flow API wrapper with retry logic
- ✅ Rate limiting for flow operations
- ✅ 7 tests passing

---

### Chunk 3: Flow List Command (30-45 min)
**Dependencies**: chunk-001, chunk-002
**Tasks**: 1 | **Tests**: 2

- flow list command
- Rich table with flow details
- Filter by flow ID

**Deliverables**:
- ✅ flow list command working
- ✅ Rich formatted output
- ✅ 2 integration tests passing

---

### Chunk 4: Flow Export Command (45 min)
**Dependencies**: chunk-001, chunk-002
**Tasks**: 2 | **Tests**: 3

- flow export command
- Export to JSON/YAML
- Backup integration
- Validation

**Deliverables**:
- ✅ flow export command
- ✅ Multiple format support
- ✅ 3 tests passing

---

### Chunk 5: Flow Import Command (Dry-Run) (45 min)
**Dependencies**: chunk-001, chunk-002, chunk-004
**Tasks**: 1 | **Tests**: 2

- flow import --dry-run command
- Validation before import
- Diff display (show changes)
- Preview mode only (no apply yet)

**Deliverables**:
- ✅ flow import --dry-run
- ✅ Validation and diff preview
- ✅ 2 integration tests passing
- ✅ **Phase 1 Week 4 COMPLETE**

---

## Total Test Count: 20 Tests

- Chunk 1: 6 tests (flow models)
- Chunk 2: 7 tests (flow API wrapper)
- Chunk 3: 2 tests (flow list)
- Chunk 4: 3 tests (flow export)
- Chunk 5: 2 tests (flow import dry-run)

**Total: 20 tests** (meets target)

---

## Key Features

### Flow Commands Available

**flow list**:
```bash
descope-mgmt flow list
descope-mgmt flow list --flow-id sign-up-or-in
```
- Displays all flows in Rich table
- Columns: Flow ID, Name, Screens, Last Modified
- Color-coded output

**flow export**:
```bash
descope-mgmt flow export --flow-id sign-up-or-in --output flow.json
descope-mgmt flow export --all --format yaml
```
- Export flows to JSON or YAML
- Single flow or all flows
- Automatic backup integration

**flow import --dry-run**:
```bash
descope-mgmt flow import --file flow.json --dry-run
```
- Preview flow import without applying
- Validation and diff display
- Safety check before actual import (Week 5)

---

## Flow Model Structure

```python
@dataclass(frozen=True)
class FlowState:
    flow_id: str
    name: str
    screens: list[dict[str, Any]]
    metadata: dict[str, Any]
    created_at: datetime
    updated_at: datetime
```

---

## Success Criteria

**Phase 1 Week 4 is complete when:**

- ✅ All 5 chunks completed
- ✅ 20+ tests passing (plan has 20)
- ✅ Flow models implemented
- ✅ Flow API wrapper working
- ✅ flow list command functional
- ✅ flow export command working
- ✅ flow import --dry-run implemented
- ✅ mypy type checking passes
- ✅ ruff formatting/linting passes
- ✅ All code committed with conventional commits

**Expected deliverables**:
- Flow state models and diff calculation
- Flow API wrapper with rate limiting
- Three flow commands (list, export, import --dry-run)
- 20 tests passing
- ~500 lines of code + tests

---

## What's NOT in Week 4

Deferred to future weeks:
- ❌ flow import --apply (actually apply) → Week 5
- ❌ flow sync command → Week 5
- ❌ Flow templates → Week 5
- ❌ Rollback mechanism → Week 5

---

**Status**: Ready for execution after Week 3 complete
**Next Session**: Execute `/cc-unleashed:plan-next` in `.claude/plans/phase1-week4/`
