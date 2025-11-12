# Chunk 4: Progress Indicators

**Status:** pending
**Dependencies:** chunk-001
**Estimated Time:** 30 minutes

---

## Task 1: Create Progress Tracking Utilities

**Files:**
- Create: `src/descope_mgmt/utils/progress.py`
- Create: `tests/unit/utils/test_progress.py`

**Step 1: Write failing tests**

Create `tests/unit/utils/test_progress.py`:
```python
"""Tests for progress tracking"""
import pytest
from rich.progress import Progress
from descope_mgmt.utils.progress import (
    create_progress_bar,
    track_batch_operation
)


def test_create_progress_bar():
    """Should create Rich progress bar with custom columns"""
    progress = create_progress_bar()

    assert isinstance(progress, Progress)
    # Should have description and bar columns
    assert progress is not None


def test_track_batch_operation():
    """Should track batch operation progress"""
    items = ["item1", "item2", "item3"]
    results = []

    def process_item(item):
        results.append(item)
        return f"processed_{item}"

    # Execute with progress tracking
    with track_batch_operation(
        items=items,
        operation_name="Processing items",
        process_fn=process_item
    ) as tracker:
        completed = list(tracker)

    assert len(completed) == 3
    assert len(results) == 3
    assert completed[0] == "processed_item1"
```

**Step 2: Run tests to verify they fail**

Run: `pytest tests/unit/utils/test_progress.py -v`

Expected: FAIL (module not found)

**Step 3: Implement progress utilities**

Create `src/descope_mgmt/utils/progress.py`:
```python
"""Progress tracking utilities."""
from typing import Callable, Iterator, Any, TypeVar
from contextlib import contextmanager
from rich.progress import (
    Progress,
    SpinnerColumn,
    TextColumn,
    BarColumn,
    TaskProgressColumn,
    TimeRemainingColumn
)
from rich.console import Console

console = Console()
T = TypeVar('T')


def create_progress_bar() -> Progress:
    """Create Rich progress bar with standard columns.

    Returns:
        Progress instance
    """
    return Progress(
        SpinnerColumn(),
        TextColumn("[progress.description]{task.description}"),
        BarColumn(),
        TaskProgressColumn(),
        TimeRemainingColumn(),
        console=console
    )


@contextmanager
def track_batch_operation(
    items: list[T],
    operation_name: str,
    process_fn: Callable[[T], Any]
) -> Iterator[Iterator[Any]]:
    """Track progress of batch operation.

    Args:
        items: Items to process
        operation_name: Description of operation
        process_fn: Function to process each item

    Yields:
        Iterator of processed results
    """
    with create_progress_bar() as progress:
        task = progress.add_task(
            f"[cyan]{operation_name}",
            total=len(items)
        )

        def process_with_progress():
            for item in items:
                result = process_fn(item)
                progress.update(task, advance=1)
                yield result

        yield process_with_progress()
```

**Step 4: Run tests to verify they pass**

Run: `pytest tests/unit/utils/test_progress.py -v`

Expected: PASS (all 2 tests)

**Step 5: Update utils exports**

Modify `src/descope_mgmt/utils/__init__.py`:
```python
"""Utility modules for descope-mgmt."""
from descope_mgmt.utils.config_loader import ConfigLoader
from descope_mgmt.utils.env_vars import substitute_env_vars
from descope_mgmt.utils.logging import configure_logging
from descope_mgmt.utils.display import (
    format_tenant_table,
    format_diff_display,
    format_progress_bar
)
from descope_mgmt.utils.progress import (
    create_progress_bar,
    track_batch_operation
)

__all__ = [
    "ConfigLoader",
    "substitute_env_vars",
    "configure_logging",
    "format_tenant_table",
    "format_diff_display",
    "format_progress_bar",
    "create_progress_bar",
    "track_batch_operation",
]
```

**Step 6: Commit**

```bash
git add src/descope_mgmt/utils/progress.py tests/unit/utils/test_progress.py src/descope_mgmt/utils/__init__.py
git commit -m "feat: add progress tracking utilities for batch operations"
```

---

## Chunk Complete Checklist

- [ ] Progress bar creation utility (1 test)
- [ ] Batch operation tracking (1 test)
- [ ] Utils module exports updated
- [ ] All commits made
- [ ] 2 tests passing total
