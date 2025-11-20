# Chunk 4: Audit Logging - Foundation

**Status:** pending
**Dependencies:** none
**Complexity:** simple
**Estimated Time:** 15 minutes
**Tasks:** 2

---

## Task 1: Create Audit Models

**Agent:** python-pro
**Files:**
- Create: `src/descope_mgmt/types/audit.py`
- Create: `tests/unit/types/test_audit.py`

**Step 1: Write the failing test**

Create test file:

```python
"""Tests for audit logging models."""

from datetime import datetime, UTC
from descope_mgmt.types.audit import AuditEvent, AuditEntry, AuditOperation


def test_audit_event_creation():
    """Test creating an audit event."""
    event = AuditEvent(
        operation=AuditOperation.TENANT_CREATE,
        tenant_id="test-tenant",
        details={"name": "Test Tenant"},
    )

    assert event.operation == AuditOperation.TENANT_CREATE
    assert event.tenant_id == "test-tenant"
    assert event.details["name"] == "Test Tenant"
    assert isinstance(event.timestamp, datetime)


def test_audit_event_serialization():
    """Test audit event can be serialized to dict."""
    event = AuditEvent(
        operation=AuditOperation.TENANT_UPDATE,
        tenant_id="tenant-1",
        user="admin@example.com",
        details={"field": "name", "old": "Old", "new": "New"},
    )

    data = event.model_dump()

    assert data["operation"] == "tenant_update"
    assert data["tenant_id"] == "tenant-1"
    assert data["user"] == "admin@example.com"
    assert "timestamp" in data


def test_audit_entry_with_success():
    """Test audit entry for successful operation."""
    entry = AuditEntry(
        operation=AuditOperation.FLOW_DEPLOY,
        resource_id="sign-up-or-in",
        success=True,
        details={"screens": 3},
    )

    assert entry.success is True
    assert entry.error is None


def test_audit_entry_with_error():
    """Test audit entry for failed operation."""
    entry = AuditEntry(
        operation=AuditOperation.TENANT_DELETE,
        resource_id="tenant-1",
        success=False,
        error="Tenant not found",
    )

    assert entry.success is False
    assert entry.error == "Tenant not found"


def test_audit_operation_enum_values():
    """Test all expected audit operations are defined."""
    expected_ops = [
        "TENANT_CREATE",
        "TENANT_UPDATE",
        "TENANT_DELETE",
        "TENANT_LIST",
        "FLOW_DEPLOY",
        "FLOW_EXPORT",
        "FLOW_IMPORT",
        "FLOW_LIST",
        "BACKUP_CREATE",
        "BACKUP_RESTORE",
    ]

    for op in expected_ops:
        assert hasattr(AuditOperation, op)
```

**Step 2: Run test to verify it fails**

```bash
pytest tests/unit/types/test_audit.py -v
```

Expected: FAIL - "ModuleNotFoundError: No module named 'descope_mgmt.types.audit'"

**Step 3: Write minimal implementation**

Create `src/descope_mgmt/types/audit.py`:

```python
"""Audit logging models."""

from datetime import UTC, datetime
from enum import Enum

from pydantic import BaseModel, Field


class AuditOperation(str, Enum):
    """Enumeration of auditable operations."""

    # Tenant operations
    TENANT_CREATE = "tenant_create"
    TENANT_UPDATE = "tenant_update"
    TENANT_DELETE = "tenant_delete"
    TENANT_LIST = "tenant_list"

    # Flow operations
    FLOW_DEPLOY = "flow_deploy"
    FLOW_EXPORT = "flow_export"
    FLOW_IMPORT = "flow_import"
    FLOW_LIST = "flow_list"

    # Backup operations
    BACKUP_CREATE = "backup_create"
    BACKUP_RESTORE = "backup_restore"


class AuditEvent(BaseModel):
    """Event logged for audit purposes."""

    operation: AuditOperation
    tenant_id: str | None = None
    flow_id: str | None = None
    user: str | None = None
    timestamp: datetime = Field(default_factory=lambda: datetime.now(UTC))
    details: dict[str, str | int | bool] = Field(default_factory=dict)


class AuditEntry(BaseModel):
    """Complete audit log entry with operation result."""

    operation: AuditOperation
    resource_id: str
    success: bool
    error: str | None = None
    timestamp: datetime = Field(default_factory=lambda: datetime.now(UTC))
    user: str | None = None
    details: dict[str, str | int | bool] = Field(default_factory=dict)
```

**Step 4: Run test to verify it passes**

```bash
pytest tests/unit/types/test_audit.py -v
```

Expected: PASS - All 6 tests passing

**Step 5: Verify coverage**

```bash
pytest tests/unit/types/test_audit.py --cov=src/descope_mgmt/types/audit --cov-report=term-missing
```

Expected: 100% coverage

**Step 6: Commit**

```bash
git add src/descope_mgmt/types/audit.py tests/unit/types/test_audit.py
git commit -m "feat: add audit logging models"
```

---

## Task 2: Create AuditLogger Service

**Agent:** python-pro
**Files:**
- Create: `src/descope_mgmt/domain/audit_logger.py`
- Create: `tests/unit/domain/test_audit_logger.py`

**Step 1: Write the failing test**

Create test file:

```python
"""Tests for audit logger service."""

import json
from pathlib import Path

from descope_mgmt.domain.audit_logger import AuditLogger
from descope_mgmt.types.audit import AuditEntry, AuditOperation


def test_audit_logger_initialization(tmp_path: Path):
    """Test audit logger creates log directory."""
    log_dir = tmp_path / "audit"
    logger = AuditLogger(log_dir=log_dir)

    assert log_dir.exists()
    assert log_dir.is_dir()


def test_log_entry_creates_file(tmp_path: Path):
    """Test logging an entry creates a log file."""
    log_dir = tmp_path / "audit"
    logger = AuditLogger(log_dir=log_dir)

    entry = AuditEntry(
        operation=AuditOperation.TENANT_CREATE,
        resource_id="test-tenant",
        success=True,
        details={"name": "Test Tenant"},
    )

    logger.log(entry)

    # Verify log file created
    log_files = list(log_dir.glob("*.jsonl"))
    assert len(log_files) == 1


def test_log_entry_appends_to_daily_file(tmp_path: Path):
    """Test multiple entries append to same daily log file."""
    log_dir = tmp_path / "audit"
    logger = AuditLogger(log_dir=log_dir)

    # Log multiple entries
    for i in range(3):
        entry = AuditEntry(
            operation=AuditOperation.TENANT_UPDATE,
            resource_id=f"tenant-{i}",
            success=True,
        )
        logger.log(entry)

    # Verify single log file with 3 lines
    log_files = list(log_dir.glob("*.jsonl"))
    assert len(log_files) == 1

    lines = log_files[0].read_text().strip().split("\n")
    assert len(lines) == 3

    # Verify each line is valid JSON
    for line in lines:
        data = json.loads(line)
        assert "operation" in data
        assert "resource_id" in data


def test_read_logs_returns_entries(tmp_path: Path):
    """Test reading logs returns audit entries."""
    log_dir = tmp_path / "audit"
    logger = AuditLogger(log_dir=log_dir)

    # Log some entries
    entries = [
        AuditEntry(
            operation=AuditOperation.TENANT_CREATE,
            resource_id=f"tenant-{i}",
            success=True,
        )
        for i in range(5)
    ]
    for entry in entries:
        logger.log(entry)

    # Read logs
    read_entries = logger.read_logs(limit=10)

    assert len(read_entries) == 5
    assert all(isinstance(e, AuditEntry) for e in read_entries)


def test_read_logs_respects_limit(tmp_path: Path):
    """Test read_logs respects the limit parameter."""
    log_dir = tmp_path / "audit"
    logger = AuditLogger(log_dir=log_dir)

    # Log 10 entries
    for i in range(10):
        entry = AuditEntry(
            operation=AuditOperation.FLOW_DEPLOY,
            resource_id=f"flow-{i}",
            success=True,
        )
        logger.log(entry)

    # Read with limit
    read_entries = logger.read_logs(limit=3)

    assert len(read_entries) == 3
```

**Step 2: Run test to verify it fails**

```bash
pytest tests/unit/domain/test_audit_logger.py -v
```

Expected: FAIL - "ModuleNotFoundError: No module named 'descope_mgmt.domain.audit_logger'"

**Step 3: Write minimal implementation**

Create `src/descope_mgmt/domain/audit_logger.py`:

```python
"""Audit logging service."""

import json
from datetime import UTC, datetime
from pathlib import Path

from descope_mgmt.types.audit import AuditEntry


class AuditLogger:
    """Service for logging audit events to persistent storage."""

    def __init__(self, log_dir: Path | None = None) -> None:
        """Initialize audit logger.

        Args:
            log_dir: Directory for audit logs (defaults to ~/.descope-mgmt/audit)
        """
        if log_dir is None:
            log_dir = Path.home() / ".descope-mgmt" / "audit"

        self.log_dir = log_dir
        self.log_dir.mkdir(parents=True, exist_ok=True)

    def log(self, entry: AuditEntry) -> None:
        """Log an audit entry.

        Args:
            entry: The audit entry to log
        """
        # Create daily log file
        today = datetime.now(UTC).strftime("%Y-%m-%d")
        log_file = self.log_dir / f"{today}.jsonl"

        # Append entry as JSON line
        with log_file.open("a") as f:
            json_line = entry.model_dump_json()
            f.write(json_line + "\n")

    def read_logs(
        self,
        limit: int = 100,
        operation: str | None = None,
    ) -> list[AuditEntry]:
        """Read audit log entries.

        Args:
            limit: Maximum number of entries to return
            operation: Optional filter by operation type

        Returns:
            List of audit entries (most recent first)
        """
        entries: list[AuditEntry] = []

        # Read log files in reverse chronological order
        log_files = sorted(self.log_dir.glob("*.jsonl"), reverse=True)

        for log_file in log_files:
            if len(entries) >= limit:
                break

            lines = log_file.read_text().strip().split("\n")

            # Process lines in reverse (most recent first)
            for line in reversed(lines):
                if len(entries) >= limit:
                    break

                if not line.strip():
                    continue

                try:
                    data = json.loads(line)
                    entry = AuditEntry(**data)

                    # Apply operation filter if specified
                    if operation is None or entry.operation == operation:
                        entries.append(entry)

                except (json.JSONDecodeError, ValueError):
                    # Skip invalid lines
                    continue

        return entries
```

**Step 4: Run test to verify it passes**

```bash
pytest tests/unit/domain/test_audit_logger.py -v
```

Expected: PASS - All 6 tests passing

**Step 5: Verify coverage**

```bash
pytest tests/unit/domain/test_audit_logger.py --cov=src/descope_mgmt/domain/audit_logger --cov-report=term-missing
```

Expected: 95%+ coverage

**Step 6: Commit**

```bash
git add src/descope_mgmt/domain/audit_logger.py tests/unit/domain/test_audit_logger.py
git commit -m "feat: add audit logger service"
```

---

## Chunk Complete Checklist

- [ ] Task 1: Audit models created with 6 tests
- [ ] Task 2: AuditLogger service created with 6 tests
- [ ] All tests passing (177+ total)
- [ ] Coverage maintained at 94%+
- [ ] Code committed (2 commits)
- [ ] Ready for Chunk 5
