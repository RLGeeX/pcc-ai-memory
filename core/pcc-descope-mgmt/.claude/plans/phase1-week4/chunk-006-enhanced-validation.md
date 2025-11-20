# Chunk 6: Enhanced Validation

**Status:** pending
**Dependencies:** none
**Complexity:** medium
**Estimated Time:** 20 minutes
**Tasks:** 2

---

## Task 1: Add Pre-flight Validation for Sync Operations

**Agent:** python-pro
**Files:**
- Create: `src/descope_mgmt/domain/validators.py`
- Create: `tests/unit/domain/test_validators.py`
- Modify: `src/descope_mgmt/cli/tenant_cmds.py`

**Step 1: Write the failing test**

Create test file:

```python
"""Tests for validation utilities."""

from descope_mgmt.domain.validators import SyncValidator
from descope_mgmt.types.config import TenantConfig, TenantListConfig
from descope_mgmt.types.exceptions import ValidationError
from descope_mgmt.types.tenant import TenantResponse
import pytest


def test_validate_sync_operations_all_valid():
    """Test validation passes when all operations are valid."""
    desired = TenantListConfig(
        tenants=[
            TenantConfig(id="tenant-1", name="Tenant 1", selfProvisioningDomains=[]),
            TenantConfig(id="tenant-2", name="Tenant 2", selfProvisioningDomains=[]),
        ]
    )

    existing = [
        TenantResponse(id="tenant-1", name="Old Name"),
    ]

    validator = SyncValidator()

    # Should not raise
    validator.validate_sync_operations(desired, existing)


def test_validate_sync_operations_detects_id_conflicts():
    """Test validation detects conflicting tenant IDs."""
    desired = TenantListConfig(
        tenants=[
            TenantConfig(id="tenant-1", name="Tenant 1", selfProvisioningDomains=[]),
            TenantConfig(id="tenant-1", name="Duplicate", selfProvisioningDomains=[]),
        ]
    )

    existing: list[TenantResponse] = []

    validator = SyncValidator()

    with pytest.raises(ValidationError) as exc_info:
        validator.validate_sync_operations(desired, existing)

    assert "duplicate" in str(exc_info.value).lower()
    assert "tenant-1" in str(exc_info.value)


def test_validate_sync_operations_detects_domain_conflicts():
    """Test validation detects conflicting domains across tenants."""
    desired = TenantListConfig(
        tenants=[
            TenantConfig(
                id="tenant-1",
                name="Tenant 1",
                selfProvisioningDomains=["example.com"],
            ),
            TenantConfig(
                id="tenant-2",
                name="Tenant 2",
                selfProvisioningDomains=["example.com"],
            ),
        ]
    )

    existing: list[TenantResponse] = []

    validator = SyncValidator()

    with pytest.raises(ValidationError) as exc_info:
        validator.validate_sync_operations(desired, existing)

    assert "domain" in str(exc_info.value).lower()
    assert "example.com" in str(exc_info.value)


def test_validate_sync_operations_detects_missing_required_fields():
    """Test validation detects missing required fields."""
    desired = TenantListConfig(
        tenants=[
            TenantConfig(id="", name="No ID", selfProvisioningDomains=[]),
        ]
    )

    existing: list[TenantResponse] = []

    validator = SyncValidator()

    with pytest.raises(ValidationError) as exc_info:
        validator.validate_sync_operations(desired, existing)

    assert "required" in str(exc_info.value).lower() or "empty" in str(exc_info.value).lower()


def test_validate_backup_restore_operations():
    """Test validation for backup/restore operations."""
    validator = SyncValidator()

    # Valid backup
    validator.validate_backup_metadata(
        tenant_id="tenant-1",
        backup_path="/path/to/backup.json",
    )

    # Invalid backup - empty tenant ID
    with pytest.raises(ValidationError):
        validator.validate_backup_metadata(
            tenant_id="",
            backup_path="/path/to/backup.json",
        )

    # Invalid backup - nonexistent file
    with pytest.raises(ValidationError):
        validator.validate_backup_metadata(
            tenant_id="tenant-1",
            backup_path="/nonexistent/path.json",
        )
```

**Step 2: Run test to verify it fails**

```bash
pytest tests/unit/domain/test_validators.py -v
```

Expected: FAIL - "ModuleNotFoundError: No module named 'descope_mgmt.domain.validators'"

**Step 3: Write minimal implementation**

Create `src/descope_mgmt/domain/validators.py`:

```python
"""Validation utilities for operations."""

from pathlib import Path

from descope_mgmt.types.config import TenantListConfig
from descope_mgmt.types.exceptions import ValidationError
from descope_mgmt.types.tenant import TenantResponse


class SyncValidator:
    """Validator for sync operations with detailed error messages."""

    def validate_sync_operations(
        self,
        desired: TenantListConfig,
        existing: list[TenantResponse],
    ) -> None:
        """Validate sync operations before execution.

        Args:
            desired: Desired tenant configuration
            existing: Existing tenants from API

        Raises:
            ValidationError: If validation fails
        """
        # Check for duplicate IDs in desired config
        tenant_ids = [t.id for t in desired.tenants]
        duplicates = [tid for tid in tenant_ids if tenant_ids.count(tid) > 1]
        if duplicates:
            unique_dups = list(set(duplicates))
            raise ValidationError(
                f"Duplicate tenant IDs found in configuration: {unique_dups}. "
                f"Each tenant must have a unique ID."
            )

        # Check for duplicate domains across tenants
        all_domains: list[str] = []
        for tenant in desired.tenants:
            all_domains.extend(tenant.selfProvisioningDomains)

        duplicate_domains = [d for d in all_domains if all_domains.count(d) > 1]
        if duplicate_domains:
            unique_dup_domains = list(set(duplicate_domains))
            raise ValidationError(
                f"Duplicate domains found across tenants: {unique_dup_domains}. "
                f"Each domain can only belong to one tenant."
            )

        # Check for empty required fields
        for tenant in desired.tenants:
            if not tenant.id or tenant.id.strip() == "":
                raise ValidationError(
                    f"Tenant ID is required and cannot be empty. "
                    f"Found tenant with name: '{tenant.name}'"
                )

            if not tenant.name or tenant.name.strip() == "":
                raise ValidationError(
                    f"Tenant name is required and cannot be empty. "
                    f"Found tenant with ID: '{tenant.id}'"
                )

    def validate_backup_metadata(
        self,
        tenant_id: str,
        backup_path: str | Path,
    ) -> None:
        """Validate backup/restore operation metadata.

        Args:
            tenant_id: Tenant identifier
            backup_path: Path to backup file

        Raises:
            ValidationError: If validation fails
        """
        if not tenant_id or tenant_id.strip() == "":
            raise ValidationError("Tenant ID is required for backup operations")

        path = Path(backup_path)
        if not path.exists():
            raise ValidationError(
                f"Backup file not found: {backup_path}. "
                f"Ensure the file exists and the path is correct."
            )

        if not path.is_file():
            raise ValidationError(
                f"Backup path is not a file: {backup_path}. "
                f"Expected a JSON backup file."
            )
```

**Step 4: Run test to verify it passes**

```bash
pytest tests/unit/domain/test_validators.py -v
```

Expected: PASS - All 6 tests passing

**Step 5: Verify coverage**

```bash
pytest tests/unit/domain/test_validators.py --cov=src/descope_mgmt/domain/validators --cov-report=term-missing
```

Expected: 95%+ coverage

**Step 6: Commit**

```bash
git add src/descope_mgmt/domain/validators.py tests/unit/domain/test_validators.py
git commit -m "feat: add pre-flight validation for sync operations"
```

---

## Task 2: Integrate Validators into CLI Commands

**Agent:** python-pro
**Files:**
- Modify: `src/descope_mgmt/cli/tenant_cmds.py`
- Modify: `tests/unit/cli/test_tenant_cmds.py`

**Step 1: Write the failing test**

Add test to `tests/unit/cli/test_tenant_cmds.py`:

```python
def test_sync_tenants_validates_before_apply(
    runner: CliRunner,
    fake_client: FakeDescopeClient,
    tmp_path: Path,
) -> None:
    """Test that sync validates configuration before applying changes."""
    # Create config with duplicate tenant IDs
    config_file = tmp_path / "invalid.yaml"
    config_file.write_text("""
tenants:
  - id: tenant-1
    name: Tenant 1
    selfProvisioningDomains: []
  - id: tenant-1
    name: Duplicate
    selfProvisioningDomains: []
""")

    result = runner.invoke(
        cli_app,
        [
            "tenant",
            "sync",
            "--config",
            str(config_file),
            "--apply",
            "--project-id",
            "test",
            "--management-key",
            "test",
        ],
    )

    assert result.exit_code == 1
    assert "duplicate" in result.output.lower()
    assert "tenant-1" in result.output
    # Should show validation error with recovery suggestion
    assert "unique" in result.output.lower()


def test_sync_tenants_validation_shows_helpful_errors(
    runner: CliRunner,
    fake_client: FakeDescopeClient,
    tmp_path: Path,
) -> None:
    """Test that validation errors include helpful recovery suggestions."""
    # Create config with duplicate domains
    config_file = tmp_path / "invalid.yaml"
    config_file.write_text("""
tenants:
  - id: tenant-1
    name: Tenant 1
    selfProvisioningDomains: ["example.com"]
  - id: tenant-2
    name: Tenant 2
    selfProvisioningDomains: ["example.com"]
""")

    result = runner.invoke(
        cli_app,
        [
            "tenant",
            "sync",
            "--config",
            str(config_file),
            "--dry-run",
            "--project-id",
            "test",
            "--management-key",
            "test",
        ],
    )

    assert result.exit_code == 1
    assert "domain" in result.output.lower()
    assert "example.com" in result.output
```

**Step 2: Run test to verify it fails**

```bash
pytest tests/unit/cli/test_tenant_cmds.py::test_sync_tenants_validates_before_apply -v
pytest tests/unit/cli/test_tenant_cmds.py::test_sync_tenants_validation_shows_helpful_errors -v
```

Expected: FAIL - Validation not integrated

**Step 3: Update sync_tenants command to use validators**

Modify `src/descope_mgmt/cli/tenant_cmds.py`:

```python
# Add import
from descope_mgmt.domain.validators import SyncValidator

@tenant_app.command(name="sync")
def sync_tenants(
    ctx: typer.Context,
    config: Annotated[Path, typer.Option(...)],
    dry_run: Annotated[bool, typer.Option(...)] = True,
    apply: Annotated[bool, typer.Option(...)] = False,
    project_id: Annotated[str | None, typer.Option(...)] = None,
    management_key: Annotated[str | None, typer.Option(...)] = None,
) -> None:
    """Synchronize tenants from YAML configuration."""
    console = get_console()

    # ... existing mode validation ...

    try:
        client = ClientFactory.create_client(project_id, management_key)
        tenant_manager = TenantManager(client)
        backup_service = BackupService()
        validator = SyncValidator()

        # Load configuration
        desired_tenants = ConfigLoader.load_tenants_from_yaml(config)

        # Get existing tenants
        existing = client.list_tenants()

        # Validate operations before proceeding
        try:
            validator.validate_sync_operations(desired_tenants, existing)
        except ValidationError as e:
            console.print(f"[red]Validation Error:[/red] {ErrorFormatter.format(e)}")
            raise typer.Exit(1)

        # ... rest of sync logic ...

    except Exception as e:
        console.print(f"[red]Error:[/red] {ErrorFormatter.format(e)}")
        raise typer.Exit(1)
```

**Step 4: Run test to verify it passes**

```bash
pytest tests/unit/cli/test_tenant_cmds.py::test_sync_tenants_validates_before_apply -v
pytest tests/unit/cli/test_tenant_cmds.py::test_sync_tenants_validation_shows_helpful_errors -v
```

Expected: All tests passing

**Step 5: Run all tests to verify nothing broke**

```bash
pytest tests/ -v
```

Expected: All tests passing (191+ total)

**Step 6: Run quality checks**

```bash
mypy src/
ruff check .
lint-imports
```

Expected: All checks passing

**Step 7: Manual verification**

Create invalid config and test:

```bash
cat > /tmp/invalid.yaml <<EOF
tenants:
  - id: test-1
    name: Test 1
    selfProvisioningDomains: []
  - id: test-1
    name: Duplicate
    selfProvisioningDomains: []
EOF

descope-mgmt tenant sync --config /tmp/invalid.yaml --dry-run
```

Expected: Validation error with helpful message about duplicate IDs

**Step 8: Commit**

```bash
git add src/descope_mgmt/cli/tenant_cmds.py tests/unit/cli/test_tenant_cmds.py
git commit -m "feat: integrate pre-flight validation into sync command"
```

---

## Chunk Complete Checklist

- [ ] Task 1: SyncValidator created with 6 tests
- [ ] Task 2: Validators integrated into sync command
- [ ] All tests passing (191+ total)
- [ ] Coverage maintained at 94%+
- [ ] All quality checks passing (mypy, ruff, lint-imports)
- [ ] Code committed (2 commits)
- [ ] **Week 4 COMPLETE! Ready for final review**
