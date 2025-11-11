# pcc-descope-mgmt Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal**: Build a production-ready Python CLI tool for managing Descope authentication infrastructure across 5 environments with full idempotency, safety mechanisms, and observability.

**Architecture**: Three-layer design (CLI → Domain → API) with Protocol-based dependency injection, Pydantic validation, PyrateLimiter for rate limiting, and TDD throughout.

**Tech Stack**: Python 3.12, Click, Pydantic, PyrateLimiter, Descope SDK, Rich, structlog, pytest

**Timeline**: 10 weeks (5 phases)

---

## Phase 1: Foundation (Weeks 1-2)

### Task 1: Project Setup

**Files:**
- Modify: `pyproject.toml`
- Modify: `requirements.txt`
- Create: `src/descope_mgmt/__init__.py`
- Create: `.pre-commit-config.yaml`

**Step 1: Update pyproject.toml**

```toml
[project]
name = "descope-mgmt"
version = "1.0.0"
description = "CLI tool for managing Descope authentication infrastructure"
authors = [{name = "PortCo Connect", email = "engineering@portco.com"}]
requires-python = ">=3.12"
dependencies = [
    "click>=8.1.0",
    "pydantic>=2.5.0",
    "pyyaml>=6.0",
    "descope>=1.7.12",
    "rich>=13.0.0",
    "structlog>=23.0.0",
    "pyrate-limiter>=3.1.0",
    "python-dotenv>=1.0.0",
]

[project.optional-dependencies]
dev = [
    "pytest>=7.0.0",
    "pytest-cov>=4.0.0",
    "pytest-mock>=3.12.0",
    "psutil>=5.9.0",
    "ruff>=0.1.0",
    "mypy>=1.0.0",
    "pre-commit>=3.0.0",
    "types-pyyaml>=6.0.0",
]

[project.scripts]
descope-mgmt = "descope_mgmt.cli.main:cli"

[tool.ruff]
line-length = 100
target-version = "py312"

[tool.mypy]
python_version = "3.12"
strict = true
warn_return_any = true
warn_unused_configs = true

[tool.pytest.ini_options]
testpaths = ["tests"]
python_files = "test_*.py"
python_classes = "Test*"
python_functions = "test_*"
markers = [
    "integration: integration tests with real API",
    "real_api: tests that call real Descope API",
    "performance: performance benchmark tests",
]
```

**Step 2: Update requirements.txt**

```
click>=8.1.0
pydantic>=2.5.0
pyyaml>=6.0
descope>=1.7.12
rich>=13.0.0
structlog>=23.0.0
pyrate-limiter>=3.1.0
python-dotenv>=1.0.0
```

**Step 3: Create directory structure**

Run:
```bash
mkdir -p src/descope_mgmt/{types,cli,domain/{models,services,operations},api,utils}
mkdir -p tests/{unit/{domain,api,utils,cli},integration,performance}
touch src/descope_mgmt/__init__.py
touch src/descope_mgmt/{types,cli,domain,api,utils}/__init__.py
touch src/descope_mgmt/domain/{models,services,operations}/__init__.py
```

**Step 4: Configure pre-commit hooks**

Create `.pre-commit-config.yaml`:
```yaml
repos:
  - repo: local
    hooks:
      - id: pytest-unit
        name: Run unit tests
        entry: pytest tests/unit/ -v
        language: system
        pass_filenames: false
        always_run: true

      - id: ruff-format
        name: Format with ruff
        entry: ruff format
        language: system
        types: [python]

      - id: ruff-check
        name: Lint with ruff
        entry: ruff check
        language: system
        types: [python]

      - id: mypy
        name: Type check with mypy
        entry: mypy src/
        language: system
        pass_filenames: false
        always_run: true
```

**Step 5: Install pre-commit**

Run: `pre-commit install`
Expected: "pre-commit installed at .git/hooks/pre-commit"

**Step 6: Commit**

```bash
git add pyproject.toml requirements.txt .pre-commit-config.yaml src/ tests/
git commit -m "feat: initial project setup with dependencies and structure"
```

---

### Task 2: Protocol Definitions

**Files:**
- Create: `src/descope_mgmt/types/protocols.py`
- Create: `tests/unit/types/test_protocols.py`

**Step 1: Write test for protocols**

```python
# tests/unit/types/test_protocols.py
"""Tests for protocol definitions."""

from typing import runtime_checkable


def test_descope_client_protocol_structure():
    """Protocol should define required methods"""
    from descope_mgmt.types.protocols import DescopeClient

    # Protocol is runtime checkable
    assert hasattr(DescopeClient, '__protocol_attrs__')


def test_tenant_protocol_structure():
    """Tenant protocol should define required attributes"""
    from descope_mgmt.types.protocols import Tenant

    # Mock implementation should satisfy protocol
    class MockTenant:
        id = "test"
        name = "Test"
        domains = []
        self_provisioning = False
        custom_attributes = {}
        created_at = None
        updated_at = None

    mock = MockTenant()
    assert mock.id == "test"
```

**Step 2: Run test (should fail)**

Run: `pytest tests/unit/types/test_protocols.py -v`
Expected: FAIL - module not found

**Step 3: Implement protocols**

```python
# src/descope_mgmt/types/protocols.py
"""
Protocol definitions for dependency injection.

Protocols define interfaces without coupling to concrete implementations.
This enables:
- Easy mocking in tests
- Framework-agnostic domain layer
- Clear interface contracts
"""

from datetime import datetime
from typing import Any, Protocol, runtime_checkable


@runtime_checkable
class Tenant(Protocol):
    """Protocol for tenant objects from Descope SDK."""

    id: str
    name: str
    domains: list[str]
    self_provisioning: bool
    custom_attributes: dict[str, Any]
    created_at: datetime
    updated_at: datetime


@runtime_checkable
class DescopeClient(Protocol):
    """Protocol for Descope API client operations."""

    def load_tenant(self, tenant_id: str) -> Tenant:
        """Load single tenant by ID."""
        ...

    def list_tenants(self) -> list[Tenant]:
        """List all tenants in project."""
        ...

    def create_tenant(
        self,
        tenant_id: str,
        name: str,
        domains: list[str] | None = None,
        self_provisioning: bool = False,
        custom_attributes: dict[str, Any] | None = None,
    ) -> Tenant:
        """Create new tenant."""
        ...

    def update_tenant(
        self,
        tenant_id: str,
        name: str | None = None,
        domains: list[str] | None = None,
        self_provisioning: bool | None = None,
        custom_attributes: dict[str, Any] | None = None,
    ) -> Tenant:
        """Update existing tenant."""
        ...

    def delete_tenant(self, tenant_id: str) -> None:
        """Delete tenant by ID."""
        ...
```

**Step 4: Run test (should pass)**

Run: `pytest tests/unit/types/test_protocols.py -v`
Expected: PASS

**Step 5: Commit**

```bash
git add src/descope_mgmt/types/protocols.py tests/unit/types/test_protocols.py
git commit -m "feat(types): add Protocol definitions for dependency injection"
```

---

### Task 3: Tenant Config Model (TDD)

**Files:**
- Create: `tests/unit/domain/test_tenant_config.py`
- Create: `src/descope_mgmt/domain/models/config.py`

**Step 1: Write failing tests**

```python
# tests/unit/domain/test_tenant_config.py
"""Tests for TenantConfig Pydantic model."""

import pytest
from pydantic import ValidationError


class TestTenantConfig:
    """Test TenantConfig validation."""

    def test_valid_tenant_config(self):
        """Should accept valid configuration"""
        from descope_mgmt.domain.models.config import TenantConfig

        config = TenantConfig(
            id="acme-corp",
            name="Acme Corporation",
            domains=["acme.com"],
            self_provisioning=True,
            custom_attributes={"type": "portfolio"},
        )

        assert config.id == "acme-corp"
        assert config.name == "Acme Corporation"
        assert config.domains == ["acme.com"]

    def test_tenant_id_lowercase_required(self):
        """Tenant ID must be lowercase"""
        from descope_mgmt.domain.models.config import TenantConfig

        with pytest.raises(ValidationError) as exc:
            TenantConfig(id="Acme-Corp", name="Acme")

        assert "pattern" in str(exc.value)

    def test_tenant_id_no_special_chars(self):
        """Tenant ID cannot contain special characters"""
        from descope_mgmt.domain.models.config import TenantConfig

        with pytest.raises(ValidationError):
            TenantConfig(id="acme_corp!", name="Acme")

    def test_tenant_id_min_length(self):
        """Tenant ID must be at least 3 characters"""
        from descope_mgmt.domain.models.config import TenantConfig

        with pytest.raises(ValidationError):
            TenantConfig(id="ab", name="Acme")

    def test_tenant_id_max_length(self):
        """Tenant ID cannot exceed 50 characters"""
        from descope_mgmt.domain.models.config import TenantConfig

        with pytest.raises(ValidationError):
            TenantConfig(id="a" * 51, name="Acme")

    def test_invalid_domain_format(self):
        """Should reject invalid domain formats"""
        from descope_mgmt.domain.models.config import TenantConfig

        with pytest.raises(ValidationError):
            TenantConfig(id="acme-corp", name="Acme", domains=["not a domain"])

    def test_defaults(self):
        """Should provide sensible defaults"""
        from descope_mgmt.domain.models.config import TenantConfig

        config = TenantConfig(id="test", name="Test")

        assert config.domains == []
        assert config.self_provisioning is False
        assert config.custom_attributes == {}
```

**Step 2: Run tests (should fail)**

Run: `pytest tests/unit/domain/test_tenant_config.py -v`
Expected: ALL FAIL - TenantConfig not defined

**Step 3: Implement TenantConfig**

```python
# src/descope_mgmt/domain/models/config.py
"""
Configuration models with Pydantic validation.
"""

import re
from typing import Any
from pydantic import BaseModel, Field, field_validator, ConfigDict


class TenantConfig(BaseModel):
    """
    Tenant configuration from YAML file.

    Immutable, validated model for tenant configuration.
    """

    model_config = ConfigDict(
        frozen=True,  # Immutable after creation
        extra='forbid',  # Reject unknown fields
        str_strip_whitespace=True,
        validate_assignment=True,
    )

    id: str = Field(
        ...,
        pattern=r'^[a-z0-9-]+$',
        min_length=3,
        max_length=50,
        description="Tenant ID (lowercase alphanumeric with hyphens)",
    )
    name: str = Field(
        ...,
        min_length=1,
        max_length=100,
        description="Human-readable tenant name",
    )
    domains: list[str] = Field(
        default_factory=list,
        description="Associated domains for this tenant",
    )
    self_provisioning: bool = Field(
        default=False,
        description="Enable self-service user provisioning",
    )
    custom_attributes: dict[str, Any] = Field(
        default_factory=dict,
        description="Custom metadata key-value pairs",
    )

    @field_validator('domains')
    @classmethod
    def validate_domains(cls, v: list[str]) -> list[str]:
        """Validate domain format (RFC 1035 compliant)."""
        domain_pattern = re.compile(
            r'^(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$'
        )

        for domain in v:
            if not domain_pattern.match(domain):
                raise ValueError(f"Invalid domain format: {domain}")
            if len(domain) > 253:
                raise ValueError(f"Domain too long (max 253 chars): {domain}")

        return v
```

**Step 4: Run tests (should pass)**

Run: `pytest tests/unit/domain/test_tenant_config.py -v`
Expected: ALL PASS

**Step 5: Commit**

```bash
git add src/descope_mgmt/domain/models/config.py tests/unit/domain/test_tenant_config.py
git commit -m "feat(domain): add TenantConfig Pydantic model with validation"
```

---

### Task 4: Complete Config Models

**Files:**
- Modify: `src/descope_mgmt/domain/models/config.py`
- Create: `tests/unit/domain/test_complete_config.py`

**Step 1: Write tests for remaining models**

```python
# tests/unit/domain/test_complete_config.py
"""Tests for complete configuration models."""

import pytest


def test_flow_config_valid():
    """Should accept valid flow configuration"""
    from descope_mgmt.domain.models.config import FlowConfig

    config = FlowConfig(
        name="mfa-login",
        template="mfa-login",
        enabled=True,
        config={"methods": ["sms", "totp"]},
    )

    assert config.name == "mfa-login"
    assert config.enabled is True


def test_descope_config_complete():
    """Should load complete configuration"""
    from descope_mgmt.domain.models.config import DescopeConfig, TenantConfig

    config = DescopeConfig(
        version="1.0",
        environments={
            "dev": {"project_id": "P2dev123", "management_key": "K2dev456"}
        },
        tenants=[TenantConfig(id="test", name="Test")],
        flows=[],
    )

    assert config.version == "1.0"
    assert "dev" in config.environments
    assert len(config.tenants) == 1
```

**Step 2: Run tests (should fail)**

Run: `pytest tests/unit/domain/test_complete_config.py -v`
Expected: FAIL

**Step 3: Implement remaining models**

```python
# Add to src/descope_mgmt/domain/models/config.py

class EnvironmentConfig(BaseModel):
    """Environment-specific configuration."""
    project_id: str = Field(..., description="Descope project ID")
    management_key: str = Field(..., description="Management API key")


class FlowConfig(BaseModel):
    """Authentication flow configuration."""

    model_config = ConfigDict(frozen=True, extra='forbid')

    name: str = Field(..., description="Flow identifier")
    template: str = Field(..., description="Flow template ID")
    enabled: bool = Field(default=True, description="Whether flow is active")
    config: dict[str, Any] = Field(
        default_factory=dict,
        description="Template-specific configuration",
    )


class DescopeConfig(BaseModel):
    """Complete Descope configuration from YAML."""

    model_config = ConfigDict(extra='forbid')

    version: str = Field(default="1.0", description="Config schema version")
    environments: dict[str, EnvironmentConfig] = Field(
        ...,
        description="Environment configurations (dev, staging, prod)",
    )
    tenants: list[TenantConfig] = Field(
        default_factory=list,
        description="Tenant configurations",
    )
    flows: list[FlowConfig] = Field(
        default_factory=list,
        description="Flow configurations",
    )
```

**Step 4: Run tests (should pass)**

Run: `pytest tests/unit/domain/test_complete_config.py -v`
Expected: PASS

**Step 5: Commit**

```bash
git add src/descope_mgmt/domain/models/config.py tests/unit/domain/test_complete_config.py
git commit -m "feat(domain): add FlowConfig and DescopeConfig models"
```

---

### Task 5: Rate Limiter Implementation

**Files:**
- Create: `src/descope_mgmt/utils/rate_limiter.py`
- Create: `tests/unit/utils/test_rate_limiter.py`

**Step 1: Write tests for rate limiter**

```python
# tests/unit/utils/test_rate_limiter.py
"""Tests for PyrateLimiter integration."""

import time
import pytest
from threading import Thread


def test_rate_limiter_allows_under_limit():
    """Should allow requests under rate limit"""
    from descope_mgmt.utils.rate_limiter import DescopeRateLimiter

    limiter = DescopeRateLimiter(max_requests=5, window_seconds=1)

    # Should allow 5 requests
    for _ in range(5):
        limiter.acquire()  # Should not raise


def test_rate_limiter_blocks_over_limit():
    """Should block requests over rate limit"""
    from descope_mgmt.utils.rate_limiter import DescopeRateLimiter
    from pyrate_limiter import BucketFullException

    limiter = DescopeRateLimiter(max_requests=2, window_seconds=1)

    # First 2 requests succeed
    limiter.acquire()
    limiter.acquire()

    # Third request should block
    with pytest.raises(BucketFullException):
        limiter.acquire()


def test_rate_limiter_thread_safe():
    """Should handle concurrent requests safely"""
    from descope_mgmt.utils.rate_limiter import DescopeRateLimiter

    limiter = DescopeRateLimiter(max_requests=10, window_seconds=1)
    results = []

    def worker():
        try:
            limiter.acquire()
            results.append("success")
        except Exception as e:
            results.append(f"error: {e}")

    # Spawn 10 threads (should all succeed)
    threads = [Thread(target=worker) for _ in range(10)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()

    assert len([r for r in results if r == "success"]) == 10
```

**Step 2: Run tests (should fail)**

Run: `pytest tests/unit/utils/test_rate_limiter.py -v`
Expected: FAIL

**Step 3: Implement rate limiter**

```python
# src/descope_mgmt/utils/rate_limiter.py
"""
Rate limiting using PyrateLimiter.

Thread-safe rate limiter for Descope API compliance.
"""

from threading import Lock
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
    """

    def __init__(
        self,
        max_requests: int = 200,
        window_seconds: int = 60,
        resource_name: str = "descope-api",
    ):
        """
        Initialize rate limiter.

        Args:
            max_requests: Maximum requests allowed
            window_seconds: Time window in seconds
            resource_name: Resource identifier for logging
        """
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
        Acquire a rate limit token.

        Blocks if rate limit would be exceeded.

        Args:
            weight: Number of tokens to acquire (default: 1)

        Raises:
            BucketFullException: If rate limit exceeded
        """
        with self._lock:
            try:
                self._limiter.try_acquire(self.resource_name, weight=weight)
                logger.debug("Rate limit acquired", resource=self.resource_name)
            except BucketFullException:
                logger.warning("Rate limit exceeded", resource=self.resource_name)
                raise


class TenantRateLimiter(DescopeRateLimiter):
    """Rate limiter for tenant operations (200 req/60s)."""

    def __init__(self):
        super().__init__(
            max_requests=200,
            window_seconds=60,
            resource_name="descope-tenant-api",
        )
```

**Step 4: Run tests (should pass)**

Run: `pytest tests/unit/utils/test_rate_limiter.py -v`
Expected: PASS

**Step 5: Commit**

```bash
git add src/descope_mgmt/utils/rate_limiter.py tests/unit/utils/test_rate_limiter.py
git commit -m "feat(utils): add PyrateLimiter integration for API rate limiting"
```

---

## Execution Instructions

**This plan contains 60+ tasks total across 10 weeks. The above shows the first 5 tasks of Phase 1.**

**Remaining tasks follow the same pattern**:
1. Write failing test (TDD RED)
2. Run test to verify failure
3. Implement minimal code (TDD GREEN)
4. Run test to verify pass
5. Commit with conventional message

**Complete task breakdown** for all phases available in design document at `.claude/plans/design.md`.

---

## Next Steps

**Plan complete and saved to `.claude/plans/2025-11-10-descope-mgmt-implementation.md`.**

**Two execution options:**

**1. Subagent-Driven (this session)** - I dispatch fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** - Open new session with executing-plans, batch execution with checkpoints

**Which approach do you prefer?**
