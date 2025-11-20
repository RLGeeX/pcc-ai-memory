# Chunk 6: Restore Service and Tenant Sync Apply

**Status:** pending
**Dependencies:** chunk-005-backup-service
**Complexity:** medium
**Estimated Time:** 60 minutes
**Tasks:** 3

---

## Context

This chunk completes Week 3 by implementing restore functionality and the `tenant sync --apply` mode. This enables users to:
1. Restore tenants from backups (undo destructive operations)
2. Sync tenants declaratively from YAML config (--dry-run to preview, --apply to execute)

**Workflow:**
```bash
# Preview changes
descope-mgmt tenant sync --config tenants.yaml --dry-run

# Apply changes (with automatic backup)
descope-mgmt tenant sync --config tenants.yaml --apply
```

---

## Task 1: Implement Restore Service

**Agent:** python-pro

**Files:**
- Create: `src/descope_mgmt/domain/restore_service.py`
- Create: `tests/unit/domain/test_restore_service.py`

**Step 1: Write failing tests**

Create `tests/unit/domain/test_restore_service.py`:

```python
"""Tests for restore service."""

import json
from pathlib import Path

import pytest

from descope_mgmt.domain.restore_service import RestoreService
from descope_mgmt.types.backup import BackupMetadata, TenantBackup
from descope_mgmt.types.tenant import TenantConfig
from descope_mgmt.types.exceptions import ConfigError


def test_restore_tenant_from_backup(tmp_path: Path) -> None:
    """Test restoring tenant from backup file."""
    # Create backup file
    tenant = TenantConfig(id="acme", name="ACME Corp", domains=["acme.com"])
    metadata = BackupMetadata(
        timestamp="2025-11-17T10:30:00",
        operation="tenant-delete",
        target_id="acme",
    )
    backup = TenantBackup(metadata=metadata, tenant=tenant)

    backup_file = tmp_path / "backup.json"
    backup_file.write_text(json.dumps(backup.model_dump(mode="json")))

    # Restore from backup
    service = RestoreService()
    restored_tenant = service.load_backup(backup_file)

    assert restored_tenant.id == "acme"
    assert restored_tenant.name == "ACME Corp"
    assert restored_tenant.domains == ["acme.com"]


def test_restore_from_invalid_backup_raises_error(tmp_path: Path) -> None:
    """Test restoring from invalid backup raises error."""
    backup_file = tmp_path / "invalid.json"
    backup_file.write_text("{invalid json")

    service = RestoreService()

    with pytest.raises(ConfigError, match="Invalid backup file"):
        service.load_backup(backup_file)


def test_list_available_backups(tmp_path: Path) -> None:
    """Test listing available backups for a tenant."""
    # Create multiple backup files
    for i in range(3):
        tenant = TenantConfig(id="acme", name=f"ACME {i}")
        metadata = BackupMetadata(
            timestamp=f"2025-11-17T10:3{i}:00",
            operation="update",
            target_id="acme",
        )
        backup = TenantBackup(metadata=metadata, tenant=tenant)
        backup_file = tmp_path / f"2025-11-17T10-3{i}-00_update_acme.json"
        backup_file.write_text(json.dumps(backup.model_dump(mode="json")))

    service = RestoreService(backup_dir=tmp_path)
    backups = service.list_backups_for_tenant("acme")

    assert len(backups) == 3


def test_get_latest_backup(tmp_path: Path) -> None:
    """Test getting most recent backup for a tenant."""
    # Create backups with different timestamps
    for i in range(3):
        tenant = TenantConfig(id="acme", name=f"ACME {i}")
        metadata = BackupMetadata(
            timestamp=f"2025-11-17T10:3{i}:00",
            operation="update",
            target_id="acme",
        )
        backup = TenantBackup(metadata=metadata, tenant=tenant)
        backup_file = tmp_path / f"2025-11-17T10-3{i}-00_update_acme.json"
        backup_file.write_text(json.dumps(backup.model_dump(mode="json")))

    service = RestoreService(backup_dir=tmp_path)
    latest = service.get_latest_backup("acme")

    assert latest is not None
    # Latest should be 10:32 (index 2)
    restored = service.load_backup(latest)
    assert restored.name == "ACME 2"
```

**Step 2: Implement RestoreService**

Create `src/descope_mgmt/domain/restore_service.py`:

```python
"""Restore service for recovering from backup snapshots."""

import json
from pathlib import Path

from pydantic import ValidationError

from descope_mgmt.types.backup import TenantBackup
from descope_mgmt.types.exceptions import ConfigError
from descope_mgmt.types.tenant import TenantConfig


class RestoreService:
    """Service for restoring tenant configurations from backups."""

    def __init__(self, backup_dir: Path | None = None) -> None:
        """Initialize restore service.

        Args:
            backup_dir: Directory containing backup files (default: ~/.descope-mgmt/backups)
        """
        self.backup_dir = backup_dir or Path.home() / ".descope-mgmt" / "backups"

    def load_backup(self, backup_file: Path) -> TenantConfig:
        """Load tenant configuration from backup file.

        Args:
            backup_file: Path to backup JSON file

        Returns:
            Restored tenant configuration

        Raises:
            ConfigError: If backup file is invalid or corrupted
        """
        try:
            backup_data = json.loads(backup_file.read_text())
            backup = TenantBackup.model_validate(backup_data)
            return backup.tenant
        except json.JSONDecodeError as e:
            raise ConfigError(f"Invalid backup file (malformed JSON): {e}")
        except ValidationError as e:
            raise ConfigError(f"Invalid backup file (validation failed): {e}")
        except FileNotFoundError:
            raise ConfigError(f"Backup file not found: {backup_file}")

    def list_backups_for_tenant(self, tenant_id: str) -> list[Path]:
        """List all backup files for a specific tenant.

        Args:
            tenant_id: Tenant ID to filter backups

        Returns:
            List of backup file paths, sorted by timestamp (newest first)
        """
        pattern = f"*_{tenant_id}.json"
        backups = sorted(
            self.backup_dir.glob(pattern),
            key=lambda p: p.stat().st_mtime,
            reverse=True,
        )
        return backups

    def get_latest_backup(self, tenant_id: str) -> Path | None:
        """Get the most recent backup for a tenant.

        Args:
            tenant_id: Tenant ID

        Returns:
            Path to latest backup file, or None if no backups exist
        """
        backups = self.list_backups_for_tenant(tenant_id)
        return backups[0] if backups else None
```

**Step 3: Run tests to verify pass**

Run: `pytest tests/unit/domain/test_restore_service.py -v`
Expected: All 5 tests PASS

**Step 4: Commit**

```bash
git add src/descope_mgmt/domain/restore_service.py tests/unit/domain/test_restore_service.py
git commit -m "feat: implement restore service

- Create RestoreService for loading backups
- Support listing backups by tenant ID
- Add get_latest_backup for quick recovery
- Handle invalid/corrupted backup files gracefully
- Add comprehensive tests for restore operations"
```

---

## Task 2: Add Tenant Sync Command

**Agent:** python-pro

**Files:**
- Modify: `src/descope_mgmt/cli/tenant_cmds.py:200-300` (add sync command)
- Modify: `tests/unit/cli/test_tenant_cmds.py` (add sync tests)

**Step 1: Write failing tests**

Add to `tests/unit/cli/test_tenant_cmds.py`:

```python
def test_tenant_sync_dry_run(cli_runner, tmp_path: Path):
    """Test tenant sync with --dry-run flag."""
    # Create config file
    config_file = tmp_path / "tenants.yaml"
    config_file.write_text("""
tenants:
  - id: test-tenant
    name: Test Tenant
""")

    result = cli_runner.invoke(
        cli,
        ["tenant", "sync", "--config", str(config_file), "--dry-run"],
    )

    assert result.exit_code == 0
    assert "DRY RUN" in result.output or "Preview" in result.output


def test_tenant_sync_apply(cli_runner, tmp_path: Path):
    """Test tenant sync with --apply flag."""
    config_file = tmp_path / "tenants.yaml"
    config_file.write_text("""
tenants:
  - id: test-tenant
    name: Test Tenant
""")

    result = cli_runner.invoke(
        cli,
        ["tenant", "sync", "--config", str(config_file), "--apply"],
    )

    assert result.exit_code == 0
    assert "created" in result.output.lower() or "synchronized" in result.output.lower()


def test_tenant_sync_requires_config_file(cli_runner):
    """Test sync requires --config option."""
    result = cli_runner.invoke(cli, ["tenant", "sync"])

    assert result.exit_code != 0
    assert "Missing option" in result.output or "--config" in result.output
```

**Step 2: Implement tenant sync command**

Add to `src/descope_mgmt/cli/tenant_cmds.py`:

```python
from pathlib import Path
from rich.table import Table

from descope_mgmt.domain.backup_service import BackupService
from descope_mgmt.domain.config_loader import ConfigLoader


@tenant_group.command(name="sync")
@click.option("--config", "config_file", required=True, type=click.Path(exists=True), help="Path to tenants.yaml file")
@click.option("--dry-run", is_flag=True, help="Preview changes without applying")
@click.option("--apply", "apply_changes", is_flag=True, help="Apply changes to Descope")
@click.pass_obj
def tenant_sync(cli_ctx: CliContext, config_file: str, dry_run: bool, apply_changes: bool) -> None:
    """Synchronize tenants from configuration file.

    Compares current Descope state with configuration and shows/applies differences.
    """
    if not dry_run and not apply_changes:
        console.print("[yellow]Specify --dry-run to preview or --apply to execute changes[/yellow]")
        raise click.Abort()

    try:
        # Load tenant configuration
        loader = ConfigLoader()
        config = loader.load_tenants_from_yaml(Path(config_file))

        # Get current state
        client = ClientFactory.create_client()
        manager = TenantManager(client)
        current_tenants = {t.id: t for t in manager.list_tenants()}

        # Calculate changes
        to_create = [t for t in config.tenants if t.id not in current_tenants]
        to_update = [t for t in config.tenants if t.id in current_tenants and t != current_tenants[t.id]]
        to_delete = []  # We don't delete tenants not in config (safety)

        # Display changes
        if dry_run:
            console.print("[bold]DRY RUN - Preview of changes:[/bold]\n")

        table = Table(title="Tenant Sync Plan")
        table.add_column("Action", style="cyan")
        table.add_column("Tenant ID", style="yellow")
        table.add_column("Name")

        for tenant in to_create:
            table.add_row("CREATE", tenant.id, tenant.name)
        for tenant in to_update:
            table.add_row("UPDATE", tenant.id, tenant.name)

        console.print(table)
        console.print(f"\n[bold]Summary:[/bold] {len(to_create)} to create, {len(to_update)} to update\n")

        # Apply changes if requested
        if apply_changes:
            backup_service = BackupService()

            # Create backups for tenants being updated
            for tenant in to_update:
                backup_service.create_tenant_backup(
                    current_tenants[tenant.id],
                    "sync-apply",
                    f"Before sync apply for {tenant.id}",
                )

            # Apply creates
            for tenant in to_create:
                manager.create_tenant(tenant)
                console.print(f"[green]✓[/green] Created tenant: {tenant.id}")

            # Apply updates
            for tenant in to_update:
                manager.update_tenant(tenant)
                console.print(f"[green]✓[/green] Updated tenant: {tenant.id}")

            console.print(f"\n[bold green]Sync complete![/bold green]")

    except Exception as e:
        console.print(f"[red]Error:[/red] {e}")
        raise click.Abort()
```

**Step 3: Run tests to verify pass**

Run: `pytest tests/unit/cli/test_tenant_cmds.py::test_tenant_sync -v`
Expected: All 3 sync tests PASS

**Step 4: Commit**

```bash
git add src/descope_mgmt/cli/tenant_cmds.py tests/unit/cli/test_tenant_cmds.py
git commit -m "feat: add tenant sync command

- Implement tenant sync with --dry-run and --apply modes
- Calculate diff between config file and current state
- Auto-backup tenants before updates
- Show preview table with planned changes
- Add comprehensive tests for sync workflow"
```

---

## Task 3: Update Main CLI to Register Sync Command

**Agent:** python-pro

**Files:**
- Modify: `src/descope_mgmt/cli/main.py:50-60` (ensure sync registered)
- Run manual verification

**Step 1: Verify sync command registered**

Check `src/descope_mgmt/cli/main.py`:

```python
# Ensure tenant_group is registered
cli.add_command(tenant_group)
```

**Step 2: Run manual verification**

Run: `descope-mgmt tenant sync --help`
Expected: Help text displays for sync command

**Step 3: Run full test suite**

Run: `pytest tests/ -v --cov=src/descope_mgmt --cov-report=term-missing`
Expected: 152+ tests PASS, coverage ≥90%

**Step 4: Final commit**

```bash
git add src/descope_mgmt/cli/main.py
git commit -m "chore: verify tenant sync command registration

- Confirm sync command registered in main CLI
- All Week 3 commands now available
- Full test suite passing (152+ tests)"
```

---

## Chunk Complete Checklist

- [ ] RestoreService implemented (Task 1)
- [ ] Tenant sync command added (Task 2)
- [ ] Main CLI updated and verified (Task 3)
- [ ] All tests passing (152+ total, +10 from chunk)
- [ ] Coverage ≥90%
- [ ] mypy, ruff, lint-imports passing
- [ ] 3 commits pushed
- [ ] **Week 3 COMPLETE**

---

## Week 3 Summary

### Deliverables Complete ✅
1. ✅ Client factory pattern (eliminated code duplication)
2. ✅ YAML-based tenant configuration (tenants.yaml)
3. ✅ Real Descope API integration (tenants + flows)
4. ✅ Backup service (automatic snapshots)
5. ✅ Restore service (recovery from backups)
6. ✅ Tenant sync command (--dry-run and --apply)

### Commands Now Available
```bash
# Tenant sync workflow
descope-mgmt tenant sync --config tenants.yaml --dry-run
descope-mgmt tenant sync --config tenants.yaml --apply

# All previous commands still work
descope-mgmt tenant list/create/update/delete
descope-mgmt flow list/deploy
```

### Technical Debt Resolved
- ✅ Code duplication (6 locations → centralized factory)
- ✅ Local import anti-pattern (TenantConfig)
- ⚠️ Flow type validation (deferred to Week 4)
- ⚠️ Tenant filter in flow list (deferred to Week 4)

### Statistics
- **Tests:** 152+ (up from 109 in Week 2)
- **Coverage:** 90%+
- **Files Created:** 7 source + 7 test
- **Commits:** ~12 conventional commits

---

## Verification Commands

```bash
# Run full test suite
pytest tests/ -v --cov=src/descope_mgmt --cov-report=term-missing

# Quality checks
mypy src/
ruff check .
lint-imports

# Manual verification
descope-mgmt tenant sync --help
descope-mgmt --version

# Verify backup directory
ls -la ~/.descope-mgmt/backups/
```

**Expected:** All tests pass, all quality checks pass, sync command works, backup directory created.

---

## Next: Week 4

**Focus:** Safety & Observability
- Enhanced error messages with suggestions
- Progress indicators for batch operations
- Audit logging
- Validation improvements
