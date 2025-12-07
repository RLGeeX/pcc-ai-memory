# Chunk 3: Adaptive Worker Pools

**Status:** pending
**Dependencies:** chunk-002-batch-progress
**Complexity:** complex
**Estimated Time:** 15 minutes
**Tasks:** 3
**Phase:** Batch Executor Refactoring
**Jira:** PCC-252

---

## Task 1: Add Concurrent Execution Support

**Agent:** python-pro
**Files:**
- Modify: `src/descope_mgmt/domain/batch_executor.py`
- Modify: `tests/unit/domain/test_batch_executor.py`

**Step 1: Add tests for concurrent execution**

Add to `tests/unit/domain/test_batch_executor.py`:

```python
import time
from concurrent.futures import ThreadPoolExecutor


class TestBatchExecutorConcurrent:
    """Tests for concurrent batch execution."""

    def test_concurrent_execution(self) -> None:
        """Test batch executes tasks concurrently."""
        executor = BatchExecutor(stop_on_error=False, max_workers=3)
        execution_times: list[float] = []

        def slow_task(delay: float = 0.1) -> float:
            start = time.time()
            time.sleep(delay)
            execution_times.append(time.time() - start)
            return delay

        tasks = [
            lambda: slow_task(0.1),
            lambda: slow_task(0.1),
            lambda: slow_task(0.1),
        ]

        start = time.time()
        result = executor.execute_batch(tasks, item_ids=["a", "b", "c"])
        total_time = time.time() - start

        assert result.total == 3
        assert result.successful == 3
        # With 3 workers, should complete in ~0.1s not ~0.3s
        assert total_time < 0.25  # Allow some overhead

    def test_max_workers_respected(self) -> None:
        """Test max_workers limits concurrent tasks."""
        executor = BatchExecutor(stop_on_error=False, max_workers=2)
        concurrent_count = [0]
        max_concurrent = [0]

        def tracking_task() -> int:
            concurrent_count[0] += 1
            max_concurrent[0] = max(max_concurrent[0], concurrent_count[0])
            time.sleep(0.05)
            concurrent_count[0] -= 1
            return 1

        tasks = [tracking_task] * 4

        result = executor.execute_batch(
            tasks,
            item_ids=["a", "b", "c", "d"],
        )

        assert result.total == 4
        assert max_concurrent[0] <= 2  # Should never exceed max_workers
```

**Step 2: Run tests to verify they fail**

```bash
pytest tests/unit/domain/test_batch_executor.py::TestBatchExecutorConcurrent -v
```

Expected: FAIL (max_workers parameter not found)

**Step 3: Add concurrent execution to BatchExecutor**

Update `src/descope_mgmt/domain/batch_executor.py`:

```python
"""Generic batch executor for parallel operations."""

from collections.abc import Callable
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Any, TypeVar

from descope_mgmt.types.batch import BatchItemResult, BatchResult
from descope_mgmt.types.protocols import RateLimiterProtocol

T = TypeVar("T")

ProgressCallback = Callable[[int, int], None]


class BatchExecutor:
    """Executes batch operations with result tracking and error collection.

    Provides a generic executor for running multiple operations with
    configurable error handling, result aggregation, progress tracking,
    and optional concurrent execution.
    """

    def __init__(
        self,
        stop_on_error: bool = True,
        rate_limiter: RateLimiterProtocol | None = None,
        max_workers: int | None = None,
    ) -> None:
        """Initialize batch executor.

        Args:
            stop_on_error: If True, raise on first error.
                          If False, collect errors and continue.
            rate_limiter: Optional rate limiter for throttling.
            max_workers: Max concurrent workers (None = sequential).
        """
        self._stop_on_error = stop_on_error
        self._rate_limiter = rate_limiter
        self._max_workers = max_workers

    def execute(self, task: Callable[[], T]) -> T:
        """Execute a single task.

        Args:
            task: Callable that returns a result.

        Returns:
            Result of task execution.

        Raises:
            Exception: Any exception raised by the task.
        """
        if self._rate_limiter:
            self._rate_limiter.acquire()
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

        total = len(tasks)

        if self._max_workers and self._max_workers > 1:
            return self._execute_concurrent(tasks, item_ids, on_progress)
        return self._execute_sequential(tasks, item_ids, on_progress)

    def _execute_sequential(
        self,
        tasks: list[Callable[[], Any]],
        item_ids: list[str],
        on_progress: ProgressCallback | None = None,
    ) -> BatchResult:
        """Execute tasks sequentially."""
        results: list[BatchItemResult] = []
        total = len(tasks)

        for idx, (task, item_id) in enumerate(zip(tasks, item_ids, strict=True)):
            try:
                result = self.execute(task)
                results.append(
                    BatchItemResult(item_id=item_id, success=True, result=result)
                )
            except Exception as e:
                if self._stop_on_error:
                    raise
                results.append(
                    BatchItemResult(item_id=item_id, success=False, error=str(e))
                )

            if on_progress:
                on_progress(idx + 1, total)

        return BatchResult(items=results, total=total)

    def _execute_concurrent(
        self,
        tasks: list[Callable[[], Any]],
        item_ids: list[str],
        on_progress: ProgressCallback | None = None,
    ) -> BatchResult:
        """Execute tasks concurrently with thread pool."""
        results: dict[str, BatchItemResult] = {}
        total = len(tasks)
        completed = 0

        def wrapped_task(task: Callable[[], Any], item_id: str) -> tuple[str, Any]:
            if self._rate_limiter:
                self._rate_limiter.acquire()
            return item_id, task()

        with ThreadPoolExecutor(max_workers=self._max_workers) as executor:
            futures = {
                executor.submit(wrapped_task, task, item_id): item_id
                for task, item_id in zip(tasks, item_ids, strict=True)
            }

            for future in as_completed(futures):
                item_id = futures[future]
                try:
                    _, result = future.result()
                    results[item_id] = BatchItemResult(
                        item_id=item_id, success=True, result=result
                    )
                except Exception as e:
                    if self._stop_on_error:
                        executor.shutdown(wait=False, cancel_futures=True)
                        raise
                    results[item_id] = BatchItemResult(
                        item_id=item_id, success=False, error=str(e)
                    )

                completed += 1
                if on_progress:
                    on_progress(completed, total)

        # Return results in original order
        ordered_results = [results[item_id] for item_id in item_ids]
        return BatchResult(items=ordered_results, total=total)
```

**Step 4: Run tests to verify they pass**

```bash
pytest tests/unit/domain/test_batch_executor.py -v
```

Expected: PASS

**Step 5: Commit**

```bash
git add src/descope_mgmt/domain/batch_executor.py tests/unit/domain/test_batch_executor.py
git commit -m "feat(batch): add concurrent execution with configurable workers"
```

---

## Task 2: Add Adaptive Worker Scaling

**Agent:** python-pro
**Files:**
- Modify: `src/descope_mgmt/domain/batch_executor.py`
- Modify: `tests/unit/domain/test_batch_executor.py`

**Step 1: Add tests for adaptive scaling**

```python
class TestBatchExecutorAdaptive:
    """Tests for adaptive worker scaling."""

    def test_calculate_optimal_workers_small_batch(self) -> None:
        """Test optimal workers for small batches."""
        executor = BatchExecutor(max_workers="auto")
        # Small batches should use fewer workers
        workers = executor._calculate_optimal_workers(5)
        assert workers <= 5

    def test_calculate_optimal_workers_large_batch(self) -> None:
        """Test optimal workers scales with batch size."""
        executor = BatchExecutor(max_workers="auto")
        small = executor._calculate_optimal_workers(10)
        large = executor._calculate_optimal_workers(100)
        assert large >= small

    def test_adaptive_execution(self) -> None:
        """Test batch execution with adaptive workers."""
        executor = BatchExecutor(stop_on_error=False, max_workers="auto")
        tasks = [lambda: i for i in range(10)]

        result = executor.execute_batch(
            tasks,
            item_ids=[str(i) for i in range(10)],
        )

        assert result.total == 10
        assert result.successful == 10
```

**Step 2: Run tests to verify they fail**

```bash
pytest tests/unit/domain/test_batch_executor.py::TestBatchExecutorAdaptive -v
```

Expected: FAIL

**Step 3: Add adaptive scaling logic**

Update `src/descope_mgmt/domain/batch_executor.py`:

```python
import os

class BatchExecutor:
    """Executes batch operations with result tracking and error collection."""

    def __init__(
        self,
        stop_on_error: bool = True,
        rate_limiter: RateLimiterProtocol | None = None,
        max_workers: int | str | None = None,
    ) -> None:
        """Initialize batch executor.

        Args:
            stop_on_error: If True, raise on first error.
            rate_limiter: Optional rate limiter for throttling.
            max_workers: Max concurrent workers. Options:
                - None: Sequential execution
                - int: Fixed worker count
                - "auto": Adaptive based on batch size and CPU count
        """
        self._stop_on_error = stop_on_error
        self._rate_limiter = rate_limiter
        self._max_workers_config = max_workers

    def _calculate_optimal_workers(self, batch_size: int) -> int:
        """Calculate optimal worker count for batch size.

        Uses a heuristic based on:
        - CPU count (for parallelism)
        - Batch size (no point having more workers than tasks)
        - A reasonable upper bound for I/O operations

        Args:
            batch_size: Number of tasks in batch.

        Returns:
            Optimal number of workers.
        """
        cpu_count = os.cpu_count() or 4
        # For I/O bound tasks, use 2-4x CPU count
        io_optimal = cpu_count * 2
        # But never more than batch size or 32 workers
        return min(batch_size, io_optimal, 32)

    def _get_worker_count(self, batch_size: int) -> int | None:
        """Get worker count for execution.

        Returns:
            Worker count or None for sequential.
        """
        if self._max_workers_config is None:
            return None
        if self._max_workers_config == "auto":
            return self._calculate_optimal_workers(batch_size)
        return self._max_workers_config

    def execute_batch(
        self,
        tasks: list[Callable[[], Any]],
        item_ids: list[str],
        on_progress: ProgressCallback | None = None,
    ) -> BatchResult:
        """Execute batch of tasks with result tracking."""
        if len(tasks) != len(item_ids):
            raise ValueError("tasks and item_ids must have same length")

        workers = self._get_worker_count(len(tasks))

        if workers and workers > 1:
            return self._execute_concurrent(tasks, item_ids, on_progress, workers)
        return self._execute_sequential(tasks, item_ids, on_progress)

    def _execute_concurrent(
        self,
        tasks: list[Callable[[], Any]],
        item_ids: list[str],
        on_progress: ProgressCallback | None,
        workers: int,
    ) -> BatchResult:
        """Execute tasks concurrently with thread pool."""
        # Update to use workers parameter instead of self._max_workers
        # ... (update the with ThreadPoolExecutor line)
        with ThreadPoolExecutor(max_workers=workers) as executor:
            # ... rest of implementation
```

**Step 4: Run tests to verify they pass**

```bash
pytest tests/unit/domain/test_batch_executor.py -v
```

Expected: PASS

**Step 5: Commit**

```bash
git add src/descope_mgmt/domain/batch_executor.py tests/unit/domain/test_batch_executor.py
git commit -m "feat(batch): add adaptive worker scaling based on batch size"
```

---

## Task 3: Quality Checks and Review

**Agent:** python-pro

**Step 1: Run full test suite**

```bash
pytest tests/ -v --cov=src/descope_mgmt --cov-report=term-missing
```

Expected: All tests pass, coverage >= 92%

**Step 2: Run quality checks**

```bash
ruff check . && mypy src/ && lint-imports
```

Expected: No errors

**Step 3: Verify 8+ tests for BatchExecutor**

```bash
pytest tests/unit/domain/test_batch_executor.py -v --collect-only | grep "test_"
```

Expected: At least 8 tests

---

## Chunk Complete Checklist

- [ ] Concurrent execution implemented
- [ ] Adaptive worker scaling added
- [ ] 8+ tests for BatchExecutor
- [ ] All quality checks passing
- [ ] Code committed
- [ ] Ready for Phase 2 (Delete Commands)
