# Chunk 6: Flow Delete Manager Logic

**Status:** pending
**Dependencies:** none (can run parallel with chunk-004)
**Complexity:** medium
**Estimated Time:** 12 minutes
**Tasks:** 2
**Phase:** Delete Commands
**Jira:** PCC-254

---

## Task 1: Add Delete Method to FlowManager

**Agent:** python-pro
**Files:**
- Modify: `src/descope_mgmt/domain/flow_manager.py`
- Modify: `tests/unit/domain/test_flow_manager.py`

**Step 1: Add tests for flow delete**

Add to `tests/unit/domain/test_flow_manager.py`:

```python
from unittest.mock import MagicMock, patch
from pathlib import Path

from descope_mgmt.domain.backup_service import BackupService


class TestFlowManagerDelete:
    """Tests for FlowManager delete operations."""

    def test_delete_flow_success(self, fake_client: FakeDescopeClient) -> None:
        """Test successful flow deletion."""
        from descope_mgmt.types.flow import FlowConfig

        flow = FlowConfig(id="flow-1", name="Login", flow_type="login")
        fake_client.flows["flow-1"] = flow

        manager = FlowManager(fake_client)
        manager.delete_flow("flow-1")

        assert "flow-1" not in fake_client.flows

    def test_delete_flow_not_found(self, fake_client: FakeDescopeClient) -> None:
        """Test delete raises error for missing flow."""
        manager = FlowManager(fake_client)

        with pytest.raises(ValueError, match="Flow not found"):
            manager.delete_flow("nonexistent")

    def test_delete_flow_with_backup(self, fake_client: FakeDescopeClient) -> None:
        """Test delete creates backup before deletion."""
        from descope_mgmt.types.flow import FlowConfig

        flow = FlowConfig(id="flow-1", name="Login", flow_type="login")
        fake_client.flows["flow-1"] = flow

        with patch.object(BackupService, "backup_flow") as mock_backup:
            mock_backup.return_value = Path("/backups/flow-1.json")

            manager = FlowManager(fake_client)
            backup_path = manager.delete_flow_with_backup("flow-1")

            mock_backup.assert_called_once()
            assert backup_path == Path("/backups/flow-1.json")
            assert "flow-1" not in fake_client.flows
```

**Step 2: Run tests to verify they fail**

```bash
pytest tests/unit/domain/test_flow_manager.py::TestFlowManagerDelete -v
```

Expected: FAIL (delete_flow, delete_flow_with_backup not found)

**Step 3: Implement delete methods in FlowManager**

Add to `src/descope_mgmt/domain/flow_manager.py`:

```python
from pathlib import Path
from descope_mgmt.domain.backup_service import BackupService


class FlowManager:
    """Manager for flow operations."""

    # ... existing methods ...

    def delete_flow(self, flow_id: str) -> None:
        """Delete a flow.

        Args:
            flow_id: ID of flow to delete.

        Raises:
            ValueError: If flow not found.
        """
        # Verify flow exists
        try:
            self.get_flow(flow_id)
        except Exception:
            raise ValueError(f"Flow not found: {flow_id}")

        self._client.delete_flow(flow_id)

    def delete_flow_with_backup(
        self,
        flow_id: str,
        backup_service: BackupService | None = None,
    ) -> Path:
        """Delete a flow after creating a backup.

        Args:
            flow_id: ID of flow to delete.
            backup_service: Optional backup service (creates default if None).

        Returns:
            Path to the backup file.

        Raises:
            ValueError: If flow not found.
        """
        # Export flow schema for backup
        schema = self.export_flow(flow_id)

        # Create backup
        if backup_service is None:
            backup_service = BackupService()

        backup_path = backup_service.backup_flow(flow_id, schema)

        # Delete flow
        self.delete_flow(flow_id)

        return backup_path
```

**Step 4: Add delete_flow to FakeDescopeClient**

Add to `tests/fakes.py`:

```python
def delete_flow(self, flow_id: str) -> None:
    """Delete a flow."""
    if flow_id not in self.flows:
        raise ValueError(f"Flow not found: {flow_id}")
    del self.flows[flow_id]
```

**Step 5: Run tests to verify they pass**

```bash
pytest tests/unit/domain/test_flow_manager.py -v
```

Expected: PASS

**Step 6: Commit**

```bash
git add src/descope_mgmt/domain/flow_manager.py tests/unit/domain/test_flow_manager.py tests/fakes.py
git commit -m "feat(flow): add delete_flow and delete_flow_with_backup methods"
```

---

## Task 2: Add Dependency Check for Flow Delete

**Agent:** python-pro
**Files:**
- Modify: `src/descope_mgmt/domain/flow_manager.py`
- Modify: `tests/unit/domain/test_flow_manager.py`

**Step 1: Add tests for dependency check**

```python
class TestFlowManagerDeleteDependencies:
    """Tests for flow delete dependency checks."""

    def test_check_flow_dependencies_none(
        self, fake_client: FakeDescopeClient
    ) -> None:
        """Test checking dependencies when none exist."""
        from descope_mgmt.types.flow import FlowConfig

        flow = FlowConfig(id="standalone", name="Standalone", flow_type="login")
        fake_client.flows["standalone"] = flow

        manager = FlowManager(fake_client)
        deps = manager.check_flow_dependencies("standalone")

        assert deps == []

    def test_delete_with_force_ignores_dependencies(
        self, fake_client: FakeDescopeClient
    ) -> None:
        """Test --force allows deletion despite dependencies."""
        from descope_mgmt.types.flow import FlowConfig

        flow = FlowConfig(id="main", name="Main", flow_type="login")
        fake_client.flows["main"] = flow

        with patch.object(BackupService, "backup_flow") as mock_backup:
            mock_backup.return_value = Path("/backups/main.json")

            manager = FlowManager(fake_client)
            # Even if dependencies exist, force=True should proceed
            backup_path = manager.delete_flow_with_backup(
                "main", force=True
            )

            assert backup_path == Path("/backups/main.json")
            assert "main" not in fake_client.flows
```

**Step 2: Run tests to verify they fail**

```bash
pytest tests/unit/domain/test_flow_manager.py::TestFlowManagerDeleteDependencies -v
```

Expected: FAIL

**Step 3: Add dependency check method**

Add to `src/descope_mgmt/domain/flow_manager.py`:

```python
def check_flow_dependencies(self, flow_id: str) -> list[str]:
    """Check if other flows depend on this flow.

    Args:
        flow_id: ID of flow to check.

    Returns:
        List of dependent flow IDs (empty if none).
    """
    # In a real implementation, this would check for:
    # - Flows that reference this flow as a sub-flow
    # - Tenants that use this flow as their login flow
    # For now, return empty list (no dependency tracking yet)
    return []

def delete_flow_with_backup(
    self,
    flow_id: str,
    backup_service: BackupService | None = None,
    force: bool = False,
) -> Path:
    """Delete a flow after creating a backup.

    Args:
        flow_id: ID of flow to delete.
        backup_service: Optional backup service.
        force: If True, delete even if dependencies exist.

    Returns:
        Path to the backup file.

    Raises:
        ValueError: If flow not found or has dependencies (without force).
    """
    # Check dependencies unless force=True
    if not force:
        deps = self.check_flow_dependencies(flow_id)
        if deps:
            raise ValueError(
                f"Flow {flow_id} has dependencies: {', '.join(deps)}. "
                "Use force=True to delete anyway."
            )

    # Export flow schema for backup
    schema = self.export_flow(flow_id)

    # Create backup
    if backup_service is None:
        backup_service = BackupService()

    backup_path = backup_service.backup_flow(flow_id, schema)

    # Delete flow
    self.delete_flow(flow_id)

    return backup_path
```

**Step 4: Run tests to verify they pass**

```bash
pytest tests/unit/domain/test_flow_manager.py -v
```

Expected: PASS

**Step 5: Commit**

```bash
git add src/descope_mgmt/domain/flow_manager.py tests/unit/domain/test_flow_manager.py
git commit -m "feat(flow): add dependency check for flow deletion"
```

---

## Chunk Complete Checklist

- [ ] delete_flow method implemented
- [ ] delete_flow_with_backup with backup
- [ ] Dependency check foundation added
- [ ] force parameter supported
- [ ] All tests passing
- [ ] Code committed
- [ ] Ready for next chunk
