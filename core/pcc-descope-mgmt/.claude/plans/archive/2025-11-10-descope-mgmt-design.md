# pcc-descope-mgmt Design Document

**Version**: 1.0
**Date**: 2025-11-10
**Status**: Approved
**Authors**: Claude (with business-analyst and python-pro consultation)

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Project Overview](#project-overview)
3. [Business Requirements](#business-requirements)
4. [Technical Architecture](#technical-architecture)
5. [Detailed Design](#detailed-design)
6. [Implementation Plan](#implementation-plan)
7. [Testing Strategy](#testing-strategy)
8. [Operational Considerations](#operational-considerations)
9. [Appendices](#appendices)

---

## Executive Summary

`pcc-descope-mgmt` is a Python CLI tool that transforms Descope authentication infrastructure management from error-prone manual operations into reliable, auditable, code-managed workflows. The tool enables developers to declaratively manage Descope projects, tenants, and authentication flows through YAML configuration files with full idempotency, safety mechanisms, and observability.

**Key Value Propositions**:
- **Time Savings**: Reduce environment provisioning from 2-4 hours to <5 minutes
- **Risk Reduction**: 80% fewer manual operations with built-in safety nets
- **Compliance**: 100% audit trails for all infrastructure changes
- **Developer Experience**: Intelligent defaults, rich feedback, and self-service capabilities

**Target Users**: DevOps engineers, backend developers, security engineers, platform engineers

**Core Capabilities**:
1. Create and manage Descope projects programmatically
2. Create/update/delete tenants with configuration-as-code
3. Deploy authentication flow templates (login, MFA, sign-up)
4. Detect and remediate configuration drift
5. Backup/restore Descope configurations
6. Multi-environment support (dev, staging, prod)

---

## Project Overview

### Background

The PortCo Connect (PCC) platform requires managing authentication infrastructure across multiple portfolio companies, each with their own tenants, SSO configurations, and authentication flows. Manual management through the Descope console is:
- Time-consuming (hours per environment)
- Error-prone (typos, inconsistent settings)
- Not auditable (no version control)
- Difficult to replicate across environments

### Goals

**Primary Goal**: Provide a CLI tool that makes Descope infrastructure management as easy and safe as managing infrastructure-as-code with Terraform.

**Secondary Goals**:
- Enable rapid environment provisioning (<5 minutes)
- Reduce configuration errors by 80%+
- Provide 100% audit trail for compliance
- Support multi-environment workflows (dev → staging → prod)
- Enable configuration drift detection and remediation

### Non-Goals (Out of Scope)

- Real-time user management (use Descope SDK directly)
- Custom authentication flow builder UI (start with templates only)
- Monitoring/alerting of Descope service health
- Migration from other auth providers (focus on Descope-native workflows)

### Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Environment provisioning time | <5 minutes | Time from config creation to working auth |
| Error rate | <2% | Failed operations / total operations |
| Test coverage | >85% | pytest-cov measurement |
| Command discoverability | 90% | User survey: "Found command without docs" |
| Self-service error resolution | 85% | Errors resolved without escalation |

---

## Business Requirements

*This section synthesizes findings from the business-analyst agent.*

### Use Cases

#### UC-1: New Environment Provisioning

**Actor**: DevOps Engineer
**Goal**: Provision complete authentication infrastructure for a new environment in <5 minutes

**Preconditions**:
- Descope account exists
- Management API key created
- YAML config file prepared

**Main Flow**:
1. Engineer creates `descope-dev.yaml` with project and tenant definitions
2. Engineer runs `descope-mgmt tenant sync --config descope-dev.yaml --dry-run`
3. System displays diff showing resources to be created
4. Engineer confirms changes
5. System creates project and tenants with progress indicators
6. System displays operation summary with created resource IDs

**Success Criteria**:
- All resources created successfully
- Operation completes in <5 minutes
- Audit log entry created
- Backup of pre-operation state saved

**Error Scenarios**:
- Invalid API key → Clear error with link to Descope console
- Rate limit exceeded → Automatic retry with exponential backoff
- Network failure mid-operation → Idempotent retry from checkpoint

---

#### UC-2: Multi-Tenant Application Setup

**Actor**: Backend Developer
**Goal**: Create tenant hierarchy for portfolio companies with specific SSO and domain configurations

**Preconditions**:
- Descope project exists
- Tenant configuration YAML prepared
- Domain ownership verified (manual step)

**Main Flow**:
1. Developer defines 10 tenants in `tenants.yaml` with domains and SSO settings
2. Developer runs `descope-mgmt tenant sync --config tenants.yaml`
3. System validates configuration (no duplicate domains, valid tenant IDs)
4. System shows diff: 10 tenants to create
5. Developer confirms
6. System creates tenants with batch operations (respecting rate limits)
7. System displays summary: 10 created, 0 failed

**Success Criteria**:
- All tenants created with correct configurations
- Domains properly mapped
- Operation summary shows all successes
- Configuration stored in version control

**Error Scenarios**:
- Duplicate tenant ID → Validation error before API call
- Domain already claimed → Clear error indicating which tenant/domain conflicts
- Partial failure (7/10 succeed) → Summary shows 7 created, 3 failed with specific errors; successful tenants not rolled back; developer can fix config and re-run (idempotent)

---

#### UC-3: Authentication Flow Synchronization

**Actor**: Security Engineer
**Goal**: Deploy updated MFA authentication flow across all environments

**Preconditions**:
- Flow template tested in dev environment
- Config updated with new flow settings
- Change approved via PR review

**Main Flow**:
1. Engineer updates `flows.yaml` to enable MFA with SMS + TOTP methods
2. Engineer runs `descope-mgmt flow deploy --config flows.yaml --environment staging --dry-run`
3. System shows flow configuration changes
4. Engineer confirms staging deployment
5. System deploys flow to staging with backup of old flow
6. Engineer repeats for production after validation
7. System provides rollback command if issues detected

**Success Criteria**:
- Flow deployed successfully to all environments
- Backups created before each deployment
- Audit trail shows who deployed what and when
- Rollback capability available

**Error Scenarios**:
- Flow template not found → Error with list of available templates
- Flow configuration invalid → Validation error with schema details
- API failure during deployment → Automatic rollback from backup

---

#### UC-4: Configuration Drift Detection

**Actor**: Platform Engineer
**Goal**: Identify and remediate differences between code and live Descope state

**Preconditions**:
- YAML config represents desired state
- Manual changes may have been made in Descope console
- Regular drift detection scheduled (e.g., weekly)

**Main Flow**:
1. Engineer runs `descope-mgmt tenant sync --config tenants.yaml --dry-run`
2. System queries Descope API for current state
3. System compares current vs. desired state
4. System displays drift report:
   - 2 tenants have domain changes
   - 1 tenant missing from Descope
   - 1 tenant in Descope not in config (orphaned)
5. Engineer reviews changes and decides:
   - Apply config to fix drift: `descope-mgmt tenant sync --config tenants.yaml`
   - Update config to match reality: manual YAML edits
6. System applies changes with confirmation prompts
7. Drift resolved; audit log records remediation

**Success Criteria**:
- All drift identified accurately
- Engineer has clear options to resolve (apply config or update config)
- Audit trail shows drift detection and resolution
- No unintended changes applied

**Error Scenarios**:
- Cannot determine drift cause → System shows both states side-by-side for manual review
- Conflicting changes (manual + config changes) → System requires explicit conflict resolution
- Orphaned resources → System prompts whether to delete or import into config

---

### Business Rules

#### Resource Identification Constraints

1. **Tenant IDs**: Must be lowercase alphanumeric with hyphens, 3-50 characters, globally unique within project
2. **Project Names**: 1-100 characters, no special characters except spaces and hyphens
3. **Domain Validation**: Must be valid DNS format (RFC 1035), verified ownership before assignment
4. **Tenant Hierarchy**: Max 3 levels of nesting (parent → child → grandchild)

#### Hierarchy Rules

1. **Parent-Child Relationships**: Child tenants inherit SSO configuration from parent unless explicitly overridden
2. **Nesting Depth**: Maximum 3 levels to prevent complexity
3. **Deletion Order**: Must delete children before parent (enforced by system)

#### Flow Dependencies

1. **Connector Requirements**: OAuth flows require configured OAuth connectors
2. **Fallback Methods**: If primary MFA method unavailable, fallback method required
3. **Template Versioning**: Flow templates versioned; system tracks which version deployed

#### Environment Isolation

1. **Production Safeguards**: Production changes require explicit `--environment prod` flag + confirmation
2. **Cross-Environment Restrictions**: Cannot copy staging tenant IDs to production (prevents ID collision)

#### Change Management

1. **Confirmation Requirements**: Destructive operations (delete, replace) require confirmation unless `--yes` flag
2. **Audit Logging**: All operations logged with timestamp, user, operation, resources affected
3. **Backup Policy**: Automatic backup before any modify/delete operation

#### Rate Limiting Compliance

1. **Batch Operations**: Respect Descope rate limits (200 req/60s for tenants)
2. **Retry Strategy**: Exponential backoff on 429 responses (1s, 2s, 4s, 8s, max 5 retries)
3. **Concurrent Limits**: Max 10 concurrent API calls

---

### Edge Cases & Error Scenarios

#### 1. Partial Failures

**Scenario**: Creating 10 tenants, #7 fails due to domain conflict

**System Behavior**:
- Complete operations 1-6 successfully
- Halt on operation 7, display error
- Ask user: Continue with remaining (8-10)? Skip? Abort?
- Provide recovery command to retry just #7 after fixing config
- Log all outcomes (6 success, 1 failed, 3 skipped/pending)

**Design Decision**: Do NOT rollback successful operations (idempotency allows safe re-run)

---

#### 2. Configuration Drift

**Scenario**: Tenant "acme-corp" has domain "acme.com" in config, but "acme.com" and "acme.net" in Descope (manual addition)

**System Behavior**:
- Detect drift: `descope-mgmt tenant sync --dry-run`
- Display diff:
  ```
  Tenant: acme-corp
    ~ domains: ["acme.com"] → ["acme.com", "acme.net"]
  ```
- Prompt user:
  - **Option A**: Apply config (remove "acme.net") - Use `--apply`
  - **Option B**: Update config to match reality - Manual YAML edit
  - **Option C**: Ignore (accept drift) - No action
- Log drift detection and resolution choice

**Design Decision**: Never auto-resolve drift; always require explicit user choice

---

#### 3. Network Failures Mid-Operation

**Scenario**: Creating tenant, network drops after API call sent but before response received

**System Behavior**:
- Log operation start with request details
- On network timeout, attempt retry (idempotent operation checks if tenant exists)
- If tenant exists on retry, verify configuration matches desired state
- If matches, mark as success (already created)
- If differs, treat as drift and show diff
- If tenant doesn't exist, retry creation

**Design Decision**: All operations must be idempotent; use checkpoints for multi-step operations

---

#### 4. Conflicting Configurations

**Scenario**: Two YAML files define tenant "acme-corp" with different domains

**System Behavior**:
- During config loading, detect duplicate tenant ID
- Error immediately: "Tenant 'acme-corp' defined in multiple configs: dev.yaml, prod.yaml"
- Suggest: Use environment-specific tenant IDs or merge configs

**Design Decision**: Fail fast on ambiguity; never guess which config takes precedence

---

#### 5. API Rate Limiting

**Scenario**: Batch creating 50 tenants exceeds 200 req/60s limit

**System Behavior**:
- Track API call rate internally
- When approaching limit, slow down requests (adaptive throttling)
- If 429 received, pause and display: "Rate limited, retrying in 5s..."
- Use exponential backoff: 1s, 2s, 4s, 8s
- Show progress indicator: "Created 30/50 tenants (rate limited, pausing...)"
- Resume after backoff period

**Design Decision**: Proactive throttling + reactive backoff; never fail due to rate limits

---

#### 6. Flow Version Conflicts

**Scenario**: Updating flow from v1 to v2 with breaking changes (removed authentication method)

**System Behavior**:
- Detect version change during diff
- Display warning: "Flow 'mfa-login' version change: v1 → v2 (breaking changes possible)"
- Require explicit flag: `--allow-breaking-changes`
- Create backup of v1 flow automatically
- Provide rollback command in output: `descope-mgmt flow rollback --backup <backup-id>`
- Log version change in audit trail

**Design Decision**: Treat flow updates as potentially breaking; require explicit acknowledgment

---

### User Experience Considerations

#### What Makes This Tool Delightful

1. **Intelligent Defaults**:
   - Auto-detect environment from Git branch name (feature/dev → dev environment)
   - Default config file discovery (./descope.yaml, ./.descope/config.yaml, ~/.descope/config.yaml)
   - Sensible defaults for all optional config fields

2. **Progressive Disclosure**:
   - Simple commands for common tasks: `descope-mgmt tenant sync`
   - Advanced flags for power users: `--dry-run`, `--backup-dir`, `--log-level debug`
   - Help text shows examples for each command

3. **Rich Feedback**:
   - Progress indicators for batch operations with estimated time remaining
   - Color-coded diffs (green=add, yellow=modify, red=delete)
   - Operation summaries with counts: "✓ 10 created, ⚠ 2 updated, ✗ 0 failed"

4. **Safety Nets**:
   - Dry-run mode shows changes without applying
   - Confirmation prompts with impact assessment: "This will delete 5 tenants. Continue? [y/N]"
   - Automatic backups before destructive operations
   - Rollback commands provided after changes

5. **Contextual Help**:
   - Command suggestions: "Did you mean 'descope-mgmt tenant list'?"
   - Inline examples in help text
   - Troubleshooting tips in error messages: "Check your management key in Descope Console → Company → Management Keys"

---

#### What Makes This Tool Frustrating (To Avoid)

1. **Silent Failures**:
   - ❌ Operation fails with no output
   - ✅ Explicit error message with fix suggestion

2. **Hidden State**:
   - ❌ Changes applied without preview
   - ✅ Always show diff before applying (unless `--yes` flag)

3. **Ambiguous Prompts**:
   - ❌ "Continue? [y/n]" (continue what?)
   - ✅ "Delete 5 tenants permanently? [y/N]"

4. **Blocking Operations**:
   - ❌ Long operations with no feedback
   - ✅ Progress indicators with time estimates

5. **Configuration Hell**:
   - ❌ Multiple sources of truth, unclear precedence
   - ✅ Single config file, explicit environment overrides

---

## Technical Architecture

*This section synthesizes findings from the python-pro agent.*

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         CLI Layer                           │
│  (Click commands: project, tenant, flow)                    │
│  - Argument parsing                                         │
│  - User interaction (prompts, progress bars)                │
│  - Output formatting (Rich terminal)                        │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                       Domain Layer                          │
│  - Configuration models (Pydantic)                          │
│  - State management (current vs desired)                    │
│  - Diff calculation                                         │
│  - Idempotent operations                                    │
│  - Business logic (validation, backups)                     │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                        API Layer                            │
│  - Descope SDK wrapper                                      │
│  - Retry logic (exponential backoff)                        │
│  - Rate limit handling                                      │
│  - Error translation (API errors → domain errors)           │
└─────────────────────────────────────────────────────────────┘
                     │
                     ▼
              Descope Management API
```

### Design Patterns

#### 1. Protocol-Based Dependency Injection

Use Python Protocols for type-safe dependency injection without tight coupling:

```python
from typing import Protocol

class DescopeClient(Protocol):
    def load_tenant(self, tenant_id: str) -> Tenant: ...
    def create_tenant(self, tenant: TenantConfig) -> Tenant: ...

class TenantService:
    def __init__(self, client: DescopeClient):
        self._client = client

    def sync_tenant(self, config: TenantConfig) -> SyncResult:
        # Business logic here
        pass
```

**Benefits**:
- Easy to mock for testing (no monkey-patching)
- Type-safe (mypy validates protocol conformance)
- Framework-agnostic domain layer

---

#### 2. Strategy Pattern for Idempotent Operations

Different operation types (create, update, delete) have different idempotency strategies:

```python
from abc import ABC, abstractmethod

class Operation(ABC):
    @abstractmethod
    def is_needed(self, current_state, desired_state) -> bool:
        """Check if operation needed (idempotency check)"""
        pass

    @abstractmethod
    def execute(self) -> OperationResult:
        """Execute the operation"""
        pass

    @abstractmethod
    def rollback(self) -> None:
        """Rollback if operation fails"""
        pass

class CreateTenantOperation(Operation):
    def is_needed(self, current_state, desired_state) -> bool:
        return desired_state.tenant_id not in current_state.tenant_ids

    def execute(self) -> OperationResult:
        # Create tenant via API
        pass

    def rollback(self) -> None:
        # Delete created tenant
        pass

class UpdateTenantOperation(Operation):
    def is_needed(self, current_state, desired_state) -> bool:
        current = current_state.get_tenant(desired_state.tenant_id)
        return current != desired_state

    def execute(self) -> OperationResult:
        # Update tenant via API
        pass

    def rollback(self) -> None:
        # Restore from backup
        pass
```

**Benefits**:
- Each operation type encapsulates its own idempotency logic
- Easy to test each operation independently
- Clear rollback semantics

---

#### 3. Context Managers for API Sessions

Ensure proper resource cleanup and backup/restore semantics:

```python
from contextlib import contextmanager
from typing import Generator

@contextmanager
def backup_before_operation(
    backup_service: BackupService,
    operation_name: str
) -> Generator[BackupId, None, None]:
    """Create backup before operation, rollback on failure"""
    backup_id = backup_service.create_backup(operation_name)
    try:
        yield backup_id
        # Operation succeeded, keep backup for audit
    except Exception as e:
        # Operation failed, restore from backup
        backup_service.restore(backup_id)
        raise

# Usage
with backup_before_operation(backup_svc, "tenant-sync") as backup_id:
    tenant_service.sync_tenants(config)
```

**Benefits**:
- Automatic cleanup on success or failure
- Guarantees backup before destructive operations
- Pythonic resource management

---

#### 4. Factory Pattern for Config Loaders

Support multiple config formats (YAML, JSON) and sources (file, stdin, URL):

```python
from abc import ABC, abstractmethod

class ConfigLoader(ABC):
    @abstractmethod
    def load(self, source: str) -> DescopeConfig:
        pass

class YamlConfigLoader(ConfigLoader):
    def load(self, source: str) -> DescopeConfig:
        with open(source) as f:
            data = yaml.safe_load(f)
        return DescopeConfig(**data)

class JsonConfigLoader(ConfigLoader):
    def load(self, source: str) -> DescopeConfig:
        with open(source) as f:
            data = json.load(f)
        return DescopeConfig(**data)

class ConfigLoaderFactory:
    _loaders = {
        '.yaml': YamlConfigLoader,
        '.yml': YamlConfigLoader,
        '.json': JsonConfigLoader,
    }

    @classmethod
    def get_loader(cls, filepath: str) -> ConfigLoader:
        ext = Path(filepath).suffix
        loader_class = cls._loaders.get(ext)
        if not loader_class:
            raise ValueError(f"Unsupported config format: {ext}")
        return loader_class()
```

**Benefits**:
- Easy to add new config formats
- Single responsibility: each loader handles one format
- Extensible without modifying existing code

---

### Code Structure

```
src/descope_mgmt/
├── __init__.py
├── cli/
│   ├── __init__.py
│   ├── main.py              # Click app entry point, command groups
│   ├── project.py           # Project subcommands
│   ├── tenant.py            # Tenant subcommands
│   ├── flow.py              # Flow subcommands
│   └── common.py            # Shared CLI utilities (output formatting, prompts)
├── domain/
│   ├── __init__.py
│   ├── models/
│   │   ├── __init__.py
│   │   ├── config.py        # Pydantic models for config files
│   │   ├── tenant.py        # Tenant domain model
│   │   ├── flow.py          # Flow domain model
│   │   └── state.py         # State representation (current vs desired)
│   ├── services/
│   │   ├── __init__.py
│   │   ├── tenant_service.py    # Tenant business logic
│   │   ├── flow_service.py      # Flow business logic
│   │   ├── diff_service.py      # Diff calculation
│   │   └── backup_service.py    # Backup/restore logic
│   ├── operations/
│   │   ├── __init__.py
│   │   ├── base.py              # Operation ABC and protocol
│   │   ├── tenant_ops.py        # Tenant operations (create, update, delete)
│   │   └── flow_ops.py          # Flow operations
│   └── exceptions.py            # Custom exception hierarchy
├── api/
│   ├── __init__.py
│   ├── protocols.py         # Type protocols for API clients
│   ├── descope_client.py    # Descope SDK wrapper
│   ├── tenant_api.py        # Tenant API operations
│   ├── flow_api.py          # Flow API operations
│   ├── retry.py             # Retry logic with exponential backoff
│   └── rate_limit.py        # Rate limit tracking and throttling
├── utils/
│   ├── __init__.py
│   ├── logging.py           # Structured logging setup (JSON + console)
│   ├── display.py           # Rich terminal output (progress bars, diffs)
│   ├── config_loader.py     # Config file discovery and loading
│   └── env_vars.py          # Environment variable substitution
└── py.typed                 # PEP 561 marker for type checking
```

**Key Principles**:
- **CLI layer is thin**: Only handles user interaction, delegates to domain layer
- **Domain layer is framework-agnostic**: No Click, no Descope SDK imports
- **API layer is isolated**: All external API calls go through this layer
- **Utils are pure functions**: No side effects, easy to test

---

### Error Handling Strategy

#### Custom Exception Hierarchy

```python
class DescopeMgmtError(Exception):
    """Base exception for all descope-mgmt errors"""
    def __init__(self, message: str, details: dict[str, Any] | None = None):
        super().__init__(message)
        self.message = message
        self.details = details or {}

class ConfigurationError(DescopeMgmtError):
    """Error in configuration file or validation"""
    pass

class ApiError(DescopeMgmtError):
    """Error from Descope API"""
    def __init__(self, message: str, status_code: int, response: dict):
        super().__init__(message, {"status_code": status_code, "response": response})
        self.status_code = status_code
        self.response = response

class RateLimitError(ApiError):
    """Rate limit exceeded (429 response)"""
    pass

class ResourceNotFoundError(ApiError):
    """Resource not found (404 response)"""
    pass

class ResourceConflictError(ApiError):
    """Resource conflict (409 response)"""
    pass

class OperationFailedError(DescopeMgmtError):
    """Operation failed during execution"""
    def __init__(self, operation_name: str, reason: str, partial_results: list):
        super().__init__(
            f"Operation '{operation_name}' failed: {reason}",
            {"operation": operation_name, "partial_results": partial_results}
        )
```

#### Error Translation at API Boundary

```python
from descope import DescopeClient, AuthException

class DescopeApiClient:
    def __init__(self, client: DescopeClient):
        self._client = client

    def load_tenant(self, tenant_id: str) -> Tenant:
        try:
            response = self._client.mgmt.tenant.load(tenant_id)
            return Tenant.from_api_response(response)
        except AuthException as e:
            # Translate Descope SDK exceptions to domain exceptions
            if e.status_code == 404:
                raise ResourceNotFoundError(
                    f"Tenant '{tenant_id}' not found",
                    status_code=404,
                    response=e.response
                )
            elif e.status_code == 429:
                raise RateLimitError(
                    "Rate limit exceeded",
                    status_code=429,
                    response=e.response
                )
            else:
                raise ApiError(
                    f"API error: {e.message}",
                    status_code=e.status_code,
                    response=e.response
                )
```

#### Context Managers for Cleanup

```python
@contextmanager
def operation_context(operation_name: str) -> Generator[OperationContext, None, None]:
    """Manage operation lifecycle with cleanup on failure"""
    context = OperationContext(operation_name)
    logger.info(f"Starting operation: {operation_name}")
    try:
        yield context
        logger.info(f"Operation succeeded: {operation_name}")
    except DescopeMgmtError as e:
        logger.error(f"Operation failed: {operation_name}", exc_info=True)
        context.mark_failed(e)
        raise
    finally:
        context.cleanup()
```

#### Exit Codes

```python
class ExitCode(IntEnum):
    SUCCESS = 0
    CONFIGURATION_ERROR = 1
    API_ERROR = 2
    OPERATION_FAILED = 3
    RATE_LIMIT_ERROR = 4
    VALIDATION_ERROR = 5

# Decorator to convert exceptions to exit codes
def cli_error_handler(func):
    @functools.wraps(func)
    def wrapper(*args, **kwargs):
        try:
            return func(*args, **kwargs)
        except ConfigurationError as e:
            logger.error(f"Configuration error: {e.message}")
            sys.exit(ExitCode.CONFIGURATION_ERROR)
        except RateLimitError as e:
            logger.error(f"Rate limit exceeded: {e.message}")
            sys.exit(ExitCode.RATE_LIMIT_ERROR)
        except ApiError as e:
            logger.error(f"API error: {e.message}")
            sys.exit(ExitCode.API_ERROR)
        except OperationFailedError as e:
            logger.error(f"Operation failed: {e.message}")
            sys.exit(ExitCode.OPERATION_FAILED)
        except Exception as e:
            logger.exception("Unexpected error")
            sys.exit(1)
    return wrapper
```

---

### Type Safety

#### Pydantic Models with Strict Validation

```python
from pydantic import BaseModel, Field, field_validator, ConfigDict
from typing import Literal

class TenantConfig(BaseModel):
    """Pydantic model for tenant configuration"""
    model_config = ConfigDict(
        frozen=True,      # Immutable after creation
        extra='forbid',   # Reject unknown fields
        str_strip_whitespace=True,
        validate_assignment=True
    )

    id: str = Field(
        ...,
        pattern=r'^[a-z0-9-]+$',
        min_length=3,
        max_length=50,
        description="Tenant ID (lowercase alphanumeric with hyphens)"
    )
    name: str = Field(
        ...,
        min_length=1,
        max_length=100,
        description="Display name for tenant"
    )
    domains: list[str] = Field(
        default_factory=list,
        description="Self-provisioning domains"
    )
    self_provisioning: bool = Field(
        default=False,
        description="Enable self-provisioning for domains"
    )

    @field_validator('domains')
    @classmethod
    def validate_domains(cls, v: list[str]) -> list[str]:
        """Validate domain format"""
        domain_pattern = re.compile(
            r'^(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$'
        )
        for domain in v:
            if not domain_pattern.match(domain):
                raise ValueError(f"Invalid domain format: {domain}")
        return v

class FlowConfig(BaseModel):
    """Pydantic model for authentication flow configuration"""
    model_config = ConfigDict(frozen=True, extra='forbid')

    template: Literal[
        "sign-up-or-in",
        "mfa-login",
        "magic-link",
        "social-login"
    ] = Field(..., description="Flow template name")
    name: str = Field(..., min_length=1, description="Display name")
    enabled: bool = Field(default=True, description="Enable flow")
    config: dict[str, Any] = Field(
        default_factory=dict,
        description="Template-specific configuration"
    )

class DescopeConfig(BaseModel):
    """Root configuration model"""
    model_config = ConfigDict(frozen=True, extra='forbid')

    version: Literal["1.0"] = "1.0"
    auth: AuthConfig
    environments: dict[str, EnvironmentConfig] = Field(default_factory=dict)
    tenants: list[TenantConfig] = Field(default_factory=list)
    flows: list[FlowConfig] = Field(default_factory=list)

    @field_validator('tenants')
    @classmethod
    def validate_unique_tenant_ids(cls, v: list[TenantConfig]) -> list[TenantConfig]:
        """Ensure no duplicate tenant IDs"""
        tenant_ids = [t.id for t in v]
        duplicates = {tid for tid in tenant_ids if tenant_ids.count(tid) > 1}
        if duplicates:
            raise ValueError(f"Duplicate tenant IDs: {duplicates}")
        return v
```

#### Generic Type Hints for API Wrappers

```python
from typing import TypeVar, Generic, Protocol

T = TypeVar('T')

class ApiResponse(Generic[T]):
    """Wrapper for API responses with type safety"""
    def __init__(self, data: T, status_code: int, headers: dict):
        self.data = data
        self.status_code = status_code
        self.headers = headers

class ApiClient(Protocol):
    """Protocol for type-safe API client"""
    def get(self, path: str) -> ApiResponse[dict]: ...
    def post(self, path: str, data: dict) -> ApiResponse[dict]: ...
    def put(self, path: str, data: dict) -> ApiResponse[dict]: ...
    def delete(self, path: str) -> ApiResponse[None]: ...

# Type-safe usage
def load_tenant(client: ApiClient, tenant_id: str) -> Tenant:
    response: ApiResponse[dict] = client.get(f"/tenants/{tenant_id}")
    return Tenant.from_dict(response.data)
```

#### Strict mypy Configuration

```toml
# pyproject.toml
[tool.mypy]
python_version = "3.12"
strict = true
warn_return_any = true
warn_unused_configs = true
disallow_untyped_defs = true
disallow_any_generics = true
disallow_subclassing_any = true
disallow_untyped_calls = true
disallow_incomplete_defs = true
check_untyped_defs = true
disallow_untyped_decorators = true
no_implicit_optional = true
warn_redundant_casts = true
warn_unused_ignores = true
warn_no_return = true
warn_unreachable = true
strict_equality = true
```

---

### Performance Considerations

#### Synchronous Implementation

**Decision**: Use synchronous code (no async/await)

**Rationale**:
- Descope SDK is synchronous
- Wrapping sync SDK in async adds complexity without benefit
- CLI tool typically runs one operation at a time
- Batch operations use threading (see below)

---

#### ThreadPoolExecutor for Batch Operations

For operations like creating 50 tenants, use threading with rate limiting:

```python
from concurrent.futures import ThreadPoolExecutor, as_completed
from threading import Semaphore

class RateLimitedExecutor:
    """Thread pool executor with rate limiting"""
    def __init__(self, max_workers: int, rate_limit: int):
        self._executor = ThreadPoolExecutor(max_workers=max_workers)
        self._semaphore = Semaphore(rate_limit)

    def submit(self, fn, *args, **kwargs):
        """Submit task with rate limiting"""
        def rate_limited_fn():
            with self._semaphore:
                return fn(*args, **kwargs)
        return self._executor.submit(rate_limited_fn)

# Usage
executor = RateLimitedExecutor(max_workers=10, rate_limit=20)
futures = []
for tenant_config in tenants:
    future = executor.submit(create_tenant, tenant_config)
    futures.append(future)

for future in as_completed(futures):
    result = future.result()
    # Handle result
```

**Benefits**:
- Parallel execution for I/O-bound operations
- Respect rate limits (20 concurrent requests)
- Progress tracking via as_completed iterator

---

#### Connection Pooling

Use requests Session for connection pooling:

```python
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

def create_session() -> requests.Session:
    """Create HTTP session with connection pooling and retries"""
    session = requests.Session()

    # Connection pooling
    adapter = HTTPAdapter(
        pool_connections=10,
        pool_maxsize=20,
        pool_block=False
    )
    session.mount('https://', adapter)
    session.mount('http://', adapter)

    return session
```

**Benefits**:
- Reuse TCP connections
- Reduce latency for repeated API calls
- Handle transient failures with retries

---

#### Streaming for Large Configs

For very large YAML files (1000+ tenants), use streaming:

```python
import yaml

def load_config_streaming(filepath: str) -> Generator[TenantConfig, None, None]:
    """Stream tenant configs from large YAML file"""
    with open(filepath) as f:
        data = yaml.safe_load(f)
        for tenant_data in data.get('tenants', []):
            yield TenantConfig(**tenant_data)

# Usage
for tenant_config in load_config_streaming('large-config.yaml'):
    process_tenant(tenant_config)
    # Memory released after each iteration
```

**Benefits**:
- Constant memory usage regardless of file size
- Start processing before entire file loaded
- Handle very large configs (10,000+ tenants)

---

### Dependencies

#### Core Dependencies

```
# requirements.txt

# CLI framework
click>=8.1.0

# Configuration and validation
pydantic>=2.5.0
pyyaml>=6.0

# Descope API
descope>=1.7.12

# Terminal UI
rich>=13.0.0

# Structured logging
structlog>=23.0.0

# Retry logic
tenacity>=8.2.0

# Environment variables
python-dotenv>=1.0.0
```

#### Development Dependencies

```
# Development tools
pytest>=7.0.0
pytest-cov>=4.0.0
pytest-mock>=3.12.0
responses>=0.24.0  # Mock HTTP responses
ruff>=0.1.0
mypy>=1.0.0
pre-commit>=3.0.0

# Type stubs
types-pyyaml>=6.0.0
types-requests>=2.31.0
```

#### Dependencies to Avoid

- **async wrappers** (asyncio, aiohttp): Descope SDK is sync, wrapping adds complexity
- **Multiple YAML parsers** (ruamel.yaml, oyaml): Stick to PyYAML for simplicity
- **Custom retry logic**: Use tenacity library instead
- **Custom logging**: Use structlog for structured logging
- **Multiple CLI frameworks**: Stick to Click

---

### Common Python Pitfalls to Avoid

#### 1. Mutable Default Arguments

```python
# ❌ BAD: Mutable default argument
def create_tenant(domains: list[str] = []):
    domains.append("default.com")
    return domains

# ✅ GOOD: Use None and initialize inside
def create_tenant(domains: list[str] | None = None):
    if domains is None:
        domains = []
    domains.append("default.com")
    return domains
```

---

#### 2. Hardcoded API Tokens

```python
# ❌ BAD: Hardcoded token
MANAGEMENT_KEY = "K2abc123..."

# ✅ GOOD: Environment variable with validation
import os

def get_management_key() -> str:
    key = os.getenv("DESCOPE_MANAGEMENT_KEY")
    if not key:
        raise ConfigurationError(
            "DESCOPE_MANAGEMENT_KEY environment variable not set. "
            "Create a management key in Descope Console → Company → Management Keys"
        )
    return key
```

---

#### 3. Exception Handling in Loops

```python
# ❌ BAD: Catch-all in loop continues silently
for tenant in tenants:
    try:
        create_tenant(tenant)
    except Exception:
        pass  # Silent failure!

# ✅ GOOD: Specific exceptions, log failures
results = []
for tenant in tenants:
    try:
        result = create_tenant(tenant)
        results.append(result)
    except ResourceConflictError as e:
        logger.warning(f"Tenant {tenant.id} already exists, skipping")
        results.append(OperationResult.skipped(tenant.id))
    except ApiError as e:
        logger.error(f"Failed to create tenant {tenant.id}: {e.message}")
        results.append(OperationResult.failed(tenant.id, str(e)))

return OperationSummary(results)
```

---

#### 4. Import Cycles

```python
# ❌ BAD: Import cycle between modules
# domain/tenant_service.py
from api.descope_client import DescopeClient

# api/descope_client.py
from domain.models import Tenant  # Cycle!

# ✅ GOOD: Use TYPE_CHECKING
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from domain.models import Tenant

class DescopeClient:
    def load_tenant(self, tenant_id: str) -> 'Tenant':
        # Use string literal for type hint
        pass
```

---

#### 5. Resource Leaks

```python
# ❌ BAD: File not closed on exception
def load_config(filepath: str) -> dict:
    f = open(filepath)
    data = yaml.safe_load(f)
    f.close()  # Not reached if safe_load raises!
    return data

# ✅ GOOD: Use context manager
def load_config(filepath: str) -> dict:
    with open(filepath) as f:
        return yaml.safe_load(f)
```

---

## Detailed Design

### Configuration File Schema

#### Full YAML Schema Example

```yaml
# descope.yaml
version: "1.0"

# Authentication configuration
# Values support environment variable substitution: ${VAR_NAME}
auth:
  project_id: "${DESCOPE_PROJECT_ID}"
  management_key: "${DESCOPE_MANAGEMENT_KEY}"

# Environment-specific overrides
# When --environment flag used, these values override top-level auth
environments:
  dev:
    project_id: "P2dev123..."
  staging:
    project_id: "P2stg456..."
  prod:
    project_id: "P2prd789..."

# Tenant definitions
tenants:
  # Basic tenant with minimal config
  - id: "acme-corp"
    name: "Acme Corporation"
    domains:
      - "acme.com"
      - "acme.net"
    self_provisioning: true
    custom_attributes:
      plan: "enterprise"
      region: "us-east"

  # Tenant with SSO configuration (future enhancement)
  - id: "widget-co"
    name: "Widget Company"
    domains: ["widget.io"]
    self_provisioning: false
    # sso:
    #   enabled: true
    #   provider: "okta"
    #   idp_url: "https://widget.okta.com/app/..."

# Authentication flow templates
flows:
  # Simple flow with just template
  - template: "sign-up-or-in"
    name: "Default Login Flow"
    enabled: true

  # Flow with configuration
  - template: "mfa-login"
    name: "Multi-Factor Authentication"
    enabled: true
    config:
      methods: ["sms", "totp", "email"]
      remember_device: true
      remember_duration_days: 30

  # Flow with custom screens (future enhancement)
  # - template: "custom-flow"
  #   name: "Custom Branded Login"
  #   enabled: true
  #   screens:
  #     - type: "login"
  #       theme: "corporate"
  #       logo_url: "https://..."
```

#### Environment Variable Substitution

```python
import os
import re

def substitute_env_vars(value: str) -> str:
    """Replace ${VAR_NAME} with environment variable value"""
    pattern = r'\$\{([^}]+)\}'

    def replace_var(match):
        var_name = match.group(1)
        var_value = os.getenv(var_name)
        if var_value is None:
            raise ConfigurationError(
                f"Environment variable '{var_name}' not set. "
                f"Required for configuration value: {value}"
            )
        return var_value

    return re.sub(pattern, replace_var, value)

# Usage in config loading
def load_config(filepath: str) -> DescopeConfig:
    with open(filepath) as f:
        data = yaml.safe_load(f)

    # Recursively substitute env vars
    data_with_env = substitute_env_vars_recursive(data)

    # Validate with Pydantic
    return DescopeConfig(**data_with_env)
```

---

### CLI Command Reference

#### Global Options

All commands support these global options:

```bash
--config PATH           # Path to config file (default: ./descope.yaml)
--environment ENV       # Environment name (dev, staging, prod)
--dry-run              # Preview changes without applying
--yes                  # Skip confirmation prompts
--log-level LEVEL      # Logging level (debug, info, warning, error)
--log-file PATH        # Write logs to file (default: logs/descope-mgmt.log)
--no-color             # Disable colored output
--quiet                # Suppress non-error output
--verbose              # Show detailed output (equivalent to --log-level debug)
```

---

#### Project Commands

##### `descope-mgmt project create`

Create a new Descope project (note: requires organization-level permissions, may not be available in all Descope plans).

```bash
descope-mgmt project create --name "PCC Production" --config descope.yaml
```

**Options**:
- `--name TEXT`: Project display name (required)
- `--config PATH`: Config file with project settings

**Example Output**:
```
✓ Project created successfully
  Project ID: P2abc123...
  Name: PCC Production

Next steps:
  1. Save project ID to DESCOPE_PROJECT_ID environment variable
  2. Create management key: Descope Console → Company → Management Keys
  3. Update descope.yaml with project_id and management_key
```

---

##### `descope-mgmt project export`

Export current project configuration to YAML file.

```bash
descope-mgmt project export --output exported-config.yaml
```

**Options**:
- `--output PATH`: Output file path (default: stdout)
- `--include-tenants`: Include tenant configurations
- `--include-flows`: Include flow configurations

**Example Output**:
```
Exporting project configuration...
✓ 10 tenants exported
✓ 3 flows exported
✓ Configuration saved to exported-config.yaml
```

---

##### `descope-mgmt project validate`

Validate configuration file without applying changes.

```bash
descope-mgmt project validate --config descope.yaml
```

**Example Output**:
```
Validating configuration...
✓ Schema validation passed
✓ 10 tenants validated
✓ 3 flows validated
✗ 2 errors found:

Error 1: Tenant 'acme-corp'
  Domain 'invalid..domain' is not a valid DNS name

Error 2: Flow 'mfa-login'
  Configuration error: 'methods' must include at least one method

Configuration is INVALID
```

---

#### Tenant Commands

##### `descope-mgmt tenant sync`

Create or update tenants to match configuration file (idempotent).

```bash
descope-mgmt tenant sync --config descope.yaml --dry-run
descope-mgmt tenant sync --config descope.yaml  # Apply changes
```

**Options**:
- `--config PATH`: Config file
- `--dry-run`: Preview changes without applying
- `--backup-dir PATH`: Directory for backups (default: .descope-backups/)

**Example Output (dry-run)**:
```
Calculating changes...

Tenant: acme-corp
  + Create new tenant
    name: "Acme Corporation"
    domains: ["acme.com", "acme.net"]
    self_provisioning: true

Tenant: widget-co
  ~ Update existing tenant
    ~ domains: ["widget.io"] → ["widget.io", "widget.com"]

Tenant: old-corp
  - Delete tenant (not in config)

Summary:
  + 1 tenant to create
  ~ 1 tenant to update
  - 1 tenant to delete

Run without --dry-run to apply changes.
```

**Example Output (apply)**:
```
Creating backup...
✓ Backup saved to .descope-backups/2025-11-10_14-30-15_pre-tenant-sync.json

Applying changes...
✓ acme-corp created (1/3)
✓ widget-co updated (2/3)

⚠ Delete tenant 'old-corp'? [y/N]: n
  Skipped deletion

Operation Summary:
  ✓ 1 tenant created
  ✓ 1 tenant updated
  ⊘ 1 tenant skipped (delete declined)

Duration: 3.2s
```

---

##### `descope-mgmt tenant list`

List all tenants in current project.

```bash
descope-mgmt tenant list
descope-mgmt tenant list --format json  # Machine-readable output
```

**Example Output**:
```
Tenants in project P2abc123...

┌──────────────┬─────────────────────┬──────────────────┬────────────────┐
│ ID           │ Name                │ Domains          │ Self-Provision │
├──────────────┼─────────────────────┼──────────────────┼────────────────┤
│ acme-corp    │ Acme Corporation    │ acme.com         │ ✓              │
│              │                     │ acme.net         │                │
│ widget-co    │ Widget Company      │ widget.io        │ ✗              │
│ mega-corp    │ Mega Corporation    │ mega.com         │ ✓              │
└──────────────┴─────────────────────┴──────────────────┴────────────────┘

Total: 3 tenants
```

---

##### `descope-mgmt tenant delete`

Delete a tenant (with confirmation).

```bash
descope-mgmt tenant delete --tenant-id acme-corp
descope-mgmt tenant delete --tenant-id acme-corp --yes  # Skip confirmation
```

**Example Output**:
```
⚠ WARNING: This will permanently delete tenant 'acme-corp'
  - All tenant data will be lost
  - Users associated with this tenant will be removed
  - This action cannot be undone

Type the tenant ID to confirm: acme-corp

Creating backup...
✓ Backup saved to .descope-backups/2025-11-10_14-35-20_pre-tenant-delete.json

Deleting tenant...
✓ Tenant 'acme-corp' deleted

Rollback command (if needed):
  descope-mgmt tenant restore --backup .descope-backups/2025-11-10_14-35-20_pre-tenant-delete.json
```

---

#### Flow Commands

##### `descope-mgmt flow deploy`

Deploy authentication flow templates.

```bash
descope-mgmt flow deploy --config descope.yaml --dry-run
descope-mgmt flow deploy --config descope.yaml  # Apply
```

**Example Output**:
```
Deploying flows...

Flow: Default Login Flow (sign-up-or-in)
  + Deploy new flow
    template: sign-up-or-in
    enabled: true

Flow: Multi-Factor Authentication (mfa-login)
  ~ Update existing flow
    ~ methods: ["sms", "totp"] → ["sms", "totp", "email"]

Run without --dry-run to apply changes.
```

---

##### `descope-mgmt flow export`

Export existing flows to YAML file.

```bash
descope-mgmt flow export --output flows.yaml
```

---

##### `descope-mgmt flow list`

List available flow templates and deployed flows.

```bash
descope-mgmt flow list
descope-mgmt flow list --templates  # Show available templates only
```

**Example Output**:
```
Available Flow Templates:
  • sign-up-or-in       - Sign up or sign in flow
  • mfa-login           - Multi-factor authentication
  • magic-link          - Passwordless magic link login
  • social-login        - Social provider authentication

Deployed Flows:
  ✓ Default Login Flow (sign-up-or-in)
  ✓ Multi-Factor Authentication (mfa-login)

Total: 2 flows deployed
```

---

### State Management Implementation

#### State Representation

```python
from dataclasses import dataclass
from typing import Optional

@dataclass(frozen=True)
class TenantState:
    """Current state of a tenant in Descope"""
    id: str
    name: str
    domains: list[str]
    self_provisioning: bool
    custom_attributes: dict[str, Any]
    created_at: datetime
    updated_at: datetime

@dataclass(frozen=True)
class ProjectState:
    """Current state of entire project"""
    project_id: str
    tenants: dict[str, TenantState]  # Keyed by tenant ID
    flows: dict[str, FlowState]       # Keyed by flow name
    fetched_at: datetime

class StateService:
    """Service for fetching and managing state"""

    def __init__(self, api_client: DescopeApiClient):
        self._client = api_client

    def fetch_current_state(self) -> ProjectState:
        """Fetch current state from Descope API"""
        tenants = self._fetch_all_tenants()
        flows = self._fetch_all_flows()

        return ProjectState(
            project_id=self._client.project_id,
            tenants={t.id: t for t in tenants},
            flows={f.name: f for f in flows},
            fetched_at=datetime.now(timezone.utc)
        )

    def _fetch_all_tenants(self) -> list[TenantState]:
        """Fetch all tenants with pagination"""
        all_tenants = []
        page = 0
        page_size = 50

        while True:
            response = self._client.list_tenants(page=page, page_size=page_size)
            tenants = [TenantState.from_api_response(t) for t in response.data]
            all_tenants.extend(tenants)

            if len(tenants) < page_size:
                break  # Last page
            page += 1

        return all_tenants
```

---

#### Diff Calculation

```python
from enum import Enum
from typing import Any

class ChangeType(Enum):
    CREATE = "create"
    UPDATE = "update"
    DELETE = "delete"
    NO_CHANGE = "no_change"

@dataclass(frozen=True)
class FieldDiff:
    """Difference in a single field"""
    field_name: str
    old_value: Any
    new_value: Any

@dataclass(frozen=True)
class TenantDiff:
    """Difference between current and desired tenant state"""
    tenant_id: str
    change_type: ChangeType
    field_diffs: list[FieldDiff]

    @property
    def has_changes(self) -> bool:
        return self.change_type != ChangeType.NO_CHANGE

@dataclass(frozen=True)
class ProjectDiff:
    """Difference between current and desired project state"""
    tenant_diffs: list[TenantDiff]
    flow_diffs: list[FlowDiff]

    @property
    def has_changes(self) -> bool:
        return any(d.has_changes for d in self.tenant_diffs + self.flow_diffs)

    @property
    def summary(self) -> DiffSummary:
        """Summarize changes"""
        creates = sum(1 for d in self.tenant_diffs if d.change_type == ChangeType.CREATE)
        updates = sum(1 for d in self.tenant_diffs if d.change_type == ChangeType.UPDATE)
        deletes = sum(1 for d in self.tenant_diffs if d.change_type == ChangeType.DELETE)

        return DiffSummary(
            creates=creates,
            updates=updates,
            deletes=deletes,
            total=creates + updates + deletes
        )

class DiffService:
    """Service for calculating diffs between states"""

    def calculate_diff(
        self,
        current_state: ProjectState,
        desired_config: DescopeConfig
    ) -> ProjectDiff:
        """Calculate diff between current state and desired config"""
        tenant_diffs = self._diff_tenants(
            current_state.tenants,
            desired_config.tenants
        )
        flow_diffs = self._diff_flows(
            current_state.flows,
            desired_config.flows
        )

        return ProjectDiff(
            tenant_diffs=tenant_diffs,
            flow_diffs=flow_diffs
        )

    def _diff_tenants(
        self,
        current_tenants: dict[str, TenantState],
        desired_tenants: list[TenantConfig]
    ) -> list[TenantDiff]:
        """Calculate tenant diffs"""
        diffs = []
        desired_ids = {t.id for t in desired_tenants}

        # Check for creates and updates
        for desired in desired_tenants:
            if desired.id not in current_tenants:
                # CREATE: Tenant doesn't exist
                diffs.append(TenantDiff(
                    tenant_id=desired.id,
                    change_type=ChangeType.CREATE,
                    field_diffs=[]
                ))
            else:
                # Possible UPDATE: Compare fields
                current = current_tenants[desired.id]
                field_diffs = self._compare_tenant_fields(current, desired)

                if field_diffs:
                    diffs.append(TenantDiff(
                        tenant_id=desired.id,
                        change_type=ChangeType.UPDATE,
                        field_diffs=field_diffs
                    ))
                else:
                    diffs.append(TenantDiff(
                        tenant_id=desired.id,
                        change_type=ChangeType.NO_CHANGE,
                        field_diffs=[]
                    ))

        # Check for deletes
        for current_id in current_tenants:
            if current_id not in desired_ids:
                # DELETE: Tenant exists but not in config
                diffs.append(TenantDiff(
                    tenant_id=current_id,
                    change_type=ChangeType.DELETE,
                    field_diffs=[]
                ))

        return diffs

    def _compare_tenant_fields(
        self,
        current: TenantState,
        desired: TenantConfig
    ) -> list[FieldDiff]:
        """Compare individual fields"""
        diffs = []

        if current.name != desired.name:
            diffs.append(FieldDiff("name", current.name, desired.name))

        if set(current.domains) != set(desired.domains):
            diffs.append(FieldDiff("domains", current.domains, desired.domains))

        if current.self_provisioning != desired.self_provisioning:
            diffs.append(FieldDiff(
                "self_provisioning",
                current.self_provisioning,
                desired.self_provisioning
            ))

        # Compare custom attributes
        if current.custom_attributes != desired.custom_attributes:
            diffs.append(FieldDiff(
                "custom_attributes",
                current.custom_attributes,
                desired.custom_attributes
            ))

        return diffs
```

---

#### Diff Display

```python
from rich.console import Console
from rich.table import Table
from rich.panel import Panel
from rich import box

class DiffDisplay:
    """Display diffs in rich terminal format"""

    def __init__(self):
        self.console = Console()

    def display_diff(self, diff: ProjectDiff) -> None:
        """Display project diff with colors"""
        if not diff.has_changes:
            self.console.print("✓ No changes detected", style="green")
            return

        # Display summary
        summary = diff.summary
        self.console.print(Panel(
            f"[green]+ {summary.creates} to create[/green]\n"
            f"[yellow]~ {summary.updates} to update[/yellow]\n"
            f"[red]- {summary.deletes} to delete[/red]",
            title="Change Summary",
            box=box.ROUNDED
        ))

        self.console.print()

        # Display tenant diffs
        for tenant_diff in diff.tenant_diffs:
            if not tenant_diff.has_changes:
                continue

            self._display_tenant_diff(tenant_diff)

        # Display flow diffs
        for flow_diff in diff.flow_diffs:
            if not flow_diff.has_changes:
                continue

            self._display_flow_diff(flow_diff)

    def _display_tenant_diff(self, diff: TenantDiff) -> None:
        """Display single tenant diff"""
        if diff.change_type == ChangeType.CREATE:
            self.console.print(f"[green]+ Tenant: {diff.tenant_id}[/green]")
            self.console.print("  [green]Create new tenant[/green]")

        elif diff.change_type == ChangeType.UPDATE:
            self.console.print(f"[yellow]~ Tenant: {diff.tenant_id}[/yellow]")
            for field_diff in diff.field_diffs:
                self._display_field_diff(field_diff)

        elif diff.change_type == ChangeType.DELETE:
            self.console.print(f"[red]- Tenant: {diff.tenant_id}[/red]")
            self.console.print("  [red]Delete tenant (not in config)[/red]")

        self.console.print()

    def _display_field_diff(self, field_diff: FieldDiff) -> None:
        """Display single field diff"""
        old = self._format_value(field_diff.old_value)
        new = self._format_value(field_diff.new_value)

        self.console.print(
            f"  [yellow]~ {field_diff.field_name}: "
            f"{old} → {new}[/yellow]"
        )

    def _format_value(self, value: Any) -> str:
        """Format value for display"""
        if isinstance(value, list):
            return f"[{', '.join(repr(v) for v in value)}]"
        elif isinstance(value, dict):
            items = [f"{k}={v}" for k, v in value.items()]
            return f"{{{', '.join(items)}}}"
        else:
            return repr(value)
```

---

### Backup and Restore

#### Backup Service

```python
from pathlib import Path
import json
from datetime import datetime

class BackupService:
    """Service for creating and restoring backups"""

    def __init__(self, backup_dir: Path = Path(".descope-backups")):
        self.backup_dir = backup_dir
        self.backup_dir.mkdir(exist_ok=True)

    def create_backup(
        self,
        operation_name: str,
        project_state: ProjectState
    ) -> BackupId:
        """Create backup of current state"""
        timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
        filename = f"{timestamp}_pre-{operation_name}.json"
        filepath = self.backup_dir / filename

        # Include Git commit hash if in repo
        git_commit = self._get_git_commit()

        backup_data = {
            "version": "1.0",
            "operation": operation_name,
            "timestamp": timestamp,
            "git_commit": git_commit,
            "project_id": project_state.project_id,
            "tenants": [self._serialize_tenant(t) for t in project_state.tenants.values()],
            "flows": [self._serialize_flow(f) for f in project_state.flows.values()],
        }

        with filepath.open("w") as f:
            json.dump(backup_data, f, indent=2)

        return BackupId(filepath)

    def restore_backup(self, backup_id: BackupId) -> ProjectState:
        """Restore state from backup"""
        with backup_id.filepath.open() as f:
            backup_data = json.load(f)

        tenants = [
            self._deserialize_tenant(t) for t in backup_data["tenants"]
        ]
        flows = [
            self._deserialize_flow(f) for f in backup_data["flows"]
        ]

        return ProjectState(
            project_id=backup_data["project_id"],
            tenants={t.id: t for t in tenants},
            flows={f.name: f for f in flows},
            fetched_at=datetime.fromisoformat(backup_data["timestamp"])
        )

    def list_backups(self) -> list[BackupMetadata]:
        """List available backups"""
        backups = []
        for filepath in sorted(self.backup_dir.glob("*.json"), reverse=True):
            with filepath.open() as f:
                data = json.load(f)

            backups.append(BackupMetadata(
                filepath=filepath,
                operation=data["operation"],
                timestamp=datetime.fromisoformat(data["timestamp"]),
                git_commit=data.get("git_commit"),
                project_id=data["project_id"]
            ))

        return backups

    def _get_git_commit(self) -> Optional[str]:
        """Get current Git commit hash"""
        try:
            import subprocess
            result = subprocess.run(
                ["git", "rev-parse", "HEAD"],
                capture_output=True,
                text=True,
                check=True
            )
            return result.stdout.strip()
        except (subprocess.CalledProcessError, FileNotFoundError):
            return None
```

---

### Retry and Rate Limiting

#### Retry Decorator with Tenacity

```python
from tenacity import (
    retry,
    stop_after_attempt,
    wait_exponential,
    retry_if_exception_type,
    before_sleep_log,
    after_log
)
import structlog

logger = structlog.get_logger()

def retry_on_rate_limit(func):
    """Decorator to retry on rate limit errors"""
    return retry(
        retry=retry_if_exception_type(RateLimitError),
        stop=stop_after_attempt(5),
        wait=wait_exponential(multiplier=1, min=1, max=60),
        before_sleep=before_sleep_log(logger, logging.WARNING),
        after=after_log(logger, logging.INFO)
    )(func)

# Usage
@retry_on_rate_limit
def create_tenant(client: DescopeApiClient, config: TenantConfig) -> Tenant:
    """Create tenant with automatic retry on rate limits"""
    return client.create_tenant(config)
```

---

#### Rate Limit Tracker

```python
from collections import deque
from time import time, sleep

class RateLimiter:
    """Track and enforce rate limits"""

    def __init__(self, max_requests: int, time_window: int):
        """
        Args:
            max_requests: Maximum requests allowed
            time_window: Time window in seconds
        """
        self.max_requests = max_requests
        self.time_window = time_window
        self.requests: deque[float] = deque()

    def acquire(self) -> None:
        """Wait if necessary to respect rate limit"""
        now = time()

        # Remove requests outside time window
        while self.requests and self.requests[0] < now - self.time_window:
            self.requests.popleft()

        # If at limit, wait
        if len(self.requests) >= self.max_requests:
            sleep_time = self.requests[0] + self.time_window - now
            if sleep_time > 0:
                logger.debug(
                    "Rate limit reached, sleeping",
                    sleep_seconds=sleep_time,
                    requests_in_window=len(self.requests)
                )
                sleep(sleep_time)
                # Recursively call to re-check after sleep
                return self.acquire()

        # Record this request
        self.requests.append(time())

    @property
    def current_rate(self) -> int:
        """Get current request count in time window"""
        now = time()
        return sum(1 for t in self.requests if t >= now - self.time_window)

# Usage in API client
class DescopeApiClient:
    def __init__(self, project_id: str, management_key: str):
        self._client = DescopeClient(project_id, management_key)
        # 200 requests per 60 seconds for tenant operations
        self._rate_limiter = RateLimiter(max_requests=200, time_window=60)

    def create_tenant(self, config: TenantConfig) -> Tenant:
        self._rate_limiter.acquire()  # Wait if necessary
        return self._client.mgmt.tenant.create(...)
```

---

## Implementation Plan

### Phase 1: Foundation (MVP) - Weeks 1-2

**Goal**: Basic working CLI with tenant create/list/sync commands

#### Week 1: Core Infrastructure

**Tasks**:
1. Project setup
   - Update `pyproject.toml` with correct package name and dependencies
   - Configure entry point: `descope-mgmt = "descope_mgmt.cli.main:cli"`
   - Set up pre-commit hooks
   - Create directory structure (cli/, domain/, api/, utils/)

2. Configuration models
   - Implement Pydantic models (TenantConfig, FlowConfig, DescopeConfig)
   - Add field validators (tenant ID pattern, domain format)
   - Implement environment variable substitution
   - Write unit tests for models (15+ test cases)

3. Config loading
   - Implement YAML config loader
   - Config file discovery (search order)
   - Environment-specific overrides
   - Error handling for invalid configs
   - Write unit tests (10+ test cases)

4. Descope SDK integration
   - Create DescopeApiClient wrapper
   - Implement tenant API operations (load, create, list)
   - Error translation (SDK exceptions → domain exceptions)
   - Write unit tests with mocked SDK (10+ test cases)

**Deliverables**:
- ✅ Config models with validation
- ✅ Config loader with env var substitution
- ✅ API client wrapper with error handling
- ✅ 35+ unit tests passing
- ✅ Pre-commit hooks configured

---

#### Week 2: CLI Commands

**Tasks**:
1. CLI framework
   - Create Click app with command groups (project, tenant, flow)
   - Implement global options (--config, --dry-run, --yes, --log-level)
   - Set up structured logging (console + file)
   - Exit code handling

2. Tenant commands
   - `tenant list`: Display tenants in table format
   - `tenant create`: Create single tenant from CLI args
   - Basic error handling and user feedback

3. State management
   - Implement StateService to fetch current state
   - Implement DiffService to calculate diffs
   - Display diffs with Rich library (colors, formatting)

4. Testing
   - Integration tests with mocked Descope API
   - CLI tests with Click's CliRunner
   - End-to-end test: load config → calculate diff → display

**Deliverables**:
- ✅ Working `descope-mgmt tenant list` command
- ✅ Working `descope-mgmt tenant create` command
- ✅ Diff calculation and display
- ✅ 20+ integration tests passing
- ✅ Manual testing with real Descope project (optional)

---

### Phase 2: Safety & Observability - Weeks 3-4

**Goal**: Production-ready with safety mechanisms and rich observability

#### Week 3: Safety Mechanisms

**Tasks**:
1. Backup service
   - Implement BackupService (create, restore, list)
   - Backup before modify/delete operations
   - Git commit hash in backup metadata
   - Restore command for rollbacks

2. Idempotent operations
   - Implement Operation ABC and strategy pattern
   - CreateTenantOperation with existence check
   - UpdateTenantOperation with deep comparison
   - DeleteTenantOperation with confirmation
   - Write tests for each operation type (15+ tests)

3. `tenant sync` command
   - Implement full sync workflow:
     1. Load config
     2. Fetch current state
     3. Calculate diff
     4. Display diff
     5. Confirm (unless --yes)
     6. Create backup
     7. Apply operations
     8. Display summary
   - Handle partial failures (some tenants succeed, some fail)
   - Write integration tests (10+ scenarios)

4. Confirmation prompts
   - Implement confirmation for destructive operations
   - Show impact assessment ("This will delete 5 tenants")
   - Respect --yes flag to skip prompts

**Deliverables**:
- ✅ Working `descope-mgmt tenant sync` command (idempotent)
- ✅ Automatic backups before changes
- ✅ Confirmation prompts for destructive operations
- ✅ 25+ tests for safety mechanisms

---

#### Week 4: Observability

**Tasks**:
1. Structured logging
   - Set up structlog with JSON formatter
   - Log all operations (start, success, failure)
   - Include context (tenant IDs, operation names, durations)
   - Log to both console (pretty) and file (JSON)

2. Progress indicators
   - Implement progress bars with Rich library
   - Show progress for batch operations (creating 50 tenants)
   - Display estimated time remaining
   - Handle rate limits gracefully (pause indicator)

3. Operation summaries
   - Collect operation results (success, skipped, failed)
   - Display summary table at end
   - Include counts, durations, and next steps

4. Detailed error messages
   - Enhance error messages with context and suggestions
   - Example: "Tenant ID 'Invalid!' is invalid. Use lowercase alphanumeric with hyphens."
   - Add links to docs where helpful

5. Rate limit handling
   - Implement RateLimiter class
   - Integrate with API client
   - Test with high-volume operations (50+ tenants)

**Deliverables**:
- ✅ Structured logging (JSON + console)
- ✅ Progress indicators for batch operations
- ✅ Operation summaries after every command
- ✅ Detailed, actionable error messages
- ✅ Rate limit handling with automatic retry

---

### Phase 3: Flow Management - Weeks 5-6

**Goal**: Full flow deployment and management

#### Week 5: Flow Templates

**Tasks**:
1. Flow models
   - FlowConfig Pydantic model
   - FlowState domain model
   - Flow API operations (deploy, list, export)

2. Flow templates
   - Define supported templates (sign-up-or-in, mfa-login, magic-link, social-login)
   - Template metadata (description, required config fields)
   - Template validation

3. `flow list` command
   - List available templates
   - List deployed flows
   - Display template details

4. `flow deploy` command
   - Load flow config from YAML
   - Deploy flow templates to Descope
   - Handle flow configuration parameters
   - Dry-run support

**Deliverables**:
- ✅ Flow templates defined
- ✅ Working `descope-mgmt flow list` command
- ✅ Working `descope-mgmt flow deploy` command
- ✅ 15+ tests for flow operations

---

#### Week 6: Flow Import/Export

**Tasks**:
1. `flow export` command
   - Export deployed flows to YAML
   - Include flow configuration
   - Support exporting all flows or specific flows

2. Flow versioning
   - Track flow template versions
   - Detect version changes in diff
   - Warn on breaking changes

3. Flow rollback
   - Backup flows before deployment
   - Implement `flow rollback` command
   - Restore from backup

4. End-to-end testing
   - Test complete flow lifecycle (deploy → export → modify → redeploy)
   - Test rollback scenarios
   - Integration tests with mocked API

**Deliverables**:
- ✅ Working `descope-mgmt flow export` command
- ✅ Flow version tracking and warnings
- ✅ Flow rollback capability
- ✅ 20+ tests for flow management

---

### Phase 4: Polish & Documentation - Weeks 7-8

**Goal**: Production-ready with comprehensive documentation

#### Week 7: Polish

**Tasks**:
1. Configuration drift detection
   - Enhance `tenant sync --dry-run` to detect drift
   - Clear diff display for drift scenarios
   - Suggestions for resolving drift (apply config or update config)

2. Multi-environment support
   - Environment overrides in config
   - `--environment` flag implementation
   - Environment-specific validation (e.g., prod safeguards)

3. Performance optimization
   - Batch operations with ThreadPoolExecutor
   - Connection pooling for HTTP requests
   - Optimize large config file loading (streaming)

4. Error recovery
   - Better partial failure handling
   - Checkpoint-based recovery for long operations
   - Resume from checkpoint after failure

**Deliverables**:
- ✅ Configuration drift detection and reporting
- ✅ Multi-environment support
- ✅ Performance improvements for batch operations
- ✅ Enhanced error recovery

---

#### Week 8: Documentation

**Tasks**:
1. User documentation
   - README with quick start guide
   - Command reference (all commands with examples)
   - Configuration file reference (full YAML schema)
   - Common workflows (provision new environment, deploy flows, detect drift)
   - Troubleshooting guide (common errors and solutions)

2. Developer documentation
   - Architecture overview (three layers, design patterns)
   - Contributing guide (how to add new commands, patterns to follow)
   - Testing guide (how to run tests, write new tests)
   - Release process

3. Examples
   - Example config files (basic, multi-environment, complex)
   - Example commands for common tasks
   - Example CI/CD integration (GitHub Actions, GitLab CI)

4. CI/CD integration guide
   - Using in CI/CD pipelines
   - Secrets management (storing management keys)
   - Automated drift detection
   - Deployment workflows

**Deliverables**:
- ✅ Comprehensive README
- ✅ Full command reference
- ✅ Example config files and scripts
- ✅ CI/CD integration guide
- ✅ Developer documentation

---

## Testing Strategy

### Unit Testing

**Scope**: Pure business logic without external dependencies

**Framework**: pytest with pytest-mock

**Coverage Target**: >90% for domain layer, >80% overall

#### Test Organization

```
tests/unit/
├── domain/
│   ├── test_config_models.py       # Pydantic model validation
│   ├── test_diff_service.py        # Diff calculation logic
│   ├── test_state_service.py       # State management (mocked API)
│   ├── test_tenant_operations.py   # Operation strategy pattern
│   └── test_backup_service.py      # Backup/restore logic
├── api/
│   ├── test_descope_client.py      # API client wrapper (mocked SDK)
│   ├── test_retry_logic.py         # Retry with exponential backoff
│   └── test_rate_limiter.py        # Rate limit tracking
└── utils/
    ├── test_config_loader.py       # Config file loading
    ├── test_env_vars.py            # Environment variable substitution
    └── test_display.py             # Rich terminal output formatting
```

#### Example Unit Test

```python
# tests/unit/domain/test_config_models.py
import pytest
from pydantic import ValidationError
from descope_mgmt.domain.models.config import TenantConfig

def test_tenant_config_valid():
    """Valid tenant config passes validation"""
    config = TenantConfig(
        id="acme-corp",
        name="Acme Corporation",
        domains=["acme.com"],
        self_provisioning=True
    )
    assert config.id == "acme-corp"
    assert config.name == "Acme Corporation"

def test_tenant_config_invalid_id():
    """Tenant ID with uppercase or special chars fails validation"""
    with pytest.raises(ValidationError) as exc_info:
        TenantConfig(
            id="Acme Corp!",  # Invalid: uppercase, space, special char
            name="Acme Corporation"
        )

    errors = exc_info.value.errors()
    assert len(errors) == 1
    assert "pattern" in errors[0]["type"]

def test_tenant_config_invalid_domain():
    """Invalid domain format fails validation"""
    with pytest.raises(ValidationError) as exc_info:
        TenantConfig(
            id="acme-corp",
            name="Acme Corporation",
            domains=["invalid..domain"]  # Invalid: consecutive dots
        )

    errors = exc_info.value.errors()
    assert "Invalid domain format" in str(errors)

def test_tenant_config_immutable():
    """Tenant config is immutable (frozen=True)"""
    config = TenantConfig(id="acme-corp", name="Acme")

    with pytest.raises(ValidationError):
        config.name = "New Name"  # Should fail due to frozen=True
```

---

### Integration Testing

**Scope**: Multi-component workflows with mocked external APIs

**Framework**: pytest with responses library (mock HTTP) or pytest-mock

**Coverage Target**: All CLI commands, all API operations

#### Test Organization

```
tests/integration/
├── cli/
│   ├── test_tenant_commands.py     # Full tenant command workflows
│   ├── test_flow_commands.py       # Full flow command workflows
│   └── test_project_commands.py    # Project management commands
├── workflows/
│   ├── test_tenant_sync.py         # Complete sync workflow
│   ├── test_drift_detection.py     # Drift detection workflow
│   └── test_backup_restore.py      # Backup and restore workflow
└── error_scenarios/
    ├── test_partial_failures.py    # Some operations succeed, some fail
    ├── test_rate_limits.py         # Rate limit handling
    └── test_network_errors.py      # Network failures and retries
```

#### Example Integration Test

```python
# tests/integration/cli/test_tenant_commands.py
from click.testing import CliRunner
import pytest
from descope_mgmt.cli.main import cli

@pytest.fixture
def mock_descope_api(mocker):
    """Mock Descope API responses"""
    mock_client = mocker.patch('descope_mgmt.api.descope_client.DescopeClient')

    # Mock tenant list (empty initially)
    mock_client.return_value.mgmt.tenant.load_all.return_value = {
        "tenants": []
    }

    # Mock tenant create (success)
    mock_client.return_value.mgmt.tenant.create.return_value = {
        "id": "acme-corp",
        "name": "Acme Corporation",
        "createdTime": 1699999999
    }

    return mock_client

@pytest.fixture
def sample_config(tmp_path):
    """Create a sample config file"""
    config_file = tmp_path / "descope.yaml"
    config_file.write_text("""
version: "1.0"
auth:
  project_id: "P2test123"
  management_key: "K2test456"
tenants:
  - id: "acme-corp"
    name: "Acme Corporation"
    domains: ["acme.com"]
    self_provisioning: true
""")
    return config_file

def test_tenant_list_empty(mock_descope_api, sample_config):
    """List tenants when none exist"""
    runner = CliRunner()
    result = runner.invoke(cli, [
        'tenant', 'list',
        '--config', str(sample_config)
    ])

    assert result.exit_code == 0
    assert "Total: 0 tenants" in result.output

def test_tenant_sync_create(mock_descope_api, sample_config):
    """Sync creates new tenant"""
    runner = CliRunner()

    # Dry-run first
    result = runner.invoke(cli, [
        'tenant', 'sync',
        '--config', str(sample_config),
        '--dry-run'
    ])

    assert result.exit_code == 0
    assert "+ 1 tenant to create" in result.output
    assert "acme-corp" in result.output

    # Apply changes
    result = runner.invoke(cli, [
        'tenant', 'sync',
        '--config', str(sample_config),
        '--yes'  # Skip confirmation
    ])

    assert result.exit_code == 0
    assert "✓ 1 tenant created" in result.output

    # Verify API was called
    mock_descope_api.return_value.mgmt.tenant.create.assert_called_once()

def test_tenant_sync_idempotent(mock_descope_api, sample_config):
    """Running sync twice doesn't duplicate tenants"""
    runner = CliRunner()

    # First sync
    result = runner.invoke(cli, [
        'tenant', 'sync',
        '--config', str(sample_config),
        '--yes'
    ])
    assert result.exit_code == 0

    # Mock tenant now exists
    mock_descope_api.return_value.mgmt.tenant.load.return_value = {
        "id": "acme-corp",
        "name": "Acme Corporation",
        "domains": ["acme.com"],
        "selfProvisioning": True
    }

    # Second sync (should detect no changes)
    result = runner.invoke(cli, [
        'tenant', 'sync',
        '--config', str(sample_config),
        '--yes'
    ])

    assert result.exit_code == 0
    assert "⊘ 1 tenant skipped (no changes)" in result.output or "No changes" in result.output
```

---

### Fixture Organization

```python
# tests/fixtures/conftest.py
import pytest
from pathlib import Path

@pytest.fixture
def sample_tenants():
    """Sample tenant configurations"""
    return [
        {"id": "acme-corp", "name": "Acme Corporation", "domains": ["acme.com"]},
        {"id": "widget-co", "name": "Widget Company", "domains": ["widget.io"]},
    ]

@pytest.fixture
def sample_config_data(sample_tenants):
    """Sample complete configuration"""
    return {
        "version": "1.0",
        "auth": {
            "project_id": "P2test123",
            "management_key": "K2test456"
        },
        "tenants": sample_tenants
    }

@pytest.fixture
def mock_api_responses():
    """Fixture providing mock API response data"""
    return {
        "tenant_list_empty": {"tenants": []},
        "tenant_list_with_data": {
            "tenants": [
                {
                    "id": "acme-corp",
                    "name": "Acme Corporation",
                    "domains": ["acme.com"],
                    "selfProvisioning": True,
                    "createdTime": 1699999999,
                    "updatedTime": 1699999999
                }
            ]
        },
        "tenant_create_success": {
            "id": "acme-corp",
            "name": "Acme Corporation",
            "createdTime": 1699999999
        },
        "rate_limit_error": {
            "errorCode": "rate_limit_exceeded",
            "message": "Rate limit exceeded",
            "statusCode": 429
        }
    }
```

---

### Test Coverage Requirements

**Minimum Coverage**:
- Overall: 85%
- Domain layer: 90% (critical business logic)
- API layer: 80%
- CLI layer: 70% (harder to test UI interactions)
- Utils: 85%

**Critical Paths (100% Coverage Required)**:
- Idempotency checks (Operation.is_needed)
- Backup before changes
- Error translation (API errors → domain errors)
- Configuration validation
- Diff calculation

**Coverage Reporting**:
```bash
# Run tests with coverage
pytest --cov=src/descope_mgmt --cov-report=html --cov-report=term-missing

# View HTML report
open htmlcov/index.html
```

---

### TDD Workflow

Follow strict TDD for all new features:

1. **RED**: Write failing test first
   - Write test that describes desired behavior
   - Run test, verify it fails (no implementation yet)

2. **GREEN**: Write minimal code to pass
   - Implement just enough to make test pass
   - No premature optimization
   - Run test, verify it passes

3. **REFACTOR**: Improve code while keeping tests green
   - Clean up implementation
   - Extract functions/classes
   - Run tests continuously to ensure still passing

**Example TDD Cycle**:

```python
# Step 1: RED - Write failing test
def test_calculate_tenant_diff_detects_name_change():
    current = TenantState(id="acme-corp", name="Acme")
    desired = TenantConfig(id="acme-corp", name="Acme Corporation")

    diff = DiffService().calculate_tenant_diff(current, desired)

    assert diff.change_type == ChangeType.UPDATE
    assert len(diff.field_diffs) == 1
    assert diff.field_diffs[0].field_name == "name"
    assert diff.field_diffs[0].old_value == "Acme"
    assert diff.field_diffs[0].new_value == "Acme Corporation"

# Run test: FAILS (method doesn't exist yet)

# Step 2: GREEN - Implement minimal code
class DiffService:
    def calculate_tenant_diff(
        self,
        current: TenantState,
        desired: TenantConfig
    ) -> TenantDiff:
        field_diffs = []

        if current.name != desired.name:
            field_diffs.append(FieldDiff("name", current.name, desired.name))

        if field_diffs:
            return TenantDiff(
                tenant_id=current.id,
                change_type=ChangeType.UPDATE,
                field_diffs=field_diffs
            )

        return TenantDiff(
            tenant_id=current.id,
            change_type=ChangeType.NO_CHANGE,
            field_diffs=[]
        )

# Run test: PASSES

# Step 3: REFACTOR - Extract helper method
class DiffService:
    def calculate_tenant_diff(
        self,
        current: TenantState,
        desired: TenantConfig
    ) -> TenantDiff:
        field_diffs = self._compare_tenant_fields(current, desired)

        if field_diffs:
            return TenantDiff(
                tenant_id=current.id,
                change_type=ChangeType.UPDATE,
                field_diffs=field_diffs
            )

        return TenantDiff(
            tenant_id=current.id,
            change_type=ChangeType.NO_CHANGE,
            field_diffs=[]
        )

    def _compare_tenant_fields(
        self,
        current: TenantState,
        desired: TenantConfig
    ) -> list[FieldDiff]:
        diffs = []

        if current.name != desired.name:
            diffs.append(FieldDiff("name", current.name, desired.name))

        return diffs

# Run test: STILL PASSES
```

---

## Operational Considerations

### Deployment

#### Installation

```bash
# Install from PyPI (when published)
pip install pcc-descope-mgmt

# Install from source (development)
git clone https://github.com/your-org/pcc-descope-mgmt.git
cd pcc-descope-mgmt
pip install -e .

# Verify installation
descope-mgmt --version
```

---

#### Configuration Management

**Recommended Setup**:

```
project-root/
├── .descope/
│   ├── config.yaml           # Shared base config
│   ├── dev.yaml              # Dev environment overrides
│   ├── staging.yaml          # Staging overrides
│   └── prod.yaml             # Production overrides
├── .env                      # Environment variables (gitignored)
└── .env.example              # Template for .env
```

**Environment Variables**:
```bash
# .env.example
DESCOPE_PROJECT_ID=P2your-project-id
DESCOPE_MANAGEMENT_KEY=K2your-management-key
DESCOPE_ENVIRONMENT=dev
```

**CI/CD Secrets**:
- Store management keys in CI/CD secrets (GitHub Secrets, GitLab Variables, etc.)
- Never commit management keys to version control
- Use separate management keys per environment
- Rotate keys regularly (every 90 days)

---

### Monitoring and Observability

#### Log Files

```
logs/
├── descope-mgmt.log          # JSON structured logs
└── descope-mgmt-debug.log    # Verbose debug logs
```

**Log Rotation**: Use logrotate or equivalent:
```
# /etc/logrotate.d/descope-mgmt
/path/to/logs/descope-mgmt.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
}
```

---

#### Audit Trail

All operations logged with:
- Timestamp (ISO 8601 with timezone)
- User (from environment or Git config)
- Operation (create, update, delete)
- Resources affected (tenant IDs, flow names)
- Success/failure status
- Duration

**Example Audit Log Entry**:
```json
{
  "timestamp": "2025-11-10T14:30:15Z",
  "level": "INFO",
  "operation": "tenant.sync",
  "user": "engineer@portco.com",
  "git_commit": "abc123...",
  "environment": "production",
  "resources": ["acme-corp", "widget-co"],
  "changes": {
    "created": 1,
    "updated": 1,
    "deleted": 0
  },
  "duration_ms": 3200,
  "status": "success"
}
```

---

### Disaster Recovery

#### Backup Strategy

**Automatic Backups**:
- Before every modify/delete operation
- Stored locally in `.descope-backups/`
- Retention: Keep last 30 days, then archive

**Manual Backups**:
```bash
# Export all configuration
descope-mgmt project export --output backup-$(date +%Y%m%d).yaml --include-tenants --include-flows

# Archive backups
tar -czf descope-backups-$(date +%Y%m%d).tar.gz .descope-backups/
```

**Backup to Cloud Storage**:
```bash
# Upload to S3/GCS
aws s3 cp .descope-backups/ s3://your-bucket/descope-backups/ --recursive
# or
gsutil -m cp -r .descope-backups/ gs://your-bucket/descope-backups/
```

---

#### Restore Procedures

**Restore from Recent Backup**:
```bash
# List available backups
descope-mgmt backup list

# Restore specific backup
descope-mgmt backup restore --backup .descope-backups/2025-11-10_14-30-15_pre-tenant-sync.json
```

**Restore from Exported Config**:
```bash
# Re-apply exported config
descope-mgmt tenant sync --config backup-20251110.yaml --yes
descope-mgmt flow deploy --config backup-20251110.yaml --yes
```

---

### Performance Tuning

#### Batch Operation Optimization

For large tenant counts (100+):

```yaml
# config.yaml
performance:
  batch_size: 50          # Process 50 tenants per batch
  max_workers: 10         # 10 concurrent API calls
  rate_limit_buffer: 0.8  # Use 80% of rate limit (safety margin)
```

---

#### Connection Pooling

```python
# Default connection pool settings
session = requests.Session()
adapter = HTTPAdapter(
    pool_connections=10,   # Keep 10 connection pools
    pool_maxsize=20,       # Max 20 connections per pool
    max_retries=3          # Retry failed connections
)
session.mount('https://', adapter)
```

---

### Security Considerations

#### Management Key Security

**DO**:
- Store keys in environment variables or secrets management
- Use separate keys per environment
- Rotate keys every 90 days
- Use least-privilege keys (limit to required operations)

**DON'T**:
- Commit keys to version control
- Share keys across environments
- Use production keys in development
- Log management keys (sanitize in logs)

---

#### Configuration File Security

**DO**:
- Version control config files (safe, no secrets)
- Review config changes via pull requests
- Use environment variable substitution for secrets
- Validate configs in CI/CD before deployment

**DON'T**:
- Put secrets directly in config files
- Share production configs publicly
- Skip validation before applying

---

## Appendices

### Appendix A: Full Command Reference

See [CLI Command Reference](#cli-command-reference) section above for complete command documentation.

---

### Appendix B: Configuration Schema Reference

See [Configuration File Schema](#configuration-file-schema) section above for full YAML schema.

---

### Appendix C: Error Code Reference

| Exit Code | Name | Description | Example |
|-----------|------|-------------|---------|
| 0 | SUCCESS | Operation completed successfully | Tenants synced |
| 1 | CONFIGURATION_ERROR | Invalid config file or validation failure | Missing required field |
| 2 | API_ERROR | Descope API returned error | Network failure |
| 3 | OPERATION_FAILED | Operation failed during execution | Partial failure |
| 4 | RATE_LIMIT_ERROR | Rate limit exceeded after retries | Too many requests |
| 5 | VALIDATION_ERROR | Business rule validation failed | Duplicate tenant ID |

---

### Appendix D: API Rate Limits

| Endpoint | Limit | Window | Backoff on 429 |
|----------|-------|--------|----------------|
| `/mgmt/tenant/*` | 200 req | 60s | 60s |
| `/mgmt/user/*` (generic) | 500 req | 60s | 60s |
| `/mgmt/user/create` | 100 req | 60s | 60s |
| `/mgmt/user/update` | 200 req | 60s | 60s |
| Backend SDK (general) | 1000 req | 10s | Exponential |

**Recommendation**: Stay under 80% of limits to avoid 429 responses.

---

### Appendix E: Pydantic Model Reference

#### TenantConfig

```python
class TenantConfig(BaseModel):
    id: str                         # Required, pattern: ^[a-z0-9-]+$, 3-50 chars
    name: str                       # Required, 1-100 chars
    domains: list[str] = []         # Optional, valid DNS names
    self_provisioning: bool = False # Optional, default False
    custom_attributes: dict = {}    # Optional, arbitrary key-value pairs
```

#### FlowConfig

```python
class FlowConfig(BaseModel):
    template: Literal[              # Required, one of:
        "sign-up-or-in",
        "mfa-login",
        "magic-link",
        "social-login"
    ]
    name: str                       # Required, display name
    enabled: bool = True            # Optional, default True
    config: dict = {}               # Optional, template-specific config
```

#### DescopeConfig

```python
class DescopeConfig(BaseModel):
    version: Literal["1.0"] = "1.0"             # Required, schema version
    auth: AuthConfig                            # Required, auth credentials
    environments: dict[str, EnvironmentConfig] = {}  # Optional, env overrides
    tenants: list[TenantConfig] = []            # Optional, tenant definitions
    flows: list[FlowConfig] = []                # Optional, flow definitions
```

---

### Appendix F: Troubleshooting Guide

#### Common Issues

**Issue**: `ConfigurationError: DESCOPE_PROJECT_ID environment variable not set`

**Solution**:
```bash
# Set environment variable
export DESCOPE_PROJECT_ID=P2your-project-id

# Or provide in config file
# auth:
#   project_id: "P2your-project-id"
```

---

**Issue**: `RateLimitError: Rate limit exceeded after 5 retries`

**Solution**:
- Reduce batch size in config
- Increase delay between operations
- Check if multiple processes are hitting same API

---

**Issue**: `ResourceConflictError: Tenant 'acme-corp' already exists`

**Solution**:
- Use `tenant sync` instead of `tenant create` (idempotent)
- Check if tenant was created in previous run
- Verify tenant ID in Descope console

---

**Issue**: `ValidationError: Tenant ID 'Acme Corp' is invalid`

**Solution**:
- Use lowercase alphanumeric with hyphens only
- Example: `acme-corp` (not `Acme Corp` or `acme_corp`)

---

### Appendix G: CI/CD Integration Example

#### GitHub Actions

```yaml
# .github/workflows/descope-sync.yml
name: Sync Descope Configuration

on:
  push:
    branches: [main]
    paths:
      - 'descope/*.yaml'

jobs:
  sync:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - uses: actions/setup-python@v4
        with:
          python-version: '3.12'

      - name: Install descope-mgmt
        run: pip install pcc-descope-mgmt

      - name: Validate config
        run: descope-mgmt project validate --config descope/prod.yaml

      - name: Dry-run sync
        run: descope-mgmt tenant sync --config descope/prod.yaml --dry-run
        env:
          DESCOPE_PROJECT_ID: ${{ secrets.DESCOPE_PROJECT_ID }}
          DESCOPE_MANAGEMENT_KEY: ${{ secrets.DESCOPE_MANAGEMENT_KEY }}

      - name: Apply changes
        run: descope-mgmt tenant sync --config descope/prod.yaml --yes
        env:
          DESCOPE_PROJECT_ID: ${{ secrets.DESCOPE_PROJECT_ID }}
          DESCOPE_MANAGEMENT_KEY: ${{ secrets.DESCOPE_MANAGEMENT_KEY }}

      - name: Upload backup
        uses: actions/upload-artifact@v3
        with:
          name: descope-backup
          path: .descope-backups/
```

---

### Appendix H: Related Documents

- **Business Requirements**: `.claude/docs/business-requirements-analysis.md`
- **Python Technical Analysis**: `docs/python-technical-analysis.md`
- **Master CLAUDE.md**: `/home/jfogarty/pcc/CLAUDE.md`
- **Project CLAUDE.md**: `CLAUDE.md`

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-11-10 | Claude (with business-analyst, python-pro) | Initial comprehensive design |

---

**End of Design Document**
