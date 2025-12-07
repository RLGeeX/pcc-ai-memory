# Chunk 2: Batch Executor Progress Integration

**Status:** pending
**Dependencies:** chunk-001-batch-executor-core
**Complexity:** medium
**Estimated Time:** 12 minutes
**Tasks:** 2
**Phase:** Batch Executor Refactoring
**Jira:** PCC-252

---

## Task 1: Add Progress Callback to BatchExecutor

**Agent:** python-pro
**Files:**
- Modify: `src/descope_mgmt/domain/batch_executor.py`
- Modify: `tests/unit/domain/test_batch_executor.py`

**Step 1: Add tests for progress callback**

Add to `tests/unit/domain/test_batch_executor.py`:

```python
    def test_execute_batch_with_progress(self) -> None:
        """Test batch execution with progress callback."""
        executor = BatchExecutor(stop_on_error=False)
        progress_calls: list[int] = []

        def on_progress(completed: int, total: int) -> None:
            progress_calls.append(completed)

        tasks: list[Callable[[], int]] = [
            lambda: 1,
            lambda: 2,
            lambda: 3,
        ]

        result = executor.execute_batch(
            tasks,
            item_ids=["a", "b", "c"],
            on_progress=on_progress,
        )

        assert result.total == 3
        assert progress_calls == [1, 2, 3]

    def test_execute_batch_progress_on_failure(self) -> None:
        """Test progress is called even on failures."""
        executor = BatchExecutor(stop_on_error=False)
        progress_calls: list[int] = []

        def on_progress(completed: int, total: int) -> None:
            progress_calls.append(completed)

        def fail() -> None:
            raise ValueError("failed")

        tasks: list[Callable[[], Any]] = [
            lambda: 1,
            fail,
            lambda: 3,
        ]

        result = executor.execute_batch(
            tasks,
            item_ids=["a", "b", "c"],
            on_progress=on_progress,
        )

        # Progress should be called for all items, including failures
        assert progress_calls == [1, 2, 3]
```

**Step 2: Run tests to verify they fail**

```bash
pytest tests/unit/domain/test_batch_executor.py::TestBatchExecutor::test_execute_batch_with_progress -v
```

Expected: FAIL (on_progress parameter not found)

**Step 3: Update BatchExecutor with progress callback**

Update `src/descope_mgmt/domain/batch_executor.py`:

```python
"""Generic batch executor for parallel operations."""

from collections.abc import Callable
from typing import Any, TypeVar

from descope_mgmt.types.batch import BatchItemResult, BatchResult

T = TypeVar("T")

ProgressCallback = Callable[[int, int], None]


class BatchExecutor:
    """Executes batch operations with result tracking and error collection.

    Provides a generic executor for running multiple operations with
    configurable error handling, result aggregation, and progress tracking.
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
        on_progress: ProgressCallback | None = None,
    ) -> BatchResult:
        """Execute batch of tasks with result tracking.

        Args:
            tasks: List of callables to execute.
            item_ids: List of identifiers for each task (same order).
            on_progress: Optional callback(completed, total) for progress.

        Returns:
            BatchResult with all item results.

        Raises:
            Exception: First exception if stop_on_error=True.
        """
        if len(tasks) != len(item_ids):
            raise ValueError("tasks and item_ids must have same length")

        results: list[BatchItemResult] = []
        total = len(tasks)

        for idx, (task, item_id) in enumerate(zip(tasks, item_ids, strict=True)):
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

            # Call progress callback after each item
            if on_progress:
                on_progress(idx + 1, total)

        return BatchResult(items=results, total=total)
```

**Step 4: Run tests to verify they pass**

```bash
pytest tests/unit/domain/test_batch_executor.py -v
```

Expected: PASS

**Step 5: Commit**

```bash
git add src/descope_mgmt/domain/batch_executor.py tests/unit/domain/test_batch_executor.py
git commit -m "feat(batch): add progress callback to BatchExecutor"
```

---

## Task 2: Add Rate Limiter Integration

**Agent:** python-pro
**Files:**
- Modify: `src/descope_mgmt/domain/batch_executor.py`
- Modify: `tests/unit/domain/test_batch_executor.py`

**Step 1: Add tests for rate limiter integration**

Add to `tests/unit/domain/test_batch_executor.py`:

```python
from unittest.mock import MagicMock, call

from descope_mgmt.types.protocols import RateLimiterProtocol


class TestBatchExecutorWithRateLimiter:
    """Tests for BatchExecutor with rate limiting."""

    def test_execute_with_rate_limiter(self) -> None:
        """Test single execution respects rate limiter."""
        mock_limiter = MagicMock(spec=RateLimiterProtocol)
        executor = BatchExecutor(rate_limiter=mock_limiter)

        result = executor.execute(lambda: "done")

        assert result == "done"
        mock_limiter.acquire.assert_called_once()

    def test_batch_execute_rate_limits_each_task(self) -> None:
        """Test batch execution rate limits each task."""
        mock_limiter = MagicMock(spec=RateLimiterProtocol)
        executor = BatchExecutor(rate_limiter=mock_limiter, stop_on_error=False)

        tasks: list[Callable[[], int]] = [
            lambda: 1,
            lambda: 2,
            lambda: 3,
        ]

        result = executor.execute_batch(tasks, item_ids=["a", "b", "c"])

        assert result.total == 3
        assert mock_limiter.acquire.call_count == 3
```

**Step 2: Run tests to verify they fail**

```bash
pytest tests/unit/domain/test_batch_executor.py::TestBatchExecutorWithRateLimiter -v
```

Expected: FAIL

**Step 3: Add rate limiter to BatchExecutor**

Update `src/descope_mgmt/domain/batch_executor.py` constructor and execute method:

```python
from descope_mgmt.types.protocols import RateLimiterProtocol

class BatchExecutor:
    """Executes batch operations with result tracking and error collection."""

    def __init__(
        self,
        stop_on_error: bool = True,
        rate_limiter: RateLimiterProtocol | None = None,
    ) -> None:
        """Initialize batch executor.

        Args:
            stop_on_error: If True, raise on first error.
                          If False, collect errors and continue.
            rate_limiter: Optional rate limiter for throttling.
        """
        self._stop_on_error = stop_on_error
        self._rate_limiter = rate_limiter

    def execute(self, task: Callable[[], T]) -> T:
        """Execute a single task.

        Args:
            task: Callable that returns a result.

        Returns:
            Result of task execution.

        Raises:
            Exception: Any exception raised by the task.
        """
        # Acquire rate limit before execution
        if self._rate_limiter:
            self._rate_limiter.acquire()

        return task()
```

**Step 4: Run tests to verify they pass**

```bash
pytest tests/unit/domain/test_batch_executor.py -v
```

Expected: PASS

**Step 5: Commit**

```bash
git add src/descope_mgmt/domain/batch_executor.py tests/unit/domain/test_batch_executor.py
git commit -m "feat(batch): integrate rate limiter into BatchExecutor"
```

---

## Chunk Complete Checklist

- [ ] Progress callback implemented
- [ ] Rate limiter integration added
- [ ] All tests passing
- [ ] Code committed
- [ ] Ready for next chunk
