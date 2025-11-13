# Chunk 10: Rate-Limited Executor (Submission-Time Limiting)

**Status:** pending
**Dependencies:** chunk-009-rate-limiter
**Complexity:** complex
**Estimated Time:** 30 minutes
**Tasks:** 2

---

## Task 1: Create RateLimitedExecutor

**Files:**
- Create: `src/descope_mgmt/api/executor.py`
- Create: `tests/unit/api/test_executor.py`

**Step 1: Write failing tests**

Create `tests/unit/api/test_executor.py`:
```python
"""Tests for rate-limited executor."""

from typing import Callable

import pytest

from descope_mgmt.api.executor import RateLimitedExecutor
from tests.fakes import FakeRateLimiter


def test_executor_single_task() -> None:
    """Test executing single task."""
    fake_limiter = FakeRateLimiter()
    executor = RateLimitedExecutor(rate_limiter=fake_limiter)

    def task() -> str:
        return "result"

    result = executor.execute(task)
    assert result == "result"
    assert fake_limiter.acquire_count == 1


def test_executor_multiple_tasks() -> None:
    """Test executing multiple tasks."""
    fake_limiter = FakeRateLimiter()
    executor = RateLimitedExecutor(rate_limiter=fake_limiter)

    def task(value: int) -> int:
        return value * 2

    results = executor.execute_batch([
        lambda: task(1),
        lambda: task(2),
        lambda: task(3),
    ])

    assert results == [2, 4, 6]
    assert fake_limiter.acquire_count == 3


def test_executor_task_failure() -> None:
    """Test executor handles task failure."""
    fake_limiter = FakeRateLimiter()
    executor = RateLimitedExecutor(rate_limiter=fake_limiter)

    def failing_task() -> None:
        raise ValueError("Task failed")

    with pytest.raises(ValueError, match="Task failed"):
        executor.execute(failing_task)

    # Rate limiter should still have been called before task execution
    assert fake_limiter.acquire_count == 1


def test_executor_batch_partial_failure() -> None:
    """Test batch execution with partial failures."""
    fake_limiter = FakeRateLimiter()
    executor = RateLimitedExecutor(rate_limiter=fake_limiter, stop_on_error=False)

    def good_task() -> str:
        return "success"

    def bad_task() -> None:
        raise ValueError("Failed")

    results = executor.execute_batch([
        good_task,
        bad_task,
        good_task,
    ])

    # Results should contain successes and error markers
    assert len(results) == 3
    assert results[0] == "success"
    assert isinstance(results[1], Exception)
    assert results[2] == "success"


def test_executor_stop_on_error() -> None:
    """Test batch execution stops on first error."""
    fake_limiter = FakeRateLimiter()
    executor = RateLimitedExecutor(rate_limiter=fake_limiter, stop_on_error=True)

    def bad_task() -> None:
        raise ValueError("Failed")

    with pytest.raises(ValueError):
        executor.execute_batch([bad_task, bad_task])

    # Only first task should have acquired rate limit
    assert fake_limiter.acquire_count == 1


def test_executor_acquires_before_execution() -> None:
    """Test rate limiter is acquired BEFORE task execution (critical design)."""
    fake_limiter = FakeRateLimiter()
    executor = RateLimitedExecutor(rate_limiter=fake_limiter)

    execution_order: list[str] = []

    def task() -> None:
        # Task records that it ran
        execution_order.append("task_executed")

    # Patch acquire to record when it's called
    original_acquire = fake_limiter.acquire
    def tracked_acquire(weight: int = 1) -> None:
        execution_order.append("rate_limit_acquired")
        original_acquire(weight)

    fake_limiter.acquire = tracked_acquire  # type: ignore

    executor.execute(task)

    # CRITICAL: Rate limit must be acquired BEFORE task execution
    assert execution_order == ["rate_limit_acquired", "task_executed"]
```

**Step 2: Run tests (expect failure)**

```bash
pytest tests/unit/api/test_executor.py -v
```

Expected: All 6 tests FAIL

**Step 3: Implement RateLimitedExecutor**

Create `src/descope_mgmt/api/executor.py`:
```python
"""Rate-limited executor for batch operations.

CRITICAL DESIGN: Rate limiting at submission time (not in workers).
This prevents queue buildup when rate limits are hit.
"""

from typing import Any, Callable, TypeVar

from descope_mgmt.types.protocols import RateLimiterProtocol

T = TypeVar("T")


class RateLimitedExecutor:
    """Executor that rate-limits task submission.

    Key design: Acquires rate limit permission BEFORE executing task.
    This prevents queue buildup when API rate limits are hit.
    """

    def __init__(
        self,
        rate_limiter: RateLimiterProtocol,
        stop_on_error: bool = True
    ) -> None:
        """Initialize executor.

        Args:
            rate_limiter: Rate limiter protocol implementation
            stop_on_error: Whether to stop batch execution on first error
        """
        self._rate_limiter = rate_limiter
        self._stop_on_error = stop_on_error

    def execute(self, task: Callable[[], T]) -> T:
        """Execute a single task with rate limiting.

        Args:
            task: Callable to execute

        Returns:
            Task result

        Raises:
            Any exception raised by the task
        """
        # CRITICAL: Acquire rate limit BEFORE executing task
        self._rate_limiter.acquire()

        # Execute task after rate limit permission granted
        return task()

    def execute_batch(
        self,
        tasks: list[Callable[[], Any]]
    ) -> list[Any]:
        """Execute multiple tasks with rate limiting.

        Args:
            tasks: List of callables to execute

        Returns:
            List of results (or exceptions if stop_on_error=False)

        Raises:
            Exception from first failed task if stop_on_error=True
        """
        results: list[Any] = []

        for task in tasks:
            try:
                # Each task acquires rate limit before execution
                result = self.execute(task)
                results.append(result)
            except Exception as e:
                if self._stop_on_error:
                    raise
                else:
                    # Record error and continue
                    results.append(e)

        return results
```

**Step 4: Run tests (expect pass)**

```bash
pytest tests/unit/api/test_executor.py -v
```

Expected: All 6 tests PASS

**Step 5: Commit**

```bash
git add src/descope_mgmt/api/executor.py tests/unit/api/test_executor.py
git commit -m "feat: add rate-limited executor with submission-time limiting"
```

---

## Task 2: Integration Test for Rate Limiting Behavior

**Files:**
- Create: `tests/integration/test_rate_limiting.py`

**Step 1: Write integration test**

Create `tests/integration/test_rate_limiting.py`:
```python
"""Integration tests for rate limiting behavior."""

import time

from descope_mgmt.api.executor import RateLimitedExecutor
from descope_mgmt.api.rate_limiter import DescopeRateLimiter


def test_rate_limiting_blocks_correctly() -> None:
    """Test rate limiter blocks when limit is exceeded."""
    # Use small limits for fast test
    limiter = DescopeRateLimiter(max_requests=2, time_window_seconds=1)
    executor = RateLimitedExecutor(rate_limiter=limiter)

    call_times: list[float] = []

    def task() -> None:
        call_times.append(time.time())

    # Execute 3 tasks (limit is 2 per second)
    start_time = time.time()
    executor.execute_batch([task, task, task])
    total_time = time.time() - start_time

    # First two should execute quickly, third should wait ~1 second
    assert total_time >= 1.0
    assert len(call_times) == 3

    # First two should be close together
    assert (call_times[1] - call_times[0]) < 0.1

    # Third should be delayed by window duration
    assert (call_times[2] - call_times[0]) >= 0.9
```

**Step 2: Run test (expect pass)**

```bash
pytest tests/integration/test_rate_limiting.py -v
```

Expected: Test PASSES (may take ~1-2 seconds due to rate limiting)

**Step 3: Commit**

```bash
git add tests/integration/test_rate_limiting.py
git commit -m "test: add integration test for rate limiting behavior"
```

---

## Chunk Complete Checklist

- [ ] RateLimitedExecutor with submission-time limiting (6 unit tests)
- [ ] Integration test for rate limiting behavior (1 test)
- [ ] All 7 tests passing (6 unit + 1 integration)
- [ ] Critical design validated: rate limiting BEFORE task execution
- [ ] Batch execution supports stop-on-error and continue-on-error
- [ ] mypy strict mode passes
- [ ] 2 commits created
- [ ] Ready for chunk 11
