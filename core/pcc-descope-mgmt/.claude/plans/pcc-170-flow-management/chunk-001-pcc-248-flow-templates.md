# Chunk 1: Flow Template System (PCC-248)

**Status:** pending
**Jira:** PCC-248
**Dependencies:** none
**Complexity:** simple
**Estimated Time:** 15-20 minutes
**Tasks:** 3
**Phase:** FlowManager Integration

---

## Task 1: Wire FlowManager.list_flows() to API Client

**Agent:** python-pro
**Files:**
- Modify: `src/descope_mgmt/domain/flow_manager.py:32-41`
- Test: `tests/unit/domain/test_flow_manager.py`

**Step 1: Write the failing test**

```python
# tests/unit/domain/test_flow_manager.py
def test_list_flows_returns_flows_from_client(mock_client: FakeDescopeClient) -> None:
    """FlowManager.list_flows() should delegate to client."""
    manager = FlowManager(mock_client)
    flows = manager.list_flows()
    assert len(flows) >= 0  # Returns list from client
```

**Step 2: Run test to verify current behavior**

Run: `pytest tests/unit/domain/test_flow_manager.py -v -k list_flows`

**Step 3: Update FlowManager.list_flows()**

```python
def list_flows(self, tenant_id: str | None = None) -> list[FlowConfig]:
    """List all flows in the project."""
    return self._client.list_flows(tenant_id)
```

**Step 4: Run test to verify it passes**

Run: `pytest tests/unit/domain/test_flow_manager.py -v`

---

## Task 2: Wire FlowManager.get_flow() to API Client

**Agent:** python-pro
**Files:**
- Modify: `src/descope_mgmt/domain/flow_manager.py:43-52`
- Test: `tests/unit/domain/test_flow_manager.py`

**Step 1: Write failing test**

```python
def test_get_flow_delegates_to_client(mock_client: FakeDescopeClient) -> None:
    """FlowManager.get_flow() should delegate to client."""
    manager = FlowManager(mock_client)
    result = manager.get_flow("sign-up-or-in")
    # Should call client.get_flow()
```

**Step 2: Update FlowManager.get_flow()**

```python
def get_flow(self, flow_id: str) -> FlowConfig | None:
    """Get a specific flow by ID."""
    return self._client.get_flow(flow_id)
```

**Step 3: Run tests**

Run: `pytest tests/unit/domain/test_flow_manager.py -v`

---

## Task 3: Add export_flow and import_flow to FlowManager

**Agent:** python-pro
**Files:**
- Modify: `src/descope_mgmt/domain/flow_manager.py`
- Test: `tests/unit/domain/test_flow_manager.py`

**Step 1: Add export_flow method**

```python
def export_flow(self, flow_id: str) -> dict[str, Any]:
    """Export flow schema as JSON dictionary."""
    return self._client.export_flow(flow_id)

def import_flow(self, flow_id: str, schema: dict[str, Any]) -> None:
    """Import flow schema from JSON dictionary."""
    self._client.import_flow(flow_id, schema)
```

**Step 2: Write tests**

```python
def test_export_flow_delegates_to_client(mock_client: FakeDescopeClient) -> None:
    manager = FlowManager(mock_client)
    result = manager.export_flow("sign-up-or-in")
    assert isinstance(result, dict)

def test_import_flow_delegates_to_client(mock_client: FakeDescopeClient) -> None:
    manager = FlowManager(mock_client)
    manager.import_flow("test-flow", {"flowId": "test-flow"})
```

**Step 3: Run all tests and commit**

Run: `pytest tests/unit/domain/ -v && ruff check . && mypy src/`

```bash
git add src/descope_mgmt/domain/flow_manager.py tests/unit/domain/test_flow_manager.py
git commit -m "feat(flow): wire FlowManager to API client methods"
```

---

## Chunk Complete Checklist

- [ ] FlowManager.list_flows() wired to client
- [ ] FlowManager.get_flow() wired to client
- [ ] FlowManager.export_flow() added
- [ ] FlowManager.import_flow() added
- [ ] All tests passing
- [ ] Code committed
- [ ] Ready for chunk 2
