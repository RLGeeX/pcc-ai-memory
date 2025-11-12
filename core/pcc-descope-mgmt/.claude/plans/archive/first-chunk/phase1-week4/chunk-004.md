# Chunk 4: Flow Export Command

**Status:** pending
**Dependencies:** chunk-001, chunk-002
**Estimated Time:** 45 minutes

---

## Task 1: Implement Flow Export

**Files:**
- Modify: `src/descope_mgmt/cli/flow.py`
- Create: `tests/integration/test_flow_export.py`

**Step 1: Write tests**

Create `tests/integration/test_flow_export.py`:
```python
"""Integration tests for flow export"""
import pytest
import json
from unittest.mock import Mock, patch
from click.testing import CliRunner
from descope_mgmt.cli.main import cli


@patch('descope_mgmt.cli.flow.DescopeApiClient')
def test_flow_export_single(mock_client_class, tmp_path):
    """Should export single flow to JSON"""
    # Mock flow data
    mock_flow = Mock()
    mock_flow.flow_id = "sign-up"
    mock_flow.screens = [{"id": "email"}]

    mock_client = Mock()
    mock_client.get_flow.return_value = mock_flow
    mock_client_class.return_value = mock_client

    output_file = tmp_path / "flow.json"

    runner = CliRunner()
    result = runner.invoke(cli, [
        'flow', 'export',
        '--flow-id', 'sign-up',
        '--output', str(output_file)
    ])

    assert result.exit_code == 0
    assert output_file.exists()

    # Verify content
    with open(output_file) as f:
        data = json.load(f)
        assert data["flow_id"] == "sign-up"
```

**Step 2: Implement export command**

Modify `src/descope_mgmt/cli/flow.py`:
```python
# Add export command

@flow.command()
@click.option('--flow-id', required=True, help='Flow ID to export')
@click.option('--output', type=click.Path(), required=True, help='Output file path')
@click.option('--format', type=click.Choice(['json', 'yaml']), default='json', help='Output format')
@click.pass_context
def export(ctx: click.Context, flow_id: str, output: str, format: str) -> None:
    """Export flow to file

    Exports flow configuration to JSON or YAML format.
    """
    try:
        import json
        from pathlib import Path

        # Get credentials
        project_id = os.getenv('DESCOPE_PROJECT_ID')
        management_key = os.getenv('DESCOPE_MANAGEMENT_KEY')

        if not project_id or not management_key:
            console.print(format_error("Missing credentials"))
            raise click.Abort()

        # Create client
        client = DescopeApiClient(project_id, management_key)

        # Get flow
        flow = client.get_flow(flow_id)

        # Prepare data
        flow_data = {
            "flow_id": flow.flow_id,
            "name": getattr(flow, 'name', flow.flow_id),
            "screens": flow.screens if hasattr(flow, 'screens') else [],
            "metadata": getattr(flow, 'metadata', {})
        }

        # Write to file
        output_path = Path(output)
        output_path.parent.mkdir(parents=True, exist_ok=True)

        if format == 'json':
            with open(output_path, 'w') as f:
                json.dump(flow_data, f, indent=2)
        else:  # yaml
            import yaml
            with open(output_path, 'w') as f:
                yaml.dump(flow_data, f)

        console.print(f"[green]✓ Exported flow '{flow_id}' to {output}[/green]")

    except Exception as e:
        console.print(format_error(f"Export failed: {e}"))
        raise click.Abort()
```

**Step 3: Run tests**

```bash
pytest tests/integration/test_flow_export.py -v
```

**Step 4: Commit**

```bash
git add src/descope_mgmt/cli/flow.py tests/integration/test_flow_export.py
git commit -m "feat: implement flow export command"
```

---

## Chunk Complete Checklist

- [ ] flow export command
- [ ] JSON/YAML format support
- [ ] 3 tests passing
