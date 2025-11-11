# Chunk 3: Internal Training & Deployment

**Status:** pending
**Dependencies:** chunk-001, chunk-002
**Estimated Time:** 60 minutes

---

## Task 1: Training Materials and Deployment Guide

**Files:**
- Create: `docs/training.md`
- Create: `docs/deployment.md`
- Create: `docs/migration-guide.md`
- Create: `examples/descope.yaml`
- Create: `examples/descope-prod.yaml`
- Create: `examples/.env.example`

**Step 1: Write training materials**

Create `docs/training.md`:
```markdown
# Training Guide for descope-mgmt

## Tool Overview

descope-mgmt is a CLI tool for managing Descope authentication infrastructure across 5 environments (test, devtest, dev, staging, prod).

**What it does:**
- Manages tenants (portfolio companies) across environments
- Deploys authentication flows
- Detects configuration drift
- Creates automatic backups

**What it does NOT do:**
- SSO configuration (manual only)
- User creation/management
- CI/CD pipelines (local testing only)

## Hands-On Exercises

### Exercise 1: List Tenants
```bash
# Set credentials
export DESCOPE_PROJECT_ID="P2test123"
export DESCOPE_MANAGEMENT_KEY="K2your-key"

# List tenants
descope-mgmt tenant list
```

### Exercise 2: Create Test Tenant
```bash
descope-mgmt tenant create \
  --tenant-id test-corp \
  --name "Test Corporation" \
  --yes
```

### Exercise 3: Detect Drift
```bash
descope-mgmt drift detect --config examples/descope.yaml
```

## Common Pitfalls

1. **Forgetting --yes flag**: All destructive operations require confirmation
2. **Wrong environment variables**: Must set both PROJECT_ID and MANAGEMENT_KEY
3. **SSO expectations**: SSO config is manual - don't expect tool to automate it

## Best Practices

1. **Always dry-run first**: Use `--dry-run` before `--apply`
2. **Review backups**: Check `~/.descope-mgmt/backups/` regularly
3. **Check drift weekly**: Run `drift detect` on Mondays
```

**Step 2: Write deployment guide**

Create `docs/deployment.md`:
```markdown
# Deployment Guide (Internal - 2 Person Team)

## NFS Mount Setup

```bash
# Tool is accessed via NFS mount
# No PyPI or git distribution needed

# Location: /home/jfogarty/pcc/core/pcc-descope-mgmt
```

## Installation Steps

### 1. Create Virtual Environment
```bash
cd /home/jfogarty/pcc/core/pcc-descope-mgmt

# Use mise to manage Python version
mise use python@3.12

# Create venv (mise handles this)
mise run venv
```

### 2. Install Dependencies
```bash
mise run install

# Or manually:
pip install -e .
```

### 3. Install Pre-Commit Hooks
```bash
pre-commit install
```

### 4. Verify Installation
```bash
descope-mgmt --version
descope-mgmt --help
```

## Environment Setup

Create `~/.bashrc` or `~/.zshrc` entries:

```bash
# Descope Management Tool
export DESCOPE_PROJECT_ID="P2your-test-project"
export DESCOPE_MANAGEMENT_KEY="K2your-test-key"

# Optional: Add to PATH if not using mise
# export PATH="/home/jfogarty/pcc/core/pcc-descope-mgmt/.venv/bin:$PATH"
```

## Verification

Run integration tests:
```bash
pytest tests/integration/ -v
```

Expected: All tests pass (or skip if no Descope test project configured)
```

**Step 3: Create examples**

Create `examples/descope.yaml`:
```yaml
version: "1.0"

# Example configuration for portfolio companies
tenants:
  # Acme Corporation
  - id: acme-corp
    name: Acme Corporation
    domains:
      - acme.com
      - acme.net
    self_provisioning: true

  # Widget Company
  - id: widget-co
    name: Widget Company
    domains:
      - widget.com
    self_provisioning: false
    custom_attributes:
      industry: "Manufacturing"
      tier: "Enterprise"

  # Startup Inc
  - id: startup-inc
    name: Startup Inc
    self_provisioning: true
```

Create `examples/.env.example`:
```bash
# Descope Project Credentials
DESCOPE_PROJECT_ID=P2your-project-id-here
DESCOPE_MANAGEMENT_KEY=K2your-management-key-here

# Optional: Override backup location
# DESCOPE_BACKUP_DIR=/custom/backup/path
```

**Step 4: Add validation test**

Create `tests/documentation/test_deployment.py`:
```python
"""Tests for deployment documentation"""
from pathlib import Path


def test_deployment_guide_exists():
    """Deployment guide should exist"""
    assert (Path("docs") / "deployment.md").exists()


def test_example_config_exists():
    """Example config should exist"""
    assert (Path("examples") / "descope.yaml").exists()
```

**Step 5: Commit**

```bash
git add docs/training.md docs/deployment.md docs/migration-guide.md
git add examples/
git add tests/documentation/test_deployment.py
git commit -m "docs: add training materials and deployment guide"
```

**Step 6: Final verification**

Run all tests:
```bash
pytest tests/ -v
```

Expected: 241+ tests passing

---

## Chunk Complete Checklist

- [ ] Training materials written
- [ ] Deployment guide complete
- [ ] Example configurations provided
- [ ] Validation test passing
- [ ] **Phase 5 Week 10 COMPLETE**
- [ ] **PROJECT v1.0 COMPLETE**
- [ ] 241+ tests passing total
