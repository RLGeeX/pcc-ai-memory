# Chunk 4: Scheduled Drift Checks (Optional)

**Status:** pending
**Dependencies:** chunk-001, chunk-002, chunk-003
**Estimated Time:** 30 minutes

---

## Task 1: Implement Drift Watch (Optional)

**Files:**
- Modify: `src/descope_mgmt/cli/drift.py`
- Create: `tests/integration/test_drift_watch.py`

**Step 1: Write tests**

Create `tests/integration/test_drift_watch.py`:
```python
"""Integration tests for drift watch"""
import pytest
from unittest.mock import Mock, patch
from click.testing import CliRunner
from descope_mgmt.cli.main import cli


@patch('descope_mgmt.cli.drift.DriftDetector')
def test_drift_watch_placeholder(mock_detector_class):
    """Placeholder test for drift watch"""
    # This is optional functionality - basic test
    runner = CliRunner()
    result = runner.invoke(cli, ['drift', 'watch', '--help'])

    assert result.exit_code == 0
    assert "watch" in result.output.lower()
```

**Step 2: Implement watch command (basic)**

Modify `src/descope_mgmt/cli/drift.py`:
```python
@drift.command()
@click.option('--interval', type=int, default=3600, help='Check interval in seconds')
@click.option('--notify', type=click.Choice(['email', 'webhook']), help='Notification method')
@click.pass_context
def watch(ctx: click.Context, interval: int, notify: str | None) -> None:
    """Watch for drift (background monitoring)

    OPTIONAL: Periodically checks for configuration drift.
    """
    console.print("[yellow]⚠ Drift watch is an optional feature[/yellow]")
    console.print("For production use, consider setting up a cron job:")
    console.print(f"  */60 * * * * descope-mgmt drift detect --config /path/to/config.yaml")
    console.print("\nUse --notify to configure alerting (not yet implemented)")
```

**Step 3: Commit**

```bash
git add src/descope_mgmt/cli/drift.py tests/integration/test_drift_watch.py
git commit -m "feat: add drift watch placeholder (optional)"
```

---

## Chunk Complete Checklist

- [ ] drift watch command (placeholder)
- [ ] Cron job documentation
- [ ] 2 tests passing
- [ ] **Phase 3 Week 7 COMPLETE**
