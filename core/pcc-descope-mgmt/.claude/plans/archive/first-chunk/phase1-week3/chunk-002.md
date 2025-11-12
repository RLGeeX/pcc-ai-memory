# Chunk 2: Restore Service

**Status:** pending
**Dependencies:** chunk-001
**Estimated Time:** 45-60 minutes

---

## Task 1: Implement RestoreService

**Files:**
- Create: `src/descope_mgmt/domain/services/restore_service.py`
- Create: `tests/unit/domain/test_restore_service.py`

**Step 1: Write failing tests**

Create `tests/unit/domain/test_restore_service.py`:
```python
"""Tests for restore service"""
import pytest
import json
from pathlib import Path
from datetime import datetime
from descope_mgmt.domain.services.restore_service import RestoreService
from descope_mgmt.domain.services.backup_service import BackupService
from descope_mgmt.domain.models.config import DescopeConfig, TenantConfig
from descope_mgmt.types.exceptions import ValidationError


@pytest.fixture
def backup_dir(tmp_path):
    """Create a backup for testing"""
    service = BackupService(backup_root=tmp_path)
    config = DescopeConfig(
        version="1.0",
        tenants=[TenantConfig(id="acme-corp", name="Acme Corp")]
    )
    return service.create_backup("P2test", "test", config)


def test_load_backup(backup_dir):
    """Should load backup from directory"""
    service = RestoreService()
    backup = service.load_backup(backup_dir)

    assert backup.project_id == "P2test"
    assert backup.environment == "test"
    assert len(backup.tenants) == 1
    assert backup.tenants[0].tenant_id == "acme-corp"


def test_validate_backup(backup_dir):
    """Should validate backup structure"""
    service = RestoreService()
    backup = service.load_backup(backup_dir)

    # Should not raise
    service.validate_backup(backup, "P2test", "test")


def test_validate_backup_project_mismatch(backup_dir):
    """Should reject backup for wrong project"""
    service = RestoreService()
    backup = service.load_backup(backup_dir)

    with pytest.raises(ValidationError, match="project mismatch"):
        service.validate_backup(backup, "P2wrong", "test")


def test_validate_backup_environment_mismatch(backup_dir):
    """Should reject backup for wrong environment"""
    service = RestoreService()
    backup = service.load_backup(backup_dir)

    with pytest.raises(ValidationError, match="environment mismatch"):
        service.validate_backup(backup, "P2test", "prod")
```

**Step 2: Run tests to verify they fail**

Run: `pytest tests/unit/domain/test_restore_service.py -v`

Expected: FAIL (service not implemented)

**Step 3: Implement restore service**

Create `src/descope_mgmt/domain/services/restore_service.py`:
```python
"""Restore service for loading backups."""
import json
from pathlib import Path
from descope_mgmt.domain.models.backup import ProjectBackup
from descope_mgmt.types.exceptions import ValidationError, ConfigurationError


class RestoreService:
    """Service for loading and restoring backups."""

    def load_backup(self, backup_path: Path) -> ProjectBackup:
        """Load backup from directory.

        Args:
            backup_path: Path to backup directory

        Returns:
            ProjectBackup model

        Raises:
            ConfigurationError: If backup file not found or invalid
        """
        backup_file = backup_path / "project.json"

        if not backup_file.exists():
            raise ConfigurationError(
                f"Backup file not found: {backup_file}"
            )

        try:
            with open(backup_file) as f:
                data = json.load(f)

            return ProjectBackup(**data)
        except Exception as e:
            raise ConfigurationError(
                f"Failed to load backup: {e}"
            ) from e

    def validate_backup(
        self,
        backup: ProjectBackup,
        expected_project_id: str,
        expected_environment: str
    ) -> None:
        """Validate backup matches expected project and environment.

        Args:
            backup: Loaded backup
            expected_project_id: Expected project ID
            expected_environment: Expected environment

        Raises:
            ValidationError: If backup doesn't match expectations
        """
        if backup.project_id != expected_project_id:
            raise ValidationError(
                f"Backup project mismatch: expected {expected_project_id}, "
                f"got {backup.project_id}"
            )

        if backup.environment != expected_environment:
            raise ValidationError(
                f"Backup environment mismatch: expected {expected_environment}, "
                f"got {backup.environment}"
            )

    def get_tenant_configs(self, backup: ProjectBackup) -> list:
        """Extract tenant configs from backup.

        Args:
            backup: Loaded backup

        Returns:
            List of TenantConfig objects
        """
        return [tb.config for tb in backup.tenants]

    def preview_restore(self, backup: ProjectBackup) -> dict:
        """Preview what would be restored.

        Args:
            backup: Loaded backup

        Returns:
            Dictionary with restore preview
        """
        return {
            "project_id": backup.project_id,
            "environment": backup.environment,
            "tenant_count": len(backup.tenants),
            "flow_count": len(backup.flows),
            "backup_timestamp": backup.metadata.timestamp,
            "tenants": [tb.tenant_id for tb in backup.tenants],
            "flows": [fb.flow_id for fb in backup.flows]
        }
```

**Step 4: Run tests to verify they pass**

Run: `pytest tests/unit/domain/test_restore_service.py -v`

Expected: PASS (all 4 tests)

**Step 5: Commit**

```bash
git add src/descope_mgmt/domain/services/restore_service.py tests/unit/domain/test_restore_service.py
git commit -m "feat: implement restore service with validation"
```

---

## Task 2: Add Integration Tests and Exports

**Files:**
- Create: `tests/integration/test_backup_restore.py`
- Modify: `src/descope_mgmt/domain/services/__init__.py`

**Step 1: Write integration test**

Create `tests/integration/test_backup_restore.py`:
```python
"""Integration test for backup and restore"""
from descope_mgmt.domain.services import BackupService, RestoreService
from descope_mgmt.domain.models.config import DescopeConfig, TenantConfig


def test_backup_and_restore_roundtrip(tmp_path):
    """Should backup and restore configuration"""
    # Create original config
    original_config = DescopeConfig(
        version="1.0",
        tenants=[
            TenantConfig(id="acme-corp", name="Acme Corporation", domains=["acme.com"]),
            TenantConfig(id="widget-co", name="Widget Company", self_provisioning=True)
        ]
    )

    # Backup
    backup_service = BackupService(backup_root=tmp_path)
    backup_path = backup_service.create_backup("P2test", "test", original_config)

    # Restore
    restore_service = RestoreService()
    backup = restore_service.load_backup(backup_path)

    # Validate
    restore_service.validate_backup(backup, "P2test", "test")

    # Extract configs
    restored_configs = restore_service.get_tenant_configs(backup)

    # Verify
    assert len(restored_configs) == 2
    assert restored_configs[0].id == "acme-corp"
    assert restored_configs[0].name == "Acme Corporation"
    assert restored_configs[0].domains == ["acme.com"]
    assert restored_configs[1].id == "widget-co"
    assert restored_configs[1].self_provisioning is True


def test_restore_preview(tmp_path):
    """Should preview restore operation"""
    config = DescopeConfig(
        version="1.0",
        tenants=[TenantConfig(id="test", name="Test")]
    )

    backup_service = BackupService(backup_root=tmp_path)
    backup_path = backup_service.create_backup("P2test", "test", config)

    restore_service = RestoreService()
    backup = restore_service.load_backup(backup_path)
    preview = restore_service.preview_restore(backup)

    assert preview["project_id"] == "P2test"
    assert preview["environment"] == "test"
    assert preview["tenant_count"] == 1
    assert "test" in preview["tenants"]
```

**Step 2: Update exports**

Modify `src/descope_mgmt/domain/services/__init__.py`:
```python
"""Domain services for descope-mgmt."""
from descope_mgmt.domain.services.state_fetcher import StateFetcher
from descope_mgmt.domain.services.diff_service import DiffService
from descope_mgmt.domain.services.backup_service import BackupService
from descope_mgmt.domain.services.restore_service import RestoreService

__all__ = [
    "StateFetcher",
    "DiffService",
    "BackupService",
    "RestoreService",
]
```

**Step 3: Run tests**

Run: `pytest tests/integration/test_backup_restore.py -v`

Expected: PASS (all 2 tests)

**Step 4: Commit**

```bash
git add tests/integration/test_backup_restore.py src/descope_mgmt/domain/services/__init__.py
git commit -m "test: add backup/restore integration tests and exports"
```

---

## Chunk Complete Checklist

- [ ] RestoreService implementation (4 tests)
- [ ] Backup validation logic
- [ ] Preview restore functionality
- [ ] Integration tests (2 tests)
- [ ] Service exports updated
- [ ] All commits made
- [ ] 6 tests passing total
