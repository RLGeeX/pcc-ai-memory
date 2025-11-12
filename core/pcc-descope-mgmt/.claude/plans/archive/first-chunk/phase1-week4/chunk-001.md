# Chunk 1: Flow State Models

**Status:** pending
**Dependencies:** phase1-week3 complete
**Estimated Time:** 45-60 minutes

---

## Task 1: Create Flow State Models

**Files:**
- Create: `src/descope_mgmt/domain/models/flow_state.py`
- Create: `tests/unit/domain/test_flow_state.py`

**Step 1: Write failing tests**

Create `tests/unit/domain/test_flow_state.py`:
```python
"""Tests for flow state models"""
import pytest
from datetime import datetime
from descope_mgmt.domain.models.flow_state import FlowState, FlowDiff
from descope_mgmt.domain.models.diff import ChangeType, FieldDiff


def test_flow_state_creation():
    """Should create immutable flow state"""
    flow = FlowState(
        flow_id="sign-up-or-in",
        name="Sign Up or In",
        screens=[{"id": "email"}],
        metadata={"version": "1.0"},
        created_at=datetime.now(),
        updated_at=datetime.now()
    )

    assert flow.flow_id == "sign-up-or-in"
    assert len(flow.screens) == 1


def test_flow_diff_creation():
    """Should create flow diff with changes"""
    diff = FlowDiff(
        flow_id="sign-up-or-in",
        change_type=ChangeType.UPDATE,
        field_diffs=[
            FieldDiff("name", "Old", "New")
        ]
    )

    assert diff.flow_id == "sign-up-or-in"
    assert diff.change_type == ChangeType.UPDATE
    assert len(diff.field_diffs) == 1
```

**Step 2: Implement flow state models**

Create `src/descope_mgmt/domain/models/flow_state.py`:
```python
"""Flow state models."""
from dataclasses import dataclass
from datetime import datetime
from typing import Any
from descope_mgmt.domain.models.diff import ChangeType, FieldDiff


@dataclass(frozen=True)
class FlowState:
    """Current state of a flow from Descope API."""
    flow_id: str
    name: str
    screens: list[dict[str, Any]]
    metadata: dict[str, Any]
    created_at: datetime
    updated_at: datetime


@dataclass(frozen=True)
class FlowDiff:
    """Difference between current and desired flow state."""
    flow_id: str
    change_type: ChangeType
    field_diffs: list[FieldDiff]
```

**Step 3: Commit**

```bash
git add src/descope_mgmt/domain/models/flow_state.py tests/unit/domain/test_flow_state.py
git commit -m "feat: add flow state models"
```

---

## Task 2: Add Flow Backup Schema

**Files:**
- Modify: `src/descope_mgmt/domain/models/backup.py`
- Create: `tests/unit/domain/test_flow_backup.py`

**Step 1: Write test**

Create `tests/unit/domain/test_flow_backup.py`:
```python
"""Tests for flow backup"""
from datetime import datetime
from descope_mgmt.domain.models.backup import FlowBackup, BackupMetadata


def test_flow_backup_creation():
    """Should create flow backup"""
    backup = FlowBackup(
        flow_id="sign-up-or-in",
        flow_data={"screens": []},
        metadata=BackupMetadata(
            timestamp=datetime.now(),
            project_id="P2test",
            environment="test"
        )
    )

    assert backup.flow_id == "sign-up-or-in"
    assert "screens" in backup.flow_data
```

**Step 2: Run test (should pass - FlowBackup already exists from Week 3)**

**Step 3: Commit**

```bash
git add tests/unit/domain/test_flow_backup.py
git commit -m "test: add flow backup tests"
```

---

## Chunk Complete Checklist

- [ ] FlowState model (frozen dataclass)
- [ ] FlowDiff model
- [ ] Flow backup tests
- [ ] All commits made
- [ ] 6 tests passing total
