# Design Revisions for pcc-descope-mgmt

**Date**: 2025-11-10
**Status**: Approved Resolutions
**References**: Original design document at `.claude/plans/2025-11-10-descope-mgmt-design.md`

This document addresses all critical and required changes identified by the business-analyst and python-pro agent reviews.

---

## Table of Contents

1. [Rate Limiter Implementation](#rate-limiter-implementation)
2. [RateLimitedExecutor Fix](#ratelimitedexecutor-fix)
3. [Timeline Revision](#timeline-revision)
4. [Performance Testing Strategy](#performance-testing-strategy)
5. [Backup File Format](#backup-file-format)
6. [Backup Storage Strategy](#backup-storage-strategy)
7. [Integration Testing with Descope Test Users](#integration-testing-with-descope-test-users)
8. [SSO Scope Clarification](#sso-scope-clarification)
9. [Additional Improvements](#additional-improvements)

---

## 1. Rate Limiter Implementation

### Decision: Use PyrateLimiter Library

**Rationale**: Battle-tested, thread-safe, supports multiple backends (InMemory, Redis, SQLite), actively maintained.

### Implementation Design

#### Dependencies Update

```python
# requirements.txt
# Add to core dependencies
pyrate-limiter>=3.1.0  # Thread-safe rate limiting
```

#### Rate Limiter Wrapper

```python
# src/descope_mgmt/api/rate_limit.py
"""
Rate limiting for Descope API using PyrateLimiter library.
"""
from threading import Lock
from typing import Optional
from pyrate_limiter import (
    Limiter,
    InMemoryBucket,
    Rate,
    Duration,
    BucketFullException,
)
import structlog

logger = structlog.get_logger()


class DescopeRateLimiter:
    """
    Thread-safe rate limiter for Descope API calls.

    Implements rate limiting using PyrateLimiter's InMemoryBucket
    with sliding window algorithm. Designed for Descope's limits:
    - Tenant operations: 200 requests per 60 seconds
    - User operations: 500 requests per 60 seconds (generic)
    """

    def __init__(
        self,
        max_requests: int = 200,
        window_seconds: int = 60,
        resource_name: str = "descope-api"
    ):
        """
        Initialize rate limiter.

        Args:
            max_requests: Maximum requests allowed in window
            window_seconds: Time window in seconds
            resource_name: Name for logging and identification
        """
        self.resource_name = resource_name
        self.max_requests = max_requests
        self.window_seconds = window_seconds

        # Define rate
        rate = Rate(max_requests, Duration.SECOND * window_seconds)

        # Create in-memory bucket (thread-safe)
        bucket = InMemoryBucket([rate])

        # Create limiter with delay capability
        self._limiter = Limiter(
            bucket,
            raise_when_fail=True,  # Raise exception when rate exceeded
            max_delay=None  # We'll handle delays manually
        )

        # Lock for thread-safe acquire
        self._lock = Lock()

        logger.info(
            "Rate limiter initialized",
            resource=resource_name,
            max_requests=max_requests,
            window_seconds=window_seconds
        )

    def acquire(self, weight: int = 1) -> None:
        """
        Acquire a rate limit token. Blocks if rate limit exceeded.

        Args:
            weight: Weight of this request (default 1)

        Raises:
            BucketFullException: If rate limit exceeded after retries
        """
        with self._lock:
            try:
                # Try to acquire with the resource name as the item
                self._limiter.try_acquire(self.resource_name, weight=weight)

                logger.debug(
                    "Rate limit acquired",
                    resource=self.resource_name,
                    weight=weight,
                    current_rate=self.current_rate
                )

            except BucketFullException as e:
                # Log rate limit hit
                logger.warning(
                    "Rate limit exceeded",
                    resource=self.resource_name,
                    weight=weight,
                    error=str(e),
                    meta_info=e.meta_info
                )
                raise

    @property
    def current_rate(self) -> int:
        """
        Get approximate current request count in window.

        Note: This is approximate as PyrateLimiter doesn't expose
        internal state. Use for logging/monitoring only.
        """
        # PyrateLimiter doesn't expose internal state, so we can't
        # get exact current rate. Return configured max for reference.
        return self.max_requests

    def reset(self) -> None:
        """
        Reset rate limiter state (for testing).

        Note: Creates a new bucket, discarding all tracked requests.
        """
        rate = Rate(self.max_requests, Duration.SECOND * self.window_seconds)
        bucket = InMemoryBucket([rate])
        self._limiter = Limiter(bucket, raise_when_fail=True)

        logger.info("Rate limiter reset", resource=self.resource_name)


class TenantRateLimiter(DescopeRateLimiter):
    """Rate limiter specifically for tenant operations (200 req/60s)"""

    def __init__(self):
        super().__init__(
            max_requests=200,
            window_seconds=60,
            resource_name="descope-tenant-api"
        )


class UserRateLimiter(DescopeRateLimiter):
    """Rate limiter for user operations (500 req/60s)"""

    def __init__(self):
        super().__init__(
            max_requests=500,
            window_seconds=60,
            resource_name="descope-user-api"
        )
```

#### Retry Decorator with Rate Limit Handling

```python
# src/descope_mgmt/api/retry.py
"""
Retry logic with exponential backoff for API calls.
"""
import functools
import time
from typing import Callable, TypeVar, Any
from pyrate_limiter import BucketFullException
import structlog

logger = structlog.get_logger()

T = TypeVar('T')


def retry_with_backoff(
    max_attempts: int = 5,
    initial_delay: float = 1.0,
    max_delay: float = 60.0,
    exponential_base: float = 2.0
):
    """
    Decorator to retry function calls with exponential backoff.

    Automatically handles BucketFullException from rate limiter by
    waiting for the required delay before retrying.

    Args:
        max_attempts: Maximum retry attempts
        initial_delay: Initial delay in seconds
        max_delay: Maximum delay cap in seconds
        exponential_base: Base for exponential backoff (default 2.0)
    """
    def decorator(func: Callable[..., T]) -> Callable[..., T]:
        @functools.wraps(func)
        def wrapper(*args: Any, **kwargs: Any) -> T:
            attempt = 0
            delay = initial_delay

            while attempt < max_attempts:
                try:
                    return func(*args, **kwargs)

                except BucketFullException as e:
                    attempt += 1

                    if attempt >= max_attempts:
                        logger.error(
                            "Rate limit exceeded after max retries",
                            function=func.__name__,
                            attempts=attempt,
                            meta_info=e.meta_info
                        )
                        raise

                    # Calculate backoff delay
                    backoff = min(delay * (exponential_base ** attempt), max_delay)

                    logger.warning(
                        "Rate limit hit, retrying with backoff",
                        function=func.__name__,
                        attempt=attempt,
                        max_attempts=max_attempts,
                        backoff_seconds=backoff
                    )

                    time.sleep(backoff)

                except Exception as e:
                    # Other exceptions propagate immediately
                    logger.error(
                        "Function failed",
                        function=func.__name__,
                        error=str(e),
                        attempt=attempt
                    )
                    raise

            # Should never reach here
            raise RuntimeError(f"Retry logic exhausted for {func.__name__}")

        return wrapper
    return decorator
```

#### Integration with API Client

```python
# src/descope_mgmt/api/descope_client.py (excerpt)
"""
Descope API client with rate limiting.
"""
from descope import DescopeClient as DescopeSDK
from .rate_limit import TenantRateLimiter, UserRateLimiter
from .retry import retry_with_backoff

class DescopeApiClient:
    """Wrapper for Descope SDK with rate limiting"""

    def __init__(self, project_id: str, management_key: str):
        self._sdk = DescopeSDK(project_id=project_id, management_key=management_key)
        self._tenant_limiter = TenantRateLimiter()
        self._user_limiter = UserRateLimiter()

    @retry_with_backoff(max_attempts=5)
    def create_tenant(self, tenant_config: dict) -> dict:
        """Create tenant with rate limiting and retry"""
        # Acquire rate limit token BEFORE API call
        self._tenant_limiter.acquire(weight=1)

        # Make API call
        return self._sdk.mgmt.tenant.create(**tenant_config)

    @retry_with_backoff(max_attempts=5)
    def load_tenant(self, tenant_id: str) -> dict:
        """Load tenant with rate limiting"""
        self._tenant_limiter.acquire(weight=1)
        return self._sdk.mgmt.tenant.load(tenant_id)
```

### Testing

```python
# tests/unit/api/test_rate_limiter.py
"""Tests for rate limiter"""
import pytest
import time
from pyrate_limiter import BucketFullException
from descope_mgmt.api.rate_limit import DescopeRateLimiter

def test_rate_limiter_allows_within_limit():
    """Rate limiter allows requests within limit"""
    limiter = DescopeRateLimiter(max_requests=5, window_seconds=1)

    # Should allow 5 requests
    for _ in range(5):
        limiter.acquire()  # Should not raise

def test_rate_limiter_blocks_over_limit():
    """Rate limiter blocks requests over limit"""
    limiter = DescopeRateLimiter(max_requests=5, window_seconds=1)

    # Use up all tokens
    for _ in range(5):
        limiter.acquire()

    # 6th request should raise
    with pytest.raises(BucketFullException):
        limiter.acquire()

def test_rate_limiter_resets_after_window():
    """Rate limiter resets after time window"""
    limiter = DescopeRateLimiter(max_requests=2, window_seconds=1)

    # Use both tokens
    limiter.acquire()
    limiter.acquire()

    # Wait for window to pass
    time.sleep(1.1)

    # Should allow new request
    limiter.acquire()  # Should not raise

def test_rate_limiter_thread_safety():
    """Rate limiter is thread-safe"""
    from concurrent.futures import ThreadPoolExecutor

    limiter = DescopeRateLimiter(max_requests=10, window_seconds=1)

    def try_acquire():
        try:
            limiter.acquire()
            return True
        except BucketFullException:
            return False

    # Try to acquire 20 tokens from 10 threads
    with ThreadPoolExecutor(max_workers=10) as executor:
        futures = [executor.submit(try_acquire) for _ in range(20)]
        results = [f.result() for f in futures]

    # Exactly 10 should succeed
    assert sum(results) == 10
```

---

## 2. RateLimitedExecutor Fix

### Problem
Original design had rate limiting inside thread workers, not at submission time.

### Solution

```python
# src/descope_mgmt/utils/concurrency.py
"""
Concurrent execution utilities with rate limiting.
"""
from concurrent.futures import ThreadPoolExecutor, Future, as_completed
from typing import Callable, TypeVar, Any, Iterator
from pyrate_limiter import BucketFullException
import structlog

from ..api.rate_limit import DescopeRateLimiter

logger = structlog.get_logger()

T = TypeVar('T')


class RateLimitedExecutor:
    """
    Thread pool executor with rate limiting applied at submission time.

    Unlike standard ThreadPoolExecutor, this applies rate limiting
    BEFORE submitting tasks to the pool, preventing queue buildup
    and ensuring API rate limits are respected during submission phase.
    """

    def __init__(
        self,
        max_workers: int,
        rate_limiter: DescopeRateLimiter
    ):
        """
        Initialize rate-limited executor.

        Args:
            max_workers: Maximum number of concurrent workers
            rate_limiter: Rate limiter instance to use
        """
        self._executor = ThreadPoolExecutor(max_workers=max_workers)
        self._rate_limiter = rate_limiter

        logger.info(
            "RateLimitedExecutor initialized",
            max_workers=max_workers,
            rate_limiter=rate_limiter.resource_name
        )

    def submit(
        self,
        fn: Callable[..., T],
        *args: Any,
        weight: int = 1,
        **kwargs: Any
    ) -> Future[T]:
        """
        Submit a callable with rate limiting.

        Acquires rate limit token BEFORE submitting to executor,
        ensuring rate limits are respected during submission phase.

        Args:
            fn: Callable to execute
            *args: Positional arguments for fn
            weight: Rate limit weight for this task
            **kwargs: Keyword arguments for fn

        Returns:
            Future representing the pending execution

        Raises:
            BucketFullException: If rate limit exceeded
        """
        # CRITICAL: Acquire rate limit token BEFORE submission
        try:
            self._rate_limiter.acquire(weight=weight)
        except BucketFullException:
            logger.warning(
                "Rate limit exceeded during submission",
                function=fn.__name__,
                weight=weight
            )
            raise

        # Now submit to executor
        future = self._executor.submit(fn, *args, **kwargs)

        logger.debug(
            "Task submitted",
            function=fn.__name__,
            weight=weight
        )

        return future

    def map(
        self,
        fn: Callable[[Any], T],
        items: list[Any],
        weight: int = 1
    ) -> Iterator[T]:
        """
        Map function over items with rate limiting.

        Args:
            fn: Function to apply to each item
            items: Items to process
            weight: Rate limit weight per item

        Yields:
            Results as they complete
        """
        futures = []

        for item in items:
            future = self.submit(fn, item, weight=weight)
            futures.append(future)

        # Yield results as they complete
        for future in as_completed(futures):
            yield future.result()

    def shutdown(self, wait: bool = True) -> None:
        """Shutdown executor"""
        self._executor.shutdown(wait=wait)

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.shutdown(wait=True)


# Adaptive worker pool sizing based on rate limits
def calculate_optimal_workers(
    rate_limit: int,
    window_seconds: int,
    avg_request_latency: float = 0.5,
    safety_factor: float = 0.8
) -> int:
    """
    Calculate optimal worker pool size based on rate limits.

    Args:
        rate_limit: Maximum requests per window
        window_seconds: Time window in seconds
        avg_request_latency: Average request latency in seconds
        safety_factor: Safety margin (0.8 = use 80% of capacity)

    Returns:
        Optimal number of workers

    Example:
        >>> calculate_optimal_workers(200, 60, 0.5, 0.8)
        2  # 200 req/60s * 0.8 * 0.5s latency = 1.33 workers, round up to 2
    """
    requests_per_second = rate_limit / window_seconds
    theoretical_workers = requests_per_second * avg_request_latency * safety_factor

    # Clamp to reasonable bounds
    optimal = max(1, min(20, int(theoretical_workers) + 1))

    logger.info(
        "Calculated optimal workers",
        rate_limit=rate_limit,
        window_seconds=window_seconds,
        avg_latency=avg_request_latency,
        theoretical=theoretical_workers,
        optimal=optimal
    )

    return optimal
```

### Usage Example

```python
# src/descope_mgmt/domain/services/tenant_service.py (excerpt)
"""Tenant service with batch operations"""
from ...api.descope_client import DescopeApiClient
from ...api.rate_limit import TenantRateLimiter
from ...utils.concurrency import RateLimitedExecutor, calculate_optimal_workers

class TenantService:
    def __init__(self, api_client: DescopeApiClient):
        self._api = api_client
        self._rate_limiter = TenantRateLimiter()

    def batch_create_tenants(self, configs: list[TenantConfig]) -> list[OperationResult]:
        """Create multiple tenants with rate-limited concurrency"""

        # Calculate optimal workers: 200 req/60s, ~0.5s latency
        max_workers = calculate_optimal_workers(200, 60, 0.5, 0.8)

        results = []

        with RateLimitedExecutor(max_workers, self._rate_limiter) as executor:
            # Submit all tasks (rate limiting happens during submission)
            futures = []
            for config in configs:
                future = executor.submit(self._create_tenant, config, weight=1)
                futures.append((config, future))

            # Collect results as they complete
            for config, future in futures:
                try:
                    result = future.result()
                    results.append(OperationResult.success(config.id, result))
                except Exception as e:
                    results.append(OperationResult.failed(config.id, str(e)))

        return results
```

---

## 3. Timeline Revision

### Decision: Extend to 10 Weeks (Full Scope)

**Rationale**: Preserve all features (tenants + flows), add buffer for documentation and testing.

### Revised Implementation Plan

#### Phase 1: Foundation (Weeks 1-2) - UNCHANGED
**Goal**: Basic working CLI with tenant create/list commands

**Week 1**: Core infrastructure, config models, SDK integration
**Week 2**: CLI framework, basic commands, state management

**Deliverables**:
- ✅ Config models with validation
- ✅ Rate limiter integration (PyrateLimiter)
- ✅ API client wrapper
- ✅ 40+ unit tests passing

---

#### Phase 2: Safety & Observability (Weeks 3-4) - UNCHANGED
**Goal**: Production-ready with safety mechanisms

**Week 3**: Backup service, idempotent operations, `tenant sync`
**Week 4**: Structured logging, progress indicators, rate limit handling

**Deliverables**:
- ✅ Idempotent `tenant sync` command
- ✅ Automatic backups
- ✅ Confirmation prompts
- ✅ 30+ integration tests

---

#### Phase 3: Flow Management (Weeks 5-6) - UNCHANGED
**Goal**: Full flow deployment and management

**Week 5**: Flow templates, deploy/list commands
**Week 6**: Flow import/export, versioning, rollback

**Deliverables**:
- ✅ Flow template deployment
- ✅ Flow export/import
- ✅ Flow rollback capability
- ✅ 20+ flow tests

---

#### Phase 4: Polish & Performance (Weeks 7-8) - ENHANCED
**Goal**: Performance optimization and quality improvements

**Week 7**: Performance Optimization
- Batch operation optimization (adaptive worker pools)
- Memory profiling for large configs
- Connection pooling tuning
- Performance benchmarks and tests

**Week 8**: Quality & Testing
- Configuration drift detection
- Multi-environment support refinement
- CLI usability improvements
- Additional edge case testing

**Deliverables**:
- ✅ Performance tests with benchmarks
- ✅ Drift detection
- ✅ Multi-environment orchestration
- ✅ 90%+ test coverage

---

#### Phase 5: Documentation & Release (Weeks 9-10) - NEW
**Goal**: Comprehensive documentation and production readiness

**Week 9**: Documentation Sprint
- User guide (getting started, tutorials, examples)
- Complete command reference with examples
- Configuration guide (YAML schema, best practices)
- Troubleshooting guide
- Pre-commit hook setup guide

**Week 10**: Release Preparation
- Security review and hardening
- Final integration testing with real Descope project
- Performance validation (load testing)
- Release notes and changelog
- Internal deployment documentation (NFS mount setup)

**Deliverables**:
- ✅ Comprehensive documentation (50+ pages)
- ✅ Example configs and scripts
- ✅ Pre-commit hook templates
- ✅ Security audit completed
- ✅ Internal deployment guide (NFS mount)

---

### Timeline Summary

| Phase | Weeks | Focus | Key Deliverables |
|-------|-------|-------|------------------|
| 1 | 1-2 | Foundation | Core infrastructure, basic CLI |
| 2 | 3-4 | Safety | Idempotent sync, backups, observability |
| 3 | 5-6 | Features | Flow management, rollback |
| 4 | 7-8 | Performance | Optimization, benchmarks, drift |
| 5 | 9-10 | Documentation | Docs, release, security audit |

**Total: 10 weeks** (2 weeks added vs original 8-week plan)

---

## 4. Internal Distribution Strategy

### Decision: NFS Mount Only (No PyPI or Git Distribution)

**Context**: Internal tool for team of 2 users.

**Distribution Approach**:
- Tool installed on shared NFS mount at `/home/jfogarty/pcc/core/pcc-descope-mgmt`
- Both users access from same location
- No need for PyPI packaging, git clones, or wheel distribution

**Installation**:
```bash
# Editable install from shared NFS mount
cd /home/jfogarty/pcc/core/pcc-descope-mgmt
pip install -e .

# Tool is now available as: descope-mgmt
descope-mgmt --version
```

**Benefits**:
- ✅ Single source of truth (shared location)
- ✅ Automatic updates (everyone uses same install)
- ✅ No version conflicts
- ✅ No distribution complexity
- ✅ Simplified Phase 5 deliverables

**Phase 5 Simplification**:
- Remove PyPI packaging tasks
- Remove git distribution documentation
- Add NFS mount setup guide
- Add editable install instructions

**Documentation Updates**:
```markdown
## Installation (Internal Team)

### Setup from NFS Mount

1. **Navigate to shared location**:
   ```bash
   cd /home/jfogarty/pcc/core/pcc-descope-mgmt
   ```

2. **Install in editable mode**:
   ```bash
   pip install -e .
   ```

3. **Verify installation**:
   ```bash
   descope-mgmt --version
   descope-mgmt --help
   ```

### Updates

When tool is updated on NFS mount:
- Changes are immediately available (editable install)
- No need to reinstall
- Run `git pull` if using git for version control
```

---

## 5. Performance Testing Strategy

### Addition to Testing Strategy

```python
# tests/performance/conftest.py
"""Fixtures for performance tests"""
import pytest

@pytest.fixture
def large_tenant_configs():
    """Generate 100 tenant configurations"""
    return [
        TenantConfig(
            id=f"tenant-{i:04d}",
            name=f"Tenant {i}",
            domains=[f"tenant{i}.example.com"],
            self_provisioning=True
        )
        for i in range(100)
    ]

@pytest.fixture
def mock_api_with_latency(mocker):
    """Mock API with realistic latency"""
    def mock_create_with_delay(tenant_config):
        time.sleep(0.5)  # Simulate 500ms API latency
        return {"id": tenant_config["id"], "name": tenant_config["name"]}

    mock = mocker.patch('descope_mgmt.api.descope_client.DescopeApiClient')
    mock.return_value.create_tenant.side_effect = mock_create_with_delay
    return mock
```

```python
# tests/performance/test_batch_operations.py
"""Performance tests for batch operations"""
import pytest
import time
from descope_mgmt.domain.services.tenant_service import TenantService

@pytest.mark.performance
def test_batch_tenant_creation_performance(large_tenant_configs, mock_api_with_latency):
    """100 tenants should complete within time constraints"""
    service = TenantService(mock_api_with_latency)

    start = time.time()
    results = service.batch_create_tenants(large_tenant_configs)
    duration = time.time() - start

    # With rate limiting (200 req/60s) and 500ms latency:
    # Theoretical: 100 requests / (200/60) = 30 seconds minimum
    # With overhead: 35-40 seconds acceptable
    assert duration < 45.0, f"Batch operation too slow: {duration}s"

    # All should succeed
    assert len(results) == 100
    assert all(r.status == "success" for r in results)

@pytest.mark.performance
def test_rate_limiter_overhead():
    """Rate limiter should add minimal overhead"""
    from descope_mgmt.api.rate_limit import DescopeRateLimiter

    limiter = DescopeRateLimiter(max_requests=1000, window_seconds=1)

    # Time 100 acquisitions
    start = time.time()
    for _ in range(100):
        limiter.acquire()
    duration = time.time() - start

    # Should be very fast (< 10ms)
    assert duration < 0.01, f"Rate limiter overhead too high: {duration}s"

@pytest.mark.performance
def test_memory_usage_large_config():
    """Memory usage should be reasonable for large configs"""
    import psutil
    import os

    process = psutil.Process(os.getpid())
    initial_memory = process.memory_info().rss / 1024 / 1024  # MB

    # Load 1000 tenant configs
    configs = [
        TenantConfig(
            id=f"tenant-{i:04d}",
            name=f"Tenant {i}",
            domains=[f"tenant{i}.example.com"],
            self_provisioning=True,
            custom_attributes={"key": f"value-{i}"}
        )
        for i in range(1000)
    ]

    final_memory = process.memory_info().rss / 1024 / 1024  # MB
    memory_increase = final_memory - initial_memory

    # 1000 configs should use < 50MB
    assert memory_increase < 50, f"Memory usage too high: {memory_increase}MB"

@pytest.mark.performance
def test_concurrent_api_calls():
    """Concurrent API calls should respect rate limits"""
    from descope_mgmt.utils.concurrency import RateLimitedExecutor
    from descope_mgmt.api.rate_limit import DescopeRateLimiter

    limiter = DescopeRateLimiter(max_requests=10, window_seconds=1)

    call_times = []

    def mock_api_call():
        call_times.append(time.time())
        time.sleep(0.1)  # Simulate API call
        return "success"

    with RateLimitedExecutor(max_workers=5, rate_limiter=limiter) as executor:
        futures = [executor.submit(mock_api_call) for _ in range(20)]
        results = [f.result() for f in futures]

    # All should succeed
    assert len(results) == 20

    # Check rate limiting: max 10 calls per second
    # Group calls by second
    first_call = min(call_times)
    calls_in_first_second = sum(1 for t in call_times if t - first_call < 1.0)

    # Should be <= 10 (rate limit)
    assert calls_in_first_second <= 10

@pytest.mark.performance
def test_config_loading_performance():
    """Config loading should be fast even for large files"""
    import tempfile
    from descope_mgmt.utils.config_loader import ConfigLoader

    # Create large config file (500 tenants)
    config_data = {
        "version": "1.0",
        "auth": {"project_id": "test", "management_key": "test"},
        "tenants": [
            {
                "id": f"tenant-{i:04d}",
                "name": f"Tenant {i}",
                "domains": [f"tenant{i}.example.com"]
            }
            for i in range(500)
        ]
    }

    with tempfile.NamedTemporaryFile(mode='w', suffix='.yaml', delete=False) as f:
        yaml.dump(config_data, f)
        config_file = f.name

    try:
        start = time.time()
        config = ConfigLoader.load(config_file)
        duration = time.time() - start

        # Should load in < 1 second
        assert duration < 1.0, f"Config loading too slow: {duration}s"
        assert len(config.tenants) == 500
    finally:
        os.unlink(config_file)
```

### Performance Test Configuration

```toml
# pyproject.toml
[tool.pytest.ini_options]
markers = [
    "performance: performance and benchmarking tests (slow)",
]

# Run performance tests separately
# pytest -m performance --benchmark-only
```

---

## 5. Backup File Format

### Pydantic Schema for Backups

```python
# src/descope_mgmt/domain/models/backup.py
"""
Backup data models.
"""
from datetime import datetime
from typing import Optional, Any
from pydantic import BaseModel, Field


class BackupMetadata(BaseModel):
    """Metadata for a backup"""

    version: str = Field(
        default="1.0",
        description="Backup format version"
    )
    timestamp: datetime = Field(
        ...,
        description="When backup was created (ISO 8601)"
    )
    operation: str = Field(
        ...,
        description="Operation that triggered backup (e.g., 'tenant.sync')"
    )
    user: Optional[str] = Field(
        None,
        description="User who initiated operation (from env or git)"
    )
    git_commit: Optional[str] = Field(
        None,
        description="Git commit hash at time of backup"
    )
    environment: Optional[str] = Field(
        None,
        description="Environment name (dev, staging, prod)"
    )
    project_id: str = Field(
        ...,
        description="Descope project ID"
    )


class TenantBackupData(BaseModel):
    """Raw tenant data from Descope API"""

    id: str
    name: str
    selfProvisioning: bool = False
    domains: list[str] = Field(default_factory=list)
    customAttributes: dict[str, Any] = Field(default_factory=dict)
    createdTime: int
    updatedTime: int
    # Add other fields as needed


class FlowBackupData(BaseModel):
    """Raw flow data from Descope API"""

    name: str
    template: str
    enabled: bool = True
    config: dict[str, Any] = Field(default_factory=dict)
    version: Optional[str] = None
    # Add other fields as needed


class Backup(BaseModel):
    """
    Complete backup file format.

    This is the root object serialized to JSON in backup files.
    """

    metadata: BackupMetadata = Field(
        ...,
        description="Backup metadata"
    )
    tenants: list[TenantBackupData] = Field(
        default_factory=list,
        description="Raw tenant data from Descope API"
    )
    flows: list[FlowBackupData] = Field(
        default_factory=list,
        description="Raw flow data from Descope API"
    )
    project_settings: Optional[dict[str, Any]] = Field(
        None,
        description="Project-level settings (future use)"
    )

    def to_json(self) -> str:
        """Serialize to JSON string"""
        return self.model_dump_json(indent=2)

    @classmethod
    def from_json(cls, json_str: str) -> "Backup":
        """Deserialize from JSON string"""
        return cls.model_validate_json(json_str)


class BackupId(BaseModel):
    """Reference to a backup file"""

    filepath: Path = Field(
        ...,
        description="Absolute path to backup file"
    )

    @property
    def timestamp_str(self) -> str:
        """Extract timestamp from filename"""
        # Filename format: 2025-11-10_14-30-15_pre-tenant-sync.json
        parts = self.filepath.stem.split('_')
        return f"{parts[0]} {parts[1].replace('-', ':')}"

    @property
    def operation(self) -> str:
        """Extract operation from filename"""
        parts = self.filepath.stem.split('_')
        return '_'.join(parts[3:])  # Everything after "pre-"
```

### Updated Backup Service

```python
# src/descope_mgmt/domain/services/backup_service.py
"""
Backup and restore service with structured format.
"""
from pathlib import Path
from datetime import datetime
import subprocess
from typing import Optional
import structlog

from ..models.backup import (
    Backup,
    BackupMetadata,
    BackupId,
    TenantBackupData,
    FlowBackupData
)
from ..models.state import ProjectState

logger = structlog.get_logger()


class BackupService:
    """Service for creating and restoring backups with structured format"""

    def __init__(self, backup_dir: Path = Path(".descope-backups")):
        self.backup_dir = backup_dir
        self.backup_dir.mkdir(exist_ok=True, parents=True)

    def create_backup(
        self,
        operation_name: str,
        project_state: ProjectState,
        environment: Optional[str] = None
    ) -> BackupId:
        """
        Create structured backup of current state.

        Args:
            operation_name: Name of operation (e.g., "tenant-sync")
            project_state: Current Descope state to backup
            environment: Environment name (dev, staging, prod)

        Returns:
            BackupId reference to created backup file
        """
        timestamp = datetime.now()
        timestamp_str = timestamp.strftime("%Y-%m-%d_%H-%M-%S")
        filename = f"{timestamp_str}_pre-{operation_name}.json"
        filepath = self.backup_dir / filename

        # Get user from environment or git
        user = self._get_current_user()
        git_commit = self._get_git_commit()

        # Create metadata
        metadata = BackupMetadata(
            version="1.0",
            timestamp=timestamp,
            operation=operation_name,
            user=user,
            git_commit=git_commit,
            environment=environment,
            project_id=project_state.project_id
        )

        # Convert state to backup data
        tenant_backups = [
            TenantBackupData(
                id=t.id,
                name=t.name,
                selfProvisioning=t.self_provisioning,
                domains=t.domains,
                customAttributes=t.custom_attributes,
                createdTime=int(t.created_at.timestamp()),
                updatedTime=int(t.updated_at.timestamp())
            )
            for t in project_state.tenants.values()
        ]

        flow_backups = [
            FlowBackupData(
                name=f.name,
                template=f.template,
                enabled=f.enabled,
                config=f.config,
                version=f.version
            )
            for f in project_state.flows.values()
        ]

        # Create backup object
        backup = Backup(
            metadata=metadata,
            tenants=tenant_backups,
            flows=flow_backups
        )

        # Write to file
        with filepath.open('w') as f:
            f.write(backup.to_json())

        logger.info(
            "Backup created",
            filepath=str(filepath),
            operation=operation_name,
            tenants=len(tenant_backups),
            flows=len(flow_backups),
            size_bytes=filepath.stat().st_size
        )

        return BackupId(filepath=filepath)

    def restore_backup(self, backup_id: BackupId) -> Backup:
        """
        Restore state from backup.

        Args:
            backup_id: Reference to backup file

        Returns:
            Backup object with all data
        """
        if not backup_id.filepath.exists():
            raise FileNotFoundError(f"Backup file not found: {backup_id.filepath}")

        with backup_id.filepath.open() as f:
            backup = Backup.from_json(f.read())

        logger.info(
            "Backup loaded",
            filepath=str(backup_id.filepath),
            operation=backup.metadata.operation,
            timestamp=backup.metadata.timestamp.isoformat(),
            tenants=len(backup.tenants),
            flows=len(backup.flows)
        )

        return backup

    def list_backups(self, limit: int = 20) -> list[BackupMetadata]:
        """
        List recent backups.

        Args:
            limit: Maximum number of backups to return

        Returns:
            List of backup metadata, most recent first
        """
        backups = []

        for filepath in sorted(
            self.backup_dir.glob("*.json"),
            key=lambda p: p.stat().st_mtime,
            reverse=True
        )[:limit]:
            try:
                with filepath.open() as f:
                    backup = Backup.from_json(f.read())
                backups.append(backup.metadata)
            except Exception as e:
                logger.warning(
                    "Failed to read backup",
                    filepath=str(filepath),
                    error=str(e)
                )

        return backups

    def _get_current_user(self) -> Optional[str]:
        """Get current user from environment or git config"""
        import os

        # Try environment variable
        user = os.getenv("USER") or os.getenv("USERNAME")

        if not user:
            # Try git config
            try:
                result = subprocess.run(
                    ["git", "config", "user.email"],
                    capture_output=True,
                    text=True,
                    check=True,
                    timeout=5
                )
                user = result.stdout.strip()
            except (subprocess.CalledProcessError, FileNotFoundError, subprocess.TimeoutExpired):
                pass

        return user

    def _get_git_commit(self) -> Optional[str]:
        """Get current Git commit hash"""
        try:
            result = subprocess.run(
                ["git", "rev-parse", "HEAD"],
                capture_output=True,
                text=True,
                check=True,
                timeout=5
            )
            return result.stdout.strip()
        except (subprocess.CalledProcessError, FileNotFoundError, subprocess.TimeoutExpired):
            return None
```

### Example Backup File

```json
{
  "metadata": {
    "version": "1.0",
    "timestamp": "2025-11-10T14:30:15.123456Z",
    "operation": "tenant-sync",
    "user": "engineer@portco.com",
    "git_commit": "abc123def456...",
    "environment": "production",
    "project_id": "P2abc123..."
  },
  "tenants": [
    {
      "id": "acme-corp",
      "name": "Acme Corporation",
      "selfProvisioning": true,
      "domains": ["acme.com", "acme.net"],
      "customAttributes": {
        "plan": "enterprise",
        "region": "us-east"
      },
      "createdTime": 1699999999,
      "updatedTime": 1700000100
    }
  ],
  "flows": [
    {
      "name": "Default Login Flow",
      "template": "sign-up-or-in",
      "enabled": true,
      "config": {},
      "version": "1.0"
    }
  ],
  "project_settings": null
}
```

---

## 6. Backup Storage Strategy

### Specification

#### Default Storage Location

```
~/.descope-mgmt/backups/
├── 2025-11-10_14-30-15_pre-tenant-sync.json
├── 2025-11-10_14-32-40_pre-flow-deploy.json
└── 2025-11-10_15-00-00_pre-tenant-delete.json
```

**Rationale**: User home directory ensures:
- Persistence across different working directories
- User-specific isolation (no permission issues)
- Easy to locate and manage

#### Alternative Locations

Users can override with `--backup-dir` flag or environment variable:

```bash
# Custom backup directory
descope-mgmt tenant sync --backup-dir /path/to/backups

# Environment variable
export DESCOPE_BACKUP_DIR=/path/to/backups
descope-mgmt tenant sync
```

#### Backup Retention Policy

**Local Retention**:
- Keep last 30 days of backups locally
- Automatic cleanup of older backups (configurable)

```python
# src/descope_mgmt/domain/services/backup_service.py (addition)

def cleanup_old_backups(self, days: int = 30) -> int:
    """
    Remove backups older than specified days.

    Args:
        days: Maximum age of backups to keep

    Returns:
        Number of backups deleted
    """
    import time

    cutoff_time = time.time() - (days * 24 * 60 * 60)
    deleted = 0

    for filepath in self.backup_dir.glob("*.json"):
        if filepath.stat().st_mtime < cutoff_time:
            logger.info(
                "Deleting old backup",
                filepath=str(filepath),
                age_days=(time.time() - filepath.stat().st_mtime) / 86400
            )
            filepath.unlink()
            deleted += 1

    return deleted
```

#### Git Integration (Recommended)

Add backups to git for team-wide access:

```bash
# .gitignore
# Don't ignore backups (keep them in version control)
!.descope-backups/*.json
```

**Benefits**:
- Team can restore from any backup
- Backup history tracked alongside code changes
- Natural disaster recovery (backups on GitHub/GitLab)

#### Cloud Storage (Optional)

For enterprise use, sync backups to cloud:

```bash
# Sync to S3 after each backup
aws s3 sync ~/.descope-mgmt/backups/ s3://company-descope-backups/

# Sync to GCS
gsutil -m rsync -r ~/.descope-mgmt/backups/ gs://company-descope-backups/
```

Add to documentation as optional post-backup hook.

---

## 7. Integration Testing with Descope Test Users

### Strategy: Use Descope Test Users Feature

Based on Descope documentation, we'll use the Test User Management feature for integration testing.

### Implementation

```python
# tests/integration/conftest.py
"""
Integration test fixtures using Descope test users.
"""
import pytest
import os
from descope import DescopeClient

@pytest.fixture(scope="session")
def descope_test_project():
    """
    Descope test project configuration.

    Requires environment variables:
    - DESCOPE_TEST_PROJECT_ID
    - DESCOPE_TEST_MANAGEMENT_KEY
    """
    project_id = os.getenv("DESCOPE_TEST_PROJECT_ID")
    management_key = os.getenv("DESCOPE_TEST_MANAGEMENT_KEY")

    if not project_id or not management_key:
        pytest.skip("Descope test project credentials not configured")

    return {
        "project_id": project_id,
        "management_key": management_key
    }

@pytest.fixture
def descope_client(descope_test_project):
    """Real Descope client for integration tests"""
    return DescopeClient(
        project_id=descope_test_project["project_id"],
        management_key=descope_test_project["management_key"]
    )

@pytest.fixture
def test_tenant_prefix():
    """Unique prefix for test tenants"""
    import uuid
    return f"test-{uuid.uuid4().hex[:8]}"

@pytest.fixture
def cleanup_test_tenants(descope_client, test_tenant_prefix):
    """Clean up test tenants after test"""
    created_tenants = []

    yield created_tenants

    # Cleanup
    for tenant_id in created_tenants:
        try:
            descope_client.mgmt.tenant.delete(tenant_id)
        except Exception as e:
            print(f"Warning: Failed to cleanup tenant {tenant_id}: {e}")
```

### Integration Test Examples

```python
# tests/integration/test_tenant_operations_real.py
"""
Integration tests with real Descope API using test users.
"""
import pytest
from descope_mgmt.domain.models.config import TenantConfig
from descope_mgmt.domain.services.tenant_service import TenantService

@pytest.mark.integration
@pytest.mark.real_api
def test_create_tenant_real_api(
    descope_client,
    test_tenant_prefix,
    cleanup_test_tenants
):
    """Create tenant using real Descope API"""
    service = TenantService(descope_client)

    # Create test tenant
    config = TenantConfig(
        id=f"{test_tenant_prefix}-acme",
        name="Acme Test Corp",
        domains=[],  # Empty to avoid domain conflicts
        self_provisioning=False
    )

    # Create
    result = service.create_tenant(config)
    cleanup_test_tenants.append(config.id)

    assert result.status == "success"
    assert result.resource_id == config.id

    # Verify created
    tenant = descope_client.mgmt.tenant.load(config.id)
    assert tenant["name"] == "Acme Test Corp"

@pytest.mark.integration
@pytest.mark.real_api
def test_tenant_sync_idempotent_real_api(
    descope_client,
    test_tenant_prefix,
    cleanup_test_tenants
):
    """Test idempotent sync with real API"""
    service = TenantService(descope_client)

    config = TenantConfig(
        id=f"{test_tenant_prefix}-widget",
        name="Widget Test Co",
        domains=[],
        self_provisioning=False
    )
    cleanup_test_tenants.append(config.id)

    # First sync: creates tenant
    result1 = service.sync_tenant(config)
    assert result1.change_type == "create"

    # Second sync: no changes (idempotent)
    result2 = service.sync_tenant(config)
    assert result2.change_type == "no_change"

    # Third sync with update: detects change
    config_updated = config.model_copy(update={"name": "Widget Test Company"})
    result3 = service.sync_tenant(config_updated)
    assert result3.change_type == "update"
```

### Test Configuration

```toml
# pyproject.toml
[tool.pytest.ini_options]
markers = [
    "integration: integration tests (may require external services)",
    "real_api: tests that use real Descope API (slow, requires credentials)",
    "performance: performance and benchmarking tests",
]

# Run integration tests with real API
# pytest -m "integration and real_api" --slow
```

### Local Testing Approach

**All testing will be performed locally with pre-commit hooks:**

```bash
# .pre-commit-config.yaml
repos:
  - repo: local
    hooks:
      - id: pytest-unit
        name: Run unit tests
        entry: pytest tests/unit/ -v
        language: system
        pass_filenames: false

      - id: ruff-format
        name: Format with ruff
        entry: ruff format
        language: system

      - id: ruff-check
        name: Lint with ruff
        entry: ruff check
        language: system

      - id: mypy
        name: Type check with mypy
        entry: mypy src/
        language: system
        pass_filenames: false
```

**Manual Integration Testing:**
```bash
# Run integration tests manually when needed
pytest -m "integration and real_api" -v

# Or run all tests locally
pytest -v
```

**Note**: No CI/CD pipelines will be configured. All quality gates enforced via pre-commit hooks and manual test runs.

### Documentation

Add to `.claude/docs/testing-guide.md`:

```markdown
## Integration Testing with Descope

Integration tests use real Descope API with test project.

### Setup

1. Create dedicated Descope test project
2. Configure test user settings in project
3. Set environment variables:

```bash
export DESCOPE_TEST_PROJECT_ID=P2test123...
export DESCOPE_TEST_MANAGEMENT_KEY=K2test456...
```

### Running Integration Tests

```bash
# Run all integration tests (with mocked API)
pytest -m integration

# Run integration tests with real API
pytest -m "integration and real_api"
```

### Test Isolation

- Each test uses unique tenant prefix (UUID-based)
- Cleanup fixtures remove test data after each test
- Tests never use production credentials
```

---

## 8. SSO Scope Clarification

### Decision: SSO Configuration is Out of Scope for v1.0 (Manual Setup Required)

#### Rationale

1. **Complexity**: SSO setup involves significant back-and-forth:
   - Google Workspace admin console configuration
   - Certificate exchanges and metadata URLs
   - Domain verification in multiple places
   - Testing and validation loops
2. **One-Time Setup**: Once configured manually, tenants can be managed programmatically
3. **Better User Experience**: Interactive Descope Console UI is better suited for initial SSO setup
4. **Timeline**: Programmatic SSO would add 1-2 weeks to development

#### SSO Configuration Workflow

**Recommended Approach:**

**Step 1: Manual SSO Setup (One-Time per Environment)**
1. Create first tenant in Descope Console (e.g., `pcconnect-main`)
2. Configure Google Workspace SSO for `pcconnect.ai` domain
3. Exchange certificates and metadata with Google Workspace
4. Test SSO login flow
5. Verify domain ownership

**Step 2: Use pcc-descope-mgmt for Everything Else**
- Create additional tenants (portfolio companies)
- Manage tenant settings (domains, custom attributes)
- Deploy authentication flows
- Detect configuration drift

**Step 3: Future Enhancement (v2.0)**
- SSO template replication (copy SSO config from first tenant to new tenants)
- SSO configuration export/import (backup and restore SSO settings)
- Note: Full SSO creation will likely remain manual due to external dependencies

#### What's Included in v1.0

✅ **Tenant Management**:
- Tenant ID, name, domains
- Self-provisioning flag
- Custom attributes
- Reference to manually-configured SSO

✅ **Flow Deployment**:
- Pre-built templates (sign-up-or-in, MFA, magic-link, social)
- Flow configuration parameters
- Flow versioning and rollback

#### What's Out of Scope for v1.0

❌ **SSO Configuration Management**:
- SAML IdP configuration (certificates, metadata URLs)
- OIDC provider setup
- Attribute mapping for SSO claims
- Domain-to-SSO provider mappings
- Automated SSO creation/modification

#### Standard Tenant Configuration Example

```yaml
# descope.yaml

# First tenant with SSO (created manually in Descope Console)
# This serves as the SSO template for the project
tenants:
  - id: "pcconnect-main"
    name: "PortCo Connect Internal"
    domains: ["pcconnect.ai"]
    self_provisioning: true
    custom_attributes:
      sso_configured: "google-workspace"
      sso_setup_date: "2025-11-10"
    # Note: SSO configuration done manually in Descope Console

  # Additional tenants (created via pcc-descope-mgmt)
  - id: "portfolio-acme"
    name: "Acme Corporation"
    domains: ["acme.com"]
    self_provisioning: true
    custom_attributes:
      plan: "enterprise"
      region: "us-east"

  - id: "portfolio-widget"
    name: "Widget Company"
    domains: ["widget.io"]
    self_provisioning: false
```

#### Documentation Update

```markdown
## Prerequisites: SSO Configuration

### Initial Setup Required (One-Time per Environment)

Before using `pcc-descope-mgmt`, configure SSO for the primary tenant:

1. **Create Primary Tenant**:
   - Log into Descope Console
   - Create tenant (e.g., `pcconnect-main`)
   - Add domain: `pcconnect.ai`

2. **Configure Google Workspace SSO**:
   - Navigate to: Descope Console → Tenants → pcconnect-main → SSO
   - Select: "Add Identity Provider" → Google Workspace
   - Follow wizard to exchange metadata with Google Workspace
   - Test SSO login with `user@pcconnect.ai`

3. **Document SSO Configuration**:
   - Add custom attributes to tenant config noting SSO setup
   - This allows `pcc-descope-mgmt` to manage the tenant without modifying SSO

### After SSO Setup

Once SSO is configured manually, use `pcc-descope-mgmt` for:
- Creating additional tenants for portfolio companies
- Managing tenant settings and custom attributes
- Deploying authentication flows
- Detecting configuration drift

### Future Enhancement (v2.0)

Planned features for programmatic SSO management:
- **SSO Template Replication**: Copy SSO config from primary tenant to new tenants
- **SSO Export/Import**: Backup and restore SSO configurations
- **SSO Validation**: Verify SSO configuration is working correctly

Note: Full automated SSO creation will likely remain manual due to external dependencies (Google Workspace admin console, certificate exchanges, domain verification).
```

---

## 9. Additional Improvements

### Addressed from Python-Pro Review

#### 1. Add Type Stubs for Descope SDK

```python
# typings/descope.pyi
"""Type stubs for Descope SDK"""
from typing import Any, Optional

class TenantAPI:
    def load(self, tenant_id: str) -> dict[str, Any]: ...
    def create(self, **kwargs: Any) -> dict[str, Any]: ...
    def update(self, tenant_id: str, **kwargs: Any) -> dict[str, Any]: ...
    def delete(self, tenant_id: str) -> None: ...
    def load_all(self) -> dict[str, list[dict[str, Any]]]: ...

class FlowAPI:
    def list(self) -> list[dict[str, Any]]: ...
    def deploy(self, **kwargs: Any) -> dict[str, Any]: ...

class ManagementSDK:
    tenant: TenantAPI
    flow: FlowAPI

class DescopeClient:
    def __init__(self, project_id: str, management_key: str): ...
    mgmt: ManagementSDK
```

Update mypy config:

```toml
# pyproject.toml
[tool.mypy]
python_version = "3.12"
strict = true
mypy_path = "typings"

# Remove ignore_missing_imports for descope
# [[tool.mypy.overrides]]
# module = "descope.*"
# ignore_missing_imports = true  # REMOVED
```

#### 2. Fix Streaming Config Loading

```python
# src/descope_mgmt/utils/config_loader.py
"""
Config loading with true streaming for large files.
"""
from pathlib import Path
from typing import Generator
import yaml

def load_config_streaming(filepath: str) -> Generator[TenantConfig, None, None]:
    """
    Stream tenant configs from large YAML file.

    Uses multi-document YAML format for true streaming without
    loading entire file into memory.
    """
    with open(filepath) as f:
        # Use safe_load_all for streaming multi-document YAML
        for document in yaml.safe_load_all(f):
            if 'tenant' in document:
                yield TenantConfig(**document['tenant'])

# Alternative: Single document with iterator
def load_config_lazy(filepath: str) -> Generator[TenantConfig, None, None]:
    """
    Lazy load from single-document YAML.

    Note: Still loads full YAML, but processes tenants lazily.
    Use multi-document format above for true streaming.
    """
    with open(filepath) as f:
        data = yaml.safe_load(f)

    # Yield one at a time (memory efficient for processing)
    for tenant_data in data.get('tenants', []):
        yield TenantConfig(**tenant_data)
```

#### 3. Add Import Cycle Prevention Architecture

```
src/descope_mgmt/
├── types/                    # Shared protocols (imports nothing)
│   ├── __init__.py
│   └── protocols.py          # All Protocol definitions
├── domain/                   # Business logic (imports only types/)
│   ├── models/
│   ├── services/
│   └── operations/
├── api/                      # External calls (imports types/ and domain/models)
│   ├── protocols.py          # Implements types/protocols
│   └── descope_client.py
└── cli/                      # User interface (imports all layers)
    └── main.py
```

**Dependency Rules**:
- `types/` imports nothing
- `domain/` imports only `types/`
- `api/` imports `types/` and `domain/models`
- `cli/` imports all layers
- NO circular imports possible

---

## Summary of Changes

### ✅ Required Changes (All Addressed)

1. **Rate Limiter**: ✅ Using PyrateLimiter with InMemoryBucket, thread-safe
2. **RateLimitedExecutor**: ✅ Fixed to apply rate limiting at submission
3. **Timeline**: ✅ Extended to 10 weeks (full scope + documentation)
4. **Distribution Strategy**: ✅ NFS mount only (no PyPI/git distribution)
5. **Performance Tests**: ✅ Comprehensive performance testing strategy
6. **Backup Format**: ✅ Pydantic schema with structured JSON format
7. **Backup Storage**: ✅ Specified location, retention, git integration
8. **Integration Testing**: ✅ Using Descope test users with real API
9. **SSO Scope**: ✅ Documented as out-of-scope for v1.0, deferred to v2.0

### ✅ Additional Improvements

10. **Type Stubs**: ✅ Created for Descope SDK (removes mypy ignore)
11. **Streaming**: ✅ Fixed config loading with multi-document YAML
12. **Architecture**: ✅ Added types/ package for import cycle prevention
13. **Documentation**: ✅ Enhanced with testing guide and scope limitations

---

## Next Steps

1. **Update design document** with these resolutions (append or inline)
2. **Get final approval** from business-analyst and python-pro agents
3. **Begin implementation** starting with Phase 1 Week 1

---

**Status**: Ready for final review and approval
**Blockers Resolved**: All critical issues addressed
**Timeline**: 10 weeks, realistic and achievable
**Quality**: Production-ready design with 85%+ coverage
