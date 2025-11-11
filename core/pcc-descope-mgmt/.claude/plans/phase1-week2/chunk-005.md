# Chunk 5: Tenant Sync Command with Dry-Run

**Status:** pending
**Dependencies:** chunk-001, chunk-002, chunk-003, chunk-004
**Estimated Time:** 60 minutes

---

## Task 1: Implement Tenant Sync Command (Dry-Run Only)

**Files:**
- Modify: `src/descope_mgmt/cli/tenant.py`
- Create: `tests/integration/test_tenant_sync.py`

**Step 1: Write integration tests**

Create `tests/integration/test_tenant_sync.py`:
```python
"""Integration tests for tenant sync command"""
import pytest
from unittest.mock import Mock, patch
from click.testing import CliRunner
from datetime import datetime
from descope_mgmt.cli.main import cli


@pytest.fixture
def temp_config(tmp_path):
    """Create temporary config file"""
    config = tmp_path / "descope.yaml"
    config.write_text("""
version: "1.0"
tenants:
  - id: acme-corp
    name: Acme Corporation
    domains:
      - acme.com
    self_provisioning: true
  - id: widget-co
    name: Widget Company
""")
    return str(config)


@patch('descope_mgmt.cli.tenant.DescopeApiClient')
@patch('descope_mgmt.cli.tenant.ConfigLoader')
def test_tenant_sync_dry_run_shows_changes(mock_loader_class, mock_client_class, temp_config):
    """tenant sync --dry-run should display planned changes"""
    # Mock config loader
    from descope_mgmt.domain.models.config import TenantConfig, DescopeConfig
    mock_loader = Mock()
    mock_loader.load_config.return_value = DescopeConfig(
        version="1.0",
        tenants=[
            TenantConfig(id="acme-corp", name="Acme Corporation", domains=["acme.com"], self_provisioning=True),
            TenantConfig(id="widget-co", name="Widget Company")
        ]
    )
    mock_loader_class.return_value = mock_loader

    # Mock API client (empty current state)
    mock_client = Mock()
    mock_client.list_tenants.return_value = []
    mock_client_class.return_value = mock_client

    runner = CliRunner()
    result = runner.invoke(cli, ['tenant', 'sync', '--config', temp_config, '--dry-run'])

    assert result.exit_code == 0
    assert 'acme-corp' in result.output
    assert 'widget-co' in result.output
    assert 'CREATE' in result.output or 'create' in result.output
    assert 'dry-run' in result.output.lower() or 'preview' in result.output.lower()


@patch('descope_mgmt.cli.tenant.DescopeApiClient')
@patch('descope_mgmt.cli.tenant.ConfigLoader')
def test_tenant_sync_dry_run_no_changes(mock_loader_class, mock_client_class, temp_config):
    """tenant sync --dry-run should show no changes when synced"""
    from descope_mgmt.domain.models.config import TenantConfig, DescopeConfig

    # Mock config
    mock_loader = Mock()
    mock_loader.load_config.return_value = DescopeConfig(
        version="1.0",
        tenants=[TenantConfig(id="acme-corp", name="Acme Corporation")]
    )
    mock_loader_class.return_value = mock_loader

    # Mock API client (matching current state)
    mock_tenant = Mock()
    mock_tenant.id = "acme-corp"
    mock_tenant.name = "Acme Corporation"
    mock_tenant.domains = []
    mock_tenant.self_provisioning = False
    mock_tenant.custom_attributes = {}
    mock_tenant.created_at = datetime.now()
    mock_tenant.updated_at = datetime.now()

    mock_client = Mock()
    mock_client.list_tenants.return_value = [mock_tenant]
    mock_client_class.return_value = mock_client

    runner = CliRunner()
    result = runner.invoke(cli, ['tenant', 'sync', '--config', temp_config, '--dry-run'])

    assert result.exit_code == 0
    assert 'No changes' in result.output or 'up to date' in result.output.lower()
```

**Step 2: Run tests to verify they fail**

Run: `pytest tests/integration/test_tenant_sync.py -v`

Expected: FAIL (sync command not implemented)

**Step 3: Implement tenant sync command**

Modify `src/descope_mgmt/cli/tenant.py`:
```python
# Add imports at top
from descope_mgmt.utils.config_loader import ConfigLoader
from descope_mgmt.domain.services.state_fetcher import StateFetcher
from descope_mgmt.domain.services.diff_service import DiffService
from descope_mgmt.domain.models.diff import ChangeType
from rich.panel import Panel


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

        # TODO: Actually apply changes (Phase 1 Week 2+)
        console.print("\n[yellow]⚠ Apply mode not yet implemented - use --dry-run for now[/yellow]")

    except Exception as e:
        console.print(format_error(f"Sync failed: {e}"))
        raise click.Abort()
```

**Step 4: Run tests to verify they pass**

Run: `pytest tests/integration/test_tenant_sync.py -v`

Expected: PASS (all 2 tests)

**Step 5: Commit**

```bash
git add src/descope_mgmt/cli/tenant.py tests/integration/test_tenant_sync.py
git commit -m "feat: implement tenant sync command with dry-run mode"
```

---

## Chunk Complete Checklist

- [ ] Tenant sync command with --dry-run (2 tests)
- [ ] Displays planned changes with color coding
- [ ] Shows creates, updates, deletes
- [ ] Handles no-changes case
- [ ] Rich formatted output with panels
- [ ] Commit made
