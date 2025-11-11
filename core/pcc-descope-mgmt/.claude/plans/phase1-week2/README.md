# Phase 1 Week 2 Implementation Plan

**Feature**: CLI Commands - Click framework, tenant list/create, state management, diff calculation
**Total Chunks**: 6
**Target**: 20+ integration tests passing by end of week
**Estimated Time**: 6-7 hours total
**Prerequisites**: Phase 1 Week 1 complete (81 unit tests passing)

---

## Chunk Overview

### Chunk 1: CLI Framework with Click (45-60 min)
**Dependencies**: phase1-week1 complete
**Tasks**: 3 | **Tests**: 8

- CLI entry point with global options (--config, --environment, --log-level)
- Tenant command group
- Common CLI utilities (formatting, confirmation)

**Deliverables**:
- ✅ Click app with --help and --version
- ✅ Tenant command group structure
- ✅ format_success, format_error, confirm_destructive_operation

---

### Chunk 2: State Models (45-60 min)
**Dependencies**: chunk-001
**Tasks**: 2 | **Tests**: 5

- TenantState, FlowState, ProjectState (frozen dataclasses)
- StateFetcher service for retrieving current Descope state
- Conversion from API data to state models

**Deliverables**:
- ✅ Immutable state models
- ✅ StateFetcher with API integration
- ✅ 5 tests passing

---

### Chunk 3: Diff Calculation Service (45-60 min)
**Dependencies**: chunk-001, chunk-002
**Tasks**: 2 | **Tests**: 9

- Diff models (ChangeType, FieldDiff, TenantDiff, ProjectDiff)
- DiffService for calculating changes
- Field-level diff tracking

**Deliverables**:
- ✅ Diff models with ChangeType enum
- ✅ DiffService detecting creates/updates/deletes
- ✅ 9 tests passing

---

### Chunk 4: Tenant List Command (30-45 min)
**Dependencies**: chunk-001, chunk-002, chunk-003
**Tasks**: 1 | **Tests**: 2

- Implement tenant list command
- Rich table output with colored columns
- Environment variable configuration (DESCOPE_PROJECT_ID, DESCOPE_MANAGEMENT_KEY)

**Deliverables**:
- ✅ tenant list command working
- ✅ Rich table with ID, Name, Domains, Self-Prov columns
- ✅ 2 integration tests passing

---

### Chunk 5: Tenant Sync with Dry-Run (60 min)
**Dependencies**: chunk-001, chunk-002, chunk-003, chunk-004
**Tasks**: 1 | **Tests**: 2

- Implement tenant sync --dry-run command
- Display planned changes (creates, updates, deletes)
- Rich formatted output with color coding
- Summary panel

**Deliverables**:
- ✅ tenant sync --dry-run showing changes
- ✅ Color-coded diff display (green=create, blue=update, red=delete)
- ✅ 2 integration tests passing

---

### Chunk 6: Rich Output Formatting (30 min)
**Dependencies**: chunk-001, chunk-002, chunk-003, chunk-004, chunk-005
**Tasks**: 2 | **Tests**: 4

- Display utilities (format_tenant_table, format_diff_display)
- Progress bar for async operations
- Utils module exports

**Deliverables**:
- ✅ Rich display utilities (4 tests)
- ✅ Reusable formatting functions
- ✅ **Phase 1 Week 2 COMPLETE**

---

## Total Test Count: 30 Tests

- Chunk 1: 8 tests (CLI framework, tenant group, common utils)
- Chunk 2: 5 tests (state models, fetcher)
- Chunk 3: 9 tests (diff models, service)
- Chunk 4: 2 tests (tenant list integration)
- Chunk 5: 2 tests (tenant sync dry-run integration)
- Chunk 6: 4 tests (display utilities)

**Total: 30 tests** (exceeds 20+ target by 50%)

---

## Key Features

### CLI Commands Available

**tenant list**:
```bash
descope-mgmt tenant list
descope-mgmt tenant list --environment prod
```
- Displays all tenants in Rich table
- Columns: ID, Name, Domains, Self-Provisioning
- Color-coded output

**tenant sync --dry-run**:
```bash
descope-mgmt tenant sync --config descope.yaml --dry-run
descope-mgmt tenant sync --config descope.yaml --environment dev --dry-run
```
- Shows planned changes without applying
- Color-coded: green (create), blue (update), red (delete)
- Field-level diff display
- Summary panel with counts

### Rich Terminal Output

- **Tables**: Tenant listings with colored columns
- **Panels**: Change summaries with borders
- **Color coding**: Green (success/create), Blue (update), Red (delete), Yellow (warning)
- **Icons**: ✓ (success), ✗ (error), ⚠ (warning), + (create), ~ (update), - (delete)

---

## Execution Instructions

### Prerequisites

Before starting Week 2:
1. ✅ Phase 1 Week 1 complete (81 unit tests passing)
2. ✅ All code committed
3. ✅ mypy and ruff passing

**Environment setup**:
```bash
export DESCOPE_PROJECT_ID="P2your-project-id"
export DESCOPE_MANAGEMENT_KEY="K2your-management-key"
```

### Using cc-unleashed Plan Workflow

**Start Week 2 execution:**
```bash
cd .claude/plans/phase1-week2
/cc-unleashed:plan-next
```

---

## Success Criteria

**Phase 1 Week 2 is complete when:**

- ✅ All 6 chunks completed
- ✅ 20+ integration tests passing (plan has 30!)
- ✅ tenant list command working
- ✅ tenant sync --dry-run showing changes
- ✅ Rich terminal output with colors
- ✅ mypy type checking passes
- ✅ ruff formatting/linting passes
- ✅ All code committed with conventional commits

**Expected deliverables**:
- CLI framework with Click
- State management (TenantState, ProjectState)
- Diff calculation (ChangeType, DiffService)
- Two working commands (list, sync --dry-run)
- Rich terminal output
- 30 integration + unit tests passing
- ~800 lines of code + tests

---

## Integration with Week 1

Week 2 builds on Week 1 foundation:

**Uses from Week 1**:
- ✅ Pydantic models (TenantConfig, DescopeConfig)
- ✅ ConfigLoader with YAML parsing
- ✅ DescopeApiClient wrapper
- ✅ Rate limiting (PyrateLimiter)
- ✅ Retry logic
- ✅ Type system (protocols, exceptions)

**Adds in Week 2**:
- ✅ CLI commands (Click framework)
- ✅ State models (current vs desired)
- ✅ Diff calculation (change detection)
- ✅ Rich terminal output
- ✅ Integration tests

---

## What's NOT in Week 2

The following are deferred to future weeks:

**NOT in Week 2**:
- ❌ tenant sync --apply (actually applying changes) → Week 3
- ❌ tenant create (direct creation) → Week 3
- ❌ Backup/restore → Week 4
- ❌ Flow commands → Week 5-6
- ❌ Drift detection command → Week 7-8

**Week 2 is DRY-RUN ONLY** - preview changes but don't apply them yet.

---

## Design Patterns in Week 2

### State vs Config Pattern
- **Config models** (TenantConfig): Desired state from YAML
- **State models** (TenantState): Current state from API
- **Diff models**: Difference between the two

### Services
- **StateFetcher**: Retrieves current state from Descope API
- **DiffService**: Compares current vs desired state
- **Later (Week 3)**: ExecutorService for applying changes

### Rich Terminal UX
- Progressive disclosure (summary → details)
- Color coding for scan-ability
- Icons for visual clarity
- Tables for structured data
- Panels for grouping

---

## Next Steps After Week 2

**Phase 1 Week 3-4**: Safety & Observability
- Implement tenant sync --apply (actually apply changes)
- Backup service with Pydantic schemas
- Confirmation prompts for destructive operations
- Progress indicators for batch operations

**Plan location**: `.claude/plans/phase1-week3/` (to be created)

---

## Files Created This Week

**Source Code** (~600 lines):
- `src/descope_mgmt/cli/{main,tenant,common}.py`
- `src/descope_mgmt/domain/models/{state,diff}.py`
- `src/descope_mgmt/domain/services/{state_fetcher,diff_service}.py`
- `src/descope_mgmt/utils/display.py`

**Tests** (~500 lines):
- `tests/unit/cli/test_{main,tenant_commands,common}.py`
- `tests/unit/domain/test_{state_models,diff_models,state_fetcher,diff_service}.py`
- `tests/unit/utils/test_display.py`
- `tests/integration/test_{tenant_list,tenant_sync}.py`

---

**Total Week 1 + Week 2: ~3,200 lines of code + tests, 111 tests passing**
**Ready for Phase 1 Week 3: Safety mechanisms and apply mode**
