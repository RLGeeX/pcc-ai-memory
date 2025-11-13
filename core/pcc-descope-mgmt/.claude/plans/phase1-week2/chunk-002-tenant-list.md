# Chunk 2: Tenant List Command

**Status:** pending
**Dependencies:** chunk-001-global-cli-options
**Complexity:** simple
**Estimated Time:** 30 minutes
**Tasks:** 2

---

## Task 1: Create Tenant List Command

**Files:**
- Create: `src/descope_mgmt/cli/tenant_cmds.py`
- Modify: `src/descope_mgmt/cli/main.py:40-42`
- Test: `tests/unit/cli/test_tenant_cmds.py`

**Step 1: Write the failing test**

Create `tests/unit/cli/test_tenant_cmds.py`:
```python
"""Tests for tenant CLI commands."""

from click.testing import CliRunner

from descope_mgmt.cli.main import cli


def test_tenant_list_shows_help() -> None:
    """Test that tenant list command shows help."""
    runner = CliRunner()
    result = runner.invoke(cli, ["tenant", "list", "--help"])
    assert result.exit_code == 0
    assert "List all tenants" in result.output


def test_tenant_list_with_no_tenants() -> None:
    """Test tenant list with no tenants returns empty message."""
    runner = CliRunner()
    result = runner.invoke(cli, ["tenant", "list"])
    # This will fail until we implement the command
    assert result.exit_code == 0
```

**Step 2: Run test to verify it fails**

```bash
pytest tests/unit/cli/test_tenant_cmds.py::test_tenant_list_shows_help -v
```
Expected: FAIL with "No such command 'list'"

**Step 3: Write minimal implementation**

Create `src/descope_mgmt/cli/tenant_cmds.py`:
```python
"""Tenant management CLI commands."""

import click
from rich.table import Table

from descope_mgmt.cli.output import get_console


@click.command()
@click.pass_context
def list_tenants(ctx: click.Context) -> None:
    """List all tenants in the current project."""
    console = get_console()
    verbose = ctx.obj.get("verbose", False)

    # TODO: In chunk 3, we'll get actual tenants from TenantManager
    # For now, show empty state

    if verbose:
        console.log("Fetching tenants from Descope API...")

    # Create Rich table
    table = Table(title="Tenants")
    table.add_column("ID", style="cyan")
    table.add_column("Name", style="green")
    table.add_column("Domains", style="yellow")

    # No data yet - will be populated in chunk 3

    if table.row_count == 0:
        console.print("[dim]No tenants found.[/dim]")
    else:
        console.print(table)
```

Update `src/descope_mgmt/cli/main.py` to register command:
```python
# After the tenant group definition, add:
from descope_mgmt.cli.tenant_cmds import list_tenants

@cli.group()
def tenant() -> None:
    """Manage Descope tenants."""
    pass

# Register tenant commands
tenant.add_command(list_tenants, name="list")
```

**Step 4: Run tests to verify they pass**

```bash
pytest tests/unit/cli/test_tenant_cmds.py -v
```
Expected: PASS (2 tests)

**Step 5: Commit**

```bash
git add src/descope_mgmt/cli/tenant_cmds.py src/descope_mgmt/cli/main.py tests/unit/cli/test_tenant_cmds.py
git commit -m "feat: add tenant list command with Rich table formatting"
```

---

## Task 2: Add Rich Table Formatting Test

**Files:**
- Modify: `tests/unit/cli/test_tenant_cmds.py`

**Step 1: Write test for table formatting**

Add to `tests/unit/cli/test_tenant_cmds.py`:
```python
def test_tenant_list_creates_table() -> None:
    """Test that tenant list creates a Rich table."""
    runner = CliRunner()
    result = runner.invoke(cli, ["tenant", "list"])
    assert result.exit_code == 0
    assert "Tenants" in result.output or "No tenants found" in result.output


def test_tenant_list_with_verbose_flag() -> None:
    """Test that verbose flag shows debug info."""
    runner = CliRunner()
    result = runner.invoke(cli, ["--verbose", "tenant", "list"])
    assert result.exit_code == 0
    # Verbose output will be added in chunk 3 when we integrate TenantManager
```

**Step 2: Run tests to verify they pass**

```bash
pytest tests/unit/cli/test_tenant_cmds.py -v
```
Expected: PASS (4 tests)

**Step 3: Manual verification**

Test the command manually:
```bash
descope-mgmt tenant list
descope-mgmt --verbose tenant list
descope-mgmt tenant list --help
```
Expected: Commands work, show empty state, help is displayed

**Step 4: Run full test suite**

```bash
pytest tests/ -v --cov=src/descope_mgmt --cov-report=term-missing
```
Expected: All tests pass (69+ tests), coverage >90%

**Step 5: Commit**

```bash
git add tests/unit/cli/test_tenant_cmds.py
git commit -m "test: add Rich table formatting tests for tenant list"
```

---

## Chunk Complete Checklist

- [ ] Tenant list command created
- [ ] Rich table formatting implemented
- [ ] Empty state handled gracefully
- [ ] Verbose flag functional
- [ ] All tests passing (69+ tests)
- [ ] 2 commits created
- [ ] Ready for chunk 3 (TenantManager integration)
