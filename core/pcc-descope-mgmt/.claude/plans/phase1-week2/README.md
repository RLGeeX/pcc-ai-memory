# Week 2: CLI Commands

**Status:** Ready for execution
**Duration:** 6-7 hours (390 minutes estimated)
**Chunks:** 8 micro-chunks (2-3 tasks each)
**Tests:** ~35 additional tests planned
**Lines of Code:** ~1,500 lines

---

## Overview

Week 2 implements actual CLI commands for tenant and flow management, building on the Week 1 foundation. By the end of this week, you'll have:

- ✅ Global CLI options (--verbose, --dry-run, --config)
- ✅ Rich-formatted console output with tables and colors
- ✅ Tenant commands: list, create, update, delete
- ✅ Flow commands: list, deploy
- ✅ TenantManager service layer for business logic
- ✅ FlowManager service layer for flow operations
- ✅ 35+ additional tests (total: 100+ tests)
- ✅ >90% coverage

**Prerequisites**: Week 1 must be complete with all tests passing.

---

## Execution Strategy

### Quick Start

```bash
# Navigate to plan directory
cd /home/jfogarty/pcc/core/pcc-descope-mgmt/.claude/plans/phase1-week2

# Execute first chunk
/cc-unleashed:plan-next
```

### Complexity Ratings

- **Simple** (3 chunks): CLI options, list commands with formatting
  - Chunks: 1, 2, 7

- **Medium** (5 chunks): Service layer logic, CRUD commands
  - Chunks: 3, 4, 5, 6, 8

### Review Checkpoints

- **Checkpoint 1** (after chunk 4): Tenant commands complete
- **Checkpoint 2** (after chunk 8): Week 2 complete, all CLI functional

### Parallelizable Chunks

- Chunks 7-8: Flow commands (independent of tenant commands)

---

## Chunk Breakdown

### Chunk 1: Global CLI Options (30 min, Simple)
**Tasks:** 3 | **Tests:** 5 | **Dependencies:** Week 1 complete

- Add global --verbose, --dry-run, --config options
- Set up Rich console for pretty output
- Update main CLI to use CliContext

---

### Chunk 2: Tenant List Command (30 min, Simple)
**Tasks:** 2 | **Tests:** 4 | **Dependencies:** chunk-001

- Implement `tenant list` command
- Rich table formatting with tenant details
- Handle empty tenant list gracefully

---

### Chunk 3: Tenant Manager Service (45 min, Medium)
**Tasks:** 3 | **Tests:** 8 | **Dependencies:** chunk-002

- Create TenantManager service in domain layer
- Implement list, get, create, update, delete methods
- Add comprehensive tests with FakeDescopeClient

---

### Chunk 4: Tenant Create Command (40 min, Medium)
**Tasks:** 3 | **Tests:** 5 | **Dependencies:** chunk-003

- Implement `tenant create` command
- Validation for tenant configuration
- Confirmation prompt and success message

**CHECKPOINT 1**: Tenant commands functional

---

### Chunk 5: Tenant Update Command (45 min, Medium)
**Tasks:** 3 | **Tests:** 5 | **Dependencies:** chunk-004

- Implement `tenant update` command
- Display diff before applying changes
- Dry-run mode support

---

### Chunk 6: Tenant Delete Command (40 min, Medium)
**Tasks:** 3 | **Tests:** 4 | **Dependencies:** chunk-005

- Implement `tenant delete` command
- Safety confirmation prompt
- Handle tenant not found gracefully

---

### Chunk 7: Flow List Command (35 min, Simple)
**Tasks:** 2 | **Tests:** 3 | **Dependencies:** chunk-003

- Implement `flow list` command
- Rich table formatting for flows
- Filter flows by tenant

---

### Chunk 8: Flow Deploy Command (45 min, Medium)
**Tasks:** 3 | **Tests:** 5 | **Dependencies:** chunk-007

- Implement `flow deploy` command
- Deploy flow from YAML configuration
- Validation and error handling

**CHECKPOINT 2**: Week 2 complete

---

## Success Criteria

Week 2 is complete when:

- [ ] All 8 chunks executed successfully
- [ ] 35+ additional tests passing (total: 100+ tests)
- [ ] Test coverage >90%
- [ ] All CLI commands respond to --help
- [ ] Rich formatting works in terminal
- [ ] Dry-run mode prevents actual changes
- [ ] mypy, ruff, import-linter all pass
- [ ] Git tag created: `week2-complete`

---

## Files Created

**Source Code** (~1,000 lines):
```
src/descope_mgmt/
  domain/
    tenant_manager.py  # TenantManager service
    flow_manager.py    # FlowManager service
  cli/
    main.py           # Updated with global options
    tenant_cmds.py    # Tenant commands
    flow_cmds.py      # Flow commands
    output.py         # Rich formatting utilities
```

**Tests** (~500 lines):
```
tests/
  unit/
    domain/
      test_tenant_manager.py  # 8 tests
      test_flow_manager.py    # 5 tests
    cli/
      test_tenant_cmds.py     # 18 tests
      test_flow_cmds.py       # 8 tests
      test_output.py          # 4 tests
```

---

## Next Steps After Week 2

Once Week 2 is complete:

1. **Review Progress**: Check `.claude/status/brief.md`
2. **Plan Week 3**: Safety, backup/restore, apply mode
3. **Execute Week 3**: Implement sync commands with diff detection

**Week 3 Preview** (6-7 hours):
- Backup service with JSON serialization
- Restore service with validation
- `tenant sync --dry-run` with diff display
- `tenant sync --apply` with auto-backup
- Progress indicators for batch operations

---

**Ready to begin?** Run: `/cc-unleashed:plan-next`
