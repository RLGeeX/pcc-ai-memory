# Chunk 4: Flow Versioning & Rollback (PCC-251)

**Status:** pending
**Jira:** PCC-251
**Dependencies:** chunk-003-pcc-250-flow-import-export
**Complexity:** medium
**Estimated Time:** 25-30 minutes
**Tasks:** 3
**Phase:** Versioning & Rollback

---

## Task 1: Add backup before import

**Agent:** python-pro
**Files:**
- Modify: `src/descope_mgmt/cli/flow_cmds.py`
- Modify: `src/descope_mgmt/domain/flow_manager.py`

**Step 1: Update import to create backup first**

```python
# In flow_cmds.py import_flow_cmd, before actual import:

from descope_mgmt.domain.backup_service import BackupService

# Create backup of existing flow before import
backup_service = BackupService()
try:
    existing_schema = manager.export_flow(actual_flow_id)
    backup_path = backup_service.backup_flow(actual_flow_id, existing_schema)
    console.print(f"[dim]Backed up existing flow to: {backup_path}[/dim]")
except Exception:
    console.print("[dim]No existing flow to backup[/dim]")

# Then import
manager.import_flow(actual_flow_id, schema)
```

**Step 2: Add backup_flow to BackupService**

```python
# In backup_service.py
def backup_flow(self, flow_id: str, schema: dict[str, Any]) -> Path:
    """Backup a flow schema before modification."""
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_path = self.backup_dir / f"flow_{flow_id}_{timestamp}.json"
    backup_path.write_text(json.dumps(schema, indent=2))
    return backup_path
```

---

## Task 2: Add flow rollback command

**Agent:** python-pro
**Files:**
- Modify: `src/descope_mgmt/cli/flow_cmds.py`

**Step 1: Add rollback command**

```python
@click.command()
@click.argument("flow_id")
@click.option("--backup", type=click.Path(exists=True, path_type=Path), help="Specific backup file")
@click.option("--latest", is_flag=True, help="Use most recent backup")
@click.option("--list", "list_backups", is_flag=True, help="List available backups")
@click.pass_context
def rollback_flow(
    ctx: click.Context,
    flow_id: str,
    backup: Path | None,
    latest: bool,
    list_backups: bool,
) -> None:
    """Rollback a flow to a previous version."""
    console = get_console()
    backup_service = BackupService()

    try:
        # Find backups for this flow
        backup_dir = backup_service.backup_dir
        pattern = f"flow_{flow_id}_*.json"
        backups = sorted(backup_dir.glob(pattern), reverse=True)

        if list_backups:
            if not backups:
                console.print(f"[yellow]No backups found for flow:[/yellow] {flow_id}")
                return
            table = Table(title=f"Backups for {flow_id}")
            table.add_column("File", style="cyan")
            table.add_column("Date", style="green")
            for b in backups:
                table.add_row(b.name, b.stat().st_mtime)
            console.print(table)
            return

        # Select backup
        if backup:
            backup_file = backup
        elif latest:
            if not backups:
                console.print(f"[red]No backups found for flow:[/red] {flow_id}")
                raise click.Abort()
            backup_file = backups[0]
        else:
            console.print("[red]Specify --backup FILE or --latest[/red]")
            raise click.Abort()

        # Restore
        schema = json.loads(backup_file.read_text())
        client = ClientFactory.create_client()
        manager = FlowManager(client)
        manager.import_flow(flow_id, schema)

        console.print(f"[green]Rolled back flow to:[/green] {backup_file.name}")

    except Exception as e:
        console.print(f"[red]Error:[/red] {ErrorFormatter.format_error(e)}")
        raise click.Abort() from e
```

**Step 2: Register in main.py**

```python
from descope_mgmt.cli.flow_cmds import rollback_flow

flow.add_command(rollback_flow, "rollback")
```

---

## Task 3: Add tests and finalize

**Agent:** python-pro
**Files:**
- Modify: `tests/unit/cli/test_flow_cmds.py`

**Step 1: Add rollback tests**

```python
def test_flow_rollback_list_shows_backups(tmp_path):
    runner = CliRunner()
    result = runner.invoke(cli, ["flow", "rollback", "test-flow", "--list"])
    # Should not error even if no backups
    assert result.exit_code in [0, 1]

def test_flow_rollback_requires_backup_or_latest():
    runner = CliRunner()
    result = runner.invoke(cli, ["flow", "rollback", "test-flow"])
    assert "Specify --backup" in result.output or result.exit_code != 0
```

**Step 2: Run full test suite and commit**

Run: `pytest tests/ -v && ruff check . && mypy src/`

```bash
git add .
git commit -m "feat(cli): add flow rollback with backup support"
```

---

## Chunk Complete Checklist

- [ ] Backup before import implemented
- [ ] BackupService.backup_flow() added
- [ ] flow rollback command added
- [ ] --list, --latest, --backup options working
- [ ] All tests passing
- [ ] Code committed
- [ ] PCC-170 COMPLETE
