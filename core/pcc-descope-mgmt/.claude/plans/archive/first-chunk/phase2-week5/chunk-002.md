# Chunk 2: Flow Sync Command (Dry-Run)

**Status:** pending
**Dependencies:** chunk-001
**Estimated Time:** 45-60 minutes

---

## Task 1: Implement Flow Sync

**Files:**
- Modify: `src/descope_mgmt/cli/flow.py`
- Create: `tests/integration/test_flow_sync.py`

**Step 1: Write tests**

Create `tests/integration/test_flow_sync.py`:
```python
"""Integration tests for flow sync"""
import pytest
from unittest.mock import Mock, patch
from click.testing import CliRunner
from descope_mgmt.cli.main import cli


@patch('descope_mgmt.cli.flow.DescopeApiClient')
def test_flow_sync_dry_run(mock_client_class, tmp_path):
    """Should preview flow sync changes"""
    # Mock client
    mock_client = Mock()
    mock_client.list_flows.return_value = []
    mock_client_class.return_value = mock_client

    # Create config
    config_file = tmp_path / "flows.yaml"
    config_file.write_text("""
flows:
  - flow_id: sign-up
    name: Sign Up
    """)

    runner = CliRunner()
    result = runner.invoke(cli, [
        'flow', 'sync',
        '--config', str(config_file),
        '--dry-run'
    ])

    assert result.exit_code == 0
    assert "sign-up" in result.output
    assert "dry-run" in result.output.lower()
```

**Step 2: Implement sync command**

Modify `src/descope_mgmt/cli/flow.py`:
```python
@flow.command()
@click.option('--config', type=click.Path(exists=True), required=True)
@click.option('--dry-run', is_flag=True)
@click.option('--yes', is_flag=True)
@click.pass_context
def sync(ctx: click.Context, config: str, dry_run: bool, yes: bool) -> None:
    """Sync flows to match configuration"""
    # Implementation similar to tenant sync
    pass
```

**Step 3: Commit**

```bash
git add src/descope_mgmt/cli/flow.py tests/integration/test_flow_sync.py
git commit -m "feat: implement flow sync --dry-run"
```

---

## Chunk Complete Checklist

- [ ] flow sync --dry-run
- [ ] 4 tests passing
