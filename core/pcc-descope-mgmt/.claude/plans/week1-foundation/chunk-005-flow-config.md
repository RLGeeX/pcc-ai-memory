# Chunk 5: FlowConfig and ProjectSettings Models

**Status:** pending
**Dependencies:** chunk-003-type-system
**Complexity:** simple
**Estimated Time:** 15 minutes
**Tasks:** 2

---

## Task 1: Create FlowConfig Model

**Files:**
- Create: `src/descope_mgmt/types/flow.py`
- Create: `tests/unit/types/test_flow.py`

**Step 1: Write failing tests**

Create `tests/unit/types/test_flow.py`:
```python
"""Tests for flow configuration model."""

import pytest
from pydantic import ValidationError

from descope_mgmt.types.flow import FlowConfig


def test_flow_config_minimal() -> None:
    """Test FlowConfig with minimal fields."""
    config = FlowConfig(
        id="flow-login",
        name="Login Flow",
        flow_type="login"
    )
    assert config.id == "flow-login"
    assert config.name == "Login Flow"
    assert config.flow_type == "login"
    assert config.description is None


def test_flow_config_with_description() -> None:
    """Test FlowConfig with description."""
    config = FlowConfig(
        id="flow-mfa",
        name="MFA Flow",
        flow_type="mfa",
        description="Multi-factor authentication flow"
    )
    assert config.description == "Multi-factor authentication flow"


def test_flow_config_invalid_type() -> None:
    """Test FlowConfig rejects invalid flow type."""
    with pytest.raises(ValidationError) as exc_info:
        FlowConfig(
            id="flow-test",
            name="Test Flow",
            flow_type="invalid-type"
        )
    assert "flow_type" in str(exc_info.value).lower()
```

**Step 2: Run tests (expect failure)**

```bash
pytest tests/unit/types/test_flow.py -v
```

Expected: All 3 tests FAIL

**Step 3: Implement FlowConfig**

Create `src/descope_mgmt/types/flow.py`:
```python
"""Flow configuration model."""

from typing import Literal

from pydantic import Field

from descope_mgmt.types.shared import ResourceIdentifier

FlowType = Literal["login", "signup", "mfa", "password-reset", "magic-link"]


class FlowConfig(ResourceIdentifier):
    """Flow configuration model.

    Represents a Descope authentication flow template.
    Design note: Flow template details deferred until Flow API exploration (Week 5).
    """

    flow_type: FlowType = Field(
        ...,
        description="Type of authentication flow"
    )

    model_config = {"frozen": True}
```

**Step 4: Run tests (expect pass)**

```bash
pytest tests/unit/types/test_flow.py -v
```

Expected: All 3 tests PASS

**Step 5: Commit**

```bash
git add src/descope_mgmt/types/flow.py tests/unit/types/test_flow.py
git commit -m "feat: add FlowConfig model with flow type validation"
```

---

## Task 2: Create ProjectSettings Model

**Files:**
- Create: `src/descope_mgmt/types/project.py`
- Create: `tests/unit/types/test_project.py`

**Step 1: Write failing tests**

Create `tests/unit/types/test_project.py`:
```python
"""Tests for project settings model."""

import pytest
from pydantic import ValidationError

from descope_mgmt.types.project import ProjectSettings


def test_project_settings_valid() -> None:
    """Test ProjectSettings with valid data."""
    settings = ProjectSettings(
        project_id="P2test123",
        management_key="K2secret123",
        environment="test"
    )
    assert settings.project_id == "P2test123"
    assert settings.management_key == "K2secret123"
    assert settings.environment == "test"


def test_project_settings_all_environments() -> None:
    """Test all valid environments."""
    for env in ["test", "devtest", "dev", "staging", "prod"]:
        settings = ProjectSettings(
            project_id="P2test",
            management_key="K2secret",
            environment=env
        )
        assert settings.environment == env


def test_project_settings_invalid_environment() -> None:
    """Test ProjectSettings rejects invalid environment."""
    with pytest.raises(ValidationError) as exc_info:
        ProjectSettings(
            project_id="P2test",
            management_key="K2secret",
            environment="invalid"
        )
    assert "environment" in str(exc_info.value).lower()
```

**Step 2: Run tests (expect failure)**

```bash
pytest tests/unit/types/test_project.py -v
```

Expected: All 3 tests FAIL

**Step 3: Implement ProjectSettings**

Create `src/descope_mgmt/types/project.py`:
```python
"""Project settings model."""

from typing import Literal

from pydantic import BaseModel, Field

Environment = Literal["test", "devtest", "dev", "staging", "prod"]


class ProjectSettings(BaseModel):
    """Project settings for a Descope environment.

    Each of the 5 environments has its own Descope project with separate ID and key.
    """

    project_id: str = Field(
        ...,
        description="Descope project ID (starts with P2)"
    )
    management_key: str = Field(
        ...,
        description="Descope management API key (starts with K2)",
        repr=False  # Don't include in repr for security
    )
    environment: Environment = Field(
        ...,
        description="Environment name (test/devtest/dev/staging/prod)"
    )

    model_config = {"frozen": True}
```

**Step 4: Run tests (expect pass)**

```bash
pytest tests/unit/types/test_project.py -v
```

Expected: All 3 tests PASS

**Step 5: Update types exports and commit**

Modify `src/descope_mgmt/types/__init__.py`:
```python
"""Type system for descope-mgmt."""

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
]
```

```bash
git add src/descope_mgmt/types/ tests/unit/types/test_project.py
git commit -m "feat: add FlowConfig and ProjectSettings models"
```

---

## Chunk Complete Checklist

- [ ] FlowConfig model with 3 tests
- [ ] ProjectSettings model with 3 tests
- [ ] All 20 type tests passing (14 + 3 + 3)
- [ ] mypy strict mode passes
- [ ] types module exports all models
- [ ] 2 commits created
- [ ] Ready for chunk 6
