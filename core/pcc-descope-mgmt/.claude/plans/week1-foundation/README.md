# Week 1: Foundation Phase

**Status:** Ready for execution
**Duration:** 6-8 hours (420 minutes estimated)
**Chunks:** 12 micro-chunks (2-3 tasks each)
**Tests:** 50+ tests planned
**Lines of Code:** ~2,000 lines

---

## Overview

Week 1 establishes the complete foundation for the pcc-descope-mgmt CLI tool. By the end of this week, you'll have:

- ✅ Complete type system with Pydantic models
- ✅ YAML configuration loader with env var substitution
- ✅ Rate-limited API client with retry logic
- ✅ CLI entry point with command groups
- ✅ 50+ passing tests with >85% coverage
- ✅ All quality checks configured (mypy, ruff, import-linter, pre-commit)

**Design Foundation**: All implementations incorporate validated design decisions from `.claude/plans/2025-11-12-design-validation-addendum.md`:
- Hybrid type import strategy (ID references)
- Protocols only for external boundaries
- import-linter for layer enforcement
- PyrateLimiter with submission-time limiting
- Retry logic in DescopeClient

---

## Execution Strategy

### Quick Start

```bash
# Navigate to plan directory
cd /home/jfogarty/pcc/core/pcc-descope-mgmt/.claude/plans/week1-foundation

# Execute first chunk
/cc-unleashed:plan-next
```

The plan execution system will:
1. Read chunk-001-project-setup.md
2. Present tasks with estimated time
3. Execute TDD steps (test → implement → verify)
4. Track progress and move to next chunk

### Complexity Ratings

Chunks are rated for execution mode recommendations:

- **Simple** (6 chunks): Boilerplate, config files, well-defined patterns
  - Recommended: Automated execution with checkpoints
  - Chunks: 1, 2, 3, 5, 8

- **Medium** (4 chunks): Business logic with clear tests, standard patterns
  - Recommended: Automated with review checkpoints
  - Chunks: 4, 6, 7, 12

- **Complex** (2 chunks): Novel algorithms, tricky integration
  - Recommended: Supervised execution with human review
  - Chunks: 10, 11

### Review Checkpoints

Plan includes 2 major review checkpoints:
- **Checkpoint 1** (after chunk 6): Type system and configuration complete
- **Checkpoint 2** (after chunk 12): Week 1 complete, all tests passing

### Parallelizable Chunks

Some chunks can be executed in parallel:
- Chunks 1-2: Project setup tasks
- Chunks 3-5: Type system models (independent)
- Chunks 8-9: Exceptions and rate limiter (independent)

---

## Chunk Breakdown

### Chunk 1: Project Setup (10-15 min, Simple)
**Tasks:** 3 | **Tests:** 0 | **Dependencies:** none

- Create directory structure (types, domain, api, cli)
- Configure pyproject.toml with all dependencies
- Install package in editable mode

**Key Files:**
- `pyproject.toml` - Dependencies, tools, import-linter config
- `src/descope_mgmt/` - Package structure

---

### Chunk 2: Pre-commit Hooks (10 min, Simple)
**Tasks:** 2 | **Tests:** 0 | **Dependencies:** chunk-001

- Configure pre-commit hooks (ruff, mypy, import-linter, pytest)
- Configure EditorConfig for consistent formatting

**Key Files:**
- `.pre-commit-config.yaml`
- `.editorconfig`

---

### Chunk 3: Type System Base (15 min, Simple)
**Tasks:** 3 | **Tests:** 7 | **Dependencies:** chunk-001

- Create ResourceIdentifier base model
- Create Protocol definitions (DescopeClient, RateLimiter)
- Export types from module

**Key Files:**
- `src/descope_mgmt/types/shared.py` - ResourceIdentifier
- `src/descope_mgmt/types/protocols.py` - Protocols

**Tests:**
- ResourceIdentifier validation (4 tests)
- Protocol verification (3 tests)

---

### Chunk 4: TenantConfig Model (20 min, Medium)
**Tasks:** 2 | **Tests:** 7 | **Dependencies:** chunk-003

- Create TenantConfig with domain validation
- Add tenant ID format validation
- Detect duplicate domains

**Key Files:**
- `src/descope_mgmt/types/tenant.py` - TenantConfig with validators

**Tests:**
- Minimal/full config (2 tests)
- Domain validation (3 tests)
- ID format validation (2 tests)

---

### Chunk 5: FlowConfig and ProjectSettings (15 min, Simple)
**Tasks:** 2 | **Tests:** 6 | **Dependencies:** chunk-003

- Create FlowConfig with flow type validation
- Create ProjectSettings with environment enum

**Key Files:**
- `src/descope_mgmt/types/flow.py` - FlowConfig
- `src/descope_mgmt/types/project.py` - ProjectSettings

**Tests:**
- FlowConfig validation (3 tests)
- ProjectSettings validation (3 tests)

---

### Chunk 6: Environment Configuration (20 min, Medium)
**Tasks:** 2 | **Tests:** 5 | **Dependencies:** chunk-005

- Create DescopeConfig composite model
- Add uniqueness validation for tenant/flow IDs

**Key Files:**
- `src/descope_mgmt/types/config.py` - DescopeConfig

**Tests:**
- Config with tenants/flows (3 tests)
- Duplicate ID detection (2 tests)

**CHECKPOINT 1**: Type system complete (25 tests passing)

---

### Chunk 7: Config Loader (25 min, Medium)
**Tasks:** 2 | **Tests:** 9 | **Dependencies:** chunk-006

- Create environment variable substitution
- Create YAML config loader with validation

**Key Files:**
- `src/descope_mgmt/domain/env_sub.py` - Env var substitution
- `src/descope_mgmt/domain/config_loader.py` - YAML loader

**Tests:**
- Env var substitution (5 tests)
- YAML loading and validation (4 tests)

---

### Chunk 8: Custom Exceptions (10 min, Simple)
**Tasks:** 2 | **Tests:** 6 | **Dependencies:** none

- Create exception hierarchy
- Add API, Config, RateLimit, Validation errors

**Key Files:**
- `src/descope_mgmt/types/exceptions.py`

**Tests:**
- Exception creation (5 tests)
- Inheritance verification (1 test)

---

### Chunk 9: Rate Limiter (20 min, Medium)
**Tasks:** 2 | **Tests:** 6 | **Dependencies:** chunk-008

- Integrate PyrateLimiter library
- Create FakeRateLimiter for testing

**Key Files:**
- `src/descope_mgmt/api/rate_limiter.py` - DescopeRateLimiter
- `tests/fakes.py` - FakeRateLimiter

**Tests:**
- Rate limiter behavior (5 tests)
- Fake rate limiter (1 test)

---

### Chunk 10: Rate-Limited Executor (30 min, Complex)
**Tasks:** 2 | **Tests:** 7 | **Dependencies:** chunk-009

- Create RateLimitedExecutor with submission-time limiting
- Add batch execution with stop-on-error/continue-on-error
- Integration test for rate limiting behavior

**Key Files:**
- `src/descope_mgmt/api/executor.py` - RateLimitedExecutor
- `tests/integration/test_rate_limiting.py`

**Tests:**
- Executor behavior (6 unit tests)
- Rate limiting integration (1 integration test)

**Critical Design**: Rate limiting BEFORE task execution (validated)

---

### Chunk 11: Descope Client (35 min, Complex)
**Tasks:** 3 | **Tests:** 6+ | **Dependencies:** chunk-010

- Create DescopeClient with retry logic
- Add exponential backoff for 429 responses
- Create FakeDescopeClient for testing
- Run full test suite verification

**Key Files:**
- `src/descope_mgmt/api/descope_client.py` - DescopeClient
- `tests/fakes.py` - FakeDescopeClient

**Tests:**
- Create/update/delete tenant (3 tests)
- Retry logic (2 tests)
- Error handling (1+ tests)

**Critical Design**: Retry logic lives in DescopeClient (HTTP concern)

---

### Chunk 12: CLI Entry Point (20 min, Medium)
**Tasks:** 3 | **Tests:** 6 | **Dependencies:** chunk-011

- Create CLI main entry point with Click
- Add tenant and flow command groups
- Create CLI context manager
- Final Week 1 verification

**Key Files:**
- `src/descope_mgmt/cli/main.py` - CLI entry
- `src/descope_mgmt/cli/context.py` - Context manager

**Tests:**
- CLI help/version (3 tests)
- Context manager (3 tests)

**CHECKPOINT 2**: Week 1 complete (50+ tests passing, >85% coverage)

---

## Success Criteria

Week 1 is complete when:

- [ ] All 12 chunks executed successfully
- [ ] 50+ tests passing (actual count may be higher)
- [ ] Test coverage >85%
- [ ] mypy strict mode passes on entire codebase
- [ ] ruff formatting and linting passes
- [ ] import-linter validates layer boundaries
- [ ] pre-commit hooks all pass
- [ ] CLI commands respond to --help
- [ ] Git tag created: `week1-complete`

---

## Files Created (40+ total)

**Source Code** (~2,000 lines):
```
src/descope_mgmt/
  __init__.py
  types/
    __init__.py
    shared.py
    protocols.py
    tenant.py
    flow.py
    project.py
    config.py
    exceptions.py
  domain/
    __init__.py
    env_sub.py
    config_loader.py
  api/
    __init__.py
    rate_limiter.py
    executor.py
    descope_client.py
  cli/
    __init__.py
    main.py
    context.py
```

**Tests** (~1,500 lines):
```
tests/
  __init__.py
  fakes.py
  fixtures/
    __init__.py
    test_config.yaml
  unit/
    __init__.py
    types/
      __init__.py
      test_shared.py
      test_protocols.py
      test_tenant.py
      test_flow.py
      test_project.py
      test_config.py
      test_exceptions.py
    domain/
      __init__.py
      test_env_sub.py
      test_config_loader.py
    api/
      __init__.py
      test_rate_limiter.py
      test_executor.py
      test_descope_client.py
    cli/
      __init__.py
      test_main.py
      test_context.py
  integration/
    __init__.py
    test_rate_limiting.py
```

**Configuration**:
```
pyproject.toml
.pre-commit-config.yaml
.editorconfig
```

---

## Next Steps After Week 1

Once Week 1 is complete:

1. **Review Progress**: Check `.claude/status/brief.md` for summary
2. **Plan Week 2**: Use `cc-unleashed:write-plan` for Week 2 (CLI commands)
3. **Execute Week 2**: Implement `tenant list`, `tenant create`, `tenant sync`

**Week 2 Preview** (6-7 hours):
- Tenant list command with Rich table output
- Tenant create command with validation
- Tenant sync with diff calculation
- Dry-run and apply modes
- Progress indicators
- ~30 additional tests

---

## Troubleshooting

### Import Errors
If you see import errors, ensure package is installed:
```bash
pip install -e .
```

### Test Failures
Run with verbose output:
```bash
pytest tests/ -v -s
```

### Type Errors
Check specific file:
```bash
mypy src/descope_mgmt/types/tenant.py
```

### Layer Violations
Check import boundaries:
```bash
lint-imports
```

### Pre-commit Failures
Run individual hooks:
```bash
pre-commit run ruff --all-files
pre-commit run mypy --all-files
```

---

## Key Design Decisions Applied

This plan implements validated design decisions from the morning's brainstorming session:

1. **Type Import Strategy**: ID references for cross-model relationships
2. **Dependency Injection**: Protocols only for DescopeClient and RateLimiter
3. **Layer Enforcement**: import-linter with pre-commit hook
4. **Rate Limiting**: PyrateLimiter with submission-time limiting
5. **Retry Logic**: Lives in DescopeClient (HTTP concern)
6. **Testing**: Fake implementations (no mocking library)

---

**Ready to begin?** Run: `/cc-unleashed:plan-next`
