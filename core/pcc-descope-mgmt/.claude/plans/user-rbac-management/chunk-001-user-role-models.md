# Chunk 1: User and Role Data Models

**Status:** pending
**Dependencies:** none
**Complexity:** simple
**Estimated Time:** 10 minutes
**Tasks:** 2
**Phase:** Data Models & Exceptions

---

## Task 1: Create UserConfig Model

**Agent:** python-pro
**Files:**
- Create: `src/descope_mgmt/types/user.py`
- Test: `tests/unit/types/test_user.py`

**Step 1: Write the test file**

```python
# tests/unit/types/test_user.py
"""Tests for UserConfig model."""

import pytest
from descope_mgmt.types.user import UserConfig, UserStatus


def test_user_config_minimal() -> None:
    """Test creating user with minimal fields."""
    user = UserConfig(user_id="U123", email="test@example.com")
    assert user.user_id == "U123"
    assert user.email == "test@example.com"
    assert user.status == UserStatus.ENABLED
    assert user.roles == []


def test_user_config_from_api_response() -> None:
    """Test creating user from API response with camelCase fields."""
    data = {
        "userId": "U456",
        "loginIds": ["test@example.com"],
        "email": "test@example.com",
        "displayName": "Test User",
        "roleNames": ["admin", "viewer"],
        "verifiedEmail": True,
        "createdTime": 1700000000,
    }
    user = UserConfig(**data)
    assert user.user_id == "U456"
    assert user.display_name == "Test User"
    assert user.roles == ["admin", "viewer"]
    assert user.verified_email is True


def test_user_status_enum() -> None:
    """Test UserStatus enum values."""
    assert UserStatus.ENABLED.value == "enabled"
    assert UserStatus.DISABLED.value == "disabled"
    assert UserStatus.INVITED.value == "invited"
```

**Step 2: Run test to verify it fails**

Run: `pytest tests/unit/types/test_user.py -v`
Expected: FAIL with "ModuleNotFoundError: No module named 'descope_mgmt.types.user'"

**Step 3: Write the implementation**

```python
# src/descope_mgmt/types/user.py
"""User configuration model."""

from enum import Enum
from typing import Any

from pydantic import BaseModel, Field


class UserStatus(str, Enum):
    """User account status."""

    ENABLED = "enabled"
    DISABLED = "disabled"
    INVITED = "invited"


class UserConfig(BaseModel):
    """Configuration for a Descope user.

    Attributes:
        user_id: Unique user identifier (assigned by Descope).
        login_ids: List of login identifiers (email, phone, etc.).
        email: User's email address.
        phone: User's phone number.
        name: User's full name.
        display_name: Display name shown in UI.
        picture: URL to user's profile picture.
        status: Account status (enabled, disabled, invited).
        verified_email: Whether email is verified.
        verified_phone: Whether phone is verified.
        roles: List of role names assigned to user.
        tenants: List of tenant IDs user belongs to.
        created_time: Unix timestamp of user creation.
        custom_attributes: Custom user attributes.
    """

    user_id: str = Field(alias="userId")
    login_ids: list[str] = Field(default_factory=list, alias="loginIds")
    email: str | None = None
    phone: str | None = None
    name: str | None = None
    display_name: str | None = Field(None, alias="displayName")
    picture: str | None = None
    status: UserStatus = UserStatus.ENABLED
    verified_email: bool = Field(False, alias="verifiedEmail")
    verified_phone: bool = Field(False, alias="verifiedPhone")
    roles: list[str] = Field(default_factory=list, alias="roleNames")
    tenants: list[str] = Field(default_factory=list, alias="tenantIds")
    created_time: int | None = Field(None, alias="createdTime")
    custom_attributes: dict[str, Any] = Field(
        default_factory=dict, alias="customAttributes"
    )

    model_config = {"populate_by_name": True}
```

**Step 4: Run test to verify it passes**

Run: `pytest tests/unit/types/test_user.py -v`
Expected: PASS (3 tests)

---

## Task 2: Create RoleConfig Model

**Agent:** python-pro
**Files:**
- Create: `src/descope_mgmt/types/role.py`
- Test: `tests/unit/types/test_role.py`

**Step 1: Write the test file**

```python
# tests/unit/types/test_role.py
"""Tests for RoleConfig model."""

import pytest
from descope_mgmt.types.role import RoleConfig


def test_role_config_minimal() -> None:
    """Test creating role with minimal fields."""
    role = RoleConfig(name="admin")
    assert role.name == "admin"
    assert role.description is None
    assert role.permissions == []


def test_role_config_full() -> None:
    """Test creating role with all fields."""
    role = RoleConfig(
        name="editor",
        description="Can edit content",
        permissions=["content:read", "content:write"],
    )
    assert role.name == "editor"
    assert role.description == "Can edit content"
    assert role.permissions == ["content:read", "content:write"]


def test_role_config_from_api_response() -> None:
    """Test creating role from API response with camelCase fields."""
    data = {
        "name": "viewer",
        "description": "Read-only access",
        "permissionNames": ["content:read"],
        "createdTime": 1700000000,
    }
    role = RoleConfig(**data)
    assert role.name == "viewer"
    assert role.permissions == ["content:read"]
    assert role.created_time == 1700000000
```

**Step 2: Run test to verify it fails**

Run: `pytest tests/unit/types/test_role.py -v`
Expected: FAIL with "ModuleNotFoundError: No module named 'descope_mgmt.types.role'"

**Step 3: Write the implementation**

```python
# src/descope_mgmt/types/role.py
"""Role configuration model."""

from pydantic import BaseModel, Field


class RoleConfig(BaseModel):
    """Configuration for a Descope role.

    Attributes:
        name: Unique role name (identifier).
        description: Human-readable role description.
        permissions: List of permission names assigned to this role.
        tenant_id: Tenant ID if tenant-level role, None for project-level.
        created_time: Unix timestamp of role creation.
    """

    name: str
    description: str | None = None
    permissions: list[str] = Field(default_factory=list, alias="permissionNames")
    tenant_id: str | None = Field(None, alias="tenantId")
    created_time: int | None = Field(None, alias="createdTime")

    model_config = {"populate_by_name": True}
```

**Step 4: Run test to verify it passes**

Run: `pytest tests/unit/types/test_role.py -v`
Expected: PASS (3 tests)

**Step 5: Commit**

```bash
git add src/descope_mgmt/types/user.py src/descope_mgmt/types/role.py \
        tests/unit/types/test_user.py tests/unit/types/test_role.py
git commit -m "feat(types): add UserConfig and RoleConfig models"
```

---

## Chunk Complete Checklist

- [ ] All tasks completed
- [ ] All tests passing
- [ ] Code committed
- [ ] Ready for next chunk
