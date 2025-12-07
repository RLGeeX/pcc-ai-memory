# Chunk 6: UserManager Domain Service

**Status:** pending
**Dependencies:** chunk-003-user-api-crud, chunk-005-user-role-api
**Complexity:** medium
**Estimated Time:** 15 minutes
**Tasks:** 3
**Phase:** Domain Layer

---

## Task 1: Create UserManager with CRUD Operations

**Agent:** python-pro
**Files:**
- Create: `src/descope_mgmt/domain/user_manager.py`
- Test: `tests/unit/domain/test_user_manager.py`

**Step 1: Write tests for UserManager CRUD**

```python
# tests/unit/domain/test_user_manager.py
"""Tests for UserManager service."""

from unittest.mock import MagicMock, create_autospec

import pytest

from descope_mgmt.domain.audit_logger import AuditLogger
from descope_mgmt.domain.user_manager import UserManager
from descope_mgmt.types.protocols import DescopeClientProtocol
from descope_mgmt.types.user import UserConfig, UserStatus


@pytest.fixture
def mock_client() -> MagicMock:
    """Create mock Descope client."""
    return create_autospec(DescopeClientProtocol)


@pytest.fixture
def mock_audit() -> MagicMock:
    """Create mock audit logger."""
    return create_autospec(AuditLogger)


@pytest.fixture
def manager(mock_client: MagicMock, mock_audit: MagicMock) -> UserManager:
    """Create UserManager with mocks."""
    return UserManager(mock_client, mock_audit)


def test_list_users_delegates_to_client(
    manager: UserManager, mock_client: MagicMock
) -> None:
    """Test list_users calls client method."""
    mock_client.list_users.return_value = []

    result = manager.list_users()

    mock_client.list_users.assert_called_once()
    assert result == []


def test_get_user_returns_user(
    manager: UserManager, mock_client: MagicMock
) -> None:
    """Test get_user returns user from client."""
    user = UserConfig(user_id="U123", email="test@example.com")
    mock_client.get_user.return_value = user

    result = manager.get_user("U123")

    assert result == user
    mock_client.get_user.assert_called_once_with("U123")


def test_invite_user_logs_audit(
    manager: UserManager, mock_client: MagicMock, mock_audit: MagicMock
) -> None:
    """Test invite_user logs to audit."""
    mock_client.invite_user.return_value = {"userId": "U999"}

    manager.invite_user(email="new@test.com", name="New User", roles=[], tenant_id=None)

    mock_audit.log.assert_called_once()
    audit_entry = mock_audit.log.call_args[0][0]
    assert audit_entry.success is True
```

**Step 2: Run tests to verify they fail**

Run: `pytest tests/unit/domain/test_user_manager.py -v`
Expected: FAIL with ModuleNotFoundError

**Step 3: Create UserManager implementation**

```python
# src/descope_mgmt/domain/user_manager.py
"""User management service."""

from descope_mgmt.domain.audit_logger import AuditLogger
from descope_mgmt.types.audit import AuditEntry, AuditOperation
from descope_mgmt.types.protocols import DescopeClientProtocol
from descope_mgmt.types.user import UserConfig


class UserManager:
    """Service for managing Descope users."""

    def __init__(
        self,
        client: DescopeClientProtocol,
        audit_logger: AuditLogger | None = None,
    ) -> None:
        """Initialize UserManager.

        Args:
            client: Descope API client
            audit_logger: Optional audit logger for operation tracking
        """
        self._client = client
        self._audit_logger = audit_logger

    def list_users(
        self,
        limit: int = 100,
        tenant_id: str | None = None,
    ) -> list[UserConfig]:
        """List users with optional filters.

        Args:
            limit: Maximum number of users to return
            tenant_id: Optional tenant ID to filter by

        Returns:
            List of user configurations
        """
        return self._client.list_users(limit=limit, tenant_id=tenant_id)

    def get_user(self, user_id: str) -> UserConfig | None:
        """Get a specific user by ID.

        Args:
            user_id: User ID to retrieve

        Returns:
            User configuration or None if not found
        """
        return self._client.get_user(user_id)

    def invite_user(
        self,
        email: str,
        name: str | None = None,
        roles: list[str] | None = None,
        tenant_id: str | None = None,
    ) -> str:
        """Invite a new user via email.

        Args:
            email: User's email address
            name: Optional display name
            roles: Optional list of roles to assign
            tenant_id: Optional tenant to associate with

        Returns:
            Created user ID

        Raises:
            ApiError: If invitation fails
        """
        try:
            result = self._client.invite_user(
                email=email,
                name=name,
                roles=roles,
                tenant_id=tenant_id,
            )
            user_id = result.get("userId", "")

            if self._audit_logger:
                self._audit_logger.log(
                    AuditEntry(
                        operation=AuditOperation.USER_INVITE,
                        resource_id=user_id,
                        success=True,
                        details={"email": email},
                    )
                )

            return user_id

        except Exception as e:
            if self._audit_logger:
                self._audit_logger.log(
                    AuditEntry(
                        operation=AuditOperation.USER_INVITE,
                        resource_id=email,
                        success=False,
                        error=str(e),
                    )
                )
            raise
```

**Step 4: Run tests**

Run: `pytest tests/unit/domain/test_user_manager.py -v`
Expected: PASS

---

## Task 2: Add update_user and delete_user Methods

**Agent:** python-pro
**Files:**
- Modify: `src/descope_mgmt/domain/user_manager.py`
- Test: `tests/unit/domain/test_user_manager.py`

**Step 1: Write tests**

```python
def test_delete_user_logs_audit(
    manager: UserManager, mock_client: MagicMock, mock_audit: MagicMock
) -> None:
    """Test delete_user logs to audit."""
    mock_client.delete_user.return_value = None

    manager.delete_user("U123")

    mock_client.delete_user.assert_called_once_with("U123")
    mock_audit.log.assert_called_once()
    audit_entry = mock_audit.log.call_args[0][0]
    assert audit_entry.operation == AuditOperation.USER_DELETE
    assert audit_entry.success is True
```

**Step 2: Add methods**

```python
    def update_user(
        self,
        user_id: str,
        name: str | None = None,
        phone: str | None = None,
        status: str | None = None,
    ) -> None:
        """Update user details.

        Args:
            user_id: User ID to update
            name: New display name
            phone: New phone number
            status: New status (enabled/disabled)

        Raises:
            ApiError: If update fails
        """
        try:
            self._client.update_user(
                user_id=user_id,
                name=name,
                phone=phone,
                status=status,
            )

            if self._audit_logger:
                self._audit_logger.log(
                    AuditEntry(
                        operation=AuditOperation.USER_UPDATE,
                        resource_id=user_id,
                        success=True,
                    )
                )

        except Exception as e:
            if self._audit_logger:
                self._audit_logger.log(
                    AuditEntry(
                        operation=AuditOperation.USER_UPDATE,
                        resource_id=user_id,
                        success=False,
                        error=str(e),
                    )
                )
            raise

    def delete_user(self, user_id: str) -> None:
        """Delete a user.

        Args:
            user_id: User ID to delete

        Raises:
            ApiError: If deletion fails
        """
        try:
            self._client.delete_user(user_id)

            if self._audit_logger:
                self._audit_logger.log(
                    AuditEntry(
                        operation=AuditOperation.USER_DELETE,
                        resource_id=user_id,
                        success=True,
                    )
                )

        except Exception as e:
            if self._audit_logger:
                self._audit_logger.log(
                    AuditEntry(
                        operation=AuditOperation.USER_DELETE,
                        resource_id=user_id,
                        success=False,
                        error=str(e),
                    )
                )
            raise
```

**Step 3: Run tests**

Run: `pytest tests/unit/domain/test_user_manager.py -v`
Expected: PASS

---

## Task 3: Add Role Assignment Methods

**Agent:** python-pro
**Files:**
- Modify: `src/descope_mgmt/domain/user_manager.py`
- Test: `tests/unit/domain/test_user_manager.py`

**Step 1: Write tests**

```python
def test_add_role_logs_audit(
    manager: UserManager, mock_client: MagicMock, mock_audit: MagicMock
) -> None:
    """Test add_role logs to audit."""
    mock_client.add_user_roles.return_value = None

    manager.add_role("U123", "admin")

    mock_client.add_user_roles.assert_called_once_with("U123", ["admin"], None)
    mock_audit.log.assert_called_once()


def test_remove_role_logs_audit(
    manager: UserManager, mock_client: MagicMock, mock_audit: MagicMock
) -> None:
    """Test remove_role logs to audit."""
    mock_client.remove_user_roles.return_value = None

    manager.remove_role("U123", "viewer")

    mock_client.remove_user_roles.assert_called_once_with("U123", ["viewer"], None)
```

**Step 2: Add methods**

```python
    def add_role(
        self,
        user_id: str,
        role_name: str,
        tenant_id: str | None = None,
    ) -> None:
        """Add a role to a user.

        Args:
            user_id: User ID
            role_name: Role name to add
            tenant_id: Optional tenant scope

        Raises:
            ApiError: If operation fails
        """
        try:
            self._client.add_user_roles(user_id, [role_name], tenant_id)

            if self._audit_logger:
                self._audit_logger.log(
                    AuditEntry(
                        operation=AuditOperation.USER_ADD_ROLE,
                        resource_id=user_id,
                        success=True,
                        details={"role": role_name},
                    )
                )

        except Exception as e:
            if self._audit_logger:
                self._audit_logger.log(
                    AuditEntry(
                        operation=AuditOperation.USER_ADD_ROLE,
                        resource_id=user_id,
                        success=False,
                        error=str(e),
                    )
                )
            raise

    def remove_role(
        self,
        user_id: str,
        role_name: str,
        tenant_id: str | None = None,
    ) -> None:
        """Remove a role from a user.

        Args:
            user_id: User ID
            role_name: Role name to remove
            tenant_id: Optional tenant scope

        Raises:
            ApiError: If operation fails
        """
        try:
            self._client.remove_user_roles(user_id, [role_name], tenant_id)

            if self._audit_logger:
                self._audit_logger.log(
                    AuditEntry(
                        operation=AuditOperation.USER_REMOVE_ROLE,
                        resource_id=user_id,
                        success=True,
                        details={"role": role_name},
                    )
                )

        except Exception as e:
            if self._audit_logger:
                self._audit_logger.log(
                    AuditEntry(
                        operation=AuditOperation.USER_REMOVE_ROLE,
                        resource_id=user_id,
                        success=False,
                        error=str(e),
                    )
                )
            raise
```

**Step 3: Run all tests**

Run: `pytest tests/unit/domain/test_user_manager.py -v`
Expected: All tests pass

**Step 4: Commit**

```bash
git add src/descope_mgmt/domain/user_manager.py tests/unit/domain/test_user_manager.py
git commit -m "feat(domain): add UserManager service with CRUD and role assignment"
```

---

## Chunk Complete Checklist

- [ ] All tasks completed
- [ ] All tests passing
- [ ] Code committed
- [ ] Ready for next chunk
