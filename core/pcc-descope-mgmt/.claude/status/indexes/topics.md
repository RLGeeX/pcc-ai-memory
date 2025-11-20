# Topic Index

Topic-based organization of features, decisions, and technical implementations.

## Architecture & Design

### Overall Architecture
- **3-Layer Design:** CLI → Domain → API
- **Archive:** [phase1-weeks1-2.md](../archives/phase1-weeks1-2.md#consolidated-design-document)
- **Pattern:** Clean architecture with protocol-based boundaries
- **Validation:** Pydantic models at type layer

### Rate Limiting
- **Decision:** Submission-time rate limiting (not execution-time)
- **Archive:** [phase1-weeks1-2.md](../archives/phase1-weeks1-2.md#critical-fix-rate-limiting-at-submission)
- **Implementation:** Week 1, Chunk 10
- **Pattern:** PyrateLimiter with InMemoryBucket (200 req/60s)
- **Why:** Prevents unbounded queue growth, fails fast

### Client Factory Pattern
- **Problem:** Code duplication in 6 command locations
- **Solution:** [current-progress.md](../current-progress.md#chunk-1-client-factory-pattern)
- **Implementation:** Week 3, Chunk 1
- **Commit:** a73ad67, f3ef3cd, 1d7fb9a
- **Pattern:** Static factory with env var fallback
- **Impact:** Reduced 24 lines of duplicated code

### Dependency Injection
- **Decision:** Protocol-based DI only for external boundaries
- **Archive:** [phase1-weeks1-2.md](../archives/phase1-weeks1-2.md#python-pro-review)
- **Pattern:** DescopeClientProtocol, RateLimiterProtocol
- **Rationale:** Testability without over-engineering

## Features

### Tenant Management

#### Tenant CRUD Commands
- **Commands:** list, create, update, delete
- **Archive:** [phase1-weeks1-2.md](../archives/phase1-weeks1-2.md#week-2-complete)
- **Implementation:** Week 2, Chunks 2, 4, 5, 6
- **Domain Service:** TenantManager (Week 2, Chunk 3)
- **Tests:** 23 tests (tenant_cmds + tenant_manager)

#### Tenant YAML Configuration
- **Feature:** Configuration-as-code for tenants
- **Progress:** [current-progress.md](../current-progress.md#chunk-2-yaml-tenant-configuration)
- **Implementation:** Week 3, Chunk 2
- **Commits:** 04667cd, 5c546bf, 65af59f
- **Model:** TenantListConfig with validators
- **Loader:** ConfigLoader.load_tenants_from_yaml()
- **Example:** config/tenants.yaml.example

#### Tenant Validators
- **Unique IDs:** Pydantic validator prevents duplicate tenant IDs
- **Unique Domains:** Validates domains unique across all tenants
- **Domain Format:** RFC 1035 FQDN validation
- **Progress:** [current-progress.md](../current-progress.md#task-1-tenantlistconfig-model)

### Flow Management

#### Flow Commands
- **Commands:** list, deploy
- **Archive:** [phase1-weeks1-2.md](../archives/phase1-weeks1-2.md#chunks-4-7-8)
- **Implementation:** Week 2, Chunks 7-8
- **Domain Service:** FlowManager
- **Tests:** 11 tests (flow_manager + flow_cmds)

#### Flow Types
- **Validation:** Literal type + runtime validation
- **Archive:** [phase1-weeks1-2.md](../archives/phase1-weeks1-2.md#flow-manager-service)
- **Types:** sign-up, sign-in, sign-up-or-in, step-up, magic-link
- **Technical Debt:** Dual sources of truth (see below)

### Configuration Management

#### YAML Loading
- **Feature:** Load tenant configs from YAML
- **Progress:** [current-progress.md](../current-progress.md#task-2-configloader-extension)
- **Implementation:** Week 3, Chunk 2
- **Error Handling:** File not found, invalid YAML, validation errors
- **Exception:** ConfigError with chained context

#### Environment Variables
- **Feature:** Env var fallback for credentials
- **Progress:** [current-progress.md](../current-progress.md#task-1-define-tenant-yaml-schema-and-models)
- **Variables:** DESCOPE_PROJECT_ID, DESCOPE_MANAGEMENT_KEY
- **Pattern:** Explicit args override env vars

### CLI & User Experience

#### Global Options
- **Options:** --verbose, --dry-run, --config
- **Archive:** [phase1-weeks1-2.md](../archives/phase1-weeks1-2.md#chunk-1-global-cli-options)
- **Implementation:** Week 2, Chunk 1
- **Pattern:** Click with pass_obj for context sharing

#### Rich Console Output
- **Library:** Rich for tables and formatting
- **Archive:** [phase1-weeks1-2.md](../archives/phase1-weeks1-2.md#chunk-1-global-cli-options)
- **Features:** Tables, colors, progress indicators
- **Singleton:** get_console() for shared instance

#### Confirmation Prompts
- **Feature:** User confirmation for destructive operations
- **Archive:** [phase1-weeks1-2.md](../archives/phase1-weeks1-2.md#chunk-6-tenant-delete)
- **Implementation:** tenant delete command
- **Pattern:** Click.confirm() with --force bypass

#### Diff Display
- **Feature:** Show changes before applying updates
- **Archive:** [phase1-weeks1-2.md](../archives/phase1-weeks1-2.md#chunk-5-tenant-update)
- **Implementation:** Week 2, Chunk 5
- **Utility:** display_tenant_diff() in cli/diff.py

## Technical Decisions

### Testing Strategy
- **Approach:** TDD with RED-GREEN-REFACTOR
- **Archive:** [phase1-weeks1-2.md](../archives/phase1-weeks1-2.md#design-phase)
- **Coverage Target:** ≥90%
- **Frameworks:** pytest, responses (HTTP mocking)
- **Fakes:** FakeDescopeClient, FakeRateLimiter

### Parallel Execution
- **Decision:** Execute independent chunks in parallel
- **Archive:** [phase1-weeks1-2.md](../archives/phase1-weeks1-2.md#parallel-execution-success)
- **Implementation:** Week 2, Chunks 4, 7-8
- **Results:** Saved ~80 minutes
- **Pattern:** Separate git branches, merge after review

### Code Quality
- **Type Checking:** mypy strict mode
- **Linting:** ruff (replacing flake8, black, isort)
- **Import Linting:** lint-imports for layer architecture
- **Pre-commit:** All hooks configured
- **Archive:** [phase1-weeks1-2.md](../archives/phase1-weeks1-2.md#tech-stack)

## Technical Debt

### Resolved ✅

#### Code Duplication (Week 3, Chunk 1)
- **Problem:** Client initialization repeated in 6 locations
- **Resolution:** ClientFactory pattern
- **Impact:** Eliminated 24 lines of duplication
- **Commits:** a73ad67, f3ef3cd, 1d7fb9a

#### Local Import Anti-Pattern (Week 3, Chunk 1)
- **Problem:** TenantConfig imported inside functions
- **Resolution:** Moved to module-level imports
- **Impact:** Minor - better Python style
- **Commit:** f3ef3cd

### Active ⏳

#### Flow Type Validation
- **Issue:** Dual sources of truth (Literal type + runtime set)
- **Impact:** Potential drift between type hint and validation
- **Priority:** Medium
- **Archive:** [phase1-weeks1-2.md](../archives/phase1-weeks1-2.md#week-2-complete)
- **Proposed Fix:** Consolidate in Week 3

#### Missing Tenant Filter
- **Issue:** Flow list doesn't filter by tenant
- **Impact:** Shows all flows, not tenant-specific
- **Priority:** Low (defer to Week 4+)
- **Archive:** [phase1-weeks1-2.md](../archives/phase1-weeks1-2.md#week-2-complete)

## Libraries & Dependencies

### Core Dependencies
- **CLI:** Click 8.x
- **Types:** Pydantic 2.x
- **HTTP:** requests
- **Rate Limiting:** PyrateLimiter
- **Output:** Rich
- **YAML:** PyYAML
- **Testing:** pytest, responses

### Tool Dependencies
- **Type Checking:** mypy
- **Linting:** ruff
- **Pre-commit:** pre-commit framework
- **Environment:** mise (Python 3.12)

## Domain Models

### Type System
- **Location:** src/descope_mgmt/types/
- **Archive:** [phase1-weeks1-2.md](../archives/phase1-weeks1-2.md#week-1-type-system-complete)
- **Models:** TenantConfig, FlowConfig, DescopeConfig, TenantListConfig
- **Protocols:** DescopeClientProtocol, RateLimiterProtocol
- **Exceptions:** ApiError, ConfigError, RateLimitError, ValidationError

### Domain Services
- **Location:** src/descope_mgmt/domain/
- **Archive:** [phase1-weeks1-2.md](../archives/phase1-weeks1-2.md#domain-layer-complete)
- **Services:** TenantManager, FlowManager, ConfigLoader
- **Utilities:** EnvSubstitution, display_tenant_diff()

### API Client
- **Location:** src/descope_mgmt/api/
- **Archive:** [phase1-weeks1-2.md](../archives/phase1-weeks1-2.md#api-layer-complete)
- **Client:** DescopeClient (real API)
- **Factory:** ClientFactory (Week 3)
- **Supporting:** RateLimiter, RateLimitedExecutor

## Cross-References

**By Week:**
- Design Phase: [phase1-weeks1-2.md](../archives/phase1-weeks1-2.md#2025-11-10-afternoon)
- Week 1: [phase1-weeks1-2.md](../archives/phase1-weeks1-2.md#2025-11-11-afternoon)
- Week 2: [phase1-weeks1-2.md](../archives/phase1-weeks1-2.md#2025-11-13-afternoon)
- Week 3: [current-progress.md](../current-progress.md#2025-11-17-afternoon)

**By Feature:**
- Tenant Management: See above
- Flow Management: See above
- Configuration: See above
- CLI: See above

**By Decision:**
- Architecture: See above
- Testing: See above
- Quality: See above
