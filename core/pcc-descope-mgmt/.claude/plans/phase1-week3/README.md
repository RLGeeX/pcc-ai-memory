# Phase 1 Week 3: Configuration Management & Real API Integration

**Status:** Pending
**Estimated Duration:** 6-7 hours (365 minutes)
**Chunks:** 6
**Dependencies:** Week 2 complete (all CLI commands implemented)

## Overview

Week 3 transitions from mock/fake implementations to production-ready configuration management and real Descope API integration. This week addresses critical technical debt from Week 2 and implements the configuration-as-code foundation for managing tenants.

## Goals

### Primary Objectives
1. ✅ **Refactor client initialization** - Extract factory pattern to eliminate code duplication (6 locations)
2. ✅ **YAML-based tenant configuration** - Enable declarative tenant management
3. ✅ **Real Descope API integration** - Replace FakeDescopeClient with actual API calls
4. ✅ **Backup/restore functionality** - Add safety mechanisms before destructive operations
5. ✅ **Tenant sync --apply mode** - Implement dry-run vs apply workflow

### Technical Debt Resolution
- ❌ Code duplication: Client initialization in 6 command locations → **FIXED in Chunk 1**
- ❌ Local import anti-pattern: TenantConfig imported in functions → **FIXED in Chunk 1**
- ⚠️ Flow type validation: Dual sources of truth → **Deferred to Week 4**
- ⚠️ Missing tenant filter in flow list → **Deferred to Week 4**

## Chunks

### Chunk 1: Client Factory Pattern (30 min, simple)
**File:** `chunk-001-client-factory.md`
- Extract ClientFactory for dependency injection
- Update all 6 command locations (tenant list/create/update/delete, flow list/deploy)
- Fix local import anti-patterns
- **Tests:** 5 (factory creation, config loading, protocol conformance)
- **Agent:** python-pro

### Chunk 2: YAML Tenant Configuration (45 min, medium)
**File:** `chunk-002-yaml-tenant-config.md`
- Define `tenants.yaml` schema for declarative tenant management
- Extend config_loader to load tenant definitions from YAML
- Add validation for duplicate IDs and domains
- **Tests:** 8 (YAML loading, validation, error handling)
- **Agent:** python-pro

### Chunk 3: Real Descope API - Tenants (60 min, complex)
**File:** `chunk-003-real-api-tenants.md`
- Implement real tenant API methods in DescopeClient
- Add proper error handling for 4xx/5xx responses
- Integration tests with real API (conditional on env vars)
- **Tests:** 10 (unit: 7, integration: 3)
- **Agent:** python-pro

### Chunk 4: Real Descope API - Flows (45 min, medium)
**File:** `chunk-004-real-api-flows.md`
- Implement real flow API methods (list, export, import, deploy)
- Add JSON serialization for flow schemas
- Integration tests for flow operations
- **Tests:** 8 (unit: 5, integration: 3)
- **Agent:** python-pro

### Chunk 5: Backup Service (45 min, medium)
**File:** `chunk-005-backup-service.md`
- Create BackupMetadata and TenantBackup Pydantic models
- Implement BackupService with local filesystem storage
- Add backup creation before destructive operations
- **Tests:** 7 (backup creation, metadata, storage)
- **Agent:** python-pro

### Chunk 6: Restore Service and Sync Apply (60 min, medium)
**File:** `chunk-006-restore-and-sync.md`
- Implement RestoreService to recover from backups
- Add `tenant sync --apply` mode (vs --dry-run)
- Automatic backup before sync apply
- **Tests:** 10 (restore: 5, sync: 5)
- **Agent:** python-pro

## Success Criteria

### Functional Requirements
- ✅ Client factory eliminates all code duplication
- ✅ Tenants can be defined in `tenants.yaml` and loaded
- ✅ Real Descope API calls succeed (with optional integration tests)
- ✅ Backups created automatically before destructive operations
- ✅ `tenant sync --apply` applies changes with safety mechanisms

### Quality Requirements
- ✅ All tests passing (target: 153+ tests, +44 from Week 2's 109)
- ✅ Coverage maintained at 90%+ (Week 2: 91%)
- ✅ All quality checks passing (mypy strict, ruff, lint-imports)
- ✅ Integration tests conditional on env vars (don't require API keys)

### Code Quality
- ✅ No code duplication in client initialization
- ✅ Proper separation: CLI → Domain → API layers
- ✅ Comprehensive error handling with actionable messages
- ✅ TDD discipline: Red-Green-Refactor for all tasks

## Dependencies

### Week 2 Completion Required
- ✅ All CLI commands implemented (tenant CRUD, flow list/deploy)
- ✅ Rich console formatting
- ✅ TenantManager and FlowManager services
- ✅ 109 tests passing, 91% coverage

### External Dependencies
- Descope SDK installed (already in pyproject.toml)
- PyYAML for configuration loading (already in pyproject.toml)
- Optional: Real Descope project for integration tests (env vars)

## Testing Strategy

### Unit Tests (Primary Focus)
- All business logic tested with mocks/fakes
- Protocol conformance tests
- Error handling edge cases

### Integration Tests (Optional)
- Conditional on environment variables:
  - `DESCOPE_TEST_PROJECT_ID` - Test project ID
  - `DESCOPE_TEST_MANAGEMENT_KEY` - Management API key
- Skip gracefully if env vars not set
- Tests marked with `@pytest.mark.integration`

### Running Tests
```bash
# Unit tests only (always run)
pytest tests/unit/ -v --cov=src/descope_mgmt

# All tests including integration (optional)
export DESCOPE_TEST_PROJECT_ID="P2..."
export DESCOPE_TEST_MANAGEMENT_KEY="K2..."
pytest tests/ -v --cov=src/descope_mgmt

# Quality checks
mypy src/ && ruff check . && lint-imports
```

## Execution Notes

### Sequential Execution Recommended
- Chunks 1-2: Foundation (factory + config)
- Chunk 3: Critical (real API integration)
- Chunks 4-6: Build on Chunk 3

No parallel tracks this week - each chunk depends on previous completion.

### Review Checkpoints
- **After Chunk 3:** Critical review point (real API integration complete)
- **After Chunk 6:** Final week review before Week 4

### Time Estimates
| Chunk | Est. Time | Complexity | Review? |
|-------|-----------|------------|---------|
| 1     | 30 min    | Simple     | No      |
| 2     | 45 min    | Medium     | No      |
| 3     | 60 min    | Complex    | Yes     |
| 4     | 45 min    | Medium     | No      |
| 5     | 45 min    | Medium     | No      |
| 6     | 60 min    | Medium     | Yes     |
| **Total** | **365 min** | **6-7 hours** | **2 checkpoints** |

## Files Created This Week

### Source Files (7 new)
```
src/descope_mgmt/
├── api/
│   └── client_factory.py          # NEW - Chunk 1
├── domain/
│   ├── backup_service.py          # NEW - Chunk 5
│   └── restore_service.py         # NEW - Chunk 6
└── types/
    └── backup.py                  # NEW - Chunk 5
```

### Test Files (7 new)
```
tests/
├── unit/
│   ├── api/
│   │   └── test_client_factory.py      # NEW - Chunk 1
│   ├── domain/
│   │   ├── test_backup_service.py      # NEW - Chunk 5
│   │   └── test_restore_service.py     # NEW - Chunk 6
│   └── types/
│       └── test_backup.py              # NEW - Chunk 5
└── integration/
    ├── test_real_tenant_api.py         # NEW - Chunk 3
    └── test_real_flow_api.py           # NEW - Chunk 4
```

### Configuration Files (2 new)
```
config/
└── tenants.yaml.example           # NEW - Chunk 2
tests/
└── fixtures/
    └── test_tenants.yaml          # NEW - Chunk 2
```

## Next Week Preview

**Week 4: Safety & Observability**
- Enhanced error messages with suggestions
- Progress indicators for batch operations
- Audit logging for all operations
- Enhanced validation and confirmations

## References

- **Design Document:** `.claude/plans/design.md`
- **Week 2 Plan:** `.claude/plans/phase1-week2/README.md`
- **Week 2 Completion:** `.claude/handoffs/Claude-2025-11-14-12-12.md`
- **Current Progress:** `.claude/status/current-progress.md`
