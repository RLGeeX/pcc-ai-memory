# Chunk 3: Flow Apply Command

**Status:** pending
**Dependencies:** chunk-001, chunk-002
**Estimated Time:** 60 minutes

---

## Task 1: Implement Apply Mode for Flows

**Files:**
- Modify: `src/descope_mgmt/cli/flow.py`
- Create: `tests/integration/test_flow_apply.py`

**Step 1: Write tests**

Create `tests/integration/test_flow_apply.py`:
```python
"""Integration tests for flow apply"""
import pytest
from unittest.mock import Mock, patch
from click.testing import CliRunner
from descope_mgmt.cli.main import cli


@patch('descope_mgmt.cli.flow.DescopeApiClient')
@patch('descope_mgmt.cli.flow.BackupService')
def test_flow_sync_apply(mock_backup_class, mock_client_class, tmp_path):
    """Should apply flow changes"""
    mock_client = Mock()
    mock_client.list_flows.return_value = []
    mock_client.create_flow.return_value = True
    mock_client_class.return_value = mock_client

    mock_backup = Mock()
    mock_backup.create_backup.return_value = tmp_path / "backup"
    mock_backup_class.return_value = mock_backup

    config_file = tmp_path / "flows.yaml"
    config_file.write_text("flows:\n  - flow_id: test\n")

    runner = CliRunner()
    result = runner.invoke(cli, [
        'flow', 'sync',
        '--config', str(config_file),
        '--apply',
        '--yes'
    ])

    assert result.exit_code == 0
    assert mock_backup.create_backup.called
    assert mock_client.create_flow.called
```

**Step 2: Implement apply mode**

Modify `src/descope_mgmt/cli/flow.py` to add apply logic.

**Step 3: Commit**

```bash
git add src/descope_mgmt/cli/flow.py tests/integration/test_flow_apply.py
git commit -m "feat: implement flow sync --apply with backup"
```

---

## Chunk Complete Checklist

- [ ] flow sync --apply
- [ ] Auto-backup
- [ ] 5 tests passing
