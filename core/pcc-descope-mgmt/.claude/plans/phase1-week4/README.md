# Week 4 Implementation Plan: Safety & Observability

**Status:** Ready for Execution
**Created:** 2025-11-18
**Estimated Duration:** 4 hours
**Total Chunks:** 6 micro-chunks

## Overview

Week 4 focuses on enhancing the safety and observability of the descope-mgmt tool through:
- Enhanced error messages with actionable recovery suggestions
- Progress indicators for batch operations
- Comprehensive audit logging
- Pre-flight validation for operations

## Plan Structure

### Chunk 1: Enhanced Error Messages (15 min, simple)
**Files:** `error_formatter.py`, `test_error_formatter.py`
- Create ErrorFormatter utility with status-code-specific suggestions
- Integrate into CLI commands (tenant and flow operations)
- **Tests:** +5 tests
- **Commits:** 2

### Chunk 2: Progress Indicators - Core (15 min, simple)
**Files:** `progress.py`, `test_progress.py`
- Create ProgressTracker wrapper around Rich Progress
- Add progress to tenant list command
- **Tests:** +3 tests
- **Commits:** 2
- **Can run in parallel with:** Chunk 1

### Chunk 3: Progress Indicators - Batch Operations (20 min, medium)
**Dependencies:** Chunk 2
- Add progress to tenant sync command (analysis + apply phases)
- Add progress to flow deploy command
- Add progress callbacks to backup cleanup
- **Tests:** +6 tests
- **Commits:** 3
- **Review Checkpoint:** After this chunk

### Chunk 4: Audit Logging - Foundation (15 min, simple)
**Files:** `audit.py`, `audit_logger.py`
- Create audit models (AuditEvent, AuditEntry, AuditOperation)
- Create AuditLogger service with JSONL storage
- **Tests:** +12 tests (6 models + 6 logger)
- **Commits:** 2
- **Can run in parallel with:** Chunks 1-2

### Chunk 5: Audit Logging - Integration (20 min, medium)
**Dependencies:** Chunk 4
- Integrate audit logging into TenantManager
- Integrate audit logging into FlowManager
- Add audit log viewer CLI command
- **Tests:** +8 tests
- **Commits:** 3

### Chunk 6: Enhanced Validation (20 min, medium)
**Files:** `validators.py`, `test_validators.py`
- Create SyncValidator with pre-flight checks
- Integrate into tenant sync command
- Validate duplicate IDs, domains, required fields
- **Tests:** +8 tests
- **Commits:** 2
- **Final Review Checkpoint**

## Execution Strategy

### Parallelizable Chunks
- **Group 1:** Chunks 1 + 2 (error formatting and progress core can run concurrently)
- **Group 2:** Chunk 4 (audit foundation independent of progress work)

### Sequential Dependencies
- Chunk 3 depends on Chunk 2 (needs ProgressTracker)
- Chunk 5 depends on Chunk 4 (needs AuditLogger)
- Chunk 6 is independent (can start anytime)

### Review Checkpoints
- After Chunk 3 (50% complete, progress features done)
- After Chunk 6 (100% complete, all features done)

## Expected Outcomes

### Test Coverage
- **Starting:** 151 tests, 94% coverage
- **Expected:** 191+ tests, 94%+ coverage
- **New Tests:** 42 tests across 6 chunks

### Commits
- **Total Commits:** 14 conventional commits
- All commits follow `feat:` prefix
- No co-authored-by lines

### New Features
1. **Error Formatting:** Contextual error messages with recovery suggestions for 401, 404, 429, config errors, validation errors
2. **Progress Tracking:** Visual feedback for list, sync, deploy, backup operations
3. **Audit Logging:** Complete audit trail in `~/.descope-mgmt/audit/*.jsonl` with viewer command
4. **Validation:** Pre-flight checks preventing invalid sync operations

### Files Created
- `src/descope_mgmt/cli/error_formatter.py`
- `src/descope_mgmt/cli/progress.py`
- `src/descope_mgmt/types/audit.py`
- `src/descope_mgmt/domain/audit_logger.py`
- `src/descope_mgmt/cli/audit_cmds.py`
- `src/descope_mgmt/domain/validators.py`
- 9 corresponding test files

### Files Modified
- `src/descope_mgmt/cli/tenant_cmds.py` (error formatting, progress, validation)
- `src/descope_mgmt/cli/flow_cmds.py` (error formatting, progress)
- `src/descope_mgmt/domain/tenant_manager.py` (audit logging)
- `src/descope_mgmt/domain/flow_manager.py` (audit logging)
- `src/descope_mgmt/domain/backup_service.py` (progress callbacks)
- `src/descope_mgmt/cli/main.py` (register audit commands)

## Execution Commands

### Start Execution
```bash
# Option 1: Execute next chunk manually
/cc-unleashed:plan-next

# Option 2: View plan status first
/cc-unleashed:plan-status

# Option 3: Execute entire plan with subagents
# (Uses execute-plan orchestrator with auto-detect mode)
/cc-unleashed:plan-execute
```

### Progress Tracking
- Metadata tracked in `plan-meta.json`
- Execution history appended after each chunk
- Status updates: pending → in_progress → complete

## Quality Assurance

Each chunk includes:
- ✅ TDD workflow (write test → fail → implement → pass)
- ✅ Coverage verification (94%+ maintained)
- ✅ Quality checks (mypy strict, ruff, lint-imports)
- ✅ Manual verification steps
- ✅ Conventional commits

## Success Criteria

Week 4 is complete when:
1. All 191+ tests passing
2. Coverage maintained at 94%+
3. All quality checks passing (mypy, ruff, lint-imports)
4. Manual verification successful for:
   - Error messages show recovery suggestions
   - Progress bars visible during batch operations
   - Audit logs captured and viewable
   - Validation prevents invalid sync operations
5. All 14 commits pushed to repository
6. Status files updated

## Notes

- **Agent Assignment:** python-pro used for all tasks
- **Chunk Size:** Average 400 tokens, 2-3 tasks per chunk
- **Estimated Velocity:** ~20 min per chunk = 2 hours total
- **Buffer:** 2 hours for review, testing, fixes
- **Total Time:** 4 hours estimated

Following the successful Week 3 pattern with automated subagent execution!
