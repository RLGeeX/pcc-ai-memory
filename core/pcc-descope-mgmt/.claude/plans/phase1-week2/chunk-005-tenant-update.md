# Chunk 5: Tenant Update Command

**Status:** pending
**Dependencies:** chunk-004-tenant-create
**Complexity:** medium
**Estimated Time:** 45 minutes
**Tasks:** 3

---

## Task 1: Create Diff Display Utility

**Files:**
- Create: `src/descope_mgmt/cli/diff.py`
- Test: `tests/unit/cli/test_diff.py`

**Step 1: Write failing tests**

Create `tests/unit/cli/test_diff.py`:
```python
"""Tests for diff display utilities."""

from descope_mgmt.cli.diff import display_tenant_diff
from descope_mgmt.types.tenant import TenantConfig


def test_display_tenant_diff_shows_changes(capsys) -> None:
    """Test that display_tenant_diff shows field changes."""
    old = TenantConfig(id="test", name="Old Name", domains=["old.com"])
    new = TenantConfig(id="test", name="New Name", domains=["new.com"])

    display_tenant_diff(old, new)

    captured = capsys.readouterr()
    assert "name" in captured.out
    assert "Old Name" in captured.out
    assert "New Name" in captured.out


def test_display_tenant_diff_no_changes(capsys) -> None:
    """Test display with no changes."""
    tenant = TenantConfig(id="test", name="Name")

    display_tenant_diff(tenant, tenant)

    captured = capsys.readouterr()
    assert "No changes" in captured.out or "identical" in captured.out.lower()
```

**Step 2: Run tests to verify they fail**

```bash
pytest tests/unit/cli/test_diff.py -v
```
Expected: FAIL with "No module named 'descope_mgmt.cli.diff'"

**Step 3: Implement diff display**

Create `src/descope_mgmt/cli/diff.py`:
```python
"""Utilities for displaying configuration diffs."""

from descope_mgmt.cli.output import get_console
from descope_mgmt.types.tenant import TenantConfig


def display_tenant_diff(old: TenantConfig, new: TenantConfig) -> None:
    """Display differences between two tenant configurations.

    Args:
        old: Original tenant configuration
        new: Updated tenant configuration
    """
    console = get_console()

    # Get model dicts for comparison
    old_dict = old.model_dump(exclude_none=True)
    new_dict = new.model_dump(exclude_none=True)

    changes = []
    for key in set(old_dict.keys()) | set(new_dict.keys()):
        old_val = old_dict.get(key)
        new_val = new_dict.get(key)

        if old_val != new_val:
            changes.append((key, old_val, new_val))

    if not changes:
        console.print("[dim]No changes detected.[/dim]")
        return

    console.print("[bold]Changes:[/bold]")
    for field, old_val, new_val in changes:
        console.print(f"  {field}:")
        console.print(f"    [red]- {old_val}[/red]")
        console.print(f"    [green]+ {new_val}[/green]")
```

**Step 4: Run tests to verify they pass**

```bash
pytest tests/unit/cli/test_diff.py -v
```
Expected: PASS (2 tests)

**Step 5: Commit**

```bash
git add src/descope_mgmt/cli/diff.py tests/unit/cli/test_diff.py
git commit -m "feat: add diff display utility for tenant changes"
```

---

## Task 2: Implement Tenant Update Command

**Files:**
- Modify: `src/descope_mgmt/cli/tenant_cmds.py`
- Modify: `src/descope_mgmt/cli/main.py:48`
- Test: `tests/unit/cli/test_tenant_cmds.py`

**Step 1: Write failing tests**

Add to `tests/unit/cli/test_tenant_cmds.py`:
```python
def test_tenant_update_shows_help() -> None:
    """Test that tenant update command shows help."""
    runner = CliRunner()
    result = runner.invoke(cli, ["tenant", "update", "--help"])
    assert result.exit_code == 0
    assert "Update an existing tenant" in result.output


@patch("descope_mgmt.cli.tenant_cmds.TenantManager")
def test_tenant_update_with_changes(mock_manager_class: Mock) -> None:
    """Test tenant update with field changes."""
    mock_manager = Mock()

    # Mock existing tenant
    existing = TenantConfig(id="test-tenant", name="Old Name")
    mock_manager.get_tenant.return_value = existing

    # Mock update result
    updated = TenantConfig(id="test-tenant", name="New Name")
    mock_manager.update_tenant.return_value = updated
    mock_manager_class.return_value = mock_manager

    runner = CliRunner()
    result = runner.invoke(
        cli, ["tenant", "update", "--id", "test-tenant", "--name", "New Name"]
    )

    assert result.exit_code == 0
    assert "Updated tenant" in result.output or "test-tenant" in result.output
```

**Step 2: Run tests to verify they fail**

```bash
pytest tests/unit/cli/test_tenant_cmds.py::test_tenant_update_shows_help -v
```
Expected: FAIL with "No such command 'update'"

**Step 3: Implement tenant update command**

Add to `src/descope_mgmt/cli/tenant_cmds.py`:
```python
from descope_mgmt.cli.diff import display_tenant_diff


@click.command()
@click.option("--id", "tenant_id", required=True, help="Tenant ID to update")
@click.option("--name", help="New tenant display name")
@click.option("--domain", "domains", multiple=True, help="New tenant domains (replaces existing)")
@click.pass_context
def update_tenant(
    ctx: click.Context, tenant_id: str, name: str | None, domains: tuple[str, ...]
) -> None:
    """Update an existing tenant in the current project."""
    console = get_console()
    verbose = ctx.obj.get("verbose", False)
    dry_run = ctx.obj.get("dry_run", False)

    # Initialize services
    rate_limiter = DescopeRateLimiter()
    client = DescopeClient(
        project_id="placeholder",
        management_key="placeholder",
        rate_limiter=rate_limiter,
    )
    manager = TenantManager(client)

    # Get existing tenant
    existing = manager.get_tenant(tenant_id)
    if existing is None:
        console.print(f"[red]✗[/red] Tenant not found: {tenant_id}")
        raise click.Abort()

    # Build updated config
    from descope_mgmt.types.tenant import TenantConfig

    updated_config = TenantConfig(
        id=tenant_id,
        name=name if name else existing.name,
        domains=list(domains) if domains else existing.domains,
    )

    # Display diff
    if verbose or dry_run:
        console.print(f"\n[bold]Tenant: {tenant_id}[/bold]")
        display_tenant_diff(existing, updated_config)
        console.print()

    if dry_run:
        console.print("[yellow]DRY RUN: Would update tenant[/yellow]")
        return

    # Update tenant
    try:
        result = manager.update_tenant(updated_config)
        console.print(f"[green]✓[/green] Updated tenant: {result.id}")
    except Exception as e:
        console.print(f"[red]✗[/red] Failed to update tenant: {e}")
        raise click.Abort()
```

Update `src/descope_mgmt/cli/main.py`:
```python
from descope_mgmt.cli.tenant_cmds import create_tenant, list_tenants, update_tenant

# Register tenant commands
tenant.add_command(list_tenants, name="list")
tenant.add_command(create_tenant, name="create")
tenant.add_command(update_tenant, name="update")
```

**Step 4: Run tests to verify they pass**

```bash
pytest tests/unit/cli/test_tenant_cmds.py -v
```
Expected: PASS (11 tests)

**Step 5: Commit**

```bash
git add src/descope_mgmt/cli/tenant_cmds.py src/descope_mgmt/cli/main.py tests/unit/cli/test_tenant_cmds.py
git commit -m "feat: add tenant update command with diff display"
```

---

## Task 3: Test Update with Dry-Run Mode

**Files:**
- Modify: `tests/unit/cli/test_tenant_cmds.py`

**Step 1: Write tests for dry-run**

Add to `tests/unit/cli/test_tenant_cmds.py`:
```python
@patch("descope_mgmt.cli.tenant_cmds.TenantManager")
def test_tenant_update_dry_run_mode(mock_manager_class: Mock) -> None:
    """Test tenant update in dry-run mode doesn't make changes."""
    mock_manager = Mock()
    existing = TenantConfig(id="test-tenant", name="Old Name")
    mock_manager.get_tenant.return_value = existing
    mock_manager_class.return_value = mock_manager

    runner = CliRunner()
    result = runner.invoke(
        cli,
        [
            "--dry-run",
            "tenant",
            "update",
            "--id",
            "test-tenant",
            "--name",
            "New Name",
        ],
    )

    assert result.exit_code == 0
    assert "DRY RUN" in result.output
    mock_manager.update_tenant.assert_not_called()


@patch("descope_mgmt.cli.tenant_cmds.TenantManager")
def test_tenant_update_nonexistent_tenant(mock_manager_class: Mock) -> None:
    """Test updating nonexistent tenant shows error."""
    mock_manager = Mock()
    mock_manager.get_tenant.return_value = None
    mock_manager_class.return_value = mock_manager

    runner = CliRunner()
    result = runner.invoke(
        cli, ["tenant", "update", "--id", "nonexistent", "--name", "Name"]
    )

    assert result.exit_code != 0
    assert "not found" in result.output.lower()
```

**Step 2: Run tests to verify they pass**

```bash
pytest tests/unit/cli/test_tenant_cmds.py -v
```
Expected: PASS (13 tests)

**Step 3: Manual testing**

```bash
descope-mgmt tenant update --help
descope-mgmt --dry-run tenant update --id test --name "Updated Name"
```
Expected: Commands work, dry-run shows diff without updating

**Step 4: Run full test suite**

```bash
pytest tests/ -v --cov=src/descope_mgmt --cov-report=term-missing
```
Expected: All tests pass (91+ tests), coverage >90%

**Step 5: Commit**

```bash
git add tests/unit/cli/test_tenant_cmds.py
git commit -m "test: add dry-run and error handling tests for tenant update"
```

---

## Chunk Complete Checklist

- [ ] Diff display utility created
- [ ] Tenant update command implemented
- [ ] Dry-run mode shows diff without changes
- [ ] Nonexistent tenant handling
- [ ] All tests passing (91+ tests)
- [ ] 3 commits created
- [ ] Ready for chunk 6 (tenant delete)
