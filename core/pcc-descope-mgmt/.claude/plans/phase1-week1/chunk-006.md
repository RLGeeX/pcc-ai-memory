# Chunk 6: API Layer - Descope Client

**Status:** pending
**Dependencies:** chunk-001, chunk-002, chunk-005
**Estimated Time:** 60-90 minutes

---

## Task 1: Create Retry Decorator with Exponential Backoff

**Files:**
- Create: `src/descope_mgmt/api/retry.py`
- Create: `tests/unit/api/test_retry.py`

**Step 1: Write failing tests**

Create `tests/unit/api/test_retry.py`:
```python
"""Tests for retry decorator"""
import pytest
import time
from unittest.mock import Mock
from descope_mgmt.api.retry import with_retry
from descope_mgmt.types.exceptions import RateLimitError, ApiError


def test_retry_succeeds_first_try():
    """Function that succeeds on first try should not retry"""
    mock_fn = Mock(return_value="success")
    decorated = with_retry(max_retries=3)(mock_fn)

    result = decorated()

    assert result == "success"
    assert mock_fn.call_count == 1


def test_retry_succeeds_after_failures():
    """Function should retry on transient failures"""
    mock_fn = Mock(side_effect=[
        RateLimitError("Rate limited", 429, {}),
        RateLimitError("Rate limited", 429, {}),
        "success"
    ])
    decorated = with_retry(max_retries=3, initial_delay=0.01)(mock_fn)

    result = decorated()

    assert result == "success"
    assert mock_fn.call_count == 3


def test_retry_exhausts_attempts():
    """Should raise after max retries exhausted"""
    mock_fn = Mock(side_effect=RateLimitError("Rate limited", 429, {}))
    decorated = with_retry(max_retries=2, initial_delay=0.01)(mock_fn)

    with pytest.raises(RateLimitError):
        decorated()

    # Should try 3 times total (initial + 2 retries)
    assert mock_fn.call_count == 3


def test_retry_exponential_backoff():
    """Should use exponential backoff between retries"""
    mock_fn = Mock(side_effect=[
        RateLimitError("Rate limited", 429, {}),
        RateLimitError("Rate limited", 429, {}),
        "success"
    ])
    decorated = with_retry(max_retries=3, initial_delay=0.1, backoff_factor=2.0)(mock_fn)

    start = time.time()
    result = decorated()
    duration = time.time() - start

    # Should wait: 0.1s + 0.2s = 0.3s minimum
    assert duration >= 0.3
    assert result == "success"


def test_retry_only_on_specific_exceptions():
    """Should only retry on RateLimitError, not other errors"""
    mock_fn = Mock(side_effect=ApiError("Server error", 500, {}))
    decorated = with_retry(max_retries=3, initial_delay=0.01)(mock_fn)

    # Should raise immediately, no retries
    with pytest.raises(ApiError):
        decorated()

    assert mock_fn.call_count == 1


def test_retry_with_args_kwargs():
    """Retry should preserve function arguments"""
    mock_fn = Mock(side_effect=[
        RateLimitError("Rate limited", 429, {}),
        "success"
    ])
    decorated = with_retry(max_retries=2, initial_delay=0.01)(mock_fn)

    result = decorated("arg1", kwarg1="value1")

    assert result == "success"
    # Verify args passed to all calls
    mock_fn.assert_called_with("arg1", kwarg1="value1")


def test_retry_max_delay():
    """Backoff should not exceed max_delay"""
    mock_fn = Mock(side_effect=[
        RateLimitError("Rate limited", 429, {}),
        RateLimitError("Rate limited", 429, {}),
        "success"
    ])
    decorated = with_retry(
        max_retries=3,
        initial_delay=1.0,
        backoff_factor=10.0,  # Would be huge without max_delay
        max_delay=0.2
    )(mock_fn)

    start = time.time()
    result = decorated()
    duration = time.time() - start

    # Should be capped at max_delay (0.2s × 2 retries = 0.4s)
    assert duration < 0.6  # Allow some overhead
    assert result == "success"
```

**Step 2: Run tests to verify they fail**

Run: `pytest tests/unit/api/test_retry.py -v`

Expected: FAIL with import errors

**Step 3: Implement retry decorator**

Create `src/descope_mgmt/api/retry.py`:
```python
"""Retry decorator with exponential backoff."""
import time
import functools
from typing import Callable, TypeVar, Any
from descope_mgmt.types.exceptions import RateLimitError
import structlog

logger = structlog.get_logger()

T = TypeVar('T')


def with_retry(
    max_retries: int = 5,
    initial_delay: float = 1.0,
    backoff_factor: float = 2.0,
    max_delay: float = 60.0
) -> Callable[[Callable[..., T]], Callable[..., T]]:
    """Decorator to retry function on RateLimitError with exponential backoff.

    Only retries on RateLimitError (429). Other exceptions are raised immediately.

    Args:
        max_retries: Maximum number of retries (default 5)
        initial_delay: Initial delay in seconds (default 1.0)
        backoff_factor: Multiplier for delay after each retry (default 2.0)
        max_delay: Maximum delay between retries (default 60.0)

    Example:
        >>> @with_retry(max_retries=3, initial_delay=1.0)
        ... def api_call():
        ...     return client.create_tenant(...)
    """
    def decorator(func: Callable[..., T]) -> Callable[..., T]:
        @functools.wraps(func)
        def wrapper(*args: Any, **kwargs: Any) -> T:
            delay = initial_delay
            last_exception = None

            for attempt in range(max_retries + 1):
                try:
                    return func(*args, **kwargs)
                except RateLimitError as e:
                    last_exception = e

                    if attempt < max_retries:
                        logger.warning(
                            "Rate limit hit, retrying",
                            attempt=attempt + 1,
                            max_retries=max_retries,
                            delay=delay,
                            function=func.__name__
                        )
                        time.sleep(delay)
                        # Exponential backoff, capped at max_delay
                        delay = min(delay * backoff_factor, max_delay)
                    else:
                        logger.error(
                            "Max retries exhausted",
                            max_retries=max_retries,
                            function=func.__name__
                        )
                        raise

            # Should never reach here, but satisfy type checker
            if last_exception:
                raise last_exception
            raise RuntimeError("Unexpected retry state")

        return wrapper
    return decorator
```

**Step 4: Run tests to verify they pass**

Run: `pytest tests/unit/api/test_retry.py -v`

Expected: PASS (all 8 tests)

**Step 5: Commit**

```bash
git add src/descope_mgmt/api/retry.py tests/unit/api/test_retry.py
git commit -m "feat: add retry decorator with exponential backoff"
```

---

## Task 2: Create DescopeApiClient Wrapper

**Files:**
- Create: `src/descope_mgmt/api/descope_client.py`
- Create: `tests/unit/api/test_descope_client.py`

**Step 1: Write failing tests**

Create `tests/unit/api/test_descope_client.py`:
```python
"""Tests for Descope API client wrapper"""
import pytest
from unittest.mock import Mock, MagicMock
from datetime import datetime
from descope_mgmt.api.descope_client import DescopeApiClient
from descope_mgmt.types.exceptions import (
    ApiError,
    RateLimitError,
    ResourceNotFoundError,
    AuthenticationError
)


@pytest.fixture
def mock_descope_sdk():
    """Mock Descope SDK"""
    sdk = Mock()
    sdk.mgmt = Mock()
    sdk.mgmt.tenant = Mock()
    return sdk


@pytest.fixture
def client(mock_descope_sdk):
    """DescopeApiClient with mocked SDK"""
    return DescopeApiClient(
        project_id="P2test123",
        management_key="K2testkey",
        _sdk=mock_descope_sdk
    )


def test_client_creation():
    """Client should initialize with credentials"""
    client = DescopeApiClient(
        project_id="P2test",
        management_key="K2key"
    )
    assert client._project_id == "P2test"


def test_load_tenant_success(client, mock_descope_sdk):
    """Should successfully load tenant"""
    # Mock SDK response
    mock_tenant = {
        "id": "acme-corp",
        "name": "Acme Corporation",
        "selfProvisioning": True,
        "domains": ["acme.com"],
        "customAttributes": {"plan": "enterprise"},
        "createdTime": 1699564800000,  # Milliseconds
        "updatedTime": 1699564800000
    }
    mock_descope_sdk.mgmt.tenant.load.return_value = mock_tenant

    # Load tenant
    result = client.load_tenant("acme-corp")

    # Verify result
    assert result.id == "acme-corp"
    assert result.name == "Acme Corporation"
    assert result.self_provisioning is True
    assert result.domains == ["acme.com"]
    assert isinstance(result.created_at, datetime)

    # Verify SDK called
    mock_descope_sdk.mgmt.tenant.load.assert_called_once_with("acme-corp")


def test_load_tenant_not_found(client, mock_descope_sdk):
    """Should raise ResourceNotFoundError for 404"""
    from descope import AuthException

    mock_descope_sdk.mgmt.tenant.load.side_effect = AuthException(
        404,
        "not_found",
        "Tenant not found"
    )

    with pytest.raises(ResourceNotFoundError) as exc_info:
        client.load_tenant("nonexistent")

    assert exc_info.value.status_code == 404


def test_create_tenant_success(client, mock_descope_sdk):
    """Should successfully create tenant"""
    mock_tenant = {
        "id": "widget-co",
        "name": "Widget Co",
        "selfProvisioning": False,
        "domains": [],
        "customAttributes": {},
        "createdTime": 1699564800000,
        "updatedTime": 1699564800000
    }
    mock_descope_sdk.mgmt.tenant.create.return_value = mock_tenant

    result = client.create_tenant(
        tenant_id="widget-co",
        name="Widget Co",
        domains=[],
        self_provisioning=False,
        custom_attributes={}
    )

    assert result.id == "widget-co"
    assert result.name == "Widget Co"


def test_create_tenant_rate_limited(client, mock_descope_sdk):
    """Should raise RateLimitError for 429"""
    from descope import AuthException

    mock_descope_sdk.mgmt.tenant.create.side_effect = AuthException(
        429,
        "rate_limit_exceeded",
        "Too many requests"
    )

    with pytest.raises(RateLimitError) as exc_info:
        client.create_tenant(
            tenant_id="test",
            name="Test",
            domains=[],
            self_provisioning=False,
            custom_attributes={}
        )

    assert exc_info.value.status_code == 429


def test_update_tenant_success(client, mock_descope_sdk):
    """Should successfully update tenant"""
    mock_tenant = {
        "id": "acme-corp",
        "name": "Acme Corporation Updated",
        "selfProvisioning": True,
        "domains": ["acme.com", "acme.net"],
        "customAttributes": {},
        "createdTime": 1699564800000,
        "updatedTime": 1699651200000
    }
    mock_descope_sdk.mgmt.tenant.update.return_value = mock_tenant

    result = client.update_tenant(
        tenant_id="acme-corp",
        name="Acme Corporation Updated",
        domains=["acme.com", "acme.net"]
    )

    assert result.name == "Acme Corporation Updated"
    assert len(result.domains) == 2


def test_delete_tenant_success(client, mock_descope_sdk):
    """Should successfully delete tenant"""
    mock_descope_sdk.mgmt.tenant.delete.return_value = None

    # Should not raise
    client.delete_tenant("acme-corp")

    mock_descope_sdk.mgmt.tenant.delete.assert_called_once_with("acme-corp")


def test_list_tenants_success(client, mock_descope_sdk):
    """Should successfully list all tenants"""
    mock_tenants = [
        {
            "id": "tenant1",
            "name": "Tenant 1",
            "selfProvisioning": False,
            "domains": [],
            "customAttributes": {},
            "createdTime": 1699564800000,
            "updatedTime": 1699564800000
        },
        {
            "id": "tenant2",
            "name": "Tenant 2",
            "selfProvisioning": True,
            "domains": ["example.com"],
            "customAttributes": {},
            "createdTime": 1699564800000,
            "updatedTime": 1699564800000
        }
    ]
    mock_descope_sdk.mgmt.tenant.load_all.return_value = mock_tenants

    result = client.list_tenants()

    assert len(result) == 2
    assert result[0].id == "tenant1"
    assert result[1].id == "tenant2"


def test_authentication_error(client, mock_descope_sdk):
    """Should raise AuthenticationError for 401/403"""
    from descope import AuthException

    mock_descope_sdk.mgmt.tenant.load.side_effect = AuthException(
        401,
        "unauthorized",
        "Invalid credentials"
    )

    with pytest.raises(AuthenticationError) as exc_info:
        client.load_tenant("test")

    assert exc_info.value.status_code == 401
```

**Step 2: Run tests to verify they fail**

Run: `pytest tests/unit/api/test_descope_client.py -v`

Expected: FAIL with import errors

**Step 3: Implement DescopeApiClient**

Create `src/descope_mgmt/api/descope_client.py`:
```python
"""Descope API client wrapper with error handling and retry logic."""
from datetime import datetime
from typing import Any
from descope import DescopeClient as DescopeSdk, AuthException
from descope_mgmt.api.retry import with_retry
from descope_mgmt.types.protocols import TenantData
from descope_mgmt.types.exceptions import (
    ApiError,
    RateLimitError,
    ResourceNotFoundError,
    AuthenticationError,
)
from dataclasses import dataclass
import structlog

logger = structlog.get_logger()


@dataclass(frozen=True)
class TenantDataImpl:
    """Implementation of TenantData protocol"""
    id: str
    name: str
    self_provisioning: bool
    domains: list[str]
    custom_attributes: dict[str, Any]
    created_at: datetime
    updated_at: datetime


class DescopeApiClient:
    """Wrapper for Descope SDK with error handling and retry logic.

    Example:
        >>> client = DescopeApiClient(
        ...     project_id="P2abc123",
        ...     management_key="K2xyz789"
        ... )
        >>> tenant = client.load_tenant("acme-corp")
    """

    def __init__(
        self,
        project_id: str,
        management_key: str,
        _sdk: Any = None  # For testing
    ):
        """Initialize Descope API client.

        Args:
            project_id: Descope project ID
            management_key: Descope management API key
            _sdk: Optional SDK override for testing
        """
        self._project_id = project_id
        self._management_key = management_key

        if _sdk is not None:
            self._sdk = _sdk
        else:
            self._sdk = DescopeSdk(project_id=project_id, management_key=management_key)

        logger.info("Descope API client initialized", project_id=project_id)

    @with_retry(max_retries=5, initial_delay=1.0)
    def load_tenant(self, tenant_id: str) -> TenantData:
        """Load a tenant by ID.

        Args:
            tenant_id: Tenant ID to load

        Returns:
            TenantData with tenant information

        Raises:
            ResourceNotFoundError: If tenant not found (404)
            AuthenticationError: If authentication fails (401/403)
            RateLimitError: If rate limited (429)
            ApiError: For other API errors
        """
        try:
            logger.debug("Loading tenant", tenant_id=tenant_id)
            result = self._sdk.mgmt.tenant.load(tenant_id)
            return self._parse_tenant(result)
        except AuthException as e:
            raise self._translate_exception(e)

    @with_retry(max_retries=5, initial_delay=1.0)
    def create_tenant(
        self,
        tenant_id: str,
        name: str,
        domains: list[str],
        self_provisioning: bool,
        custom_attributes: dict[str, Any]
    ) -> TenantData:
        """Create a new tenant.

        Args:
            tenant_id: Unique tenant ID
            name: Tenant display name
            domains: List of domains for tenant
            self_provisioning: Enable self-service provisioning
            custom_attributes: Custom metadata

        Returns:
            Created TenantData

        Raises:
            RateLimitError: If rate limited (429)
            ApiError: For other errors
        """
        try:
            logger.info("Creating tenant", tenant_id=tenant_id, name=name)
            result = self._sdk.mgmt.tenant.create(
                tenant_id=tenant_id,
                name=name,
                self_provisioning=self_provisioning,
                domains=domains,
                custom_attributes=custom_attributes
            )
            return self._parse_tenant(result)
        except AuthException as e:
            raise self._translate_exception(e)

    @with_retry(max_retries=5, initial_delay=1.0)
    def update_tenant(
        self,
        tenant_id: str,
        name: str | None = None,
        domains: list[str] | None = None,
        self_provisioning: bool | None = None,
        custom_attributes: dict[str, Any] | None = None
    ) -> TenantData:
        """Update an existing tenant.

        Args:
            tenant_id: Tenant ID to update
            name: New name (optional)
            domains: New domains (optional)
            self_provisioning: New self-provisioning setting (optional)
            custom_attributes: New custom attributes (optional)

        Returns:
            Updated TenantData

        Raises:
            ResourceNotFoundError: If tenant not found
            RateLimitError: If rate limited
            ApiError: For other errors
        """
        try:
            logger.info("Updating tenant", tenant_id=tenant_id)
            result = self._sdk.mgmt.tenant.update(
                tenant_id=tenant_id,
                name=name,
                self_provisioning=self_provisioning,
                domains=domains,
                custom_attributes=custom_attributes
            )
            return self._parse_tenant(result)
        except AuthException as e:
            raise self._translate_exception(e)

    @with_retry(max_retries=5, initial_delay=1.0)
    def delete_tenant(self, tenant_id: str) -> None:
        """Delete a tenant.

        Args:
            tenant_id: Tenant ID to delete

        Raises:
            ResourceNotFoundError: If tenant not found
            RateLimitError: If rate limited
            ApiError: For other errors
        """
        try:
            logger.warning("Deleting tenant", tenant_id=tenant_id)
            self._sdk.mgmt.tenant.delete(tenant_id)
        except AuthException as e:
            raise self._translate_exception(e)

    @with_retry(max_retries=5, initial_delay=1.0)
    def list_tenants(self) -> list[TenantData]:
        """List all tenants in the project.

        Returns:
            List of TenantData

        Raises:
            RateLimitError: If rate limited
            ApiError: For other errors
        """
        try:
            logger.debug("Listing all tenants")
            results = self._sdk.mgmt.tenant.load_all()
            return [self._parse_tenant(t) for t in results]
        except AuthException as e:
            raise self._translate_exception(e)

    def _parse_tenant(self, data: dict[str, Any]) -> TenantData:
        """Parse tenant data from SDK response."""
        return TenantDataImpl(
            id=data["id"],
            name=data["name"],
            self_provisioning=data.get("selfProvisioning", False),
            domains=data.get("domains", []),
            custom_attributes=data.get("customAttributes", {}),
            created_at=datetime.fromtimestamp(data["createdTime"] / 1000),
            updated_at=datetime.fromtimestamp(data["updatedTime"] / 1000)
        )

    def _translate_exception(self, exc: AuthException) -> ApiError:
        """Translate Descope SDK exception to domain exception."""
        status_code = exc.status_code
        error_code = exc.error_code
        message = exc.error_message

        if status_code == 429:
            return RateLimitError(message, status_code, {"error_code": error_code})
        elif status_code == 404:
            return ResourceNotFoundError(message, status_code, {"error_code": error_code})
        elif status_code in (401, 403):
            return AuthenticationError(message, status_code, {"error_code": error_code})
        else:
            return ApiError(message, status_code, {"error_code": error_code})
```

**Step 4: Run tests to verify they pass**

Run: `pytest tests/unit/api/test_descope_client.py -v`

Expected: PASS (all 10 tests)

**Step 5: Commit**

```bash
git add src/descope_mgmt/api/descope_client.py tests/unit/api/test_descope_client.py
git commit -m "feat: add Descope API client wrapper with error handling"
```

---

## Task 3: Update API Module Exports

**Files:**
- Modify: `src/descope_mgmt/api/__init__.py`

**Step 1: Export API components**

Update `src/descope_mgmt/api/__init__.py`:
```python
"""API layer for Descope SDK integration."""
from descope_mgmt.api.descope_client import DescopeApiClient
from descope_mgmt.api.rate_limit import (
    DescopeRateLimiter,
    TenantRateLimiter,
    UserRateLimiter,
)
from descope_mgmt.api.retry import with_retry

__all__ = [
    "DescopeApiClient",
    "DescopeRateLimiter",
    "TenantRateLimiter",
    "UserRateLimiter",
    "with_retry",
]
```

**Step 2: Commit**

```bash
git add src/descope_mgmt/api/__init__.py
git commit -m "feat: export API components from api module"
```

---

## Task 4: Run Full Test Suite

**Files:**
- None (testing only)

**Step 1: Run all unit tests**

Run: `pytest tests/unit/ -v --cov=src/descope_mgmt`

Expected: 40+ tests passing, >80% coverage

**Step 2: Run mypy type checking**

Run: `mypy src/`

Expected: SUCCESS (no type errors)

**Step 3: Run ruff formatting and linting**

Run: `ruff format . && ruff check .`

Expected: All files formatted, no lint errors

**Step 4: Verify pre-commit hooks work**

Run: `pre-commit run --all-files`

Expected: All hooks pass (or run successfully)

**Step 5: Create summary commit**

```bash
git add -A
git commit -m "chore: phase 1 week 1 complete - 40+ tests passing" --allow-empty
```

---

## Chunk Complete Checklist

- [ ] Retry decorator with exponential backoff (8 tests)
- [ ] DescopeApiClient with SDK wrapper (10 tests)
- [ ] Error translation (SDK → domain exceptions)
- [ ] API module exports configured
- [ ] Full test suite passing (40+ tests total)
- [ ] mypy type checking passes
- [ ] ruff formatting/linting passes
- [ ] Pre-commit hooks working
- [ ] All commits made
- [ ] **Phase 1 Week 1 COMPLETE**
