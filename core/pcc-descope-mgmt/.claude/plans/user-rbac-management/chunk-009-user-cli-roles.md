# Chunk 9: User CLI Commands - Role Assignment

**Status:** pending
**Dependencies:** chunk-008-user-cli-crud
**Complexity:** simple
**Estimated Time:** 10 minutes
**Tasks:** 2
**Phase:** CLI Commands

---

## Task 1: Add add-role Command

**Agent:** python-pro
**Files:**
- Modify: `src/descope_mgmt/cli/user_cmds.py`
- Test: `tests/unit/cli/test_user_cmds.py`

**Step 1: Write test**

```python
def test_add_role_to_user(
    runner: CliRunner, mock_client_factory: MagicMock
) -> None:
    """Test add-role adds role to user."""
    mock_client = MagicMock()
    mock_client.add_user_roles.return_value = None
    mock_client_factory.create_client.return_value = mock_client

    result = runner.invoke(
        add_role,
        ["U123", "admin"],
        obj={"verbose": False, "dry_run": False},
    )

    assert result.exit_code == 0
    assert "Added role" in result.output
    mock_client.add_user_roles.assert_called_once_with("U123", ["admin"], None)


def test_add_role_with_tenant(
    runner: CliRunner, mock_client_factory: MagicMock
) -> None:
    """Test add-role with tenant scope."""
    mock_client = MagicMock()
    mock_client.add_user_roles.return_value = None
    mock_client_factory.create_client.return_value = mock_client

    result = runner.invoke(
        add_role,
        ["U123", "admin", "--tenant-id", "tenant-1"],
        obj={"verbose": False, "dry_run": False},
    )

    assert result.exit_code == 0
    mock_client.add_user_roles.assert_called_once_with("U123", ["admin"], "tenant-1")
```

**Step 2: Add add-role command**

```python
@click.command("add-role")
@click.argument("user_id")
@click.argument("role_name")
@click.option("--tenant-id", help="Tenant scope for the role")
@click.pass_context
def add_role(
    ctx: click.Context,
    user_id: str,
    role_name: str,
    tenant_id: str | None,
) -> None:
    """Add a role to a user."""
    console = get_console()
    dry_run = ctx.obj.get("dry_run", False)

    if dry_run:
        console.print("[yellow]DRY RUN: Would add role[/yellow]")
        console.print(f"  User ID: {user_id}")
        console.print(f"  Role: {role_name}")
        if tenant_id:
            console.print(f"  Tenant: {tenant_id}")
        return

    try:
        client = ClientFactory.create_client()
        manager = UserManager(client)
        manager.add_role(user_id, role_name, tenant_id)

        console.print(f"[green]✓[/green] Added role '{role_name}' to user {user_id}")

    except Exception as e:
        console.print(f"[red]Error:[/red] {ErrorFormatter.format_error(e)}")
        raise click.Abort() from e
```

**Step 3: Run tests**

Run: `pytest tests/unit/cli/test_user_cmds.py -k "add_role" -v`
Expected: PASS

---

## Task 2: Add remove-role Command

**Agent:** python-pro
**Files:**
- Modify: `src/descope_mgmt/cli/user_cmds.py`
- Test: `tests/unit/cli/test_user_cmds.py`

**Step 1: Write test**

```python
def test_remove_role_from_user(
    runner: CliRunner, mock_client_factory: MagicMock
) -> None:
    """Test remove-role removes role from user."""
    mock_client = MagicMock()
    mock_client.remove_user_roles.return_value = None
    mock_client_factory.create_client.return_value = mock_client

    result = runner.invoke(
        remove_role,
        ["U123", "viewer"],
        obj={"verbose": False, "dry_run": False},
    )

    assert result.exit_code == 0
    assert "Removed role" in result.output
    mock_client.remove_user_roles.assert_called_once_with("U123", ["viewer"], None)
```

**Step 2: Add remove-role command**

```python
@click.command("remove-role")
@click.argument("user_id")
@click.argument("role_name")
@click.option("--tenant-id", help="Tenant scope for the role")
@click.pass_context
def remove_role(
    ctx: click.Context,
    user_id: str,
    role_name: str,
    tenant_id: str | None,
) -> None:
    """Remove a role from a user."""
    console = get_console()
    dry_run = ctx.obj.get("dry_run", False)

    if dry_run:
        console.print("[yellow]DRY RUN: Would remove role[/yellow]")
        console.print(f"  User ID: {user_id}")
        console.print(f"  Role: {role_name}")
        if tenant_id:
            console.print(f"  Tenant: {tenant_id}")
        return

    try:
        client = ClientFactory.create_client()
        manager = UserManager(client)
        manager.remove_role(user_id, role_name, tenant_id)

        console.print(f"[green]✓[/green] Removed role '{role_name}' from user {user_id}")

    except Exception as e:
        console.print(f"[red]Error:[/red] {ErrorFormatter.format_error(e)}")
        raise click.Abort() from e
```

**Step 3: Run all user CLI tests**

Run: `pytest tests/unit/cli/test_user_cmds.py -v`
Expected: All tests pass

**Step 4: Commit**

```bash
git add src/descope_mgmt/cli/user_cmds.py tests/unit/cli/test_user_cmds.py
git commit -m "feat(cli): add user role assignment commands (add-role, remove-role)"
```

---

## Chunk Complete Checklist

- [ ] All tasks completed
- [ ] All tests passing
- [ ] Code committed
- [ ] Ready for next chunk
