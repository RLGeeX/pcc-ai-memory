# Phase 1 Week 1 Implementation Plan

**Feature**: Foundation - Project setup, Pydantic models, config loader, and Descope API integration
**Total Chunks**: 8 (revised from 6)
**Target**: 40+ unit tests passing by end of week
**Estimated Time**: 6-8 hours total

---

## Chunk Overview

### Chunk 1: Project Foundation & Setup (45-60 min)
**Dependencies**: None
**Tasks**: 7

- Initialize directory structure (types/, cli/, domain/, api/, utils/)
- Configure pyproject.toml with all dependencies
- Update requirements.txt (add pyrate-limiter)
- Install dependencies in editable mode
- Configure pre-commit hooks
- Verify .gitignore
- Update README

---

### Chunk 2: Type System & Protocols (45-60 min)
**Dependencies**: chunk-001
**Tasks**: 5 | **Tests**: 8

- Create Protocol definitions (DescopeClient, ConfigLoader, BackupStorage)
- Create exception hierarchy (DescopeMgmtError, ApiError, etc.)
- Create type aliases (TenantId, ProjectId, etc.)
- Export all types from types module
- Configure mypy strict checking

---

### Chunk 3: TenantConfig Pydantic Model (30-45 min) ✨ SPLIT
**Dependencies**: chunk-001, chunk-002
**Tasks**: 1 | **Tests**: 12

- TenantConfig model with validators
- ID pattern validation (lowercase, alphanumeric, hyphens)
- Domain format validation (RFC 1035)
- Length constraints (ID: 3-50, name: 1-100)
- Immutability (frozen model)

---

### Chunk 4: FlowConfig and DescopeConfig Models (30-45 min) ✨ SPLIT
**Dependencies**: chunk-001, chunk-002, chunk-003
**Tasks**: 2 | **Tests**: 9

- FlowConfig model
- DescopeConfig top-level model
- AuthConfig and EnvironmentConfig
- Pydantic parsing of nested structures

---

### Chunk 5: Environment Variable Substitution (30 min) ✨ SPLIT
**Dependencies**: chunk-001, chunk-002
**Tasks**: 1 | **Tests**: 7

- Environment variable substitution (${VAR_NAME} syntax)
- Recursive substitution in dicts and lists
- ConfigurationError for missing vars

---

### Chunk 6: Configuration Loader (45-60 min)
**Dependencies**: chunk-001, chunk-002, chunk-003, chunk-004, chunk-005
**Tasks**: 3 | **Tests**: 11

- YAML config loader with discovery chain
- Environment-specific overrides (descope-{env}.yaml)
- Utils module exports

---

### Chunk 7: API Layer - Rate Limiting (60 min)
**Dependencies**: chunk-001, chunk-002
**Tasks**: 3 | **Tests**: 16

- DescopeRateLimiter with PyrateLimiter (thread-safe)
- TenantRateLimiter (200 req/60s) and UserRateLimiter (500 req/60s)
- RateLimitedExecutor with **submission-time limiting** (CRITICAL)
- Structlog configuration

---

### Chunk 8: API Layer - Descope Client (60-90 min)
**Dependencies**: chunk-001, chunk-002, chunk-007
**Tasks**: 4 | **Tests**: 18

- Retry decorator with exponential backoff
- DescopeApiClient wrapper with SDK integration
- Error translation (SDK → domain exceptions)
- Full test suite verification (40+ tests)

---

## Total Test Count: 81 Tests

- Chunk 1: 0 tests (setup)
- Chunk 2: 8 tests (protocols, exceptions, types)
- Chunk 3: 12 tests (TenantConfig) ✨
- Chunk 4: 9 tests (FlowConfig, DescopeConfig) ✨
- Chunk 5: 7 tests (env vars) ✨
- Chunk 6: 11 tests (config loader)
- Chunk 7: 16 tests (rate limiting)
- Chunk 8: 18 tests (API client, retry)

**Total: 81 tests** (exceeds 40+ target by 2x!)

---

## Improvements from Original Plan

### Better Chunk Sizing ✨
- **Original Chunk 3**: 60-90 min, 28 tests (TOO LARGE)
- **New Chunks 3-5**: 30-45 min each, 12/9/7 tests (BETTER)

**Benefits**:
- ✅ More natural breakpoints (30-45 min sessions)
- ✅ Easier to resume if interrupted
- ✅ Clearer focus per chunk (one model at a time)
- ✅ Better for TDD flow (test → implement → commit)

---

## Execution Instructions

### Using cc-unleashed Plan Workflow

**Start execution:**
```bash
/cc-unleashed:plan-next
```

This will:
1. Load chunk-001.md
2. Guide you through each task
3. Run tests after each step
4. Move to next chunk when complete

---

## Success Criteria

**Phase 1 Week 1 is complete when:**

- ✅ All 8 chunks completed
- ✅ 40+ unit tests passing (plan has 81!)
- ✅ mypy type checking passes (strict mode)
- ✅ ruff formatting/linting passes
- ✅ pre-commit hooks installed and working
- ✅ All code committed with conventional commits
- ✅ No blocking issues

---

## Key Design Decisions

### TDD Approach
Every feature starts with a failing test. This ensures:
- Tests actually verify behavior
- Code is testable from the start
- Clear acceptance criteria

### Type Safety
- Pydantic models for all config
- mypy strict mode enabled
- Protocol-based dependency injection
- Type aliases for domain concepts

### Rate Limiting Strategy
**CRITICAL**: Rate limiting at submission time (not in workers)
- Prevents queue buildup
- Ensures API limits respected
- Uses PyrateLimiter library (thread-safe)

### Import Cycle Prevention
Dependency rules:
- `types/` imports nothing
- `domain/` imports only `types/`
- `api/` imports `types/` and `domain/models`
- `cli/` imports all layers

---

## Next Steps After Week 1

**Phase 1 Week 2** (6 chunks):
- CLI framework with Click
- Basic commands: tenant list, tenant create
- State management (fetch current, calculate diffs)
- Rich terminal output

**Plan location**: `.claude/plans/phase1-week2/`

---

## Files Created This Week

**Source Code** (~800 lines):
- `src/descope_mgmt/types/{protocols,exceptions,common}.py`
- `src/descope_mgmt/domain/models/config.py`
- `src/descope_mgmt/utils/{env_vars,config_loader,logging,concurrency}.py`
- `src/descope_mgmt/api/{rate_limit,retry,descope_client}.py`

**Tests** (~1,200 lines):
- 16 test files with 81 unit tests

**Configuration**:
- `.pre-commit-config.yaml`
- `pyproject.toml` (updated)
- `requirements.txt` (updated)
- `README.md` (updated)

---

**Total: ~2,000 lines of production code + tests**
**Ready for Phase 1 Week 2: CLI implementation**
