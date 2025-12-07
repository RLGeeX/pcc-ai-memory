# Chunk 4: Role API Client - CRUD Methods

**Status:** pending
**Dependencies:** chunk-001-user-role-models, chunk-002a-protocol-updates
**Complexity:** medium
**Estimated Time:** 10 minutes
**Tasks:** 2
**Phase:** API Client Methods

---

## Task 1: Add list_roles and create_role Methods

**Agent:** python-pro
**Files:**
- Modify: `src/descope_mgmt/api/descope_client.py`
- Test: `tests/unit/api/test_descope_client.py`

**Step 1: Write tests for list_roles and create_role**

```python
def test_list_roles_returns_role_configs(
    mock_requests: MagicMock,
    client: DescopeClient,
) -> None:
    """Test list_roles returns list of RoleConfig objects."""
    mock_requests.return_value.status_code = 200
    mock_requests.return_value.json.return_value = {
        "roles": [
            {"name": "admin", "description": "Administrator", "permissionNames": ["*"]},
            {"name": "viewer", "description": "Read-only", "permissionNames": ["read"]},
        ]
    }

    roles = client.list_roles()

    assert len(roles) == 2
    assert roles[0].name == "admin"
    assert roles[0].permissions == ["*"]
    assert roles[1].name == "viewer"


def test_create_role_sends_correct_payload(
    mock_requests: MagicMock,
    client: DescopeClient,
) -> None:
    """Test create_role sends correct data."""
    mock_requests.return_value.status_code = 200
    mock_requests.return_value.json.return_value = {}

    from descope_mgmt.types.role import RoleConfig
    config = RoleConfig(name="editor", description="Can edit", permissions=["read", "write"])
    client.create_role(config)

    assert "mgmt/role/create" in mock_requests.call_args[1]["url"]
    call_data = mock_requests.call_args[1]["json"]
    assert call_data["name"] == "editor"
    assert call_data["description"] == "Can edit"
    assert call_data["permissionNames"] == ["read", "write"]
```

**Step 2: Run tests to verify they fail**

Run: `pytest tests/unit/api/test_descope_client.py::test_list_roles_returns_role_configs -v`
Expected: FAIL with AttributeError

**Step 3: Add imports and methods**

Add import at top of descope_client.py:
```python
from descope_mgmt.types.role import RoleConfig
```

Add methods:

```python
    def list_roles(self) -> list[RoleConfig]:
        """List all project-level roles.

        Returns:
            List of role configurations

        Raises:
            ApiError: If API request fails after retries
        """
        endpoint = f"{BASE_URL}/mgmt/role/all"
        response = self._request_with_retry("GET", endpoint, None)
        roles_data = response.get("roles", [])
        return [RoleConfig(**r) for r in roles_data]

    def create_role(self, config: RoleConfig) -> dict[str, Any]:
        """Create a new role.

        Args:
            config: Role configuration

        Returns:
            API response

        Raises:
            ApiError: If API request fails after retries
        """
        endpoint = f"{BASE_URL}/mgmt/role/create"
        data = {
            "name": config.name,
            "description": config.description,
            "permissionNames": config.permissions,
        }
        return self._request_with_retry("POST", endpoint, data)
```

**Step 4: Run tests to verify they pass**

Run: `pytest tests/unit/api/test_descope_client.py -k "role" -v`
Expected: PASS

---

## Task 2: Add update_role and delete_role Methods

**Agent:** python-pro
**Files:**
- Modify: `src/descope_mgmt/api/descope_client.py`
- Test: `tests/unit/api/test_descope_client.py`

**Step 1: Write tests**

```python
def test_update_role_sends_correct_payload(
    mock_requests: MagicMock,
    client: DescopeClient,
) -> None:
    """Test update_role sends correct data."""
    mock_requests.return_value.status_code = 200
    mock_requests.return_value.json.return_value = {}

    client.update_role(
        name="editor",
        new_name="senior-editor",
        description="Senior editor role",
        permissions=["read", "write", "publish"],
    )

    assert "mgmt/role/update" in mock_requests.call_args[1]["url"]
    call_data = mock_requests.call_args[1]["json"]
    assert call_data["name"] == "editor"
    assert call_data["newName"] == "senior-editor"


def test_delete_role_calls_correct_endpoint(
    mock_requests: MagicMock,
    client: DescopeClient,
) -> None:
    """Test delete_role calls correct endpoint."""
    mock_requests.return_value.status_code = 200
    mock_requests.return_value.json.return_value = {}

    client.delete_role("old-role")

    assert "mgmt/role/delete" in mock_requests.call_args[1]["url"]
    call_data = mock_requests.call_args[1]["json"]
    assert call_data["name"] == "old-role"
```

**Step 2: Add methods**

```python
    def update_role(
        self,
        name: str,
        new_name: str | None = None,
        description: str | None = None,
        permissions: list[str] | None = None,
    ) -> dict[str, Any]:
        """Update an existing role.

        Args:
            name: Current role name
            new_name: New name for the role (optional)
            description: New description (optional)
            permissions: New list of permissions (optional, replaces existing)

        Returns:
            API response

        Raises:
            ApiError: If API request fails after retries
        """
        endpoint = f"{BASE_URL}/mgmt/role/update"
        data: dict[str, Any] = {"name": name}
        if new_name:
            data["newName"] = new_name
        if description is not None:
            data["description"] = description
        if permissions is not None:
            data["permissionNames"] = permissions
        return self._request_with_retry("POST", endpoint, data)

    def delete_role(self, name: str) -> None:
        """Delete a role.

        Args:
            name: Role name to delete

        Raises:
            ApiError: If API request fails after retries
        """
        endpoint = f"{BASE_URL}/mgmt/role/delete"
        data = {"name": name}
        self._request_with_retry("POST", endpoint, data)
```

**Step 3: Run all role tests**

Run: `pytest tests/unit/api/test_descope_client.py -k "role" -v`
Expected: All tests pass

**Step 4: Commit**

```bash
git add src/descope_mgmt/api/descope_client.py tests/unit/api/test_descope_client.py
git commit -m "feat(api): add role CRUD methods to DescopeClient"
```

---

## Chunk Complete Checklist

- [ ] All tasks completed
- [ ] All tests passing
- [ ] Code committed
- [ ] Ready for next chunk
