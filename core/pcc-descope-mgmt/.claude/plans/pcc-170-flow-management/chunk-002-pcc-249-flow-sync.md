# Chunk 2: Flow Sync Command (PCC-249)

**Status:** pending
**Jira:** PCC-249
**Dependencies:** chunk-001-pcc-248-flow-templates
**Complexity:** medium
**Estimated Time:** 20-25 minutes
**Tasks:** 2
**Phase:** Flow Sync

---

## Task 1: Add flow sync --dry-run command

**Agent:** python-pro
**Files:**
- Modify: `src/descope_mgmt/cli/flow_cmds.py`
- Modify: `src/descope_mgmt/cli/main.py`
- Test: `tests/unit/cli/test_flow_cmds.py`

**Step 1: Add sync command to flow_cmds.py**

```python
@click.command()
@click.option("--config", "config_file", type=click.Path(exists=True, path_type=Path), help="Config file with flows")
@click.option("--dry-run", is_flag=True, default=True, help="Preview changes without applying")
@click.option("--apply", "apply_changes", is_flag=True, help="Apply changes to Descope")
@click.pass_context
def sync_flows(
    ctx: click.Context,
    config_file: Path | None,
    dry_run: bool,
    apply_changes: bool,
) -> None:
    """Sync flows from config to Descope."""
    console = get_console()

    if apply_changes:
        dry_run = False

    try:
        client = ClientFactory.create_client()
        manager = FlowManager(client)

        # Get current flows
        current_flows = manager.list_flows()

        if dry_run:
            console.print("[yellow]DRY RUN[/yellow] - No changes will be applied")

        # Display current state
        table = Table(title="Flow Sync Preview")
        table.add_column("Flow ID", style="cyan")
        table.add_column("Status", style="green")

        for flow in current_flows:
            table.add_row(flow.id, "exists")

        console.print(table)

    except Exception as e:
        console.print(f"[red]Error:[/red] {ErrorFormatter.format_error(e)}")
        raise click.Abort() from e
```

**Step 2: Register command in main.py**

```python
from descope_mgmt.cli.flow_cmds import list_flows, deploy_flow, sync_flows

flow.add_command(sync_flows, "sync")
```

**Step 3: Test the command**

Run: `descope-mgmt flow sync --dry-run`

---

## Task 2: Add tests for flow sync

**Agent:** python-pro
**Files:**
- Create: `tests/unit/cli/test_flow_cmds.py`

**Step 1: Write CLI tests**

```python
from click.testing import CliRunner
from descope_mgmt.cli.main import cli

def test_flow_sync_dry_run_shows_preview():
    runner = CliRunner()
    result = runner.invoke(cli, ["flow", "sync", "--dry-run"])
    assert result.exit_code == 0
    assert "DRY RUN" in result.output
```

**Step 2: Run tests and commit**

Run: `pytest tests/unit/cli/test_flow_cmds.py -v && ruff check . && mypy src/`

```bash
git add src/descope_mgmt/cli/flow_cmds.py src/descope_mgmt/cli/main.py tests/unit/cli/test_flow_cmds.py
git commit -m "feat(cli): add flow sync command with dry-run mode"
```

---

## Chunk Complete Checklist

- [ ] flow sync --dry-run command added
- [ ] Command registered in main.py
- [ ] CLI tests written
- [ ] All tests passing
- [ ] Code committed
- [ ] Ready for chunk 3
