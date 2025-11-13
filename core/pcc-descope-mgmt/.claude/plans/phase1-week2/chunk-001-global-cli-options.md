# Chunk 1: Global CLI Options & Rich Setup

**Status:** pending
**Dependencies:** Week 1 complete
**Complexity:** simple
**Estimated Time:** 30 minutes
**Tasks:** 3

---

## Task 1: Add Rich Dependency and Setup

**Files:**
- Modify: `pyproject.toml:32` (dependencies section)
- Create: `src/descope_mgmt/cli/output.py`
- Test: `tests/unit/cli/test_output.py`

**Step 1: Write the failing test for Console wrapper**

Create `tests/unit/cli/test_output.py`:
```python
"""Tests for CLI output utilities."""

from descope_mgmt.cli.output import get_console


def test_get_console_returns_rich_console() -> None:
    """Test that get_console returns a Rich Console instance."""
    console = get_console()
    assert hasattr(console, "print")
    assert hasattr(console, "log")


def test_get_console_returns_same_instance() -> None:
    """Test that get_console returns singleton instance."""
    console1 = get_console()
    console2 = get_console()
    assert console1 is console2
```

**Step 2: Run test to verify it fails**

```bash
pytest tests/unit/cli/test_output.py -v
```
Expected: FAIL with "No module named 'descope_mgmt.cli.output'"

**Step 3: Add Rich to dependencies**

Update `pyproject.toml` dependencies:
```toml
dependencies = [
    "click>=8.1.0",
    "descope>=1.0.0",
    "pydantic>=2.0.0",
    "pyrate-limiter>=3.0.0",
    "pyyaml>=6.0",
    "requests>=2.31.0",
    "rich>=13.7.0",  # Add this line
]
```

**Step 4: Install Rich**

```bash
pip install -e .
```

**Step 5: Write minimal implementation**

Create `src/descope_mgmt/cli/output.py`:
```python
"""CLI output utilities using Rich."""

from rich.console import Console

_console: Console | None = None


def get_console() -> Console:
    """Get or create the Rich Console singleton.

    Returns:
        Console: Rich Console instance for formatted output
    """
    global _console
    if _console is None:
        _console = Console()
    return _console
```

**Step 6: Run tests to verify they pass**

```bash
pytest tests/unit/cli/test_output.py -v
```
Expected: PASS (2 tests)

**Step 7: Commit**

```bash
git add pyproject.toml src/descope_mgmt/cli/output.py tests/unit/cli/test_output.py
git commit -m "feat: add Rich console utilities for CLI output"
```

---

## Task 2: Add Global CLI Options

**Files:**
- Modify: `src/descope_mgmt/cli/main.py:8-14`
- Modify: `tests/unit/cli/test_main.py`

**Step 1: Write failing tests for global options**

Add to `tests/unit/cli/test_main.py`:
```python
def test_cli_accepts_verbose_flag() -> None:
    """Test that CLI accepts --verbose flag."""
    runner = CliRunner()
    result = runner.invoke(cli, ["--verbose", "--version"])
    assert result.exit_code == 0


def test_cli_accepts_dry_run_flag() -> None:
    """Test that CLI accepts --dry-run flag."""
    runner = CliRunner()
    result = runner.invoke(cli, ["--dry-run", "--version"])
    assert result.exit_code == 0


def test_cli_accepts_config_option() -> None:
    """Test that CLI accepts --config option."""
    runner = CliRunner()
    result = runner.invoke(cli, ["--config", "/tmp/test.yaml", "--version"])
    assert result.exit_code == 0
```

**Step 2: Run tests to verify they fail**

```bash
pytest tests/unit/cli/test_main.py::test_cli_accepts_verbose_flag -v
pytest tests/unit/cli/test_main.py::test_cli_accepts_dry_run_flag -v
pytest tests/unit/cli/test_main.py::test_cli_accepts_config_option -v
```
Expected: FAIL with "no such option" errors

**Step 3: Implement global options**

Update `src/descope_mgmt/cli/main.py`:
```python
"""Main CLI entry point for descope-mgmt."""

from pathlib import Path

import click

from descope_mgmt import __version__
from descope_mgmt.cli.context import CliContext


@click.group()
@click.version_option(version=__version__, prog_name="descope-mgmt")
@click.option(
    "--verbose",
    is_flag=True,
    default=False,
    help="Enable verbose output for debugging.",
)
@click.option(
    "--dry-run",
    is_flag=True,
    default=False,
    help="Perform a dry run without making actual changes.",
)
@click.option(
    "--config",
    type=click.Path(exists=False, path_type=Path),
    default=None,
    help="Path to configuration file (default: ./descope.yaml).",
)
@click.pass_context
def cli(ctx: click.Context, verbose: bool, dry_run: bool, config: Path | None) -> None:
    """Descope Management CLI - Infrastructure-as-code for Descope authentication."""
    # Store options in context for subcommands
    ctx.ensure_object(dict)
    ctx.obj["verbose"] = verbose
    ctx.obj["dry_run"] = dry_run
    ctx.obj["config"] = config


@cli.group()
def tenant() -> None:
    """Manage Descope tenants."""
    pass


@cli.group()
def flow() -> None:
    """Manage Descope flows."""
    pass
```

**Step 4: Run tests to verify they pass**

```bash
pytest tests/unit/cli/test_main.py -v
```
Expected: PASS (all tests including 3 new ones)

**Step 5: Commit**

```bash
git add src/descope_mgmt/cli/main.py tests/unit/cli/test_main.py
git commit -m "feat: add global CLI options (verbose, dry-run, config)"
```

---

## Task 3: Verify Global Options Work

**Files:**
- None (manual testing)

**Step 1: Test help output**

```bash
descope-mgmt --help
```
Expected: Help text shows --verbose, --dry-run, --config options

**Step 2: Test combined options**

```bash
descope-mgmt --verbose --dry-run --version
```
Expected: Version output without errors

**Step 3: Run full test suite**

```bash
pytest tests/ -v
```
Expected: All tests pass (67+ tests)

**Step 4: Run quality checks**

```bash
mypy src/
ruff check .
lint-imports
```
Expected: All checks pass

---

## Chunk Complete Checklist

- [ ] Rich dependency added and installed
- [ ] Console utilities implemented and tested
- [ ] Global CLI options functional
- [ ] All tests passing (67+ tests)
- [ ] Quality checks passing
- [ ] 2 commits created
- [ ] Ready for chunk 2
