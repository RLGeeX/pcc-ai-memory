# Chunk 2: Drift Detect Command

**Status:** pending
**Dependencies:** chunk-001
**Estimated Time:** 45-60 minutes

---

## Task 1: Implement Drift Detect Command

**Files:**
- Create: `src/descope_mgmt/cli/drift.py`
- Modify: `src/descope_mgmt/cli/main.py`
- Create: `tests/integration/test_drift_detect.py`

**Step 1: Write tests**

Create `tests/integration/test_drift_detect.py`:
```python
"""Integration tests for drift detect"""
import pytest
from unittest.mock import Mock, patch
from click.testing import CliRunner
from descope_mgmt.cli.main import cli


@patch('descope_mgmt.cli.drift.DriftDetector')
@patch('descope_mgmt.cli.drift.StateFetcher')
@patch('descope_mgmt.cli.drift.ConfigLoader')
@patch('descope_mgmt.cli.drift.DescopeApiClient')
def test_drift_detect_no_drift(mock_client_class, mock_loader_class, mock_fetcher_class, mock_detector_class):
    """Should show no drift when states match"""
    # Mock no drift
    mock_drift_report = Mock()
    mock_drift_report.has_drift = False
    mock_drift_report.drifts = []

    mock_detector = Mock()
    mock_detector.detect_drift.return_value = mock_drift_report
    mock_detector_class.return_value = mock_detector

    runner = CliRunner()
    result = runner.invoke(cli, ['drift', 'detect', '--config', 'test.yaml'])

    assert result.exit_code == 0
    assert "no drift" in result.output.lower() or "✓" in result.output
```

**Step 2: Implement drift command group**

Create `src/descope_mgmt/cli/drift.py`:
```python
"""Drift detection commands."""
import os
import click
from rich.console import Console
from rich.table import Table
from descope_mgmt.api.descope_client import DescopeApiClient
from descope_mgmt.domain.services import StateFetcher, DriftDetector
from descope_mgmt.utils.config_loader import ConfigLoader
from descope_mgmt.cli.common import format_error

console = Console()


@click.group()
def drift():
    """Detect configuration drift"""
    pass


@drift.command()
@click.option('--config', type=click.Path(exists=True), help='Configuration file')
@click.option('--severity', type=click.Choice(['info', 'warning', 'critical']), help='Filter by severity')
@click.pass_context
def detect(ctx: click.Context, config: str | None, severity: str | None) -> None:
    """Detect configuration drift

    Compares current Descope state with desired configuration
    and reports any differences.
    """
    try:
        # Load config
        loader = ConfigLoader()
        desired_config = loader.load_or_discover(config)

        # Get credentials
        project_id = os.getenv('DESCOPE_PROJECT_ID')
        management_key = os.getenv('DESCOPE_MANAGEMENT_KEY')

        if not project_id or not management_key:
            console.print(format_error("Missing credentials"))
            raise click.Abort()

        # Fetch current state
        client = DescopeApiClient(project_id, management_key)
        fetcher = StateFetcher(client, project_id)
        current_state = fetcher.fetch_current_state()

        # Detect drift
        detector = DriftDetector()
        drift_report = detector.detect_drift(current_state, desired_config)

        # Display results
        if not drift_report.has_drift:
            console.print("[green]✓ No configuration drift detected[/green]")
            return

        # Filter by severity if specified
        drifts = drift_report.drifts
        if severity:
            from descope_mgmt.domain.services.drift_detector import DriftSeverity
            sev_enum = DriftSeverity(severity)
            drifts = [d for d in drifts if d.severity == sev_enum]

        # Show summary
        console.print(f"\n[yellow]⚠ Configuration drift detected:[/yellow]")
        console.print(f"  Critical: {drift_report.count_by_severity(DriftSeverity.CRITICAL)}")
        console.print(f"  Warning: {drift_report.count_by_severity(DriftSeverity.WARNING)}")
        console.print(f"  Info: {drift_report.count_by_severity(DriftSeverity.INFO)}\n")

        # Show drift table
        table = Table(title="Drift Details")
        table.add_column("Severity", style="yellow")
        table.add_column("Resource", style="cyan")
        table.add_column("Field", style="green")
        table.add_column("Current", style="dim")
        table.add_column("Expected", style="bright_white")

        for drift_item in drifts:
            severity_color = {
                DriftSeverity.CRITICAL: "red",
                DriftSeverity.WARNING: "yellow",
                DriftSeverity.INFO: "blue"
            }[drift_item.severity]

            table.add_row(
                f"[{severity_color}]{drift_item.severity.value.upper()}[/{severity_color}]",
                f"{drift_item.resource_type}: {drift_item.resource_id}",
                drift_item.field,
                str(drift_item.current_value),
                str(drift_item.expected_value)
            )

        console.print(table)

    except Exception as e:
        console.print(format_error(f"Drift detection failed: {e}"))
        raise click.Abort()
```

**Step 3: Register drift group**

Modify `src/descope_mgmt/cli/main.py`:
```python
from descope_mgmt.cli.drift import drift

cli.add_command(drift)
```

**Step 4: Commit**

```bash
git add src/descope_mgmt/cli/drift.py src/descope_mgmt/cli/main.py tests/integration/test_drift_detect.py
git commit -m "feat: implement drift detect command"
```

---

## Chunk Complete Checklist

- [ ] drift detect command
- [ ] Severity filtering
- [ ] Rich table display
- [ ] 4 tests passing
