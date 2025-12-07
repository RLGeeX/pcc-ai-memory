# Chunk 2: Audit Operations and Exceptions

**Status:** pending
**Dependencies:** none
**Complexity:** simple
**Estimated Time:** 5 minutes
**Tasks:** 2
**Phase:** Data Models & Exceptions

---

## Task 1: Add User/Role Audit Operations

**Agent:** python-pro
**Files:**
- Modify: `src/descope_mgmt/types/audit.py:9-27`

**Step 1: Add new enum values to AuditOperation**

Add these values to the `AuditOperation` enum after the existing Flow operations:

```python
    # User operations
    USER_CREATE = "user_create"
    USER_INVITE = "user_invite"
    USER_UPDATE = "user_update"
    USER_DELETE = "user_delete"
    USER_LIST = "user_list"
    USER_ADD_ROLE = "user_add_role"
    USER_REMOVE_ROLE = "user_remove_role"

    # Role operations
    ROLE_CREATE = "role_create"
    ROLE_UPDATE = "role_update"
    ROLE_DELETE = "role_delete"
    ROLE_LIST = "role_list"
```

**Step 2: Run existing tests to verify no regression**

Run: `pytest tests/unit/types/ -v`
Expected: All existing tests pass

---

## Task 2: Add User/Role Exception Classes

**Agent:** python-pro
**Files:**
- Modify: `src/descope_mgmt/types/exceptions.py`
- Test: `tests/unit/types/test_exceptions.py`

**Step 1: Write test for new exceptions**

```python
# tests/unit/types/test_exceptions.py
"""Tests for custom exceptions."""

import pytest
from descope_mgmt.types.exceptions import (
    ApiError,
    UserNotFoundError,
    RoleNotFoundError,
    RoleInUseError,
    InvalidEmailError,
)


def test_user_not_found_error() -> None:
    """Test UserNotFoundError."""
    error = UserNotFoundError("User U123 not found")
    assert str(error) == "User U123 not found"
    assert isinstance(error, Exception)


def test_role_not_found_error() -> None:
    """Test RoleNotFoundError."""
    error = RoleNotFoundError("Role 'admin' not found")
    assert str(error) == "Role 'admin' not found"


def test_role_in_use_error() -> None:
    """Test RoleInUseError."""
    error = RoleInUseError("Role 'admin' is assigned to 5 users")
    assert str(error) == "Role 'admin' is assigned to 5 users"


def test_invalid_email_error() -> None:
    """Test InvalidEmailError."""
    error = InvalidEmailError("Invalid email format: bad-email")
    assert str(error) == "Invalid email format: bad-email"


def test_api_error_with_status() -> None:
    """Test ApiError with status code."""
    error = ApiError("Not found", status_code=404)
    assert error.status_code == 404
```

**Step 2: Run test to verify it fails**

Run: `pytest tests/unit/types/test_exceptions.py -v`
Expected: FAIL with ImportError for new exception classes

**Step 3: Add exception classes**

Append to `src/descope_mgmt/types/exceptions.py`:

```python
class UserNotFoundError(DescopeMgmtError):
    """Exception raised when user does not exist."""

    pass


class RoleNotFoundError(DescopeMgmtError):
    """Exception raised when role does not exist."""

    pass


class RoleInUseError(DescopeMgmtError):
    """Exception raised when attempting to delete a role that is assigned to users."""

    pass


class InvalidEmailError(DescopeMgmtError):
    """Exception raised for invalid email format."""

    pass
```

**Step 4: Run test to verify it passes**

Run: `pytest tests/unit/types/test_exceptions.py -v`
Expected: PASS (5 tests)

**Step 5: Commit**

```bash
git add src/descope_mgmt/types/audit.py src/descope_mgmt/types/exceptions.py \
        tests/unit/types/test_exceptions.py
git commit -m "feat(types): add user/role audit operations and exceptions"
```

---

## Chunk Complete Checklist

- [ ] All tasks completed
- [ ] All tests passing
- [ ] Code committed
- [ ] Ready for next chunk
