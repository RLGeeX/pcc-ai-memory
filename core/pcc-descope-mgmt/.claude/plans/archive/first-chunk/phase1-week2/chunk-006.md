# Chunk 6: Rich Output Formatting

**Status:** pending
**Dependencies:** chunk-001, chunk-002, chunk-003, chunk-004, chunk-005
**Estimated Time:** 30 minutes

---

## Task 1: Create Rich Output Utilities

**Files:**
- Create: `src/descope_mgmt/utils/display.py`
- Create: `tests/unit/utils/test_display.py`

**Step 1: Write failing tests**

Create `tests/unit/utils/test_display.py`:
```python
"""Tests for display utilities"""
import pytest
from descope_mgmt.utils.display import (
    format_tenant_table,
    format_diff_display,
    format_progress_bar
)
from descope_mgmt.domain.models.state import TenantState
from descope_mgmt.domain.models.diff import TenantDiff, ChangeType, FieldDiff
from datetime import datetime


def test_format_tenant_table():
    """Should format tenants as Rich table"""
    tenants = [
        TenantState(
            id="acme-corp",
            name="Acme Corporation",
            domains=["acme.com"],
            self_provisioning=True,
            custom_attributes={},
            created_at=datetime.now(),
            updated_at=datetime.now()
        )
    ]

    table = format_tenant_table(tenants)
    # Table is a Rich Table object
    assert table is not None
    assert hasattr(table, 'columns')


def test_format_diff_display_create():
    """Should format create diff"""
    diff = TenantDiff(
        tenant_id="acme-corp",
        change_type=ChangeType.CREATE,
        field_diffs=[]
    )

    output = format_diff_display(diff)
    assert "CREATE" in output or "+" in output
    assert "acme-corp" in output


def test_format_diff_display_update():
    """Should format update diff with field changes"""
    diff = TenantDiff(
        tenant_id="acme-corp",
        change_type=ChangeType.UPDATE,
        field_diffs=[
            FieldDiff("name", "Old Name", "New Name"),
            FieldDiff("domains", [], ["acme.com"])
        ]
    )

    output = format_diff_display(diff)
    assert "UPDATE" in output or "~" in output
    assert "name" in output
    assert "Old Name" in output
    assert "New Name" in output


def test_format_progress_bar():
    """Should create progress bar"""
    from rich.progress import Progress

    progress = format_progress_bar()
    assert isinstance(progress, Progress)
```

**Step 2: Run tests to verify they fail**

Run: `pytest tests/unit/utils/test_display.py -v`

Expected: FAIL with import errors

**Step 3: Implement display utilities**

Create `src/descope_mgmt/utils/display.py`:
```python
"""Rich terminal display utilities."""
from rich.table import Table
from rich.progress import Progress, SpinnerColumn, TextColumn, BarColumn, TaskProgressColumn
from rich.console import Console
from descope_mgmt.domain.models.state import TenantState
from descope_mgmt.domain.models.diff import TenantDiff, ChangeType

console = Console()


def format_tenant_table(tenants: list[TenantState]) -> Table:
    """Format tenants as Rich table.

    Args:
        tenants: List of tenant states

    Returns:
        Rich Table object
    """
    table = Table(title=f"Tenants ({len(tenants)})")
    table.add_column("ID", style="cyan", no_wrap=True)
    table.add_column("Name", style="green")
    table.add_column("Domains", style="yellow")
    table.add_column("Self-Prov", style="magenta", justify="center")
    table.add_column("Custom Attrs", style="dim")

    for tenant in tenants:
        table.add_row(
            tenant.id,
            tenant.name,
            ", ".join(tenant.domains) if tenant.domains else "-",
            "✓" if tenant.self_provisioning else "-",
            str(len(tenant.custom_attributes)) if tenant.custom_attributes else "-"
        )

    return table


def format_diff_display(diff: TenantDiff) -> str:
    """Format tenant diff for display.

    Args:
        diff: Tenant diff object

    Returns:
        Formatted string
    """
    if diff.change_type == ChangeType.CREATE:
        return f"[green]+ CREATE[/green] {diff.tenant_id}"
    elif diff.change_type == ChangeType.UPDATE:
        result = f"[blue]~ UPDATE[/blue] {diff.tenant_id}\n"
        for field_diff in diff.field_diffs:
            result += f"    {field_diff.field_name}: {field_diff.old_value} → {field_diff.new_value}\n"
        return result.rstrip()
    elif diff.change_type == ChangeType.DELETE:
        return f"[red]- DELETE[/red] {diff.tenant_id}"
    else:
        return f"  {diff.tenant_id} (no change)"


def format_progress_bar() -> Progress:
    """Create Rich progress bar.

    Returns:
        Progress object with custom columns
    """
    return Progress(
        SpinnerColumn(),
        TextColumn("[progress.description]{task.description}"),
        BarColumn(),
        TaskProgressColumn(),
        console=console
    )
```

**Step 4: Run tests to verify they pass**

Run: `pytest tests/unit/utils/test_display.py -v`

Expected: PASS (all 4 tests)

**Step 5: Commit**

```bash
git add src/descope_mgmt/utils/display.py tests/unit/utils/test_display.py
git commit -m "feat: add Rich terminal display utilities"
```

---

## Task 2: Update Utils Module Exports

**Files:**
- Modify: `src/descope_mgmt/utils/__init__.py`

**Step 1: Add display utilities to exports**

Modify `src/descope_mgmt/utils/__init__.py`:
```python
"""Utility modules for descope-mgmt."""
from descope_mgmt.utils.config_loader import ConfigLoader
from descope_mgmt.utils.env_vars import substitute_env_vars
from descope_mgmt.utils.logging import configure_logging
from descope_mgmt.utils.display import (
    format_tenant_table,
    format_diff_display,
    format_progress_bar
)

__all__ = [
    "ConfigLoader",
    "substitute_env_vars",
    "configure_logging",
    "format_tenant_table",
    "format_diff_display",
    "format_progress_bar",
]
```

**Step 2: Commit**

```bash
git add src/descope_mgmt/utils/__init__.py
git commit -m "feat: export display utilities from utils module"
```

---

## Chunk Complete Checklist

- [ ] Rich display utilities (4 tests)
- [ ] format_tenant_table with colored columns
- [ ] format_diff_display with change types
- [ ] format_progress_bar for async operations
- [ ] Utils module exports updated
- [ ] All commits made
- [ ] **Phase 1 Week 2 COMPLETE**
