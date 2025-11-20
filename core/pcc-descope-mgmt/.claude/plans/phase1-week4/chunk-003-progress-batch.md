# Chunk 3: Progress Indicators - Batch Operations

**Status:** pending
**Dependencies:** chunk-002-progress-core
**Complexity:** medium
**Estimated Time:** 20 minutes
**Tasks:** 3

---

## Task 1: Add Progress to Tenant Sync Command

**Agent:** python-pro
**Files:**
- Modify: `src/descope_mgmt/cli/tenant_cmds.py`
- Modify: `tests/unit/cli/test_tenant_cmds.py`

**Step 1: Write the failing test**

Add test to `tests/unit/cli/test_tenant_cmds.py`:

```python
def test_sync_tenants_shows_progress_for_multiple_operations(
    runner: CliRunner,
    fake_client: FakeDescopeClient,
    tmp_path: Path,
) -> None:
    """Test that tenant sync shows progress for multiple operations."""
    # Create config with 3 tenants (1 create, 1 update, 1 no-op)
    config_file = tmp_path / "tenants.yaml"
    config_file.write_text("""
tenants:
  - id: tenant-1
    name: New Tenant
    selfProvisioningDomains: []
  - id: tenant-2
    name: Updated Tenant
    selfProvisioningDomains: []
  - id: tenant-3
    name: Existing Tenant
    selfProvisioningDomains: []
""")

    # Setup fake client state
    fake_client.tenants = [
        TenantResponse(id="tenant-2", name="Old Name"),
        TenantResponse(id="tenant-3", name="Existing Tenant"),
    ]

    with patch("descope_mgmt.cli.tenant_cmds.ProgressTracker") as mock_tracker:
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

        assert result.exit_code == 0
        # Should show progress for processing tenants
        mock_tracker.assert_called()
        call_args = mock_tracker.call_args_list[0]
        assert call_args[1]["total"] == 3
```

**Step 2: Run test to verify it fails**

```bash
pytest tests/unit/cli/test_tenant_cmds.py::test_sync_tenants_shows_progress_for_multiple_operations -v
```

Expected: FAIL - Progress not shown for sync

**Step 3: Update sync_tenants command**

Modify sync_tenants in `src/descope_mgmt/cli/tenant_cmds.py`:

```python
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

    # ... existing validation and setup ...

    try:
        client = ClientFactory.create_client(project_id, management_key)
        tenant_manager = TenantManager(client)
        backup_service = BackupService()

        # Load configuration
        desired_tenants = ConfigLoader.load_tenants_from_yaml(config)

        # ... existing diff calculation ...

        # Display plan with progress
        with ProgressTracker(
            total=len(desired_tenants.tenants),
            description="Analyzing configuration",
            console=console,
        ) as progress:
            for tenant in desired_tenants.tenants:
                # ... existing diff logic ...
                progress.update(1)

        # Display summary table
        # ... existing table display code ...

        # Apply changes if requested
        if apply:
            console.print("\n[bold yellow]Applying changes...[/bold yellow]")

            with ProgressTracker(
                total=len(to_create) + len(to_update),
                description="Applying tenant changes",
                console=console,
            ) as progress:
                # Create new tenants
                for tenant_cfg in to_create:
                    # ... existing create logic ...
                    progress.update(1)

                # Update existing tenants
                for tenant_id, tenant_cfg in to_update:
                    # Backup before update
                    backup = backup_service.create_backup(tenant_id, tenant_cfg)
                    # ... existing update logic ...
                    progress.update(1)

        # ... rest of function ...

    except Exception as e:
        console.print(f"[red]Error:[/red] {ErrorFormatter.format(e)}")
        raise typer.Exit(1)
```

**Step 4: Run test to verify it passes**

```bash
pytest tests/unit/cli/test_tenant_cmds.py::test_sync_tenants_shows_progress_for_multiple_operations -v
```

Expected: PASS

**Step 5: Commit**

```bash
git add src/descope_mgmt/cli/tenant_cmds.py tests/unit/cli/test_tenant_cmds.py
git commit -m "feat: add progress indicators to tenant sync command"
```

---

## Task 2: Add Progress to Flow Export/Import Operations

**Agent:** python-pro
**Files:**
- Modify: `src/descope_mgmt/cli/flow_cmds.py`
- Modify: `tests/unit/cli/test_flow_cmds.py`

**Step 1: Write the failing test**

Add test to `tests/unit/cli/test_flow_cmds.py`:

```python
def test_deploy_flow_shows_progress_for_screens(
    runner: CliRunner,
    fake_client: FakeDescopeClient,
    tmp_path: Path,
) -> None:
    """Test that flow deploy shows progress when deploying multiple screens."""
    # Create flow file with multiple screens
    flow_file = tmp_path / "flow.json"
    flow_data = {
        "flowId": "sign-up-or-in",
        "screens": [
            {"id": "screen-1", "inputs": []},
            {"id": "screen-2", "inputs": []},
            {"id": "screen-3", "inputs": []},
        ],
    }
    flow_file.write_text(json.dumps(flow_data))

    with patch("descope_mgmt.cli.flow_cmds.ProgressTracker") as mock_tracker:
        result = runner.invoke(
            cli_app,
            [
                "flow",
                "deploy",
                "--flow-file",
                str(flow_file),
                "--project-id",
                "test",
                "--management-key",
                "test",
            ],
        )

        assert result.exit_code == 0
        # Verify progress shown for screens
        mock_tracker.assert_called()
        call_args = mock_tracker.call_args
        assert call_args[1]["total"] == 3
```

**Step 2: Run test to verify it fails**

```bash
pytest tests/unit/cli/test_flow_cmds.py::test_deploy_flow_shows_progress_for_screens -v
```

Expected: FAIL - Progress not shown

**Step 3: Update deploy_flow command**

Modify `src/descope_mgmt/cli/flow_cmds.py`:

```python
# Add import
from descope_mgmt.cli.progress import ProgressTracker

@flow_app.command(name="deploy")
def deploy_flow(
    ctx: typer.Context,
    flow_file: Annotated[Path, typer.Option(...)],
    project_id: Annotated[str | None, typer.Option(...)] = None,
    management_key: Annotated[str | None, typer.Option(...)] = None,
) -> None:
    """Deploy a flow from JSON file."""
    console = get_console()
    try:
        # ... existing validation ...

        client = ClientFactory.create_client(project_id, management_key)
        flow_manager = FlowManager(client)

        # Deploy with progress
        screens = flow_data.get("screens", [])
        with ProgressTracker(
            total=len(screens),
            description=f"Deploying flow '{flow_id}'",
            console=console,
        ) as progress:
            for screen_id, screen_data in screens:
                flow_manager.deploy_screen(flow_id, screen_id, screen_data)
                progress.update(1)

        console.print(f"[green]✓[/green] Flow '{flow_id}' deployed successfully")

    except Exception as e:
        console.print(f"[red]Error:[/red] {ErrorFormatter.format(e)}")
        raise typer.Exit(1)
```

**Step 4: Run test to verify it passes**

```bash
pytest tests/unit/cli/test_flow_cmds.py::test_deploy_flow_shows_progress_for_screens -v
```

Expected: PASS

**Step 5: Commit**

```bash
git add src/descope_mgmt/cli/flow_cmds.py tests/unit/cli/test_flow_cmds.py
git commit -m "feat: add progress indicators to flow deploy command"
```

---

## Task 3: Add Progress to Backup/Restore Operations

**Agent:** python-pro
**Files:**
- Modify: `src/descope_mgmt/domain/backup_service.py`
- Modify: `src/descope_mgmt/domain/restore_service.py`
- Modify: `tests/unit/domain/test_backup_service.py`

**Step 1: Write the failing test**

Add test to `tests/unit/domain/test_backup_service.py`:

```python
from unittest.mock import MagicMock


def test_cleanup_old_backups_reports_progress():
    """Test that cleanup reports progress for multiple deletions."""
    service = BackupService()

    # Create old backups
    tenant_id = "test-tenant"
    for i in range(5):
        old_time = datetime.now(UTC) - timedelta(days=35 + i)
        service.create_backup(
            tenant_id,
            TenantConfig(id=tenant_id, name=f"Tenant {i}"),
            backup_time=old_time,
        )

    # Mock progress callback
    progress_callback = MagicMock()

    # Cleanup with progress
    deleted = service.cleanup_old_backups(retention_days=30, progress_callback=progress_callback)

    assert deleted == 5
    assert progress_callback.call_count == 5
```

**Step 2: Run test to verify it fails**

```bash
pytest tests/unit/domain/test_backup_service.py::test_cleanup_old_backups_reports_progress -v
```

Expected: FAIL - progress_callback parameter doesn't exist

**Step 3: Update BackupService to support progress callbacks**

Modify `src/descope_mgmt/domain/backup_service.py`:

```python
from typing import Callable

class BackupService:
    """Service for creating and managing tenant backups."""

    # ... existing code ...

    def cleanup_old_backups(
        self,
        retention_days: int = 30,
        progress_callback: Callable[[], None] | None = None,
    ) -> int:
        """Remove backups older than retention period.

        Args:
            retention_days: Number of days to retain backups
            progress_callback: Optional callback called after each deletion

        Returns:
            Number of backups deleted
        """
        cutoff = datetime.now(UTC) - timedelta(days=retention_days)
        deleted = 0

        for tenant_dir in self.backup_dir.iterdir():
            if not tenant_dir.is_dir():
                continue

            for backup_file in tenant_dir.glob("*.json"):
                try:
                    # ... existing parsing logic ...

                    if backup_time < cutoff:
                        backup_file.unlink()
                        deleted += 1
                        if progress_callback:
                            progress_callback()

                except (ValueError, IndexError):
                    continue

        return deleted
```

**Step 4: Run test to verify it passes**

```bash
pytest tests/unit/domain/test_backup_service.py::test_cleanup_old_backups_reports_progress -v
```

Expected: PASS

**Step 5: Run all domain tests**

```bash
pytest tests/unit/domain/ -v
```

Expected: All tests passing

**Step 6: Commit**

```bash
git add src/descope_mgmt/domain/backup_service.py tests/unit/domain/test_backup_service.py
git commit -m "feat: add progress callback support to backup cleanup"
```

---

## Chunk Complete Checklist

- [ ] Task 1: Progress added to tenant sync (2 progress bars)
- [ ] Task 2: Progress added to flow deploy
- [ ] Task 3: Progress callbacks added to backup/restore
- [ ] All tests passing (165+ total)
- [ ] Coverage maintained at 94%+
- [ ] Code committed (3 commits)
- [ ] **Review Checkpoint:** Ready for review before continuing
