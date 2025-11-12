# Chunk 5: Tenant Sync --apply

**Status:** pending
**Dependencies:** chunk-001, chunk-003, chunk-004
**Estimated Time:** 60 minutes

---

## Task 1: Implement Apply Mode for Tenant Sync

**Files:**
- Modify: `src/descope_mgmt/cli/tenant.py`
- Create: `tests/integration/test_tenant_sync_apply.py`

**Step 1: Write integration tests**

Create `tests/integration/test_tenant_sync_apply.py`:
```python
"""Integration tests for tenant sync --apply"""
import pytest
from unittest.mock import Mock, patch
from click.testing import CliRunner
from descope_mgmt.cli.main import cli


@patch('descope_mgmt.cli.tenant.DescopeApiClient')
@patch('descope_mgmt.cli.tenant.ConfigLoader')
@patch('descope_mgmt.cli.tenant.BackupService')
def test_tenant_sync_apply_creates_tenants(mock_backup_class, mock_loader_class, mock_client_class, tmp_path):
    """tenant sync --apply should create new tenants"""
    from descope_mgmt.domain.models.config import TenantConfig, DescopeConfig

    # Mock config
    mock_loader = Mock()
    mock_loader.load_config.return_value = DescopeConfig(
        version="1.0",
        tenants=[TenantConfig(id="acme-corp", name="Acme Corporation")]
    )
    mock_loader_class.return_value = mock_loader

    # Mock API client (empty current state)
    mock_client = Mock()
    mock_client.list_tenants.return_value = []
    mock_client.create_tenant.return_value = True
    mock_client_class.return_value = mock_client

    # Mock backup service
    mock_backup = Mock()
    mock_backup.create_backup.return_value = tmp_path / "backup"
    mock_backup_class.return_value = mock_backup

    runner = CliRunner()
    config_file = tmp_path / "descope.yaml"
    config_file.write_text("version: '1.0'\ntenants: []")

    result = runner.invoke(cli, [
        'tenant', 'sync',
        '--config', str(config_file),
        '--apply',
        '--yes'  # Skip confirmation
    ])

    assert result.exit_code == 0
    # Should have created backup
    assert mock_backup.create_backup.called
    # Should have created tenant
    assert mock_client.create_tenant.called


@patch('descope_mgmt.cli.tenant.DescopeApiClient')
@patch('descope_mgmt.cli.tenant.ConfigLoader')
def test_tenant_sync_apply_requires_confirmation(mock_loader_class, mock_client_class, tmp_path):
    """tenant sync --apply should require confirmation without --yes"""
    from descope_mgmt.domain.models.config import TenantConfig, DescopeConfig

    mock_loader = Mock()
    mock_loader.load_config.return_value = DescopeConfig(
        version="1.0",
        tenants=[TenantConfig(id="test", name="Test")]
    )
    mock_loader_class.return_value = mock_loader

    mock_client = Mock()
    mock_client.list_tenants.return_value = []
    mock_client_class.return_value = mock_client

    runner = CliRunner()
    config_file = tmp_path / "descope.yaml"
    config_file.write_text("version: '1.0'\ntenants: []")

    # Provide "n" to confirmation prompt
    result = runner.invoke(cli, [
        'tenant', 'sync',
        '--config', str(config_file),
        '--apply'
    ], input='n\n')

    # Should have aborted
    assert result.exit_code != 0 or "abort" in result.output.lower()
```

**Step 2: Run tests to verify they fail**

Run: `pytest tests/integration/test_tenant_sync_apply.py -v`

Expected: FAIL (apply mode not implemented)

**Step 3: Implement apply mode**

Modify `src/descope_mgmt/cli/tenant.py` (update the sync command):
```python
# Update the sync command to actually apply changes

@tenant.command()
@click.option('--dry-run', is_flag=True, help='Preview changes without applying')
@click.option('--yes', is_flag=True, help='Skip confirmation prompts')
@click.pass_context
def sync(ctx: click.Context, dry_run: bool, yes: bool) -> None:
    """Sync tenants to match configuration

    Idempotent operation that creates, updates, or deletes tenants
    to match the desired state in the configuration file.
    """
    try:
        from descope_mgmt.cli.safety import safe_destructive_operation
        from descope_mgmt.utils.progress import track_batch_operation

        # Get config path and environment
        config_path = ctx.obj.get('config')
        environment = ctx.obj.get('environment')

        # Load configuration
        loader = ConfigLoader()
        if environment:
            config = loader.load_with_environment(environment, config_path)
        else:
            config = loader.load_or_discover(config_path)

        console.print(f"[dim]Loaded configuration with {len(config.tenants)} tenants[/dim]")

        # Get credentials
        project_id = os.getenv('DESCOPE_PROJECT_ID')
        management_key = os.getenv('DESCOPE_MANAGEMENT_KEY')

        if not project_id or not management_key:
            console.print(format_error("Missing DESCOPE_PROJECT_ID or DESCOPE_MANAGEMENT_KEY"))
            raise click.Abort()

        # Fetch current state
        client = DescopeApiClient(project_id, management_key)
        fetcher = StateFetcher(client, project_id)
        current_state = fetcher.fetch_current_state()

        console.print(f"[dim]Current state: {len(current_state.tenants)} tenants[/dim]")

        # Calculate diff
        diff_service = DiffService()
        diff = diff_service.calculate_diff(current_state, config)

        # Display changes
        if not diff.has_changes():
            console.print("[green]✓ No changes needed - configuration matches current state[/green]")
            return

        # Show summary
        creates = diff.count_by_type(ChangeType.CREATE)
        updates = diff.count_by_type(ChangeType.UPDATE)
        deletes = diff.count_by_type(ChangeType.DELETE)

        console.print(Panel(
            f"[yellow]Changes Summary:[/yellow]\n"
            f"  [green]+ {creates} to create[/green]\n"
            f"  [blue]~ {updates} to update[/blue]\n"
            f"  [red]- {deletes} to delete[/red]",
            title="Planned Changes"
        ))

        # Show detailed changes
        for tenant_diff in diff.tenant_diffs:
            if tenant_diff.change_type == ChangeType.NO_CHANGE:
                continue

            if tenant_diff.change_type == ChangeType.CREATE:
                console.print(f"  [green]+ CREATE[/green] {tenant_diff.tenant_id}")
            elif tenant_diff.change_type == ChangeType.UPDATE:
                console.print(f"  [blue]~ UPDATE[/blue] {tenant_diff.tenant_id}")
                for field_diff in tenant_diff.field_diffs:
                    console.print(f"      {field_diff.field_name}: {field_diff.old_value} → {field_diff.new_value}")
            elif tenant_diff.change_type == ChangeType.DELETE:
                console.print(f"  [red]- DELETE[/red] {tenant_diff.tenant_id}")

        # Dry-run mode
        if dry_run:
            console.print("\n[yellow]⚠ Dry-run mode - no changes applied[/yellow]")
            console.print("Run without --dry-run to apply these changes")
            return

        # Apply mode - require confirmation
        if not yes:
            if not click.confirm("\nApply these changes?", default=False):
                console.print("[yellow]Aborted[/yellow]")
                raise click.Abort()

        # Create backup before applying
        def apply_changes():
            # Execute creates
            for tenant_diff in diff.tenant_diffs:
                if tenant_diff.change_type == ChangeType.CREATE:
                    tenant_config = next(t for t in config.tenants if t.id == tenant_diff.tenant_id)
                    client.create_tenant(tenant_config)
                    console.print(f"[green]✓ Created {tenant_diff.tenant_id}[/green]")

                elif tenant_diff.change_type == ChangeType.UPDATE:
                    tenant_config = next(t for t in config.tenants if t.id == tenant_diff.tenant_id)
                    client.update_tenant(tenant_config)
                    console.print(f"[blue]✓ Updated {tenant_diff.tenant_id}[/blue]")

                elif tenant_diff.change_type == ChangeType.DELETE:
                    client.delete_tenant(tenant_diff.tenant_id)
                    console.print(f"[red]✓ Deleted {tenant_diff.tenant_id}[/red]")

        # Execute with auto-backup
        safe_destructive_operation(
            operation=apply_changes,
            project_id=project_id,
            environment=environment or "default",
            config=config,
            operation_name="tenant sync"
        )

        console.print(f"\n[green]✓ Sync complete - {creates + updates + deletes} changes applied[/green]")

    except Exception as e:
        console.print(format_error(f"Sync failed: {e}"))
        raise click.Abort()
```

**Step 4: Run tests to verify they pass**

Run: `pytest tests/integration/test_tenant_sync_apply.py -v`

Expected: PASS (all 2 tests)

**Step 5: Commit**

```bash
git add src/descope_mgmt/cli/tenant.py tests/integration/test_tenant_sync_apply.py
git commit -m "feat: implement tenant sync --apply with auto-backup"
```

---

## Task 2: Add Progress Tracking to Batch Operations

**Files:**
- Modify: `src/descope_mgmt/cli/tenant.py` (add progress bar to sync)

**Step 1: Enhance sync with progress bar**

Update the apply_changes function in tenant.py:
```python
# Update apply_changes to use progress tracking
from descope_mgmt.utils.progress import create_progress_bar

def apply_changes():
    changes = [d for d in diff.tenant_diffs if d.change_type != ChangeType.NO_CHANGE]

    with create_progress_bar() as progress:
        task = progress.add_task("[cyan]Applying changes", total=len(changes))

        for tenant_diff in changes:
            if tenant_diff.change_type == ChangeType.CREATE:
                tenant_config = next(t for t in config.tenants if t.id == tenant_diff.tenant_id)
                client.create_tenant(tenant_config)
                console.print(f"[green]✓ Created {tenant_diff.tenant_id}[/green]")

            elif tenant_diff.change_type == ChangeType.UPDATE:
                tenant_config = next(t for t in config.tenants if t.id == tenant_diff.tenant_id)
                client.update_tenant(tenant_config)
                console.print(f"[blue]✓ Updated {tenant_diff.tenant_id}[/blue]")

            elif tenant_diff.change_type == ChangeType.DELETE:
                client.delete_tenant(tenant_diff.tenant_id)
                console.print(f"[red]✓ Deleted {tenant_diff.tenant_id}[/red]")

            progress.update(task, advance=1)
```

**Step 2: Commit**

```bash
git add src/descope_mgmt/cli/tenant.py
git commit -m "feat: add progress tracking to tenant sync"
```

---

## Chunk Complete Checklist

- [ ] Tenant sync --apply implementation (2 tests)
- [ ] Auto-backup before apply
- [ ] Confirmation prompts (--yes flag)
- [ ] Progress bar for batch operations
- [ ] Create, update, delete execution
- [ ] All commits made
- [ ] 3 tests passing total (2 integration + existing)
