# Chunk 5: User Role Assignment API Methods

**Status:** pending
**Dependencies:** chunk-003-user-api-crud
**Complexity:** medium
**Estimated Time:** 10 minutes
**Tasks:** 2
**Phase:** API Client Methods

---

## Task 1: Add add_user_roles and remove_user_roles Methods

**Agent:** python-pro
**Files:**
- Modify: `src/descope_mgmt/api/descope_client.py`
- Test: `tests/unit/api/test_descope_client.py`

**Step 1: Write tests**

```python
def test_add_user_roles_sends_correct_payload(
    mock_requests: MagicMock,
    client: DescopeClient,
) -> None:
    """Test add_user_roles sends correct data."""
    mock_requests.return_value.status_code = 200
    mock_requests.return_value.json.return_value = {}

    client.add_user_roles("U123", ["admin", "viewer"])

    assert "mgmt/user/update/role/add" in mock_requests.call_args[1]["url"]
    call_data = mock_requests.call_args[1]["json"]
    assert call_data["userId"] == "U123"
    assert call_data["roleNames"] == ["admin", "viewer"]


def test_add_user_roles_with_tenant(
    mock_requests: MagicMock,
    client: DescopeClient,
) -> None:
    """Test add_user_roles with tenant scope."""
    mock_requests.return_value.status_code = 200
    mock_requests.return_value.json.return_value = {}

    client.add_user_roles("U123", ["admin"], tenant_id="tenant-1")

    call_data = mock_requests.call_args[1]["json"]
    assert call_data["tenantId"] == "tenant-1"


def test_remove_user_roles_sends_correct_payload(
    mock_requests: MagicMock,
    client: DescopeClient,
) -> None:
    """Test remove_user_roles sends correct data."""
    mock_requests.return_value.status_code = 200
    mock_requests.return_value.json.return_value = {}

    client.remove_user_roles("U123", ["viewer"])

    assert "mgmt/user/update/role/remove" in mock_requests.call_args[1]["url"]
    call_data = mock_requests.call_args[1]["json"]
    assert call_data["userId"] == "U123"
    assert call_data["roleNames"] == ["viewer"]
```

**Step 2: Run tests to verify they fail**

Run: `pytest tests/unit/api/test_descope_client.py::test_add_user_roles_sends_correct_payload -v`
Expected: FAIL

**Step 3: Add methods**

```python
    def add_user_roles(
        self,
        user_id: str,
        roles: list[str],
        tenant_id: str | None = None,
    ) -> None:
        """Add roles to a user without overwriting existing roles.

        Args:
            user_id: User ID
            roles: List of role names to add
            tenant_id: Optional tenant scope for the roles

        Raises:
            ApiError: If API request fails after retries
        """
        endpoint = f"{BASE_URL}/mgmt/user/update/role/add"
        data: dict[str, Any] = {
            "userId": user_id,
            "roleNames": roles,
        }
        if tenant_id:
            data["tenantId"] = tenant_id
        self._request_with_retry("POST", endpoint, data)

    def remove_user_roles(
        self,
        user_id: str,
        roles: list[str],
        tenant_id: str | None = None,
    ) -> None:
        """Remove specific roles from a user.

        Args:
            user_id: User ID
            roles: List of role names to remove
            tenant_id: Optional tenant scope for the roles

        Raises:
            ApiError: If API request fails after retries
        """
        endpoint = f"{BASE_URL}/mgmt/user/update/role/remove"
        data: dict[str, Any] = {
            "userId": user_id,
            "roleNames": roles,
        }
        if tenant_id:
            data["tenantId"] = tenant_id
        self._request_with_retry("POST", endpoint, data)
```

**Step 4: Run tests**

Run: `pytest tests/unit/api/test_descope_client.py -k "user_roles" -v`
Expected: PASS (3 tests)

---

## Task 2: Add set_user_roles Method

**Agent:** python-pro
**Files:**
- Modify: `src/descope_mgmt/api/descope_client.py`
- Test: `tests/unit/api/test_descope_client.py`

**Step 1: Write test**

```python
def test_set_user_roles_replaces_all_roles(
    mock_requests: MagicMock,
    client: DescopeClient,
) -> None:
    """Test set_user_roles replaces all roles."""
    mock_requests.return_value.status_code = 200
    mock_requests.return_value.json.return_value = {}

    client.set_user_roles("U123", ["editor"])

    assert "mgmt/user/update/role/set" in mock_requests.call_args[1]["url"]
    call_data = mock_requests.call_args[1]["json"]
    assert call_data["userId"] == "U123"
    assert call_data["roleNames"] == ["editor"]
```

**Step 2: Add method**

```python
    def set_user_roles(
        self,
        user_id: str,
        roles: list[str],
        tenant_id: str | None = None,
    ) -> None:
        """Set (replace) all roles for a user.

        Args:
            user_id: User ID
            roles: List of role names (replaces all existing roles)
            tenant_id: Optional tenant scope for the roles

        Raises:
            ApiError: If API request fails after retries
        """
        endpoint = f"{BASE_URL}/mgmt/user/update/role/set"
        data: dict[str, Any] = {
            "userId": user_id,
            "roleNames": roles,
        }
        if tenant_id:
            data["tenantId"] = tenant_id
        self._request_with_retry("POST", endpoint, data)
```

**Step 3: Run all API tests**

Run: `pytest tests/unit/api/test_descope_client.py -v`
Expected: All tests pass

**Step 4: Commit**

```bash
git add src/descope_mgmt/api/descope_client.py tests/unit/api/test_descope_client.py
git commit -m "feat(api): add user role assignment methods"
```

---

## REVIEW CHECKPOINT

This is a review checkpoint. After completing this chunk:
1. Run full test suite: `pytest tests/unit/ -v`
2. Run linters: `ruff check . && mypy .`
3. Review all API client changes for consistency

---

## Chunk Complete Checklist

- [ ] All tasks completed
- [ ] All tests passing
- [ ] Code committed
- [ ] Review checkpoint completed
- [ ] Ready for next chunk
