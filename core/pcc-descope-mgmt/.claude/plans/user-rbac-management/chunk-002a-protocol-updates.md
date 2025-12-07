# Chunk 2A: Protocol and Export Updates

**Status:** pending
**Dependencies:** chunk-001-user-role-models
**Complexity:** simple
**Estimated Time:** 5 minutes
**Tasks:** 2
**Phase:** Data Models & Exceptions

---

## Task 1: Update DescopeClientProtocol

**Agent:** python-pro
**Files:**
- Modify: `src/descope_mgmt/types/protocols.py`

**Step 1: Add TYPE_CHECKING imports for new types**

At top of file, update the TYPE_CHECKING block:

```python
if TYPE_CHECKING:
    from descope_mgmt.types.flow import FlowConfig
    from descope_mgmt.types.role import RoleConfig
    from descope_mgmt.types.tenant import TenantConfig
    from descope_mgmt.types.user import UserConfig
```

**Step 2: Add user methods to DescopeClientProtocol**

After the flow methods, add:

```python
    # User operations
    def list_users(
        self, limit: int = 100, tenant_id: str | None = None
    ) -> list["UserConfig"]:
        """List users with optional filters."""
        ...

    def get_user(self, user_id: str) -> "UserConfig | None":
        """Get a specific user by ID."""
        ...

    def invite_user(
        self,
        email: str,
        name: str | None = None,
        roles: list[str] | None = None,
        tenant_id: str | None = None,
    ) -> dict[str, Any]:
        """Invite a new user via email."""
        ...

    def update_user(
        self,
        user_id: str,
        name: str | None = None,
        phone: str | None = None,
        status: str | None = None,
    ) -> dict[str, Any]:
        """Update user details."""
        ...

    def delete_user(self, user_id: str) -> None:
        """Delete a user."""
        ...

    def add_user_roles(
        self,
        user_id: str,
        roles: list[str],
        tenant_id: str | None = None,
    ) -> None:
        """Add roles to a user."""
        ...

    def remove_user_roles(
        self,
        user_id: str,
        roles: list[str],
        tenant_id: str | None = None,
    ) -> None:
        """Remove roles from a user."""
        ...

    def set_user_roles(
        self,
        user_id: str,
        roles: list[str],
        tenant_id: str | None = None,
    ) -> None:
        """Set (replace) all roles for a user."""
        ...
```

**Step 3: Add role methods to DescopeClientProtocol**

After user methods, add:

```python
    # Role operations
    def list_roles(self) -> list["RoleConfig"]:
        """List all project-level roles."""
        ...

    def create_role(self, config: "RoleConfig") -> dict[str, Any]:
        """Create a new role."""
        ...

    def update_role(
        self,
        name: str,
        new_name: str | None = None,
        description: str | None = None,
        permissions: list[str] | None = None,
    ) -> dict[str, Any]:
        """Update an existing role."""
        ...

    def delete_role(self, name: str) -> None:
        """Delete a role."""
        ...
```

---

## Task 2: Update types/__init__.py Exports

**Agent:** python-pro
**Files:**
- Modify: `src/descope_mgmt/types/__init__.py`

**Step 1: Read current exports**

Check what's currently exported from the types package.

**Step 2: Add new type exports**

Add to `__init__.py`:

```python
from descope_mgmt.types.role import RoleConfig
from descope_mgmt.types.user import UserConfig, UserStatus
```

And update `__all__` if it exists:

```python
__all__ = [
    # ... existing exports ...
    "RoleConfig",
    "UserConfig",
    "UserStatus",
]
```

**Step 3: Verify imports work**

Run: `python -c "from descope_mgmt.types import UserConfig, UserStatus, RoleConfig; print('OK')"`
Expected: "OK"

**Step 4: Commit**

```bash
git add src/descope_mgmt/types/protocols.py src/descope_mgmt/types/__init__.py
git commit -m "feat(types): add user/role protocol methods and type exports"
```

---

## Chunk Complete Checklist

- [ ] Protocol updated with all user methods
- [ ] Protocol updated with all role methods
- [ ] Types exported from __init__.py
- [ ] Import verification passes
- [ ] Code committed
- [ ] Ready for next chunk
