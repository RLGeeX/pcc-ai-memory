# Chunk 4: Tenant Delete Manager Logic

**Status:** pending
**Dependencies:** none (can run parallel with chunk-006)
**Complexity:** simple
**Estimated Time:** 10 minutes
**Tasks:** 2
**Phase:** Delete Commands
**Jira:** PCC-253

---

## Task 1: Add Delete with Backup to TenantManager

**Agent:** python-pro
**Files:**
- Modify: `src/descope_mgmt/domain/tenant_manager.py`
- Modify: `tests/unit/domain/test_tenant_manager.py`

**Step 1: Add tests for delete with backup**

Add to `tests/unit/domain/test_tenant_manager.py`:

```python
from unittest.mock import MagicMock, patch
from pathlib import Path

from descope_mgmt.domain.backup_service import BackupService


class TestTenantManagerDelete:
    """Tests for TenantManager delete operations."""

    def test_delete_tenant_creates_backup(self, fake_client: FakeDescopeClient) -> None:
        """Test delete creates backup before deletion."""
        # Setup tenant
        tenant = TenantConfig(id="tenant-1", name="Test", domains=["test.com"])
        fake_client.tenants["tenant-1"] = tenant

        with patch.object(BackupService, "create_tenant_backup") as mock_backup:
            mock_backup.return_value = Path("/backups/tenant-1.json")

            manager = TenantManager(fake_client)
            backup_path = manager.delete_tenant_with_backup("tenant-1")

            mock_backup.assert_called_once()
            assert backup_path == Path("/backups/tenant-1.json")
            assert "tenant-1" not in fake_client.tenants

    def test_delete_tenant_not_found(self, fake_client: FakeDescopeClient) -> None:
        """Test delete raises error for missing tenant."""
        manager = TenantManager(fake_client)

        with pytest.raises(ValueError, match="Tenant not found"):
            manager.delete_tenant_with_backup("nonexistent")

    def test_delete_tenant_returns_backup_path(
        self, fake_client: FakeDescopeClient
    ) -> None:
        """Test delete returns the backup file path."""
        tenant = TenantConfig(id="tenant-1", name="Test", domains=[])
        fake_client.tenants["tenant-1"] = tenant

        with patch.object(BackupService, "create_tenant_backup") as mock_backup:
            mock_backup.return_value = Path("/tmp/backup.json")

            manager = TenantManager(fake_client)
            result = manager.delete_tenant_with_backup("tenant-1")

            assert result == Path("/tmp/backup.json")
```

**Step 2: Run tests to verify they fail**

```bash
pytest tests/unit/domain/test_tenant_manager.py::TestTenantManagerDelete -v
```

Expected: FAIL (delete_tenant_with_backup not found)

**Step 3: Implement delete_tenant_with_backup**

Add to `src/descope_mgmt/domain/tenant_manager.py`:

```python
from pathlib import Path
from descope_mgmt.domain.backup_service import BackupService


class TenantManager:
    """Manager for tenant operations."""

    # ... existing methods ...

    def delete_tenant_with_backup(
        self,
        tenant_id: str,
        backup_service: BackupService | None = None,
    ) -> Path:
        """Delete a tenant after creating a backup.

        Args:
            tenant_id: ID of tenant to delete.
            backup_service: Optional backup service (creates default if None).

        Returns:
            Path to the backup file.

        Raises:
            ValueError: If tenant not found.
        """
        # Get tenant first (validates existence)
        tenant = self.get_tenant(tenant_id)
        if tenant is None:
            raise ValueError(f"Tenant not found: {tenant_id}")

        # Create backup
        if backup_service is None:
            backup_service = BackupService()

        backup_path = backup_service.create_tenant_backup(
            tenant=tenant,
            operation="tenant-delete",
            description=f"Backup before deleting tenant {tenant_id}",
        )

        # Delete tenant
        self.delete_tenant(tenant_id)

        return backup_path
```

**Step 4: Run tests to verify they pass**

```bash
pytest tests/unit/domain/test_tenant_manager.py -v
```

Expected: PASS

**Step 5: Commit**

```bash
git add src/descope_mgmt/domain/tenant_manager.py tests/unit/domain/test_tenant_manager.py
git commit -m "feat(tenant): add delete_tenant_with_backup method"
```

---

## Task 2: Add Audit Logging to Delete

**Agent:** python-pro
**Files:**
- Modify: `src/descope_mgmt/domain/tenant_manager.py`
- Modify: `tests/unit/domain/test_tenant_manager.py`

**Step 1: Add tests for audit logging on delete**

```python
from descope_mgmt.domain.audit_logger import AuditLogger
from descope_mgmt.types.audit import AuditOperation


class TestTenantManagerDeleteAudit:
    """Tests for delete audit logging."""

    def test_delete_logs_audit_entry(self, fake_client: FakeDescopeClient) -> None:
        """Test delete logs audit entry on success."""
        tenant = TenantConfig(id="tenant-1", name="Test", domains=[])
        fake_client.tenants["tenant-1"] = tenant

        with patch.object(AuditLogger, "log") as mock_log:
            with patch.object(BackupService, "create_tenant_backup") as mock_backup:
                mock_backup.return_value = Path("/tmp/backup.json")

                manager = TenantManager(fake_client)
                manager.delete_tenant_with_backup("tenant-1", audit_logger=mock_log)

                # Verify audit was called
                mock_log.assert_called_once()
                call_args = mock_log.call_args[0][0]
                assert call_args.operation == AuditOperation.TENANT_DELETE
                assert call_args.resource_id == "tenant-1"
                assert call_args.success is True
```

**Step 2: Run test to verify it fails**

```bash
pytest tests/unit/domain/test_tenant_manager.py::TestTenantManagerDeleteAudit -v
```

Expected: FAIL

**Step 3: Add audit logging parameter**

Update `delete_tenant_with_backup` signature:

```python
from descope_mgmt.domain.audit_logger import AuditLogger
from descope_mgmt.types.audit import AuditEntry, AuditOperation


def delete_tenant_with_backup(
    self,
    tenant_id: str,
    backup_service: BackupService | None = None,
    audit_logger: AuditLogger | None = None,
) -> Path:
    """Delete a tenant after creating a backup.

    Args:
        tenant_id: ID of tenant to delete.
        backup_service: Optional backup service.
        audit_logger: Optional audit logger for recording operation.

    Returns:
        Path to the backup file.

    Raises:
        ValueError: If tenant not found.
    """
    tenant = self.get_tenant(tenant_id)
    if tenant is None:
        raise ValueError(f"Tenant not found: {tenant_id}")

    if backup_service is None:
        backup_service = BackupService()

    backup_path = backup_service.create_tenant_backup(
        tenant=tenant,
        operation="tenant-delete",
        description=f"Backup before deleting tenant {tenant_id}",
    )

    self.delete_tenant(tenant_id)

    # Log audit entry
    if audit_logger:
        from datetime import datetime, UTC
        entry = AuditEntry(
            timestamp=datetime.now(UTC),
            operation=AuditOperation.TENANT_DELETE,
            resource_id=tenant_id,
            success=True,
            details={"backup_path": str(backup_path)},
        )
        audit_logger.log(entry)

    return backup_path
```

**Step 4: Run tests to verify they pass**

```bash
pytest tests/unit/domain/test_tenant_manager.py -v
```

Expected: PASS

**Step 5: Commit**

```bash
git add src/descope_mgmt/domain/tenant_manager.py tests/unit/domain/test_tenant_manager.py
git commit -m "feat(tenant): add audit logging to delete operation"
```

---

## Chunk Complete Checklist

- [ ] delete_tenant_with_backup implemented
- [ ] Automatic backup before deletion
- [ ] Audit logging integration
- [ ] All tests passing
- [ ] Code committed
- [ ] Ready for next chunk
