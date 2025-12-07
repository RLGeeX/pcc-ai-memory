# Chunk 8: User CLI Commands - CRUD

**Status:** pending
**Dependencies:** chunk-006-user-manager
**Complexity:** medium
**Estimated Time:** 15 minutes
**Tasks:** 3
**Phase:** CLI Commands

---

## Task 1: Create user_cmds.py with list and get Commands

**Agent:** python-pro
**Files:**
- Create: `src/descope_mgmt/cli/user_cmds.py`
- Test: `tests/unit/cli/test_user_cmds.py`

**Step 1: Write tests for list and get commands**

```python
# tests/unit/cli/test_user_cmds.py
"""Tests for user CLI commands."""

from unittest.mock import MagicMock, patch

import pytest
from click.testing import CliRunner

from descope_mgmt.cli.user_cmds import list_users, get_user
from descope_mgmt.types.user import UserConfig, UserStatus


@pytest.fixture
def runner() -> CliRunner:
    """Create CLI test runner."""
    return CliRunner()


@pytest.fixture
def mock_client_factory() -> MagicMock:
    """Mock ClientFactory."""
    with patch("descope_mgmt.cli.user_cmds.ClientFactory") as mock:
        yield mock


def test_list_users_displays_table(
    runner: CliRunner, mock_client_factory: MagicMock
) -> None:
    """Test list_users displays users in table format."""
    mock_client = MagicMock()
    mock_client.list_users.return_value = [
        UserConfig(user_id="U1", email="a@test.com", status=UserStatus.ENABLED),
        UserConfig(user_id="U2", email="b@test.com", status=UserStatus.INVITED),
    ]
    mock_client_factory.create_client.return_value = mock_client

    result = runner.invoke(list_users, obj={"verbose": False})

    assert result.exit_code == 0
    assert "U1" in result.output
    assert "a@test.com" in result.output


def test_list_users_empty_shows_message(
    runner: CliRunner, mock_client_factory: MagicMock
) -> None:
    """Test list_users shows message when no users."""
    mock_client = MagicMock()
    mock_client.list_users.return_value = []
    mock_client_factory.create_client.return_value = mock_client

    result = runner.invoke(list_users, obj={"verbose": False})

    assert result.exit_code == 0
    assert "No users found" in result.output


def test_get_user_displays_details(
    runner: CliRunner, mock_client_factory: MagicMock
) -> None:
    """Test get_user displays user details."""
    mock_client = MagicMock()
    mock_client.get_user.return_value = UserConfig(
        user_id="U123",
        email="test@example.com",
        display_name="Test User",
        status=UserStatus.ENABLED,
        roles=["admin"],
    )
    mock_client_factory.create_client.return_value = mock_client

    result = runner.invoke(get_user, ["U123"], obj={"verbose": False})

    assert result.exit_code == 0
    assert "U123" in result.output
    assert "test@example.com" in result.output
```

**Step 2: Run tests to verify they fail**

Run: `pytest tests/unit/cli/test_user_cmds.py -v`
Expected: FAIL with ModuleNotFoundError

**Step 3: Create user_cmds.py with list and get commands**

```python
# src/descope_mgmt/cli/user_cmds.py
"""User management CLI commands."""

import click
from rich.table import Table

from descope_mgmt.api.client_factory import ClientFactory
from descope_mgmt.cli.error_formatter import ErrorFormatter
from descope_mgmt.cli.output import get_console
from descope_mgmt.domain.user_manager import UserManager


@click.command("list")
@click.option("--tenant-id", help="Filter by tenant ID")
@click.option("--limit", default=100, help="Maximum users to return")
@click.option(
    "--format",
    "output_format",
    type=click.Choice(["table", "json"]),
    default="table",
    help="Output format",
)
@click.pass_context
def list_users(
    ctx: click.Context,
    tenant_id: str | None,
    limit: int,
    output_format: str,
) -> None:
    """List users in the project."""
    console = get_console()
    verbose = ctx.obj.get("verbose", False)

    try:
        if verbose:
            console.log("Fetching users from Descope API...")

        client = ClientFactory.create_client()
        manager = UserManager(client)
        users = manager.list_users(limit=limit, tenant_id=tenant_id)

        if len(users) == 0:
            console.print("[dim]No users found.[/dim]")
            return

        if output_format == "json":
            import json
            data = [u.model_dump(mode="json") for u in users]
            console.print(json.dumps(data, indent=2))
            return

        # Table format
        table = Table(title="Users")
        table.add_column("User ID", style="cyan")
        table.add_column("Email", style="green")
        table.add_column("Name")
        table.add_column("Status", style="yellow")
        table.add_column("Roles")

        for user in users:
            roles = ", ".join(user.roles) if user.roles else "-"
            table.add_row(
                user.user_id,
                user.email or "-",
                user.display_name or user.name or "-",
                user.status.value,
                roles,
            )

        console.print(table)

    except Exception as e:
        console.print(f"[red]Error:[/red] {ErrorFormatter.format_error(e)}")
        raise click.Abort() from e


@click.command("get")
@click.argument("user_id")
@click.option(
    "--format",
    "output_format",
    type=click.Choice(["table", "json"]),
    default="table",
)
@click.pass_context
def get_user(ctx: click.Context, user_id: str, output_format: str) -> None:
    """Get user details by ID."""
    console = get_console()

    try:
        client = ClientFactory.create_client()
        manager = UserManager(client)
        user = manager.get_user(user_id)

        if user is None:
            console.print(f"[red]User not found:[/red] {user_id}")
            raise click.Abort()

        if output_format == "json":
            console.print(user.model_dump_json(indent=2))
            return

        # Table format
        table = Table(title=f"User: {user_id}")
        table.add_column("Field", style="cyan")
        table.add_column("Value")

        table.add_row("User ID", user.user_id)
        table.add_row("Email", user.email or "-")
        table.add_row("Name", user.display_name or user.name or "-")
        table.add_row("Phone", user.phone or "-")
        table.add_row("Status", user.status.value)
        table.add_row("Roles", ", ".join(user.roles) if user.roles else "-")
        table.add_row("Tenants", ", ".join(user.tenants) if user.tenants else "-")
        table.add_row("Email Verified", str(user.verified_email))

        console.print(table)

    except click.Abort:
        raise
    except Exception as e:
        console.print(f"[red]Error:[/red] {ErrorFormatter.format_error(e)}")
        raise click.Abort() from e
```

**Step 4: Run tests**

Run: `pytest tests/unit/cli/test_user_cmds.py -k "list or get" -v`
Expected: PASS

---

## Task 2: Add invite Command

**Agent:** python-pro
**Files:**
- Modify: `src/descope_mgmt/cli/user_cmds.py`
- Test: `tests/unit/cli/test_user_cmds.py`

**Step 1: Write test**

```python
def test_invite_user_creates_user(
    runner: CliRunner, mock_client_factory: MagicMock
) -> None:
    """Test invite_user sends invitation."""
    mock_client = MagicMock()
    mock_client.invite_user.return_value = {"userId": "U999"}
    mock_client_factory.create_client.return_value = mock_client

    result = runner.invoke(
        invite_user,
        ["--email", "new@test.com", "--name", "New User"],
        obj={"verbose": False, "dry_run": False},
    )

    assert result.exit_code == 0
    assert "Invited" in result.output or "U999" in result.output
    mock_client.invite_user.assert_called_once()
```

**Step 2: Add invite command**

```python
@click.command("invite")
@click.option("--email", required=True, help="User email address")
@click.option("--name", help="Display name")
@click.option("--role", "roles", multiple=True, help="Roles to assign (repeatable)")
@click.option("--tenant-id", help="Associate with tenant")
@click.pass_context
def invite_user(
    ctx: click.Context,
    email: str,
    name: str | None,
    roles: tuple[str, ...],
    tenant_id: str | None,
) -> None:
    """Invite a new user via email."""
    console = get_console()
    dry_run = ctx.obj.get("dry_run", False)

    if dry_run:
        console.print("[yellow]DRY RUN: Would invite user[/yellow]")
        console.print(f"  Email: {email}")
        console.print(f"  Name: {name or '-'}")
        console.print(f"  Roles: {', '.join(roles) if roles else '-'}")
        return

    try:
        client = ClientFactory.create_client()
        manager = UserManager(client)
        user_id = manager.invite_user(
            email=email,
            name=name,
            roles=list(roles) if roles else None,
            tenant_id=tenant_id,
        )

        console.print(f"[green]✓[/green] Invited user: {email}")
        console.print(f"  User ID: {user_id}")

    except Exception as e:
        console.print(f"[red]Error:[/red] {ErrorFormatter.format_error(e)}")
        raise click.Abort() from e
```

**Step 3: Run test**

Run: `pytest tests/unit/cli/test_user_cmds.py::test_invite_user_creates_user -v`
Expected: PASS

---

## Task 3: Add update and delete Commands

**Agent:** python-pro
**Files:**
- Modify: `src/descope_mgmt/cli/user_cmds.py`
- Test: `tests/unit/cli/test_user_cmds.py`

**Step 1: Write tests**

```python
def test_delete_user_requires_confirmation(
    runner: CliRunner, mock_client_factory: MagicMock
) -> None:
    """Test delete_user asks for confirmation."""
    mock_client = MagicMock()
    mock_client.get_user.return_value = UserConfig(
        user_id="U123", email="test@example.com"
    )
    mock_client_factory.create_client.return_value = mock_client

    # Without --force, should prompt
    result = runner.invoke(
        delete_user, ["U123"], obj={"verbose": False, "dry_run": False}, input="n\n"
    )

    assert "cancelled" in result.output.lower() or result.exit_code == 0
    mock_client.delete_user.assert_not_called()


def test_delete_user_force_skips_confirmation(
    runner: CliRunner, mock_client_factory: MagicMock
) -> None:
    """Test delete_user --force skips confirmation."""
    mock_client = MagicMock()
    mock_client.get_user.return_value = UserConfig(
        user_id="U123", email="test@example.com"
    )
    mock_client_factory.create_client.return_value = mock_client

    result = runner.invoke(
        delete_user, ["U123", "--force"], obj={"verbose": False, "dry_run": False}
    )

    assert result.exit_code == 0
    mock_client.delete_user.assert_called_once_with("U123")
```

**Step 2: Add commands**

```python
@click.command("update")
@click.argument("user_id")
@click.option("--name", help="New display name")
@click.option("--phone", help="New phone number")
@click.option(
    "--status",
    type=click.Choice(["enabled", "disabled"]),
    help="New status",
)
@click.pass_context
def update_user(
    ctx: click.Context,
    user_id: str,
    name: str | None,
    phone: str | None,
    status: str | None,
) -> None:
    """Update user details."""
    console = get_console()
    dry_run = ctx.obj.get("dry_run", False)

    if not any([name, phone, status]):
        console.print("[yellow]No updates specified. Use --name, --phone, or --status.[/yellow]")
        return

    if dry_run:
        console.print("[yellow]DRY RUN: Would update user[/yellow]")
        console.print(f"  User ID: {user_id}")
        if name:
            console.print(f"  Name: {name}")
        if phone:
            console.print(f"  Phone: {phone}")
        if status:
            console.print(f"  Status: {status}")
        return

    try:
        client = ClientFactory.create_client()
        manager = UserManager(client)
        manager.update_user(user_id=user_id, name=name, phone=phone, status=status)

        console.print(f"[green]✓[/green] Updated user: {user_id}")

    except Exception as e:
        console.print(f"[red]Error:[/red] {ErrorFormatter.format_error(e)}")
        raise click.Abort() from e


@click.command("delete")
@click.argument("user_id")
@click.option("--force", is_flag=True, help="Skip confirmation prompt")
@click.pass_context
def delete_user(ctx: click.Context, user_id: str, force: bool) -> None:
    """Delete a user."""
    console = get_console()
    dry_run = ctx.obj.get("dry_run", False)

    try:
        client = ClientFactory.create_client()
        manager = UserManager(client)

        # Verify user exists
        user = manager.get_user(user_id)
        if user is None:
            console.print(f"[red]User not found:[/red] {user_id}")
            raise click.Abort()

        # Show user info
        console.print("\n[bold red]WARNING: About to delete user[/bold red]")
        console.print(f"  User ID: {user.user_id}")
        console.print(f"  Email: {user.email or '-'}")
        console.print(f"  Name: {user.display_name or '-'}")
        console.print("\n[yellow]This operation cannot be undone![/yellow]\n")

        if dry_run:
            console.print("[yellow]DRY RUN: Would delete user[/yellow]")
            return

        if not force:
            confirmed = click.confirm("Are you sure you want to delete this user?")
            if not confirmed:
                console.print("[dim]Deletion cancelled.[/dim]")
                return

        manager.delete_user(user_id)
        console.print(f"[green]✓[/green] Deleted user: {user_id}")

    except click.Abort:
        raise
    except Exception as e:
        console.print(f"[red]Error:[/red] {ErrorFormatter.format_error(e)}")
        raise click.Abort() from e
```

**Step 3: Run all tests**

Run: `pytest tests/unit/cli/test_user_cmds.py -v`
Expected: All tests pass

**Step 4: Commit**

```bash
git add src/descope_mgmt/cli/user_cmds.py tests/unit/cli/test_user_cmds.py
git commit -m "feat(cli): add user CRUD commands (list, get, invite, update, delete)"
```

---

## Chunk Complete Checklist

- [ ] All tasks completed
- [ ] All tests passing
- [ ] Code committed
- [ ] Ready for next chunk
