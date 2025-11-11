# Chunk 2: Partial Failure Handling

**Status:** pending
**Dependencies:** chunk-001
**Estimated Time:** 60 minutes

---

## Task 1: Implement Continue-on-Error Mode

**Files:**
- Modify: `src/descope_mgmt/cli/tenant.py`
- Create: `tests/integration/test_continue_on_error.py`

**Step 1: Write tests**

Create `tests/integration/test_continue_on_error.py`:
```python
"""Integration tests for continue-on-error"""
import pytest
from unittest.mock import Mock, patch
from click.testing import CliRunner
from descope_mgmt.cli.main import cli


@patch('descope_mgmt.cli.tenant.DescopeApiClient')
def test_continue_on_error_mode(mock_client_class, tmp_path):
    """Should continue processing even if some operations fail"""
    # Mock client with one failure
    mock_client = Mock()
    mock_client.create_tenant.side_effect = [
        True,  # Success
        Exception("API error"),  # Failure
        True  # Success
    ]
    mock_client_class.return_value = mock_client

    runner = CliRunner()
    result = runner.invoke(cli, [
        'tenant', 'sync',
        '--config', 'test.yaml',
        '--apply',
        '--continue-on-error',
        '--yes'
    ])

    # Should have attempted all operations
    assert mock_client.create_tenant.call_count == 3
    # Should show partial success
    assert "2 succeeded" in result.output or "partial" in result.output.lower()
```

**Step 2: Implement continue-on-error**

Modify `src/descope_mgmt/cli/tenant.py` to add `--continue-on-error` flag and error aggregation logic.

**Step 3: Commit**

```bash
git add src/descope_mgmt/cli/tenant.py tests/integration/test_continue_on_error.py
git commit -m "feat: add continue-on-error mode for batch operations"
```

---

## Chunk Complete Checklist

- [ ] --continue-on-error flag
- [ ] Error aggregation
- [ ] Partial success reporting
- [ ] 5 tests passing
