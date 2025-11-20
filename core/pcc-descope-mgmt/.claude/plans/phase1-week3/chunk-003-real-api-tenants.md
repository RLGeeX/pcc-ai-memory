# Chunk 3: Real Descope API - Tenants

**Status:** pending
**Dependencies:** chunk-002-yaml-tenant-config
**Complexity:** complex
**Estimated Time:** 60 minutes
**Tasks:** 3

---

## Context

This chunk replaces FakeDescopeClient with real Descope Management API calls for tenant operations. The existing DescopeClient class has placeholder implementations that return mock data. This chunk implements the actual HTTP calls to Descope's REST API.

**Descope Tenant API Endpoints:**
- `GET /v1/mgmt/tenant/all` - List all tenants
- `GET /v1/mgmt/tenant/{tenantId}` - Get single tenant
- `POST /v1/mgmt/tenant/create` - Create tenant
- `POST /v1/mgmt/tenant/update` - Update tenant
- `DELETE /v1/mgmt/tenant/{tenantId}` - Delete tenant

**Error Handling:** Must handle 4xx (validation errors, not found) and 5xx (server errors) responses with actionable error messages.

---

## Task 1: Implement Real Tenant API Methods

**Agent:** python-pro

**Files:**
- Modify: `src/descope_mgmt/api/descope_client.py:200-350` (tenant methods)
- Modify: `tests/unit/api/test_descope_client.py` (update unit tests)

**Step 1: Update unit tests to use responses library**

Add to `tests/unit/api/test_descope_client.py`:

```python
import responses
from descope_mgmt.types.tenant import TenantConfig


@responses.activate
def test_list_tenants_success() -> None:
    """Test list_tenants with successful API response."""
    responses.add(
        responses.GET,
        "https://api.descope.com/v1/mgmt/tenant/all",
        json={"tenants": [
            {"id": "tenant1", "name": "Tenant 1", "domains": ["t1.com"]},
            {"id": "tenant2", "name": "Tenant 2", "domains": []},
        ]},
        status=200,
    )

    rate_limiter = FakeRateLimiter()
    client = DescopeClient("P2test", "K2test", rate_limiter)

    tenants = client.list_tenants()

    assert len(tenants) == 2
    assert tenants[0].id == "tenant1"
    assert tenants[1].id == "tenant2"


@responses.activate
def test_create_tenant_success() -> None:
    """Test create_tenant with successful API response."""
    responses.add(
        responses.POST,
        "https://api.descope.com/v1/mgmt/tenant/create",
        json={"tenant": {"id": "new-tenant", "name": "New Tenant", "domains": []}},
        status=201,
    )

    rate_limiter = FakeRateLimiter()
    client = DescopeClient("P2test", "K2test", rate_limiter)
    config = TenantConfig(id="new-tenant", name="New Tenant")

    tenant = client.create_tenant(config)

    assert tenant.id == "new-tenant"
    assert tenant.name == "New Tenant"


@responses.activate
def test_list_tenants_handles_api_error() -> None:
    """Test list_tenants handles API errors gracefully."""
    responses.add(
        responses.GET,
        "https://api.descope.com/v1/mgmt/tenant/all",
        json={"error": "Unauthorized"},
        status=401,
    )

    rate_limiter = FakeRateLimiter()
    client = DescopeClient("P2test", "K2test", rate_limiter)

    with pytest.raises(ApiError, match="401"):
        client.list_tenants()
```

**Step 2: Implement real tenant API methods**

Update `src/descope_mgmt/api/descope_client.py`:

```python
import requests
from typing import Any

from descope_mgmt.types.exceptions import ApiError
from descope_mgmt.types.tenant import TenantConfig


class DescopeClient:
    """Client for Descope Management API."""

    BASE_URL = "https://api.descope.com/v1/mgmt"

    def __init__(
        self,
        project_id: str,
        management_key: str,
        rate_limiter: RateLimiterProtocol,
    ) -> None:
        """Initialize Descope API client.

        Args:
            project_id: Descope project ID (P2...)
            management_key: Management API key (K2...)
            rate_limiter: Rate limiter instance
        """
        self._project_id = project_id
        self._management_key = management_key
        self._rate_limiter = rate_limiter
        self._session = requests.Session()
        self._session.headers.update({
            "Authorization": f"Bearer {project_id}:{management_key}",
            "Content-Type": "application/json",
        })

    def _make_request(
        self,
        method: str,
        endpoint: str,
        json_data: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        """Make HTTP request to Descope API with rate limiting and retry.

        Args:
            method: HTTP method (GET, POST, DELETE)
            endpoint: API endpoint path (e.g., "/tenant/all")
            json_data: Optional JSON body for POST requests

        Returns:
            Response JSON data

        Raises:
            ApiError: If request fails after retries
        """
        url = f"{self.BASE_URL}{endpoint}"

        # Acquire rate limit token
        self._rate_limiter.acquire()

        # Make request with retry logic
        for attempt in range(5):
            try:
                response = self._session.request(method, url, json=json_data, timeout=30)

                # Handle successful responses
                if response.status_code in (200, 201):
                    return response.json()

                # Handle rate limiting (retry)
                if response.status_code == 429:
                    wait_time = 2 ** attempt
                    time.sleep(wait_time)
                    continue

                # Handle client/server errors
                error_msg = response.json().get("error", "Unknown error")
                raise ApiError(
                    f"API request failed ({response.status_code}): {error_msg}. "
                    f"Endpoint: {endpoint}"
                )

            except requests.RequestException as e:
                if attempt == 4:  # Last attempt
                    raise ApiError(f"Network error after 5 retries: {e}")
                time.sleep(2 ** attempt)

        raise ApiError(f"Request failed after 5 retries: {endpoint}")

    def list_tenants(self) -> list[TenantConfig]:
        """List all tenants in the project.

        Returns:
            List of tenant configurations

        Raises:
            ApiError: If API request fails
        """
        data = self._make_request("GET", "/tenant/all")
        tenant_dicts = data.get("tenants", [])
        return [TenantConfig.model_validate(t) for t in tenant_dicts]

    def get_tenant(self, tenant_id: str) -> TenantConfig:
        """Get a single tenant by ID.

        Args:
            tenant_id: Tenant identifier

        Returns:
            Tenant configuration

        Raises:
            ApiError: If tenant not found or request fails
        """
        data = self._make_request("GET", f"/tenant/{tenant_id}")
        return TenantConfig.model_validate(data["tenant"])

    def create_tenant(self, config: TenantConfig) -> TenantConfig:
        """Create a new tenant.

        Args:
            config: Tenant configuration

        Returns:
            Created tenant configuration

        Raises:
            ApiError: If creation fails
        """
        payload = {
            "id": config.id,
            "name": config.name,
            "domains": config.domains,
        }
        data = self._make_request("POST", "/tenant/create", json_data=payload)
        return TenantConfig.model_validate(data["tenant"])

    def update_tenant(self, config: TenantConfig) -> TenantConfig:
        """Update an existing tenant.

        Args:
            config: Updated tenant configuration

        Returns:
            Updated tenant configuration

        Raises:
            ApiError: If update fails
        """
        payload = {
            "id": config.id,
            "name": config.name,
            "domains": config.domains,
        }
        data = self._make_request("POST", "/tenant/update", json_data=payload)
        return TenantConfig.model_validate(data["tenant"])

    def delete_tenant(self, tenant_id: str) -> None:
        """Delete a tenant.

        Args:
            tenant_id: Tenant identifier

        Raises:
            ApiError: If deletion fails
        """
        self._make_request("DELETE", f"/tenant/{tenant_id}")
```

**Step 3: Run unit tests**

Run: `pytest tests/unit/api/test_descope_client.py -v`
Expected: All tests PASS with mocked responses

**Step 4: Commit**

```bash
git add src/descope_mgmt/api/descope_client.py tests/unit/api/test_descope_client.py
git commit -m "feat: implement real Descope tenant API methods

- Replace placeholder implementations with actual HTTP calls
- Add _make_request helper with retry logic and rate limiting
- Handle 4xx/5xx errors with actionable messages
- Add comprehensive unit tests with responses library"
```

---

## Task 2: Add Integration Tests (Optional)

**Agent:** python-pro

**Files:**
- Create: `tests/integration/test_real_tenant_api.py`
- Modify: `pyproject.toml` (add pytest markers)

**Step 1: Add pytest markers for integration tests**

Update `pyproject.toml`:

```toml
[tool.pytest.ini_options]
markers = [
    "integration: marks tests as integration tests (deselect with '-m \"not integration\"')",
]
```

**Step 2: Create integration tests**

Create `tests/integration/test_real_tenant_api.py`:

```python
"""Integration tests for real Descope tenant API.

These tests require real Descope credentials:
- DESCOPE_TEST_PROJECT_ID
- DESCOPE_TEST_MANAGEMENT_KEY

Tests are skipped if credentials not provided.
"""

import os

import pytest

from descope_mgmt.api.client_factory import ClientFactory
from descope_mgmt.domain.tenant_manager import TenantManager
from descope_mgmt.types.tenant import TenantConfig


# Skip all tests if credentials not available
pytestmark = pytest.mark.skipif(
    not os.getenv("DESCOPE_TEST_PROJECT_ID") or not os.getenv("DESCOPE_TEST_MANAGEMENT_KEY"),
    reason="Integration tests require DESCOPE_TEST_PROJECT_ID and DESCOPE_TEST_MANAGEMENT_KEY",
)


@pytest.mark.integration
def test_list_tenants_real_api() -> None:
    """Test list_tenants with real Descope API."""
    client = ClientFactory.create_client()
    manager = TenantManager(client)

    tenants = manager.list_tenants()

    # Should return a list (may be empty in test project)
    assert isinstance(tenants, list)


@pytest.mark.integration
def test_create_and_delete_tenant_real_api() -> None:
    """Test tenant creation and deletion with real API."""
    client = ClientFactory.create_client()
    manager = TenantManager(client)

    # Create test tenant
    test_config = TenantConfig(
        id="integration-test-temp",
        name="Integration Test Temporary Tenant",
    )

    created = manager.create_tenant(test_config)
    assert created.id == "integration-test-temp"

    # Clean up - delete the tenant
    manager.delete_tenant("integration-test-temp")

    # Verify deletion
    tenants = manager.list_tenants()
    assert not any(t.id == "integration-test-temp" for t in tenants)
```

**Step 3: Run integration tests (if credentials available)**

Run: `pytest tests/integration/test_real_tenant_api.py -v -m integration`
Expected: SKIPPED if no credentials, PASS if credentials provided

**Step 4: Commit**

```bash
git add tests/integration/test_real_tenant_api.py pyproject.toml
git commit -m "test: add optional integration tests for real API

- Create integration tests that use real Descope API
- Tests skip gracefully if credentials not provided
- Add pytest markers for integration test filtering
- Test tenant creation and deletion end-to-end"
```

---

## Task 3: Update FakeDescopeClient for Test Compatibility

**Agent:** python-pro

**Files:**
- Modify: `tests/fakes.py:100-150` (update FakeDescopeClient implementation)

**Step 1: Update FakeDescopeClient to match real client behavior**

Update `tests/fakes.py`:

```python
from descope_mgmt.types.exceptions import ApiError


class FakeDescopeClient:
    """Fake Descope client for testing without real API calls."""

    def __init__(self) -> None:
        """Initialize fake client with in-memory storage."""
        self._tenants: dict[str, TenantConfig] = {}
        self._flows: dict[str, FlowConfig] = {}

    def list_tenants(self) -> list[TenantConfig]:
        """Return all stored tenants."""
        return list(self._tenants.values())

    def get_tenant(self, tenant_id: str) -> TenantConfig:
        """Get tenant by ID.

        Raises:
            ApiError: If tenant not found (matches real API behavior)
        """
        if tenant_id not in self._tenants:
            raise ApiError(f"Tenant not found: {tenant_id}")
        return self._tenants[tenant_id]

    def create_tenant(self, config: TenantConfig) -> TenantConfig:
        """Create tenant (store in memory).

        Raises:
            ApiError: If tenant ID already exists
        """
        if config.id in self._tenants:
            raise ApiError(f"Tenant already exists: {config.id}")
        self._tenants[config.id] = config
        return config

    def update_tenant(self, config: TenantConfig) -> TenantConfig:
        """Update tenant.

        Raises:
            ApiError: If tenant not found
        """
        if config.id not in self._tenants:
            raise ApiError(f"Tenant not found: {config.id}")
        self._tenants[config.id] = config
        return config

    def delete_tenant(self, tenant_id: str) -> None:
        """Delete tenant.

        Raises:
            ApiError: If tenant not found
        """
        if tenant_id not in self._tenants:
            raise ApiError(f"Tenant not found: {tenant_id}")
        del self._tenants[tenant_id]

    # Flow methods remain unchanged...
```

**Step 2: Run all tests to verify compatibility**

Run: `pytest tests/ -v --cov=src/descope_mgmt`
Expected: All tests PASS (existing tests use FakeDescopeClient)

**Step 3: Commit**

```bash
git add tests/fakes.py
git commit -m "test: update fake client to match real API behavior

- Add ApiError exceptions for not found scenarios
- Add duplicate ID validation in create_tenant
- Ensure fake client matches real client error behavior
- Maintains test compatibility with existing test suite"
```

---

## Chunk Complete Checklist

- [ ] Real tenant API methods implemented (Task 1)
- [ ] Integration tests added (Task 2)
- [ ] FakeDescopeClient updated for compatibility (Task 3)
- [ ] All tests passing (127+ total, +10 from chunk)
- [ ] Coverage ≥90%
- [ ] mypy, ruff, lint-imports passing
- [ ] 3 commits pushed

---

## Verification Commands

```bash
# Run unit tests
pytest tests/unit/ -v --cov=src/descope_mgmt

# Run integration tests (if credentials available)
export DESCOPE_TEST_PROJECT_ID="P2your-project-id"
export DESCOPE_TEST_MANAGEMENT_KEY="K2your-key"
pytest tests/integration/ -v -m integration

# Quality checks
mypy src/
ruff check .
lint-imports
```

**Expected:** All unit tests pass, integration tests skip or pass depending on credentials.
