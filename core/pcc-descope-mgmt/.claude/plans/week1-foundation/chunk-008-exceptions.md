# Chunk 8: Custom Exceptions Hierarchy

**Status:** pending
**Dependencies:** none (can run in parallel with chunks 6-7)
**Complexity:** simple
**Estimated Time:** 10 minutes
**Tasks:** 2

---

## Task 1: Create Exception Classes

**Files:**
- Create: `src/descope_mgmt/types/exceptions.py`
- Create: `tests/unit/types/test_exceptions.py`

**Step 1: Write failing tests**

Create `tests/unit/types/test_exceptions.py`:
```python
"""Tests for custom exceptions."""

import pytest

from descope_mgmt.types.exceptions import (
    DescopeMgmtError,
    ApiError,
    ConfigurationError,
    RateLimitError,
    ValidationError as DescopeValidationError,
)


def test_base_exception() -> None:
    """Test base exception."""
    with pytest.raises(DescopeMgmtError) as exc_info:
        raise DescopeMgmtError("Base error")
    assert str(exc_info.value) == "Base error"


def test_api_error() -> None:
    """Test API error with status code."""
    error = ApiError("API failed", status_code=429)
    assert error.status_code == 429
    assert "API failed" in str(error)


def test_configuration_error() -> None:
    """Test configuration error."""
    with pytest.raises(ConfigurationError) as exc_info:
        raise ConfigurationError("Config invalid")
    assert "Config invalid" in str(exc_info.value)


def test_rate_limit_error() -> None:
    """Test rate limit error."""
    with pytest.raises(RateLimitError) as exc_info:
        raise RateLimitError("Rate limited")
    assert "Rate limited" in str(exc_info.value)


def test_validation_error() -> None:
    """Test validation error."""
    with pytest.raises(DescopeValidationError) as exc_info:
        raise DescopeValidationError("Validation failed")
    assert "Validation failed" in str(exc_info.value)


def test_exception_hierarchy() -> None:
    """Test exception inheritance."""
    assert issubclass(ApiError, DescopeMgmtError)
    assert issubclass(ConfigurationError, DescopeMgmtError)
    assert issubclass(RateLimitError, DescopeMgmtError)
    assert issubclass(DescopeValidationError, DescopeMgmtError)
```

**Step 2: Run tests (expect failure)**

```bash
pytest tests/unit/types/test_exceptions.py -v
```

Expected: All 6 tests FAIL

**Step 3: Implement exceptions**

Create `src/descope_mgmt/types/exceptions.py`:
```python
"""Custom exception hierarchy for descope-mgmt."""


class DescopeMgmtError(Exception):
    """Base exception for all descope-mgmt errors."""


class ApiError(DescopeMgmtError):
    """Error from Descope API calls.

    Attributes:
        status_code: HTTP status code (if applicable)
    """

    def __init__(self, message: str, status_code: int | None = None) -> None:
        """Initialize API error.

        Args:
            message: Error message
            status_code: HTTP status code
        """
        super().__init__(message)
        self.status_code = status_code


class ConfigurationError(DescopeMgmtError):
    """Error in configuration file or settings."""


class RateLimitError(DescopeMgmtError):
    """Error when rate limit is exceeded."""


class ValidationError(DescopeMgmtError):
    """Error during input validation."""
```

**Step 4: Run tests (expect pass)**

```bash
pytest tests/unit/types/test_exceptions.py -v
```

Expected: All 6 tests PASS

**Step 5: Commit**

```bash
git add src/descope_mgmt/types/exceptions.py tests/unit/types/test_exceptions.py
git commit -m "feat: add custom exception hierarchy"
```

---

## Task 2: Update types exports

**Files:**
- Modify: `src/descope_mgmt/types/__init__.py`

**Step 1: Export exceptions**

```python
"""Type system for descope-mgmt."""

from descope_mgmt.types.config import DescopeConfig
from descope_mgmt.types.exceptions import (
    ApiError,
    ConfigurationError,
    DescopeMgmtError,
    RateLimitError,
    ValidationError,
)
from descope_mgmt.types.flow import FlowConfig
from descope_mgmt.types.project import ProjectSettings
from descope_mgmt.types.protocols import DescopeClientProtocol, RateLimiterProtocol
from descope_mgmt.types.shared import ResourceIdentifier
from descope_mgmt.types.tenant import TenantConfig

__all__ = [
    # Base types
    "ResourceIdentifier",
    # Protocols
    "DescopeClientProtocol",
    "RateLimiterProtocol",
    # Config models
    "TenantConfig",
    "FlowConfig",
    "ProjectSettings",
    "DescopeConfig",
    # Exceptions
    "DescopeMgmtError",
    "ApiError",
    "ConfigurationError",
    "RateLimitError",
    "ValidationError",
]
```

**Step 2: Run all tests**

```bash
pytest tests/unit/types/ -v
```

Expected: All 31 tests PASS (25 + 6)

**Step 3: Commit**

```bash
git add src/descope_mgmt/types/__init__.py
git commit -m "feat: export custom exceptions from types module"
```

---

## Chunk Complete Checklist

- [ ] Custom exception hierarchy with 6 tests
- [ ] All exceptions inherit from DescopeMgmtError
- [ ] types module exports exceptions
- [ ] All 31 type tests passing
- [ ] mypy strict mode passes
- [ ] 2 commits created
- [ ] Ready for chunk 9
