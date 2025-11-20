# Chunk 2: Progress Indicators - Core

**Status:** pending
**Dependencies:** none
**Complexity:** simple
**Estimated Time:** 15 minutes
**Tasks:** 2

---

## Task 1: Create ProgressTracker Utility

**Agent:** python-pro
**Files:**
- Create: `src/descope_mgmt/cli/progress.py`
- Create: `tests/unit/cli/test_progress.py`

**Step 1: Write the failing test**

Create test file:

```python
"""Tests for progress tracking utilities."""

from unittest.mock import MagicMock

from descope_mgmt.cli.progress import ProgressTracker


def test_progress_tracker_context_manager():
    """Test ProgressTracker as context manager."""
    tracker = ProgressTracker(total=10, description="Processing")

    with tracker as progress:
        assert progress is not None
        for i in range(10):
            progress.update(1)


def test_progress_tracker_with_custom_console():
    """Test ProgressTracker with custom console."""
    mock_console = MagicMock()
    tracker = ProgressTracker(total=5, description="Testing", console=mock_console)

    with tracker as progress:
        progress.update(1)

    # Verify console was used
    assert mock_console is not None


def test_progress_tracker_disabled():
    """Test ProgressTracker can be disabled."""
    tracker = ProgressTracker(total=10, description="Silent", enabled=False)

    with tracker as progress:
        # Should not raise even when disabled
        progress.update(1)
```

**Step 2: Run test to verify it fails**

```bash
pytest tests/unit/cli/test_progress.py -v
```

Expected: FAIL - "ModuleNotFoundError: No module named 'descope_mgmt.cli.progress'"

**Step 3: Write minimal implementation**

Create `src/descope_mgmt/cli/progress.py`:

```python
"""Progress tracking utilities using Rich."""

from contextlib import contextmanager
from typing import Generator

from rich.console import Console
from rich.progress import (
    BarColumn,
    MofNCompleteColumn,
    Progress,
    TaskID,
    TextColumn,
    TimeRemainingColumn,
)

from descope_mgmt.cli.output import get_console


class ProgressTracker:
    """Context manager for tracking progress of operations."""

    def __init__(
        self,
        total: int,
        description: str,
        console: Console | None = None,
        enabled: bool = True,
    ) -> None:
        """Initialize progress tracker.

        Args:
            total: Total number of items to process
            description: Description of the operation
            console: Rich Console instance (defaults to shared console)
            enabled: Whether progress tracking is enabled
        """
        self.total = total
        self.description = description
        self.console = console or get_console()
        self.enabled = enabled
        self._progress: Progress | None = None
        self._task_id: TaskID | None = None

    def __enter__(self) -> "ProgressUpdater":
        """Start progress tracking."""
        if not self.enabled:
            return ProgressUpdater(None, None)

        self._progress = Progress(
            TextColumn("[bold blue]{task.description}"),
            BarColumn(),
            MofNCompleteColumn(),
            TimeRemainingColumn(),
            console=self.console,
        )
        self._progress.__enter__()
        self._task_id = self._progress.add_task(self.description, total=self.total)

        return ProgressUpdater(self._progress, self._task_id)

    def __exit__(self, exc_type, exc_val, exc_tb) -> None:
        """Stop progress tracking."""
        if self._progress:
            self._progress.__exit__(exc_type, exc_val, exc_tb)


class ProgressUpdater:
    """Helper class for updating progress."""

    def __init__(self, progress: Progress | None, task_id: TaskID | None) -> None:
        """Initialize progress updater.

        Args:
            progress: Rich Progress instance
            task_id: Task ID to update
        """
        self._progress = progress
        self._task_id = task_id

    def update(self, advance: int = 1) -> None:
        """Advance progress by N steps.

        Args:
            advance: Number of steps to advance
        """
        if self._progress and self._task_id is not None:
            self._progress.update(self._task_id, advance=advance)
```

**Step 4: Run test to verify it passes**

```bash
pytest tests/unit/cli/test_progress.py -v
```

Expected: PASS - All 3 tests passing

**Step 5: Verify coverage**

```bash
pytest tests/unit/cli/test_progress.py --cov=src/descope_mgmt/cli/progress --cov-report=term-missing
```

Expected: 95%+ coverage

**Step 6: Commit**

```bash
git add src/descope_mgmt/cli/progress.py tests/unit/cli/test_progress.py
git commit -m "feat: add progress tracker utility with Rich"
```

---

## Task 2: Add Progress to Tenant List Command

**Agent:** python-pro
**Files:**
- Modify: `src/descope_mgmt/cli/tenant_cmds.py`
- Modify: `tests/unit/cli/test_tenant_cmds.py`

**Step 1: Write the failing test**

Add test to `tests/unit/cli/test_tenant_cmds.py`:

```python
from unittest.mock import patch


def test_list_tenants_shows_progress(
    runner: CliRunner, fake_client: FakeDescopeClient
) -> None:
    """Test that tenant list shows progress indicator."""
    # Add multiple tenants to fake client
    fake_client.tenants = [
        TenantResponse(id=f"tenant-{i}", name=f"Tenant {i}")
        for i in range(10)
    ]

    with patch("descope_mgmt.cli.tenant_cmds.ProgressTracker") as mock_tracker:
        result = runner.invoke(
            cli_app,
            ["tenant", "list", "--project-id", "test", "--management-key", "test"],
        )

        assert result.exit_code == 0
        # Verify ProgressTracker was created with correct params
        mock_tracker.assert_called_once()
        call_args = mock_tracker.call_args
        assert call_args[1]["total"] == 10
        assert "Processing tenants" in call_args[1]["description"]
```

**Step 2: Run test to verify it fails**

```bash
pytest tests/unit/cli/test_tenant_cmds.py::test_list_tenants_shows_progress -v
```

Expected: FAIL - ProgressTracker not called

**Step 3: Update list_tenants command**

Modify `src/descope_mgmt/cli/tenant_cmds.py`:

```python
# Add import at top
from descope_mgmt.cli.progress import ProgressTracker

# Update list_tenants command:

@tenant_app.command(name="list")
def list_tenants(
    ctx: typer.Context,
    project_id: Annotated[str | None, typer.Option(...)] = None,
    management_key: Annotated[str | None, typer.Option(...)] = None,
) -> None:
    """List all tenants in the project."""
    console = get_console()
    try:
        client = ClientFactory.create_client(project_id, management_key)
        tenants = client.list_tenants()

        if not tenants:
            console.print("[yellow]No tenants found[/yellow]")
            return

        # Create table
        table = Table(title="Tenants")
        table.add_column("Tenant ID", style="cyan")
        table.add_column("Name", style="green")

        # Add rows with progress
        with ProgressTracker(
            total=len(tenants),
            description="Processing tenants",
            console=console,
        ) as progress:
            for tenant in tenants:
                table.add_row(tenant.id, tenant.name or "")
                progress.update(1)

        console.print(table)

    except Exception as e:
        console.print(f"[red]Error:[/red] {ErrorFormatter.format(e)}")
        raise typer.Exit(1)
```

**Step 4: Run test to verify it passes**

```bash
pytest tests/unit/cli/test_tenant_cmds.py::test_list_tenants_shows_progress -v
```

Expected: PASS

**Step 5: Run all CLI tests**

```bash
pytest tests/unit/cli/ -v
```

Expected: All tests passing

**Step 6: Manual verification**

```bash
descope-mgmt tenant list
```

Expected: Progress bar displayed while processing tenants

**Step 7: Commit**

```bash
git add src/descope_mgmt/cli/tenant_cmds.py tests/unit/cli/test_tenant_cmds.py
git commit -m "feat: add progress indicator to tenant list command"
```

---

## Chunk Complete Checklist

- [ ] Task 1: ProgressTracker utility created with 3 tests
- [ ] Task 2: Progress added to tenant list command
- [ ] All tests passing (159+ total)
- [ ] Coverage maintained at 94%+
- [ ] Code committed (2 commits)
- [ ] Ready for Chunk 3
