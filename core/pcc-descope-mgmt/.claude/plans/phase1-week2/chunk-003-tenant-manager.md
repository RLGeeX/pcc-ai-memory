# Chunk 3: Tenant Manager Service

**Status:** pending
**Dependencies:** chunk-002-tenant-list
**Complexity:** medium
**Estimated Time:** 45 minutes
**Tasks:** 3

---

## Task 1: Create TenantManager Service

**Files:**
- Create: `src/descope_mgmt/domain/tenant_manager.py`
- Test: `tests/unit/domain/test_tenant_manager.py`

**Step 1: Write the failing tests**

Create `tests/unit/domain/test_tenant_manager.py`:
```python
"""Tests for TenantManager service."""

import pytest

from descope_mgmt.domain.tenant_manager import TenantManager
from descope_mgmt.types.exceptions import DescopeApiError
from descope_mgmt.types.tenant import TenantConfig
from tests.fakes import FakeDescopeClient


def test_list_tenants_returns_all_tenants() -> None:
    """Test that list_tenants returns all tenants from API."""
    client = FakeDescopeClient()
    manager = TenantManager(client)

    # FakeDescopeClient starts with empty state
    tenants = manager.list_tenants()
    assert len(tenants) == 0


def test_list_tenants_with_data() -> None:
    """Test list_tenants returns populated data."""
    client = FakeDescopeClient()
    tenant_config = TenantConfig(id="test-tenant", name="Test Tenant")
    client.create_tenant(tenant_config)

    manager = TenantManager(client)
    tenants = manager.list_tenants()

    assert len(tenants) == 1
    assert tenants[0].id == "test-tenant"
    assert tenants[0].name == "Test Tenant"


def test_get_tenant_by_id() -> None:
    """Test get_tenant retrieves specific tenant."""
    client = FakeDescopeClient()
    tenant_config = TenantConfig(id="test-tenant", name="Test Tenant")
    client.create_tenant(tenant_config)

    manager = TenantManager(client)
    tenant = manager.get_tenant("test-tenant")

    assert tenant is not None
    assert tenant.id == "test-tenant"


def test_get_tenant_not_found() -> None:
    """Test get_tenant returns None for missing tenant."""
    client = FakeDescopeClient()
    manager = TenantManager(client)

    tenant = manager.get_tenant("nonexistent")
    assert tenant is None
```

**Step 2: Run tests to verify they fail**

```bash
pytest tests/unit/domain/test_tenant_manager.py -v
```
Expected: FAIL with "No module named 'descope_mgmt.domain.tenant_manager'"

**Step 3: Write minimal implementation**

Create `src/descope_mgmt/domain/tenant_manager.py`:
```python
"""Tenant management service."""

from descope_mgmt.types.protocols import DescopeClientProtocol
from descope_mgmt.types.tenant import TenantConfig


class TenantManager:
    """Service for managing Descope tenants."""

    def __init__(self, client: DescopeClientProtocol) -> None:
        """Initialize TenantManager.

        Args:
            client: Descope API client
        """
        self._client = client

    def list_tenants(self) -> list[TenantConfig]:
        """List all tenants in the project.

        Returns:
            List of tenant configurations
        """
        return self._client.list_tenants()

    def get_tenant(self, tenant_id: str) -> TenantConfig | None:
        """Get a specific tenant by ID.

        Args:
            tenant_id: Tenant ID to retrieve

        Returns:
            Tenant configuration or None if not found
        """
        return self._client.get_tenant(tenant_id)
```

**Step 4: Run tests to verify they pass**

```bash
pytest tests/unit/domain/test_tenant_manager.py -v
```
Expected: PASS (4 tests)

**Step 5: Commit**

```bash
git add src/descope_mgmt/domain/tenant_manager.py tests/unit/domain/test_tenant_manager.py
git commit -m "feat: add TenantManager service for tenant operations"
```

---

## Task 2: Add Create and Update Methods

**Files:**
- Modify: `src/descope_mgmt/domain/tenant_manager.py`
- Modify: `tests/unit/domain/test_tenant_manager.py`

**Step 1: Write failing tests**

Add to `tests/unit/domain/test_tenant_manager.py`:
```python
def test_create_tenant() -> None:
    """Test create_tenant creates new tenant."""
    client = FakeDescopeClient()
    manager = TenantManager(client)

    tenant_config = TenantConfig(id="new-tenant", name="New Tenant")
    result = manager.create_tenant(tenant_config)

    assert result.id == "new-tenant"
    assert len(manager.list_tenants()) == 1


def test_update_tenant() -> None:
    """Test update_tenant modifies existing tenant."""
    client = FakeDescopeClient()
    tenant_config = TenantConfig(id="test-tenant", name="Test Tenant")
    client.create_tenant(tenant_config)

    manager = TenantManager(client)

    updated = TenantConfig(id="test-tenant", name="Updated Name")
    result = manager.update_tenant(updated)

    assert result.name == "Updated Name"
```

**Step 2: Run tests to verify they fail**

```bash
pytest tests/unit/domain/test_tenant_manager.py::test_create_tenant -v
pytest tests/unit/domain/test_tenant_manager.py::test_update_tenant -v
```
Expected: FAIL with "AttributeError: 'TenantManager' object has no attribute 'create_tenant'"

**Step 3: Implement methods**

Add to `src/descope_mgmt/domain/tenant_manager.py`:
```python
    def create_tenant(self, tenant: TenantConfig) -> TenantConfig:
        """Create a new tenant.

        Args:
            tenant: Tenant configuration

        Returns:
            Created tenant configuration

        Raises:
            DescopeApiError: If creation fails
        """
        return self._client.create_tenant(tenant)

    def update_tenant(self, tenant: TenantConfig) -> TenantConfig:
        """Update an existing tenant.

        Args:
            tenant: Updated tenant configuration

        Returns:
            Updated tenant configuration

        Raises:
            DescopeApiError: If update fails
        """
        return self._client.update_tenant(tenant)
```

**Step 4: Run tests to verify they pass**

```bash
pytest tests/unit/domain/test_tenant_manager.py -v
```
Expected: PASS (6 tests)

**Step 5: Commit**

```bash
git add src/descope_mgmt/domain/tenant_manager.py tests/unit/domain/test_tenant_manager.py
git commit -m "feat: add create and update methods to TenantManager"
```

---

## Task 3: Add Delete Method

**Files:**
- Modify: `src/descope_mgmt/domain/tenant_manager.py`
- Modify: `tests/unit/domain/test_tenant_manager.py`

**Step 1: Write failing tests**

Add to `tests/unit/domain/test_tenant_manager.py`:
```python
def test_delete_tenant() -> None:
    """Test delete_tenant removes tenant."""
    client = FakeDescopeClient()
    tenant_config = TenantConfig(id="test-tenant", name="Test Tenant")
    client.create_tenant(tenant_config)

    manager = TenantManager(client)
    manager.delete_tenant("test-tenant")

    assert len(manager.list_tenants()) == 0


def test_delete_nonexistent_tenant_raises_error() -> None:
    """Test deleting nonexistent tenant raises error."""
    client = FakeDescopeClient()
    manager = TenantManager(client)

    with pytest.raises(DescopeApiError):
        manager.delete_tenant("nonexistent")
```

**Step 2: Run tests to verify they fail**

```bash
pytest tests/unit/domain/test_tenant_manager.py::test_delete_tenant -v
pytest tests/unit/domain/test_tenant_manager.py::test_delete_nonexistent_tenant_raises_error -v
```
Expected: FAIL with AttributeError

**Step 3: Implement delete method**

Add to `src/descope_mgmt/domain/tenant_manager.py`:
```python
    def delete_tenant(self, tenant_id: str) -> None:
        """Delete a tenant.

        Args:
            tenant_id: ID of tenant to delete

        Raises:
            DescopeApiError: If deletion fails or tenant not found
        """
        self._client.delete_tenant(tenant_id)
```

**Step 4: Run tests to verify they pass**

```bash
pytest tests/unit/domain/test_tenant_manager.py -v
```
Expected: PASS (8 tests)

**Step 5: Run full test suite**

```bash
pytest tests/ -v --cov=src/descope_mgmt --cov-report=term-missing
```
Expected: All tests pass (77+ tests), coverage >90%

**Step 6: Commit**

```bash
git add src/descope_mgmt/domain/tenant_manager.py tests/unit/domain/test_tenant_manager.py
git commit -m "feat: add delete method to TenantManager"
```

---

## Chunk Complete Checklist

- [ ] TenantManager service created
- [ ] List, get, create, update, delete methods implemented
- [ ] 8 comprehensive tests passing
- [ ] All tests passing (77+ tests)
- [ ] 3 commits created
- [ ] Ready for chunk 4 (tenant create command)
