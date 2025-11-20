# Chunk 5: Backup Service

**Status:** pending
**Dependencies:** chunk-004-real-api-flows
**Complexity:** medium
**Estimated Time:** 45 minutes
**Tasks:** 2

---

## Context

This chunk implements automatic backup functionality to create safety snapshots before destructive operations (update, delete, sync). Backups are stored locally in `~/.descope-mgmt/backups/` with structured metadata.

**Backup Structure:**
```
~/.descope-mgmt/backups/
├── 2025-11-17T10-30-00_tenant-update_acme-corp.json
├── 2025-11-17T11-15-00_tenant-delete_widget-co.json
└── 2025-11-17T12-00-00_sync-apply_all-tenants.json
```

---

## Task 1: Create Backup Models

**Agent:** python-pro

**Files:**
- Create: `src/descope_mgmt/types/backup.py`
- Create: `tests/unit/types/test_backup.py`

**Step 1: Write failing tests**

Create `tests/unit/types/test_backup.py`:

```python
"""Tests for backup models."""

from datetime import datetime

import pytest

from descope_mgmt.types.backup import BackupMetadata, TenantBackup
from descope_mgmt.types.tenant import TenantConfig


def test_backup_metadata_creation() -> None:
    """Test BackupMetadata model creation."""
    metadata = BackupMetadata(
        timestamp=datetime(2025, 11, 17, 10, 30, 0),
        operation="tenant-update",
        target_id="acme-corp",
        description="Before updating ACME Corporation tenant",
    )

    assert metadata.timestamp.year == 2025
    assert metadata.operation == "tenant-update"
    assert metadata.target_id == "acme-corp"


def test_tenant_backup_creation() -> None:
    """Test TenantBackup model creation."""
    tenant = TenantConfig(id="acme", name="ACME Corp", domains=["acme.com"])
    metadata = BackupMetadata(
        timestamp=datetime(2025, 11, 17, 10, 30, 0),
        operation="tenant-delete",
        target_id="acme",
    )

    backup = TenantBackup(
        metadata=metadata,
        tenant=tenant,
    )

    assert backup.metadata.operation == "tenant-delete"
    assert backup.tenant.id == "acme"


def test_tenant_backup_to_json() -> None:
    """Test TenantBackup JSON serialization."""
    tenant = TenantConfig(id="acme", name="ACME Corp")
    metadata = BackupMetadata(
        timestamp=datetime(2025, 11, 17, 10, 30, 0),
        operation="tenant-delete",
        target_id="acme",
    )
    backup = TenantBackup(metadata=metadata, tenant=tenant)

    json_data = backup.model_dump(mode="json")

    assert json_data["metadata"]["operation"] == "tenant-delete"
    assert json_data["tenant"]["id"] == "acme"
```

**Step 2: Run tests to verify failure**

Run: `pytest tests/unit/types/test_backup.py -v`
Expected: FAIL (module doesn't exist)

**Step 3: Implement backup models**

Create `src/descope_mgmt/types/backup.py`:

```python
"""Backup models for Descope configuration snapshots."""

from datetime import datetime

from pydantic import BaseModel, Field

from descope_mgmt.types.tenant import TenantConfig


class BackupMetadata(BaseModel):
    """Metadata for a backup snapshot.

    Attributes:
        timestamp: When the backup was created
        operation: Operation that triggered the backup (e.g., "tenant-update")
        target_id: ID of the resource being backed up
        description: Optional human-readable description
    """

    timestamp: datetime
    operation: str
    target_id: str
    description: str = ""


class TenantBackup(BaseModel):
    """Backup snapshot of a tenant configuration.

    Contains both metadata about the backup and the tenant state.
    """

    metadata: BackupMetadata
    tenant: TenantConfig

    def filename(self) -> str:
        """Generate filename for this backup.

        Returns:
            Formatted filename (e.g., "2025-11-17T10-30-00_tenant-update_acme-corp.json")
        """
        timestamp_str = self.metadata.timestamp.strftime("%Y-%m-%dT%H-%M-%S")
        return f"{timestamp_str}_{self.metadata.operation}_{self.metadata.target_id}.json"
```

**Step 4: Run tests to verify pass**

Run: `pytest tests/unit/types/test_backup.py -v`
Expected: All 3 tests PASS

**Step 5: Commit**

```bash
git add src/descope_mgmt/types/backup.py tests/unit/types/test_backup.py
git commit -m "feat: add backup models for tenant snapshots

- Create BackupMetadata model with timestamp and operation info
- Create TenantBackup model with metadata and tenant state
- Add filename() method for consistent backup file naming
- Add comprehensive tests for backup models"
```

---

## Task 2: Implement Backup Service

**Agent:** python-pro

**Files:**
- Create: `src/descope_mgmt/domain/backup_service.py`
- Create: `tests/unit/domain/test_backup_service.py`

**Step 1: Write failing tests**

Create `tests/unit/domain/test_backup_service.py`:

```python
"""Tests for backup service."""

from datetime import datetime
from pathlib import Path

import pytest

from descope_mgmt.domain.backup_service import BackupService
from descope_mgmt.types.backup import BackupMetadata
from descope_mgmt.types.tenant import TenantConfig


def test_create_tenant_backup(tmp_path: Path) -> None:
    """Test creating a tenant backup."""
    service = BackupService(backup_dir=tmp_path)
    tenant = TenantConfig(id="acme", name="ACME Corp", domains=["acme.com"])

    backup_path = service.create_tenant_backup(
        tenant=tenant,
        operation="tenant-update",
    )

    assert backup_path.exists()
    assert backup_path.suffix == ".json"
    assert "tenant-update" in backup_path.name
    assert "acme" in backup_path.name


def test_backup_service_creates_directory(tmp_path: Path) -> None:
    """Test backup service creates backup directory if missing."""
    backup_dir = tmp_path / "backups"
    assert not backup_dir.exists()

    service = BackupService(backup_dir=backup_dir)
    tenant = TenantConfig(id="test", name="Test")

    service.create_tenant_backup(tenant, "test-operation")

    assert backup_dir.exists()


def test_list_backups(tmp_path: Path) -> None:
    """Test listing backup files."""
    service = BackupService(backup_dir=tmp_path)

    # Create multiple backups
    tenant1 = TenantConfig(id="tenant1", name="Tenant 1")
    tenant2 = TenantConfig(id="tenant2", name="Tenant 2")

    service.create_tenant_backup(tenant1, "create")
    service.create_tenant_backup(tenant2, "create")

    backups = service.list_backups()

    assert len(backups) == 2


def test_cleanup_old_backups(tmp_path: Path) -> None:
    """Test cleanup removes old backup files."""
    service = BackupService(backup_dir=tmp_path, retention_days=30)

    # Create backup file with old timestamp (31 days ago)
    old_backup = tmp_path / "2024-10-01T00-00-00_old-backup_test.json"
    old_backup.write_text("{}")

    # Create recent backup
    tenant = TenantConfig(id="recent", name="Recent")
    service.create_tenant_backup(tenant, "create")

    # Cleanup old backups
    removed = service.cleanup_old_backups()

    assert removed == 1
    assert not old_backup.exists()
```

**Step 2: Implement BackupService**

Create `src/descope_mgmt/domain/backup_service.py`:

```python
"""Backup service for creating and managing configuration snapshots."""

import json
from datetime import datetime, timedelta
from pathlib import Path

from descope_mgmt.types.backup import BackupMetadata, TenantBackup
from descope_mgmt.types.tenant import TenantConfig


class BackupService:
    """Service for creating and managing backup snapshots.

    Backups are stored as JSON files in the backup directory with
    timestamped filenames for easy identification and cleanup.
    """

    def __init__(
        self,
        backup_dir: Path | None = None,
        retention_days: int = 30,
    ) -> None:
        """Initialize backup service.

        Args:
            backup_dir: Directory for storing backups (default: ~/.descope-mgmt/backups)
            retention_days: Number of days to keep backups (default: 30)
        """
        self.backup_dir = backup_dir or Path.home() / ".descope-mgmt" / "backups"
        self.retention_days = retention_days

        # Ensure backup directory exists
        self.backup_dir.mkdir(parents=True, exist_ok=True)

    def create_tenant_backup(
        self,
        tenant: TenantConfig,
        operation: str,
        description: str = "",
    ) -> Path:
        """Create a backup snapshot of a tenant.

        Args:
            tenant: Tenant configuration to back up
            operation: Operation triggering the backup (e.g., "tenant-update")
            description: Optional description

        Returns:
            Path to created backup file
        """
        metadata = BackupMetadata(
            timestamp=datetime.now(),
            operation=operation,
            target_id=tenant.id,
            description=description or f"Backup before {operation}",
        )

        backup = TenantBackup(
            metadata=metadata,
            tenant=tenant,
        )

        # Write backup to file
        backup_path = self.backup_dir / backup.filename()
        backup_json = backup.model_dump(mode="json")
        backup_path.write_text(json.dumps(backup_json, indent=2))

        return backup_path

    def list_backups(self, target_id: str | None = None) -> list[Path]:
        """List all backup files.

        Args:
            target_id: Optional filter by target ID

        Returns:
            List of backup file paths, sorted by timestamp (newest first)
        """
        pattern = f"*_{target_id}.json" if target_id else "*.json"
        backups = sorted(
            self.backup_dir.glob(pattern),
            key=lambda p: p.stat().st_mtime,
            reverse=True,
        )
        return backups

    def cleanup_old_backups(self) -> int:
        """Remove backup files older than retention period.

        Returns:
            Number of backups removed
        """
        cutoff_date = datetime.now() - timedelta(days=self.retention_days)
        removed = 0

        for backup_file in self.backup_dir.glob("*.json"):
            # Parse timestamp from filename (YYYY-MM-DDTHH-MM-SS_...)
            try:
                timestamp_str = backup_file.name.split("_")[0]
                timestamp = datetime.strptime(timestamp_str, "%Y-%m-%dT%H-%M-%S")

                if timestamp < cutoff_date:
                    backup_file.unlink()
                    removed += 1
            except (ValueError, IndexError):
                # Skip files with unexpected format
                continue

        return removed
```

**Step 3: Run tests to verify pass**

Run: `pytest tests/unit/domain/test_backup_service.py -v`
Expected: All 4 tests PASS

**Step 4: Commit**

```bash
git add src/descope_mgmt/domain/backup_service.py tests/unit/domain/test_backup_service.py
git commit -m "feat: implement backup service

- Create BackupService for managing tenant snapshots
- Store backups in ~/.descope-mgmt/backups/ by default
- Support listing and cleaning up old backups (30-day retention)
- Add comprehensive tests for backup operations"
```

---

## Chunk Complete Checklist

- [ ] Backup models created (Task 1)
- [ ] BackupService implemented (Task 2)
- [ ] All tests passing (142+ total, +7 from chunk)
- [ ] Coverage ≥90%
- [ ] mypy, ruff, lint-imports passing
- [ ] 2 commits pushed

---

## Verification Commands

```bash
# Run tests
pytest tests/unit/types/test_backup.py -v
pytest tests/unit/domain/test_backup_service.py -v

# Quality checks
mypy src/
ruff check .
lint-imports

# Manual verification - backup directory
python3 -c "from descope_mgmt.domain.backup_service import BackupService; s = BackupService(); print(s.backup_dir)"
```

**Expected:** All tests pass, backup directory path displayed correctly.
