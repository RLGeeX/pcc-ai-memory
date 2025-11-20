# Chunk 5: Audit Logging - Integration

**Status:** pending
**Dependencies:** chunk-004-audit-foundation
**Complexity:** medium
**Estimated Time:** 20 minutes
**Tasks:** 3

---

## Task 1: Integrate Audit Logging into Tenant Operations

**Agent:** python-pro
**Files:**
- Modify: `src/descope_mgmt/domain/tenant_manager.py`
- Modify: `tests/unit/domain/test_tenant_manager.py`

**Step 1: Write the failing test**

Add test to `tests/unit/domain/test_tenant_manager.py`:

```python
from unittest.mock import MagicMock
from descope_mgmt.domain.audit_logger import AuditLogger
from descope_mgmt.types.audit import AuditOperation


def test_create_tenant_logs_audit_event(fake_client: FakeDescopeClient) -> None:
    """Test that creating a tenant logs an audit event."""
    mock_logger = MagicMock(spec=AuditLogger)
    manager = TenantManager(fake_client, audit_logger=mock_logger)

    config = TenantConfig(
        id="test-tenant",
        name="Test Tenant",
        selfProvisioningDomains=[],
    )

    manager.create_tenant(config)

    # Verify audit log was called
    mock_logger.log.assert_called_once()
    call_args = mock_logger.log.call_args[0][0]

    assert call_args.operation == AuditOperation.TENANT_CREATE
    assert call_args.resource_id == "test-tenant"
    assert call_args.success is True


def test_update_tenant_logs_audit_event_on_failure(fake_client: FakeDescopeClient) -> None:
    """Test that failed tenant update logs failure."""
    mock_logger = MagicMock(spec=AuditLogger)
    manager = TenantManager(fake_client, audit_logger=mock_logger)

    # Make the update fail
    fake_client.update_tenant_error = ApiError("Tenant not found", status_code=404)

    config = TenantConfig(
        id="nonexistent",
        name="Test",
        selfProvisioningDomains=[],
    )

    # Expect exception
    with pytest.raises(ApiError):
        manager.update_tenant("nonexistent", config)

    # Verify audit log recorded the failure
    mock_logger.log.assert_called_once()
    call_args = mock_logger.log.call_args[0][0]

    assert call_args.operation == AuditOperation.TENANT_UPDATE
    assert call_args.resource_id == "nonexistent"
    assert call_args.success is False
    assert "not found" in call_args.error.lower()
```

**Step 2: Run test to verify it fails**

```bash
pytest tests/unit/domain/test_tenant_manager.py::test_create_tenant_logs_audit_event -v
pytest tests/unit/domain/test_tenant_manager.py::test_update_tenant_logs_audit_event_on_failure -v
```

Expected: FAIL - audit_logger parameter doesn't exist

**Step 3: Update TenantManager to support audit logging**

Modify `src/descope_mgmt/domain/tenant_manager.py`:

```python
# Add imports
from descope_mgmt.domain.audit_logger import AuditLogger
from descope_mgmt.types.audit import AuditEntry, AuditOperation


class TenantManager:
    """Manager for tenant operations."""

    def __init__(
        self,
        client: DescopeClient,
        audit_logger: AuditLogger | None = None,
    ) -> None:
        """Initialize tenant manager.

        Args:
            client: Descope API client
            audit_logger: Optional audit logger
        """
        self.client = client
        self.audit_logger = audit_logger or AuditLogger()

    def create_tenant(self, config: TenantConfig) -> TenantResponse:
        """Create a new tenant with audit logging.

        Args:
            config: Tenant configuration

        Returns:
            Created tenant response
        """
        try:
            result = self.client.create_tenant(
                tenant_id=config.id,
                name=config.name,
                self_provisioning_domains=config.selfProvisioningDomains,
            )

            # Log successful creation
            self.audit_logger.log(
                AuditEntry(
                    operation=AuditOperation.TENANT_CREATE,
                    resource_id=config.id,
                    success=True,
                    details={"name": config.name},
                )
            )

            return result

        except Exception as e:
            # Log failure
            self.audit_logger.log(
                AuditEntry(
                    operation=AuditOperation.TENANT_CREATE,
                    resource_id=config.id,
                    success=False,
                    error=str(e),
                )
            )
            raise

    def update_tenant(self, tenant_id: str, config: TenantConfig) -> TenantResponse:
        """Update existing tenant with audit logging.

        Args:
            tenant_id: Tenant ID to update
            config: New tenant configuration

        Returns:
            Updated tenant response
        """
        try:
            result = self.client.update_tenant(
                tenant_id=tenant_id,
                name=config.name,
                self_provisioning_domains=config.selfProvisioningDomains,
            )

            # Log successful update
            self.audit_logger.log(
                AuditEntry(
                    operation=AuditOperation.TENANT_UPDATE,
                    resource_id=tenant_id,
                    success=True,
                    details={"name": config.name},
                )
            )

            return result

        except Exception as e:
            # Log failure
            self.audit_logger.log(
                AuditEntry(
                    operation=AuditOperation.TENANT_UPDATE,
                    resource_id=tenant_id,
                    success=False,
                    error=str(e),
                )
            )
            raise

    def delete_tenant(self, tenant_id: str) -> None:
        """Delete tenant with audit logging.

        Args:
            tenant_id: Tenant ID to delete
        """
        try:
            self.client.delete_tenant(tenant_id)

            # Log successful deletion
            self.audit_logger.log(
                AuditEntry(
                    operation=AuditOperation.TENANT_DELETE,
                    resource_id=tenant_id,
                    success=True,
                )
            )

        except Exception as e:
            # Log failure
            self.audit_logger.log(
                AuditEntry(
                    operation=AuditOperation.TENANT_DELETE,
                    resource_id=tenant_id,
                    success=False,
                    error=str(e),
                )
            )
            raise
```

**Step 4: Run test to verify it passes**

```bash
pytest tests/unit/domain/test_tenant_manager.py -v
```

Expected: All tests passing

**Step 5: Commit**

```bash
git add src/descope_mgmt/domain/tenant_manager.py tests/unit/domain/test_tenant_manager.py
git commit -m "feat: integrate audit logging into tenant operations"
```

---

## Task 2: Integrate Audit Logging into Flow Operations

**Agent:** python-pro
**Files:**
- Modify: `src/descope_mgmt/domain/flow_manager.py`
- Modify: `tests/unit/domain/test_flow_manager.py`

**Step 1: Write the failing test**

Add test to `tests/unit/domain/test_flow_manager.py`:

```python
from unittest.mock import MagicMock
from descope_mgmt.domain.audit_logger import AuditLogger
from descope_mgmt.types.audit import AuditOperation


def test_deploy_screen_logs_audit_event(fake_client: FakeDescopeClient) -> None:
    """Test that deploying a screen logs an audit event."""
    mock_logger = MagicMock(spec=AuditLogger)
    manager = FlowManager(fake_client, audit_logger=mock_logger)

    manager.deploy_screen("sign-up", "screen-1", {"id": "screen-1"})

    # Verify audit log was called
    mock_logger.log.assert_called_once()
    call_args = mock_logger.log.call_args[0][0]

    assert call_args.operation == AuditOperation.FLOW_DEPLOY
    assert call_args.resource_id == "sign-up"
    assert call_args.success is True
```

**Step 2: Run test to verify it fails**

```bash
pytest tests/unit/domain/test_flow_manager.py::test_deploy_screen_logs_audit_event -v
```

Expected: FAIL - audit_logger parameter doesn't exist

**Step 3: Update FlowManager similarly to TenantManager**

Modify `src/descope_mgmt/domain/flow_manager.py`:

```python
# Add imports
from descope_mgmt.domain.audit_logger import AuditLogger
from descope_mgmt.types.audit import AuditEntry, AuditOperation


class FlowManager:
    """Manager for flow operations."""

    def __init__(
        self,
        client: DescopeClient,
        audit_logger: AuditLogger | None = None,
    ) -> None:
        """Initialize flow manager.

        Args:
            client: Descope API client
            audit_logger: Optional audit logger
        """
        self.client = client
        self.audit_logger = audit_logger or AuditLogger()

    def deploy_screen(
        self,
        flow_id: str,
        screen_id: str,
        screen_data: dict[str, any],
    ) -> None:
        """Deploy a screen to a flow with audit logging.

        Args:
            flow_id: Flow identifier
            screen_id: Screen identifier
            screen_data: Screen configuration
        """
        try:
            self.client.deploy_flow_screen(flow_id, screen_id, screen_data)

            # Log successful deployment
            self.audit_logger.log(
                AuditEntry(
                    operation=AuditOperation.FLOW_DEPLOY,
                    resource_id=flow_id,
                    success=True,
                    details={"screen_id": screen_id},
                )
            )

        except Exception as e:
            # Log failure
            self.audit_logger.log(
                AuditEntry(
                    operation=AuditOperation.FLOW_DEPLOY,
                    resource_id=flow_id,
                    success=False,
                    error=str(e),
                    details={"screen_id": screen_id},
                )
            )
            raise

    # Apply similar pattern to export_flow, import_flow methods
```

**Step 4: Run test to verify it passes**

```bash
pytest tests/unit/domain/test_flow_manager.py -v
```

Expected: All tests passing

**Step 5: Commit**

```bash
git add src/descope_mgmt/domain/flow_manager.py tests/unit/domain/test_flow_manager.py
git commit -m "feat: integrate audit logging into flow operations"
```

---

## Task 3: Add Audit Log Viewer Command

**Agent:** python-pro
**Files:**
- Modify: `src/descope_mgmt/cli/main.py`
- Create: `src/descope_mgmt/cli/audit_cmds.py`
- Create: `tests/unit/cli/test_audit_cmds.py`

**Step 1: Write the failing test**

Create test file:

```python
"""Tests for audit commands."""

import json
from pathlib import Path

from typer.testing import CliRunner

from descope_mgmt.cli.main import cli_app
from descope_mgmt.domain.audit_logger import AuditLogger
from descope_mgmt.types.audit import AuditEntry, AuditOperation


def test_audit_list_displays_recent_entries(tmp_path: Path) -> None:
    """Test audit list command displays recent log entries."""
    # Create audit logs
    audit_dir = tmp_path / "audit"
    logger = AuditLogger(log_dir=audit_dir)

    for i in range(5):
        entry = AuditEntry(
            operation=AuditOperation.TENANT_CREATE,
            resource_id=f"tenant-{i}",
            success=True,
        )
        logger.log(entry)

    # Run command
    runner = CliRunner()
    result = runner.invoke(
        cli_app,
        ["audit", "list", "--log-dir", str(audit_dir)],
    )

    assert result.exit_code == 0
    assert "tenant-0" in result.output
    assert "TENANT_CREATE" in result.output


def test_audit_list_filters_by_operation(tmp_path: Path) -> None:
    """Test audit list can filter by operation type."""
    # Create mixed audit logs
    audit_dir = tmp_path / "audit"
    logger = AuditLogger(log_dir=audit_dir)

    logger.log(
        AuditEntry(
            operation=AuditOperation.TENANT_CREATE,
            resource_id="tenant-1",
            success=True,
        )
    )
    logger.log(
        AuditEntry(
            operation=AuditOperation.FLOW_DEPLOY,
            resource_id="flow-1",
            success=True,
        )
    )

    # Run with filter
    runner = CliRunner()
    result = runner.invoke(
        cli_app,
        ["audit", "list", "--log-dir", str(audit_dir), "--operation", "flow_deploy"],
    )

    assert result.exit_code == 0
    assert "flow-1" in result.output
    assert "tenant-1" not in result.output
```

**Step 2: Run test to verify it fails**

```bash
pytest tests/unit/cli/test_audit_cmds.py -v
```

Expected: FAIL - audit command doesn't exist

**Step 3: Create audit commands**

Create `src/descope_mgmt/cli/audit_cmds.py`:

```python
"""CLI commands for viewing audit logs."""

from pathlib import Path
from typing import Annotated

import typer
from rich.table import Table

from descope_mgmt.cli.output import get_console
from descope_mgmt.domain.audit_logger import AuditLogger

audit_app = typer.Typer(help="View audit logs")


@audit_app.command(name="list")
def list_audit_logs(
    log_dir: Annotated[Path | None, typer.Option(...)] = None,
    limit: Annotated[int, typer.Option(...)] = 50,
    operation: Annotated[str | None, typer.Option(...)] = None,
) -> None:
    """List recent audit log entries."""
    console = get_console()

    try:
        logger = AuditLogger(log_dir=log_dir)
        entries = logger.read_logs(limit=limit, operation=operation)

        if not entries:
            console.print("[yellow]No audit logs found[/yellow]")
            return

        # Display in table
        table = Table(title="Audit Logs")
        table.add_column("Timestamp", style="cyan")
        table.add_column("Operation", style="blue")
        table.add_column("Resource", style="green")
        table.add_column("Status", style="yellow")
        table.add_column("Details")

        for entry in entries:
            status = "✓ Success" if entry.success else "✗ Failed"
            status_color = "green" if entry.success else "red"

            details = entry.error if entry.error else str(entry.details)

            table.add_row(
                entry.timestamp.strftime("%Y-%m-%d %H:%M:%S"),
                entry.operation.value,
                entry.resource_id,
                f"[{status_color}]{status}[/{status_color}]",
                details,
            )

        console.print(table)

    except Exception as e:
        console.print(f"[red]Error:[/red] {e}")
        raise typer.Exit(1)
```

**Step 4: Register audit commands in main CLI**

Modify `src/descope_mgmt/cli/main.py`:

```python
# Add import
from descope_mgmt.cli.audit_cmds import audit_app

# Register app
cli_app.add_typer(audit_app, name="audit")
```

**Step 5: Run test to verify it passes**

```bash
pytest tests/unit/cli/test_audit_cmds.py -v
```

Expected: All tests passing

**Step 6: Manual verification**

```bash
descope-mgmt audit list --limit 10
```

Expected: Table of recent audit log entries displayed

**Step 7: Commit**

```bash
git add src/descope_mgmt/cli/audit_cmds.py src/descope_mgmt/cli/main.py tests/unit/cli/test_audit_cmds.py
git commit -m "feat: add audit log viewer command"
```

---

## Chunk Complete Checklist

- [ ] Task 1: Audit logging integrated into tenant operations
- [ ] Task 2: Audit logging integrated into flow operations
- [ ] Task 3: Audit viewer command added
- [ ] All tests passing (185+ total)
- [ ] Coverage maintained at 94%+
- [ ] Code committed (3 commits)
- [ ] Ready for Chunk 6
