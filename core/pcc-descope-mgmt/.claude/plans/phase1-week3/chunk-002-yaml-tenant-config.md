# Chunk 2: YAML Tenant Configuration

**Status:** complete
**Dependencies:** chunk-001-client-factory
**Complexity:** medium
**Estimated Time:** 45 minutes
**Tasks:** 3

---

## Context

This chunk enables configuration-as-code for tenants. Instead of creating tenants one-by-one via CLI options, users can define all tenants in a YAML file and load them declaratively.

**YAML Schema Example:**
```yaml
tenants:
  - id: acme-corp
    name: ACME Corporation
    domains:
      - acme.com
      - acmecorp.com

  - id: widget-co
    name: Widget Company
    domains:
      - widget.co
```

---

## Task 1: Define Tenant YAML Schema and Models

**Agent:** python-pro

**Files:**
- Modify: `src/descope_mgmt/types/config.py:50-80` (add TenantListConfig)
- Create: `tests/fixtures/test_tenants.yaml`
- Modify: `tests/unit/types/test_config.py` (add tenant list tests)

**Step 1: Write failing tests**

Add to `tests/unit/types/test_config.py`:

```python
def test_tenant_list_config_from_dict() -> None:
    """Test TenantListConfig creation from dict."""
    data = {
        "tenants": [
            {"id": "acme", "name": "ACME Corp", "domains": ["acme.com"]},
            {"id": "widget", "name": "Widget Co", "domains": ["widget.co"]},
        ]
    }

    config = TenantListConfig.model_validate(data)

    assert len(config.tenants) == 2
    assert config.tenants[0].id == "acme"
    assert config.tenants[1].id == "widget"


def test_tenant_list_config_validates_unique_ids() -> None:
    """Test validation rejects duplicate tenant IDs."""
    data = {
        "tenants": [
            {"id": "acme", "name": "ACME Corp"},
            {"id": "acme", "name": "ACME Duplicate"},  # Duplicate ID
        ]
    }

    with pytest.raises(ValueError, match="Duplicate tenant ID"):
        TenantListConfig.model_validate(data)


def test_tenant_list_config_validates_unique_domains() -> None:
    """Test validation rejects duplicate domains."""
    data = {
        "tenants": [
            {"id": "acme", "name": "ACME Corp", "domains": ["acme.com"]},
            {"id": "widget", "name": "Widget Co", "domains": ["acme.com"]},  # Duplicate domain
        ]
    }

    with pytest.raises(ValueError, match="Duplicate domain"):
        TenantListConfig.model_validate(data)
```

**Step 2: Run tests to verify failure**

Run: `pytest tests/unit/types/test_config.py::test_tenant_list_config_from_dict -v`
Expected: FAIL with "NameError: name 'TenantListConfig' is not defined"

**Step 3: Implement TenantListConfig**

Update `src/descope_mgmt/types/config.py`:

```python
from typing import TYPE_CHECKING

from pydantic import BaseModel, Field, field_validator

if TYPE_CHECKING:
    from descope_mgmt.types.tenant import TenantConfig


class TenantListConfig(BaseModel):
    """Configuration for a list of tenants loaded from YAML.

    Validates:
    - Unique tenant IDs across all tenants
    - Unique domains across all tenants
    """

    tenants: list["TenantConfig"] = Field(default_factory=list)

    @field_validator("tenants")
    @classmethod
    def validate_unique_ids(cls, tenants: list["TenantConfig"]) -> list["TenantConfig"]:
        """Validate tenant IDs are unique."""
        ids = [t.id for t in tenants]
        duplicates = [tid for tid in ids if ids.count(tid) > 1]
        if duplicates:
            raise ValueError(f"Duplicate tenant IDs found: {set(duplicates)}")
        return tenants

    @field_validator("tenants")
    @classmethod
    def validate_unique_domains(cls, tenants: list["TenantConfig"]) -> list["TenantConfig"]:
        """Validate domains are unique across all tenants."""
        all_domains: list[tuple[str, str]] = []  # (domain, tenant_id)
        for tenant in tenants:
            for domain in tenant.domains:
                all_domains.append((domain, tenant.id))

        # Find duplicates
        domain_names = [d[0] for d in all_domains]
        duplicates = [(d, tid) for d, tid in all_domains if domain_names.count(d) > 1]

        if duplicates:
            dup_msg = ", ".join(f"{d} (tenant: {tid})" for d, tid in set(duplicates))
            raise ValueError(f"Duplicate domains found: {dup_msg}")

        return tenants
```

Also update imports in the file:
```python
# Add to imports
from descope_mgmt.types.tenant import TenantConfig  # Real import at runtime
```

**Step 4: Run tests to verify pass**

Run: `pytest tests/unit/types/test_config.py::test_tenant_list -v`
Expected: 3 tests PASS

**Step 5: Commit**

```bash
git add src/descope_mgmt/types/config.py tests/unit/types/test_config.py
git commit -m "feat: add tenant list configuration model

- Create TenantListConfig for loading tenants from YAML
- Validate unique tenant IDs across all tenants
- Validate unique domains across all tenants
- Add comprehensive validation tests"
```

---

## Task 2: Extend ConfigLoader for Tenant YAML Files

**Agent:** python-pro

**Files:**
- Modify: `src/descope_mgmt/domain/config_loader.py:60-100` (add load_tenants_from_yaml)
- Create: `tests/fixtures/test_tenants.yaml`
- Modify: `tests/unit/domain/test_config_loader.py` (add tenant loading tests)

**Step 1: Create test fixture**

Create `tests/fixtures/test_tenants.yaml`:

```yaml
tenants:
  - id: test-tenant-1
    name: Test Tenant 1
    domains:
      - tenant1.test.com
      - t1.example.com

  - id: test-tenant-2
    name: Test Tenant 2
    domains:
      - tenant2.test.com
```

**Step 2: Write failing tests**

Add to `tests/unit/domain/test_config_loader.py`:

```python
def test_load_tenants_from_yaml(tmp_path: Path) -> None:
    """Test loading tenant configuration from YAML file."""
    yaml_content = """
tenants:
  - id: acme
    name: ACME Corp
    domains:
      - acme.com
  - id: widget
    name: Widget Co
"""
    yaml_file = tmp_path / "tenants.yaml"
    yaml_file.write_text(yaml_content)

    loader = ConfigLoader()
    config = loader.load_tenants_from_yaml(yaml_file)

    assert len(config.tenants) == 2
    assert config.tenants[0].id == "acme"
    assert config.tenants[1].id == "widget"


def test_load_tenants_from_yaml_with_env_vars(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    """Test tenant loading with environment variable substitution."""
    monkeypatch.setenv("TENANT_DOMAIN", "example.com")

    yaml_content = """
tenants:
  - id: test
    name: Test Tenant
    domains:
      - ${TENANT_DOMAIN}
"""
    yaml_file = tmp_path / "tenants.yaml"
    yaml_file.write_text(yaml_content)

    loader = ConfigLoader()
    config = loader.load_tenants_from_yaml(yaml_file)

    assert config.tenants[0].domains == ["example.com"]


def test_load_tenants_from_yaml_invalid_file_raises_error(tmp_path: Path) -> None:
    """Test loading from non-existent file raises error."""
    loader = ConfigLoader()

    with pytest.raises(FileNotFoundError):
        loader.load_tenants_from_yaml(tmp_path / "missing.yaml")
```

**Step 3: Implement load_tenants_from_yaml**

Update `src/descope_mgmt/domain/config_loader.py`:

```python
from pathlib import Path
from typing import Any

import yaml
from pydantic import ValidationError

from descope_mgmt.domain.env_sub import substitute_env_vars
from descope_mgmt.types.config import DescopeConfig, TenantListConfig
from descope_mgmt.types.exceptions import ConfigError


class ConfigLoader:
    """Loads configuration from YAML files with environment variable substitution."""

    def load_from_yaml(self, file_path: Path) -> DescopeConfig:
        """Load Descope configuration from YAML file.

        (existing implementation unchanged)
        """
        # ... existing code ...

    def load_tenants_from_yaml(self, file_path: Path) -> TenantListConfig:
        """Load tenant list configuration from YAML file.

        Args:
            file_path: Path to tenants YAML file

        Returns:
            Parsed and validated tenant list configuration

        Raises:
            FileNotFoundError: If file doesn't exist
            ConfigError: If YAML is invalid or validation fails
        """
        if not file_path.exists():
            raise FileNotFoundError(f"Configuration file not found: {file_path}")

        try:
            # Read and parse YAML
            yaml_content = file_path.read_text()
            data: dict[str, Any] = yaml.safe_load(yaml_content)

            # Substitute environment variables
            data_with_env = substitute_env_vars(data)

            # Validate with Pydantic
            return TenantListConfig.model_validate(data_with_env)

        except yaml.YAMLError as e:
            raise ConfigError(f"Invalid YAML in {file_path}: {e}")
        except ValidationError as e:
            raise ConfigError(f"Configuration validation failed: {e}")
```

**Step 4: Run tests to verify pass**

Run: `pytest tests/unit/domain/test_config_loader.py::test_load_tenants -v`
Expected: 3 tests PASS

**Step 5: Commit**

```bash
git add src/descope_mgmt/domain/config_loader.py tests/unit/domain/test_config_loader.py tests/fixtures/test_tenants.yaml
git commit -m "feat: add tenant YAML loading to config loader

- Implement load_tenants_from_yaml method
- Support environment variable substitution in tenant configs
- Add test fixture for tenant YAML files
- Add comprehensive tests for tenant loading"
```

---

## Task 3: Create Example Tenant Configuration File

**Agent:** python-pro

**Files:**
- Create: `config/tenants.yaml.example`
- Modify: `.gitignore` (add config/tenants.yaml to ignored files)

**Step 1: Create example configuration**

Create `config/tenants.yaml.example`:

```yaml
# Example tenant configuration file for pcc-descope-mgmt
#
# Usage:
#   1. Copy this file to config/tenants.yaml
#   2. Update tenant definitions for your environment
#   3. Run: descope-mgmt tenant sync --config config/tenants.yaml --dry-run
#
# Environment variable substitution is supported using ${VAR_NAME} syntax

tenants:
  # Example tenant 1: ACME Corporation
  - id: acme-corp
    name: ACME Corporation
    domains:
      - acme.com
      - acmecorp.com
      - ${ACME_CUSTOM_DOMAIN}  # Optional: environment variable
    # domains can be empty list if tenant has no custom domains
    # domains: []

  # Example tenant 2: Widget Company
  - id: widget-co
    name: Widget Company
    domains:
      - widget.co

  # Example tenant 3: Minimal configuration
  - id: startup-inc
    name: Startup Inc
    # No domains specified (empty by default)

# Notes:
# - Tenant IDs must be unique across all tenants
# - Domains must be unique across all tenants
# - Tenant IDs should be lowercase with hyphens (kebab-case)
# - Empty domains list is valid (no custom domains for that tenant)
```

**Step 2: Update .gitignore**

Add to `.gitignore`:

```
# Tenant configuration (contains sensitive domain mappings)
config/tenants.yaml
```

**Step 3: Verify file created**

Run: `ls -la config/tenants.yaml.example`
Expected: File exists

**Step 4: Commit**

```bash
git add config/tenants.yaml.example .gitignore
git commit -m "docs: add example tenant configuration file

- Create tenants.yaml.example with documentation
- Add comments explaining usage and environment variables
- Update .gitignore to exclude actual tenants.yaml file
- Provides template for users to customize"
```

---

## Chunk Complete Checklist

- [ ] TenantListConfig model created with validation (Task 1)
- [ ] ConfigLoader.load_tenants_from_yaml implemented (Task 2)
- [ ] Example tenants.yaml.example created (Task 3)
- [ ] All tests passing (117+ total, +8 from chunk)
- [ ] Coverage ≥90%
- [ ] mypy, ruff, lint-imports passing
- [ ] 3 commits pushed

---

## Verification Commands

```bash
# Run tests
pytest tests/unit/types/test_config.py::test_tenant_list -v
pytest tests/unit/domain/test_config_loader.py::test_load_tenants -v

# Quality checks
mypy src/
ruff check .
lint-imports

# Manual verification - example file valid YAML
python3 -c "import yaml; yaml.safe_load(open('config/tenants.yaml.example'))"
```

**Expected:** All tests pass, YAML file is valid.
