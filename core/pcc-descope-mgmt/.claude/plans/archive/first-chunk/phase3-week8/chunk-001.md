# Chunk 1: Advanced Retry Strategies

**Status:** pending
**Dependencies:** phase3-week7 complete
**Estimated Time:** 60 minutes

---

## Task 1: Implement Circuit Breaker

**Files:**
- Create: `src/descope_mgmt/api/circuit_breaker.py`
- Create: `tests/unit/api/test_circuit_breaker.py`

**Step 1: Write tests**

Create `tests/unit/api/test_circuit_breaker.py`:
```python
"""Tests for circuit breaker"""
import pytest
from descope_mgmt.api.circuit_breaker import CircuitBreaker, CircuitState


def test_circuit_breaker_opens_after_failures():
    """Should open circuit after failure threshold"""
    breaker = CircuitBreaker(failure_threshold=3, timeout=60)

    # Simulate failures
    for _ in range(3):
        breaker.record_failure()

    assert breaker.state == CircuitState.OPEN


def test_circuit_breaker_allows_when_closed():
    """Should allow requests when circuit is closed"""
    breaker = CircuitBreaker()

    assert breaker.can_execute()
```

**Step 2: Implement circuit breaker**

Create `src/descope_mgmt/api/circuit_breaker.py`:
```python
"""Circuit breaker pattern implementation."""
from enum import Enum
from time import time
from dataclasses import dataclass


class CircuitState(Enum):
    """Circuit breaker states."""
    CLOSED = "closed"  # Normal operation
    OPEN = "open"  # Failing, block requests
    HALF_OPEN = "half_open"  # Testing if recovered


@dataclass
class CircuitBreaker:
    """Circuit breaker for API calls."""
    failure_threshold: int = 5
    timeout: int = 60  # seconds
    half_open_attempts: int = 3

    def __post_init__(self):
        self.state = CircuitState.CLOSED
        self.failure_count = 0
        self.last_failure_time = None

    def can_execute(self) -> bool:
        """Check if operation can execute.

        Returns:
            True if operation allowed, False if circuit is open
        """
        if self.state == CircuitState.CLOSED:
            return True

        if self.state == CircuitState.OPEN:
            # Check if timeout has passed
            if self.last_failure_time and (time() - self.last_failure_time) > self.timeout:
                self.state = CircuitState.HALF_OPEN
                return True
            return False

        if self.state == CircuitState.HALF_OPEN:
            return True

        return False

    def record_success(self) -> None:
        """Record successful operation."""
        self.failure_count = 0
        self.state = CircuitState.CLOSED

    def record_failure(self) -> None:
        """Record failed operation."""
        self.failure_count += 1
        self.last_failure_time = time()

        if self.failure_count >= self.failure_threshold:
            self.state = CircuitState.OPEN
```

**Step 3: Commit**

```bash
git add src/descope_mgmt/api/circuit_breaker.py tests/unit/api/test_circuit_breaker.py
git commit -m "feat: implement circuit breaker pattern"
```

---

## Chunk Complete Checklist

- [ ] CircuitBreaker implementation
- [ ] State transitions (closed/open/half-open)
- [ ] 6 tests passing
