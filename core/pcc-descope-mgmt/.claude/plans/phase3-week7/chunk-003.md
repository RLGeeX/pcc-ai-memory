# Chunk 3: Drift Report Generation

**Status:** pending
**Dependencies:** chunk-001, chunk-002
**Estimated Time:** 45 minutes

---

## Task 1: Implement Drift Report Command

**Files:**
- Modify: `src/descope_mgmt/cli/drift.py`
- Create: `tests/integration/test_drift_report.py`

**Step 1: Write tests**

Create `tests/integration/test_drift_report.py`:
```python
"""Integration tests for drift report"""
import pytest
from unittest.mock import Mock, patch
from click.testing import CliRunner
from descope_mgmt.cli.main import cli


@patch('descope_mgmt.cli.drift.DriftDetector')
def test_drift_report_json(mock_detector_class, tmp_path):
    """Should generate drift report in JSON format"""
    mock_drift_report = Mock()
    mock_drift_report.has_drift = True
    mock_drift_report.drifts = []

    mock_detector = Mock()
    mock_detector.detect_drift.return_value = mock_drift_report
    mock_detector_class.return_value = mock_detector

    output_file = tmp_path / "drift-report.json"

    runner = CliRunner()
    result = runner.invoke(cli, [
        'drift', 'report',
        '--output', str(output_file),
        '--format', 'json'
    ])

    assert result.exit_code == 0
    assert output_file.exists()
```

**Step 2: Implement report command**

Modify `src/descope_mgmt/cli/drift.py`:
```python
@drift.command()
@click.option('--output', type=click.Path(), required=True)
@click.option('--format', type=click.Choice(['json', 'html', 'markdown']), default='json')
@click.pass_context
def report(ctx: click.Context, output: str, format: str) -> None:
    """Generate drift report

    Creates a drift report in various formats for documentation.
    """
    try:
        import json
        from pathlib import Path

        # Detect drift (same as detect command)
        loader = ConfigLoader()
        desired_config = loader.load_or_discover()

        project_id = os.getenv('DESCOPE_PROJECT_ID')
        management_key = os.getenv('DESCOPE_MANAGEMENT_KEY')
        client = DescopeApiClient(project_id, management_key)
        fetcher = StateFetcher(client, project_id)
        current_state = fetcher.fetch_current_state()

        detector = DriftDetector()
        drift_report = detector.detect_drift(current_state, desired_config)

        # Generate report
        output_path = Path(output)
        output_path.parent.mkdir(parents=True, exist_ok=True)

        if format == 'json':
            report_data = {
                "has_drift": drift_report.has_drift,
                "drift_count": len(drift_report.drifts),
                "drifts": [
                    {
                        "resource_type": d.resource_type,
                        "resource_id": d.resource_id,
                        "field": d.field,
                        "current_value": d.current_value,
                        "expected_value": d.expected_value,
                        "severity": d.severity.value
                    }
                    for d in drift_report.drifts
                ]
            }
            with open(output_path, 'w') as f:
                json.dump(report_data, f, indent=2)

        elif format == 'markdown':
            # TODO: Implement markdown format
            pass

        elif format == 'html':
            # TODO: Implement HTML format
            pass

        console.print(f"[green]✓ Drift report generated: {output}[/green]")

    except Exception as e:
        console.print(format_error(f"Report generation failed: {e}"))
        raise click.Abort()
```

**Step 3: Commit**

```bash
git add src/descope_mgmt/cli/drift.py tests/integration/test_drift_report.py
git commit -m "feat: implement drift report generation"
```

---

## Chunk Complete Checklist

- [ ] drift report command
- [ ] JSON format support
- [ ] 3 tests passing
