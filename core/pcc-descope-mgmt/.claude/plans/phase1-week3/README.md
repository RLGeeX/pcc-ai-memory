# Phase 1 Week 3 Implementation Plan

**Feature**: Safety & Observability - Backup/restore, apply mode, destructive operation safeguards
**Total Chunks**: 6
**Target**: 25+ tests passing by end of week
**Estimated Time**: 6-7 hours total
**Prerequisites**: Phase 1 Week 1-2 complete (111 tests passing)

---

## Chunk Overview

### Chunk 1: Backup Service with Pydantic Schemas (60 min)
**Dependencies**: phase1-week2 complete
**Tasks**: 3 | **Tests**: 8

- BackupSchema models (TenantBackup, ProjectBackup)
- BackupService for creating backups
- Default storage: `~/.descope-mgmt/backups/`
- 30-day retention policy

**Deliverables**:
- ✅ Pydantic schemas for backups
- ✅ BackupService with file I/O
- ✅ 8 tests passing

---

### Chunk 2: Restore Service (45-60 min)
**Dependencies**: chunk-001
**Tasks**: 2 | **Tests**: 6

- RestoreService for loading backups
- Validation before restore
- Dry-run mode for restore preview

**Deliverables**:
- ✅ RestoreService implementation
- ✅ Validation logic
- ✅ 6 tests passing

---

### Chunk 3: Confirmation Prompts & Safety (30-45 min)
**Dependencies**: chunk-001, chunk-002
**Tasks**: 2 | **Tests**: 4

- Destructive operation detection
- Rich confirmation prompts
- --yes flag to skip prompts
- Backup before destructive operations

**Deliverables**:
- ✅ confirm_destructive_operation enhanced
- ✅ Auto-backup before deletes
- ✅ 4 tests passing

---

### Chunk 4: Progress Indicators (30 min)
**Dependencies**: chunk-001
**Tasks**: 1 | **Tests**: 2

- Progress bars for batch operations
- AsyncIO integration
- Rich progress display

**Deliverables**:
- ✅ Progress tracking for batch ops
- ✅ 2 tests passing

---

### Chunk 5: Tenant Sync --apply (60 min)
**Dependencies**: chunk-001, chunk-003, chunk-004
**Tasks**: 2 | **Tests**: 3

- Actually apply changes (not just dry-run)
- Create/update/delete execution
- Error handling and rollback
- Progress tracking

**Deliverables**:
- ✅ tenant sync --apply working
- ✅ Automatic backup before apply
- ✅ 3 integration tests passing

---

### Chunk 6: Tenant Create Command (45 min)
**Dependencies**: chunk-001, chunk-003
**Tasks**: 1 | **Tests**: 2

- tenant create command
- Interactive prompts for config
- Validation and confirmation
- Integration with BackupService

**Deliverables**:
- ✅ tenant create command
- ✅ 2 integration tests passing
- ✅ **Phase 1 Week 3 COMPLETE**

---

## Total Test Count: 25 Tests

- Chunk 1: 8 tests (backup service)
- Chunk 2: 6 tests (restore service)
- Chunk 3: 4 tests (confirmation prompts)
- Chunk 4: 2 tests (progress indicators)
- Chunk 5: 3 tests (sync apply integration)
- Chunk 6: 2 tests (tenant create integration)

**Total: 25 tests** (exceeds 20+ target)

---

## Key Features

### Backup System
- **Format**: Pydantic schemas serialized to JSON
- **Location**: `~/.descope-mgmt/backups/{project_id}/{timestamp}/`
- **Retention**: 30 days (configurable)
- **Auto-backup**: Before any destructive operation

### Safety Mechanisms
- **Confirmation prompts**: For deletes and updates
- **Dry-run first**: Encourage preview before apply
- **--yes flag**: Skip prompts for automation
- **Validation**: Schema validation before operations

### Progress Tracking
- **Rich progress bars**: For batch operations
- **Async operations**: Non-blocking UI updates
- **Clear feedback**: Success/error states

---

## Success Criteria

**Phase 1 Week 3 is complete when:**

- ✅ All 6 chunks completed
- ✅ 25+ tests passing (plan has 25)
- ✅ Backup/restore services working
- ✅ tenant sync --apply functional
- ✅ tenant create command working
- ✅ Destructive operations have safeguards
- ✅ mypy type checking passes
- ✅ ruff formatting/linting passes
- ✅ All code committed with conventional commits

**Expected deliverables**:
- Backup/restore system with Pydantic schemas
- Safety mechanisms (confirmations, auto-backups)
- tenant sync --apply (actually applies changes)
- tenant create command
- Progress indicators
- 25 tests passing
- ~600 lines of code + tests

---

## What's NOT in Week 3

Deferred to future weeks:
- ❌ Flow management → Week 4-5
- ❌ Drift detection → Week 7
- ❌ Advanced error recovery → Week 8
- ❌ Performance optimization → Week 9

---

**Status**: Ready for execution after Week 2 complete
**Next Session**: Execute `/cc-unleashed:plan-next` in `.claude/plans/phase1-week3/`
