# Chunk 7: YAML Configuration Loader

**Status:** pending
**Dependencies:** chunk-006-env-config
**Complexity:** medium
**Estimated Time:** 25 minutes
**Tasks:** 2

---

## Task 1: Create Environment Variable Substitution

**Files:**
- Create: `src/descope_mgmt/domain/env_sub.py`
- Create: `tests/unit/domain/test_env_sub.py`

**Step 1: Write failing tests**

Create `tests/unit/domain/__init__.py`:
```python
"""Unit tests for domain layer."""
```

Create `tests/unit/domain/test_env_sub.py`:
```python
"""Tests for environment variable substitution."""

import os

import pytest

from descope_mgmt.domain.env_sub import substitute_env_vars


def test_substitute_env_vars_no_substitution() -> None:
    """Test substitution with no env vars."""
    data = {"key": "value", "nested": {"inner": "data"}}
    result = substitute_env_vars(data)
    assert result == data


def test_substitute_env_vars_simple(monkeypatch: pytest.MonkeyPatch) -> None:
    """Test simple environment variable substitution."""
    monkeypatch.setenv("TEST_VAR", "test_value")
    data = {"key": "${TEST_VAR}"}
    result = substitute_env_vars(data)
    assert result == {"key": "test_value"}


def test_substitute_env_vars_nested(monkeypatch: pytest.MonkeyPatch) -> None:
    """Test nested environment variable substitution."""
    monkeypatch.setenv("API_KEY", "secret123")
    data = {
        "project": {
            "management_key": "${API_KEY}",
            "name": "test"
        }
    }
    result = substitute_env_vars(data)
    assert result["project"]["management_key"] == "secret123"


def test_substitute_env_vars_missing() -> None:
    """Test error on missing environment variable."""
    data = {"key": "${MISSING_VAR}"}
    with pytest.raises(ValueError) as exc_info:
        substitute_env_vars(data)
    assert "MISSING_VAR" in str(exc_info.value)


def test_substitute_env_vars_list(monkeypatch: pytest.MonkeyPatch) -> None:
    """Test substitution in lists."""
    monkeypatch.setenv("DOMAIN", "example.com")
    data = {"domains": ["${DOMAIN}", "other.com"]}
    result = substitute_env_vars(data)
    assert result == {"domains": ["example.com", "other.com"]}
```

**Step 2: Run tests (expect failure)**

```bash
pytest tests/unit/domain/test_env_sub.py -v
```

Expected: All 5 tests FAIL

**Step 3: Implement env_sub.py**

Create `src/descope_mgmt/domain/__init__.py`:
```python
"""Domain layer for business logic."""
```

Create `src/descope_mgmt/domain/env_sub.py`:
```python
"""Environment variable substitution for configuration files."""

import os
import re
from typing import Any

ENV_VAR_PATTERN = re.compile(r"\$\{([A-Z0-9_]+)\}")


def substitute_env_vars(data: dict[str, Any]) -> dict[str, Any]:
    """Recursively substitute environment variables in configuration.

    Replaces ${VAR_NAME} patterns with environment variable values.

    Args:
        data: Configuration dictionary

    Returns:
        Dictionary with substituted values

    Raises:
        ValueError: If required environment variable is missing
    """
    if isinstance(data, dict):
        return {k: substitute_env_vars(v) for k, v in data.items()}
    elif isinstance(data, list):
        return [substitute_env_vars(item) for item in data]
    elif isinstance(data, str):
        return _substitute_string(data)
    else:
        return data


def _substitute_string(value: str) -> str:
    """Substitute environment variables in a string.

    Args:
        value: String potentially containing ${VAR} patterns

    Returns:
        String with substituted values

    Raises:
        ValueError: If required environment variable is missing
    """
    def replacer(match: re.Match[str]) -> str:
        var_name = match.group(1)
        env_value = os.getenv(var_name)
        if env_value is None:
            raise ValueError(
                f"Environment variable '{var_name}' is required but not set"
            )
        return env_value

    return ENV_VAR_PATTERN.sub(replacer, value)
```

**Step 4: Run tests (expect pass)**

```bash
pytest tests/unit/domain/test_env_sub.py -v
```

Expected: All 5 tests PASS

**Step 5: Commit**

```bash
git add src/descope_mgmt/domain/ tests/unit/domain/
git commit -m "feat: add environment variable substitution for config files"
```

---

## Task 2: Create YAML Config Loader

**Files:**
- Create: `src/descope_mgmt/domain/config_loader.py`
- Create: `tests/unit/domain/test_config_loader.py`
- Create: `tests/fixtures/test_config.yaml` (test data)

**Step 1: Write failing tests**

Create `tests/fixtures/__init__.py`:
```python
"""Test fixtures directory."""
```

Create `tests/fixtures/test_config.yaml`:
```yaml
project:
  project_id: "P2test123"
  management_key: "${TEST_MANAGEMENT_KEY}"
  environment: "test"

tenants:
  - id: "tenant-1"
    name: "Tenant One"
    domains:
      - "tenant1.com"

  - id: "tenant-2"
    name: "Tenant Two"
    domains:
      - "tenant2.com"
    flow_ids:
      - "flow-login"

flows:
  - id: "flow-login"
    name: "Login Flow"
    flow_type: "login"
```

Create `tests/unit/domain/test_config_loader.py`:
```python
"""Tests for configuration loader."""

from pathlib import Path

import pytest

from descope_mgmt.domain.config_loader import ConfigLoader


@pytest.fixture
def test_config_path() -> Path:
    """Path to test configuration file."""
    return Path(__file__).parent.parent.parent / "fixtures" / "test_config.yaml"


def test_config_loader_load_valid(
    test_config_path: Path,
    monkeypatch: pytest.MonkeyPatch
) -> None:
    """Test loading valid configuration."""
    monkeypatch.setenv("TEST_MANAGEMENT_KEY", "K2secret123")
    loader = ConfigLoader()
    config = loader.load(test_config_path)

    assert config.project.project_id == "P2test123"
    assert config.project.management_key == "K2secret123"
    assert len(config.tenants) == 2
    assert len(config.flows) == 1


def test_config_loader_missing_env_var(test_config_path: Path) -> None:
    """Test error on missing environment variable."""
    loader = ConfigLoader()
    with pytest.raises(ValueError) as exc_info:
        loader.load(test_config_path)
    assert "TEST_MANAGEMENT_KEY" in str(exc_info.value)


def test_config_loader_file_not_found() -> None:
    """Test error on missing config file."""
    loader = ConfigLoader()
    with pytest.raises(FileNotFoundError):
        loader.load(Path("/nonexistent/config.yaml"))


def test_config_loader_invalid_yaml(tmp_path: Path) -> None:
    """Test error on invalid YAML."""
    invalid_file = tmp_path / "invalid.yaml"
    invalid_file.write_text("{ invalid yaml")
    loader = ConfigLoader()
    with pytest.raises(ValueError) as exc_info:
        loader.load(invalid_file)
    assert "yaml" in str(exc_info.value).lower()
```

**Step 2: Run tests (expect failure)**

```bash
pytest tests/unit/domain/test_config_loader.py -v
```

Expected: All 4 tests FAIL

**Step 3: Implement ConfigLoader**

Create `src/descope_mgmt/domain/config_loader.py`:
```python
"""Configuration file loader with YAML parsing and env var substitution."""

from pathlib import Path
from typing import Any

import yaml
from pydantic import ValidationError

from descope_mgmt.domain.env_sub import substitute_env_vars
from descope_mgmt.types.config import DescopeConfig


class ConfigLoader:
    """Loads and validates Descope configuration from YAML files."""

    def load(self, config_path: Path) -> DescopeConfig:
        """Load configuration from YAML file.

        Args:
            config_path: Path to YAML configuration file

        Returns:
            Validated DescopeConfig instance

        Raises:
            FileNotFoundError: If config file doesn't exist
            ValueError: If YAML is invalid or env vars are missing
            ValidationError: If configuration fails Pydantic validation
        """
        if not config_path.exists():
            raise FileNotFoundError(f"Configuration file not found: {config_path}")

        # Load YAML
        try:
            with open(config_path) as f:
                raw_data: dict[str, Any] = yaml.safe_load(f)
        except yaml.YAMLError as e:
            raise ValueError(f"Invalid YAML in {config_path}: {e}")

        # Substitute environment variables
        try:
            substituted_data = substitute_env_vars(raw_data)
        except ValueError as e:
            raise ValueError(f"Environment variable substitution failed: {e}")

        # Validate with Pydantic
        try:
            return DescopeConfig(**substituted_data)
        except ValidationError as e:
            raise ValidationError(f"Configuration validation failed: {e}")
```

**Step 4: Run tests (expect pass)**

```bash
pytest tests/unit/domain/test_config_loader.py -v
```

Expected: All 4 tests PASS

**Step 5: Commit**

```bash
git add src/descope_mgmt/domain/ tests/unit/domain/ tests/fixtures/
git commit -m "feat: add YAML config loader with env var substitution"
```

---

## Chunk Complete Checklist

- [ ] Environment variable substitution with 5 tests
- [ ] YAML config loader with 4 tests
- [ ] Test fixtures created
- [ ] All 9 domain tests passing
- [ ] mypy strict mode passes
- [ ] 2 commits created
- [ ] Ready for chunk 8
