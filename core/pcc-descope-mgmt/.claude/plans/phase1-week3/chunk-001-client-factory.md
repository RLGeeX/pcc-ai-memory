# Chunk 1: Client Factory Pattern

**Status:** pending
**Dependencies:** none (Week 2 complete)
**Complexity:** simple
**Estimated Time:** 30 minutes
**Tasks:** 3

---

## Context

Week 2 identified critical code duplication: client initialization code is repeated in 6 command locations:
- `tenant_cmds.py`: list, create, update, delete
- `flow_cmds.py`: list, deploy

This chunk extracts a ClientFactory pattern to:
1. Eliminate duplication
2. Enable proper dependency injection
3. Fix local import anti-patterns
4. Centralize configuration loading

---

## Task 1: Create ClientFactory

**Agent:** python-pro

**Files:**
- Create: `src/descope_mgmt/api/client_factory.py`
- Create: `tests/unit/api/test_client_factory.py`

**Step 1: Write the failing test**

Create `tests/unit/api/test_client_factory.py`:

```python
"""Tests for client factory."""

import pytest
from descope_mgmt.api.client_factory import ClientFactory
from descope_mgmt.api.descope_client import DescopeClient
from descope_mgmt.types.protocols import DescopeClientProtocol


def test_create_client_returns_protocol_instance() -> None:
    """Test factory creates client implementing protocol."""
    client = ClientFactory.create_client(
        project_id="P2test123",
        management_key="K2test456"
    )

    assert isinstance(client, DescopeClientProtocol)


def test_create_client_with_env_vars(monkeypatch: pytest.MonkeyPatch) -> None:
    """Test factory uses environment variables as fallback."""
    monkeypatch.setenv("DESCOPE_PROJECT_ID", "P2env123")
    monkeypatch.setenv("DESCOPE_MANAGEMENT_KEY", "K2env456")

    client = ClientFactory.create_client()

    assert client is not None


def test_create_client_missing_credentials_raises_error() -> None:
    """Test factory raises clear error when credentials missing."""
    with pytest.raises(ValueError, match="project_id.*management_key"):
        ClientFactory.create_client()
```

**Step 2: Run test to verify it fails**

Run: `pytest tests/unit/api/test_client_factory.py -v`
Expected: FAIL with "No module named 'descope_mgmt.api.client_factory'"

**Step 3: Write minimal implementation**

Create `src/descope_mgmt/api/client_factory.py`:

```python
"""Factory for creating Descope API clients."""

import os
from typing import Optional

from descope_mgmt.api.descope_client import DescopeClient
from descope_mgmt.api.rate_limiter import RateLimiter
from descope_mgmt.types.protocols import DescopeClientProtocol


class ClientFactory:
    """Factory for creating configured Descope API clients.

    Centralizes client initialization to eliminate code duplication
    and enable proper dependency injection.
    """

    @staticmethod
    def create_client(
        project_id: Optional[str] = None,
        management_key: Optional[str] = None,
    ) -> DescopeClientProtocol:
        """Create configured Descope API client.

        Args:
            project_id: Descope project ID (or from DESCOPE_PROJECT_ID env var)
            management_key: Management API key (or from DESCOPE_MANAGEMENT_KEY env var)

        Returns:
            Configured client implementing DescopeClientProtocol

        Raises:
            ValueError: If credentials not provided and not in environment
        """
        # Try parameters first, then environment variables
        pid = project_id or os.getenv("DESCOPE_PROJECT_ID")
        key = management_key or os.getenv("DESCOPE_MANAGEMENT_KEY")

        if not pid or not key:
            raise ValueError(
                "Missing credentials: provide project_id and management_key "
                "or set DESCOPE_PROJECT_ID and DESCOPE_MANAGEMENT_KEY environment variables"
            )

        # Create rate limiter (200 requests per 60 seconds)
        rate_limiter = RateLimiter(max_requests=200, time_window=60)

        # Create and return client
        return DescopeClient(
            project_id=pid,
            management_key=key,
            rate_limiter=rate_limiter,
        )
```

**Step 4: Run test to verify it passes**

Run: `pytest tests/unit/api/test_client_factory.py -v`
Expected: All 3 tests PASS

**Step 5: Commit**

```bash
git add src/descope_mgmt/api/client_factory.py tests/unit/api/test_client_factory.py
git commit -m "feat: add client factory pattern

- Create ClientFactory for centralized client initialization
- Support environment variable fallback for credentials
- Add comprehensive tests for factory creation
- Addresses Week 2 technical debt: code duplication"
```

---

## Task 2: Update Tenant Commands to Use Factory

**Agent:** python-pro

**Files:**
- Modify: `src/descope_mgmt/cli/tenant_cmds.py:1-20,40-55,75-90,110-125` (4 command functions)
- Modify: `tests/unit/cli/test_tenant_cmds.py:1-10` (imports)

**Step 1: Write test update**

Update `tests/unit/cli/test_tenant_cmds.py` imports (no new tests needed, existing tests cover):

```python
# Update imports at top of file
from descope_mgmt.api.client_factory import ClientFactory
from descope_mgmt.types.tenant import TenantConfig  # Move to module level
```

**Step 2: Update tenant_cmds.py implementation**

Modify `src/descope_mgmt/cli/tenant_cmds.py`:

```python
"""Tenant management commands."""

import click
from rich.prompt import Confirm

from descope_mgmt.api.client_factory import ClientFactory
from descope_mgmt.cli.context import CliContext
from descope_mgmt.cli.diff import display_tenant_diff
from descope_mgmt.cli.output import console
from descope_mgmt.domain.tenant_manager import TenantManager
from descope_mgmt.types.tenant import TenantConfig  # Module-level import


@click.group(name="tenant")
@click.pass_context
def tenant_group(ctx: click.Context) -> None:
    """Manage Descope tenants."""
    pass


@tenant_group.command(name="list")
@click.pass_obj
def tenant_list(cli_ctx: CliContext) -> None:
    """List all tenants in the project."""
    try:
        # Use factory instead of inline initialization
        client = ClientFactory.create_client()
        manager = TenantManager(client)

        tenants = manager.list_tenants()

        # ... rest of implementation unchanged
    except Exception as e:
        console.print(f"[red]Error:[/red] {e}")
        raise click.Abort()


@tenant_group.command(name="create")
@click.option("--id", "tenant_id", required=True, help="Unique tenant identifier")
@click.option("--name", required=True, help="Tenant display name")
@click.pass_obj
def tenant_create(cli_ctx: CliContext, tenant_id: str, name: str) -> None:
    """Create a new tenant."""
    try:
        # Use factory
        client = ClientFactory.create_client()
        manager = TenantManager(client)

        config = TenantConfig(id=tenant_id, name=name)  # Module-level import, no local

        # ... rest of implementation unchanged
    except Exception as e:
        console.print(f"[red]Error:[/red] {e}")
        raise click.Abort()


@tenant_group.command(name="update")
@click.option("--id", "tenant_id", required=True, help="Tenant ID to update")
@click.option("--name", help="New tenant name")
@click.option("--domains", help="Comma-separated list of domains")
@click.pass_obj
def tenant_update(cli_ctx: CliContext, tenant_id: str, name: str | None, domains: str | None) -> None:
    """Update an existing tenant."""
    try:
        # Use factory
        client = ClientFactory.create_client()
        manager = TenantManager(client)

        # ... rest of implementation unchanged
    except Exception as e:
        console.print(f"[red]Error:[/red] {e}")
        raise click.Abort()


@tenant_group.command(name="delete")
@click.option("--id", "tenant_id", required=True, help="Tenant ID to delete")
@click.option("--force", is_flag=True, help="Skip confirmation prompt")
@click.pass_obj
def tenant_delete(cli_ctx: CliContext, tenant_id: str, force: bool) -> None:
    """Delete a tenant."""
    try:
        # Use factory
        client = ClientFactory.create_client()
        manager = TenantManager(client)

        # ... rest of implementation unchanged
    except Exception as e:
        console.print(f"[red]Error:[/red] {e}")
        raise click.Abort()
```

**Step 3: Run tests to verify**

Run: `pytest tests/unit/cli/test_tenant_cmds.py -v`
Expected: All tests PASS (existing tests cover functionality)

**Step 4: Commit**

```bash
git add src/descope_mgmt/cli/tenant_cmds.py tests/unit/cli/test_tenant_cmds.py
git commit -m "refactor: use client factory in tenant commands

- Replace 4 instances of inline client initialization with factory
- Move TenantConfig import to module level (fix anti-pattern)
- No functional changes, existing tests verify behavior"
```

---

## Task 3: Update Flow Commands to Use Factory

**Agent:** python-pro

**Files:**
- Modify: `src/descope_mgmt/cli/flow_cmds.py:1-20,35-50,65-80` (2 command functions)
- Modify: `tests/unit/cli/test_flow_cmds.py:1-10` (imports)

**Step 1: Update flow_cmds.py implementation**

Modify `src/descope_mgmt/cli/flow_cmds.py`:

```python
"""Flow management commands."""

import click

from descope_mgmt.api.client_factory import ClientFactory
from descope_mgmt.cli.context import CliContext
from descope_mgmt.cli.output import console
from descope_mgmt.domain.flow_manager import FlowManager


@click.group(name="flow")
@click.pass_context
def flow_group(ctx: click.Context) -> None:
    """Manage Descope authentication flows."""
    pass


@flow_group.command(name="list")
@click.pass_obj
def flow_list(cli_ctx: CliContext) -> None:
    """List all authentication flows."""
    try:
        # Use factory instead of inline initialization
        client = ClientFactory.create_client()
        manager = FlowManager(client)

        flows = manager.list_flows()

        # ... rest of implementation unchanged
    except Exception as e:
        console.print(f"[red]Error:[/red] {e}")
        raise click.Abort()


@flow_group.command(name="deploy")
@click.option("--flow-id", required=True, help="Flow identifier")
@click.option("--screen-id", required=True, help="Screen identifier")
@click.pass_obj
def flow_deploy(cli_ctx: CliContext, flow_id: str, screen_id: str) -> None:
    """Deploy an authentication flow."""
    try:
        # Use factory
        client = ClientFactory.create_client()
        manager = FlowManager(client)

        # ... rest of implementation unchanged
    except Exception as e:
        console.print(f"[red]Error:[/red] {e}")
        raise click.Abort()
```

**Step 2: Run tests to verify**

Run: `pytest tests/unit/cli/test_flow_cmds.py -v`
Expected: All tests PASS

**Step 3: Run full test suite**

Run: `pytest tests/ -v --cov=src/descope_mgmt --cov-report=term-missing`
Expected: 109 tests PASS, coverage ≥90%

**Step 4: Commit**

```bash
git add src/descope_mgmt/cli/flow_cmds.py tests/unit/cli/test_flow_cmds.py
git commit -m "refactor: use client factory in flow commands

- Replace 2 instances of inline client initialization with factory
- Eliminates all code duplication from Week 2 technical debt
- Total: 6 command locations now use centralized factory"
```

---

## Chunk Complete Checklist

- [ ] ClientFactory created with tests (Task 1)
- [ ] Tenant commands refactored to use factory (Task 2)
- [ ] Flow commands refactored to use factory (Task 3)
- [ ] All 109+ tests passing
- [ ] Coverage ≥90%
- [ ] mypy, ruff, lint-imports passing
- [ ] 3 commits pushed
- [ ] Code duplication eliminated
- [ ] Local import anti-pattern fixed

---

## Verification Commands

```bash
# Run all tests
pytest tests/ -v --cov=src/descope_mgmt --cov-report=term-missing

# Quality checks
mypy src/
ruff check .
lint-imports

# Manual verification - commands still work
descope-mgmt tenant list --help
descope-mgmt flow list --help
```

**Expected:** All tests pass, all quality checks pass, commands display help correctly.
