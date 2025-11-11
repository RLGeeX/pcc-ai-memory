# Chunk 3: Confirmation Prompts & Safety

**Status:** pending
**Dependencies:** chunk-001, chunk-002
**Estimated Time:** 30-45 minutes

---

## Task 1: Enhance Confirmation Prompts

**Files:**
- Modify: `src/descope_mgmt/cli/common.py`
- Create: `tests/unit/cli/test_confirmation.py`

**Step 1: Write failing tests**

Create `tests/unit/cli/test_confirmation.py`:
```python
"""Tests for confirmation prompt enhancements"""
import pytest
from unittest.mock import patch
from descope_mgmt.cli.common import confirm_destructive_operation


def test_confirm_destructive_delete_tenant():
    """Should show tenant details in confirmation"""
    with patch('click.confirm', return_value=True) as mock_confirm:
        result = confirm_destructive_operation(
            operation="delete",
            resource_type="tenant",
            resource_id="acme-corp",
            details={"name": "Acme Corporation", "domains": ["acme.com"]}
        )

        assert result is True
        # Should have been called with detailed message
        call_args = mock_confirm.call_args[0][0]
        assert "acme-corp" in call_args
        assert "Acme Corporation" in call_args


def test_confirm_destructive_auto_yes():
    """Should skip confirmation if yes=True"""
    result = confirm_destructive_operation(
        operation="delete",
        resource_type="tenant",
        resource_id="test",
        yes=True
    )

    assert result is True  # Auto-approved


def test_confirm_destructive_user_rejects():
    """Should return False if user rejects"""
    with patch('click.confirm', return_value=False) as mock_confirm:
        result = confirm_destructive_operation(
            operation="delete",
            resource_type="tenant",
            resource_id="test"
        )

        assert result is False
```

**Step 2: Run tests to verify they fail**

Run: `pytest tests/unit/cli/test_confirmation.py -v`

Expected: FAIL (enhanced function not implemented)

**Step 3: Enhance confirmation function**

Modify `src/descope_mgmt/cli/common.py`:
```python
# Update the existing confirm_destructive_operation function

def confirm_destructive_operation(
    operation: str,
    resource_type: str,
    resource_id: str,
    details: dict | None = None,
    yes: bool = False
) -> bool:
    """Confirm destructive operation with details.

    Args:
        operation: Operation type (delete, update)
        resource_type: Type of resource (tenant, flow)
        resource_id: Resource identifier
        details: Additional details to show
        yes: Skip confirmation if True

    Returns:
        True if confirmed, False otherwise
    """
    if yes:
        return True

    # Build detailed message
    message = f"\n⚠️  {operation.upper()} {resource_type}: {resource_id}\n"

    if details:
        message += "\nDetails:\n"
        for key, value in details.items():
            message += f"  {key}: {value}\n"

    message += f"\nThis operation cannot be undone. Continue?"

    return click.confirm(message, default=False)
```

**Step 4: Run tests to verify they pass**

Run: `pytest tests/unit/cli/test_confirmation.py -v`

Expected: PASS (all 3 tests)

**Step 5: Commit**

```bash
git add src/descope_mgmt/cli/common.py tests/unit/cli/test_confirmation.py
git commit -m "feat: enhance confirmation prompts with resource details"
```

---

## Task 2: Auto-Backup Before Destructive Operations

**Files:**
- Create: `src/descope_mgmt/cli/safety.py`
- Create: `tests/unit/cli/test_safety.py`

**Step 1: Write failing test**

Create `tests/unit/cli/test_safety.py`:
```python
"""Tests for safety mechanisms"""
import pytest
from unittest.mock import Mock, patch
from descope_mgmt.cli.safety import safe_destructive_operation
from descope_mgmt.domain.models.config import DescopeConfig, TenantConfig


def test_auto_backup_before_delete(tmp_path):
    """Should create backup before destructive operation"""
    config = DescopeConfig(
        version="1.0",
        tenants=[TenantConfig(id="acme-corp", name="Acme Corp")]
    )

    # Mock operation
    operation_mock = Mock(return_value=True)

    with patch('descope_mgmt.cli.safety.BackupService') as mock_backup_class:
        mock_backup_service = Mock()
        mock_backup_service.create_backup.return_value = tmp_path / "backup"
        mock_backup_class.return_value = mock_backup_service

        result = safe_destructive_operation(
            operation=operation_mock,
            project_id="P2test",
            environment="test",
            config=config,
            operation_name="delete tenant"
        )

        # Should have created backup
        assert mock_backup_service.create_backup.called
        # Should have executed operation
        assert operation_mock.called
        assert result is True
```

**Step 2: Run test to verify it fails**

Run: `pytest tests/unit/cli/test_safety.py -v`

Expected: FAIL (module not found)

**Step 3: Implement safety wrapper**

Create `src/descope_mgmt/cli/safety.py`:
```python
"""Safety mechanisms for destructive operations."""
from typing import Callable, Any
from pathlib import Path
import structlog
from descope_mgmt.domain.services import BackupService
from descope_mgmt.domain.models.config import DescopeConfig

logger = structlog.get_logger()


def safe_destructive_operation(
    operation: Callable[[], Any],
    project_id: str,
    environment: str,
    config: DescopeConfig,
    operation_name: str,
    backup_root: Path | None = None
) -> Any:
    """Execute destructive operation with automatic backup.

    Args:
        operation: Function to execute
        project_id: Descope project ID
        environment: Environment name
        config: Current configuration
        operation_name: Human-readable operation name
        backup_root: Optional backup directory

    Returns:
        Result of operation
    """
    # Create backup before operation
    backup_service = BackupService(backup_root=backup_root)

    logger.info(
        "creating_backup_before_operation",
        operation=operation_name,
        project_id=project_id,
        environment=environment
    )

    backup_path = backup_service.create_backup(
        project_id=project_id,
        environment=environment,
        config=config
    )

    logger.info(
        "backup_created",
        backup_path=str(backup_path)
    )

    # Execute operation
    try:
        result = operation()
        logger.info(
            "operation_completed",
            operation=operation_name
        )
        return result
    except Exception as e:
        logger.error(
            "operation_failed",
            operation=operation_name,
            error=str(e),
            backup_path=str(backup_path)
        )
        raise
```

**Step 4: Run test to verify it passes**

Run: `pytest tests/unit/cli/test_safety.py -v`

Expected: PASS (1 test)

**Step 5: Commit**

```bash
git add src/descope_mgmt/cli/safety.py tests/unit/cli/test_safety.py
git commit -m "feat: add auto-backup before destructive operations"
```

---

## Chunk Complete Checklist

- [ ] Enhanced confirmation prompts (3 tests)
- [ ] Auto-backup safety wrapper (1 test)
- [ ] Detailed resource information in prompts
- [ ] --yes flag support
- [ ] All commits made
- [ ] 4 tests passing total
