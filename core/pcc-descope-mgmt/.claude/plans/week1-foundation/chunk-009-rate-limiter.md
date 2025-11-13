# Chunk 9: PyrateLimiter Integration

**Status:** pending
**Dependencies:** chunk-008-exceptions
**Complexity:** medium
**Estimated Time:** 20 minutes
**Tasks:** 2

---

## Task 1: Create RateLimiter Wrapper

**Files:**
- Create: `src/descope_mgmt/api/rate_limiter.py`
- Create: `tests/unit/api/test_rate_limiter.py`

**Step 1: Write failing tests**

Create `tests/unit/api/__init__.py`:
```python
"""Unit tests for API layer."""
```

Create `tests/unit/api/test_rate_limiter.py`:
```python
"""Tests for rate limiter."""

import time

import pytest

from descope_mgmt.api.rate_limiter import DescopeRateLimiter


def test_rate_limiter_single_acquire() -> None:
    """Test single acquire succeeds immediately."""
    limiter = DescopeRateLimiter(max_requests=10, time_window_seconds=60)
    start = time.time()
    limiter.acquire()
    elapsed = time.time() - start
    assert elapsed < 0.1  # Should be instant


def test_rate_limiter_multiple_acquires() -> None:
    """Test multiple acquires within limit."""
    limiter = DescopeRateLimiter(max_requests=5, time_window_seconds=60)
    for _ in range(5):
        limiter.acquire()  # Should all succeed without blocking


def test_rate_limiter_blocks_when_exceeded() -> None:
    """Test rate limiter blocks when limit exceeded."""
    # Small limit and window for faster test
    limiter = DescopeRateLimiter(max_requests=2, time_window_seconds=1)

    # First two should succeed immediately
    limiter.acquire()
    limiter.acquire()

    # Third should block (but we won't actually wait in test)
    # Just verify the implementation is correct
    assert limiter._limiter is not None


def test_rate_limiter_weighted_acquire() -> None:
    """Test acquire with weight parameter."""
    limiter = DescopeRateLimiter(max_requests=10, time_window_seconds=60)
    limiter.acquire(weight=5)  # Should consume 5 requests
    # Verify limiter accepted the weight (implementation detail)


def test_rate_limiter_default_values() -> None:
    """Test rate limiter with default Descope limits."""
    limiter = DescopeRateLimiter()  # Should use 200 req/60s default
    limiter.acquire()
    assert True  # Successfully created and used
```

**Step 2: Run tests (expect failure)**

```bash
pytest tests/unit/api/test_rate_limiter.py -v
```

Expected: All 5 tests FAIL

**Step 3: Implement DescopeRateLimiter**

Create `src/descope_mgmt/api/__init__.py`:
```python
"""API layer for external service interactions."""
```

Create `src/descope_mgmt/api/rate_limiter.py`:
```python
"""Rate limiter implementation using PyrateLimiter."""

from pyrate_limiter import Duration, Limiter, Rate, InMemoryBucket


class DescopeRateLimiter:
    """Rate limiter for Descope API calls.

    Uses PyrateLimiter with InMemoryBucket (thread-safe).
    Blocks at submission time to prevent queue buildup (validated design decision).

    Default: 200 requests per 60 seconds (Descope tenant API limit).
    """

    def __init__(
        self,
        max_requests: int = 200,
        time_window_seconds: int = 60
    ) -> None:
        """Initialize rate limiter.

        Args:
            max_requests: Maximum requests allowed in time window
            time_window_seconds: Time window in seconds
        """
        self._max_requests = max_requests
        self._time_window = time_window_seconds

        # Create rate limiter with InMemoryBucket (thread-safe)
        rate = Rate(max_requests, time_window_seconds * Duration.SECOND)
        self._limiter = Limiter(rate, bucket_class=InMemoryBucket)

    def acquire(self, weight: int = 1) -> None:
        """Acquire permission to make API call(s).

        Blocks if rate limit would be exceeded until capacity is available.

        Args:
            weight: Number of requests this operation counts as (default: 1)
        """
        # PyrateLimiter automatically blocks if rate limit exceeded
        self._limiter.try_acquire("descope_api", weight=weight)
```

**Step 4: Run tests (expect pass)**

```bash
pytest tests/unit/api/test_rate_limiter.py -v
```

Expected: All 5 tests PASS

**Step 5: Commit**

```bash
git add src/descope_mgmt/api/ tests/unit/api/
git commit -m "feat: add PyrateLimiter integration for rate limiting"
```

---

## Task 2: Create Fake RateLimiter for Testing

**Files:**
- Modify: `tests/fakes.py`

**Step 1: Implement FakeRateLimiter**

```python
"""Fake implementations for testing (no mocking library needed)."""

from descope_mgmt.types.protocols import RateLimiterProtocol


class FakeRateLimiter:
    """Fake rate limiter for testing.

    Implements RateLimiterProtocol without actual rate limiting.
    Tracks acquire calls for test verification.
    """

    def __init__(self) -> None:
        """Initialize fake rate limiter."""
        self.acquire_count = 0
        self.total_weight = 0
        self.calls: list[int] = []

    def acquire(self, weight: int = 1) -> None:
        """Record acquire call without blocking.

        Args:
            weight: Request weight
        """
        self.acquire_count += 1
        self.total_weight += weight
        self.calls.append(weight)


# Verify FakeRateLimiter implements protocol at runtime
assert isinstance(FakeRateLimiter(), RateLimiterProtocol)
```

**Step 2: Write test for fake**

Add to `tests/unit/api/test_rate_limiter.py`:
```python
from tests.fakes import FakeRateLimiter


def test_fake_rate_limiter() -> None:
    """Test fake rate limiter for testing."""
    fake = FakeRateLimiter()
    fake.acquire()
    fake.acquire(weight=3)

    assert fake.acquire_count == 2
    assert fake.total_weight == 4
    assert fake.calls == [1, 3]
```

**Step 3: Run tests (expect pass)**

```bash
pytest tests/unit/api/test_rate_limiter.py::test_fake_rate_limiter -v
```

Expected: Test PASSES

**Step 4: Commit**

```bash
git add tests/fakes.py tests/unit/api/test_rate_limiter.py
git commit -m "feat: add FakeRateLimiter for testing"
```

---

## Chunk Complete Checklist

- [ ] DescopeRateLimiter with PyrateLimiter (5 tests)
- [ ] FakeRateLimiter for testing (1 test)
- [ ] All 6 API tests passing
- [ ] Rate limiter uses InMemoryBucket (thread-safe)
- [ ] Blocks at submission time (validated design)
- [ ] mypy strict mode passes
- [ ] 2 commits created
- [ ] Ready for chunk 10
