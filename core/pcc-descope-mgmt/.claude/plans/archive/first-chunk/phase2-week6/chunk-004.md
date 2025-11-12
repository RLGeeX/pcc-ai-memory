# Chunk 4: Audit Logging

**Status:** pending
**Dependencies:** chunk-002, chunk-003
**Estimated Time:** 45-60 minutes

---

## Task 1: Implement Audit Logger

**Files:**
- Create: `src/descope_mgmt/utils/audit.py`
- Create: `tests/unit/utils/test_audit.py`

**Step 1: Write tests**

Create `tests/unit/utils/test_audit.py`:
```python
"""Tests for audit logging"""
import pytest
from pathlib import Path
from descope_mgmt.utils.audit import AuditLogger


def test_audit_logger(tmp_path):
    """Should log operations to audit log"""
    log_dir = tmp_path / "logs"
    logger = AuditLogger(log_dir=log_dir)

    logger.log_operation(
        operation="tenant_create",
        resource_id="acme-corp",
        user="admin",
        details={"name": "Acme Corp"}
    )

    # Verify log file created
    assert (log_dir / "audit.log").exists()
```

**Step 2: Implement audit logger**

Create `src/descope_mgmt/utils/audit.py`:
```python
"""Audit logging."""
import json
from pathlib import Path
from datetime import datetime
import structlog


class AuditLogger:
    """Audit logger for tracking operations."""

    def __init__(self, log_dir: Path | None = None):
        """Initialize audit logger.

        Args:
            log_dir: Directory for audit logs
        """
        if log_dir is None:
            log_dir = Path.home() / ".descope-mgmt" / "logs"

        self.log_dir = Path(log_dir)
        self.log_dir.mkdir(parents=True, exist_ok=True)

        self.logger = structlog.get_logger()

    def log_operation(
        self,
        operation: str,
        resource_id: str,
        user: str,
        details: dict | None = None
    ) -> None:
        """Log operation to audit log.

        Args:
            operation: Operation type
            resource_id: Resource identifier
            user: User performing operation
            details: Additional details
        """
        log_entry = {
            "timestamp": datetime.now().isoformat(),
            "operation": operation,
            "resource_id": resource_id,
            "user": user,
            "details": details or {}
        }

        # Write to audit log
        audit_file = self.log_dir / "audit.log"
        with open(audit_file, 'a') as f:
            f.write(json.dumps(log_entry) + "\n")

        # Also log via structlog
        self.logger.info(
            "audit_operation",
            operation=operation,
            resource_id=resource_id,
            user=user
        )
```

**Step 3: Commit**

```bash
git add src/descope_mgmt/utils/audit.py tests/unit/utils/test_audit.py
git commit -m "feat: add audit logging for operations"
```

---

## Chunk Complete Checklist

- [ ] AuditLogger service
- [ ] Operation tracking
- [ ] 4 tests passing
