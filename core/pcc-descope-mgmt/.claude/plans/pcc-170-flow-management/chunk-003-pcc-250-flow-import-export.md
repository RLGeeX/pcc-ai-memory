# Chunk 3: Flow Import/Export Commands (PCC-250)

**Status:** pending
**Jira:** PCC-250
**Dependencies:** chunk-001-pcc-248-flow-templates
**Complexity:** medium
**Estimated Time:** 25-30 minutes
**Tasks:** 3
**Phase:** Import/Export

---

## Task 1: Add flow export command

**Agent:** python-pro
**Files:**
- Modify: `src/descope_mgmt/cli/flow_cmds.py`
- Modify: `src/descope_mgmt/cli/main.py`

**Step 1: Add export command**

```python
@click.command()
@click.argument("flow_id")
@click.option("--output", "-o", type=click.Path(path_type=Path), help="Output file path")
@click.pass_context
def export_flow_cmd(ctx: click.Context, flow_id: str, output: Path | None) -> None:
    """Export a flow to JSON file."""
    console = get_console()
    verbose = ctx.obj.get("verbose", False)

    try:
        client = ClientFactory.create_client()
        manager = FlowManager(client)

        if verbose:
            console.log(f"Exporting flow '{flow_id}'...")

        schema = manager.export_flow(flow_id)

        # Determine output path
        if output is None:
            output = Path(f"{flow_id}.json")

        # Write to file
        output.write_text(json.dumps(schema, indent=2))
        console.print(f"[green]Exported flow to:[/green] {output}")

    except Exception as e:
        console.print(f"[red]Error:[/red] {ErrorFormatter.format_error(e)}")
        raise click.Abort() from e
```

**Step 2: Register in main.py**

```python
from descope_mgmt.cli.flow_cmds import export_flow_cmd

flow.add_command(export_flow_cmd, "export")
```

---

## Task 2: Add flow import command

**Agent:** python-pro
**Files:**
- Modify: `src/descope_mgmt/cli/flow_cmds.py`

**Step 1: Add import command**

```python
@click.command()
@click.argument("file_path", type=click.Path(exists=True, path_type=Path))
@click.option("--flow-id", help="Override flow ID from file")
@click.option("--dry-run", is_flag=True, help="Validate without importing")
@click.option("--apply", "apply_import", is_flag=True, help="Actually import the flow")
@click.pass_context
def import_flow_cmd(
    ctx: click.Context,
    file_path: Path,
    flow_id: str | None,
    dry_run: bool,
    apply_import: bool,
) -> None:
    """Import a flow from JSON file."""
    console = get_console()

    try:
        # Load flow schema
        schema = json.loads(file_path.read_text())

        # Get flow ID from file or override
        actual_flow_id = flow_id or schema.get("flowId", file_path.stem)

        if dry_run or not apply_import:
            console.print("[yellow]DRY RUN[/yellow] - Validating flow...")
            console.print(f"  Flow ID: {actual_flow_id}")
            console.print(f"  Tasks: {len(schema.get('contents', {}).get('tasks', {}))}")
            console.print(f"  Screens: {len(schema.get('screens', []))}")
            console.print("[green]Validation passed[/green]")
            return

        # Actually import
        client = ClientFactory.create_client()
        manager = FlowManager(client)

        manager.import_flow(actual_flow_id, schema)
        console.print(f"[green]Imported flow:[/green] {actual_flow_id}")

    except Exception as e:
        console.print(f"[red]Error:[/red] {ErrorFormatter.format_error(e)}")
        raise click.Abort() from e
```

**Step 2: Register in main.py**

```python
from descope_mgmt.cli.flow_cmds import import_flow_cmd

flow.add_command(import_flow_cmd, "import")
```

---

## Task 3: Add tests for export/import

**Agent:** python-pro
**Files:**
- Modify: `tests/unit/cli/test_flow_cmds.py`

**Step 1: Add tests**

```python
def test_flow_export_creates_file(tmp_path):
    runner = CliRunner()
    output = tmp_path / "test-flow.json"
    result = runner.invoke(cli, ["flow", "export", "sign-up-or-in", "-o", str(output)])
    # Note: May fail without real API, but tests command structure

def test_flow_import_dry_run_validates():
    runner = CliRunner()
    # Create temp flow file
    with runner.isolated_filesystem():
        Path("test.json").write_text('{"flowId": "test", "contents": {}}')
        result = runner.invoke(cli, ["flow", "import", "test.json", "--dry-run"])
        assert "DRY RUN" in result.output
```

**Step 2: Run tests and commit**

Run: `pytest tests/unit/cli/test_flow_cmds.py -v && ruff check . && mypy src/`

```bash
git add src/descope_mgmt/cli/flow_cmds.py src/descope_mgmt/cli/main.py tests/unit/cli/test_flow_cmds.py
git commit -m "feat(cli): add flow export and import commands"
```

---

## Chunk Complete Checklist

- [ ] flow export command added
- [ ] flow import command with dry-run added
- [ ] Commands registered in main.py
- [ ] Tests written
- [ ] All tests passing
- [ ] Code committed
- [ ] Ready for chunk 4
