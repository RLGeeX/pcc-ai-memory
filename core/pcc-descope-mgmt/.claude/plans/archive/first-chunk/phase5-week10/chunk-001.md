# Chunk 1: User Guide & Tutorials

**Status:** pending
**Dependencies:** phase4-week9 complete
**Estimated Time:** 90 minutes

---

## Task 1: Create Comprehensive User Guide

**Files:**
- Create: `docs/user-guide.md`
- Create: `docs/getting-started.md`
- Create: `docs/workflows.md`
- Create: `docs/troubleshooting.md`

**Step 1: Write user guide**

Create `docs/user-guide.md` (~1000 lines - comprehensive reference).

Create `docs/getting-started.md`:
```markdown
# Getting Started with descope-mgmt

## Installation

```bash
# Mount NFS share (if not already mounted)
# Internal deployment only

# Navigate to project
cd /home/jfogarty/pcc/core/pcc-descope-mgmt

# Activate virtual environment (managed by mise)
mise run activate

# Install in editable mode
pip install -e .
```

## First Steps

### 1. Set Environment Variables

```bash
export DESCOPE_PROJECT_ID="P2your-project-id"
export DESCOPE_MANAGEMENT_KEY="K2your-management-key"
```

### 2. Create Configuration File

Create `descope.yaml`:

```yaml
version: "1.0"
tenants:
  - id: acme-corp
    name: Acme Corporation
    domains:
      - acme.com
    self_provisioning: true
```

### 3. Preview Changes

```bash
descope-mgmt tenant sync --config descope.yaml --dry-run
```

### 4. Apply Changes

```bash
descope-mgmt tenant sync --config descope.yaml --apply
```

## Next Steps

- Read [Workflows](workflows.md) for common scenarios
- See [User Guide](user-guide.md) for complete reference
- Check [Troubleshooting](troubleshooting.md) if you encounter issues
```

Create `docs/workflows.md` with common workflows.

Create `docs/troubleshooting.md` with common issues and solutions.

**Step 2: Add validation test**

Create `tests/documentation/test_docs_validity.py`:
```python
"""Tests for documentation validity"""
import pytest
from pathlib import Path


def test_user_guide_exists():
    """User guide should exist"""
    assert (Path("docs") / "user-guide.md").exists()


def test_getting_started_exists():
    """Getting started guide should exist"""
    assert (Path("docs") / "getting-started.md").exists()
```

**Step 3: Commit**

```bash
git add docs/user-guide.md docs/getting-started.md docs/workflows.md docs/troubleshooting.md
git add tests/documentation/test_docs_validity.py
git commit -m "docs: add comprehensive user guides and tutorials"
```

---

## Chunk Complete Checklist

- [ ] User guide (comprehensive)
- [ ] Getting started tutorial
- [ ] Common workflows
- [ ] Troubleshooting guide
- [ ] 2 validation tests
