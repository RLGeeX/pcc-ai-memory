# Chunk 10: Audit Statistics Dashboard

**Status:** pending
**Dependencies:** chunk-008-audit-filtering
**Complexity:** medium
**Estimated Time:** 12 minutes
**Tasks:** 2
**Phase:** Audit Log Enhancements
**Jira:** PCC-255

---

## Task 1: Add Statistics Calculation to AuditLogger

**Agent:** python-pro
**Files:**
- Modify: `src/descope_mgmt/domain/audit_logger.py`
- Create: `src/descope_mgmt/types/audit_stats.py`
- Modify: `tests/unit/domain/test_audit_logger.py`

**Step 1: Create AuditStats type and add tests**

Create `tests/unit/types/test_audit_stats.py`:

```python
"""Tests for audit statistics types."""

from datetime import datetime, UTC
from descope_mgmt.types.audit_stats import AuditStats, OperationCount


class TestAuditStats:
    """Tests for AuditStats."""

    def test_stats_from_entries(self) -> None:
        """Test creating stats from entries."""
        stats = AuditStats(
            total_entries=100,
            successful=85,
            failed=15,
            success_rate=0.85,
            operations=[
                OperationCount(operation="tenant_create", count=50),
                OperationCount(operation="tenant_update", count=35),
                OperationCount(operation="tenant_delete", count=15),
            ],
            period_start=datetime(2025, 1, 1, tzinfo=UTC),
            period_end=datetime(2025, 1, 31, tzinfo=UTC),
        )

        assert stats.total_entries == 100
        assert stats.success_rate == 0.85
        assert len(stats.operations) == 3

    def test_stats_top_operations(self) -> None:
        """Test operations sorted by count."""
        stats = AuditStats(
            total_entries=100,
            successful=100,
            failed=0,
            success_rate=1.0,
            operations=[
                OperationCount(operation="a", count=10),
                OperationCount(operation="b", count=50),
                OperationCount(operation="c", count=40),
            ],
            period_start=datetime(2025, 1, 1, tzinfo=UTC),
            period_end=datetime(2025, 1, 31, tzinfo=UTC),
        )

        top = stats.top_operations(2)
        assert top[0].operation == "b"
        assert top[1].operation == "c"
```

Add tests to `tests/unit/domain/test_audit_logger.py`:

```python
from descope_mgmt.types.audit_stats import AuditStats


class TestAuditLoggerStats:
    """Tests for audit log statistics."""

    def test_get_statistics(self, tmp_path: Path) -> None:
        """Test getting statistics from logs."""
        logger = AuditLogger(log_dir=tmp_path)

        # Create various entries
        now = datetime.now(UTC)
        entries = [
            AuditEntry(
                timestamp=now,
                operation=AuditOperation.TENANT_CREATE,
                resource_id="t1",
                success=True,
            ),
            AuditEntry(
                timestamp=now,
                operation=AuditOperation.TENANT_CREATE,
                resource_id="t2",
                success=True,
            ),
            AuditEntry(
                timestamp=now,
                operation=AuditOperation.TENANT_UPDATE,
                resource_id="t1",
                success=False,
                error="API error",
            ),
        ]

        for entry in entries:
            logger.log(entry)

        stats = logger.get_statistics()

        assert stats.total_entries == 3
        assert stats.successful == 2
        assert stats.failed == 1
        assert stats.success_rate == pytest.approx(0.666, rel=0.01)
```

**Step 2: Run tests to verify they fail**

```bash
pytest tests/unit/domain/test_audit_logger.py::TestAuditLoggerStats -v
```

Expected: FAIL

**Step 3: Create AuditStats type**

Create `src/descope_mgmt/types/audit_stats.py`:

```python
"""Audit statistics types."""

from datetime import datetime
from pydantic import BaseModel


class OperationCount(BaseModel):
    """Count of operations by type."""

    operation: str
    count: int


class AuditStats(BaseModel):
    """Statistics summary for audit logs."""

    total_entries: int
    successful: int
    failed: int
    success_rate: float
    operations: list[OperationCount]
    period_start: datetime | None = None
    period_end: datetime | None = None

    def top_operations(self, n: int = 5) -> list[OperationCount]:
        """Get top N operations by count."""
        return sorted(self.operations, key=lambda x: x.count, reverse=True)[:n]
```

**Step 4: Add get_statistics to AuditLogger**

Add to `src/descope_mgmt/domain/audit_logger.py`:

```python
from collections import Counter
from descope_mgmt.types.audit_stats import AuditStats, OperationCount


class AuditLogger:
    # ... existing methods ...

    def get_statistics(
        self,
        limit: int = 10000,
        **filters: Any,
    ) -> AuditStats:
        """Get statistics summary of audit logs.

        Args:
            limit: Maximum entries to analyze.
            **filters: Additional filters to apply.

        Returns:
            AuditStats with summary information.
        """
        entries = self.read_logs(limit=limit, **filters)

        if not entries:
            return AuditStats(
                total_entries=0,
                successful=0,
                failed=0,
                success_rate=0.0,
                operations=[],
            )

        # Calculate counts
        total = len(entries)
        successful = sum(1 for e in entries if e.success)
        failed = total - successful
        success_rate = successful / total if total > 0 else 0.0

        # Count operations
        op_counter: Counter[str] = Counter()
        for entry in entries:
            op_counter[entry.operation.value] += 1

        operations = [
            OperationCount(operation=op, count=count)
            for op, count in op_counter.most_common()
        ]

        # Get period from entries
        timestamps = [e.timestamp for e in entries]
        period_start = min(timestamps) if timestamps else None
        period_end = max(timestamps) if timestamps else None

        return AuditStats(
            total_entries=total,
            successful=successful,
            failed=failed,
            success_rate=success_rate,
            operations=operations,
            period_start=period_start,
            period_end=period_end,
        )
```

**Step 5: Run tests to verify they pass**

```bash
pytest tests/unit/domain/test_audit_logger.py -v
pytest tests/unit/types/test_audit_stats.py -v
```

Expected: PASS

**Step 6: Commit**

```bash
git add src/descope_mgmt/types/audit_stats.py src/descope_mgmt/domain/audit_logger.py tests/
git commit -m "feat(audit): add statistics calculation with AuditStats"
```

---

## Task 2: Add Stats Command to CLI

**Agent:** python-pro
**Files:**
- Modify: `src/descope_mgmt/cli/audit_cmds.py`
- Modify: `tests/unit/cli/test_audit_cmds.py`
- Modify: `src/descope_mgmt/cli/main.py`

**Step 1: Add tests for stats command**

```python
class TestAuditStatsCLI:
    """Tests for audit stats CLI command."""

    def test_stats_displays_summary(self) -> None:
        """Test stats command displays summary."""
        runner = CliRunner()

        with patch("descope_mgmt.cli.audit_cmds.AuditLogger") as mock_logger_cls:
            mock_logger = MagicMock()
            mock_logger.get_statistics.return_value = AuditStats(
                total_entries=100,
                successful=85,
                failed=15,
                success_rate=0.85,
                operations=[
                    OperationCount(operation="tenant_create", count=50),
                    OperationCount(operation="tenant_update", count=35),
                ],
                period_start=datetime(2025, 1, 1, tzinfo=UTC),
                period_end=datetime(2025, 1, 31, tzinfo=UTC),
            )
            mock_logger_cls.return_value = mock_logger

            result = runner.invoke(audit_stats)

            assert result.exit_code == 0
            assert "100" in result.output  # total entries
            assert "85" in result.output  # successful
            assert "tenant_create" in result.output  # top operation
```

**Step 2: Run tests to verify they fail**

```bash
pytest tests/unit/cli/test_audit_cmds.py::TestAuditStatsCLI -v
```

Expected: FAIL (audit_stats not found)

**Step 3: Implement stats command**

Add to `src/descope_mgmt/cli/audit_cmds.py`:

```python
from descope_mgmt.types.audit_stats import AuditStats


@click.command()
@click.option(
    "--log-dir",
    type=click.Path(exists=False, path_type=Path),
    default=None,
    help="Directory containing audit logs.",
)
@click.option(
    "--since",
    type=click.DateTime(formats=["%Y-%m-%d"]),
    default=None,
    help="Analyze entries after this date.",
)
@click.option(
    "--top",
    type=int,
    default=5,
    help="Number of top operations to show (default: 5).",
)
def audit_stats(
    log_dir: Path | None,
    since: datetime | None,
    top: int,
) -> None:
    """Display audit log statistics dashboard."""
    console = get_console()

    audit_logger = AuditLogger(log_dir=log_dir)

    # Build filters
    filters: dict[str, Any] = {}
    if since:
        from datetime import UTC
        filters["start_date"] = since.replace(tzinfo=UTC)

    stats = audit_logger.get_statistics(**filters)

    # Display header
    console.print("\n[bold]Audit Log Statistics[/bold]\n")

    # Summary table
    summary_table = Table(title="Summary")
    summary_table.add_column("Metric", style="cyan")
    summary_table.add_column("Value", style="green")

    summary_table.add_row("Total Entries", str(stats.total_entries))
    summary_table.add_row("Successful", f"{stats.successful} ({stats.success_rate:.1%})")
    summary_table.add_row("Failed", str(stats.failed))

    if stats.period_start:
        summary_table.add_row(
            "Period",
            f"{stats.period_start.strftime('%Y-%m-%d')} to {stats.period_end.strftime('%Y-%m-%d')}"
        )

    console.print(summary_table)

    # Operations breakdown
    if stats.operations:
        console.print()
        ops_table = Table(title=f"Top {top} Operations")
        ops_table.add_column("Operation", style="yellow")
        ops_table.add_column("Count", style="cyan", justify="right")
        ops_table.add_column("Percentage", justify="right")

        for op in stats.top_operations(top):
            pct = op.count / stats.total_entries * 100 if stats.total_entries > 0 else 0
            ops_table.add_row(
                op.operation,
                str(op.count),
                f"{pct:.1f}%",
            )

        console.print(ops_table)

    console.print()
```

**Step 4: Register command in main.py**

```python
from descope_mgmt.cli.audit_cmds import list_audit_logs, export_audit_logs, audit_stats

audit.add_command(audit_stats, name="stats")
```

**Step 5: Run tests to verify they pass**

```bash
pytest tests/unit/cli/test_audit_cmds.py -v
```

Expected: PASS

**Step 6: Commit**

```bash
git add src/descope_mgmt/cli/audit_cmds.py tests/unit/cli/test_audit_cmds.py src/descope_mgmt/cli/main.py
git commit -m "feat(cli): add audit stats command with dashboard display"
```

---

## Chunk Complete Checklist

- [ ] AuditStats type created
- [ ] get_statistics method implemented
- [ ] Stats CLI command created
- [ ] Dashboard display with tables
- [ ] 5+ tests for audit enhancements
- [ ] All tests passing
- [ ] Code committed
- [ ] Ready for Phase 4 (Rate Limit Verification)
