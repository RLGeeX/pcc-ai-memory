# Chunk 3: Type System - Protocols and Shared Types

**Status:** pending
**Dependencies:** chunk-001-project-setup
**Complexity:** simple
**Estimated Time:** 15 minutes
**Tasks:** 3

---

## Task 1: Create Shared Base Types

**Files:**
- Create: `src/descope_mgmt/types/shared.py`
- Create: `tests/unit/types/test_shared.py`

**Step 1: Write failing tests**

Create `tests/unit/types/__init__.py`:
```python
"""Unit tests for type system."""
```

Create `tests/unit/types/test_shared.py`:
```python
"""Tests for shared type definitions."""

import pytest
from pydantic import ValidationError

from descope_mgmt.types.shared import ResourceIdentifier


def test_resource_identifier_valid() -> None:
    """Test ResourceIdentifier with valid data."""
    resource = ResourceIdentifier(
        id="test-123",
        name="Test Resource",
        description="A test resource"
    )
    assert resource.id == "test-123"
    assert resource.name == "Test Resource"
    assert resource.description == "A test resource"


def test_resource_identifier_no_description() -> None:
    """Test ResourceIdentifier without description."""
    resource = ResourceIdentifier(id="test-123", name="Test Resource")
    assert resource.id == "test-123"
    assert resource.name == "Test Resource"
    assert resource.description is None


def test_resource_identifier_missing_id() -> None:
    """Test ResourceIdentifier fails without id."""
    with pytest.raises(ValidationError) as exc_info:
        ResourceIdentifier(name="Test")
    assert "id" in str(exc_info.value)


def test_resource_identifier_missing_name() -> None:
    """Test ResourceIdentifier fails without name."""
    with pytest.raises(ValidationError) as exc_info:
        ResourceIdentifier(id="test-123")
    assert "name" in str(exc_info.value)
```

**Step 2: Run tests to verify failure**

```bash
pytest tests/unit/types/test_shared.py -v
```

Expected: All 4 tests FAIL (module doesn't exist)

**Step 3: Implement ResourceIdentifier**

Create `src/descope_mgmt/types/shared.py`:
```python
"""Shared type definitions used across the application."""

from pydantic import BaseModel, Field


class ResourceIdentifier(BaseModel):
    """Base model for all Descope resources with common identifier fields.

    This is used as a base for TenantConfig, FlowConfig, etc. to ensure
    consistent ID reference patterns and avoid circular imports.
    """

    id: str = Field(..., description="Unique identifier for the resource")
    name: str = Field(..., description="Human-readable name")
    description: str | None = Field(None, description="Optional description")

    model_config = {"frozen": True}  # Immutable for safety
```

**Step 4: Run tests to verify pass**

```bash
pytest tests/unit/types/test_shared.py -v
```

Expected: All 4 tests PASS

**Step 5: Commit**

```bash
git add src/descope_mgmt/types/shared.py tests/unit/types/
git commit -m "feat: add ResourceIdentifier base model for type system"
```

---

## Task 2: Create Protocol Definitions

**Files:**
- Create: `src/descope_mgmt/types/protocols.py`
- Create: `tests/unit/types/test_protocols.py`

**Step 1: Write tests for protocols**

Create `tests/unit/types/test_protocols.py`:
```python
"""Tests for protocol definitions."""

from typing import Protocol, runtime_checkable

from descope_mgmt.types.protocols import DescopeClientProtocol, RateLimiterProtocol


def test_descope_client_protocol_is_protocol() -> None:
    """Test DescopeClientProtocol is a Protocol."""
    assert isinstance(DescopeClientProtocol, type)
    assert issubclass(DescopeClientProtocol, Protocol)


def test_rate_limiter_protocol_is_protocol() -> None:
    """Test RateLimiterProtocol is a Protocol."""
    assert isinstance(RateLimiterProtocol, type)
    assert issubclass(RateLimiterProtocol, Protocol)


def test_descope_client_protocol_runtime_checkable() -> None:
    """Test DescopeClientProtocol is runtime checkable."""
    # Protocol should be runtime_checkable for isinstance checks
    class FakeClient:
        def create_tenant(self, config: dict[str, str]) -> dict[str, str]:
            return {}

        def update_tenant(self, tenant_id: str, config: dict[str, str]) -> dict[str, str]:
            return {}

        def delete_tenant(self, tenant_id: str) -> None:
            pass

    fake = FakeClient()
    assert isinstance(fake, DescopeClientProtocol)
```

**Step 2: Run tests to verify failure**

```bash
pytest tests/unit/types/test_protocols.py -v
```

Expected: All 3 tests FAIL (module doesn't exist)

**Step 3: Implement protocols**

Create `src/descope_mgmt/types/protocols.py`:
```python
"""Protocol definitions for external boundaries (dependency injection)."""

from typing import Protocol, runtime_checkable


@runtime_checkable
class DescopeClientProtocol(Protocol):
    """Protocol for Descope API client operations.

    This defines the contract for external API calls. Only external boundaries
    get protocols (not internal services like TenantManager).
    """

    def create_tenant(self, config: dict[str, str]) -> dict[str, str]:
        """Create a new tenant.

        Args:
            config: Tenant configuration dictionary

        Returns:
            Response dictionary with tenant details
        """
        ...

    def update_tenant(
        self, tenant_id: str, config: dict[str, str]
    ) -> dict[str, str]:
        """Update an existing tenant.

        Args:
            tenant_id: Unique tenant identifier
            config: Updated configuration dictionary

        Returns:
            Response dictionary with updated tenant details
        """
        ...

    def delete_tenant(self, tenant_id: str) -> None:
        """Delete a tenant.

        Args:
            tenant_id: Unique tenant identifier
        """
        ...


@runtime_checkable
class RateLimiterProtocol(Protocol):
    """Protocol for rate limiting operations.

    Single rate limiter for all Descope operations (v1.0 simplicity).
    """

    def acquire(self, weight: int = 1) -> None:
        """Acquire permission to make API call(s).

        Blocks if rate limit would be exceeded.

        Args:
            weight: Number of requests this operation counts as (default: 1)
        """
        ...
```

**Step 4: Run tests to verify pass**

```bash
pytest tests/unit/types/test_protocols.py -v
```

Expected: All 3 tests PASS

**Step 5: Commit**

```bash
git add src/descope_mgmt/types/protocols.py tests/unit/types/test_protocols.py
git commit -m "feat: add Protocol definitions for DescopeClient and RateLimiter"
```

---

## Task 3: Update types __init__.py

**Files:**
- Modify: `src/descope_mgmt/types/__init__.py`

**Step 1: Export public types**

```python
"""Type system for descope-mgmt.

This module contains all type definitions, protocols, and shared base classes.
Organized to prevent circular imports using the validated hybrid approach.
"""

from descope_mgmt.types.protocols import DescopeClientProtocol, RateLimiterProtocol
from descope_mgmt.types.shared import ResourceIdentifier

__all__ = [
    "ResourceIdentifier",
    "DescopeClientProtocol",
    "RateLimiterProtocol",
]
```

**Step 2: Commit**

```bash
git add src/descope_mgmt/types/__init__.py
git commit -m "feat: export public types from types module"
```

---

## Chunk Complete Checklist

- [ ] ResourceIdentifier base model created with 4 tests
- [ ] Protocol definitions created with 3 tests
- [ ] types/__init__.py exports public API
- [ ] All 7 tests passing
- [ ] mypy passes with strict mode
- [ ] 3 commits created
- [ ] Ready for chunk 4
