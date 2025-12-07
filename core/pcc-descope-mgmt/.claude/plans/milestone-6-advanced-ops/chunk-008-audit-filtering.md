# Chunk 8: Enhanced Audit Log Filtering

**Status:** pending
**Dependencies:** none (can run parallel with chunk-009)
**Complexity:** simple
**Estimated Time:** 10 minutes
**Tasks:** 2
**Phase:** Audit Log Enhancements
**Jira:** PCC-255

---

## Task 1: Add Date Range Filtering to AuditLogger

**Agent:** python-pro
**Files:**
- Modify: `src/descope_mgmt/domain/audit_logger.py`
- Modify: `tests/unit/domain/test_audit_logger.py`

**Step 1: Add tests for date range filtering**

Add to `tests/unit/domain/test_audit_logger.py`:

```python
from datetime import datetime, timedelta, UTC


class TestAuditLoggerFiltering:
    """Tests for audit log filtering."""

    def test_filter_by_date_range(self, tmp_path: Path) -> None:
        """Test filtering logs by date range."""
        logger = AuditLogger(log_dir=tmp_path)

        # Create entries across different dates
        now = datetime.now(UTC)
        yesterday = now - timedelta(days=1)
        last_week = now - timedelta(days=7)

        entries = [
            AuditEntry(
                timestamp=last_week,
                operation=AuditOperation.TENANT_CREATE,
                resource_id="old",
                success=True,
            ),
            AuditEntry(
                timestamp=yesterday,
                operation=AuditOperation.TENANT_UPDATE,
                resource_id="recent",
                success=True,
            ),
            AuditEntry(
                timestamp=now,
                operation=AuditOperation.TENANT_DELETE,
                resource_id="today",
                success=True,
            ),
        ]

        for entry in entries:
            logger.log(entry)

        # Filter to last 2 days
        start_date = now - timedelta(days=2)
        filtered = logger.read_logs(start_date=start_date)

        assert len(filtered) == 2
        assert all(e.timestamp >= start_date for e in filtered)

    def test_filter_by_end_date(self, tmp_path: Path) -> None:
        """Test filtering logs with end date."""
        logger = AuditLogger(log_dir=tmp_path)

        now = datetime.now(UTC)
        entry = AuditEntry(
            timestamp=now,
            operation=AuditOperation.TENANT_CREATE,
            resource_id="test",
            success=True,
        )
        logger.log(entry)

        # End date before now should exclude the entry
        end_date = now - timedelta(hours=1)
        filtered = logger.read_logs(end_date=end_date)

        assert len(filtered) == 0

    def test_filter_by_resource_id(self, tmp_path: Path) -> None:
        """Test filtering logs by resource ID."""
        logger = AuditLogger(log_dir=tmp_path)

        entries = [
            AuditEntry(
                timestamp=datetime.now(UTC),
                operation=AuditOperation.TENANT_CREATE,
                resource_id="tenant-1",
                success=True,
            ),
            AuditEntry(
                timestamp=datetime.now(UTC),
                operation=AuditOperation.TENANT_UPDATE,
                resource_id="tenant-2",
                success=True,
            ),
        ]

        for entry in entries:
            logger.log(entry)

        filtered = logger.read_logs(resource_id="tenant-1")

        assert len(filtered) == 1
        assert filtered[0].resource_id == "tenant-1"
```

**Step 2: Run tests to verify they fail**

```bash
pytest tests/unit/domain/test_audit_logger.py::TestAuditLoggerFiltering -v
```

Expected: FAIL (start_date, end_date, resource_id parameters not found)

**Step 3: Add filtering parameters to read_logs**

Update `src/descope_mgmt/domain/audit_logger.py`:

```python
def read_logs(
    self,
    limit: int = 100,
    operation: str | None = None,
    start_date: datetime | None = None,
    end_date: datetime | None = None,
    resource_id: str | None = None,
    success: bool | None = None,
) -> list[AuditEntry]:
    """Read audit log entries with filtering.

    Args:
        limit: Maximum number of entries to return.
        operation: Optional filter by operation type.
        start_date: Optional filter for entries after this date.
        end_date: Optional filter for entries before this date.
        resource_id: Optional filter by resource ID.
        success: Optional filter by success status.

    Returns:
        List of audit entries (most recent first).
    """
    entries: list[AuditEntry] = []

    log_files = sorted(self.log_dir.glob("*.jsonl"), reverse=True)

    for log_file in log_files:
        if len(entries) >= limit:
            break

        lines = log_file.read_text().strip().split("\n")

        for line in reversed(lines):
            if len(entries) >= limit:
                break

            if not line.strip():
                continue

            try:
                data = json.loads(line)
                entry = AuditEntry(**data)

                # Apply filters
                if operation is not None and entry.operation != operation:
                    continue
                if start_date is not None and entry.timestamp < start_date:
                    continue
                if end_date is not None and entry.timestamp > end_date:
                    continue
                if resource_id is not None and entry.resource_id != resource_id:
                    continue
                if success is not None and entry.success != success:
                    continue

                entries.append(entry)

            except (json.JSONDecodeError, ValueError):
                continue

    return entries
```

**Step 4: Run tests to verify they pass**

```bash
pytest tests/unit/domain/test_audit_logger.py -v
```

Expected: PASS

**Step 5: Commit**

```bash
git add src/descope_mgmt/domain/audit_logger.py tests/unit/domain/test_audit_logger.py
git commit -m "feat(audit): add date range and resource filtering to read_logs"
```

---

## Task 2: Add Filtering Options to CLI

**Agent:** python-pro
**Files:**
- Modify: `src/descope_mgmt/cli/audit_cmds.py`
- Modify: `tests/unit/cli/test_audit_cmds.py`

**Step 1: Add tests for CLI filtering options**

```python
class TestAuditCLIFiltering:
    """Tests for audit CLI filtering options."""

    def test_filter_by_resource(self) -> None:
        """Test --resource filter option."""
        runner = CliRunner()

        with patch("descope_mgmt.cli.audit_cmds.AuditLogger") as mock_logger_cls:
            mock_logger = MagicMock()
            mock_logger.read_logs.return_value = []
            mock_logger_cls.return_value = mock_logger

            result = runner.invoke(
                list_audit_logs, ["--resource", "tenant-123"]
            )

            mock_logger.read_logs.assert_called_once()
            call_kwargs = mock_logger.read_logs.call_args[1]
            assert call_kwargs.get("resource_id") == "tenant-123"

    def test_filter_by_date_range(self) -> None:
        """Test --since and --until filter options."""
        runner = CliRunner()

        with patch("descope_mgmt.cli.audit_cmds.AuditLogger") as mock_logger_cls:
            mock_logger = MagicMock()
            mock_logger.read_logs.return_value = []
            mock_logger_cls.return_value = mock_logger

            result = runner.invoke(
                list_audit_logs,
                ["--since", "2025-01-01", "--until", "2025-01-31"],
            )

            call_kwargs = mock_logger.read_logs.call_args[1]
            assert call_kwargs.get("start_date") is not None
            assert call_kwargs.get("end_date") is not None
```

**Step 2: Run tests to verify they fail**

```bash
pytest tests/unit/cli/test_audit_cmds.py::TestAuditCLIFiltering -v
```

Expected: FAIL

**Step 3: Add filtering options to CLI**

Update `src/descope_mgmt/cli/audit_cmds.py`:

```python
from datetime import datetime


@click.command()
@click.option(
    "--log-dir",
    type=click.Path(exists=False, path_type=Path),
    default=None,
    help="Directory containing audit logs.",
)
@click.option(
    "--limit",
    type=int,
    default=50,
    help="Maximum number of entries to display.",
)
@click.option(
    "--operation",
    type=str,
    default=None,
    help="Filter by operation type (e.g., tenant_create).",
)
@click.option(
    "--resource",
    "resource_id",
    type=str,
    default=None,
    help="Filter by resource ID.",
)
@click.option(
    "--since",
    type=click.DateTime(formats=["%Y-%m-%d", "%Y-%m-%dT%H:%M:%S"]),
    default=None,
    help="Show entries after this date (YYYY-MM-DD).",
)
@click.option(
    "--until",
    "until_date",
    type=click.DateTime(formats=["%Y-%m-%d", "%Y-%m-%dT%H:%M:%S"]),
    default=None,
    help="Show entries before this date (YYYY-MM-DD).",
)
@click.option(
    "--success/--failed",
    "success_filter",
    default=None,
    help="Filter by success or failure status.",
)
def list_audit_logs(
    log_dir: Path | None,
    limit: int,
    operation: str | None,
    resource_id: str | None,
    since: datetime | None,
    until_date: datetime | None,
    success_filter: bool | None,
) -> None:
    """List recent audit log entries with optional filtering."""
    console = get_console()

    audit_logger = AuditLogger(log_dir=log_dir)

    # Apply timezone to dates if provided
    from datetime import UTC
    start_date = since.replace(tzinfo=UTC) if since else None
    end_date = until_date.replace(tzinfo=UTC) if until_date else None

    entries = audit_logger.read_logs(
        limit=limit,
        operation=operation,
        start_date=start_date,
        end_date=end_date,
        resource_id=resource_id,
        success=success_filter,
    )

    # ... rest of display logic remains the same
```

**Step 4: Run tests to verify they pass**

```bash
pytest tests/unit/cli/test_audit_cmds.py -v
```

Expected: PASS

**Step 5: Commit**

```bash
git add src/descope_mgmt/cli/audit_cmds.py tests/unit/cli/test_audit_cmds.py
git commit -m "feat(cli): add filtering options to audit list command"
```

---

## Chunk Complete Checklist

- [ ] Date range filtering implemented
- [ ] Resource ID filtering added
- [ ] Success/failure filtering added
- [ ] CLI options updated
- [ ] All tests passing
- [ ] Code committed
- [ ] Ready for next chunk
