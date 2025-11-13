# Chunk 12: CLI Entry Point and Basic Structure

**Status:** pending
**Dependencies:** chunk-011-descope-client
**Complexity:** medium
**Estimated Time:** 20 minutes
**Tasks:** 3

---

## Task 1: Create CLI Main Entry Point

**Files:**
- Create: `src/descope_mgmt/cli/main.py`
- Create: `tests/unit/cli/test_main.py`

**Step 1: Write failing tests**

Create `tests/unit/cli/__init__.py`:
```python
"""Unit tests for CLI layer."""
```

Create `tests/unit/cli/test_main.py`:
```python
"""Tests for CLI main entry point."""

from click.testing import CliRunner

from descope_mgmt.cli.main import cli


def test_cli_help() -> None:
    """Test CLI help output."""
    runner = CliRunner()
    result = runner.invoke(cli, ["--help"])
    assert result.exit_code == 0
    assert "descope-mgmt" in result.output.lower()


def test_cli_version() -> None:
    """Test CLI version output."""
    runner = CliRunner()
    result = runner.invoke(cli, ["--version"])
    assert result.exit_code == 0
    assert "0.1.0" in result.output


def test_cli_tenant_command_exists() -> None:
    """Test tenant command group exists."""
    runner = CliRunner()
    result = runner.invoke(cli, ["tenant", "--help"])
    assert result.exit_code == 0
    assert "tenant" in result.output.lower()
```

**Step 2: Run tests (expect failure)**

```bash
pytest tests/unit/cli/test_main.py -v
```

Expected: All 3 tests FAIL

**Step 3: Implement CLI main**

Create `src/descope_mgmt/cli/__init__.py`:
```python
"""CLI layer for user interactions."""
```

Create `src/descope_mgmt/cli/main.py`:
```python
"""Main CLI entry point for descope-mgmt."""

import click

from descope_mgmt import __version__


@click.group()
@click.version_option(version=__version__, prog_name="descope-mgmt")
@click.pass_context
def cli(ctx: click.Context) -> None:
    """Descope Management CLI.

    Infrastructure-as-code tool for managing Descope authentication.
    """
    # Ensure context object exists
    ctx.ensure_object(dict)


@cli.group()
@click.pass_context
def tenant(ctx: click.Context) -> None:
    """Manage Descope tenants.

    Commands for creating, updating, deleting, and syncing tenants.
    """
    pass


@cli.group()
@click.pass_context
def flow(ctx: click.Context) -> None:
    """Manage authentication flows.

    Commands for deploying and managing authentication flow templates.
    """
    pass


if __name__ == "__main__":
    cli()
```

**Step 4: Run tests (expect pass)**

```bash
pytest tests/unit/cli/test_main.py -v
```

Expected: All 3 tests PASS

**Step 5: Test CLI from command line**

```bash
descope-mgmt --help
descope-mgmt --version
descope-mgmt tenant --help
descope-mgmt flow --help
```

Expected: All commands work and display help

**Step 6: Commit**

```bash
git add src/descope_mgmt/cli/ tests/unit/cli/
git commit -m "feat: add CLI entry point with tenant and flow command groups"
```

---

## Task 2: Create CLI Context Manager

**Files:**
- Create: `src/descope_mgmt/cli/context.py`
- Create: `tests/unit/cli/test_context.py`

**Step 1: Write failing tests**

Create `tests/unit/cli/test_context.py`:
```python
"""Tests for CLI context manager."""

from pathlib import Path

import pytest

from descope_mgmt.cli.context import CliContext
from descope_mgmt.types.project import ProjectSettings


def test_cli_context_initialization() -> None:
    """Test CLI context initializes correctly."""
    project = ProjectSettings(
        project_id="P2test",
        management_key="K2secret",
        environment="test"
    )
    ctx = CliContext(project=project)
    assert ctx.project.environment == "test"


def test_cli_context_verbose_mode() -> None:
    """Test CLI context verbose mode."""
    project = ProjectSettings(
        project_id="P2test",
        management_key="K2secret",
        environment="test"
    )
    ctx = CliContext(project=project, verbose=True)
    assert ctx.verbose is True


def test_cli_context_dry_run() -> None:
    """Test CLI context dry-run mode."""
    project = ProjectSettings(
        project_id="P2test",
        management_key="K2secret",
        environment="test"
    )
    ctx = CliContext(project=project, dry_run=True)
    assert ctx.dry_run is True
```

**Step 2: Run tests (expect failure)**

```bash
pytest tests/unit/cli/test_context.py -v
```

Expected: All 3 tests FAIL

**Step 3: Implement CliContext**

Create `src/descope_mgmt/cli/context.py`:
```python
"""CLI context for passing state between commands."""

from pathlib import Path

from descope_mgmt.types.project import ProjectSettings


class CliContext:
    """Context object for CLI commands.

    Stores shared state like project settings, verbosity, and dry-run mode.
    Passed between Click commands via @click.pass_context.
    """

    def __init__(
        self,
        project: ProjectSettings,
        verbose: bool = False,
        dry_run: bool = False,
        config_path: Path | None = None
    ) -> None:
        """Initialize CLI context.

        Args:
            project: Project settings for this environment
            verbose: Enable verbose output
            dry_run: Enable dry-run mode (no actual API calls)
            config_path: Path to configuration file
        """
        self.project = project
        self.verbose = verbose
        self.dry_run = dry_run
        self.config_path = config_path
```

**Step 4: Run tests (expect pass)**

```bash
pytest tests/unit/cli/test_context.py -v
```

Expected: All 3 tests PASS

**Step 5: Commit**

```bash
git add src/descope_mgmt/cli/context.py tests/unit/cli/test_context.py
git commit -m "feat: add CLI context manager for command state"
```

---

## Task 3: Week 1 Final Verification

**Step 1: Run complete test suite**

```bash
pytest tests/ -v --cov=src/descope_mgmt --cov-report=html --cov-report=term
```

Expected output:
- All tests PASS (50+ tests total)
- Coverage >85%
- HTML report generated in `htmlcov/`

**Step 2: Verify all quality checks**

```bash
# Type checking
mypy src/

# Linting
ruff check .

# Formatting
ruff format --check .

# Import boundaries
lint-imports

# Pre-commit (runs all checks)
pre-commit run --all-files
```

Expected: All checks PASS

**Step 3: Test CLI commands**

```bash
# Test all CLI commands work
descope-mgmt --version
descope-mgmt --help
descope-mgmt tenant --help
descope-mgmt flow --help
```

Expected: All commands display help correctly

**Step 4: Create Week 1 Summary**

Count test statistics:
```bash
pytest tests/ --collect-only -q | tail -1
```

Count lines of code:
```bash
find src/descope_mgmt -name "*.py" -exec wc -l {} + | tail -1
```

**Step 5: Final commit**

```bash
git add .
git commit -m "feat: complete Week 1 foundation (types, config, api, cli)"
```

**Step 6: Create checkpoint tag**

```bash
git tag -a week1-complete -m "Week 1 Complete: Foundation, types, config, API client, CLI entry"
```

---

## Chunk Complete Checklist

- [ ] CLI entry point with command groups (3 tests)
- [ ] CLI context manager (3 tests)
- [ ] All Week 1 tests passing (50+ total tests)
- [ ] Test coverage >85%
- [ ] All quality checks pass (mypy, ruff, import-linter)
- [ ] CLI commands functional from terminal
- [ ] Week 1 complete and tagged
- [ ] Ready for Week 2 (CLI commands implementation)

---

## Week 1 Deliverables Summary

**Files Created**: 40+ files
**Lines of Code**: ~2,000 lines
**Tests Written**: 50+ tests
**Test Coverage**: >85%

**Modules Complete**:
- ✅ Type system (protocols, models, exceptions)
- ✅ Configuration (YAML loader, env var substitution)
- ✅ API layer (rate limiter, executor, Descope client)
- ✅ CLI foundation (entry point, context manager)

**Quality**:
- ✅ mypy strict mode passes
- ✅ ruff formatting and linting passes
- ✅ import-linter validates layer boundaries
- ✅ Pre-commit hooks configured and passing

**Ready for Week 2**: CLI commands (tenant list, tenant create, tenant sync)
