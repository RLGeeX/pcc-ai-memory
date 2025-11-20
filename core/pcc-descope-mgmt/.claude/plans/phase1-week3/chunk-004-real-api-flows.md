# Chunk 4: Real Descope API - Flows

**Status:** pending
**Dependencies:** chunk-003-real-api-tenants
**Complexity:** medium
**Estimated Time:** 45 minutes
**Tasks:** 2

---

## Context

This chunk implements real Descope API calls for flow operations. Flow management involves working with JSON schemas representing authentication flow configurations (screens, actions, connectors).

**Descope Flow API Endpoints:**
- `GET /v1/mgmt/flow` - List all flows
- `GET /v1/mgmt/flow/export` - Export flow as JSON
- `POST /v1/mgmt/flow/import` - Import flow from JSON
- `POST /v1/mgmt/screen` - Deploy flow screen

---

## Task 1: Implement Real Flow API Methods

**Agent:** python-pro

**Files:**
- Modify: `src/descope_mgmt/api/descope_client.py:400-550` (flow methods)
- Modify: `tests/unit/api/test_descope_client.py` (add flow tests)

**Step 1: Write failing tests**

Add to `tests/unit/api/test_descope_client.py`:

```python
@responses.activate
def test_list_flows_success() -> None:
    """Test list_flows with successful API response."""
    responses.add(
        responses.GET,
        "https://api.descope.com/v1/mgmt/flow",
        json={"flows": [
            {"flow_id": "sign-up-or-in", "name": "Sign Up or In", "flow_type": "sign-up-or-in"},
            {"flow_id": "step-up", "name": "Step Up", "flow_type": "step-up"},
        ]},
        status=200,
    )

    rate_limiter = FakeRateLimiter()
    client = DescopeClient("P2test", "K2test", rate_limiter)

    flows = client.list_flows()

    assert len(flows) == 2
    assert flows[0].flow_id == "sign-up-or-in"


@responses.activate
def test_export_flow_success() -> None:
    """Test export_flow returns JSON schema."""
    flow_schema = {"screens": [], "interactions": []}
    responses.add(
        responses.GET,
        "https://api.descope.com/v1/mgmt/flow/export?flowId=sign-up-or-in",
        json=flow_schema,
        status=200,
    )

    rate_limiter = FakeRateLimiter()
    client = DescopeClient("P2test", "K2test", rate_limiter)

    schema = client.export_flow("sign-up-or-in")

    assert "screens" in schema
    assert "interactions" in schema


@responses.activate
def test_import_flow_success() -> None:
    """Test import_flow with valid JSON schema."""
    flow_schema = {"screens": [], "interactions": []}
    responses.add(
        responses.POST,
        "https://api.descope.com/v1/mgmt/flow/import",
        json={"status": "success"},
        status=200,
    )

    rate_limiter = FakeRateLimiter()
    client = DescopeClient("P2test", "K2test", rate_limiter)

    client.import_flow("sign-up-or-in", flow_schema)
    # Should not raise exception


@responses.activate
def test_deploy_screen_success() -> None:
    """Test deploy_screen creates flow screen."""
    responses.add(
        responses.POST,
        "https://api.descope.com/v1/mgmt/screen",
        json={"screen_id": "custom-screen"},
        status=201,
    )

    rate_limiter = FakeRateLimiter()
    client = DescopeClient("P2test", "K2test", rate_limiter)

    screen_id = client.deploy_screen("sign-up-or-in", "custom-screen")

    assert screen_id == "custom-screen"
```

**Step 2: Run tests to verify failure**

Run: `pytest tests/unit/api/test_descope_client.py::test_list_flows -v`
Expected: FAIL (methods not implemented yet)

**Step 3: Implement flow API methods**

Add to `src/descope_mgmt/api/descope_client.py`:

```python
from typing import Any


class DescopeClient:
    # ... existing tenant methods ...

    def list_flows(self) -> list[FlowConfig]:
        """List all authentication flows in the project.

        Returns:
            List of flow configurations

        Raises:
            ApiError: If API request fails
        """
        data = self._make_request("GET", "/flow")
        flow_dicts = data.get("flows", [])
        return [FlowConfig.model_validate(f) for f in flow_dicts]

    def export_flow(self, flow_id: str) -> dict[str, Any]:
        """Export flow as JSON schema.

        Args:
            flow_id: Flow identifier

        Returns:
            Flow JSON schema

        Raises:
            ApiError: If flow not found or export fails
        """
        data = self._make_request("GET", f"/flow/export?flowId={flow_id}")
        return data

    def import_flow(self, flow_id: str, schema: dict[str, Any]) -> None:
        """Import flow from JSON schema.

        Args:
            flow_id: Flow identifier
            schema: Flow JSON schema

        Raises:
            ApiError: If import fails
        """
        payload = {
            "flowId": flow_id,
            "flow": schema,
        }
        self._make_request("POST", "/flow/import", json_data=payload)

    def deploy_screen(self, flow_id: str, screen_id: str) -> str:
        """Deploy a screen for a flow.

        Args:
            flow_id: Flow identifier
            screen_id: Screen identifier

        Returns:
            Deployed screen ID

        Raises:
            ApiError: If deployment fails
        """
        payload = {
            "flowId": flow_id,
            "screenId": screen_id,
        }
        data = self._make_request("POST", "/screen", json_data=payload)
        return data["screen_id"]
```

**Step 4: Run tests to verify pass**

Run: `pytest tests/unit/api/test_descope_client.py::test_list_flows -v`
Expected: All flow tests PASS

**Step 5: Commit**

```bash
git add src/descope_mgmt/api/descope_client.py tests/unit/api/test_descope_client.py
git commit -m "feat: implement real Descope flow API methods

- Add list_flows, export_flow, import_flow, deploy_screen methods
- Handle JSON schema serialization for flow configurations
- Add comprehensive unit tests with mocked responses
- Complete real API integration (tenants + flows)"
```

---

## Task 2: Add Flow Integration Tests and Update Fakes

**Agent:** python-pro

**Files:**
- Create: `tests/integration/test_real_flow_api.py`
- Modify: `tests/fakes.py` (update FakeDescopeClient flow methods)

**Step 1: Create flow integration tests**

Create `tests/integration/test_real_flow_api.py`:

```python
"""Integration tests for real Descope flow API.

These tests require real Descope credentials:
- DESCOPE_TEST_PROJECT_ID
- DESCOPE_TEST_MANAGEMENT_KEY

Tests are skipped if credentials not provided.
"""

import os

import pytest

from descope_mgmt.api.client_factory import ClientFactory
from descope_mgmt.domain.flow_manager import FlowManager


# Skip all tests if credentials not available
pytestmark = pytest.mark.skipif(
    not os.getenv("DESCOPE_TEST_PROJECT_ID") or not os.getenv("DESCOPE_TEST_MANAGEMENT_KEY"),
    reason="Integration tests require DESCOPE_TEST_PROJECT_ID and DESCOPE_TEST_MANAGEMENT_KEY",
)


@pytest.mark.integration
def test_list_flows_real_api() -> None:
    """Test list_flows with real Descope API."""
    client = ClientFactory.create_client()
    manager = FlowManager(client)

    flows = manager.list_flows()

    # Should return a list (may be empty or have default flows)
    assert isinstance(flows, list)


@pytest.mark.integration
def test_export_and_import_flow_real_api() -> None:
    """Test flow export and import with real API."""
    client = ClientFactory.create_client()

    # List flows to get an existing flow ID
    flows = client.list_flows()
    if not flows:
        pytest.skip("No flows available in test project")

    flow_id = flows[0].flow_id

    # Export flow
    schema = client.export_flow(flow_id)
    assert isinstance(schema, dict)

    # Note: We don't test import here to avoid modifying real flows
    # Import would be: client.import_flow(flow_id, schema)
```

**Step 2: Update FakeDescopeClient flow methods**

Update `tests/fakes.py`:

```python
from typing import Any


class FakeDescopeClient:
    # ... existing tenant methods ...

    def list_flows(self) -> list[FlowConfig]:
        """Return all stored flows."""
        return list(self._flows.values())

    def export_flow(self, flow_id: str) -> dict[str, Any]:
        """Export flow as JSON schema.

        Raises:
            ApiError: If flow not found
        """
        if flow_id not in self._flows:
            raise ApiError(f"Flow not found: {flow_id}")

        # Return minimal valid flow schema
        return {
            "flow_id": flow_id,
            "screens": [],
            "interactions": [],
        }

    def import_flow(self, flow_id: str, schema: dict[str, Any]) -> None:
        """Import flow from JSON schema."""
        # Store flow configuration from schema
        flow_config = FlowConfig(
            flow_id=flow_id,
            name=schema.get("name", flow_id),
            flow_type="sign-up-or-in",  # Default type
        )
        self._flows[flow_id] = flow_config

    def deploy_screen(self, flow_id: str, screen_id: str) -> str:
        """Deploy screen (fake returns screen_id).

        Raises:
            ApiError: If flow not found
        """
        if flow_id not in self._flows:
            raise ApiError(f"Flow not found: {flow_id}")
        return screen_id
```

**Step 3: Run all tests**

Run: `pytest tests/ -v --cov=src/descope_mgmt`
Expected: All tests PASS

**Step 4: Commit**

```bash
git add tests/integration/test_real_flow_api.py tests/fakes.py
git commit -m "test: add flow integration tests and update fakes

- Create integration tests for real flow API operations
- Update FakeDescopeClient flow methods to match real behavior
- Add ApiError exceptions for not found scenarios
- Tests skip gracefully if credentials not provided"
```

---

## Chunk Complete Checklist

- [ ] Real flow API methods implemented (Task 1)
- [ ] Flow integration tests and fakes updated (Task 2)
- [ ] All tests passing (135+ total, +8 from chunk)
- [ ] Coverage ≥90%
- [ ] mypy, ruff, lint-imports passing
- [ ] 2 commits pushed

---

## Verification Commands

```bash
# Run unit tests
pytest tests/unit/api/test_descope_client.py -v

# Run flow integration tests (if credentials available)
export DESCOPE_TEST_PROJECT_ID="P2your-project-id"
export DESCOPE_TEST_MANAGEMENT_KEY="K2your-key"
pytest tests/integration/test_real_flow_api.py -v -m integration

# Quality checks
mypy src/
ruff check .
lint-imports
```

**Expected:** All tests pass, flow commands work with real API.
