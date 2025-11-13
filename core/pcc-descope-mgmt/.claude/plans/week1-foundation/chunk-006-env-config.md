# Chunk 6: Environment Configuration Model

**Status:** pending
**Dependencies:** chunk-005-flow-config
**Complexity:** medium
**Estimated Time:** 20 minutes
**Tasks:** 2

---

## Task 1: Create DescopeConfig Model

**Files:**
- Create: `src/descope_mgmt/types/config.py`
- Create: `tests/unit/types/test_config.py`

**Step 1: Write failing tests**

Create `tests/unit/types/test_config.py`:
```python
"""Tests for configuration models."""

import pytest
from pydantic import ValidationError

from descope_mgmt.types.config import DescopeConfig
from descope_mgmt.types.flow import FlowConfig
from descope_mgmt.types.project import ProjectSettings
from descope_mgmt.types.tenant import TenantConfig


def test_descope_config_minimal() -> None:
    """Test DescopeConfig with minimal configuration."""
    project = ProjectSettings(
        project_id="P2test",
        management_key="K2secret",
        environment="test"
    )
    config = DescopeConfig(project=project, tenants=[], flows=[])
    assert config.project.environment == "test"
    assert len(config.tenants) == 0
    assert len(config.flows) == 0


def test_descope_config_with_tenants() -> None:
    """Test DescopeConfig with tenant definitions."""
    project = ProjectSettings(
        project_id="P2test",
        management_key="K2secret",
        environment="test"
    )
    tenants = [
        TenantConfig(id="tenant-1", name="Tenant 1", domains=["t1.com"]),
        TenantConfig(id="tenant-2", name="Tenant 2", domains=["t2.com"]),
    ]
    config = DescopeConfig(project=project, tenants=tenants, flows=[])
    assert len(config.tenants) == 2


def test_descope_config_with_flows() -> None:
    """Test DescopeConfig with flow definitions."""
    project = ProjectSettings(
        project_id="P2test",
        management_key="K2secret",
        environment="test"
    )
    flows = [
        FlowConfig(id="flow-1", name="Login", flow_type="login"),
        FlowConfig(id="flow-2", name="MFA", flow_type="mfa"),
    ]
    config = DescopeConfig(project=project, tenants=[], flows=flows)
    assert len(config.flows) == 2


def test_descope_config_duplicate_tenant_ids() -> None:
    """Test DescopeConfig rejects duplicate tenant IDs."""
    project = ProjectSettings(
        project_id="P2test",
        management_key="K2secret",
        environment="test"
    )
    tenants = [
        TenantConfig(id="tenant-1", name="Tenant 1", domains=["t1.com"]),
        TenantConfig(id="tenant-1", name="Tenant Duplicate", domains=["t2.com"]),
    ]
    with pytest.raises(ValidationError) as exc_info:
        DescopeConfig(project=project, tenants=tenants, flows=[])
    assert "duplicate" in str(exc_info.value).lower()


def test_descope_config_duplicate_flow_ids() -> None:
    """Test DescopeConfig rejects duplicate flow IDs."""
    project = ProjectSettings(
        project_id="P2test",
        management_key="K2secret",
        environment="test"
    )
    flows = [
        FlowConfig(id="flow-1", name="Login 1", flow_type="login"),
        FlowConfig(id="flow-1", name="Login 2", flow_type="login"),
    ]
    with pytest.raises(ValidationError) as exc_info:
        DescopeConfig(project=project, tenants=[], flows=flows)
    assert "duplicate" in str(exc_info.value).lower()
```

**Step 2: Run tests (expect failure)**

```bash
pytest tests/unit/types/test_config.py -v
```

Expected: All 5 tests FAIL

**Step 3: Implement DescopeConfig**

Create `src/descope_mgmt/types/config.py`:
```python
"""Configuration models for Descope management."""

from pydantic import BaseModel, Field, field_validator

from descope_mgmt.types.flow import FlowConfig
from descope_mgmt.types.project import ProjectSettings
from descope_mgmt.types.tenant import TenantConfig


class DescopeConfig(BaseModel):
    """Complete Descope configuration for an environment.

    Combines project settings with tenant and flow definitions.
    Validates uniqueness of IDs across resources.
    """

    project: ProjectSettings = Field(
        ...,
        description="Project settings for this environment"
    )
    tenants: list[TenantConfig] = Field(
        default_factory=list,
        description="List of tenant configurations"
    )
    flows: list[FlowConfig] = Field(
        default_factory=list,
        description="List of flow configurations"
    )

    @field_validator("tenants")
    @classmethod
    def validate_unique_tenant_ids(cls, v: list[TenantConfig]) -> list[TenantConfig]:
        """Validate tenant IDs are unique."""
        ids = [tenant.id for tenant in v]
        if len(ids) != len(set(ids)):
            raise ValueError("Duplicate tenant IDs found")
        return v

    @field_validator("flows")
    @classmethod
    def validate_unique_flow_ids(cls, v: list[FlowConfig]) -> list[FlowConfig]:
        """Validate flow IDs are unique."""
        ids = [flow.id for flow in v]
        if len(ids) != len(set(ids)):
            raise ValueError("Duplicate flow IDs found")
        return v

    model_config = {"frozen": True}
```

**Step 4: Run tests (expect pass)**

```bash
pytest tests/unit/types/test_config.py -v
```

Expected: All 5 tests PASS

**Step 5: Commit**

```bash
git add src/descope_mgmt/types/config.py tests/unit/types/test_config.py
git commit -m "feat: add DescopeConfig model with uniqueness validation"
```

---

## Task 2: Update types exports and verify all tests

**Files:**
- Modify: `src/descope_mgmt/types/__init__.py`

**Step 1: Export DescopeConfig**

```python
"""Type system for descope-mgmt."""

from descope_mgmt.types.config import DescopeConfig
from descope_mgmt.types.flow import FlowConfig
from descope_mgmt.types.project import ProjectSettings
from descope_mgmt.types.protocols import DescopeClientProtocol, RateLimiterProtocol
from descope_mgmt.types.shared import ResourceIdentifier
from descope_mgmt.types.tenant import TenantConfig

__all__ = [
    "ResourceIdentifier",
    "DescopeClientProtocol",
    "RateLimiterProtocol",
    "TenantConfig",
    "FlowConfig",
    "ProjectSettings",
    "DescopeConfig",
]
```

**Step 2: Run all type tests**

```bash
pytest tests/unit/types/ -v --cov=src/descope_mgmt/types
```

Expected: All 25 tests PASS with >90% coverage

**Step 3: Run mypy**

```bash
mypy src/descope_mgmt/types/
```

Expected: Success, no errors

**Step 4: Commit**

```bash
git add src/descope_mgmt/types/__init__.py
git commit -m "feat: export DescopeConfig from types module"
```

---

## Chunk Complete Checklist

- [ ] DescopeConfig model with 5 tests
- [ ] Uniqueness validation for tenant/flow IDs
- [ ] All 25 type tests passing
- [ ] >90% test coverage for types module
- [ ] mypy strict mode passes
- [ ] types module complete (CHECKPOINT 1)
- [ ] 2 commits created
- [ ] Ready for chunk 7
