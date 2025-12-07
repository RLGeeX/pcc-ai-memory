# Chunk 7: RoleManager Domain Service

**Status:** pending
**Dependencies:** chunk-004-role-api-crud
**Complexity:** simple
**Estimated Time:** 10 minutes
**Tasks:** 2
**Phase:** Domain Layer

---

## Task 1: Create RoleManager with CRUD Operations

**Agent:** python-pro
**Files:**
- Create: `src/descope_mgmt/domain/role_manager.py`
- Test: `tests/unit/domain/test_role_manager.py`

**Step 1: Write tests**

```python
# tests/unit/domain/test_role_manager.py
"""Tests for RoleManager service."""

from unittest.mock import MagicMock, create_autospec

import pytest

from descope_mgmt.domain.audit_logger import AuditLogger
from descope_mgmt.domain.role_manager import RoleManager
from descope_mgmt.types.audit import AuditOperation
from descope_mgmt.types.protocols import DescopeClientProtocol
from descope_mgmt.types.role import RoleConfig


@pytest.fixture
def mock_client() -> MagicMock:
    """Create mock Descope client."""
    return create_autospec(DescopeClientProtocol)


@pytest.fixture
def mock_audit() -> MagicMock:
    """Create mock audit logger."""
    return create_autospec(AuditLogger)


@pytest.fixture
def manager(mock_client: MagicMock, mock_audit: MagicMock) -> RoleManager:
    """Create RoleManager with mocks."""
    return RoleManager(mock_client, mock_audit)


def test_list_roles_delegates_to_client(
    manager: RoleManager, mock_client: MagicMock
) -> None:
    """Test list_roles calls client method."""
    mock_client.list_roles.return_value = []

    result = manager.list_roles()

    mock_client.list_roles.assert_called_once()
    assert result == []


def test_get_role_finds_by_name(
    manager: RoleManager, mock_client: MagicMock
) -> None:
    """Test get_role returns matching role."""
    roles = [
        RoleConfig(name="admin", description="Admin role"),
        RoleConfig(name="viewer", description="Viewer role"),
    ]
    mock_client.list_roles.return_value = roles

    result = manager.get_role("admin")

    assert result is not None
    assert result.name == "admin"


def test_get_role_returns_none_if_not_found(
    manager: RoleManager, mock_client: MagicMock
) -> None:
    """Test get_role returns None for unknown role."""
    mock_client.list_roles.return_value = []

    result = manager.get_role("nonexistent")

    assert result is None


def test_create_role_logs_audit(
    manager: RoleManager, mock_client: MagicMock, mock_audit: MagicMock
) -> None:
    """Test create_role logs to audit."""
    mock_client.create_role.return_value = {}

    manager.create_role(name="editor", description="Editor role", permissions=["write"])

    mock_client.create_role.assert_called_once()
    mock_audit.log.assert_called_once()
    audit_entry = mock_audit.log.call_args[0][0]
    assert audit_entry.operation == AuditOperation.ROLE_CREATE
    assert audit_entry.success is True
```

**Step 2: Run tests to verify they fail**

Run: `pytest tests/unit/domain/test_role_manager.py -v`
Expected: FAIL with ModuleNotFoundError

**Step 3: Create RoleManager implementation**

```python
# src/descope_mgmt/domain/role_manager.py
"""Role management service."""

from descope_mgmt.domain.audit_logger import AuditLogger
from descope_mgmt.types.audit import AuditEntry, AuditOperation
from descope_mgmt.types.protocols import DescopeClientProtocol
from descope_mgmt.types.role import RoleConfig


class RoleManager:
    """Service for managing Descope roles."""

    def __init__(
        self,
        client: DescopeClientProtocol,
        audit_logger: AuditLogger | None = None,
    ) -> None:
        """Initialize RoleManager.

        Args:
            client: Descope API client
            audit_logger: Optional audit logger for operation tracking
        """
        self._client = client
        self._audit_logger = audit_logger

    def list_roles(self) -> list[RoleConfig]:
        """List all project-level roles.

        Returns:
            List of role configurations
        """
        return self._client.list_roles()

    def get_role(self, name: str) -> RoleConfig | None:
        """Get a role by name.

        Args:
            name: Role name to find

        Returns:
            Role configuration or None if not found
        """
        roles = self._client.list_roles()
        for role in roles:
            if role.name == name:
                return role
        return None

    def create_role(
        self,
        name: str,
        description: str | None = None,
        permissions: list[str] | None = None,
    ) -> RoleConfig:
        """Create a new role.

        Args:
            name: Role name (unique identifier)
            description: Human-readable description
            permissions: List of permission names

        Returns:
            Created role configuration

        Raises:
            ApiError: If creation fails
        """
        config = RoleConfig(
            name=name,
            description=description,
            permissions=permissions or [],
        )

        try:
            self._client.create_role(config)

            if self._audit_logger:
                self._audit_logger.log(
                    AuditEntry(
                        operation=AuditOperation.ROLE_CREATE,
                        resource_id=name,
                        success=True,
                        details={"description": description or ""},
                    )
                )

            return config

        except Exception as e:
            if self._audit_logger:
                self._audit_logger.log(
                    AuditEntry(
                        operation=AuditOperation.ROLE_CREATE,
                        resource_id=name,
                        success=False,
                        error=str(e),
                    )
                )
            raise
```

**Step 4: Run tests**

Run: `pytest tests/unit/domain/test_role_manager.py -v`
Expected: PASS

---

## Task 2: Add update_role and delete_role Methods

**Agent:** python-pro
**Files:**
- Modify: `src/descope_mgmt/domain/role_manager.py`
- Test: `tests/unit/domain/test_role_manager.py`

**Step 1: Write tests**

```python
def test_update_role_logs_audit(
    manager: RoleManager, mock_client: MagicMock, mock_audit: MagicMock
) -> None:
    """Test update_role logs to audit."""
    mock_client.update_role.return_value = {}

    manager.update_role(name="editor", description="Updated description")

    mock_client.update_role.assert_called_once()
    mock_audit.log.assert_called_once()


def test_delete_role_logs_audit(
    manager: RoleManager, mock_client: MagicMock, mock_audit: MagicMock
) -> None:
    """Test delete_role logs to audit."""
    mock_client.delete_role.return_value = None

    manager.delete_role("old-role")

    mock_client.delete_role.assert_called_once_with("old-role")
    mock_audit.log.assert_called_once()
    audit_entry = mock_audit.log.call_args[0][0]
    assert audit_entry.operation == AuditOperation.ROLE_DELETE
```

**Step 2: Add methods**

```python
    def update_role(
        self,
        name: str,
        new_name: str | None = None,
        description: str | None = None,
        permissions: list[str] | None = None,
    ) -> None:
        """Update an existing role.

        Args:
            name: Current role name
            new_name: New name for the role
            description: New description
            permissions: New list of permissions (replaces existing)

        Raises:
            ApiError: If update fails
        """
        try:
            self._client.update_role(
                name=name,
                new_name=new_name,
                description=description,
                permissions=permissions,
            )

            if self._audit_logger:
                self._audit_logger.log(
                    AuditEntry(
                        operation=AuditOperation.ROLE_UPDATE,
                        resource_id=name,
                        success=True,
                    )
                )

        except Exception as e:
            if self._audit_logger:
                self._audit_logger.log(
                    AuditEntry(
                        operation=AuditOperation.ROLE_UPDATE,
                        resource_id=name,
                        success=False,
                        error=str(e),
                    )
                )
            raise

    def delete_role(self, name: str) -> None:
        """Delete a role.

        Args:
            name: Role name to delete

        Raises:
            ApiError: If deletion fails
        """
        try:
            self._client.delete_role(name)

            if self._audit_logger:
                self._audit_logger.log(
                    AuditEntry(
                        operation=AuditOperation.ROLE_DELETE,
                        resource_id=name,
                        success=True,
                    )
                )

        except Exception as e:
            if self._audit_logger:
                self._audit_logger.log(
                    AuditEntry(
                        operation=AuditOperation.ROLE_DELETE,
                        resource_id=name,
                        success=False,
                        error=str(e),
                    )
                )
            raise
```

**Step 3: Run all tests**

Run: `pytest tests/unit/domain/test_role_manager.py -v`
Expected: All tests pass

**Step 4: Commit**

```bash
git add src/descope_mgmt/domain/role_manager.py tests/unit/domain/test_role_manager.py
git commit -m "feat(domain): add RoleManager service with CRUD operations"
```

---

## Chunk Complete Checklist

- [ ] All tasks completed
- [ ] All tests passing
- [ ] Code committed
- [ ] Ready for next chunk
