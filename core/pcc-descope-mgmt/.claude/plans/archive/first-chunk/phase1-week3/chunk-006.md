# Chunk 6: Tenant Create Command

**Status:** pending
**Dependencies:** chunk-001, chunk-003
**Estimated Time:** 45 minutes

---

## Task 1: Implement Tenant Create Command

**Files:**
- Modify: `src/descope_mgmt/cli/tenant.py`
- Create: `tests/integration/test_tenant_create.py`

**Step 1: Write integration tests**

Create `tests/integration/test_tenant_create.py`:
```python
"""Integration tests for tenant create"""
import pytest
from unittest.mock import Mock, patch
from click.testing import CliRunner
from descope_mgmt.cli.main import cli


@patch('descope_mgmt.cli.tenant.DescopeApiClient')
@patch('descope_mgmt.cli.tenant.BackupService')
def test_tenant_create_command(mock_backup_class, mock_client_class, tmp_path):
    """tenant create should create new tenant"""
    # Mock API client
    mock_client = Mock()
    mock_client.create_tenant.return_value = True
    mock_client_class.return_value = mock_client

    # Mock backup service
    mock_backup = Mock()
    mock_backup.create_backup.return_value = tmp_path / "backup"
    mock_backup_class.return_value = mock_backup

    runner = CliRunner()
    result = runner.invoke(cli, [
        'tenant', 'create',
        '--tenant-id', 'acme-corp',
        '--name', 'Acme Corporation',
        '--domain', 'acme.com',
        '--self-provisioning',
        '--yes'
    ])

    assert result.exit_code == 0
    assert mock_client.create_tenant.called
    assert "created" in result.output.lower() or "✓" in result.output


@patch('descope_mgmt.cli.tenant.DescopeApiClient')
def test_tenant_create_validation_error(mock_client_class):
    """tenant create should validate tenant ID format"""
    mock_client = Mock()
    mock_client_class.return_value = mock_client

    runner = CliRunner()
    result = runner.invoke(cli, [
        'tenant', 'create',
        '--tenant-id', 'INVALID_ID',  # Uppercase not allowed
        '--name', 'Test',
        '--yes'
    ])

    # Should fail validation
    assert result.exit_code != 0
    assert "validation" in result.output.lower() or "invalid" in result.output.lower()
```

**Step 2: Run tests to verify they fail**

Run: `pytest tests/integration/test_tenant_create.py -v`

Expected: FAIL (command not implemented)

**Step 3: Implement tenant create command**

Modify `src/descope_mgmt/cli/tenant.py`:
```python
# Add the create command to the tenant group

@tenant.command()
@click.option('--tenant-id', required=True, help='Tenant ID (lowercase, alphanumeric, hyphens)')
@click.option('--name', required=True, help='Tenant display name')
@click.option('--domain', multiple=True, help='Allowed domains (can specify multiple)')
@click.option('--self-provisioning/--no-self-provisioning', default=False, help='Enable self-provisioning')
@click.option('--yes', is_flag=True, help='Skip confirmation prompts')
@click.pass_context
def create(
    ctx: click.Context,
    tenant_id: str,
    name: str,
    domain: tuple[str, ...],
    self_provisioning: bool,
    yes: bool
) -> None:
    """Create a new tenant

    Creates a new tenant with the specified configuration.
    Automatically creates a backup before creation.
    """
    try:
        from descope_mgmt.cli.safety import safe_destructive_operation
        from descope_mgmt.domain.models.config import TenantConfig, DescopeConfig
        from pydantic import ValidationError

        # Validate tenant config
        try:
            tenant_config = TenantConfig(
                id=tenant_id,
                name=name,
                domains=list(domain) if domain else [],
                self_provisioning=self_provisioning
            )
        except ValidationError as e:
            console.print(format_error(f"Validation failed: {e}"))
            raise click.Abort()

        # Show what will be created
        console.print("\n[cyan]Tenant to create:[/cyan]")
        console.print(f"  ID: {tenant_config.id}")
        console.print(f"  Name: {tenant_config.name}")
        console.print(f"  Domains: {', '.join(tenant_config.domains) if tenant_config.domains else 'None'}")
        console.print(f"  Self-provisioning: {tenant_config.self_provisioning}")

        # Confirm
        if not yes:
            if not click.confirm("\nCreate this tenant?", default=False):
                console.print("[yellow]Aborted[/yellow]")
                raise click.Abort()

        # Get credentials
        project_id = os.getenv('DESCOPE_PROJECT_ID')
        management_key = os.getenv('DESCOPE_MANAGEMENT_KEY')
        environment = ctx.obj.get('environment', 'default')

        if not project_id or not management_key:
            console.print(format_error("Missing DESCOPE_PROJECT_ID or DESCOPE_MANAGEMENT_KEY"))
            raise click.Abort()

        # Create client
        client = DescopeApiClient(project_id, management_key)

        # Get current config for backup
        fetcher = StateFetcher(client, project_id)
        current_state = fetcher.fetch_current_state()
        current_config = DescopeConfig(
            version="1.0",
            tenants=[TenantConfig(
                id=t.id,
                name=t.name,
                domains=t.domains,
                self_provisioning=t.self_provisioning
            ) for t in current_state.tenants]
        )

        # Execute with auto-backup
        def create_tenant():
            client.create_tenant(tenant_config)

        safe_destructive_operation(
            operation=create_tenant,
            project_id=project_id,
            environment=environment,
            config=current_config,
            operation_name="tenant create"
        )

        console.print(f"\n[green]✓ Tenant '{tenant_id}' created successfully[/green]")

    except Exception as e:
        console.print(format_error(f"Tenant creation failed: {e}"))
        raise click.Abort()
```

**Step 4: Run tests to verify they pass**

Run: `pytest tests/integration/test_tenant_create.py -v`

Expected: PASS (all 2 tests)

**Step 5: Commit**

```bash
git add src/descope_mgmt/cli/tenant.py tests/integration/test_tenant_create.py
git commit -m "feat: implement tenant create command with validation"
```

---

## Chunk Complete Checklist

- [ ] tenant create command (2 tests)
- [ ] Pydantic validation integration
- [ ] Auto-backup before creation
- [ ] Confirmation prompts
- [ ] All commits made
- [ ] **Phase 1 Week 3 COMPLETE**
- [ ] 2 integration tests passing
