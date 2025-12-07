# Chunk 9: Audit Log Export Formats

**Status:** pending
**Dependencies:** chunk-008-audit-filtering (for filtering support)
**Complexity:** medium
**Estimated Time:** 12 minutes
**Tasks:** 2
**Phase:** Audit Log Enhancements
**Jira:** PCC-255

---

## Task 1: Add Export Methods to AuditLogger

**Agent:** python-pro
**Files:**
- Modify: `src/descope_mgmt/domain/audit_logger.py`
- Modify: `tests/unit/domain/test_audit_logger.py`

**Step 1: Add tests for export methods**

Add to `tests/unit/domain/test_audit_logger.py`:

```python
import csv
import io


class TestAuditLoggerExport:
    """Tests for audit log export functionality."""

    def test_export_to_json(self, tmp_path: Path) -> None:
        """Test exporting logs to JSON format."""
        logger = AuditLogger(log_dir=tmp_path)

        entry = AuditEntry(
            timestamp=datetime.now(UTC),
            operation=AuditOperation.TENANT_CREATE,
            resource_id="tenant-1",
            success=True,
        )
        logger.log(entry)

        json_output = logger.export_json(limit=10)

        data = json.loads(json_output)
        assert isinstance(data, list)
        assert len(data) == 1
        assert data[0]["resource_id"] == "tenant-1"

    def test_export_to_csv(self, tmp_path: Path) -> None:
        """Test exporting logs to CSV format."""
        logger = AuditLogger(log_dir=tmp_path)

        entry = AuditEntry(
            timestamp=datetime.now(UTC),
            operation=AuditOperation.TENANT_CREATE,
            resource_id="tenant-1",
            success=True,
        )
        logger.log(entry)

        csv_output = logger.export_csv(limit=10)

        reader = csv.DictReader(io.StringIO(csv_output))
        rows = list(reader)
        assert len(rows) == 1
        assert rows[0]["resource_id"] == "tenant-1"
        assert "timestamp" in rows[0]

    def test_export_csv_headers(self, tmp_path: Path) -> None:
        """Test CSV export includes proper headers."""
        logger = AuditLogger(log_dir=tmp_path)

        entry = AuditEntry(
            timestamp=datetime.now(UTC),
            operation=AuditOperation.TENANT_CREATE,
            resource_id="test",
            success=True,
        )
        logger.log(entry)

        csv_output = logger.export_csv(limit=10)

        lines = csv_output.strip().split("\n")
        headers = lines[0].split(",")
        assert "timestamp" in headers
        assert "operation" in headers
        assert "resource_id" in headers
        assert "success" in headers
```

**Step 2: Run tests to verify they fail**

```bash
pytest tests/unit/domain/test_audit_logger.py::TestAuditLoggerExport -v
```

Expected: FAIL (export_json, export_csv not found)

**Step 3: Implement export methods**

Add to `src/descope_mgmt/domain/audit_logger.py`:

```python
import csv
import io


class AuditLogger:
    # ... existing methods ...

    def export_json(
        self,
        limit: int = 100,
        **filters: Any,
    ) -> str:
        """Export audit logs to JSON format.

        Args:
            limit: Maximum entries to export.
            **filters: Additional filters (operation, start_date, etc.)

        Returns:
            JSON string of audit entries.
        """
        entries = self.read_logs(limit=limit, **filters)

        # Convert to JSON-serializable format
        data = []
        for entry in entries:
            entry_dict = entry.model_dump(mode="json")
            # Convert timestamp to ISO format string
            entry_dict["timestamp"] = entry.timestamp.isoformat()
            # Convert operation enum to string
            entry_dict["operation"] = entry.operation.value
            data.append(entry_dict)

        return json.dumps(data, indent=2)

    def export_csv(
        self,
        limit: int = 100,
        **filters: Any,
    ) -> str:
        """Export audit logs to CSV format.

        Args:
            limit: Maximum entries to export.
            **filters: Additional filters (operation, start_date, etc.)

        Returns:
            CSV string of audit entries.
        """
        entries = self.read_logs(limit=limit, **filters)

        output = io.StringIO()
        fieldnames = [
            "timestamp",
            "operation",
            "resource_id",
            "success",
            "error",
            "details",
        ]
        writer = csv.DictWriter(output, fieldnames=fieldnames)
        writer.writeheader()

        for entry in entries:
            writer.writerow({
                "timestamp": entry.timestamp.isoformat(),
                "operation": entry.operation.value,
                "resource_id": entry.resource_id,
                "success": str(entry.success),
                "error": entry.error or "",
                "details": json.dumps(entry.details) if entry.details else "",
            })

        return output.getvalue()
```

**Step 4: Run tests to verify they pass**

```bash
pytest tests/unit/domain/test_audit_logger.py -v
```

Expected: PASS

**Step 5: Commit**

```bash
git add src/descope_mgmt/domain/audit_logger.py tests/unit/domain/test_audit_logger.py
git commit -m "feat(audit): add JSON and CSV export methods"
```

---

## Task 2: Add Export Command to CLI

**Agent:** python-pro
**Files:**
- Modify: `src/descope_mgmt/cli/audit_cmds.py`
- Modify: `tests/unit/cli/test_audit_cmds.py`
- Modify: `src/descope_mgmt/cli/main.py`

**Step 1: Add tests for export command**

```python
class TestAuditExportCLI:
    """Tests for audit export CLI command."""

    def test_export_json_to_stdout(self) -> None:
        """Test exporting JSON to stdout."""
        runner = CliRunner()

        with patch("descope_mgmt.cli.audit_cmds.AuditLogger") as mock_logger_cls:
            mock_logger = MagicMock()
            mock_logger.export_json.return_value = '[{"test": "data"}]'
            mock_logger_cls.return_value = mock_logger

            result = runner.invoke(export_audit_logs, ["--format", "json"])

            assert result.exit_code == 0
            assert '{"test": "data"}' in result.output

    def test_export_csv_to_file(self) -> None:
        """Test exporting CSV to file."""
        runner = CliRunner()

        with runner.isolated_filesystem():
            with patch("descope_mgmt.cli.audit_cmds.AuditLogger") as mock_logger_cls:
                mock_logger = MagicMock()
                mock_logger.export_csv.return_value = "timestamp,operation\n2025-01-01,create"
                mock_logger_cls.return_value = mock_logger

                result = runner.invoke(
                    export_audit_logs,
                    ["--format", "csv", "--output", "audit.csv"],
                )

                assert result.exit_code == 0
                assert Path("audit.csv").exists()
                content = Path("audit.csv").read_text()
                assert "timestamp,operation" in content
```

**Step 2: Run tests to verify they fail**

```bash
pytest tests/unit/cli/test_audit_cmds.py::TestAuditExportCLI -v
```

Expected: FAIL (export_audit_logs not found)

**Step 3: Implement export command**

Add to `src/descope_mgmt/cli/audit_cmds.py`:

```python
@click.command()
@click.option(
    "--format",
    "output_format",
    type=click.Choice(["json", "csv"]),
    default="json",
    help="Export format (default: json).",
)
@click.option(
    "--output", "-o",
    type=click.Path(path_type=Path),
    default=None,
    help="Output file path (default: stdout).",
)
@click.option(
    "--log-dir",
    type=click.Path(exists=False, path_type=Path),
    default=None,
    help="Directory containing audit logs.",
)
@click.option("--limit", type=int, default=1000, help="Maximum entries to export.")
@click.option("--operation", type=str, default=None, help="Filter by operation.")
@click.option("--resource", "resource_id", type=str, default=None, help="Filter by resource.")
@click.option(
    "--since",
    type=click.DateTime(formats=["%Y-%m-%d"]),
    default=None,
    help="Export entries after this date.",
)
def export_audit_logs(
    output_format: str,
    output: Path | None,
    log_dir: Path | None,
    limit: int,
    operation: str | None,
    resource_id: str | None,
    since: datetime | None,
) -> None:
    """Export audit logs to JSON or CSV format."""
    console = get_console()

    audit_logger = AuditLogger(log_dir=log_dir)

    # Build filter kwargs
    filters: dict[str, Any] = {}
    if operation:
        filters["operation"] = operation
    if resource_id:
        filters["resource_id"] = resource_id
    if since:
        from datetime import UTC
        filters["start_date"] = since.replace(tzinfo=UTC)

    # Export in requested format
    if output_format == "json":
        content = audit_logger.export_json(limit=limit, **filters)
    else:
        content = audit_logger.export_csv(limit=limit, **filters)

    # Write to file or stdout
    if output:
        output.write_text(content)
        console.print(f"[green]Exported to:[/green] {output}")
    else:
        console.print(content)
```

**Step 4: Register command in main.py**

```python
from descope_mgmt.cli.audit_cmds import list_audit_logs, export_audit_logs

audit.add_command(list_audit_logs, name="list")
audit.add_command(export_audit_logs, name="export")
```

**Step 5: Run tests to verify they pass**

```bash
pytest tests/unit/cli/test_audit_cmds.py -v
```

Expected: PASS

**Step 6: Commit**

```bash
git add src/descope_mgmt/cli/audit_cmds.py tests/unit/cli/test_audit_cmds.py src/descope_mgmt/cli/main.py
git commit -m "feat(cli): add audit export command with JSON and CSV formats"
```

---

## Chunk Complete Checklist

- [ ] export_json method implemented
- [ ] export_csv method implemented
- [ ] Export CLI command created
- [ ] Output to file or stdout
- [ ] All tests passing
- [ ] Code committed
- [ ] Ready for next chunk
