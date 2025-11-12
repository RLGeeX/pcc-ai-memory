# Chunk 2: Tenant Delete Command

**Status:** pending
**Dependencies:** chunk-001
**Estimated Time:** 45 minutes

---

## Task 1: Implement Tenant Delete

**Files:**
- Modify: `src/descope_mgmt/cli/tenant.py`
- Create: `tests/integration/test_tenant_delete.py`

**Step 1: Write tests**

Create `tests/integration/test_tenant_delete.py`:
```python
"""Integration tests for tenant delete"""
import pytest
from unittest.mock import Mock, patch
from click.testing import CliRunner
from descope_mgmt.cli.main import cli


@patch('descope_mgmt.cli.tenant.DescopeApiClient')
@patch('descope_mgmt.cli.tenant.BackupService')
def test_tenant_delete(mock_backup_class, mock_client_class, tmp_path):
    """Should delete tenant with backup"""
    mock_client = Mock()
    mock_tenant = Mock()
    mock_tenant.id = "acme-corp"
    mock_tenant.name = "Acme Corp"
    mock_client.get_tenant.return_value = mock_tenant
    mock_client.delete_tenant.return_value = True
    mock_client_class.return_value = mock_client

    mock_backup = Mock()
    mock_backup.create_backup.return_value = tmp_path / "backup"
    mock_backup_class.return_value = mock_backup

    runner = CliRunner()
    result = runner.invoke(cli, [
        'tenant', 'delete',
        '--tenant-id', 'acme-corp',
        '--yes'
    ])

    assert result.exit_code == 0
    assert mock_backup.create_backup.called
    assert mock_client.delete_tenant.called
```

**Step 2: Implement delete command**

Modify `src/descope_mgmt/cli/tenant.py`:
```python
@tenant.command()
@click.option('--tenant-id', required=True)
@click.option('--yes', is_flag=True)
@click.pass_context
def delete(ctx: click.Context, tenant_id: str, yes: bool) -> None:
    """Delete tenant

    DESTRUCTIVE OPERATION: Creates automatic backup before deletion.
    """
    from descope_mgmt.cli.safety import safe_destructive_operation

    # Get tenant details for confirmation
    project_id = os.getenv('DESCOPE_PROJECT_ID')
    management_key = os.getenv('DESCOPE_MANAGEMENT_KEY')
    client = DescopeApiClient(project_id, management_key)

    tenant = client.get_tenant(tenant_id)

    # Confirm
    if not confirm_destructive_operation(
        operation="delete",
        resource_type="tenant",
        resource_id=tenant_id,
        details={"name": tenant.name, "domains": tenant.domains},
        yes=yes
    ):
        raise click.Abort()

    # Delete with auto-backup
    def delete_tenant():
        client.delete_tenant(tenant_id)

    safe_destructive_operation(
        operation=delete_tenant,
        project_id=project_id,
        environment=ctx.obj.get('environment', 'default'),
        config=DescopeConfig(version="1.0", tenants=[]),
        operation_name="tenant delete"
    )

    console.print(f"[green]✓ Deleted tenant '{tenant_id}'[/green]")
```

**Step 3: Commit**

```bash
git add src/descope_mgmt/cli/tenant.py tests/integration/test_tenant_delete.py
git commit -m "feat: implement tenant delete with auto-backup"
```

---

## Chunk Complete Checklist

- [ ] tenant delete command
- [ ] Confirmation with details
- [ ] Auto-backup
- [ ] 4 tests passing
