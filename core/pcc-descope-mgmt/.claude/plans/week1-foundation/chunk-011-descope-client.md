# Chunk 11: Descope API Client with Retry Logic

**Status:** pending
**Dependencies:** chunk-010-rate-executor
**Complexity:** complex
**Estimated Time:** 35 minutes
**Tasks:** 3

---

## Task 1: Create DescopeClient Core

**Files:**
- Create: `src/descope_mgmt/api/descope_client.py`
- Create: `tests/unit/api/test_descope_client.py`

**Step 1: Write failing tests**

Create `tests/unit/api/test_descope_client.py`:
```python
"""Tests for Descope API client."""

from unittest.mock import Mock, patch

import pytest
import requests

from descope_mgmt.api.descope_client import DescopeClient
from descope_mgmt.types.exceptions import ApiError
from descope_mgmt.types.tenant import TenantConfig
from tests.fakes import FakeRateLimiter


@pytest.fixture
def fake_limiter() -> FakeRateLimiter:
    """Create fake rate limiter."""
    return FakeRateLimiter()


@pytest.fixture
def client(fake_limiter: FakeRateLimiter) -> DescopeClient:
    """Create Descope client with fake rate limiter."""
    return DescopeClient(
        project_id="P2test",
        management_key="K2secret",
        rate_limiter=fake_limiter
    )


def test_client_initialization(client: DescopeClient) -> None:
    """Test client initializes correctly."""
    assert client._project_id == "P2test"
    assert client._management_key == "K2secret"


@patch("requests.post")
def test_create_tenant_success(
    mock_post: Mock,
    client: DescopeClient,
    fake_limiter: FakeRateLimiter
) -> None:
    """Test successful tenant creation."""
    mock_response = Mock()
    mock_response.status_code = 200
    mock_response.json.return_value = {"id": "tenant-1", "name": "Test"}
    mock_post.return_value = mock_response

    tenant = TenantConfig(id="tenant-1", name="Test", domains=["test.com"])
    result = client.create_tenant(tenant)

    assert result["id"] == "tenant-1"
    assert fake_limiter.acquire_count == 1
    mock_post.assert_called_once()


@patch("requests.post")
def test_create_tenant_rate_limit_retry(
    mock_post: Mock,
    client: DescopeClient,
    fake_limiter: FakeRateLimiter
) -> None:
    """Test client retries on 429 rate limit."""
    # First call returns 429, second succeeds
    rate_limit_response = Mock()
    rate_limit_response.status_code = 429
    success_response = Mock()
    success_response.status_code = 200
    success_response.json.return_value = {"id": "tenant-1"}
    mock_post.side_effect = [rate_limit_response, success_response]

    tenant = TenantConfig(id="tenant-1", name="Test", domains=["test.com"])
    result = client.create_tenant(tenant)

    assert result["id"] == "tenant-1"
    assert mock_post.call_count == 2  # Initial + 1 retry


@patch("requests.post")
def test_create_tenant_max_retries_exceeded(
    mock_post: Mock,
    client: DescopeClient
) -> None:
    """Test client raises error after max retries."""
    mock_response = Mock()
    mock_response.status_code = 429
    mock_post.return_value = mock_response

    tenant = TenantConfig(id="tenant-1", name="Test", domains=["test.com"])

    with pytest.raises(ApiError, match="429"):
        client.create_tenant(tenant)

    assert mock_post.call_count == 5  # Max retries


@patch("requests.put")
def test_update_tenant(
    mock_put: Mock,
    client: DescopeClient,
    fake_limiter: FakeRateLimiter
) -> None:
    """Test tenant update."""
    mock_response = Mock()
    mock_response.status_code = 200
    mock_response.json.return_value = {"id": "tenant-1", "name": "Updated"}
    mock_put.return_value = mock_response

    tenant = TenantConfig(id="tenant-1", name="Updated", domains=["test.com"])
    result = client.update_tenant("tenant-1", tenant)

    assert result["name"] == "Updated"
    assert fake_limiter.acquire_count == 1


@patch("requests.delete")
def test_delete_tenant(
    mock_delete: Mock,
    client: DescopeClient,
    fake_limiter: FakeRateLimiter
) -> None:
    """Test tenant deletion."""
    mock_response = Mock()
    mock_response.status_code = 204
    mock_delete.return_value = mock_response

    client.delete_tenant("tenant-1")

    assert fake_limiter.acquire_count == 1
    mock_delete.assert_called_once()
```

**Step 2: Run tests (expect failure)**

```bash
pytest tests/unit/api/test_descope_client.py -v
```

Expected: All 6 tests FAIL

**Step 3: Implement DescopeClient**

Create `src/descope_mgmt/api/descope_client.py`:
```python
"""Descope API client with rate limiting and retry logic."""

import time
from typing import Any

import requests

from descope_mgmt.types.exceptions import ApiError
from descope_mgmt.types.protocols import RateLimiterProtocol
from descope_mgmt.types.tenant import TenantConfig


class DescopeClient:
    """Descope API client with rate limiting and exponential backoff retry.

    Retry logic lives here (HTTP concern) per validated design.
    Rate limiting is handled by RateLimiter protocol.
    """

    BASE_URL = "https://api.descope.com/v1"
    MAX_RETRIES = 5

    def __init__(
        self,
        project_id: str,
        management_key: str,
        rate_limiter: RateLimiterProtocol
    ) -> None:
        """Initialize Descope client.

        Args:
            project_id: Descope project ID
            management_key: Descope management API key
            rate_limiter: Rate limiter protocol implementation
        """
        self._project_id = project_id
        self._management_key = management_key
        self._rate_limiter = rate_limiter
        self._headers = {
            "Authorization": f"Bearer {project_id}:{management_key}",
            "Content-Type": "application/json",
        }

    def create_tenant(self, config: TenantConfig) -> dict[str, Any]:
        """Create a new tenant.

        Args:
            config: Tenant configuration

        Returns:
            API response dictionary

        Raises:
            ApiError: If API call fails after retries
        """
        return self._request_with_retry(
            method="POST",
            endpoint="/mgmt/tenant",
            data=config.model_dump()
        )

    def update_tenant(
        self,
        tenant_id: str,
        config: TenantConfig
    ) -> dict[str, Any]:
        """Update an existing tenant.

        Args:
            tenant_id: Tenant ID to update
            config: Updated tenant configuration

        Returns:
            API response dictionary

        Raises:
            ApiError: If API call fails after retries
        """
        return self._request_with_retry(
            method="PUT",
            endpoint=f"/mgmt/tenant/{tenant_id}",
            data=config.model_dump()
        )

    def delete_tenant(self, tenant_id: str) -> None:
        """Delete a tenant.

        Args:
            tenant_id: Tenant ID to delete

        Raises:
            ApiError: If API call fails after retries
        """
        self._request_with_retry(
            method="DELETE",
            endpoint=f"/mgmt/tenant/{tenant_id}"
        )

    def _request_with_retry(
        self,
        method: str,
        endpoint: str,
        data: dict[str, Any] | None = None
    ) -> dict[str, Any]:
        """Make HTTP request with exponential backoff retry.

        Args:
            method: HTTP method (GET, POST, PUT, DELETE)
            endpoint: API endpoint path
            data: Request body data

        Returns:
            Response JSON dictionary

        Raises:
            ApiError: If request fails after all retries
        """
        url = f"{self.BASE_URL}{endpoint}"

        for attempt in range(self.MAX_RETRIES):
            try:
                # Acquire rate limit permission BEFORE making request
                self._rate_limiter.acquire()

                # Make HTTP request
                response = requests.request(
                    method=method,
                    url=url,
                    headers=self._headers,
                    json=data,
                    timeout=30
                )

                # Handle rate limiting with exponential backoff
                if response.status_code == 429:
                    if attempt < self.MAX_RETRIES - 1:
                        sleep_time = 2 ** attempt  # 1s, 2s, 4s, 8s, 16s
                        time.sleep(sleep_time)
                        continue
                    else:
                        raise ApiError(
                            f"Rate limit exceeded after {self.MAX_RETRIES} retries",
                            status_code=429
                        )

                # Handle other HTTP errors
                if response.status_code >= 400:
                    raise ApiError(
                        f"API error: {response.status_code} - {response.text}",
                        status_code=response.status_code
                    )

                # Success (2xx status codes)
                if response.status_code == 204:
                    return {}  # No content
                return response.json()

            except requests.RequestException as e:
                if attempt == self.MAX_RETRIES - 1:
                    raise ApiError(f"Request failed after {self.MAX_RETRIES} attempts: {e}")
                sleep_time = 2 ** attempt
                time.sleep(sleep_time)

        # Should never reach here, but for type safety
        raise ApiError("Unexpected error in retry logic")
```

**Step 4: Run tests (expect pass)**

```bash
pytest tests/unit/api/test_descope_client.py -v
```

Expected: All 6 tests PASS

**Step 5: Commit**

```bash
git add src/descope_mgmt/api/descope_client.py tests/unit/api/test_descope_client.py
git commit -m "feat: add DescopeClient with retry logic and rate limiting"
```

---

## Task 2: Create FakeDescopeClient for Testing

**Files:**
- Modify: `tests/fakes.py`

**Step 1: Add FakeDescopeClient**

Append to `tests/fakes.py`:
```python
from descope_mgmt.types.tenant import TenantConfig


class FakeDescopeClient:
    """Fake Descope client for testing.

    Implements DescopeClientProtocol without actual API calls.
    Tracks calls for test verification.
    """

    def __init__(self) -> None:
        """Initialize fake client."""
        self.calls: list[dict[str, Any]] = []
        self.tenants: dict[str, dict[str, Any]] = {}

    def create_tenant(self, config: TenantConfig) -> dict[str, Any]:
        """Fake create tenant.

        Args:
            config: Tenant configuration

        Returns:
            Fake response
        """
        self.calls.append({"method": "create_tenant", "config": config})
        tenant_dict = config.model_dump()
        self.tenants[config.id] = tenant_dict
        return tenant_dict

    def update_tenant(
        self,
        tenant_id: str,
        config: TenantConfig
    ) -> dict[str, Any]:
        """Fake update tenant.

        Args:
            tenant_id: Tenant ID
            config: Updated configuration

        Returns:
            Fake response
        """
        self.calls.append({
            "method": "update_tenant",
            "tenant_id": tenant_id,
            "config": config
        })
        tenant_dict = config.model_dump()
        self.tenants[tenant_id] = tenant_dict
        return tenant_dict

    def delete_tenant(self, tenant_id: str) -> None:
        """Fake delete tenant.

        Args:
            tenant_id: Tenant ID
        """
        self.calls.append({"method": "delete_tenant", "tenant_id": tenant_id})
        if tenant_id in self.tenants:
            del self.tenants[tenant_id]


# Verify FakeDescopeClient implements protocol
from descope_mgmt.types.protocols import DescopeClientProtocol
assert isinstance(FakeDescopeClient(), DescopeClientProtocol)
```

**Step 2: Commit**

```bash
git add tests/fakes.py
git commit -m "feat: add FakeDescopeClient for domain layer testing"
```

---

## Task 3: Run All Week 1 Tests

**Step 1: Run complete test suite**

```bash
pytest tests/ -v --cov=src/descope_mgmt --cov-report=term-missing
```

Expected: All tests PASS with >85% coverage

**Step 2: Run mypy on entire codebase**

```bash
mypy src/
```

Expected: Success, no errors

**Step 3: Run import-linter**

```bash
lint-imports
```

Expected: All contracts validated, no violations

**Step 4: Run pre-commit on all files**

```bash
pre-commit run --all-files
```

Expected: All hooks pass

---

## Chunk Complete Checklist

- [ ] DescopeClient with retry logic (6 unit tests)
- [ ] FakeDescopeClient for testing
- [ ] All Week 1 tests passing (47+ total)
- [ ] Test coverage >85%
- [ ] mypy strict mode passes on entire codebase
- [ ] import-linter validates layer boundaries
- [ ] pre-commit hooks all pass
- [ ] 2 commits created
- [ ] Ready for chunk 12 (final chunk)
