# Chunk 4: Tenant List Command Implementation

**Status:** pending
**Dependencies:** chunk-001, chunk-002, chunk-003
**Estimated Time:** 30-45 minutes

---

## Task 1: Implement Tenant List Command

**Files:**
- Modify: `src/descope_mgmt/cli/tenant.py`
- Create: `tests/integration/test_tenant_list.py`

**Step 1: Write integration test**

Create `tests/integration/test_tenant_list.py`:
```python
"""Integration tests for tenant list command"""
import pytest
from unittest.mock import Mock, patch
from click.testing import CliRunner
from datetime import datetime
from descope_mgmt.cli.main import cli


@pytest.fixture
def mock_api_client():
    """Mock API client with test data"""
    client = Mock()

    # Mock tenant data
    tenant1 = Mock()
    tenant1.id = "acme-corp"
    tenant1.name = "Acme Corporation"
    tenant1.domains = ["acme.com"]
    tenant1.self_provisioning = True
    tenant1.custom_attributes = {}
    tenant1.created_at = datetime(2025, 1, 1)
    tenant1.updated_at = datetime(2025, 1, 10)

    tenant2 = Mock()
    tenant2.id = "widget-co"
    tenant2.name = "Widget Company"
    tenant2.domains = []
    tenant2.self_provisioning = False
    tenant2.custom_attributes = {}
    tenant2.created_at = datetime(2025, 1, 5)
    tenant2.updated_at = datetime(2025, 1, 5)

    client.list_tenants.return_value = [tenant1, tenant2]
    return client


@patch('descope_mgmt.cli.tenant.DescopeApiClient')
def test_tenant_list_displays_tenants(mock_client_class, mock_api_client):
    """tenant list should display all tenants"""
    mock_client_class.return_value = mock_api_client

    runner = CliRunner()
    result = runner.invoke(cli, ['tenant', 'list'])

    assert result.exit_code == 0
    assert 'acme-corp' in result.output
    assert 'Acme Corporation' in result.output
    assert 'widget-co' in result.output
    assert 'Widget Company' in result.output


@patch('descope_mgmt.cli.tenant.DescopeApiClient')
def test_tenant_list_empty_project(mock_client_class):
    """tenant list should handle empty project"""
    mock_client = Mock()
    mock_client.list_tenants.return_value = []
    mock_client_class.return_value = mock_client

    runner = CliRunner()
    result = runner.invoke(cli, ['tenant', 'list'])

    assert result.exit_code == 0
    assert 'No tenants found' in result.output or '0 tenants' in result.output.lower()
```

**Step 2: Run test to verify it fails**

Run: `pytest tests/integration/test_tenant_list.py -v`

Expected: FAIL (command not implemented)

**Step 3: Implement tenant list command**

Modify `src/descope_mgmt/cli/tenant.py`:
```python
import click
import os
from rich.console import Console
from rich.table import Table
from descope_mgmt.api.descope_client import DescopeApiClient
from descope_mgmt.cli.common import format_error

console = Console()


@click.group()
def tenant() -> None:
    """Manage Descope tenants"""
    pass


@tenant.command()
@click.pass_context
def list(ctx: click.Context) -> None:
    """List all tenants in the project"""
    try:
        # Get credentials from environment
        project_id = os.getenv('DESCOPE_PROJECT_ID')
        management_key = os.getenv('DESCOPE_MANAGEMENT_KEY')

        if not project_id or not management_key:
            console.print(format_error("Missing DESCOPE_PROJECT_ID or DESCOPE_MANAGEMENT_KEY"))
            raise click.Abort()

        # Create client and fetch tenants
        client = DescopeApiClient(project_id, management_key)
        tenants = client.list_tenants()

        if not tenants:
            console.print("No tenants found")
            return

        # Create table
        table = Table(title=f"Tenants ({len(tenants)})")
        table.add_column("ID", style="cyan")
        table.add_column("Name", style="green")
        table.add_column("Domains", style="yellow")
        table.add_column("Self-Prov", style="magenta")

        for tenant in tenants:
            table.add_row(
                tenant.id,
                tenant.name,
                ", ".join(tenant.domains) if tenant.domains else "-",
                "✓" if tenant.self_provisioning else "-"
            )

        console.print(table)

    except Exception as e:
        console.print(format_error(f"Failed to list tenants: {e}"))
        raise click.Abort()
```

**Step 4: Run test to verify it passes**

Run: `pytest tests/integration/test_tenant_list.py -v`

Expected: PASS (all 2 tests)

**Step 5: Commit**

```bash
git add src/descope_mgmt/cli/tenant.py tests/integration/test_tenant_list.py
git commit -m "feat: implement tenant list command with Rich table output"
```

---

## Chunk Complete Checklist

- [ ] Tenant list command implemented
- [ ] Rich table output with colored columns
- [ ] Integration tests passing (2 tests)
- [ ] Handles empty project gracefully
- [ ] Commit made
