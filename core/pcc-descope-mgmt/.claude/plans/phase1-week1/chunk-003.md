# Chunk 3: TenantConfig Pydantic Model

**Status:** pending
**Dependencies:** chunk-001, chunk-002
**Estimated Time:** 30-45 minutes

---

## Task 1: Create TenantConfig Model with Validators

**Files:**
- Create: `src/descope_mgmt/domain/models/config.py`
- Create: `tests/unit/domain/test_tenant_config.py`

**Step 1: Write failing tests for TenantConfig**

Create `tests/unit/domain/test_tenant_config.py`:
```python
"""Tests for TenantConfig Pydantic model"""
import pytest
from pydantic import ValidationError
from descope_mgmt.domain.models.config import TenantConfig


def test_tenant_config_valid():
    """Valid tenant config should pass validation"""
    config = TenantConfig(
        id="acme-corp",
        name="Acme Corporation",
        domains=["acme.com"],
        self_provisioning=True,
        custom_attributes={"plan": "enterprise"}
    )
    assert config.id == "acme-corp"
    assert config.name == "Acme Corporation"
    assert config.domains == ["acme.com"]
    assert config.self_provisioning is True


def test_tenant_config_minimal():
    """Minimal tenant config with defaults"""
    config = TenantConfig(id="widget-co", name="Widget Co")
    assert config.id == "widget-co"
    assert config.domains == []
    assert config.self_provisioning is False
    assert config.custom_attributes == {}


def test_tenant_id_lowercase_only():
    """Tenant ID must be lowercase"""
    with pytest.raises(ValidationError) as exc_info:
        TenantConfig(id="AcmeCorp", name="Acme")
    errors = exc_info.value.errors()
    assert any("pattern" in str(e) for e in errors)


def test_tenant_id_no_special_chars():
    """Tenant ID allows only alphanumeric and hyphens"""
    with pytest.raises(ValidationError):
        TenantConfig(id="acme_corp!", name="Acme")


def test_tenant_id_length_constraints():
    """Tenant ID must be 3-50 characters"""
    # Too short
    with pytest.raises(ValidationError):
        TenantConfig(id="ab", name="Short")

    # Too long
    with pytest.raises(ValidationError):
        TenantConfig(id="a" * 51, name="Long")

    # Just right
    config = TenantConfig(id="abc", name="Min Length")
    assert config.id == "abc"


def test_tenant_name_required():
    """Tenant name is required"""
    with pytest.raises(ValidationError):
        TenantConfig(id="acme-corp")  # type: ignore


def test_tenant_name_length():
    """Tenant name must be 1-100 characters"""
    with pytest.raises(ValidationError):
        TenantConfig(id="acme-corp", name="")

    with pytest.raises(ValidationError):
        TenantConfig(id="acme-corp", name="x" * 101)


def test_domain_validation():
    """Domains must be valid DNS format"""
    # Valid domains
    config = TenantConfig(
        id="acme-corp",
        name="Acme",
        domains=["acme.com", "acme.net", "subdomain.acme.com"]
    )
    assert len(config.domains) == 3

    # Invalid domain
    with pytest.raises(ValidationError) as exc_info:
        TenantConfig(
            id="acme-corp",
            name="Acme",
            domains=["invalid domain!"]
        )
    assert "Invalid domain format" in str(exc_info.value)


def test_tenant_config_immutable():
    """TenantConfig should be frozen (immutable)"""
    config = TenantConfig(id="acme-corp", name="Acme")
    with pytest.raises(ValidationError):
        config.id = "new-id"  # type: ignore


def test_tenant_config_extra_fields_forbidden():
    """Extra fields should be rejected"""
    with pytest.raises(ValidationError):
        TenantConfig(
            id="acme-corp",
            name="Acme",
            unknown_field="value"  # type: ignore
        )


def test_tenant_config_whitespace_stripped():
    """Whitespace should be stripped from strings"""
    config = TenantConfig(id="  acme-corp  ", name="  Acme Corporation  ")
    assert config.id == "acme-corp"
    assert config.name == "Acme Corporation"
```

**Step 2: Run tests to verify they fail**

Run: `pytest tests/unit/domain/test_tenant_config.py -v`

Expected: FAIL with import errors and missing TenantConfig

**Step 3: Implement TenantConfig model**

Create `src/descope_mgmt/domain/models/config.py`:
```python
"""Pydantic models for configuration files.

These models validate and parse YAML configuration files.
"""
import re
from typing import Any
from pydantic import BaseModel, Field, field_validator, ConfigDict


class TenantConfig(BaseModel):
    """Configuration for a single tenant.

    Example:
        ```yaml
        id: acme-corp
        name: Acme Corporation
        domains:
          - acme.com
          - acme.net
        self_provisioning: true
        custom_attributes:
          plan: enterprise
          entity_type: portfolio_company
        ```
    """
    model_config = ConfigDict(
        frozen=True,  # Immutable after creation
        extra='forbid',  # Reject unknown fields
        str_strip_whitespace=True,  # Strip whitespace
        validate_assignment=True  # Validate on assignment
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
        description="Tenant display name"
    )
    domains: list[str] = Field(
        default_factory=list,
        description="List of domains for this tenant"
    )
    self_provisioning: bool = Field(
        default=False,
        description="Allow self-service user provisioning"
    )
    custom_attributes: dict[str, Any] = Field(
        default_factory=dict,
        description="Custom attributes for tenant metadata"
    )

    @field_validator('domains')
    @classmethod
    def validate_domains(cls, v: list[str]) -> list[str]:
        """Validate domain format (RFC 1035)"""
        domain_pattern = re.compile(r'^(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$')
        for domain in v:
            if not domain_pattern.match(domain):
                raise ValueError(f"Invalid domain format: {domain}")
        return v
```

**Step 4: Run tests to verify they pass**

Run: `pytest tests/unit/domain/test_tenant_config.py -v`

Expected: PASS (all 12 tests)

**Step 5: Commit**

```bash
git add src/descope_mgmt/domain/models/config.py tests/unit/domain/test_tenant_config.py
git commit -m "feat: add TenantConfig Pydantic model with validators"
```

---

## Chunk Complete Checklist

- [ ] TenantConfig model implemented
- [ ] 12 tests passing
- [ ] All validators working (ID pattern, domain format, length constraints)
- [ ] Model is frozen (immutable)
- [ ] Extra fields forbidden
- [ ] Whitespace stripped
- [ ] Commit made
