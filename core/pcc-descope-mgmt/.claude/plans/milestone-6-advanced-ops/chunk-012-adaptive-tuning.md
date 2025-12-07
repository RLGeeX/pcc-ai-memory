# Chunk 12: Adaptive Rate Limit Tuning

**Status:** pending
**Dependencies:** chunk-011-rate-limit-benchmarks
**Complexity:** complex
**Estimated Time:** 15 minutes
**Tasks:** 3
**Phase:** Rate Limit Verification
**Jira:** PCC-256

---

## Task 1: Add Adaptive Rate Limiter

**Agent:** python-pro
**Files:**
- Create: `src/descope_mgmt/api/adaptive_rate_limiter.py`
- Create: `tests/unit/api/test_adaptive_rate_limiter.py`

**Step 1: Add tests for adaptive rate limiter**

Create `tests/unit/api/test_adaptive_rate_limiter.py`:

```python
"""Tests for adaptive rate limiter."""

import time
from unittest.mock import MagicMock, patch

import pytest

from descope_mgmt.api.adaptive_rate_limiter import AdaptiveRateLimiter


class TestAdaptiveRateLimiter:
    """Tests for AdaptiveRateLimiter."""

    def test_initial_rate(self) -> None:
        """Test initial rate is set correctly."""
        limiter = AdaptiveRateLimiter(
            initial_rate=10,
            min_rate=1,
            max_rate=100,
        )
        assert limiter.current_rate == 10

    def test_decrease_on_rate_limit_error(self) -> None:
        """Test rate decreases after rate limit error."""
        limiter = AdaptiveRateLimiter(
            initial_rate=10,
            min_rate=1,
            max_rate=100,
        )

        initial_rate = limiter.current_rate
        limiter.record_rate_limit_error()

        assert limiter.current_rate < initial_rate

    def test_increase_on_success(self) -> None:
        """Test rate increases after successful operations."""
        limiter = AdaptiveRateLimiter(
            initial_rate=10,
            min_rate=1,
            max_rate=100,
        )

        # Record many successes
        for _ in range(100):
            limiter.record_success()

        assert limiter.current_rate >= 10  # Should increase or stay same

    def test_respects_min_rate(self) -> None:
        """Test rate doesn't go below minimum."""
        limiter = AdaptiveRateLimiter(
            initial_rate=5,
            min_rate=3,
            max_rate=100,
        )

        # Many errors
        for _ in range(20):
            limiter.record_rate_limit_error()

        assert limiter.current_rate >= 3

    def test_respects_max_rate(self) -> None:
        """Test rate doesn't exceed maximum."""
        limiter = AdaptiveRateLimiter(
            initial_rate=50,
            min_rate=1,
            max_rate=60,
        )

        # Many successes
        for _ in range(1000):
            limiter.record_success()

        assert limiter.current_rate <= 60

    def test_acquire_respects_current_rate(self) -> None:
        """Test acquire uses current adaptive rate."""
        limiter = AdaptiveRateLimiter(
            initial_rate=20,
            min_rate=1,
            max_rate=100,
        )

        start = time.perf_counter()

        for _ in range(5):
            limiter.acquire()

        elapsed = time.perf_counter() - start

        # At 20/sec, 5 operations should take ~0.2 seconds
        assert elapsed < 1.0  # Should be fast at 20/sec
```

**Step 2: Run tests to verify they fail**

```bash
pytest tests/unit/api/test_adaptive_rate_limiter.py -v
```

Expected: FAIL (module not found)

**Step 3: Implement AdaptiveRateLimiter**

Create `src/descope_mgmt/api/adaptive_rate_limiter.py`:

```python
"""Adaptive rate limiter with dynamic rate adjustment."""

import threading
import time
from collections import deque

from descope_mgmt.types.protocols import RateLimiterProtocol


class AdaptiveRateLimiter(RateLimiterProtocol):
    """Rate limiter that adapts based on API responses.

    Decreases rate when rate limit errors occur and gradually
    increases when operations succeed consistently.
    """

    def __init__(
        self,
        initial_rate: float = 10.0,
        min_rate: float = 1.0,
        max_rate: float = 100.0,
        decrease_factor: float = 0.5,
        increase_factor: float = 1.1,
        success_threshold: int = 50,
    ) -> None:
        """Initialize adaptive rate limiter.

        Args:
            initial_rate: Starting requests per second.
            min_rate: Minimum allowed rate.
            max_rate: Maximum allowed rate.
            decrease_factor: Multiplier when rate limit hit (< 1).
            increase_factor: Multiplier after success threshold (> 1).
            success_threshold: Successes needed before rate increase.
        """
        self._current_rate = initial_rate
        self._min_rate = min_rate
        self._max_rate = max_rate
        self._decrease_factor = decrease_factor
        self._increase_factor = increase_factor
        self._success_threshold = success_threshold

        self._success_count = 0
        self._last_acquire_time = 0.0
        self._lock = threading.Lock()

    @property
    def current_rate(self) -> float:
        """Get current rate limit."""
        return self._current_rate

    def acquire(self) -> None:
        """Acquire permission to make a request.

        Blocks until rate limit allows the request.
        """
        with self._lock:
            now = time.time()
            min_interval = 1.0 / self._current_rate

            elapsed = now - self._last_acquire_time
            if elapsed < min_interval:
                time.sleep(min_interval - elapsed)

            self._last_acquire_time = time.time()

    def record_success(self) -> None:
        """Record a successful API operation.

        After enough successes, rate may be increased.
        """
        with self._lock:
            self._success_count += 1

            if self._success_count >= self._success_threshold:
                # Increase rate
                new_rate = self._current_rate * self._increase_factor
                self._current_rate = min(new_rate, self._max_rate)
                self._success_count = 0

    def record_rate_limit_error(self) -> None:
        """Record a rate limit error from the API.

        Immediately decreases the rate.
        """
        with self._lock:
            new_rate = self._current_rate * self._decrease_factor
            self._current_rate = max(new_rate, self._min_rate)
            self._success_count = 0  # Reset success counter

    def get_stats(self) -> dict[str, float]:
        """Get current rate limiter statistics."""
        return {
            "current_rate": self._current_rate,
            "min_rate": self._min_rate,
            "max_rate": self._max_rate,
            "success_count": self._success_count,
        }
```

**Step 4: Run tests to verify they pass**

```bash
pytest tests/unit/api/test_adaptive_rate_limiter.py -v
```

Expected: PASS

**Step 5: Commit**

```bash
git add src/descope_mgmt/api/adaptive_rate_limiter.py tests/unit/api/test_adaptive_rate_limiter.py
git commit -m "feat(api): add AdaptiveRateLimiter with dynamic rate adjustment"
```

---

## Task 2: Add Integration with BatchExecutor

**Agent:** python-pro
**Files:**
- Modify: `tests/performance/test_rate_limiting.py`

**Step 1: Add adaptive rate limiter benchmark**

Add to `tests/performance/test_rate_limiting.py`:

```python
from descope_mgmt.api.adaptive_rate_limiter import AdaptiveRateLimiter
from descope_mgmt.domain.batch_executor import BatchExecutor


class TestAdaptiveRateLimiterBenchmarks:
    """Benchmark tests for adaptive rate limiter."""

    @pytest.mark.benchmark
    def test_adaptive_with_batch_executor(self, benchmark_reporter: Any) -> None:
        """Benchmark adaptive rate limiter with batch executor."""
        limiter = AdaptiveRateLimiter(
            initial_rate=20,
            min_rate=5,
            max_rate=50,
        )
        executor = BatchExecutor(rate_limiter=limiter, stop_on_error=False)

        latencies: list[float] = []

        def task() -> int:
            start = time.perf_counter()
            result = 42  # Simulate work
            latencies.append(time.perf_counter() - start)
            limiter.record_success()  # Report success
            return result

        tasks = [task] * 30
        item_ids = [str(i) for i in range(30)]

        result = executor.execute_batch(tasks, item_ids)

        benchmark_result = BenchmarkResult.from_latencies(
            name="Adaptive RateLimiter + BatchExecutor",
            latencies=latencies,
        )

        benchmark_reporter(benchmark_result)

        assert result.successful == 30
        # Rate should have increased due to successes
        assert limiter.current_rate >= 20

    @pytest.mark.benchmark
    def test_adaptive_recovery_from_errors(self, benchmark_reporter: Any) -> None:
        """Benchmark adaptive rate limiter recovery after errors."""
        limiter = AdaptiveRateLimiter(
            initial_rate=20,
            min_rate=5,
            max_rate=50,
            success_threshold=10,  # Recover faster for test
        )

        # Simulate rate limit errors
        for _ in range(3):
            limiter.record_rate_limit_error()

        rate_after_errors = limiter.current_rate
        assert rate_after_errors < 20  # Should have decreased

        # Simulate recovery with successes
        for _ in range(50):
            limiter.acquire()
            limiter.record_success()

        rate_after_recovery = limiter.current_rate
        assert rate_after_recovery > rate_after_errors  # Should have recovered
```

**Step 2: Run adaptive benchmarks**

```bash
pytest tests/performance/test_rate_limiting.py -v -s -m benchmark
```

Expected: PASS with benchmark output

**Step 3: Commit**

```bash
git add tests/performance/test_rate_limiting.py
git commit -m "test(perf): add adaptive rate limiter benchmarks"
```

---

## Task 3: Final Quality Checks and Documentation

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

**Step 3: Verify test counts per deliverable**

```bash
# PCC-252: BatchExecutor (8+ tests)
pytest tests/unit/domain/test_batch_executor.py -v --collect-only | grep "test_" | wc -l

# PCC-253: Tenant delete (5+ tests)
pytest tests/unit/cli/test_tenant_cmds.py -v --collect-only | grep "delete" | wc -l

# PCC-254: Flow delete (4+ tests)
pytest tests/unit/cli/test_flow_cmds.py -v --collect-only | grep "delete" | wc -l

# PCC-255: Audit enhancements (5+ tests)
pytest tests/unit/domain/test_audit_logger.py tests/unit/cli/test_audit_cmds.py -v --collect-only | wc -l

# PCC-256: Rate limit (3+ tests)
pytest tests/performance/test_rate_limiting.py tests/unit/api/test_adaptive_rate_limiter.py -v --collect-only | wc -l
```

Expected: Meet or exceed test requirements for each deliverable

**Step 4: Run pre-commit hooks**

```bash
pre-commit run --all-files
```

Expected: All hooks pass

---

## Chunk Complete Checklist

- [ ] AdaptiveRateLimiter implemented
- [ ] Integration with BatchExecutor verified
- [ ] Performance benchmarks passing
- [ ] 3+ tests for rate limiting
- [ ] All quality checks passing
- [ ] All deliverables have required tests
- [ ] Code committed
- [ ] Phase 4 complete - Milestone 6 done!
