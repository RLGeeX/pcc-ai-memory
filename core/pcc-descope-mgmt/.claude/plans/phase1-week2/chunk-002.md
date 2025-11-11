# Chunk 2: State Models (TenantState, ProjectState)

**Status:** pending
**Dependencies:** chunk-001
**Estimated Time:** 45-60 minutes

---

## Task 1: Create TenantState Model

**Files:**
- Create: `src/descope_mgmt/domain/models/state.py`
- Create: `tests/unit/domain/test_state_models.py`

**Step 1: Write failing tests**

Create `tests/unit/domain/test_state_models.py`:
```python
"""Tests for state models"""
import pytest
from datetime import datetime
from descope_mgmt.domain.models.state import TenantState, ProjectState


def test_tenant_state_creation():
    """TenantState should be created from API data"""
    state = TenantState(
        id="acme-corp",
        name="Acme Corporation",
        domains=["acme.com"],
        self_provisioning=True,
        custom_attributes={"plan": "enterprise"},
        created_at=datetime.now(),
        updated_at=datetime.now()
    )
    assert state.id == "acme-corp"
    assert state.name == "Acme Corporation"


def test_tenant_state_immutable():
    """TenantState should be frozen"""
    state = TenantState(
        id="acme-corp",
        name="Acme",
        domains=[],
        self_provisioning=False,
        custom_attributes={},
        created_at=datetime.now(),
        updated_at=datetime.now()
    )
    with pytest.raises(Exception):  # FrozenInstanceError or similar
        state.name = "New Name"  # type: ignore


def test_project_state_creation():
    """ProjectState should hold all tenants"""
    now = datetime.now()
    tenant1 = TenantState(
        id="tenant1",
        name="Tenant 1",
        domains=[],
        self_provisioning=False,
        custom_attributes={},
        created_at=now,
        updated_at=now
    )
    tenant2 = TenantState(
        id="tenant2",
        name="Tenant 2",
        domains=[],
        self_provisioning=True,
        custom_attributes={},
        created_at=now,
        updated_at=now
    )

    state = ProjectState(
        project_id="P2abc123",
        tenants={"tenant1": tenant1, "tenant2": tenant2},
        flows={},
        fetched_at=now
    )

    assert state.project_id == "P2abc123"
    assert len(state.tenants) == 2
    assert "tenant1" in state.tenants
    assert "tenant2" in state.tenants
```

**Step 2: Run tests to verify they fail**

Run: `pytest tests/unit/domain/test_state_models.py -v`

Expected: FAIL with import errors

**Step 3: Implement state models**

Create `src/descope_mgmt/domain/models/state.py`:
```python
"""State models representing current Descope state.

These models capture the actual state from Descope API,
as opposed to config models which represent desired state.
"""
from dataclasses import dataclass
from datetime import datetime
from typing import Any


@dataclass(frozen=True)
class TenantState:
    """Current state of a tenant in Descope.

    This represents what actually exists in Descope,
    fetched from the API.
    """
    id: str
    name: str
    domains: list[str]
    self_provisioning: bool
    custom_attributes: dict[str, Any]
    created_at: datetime
    updated_at: datetime


@dataclass(frozen=True)
class FlowState:
    """Current state of a flow in Descope."""
    id: str
    name: str
    enabled: bool
    config: dict[str, Any]


@dataclass(frozen=True)
class ProjectState:
    """Current state of entire Descope project.

    Snapshot of all resources at a point in time.
    """
    project_id: str
    tenants: dict[str, TenantState]  # Keyed by tenant ID
    flows: dict[str, FlowState]  # Keyed by flow ID
    fetched_at: datetime
```

**Step 4: Run tests to verify they pass**

Run: `pytest tests/unit/domain/test_state_models.py -v`

Expected: PASS (all 3 tests)

**Step 5: Commit**

```bash
git add src/descope_mgmt/domain/models/state.py tests/unit/domain/test_state_models.py
git commit -m "feat: add state models for representing current Descope state"
```

---

## Task 2: Create State Fetcher Service

**Files:**
- Create: `src/descope_mgmt/domain/services/state_fetcher.py`
- Create: `tests/unit/domain/test_state_fetcher.py`

**Step 1: Write failing tests**

Create `tests/unit/domain/test_state_fetcher.py`:
```python
"""Tests for state fetcher service"""
import pytest
from unittest.mock import Mock
from datetime import datetime
from descope_mgmt.domain.services.state_fetcher import StateFetcher
from descope_mgmt.domain.models.state import TenantState


@pytest.fixture
def mock_client():
    """Mock Descope API client"""
    client = Mock()
    return client


def test_fetch_current_state(mock_client):
    """Should fetch current state from API"""
    # Mock API response
    tenant_data = Mock()
    tenant_data.id = "acme-corp"
    tenant_data.name = "Acme Corporation"
    tenant_data.domains = ["acme.com"]
    tenant_data.self_provisioning = True
    tenant_data.custom_attributes = {}
    tenant_data.created_at = datetime.now()
    tenant_data.updated_at = datetime.now()

    mock_client.list_tenants.return_value = [tenant_data]

    fetcher = StateFetcher(mock_client, project_id="P2abc123")
    state = fetcher.fetch_current_state()

    assert state.project_id == "P2abc123"
    assert len(state.tenants) == 1
    assert "acme-corp" in state.tenants
    assert isinstance(state.tenants["acme-corp"], TenantState)


def test_fetch_empty_state(mock_client):
    """Should handle empty project"""
    mock_client.list_tenants.return_value = []

    fetcher = StateFetcher(mock_client, project_id="P2empty")
    state = fetcher.fetch_current_state()

    assert state.project_id == "P2empty"
    assert len(state.tenants) == 0
```

**Step 2: Run tests to verify they fail**

Run: `pytest tests/unit/domain/test_state_fetcher.py -v`

Expected: FAIL with import errors

**Step 3: Implement state fetcher**

Create `src/descope_mgmt/domain/services/state_fetcher.py`:
```python
"""Service for fetching current state from Descope API."""
from datetime import datetime
from descope_mgmt.types.protocols import DescopeClient
from descope_mgmt.domain.models.state import ProjectState, TenantState, FlowState
import structlog

logger = structlog.get_logger()


class StateFetcher:
    """Fetches current state from Descope API.

    Example:
        >>> fetcher = StateFetcher(client, project_id="P2abc123")
        >>> state = fetcher.fetch_current_state()
        >>> print(f"Found {len(state.tenants)} tenants")
    """

    def __init__(self, client: DescopeClient, project_id: str):
        """Initialize state fetcher.

        Args:
            client: Descope API client
            project_id: Descope project ID
        """
        self._client = client
        self._project_id = project_id

    def fetch_current_state(self) -> ProjectState:
        """Fetch current state of all resources from Descope.

        Returns:
            ProjectState snapshot

        Raises:
            ApiError: If API call fails
        """
        logger.info("Fetching current state", project_id=self._project_id)

        # Fetch all tenants
        tenant_data = self._client.list_tenants()
        tenants = {
            t.id: TenantState(
                id=t.id,
                name=t.name,
                domains=t.domains,
                self_provisioning=t.self_provisioning,
                custom_attributes=t.custom_attributes,
                created_at=t.created_at,
                updated_at=t.updated_at
            )
            for t in tenant_data
        }

        # TODO: Fetch flows (Phase 3)
        flows: dict[str, FlowState] = {}

        fetched_at = datetime.now()

        logger.info(
            "Current state fetched",
            tenants=len(tenants),
            flows=len(flows)
        )

        return ProjectState(
            project_id=self._project_id,
            tenants=tenants,
            flows=flows,
            fetched_at=fetched_at
        )
```

**Step 4: Run tests to verify they pass**

Run: `pytest tests/unit/domain/test_state_fetcher.py -v`

Expected: PASS (all 2 tests)

**Step 5: Commit**

```bash
git add src/descope_mgmt/domain/services/state_fetcher.py tests/unit/domain/test_state_fetcher.py
git commit -m "feat: add state fetcher service for retrieving current Descope state"
```

---

## Chunk Complete Checklist

- [ ] TenantState model (3 tests)
- [ ] FlowState model
- [ ] ProjectState model
- [ ] StateFetcher service (2 tests)
- [ ] Total: 5 tests passing
- [ ] All state models are frozen (immutable)
- [ ] All commits made
