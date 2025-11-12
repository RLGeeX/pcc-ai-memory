# Chunk 4: Error Reporting Improvements

**Status:** pending
**Dependencies:** chunk-001, chunk-002, chunk-003
**Estimated Time:** 30 minutes

---

## Task 1: Enhanced Error Messages

**Files:**
- Modify: `src/descope_mgmt/cli/common.py`
- Create: `tests/unit/cli/test_error_reporting.py`

**Step 1: Write tests**

Create `tests/unit/cli/test_error_reporting.py`:
```python
"""Tests for error reporting"""
from descope_mgmt.cli.common import format_error_with_suggestion


def test_error_with_suggestion():
    """Should format error with actionable suggestion"""
    result = format_error_with_suggestion(
        error="Tenant ID already exists",
        suggestion="Use 'tenant update' instead",
        command="descope-mgmt tenant update --tenant-id acme-corp"
    )

    assert "already exists" in result
    assert "tenant update" in result
    assert "descope-mgmt" in result
```

**Step 2: Implement enhanced error formatting**

Modify `src/descope_mgmt/cli/common.py`:
```python
def format_error_with_suggestion(
    error: str,
    suggestion: str | None = None,
    command: str | None = None
) -> str:
    """Format error with actionable suggestion.

    Args:
        error: Error message
        suggestion: Suggested action
        command: Example command

    Returns:
        Formatted error message
    """
    message = f"[red]✗ Error:[/red] {error}"

    if suggestion:
        message += f"\n[yellow]💡 Suggestion:[/yellow] {suggestion}"

    if command:
        message += f"\n[cyan]Command:[/cyan] {command}"

    return message
```

**Step 3: Commit**

```bash
git add src/descope_mgmt/cli/common.py tests/unit/cli/test_error_reporting.py
git commit -m "feat: add error messages with actionable suggestions"
```

---

## Chunk Complete Checklist

- [ ] Enhanced error formatting
- [ ] Actionable suggestions
- [ ] Example commands
- [ ] 2 tests passing
- [ ] **Phase 3 Week 8 COMPLETE**
