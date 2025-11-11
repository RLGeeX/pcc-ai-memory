# Chunk 3: State Recovery

**Status:** pending
**Dependencies:** chunk-001, chunk-002
**Estimated Time:** 45 minutes

---

## Task 1: Implement State Checkpointing

**Files:**
- Create: `src/descope_mgmt/utils/checkpoint.py`
- Create: `tests/unit/utils/test_checkpoint.py`

**Step 1: Write tests**

Create `tests/unit/utils/test_checkpoint.py`:
```python
"""Tests for state checkpointing"""
import pytest
from pathlib import Path
from descope_mgmt.utils.checkpoint import CheckpointManager


def test_save_and_load_checkpoint(tmp_path):
    """Should save and load checkpoint"""
    manager = CheckpointManager(checkpoint_dir=tmp_path)

    state = {
        "operation": "tenant_sync",
        "completed": ["acme-corp", "widget-co"],
        "remaining": ["test-co"]
    }

    manager.save_checkpoint("sync-123", state)

    loaded = manager.load_checkpoint("sync-123")
    assert loaded["completed"] == ["acme-corp", "widget-co"]
```

**Step 2: Implement checkpoint manager**

Create `src/descope_mgmt/utils/checkpoint.py`:
```python
"""State checkpointing for recovery."""
import json
from pathlib import Path


class CheckpointManager:
    """Manages operation checkpoints for recovery."""

    def __init__(self, checkpoint_dir: Path | None = None):
        if checkpoint_dir is None:
            checkpoint_dir = Path.home() / ".descope-mgmt" / "checkpoints"

        self.checkpoint_dir = Path(checkpoint_dir)
        self.checkpoint_dir.mkdir(parents=True, exist_ok=True)

    def save_checkpoint(self, operation_id: str, state: dict) -> None:
        """Save checkpoint for operation."""
        checkpoint_file = self.checkpoint_dir / f"{operation_id}.json"
        with open(checkpoint_file, 'w') as f:
            json.dump(state, f, indent=2)

    def load_checkpoint(self, operation_id: str) -> dict | None:
        """Load checkpoint for operation."""
        checkpoint_file = self.checkpoint_dir / f"{operation_id}.json"
        if not checkpoint_file.exists():
            return None

        with open(checkpoint_file) as f:
            return json.load(f)

    def clear_checkpoint(self, operation_id: str) -> None:
        """Clear checkpoint after successful completion."""
        checkpoint_file = self.checkpoint_dir / f"{operation_id}.json"
        if checkpoint_file.exists():
            checkpoint_file.unlink()
```

**Step 3: Commit**

```bash
git add src/descope_mgmt/utils/checkpoint.py tests/unit/utils/test_checkpoint.py
git commit -m "feat: add state checkpointing for recovery"
```

---

## Chunk Complete Checklist

- [ ] CheckpointManager
- [ ] Save/load/clear operations
- [ ] 2 tests passing
