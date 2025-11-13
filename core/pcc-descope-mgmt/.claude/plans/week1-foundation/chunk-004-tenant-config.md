# Chunk 4: TenantConfig Model with Pydantic Validators

**Status:** pending
**Dependencies:** chunk-003-type-system
**Complexity:** medium
**Estimated Time:** 20 minutes
**Tasks:** 2

---

## Task 1: Create TenantConfig Model

**Files:**
- Create: `src/descope_mgmt/types/tenant.py`
- Create: `tests/unit/types/test_tenant.py`

**Step 1: Write failing tests**

Create `tests/unit/types/test_tenant.py`:
```python
"""Tests for tenant configuration model."""

import pytest
from pydantic import ValidationError

from descope_mgmt.types.tenant import TenantConfig


def test_tenant_config_minimal() -> None:
    """Test TenantConfig with minimal required fields."""
    config = TenantConfig(
        id="tenant-123",
        name="Acme Corp",
        domains=["acme.com"]
    )
    assert config.id == "tenant-123"
    assert config.name == "Acme Corp"
    assert config.domains == ["acme.com"]
    assert config.description is None
    assert config.flow_ids == []
    assert config.enabled is True


def test_tenant_config_full() -> None:
    """Test TenantConfig with all fields."""
    config = TenantConfig(
        id="tenant-123",
        name="Acme Corp",
        description="Acme Corporation tenant",
        domains=["acme.com", "acme.io"],
        flow_ids=["flow-login", "flow-mfa"],
        enabled=False
    )
    assert config.description == "Acme Corporation tenant"
    assert len(config.domains) == 2
    assert len(config.flow_ids) == 2
    assert config.enabled is False


def test_tenant_config_invalid_domain() -> None:
    """Test TenantConfig rejects invalid domain."""
    with pytest.raises(ValidationError) as exc_info:
        TenantConfig(
            id="tenant-123",
            name="Acme Corp",
            domains=["not a valid domain!"]
        )
    assert "domain" in str(exc_info.value).lower()


def test_tenant_config_empty_domains() -> None:
    """Test TenantConfig requires at least one domain."""
    with pytest.raises(ValidationError) as exc_info:
        TenantConfig(
            id="tenant-123",
            name="Acme Corp",
            domains=[]
        )
    assert "domains" in str(exc_info.value).lower()


def test_tenant_config_duplicate_domains() -> None:
    """Test TenantConfig rejects duplicate domains."""
    with pytest.raises(ValidationError) as exc_info:
        TenantConfig(
            id="tenant-123",
            name="Acme Corp",
            domains=["acme.com", "acme.com"]
        )
    assert "duplicate" in str(exc_info.value).lower()


def test_tenant_config_id_format() -> None:
    """Test TenantConfig validates ID format."""
    with pytest.raises(ValidationError) as exc_info:
        TenantConfig(
            id="Invalid ID!",
            name="Acme Corp",
            domains=["acme.com"]
        )
    assert "id" in str(exc_info.value).lower()


def test_tenant_config_to_dict() -> None:
    """Test TenantConfig serialization."""
    config = TenantConfig(
        id="tenant-123",
        name="Acme Corp",
        domains=["acme.com"]
    )
    data = config.model_dump()
    assert data["id"] == "tenant-123"
    assert isinstance(data["domains"], list)
```

**Step 2: Run tests to verify failure**

```bash
pytest tests/unit/types/test_tenant.py -v
```

Expected: All 7 tests FAIL (module doesn't exist)

**Step 3: Implement TenantConfig**

Create `src/descope_mgmt/types/tenant.py`:
```python
"""Tenant configuration model."""

import re
from typing import Annotated

from pydantic import Field, field_validator

from descope_mgmt.types.shared import ResourceIdentifier

# Domain regex: basic domain validation
DOMAIN_PATTERN = re.compile(
    r"^(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$"
)

# Tenant ID pattern: lowercase alphanumeric with hyphens
TENANT_ID_PATTERN = re.compile(r"^[a-z0-9][a-z0-9-]*[a-z0-9]$")


class TenantConfig(ResourceIdentifier):
    """Tenant configuration model.

    Represents a Descope tenant with validation for domains and IDs.
    Uses ID references for flows (not nested objects) per validated design.
    """

    domains: Annotated[
        list[str],
        Field(
            min_length=1,
            description="List of domains for this tenant (at least one required)"
        )
    ]
    flow_ids: list[str] = Field(
        default_factory=list,
        description="Flow IDs to associate with this tenant (references by ID)"
    )
    enabled: bool = Field(
        default=True,
        description="Whether the tenant is enabled"
    )

    @field_validator("id")
    @classmethod
    def validate_tenant_id(cls, v: str) -> str:
        """Validate tenant ID format."""
        if not TENANT_ID_PATTERN.match(v):
            raise ValueError(
                f"Tenant ID must be lowercase alphanumeric with hyphens: {v}"
            )
        return v

    @field_validator("domains")
    @classmethod
    def validate_domains(cls, v: list[str]) -> list[str]:
        """Validate domain format and uniqueness."""
        if not v:
            raise ValueError("At least one domain is required")

        # Check for duplicates
        if len(v) != len(set(v)):
            raise ValueError("Duplicate domains not allowed")

        # Validate each domain
        for domain in v:
            if not DOMAIN_PATTERN.match(domain):
                raise ValueError(f"Invalid domain format: {domain}")

        return v

    model_config = {"frozen": True}  # Immutable
```

**Step 4: Run tests to verify pass**

```bash
pytest tests/unit/types/test_tenant.py -v
```

Expected: All 7 tests PASS

**Step 5: Commit**

```bash
git add src/descope_mgmt/types/tenant.py tests/unit/types/test_tenant.py
git commit -m "feat: add TenantConfig model with domain and ID validation"
```

---

## Task 2: Update types exports

**Files:**
- Modify: `src/descope_mgmt/types/__init__.py`

**Step 1: Export TenantConfig**

```python
"""Type system for descope-mgmt."""

from descope_mgmt.types.protocols import DescopeClientProtocol, RateLimiterProtocol
from descope_mgmt.types.shared import ResourceIdentifier
from descope_mgmt.types.tenant import TenantConfig

__all__ = [
    "ResourceIdentifier",
    "DescopeClientProtocol",
    "RateLimiterProtocol",
    "TenantConfig",
]
```

**Step 2: Run all type tests**

```bash
pytest tests/unit/types/ -v
```

Expected: All tests PASS (14 total now)

**Step 3: Commit**

```bash
git add src/descope_mgmt/types/__init__.py
git commit -m "feat: export TenantConfig from types module"
```

---

## Chunk Complete Checklist

- [ ] TenantConfig model created with 7 tests
- [ ] Domain validation with regex
- [ ] ID format validation
- [ ] Duplicate domain detection
- [ ] types module exports TenantConfig
- [ ] All 14 type tests passing
- [ ] mypy strict mode passes
- [ ] 2 commits created
- [ ] Ready for chunk 5
