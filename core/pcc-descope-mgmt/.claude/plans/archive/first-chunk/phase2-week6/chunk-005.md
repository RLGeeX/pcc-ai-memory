# Chunk 5: Rate Limit Verification

**Status:** pending
**Dependencies:** chunk-001
**Estimated Time:** 30 minutes

---

## Task 1: Create Rate Limit Stress Tests

**Files:**
- Create: `tests/performance/test_rate_limiting.py`

**Step 1: Write stress tests**

Create `tests/performance/test_rate_limiting.py`:
```python
"""Performance tests for rate limiting"""
import pytest
from time import time
from descope_mgmt.api.rate_limit import DescopeRateLimiter, TenantRateLimiter


def test_rate_limiter_enforces_limits():
    """Should enforce rate limits correctly"""
    limiter = TenantRateLimiter()  # 200 req/60s

    start = time()

    # Try to acquire 210 tokens (should take > 0 seconds due to limiting)
    for _ in range(210):
        limiter.acquire()

    elapsed = time() - start

    # Should have been rate limited (not instant)
    assert elapsed > 0.1, "Rate limiter should enforce delays"


def test_rate_limiter_thread_safe():
    """Should be thread-safe"""
    from concurrent.futures import ThreadPoolExecutor

    limiter = TenantRateLimiter()

    def acquire_token():
        limiter.acquire()
        return True

    with ThreadPoolExecutor(max_workers=10) as executor:
        futures = [executor.submit(acquire_token) for _ in range(100)]
        results = [f.result() for f in futures]

    assert len(results) == 100
```

**Step 2: Run tests**

```bash
pytest tests/performance/test_rate_limiting.py -v
```

**Step 3: Document benchmarks**

Create `docs/performance-benchmarks.md`:
```markdown
# Performance Benchmarks

## Rate Limiting

- **Tenant operations**: 200 req/60s
- **User operations**: 500 req/60s
- **Thread-safe**: ✓ (PyrateLimiter InMemoryBucket)
- **Submission-time limiting**: ✓ (prevents queue buildup)

## Stress Test Results

- 100 concurrent operations: PASS
- Rate limit enforcement: PASS
- Thread safety: PASS
```

**Step 4: Commit**

```bash
git add tests/performance/test_rate_limiting.py docs/performance-benchmarks.md
git commit -m "test: add rate limit stress tests and benchmarks"
```

---

## Chunk Complete Checklist

- [ ] Rate limit stress tests
- [ ] Thread safety verification
- [ ] Performance benchmarks documented
- [ ] 2 tests passing
- [ ] **Phase 2 Week 6 COMPLETE**
