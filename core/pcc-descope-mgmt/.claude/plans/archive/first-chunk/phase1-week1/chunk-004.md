# Chunk 4: FlowConfig and DescopeConfig Models

**Status:** pending
**Dependencies:** chunk-001, chunk-002, chunk-003
**Estimated Time:** 30-45 minutes

---

## Task 1: Create FlowConfig Model

**Files:**
- Modify: `src/descope_mgmt/domain/models/config.py`
- Create: `tests/unit/domain/test_flow_config.py`

**Step 1: Write failing tests**

Create `tests/unit/domain/test_flow_config.py`:
```python
"""Tests for FlowConfig Pydantic model"""
import pytest
from pydantic import ValidationError
from descope_mgmt.domain.models.config import FlowConfig


def test_flow_config_valid():
    """Valid flow config should pass validation"""
    config = FlowConfig(
        template="sign-up-or-in",
        name="Default Login Flow",
        enabled=True,
        config={"methods": ["email", "sms"]}
    )
    assert config.template == "sign-up-or-in"
    assert config.name == "Default Login Flow"
    assert config.enabled is True


def test_flow_config_minimal():
    """Minimal flow config with defaults"""
    config = FlowConfig(template="mfa-login", name="MFA Flow")
    assert config.template == "mfa-login"
    assert config.enabled is True  # Default
    assert config.config == {}  # Default


def test_flow_template_required():
    """Flow template is required"""
    with pytest.raises(ValidationError):
        FlowConfig(name="Test Flow")  # type: ignore


def test_flow_name_required():
    """Flow name is required"""
    with pytest.raises(ValidationError):
        FlowConfig(template="sign-up-or-in")  # type: ignore
```

**Step 2: Run tests to verify they fail**

Run: `pytest tests/unit/domain/test_flow_config.py -v`

Expected: FAIL with missing FlowConfig

**Step 3: Add FlowConfig to config.py**

Add to `src/descope_mgmt/domain/models/config.py`:
```python
class FlowConfig(BaseModel):
    """Configuration for an authentication flow.

    Example:
        ```yaml
        template: mfa-login
        name: Multi-Factor Authentication
        enabled: true
        config:
          methods: [sms, totp, email]
          remember_device: true
          remember_duration_days: 30
        ```
    """
    model_config = ConfigDict(
        frozen=True,
        extra='forbid',
        str_strip_whitespace=True,
        validate_assignment=True
    )

    template: str = Field(
        ...,
        min_length=1,
        description="Flow template identifier"
    )
    name: str = Field(
        ...,
        min_length=1,
        max_length=100,
        description="Flow display name"
    )
    enabled: bool = Field(
        default=True,
        description="Whether flow is enabled"
    )
    config: dict[str, Any] = Field(
        default_factory=dict,
        description="Flow-specific configuration"
    )
```

**Step 4: Run tests to verify they pass**

Run: `pytest tests/unit/domain/test_flow_config.py -v`

Expected: PASS (all 4 tests)

**Step 5: Commit**

```bash
git add src/descope_mgmt/domain/models/config.py tests/unit/domain/test_flow_config.py
git commit -m "feat: add FlowConfig Pydantic model"
```

---

## Task 2: Create DescopeConfig Top-Level Model

**Files:**
- Modify: `src/descope_mgmt/domain/models/config.py`
- Create: `tests/unit/domain/test_descope_config.py`

**Step 1: Write failing tests**

Create `tests/unit/domain/test_descope_config.py`:
```python
"""Tests for DescopeConfig top-level model"""
import pytest
from pydantic import ValidationError
from descope_mgmt.domain.models.config import DescopeConfig


def test_descope_config_valid():
    """Valid top-level config should parse"""
    config = DescopeConfig(
        version="1.0",
        auth={"project_id": "P2abc", "management_key": "K2xyz"},
        environments={
            "test": {"project_id": "P2test"},
            "dev": {"project_id": "P2dev"}
        },
        tenants=[
            {"id": "acme-corp", "name": "Acme Corporation"}
        ],
        flows=[
            {"template": "sign-up-or-in", "name": "Login"}
        ]
    )
    assert config.version == "1.0"
    assert len(config.tenants) == 1
    assert len(config.flows) == 1
    assert len(config.environments) == 2


def test_descope_config_minimal():
    """Minimal config with defaults"""
    config = DescopeConfig(version="1.0")
    assert config.tenants == []
    assert config.flows == []
    assert config.environments == {}


def test_version_required():
    """Version field is required"""
    with pytest.raises(ValidationError):
        DescopeConfig()  # type: ignore


def test_tenant_configs_parsed():
    """Tenants should be parsed as TenantConfig instances"""
    config = DescopeConfig(
        version="1.0",
        tenants=[{"id": "test-tenant", "name": "Test"}]
    )
    assert len(config.tenants) == 1
    from descope_mgmt.domain.models.config import TenantConfig
    assert isinstance(config.tenants[0], TenantConfig)


def test_flow_configs_parsed():
    """Flows should be parsed as FlowConfig instances"""
    config = DescopeConfig(
        version="1.0",
        flows=[{"template": "mfa", "name": "MFA"}]
    )
    assert len(config.flows) == 1
    from descope_mgmt.domain.models.config import FlowConfig
    assert isinstance(config.flows[0], FlowConfig)
```

**Step 2: Run tests to verify they fail**

Run: `pytest tests/unit/domain/test_descope_config.py -v`

Expected: FAIL with missing DescopeConfig

**Step 3: Add DescopeConfig to config.py**

Add to `src/descope_mgmt/domain/models/config.py`:
```python
class AuthConfig(BaseModel):
    """Authentication configuration."""
    project_id: str = Field(..., description="Descope project ID")
    management_key: str = Field(..., description="Descope management key")


class EnvironmentConfig(BaseModel):
    """Environment-specific configuration."""
    project_id: str = Field(..., description="Descope project ID for this environment")


class DescopeConfig(BaseModel):
    """Top-level configuration file structure.

    Example:
        ```yaml
        version: "1.0"
        auth:
          project_id: "${DESCOPE_PROJECT_ID}"
          management_key: "${DESCOPE_MANAGEMENT_KEY}"
        environments:
          test:
            project_id: "P2test123"
          dev:
            project_id: "P2dev456"
        tenants:
          - id: acme-corp
            name: Acme Corporation
        flows:
          - template: sign-up-or-in
            name: Default Login
        ```
    """
    model_config = ConfigDict(
        extra='forbid',
        str_strip_whitespace=True
    )

    version: str = Field(..., description="Config file format version")
    auth: AuthConfig | None = Field(None, description="Authentication settings")
    environments: dict[str, EnvironmentConfig] = Field(
        default_factory=dict,
        description="Environment-specific project IDs"
    )
    tenants: list[TenantConfig] = Field(
        default_factory=list,
        description="Tenant configurations"
    )
    flows: list[FlowConfig] = Field(
        default_factory=list,
        description="Flow configurations"
    )
```

**Step 4: Run tests to verify they pass**

Run: `pytest tests/unit/domain/test_descope_config.py -v`

Expected: PASS (all 5 tests)

**Step 5: Commit**

```bash
git add src/descope_mgmt/domain/models/config.py tests/unit/domain/test_descope_config.py
git commit -m "feat: add DescopeConfig top-level model"
```

---

## Chunk Complete Checklist

- [ ] FlowConfig model (4 tests)
- [ ] DescopeConfig top-level model (5 tests)
- [ ] Total: 9 tests passing in this chunk
- [ ] All models use Pydantic validation
- [ ] All commits made
