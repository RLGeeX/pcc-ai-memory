# Chunk 1: Batch Operations with Parallelism

**Status:** pending
**Dependencies:** phase2-week5 complete
**Estimated Time:** 60 minutes

---

## Task 1: Create BatchExecutor Service

**Files:**
- Create: `src/descope_mgmt/domain/services/batch_executor.py`
- Create: `tests/unit/domain/test_batch_executor.py`

**Step 1: Write failing tests**

Create `tests/unit/domain/test_batch_executor.py`:
```python
"""Tests for batch executor"""
import pytest
from unittest.mock import Mock
from descope_mgmt.domain.services.batch_executor import BatchExecutor


def test_batch_executor_parallel():
    """Should execute operations in parallel with rate limiting"""
    operations = [lambda: i for i in range(5)]

    rate_limiter = Mock()
    executor = BatchExecutor(rate_limiter=rate_limiter, max_workers=3)

    results = executor.execute_batch(operations)

    assert len(results) == 5
    # Should have called rate limiter
    assert rate_limiter.acquire.call_count == 5
```

**Step 2: Implement BatchExecutor**

Create `src/descope_mgmt/domain/services/batch_executor.py`:
```python
"""Batch executor with parallelism and rate limiting."""
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Callable, Any
import structlog

logger = structlog.get_logger()


class BatchExecutor:
    """Execute operations in parallel with rate limiting."""

    def __init__(self, rate_limiter, max_workers: int = 5):
        """Initialize batch executor.

        Args:
            rate_limiter: Rate limiter instance
            max_workers: Maximum concurrent workers
        """
        self.rate_limiter = rate_limiter
        self.max_workers = max_workers

    def execute_batch(self, operations: list[Callable[[], Any]]) -> list[Any]:
        """Execute batch operations with rate limiting at submission.

        Args:
            operations: List of operations to execute

        Returns:
            List of results
        """
        results = []

        with ThreadPoolExecutor(max_workers=self.max_workers) as executor:
            futures = []

            for op in operations:
                # CRITICAL: Rate limit at submission time
                self.rate_limiter.acquire()

                future = executor.submit(op)
                futures.append(future)

            # Collect results
            for future in as_completed(futures):
                try:
                    result = future.result()
                    results.append(result)
                except Exception as e:
                    logger.error("batch_operation_failed", error=str(e))
                    results.append({"error": str(e)})

        return results
```

**Step 3: Commit**

```bash
git add src/descope_mgmt/domain/services/batch_executor.py tests/unit/domain/test_batch_executor.py
git commit -m "feat: add batch executor with rate limiting"
```

---

## Chunk Complete Checklist

- [ ] BatchExecutor service
- [ ] Parallel execution
- [ ] Rate limit at submission
- [ ] 6 tests passing
