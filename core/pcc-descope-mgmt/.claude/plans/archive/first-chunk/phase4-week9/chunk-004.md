# Chunk 4: Help Text & Documentation

**Status:** pending
**Dependencies:** None (documentation)
**Estimated Time:** 30 minutes

---

## Task 1: Comprehensive Help Text

**Files:**
- Modify: `src/descope_mgmt/cli/tenant.py`
- Modify: `src/descope_mgmt/cli/flow.py`
- Create: `tests/unit/cli/test_help_text.py`

**Step 1: Write test**

Create `tests/unit/cli/test_help_text.py`:
```python
"""Tests for help text"""
from click.testing import CliRunner
from descope_mgmt.cli.main import cli


def test_tenant_sync_help_has_examples():
    """Should show examples in help text"""
    runner = CliRunner()
    result = runner.invoke(cli, ['tenant', 'sync', '--help'])

    assert result.exit_code == 0
    assert "Examples:" in result.output or "descope-mgmt" in result.output
```

**Step 2: Enhance help text**

Modify command docstrings to include examples:

```python
@tenant.command()
@click.option('--dry-run', is_flag=True, help='Preview changes without applying')
@click.option('--yes', is_flag=True, help='Skip confirmation prompts')
@click.pass_context
def sync(ctx: click.Context, dry_run: bool, yes: bool) -> None:
    """Sync tenants to match configuration

    Idempotent operation that creates, updates, or deletes tenants
    to match the desired state in the configuration file.

    \b
    Examples:
      # Preview changes
      descope-mgmt tenant sync --config descope.yaml --dry-run

      # Apply changes
      descope-mgmt tenant sync --config descope.yaml --apply

      # Skip confirmation
      descope-mgmt tenant sync --config descope.yaml --apply --yes

      # Specific environment
      descope-mgmt tenant sync --environment prod --apply
    """
    # ... implementation
```

**Step 3: Commit**

```bash
git add src/descope_mgmt/cli/tenant.py src/descope_mgmt/cli/flow.py tests/unit/cli/test_help_text.py
git commit -m "docs: add examples to help text"
```

---

## Chunk Complete Checklist

- [ ] Examples in --help
- [ ] Comprehensive command documentation
- [ ] 1 test passing
- [ ] **Phase 4 Week 9 COMPLETE**
