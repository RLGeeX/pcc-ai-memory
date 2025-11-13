# Chunk 4: Tenant Create Command

**Status:** pending
**Dependencies:** chunk-003-tenant-manager
**Complexity:** medium
**Estimated Time:** 40 minutes
**Tasks:** 3

---

## Task 1: Update Tenant List to Use TenantManager

**Files:**
- Modify: `src/descope_mgmt/cli/tenant_cmds.py:1-30`
- Modify: `tests/unit/cli/test_tenant_cmds.py`

**Step 1: Write failing test with actual data**

Add to `tests/unit/cli/test_tenant_cmds.py`:
```python
from unittest.mock import Mock, patch

from descope_mgmt.types.tenant import TenantConfig


@patch("descope_mgmt.cli.tenant_cmds.TenantManager")
def test_tenant_list_displays_tenants(mock_manager_class: Mock) -> None:
    """Test tenant list displays tenant data in table."""
    # Setup mock
    mock_manager = Mock()
    mock_manager.list_tenants.return_value = [
        TenantConfig(id="tenant1", name="Tenant One", domains=["example.com"]),
        TenantConfig(id="tenant2", name="Tenant Two"),
    ]
    mock_manager_class.return_value = mock_manager

    runner = CliRunner()
    result = runner.invoke(cli, ["tenant", "list"])

    assert result.exit_code == 0
    assert "tenant1" in result.output
    assert "Tenant One" in result.output
```

**Step 2: Run test to verify it fails**

```bash
pytest tests/unit/cli/test_tenant_cmds.py::test_tenant_list_displays_tenants -v
```
Expected: FAIL (TenantManager not imported/used)

**Step 3: Update tenant list command**

Update `src/descope_mgmt/cli/tenant_cmds.py`:
```python
"""Tenant management CLI commands."""

import click
from rich.table import Table

from descope_mgmt.api.descope_client import DescopeClient
from descope_mgmt.api.rate_limiter import DescopeRateLimiter
from descope_mgmt.cli.output import get_console
from descope_mgmt.domain.tenant_manager import TenantManager


@click.command()
@click.pass_context
def list_tenants(ctx: click.Context) -> None:
    """List all tenants in the current project."""
    console = get_console()
    verbose = ctx.obj.get("verbose", False)

    if verbose:
        console.log("Fetching tenants from Descope API...")

    # Initialize services
    # TODO: In chunk 5, get credentials from config
    rate_limiter = DescopeRateLimiter()
    client = DescopeClient(
        project_id="placeholder",
        management_key="placeholder",
        rate_limiter=rate_limiter,
    )
    manager = TenantManager(client)

    # Fetch tenants
    tenants = manager.list_tenants()

    # Create Rich table
    table = Table(title="Tenants")
    table.add_column("ID", style="cyan")
    table.add_column("Name", style="green")
    table.add_column("Domains", style="yellow")

    for tenant in tenants:
        domains = ", ".join(tenant.domains) if tenant.domains else "-"
        table.add_row(tenant.id, tenant.name, domains)

    if len(tenants) == 0:
        console.print("[dim]No tenants found.[/dim]")
    else:
        console.print(table)
```

**Step 4: Run tests to verify they pass**

```bash
pytest tests/unit/cli/test_tenant_cmds.py -v
```
Expected: PASS (5 tests)

**Step 5: Commit**

```bash
git add src/descope_mgmt/cli/tenant_cmds.py tests/unit/cli/test_tenant_cmds.py
git commit -m "feat: integrate TenantManager with tenant list command"
```

---

## Task 2: Create Tenant Create Command

**Files:**
- Modify: `src/descope_mgmt/cli/tenant_cmds.py`
- Modify: `src/descope_mgmt/cli/main.py:47`
- Modify: `tests/unit/cli/test_tenant_cmds.py`

**Step 1: Write failing tests**

Add to `tests/unit/cli/test_tenant_cmds.py`:
```python
def test_tenant_create_shows_help() -> None:
    """Test that tenant create command shows help."""
    runner = CliRunner()
    result = runner.invoke(cli, ["tenant", "create", "--help"])
    assert result.exit_code == 0
    assert "Create a new tenant" in result.output


@patch("descope_mgmt.cli.tenant_cmds.TenantManager")
def test_tenant_create_with_required_args(mock_manager_class: Mock) -> None:
    """Test tenant create with required arguments."""
    mock_manager = Mock()
    created = TenantConfig(id="new-tenant", name="New Tenant")
    mock_manager.create_tenant.return_value = created
    mock_manager_class.return_value = mock_manager

    runner = CliRunner()
    result = runner.invoke(
        cli, ["tenant", "create", "--id", "new-tenant", "--name", "New Tenant"]
    )

    assert result.exit_code == 0
    assert "Created tenant" in result.output or "new-tenant" in result.output
```

**Step 2: Run tests to verify they fail**

```bash
pytest tests/unit/cli/test_tenant_cmds.py::test_tenant_create_shows_help -v
```
Expected: FAIL with "No such command 'create'"

**Step 3: Implement tenant create command**

Add to `src/descope_mgmt/cli/tenant_cmds.py`:
```python
@click.command()
@click.option("--id", "tenant_id", required=True, help="Tenant ID (unique identifier)")
@click.option("--name", required=True, help="Tenant display name")
@click.option("--domain", "domains", multiple=True, help="Tenant domains (can specify multiple)")
@click.pass_context
def create_tenant(
    ctx: click.Context, tenant_id: str, name: str, domains: tuple[str, ...]
) -> None:
    """Create a new tenant in the current project."""
    console = get_console()
    verbose = ctx.obj.get("verbose", False)
    dry_run = ctx.obj.get("dry_run", False)

    # Build tenant config
    from descope_mgmt.types.tenant import TenantConfig

    tenant_config = TenantConfig(
        id=tenant_id,
        name=name,
        domains=list(domains) if domains else None,
    )

    if verbose:
        console.log(f"Creating tenant: {tenant_config.model_dump_json(indent=2)}")

    if dry_run:
        console.print("[yellow]DRY RUN: Would create tenant[/yellow]")
        console.print(f"  ID: {tenant_id}")
        console.print(f"  Name: {name}")
        if domains:
            console.print(f"  Domains: {', '.join(domains)}")
        return

    # Initialize services
    rate_limiter = DescopeRateLimiter()
    client = DescopeClient(
        project_id="placeholder",
        management_key="placeholder",
        rate_limiter=rate_limiter,
    )
    manager = TenantManager(client)

    # Create tenant
    try:
        created = manager.create_tenant(tenant_config)
        console.print(f"[green]✓[/green] Created tenant: {created.id}")
    except Exception as e:
        console.print(f"[red]✗[/red] Failed to create tenant: {e}")
        raise click.Abort()
```

Update `src/descope_mgmt/cli/main.py` to register command:
```python
from descope_mgmt.cli.tenant_cmds import create_tenant, list_tenants

# Register tenant commands
tenant.add_command(list_tenants, name="list")
tenant.add_command(create_tenant, name="create")
```

**Step 4: Run tests to verify they pass**

```bash
pytest tests/unit/cli/test_tenant_cmds.py -v
```
Expected: PASS (7 tests)

**Step 5: Commit**

```bash
git add src/descope_mgmt/cli/tenant_cmds.py src/descope_mgmt/cli/main.py tests/unit/cli/test_tenant_cmds.py
git commit -m "feat: add tenant create command with validation"
```

---

## Task 3: Add Dry-Run and Verbose Support

**Files:**
- Modify: `tests/unit/cli/test_tenant_cmds.py`

**Step 1: Write tests for dry-run mode**

Add to `tests/unit/cli/test_tenant_cmds.py`:
```python
def test_tenant_create_dry_run_mode() -> None:
    """Test tenant create in dry-run mode."""
    runner = CliRunner()
    result = runner.invoke(
        cli,
        [
            "--dry-run",
            "tenant",
            "create",
            "--id",
            "test-tenant",
            "--name",
            "Test Tenant",
        ],
    )

    assert result.exit_code == 0
    assert "DRY RUN" in result.output
    assert "Would create tenant" in result.output


def test_tenant_create_verbose_mode() -> None:
    """Test tenant create in verbose mode."""
    runner = CliRunner()
    result = runner.invoke(
        cli,
        [
            "--verbose",
            "--dry-run",
            "tenant",
            "create",
            "--id",
            "test-tenant",
            "--name",
            "Test Tenant",
        ],
    )

    assert result.exit_code == 0
    assert "Creating tenant" in result.output
```

**Step 2: Run tests to verify they pass**

```bash
pytest tests/unit/cli/test_tenant_cmds.py -v
```
Expected: PASS (9 tests)

**Step 3: Manual testing**

```bash
descope-mgmt tenant create --help
descope-mgmt --dry-run tenant create --id test --name "Test Tenant"
descope-mgmt --verbose --dry-run tenant create --id test --name "Test Tenant" --domain example.com
```
Expected: Commands work, dry-run prevents creation

**Step 4: Run full test suite**

```bash
pytest tests/ -v --cov=src/descope_mgmt --cov-report=term-missing
```
Expected: All tests pass (84+ tests), coverage >90%

**Step 5: Commit**

```bash
git add tests/unit/cli/test_tenant_cmds.py
git commit -m "test: add dry-run and verbose tests for tenant create"
```

---

## Chunk Complete Checklist

- [ ] Tenant list integrated with TenantManager
- [ ] Tenant create command implemented
- [ ] Dry-run mode functional
- [ ] Verbose mode functional
- [ ] All tests passing (84+ tests)
- [ ] 3 commits created
- [ ] **CHECKPOINT 1**: Tenant commands functional
- [ ] Ready for chunk 5 (tenant update)
