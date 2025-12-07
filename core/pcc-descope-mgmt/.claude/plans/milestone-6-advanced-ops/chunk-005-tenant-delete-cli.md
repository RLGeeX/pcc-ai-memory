# Chunk 5: Tenant Delete CLI Command Enhancement

**Status:** pending
**Dependencies:** chunk-004-tenant-delete-manager
**Complexity:** simple
**Estimated Time:** 10 minutes
**Tasks:** 2
**Phase:** Delete Commands
**Jira:** PCC-253

---

## Task 1: Enhance delete_tenant CLI with Backup

**Agent:** python-pro
**Files:**
- Modify: `src/descope_mgmt/cli/tenant_cmds.py`
- Modify: `tests/unit/cli/test_tenant_cmds.py`

**Step 1: Add tests for CLI delete with backup**

Add to `tests/unit/cli/test_tenant_cmds.py`:

```python
from unittest.mock import patch, MagicMock
from pathlib import Path
from click.testing import CliRunner

from descope_mgmt.cli.tenant_cmds import delete_tenant


class TestDeleteTenantCLI:
    """Tests for tenant delete CLI command."""

    def test_delete_shows_backup_path(self) -> None:
        """Test delete shows backup path on success."""
        runner = CliRunner()

        with patch("descope_mgmt.cli.tenant_cmds.ClientFactory") as mock_factory:
            with patch("descope_mgmt.cli.tenant_cmds.TenantManager") as mock_manager_cls:
                mock_manager = MagicMock()
                mock_manager.get_tenant.return_value = MagicMock(
                    id="t1", name="Test", domains=[]
                )
                mock_manager.delete_tenant_with_backup.return_value = Path(
                    "/backups/t1.json"
                )
                mock_manager_cls.return_value = mock_manager

                result = runner.invoke(
                    delete_tenant, ["--id", "t1", "--force"], obj={}
                )

                assert result.exit_code == 0
                assert "backup" in result.output.lower()
                assert "t1" in result.output

    def test_delete_without_force_prompts(self) -> None:
        """Test delete without --force prompts for confirmation."""
        runner = CliRunner()

        with patch("descope_mgmt.cli.tenant_cmds.ClientFactory"):
            with patch("descope_mgmt.cli.tenant_cmds.TenantManager") as mock_manager_cls:
                mock_manager = MagicMock()
                mock_manager.get_tenant.return_value = MagicMock(
                    id="t1", name="Test", domains=[]
                )
                mock_manager_cls.return_value = mock_manager

                # Simulate 'n' response to confirmation
                result = runner.invoke(
                    delete_tenant, ["--id", "t1"], obj={}, input="n\n"
                )

                assert "cancelled" in result.output.lower()
                mock_manager.delete_tenant_with_backup.assert_not_called()

    def test_delete_force_skips_prompt(self) -> None:
        """Test --force skips confirmation prompt."""
        runner = CliRunner()

        with patch("descope_mgmt.cli.tenant_cmds.ClientFactory"):
            with patch("descope_mgmt.cli.tenant_cmds.TenantManager") as mock_manager_cls:
                mock_manager = MagicMock()
                mock_manager.get_tenant.return_value = MagicMock(
                    id="t1", name="Test", domains=[]
                )
                mock_manager.delete_tenant_with_backup.return_value = Path("/b.json")
                mock_manager_cls.return_value = mock_manager

                result = runner.invoke(
                    delete_tenant, ["--id", "t1", "--force"], obj={}
                )

                mock_manager.delete_tenant_with_backup.assert_called_once()
```

**Step 2: Run tests to verify they fail**

```bash
pytest tests/unit/cli/test_tenant_cmds.py::TestDeleteTenantCLI -v
```

Expected: Some tests may fail due to current implementation

**Step 3: Update delete_tenant CLI command**

Update `src/descope_mgmt/cli/tenant_cmds.py`:

```python
@click.command()
@click.option("--id", "tenant_id", required=True, help="Tenant ID to delete")
@click.option("--force", is_flag=True, help="Skip confirmation prompt")
@click.pass_context
def delete_tenant(ctx: click.Context, tenant_id: str, force: bool) -> None:
    """Delete a tenant from the current project.

    Creates an automatic backup before deletion. Use --force to skip
    the confirmation prompt.
    """
    console = get_console()
    dry_run = ctx.obj.get("dry_run", False)

    # Initialize services
    client = ClientFactory.create_client()
    manager = TenantManager(client)
    backup_service = BackupService()

    # Verify tenant exists
    existing = manager.get_tenant(tenant_id)
    if existing is None:
        console.print(f"[red]Error:[/red] Tenant not found: {tenant_id}")
        raise click.Abort()

    # Display tenant info
    console.print("\n[bold red]WARNING: About to delete tenant[/bold red]")
    console.print(f"  ID: {existing.id}")
    console.print(f"  Name: {existing.name}")
    if existing.domains:
        console.print(f"  Domains: {', '.join(existing.domains)}")
    console.print("\n[dim]A backup will be created before deletion.[/dim]\n")

    if dry_run:
        console.print("[yellow]DRY RUN: Would delete tenant[/yellow]")
        return

    # Confirmation prompt
    if not force:
        confirmed = click.confirm("Are you sure you want to delete this tenant?")
        if not confirmed:
            console.print("[dim]Deletion cancelled.[/dim]")
            return

    # Delete tenant with backup
    try:
        backup_path = manager.delete_tenant_with_backup(
            tenant_id,
            backup_service=backup_service,
        )
        console.print(f"[green]Deleted tenant:[/green] {tenant_id}")
        console.print(f"[dim]Backup saved to: {backup_path}[/dim]")
    except Exception as e:
        console.print(f"[red]Error:[/red] {ErrorFormatter.format_error(e)}")
        raise click.Abort() from e
```

**Step 4: Run tests to verify they pass**

```bash
pytest tests/unit/cli/test_tenant_cmds.py -v
```

Expected: PASS

**Step 5: Commit**

```bash
git add src/descope_mgmt/cli/tenant_cmds.py tests/unit/cli/test_tenant_cmds.py
git commit -m "feat(cli): enhance tenant delete with automatic backup"
```

---

## Task 2: Add --no-backup Option

**Agent:** python-pro
**Files:**
- Modify: `src/descope_mgmt/cli/tenant_cmds.py`
- Modify: `tests/unit/cli/test_tenant_cmds.py`

**Step 1: Add test for --no-backup option**

```python
    def test_delete_no_backup_option(self) -> None:
        """Test --no-backup skips backup creation."""
        runner = CliRunner()

        with patch("descope_mgmt.cli.tenant_cmds.ClientFactory"):
            with patch("descope_mgmt.cli.tenant_cmds.TenantManager") as mock_manager_cls:
                mock_manager = MagicMock()
                mock_manager.get_tenant.return_value = MagicMock(
                    id="t1", name="Test", domains=[]
                )
                mock_manager_cls.return_value = mock_manager

                result = runner.invoke(
                    delete_tenant,
                    ["--id", "t1", "--force", "--no-backup"],
                    obj={},
                )

                assert result.exit_code == 0
                # Should call delete_tenant, not delete_tenant_with_backup
                mock_manager.delete_tenant.assert_called_once_with("t1")
                mock_manager.delete_tenant_with_backup.assert_not_called()
```

**Step 2: Run test to verify it fails**

```bash
pytest tests/unit/cli/test_tenant_cmds.py::TestDeleteTenantCLI::test_delete_no_backup_option -v
```

Expected: FAIL

**Step 3: Add --no-backup option**

Update delete_tenant command:

```python
@click.command()
@click.option("--id", "tenant_id", required=True, help="Tenant ID to delete")
@click.option("--force", is_flag=True, help="Skip confirmation prompt")
@click.option("--no-backup", is_flag=True, help="Skip backup creation (dangerous)")
@click.pass_context
def delete_tenant(
    ctx: click.Context, tenant_id: str, force: bool, no_backup: bool
) -> None:
    """Delete a tenant from the current project.

    Creates an automatic backup before deletion unless --no-backup is specified.
    Use --force to skip the confirmation prompt.
    """
    console = get_console()
    dry_run = ctx.obj.get("dry_run", False)

    client = ClientFactory.create_client()
    manager = TenantManager(client)

    existing = manager.get_tenant(tenant_id)
    if existing is None:
        console.print(f"[red]Error:[/red] Tenant not found: {tenant_id}")
        raise click.Abort()

    # Display warning
    console.print("\n[bold red]WARNING: About to delete tenant[/bold red]")
    console.print(f"  ID: {existing.id}")
    console.print(f"  Name: {existing.name}")
    if existing.domains:
        console.print(f"  Domains: {', '.join(existing.domains)}")

    if no_backup:
        console.print("\n[bold yellow]NO BACKUP will be created![/bold yellow]\n")
    else:
        console.print("\n[dim]A backup will be created before deletion.[/dim]\n")

    if dry_run:
        console.print("[yellow]DRY RUN: Would delete tenant[/yellow]")
        return

    if not force:
        confirmed = click.confirm("Are you sure you want to delete this tenant?")
        if not confirmed:
            console.print("[dim]Deletion cancelled.[/dim]")
            return

    try:
        if no_backup:
            manager.delete_tenant(tenant_id)
            console.print(f"[green]Deleted tenant:[/green] {tenant_id}")
        else:
            backup_service = BackupService()
            backup_path = manager.delete_tenant_with_backup(
                tenant_id, backup_service=backup_service
            )
            console.print(f"[green]Deleted tenant:[/green] {tenant_id}")
            console.print(f"[dim]Backup saved to: {backup_path}[/dim]")
    except Exception as e:
        console.print(f"[red]Error:[/red] {ErrorFormatter.format_error(e)}")
        raise click.Abort() from e
```

**Step 4: Run tests to verify they pass**

```bash
pytest tests/unit/cli/test_tenant_cmds.py -v
```

Expected: PASS

**Step 5: Commit**

```bash
git add src/descope_mgmt/cli/tenant_cmds.py tests/unit/cli/test_tenant_cmds.py
git commit -m "feat(cli): add --no-backup option to tenant delete"
```

---

## Chunk Complete Checklist

- [ ] delete_tenant CLI enhanced with backup
- [ ] --no-backup option added
- [ ] Confirmation prompt working
- [ ] 5+ tests for tenant delete
- [ ] All tests passing
- [ ] Code committed
- [ ] Ready for next chunk
