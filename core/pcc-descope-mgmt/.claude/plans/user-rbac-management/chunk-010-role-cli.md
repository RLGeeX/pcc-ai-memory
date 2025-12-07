# Chunk 10: Role CLI Commands

**Status:** pending
**Dependencies:** chunk-007-role-manager
**Complexity:** simple
**Estimated Time:** 10 minutes
**Tasks:** 2
**Phase:** CLI Commands

---

## Task 1: Create role_cmds.py with list and create Commands

**Agent:** python-pro
**Files:**
- Create: `src/descope_mgmt/cli/role_cmds.py`
- Test: `tests/unit/cli/test_role_cmds.py`

**Step 1: Write tests**

```python
# tests/unit/cli/test_role_cmds.py
"""Tests for role CLI commands."""

from unittest.mock import MagicMock, patch

import pytest
from click.testing import CliRunner

from descope_mgmt.cli.role_cmds import list_roles, create_role, delete_role
from descope_mgmt.types.role import RoleConfig


@pytest.fixture
def runner() -> CliRunner:
    """Create CLI test runner."""
    return CliRunner()


@pytest.fixture
def mock_client_factory() -> MagicMock:
    """Mock ClientFactory."""
    with patch("descope_mgmt.cli.role_cmds.ClientFactory") as mock:
        yield mock


def test_list_roles_displays_table(
    runner: CliRunner, mock_client_factory: MagicMock
) -> None:
    """Test list_roles displays roles in table format."""
    mock_client = MagicMock()
    mock_client.list_roles.return_value = [
        RoleConfig(name="admin", description="Administrator", permissions=["*"]),
        RoleConfig(name="viewer", description="Read-only", permissions=["read"]),
    ]
    mock_client_factory.create_client.return_value = mock_client

    result = runner.invoke(list_roles, obj={"verbose": False})

    assert result.exit_code == 0
    assert "admin" in result.output
    assert "Administrator" in result.output


def test_create_role_creates_role(
    runner: CliRunner, mock_client_factory: MagicMock
) -> None:
    """Test create_role creates new role."""
    mock_client = MagicMock()
    mock_client.create_role.return_value = {}
    mock_client_factory.create_client.return_value = mock_client

    result = runner.invoke(
        create_role,
        ["editor", "--description", "Can edit content"],
        obj={"verbose": False, "dry_run": False},
    )

    assert result.exit_code == 0
    assert "Created" in result.output
    mock_client.create_role.assert_called_once()
```

**Step 2: Create role_cmds.py**

```python
# src/descope_mgmt/cli/role_cmds.py
"""Role management CLI commands."""

import click
from rich.table import Table

from descope_mgmt.api.client_factory import ClientFactory
from descope_mgmt.cli.error_formatter import ErrorFormatter
from descope_mgmt.cli.output import get_console
from descope_mgmt.domain.role_manager import RoleManager


@click.command("list")
@click.option(
    "--format",
    "output_format",
    type=click.Choice(["table", "json"]),
    default="table",
    help="Output format",
)
@click.pass_context
def list_roles(ctx: click.Context, output_format: str) -> None:
    """List all project-level roles."""
    console = get_console()
    verbose = ctx.obj.get("verbose", False)

    try:
        if verbose:
            console.log("Fetching roles from Descope API...")

        client = ClientFactory.create_client()
        manager = RoleManager(client)
        roles = manager.list_roles()

        if len(roles) == 0:
            console.print("[dim]No roles found.[/dim]")
            return

        if output_format == "json":
            import json
            data = [r.model_dump(mode="json") for r in roles]
            console.print(json.dumps(data, indent=2))
            return

        # Table format
        table = Table(title="Roles")
        table.add_column("Name", style="cyan")
        table.add_column("Description")
        table.add_column("Permissions", style="yellow")

        for role in roles:
            perms = ", ".join(role.permissions) if role.permissions else "-"
            table.add_row(role.name, role.description or "-", perms)

        console.print(table)

    except Exception as e:
        console.print(f"[red]Error:[/red] {ErrorFormatter.format_error(e)}")
        raise click.Abort() from e


@click.command("create")
@click.argument("name")
@click.option("--description", help="Role description")
@click.option(
    "--permission", "permissions", multiple=True, help="Permissions (repeatable)"
)
@click.pass_context
def create_role(
    ctx: click.Context,
    name: str,
    description: str | None,
    permissions: tuple[str, ...],
) -> None:
    """Create a new role."""
    console = get_console()
    dry_run = ctx.obj.get("dry_run", False)

    if dry_run:
        console.print("[yellow]DRY RUN: Would create role[/yellow]")
        console.print(f"  Name: {name}")
        console.print(f"  Description: {description or '-'}")
        console.print(f"  Permissions: {', '.join(permissions) if permissions else '-'}")
        return

    try:
        client = ClientFactory.create_client()
        manager = RoleManager(client)
        manager.create_role(
            name=name,
            description=description,
            permissions=list(permissions) if permissions else None,
        )

        console.print(f"[green]✓[/green] Created role: {name}")

    except Exception as e:
        console.print(f"[red]Error:[/red] {ErrorFormatter.format_error(e)}")
        raise click.Abort() from e
```

**Step 3: Run tests**

Run: `pytest tests/unit/cli/test_role_cmds.py -k "list or create" -v`
Expected: PASS

---

## Task 2: Add update and delete Commands

**Agent:** python-pro
**Files:**
- Modify: `src/descope_mgmt/cli/role_cmds.py`
- Test: `tests/unit/cli/test_role_cmds.py`

**Step 1: Write tests**

```python
def test_delete_role_requires_confirmation(
    runner: CliRunner, mock_client_factory: MagicMock
) -> None:
    """Test delete_role asks for confirmation."""
    mock_client = MagicMock()
    mock_client.list_roles.return_value = [
        RoleConfig(name="old-role", description="To delete")
    ]
    mock_client_factory.create_client.return_value = mock_client

    result = runner.invoke(
        delete_role, ["old-role"], obj={"verbose": False, "dry_run": False}, input="n\n"
    )

    assert "cancelled" in result.output.lower() or result.exit_code == 0
    mock_client.delete_role.assert_not_called()


def test_delete_role_force_deletes(
    runner: CliRunner, mock_client_factory: MagicMock
) -> None:
    """Test delete_role --force skips confirmation."""
    mock_client = MagicMock()
    mock_client.list_roles.return_value = [
        RoleConfig(name="old-role", description="To delete")
    ]
    mock_client.delete_role.return_value = None
    mock_client_factory.create_client.return_value = mock_client

    result = runner.invoke(
        delete_role,
        ["old-role", "--force"],
        obj={"verbose": False, "dry_run": False},
    )

    assert result.exit_code == 0
    mock_client.delete_role.assert_called_once_with("old-role")
```

**Step 2: Add commands**

```python
@click.command("update")
@click.argument("name")
@click.option("--new-name", help="Rename the role")
@click.option("--description", help="New description")
@click.option(
    "--permission", "permissions", multiple=True, help="Replace permissions (repeatable)"
)
@click.pass_context
def update_role(
    ctx: click.Context,
    name: str,
    new_name: str | None,
    description: str | None,
    permissions: tuple[str, ...],
) -> None:
    """Update a role."""
    console = get_console()
    dry_run = ctx.obj.get("dry_run", False)

    if not any([new_name, description, permissions]):
        console.print(
            "[yellow]No updates specified. Use --new-name, --description, or --permission.[/yellow]"
        )
        return

    if dry_run:
        console.print("[yellow]DRY RUN: Would update role[/yellow]")
        console.print(f"  Name: {name}")
        if new_name:
            console.print(f"  New Name: {new_name}")
        if description:
            console.print(f"  Description: {description}")
        if permissions:
            console.print(f"  Permissions: {', '.join(permissions)}")
        return

    try:
        client = ClientFactory.create_client()
        manager = RoleManager(client)
        manager.update_role(
            name=name,
            new_name=new_name,
            description=description,
            permissions=list(permissions) if permissions else None,
        )

        console.print(f"[green]✓[/green] Updated role: {name}")

    except Exception as e:
        console.print(f"[red]Error:[/red] {ErrorFormatter.format_error(e)}")
        raise click.Abort() from e


@click.command("delete")
@click.argument("name")
@click.option("--force", is_flag=True, help="Skip confirmation prompt")
@click.pass_context
def delete_role(ctx: click.Context, name: str, force: bool) -> None:
    """Delete a role."""
    console = get_console()
    dry_run = ctx.obj.get("dry_run", False)

    try:
        client = ClientFactory.create_client()
        manager = RoleManager(client)

        # Verify role exists
        role = manager.get_role(name)
        if role is None:
            console.print(f"[red]Role not found:[/red] {name}")
            raise click.Abort()

        console.print("\n[bold red]WARNING: About to delete role[/bold red]")
        console.print(f"  Name: {role.name}")
        console.print(f"  Description: {role.description or '-'}")
        console.print("\n[yellow]This operation cannot be undone![/yellow]\n")

        if dry_run:
            console.print("[yellow]DRY RUN: Would delete role[/yellow]")
            return

        if not force:
            confirmed = click.confirm("Are you sure you want to delete this role?")
            if not confirmed:
                console.print("[dim]Deletion cancelled.[/dim]")
                return

        manager.delete_role(name)
        console.print(f"[green]✓[/green] Deleted role: {name}")

    except click.Abort:
        raise
    except Exception as e:
        console.print(f"[red]Error:[/red] {ErrorFormatter.format_error(e)}")
        raise click.Abort() from e
```

**Step 3: Run all tests**

Run: `pytest tests/unit/cli/test_role_cmds.py -v`
Expected: All tests pass

**Step 4: Commit**

```bash
git add src/descope_mgmt/cli/role_cmds.py tests/unit/cli/test_role_cmds.py
git commit -m "feat(cli): add role CRUD commands (list, create, update, delete)"
```

---

## REVIEW CHECKPOINT

This is a review checkpoint. After completing this chunk:
1. Run full test suite: `pytest tests/unit/ -v`
2. Run linters: `ruff check . && mypy .`
3. Review all CLI commands for consistency in output format and error handling

---

## Chunk Complete Checklist

- [ ] All tasks completed
- [ ] All tests passing
- [ ] Review checkpoint completed
- [ ] Code committed
- [ ] Ready for next chunk
