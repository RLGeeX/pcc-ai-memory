# Chunk 2: Type System & Protocols

**Status:** pending
**Dependencies:** chunk-001
**Estimated Time:** 45-60 minutes

---

## Task 1: Create Protocol Definitions

**Files:**
- Create: `src/descope_mgmt/types/protocols.py`

**Step 1: Write failing import test**

Create `tests/unit/test_protocols.py`:
```python
"""Tests for protocol definitions"""
import pytest
from descope_mgmt.types.protocols import DescopeClient, ConfigLoader


def test_protocols_importable():
    """Protocol types should be importable"""
    assert DescopeClient is not None
    assert ConfigLoader is not None
```

**Step 2: Run test to verify it fails**

Run: `pytest tests/unit/test_protocols.py -v`

Expected: FAIL with "ModuleNotFoundError: No module named 'descope_mgmt.types.protocols'"

**Step 3: Create protocol definitions**

Create `src/descope_mgmt/types/protocols.py`:
```python
"""Protocol definitions for dependency injection.

All protocols defined here to avoid import cycles.
Domain layer depends only on these protocols, not concrete implementations.
"""
from typing import Protocol, Any
from datetime import datetime


class TenantData(Protocol):
    """Protocol for tenant data from API"""
    id: str
    name: str
    self_provisioning: bool
    domains: list[str]
    custom_attributes: dict[str, Any]
    created_at: datetime
    updated_at: datetime


class FlowData(Protocol):
    """Protocol for flow data from API"""
    id: str
    name: str
    enabled: bool
    config: dict[str, Any]


class DescopeClient(Protocol):
    """Protocol for Descope API client operations"""

    def load_tenant(self, tenant_id: str) -> TenantData:
        """Load a tenant by ID"""
        ...

    def create_tenant(
        self,
        tenant_id: str,
        name: str,
        domains: list[str],
        self_provisioning: bool,
        custom_attributes: dict[str, Any]
    ) -> TenantData:
        """Create a new tenant"""
        ...

    def update_tenant(
        self,
        tenant_id: str,
        name: str | None = None,
        domains: list[str] | None = None,
        self_provisioning: bool | None = None,
        custom_attributes: dict[str, Any] | None = None
    ) -> TenantData:
        """Update an existing tenant"""
        ...

    def delete_tenant(self, tenant_id: str) -> None:
        """Delete a tenant"""
        ...

    def list_tenants(self) -> list[TenantData]:
        """List all tenants in the project"""
        ...


class ConfigLoader(Protocol):
    """Protocol for configuration loading"""

    def load_config(self, config_path: str) -> Any:
        """Load configuration from file"""
        ...

    def discover_config(self) -> str | None:
        """Discover config file using discovery chain"""
        ...


class BackupStorage(Protocol):
    """Protocol for backup storage operations"""

    def save_backup(self, backup_data: dict[str, Any], metadata: dict[str, Any]) -> str:
        """Save backup and return backup ID"""
        ...

    def load_backup(self, backup_id: str) -> dict[str, Any]:
        """Load backup by ID"""
        ...

    def list_backups(self) -> list[dict[str, Any]]:
        """List all available backups"""
        ...
```

**Step 4: Run test to verify it passes**

Run: `pytest tests/unit/test_protocols.py -v`

Expected: PASS

**Step 5: Commit**

```bash
git add src/descope_mgmt/types/protocols.py tests/unit/test_protocols.py
git commit -m "feat: add protocol definitions for dependency injection"
```

---

## Task 2: Create Base Exception Hierarchy

**Files:**
- Create: `src/descope_mgmt/types/exceptions.py`
- Create: `tests/unit/test_exceptions.py`

**Step 1: Write failing test**

Create `tests/unit/test_exceptions.py`:
```python
"""Tests for exception hierarchy"""
import pytest
from descope_mgmt.types.exceptions import (
    DescopeMgmtError,
    ConfigurationError,
    ApiError,
    RateLimitError,
    ValidationError as DescopeValidationError,
)


def test_exception_hierarchy():
    """Exception hierarchy should be properly structured"""
    assert issubclass(ConfigurationError, DescopeMgmtError)
    assert issubclass(ApiError, DescopeMgmtError)
    assert issubclass(RateLimitError, ApiError)
    assert issubclass(DescopeValidationError, DescopeMgmtError)


def test_base_exception_with_details():
    """Base exception should support details dict"""
    error = DescopeMgmtError("Test error", details={"key": "value"})
    assert error.message == "Test error"
    assert error.details == {"key": "value"}
    assert str(error) == "Test error"


def test_api_error_with_status_code():
    """API error should include status code and response"""
    error = ApiError("API failed", status_code=500, response={"error": "Internal"})
    assert error.status_code == 500
    assert error.response == {"error": "Internal"}
    assert error.details["status_code"] == 500


def test_rate_limit_error():
    """Rate limit error should extend API error"""
    error = RateLimitError("Too many requests", status_code=429, response={})
    assert error.status_code == 429
    assert isinstance(error, ApiError)
```

**Step 2: Run test to verify it fails**

Run: `pytest tests/unit/test_exceptions.py -v`

Expected: FAIL with import errors

**Step 3: Implement exception hierarchy**

Create `src/descope_mgmt/types/exceptions.py`:
```python
"""Exception hierarchy for descope-mgmt.

All custom exceptions inherit from DescopeMgmtError.
"""
from typing import Any


class DescopeMgmtError(Exception):
    """Base exception for all descope-mgmt errors"""

    def __init__(self, message: str, details: dict[str, Any] | None = None):
        super().__init__(message)
        self.message = message
        self.details = details or {}

    def __str__(self) -> str:
        return self.message


class ConfigurationError(DescopeMgmtError):
    """Error in configuration file or validation"""
    pass


class ValidationError(DescopeMgmtError):
    """Error in data validation"""
    pass


class ApiError(DescopeMgmtError):
    """Error from Descope API"""

    def __init__(
        self,
        message: str,
        status_code: int,
        response: dict[str, Any]
    ):
        super().__init__(
            message,
            details={"status_code": status_code, "response": response}
        )
        self.status_code = status_code
        self.response = response


class RateLimitError(ApiError):
    """Rate limit exceeded (429 response)"""
    pass


class ResourceNotFoundError(ApiError):
    """Resource not found (404 response)"""
    pass


class AuthenticationError(ApiError):
    """Authentication failed (401/403 response)"""
    pass
```

**Step 4: Run test to verify it passes**

Run: `pytest tests/unit/test_exceptions.py -v`

Expected: PASS (all 4 tests)

**Step 5: Commit**

```bash
git add src/descope_mgmt/types/exceptions.py tests/unit/test_exceptions.py
git commit -m "feat: add exception hierarchy with API error types"
```

---

## Task 3: Create Shared Type Aliases

**Files:**
- Create: `src/descope_mgmt/types/common.py`
- Create: `tests/unit/test_common_types.py`

**Step 1: Write test for type aliases**

Create `tests/unit/test_common_types.py`:
```python
"""Tests for common type aliases"""
from descope_mgmt.types.common import TenantId, ProjectId, BackupId, Timestamp


def test_type_aliases_importable():
    """Type aliases should be importable"""
    assert TenantId is not None
    assert ProjectId is not None
    assert BackupId is not None
    assert Timestamp is not None
```

**Step 2: Run test to verify it fails**

Run: `pytest tests/unit/test_common_types.py -v`

Expected: FAIL with import errors

**Step 3: Create type aliases**

Create `src/descope_mgmt/types/common.py`:
```python
"""Common type aliases for type safety.

Using NewType for distinct types that shouldn't be confused.
"""
from typing import NewType
from datetime import datetime
from pathlib import Path

# Distinct string types for domain concepts
TenantId = NewType('TenantId', str)
ProjectId = NewType('ProjectId', str)
FlowId = NewType('FlowId', str)
BackupId = NewType('BackupId', Path)

# Timestamp type
Timestamp = datetime

# Environment names (literal type for validation)
from typing import Literal

Environment = Literal["test", "devtest", "dev", "staging", "prod"]
```

**Step 4: Run test to verify it passes**

Run: `pytest tests/unit/test_common_types.py -v`

Expected: PASS

**Step 5: Commit**

```bash
git add src/descope_mgmt/types/common.py tests/unit/test_common_types.py
git commit -m "feat: add type aliases for domain concepts"
```

---

## Task 4: Update types/__init__.py

**Files:**
- Modify: `src/descope_mgmt/types/__init__.py`

**Step 1: Export all types from types module**

Update `src/descope_mgmt/types/__init__.py`:
```python
"""Type definitions and protocols for descope-mgmt.

This module exports all protocols, exceptions, and type aliases.
Import from this module to avoid import cycles.
"""
from descope_mgmt.types.protocols import (
    TenantData,
    FlowData,
    DescopeClient,
    ConfigLoader,
    BackupStorage,
)
from descope_mgmt.types.exceptions import (
    DescopeMgmtError,
    ConfigurationError,
    ValidationError,
    ApiError,
    RateLimitError,
    ResourceNotFoundError,
    AuthenticationError,
)
from descope_mgmt.types.common import (
    TenantId,
    ProjectId,
    FlowId,
    BackupId,
    Timestamp,
    Environment,
)

__all__ = [
    # Protocols
    "TenantData",
    "FlowData",
    "DescopeClient",
    "ConfigLoader",
    "BackupStorage",
    # Exceptions
    "DescopeMgmtError",
    "ConfigurationError",
    "ValidationError",
    "ApiError",
    "RateLimitError",
    "ResourceNotFoundError",
    "AuthenticationError",
    # Type aliases
    "TenantId",
    "ProjectId",
    "FlowId",
    "BackupId",
    "Timestamp",
    "Environment",
]
```

**Step 2: Test imports**

Create `tests/unit/test_types_module.py`:
```python
"""Test that all types are importable from types module"""
from descope_mgmt import types


def test_all_exports_available():
    """All __all__ exports should be available"""
    for name in types.__all__:
        assert hasattr(types, name), f"{name} not exported from types module"
```

**Step 3: Run test**

Run: `pytest tests/unit/test_types_module.py -v`

Expected: PASS

**Step 4: Commit**

```bash
git add src/descope_mgmt/types/__init__.py tests/unit/test_types_module.py
git commit -m "feat: export all types from types module"
```

---

## Task 5: Configure mypy for Strict Type Checking

**Files:**
- Verify: `pyproject.toml` has mypy config

**Step 1: Verify mypy configuration**

Run: `grep -A 10 '\[tool.mypy\]' pyproject.toml`

Expected: Strict mode enabled

**Step 2: Run mypy on types module**

Run: `mypy src/descope_mgmt/types/`

Expected: SUCCESS (no type errors)

**Step 3: Add mypy test to verify**

Create `tests/unit/test_mypy.py`:
```python
"""Verify mypy type checking passes"""
import subprocess
import sys


def test_mypy_types_module():
    """Type checking should pass for types module"""
    result = subprocess.run(
        [sys.executable, "-m", "mypy", "src/descope_mgmt/types/"],
        capture_output=True,
        text=True
    )
    assert result.returncode == 0, f"mypy failed:\n{result.stdout}\n{result.stderr}"
```

**Step 4: Run test**

Run: `pytest tests/unit/test_mypy.py -v`

Expected: PASS

**Step 5: Commit**

```bash
git add tests/unit/test_mypy.py
git commit -m "test: add mypy verification test for types module"
```

---

## Chunk Complete Checklist

- [ ] Protocol definitions created (DescopeClient, ConfigLoader, BackupStorage)
- [ ] Exception hierarchy implemented with tests
- [ ] Type aliases defined (TenantId, ProjectId, etc.)
- [ ] types module exports all types
- [ ] mypy strict checking passes
- [ ] All tests passing (8+ tests)
- [ ] All commits made
