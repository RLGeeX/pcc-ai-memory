# Chunk 5: Rollback Mechanism

**Status:** pending
**Dependencies:** chunk-003
**Estimated Time:** 45 minutes

---

## Task 1: Implement Flow Rollback

**Files:**
- Modify: `src/descope_mgmt/cli/flow.py`
- Create: `tests/integration/test_flow_rollback.py`

**Step 1: Write tests**

Create `tests/integration/test_flow_rollback.py`:
```python
"""Integration tests for flow rollback"""
import pytest
from unittest.mock import Mock, patch
from click.testing import CliRunner
from descope_mgmt.cli.main import cli


@patch('descope_mgmt.cli.flow.RestoreService')
@patch('descope_mgmt.cli.flow.DescopeApiClient')
def test_flow_rollback(mock_client_class, mock_restore_class, tmp_path):
    """Should rollback flow from backup"""
    mock_client = Mock()
    mock_client_class.return_value = mock_client

    mock_restore = Mock()
    mock_restore_class.return_value = mock_restore

    runner = CliRunner()
    result = runner.invoke(cli, [
        'flow', 'rollback',
        '--flow-id', 'sign-up',
        '--backup', str(tmp_path),
        '--yes'
    ])

    # Should attempt restore
    assert mock_restore.load_backup.called
```

**Step 2: Implement rollback command**

Modify `src/descope_mgmt/cli/flow.py`:
```python
@flow.command()
@click.option('--flow-id', required=True)
@click.option('--backup', type=click.Path(exists=True), required=True)
@click.option('--yes', is_flag=True)
@click.pass_context
def rollback(ctx: click.Context, flow_id: str, backup: str, yes: bool) -> None:
    """Rollback flow from backup"""
    from descope_mgmt.domain.services import RestoreService

    if not yes:
        if not click.confirm(f"Rollback flow '{flow_id}' from backup?"):
            raise click.Abort()

    restore_service = RestoreService()
    backup_data = restore_service.load_backup(Path(backup))

    # Find flow in backup
    flow_backup = next((f for f in backup_data.flows if f.flow_id == flow_id), None)

    if not flow_backup:
        console.print(format_error(f"Flow '{flow_id}' not found in backup"))
        raise click.Abort()

    # Restore flow
    project_id = os.getenv('DESCOPE_PROJECT_ID')
    management_key = os.getenv('DESCOPE_MANAGEMENT_KEY')
    client = DescopeApiClient(project_id, management_key)

    client.update_flow(flow_id, flow_backup.flow_data)

    console.print(f"[green]✓ Rolled back flow '{flow_id}'[/green]")
```

**Step 3: Commit**

```bash
git add src/descope_mgmt/cli/flow.py tests/integration/test_flow_rollback.py
git commit -m "feat: implement flow rollback command"
```

---

## Chunk Complete Checklist

- [ ] flow rollback command
- [ ] Backup restore integration
- [ ] 2 tests passing
- [ ] **Phase 2 Week 5 COMPLETE**
