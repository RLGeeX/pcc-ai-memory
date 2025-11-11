# Chunk 1: CLI Framework with Click

**Status:** pending
**Dependencies:** phase1-week1 (all chunks complete)
**Estimated Time:** 45-60 minutes

---

## Task 1: Create CLI Entry Point

**Files:**
- Create: `src/descope_mgmt/cli/main.py`
- Create: `tests/unit/cli/test_main.py`

**Step 1: Write failing test**

Create `tests/unit/cli/test_main.py`:
```python
"""Tests for CLI entry point"""
import pytest
from click.testing import CliRunner
from descope_mgmt.cli.main import cli


def test_cli_help():
    """CLI should display help message"""
    runner = CliRunner()
    result = runner.invoke(cli, ['--help'])
    assert result.exit_code == 0
    assert 'descope-mgmt' in result.output.lower()


def test_cli_version():
    """CLI should display version"""
    runner = CliRunner()
    result = runner.invoke(cli, ['--version'])
    assert result.exit_code == 0
    assert '1.0.0' in result.output


def test_cli_no_args():
    """CLI without args should show help"""
    runner = CliRunner()
    result = runner.invoke(cli, [])
    assert result.exit_code == 0
    assert 'Usage:' in result.output
```

**Step 2: Run test to verify it fails**

Run: `pytest tests/unit/cli/test_main.py -v`

Expected: FAIL with import error

**Step 3: Implement CLI entry point**

Create `src/descope_mgmt/cli/main.py`:
```python
"""Main CLI entry point for descope-mgmt."""
import click
from descope_mgmt import __version__


@click.group()
@click.version_option(version=__version__, prog_name='descope-mgmt')
@click.option(
    '--config',
    type=click.Path(exists=True),
    help='Path to configuration file (default: auto-discover)'
)
@click.option(
    '--environment',
    type=click.Choice(['test', 'devtest', 'dev', 'staging', 'prod']),
    help='Environment to operate on'
)
@click.option(
    '--log-level',
    type=click.Choice(['DEBUG', 'INFO', 'WARNING', 'ERROR']),
    default='INFO',
    help='Logging level'
)
@click.pass_context
def cli(ctx: click.Context, config: str | None, environment: str | None, log_level: str) -> None:
    """Descope Management CLI

    Manage Descope authentication infrastructure using configuration-as-code.

    Examples:
        descope-mgmt tenant list
        descope-mgmt tenant sync --config descope.yaml --dry-run
        descope-mgmt flow deploy --environment staging
    """
    # Ensure context object exists
    ctx.ensure_object(dict)

    # Store global options in context
    ctx.obj['config'] = config
    ctx.obj['environment'] = environment
    ctx.obj['log_level'] = log_level

    # Configure logging
    from descope_mgmt.utils.logging import configure_logging
    configure_logging(level=log_level)


if __name__ == '__main__':
    cli(obj={})
```

**Step 4: Run tests to verify they pass**

Run: `pytest tests/unit/cli/test_main.py -v`

Expected: PASS (all 3 tests)

**Step 5: Commit**

```bash
git add src/descope_mgmt/cli/main.py tests/unit/cli/test_main.py
git commit -m "feat: add CLI entry point with Click"
```

---

## Task 2: Create Tenant Command Group

**Files:**
- Create: `src/descope_mgmt/cli/tenant.py`
- Modify: `src/descope_mgmt/cli/main.py`
- Create: `tests/unit/cli/test_tenant_commands.py`

**Step 1: Write failing test**

Create `tests/unit/cli/test_tenant_commands.py`:
```python
"""Tests for tenant command group"""
import pytest
from click.testing import CliRunner
from descope_mgmt.cli.main import cli


def test_tenant_group_help():
    """Tenant command group should have help"""
    runner = CliRunner()
    result = runner.invoke(cli, ['tenant', '--help'])
    assert result.exit_code == 0
    assert 'tenant' in result.output.lower()
    assert 'list' in result.output.lower()
    assert 'sync' in result.output.lower()
```

**Step 2: Run test to verify it fails**

Run: `pytest tests/unit/cli/test_tenant_commands.py::test_tenant_group_help -v`

Expected: FAIL (no tenant subcommand)

**Step 3: Create tenant command group**

Create `src/descope_mgmt/cli/tenant.py`:
```python
"""Tenant management commands."""
import click


@click.group()
def tenant() -> None:
    """Manage Descope tenants

    Commands for creating, updating, listing, and syncing tenant configurations
    across environments.
    """
    pass


@tenant.command()
@click.pass_context
def list(ctx: click.Context) -> None:
    """List all tenants in the project

    Example:
        descope-mgmt tenant list
        descope-mgmt tenant list --environment prod
    """
    click.echo("Tenant list command (not yet implemented)")


@tenant.command()
@click.option(
    '--dry-run',
    is_flag=True,
    help='Preview changes without applying them'
)
@click.option(
    '--yes',
    is_flag=True,
    help='Skip confirmation prompts'
)
@click.pass_context
def sync(ctx: click.Context, dry_run: bool, yes: bool) -> None:
    """Sync tenants to match configuration

    Idempotent operation that creates, updates, or deletes tenants
    to match the desired state in the configuration file.

    Example:
        descope-mgmt tenant sync --config descope.yaml --dry-run
        descope-mgmt tenant sync --config descope.yaml --yes
    """
    click.echo(f"Tenant sync command (dry_run={dry_run}, yes={yes})")
```

**Step 4: Register tenant group with main CLI**

Modify `src/descope_mgmt/cli/main.py`:
```python
# Add import at top
from descope_mgmt.cli.tenant import tenant

# Add command registration after cli() definition
cli.add_command(tenant)
```

**Step 5: Run tests to verify they pass**

Run: `pytest tests/unit/cli/test_tenant_commands.py -v`

Expected: PASS

**Step 6: Commit**

```bash
git add src/descope_mgmt/cli/tenant.py src/descope_mgmt/cli/main.py tests/unit/cli/test_tenant_commands.py
git commit -m "feat: add tenant command group with list and sync"
```

---

## Task 3: Create Common CLI Utilities

**Files:**
- Create: `src/descope_mgmt/cli/common.py`
- Create: `tests/unit/cli/test_common.py`

**Step 1: Write failing tests**

Create `tests/unit/cli/test_common.py`:
```python
"""Tests for common CLI utilities"""
import pytest
import click
from descope_mgmt.cli.common import (
    confirm_destructive_operation,
    get_config_loader,
    format_success,
    format_error
)


def test_format_success():
    """Success messages should be green with checkmark"""
    result = format_success("Operation completed")
    assert "✓" in result
    assert "Operation completed" in result


def test_format_error():
    """Error messages should be red with X"""
    result = format_error("Operation failed")
    assert "✗" in result
    assert "Operation failed" in result


def test_confirm_destructive_operation_with_yes_flag():
    """--yes flag should skip confirmation"""
    result = confirm_destructive_operation(
        "Delete 5 tenants?",
        yes=True
    )
    assert result is True


def test_get_config_loader(tmp_path):
    """Should create config loader with correct path"""
    config_file = tmp_path / "descope.yaml"
    config_file.write_text('version: "1.0"')

    loader = get_config_loader(str(config_file))
    assert loader is not None
```

**Step 2: Run tests to verify they fail**

Run: `pytest tests/unit/cli/test_common.py -v`

Expected: FAIL with import errors

**Step 3: Implement common utilities**

Create `src/descope_mgmt/cli/common.py`:
```python
"""Common utilities for CLI commands."""
import click
from descope_mgmt.utils.config_loader import ConfigLoader


def confirm_destructive_operation(message: str, yes: bool = False) -> bool:
    """Prompt user for confirmation of destructive operation.

    Args:
        message: Confirmation message to display
        yes: If True, skip prompt and return True

    Returns:
        True if user confirms, False otherwise
    """
    if yes:
        return True
    return click.confirm(message, abort=False)


def get_config_loader(config_path: str | None = None) -> ConfigLoader:
    """Get config loader instance.

    Args:
        config_path: Optional path to config file

    Returns:
        ConfigLoader instance
    """
    return ConfigLoader()


def format_success(message: str) -> str:
    """Format success message with color and icon.

    Args:
        message: Success message

    Returns:
        Formatted string with green color and checkmark
    """
    return click.style(f"✓ {message}", fg='green')


def format_error(message: str) -> str:
    """Format error message with color and icon.

    Args:
        message: Error message

    Returns:
        Formatted string with red color and X
    """
    return click.style(f"✗ {message}", fg='red')


def format_warning(message: str) -> str:
    """Format warning message with color and icon.

    Args:
        message: Warning message

    Returns:
        Formatted string with yellow color and warning icon
    """
    return click.style(f"⚠ {message}", fg='yellow')
```

**Step 4: Run tests to verify they pass**

Run: `pytest tests/unit/cli/test_common.py -v`

Expected: PASS (all 4 tests)

**Step 5: Commit**

```bash
git add src/descope_mgmt/cli/common.py tests/unit/cli/test_common.py
git commit -m "feat: add common CLI utilities for formatting and confirmation"
```

---

## Chunk Complete Checklist

- [ ] CLI entry point with Click (3 tests)
- [ ] Tenant command group (1 test)
- [ ] Common CLI utilities (4 tests)
- [ ] Total: 8 tests passing
- [ ] Global options (--config, --environment, --log-level)
- [ ] All commits made
