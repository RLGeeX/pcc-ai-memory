# Chunk 1: Project Foundation & Setup

**Status:** pending
**Dependencies:** none
**Estimated Time:** 45-60 minutes

---

## Task 1: Initialize Project Structure

**Files:**
- Create: `src/descope_mgmt/__init__.py`
- Create: `src/descope_mgmt/types/__init__.py`
- Create: `src/descope_mgmt/cli/__init__.py`
- Create: `src/descope_mgmt/domain/__init__.py`
- Create: `src/descope_mgmt/domain/models/__init__.py`
- Create: `src/descope_mgmt/domain/services/__init__.py`
- Create: `src/descope_mgmt/domain/operations/__init__.py`
- Create: `src/descope_mgmt/api/__init__.py`
- Create: `src/descope_mgmt/utils/__init__.py`
- Create: `tests/__init__.py`
- Create: `tests/unit/__init__.py`
- Create: `tests/unit/domain/__init__.py`
- Create: `tests/unit/api/__init__.py`
- Create: `tests/unit/utils/__init__.py`

**Step 1: Create directory structure**

```bash
mkdir -p src/descope_mgmt/{types,cli,domain/{models,services,operations},api,utils}
mkdir -p tests/{unit/{domain,api,utils},integration,performance}
```

**Step 2: Create __init__.py files**

```bash
touch src/descope_mgmt/__init__.py
touch src/descope_mgmt/{types,cli,domain,api,utils}/__init__.py
touch src/descope_mgmt/domain/{models,services,operations}/__init__.py
touch tests/__init__.py
touch tests/unit/__init__.py
touch tests/unit/{domain,api,utils}/__init__.py
```

**Step 3: Add version to main __init__.py**

Create `src/descope_mgmt/__init__.py`:
```python
"""Descope Management CLI Tool"""

__version__ = "1.0.0"
```

**Step 4: Verify structure**

Run: `tree src/descope_mgmt tests -I __pycache__`

Expected: Directory structure matches design document (CLI → Domain → API layers)

**Step 5: Commit**

```bash
git add src/ tests/
git commit -m "feat: initialize project directory structure"
```

---

## Task 2: Configure pyproject.toml

**Files:**
- Modify: `pyproject.toml`

**Step 1: Update pyproject.toml with package metadata**

Replace contents with:
```toml
[build-system]
requires = ["setuptools>=68.0"]
build-backend = "setuptools.build_meta"

[project]
name = "descope-mgmt"
version = "1.0.0"
description = "CLI tool for managing Descope authentication infrastructure"
readme = "README.md"
requires-python = ">=3.12"
authors = [
    {name = "PortCo Connect Team", email = "engineering@pcconnect.ai"}
]
classifiers = [
    "Development Status :: 4 - Beta",
    "Intended Audience :: Developers",
    "Programming Language :: Python :: 3.12",
    "Topic :: System :: Systems Administration"
]

dependencies = [
    "click>=8.1.0",
    "pydantic>=2.5.0",
    "pyyaml>=6.0",
    "descope>=1.7.12",
    "rich>=13.0.0",
    "structlog>=23.0.0",
    "pyrate-limiter>=3.1.0",
    "python-dotenv>=1.0.0",
]

[project.optional-dependencies]
dev = [
    "pytest>=7.0.0",
    "pytest-cov>=4.0.0",
    "pytest-mock>=3.12.0",
    "psutil>=5.9.0",
    "ruff>=0.1.0",
    "mypy>=1.0.0",
    "pre-commit>=3.0.0",
    "types-pyyaml>=6.0.0",
    "types-requests>=2.31.0",
]

[project.scripts]
descope-mgmt = "descope_mgmt.cli.main:cli"

[tool.setuptools.packages.find]
where = ["src"]

[tool.ruff]
line-length = 100
target-version = "py312"
src = ["src", "tests"]

[tool.ruff.lint]
select = ["E", "F", "I", "N", "W", "B", "UP"]
ignore = ["E501"]

[tool.mypy]
python_version = "3.12"
strict = true
warn_return_any = true
warn_unused_configs = true
disallow_untyped_defs = true
files = ["src"]

[[tool.mypy.overrides]]
module = "descope.*"
ignore_missing_imports = true

[tool.pytest.ini_options]
testpaths = ["tests"]
python_files = "test_*.py"
python_classes = "Test*"
python_functions = "test_*"
addopts = "-v --strict-markers"
markers = [
    "integration: integration tests with real API",
    "real_api: tests requiring Descope API credentials",
    "performance: performance benchmarking tests"
]

[tool.coverage.run]
source = ["src/descope_mgmt"]
omit = ["tests/*"]

[tool.coverage.report]
exclude_lines = [
    "pragma: no cover",
    "def __repr__",
    "raise NotImplementedError",
    "if TYPE_CHECKING:",
    "if __name__ == .__main__.:",
]
```

**Step 2: Verify configuration**

Run: `cat pyproject.toml`

Expected: All dependencies listed, entry point configured

**Step 3: Commit**

```bash
git add pyproject.toml
git commit -m "feat: configure pyproject.toml with dependencies and metadata"
```

---

## Task 3: Update requirements.txt

**Files:**
- Modify: `requirements.txt`

**Step 1: Add pyrate-limiter dependency**

Add to `requirements.txt`:
```
pyrate-limiter>=3.1.0
```

**Step 2: Verify dependencies**

Run: `cat requirements.txt`

Expected: pyrate-limiter>=3.1.0 present

**Step 3: Commit**

```bash
git add requirements.txt
git commit -m "feat: add pyrate-limiter to requirements"
```

---

## Task 4: Install Dependencies

**Files:**
- None (installation only)

**Step 1: Install package in editable mode**

Run: `pip install -e .[dev]`

Expected: All dependencies install successfully

**Step 2: Verify installation**

Run: `pip list | grep -E '(click|pydantic|pyrate-limiter|descope)'`

Expected: All core packages installed

**Step 3: Verify entry point**

Run: `which descope-mgmt`

Expected: Command found in PATH

---

## Task 5: Configure Pre-commit Hooks

**Files:**
- Create: `.pre-commit-config.yaml`

**Step 1: Create pre-commit configuration**

Create `.pre-commit-config.yaml`:
```yaml
repos:
  - repo: local
    hooks:
      - id: pytest-unit
        name: Run unit tests
        entry: pytest tests/unit/ -v
        language: system
        pass_filenames: false
        stages: [commit]

      - id: ruff-format
        name: Format with ruff
        entry: ruff format .
        language: system
        types: [python]
        stages: [commit]

      - id: ruff-check
        name: Lint with ruff
        entry: ruff check .
        language: system
        types: [python]
        stages: [commit]

      - id: mypy
        name: Type check with mypy
        entry: mypy src/
        language: system
        pass_filenames: false
        types: [python]
        stages: [commit]
```

**Step 2: Install pre-commit hooks**

Run: `pre-commit install`

Expected: "pre-commit installed at .git/hooks/pre-commit"

**Step 3: Test pre-commit (will fail - no tests yet)**

Run: `pre-commit run --all-files || true`

Expected: Hooks run but may fail (no tests exist yet)

**Step 4: Commit**

```bash
git add .pre-commit-config.yaml
git commit -m "feat: add pre-commit hooks for testing and linting"
```

---

## Task 6: Configure Editor Settings

**Files:**
- Verify: `.editorconfig` exists

**Step 1: Verify .editorconfig**

Run: `cat .editorconfig`

Expected: File exists with Python settings (from project root)

**Step 2: Create .gitignore additions**

Verify `.gitignore` includes:
```
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
env/
venv/
.venv/
*.egg-info/
dist/
build/
.pytest_cache/
.coverage
htmlcov/
.mypy_cache/
.ruff_cache/
.env
.vscode/
.idea/
```

**Step 3: Commit if changes needed**

```bash
git add .gitignore
git commit -m "chore: update gitignore for Python project" || echo "No changes needed"
```

---

## Task 7: Create README Stub

**Files:**
- Modify: `README.md`

**Step 1: Update README with basic structure**

Replace/update `README.md`:
```markdown
# pcc-descope-mgmt

CLI tool for managing Descope authentication infrastructure using configuration-as-code.

## Overview

`pcc-descope-mgmt` enables declarative management of Descope projects, tenants, and authentication flows across multiple environments (test, devtest, dev, staging, prod).

## Installation

```bash
cd /home/jfogarty/pcc/core/pcc-descope-mgmt
pip install -e .[dev]
```

## Quick Start

```bash
# List tenants
descope-mgmt tenant list

# Sync tenants from config (dry-run)
descope-mgmt tenant sync --config descope.yaml --dry-run

# Apply changes
descope-mgmt tenant sync --config descope.yaml
```

## Development

**Run tests:**
```bash
pytest tests/unit/ -v
```

**Format code:**
```bash
ruff format .
```

**Type check:**
```bash
mypy src/
```

## Documentation

See `.claude/plans/design.md` for complete design documentation.

## Status

🚧 **Phase 1 Week 1** - Foundation in progress

Target: 40+ unit tests passing by end of week
```

**Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add README with installation and quick start"
```

---

## Chunk Complete Checklist

- [ ] Directory structure created (types/, cli/, domain/, api/, utils/)
- [ ] pyproject.toml configured with dependencies
- [ ] requirements.txt updated with pyrate-limiter
- [ ] Dependencies installed (pip install -e .[dev])
- [ ] Pre-commit hooks configured and installed
- [ ] .gitignore verified
- [ ] README updated
- [ ] All commits made with conventional commit messages
