# Chunk 6: Tenant Delete Command

**Status:** pending
**Dependencies:** chunk-005-tenant-update
**Complexity:** medium
**Estimated Time:** 40 minutes
**Tasks:** 3

---

## Task 1: Implement Tenant Delete Command

**Files:**
- Modify: `src/descope_mgmt/cli/tenant_cmds.py`
- Modify: `src/descope_mgmt/cli/main.py:49`
- Test: `tests/unit/cli/test_tenant_cmds.py`

**Step 1: Write failing tests**

Add to `tests/unit/cli/test_tenant_cmds.py`:
```python
def test_tenant_delete_shows_help() -> None:
    """Test that tenant delete command shows help."""
    runner = CliRunner()
    result = runner.invoke(cli, ["tenant", "delete", "--help"])
    assert result.exit_code == 0
    assert "Delete a tenant" in result.output


@patch("descope_mgmt.cli.tenant_cmds.TenantManager")
def test_tenant_delete_with_confirmation(mock_manager_class: Mock) -> None:
    """Test tenant delete with confirmation prompt."""
    mock_manager = Mock()
    existing = TenantConfig(id="test-tenant", name="Test Tenant")
    mock_manager.get_tenant.return_value = existing
    mock_manager_class.return_value = mock_manager

    runner = CliRunner()
    # Simulate user confirming deletion (input 'y')
    result = runner.invoke(
        cli, ["tenant", "delete", "--id", "test-tenant"], input="y\n"
    )

    assert result.exit_code == 0
    mock_manager.delete_tenant.assert_called_once_with("test-tenant")
```

**Step 2: Run tests to verify they fail**

```bash
pytest tests/unit/cli/test_tenant_cmds.py::test_tenant_delete_shows_help -v
```
Expected: FAIL with "No such command 'delete'"

**Step 3: Implement tenant delete command**

Add to `src/descope_mgmt/cli/tenant_cmds.py`:
```python
@click.command()
@click.option("--id", "tenant_id", required=True, help="Tenant ID to delete")
@click.option("--force", is_flag=True, help="Skip confirmation prompt")
@click.pass_context
def delete_tenant(ctx: click.Context, tenant_id: str, force: bool) -> None:
    """Delete a tenant from the current project.

    WARNING: This operation cannot be undone. All tenant data will be permanently deleted.
    """
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

    # Verify tenant exists
    existing = manager.get_tenant(tenant_id)
    if existing is None:
        console.print(f"[red]✗[/red] Tenant not found: {tenant_id}")
        raise click.Abort()

    # Display tenant info
    console.print(f"\n[bold red]WARNING: About to delete tenant[/bold red]")
    console.print(f"  ID: {existing.id}")
    console.print(f"  Name: {existing.name}")
    if existing.domains:
        console.print(f"  Domains: {', '.join(existing.domains)}")
    console.print("\n[yellow]This operation cannot be undone![/yellow]\n")

    if dry_run:
        console.print("[yellow]DRY RUN: Would delete tenant[/yellow]")
        return

    # Confirmation prompt
    if not force:
        confirmed = click.confirm("Are you sure you want to delete this tenant?")
        if not confirmed:
            console.print("[dim]Deletion cancelled.[/dim]")
            return

    # Delete tenant
    try:
        manager.delete_tenant(tenant_id)
        console.print(f"[green]✓[/green] Deleted tenant: {tenant_id}")
    except Exception as e:
        console.print(f"[red]✗[/red] Failed to delete tenant: {e}")
        raise click.Abort()
```

Update `src/descope_mgmt/cli/main.py`:
```python
from descope_mgmt.cli.tenant_cmds import (
    create_tenant,
    delete_tenant,
    list_tenants,
    update_tenant,
)

# Register tenant commands
tenant.add_command(list_tenants, name="list")
tenant.add_command(create_tenant, name="create")
tenant.add_command(update_tenant, name="update")
tenant.add_command(delete_tenant, name="delete")
```

**Step 4: Run tests to verify they pass**

```bash
pytest tests/unit/cli/test_tenant_cmds.py -v
```
Expected: PASS (15 tests)

**Step 5: Commit**

```bash
git add src/descope_mgmt/cli/tenant_cmds.py src/descope_mgmt/cli/main.py tests/unit/cli/test_tenant_cmds.py
git commit -m "feat: add tenant delete command with confirmation"
```

---

## Task 2: Test Delete with Force and Dry-Run

**Files:**
- Modify: `tests/unit/cli/test_tenant_cmds.py`

**Step 1: Write additional tests**

Add to `tests/unit/cli/test_tenant_cmds.py`:
```python
@patch("descope_mgmt.cli.tenant_cmds.TenantManager")
def test_tenant_delete_with_force_flag(mock_manager_class: Mock) -> None:
    """Test tenant delete with --force skips confirmation."""
    mock_manager = Mock()
    existing = TenantConfig(id="test-tenant", name="Test Tenant")
    mock_manager.get_tenant.return_value = existing
    mock_manager_class.return_value = mock_manager

    runner = CliRunner()
    result = runner.invoke(cli, ["tenant", "delete", "--id", "test-tenant", "--force"])

    assert result.exit_code == 0
    mock_manager.delete_tenant.assert_called_once_with("test-tenant")


@patch("descope_mgmt.cli.tenant_cmds.TenantManager")
def test_tenant_delete_dry_run_mode(mock_manager_class: Mock) -> None:
    """Test tenant delete in dry-run mode."""
    mock_manager = Mock()
    existing = TenantConfig(id="test-tenant", name="Test Tenant")
    mock_manager.get_tenant.return_value = existing
    mock_manager_class.return_value = mock_manager

    runner = CliRunner()
    result = runner.invoke(
        cli, ["--dry-run", "tenant", "delete", "--id", "test-tenant"]
    )

    assert result.exit_code == 0
    assert "DRY RUN" in result.output
    mock_manager.delete_tenant.assert_not_called()


@patch("descope_mgmt.cli.tenant_cmds.TenantManager")
def test_tenant_delete_cancelled_by_user(mock_manager_class: Mock) -> None:
    """Test tenant delete can be cancelled at prompt."""
    mock_manager = Mock()
    existing = TenantConfig(id="test-tenant", name="Test Tenant")
    mock_manager.get_tenant.return_value = existing
    mock_manager_class.return_value = mock_manager

    runner = CliRunner()
    # Simulate user declining deletion (input 'n')
    result = runner.invoke(
        cli, ["tenant", "delete", "--id", "test-tenant"], input="n\n"
    )

    assert result.exit_code == 0
    assert "cancelled" in result.output.lower()
    mock_manager.delete_tenant.assert_not_called()
```

**Step 2: Run tests to verify they pass**

```bash
pytest tests/unit/cli/test_tenant_cmds.py -v
```
Expected: PASS (18 tests)

**Step 3: Commit**

```bash
git add tests/unit/cli/test_tenant_cmds.py
git commit -m "test: add force flag and cancellation tests for tenant delete"
```

---

## Task 3: Verify All Tenant Commands

**Files:**
- None (verification only)

**Step 1: Test all tenant commands manually**

```bash
# List (should show empty or existing tenants)
descope-mgmt tenant list

# Create in dry-run
descope-mgmt --dry-run tenant create --id test --name "Test"

# Update in dry-run
descope-mgmt --dry-run tenant update --id test --name "Updated"

# Delete in dry-run
descope-mgmt --dry-run tenant delete --id test

# All help commands
descope-mgmt tenant --help
descope-mgmt tenant list --help
descope-mgmt tenant create --help
descope-mgmt tenant update --help
descope-mgmt tenant delete --help
```

**Step 2: Run full test suite**

```bash
pytest tests/ -v --cov=src/descope_mgmt --cov-report=html --cov-report=term-missing
```
Expected: All tests pass (95+ tests), coverage >90%

**Step 3: Run all quality checks**

```bash
mypy src/
ruff check .
ruff format --check .
lint-imports
pre-commit run --all-files
```
Expected: All checks pass

**Step 4: Create verification commit**

```bash
git add -A
git commit -m "chore: verify all tenant commands functional"
```

---

## Chunk Complete Checklist

- [ ] Tenant delete command implemented
- [ ] Confirmation prompt functional
- [ ] Force flag skips confirmation
- [ ] Dry-run mode prevents deletion
- [ ] Cancellation works correctly
- [ ] All tests passing (95+ tests)
- [ ] All quality checks passing
- [ ] 3 commits created
- [ ] Ready for chunk 7 (flow list)
