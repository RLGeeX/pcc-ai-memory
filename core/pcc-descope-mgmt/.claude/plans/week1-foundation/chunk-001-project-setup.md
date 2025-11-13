# Chunk 1: Project Setup and Directory Structure

**Status:** pending
**Dependencies:** none
**Complexity:** simple
**Estimated Time:** 10-15 minutes
**Tasks:** 3

---

## Task 1: Create Project Directory Structure

**Files:**
- Create: `src/descope_mgmt/__init__.py`
- Create: `src/descope_mgmt/types/__init__.py`
- Create: `src/descope_mgmt/domain/__init__.py`
- Create: `src/descope_mgmt/api/__init__.py`
- Create: `src/descope_mgmt/cli/__init__.py`
- Create: `tests/__init__.py`
- Create: `tests/unit/__init__.py`
- Create: `tests/integration/__init__.py`
- Create: `tests/fakes.py`

**Step 1: Create directory structure**

```bash
cd /home/jfogarty/pcc/core/pcc-descope-mgmt

mkdir -p src/descope_mgmt/{types,domain,api,cli}
mkdir -p tests/{unit,integration}

touch src/descope_mgmt/__init__.py
touch src/descope_mgmt/types/__init__.py
touch src/descope_mgmt/domain/__init__.py
touch src/descope_mgmt/api/__init__.py
touch src/descope_mgmt/cli/__init__.py
touch tests/__init__.py
touch tests/unit/__init__.py
touch tests/integration/__init__.py
touch tests/fakes.py
```

**Step 2: Add package version**

Create `src/descope_mgmt/__init__.py`:
```python
"""Descope Management CLI - Infrastructure-as-code for Descope authentication."""

__version__ = "0.1.0"
```

**Step 3: Commit**

```bash
git add src/ tests/
git commit -m "feat: create project structure with 4-layer architecture"
```

---

## Task 2: Configure pyproject.toml

**Files:**
- Modify: `pyproject.toml` (replace entire file)

**Step 1: Write complete pyproject.toml**

```toml
[build-system]
requires = ["setuptools>=61.0", "wheel"]
build-backend = "setuptools.build_meta"

[project]
name = "descope-mgmt"
version = "0.1.0"
description = "Infrastructure-as-code CLI for managing Descope authentication"
readme = "README.md"
requires-python = ">=3.12"
license = {text = "MIT"}
authors = [
    {name = "Your Name", email = "your.email@example.com"}
]
dependencies = [
    "descope>=0.9.0",
    "click>=8.1.0",
    "pydantic>=2.0.0",
    "pyyaml>=6.0",
    "requests>=2.31.0",
    "pyrate-limiter>=3.0.0",
    "rich>=13.0.0",
    "python-dotenv>=1.0.0",
    "import-linter>=2.0",
]

[project.optional-dependencies]
dev = [
    "pytest>=7.4.0",
    "pytest-cov>=4.1.0",
    "mypy>=1.5.0",
    "ruff>=0.1.0",
    "types-pyyaml>=6.0.12",
    "types-requests>=2.31.0",
]

[project.scripts]
descope-mgmt = "descope_mgmt.cli.main:cli"

[tool.setuptools.packages.find]
where = ["src"]

[tool.ruff]
target-version = "py312"
line-length = 88
select = ["E", "W", "F", "I", "N", "B", "A", "C4", "T20", "UP"]
ignore = []
src = ["src", "tests"]

[tool.ruff.format]
quote-style = "double"
indent-style = "space"

[tool.ruff.isort]
known-first-party = ["descope_mgmt"]

[tool.mypy]
python_version = "3.12"
warn_return_any = true
warn_unused_configs = true
disallow_untyped_defs = true
disallow_any_unimported = true
no_implicit_optional = true
warn_redundant_casts = true
warn_unused_ignores = true
warn_no_return = true
check_untyped_defs = true
strict_equality = true

[[tool.mypy.overrides]]
module = "descope.*"
ignore_missing_imports = true

[tool.pytest.ini_options]
testpaths = ["tests"]
addopts = "--cov=src/descope_mgmt --cov-report=html --cov-report=term-missing --cov-report=term:skip-covered -v"
python_files = ["test_*.py"]
python_classes = ["Test*"]
python_functions = ["test_*"]

[tool.importlinter]
root_package = "descope_mgmt"

[[tool.importlinter.contracts]]
name = "Layer architecture enforcement"
type = "layers"
layers = [
    "cli",
    "domain",
    "api",
    "types",
]
ignore_imports = [
    "descope_mgmt.*.tests -> descope_mgmt.*",
]

[[tool.importlinter.contracts]]
name = "No cross-layer violations"
type = "forbidden"
source_modules = ["descope_mgmt.types"]
forbidden_modules = [
    "descope_mgmt.api",
    "descope_mgmt.domain",
    "descope_mgmt.cli",
]
```

**Step 2: Commit**

```bash
git add pyproject.toml
git commit -m "feat: configure pyproject.toml with dependencies and tools"
```

---

## Task 3: Install Dependencies

**Step 1: Install package in editable mode**

```bash
cd /home/jfogarty/pcc/core/pcc-descope-mgmt
pip install -e ".[dev]"
```

Expected output: Package installed successfully with all dependencies

**Step 2: Verify installation**

```bash
python -c "import descope_mgmt; print(descope_mgmt.__version__)"
```

Expected output: `0.1.0`

**Step 3: Verify import-linter**

```bash
lint-imports
```

Expected output: All contracts validated (no violations yet since no code exists)

---

## Chunk Complete Checklist

- [ ] Directory structure created (4 layers + tests)
- [ ] pyproject.toml configured with all dependencies
- [ ] Package installed in editable mode
- [ ] import-linter validates successfully
- [ ] 2 commits created
- [ ] Ready for chunk 2
