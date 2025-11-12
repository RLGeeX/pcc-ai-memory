# Chunk 3: Progress Bar Enhancements

**Status:** pending
**Dependencies:** None (UI polish)
**Estimated Time:** 30 minutes

---

## Task 1: Enhanced Progress Tracking

**Files:**
- Modify: `src/descope_mgmt/utils/progress.py`
- Create: `tests/unit/utils/test_progress_enhanced.py`

**Step 1: Write tests**

Create `tests/unit/utils/test_progress_enhanced.py`:
```python
"""Tests for enhanced progress tracking"""
from descope_mgmt.utils.progress import create_progress_with_eta


def test_progress_with_eta():
    """Should create progress bar with ETA"""
    progress = create_progress_with_eta()

    assert progress is not None
    # Should have ETA column
```

**Step 2: Enhance progress utilities**

Modify `src/descope_mgmt/utils/progress.py`:
```python
from rich.progress import TimeRemainingColumn, SpeedColumn

def create_progress_with_eta() -> Progress:
    """Create progress bar with ETA and speed.

    Returns:
        Progress instance with enhanced columns
    """
    return Progress(
        SpinnerColumn(),
        TextColumn("[progress.description]{task.description}"),
        BarColumn(),
        TaskProgressColumn(),
        TimeRemainingColumn(),
        SpeedColumn(),
        console=console
    )
```

**Step 3: Commit**

```bash
git add src/descope_mgmt/utils/progress.py tests/unit/utils/test_progress_enhanced.py
git commit -m "feat: enhance progress bars with ETA and speed"
```

---

## Chunk Complete Checklist

- [ ] Enhanced progress bars
- [ ] ETA display
- [ ] Speed tracking
- [ ] 1 test passing
