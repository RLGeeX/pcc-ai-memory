# Chunk 7: Flow Delete CLI Command

**Status:** pending
**Dependencies:** chunk-006-flow-delete-manager
**Complexity:** simple
**Estimated Time:** 10 minutes
**Tasks:** 2
**Phase:** Delete Commands
**Jira:** PCC-254

---

## Task 1: Create delete_flow CLI Command

**Agent:** python-pro
**Files:**
- Modify: `src/descope_mgmt/cli/flow_cmds.py`
- Modify: `tests/unit/cli/test_flow_cmds.py`

**Step 1: Add tests for flow delete CLI**

Add to `tests/unit/cli/test_flow_cmds.py`:

```python
from unittest.mock import MagicMock, patch
from pathlib import Path
from click.testing import CliRunner

from descope_mgmt.cli.flow_cmds import delete_flow_cmd


class TestDeleteFlowCLI:
    """Tests for flow delete CLI command."""

    def test_delete_flow_success(self) -> None:
        """Test successful flow deletion."""
        runner = CliRunner()

        with patch("descope_mgmt.cli.flow_cmds.ClientFactory"):
            with patch("descope_mgmt.cli.flow_cmds.FlowManager") as mock_manager_cls:
                mock_manager = MagicMock()
                mock_manager.get_flow.return_value = MagicMock(
                    id="login", name="Login Flow", flow_type="login"
                )
                mock_manager.delete_flow_with_backup.return_value = Path(
                    "/backups/login.json"
                )
                mock_manager_cls.return_value = mock_manager

                result = runner.invoke(
                    delete_flow_cmd, ["login", "--force"], obj={}
                )

                assert result.exit_code == 0
                assert "deleted" in result.output.lower()
                assert "backup" in result.output.lower()

    def test_delete_flow_not_found(self) -> None:
        """Test delete for non-existent flow."""
        runner = CliRunner()

        with patch("descope_mgmt.cli.flow_cmds.ClientFactory"):
            with patch("descope_mgmt.cli.flow_cmds.FlowManager") as mock_manager_cls:
                mock_manager = MagicMock()
                mock_manager.get_flow.return_value = None
                mock_manager_cls.return_value = mock_manager

                result = runner.invoke(
                    delete_flow_cmd, ["nonexistent", "--force"], obj={}
                )

                assert result.exit_code != 0
                assert "not found" in result.output.lower()

    def test_delete_flow_confirmation_prompt(self) -> None:
        """Test delete prompts for confirmation without --force."""
        runner = CliRunner()

        with patch("descope_mgmt.cli.flow_cmds.ClientFactory"):
            with patch("descope_mgmt.cli.flow_cmds.FlowManager") as mock_manager_cls:
                mock_manager = MagicMock()
                mock_manager.get_flow.return_value = MagicMock(
                    id="login", name="Login", flow_type="login"
                )
                mock_manager_cls.return_value = mock_manager

                # Decline confirmation
                result = runner.invoke(
                    delete_flow_cmd, ["login"], obj={}, input="n\n"
                )

                assert "cancelled" in result.output.lower()
                mock_manager.delete_flow_with_backup.assert_not_called()
```

**Step 2: Run tests to verify they fail**

```bash
pytest tests/unit/cli/test_flow_cmds.py::TestDeleteFlowCLI -v
```

Expected: FAIL (delete_flow_cmd not found)

**Step 3: Implement delete_flow_cmd**

Add to `src/descope_mgmt/cli/flow_cmds.py`:

```python
@click.command()
@click.argument("flow_id")
@click.option("--force", is_flag=True, help="Skip confirmation and dependency checks")
@click.option("--no-backup", is_flag=True, help="Skip backup creation (dangerous)")
@click.pass_context
def delete_flow_cmd(
    ctx: click.Context,
    flow_id: str,
    force: bool,
    no_backup: bool,
) -> None:
    """Delete a flow from the current project.

    Creates an automatic backup before deletion unless --no-backup is specified.
    Use --force to skip confirmation and dependency checks.
    """
    console = get_console()
    dry_run = ctx.obj.get("dry_run", False)

    # Initialize services
    client = ClientFactory.create_client()
    manager = FlowManager(client)

    # Verify flow exists
    flow = manager.get_flow(flow_id)
    if flow is None:
        console.print(f"[red]Error:[/red] Flow not found: {flow_id}")
        raise click.Abort()

    # Display flow info
    console.print("\n[bold red]WARNING: About to delete flow[/bold red]")
    console.print(f"  ID: {flow.id}")
    console.print(f"  Name: {flow.name}")
    console.print(f"  Type: {flow.flow_type}")

    # Check dependencies unless force
    if not force:
        deps = manager.check_flow_dependencies(flow_id)
        if deps:
            console.print(f"\n[yellow]Warning: Flow has dependencies:[/yellow]")
            for dep in deps:
                console.print(f"  - {dep}")
            console.print("[yellow]Use --force to delete anyway.[/yellow]")
            raise click.Abort()

    if no_backup:
        console.print("\n[bold yellow]NO BACKUP will be created![/bold yellow]\n")
    else:
        console.print("\n[dim]A backup will be created before deletion.[/dim]\n")

    if dry_run:
        console.print("[yellow]DRY RUN: Would delete flow[/yellow]")
        return

    # Confirmation prompt
    if not force:
        confirmed = click.confirm("Are you sure you want to delete this flow?")
        if not confirmed:
            console.print("[dim]Deletion cancelled.[/dim]")
            return

    # Delete flow
    try:
        if no_backup:
            manager.delete_flow(flow_id)
            console.print(f"[green]Deleted flow:[/green] {flow_id}")
        else:
            backup_service = BackupService()
            backup_path = manager.delete_flow_with_backup(
                flow_id,
                backup_service=backup_service,
                force=force,
            )
            console.print(f"[green]Deleted flow:[/green] {flow_id}")
            console.print(f"[dim]Backup saved to: {backup_path}[/dim]")
    except Exception as e:
        console.print(f"[red]Error:[/red] {ErrorFormatter.format_error(e)}")
        raise click.Abort() from e
```

**Step 4: Run tests to verify they pass**

```bash
pytest tests/unit/cli/test_flow_cmds.py -v
```

Expected: PASS

**Step 5: Commit**

```bash
git add src/descope_mgmt/cli/flow_cmds.py tests/unit/cli/test_flow_cmds.py
git commit -m "feat(cli): add flow delete command with backup and confirmation"
```

---

## Task 2: Register delete_flow_cmd in Main CLI

**Agent:** python-pro
**Files:**
- Modify: `src/descope_mgmt/cli/main.py`
- Modify: `tests/unit/cli/test_main.py`

**Step 1: Add test for command registration**

```python
def test_flow_delete_command_registered() -> None:
    """Test flow delete command is registered."""
    runner = CliRunner()
    result = runner.invoke(cli, ["flow", "delete", "--help"])
    assert result.exit_code == 0
    assert "Delete a flow" in result.output
```

**Step 2: Register the command**

In `src/descope_mgmt/cli/main.py`, add to the flow group:

```python
from descope_mgmt.cli.flow_cmds import (
    list_flows,
    deploy_flow,
    sync_flows,
    export_flow_cmd,
    import_flow_cmd,
    rollback_flow,
    delete_flow_cmd,  # Add this import
)

# In the flow group registration section:
flow.add_command(delete_flow_cmd, name="delete")
```

**Step 3: Run tests to verify they pass**

```bash
pytest tests/unit/cli/test_main.py -v
```

Expected: PASS

**Step 4: Test CLI manually**

```bash
descope-mgmt flow delete --help
```

Expected: Shows help for flow delete command

**Step 5: Commit**

```bash
git add src/descope_mgmt/cli/main.py tests/unit/cli/test_main.py
git commit -m "feat(cli): register flow delete command"
```

---

## Chunk Complete Checklist

- [ ] delete_flow_cmd CLI command created
- [ ] Confirmation prompt working
- [ ] --force and --no-backup options
- [ ] Dependency check display
- [ ] Command registered in main CLI
- [ ] 4+ tests for flow delete
- [ ] All tests passing
- [ ] Code committed
- [ ] Ready for Phase 3 (Audit Enhancements)
