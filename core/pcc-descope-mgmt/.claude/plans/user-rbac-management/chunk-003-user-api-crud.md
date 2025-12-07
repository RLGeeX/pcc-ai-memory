# Chunk 3: User API Client - CRUD Methods

**Status:** pending
**Dependencies:** chunk-001-user-role-models, chunk-002a-protocol-updates
**Complexity:** medium
**Estimated Time:** 15 minutes
**Tasks:** 3
**Phase:** API Client Methods

---

## Task 1: Add list_users and get_user Methods

**Agent:** python-pro
**Files:**
- Modify: `src/descope_mgmt/api/descope_client.py`
- Test: `tests/unit/api/test_descope_client.py`

**Step 1: Write tests for list_users and get_user**

Add to `tests/unit/api/test_descope_client.py`:

```python
def test_list_users_returns_user_configs(
    mock_requests: MagicMock,
    client: DescopeClient,
) -> None:
    """Test list_users returns list of UserConfig objects."""
    mock_requests.return_value.status_code = 200
    mock_requests.return_value.json.return_value = {
        "users": [
            {"userId": "U1", "email": "a@test.com", "status": "enabled"},
            {"userId": "U2", "email": "b@test.com", "status": "invited"},
        ]
    }

    users = client.list_users()

    assert len(users) == 2
    assert users[0].user_id == "U1"
    assert users[1].email == "b@test.com"
    mock_requests.assert_called_once()
    assert "mgmt/user/search" in mock_requests.call_args[1]["url"]


def test_get_user_returns_user_config(
    mock_requests: MagicMock,
    client: DescopeClient,
) -> None:
    """Test get_user returns UserConfig for valid user."""
    mock_requests.return_value.status_code = 200
    mock_requests.return_value.json.return_value = {
        "userId": "U123",
        "email": "test@example.com",
        "displayName": "Test User",
    }

    user = client.get_user("U123")

    assert user is not None
    assert user.user_id == "U123"
    assert user.display_name == "Test User"


def test_get_user_returns_none_for_404(
    mock_requests: MagicMock,
    client: DescopeClient,
) -> None:
    """Test get_user returns None when user not found."""
    mock_requests.return_value.status_code = 404
    mock_requests.return_value.text = "User not found"

    user = client.get_user("nonexistent")

    assert user is None
```

**Step 2: Run tests to verify they fail**

Run: `pytest tests/unit/api/test_descope_client.py::test_list_users_returns_user_configs -v`
Expected: FAIL with AttributeError

**Step 3: Add imports and methods to descope_client.py**

Add import at top:
```python
from descope_mgmt.types.user import UserConfig
```

Add methods to DescopeClient class:

```python
    def list_users(
        self, limit: int = 100, tenant_id: str | None = None
    ) -> list[UserConfig]:
        """List users with optional filters.

        Args:
            limit: Maximum number of users to return (default 100)
            tenant_id: Optional tenant ID to filter users

        Returns:
            List of user configurations

        Raises:
            ApiError: If API request fails after retries
        """
        endpoint = f"{BASE_URL}/mgmt/user/search"
        data: dict[str, Any] = {"limit": limit}
        if tenant_id:
            data["tenantIds"] = [tenant_id]
        response = self._request_with_retry("POST", endpoint, data)
        users_data = response.get("users", [])
        return [UserConfig(**u) for u in users_data]

    def get_user(self, user_id: str) -> UserConfig | None:
        """Get a specific user by ID.

        Args:
            user_id: Unique user identifier

        Returns:
            User configuration or None if not found

        Raises:
            ApiError: If API request fails after retries
        """
        endpoint = f"{BASE_URL}/mgmt/user?userId={user_id}"
        try:
            response = self._request_with_retry("GET", endpoint, None)
            return UserConfig(**response)
        except ApiError as e:
            if e.status_code == 404:
                return None
            raise
```

**Step 4: Run tests to verify they pass**

Run: `pytest tests/unit/api/test_descope_client.py -k "list_users or get_user" -v`
Expected: PASS (3 tests)

---

## Task 2: Add invite_user Method

**Agent:** python-pro
**Files:**
- Modify: `src/descope_mgmt/api/descope_client.py`
- Test: `tests/unit/api/test_descope_client.py`

**Step 1: Write test for invite_user**

```python
def test_invite_user_sends_correct_payload(
    mock_requests: MagicMock,
    client: DescopeClient,
) -> None:
    """Test invite_user sends invitation email."""
    mock_requests.return_value.status_code = 200
    mock_requests.return_value.json.return_value = {"userId": "U999"}

    result = client.invite_user(
        email="new@example.com",
        name="New User",
        roles=["viewer"],
        tenant_id=None,
    )

    assert result["userId"] == "U999"
    call_data = mock_requests.call_args[1]["json"]
    assert call_data["email"] == "new@example.com"
    assert call_data["displayName"] == "New User"
    assert call_data["roleNames"] == ["viewer"]
    assert "invite" in call_data or "sendMail" in str(call_data)
```

**Step 2: Add invite_user method**

```python
    def invite_user(
        self,
        email: str,
        name: str | None = None,
        roles: list[str] | None = None,
        tenant_id: str | None = None,
    ) -> dict[str, Any]:
        """Invite a new user via email.

        Args:
            email: User's email address
            name: Optional display name
            roles: Optional list of role names to assign
            tenant_id: Optional tenant to associate user with

        Returns:
            API response with created user ID

        Raises:
            ApiError: If API request fails after retries
        """
        endpoint = f"{BASE_URL}/mgmt/user/create"
        data: dict[str, Any] = {
            "loginId": email,
            "email": email,
            "invite": True,
        }
        if name:
            data["displayName"] = name
        if roles:
            data["roleNames"] = roles
        if tenant_id:
            data["tenantIds"] = [tenant_id]
        return self._request_with_retry("POST", endpoint, data)
```

**Step 3: Run test to verify it passes**

Run: `pytest tests/unit/api/test_descope_client.py::test_invite_user_sends_correct_payload -v`
Expected: PASS

---

## Task 3: Add update_user and delete_user Methods

**Agent:** python-pro
**Files:**
- Modify: `src/descope_mgmt/api/descope_client.py`
- Test: `tests/unit/api/test_descope_client.py`

**Step 1: Write tests**

```python
def test_update_user_sends_correct_endpoint(
    mock_requests: MagicMock,
    client: DescopeClient,
) -> None:
    """Test update_user calls correct endpoint."""
    mock_requests.return_value.status_code = 200
    mock_requests.return_value.json.return_value = {}

    client.update_user(
        user_id="U123",
        name="Updated Name",
        phone="+1234567890",
    )

    assert "mgmt/user/update" in mock_requests.call_args[1]["url"]
    call_data = mock_requests.call_args[1]["json"]
    assert call_data["userId"] == "U123"
    assert call_data["displayName"] == "Updated Name"


def test_delete_user_calls_correct_endpoint(
    mock_requests: MagicMock,
    client: DescopeClient,
) -> None:
    """Test delete_user calls correct endpoint."""
    mock_requests.return_value.status_code = 200
    mock_requests.return_value.json.return_value = {}

    client.delete_user("U123")

    assert "mgmt/user/delete" in mock_requests.call_args[1]["url"]
    call_data = mock_requests.call_args[1]["json"]
    assert call_data["userId"] == "U123"
```

**Step 2: Add methods**

```python
    def update_user(
        self,
        user_id: str,
        name: str | None = None,
        phone: str | None = None,
        status: str | None = None,
    ) -> dict[str, Any]:
        """Update user details.

        Uses specific update endpoints to avoid overwriting unrelated fields.

        Args:
            user_id: User ID to update
            name: New display name
            phone: New phone number
            status: New status (enabled/disabled)

        Returns:
            API response

        Raises:
            ApiError: If API request fails after retries
        """
        results: dict[str, Any] = {}

        if name:
            endpoint = f"{BASE_URL}/mgmt/user/update/name"
            data = {"userId": user_id, "displayName": name}
            results["name"] = self._request_with_retry("POST", endpoint, data)

        if phone:
            endpoint = f"{BASE_URL}/mgmt/user/update/phone"
            data = {"userId": user_id, "phone": phone}
            results["phone"] = self._request_with_retry("POST", endpoint, data)

        if status:
            endpoint = f"{BASE_URL}/mgmt/user/update/status"
            data = {"userId": user_id, "status": status}
            results["status"] = self._request_with_retry("POST", endpoint, data)

        return results

    def delete_user(self, user_id: str) -> None:
        """Delete a user.

        Args:
            user_id: User ID to delete

        Raises:
            ApiError: If API request fails after retries
        """
        endpoint = f"{BASE_URL}/mgmt/user/delete"
        data = {"userId": user_id}
        self._request_with_retry("POST", endpoint, data)
```

**Step 3: Run all user API tests**

Run: `pytest tests/unit/api/test_descope_client.py -k "user" -v`
Expected: All tests pass

**Step 4: Commit**

```bash
git add src/descope_mgmt/api/descope_client.py tests/unit/api/test_descope_client.py
git commit -m "feat(api): add user CRUD methods to DescopeClient"
```

---

## Chunk Complete Checklist

- [ ] All tasks completed
- [ ] All tests passing
- [ ] Code committed
- [ ] Ready for next chunk
