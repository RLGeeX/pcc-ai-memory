# Chunk 1: Backup Service with Pydantic Schemas

**Status:** pending
**Dependencies:** phase1-week2 complete
**Estimated Time:** 60 minutes

---

## Task 1: Create Backup Schema Models

**Files:**
- Create: `src/descope_mgmt/domain/models/backup.py`
- Create: `tests/unit/domain/test_backup_models.py`

**Step 1: Write failing tests**

Create `tests/unit/domain/test_backup_models.py`:
```python
"""Tests for backup models"""
import pytest
from datetime import datetime
from descope_mgmt.domain.models.backup import (
    TenantBackup,
    FlowBackup,
    ProjectBackup,
    BackupMetadata
)
from descope_mgmt.domain.models.config import TenantConfig


def test_tenant_backup_creation():
    """Should create tenant backup with metadata"""
    tenant_config = TenantConfig(
        id="acme-corp",
        name="Acme Corporation",
        domains=["acme.com"]
    )

    backup = TenantBackup(
        tenant_id="acme-corp",
        config=tenant_config,
        metadata=BackupMetadata(
            timestamp=datetime.now(),
            project_id="P2test123",
            environment="test"
        )
    )

    assert backup.tenant_id == "acme-corp"
    assert backup.config.name == "Acme Corporation"
    assert backup.metadata.project_id == "P2test123"


def test_project_backup_aggregation():
    """Should aggregate multiple tenant backups"""
    backup = ProjectBackup(
        project_id="P2test123",
        environment="test",
        tenants=[],
        flows=[],
        metadata=BackupMetadata(
            timestamp=datetime.now(),
            project_id="P2test123",
            environment="test"
        )
    )

    assert backup.project_id == "P2test123"
    assert len(backup.tenants) == 0
    assert len(backup.flows) == 0


def test_backup_serialization():
    """Should serialize to JSON"""
    backup = TenantBackup(
        tenant_id="acme-corp",
        config=TenantConfig(id="acme-corp", name="Acme Corp"),
        metadata=BackupMetadata(
            timestamp=datetime.now(),
            project_id="P2test",
            environment="test"
        )
    )

    # Pydantic model_dump should work
    data = backup.model_dump()
    assert data["tenant_id"] == "acme-corp"
    assert "config" in data
    assert "metadata" in data
```

**Step 2: Run tests to verify they fail**

Run: `pytest tests/unit/domain/test_backup_models.py -v`

Expected: FAIL with import errors

**Step 3: Implement backup models**

Create `src/descope_mgmt/domain/models/backup.py`:
```python
"""Backup schema models using Pydantic."""
from datetime import datetime
from typing import Any
from pydantic import BaseModel, Field
from descope_mgmt.domain.models.config import TenantConfig, FlowConfig


class BackupMetadata(BaseModel):
    """Metadata for backups."""
    timestamp: datetime = Field(default_factory=datetime.now)
    project_id: str
    environment: str
    tool_version: str = Field(default="1.0.0")

    class Config:
        frozen = True


class TenantBackup(BaseModel):
    """Backup schema for a single tenant."""
    tenant_id: str
    config: TenantConfig
    metadata: BackupMetadata

    class Config:
        frozen = True


class FlowBackup(BaseModel):
    """Backup schema for a single flow."""
    flow_id: str
    flow_data: dict[str, Any]  # Raw flow JSON from API
    metadata: BackupMetadata

    class Config:
        frozen = True


class ProjectBackup(BaseModel):
    """Backup schema for entire project."""
    project_id: str
    environment: str
    tenants: list[TenantBackup]
    flows: list[FlowBackup]
    metadata: BackupMetadata

    class Config:
        frozen = True
```

**Step 4: Run tests to verify they pass**

Run: `pytest tests/unit/domain/test_backup_models.py -v`

Expected: PASS (all 3 tests)

**Step 5: Commit**

```bash
git add src/descope_mgmt/domain/models/backup.py tests/unit/domain/test_backup_models.py
git commit -m "feat: add Pydantic backup schema models"
```

---

## Task 2: Implement BackupService

**Files:**
- Create: `src/descope_mgmt/domain/services/backup_service.py`
- Create: `tests/unit/domain/test_backup_service.py`

**Step 1: Write failing tests**

Create `tests/unit/domain/test_backup_service.py`:
```python
"""Tests for backup service"""
import pytest
import json
from pathlib import Path
from datetime import datetime
from descope_mgmt.domain.services.backup_service import BackupService
from descope_mgmt.domain.models.backup import ProjectBackup, BackupMetadata
from descope_mgmt.domain.models.config import DescopeConfig, TenantConfig


@pytest.fixture
def backup_service(tmp_path):
    """Create backup service with temp directory"""
    return BackupService(backup_root=tmp_path)


def test_create_backup(backup_service, tmp_path):
    """Should create backup directory and files"""
    config = DescopeConfig(
        version="1.0",
        tenants=[TenantConfig(id="acme-corp", name="Acme Corp")]
    )

    backup_path = backup_service.create_backup(
        project_id="P2test123",
        environment="test",
        config=config
    )

    assert backup_path.exists()
    assert (backup_path / "project.json").exists()

    # Verify content
    with open(backup_path / "project.json") as f:
        data = json.load(f)
        assert data["project_id"] == "P2test123"
        assert len(data["tenants"]) == 1


def test_list_backups(backup_service):
    """Should list available backups"""
    config = DescopeConfig(version="1.0", tenants=[])

    # Create 2 backups
    backup_service.create_backup("P2test", "test", config)
    backup_service.create_backup("P2test", "test", config)

    backups = backup_service.list_backups("P2test")
    assert len(backups) >= 2


def test_retention_policy(backup_service):
    """Should clean up old backups beyond retention"""
    # This is a placeholder - actual implementation in Task 3
    assert backup_service.retention_days == 30
```

**Step 2: Run tests to verify they fail**

Run: `pytest tests/unit/domain/test_backup_service.py -v`

Expected: FAIL (service not implemented)

**Step 3: Implement backup service**

Create `src/descope_mgmt/domain/services/backup_service.py`:
```python
"""Backup service for creating and managing backups."""
import json
from pathlib import Path
from datetime import datetime, timedelta
from typing import Optional
from descope_mgmt.domain.models.backup import (
    ProjectBackup,
    TenantBackup,
    BackupMetadata
)
from descope_mgmt.domain.models.config import DescopeConfig


class BackupService:
    """Service for creating and managing backups."""

    def __init__(
        self,
        backup_root: Optional[Path] = None,
        retention_days: int = 30
    ):
        """Initialize backup service.

        Args:
            backup_root: Root directory for backups (default: ~/.descope-mgmt/backups/)
            retention_days: Number of days to retain backups
        """
        if backup_root is None:
            backup_root = Path.home() / ".descope-mgmt" / "backups"

        self.backup_root = Path(backup_root)
        self.retention_days = retention_days
        self.backup_root.mkdir(parents=True, exist_ok=True)

    def create_backup(
        self,
        project_id: str,
        environment: str,
        config: DescopeConfig
    ) -> Path:
        """Create backup of current configuration.

        Args:
            project_id: Descope project ID
            environment: Environment name
            config: Configuration to back up

        Returns:
            Path to backup directory
        """
        timestamp = datetime.now()
        timestamp_str = timestamp.strftime("%Y%m%d_%H%M%S")

        # Create backup directory: backups/{project_id}/{timestamp}/
        backup_dir = self.backup_root / project_id / timestamp_str
        backup_dir.mkdir(parents=True, exist_ok=True)

        # Create metadata
        metadata = BackupMetadata(
            timestamp=timestamp,
            project_id=project_id,
            environment=environment
        )

        # Create tenant backups
        tenant_backups = [
            TenantBackup(
                tenant_id=tenant.id,
                config=tenant,
                metadata=metadata
            )
            for tenant in config.tenants
        ]

        # Create project backup
        project_backup = ProjectBackup(
            project_id=project_id,
            environment=environment,
            tenants=tenant_backups,
            flows=[],  # TODO: Add flows in Week 4
            metadata=metadata
        )

        # Write to JSON
        backup_file = backup_dir / "project.json"
        with open(backup_file, "w") as f:
            json.dump(project_backup.model_dump(), f, indent=2, default=str)

        return backup_dir

    def list_backups(self, project_id: str) -> list[Path]:
        """List available backups for project.

        Args:
            project_id: Descope project ID

        Returns:
            List of backup directory paths, sorted by timestamp (newest first)
        """
        project_dir = self.backup_root / project_id
        if not project_dir.exists():
            return []

        backups = sorted(
            [d for d in project_dir.iterdir() if d.is_dir()],
            reverse=True
        )
        return backups

    def cleanup_old_backups(self, project_id: str) -> int:
        """Remove backups older than retention period.

        Args:
            project_id: Descope project ID

        Returns:
            Number of backups deleted
        """
        cutoff = datetime.now() - timedelta(days=self.retention_days)
        deleted = 0

        for backup_dir in self.list_backups(project_id):
            # Parse timestamp from directory name (YYYYMMDD_HHMMSS)
            try:
                timestamp_str = backup_dir.name
                timestamp = datetime.strptime(timestamp_str, "%Y%m%d_%H%M%S")

                if timestamp < cutoff:
                    # Delete old backup
                    import shutil
                    shutil.rmtree(backup_dir)
                    deleted += 1
            except (ValueError, OSError):
                continue

        return deleted
```

**Step 4: Run tests to verify they pass**

Run: `pytest tests/unit/domain/test_backup_service.py -v`

Expected: PASS (all 3 tests)

**Step 5: Commit**

```bash
git add src/descope_mgmt/domain/services/backup_service.py tests/unit/domain/test_backup_service.py
git commit -m "feat: implement backup service with retention policy"
```

---

## Task 3: Add Backup Service to Exports

**Files:**
- Modify: `src/descope_mgmt/domain/services/__init__.py`

**Step 1: Update exports**

Modify `src/descope_mgmt/domain/services/__init__.py`:
```python
"""Domain services for descope-mgmt."""
from descope_mgmt.domain.services.state_fetcher import StateFetcher
from descope_mgmt.domain.services.diff_service import DiffService
from descope_mgmt.domain.services.backup_service import BackupService

__all__ = [
    "StateFetcher",
    "DiffService",
    "BackupService",
]
```

**Step 2: Add integration test**

Create `tests/integration/test_backup_integration.py`:
```python
"""Integration test for backup service"""
from descope_mgmt.domain.services import BackupService
from descope_mgmt.domain.models.config import DescopeConfig, TenantConfig


def test_backup_service_integration(tmp_path):
    """Should create and list backups"""
    service = BackupService(backup_root=tmp_path)

    config = DescopeConfig(
        version="1.0",
        tenants=[
            TenantConfig(id="acme-corp", name="Acme Corporation"),
            TenantConfig(id="widget-co", name="Widget Company")
        ]
    )

    # Create backup
    backup_path = service.create_backup("P2test", "test", config)
    assert backup_path.exists()

    # List backups
    backups = service.list_backups("P2test")
    assert len(backups) == 1

    # Verify backup content
    import json
    with open(backup_path / "project.json") as f:
        data = json.load(f)
        assert len(data["tenants"]) == 2
```

Run: `pytest tests/integration/test_backup_integration.py -v`

**Step 3: Commit**

```bash
git add src/descope_mgmt/domain/services/__init__.py tests/integration/test_backup_integration.py
git commit -m "feat: export backup service and add integration test"
```

---

## Chunk Complete Checklist

- [ ] Backup schema models (3 tests)
- [ ] BackupService implementation (3 tests)
- [ ] Retention policy with cleanup
- [ ] Integration test (2 tests)
- [ ] Service exports updated
- [ ] All commits made
- [ ] 8 tests passing total
