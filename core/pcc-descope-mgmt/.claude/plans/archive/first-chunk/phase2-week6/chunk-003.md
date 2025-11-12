# Chunk 3: Flow Delete Command

**Status:** pending
**Dependencies:** chunk-001
**Estimated Time:** 45 minutes

---

## Task 1: Implement Flow Delete

**Files:**
- Modify: `src/descope_mgmt/cli/flow.py`
- Create: `tests/integration/test_flow_delete.py`

**Step 1: Write tests**

Create `tests/integration/test_flow_delete.py`:
```python
"""Integration tests for flow delete"""
import pytest
from unittest.mock import Mock, patch
from click.testing import CliRunner
from descope_mgmt.cli.main import cli


@patch('descope_mgmt.cli.flow.DescopeApiClient')
@patch('descope_mgmt.cli.flow.BackupService')
def test_flow_delete(mock_backup_class, mock_client_class, tmp_path):
    """Should delete flow with backup"""
    mock_client = Mock()
    mock_flow = Mock()
    mock_flow.flow_id = "sign-up"
    mock_flow.name = "Sign Up"
    mock_client.get_flow.return_value = mock_flow
    mock_client.delete_flow.return_value = True
    mock_client_class.return_value = mock_client

    mock_backup = Mock()
    mock_backup.create_backup.return_value = tmp_path / "backup"
    mock_backup_class.return_value = mock_backup

    runner = CliRunner()
    result = runner.invoke(cli, [
        'flow', 'delete',
        '--flow-id', 'sign-up',
        '--yes'
    ])

    assert result.exit_code == 0
    assert mock_backup.create_backup.called
    assert mock_client.delete_flow.called
```

**Step 2: Implement delete command**

Modify `src/descope_mgmt/cli/flow.py`:
```python
@flow.command()
@click.option('--flow-id', required=True)
@click.option('--yes', is_flag=True)
@click.pass_context
def delete(ctx: click.Context, flow_id: str, yes: bool) -> None:
    """Delete flow

    DESTRUCTIVE OPERATION: Creates automatic backup before deletion.
    """
    from descope_mgmt.cli.safety import safe_destructive_operation
    from descope_mgmt.cli.common import confirm_destructive_operation

    # Get flow details
    project_id = os.getenv('DESCOPE_PROJECT_ID')
    management_key = os.getenv('DESCOPE_MANAGEMENT_KEY')
    client = DescopeApiClient(project_id, management_key)

    flow = client.get_flow(flow_id)

    # Confirm
    if not confirm_destructive_operation(
        operation="delete",
        resource_type="flow",
        resource_id=flow_id,
        details={"name": getattr(flow, 'name', flow_id)},
        yes=yes
    ):
        raise click.Abort()

    # Delete with auto-backup
    def delete_flow():
        client.delete_flow(flow_id)

    safe_destructive_operation(
        operation=delete_flow,
        project_id=project_id,
        environment=ctx.obj.get('environment', 'default'),
        config=DescopeConfig(version="1.0", tenants=[]),
        operation_name="flow delete"
    )

    console.print(f"[green]✓ Deleted flow '{flow_id}'[/green]")
```

**Step 3: Commit**

```bash
git add src/descope_mgmt/cli/flow.py tests/integration/test_flow_delete.py
git commit -m "feat: implement flow delete with auto-backup"
```

---

## Chunk Complete Checklist

- [ ] flow delete command
- [ ] Confirmation with details
- [ ] Auto-backup
- [ ] 4 tests passing
