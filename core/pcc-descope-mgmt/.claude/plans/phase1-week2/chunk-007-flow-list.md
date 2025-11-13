# Chunk 7: Flow List Command

**Status:** pending
**Dependencies:** chunk-003-tenant-manager
**Complexity:** simple
**Estimated Time:** 35 minutes
**Tasks:** 2

---

## Task 1: Create FlowManager Service

**Files:**
- Create: `src/descope_mgmt/domain/flow_manager.py`
- Test: `tests/unit/domain/test_flow_manager.py`

**Step 1: Write failing tests**

Create `tests/unit/domain/test_flow_manager.py`:
```python
"""Tests for FlowManager service."""

from descope_mgmt.domain.flow_manager import FlowManager
from descope_mgmt.types.flow import FlowConfig
from tests.fakes import FakeDescopeClient


def test_list_flows_returns_empty_list() -> None:
    """Test that list_flows returns empty list initially."""
    client = FakeDescopeClient()
    manager = FlowManager(client)

    flows = manager.list_flows()
    assert len(flows) == 0


def test_list_flows_with_data() -> None:
    """Test list_flows returns flow data."""
    client = FakeDescopeClient()
    # For now, we'll use a simple list since FakeDescopeClient
    # doesn't have flow methods yet
    manager = FlowManager(client)
    flows = manager.list_flows()

    assert isinstance(flows, list)


def test_get_flow_by_id() -> None:
    """Test get_flow retrieves specific flow."""
    client = FakeDescopeClient()
    manager = FlowManager(client)

    # For v1.0, we'll implement basic flow retrieval
    flow = manager.get_flow("nonexistent")
    assert flow is None
```

**Step 2: Run tests to verify they fail**

```bash
pytest tests/unit/domain/test_flow_manager.py -v
```
Expected: FAIL with "No module named 'descope_mgmt.domain.flow_manager'"

**Step 3: Write minimal implementation**

Create `src/descope_mgmt/domain/flow_manager.py`:
```python
"""Flow management service."""

from descope_mgmt.types.flow import FlowConfig
from descope_mgmt.types.protocols import DescopeClientProtocol


class FlowManager:
    """Service for managing Descope flows."""

    def __init__(self, client: DescopeClientProtocol) -> None:
        """Initialize FlowManager.

        Args:
            client: Descope API client
        """
        self._client = client

    def list_flows(self, tenant_id: str | None = None) -> list[FlowConfig]:
        """List all flows in the project.

        Args:
            tenant_id: Optional tenant ID to filter flows

        Returns:
            List of flow configurations
        """
        # TODO: In Week 4, implement actual API calls
        # For now, return empty list as flows aren't in Week 2 scope
        return []

    def get_flow(self, flow_id: str) -> FlowConfig | None:
        """Get a specific flow by ID.

        Args:
            flow_id: Flow ID to retrieve

        Returns:
            Flow configuration or None if not found
        """
        # TODO: In Week 4, implement actual API calls
        return None
```

**Step 4: Run tests to verify they pass**

```bash
pytest tests/unit/domain/test_flow_manager.py -v
```
Expected: PASS (3 tests)

**Step 5: Commit**

```bash
git add src/descope_mgmt/domain/flow_manager.py tests/unit/domain/test_flow_manager.py
git commit -m "feat: add FlowManager service skeleton"
```

---

## Task 2: Create Flow List Command

**Files:**
- Create: `src/descope_mgmt/cli/flow_cmds.py`
- Modify: `src/descope_mgmt/cli/main.py:50-52`
- Test: `tests/unit/cli/test_flow_cmds.py`

**Step 1: Write failing tests**

Create `tests/unit/cli/test_flow_cmds.py`:
```python
"""Tests for flow CLI commands."""

from click.testing import CliRunner

from descope_mgmt.cli.main import cli


def test_flow_list_shows_help() -> None:
    """Test that flow list command shows help."""
    runner = CliRunner()
    result = runner.invoke(cli, ["flow", "list", "--help"])
    assert result.exit_code == 0
    assert "List all flows" in result.output


def test_flow_list_with_no_flows() -> None:
    """Test flow list with no flows returns empty message."""
    runner = CliRunner()
    result = runner.invoke(cli, ["flow", "list"])
    assert result.exit_code == 0
    assert "No flows found" in result.output or "Flows" in result.output


def test_flow_list_with_verbose_flag() -> None:
    """Test that verbose flag works with flow list."""
    runner = CliRunner()
    result = runner.invoke(cli, ["--verbose", "flow", "list"])
    assert result.exit_code == 0
```

**Step 2: Run tests to verify they fail**

```bash
pytest tests/unit/cli/test_flow_cmds.py::test_flow_list_shows_help -v
```
Expected: FAIL with "No such command 'list'"

**Step 3: Implement flow list command**

Create `src/descope_mgmt/cli/flow_cmds.py`:
```python
"""Flow management CLI commands."""

import click
from rich.table import Table

from descope_mgmt.api.descope_client import DescopeClient
from descope_mgmt.api.rate_limiter import DescopeRateLimiter
from descope_mgmt.cli.output import get_console
from descope_mgmt.domain.flow_manager import FlowManager


@click.command()
@click.option("--tenant", help="Filter flows by tenant ID")
@click.pass_context
def list_flows(ctx: click.Context, tenant: str | None) -> None:
    """List all flows in the current project."""
    console = get_console()
    verbose = ctx.obj.get("verbose", False)

    if verbose:
        console.log("Fetching flows from Descope API...")

    # Initialize services
    rate_limiter = DescopeRateLimiter()
    client = DescopeClient(
        project_id="placeholder",
        management_key="placeholder",
        rate_limiter=rate_limiter,
    )
    manager = FlowManager(client)

    # Fetch flows
    flows = manager.list_flows(tenant_id=tenant)

    # Create Rich table
    table = Table(title="Flows")
    table.add_column("ID", style="cyan")
    table.add_column("Name", style="green")
    table.add_column("Type", style="yellow")
    table.add_column("Tenant", style="magenta")

    for flow in flows:
        tenant_display = getattr(flow, "tenant_id", "-")
        table.add_row(flow.id, flow.name, flow.flow_type, tenant_display)

    if len(flows) == 0:
        console.print("[dim]No flows found.[/dim]")
    else:
        console.print(table)
```

Update `src/descope_mgmt/cli/main.py`:
```python
from descope_mgmt.cli.flow_cmds import list_flows

# Register flow commands (after flow group definition)
flow.add_command(list_flows, name="list")
```

**Step 4: Run tests to verify they pass**

```bash
pytest tests/unit/cli/test_flow_cmds.py -v
```
Expected: PASS (3 tests)

**Step 5: Manual testing**

```bash
descope-mgmt flow list
descope-mgmt flow list --help
descope-mgmt --verbose flow list
```
Expected: Commands work, show empty state

**Step 6: Run full test suite**

```bash
pytest tests/ -v --cov=src/descope_mgmt --cov-report=term-missing
```
Expected: All tests pass (98+ tests), coverage >90%

**Step 7: Commit**

```bash
git add src/descope_mgmt/cli/flow_cmds.py src/descope_mgmt/cli/main.py tests/unit/cli/test_flow_cmds.py
git commit -m "feat: add flow list command with Rich table"
```

---

## Chunk Complete Checklist

- [ ] FlowManager service created
- [ ] Flow list command implemented
- [ ] Rich table formatting
- [ ] Tenant filter option
- [ ] All tests passing (98+ tests)
- [ ] 2 commits created
- [ ] Ready for chunk 8 (flow deploy)
