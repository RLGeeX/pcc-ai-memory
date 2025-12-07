# Chunk 1: BatchExecutor Core with Result Types

**Status:** pending
**Dependencies:** none
**Complexity:** medium
**Estimated Time:** 15 minutes
**Tasks:** 3
**Phase:** Batch Executor Refactoring
**Jira:** PCC-252

---

## Task 1: Create BatchResult Types

**Agent:** python-pro
**Files:**
- Create: `src/descope_mgmt/types/batch.py`
- Test: `tests/unit/types/test_batch.py`

**Step 1: Write failing tests for BatchResult**

```python
# tests/unit/types/test_batch.py
"""Tests for batch operation types."""

import pytest
from descope_mgmt.types.batch import BatchResult, BatchItemResult


class TestBatchItemResult:
    """Tests for BatchItemResult."""

    def test_success_result(self) -> None:
        """Test successful item result."""
        result = BatchItemResult(
            item_id="tenant-1",
            success=True,
            result={"id": "tenant-1", "name": "Test"},
        )
        assert result.success is True
        assert result.error is None

    def test_failed_result(self) -> None:
        """Test failed item result."""
        result = BatchItemResult(
            item_id="tenant-2",
            success=False,
            error="API rate limit exceeded",
        )
        assert result.success is False
        assert result.error == "API rate limit exceeded"


class TestBatchResult:
    """Tests for BatchResult."""

    def test_all_successful(self) -> None:
        """Test batch with all successful items."""
        items = [
            BatchItemResult(item_id="1", success=True),
            BatchItemResult(item_id="2", success=True),
        ]
        result = BatchResult(items=items, total=2)
        assert result.successful == 2
        assert result.failed == 0
        assert result.all_successful is True

    def test_partial_failure(self) -> None:
        """Test batch with some failures."""
        items = [
            BatchItemResult(item_id="1", success=True),
            BatchItemResult(item_id="2", success=False, error="Failed"),
        ]
        result = BatchResult(items=items, total=2)
        assert result.successful == 1
        assert result.failed == 1
        assert result.all_successful is False

    def test_failed_items_property(self) -> None:
        """Test failed_items returns only failures."""
        items = [
            BatchItemResult(item_id="1", success=True),
            BatchItemResult(item_id="2", success=False, error="E1"),
            BatchItemResult(item_id="3", success=False, error="E2"),
        ]
        result = BatchResult(items=items, total=3)
        failed = result.failed_items
        assert len(failed) == 2
        assert all(not f.success for f in failed)
```

**Step 2: Run tests to verify they fail**

```bash
pytest tests/unit/types/test_batch.py -v
```

Expected: FAIL with ModuleNotFoundError

**Step 3: Implement BatchResult types**

```python
# src/descope_mgmt/types/batch.py
"""Batch operation result types."""

from typing import Any

from pydantic import BaseModel, computed_field


class BatchItemResult(BaseModel):
    """Result of a single item in a batch operation."""

    item_id: str
    success: bool
    result: Any | None = None
    error: str | None = None


class BatchResult(BaseModel):
    """Result of a batch operation."""

    items: list[BatchItemResult]
    total: int

    @computed_field
    @property
    def successful(self) -> int:
        """Count of successful items."""
        return sum(1 for item in self.items if item.success)

    @computed_field
    @property
    def failed(self) -> int:
        """Count of failed items."""
        return sum(1 for item in self.items if not item.success)

    @computed_field
    @property
    def all_successful(self) -> bool:
        """True if all items succeeded."""
        return self.failed == 0

    @property
    def failed_items(self) -> list[BatchItemResult]:
        """Get list of failed items."""
        return [item for item in self.items if not item.success]
```

**Step 4: Run tests to verify they pass**

```bash
pytest tests/unit/types/test_batch.py -v
```

Expected: PASS

**Step 5: Export from types module**

Add to `src/descope_mgmt/types/__init__.py`:
```python
from descope_mgmt.types.batch import BatchItemResult, BatchResult
```

**Step 6: Commit**

```bash
git add src/descope_mgmt/types/batch.py tests/unit/types/test_batch.py src/descope_mgmt/types/__init__.py
git commit -m "feat(types): add BatchResult and BatchItemResult types"
```

---

## Task 2: Create BatchExecutor Domain Class

**Agent:** python-pro
**Files:**
- Create: `src/descope_mgmt/domain/batch_executor.py`
- Test: `tests/unit/domain/test_batch_executor.py`

**Step 1: Write failing tests for BatchExecutor**

```python
# tests/unit/domain/test_batch_executor.py
"""Tests for BatchExecutor."""

from collections.abc import Callable
from typing import Any
from unittest.mock import MagicMock

import pytest

from descope_mgmt.domain.batch_executor import BatchExecutor
from descope_mgmt.types.batch import BatchResult


class TestBatchExecutor:
    """Tests for BatchExecutor."""

    def test_execute_single_success(self) -> None:
        """Test executing a single successful task."""
        executor = BatchExecutor()
        result = executor.execute(lambda: "success")
        assert result == "success"

    def test_execute_single_failure(self) -> None:
        """Test executing a single failing task."""
        executor = BatchExecutor()

        def failing_task() -> str:
            raise ValueError("Task failed")

        with pytest.raises(ValueError, match="Task failed"):
            executor.execute(failing_task)

    def test_execute_batch_all_success(self) -> None:
        """Test batch execution with all successes."""
        executor = BatchExecutor(stop_on_error=False)
        tasks: list[Callable[[], int]] = [
            lambda: 1,
            lambda: 2,
            lambda: 3,
        ]

        result = executor.execute_batch(tasks, item_ids=["a", "b", "c"])

        assert result.total == 3
        assert result.successful == 3
        assert result.failed == 0
        assert result.all_successful is True

    def test_execute_batch_with_failures(self) -> None:
        """Test batch execution collecting failures."""
        executor = BatchExecutor(stop_on_error=False)

        def fail() -> None:
            raise ValueError("failed")

        tasks: list[Callable[[], Any]] = [
            lambda: 1,
            fail,
            lambda: 3,
        ]

        result = executor.execute_batch(tasks, item_ids=["a", "b", "c"])

        assert result.total == 3
        assert result.successful == 2
        assert result.failed == 1
        assert result.failed_items[0].item_id == "b"
        assert "failed" in result.failed_items[0].error

    def test_execute_batch_stop_on_error(self) -> None:
        """Test batch execution stops on first error when configured."""
        executor = BatchExecutor(stop_on_error=True)

        def fail() -> None:
            raise ValueError("stop here")

        tasks: list[Callable[[], Any]] = [
            lambda: 1,
            fail,
            lambda: 3,
        ]

        with pytest.raises(ValueError, match="stop here"):
            executor.execute_batch(tasks, item_ids=["a", "b", "c"])
```

**Step 2: Run tests to verify they fail**

```bash
pytest tests/unit/domain/test_batch_executor.py -v
```

Expected: FAIL

**Step 3: Implement BatchExecutor**

```python
# src/descope_mgmt/domain/batch_executor.py
"""Generic batch executor for parallel operations."""

from collections.abc import Callable
from typing import Any, TypeVar

from descope_mgmt.types.batch import BatchItemResult, BatchResult

T = TypeVar("T")


class BatchExecutor:
    """Executes batch operations with result tracking and error collection.

    Provides a generic executor for running multiple operations with
    configurable error handling and result aggregation.
    """

    def __init__(self, stop_on_error: bool = True) -> None:
        """Initialize batch executor.

        Args:
            stop_on_error: If True, raise on first error.
                          If False, collect errors and continue.
        """
        self._stop_on_error = stop_on_error

    def execute(self, task: Callable[[], T]) -> T:
        """Execute a single task.

        Args:
            task: Callable that returns a result.

        Returns:
            Result of task execution.

        Raises:
            Exception: Any exception raised by the task.
        """
        return task()

    def execute_batch(
        self,
        tasks: list[Callable[[], Any]],
        item_ids: list[str],
    ) -> BatchResult:
        """Execute batch of tasks with result tracking.

        Args:
            tasks: List of callables to execute.
            item_ids: List of identifiers for each task (same order).

        Returns:
            BatchResult with all item results.

        Raises:
            Exception: First exception if stop_on_error=True.
        """
        if len(tasks) != len(item_ids):
            raise ValueError("tasks and item_ids must have same length")

        results: list[BatchItemResult] = []

        for task, item_id in zip(tasks, item_ids, strict=True):
            try:
                result = self.execute(task)
                results.append(
                    BatchItemResult(
                        item_id=item_id,
                        success=True,
                        result=result,
                    )
                )
            except Exception as e:
                if self._stop_on_error:
                    raise
                results.append(
                    BatchItemResult(
                        item_id=item_id,
                        success=False,
                        error=str(e),
                    )
                )

        return BatchResult(items=results, total=len(tasks))
```

**Step 4: Run tests to verify they pass**

```bash
pytest tests/unit/domain/test_batch_executor.py -v
```

Expected: PASS

**Step 5: Export from domain module**

Add to `src/descope_mgmt/domain/__init__.py`:
```python
from descope_mgmt.domain.batch_executor import BatchExecutor
```

**Step 6: Commit**

```bash
git add src/descope_mgmt/domain/batch_executor.py tests/unit/domain/test_batch_executor.py src/descope_mgmt/domain/__init__.py
git commit -m "feat(domain): add BatchExecutor with result tracking"
```

---

## Task 3: Run Quality Checks

**Agent:** python-pro

**Step 1: Run full test suite**

```bash
pytest tests/ -v --cov=src/descope_mgmt --cov-report=term-missing
```

Expected: All tests pass, coverage maintained

**Step 2: Run linting and type checks**

```bash
ruff check . && mypy src/ && lint-imports
```

Expected: No errors

---

## Chunk Complete Checklist

- [ ] BatchResult and BatchItemResult types created
- [ ] BatchExecutor domain class implemented
- [ ] All tests passing
- [ ] Code committed
- [ ] Ready for next chunk
