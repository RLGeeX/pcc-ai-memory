# Chunk 2: API Documentation & Runbooks

**Status:** pending
**Dependencies:** chunk-001
**Estimated Time:** 60 minutes

---

## Task 1: API Reference Documentation

**Files:**
- Create: `docs/api-reference.md`
- Create: `docs/architecture.md`
- Create: `docs/runbooks/emergency-rollback.md`
- Create: `docs/runbooks/new-environment.md`
- Create: `docs/runbooks/new-tenant.md`

**Step 1: Write API documentation**

Create `docs/api-reference.md`:
```markdown
# API Reference

## Module: descope_mgmt.cli

### Commands

#### tenant list
List all tenants in project.

**Usage:**
```bash
descope-mgmt tenant list [--environment ENV]
```

**Options:**
- `--environment`: Filter by environment

#### tenant sync
Sync tenants to match configuration.

**Usage:**
```bash
descope-mgmt tenant sync --config FILE [--dry-run] [--apply] [--yes]
```

... (continue for all commands)

## Module: descope_mgmt.domain

### Services

#### BackupService
Create and manage backups.

**Methods:**
- `create_backup(project_id, environment, config)`: Create backup
- `list_backups(project_id)`: List available backups
- `cleanup_old_backups(project_id)`: Remove old backups

... (continue for all services)
```

**Step 2: Write runbooks**

Create `docs/runbooks/emergency-rollback.md`:
```markdown
# Emergency Rollback Procedure

## When to Use
Use this runbook when you need to immediately rollback a failed change.

## Prerequisites
- Backup was created before the change
- You have the backup timestamp

## Steps

### 1. List Available Backups
```bash
ls ~/.descope-mgmt/backups/P2your-project-id/
```

### 2. Identify Backup to Restore
```bash
# Backups are named with timestamp: YYYYMMDD_HHMMSS
# Example: 20250115_143000
```

### 3. Restore Backup
```bash
# For tenant rollback
descope-mgmt tenant rollback --backup ~/.descope-mgmt/backups/P2test/20250115_143000

# For flow rollback
descope-mgmt flow rollback --flow-id FLOW_ID --backup PATH
```

### 4. Verify Restoration
```bash
descope-mgmt tenant list
descope-mgmt drift detect --config descope.yaml
```

## Troubleshooting
- If backup not found: Check backup directory path
- If restore fails: Review audit logs for details
```

Create similar runbooks for other scenarios.

**Step 3: Add validation test**

Create `tests/documentation/test_runbooks.py`:
```python
"""Tests for runbook validity"""
from pathlib import Path


def test_emergency_rollback_runbook_exists():
    """Emergency rollback runbook should exist"""
    assert (Path("docs/runbooks") / "emergency-rollback.md").exists()
```

**Step 4: Commit**

```bash
git add docs/api-reference.md docs/architecture.md docs/runbooks/
git add tests/documentation/test_runbooks.py
git commit -m "docs: add API reference and operational runbooks"
```

---

## Chunk Complete Checklist

- [ ] API reference documentation
- [ ] Architecture documentation
- [ ] Emergency rollback runbook
- [ ] New environment runbook
- [ ] New tenant runbook
- [ ] 2 validation tests
