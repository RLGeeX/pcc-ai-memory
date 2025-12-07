# Chunk 11: CLI Integration - Wire Up Command Groups

**Status:** pending
**Dependencies:** chunk-008-user-cli-crud, chunk-009-user-cli-roles, chunk-010-role-cli
**Complexity:** simple
**Estimated Time:** 10 minutes
**Tasks:** 2
**Phase:** Integration & Testing

---

## Task 1: Create user and role Command Groups

**Agent:** python-pro
**Files:**
- Modify: `src/descope_mgmt/cli/user_cmds.py`
- Modify: `src/descope_mgmt/cli/role_cmds.py`

**Step 1: Add user command group to user_cmds.py**

At the top of `user_cmds.py`, add the group definition:

```python
@click.group()
def user() -> None:
    """Manage Descope users."""
    pass


# Register commands to the group
user.add_command(list_users, name="list")
user.add_command(get_user, name="get")
user.add_command(invite_user, name="invite")
user.add_command(update_user, name="update")
user.add_command(delete_user, name="delete")
user.add_command(add_role, name="add-role")
user.add_command(remove_role, name="remove-role")
```

**Step 2: Add role command group to role_cmds.py**

At the top of `role_cmds.py`, add:

```python
@click.group()
def role() -> None:
    """Manage Descope roles."""
    pass


# Register commands to the group
role.add_command(list_roles, name="list")
role.add_command(create_role, name="create")
role.add_command(update_role, name="update")
role.add_command(delete_role, name="delete")
```

**Step 3: Verify imports work**

Run: `python -c "from descope_mgmt.cli.user_cmds import user; from descope_mgmt.cli.role_cmds import role; print('OK')"`
Expected: "OK"

---

## Task 2: Register Groups in main.py

**Agent:** python-pro
**Files:**
- Modify: `src/descope_mgmt/cli/main.py`

**Step 1: Read current main.py structure**

Review the existing CLI structure in main.py to understand how commands are registered.

**Step 2: Add imports and register groups**

Add imports at top of main.py:

```python
from descope_mgmt.cli.user_cmds import user
from descope_mgmt.cli.role_cmds import role
```

Add command group registration (after existing tenant/flow groups):

```python
cli.add_command(user)
cli.add_command(role)
```

**Step 3: Test CLI integration**

Run: `descope-mgmt --help`
Expected: Output shows `user` and `role` commands:
```
Commands:
  audit   Manage audit logs.
  flow    Manage Descope flows.
  role    Manage Descope roles.
  tenant  Manage Descope tenants.
  user    Manage Descope users.
```

Run: `descope-mgmt user --help`
Expected: Shows user subcommands (list, get, invite, update, delete, add-role, remove-role)

Run: `descope-mgmt role --help`
Expected: Shows role subcommands (list, create, update, delete)

**Step 4: Commit**

```bash
git add src/descope_mgmt/cli/main.py src/descope_mgmt/cli/user_cmds.py src/descope_mgmt/cli/role_cmds.py
git commit -m "feat(cli): integrate user and role command groups"
```

---

## Chunk Complete Checklist

- [ ] All tasks completed
- [ ] CLI help shows user and role commands
- [ ] All subcommands accessible
- [ ] Code committed
- [ ] Ready for next chunk
