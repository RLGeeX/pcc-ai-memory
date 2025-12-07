# Chunk 11: Rate Limit Performance Benchmarks

**Status:** pending
**Dependencies:** none
**Complexity:** medium
**Estimated Time:** 12 minutes
**Tasks:** 2
**Phase:** Rate Limit Verification
**Jira:** PCC-256

---

## Task 1: Create Performance Test Infrastructure

**Agent:** python-pro
**Files:**
- Create: `tests/performance/__init__.py`
- Create: `tests/performance/test_rate_limiting.py`
- Create: `tests/performance/conftest.py`

**Step 1: Create performance test directory structure**

```bash
mkdir -p tests/performance
touch tests/performance/__init__.py
```

**Step 2: Create conftest for performance tests**

Create `tests/performance/conftest.py`:

```python
"""Fixtures for performance tests."""

import time
from dataclasses import dataclass, field
from typing import Any

import pytest


@dataclass
class BenchmarkResult:
    """Result of a benchmark run."""

    name: str
    total_operations: int
    total_time_seconds: float
    operations_per_second: float
    avg_latency_ms: float
    min_latency_ms: float
    max_latency_ms: float
    latencies: list[float] = field(default_factory=list)

    @classmethod
    def from_latencies(
        cls,
        name: str,
        latencies: list[float],
    ) -> "BenchmarkResult":
        """Create result from list of latencies in seconds."""
        total_time = sum(latencies)
        ops_per_sec = len(latencies) / total_time if total_time > 0 else 0
        latencies_ms = [l * 1000 for l in latencies]

        return cls(
            name=name,
            total_operations=len(latencies),
            total_time_seconds=total_time,
            operations_per_second=ops_per_sec,
            avg_latency_ms=sum(latencies_ms) / len(latencies_ms) if latencies_ms else 0,
            min_latency_ms=min(latencies_ms) if latencies_ms else 0,
            max_latency_ms=max(latencies_ms) if latencies_ms else 0,
            latencies=latencies_ms,
        )


@pytest.fixture
def benchmark_reporter(capsys: Any) -> Any:
    """Fixture for reporting benchmark results."""

    def report(result: BenchmarkResult) -> None:
        print(f"\n{'=' * 60}")
        print(f"Benchmark: {result.name}")
        print(f"{'=' * 60}")
        print(f"Operations:     {result.total_operations}")
        print(f"Total Time:     {result.total_time_seconds:.3f}s")
        print(f"Ops/Second:     {result.operations_per_second:.1f}")
        print(f"Avg Latency:    {result.avg_latency_ms:.2f}ms")
        print(f"Min Latency:    {result.min_latency_ms:.2f}ms")
        print(f"Max Latency:    {result.max_latency_ms:.2f}ms")
        print(f"{'=' * 60}\n")

    return report
```

**Step 3: Create rate limiting benchmark tests**

Create `tests/performance/test_rate_limiting.py`:

```python
"""Performance benchmarks for rate limiting."""

import time

import pytest

from descope_mgmt.api.rate_limiter import RateLimiter
from tests.performance.conftest import BenchmarkResult


class TestRateLimiterBenchmarks:
    """Benchmark tests for rate limiter."""

    @pytest.mark.benchmark
    def test_rate_limiter_throughput(self, benchmark_reporter: Any) -> None:
        """Benchmark rate limiter throughput at various rates."""
        # Test at 10 ops/second
        rate_limiter = RateLimiter(requests_per_second=10)

        latencies: list[float] = []
        operations = 20  # 2 seconds worth at 10/sec

        for _ in range(operations):
            start = time.perf_counter()
            rate_limiter.acquire()
            latencies.append(time.perf_counter() - start)

        result = BenchmarkResult.from_latencies(
            name="RateLimiter @ 10 ops/sec",
            latencies=latencies,
        )

        benchmark_reporter(result)

        # Verify rate limiting is working
        assert result.operations_per_second <= 12  # Allow some tolerance
        assert result.total_time_seconds >= 1.8  # Should take ~2 seconds

    @pytest.mark.benchmark
    def test_rate_limiter_burst(self, benchmark_reporter: Any) -> None:
        """Benchmark rate limiter burst handling."""
        rate_limiter = RateLimiter(requests_per_second=50)

        latencies: list[float] = []
        operations = 10  # Quick burst

        for _ in range(operations):
            start = time.perf_counter()
            rate_limiter.acquire()
            latencies.append(time.perf_counter() - start)

        result = BenchmarkResult.from_latencies(
            name="RateLimiter Burst @ 50 ops/sec",
            latencies=latencies,
        )

        benchmark_reporter(result)

        # First operations should be fast (burst allowance)
        assert result.min_latency_ms < 10  # Sub-10ms for burst


class TestRateLimitCompliance:
    """Tests for rate limit compliance."""

    @pytest.mark.benchmark
    def test_respects_rate_limit(self) -> None:
        """Verify rate limiter respects configured limit."""
        rate_per_second = 5
        rate_limiter = RateLimiter(requests_per_second=rate_per_second)

        start = time.perf_counter()
        operations = 10

        for _ in range(operations):
            rate_limiter.acquire()

        elapsed = time.perf_counter() - start

        # Should take at least (operations - 1) / rate seconds
        # (first operation is instant, subsequent are rate-limited)
        expected_min = (operations - 1) / rate_per_second
        assert elapsed >= expected_min * 0.9  # 10% tolerance

    @pytest.mark.benchmark
    def test_no_rate_limit_exceeded_errors(self) -> None:
        """Verify no rate limit errors during sustained load."""
        rate_limiter = RateLimiter(requests_per_second=20)
        errors: list[Exception] = []

        for _ in range(50):
            try:
                rate_limiter.acquire()
            except Exception as e:
                errors.append(e)

        assert len(errors) == 0, f"Rate limit errors: {errors}"
```

**Step 4: Run benchmark tests**

```bash
pytest tests/performance/test_rate_limiting.py -v -s --benchmark
```

Expected: Tests pass with benchmark output

**Step 5: Commit**

```bash
git add tests/performance/
git commit -m "feat(tests): add rate limiting performance benchmarks"
```

---

## Task 2: Add Benchmark Markers to pytest.ini

**Agent:** python-pro
**Files:**
- Modify: `pyproject.toml` or `pytest.ini`

**Step 1: Add benchmark marker**

Add to `pyproject.toml` under `[tool.pytest.ini_options]`:

```toml
[tool.pytest.ini_options]
markers = [
    "benchmark: marks tests as performance benchmarks (deselect with '-m \"not benchmark\"')",
    "integration: marks tests as integration tests requiring real API",
]
```

Or create/update `pytest.ini`:

```ini
[pytest]
markers =
    benchmark: marks tests as performance benchmarks
    integration: marks tests as integration tests requiring real API
```

**Step 2: Verify markers are registered**

```bash
pytest --markers | grep benchmark
```

Expected: Shows benchmark marker description

**Step 3: Run only benchmark tests**

```bash
pytest -m benchmark -v -s
```

Expected: Only runs benchmark-marked tests

**Step 4: Commit**

```bash
git add pyproject.toml
git commit -m "chore(tests): add benchmark marker to pytest configuration"
```

---

## Chunk Complete Checklist

- [ ] Performance test infrastructure created
- [ ] BenchmarkResult type for reporting
- [ ] Rate limiter throughput benchmarks
- [ ] Rate limit compliance tests
- [ ] Benchmark marker configured
- [ ] All tests passing
- [ ] Code committed
- [ ] Ready for next chunk
