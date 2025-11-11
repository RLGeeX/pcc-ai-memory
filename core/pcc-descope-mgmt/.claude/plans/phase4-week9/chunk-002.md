# Chunk 2: Caching Strategy

**Status:** pending
**Dependencies:** chunk-001
**Estimated Time:** 60 minutes

---

## Task 1: Implement Response Caching

**Files:**
- Create: `src/descope_mgmt/utils/cache.py`
- Create: `tests/unit/utils/test_cache.py`

**Step 1: Write tests**

Create `tests/unit/utils/test_cache.py`:
```python
"""Tests for caching"""
import pytest
from time import sleep
from descope_mgmt.utils.cache import ResponseCache


def test_cache_stores_and_retrieves():
    """Should cache and retrieve responses"""
    cache = ResponseCache(ttl=60)

    cache.set("key1", {"data": "value"})
    result = cache.get("key1")

    assert result == {"data": "value"}


def test_cache_expires_after_ttl():
    """Should expire cache after TTL"""
    cache = ResponseCache(ttl=1)  # 1 second TTL

    cache.set("key1", "value")
    sleep(1.1)

    result = cache.get("key1")
    assert result is None
```

**Step 2: Implement cache**

Create `src/descope_mgmt/utils/cache.py`:
```python
"""Response caching."""
from time import time
from typing import Any


class ResponseCache:
    """Simple TTL-based cache."""

    def __init__(self, ttl: int = 300):
        """Initialize cache.

        Args:
            ttl: Time to live in seconds (default: 5 minutes)
        """
        self.ttl = ttl
        self._cache: dict[str, tuple[Any, float]] = {}

    def get(self, key: str) -> Any | None:
        """Get value from cache.

        Args:
            key: Cache key

        Returns:
            Cached value or None if expired/not found
        """
        if key not in self._cache:
            return None

        value, timestamp = self._cache[key]

        # Check if expired
        if time() - timestamp > self.ttl:
            del self._cache[key]
            return None

        return value

    def set(self, key: str, value: Any) -> None:
        """Set value in cache.

        Args:
            key: Cache key
            value: Value to cache
        """
        self._cache[key] = (value, time())

    def invalidate(self, key: str) -> None:
        """Invalidate cache entry.

        Args:
            key: Cache key
        """
        if key in self._cache:
            del self._cache[key]

    def clear(self) -> None:
        """Clear all cache."""
        self._cache.clear()
```

**Step 3: Integrate with API client**

Modify `src/descope_mgmt/api/descope_client.py` to add optional caching.

**Step 4: Commit**

```bash
git add src/descope_mgmt/utils/cache.py tests/unit/utils/test_cache.py
git commit -m "feat: implement response caching with TTL"
```

---

## Chunk Complete Checklist

- [ ] ResponseCache implementation
- [ ] TTL-based expiration
- [ ] Cache integration
- [ ] 4 tests passing
