# Chunk 2: Flow API Wrapper

**Status:** pending
**Dependencies:** chunk-001
**Estimated Time:** 60 minutes

---

## Task 1: Extend DescopeApiClient for Flows

**Files:**
- Modify: `src/descope_mgmt/api/descope_client.py`
- Create: `tests/unit/api/test_flow_api.py`

**Step 1: Write failing tests**

Create `tests/unit/api/test_flow_api.py`:
```python
"""Tests for flow API methods"""
import pytest
from unittest.mock import Mock, patch
from descope_mgmt.api.descope_client import DescopeApiClient


@patch('descope_mgmt.api.descope_client.DescopeClient')
def test_list_flows(mock_descope_class):
    """Should list all flows"""
    mock_sdk = Mock()
    mock_sdk.mgmt.flow.list_flows.return_value = [
        Mock(flow_id="flow1", name="Flow 1"),
        Mock(flow_id="flow2", name="Flow 2")
    ]
    mock_descope_class.return_value = mock_sdk

    client = DescopeApiClient("P2test", "K2key")
    flows = client.list_flows()

    assert len(flows) == 2
    assert flows[0].flow_id == "flow1"


@patch('descope_mgmt.api.descope_client.DescopeClient')
def test_get_flow(mock_descope_class):
    """Should get specific flow"""
    mock_sdk = Mock()
    mock_flow = Mock(flow_id="flow1", screens=[])
    mock_sdk.mgmt.flow.export_flow.return_value = mock_flow
    mock_descope_class.return_value = mock_sdk

    client = DescopeApiClient("P2test", "K2key")
    flow = client.get_flow("flow1")

    assert flow.flow_id == "flow1"
```

**Step 2: Implement flow methods**

Modify `src/descope_mgmt/api/descope_client.py`:
```python
# Add flow methods to DescopeApiClient class

    def list_flows(self) -> list:
        """List all flows in project."""
        try:
            return self._client.mgmt.flow.list_flows()
        except Exception as e:
            raise ApiError(f"Failed to list flows: {e}") from e

    def get_flow(self, flow_id: str) -> Any:
        """Get flow by ID."""
        try:
            return self._client.mgmt.flow.export_flow(flow_id)
        except Exception as e:
            raise ApiError(f"Failed to get flow {flow_id}: {e}") from e

    def create_flow(self, flow_id: str, flow_data: dict) -> None:
        """Create new flow."""
        try:
            self._client.mgmt.flow.import_flow(flow_id, flow_data)
        except Exception as e:
            raise ApiError(f"Failed to create flow {flow_id}: {e}") from e

    def update_flow(self, flow_id: str, flow_data: dict) -> None:
        """Update existing flow."""
        try:
            self._client.mgmt.flow.import_flow(flow_id, flow_data)
        except Exception as e:
            raise ApiError(f"Failed to update flow {flow_id}: {e}") from e

    def delete_flow(self, flow_id: str) -> None:
        """Delete flow."""
        try:
            self._client.mgmt.flow.delete_flows([flow_id])
        except Exception as e:
            raise ApiError(f"Failed to delete flow {flow_id}: {e}") from e
```

**Step 3: Commit**

```bash
git add src/descope_mgmt/api/descope_client.py tests/unit/api/test_flow_api.py
git commit -m "feat: add flow API methods to DescopeApiClient"
```

---

## Chunk Complete Checklist

- [ ] list_flows method
- [ ] get_flow method
- [ ] create_flow method
- [ ] update_flow method
- [ ] delete_flow method
- [ ] 7 tests passing
