# Chunk 3: Flow List Command

**Status:** pending
**Dependencies:** chunk-001, chunk-002
**Estimated Time:** 30-45 minutes

---

## Task 1: Implement Flow List Command

**Files:**
- Create: `src/descope_mgmt/cli/flow.py`
- Modify: `src/descope_mgmt/cli/main.py`
- Create: `tests/integration/test_flow_list.py`

**Step 1: Write integration test**

Create `tests/integration/test_flow_list.py`:
```python
"""Integration tests for flow list"""
import pytest
from unittest.mock import Mock, patch
from click.testing import CliRunner
from descope_mgmt.cli.main import cli
from datetime import datetime


@patch('descope_mgmt.cli.flow.DescopeApiClient')
def test_flow_list_command(mock_client_class):
    """flow list should display flows in table"""
    # Mock API client
    mock_flow1 = Mock()
    mock_flow1.flow_id = "sign-up"
    mock_flow1.name = "Sign Up"

    mock_flow2 = Mock()
    mock_flow2.flow_id = "sign-in"
    mock_flow2.name = "Sign In"

    mock_client = Mock()
    mock_client.list_flows.return_value = [mock_flow1, mock_flow2]
    mock_client_class.return_value = mock_client

    runner = CliRunner()
    result = runner.invoke(cli, ['flow', 'list'])

    assert result.exit_code == 0
    assert "sign-up" in result.output
    assert "sign-in" in result.output
```

**Step 2: Implement flow command group**

Create `src/descope_mgmt/cli/flow.py`:
```python
"""Flow management commands."""
import os
import click
from rich.console import Console
from descope_mgmt.api.descope_client import DescopeApiClient
from descope_mgmt.cli.common import format_error
from descope_mgmt.utils.display import format_tenant_table

console = Console()


@click.group()
def flow():
    """Manage authentication flows"""
    pass


@flow.command()
@click.option('--flow-id', help='Filter by flow ID')
@click.pass_context
def list(ctx: click.Context, flow_id: str | None) -> None:
    """List authentication flows

    Displays all flows in a Rich table format.
    """
    try:
        # Get credentials
        project_id = os.getenv('DESCOPE_PROJECT_ID')
        management_key = os.getenv('DESCOPE_MANAGEMENT_KEY')

        if not project_id or not management_key:
            console.print(format_error("Missing DESCOPE_PROJECT_ID or DESCOPE_MANAGEMENT_KEY"))
            raise click.Abort()

        # Create client
        client = DescopeApiClient(project_id, management_key)

        # List flows
        flows = client.list_flows()

        # Filter if needed
        if flow_id:
            flows = [f for f in flows if f.flow_id == flow_id]

        # Display table
        from rich.table import Table
        table = Table(title=f"Flows ({len(flows)})")
        table.add_column("Flow ID", style="cyan", no_wrap=True)
        table.add_column("Name", style="green")

        for flow in flows:
            table.add_row(
                flow.flow_id,
                getattr(flow, 'name', flow.flow_id)
            )

        console.print(table)

    except Exception as e:
        console.print(format_error(f"Failed to list flows: {e}"))
        raise click.Abort()
```

**Step 3: Register flow group in main**

Modify `src/descope_mgmt/cli/main.py`:
```python
# Add import
from descope_mgmt.cli.flow import flow

# Add flow group
cli.add_command(flow)
```

**Step 4: Run test**

```bash
pytest tests/integration/test_flow_list.py -v
```

**Step 5: Commit**

```bash
git add src/descope_mgmt/cli/flow.py src/descope_mgmt/cli/main.py tests/integration/test_flow_list.py
git commit -m "feat: implement flow list command"
```

---

## Chunk Complete Checklist

- [ ] flow list command
- [ ] Rich table output
- [ ] Filter by flow ID
- [ ] 2 integration tests passing
