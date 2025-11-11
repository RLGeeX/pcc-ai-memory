# Python Technical Analysis for pcc-descope-mgmt

## Executive Summary

This document provides Python-specific architectural guidance for building `pcc-descope-mgmt`, a CLI tool for managing Descope authentication infrastructure. The analysis covers design patterns, code organization, error handling, testing strategies, and performance considerations tailored to Python 3.12 with emphasis on type safety, maintainability, and idempotent operations.

## 1. Design Patterns

### Recommended Patterns

**Dependency Injection with Protocol Pattern**
```python
from typing import Protocol
from descope import DescopeClient

class DescopeAPIProtocol(Protocol):
    def create_project(self, config: dict) -> str: ...
    def get_project(self, project_id: str) -> dict: ...

class DescopeAPIWrapper:
    """Concrete implementation with retry/rate-limit logic"""
    def __init__(self, client: DescopeClient, rate_limiter: RateLimiter):
        self._client = client
        self._rate_limiter = rate_limiter
```
- **Benefit**: Enables testing with mock implementations without monkey-patching
- **Type Safety**: Mypy validates protocol compliance

**Strategy Pattern for Operations**
```python
from abc import ABC, abstractmethod

class Operation(ABC):
    @abstractmethod
    async def execute(self, ctx: OperationContext) -> OperationResult:
        """Execute idempotent operation"""
        pass

    @abstractmethod
    async def validate(self, config: Config) -> list[ValidationError]:
        """Validate before execution"""
        pass

class CreateProjectOperation(Operation):
    """Concrete strategy for project creation"""
    pass
```
- **Rationale**: Each Descope operation (create project, update tenant, modify flow) has unique logic but shares validation/backup/rollback patterns
- **Idempotency**: Strategy pattern centralizes state comparison and diff calculation

**Context Manager for API Sessions**
```python
from contextlib import asynccontextmanager
from typing import AsyncIterator

@asynccontextmanager
async def descope_session(
    api_key: str,
    rate_limit: int = 200
) -> AsyncIterator[DescopeAPIWrapper]:
    """Manage API lifecycle with automatic cleanup and rate limiting"""
    limiter = RateLimiter(rate_limit)
    client = DescopeClient(api_key)
    wrapper = DescopeAPIWrapper(client, limiter)
    try:
        yield wrapper
    finally:
        await wrapper.close()  # Cleanup connections
```
- **Use Case**: Ensures proper resource cleanup even on exceptions
- **Rate Limiting**: Centralized rate limit enforcement per session

**Factory Pattern for Config Loaders**
```python
class ConfigLoaderFactory:
    @staticmethod
    def create_loader(source: str) -> ConfigLoader:
        if source.endswith('.yaml'):
            return YAMLConfigLoader()
        elif source.startswith('http'):
            return RemoteConfigLoader()
        raise ValueError(f"Unsupported source: {source}")
```
- **Extensibility**: Easy to add JSON, TOML, or remote sources without modifying clients

## 2. Code Structure Best Practices

### Package Organization
```
src/pcc_descope_mgmt/
├── __init__.py
├── cli/                      # Click commands (thin layer)
│   ├── __init__.py
│   ├── main.py              # Entry point
│   ├── project.py           # Project subcommands
│   ├── tenant.py            # Tenant subcommands
│   └── flow.py              # Flow subcommands
├── domain/                   # Business logic (framework-agnostic)
│   ├── __init__.py
│   ├── models.py            # Pydantic models
│   ├── operations/          # Operation strategies
│   │   ├── __init__.py
│   │   ├── base.py
│   │   ├── project.py
│   │   └── tenant.py
│   ├── state.py             # State comparison logic
│   └── validators.py        # Custom validation logic
├── api/                      # External API interactions
│   ├── __init__.py
│   ├── client.py            # Descope SDK wrapper
│   ├── rate_limiter.py      # Rate limiting implementation
│   └── retry.py             # Retry with exponential backoff
├── config/                   # Configuration management
│   ├── __init__.py
│   ├── loaders.py           # YAML/JSON loaders
│   └── schemas.py           # Config Pydantic models
└── utils/                    # Cross-cutting concerns
    ├── __init__.py
    ├── logging.py           # Structured logging setup
    └── backup.py            # Backup utilities

tests/
├── unit/                     # Fast, isolated tests
│   ├── test_models.py
│   ├── test_state.py
│   └── test_validators.py
├── integration/              # Tests with mocked API
│   ├── test_operations.py
│   └── test_cli.py
└── fixtures/                 # Shared test data
    ├── configs/
    └── api_responses/
```

**Key Principles**:
- **Separation of Concerns**: CLI layer only handles argument parsing and output formatting
- **Domain-Driven Design**: Business logic in `domain/` is framework-agnostic (no Click dependencies)
- **Testability**: Domain layer can be tested without CLI or API mocking

## 3. Error Handling Strategy

### Exception Hierarchy
```python
class DescopeMgmtError(Exception):
    """Base exception for all tool errors"""
    def __init__(self, message: str, context: dict | None = None):
        self.message = message
        self.context = context or {}
        super().__init__(message)

class ConfigurationError(DescopeMgmtError):
    """Invalid configuration or validation failure"""
    pass

class APIError(DescopeMgmtError):
    """Descope API interaction failure"""
    def __init__(self, message: str, status_code: int, response_body: str):
        super().__init__(message, {"status_code": status_code, "response": response_body})

class RateLimitError(APIError):
    """Rate limit exceeded"""
    pass

class StateConflictError(DescopeMgmtError):
    """Actual state differs from expected (non-idempotent scenario)"""
    pass
```

### Context Managers for Cleanup
```python
from contextlib import contextmanager
import tempfile
import shutil

@contextmanager
def backup_context(project_id: str, api: DescopeAPIWrapper):
    """Backup current state before modifications"""
    backup_path = None
    try:
        backup_path = create_backup(project_id, api)
        yield backup_path
    except Exception as e:
        if backup_path:
            logger.error(f"Operation failed, backup at {backup_path}")
        raise
    finally:
        # Optional: cleanup old backups
        cleanup_old_backups(keep_count=5)
```

### Error Propagation in CLI
```python
import click
import sys

def handle_errors(func):
    """Decorator for Click commands to convert exceptions to exit codes"""
    @functools.wraps(func)
    def wrapper(*args, **kwargs):
        try:
            return func(*args, **kwargs)
        except ConfigurationError as e:
            logger.error(f"Configuration error: {e.message}", extra=e.context)
            sys.exit(1)
        except RateLimitError as e:
            logger.error(f"Rate limit exceeded: {e.message}")
            sys.exit(2)
        except APIError as e:
            logger.error(f"API error: {e.message}", extra=e.context)
            sys.exit(3)
    return wrapper
```

## 4. Testing Strategy Details

### CLI Testing with Click's CliRunner
```python
from click.testing import CliRunner
from pcc_descope_mgmt.cli.main import cli

def test_project_create_success(mock_api, temp_config_file):
    """Integration test for project creation command"""
    runner = CliRunner()
    result = runner.invoke(cli, [
        'project', 'create',
        '--config', temp_config_file,
        '--dry-run'
    ])
    assert result.exit_code == 0
    assert "Project would be created" in result.output
```

### Mocking External APIs with pytest-mock
```python
import pytest
from unittest.mock import MagicMock

@pytest.fixture
def mock_descope_client(mocker):
    """Mock Descope SDK client"""
    mock = mocker.MagicMock(spec=DescopeClient)
    mock.mgmt.project.create.return_value = {"project_id": "test-123"}
    return mock

def test_create_project_operation(mock_descope_client):
    """Unit test for project creation logic"""
    wrapper = DescopeAPIWrapper(mock_descope_client, rate_limiter=None)
    result = wrapper.create_project({"name": "Test Project"})
    assert result.project_id == "test-123"
    mock_descope_client.mgmt.project.create.assert_called_once()
```

### Fixture Organization
```python
# tests/conftest.py
import pytest
import yaml
from pathlib import Path

@pytest.fixture
def sample_config():
    """Sample valid configuration"""
    return {
        "projects": [
            {"name": "prod", "tenants": ["tenant-a", "tenant-b"]}
        ]
    }

@pytest.fixture
def temp_config_file(tmp_path, sample_config):
    """Write config to temporary YAML file"""
    config_path = tmp_path / "config.yaml"
    config_path.write_text(yaml.dump(sample_config))
    return str(config_path)

@pytest.fixture(scope="session")
def api_response_fixtures():
    """Load API response fixtures from JSON files"""
    fixtures_dir = Path(__file__).parent / "fixtures" / "api_responses"
    return {f.stem: json.loads(f.read_text()) for f in fixtures_dir.glob("*.json")}
```

### Testing Idempotency
```python
def test_create_project_idempotent(mock_api):
    """Verify operation is safe to run multiple times"""
    config = ProjectConfig(name="test-project")

    # First run: should create
    result1 = create_project(config, mock_api)
    assert result1.action == "created"

    # Second run: should detect existing and skip
    result2 = create_project(config, mock_api)
    assert result2.action == "unchanged"

    # Verify API only called once
    assert mock_api.create_project.call_count == 1
```

## 5. Performance Considerations

### Sync vs Async Decision
**Recommendation**: Use **synchronous** implementation with async-compatible architecture
- **Rationale**: Descope SDK is synchronous; wrapping in async adds complexity without performance benefit
- **Future-Proofing**: Design interfaces to accept async in future (use protocols with both sync/async methods)

### Batch Operations Pattern
```python
from concurrent.futures import ThreadPoolExecutor, as_completed

def batch_create_tenants(
    tenants: list[TenantConfig],
    api: DescopeAPIWrapper,
    max_workers: int = 5
) -> list[OperationResult]:
    """Create multiple tenants with controlled parallelism"""
    results = []
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        futures = {
            executor.submit(create_tenant, tenant, api): tenant
            for tenant in tenants
        }
        for future in as_completed(futures):
            try:
                result = future.result()
                results.append(result)
            except Exception as e:
                tenant = futures[future]
                logger.error(f"Failed to create {tenant.name}: {e}")
                results.append(OperationResult(error=str(e)))
    return results
```
- **Rate Limiting**: Integrate with rate limiter to respect API quotas
- **Max Workers**: Default to 5 to avoid overwhelming API (200 req/60s limit)

### Connection Pooling
```python
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

def create_session_with_pooling() -> requests.Session:
    """Session with connection pooling and retries"""
    session = requests.Session()
    retry_strategy = Retry(
        total=3,
        backoff_factor=1,
        status_forcelist=[429, 500, 502, 503, 504],
    )
    adapter = HTTPAdapter(
        max_retries=retry_strategy,
        pool_connections=10,
        pool_maxsize=20
    )
    session.mount("https://", adapter)
    return session
```

### Memory Management for Large Configs
```python
from typing import Iterator

def load_config_stream(file_path: str) -> Iterator[ProjectConfig]:
    """Stream large YAML configs without loading entire file"""
    import yaml
    with open(file_path) as f:
        data = yaml.safe_load_all(f)  # Generator for multi-document YAML
        for doc in data:
            yield ProjectConfig.model_validate(doc)
```

## 6. Type Safety with Pydantic and Mypy

### Pydantic Models for Config Validation
```python
from pydantic import BaseModel, Field, field_validator, ConfigDict
from typing import Annotated

class TenantConfig(BaseModel):
    """Configuration for a Descope tenant"""
    model_config = ConfigDict(frozen=True, extra='forbid')

    name: Annotated[str, Field(min_length=1, max_length=50, pattern=r'^[a-z0-9-]+$')]
    display_name: str
    auth_methods: list[str] = Field(default_factory=lambda: ['email', 'sso'])

    @field_validator('auth_methods')
    @classmethod
    def validate_auth_methods(cls, v: list[str]) -> list[str]:
        valid_methods = {'email', 'sso', 'totp', 'webauthn'}
        if invalid := set(v) - valid_methods:
            raise ValueError(f"Invalid auth methods: {invalid}")
        return v

class ProjectConfig(BaseModel):
    """Configuration for a Descope project"""
    name: str
    tenants: list[TenantConfig] = Field(default_factory=list)
    environment_overrides: dict[str, str] = Field(default_factory=dict)

    @field_validator('environment_overrides')
    @classmethod
    def resolve_env_vars(cls, v: dict[str, str]) -> dict[str, str]:
        """Substitute ${VAR} with environment variables"""
        import os
        import re
        resolved = {}
        for key, value in v.items():
            resolved[key] = re.sub(
                r'\$\{(\w+)\}',
                lambda m: os.getenv(m.group(1), m.group(0)),
                value
            )
        return resolved
```

### Type Hints for API Wrappers
```python
from typing import TypeVar, Generic, Callable
from pydantic import BaseModel

T = TypeVar('T', bound=BaseModel)

class DescopeAPIWrapper:
    def get_resource(
        self,
        resource_id: str,
        response_model: type[T]
    ) -> T:
        """Type-safe API call with automatic Pydantic validation"""
        response = self._client.get(f"/resources/{resource_id}")
        return response_model.model_validate(response.json())

    def list_resources(
        self,
        resource_type: str,
        response_model: type[T]
    ) -> list[T]:
        """Type-safe list operation"""
        response = self._client.get(f"/{resource_type}")
        return [response_model.model_validate(item) for item in response.json()]
```

### Mypy Configuration for Strict Checking
```toml
# pyproject.toml
[tool.mypy]
python_version = "3.12"
warn_return_any = true
warn_unused_configs = true
disallow_untyped_defs = true
disallow_any_unimported = true
no_implicit_optional = true
warn_redundant_casts = true
warn_unused_ignores = true
warn_unreachable = true
strict_equality = true

[[tool.mypy.overrides]]
module = "descope.*"
ignore_missing_imports = true  # If Descope SDK lacks type stubs
```

## 7. Dependency Management

### Recommended Dependencies
```toml
# pyproject.toml
[project]
dependencies = [
    "click>=8.1.7",           # CLI framework
    "pydantic>=2.5.0",        # Data validation
    "pydantic-settings>=2.1", # Settings management
    "descope>=1.0.0",         # Official Descope SDK
    "pyyaml>=6.0.1",          # YAML parsing
    "rich>=13.7.0",           # Terminal UI (tables, progress bars)
    "tenacity>=8.2.3",        # Retry with exponential backoff
    "structlog>=23.2.0",      # Structured logging
    "python-dotenv>=1.0.0",   # Environment variable loading
]

[project.optional-dependencies]
dev = [
    "pytest>=7.4.0",
    "pytest-cov>=4.1.0",
    "pytest-mock>=3.12.0",
    "pytest-asyncio>=0.21.0",  # If adding async in future
    "ruff>=0.1.6",
    "mypy>=1.7.0",
    "types-pyyaml>=6.0.12",
    "pre-commit>=3.5.0",
]
```

### Dependencies to Avoid
- **Avoid**: `asyncio` wrappers for sync SDK (unnecessary complexity)
- **Avoid**: Heavy CLI frameworks (Typer, argparse) - Click is sufficient
- **Avoid**: Multiple YAML parsers - stick with PyYAML
- **Avoid**: Custom retry logic - use `tenacity` library

### Pinning Strategy
```bash
# requirements.txt (generated from pyproject.toml)
click==8.1.7
pydantic==2.5.2
# ... pin exact versions for reproducibility

# pyproject.toml (source of truth)
dependencies = [
    "click>=8.1.7,<9.0",  # Allow patch updates
    "pydantic>=2.5.0,<3.0",
]
```

## 8. Common Python Pitfalls to Avoid

### Mutable Default Arguments
```python
# WRONG
def create_project(config: dict, tags: list[str] = []):
    tags.append("default")  # Mutates shared default!

# CORRECT
def create_project(config: dict, tags: list[str] | None = None):
    if tags is None:
        tags = []
    tags.append("default")
```

### API Token Security
```python
# WRONG
API_KEY = "dsk_12345"  # Hardcoded

# CORRECT
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    descope_api_key: str

    class Config:
        env_file = '.env'
        env_file_encoding = 'utf-8'

settings = Settings()  # Loads from environment
```

### Exception Handling in Loops
```python
# WRONG - one failure stops all processing
for tenant in tenants:
    create_tenant(tenant)  # Exception aborts loop

# CORRECT - collect failures and continue
results = []
for tenant in tenants:
    try:
        result = create_tenant(tenant)
        results.append(result)
    except Exception as e:
        logger.error(f"Failed {tenant.name}: {e}")
        results.append(OperationResult(error=str(e)))
```

### Type Hint Pitfalls
```python
# WRONG - using dict/list without generics
def process_config(data: dict) -> list:
    pass

# CORRECT - specific types
def process_config(data: dict[str, Any]) -> list[ProjectConfig]:
    pass

# BETTER - Pydantic model
def process_config(data: ConfigDict) -> list[ProjectConfig]:
    pass
```

### Import Cycles
```python
# WRONG - circular imports
# models.py
from .operations import Operation  # operations.py imports models.py

# CORRECT - use TYPE_CHECKING
from typing import TYPE_CHECKING
if TYPE_CHECKING:
    from .operations import Operation  # Only imported for type checking
```

### Resource Leaks
```python
# WRONG
f = open('config.yaml')
data = yaml.safe_load(f)
# File handle never closed if exception occurs

# CORRECT
with open('config.yaml') as f:
    data = yaml.safe_load(f)
# Automatically closed even on exception
```

## Conclusion

This technical analysis emphasizes Python 3.12 best practices for building a maintainable, type-safe CLI tool. Key takeaways:

1. **Use Protocols for Dependency Injection** instead of abstract base classes for better type safety
2. **Separate CLI from Business Logic** to enable testing without Click framework
3. **Leverage Pydantic for All Data Validation** including configs and API responses
4. **Implement Idempotency Through State Comparison** using immutable Pydantic models
5. **Use Context Managers Extensively** for resource management and cleanup
6. **Enable Strict Mypy Checking** to catch type errors before runtime
7. **Structure Tests by Speed** (unit vs integration) for fast feedback loops
8. **Avoid Async Complexity** since Descope SDK is synchronous

The recommended architecture prioritizes maintainability and testability over premature optimization, with clear extension points for future enhancements (async support, additional config formats, new Descope operations).
