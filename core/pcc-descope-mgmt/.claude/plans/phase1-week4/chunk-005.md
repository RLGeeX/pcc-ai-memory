# Chunk 5: Flow Import Command (Dry-Run)

**Status:** pending
**Dependencies:** chunk-001, chunk-002, chunk-004
**Estimated Time:** 45 minutes

---

## Task 1: Implement Flow Import --dry-run

**Files:**
- Modify: `src/descope_mgmt/cli/flow.py`
- Create: `tests/integration/test_flow_import.py`

**Step 1: Write tests**

Create `tests/integration/test_flow_import.py`:
```python
"""Integration tests for flow import"""
import pytest
import json
from unittest.mock import Mock, patch
from click.testing import CliRunner
from descope_mgmt.cli.main import cli


@patch('descope_mgmt.cli.flow.DescopeApiClient')
def test_flow_import_dry_run(mock_client_class, tmp_path):
    """Should preview flow import without applying"""
    # Create flow file
    flow_file = tmp_path / "flow.json"
    flow_data = {
        "flow_id": "test-flow",
        "name": "Test Flow",
        "screens": [{"id": "email"}]
    }
    with open(flow_file, 'w') as f:
        json.dump(flow_data, f)

    # Mock client
    mock_client = Mock()
    mock_client.get_flow.side_effect = Exception("Not found")  # Flow doesn't exist
    mock_client_class.return_value = mock_client

    runner = CliRunner()
    result = runner.invoke(cli, [
        'flow', 'import',
        '--file', str(flow_file),
        '--dry-run'
    ])

    assert result.exit_code == 0
    assert "test-flow" in result.output
    assert ("dry-run" in result.output.lower() or "preview" in result.output.lower())
    # Should NOT have called create_flow
    assert not mock_client.create_flow.called
```

**Step 2: Implement import command**

Modify `src/descope_mgmt/cli/flow.py`:
```python
# Add import command

@flow.command(name='import')
@click.option('--file', type=click.Path(exists=True), required=True, help='Flow file to import')
@click.option('--dry-run', is_flag=True, help='Preview import without applying')
@click.option('--yes', is_flag=True, help='Skip confirmation')
@click.pass_context
def import_flow(ctx: click.Context, file: str, dry_run: bool, yes: bool) -> None:
    """Import flow from file

    Imports flow configuration from JSON or YAML file.
    Use --dry-run to preview changes before applying.
    """
    try:
        import json
        from pathlib import Path

        # Load flow file
        file_path = Path(file)
        with open(file_path) as f:
            if file_path.suffix == '.json':
                flow_data = json.load(f)
            else:  # yaml
                import yaml
                flow_data = yaml.safe_load(f)

        flow_id = flow_data['flow_id']

        # Validate
        if not flow_id:
            console.print(format_error("Flow file missing 'flow_id'"))
            raise click.Abort()

        # Get credentials
        project_id = os.getenv('DESCOPE_PROJECT_ID')
        management_key = os.getenv('DESCOPE_MANAGEMENT_KEY')

        if not project_id or not management_key:
            console.print(format_error("Missing credentials"))
            raise click.Abort()

        # Create client
        client = DescopeApiClient(project_id, management_key)

        # Check if flow exists
        try:
            existing = client.get_flow(flow_id)
            operation = "UPDATE"
        except:
            existing = None
            operation = "CREATE"

        # Show what would be done
        console.print(f"\n[cyan]Flow import preview:[/cyan]")
        console.print(f"  Operation: [yellow]{operation}[/yellow]")
        console.print(f"  Flow ID: {flow_id}")
        console.print(f"  Name: {flow_data.get('name', 'N/A')}")
        console.print(f"  Screens: {len(flow_data.get('screens', []))}")

        if dry_run:
            console.print("\n[yellow]⚠ Dry-run mode - no changes applied[/yellow]")
            return

        # TODO: Actually apply in Week 5
        console.print("\n[yellow]⚠ Apply mode not yet implemented - use --dry-run for now[/yellow]")

    except Exception as e:
        console.print(format_error(f"Import failed: {e}"))
        raise click.Abort()
```

**Step 3: Run tests**

```bash
pytest tests/integration/test_flow_import.py -v
```

**Step 4: Commit**

```bash
git add src/descope_mgmt/cli/flow.py tests/integration/test_flow_import.py
git commit -m "feat: implement flow import --dry-run command"
```

---

## Chunk Complete Checklist

- [ ] flow import --dry-run
- [ ] JSON/YAML file support
- [ ] Validation
- [ ] Preview display
- [ ] 2 tests passing
- [ ] **Phase 1 Week 4 COMPLETE**
