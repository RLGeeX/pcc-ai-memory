# pcc-descope-mgmt Consolidated Design Document

**Version**: 2.0 (Consolidated)
**Date**: 2025-11-10
**Status**: Approved for Implementation
**Timeline**: 10 Weeks

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

---

## Executive Summary

`pcc-descope-mgmt` is a Python CLI tool that transforms Descope authentication infrastructure management from error-prone manual operations into reliable, auditable, code-managed workflows. The tool enables developers to declaratively manage Descope projects, tenants, and authentication flows through YAML configuration files with full idempotency, safety mechanisms, and observability.

### Key Value Propositions

- **Time Savings**: Reduce environment provisioning from 2-4 hours to <5 minutes
- **Risk Reduction**: 80% fewer manual operations with built-in safety nets
- **Compliance**: 100% audit trails for all infrastructure changes
- **Developer Experience**: Intelligent defaults, rich feedback, and self-service capabilities

### Target Users

DevOps engineers, backend developers, security engineers, platform engineers

### Core Capabilities

1. Create and manage Descope projects programmatically
2. Create/update/delete tenants with configuration-as-code
3. Deploy authentication flow templates (login, MFA, sign-up)
4. Detect and remediate configuration drift
5. Backup/restore Descope configurations
6. Multi-environment support (dev, staging, prod)

### Distribution Strategy

**Internal deployment only**: Tool installed on shared NFS mount at `/home/jfogarty/pcc/core/pcc-descope-mgmt`. Both team users access from same location via editable install (`pip install -e .`). No PyPI distribution or git clones required.

---

## Project Overview

### Background

The PortCo Connect (PCC) platform requires managing authentication infrastructure across **5 environments** (test, devtest, dev, staging, prod) and **multiple portfolio companies**. Each environment has its own Descope project, and each portfolio company requires a tenant within each project.

**Environment Structure**:
- **test**: API testing and integration tests
- **devtest**: Initial development work
- **dev**: CI/CD development environment
- **staging**: QA and UAT
- **prod**: Production

**Tenant Structure**:
- Each portfolio company/entity = 1 tenant per environment
- Tenants may or may not have their own SSO
- All SSO configuration is manual (too complex to automate)

**Why This Tool Exists**:
- Descope free plan doesn't support Terraform
- Manual management through console is time-consuming (hours per environment)
- Error-prone (typos, inconsistent settings across environments)
- Not auditable (no version control)
- Difficult to replicate configurations across 5 environments

### Goals

**Primary Goal**: Provide a CLI tool that makes Descope infrastructure management as easy and safe as managing infrastructure-as-code with Terraform (replacement for Terraform on free plan).

**Secondary Goals**:
- Enable rapid environment provisioning (<5 minutes per environment)
- Reduce configuration errors by 80%+ through declarative config
- Provide 100% audit trail for compliance
- Support 5-environment workflows (test → devtest → dev → staging → prod)
- Enable configuration drift detection and remediation
- Maintain consistency across all 5 environments

### Scope Clarifications

**In Scope for v1.0**:
- ✅ Tenant management (create, update, delete, sync)
- ✅ Flow template deployment and management
- ✅ Configuration drift detection
- ✅ Backup/restore with Pydantic schemas
- ✅ Rate limiting using PyrateLimiter library
- ✅ Idempotent operations
- ✅ Local testing with pre-commit hooks

**Out of Scope for v1.0**:
- ❌ **SSO configuration management** (always manual - too complex to automate)
- ❌ **User creation/management** (handled by separate APIs outside this tool)
- ❌ **"Bring Your Own SSO" automation** (entities with their own SSO handle setup manually)
- ❌ Custom authentication flow builder UI
- ❌ Monitoring/alerting of Descope service health
- ❌ Migration from other auth providers
- ❌ CI/CD pipelines (local testing only)
- ❌ PyPI or git distribution (NFS mount only)

### SSO and User Management Context

**SSO Configuration** (Out of Scope):
- All SSO setup is manual (whether Google Workspace for PortCo or entity-specific)
- Too much back-and-forth with external identity providers
- Requires domain verification, certificate exchange, testing
- Must be done in Descope Console for each environment

**User Management** (Out of Scope):
- User creation handled by separate APIs
- This tool only manages the **infrastructure** (projects, tenants, flows)
- Think of it as "Terraform for Descope free plan" - infrastructure only

**What This Tool Does**:
- Manages the base Descope objects (projects, tenants, flows)
- Ensures consistency across 5 environments
- Detects configuration drift
- Provides backup/restore capabilities

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

### Use Cases

#### UC-1: New Environment Provisioning

**Actor**: DevOps Engineer
**Goal**: Provision complete authentication infrastructure for a new environment in <5 minutes

**Preconditions**:
- Descope account exists
- Management API key created
- YAML config file prepared
- SSO manually configured for primary tenant

**Main Flow**:
1. Engineer creates `descope-dev.yaml` with tenant definitions
2. Engineer runs `descope-mgmt tenant sync --config descope-dev.yaml --dry-run`
3. System displays diff showing resources to be created
4. Engineer confirms changes
5. System creates tenants with progress indicators
6. System displays operation summary with created resource IDs

**Success Criteria**:
- All resources created successfully
- Operation completes in <5 minutes
- Audit log entry created
- Backup of pre-operation state saved

---

#### UC-2: Multi-Tenant Application Setup

**Actor**: Backend Developer
**Goal**: Create tenant hierarchy for portfolio companies

**Main Flow**:
1. Developer defines 10 tenants in `tenants.yaml` with domains
2. Developer runs `descope-mgmt tenant sync --config tenants.yaml`
3. System validates configuration (no duplicate domains, valid tenant IDs)
4. System shows diff: 10 tenants to create
5. Developer confirms
6. System creates tenants with batch operations (respecting rate limits)
7. System displays summary: 10 created, 0 failed

**Error Scenarios**:
- Duplicate tenant ID → Validation error before API call
- Domain already claimed → Clear error indicating which tenant/domain conflicts
- Partial failure (7/10 succeed) → Summary shows 7 created, 3 failed; successful tenants not rolled back; developer can fix config and re-run (idempotent)

---

#### UC-3: Authentication Flow Synchronization

**Actor**: Security Engineer
**Goal**: Deploy updated MFA authentication flow across all environments

**Main Flow**:
1. Engineer updates `flows.yaml` to enable MFA with SMS + TOTP methods
2. Engineer runs `descope-mgmt flow deploy --config flows.yaml --environment staging --dry-run`
3. System shows flow configuration changes
4. Engineer confirms staging deployment
5. System deploys flow to staging with backup of old flow
6. Engineer repeats for production after validation
7. System provides rollback command if issues detected

---

#### UC-4: Configuration Drift Detection

**Actor**: Platform Engineer
**Goal**: Identify and remediate differences between code and live Descope state

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

---

### Business Rules

#### Resource Identification Constraints

1. **Tenant IDs**: Lowercase alphanumeric with hyphens, 3-50 characters, globally unique within project
2. **Project Names**: 1-100 characters, no special characters except spaces and hyphens
3. **Domain Validation**: Valid DNS format (RFC 1035), verified ownership before assignment
4. **Tenant Hierarchy**: Max 3 levels of nesting (parent → child → grandchild)

#### Change Management

1. **Confirmation Requirements**: Destructive operations (delete, replace) require confirmation unless `--yes` flag
2. **Audit Logging**: All operations logged with timestamp, user, operation, resources affected
3. **Backup Policy**: Automatic backup before any modify/delete operation using Pydantic schemas

#### Rate Limiting Compliance

1. **Batch Operations**: Respect Descope rate limits (200 req/60s for tenants) using PyrateLimiter library
2. **Retry Strategy**: Exponential backoff on 429 responses (1s, 2s, 4s, 8s, max 5 retries)
3. **Concurrent Limits**: Adaptive worker pools based on rate limits
4. **Rate Limiting at Submission**: Critical - rate limiting happens BEFORE submitting to thread pool, not in workers

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
- Display diff with color coding
- Prompt user:
  - **Option A**: Apply config (remove "acme.net")
  - **Option B**: Update config to match reality
  - **Option C**: Ignore (accept drift)
- Log drift detection and resolution choice

**Design Decision**: Never auto-resolve drift; always require explicit user choice

---

#### 3. API Rate Limiting

**Scenario**: Batch creating 50 tenants exceeds 200 req/60s limit

**System Behavior**:
- Use PyrateLimiter with InMemoryBucket for thread-safe tracking
- Apply rate limiting at submission time (before adding to thread pool)
- When approaching limit, adaptive throttling
- If 429 received, pause and display: "Rate limited, retrying in 5s..."
- Use exponential backoff: 1s, 2s, 4s, 8s
- Show progress indicator: "Created 30/50 tenants (rate limited, pausing...)"
- Resume after backoff period

**Design Decision**: Proactive throttling + reactive backoff; never fail due to rate limits

---

### User Experience Considerations

#### What Makes This Tool Delightful

1. **Intelligent Defaults**:
   - Auto-detect environment from Git branch name
   - Default config file discovery chain
   - Sensible defaults for all optional config fields

2. **Progressive Disclosure**:
   - Simple commands for common tasks
   - Advanced flags for power users
   - Help text shows examples

3. **Rich Feedback**:
   - Progress indicators with estimated time remaining
   - Color-coded diffs (green=add, yellow=modify, red=delete)
   - Operation summaries with counts

4. **Safety Nets**:
   - Dry-run mode shows changes without applying
   - Confirmation prompts with impact assessment
   - Automatic Pydantic-validated backups before destructive operations
   - Rollback commands provided after changes

---

## Technical Architecture

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
│  - Business logic (validation, backups with Pydantic)       │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                        API Layer                            │
│  - Descope SDK wrapper                                      │
│  - Retry logic (exponential backoff)                        │
│  - Rate limit handling (PyrateLimiter)                      │
│  - Error translation (API errors → domain errors)           │
└─────────────────────────────────────────────────────────────┘
                     │
                     ▼
              Descope Management API
```

### Design Patterns

#### 1. Protocol-Based Dependency Injection

```python
from typing import Protocol

class DescopeClient(Protocol):
    def load_tenant(self, tenant_id: str) -> Tenant: ...
    def create_tenant(self, tenant: TenantConfig) -> Tenant: ...

class TenantService:
    def __init__(self, client: DescopeClient):
        self._client = client
```

**Benefits**: Easy to mock for testing, type-safe, framework-agnostic domain layer

---

#### 2. Strategy Pattern for Idempotent Operations

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
```

---

### Code Structure

```
src/descope_mgmt/
├── __init__.py
├── types/                    # Shared protocols (imports nothing)
│   ├── __init__.py
│   └── protocols.py          # All Protocol definitions
├── cli/
│   ├── __init__.py
│   ├── main.py              # Click app entry point
│   ├── tenant.py            # Tenant subcommands
│   ├── flow.py              # Flow subcommands
│   └── common.py            # Shared CLI utilities
├── domain/                   # Business logic (imports only types/)
│   ├── models/
│   │   ├── __init__.py
│   │   ├── config.py        # Pydantic models for config files
│   │   ├── backup.py        # Pydantic models for backups
│   │   ├── tenant.py        # Tenant domain model
│   │   └── state.py         # State representation
│   ├── services/
│   │   ├── tenant_service.py
│   │   ├── flow_service.py
│   │   ├── diff_service.py
│   │   └── backup_service.py
│   └── operations/
│       ├── base.py
│       └── tenant_ops.py
├── api/                      # External calls (imports types/ and domain/models)
│   ├── descope_client.py    # Descope SDK wrapper
│   ├── rate_limit.py        # PyrateLimiter integration
│   └── retry.py             # Retry logic
└── utils/
    ├── logging.py
    ├── display.py
    └── config_loader.py
```

**Dependency Rules** (Import Cycle Prevention):
- `types/` imports nothing
- `domain/` imports only `types/`
- `api/` imports `types/` and `domain/models`
- `cli/` imports all layers
- NO circular imports possible

---

### Rate Limiting with PyrateLimiter

#### Implementation

```python
# src/descope_mgmt/api/rate_limit.py
from pyrate_limiter import (
    Limiter,
    InMemoryBucket,
    Rate,
    Duration,
    BucketFullException,
)
import structlog

logger = structlog.get_logger()

class DescopeRateLimiter:
    """
    Thread-safe rate limiter for Descope API calls.

    Uses PyrateLimiter's InMemoryBucket with sliding window algorithm.
    Designed for Descope's limits:
    - Tenant operations: 200 requests per 60 seconds
    - User operations: 500 requests per 60 seconds
    """

    def __init__(
        self,
        max_requests: int = 200,
        window_seconds: int = 60,
        resource_name: str = "descope-api"
    ):
        self.resource_name = resource_name
        self.max_requests = max_requests
        self.window_seconds = window_seconds

        # Define rate
        rate = Rate(max_requests, Duration.SECOND * window_seconds)

        # Create in-memory bucket (thread-safe)
        bucket = InMemoryBucket([rate])

        # Create limiter
        self._limiter = Limiter(bucket, raise_when_fail=True)
        self._lock = Lock()

    def acquire(self, weight: int = 1) -> None:
        """
        Acquire a rate limit token. Blocks if rate limit exceeded.
        """
        with self._lock:
            try:
                self._limiter.try_acquire(self.resource_name, weight=weight)
                logger.debug("Rate limit acquired", resource=self.resource_name)
            except BucketFullException as e:
                logger.warning("Rate limit exceeded", resource=self.resource_name)
                raise

class TenantRateLimiter(DescopeRateLimiter):
    """Rate limiter specifically for tenant operations (200 req/60s)"""
    def __init__(self):
        super().__init__(max_requests=200, window_seconds=60, resource_name="descope-tenant-api")
```

---

#### RateLimitedExecutor (CRITICAL FIX)

**Problem**: Original design had rate limiting inside thread workers, not at submission time.

**Solution**: Apply rate limiting BEFORE submitting to thread pool.

```python
# src/descope_mgmt/utils/concurrency.py
from concurrent.futures import ThreadPoolExecutor, Future
from pyrate_limiter import BucketFullException

class RateLimitedExecutor:
    """
    Thread pool executor with rate limiting applied at submission time.

    CRITICAL: Rate limiting happens BEFORE submitting tasks to pool,
    preventing queue buildup and ensuring API rate limits are respected.
    """

    def __init__(self, max_workers: int, rate_limiter: DescopeRateLimiter):
        self._executor = ThreadPoolExecutor(max_workers=max_workers)
        self._rate_limiter = rate_limiter

    def submit(
        self,
        fn: Callable[..., T],
        *args: Any,
        weight: int = 1,
        **kwargs: Any
    ) -> Future[T]:
        """
        Submit a callable with rate limiting.

        CRITICAL: Acquires rate limit token BEFORE submitting to executor.
        """
        # Acquire rate limit token BEFORE submission
        try:
            self._rate_limiter.acquire(weight=weight)
        except BucketFullException:
            logger.warning("Rate limit exceeded during submission", function=fn.__name__)
            raise

        # Now submit to executor
        future = self._executor.submit(fn, *args, **kwargs)
        logger.debug("Task submitted", function=fn.__name__)
        return future
```

#### Adaptive Worker Pool Sizing

```python
def calculate_optimal_workers(
    rate_limit: int,
    window_seconds: int,
    avg_request_latency: float = 0.5,
    safety_factor: float = 0.8
) -> int:
    """
    Calculate optimal worker pool size based on rate limits.

    Example:
        >>> calculate_optimal_workers(200, 60, 0.5, 0.8)
        2  # 200 req/60s * 0.8 * 0.5s latency = 1.33 workers, round up to 2
    """
    requests_per_second = rate_limit / window_seconds
    theoretical_workers = requests_per_second * avg_request_latency * safety_factor
    optimal = max(1, min(20, int(theoretical_workers) + 1))
    return optimal
```

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
```

---

### Type Safety

#### Pydantic Models with Strict Validation

```python
from pydantic import BaseModel, Field, field_validator, ConfigDict

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
    name: str = Field(..., min_length=1, max_length=100)
    domains: list[str] = Field(default_factory=list)
    self_provisioning: bool = Field(default=False)
    custom_attributes: dict[str, Any] = Field(default_factory=dict)

    @field_validator('domains')
    @classmethod
    def validate_domains(cls, v: list[str]) -> list[str]:
        """Validate domain format"""
        domain_pattern = re.compile(r'^(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$')
        for domain in v:
            if not domain_pattern.match(domain):
                raise ValueError(f"Invalid domain format: {domain}")
        return v
```

---

### Performance Considerations

#### Synchronous Implementation

**Decision**: Use synchronous code (no async/await)

**Rationale**:
- Descope SDK is synchronous
- Wrapping sync SDK in async adds complexity without benefit
- CLI tool typically runs one operation at a time
- Batch operations use threading with RateLimitedExecutor

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

# Rate limiting (CRITICAL UPDATE)
pyrate-limiter>=3.1.0

# Environment variables
python-dotenv>=1.0.0
```

#### Development Dependencies

```
# Development tools
pytest>=7.0.0
pytest-cov>=4.0.0
pytest-mock>=3.12.0
psutil>=5.9.0  # For memory profiling in performance tests
ruff>=0.1.0
mypy>=1.0.0
pre-commit>=3.0.0

# Type stubs
types-pyyaml>=6.0.0
types-requests>=2.31.0
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

# Environment-specific project IDs (5 environments)
environments:
  test:
    project_id: "P2test123..."  # API testing
  devtest:
    project_id: "P2dvt456..."   # Initial dev work
  dev:
    project_id: "P2dev789..."   # CI/CD dev environment
  staging:
    project_id: "P2stg012..."   # QA and UAT
  prod:
    project_id: "P2prd345..."   # Production

# Tenant definitions (replicated across all 5 environments)
# Each entity = 1 tenant per environment
tenants:
  # PortCo Connect internal users
  - id: "pcconnect-main"
    name: "PortCo Connect Internal"
    domains: ["pcconnect.ai"]
    self_provisioning: true
    custom_attributes:
      entity_type: "internal"
      # Note: SSO configured manually in Descope Console per environment

  # Portfolio Company: Acme Corporation
  - id: "acme-corp"
    name: "Acme Corporation"
    domains: ["acme.com"]
    self_provisioning: true
    custom_attributes:
      entity_type: "portfolio_company"
      plan: "enterprise"
      # Note: If Acme brings their own SSO, configured manually

  # Portfolio Company: Widget Inc
  - id: "widget-inc"
    name: "Widget Inc"
    domains: ["widget.io"]
    self_provisioning: false
    custom_attributes:
      entity_type: "portfolio_company"
      plan: "standard"

# Authentication flow templates
flows:
  - template: "sign-up-or-in"
    name: "Default Login Flow"
    enabled: true

  - template: "mfa-login"
    name: "Multi-Factor Authentication"
    enabled: true
    config:
      methods: ["sms", "totp", "email"]
      remember_device: true
      remember_duration_days: 30
```

---

### CLI Command Reference

#### Global Options

```bash
--config PATH           # Path to config file (default: ./descope.yaml)
--environment ENV       # Environment name (dev, staging, prod)
--dry-run              # Preview changes without applying
--yes                  # Skip confirmation prompts
--log-level LEVEL      # Logging level (debug, info, warning, error)
--backup-dir PATH      # Backup directory (default: ~/.descope-mgmt/backups/)
--no-color             # Disable colored output
```

---

#### Tenant Commands

##### `descope-mgmt tenant sync`

Create or update tenants to match configuration file (idempotent).

```bash
descope-mgmt tenant sync --config descope.yaml --dry-run
descope-mgmt tenant sync --config descope.yaml  # Apply changes
```

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

Summary:
  + 1 tenant to create
  ~ 1 tenant to update

Run without --dry-run to apply changes.
```

**Example Output (apply)**:
```
Creating backup...
✓ Backup saved to ~/.descope-mgmt/backups/2025-11-10_14-30-15_pre-tenant-sync.json

Applying changes...
✓ acme-corp created (1/2)
✓ widget-co updated (2/2)

Operation Summary:
  ✓ 1 tenant created
  ✓ 1 tenant updated

Duration: 3.2s
```

---

##### `descope-mgmt tenant list`

List all tenants in current project.

```bash
descope-mgmt tenant list
descope-mgmt tenant list --format json
```

---

#### Flow Commands

##### `descope-mgmt flow deploy`

Deploy authentication flow templates.

```bash
descope-mgmt flow deploy --config descope.yaml --dry-run
descope-mgmt flow deploy --config descope.yaml
```

---

##### `descope-mgmt flow list`

List available flow templates and deployed flows.

```bash
descope-mgmt flow list
descope-mgmt flow list --templates  # Show available templates only
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
```

---

#### Diff Calculation

```python
from enum import Enum

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

class DiffService:
    """Service for calculating diffs between states"""

    def calculate_diff(
        self,
        current_state: ProjectState,
        desired_config: DescopeConfig
    ) -> ProjectDiff:
        tenant_diffs = self._diff_tenants(
            current_state.tenants,
            desired_config.tenants
        )
        return ProjectDiff(tenant_diffs=tenant_diffs, flow_diffs=flow_diffs)
```

---

### Backup and Restore with Pydantic Schemas

#### Backup Data Models

```python
# src/descope_mgmt/domain/models/backup.py
from datetime import datetime
from typing import Optional, Any
from pydantic import BaseModel, Field

class BackupMetadata(BaseModel):
    """Metadata for a backup"""
    version: str = Field(default="1.0", description="Backup format version")
    timestamp: datetime = Field(..., description="When backup was created (ISO 8601)")
    operation: str = Field(..., description="Operation that triggered backup")
    user: Optional[str] = Field(None, description="User who initiated operation")
    git_commit: Optional[str] = Field(None, description="Git commit hash at time of backup")
    environment: Optional[str] = Field(None, description="Environment name")
    project_id: str = Field(..., description="Descope project ID")

class TenantBackupData(BaseModel):
    """Raw tenant data from Descope API"""
    id: str
    name: str
    selfProvisioning: bool = False
    domains: list[str] = Field(default_factory=list)
    customAttributes: dict[str, Any] = Field(default_factory=dict)
    createdTime: int
    updatedTime: int

class Backup(BaseModel):
    """Complete backup file format"""
    metadata: BackupMetadata = Field(..., description="Backup metadata")
    tenants: list[TenantBackupData] = Field(default_factory=list)
    flows: list[FlowBackupData] = Field(default_factory=list)
    project_settings: Optional[dict[str, Any]] = Field(None)

    def to_json(self) -> str:
        """Serialize to JSON string"""
        return self.model_dump_json(indent=2)

    @classmethod
    def from_json(cls, json_str: str) -> "Backup":
        """Deserialize from JSON string"""
        return cls.model_validate_json(json_str)
```

---

#### Backup Service

```python
# src/descope_mgmt/domain/services/backup_service.py
from pathlib import Path
from datetime import datetime
import subprocess

class BackupService:
    """Service for creating and restoring backups with structured format"""

    def __init__(self, backup_dir: Path = Path("~/.descope-mgmt/backups").expanduser()):
        self.backup_dir = backup_dir
        self.backup_dir.mkdir(exist_ok=True, parents=True)

    def create_backup(
        self,
        operation_name: str,
        project_state: ProjectState,
        environment: Optional[str] = None
    ) -> BackupId:
        """Create structured backup of current state."""
        timestamp = datetime.now()
        timestamp_str = timestamp.strftime("%Y-%m-%d_%H-%M-%S")
        filename = f"{timestamp_str}_pre-{operation_name}.json"
        filepath = self.backup_dir / filename

        # Get user from environment or git
        user = self._get_current_user()
        git_commit = self._get_git_commit()

        # Create metadata
        metadata = BackupMetadata(
            version="1.0",
            timestamp=timestamp,
            operation=operation_name,
            user=user,
            git_commit=git_commit,
            environment=environment,
            project_id=project_state.project_id
        )

        # Convert state to backup data
        tenant_backups = [
            TenantBackupData(
                id=t.id,
                name=t.name,
                selfProvisioning=t.self_provisioning,
                domains=t.domains,
                customAttributes=t.custom_attributes,
                createdTime=int(t.created_at.timestamp()),
                updatedTime=int(t.updated_at.timestamp())
            )
            for t in project_state.tenants.values()
        ]

        # Create backup object
        backup = Backup(metadata=metadata, tenants=tenant_backups, flows=flow_backups)

        # Write to file
        with filepath.open('w') as f:
            f.write(backup.to_json())

        logger.info("Backup created", filepath=str(filepath), tenants=len(tenant_backups))
        return BackupId(filepath=filepath)

    def cleanup_old_backups(self, days: int = 30) -> int:
        """Remove backups older than specified days."""
        import time
        cutoff_time = time.time() - (days * 24 * 60 * 60)
        deleted = 0

        for filepath in self.backup_dir.glob("*.json"):
            if filepath.stat().st_mtime < cutoff_time:
                logger.info("Deleting old backup", filepath=str(filepath))
                filepath.unlink()
                deleted += 1

        return deleted
```

---

#### Backup Storage Strategy

**Default Location**: `~/.descope-mgmt/backups/`

**Retention**: Keep last 30 days locally (configurable)

**Alternative Locations**: Override with `--backup-dir` flag or `DESCOPE_BACKUP_DIR` environment variable

**Git Integration (Recommended)**:
```bash
# Add backups to version control
!.descope-backups/*.json
```

**Cloud Sync (Optional)**:
```bash
# Sync to S3/GCS after each backup
aws s3 sync ~/.descope-mgmt/backups/ s3://company-descope-backups/
gsutil -m rsync -r ~/.descope-mgmt/backups/ gs://company-descope-backups/
```

---

## Implementation Plan

### Timeline: 10 Weeks (5 Phases)

---

### Phase 1: Foundation (Weeks 1-2)

**Goal**: Basic working CLI with tenant create/list commands

#### Week 1: Core Infrastructure

**Tasks**:
1. Project setup
   - Update `pyproject.toml` (package name, dependencies including `pyrate-limiter>=3.1.0`)
   - Configure entry point: `descope-mgmt = "descope_mgmt.cli.main:cli"`
   - Create directory structure (types/, cli/, domain/, api/, utils/)
   - Set up pre-commit hooks

2. Pydantic models
   - Implement TenantConfig, FlowConfig, DescopeConfig with validators
   - Environment variable substitution
   - Write 15+ unit tests

3. Config loader
   - YAML file loading with discovery chain
   - Environment-specific overrides
   - Write 10+ unit tests

4. Descope API integration
   - DescopeApiClient wrapper with PyrateLimiter
   - Retry decorator with exponential backoff
   - Error translation (SDK → domain exceptions)
   - Write 10+ unit tests with mocked SDK

**Deliverables**:
- ✅ Config models with validation
- ✅ Rate limiter integration (PyrateLimiter)
- ✅ API client wrapper
- ✅ 40+ unit tests passing

---

#### Week 2: CLI Commands

**Tasks**:
1. CLI framework with Click (command groups, global options)
2. Basic commands: `tenant list`, `tenant create`
3. State management (fetch current state, calculate diffs)
4. Rich terminal output with colored diffs

**Deliverables**:
- ✅ Working `descope-mgmt tenant list` command
- ✅ Working `descope-mgmt tenant create` command
- ✅ Diff calculation and display
- ✅ 20+ integration tests passing

---

### Phase 2: Safety & Observability (Weeks 3-4)

**Goal**: Production-ready with safety mechanisms

#### Week 3: Safety Mechanisms

**Tasks**:
1. Backup service with Pydantic schemas
2. Idempotent operations (Operation ABC, strategy pattern)
3. `tenant sync` command (full workflow)
4. Confirmation prompts for destructive operations

**Deliverables**:
- ✅ Working `descope-mgmt tenant sync` command (idempotent)
- ✅ Automatic Pydantic-validated backups
- ✅ Confirmation prompts
- ✅ 25+ tests for safety mechanisms

---

#### Week 4: Observability

**Tasks**:
1. Structured logging (structlog with JSON formatter)
2. Progress indicators with Rich library
3. Operation summaries
4. Rate limit handling with PyrateLimiter

**Deliverables**:
- ✅ Structured logging (JSON + console)
- ✅ Progress indicators for batch operations
- ✅ Rate limit handling with automatic retry
- ✅ Detailed, actionable error messages

---

### Phase 3: Flow Management (Weeks 5-6)

**Goal**: Full flow deployment and management

#### Week 5: Flow Templates

**Tasks**:
1. Flow models (FlowConfig, FlowState)
2. Flow templates definition (sign-up-or-in, mfa-login, magic-link, social-login)
3. `flow list` command
4. `flow deploy` command

**Deliverables**:
- ✅ Flow templates defined
- ✅ Working `descope-mgmt flow list` command
- ✅ Working `descope-mgmt flow deploy` command
- ✅ 15+ tests for flow operations

---

#### Week 6: Flow Import/Export

**Tasks**:
1. `flow export` command
2. Flow versioning and warnings
3. Flow rollback capability
4. End-to-end testing

**Deliverables**:
- ✅ Working `descope-mgmt flow export` command
- ✅ Flow version tracking and warnings
- ✅ Flow rollback capability
- ✅ 20+ tests for flow management

---

### Phase 4: Polish & Performance (Weeks 7-8)

**Goal**: Performance optimization and quality improvements

#### Week 7: Performance Optimization

**Tasks**:
1. Batch operation optimization (adaptive worker pools with RateLimitedExecutor)
2. Memory profiling for large configs
3. Connection pooling tuning
4. Performance benchmarks and tests

**Deliverables**:
- ✅ Performance tests with benchmarks
- ✅ Optimized batch operations
- ✅ Memory usage < 50MB for 1000 tenants

---

#### Week 8: Quality & Testing

**Tasks**:
1. Configuration drift detection
2. Multi-environment support refinement
3. CLI usability improvements
4. Additional edge case testing

**Deliverables**:
- ✅ Drift detection and reporting
- ✅ Multi-environment orchestration
- ✅ 90%+ test coverage

---

### Phase 5: Documentation & Release (Weeks 9-10)

**Goal**: Comprehensive documentation and production readiness

#### Week 9: Documentation Sprint

**Tasks**:
1. User guide (getting started, tutorials, examples)
2. Complete command reference with examples
3. Configuration guide (YAML schema, best practices)
4. Troubleshooting guide
5. Pre-commit hook setup guide

**Deliverables**:
- ✅ Comprehensive user documentation
- ✅ Command reference
- ✅ Example configs

---

#### Week 10: Release Preparation

**Tasks**:
1. Security review and hardening
2. Final integration testing with real Descope project
3. Performance validation (load testing with 100+ tenants)
4. Release notes and changelog
5. Internal deployment documentation (NFS mount setup)

**Deliverables**:
- ✅ Security audit completed
- ✅ Internal deployment guide (NFS mount)
- ✅ Release-ready v1.0

---

### Phase Summary

| Phase | Weeks | Focus | Key Deliverables |
|-------|-------|-------|------------------|
| 1 | 1-2 | Foundation | Core infrastructure, basic CLI |
| 2 | 3-4 | Safety | Idempotent sync, backups, observability |
| 3 | 5-6 | Features | Flow management, rollback |
| 4 | 7-8 | Performance | Optimization, benchmarks, drift |
| 5 | 9-10 | Documentation | Docs, release, security audit |

**Total: 10 weeks** (extended from 8 weeks to include documentation and release preparation)

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
│   ├── test_backup_service.py      # Backup/restore with Pydantic
│   └── test_tenant_operations.py   # Operation strategy pattern
├── api/
│   ├── test_descope_client.py      # API client wrapper
│   ├── test_rate_limiter.py        # PyrateLimiter integration
│   └── test_retry_logic.py         # Retry with exponential backoff
└── utils/
    ├── test_config_loader.py       # Config file loading
    └── test_env_vars.py            # Environment variable substitution
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

def test_tenant_config_invalid_id():
    """Tenant ID with uppercase fails validation"""
    with pytest.raises(ValidationError) as exc_info:
        TenantConfig(id="Acme Corp!", name="Acme Corporation")

    errors = exc_info.value.errors()
    assert "pattern" in errors[0]["type"]
```

---

### Integration Testing with Descope Test Users

**Approach**: Use Descope Test User Management feature for integration testing with real API

#### Setup

```python
# tests/integration/conftest.py
import pytest
import os

@pytest.fixture(scope="session")
def descope_test_project():
    """
    Descope test project configuration.

    Requires environment variables:
    - DESCOPE_TEST_PROJECT_ID
    - DESCOPE_TEST_MANAGEMENT_KEY
    """
    project_id = os.getenv("DESCOPE_TEST_PROJECT_ID")
    management_key = os.getenv("DESCOPE_TEST_MANAGEMENT_KEY")

    if not project_id or not management_key:
        pytest.skip("Descope test project credentials not configured")

    return {"project_id": project_id, "management_key": management_key}

@pytest.fixture
def cleanup_test_tenants(descope_client, test_tenant_prefix):
    """Clean up test tenants after test"""
    created_tenants = []
    yield created_tenants

    # Cleanup
    for tenant_id in created_tenants:
        try:
            descope_client.mgmt.tenant.delete(tenant_id)
        except Exception as e:
            print(f"Warning: Failed to cleanup tenant {tenant_id}: {e}")
```

#### Integration Test Example

```python
# tests/integration/test_tenant_operations_real.py
@pytest.mark.integration
@pytest.mark.real_api
def test_tenant_sync_idempotent_real_api(
    descope_client,
    test_tenant_prefix,
    cleanup_test_tenants
):
    """Test idempotent sync with real API"""
    service = TenantService(descope_client)

    config = TenantConfig(
        id=f"{test_tenant_prefix}-widget",
        name="Widget Test Co",
        domains=[],
        self_provisioning=False
    )
    cleanup_test_tenants.append(config.id)

    # First sync: creates tenant
    result1 = service.sync_tenant(config)
    assert result1.change_type == "create"

    # Second sync: no changes (idempotent)
    result2 = service.sync_tenant(config)
    assert result2.change_type == "no_change"
```

---

### Performance Testing

**New in v2.0**: Comprehensive performance testing strategy

```python
# tests/performance/test_batch_operations.py
import pytest
import time
from descope_mgmt.domain.services.tenant_service import TenantService

@pytest.mark.performance
def test_batch_tenant_creation_performance(large_tenant_configs, mock_api_with_latency):
    """100 tenants should complete within time constraints"""
    service = TenantService(mock_api_with_latency)

    start = time.time()
    results = service.batch_create_tenants(large_tenant_configs)
    duration = time.time() - start

    # With rate limiting (200 req/60s) and 500ms latency:
    # Theoretical: 100 requests / (200/60) = 30 seconds minimum
    # With overhead: 35-40 seconds acceptable
    assert duration < 45.0, f"Batch operation too slow: {duration}s"
    assert len(results) == 100
    assert all(r.status == "success" for r in results)

@pytest.mark.performance
def test_memory_usage_large_config():
    """Memory usage should be reasonable for large configs"""
    import psutil, os

    process = psutil.Process(os.getpid())
    initial_memory = process.memory_info().rss / 1024 / 1024  # MB

    # Load 1000 tenant configs
    configs = [TenantConfig(id=f"tenant-{i:04d}", name=f"Tenant {i}") for i in range(1000)]

    final_memory = process.memory_info().rss / 1024 / 1024
    memory_increase = final_memory - initial_memory

    # 1000 configs should use < 50MB
    assert memory_increase < 50, f"Memory usage too high: {memory_increase}MB"
```

**Performance Benchmarks**:
- 100 tenants created in < 45 seconds
- 1000 configs loaded with < 50MB memory increase
- Rate limiter overhead < 10ms per acquisition

---

### Local Testing Approach (No CI/CD)

**All testing performed locally with pre-commit hooks:**

```bash
# .pre-commit-config.yaml
repos:
  - repo: local
    hooks:
      - id: pytest-unit
        name: Run unit tests
        entry: pytest tests/unit/ -v
        language: system
        pass_filenames: false

      - id: ruff-format
        name: Format with ruff
        entry: ruff format
        language: system

      - id: ruff-check
        name: Lint with ruff
        entry: ruff check
        language: system

      - id: mypy
        name: Type check with mypy
        entry: mypy src/
        language: system
        pass_filenames: false
```

**Manual Integration Testing**:
```bash
# Run integration tests manually when needed
pytest -m "integration and real_api" -v

# Run performance tests
pytest -m performance --benchmark-only
```

---

### Test Coverage Requirements

**Minimum Coverage**:
- Overall: 85%
- Domain layer: 90% (critical business logic)
- API layer: 80%
- CLI layer: 70%

**Critical Paths (100% Coverage Required)**:
- Idempotency checks (Operation.is_needed)
- Backup before changes (Pydantic validation)
- Error translation
- Configuration validation
- Diff calculation

**Coverage Reporting**:
```bash
pytest --cov=src/descope_mgmt --cov-report=html --cov-report=term-missing
open htmlcov/index.html
```

---

### TDD Workflow

Follow strict TDD for all new features:

1. **RED**: Write failing test first
2. **GREEN**: Write minimal code to pass
3. **REFACTOR**: Improve code while keeping tests green

**Example**:
```python
# Step 1: RED - Write failing test
def test_calculate_tenant_diff_detects_name_change():
    current = TenantState(id="acme-corp", name="Acme")
    desired = TenantConfig(id="acme-corp", name="Acme Corporation")
    diff = DiffService().calculate_tenant_diff(current, desired)
    assert diff.change_type == ChangeType.UPDATE

# Step 2: GREEN - Implement minimal code
# Step 3: REFACTOR - Extract helper methods
```

---

## Operational Considerations

### Deployment (Internal NFS Mount)

#### Installation

```bash
# Navigate to shared NFS mount location
cd /home/jfogarty/pcc/core/pcc-descope-mgmt

# Install in editable mode
pip install -e .

# Verify installation
descope-mgmt --version
descope-mgmt --help
```

**Benefits of NFS Mount Approach**:
- ✅ Single source of truth (shared location)
- ✅ Automatic updates (everyone uses same install)
- ✅ No version conflicts
- ✅ No distribution complexity

#### Updates

When tool is updated on NFS mount:
- Changes are immediately available (editable install)
- No need to reinstall
- Run `git pull` if using git for version control

---

### Configuration Management

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
DESCOPE_BACKUP_DIR=~/.descope-mgmt/backups
```

---

### Monitoring and Observability

#### Log Files

```
logs/
├── descope-mgmt.log          # JSON structured logs
└── descope-mgmt-debug.log    # Verbose debug logs
```

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
  "changes": {"created": 1, "updated": 1, "deleted": 0},
  "duration_ms": 3200,
  "status": "success"
}
```

---

### Disaster Recovery

#### Backup Strategy

**Automatic Backups**:
- Before every modify/delete operation
- Stored in `~/.descope-mgmt/backups/` (default)
- Retention: Keep last 30 days locally (configurable)
- Pydantic-validated JSON format

**Manual Backups**:
```bash
# Export all configuration
descope-mgmt project export --output backup-$(date +%Y%m%d).yaml --include-tenants --include-flows

# Archive backups
tar -czf descope-backups-$(date +%Y%m%d).tar.gz ~/.descope-mgmt/backups/
```

**Cloud Sync (Optional)**:
```bash
# Upload to S3/GCS
aws s3 sync ~/.descope-mgmt/backups/ s3://your-bucket/descope-backups/
```

#### Restore Procedures

```bash
# List available backups
ls -lh ~/.descope-mgmt/backups/

# Restore from backup (manual process: re-apply config from backup)
descope-mgmt tenant sync --config <restored-backup-config.yaml>
```

---

## Appendices

### A. Key Design Decisions

1. **Rate Limiting**: PyrateLimiter library instead of custom implementation
   - Rationale: Battle-tested, thread-safe, actively maintained

2. **RateLimitedExecutor**: Rate limiting at submission, not in workers
   - Rationale: Prevents queue buildup, ensures API limits respected

3. **Timeline**: 10 weeks instead of 8 weeks
   - Rationale: Full scope (tenants + flows) + documentation phase

4. **Distribution**: NFS mount only, no PyPI
   - Rationale: Internal tool for 2 users, simplifies deployment

5. **Backup Format**: Pydantic schemas instead of simple JSON
   - Rationale: Type safety, validation, future extensibility

6. **Testing**: Local with pre-commit hooks, no CI/CD
   - Rationale: Small team, manual integration testing sufficient

7. **SSO**: Manual setup as prerequisite, not automated
   - Rationale: Complex external dependencies, one-time setup

---

### B. Critical Path Items

**Must Have for v1.0**:
- ✅ PyrateLimiter integration with thread-safe InMemoryBucket
- ✅ RateLimitedExecutor with submission-time rate limiting
- ✅ Pydantic schemas for backups
- ✅ Idempotent tenant sync
- ✅ Drift detection
- ✅ Flow template deployment
- ✅ 85%+ test coverage
- ✅ Pre-commit hooks
- ✅ User documentation

**Deferred to v2.0**:
- SSO template replication
- SSO export/import
- CI/CD integration guide (if needed)
- PyPI packaging (if distribution needs change)

---

### C. Dependencies Summary

**Core** (Production):
- click>=8.1.0
- pydantic>=2.5.0
- pyyaml>=6.0
- descope>=1.7.12
- rich>=13.0.0
- structlog>=23.0.0
- **pyrate-limiter>=3.1.0** (CRITICAL)
- python-dotenv>=1.0.0

**Development**:
- pytest>=7.0.0, pytest-cov>=4.0.0, pytest-mock>=3.12.0
- psutil>=5.9.0 (performance tests)
- ruff>=0.1.0, mypy>=1.0.0
- pre-commit>=3.0.0

---

### D. Quick Reference

**Installation**:
```bash
cd /home/jfogarty/pcc/core/pcc-descope-mgmt
pip install -e .
```

**Setup Test Environment**:
```bash
export DESCOPE_TEST_PROJECT_ID=P2test123...
export DESCOPE_TEST_MANAGEMENT_KEY=K2test456...
```

**Run Tests**:
```bash
# Unit tests only
pytest tests/unit/ -v

# Integration tests with real API
pytest -m "integration and real_api" -v

# Performance tests
pytest -m performance -v

# All tests with coverage
pytest --cov=src/descope_mgmt --cov-report=html
```

**Common Commands**:
```bash
# List tenants
descope-mgmt tenant list

# Sync tenants (dry-run)
descope-mgmt tenant sync --config descope.yaml --dry-run

# Sync tenants (apply)
descope-mgmt tenant sync --config descope.yaml

# Deploy flows
descope-mgmt flow deploy --config descope.yaml

# List backups
ls -lh ~/.descope-mgmt/backups/
```

---

**End of Consolidated Design Document**

*This document consolidates the original design with all approved revisions. Implementation should follow this document as the single source of truth.*
